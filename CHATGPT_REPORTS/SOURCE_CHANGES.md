# Victory source changes for review

## Landing job-size recovery

`land.rs` accepts `VICTORY_LAND_JOB_KB` between 64 and 1,024 and keeps 256 KiB as the default. The `jobs_with_target` partition retains the existing sorted piece order and keeps pieces sharing a guest 64 KiB block together. `land/tests.rs` covers five target sizes and validates the partition across ranges that cross job boundaries. Tests and the offline release passed. The one-variable screen delivered 6.62 FPS at both 256 and 512 KiB. Commit `bca549d` retains the smaller default.

`scripts/compare-scarlett.ps1` records status, actual PID and binary hash in `run.json` and supports optional diagnostic timeline output. `scripts/new-review-package.ps1` verifies archived report hashes before replacing the review ZIP and records the current working tree, last test, benchmark and incomplete runs.

## D3D12 capability probe and strict linked-record fixture

Commit `aa47688` shares the device's Options19 result in `host.rs`. `descriptor/host.rs` skips allocations beyond the reported modern device limit and retains the old allocation fallback for legacy feature reporting. `pipeline/host.rs` uses the cached query for static-sampler lowering. `memory.rs` verifies real hardware, device-local heaps, two dispatched stages and exact result and sentinel values. It captures the D3D12 validation message before the runtime drains the info queue. This exposed and confirmed the fix for the original invalid 4,194,304-entry heap probe. Both hardware modes and 37 descriptor tests passed.

## Refresh diagnosis

`watch.rs` consumes candidate ranges lazily when the submission already has a held write-watch result. Its optional `VICTORY_AHEAD_INDEX` finds exact single-asking coverage using a sorted index. `VICTORY_AHEAD_INDEX_VERIFY=1` compares decisions and uses the original result. `refresh_census.rs`, `host.rs` and `shadow.rs` add ranked call-site, repeat and outcome telemetry behind `VICTORY_REFRESH_CENSUS=1`. All 33 focused watch and popwatch tests passed with the opt-in index on and off. The performance experiment remains opt-in pending the isolated throughput screen.

`draw.rs` adds opt-in timeline sampling of descriptor/buffer lookup and the subsequent refresh enqueue and deduplication. One request in 128 is sampled per participating recording thread. UAV declarations, aliases, and resource state processing follow the same code paths. This diagnostic change is pending compilation and the first samples.

`descriptor/host.rs` retains the independent opt-in texture-queue membership candidate. It adds both exact write-generation and two-thread remap/removal fixtures. The candidate has yet to be included in a benchmark build.

## Warm-up receipts and interrupted-run recovery

`compare-scarlett.ps1` records source provenance, planned windows and child exit before draining logs. `summarize-warmup.ps1` exports raw intervals and partial-window status, reported pipeline backlog, logged shader completions, pipeline-library save counters and matching Windows activity. The recovery fixture exercised a real interrupted log. `compare-run-metrics.ps1 -RequireSuccessfulExit` rejects exit code 1. `new-review-package.ps1` now includes the warm-up report and sanitized critical-path summaries.

## Selective Scarlett integration

`95aa317` adapts the queue selection from `aae3811` and ports the common harness. `TextureQueue::due` partitions the due retry and fresh lists before sorting just the selected entries. The differential fixture verifies exact selection and ordering under varied limits. The port passed the opening checkpoint with the original static-sampler cache policy. Texture processing changed from 18.35 to 15.27 ms in sampled runs. Overall FPS was 6.82 versus 6.89, so gameplay benefit is unproven. The default cache-bypass run was still compiling at close and rebuilt hundreds of pipelines that stayed cached with queue-only.

## Phase 2 recovery

The recovered release repairs indirect rejection propagation and sparse descriptor iteration. `indirect::validate_layout` and `bound` return the observed failure with the existing layout and address checks. `draw::State::lighting_view` checks the handle belongs to the active heap and to a descriptor boundary before reading. `Host::relay_card_back` records opt-in sampled event-wait time and reuses a range vector within a landing job. The release compiled and ran the diagnostic checkpoint to exit code 0. The first test pass revealed a default-policy assumption in the budget-reset fixture. The revised fixture supplies exact half-budget dispatches.

The separate `VICTORY_SPANS_QUICK=1` candidate adds conservative per-slot membership to `HostHeap`. Non-placed updates can bypass the shared `Spans` mutex only when the slot cannot hold a span record. Marking and clearing happen under the slot's existing writer lock. Alias invalidation can leave a conservative mark. The mode defaults off and still needs paired gameplay runs.

`scripts/compare-run-metrics.ps1` checks the binary hash, cache mode, console configuration and isolation of the selected switch. It requires raw intervals spanning the requested window and samples with zero pipelines pending. The fixture covers the intended pair and rejects mismatched identity, extra setting changes, unsettled windows and an unchanged experimental setting.

## Phase 1 and Scarlett ports

