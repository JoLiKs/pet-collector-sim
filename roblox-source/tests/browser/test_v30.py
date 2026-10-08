#!/usr/bin/env python3
"""v3.0 в веб-демо (Chromium):
1) ИИ-боты: 10–20 NPC в Workspace.AiBots с меткой «ИИ», в списке игроков только живой игрок, нет сообщений о входе;
2) порталы: арка закрытого мира открывает окно «Миры» с подсказкой, арка открытого — телепорт; у арки есть вихрь;
3) зелья: «Лечение» и «Реген» назначаются в быстрые слоты, лечение мгновенно, реген — таймер «x3 00:0N» и рост HP;
4) интерфейс 1/1.5: на 1280×720, 390×844 и 844×390 всё в пределах экрана, на телефоне кнопки >= 36 px (на ПК >= 24), текст не мельче 9 px.
Скриншоты (--shots DIR, по умолчанию docs/screens): 80_portal, 80_spawn, 80_bots, 80_hud_scaled_1280x720, 80_hud_scaled_390x844.
Запуск: bash tests/browser/build_ui_site.sh && python3 tests/browser/test_v30.py [--shots DIR]"""
import os, sys, re, math
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

S = lambda n: '[data-n="Hotbar"] [data-n="Slot%d"]' % n
INV = '[data-n="InventoryPanel"]'
def cap(g, n): return g.text(S(n) + ' > [data-n="Caption"]').strip()
def cnt(g, n): return g.text(S(n) + ' > [data-n="Count"]').strip()
def toasts(page): return page.evaluate("(()=>{const t=document.querySelector('[data-n=Toasts]'); return t? t.innerText: ''})()")
def shot(page, name):
    p = os.path.join(SHOTS, name); page.screenshot(path=p); print('shot', p)

BOTS = """(()=>{const f=R2W.ENV.workspace.findChild('AiBots'); if(!f) return {n:0, ai:0, names:[]};
 const walk=(i,out)=>{for(const c of i.children){ if(c.className==='TextLabel') out.push(String((c.attrs&&c.attrs.get('Loc_Text'))||'')); walk(c,out);} return out;};
 let ai=0; const names=[]; for(const m of f.children){ const t=walk(m,[]); names.push(m.props.Name); if(t.some(s=>s.startsWith('bot.name_ai'))) ai++; }
 return {n:f.children.length, ai, names};})()"""
HP = """(()=>{const ch=R2W.ENV.localPlayer.props.Character; const h=ch&&ch.children.find(c=>c.className==='Humanoid');
 return h? h.props.Health/h.props.MaxHealth : -1;})()"""
POS = """(()=>{const r=R2W.ENV.localPlayer.props.Character.findChild('HumanoidRootPart').props.CFrame; return [r.x,r.z];})()"""
CAM = "(([y,p,d])=>{const c=R2W.ENV.cam; c.yaw=y; c.pitch=p; c.dist=d;})"

def arch_front(i, n=5, r=85):  # WorldDecor.portalOrigins: дуга радиуса 90, точка перед аркой — на 5 ближе к центру
    a = math.radians(90 + (i - (n + 1) / 2) * 21)
    return r * math.cos(a), r * math.sin(a)

def boot(page, g, url, extra=''):
    page.goto(url + 'index.html?persist=0&seed=1&lang=ru&country=RU&attr.DailyAutoOpen=false' + extra)
    g.wait(lambda: g.vis('[data-n="Hotbar"]'), timeout=120, what='hotbar')
    g.wait(lambda: not g.vis('[data-n="Dot2"]'), timeout=40, what='loading')
    if g.vis('[data-n="Skip"]'):
        page.locator('[data-n="Skip"]').first.click(force=True); page.wait_for_timeout(600)

