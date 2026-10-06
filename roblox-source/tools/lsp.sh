#!/usr/bin/env bash
# Быстрая статика: stylua (форматирует), selene, rojo sourcemap, luau-lsp analyze
cd "$(dirname "$0")/.."
T=./tools_dl
$T/stylua src tests
$T/selene src 2>&1 | tail -3
$T/rojo sourcemap default.project.json -o sourcemap.json
$T/luau-lsp analyze --definitions=$T/globalTypes.d.luau --sourcemap=sourcemap.json src 2>&1 | grep -v "^\[INFO\]\|^\[WARN\]" || true
echo "lsp done"
