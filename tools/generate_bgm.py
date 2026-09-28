#!/usr/bin/env python3
"""Render ALAKAZAR's cyber BGM to Ogg Vorbis files.

One shared sound palette keeps every track unified: filtered saw bass rolling
on the off-16ths, a detuned saw pad, a pulse pluck arpeggio with a dotted-eighth
echo, a restrained saw lead, and a four-on-the-floor kick that side-chains the
music so the whole mix "pumps". Everything is low-passed and mixed quietly so
it sits under the game instead of competing with it. Synthesis is standard
library only and deterministic; encoding needs `pip install soundfile`.

    python3 tools/generate_bgm.py

Writes into assets/audio/bgm/ (mono, 32 kHz, Vorbis ~74 kbps):
    battle_loop.ogg  D minor, 132 BPM, 36 bars. Mostly a low-key groove; once
                     per loop it builds, spikes with the hook, peaks in a
                     twin-lead climax, settles through an after-glow and a
                     kick-less break. Rendered circularly so echoes and pad
                     tails wrap into the start; Vorbis keeps the exact frame
                     count, so the loop stays seamless (`loop=true` in
                     battle_loop.ogg.import).
    victory.ogg      rising arp that resolves D minor -> D major
    defeat.ogg       the battle pad powering down (tape-stop and filter close)
    boss_loop.ogg    first boss: E minor, 140 BPM, 32 bars. A heavier march:
                     Phrygian F against E, octave-bouncing bass, a marching
                     hook, a twin-lead climax and a kick-less break.
    rotorick_error.ogg / rotorick_jackpot.ogg  the same loop, sample-for-sample
                     in time, for reel 5 (a broken, muffled, stuttering
                     machine) and reel 7 (gold bells, octave leads, heavier
                     kick); the game cross-fades between the three.
    rotorick_loop.ogg  Rotorick: A harmonic minor, 152 BPM in a triplet 12/8
                     swing. A mad cyber-circus that grabs from the first bar
                     and never lets up (oom-pah bass, chromatic lead, reel-spin
                     arpeggios); a darker "verdict" with a tolling bell keeps
                     the drive, then a jackpot climax.

    draft_loop.ogg   before setting out (weapon/fairy picks, rewards): an E Dorian
                     6/8 jig on a tin-whistle voice over a drone and bodhran,
                     with a cyber arp and, in the second passes, a soft kick.
    camp_loop.ogg    the camp: a D Mixolydian slow air in 3/4, harp arpeggios,
                     drone, a campfire crackle and a faint digital rain.
    king_loop.ogg    the Prison King (final boss): C Phrygian dominant, 120 BPM
                     half-time, 90 bars (3 minutes). Prison bells, chain rattles,
                     iron doors slamming, a throne-room organ and a crawling bass;
                     the king's motif, the battle hook remembered in C minor, a
                     twin-lead climax and a bells-and-heartbeat silence.
    king_rage.ogg    the same score in sync for the enraged king: double-time
                     drums, a siren, bells on every beat, distorted bass,
                     melodies an octave up.
    king_victory.ogg chains snap, the great bell tolls, the battle hook in D major.
    king_intro.ogg   under the blackout before the final battle: a cell door slams,
                     the organ swells, the great bell and the king's motif.
    king_rage_sting.ogg  the king enrages: chains snap, siren, a distorted roar, a
                     dissonant organ cluster and clashing bells.
    king_fall.ogg    the king falls: chains burst, a great hit, bells over C major.
    rotorick_intro.ogg  Rotorick arrives: reels spin and lock, a buzzer, a stab.
    (Sound effects are rendered by tools/generate_sfx.py.)

    python3 tools/generate_bgm.py boss_loop.ogg rotorick_loop.ogg  # only these
"""

import math
import os
import random

RATE = 32000
BPM = 132
TARGET_RMS = 0.2  # shared loudness so tracks feel like one soundtrack
STEP = 60.0 / BPM / 4  # one sixteenth note in seconds
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "bgm")
# libsndfile Vorbis setting: 0 = best quality, 1 = smallest. 0.5 (~74 kbps
# mono) is the smallest setting that keeps these synth tracks transparent.
COMPRESSION = 0.5
# The quiet acoustic-style tracks expose Vorbis artefacts, so they get more bits.
CLEAN_COMPRESSION = 0.2

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

    def write(self, path, peak=0.85):
        import numpy
        import soundfile

        total = [sum(b[i] for b in self.buses.values()) for i in range(self.n)]
        if getattr(self, "post", None):
            total = self.post(total)
        total = [math.tanh(s * 1.1) for s in total]  # gentle glue
        # Match loudness across tracks (RMS), never exceeding the peak ceiling.
        top = max(abs(s) for s in total) or 1.0
        rms = math.sqrt(sum(s * s for s in total) / self.n) or 1.0
        scale = min(peak / top, TARGET_RMS * getattr(self, "loudness", 1.0) / rms)
        data = numpy.array(total, dtype=numpy.float32) * scale
        # Written in blocks: one large Vorbis write crashes some libsndfile builds.
        with soundfile.SoundFile(path, "w", RATE, 1, format="OGG", subtype="VORBIS",
                                 compression_level=getattr(self, "compression", COMPRESSION)) as f:
            for i in range(0, len(data), 4096):
                f.write(data[i:i + 4096])


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


# ---------------------------------------------------------------------------
# Boss themes (same instruments; their own keys and tempos)
# ---------------------------------------------------------------------------

def with_tempo(bpm, render):
    """Run a renderer with STEP set for its tempo (the shared voices read STEP)."""
    global STEP
    saved = STEP
    STEP = 60.0 / bpm / 4
    try:
        return render()
    finally:
        STEP = saved


def lower_third(note, pcs):
    m = midi(note) if isinstance(note, str) else note
    below = [c for c in range(m - 1, m - 13, -1) if c % 12 in pcs]
    return below[1]


def bell(note, seconds, vol=0.1):
    """Cold metallic toll: a sine plus an inharmonic partial."""
    m = midi(note) if isinstance(note, str) else note
    body = synth(m, seconds, "sine", vol=vol, attack=0.002, decay=0.9, sustain=0.0,
                 release=0.4, cutoff=(6000, 3000, 0.5))
    ring = synth(m + 17.58, seconds, "sine", vol=vol * 0.45, attack=0.002, decay=0.35,
                 sustain=0.0, release=0.2, cutoff=(8000, 4000, 0.3))
    octave = synth(m - 12, seconds, "sine", vol=vol * 0.6, attack=0.004, decay=1.4,
                   sustain=0.0, release=0.5, cutoff=(3000, 1500, 0.5))
    return [a + b + c for a, b, c in zip(body, ring + [0.0] * len(body), octave)][:len(body)]