| Change and provenance | Files and behavior | Verification, impact and rollback |
|---|---|---|
| `7805667` commit-aware pool pressure | `victory-gpu/src/{host,list,residency}.rs`. Keep idle host list and allocator reuse while Windows commit headroom is healthy. Retain emergency clearing on allocation failures. | Matched cap and mip settings went from 4.34 to 6.45 FPS. List allocations were much lower. Use the original release executable to isolate the change. |
| `b116467` BC7 and worker recovery | `victory-formats/src/bcpack.rs` corrects BC7 channel rotation. `victory-gpu/src/pipeline/make.rs` converts worker panic to failure and preserves recovery. `ambient.rs` adds a diagnostic clamp option. | Focused fixtures passed. Brightness clamp experiment left blocky edges visible. Restore the earlier binary to isolate these changes and leave the override disabled for matched runs. |
| `99b1b47` indirect policy tests | `victory-gpu/src/indirect.rs` verifies both list-budget modes in WARP, with the opt-in setting made explicit. | Nine indirect tests and three queue/fence tests passed. Runtime drop attribution remains pending. |
| `2789f51` legacy arithmetic | `victory-shader/src/emit/lower.rs` compiles the guest legacy multiply-add as a fused operation with the required zero handling. `emit/valu_tests.rs` adds an arithmetic reference fixture. | Hardware CPU/reference comparison passed on RTX 3060 Ti. |
| `714cda3`, from Scarlett | `victory-gpu/src/pipeline/{host,library}.rs`. A scoped policy bypasses persistent pipeline library reuse for static-sampler pipelines and restores the policy for nested work. | Six focused cache tests passed. Warm application benchmark and cross-process artifact reproduction remain pending. Run preserved `8999b80` for direct comparison instead of altering existing game data or cache. |
| `aae3811`, adapted from Scarlett `b4ed67d` | `victory-gpu/src/descriptor/host.rs`, texture queue selection. Partition candidates and sort the subset selected by the original earliest/newest and retry ordering. | Three focused tests passed. Identical selection against the reference sort across all tested limits. CPU fixture improved from 5.10 to 1.45 ms at 256 requests, with gameplay impact pending. |
| `3078989` benchmark runner | `scripts/compare-scarlett.ps1` and `scripts/summarize-scarlett.ps1`. Match one workload and settings, save process exit and sampled windows, and preserve per-fork cache separation. | Runtime logs and benchmark exports retained locally. A short cold sample estimates compilation and startup behavior. It cannot characterize steady performance. |

Paths under `victory-gpu/src`, `victory-shader/src`, and `victory-formats/src` belong to `cool_fox/crates`. The integration source remains on `codex/scarlett-integration`, based on `8999b80`. See [SCARLETT_REPORT.md](SCARLETT_REPORT.md) for the excluded Scarlett launcher behaviors and comparison methodology.

## Unfinished Phase 2 source

The pre-Scarlett snapshot is preserved as `cool_fox/target/benchmarks/phase2-pre-scarlett.patch` and `phase2-pre-scarlett-untracked`. The working tree adds descriptor sweep metrics and deduplication in `draw.rs` and `descriptor/host.rs`, presentation timing in `host.rs`, extra extent diagnostics in `ambient.rs`, `draw.rs`, and `host/spans.rs`, provenance and temporary buffer work in `land.rs`, `land/readback_trace.rs`, `shadow.rs` and `texback.rs`, and indirect reasons in `list.rs`, `list/indirect_drops.rs`, `draw.rs`, `pipeline.rs`, and `pipeline/make.rs`.

The recovery snapshot records the original interrupted work. The current source includes both new Rust modules and the follow-up fixes. Keep the named Phase 1 and Phase 2 rollback binaries for controlled comparisons.

The latest working-tree patch adds single-lock copy coverage in `shadow.rs` and DXGI Present result tracking in `host.rs`. The benchmark helper and guest-lighting switch are included. The requested stop interrupted compilation after correcting a missing test import. The full patch is included in the review archive and is separate from the tested `6afb875` release.

## Targeted follow-up

Commit `5811d95` finishes the interrupted source patch. The four focused release tests passed. It combines shadow copy coverage under the existing page lock and records accepted DXGI intervals separately from attempted frames. A gap across an occluded or failed call remains part of elapsed time between successive accepted presentations. Windows display scan-out remains a separate measurement.

The shared launcher rejects active Victory tests and compiler processes and accepts an optional landing worker count for controlled experiments. The updated summary separates CPU merge, fetch, refresh and descriptor phases. The Windows performance sampler records process CPU time and GPU-engine activity from outside Victory. Use the same sampler cadence for both sides of any experiment.

| Commit | Source and invariants | Verification |
|---|---|---|
| `1e71efa` | `memory.rs` and `descriptor/host.rs`. Move the directory view slots from an address-keyed global cache to their owning host heap. Encode full guest addresses in disjoint list-key namespaces. | Two address/heap regression tests and an RTX 3060 Ti GPU pointer round trip passed. The builder gate stays active. |
| `0478002` | `shadow.rs` and `land.rs`. Reuse exclusion and allowed-range scratch per worker job, coalesce spans in place and binary-search their ends. Preserve snapshot lock order and flight publication. | Differential complements and three exact-byte or concurrent CPU/GPU fixtures passed. Gameplay performance is pending. |
| `4336c22` | `descriptor.rs`, `host.rs` and scripts. Clip read regions at the mirrored slot bound behind `VICTORY_HEAP_CLIP_READS`; query the full original write-watch range. Include recorded compute dispatches in timing samples. | Both descriptor cap fixtures and the metrics parser passed. An on/off comparison is pending and the flag defaults off. |

The pending landing job-size experiment keeps the existing 256 KiB default and preserves a whole 64 KiB guest memory block across job boundaries. Changes are in `land.rs`, its randomized partition fixture, and the comparison launcher. They are separate from the current six-worker run and await test and build.
