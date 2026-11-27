# Victory Scarlett 3070 comparison

## Status

This comparison used the i7-12700F, RTX 3060 Ti 8 GiB, and 32 GiB Windows D3D12 machine. The existing WASDeKeys checkout and Phase 1 release are preserved. The Scarlett fork and the integration candidate each have separate checkouts. Phase 2 work in progress is preserved in the original working tree and in a patch plus copies of its untracked source files. See [HANDOFF.md](HANDOFF.md) for all Phase 2 requirements and the exact recovery paths.

Keep the WASDeKeys-based branch as the foundation. The preserved release averaged 6.89 FPS against Scarlett's 2.82 FPS at the opening checkpoint. Scarlett spent much more time waiting on the GPU and exceeded its local-memory budget. The combined ports increased warm-start compilation and did not settle before the run closed. A queue-only run with the original cache policy settled at 6.82 FPS, rendered the same checkpoint and exited 0. The queue port is on the primary branch at `95aa317`. The static-sampler bypass remains in the separate integration checkout.

## Source and build

- WASDeKeys base is `179ad6e`. Its Phase 1 baseline is `8999b80`. The preserved executable is `victory-phase1-8999b80.exe` under the original release directory, SHA-256 `e55fb823b9f26c22d18a36d2335880598f6587366c1e0a10ba47068d1ecf5d1c`.
- Scarlett checkout is at `../victory-scarlett-3070`, pinned at `74e7621f0b258ab3f5f246fa9a0c40f3213d68d4`. Its Op-lite ancestor `835ca60` descends from cool_fox `f4b48ad`. Scarlett is five commits past `835ca60`, and 12 past `f4b48ad`. WASDeKeys imported a source snapshot and shares no Git commit objects with Scarlett. Of 250 common paths, 235 vendored files match `f4b48ad` byte for byte, and 175 match Scarlett HEAD.
- Integration worktree is at `../victory-scarlett-integration` on `codex/scarlett-integration`. It branches from the preserved Phase 1 release.
- Both candidates built with `cargo build --offline --locked --release --target x86_64-pc-windows-msvc -p victory --features diagnostics` and pinned Rust 1.98.1. Scarlett build SHA-256 is `ac315cfd8a46dec3599ff872acf611fc3ae78d02807616635d2c129337493085`. Combined release SHA-256 is `d5b207648ebaa49ff16dddfaf9dc98f97e293e6e0f77077087d00dc75ed64db7`.
- I inspected the tracked build hooks, Cargo configuration and lockfile, and the launcher and its graphics switches before running. The build scripts fingerprint source files locally. The comparison used offline builds and the common local harness. The Scarlett launcher can choose a prebuilt executable, applies title-code pacing patches and enables named pipeline exclusions and large write-combined readback suppression. Those launcher options were excluded from the comparison. Zero also overrides pacing, so the variable was left unset.

## What the source showed

| Area | Finding and integration decision |
|---|---|
| NVIDIA heap | Scarlett can reserve more of the 1,000,000-entry heap for transient tables, leaving fewer mirrored entries for guest bindless indices. Both warn at 1,245,184 requested entries. A larger transient reserve does not supply descriptor virtualization. |
| Descriptor processing | Scarlett has in-place dirty record scanning and a fast path for placed texture spans. Its default sweep limits can postpone dirty slots. The common warm comparison disabled those limits. The selected port partitions the texture upload queue before sorting, preserving exact eligibility and ordering. |
| Residency and allocator recycling | Scarlett has additional idle eviction, pooling and reserve controls. The original build retains its verified commit-aware list, prelude and scratch reuse safeguard. Scarlett still crossed the local VRAM budget on the common warm profile. |
| Scratch and readback | Scarlett has scratch reuse and skips reads for already superseded bytes. The separately enabled launcher rule suppresses GPU writeback for large write-combined memory and can leave CPU data or alias views stale. The rule was excluded. The scratch change needs targeted overlap and unmapped-memory tests before porting. |
| Pipeline cache | The port rebuilds static-sampler pipelines through the driver instead of using cross-process library entries for them. It retains in-process reuse and the rest of the library. Scarlett cites a mismatched sampler ordering on an NVIDIA driver. The local six-test suite verifies the policy and cache behavior. A cross-process pixel reproduction on the RTX 3060 Ti remains pending. |
| Shader translation and rendering | Both have Wave32 cascade lowering and integer RTV blend handling. Scarlett keeps split arithmetic for the legacy multiply-add instructions that Phase 1 corrected with a hardware reference test. The original also keeps its BC7 rotation and worker-panic fixes. Scarlett has an alternate HDR target format and ambient replacement. The window scene still had color bands and blocky edges. Both retain gaps in Wave64 translation and BVH execution. |
| Indirect operations | Scarlett's launcher excludes two shader hashes. Those exclusions were omitted. The remaining drops are still substantial and the dedicated Phase 2 rejection census is in progress. Both retain undocumented graphics ABI gaps. |
| Logging | Scarlett's async writer has an unbounded queue and no explicit drain on shutdown. The benchmark used synchronous logging in both builds. A bounded, drainable logger can be evaluated independently. |

