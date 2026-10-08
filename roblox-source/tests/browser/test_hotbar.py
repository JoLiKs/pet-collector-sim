#!/usr/bin/env python3
"""v2.9: быстрые слоты 3–5 хотбара в веб-демо.
Проверяет: по умолчанию 3 — зелье удачи, 4 — эликсир монет, 5 — пусто («+»); тап без зелий — подсказка «где взять»
без слова «слияние»; выпить → таймер «x2 ММ:СС» и полоса на слоте, повтор продлевает (~10 мин); оба буста видны;
донатный буст x5 (как LUCK_5X_10M) — тоже на слоте; пустой слот открывает инвентарь «Выберите предмет для слота 5»;
назначение из инвентаря («В слот 5») → предмет в слоте; «Убрать из слота»; угощение — без кнопок слотов;
перезагрузка сохраняет назначение и таймер; на 390×844 и 844×390 слоты не налезают на кошелёк/таймер/прыжок.
Запуск:  bash tests/browser/build_ui_site.sh && python3 tests/browser/test_hotbar.py [--shots DIR]"""
import os, sys, re
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.environ.get('R2W_DIR', '/workspace/roblox2web') + '/tests/browser')
sys.path.insert(0, HERE)
from ui_helpers import *

SHOTS = '/tmp/shots_hotbar'
if '--shots' in sys.argv: SHOTS = sys.argv[sys.argv.index('--shots') + 1]
os.makedirs(SHOTS, exist_ok=True)
fails = []; oks = 0
def check(name, cond, info=''):
    global oks
    if cond: oks += 1; print('OK  ', name)
    else: fails.append(name); print('FAIL', name, info)

S = lambda n: '[data-n="Hotbar"] [data-n="Slot%d"]' % n
INV = '[data-n="InventoryPanel"]'
def cap(g, n): return g.text(S(n) + ' > [data-n="Caption"]').strip()
def cnt(g, n): return g.text(S(n) + ' > [data-n="Count"]').strip()
def toasts(page): return page.evaluate("(()=>{const t=document.querySelector('[data-n=Toasts]'); return t? t.innerText: ''})()")
def mmss(t):
    m = re.search(r'x(\d) (\d\d):(\d\d)', t)
    return (int(m.group(1)), int(m.group(2)) * 60 + int(m.group(3))) if m else (0, -1)
def rect(page, sel):
    return page.evaluate("(q)=>{const e=document.querySelector(q); if(!e) return null; const r=e.getBoundingClientRect(); return [r.left,r.top,r.right,r.bottom]}", sel)
def overlap(a, b):
    return a and b and a[0] < b[2] - 1 and b[0] < a[2] - 1 and a[1] < b[3] - 1 and b[1] < a[3] - 1

