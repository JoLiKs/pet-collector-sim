#!/usr/bin/env python3
"""Геймпассы и девелоперские продукты через Roblox Open Cloud (v2.7).

  ROBLOX_OPEN_CLOUD_KEY=…  python3 tools/roblox_store.py list   [--universe N]
  ROBLOX_OPEN_CLOUD_KEY=…  python3 tools/roblox_store.py create [--universe N] [--only KEY] [--no-image]
  ROBLOX_OPEN_CLOUD_KEY=…  python3 tools/roblox_store.py verify [--universe N]
  python3 tools/roblox_store.py write-config   # ID из tools/store_ids.json -> Config.GAMEPASS_IDS / PRODUCT_IDS

* Данные (имя, описание, цена = SuggestedPrice) берутся из src/ReplicatedStorage/Config.lua (через luau).
* Без дублей: перед созданием читается список пассов/продуктов вселенной; если имя уже есть — берётся его ID.
  Повторный запуск после сбоя пропускает созданное. Результат — tools/store_ids.json (без секретов).
* Ключ читается только из переменной окружения и передаётся только заголовком x-api-key; в вывод и файлы не попадает.
* Иконки: assets/store/<KEY>.png (python3 tools/art/make_store_icons.py)."""
import json, os, re, subprocess, sys, tempfile, time
import requests

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
API = 'https://apis.roblox.com'
UNIVERSE = 10769777582
IDS_FILE = os.path.join(ROOT, 'tools', 'store_ids.json')
KEY = os.environ.get('ROBLOX_OPEN_CLOUD_KEY', '')

def scrub(t):
    t = str(t)
    return t.replace(KEY, '***') if KEY else t

def hdr():
    if not KEY: sys.exit('ROBLOX_OPEN_CLOUD_KEY не задан')
    return {'x-api-key': KEY}

def req(method, url, **kw):
    for attempt in range(5):
        r = requests.request(method, url, headers=hdr(), timeout=60, **kw)
        if r.status_code == 429 or r.status_code >= 500:
            time.sleep(2 + attempt * 3); continue
        return r
    return r

def config():
    """GAMEPASSES / PRODUCTS / *_ORDER из Config.lua (luau выполняет файл и печатает JSON)."""
    luau = os.path.join(ROOT, 'tools_dl', 'luau')
    with tempfile.TemporaryDirectory() as d:
        open(os.path.join(d, 'Config.luau'), 'w').write(open(os.path.join(ROOT, 'src', 'ReplicatedStorage', 'Config.lua')).read())
        open(os.path.join(d, 'dump.luau'), 'w').write('''
local C = require("./Config")
local function esc(s) return (string.gsub(tostring(s), '[%c"\\\\]', function(c) return string.format("\\\\u%04x", string.byte(c)) end)) end
local function items(t, order)
  local out = {}
  for _, k in ipairs(order) do local v = t[k]
    table.insert(out, string.format('{"key":"%s","name":"%s","description":"%s","price":%d}', k, esc(v.Name), esc(v.Description or ""), v.SuggestedPrice or 0))
  end
  return "[" .. table.concat(out, ",") .. "]"
end
print('{"passes":' .. items(C.GAMEPASSES, C.GAMEPASS_ORDER) .. ',"products":' .. items(C.PRODUCTS, C.PRODUCT_ORDER) .. '}')
''')
        out = subprocess.run([luau, 'dump.luau'], cwd=d, capture_output=True, text=True, check=True).stdout
    return json.loads(out)

def list_all(kind, universe):
    if kind == 'pass':
        url, field = f'{API}/game-passes/v1/universes/{universe}/game-passes/creator', 'gamePasses'
    else:
        url, field = f'{API}/developer-products/v2/universes/{universe}/developer-products/creator', 'developerProducts'
    items, token = [], None
    while True:
        params = {'pageSize': 50}
        if token: params['pageToken'] = token
        r = req('GET', url, params=params)
        if r.status_code != 200: sys.exit(f'GET {kind} list: HTTP {r.status_code}: {scrub(r.text[:300])}')
        j = r.json(); items += j.get(field) or []
        token = j.get('nextPageToken')
        if not token: return items

def item_id(kind, it):
    return it['gamePassId'] if kind == 'pass' else it['productId']

def price_of(it):
    pi = it.get('priceInformation') or {}
    return pi.get('defaultPriceInRobux')

