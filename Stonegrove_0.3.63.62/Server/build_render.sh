#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
RUNTIME="$ROOT/Server/Runtime"
TMP="${TMPDIR:-/tmp}/stonegrove-luajit"
mkdir -p "$RUNTIME"
rm -rf "$TMP"
echo "Building LuaJIT 2.1 for Stonegrove Linux server..."
git clone --depth 1 --branch v2.1 https://github.com/LuaJIT/LuaJIT.git "$TMP"
make -C "$TMP" -j"$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)"
# Dereference the build symlink so the deployed Runtime contains the real ELF library.
cp -L "$TMP/src/libluajit.so" "$RUNTIME/libluajit-5.1.so.2"
python3 "$ROOT/Server/validate_render.py"
echo "Stonegrove Render build validation passed."
