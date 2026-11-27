#requires -Version 7.0
<#
.SYNOPSIS
Builds the local ChatGPT review archive from explicit text inputs.
.EXAMPLE
pwsh -File scripts/new-review-package.ps1
.EXAMPLE
pwsh -File scripts/new-review-package.ps1 -ArchiveReport
#>
[CmdletBinding()]
param(
    [string]$Inputs = '',
    [string]$Checkpoint = '',
    [string]$LocalAppData = $env:LOCALAPPDATA,
    [switch]$ArchiveReport
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$reports = Join-Path $repo 'CHATGPT_REPORTS'
$logDir = Join-Path $reports 'LOGS'
$history = Join-Path $reports 'HISTORY'
$null = New-Item -ItemType Directory -Force -Path $reports,$logDir,$history
if (-not $Inputs) { $Inputs = Join-Path $reports 'REVIEW_INPUTS.json' }
if (-not $Checkpoint) { $Checkpoint = Join-Path $reports 'CHECKPOINT.json' }
$inputsPath = (Resolve-Path -LiteralPath $Inputs).ProviderPath
$inputsSource = [IO.File]::ReadAllText($inputsPath)
$inputsList = @($inputsSource | ConvertFrom-Json)
$generated = [DateTimeOffset]::UtcNow
$timestamp = $generated.ToString('yyyyMMddTHHmmssfffZ')
$utf8 = [Text.UTF8Encoding]::new($false)

function Write-AtomicText([string]$Path, [string]$Content) {
    $next = "$Path.$([Guid]::NewGuid().ToString('N')).tmp"
    try {
        [IO.File]::WriteAllText($next, $Content, $utf8)
        [IO.File]::Move($next, $Path, $true)
    } finally {
        if ([IO.File]::Exists($next)) { [IO.File]::Delete($next) }
    }
}

function Protect-ReviewText([string]$Value) {
    $Value = $Value -replace '(?i)\b[A-Z]:[/\\]+Users[/\\]+[^/\\\s"<>]+[/\\]+AppData[/\\]+Local', '%LOCALAPPDATA%'
    $Value = $Value -replace '(?i)\b[A-Z]:[/\\]+Users[/\\]+[^/\\\s"<>]+', '%USERPROFILE%'
    $Value = $Value -replace '(?i)\b[A-Z]:[/\\]+[^\r\n"<>]*?(?:game_scarlett_master\.exe|\.rpf\b)', '[local title content]'
    $Value = $Value -replace '(?i)\b[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}\b', '[redacted email]'
    $Value = $Value -replace '(?i)\b(?:Bearer|Basic)\s+[A-Za-z0-9+/_=.-]+', '[redacted authorization]'
    $Value = $Value -replace '(?i)\b(password|secret|access[_-]?token|refresh[_-]?token|api[_-]?key|authorization|set-cookie|cookie|xuid|gamertag)\s*[:=]\s*(?:"[^"\r\n]*"|[^\s,;]+)', '$1=[redacted]'
    $Value = $Value -replace '(?i)\bhttps?://[^\s"<>]+\?[^\s"<>]+', '[redacted URL query]'
    return $Value
}

function Read-ReviewLog([IO.FileInfo]$File, [bool]$Runtime, [bool]$Complete = $false) {
    $bounded = $Runtime -and $File.Length -gt 32MB
    $edgeLines = if ($bounded) {
        @(Get-Content -LiteralPath $File.FullName -TotalCount 2000) + @(Get-Content -LiteralPath $File.FullName -Tail 2000)
    }
    $stream = if (-not $bounded) { [IO.File]::Open($File.FullName, 'Open', 'Read', 'ReadWrite') }
    $reader = if ($stream) { [IO.StreamReader]::new($stream) }
    $index = 0
    $first = [Collections.Generic.List[string]]::new()
    $last = [Collections.Generic.Queue[string]]::new()
    $seen = [Collections.Generic.HashSet[string]]::new()
    $total = 0
    try {
        while ($true) {
            $line = if ($bounded) { $edgeLines[$index++] } else { $reader.ReadLine() }
            if ($null -eq $line) { break }
            # A game can emit free-form or identifying text through other modules.
            if ($Runtime -and $line -notmatch '(?i)victory_gpu::(?:host|copystat|frame|pipeline|descriptor|draw|shadow|queue|list|land|texback|ambient|readback|refresh|indirect_metrics|dxgi)|victory_hle::modules::lifecycle.+(?:window closed|title suspended|title did not finish suspending)') { continue }
            if ($Runtime -and $line -notmatch '(?i)\b(?:warn|error)\b|fps,.{0,80}ms/frame|presentation|dxgi|adapter|wave(?:32|64)|driver|width=|resolution|heap|readback|copied back|copying back|resource refresh|list close|memory|pipeline library saved|title suspended|indirect') { continue }
            if ($line -match '(?i)license[_ -]?key|license[_ -]?token|session[_ -]?ticket|\b(?:report|upload).{0,25}https?://') { continue }
            if ($line.Length -gt 1400) { $line = $line.Substring(0, 1400) + ' …' }
            $line = Protect-ReviewText $line
            if (-not $Complete -and $line -match '(?i)\b(?:warn|error)\b') {
                $signature = $line -replace '^\S+\s+', ''
                if (-not $seen.Add($signature)) { continue }
            }
            ++$total
            if ($Complete -or $first.Count -lt 55) { $first.Add($line); continue }
            if ($last.Count -eq 100) { $null = $last.Dequeue() }
            $last.Enqueue($line)
        }
    } finally {
        if ($reader) { $reader.Dispose() }
    }
    $omitted = $total - $first.Count - $last.Count
    $result = @($first.ToArray())
    if ($omitted -gt 0) { $result += "[… $omitted intervening matching lines omitted …]" }
    $result += $last.ToArray()
    if ($bounded) { $result = @('[Long log. Only the first and last 2,000 source lines were scanned.]') + $result }
    return ($result -join "`n") + "`n"
}

function Revision-Hash([string]$Text) {
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($utf8.GetBytes($Text))).ToLowerInvariant()
}

