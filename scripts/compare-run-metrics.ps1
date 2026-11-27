# Export paired results from a single-setting experiment using the same executable.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ControlRun,
    [Parameter(Mandatory)][string]$CandidateRun,
    [Parameter(Mandatory)][DateTimeOffset]$ControlFrom,
    [Parameter(Mandatory)][DateTimeOffset]$CandidateFrom,
    [Parameter(Mandatory)][ValidatePattern('^VICTORY_[A-Z_0-9]+$')][string]$Setting,
    [switch]$RequireSuccessfulExit,
    [ValidateRange(1, 600)][int]$Seconds = 60
)

$ErrorActionPreference = 'Stop'

function Read-Run([string]$Directory) {
    Get-Content -LiteralPath (Join-Path $Directory 'run.json') -Raw | ConvertFrom-Json -AsHashtable
}

$control = Read-Run $ControlRun
$candidate = Read-Run $CandidateRun
if ($RequireSuccessfulExit -and (@($control,$candidate) | Where-Object { $_.status -ne 'exited' -or $_.exit_code -ne 0 })) {
    throw 'Both game processes must have exited successfully for this comparison.'
}
if ($control.binary_sha256 -notmatch '^[a-fA-F0-9]{64}$' -or
    $control.binary_sha256 -ne $candidate.binary_sha256) {
    throw 'The runs must use the same executable hash.'
}
if ($control.console -ne $candidate.console -or $control.mode -ne $candidate.mode) {
    throw 'The runs must have the same console profile and cache mode.'
}
if ($control.settings[$Setting] -ceq $candidate.settings[$Setting]) {
    throw "The selected setting did not change: $Setting."
}
foreach ($key in @($control.settings.Keys) + @($candidate.settings.Keys) | Sort-Object -Unique) {
    if ($key -in @($Setting, 'VICTORY_CACHE_DIR', 'VICTORY_DATA_DIR')) { continue }
    if ($control.settings[$key] -cne $candidate.settings[$key]) {
        throw "Another setting differs between runs: $key."
    }
}

function Measure-Run([string]$Directory, [DateTimeOffset]$From, $Mode) {
    $log = Join-Path $Directory 'game.log'
    $raw = & (Join-Path $PSScriptRoot 'measure-frames.ps1') -Log $log -From $From -To $From.AddSeconds($Seconds) -Aggregate |
        ConvertFrom-Json -AsHashtable
    if ($raw.raw_samples -eq 0 -or $raw.windows_without_raw_intervals -ne 0) {
        throw "Raw frame intervals are missing from $Directory."
    }
    $covered = $raw.mean_ms * $raw.raw_samples / 1000
    if ([math]::Abs($covered - $Seconds) -gt [math]::Max(2, $Seconds * 0.05)) {
        throw "Only $covered seconds of frame intervals were measured in $Directory."
    }
    $sampled = & (Join-Path $PSScriptRoot 'summarize-scarlett.ps1') -Log $log -Checkpoint $From -Seconds $Seconds |
        ConvertFrom-Json -AsHashtable
    if ($sampled.windows -eq 0 -or ($sampled.sampled_frame_windows | Where-Object { $_.pending -ne 0 })) {
        throw "The sample has no settled pipeline windows in $Directory."
    }
    $hostWork = $sampled.recorded_host_work_windows
    [ordered]@{
        setting_value = $Mode.settings[$Setting]
        log_folder = Split-Path -Leaf $Directory
        sampled_from = $From.ToString('o')
        raw_coverage_seconds = $covered
        mean_host_draws_per_attempt = if ($hostWork.Count) {
            ($hostWork | Measure-Object -Property draws -Average).Average
        } else {
            ($sampled.sampled_frame_windows | Measure-Object -Property draws -Average).Average
        }
        mean_host_compute_dispatches_per_attempt = if ($hostWork.Count) {
            ($hostWork | Measure-Object -Property dispatches -Average).Average
        }
        unaccepted_dxgi_calls = ($sampled.dxgi_nonaccepted_windows | Measure-Object -Property not_accepted -Sum).Sum
        raw = $raw
        sampled = $sampled
    }
}

$before = Measure-Run $ControlRun $ControlFrom $control
$after = Measure-Run $CandidateRun $CandidateFrom $candidate
[ordered]@{
    setting = $Setting
    binary_sha256 = $control.binary_sha256
    console = $control.console
    cache_mode = $control.mode
    requested_seconds = $Seconds
    control = $before
    candidate = $after
    fps_difference = $after.raw.fps - $before.raw.fps
} | ConvertTo-Json -Depth 10
