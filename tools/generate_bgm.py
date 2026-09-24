#!/usr/bin/env python3
"""Render ALAKAZAR's cyber BGM to WAV files (standard library only).

One shared sound palette keeps every track unified: filtered saw bass rolling
on the off-16ths, a detuned saw pad, a pulse pluck arpeggio with a dotted-eighth
echo, a restrained saw lead, and a four-on-the-floor kick that side-chains the
music so the whole mix "pumps". Everything is low-passed and mixed quietly so
it sits under the game instead of competing with it. Output is deterministic,
so re-running the script reproduces the files byte for byte.

    python3 tools/generate_bgm.py

Writes into assets/audio/bgm/:
    battle_loop.wav  D minor, 132 BPM, 16 bars. Bars 1-8 build (filter opens,
                     riser), bars 9-16 pay off with the hook, then it drops
                     back to the groove. Rendered circularly so echoes and pad
                     tails wrap into the start; a `smpl` chunk marks the loop so
                     Godot's "Detect From WAV" import loops it seamlessly.
    victory.wav      rising arp that resolves D minor -> D major
    defeat.wav       the battle pad powering down (tape-stop and filter close)
"""

import math
import os
import random
import struct
import wave

RATE = 32000
BPM = 132
TARGET_RMS = 0.2  # shared loudness so tracks feel like one soundtrack
STEP = 60.0 / BPM / 4  # one sixteenth note in seconds
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "bgm")

NOTE_INDEX = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5,
              "F#": 6, "Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10,
              "Bb": 10, "B": 11}


def midi(name):
    return 12 * (int(name[-1]) + 1) + NOTE_INDEX[name[:-1]]


def hz(note):
    """'A4' -> 440.0; also accepts a MIDI number."""
    m = note if isinstance(note, (int, float)) else midi(note)
    return 440.0 * 2 ** ((m - 69) / 12)


def lp_coef(fc):
    w = 2 * math.pi * min(fc, RATE * 0.45) / RATE
    return w / (1 + w)


# ---------------------------------------------------------------------------
# Voices: each returns a list of samples starting at the note-on.
# ---------------------------------------------------------------------------

def synth(note, seconds, wave_="saw", detune=(0.0,), vol=0.3,
          attack=0.004, decay=0.15, sustain=0.6, release=0.05,
          cutoff=(3000, 1200, 0.1), pitch=None, glide_from=None, duty=0.5):
    """Subtractive voice: oscillator(s) -> 2-pole low-pass -> ADSR.

    cutoff = (start_hz, sustain_hz, decay_seconds) of the filter envelope.
    pitch  = optional callable t -> frequency multiplier (for tape-stops).
    """
    n = int((seconds + release) * RATE)
    gate = seconds
    base = hz(note)
    start_f = hz(glide_from) if glide_from else base
    ratios = [2 ** (c / 1200) for c in detune]
    phases = [(i * 0.37) % 1.0 for i in range(len(ratios))]
    f_start, f_sus, f_decay = cutoff
    y1 = y2 = 0.0
    out = [0.0] * n
    norm = 1.0 / len(ratios)
    for i in range(n):
        t = i / RATE
        f = base if t > 0.04 or not glide_from else start_f + (base - start_f) * t / 0.04
        if pitch:
            f *= pitch(t)
        s = 0.0
        for k, r in enumerate(ratios):
            p = (phases[k] + f * r / RATE) % 1.0
            phases[k] = p
            if wave_ == "saw":
                s += 2.0 * p - 1.0
            elif wave_ == "pulse":
                s += (1.0 if p < duty else 0.0) - duty
            elif wave_ == "tri":
                s += 1.0 - 4.0 * abs(p - 0.5)
            else:
                s += math.sin(2 * math.pi * p)
        s *= norm
        a = lp_coef(f_sus + (f_start - f_sus) * math.exp(-t / f_decay))
        y1 += a * (s - y1)
        y2 += a * (y1 - y2)
        if t < attack:
            env = t / attack
        elif t < gate:
            env = sustain + (1 - sustain) * math.exp(-(t - attack) / decay)
        else:
            held = sustain + (1 - sustain) * math.exp(-(gate - attack) / decay)
            env = held * max(0.0, 1 - (t - gate) / release)
        out[i] = y2 * env * vol
    return out


