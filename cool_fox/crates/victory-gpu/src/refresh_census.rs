//! Optional attribution of refresh requests and their outcomes.

use std::collections::HashMap;
use std::panic::Location;
use std::sync::atomic::{AtomicU64, Ordering::Relaxed};
use std::sync::{Arc, Mutex, OnceLock, Weak};

use crate::shadow::Shadow;

const MAX_RANGES: usize = 50_000;

type RangeKey = (usize, usize, usize);

#[derive(Default)]
struct Census {
    callers: HashMap<&'static Location<'static>, [u64; 2]>,
    ranges: HashMap<RangeKey, (Weak<Shadow>, u64)>,
    repeats: [u64; 3],
}

fn census() -> &'static Mutex<Census> {
    static CENSUS: OnceLock<Mutex<Census>> = OnceLock::new();
    CENSUS.get_or_init(Mutex::default)
}

fn enabled() -> bool {
    static ENABLED: OnceLock<bool> = OnceLock::new();
    *ENABLED.get_or_init(|| std::env::var_os("VICTORY_REFRESH_CENSUS").is_some_and(|v| v == "1"))
}

pub(crate) fn request(caller: &'static Location<'static>, queued: bool) {
    if enabled() {
        let mut census = census().lock().unwrap_or_else(|e| e.into_inner());
        census.callers.entry(caller).or_default()[usize::from(!queued)] += 1;
    }
}

pub(crate) fn step(shadow: &Arc<Shadow>, from: usize, len: usize, submission: u64) {
    if !enabled() {
        return;
    }
    let mut census = census().lock().unwrap_or_else(|e| e.into_inner());
    let key = (Arc::as_ptr(shadow) as usize, from, len);
    if let Some((_, last_submission)) = census.ranges.get_mut(&key) {
        let local = *last_submission == submission;
        *last_submission = submission;
        census.repeats[usize::from(!local)] += 1;
    } else if census.ranges.len() < MAX_RANGES {
        // Keep only the allocation identity, so a freed Shadow's pointer
        // cannot be reused in the current reporting window.
        census.ranges.insert(key, (Arc::downgrade(shadow), submission));
    } else {
        census.repeats[2] += 1;
    }
}

#[derive(Clone, Copy)]
pub(crate) enum Outcome {
    KeptAheadAsking,
    AheadIndexMismatch,
    CoveredByFront,
    Coalesced,
    DirectBacking,
    Empty,
    Untracked,
    PendingGpuWrite,
    NeedsWriteWatch,
    IncompleteCopyNotes,
    JournalWrite,
    CleanJournal,
    UpdatedWithoutCopy,
    UpdatedWithCopy,
    TextureQueueAlreadyClear,
}

const OUTCOMES: &[&str] = &[
    "kept ahead asking", "index mismatch", "front coverage", "coalesced range", "direct backing", "empty range", "untracked memory",
    "pending GPU write", "needs write watch", "incomplete copy notes", "journal write",
    "clean journal", "updated without copy", "updated with copy", "texture queue already clear",
];

static COUNTS: [AtomicU64; OUTCOMES.len()] = [const { AtomicU64::new(0) }; OUTCOMES.len()];

pub(crate) fn outcome(kind: Outcome) {
    if enabled() {
        COUNTS[kind as usize].fetch_add(1, Relaxed);
    }
}

pub(crate) fn report() {
    if !enabled() {
        return;
    }
    let snapshot = std::mem::take(&mut *census().lock().unwrap_or_else(|e| e.into_inner()));
    let Census { callers, ranges, repeats: [same_submission, other_submission, unclassified] } = snapshot;
    let mut callers: Vec<_> = callers.into_iter().collect();
    callers.sort_unstable_by_key(|(site, [queued, deduplicated])| {
        (std::cmp::Reverse(queued + deduplicated), site.file(), site.line(), site.column())
    });
    tracing::info!(unique_exact_ranges = ranges.len(), same_submission, other_submission, unclassified,
        "refresh census for processed steps");
    for (site, [queued, deduplicated]) in callers.into_iter().take(16) {
        tracing::info!(file = site.file(), line = site.line(), queued, deduplicated, "refresh request source");
    }
    let mut outcomes = OUTCOMES.iter().zip(COUNTS.iter().map(|n| n.swap(0, Relaxed))).collect::<Vec<_>>();
    outcomes.sort_unstable_by_key(|(_, count)| std::cmp::Reverse(*count));
    for (reason, count) in outcomes.into_iter().filter(|(_, count)| *count != 0) {
        tracing::info!(reason = *reason, count, "refresh census outcome");
    }
}
