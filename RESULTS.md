# Results

All runs on one machine, first playable scene, console profile "Series S",
same sandbox and the same launcher settings (cool_fox's "pareto-residency"
profile, see `scripts/settings.env`) unless a row says otherwise.

## Machine

| | |
|---|---|
| GPU | NVIDIA card (test machine) |
| CPU | Core i7-13700KF |
| RAM | 62 GB |
| OS | Arch Linux, kernel 6.18 LTS |
| Driver | NVIDIA 620.73.04, open kernel modules rebuilt with NVIDIA PR #1542 (issue #1540: random kernel soft lockups) |
| Wine | GE-Proton11-6, vkd3d-proton from Proton Experimental, DXVK `dxgi.dll`, Microsoft `d3dcompiler_47.dll` |
| Build | `scripts/build.sh` defaults: release, `--features diagnostics` |

## Method

- **Frame time** comes from the fork's own frame statistics line
  (`… fps, … ms/frame (… preparing …)`, printed at `VICTORY_LOG=info`), read
  over the steady scene once the world is shown. The range given is the spread
  of those lines; the median is noted where it was computed. No external
  frame-time tool was used.
- **"Clean"** means: the title did not stop, no "no frame presented" pause
  warning, no GPU channel fault reported by the NVIDIA driver while the scene
  ran (driver messages at the title's shutdown are not counted).
- **Split** (where noted): CPU time preparing submissions, time on the card,
  time copying results back, as reported on the same line.
- Runs were made with the screens asleep (DPMS); see the known defects in the
  README.
- Cold caches = the runner's shader, pipeline and image caches empty at start;
  warm = filled by an earlier run of the same build.

## Configurations

### A. cool_fox `f4b48ad`, unmodified

Settings: cool_fox's launcher profile as shipped (including
`VICTORY_LEVELS_ON_DEMAND=1`, `VICTORY_CARD_BUFFERS_MIN_KB=64`).

| Runs | Length | Frame time | Faults | Notes |
|---|---|---|---|---|
| 1 | 900 s asked, 764 s of scene, cold caches | 360–410 ms (2.4–2.8 fps) | clean: 0 GPU faults, 0 pauses | split: preparing 27–31 ms, copying back 17–22 ms |

