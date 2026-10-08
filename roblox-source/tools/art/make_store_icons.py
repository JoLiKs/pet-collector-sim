#!/usr/bin/env python3
"""Иконки 512×512 (всё важное — в круге r≈230: Roblox показывает иконки пассов кругом) для геймпассов и девелоперских продуктов (v2.7) в стиле assets/icon_512.png:
SVG из parts.py + store_parts.py, растеризация в Chromium. Результат: assets/store/<KEY>.png (+ .svg) и коллаж
assets/store/_collage.png. Запуск: python3 tools/art/make_store_icons.py [outdir]"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from parts import *
from store_parts import *

def svg(body, bg):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">{defs()}{store_defs()}'
            f'<rect width="512" height="512" fill="url(#{bg})"/>{body}</svg>')

def burst(c='#fff', op=.26, cy=240):
    return sunburst(256, cy, 18, 700, c, op)

ICONS = {
    # --- game passes ---
    'DOUBLE_COINS': svg(f'''{burst()}<circle cx="256" cy="250" r="200" fill="url(#aura)"/>
{coin(190, 250, 110, -12)}{coin(335, 185, 84, 14)}{coin(370, 330, 56, 0)}{coin(110, 140, 38, -20)}
{sparkle(430, 90, 1.3)}{sparkle(90, 430, 1.0)}{label(256, 455, "x2", 165, '#ffe14a')}''', 'bgSun'),
    'DOUBLE_SPEED': svg(f'''{burst('#e8fbff', .22)}<circle cx="290" cy="250" r="190" fill="url(#aura)" opacity=".7"/>
{speed_lines(190, 230, 1.0)}{cat(300, 230, .95)}{bolt(80, 120, 1.25, -20)}{bolt(440, 110, 1.0, 20)}
{label(256, 458, "x2", 150, '#fff36b')}''', 'bgBlue'),
    'AUTO_COLLECT': svg(f'''{burst('#fff', .22)}<circle cx="256" cy="260" r="200" fill="url(#aura)" opacity=".8"/>
{magnet(220, 300, 1.25, -25)}
<path d="M300,190 Q360,150 420,170" fill="none" stroke="#fff" stroke-width="12" stroke-linecap="round" opacity=".8" stroke-dasharray="20 16"/>
<path d="M320,280 Q390,280 440,320" fill="none" stroke="#fff" stroke-width="12" stroke-linecap="round" opacity=".8" stroke-dasharray="20 16"/>
{coin(430, 160, 46, 10)}{coin(445, 330, 40, -10)}{coin(380, 450, 34, 0)}{sparkle(110, 90, 1.2)}{sparkle(470, 250, .8)}''', 'bgGreen'),
    'VIP': svg(f'''{burst('#ffe9ff', .22)}<circle cx="256" cy="230" r="210" fill="url(#aura)"/>
{crown(256, 220, 1.1)}{gem(90, 110, .8)}{gem(430, 400, .7, 'url(#gemPink)', 15)}{sparkle(440, 90, 1.2)}{sparkle(70, 360, 1.0)}
{label(256, 445, "VIP", 140, '#ffe14a')}''', 'bgPurple'),
    'BATTLE_PASS': svg(f'''{burst('#fff', .22)}<circle cx="256" cy="250" r="210" fill="url(#aura)" opacity=".8"/>
{ticket(256, 230, 1.15, -10)}{crown(256, 85, .45, 0)}{coin(80, 400, 40, -10)}{gem(440, 420, .75)}{sparkle(450, 110, 1.1)}{sparkle(60, 120, .9)}
{label(256, 440, "PASS", 96, '#ffffff')}''', 'bgRed'),
    # --- developer products ---
    'GEMS_SMALL': svg(f'''{burst('#e8fbff', .25)}<circle cx="256" cy="260" r="180" fill="url(#aura)" opacity=".75"/>
{gem(200, 300, 2.6, rot=-12)}{gem(340, 250, 2.0, 'url(#gemPink)', 14)}{gem(300, 400, 1.3, rot=4)}
{sparkle(110, 110, 1.2)}{sparkle(420, 120, 1.0)}{sparkle(440, 400, .8)}''', 'bgBlue'),
    'GEMS_MEDIUM': svg(f'''{burst('#e8fbff', .25)}<circle cx="256" cy="260" r="200" fill="url(#aura)" opacity=".75"/>
{pouch(256, 300, 1.25, 'url(#gemPink)')}{gem(200, 150, 1.4, rot=-15)}{gem(300, 140, 1.6, rot=10)}{gem(255, 120, 1.2, 'url(#gemPink)')}
{gem(90, 420, 1.0)}{gem(430, 420, 1.0, rot=20)}{sparkle(430, 100, 1.1)}{sparkle(80, 120, .9)}''', 'bgBlue'),
    'GEMS_LARGE': svg(f'''{burst('#e8fbff', .25)}<circle cx="256" cy="270" r="215" fill="url(#aura)" opacity=".8"/>
{chest(256, 320, 1.15)}{gem(180, 175, 1.5, rot=-18)}{gem(256, 150, 1.8)}{gem(335, 178, 1.5, 'url(#gemPink)', 16)}
{gem(215, 220, 1.1, 'url(#gemPink)')}{gem(300, 225, 1.1)}{gem(70, 450, .9)}{gem(445, 450, .9, 'url(#gemPink)')}
{sparkle(90, 110, 1.3)}{sparkle(430, 90, 1.1)}''', 'bgPurple'),
    'COINS_SMALL': svg(f'''{burst()}<circle cx="256" cy="260" r="190" fill="url(#aura)"/>
{pouch(256, 310, 1.25)}{coin(200, 170, 50, -10)}{coin(300, 155, 56, 12)}{coin(255, 125, 44, 0)}
{coin(90, 420, 40, -15)}{coin(430, 410, 36, 10)}{sparkle(430, 100, 1.1)}{sparkle(80, 120, .9)}''', 'bgSun'),
    'COINS_LARGE': svg(f'''{burst()}<circle cx="256" cy="270" r="215" fill="url(#aura)"/>
{chest(256, 330, 1.15)}{coin(170, 190, 52, -14)}{coin(256, 160, 62, 0)}{coin(340, 192, 52, 14)}
{coin(215, 230, 40, 8)}{coin(300, 235, 40, -8)}{coin(70, 440, 36, -10)}{coin(445, 440, 34, 10)}
{sparkle(90, 110, 1.3)}{sparkle(430, 90, 1.1)}''', 'bgRed'),
    'LUCK_2X_15M': svg(f'''{burst('#f4ffd0', .28)}<circle cx="256" cy="240" r="200" fill="url(#aura)" opacity=".7"/>
{clover(250, 205, 1.05, rot=-10)}{sparkle(420, 100, 1.3)}{sparkle(80, 380, 1.0)}{sparkle(110, 90, .8, '#fff6a0')}
{label(256, 458, "x2", 150, '#ffffff')}''', 'bgGreen'),
    'LUCK_5X_10M': svg(f'''{burst('#ffe9ff', .24)}<circle cx="256" cy="240" r="215" fill="url(#aura)"/>
{clover(250, 205, 1.05, 'url(#cloverGold)', 10)}{bolt(440, 110, .9, 20)}{sparkle(80, 100, 1.3)}{sparkle(450, 300, 1.0)}{sparkle(70, 330, .9, '#fff6a0')}
{label(256, 458, "x5", 150, '#ffe14a')}''', 'bgPurple'),
    'BP_SKIP': svg(f'''{burst('#fff', .22)}<circle cx="256" cy="260" r="200" fill="url(#aura)" opacity=".8"/>
{ticket(200, 300, .85, -14)}{arrow_up(390, 230, 1.15)}{arrow_up(390, 120, .7)}{sparkle(90, 110, 1.1)}{sparkle(460, 420, .9)}
{label(200, 175, "+5", 150, '#ffe14a')}''', 'bgRed'),
    'ESSENCE_PACK': svg(f'''{burst('#f0e0ff', .22)}<circle cx="256" cy="270" r="210" fill="url(#aura)" opacity=".55"/>
{flask(230, 290, 1.25)}{orb(400, 380, 52)}{orb(410, 170, 34)}{orb(90, 420, 30)}
{sparkle(110, 110, 1.2, '#f3d0ff')}{sparkle(440, 80, 1.0)}{sparkle(470, 270, .8)}''', 'bgTeal'),
}

def render(outdir):
    from playwright.sync_api import sync_playwright
    os.makedirs(outdir, exist_ok=True)
    with sync_playwright() as p:
        b = p.chromium.launch(executable_path='/usr/bin/google-chrome', args=['--no-sandbox'])
        pg = b.new_page(viewport={'width': 512, 'height': 512})
        for key, s in ICONS.items():
            pg.set_content('<html><body style="margin:0;background:#000">' + s + '</body></html>'); pg.wait_for_timeout(150)
            pg.screenshot(path=os.path.join(outdir, key + '.png'), clip={'x': 0, 'y': 0, 'width': 512, 'height': 512})
            open(os.path.join(outdir, key + '.svg'), 'w').write(s)
        b.close()
    collage(outdir)

def collage(outdir):
    from PIL import Image, ImageDraw
    keys = list(ICONS); cols = 5; t = 200; pad = 10; cap = 22
    rows = (len(keys) + cols - 1) // cols
    m = Image.new('RGB', (cols * (t + pad) + pad, rows * (t + pad + cap) + pad), (24, 26, 48)); d = ImageDraw.Draw(m)
    for i, k in enumerate(keys):
        x = pad + (i % cols) * (t + pad); y = pad + (i // cols) * (t + pad + cap)
        m.paste(Image.open(os.path.join(outdir, k + '.png')).convert('RGB').resize((t, t), Image.LANCZOS), (x, y))
        d.ellipse((x, y, x + t - 1, y + t - 1), outline=(255, 255, 255))  # круг: так Roblox показывает иконку пасса
        d.text((x + 4, y + t + 4), k, fill=(230, 230, 255))
    m.save(os.path.join(outdir, '_collage.png'))

if __name__ == '__main__':
    render(sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'store'))
