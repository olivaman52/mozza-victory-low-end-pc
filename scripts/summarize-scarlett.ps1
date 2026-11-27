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
$guestRecordsPattern = "descriptor records the title copied into its heap as bytes .*?per frame (?<pages>$number) changed heap pages, (?<slots>$number) slots looked at, (?<mirrored>$number) whose record was new and was mirrored, (?<tabled>$number) new ones of draws' tables left to the draws, (?<deferred>$number) that waited for a draw first, (?<wall_ms>$number) ms \((?<wait_ms>$number) ms waited for\);.*?(?<read_mb>$number) MB read; (?<ask_ms>$number) ms asking, (?<compare_ms>$number) reading and comparing, (?<make_ms>$number) making"
$landingPattern = "landing per frame .*?which pieces to fetch (?<select_ms>$number) ms,.*?merging what was fetched (?<merge_ms>$number) ms \((?<worker_ms>$number) ms on all threads, (?<jobs>$number) jobs\).*? (?<lock_ms>$number) ms waiting for the title's bytes going in, (?<guards_ms>$number) ms opening or noting guards"
$relayPattern = "host copies in the card's memory: .*? (?<fetched_pieces>$number) of them fetched \((?<fetched_mb>$number) MB\) with (?<waits>$number) more waits for the card \((?<fetch_ms>$number) ms\)"
$refreshPattern = "preparing per frame, the submitting thread: (?<watch_ms>$number) ms asking the write watch .*? (?<steps_ms>$number) in the lists' steps \(refreshes (?<refresh_ms>$number) in (?<flushes>$number) flushes of (?<refresh_count>$number), (?<unchanged>$number) of them known to copy nothing"
$presentStatusPattern = 'DXGI presentation results attempted=(?<attempted>\d+) not_accepted=(?<not_accepted>\d+)'
$hostWorkPattern = "present interval metrics .*?draws=(?<draws>$number) host_dispatches=(?<dispatches>$number)"
$memoryPattern = "the card's own: budget (?<budget>\d+) MB, in use (?<dedicated>\d+) MB,.*?the PC's shared with the card: budget \d+ MB, in use (?<shared>\d+) MB"
$systemPattern = 'memory: (?<private>\d+) MB private \((?<resident>\d+) MB of it in memory; the PC has (?<physical>\d+) MB free and (?<commit>\d+) MB left to commit\)'
$gpuPattern = "the card's clock per frame: nothing of ours queued (?<idle>$number) ms \(the card about (?<occupancy>$number)% busy by this count\), (?<behind>$number) ms of that"
$indirectPattern = 'indirect calls dropped rank=\d+ reason="(?<reason>[a-z_]+)" calls=(?<calls>\d+)'
$fetchPattern = 'GPU readback transfer sample .+?pieces=(?<pieces>\d+) fetched_bytes=(?<bytes>\d+) copy_queue=(?:true|false) fence_wait_us=(?<fence_us>\d+) record_submit_overlap_and_wait_us=(?<relay_us>\d+)'
$sweepPattern = "buffer descriptor sweep frames=(?<frames>$number) full=(?<full>\d+) partial=(?<partial>\d+) dirty=(?<dirty>\d+) fallback=(?<fallback>\d+) duplicate=(?<duplicate>\d+) selection_ms=(?<selection_ms>$number)"
$budgetPattern = " (?<empty>$number) indirect records a frame ran empty for want of their list's budget"
$frames = [Collections.Generic.List[object]]::new()
$descriptors = [Collections.Generic.List[object]]::new()
$gpu = [Collections.Generic.List[object]]::new()
$memory = [Collections.Generic.List[object]]::new()
$system = [Collections.Generic.List[object]]::new()
$fetch = [Collections.Generic.List[object]]::new()
$sweeps = [Collections.Generic.List[object]]::new()
$budget = [Collections.Generic.List[object]]::new()
$guestRecords = [Collections.Generic.List[object]]::new()
$landing = [Collections.Generic.List[object]]::new()
$relay = [Collections.Generic.List[object]]::new()
$refresh = [Collections.Generic.List[object]]::new()
$presentStatus = [Collections.Generic.List[object]]::new()
$hostWork = [Collections.Generic.List[object]]::new()
$rejections = @{}
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
        if ($line -notmatch '^(?<timestamp>\S+)\s+INFO\s+victory_gpu::(?:host|copystat|descriptor|frame_metrics|land|indirect_metrics|readback|descriptor_sweep):') { continue }
        $time = [DateTimeOffset]::Parse($Matches.timestamp, $culture)
        if ($time -lt $Checkpoint -or $time -ge $end) { continue }
        if ($line -match $framePattern) { Add-MatchedRow $frames $Matches $time }
        elseif ($line -match $descriptorPattern) { Add-MatchedRow $descriptors $Matches $time }
        elseif ($line -match $guestRecordsPattern) { Add-MatchedRow $guestRecords $Matches $time }
        elseif ($line -match $landingPattern) { Add-MatchedRow $landing $Matches $time }
        elseif ($line -match $relayPattern) { Add-MatchedRow $relay $Matches $time }
        elseif ($line -match $refreshPattern) { Add-MatchedRow $refresh $Matches $time }
        elseif ($line -match $presentStatusPattern) { Add-MatchedRow $presentStatus $Matches $time }
        elseif ($line -match $hostWorkPattern) { Add-MatchedRow $hostWork $Matches $time }
        elseif ($line -match $gpuPattern) { Add-MatchedRow $gpu $Matches $time }
        elseif ($line -match $memoryPattern) { Add-MatchedRow $memory $Matches $time }
        elseif ($line -match $systemPattern) { Add-MatchedRow $system $Matches $time }
        elseif ($line -match $fetchPattern) { Add-MatchedRow $fetch $Matches $time }
        elseif ($line -match $sweepPattern) { Add-MatchedRow $sweeps $Matches $time }
        elseif ($line -match $budgetPattern) { Add-MatchedRow $budget $Matches $time }
        elseif ($line -match $indirectPattern) { $rejections[$Matches.reason] += [long]$Matches.calls }
    }
} finally {
    $reader.Dispose()
}
$mean = if ($frames.Count) { ($frames | Measure-Object -Property ms -Average).Average }
$rejected = ($rejections.Values | Measure-Object -Sum).Sum
$ranked = @($rejections.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
    [ordered]@{ reason = $_.Key; calls = $_.Value; share_percent = 100 * $_.Value / $rejected }
})
[ordered]@{
    checkpoint = $Checkpoint.ToString('O')
    seconds = $Seconds
    windows = $frames.Count
    interval_mean_ms = $mean
    fps_from_interval_mean = if ($mean -gt 0) { 1000 / $mean }
    sampled_frame_windows = $frames.ToArray()
    descriptor_windows = $descriptors.ToArray()
    guest_descriptor_record_windows = $guestRecords.ToArray()
    landing_windows = $landing.ToArray()
    card_fetch_windows = $relay.ToArray()
    refresh_windows = $refresh.ToArray()
    dxgi_nonaccepted_windows = $presentStatus.ToArray()
    recorded_host_work_windows = $hostWork.ToArray()
    queue_estimates = $gpu.ToArray()
    gpu_memory = $memory.ToArray()
    system_memory = $system.ToArray()
    indirect_cpu_rejections = $ranked
    indirect_empty_gpu_record_windows = $budget.ToArray()
    sampled_readback_transfers = $fetch.ToArray()
    descriptor_sweep_windows = $sweeps.ToArray()
} | ConvertTo-Json -Depth 4