with serve('/tmp/gw_ui') as url:
    with browser(1280, 720) as ctx:
        page = ctx.new_page(); errs = collect(page); g = G(page); g.shots = SHOTS
        page.goto(url + 'index.html?seed=1&country=RU&lang=ru&attr.DailyAutoOpen=false')
        g.wait(lambda: g.vis('[data-n="Hotbar"]'), timeout=120, what='hotbar')
        g.wait(lambda: not g.vis('[data-n="Dot2"]'), timeout=40, what='loading')
        page.wait_for_timeout(1500)
        check('5 слотов', all(g.vis(S(i)) for i in range(1, 6)))
        check('слот 3 — «Удача» (зелье удачи)', cap(g, 3) == 'Удача' and g.vis(S(3) + ' > [data-n="Icon"]'), cap(g, 3))
        check('слот 4 — «Монеты» (эликсир)', cap(g, 4) == 'Монеты', cap(g, 4))
        check('слот 5 — пустой «+»', cap(g, 5) == 'Пусто' and g.vis(S(5) + ' [data-n="Plus"]'))
        check('зелий нет — слот тусклый, ×0', g.vis(S(3) + ' [data-n="Dim"]') and cnt(g, 3) == '×0', cnt(g, 3))
        g.click(S(3)); page.wait_for_timeout(600)
        t = toasts(page)
        check('тап без зелий — подсказка, где взять', 'верстак' in t and 'задания' in t, t)
        check('в подсказке нет «слияния»', 'слиян' not in t.lower(), t)
        g.cmd('item:luck_potion=3'); g.cmd('item:coin_elixir=2')
        g.wait(lambda: cnt(g, 3) == '×3', what='×3')
        check('счётчик ×3, слот яркий', not g.vis(S(3) + ' [data-n="Dim"]'))
        g.click(S(3))
        g.wait(lambda: mmss(cap(g, 3))[1] > 0, what='timer 3')
        m, left = mmss(cap(g, 3))
        check('выпил: таймер «x2 ММ:СС» на слоте', m == 2 and 280 <= left <= 300, cap(g, 3))
        check('полоса убывания видна', g.vis(S(3) + ' [data-n="BoostBar"]'))
        check('×2 после питья', cnt(g, 3) == '×2', cnt(g, 3))
        page.wait_for_timeout(1200)
        g.click(S(3))
        g.wait(lambda: mmss(cap(g, 3))[1] > 400, what='extend')
        check('повтор продлевает (~10:00)', 560 <= mmss(cap(g, 3))[1] <= 600, cap(g, 3))
        g.click(S(4))
        g.wait(lambda: mmss(cap(g, 4))[1] > 0, what='timer 4')
        check('эликсир монет: свой таймер', mmss(cap(g, 4))[0] == 2 and 280 <= mmss(cap(g, 4))[1] <= 300, cap(g, 4))
        check('оба таймера видны одновременно', mmss(cap(g, 3))[1] > 0 and g.vis(S(4) + ' [data-n="BoostBar"]'))
        check('таймера удачи нет справа (он на слоте)', not g.vis('[data-n="LuckChip"]'))
        g.shot('01_both_timers')
        # пустой слот -> инвентарь с подсказкой
        g.click(S(5))
        g.wait(lambda: g.vis(INV), what='inventory')
        page.wait_for_timeout(500)
        check('пустой слот открывает инвентарь «Выберите предмет для слота 5»', 'слота 5' in g.text(INV + ' [data-n="Hint"]'))
        g.cmd('item:ticket_MeadowEgg=1')
        # v3.1: в режиме «для слота 5» тап по подходящему предмету сразу кладёт его в слот 5
        g.click(INV + ' [data-n="Cell_ticket_MeadowEgg"]')
        g.wait(lambda: cap(g, 5) == 'Билет', what='ticket slot (one tap)')
        check('назначено одним тапом: в слоте 5 билет ×1', cnt(g, 5) == '×1' and g.vis(S(5) + ' > [data-n="Icon"]'), cnt(g, 5))
        page.wait_for_timeout(400)
        check('у назначенного — «Убрать из слота 5»', 'слота 5' in g.text(INV + ' [data-n="RemoveSlot"]'))
        g.shot('02_assign')
        # кнопки карточки: «Убрать из слота 5» -> слот пуст, затем «В слот 5» (путь через кнопки карточки)
        g.click(INV + ' [data-n="RemoveSlot"]')
        g.wait(lambda: cap(g, 5) == 'Пусто', what='ticket removed')
        check('у билета кнопки «В слот 3/4/5»', all(g.vis(INV + ' [data-n="ToSlot%d"]' % n) for n in (3, 4, 5)))
        g.click(INV + ' [data-n="ToSlot5"]')
        g.wait(lambda: cap(g, 5) == 'Билет', what='ticket slot')
        check('«В слот 5» из карточки — билет снова в слоте 5', cnt(g, 5) == '×1')
        g.click(INV + ' [data-n="Cell_xp_treat"]'); page.wait_for_timeout(400)
        check('угощение — без кнопок слотов, с пояснением', not g.vis(INV + ' [data-n="SlotRow"]') and 'Питомцы' in g.text(INV + ' [data-n="SlotNote"]'))
        g.click(INV + ' [data-n="Cell_coin_elixir"]'); page.wait_for_timeout(400)
        g.click(INV + ' [data-n="RemoveSlot"]')
        g.wait(lambda: cap(g, 4) == 'Пусто', what='removed')
        check('«Убрать из слота 4» — слот пуст', g.vis(S(4) + ' [data-n="Plus"]'))
        g.click(INV + ' [data-n="ToSlot4"]')
        g.wait(lambda: cap(g, 4) not in ('Пусто', ''), what='back')
        g.click(INV + ' [data-n="Close"]'); page.wait_for_timeout(500)
        # донатный буст x5 — через ту же систему
        g.cmd('boost:Luck5=600')
        g.wait(lambda: mmss(cap(g, 3))[0] == 5, what='x5')
        check('донат x5 виден на слоте удачи', 590 <= mmss(cap(g, 3))[1] <= 600, cap(g, 3))
        # перезагрузка
        page.wait_for_timeout(1500)
        page.reload()
        g.wait(lambda: g.vis('[data-n="Hotbar"]'), timeout=120, what='hotbar 2')
        g.wait(lambda: cap(g, 5) == 'Билет', timeout=40, what='slot5 after reload')
        check('после перезагрузки: билет в слоте 5', True)
        g.wait(lambda: mmss(cap(g, 3))[1] > 0, timeout=20, what='timer after reload')
        check('после перезагрузки таймер корректный (x5 ~9:5x)', mmss(cap(g, 3))[0] == 5 and 480 <= mmss(cap(g, 3))[1] <= 600, cap(g, 3))
        # билет: вдали от яйца — окно яйца и подсказка подойти (или сразу открыть, если рядом)
        g.click(S(5)); page.wait_for_timeout(1200)
        t = toasts(page)
        check('билет из слота: окно яйца или открытие', g.vis('[data-n="EggPanel"]') or cnt(g, 5) == '×0', t)
        check('ошибок эмулятора нет', page.evaluate('R2W.ENV.errorCount') == 0, page.evaluate('R2W.ENV.errorCount'))
    # v3.1 регрессия «не назначается в пустой слот» (реальная игра): питомцы фармят — счётчики меняются
    # несколько раз в секунду; тап длится ~0.3 с (нажатие и отпускание — разные моменты, как на телефоне).
    # Раньше карточка пересоздавалась на каждом снимке, кнопка под пальцем исчезала и тап терялся (~1/3 успехов).
    with browser(390, 844, True) as ctx:
        page = ctx.new_page(); g = G(page); g.shots = SHOTS
        page.goto(url + 'index.html?persist=0&seed=1&country=RU&lang=ru&attr.DailyAutoOpen=false&attr.BotsDisabled=true')
        g.wait(lambda: g.vis('[data-n="Hotbar"]'), timeout=120, what='hotbar')
        g.wait(lambda: not g.vis('[data-n="Dot2"]'), timeout=40, what='loading')
        page.wait_for_timeout(1500)
        g.cmd('item:ticket_MeadowEgg=1'); g.cmd('farm:on')
        open_inv = page.locator('[data-n="InventoryBtn"]').first
        open_inv.click(); g.wait(lambda: g.vis(INV), what='inventory')
        g.click(INV + ' [data-n="Cell_ticket_MeadowEgg"]'); page.wait_for_timeout(500)
        page.evaluate("()=>{window.__b=document.querySelector('[data-n=InventoryPanel] [data-n=ToSlot5]')}")
        w0 = g.text(INV + ' [data-n="Have"]')
        page.wait_for_timeout(2500)
        same = page.evaluate("()=>!!(window.__b&&window.__b.isConnected)")
        check('пока счётчики меняются, кнопка «В слот 5» — тот же экземпляр', same)
        okc, n = 0, 8
        for k in range(n):
            want = 'Билет' if cap(g, 5) == 'Пусто' else 'Пусто'
            sel = INV + (' [data-n="ToSlot5"]' if want == 'Билет' else ' [data-n="RemoveSlot"]')
            b = page.locator(sel).first.bounding_box()
            page.mouse.move(b['x'] + b['width'] / 2, b['y'] + b['height'] / 2)
            page.mouse.down(); page.wait_for_timeout(300); page.mouse.up()
            try:
                g.wait(lambda: cap(g, 5) == want, timeout=5); okc += 1
            except AssertionError:
                pass
        check('тапы 0.3 с во время фарма: %d/%d назначений/снятий прошли' % (okc, n), okc == n)
        g.cmd('farm:off'); page.wait_for_timeout(500)
        g.click(INV + ' [data-n="Close"]'); page.wait_for_timeout(400)
        # пустой «+» во время фарма: тап по слоту -> тап по предмету -> предмет в слоте
        if cap(g, 5) != 'Пусто':
            open_inv.click(); g.wait(lambda: g.vis(INV), what='inv')
            g.click(INV + ' [data-n="Cell_ticket_MeadowEgg"]'); page.wait_for_timeout(400)
            g.click(INV + ' [data-n="RemoveSlot"]'); g.wait(lambda: cap(g, 5) == 'Пусто', what='clear')
            g.click(INV + ' [data-n="Close"]'); page.wait_for_timeout(400)
        g.cmd('farm:on')
        g.click(S(5)); g.wait(lambda: g.vis(INV), what='inv from +')
        b = page.locator(INV + ' [data-n="Cell_ticket_MeadowEgg"]').first
        b.scroll_into_view_if_needed(); bb = b.bounding_box()
        page.mouse.move(bb['x'] + bb['width'] / 2, bb['y'] + bb['height'] / 2)
        page.mouse.down(); page.wait_for_timeout(300); page.mouse.up()
        try:
            g.wait(lambda: cap(g, 5) == 'Билет', timeout=6); ok = True
        except AssertionError:
            ok = False
        check('«+» → тап по билету во время фарма — билет в слоте 5', ok, cap(g, 5))
        g.cmd('farm:off')
        g.shot('03_assign_while_farming')
    for (w, h) in [(390, 844), (844, 390)]:
        with browser(w, h, True) as ctx:
            page = ctx.new_page(); g = G(page); g.shots = SHOTS
            page.goto(url + 'index.html?persist=0&seed=1&country=RU&lang=ru&attr.DailyAutoOpen=false')
            g.wait(lambda: g.vis('[data-n="Hotbar"]'), timeout=120, what='hotbar')
            g.wait(lambda: not g.vis('[data-n="Dot2"]'), timeout=40, what='loading')
            g.cmd('event:GoldenRain'); g.cmd('item:luck_potion=2'); page.wait_for_timeout(2000)
            hb = rect(page, '[data-n="Hotbar"]')
            bad = [n for n in ('Currency', 'Timer') if overlap(hb, rect(page, '[data-n="%s"]' % n))]
            jump = w - 104 if True else w
            inside = hb[0] >= 0 and hb[2] <= w and hb[3] <= h
            check('%d×%d: хотбар не налезает на кошелёк и таймер' % (w, h), not bad, bad)
            check('%d×%d: внутри экрана и левее кнопки прыжка' % (w, h), inside and hb[2] <= jump + 1, hb)
            s3 = rect(page, S(3))
            check('%d×%d: слот не меньше 36 px' % (w, h), s3[2] - s3[0] >= 36, s3)
            g.shot('03_%dx%d' % (w, h))

print('\n%d OK, %d FAIL' % (oks, len(fails)))
sys.exit(1 if fails else 0)
