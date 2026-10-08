#!/usr/bin/env python3
"""v2.8: окно ежедневной награды за вход в веб-демо.
Проверяет: окно само открывается при первом входе — после экрана загрузки и без плашки обучения; 7 карточек,
сегодня — «CLAIM!»; «CLAIM» выдаёт награду (монеты в кошельке, галочка, «Next in ЧЧ:ММ»); после закрытия
обучение возвращается; после перезагрузки в те же сутки окно само НЕ всплывает (сохранение в localStorage);
вручную открывается через «Ещё»; на 390×844 и 844×390 ничего не обрезано.
Запуск:  bash tests/browser/build_ui_site.sh && python3 tests/browser/test_daily.py [--shots DIR]"""
import os, sys, re
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.environ.get('R2W_DIR', '/workspace/roblox2web') + '/tests/browser')
sys.path.insert(0, HERE)
from ui_helpers import *

SHOTS = '/tmp/shots_daily'
if '--shots' in sys.argv: SHOTS = sys.argv[sys.argv.index('--shots') + 1]
os.makedirs(SHOTS, exist_ok=True)
fails = []; oks = 0
def check(name, cond, info=''):
    global oks
    if cond: oks += 1; print('OK  ', name)
    else: fails.append(name); print('FAIL', name, info)

W = '[data-n="DailyPanel"]'
COINS = '[data-n="Currency"] [data-n="Coins"] [data-n="Value"]'

def inside(page, sel):
    """Все карточки, кнопка и крестик целиком внутри экрана."""
    return page.evaluate("""(q)=>{const out=[];const vw=innerWidth,vh=innerHeight;
      for(const n of ['Day1','Day2','Day3','Day4','Day5','Day6','Day7','Claim','Close','Title']){
        const e=document.querySelector(q+' [data-n="'+n+'"]'); if(!e){out.push(n+':нет');continue}
        const r=e.getBoundingClientRect(); if(r.left<0||r.top<0||r.right>vw+0.5||r.bottom>vh+0.5||r.width<8) out.push(n+':'+[r.left,r.top,r.right,r.bottom].map(Math.round))}
      return out}""", sel)

