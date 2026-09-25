"""BGM synthesis and the final audio mix.

The soundtrack is generated, not sampled, so every episode is license-free:
a slow D-minor pad, a low drone, sparse FM bells, a chime on each stop, a
soft whoosh when the globe travels, and (for the kanji stop) plucked notes
in a Japanese yo-scale. Narration is laid on top and the music ducks under it.
"""

import subprocess

import numpy as np

RATE = 48000
RNG_SEED = 7
SFX_GAIN = 0.45  # hits sit clearly under the narration


def _ffmpeg():
    import imageio_ffmpeg

    return imageio_ffmpeg.get_ffmpeg_exe()


def decode(path):
    """Decode any audio file to mono float32 at RATE."""
    raw = subprocess.run(
        [_ffmpeg(), "-v", "error", "-i", path, "-f", "f32le", "-ac", "1", "-ar", str(RATE), "-"],
        check=True, capture_output=True,
    ).stdout
    return np.frombuffer(raw, dtype="<f4").astype(np.float64)


def midi(note):
    names = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    base = names[note[0]]
    rest = note[1:]
    if rest.startswith("b"):
        base -= 1
        rest = rest[1:]
    elif rest.startswith("#"):
        base += 1
        rest = rest[1:]
    return 12 * (int(rest) + 1) + base


def hz(note):
    return 440.0 * 2 ** ((midi(note) - 69) / 12)


def _env(n, attack, release):
    """Linear attack/release envelope over n samples."""
    t = np.arange(n) / RATE
    dur = n / RATE
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    r = np.clip((dur - t) / max(release, 1e-4), 0, 1)
    shape = np.minimum(a, r)
    return shape * shape * (3 - 2 * shape)  # smoothstep


def _pad_note(freq, n, phase_rng):
    t = np.arange(n) / RATE
    out = np.zeros(n)
    # Two slightly detuned voices, a few soft harmonics each: warm, no filter needed.
    for detune in (-0.0025, 0.0025):
        f = freq * (1 + detune)
        ph = phase_rng.uniform(0, 2 * np.pi)
        for h, amp in ((1, 1.0), (2, 0.32), (3, 0.14), (4, 0.06)):
            out += amp * np.sin(2 * np.pi * f * h * t + ph * h)
    trem = 1 + 0.12 * np.sin(2 * np.pi * phase_rng.uniform(0.07, 0.13) * t + phase_rng.uniform(0, 6))
    return out * trem


def _bell(freq, dur=4.0):
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    index = 2.4 * np.exp(-t * 3.0)
    mod = np.sin(2 * np.pi * freq * 3.5 * t)
    car = np.sin(2 * np.pi * freq * t + index * mod)
    car += 0.35 * np.sin(2 * np.pi * freq * 2.01 * t) * np.exp(-t * 2.2)
    attack = np.clip(t / 0.004, 0, 1)
    return car * attack * np.exp(-t * 1.25)


def _pluck(freq, dur=2.8):
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    out = np.zeros(n)
    for h in range(1, 9):
        out += np.sin(2 * np.pi * freq * h * t * (1 + 0.0006 * h * h)) * np.exp(-t * (1.6 + 1.3 * h)) / h
    # A little pitch "bend-in" gives the koto-like attack.
    attack = np.clip(t / 0.003, 0, 1)
    return out * attack


def _whoosh(dur, rng):
    n = int(dur * RATE)
    noise = rng.standard_normal(n)
    spec = np.fft.rfft(noise)
    freqs = np.fft.rfftfreq(n, 1 / RATE)
    spec *= np.exp(-((np.log(freqs + 1) - np.log(900)) ** 2) / 1.2)  # soft band around 900 Hz
    band = np.fft.irfft(spec, n)
    band /= np.max(np.abs(band)) + 1e-9
    t = np.linspace(0, 1, n)
    return band * np.sin(np.pi * t) ** 2


def _reverb(signal, seconds=3.2, rng=None):
    rng = rng or np.random.default_rng(RNG_SEED)
    n_ir = int(seconds * RATE)
    t = np.arange(n_ir) / RATE
    ir = rng.standard_normal(n_ir) * np.exp(-t * 6.9 / seconds)
    ir[: int(0.012 * RATE)] = 0  # pre-delay
    ir /= np.sqrt(np.sum(ir**2))
    n = len(signal) + n_ir
    size = 1 << (n - 1).bit_length()
    wet = np.fft.irfft(np.fft.rfft(signal, size) * np.fft.rfft(ir, size), size)[: len(signal)]
    return wet


def _add(track, clip, start_s, gain=1.0):
    i = int(start_s * RATE)
    if i >= len(track):
        return
    j = min(len(track), i + len(clip))
    track[i:j] += clip[: j - i] * gain


