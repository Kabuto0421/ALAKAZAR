#!/usr/bin/env python3
"""Render ALAKAZAR's sound effects to Ogg Vorbis files.

Every effect is built from the same few materials and runs through the same
chain, so they sound like one game:

  * materials: cloth/air (filtered noise), wood, stone, iron (modal
    resonators), skin drums, glass chimes. Anything pitched is tuned to
    D minor, the key of the battle theme;
  * one shared room: the same short stone-hall reverb on every effect
    (only the amount changes);
  * one finishing chain: a low cut at 40 Hz, a soft top above 11 kHz, gentle
    tape-like saturation, and loudness matched by category (interface <
    footsteps < hits < big events).

The Prison King's sounds (revive, fortress, his hits and fall) use the same
materials but lean on iron, chains and stone, to match his theme.

Needs numpy and soundfile (`pip install numpy soundfile`). Deterministic.

    python3 tools/generate_sfx.py            # all
    python3 tools/generate_sfx.py hit step   # only these

Writes assets/audio/sfx/<name>.ogg (mono, 44.1 kHz).
"""

import os
import sys

import numpy as np

SR = 44100
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "sfx")
NOTE = {"C": 0, "C#": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "G": 7,
        "G#": 8, "A": 9, "Bb": 10, "B": 11}


def hz(name):
    """'D4' -> Hz."""
    m = 12 * (int(name[-1]) + 1) + NOTE[name[:-1]]
    return 440.0 * 2 ** ((m - 69) / 12)


