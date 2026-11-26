# Cross-build the vendored cool_fox runner for Windows on Windows.
#
# usage: build.ps1 [cargo build args...]   (default: --release --locked --features diagnostics)
#
# Builds cool_fox/ (already carrying patches 0001-0002) with the toolchain pinned
# by the checkout. Needs Rust with the x86_64-pc-windows-msvc target and the
# Visual Studio Build Tools (link.exe + Windows SDK).
#
# Result: cool_fox\target\release\victory.exe
# Logs:   D:\victory-gtx1660\build-log-<timestamp>.txt      (full cargo output)
#         D:\victory-gtx1660\build-summary-<timestamp>.txt  (important parts only)
$ErrorActionPreference = 'Stop'
$here = Split-Path $MyInvocation.MyCommand.Definition -Parent
$src = Join-Path $here '..\cool_fox'
$root = Resolve-Path (Join-Path $here '..')
if (-not (Test-Path (Join-Path $src 'rust-toolchain.toml'))) {
    Write-Host "build.ps1: run it beside cool_fox (expected $src)"; exit 2
}

$ts = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$buildLog = Join-Path $root "build-log-$ts.txt"
$summary  = Join-Path $root "build-summary-$ts.txt"

Push-Location $src
try {
    if ($args.Count -eq 0) { $args = @('--release', '--locked', '--features', 'diagnostics') }

    $start = Get-Date
    Write-Host "build.ps1: cargo build $args"
    Write-Host "  full log: $buildLog"

    # Run cargo, tee to console and capture everything to the build log.
    $proc = Start-Process -FilePath 'cargo' -ArgumentList @('build', '-p', 'victory', '--target', 'x86_64-pc-windows-msvc') + $args -Wait -PassThru -NoNewWindow -RedirectStandardOutput $buildLog -RedirectStandardError $buildLog
    $code = $proc.ExitCode

    $end = Get-Date
    $seconds = ($end - $start).TotalSeconds

    # --- Extract important parts only into the summary ---
    $lines = @()
    function w($s) { $script:lines += $s }

    w ("=== build.ps1 summary ===")
    w ("time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    w ("duration: $([math]::Round($seconds,1)) s")
    w ("exit code: $code")
    w ("target: x86_64-pc-windows-msvc --release --features diagnostics")
    w ("binary: $root\cool_fox\target\x86_64-pc-windows-msvc\release\victory.exe")
    w ("")

    # Count errors and warnings from the captured log.
    $errCount = (Select-String -Path $buildLog -Pattern '^error' | Measure-Object -Line | Select-Object -ExpandProperty Lines)
    $warnCount = (Select-String -Path $buildLog -Pattern '^warning:' | Measure-Object -Line | Select-Object -ExpandProperty Lines)
    w ("errors: $errCount")
    w ("warnings: $warnCount")
    w ("")

    # Show any errors.
    if ($errCount -gt 0) {
        w ("=== ERRORS ===")
        Select-String -Path $buildLog -Pattern '^error' | ForEach-Object { w $_.ToString() }
        w ("")
    }

    # Show warnings touching files we care about (pool.rs, host.rs).
    $poolWarns = Select-String -Path $buildLog -Pattern 'pool\.rs|host\.rs' | ForEach-Object { $_.ToString() }
    if ($poolWarns) {
        w ("=== warnings in pool.rs / host.rs ===")
        $poolWarns | ForEach-Object { w $_ }
        w ("")
    }

    # Show the final cargo status line (Finished / error).
    Select-String -Path $buildLog -Pattern '^(Finished|error)' | ForEach-Object { w $_.ToString() }
    w ("")
    w ("full log: $buildLog")

    $lines | Out-File -FilePath $summary -Encoding utf8
    $lines | Write-Host

    if ($code -ne 0) {
        Write-Host "build.ps1: cargo build FAILED (exit $code). See $buildLog" -ForegroundColor Red
        exit $code
    }
    Write-Host "build.ps1: build OK. Summary: $summary"
}
finally {
    Pop-Location
}
