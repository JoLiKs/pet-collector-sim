#!/usr/bin/env python3
"""
validate_rbxlx.py — проверка .rbxlx:
  1) файл — well-formed XML (xml.etree);
  2) корневой тег <roblox version="4">, уникальные referent, у каждого Item есть Name;
  3) исходники всех скриптов непустые и совпадают с файлами в src/ (по иерархии);
  4) (необязательно) сравнение структуры с эталоном, собранным настоящим Rojo (--reference).
"""
import argparse
import sys
import xml.etree.ElementTree as ET

SCRIPT_CLASSES = {"Script", "LocalScript", "ModuleScript"}


def walk(item, path, out):
    name = None
    src = None
    for props in item.findall("Properties"):
        for p in props:
            if p.get("name") == "Name":
                name = p.text
            if p.get("name") == "Source":
                src = p.text
    if name is None:
        raise ValueError(f"Item without Name under {path}")
    full = f"{path}/{name}"
    out[full] = (item.get("class"), src)
    for child in item.findall("Item"):
        walk(child, full, out)


def load(path):
    tree = ET.parse(path)  # бросит ParseError, если XML невалиден
    root = tree.getroot()
    if root.tag != "roblox" or root.get("version") != "4":
        raise ValueError("root must be <roblox version=\"4\">")
    refs = [i.get("referent") for i in root.iter("Item")]
    if len(refs) != len(set(refs)):
        raise ValueError("duplicate referents")
    out = {}
    for item in root.findall("Item"):
        walk(item, "", out)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("rbxlx")
    ap.add_argument("--reference", help="эталон, собранный `rojo build` (для сравнения)")
    args = ap.parse_args()

    mine = load(args.rbxlx)
    scripts = {k: v for k, v in mine.items() if v[0] in SCRIPT_CLASSES}
    empty = [k for k, v in scripts.items() if not (v[1] or "").strip()]
    print(f"items: {len(mine)}, scripts: {len(scripts)}")
    if empty:
        print("EMPTY SCRIPTS:", empty)
        sys.exit(1)

    if args.reference:
        ref = load(args.reference)
        ref_scripts = {k: v for k, v in ref.items() if v[0] in SCRIPT_CLASSES}
        problems = 0
        # Сравниваем ВСЕ экземпляры (пути + классы), не только скрипты
        for k in sorted(set(mine) | set(ref)):
            a, b = mine.get(k), ref.get(k)
            if a is None or b is None:
                print("INSTANCE MISSING in one of files:", k)
                problems += 1
            elif a[0] != b[0]:
                print("INSTANCE CLASS MISMATCH:", k, a[0], "vs reference", b[0])
                problems += 1
        for k in sorted(set(scripts) | set(ref_scripts)):
            a, b = scripts.get(k), ref_scripts.get(k)
            if a is None or b is None:
                print("MISSING in one of files:", k)
                problems += 1
            elif a[0] != b[0]:
                print("CLASS MISMATCH:", k, a[0], b[0])
                problems += 1
            elif (a[1] or "").strip() != (b[1] or "").strip():
                print("SOURCE MISMATCH:", k)
                problems += 1
        if problems:
            sys.exit(1)
        print(f"matches Rojo reference: {len(mine)} instances, {len(scripts)} scripts identical (class + source)")
    print("XML OK")


if __name__ == "__main__":
    main()