class Kit:
    """Building blocks. One seeded random source per effect."""

    def __init__(self, seed):
        self.rng = np.random.default_rng(seed)

    # --- time and envelopes -------------------------------------------------
    @staticmethod
    def n(d):
        return max(1, int(d * SR))

    def t(self, d):
        return np.arange(self.n(d)) / SR

    def decay(self, d, tau, attack=0.002):
        t = self.t(d)
        env = np.exp(-t / tau)
        a = self.n(attack)
        env[:a] *= np.linspace(0, 1, a)
        return env * self.tail(len(t))

    @staticmethod
    def tail(n, share=0.3):
        """Fade the last part of a piece to silence, so nothing ends in a click."""
        env = np.ones(n)
        f = max(1, int(n * share))
        env[-f:] = 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, f))
        return env

    def swell(self, d, peak, attack_curve=2.0, release_curve=1.5):
        """Rises to 1 at `peak` (0..1 of the length), then falls to 0."""
        k = np.linspace(0, 1, self.n(d))
        up = (k / peak) ** attack_curve
        down = ((1 - k) / (1 - peak)) ** release_curve
        return np.where(k < peak, up, down)

    # --- sources ------------------------------------------------------------
    def noise(self, d):
        return self.rng.uniform(-1, 1, self.n(d))

    def tone(self, freq, d, shape="sine", harmonics=None):
        """freq: a number or an array (a glide). harmonics: [(multiple, amp)]."""
        f = np.full(self.n(d), float(freq)) if np.isscalar(freq) else np.asarray(freq, float)
        phase = np.cumsum(f) / SR
        if harmonics is None:
            harmonics = [(1, 1.0)]
        out = np.zeros_like(phase)
        for mult, amp in harmonics:
            p = phase * mult
            if shape == "saw":
                out += amp * (2 * (p % 1.0) - 1)
            else:
                out += amp * np.sin(2 * np.pi * p)
        return out

    def glide(self, f0, f1, d, curve=1.0):
        k = np.linspace(0, 1, self.n(d)) ** curve
        return f0 * (f1 / f0) ** k

    def modal(self, d, modes, jitter=0.0):
        """Struck object: modes = [(Hz, decay seconds, amp)]."""
        t = self.t(d)
        out = np.zeros_like(t)
        for f, tau, amp in modes:
            f *= 1 + self.rng.uniform(-jitter, jitter)
            out += amp * np.sin(2 * np.pi * f * t + self.rng.uniform(0, 6.28)) * np.exp(-t / tau)
        a = self.n(0.001)
        out[:a] *= np.linspace(0, 1, a)
        return out * self.tail(len(out))

    # --- filters ------------------------------------------------------------
    @staticmethod
    def band(x, lo=0.0, hi=SR / 2, soft=0.35):
        """Zero-phase band-pass by spectral mask with soft (log) edges."""
        n = len(x)
        size = 1 << int(np.ceil(np.log2(n + 1)))
        spec = np.fft.rfft(x, size)
        f = np.fft.rfftfreq(size, 1 / SR)
        lf = np.log2(np.maximum(f, 1.0))
        mask = np.ones_like(f)
        if lo > 0:
            mask *= np.clip((lf - np.log2(lo)) / soft + 0.5, 0, 1)
        if hi < SR / 2:
            mask *= np.clip((np.log2(hi) - lf) / soft + 0.5, 0, 1)
        return np.fft.irfft(spec * mask, size)[:n]

    def sweep(self, x, lo, hi, soft=0.4):
        """Time-varying band-pass: lo/hi are arrays (or numbers) over x."""
        n = len(x)
        lo = np.broadcast_to(np.asarray(lo, float), (n,)) if np.ndim(lo) == 0 else np.interp(np.arange(n), np.linspace(0, n - 1, len(lo)), lo)
        hi = np.broadcast_to(np.asarray(hi, float), (n,)) if np.ndim(hi) == 0 else np.interp(np.arange(n), np.linspace(0, n - 1, len(hi)), hi)
        block = 512
        hop = block // 2
        win = np.hanning(block)
        pad = np.concatenate([np.zeros(block), x, np.zeros(block)])
        out = np.zeros_like(pad)
        f = np.fft.rfftfreq(block, 1 / SR)
        lf = np.log2(np.maximum(f, 1.0))
        for s in range(0, len(pad) - block, hop):
            c = min(max(s - block + hop, 0), n - 1)
            spec = np.fft.rfft(pad[s:s + block] * win)
            mask = np.clip((lf - np.log2(max(lo[c], 1.0))) / soft + 0.5, 0, 1)
            mask *= np.clip((np.log2(max(hi[c], 2.0)) - lf) / soft + 0.5, 0, 1)
            out[s:s + block] += np.fft.irfft(spec * mask, block) * win
        return out[block:block + n] / 0.75

    # --- materials ----------------------------------------------------------
    def thump(self, d=0.18, f0=120, f1=50, tau=0.06):
        """A body hitting something: a falling low sine."""
        return self.tone(self.glide(f0, f1, d, 0.5), d) * self.decay(d, tau)

    def burst(self, d, lo, hi, tau):
        return self.band(self.noise(d), lo, hi) * self.decay(d, tau)

    def grit(self, d, lo, hi, rate, tau):
        """Grainy noise: scraping, crunching, crackling (random AM)."""
        x = self.band(self.noise(d), lo, hi)
        grains = (self.rng.random(self.n(d)) < rate / SR) * self.rng.uniform(0.1, 1.0, self.n(d)) ** 2
        am = np.convolve(grains, np.hanning(self.n(0.003)), "same")
        return x * am / max(am.max(), 1e-9) * self.decay(d, tau)

    def iron(self, d, base=420, tau=0.35, amp=1.0):
        ratios = [1.0, 2.32, 4.25, 6.63, 9.38]
        return self.modal(d, [(base * r, tau / (1 + 0.4 * i), amp / (1 + i * 0.5)) for i, r in enumerate(ratios)], 0.01)

    def wood(self, d, base=620, tau=0.05, amp=1.0):
        return self.modal(d, [(base, tau, amp), (base * 2.7, tau * 0.6, amp * 0.4), (base * 5.1, tau * 0.3, amp * 0.2)], 0.02)

    def stone(self, d, tau=0.2):
        return self.band(self.noise(d), 90, 1400) * self.decay(d, tau) + self.thump(d, 90, 40, tau * 0.6) * 0.6

    def glass(self, note, d=0.9, amp=1.0):
        f = hz(note)
        return self.modal(d, [(f, 0.5, amp), (f * 2.76, 0.18, amp * 0.3), (f * 5.4, 0.07, amp * 0.15)])

    def chain(self, d=0.35, links=6):
        out = np.zeros(self.n(d))
        for k in range(links):
            at = self.n(self.rng.uniform(0, d * 0.6))
            clink = self.iron(0.12, self.rng.uniform(1800, 3200), 0.05, self.rng.uniform(0.3, 0.8))
            place(out, at, clink)
        return out + self.grit(d, 2500, 9000, 180, d / 3) * 0.3

    def debris(self, d, count=10, lo=300, hi=3000):
        """Pebbles and pieces landing after a crash."""
        out = np.zeros(self.n(d))
        for _ in range(count):
            at = self.n(self.rng.uniform(0.02, d * 0.8) ** 1.3 / (d * 0.8) ** 0.3)
            piece = self.band(self.noise(0.04), lo, hi) * self.decay(0.04, 0.008) * self.rng.uniform(0.2, 0.7)
            place(out, at, piece)
        return out

    def whoosh(self, d, lo0, hi0, lo1, hi1, peak=0.5):
        x = self.sweep(self.noise(d), self.glide(lo0, lo1, d), self.glide(hi0, hi1, d))
        return x * self.swell(d, peak)


