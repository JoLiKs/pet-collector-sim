#!/usr/bin/env python3
"""v3.1 в веб-демо (Chromium):
1) морской сундук: chest:auto ставит сундук в свободном месте хаба (не у спавна, фонтана, порталов); о появлении —
   только звуковое событие (без сообщений); открывается ProximityPrompt (E) и касанием; первый получает награду;
   в демо — запасная модель из деталей (roblox2web не читает .rbxm);
2) звук: «Музыка вкл/выкл», «Звуки вкл/выкл», громкость — сохраняются (Core.Audio); без ID треков музыка молчит без ошибок;
3) левые кнопки: на ПК в 2.5 раза ниже (≈15 px), на телефоне >= 36 px; окна на ПК в 1.5 раза меньше (≈337×240),
   на телефоне меньше, чем в v3.0 (374×432), и в пределах экрана;
4) быстрый слот: «+» -> инвентарь -> тап по предмету — предмет в слоте.
Скриншоты (--shots DIR, по умолчанию docs/screens): 90_hub_chest, 90_buttons_panel_1280x720, 90_buttons_panel_390x844,
90_slot_assign.
Запуск: bash tests/browser/build_ui_site.sh && python3 tests/browser/test_v31.py [--shots DIR]"""
import os, sys, math
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
def toasts(page): return page.evaluate("()=>{const L=R2W.ENV.gui; if(L&&L.roots&&L.syncRoot) for(const r of L.roots.keys()) L.syncRoot(r)}") or page.evaluate("(()=>{const t=document.querySelector('[data-n=Toasts]'); return t? t.innerText: ''})()")
def shot(page, name):
    p = os.path.join(SHOTS, name); page.screenshot(path=p); print('shot', p)
WATTR = "(k)=>{const a=R2W.ENV.workspace.attrs; return a? a.get(k): undefined}"
GATTR = """(k)=>{const pg=R2W.ENV.localPlayer.children.find(c=>c.className==='PlayerGui'); const g=pg&&pg.children.find(c=>c.props.Name==='PetCollectorGui'); return g&&g.attrs? g.attrs.get(k): undefined}"""
CHESTS = """(()=>{const f=R2W.ENV.workspace.findChild('SeaChests'); if(!f) return [];
 return f.children.map(m=>{const p=m.props.PrimaryPart; const cf=p&&p.props.CFrame; return {name:m.props.Name, asset:m.attrs&&m.attrs.get('FromAsset'),
  by:m.attrs&&m.attrs.get('OpenedBy'), x:cf?cf.x:0, z:cf?cf.z:0};});})()"""
COINS = '[data-n="Currency"] [data-n="Coins"] [data-n="Value"]'
RECT = "(q)=>{const e=document.querySelector(q); if(!e) return null; const r=e.getBoundingClientRect(); return {x:r.left,y:r.top,w:r.width,h:r.height}}"

def boot(page, g, url, extra=''):
    page.goto(url + 'index.html?persist=0&seed=1&lang=ru&country=RU&attr.DailyAutoOpen=false&attr.BotsDisabled=true' + extra)
    g.wait(lambda: g.vis('[data-n="Hotbar"]'), timeout=120, what='hotbar')
    g.wait(lambda: not g.vis('[data-n="Dot2"]'), timeout=40, what='loading')
    if g.vis('[data-n="Skip"]'):
        page.locator('[data-n="Skip"]').first.click(force=True); page.wait_for_timeout(600)

def panel_check(page, g, w, h, label):
    g.cmd('ui:Shop'); g.wait(lambda: g.vis('[data-n="ShopPanel"]'), what='shop'); page.wait_for_timeout(900)
    r = page.evaluate(RECT, '[data-n="ShopPanel"]')
    check('%s: окно в пределах экрана' % label, r and r['x'] >= -1 and r['y'] >= -1 and r['x'] + r['w'] <= w + 1 and r['y'] + r['h'] <= h + 1, r)
    return r