def assign(page, g, item, slot):
    if not g.vis(INV):
        open_inv = page.locator('[data-n="InventoryBtn"], [data-n="Inventory"]').first
        g.click(S(5)) if cap(g, 5) == 'Пусто' else open_inv.click()
        g.wait(lambda: g.vis(INV), what='inventory')
    g.click(INV + ' [data-n="Cell_%s"]' % item); page.wait_for_timeout(400)
    # v3.1: из пустого слота N предмет кладётся сразу (одним тапом), кнопки «В слот N» уже не нужны
    if g.vis(INV + ' [data-n="ToSlot%d"]' % slot):
        g.click(INV + ' [data-n="ToSlot%d"]' % slot)
    g.wait(lambda: cnt(g, slot).startswith('×') and cap(g, slot) not in ('Пусто', ''), what='slot %d' % slot)

def ui_layout(page, w, h, label, tap=36, left_tap=None):
    # v3.1: левые кнопки на ПК намеренно в 2.5 раза ниже (мышь) — для них свой порог left_tap
    left_tap = left_tap or tap
    r = page.evaluate("""([w,h,tap,ltap])=>{
      const vis=e=>{const s=getComputedStyle(e); const r=e.getBoundingClientRect(); return s.visibility!=='hidden'&&s.display!=='none'&&r.width>0&&r.height>0&&+s.opacity>0.05;};
      const out=[], small=[], tiny=[];
      for(const n of ['Hotbar','Currency','Timer','ShopBtn','IndexBtn','MoreBtn','JumpBtn']){
        const e=document.querySelector('[data-n="'+n+'"]'); if(!e||!vis(e)) continue; const r=e.getBoundingClientRect();
        if(r.left<-1||r.top<-1||r.right>w+1||r.bottom>h+1) out.push(n+':'+[r.left,r.top,r.right,r.bottom].map(Math.round));
      }
      for(const e of document.querySelectorAll('[data-n="Hotbar"] [data-n^="Slot"], [data-n$="Btn"]')){
        if(!vis(e)) continue; const r=e.getBoundingClientRect(); const lim=e.closest('[data-n="LeftButtons"]')?ltap:tap; if(Math.min(r.width,r.height)<lim-0.5) small.push((e.dataset.n||'?')+':'+Math.round(r.width)+'x'+Math.round(r.height));
      }
      for(const e of document.querySelectorAll('[data-n="Hotbar"] *, [data-n="Currency"] *')){
        if(!vis(e)||!e.childNodes.length||![...e.childNodes].some(c=>c.nodeType===3&&c.textContent.trim())) continue;
        const fs=parseFloat(getComputedStyle(e).fontSize); if(fs<9) tiny.push((e.dataset.n||e.tagName)+':'+fs);
      }
      return {out, small, tiny};}""", [w, h, tap, left_tap])
    check('%s: HUD в пределах экрана' % label, not r['out'], r['out'])
    check('%s: кнопки и слоты >= %d px' % (label, tap), not r['small'], r['small'])
    check('%s: текст хотбара/кошелька не мельче 9 px' % label, not r['tiny'], r['tiny'][:6])