Picture and work: 7 of the 16 pipeline worker threads died of a stack overflow
(vkd3d-proton's DXIL-to-SPIR-V converter recursing without end), so some
work was never done (about 600 indirect dispatches lost per frame); many
textures were missing (some untextured surfaces, dark interiors).

### B. + patches 0001–0002, texture mip drop 2

Settings: A with `VICTORY_LEVELS_ON_DEMAND=0`, `VICTORY_TEXTURE_MIP_DROP=2`.

| Runs | Length | Frame time | Faults | Notes |
|---|---|---|---|---|
| 5 | 1 × 900 s (761 s of scene, cold caches) + 4 × 420 s (warm) | 271–291 ms (3.4–3.7 fps) over the five | 5 clean of 5; 0 stack overflows; 0 GPU hangs | split (first run): preparing 26–28 ms, on the card 251–255 ms, copying back 17–19 ms |

Picture: textures back; no worker thread lost. Heads still not drawn (also
the case in A).

### C. + memory placement (the ~10 fps configuration)

Settings: B with `VICTORY_CARD_BUFFERS_MB=1024`, `VICTORY_CARD_WINDOWS_MB=768`,
`VICTORY_TEXTURE_MIP_DROP=3` (this is `scripts/settings.env`). Build: patches
0001–0004 applied, the switches of 0003 and 0004 off, so the code that ran is
that of 0001–0002.

| Runs | Length | Frame time | Faults | Notes |
|---|---|---|---|---|
| 1 (first run) | 600 s asked, 504 s of scene (about 8 min), warm caches | 100–105 ms (9.5–9.9 fps); median of the last 60 lines 102.5 ms; fastest line 90 ms | clean | split: preparing 23–25 ms, on the card 69–75 ms, copying back 13 ms |

Picture: as B, textures one mip level softer (drop 3 instead of 2); heads still
not drawn. Four further runs of 420 s with the same settings were clean, with medians of 100.6, 104.3, 106.4 and 101.4 ms per frame (264 to 320 s of scene each). The only driver messages were logged at the moment each run was stopped.

One further run with `VICTORY_TEXTURE_MIP_DROP=2` (sharper textures) and the same memory settings gave 97–100 ms per frame, clean; with drop 1 it was 115 ms (the measured card no longer holds the copies). Drop 2 with these settings was then validated on five clean runs (92–106 ms).

## D. Current settings: C with `VICTORY_CARD_WINDOWS_MB=256` and `VICTORY_TEXTURE_MIP_DROP=1`

Five clean runs of 420 s: medians 98, 112.2, 101.9, 106 and 107.7 ms per frame (270–340 s of scene each). Sharper textures than C at the same speed.

Budget sweep, runs of 330 s (compare only runs of equal length: the scene gets heavier with time, 330 s runs read about 10 ms lower than 420 s runs), `MIP_DROP=2`:

| `CARD_BUFFERS_MB` | `CARD_WINDOWS_MB` | median ms per frame |
|---|---|---|
| 1024 | 768 | 92–98, 96.5 |
| 1024 | 256 | 91.2, 90.2, 93.5 |
| 1024 | 128 | 97.8 |
| 1024 | 0 | 93.6 |
| 1280 | 512 | 106.1 |
| 1536 | 256 | 103.7 |
| 768 | 1024 | 273.7 |
| 640 | 1152 | 274.6 |

So `CARD_BUFFERS_MB=1024` carries the gain: below it the frame time returns to about 275 ms. With the monitors awake or asleep the figures are the same within noise.



## What the gain from B to C is

About 180 ms per frame. Our reading (inferred from the driver's power and bus
figures during B, not measured pass by pass): in B the card waited more than it worked: shader-written
buffers and the title's vertex/index memory lived in the PC's memory, so the card
read them across PCIe and the CPU checked them after each frame. Raising the cap
of card-side buffer copies to 1024 MB and copying 768 MB of the title's memory
windows to the card moved that traffic onto the card; the extra texture mip drop
makes room for it on the card. No rendering pass is skipped by these three settings.

## Windows, AMD Radeon RX 9070 XT (contributed run, not the authors' machine)

The first Windows figures for this repository. The README's Windows path was followed as written, with
nothing changed: build with `scripts\build.ps1` (release, `--features diagnostics`) at `494e574`, and start
only through `scripts\run.cmd` with its defaults. That means Series S, `VICTORY_LOG=info`,
`CARD_BUFFERS_MB=512`, `CARD_WINDOWS_MB=256`, `TEXTURE_MIP_DROP=3`, `LEVELS_ON_DEMAND=1`,
`STAGING_KEPT=2`, `MAX_PRELUDES=16`, `DISPLAY_MODE=1920x1080`, and the other launcher values as
printed under "settings in effect". The run added only two variables, passed with `-KeepEnv`:
`VICTORY_KEYS` (Enter presses to get past the start screens) and `VICTORY_CACHE_DIR` (a dedicated
cache folder, so that "cold" really means empty). No `VICTORY_*` value differed from the launcher's.

| | |
|---|---|
| GPU | AMD Radeon RX 9070 XT 16 GB, driver 32.0.32029.2010 |
| CPU | AMD Ryzen 7 9800X3D |
| RAM | 32 GB, 64 GB page file |
| OS | Windows 11 Pro 26200 (native, no Wine) |

**Method.** The frame statistics line was read from the log, as in the sections above. The counters
behind it reset about every 1 s, and the line is printed about every 5 s. So each line is the average
of the roughly 1 s interval before it, sampled every 5 s, and "worst" below means the worst sampled
interval average, not the worst single frame. The scene
starts at the first line of the playable cell scene, which comes after the start screens and the opening
cutscene. Both runs were stopped by closing the window, after about 230 s of scene (cold) and about
205 s (warm). To compare windows of equal length, the table covers the first 200 s of scene, and a second
row in each pair leaves out the first 30 s. Cold = `VICTORY_CACHE_DIR` deleted before launch. Warm = the
next launch with the same folder. The driver's own shader cache was not cleared.

| Run | Window | Lines | median ms/frame | p10–p90 | worst sampled interval | mean | lines > 100 ms | preparing | copies | copying back | waiting for the GPU | draws/frame |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| cold | 0–200 s | 39 | **61.2** (16.3 fps) | 54.4–70.2 | 301.5 | 74.3 | 3 | 55.4 | 15.1 | 22.9 | 0.1 | 3,735 |
| cold | 30–200 s | 33 | 59.1 | 54.4–66.3 | 76.1 | 60.1 | 0 | 53.7 | 14.5 | 23.0 | 0.2 | 3,548 |
| warm | 0–200 s | 39 | **59.6** (16.8 fps) | 53.3–69.4 | 171.2 | 64.1 | 2 | 53.7 | 13.5 | 21.5 | 0.0 | 3,563 |
| warm | 30–200 s | 33 | 59.0 | 53.2–69.4 | 106.3 | 61.1 | 1 | 53.5 | 12.3 | 21.4 | 0.0 | 3,423 |

Other observations from the same logs:

- **Launch to playable scene:** 128 s cold, 100 s warm. In the cold run, pipelines still being made
  peaked at 66 per line during the first 30 s of scene and dropped to 0–2 after that. In the warm run
  the count stayed at 0.
- **Warming removes stutter, not steady frame time.** The steady median is 59 ms either way. The warm
  cache takes away the cold run's first-minute spikes: the worst sampled interval average falls from 301 ms to
  171 ms, and the mean from 74 ms to 64 ms.
- **The card is mostly waiting on the submitting thread.** "Preparing" (about 54 ms, of which copies
  take 12–15 ms) is almost the whole frame time. "Waiting for the GPU" (the line's "on the GPU" field,
  which `host.rs` defines as time the CPU spends waiting for the GPU) reads 0.0–0.2 ms. The log's
  separate "the card's clock per frame" lines put queue occupancy at 43–46 % (median per line) in the
  scene. They show about 32–34 ms per frame with nothing of ours queued, almost all of it "while the
  submitting thread was working", and the submitting thread waits 0.0 ms for the card (median).
  These counts measure queue occupancy, not GPU load. No other memory settings were tried here.
- **Card-side copies** ("host copies in the card's memory") were 808–832 MB with `CARD_BUFFERS_MB=512`
  and `CARD_WINDOWS_MB=256`.
- **Peak process memory:** 17–20 GB working set and 24–27 GB private. There was no `0x8007000E`, no
  os error 1450, no pause warning, and no stop before the window was closed.
- **Dropped work:** about 2,600 per frame dropped as "a stage of the ray-tracing structure builder,
  which is off", as expected with `VICTORY_AMBIENT`. The frame line reports 320–370 dropped without a
  host pipeline.
- **Picture:** heads and hair were drawn in both runs (see the README's known defect, which reports
  them missing in most Linux runs). Frosted window glass renders as coarse blotches rather than a
  smooth blur.

**Windows build note:** `scripts\build.ps1` stops at its first line of cargo output under Windows
PowerShell 5.1 (the `powershell` that ships with Windows). The error is `NativeCommandError` on
"Compiling proc-macro2", because of `$ErrorActionPreference = 'Stop'` together with redirected native
stderr. It builds fine under PowerShell 7: `pwsh -File scripts\build.ps1`.
