# Victory Phase 2 handoff

## Starting point and constraints

Continue the graphics overhaul on `codex/graphics-overhaul` from `8999b80`. Preserve the Phase 1 fixes and the existing pressure recovery. Work with authorized source and legally obtained local test content. Keep title assets, derived captures and logs outside version control. Leave DRM, licensing, authentication, system security and GPU watchdogs outside the scope. Keep incomplete GPU paths gated. Do not guess undocumented ABI details or improve benchmarks by dropping required work.

Target Windows D3D12 on an i7-12700F (8 P cores, 4 E cores, 20 logical processors), RTX 3060 Ti (8 GiB) and 32 GiB RAM. Aim for correctly rendered 10 FPS, then 15–20 FPS, then investigate stable 30 FPS at verified internal resolution. Establish and fix the lighting error, reduce synchronization overhead and missing operations, and validate 30 minutes of sustained operation.

## Work requested

| Priority | Area | Requirements |
|---|---|---|
| P0 | Descriptor processing | Incremental dirty slots, generations, reverse references, destruction, remapping, late backing, aliasing, deduplication, batching, fence-aware retirement and a counted conservative scan. Preserve non-uniform indexing. Aim to halve slot inspection and measure list-close waits. |
| P0 | GPU readback | Attribute producer, resource and requested versus modified ranges, consumer evidence, waits, copying, page protection and overlapping requests. Validate CPU/GPU overlap, aliasing and remaps before changing coherency or transfer policy. Explain the Phase 1 readback increase. |
| P0 | Command preparation | Avoid provably redundant refreshes, batch memory queries, and reduce guard and protection contention. Preserve synchronization and isolate overlapping costs. |
| P0 | Dark lighting | Compare intermediate targets and authorized references. Check missing compute, shader arithmetic, views, formats, constants, barriers, sampling, indirect and acceleration structures. Keep experimental brightness overrides off. |
| P0 | BVH | Validate producer and traversal shaders, GPU addresses, layout, lifetime, barriers, counters, readback and order with deterministic fixtures. Preserve the gate until the complete path works. |
| P0 | Indirect drops | Rank actual rejection reasons, including pipelines, shaders, signatures, argument/count buffers, addressing, state, budget, descriptors and prior producers. Add WARP and hardware fixtures before targeted fixes. |
| P1 | Wave64 | Implement only proven lowering for divergence, lane masks, reductions, first-active reads, and cross-half communication. Compare CPU references and Ampere outputs with inactive lanes, partial waves and floating-point edge cases. |
| P1 | Descriptor capacity and alignment | Design remapping beyond 1,000,000 host entries with coherent GPU mappings and descriptor lifetimes. Test unaligned CBV, SRV and UAV ranges with overlapping GPU writes before replacing null fallbacks. |
| P1 | Undocumented methods | Establish contracts for device `0x1c8`/`0x218`, pipeline state `0x58`, list `0x1a8` and queue `0xb8`. Shutdown queue warning is lower priority. |
| P1 | Hardware profiling | Measure worker counts independently, P/E core scheduling, CPU/GPU overlap, utilization, memory and residency. No global scheduling changes. |
| P0 | Reproducible benchmarks | Three independent comparable runs per significant change. Match checkpoint, camera, settings, resolution, system load and settle conditions. Keep cold and warm runs distinct. Capture actual FPS, global median/p95/p99 from raw intervals, preparation, GPU idle/execution, readback, descriptors, dropped work, memory and image comparisons. |
| P1 | Resolution and stability | Record scene, dynamic resolution, upscaler input/output and presentation dimensions. Run authorized workloads for at least 30 minutes and check resource growth, device loss, cache and frame-time degradation. |

## Current state