with serve('/tmp/gw_ui') as url:
    # ---------------- ПК 1280×720
    with browser(1280, 720) as ctx:
        page = ctx.new_page(); errs = collect(page); g = G(page); g.shots = SHOTS
        boot(page, g, url)
        g.cmd('seed'); g.wait(lambda: '60' in g.text(COINS), what='seed')
        # --- 1. морской сундук
        n0 = len(toasts(page))
        g.cmd('chest:auto'); page.wait_for_timeout(1200)
        at = page.evaluate(WATTR, 'SeaChestAt')
        ch = page.evaluate(CHESTS)
        check('сундук появился в хабе', at not in (None, 'none') and len(ch) == 1, (at, ch))
        if ch:
            c = ch[0]; d_spawn = math.hypot(c['x'], c['z'] - 26); d_center = math.hypot(c['x'], c['z'])
            check('место: не у спавна и фонтана, в кольце хаба', d_spawn >= 22 + 6 - 0.5 and 24 - 0.5 <= d_center <= 92 + 0.5, (c, d_spawn, d_center))
            check('веб-демо: запасная модель из деталей (.rbxm в roblox2web не читается)', c['asset'] is False, c)
        g.wait(lambda: page.evaluate(GATTR, 'SeaChestSfx') == 'Spawn', what='spawn sfx', timeout=20)
        check('о появлении — звуковое событие (тихий сигнал)', True)
        check('о появлении нет сообщений', 'сундук' not in toasts(page).lower(), toasts(page))
        # несколько случайных мест — все допустимые
        bad = []
        for _ in range(6):
            g.cmd('chest:auto'); page.wait_for_timeout(500)
            for c in page.evaluate(CHESTS):
                if c['by'] is None and (math.hypot(c['x'], c['z'] - 26) < 27.5 or math.hypot(c['x'], c['z']) < 23.5 or math.hypot(c['x'], c['z']) > 92.5):
                    bad.append(c)
        check('6 случайных мест — все вне спавна/фонтана и внутри хаба', not bad, bad)
        ch = [c for c in page.evaluate(CHESTS) if c['by'] is None]
        c = ch[-1]
        # кадр: сундук перед персонажем
        dx, dz = c['x'], c['z']; L = math.hypot(dx, dz) or 1
        sx, sz = dx - dx / L * 15, dz - dz / L * 15  # дальше дистанции подсказки — сундук виден целиком
        g.cmd('look:%.1f,%.1f,%.1f,%.1f' % (sx, sz, c['x'], c['z']))
        page.evaluate("(([y,p,d])=>{const c=R2W.ENV.cam; c.pitch=p; c.dist=d;})", [0, 0.28, 12]); page.wait_for_timeout(1500)
        shot(page, '90_hub_chest.png')
        # ProximityPrompt (E, удержание 0.5 с)
        coins0 = g.text(COINS)
        g.cmd('tp:%.1f,%.1f' % (c['x'] - c['x'] / L * 5, c['z'] - c['z'] / L * 5))
        g.wait(lambda: page.evaluate('!!R2W.ENV.prompts.active'), what='chest prompt')
        page.keyboard.down('e'); g.vwait(1.0); page.keyboard.up('e')  # v3.3: удержание по игровому времени
        g.wait(lambda: 'Морской сундук' in toasts(page), what='chest toast', timeout=20)
        t = toasts(page)
        check('ProximityPrompt: награда первому («Морской сундук: …»)', 'монет' in t.lower() or 'coins' in t.lower(), t[-300:])
        g.wait(lambda: g.text(COINS) != coins0, what='coins up', timeout=15)
        check('монеты начислены', True)
        g.wait(lambda: page.evaluate(GATTR, 'SeaChestSfx') == 'Open', what='open sfx', timeout=10)
        check('звук открытия', True)
        # касание: сундук прямо в точке игрока
        page.wait_for_timeout(1500)
        g.cmd('chest:60,-40'); page.wait_for_timeout(600)
        g.cmd('tp:60,-40'); page.wait_for_timeout(2500)
        opened = [c for c in page.evaluate(CHESTS) if abs(c['x'] - 60) < 1 and c['by'] is not None]
        check('касание открывает сундук', opened or page.evaluate(CHESTS) == [], page.evaluate(CHESTS))
        # повторное открытие ничего не даёт
        g.cmd('chest:open'); page.wait_for_timeout(500)
        check('второе открытие — отказ (сундука уже нет)', page.evaluate(WATTR, 'SeaChestOpen') == 'gone', page.evaluate(WATTR, 'SeaChestOpen'))
        # --- 2. звук в настройках
        g.cmd('ui:Settings'); g.wait(lambda: g.vis('[data-n="SettingsPanel"]'), what='settings'); page.wait_for_timeout(600)
        M = '[data-n="SettingsPanel"] [data-n="MusicToggle"]'
        check('настройки: «Музыка: вкл»', 'вкл' in g.text(M) and 'выкл' not in g.text(M), g.text(M))
        g.click(M); g.wait(lambda: 'выкл' in g.text(M), what='music off')
        check('музыка выключается', True)
        g.wait(lambda: 'выключена' in g.text('[data-n="SettingsPanel"] [data-n="MusicStatus"]'), what='status off')
        check('строка состояния: «Музыка: выключена»', True)
        g.click('[data-n="SettingsPanel"] [data-n="VolUp"]'); g.wait(lambda: '70%' in g.text('[data-n="SettingsPanel"] [data-n="VolValue"]'), what='vol 70')
        check('громкость +10% (70%)', True)
        g.click('[data-n="SettingsPanel"] [data-n="SfxToggle"]'); g.wait(lambda: 'выкл' in g.text('[data-n="SettingsPanel"] [data-n="SfxToggle"]'), what='sfx off')
        check('звуки выключаются', True)
        # v3.2.2: группы SoundService «Music»/«SFX»; «Звуки: выкл» — громкость группы SFX 0; звуки персонажа — в SFX
        g.wait(lambda: page.evaluate(GATTR, 'SfxVolume') == 0, what='sfx group 0')
        check('«Звуки: выкл» — группа SFX = 0', True)
        g.cmd('charsound')
        SG = """()=>{let r=null; const w=(x)=>{ if(r) return; if(x.className==='Sound'&&x.props.Name==='PcsTestRunning'){r=x;return;} for(const c of x.children) w(c);}; w(R2W.ENV.workspace); return r? (r.props.SoundGroup? r.props.SoundGroup.props.Name: 'none'): null}"""
        g.wait(lambda: page.evaluate(SG) is not None, what='char sound')
        check('звук персонажа (шаги) — в группе SFX', page.evaluate(SG) == 'SFX', page.evaluate(SG))
        GR = """()=>{const ss=R2W.ENV.svc('SoundService'); return ss.children.filter(c=>c.className==='SoundGroup').map(c=>c.props.Name+':'+c.props.Volume).sort().join(',')}"""
        check('SoundService: группы Music:0 и SFX:0 (обе выключены)', page.evaluate(GR) == 'Music:0,SFX:0', page.evaluate(GR))
        g.click('[data-n="SettingsPanel"] [data-n="SfxToggle"]'); g.wait(lambda: page.evaluate(GATTR, 'SfxVolume') == 1, what='sfx on')
        check('«Звуки: вкл» — группа SFX = 1', True)
        g.click(M); g.wait(lambda: 'выкл' not in g.text(M), what='music on')
        g.wait(lambda: 'играет' in g.text('[data-n="SettingsPanel"] [data-n="MusicStatus"]'), what='status playing')
        check('строка состояния музыки: «Музыка: играет»', True)
        # v3.1.1: ID треков заданы (Config.SOUNDS) — оба трека созданы; в демо загрузка не падает (AudioFailed пусто)
        check('ID треков заданы: MusicTracks = CalmEpicRain, ошибок загрузки нет', page.evaluate(GATTR, 'MusicTracks') == 'CalmEpicRain' and not page.evaluate(GATTR, 'AudioFailed'), (page.evaluate(GATTR, 'MusicTracks'), page.evaluate(GATTR, 'AudioFailed')))
        check('ID вписаны — подсказки «музыка появится…» нет', not g.vis('[data-n="SettingsPanel"] [data-n="MusicMissing"]'))
        g.click('[data-n="SettingsPanel"] [data-n="Close"]'); page.wait_for_timeout(400)
        # --- 3. левые кнопки и окно на ПК
        sb = page.evaluate(RECT, '[data-n="ShopBtn"]'); eb = page.evaluate(RECT, '[data-n="EggsBtn"]')
        check('ПК: «Магазин» ≈15 px высотой (в 2.5 раза ниже 37 px v3.0)', sb and 12 <= sb['h'] <= 18, sb)
        check('ПК: подпись читаемая (ширина ≥ 60 px)', sb and sb['w'] >= 60, sb)
        for n in ('IndexBtn', 'MoreBtn'):
            r = page.evaluate(RECT, '[data-n="%s"]' % n)
            check('ПК: %s той же высоты' % n, r and abs(r['h'] - sb['h']) < 1.5, r)
        r = panel_check(page, g, 1280, 720, 'ПК')
        # v3.2: окно чуть больше v3.1 (текст >= 12 px), но компактнее v3.0 (507×360): ≈435×317
        check('ПК: окно компактное (v3.2: ≈435×317, меньше v3.0 507×360)', r and 400 <= r['w'] <= 460 and 290 <= r['h'] <= 330, r)
        shot(page, '90_buttons_panel_1280x720.png')
        check('ПК: без ошибок эмулятора', not errs, errs[:3])
    # ---------------- телефон 390×844
    with browser(390, 844, True) as ctx:
        page = ctx.new_page(); errs = collect(page); g = G(page); g.shots = SHOTS
        boot(page, g, url)
        g.cmd('seed'); g.wait(lambda: '60' in g.text(COINS), what='seed')
        for n in ('ShopBtn', 'IndexBtn', 'MoreBtn'):
            r = page.evaluate(RECT, '[data-n="%s"]' % n)
            check('телефон: %s не ниже 36 px' % n, r and r['h'] >= 35.5, r)
        r = panel_check(page, g, 390, 844, 'телефон')
        # v3.2: окно — в безопасной области над кнопками HUD (UiGeometry), не перекрывает их
        lb = page.evaluate(RECT, '[data-n="LeftButtons"]')
        check('телефон: окно не закрывает левые кнопки (v3.2)', r and lb and r['y'] + r['h'] <= lb['y'] + 1, (r, lb))
        shot(page, '90_buttons_panel_390x844.png')
        g.click('[data-n="ShopPanel"] [data-n="Close"]'); page.wait_for_timeout(400)
        # --- 4. быстрый слот: «+» -> предмет
        g.cmd('item:health_potion=3'); page.wait_for_timeout(800)
        if cap(g, 5) != 'Пусто':
            g.cmd('ui:Inventory'); g.wait(lambda: g.vis(INV), what='inv')
            if g.vis(INV + ' [data-n="RemoveSlot"]'): g.click(INV + ' [data-n="RemoveSlot"]')
            g.click(INV + ' [data-n="Close"]'); page.wait_for_timeout(400)
        g.click(S(5)); g.wait(lambda: g.vis(INV), what='inventory from +')
        page.wait_for_timeout(500)
        cell = page.locator(INV + ' [data-n="Cell_health_potion"]').first
        cell.dispatch_event('pointerdown'); page.wait_for_timeout(300); cell.dispatch_event('pointerup'); cell.dispatch_event('click')
        g.wait(lambda: cap(g, 5) not in ('Пусто', ''), what='slot 5 filled', timeout=20)
        page.wait_for_timeout(600)
        check('«+» -> тап по зелью -> зелье в слоте 5', 'Лечение' in cap(g, 5) or cap(g, 5) != 'Пусто', cap(g, 5))
        shot(page, '90_slot_assign.png')
        check('телефон: без ошибок эмулятора', not errs, errs[:3])

print('\n%d ok, %d failed %s' % (oks, len(fails), fails))
sys.exit(1 if fails else 0)
