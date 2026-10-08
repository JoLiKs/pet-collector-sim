# SVG building blocks for the game icon / badge / thumbnail (cartoon Roblox-simulator style, thick outlines).
OL = '#1b1840'  # outline colour

def defs():
    return f'''
<defs>
  <radialGradient id="bgSun" cx="50%" cy="45%" r="70%"><stop offset="0" stop-color="#fff6a8"/><stop offset=".45" stop-color="#ffc93c"/><stop offset="1" stop-color="#ff7b29"/></radialGradient>
  <radialGradient id="bgMagic" cx="50%" cy="45%" r="75%"><stop offset="0" stop-color="#7ef0ff"/><stop offset=".4" stop-color="#3a8dff"/><stop offset="1" stop-color="#3b1a9e"/></radialGradient>
  <radialGradient id="bgMeadow" cx="50%" cy="35%" r="80%"><stop offset="0" stop-color="#e9fbff"/><stop offset=".5" stop-color="#7fd4ff"/><stop offset="1" stop-color="#2f7fe0"/></radialGradient>
  <linearGradient id="gold" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff3a0"/><stop offset=".5" stop-color="#ffc928"/><stop offset="1" stop-color="#e88a0c"/></linearGradient>
  <linearGradient id="goldRim" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffb81c"/><stop offset="1" stop-color="#c46a06"/></linearGradient>
  <linearGradient id="blade" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#ffffff"/><stop offset=".5" stop-color="#d9ecff"/><stop offset="1" stop-color="#8fb0d8"/></linearGradient>
  <linearGradient id="gem" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#c8fbff"/><stop offset=".5" stop-color="#4fd2ff"/><stop offset="1" stop-color="#1673e0"/></linearGradient>
  <linearGradient id="gemPink" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ffd6f5"/><stop offset=".5" stop-color="#ff6ad5"/><stop offset="1" stop-color="#b0249a"/></linearGradient>
  <linearGradient id="egg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ffffff"/><stop offset=".6" stop-color="#e8f3ff"/><stop offset="1" stop-color="#b9cdf0"/></linearGradient>
  <linearGradient id="catBody" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#9ee7ff"/><stop offset="1" stop-color="#3fa9f5"/></linearGradient>
  <linearGradient id="bunBody" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffe0f2"/><stop offset="1" stop-color="#ff9ccf"/></linearGradient>
  <linearGradient id="dogBody" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffd9a0"/><stop offset="1" stop-color="#f0a050"/></linearGradient>
  <linearGradient id="grass" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#8af06a"/><stop offset="1" stop-color="#2fa84a"/></linearGradient>
  <radialGradient id="aura" cx="50%" cy="50%" r="50%"><stop offset="0" stop-color="#fffbd0" stop-opacity=".95"/><stop offset=".55" stop-color="#ffe14a" stop-opacity=".55"/><stop offset="1" stop-color="#ffb000" stop-opacity="0"/></radialGradient>
  <filter id="shadow" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="6" stdDeviation="6" flood-color="#000" flood-opacity=".35"/></filter>
</defs>'''

def sunburst(cx, cy, n=16, r=900, c1='#ffffff', op=.22):
    import math
    out = []
    for i in range(n):
        a0 = 2 * math.pi * i / n; a1 = a0 + math.pi / n
        out.append(f'<polygon points="{cx},{cy} {cx + r*math.cos(a0):.1f},{cy + r*math.sin(a0):.1f} {cx + r*math.cos(a1):.1f},{cy + r*math.sin(a1):.1f}" fill="{c1}" opacity="{op}"/>')
    return '<g>' + ''.join(out) + '</g>'

def coin(x, y, r, rot=0):
    return f'''<g transform="translate({x},{y}) rotate({rot})" filter="url(#shadow)">
  <ellipse cx="0" cy="0" rx="{r}" ry="{r}" fill="url(#goldRim)" stroke="{OL}" stroke-width="{r*0.12:.1f}"/>
  <ellipse cx="0" cy="{-r*0.04:.1f}" rx="{r*0.78:.1f}" ry="{r*0.78:.1f}" fill="url(#gold)"/>
  <ellipse cx="0" cy="{-r*0.04:.1f}" rx="{r*0.56:.1f}" ry="{r*0.56:.1f}" fill="none" stroke="#e39a12" stroke-width="{r*0.07:.1f}"/>
  <path d="M0,{-r*0.36:.1f} L{r*0.1:.1f},{-r*0.1:.1f} L{r*0.36:.1f},0 L{r*0.1:.1f},{r*0.1:.1f} L0,{r*0.36:.1f} L{-r*0.1:.1f},{r*0.1:.1f} L{-r*0.36:.1f},0 L{-r*0.1:.1f},{-r*0.1:.1f}Z" fill="#fff8d0"/>
  <ellipse cx="{-r*0.38:.1f}" cy="{-r*0.42:.1f}" rx="{r*0.22:.1f}" ry="{r*0.1:.1f}" fill="#fff" opacity=".8" transform="rotate(-35 {-r*0.38:.1f} {-r*0.42:.1f})"/>
</g>'''

