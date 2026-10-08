#!/usr/bin/env python3
"""Скриншоты v2.8 (RU) окна ежедневной награды: docs/screens/60_daily_{1280x720,390x844,844x390}.png
(окно открывается само при первом входе) и 60_daily_claimed_1280x720.png (после «ЗАБРАТЬ»).
Запуск: bash tests/browser/build_ui_site.sh && python3 tests/browser/shots_v28.py [--shots DIR]"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.environ.get('R2W_DIR', '/workspace/roblox2web') + '/tests/browser'); sys.path.insert(0, HERE)
from ui_helpers import *
OUT = os.path.join(HERE, '..', '..', 'docs', 'screens')
if '--shots' in sys.argv: OUT = sys.argv[sys.argv.index('--shots') + 1]
os.makedirs(OUT, exist_ok=True)
W = '[data-n="DailyPanel"]'
JS_RECTS = """(q)=>{const p=document.querySelector(q); const r=p.getBoundingClientRect(); const t=[];
  for(const e of p.querySelectorAll('*')){ if(e.children.length===0 && (e.textContent||'').trim()){const b=e.getBoundingClientRect(); t.push([b.left,b.top,b.right,b.bottom])}}
  return {panel:[r.left,r.top,r.right,r.bottom], text:t}}"""

def white_outside_text(page, path):
    """Белые пиксели (min(R,G,B) >= 235) в окне вне прямоугольников текста — должно быть 0."""
    from PIL import Image
    info = page.evaluate(JS_RECTS, W); im = Image.open(path).convert('RGB'); px = im.load()
    L, T, R, B = [int(v) for v in info['panel']]; n = 0
    for y in range(max(0, T), min(im.size[1], B)):
        for x in range(max(0, L), min(im.size[0], R)):
            if min(px[x, y]) >= 235 and not any(a - 3 <= x <= c + 3 and b - 3 <= y <= d + 3 for a, b, c, d in info['text']):
                n += 1
    print('white px outside text', os.path.basename(path), n)
    return n

def run(w, h, touch, name, claim=False):
    with serve('/tmp/gw_ui') as url, browser(w, h, touch) as ctx:
        page = ctx.new_page(); errs = collect(page); g = G(page)
        page.goto(url + 'index.html?persist=0&seed=1&lang=ru&country=RU')
        g.wait(lambda: g.vis(W), timeout=120, what='daily auto-open')
        page.wait_for_timeout(1200)
        p = os.path.join(OUT, name); page.screenshot(path=p); print('shot', p); white_outside_text(page, p)
        if claim:
            page.locator(W + ' [data-n="Claim"]').first.click()
            page.wait_for_timeout(350)
            p2 = os.path.join(OUT, '60_daily_flying_1280x720.png') if '--fly' in sys.argv else None
            if p2: page.screenshot(path=p2); print('shot', p2)
            page.wait_for_timeout(1800)
            p = os.path.join(OUT, '60_daily_claimed_1280x720.png'); page.screenshot(path=p); print('shot', p); white_outside_text(page, p)
        print('errors', [e for e in errs if 'favicon' not in e][:3], page.evaluate('R2W.ENV.errorCount'))

run(1280, 720, False, '60_daily_1280x720.png', claim=True)
run(390, 844, True, '60_daily_390x844.png')
run(844, 390, True, '60_daily_844x390.png')