# E natural minor; D# is used over the B chord.
BOSS_PCS = [4, 6, 7, 9, 11, 0, 2]
BOSS_CHORDS = {
    "Em": {"bass": "E2", "pad": ["E3", "G3", "B3", "E4"], "arp": ["E4", "G4", "B4", "E5"]},
    "F": {"bass": "F2", "pad": ["F3", "A3", "C4", "F4"], "arp": ["F4", "A4", "C5", "F5"]},
    "D": {"bass": "D2", "pad": ["D3", "F#3", "A3", "D4"], "arp": ["D4", "F#4", "A4", "D5"]},
    "C": {"bass": "C2", "pad": ["C3", "E3", "G3", "C4"], "arp": ["C4", "E4", "G4", "C5"]},
    "Am": {"bass": "A1", "pad": ["A2", "C3", "E3", "A3"], "arp": ["A3", "C4", "E4", "A4"]},
    "B": {"bass": "B1", "pad": ["B2", "D#3", "F#3", "B3"], "arp": ["B3", "D#4", "F#4", "B4"]},
}
MENACE = ["Em", "F", "Em", "D"]
TURN = ["Em", "C", "Am", "B"]
BOSS_HOOK = [
    [(0, 3, "E5"), (3, 3, "G5"), (6, 2, "B5"), (8, 4, "A5"), (12, 2, "G5"), (14, 2, "F#5")],
    [(0, 3, "E5"), (3, 3, "G5"), (6, 2, "C6"), (8, 8, "B5")],
    [(0, 2, "A5"), (2, 2, "G5"), (4, 2, "E5"), (6, 2, "C5"), (8, 4, "E5"), (12, 4, "A5")],
    [(0, 3, "F#5"), (3, 3, "A5"), (6, 2, "D#6"), (8, 8, "B5")],
]
BOSS_CLIMAX = [
    [(0, 2, "B5"), (2, 2, "E6"), (4, 2, "D6"), (6, 2, "B5"), (8, 4, "G5"), (12, 4, "B5")],
    [(0, 2, "C6"), (2, 2, "F6"), (4, 2, "E6"), (6, 2, "C6"), (8, 8, "A5")],
    [(0, 2, "B5"), (2, 2, "E6"), (4, 2, "G6"), (6, 2, "F#6"), (8, 4, "E6"), (12, 4, "B5")],
    [(0, 3, "A5"), (3, 3, "D6"), (6, 2, "F#6"), (8, 8, "A6")],
]
# name, bars, progression, kick, hat, clap, arp vol, arp cutoff, pad vol, bass vol, lead
BOSS_SECTIONS = [
    ("intro",  4, MENACE, 0.6,  0.10, 0.0,  0.08, 900,  0.10, 0.45, None),
    ("drive",  8, MENACE, 0.85, 0.18, 0.35, 0.11, 1800, 0.10, 0.52, None),
    ("hook",   8, TURN,   0.9,  0.20, 0.40, 0.11, 2600, 0.11, 0.52, "hook"),
    ("climax", 8, MENACE, 0.95, 0.24, 0.50, 0.12, 4200, 0.12, 0.55, "climax"),
    ("break",  4, TURN,   0.0,  0.0,  0.0,  0.07, 800,  0.11, 0.35, None),
]


def boss_theme():
    bar_len = 16 * STEP
    plan = []
    for name, count, prog, *levels in BOSS_SECTIONS:
        for i in range(count):
            plan.append((name, i, count, BOSS_CHORDS[prog[i % 4]], levels))
    mix = Mix(len(plan) * bar_len, wrap=True)
    rng = random.Random(21)
    kicks = []
    starts = {}
    for bar, (name, idx, count, chord, levels) in enumerate(plan):
        k_vol, hat, clap, arp_v, arp_c, pad_v, bass_v, part = levels
        t0 = bar * bar_len
        starts.setdefault(name, bar)
        climax = name == "climax"
        for beat in range(4):
            bt = t0 + beat * 4 * STEP
            if k_vol and (name != "intro" or beat == 0):
                mix.put("kick", bt, kick(k_vol))
                kicks.append(bt)
            # March bass: root, octave, root on the 16ths after the kick.
            for s in (1, 2, 3):
                note = midi(chord["bass"]) + (12 if s == 2 and name != "intro" else 0)
                mix.put("bass", bt + s * STEP, bass_note(note, vol=bass_v))
            if hat:
                mix.put("hat", bt + 2 * STEP, noise_hit(rng, 0.08, 6000, 12000, hat))
                for s in (1, 3):
                    mix.put("hat", bt + s * STEP, noise_hit(rng, 0.03, 7000, 13000, hat * 0.35))
            if clap and beat in (1, 3):
                mix.put("clap", bt, noise_hit(rng, 0.18, 900, 3200, clap, bursts=3))
            if climax:
                mix.put("stab", bt + 2 * STEP, stab(chord["arp"][:3]))
        mix.put("pad", t0, pad_chord(chord["pad"], bar_len - 0.1, cutoff=1100 if climax else 800, vol=pad_v))
        order = [0, 1, 2, 3, 2, 1, 2, 3] if name != "break" else [0, 2, 1, 2]
        for s in range(16):
            note = chord["arp"][order[s % len(order)]]
            mix.put("arp", t0 + s * STEP, pluck(note, arp_c, vol=arp_v))
        if part:
            phrase = BOSS_CLIMAX[idx % 4] if part == "climax" and idx < 4 else BOSS_HOOK[idx % 4]
            lift = 12 if part == "climax" and idx >= 4 else 0
            prev = None
            for step, length, note in phrase:
                m = midi(note) + lift
                mix.put("lead", t0 + step * STEP, lead(m, length, glide_from=prev))
                if part == "climax":
                    mix.put("lead", t0 + step * STEP, lead(lower_third(m, BOSS_PCS + [3]), length, vol=0.09))
                prev = m
    # Tension into the drive, and crashes on the big entrances.
    mix.put("fx", (starts["drive"] - 2) * bar_len, riser(rng, 2 * bar_len))
    mix.put("fx", starts["drive"] * bar_len, noise_hit(rng, 1.6, 3000, 11000, 0.18))
    mix.put("fx", starts["hook"] * bar_len, noise_hit(rng, 1.4, 3000, 11000, 0.14))
    mix.put("fx", starts["climax"] * bar_len - 4 * STEP, riser(rng, 4 * STEP, vol=0.16))
    mix.put("fx", starts["climax"] * bar_len, noise_hit(rng, 2.2, 2500, 11000, 0.22))
    mix.put("fx", (len(plan) - 2) * bar_len, riser(rng, 2 * bar_len, vol=0.1))
    mix.echo("arp", STEP * 3, 0.3, 0.4)
    mix.echo("lead", STEP * 3, 0.35, 0.38)
    mix.echo("stab", STEP * 3, 0.25, 0.3)
    mix.duck("pad", kicks, 0.7)
    mix.duck("arp", kicks, 0.45)
    mix.duck("stab", kicks, 0.3)
    mix.duck("bass", kicks, 0.3, length=0.12)
    mix.duck("lead", kicks, 0.2)
    return mix