def place(buf, at, x, gain=1.0):
    end = min(len(buf), at + len(x))
    if end > at:
        buf[at:end] += x[:end - at] * gain


def layer(*parts):
    """Sum sounds of different lengths (padded to the longest)."""
    out = np.zeros(max(len(x) for x in parts))
    for x in parts:
        out[:len(x)] += x
    return out


def mix(d, *parts):
    """parts: (seconds, samples, gain)."""
    out = np.zeros(Kit.n(d))
    for at, x, g in parts:
        place(out, Kit.n(at), x, g)
    return out


# ---------------------------------------------------------------------------
# The shared room and finishing chain
# ---------------------------------------------------------------------------

def _room_ir():
    k = Kit(1)
    d = 0.9
    tail = k.band(k.noise(d), 150, 5200) * np.exp(-k.t(d) / 0.22)
    for at, g in ((0.011, 0.5), (0.019, 0.35), (0.027, 0.3), (0.041, 0.2)):
        tail[k.n(at)] += g
    tail[0] = 0
    return tail / np.sqrt(np.sum(tail ** 2))


ROOM = _room_ir()
# Loudness by category (short-term RMS target, dBFS).
LEVEL = {"ui": -24.0, "step": -23.0, "hit": -17.0, "big": -15.0, "boss": -14.0}


def finish(x, level="hit", room=0.14):
    x = np.asarray(x, float)
    x = np.concatenate([x, np.zeros(int(0.35 * SR * (room > 0)))])
    if room > 0:
        wet = np.convolve(x, ROOM)[:len(x)]
        x = x + wet * room * np.sqrt(np.mean(x ** 2) / max(np.mean(wet ** 2), 1e-12))
    x = Kit.band(x, 40, 11000, 0.5)
    # Short-term loudness: the loudest 60 ms window.
    w = int(0.06 * SR)
    power = np.convolve(x ** 2, np.ones(w) / w, "same")
    rms = np.sqrt(power.max()) or 1.0
    x *= 10 ** (LEVEL[level] / 20) / rms
    x = np.tanh(x * 1.4) / 1.4
    peak = np.max(np.abs(x))
    if peak > 0.89:
        x *= 0.89 / peak
    # Trim the silent tail, with a short fade.
    loud = np.nonzero(np.abs(x) > 10 ** (-60 / 20))[0]
    end = min(len(x), (loud[-1] if len(loud) else 0) + int(0.02 * SR))
    x = x[:end]
    f = min(len(x), int(0.01 * SR))
    x[-f:] *= np.linspace(1, 0, f)
    return x.astype(np.float32)


# ---------------------------------------------------------------------------
# The effects. Each returns (samples, level, room).
# ---------------------------------------------------------------------------

def step(k):
    # A boot on stone: a soft scuff and a heel.
    return mix(0.2, (0, k.burst(0.08, 120, 1800, 0.018), 0.8), (0, k.thump(0.1, 110, 60, 0.03), 0.9),
               (0.012, k.grit(0.1, 1500, 6000, 400, 0.03), 0.25)), "step", 0.08


def enemy_step(k):
    # Armoured boots: heavier, with a jingle of plates.
    return mix(0.3, (0, k.thump(0.14, 95, 50, 0.04), 1.0), (0, k.burst(0.08, 100, 1400, 0.02), 0.7),
               (0.01, k.iron(0.2, 1700, 0.06, 0.25), 1.0), (0.03, k.iron(0.15, 2300, 0.04, 0.15), 1.0)), "step", 0.08


def slash(k):
    # A blade cutting the air, with the faint ring of steel.
    return mix(0.35, (0, k.whoosh(0.24, 500, 1600, 1400, 6000, 0.45), 1.0),
               (0.08, k.iron(0.3, 1310, 0.12, 0.12), 1.0)), "hit", 0.1


def hit(k):
    # Striking armour and body: a punch, a crunch, a short clank.
    return mix(0.3, (0, k.thump(0.2, 140, 55, 0.06), 1.0), (0, k.burst(0.06, 200, 3500, 0.012), 0.9),
               (0.004, k.grit(0.1, 800, 4000, 900, 0.03), 0.5), (0, k.iron(0.15, 900, 0.05, 0.2), 1.0)), "hit", 0.12


def enemy_die(k):
    # The soldier drops: armour clatters and the body hits the floor.
    return mix(0.9, (0, k.iron(0.4, 780, 0.12, 0.35), 1.0), (0.05, k.debris(0.4, 7, 900, 4500), 0.8),
               (0.22, k.thump(0.3, 90, 40, 0.09), 1.0), (0.22, k.burst(0.2, 100, 1200, 0.05), 0.6),
               (0.3, k.iron(0.3, 1150, 0.08, 0.15), 1.0)), "hit", 0.16


