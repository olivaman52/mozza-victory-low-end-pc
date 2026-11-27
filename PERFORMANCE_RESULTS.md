# Performance results

## Matched coverage-index retry

Two 50-second zero-backlog samples from the same release used equivalent warm cache and data copies and exited 0. The control and candidate had 4,531 and 4,550 host draws per attempt, and 3,438 and 3,335 compute dispatches. The camera and frame content varied within the opening scene. Mean system CPU was 75.83% and 75.89% in five Windows samples per run. The highest other GPU engine averaged 58.76% and 58.01% respectively.

| Index | Accepted FPS | Mean / median / p95 / p99 (ms) | Write-watch (ms) | Refreshes (ms) |
|---|---:|---|---:|---:|
| Off | 6.83 | 146.50 / 142.71 / 178.27 / 261.62 | 9.08 | 38.86 |
| On | 6.73 | 148.57 / 145.08 / 182.11 / 256.98 | 9.87 | 37.92 |

The index stays off. This screen showed no improvement in accepted-present throughput or median or p95, with a small workload difference. The separately preserved 6.53 FPS exit-code-1 minute remains partial evidence. Both repeat runs showed visible hair and outdoor geometry and a dark interior.

## Landing job-size screen

Both runs used four workers, independent copies of the same warm seed, and `victory-phase2-job-screen.exe` with SHA-256 `eef6a415ba32c636dd1dfb5c27a21f1a56c00df7ae8f15483dbc99a903e81cf0`. The 512 KiB run advanced sooner, so both samples use 40 seconds from the matching opening-window segment with zero pending pipelines. The raw accepted intervals cover 40.06 and 39.70 seconds.

| Target | FPS | Median / p95 / p99 ms | Landing wall / worker sum ms | Jobs per frame | Draws / dispatches |
|---|---:|---|---|---:|---:|
| 256 KiB | 6.62 | 144.41 / 196.12 / 396.13 | 40.77 / 147.90 | 263.16 | 4,555 / 3,381 |
| 512 KiB | 6.62 | 147.34 / 204.35 / 253.82 | 40.62 / 141.78 | 135.57 | 4,647 / 3,488 |

GPU fetch averaged 32.76 and 22.36 ms while landing wall time moved just 0.15 ms. The candidate had roughly 2% more draws, 3% more dispatches and higher background GPU activity in the available Windows samples. Both runs rendered the character and continued to show dark interior lighting. Both exited 0. The similar FPS and nearly unchanged landing wall time do not warrant a default change or additional worker and job-size combinations at this point. Raw pair and separate activity logs are indexed in the review package.

## Opening-scene diagnostic timeline

Two three-frame traces, taken separately from throughput measurements, recorded 71.62 and 67.22 ms of graphics-queue work and 89.27 and 38.21 ms idle. Instrumentation and guest Present timing make the samples unsuitable as FPS benchmarks. The reconstructed paths include 10.52 and 6.98 ms per frame between wake-up and execution, 4.49 and 8.76 ms in a copy refresh, and 5.00 and 6.64 ms in the texture heap pass. The second sample shows recording workers waiting for `HostHeap::queue_texture` via `note_buffer` and `mirror`. Such waits overlap. Verify the effect of removing proven-empty queue lookups with matched throughput samples.

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

## Phase 2 integration

The preserved warm baseline averaged 6.89 FPS. The queue-only Scarlett port averaged 6.82 FPS in eleven later settled windows with the same profile and a separate clone of the warm cache. Texture processing fell from 18.35 to 15.27 ms while list-close wait was similar at 21.53 ms versus 21.12 ms. Both reports are sampled windows. The difference does not establish a gameplay speedup. The queue differential fixture proved ordering equivalence and its CPU-only benchmark was faster. The queue change is on the primary branch at `95aa317`.

The default static-sampler bypass in the separate integration branch produced 905 creations and 926 loads, compared with 3 creations and 2,083 loads while retaining cache reuse. It exited before settling. The current branch uses the original cache policy. Details and conditions are in [Scarlett report](SCARLETT_REPORT.md).

