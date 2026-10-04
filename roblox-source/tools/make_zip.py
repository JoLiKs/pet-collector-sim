#!/usr/bin/env python3
"""Собирает dist/PetCollectorSimulator_v2.0.zip (и копию в корне): исходники, .rbxlx, документация, тесты, скриншоты."""
import os, sys, zipfile
root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
EXCL_DIRS = {'.git', 'tools_dl', 'build', 'dist', 'node_modules', '__pycache__'}
EXCL_FILES = {'sourcemap.json'}
name = 'PetCollectorSimulator_v2.0.zip'
out = os.path.join(root, 'dist', name)
os.makedirs(os.path.dirname(out), exist_ok=True)
n = 0
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
    for d, dirs, files in os.walk(root):
        dirs[:] = sorted(x for x in dirs if x not in EXCL_DIRS)
        for f in sorted(files):
            if f in EXCL_FILES or f.endswith('.zip'):
                continue
            p = os.path.join(d, f)
            z.write(p, 'PetCollectorSimulator/' + os.path.relpath(p, root).replace(os.sep, '/'))
            n += 1
import shutil
shutil.copyfile(out, os.path.join(root, name))
print('OK', out, n, 'files', os.path.getsize(out) // 1024, 'KiB')
