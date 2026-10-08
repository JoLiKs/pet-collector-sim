#!/usr/bin/env python3
"""Иконка игры, значок и превью (v2.6): SVG из parts.py, растеризация в Chromium (Playwright). Рисовано кодом — без
генерации картинок; правьте parts.py/make_art.py и перезапускайте."""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from parts import *
from playwright.sync_api import sync_playwright

def svg(w, h, body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{defs()}{body}</svg>'

def icon_a(w=512):  # sunburst + pet hatching from egg with raised sword
    return svg(w, w, f'''
<rect width="512" height="512" fill="url(#bgSun)"/>{sunburst(256, 230, 18, 700, '#fff', .28)}
<circle cx="256" cy="250" r="190" fill="url(#aura)"/>
{sword(240+112*.95, 250+62*.95, .9, 32)}
{cat(240, 250, .95, arm=1)}
{egg_bottom(250, 400, 1.35)}
{coin(78, 120, 40, -15)}{coin(440, 95, 34, 20)}{coin(450, 330, 30, -10)}{coin(70, 360, 28, 15)}
{gem(120, 445, .8)}{gem(410, 440, .7, 'url(#gemPink)', 15)}
{sparkle(160, 70, 1.2)}{sparkle(390, 200, .9)}{sparkle(60, 250, .8)}{sparkle(470, 230, .7, '#fff6a0')}
''')

def icon_b(w=512):  # magic: superpower aura, cat with sword, lightning
    return svg(w, w, f'''
<rect width="512" height="512" fill="url(#bgMagic)"/>{sunburst(256, 240, 14, 700, '#bff7ff', .18)}
<circle cx="256" cy="260" r="215" fill="url(#aura)"/>
{bolt(85, 150, 1.3, -15)}{bolt(430, 330, 1.1, 20)}
{sword(250+112*1.05, 265+62*1.05, .95, 35)}
{cat(250, 265, 1.05, arm=1)}
{coin(90, 420, 44, -10)}{coin(430, 110, 38, 15)}{coin(160, 470, 26, 0)}
{gem(440, 450, .9)}{gem(70, 300, .65, 'url(#gemPink)', -15)}
{sparkle(150, 80, 1.3)}{sparkle(360, 60, .9)}{sparkle(470, 220, .8)}
''')

def icon_c(w=512):  # meadow: three pets around an egg, coin pile
    return svg(w, w, f'''
<rect width="512" height="512" fill="url(#bgMeadow)"/>{sunburst(256, 150, 16, 700, '#ffffff', .25)}
<ellipse cx="256" cy="520" rx="420" ry="140" fill="url(#grass)" stroke="{OL}" stroke-width="8"/>
{egg_full(256, 215, .95)}
{bunny(110, 340, .62)}{dog(405, 345, .6)}{cat(256, 385, .62)}
{coin(70, 90, 36, -10)}{coin(450, 80, 30, 10)}{coin(460, 200, 24, 0)}
{gem(60, 210, .6)}{sparkle(380, 150, 1.0)}{sparkle(140, 150, .8)}
''')

def badge(w=512):  # circle-safe: everything important inside r≈200
    return svg(w, w, f'''
<rect width="512" height="512" fill="url(#bgSun)"/>{sunburst(256, 256, 20, 700, '#fff', .3)}
<circle cx="256" cy="256" r="232" fill="none" stroke="#fff" stroke-width="14" opacity=".8"/>
<circle cx="256" cy="256" r="246" fill="none" stroke="{OL}" stroke-width="12"/>
<circle cx="256" cy="260" r="170" fill="url(#aura)"/>
{sword(250+112*.78, 262+62*.78, .72, 32)}
{cat(250, 262, .78, arm=1)}
{egg_bottom(254, 382, 1.05)}
{coin(130, 150, 30, -15)}{coin(390, 140, 26, 15)}{gem(392, 360, .6)}{sparkle(160, 330, .8)}{sparkle(350, 95, .8)}
''')

def thumb(w=1920, h=1080, ru=True):
    title1 = 'PET COLLECTOR'; title2 = 'SIMULATOR'
    return svg(w, h, f'''
<rect width="{w}" height="{h}" fill="url(#bgSun)"/>{sunburst(960, 560, 28, 2000, '#fff', .25)}
<ellipse cx="960" cy="1180" rx="1300" ry="320" fill="url(#grass)" stroke="{OL}" stroke-width="10"/>
<circle cx="960" cy="610" r="380" fill="url(#aura)"/>
{sword(940+112*1.55, 640+62*1.55, 1.45, 32)}
{cat(940, 640, 1.55, arm=1)}
{egg_bottom(955, 880, 2.1)}
{bunny(370, 780, 1.05)}{dog(1560, 785, 1.0)}
{egg_full(190, 470, .8, ('#ffb3e0', '#9bf09a', '#7fc8ff'))}{egg_full(1740, 470, .75)}
{coin(560, 300, 60, -15)}{coin(1380, 280, 54, 20)}{coin(1500, 560, 40, -10)}{coin(420, 560, 40, 15)}{coin(760, 960, 46, 0)}{coin(1180, 990, 40, 10)}
{gem(300, 980, 1.0)}{gem(1650, 990, .9, 'url(#gemPink)', 15)}{gem(1330, 430, .7)}
{sparkle(700, 180, 1.6)}{sparkle(1250, 420, 1.1)}{sparkle(250, 300, 1.2)}{sparkle(1700, 250, 1.0, '#fff6a0')}
<g font-family="'Arial Black','Impact',sans-serif" font-weight="900" text-anchor="middle" filter="url(#shadow)">
  <text x="960" y="150" font-size="140" fill="#fff" stroke="{OL}" stroke-width="22" paint-order="stroke" letter-spacing="4">{title1}</text>
  <text x="960" y="265" font-size="104" fill="#ffd93b" stroke="{OL}" stroke-width="18" paint-order="stroke" letter-spacing="10">{title2}</text>
</g>
''')

def render(items, outdir):
    os.makedirs(os.path.join(outdir, 'variants'), exist_ok=True)
    with sync_playwright() as p:
        b = p.chromium.launch(executable_path='/usr/bin/google-chrome', args=['--no-sandbox'])
        for name, (w, h, s) in items.items():
            pg = b.new_page(viewport={'width': w, 'height': h})
            pg.set_content('<html><body style="margin:0;background:#000">' + s + '</body></html>')
            pg.wait_for_timeout(200)
            pg.screenshot(path=os.path.join(outdir, name), clip={'x': 0, 'y': 0, 'width': w, 'height': h})
            open(os.path.join(outdir, name.replace('.png', '.svg')), 'w').write(s)
        b.close()

if __name__ == '__main__':
    # python3 tools/art/make_art.py [assets_dir]  -> icon_512.png (вариант A), badge_512.png, thumbnail_1920x1080.png,
    # variants/icon_b.png, variants/icon_c.png (+ .svg-исходники рядом)
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), '..', '..', 'assets')
    render({'icon_512.png': (512, 512, icon_a()), 'badge_512.png': (512, 512, badge()),
            'thumbnail_1920x1080.png': (1920, 1080, thumb()),
            'variants/icon_b.png': (512, 512, icon_b()), 'variants/icon_c.png': (512, 512, icon_c())}, out)
