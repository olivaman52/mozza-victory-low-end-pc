# run-test.ps1 — run the built victory.exe with measured GTX 1660 settings,
# then auto-extract only the important error parts via analyze-log.ps1.
#
# usage: .\scripts\run-test.ps1 -Game <path-to-your-game-exe>
#   optional: -Log <path-to-expected-log>   (default D:\victory-gtx1660\victory-run3.log)
#             -Console series-s|series-x    (default series-s)
#             -MipDrop 0..3                 (default 3)
#             -NoAnalyze                    (skip the auto analyze step)
#
# Requires pwsh (PowerShell). Runs from D:\victory-gtx1660.
# The binary must already be built (scripts/build.ps1 or cargo build --release).

param(
    [Parameter(Mandatory)][string]$Game,
    [string]$Log = 'D:\victory-gtx1660\victory-run3.log',
    [ValidateSet('series-s', 'series-x')][string]$Console = 'series-s',
    [ValidateRange(0, 3)][int]$MipDrop = 3,
    [switch]$NoAnalyze
)

$ErrorActionPreference = 'Stop'
$here = Split-Path $MyInvocation.MyCommand.Definition -Parent
$root = Resolve-Path (Join-Path $here '..')
$exe = Join-Path $root 'cool_fox\target\x86_64-pc-windows-msvc\release\victory.exe'

if (-not (Test-Path $exe)) {
    Write-Host "run-test.ps1: built binary not found: $exe"; exit 2
    Write-Host "  build it first:  .\scripts\build.ps1"
}
if (-not (Test-Path $Game)) {
    Write-Host "run-test.ps1: game executable not found: $Game"; exit 2
}

# Measured GTX 1660 settings (scripts/settings.env)
$settings = [ordered]@{
    VICTORY_CARD_BUFFERS_MB     = '1024'
    VICTORY_CARD_WINDOWS_MB     = '768'
    VICTORY_TEXTURE_MIP_DROP    = "$MipDrop"
    VICTORY_LEVELS_ON_DEMAND    = '0'
    VICTORY_CARD_BUFFERS_MIN_KB = '64'
    VICTORY_AMBIENT             = '0.8'
    VICTORY_AMBIENT_AIR         = '1.5'
    VICTORY_TEXTURE_NO_WAIT     = '1'
    VICTORY_RELAY               = '2'
    VICTORY_RELAY_COPY          = '1'
    VICTORY_WIDE_BACK           = '1'
    VICTORY_CARD_REHASH_RUNS    = '1'
    VICTORY_JOIN_COPIES         = '1'
    VICTORY_INDIRECT_WINDOW     = '1'
    VICTORY_INDIRECT_BATCH      = '2'
    VICTORY_CARD_STEPS          = '2'
    VICTORY_MAP_THREADS         = '1'
    VICTORY_CARD_AWAKE          = '1'
    VICTORY_SHOW_AFTER          = '1'
    VICTORY_UPLOAD_AHEAD        = '1'
    VICTORY_THIN                = '1'
    VICTORY_JOIN_PARTS          = '8'
    VICTORY_LOG                 = 'info'
}

foreach ($k in $settings.Keys) {
    if (-not (Test-Path "Env:$k")) { Set-Item "Env:$k" $settings[$k] }
}

Write-Host "run-test.ps1: settings in effect:"
Get-ChildItem Env:VICTORY_* | Sort-Object Name | ForEach-Object { Write-Host "  $($_.Name)=$($_.Value)" }

$Exe = (Resolve-Path $exe).Path
$Game = (Resolve-Path $Game).Path
Push-Location (Split-Path $Exe)
try {
    Write-Host "running: & $Exe run $Game --execute --console $Console"
    & $Exe run $Game --execute --console $Console
    $code = $LASTEXITCODE
} finally {
    Pop-Location
}
Write-Host "exit code: $code"

if (-not $NoAnalyze) {
    Write-Host ""
    Write-Host "=== auto-analyzing log: $Log ==="
    & (Join-Path $root 'scripts\analyze-log.ps1') -Log $Log
}

exit $code