# A harmonic minor (G#) for the circus-executioner mood.
ROTO_PCS = [9, 11, 0, 2, 4, 5, 8]
ROTO_CHORDS = {
    "Am": {"bass": "A1", "fifth": "E2", "chord": ["A3", "C4", "E4"], "pad": ["A2", "C3", "E3", "A3"]},
    "E": {"bass": "E2", "fifth": "B1", "chord": ["G#3", "B3", "D4"], "pad": ["E2", "G#2", "B2", "D3"]},
    "Dm": {"bass": "D2", "fifth": "A1", "chord": ["D4", "F4", "A4"], "pad": ["D3", "F3", "A3", "D4"]},
    "F": {"bass": "F1", "fifth": "C2", "chord": ["F3", "A3", "C4"], "pad": ["F2", "A2", "C3", "F3"]},
}
ROTO_PROG = ["Am", "E", "Am", "E", "Dm", "Am", "E", "Am"]
# (tick, length, note) on a 12-tick bar (triplet eighths).
ROTO_TUNE = [
    [(0, 2, "E5"), (2, 1, "A5"), (3, 2, "G#5"), (5, 1, "A5"), (6, 2, "C6"), (8, 1, "B5"), (9, 3, "A5")],
    [(0, 2, "G#5"), (2, 1, "B5"), (3, 2, "A5"), (5, 1, "G#5"), (6, 2, "F5"), (8, 1, "E5"), (9, 3, "D5")],
    [(0, 2, "E5"), (2, 1, "A5"), (3, 2, "G#5"), (5, 1, "A5"), (6, 2, "E6"), (8, 1, "D6"), (9, 3, "C6")],
    [(0, 1, "B5"), (1, 1, "C6"), (2, 1, "B5"), (3, 1, "A5"), (4, 1, "G#5"), (5, 1, "F5"), (6, 3, "E5"), (9, 3, "G#5")],
    [(0, 2, "D5"), (2, 1, "F5"), (3, 2, "A5"), (5, 1, "D6"), (6, 3, "C6"), (9, 2, "A5"), (11, 1, "F5")],
    [(0, 2, "E5"), (2, 1, "A5"), (3, 2, "C6"), (5, 1, "E6"), (6, 3, "D6"), (9, 3, "C6")],
    [(0, 1, "G#5"), (1, 1, "A5"), (2, 1, "B5"), (3, 1, "C6"), (4, 1, "D6"), (5, 1, "E6"),
     (6, 1, "F6"), (7, 1, "E6"), (8, 1, "D6"), (9, 3, "B5")],
    [(0, 3, "A5"), (3, 3, "E5"), (6, 6, "A4")],
]
# The executioner's verdict: slow, low, deliberate.
ROTO_VERDICT = [
    [(0, 6, "A3"), (6, 6, "C4")],
    [(0, 6, "B3"), (6, 3, "G#3"), (9, 3, "E3")],
    [(0, 6, "F3"), (6, 6, "D3")],
    [(0, 9, "E3"), (9, 3, "G#3")],
]
# Busy from the first bar to the last: the hook opens the loop and the reel,
# oom-pah and kick never drop out; the verdict darkens without going quiet.
# name, bars, kick pattern, clap, oom-pah vol, reel vol, pad vol, lead
ROTO_SECTIONS = [
    ("circus",  8, "four",  0.30, 0.11, 0.06, 0.07, "tune"),
    ("frenzy",  8, "four",  0.40, 0.11, 0.07, 0.08, "tune2"),
    ("verdict", 4, "four",  0.40, 0.09, 0.06, 0.11, "verdict"),
    ("jackpot", 8, "four",  0.45, 0.12, 0.08, 0.10, "twin"),
]


