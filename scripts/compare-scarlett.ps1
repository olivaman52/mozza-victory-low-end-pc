[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Exe,
    [Parameter(Mandatory)][string]$Game,
    [Parameter(Mandatory)][string]$Cache,
    [Parameter(Mandatory)][string]$Data,
    [Parameter(Mandatory)][string]$LogDirectory,
    [switch]$Cold,
    [switch]$RawFrameIntervals,
    [switch]$RenderDimensions,
    [switch]$ReadbackTrace,
    [switch]$SpansQuick,
    [switch]$DisableAmbientStandIn,
    [switch]$ClipGuestDescriptorReads,
    [ValidateRange(1,16)][int]$LandingThreads
)

$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).ProviderPath
$Game = (Resolve-Path -LiteralPath $Game).ProviderPath
$Data = (Resolve-Path -LiteralPath $Data).ProviderPath
if (Test-Path -LiteralPath $LogDirectory) { throw "Log directory already exists: $LogDirectory" }
if ($Cold -and (Test-Path -LiteralPath $Cache)) { throw "A cold run needs a fresh cache path: $Cache" }
if (-not $Cold -and -not (Test-Path -LiteralPath $Cache -PathType Container)) {
    throw "Warm cache not found: $Cache"
}
if (Get-Process -Name 'victory*' -ErrorAction SilentlyContinue) {
    throw 'A Victory session or test is already running.'
}
if (Get-Process -Name cargo,rustc,cl,link -ErrorAction SilentlyContinue) {
    throw 'A compiler, linker, or Cargo test is already running.'
}
New-Item -ItemType Directory -Path $LogDirectory | Out-Null
$settings = [ordered]@{
    VICTORY_CACHE_DIR = $Cache
    VICTORY_DATA_DIR = $Data
    VICTORY_DISPLAY_MODE = '1920x1080'
    VICTORY_CARD_BUFFERS_MB = '1024'
    VICTORY_CARD_WINDOWS_MB = '256'
    VICTORY_TEXTURE_MIP_DROP = '1'
    VICTORY_LEVELS_ON_DEMAND = '1'
    VICTORY_CARD_BUFFERS_MIN_KB = '64'
    VICTORY_STAGING_KEPT = '4'
    VICTORY_MAX_PRELUDES = '32'
    VICTORY_AMBIENT = '0.3'
    VICTORY_AMBIENT_AIR = '1.5'
    VICTORY_TEXTURE_NO_WAIT = '1'
    VICTORY_RELAY = '2'
    VICTORY_RELAY_COPY = '1'
    VICTORY_WIDE_BACK = '1'
    VICTORY_CARD_REHASH_RUNS = '1'
    VICTORY_JOIN_COPIES = '1'
    VICTORY_INDIRECT_WINDOW = '1'
    VICTORY_INDIRECT_BATCH = '2'
    VICTORY_CARD_STEPS = '2'
    VICTORY_MAP_THREADS = '1'
    VICTORY_CARD_AWAKE = '1'
    VICTORY_SHOW_AFTER = '1'
    VICTORY_UPLOAD_AHEAD = '1'
    VICTORY_THIN = '1'
    VICTORY_JOIN_PARTS = '8'
    VICTORY_LOG = 'info'
    VICTORY_LOG_SYNC = '1'
    VICTORY_PANEL = '1'
    VICTORY_RAW_VIEWS = '0'
    VICTORY_GROUP_SYNC = '2'
    VICTORY_WAVE_LOCAL = 'idiom'
    VICTORY_PIPELINE_BOOK = '1'
    VICTORY_KEYS = '30:Enter,38:Enter,46:Enter,54:Enter,62:Enter,70:Enter,78:Enter,86:Enter'
    VICTORY_WC_NO_BACK = '0'
    VICTORY_GPU_ONLY = '0'
    VICTORY_KNOWN_WRITES = '0'
    VICTORY_HEAP_PASS_MAX = '0'
    VICTORY_HEAP_CHANGED_MAX = '0'
}
if ($RawFrameIntervals) { $settings.VICTORY_RAW_FRAME_INTERVALS = '1' }
if ($RenderDimensions) { $settings.VICTORY_RENDER_DIMENSIONS = '1' }
if ($ReadbackTrace) { $settings.VICTORY_READBACK_TRACE = '1' }
if ($SpansQuick) { $settings.VICTORY_SPANS_QUICK = '1' }
if ($DisableAmbientStandIn) { $settings.VICTORY_AMBIENT = '0' }
if ($ClipGuestDescriptorReads) { $settings.VICTORY_HEAP_CLIP_READS = '1' }
if ($PSBoundParameters.ContainsKey('LandingThreads')) {
    $settings.VICTORY_LAND_THREADS = $LandingThreads.ToString([Globalization.CultureInfo]::InvariantCulture)
}

$start = [Diagnostics.ProcessStartInfo]::new()
$start.FileName = $Exe
$start.WorkingDirectory = Split-Path -Parent $Exe
$start.UseShellExecute = $false
foreach ($key in @($start.Environment.Keys)) {
    if ($key -like 'VICTORY_*') { $null = $start.Environment.Remove($key) }
}
foreach ($key in $settings.Keys) { $start.Environment[$key] = $settings[$key] }

$metadata = [ordered]@{
    started_utc = [DateTime]::UtcNow.ToString('O')
    binary = $Exe
    binary_sha256 = (Get-FileHash -LiteralPath $Exe).Hash
    mode = if ($Cold) { 'cold' } else { 'warm' }
    console = 'series-s'
    settings = $settings
}
$metadata | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $LogDirectory 'run.json')
$start.RedirectStandardOutput = $true
$start.RedirectStandardError = $true
$start.CreateNoWindow = $true
foreach ($argument in @('run', $Game, '--execute', '--console', 'series-s')) {
    $start.ArgumentList.Add($argument)
}
$process = [Diagnostics.Process]::Start($start)
$stdout = [IO.File]::Open((Join-Path $LogDirectory 'stdout.log'), 'CreateNew', 'Write', 'Read')
$stderr = [IO.File]::Open((Join-Path $LogDirectory 'game.log'), 'CreateNew', 'Write', 'Read')
try {
    $stdoutTask = $process.StandardOutput.BaseStream.CopyToAsync($stdout)
    $stderrTask = $process.StandardError.BaseStream.CopyToAsync($stderr)
    Write-Output "Victory PID $($process.Id). Log directory $LogDirectory"
    $process.WaitForExit()
    $null = $stdoutTask.GetAwaiter().GetResult()
    $null = $stderrTask.GetAwaiter().GetResult()
    $process.ExitCode | Set-Content -LiteralPath (Join-Path $LogDirectory 'exit-code.txt')
    exit $process.ExitCode
} finally {
    $stdout.Dispose()
    $stderr.Dispose()
    $process.Dispose()
}
