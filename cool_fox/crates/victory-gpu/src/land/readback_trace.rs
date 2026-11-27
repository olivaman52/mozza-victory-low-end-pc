//! Optional traces for the relay and its readback consumers. Each kind has
//! a bounded sample budget to limit I/O while a title is running.

use std::sync::OnceLock;
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::{Duration, Instant};

pub(crate) fn enabled() -> bool {
    static ON: OnceLock<bool> = OnceLock::new();
    *ON.get_or_init(|| std::env::var_os("VICTORY_READBACK_TRACE").is_some_and(|v| v == "1"))
}

#[derive(Clone, Copy)]
pub(crate) enum Kind {
    CardFetch,
    CardMerge,
    SharedMerge,
    Texture,
}

/// Admit eight samples per elapsed second, per category. The count is kept
/// in the low byte so callers on different landing workers share a budget.
fn admit(slot: &AtomicU64, second: u64) -> bool {
    let stamp = second << 8;
    slot.fetch_update(Ordering::Relaxed, Ordering::Relaxed, |previous| {
        let old_stamp = previous & !0xff;
        if old_stamp < stamp {
            Some(stamp | 1)
        } else if old_stamp == stamp && previous & 0xff < 8 {
            Some(previous + 1)
        } else {
            None
        }
    })
    .is_ok()
}

pub(crate) fn sample(kind: Kind) -> Option<Instant> {
    static EPOCH: OnceLock<Instant> = OnceLock::new();
    static COUNTS: [AtomicU64; 4] = [const { AtomicU64::new(0) }; 4];
    if !enabled() || !tracing::enabled!(tracing::Level::INFO) {
        return None;
    }
    let epoch = *EPOCH.get_or_init(Instant::now);
    let now = Instant::now();
    admit(&COUNTS[kind as usize], now.duration_since(epoch).as_secs()).then_some(now)
}

pub(super) struct Merge {
    shadow: u64,
    start: usize,
    end: usize,
    eligible_bytes: usize,
    written_envelope: Option<(usize, usize)>,
    guards: Duration,
    began: Instant,
    producer: &'static str,
}

impl Merge {
    pub(super) fn start(shadow: &crate::shadow::Shadow, title: usize, parts: &[(usize, usize)]) -> Option<Self> {
        let (kind, producer) = if shadow.carded() {
            (Kind::CardMerge, "gpu_buffer_fetch")
        } else {
            (Kind::SharedMerge, "gpu_shared_buffer")
        };
        Some(Self {
            began: sample(kind)?,
            shadow: shadow.id(),
            start: title + parts.first()?.0,
            end: title + parts.last()?.1,
            eligible_bytes: parts.iter().map(|&(start, end)| end - start).sum(),
            written_envelope: None,
            guards: Duration::ZERO,
            producer,
        })
    }

    pub(super) fn guards(&mut self, duration: Duration) {
        self.guards += duration;
    }

    /// A page segment in which at least one store was made. The assembly
    /// merge reports the store count, without per-dword offsets.
    pub(super) fn written(&mut self, start: usize, end: usize) {
        self.written_envelope = Some(self.written_envelope.map_or((start, end), |(a, b)| (a.min(start), b.max(end))));
    }

    pub(super) fn finish(self, beside: bool, dwords: u64, missing_segments: u64) {
        let elapsed_us = self.began.elapsed().as_micros() as u64;
        tracing::info!(
            producer = self.producer,
            consumer = "guest_memory_publication",
            cpu_read = "unobserved",
            shadow = self.shadow,
            eligible_start = self.start,
            eligible_end = self.end,
            eligible_bytes = self.eligible_bytes,
            written_segment_envelope = ?self.written_envelope,
            dwords_stored = dwords,
            missing_segments,
            beside,
            guard_us = self.guards.as_micros() as u64,
            elapsed_us,
            "GPU buffer readback merge sample"
        );
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sampling_budget_resets_without_reopening_old_windows() {
        let slot = AtomicU64::new(0);
        for second in [0, 1, 4] {
            for _ in 0..8 {
                assert!(admit(&slot, second));
            }
            assert!(!admit(&slot, second));
        }
        assert!(!admit(&slot, 2));
        assert!(admit(&slot, 5));
    }
}