with serve('/tmp/gw_ui') as url:
    with browser(1280, 720) as ctx:
        page = ctx.new_page(); errs = collect(page); g = G(page); g.shots = SHOTS
        logs = []; page.on('console', lambda m: logs.append(m.text))
        boot(page, g, url)
        # --- 1. ИИ-боты
        g.wait(lambda: page.evaluate(BOTS)['n'] >= 10, timeout=90, what='bots 10')
        page.wait_for_timeout(3000)
        b = page.evaluate(BOTS)
        check('ИИ-ботов 10–20', 10 <= b['n'] <= 20, b['n'])
        check('у каждого бота метка «ИИ» (bot.name_ai)', b['ai'] == b['n'], b)
        nplayers = page.evaluate("(()=>{const P=R2W.ENV.game.children.find(c=>c.className==='Players'); return P? P.children.filter(c=>c.className==='Player').length : -1})()")
        check('в списке игроков только живой игрок', nplayers == 1, nplayers)
        t = toasts(page)
        check('нет сообщений о входе ботов', not any(nm.split('_', 1)[-1] in t for nm in b['names']) and 'зашёл' not in t, t)
        # кадр с ботами: встать рядом с самой плотной группой ботов в хабе
        best = None
        for _ in range(12):
            pts = page.evaluate("""(()=>{const f=R2W.ENV.workspace.findChild('AiBots'); return f.children.map(m=>{const r=m.findChild('HumanoidRootPart'); return r? [r.props.CFrame.x, r.props.CFrame.z]: null})\n .filter(p=>p);})()""")
            for p0 in pts:
                k = sum(1 for q in pts if math.hypot(q[0] - p0[0], q[1] - p0[1]) < 35)
                if not best or k > best[0]: best = (k, p0)
            if best and best[0] >= 5: break
            page.wait_for_timeout(2500)
        bx, bz = best[1] if best else (0, 0)
        # в биоме арка возврата стоит с +Z от центра — камера с -Z, чтобы она не загораживала кадр
        in_zone = abs(bx) > 300 or abs(bz) > 300
        if in_zone:
            g.cmd('look:%.1f,%.1f,%.1f,%.1f' % (bx, bz - 12, bx, bz)); page.evaluate(CAM, [math.pi - 0.3, 0.55, 34])
        else:
            g.cmd('look:%.1f,%.1f,%.1f,%.1f' % (bx + 6, bz + 14, bx, bz)); page.evaluate(CAM, [0.3, 0.5, 34])
        page.wait_for_timeout(1500)
        print('bots near', best)
        shot(page, '80_bots.png')
        # --- 2. Площадь спавна и порталы
        g.cmd('look:0,30,0,0'); page.evaluate(CAM, [0, 0.42, 22]); page.wait_for_timeout(2500)
        shot(page, '80_spawn.png')
        g.cmd('look:0,52,0,90'); page.evaluate(CAM, [math.pi, 0.2, 30]); page.wait_for_timeout(2500)
        shot(page, '80_portal.png')
        fx, fz = arch_front(2)  # Forest — закрыт
        g.cmd('tp:%.1f,%.1f' % (fx, fz))
        g.wait(lambda: page.evaluate('!!R2W.ENV.prompts.active'), what='forest prompt')
        page.keyboard.press('e')
        g.wait(lambda: g.vis('[data-n="WorldsPanel"]') or g.vis('[data-n="ZonesPanel"]'), timeout=15, what='worlds panel')
        t = toasts(page)
        check('арка закрытого мира: окно «Миры» и подсказка', 'закрыт' in t, t)
        page.keyboard.press('Escape'); page.wait_for_timeout(400)
        for sel in ('[data-n="WorldsPanel"] [data-n="Close"]', '[data-n="ZonesPanel"] [data-n="Close"]'):
            if g.vis(sel): g.click(sel)
        page.wait_for_timeout(600)
        mx, mz = arch_front(1)  # Meadow — открыт
        g.cmd('tp:%.1f,%.1f' % (mx, mz)); page.wait_for_timeout(1500)
        g.wait(lambda: page.evaluate('!!R2W.ENV.prompts.active'), what='meadow prompt')
        page.keyboard.press('e')
        g.wait(lambda: page.evaluate(POS)[0] > 400, timeout=20, what='teleport meadow')
        p = page.evaluate(POS)
        check('арка открытого мира переносит в мир', abs(p[0] - 520) < 30 and abs(p[1] - 38) < 20, p)
        # --- 3. Зелья
        g.cmd('tp:0,26'); page.wait_for_timeout(800)
        g.cmd('item:health_potion=2'); g.cmd('item:regen_potion=2'); page.wait_for_timeout(600)
        assign(page, g, 'health_potion', 5)
        check('слот 5: «Лечение» ×2', cap(g, 5) == 'Лечение' and cnt(g, 5) == '×2', (cap(g, 5), cnt(g, 5)))
        g.click(INV + ' [data-n="Cell_regen_potion"]'); page.wait_for_timeout(400)
        g.click(INV + ' [data-n="ToSlot4"]')
        g.wait(lambda: cap(g, 4) == 'Реген', what='regen slot')
        check('слот 4: «Реген» ×2', cnt(g, 4) == '×2', cnt(g, 4))
        g.click(INV + ' [data-n="Close"]'); page.wait_for_timeout(500)
        g.cmd('hp:0.25'); page.wait_for_timeout(600)
        h0 = page.evaluate(HP)
        g.click(S(5))
        g.wait(lambda: page.evaluate(HP) > h0 + 0.5, timeout=10, what='heal')
        h1 = page.evaluate(HP)
        check('лечение: мгновенно +70%% (%.2f → %.2f)' % (h0, h1), h1 >= 0.9, (h0, h1))
        try: g.wait(lambda: cnt(g, 5) == '×1', timeout=8, what='count 1')
        except AssertionError: pass
        check('лечение: ×1 в слоте', cnt(g, 5) == '×1', cnt(g, 5))
        g.cmd('hp:1'); page.wait_for_timeout(400)
        g.click(S(5)); page.wait_for_timeout(700)
        check('при полном здоровье зелье не тратится', cnt(g, 5) == '×1' and 'здоров' in toasts(page).lower(), toasts(page))
        g.cmd('hp:0.3'); page.wait_for_timeout(400)
        h2 = page.evaluate(HP); t0 = page.evaluate('R2W.ENV.rt.now')
        g.click(S(4))
        g.wait(lambda: re.search(r'x3 00:0\d', cap(g, 4)) is not None, timeout=10, what='regen timer')
        check('реген: таймер «x3 00:0N» на слоте', True, cap(g, 4))
        check('реген: полоса убывания', g.vis(S(4) + ' [data-n="BoostBar"]'))
        page.wait_for_timeout(700)
        shot(page, '80_hud_scaled_1280x720.png')
        g.vwait(5.5)
        h3 = page.evaluate(HP); dt = page.evaluate('R2W.ENV.rt.now') - t0
        check('реген x3: +~15%% за 5 с (%.2f → %.2f за %.1f с)' % (h2, h3, dt), h3 - h2 >= 0.12, (h2, h3, dt))
        check('реген закончился — слот снова «Реген»', cap(g, 4) == 'Реген', cap(g, 4))
        ui_layout(page, 1280, 720, '1280×720 (мышь)', tap=24, left_tap=14)
        check('ошибок эмулятора нет', page.evaluate('R2W.ENV.errorCount') == 0, page.evaluate('R2W.ENV.errorCount'))
        check('в консоли нет ошибок', not errs, errs[:3])
    for (w, h) in [(390, 844), (844, 390)]:
        with browser(w, h, True) as ctx:
            page = ctx.new_page(); g = G(page); g.shots = SHOTS
            boot(page, g, url, '&attr.BotsDisabled=true')
            g.cmd('item:health_potion=2'); g.cmd('item:regen_potion=1'); g.cmd('item:luck_potion=2'); page.wait_for_timeout(600)
            assign(page, g, 'health_potion', 5)
            g.click(INV + ' [data-n="Cell_regen_potion"]'); page.wait_for_timeout(400)
            g.click(INV + ' [data-n="ToSlot4"]'); g.wait(lambda: cap(g, 4) == 'Реген', what='regen slot')
            g.click(INV + ' [data-n="Close"]'); page.wait_for_timeout(500)
            g.click(S(3)); g.cmd('hp:0.4'); page.wait_for_timeout(300); g.click(S(4))
            g.wait(lambda: re.search(r'x3 00:0\d', cap(g, 4)) is not None, timeout=10, what='regen timer')
            page.wait_for_timeout(600)
            if (w, h) == (390, 844): shot(page, '80_hud_scaled_390x844.png')
            else: g.shot('80_hud_scaled_844x390')
            ui_layout(page, w, h, '%d×%d' % (w, h))

print('\n%d ok, %d failed %s' % (oks, len(fails), fails))
sys.exit(1 if fails else 0)