def player_hurt(k):
    # A heavy blow to the hero: a deep punch, cloth tearing, a dull ring.
    return mix(0.5, (0, k.thump(0.3, 150, 45, 0.09), 1.3), (0, k.burst(0.09, 150, 2500, 0.02), 1.0),
               (0.01, k.grit(0.14, 1200, 6000, 1500, 0.05), 0.5),
               (0, k.modal(0.4, [(hz("D3"), 0.16, 0.3), (hz("A3"), 0.12, 0.15)]), 1.0)), "big", 0.12


def turn_player(k):
    # Your turn: a small glass chime, D then A.
    return mix(0.9, (0, k.glass("D5", 0.8, 0.8), 1.0), (0.09, k.glass("A5", 0.8, 0.7), 1.0),
               (0, k.wood(0.08, 900, 0.02, 0.3), 1.0)), "ui", 0.25


def turn_enemy(k):
    # The enemy's turn: two low skin-drum beats.
    def drum():
        return layer(k.modal(0.5, [(hz("D2"), 0.18, 1.0), (hz("D2") * 1.59, 0.1, 0.4)]), k.burst(0.05, 200, 2000, 0.01) * 0.4)
    return mix(0.8, (0, drum(), 0.8), (0.16, drum(), 1.0)), "ui", 0.25


def denied(k):
    # Can't do that: a dull double knock on wood.
    return mix(0.3, (0, k.wood(0.1, 300, 0.03), 1.0), (0.09, k.wood(0.1, 260, 0.03), 1.0)), "ui", 0.08


def select(k):
    # A soft click: a light wooden tap and a paper flick.
    return mix(0.15, (0, k.wood(0.08, 1400, 0.012, 0.8), 1.0), (0, k.burst(0.03, 2500, 8000, 0.006), 0.4)), "ui", 0.06


def dash(k):
    # A charge: pounding strides speeding up over rattling gravel.
    out = np.zeros(k.n(0.7))
    at = 0.0
    gap = 0.13
    while at < 0.5:
        place(out, k.n(at), layer(k.thump(0.14, 100, 45, 0.04), k.burst(0.06, 100, 1500, 0.015) * 0.6))
        at += gap
        gap *= 0.85
    return out + k.grit(0.7, 400, 3000, 300, 0.4) * k.swell(0.7, 0.6) * 0.5, "hit", 0.1


def crash(k):
    # Slamming into a wall or a body: a boom, a crunch, then debris.
    return mix(1.0, (0, k.thump(0.5, 90, 35, 0.14), 1.4), (0, k.burst(0.25, 100, 4000, 0.05), 1.0),
               (0, k.wood(0.3, 210, 0.08, 0.4), 1.0), (0.03, k.debris(0.7, 12), 0.8)), "big", 0.16


def push(k):
    # A shove and boots scraping back over stone.
    return mix(0.45, (0, k.thump(0.14, 120, 60, 0.04), 1.0),
               (0.02, k.grit(0.36, 400, 2500, 700, 0.14), 0.7)), "hit", 0.1


def chalk(k):
    # Chalk scratching a stroke on the floor.
    return k.grit(0.16, 2000, 7000, 2500, 0.08) * k.swell(0.16, 0.2), "step", 0.06


def circle_cast(k):
    # The circle closes: air rushes in, a deep boom, then a D-minor shimmer.
    shimmer = sum(k.glass(n, 1.4, 0.5) for n in ("D5", "F5", "A5", "D6"))
    return mix(1.9, (0, k.whoosh(0.5, 200, 800, 900, 5000, 0.95), 0.9),
               (0.48, k.thump(0.7, 80, 30, 0.2), 1.4), (0.48, k.burst(0.5, 100, 2500, 0.1), 0.8),
               (0.5, shimmer, 0.5)), "big", 0.3


def throw(k):
    # A javelin thrown: a short whoosh dropping in pitch as it passes.
    return k.whoosh(0.3, 1500, 5000, 600, 2200, 0.3), "hit", 0.1


def arrow(k):
    # A bowstring's twang and the arrow's hiss.
    twang = k.modal(0.3, [(hz("D3"), 0.07, 1.0), (hz("D3") * 2, 0.05, 0.5), (hz("D3") * 3, 0.03, 0.3)])
    return mix(0.4, (0, twang, 0.7), (0.02, k.whoosh(0.2, 3000, 9000, 1500, 5000, 0.2), 0.8)), "hit", 0.1


