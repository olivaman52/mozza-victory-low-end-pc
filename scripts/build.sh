#!/bin/bash
# Cross-build the runner for Windows from Linux with clang-cl and lld-link.
#
# usage: build.sh [cargo build args...]   (default: --release --locked --features diagnostics)
#
# Environment:
#   SRC_DIR   the cool_fox checkout to build (default: the vendored cool_fox/
#             tree next to this repository)
#   XWIN_DIR  an MSVC CRT + Windows SDK splat made with `xwin splat --use-winsysroot-style`
# Needs: the Rust toolchain pinned by the checkout with the x86_64-pc-windows-msvc target,
#        clang (clang-cl), lld (lld-link) and llvm (llvm-lib).
set -eu
here=$(cd "$(dirname "$0")" && pwd)
cd "${SRC_DIR:-$here/../cool_fox}"
[ -f rust-toolchain.toml ] || { echo "build.sh: run it in the cool_fox checkout or set SRC_DIR" >&2; exit 2; }
: "${XWIN_DIR:?set XWIN_DIR to a winsysroot-style xwin splat}"

first() { for d in "$@"; do [ -d "$d" ] && { echo "$d"; return; }; done; echo "build.sh: not found: $1" >&2; exit 2; }
msvc=$(first "$XWIN_DIR"/VC/Tools/MSVC/*/lib/x64)
kits=$(first "$XWIN_DIR"/"Windows Kits"/10/Lib/*)

t=x86_64_pc_windows_msvc
export CARGO_TARGET_X86_64_PC_WINDOWS_MSVC_LINKER=lld-link
export "CC_$t=clang-cl" "CXX_$t=clang-cl" "AR_$t=llvm-lib"
export "CFLAGS_$t=/winsysroot $XWIN_DIR" "CXXFLAGS_$t=/winsysroot $XWIN_DIR"
# Encoded (0x1f-separated) so that paths with spaces survive.
sep=$'\x1f'
export CARGO_ENCODED_RUSTFLAGS="-Lnative=$msvc$sep-Lnative=$kits/ucrt/x64$sep-Lnative=$kits/um/x64"

[ $# -gt 0 ] || set -- --release --locked --features diagnostics
exec cargo build -p victory --target x86_64-pc-windows-msvc "$@"