- Baseline binary copied to `cool_fox/target/x86_64-pc-windows-msvc/release/victory-phase1-8999b80.exe`. Both binaries matched SHA-256 `e55fb823b9f26c22d18a36d2335880598f6587366c1e0a10ba47068d1ecf5d1c` at Phase 2 start.
- Read all 32,948 lines of `%LOCALAPPDATA%/victory/wasdekeys-179ad6e/logs/overhaul-1024-mip1-20261127-011800/game.log`. It ends with the queue `0xb8` warning, normal title suspension, pipeline library save and exit code 0.
- Baseline at Series S, 1,024 MiB buffer cap, mip drop 1 is 6.79 FPS, 147.3 ms, 65.5 ms readback, around 270 missing-pipeline and 619 dropped indirect operations per frame. Latest representative window reports 48.5 ms descriptor inspection, 11.6 ms span/refresh, 16.0 ms textures and 29.6 ms waiting at list close. These timings overlap. Stock comparisons were 2.42 FPS default and 4.34 FPS at 1,024 MiB. The list recycling change reached 6.45 FPS at mip drop 3.
- Complete log contains 22 translation refusals across divergent reductions, lane masks, first-active-lane reads and generic unsupported Wave64 shapes. About 255 missing-pipeline operations per frame in a previous sampled window were explicitly disabled BVH stages. Current lighting resolves approximately 1280×720 with radiance and air buffers at 640×360 and 80×46. Scene resolution and causality for dark lighting are open.
- Phase 1 ambient clamp experiment failed to resolve the outline and only changed brightness. The final Phase 1 build used the original ambient default. Mip drop 1 looked sharper and the outline was absent in the inspected frame. Dark lighting remained.

## Milestones

| Issue | Root cause | Implementation and files | Tests | Before and after | Remaining limitations |
|---|---|---|---|---|---|
| Phase 1 rollback | New builds replace the primary binary | Verified separate pre-Phase 2 binary | SHA-256 comparison | Identical binaries | Rollback artifact is locally ignored by Git |

## Resume here

1. Inspect `cool_fox/crates/victory-gpu/src/draw.rs` `heap_buffer_pass` and `descriptor/host.rs` `Slots`, `note_buffer`, and `mirror`. First preserve the existing fallback schedule and fence behavior while reducing duplicate invalidation and measuring reasons, then add lifetime/range invalidation only where transitions are established.
2. Attribute readback in `land.rs`, `relay.rs`, `shadow.rs` and `watch.rs`. Classify indirect failures from `draw.rs` and `list.rs` before altering execution. Add raw presentation interval capture and use the existing 1,024 MiB, mip 1 profile for the first matched tests.
3. Run `pwsh -File scripts/build.ps1` and focused release-profile tests from `cool_fox` with `--locked --target x86_64-pc-windows-msvc --features diagnostics`. Keep each verified change small. Update this file and the Phase 1 documents after each milestone.

## Scarlett 3070 comparison and integration

The user paused Phase 2 to compare the Scarlett 3070 fork on the same machine and workload, then selectively integrate validated changes and resume Phase 2.

- Original checkout deliberately remains on `codex/graphics-overhaul` with Phase 2 changes in progress. At the comparison start, the tracked diff was saved to `cool_fox/target/benchmarks/phase2-pre-scarlett.patch` and the untracked files to the adjacent `phase2-pre-scarlett-untracked` directory. The Phase 1 release binary and benchmark exports remain in place.
- The independent Scarlett checkout is at `../victory-scarlett-3070`, pinned at `74e7621f0b258ab3f5f246fa9a0c40f3213d68d4`. Its listed Op-lite base `835ca60` follows cool_fox `f4b48ad`. WASDeKeys vendors the cool_fox tree, so Git commit IDs do not intersect. Of 250 shared paths, 235 vendored blobs match `f4b48ad`, 182 match `835ca60`, and 175 match Scarlett HEAD.
- Separate integration worktree `../victory-scarlett-integration` branches from `8999b80` on `codex/scarlett-integration`. Its first candidate excludes static-sampler pipelines from the persistent D3D12 pipeline library while still creating and executing them. Files are `pipeline/host.rs` and `pipeline/library.rs`. Scarlett documents a cross-process sampler-index issue on an NVIDIA 4070 SUPER. Retest image fidelity and warm startup on the RTX 3060 Ti.
- Scarlett's 3070 launcher sets two shader-hash exclusions, suppresses GPU writeback for large write-combined buffers, and patches pacing through the executable. Those switches are excluded from the controlled run and integration. The async stderr writer has an unbounded queue and no shutdown drain. Stock release measurements use synchronous logging in both builds.
- At comparison start Phase 2 work in the original checkout included fallback scan instrumentation and deduplication, sparse buffer ranges, raw intervals, indirect rejection reporting, readback attribution and interval reuse, and scene dimension instrumentation. These edits are unverified and remain separate from the Scarlett candidate. The three helpers reached account usage limits, so review their incomplete edits and compile before resuming.

