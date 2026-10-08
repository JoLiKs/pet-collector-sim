#!/usr/bin/env python3
"""
build_rbxlx.py — собирает Roblox place-файл (.rbxlx, XML) из Rojo-проекта БЕЗ установленного Rojo.

Реализует нужное подмножество правил Rojo:
  * default.project.json: $className, $path, $properties, $ignoreUnknownInstances
  * Name.lua            -> ModuleScript
  * Name.server.lua     -> Script
  * Name.client.lua     -> LocalScript
  * папка с init.*.lua  -> скрипт с дочерними объектами
  * Name.meta.json / init.meta.json -> className и properties
  * Name.rbxmx (XML-модель, v3.1) -> вставляется как есть: корень получает имя из проекта, referent'ы
    переименовываются (уникальны в плейсе), раздел SharedStrings переносится в конец документа
Использование:  python3 tools/build_rbxlx.py [--project default.project.json] [--out build/PetCollectorSimulator.rbxlx]
Только стандартная библиотека Python 3.
"""
import argparse
import json
import os
import re
import sys
import xml.etree.ElementTree as ET
from xml.sax.saxutils import escape

SCRIPT_EXTS = (".lua", ".luau")

# Известные свойства: тип в XML. Всё остальное при необходимости добавляйте сюда.
PROP_TYPES = {
    "CharacterAutoLoads": "bool",
    "StreamingEnabled": "bool",
    "ResetOnSpawn": "bool",
    "IgnoreGuiInset": "bool",
    "Disabled": "bool",
    "ZIndexBehavior": ("token", {"Global": 0, "Sibling": 1}),
    "ScreenInsets": ("token", {"None": 0, "DeviceSafeInsets": 1, "CoreUISafeInsets": 2, "TopbarSafeInsets": 3}),
}

CONTROL_RE = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f]")


# Rojo сам подставляет класс для этих специальных контейнеров внутри StarterPlayer
SPECIAL_CONTAINERS = {"StarterPlayerScripts", "StarterCharacterScripts", "StarterPack"}


class Node:
    def __init__(self, class_name, name):
        self.class_name = class_name
        self.name = name
        self.props = {}
        self.source = None
        self.children = []
        self.raw = None  # (Item-элемент, [SharedString-элементы]) для .rbxmx


_MODEL_N = [0]


def build_from_rbxmx(path, name):
    """XML-модель Roblox: первый Item верхнего уровня с переименованными referent'ами."""
    root = ET.parse(path).getroot()
    item = root.find("Item")
    if item is None:
        raise ValueError(f"{path}: в модели нет Item")
    _MODEL_N[0] += 1
    prefix = "RBXMODEL%02d" % _MODEL_N[0]
    for el in item.iter("Item"):
        if el.get("referent") is not None:
            el.set("referent", prefix + el.get("referent"))
    for ref in item.iter("Ref"):
        if ref.text and ref.text.strip() not in ("", "null"):
            ref.text = prefix + ref.text.strip()
    props = item.find("Properties")
    nm = props.find("string[@name='Name']") if props is not None else None
    if nm is not None:
        nm.text = name
    node = Node(item.get("class"), name)
    shared = root.find("SharedStrings")
    node.raw = (item, list(shared) if shared is not None else [])
    return node


def read_text(path):
    with open(path, "r", encoding="utf-8") as f:
        text = f.read().replace("\r\n", "\n").replace("\r", "\n")
    if CONTROL_RE.search(text):
        raise ValueError(f"{path}: contains XML-illegal control characters")
    return text


def script_class(filename):
    base = filename
    for ext in SCRIPT_EXTS:
        if base.endswith(ext):
            base = base[: -len(ext)]
            break
    else:
        return None, None
    if base.endswith(".server"):
        return "Script", base[: -len(".server")]
    if base.endswith(".client"):
        return "LocalScript", base[: -len(".client")]
    return "ModuleScript", base


def load_meta(path):
    if os.path.isfile(path):
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    return {}


def apply_meta(node, meta):
    if "className" in meta:
        node.class_name = meta["className"]
    for k, v in meta.get("properties", {}).items():
        if k == "Name":
            continue
        node.props[k] = v


def build_from_path(path, name, override_class=None):
    if os.path.isfile(path) and path.endswith(".rbxmx"):
        return build_from_rbxmx(path, name)
    if os.path.isfile(path):
        cls, base = script_class(os.path.basename(path))
        if cls is None:
            return None
        node = Node(cls, name or base)
        node.source = read_text(path)
        meta_path = os.path.join(os.path.dirname(path), base + ".meta.json")
        apply_meta(node, load_meta(meta_path))
        return node

    # папка
    entries = sorted(os.listdir(path))
    node = Node(override_class or "Folder", name)
    init_file = None
    for e in entries:
        for ext in SCRIPT_EXTS:
            for kind in ("", ".server", ".client"):
                if e == "init" + kind + ext:
                    init_file = e
    if init_file:
        cls, _ = script_class(init_file)
        node.class_name = cls
        node.source = read_text(os.path.join(path, init_file))
    apply_meta(node, load_meta(os.path.join(path, "init.meta.json")))

    for e in entries:
        full = os.path.join(path, e)
        if e == init_file or e == "init.meta.json" or e.endswith(".meta.json"):
            continue
        if e.endswith(".spec.lua") or e.startswith("."):
            continue
        if os.path.isdir(full):
            child = build_from_path(full, e)
        else:
            child = build_from_path(full, None)
        if child is not None:
            node.children.append(child)
    return node


