#!/usr/bin/env python3
"""Скриншоты v2.6 (RU, 1280×720) для docs/screens/50_*.png: экран загрузки с логотипом, HUD с иконкой монет,
табличка с логотипом в хабе, кадр середины замаха мечом (пауза эмулятора + покадровый шаг) и окно «Инвентарь».
Запуск: bash tests/browser/build_ui_site.sh && python3 tests/browser/shots_v26.py [--shots DIR]"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.environ.get('R2W_DIR', '/workspace/roblox2web') + '/tests/browser'); sys.path.insert(0, HERE)
from ui_helpers import *
OUT = os.path.join(HERE, '..', '..', 'docs', 'screens')
if '--shots' in sys.argv: OUT = sys.argv[sys.argv.index('--shots') + 1]
os.makedirs(OUT, exist_ok=True)
SIDE = """(()=>{const R=R2W.ENV.localPlayer.props.Character.findChild('HumanoidRootPart').props.CFrame.r; const fx=-R[2], fz=-R[8];
 const sx=fz*0.6-fx*0.8, sz=-fx*0.6-fz*0.8; R2W.ENV.cam.yaw=Math.atan2(sx,sz); R2W.ENV.cam.pitch=0.28; R2W.ENV.cam.dist=12;})()"""
def shot(page, name):
    p = os.path.join(OUT, name); page.screenshot(path=p); print('shot', p)
with serve('/tmp/gw_ui') as url, browser(1280, 720) as ctx:
    page = ctx.new_page(); errs = collect(page); g = G(page)
    page.goto(url + 'index.html?persist=0&seed=1&lang=ru&country=RU')
    g.wait(lambda: g.vis('[data-n="Dot2"]'), timeout=120, what='loading screen')
    page.wait_for_timeout(400); shot(page, '50_loading.png')
    g.wait(lambda: g.vis('[data-n="Hotbar"]'), timeout=120, what='hotbar')
    g.wait(lambda: not g.vis('[data-n="Dot2"]'), timeout=30, what='loading screen gone')
    if g.vis('[data-n="Skip"]'): page.locator('[data-n="Skip"]').first.click(force=True); page.wait_for_timeout(500)
    g.cmd('seed'); page.wait_for_timeout(1500)
    shot(page, '50_hud_coin.png')
    g.cmd('tp:0,-22'); page.wait_for_timeout(1500)  # перед табличкой (z = -50), камера сзади, почти горизонтально
    page.evaluate('R2W.ENV.paused=true'); page.evaluate('R2W.ENV.cam.yaw=0; R2W.ENV.cam.pitch=0.05; R2W.ENV.cam.dist=16'); page.wait_for_timeout(600)
    shot(page, '50_logo_sign.png'); page.evaluate('R2W.ENV.paused=false')
    # середина замаха: меч в руке, пауза, удар (Q), 3 кадра по 0.04 с, камера сбоку
    g.cmd('tp:615,-70'); page.wait_for_timeout(1500)
    page.keyboard.press('q'); page.wait_for_timeout(1500)
    page.evaluate('R2W.ENV.paused=true'); page.wait_for_timeout(250)
    page.evaluate('R2W.ENV.frame(0.04); R2W.ENV.frame(0.04)')
    page.keyboard.press('q'); page.wait_for_timeout(150)
    for _ in range(3): page.evaluate('R2W.ENV.frame(0.04); R2W.ENV.gui.flush()')
    page.evaluate(SIDE); page.wait_for_timeout(500)
    shot(page, '50_swing_mid.png')
    page.evaluate('R2W.ENV.paused=false'); page.wait_for_timeout(1000)
    page.locator('[data-n="InventoryBtn"]').first.click(); page.wait_for_timeout(1200)
    page.locator('[data-n="Cell_Crystal"]').first.click(); page.wait_for_timeout(800)
    shot(page, '50_inventory.png')
    real = [e for e in errs if 'favicon' not in e]
    print('errors', real[:3], page.evaluate('R2W.ENV.errorCount'))
