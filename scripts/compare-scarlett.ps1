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
    [switch]$RefreshCensus,
    [switch]$TraceRefreshLookup,
    [switch]$AheadIndex,
    [switch]$VerifyAheadIndex,
    [switch]$QuickTextureQueue,
    [string]$SourceRevision,
    [ValidateRange(0,180)][int[]]$SummaryMinutes,
    [ValidateRange(1,16)][int]$LandingThreads,
    [ValidateRange(64,1024)][int]$LandingJobKiB,
    [ValidateRange(1,1800)][int[]]$TimelineAtSeconds,
    [ValidateRange(1,8)][int]$TimelineFrames = 3
)

$ErrorActionPreference = 'Stop'
if ($VerifyAheadIndex -and -not $AheadIndex) { throw 'VerifyAheadIndex requires AheadIndex.' }
if ($TraceRefreshLookup -and -not $TimelineAtSeconds.Count) { throw 'TraceRefreshLookup requires TimelineAtSeconds.' }
if ($SummaryMinutes.Count -and -not $RawFrameIntervals) { throw 'SummaryMinutes requires RawFrameIntervals.' }
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
if ($RefreshCensus) { $settings.VICTORY_REFRESH_CENSUS = '1' }
if ($TraceRefreshLookup) { $settings.VICTORY_TRACE_REFRESH_LOOKUP = '1' }
if ($AheadIndex) { $settings.VICTORY_AHEAD_INDEX = '1' }
if ($VerifyAheadIndex) { $settings.VICTORY_AHEAD_INDEX_VERIFY = '1' }
if ($QuickTextureQueue) { $settings.VICTORY_TEXTURE_QUEUE_QUICK = '1' }
if ($PSBoundParameters.ContainsKey('LandingThreads')) {
    $settings.VICTORY_LAND_THREADS = $LandingThreads.ToString([Globalization.CultureInfo]::InvariantCulture)
}
if ($PSBoundParameters.ContainsKey('LandingJobKiB')) {
    $settings.VICTORY_LAND_JOB_KB = $LandingJobKiB.ToString([Globalization.CultureInfo]::InvariantCulture)
}
if ($PSBoundParameters.ContainsKey('TimelineAtSeconds')) {
    $timelinePath = Join-Path (Resolve-Path -LiteralPath $LogDirectory).ProviderPath 'timeline.json'
    $settings.VICTORY_TIMELINE = "$(($TimelineAtSeconds | Sort-Object -Unique) -join '+'),$TimelineFrames,$timelinePath"
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
    status = 'starting'
    pid = $null
    process_started_utc = $null
    finished_utc = $null
    exit_code = $null
    launcher_error = $null
    log = Join-Path $LogDirectory 'game.log'
    binary = $Exe
    binary_sha256 = (Get-FileHash -LiteralPath $Exe).Hash
    mode = if ($Cold) { 'cold' } else { 'warm' }
    console = 'series-s'
    settings = $settings
    source_revision = $SourceRevision
    checkout_head_at_launch = (git -C $PSScriptRoot rev-parse HEAD)
    checkout_changes_at_launch = @(git -C $PSScriptRoot status --porcelain=v1)
    summary_minutes = @($SummaryMinutes | Sort-Object -Unique)
    expected_sample_end_utc = $null
}
$metadataPath = Join-Path (Resolve-Path -LiteralPath $LogDirectory).ProviderPath 'run.json'
function Write-RunMetadata {
    $pending = "$metadataPath.$([Guid]::NewGuid().ToString('N')).tmp"
    try {
        $metadata | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $pending
        [IO.File]::Move($pending, $metadataPath, $true)
    } finally {
        if ([IO.File]::Exists($pending)) { [IO.File]::Delete($pending) }
    }
}
Write-RunMetadata
$start.RedirectStandardOutput = $true
$start.RedirectStandardError = $true
$start.CreateNoWindow = $true
foreach ($argument in @('run', $Game, '--execute', '--console', 'series-s')) {
    $start.ArgumentList.Add($argument)
}
$process = $null
$stdout = $null
$stderr = $null
try {
    $stdout = [IO.File]::Open((Join-Path $LogDirectory 'stdout.log'), 'CreateNew', 'Write', 'Read')
    $stderr = [IO.File]::Open($metadata.log, 'CreateNew', 'Write', 'Read')
    $process = [Diagnostics.Process]::Start($start)
    $stdoutTask = $process.StandardOutput.BaseStream.CopyToAsync($stdout)
    $stderrTask = $process.StandardError.BaseStream.CopyToAsync($stderr)
    $metadata.status = 'running'
    $metadata.pid = $process.Id
    $metadata.process_started_utc = $process.StartTime.ToUniversalTime().ToString('O')
    if ($metadata.summary_minutes.Count) {
        $metadata.expected_sample_end_utc = $process.StartTime.ToUniversalTime().AddMinutes(1 + $metadata.summary_minutes[-1]).ToString('O')
    }
    Write-RunMetadata
    Write-Output "Victory PID $($process.Id). Log directory $LogDirectory"
    $process.WaitForExit()
    $metadata.status = 'draining'
    $metadata.exit_code = $process.ExitCode
    $metadata.finished_utc = $process.ExitTime.ToUniversalTime().ToString('O')
    Write-RunMetadata
    $null = $stdoutTask.GetAwaiter().GetResult()
    $null = $stderrTask.GetAwaiter().GetResult()
    $process.ExitCode | Set-Content -LiteralPath (Join-Path $LogDirectory 'exit-code.txt')
    $metadata.status = 'exited'
    Write-RunMetadata
    if ($metadata.summary_minutes.Count) {
        & (Join-Path $PSScriptRoot 'summarize-warmup.ps1') -Run $LogDirectory -Minutes $metadata.summary_minutes
    }
    exit $process.ExitCode
} catch {
    $metadata.launcher_error = $_.Exception.Message
    Write-RunMetadata
    throw
} finally {
    if ($stdout) { $stdout.Dispose() }
    if ($stderr) { $stderr.Dispose() }
    if ($process) { $process.Dispose() }
}
