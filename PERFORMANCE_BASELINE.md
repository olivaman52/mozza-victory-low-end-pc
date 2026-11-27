# Performance baseline

Host is Windows, Intel i7-12700F (8 P cores, 4 E cores, 20 logical processors), RTX 3060 Ti (8 GB, native Wave32), and 32 GB system RAM. The run used WASDeKeys `179ad6e`, its diagnostics release, the default low-memory Series S launcher, 512 MiB card buffers, mip drop 3, and a reported 1920×1080 display mode. Internal scene resolution was not independently measured. All runs use local content and logs.

The complete 39,085-line log at `wasdekeys-179ad6e/logs/20261127-000737/game.log` under the local Victory data directory was scanned. The benchmark used ten settled opening-checkpoint log samples, with at least 4,000 draws, zero pipelines compiling and no more than 400 missing-pipeline draws per sample. FPS is 1,000 divided by mean sampled frame time. These are interval averages.

| Item | Baseline |
|---|---:|
| FPS | 2.42 |
| Mean frame time | 413 ms |
| CPU submission preparation | 128.1 ms |
| GPU readback | 90.7 ms |
| Draws / missing-pipeline draws / dropped indirect operations per frame | 4,426 / 276 / 616 |
| Shader translation warnings | 22 |
| Dedicated usage and budget near checkpoint | 5,473 MiB / 6,236 MiB |
| Host pipelines built | 1,724 |

The overlay showed one roughly 315 ms GPU-busy reading. Preparation, GPU work and readback overlap. The frame log's “on the GPU” field counts time spent waiting for the GPU and cannot substitute for the busy estimate. The first run built its shader and pipeline cache before these samples. The opening checkpoint is insufficient to characterize later scenes or long sessions.