def block(k):
    # A shield takes the blow: a bright iron clang.
    return mix(0.8, (0, k.iron(0.7, 520, 0.28), 1.0), (0, k.thump(0.1, 160, 80, 0.03), 0.6),
               (0, k.burst(0.03, 1500, 8000, 0.006), 0.6)), "hit", 0.14


def ambush(k):
    # Out of the shadows: a quick hiss, then the stab.
    stab, _, _ = hit(k)
    return mix(0.5, (0, k.whoosh(0.18, 1000, 4000, 2000, 8000, 0.8), 0.8), (0.16, stab, 1.0)), "hit", 0.12


def combo(k):
    # Two down in one move: a quick rising chime, D F A.
    return mix(1.1, (0, k.glass("D6", 0.7), 0.7), (0.07, k.glass("F6", 0.7), 0.7), (0.14, k.glass("A6", 0.9), 0.8)), "ui", 0.3


def swap(k):
    # Trading places: two gusts of air meeting, and a soft pop.
    return mix(0.5, (0, k.whoosh(0.22, 400, 1200, 1500, 5000, 0.9), 0.8),
               (0.2, k.burst(0.04, 300, 3000, 0.01), 0.7), (0.2, k.thump(0.08, 180, 90, 0.02), 0.6)), "hit", 0.14


def quake(k):
    # The hammer hits the ground: a deep boom, a rumble, stones jumping.
    rumble = k.band(k.noise(0.9), 30, 220) * k.decay(0.9, 0.3)
    return mix(1.1, (0, k.thump(0.7, 70, 28, 0.22), 1.5), (0, rumble, 1.2),
               (0, k.burst(0.12, 200, 3000, 0.03), 0.8), (0.05, k.debris(0.8, 14, 400, 3000), 0.7)), "big", 0.16


def scan(k):
    # The analyst reads your weapon: a clockwork ratchet winding up.
    out = np.zeros(k.n(0.5))
    for i in range(8):
        place(out, k.n(i * 0.045), k.wood(0.04, 1800 + i * 120, 0.008, 0.6))
    return out, "step", 0.1


def axe(k):
    # A spinning axe: the air chopped at every turn.
    d = 0.5
    spin = 0.5 + 0.5 * np.sin(2 * np.pi * 14 * k.t(d)) ** 2
    return k.whoosh(d, 400, 2000, 700, 3500, 0.5) * spin, "hit", 0.1


def bolt(k):
    # A lightning strike: a sharp crack, crackle, and a roll of thunder.
    crack = k.burst(0.03, 500, 11000, 0.008)
    crackle = k.grit(0.35, 1500, 9000, 500, 0.12)
    thunder = k.band(k.noise(1.0), 30, 300) * k.swell(1.0, 0.15, 1, 2)
    return mix(1.1, (0, crack, 1.4), (0, crackle, 0.8), (0.05, thunder, 1.2)), "big", 0.18


def cannon(k):
    # A cannon shot: a boom and a blast of smoke.
    return mix(0.8, (0, k.thump(0.5, 110, 35, 0.12), 1.4), (0, k.burst(0.5, 60, 1500, 0.1), 1.0),
               (0, k.burst(0.03, 1500, 9000, 0.006), 0.6)), "big", 0.14


def blast(k):
    # An explosion rolling out.
    body = k.band(k.noise(1.1), 30, 900) * k.decay(1.1, 0.3)
    return mix(1.2, (0, k.thump(0.6, 90, 30, 0.18), 1.4), (0, body, 1.3),
               (0, k.burst(0.05, 1000, 8000, 0.01), 0.6), (0.1, k.debris(0.8, 10), 0.4)), "big", 0.16


def firework(k):
    # A rocket whistles up and bursts into crackling sparks.
    d = 0.45
    whistle = k.tone(k.glide(900, 2600, d), d) * k.swell(d, 0.8) * 0.3 + k.whoosh(d, 800, 3000, 2000, 8000, 0.8) * 0.5
    return mix(1.4, (0, whistle, 1.0), (d, k.thump(0.3, 140, 50, 0.07), 1.0),
               (d, k.burst(0.1, 300, 6000, 0.03), 0.8), (d + 0.05, k.grit(0.8, 3000, 10000, 120, 0.35), 0.9)), "big", 0.2


def zap(k):
    # Electricity arcing: a buzz and crackles.
    d = 0.28
    buzz = k.band(k.tone(120, d, "saw"), 200, 5000) * k.decay(d, 0.1) * 0.5
    return buzz + k.grit(d, 1500, 9000, 1200, 0.1), "hit", 0.08