## Recovered Phase 2 diagnostics

The warm run at 06:22 CET on November 27 reached the opening checkpoint and exited with code 0. The 60-second sample beginning at 06:25 CET had 316 raw present intervals across 55 windows. The observed presentation rate was 5.23 FPS with a 191.07 ms mean, 187.51 ms median, 237.68 ms p95 and 295.65 ms p99. Frame generation was inactive. Detailed tracing and concurrent test compilation affect this sample, so it cannot establish a throughput delta versus the earlier 6.89 FPS release.

| Measurement | Diagnostic result |
|---|---:|
| CPU preparation and GPU readback | 157.27 ms and 74.42 ms per sampled frame, overlapping other timers |
| GPU readback volume | 50.67 MB per sampled frame |
| Descriptor inspection, spans, textures and close wait | 48.36 ms, 7.08 ms, 21.30 ms and 18.65 ms |
| Buffer descriptor sweep | 128,697 candidates deduplicated in 316 frames, about 407 per frame, with about 2.17 ms per frame selecting candidates |
| Indirect rejections | 186,940 ray dependency (94.82%) and 10,214 shader translation failures (5.18%) across the sampled windows |
| Indirect GPU budget | Zero observed empty records for budget in 55 windows |
| Card-diff relay | 480 transfer samples, 1.85 ms mean event wait and 2.30 ms mean record, submit and wait time per sampled batch |

The sampled relay batches averaged 5.94 MB. The trace observes eventual publication to guest memory. It cannot tell whether the guest CPU reads each published range. The fallback accounted for 2.86 million candidates and the dirty set for 3.27 million candidates, so removing their overlap alone leaves substantial work. The layer observed a 1280×720 scene-depth input and Resolve output, with a 1920×1080 swap chain. Primary scene color and upscaling dimensions are still open.

In the same diagnostic window, 480 sampled landing jobs averaged 45,849 eligible bytes and 16,506 bytes stored to guest memory. Mean wall time was 69.39 µs per sampled job and 1.97 µs in its instrumented guard region. The sampler takes the first eligible jobs each second, so those per-piece figures cannot be multiplied by all jobs to estimate whole-frame cost.

Evidence is in `phase2-diagnostic-raw.json`, `phase2-diagnostic-summary.json` and the 06:22 runtime log. The selected interval is a single checkpoint sample. Timing figures are from different counters with overlapping scopes.

### Timing-only checkpoint run

The 06:32 CET launch used the same recovered release with raw presentation intervals and an independent warm cache copy. Over the 60-second window starting at 06:35:30, 391 raw intervals yielded 6.49 mean FPS, 154.03 ms mean, 150.60 ms median, 193.85 ms p95 and 238.50 ms p99. Sampled counters averaged 124.81 ms preparing, 65.88 ms readback, 49.09 MB read back, 40.29 ms looking at descriptors and 11.66 ms waiting at list close. There were 275.25 missing pipelines and 615.25 indirect drops per sampled frame. Near the end of the minute, dedicated use was 5,903 MiB of 6,527 MiB, and shared use was 5,637 MiB. System counters showed 2,571 MiB free and 7,562 MiB commit headroom. The opening checkpoint showed the character, window and hair with the dark interior. The app exited 0 after about five minutes. Test compilation still overlapped the run.

The span-lock candidate defaults off. Use separate warm cache and data copies for on and off runs of the same candidate binary. Compare wait and memory counters alongside the sample images and rejection counts.

### First paired span-lock experiment

Both launches used the `6afb875` executable, Series S, 1,024 MiB buffers, mip drop 1, 1920×1080 presentation, and independent copies of the same warm seed. They differed in `VICTORY_SPANS_QUICK`. The first settled minute of each run passed the identity, setting, raw coverage and pipeline checks in `scripts/compare-run-metrics.ps1`.

