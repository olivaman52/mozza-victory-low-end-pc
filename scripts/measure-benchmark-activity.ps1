# Take low-frequency Windows CPU and GPU samples alongside a benchmark.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][int]$GamePid,
    [ValidateRange(1, 120)][int]$Samples = 8,
    [ValidateRange(2, 60)][int]$IntervalSeconds = 10
)

$ErrorActionPreference = 'Stop'
$paths = @(
    '\Processor(_Total)\% Processor Time',
    '\Process(*)\% Processor Time',
    '\GPU Engine(*)\Utilization Percentage'
)

$samplesWritten = 0
$counterErrors = @()
Get-Counter -Counter $paths -SampleInterval $IntervalSeconds -MaxSamples $Samples -ErrorAction SilentlyContinue -ErrorVariable +counterErrors | ForEach-Object {
    $snapshot = $_
    $valid = @($snapshot.CounterSamples | Where-Object { $_.Status -in 0,1 })
    $cpu = @($valid | Where-Object Path -like '*\process(*)\% processor time')
    $gpu = @($valid | Where-Object Path -like '*\gpu engine(*)\utilization percentage')
    $active = @($gpu | Where-Object { $_.CookedValue -gt 0 })
    $gamePattern = "pid_${GamePid}_*"
    $row = [ordered]@{
        timestamp = $snapshot.Timestamp.ToUniversalTime().ToString('o')
        system_cpu = ($valid | Where-Object Path -like '*\processor(_total)\% processor time').CookedValue
        invalid_counters = $snapshot.CounterSamples.Count - $valid.Count
        top_cpu_process_instances = @($cpu | Where-Object InstanceName -notin 'idle','_total' |
            Sort-Object CookedValue -Descending | Select-Object -First 8 InstanceName,CookedValue)
        game_gpu_engines = @($active | Where-Object InstanceName -like $gamePattern |
            Sort-Object CookedValue -Descending | Select-Object -First 8 InstanceName,CookedValue)
        other_gpu_engines = @($active | Where-Object InstanceName -notlike $gamePattern |
            Sort-Object CookedValue -Descending | Select-Object -First 8 InstanceName,CookedValue)
    }
    ++$samplesWritten
    $row | ConvertTo-Json -Compress -Depth 4
}
if ($samplesWritten -eq 0) { throw 'Windows returned no performance samples.' }
if ($samplesWritten -ne $Samples -or $counterErrors.Count -gt 0) {
    Write-Warning "Windows returned $samplesWritten of $Samples samples with $($counterErrors.Count) counter errors."
}
