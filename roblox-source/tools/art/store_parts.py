# Extra SVG parts for store icons (game passes / developer products), same cartoon style as parts.py.
from parts import OL

def store_defs():
    return '''
<defs>
  <radialGradient id="bgGreen" cx="50%" cy="45%" r="72%"><stop offset="0" stop-color="#eaffb0"/><stop offset=".45" stop-color="#6fdc4a"/><stop offset="1" stop-color="#138a3a"/></radialGradient>
  <radialGradient id="bgPurple" cx="50%" cy="45%" r="75%"><stop offset="0" stop-color="#ffd6ff"/><stop offset=".45" stop-color="#b456ff"/><stop offset="1" stop-color="#3b1490"/></radialGradient>
  <radialGradient id="bgBlue" cx="50%" cy="45%" r="75%"><stop offset="0" stop-color="#d8fbff"/><stop offset=".45" stop-color="#42b8ff"/><stop offset="1" stop-color="#1640b8"/></radialGradient>
  <radialGradient id="bgRed" cx="50%" cy="45%" r="75%"><stop offset="0" stop-color="#ffe6c0"/><stop offset=".45" stop-color="#ff7a4a"/><stop offset="1" stop-color="#a8142e"/></radialGradient>
  <radialGradient id="bgTeal" cx="50%" cy="45%" r="75%"><stop offset="0" stop-color="#e0fff6"/><stop offset=".45" stop-color="#3fd8c0"/><stop offset="1" stop-color="#0f6f86"/></radialGradient>
  <linearGradient id="red" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ff8a8a"/><stop offset="1" stop-color="#d91c3c"/></linearGradient>
  <linearGradient id="steel" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffffff"/><stop offset="1" stop-color="#a9b8cc"/></linearGradient>
  <linearGradient id="wood" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#d8894a"/><stop offset="1" stop-color="#8a4a20"/></linearGradient>
  <linearGradient id="cloth" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffd27a"/><stop offset="1" stop-color="#c9772c"/></linearGradient>
  <linearGradient id="clover" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#b6ff8a"/><stop offset="1" stop-color="#26a843"/></linearGradient>
  <linearGradient id="cloverGold" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff6a0"/><stop offset=".5" stop-color="#ffcf2a"/><stop offset="1" stop-color="#e07b0c"/></linearGradient>
  <linearGradient id="ticket" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ffe9ff"/><stop offset=".5" stop-color="#ff7ae0"/><stop offset="1" stop-color="#8a2be2"/></linearGradient>
  <radialGradient id="orb" cx="40%" cy="35%" r="70%"><stop offset="0" stop-color="#ffffff"/><stop offset=".35" stop-color="#e3a8ff"/><stop offset=".75" stop-color="#9b3dff"/><stop offset="1" stop-color="#4a128f"/></radialGradient>
  <linearGradient id="arrowG" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#b4ff7a"/><stop offset="1" stop-color="#22b04a"/></linearGradient>
</defs>'''

def label(x, y, text, size=120, fill='#fff', sw=None, rot=0):
    sw = sw or size * 0.17
    return (f'<text x="{x}" y="{y}" transform="rotate({rot} {x} {y})" font-family="\'Arial Black\',\'Impact\',sans-serif" font-weight="900" '
            f'font-size="{size}" text-anchor="middle" fill="{fill}" stroke="{OL}" stroke-width="{sw:.1f}" paint-order="stroke" '
            f'filter="url(#shadow)">{text}</text>')

def magnet(x, y, s, rot=0):
    return f'''<g transform="translate({x},{y}) rotate({rot}) scale({s})" filter="url(#shadow)">
  <path d="M-110,-40 L-110,20 A110,110 0 0 0 110,20 L110,-40 L50,-40 L50,20 A50,50 0 0 1 -50,20 L-50,-40Z" fill="url(#red)" stroke="{OL}" stroke-width="10" stroke-linejoin="round"/>
  <rect x="-110" y="-110" width="60" height="72" rx="6" fill="url(#steel)" stroke="{OL}" stroke-width="10"/>
  <rect x="50" y="-110" width="60" height="72" rx="6" fill="url(#steel)" stroke="{OL}" stroke-width="10"/>
  <path d="M-88,30 A88,88 0 0 0 -20,100" fill="none" stroke="#fff" stroke-width="12" stroke-linecap="round" opacity=".55"/>
</g>'''