| Metric | Off | On |
|---|---:|---:|
| Raw present intervals | 377 | 397 |
| FPS | 6.31 | 6.55 |
| Mean frame interval | 158.50 ms | 152.68 ms |
| Median, p95 and p99 | 153.91 / 201.73 / 339.54 ms | 149.73 / 184.89 / 208.15 ms |
| Descriptor inspection | 44.11 ms | 42.89 ms |
| Descriptor list-close wait | 16.07 ms | 15.73 ms |
| Readback | 67.76 ms | 68.84 ms |
| Draws per sampled frame | 4,622 | 4,495 |
| Missing pipelines and indirect drops per sampled frame | 281 / 628 | 280 / 614 |

The 0.24 FPS difference comes from one pair. Both samples showed the character and window, with dark lighting. The fence appeared in the span-on screenshot and was faint or absent in the span-off screenshot, which also showed blue patches. Scene timing and per-frame work differed, so the still images cannot attribute those changes to the switch. The opt-in remains off by default pending repeatable pixel and performance results. The complete pair is in `cool_fox/target/benchmarks/phase2-span-paired.json`.

The earlier raw frame meter counted intervals after all DXGI Present calls. The screenshots establish visible output for the inspected checkpoints. No frame generation backend was active in these runs.

## Targeted Phase 2 clean-build baseline

The `5811d95` release launched at 07:23 CET after compilation and all tests had finished. It used the historical Series S, 1,024 MiB buffer, 256 MiB window, mip-drop-1 profile, an isolated copy of the warm cache, and raw accepted DXGI presentation intervals. The opening window and hair rendered. The interior stayed dark. Presentation was 1920×1080 with internal color dimensions unverified.

| Metric | 07:26:35–07:27:35 CET |
|---|---:|
| Accepted presentation intervals | 410 in 56 timing windows |
| Accepted presentation rate | 6.82 FPS |
| Mean, median, p95 and p99 | 146.58 / 142.25 / 186.27 / 259.22 ms |
| CPU preparation and readback | 115.00 / 64.66 ms |
| GPU fetch and CPU landing wall time | 21.02 / 39.31 ms |
| Guest record sweep and its wait | 52.55 / 13.69 ms |
| Host view inspection and list-close wait | 41.63 / 14.45 ms |
| Resource refreshes and known no-copy calls | 10,046 / 9,029 per sampled frame |
| Draws, missing pipelines and indirect drops | 4,609 / 279 / 620 per sampled frame |
| Dedicated and shared GPU memory | 6,247 of 6,806 MiB and 5,584 MiB shared near the final sample |

No unaccepted DXGI calls or outstanding pipelines were logged in the sample. The app closed normally with status 0. No compiler or synthetic GPU workload ran during the measurement. Windows' wildcard performance counter query failed after one startup sample, so settled background activity is unknown. That startup sample recorded active desktop CPU and GPU processes. The next sampler revision discards invalid counters and reports incomplete sampling. The new accepted-present metric does not independently confirm scan-out. The 6.82 FPS result is a baseline screen and does not establish an improvement over the historical 6.89 FPS.

CPU landing averaged about 261 jobs per frame and 5.69 ms of guard work summed across workers. The guest record sweep read 11.46 MiB per frame and considered about 198,272 candidate slots. Read-and-compare took 6.60 ms while view creation took 20.20 ms. These timings overlap other work. The updated export also reports 95.32% unavailable ray dependencies and 4.68% shader translation failures among sampled CPU-side indirect rejections.

### Guest descriptor clipping screen

The `4336c22` executable ran two warm opening-window samples with a 60-second selection and the same Series S graphics settings. The clip-off window began at 07:41:20 CET and clip-on at 07:46:40 CET. Both had zero outstanding pipelines and exited 0. Six Windows CPU and GPU samples cover each minute. Both visually rendered the character and scene. Dark lighting and intermittent image artifacts were still visible. The screenshots do not establish pixel equivalence, and memory use and background activity differed.

