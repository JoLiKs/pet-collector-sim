#!/usr/bin/env python3
"""Браузерный (Chromium) тест реальной игры: Luau-код -> транспилятор -> эмулятор. Кликает по интерфейсу.
Запуск:  bash tests/browser/build_ui_site.sh && python3 tests/browser/test_game_ui.py [--shots DIR]
Печатает OK/FAIL по шагам, сохраняет скриншоты (по умолчанию docs/screens)."""
import os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.environ.get('R2W_DIR', '/workspace/roblox2web') + '/tests/browser')
sys.path.insert(0, HERE)
from ui_helpers import *

SHOTS = os.path.join(HERE, '..', '..', 'docs', 'screens')
if '--shots' in sys.argv: SHOTS = sys.argv[sys.argv.index('--shots') + 1]
os.makedirs(SHOTS, exist_ok=True)
fails = []; oks = 0
def open_panel(n):
    """Раздел из HUD: справа/слева — прямые кнопки, остальное — через «Ещё»."""
    direct = {'Pets': 'PetsBtn', 'Quests': 'QuestsBtn', 'Shop': 'ShopBtn', 'Index': 'IndexBtn'}
    if n in direct:
        g.click('[data-n="%s"]' % direct[n]); return
    g.click('[data-n="MoreBtn"]'); g.wait(lambda: g.vis('[data-n="MorePanel"] [data-n="%s"]' % n), what='more ' + n)
    g.click('[data-n="MorePanel"] [data-n="%s"]' % n)
def check(name, cond, info=''):
    global oks
    if cond: oks += 1; print('OK  ', name)
    else: fails.append(name); print('FAIL', name, info)

