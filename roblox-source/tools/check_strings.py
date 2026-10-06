#!/usr/bin/env python3
"""
Линтер захардкоженных строк интерфейса: ищет в src/ английские строковые литералы, которые игрок может увидеть
(Text = "...", UiKit.text(..., "..."), Notify/Toasts, return false, "...", ActionText/ObjectText и т.п.)
и которые не являются ключами Locale. Технические строки (имена инстансов, атрибуты, ремоуты, Enum, логи) пропускаются.
Запуск: python3 tools/check_strings.py   (код возврата 1, если найдены нарушения)
Разрешить строку точечно: комментарий  -- l10n-ok  в конце строки.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
EN = os.path.join(SRC, "ReplicatedStorage", "LocaleEn.lua")

keys = set(re.findall(r'^\t\["([^"]+)"\] =', open(EN, encoding="utf-8").read(), re.M))
RU = os.path.join(SRC, "ReplicatedStorage", "LocaleRu.lua")
ru_src = open(RU, encoding="utf-8").read()
# Тексты «данных», у которых есть перевод в LocaleRu.Names (Locale.n / setWorld переводят их по исходному тексту)
names = set(re.findall(r'^\t\["((?:[^"\\]|\\.)*)"\] =', ru_src[ru_src.index("LocaleRu.Names"):], re.M))

# Литерал сразу после этих конструкций виден игроку (правило A: любое английское слово)
DIRECT_UI = re.compile(
    r'(\bText\s*=\s*|\.Text\s*=\s*|PlaceholderText\s*=\s*|ActionText\s*=\s*|ObjectText\s*=\s*|'
    r'UiKit\.(text|badge)\([^()]*,\s*|Notify\.send\(\s*[^,()]+,\s*|Toasts\.show\(\s*|:Kick\(\s*|'
    r'Widgets\.(label|button)\(\{[^}]*Text\s*=\s*)$'
)
# Правило B: фраза из нескольких английских слов где угодно (кроме технических строк и данных)
PHRASE = re.compile(r"^[A-Za-z][a-z']+([ ,][A-Za-z'][A-Za-z']*)+[ .!?:]*$|^[A-Z][a-z]+[!?.]$")
TECH_LINE = re.compile(
    r'require\(|GetService\(|WaitForChild\(|FindFirstChild|FindFirstAncestor|\bName\s*=\s*"|:IsA\(|Instance\.new\(|'
    r'Attribute\(|AttributeChangedSignal|getEvent\(|getFunction\(|Actions\.call\(|Router\.register\(|Enum\.|'
    r'\bprint\(|\bwarn\(|\berror\(|\bassert\(|typeof\(|type\(|Widgets\.New\(|:GetPropertyChangedSignal|'
    r'string\.(format|match|find|gsub|split|rep|sub)\(|\bKind\s*==|\bType\s*==|Currency\s*=|Status\s*==|'
    r'Font\s*=|ScaleType|AntiExploit\.strike\(|findMotor\(|Widgets\.panel\(|UiKit\.tabs\(|Locale\.(m|t|tp|k|kn|setWorld|get)\(|L\.(t|k|kn|n|bind)\(|Fx_|Tween|Sound|rbxasset'
)
LIT = re.compile(r'"((?:[^"\\\n]|\\.)*)"')
# Данные (имена/описания переводятся через Names и проверяются тестом), ключи Locale и эмулятор тестов не сканируем
SKIP_FILES = {"LocaleEn.lua", "LocaleRu.lua", "Locale.lua"}
DATA_FILES = {"PetData.lua", "Abilities.lua", "AchievementData.lua", "BattlePassData.lua", "EnemyData.lua", "EventData.lua",
              "QuestData.lua", "RecipeData.lua", "ResourceData.lua", "ShopData.lua", "TalentData.lua", "UpgradeData.lua",
              "ZoneData.lua", "Config.lua"}
ALLOW = {"VIP", "R$", "OK", "Q", "E", "X", "ON", "OFF"}


def is_text(s):
    return s not in keys and s not in names and s not in ALLOW and re.search(r"[A-Za-z]{2,}", s) is not None and not re.fullmatch(
        r"[a-z_0-9]+(\.[A-Za-z_0-9]+)+\.?", s
    )


def scan():
    bad = []
    for dirpath, _, files in os.walk(SRC):
        for fn in sorted(files):
            if not fn.endswith(".lua") or fn in SKIP_FILES or fn in DATA_FILES:
                continue
            path = os.path.join(dirpath, fn)
            in_block = False
            for i, line in enumerate(open(path, encoding="utf-8"), 1):
                code = line.rstrip("\n")
                if in_block:
                    if "]]" in code:
                        in_block = False
                    continue
                if re.match(r"\s*--\[=*\[", code):
                    in_block = "]]" not in code
                    continue
                if "l10n-ok" in code or code.lstrip().startswith("--"):
                    continue
                if TECH_LINE.search(code):
                    continue
                for m in LIT.finditer(code):
                    s = m.group(1)
                    before = code[: m.start()]
                    if re.search(r"[=~]=\s*$", before):
                        continue  # сравнение со значением-идентификатором
                    if "--" in before:
                        break
                    if not is_text(s):
                        continue
                    if not (DIRECT_UI.search(before) or PHRASE.match(s)):
                        continue
                    bad.append(f"{os.path.relpath(path, ROOT)}:{i}: \"{s}\"")
    return bad


if __name__ == "__main__":
    found = scan()
    for b in found:
        print(b)
    print(f"check_strings: {len(found)} hardcoded UI string(s), {len(keys)} locale keys")
    sys.exit(1 if found else 0)
