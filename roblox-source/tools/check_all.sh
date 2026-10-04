#!/usr/bin/env bash
# Полная проверка проекта: формат, линт, типы, тесты логики, сборка и валидация .rbxlx.
# Использование:  bash tools/check_all.sh
# Бинарники ищутся в ./tools_dl (если скачаны) либо в PATH (rokit/aftman).
set -u
cd "$(dirname "$0")/.."
T=./tools_dl
bin() { if [ -x "$T/$1" ]; then echo "$T/$1"; else command -v "$1" || echo "MISSING-$1"; fi; }
ROJO=$(bin rojo); STYLUA=$(bin stylua); SELENE=$(bin selene); LSP=$(bin luau-lsp); LUAU=$(bin luau)
fail=0
step() { echo; echo "=== $1"; }
run() { "$@" || { echo "!! FAILED: $*"; fail=1; }; }

step "1/7 StyLua (формат)";            run "$STYLUA" --check src tests
step "2/7 Selene (линт)";              run "$SELENE" src
step "3/7 Rojo sourcemap";             run "$ROJO" sourcemap default.project.json -o sourcemap.json
step "4/7 luau-lsp analyze (типы + синтаксис всех файлов)"
if [ -f "$T/globalTypes.d.luau" ]; then DEFS="$T/globalTypes.d.luau"; else DEFS="globalTypes.d.luau"; fi
out=$("$LSP" analyze --definitions="$DEFS" --sourcemap=sourcemap.json src 2>&1 | grep -v "^\[INFO\]\|^\[WARN\]")
if [ -n "$out" ]; then echo "$out"; fail=1; else echo "no diagnostics"; fi
step "5/7 Тесты серверной логики (Luau + эмуляция Roblox API)"; run python3 tests/run_tests.py --luau "$LUAU"
step "6/7 Сборка .rbxlx без Rojo";     run python3 tools/build_rbxlx.py
step "7/7 Валидация .rbxlx (XML + сверка с эталоном rojo build)"
"$ROJO" build default.project.json -o build/rojo_reference.rbxlx >/dev/null 2>&1
run python3 tools/validate_rbxlx.py build/PetCollectorSimulator.rbxlx --reference build/rojo_reference.rbxlx
echo
if [ "$fail" = 0 ]; then echo "ALL CHECKS PASSED"; else echo "SOME CHECKS FAILED"; exit 1; fi