with serve('/tmp/gw_ui') as url, browser() as ctx:
    page = ctx.new_page(); errs = collect(page); g = G(page); g.shots = SHOTS
    page.goto(url + 'index.html?persist=0&seed=1&country=US&attr.DailyAutoOpen=false')
    g.wait(lambda: g.vis('[data-n="Hotbar"]'), timeout=120, what='hotbar')
    check('HUD загружен, ошибок эмулятора нет', page.evaluate('R2W.ENV.errorCount') == 0)
    g.vwait(1.5)  # v3.2: ожидания — по игровому времени и состоянию, а не по настенным часам
    g.shot('01_hub')
    # v2.5: компактный HUD как в Roblox-симуляторах — без сетки из 12 кнопок и без кнопки «УДАР»
    for n in ['ShopBtn', 'IndexBtn', 'MoreBtn']:
        check('слева: ' + n, g.vis('[data-n="LeftButtons"] [data-n="%s"]' % n))
    for n in ['EggsBtn', 'PetsBtn', 'QuestsBtn', 'InventoryBtn']:
        check('справа: ' + n, g.vis('[data-n="RightButtons"] [data-n="%s"]' % n))
    check('валюты слева снизу', g.vis('[data-n="Currency"] [data-n="Coins"]') and g.vis('[data-n="Currency"] [data-n="Gems"]'))
    check('хотбар: 3 слота', all(g.vis('[data-n="Hotbar"] [data-n="Slot%d"]' % i) for i in (1, 2, 3)))
    # v2.6: иконки валют и хотбара — из примитивов GUI (не эмодзи): контейнер Icon со слоями-фреймами
    NLAYERS = "(sel)=>{const e=document.querySelector(sel); return e? e.querySelectorAll('div').length: 0}"
    for sel in ['[data-n="Currency"] [data-n="Coins"] [data-n="Icon"]', '[data-n="Currency"] [data-n="Gems"] [data-n="Icon"]',
                '[data-n="Hotbar"] [data-n="Slot1"] [data-n="Icon"]', '[data-n="Hotbar"] [data-n="Slot2"] [data-n="Icon"]',
                '[data-n="Hotbar"] [data-n="Slot3"] [data-n="Icon"]', '[data-n="RightButtons"] [data-n="InventoryBtn"] [data-n="Icon"]']:
        check('иконка из примитивов: ' + sel.split('"')[-2] + ' ' + sel.split('"')[3], g.vis(sel) and page.evaluate(NLAYERS, sel) >= 5, page.evaluate(NLAYERS, sel))
    hud_txt = g.text('[data-n="Currency"]') + g.text('[data-n="Hotbar"]')
    check('в валютах и хотбаре нет эмодзи', not any(ch in hud_txt for ch in '🪙💎⚔🧲🧪'), hud_txt)
    g.wait(lambda: g.vis('[data-n="Timer"] [data-n="NextEvent"]'), what='next event chip', timeout=30)
    nxt = g.p.locator('[data-n="Timer"] [data-n="NextEvent"]').first.inner_text()
    # v3.2: луна — значок из примитивов (Icons), а не эмодзи в тексте
    check('справа снизу — компактный таймер до ближайшего события (значок-луна из примитивов)', ':' in nxt and '🌙' not in nxt and page.evaluate(NLAYERS, '[data-n="Timer"] [data-n="NextEvent"] [data-n="Icon"]') >= 2, nxt)
    check('нет старого меню и кнопок УДАР/СБОР', not g.vis('[data-n="Menu"]') and not g.vis('[data-n="Attack"]') and not g.vis('[data-n="Collect"]'))
    # Удар — выбрать меч в хотбаре и кликнуть по миру (настоящий Tool в руке); в воздухе — без тоста
    JS_TOOL = "(()=>{const c=R2W.ENV.localPlayer.props.Character; if(!c) return ''; const t=c.children.find(x=>x.className==='Tool'); return t? t.props.Name: ''})()"
    if g.p.evaluate(JS_TOOL) == 'Sword': page.keyboard.press('2'); g.vwait(0.4)  # повторный выбор слота снимает инструмент
    g.click('[data-n="Hotbar"] [data-n="Slot1"]'); g.vwait(0.5)
    check('слот 1 — меч в руке (Tool)', g.p.evaluate(JS_TOOL) == 'Sword', g.p.evaluate(JS_TOOL))
    page.mouse.click(640, 330); g.vwait(0.6)
    toast_txt = g.p.evaluate("(()=>{const t=document.querySelector('[data-n=Toasts]'); return t? t.innerText: ''})()")
    bad = ('No enemy' in toast_txt) or ('Too far' in toast_txt) or ('нет враг' in toast_txt.lower())
    check('атака в воздух без тоста', not bad, toast_txt)
    g.shot('01b_air_swing')
    page.keyboard.press('2'); g.vwait(0.4)
    check('клавиша 2 — магнит в руке', g.p.evaluate(JS_TOOL) == 'Collector', g.p.evaluate(JS_TOOL))
    # «Ещё»: все разделы, которых нет на главном экране
    g.click('[data-n="MoreBtn"]')
    g.wait(lambda: g.vis('[data-n="MorePanel"]'), what='more')
    for n in ['Upgrades', 'Rebirth', 'Talents', 'Daily', 'Zones', 'Craft', 'Market', 'Trade', 'Boards', 'Settings']:
        check('«Ещё»: ' + n, g.vis('[data-n="MorePanel"] [data-n="%s"]' % n))
    g.shot('01c_more')
    g.click('[data-n="MorePanel"] [data-n="Close"]')
    check('виден 3D-мир (меши)', page.evaluate('R2W.ENV.world3d.meshes.size') > 100)

    # --- ресурсы и питомцы
    g.cmd('seed')
    g.wait(lambda: '60' in g.text('[data-n="Currency"] [data-n="Coins"] [data-n="Value"]'))
    check('валюты пришли в HUD (60K монет)', True)
    # --- вылупление из яйца хаба
    g.cmd('tp:-22,-76')
    g.wait(lambda: page.evaluate('!!R2W.ENV.prompts.active'), what='egg prompt')
    page.keyboard.press('e')
    g.wait(lambda: g.vis('[data-n="EggPanel"] [data-n="Hatch1"]'), what='egg panel')
    g.shot('02_egg')
    g.click('[data-n="EggPanel"] [data-n="Hatch1"]')
    g.wait(lambda: g.vis('[data-n="HatchOverlay"] [data-n="Awesome"]'), what='hatch popup'); g.vwait(1.2)
    g.shot('02b_hatch')
    check('вылупление из яйца', True)
    g.click('[data-n="HatchOverlay"] [data-n="Awesome"]')
    if g.vis('[data-n="EggPanel"]'): g.click('[data-n="EggPanel"] [data-n="Close"]')
    # Индекс: вылупленные питомцы открыты, остальные — «???»
    open_panel('Index')
    # v3.2: ждём состояния — прогресс и клетки отрисованы (под нагрузкой DOM догоняет кадры эмулятора не сразу)
    g.wait(lambda: g.vis('[data-n="IndexPanel"] [data-n="Progress"]') and re.search(r'\d+\s*/\s*\d+', g.text('[data-n="IndexPanel"] [data-n="Progress"]')) is not None and '???' in g.text('[data-n="IndexPanel"]'), timeout=90, what='index')
    prog = g.text('[data-n="IndexPanel"] [data-n="Progress"]')
    m = re.search(r'(\d+)\s*/\s*(\d+)', prog)
    check('Индекс: открыто ≥ 1 из всех', bool(m) and int(m.group(1)) >= 1 and int(m.group(2)) >= 30, prog)
    check('Индекс: закрытые показаны как ???', '???' in g.text('[data-n="IndexPanel"]'))
    g.shot('02c_index')
    g.click('[data-n="IndexPanel"] [data-n="Close"]')
    open_panel('Pets')
    g.wait(lambda: len(g.names('[data-n="PetsPanel"]')) > 40)
    txt = g.text('[data-n="PetsPanel"]')
    check('инвентарь питомцев: 7 штук', 'Pets 7/30' in txt, txt[:80])
    sel0 = g.text('[data-n="PetsPanel"] [data-n="Footer"]')
    g.click('[data-n="PetsPanel"] [data-n="p4"]')
    g.wait(lambda: g.text('[data-n="PetsPanel"] [data-n="Footer"]') != sel0, what='pet selected')
    g.click('[data-n="PetsPanel"] [data-n="Equip"]')
    g.wait(lambda: 'Team 1/3' in g.text('[data-n="PetsPanel"]'), what='equip')
    check('экипировка в команду', True)
    g.click('[data-n="PetsPanel"] [data-n="FilterElement"]')
    try: g.wait(lambda: 'Element: All' not in g.text('[data-n="PetsPanel"] [data-n="FilterElement"]'), timeout=10, what='filter')
    except AssertionError: pass
    check('фильтр по стихии меняет список', 'Element: All' not in g.text('[data-n="PetsPanel"] [data-n="FilterElement"]'))
    g.click('[data-n="PetsPanel"] [data-n="FilterElement"]'); g.click('[data-n="PetsPanel"] [data-n="FilterElement"]')
    g.click('[data-n="PetsPanel"] [data-n="FilterElement"]'); g.click('[data-n="PetsPanel"] [data-n="FilterElement"]')
    g.click('[data-n="PetsPanel"] [data-n="p5"]'); g.click('[data-n="PetsPanel"] [data-n="Fav"]')
    g.wait(lambda: 'Unfavorite' in g.text('[data-n="PetsPanel"]'), what='fav')
    check('избранное', True)
    g.shot('03_pets')
    g.click('[data-n="PetsPanel"] [data-n="ModeToggle"]')
    g.click('[data-n="PetsPanel"] [data-n="p1"]')
    g.click('[data-n="PetsPanel"] [data-n="AutoPick"]')
    g.wait(lambda: '3/3' in g.text('[data-n="PetsPanel"]'), what='autopick')
    g.shot('04_fusion')
    g.click('[data-n="PetsPanel"] [data-n="FuseGo"]')
    g.wait(lambda: 'Pets 5/30' in g.text('[data-n="PetsPanel"]'), what='fuse')
    check('слияние 3→1 (7 → 5 питомцев)', True)
    g.wait(lambda: g.vis('[data-n="HatchOverlay"] [data-n="Awesome"]'), what='fuse popup'); g.vwait(1.0)
    g.shot('04b_fusion_result')
    g.click('[data-n="HatchOverlay"] [data-n="Awesome"]')
    g.click('[data-n="PetsPanel"] [data-n="Close"]')

    # --- крафт
    open_panel('Craft')
    g.wait(lambda: g.vis('[data-n="CraftPanel"]') and g.p.locator('[data-n="CraftPanel"] [data-n="Make"]').count() > 0)
    g.shot('05_craft')
    g.click('[data-n="CraftPanel"] [data-n="Make"]')
    g.click('[data-n="CraftPanel"] [data-n="Tab_Items"]')
    g.wait(lambda: 'x1' in g.text('[data-n="CraftPanel"]') or 'x2' in g.text('[data-n="CraftPanel"]'), what='craft item')
    check('крафт: предмет появился', True)
    check('крафт: у ресурсов свои иконки', all(g.vis('[data-n="CraftPanel"] [data-n="Icon_%s"]' % r) for r in ['Wood', 'Stone', 'Ore', 'Herb', 'Crystal', 'Essence', 'Fragment']))
    g.click('[data-n="CraftPanel"] [data-n="Close"]')

    # --- v2.6: инвентарь — все ресурсы и предметы, у каждого своя иконка; клик — описание, где добыть, для чего
    g.click('[data-n="RightButtons"] [data-n="InventoryBtn"]')
    g.wait(lambda: g.vis('[data-n="InventoryPanel"]') and g.p.locator('[data-n="InventoryPanel"] [data-n^="Cell_"]').count() > 0, what='inventory')
    ncell = g.p.locator('[data-n="InventoryPanel"] [data-n^="Cell_"]').count()
    check('инвентарь: 7 ресурсов + 11 предметов', ncell == 18, ncell)
    kinds = page.evaluate("""(()=>{const out=new Set(); for(const c of document.querySelectorAll('[data-n="InventoryPanel"] [data-n^="Cell_"]')){
      const i=c.querySelector('[data-n="Icon"]'); if(i && i.querySelectorAll('div').length>=3) out.add(c.dataset.n);} return out.size;})()""")
    check('инвентарь: в каждой ячейке своя иконка', kinds == ncell, kinds)
    wood = g.text('[data-n="InventoryPanel"] [data-n="Cell_Wood"] [data-n="Count"]')
    check('инвентарь: число дерева после seed', wood not in ('', '0'), wood)
    g.click('[data-n="InventoryPanel"] [data-n="Cell_Crystal"]')
    INFO = '[data-n="InventoryPanel"] [data-n="Info"]'
    try: g.wait(lambda: 'Frostpeak Glade' in g.text(INFO) and 'Luck Potion' in g.text(INFO), timeout=90, what='crystal info')
    except AssertionError: pass
    info = g.text(INFO)
    check('инвентарь: кристалл — где добыть (миры) и для чего (рецепты)', 'Where to get' in info and 'Frostpeak Glade' in info and 'Used for' in info and 'Luck Potion' in info, info[:300])
    g.shot('15_inventory')
    g.click('[data-n="InventoryPanel"] [data-n="Cell_luck_potion"]')
    try: g.wait(lambda: 'Workbench' in g.text(INFO) and 'chests' in g.text(INFO) and 'Drink' in g.text(INFO), timeout=90, what='potion info')
    except AssertionError: pass
    info = g.text(INFO)
    check('инвентарь: зелье — верстак и сундуки, как применить', 'Workbench' in info and 'chests' in info and 'Drink' in info, info[:300])
    g.click('[data-n="InventoryPanel"] [data-n="Close"]')

    # --- NPC и квест
    g.cmd('tp:-30,30')
    g.wait(lambda: page.evaluate('!!R2W.ENV.prompts.active'), what='prompt')
    for _ in range(3):  # повтор нажатия: под нагрузкой (боты) первый E иногда приходится на смену подсказки
        page.keyboard.press('e')
        try:
            g.wait(lambda: g.vis('[data-n="DialogBox"]'), what='dialog', timeout=6)
            break
        except AssertionError:
            pass
    g.wait(lambda: g.vis('[data-n="DialogBox"]'), what='dialog')
    for _ in range(4):
        if 'Accept' in g.text('[data-n="DialogBox"] [data-n="Action"]'): break
        a0 = g.text('[data-n="DialogBox"]')
        g.click('[data-n="DialogBox"] [data-n="Action"]')
        g.wait(lambda: not g.vis('[data-n="DialogBox"]') or g.text('[data-n="DialogBox"]') != a0, what='dialog step')
    g.shot('06_dialog')
    check('диалог NPC дошёл до «Accept quest»', 'Accept' in g.text('[data-n="DialogBox"] [data-n="Action"]'))
    a0 = g.text('[data-n="DialogBox"]')
    g.click('[data-n="DialogBox"] [data-n="Action"]')
    # квест принят: диалог закрывается или переходит к следующей реплике
    g.wait(lambda: not g.vis('[data-n="DialogBox"]') or g.text('[data-n="DialogBox"]') != a0, what='quest accepted')
    open_panel('Quests')
    g.click('[data-n="QuestsPanel"] [data-n="Tab_Story"]')
    g.wait(lambda: 'Wood for the Bench' in g.text('[data-n="QuestsPanel"]'), timeout=90, what='story')
    check('квест принят и виден в журнале', 'Wood for the Bench' in g.text('[data-n="QuestsPanel"]'))
    g.shot('07_quests')
    g.click('[data-n="QuestsPanel"] [data-n="Tab_Achievements"]')
    try: g.wait(lambda: 'Achievements:' in g.text('[data-n="QuestsPanel"]'), timeout=10, what='achievements')
    except AssertionError: pass
    check('вкладка достижений', 'Achievements:' in g.text('[data-n="QuestsPanel"]'))
    g.click('[data-n="QuestsPanel"] [data-n="Close"]')

    # --- рынок + батл-пасс
    g.cmd('tp:0,-30')
    open_panel('Market')
    g.wait(lambda: g.vis('[data-n="MarketPanel"]') and g.p.locator('[data-n="MarketPanel"] [data-n="Buy"]').count() > 0)
    g.shot('08_market')
    before = g.text('[data-n="Currency"] [data-n="Coins"] [data-n="Value"]') + g.text('[data-n="Currency"] [data-n="Gems"] [data-n="Value"]')
    g.click('[data-n="MarketPanel"] [data-n="Buy"]')
    try: g.wait(lambda: g.text('[data-n="Currency"] [data-n="Coins"] [data-n="Value"]') + g.text('[data-n="Currency"] [data-n="Gems"] [data-n="Value"]') != before, timeout=15, what='market buy')
    except AssertionError: pass
    after = g.text('[data-n="Currency"] [data-n="Coins"] [data-n="Value"]') + g.text('[data-n="Currency"] [data-n="Gems"] [data-n="Value"]')
    check('покупка в магазине ротации списывает валюту', before != after, before + ' ' + after)
    g.cmd('bpxp:500')
    g.click('[data-n="MarketPanel"] [data-n="Tab_Battle Pass"]')
    g.wait(lambda: g.p.locator('[data-n="MarketPanel"] [data-n="ClaimFree"]').count() > 0, what='bp')
    g.shot('09_battlepass')
    g.click('[data-n="MarketPanel"] [data-n="ClaimAll"]'); g.vwait(1.0)
    check('батл-пасс: премиум-трек заблокирован без пасса', g.p.locator('[data-n="MarketPanel"] [data-n="PremiumBanner"]').count() == 1)
    g.click('[data-n="MarketPanel"] [data-n="Close"]')

    # --- таланты, топы
    open_panel('Talents')
    try: g.wait(lambda: g.vis('[data-n="TalentsPanel"]') and all(b in g.text('[data-n="TalentsPanel"]') for b in ['Economy', 'Combat', 'Nature']), timeout=10, what='talents')
    except AssertionError: pass
    check('таланты: 3 ветки', all(b in g.text('[data-n="TalentsPanel"]') for b in ['Economy', 'Combat', 'Nature']))
    g.shot('10_talents')
    g.click('[data-n="TalentsPanel"] [data-n="Close"]')
    open_panel('Boards'); g.wait(lambda: 'Player1' in g.text('[data-n="LeaderboardsPanel"]'), what='boards')
    check('лидерборды показывают игрока', 'Player1' in g.text('[data-n="LeaderboardsPanel"]'), g.text('[data-n="LeaderboardsPanel"]')[:100])
    g.click('[data-n="LeaderboardsPanel"] [data-n="Close"]')

    # --- торговля с ботом
    open_panel('Trade')
    g.click('[data-n="TradePanel"] [data-n="TradeBot"]')
    g.wait(lambda: g.vis('[data-n="TradePanel"] [data-n="Live"]'), what='trade live')
    g.click('[data-n="TradePanel"] [data-n="Picker"] [data-n^="Add_"]'); g.vwait(0.5)
    # предложение Тома случайное: доплачиваем монетами, чтобы обмен был ему выгоден (иначе «Tom isn't happy»)
    for _ in range(2):
        g.click('[data-n="TradePanel"] [data-n="Coins+10k"]'); g.vwait(0.3)
    g.vwait(1.0)
    g.click('[data-n="TradePanel"] [data-n="Ready"]')
    g.wait(lambda: g.p.locator('[data-n="TradePanel"] [data-n="Confirm"]').first.evaluate('e=>e.style.opacity!="0.5"') , what='x')
    g.shot('11_trade')
    # «Подтвердить» активна после отсчёта TRADE_CONFIRM_SECONDS (виртуальное время эмулятора идёт медленнее) — жмём, пока сделка не закроется
    for _ in range(20):
        g.vwait(1.5)
        if not g.vis('[data-n="TradePanel"] [data-n="Live"]'): break
        g.click('[data-n="TradePanel"] [data-n="Confirm"]', timeout=3000)
    g.wait(lambda: not g.vis('[data-n="TradePanel"] [data-n="Live"]'), what='trade close', timeout=30)
    check('торговля с ботом завершена', True)
    g.p.keyboard.press('Escape')
    if g.vis('[data-n="TradePanel"]'): g.click('[data-n="TradePanel"] [data-n="Close"]')

    # --- события
    g.cmd('event:GoldenRain')
    # состояние событий приходит раз в секунду виртуального времени — ждём плашку, а не фиксированные 1.5 с
    try: g.wait(lambda: g.p.locator('[data-n="Timer"] [data-n^="Event_"]').count() >= 1 and not g.vis('[data-n="Timer"] [data-n="NextEvent"]'), timeout=30, what='event chip')
    except AssertionError: pass
    check('событие — компактная плашка в таймере справа снизу', g.p.locator('[data-n="Timer"] [data-n^="Event_"]').count() >= 1)
    check('во время события «через N:NN» скрыто', not g.vis('[data-n="Timer"] [data-n="NextEvent"]'))
    # станции хаба: разделы из бывшего меню открываются и у NPC/объектов (ProximityPrompt)
    g.cmd('tp:-26,12')
    g.wait(lambda: page.evaluate('!!R2W.ENV.prompts.active'), what='daily prompt')
    page.keyboard.press('e')
    g.wait(lambda: g.vis('[data-n="DailyPanel"]'), what='daily panel')
    check('станция «Сундук наград» открывает ежедневные награды', True)
    g.click('[data-n="DailyPanel"] [data-n="Close"]')

    # --- мир: бой
    open_panel('Zones'); g.wait(lambda: g.vis('[data-n="WorldsPanel"]') or g.vis('[data-n="ZonesPanel"]'), what='worlds')
    g.shot('12_worlds')
    g.p.evaluate("document.querySelector('[data-n=ZonesPanel] [data-n=Close], [data-n=WorldsPanel] [data-n=Close]').click()")
    g.cmd('tp:520,40')
    g.wait(lambda: g.p.evaluate("(R2W.ENV.workspace.findChild('Enemies')||{children:[]}).children.filter(m=>!(m.attrs&&m.attrs.get('IsBoss'))).length")>2, timeout=90, what='enemies')
    check('в зоне есть враги', True)
    g.vwait(6)
    JS_HURT = "(()=>{const f=R2W.ENV.workspace.findChild('Enemies'); if(!f) return 0; let n=0; for(const m of f.children){const a=m.attrs; if(a && a.get('Hp')!==undefined && a.get('MaxHp') && a.get('Hp')<a.get('MaxHp')) n++;} return n;})()"
    hurt = 0
    for _ in range(12):
        g.cmd('tpenemy'); g.vwait(0.5)
        page.keyboard.press('q'); g.vwait(0.6)
        hurt = g.p.evaluate(JS_HURT)
        if hurt:
            break
    g.shot('13_combat')
    nvis = g.p.evaluate("(R2W.ENV.workspace.findChild('EnemyVisuals')||{children:[]}).children.length")
    check('враги нарисованы клиентом (EnemyVisuals)', nvis >= 3, nvis)
    check('удар игрока/питомцев наносит урон врагам', hurt > 0, 'hurt=%s' % hurt)
    # Добьём врага: Kill Fx с текстом лута и/или LootOrb в мире
    hud0 = g.text('[data-n="Currency"] [data-n="Coins"] [data-n="Value"]')
    killed = False
    for _ in range(30):
        g.cmd('tpenemy'); page.mouse.click(640, 330); g.vwait(0.35)
        if g.p.locator('[data-n^="Fx_Kill"]').count() > 0:
            killed = True
            break
        # враг исчез
        alive = g.p.evaluate("(R2W.ENV.workspace.findChild('Enemies')||{children:[]}).children.filter(m=>m.attrs&&m.attrs.get('Hp')===0).length")
        if alive:
            killed = True
            break
    g.vwait(1.2)
    orbs = g.p.evaluate("(()=>{const f=R2W.ENV.workspace.findChild('Enemies'); if(!f) return 0; return f.children.filter(c=>c.props&&c.props.Name==='LootOrb').length})()")
    kill_fx = g.p.locator('[data-n^="Fx_Kill"]').count()
    hud1 = g.text('[data-n="Currency"] [data-n="Coins"] [data-n="Value"]')
    check('убийство даёт лут (fx/orbs/монеты)', kill_fx > 0 or orbs > 0 or hud1 != hud0, 'fx=%s orbs=%s hud %s→%s' % (kill_fx, orbs, hud0, hud1))
    g.shot('13b_loot')
    g.cmd('event:BossRaid')
    g.wait(lambda: g.vis('[data-n="BossBar"]'), timeout=60, what='boss bar')
    g.vwait(3); g.shot('14_raid')
    check('полоса босса рейда', True)
    check('за прогон не было ошибок эмулятора', page.evaluate('R2W.ENV.errorCount') == 0, str(page.evaluate('R2W.ENV.errorCount')))
    check('в консоли страницы нет ошибок', not errs, str(errs[:3]))
print('\n%d ok, %d failed' % (oks, len(fails)), fails)
sys.exit(1 if fails else 0)
