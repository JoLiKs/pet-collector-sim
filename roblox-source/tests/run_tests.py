#!/usr/bin/env python3
"""
Собирает единый Luau-файл (эмуляция Roblox + исходники игры + тест-кейсы) и запускает его в `luau`.
Запуск:  python3 tests/run_tests.py [--luau путь/к/luau]
"""
import argparse
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")

MODULE_DIRS = [
    ("ReplicatedStorage", os.path.join(SRC, "ReplicatedStorage")),
    ("ServerScriptService/Server", os.path.join(SRC, "ServerScriptService", "Server")),
]
CLIENT_DIR = os.path.join(SRC, "StarterGui", "PetCollectorGui", "Modules")
CLIENT_PURE = ["Layout"]


def collect():
    items = []
    for prefix, base in MODULE_DIRS:
        for name in sorted(os.listdir(base)):
            if not name.endswith(".lua"):
                continue
            path_key = prefix + "/" + name[:-4]
            if prefix == "ReplicatedStorage":
                path_key = "ReplicatedStorage/Shared/" + name[:-4]
            with open(os.path.join(base, name), encoding="utf-8") as f:
                src = f.read()
            src = re.sub(r"^export type", "type", src, flags=re.M)
            items.append((path_key, src))
    # Чистые клиентские модули без зависимостей от GUI (v2.4: раскладка HUD)
    for name in CLIENT_PURE:
        with open(os.path.join(CLIENT_DIR, name + ".lua"), encoding="utf-8") as f:
            src = re.sub(r"^export type", "type", f.read(), flags=re.M)
        items.append(("ReplicatedStorage/Client/" + name, src))
    return items


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--luau", default=os.path.join(ROOT, "tools_dl", "luau"))
    args = ap.parse_args()

    parts = [open(os.path.join(ROOT, "tests", "prelude.lua"), encoding="utf-8").read(), "SOURCES = {}"]
    for key, src in collect():
        parts.append(f'SOURCES["{key}"] = function(script)\n{src}\nend')
    parts.append(open(os.path.join(ROOT, "tests", "cases.lua"), encoding="utf-8").read())
    out = os.path.join(ROOT, "build", "_test_bundle.lua")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as f:
        f.write("\n".join(parts))
    res = subprocess.run([args.luau, out], capture_output=True, text=True)
    sys.stdout.write(res.stdout)
    sys.stderr.write(res.stderr)
    sys.exit(res.returncode)


if __name__ == "__main__":
    main()