def discharge(k):
    # A capacitor dumping its charge: a big arc and a thump.
    z, _, _ = zap(k)
    return mix(0.8, (0, k.whoosh(0.2, 200, 1500, 2000, 9000, 0.9), 0.6), (0.18, z * 1.3, 1.0),
               (0.18, k.thump(0.4, 120, 40, 0.1), 1.2), (0.18, k.grit(0.5, 1000, 9000, 600, 0.2), 0.7)), "big", 0.14


def resonate(k):
    # A shot passing through a cannon: the barrel rings, tuned to A.
    return k.modal(0.8, [(hz("A4"), 0.35, 1.0), (hz("A4") * 2.4, 0.15, 0.4), (hz("A4") * 4.1, 0.07, 0.2)]), "step", 0.2


def burn(k):
    # Fire catching: a whoosh of flame and crackling.
    return mix(0.8, (0, k.band(k.noise(0.6), 150, 2500) * k.swell(0.6, 0.2), 0.8),
               (0, k.grit(0.7, 1500, 8000, 250, 0.3), 0.8)), "hit", 0.12


def roar(k):
    # A beast's roar: a rough, throaty growl rising and falling.
    d = 1.1
    growl = 0.6 + 0.4 * np.sin(2 * np.pi * 28 * k.t(d)) * k.rng.uniform(0.8, 1.0, k.n(d))
    voice = k.sweep(k.noise(d), k.glide(250, 180, d), k.glide(1100, 800, d)) * growl
    pitch = k.band(k.tone(k.glide(95, 75, d), d, "saw"), 60, 1200) * 0.35
    return (voice + pitch) * k.swell(d, 0.25, 1.5, 1.2), "big", 0.2


def smash(k):
    # Something heavy smashed to pieces.
    return mix(1.0, (0, k.stone(0.4, 0.12), 1.3), (0, k.wood(0.3, 180, 0.07), 0.6),
               (0.02, k.debris(0.8, 16, 300, 3500), 1.0)), "big", 0.16


def siege_warn(k):
    # The siege tightens: a low war horn on D.
    d = 0.9
    horn = k.band(k.tone(hz("D3"), d, "saw") + k.tone(hz("A3"), d, "saw") * 0.4, 80, 1400)
    return horn * k.swell(d, 0.3, 1.2, 1.2) * 0.8 + k.burst(d, 300, 2000, 0.4) * 0.05, "hit", 0.25


def plant(k):
    # A mine pushed into the dirt: a scuff and a small metal click.
    return mix(0.3, (0, k.grit(0.12, 300, 2500, 900, 0.05), 0.7), (0.08, k.iron(0.12, 2600, 0.03, 0.5), 1.0)), "step", 0.08


def summon(k):
    # A fairy appears: a breath of air and a glass-chime run (D minor pentatonic).
    notes = ("A5", "C6", "D6", "F6", "A6")
    return mix(1.3, (0, k.whoosh(0.35, 1000, 3000, 3000, 9000, 0.6), 0.5),
               *((0.04 + i * 0.045, k.glass(n, 0.9, 0.6), 1.0) for i, n in enumerate(notes))), "hit", 0.3


def shadow(k):
    # A shadow stitched to the floor: a dark reversed hiss and a low hum.
    d = 0.5
    hiss = k.band(k.noise(d), 300, 3000) * k.swell(d, 0.85, 3, 1)
    return hiss * 0.8 + k.tone(hz("D2"), d) * k.swell(d, 0.7) * 0.4, "hit", 0.18


def wall_rise(k):
    # A wall grinding up out of the floor.
    d = 0.55
    grind = k.grit(d, 80, 900, 1500, 1.0) * k.swell(d, 0.7)
    return mix(0.8, (0, grind, 1.0), (d - 0.05, k.stone(0.3, 0.08), 1.0)), "hit", 0.14


def clank(k):
    # Heavy iron set down.
    return mix(0.6, (0, k.iron(0.5, 330, 0.2), 1.0), (0, k.thump(0.15, 130, 60, 0.04), 0.9)), "hit", 0.12


def glutton_windup(k):
    # The glutton winds up: a deep, rumbling growl of hunger.
    d = 0.7
    rumble = k.band(k.noise(d), 60, 500) * (0.6 + 0.4 * np.sin(2 * np.pi * 11 * k.t(d)))
    return (rumble + k.band(k.tone(k.glide(70, 110, d), d, "saw"), 50, 700) * 0.4) * k.swell(d, 0.85), "hit", 0.12


