# Victory Phase 2 review

## Status at 2026-11-27 06:14 CET

The primary checkout is `.`, branch `codex/graphics-overhaul` at `95aa317` with the reviewed Scarlett texture queue port and benchmark tools. It retains Phase 2 graphics edits, two new Rust modules, and documentation updates in the working tree. The separate integration worktree remains on `codex/scarlett-integration` at `3078989`, with a local harness option for reproducing the cache comparison. The WASDeKeys base is `179ad6e` and the preserved release is `8999b80`.

The Windows machine has an i7-12700F with 8 P cores, 4 E cores and 20 logical processors, an RTX 3060 Ti with 8 GiB VRAM and Wave32, NVIDIA driver 617.42, and 32 GiB RAM. Rendering uses Direct3D 12. The matched benchmark profile uses Series S, 1,024 MiB card buffers, 256 MiB windows, texture mip drop 1, and 1920×1080 presentation. Internal scene resolution remains unverified.

The executables below are locked diagnostics releases targeting `x86_64-pc-windows-msvc`, built with the pinned Rust 1.98.1 toolchain.

| Executable relative to its checkout | SHA-256 | Status |
|---|---|---|
| `cool_fox/target/x86_64-pc-windows-msvc/release/victory-phase1-8999b80.exe` | `e55fb823b9f26c22d18a36d2335880598f6587366c1e0a10ba47068d1ecf5d1c` | Preserved Phase 1 release and baseline |
| `cool_fox/target/x86_64-pc-windows-msvc/release/victory.exe`, in the integration checkout | `d5b207648ebaa49ff16dddfaf9dc98f97e293e6e0f77077087d00dc75ed64db7` | Built and passed synthetic tests. Warm startup quit before settling with the bypass active. Queue-only warm run settled and exited 0. |

## Measurements

| Run | FPS | Mean frame ms | GPU wait ms | Readback ms | Descriptor inspection ms | List-close wait ms | Missing pipeline/frame | Dropped indirect/frame |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Original stock, 512 MiB, mip drop 3 | 2.42 | 413 | | 90.7 | | | 276 | 616 |
| Stock, 1,024 MiB, mip drop 3 | 4.34 | 230.4 | | 45.7 | | | | |
| Commit-aware command list recycling | 6.45 | 155.1 | | 65.8 | | | | |
| Preserved Phase 1, final prior release run | 6.79 | 147.3 | | 65.5 | | | 270 | 619 |
| Preserved Phase 1, warm checkpoint | 6.89 | 145.2 | 4.9 | 62.8 | 43.8 | 21.1 | 278 | 622 |
| Scarlett 3070, warm checkpoint | 2.82 | 355.1 | 261.8 | 57.8 | 35.3 | 2.6 | 260 | 573 |
| Combined WASDeKeys integration, warm startup only | 2.71 | 369.0 | 0.0 | 77.5 | 58.8 | 26.6 | 284 | 728 |
| Integration, queue only, later warm checkpoint | 6.82 | 146.6 | 4.0 | 65.9 | 41.6 | 21.5 | 272 | 620 |

The two completed warm comparison runs used library caches populated by their own version and different sample windows. The preserved Phase 1 result has nine settled windows, the Scarlett result eleven. Both exited 0. GPU waits are queue-wait measurements, and the CPU, GPU and readback timers overlap. These samples do not establish global present-interval percentiles.

The preserved build spent about 62.8 ms on readback with 49.4 MB transferred per frame. Scarlett's dedicated use was 8,144 MiB against a 6,793 MiB budget, compared with 5,961 MiB against 6,637 MiB for Phase 1. Scarlett also had 1,840 MiB physical RAM free and 2,428 MiB left to commit, compared with 5,958 MiB and 6,055 MiB for Phase 1. VRAM pressure and high GPU wait co-occurred. Their causal relationship remains unverified.

The combined startup run averaged 303 pending pipelines over its last sampled minute and closed cleanly with 269 pending. The same executable ran the queue-only variant with `VICTORY_LIBRARY_STATIC_SAMPLERS=1` against another clean copy of the baseline warm cache. It reported 3 created and 2,083 loaded at shutdown, matching the preserved run. The combined default-bypass run reported 905 created and 926 loaded. Keep the bypass isolated until a cross-process pixel fixture demonstrates a visual regression worth the compilation cost.

