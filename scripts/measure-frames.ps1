# Export metrics windows, or aggregate actual intervals from VICTORY_RAW_FRAME_INTERVALS=1.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Log,
    [DateTimeOffset]$From = [DateTimeOffset]::MinValue,
    [DateTimeOffset]$To = [DateTimeOffset]::MaxValue,
    [switch]$Aggregate
)

$ErrorActionPreference = 'Stop'
if ($To -le $From) { throw 'To must be later than From.' }
$culture = [Globalization.CultureInfo]::InvariantCulture
$fields = @(
    'samples', 'fps', 'p50_ms', 'p95_ms', 'p99_ms', 'cpu_prepare_ms',
    'gpu_wait_ms', 'buffer_upload_mb', 'texture_upload_mb', 'readback_ms',
    'readback_mb', 'draws', 'missing_pipeline_draws', 'dropped_indirect',
    'compiling_pipelines'
)
$pattern = '^(?<timestamp>\S+)\s+INFO\s+victory_gpu::frame_metrics:\s+present interval metrics\s+(?<values>.*)$'
$rawPattern = '^\S+\s+INFO\s+victory_gpu::frame_metrics:\s+raw presentation intervals\s+intervals_ms=(?<intervals>\[[^]]*\])$'
$raw = $null
$allIntervals = [Collections.Generic.List[double]]::new()
$windowsWithoutRaw = 0
$logFile = (Resolve-Path -LiteralPath $Log).ProviderPath
$stream = [IO.File]::Open($logFile, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
$reader = [IO.StreamReader]::new($stream)
try {
    $records = @(while ($null -ne ($line = $reader.ReadLine())) {
        if ($Aggregate -and $line -match $rawPattern) {
            # The presenter logs this immediately before the matching metrics window.
            $raw = $Matches.intervals
            continue
        }
        if ($line -notmatch $pattern) { continue }
        $record = [ordered]@{ timestamp = $Matches.timestamp }
        $values = $Matches.values
        $rawWindow = $raw
        $raw = $null
        $timestamp = [DateTimeOffset]::Parse($record.timestamp, $culture)
        if ($timestamp -lt $From -or $timestamp -ge $To) { continue }
        foreach ($pair in [regex]::Matches($values, '(\w+)=([-\d.eE+]+)')) {
            $key = $pair.Groups[1].Value
            if ($key -in $fields -or $key -eq 'host_dispatches') {
                $record[$key] = [double]::Parse($pair.Groups[2].Value, $culture)
            }
        }
        if ($record.Count - [int]$record.Contains('host_dispatches') -ne $fields.Count + 1) { continue }
        if ($Aggregate) {
            [double[]]$intervals = @()
            if ($null -ne $rawWindow) { $intervals = $rawWindow | ConvertFrom-Json -NoEnumerate }
            if ($intervals.Count -ne $record.samples -or ($intervals | Where-Object { -not [double]::IsFinite($_) -or $_ -le 0 })) {
                $windowsWithoutRaw++
            } else {
                $allIntervals.AddRange($intervals)
            }
        }
        [pscustomobject]$record
    })
} finally {
    $reader.Dispose()
}
if (-not $Aggregate) {
    ConvertTo-Json -InputObject $records
    return
}

$stats = [ordered]@{
    windows = $records.Count
    windows_without_raw_intervals = $windowsWithoutRaw
    raw_samples = $allIntervals.Count
    mean_ms = $null
    fps = $null
    p50_ms = $null
    p95_ms = $null
    p99_ms = $null
}
if ($windowsWithoutRaw -eq 0 -and $allIntervals.Count -gt 0) {
    $allIntervals.Sort()
    $stats.mean_ms = ($allIntervals | Measure-Object -Average).Average
    $stats.fps = 1000 / $stats.mean_ms
    $middle = [int][Math]::Floor($allIntervals.Count / 2)
    $stats.p50_ms = if ($allIntervals.Count % 2 -eq 0) {
        ($allIntervals[$middle - 1] + $allIntervals[$middle]) / 2
    } else {
        $allIntervals[$middle]
    }
    foreach ($percentile in 95,99) {
        $stats["p${percentile}_ms"] = $allIntervals[[int][Math]::Ceiling($allIntervals.Count * $percentile / 100) - 1]
    }
}
$stats | ConvertTo-Json
