# analyze-log.ps1 — extract only the important OOM/error parts of a victory log
#
# usage: .\scripts\analyze-log.ps1 [path-to-log]
# default log: D:\victory-gtx1660\victory-run3.log
#
# Prints a compact summary to stdout AND writes it to
# D:\victory-gtx1660\error-summary-<timestamp>.txt so you can paste it here.
# Nothing else from the log is read or shown.

param(
    [string]$Log = 'D:\victory-gtx1660\victory-run3.log'
)

if (-not (Test-Path $Log)) {
    Write-Host "analyze-log.ps1: no such log: $Log"; exit 2
}

$ts = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$out = 'D:\victory-gtx1660\error-summary-' + $ts + '.txt'

$lines = @()
function w($s) { $script:lines += $s }

w ("=== analyze-log.ps1 ===")
w ("log: $Log")
w ("")

# 1. Total 0x8007000E count (OOM)
$oomCount = (Select-String -Path $Log -Pattern '0x8007000E').Count
w ("=== 0x8007000E OOM count ===")
w ($oomCount)
w ("")

# 2. "no shared buffer" burst at exactly 4 MB (4194304 bytes)
$sb4Count = (Select-String -Path $Log -Pattern 'no shared buffer.*4194304').Count
w ("=== 'no shared buffer' at size=4194304 (4 MB) ===")
w ($sb4Count)
w ("")

# 3. First error line (first 0x8007000E match)
$first = Select-String -Path $Log -Pattern '0x8007000E' | Select-Object -First 1
w ("=== first error ===")
if ($first) { w ($first.ToString()) } else { w ("none found") }
w ("")

# 4. Log tail (last 60 lines) — where the run dies
w ("=== log tail (last 60 lines) ===")
Get-Content -Path $Log -Tail 60 | ForEach-Object { w $_ }
w ("")

# 5. Commit / physical headroom lines from refresh() output
w ("=== commit / physical headroom lines ===")
Select-String -Path $Log -Pattern 'available_commit_mib|physical_free_mib|1658/5233' | ForEach-Object { w $_.ToString() }
w ("")

# 6. Private memory growth hints
w ("=== private memory lines ===")
Select-String -Path $Log -Pattern 'private|Private' | ForEach-Object { w $_.ToString() }

$lines | Out-File -FilePath $out -Encoding utf8
$lines | Write-Host
Write-Host "summary written to: $out"