def create(kind, universe, e, with_image=True):
    url = (f'{API}/game-passes/v1/universes/{universe}/game-passes' if kind == 'pass'
           else f'{API}/developer-products/v2/universes/{universe}/developer-products')
    data = {'name': e['name'], 'description': e['description'], 'isForSale': 'true', 'price': str(e['price'])}
    files = None
    img = os.path.join(ROOT, 'assets', 'store', e['key'] + '.png')
    if with_image and os.path.exists(img):
        files = {'imageFile': (e['key'] + '.png', open(img, 'rb'), 'image/png')}
    else:
        files = {k: (None, v) for k, v in data.items()}; data = None  # всё равно multipart/form-data
    r = req('POST', url, data=data, files=files)
    return r

def load_ids():
    return json.load(open(IDS_FILE)) if os.path.exists(IDS_FILE) else {'universe': UNIVERSE, 'passes': {}, 'products': {}}

def save_ids(ids):
    json.dump(ids, open(IDS_FILE, 'w'), indent=2, ensure_ascii=False); open(IDS_FILE, 'a').write('\n')

def cmd_list(universe):
    for kind in ('pass', 'product'):
        for it in list_all(kind, universe):
            print(f"{kind:8} {item_id(kind, it):>14}  {it['name']:<28} price={price_of(it)} forSale={it.get('isForSale')} "
                  f"icon={it.get('iconAssetId', it.get('iconImageAssetId'))}")

def cmd_create(universe, only=None, with_image=True):
    cfg = config(); ids = load_ids()
    if ids.get('universe') != universe:  # другой опыт — старые ID не смешиваем
        ids = {'universe': universe, 'passes': {}, 'products': {}}
    for kind, group, entries in (('pass', 'passes', cfg['passes']), ('product', 'products', cfg['products'])):
        existing = {it['name']: it for it in list_all(kind, universe)}
        for e in entries:
            if only and e['key'] not in only: continue
            if e['name'] in existing:
                it = existing[e['name']]
                ids[group][e['key']] = {'id': item_id(kind, it), 'name': e['name'], 'price': price_of(it)}
                print(f'skip   {kind:8} {e["key"]:<14} уже есть: {item_id(kind, it)}'); save_ids(ids); continue
            r = create(kind, universe, e, with_image)
            if r.status_code == 200:
                it = r.json(); ids[group][e['key']] = {'id': item_id(kind, it), 'name': e['name'], 'price': price_of(it)}
                print(f'create {kind:8} {e["key"]:<14} -> {item_id(kind, it)} price={price_of(it)} icon={it.get("iconAssetId", it.get("iconImageAssetId"))}')
                save_ids(ids)
            else:
                print(f'FAIL   {kind:8} {e["key"]:<14} HTTP {r.status_code}: {scrub(r.text[:400])}')
            time.sleep(1.0)
    return ids

def cmd_verify(universe):
    ids = load_ids(); bad = 0
    for kind, group in (('pass', 'passes'), ('product', 'products')):
        by_id = {item_id(kind, it): it for it in list_all(kind, universe)}
        for key, v in ids[group].items():
            it = by_id.get(v['id'])
            ok = bool(it) and it.get('isForSale') and (price_of(it) or 0) > 0
            bad += 0 if ok else 1
            print(f"{'OK ' if ok else 'BAD'} {kind:8} {key:<14} {v['id']:>14} forSale={it and it.get('isForSale')} price={it and price_of(it)} "
                  f"icon={it and it.get('iconAssetId', it.get('iconImageAssetId'))}")
    return bad

def cmd_write_config():
    ids = load_ids(); p = os.path.join(ROOT, 'src', 'ReplicatedStorage', 'Config.lua'); s = open(p).read()
    for table, group in (('GAMEPASS_IDS', 'passes'), ('PRODUCT_IDS', 'products')):
        a = s.index(f'Config.{table} = {{'); b = s.index('\n}', a); blk = s[a:b]
        for key, v in ids[group].items():
            blk, n = re.subn(rf'(\n\t{key} = )\d+,', rf'\g<1>{int(v["id"])},', blk)
            if n != 1: sys.exit(f'{table}.{key} не найден в Config.lua')
        s = s[:a] + blk + s[b:]
    open(p, 'w').write(s); print('Config.lua: ID вписаны')

if __name__ == '__main__':
    a = sys.argv[1:]
    uni = int(a[a.index('--universe') + 1]) if '--universe' in a else UNIVERSE
    only = set(a[a.index('--only') + 1].split(',')) if '--only' in a else None
    cmd = a[0] if a else 'list'
    if cmd == 'list': cmd_list(uni)
    elif cmd == 'create': cmd_create(uni, only, '--no-image' not in a)
    elif cmd == 'verify': sys.exit(1 if cmd_verify(uni) else 0)
    elif cmd == 'write-config': cmd_write_config()
    else: sys.exit(__doc__)