def gem(x, y, s, fill='url(#gem)', rot=0):
    return f'''<g transform="translate({x},{y}) rotate({rot}) scale({s})" filter="url(#shadow)">
  <polygon points="-30,-12 -16,-30 16,-30 30,-12 0,34" fill="{fill}" stroke="{OL}" stroke-width="6" stroke-linejoin="round"/>
  <polygon points="-30,-12 30,-12 0,34" fill="#000" opacity=".12"/>
  <polygon points="-16,-30 0,-12 16,-30" fill="#fff" opacity=".55"/>
  <polygon points="-30,-12 -16,-30 -8,-12" fill="#fff" opacity=".35"/>
</g>'''

def sparkle(x, y, s, c='#ffffff'):
    return f'<path transform="translate({x},{y}) scale({s})" d="M0,-20 C3,-5 5,-3 20,0 C5,3 3,5 0,20 C-3,5 -5,3 -20,0 C-5,-3 -3,-5 0,-20Z" fill="{c}"/>'

def sword(x, y, s, rot):
    # vertical sword pointing up, origin at the grip centre
    return f'''<g transform="translate({x},{y}) rotate({rot}) scale({s})" filter="url(#shadow)">
  <path d="M-15,-30 L-15,-205 L0,-240 L15,-205 L15,-30Z" fill="url(#blade)" stroke="{OL}" stroke-width="8" stroke-linejoin="round"/>
  <path d="M0,-40 L0,-215" stroke="#7fe3ff" stroke-width="6" stroke-linecap="round"/>
  <rect x="-55" y="-38" width="110" height="22" rx="11" fill="url(#gold)" stroke="{OL}" stroke-width="8"/>
  <rect x="-11" y="-18" width="22" height="58" rx="8" fill="#8a4a24" stroke="{OL}" stroke-width="8"/>
  <circle cx="0" cy="50" r="17" fill="url(#gold)" stroke="{OL}" stroke-width="8"/>
</g>'''

def egg_bottom(x, y, s):
    # lower half of a cracked egg (zigzag top edge)
    return f'''<g transform="translate({x},{y}) scale({s})" filter="url(#shadow)">
  <path d="M-120,-10 L-95,-40 L-70,-8 L-40,-45 L-10,-10 L20,-48 L48,-12 L78,-42 L100,-10 L122,-30
           C130,40 95,120 0,120 C-95,120 -132,50 -120,-10Z" fill="url(#egg)" stroke="{OL}" stroke-width="9" stroke-linejoin="round"/>
  <ellipse cx="-55" cy="45" rx="20" ry="14" fill="#7fc8ff"/>
  <ellipse cx="45" cy="70" rx="26" ry="16" fill="#ffb3e0"/>
  <ellipse cx="70" cy="15" rx="12" ry="9" fill="#9bf09a"/>
</g>'''

def egg_full(x, y, s, spots=('#7fc8ff', '#ffb3e0', '#9bf09a')):
    return f'''<g transform="translate({x},{y}) scale({s})" filter="url(#shadow)">
  <path d="M0,-130 C70,-130 120,-30 120,30 C120,95 70,130 0,130 C-70,130 -120,95 -120,30 C-120,-30 -70,-130 0,-130Z" fill="url(#egg)" stroke="{OL}" stroke-width="9"/>
  <ellipse cx="-45" cy="-40" rx="22" ry="16" fill="{spots[0]}"/><ellipse cx="40" cy="20" rx="28" ry="18" fill="{spots[1]}"/><ellipse cx="-30" cy="70" rx="16" ry="12" fill="{spots[2]}"/>
  <ellipse cx="-50" cy="-80" rx="18" ry="30" fill="#fff" opacity=".85" transform="rotate(25 -50 -80)"/>
</g>'''

