# Victory graphics overhaul

Start with WASDeKeys `179ad6e` and its vendored Windows renderer. Build with pinned Rust 1.98.1, MSVC and the locked dependency graph. Use local game data and synthetic fixtures. The Windows host policy, licensing, authentication, DRM, watchdog and driver protections are outside the work.

| Priority | Issue and source | Implementation and acceptance |
|---|---|---|
| P0 | Command list churn in `victory-gpu/src/{list,host,residency}.rs` | Keep bounded allocator reuse while commit headroom is healthy. Retain emergency cleanup. Compare list creations, frame time and commit headroom on the same checkpoint. |
| P0 | Guest pipeline slots 0x1c8 and 0x218 in `device.rs` | Confirm layouts from authorized ABI information and fixtures. Feed supported state and shader stages through `pipeline/{host,make,library}.rs`. Test malformed layouts, variant state and concurrent reuse. |
| P0 | Dropped Wave64 programs in `victory-shader/src/{ir,structure,emit}` | Identify wave operations and divergence, then prove equivalent lowering against CPU references and GPU fixtures. Report unsupported shapes precisely. |
| P0 | Bindless heap cap and alignment in `descriptor/host.rs`, `draw.rs`, `shadow.rs` | Trace guest and host slot indices separately. Validate non-uniform indexing, lifetimes and generation handling before enabling indirection. Preserve byte ranges for CBVs, SRVs and UAVs. |
| P1 | Missing indirect graphics and compute in `indirect.rs` and `list.rs` | Separate missing signatures and pipelines from count and budget failures. Validate GPU-generated arguments, barriers and ordering. |
| P1 | Physical and committed memory, textures, and lighting in `residency.rs`, `texture.rs`, `tiles.rs`, `ambient.rs` | Keep physical RAM, commit and DXGI local budgets separate. Compare mip settings and verify images. Validate tiled light correction independently from the buffer profile. |
| P1 | Copy and fence overhead in `host.rs`, `shadow.rs`, `watch.rs`, `queue.rs` | Measure dirty ranges, transfer overlap and real GPU writes. Deduplicate only identical in-flight ranges with equivalent ownership and fence ordering. Compare bytes returned to the guest. |
| P1 | Diagnostics in `host.rs`, `host/panel.rs`, `copystat.rs` | Add optional per-presentation latency quantiles and machine-readable sample fields. Compare matched scenes with diagnostics and validation overhead called out. |
| P2 | Worker scheduling and caches in `pipeline/make.rs`, `pipeline/library.rs`, `shader_cache.rs`, HLE DirectStorage and page mapping | Compare worker counts and cache fingerprints before adjusting defaults. Validate on cold and warm caches and report adapter and driver behavior. |
| P2 | Queue slot 0xb8 in `queue.rs` and CPU emulation in `victory-loader/src/console_insn.rs` | Confirm suspend semantics in an authorized fixture. Profile instruction emulation before changing it. |

Benchmark gates are visibility, correct draws and dispatches, stability, then sustained FPS at verified internal resolution. Reach 5, 10 and 20 FPS before drawing conclusions about 30 or 60 FPS. Use identical builds and workloads for individual setting changes. Keep unsupported API calls explicit until their contracts are known.

The command-list change passed its first checkpoint comparison at 6.45 FPS versus 4.34 FPS on the stock executable with the same buffer cap. The buffer cap comparison reached 4.34 FPS versus 2.42 FPS with stock defaults. The final release averaged 6.79 FPS with mip drop 1 and passed focused shader arithmetic tests on hardware. The main measured costs still include readback and bindless descriptor processing. The heap pass already tracks descriptor writes, but periodically revisits slots for resource destruction and late backing allocation. Replacing the remaining scan needs invalidation coverage for both events plus remaps and aliased ranges. Most missing-pipeline operations in the checkpoint were disabled BVH builder stages. The builder needs complete translation and GPU-written address and readback fixtures before enabling it. See [results](PERFORMANCE_RESULTS.md) and [compatibility status](COMPATIBILITY_STATUS.md).

## Phase 2 acceptance sequence

1. Validate the recovered sparse descriptor sweep and dirty-slot deduplication with fallback, slot-rewrite and remap tests. Report inspected slots and list-close waits at the same checkpoint. Preserve heap mirroring and fence ownership.
2. Keep exact readback merge results and attribute GPU fetch and CPU guard work separately. Test concurrent CPU writes, GPU overlap, aliases, remaps and missing pages. Decide which refresh paths to change from measured no-copy and lock-contended categories.
3. Rank indirect failures while GPU budget-rejected records remain separately counted. Confirm the dominant reason before changing signatures or dependencies. Keep incomplete BVH paths gated.
4. Verify scene and upscaler resource dimensions before introducing alternate upscalers. Defer frame generation until the base renderer has stable frame times and a verified pre-HUD frame identity.
