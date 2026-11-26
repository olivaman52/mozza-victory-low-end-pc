# run.ps1 -Exe <victory.exe> -Game <your own copy's executable> [-Console series-s] [-MipDrop 1] [-KeepEnv]
# Starts the title on Windows with the settings measured in RESULTS.md (the same values as settings.env).
# NOT TESTED ON WINDOWS BY US: every measurement of this repository was made under Linux/Wine.
# Every VICTORY_* variable already in your environment is cleared first (except the path variables
# VICTORY_CONFIG, VICTORY_GAME_DIR, VICTORY_CACHE_DIR, VICTORY_DATA_DIR), so that a value left over
# from another fork's guide cannot replace a measured one. -KeepEnv keeps them (they then win over
# the values below) and lists every one that differs from the measured value.
# Run it from a normal PowerShell window, not as administrator, or through run.cmd beside it.
param(
    [Parameter(Mandatory)][string]$Exe,
    [Parameter(Mandatory)][string]$Game,
    [ValidateSet('series-s', 'series-x')][string]$Console = 'series-s',
    [ValidateRange(0, 3)][int]$MipDrop = 1,
    [string]$Log = 'info',
    [switch]$KeepEnv
)
$settings = [ordered]@{
    # Memory placement: the three settings behind the step from about 280 to about 100 ms per frame on a 6 GB card.
    # Measured on 6 GB: drop 1 with CARD_WINDOWS_MB=256. If video memory runs short, use -MipDrop 2 or 3.
    VICTORY_CARD_BUFFERS_MB     = '1024'
    VICTORY_CARD_WINDOWS_MB     = '256'
    VICTORY_TEXTURE_MIP_DROP    = "$MipDrop"
    VICTORY_LEVELS_ON_DEMAND    = '0'
    VICTORY_CARD_BUFFERS_MIN_KB = '64'
    # The fork's stand-in for ray-traced light (a skip: lighting is approximate).
    VICTORY_AMBIENT             = '0.8'
    VICTORY_AMBIENT_AIR         = '1.5'
    # The fork's launcher settings (speed).
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
    # "info" prints the frame statistics line ("... fps, ... ms/frame (... preparing ...)") that RESULTS.md
    # quotes; it exists only in a build made with --features diagnostics (README, Windows, step 3).
    VICTORY_LOG                 = $Log
}
if (-not (Test-Path $Exe))  { Write-Host "No $Exe. Build it first (README.md, Windows)."; exit 2 }
if (-not (Test-Path $Game)) { Write-Host "No $Game. Pass the executable of your own copy of the title."; exit 2 }
$paths = 'VICTORY_CONFIG', 'VICTORY_GAME_DIR', 'VICTORY_CACHE_DIR', 'VICTORY_DATA_DIR'
if (-not $KeepEnv) {
    Get-ChildItem Env:VICTORY_* | Where-Object { $_.Name -notin $paths } | ForEach-Object { Remove-Item "Env:$($_.Name)" }
}
foreach ($k in $settings.Keys) {
    if (-not (Test-Path "Env:$k")) { Set-Item "Env:$k" $settings[$k] }
}
# What the title will run with: every VICTORY_* variable, and a warning for each one that differs from
# the measured value (possible only with -KeepEnv).
$differ = @()
foreach ($k in $settings.Keys) {
    $now = (Get-Item "Env:$k").Value
    if ($now -ne $settings[$k]) { $differ += "$k=$now (measured: $($settings[$k]))" }
}
Write-Host "victory-gtx1660: settings in effect:"
Get-ChildItem Env:VICTORY_* | Sort-Object Name | ForEach-Object { Write-Host "  $($_.Name)=$($_.Value)" }
if ($differ.Count -gt 0) {
    Write-Host "victory-gtx1660: WARNING, these differ from the measured configuration:" -ForegroundColor Yellow
    $differ | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
}
$Exe = (Resolve-Path $Exe).Path
$Game = (Resolve-Path $Game).Path
Push-Location (Split-Path $Exe)
try { & $Exe run $Game --execute --console $Console } finally { Pop-Location }
exit $LASTEXITCODE