def broken_machine(beat_len):
    """Reel 5: wobbling pitch, a muffled low-pass, bit-crush grit and stutters.
    Every step wraps around the loop so the seam stays clean."""
    def post(total):
        n = len(total)
        out = [0.0] * n
        for i in range(n):  # pitch wobble through a modulated delay
            t = i / RATE
            d = (0.006 + 0.004 * math.sin(2 * math.pi * 0.55 * t)) * RATE
            j = i - d
            k = math.floor(j)
            f = j - k
            out[i] = total[k % n] * (1 - f) + total[(k + 1) % n] * f
        a = lp_coef(750)
        y1 = y2 = 0.0
        for _ in range(2):  # two passes so the filter state wraps into the start
            for i in range(n):
                y1 += a * (out[i] - y1)
                y2 += a * (y1 - y2)
                out[i] = y2 if _ else out[i]
        hold = 0.0
        crush = int(RATE / 6000)
        rng = random.Random(55)
        beat = int(beat_len * RATE)
        cut = [rng.random() < 0.3 for _ in range(n // beat + 1)]
        fade = int(0.006 * RATE)
        for i in range(n):
            if i % crush == 0:
                hold = round(out[i] * 24) / 24
            s = out[i] * 0.6 + hold * 0.4
            b, pos = divmod(i, beat)
            if cut[b] and pos > beat // 2:  # the machine drops out for half a beat
                edge = min(pos - beat // 2, beat - pos)
                s *= max(0.0, 1 - edge / fade) if edge < fade else 0.0
            out[i] = s
        return out
    return post


def roto_theme(variant="normal"):
    """variant: "normal", "error" (reel 5) or "jackpot" (reel 7). All three
    share the timeline exactly so the game can cross-fade between them."""
    error = variant == "error"
    jackpot = variant == "jackpot"
    beat_len = 4 * STEP
    tick = beat_len / 3
    bar_len = 4 * beat_len
    plan = []
    for name, count, *levels in ROTO_SECTIONS:
        for i in range(count):
            plan.append((name, i, count, levels))
    mix = Mix(len(plan) * bar_len, wrap=True)
    rng = random.Random(77)
    kicks = []
    starts = {}

    def note_len(ticks):
        return ticks * tick * 0.9

    for bar, (name, idx, count, levels) in enumerate(plan):
        kick_mode, clap, oompah, reel, pad_v, part = levels
        key = ROTO_PROG[idx % 8] if name != "verdict" else ["Am", "E", "Dm", "E"][idx % 4]
        chord = ROTO_CHORDS[key]
        t0 = bar * bar_len
        starts.setdefault(name, bar)
        for beat in range(4):
            bt = t0 + beat * beat_len
            hit = (kick_mode == "four") or (kick_mode == "waltz" and beat in (0, 2)) or (kick_mode == "half" and beat == 0)
            if hit:
                if not error:
                    mix.put("kick", bt, kick((0.95 if name == "verdict" and beat == 0 else 0.8) + (0.1 if jackpot else 0.0)))
                kicks.append(bt)
            if clap and beat in (1, 3) and not error:
                mix.put("clap", bt, noise_hit(rng, 0.16, 900, 3200, clap * (1.3 if jackpot else 1.0), bursts=3))
            if jackpot:
                # Gold: a bell on every beat climbing the chord, and a sub thump on the bar.
                tone = chord["chord"][beat % 3]
                mix.put("bell", bt, bell(midi(tone) + 24, 0.5, vol=0.05))
                if beat == 0:
                    mix.put("bass", bt, synth(midi(chord["bass"]) - 12, beat_len * 1.5, "sine", vol=0.35,
                                              attack=0.004, decay=0.4, sustain=0.2, release=0.1,
                                              cutoff=(400, 200, 0.2)))
            if kick_mode != "none":
                mix.put("hat", bt + 2 * tick, noise_hit(rng, 0.05, 6500, 12500, 0.12))
            if oompah:
                # Oom-pah: bass on the beat (root / fifth), chord plucks on the swung offbeats.
                bass = chord["bass"] if beat in (0, 2) else chord["fifth"]
                mix.put("bass", bt, synth(bass, tick * 1.6, "saw", detune=(-6, 6), vol=0.5,
                                          attack=0.003, decay=0.1, sustain=0.45, release=0.03,
                                          cutoff=(1500, 280, 0.05)))
                for off in (1, 2):
                    for nt in chord["chord"]:
                        mix.put("comp", bt + off * tick, pluck(nt, 1800, vol=oompah * 0.55))
            if reel:
                # Reel spin: fast triplet plucks tumbling through the chord.
                tones = chord["chord"] + [chord["chord"][0]]
                for k in range(3):
                    idx_note = (beat * 3 + k + bar) % 4
                    m = midi(tones[idx_note]) + 12
                    mix.put("arp", bt + k * tick, pluck(m, 2600, vol=reel))
        mix.put("pad", t0, pad_chord(chord["pad"], bar_len - 0.1, cutoff=900, vol=pad_v))
        if part in ("tune", "tune2", "twin") and not error:
            phrase = ROTO_TUNE[idx % 8]
            prev = None
            for tk, length, note in phrase:
                m = midi(note) + (12 if part == "twin" and idx >= 4 else 0)
                mix.put("lead", t0 + tk * tick, synth(m, note_len(length), "saw", detune=(-7, 7),
                                                       vol=0.15, attack=0.006, decay=0.18, sustain=0.6,
                                                       release=0.06, cutoff=(3000, 1700, 0.15),
                                                       glide_from=prev if length > 1 else None))
                if jackpot:
                    mix.put("lead", t0 + tk * tick, synth(m + 12, note_len(length), "pulse", duty=0.3,
                                                           vol=0.06, attack=0.004, decay=0.15, sustain=0.5,
                                                           release=0.05, cutoff=(4500, 2200, 0.1)))
                if part in ("tune2", "twin"):
                    low = lower_third(m, ROTO_PCS)
                    mix.put("lead", t0 + tk * tick, synth(low, note_len(length), "pulse", duty=0.25,
                                                           vol=0.07, attack=0.004, decay=0.15, sustain=0.5,
                                                           release=0.05, cutoff=(2500, 1200, 0.1)))
                prev = m
        elif part == "verdict":
            mix.put("bell", t0, bell("A5" if idx % 2 == 0 else "E5", 2.0, vol=0.12))
            for tk, length, note in ([] if error else ROTO_VERDICT[idx % 4]):
                mix.put("lead", t0 + tk * tick, synth(note, note_len(length), "saw", detune=(-9, 0, 9),
                                                       vol=0.2, attack=0.03, decay=0.5, sustain=0.7,
                                                       release=0.2, cutoff=(1600, 700, 0.3)))
                mix.put("lead", t0 + tk * tick, synth(midi(note) - 12, note_len(length), "saw", detune=(-5, 5),
                                                       vol=0.12, attack=0.03, decay=0.5, sustain=0.7,
                                                       release=0.2, cutoff=(900, 400, 0.3)))
    # Jackpot: a bright bell sweep and crash as the climax lands.
    jp = starts["jackpot"] * bar_len
    for k, note in enumerate(["A5", "C6", "E6", "A6", "C7", "E7"]):
        mix.put("bell", jp - (6 - k) * tick, bell(note, 0.8, vol=0.07))
    mix.put("fx", jp, noise_hit(rng, 2.2, 2500, 11000, 0.22))
    # The loop opens on a crash so every lap lands with a bang.
    mix.put("fx", 0, noise_hit(rng, 1.6, 3000, 11000, 0.18))
    mix.put("fx", starts["frenzy"] * bar_len, noise_hit(rng, 1.4, 3000, 11000, 0.15))
    mix.put("fx", starts["verdict"] * bar_len, noise_hit(rng, 2.5, 1200, 6000, 0.14))
    mix.put("fx", jp - 2 * beat_len, riser(rng, 2 * beat_len, vol=0.16))
    mix.echo("arp", tick * 2, 0.3, 0.35)
    mix.echo("lead", tick * 3, 0.3, 0.32)
    mix.echo("bell", beat_len, 0.4, 0.5)
    mix.duck("pad", kicks, 0.6)
    mix.duck("comp", kicks, 0.3)
    mix.duck("arp", kicks, 0.35)
    mix.duck("lead", kicks, 0.15)
    if error:
        mix.post = broken_machine(beat_len)
        mix.loudness = 0.65
    elif jackpot:
        mix.loudness = 1.1
    return mix


# ---------------------------------------------------------------------------
# Celtic x cyber: the draft (before setting out) and the camp
# ---------------------------------------------------------------------------

# Breath noise in the whistle (0 = clean).
BREATH = 0.0


def whistle(note, seconds, vol=0.13, cut=None, vib=True):
    """Tin-whistle-like voice: soft sine with a little second harmonic, breath
    noise, delayed vibrato and an optional grace-note cut above."""
    m = midi(note) if isinstance(note, str) else note
    n = int((seconds + 0.08) * RATE)
    base = hz(m)
    grace = hz(cut if cut is not None else m + 2) if cut is not False else base
    rng = random.Random(m * 7 + int(seconds * 100))
    out = [0.0] * n
    phase = 0.0
    breath = 0.0
    for i in range(n):
        t = i / RATE
        f = grace if (cut is not False and t < 0.035) else base
        if vib and t > 0.25:
            f *= 1 + 0.006 * math.sin(2 * math.pi * 5.5 * (t - 0.25)) * min(1.0, (t - 0.25) * 3)
        phase = (phase + f / RATE) % 1.0
        tone = math.sin(2 * math.pi * phase) + 0.18 * math.sin(4 * math.pi * phase)
        breath += 0.2 * (rng.uniform(-1, 1) - breath)
        if t < 0.03:
            env = t / 0.03
        elif t < seconds:
            env = 0.85 + 0.15 * math.exp(-(t - 0.03) / 0.2)
        else:
            env = 0.85 * max(0.0, 1 - (t - seconds) / 0.08)
        out[i] = (tone + breath * BREATH) * env * vol
    return out


def bodhran(vol=0.5, accent=False):
    """Frame drum: a pitch-dropping low thump plus a skin slap."""
    n = int(0.3 * RATE)
    out = [0.0] * n
    phase = 0.0
    rng = random.Random(3)
    y = 0.0
    for i in range(n):
        t = i / RATE
        f = 70 + (90 if accent else 60) * math.exp(-t * 25)
        phase += f / RATE
        y += lp_coef(900) * (rng.uniform(-1, 1) - y)
        out[i] = (math.sin(2 * math.pi * phase) * math.exp(-t * 9) + y * math.exp(-t * 80) * 0.15) * vol
    return out


def drone(notes, seconds, vol=0.06):
    """Bagpipe-like drone: buzzy saws low-passed, breathing slowly."""
    voices = [synth(nt, seconds, "saw", detune=(-4, 4), vol=vol, attack=0.4, decay=1.0,
                    sustain=1.0, release=0.4, cutoff=(700, 700, 1.0)) for nt in notes]
    return [sum(v) for v in zip(*voices)]


def harp(note, vol=0.1):
    return synth(note, 1.6, "tri", vol=vol, attack=0.003, decay=0.5, sustain=0.08,
                 release=0.8, cutoff=(4000, 1400, 0.3))


def crackle(rng, seconds, vol=0.05):
    """Campfire, kept clean: no hiss, just a few soft rounded pops (short
    decaying low sine blips instead of noise bursts)."""
    n = int(seconds * RATE)
    out = [0.0] * n
    for _ in range(int(seconds * 3)):
        at = rng.randrange(n)
        f = rng.uniform(900, 1600)
        pop = rng.uniform(0.3, 1.0) * vol
        for k in range(int(0.02 * RATE)):
            t = k / RATE
            out[(at + k) % n] += math.sin(2 * math.pi * f * t) * math.exp(-t * 300) * pop
    return out


# E Dorian jig in 6/8: six eighth-note ticks per bar.
DRAFT_CHORDS = {
    "Em": {"bass": "E2", "arp": ["E4", "G4", "B4"], "pad": ["E3", "B3", "G4"]},
    "D": {"bass": "D2", "arp": ["D4", "F#4", "A4"], "pad": ["D3", "A3", "F#4"]},
    "A": {"bass": "A1", "arp": ["A3", "C#4", "E4"], "pad": ["A2", "E3", "C#4"]},
}
JIG_A = [
    [(0, 1, "B4"), (1, 1, "E5"), (2, 1, "E5"), (3, 1, "G5"), (4, 1, "E5"), (5, 1, "E5")],
    [(0, 1, "D5"), (1, 1, "F#5"), (2, 1, "A5"), (3, 1, "F#5"), (4, 1, "E5"), (5, 1, "D5")],
    [(0, 1, "B4"), (1, 1, "E5"), (2, 1, "E5"), (3, 1, "G5"), (4, 1, "E5"), (5, 1, "G5")],
    [(0, 1, "A5"), (1, 1, "F#5"), (2, 1, "D5"), (3, 3, "E5")],
    [(0, 1, "B4"), (1, 1, "E5"), (2, 1, "E5"), (3, 1, "G5"), (4, 1, "E5"), (5, 1, "E5")],
    [(0, 1, "D5"), (1, 1, "F#5"), (2, 1, "A5"), (3, 1, "B5"), (4, 1, "A5"), (5, 1, "F#5")],
    [(0, 1, "E5"), (1, 1, "C#5"), (2, 1, "E5"), (3, 1, "A5"), (4, 1, "G5"), (5, 1, "F#5")],
    [(0, 2, "E5"), (2, 1, "B4"), (3, 3, "E5")],
]
JIG_B = [
    [(0, 1, "E6"), (1, 1, "D6"), (2, 1, "B5"), (3, 1, "A5"), (4, 1, "B5"), (5, 1, "D6")],
    [(0, 1, "E6"), (1, 1, "B5"), (2, 1, "G5"), (3, 3, "A5")],
    [(0, 1, "D6"), (1, 1, "B5"), (2, 1, "A5"), (3, 1, "F#5"), (4, 1, "A5"), (5, 1, "D6")],
    [(0, 1, "F#6"), (1, 1, "E6"), (2, 1, "D6"), (3, 3, "E6")],
    [(0, 1, "E6"), (1, 1, "D6"), (2, 1, "B5"), (3, 1, "A5"), (4, 1, "B5"), (5, 1, "D6")],
    [(0, 1, "E6"), (1, 1, "B5"), (2, 1, "G5"), (3, 3, "A5")],
    [(0, 1, "G5"), (1, 1, "A5"), (2, 1, "B5"), (3, 1, "C#6"), (4, 1, "D6"), (5, 1, "B5")],
    [(0, 3, "E6"), (3, 3, "B5")],
]
JIG_A_CHORDS = ["Em", "D", "Em", "D", "Em", "D", "A", "Em"]
JIG_B_CHORDS = ["Em", "Em", "D", "D", "Em", "Em", "A", "Em"]


def draft_theme(bpm=100):
    """Before setting out: whistle jig over drone and bodhran, cyber arp and kick."""
    beat = 60.0 / bpm           # dotted quarter
    tick = beat / 3             # eighth note
    bar = beat * 2
    plan = [("intro", i, "Em" if i % 2 == 0 else "D", None) for i in range(4)]
    plan += [("A", i, JIG_A_CHORDS[i], JIG_A[i]) for i in range(8)]
    plan += [("A2", i, JIG_A_CHORDS[i], JIG_A[i]) for i in range(8)]
    plan += [("B", i, JIG_B_CHORDS[i], JIG_B[i]) for i in range(8)]
    plan += [("B2", i, JIG_B_CHORDS[i], JIG_B[i]) for i in range(8)]
    mix = Mix(len(plan) * bar, wrap=True)
    rng = random.Random(31)
    kicks = []
    for b, (name, idx, key, phrase) in enumerate(plan):
        chord = DRAFT_CHORDS[key]
        t0 = b * bar
        full = name in ("A2", "B2")
        mix.put("drone", t0, drone(["E2", "B2"], bar, vol=0.05))
        # Bodhran: the jig's lilt, accent on each dotted beat.
        for k, hit in enumerate([1, 0, 1, 1, 0, 1]):
            if hit and (name != "intro" or k in (0, 3)):
                mix.put("drum", t0 + k * tick, bodhran(0.45 if k in (0, 3) else 0.25, accent=k in (0, 3)))
        if full:
            for k in (0, 3):
                mix.put("kick", t0 + k * tick, kick(0.6))
                kicks.append(t0 + k * tick)
            mix.put("hat", t0 + 2 * tick, noise_hit(rng, 0.04, 6500, 10000, 0.035))
            mix.put("hat", t0 + 5 * tick, noise_hit(rng, 0.04, 6500, 10000, 0.035))
        # Bass on the beats.
        for k in (0, 3):
            mix.put("bass", t0 + k * tick, synth(chord["bass"], tick * 2.4, "saw", detune=(-6, 6), vol=0.35,
                                                 attack=0.005, decay=0.15, sustain=0.5, release=0.05,
                                                 cutoff=(1200, 300, 0.08)))
        # Cyber arp: triplet plucks through the chord, brighter in the full parts.
        for k in range(6):
            nt = chord["arp"][[0, 1, 2, 1, 2, 1][k]]
            mix.put("arp", t0 + k * tick, pluck(midi(nt) + 12, 2800 if full else 1600, vol=0.07 if full else 0.05))
        mix.put("pad", t0, pad_chord(chord["pad"], bar - 0.05, cutoff=900, vol=0.05))
        if phrase:
            for tk, length, note in phrase:
                cut = (tk % 3 == 0) and length == 1
                mix.put("lead", t0 + tk * tick, whistle(note, length * tick * 0.92, vol=0.14, cut=None if cut else False))
                if full:
                    # A quiet digital double an octave below.
                    mix.put("lead", t0 + tk * tick, pluck(midi(note) - 12, 2200, vol=0.05))
    mix.put("fx", 4 * bar, noise_hit(rng, 1.0, 3000, 8000, 0.05))
    mix.put("fx", 20 * bar, noise_hit(rng, 1.2, 3000, 8000, 0.06))
    mix.compression = CLEAN_COMPRESSION
    mix.echo("arp", tick * 3, 0.3, 0.35)
    mix.echo("lead", tick * 3, 0.25, 0.25)
    mix.duck("arp", kicks, 0.3)
    mix.duck("pad", kicks, 0.4)
    return mix


# D Mixolydian slow air in 3/4.
CAMP_CHORDS = {
    "D": {"bass": "D2", "harp": ["D3", "A3", "D4", "F#4", "A4", "D5"], "pad": ["D3", "A3", "F#4"]},
    "C": {"bass": "C2", "harp": ["C3", "G3", "C4", "E4", "G4", "C5"], "pad": ["C3", "G3", "E4"]},
    "G": {"bass": "G1", "harp": ["G2", "D3", "G3", "B3", "D4", "G4"], "pad": ["G2", "D3", "B3"]},
}
CAMP_AIR = [
    [(0, 2, "F#5"), (2, 1, "A5")],
    [(0, 2, "G5"), (2, 1, "E5")],
    [(0, 1, "D5"), (1, 1, "E5"), (2, 1, "G5")],
    [(0, 3, "F#5")],
    [(0, 2, "A5"), (2, 1, "B5")],
    [(0, 2, "C6"), (2, 1, "B5")],
    [(0, 1, "A5"), (1, 1, "G5"), (2, 1, "E5")],
    [(0, 3, "D5")],
    [(0, 2, "B5"), (2, 1, "A5")],
    [(0, 2, "F#5"), (2, 1, "E5")],
    [(0, 1, "E5"), (1, 1, "G5"), (2, 1, "C6")],
    [(0, 3, "A5")],
]
CAMP_PLAN = ["D", "C", "G", "D"] + ["D", "C", "G", "D", "D", "C", "G", "D", "G", "D", "C", "D"]


def camp_theme(bpm=76):
    """Rest by the fire: harp arpeggios, a slow whistle air, drone, crackle, a
    faint digital rain."""
    beat = 60.0 / bpm
    bar = beat * 3
    mix = Mix(len(CAMP_PLAN) * bar, wrap=True)
    rng = random.Random(57)
    mix.put("fire", 0, crackle(rng, len(CAMP_PLAN) * bar, vol=0.09))
    for b, key in enumerate(CAMP_PLAN):
        chord = CAMP_CHORDS[key]
        t0 = b * bar
        mix.put("drone", t0, drone(["D2", "A2"], bar, vol=0.035))
        mix.put("pad", t0, pad_chord(chord["pad"], bar - 0.05, cutoff=700, vol=0.045))
        mix.put("bass", t0, synth(chord["bass"], bar * 0.9, "sine", vol=0.25, attack=0.05, decay=0.8,
                                  sustain=0.5, release=0.4, cutoff=(600, 400, 0.5)))
        # Harp: rolling up the chord in eighths.
        for k, nt in enumerate(chord["harp"]):
            mix.put("harp", t0 + k * beat / 2, harp(nt, vol=0.09))
        # Digital rain: a few high glassy blips every other bar.
        if b % 2 == 1:
            for k in range(3):
                nt = midi(chord["harp"][-1 - k]) + 12
                mix.put("rain", t0 + (1.5 + k * 0.5) * beat, synth(nt, 0.08, "pulse", duty=0.2, vol=0.035,
                                                                 attack=0.001, decay=0.05, sustain=0.1,
                                                                 release=0.05, cutoff=(5000, 2500, 0.05)))
        if b >= 4:
            for tk, length, note in CAMP_AIR[b - 4]:
                mix.put("lead", t0 + tk * beat, whistle(note, length * beat * 0.95, vol=0.12,
                                                        cut=None if length > 1 else False))
    mix.echo("harp", beat / 2 * 3, 0.3, 0.35)
    mix.echo("lead", beat, 0.3, 0.35)
    mix.echo("rain", beat * 0.75, 0.45, 0.6)
    mix.loudness = 0.75
    mix.compression = CLEAN_COMPRESSION
    return mix


# ---------------------------------------------------------------------------
# The Prison King (final boss): heavy, slow and regal; a rage twin in sync
# ---------------------------------------------------------------------------

# C Phrygian dominant (C Db E F G Ab Bb); the battle-hook quote borrows C minor.
KING_PCS = [0, 1, 4, 5, 7, 8, 10]
KING_CHORDS = {
    "C": {"bass": "C2", "pad": ["C3", "E3", "G3", "C4"], "arp": ["C4", "E4", "G4", "C5"]},
    "Db": {"bass": "Db2", "pad": ["Db3", "F3", "Ab3", "Db4"], "arp": ["Db4", "F4", "Ab4", "Db5"]},
    "Fm": {"bass": "F1", "pad": ["F2", "Ab2", "C3", "F3"], "arp": ["F3", "Ab3", "C4", "F4"]},
    "Bbm": {"bass": "Bb1", "pad": ["Bb2", "Db3", "F3", "Bb3"], "arp": ["Bb3", "Db4", "F4", "Bb4"]},
    "Ab": {"bass": "Ab1", "pad": ["Ab2", "C3", "Eb3", "Ab3"], "arp": ["Ab3", "C4", "Eb4", "Ab4"]},
    "Cm": {"bass": "C2", "pad": ["C3", "Eb3", "G3", "C4"], "arp": ["C4", "Eb4", "G4", "C5"]},
    "G": {"bass": "G1", "pad": ["G2", "B2", "D3", "G3"], "arp": ["G3", "B3", "D4", "G4"]},
}
# The king's own motif: slow, stepping through the flat second and the major third.
KING_MOTIF = [
    [(0, 6, "C5"), (6, 2, "Db5"), (8, 8, "E5")],
    [(0, 4, "F5"), (4, 4, "E5"), (8, 4, "Db5"), (12, 4, "C5")],
    [(0, 6, "G5"), (6, 2, "Ab5"), (8, 6, "G5"), (14, 2, "F5")],
    [(0, 4, "E5"), (4, 4, "Db5"), (8, 8, "C5")],
]
KING_ANSWER = [
    [(0, 4, "C6"), (4, 4, "Bb5"), (8, 4, "Ab5"), (12, 4, "G5")],
    [(0, 6, "Ab5"), (6, 2, "G5"), (8, 8, "F5")],
    [(0, 4, "E5"), (4, 4, "F5"), (8, 4, "G5"), (12, 4, "Ab5")],
    [(0, 6, "Bb5"), (6, 2, "Ab5"), (8, 8, "G5")],
]
# name, bars, progression
KING_PLAN = [
    ("gate", 6, ["C", "C", "Db", "C", "Db", "C"]),
    ("march", 12, ["C", "Db", "Fm", "C"]),
    ("motif", 12, ["C", "Db", "Fm", "C"]),
    ("quote", 12, ["Cm", "Ab", "Fm", "G"]),
    ("build", 8, ["Fm", "Db", "Bbm", "C"]),
    ("climax", 16, ["C", "Db", "Fm", "Db"]),
    ("silence", 8, ["C", "C", "Db", "C"]),
    ("reprise", 12, ["C", "Db", "Fm", "C"]),
    ("turn", 4, ["Db", "Db", "C", "C"]),
]


def organ(notes, seconds, vol=0.05, cutoff=1600):
    """Throne-room organ: square voices with their octave, slow swell."""
    voices = []
    for nt in notes:
        m = midi(nt) if isinstance(nt, str) else nt
        for shift, v in ((0, vol), (12, vol * 0.5)):
            voices.append(synth(m + shift, seconds, "pulse", duty=0.5, vol=v, attack=0.12,
                                decay=0.8, sustain=0.85, release=0.3, cutoff=(cutoff, cutoff * 0.7, 1.0)))
    return [sum(v) for v in zip(*voices)]


def chains(rng, vol=0.08):
    """A rattle of chain links: a few bright, gritty bursts."""
    return noise_hit(rng, 0.28, 2500, 9000, vol, bursts=5)


def door_slam(rng, vol=0.5):
    """An iron door slamming shut: a low thud and a clang."""
    thud = kick(vol)
    clang = noise_hit(rng, 0.45, 300, 2600, vol * 0.35)
    ring = bell("C3", 0.6, vol=vol * 0.08)
    out = [0.0] * max(len(thud), len(clang), len(ring))
    for part in (thud, clang, ring):
        for i, x in enumerate(part):
            out[i] += x
    return out


def dirty_bass(note, steps, vol):
    raw = bass_note(note, steps, vol=vol)
    return [math.tanh(x * 4.0) * vol * 0.6 for x in raw]


def siren(seconds, vol=0.04):
    """A wailing alarm: a pulse voice gliding a fifth up and back."""
    return synth("G5", seconds, "pulse", duty=0.35, vol=vol, attack=0.05, decay=1.0, sustain=0.9,
                 release=0.2, cutoff=(3200, 2400, 1.0),
                 pitch=lambda t: 2 ** ((7 * (0.5 - 0.5 * math.cos(t * math.pi * 2 / seconds))) / 12))


def king_theme(variant="normal"):
    """Three minutes under the Prison King. 'rage' is the same score, sample for
    sample in time, with double-time drums, a siren, tolling bells on every
    beat, a distorted bass and the melodies an octave up; the game cross-fades
    to it when the king drops to half health."""
    rage = variant == "rage"
    bar_len = 16 * STEP
    beat = 4 * STEP
    plan = []
    for name, count, prog in KING_PLAN:
        for i in range(count):
            plan.append((name, i, count, KING_CHORDS[prog[i % len(prog)]]))
    mix = Mix(len(plan) * bar_len, wrap=True)
    rng = random.Random(1111)
    kicks = []
    starts = {}
    # The battle hook, down a tone to C and borrowed into the king's minor.
    quote = [[(st, ln, midi(nt) - 2) for st, ln, nt in bar] for bar in HOOK]
    for b, (name, idx, count, chord) in enumerate(plan):
        t0 = b * bar_len
        starts.setdefault(name, b)
        quiet = name in ("gate", "silence")
        big = name in ("climax", "build")
        # --- drums ---
        if quiet:
            # A heartbeat under the bells (faster in rage).
            for k in ((0, 1, 2, 3) if rage else (0, 2)):
                mix.put("kick", t0 + k * beat, kick(0.32))
                mix.put("kick", t0 + k * beat + STEP, kick(0.2))
        else:
            level = 0.95 if big else 0.8
            for k in range(4):
                if k in (0, 2) or rage:
                    mix.put("kick", t0 + k * beat, kick(level))
                    kicks.append(t0 + k * beat)
                if k == 2 or (rage and k in (1, 3)):
                    mix.put("clap", t0 + k * beat, noise_hit(rng, 0.22, 700, 3000, 0.42 if big else 0.34, bursts=3))
            hats = range(16) if rage else range(0, 16, 2)
            for s in hats:
                mix.put("hat", t0 + s * STEP, noise_hit(rng, 0.04, 7000, 13000, 0.07 if s % 4 else 0.12))
            if name == "build" and idx >= count - 2:
                for s in range(8, 16):
                    mix.put("clap", t0 + s * STEP, noise_hit(rng, 0.08, 900, 3500, 0.12 + 0.02 * s))
        # --- bells, chains, doors, keys ---
        toll = quiet or name == "climax" or (name == "quote" and idx % 2 == 0)
        if toll:
            for k in (range(4) if rage else (0,)):
                mix.put("bell", t0 + k * beat, bell("C4" if k == 0 else "G3", 2.0 if k == 0 else 0.8, vol=0.09))
        if not quiet:
            mix.put("chain", t0 + 14 * STEP, chains(rng, 0.06 if not rage else 0.09))
        if idx % 4 == 3 and name in ("march", "motif", "climax", "reprise", "build"):
            mix.put("door", t0 + 12 * STEP, door_slam(rng, 0.55))
        if quiet and b % 2 == 1:
            for k in range(3):
                mix.put("keys", t0 + (6 + k * 2) * STEP, pluck(midi("C7") + [0, 4, 7][k], 6000, vol=0.03))
        # --- drone / organ / bass ---
        if quiet:
            mix.put("drone", t0, synth(chord["bass"], bar_len, "sine", vol=0.07, attack=0.3, decay=1.0,
                                       sustain=0.9, release=0.4, cutoff=(500, 400, 1.0)))
            mix.put("pad", t0, organ(chord["pad"][:3], bar_len - 0.1, vol=0.018, cutoff=800))
        else:
            mix.put("pad", t0, organ(chord["pad"], bar_len - 0.1, vol=0.045 if big else 0.035,
                                     cutoff=2200 if big else 1500))
            root = midi(chord["bass"])
            bass_steps = range(0, 16, 2) if rage else ((0, 4, 8, 12) if not big else range(0, 16, 2))
            for s in bass_steps:
                note = root + (12 if big and s % 4 == 2 else 0) + (1 if name == "march" and s == 12 and idx % 2 else 0)
                vol = 0.5 if s % 4 == 0 else 0.4
                mix.put("bass", t0 + s * STEP, dirty_bass(note, 2, vol) if rage else bass_note(note, 3 if not big else 2, vol))
        # --- arps ---
        if name in ("climax", "reprise", "build") or (rage and not quiet):
            order = [0, 1, 2, 3, 2, 1, 2, 3]
            for s in range(0, 16, 1 if rage else 2):
                mix.put("arp", t0 + s * STEP, pluck(chord["arp"][order[(s // (1 if rage else 2)) % 8]],
                                                   3200 if big else 2200, vol=0.08))
        if rage and not quiet and idx % 2 == 0:
            mix.put("siren", t0, siren(bar_len * 2))
        # --- melodies ---
        lift = 12 if rage else 0
        if name in ("motif", "reprise") or (name == "climax" and idx < 8):
            prev = None
            for st, ln, nt in KING_MOTIF[idx % 4]:
                m = midi(nt) + lift - (12 if name == "reprise" else 0)
                mix.put("lead", t0 + st * STEP, lead(m, ln, glide_from=prev, vol=0.15))
                if name == "climax":
                    mix.put("lead", t0 + st * STEP, lead(lower_third(m, KING_PCS), ln, vol=0.08))
                prev = m
        if name == "climax" and idx >= 8:
            for st, ln, nt in KING_ANSWER[idx % 4]:
                m = midi(nt) + lift
                mix.put("lead", t0 + st * STEP, lead(m, ln, vol=0.15))
                mix.put("lead", t0 + st * STEP, lead(lower_third(m, KING_PCS), ln, vol=0.08))
        if name == "quote":
            # The battle hook, remembered in the dark: a slow choir-like voice.
            for st, ln, m in quote[idx % 4]:
                mix.put("choir", t0 + st * STEP, synth(m + lift, ln * STEP * 0.95, "saw", detune=(-9, 9), vol=0.11,
                                                       attack=0.12, decay=0.5, sustain=0.8, release=0.2,
                                                       cutoff=(1800, 1200, 0.4)))
    # Swells into the big entrances.
    for name in ("march", "build", "climax", "reprise"):
        mix.put("fx", starts[name] * bar_len - 2 * bar_len, riser(rng, 2 * bar_len, vol=0.1))
        mix.put("fx", starts[name] * bar_len, noise_hit(rng, 1.8, 2500, 11000, 0.18))
    mix.put("fx", len(plan) * bar_len - 2 * bar_len, riser(rng, 2 * bar_len, vol=0.12))
    mix.echo("bell", beat * 1.5, 0.35, 0.5)
    mix.echo("lead", STEP * 3, 0.35, 0.35)
    mix.echo("choir", beat, 0.4, 0.5)
    mix.echo("arp", STEP * 3, 0.3, 0.35)
    mix.echo("keys", STEP * 3, 0.5, 0.6)
    mix.duck("pad", kicks, 0.5)
    mix.duck("arp", kicks, 0.35)
    mix.duck("bass", kicks, 0.25, length=0.12)
    mix.loudness = 1.1 if rage else 1.0
    return mix


def king_victory_jingle():
    """The Prison King falls: chains snap one by one, the great bell tolls, and the
    battle hook finally rings out in D major."""
    mix = Mix(9.5, wrap=False)
    rng = random.Random(77)
    for k in range(4):
        mix.put("chain", 0.25 * k, chains(rng, 0.12))
        mix.put("chain", 0.25 * k + 0.05, noise_hit(rng, 0.15, 3000, 11000, 0.1))
    mix.put("door", 1.1, door_slam(rng, 0.8))
    mix.put("bell", 1.1, bell("D4", 3.0, vol=0.12))
    hit = 1.9
    mix.put("pad", hit, pad_chord(["D3", "F#3", "A3", "D4", "F#4"], 6.0, cutoff=2400, vol=0.09))
    mix.put("bass", hit, synth("D2", 5.0, "saw", detune=(-6, 6), vol=0.4, decay=1.5,
                               sustain=0.5, release=0.8, cutoff=(1600, 300, 0.2)))
    mix.put("kick", hit, kick())
    mix.put("fx", hit, noise_hit(rng, 2.4, 3000, 11000, 0.18))
    # The hook's first two bars in D major (F -> F#, C -> C#).
    major = {"F5": "F#5", "C5": "C#5", "F4": "F#4"}
    t = hit
    for bar in HOOK[:2]:
        for st, ln, nt in bar:
            mix.put("lead", t + st * STEP, lead(major.get(nt, nt), ln, vol=0.15))
        t += 16 * STEP
    mix.put("lead", t, lead("D6", 12, glide_from="A5", vol=0.14))
    for i, note in enumerate(["A5", "D6", "F#6", "A6", "F#6", "D6", "A5", "D6"]):
        mix.put("arp", t + i * STEP, pluck(note, 3500, vol=0.09))
    mix.echo("lead", STEP * 3, 0.3, 0.35)
    mix.echo("arp", STEP * 3, 0.35, 0.45)
    mix.echo("bell", 0.4, 0.4, 0.5)
    return mix


def king_intro_sting():
    """Under the blackout before the final battle (3.8 s, then the theme starts):
    a cell door slams in the dark, the throne-room organ swells, and as his name
    appears the great bell tolls under the first bar of his motif."""
    mix = Mix(4.3, wrap=False)
    rng = random.Random(81)
    mix.put("door", 0.2, door_slam(rng, 0.8))
    mix.put("fx", 0.0, riser(rng, 1.2, 0.05))
    mix.put("organ", 0.5, organ(["C3", "G3", "C4", "E4"], 3.0, vol=0.05, cutoff=1300))
    mix.put("bass", 0.5, synth("C1", 3.0, "saw", detune=(-8, 8), vol=0.3, attack=0.4, decay=1.5,
                               sustain=0.7, release=0.6, cutoff=(500, 250, 1.0)))
    hit = 1.25
    mix.put("kick", hit, kick())
    mix.put("bell", hit, bell("C3", 2.4, vol=0.14))
    mix.put("bell", hit + 1.0, bell("G2", 1.6, vol=0.09))
    mix.put("chain", hit, chains(rng, 0.1))
    mix.put("fx", hit, noise_hit(rng, 1.2, 200, 3000, 0.1))
    for st, ln, nt in KING_MOTIF[0]:
        mix.put("lead", hit + st * STEP, lead(midi(nt) - 12, ln, vol=0.12))
    mix.put("fx", 3.2, riser(rng, 0.6, 0.08))
    mix.echo("bell", 0.5, 0.4, 0.5)
    mix.echo("lead", STEP * 3, 0.3, 0.3)
    return mix


def king_rage_sting():
    """The king enrages (2.6 s): chains snap, the siren wails, a distorted roar,
    then a dissonant organ cluster and bells clashing a semitone apart."""
    mix = Mix(3.0, wrap=False)
    rng = random.Random(82)
    mix.put("kick", 0.0, kick())
    mix.put("fx", 0.0, noise_hit(rng, 0.6, 400, 9000, 0.2))
    for k in range(3):
        mix.put("chain", 0.05 + 0.1 * k, chains(rng, 0.12))
    mix.put("siren", 0.0, siren(2.4, 0.05))
    roar = synth("C1", 1.3, "saw", detune=(-20, 0, 17), vol=0.5, attack=0.05, decay=0.8, sustain=0.6,
                 release=0.3, cutoff=(900, 300, 0.4), pitch=lambda t: 1 + 0.05 * math.sin(t * 40))
    mix.put("roar", 0.1, [math.tanh(x * 3.0) * 0.3 for x in roar])
    mix.put("door", 0.35, door_slam(rng, 0.7))
    mix.put("organ", 0.35, organ(["C3", "Db3", "E3", "G3", "Bb3"], 2.0, vol=0.045, cutoff=1800))
    mix.put("bell", 0.35, bell("C4", 1.8, vol=0.1))
    mix.put("bell", 0.35, bell("Db4", 1.8, vol=0.08))
    mix.put("kick", 0.35, kick())
    mix.echo("bell", 0.3, 0.35, 0.4)
    return mix


def king_fall_sting():
    """The king falls (3.0 s): chains burst one after another into a rising rush,
    a great hit into the white-out, then the bells ring out over a bright C major."""
    mix = Mix(3.6, wrap=False)
    rng = random.Random(83)
    for k in range(4):
        mix.put("chain", 0.18 * k, chains(rng, 0.13))
        mix.put("chain", 0.18 * k + 0.03, noise_hit(rng, 0.12, 3000, 11000, 0.08))
    mix.put("fx", 0.1, riser(rng, 0.9, 0.12))
    hit = 1.0
    mix.put("kick", hit, kick(1.0))
    mix.put("door", hit, door_slam(rng, 0.9))
    mix.put("fx", hit, noise_hit(rng, 1.6, 2500, 11000, 0.16))
    mix.put("bell", hit, bell("C4", 2.4, vol=0.12))
    mix.put("bell", hit + 0.25, bell("G4", 2.2, vol=0.08))
    mix.put("pad", 1.2, pad_chord(["C3", "G3", "C4", "E4", "G4"], 2.0, cutoff=2200, vol=0.07))
    mix.put("bass", 1.2, synth("C2", 1.8, "saw", detune=(-6, 6), vol=0.3, attack=0.2, decay=1.2,
                               sustain=0.5, release=0.5, cutoff=(1200, 300, 0.3)))
    mix.echo("bell", 0.4, 0.4, 0.5)
    return mix


def rotorick_intro_sting():
    """Rotorick arrives (2 s): the reels spin up and lock, a buzzer, and the
    circus stab in A harmonic minor."""
    mix = Mix(2.6, wrap=False)
    rng = random.Random(84)
    t = 0.0
    gap = 0.09
    notes = ["A4", "C5", "E5", "G#5"]
    i = 0
    while t < 1.2:
        mix.put("arp", t, pluck(notes[i % 4], 3000, vol=0.09))
        mix.put("fx", t, noise_hit(rng, 0.03, 3000, 9000, 0.05))
        t += gap
        gap = max(0.045, gap * 0.9) if t < 0.7 else gap * 1.18
        i += 1
    for k in range(3):
        mix.put("fx", 1.2 + 0.08 * k, noise_hit(rng, 0.05, 800, 6000, 0.12))
    hit = 1.45
    mix.put("buzz", hit, synth("A2", 0.35, "pulse", duty=0.5, vol=0.08, sustain=1.0,
                               cutoff=(2000, 2000, 1.0)))
    mix.put("kick", hit, kick())
    mix.put("pad", hit, pad_chord(["A3", "C4", "E4", "G#4"], 0.6, cutoff=2600, vol=0.08))
    mix.put("bass", hit, bass_note("A1", 4, vol=0.5))
    mix.echo("arp", 0.12, 0.3, 0.3)
    return mix


def main():
    import sys
    os.makedirs(OUT_DIR, exist_ok=True)
    tracks = {"battle_loop.ogg": battle_theme, "victory.ogg": victory_jingle,
              "defeat.ogg": defeat_jingle,
              "boss_loop.ogg": lambda: with_tempo(140, boss_theme),
              "rotorick_loop.ogg": lambda: with_tempo(152, roto_theme),
              "rotorick_error.ogg": lambda: with_tempo(152, lambda: roto_theme("error")),
              "rotorick_jackpot.ogg": lambda: with_tempo(152, lambda: roto_theme("jackpot")),
              "draft_loop.ogg": lambda: with_tempo(100, draft_theme),
              "camp_loop.ogg": lambda: with_tempo(76, camp_theme),
              "king_loop.ogg": lambda: with_tempo(120, king_theme),
              "king_rage.ogg": lambda: with_tempo(120, lambda: king_theme("rage")),
              "king_victory.ogg": king_victory_jingle,
              "king_intro.ogg": lambda: with_tempo(120, king_intro_sting),
              "king_rage_sting.ogg": lambda: with_tempo(120, king_rage_sting),
              "king_fall.ogg": lambda: with_tempo(120, king_fall_sting),
              "rotorick_intro.ogg": lambda: with_tempo(152, rotorick_intro_sting)}
    only = sys.argv[1:]
    for name, render in tracks.items():
        if only and name not in only:
            continue
        path = os.path.join(OUT_DIR, name)
        mix = render()
        mix.write(path)
        print(f"{name}: {mix.n / RATE:.2f}s, {os.path.getsize(path) // 1024} KiB")


if __name__ == "__main__":
    main()