def _boom(rng):
    """Cinematic hit: pitch-dropping sub, a noise crack and a short tail."""
    n = int(1.6 * RATE)
    t = np.arange(n) / RATE
    freq = 38 + 90 * np.exp(-t * 9)
    sub = np.sin(2 * np.pi * np.cumsum(freq) / RATE) * np.exp(-t * 2.6)
    crack = rng.standard_normal(n) * np.exp(-t * 38)
    return np.tanh(1.8 * (sub * 0.9 + crack * 0.35))


def _thud(rng):
    """Hanko stamp: dull low knock plus paper slap."""
    n = int(0.7 * RATE)
    t = np.arange(n) / RATE
    body = np.sin(2 * np.pi * (70 + 60 * np.exp(-t * 30)) * t) * np.exp(-t * 11)
    slap = rng.standard_normal(n) * np.exp(-t * 70)
    return body + 0.45 * slap


def _pop():
    n = int(0.18 * RATE)
    t = np.arange(n) / RATE
    return np.sin(2 * np.pi * (1300 - 700 * t / 0.18) * t) * np.exp(-t * 30)


def _shine():
    out = np.zeros(int(3.2 * RATE))
    for i, note in enumerate(["D6", "A6", "D7", "F#7"]):
        clip = _bell(hz(note), 2.8) * (0.8 - 0.12 * i)
        s = int(i * 0.045 * RATE)
        out[s:s + len(clip)] += clip[: len(out) - s]
    return out


def _glitch(dur, rng):
    n = int(dur * RATE)
    out = np.zeros(n)
    pos = 0
    while pos < n:
        seg = int(rng.uniform(0.04, 0.11) * RATE)
        t = np.arange(min(seg, n - pos)) / RATE
        kind = rng.integers(3)
        if kind == 0:
            chunk = np.sign(np.sin(2 * np.pi * rng.uniform(200, 900) * t)) * 0.35
        elif kind == 1:
            chunk = rng.standard_normal(len(t)) * 0.3
        else:
            chunk = np.sin(2 * np.pi * rng.uniform(1500, 3000) * t) * 0.25
        out[pos:pos + len(t)] = chunk * np.hanning(len(t))
        pos += seg
    return out


def _ticks(dur):
    """Accelerating clock ticks for rolling counters."""
    n = int(dur * RATE)
    out = np.zeros(n)
    tick = _pop()[: int(0.03 * RATE)] * 0.6
    t = 0.0
    step = 0.09
    while t < dur - 0.03:
        i = int(t * RATE)
        out[i:i + len(tick)] += tick[: n - i]
        t += step
        step = max(0.035, step * 0.9)
    return out


def sfx_track(duration, fx):
    rng = np.random.default_rng(RNG_SEED + 1)
    track = np.zeros(int(duration * RATE))
    for cue in fx:
        kind = cue.get("sfx")
        if kind == "boom":
            _add(track, _boom(rng), cue["t"], 0.36)
        elif kind == "thud":
            _add(track, _thud(rng), cue["t"], 0.22)
        elif kind == "pop":
            _add(track, _pop(), cue["t"], 0.16)
        elif kind == "shine":
            _add(track, _shine(), cue["t"], 0.12)
        elif kind == "whoosh":
            _add(track, _whoosh(0.5, rng), cue["t"] - 0.1, 0.35)
        elif kind == "glitch":
            _add(track, _glitch(max(0.3, cue["dur"]), rng), cue["t"], 0.13)
        elif kind == "ticks":
            _add(track, _ticks(max(0.3, cue["dur"])), cue["t"], 0.2)
    return track


CHORDS = [
    ["D3", "A3", "C4", "E4", "F4"],  # Dm9
    ["Bb2", "F3", "A3", "D4"],  # Bbmaj7
    ["F2", "C3", "A3", "E4"],  # Fmaj7
    ["G2", "D3", "F3", "A3", "Bb3"],  # Gm9
]
BELL_NOTES = ["D5", "F5", "G5", "A5", "C6", "D6"]
YO_SCALE = ["D4", "E4", "G4", "A4", "C5", "D5", "E5"]