def kick(vol=0.9):
    n = int(0.28 * RATE)
    out = [0.0] * n
    phase = 0.0
    for i in range(n):
        t = i / RATE
        f = 45 + 110 * math.exp(-t * 32)
        phase += f / RATE
        env = math.exp(-t * 11) * min(1.0, i / 16)
        out[i] = math.sin(2 * math.pi * phase) * env * vol
    return out


def noise_hit(rng, seconds, lo, hi, vol, bursts=1):
    """Band-limited noise: (low-pass at hi) minus (low-pass at lo)."""
    n = int(seconds * RATE)
    a_hi, a_lo = lp_coef(hi), lp_coef(lo)
    h = l = 0.0
    out = [0.0] * n
    burst_len = 0.011 * RATE
    for i in range(n):
        x = rng.uniform(-1, 1)
        h += a_hi * (x - h)
        l += a_lo * (x - l)
        if bursts > 1 and i < burst_len * bursts:
            env = 1 - (i % burst_len) / burst_len * 0.7
        else:
            env = (1 - i / n) ** 3
        out[i] = (h - l) * env * vol * min(1.0, i / 12)
    return out


def riser(rng, seconds, vol=0.12):
    n = int(seconds * RATE)
    out = [0.0] * n
    y = 0.0
    for i in range(n):
        k = i / n
        y += lp_coef(300 + 7000 * k * k) * (rng.uniform(-1, 1) - y)
        out[i] = y * vol * k * k
    return out


# ---------------------------------------------------------------------------
# Mixing
# ---------------------------------------------------------------------------

