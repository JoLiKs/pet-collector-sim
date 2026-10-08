#!/usr/bin/env python3
"""Оригинальная процедурная музыка Pet Collector Simulator (v3.1).

Два бесшовно зацикленных трека, целиком синтезированных этим скриптом (без сэмплов и чужих мелодий):
  * calm_meadow  — спокойная фоновая тема «классика + 8-бит»: альбертиев бас (как у классиков), мягкий
                   пульс-лид, треугольный бас и тихий «струнный» пэд; ре мажор, 84 BPM, 24 такта (~69 с);
  * epic_surge   — эпичная тема для «Суперсилы»: ля минор, 150 BPM, 40 тактов (~64 с), ударные из шума,
                   октавный бас, «медный» лид с терцией и быстрые арпеджио.
Хвосты нот и эхо заворачиваются в начало, поэтому стык цикла не слышен (Looped = true в Roblox).

Плюс короткие звуки морского сундука: chest_spawn (тихий сигнал появления) и chest_open (открытие).

    python3 tools/music/synth.py [OUT_DIR [NAME...]]   -> OUT_DIR/<name>.{wav,ogg}
"""
import os
import subprocess
import sys

import numpy as np

SR = 44100
rng = np.random.default_rng(31)


def midi_hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


NOTE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def n(name):
    """'F#4' -> midi."""
    base = NOTE[name[0]]
    i = 1
    while i < len(name) and name[i] in "#b":
        base += 1 if name[i] == "#" else -1
        i += 1
    return base + 12 * (int(name[i:]) + 1)


# ---------------------------------------------------------------- осцилляторы
def osc(kind, f, t, duty=0.5):
    ph = (f * t) % 1.0
    if kind == "square":
        return np.where(ph < duty, 1.0, -1.0) * 0.8
    if kind == "tri":
        return 4 * np.abs(ph - 0.5) - 1
    if kind == "saw":
        return 2 * ph - 1
    if kind == "sine":
        return np.sin(2 * np.pi * ph)
    raise ValueError(kind)


def env(nsamp, a, d, s, r, dur_s):
    """ADSR (секунды); нота звучит dur_s, затем релиз r."""
    t = np.arange(nsamp) / SR
    e = np.zeros(nsamp)
    a = max(a, 1e-3)
    e = np.where(t < a, t / a, 1.0)
    dec = (t >= a) & (t < a + d)
    e = np.where(dec, 1 - (1 - s) * (t - a) / max(d, 1e-3), e)
    e = np.where((t >= a + d), s, e)
    rel = t >= dur_s
    e = np.where(rel, e * np.clip(1 - (t - dur_s) / max(r, 1e-3), 0, 1), e)
    return e


def lowpass(x, alpha):
    """Мягкий ФНЧ (alpha 0..1, меньше — темнее): свёртка с треугольным окном ~2/alpha отсчётов."""
    w = max(1, int(1 / alpha))
    k = np.convolve(np.ones(w), np.ones(w))
    return np.convolve(x, k / k.sum(), mode="same")


def mix(a, b, gb=1.0):
    """Сумма двух сигналов разной длины."""
    out = np.zeros(max(len(a), len(b)))
    out[: len(a)] += a
    out[: len(b)] += b * gb
    return out


class Track:
    def __init__(self, seconds):
        self.n = int(round(seconds * SR))
        self.buf = np.zeros((self.n, 2))

    def add(self, start_s, sig, pan=0.0, gain=1.0):
        """Кладёт сигнал с заворотом в начало (бесшовный цикл)."""
        s = int(round(start_s * SR)) % self.n
        L = np.cos((pan + 1) * np.pi / 4) * gain
        R = np.sin((pan + 1) * np.pi / 4) * gain
        idx = (np.arange(len(sig)) + s) % self.n
        np.add.at(self.buf[:, 0], idx, sig * L)
        np.add.at(self.buf[:, 1], idx, sig * R)

    def echo(self, delay_s, fb, mix):
        d = int(delay_s * SR)
        wet = np.zeros_like(self.buf)
        tap = self.buf.copy()
        for k in range(1, 5):
            tap = np.roll(tap, d, axis=0) * fb
            # пинг-понг
            wet += tap[:, ::-1] if k % 2 else tap
        self.buf = self.buf + wet * mix

    def finish(self, peak_db):
        x = self.buf
        x = np.tanh(x * 1.2) / np.tanh(1.2)
        x *= 10 ** (peak_db / 20) / (np.max(np.abs(x)) + 1e-9)
        return x


