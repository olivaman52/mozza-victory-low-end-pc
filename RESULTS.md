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