def build_from_project(node_json, name, root_dir):
    class_name = node_json.get("$className")
    path = node_json.get("$path")
    if not class_name and name in SPECIAL_CONTAINERS:
        class_name = name
    if path:
        node = build_from_path(os.path.join(root_dir, path), name, class_name)
        if node is None:
            raise ValueError(f"{path}: не удалось собрать (неподдерживаемый файл)")
        if class_name and node.raw is None:
            node.class_name = class_name
    else:
        node = Node(class_name or "Folder", name)
    for k, v in node_json.get("$properties", {}).items():
        node.props[k] = v
    for k, v in node_json.items():
        if k.startswith("$"):
            continue
        node.children.append(build_from_project(v, k, root_dir))
    return node


class Writer:
    def __init__(self):
        self.out = []
        self.counter = 0
        self.shared = {}

    def referent(self):
        self.counter += 1
        return "RBX%032X" % self.counter

    def prop_xml(self, key, value):
        spec = PROP_TYPES.get(key)
        if spec is None:
            if isinstance(value, bool):
                spec = "bool"
            elif isinstance(value, (int, float)):
                spec = "double"
            else:
                spec = "string"
        if isinstance(spec, tuple):
            kind, mapping = spec
            token = mapping[value] if isinstance(value, str) else int(value)
            return f'<token name="{key}">{token}</token>'
        if spec == "bool":
            return f'<bool name="{key}">{"true" if value else "false"}</bool>'
        if spec == "double":
            return f'<double name="{key}">{value}</double>'
        return f'<string name="{key}">{escape(str(value))}</string>'

    def write_node(self, node, depth):
        pad = "\t" * depth
        if node.raw is not None:
            item, shared = node.raw
            self.out.append(pad + ET.tostring(item, encoding="unicode").strip())
            for sh in shared:
                self.shared[sh.get("md5")] = ET.tostring(sh, encoding="unicode").strip()
            return
        self.out.append(f'{pad}<Item class="{node.class_name}" referent="{self.referent()}">')
        self.out.append(f"{pad}\t<Properties>")
        self.out.append(f'{pad}\t\t<string name="Name">{escape(node.name)}</string>')
        if node.class_name == "Script":
            self.out.append(f'{pad}\t\t<token name="RunContext">0</token>')
        for k, v in node.props.items():
            self.out.append(f"{pad}\t\t{self.prop_xml(k, v)}")
        if node.source is not None:
            src = node.source.replace("]]>", "]]]]><![CDATA[>")
            self.out.append(f'{pad}\t\t<ProtectedString name="Source"><![CDATA[{src}]]></ProtectedString>')
        self.out.append(f"{pad}\t</Properties>")
        for child in node.children:
            self.write_node(child, depth + 1)
        self.out.append(f"{pad}</Item>")

    def document(self, root):
        self.out.append('<?xml version="1.0" encoding="utf-8"?>')
        self.out.append(
            '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
            'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
            'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">'
        )
        self.out.append("\t<Meta name=\"ExplicitAutoJoints\">true</Meta>")
        for child in root.children:
            self.write_node(child, 1)
        if self.shared:
            self.out.append("\t<SharedStrings>")
            for key in sorted(self.shared):
                self.out.append("\t\t" + self.shared[key])
            self.out.append("\t</SharedStrings>")
        self.out.append("</roblox>")
        return "\n".join(self.out) + "\n"


def count(node):
    n = 1 if node.source is not None else 0
    return n + sum(count(c) for c in node.children)


def main():
    ap = argparse.ArgumentParser()
    root_default = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    ap.add_argument("--project", default=os.path.join(root_default, "default.project.json"))
    ap.add_argument("--out", default=os.path.join(root_default, "build", "PetCollectorSimulator.rbxlx"))
    args = ap.parse_args()

    with open(args.project, "r", encoding="utf-8") as f:
        project = json.load(f)
    root_dir = os.path.dirname(os.path.abspath(args.project))
    tree = build_from_project(project["tree"], project.get("name", "Game"), root_dir)
    xml = Writer().document(tree)
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "w", encoding="utf-8", newline="\n") as f:
        f.write(xml)
    print(f"OK: {args.out}  ({len(xml)//1024} KiB, scripts: {count(tree)})")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # noqa: BLE001
        print("ERROR:", exc, file=sys.stderr)
        sys.exit(1)
