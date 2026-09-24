#!/usr/bin/env python3
"""Render ALAKAZAR's chiptune BGM to WAV files (standard library only).

The voices imitate a classic 8-bit sound chip: two pulse channels (lead and
arpeggio), a 4-bit stepped triangle for the bass and an LFSR noise channel for
drums. Output is deterministic, so re-running the script reproduces the files
byte for byte.

    python3 tools/generate_bgm.py

Writes into assets/audio/bgm/:
    battle_loop.wav  looping battle theme (a `smpl` chunk marks the loop so
                     Godot's "Detect From WAV" import loops it seamlessly)
    victory.wav      one-shot jingle for SECTOR CLEAR
    defeat.wav       one-shot jingle for EXPEDITION FAILED
"""

import math
import os
import struct
import wave

RATE = 22050
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "bgm")

NOTE_INDEX = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6,
              "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def freq(name):
    """'A4' -> 440.0, 'G#3' -> 207.65."""
    pitch, octave = name[:-1], int(name[-1])
    midi = 12 * (octave + 1) + NOTE_INDEX[pitch]
    return 440.0 * 2 ** ((midi - 69) / 12)


class Track:
    """A mono mix buffer addressed in sequencer steps."""

    def __init__(self, bpm, steps, steps_per_beat=4):
        self.step_len = 60.0 / bpm / steps_per_beat
        self.length = int(round(steps * self.step_len * RATE))
        self.buf = [0.0] * self.length

    def at(self, step):
        return int(round(step * self.step_len * RATE))

    # --- voices -----------------------------------------------------------

    def pulse(self, step, steps, note, duty=0.25, vol=0.5, gate=0.9,
              decay=0.35, vibrato=True, slide_from=None):
        """Pulse-wave note with a stepped (4-bit) volume envelope."""
        start = self.at(step)
        dur = max(1, int((self.at(step + steps) - start) * gate))
        f = freq(note)
        f0 = freq(slide_from) if slide_from else f
        phase = 0.0
        for i in range(dur):
            idx = start + i
            if idx >= self.length:
                break
            t = i / RATE
            cur = f if t > 0.03 else f0 + (f - f0) * (t / 0.03)
            # Delayed vibrato on held notes, like a hand-written chip driver.
            if vibrato and t > 0.18:
                cur *= 2 ** (0.18 * math.sin(2 * math.pi * 6.0 * (t - 0.18)) / 12)
            phase = (phase + cur / RATE) % 1.0
            level = vol * max(0.55, 1.0 - decay * t * 2.2)
            level = round(level * 15) / 15  # 16 hardware volume steps
            fade = min(1.0, i / 40, (dur - i) / 60)  # soften on/off clicks
            self.buf[idx] += ((1.0 if phase < duty else 0.0) - duty) * 2 * level * fade

    def triangle(self, step, steps, note, vol=0.55, gate=0.85):
        """4-bit stepped triangle (32 levels, fixed volume like the NES)."""
        start = self.at(step)
        dur = max(1, int((self.at(step + steps) - start) * gate))
        f = freq(note)
        phase = 0.0
        for i in range(dur):
            idx = start + i
            if idx >= self.length:
                break
            phase = (phase + f / RATE) % 1.0
            tri = 1.0 - 4.0 * abs(phase - 0.5)
            tri = round(tri * 7.5) / 7.5
            fade = min(1.0, i / 30, (dur - i) / 60)
            self.buf[idx] += tri * vol * fade

    def noise(self, step, kind, vol=0.35):
        """LFSR noise drums: 'k' kick, 's' snare, 'h' closed hat, 'o' open hat."""
        start = self.at(step)
        length = {"k": 0.12, "s": 0.16, "h": 0.035, "o": 0.14}[kind]
        rate = {"k": 3000, "s": 9000, "h": 18000, "o": 16000}[kind]
        short = kind in "ho"
        reg, hold, out = 0x7FFF, 0, 1.0
        period = RATE / rate
        n = int(length * RATE)
        for i in range(n):
            idx = start + i
            if idx >= self.length:
                break
            hold += 1
            if hold >= period:
                hold -= period
                tap = 6 if short else 1
                bit = (reg ^ (reg >> tap)) & 1
                reg = (reg >> 1) | (bit << 14)
                out = 1.0 if reg & 1 else -1.0
            env = (1.0 - i / n) ** (2.0 if kind == "k" else 1.3) * min(1.0, i / 24)
            sample = out * vol * env
            if kind == "k":
                # Pitch-dropping square thump under the noise burst.
                t = i / RATE
                kf = 150 * math.exp(-t * 28) + 45
                sample = sample * 0.35 + (1.0 if math.sin(2 * math.pi * kf * t) > 0 else -1.0) * vol * 1.4 * env
            self.buf[idx] += sample

    # --- output ------------------------------------------------------------

    def write(self, path, peak=0.85, loop=False):
        top = max(abs(s) for s in self.buf) or 1.0
        scale = peak / top
        frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * scale)) * 32767))
                          for s in self.buf)
        with wave.open(path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(frames)
        if loop:
            append_loop_chunk(path, self.length)


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


def sequence(track, notes, voice, **kw):
    """notes: iterable of (note or None, steps); None is a rest."""
    step = 0
    for note, steps in notes:
        if note:
            voice(step, steps, note, **kw)
        step += steps
    return step


# ---------------------------------------------------------------------------
# Battle theme: A minor, 150 BPM, 16 bars (A section + B section), loops.
# ---------------------------------------------------------------------------

BATTLE_CHORDS = [
    # A section: tension on the 6x6 board
    ("A", "min"), ("A", "min"), ("F", "maj"), ("G", "maj"),
    ("A", "min"), ("A", "min"), ("F", "maj"), ("E", "maj"),
    # B section: push through the encirclement
    ("D", "min"), ("D", "min"), ("A", "min"), ("A", "min"),
    ("F", "maj"), ("G", "maj"), ("E", "maj"), ("E", "maj"),
]

BATTLE_MELODY = [
    # bar 1-4
    ("A4", 2), ("C5", 2), ("E5", 4), ("D5", 2), ("C5", 2), ("B4", 2), ("C5", 2),
    ("A4", 4), ("E4", 2), ("A4", 2), ("B4", 4), ("C5", 4),
    ("C5", 2), ("A4", 2), ("C5", 2), ("F5", 4), ("E5", 2), ("D5", 2), ("C5", 2),
    ("D5", 6), ("B4", 2), ("G4", 4), (None, 2), ("B4", 2),
    # bar 5-8
    ("A4", 2), ("C5", 2), ("E5", 4), ("A5", 4), ("G5", 2), ("E5", 2),
    ("F5", 2), ("E5", 2), ("D5", 2), ("C5", 2), ("D5", 4), ("E5", 4),
    ("F5", 4), ("E5", 2), ("D5", 2), ("C5", 4), ("A4", 4),
    ("B4", 8), ("G#4", 4), ("E4", 4),
    # bar 9-12
    ("D5", 4), ("F5", 4), ("A5", 6), ("G5", 2),
    ("F5", 2), ("E5", 2), ("D5", 4), ("C5", 2), ("D5", 2), ("F5", 4),
    ("E5", 4), ("C5", 4), ("A4", 6), ("B4", 2),
    ("C5", 2), ("D5", 2), ("E5", 4), ("G5", 4), ("E5", 4),
    # bar 13-16
    ("F5", 6), ("E5", 2), ("D5", 4), ("C5", 4),
    ("D5", 4), ("B4", 4), ("G5", 4), ("F5", 4),
    ("E5", 8), ("D5", 2), ("C5", 2), ("B4", 4),
    ("G#4", 4), ("B4", 4), ("E5", 4), (None, 4),
]

CHORD_TONES = {"min": [0, 3, 7, 12], "maj": [0, 4, 7, 12]}
NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


def transpose(root, octave, semis):
    n = NOTE_INDEX[root] + semis
    return NAMES[n % 12] + str(octave + n // 12)


def battle_theme():
    bars = len(BATTLE_CHORDS)
    track = Track(bpm=150, steps=bars * 16)
    assert sequence(track, BATTLE_MELODY, track.pulse, duty=0.25, vol=0.42) == bars * 16

    for bar, (root, quality) in enumerate(BATTLE_CHORDS):
        base = bar * 16
        tones = CHORD_TONES[quality]
        octave = 3 if NOTE_INDEX[root] >= NOTE_INDEX["F"] else 4
        # Fast 12.5% pulse arpeggio, quieter, sits under the lead.
        for s in range(16):
            note = transpose(root, octave, tones[s % 4])
            track.pulse(base + s, 1, note, duty=0.125, vol=0.16, gate=0.7, vibrato=False)
        # Octave-bouncing triangle bass in eighths.
        bass_oct = 2 if NOTE_INDEX[root] >= NOTE_INDEX["E"] else 3
        for s in range(0, 16, 2):
            jump = 12 if (s // 2) % 2 else 0
            if bar in (7, 15) and s >= 12:
                jump = 7 if s == 12 else 10  # walk-up into the next phrase
            track.triangle(base + s, 2, transpose(root, bass_oct, jump))
        # Drums: kick / snare backbeat with hats; fill on phrase ends.
        for s in range(16):
            if s in (0, 6, 8):
                track.noise(base + s, "k")
            elif s in (4, 12):
                track.noise(base + s, "s", vol=0.3)
            elif bar in (7, 15) and s >= 13:
                track.noise(base + s, "s", vol=0.22)
            elif s % 2 == 0:
                track.noise(base + s, "h", vol=0.12)
            elif s == 15:
                track.noise(base + s, "o", vol=0.1)
    return track


# ---------------------------------------------------------------------------
# Jingles
# ---------------------------------------------------------------------------

def victory_jingle():
    track = Track(bpm=150, steps=36)
    lead = [("A4", 1), ("C#5", 1), ("E5", 1), ("A5", 3),
            ("G5", 2), ("A5", 2), ("B5", 2), ("C#6", 12), (None, 12)]
    harm = [("E4", 1), ("A4", 1), ("C#5", 1), ("E5", 3),
            ("D5", 2), ("E5", 2), ("F#5", 2), ("A5", 12), (None, 12)]
    sequence(track, lead, track.pulse, duty=0.5, vol=0.4, gate=0.95)
    sequence(track, harm, track.pulse, duty=0.25, vol=0.22, gate=0.95, vibrato=False)
    bass = [("A2", 3), ("A2", 3), ("G2", 2), ("A2", 2), ("B2", 2), ("A2", 12), (None, 12)]
    sequence(track, bass, track.triangle, gate=0.95)
    for s, kind in [(0, "k"), (3, "k"), (6, "s"), (8, "s"), (10, "s"), (12, "k")]:
        track.noise(s, kind, vol=0.3)
    track.noise(12, "o", vol=0.18)
    return track


def defeat_jingle():
    track = Track(bpm=96, steps=32)
    lead = [("E5", 4), ("D#5", 4), ("D5", 4), ("C#5", 4), ("C5", 12), (None, 4)]
    sequence(track, lead, track.pulse, duty=0.5, vol=0.38, gate=0.95, decay=0.25)
    harm = [("C5", 4), ("B4", 4), ("A#4", 4), ("A4", 4), ("A4", 12), (None, 4)]
    sequence(track, harm, track.pulse, duty=0.25, vol=0.18, gate=0.95, vibrato=False)
    bass = [("A2", 8), ("F2", 8), ("A2", 12), (None, 4)]
    sequence(track, bass, track.triangle, gate=0.95)
    track.noise(16, "o", vol=0.12)
    return track


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
