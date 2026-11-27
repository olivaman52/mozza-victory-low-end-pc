# Export one object per metrics window from a run with VICTORY_FRAME_METRICS=1.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Log
)

$ErrorActionPreference = 'Stop'
$culture = [Globalization.CultureInfo]::InvariantCulture
$fields = @(
    'samples', 'fps', 'p50_ms', 'p95_ms', 'p99_ms', 'cpu_prepare_ms',
    'gpu_wait_ms', 'buffer_upload_mb', 'texture_upload_mb', 'readback_ms',
    'readback_mb', 'draws', 'missing_pipeline_draws', 'dropped_indirect',
    'compiling_pipelines'
)
$pattern = '^(?<timestamp>\S+)\s+INFO\s+victory_gpu::frame_metrics:\s+present interval metrics\s+(?<values>.*)$'
$logFile = (Resolve-Path -LiteralPath $Log).ProviderPath
$stream = [IO.File]::Open($logFile, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
$reader = [IO.StreamReader]::new($stream)
try {
    $records = while ($null -ne ($line = $reader.ReadLine())) {
        if ($line -notmatch $pattern) { continue }
        $record = [ordered]@{ timestamp = $Matches.timestamp }
        foreach ($pair in [regex]::Matches($Matches.values, '(\w+)=([-\d.eE+]+)')) {
            $key = $pair.Groups[1].Value
            if ($key -in $fields) {
                $record[$key] = [double]::Parse($pair.Groups[2].Value, $culture)
            }
        }
        if ($record.Count -eq $fields.Count + 1) { [pscustomobject]$record }
    }
} finally {
    $reader.Dispose()
}
ConvertTo-Json -InputObject @($records)