### Source review

| Area | Scarlett at `74e7621` | Decision |
|---|---|---|
| NVIDIA heap | `descriptor/host.rs` adjusts the dynamic reserve down to a cap of half the host heap. The launcher requests 524,288. This trades mirrored guest slots for transient capacity. It neither virtualizes indices above one million nor preserves all lower guest indices. | Keep the current cap split while instrumenting actual table allocation failures and high-index use. |
| Descriptor processing | `b4ed67d` adds in-place dirty record scanning, span quick checks and in-place synchronization. `bc264a4` adds named-only tables and queue marks. | Retain candidate references. Review the copied/table lifetimes and mapping guards before adapting. Existing conservative fallback remains necessary. |
| Memory and residency | Scarlett adds immediate idle eviction, VRAM reserve changes, pooling, write-watch early exit, and cold residency changes. `list.rs` still ties pooling to broad physical pressure. | Keep local commit-aware list recycling. Measure individual eviction/page-pool changes with aliasing, residency and texture refill checks. |
| Readback | Scratch reuse in `707d7d9` avoids a read if newer CPU writes cover it. `b4ed67d` launcher separately disables large write-combined writebacks. | Scratch reuse needs an unmapped/partial-read fixture. Preserve GPU-produced bytes until a buffer's CPU dependency is established. |
| Shaders and format | Both have Wave32 cascade support and integer RTV blend handling. Scarlett has extra lowering, static-sampler cache protection, R9G9B9E5 format experiment and ambient replacement. | Keep Phase 1 fused arithmetic, BC7 rotation and pipeline panic tests. First isolate the static-sampler cache policy. Do not equate ambient replacement or a substitute format with a lighting fix. |
| Indirect and BVH | Scarlett retains experimental indirect options and the BVH gate, explicitly drops two pipeline hashes in the launcher, and still stubs device slots `0x1c8`/ `0x218`. | Compare common execution settings and maintain the Phase 2 rejection census. |
| Logging and pacing | `logging.rs` uses an unbounded async queue without a drain. `frame_rate.rs` patches title code for custom timing only when `VICTORY_FRAME_INTERVAL_MS` is set. Zero is also an override. | Use synchronous logging, keep the patch inactive, and preserve measured frame intervals. |
| Build review | Tracked build scripts fingerprint source files locally. The lockfile uses crates.io dependencies, with the direct `tracing` dependency already in the graph. The 3070 launcher sets process variables and invokes local executables, but can fall back to an arbitrary prebuilt root executable and writes its log into the checkout. | No downloaded executable or upstream launcher was run. Execute only the offline, locked local build through the shared harness with logs and saves outside the checkout. |

### Build and benchmark progress

- Scarlett and the integration candidate both compiled with pinned Rust 1.98.1 using `cargo build --offline --locked --release --target x86_64-pc-windows-msvc -p victory --features diagnostics`. Scarlett binary SHA-256 is `ac315cfd8a46dec3599ff872acf611fc3ae78d02807616635d2c129337493085`. Six release-profile pipeline library tests passed. Integration source and the shared launcher are committed as `714cda3`. The test establishes that the local bypass reaches pipeline compilation and restores policy after nesting. A hardware reproduction of incorrect cross-process sampling is still pending.
- `scripts/compare-scarlett.ps1` in the integration worktree supplies the common Series S profile with 1,024 MiB card buffers, 256 MiB windows, mip drop 1 and reported 1920×1080. It records binary identity and settings, gives each variant its own cache, and uses copies of the same starting save and storage. Original saves remain in place.
- First cold Scarlett benchmark is running in `%LOCALAPPDATA%/victory/bench-scarlett-74e7621/scarlett/cold/logs-20261127-021621`. Its first launcher held the log exclusively, so read that run after close. Later invocations use a readable log file. The startup screen alone is not a benchmark.

Next, capture Scarlett at the first settled scene and close it gracefully. Read its log, then run `phase1` and `integration` with the same settings and equivalent cold/warm caches. Continue selecting samples at the same playable checkpoint. Verify drops, screen contents, memory, process exit, and the degree to which resolution is comparable before choosing the long-term foundation.