def note_sig(kind, midi, dur_s, adsr, duty=0.5, vib=0.0, vib_rate=5.5, detune=0.0):
    a, d, s, r = adsr
    total = dur_s + r
    t = np.arange(int(total * SR)) / SR
    f = midi_hz(midi) * (1 + detune)
    if vib:
        # вибрато вступает плавно, как у живого исполнителя
        depth = vib * np.clip(t / 0.25, 0, 1)
        phase = np.cumsum(f * (1 + depth * np.sin(2 * np.pi * vib_rate * t))) / SR
        sig = osc(kind, 1.0, phase, duty) if kind != "sine" else np.sin(2 * np.pi * phase)
    else:
        sig = osc(kind, f, t, duty)
    return sig * env(len(t), a, d, s, r, dur_s)


# ---------------------------------------------------------------- спокойная тема
def calm():
    bpm = 84
    beat = 60 / bpm
    bars = 24
    tr = Track(bars * 4 * beat)
    # гармония по тактам (ре мажор): A (8) — A' (8) — B (4) — каданс (4)
    A = ["D", "A", "Bm", "F#m", "G", "D", "Em", "A"]
    A2 = ["D", "A", "Bm", "F#m", "G", "D", "G", "A"]
    B = ["Bm", "G", "D", "A"]
    C = ["G", "A", "D", "D"]
    prog = (A + A2 + B + C)[:bars]
    chords = {
        "D": ["D3", "F#3", "A3"], "A": ["A2", "C#3", "E3"], "A7": ["A2", "C#3", "G3"], "Bm": ["B2", "D3", "F#3"],
        "F#m": ["F#2", "A2", "C#3"], "G": ["G2", "B2", "D3"], "Em": ["E2", "G2", "B2"],
    }
    scale = [n(x) for x in ["D4", "E4", "F#4", "G4", "A4", "B4", "C#5", "D5", "E5", "F#5", "G5", "A5"]]
    for bar, ch in enumerate(prog):
        t0 = bar * 4 * beat
        lo, mid, hi = (n(x) for x in chords[ch])
        # альбертиев бас: 1-5-3-5 восьмыми, мягкий треугольник + немного пульса
        for i, m in enumerate([lo + 12, hi + 12, mid + 12, hi + 12] * 2):
            sig = mix(note_sig("tri", m, beat * 0.45, (0.004, 0.08, 0.5, 0.12)),
                      note_sig("square", m, beat * 0.4, (0.004, 0.05, 0.3, 0.1), duty=0.125), 0.25)
            tr.add(t0 + i * beat / 2, sig, pan=-0.25, gain=0.16)
        # бас — корень, половинками
        for h in range(2):
            m = lo - 12 if h == 0 else hi - 24  # корень, затем квинта аккорда ниже
            tr.add(t0 + h * 2 * beat, note_sig("tri", m, 2 * beat * 0.9, (0.01, 0.2, 0.7, 0.2)), gain=0.30)
        # пэд «струнные»: два слегка расстроенных пилообразных через ФНЧ (только в 2-й половине и в B)
        if bar >= 8:
            pad = np.zeros(int((4 * beat + 0.6) * SR))
            for m in (lo + 12, mid + 12, hi + 12):
                for dt in (-0.004, 0.004):
                    s = note_sig("saw", m, 4 * beat, (0.6, 0.5, 0.8, 0.6), detune=dt)
                    pad[: len(s)] += s
            pad = lowpass(pad, 0.035)
            tr.add(t0, pad, pan=0.3, gain=0.05 if bar < 16 else 0.07)
    # мелодия: на сильных долях звук аккорда, между ними — проходящие ноты; фразы по 2 такта
    chord_pc = {k: [n(x) % 12 for x in v] for k, v in chords.items()}
    rhythms = [
        [1, 0.5, 0.5, 1, 1], [1.5, 0.5, 1, 1], [0.5, 0.5, 0.5, 0.5, 2], [1, 1, 2],
        [0.5, 0.5, 1, 0.5, 0.5, 1], [2, 1, 1], [1, 0.5, 0.5, 2], [3, 1],
    ]
    phrase_bank = {}
    idx = 6  # A4
    for bar, ch in enumerate(prog):
        section = bar // 8
        key = (bar % 8, ch)
        if section == 1 and key in phrase_bank and bar % 8 < 6:
            notes = phrase_bank[key]  # A' повторяет начало A (узнаваемость), конец меняется
        else:
            r = rhythms[(bar * 3 + section) % len(rhythms)] if bar % 2 == 0 else rhythms[(bar * 5 + 1) % len(rhythms)]
            if bar % 8 == 7 or bar == bars - 1:
                r = [2, 2] if bar != bars - 1 else [1, 1, 2]
            notes = []
            pos = 0.0
            for dur in r:
                strong = pos in (0.0, 2.0)
                cands = [i for i in range(len(scale)) if abs(i - idx) <= 3]
                if strong:
                    cands = [i for i in cands if scale[i] % 12 in chord_pc[ch]] or cands
                else:
                    cands = [i for i in cands if abs(i - idx) <= 2] or cands
                # тяготение к середине диапазона
                w = np.array([1.0 / (1 + abs(i - 5) * 0.35) * (1.6 if abs(i - idx) == 1 else 1.0) for i in cands])
                idx = int(rng.choice(cands, p=w / w.sum()))
                notes.append((pos, dur, scale[idx]))
                pos += dur
            if bar == bars - 1:
                notes[-1] = (notes[-1][0], notes[-1][1], n("D5") if notes[-1][2] > n("F#4") else n("D4"))
            phrase_bank[key] = notes
        t0 = bar * 4 * beat
        for pos, dur, m in notes:
            sig = note_sig("square", m, dur * beat * 0.92, (0.012, 0.15, 0.55, 0.18), duty=0.25, vib=0.004)
            sig = lowpass(sig, 0.25)
            tr.add(t0 + pos * beat, sig, pan=0.1, gain=0.13)
            if bar >= 16:  # B-часть: «флейта» октавой выше, тише
                tr.add(t0 + pos * beat, note_sig("sine", m + 12, dur * beat * 0.9, (0.03, 0.1, 0.7, 0.2), vib=0.005),
                       pan=-0.3, gain=0.05)
    tr.echo(beat * 0.75, 0.35, 0.35)
    return tr.finish(-4.0)


