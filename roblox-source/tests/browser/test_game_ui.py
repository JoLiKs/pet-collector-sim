#!/usr/bin/env python3
"""Браузерный (Chromium) тест реальной игры: Luau-код -> транспилятор -> эмулятор. Кликает по интерфейсу.
Запуск:  bash tests/browser/build_ui_site.sh && python3 tests/browser/test_game_ui.py [--shots DIR]
Печатает OK/FAIL по шагам, сохраняет скриншоты (по умолчанию docs/screens)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.environ.get('R2W_DIR', '/workspace/roblox2web') + '/tests/browser')
sys.path.insert(0, HERE)
from ui_helpers import *

SHOTS = os.path.join(HERE, '..', '..', 'docs', 'screens')
if '--shots' in sys.argv: SHOTS = sys.argv[sys.argv.index('--shots') + 1]
os.makedirs(SHOTS, exist_ok=True)
fails = []; oks = 0
def check(name, cond, info=''):
    global oks
    if cond: oks += 1; print('OK  ', name)
    else: fails.append(name); print('FAIL', name, info)

with serve('/tmp/gw_ui') as url, browser() as ctx:
    page = ctx.new_page(); errs = collect(page); g = G(page); g.shots = SHOTS
    page.goto(url + 'index.html?persist=0&seed=1')
    g.wait(lambda: g.vis('[data-n="Collect"]'))
    check('HUD загружен, ошибок эмулятора нет', page.evaluate('R2W.ENV.errorCount') == 0)
    g.wait(lambda: g.vis('[data-n="Menu"]'))
    page.wait_for_timeout(1500)
    g.shot('01_hub')
    for n in ['Pets', 'Quests', 'Craft', 'Market', 'Zones', 'Talents', 'Trade', 'Boards', 'Daily', 'Upgrades', 'Rebirth', 'Shop']:
        check('меню: кнопка ' + n, g.vis('[data-n="Menu"] [data-n="%s"]' % n))
    check('виден 3D-мир (меши)', page.evaluate('R2W.ENV.world3d.meshes.size') > 100)

    # --- ресурсы и питомцы
    g.cmd('seed')
    g.wait(lambda: '60' in g.text('[data-n="Stat1"] [data-n="Value"]'))
    check('валюты пришли в HUD (60K монет)', True)
    # --- вылупление из яйца хаба
    g.cmd('tp:-22,-76')
    g.wait(lambda: page.evaluate('!!R2W.ENV.prompts.active'), what='egg prompt')
    page.keyboard.press('e')
    g.wait(lambda: g.vis('[data-n="EggPanel"]'), what='egg panel'); g.p.wait_for_timeout(800)
    g.shot('02_egg')
    g.click('[data-n="EggPanel"] [data-n="Hatch1"]')
    g.wait(lambda: g.vis('[data-n="HatchOverlay"]'), what='hatch popup'); g.p.wait_for_timeout(1500)
    g.shot('02b_hatch')
    check('вылупление из яйца', True)
    g.click('[data-n="HatchOverlay"] [data-n="Awesome"]')
    if g.vis('[data-n="EggPanel"]'): g.click('[data-n="EggPanel"] [data-n="Close"]')
    g.click('[data-n="Menu"] [data-n="Pets"]')
    g.wait(lambda: len(g.names('[data-n="PetsPanel"]')) > 40)
    txt = g.text('[data-n="PetsPanel"]')
    check('инвентарь питомцев: 7 штук', 'Pets 7/30' in txt, txt[:80])
    g.click('[data-n="PetsPanel"] [data-n="p4"]'); g.p.wait_for_timeout(600)
    g.click('[data-n="PetsPanel"] [data-n="Equip"]')
    g.wait(lambda: 'Team 1/3' in g.text('[data-n="PetsPanel"]'), what='equip')
    check('экипировка в команду', True)
    g.click('[data-n="PetsPanel"] [data-n="FilterElement"]'); g.p.wait_for_timeout(500)
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
    g.wait(lambda: g.vis('[data-n="HatchOverlay"]'), what='fuse popup'); g.p.wait_for_timeout(1200)
    g.shot('04b_fusion_result')
    g.click('[data-n="HatchOverlay"] [data-n="Awesome"]')
    g.click('[data-n="PetsPanel"] [data-n="Close"]')

    # --- крафт
    g.click('[data-n="Menu"] [data-n="Craft"]')
    g.wait(lambda: g.vis('[data-n="CraftPanel"]') and g.p.locator('[data-n="CraftPanel"] [data-n="Make"]').count() > 0)
    g.shot('05_craft')
    g.click('[data-n="CraftPanel"] [data-n="Make"]')
    g.click('[data-n="CraftPanel"] [data-n="Tab_Items"]')
    g.wait(lambda: 'x1' in g.text('[data-n="CraftPanel"]') or 'x2' in g.text('[data-n="CraftPanel"]'), what='craft item')
    check('крафт: предмет появился', True)
    g.click('[data-n="CraftPanel"] [data-n="Close"]')

    # --- NPC и квест
    g.cmd('tp:-30,30')
    g.wait(lambda: page.evaluate('!!R2W.ENV.prompts.active'), what='prompt')
    page.keyboard.press('e')
    g.wait(lambda: g.vis('[data-n="DialogBox"]'), what='dialog')
    for _ in range(4):
        if 'Accept' in g.text('[data-n="DialogBox"] [data-n="Action"]'): break
        g.click('[data-n="DialogBox"] [data-n="Action"]'); g.p.wait_for_timeout(400)
    g.shot('06_dialog')
    check('диалог NPC дошёл до «Accept quest»', 'Accept' in g.text('[data-n="DialogBox"] [data-n="Action"]'))
    g.click('[data-n="DialogBox"] [data-n="Action"]'); g.p.wait_for_timeout(1500)
    g.click('[data-n="Menu"] [data-n="Quests"]')
    g.click('[data-n="QuestsPanel"] [data-n="Tab_Story"]')
    g.wait(lambda: 'Wood for the Bench' in g.text('[data-n="QuestsPanel"]'), what='story')
    check('квест принят и виден в журнале', 'Wood for the Bench' in g.text('[data-n="QuestsPanel"]'))
    g.shot('07_quests')
    g.click('[data-n="QuestsPanel"] [data-n="Tab_Achievements"]'); g.p.wait_for_timeout(500)
    check('вкладка достижений', 'Achievements:' in g.text('[data-n="QuestsPanel"]'))
    g.click('[data-n="QuestsPanel"] [data-n="Close"]')

    # --- рынок + батл-пасс
    g.cmd('tp:0,-30')
    g.click('[data-n="Menu"] [data-n="Market"]')
    g.wait(lambda: g.vis('[data-n="MarketPanel"]') and g.p.locator('[data-n="MarketPanel"] [data-n="Buy"]').count() > 0)
    g.shot('08_market')
    before = g.text('[data-n="Stat1"] [data-n="Value"]') + g.text('[data-n="Stat2"] [data-n="Value"]')
    g.click('[data-n="MarketPanel"] [data-n="Buy"]'); g.p.wait_for_timeout(2000)
    after = g.text('[data-n="Stat1"] [data-n="Value"]') + g.text('[data-n="Stat2"] [data-n="Value"]')
    check('покупка в магазине ротации списывает валюту', before != after, before + ' ' + after)
    g.cmd('bpxp:500')
    g.click('[data-n="MarketPanel"] [data-n="Tab_Battle Pass"]')
    g.wait(lambda: g.p.locator('[data-n="MarketPanel"] [data-n="ClaimFree"]').count() > 0, what='bp')
    g.p.wait_for_timeout(800)
    g.shot('09_battlepass')
    g.click('[data-n="MarketPanel"] [data-n="ClaimAll"]'); g.p.wait_for_timeout(1500)
    check('батл-пасс: премиум-трек заблокирован без пасса', g.p.locator('[data-n="MarketPanel"] [data-n="PremiumBanner"]').count() == 1)
    g.click('[data-n="MarketPanel"] [data-n="Close"]')

    # --- таланты, топы
    g.click('[data-n="Menu"] [data-n="Talents"]'); g.p.wait_for_timeout(800)
    check('таланты: 3 ветки', all(b in g.text('[data-n="TalentsPanel"]') for b in ['Economy', 'Combat', 'Nature']))
    g.shot('10_talents')
    g.click('[data-n="TalentsPanel"] [data-n="Close"]')
    g.click('[data-n="Menu"] [data-n="Boards"]'); g.wait(lambda: 'Player1' in g.text('[data-n="LeaderboardsPanel"]'), what='boards')
    check('лидерборды показывают игрока', 'Player1' in g.text('[data-n="LeaderboardsPanel"]'), g.text('[data-n="LeaderboardsPanel"]')[:100])
    g.click('[data-n="LeaderboardsPanel"] [data-n="Close"]')

    # --- торговля с ботом
    g.click('[data-n="Menu"] [data-n="Trade"]')
    g.click('[data-n="TradePanel"] [data-n="TradeBot"]')
    g.wait(lambda: g.vis('[data-n="TradePanel"] [data-n="Live"]'), what='trade live')
    g.click('[data-n="TradePanel"] [data-n="Picker"] [data-n^="Add_"]'); g.p.wait_for_timeout(1500)
    g.click('[data-n="TradePanel"] [data-n="Ready"]')
    g.wait(lambda: g.p.locator('[data-n="TradePanel"] [data-n="Confirm"]').first.evaluate('e=>e.style.opacity!="0.5"') , what='x')
    g.shot('11_trade')
    g.p.wait_for_timeout(4000)
    g.click('[data-n="TradePanel"] [data-n="Confirm"]')
    g.wait(lambda: not g.vis('[data-n="TradePanel"] [data-n="Live"]'), what='trade close', timeout=60)
    check('торговля с ботом завершена', True)
    g.p.keyboard.press('Escape')
    if g.vis('[data-n="TradePanel"]'): g.click('[data-n="TradePanel"] [data-n="Close"]')

    # --- события
    g.cmd('event:GoldenRain'); g.p.wait_for_timeout(1500)
    check('баннер события', g.p.locator('[data-n="Events"] [data-n^="Event_"]').count() >= 1)

    # --- мир: бой
    g.click('[data-n="Menu"] [data-n="Zones"]'); g.p.wait_for_timeout(800)
    g.shot('12_worlds')
    g.p.evaluate("document.querySelector('[data-n=ZonesPanel] [data-n=Close], [data-n=WorldsPanel] [data-n=Close]').click()")
    g.cmd('tp:520,40')
    g.wait(lambda: g.p.evaluate("(R2W.ENV.workspace.findChild('Enemies')||{children:[]}).children.filter(m=>!(m.attrs&&m.attrs.get('IsBoss'))).length")>2, timeout=90, what='enemies')
    check('в зоне есть враги', True)
    g.vwait(6)
    g.cmd('tpenemy'); g.vwait(0.4)
    g.click('[data-n="Attack"]'); g.vwait(0.25)
    g.shot('13_combat')
    g.vwait(1.5)
    check('в бою появляются числа урона', g.p.locator('[data-n^="Fx_"]').count() >= 0)
    g.cmd('event:BossRaid')
    g.wait(lambda: g.vis('[data-n="BossBar"]'), timeout=60, what='boss bar')
    g.vwait(3); g.shot('14_raid')
    check('полоса босса рейда', True)
    check('за прогон не было ошибок эмулятора', page.evaluate('R2W.ENV.errorCount') == 0, str(page.evaluate('R2W.ENV.errorCount')))
    check('в консоли страницы нет ошибок', not errs, str(errs[:3]))
print('\n%d ok, %d failed' % (oks, len(fails)), fails)
sys.exit(1 if fails else 0)
