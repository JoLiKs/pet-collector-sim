#!/usr/bin/env python3
"""Скриншоты v2.9 (RU): docs/screens/70_potion_{1280x720,390x844}.png — быстрые слоты 3–5 с активными таймерами
бустов, 70_assign_slot.png — карточка предмета в инвентаре с кнопками «В слот 3/4/5».
Запуск: bash tests/browser/build_ui_site.sh && python3 tests/browser/shots_v29.py [--shots DIR]"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.environ.get('R2W_DIR', '/workspace/roblox2web') + '/tests/browser'); sys.path.insert(0, HERE)
from ui_helpers import *
OUT = os.path.join(HERE, '..', '..', 'docs', 'screens')
if '--shots' in sys.argv: OUT = sys.argv[sys.argv.index('--shots') + 1]
os.makedirs(OUT, exist_ok=True)
S = lambda n: '[data-n="Hotbar"] [data-n="Slot%d"]' % n
INV = '[data-n="InventoryPanel"]'

def boot(page, g, url):
    page.goto(url + 'index.html?persist=0&seed=1&lang=ru&country=RU&attr.DailyAutoOpen=false')
    g.wait(lambda: g.vis('[data-n="Hotbar"]'), timeout=120, what='hotbar')
    g.wait(lambda: not g.vis('[data-n="Dot2"]'), timeout=40, what='loading')
    if g.vis('[data-n="Skip"]'):
        page.locator('[data-n="Skip"]').first.click(force=True); page.wait_for_timeout(600)
    g.cmd('item:luck_potion=4'); g.cmd('item:coin_elixir=2'); g.cmd('item:ticket_ForestEgg=2')
    page.wait_for_timeout(800)

def shot(page, name):
    p = os.path.join(OUT, name); page.screenshot(path=p); print('shot', p)

with serve('/tmp/gw_ui') as url:
    with browser(1280, 720) as ctx:
        page = ctx.new_page(); g = G(page); boot(page, g, url)
        page.locator(S(3)).first.click(); page.wait_for_timeout(700)
        page.locator(S(4)).first.click(); page.wait_for_timeout(700)
        page.locator(S(5)).first.click(); g.wait(lambda: g.vis(INV), what='inv')
        page.locator(INV + ' [data-n="Cell_ticket_ForestEgg"]').first.click(); page.wait_for_timeout(700)
        shot(page, '70_assign_slot.png')
        page.locator(INV + ' [data-n="ToSlot5"]').first.click(); page.wait_for_timeout(900)
        page.locator(INV + ' [data-n="Close"]').first.click(); page.wait_for_timeout(5000)  # тосты уходят
        shot(page, '70_potion_1280x720.png')
    with browser(390, 844, True) as ctx:
        page = ctx.new_page(); g = G(page); boot(page, g, url)
        page.locator(S(3)).first.click(); page.wait_for_timeout(700)
        page.locator(S(4)).first.click(); page.wait_for_timeout(5000)
        shot(page, '70_potion_390x844.png')
