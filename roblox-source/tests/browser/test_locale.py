#!/usr/bin/env python3
"""Chromium-тест локализации: язык по стране (?country=RU / US), реальная гео-IP эмулятора (CORS-сервисы с фолбэками),
фолбэк на navigator.language, переключатель RU/EN в настройках и сохранение выбора в данных игрока.
Запуск:  bash tests/browser/build_ui_site.sh && python3 tests/browser/test_locale.py [--shots DIR]
Скриншоты: docs/screens/22_ru_hud.png, 22b_ru_pets.png … 22h_ru_craft.png."""
import os, re, sys, time
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.environ.get('R2W_DIR', '/workspace/roblox2web') + '/tests/browser')
sys.path.insert(0, HERE)
from ui_helpers import *  # noqa: F401,F403  (serve, G, ARGS, sync_playwright)

SHOTS = os.path.join(HERE, '..', '..', 'docs', 'screens')
if '--shots' in sys.argv: SHOTS = sys.argv[sys.argv.index('--shots') + 1]
os.makedirs(SHOTS, exist_ok=True)
fails = []; oks = 0
CYR = re.compile('[\u0400-\u04FF]')
def check(name, cond, info=''):
    global oks
    if cond: oks += 1; print('OK  ', name)
    else: fails.append(name); print('FAIL', name, str(info)[:300])

def lang_attr(page):
    return page.evaluate("(()=>{const p=R2W.ENV.localPlayer; return p&&p.attrs? p.attrs.get('Lang'): null})()")

def world_texts(page):
    # тексты мира с атрибутом Loc_Text (билборды/таблички, созданные Locale.setWorld); строки Luau в эмуляторе — байты UTF-8
    return page.evaluate("""(()=>{const out=[];const walk=(n)=>{ if(n.attrs&&n.attrs.get('Loc_Text')!==undefined&&typeof n.props.Text==='string') out.push((()=>{try{return decodeURIComponent(escape(n.props.Text))}catch(e){return n.props.Text}})()); for(const c of n.children) walk(c); }; walk(R2W.ENV.workspace); return out;})()""")

def menu_text(g, n):
    try:
        return g.text('[data-n="Menu"] [data-n="%s"]' % n).strip().upper()
    except Exception:
        return ''

def eventually(page, fn, timeout=12):
    t = time.time()
    while time.time() - t < timeout:
        try:
            if fn(): return True
        except Exception:
            pass
        page.wait_for_timeout(250)
    return False

def menu_is(page, g, word):
    return eventually(page, lambda: menu_text(g, 'Pets').startswith(word))

def boot(page, url, query):
    page.goto(url + 'index.html?' + query)
    g = G(page); g.shots = SHOTS
    g.wait(lambda: g.vis('[data-n="Menu"]'), what='menu')
    g.wait(lambda: lang_attr(page) in ('ru', 'en'), what='Lang attribute')
    page.wait_for_timeout(1200)
    return g