def cat(x, y, s, body='url(#catBody)', ear_in='#ff9fd0', eye='#1b1840', mood='happy', arm=None):
    # chibi cat: big head, ears, huge eyes with highlights, blush, w-mouth; arm = (angle) raised paw
    paw = ''
    if arm is not None:  # paw gripping the sword handle at the right side of the body (drawn over the head/body)
        paw = f'<ellipse cx="112" cy="62" rx="34" ry="30" fill="{body}" stroke="{OL}" stroke-width="9"/><path d="M98,50 Q112,44 126,50" fill="none" stroke="{OL}" stroke-width="5" stroke-linecap="round" opacity=".6"/>'
    return f'''<g transform="translate({x},{y}) scale({s})">
  <ellipse cx="0" cy="95" rx="92" ry="78" fill="{body}" stroke="{OL}" stroke-width="10"/>
  <ellipse cx="0" cy="110" rx="52" ry="44" fill="#fff" opacity=".55"/>
  <path d="M-118,-40 L-112,-150 L-40,-100Z" fill="{body}" stroke="{OL}" stroke-width="10" stroke-linejoin="round"/>
  <path d="M118,-40 L112,-150 L40,-100Z" fill="{body}" stroke="{OL}" stroke-width="10" stroke-linejoin="round"/>
  <path d="M-100,-62 L-100,-125 L-58,-98Z" fill="{ear_in}"/>
  <path d="M100,-62 L100,-125 L58,-98Z" fill="{ear_in}"/>
  <ellipse cx="0" cy="-10" rx="135" ry="112" fill="{body}" stroke="{OL}" stroke-width="10"/>
  <ellipse cx="-60" cy="-75" rx="38" ry="16" fill="#fff" opacity=".5" transform="rotate(-20 -60 -75)"/>
  <ellipse cx="-50" cy="0" rx="30" ry="38" fill="{eye}"/>
  <ellipse cx="50" cy="0" rx="30" ry="38" fill="{eye}"/>
  <circle cx="-60" cy="-14" r="12" fill="#fff"/><circle cx="40" cy="-14" r="12" fill="#fff"/>
  <circle cx="-42" cy="14" r="6" fill="#fff"/><circle cx="58" cy="14" r="6" fill="#fff"/>
  <ellipse cx="-92" cy="38" rx="22" ry="12" fill="#ff7fb5" opacity=".75"/>
  <ellipse cx="92" cy="38" rx="22" ry="12" fill="#ff7fb5" opacity=".75"/>
  <path d="M-22,42 Q-11,58 0,44 Q11,58 22,42" fill="none" stroke="{OL}" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M-8,30 L8,30 L0,39Z" fill="#ff6fa8" stroke="{OL}" stroke-width="4" stroke-linejoin="round"/>
  {paw}
</g>'''

def bunny(x, y, s):
    b = 'url(#bunBody)'
    return f'''<g transform="translate({x},{y}) scale({s})">
  <ellipse cx="0" cy="90" rx="85" ry="72" fill="{b}" stroke="{OL}" stroke-width="10"/>
  <ellipse cx="-45" cy="-140" rx="30" ry="85" fill="{b}" stroke="{OL}" stroke-width="10" transform="rotate(-12 -45 -140)"/>
  <ellipse cx="45" cy="-140" rx="30" ry="85" fill="{b}" stroke="{OL}" stroke-width="10" transform="rotate(12 45 -140)"/>
  <ellipse cx="-45" cy="-140" rx="13" ry="60" fill="#fff" opacity=".7" transform="rotate(-12 -45 -140)"/>
  <ellipse cx="45" cy="-140" rx="13" ry="60" fill="#fff" opacity=".7" transform="rotate(12 45 -140)"/>
  <ellipse cx="0" cy="-5" rx="125" ry="105" fill="{b}" stroke="{OL}" stroke-width="10"/>
  <ellipse cx="-46" cy="0" rx="26" ry="34" fill="{OL}"/><ellipse cx="46" cy="0" rx="26" ry="34" fill="{OL}"/>
  <circle cx="-55" cy="-12" r="10" fill="#fff"/><circle cx="37" cy="-12" r="10" fill="#fff"/>
  <ellipse cx="-85" cy="38" rx="20" ry="11" fill="#ff5f9e" opacity=".6"/><ellipse cx="85" cy="38" rx="20" ry="11" fill="#ff5f9e" opacity=".6"/>
  <path d="M-16,40 Q0,56 16,40" fill="none" stroke="{OL}" stroke-width="8" stroke-linecap="round"/>
</g>'''

def dog(x, y, s):
    b = 'url(#dogBody)'
    return f'''<g transform="translate({x},{y}) scale({s})">
  <ellipse cx="0" cy="90" rx="88" ry="74" fill="{b}" stroke="{OL}" stroke-width="10"/>
  <ellipse cx="0" cy="-5" rx="130" ry="108" fill="{b}" stroke="{OL}" stroke-width="10"/>
  <ellipse cx="-118" cy="-10" rx="38" ry="70" fill="#b8692c" stroke="{OL}" stroke-width="10" transform="rotate(18 -118 -10)"/>
  <ellipse cx="118" cy="-10" rx="38" ry="70" fill="#b8692c" stroke="{OL}" stroke-width="10" transform="rotate(-18 118 -10)"/>
  <ellipse cx="0" cy="40" rx="60" ry="42" fill="#fff3dc"/>
  <ellipse cx="-48" cy="-12" rx="25" ry="32" fill="{OL}"/><ellipse cx="48" cy="-12" rx="25" ry="32" fill="{OL}"/>
  <circle cx="-56" cy="-24" r="10" fill="#fff"/><circle cx="40" cy="-24" r="10" fill="#fff"/>
  <ellipse cx="0" cy="22" rx="18" ry="12" fill="{OL}"/>
  <path d="M-18,44 Q0,60 18,44" fill="none" stroke="{OL}" stroke-width="7" stroke-linecap="round"/>
  <path d="M-6,52 Q0,74 8,52" fill="#ff6f8a" stroke="{OL}" stroke-width="5"/>
</g>'''

def bolt(x, y, s, rot=0):
    return f'<path transform="translate({x},{y}) rotate({rot}) scale({s})" d="M10,-60 L-25,5 L0,5 L-12,60 L28,-12 L2,-12 L18,-60Z" fill="#fff36b" stroke="{OL}" stroke-width="6" stroke-linejoin="round"/>'