def crown(x, y, s, rot=0):
    return f'''<g transform="translate({x},{y}) rotate({rot}) scale({s})" filter="url(#shadow)">
  <path d="M-150,70 L-170,-80 L-85,-10 L0,-130 L85,-10 L170,-80 L150,70Z" fill="url(#gold)" stroke="{OL}" stroke-width="12" stroke-linejoin="round"/>
  <rect x="-160" y="60" width="320" height="56" rx="16" fill="url(#goldRim)" stroke="{OL}" stroke-width="12"/>
  <circle cx="-170" cy="-84" r="20" fill="url(#gold)" stroke="{OL}" stroke-width="9"/><circle cx="170" cy="-84" r="20" fill="url(#gold)" stroke="{OL}" stroke-width="9"/>
  <circle cx="0" cy="-134" r="22" fill="url(#gold)" stroke="{OL}" stroke-width="9"/>
  <ellipse cx="0" cy="88" rx="26" ry="20" fill="url(#red)" stroke="{OL}" stroke-width="7"/>
  <ellipse cx="-92" cy="88" rx="18" ry="15" fill="url(#gem)" stroke="{OL}" stroke-width="7"/><ellipse cx="92" cy="88" rx="18" ry="15" fill="url(#gem)" stroke="{OL}" stroke-width="7"/>
  <path d="M-120,40 L-130,-30" stroke="#fff" stroke-width="12" stroke-linecap="round" opacity=".6"/>
</g>'''

def pouch(x, y, s, fill='url(#cloth)'):
    return f'''<g transform="translate({x},{y}) scale({s})" filter="url(#shadow)">
  <path d="M-60,-90 C-120,-40 -150,40 -130,90 C-110,140 110,140 130,90 C150,40 120,-40 60,-90Z" fill="{fill}" stroke="{OL}" stroke-width="11" stroke-linejoin="round"/>
  <path d="M-70,-95 Q0,-60 70,-95 L85,-125 Q0,-100 -85,-125Z" fill="{fill}" stroke="{OL}" stroke-width="10" stroke-linejoin="round"/>
  <path d="M-62,-88 Q0,-70 62,-88" fill="none" stroke="#7a3a12" stroke-width="12" stroke-linecap="round"/>
  <ellipse cx="-70" cy="10" rx="18" ry="45" fill="#fff" opacity=".35" transform="rotate(15 -70 10)"/>
</g>'''

def chest(x, y, s, open_=True):
    lid = ('<path d="M-150,-40 L-130,-150 L130,-150 L150,-40Z" fill="url(#wood)" stroke="#1b1840" stroke-width="11" stroke-linejoin="round"/>'
           '<rect x="-18" y="-150" width="36" height="110" fill="url(#gold)" stroke="#1b1840" stroke-width="8"/>') if open_ else ''
    return f'''<g transform="translate({x},{y}) scale({s})" filter="url(#shadow)">
  {lid}
  <rect x="-160" y="-40" width="320" height="170" rx="18" fill="url(#wood)" stroke="{OL}" stroke-width="12"/>
  <rect x="-160" y="-40" width="320" height="40" fill="url(#goldRim)" stroke="{OL}" stroke-width="10"/>
  <rect x="-30" y="-10" width="60" height="70" rx="10" fill="url(#gold)" stroke="{OL}" stroke-width="9"/>
  <circle cx="0" cy="20" r="9" fill="{OL}"/>
  <path d="M-120,40 L120,40 M-120,90 L120,90" stroke="#6b3412" stroke-width="7" opacity=".5"/>
</g>'''

def clover(x, y, s, fill='url(#clover)', rot=0):
    leaf = lambda a: f'<g transform="rotate({a})"><path d="M0,0 C-70,-30 -95,-120 -40,-140 C-15,-150 0,-120 0,-105 C0,-120 15,-150 40,-140 C95,-120 70,-30 0,0Z" fill="{fill}" stroke="{OL}" stroke-width="10" stroke-linejoin="round"/><path d="M0,-20 L0,-100" stroke="#fff" stroke-width="7" opacity=".45" stroke-linecap="round"/></g>'
    return f'''<g transform="translate({x},{y}) rotate({rot}) scale({s})" filter="url(#shadow)">
  <path d="M0,10 Q20,110 70,170" fill="none" stroke="{OL}" stroke-width="30" stroke-linecap="round"/>
  <path d="M0,10 Q20,110 70,170" fill="none" stroke="#3fbf4a" stroke-width="14" stroke-linecap="round"/>
  {leaf(0)}{leaf(90)}{leaf(180)}{leaf(270)}
  <circle cx="0" cy="0" r="16" fill="{fill}" stroke="{OL}" stroke-width="7"/>
</g>'''

