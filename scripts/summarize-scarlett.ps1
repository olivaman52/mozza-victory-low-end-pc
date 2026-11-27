[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Log,
    [Parameter(Mandatory)][DateTimeOffset]$Checkpoint,
    [ValidateRange(1, 600)][int]$Seconds = 60
)

$ErrorActionPreference = 'Stop'
$culture = [Globalization.CultureInfo]::InvariantCulture
$end = $Checkpoint.AddSeconds($Seconds)
$number = '[0-9]+(?:\.[0-9]+)?'
$framePattern = "(?<ms>$number) ms/frame \((?<prepare>$number) preparing:.*?(?<wait>$number) on the GPU; (?<readback>$number) copying back (?<backMb>$number) MB\), (?<draws>\d+) draws/frame, dropped (?<missing>\d+) without a host pipeline \((?<pending>\d+) being made\) and (?<indirect>\d+) indirect"
$descriptorPattern = "(?<slots>$number) ms looking at slots, (?<spans>$number) their copies' spans and refreshes, (?<textures>$number) textures;.*?(?<close>$number) ms waited"
$memoryPattern = "the card's own: budget (?<budget>\d+) MB, in use (?<dedicated>\d+) MB,.*?the PC's shared with the card: budget \d+ MB, in use (?<shared>\d+) MB"
$systemPattern = 'memory: (?<private>\d+) MB private \((?<resident>\d+) MB of it in memory; the PC has (?<physical>\d+) MB free and (?<commit>\d+) MB left to commit\)'
$gpuPattern = "the card's clock per frame: nothing of ours queued (?<idle>$number) ms \(the card about (?<occupancy>$number)% busy by this count\), (?<behind>$number) ms of that"
$frames = [Collections.Generic.List[object]]::new()
$descriptors = [Collections.Generic.List[object]]::new()
$gpu = [Collections.Generic.List[object]]::new()
$memory = [Collections.Generic.List[object]]::new()
$system = [Collections.Generic.List[object]]::new()
$read = [IO.File]::Open((Resolve-Path -LiteralPath $Log).ProviderPath, 'Open', 'Read', 'ReadWrite')
$reader = [IO.StreamReader]::new($read)
function Add-MatchedRow($collection, $matched, $timestamp) {
    $values = [ordered]@{ timestamp = $timestamp.ToString('O') }
    foreach ($key in $matched.Keys) {
        if ($key -is [string]) { $values[$key] = [double]::Parse($matched[$key], $culture) }
    }
    $collection.Add([pscustomobject]$values)
}
try {
    while ($null -ne ($line = $reader.ReadLine())) {
        if ($line -notmatch '^(?<timestamp>\S+)\s+INFO\s+victory_gpu::(?:host|copystat):') { continue }
        $time = [DateTimeOffset]::Parse($Matches.timestamp, $culture)
        if ($time -lt $Checkpoint -or $time -ge $end) { continue }
        if ($line -match $framePattern) { Add-MatchedRow $frames $Matches $time }
        elseif ($line -match $descriptorPattern) { Add-MatchedRow $descriptors $Matches $time }
        elseif ($line -match $gpuPattern) { Add-MatchedRow $gpu $Matches $time }
        elseif ($line -match $memoryPattern) { Add-MatchedRow $memory $Matches $time }
        elseif ($line -match $systemPattern) { Add-MatchedRow $system $Matches $time }
    }
} finally {
    $reader.Dispose()
}
$mean = if ($frames.Count) { ($frames | Measure-Object -Property ms -Average).Average }
[ordered]@{
    checkpoint = $Checkpoint.ToString('O')
    seconds = $Seconds
    windows = $frames.Count
    interval_mean_ms = $mean
    fps_from_interval_mean = if ($mean -gt 0) { 1000 / $mean }
    sampled_frame_windows = $frames.ToArray()
    descriptor_windows = $descriptors.ToArray()
    queue_estimates = $gpu.ToArray()
    gpu_memory = $memory.ToArray()
    system_memory = $system.ToArray()
} | ConvertTo-Json -Depth 4
