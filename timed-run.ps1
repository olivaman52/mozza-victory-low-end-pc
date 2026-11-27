# Prewarm shaders with a 6-minute timer and live %, then launch the title
# with NO run timer. Re-running prewarm skips shaders already in the cache.
param(
    [int]$WarmSeconds = 360,
    [int]$Jobs = 24,
    [Parameter(Mandatory)][string]$Game
)

$repo = $PSScriptRoot
$exe = Join-Path $repo 'cool_fox\target\x86_64-pc-windows-msvc\release\victory.exe'
$gameDir = Split-Path $game
$status = Join-Path $repo 'timed-status.txt'
$warmLog = Join-Path $repo 'timed-prewarm.log'
$runOut = Join-Path $repo 'timed-game.out.log'
$runErr = Join-Path $repo 'timed-game.err.log'
if (-not (Test-Path $exe)) { throw "No $exe" }
if (-not (Test-Path $game)) { throw "No $game" }
"INIT" | Set-Content -Encoding ascii $status

# Same settings as launch.ps1 (low-memory OOM-safe profile).
# CARD_BUFFERS_MB=512 and TEXTURE_MIP_DROP=3 to stop 0x8007000E OOM crashes.
$env:VICTORY_CARD_BUFFERS_MB     = '512'
$env:VICTORY_CARD_WINDOWS_MB     = '256'
$env:VICTORY_TEXTURE_MIP_DROP    = '3'
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
$env:VICTORY_RAW_VIEWS           = '0'
$env:VICTORY_GROUP_SYNC          = '2'
$env:VICTORY_WAVE_LOCAL          = 'idiom'
Remove-Item Env:VICTORY_WAVE_WIDE -ErrorAction SilentlyContinue
$env:VICTORY_PIPELINE_BOOK       = '1'
$env:VICTORY_KEYS                = '30:Enter,38:Enter,46:Enter,54:Enter,62:Enter,70:Enter,78:Enter,86:Enter'

# ---- 1. Prewarm shaders into the same cache the game uses ----
$env:VICTORY_WARM_SECONDS = "$WarmSeconds"
$env:VICTORY_HOST_WAVE = '32'
$env:VICTORY_HOST_MAX_WAVE = '32'
$warm = Start-Job -ScriptBlock {
    param($exe, $dir, $jobs, $log)
    & $exe translate $dir --warm all --jobs $jobs 2>&1 | Tee-Object -FilePath $log
} -ArgumentList $exe, $gameDir, $Jobs, $warmLog
$warmStart = Get-Date
while ($warm.State -in @('NotStarted', 'Running')) {
    $elapsed = [int]((Get-Date) - $warmStart).TotalSeconds
    $pct = [Math]::Min(100, [int](100 * $elapsed / $WarmSeconds))
    $remaining = [Math]::Max(0, $WarmSeconds - $elapsed)
    $last = ''
    if (Test-Path $warmLog) {
        $line = Get-Content $warmLog -Tail 1 -ErrorAction SilentlyContinue
        if ($line -match 'warm-up\s+(\d+)\s+shaders') { $last = " shader=$($Matches[1])" }
    }
    ("PREWARM {0}% | {1}s left |{2}" -f $pct, $remaining, $last) | Set-Content -Encoding ascii $status
    Start-Sleep -Seconds 1
}
Receive-Job -Job $warm | Out-File -FilePath $warmLog -Encoding utf8
Remove-Job -Job $warm -Force
Remove-Item Env:VICTORY_WARM_SECONDS -ErrorAction SilentlyContinue
"PREWARM 100% | done" | Set-Content -Encoding ascii $status

# ---- 2. Launch the title with NO timer (it runs until you close it) ----
Push-Location $repo
try {
    $p = Start-Process -FilePath $exe `
        -ArgumentList @('run', $game, '--execute', '--console', 'series-s') `
        -WorkingDirectory $repo `
        -RedirectStandardOutput $runOut -RedirectStandardError $runErr -PassThru
    ("GAME RUNNING (no timer) | victory PID {0}" -f $p.Id) | Set-Content -Encoding ascii $status
}
finally { Pop-Location }
