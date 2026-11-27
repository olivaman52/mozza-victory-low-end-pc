# Recommended configuration

Use the diagnostics release and a separate cache for this checkout. Keep info logging and the in-game FPS panel for benchmark runs. Select Series S through the included launcher. Preserve the real save directory across comparisons.

From the repository root, run `./scripts/build.ps1`. This invokes a locked diagnostics release build of `victory` for `x86_64-pc-windows-msvc`, using the vendored tree's pinned toolchain. The executable is at `cool_fox/target/x86_64-pc-windows-msvc/release/victory.exe`. The local build with the legacy shader fix has SHA-256 `e55fb823b9f26c22d18a36d2335880598f6587366c1e0a10ba47068d1ecf5d1c`.

`launch.ps1 -Game <path> -CardBuffersMb 1024 -MipDrop 1` is the sharpest tested profile. It averaged 6.79 FPS at the opening checkpoint on the final release. Use `-MipDrop 3` at the same buffer cap for more VRAM headroom. The launcher default of 512 MiB is the lower-memory fallback. A reported 1080p display mode does not establish internal render resolution.

Set `VICTORY_FRAME_METRICS=1` to log one window of actual presentation intervals per second. Pass the resulting game log to `scripts/measure-frames.ps1 -Log <path>` for JSON. Each window reports median, p95 and p99 latency. Separate CPU preparation and GPU wait fields overlap other timings and should not be summed.

| Switch | Implementation |
|---|---|
| `VICTORY_ASYNC_SUBMIT`, `VICTORY_THIN` | Submission and compact list recording in the GPU queue/list paths |
| `VICTORY_FAST_CORES`, `VICTORY_DSTORAGE_IO` | Windows thread placement and DirectStorage I/O paths |
| `VICTORY_LATE_WAIT`, `VICTORY_RELAY`, `VICTORY_WAIT_RESIDENT` | Queue flight completion, readback relay and resource residency waits |
| `VICTORY_LEVELS_ON_DEMAND`, `VICTORY_UPLOAD_AHEAD`, `VICTORY_SHOW_AFTER` | Mip residency, texture upload-ahead and visibility after transfer |
| `VICTORY_SEND_CHANGED`, `VICTORY_HEAP_PASS_ASIDE` | Dirty upload and descriptor scanning paths |
| `VICTORY_CARD_REHASH_RUNS`, `VICTORY_JOIN_COPIES` | Grouping card hash work and combining adjacent recorded copies |

Use the tested launcher's settings as a set until an individual switch has a measured result. Keep experimental lighting and shader adjustments separate.

The Phase 2 candidate preserves the original static-sampler cache policy. Keep `VICTORY_READBACK_TRACE` and `VICTORY_RENDER_DIMENSIONS` off during a throughput run. For a separate diagnostic run, they measure readback fence waits and known render-resource extents. Set `VICTORY_RAW_FRAME_INTERVALS=1` when collecting frame-level statistics. Run `scripts/measure-frames.ps1 -Log <path> -From <UTC timestamp> -To <UTC timestamp> -Aggregate` for a true aggregate median and nearest-rank p95/p99 across the selected window.

`VICTORY_SPANS_QUICK=1` is a descriptor lock experiment available in `6afb875`. The first pair showed a small difference and had different per-frame work. Keep the flag off in the recommended profile.

The shared comparison matches the existing launcher values of ambient 0.3 and air 1.5. Run the separate `-DisableAmbientStandIn` experiment to inspect the game's own lighting outputs while retaining the BVH gate. It changes only `VICTORY_AMBIENT` to zero. Use the other profile values for direct comparison and keep the brightness clamp experiment off.

`VICTORY_HEAP_CLIP_READS=1` reduces guest record reads in the capped heap mirror. It read 6.02 instead of 11.51 MiB per frame in the first pair and had similar workload counts. FPS and latency tails did not improve. Keep the flag off in the recommended profile.

Keep four landing workers and a 256 KiB target. Six workers reduced landing wall time to 34.37 ms from 39.29 ms while FPS stayed around 6.9 and worker CPU time rose. The 512 KiB comparison halved the job count while both sizes measured 6.62 FPS and landing wall time stayed near 40.7 ms.

Use `-RefreshCensus`, `-AheadIndex -VerifyAheadIndex`, and `-TimelineAtSeconds 203,233` on `scripts/compare-scarlett.ps1` for separate diagnostic runs. The timeline hooks and extra validation visits affect timings. Keep the optional coverage index off in the throughput profile until a matched screen shows its effect.