# ---------------------------------------------------------------- эпичная тема
def epic():
    bpm = 150
    beat = 60 / bpm
    bars = 40
    tr = Track(bars * 4 * beat)
    loop = ["Am", "F", "C", "G", "Am", "F", "G", "E"]
    chords = {"Am": ["A2", "C3", "E3"], "F": ["F2", "A2", "C3"], "C": ["C3", "E3", "G3"], "G": ["G2", "B2", "D3"],
              "E": ["E2", "G#2", "B2"], "Dm": ["D3", "F3", "A3"]}
    prog = [loop[b % 8] for b in range(bars)]
    for b in range(24, 32):
        prog[b] = ["F", "G", "Am", "Am", "Dm", "F", "E", "E"][b - 24]
    t = np.arange(int(0.35 * SR)) / SR
    kick = np.sin(2 * np.pi * np.cumsum(50 + 120 * np.exp(-t * 30)) / SR) * np.exp(-t * 9)
    tn = np.arange(int(0.22 * SR)) / SR
    snare = (rng.standard_normal(len(tn)) * 0.7 + 0.5 * np.sin(2 * np.pi * 190 * tn)) * np.exp(-tn * 18)
    th = np.arange(int(0.05 * SR)) / SR
    hat = np.diff(rng.standard_normal(len(th) + 1)) * np.exp(-th * 80) * 0.5
    crash_t = np.arange(int(1.6 * SR)) / SR
    crash = np.diff(rng.standard_normal(len(crash_t) + 1)) * np.exp(-crash_t * 2.5) * 0.35
    scale = [n(x) for x in ["A4", "B4", "C5", "D5", "E5", "F5", "G5", "A5", "B5", "C6"]]
    chord_pc = {k: [n(x) % 12 for x in v] for k, v in chords.items()}
    idx = 4
    motifs = {}
    for bar, ch in enumerate(prog):
        t0 = bar * 4 * beat
        intro = bar < 4
        lo, mid, hi = (n(x) for x in chords[ch])
        # ударные
        for k in range(4):
            if not intro or k % 2 == 0:
                if k in (0, 2) or (bar % 2 == 1 and k == 3):
                    tr.add(t0 + k * beat + (beat / 2 if k == 3 else 0), kick, gain=0.55)
            if not intro and k in (1, 3):
                tr.add(t0 + k * beat, snare, gain=0.32, pan=0.05)
        if not intro:
            for e in range(8):
                tr.add(t0 + e * beat / 2, hat, gain=0.18 if e % 2 else 0.1, pan=0.35)
        if bar % 8 == 0:
            tr.add(t0, crash, gain=0.4, pan=-0.3)
        if bar % 8 == 7:  # сбивка малым барабаном в конце фразы
            for e in range(4):
                tr.add(t0 + 3 * beat + e * beat / 4, snare, gain=0.16 + 0.04 * e)
        # бас — октавные восьмые, пила через ФНЧ
        for e in range(8):
            m = lo - 12 + (12 if e % 2 else 0)
            s = lowpass(note_sig("saw", m, beat * 0.42, (0.003, 0.08, 0.6, 0.05)), 0.12)
            tr.add(t0 + e * beat / 2, s, gain=0.30)
        # арпеджио шестнадцатыми (треугольник), со второй фразы
        if bar >= 8:
            arp = [lo + 24, mid + 24, hi + 24, mid + 24]
            for e in range(16):
                tr.add(t0 + e * beat / 4, note_sig("tri", arp[e % 4], beat * 0.2, (0.002, 0.04, 0.4, 0.04)),
                       gain=0.10, pan=-0.4)
        # «медь» — аккорд долгими нотами
        brass = np.zeros(int((4 * beat + 0.3) * SR))
        for m in (lo + 12, mid + 12, hi + 12):
            for dt in (-0.003, 0.003):
                s = note_sig("saw", m, 4 * beat * 0.95, (0.08, 0.3, 0.7, 0.3), detune=dt)
                brass[: len(s)] += s
        brass = lowpass(brass, 0.06 if bar < 8 else 0.1)
        tr.add(t0, brass, gain=0.05, pan=0.25)
        # лид с 8-го такта: героический мотив (повторяется каждые 4 такта с вариацией)
        if bar >= 8:
            mkey = (bar % 4, ch)
            if mkey in motifs and bar % 16 < 12:
                notes = motifs[mkey]
            else:
                rh = [[1.5, 0.5, 1, 1], [0.5, 0.5, 1, 2], [1, 1, 1, 0.5, 0.5], [3, 1]][bar % 4]
                notes = []
                pos = 0.0
                for d in rh:
                    cands = [i for i in range(len(scale)) if abs(i - idx) <= 3]
                    if pos in (0.0, 2.0):
                        cands = [i for i in cands if scale[i] % 12 in chord_pc[ch]] or cands
                    w = np.array([1.0 / (1 + abs(i - 4) * 0.3) for i in cands])
                    idx = int(rng.choice(cands, p=w / w.sum()))
                    notes.append((pos, d, scale[idx]))
                    pos += d
                motifs[mkey] = notes
            for pos, d, m in notes:
                s = note_sig("square", m, d * beat * 0.9, (0.01, 0.1, 0.7, 0.12), duty=0.5, vib=0.006, vib_rate=6)
                s = lowpass(s, 0.3)
                tr.add(t0 + pos * beat, s, gain=0.11, pan=0.1)
                if bar >= 16:  # вторая партия терцией ниже (диатонически)
                    j = scale.index(m) if m in scale else None
                    if j is not None and j >= 2:
                        s2 = lowpass(note_sig("square", scale[j - 2], d * beat * 0.9, (0.01, 0.1, 0.7, 0.12), duty=0.25),
                                     0.3)
                        tr.add(t0 + pos * beat, s2, gain=0.06, pan=-0.2)
    tr.echo(beat * 0.5, 0.25, 0.22)
    return tr.finish(-2.0)