with serve('/tmp/gw_ui') as url, sync_playwright() as pw:
    b = pw.chromium.launch(executable_path='/usr/bin/google-chrome', args=ARGS)
    def ctx(locale='en-US'):
        return b.new_context(viewport={'width': 1280, 'height': 760}, locale=locale)

    # ---------- 1) ?country=RU -> русский (браузер en-US)
    c = ctx('en-US'); page = c.new_page(); errs = collect(page)
    g = boot(page, url, 'persist=0&seed=1&country=RU')
    check('RU: атрибут Lang = ru', lang_attr(page) == 'ru', lang_attr(page))
    check('RU: страна из ?country (geo.source=param)', page.evaluate('R2W.geo.country') == 'RU' and page.evaluate('R2W.geo.source') == 'param')
    check('RU: меню на русском (Питомцы)', menu_is(page, g, 'ПИТОМЦЫ'), menu_text(g, 'Pets'))
    check('RU: кнопка удара «УДАР [Q]» (без ⚔)', g.text('[data-n="Attack"]').strip() == 'УДАР [Q]', g.text('[data-n="Attack"]'))
    check('RU: кнопка настроек показывает RU', 'RU' in g.text('[data-n="Settings"]') and CYR.search(g.text('[data-n="Settings"]')) is not None, g.text('[data-n="Settings"]'))
    check('RU: подписи демо (верхняя панель) на русском', page.inner_text('#r2w-btn-players') == 'Игроки' and page.evaluate('document.documentElement.lang') == 'ru')
    eventually(page, lambda: sum(1 for t in world_texts(page) if CYR.search(t)) > 10)
    wt = world_texts(page)
    ru_world = [t for t in wt if CYR.search(t)]
    check('RU: тексты мира переведены (%d из %d с кириллицей)' % (len(ru_world), len(wt)), len(wt) > 10 and len(ru_world) >= len(wt) * 0.8, [t for t in wt if not CYR.search(t)][:12])
    g.cmd('seed'); page.wait_for_timeout(800)
    g.shot('22_ru_hud')
    # подсказка ProximityPrompt у яйца
    g.cmd('tp:-22,-76')
    g.wait(lambda: page.evaluate('!!R2W.ENV.prompts.active'), what='egg prompt'); page.wait_for_timeout(300)
    pa = page.inner_text('#r2w-pa')
    check('RU: ProximityPrompt на русском', CYR.search(pa) is not None, pa)
    page.keyboard.press('e')
    g.wait(lambda: g.vis('[data-n="EggPanel"]'), what='egg panel'); page.wait_for_timeout(600)
    egg_txt = g.text('[data-n="EggPanel"]')
    check('RU: панель яйца на русском', CYR.search(egg_txt) is not None and 'Hatch' not in egg_txt, egg_txt[:120])
    g.click('[data-n="EggPanel"] [data-n="Hatch1"]')
    g.wait(lambda: g.vis('[data-n="HatchOverlay"]'), what='hatch'); page.wait_for_timeout(1200)
    g.click('[data-n="HatchOverlay"] [data-n="Awesome"]')
    if g.vis('[data-n="EggPanel"]'): g.click('[data-n="EggPanel"] [data-n="Close"]')
    # диалог NPC (реплики из данных переводятся через Names)
    g.cmd('tp:-30,30')
    g.wait(lambda: page.evaluate('!!R2W.ENV.prompts.active'), what='npc prompt')
    page.keyboard.press('e')
    g.wait(lambda: g.vis('[data-n="DialogBox"]'), what='dialog'); page.wait_for_timeout(600)
    d_txt = g.text('[data-n="DialogBox"]')
    check('RU: диалог NPC на русском', CYR.search(d_txt) is not None and 'Accept' not in d_txt, d_txt[:160])
    g.shot('22f_ru_dialog')
    for _ in range(3):
        if not g.vis('[data-n="DialogBox"]'): break
        if g.vis('[data-n="DialogBox"] [data-n="Close"]'): g.click('[data-n="DialogBox"] [data-n="Close"]'); break
        page.keyboard.press('Escape'); page.wait_for_timeout(300)
    g.cmd('tp:40,40'); page.wait_for_timeout(500)
    # подсказка ProximityPrompt рисуется поверх интерфейса — прячем её на скриншотах панелей
    page.add_style_tag(content='#r2w-prompt{visibility:hidden !important}')
    g.click('[data-n="Menu"] [data-n="Talents"]'); page.wait_for_timeout(800)
    tl_txt = g.text('[data-n="TalentsPanel"]')
    check('RU: таланты (Экономика/Бой/Природа)', all(w in tl_txt for w in ['Экономика', 'Бой', 'Природа']), tl_txt[:160])
    g.shot('22g_ru_talents')
    g.click('[data-n="TalentsPanel"] [data-n="Close"]')
    g.click('[data-n="Menu"] [data-n="Craft"]'); page.wait_for_timeout(800)
    g.shot('22h_ru_craft')
    g.click('[data-n="CraftPanel"] [data-n="Close"]')
    g.click('[data-n="Menu"] [data-n="Pets"]'); page.wait_for_timeout(800)
    pets_txt = g.text('[data-n="PetsPanel"]')
    check('RU: панель питомцев (Стихия: все, Питомцы N/M)', 'Стихия: все' in pets_txt and 'Питомцы' in pets_txt, pets_txt[:160])
    g.click('[data-n="PetsPanel"] [data-n="p1"]'); page.wait_for_timeout(500)
    g.shot('22b_ru_pets')
    g.click('[data-n="PetsPanel"] [data-n="Close"]')
    g.click('[data-n="Menu"] [data-n="Quests"]'); page.wait_for_timeout(800)
    q_txt = g.text('[data-n="QuestsPanel"]')
    check('RU: журнал заданий на русском', CYR.search(q_txt) is not None, q_txt[:120])
    g.shot('22c_ru_quests')
    g.click('[data-n="QuestsPanel"] [data-n="Close"]')
    g.click('[data-n="Menu"] [data-n="Market"]'); page.wait_for_timeout(800)
    g.shot('22d_ru_market')
    g.click('[data-n="MarketPanel"] [data-n="Close"]')
    g.click('[data-n="Menu"] [data-n="Trade"]'); page.wait_for_timeout(800)
    t_txt = g.text('[data-n="TradePanel"]')
    check('RU: торговля на русском (Торговец Том)', 'Торговец Том' in t_txt, t_txt[:160])
    g.shot('22e_ru_trade')
    g.click('[data-n="TradePanel"] [data-n="Close"]')
    # переключение на английский в настройках — всё перерисовывается без перезагрузки
    g.click('[data-n="Settings"]')
    g.wait(lambda: g.vis('[data-n="SettingsPanel"]'), what='settings')
    g.click('[data-n="SettingsPanel"] [data-n="Lang_en"]')
    g.wait(lambda: lang_attr(page) == 'en', what='lang en'); page.wait_for_timeout(800)
    check('RU->EN: меню перерисовано (Pets)', menu_is(page, g, 'PETS'), menu_text(g, 'Pets'))
    check('RU->EN: заголовок панели настроек на английском', 'Settings' in g.text('[data-n="SettingsPanel"]'))
    eventually(page, lambda: sum(1 for t in world_texts(page) if CYR.search(t)) == 0)
    wt2 = world_texts(page)
    check('RU->EN: тексты мира вернулись на английский', len(wt2) > 10 and sum(1 for t in wt2 if CYR.search(t)) == 0, [t for t in wt2 if CYR.search(t)][:8])
    g.click('[data-n="SettingsPanel"] [data-n="Lang_ru"]')
    g.wait(lambda: lang_attr(page) == 'ru', what='lang ru'); page.wait_for_timeout(500)
    check('EN->RU: снова русский', menu_is(page, g, 'ПИТОМЦЫ'))
    check('RU: ошибок эмулятора нет', page.evaluate('R2W.ENV.errorCount') == 0, page.evaluate('R2W.ENV.errorCount'))
    check('RU: в консоли страницы нет ошибок', not [e for e in errs if 'favicon' not in e], errs[:3])
    c.close()

    # ---------- 2) ?country=US в русском браузере -> английский; ручной выбор сохраняется в данных (persist)
    c = ctx('ru-RU'); page = c.new_page(); errs = collect(page)
    g = boot(page, url, 'seed=1&country=US')
    check('US: Lang = en (страна главнее ru-RU браузера)', lang_attr(page) == 'en', lang_attr(page))
    check('US: меню на английском', menu_is(page, g, 'PETS'))
    check('US: удар «ATTACK [Q]»', g.text('[data-n="Attack"]').strip() == 'ATTACK [Q]', g.text('[data-n="Attack"]'))
    check('US: LocaleId из navigator.language = ru-ru', page.evaluate("R2W.ENV.localPlayer.props.LocaleId") == 'ru-ru')
    check('US: подписи демо на английском', page.inner_text('#r2w-btn-players') == 'Players')
    g.click('[data-n="Settings"]')
    g.wait(lambda: g.vis('[data-n="SettingsPanel"]'), what='settings')
    g.click('[data-n="SettingsPanel"] [data-n="Lang_ru"]')
    g.wait(lambda: lang_attr(page) == 'ru', what='manual ru'); page.wait_for_timeout(500)
    page.evaluate('R2W.ENV.shutdown()')  # как при закрытии вкладки: сохранение данных
    page.wait_for_timeout(500)
    g = boot(page, url, 'seed=1&country=US')
    check('US + ручной RU: выбор сохранился после перезагрузки', lang_attr(page) == 'ru' and menu_is(page, g, 'ПИТОМЦЫ'), lang_attr(page))
    c.close()

    # ---------- 3) реальная гео-IP без параметров: какой CORS-сервис ответил
    c = ctx('en-US'); page = c.new_page()
    g = boot(page, url, 'persist=0&seed=1')
    page.wait_for_function('R2W.geo.status !== "pending"', timeout=10000)
    geo = page.evaluate('({status:R2W.geo.status,country:R2W.geo.country,source:R2W.geo.source,tried:R2W.geo.tried})')
    print('     geo:', geo)
    check('гео-IP: страна определена реальным сервисом (%s -> %s)' % (geo['source'], geo['country']), geo['status'] == 'ok' and geo['source'] not in ('param',), geo)
    check('гео-IP: атрибут Country совпадает', page.evaluate("R2W.ENV.localPlayer.attrs.get('Country')") == geo['country'])
    c.close()

    # ---------- 4) Cloudflare заблокирован -> следующий сервис цепочки
    c = ctx('en-US'); page = c.new_page()
    page.route(re.compile(r'.*cloudflare\.com/cdn-cgi/trace.*'), lambda r: r.abort())
    g = boot(page, url, 'persist=0&seed=1')
    page.wait_for_function('R2W.geo.status !== "pending"', timeout=10000)
    geo = page.evaluate('({status:R2W.geo.status,source:R2W.geo.source,tried:R2W.geo.tried})')
    print('     geo (cloudflare blocked):', geo)
    check('гео-IP: фолбэк на следующий сервис', geo['status'] == 'ok' and geo['source'] != 'cloudflare' and not geo['tried'][0]['ok'], geo)
    c.close()

    # ---------- 5) вся гео-IP недоступна -> navigator.language (ru-RU) -> русский, в пределах ~2 с
    c = ctx('ru-RU'); page = c.new_page()
    page.route(re.compile(r'.*(cloudflare\.com|geojs\.io|country\.is|ipapi\.co).*'), lambda r: r.abort())
    t0 = time.time()
    g = boot(page, url, 'persist=0&seed=1')
    page.wait_for_function('R2W.geo.status !== "pending"', timeout=10000)
    geo = page.evaluate('({status:R2W.geo.status,source:R2W.geo.source})')
    check('гео-IP недоступна -> fail', geo['status'] == 'fail', geo)
    check('гео-IP недоступна + ru-RU браузер -> русский', lang_attr(page) == 'ru' and menu_is(page, g, 'ПИТОМЦЫ'), lang_attr(page))
    check('гео-IP недоступна: атрибут Country пуст', page.evaluate("R2W.ENV.localPlayer.attrs.get('Country')") == '')
    c.close()

    # ---------- 6) ?lang=en в русском браузере -> английский, без сетевых запросов
    c = ctx('ru-RU'); page = c.new_page()
    hits = []
    page.on('request', lambda r: hits.append(r.url) if re.search(r'cdn-cgi/trace|geojs|country\.is|ipapi', r.url) else None)
    g = boot(page, url, 'persist=0&seed=1&lang=en')
    check('?lang=en: английский в ru-RU браузере', lang_attr(page) == 'en' and menu_is(page, g, 'PETS'), lang_attr(page))
    check('?lang=en: гео-запросов нет', not hits, hits)
    c.close()
    b.close()

print('\n%d ok, %d failed %s' % (oks, len(fails), fails))
sys.exit(1 if fails else 0)