class Mix:
    """Named buses in one timeline. wrap=True renders circularly for loops."""

    def __init__(self, seconds, wrap):
        self.n = int(round(seconds * RATE))
        self.wrap = wrap
        self.buses = {}

    def bus(self, name):
        return self.buses.setdefault(name, [0.0] * self.n)

    def put(self, name, at_seconds, samples):
        buf, n = self.bus(name), self.n
        start = int(round(at_seconds * RATE))
        for i, s in enumerate(samples):
            j = start + i
            if j >= n:
                if not self.wrap:
                    break
                j %= n
            buf[j] += s

    def echo(self, name, delay, feedback, mix):
        """Feedback delay; a loop is run twice around so tails wrap in."""
        buf, n = self.bus(name), self.n
        d = int(delay * RATE)
        passes = 2 if self.wrap else 1
        wet = [0.0] * n
        for _ in range(passes):
            for i in range(n):
                j = i - d
                if j < 0 and not self.wrap:
                    continue
                j %= n
                wet[i] = buf[j] + feedback * wet[j]
        for i in range(n):
            buf[i] += wet[i] * mix

    def duck(self, name, kick_times, depth, length=0.2):
        """Side-chain pump: dip the bus right after every kick."""
        buf, n = self.bus(name), self.n
        gain = [1.0] * n
        for kt in kick_times:
            start = int(round(kt * RATE))
            for i in range(int(length * RATE)):
                j = start + i
                if j >= n:
                    if not self.wrap:
                        break
                    j %= n
                g = 1 - depth * (1 - i / (length * RATE)) ** 2
                gain[j] = min(gain[j], g)
        for i in range(n):
            buf[i] *= gain[i]

    def write(self, path, peak=0.85, loop=False):
        total = [sum(b[i] for b in self.buses.values()) for i in range(self.n)]
        total = [math.tanh(s * 1.1) for s in total]  # gentle glue
        # Match loudness across tracks (RMS), never exceeding the peak ceiling.
        top = max(abs(s) for s in total) or 1.0
        rms = math.sqrt(sum(s * s for s in total) / self.n) or 1.0
        scale = min(peak / top, TARGET_RMS / rms)
        frames = b"".join(struct.pack("<h", int(s * scale * 32767)) for s in total)
        with wave.open(path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(frames)
        if loop:
            append_loop_chunk(path, self.n)


def append_loop_chunk(path, frames):
    """Append a RIFF `smpl` chunk with one forward loop over the whole file."""
    loop = struct.pack("<6I", 0, 0, 0, frames - 1, 0, 0)
    body = struct.pack("<9I", 0, 0, int(1e9 / RATE), 60, 0, 0, 0, 1, 0) + loop
    with open(path, "r+b") as f:
        f.seek(0, os.SEEK_END)
        f.write(b"smpl" + struct.pack("<I", len(body)) + body)
        size = f.tell()
        f.seek(4)
        f.write(struct.pack("<I", size - 8))


# ---------------------------------------------------------------------------
# Shared palette (used by every track so they sound like one soundtrack)
# ---------------------------------------------------------------------------

def bass_note(note, steps=1, vol=0.5):
    return synth(note, steps * STEP * 0.8, "saw", detune=(-6, 6), vol=vol,
                 attack=0.003, decay=0.08, sustain=0.5, release=0.02,
                 cutoff=(1400, 260, 0.05))


def pad_chord(notes, seconds, cutoff=1000, vol=0.1, pitch=None, close=None):
    cut = (cutoff, close if close else cutoff, 1.2 if close else 1.0)
    voices = [synth(nt, seconds, "saw", detune=(-11, 0, 9), vol=vol, attack=0.08,
                    decay=0.6, sustain=0.8, release=0.25, cutoff=cut, pitch=pitch)
              for nt in notes]
    return [sum(v) for v in zip(*voices)]


def pluck(note, cutoff, vol=0.13):
    return synth(note, STEP * 0.6, "pulse", duty=0.3, vol=vol, attack=0.002,
                 decay=0.07, sustain=0.15, release=0.03,
                 cutoff=(cutoff, cutoff * 0.35, 0.05))


def lead(note, steps, glide_from=None, vol=0.16):
    return synth(note, steps * STEP * 0.9, "saw", detune=(-7, 7), vol=vol,
                 attack=0.01, decay=0.25, sustain=0.7, release=0.08,
                 cutoff=(2600, 1500, 0.2), glide_from=glide_from)


# ---------------------------------------------------------------------------
# Battle loop
# ---------------------------------------------------------------------------

# One chord per bar, four-bar cycle: i - VI - iv - V (A major pulls back home).
CHORDS = [
    {"bass": "D2", "pad": ["D3", "F3", "A3", "D4"], "arp": ["D4", "F4", "A4", "D5"]},
    {"bass": "A#1", "pad": ["A#2", "D3", "F3", "A#3"], "arp": ["A#3", "D4", "F4", "A#4"]},
    {"bass": "G1", "pad": ["G2", "A#2", "D3", "G3"], "arp": ["G3", "A#3", "D4", "G4"]},
    {"bass": "A1", "pad": ["A2", "C#3", "E3", "A3"], "arp": ["A3", "C#4", "E4", "A4"]},
]
ARP_ORDER = [0, 2, 1, 3, 2, 1, 3, 2]

# Hook: (step, length, note) per bar. Sparse and syncopated so it hooks
# without shouting; the second pass lifts the ending.
HOOK = [
    [(0, 2, "A4"), (3, 2, "D5"), (6, 2, "F5"), (8, 4, "E5"), (12, 2, "D5"), (14, 2, "C5")],
    [(0, 2, "D5"), (3, 2, "F5"), (6, 2, "A5"), (8, 6, "G5")],
    [(0, 2, "G5"), (3, 2, "F5"), (6, 2, "D5"), (8, 4, "A#4"), (12, 2, "C5"), (14, 2, "D5")],
    [(0, 3, "E5"), (3, 3, "C#5"), (6, 2, "A4"), (8, 4, "E5"), (12, 4, "C#5")],
]
HOOK_LIFT = [(0, 2, "E5"), (2, 2, "F5"), (4, 2, "G5"), (6, 2, "A5"), (8, 6, "A5")]

# Climax: the hook's answer, higher and more driving, doubled a third below.
CLIMAX = [
    [(0, 3, "A5"), (3, 3, "F5"), (6, 2, "D5"), (8, 2, "E5"), (10, 2, "F5"), (12, 4, "A5")],
    [(0, 3, "A#5"), (3, 3, "A5"), (6, 2, "F5"), (8, 2, "D5"), (10, 2, "F5"), (12, 4, "A5")],
    [(0, 3, "G5"), (3, 3, "A#5"), (6, 2, "D6"), (8, 4, "C6"), (12, 2, "A#5"), (14, 2, "A5")],
    [(0, 3, "E5"), (3, 3, "A5"), (6, 2, "C#6"), (8, 8, "E6")],
]
# D natural minor; the harmony over the A chord uses its own tones instead.
SCALE_PCS = [2, 4, 5, 7, 9, 10, 0]
A_MAJOR_PCS = [9, 1, 4]


def third_below(note, dominant):
    """Harmony note under the lead: a diatonic third below in D minor, or the
    next A-major chord tone below on the A bar (avoids F against C#)."""
    m = midi(note)
    if dominant:
        cand = m - 1
        while cand % 12 not in A_MAJOR_PCS:
            cand -= 1
        return cand
    below = [c for c in range(m - 1, m - 13, -1) if c % 12 in SCALE_PCS]
    return below[1]


# Mostly a low-key groove that stays out of the way; once per loop it builds,
# spikes with the hook, peaks in a twin-lead climax, then settles through an
# after-glow and a kick-less break.
# Per-section levels: kick, open hat, 16th ticks, clap, arp (vol, cutoff
# start, cutoff end), pad (vol, cutoff), bass vol, lead part.
SECTIONS = [
    # name      bars kick  hat   tick  clap  arp_v arp_c0 arp_c1 pad_v pad_c bass  lead
    ("calm",    8,   0.55, 0.12, 0.04, 0.0,  0.08, 900,   900,   0.08, 800,  0.40, None),
    ("groove",  4,   0.65, 0.16, 0.06, 0.25, 0.10, 1100,  1400,  0.09, 900,  0.45, None),
    ("build",   4,   0.80, 0.20, 0.08, 0.35, 0.12, 1500,  4000,  0.10, 1400, 0.50, None),
    ("peak",    4,   0.90, 0.22, 0.08, 0.45, 0.13, 4200,  4200,  0.11, 1600, 0.50, "hook"),
    ("climax",  4,   0.95, 0.24, 0.10, 0.50, 0.12, 5000,  5000,  0.12, 2000, 0.52, "climax"),
    ("glow",    4,   0.65, 0.16, 0.06, 0.25, 0.10, 2600,  1000,  0.09, 1100, 0.45, "tail"),
    ("break",   4,   0.0,  0.0,  0.04, 0.0,  0.07, 800,   800,   0.10, 700,  0.30, None),
]


def stab(notes, vol=0.05):
    """Short bright supersaw chord hit for the climax off-beats."""
    voices = [synth(nt, STEP * 0.7, "saw", detune=(-15, -5, 5, 15), vol=vol,
                    attack=0.002, decay=0.06, sustain=0.3, release=0.05,
                    cutoff=(4200, 1500, 0.06)) for nt in notes]
    return [sum(v) for v in zip(*voices)]


def battle_theme():
    bar_len = 16 * STEP
    plan = []
    for name, count, *levels in SECTIONS:
        for i in range(count):
            plan.append((name, i, count, levels))
    plan += [plan[0]] * 4  # four calm bars lead back into the loop start
    bars = len(plan)
    mix = Mix(bars * bar_len, wrap=True)
    rng = random.Random(4)
    kicks = []
    starts = {}

    for bar, (name, idx, count, levels) in enumerate(plan):
        k_vol, hat, tick, clap, arp_v, arp_c0, arp_c1, pad_v, pad_c, bass_v, part = levels
        chord = CHORDS[bar % 4]
        t0 = bar * bar_len
        arp_cut = arp_c0 + (arp_c1 - arp_c0) * (idx / max(1, count - 1))
        starts.setdefault(name, bar)
        climax = name == "climax"
        # One-beat drop-out right before the climax lands.
        stop_beat = 3 if name == "peak" and idx == count - 1 else -1

        for beat in range(4):
            bt = t0 + beat * 4 * STEP
            if beat == stop_beat:
                continue
            if k_vol:
                mix.put("kick", bt, kick(k_vol))
                kicks.append(bt)
            # Rolling off-16th bass; the kick owns the downbeat. The climax
            # bounces root-octave-root.
            for s in (1, 2, 3):
                note = midi(chord["bass"])
                if (climax and s == 2) or (part == "hook" and s == 3 and beat == 3):
                    note += 12
                mix.put("bass", bt + s * STEP, bass_note(note, vol=bass_v))
            if hat:
                mix.put("hat", bt + 2 * STEP, noise_hit(rng, 0.09, 6000, 12000, hat))
            for s in ((0, 1, 3) if climax else (1, 3)):
                mix.put("hat", bt + s * STEP, noise_hit(rng, 0.03, 7000, 13000, tick))
            if clap and beat in (1, 3):
                mix.put("clap", bt, noise_hit(rng, 0.18, 900, 3200, clap, bursts=3))
            if climax:
                mix.put("stab", bt + 2 * STEP, stab(chord["arp"][:3]))

        mix.put("pad", t0, pad_chord(chord["pad"], bar_len - 0.1, cutoff=pad_c, vol=pad_v))

        for s in range(16):
            if stop_beat >= 0 and s >= stop_beat * 4:
                break
            note = chord["arp"][ARP_ORDER[s % 8]]
            mix.put("arp", t0 + s * STEP, pluck(note, arp_cut, vol=arp_v))

        if part in ("hook", "climax"):
            if part == "climax":
                phrase = CLIMAX[idx]
            else:
                phrase = HOOK_LIFT if idx == count - 1 else HOOK[bar % 4]
            prev = None
            for step, length, note in phrase:
                mix.put("lead", t0 + step * STEP, lead(note, length, glide_from=prev))
                if part == "climax":
                    low = third_below(note, dominant=(bar % 4 == 3))
                    mix.put("lead", t0 + step * STEP, lead(low, length, vol=0.1))
                prev = note
        elif part == "tail" and idx == 0:
            # The climax resolves onto one long D and lets the echo carry it.
            mix.put("lead", t0, synth("D5", bar_len * 0.9, "saw", detune=(-7, 7), vol=0.14,
                                      attack=0.01, decay=0.8, sustain=0.35, release=0.6,
                                      cutoff=(2600, 700, 1.2), glide_from="E5"))

    peak, top = starts["peak"], starts["climax"]
    # Build-up tension into the spike.
    mix.put("fx", (peak - 2) * bar_len, riser(rng, 2 * bar_len))
    for s in range(8, 16):
        mix.put("clap", (peak - 1) * bar_len + s * STEP,
                noise_hit(rng, 0.08, 900, 3200, 0.12 + 0.03 * (s - 8)))
    mix.put("fx", peak * bar_len, noise_hit(rng, 1.6, 3000, 11000, 0.18))  # crash
    # Short swell through the drop-out, then a bigger crash on the climax.
    mix.put("fx", top * bar_len - 4 * STEP, riser(rng, 4 * STEP, vol=0.16))
    mix.put("fx", top * bar_len, noise_hit(rng, 2.2, 2500, 11000, 0.22))

    mix.echo("arp", STEP * 3, 0.35, 0.45)
    mix.echo("lead", STEP * 3, 0.38, 0.4)
    mix.echo("stab", STEP * 3, 0.25, 0.3)
    mix.duck("pad", kicks, 0.7)
    mix.duck("arp", kicks, 0.45)
    mix.duck("stab", kicks, 0.3)
    mix.duck("bass", kicks, 0.3, length=0.12)
    mix.duck("lead", kicks, 0.2)
    return mix


# ---------------------------------------------------------------------------
# Jingles (same instruments and key as the battle loop)
# ---------------------------------------------------------------------------

def victory_jingle():
    mix = Mix(4.8, wrap=False)
    rng = random.Random(9)
    for i, note in enumerate(["D4", "F4", "A4", "D5", "F#5", "A5"]):
        mix.put("arp", i * STEP, pluck(note, 2500 + 400 * i, vol=0.16))
    hit = 6 * STEP
    mix.put("kick", hit, kick())
    mix.put("clap", hit, noise_hit(rng, 0.2, 900, 3200, 0.4, bursts=3))
    mix.put("fx", hit, noise_hit(rng, 1.8, 3000, 11000, 0.16))
    mix.put("pad", hit, pad_chord(["D3", "F#3", "A3", "D4", "F#4"], 2.2, cutoff=2200, vol=0.09))
    mix.put("bass", hit, synth("D2", 1.6, "saw", detune=(-6, 6), vol=0.45, decay=0.3,
                               sustain=0.5, release=0.3, cutoff=(1600, 300, 0.1)))
    mix.put("lead", hit, lead("D6", 12, glide_from="A5", vol=0.14))
    for i, note in enumerate(["A5", "D6", "F#6", "A6", "F#6", "D6", "A5", "D6"]):
        mix.put("arp", hit + (4 + i) * STEP, pluck(note, 3500, vol=0.09))
    mix.echo("arp", STEP * 3, 0.35, 0.45)
    mix.echo("lead", STEP * 3, 0.3, 0.35)
    return mix


def defeat_jingle():
    mix = Mix(4.6, wrap=False)
    rng = random.Random(13)
    down = lambda t: max(0.25, 1.0 - 0.12 * max(0.0, t - 0.6) ** 1.6)  # tape-stop
    mix.put("pad", 0, pad_chord(["D3", "F3", "A3", "D4"], 3.4, cutoff=1400, vol=0.11,
                                pitch=down, close=180))
    mix.put("bass", 0, synth("D2", 3.4, "saw", detune=(-6, 6), vol=0.4, decay=1.2,
                             sustain=0.4, release=0.3, cutoff=(900, 150, 0.8), pitch=down))
    for i, note in enumerate(["A4", "F4", "D4", "A3"]):
        mix.put("arp", i * 4 * STEP, pluck(note, 1600 - 250 * i, vol=0.14))
    mix.put("kick", 0, kick(0.7))
    mix.put("fx", 0, noise_hit(rng, 1.4, 1500, 6000, 0.1))
    mix.echo("arp", STEP * 3, 0.4, 0.5)
    return mix


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    battle_theme().write(os.path.join(OUT_DIR, "battle_loop.wav"), loop=True)
    victory_jingle().write(os.path.join(OUT_DIR, "victory.wav"))
    defeat_jingle().write(os.path.join(OUT_DIR, "defeat.wav"))
    for name in sorted(os.listdir(OUT_DIR)):
        path = os.path.join(OUT_DIR, name)
        if name.endswith(".wav"):
            with wave.open(path) as w:
                print(f"{name}: {w.getnframes() / w.getframerate():.2f}s, {os.path.getsize(path) // 1024} KiB")


if __name__ == "__main__":
    main()
