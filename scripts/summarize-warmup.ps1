#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Run,
    [ValidateRange(0,180)][int[]]$Minutes = @(0,2,5,10,15,20,25,30),
    [string]$Activity
)

$ErrorActionPreference = 'Stop'
$receipt = Get-Content -LiteralPath (Join-Path $Run 'run.json') -Raw | ConvertFrom-Json -DateKind String
$started = [DateTimeOffset]::Parse($receipt.process_started_utc)
$log = Join-Path $Run 'game.log'
$activityRows = if ($Activity) { @(Get-Content -LiteralPath $Activity -Raw | ConvertFrom-Json -DateKind String) } else { @() }
$milestones = @($Minutes | Sort-Object -Unique)
$end = $started.AddMinutes(1 + $milestones[-1])
$lifecycle = [Collections.Generic.List[object]]::new()
$shaderEvents = [Collections.Generic.List[object]]::new()
$cacheEvents = [Collections.Generic.List[object]]::new()
$source = [IO.File]::Open($log, 'Open', 'Read', 'ReadWrite')
$reader = [IO.StreamReader]::new($source)
try {
    while ($null -ne ($line = $reader.ReadLine())) {
        if ($line -notmatch '^(?<time>\S+)\s+(?:INFO|WARN|ERROR)\s+(?<scope>victory_gpu::pipeline(?:::library)?|victory_hle::modules::lifecycle):\s+(?<message>.*)') { continue }
        $when = [DateTimeOffset]::Parse($Matches.time)
        $scope = $Matches.scope
        $message = $Matches.message
        if ($scope -eq 'victory_hle::modules::lifecycle') {
            if ($message -match 'window closed|suspending|did not finish|suspended|resum') {
                $lifecycle.Add([ordered]@{ utc = $when.ToString('o'); event = ($message -replace '\s+\w+=.*$','') })
            }
            continue
        }
        if ($message -match '^shader (translated|does not translate)') {
            $shaderEvents.Add([PSCustomObject]@{ at = $when; translated = $Matches[1] -eq 'translated' })
        } elseif ($message -match 'host pipeline library saved .*?\bmade=(\d+) loaded=(\d+)') {
            $cacheEvents.Add([PSCustomObject]@{ at = $when; made = [int]$Matches[1]; loaded = [int]$Matches[2] })
        }
    }
} finally {
    $reader.Dispose()
}