def glutton_bite(k):
    # A big wet chomp: teeth snap, a crunch, a swallow.
    snap = layer(k.burst(0.02, 2000, 9000, 0.004), k.wood(0.05, 1200, 0.01, 0.6))
    return mix(0.7, (0, snap, 1.2), (0.01, k.thump(0.12, 160, 70, 0.03), 0.8),
               (0.02, k.grit(0.25, 300, 2500, 1300, 0.08), 0.9),
               (0.3, k.tone(k.glide(280, 110, 0.2), 0.2) * k.decay(0.2, 0.06), 0.6)), "hit", 0.12


def glutton_gulp(k):
    # Swallowing the hero whole: a huge chomp and a long, deep gulp.
    bite, _, _ = glutton_bite(k)
    gulp = k.tone(k.glide(320, 70, 0.4, 0.7), 0.4) * k.decay(0.4, 0.15) + k.band(k.noise(0.4), 100, 900) * k.decay(0.4, 0.1) * 0.5
    return mix(1.0, (0, bite, 1.2), (0.3, gulp, 1.0), (0.32, k.thump(0.3, 90, 40, 0.1), 1.0)), "big", 0.14


def abyss_crack(k):
    # The floor splits: cracks racing out, a rumble opening below.
    out = np.zeros(k.n(1.4))
    at = 0.0
    gap = 0.12
    while at < 0.8:
        place(out, k.n(at), layer(k.burst(0.05, 900, 6000, 0.01) * k.rng.uniform(0.5, 1.0), k.stone(0.08, 0.02) * 0.4))
        at += gap
        gap = max(0.03, gap * 0.8)
    rumble = k.band(k.noise(1.4), 30, 250) * k.swell(1.4, 0.55, 1.5, 1.5)
    return out + rumble * 1.2 + mix(1.4, (0.8, k.debris(0.6, 14, 200, 2500), 0.7)), "big", 0.2


def abyss_fall(k):
    # Falling into the pit: a descending rush, then a distant thud far below.
    d = 0.6
    fall = k.whoosh(d, 800, 4000, 150, 900, 0.2)
    return mix(1.1, (0, fall, 1.0), (d + 0.1, k.thump(0.3, 70, 35, 0.08), 0.5)), "hit", 0.28


def gravity_pull(k):
    # Gravity draws them in: air sucked inward and a low hum rising.
    d = 0.55
    suck = k.sweep(k.noise(d), k.glide(1500, 150, d), k.glide(6000, 900, d)) * k.swell(d, 0.9, 2, 1)
    hum = k.tone(k.glide(hz("D2"), hz("A2"), d), d) * k.swell(d, 0.9) * 0.5
    return mix(0.7, (0, suck, 1.0), (0, hum, 1.0), (d - 0.03, k.thump(0.12, 120, 60, 0.03), 0.8)), "hit", 0.18


def gravity_push(k):
    # Gravity flings them away: a thump and a gust bursting outward.
    return mix(0.6, (0, k.thump(0.25, 90, 40, 0.07), 1.3),
               (0, k.whoosh(0.4, 200, 1200, 1500, 7000, 0.08), 1.0)), "hit", 0.18


def _howl(k, d, notes, vol=1.0):
    f = np.interp(np.linspace(0, 1, k.n(d)), np.linspace(0, 1, len(notes)), notes)
    f = f * (1 + 0.012 * np.sin(2 * np.pi * 5.5 * k.t(d)))
    voice = k.tone(f, d, harmonics=[(1, 1.0), (2, 0.35), (3, 0.12)])
    breath = k.band(k.noise(d), 800, 4000) * 0.12
    return (voice + breath) * k.swell(d, 0.3, 1.5, 1.2) * vol


def wolf_howl(k):
    # The lone wolf's howl, rising to A and settling on D.
    return _howl(k, 1.3, [hz("D4"), hz("A4"), hz("A4") * 1.02, hz("F4"), hz("D4")]), "hit", 0.35


def wolf_bite(k):
    # A snarl and a snap of jaws.
    d = 0.25
    snarl = k.band(k.noise(d), 200, 1500) * (0.5 + 0.5 * np.sin(2 * np.pi * 35 * k.t(d))) * k.swell(d, 0.5)
    snap = layer(k.burst(0.02, 2000, 9000, 0.004), k.wood(0.04, 1500, 0.008, 0.5))
    return mix(0.45, (0, snarl, 0.8), (0.2, snap, 1.2), (0.21, k.thump(0.1, 150, 70, 0.03), 0.7)), "hit", 0.12


def wolf_sulk(k):
    # A sulky little whine: "hmph".
    return _howl(k, 0.45, [hz("A5"), hz("F5"), hz("D5")], 0.7) + k.band(k.noise(0.45), 400, 2000) * k.decay(0.45, 0.1) * 0.1, "step", 0.15


