# Performance results

| Configuration | FPS | Mean frame time | GPU readback | Notes |
|---|---:|---:|---:|---|
| WASDeKeys stock, 512 MiB, mip drop 3 | 2.42 | 413 ms | 90.7 ms | Ten settled samples |
| Same stock executable, 1,024 MiB, mip drop 3 | 4.34 | 230.4 ms | 45.7 ms | Ten settled samples. Blocky hair lighting remained. |
| Commit-aware list recycling, 1,024 MiB, mip drop 3 | 6.45 | 155.1 ms | 65.8 ms | Ten settled samples. The blocky edge remains visible. |
| Before legacy shader fix, 1,024 MiB, mip drop 1 | 6.76 | 148.0 ms | 66.5 ms | Ten settled samples. The fence and hair were sharper, and the blocky edge was absent in the inspected frame. |
| Final release, 1,024 MiB, mip drop 1 | 6.79 | 147.3 ms | 65.5 ms | Ten settled samples. The blocky edge was absent in the inspected frame, and the room remained dark. |

The second run reused the saved cache. Both comparisons filter out windows with outstanding pipelines, but the scene timing and system activity varied. The 1,024 MiB cap increases memory use. The second run reported about 3.2 GiB free physical RAM and 8.6 GiB remaining commit near the sample.

The stock build enabled physical-memory pressure and discarded command lists despite available commit. The 512 MiB run created about 285,000 lists and 75,000 preludes cumulatively by shutdown. The matched stock 1,024 MiB run had already created 54,486 lists by its opening scene. The patched 1,024 MiB run stabilized at 1,477 list creations, with over 6,000 MiB of available commit. Readback time rose against the stock 1,024 MiB run even as total frame time fell. List and prelude counts are cumulative, and the runs had different durations.

The patched comparison is `wasdekeys-179ad6e/logs/pool-fix-1024-mip3-20261127-005426/game.log` under the local Victory data directory. The ambient clamp had its default value during this comparison. The patch does not add a render or dispatch skip.

Verification used nine release-profile tests across memory-pressure policy, pipeline worker recovery, frame-time quantiles, descriptor spans and BC7 decoding. All passed. A synthetic log fixture also verified the JSON exporter.

The rebuilt release was run with the optional frame metrics and `VICTORY_AMBIENT_MOST=1`. Across the last 30 matched one-second windows, mean window FPS was 6.3, mean window median latency was 151.8 ms, and mean window p95 and p99 were both 214.5 ms. These are averages of window-level quantiles. The lower clamp changed brightness while the blocks around the hair persisted. The run closed normally. The JSON exporter was also verified against the live log.

The sharper profile used 6,374 MiB out of a 6,741 MiB local budget near the checkpoint. The earlier mip-drop-3 run used 6,124 out of 6,782 MiB. The small FPS difference may reflect scene and system variation. No crash or device loss appeared in the five-minute sharper-texture run. Dark lighting remained.

The synthetic indirect-budget test initially assumed the opt-in consume-the-rest mode. The revised fixture covers both policies explicitly. Nine WARP indirect tests and three queue/fence tests passed. The shader test matched a fused CPU arithmetic reference on the RTX 3060 Ti. Three existing wave tests passed, including bit-exact half-wave arithmetic on the hardware adapter.

The final release regenerated shader translations. The run recorded about 1,438 cumulative list creations by the checkpoint and showed 5,864 MiB of 6,589 MiB dedicated GPU memory in use near the last sample. The final run was still active after seven minutes, with no device loss logged. Extended stability and internal 1080p remain unverified. The 0.03 FPS difference between the two mip-drop-1 runs is within run-to-run variation.

The final capture exported 349 profiling windows to `cool_fox/target/benchmarks/overhaul-checkpoint.json`. The last 30 matched windows averaged 6.80 FPS, a 144.8 ms median and a 172.6 ms p95 and p99, calculated as averages of window-level quantiles. The run log is `wasdekeys-179ad6e/logs/overhaul-1024-mip1-20261127-011800/game.log` under the local Victory data directory.

The final run still averaged roughly 270 missing-pipeline operations and 619 dropped indirect operations per frame. The explicitly disabled ray-tracing structure builder accounted for about 255 of the missing-pipeline operations per frame in one sampled window. Descriptor work took about 36–45 ms looking at slots and caused about 17–26 ms of waits at list close in nearby windows. Readback and descriptor work overlap other timings. The path to 10 FPS requires further work in these areas plus validation of the missing graphics operations.
