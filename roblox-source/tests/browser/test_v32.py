"""v3.2 — браузерная проверка исправлений из списка (эмулятор roblox2web, сайт /tmp/gw_ui с UiDriver).
1) подписи мира: без наложений поверх HUD, подписи ботов мельче и скрываются при наложении;
2) таблички зон/яиц не перекрывают хотбар и кнопки;
3) ПК: текст окон не мельче 12 px (заголовки 14 px) и не обрезается;
4) телефон 390×844 и 844×390: окна в безопасной области (над хотбаром, мимо кнопок HUD), крестик виден,
   магазин прокручивается до кнопок VIP / Боевой пропуск;
5) значки событий — из примитивов (без эмодзи);
6) «Авто» — только у владельца пропуска «Автосбор», в листе «Ещё»;
7) место морского сундука — проверка сервера (chestcheck) и снимок.
Ожидания — по состоянию (атрибуты, DOM), а не по таймерам. Снимки — docs/screens/95_*.
"""
import os, sys, re
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from ui_helpers import *

SHOTS = os.path.join(HERE, '..', '..', 'docs', 'screens')
if '--shots' in sys.argv: SHOTS = sys.argv[sys.argv.index('--shots') + 1]
os.makedirs(SHOTS, exist_ok=True)
fails = []; oks = 0
def check(name, cond, info=''):
    global oks
    if cond:
        oks += 1; print('  ok  ', name)
    else:
        fails.append(name); print('  FAIL', name, str(info)[:400])
def shot(page, name):
    p = os.path.join(SHOTS, name); page.screenshot(path=p); print('shot', p)

RECT = "(q)=>{const e=document.querySelector(q); if(!e) return null; const r=e.getBoundingClientRect(); if(r.width<1) return null; return {x:r.left,y:r.top,w:r.width,h:r.height}}"
WATTR = "(k)=>{const a=R2W.ENV.workspace.attrs; return a? a.get(k): undefined}"
PSCALE = "(n)=>{const pg=R2W.ENV.localPlayer.children.find(c=>c.className==='PlayerGui'); const g=pg&&pg.children.find(c=>c.props.Name==='PetCollectorGui'); if(!g) return null; const f=(x)=>{ if(x.props.Name===n && x.className==='Frame') return x; for(const c of x.children){const r=f(c); if(r) return r;} return null}; const p=f(g); const u=p&&p.children.find(c=>c.className==='UIScale'); return u? u.props.Scale: null}"
CORE = "(k)=>{const pg=R2W.ENV.localPlayer.children.find(c=>c.className==='PlayerGui'); const g=pg&&pg.children.find(c=>c.props.Name==='PetCollectorGui'); return g&&g.attrs? g.attrs.get(k): undefined}"
# текст окна: размер шрифта на экране (с учётом UIScale), обрезка по высоте/ширине (span шире/выше своей рамки)
TEXT = """(sel)=>{const root=document.querySelector(sel); if(!root) return null; const out=[]; let minfs=99, n=0;
 for(const span of root.querySelectorAll('span')){ const host=span.parentElement; const txt=span.textContent.trim(); if(!host||!txt) continue;
  let p=host, vis=true; while(p&&p!==document.body){ const s=getComputedStyle(p); if(s.display==='none'||s.visibility==='hidden'||parseFloat(s.opacity)===0){vis=false;break;} p=p.parentElement;} if(!vis) continue;
  const hr=host.getBoundingClientRect(); if(hr.width<2||hr.height<2) continue;
  let sc=host.parentElement; while(sc&&sc!==root){ const s=getComputedStyle(sc); if(s.overflowY==='auto'||s.overflowY==='scroll') break; sc=sc.parentElement;}
  if(sc&&sc!==root){ const sr=sc.getBoundingClientRect(); if(hr.bottom<sr.top||hr.top>sr.bottom) continue; }
  const fs=parseFloat(getComputedStyle(span).fontSize)*hr.height/(host.offsetHeight||1); n++; if(fs<minfs) minfs=fs;
  const clip=span.scrollHeight>host.clientHeight+2||span.scrollWidth>host.clientWidth+2;
  if(clip||fs<11.5){ const d=host.closest('[data-n]'); out.push((d?d.dataset.n:'')+':'+txt.slice(0,40)+':'+fs.toFixed(1)+(clip?':clip':'')); } }
 return {n:n, minfs:minfs, bad:out};}"""
