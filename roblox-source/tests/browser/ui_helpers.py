import sys,time,os
sys.path.insert(0,'/workspace/roblox2web/tests/browser')
from common import *
class G:
    def __init__(s,page): s.p=page; s.logs=[]; page.on('console',lambda m: s.logs.append(m.text))
    def cmd(s,c,wait=True):
        n=len(s.logs)
        s.p.evaluate("(c)=>{const w=R2W.ENV.workspace;w.attrs=w.attrs||new Map();w.attrs.set('UiCmd',c)}",c)
        if wait: s.wait(lambda: any(('UIDRIVER' in l and c in l) for l in s.logs[n:]),what=c)
    def wait(s,fn,timeout=40,what=''):
        t=time.time()
        while time.time()-t<timeout:
            if fn(): return True
            s.p.wait_for_timeout(250)
        raise AssertionError('timeout '+what)
    def vwait(s,sec):
        t0=s.p.evaluate('R2W.ENV.rt.now')
        s.wait(lambda: s.p.evaluate('R2W.ENV.rt.now')-t0>=sec,timeout=sec*8+10,what='vwait')
    def click(s,sel,**k):
        try: s.p.locator(sel).first.click(timeout=k.pop('timeout',15000),**k)
        except Exception:
            try: s.shot('_FAIL')
            except Exception: pass
            raise
    def vis(s,sel): return s.p.locator(sel).first.is_visible() if s.p.locator(sel).count() else False
    def text(s,sel): return s.p.locator(sel).first.inner_text()
    def names(s,sel): return s.p.evaluate("(q)=>[...document.querySelector(q).querySelectorAll('[data-n]')].map(e=>e.dataset.n)",sel)
    # v3.2: детерминированные ожидания — два кадра рендера браузера (кадр на паузе дорисован) и
    # покадровый шаг симуляции на паузе (R2W.ENV.paused + ENV.frame) до выполнения условия
    def raf(s,n=2):
        for _ in range(n): s.p.evaluate("new Promise(r=>requestAnimationFrame(()=>r()))")
    def resync(s):
        # Эмулятор: чтение AbsoluteSize из Lua (layout.ensure) снимает «грязный» флаг корня до flush, и новые
        # дочерние элементы могут не попасть в DOM до следующего изменения. Тесту нужен DOM — синхронизируем корни.
        s.p.evaluate("()=>{const L=R2W.ENV.gui; if(L&&L.roots&&L.syncRoot) for(const r of L.roots.keys()) L.syncRoot(r)}")
    def pause(s):
        s.p.evaluate('R2W.ENV.paused=true'); s.raf()
    def step_until(s,fn,frames=60,dt=0.02):
        for _ in range(frames):
            r=fn()
            if r: return r
            s.p.evaluate('(dt)=>{R2W.ENV.frame(dt); R2W.ENV.gui&&R2W.ENV.gui.flush&&R2W.ENV.gui.flush()}',dt)
        return fn()
    def shot(s,name): s.p.screenshot(path=os.path.join(getattr(s,'shots','/tmp/shots'),name+'.png'))
