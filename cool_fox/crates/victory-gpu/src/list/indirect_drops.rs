//! CPU-side reasons an indirect call was not recorded. The GPU's separate
//! budget counters measure records that were recorded but later ran empty.

use std::sync::atomic::{AtomicU64, Ordering::Relaxed};

macro_rules! reasons {
    ($($variant:ident => $label:literal),+ $(,)?) => {
        #[derive(Clone, Copy, Debug, Eq, PartialEq)]
        #[repr(usize)]
        pub(crate) enum Reason { $($variant),+ }

        impl Reason {
            const ALL: &[Self] = &[$(Self::$variant),+];

            #[cfg(feature = "diagnostics")]
            fn label(self) -> &'static str {
                match self { $(Self::$variant => $label),+ }
            }
        }
    };
}

reasons! {
    UnsupportedSignature => "unsupported_signature",
    InvalidArgumentBuffer => "invalid_argument_buffer",
    InvalidCountBuffer => "invalid_count_buffer",
    NoHostList => "no_host_list",
    DiagnosticPipelineSkip => "diagnostic_pipeline_skip",
    BuilderUnavailable => "bvh_builder_unavailable",
    RayTracingDependency => "ray_tracing_dependency",
    MissingPipeline => "missing_pipeline",
    PipelinePending => "pipeline_pending",
    ShaderTranslation => "shader_translation_failed",
    PipelineRejected => "host_pipeline_rejected",
    PipelineMismatch => "pipeline_kind_or_topology_mismatch",
    ArgumentBacking => "argument_backing_unavailable",
    CountBacking => "count_backing_unavailable",
    HostSignature => "host_signature_unavailable",
    DiagnosticMeshSkip => "diagnostic_mesh_skip",
    InvalidLayout => "invalid_argument_layout",
    ArgumentAlignment => "argument_alignment",
    CountAlignment => "count_alignment",
    ClampUnavailable => "argument_clamp_unavailable",
    ClampBudgetBuffer => "clamp_budget_buffer_unavailable",
    ClampScratchBuffer => "clamp_scratch_buffer_unavailable",
    ClampAddressing => "unsupported_clamp_addressing",
    IndexBacking => "index_backing_unavailable",
    DescriptorSlots => "descriptor_slots_unavailable",
    RootDescriptor => "root_descriptor_unavailable",
    ShaderAddressing => "shader_addressing_unavailable",
    IndirectMeshAbi => "indirect_mesh_abi_unimplemented",
}

struct Counts([AtomicU64; Reason::ALL.len()]);

impl Counts {
    const fn new() -> Self {
        Self([const { AtomicU64::new(0) }; Reason::ALL.len()])
    }

    fn add(&self, reason: Reason) {
        self.0[reason as usize].fetch_add(1, Relaxed);
    }

    fn take(&self) -> [u64; Reason::ALL.len()] {
        std::array::from_fn(|i| self.0[i].swap(0, Relaxed))
    }
}

static DROPS: Counts = Counts::new();

pub(crate) fn note(reason: Reason) {
    DROPS.add(reason);
}

pub(super) fn take() -> u64 {
    let counts = DROPS.take();
    let total = counts.iter().sum();
    #[cfg(feature = "diagnostics")]
    if tracing::enabled!(target: "victory_gpu::indirect_metrics", tracing::Level::INFO) {
        for (rank, (reason, calls)) in ranked(&counts).into_iter().enumerate() {
            tracing::info!(
                target: "victory_gpu::indirect_metrics",
                rank = rank + 1,
                reason = reason.label(),
                calls,
                total,
                share_percent = 100.0 * calls as f64 / total as f64,
                "indirect calls dropped"
            );
        }
    }
    total
}

#[cfg(any(feature = "diagnostics", test))]
fn ranked(counts: &[u64; Reason::ALL.len()]) -> Vec<(Reason, u64)> {
    let mut ranked: Vec<_> = Reason::ALL.iter().copied().zip(counts.iter().copied())
        .filter(|&(_, count)| count != 0)
        .collect();
    ranked.sort_unstable_by_key(|&(reason, count)| (std::cmp::Reverse(count), reason as usize));
    ranked
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn failures_are_ranked_and_counted_once_across_recording_threads() {
        let drops = Counts::new();
        std::thread::scope(|scope| {
            for _ in 0..8 {
                scope.spawn(|| {
                    drops.add(Reason::PipelinePending);
                    drops.add(Reason::PipelinePending);
                    drops.add(Reason::InvalidArgumentBuffer);
                    drops.add(Reason::RayTracingDependency);
                });
            }
        });
        let counts = drops.take();
        assert_eq!(counts.iter().sum::<u64>(), 32);
        assert_eq!(ranked(&counts), [
            (Reason::PipelinePending, 16),
            (Reason::InvalidArgumentBuffer, 8),
            (Reason::RayTracingDependency, 8),
        ]);
        assert!(ranked(&drops.take()).is_empty());
    }
}