# v3.2.1: размеры шрифта описаний ([data-n=Desc]) в окне — у всех строк один и тот же (не TextScaled)
DESCFS = """(sel)=>{const root=document.querySelector(sel); if(!root) return []; const out=[];
 for(const d of root.querySelectorAll('[data-n="Desc"]')){ const sp=d.querySelector('span'); if(!sp||!sp.textContent.trim()) continue;
  const r=d.getBoundingClientRect(); if(r.width<2||r.height<2||getComputedStyle(d).display==='none') continue;
  out.push(Math.round(parseFloat(getComputedStyle(sp).fontSize)*r.height/(d.offsetHeight||1)*10)/10); } return out;}"""
# подписи над головами/таблички (BillboardGui) — видимые прямоугольники на экране
BBS = """()=>{const out=[]; for(const d of document.querySelectorAll('div[data-gui]')){ if(getComputedStyle(d.parentElement).zIndex!=='1') continue;
  const s=getComputedStyle(d); if(s.display==='none'||s.visibility==='hidden') continue;
  let txt='', vis=false; for(const sp of d.querySelectorAll('span')){ const st=getComputedStyle(sp); if(sp.textContent.trim() && parseFloat(st.opacity||'1')>0.05){ txt+=sp.textContent.trim()+' '; vis=true; } }
  if(!vis) continue; const r=d.getBoundingClientRect(); if(r.width<2||r.height<2) continue;
  if(r.right<0||r.bottom<0||r.left>innerWidth||r.top>innerHeight) continue;
  out.push({x:r.left,y:r.top,w:r.width,h:r.height,t:txt.trim().slice(0,30),n:d.dataset.gui}); } return out;}"""
EMOJI = re.compile('[\U0001F300-\U0001FAFF\u2600-\u27BF\u23E9-\u23FA\u231A\u231B]')

def inter(a, b, pad=0):
    return a and b and a['x'] < b['x'] + b['w'] - pad and b['x'] < a['x'] + a['w'] - pad and a['y'] < b['y'] + b['h'] - pad and b['y'] < a['y'] + a['h'] - pad

def boot(page, g, url, extra='&attr.BotsDisabled=true'):
    page.goto(url + 'index.html?persist=0&seed=1&lang=ru&country=RU&attr.DailyAutoOpen=false' + extra)
    g.wait(lambda: g.vis('[data-n="Hotbar"]'), timeout=120, what='hotbar')
    g.wait(lambda: not g.vis('[data-n="Dot2"]'), timeout=40, what='loading')
    if g.vis('[data-n="Skip"]'):
        page.locator('[data-n="Skip"]').first.click(force=True)
        g.wait(lambda: not g.vis('[data-n="Skip"]'), what='tutorial off')

def open_panel(page, g, name):
    g.cmd('ui:' + name)
    sel = '[data-n="%sPanel"]' % name
    g.wait(lambda: g.vis(sel), what=name)
    # Окно открывается анимацией масштаба (0.18 с игрового времени): ждём состояния — UIScale окна дошёл
    # до PANEL_SCALE (0.8), а не «размер перестал меняться» (под нагрузкой кадры эмулятора могут стоять)
    g.wait(lambda: abs((page.evaluate(PSCALE, name + 'Panel') or 0) - 0.8) < 0.002, what=name + ' scale')
    g.raf()
    return page.evaluate(RECT, sel)

def close_panel(page, g, name):
    sel = '[data-n="%sPanel"]' % name
    g.click(sel + ' [data-n="Close"]')
    g.wait(lambda: not g.vis(sel), what='close ' + name)

PANELS = ['Shop', 'More', 'Pets', 'Inventory', 'Upgrades', 'Rebirth', 'Talents', 'Craft', 'Market', 'Trade', 'Quests', 'Index', 'Settings', 'Worlds', 'Egg']

