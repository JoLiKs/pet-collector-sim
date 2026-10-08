#!/usr/bin/env python3
"""v2.7: магазин в веб-демо с реальными ID геймпассов/продуктов.
Проверяет: цены всех 14 товаров (GetProductInfo -> каталог демо), демо-окно покупки
(«деньги не списываются»), отмену, покупку пасса (сразу КУПЛЕНО) и продуктов (ProcessReceipt -> PurchaseGranted).
Запуск:  bash tests/browser/build_ui_site.sh && python3 tests/browser/test_shop.py [--shots DIR]"""
import json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.environ.get('R2W_DIR', '/workspace/roblox2web') + '/tests/browser')
sys.path.insert(0, HERE)
from ui_helpers import *

ROOT = os.path.join(HERE, '..', '..')
SHOTS = '/tmp/shots_shop'
if '--shots' in sys.argv: SHOTS = sys.argv[sys.argv.index('--shots') + 1]
os.makedirs(SHOTS, exist_ok=True)
STORE = json.load(open(os.path.join(ROOT, 'tools', 'store_ids.json')))
fails = []; oks = 0
def check(name, cond, info=''):
    global oks
    if cond: oks += 1; print('OK  ', name)
    else: fails.append(name); print('FAIL', name, info)

with serve('/tmp/gw_ui') as url, browser() as ctx:
    page = ctx.new_page(); errs = collect(page); g = G(page); g.shots = SHOTS
    page.goto(url + 'index.html?persist=0&seed=1&country=US&attr.DailyAutoOpen=false')
    g.wait(lambda: g.vis('[data-n="Hotbar"]'), timeout=120, what='hotbar')
    page.wait_for_timeout(1000)
    g.click('[data-n="ShopBtn"]')
    g.wait(lambda: g.vis('[data-n="ShopPanel"]'), what='shop')
    BTN = '[data-n="ShopPanel"] [data-n="Buy_%s"]'
    items = [(k, v, 'pass') for k, v in STORE['passes'].items()] + [(k, v, 'product') for k, v in STORE['products'].items()]
    check('в сторе 5 пассов и 9 продуктов', len(STORE['passes']) == 5 and len(STORE['products']) == 9)
    for key, v, kind in items:
        want = 'R$ %d' % v['price']
        try:
            g.wait(lambda: page.locator(BTN % key).count() > 0 and g.text(BTN % key).strip() == want, timeout=20, what=key)
        except Exception:
            pass
        got = g.text(BTN % key).strip() if page.locator(BTN % key).count() else '(нет кнопки)'
        check('цена %s (%s) = %s' % (key, kind, want), got == want, got)
    g.shot('01_shop_prices')
    page.locator(BTN % 'ESSENCE_PACK').first.scroll_into_view_if_needed()
    g.shot('02_shop_essence_bp')

    vip = STORE['passes']['VIP']
    page.locator(BTN % 'VIP').first.scroll_into_view_if_needed()
    g.click(BTN % 'VIP')
    g.wait(lambda: g.vis('#r2w-buy-ok'), what='demo modal')
    modal = page.evaluate("(()=>{const b=document.getElementById('r2w-buy-ok'); return b? b.closest('div').parentElement.innerText: ''})()")
    check('демо-окно: имя, цена и «деньги не списываются»',
          'VIP' in modal and ('R$ %d' % vip['price']) in modal and ('демо' in modal.lower() or 'demo' in modal.lower()), modal)
    g.shot('03_demo_purchase_modal')
    page.click('#r2w-buy-cancel'); page.wait_for_timeout(800)
    check('отмена: пасс не выдан', g.text(BTN % 'VIP').strip() == 'R$ %d' % vip['price'], g.text(BTN % 'VIP'))
    g.click(BTN % 'VIP'); g.wait(lambda: g.vis('#r2w-buy-ok'), what='demo modal 2')
    page.click('#r2w-buy-ok')
    try:
        g.wait(lambda: g.text(BTN % 'VIP').strip() in ('OWNED', 'КУПЛЕНО'), timeout=15, what='owned')
    except Exception:
        pass
    check('пасс VIP действует сразу (КУПЛЕНО без перезахода)', g.text(BTN % 'VIP').strip() in ('OWNED', 'КУПЛЕНО'), g.text(BTN % 'VIP'))
    check('эмулятор видит владение (UserOwnsGamePassAsync)', page.evaluate("R2W.ENV.market.owned.has('gp:%d')" % vip['id']))

    for key in ['GEMS_SMALL', 'ESSENCE_PACK', 'BP_SKIP']:
        page.evaluate('R2W.ENV.market.lastDecision = null')
        page.locator(BTN % key).first.scroll_into_view_if_needed()
        g.click(BTN % key); g.wait(lambda: g.vis('#r2w-buy-ok'), what='modal ' + key)
        page.click('#r2w-buy-ok')
        try:
            g.wait(lambda: page.evaluate('R2W.ENV.market.lastDecision') is not None, timeout=15, what='receipt ' + key)
        except Exception:
            pass
        d = page.evaluate('R2W.ENV.market.lastDecision')
        check('продукт %s: ProcessReceipt -> PurchaseGranted' % key, d == 'PurchaseGranted', d)
    page.wait_for_timeout(500)
    g.shot('04_after_purchases')
    check('ошибок эмулятора нет', page.evaluate('R2W.ENV.errorCount') == 0, page.evaluate('R2W.ENV.errorCount'))

print('\n%d OK, %d FAIL' % (oks, len(fails)))
sys.exit(1 if fails else 0)