$core = [ordered]@{}
$revisions = [ordered]@{}
function Add-Report([string]$Name, [string]$Path) {
    $source = [IO.File]::ReadAllText($Path)
    $core[$Name] = Protect-ReviewText $source
    $revisions[$Name] = [ordered]@{
        path = $Path
        local_sha256 = Revision-Hash $source
        packaged_sha256 = Revision-Hash $core[$Name]
    }
}
foreach ($name in @('LATEST_REPORT.md','BENCHMARK_HISTORY.csv','SOURCE_CHANGES.md','SHADER_WARMUP_REPORT.md')) {
    Add-Report $name (Join-Path $reports $name)
}
foreach ($name in @('HANDOFF.md','VICTORY_FIX_PLAN.md','PERFORMANCE_BASELINE.md','PERFORMANCE_RESULTS.md','COMPATIBILITY_STATUS.md','CHANGELOG.md','RECOMMENDED_CONFIG.md','SCARLETT_REPORT.md','UPSCALING_STATUS.md','FRAME_GENERATION_STATUS.md')) {
    Add-Report $name (Join-Path $repo $name)
}
Add-Report 'CHECKPOINT.json' (Resolve-Path -LiteralPath $Checkpoint).ProviderPath
Add-Report 'REVIEW_INPUTS.json' $inputsPath
if ($revisions['REVIEW_INPUTS.json'].local_sha256 -ne (Revision-Hash $inputsSource)) {
    throw 'The review input list changed while reading reports.'
}
$state = $core['CHECKPOINT.json'] | ConvertFrom-Json -AsHashtable
foreach ($key in 'revision','last_completed_benchmark','last_completed_test','unfinished_task','active_runs') {
    if (-not $state.Contains($key)) { throw "Review checkpoint is missing $key." }
}

