# NOTES — "no shared buffer" 0x8007000E OOM

## Status
FIX APPLIED, committed, pushed, and build-verified (cargo check clean).

- Commit: `bc37f3a` — "Cap staging pool idle retention at STAGING_KEPT, gate on commit headroom"
- Branch: `main`, pushed to `origin/main`
- Verified: `cargo check -p victory --target x86_64-pc-windows-msvc --features diagnostics` → Finished, no errors (only pre-existing unrelated warnings)

## Evidence from the log (read via extracted files only)
- 3909 matches of `0x8007000E`; the first is a "no unordered-access buffer" (24 MB), then a sustained burst of **"no shared buffer"** warnings, every one at `size=4194304` (4 MB), starting ~12:54:21 and running for ~2 seconds straight (log-tail.txt). The run then dies.
- `log-tail.txt` (final frames): only `victory_gpu::host` "no shared buffer" warnings at 4 MB, plus pipeline refusals — nothing else is being logged, i.e. allocation is completely wedged.
- `memory-trend.txt` / `refresh()` warn line (frame 11): `physical_free_mib=5361 available_commit_mib=1047` — commit headroom is already down to ~1 GiB early while physical RAM is plentiful, and it depletes from there. Private memory 5.4 GB → 7.7 GB; VRAM only ~32% used (1658/5233 MB). **VRAM is not the bottleneck; PC system memory / commit is.**

## Root cause (fixed)
`cool_fox/crates/victory-gpu/src/pool.rs`:
- `pool.rs:30` `const BLOCK: u64 = 64 << 20;` — blocks are 64 MiB.
- `pool.rs:34` `const SPARE_KEPT: usize = 64;` — up to 64 empty blocks kept = **4 GiB held idle**.
- `pool.rs:44-64` `room()`: `limit = spares(memory, keep_freed() && !pressure)` returns `SPARE_KEPT` (64) whenever VRAM use is under 85 % (`pool.rs:68`). That same `limit` was applied to the **STAGING** pool (`pool.rs:54-63`, `staging_limit = limit` when not critical/pressured).

STAGING blocks are `Upload` resources — mapped system-RAM upload buffers (PC memory/commit), not VRAM. Because the card's VRAM is only ~32% used (< 85 %), `room()` let the staging pool retain ~4 GiB of **idle PC-memory upload buffers**. Together with the measured 1024+768 MB card-copy reservation and private-memory growth (5.4→7.7 GB), Windows commit headroom (already ~1 GiB at frame 11) was exhausted, so each 4 MB "no shared buffer" allocation failed with `0x8007000E`.

Contributing: `cool_fox/crates/victory-gpu/src/host.rs:374-401` `ram_idle_ms()` only relaxed RAM-cache retention below 2 GiB free physical / 4 GiB; it did not react to commit headroom, so the 4 GiB of idle staging stayed committed long past the point Windows could spare it.

## Fix applied
`cool_fox/crates/victory-gpu/src/pool.rs` (`room()`):
- The STAGING pool no longer inherits `SPARE_KEPT` (64 blocks = 4 GiB) based on VRAM usage.
- `staging_limit` now caps at `STAGING_KEPT` (8 blocks = 512 MiB), drops to half that (`STAGING_KEPT / 2` = 256 MiB) when commit headroom is under 2 GiB, and stays at 0/1 under critical commit or pressure as before.
- `SPARE_KEPT=64` is kept only for the VRAM-backed TEXTURES pool (unchanged).

`cool_fox/crates/victory-gpu/src/host.rs` (`ram_idle_ms()`):
- Added `COMMIT_SCARCE_BYTES` (2 GiB): when available commit is under 2 GiB, RAM caches (staging buffers, loose shadows, mapped pipeline library) use their shortest idle timeout (2000 ms) even if physical RAM is plentiful, so idle system memory is returned before commit is exhausted.

Files: `cool_fox/crates/victory-gpu/src/pool.rs` (primary), `cool_fox/crates/victory-gpu/src/host.rs` (ram_idle_ms).

## Addendum — 2026-11-26, user-provided settings + VICTORY_STAGING_KEPT