| Metric | Clip off | Clip on |
|---|---:|---:|
| Accepted presentation intervals | 413 | 415 |
| FPS | 6.93 | 6.88 |
| Median / p95 / p99 | 141.94 / 173.80 / 213.33 ms | 141.72 / 186.02 / 235.28 ms |
| Host draws / compute dispatches per attempt | 4,558 / 3,363 | 4,556 / 3,382 |
| Guest descriptor candidates / new mirrors | 199,366 / 9,552 | 197,343 / 9,610 |
| Guest descriptor reads | 11.51 MiB | 6.02 MiB |
| Guest descriptor processing / wait | 54.33 / 14.67 ms | 52.60 / 12.58 ms |
| Host inspection / list-close wait | 41.54 / 15.38 ms | 40.00 / 16.62 ms |
| GPU fetch / CPU landing | 21.01 / 39.29 ms | 20.24 / 40.02 ms |
| Missing pipelines / indirect drops | 273 / 612 | 275 / 613 |
| Dedicated budget / use at final sample | 6,618 / 5,984 MiB | 6,589 / 6,511 MiB |
| Shared GPU memory at final sample | 5,260 MiB | 5,814 MiB |

Clipping reduced the read volume by about 48% with similar recorded draw and dispatch counts. The first pair showed a 2.09 ms lower guest sweep wait and a small decline in FPS. System CPU averaged 74.67% off and 72.99% on. The most active background GPU engine per snapshot averaged 27.46% off and 28.38% on. These are sampled individual engine figures and cannot be summed into GPU occupancy. Preserve the opt-in for diagnosis. There is no sustained throughput gain to justify enabling it or repeating the pair immediately. The host pass and CPU landing remain separate costs. [Paired export](cool_fox/target/benchmarks/phase2-targeted-clipping-pair.json)

### Landing worker screen recovered after interruption

The six-worker 07:52:30 CET sample used the same `4336c22` executable, graphics settings, independently cloned warm inputs and opening window as the four-worker clip-off sample. Each window recorded 413 accepted presents with settled pipelines. CPU and per-engine activity are from six snapshots per window.

| Metric | Four workers | Six workers |
|---|---:|---:|
| Accepted presentation FPS | 6.93 | 6.87 |
| Median / p95 / p99 | 141.94 / 173.80 / 213.33 ms | 143.68 / 173.68 / 213.31 ms |
| CPU landing wall / worker sum | 39.29 / 139.52 ms | 34.37 / 170.15 ms |
| Jobs | 257.67 | 257.38 |
| Guard and merge-lock work summed across workers | 5.52 / 1.66 ms | 8.11 / 1.57 ms |
| GPU fetch / whole readback | 21.01 / 65.06 ms | 19.43 / 57.54 ms |
| Host draws / compute dispatches | 4,558 / 3,363 | 4,578 / 3,395 |
| Dedicated use / budget, shared GPU use | 5,984 / 6,618 MiB, 5,260 MiB | 6,430 / 6,712 MiB, 5,484 MiB |
| System CPU / highest background engine mean | 74.67% / 27.46% | 74.40% / 28.60% |

Worker time divided by merge wall time increased from 3.55 to 4.95. This estimates average parallel work during the measured region. Per-worker imbalance and wake or dispatch delay were unrecorded. The faster landing and readback did not improve frame time in this pair. Four workers remain the default. The six-worker process later exited 0 after about seven hours and 17 minutes. The log shows a window close and a title suspend timeout. No matching device-loss or crash line appeared. Its final window had about 5,275 host draws per frame, outside the controlled opening-window workload. [Paired export](cool_fox/target/benchmarks/phase2-targeted-landing-workers-pair.json)

An offline Wave32 translation probe admitted 52 of 52 BVH builder programs to D3D12 compute pipeline creation. Six existing intersection fixtures passed. Four indirect list tests, the new atomic membership test, and an existing span extent test passed with D3D12 debug and GPU-based validation requested. The test output confirms the results. It does not independently report which validation interfaces Windows enabled.
