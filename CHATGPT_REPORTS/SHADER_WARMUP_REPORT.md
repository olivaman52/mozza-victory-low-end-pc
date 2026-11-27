# Shader and pipeline warm-up

## Historical observation

The six-worker run used one warm seed and the executable with SHA-256 `d7cda8019bb0298f8bd8c19d0bb09b2e9180846bba74579bce8bc27dacd1e73e`. The process ran for about seven hours and exited 0 after a window-close request and title suspend timeout. Scene, camera and external activity were uncontrolled after the initial benchmark.

| Elapsed window | Accepted-present FPS | Raw p95 | Peak logged pipeline backlog |
|---|---:|---:|---:|
| 5–6 minutes | 7.36 | 165.76 ms | 3 |
| 10–11 minutes | 7.71 | 150.07 ms | 0 |
| 15–16 minutes | 7.58 | 150.32 ms | 0 |
| 20–21 minutes | 7.71 | 153.58 ms | 0 |
| 30–31 minutes | 7.64 | 155.82 ms | 0 |

These figures came from the supplied independent reanalysis. They suggest little change from minute 10 to 30. Scene and host workload variation prevent attributing the earlier change to pipeline creation. The long run establishes survival until shutdown under that workload. It leaves the controlled stability test open.

A scan of the complete historical log found 1,657 successful shader translations and 22 refusals in the first minute, 28 successes in the minute-2 window, one in the minute-5 window and zero in the minute-10 through minute-30 windows above. A newly encountered pixel shader successfully translated about 55 minutes after launch. This is evidence of later on-demand work, with no evidence of continuous translation across the measured windows.

## Controlled warm-cache run and restart

The run began at 16:25:04 CET with the preserved diagnostics release, four workers, 256 KiB landing jobs, 1080p presentation, an isolated warm cache and separate benchmark data. PID 29692 is recorded in `CHECKPOINT.json`. The final minute is scheduled to finish at 16:56:04 CET. Keep a fixed opening checkpoint and camera where the title allows. Record automatic camera transitions or changes in workload and compare similar segments only.

`scripts/compare-scarlett.ps1 -RawFrameIntervals -SummaryMinutes 0,2,5,10,15,20,25,30` writes the planned end and process identity, then calls `scripts/summarize-warmup.ps1` after the log drains. The summary marks partial windows and records actual process exit separately from wrapper status. An activity export can be joined afterward. Keep diagnostics, compilation and synthetic GPU work out of the run.

After normal close, inventory the isolated cache, then restart the same executable with identical settings, the warmed cache and a clean copy of the same benchmark data. Record cache persistence, startup through the same checkpoint and the first comparable zero-backlog interval. The driver cache is shared unless independently shown otherwise. Shader completion log messages are useful even when pipeline backlog reports zero. Exact active worker counts and independently measured displayed/rendered FPS remain unavailable in this binary.
