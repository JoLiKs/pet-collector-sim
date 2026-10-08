#!/usr/bin/env python3
"""Chromium: удар выглядит ударом. Атака без врага рисует меч и дугу (инстансы ClientFx), рука поднята через Motor6D,
тоста и эмодзи ⚔ нет; удар по врагу даёт вспышку/искры и урон. Кадр в середине замаха ловится паузой эмулятора
(R2W.ENV.paused). v2.5: меч — настоящий Tool из хотбара (Q / клик по миру). Скриншоты: 21_swing.png, 21b_hit.png.
v2.6: замах измеряется покадрово (пауза + R2W.ENV.frame(0.04)): позиции меча (Handle) и правой руки в системе HumanoidRootPart
до удара и во время — для атаки в воздух, удара по врагу и удара по суперигроку; кадр середины замаха — 21c_swing_mid.png.
Запуск: bash tests/browser/build_ui_site.sh && python3 tests/browser/test_swing.py [--shots DIR]"""
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
FXQ = """(()=>{const f=R2W.ENV.workspace.findChild('ClientFx'); const r={arc:0,glow:0,sword:0,flash:0,spark:0};
 const ch=R2W.ENV.localPlayer.props.Character; if(ch && ch.children.some(x=>x.className==='Tool'&&x.props.Name==='Sword')) r.sword++;
 if(!f) return r; for(const c of f.children){const n=c.props.Name, vis=c.props.Transparency<1;
 if(n==='SlashArc'&&vis) r.arc++; if(n==='SlashGlow'&&vis) r.glow++; if(n==='SwordBlade') r.sword++; if(n==='HitFlash') r.flash++; if(n==='HitSpark') r.spark++;} return r;})()"""
ARM = """(()=>{const ch=R2W.ENV.localPlayer.props.Character; const a=ch.findChild('Right Arm').props.CFrame, r=ch.findChild('HumanoidRootPart').props.CFrame;
 const d=[a.x-r.x,a.y-r.y,a.z-r.z]; const R=r.r; return [R[0]*d[0]+R[3]*d[1]+R[6]*d[2], R[1]*d[0]+R[4]*d[1]+R[7]*d[2], R[2]*d[0]+R[5]*d[1]+R[8]*d[2]];})()"""
# камера сбоку от персонажа (кадр на паузе, рендер идёт)
SIDE = """(()=>{const R=R2W.ENV.localPlayer.props.Character.findChild('HumanoidRootPart').props.CFrame.r; const fx=-R[2], fz=-R[8];
 const sx=fz*1+fx*0.35, sz=-fx*1+fz*0.35; R2W.ENV.cam.yaw=Math.atan2(sx,sz); R2W.ENV.cam.pitch=0.28; R2W.ENV.cam.dist=13;})()"""
# поза в системе HumanoidRootPart: правая рука и рукоять меча-Tool (если в руке)
POSE = """(()=>{const ch=R2W.ENV.localPlayer.props.Character; const r=ch.findChild('HumanoidRootPart').props.CFrame, R=r.r;
 const loc=c=>{const d=[c.x-r.x,c.y-r.y,c.z-r.z]; return [R[0]*d[0]+R[3]*d[1]+R[6]*d[2], R[1]*d[0]+R[4]*d[1]+R[7]*d[2], R[2]*d[0]+R[5]*d[1]+R[8]*d[2]];};
 const t=ch.children.find(x=>x.className==='Tool'&&x.props.Name==='Sword'); const h=t&&t.findChild('Handle');
 return {arm:loc(ch.findChild('Right Arm').props.CFrame), handle:h? loc(h.props.CFrame): null, root:[r.x,r.y,r.z]};})()"""
def dist(a, b): return sum((a[i] - b[i]) ** 2 for i in range(3)) ** 0.5
def measure(page, trigger, shot=None, g=None):
    """Пауза → поза покоя (меч уже в руке) → удар → 9 кадров по 0.04 с. Возвращает макс. смещение меча и руки."""
    page.evaluate('R2W.ENV.paused=true'); page.wait_for_timeout(250)
    page.evaluate('R2W.ENV.frame(0.04); R2W.ENV.frame(0.04)')  # поза покоя устоялась (риг догнал HumanoidRootPart)
    rest = page.evaluate(POSE); trigger(); page.wait_for_timeout(150)
    dh = da = 0.0; prev = rest['root']; jumps = 0
    for i in range(9):
        page.evaluate('R2W.ENV.frame(0.04); R2W.ENV.gui.flush()')
        p = page.evaluate(POSE)
        jumped = dist(p['root'], prev) > 1.5; prev = p['root']
        if jumped: jumps += 1; continue  # отброс/телепорт: риг догоняет корень через кадр — этот кадр не считаем
        da = max(da, dist(p['arm'], rest['arm']))
        if p['handle'] and rest['handle']: dh = max(dh, dist(p['handle'], rest['handle']))
        if shot and i == 2: page.evaluate(SIDE.replace('fz*1+fx*0.35','fz*0.6-fx*0.8').replace('-fx*1+fz*0.35','-fx*0.6-fz*0.8')); page.wait_for_timeout(400); g.shot(shot)
    page.evaluate('R2W.ENV.paused=false')
    return {'sword': round(dh, 2), 'arm': round(da, 2), 'rest_handle': bool(rest['handle']), 'jumps': jumps}
