#!/usr/bin/env python3
"""Render ALAKAZAR's sound effects to Ogg Vorbis files.

The game keeps sound effects to a minimum: footsteps, and the Prison King's
fight (his revivals, the fortresses, his hits and his fall). Everything else
is left to the music.

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
    python3 tools/generate_sfx.py king_hit step   # only these

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
    # Soldiers' heavy boots on stone: a low, dull thud, no metal (it plays every
    # time the enemies move, so it stays soft and out of the way).
    return mix(0.3, (0, k.thump(0.16, 85, 42, 0.05), 1.0), (0, k.burst(0.08, 80, 700, 0.02), 0.6),
               (0.015, k.grit(0.08, 300, 1200, 300, 0.02), 0.15)), "step", 0.08


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


## Cannon chain links: a short 8-bit "pi-kon" (a quick blip a fourth below, then the
## note), one semitone higher for every link, chain_01 (D5) to chain_20 (A6).
CHAIN_LINKS = 20


def chain_link(k, link):
    root = 74 + (link - 1)

    def pulse(midi_note, d, tau, chirp):
        f = 440.0 * 2 ** ((midi_note - 69) / 12)
        t = k.t(d)
        freq = f * (chirp + (1 - chirp) * np.clip(t / 0.03, 0, 1))
        phase = 2 * np.pi * np.cumsum(freq) / SR
        wave = np.sign(np.sin(phase)) * 0.6
        # A soft low-pass (a few harmonics only), so it never gets shrill.
        a = np.exp(-2 * np.pi * f * 3.0 / SR)
        out = np.zeros_like(wave)
        acc = 0.0
        for i, v in enumerate(wave):
            acc = (1 - a) * v + a * acc
            out[i] = acc
        return out * k.decay(d, tau, attack=0.004)

    pi = pulse(root - 5, 0.05, 0.025, 0.97)
    kon = pulse(root, 0.22, 0.08, 0.985)
    buf = np.zeros(int(SR * 0.27))
    place(buf, 0, pi)
    place(buf, int(0.045 * SR), kon)
    return buf, "hit", 0.05


EFFECTS = [step, enemy_step, king_revive, fortress_spawn, king_hit, fortress_crack, fortress_collapse, king_collapse]


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
    for link in range(1, CHAIN_LINKS + 1):
        name = "chain_%02d" % link
        if only and name not in only and "chain" not in only:
            continue
        samples, level, room = chain_link(Kit(2000 + link), link)
        data = finish(samples, level, room)
        soundfile.write(os.path.join(OUT_DIR, name + ".ogg"), data, SR, format="OGG", subtype="VORBIS")
    if not only or "chain" in only:
        print("chain_01..chain_%02d" % CHAIN_LINKS)


if __name__ == "__main__":
    main()