New run (victory-run3.log) still hit one `0x8007000E` OOM at line 58531 ("no host list for a state prelude"), with private memory climbing to ~15.7 GB and preludes growing from 126 → 876. Commit headroom (15,160 MiB available at start) was exhausted before critical-commit gating could release idle staging blocks.

Applied user settings to `scripts/run-test.ps1` and `scripts/settings.env`:
- `VICTORY_CARD_BUFFERS_MB=1024`, `VICTORY_LEVELS_ON_DEMAND=1`, `VICTORY_RAW_VIEWS=0`,
  `VICTORY_GROUP_SYNC=2`, `VICTORY_WAVE_LOCAL=idiom`, `VICTORY_WAVE_WIDE=`,
  `VICTORY_PIPELINE_BOOK=1`, `VICTORY_CARD_BUFFERS_MIN_KB=64`, `VICTORY_STAGING_KEPT=4`.

`cool_fox/crates/victory-gpu/src/pool.rs`: added `VICTORY_STAGING_KEPT` env var to override the
hard-coded `STAGING_KEPT = 8` idle staging blocks (each 64 MiB of PC commit memory). Default remains 8;
`run-test.ps1` now sets 4 to free ~256 MiB of commit earlier, before headroom is exhausted.

## Addendum — 2026-11-27, launch scripts now default to low-memory OOM-safe settings

`launch.ps1` and `timed-run.ps1` now default to the OOM-mitigation profile
(previously applied manually):

- `VICTORY_CARD_BUFFERS_MB=512` (was 1024)
- `VICTORY_TEXTURE_MIP_DROP=3` (was 1)
- `VICTORY_STAGING_KEPT=4`
- `VICTORY_MAX_PRELUDES=32`

These stop the `0x8007000E` OOM crashes where private memory climbed from
~6 GB to ~17 GB and Windows commit headroom was exhausted. The sharper-texture
measured profile (`CARD_BUFFERS_MB=1024`, `MipDrop=1`) is still available
via `-KeepEnv` overrides before launch.

To use the sharper profile manually:

```powershell
$env:VICTORY_CARD_BUFFERS_MB = '1024'
$env:VICTORY_CARD_WINDOWS_MB = '256'
$env:VICTORY_TEXTURE_MIP_DROP = '1'
$env:VICTORY_LEVELS_ON_DEMAND = '1'
$env:VICTORY_STAGING_KEPT = '2'
$env:VICTORY_MAX_PRELUDES = '16'

.\scripts\run.cmd -Exe .\cool_fox\target\x86_64-pc-windows-msvc\release\victory.exe -Game "D:\path\to\your\copy\<its executable>" -KeepEnv
```

New run (victory-run3.log) still hit one `0x8007000E` OOM at line 58531 ("no host list for a state prelude"), with private memory climbing to ~15.7 GB and preludes growing from 126 → 876 (~4.4 GB of commit memory). Commit headroom was exhausted before critical-commit gating could release idle staging blocks — per-host-list preludes were the main remaining commit consumer.

`cool_fox/crates/victory-gpu/src/host.rs`: added prelude pooling.
- `PRELUDE_IDLE`: a static pool of free preludes (allocator + closed list). Used preludes go back here when their `HostList` is dropped (via `PreludeSlot::Drop`), instead of being released.
- `make_prelude()` draws from `PRELUDE_IDLE` before creating a new allocator/list, so a prelude is reused across many lists instead of each list growing its own forever.
- `VICTORY_MAX_PRELUDES` env var caps idle preludes kept (default 64; 0: none kept). `PreludeSlot::Drop` only returns a prelude to the pool while `idle.len() < max_preludes()`; above that the prelude is released and its ~5 MB of commit is reclaimed.

Preludes were created on demand and never recycled: every list that ever needed texture transitions owned one prelude for its whole life. With ~630+ lists, that is thousands of allocator+list objects (~5 MB each) all committed at once — exactly the 126→876 growth and ~4.4 GB of commit memory that exhausted Windows commit headroom before OOM. CardWork preludes (sync/check/fetch) were already recycled via `card_done()`; this brings per-list preludes in line.