def catch(g, page, need):
    for _ in range(60):
        r = page.evaluate(FXQ)
        if need(r): page.evaluate('R2W.ENV.paused=true'); return r
        page.wait_for_timeout(10)
    return page.evaluate(FXQ)
with serve('/tmp/gw_ui') as url, browser() as ctx:
    page = ctx.new_page(); errs = collect(page); g = G(page); g.shots = SHOTS
    page.goto(url + 'index.html?persist=0&seed=1&country=US')
    g.wait(lambda: g.vis('[data-n="Hotbar"]'), timeout=120, what='hotbar'); page.wait_for_timeout(2000)
    g.cmd('seed'); g.cmd('tp:615,-70'); g.vwait(1.0)   # край луга, рядом никого
    got = None
    for attempt in range(5):
        page.keyboard.press('q')  # Q — удар мечом из хотбара (сам берёт меч в руку)
        r = catch(g, page, lambda r: r['arc'] >= 6 and r['sword'] >= 1)
        if r['arc'] >= 6: got = r; break
        page.wait_for_timeout(500)
    check('атака в воздух: дуга удара (SlashArc) видна', bool(got) and got['arc'] >= 6, got)
    check('атака в воздух: меч в руке', bool(got) and got['sword'] >= 1, got)
    arm = page.evaluate(ARM)
    check('рука поднята замахом (Motor6D)', arm[1] > 0.3 or arm[2] < -0.3, arm)
    page.evaluate(SIDE.replace('fz*1+fx*0.35','fz*0.6-fx*0.8').replace('-fx*1+fz*0.35','-fx*0.6-fz*0.8')); page.wait_for_timeout(400); g.shot('21_swing')
    page.evaluate('R2W.ENV.paused=false'); g.vwait(0.6)
    toast = page.evaluate("(()=>{const t=document.querySelector('[data-n=Toasts]'); return t? t.innerText: ''})()")
    check('нет тоста «No enemy»', 'No enemy' not in toast and 'Too far' not in toast, toast)
    check('нет эмодзи ⚔ в эффектах/тостах', '⚔' not in toast and page.locator('[data-n="Fx_Swing"]').count() == 0)
    left = page.evaluate(FXQ)
    check('эффекты убираются после удара (меч остаётся в руке как Tool)', left['arc'] == 0, left)
    # v2.6: покадровый замах до/во время удара — меч уже в руке (Tool), рука и меч должны заметно сдвинуться
    g.vwait(0.6)
    m = measure(page, lambda: page.keyboard.press('q'), shot='21c_swing_mid', g=g); print('    замах:', m)
    check('замах в воздух: меч (Handle) смещается > 1.5 стада', m['rest_handle'] and m['sword'] > 1.5, m)
    check('замах в воздух: плечо/рука смещается > 0.9 стада', m['arm'] > 0.9, m)
    g.vwait(0.6)
    # попадание по врагу
    g.cmd('tpenemy'); g.vwait(0.4)
    hit = None
    for _ in range(8):
        g.cmd('tpenemy'); g.vwait(0.3)
        page.mouse.click(640, 330)  # с мечом в руке — клик по миру
        r = catch(g, page, lambda r: r['flash'] >= 1 and r['spark'] >= 4 and r['arc'] >= 5)
        if r['flash'] >= 1: hit = r; break
        g.vwait(0.3)
    check('попадание: вспышка и искры', bool(hit), hit)
    page.evaluate(SIDE); page.wait_for_timeout(400); g.shot('21b_hit'); page.evaluate('R2W.ENV.paused=false')
    g.vwait(0.6); g.cmd('tpenemy'); g.vwait(0.5)
    m = measure(page, lambda: page.mouse.click(640, 330)); print('    замах:', m)
    check('удар по врагу: меч и рука делают замах', m['sword'] > 1.5 and m['arm'] > 0.9, m)
    # удар по суперигроку (бот с суперсилой)
    g.cmd('super:bot'); g.vwait(1.5); g.cmd('super:near'); g.vwait(0.8)
    m = measure(page, lambda: page.keyboard.press('q')); print('    замах:', m)
    check('удар по суперигроку: меч и рука делают замах', 1.5 < m['sword'] < 8 and 0.9 < m['arm'] < 5, m)
    g.cmd('super:end'); g.vwait(0.5)
    check('ошибок эмулятора нет', page.evaluate('R2W.ENV.errorCount') == 0)
    check('ошибок консоли нет', not errs, errs[:3])
print('\n%d ok, %d failed' % (oks, len(fails)), fails)
sys.exit(1 if fails else 0)