with serve('/tmp/gw_ui') as url:
    # ================= ПК 1280×720: текст окон, «Авто», значки событий
    with browser(1280, 720) as ctx:
        page = ctx.new_page(); errs = collect(page); g = G(page)
        boot(page, g, url)
        g.cmd('seed')
        # --- 6) «Авто»
        left = page.evaluate("()=>[...document.querySelectorAll('[data-n=\"LeftButtons\"] > [data-n]')].filter(e=>e.getBoundingClientRect().width>0).map(e=>e.dataset.n)")
        check('левая колонка: Магазин, Индекс, Ещё (без «Авто»)', sorted(left) == ['IndexBtn', 'MoreBtn', 'ShopBtn'], left)
        open_panel(page, g, 'More')
        check('без пропуска «Автосбор» переключателя нет', not g.vis('[data-n="MorePanel"] [data-n="AutoToggle"]'))
        g.cmd('pass:AUTO_COLLECT')
        g.wait(lambda: g.vis('[data-n="MorePanel"] [data-n="AutoToggle"]'), what='auto toggle')
        check('владелец пропуска: «Авто» в листе «Ещё»', True)
        t0 = g.text('[data-n="MorePanel"] [data-n="AutoToggle"]')
        g.click('[data-n="MorePanel"] [data-n="AutoToggle"]')
        g.wait(lambda: g.text('[data-n="MorePanel"] [data-n="AutoToggle"]') != t0, what='toggle text')
        check('переключение «Авто» меняет состояние (%s -> %s)' % (t0, g.text('[data-n="MorePanel"] [data-n="AutoToggle"]')), True)
        g.cmd('pass:-AUTO_COLLECT')
        g.wait(lambda: not g.vis('[data-n="MorePanel"] [data-n="AutoToggle"]'), what='toggle hidden')
        check('пропуск снят — переключатель скрыт', True)
        close_panel(page, g, 'More')
        # --- 3) текст окон на ПК
        worst = 99; bad = []
        for name in PANELS:
            r = open_panel(page, g, name)
            t = page.evaluate(TEXT, '[data-n="%sPanel"]' % name)
            worst = min(worst, t['minfs'])
            bad += [name + '>' + b for b in t['bad']]
            check('ПК %s: окно компактное и в экране (%dx%d)' % (name, r['w'], r['h']), r['w'] <= 460 and r['h'] <= 720 - 20 and r['x'] >= 0 and r['y'] >= 0, r)
            if name in ('Upgrades', 'Talents', 'Shop', 'Worlds'):
                fs = page.evaluate(DESCFS, '[data-n="%sPanel"]' % name)
                check('ПК %s: описания одного размера, не мельче 12 px (%s)' % (name, sorted(set(fs))), len(fs) >= 2 and max(fs) - min(fs) <= 0.5 and min(fs) >= 11.5, fs)
            if name == 'Upgrades':
                shot(page, '95_pc_panel_text.png')
            close_panel(page, g, name)
        check('ПК: текст окон не мельче 12 px (мин. %.1f)' % worst, worst >= 11.5)
        check('ПК: текст окон не обрезается', not bad, bad[:6])
        # --- 5) значки событий
        g.wait(lambda: g.vis('[data-n="NextEvent"]'), what='next event chip')
        icon = page.evaluate("()=>{const e=document.querySelector('[data-n=\"NextEvent\"] [data-n=\"Icon\"]'); return !!e && e.getBoundingClientRect().width>4}")
        check('плашка «следующее событие»: значок луны из примитивов', icon)
        g.cmd('event:GoldenRain')
        g.wait(lambda: g.vis('[data-n="Event_GoldenRain"]'), what='event chip')
        ic = page.evaluate(RECT, '[data-n="Event_GoldenRain"] [data-n="Icon"]')
        check('плашка активного события: значок часов из примитивов', ic and ic['w'] > 4, ic)
        # v3.3: «Дождь монет» — название на плашке и своя музыка, пока событие идёт
        GA = """(k)=>{const pg=R2W.ENV.localPlayer.children.find(c=>c.className==='PlayerGui'); const g=pg&&pg.children.find(c=>c.props.Name==='PetCollectorGui'); return g&&g.attrs? g.attrs.get(k): undefined}"""
        chip_t = g.text('[data-n="Event_GoldenRain"]')
        check('плашка: «Дождь монет» (не «Золотой дождь»)', 'Дождь монет' in chip_t and 'Золот' not in chip_t, chip_t)
        g.wait(lambda: page.evaluate(GA, 'RainActive') is True, what='RainActive')
        g.wait(lambda: page.evaluate(GA, 'MusicTarget') == 'Rain', what='rain music')
        check('во время дождя играет тема «Дождь монет» (MusicTarget = Rain)', True)
        hud_text = page.evaluate("()=>document.querySelector('[data-gui=\"PetCollectorGui\"]').innerText")
        check('в HUD нет эмодзи (🌙, ⏱ и др.)', not EMOJI.search(hud_text), EMOJI.findall(hud_text)[:5])
        shot(page, '95_hud_event_icons.png')
        check('ПК: без ошибок эмулятора', not errs, errs[:3])

    # ================= телефон: окна в безопасной области, магазин до кнопок VIP / пропуска
    for (W, H, tag) in ((390, 844, 'portrait'), (844, 390, 'landscape')):
        with browser(W, H, True) as ctx:
            page = ctx.new_page(); errs = collect(page); g = G(page)
            boot(page, g, url)
            g.cmd('seed')
            hud = {n: page.evaluate(RECT, '[data-n="%s"]' % n) for n in ('LeftButtons', 'RightButtons', 'Hotbar', 'Currency')}
            worst = 99; bad = []
            for name in ('Shop', 'Pets', 'Inventory', 'Quests', 'Market', 'More', 'Talents', 'Index'):
                r = open_panel(page, g, name)
                hits = [n for n, b in hud.items() if inter(r, b, 1)]
                check('%s %s: окно не закрывает %s' % (tag, name, '/'.join(hud)), not hits, (r, hits))
                cl = page.evaluate(RECT, '[data-n="%sPanel"] [data-n="Close"]' % name)
                check('%s %s: крестик виден' % (tag, name), cl and cl['x'] >= 0 and cl['y'] >= 0 and cl['x'] + cl['w'] <= W and cl['y'] + cl['h'] <= H, cl)
                t = page.evaluate(TEXT, '[data-n="%sPanel"]' % name)
                worst = min(worst, t['minfs']); bad += [name + '>' + b for b in t['bad']]
                if name == 'Shop':
                    # прокрутка до конца геймпассов: кнопки VIP и Боевого пропуска видны в окне
                    for key in ('VIP', 'BATTLE_PASS'):
                        page.evaluate("(k)=>{const b=document.querySelector('[data-n=\"ShopPanel\"] [data-n=\"Buy_'+k+'\"]'); b.scrollIntoView({block:'center'});}", key)
                        b = page.evaluate(RECT, '[data-n="ShopPanel"] [data-n="Buy_%s"]' % key)
                        check('%s: кнопка покупки %s видна после прокрутки' % (tag, key), b and r['y'] <= b['y'] and b['y'] + b['h'] <= r['y'] + r['h'] + 1, (b, r))
                    sc = page.evaluate("()=>{const s=document.querySelector('[data-n=\"ShopPanel\"] [data-n=\"Scroll\"]'); return s && getComputedStyle(s).overflowY}")
                    check('%s: список магазина прокручивается' % tag, sc in ('auto', 'scroll'), sc)
                    shot(page, '95_shop_phone_%s.png' % tag)
                close_panel(page, g, name)
            check('%s: текст окон не мельче 12 px (мин. %.1f)' % (tag, worst), worst >= 11.5)
            check('%s: текст окон не обрезается' % tag, not bad, bad[:6])
            check('%s: без ошибок эмулятора' % tag, not errs, errs[:3])

    # ================= подписи мира (с ботами) и место сундука
    with browser(1280, 720) as ctx:
        page = ctx.new_page(); errs = collect(page); g = G(page)
        boot(page, g, url, '')
        def settle():
            # камера после телепорта и раскладка подписей (WorldLabels — раз в 0.1 с игрового времени):
            # ждём 0.6 с игрового времени эмулятора (не настенные часы)
            g.vwait(0.6)
        g.wait(lambda: page.evaluate("()=>{let n=0; const w=(x)=>{ if(x.className==='BillboardGui' && x.attrs && x.attrs.get('LabelKind')==='Bot') n++; for(const c of x.children) w(c);}; w(R2W.ENV.workspace); return n}") >= 2, timeout=90, what='bots')
        g.cmd('look:0,34,0,8')
        settle()
        hudr = [page.evaluate(RECT, '[data-n="%s"]' % n) for n in ('Hotbar', 'LeftButtons', 'RightButtons', 'Currency')]
        bbs = page.evaluate(BBS)
        over_hud = [b['t'] for b in bbs if any(inter(b, h, 2) for h in hudr if h)]
        check('подписи мира не заходят на HUD (%d видно)' % len(bbs), not over_hud, over_hud)
        big = [b for b in bbs if b['h'] > 110]
        check('нет огромных табличек (выше 110 px)', not big, big[:3])
        shot(page, '95_labels.png')
        # вблизи яиц хаба и у таблички мира (яйцо + указатель зоны): раньше надпись закрывала хотбар
        for pos, name in (('0,-64,0,-90', 'яйца хаба'), ('512,40,516,-14', 'табличка мира и яйцо')):
            g.cmd('look:' + pos)
            settle()
            bbs = page.evaluate(BBS)
            over_hud = [b['t'] for b in bbs if any(inter(b, h, 2) for h in hudr if h)]
            check('%s: подписи не перекрывают хотбар и кнопки (%d видно)' % (name, len(bbs)), not over_hud, over_hud)
            big = [b for b in bbs if b['h'] > 110 or b['w'] > 640]
            check('%s: надпись не на пол-экрана' % name, not big, big[:3])
            if pos.startswith('0,'):
                shot(page, '95_zone_titles.png')
        # аудит v3.2: подпись, вынутая из Workspace и вставленная обратно, не уменьшается повторно
        RSIZE = "()=>{let r=null; const w=(x)=>{ if(r) return; if(x.className==='BillboardGui' && x.attrs && x.attrs.get('Relabel')===true){ r=[x.props.Size.xo, x.props.Size.yo]; return;} for(const c of x.children) w(c);}; w(R2W.ENV.workspace); return r}"
        g.cmd('relabel')
        g.wait(lambda: page.evaluate(WATTR, 'RelabelPart') not in (None, ''), what='relabel')
        settle()
        s1 = page.evaluate(RSIZE)
        g.cmd('relabel')
        settle()
        s2 = page.evaluate(RSIZE)
        check('подпись после повторной вставки в Workspace того же размера (%s -> %s)' % (s1, s2), s1 is not None and s1 == s2, (s1, s2))
        # --- 7) морской сундук: проверки места
        for xz, want in (('0,0', False), ('0,26', False)):
            g.cmd('chestcheck:' + xz)
            res = page.evaluate(WATTR, 'SeaChestCheck')
            check('сундук: место %s %s (%s)' % (xz, 'подходит' if want else 'отклонено', res), (res == 'ok') == want, res)
        g.cmd('chest:auto')
        at = page.evaluate(WATTR, 'SeaChestAt')
        check('сундук появился в проверенном месте (%s)' % at, at not in (None, 'none'), at)
        if at not in (None, 'none'):
            x, z = [float(v) for v in at.split(',')]
            check('сундук: не ближе %d студов к точке появления' % 34, ((x - 0) ** 2 + (z - 26) ** 2) ** 0.5 >= 34 - 0.5, at)
            dx, dz = (0 - x), (26 - z)
            dl = max(1e-6, (dx * dx + dz * dz) ** 0.5)
            g.cmd('look:%.1f,%.1f,%.1f,%.1f' % (x + dx / dl * 14, z + dz / dl * 14, x, z))
            settle()
            shot(page, '95_chest_spot.png')
        check('подписи/сундук: без ошибок эмулятора', not errs, errs[:3])

print('\n%d ok, %d failed' % (oks, len(fails)))
if fails:
    print('FAILED:'); [print(' -', f) for f in fails]
    sys.exit(1)
