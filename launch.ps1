# WASDeKeys/victory-low-end-pc launcher — low-memory OOM-safe profile for 6 GB / low-RAM cards.
# Uses the vendored cool_fox diagnostics build and scripts\run.cmd.
# These settings reduce commit pressure so the 0x8007000E OOM crashes stop.
param(
    [string]$Game = 'USER_HOME\Downloads\LOCAL_TITLE-\game_scarlett_master.exe',
    [uint32]$CardBuffersMb = 512,
    [ValidateRange(0, 3)][int]$MipDrop = 3
)

$repo = $PSScriptRoot
$exe = Join-Path $repo 'cool_fox\target\x86_64-pc-windows-msvc\release\victory.exe'
if (-not (Test-Path $exe)) { Write-Error "No $exe. Run scripts\build.ps1 first."; return }
if (-not (Test-Path $Game)) { Write-Error "No $Game"; return }

# Low-memory OOM-safe configuration (README.md Windows OOM mitigation).
# CARD_BUFFERS_MB=512 instead of 1024 to keep commit headroom.
# TEXTURE_MIP_DROP=3 instead of 1 to keep texture copies small enough to fit.
$env:VICTORY_CARD_BUFFERS_MB     = [string]$CardBuffersMb
$env:VICTORY_CARD_WINDOWS_MB     = '256'
$env:VICTORY_TEXTURE_MIP_DROP    = [string]$MipDrop
$env:VICTORY_LEVELS_ON_DEMAND    = '1'
$env:VICTORY_CARD_BUFFERS_MIN_KB = '64'
$env:VICTORY_STAGING_KEPT        = '4'
$env:VICTORY_MAX_PRELUDES        = '32'
$env:VICTORY_AMBIENT             = '0.3'
$env:VICTORY_AMBIENT_AIR         = '1.5'
$env:VICTORY_TEXTURE_NO_WAIT     = '1'
$env:VICTORY_RELAY               = '2'
$env:VICTORY_RELAY_COPY          = '1'
$env:VICTORY_WIDE_BACK           = '1'
$env:VICTORY_CARD_REHASH_RUNS    = '1'
$env:VICTORY_JOIN_COPIES         = '1'
$env:VICTORY_INDIRECT_WINDOW     = '1'
$env:VICTORY_INDIRECT_BATCH      = '2'
$env:VICTORY_CARD_STEPS          = '2'
$env:VICTORY_MAP_THREADS         = '1'
$env:VICTORY_CARD_AWAKE          = '1'
$env:VICTORY_SHOW_AFTER          = '1'
$env:VICTORY_UPLOAD_AHEAD        = '1'
$env:VICTORY_THIN                = '1'
$env:VICTORY_JOIN_PARTS          = '8'
$env:VICTORY_LOG                 = 'info'
# User's NVIDIA shader settings.
$env:VICTORY_RAW_VIEWS      = '0'
$env:VICTORY_GROUP_SYNC     = '2'
$env:VICTORY_WAVE_LOCAL     = 'idiom'
Remove-Item Env:VICTORY_WAVE_WIDE -ErrorAction SilentlyContinue
$env:VICTORY_PIPELINE_BOOK = '1'
# Hands-off past the start screens (diagnostics build honours this).
$env:VICTORY_KEYS = '30:Enter,38:Enter,46:Enter,54:Enter,62:Enter,70:Enter,78:Enter,86:Enter'

& (Join-Path $repo 'scripts\run.cmd') -Exe $exe -Game $Game -Console series-s -MipDrop $MipDrop -KeepEnv