$windows = foreach ($minute in $milestones) {
    $from = $started.AddMinutes($minute)
    $to = $from.AddMinutes(1)
    $raw = & (Join-Path $PSScriptRoot 'measure-frames.ps1') -Log $log -From $from -To $to -Aggregate | ConvertFrom-Json
    $samples = @(& (Join-Path $PSScriptRoot 'measure-frames.ps1') -Log $log -From $from -To $to | ConvertFrom-Json -DateKind String)
    $settled = & (Join-Path $PSScriptRoot 'summarize-scarlett.ps1') -Log $log -Checkpoint $from -Seconds 60 | ConvertFrom-Json
    $shaderWindow = @($shaderEvents | Where-Object { $_.at -ge $from -and $_.at -lt $to })
    $activityWindow = @($activityRows | Where-Object { [DateTimeOffset]$_.timestamp -ge $from -and [DateTimeOffset]$_.timestamp -lt $to })
    $sampleIndex = 0
    $zeroBacklogCompletions = 0
    foreach ($completion in $shaderWindow) {
        if (-not $completion.translated) { continue }
        while ($sampleIndex -lt $samples.Count -and [DateTimeOffset]$samples[$sampleIndex].timestamp -lt $completion.at) {
            ++$sampleIndex
        }
        if ($sampleIndex -eq 0 -or $sampleIndex -ge $samples.Count) { continue }
        $before = $samples[$sampleIndex - 1]
        $after = $samples[$sampleIndex]
        $gap = [DateTimeOffset]$after.timestamp - [DateTimeOffset]$before.timestamp
        if ($gap.TotalSeconds -le 3 -and $before.compiling_pipelines -eq 0 -and $after.compiling_pipelines -eq 0) {
            ++$zeroBacklogCompletions
        }
    }
    $coverage = $raw.raw_samples * $raw.mean_ms / 1e3
    [ordered]@{
        minute = $minute
        from_utc = $from.ToString('o')
        measured_interval_seconds = $coverage
        complete = ($coverage -ge 57 -and $coverage -le 63 -and $raw.windows_without_raw_intervals -eq 0)
        accepted_present = $raw
        peak_pending_pipelines = ($samples | Measure-Object compiling_pipelines -Maximum).Maximum
        new_shader_translation_successes = @($shaderWindow | Where-Object translated).Count
        new_shader_translation_failures = @($shaderWindow | Where-Object { -not $_.translated }).Count
        shader_completions_between_zero_pending_samples = $zeroBacklogCompletions
        last_pipeline_library_save = ($cacheEvents | Where-Object { $_.at -lt $to } | Select-Object -Last 1)
        host_draws_mean = ($samples | Measure-Object draws -Average).Average
        host_dispatches_mean = ($samples | Measure-Object host_dispatches -Average).Average
        cpu_prepare_ms_mean = ($samples | Measure-Object cpu_prepare_ms -Average).Average
        missing_pipeline_operations_mean = ($samples | Measure-Object missing_pipeline_draws -Average).Average
        dropped_indirect_mean = ($samples | Measure-Object dropped_indirect -Average).Average
        readback_ms_mean = ($samples | Measure-Object readback_ms -Average).Average
        landing_ms_mean = ($settled.landing_windows | Measure-Object merge_ms -Average).Average
        descriptor_slot_ms_mean = ($settled.descriptor_windows | Measure-Object slots -Average).Average
        descriptor_close_wait_ms_mean = ($settled.descriptor_windows | Measure-Object close -Average).Average
        gpu_queue_idle_estimate_ms_mean = ($settled.queue_estimates | Measure-Object idle -Average).Average
        gpu_memory = ($settled.gpu_memory | Select-Object -Last 1)
        ram = ($settled.system_memory | Select-Object -Last 1)
        system_cpu_activity_mean = ($activityWindow | Measure-Object system_cpu -Average).Average
        peak_game_gpu_engine_activity_mean = ($activityWindow | ForEach-Object { $_.game_gpu_engines | Select-Object -First 1 } | Measure-Object CookedValue -Average).Average
        peak_other_gpu_engine_activity_mean = ($activityWindow | ForEach-Object { $_.other_gpu_engines | Select-Object -First 1 } | Measure-Object CookedValue -Average).Average
        activity_sample_count = $activityWindow.Count
    }
}
$completed = @($windows | Where-Object { $_.complete } | ForEach-Object { $_.minute })
$result = [ordered]@{
    binary_sha256 = $receipt.binary_sha256
    exit_code = $receipt.exit_code
    wrapper_status = $receipt.status
    launcher_error = $receipt.launcher_error
    actual_exit_utc = $receipt.finished_utc
    started_utc = $started.ToString('o')
    planned_end_utc = $end.ToString('o')
    planned_end_reached = $receipt.finished_utc -and [DateTimeOffset]$receipt.finished_utc -ge $end
    completed_windows_minutes = $completed
    unavailable_metrics = @('independent rendered/displayed FPS', 'instantaneous translation queue and active workers', 'independent GPU execution timestamps', 'shader cache hits and misses between reported events')
    lifecycle = $lifecycle
    windows = @($windows)
}
$path = Join-Path (Resolve-Path -LiteralPath $Run).ProviderPath 'warmup-summary.json'
$next = "$path.$([Guid]::NewGuid().ToString('N')).tmp"
try {
    $result | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $next
    [IO.File]::Move($next, $path, $true)
} finally {
    if ([IO.File]::Exists($next)) { [IO.File]::Delete($next) }
}
Write-Output $path