# ---------------------------------------------------------------- короткие звуки сундука
def chest_spawn():
    """Тихий сигнал «где-то появился сундук»: мягкий шорох волны и три колокольчика (2.4 с)."""
    tr = Track(2.4)
    t = np.arange(int(2.4 * SR)) / SR
    wave_ = lowpass(rng.standard_normal(len(t)), 0.02) * np.sin(np.pi * np.clip(t / 2.4, 0, 1)) ** 2
    tr.add(0, wave_, gain=0.6)
    for i, m in enumerate([n("E6"), n("B5"), n("G#6")]):
        bell = mix(note_sig("sine", m, 0.05, (0.002, 0.9, 0.0, 0.9)), note_sig("sine", m + 19, 0.05, (0.002, 0.5, 0, 0.5)),
                   0.3)
        tr.add(0.25 + i * 0.32, bell, pan=(-0.4, 0.4, 0.0)[i], gain=0.35)
    x = tr.buf
    x[-int(0.3 * SR):] *= np.linspace(1, 0, int(0.3 * SR))[:, None]
    tr.buf = x
    return tr.finish(-6.0)


def chest_open():
    """Открытие: скрип крышки (шум через ФНЧ) и звон монет вверх (1.2 с)."""
    tr = Track(1.2)
    t = np.arange(int(0.25 * SR)) / SR
    creak = lowpass(rng.standard_normal(len(t)), 0.05) * np.sin(2 * np.pi * (180 + 300 * t) * t) * np.exp(-t * 6)
    tr.add(0, creak, gain=0.8)
    for i, m in enumerate([n("C6"), n("E6"), n("G6"), n("C7"), n("E7")]):
        tr.add(0.18 + i * 0.07, note_sig("square", m, 0.04, (0.001, 0.15, 0.0, 0.2), duty=0.25), gain=0.25,
               pan=(i - 2) * 0.2)
    x = tr.buf
    x[-int(0.2 * SR):] *= np.linspace(1, 0, int(0.2 * SR))[:, None]
    tr.buf = x
    return tr.finish(-4.0)


def write(path_noext, x):
    import wave

    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(path_noext + ".wav", "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path_noext + ".wav", "-c:a", "libvorbis", "-q:a", "4",
                    path_noext + ".ogg"], check=True)
    return len(x) / SR


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "assets/audio"
    os.makedirs(out, exist_ok=True)
    only = sys.argv[2:]
    for name, fn in (("calm_meadow", calm), ("epic_surge", epic), ("chest_spawn", chest_spawn), ("chest_open", chest_open)):
        if only and name not in only:
            continue
        secs = write(os.path.join(out, name), fn())
        print("%s: %.1f s" % (name, secs))