## Integrated changes

| Change | Commit | Verification |
|---|---|---|
| Static-sampler pipeline cache bypass | `714cda3` | Six release-profile pipeline-library tests. The new fixture verifies the create path is used and policy is restored after nesting. |
| Partitioned texture queue selection | `aae3811` | Three release-profile queue tests. Differential fixture checks exact full-sort equivalence for deadlines, retries, overwritten and removed slots, and all limits. The 40,000-slot CPU-only microbenchmark returned identical values and measured 5.10 ms old vs 1.45 ms partitioned at a 256-entry request under concurrent load. |
| Shared benchmark runner and log summarizer | `3078989` | One executable at a time, same copied starting save, distinct cache roots, process-local options, retained exit codes, and per-window export. |

## On-machine benchmark

All runs targeted Series S with 1,024 MiB of card buffers, 256 MiB windows, mip drop 1 and 1920×1080 presentation. Internal scene resolution is unverified. Independent copies of the same original warm cache were prepared for the preserved and integration builds. Scarlett used its own cache populated by its cold run. Scarlett's settled row spans a 60-second selection window. The Phase 1 warm row uses the first nine settled samples available when Computer Use stopped. Cold rows capture startup before pipelines settled. Reported FPS is the reciprocal of mean sampled interval time. Global raw-frame percentiles and repeated-run variability remain unmeasured.

| Build and cache | FPS | Frame ms | GPU wait ms | Readback ms | Missing pipeline/frame | Dropped indirect/frame | Rendering and stability |
|---|---:|---:|---:|---:|---:|---:|---|
| Scarlett cold | 2.84 | 352.2 | — | 54.2 | 917 | 1,425 | Average 743 pipelines pending. Severe overexposure. Normal suspend. |
| Phase 1 cold | 2.63 | 380.4 | — | 27.6 | 1,411 | 1,546 | Average 1,039 pending. Black frame. Part of the run overlapped compilation. Exit 0. |
| Scarlett warm, settled | 2.82 | 355.1 | 261.8 | 57.8 | 260 | 573 | Average zero pending. Character and room visible with color banding and blocky edges. Exit 0. |
| Phase 1 warm, settled | 6.89 | 145.2 | 4.9 | 62.8 | 278 | 622 | Zero pending across nine samples. The prior 6.79 FPS reference run visually confirmed the checkpoint. The warm run exited 0. |
| Integration, both ports, warm startup | 2.71 | 369.0 | 0.0 | 77.5 | 284 | 728 | Average 303 pipelines pending, 269 at close. Exit 0. |
| Integration, queue only, warm | 6.82 | 146.6 | 4.0 | 65.9 | 272 | 620 | Eleven settled windows. Character and window rendered without Scarlett's severe banding. Dark interior remains. Exit 0. |

Scarlett warm averaged 35.3 ms of descriptor inspection and 2.6 ms waiting for descriptor work at list close. Dedicated memory use near the end of the window was 8,144 MiB against a 6,793 MiB budget, with 6,072 MiB of shared GPU memory, 1,840 MiB physical RAM free and 2,428 MiB left to commit. The unusually high GPU wait and budget pressure are related observations. This run does not isolate a cause.

The preserved build's warm sample averaged 43.8 ms of descriptor inspection and 21.1 ms of list-close waits. At the end of the selected sample, it reported 5,961 MiB dedicated in use against a 6,637 MiB budget, 5,467 MiB shared, 5,958 MiB physical RAM free and 6,055 MiB left to commit. Scarlett's lower descriptor timings are worth investigating independently. A faster isolated subsystem did not translate into a faster run on this profile.

Queue-only kept persistent static-sampler cache reuse through `VICTORY_LIBRARY_STATIC_SAMPLERS=1` on the integration executable. It reported 41.61 ms slot inspection, 15.27 ms texture processing, 21.53 ms list-close waits, 6,183 MiB dedicated use against a 6,725 MiB budget, and 5,755 MiB shared at the final snapshot. Texture processing was 3.08 ms lower than the previous Phase 1 warm sample. Overall FPS was close, and readback was about 3 ms higher. Some compilation overlapped this run. An earlier settled sample during heavier compilation reached 6.32 FPS. Keep those samples separate and treat any gameplay gain as unproven.

The queue-only exit telemetry reported 3 pipeline creations and 2,083 loads, matching the preserved warm run. The combined ports reported 905 creations and 926 loads. Retest the cache bypass only with a controlled cross-process sampler pixel fixture and an explicit setting.

## Remaining work

Dark lighting and blocked BVH stages, unreadable descriptor positions above the host limit, unaligned buffer ranges, Wave64 refusals, undocumented graphics methods, and indirect failure classification remain open. The original Phase 2 edits are saved but need a review and build. The full correctness matrix, three independent settled runs per significant change, and 30-minute stability validation are outstanding.
