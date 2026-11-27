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
