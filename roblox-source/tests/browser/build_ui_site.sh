#!/usr/bin/env bash
# Собирает веб-версию игры + UiDriver (только для теста) в /tmp/gw_ui
set -e
G=$(cd "$(dirname "$0")/../.." && pwd)
R2W=${R2W_DIR:-/workspace/roblox2web}
rm -rf /tmp/gw_src /tmp/gw_ui
mkdir -p /tmp/gw_src
(cd "$G" && tar --exclude=.git --exclude=tools_dl --exclude=dist --exclude=build --exclude=docs --exclude=node_modules -cf - .) | (cd /tmp/gw_src && tar xf -)
cp "$G/tests/browser/UiDriver.server.lua" /tmp/gw_src/src/ServerScriptService/UiDriver.server.lua
node "$R2W/roblox2web.js" /tmp/gw_src -o /tmp/gw_ui >/dev/null
echo built /tmp/gw_ui
