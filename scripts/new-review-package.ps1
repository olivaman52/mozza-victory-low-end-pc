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
$inputsList = @(Get-Content -LiteralPath $Inputs -Raw | ConvertFrom-Json)
$timestamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssfffZ')
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

function Read-ReviewLog([IO.FileInfo]$File, [bool]$Runtime) {
    $stream = [IO.File]::Open($File.FullName, 'Open', 'Read', 'ReadWrite')
    $reader = [IO.StreamReader]::new($stream)
    $first = [Collections.Generic.List[string]]::new()
    $last = [Collections.Generic.Queue[string]]::new()
    $seen = [Collections.Generic.HashSet[string]]::new()
    $total = 0
    try {
        while ($null -ne ($line = $reader.ReadLine())) {
            # A game can emit free-form or identifying text through other modules.
            if ($Runtime -and $line -notmatch '(?i)victory_gpu::(?:host|copystat|frame|pipeline|descriptor|draw|shadow|queue|list|land|texback|ambient)|victory_hle::modules::lifecycle.+(?:window closed|title suspended)') { continue }
            if ($Runtime -and $line -notmatch '(?i)\b(?:warn|error)\b|fps,.{0,80}ms/frame|presentation|dxgi|adapter|wave(?:32|64)|driver|width=|resolution|heap|readback|copied back|copying back|resource refresh|list close|memory|pipeline library saved|title suspended|indirect') { continue }
            if ($line -match '(?i)license[_ -]?key|license[_ -]?token|session[_ -]?ticket|\b(?:report|upload).{0,25}https?://') { continue }
            if ($line.Length -gt 1400) { $line = $line.Substring(0, 1400) + ' …' }
            $line = Protect-ReviewText $line
            if ($line -match '(?i)\b(?:warn|error)\b') {
                $signature = $line -replace '^\S+\s+', ''
                if (-not $seen.Add($signature)) { continue }
            }
            ++$total
            if ($first.Count -lt 55) { $first.Add($line); continue }
            if ($last.Count -eq 100) { $null = $last.Dequeue() }
            $last.Enqueue($line)
        }
    } finally {
        $reader.Dispose()
    }
    $omitted = $total - $first.Count - $last.Count
    $result = @($first.ToArray())
    if ($omitted -gt 0) { $result += "[… $omitted intervening matching lines omitted …]" }
    $result += $last.ToArray()
    return ($result -join "`n") + "`n"
}

$core = [ordered]@{}
foreach ($name in @('LATEST_REPORT.md','BENCHMARK_HISTORY.csv','SOURCE_CHANGES.md')) {
    $core[$name] = Protect-ReviewText ([IO.File]::ReadAllText((Join-Path $reports $name)))
}
foreach ($name in @('HANDOFF.md','VICTORY_FIX_PLAN.md','PERFORMANCE_BASELINE.md','PERFORMANCE_RESULTS.md','COMPATIBILITY_STATUS.md','CHANGELOG.md','RECOMMENDED_CONFIG.md','SCARLETT_REPORT.md','UPSCALING_STATUS.md','FRAME_GENERATION_STATUS.md')) {
    $core[$name] = Protect-ReviewText ([IO.File]::ReadAllText((Join-Path $repo $name)))
}
if ($ArchiveReport) {
    Write-AtomicText (Join-Path $history "$timestamp-LATEST_REPORT.md") $core['LATEST_REPORT.md']
}

$evidence = [ordered]@{}
$manifest = [Collections.Generic.List[object]]::new()
$excerpts = [Collections.Generic.List[string]]::new()
$excerpts.Add("Victory review evidence generated $timestamp UTC.")
$excerpts.Add('Runtime excerpts contain selected graphics diagnostics. Complete runtime logs and title captures remain local.')
$excerpts.Add('')
foreach ($item in $inputsList) {
    if ($item.kind -notin 'runtime','build','test','benchmark','patch' -or $item.label -notmatch '^[A-Za-z0-9_-]{1,70}$') {
        throw 'Invalid review input kind or label.'
    }
    $path = [string]$item.path
    if ($path -match '^%LOCALAPPDATA%[/\\](.+)$') {
        $path = Join-Path $LocalAppData $Matches[1]
    } else {
        $path = [Environment]::ExpandEnvironmentVariables($path)
    }
    if (-not [IO.Path]::IsPathFullyQualified($path)) { $path = Join-Path $repo $path }
    $record = [ordered]@{ Label = $item.label; Kind = $item.kind; LocalOriginal = Protect-ReviewText $path; Bytes = ''; Included = '' }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $record.Included = 'Original unavailable'
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
    if ($item.kind -eq 'runtime') {
        $content = Read-ReviewLog $file $true
        $excerpts.Add("## $($item.label)")
        $excerpts.Add($content)
        $record.Included = 'Filtered excerpt in LATEST_LOG_EXCERPTS.txt'
    } elseif ($file.Length -le 640KB) {
        $original = [IO.File]::ReadAllText($file.FullName)
        if ($original.Contains([char]0)) { throw "Binary data rejected for review input $($item.label)." }
        if ($item.kind -eq 'benchmark') {
            $null = ConvertFrom-Json -InputObject $original -ErrorAction Stop
        }
        $content = Protect-ReviewText $original
        $entry = "$($item.label)$($file.Extension)"
        if ($evidence.Contains($entry)) { throw "Duplicate review input $entry." }
        $evidence[$entry] = $content
        Write-AtomicText (Join-Path $logDir $entry) $content
        $record.Included = "LOGS/$entry"
    } elseif ($item.kind -in 'build','test') {
        $excerpts.Add("## $($item.label)")
        $excerpts.Add((Read-ReviewLog $file $false))
        $record.Included = 'Size-limited excerpt in LATEST_LOG_EXCERPTS.txt'
    } else {
        $record.Included = 'Size limit exceeded. See local original.'
    }
    $manifest.Add([pscustomobject]$record)
}
$core['LATEST_LOG_EXCERPTS.txt'] = ($excerpts -join "`n") + "`n"
$core['LOG_MANIFEST.csv'] = ($manifest | ConvertTo-Csv -NoTypeInformation) -join "`n"
Write-AtomicText (Join-Path $reports 'LATEST_LOG_EXCERPTS.txt') $core['LATEST_LOG_EXCERPTS.txt']
Write-AtomicText (Join-Path $reports 'LOG_MANIFEST.csv') $core['LOG_MANIFEST.csv']

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
    [IO.File]::Move($temporaryArchive, $archive, $true)
} finally {
    if ([IO.File]::Exists($temporaryArchive)) { [IO.File]::Delete($temporaryArchive) }
}
Get-Item -LiteralPath $archive
