#!/usr/bin/env bash
# Собирает веб-версию (транспилятор Luau->JS + эмулятор roblox2web) в каталог репозитория демо и оставляет там README/.nojekyll.
# Использование: bash tools/publish_web.sh [/workspace/roblox-game-web]
set -e
G=$(cd "$(dirname "$0")/.." && pwd)
OUT=${1:-/workspace/roblox-game-web}
R2W=${R2W_DIR:-/workspace/roblox2web}
mkdir -p "$OUT"
find "$OUT" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
node "$R2W/roblox2web.js" "$G" -o "$OUT" --zip "$OUT/PetCollectorSimulator_web.zip" >/dev/null
touch "$OUT/.nojekyll"
cp "$G/docs/DEMO_README.md" "$OUT/README.md"
mkdir -p "$OUT/roblox-source"
(cd "$G" && tar --exclude=.git --exclude=tools_dl --exclude=build --exclude=dist --exclude=node_modules --exclude=sourcemap.json -cf - .) | (cd "$OUT/roblox-source" && tar xf -)
echo "web build: $OUT"