$evidence = [ordered]@{}
$manifest = [Collections.Generic.List[object]]::new()
$excerpts = [Collections.Generic.List[string]]::new()
$excerpts.Add("Victory review evidence generated $timestamp UTC.")
$excerpts.Add('Runtime excerpts contain selected graphics diagnostics. Complete runtime logs and title captures remain local.')
$excerpts.Add('')
foreach ($item in $inputsList) {
    if ($item.kind -notin 'runtime','build','test','benchmark','patch','diagnostic' -or $item.label -notmatch '^[A-Za-z0-9_-]{1,70}$') {
        throw 'Invalid review input kind or label.'
    }
    $path = [string]$item.path
    if ($path -match '^%LOCALAPPDATA%[/\\](.+)$') {
        $path = Join-Path $LocalAppData $Matches[1]
    } else {
        $path = [Environment]::ExpandEnvironmentVariables($path)
    }
    if (-not [IO.Path]::IsPathFullyQualified($path)) { $path = Join-Path $repo $path }
    $record = [ordered]@{ Label = $item.label; Kind = $item.kind; LocalOriginal = Protect-ReviewText $path; Bytes = ''; Included = ''; Omission = '' }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $record.Included = 'Original unavailable'
        $record.Omission = 'Expected source was missing when this archive was generated.'
        $manifest.Add([pscustomobject]$record)
        continue
    }
    $file = Get-Item -LiteralPath $path
    $record.Bytes = $file.Length
    $accepted = switch ($item.kind) {
        runtime { $file.Extension -eq '.log' }
        benchmark { $file.Extension -eq '.json' }
        patch { $file.Extension -in '.diff','.patch' }
        default { $file.Extension -in '.txt','.log' }
    }
    if (-not $accepted) { throw "File type rejected for review input $($item.label)." }
    if ($item.kind -eq 'runtime' -and $item.complete -eq $true -and $file.Length -le 640KB) {
        $entry = "$($item.label).log"
        if ($evidence.Contains($entry)) { throw "Duplicate review input $entry." }
        $evidence[$entry] = Read-ReviewLog $file $true $true
        $record.Included = "LOGS/$entry"
        $record.Omission = 'Only redacted graphics and lifecycle records are included.'
    } elseif ($item.kind -eq 'runtime') {
        $content = Read-ReviewLog $file $true
        $excerpts.Add("## $($item.label)")
        $excerpts.Add($content)
        $record.Included = 'Filtered excerpt in LATEST_LOG_EXCERPTS.txt'
        $record.Omission = if ($file.Length -gt 32MB) { 'Large runtime log. Bounded head and tail excerpts.' } else { 'Runtime excerpt. Complete original remains local.' }
    } elseif ($file.Length -le 640KB) {
        $stream = [IO.File]::Open($file.FullName, 'Open', 'Read', 'ReadWrite')
        try {
            $reader = [IO.StreamReader]::new($stream)
            try { $original = $reader.ReadToEnd() }
            finally { $reader.Dispose() }
        } finally { $stream.Dispose() }
        if ($original.Contains([char]0)) { throw "Binary data rejected for review input $($item.label)." }
        if ($item.kind -eq 'benchmark') {
            $null = ConvertFrom-Json -InputObject $original -ErrorAction Stop
        }
        $content = Protect-ReviewText $original
        $entry = "$($item.label)$($file.Extension)"
        if ($evidence.Contains($entry)) { throw "Duplicate review input $entry." }
        $evidence[$entry] = $content
        $record.Included = "LOGS/$entry"
    } elseif ($item.kind -in 'build','test') {
        $excerpts.Add("## $($item.label)")
        $excerpts.Add((Read-ReviewLog $file $false))
        $record.Included = 'Size-limited excerpt in LATEST_LOG_EXCERPTS.txt'
        $record.Omission = 'Text input exceeded the full-file size limit.'
    } else {
        $record.Included = 'Size limit exceeded. See local original.'
        $record.Omission = 'Input exceeded the full-file size limit.'
    }
    $manifest.Add([pscustomobject]$record)
}
$core['LATEST_LOG_EXCERPTS.txt'] = ($excerpts -join "`n") + "`n"
$core['LOG_MANIFEST.csv'] = ($manifest | ConvertTo-Csv -NoTypeInformation) -join "`n"
$commit = & git -C $repo rev-parse HEAD
if ($LASTEXITCODE -ne 0) { throw 'Could not identify the Git commit.' }
$branch = & git -C $repo branch --show-current
if ($LASTEXITCODE -ne 0) { throw 'Could not identify the Git branch.' }
$status = @(& git -C $repo -c core.quotepath=false status --short)
if ($LASTEXITCODE -ne 0) { throw 'Could not read the Git working tree status.' }
$core['PACKAGE_MANIFEST.json'] = [ordered]@{
    generated_utc = $generated.ToString('o')
    checkpoint_revision = $state.revision
    repository = Protect-ReviewText $repo
    git_branch = $branch
    git_commit = $commit
    git_working_tree_status = @($status | ForEach-Object { Protect-ReviewText $_ })
    last_completed_benchmark = $state.last_completed_benchmark
    last_completed_test = $state.last_completed_test
    unfinished_task = $state.unfinished_task
    active_runs = $state.active_runs
    report_revisions = @($revisions.GetEnumerator() | ForEach-Object {
        [ordered]@{ file = $_.Key; local_sha256 = $_.Value.local_sha256; archived_sha256 = $_.Value.packaged_sha256 }
    })
    evidence = $manifest.ToArray()
} | ConvertTo-Json -Depth 10

$archive = Join-Path $repo 'CHATGPT_REVIEW_PACKAGE.zip'
$temporaryArchive = "$archive.$([Guid]::NewGuid().ToString('N')).tmp"
try {
    $zip = [IO.Compression.ZipFile]::Open($temporaryArchive, 'Create')
    try {
        foreach ($entries in @($core, $evidence)) {
            $prefix = if ([object]::ReferenceEquals($entries, $evidence)) { 'LOGS/' } else { '' }
            foreach ($name in $entries.Keys) {
                $member = $zip.CreateEntry("$prefix$name", 'Optimal')
                $writer = [IO.StreamWriter]::new($member.Open(), $utf8)
                try { $writer.Write([string]$entries[$name]) } finally { $writer.Dispose() }
            }
        }
    } finally {
        $zip.Dispose()
    }
    foreach ($revision in $revisions.Values) {
        if ((Revision-Hash ([IO.File]::ReadAllText($revision.path))) -ne $revision.local_sha256) {
            throw "A report changed while packaging: $($revision.path). Regenerate from the new checkpoint."
        }
    }
    [IO.File]::Move($temporaryArchive, $archive, $true)
} finally {
    if ([IO.File]::Exists($temporaryArchive)) { [IO.File]::Delete($temporaryArchive) }
}
foreach ($entry in $evidence.Keys) {
    Write-AtomicText (Join-Path $logDir $entry) $evidence[$entry]
}
foreach ($name in 'LATEST_LOG_EXCERPTS.txt','LOG_MANIFEST.csv','PACKAGE_MANIFEST.json') {
    Write-AtomicText (Join-Path $reports $name) $core[$name]
}
if ($ArchiveReport) {
    Write-AtomicText (Join-Path $history "$timestamp-LATEST_REPORT.md") $core['LATEST_REPORT.md']
}
Get-Item -LiteralPath $archive
