#!/usr/bin/env python3
"""Chromium: событие «Суперсила / Охота» в веб-демо (боты включены патчем DEMO_BOTS).
1) суперсила у бота → у игрока задание «Останови…», карточка с HP и таймером, стрелка-указатель и 3D-стрелка;
   удары кнопкой УДАР снижают HP суперигрока, после остановки — баннер, взрыв частиц и награда;
2) суперсила у игрока → рост, аура (оболочка, кольцо, свет), задание «Продержись», ударная волна по кнопке;
   по таймеру — «ПОБЕДА!» и крупная награда.
Цикл ускоряется командами UiDriver (атрибуты Workspace SuperpowerForce / SuperpowerTimeScale).
Скриншоты: 23_super_me.png, 24_super_hunt.png, 25_super_stop.png.
Запуск: bash tests/browser/build_ui_site.sh && python3 tests/browser/test_super.py [--shots DIR]"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.environ.get('R2W_DIR', '/workspace/roblox2web') + '/tests/browser'); sys.path.insert(0, HERE)
from ui_helpers import *
SHOTS = os.path.join(HERE, '..', '..', 'docs', 'screens')
if '--shots' in sys.argv: SHOTS = sys.argv[sys.argv.index('--shots') + 1]
os.makedirs(SHOTS, exist_ok=True)
fails = []; oks = 0
def check(name, cond, info=''):
    global oks
    if cond: oks += 1; print('OK  ', name)
    else: fails.append(name); print('FAIL', name, info)

# суперигрок: модель с атрибутом Super (бот в Workspace.Bots или персонаж игрока)
TARGET = """(()=>{const ws=R2W.ENV.workspace; const pick=m=>m&&m.attrs&&m.attrs.get('Super')===true;
 const ch=R2W.ENV.localPlayer.props.Character; const b=ws.findChild('Bots'); let m=null;
 if(pick(ch)) m=ch; else if(b) for(const c of b.children) if(pick(c)) m=c;
 if(!m) return null; const r=m.findChild('HumanoidRootPart').props.CFrame;
 return {name:m.props.Name, hp:m.attrs.get('SuperHp'), max:m.attrs.get('SuperMaxHp'), x:r.x, y:r.y, z:r.z, scale:m.scaleFactor||1, me:m===ch};})()"""
FX = """(()=>{const f=R2W.ENV.workspace.findChild('ClientFx'); const r={};
 if(!f) return r; for(const c of f.children){const n=c.props.Name; if(c.props.Transparency<1) r[n]=(r[n]||0)+1;} return r;})()"""
ME = """(()=>{const ch=R2W.ENV.localPlayer.props.Character; const r=ch.findChild('HumanoidRootPart').props.CFrame;
 const h=ch.findChildOfClass? null: null; return {x:r.x,y:r.y,z:r.z, scale:ch.scaleFactor||1};})()"""
def toasts(page): return page.evaluate("(()=>{const t=document.querySelector('[data-n=Toasts]'); return t? t.innerText: ''})()")
def card(page): return page.evaluate("(()=>{const t=document.querySelector('[data-n=HuntCard]'); return t && t.offsetParent!==null ? t.innerText: ''})()")

with serve('/tmp/gw_ui') as url, browser() as ctx:
    page = ctx.new_page(); errs = collect(page); g = G(page); g.shots = SHOTS
    page.goto(url + 'index.html?persist=0&seed=1&country=RU')
    g.wait(lambda: g.vis('[data-n="Hotbar"]'), timeout=120, what='hotbar'); page.wait_for_timeout(2000)
    g.cmd('seed'); g.cmd('tp:0,10'); g.vwait(1.0)
    nb = page.evaluate("(()=>{const b=R2W.ENV.workspace.findChild('Bots'); return b? b.children.length: 0})()")
    check('в демо есть 3 бота-игрока (DEMO_BOTS)', nb == 3, nb)

    # ---------- 1. суперсила у бота: охота ----------
    g.cmd('super:bot')
    g.wait(lambda: page.evaluate(TARGET) is not None, what='bot super')
    g.vwait(1.0)
    t = page.evaluate(TARGET)
    check('суперигрок-бот вырос', t and t['scale'] > 1.5, t)
    g.wait(lambda: 'ОХОТА' in card(page), what='hunt card')
    c = card(page)
    check('задание «Останови …!» в карточке', 'Останови' in c, c)
    check('баннер «СУПЕРСИЛА!» в стеке', 'СУПЕРСИЛА' in toasts(page), toasts(page))
    # отходим подальше: указатель и 3D-стрелка
    g.cmd('tp:%d,%d' % (t['x'] + 45, t['z'] + 25)); g.vwait(1.2)
    check('экранная стрелка-указатель видна', g.vis('[data-n="HuntPointer"] [data-n="Shaft"]'))
    ptxt = page.evaluate("(()=>{const l=document.querySelector('[data-n=HuntPointer] [data-n=Label]'); return l? l.innerText: ''})()")
    check('у стрелки дистанция в метрах', ' м' in ptxt, ptxt)
    fx = page.evaluate(FX)
    check('3D-стрелка над персонажем', fx.get('HuntArrow', 0) == 1 and fx.get('HuntArrowHead', 0) == 2, fx)
    check('аура суперигрока (оболочка + кольцо)', fx.get('SuperAura', 0) == 1 and fx.get('SuperRing', 0) >= 10, fx)
    page.evaluate('R2W.ENV.paused=true'); page.wait_for_timeout(500); g.shot('24_super_hunt'); page.evaluate('R2W.ENV.paused=false')

    # удары по суперигроку: v2.5 — меч из хотбара (Q / клик по миру), кнопки «УДАР» больше нет
    hp0 = page.evaluate(TARGET)['hp']; low = hp0; stopped = False; shot_stop = False
    for i in range(420):  # до конца раунда (клавиша Q быстрее старого клика по кнопке)
        if i % 3 == 0: g.cmd('super:near')
        page.keyboard.press('q'); page.wait_for_timeout(120)
        t = page.evaluate(TARGET)
        if t is None:
            stopped = True
            break
        low = min(low, t['hp'] or low)
        if i % 10 == 0: print('   hp', t['hp'], '/', t['max'], 't=%.1f' % page.evaluate('R2W.ENV.rt.now'), card(page).replace('\n', ' | '))
    check('удары охотника снижают HP суперигрока', low < hp0, (hp0, low))
    # кадр остановки: ловим взрыв частиц
    for _ in range(40):
        fx = page.evaluate(FX)
        if fx.get('StopParticle', 0) >= 8: page.evaluate('R2W.ENV.paused=true'); shot_stop = True; break
        page.wait_for_timeout(25)
    check('суперигрок остановлен', stopped, toasts(page))
    check('взрыв частиц при остановке', shot_stop, fx)
    page.evaluate('R2W.ENV.cam.dist=20; R2W.ENV.cam.pitch=0.7')  # сверху: боты не загораживают кадр
    page.wait_for_timeout(400); g.shot('25_super_stop'); page.evaluate('R2W.ENV.paused=false')
    g.wait(lambda: 'ОХОТА УДАЛАСЬ' in toasts(page), timeout=10, what='stop banner')
    check('баннер «ОХОТА УДАЛАСЬ!»', 'ОХОТА УДАЛАСЬ' in toasts(page))
    check('награда охотнику', 'Награда' in toasts(page), toasts(page))
    g.vwait(2.0)
    check('карточка охоты скрылась', card(page) == '', card(page))

    # ---------- 2. суперсила у игрока ----------
    g.vwait(4.5)   # баннеры прошлого раунда уходят
    g.cmd('tp:-40,60'); g.vwait(0.8)   # открытое место у домиков ботов (без табличек хаба в кадре)
    g.cmd('super:me')
    g.wait(lambda: 'СУПЕРСИЛА' in card(page), what='me card')
    g.vwait(1.2)
    me = page.evaluate(ME)
    check('игрок вырос (Model:ScaleTo)', me['scale'] > 1.5, me)
    fx = page.evaluate(FX)
    check('аура на игроке: оболочка, кольцо', fx.get('SuperAura', 0) == 1 and fx.get('SuperRing', 0) >= 10, fx)
    check('PointLight в ауре', page.evaluate("(()=>{const f=R2W.ENV.workspace.findChild('ClientFx'); const a=f&&f.findChild('SuperAura'); return !!(a&&a.findChild('SuperLight'))})()"))
    check('задание «Продержись»', 'Продержись' in card(page), card(page))
    check('баннер «СУПЕРСИЛА ТВОЯ!»', 'СУПЕРСИЛА ТВОЯ' in toasts(page), toasts(page))
    check('стрелки к себе нет', not g.vis('[data-n="HuntPointer"] [data-n="Shaft"]'))
    g.vwait(4.6)   # боты подбегают, баннер уходит
    wave = None
    for _ in range(6):
        page.keyboard.press('q')
        for _ in range(30):
            fx = page.evaluate(FX)
            if fx.get('ShockShard', 0) >= 10: wave = fx; page.evaluate('R2W.ENV.paused=true'); break
            page.wait_for_timeout(15)
        if wave: break
        g.vwait(2.4)
    check('ударная волна по удару мечом (Q)', bool(wave), fx)
    page.evaluate('R2W.ENV.cam.dist=26; R2W.ENV.cam.pitch=0.35')
    page.wait_for_timeout(400); g.shot('23_super_me'); page.evaluate('R2W.ENV.paused=false')
    t = page.evaluate(TARGET)
    for _ in range(8):
        if t and t['hp'] < t['max']: break
        g.vwait(1.0); t = page.evaluate(TARGET)
    check('боты-охотники бьют суперигрока', t and t['hp'] < t['max'], t)
    # v2.4 (аудит К1): награда за удержание — только активному суперигроку (≥ 2 ударных волн или движение)
    g.vwait(2.4); page.keyboard.press('q'); g.vwait(0.5)
    g.cmd('super:end')
    g.wait(lambda: 'ПОБЕДА' in toasts(page) or 'ТЕБЯ ОСТАНОВИЛИ' in toasts(page), timeout=15, what='end banner')
    tt = toasts(page)
    check('итог раунда игрока: баннер', 'ПОБЕДА' in tt or 'ТЕБЯ ОСТАНОВИЛИ' in tt, tt)
    check('награда за удержание суперсилы', 'ПОБЕДА' not in tt or 'Награда' in tt, tt)
    g.vwait(1.5)
    me = page.evaluate(ME)
    check('размер игрока вернулся', abs(me['scale'] - 1) < 1e-6, me)
    check('аура убрана', page.evaluate(FX).get('SuperAura', 0) == 0)
    check('ошибок эмулятора нет', page.evaluate('R2W.ENV.errorCount') == 0)
    check('ошибок консоли нет', not errs, errs[:3])
print('\n%d ok, %d failed' % (oks, len(fails)), fails)
sys.exit(1 if fails else 0)
