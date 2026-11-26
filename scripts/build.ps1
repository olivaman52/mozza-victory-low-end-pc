# Cross-build the vendored cool_fox runner for Windows on Windows.
#
# usage: build.ps1 [cargo build args...]   (default: --release --locked --features diagnostics)
#
# Builds cool_fox/ (already carrying patches 0001-0002) with the toolchain pinned
# by the checkout. Needs Rust with the x86_64-pc-windows-msvc target and the
# Visual Studio Build Tools (link.exe + Windows SDK).
#
# Result: cool_fox\target\release\victory.exe
$ErrorActionPreference = 'Stop'
$here = Split-Path $MyInvocation.MyCommand.Definition -Parent
$src = Join-Path $here '..\cool_fox'
if (-not (Test-Path (Join-Path $src 'rust-toolchain.toml'))) {
    Write-Host "build.ps1: run it beside cool_fox (expected $src)"; exit 2
}
Push-Location $src
try {
    if ($args.Count -eq 0) { $args = @('--release', '--locked', '--features', 'diagnostics') }
    cargo build -p victory --target x86_64-pc-windows-msvc @args
} finally {
    Pop-Location
}
