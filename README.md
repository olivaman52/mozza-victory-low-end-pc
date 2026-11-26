# victory-gtx1660

Patches, settings and launch scripts that took a console title from about
360–410 ms per frame to about 100–106 ms per frame (about 10 fps) on our
test machine under Linux, on top of the public fork
[codec-d/cool_fox](https://github.com/codec-d/cool_fox) at commit
`f4b48ad766ddbec1a1867022cd42f7645b0dd55e`.

Jump to: [Results](#results) · [Linux](#how-to-reproduce-on-linux) · [Windows](#how-to-reproduce-on-windows) · [Known defects](#known-defects-in-this-configuration)

## What this is and is not

- It is the cool_fox fork source (`cool_fox/`), already carrying patches
  0001–0002, plus the remaining patches (`patches/`), a settings file and
  launch scripts for Linux and Windows (`scripts/`), and the measurements
  behind them (`RESULTS.md`). Clone this repository alone and nothing else
  needs downloading — not the fork, not any patch — except the game title.
- It contains **no game files, code, assets, captures or logs**. You need your
  own copy of the title.
- It is not affiliated with or endorsed by the title's developer or publisher,
  nor by the authors of VIctory or cool_fox.
- One machine, a handful of runs: the ~100 ms figure comes from **five clean
  runs** of 4 to 8 minutes of scene each.

## Results

First playable scene, console profile "Series S". Frame time = the median of
the fork's own frame statistics line over the steady scene (not an external
tool). Details per run in [RESULTS.md](RESULTS.md).

| Configuration | ms per frame | fps | Runs |
|---|---|---|---|
| cool_fox `f4b48ad`, unmodified, its launcher's settings | 360–410 | 2.4–2.8 | 1 (15 min) |
| + patches 0001–0002, `LEVELS_ON_DEMAND=0`, `TEXTURE_MIP_DROP=2` | 271–291 | 3.4–3.7 | 5 (7–15 min each) |
| + `CARD_BUFFERS_MB=1024`, `CARD_WINDOWS_MB=256`, `TEXTURE_MIP_DROP=1` (**current settings**: sharper textures, same speed) | 98–112 | 9–10 | 5 (4.5–6 min of scene each; medians 98, 112.2, 101.9, 106, 107.7), all clean |
| the same with `CARD_WINDOWS_MB=768`, `TEXTURE_MIP_DROP=3` (first settings found) | 100–106 | 9.4–9.9 | 5 (4–8 min of scene each; medians 102.5, 100.6, 104.3, 106.4, 101.4), all clean |

Machine: our test machine — Core i7-13700KF, 62 GB RAM, Arch Linux (kernel 6.18
LTS), NVIDIA driver 620.73.04 (open kernel modules rebuilt with NVIDIA's
[PR #1542](https://github.com/NVIDIA/open-gpu-kernel-modules/pull/1542) against
random soft lockups, issue #1540), Wine from GE-Proton11-6 with vkd3d-proton
from Proton Experimental, Microsoft's `d3dcompiler_47.dll` in the prefix.

The last step moves memory, it does not skip work: copies of the title's
buffers and memory windows are kept in the card's memory instead of the PC's,
and texture copies start one mip level further down so that this fits in the
card's memory.

## Known defects (in this configuration)

- **Cards with less than the measured card's memory are below what was measured.** The memory settings reserve about 1.8 GB of video memory for copies of the title's buffers on top of textures; on the measured card that just fits (one texture level
  sharper already costs 15 %). On a 4 GB card they overflow: one user reports
  about 3 fps and a black picture. Untested starting point for 4 GB:
  `VICTORY_TEXTURE_MIP_DROP=3`, `VICTORY_CARD_BUFFERS_MB=1024`,
  `VICTORY_CARD_WINDOWS_MB=256` (set them before launching; on Windows add
  `-KeepEnv` to `run.cmd`). With 8 GB or more, try
  `VICTORY_TEXTURE_MIP_DROP=0`. **Do not lower `VICTORY_CARD_BUFFERS_MB` below
  1024**: measured here, 768 or 640 loses the whole gain (back to about
  275 ms per frame), and raising it to 1280–1536 gains nothing; a larger
  `VICTORY_CARD_WINDOWS_MB` did not help either (768: about 3–5 ms slower than
  256 in runs of equal length).

- **Only the first playable scene was measured.** Nothing later in the title
  (open areas, driving, streets with traffic) has been run by us: expect it to
  be slower there, as the fork's own README reports for its author's card, and
  it may show defects we have not seen (a black picture was reported by one
  user in an open area).

- **Characters' heads are missing in most runs** (about 13 of 15): the head
  geometry never reaches the picture and the hair is deformed, from the first
  seconds of the scene to the end of the run; in the other runs heads and hair
  are correct with the same build and settings. The same defect is seen with
  unmodified cool_fox on this machine; not seen with the older tree. Cause not
  found yet. Ruled out: texture settings, the speed settings, mesh output
  limits, the integer buffer view path (`patches/optional/0007`).
- **Ray-traced lighting is not computed**: the fork's ambient-light stand-in
  (`VICTORY_AMBIENT`) replaces it, so lighting and shadows are approximate.
- **Textures start one mip level down** (`VICTORY_TEXTURE_MIP_DROP=1`; with 3 they are visibly softer; 0 does not fit next to the buffer copies on the measured card) — compare with drop 2
  (which gives the 271–291 ms row).
- **The start screen was not passed with the monitors awake** on this setup
  (unexplained). The runs were made with the screens put to sleep with DPMS
  (`scripts/dpms.sh`, `DPMS=1` for `run.sh`).

## Patches

| File | What it does | Author |
|---|---|---|
| `0001` | Shader translation: every loop gets one branch back. vkd3d-proton's DXIL-to-SPIR-V converter recursed until a stack overflow on loops with several back edges, killing pipeline worker threads. | Impre-visible |
| `0002` | `VICTORY_TEXTURE_MIP_DROP=0..3`: host copies of large placed textures start that many levels down (off by default). | port by Impre-visible, idea and original code by antikohza |
| `optional/0003` | Diagnostics: viewport size census with `VICTORY_CARD_SPANS=1`. | Impre-visible |
| `optional/0004` | `VICTORY_CARD_AWAKE=idle`: keep the clocks up only while the card is idle. | Impre-visible |
| `optional/0006` | Diagnostics: pipelines left out on purpose are reported as such. | Impre-visible |
| `optional/0007` | `VICTORY_VIEW_INTEGER=0`: diagnostic switch for typed integer buffer views. | Impre-visible |

The optional patches change nothing unless their switch is set. None of them
was switched on in the measured runs.

## How to reproduce on Linux

You need: your own copy of the title, a Linux PC with a recent NVIDIA driver,
a Proton build, `bubblewrap`, systemd (for the memory cap), and to build:
the Rust toolchain pinned by cool_fox with the `x86_64-pc-windows-msvc` target,
`clang`, `lld`, `llvm` and [xwin](https://github.com/Jake-Shadle/xwin).

1. Build (cross-build from Linux; `xwin splat --use-winsysroot-style` once
   for the Windows SDK, accepting its licence). The vendored `cool_fox/`
   tree already carries patches 0001–0002, so nothing needs cloning or
   `git am`-ing — just this repository:
   ```sh
   XWIN_DIR=/path/to/xwin-splat scripts/build.sh
   ```
   The result is `cool_fox/target/x86_64-pc-windows-msvc/release/victory.exe`.
   Optional patches (`patches/optional/`, diagnostics and experiments) can be
   applied on top with `git apply` inside `cool_fox/` if you want them:
   ```sh
   cd cool_fox && git apply ../patches/optional/0003-*.patch && cd ..
   ```
2. Prepare a Wine prefix: copy `d3d12.dll` and `d3d12core.dll` from
   vkd3d-proton (we used the one shipped with Proton Experimental) and
   `dxgi.dll` from DXVK into its `system32`, and install Microsoft's
   `d3dcompiler_47.dll` (`winetricks d3dcompiler_47`); without it the
   fork's indirect-argument clamp shader does not compile under Wine and
   indirect draws are dropped.
3. Run with the settings of `scripts/settings.env`:
   ```sh
   VICTORY_EXE=$PWD/cool_fox/target/x86_64-pc-windows-msvc/release/victory.exe \
   GAME_EXE=/path/to/your/own/copy/<its executable> \
   PROTON_DIR=/path/to/GE-Proton11-6/files \
   WINEPREFIX=/path/to/prefix WORK_DIR=/path/to/workdir DPMS=1 \
   scripts/run.sh 600
   ```
   The run is sandboxed (no network, read-only system except `WORK_DIR` and
   the prefix). The log goes to `WORK_DIR/logs/`; at the end the script prints
   the median of the last 40 frame statistics lines. The first run translates
   every shader and is much slower; measure on later runs.

## How to reproduce on Windows

**Not tested by us**: all our runs were under Linux.

> **The patches alone do not give the ~100 ms figure.** Most of the gain comes
> from three settings (`VICTORY_CARD_BUFFERS_MB` above all, with `VICTORY_CARD_WINDOWS_MB=256`,
> `VICTORY_TEXTURE_MIP_DROP=1` and `VICTORY_LEVELS_ON_DEMAND=0`). Start the
> title **only with `scripts\run.cmd` (or `run.ps1`)**. Starting `victory.exe`
> yourself, or cool_fox's own `Play-VIctory.cmd`, runs without them
> (`Play-VIctory.cmd` also sets `VICTORY_LEVELS_ON_DEMAND=1`): that is the
> 271–291 ms (about 3.5 fps) or 360–410 ms (about 2.5 fps) row of the table
> above, not the 100 ms one.

> **Reported problem on Windows with GTX 16 / RTX 20 cards (Turing):** a tester
> with a GTX 1660 SUPER on Windows 11 reports that the fork does not get past
> the start screens there with NVIDIA's driver, while it does with the software
> adapter and under Linux
> ([report](https://github.com/Marvisak/VIctory/issues/2835#issuecomment-7188866396)).
> If you have such a card on Windows, expect this; on newer cards it is not
> reported.

With that said: cool_fox itself is developed and played on Windows, and the
patches and settings are the same there, so this should work, but the figures
above are Linux figures. The texture and memory settings matter most on
memory-constrained cards.

### What you need

- Windows 10/11 x64
- Your own copy of the title (this repo contains **no game files**)
- A Direct3D 12 card with a recent driver
- [Git for Windows](https://git-scm.com/download/win)
- [Rust](https://rustup.rs) (the toolchain is pinned by the fork and installs itself)
- Visual Studio Build Tools with **"Desktop development with C++"** and a Windows SDK

### Step 1 — Clone the repository

```powershell
git clone https://github.com/WASDeKeys/victory-gtx1660
cd victory-gtx1660
```

The vendored `cool_fox/` tree already carries patches 0001–0002, so nothing
needs cloning or `git am`-ing besides this repository.

Optional patches (`patches/optional/`, diagnostics and experiments) can be
applied on top if you want them:

```powershell
cd cool_fox; git apply ..\patches\optional\0003-*.patch; cd ..
```

### Step 2 — Build victory.exe

From inside the repo folder:

```powershell
.\scripts\build.ps1
```

This runs `cargo build` inside `cool_fox/` with the diagnostics feature (it
prints the frame statistics line used to measure; without it there is no such
line in the log).

First build: **10–20 minutes**. Later builds are much faster.

When it finishes, the result is:

```
cool_fox\target\x86_64-pc-windows-msvc\release\victory.exe
```

Verify it exists:

```powershell
ls cool_fox\target\x86_64-pc-windows-msvc\release\victory.exe
```

### Step 3 — Run the game

Launch **only** through `scripts\run.cmd` (or `run.ps1`) so the memory
settings are applied. Starting `victory.exe` yourself, or cool_fox's own
`Play-VIctory.cmd`, runs without them.

```powershell
.\scripts\run.cmd -Exe .\cool_fox\target\x86_64-pc-windows-msvc\release\victory.exe -Game "D:\path\to\your\copy\<its executable>"
```

Replace `D:\path\to\your\copy\<its executable>` with the real path to your
game's `.exe`. Keep the quotes if the path has spaces.

The script clears leftover `VICTORY_*` variables, applies the settings, and
prints `victory-gtx1660: settings in effect:` with every value. Check this
list before comparing frame rates.

### Step 4 — Expect the first run to be slow

The first run translates every shader and compiles pipelines: expect several
slow minutes and stutter. **Judge the speed on the second run or later**,
when caches are warm. The fork keeps its caches under
`%LOCALAPPDATA%\victory\cache` unless `VICTORY_CACHE_DIR` is set (see
`victory.example.toml` in the fork).

### Tuning for mid-range and laptop cards

The measured settings were tuned for a GTX 1660 6 GB desktop under Linux.
On Windows, especially on 6 GB laptop cards, you may hit "Insufficient
system resources" (os error 1450) or stutter. The launcher now defaults to
lower-memory values (`CARD_BUFFERS_MB=512`, `MipDrop=3`, `LEVELS_ON_DEMAND=1`).

If you still have problems, set these before launching:

```powershell
$env:VICTORY_CARD_BUFFERS_MB = '512'
$env:VICTORY_CARD_WINDOWS_MB = '256'
$env:VICTORY_TEXTURE_MIP_DROP = '3'
$env:VICTORY_LEVELS_ON_DEMAND = '1'
$env:VICTORY_STAGING_KEPT = '4'
$env:VICTORY_MAX_PRELUDES = '32'

.\scripts\run.cmd -Exe .\cool_fox\target\x86_64-pc-windows-msvc\release\victory.exe -Game "D:\path\to\your\copy\<its executable>" -KeepEnv
```

`-KeepEnv` keeps the variables you set instead of letting the script clear
them. If video memory runs short (stutter, textures missing), try
`-MipDrop 2` or `-MipDrop 3`. `-Console series-x` selects the larger console
profile (slower).

### Windows OOM mitigation (not measured by us)

A Windows run hit `0x8007000E` OOM ("no host list for a state prelude") with
private memory climbing to ~15.7 GB and commit headroom exhausted. The
following overrides reduce commit pressure:

| Variable | Value | Purpose |
|---|---|---|
| `VICTORY_CARD_BUFFERS_MB` | `512` | Card-side buffer copy cap (lowered from measured 1024 for mid-range cards) |
| `VICTORY_CARD_BUFFERS_MIN_KB` | `64` | Pool every title buffer, no minimum skip |
| `VICTORY_LEVELS_ON_DEMAND` | `1` | Textures made level by level on demand |
| `VICTORY_RAW_VIEWS` | `0` | Raw views off |
| `VICTORY_GROUP_SYNC` | `2` | Group sync level |
| `VICTORY_WAVE_LOCAL` | `idiom` | Wave local mode |
| `VICTORY_WAVE_WIDE` | `` (empty) | Wave wide mode off |
| `VICTORY_PIPELINE_BOOK` | `1` | Pipeline book enabled |
| `VICTORY_STAGING_KEPT` | `4` | Idle staging blocks kept (default 8; frees ~256 MiB commit) |
| `VICTORY_MAX_PRELUDES` | `32` | Idle preludes kept (default 64; each ~5 MB commit; 0 keeps none) |

`VICTORY_STAGING_KEPT` overrides the hard-coded `STAGING_KEPT = 8` idle
staging blocks (each 64 MiB of PC commit memory). Cutting to 4 frees ~256 MiB
earlier.

`VICTORY_MAX_PRELUDES` caps idle preludes kept (default 64). Each prelude is
one command allocator plus one closed command list — about 5 MB of PC commit
memory. Used preludes now go back to a pool (`PRELUDE_IDLE`) and are reused;
`PreludeSlot::Drop` returns a prelude to the pool while idle count is under
`VICTORY_MAX_PRELUDES`, above that it is released.

### How to compare frame rates with ours

Our figures are the median of the log's frame statistics line
(`... fps, ... ms/frame (... preparing ...)`, diagnostics build,
`VICTORY_LOG=info`, which `run.ps1` sets) over the steady first scene, Series
S profile, second run or later (warm caches), with no frame generation.

A figure from another fork is often taken differently: some use the Series X
profile with a capped output resolution (`VICTORY_RESOLUTION=1920x1080`),
a lower render scale, skipped ray-tracing passes, a window-title counter, or
a driver's frame generation (which doubles what you see, not what the game
computes). Compare like with like.

### Whether the memory settings took effect

Shows in the same log (diagnostics build): the line
"host copies in the card's memory: N copies X MB ..." should read about
1,000 MB or more once the scene runs. Copies go to the card only while a
fifth of the card's memory budget is free; on Windows that budget is what the
system grants this process (other programs and the desktop take their share),
so fewer copies may fit than under Linux. If X stays near 500 MB, close other
programs that use the GPU or try `-MipDrop 3`.

If something goes wrong, compare with the fork's own launcher
(`Play-VIctory.cmd` in cool_fox) to tell a problem of these patches from one
of the fork.

## Credits

- [VIctory](https://github.com/Marvisak/VIctory) by Marvisak and its
  contributors: the compatibility layer itself.
- [codec-d/cool_fox](https://github.com/codec-d/cool_fox) by codec_d: the fork
  these patches apply to, and its launcher's settings.
- [avatarmanz/VIctory-7900XTX](https://github.com/avatarmanz/VIctory-7900XTX):
  the tree cool_fox derives from.
- [fxceless/victory-fork](https://github.com/fxceless/victory-fork): the fork
  that one started from.
- antikohza: the texture mip drop (ztrx PR #84, after Marvisak/VIctory#2146),
  ported here in patch 0002.
- The patches were written with [Claude Code](https://claude.com/claude-code).

## Licence

GPL-3.0-or-later, as VIctory and cool_fox; the patches are derived work of
cool_fox. See [LICENSE](LICENSE).