def music(duration, scenes):
    """Render the BGM (without narration) for the episode timeline."""
    rng = np.random.default_rng(RNG_SEED)
    n = int(duration * RATE)
    left = np.zeros(n)
    right = np.zeros(n)
    dry = np.zeros(n)

    # Pad: 8-second chords with 2-second crossfades; the final bars return to Dm.
    chord_len = 8.0
    k = 0
    start = 0.0
    while start < duration:
        chord = CHORDS[k % len(CHORDS)]
        if start + chord_len >= duration - 4:
            chord = CHORDS[0]
        seg = min(chord_len + 2.0, duration - start + 0.5)
        m = int(seg * RATE)
        tone = sum(_pad_note(hz(note), m, rng) / (1 + 0.15 * i) for i, note in enumerate(chord))
        tone *= _env(m, 2.0, 2.0) * 0.05
        _add(dry, tone, start)
        start += chord_len
        k += 1

    # Low drone that swells in over the first seconds.
    t = np.arange(n) / RATE
    drone = (np.sin(2 * np.pi * hz("D2") * t) + 0.3 * np.sin(2 * np.pi * hz("A2") * t)) * 0.05
    drone *= np.clip(t / 4.0, 0, 1) * np.clip((duration - t) / 3.0, 0, 1)
    dry += drone

    bells = np.zeros(n)
    plucks = np.zeros(n)
    sfx = np.zeros(n)

    kanji = [s for s in scenes if s["id"] == "kanji"]
    kanji_range = (kanji[0]["start"], kanji[0]["end"]) if kanji else (-1, -1)

    # Sparse bells, avoiding the kanji stop where plucks take over.
    tb = 1.5
    while tb < duration - 3:
        if not (kanji_range[0] - 0.5 < tb < kanji_range[1]):
            note = BELL_NOTES[rng.integers(len(BELL_NOTES))]
            _add(bells, _bell(hz(note)), tb, 0.05 * rng.uniform(0.6, 1.0))
        tb += rng.uniform(1.8, 3.4)

    if kanji:
        tp = kanji_range[0] + 0.2
        while tp < kanji_range[1] - 0.5:
            note = YO_SCALE[rng.integers(len(YO_SCALE))]
            _add(plucks, _pluck(hz(note)), tp, 0.11 * rng.uniform(0.7, 1.0))
            tp += rng.choice([0.6, 0.9, 1.2, 1.8])

    for s in scenes:
        if s["id"] != "intro":
            _add(sfx, _whoosh(1.6, rng), s["start"] - 0.2, 0.03)
            chime = _bell(hz("A5"), 5) + 0.7 * _bell(hz("D6"), 5)
            _add(bells, chime, s["start"] + 1.1, 0.06)

    wet_src = dry + bells + plucks
    wet = _reverb(wet_src, rng=rng)
    mono = dry * 0.8 + wet * 0.55 + sfx
    # Slow auto-pan on the bells/plucks for width.
    pan = 0.5 + 0.35 * np.sin(2 * np.pi * 0.05 * t)
    left = mono + (bells + plucks) * 0.5 * (1 - pan)
    right = mono + (bells + plucks) * 0.5 * pan
    fade = np.clip((duration - t) / 2.5, 0, 1) * np.clip(t / 1.0, 0, 1)
    return np.stack([left * fade, right * fade], axis=1)


def _smooth_env(x, attack=0.03, release=0.45):
    """Peak follower used to duck the music under the narration."""
    hop = 480
    frames = np.abs(x[: len(x) // hop * hop]).reshape(-1, hop).max(axis=1)
    env = np.zeros_like(frames)
    a = np.exp(-hop / (attack * RATE))
    r = np.exp(-hop / (release * RATE))
    level = 0.0
    for i, v in enumerate(frames):
        coef = a if v > level else r
        level = coef * level + (1 - coef) * v
        env[i] = level
    env = np.repeat(env, hop)
    return np.pad(env, (0, len(x) - len(env)), mode="edge")


def mix(duration, voice_clips, scenes, fx=()):
    """voice_clips: list of (start_seconds, wav_path). Returns stereo float array."""
    n = int(duration * RATE)
    voice = np.zeros(n)
    for start, path in voice_clips:
        _add(voice, decode(path), start)
    peak = np.max(np.abs(voice)) or 1.0
    voice *= 0.5 / peak  # headroom before the limiter
    # Normalise the narration so it sits around -18 dBFS RMS while speaking.
    speaking = np.abs(voice) > 0.01
    rms = np.sqrt(np.mean(voice[speaking] ** 2)) if speaking.any() else 1.0
    voice *= 0.12 / rms

    bgm = music(duration, scenes)
    bgm /= np.max(np.abs(bgm)) + 1e-9
    duck = 1 - 0.55 * np.clip(_smooth_env(voice) / 0.08, 0, 1)
    hits = sfx_track(duration, fx) * SFX_GAIN
    out = bgm * 0.32 * duck[:, None] + (voice + hits)[:, None]
    return np.tanh(out * 1.1) / np.tanh(1.1)  # gentle limiter


def write_wav(path, stereo):
    import wave

    pcm = (np.clip(stereo, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())