with serve('/tmp/gw_ui') as url:
    with browser(1280, 720) as ctx:
        page = ctx.new_page(); errs = collect(page); g = G(page); g.shots = SHOTS
        page.goto(url + 'index.html?seed=1&country=US')  # persist включён, контекст чистый — первый вход
        g.wait(lambda: g.vis('[data-n="Hotbar"]'), timeout=120, what='hotbar')
        seen_both = False; seen_tut = False
        for _ in range(160):
            if g.vis(W):
                seen_both = seen_both or g.vis('[data-n="Dot2"]')
                seen_tut = seen_tut or g.vis('[data-n="Tutorial"]')
                break
            page.wait_for_timeout(250)
        check('окно открылось само при первом входе', g.vis(W))
        check('не одновременно с экраном загрузки', not seen_both and not g.vis('[data-n="Dot2"]'))
        page.wait_for_timeout(600)
        check('плашка обучения скрыта, пока открыто окно', not g.vis('[data-n="Tutorial"]') and not seen_tut)
        g.shot('01_auto_open')
        check('7 карточек', all(g.vis(W + ' [data-n="Day%d"]' % d) for d in range(1, 8)))
        check('сегодня — «CLAIM!» на карточке дня 1', 'CLAIM' in g.text(W + ' [data-n="Day1"] [data-n="Top"]'))
        check('день 2 — «DAY 2»', 'DAY 2' in g.text(W + ' [data-n="Day2"] [data-n="Top"]'))
        check('день 7 — тайна «???»', g.text(W + ' [data-n="Day7"] [data-n="Amount"]').strip() == '???')
        check('день 1 — «+500» монет', g.text(W + ' [data-n="Day1"] [data-n="Amount"]').strip() == '+500')
        check('кнопка «CLAIM»', g.text(W + ' [data-n="Claim"]').strip() == 'CLAIM')
        check('метка «VIP x2» в шапке', 'VIP x2' in g.text(W + ' [data-n="VipChip"]'))
        check('1280×720: ничего не обрезано', inside(page, W) == [], inside(page, W))
        coins0 = g.text(COINS)
        g.click(W + ' [data-n="Claim"]')
        g.wait(lambda: g.vis(W + ' [data-n="Day1"] [data-n="Done"]'), what='done')
        page.wait_for_timeout(300)
        check('иконки летят в кошелёк', page.locator('[data-n="DailyFly"]').count() >= 1)
        g.wait(lambda: g.text(COINS) != coins0, what='coins')
        check('монеты зачислены (+500)', '500' in g.text(COINS), g.text(COINS))
        txt = g.text(W + ' [data-n="Claim"]')
        check('кнопка «Next in ЧЧ:ММ»', re.search(r'Next in \d\d:\d\d', txt) is not None, txt)
        check('галочка на дне 1', g.vis(W + ' [data-n="Day1"] [data-n="Check"]'))
        page.wait_for_timeout(1200); g.shot('02_claimed')
        g.click(W + ' [data-n="Close"]')
        g.wait(lambda: not g.vis(W), what='closed')
        g.wait(lambda: g.vis('[data-n="Tutorial"]'), timeout=15, what='tutorial back')
        check('после закрытия обучение вернулось', True)
        page.wait_for_timeout(1500)
        # перезагрузка в те же сутки — окно само не всплывает
        page.reload()
        g.wait(lambda: g.vis('[data-n="Hotbar"]'), timeout=120, what='hotbar 2')
        g.wait(lambda: not g.vis('[data-n="Dot2"]'), timeout=40, what='loading gone 2')
        page.wait_for_timeout(5000)
        check('после перезагрузки в те же сутки окно не всплыло', not g.vis(W))
        check('монеты сохранились', '500' in g.text(COINS), g.text(COINS))
        # вручную — через «Ещё»
        g.click('[data-n="MoreBtn"]')
        g.wait(lambda: g.vis('[data-n="MorePanel"]'), what='more')
        g.click('[data-n="MorePanel"] [data-n="Daily"]')
        g.wait(lambda: g.vis(W), what='manual open')
        page.wait_for_timeout(600)
        check('вручную через «Ещё» открывается', g.vis(W))
        check('день 1 отмечен, таймер на кнопке', g.vis(W + ' [data-n="Day1"] [data-n="Done"]') and 'Next in' in g.text(W + ' [data-n="Claim"]'))
        g.click(W + ' [data-n="Claim"]'); page.wait_for_timeout(1500)
        check('повторный «забор» ничего не даёт', '500' in g.text(COINS) and '1,000' not in g.text(COINS) and '1000' not in g.text(COINS), g.text(COINS))
        g.shot('03_manual')
        check('ошибок эмулятора нет', page.evaluate('R2W.ENV.errorCount') == 0, page.evaluate('R2W.ENV.errorCount'))
    for (w, h) in [(390, 844), (844, 390)]:
        with browser(w, h, True) as ctx:
            page = ctx.new_page(); g = G(page); g.shots = SHOTS
            page.goto(url + 'index.html?persist=0&seed=1&country=RU&lang=ru')
            g.wait(lambda: g.vis(W), timeout=120, what='auto open %dx%d' % (w, h))
            page.wait_for_timeout(1000)
            bad = inside(page, W)
            check('%d×%d: окно открылось, ничего не обрезано' % (w, h), bad == [], bad)
            check('%d×%d: «ЗАБРАТЬ», «ДЕНЬ 2»' % (w, h), g.text(W + ' [data-n="Claim"]').strip() == 'ЗАБРАТЬ' and 'ДЕНЬ 2' in g.text(W + ' [data-n="Day2"] [data-n="Top"]'))
            g.shot('04_%dx%d' % (w, h))

print('\n%d OK, %d FAIL' % (oks, len(fails)))
sys.exit(1 if fails else 0)