def flask(x, y, s, liquid='url(#orb)'):
    return f'''<g transform="translate({x},{y}) scale({s})" filter="url(#shadow)">
  <path d="M-40,-150 L-40,-70 C-120,-40 -140,40 -110,95 C-80,150 80,150 110,95 C140,40 120,-40 40,-70 L40,-150Z" fill="#e8f6ff" fill-opacity=".85" stroke="{OL}" stroke-width="11" stroke-linejoin="round"/>
  <path d="M-108,30 C-60,10 60,50 108,30 C120,70 100,130 0,132 C-100,130 -120,70 -108,30Z" fill="{liquid}"/>
  <rect x="-55" y="-185" width="110" height="45" rx="12" fill="url(#wood)" stroke="{OL}" stroke-width="10"/>
  <ellipse cx="-60" cy="-10" rx="16" ry="40" fill="#fff" opacity=".6" transform="rotate(20 -60 -10)"/>
  <circle cx="30" cy="70" r="12" fill="#fff" opacity=".7"/><circle cx="-20" cy="95" r="8" fill="#fff" opacity=".7"/>
</g>'''

def orb(x, y, r):
    return f'''<g transform="translate({x},{y})" filter="url(#shadow)">
  <circle r="{r}" fill="url(#orb)" stroke="{OL}" stroke-width="{r*0.09:.1f}"/>
  <path d="M{-r*0.5:.1f},{r*0.2:.1f} C{-r*0.2:.1f},{-r*0.5:.1f} {r*0.5:.1f},{-r*0.3:.1f} {r*0.3:.1f},{r*0.2:.1f}" fill="none" stroke="#fff" stroke-width="{r*0.08:.1f}" stroke-linecap="round" opacity=".7"/>
  <ellipse cx="{-r*0.35:.1f}" cy="{-r*0.45:.1f}" rx="{r*0.22:.1f}" ry="{r*0.12:.1f}" fill="#fff" opacity=".85" transform="rotate(-35 {-r*0.35:.1f} {-r*0.45:.1f})"/>
</g>'''

def ticket(x, y, s, rot=0, star=True):
    st = '<path d="M0,-58 L17,-18 L60,-15 L27,12 L37,55 L0,32 L-37,55 L-27,12 L-60,-15 L-17,-18Z" fill="url(#gold)" stroke="#1b1840" stroke-width="8" stroke-linejoin="round"/>' if star else ''
    return f'''<g transform="translate({x},{y}) rotate({rot}) scale({s})" filter="url(#shadow)">
  <path d="M-170,-100 L170,-100 L170,-30 A30,30 0 0 0 170,30 L170,100 L-170,100 L-170,30 A30,30 0 0 0 -170,-30Z" fill="url(#ticket)" stroke="{OL}" stroke-width="12" stroke-linejoin="round"/>
  <rect x="-140" y="-72" width="280" height="144" rx="14" fill="none" stroke="#fff" stroke-width="7" stroke-dasharray="18 12" opacity=".7"/>
  {st}
</g>'''

def arrow_up(x, y, s):
    return f'<path transform="translate({x},{y}) scale({s})" d="M0,-90 L80,0 L35,0 L35,80 L-35,80 L-35,0 L-80,0Z" fill="url(#arrowG)" stroke="{OL}" stroke-width="10" stroke-linejoin="round" filter="url(#shadow)"/>'

def speed_lines(x, y, s, c='#ffffff'):
    return f'''<g transform="translate({x},{y}) scale({s})" stroke="{c}" stroke-linecap="round" opacity=".9">
  <path d="M-200,-60 L-80,-60" stroke-width="16"/><path d="M-230,0 L-90,0" stroke-width="20"/><path d="M-200,60 L-80,60" stroke-width="16"/>
</g>'''