The queue-only run displayed the character and window without Scarlett's severe banding. The dark interior remained. Texture processing was 15.27 ms versus 18.35 ms in the earlier baseline. The later window averaged 6.82 FPS, close to the previous 6.89 FPS. An earlier window overlapped more compiler activity and averaged 6.32 FPS. Treat the fixture speedup as isolated CPU evidence. The profile remains 1920×1080 presentation with internal dimensions pending.

## Changes and verification

- The verified Phase 1 release keeps idle lists and allocators while commit headroom permits, with emergency trimming retained. It includes corrected BC7 channel rotation, pipeline worker failure recovery, fused guest legacy multiply-add verified on RTX 3060 Ti, WARP indirect tests, and an earlier optional per-window frame metrics exporter.
- `714cda3` bypasses persistent pipeline-library entries for pipelines using static samplers while leaving in-process creation and reuse intact. Six library tests passed. Cross-process pixel correctness on RTX 3060 Ti is pending.
- `aae3811` partitions the eligible texture queue before sorting. Three focused queue tests passed, including identical ordering across limits in a differential test. The 40,000-slot CPU-only microbenchmark returned identical results and took 5.10 ms old vs 1.45 ms partitioned at a 256-entry request under concurrent load. Gameplay effect remains unverified.
- `3078989` adds the common benchmark runner, isolated cache and save roots, an exit record, and a sampled window exporter. The Phase 1 warm rerun and Scarlett warm run closed normally.
- Original Phase 2 work includes dirty descriptor sweep instrumentation and deduplication, sparse buffer ranges, individual present intervals, counted indirect rejection reasons, reduced readback interval allocation, readback attribution, and scene extent instrumentation. The indirect clamp wrappers now return typed failures while preserving execution policy. The lighting diagnostic checks the descriptor belongs to a bound heap and starts at a slot boundary. Readback tracing now measures actual event waits separately from the broader relay window. The compilation check is in progress. The PowerShell raw-frame exporter passed an aggregate, timestamp-filter, missing-sample and legacy-export fixture.

## Rendering and stability

The prior Phase 1 image showed a sharp fence and hair. The square hair edge was absent in the inspected frame, and the room remained dark. Scarlett showed banding and blocky edges at its warm checkpoint and severe overexposure during startup. The cold Phase 1 run had a black sample frame with over a thousand pipelines pending. The ambient clamp test changed brightness and left blocky edges visible. It is not a lighting fix. The comparison excluded launcher flags for named pipeline suppression and write-combined readback suppression.

There are still 22 shader translation refusals across multiple Wave64 cases on the preserved run, a one-million-entry host descriptor limit for a 1,245,184-entry guest request, unaligned-view cases, and missing pipeline and indirect operations. The BVH builder remains gated. The queue slot `0xb8` was seen during normal shutdown. Later scenes, sustained timing, device loss over extended runs, render resolution, and stability beyond the brief runs remain pending.

## Immediate continuation

1. Finish the Phase 2 recovered build and release tests on the primary branch. Keep the rollback binary and the separate integration binary.
2. Rebenchmark the new diagnostics release with raw intervals at the same checkpoint. Run readback and dimensions probes separately. Check descriptor wait, GPU readback and ranked indirect drops before attributing change.
3. The original Phase 2 source is already present and repaired in the primary working tree. The pre-recovery patch is an archival copy. Keep the current typed clamp plumbing, lifetime correction, and transfer/census work in the current tree.
4. Continue with descriptor list-close waits, readback attribution, redundant refreshes and the indirect rejection census. Validate scene extents from source and logs before claiming native internal resolution.
5. Append new benchmark records to [BENCHMARK_HISTORY.csv](BENCHMARK_HISTORY.csv), add diagnostic sources to `REVIEW_INPUTS.json` and regenerate with `pwsh -File scripts/new-review-package.ps1`. Run with `-ArchiveReport` before replacing a major report revision. `LOG_MANIFEST.csv` identifies complete local logs, including those represented by redacted excerpts.