# --- The Prison King -------------------------------------------------------

def king_revive(k):
    # A soldier dragged back: chains haul, a cell door creaks open, a low toll.
    creak = k.band(k.tone(k.glide(140, 220, 0.5), 0.5, "saw"), 300, 2500) * (0.5 + 0.5 * k.rng.random(k.n(0.5)) ** 4) * k.swell(0.5, 0.6)
    toll = k.modal(1.4, [(hz("C3"), 0.6, 1.0), (hz("C3") * 2.76, 0.25, 0.4), (hz("C2"), 0.9, 0.6)])
    return mix(1.6, (0, k.chain(0.5, 8), 1.0), (0.2, creak, 0.5), (0.55, k.iron(0.4, 260, 0.2), 0.9),
               (0.55, toll, 0.5)), "boss", 0.3


def fortress_spawn(k):
    # The fortress gate bangs open and a soldier marches out.
    return mix(1.0, (0, k.iron(0.6, 190, 0.25), 1.0), (0, k.thump(0.3, 100, 40, 0.08), 1.2),
               (0.05, k.chain(0.3, 5), 0.6), (0.35, enemy_step(k)[0], 0.6)), "boss", 0.24


def king_hit(k):
    # Striking the king: a deep, gong-like iron boom.
    return mix(1.2, (0, k.iron(1.1, 150, 0.6), 1.2), (0, k.thump(0.3, 120, 45, 0.08), 1.2),
               (0, k.burst(0.05, 800, 8000, 0.01), 0.6)), "boss", 0.24


def fortress_crack(k):
    # The fortress cracks: splitting stone and falling chips.
    return mix(0.8, (0, k.burst(0.04, 700, 6000, 0.01), 1.2), (0.02, k.stone(0.3, 0.08), 1.0),
               (0.05, k.debris(0.6, 12, 400, 3500), 0.9)), "boss", 0.2


def fortress_collapse(k):
    # The fortress falls: iron bars twist, stone crashes, dust settles.
    d = 1.8
    rumble = k.band(k.noise(d), 30, 400) * k.decay(d, 0.5)
    return mix(d, (0, k.thump(0.8, 80, 28, 0.25), 1.5), (0, rumble, 1.3), (0, k.iron(1.0, 240, 0.4), 0.7),
               (0.1, k.debris(1.4, 26, 200, 3000), 1.0), (0.4, k.chain(0.5, 6), 0.5)), "boss", 0.28


def king_collapse(k):
    # The king crumbles: iron plates buckle one by one, chains fall, a last boom.
    d = 2.6
    out = np.zeros(k.n(d))
    for i, (at, base) in enumerate(((0.0, 220), (0.35, 180), (0.65, 150), (0.9, 120))):
        place(out, k.n(at), k.iron(1.0, base, 0.4) * (0.7 + 0.1 * i))
        place(out, k.n(at), k.thump(0.3, 110, 45, 0.08))
    rumble = k.band(k.noise(d), 30, 300) * k.swell(d, 0.45, 1.5, 1.5)
    return (out + rumble + mix(d, (0.5, k.chain(0.8, 12), 0.8), (1.3, k.thump(0.9, 70, 25, 0.3), 1.6),
                               (1.3, k.debris(1.2, 20, 200, 2500), 0.8))), "boss", 0.35


EFFECTS = [step, enemy_step, slash, hit, enemy_die, player_hurt, turn_player, turn_enemy, denied,
           select, dash, crash, push, chalk, circle_cast, throw, arrow, block, ambush, combo, swap,
           quake, scan, axe, bolt, cannon, blast, firework, zap, discharge, resonate, burn, roar,
           smash, siege_warn, plant, summon, shadow, wall_rise, clank, glutton_windup, glutton_bite,
           glutton_gulp, abyss_crack, abyss_fall, gravity_pull, gravity_push, wolf_howl, wolf_bite,
           wolf_sulk, king_revive, fortress_spawn, king_hit, fortress_crack, fortress_collapse,
           king_collapse]


def main():
    import soundfile
    os.makedirs(OUT_DIR, exist_ok=True)
    only = sys.argv[1:]
    for i, render in enumerate(EFFECTS):
        name = render.__name__
        if only and name not in only:
            continue
        samples, level, room = render(Kit(1000 + i))
        data = finish(samples, level, room)
        path = os.path.join(OUT_DIR, name + ".ogg")
        soundfile.write(path, data, SR, format="OGG", subtype="VORBIS")
        print(f"{name}: {len(data) / SR:.2f}s")


if __name__ == "__main__":
    main()
