#!/usr/bin/env python3
"""Cuts the recorded shots (build/pv/*.avi, see pv_shot.gd) to the title theme and writes
build/pv/ALAKAZAR_PV.mp4 (1920x1080, 30 fps, with the song).

    python3 tools/pv/make_pv.py            # assemble from the clips already recorded
    python3 tools/pv/make_pv.py --record   # (re)record every clip first (needs GODOT=<path to godot>)

The cut list is in song time (seconds into assets/audio/bgm/title_theme.ogg); each cut takes
`length` seconds of a clip from `src` seconds in. The sections of the song and where the big hits
fall (9.6 / 17.2 / 26.5 / 34.8 / 41.9 s) are in assets/audio/bgm/title_theme.cues.json.
"""
import os
import subprocess
import sys

import imageio_ffmpeg

FF = imageio_ffmpeg.get_ffmpeg_exe()
CLIPS = "build/pv"
SONG = "assets/audio/bgm/title_theme.ogg"
SONG_LENGTH = 58.402
FPS = 30
# The title-screen clip starts with a black fade-in before song time 41.85: skip it.
FUSION_LEAD = 0.15

# Every cut is one moment of impact: the recorded clips are scanned for their sudden changes (a slash,
# a flash, a chain pop), and each cut starts on one of them, landing on a drum, a kick, a melody note or an
# eighth note of the song (cues.json). Board shots punch in on where the change happened.
import json as _json

W_, H_ = 192, 120
_peaks_cache = {}


def peaks_of(clip, limit=16):
    """[(time, cx, cy, strength)] of a clip's sudden changes (cx, cy in the 1728x1080 frame)."""
    if clip in _peaks_cache:
        return _peaks_cache[clip]
    import numpy as np
    raw = subprocess.run([FF, "-v", "error", "-i", f"{CLIPS}/{clip}.avi", "-vf", f"fps={FPS},scale={W_}:{H_}",
                          "-f", "rawvideo", "-pix_fmt", "gray", "-"], capture_output=True).stdout
    a = np.frombuffer(raw, np.uint8).reshape(-1, H_, W_).astype(float)
    diff = np.abs(np.diff(a, axis=0))
    energy = diff.mean(axis=(1, 2))
    mean = energy.mean()
    found = []
    for k in range(1, len(energy) - 1):
        t = (k + 1) / FPS
        if t < 0.9 or energy[k] < energy[k - 1] or energy[k] < energy[k + 1] or energy[k] < mean * 1.8:
            continue
        d = diff[k]
        w = np.maximum(d - d.max() * 0.35, 0)
        if w.sum() <= 0:
            continue
        ys, xs = np.mgrid[0:H_, 0:W_]
        cx = float((w * xs).sum() / w.sum()) / W_ * 1728
        cy = float((w * ys).sum() / w.sum()) / H_ * 1080
        found.append((t, cx, cy, float(energy[k])))
    # keep the strongest, at least a tenth of a second apart
    found.sort(key=lambda f: -f[3])
    kept = []
    for f in found:
        if all(abs(f[0] - g[0]) >= 0.12 for g in kept):
            kept.append(f)
        if len(kept) >= limit:
            break
    kept.sort()
    _peaks_cache[clip] = kept
    return kept


# After this many seconds a clip shows the defeat panel (or has nothing left to see): no cuts past it.
LAST_MOMENT = {"basic": 8.3, "glutton": 2.9, "swarm": 6.0, "daggers": 4.6, "hammer2": 2.5, "circle": 5.2, "meteor": 3.6, "chain": 3.4, "fairies": 24.0}
BOARD_CLIPS = ("basic", "hammer2", "daggers", "circle", "chain", "meteor", "swarm", "glutton", "fairies")
_taken = {}
_last_t = {}


def moment(clip, step):
    """The next moment of `clip` (cycling): (src, zoom, center) for a cut."""
    ps = [p for p in peaks_of(clip) if p[0] <= LAST_MOMENT.get(clip, 99)] or peaks_of(clip)[:1]
    n = _taken.get(clip, 0)
    _taken[clip] = n + 1
    t, cx, cy, _ = ps[n % len(ps)]
    _last_t[clip] = LAST_MOMENT.get(clip, 99)
    zoom = (2.2 if n % 2 == 0 else 1.5) if clip in BOARD_CLIPS else (1.0 if n % 2 == 0 else 1.7)
    return max(0.0, t - 0.04), zoom, (cx, cy)


def run_cuts(times, end, cycle, extra=None):
    """Cuts starting at each time in `times` (the last one runs to `end`), clips taken in turn from `cycle`."""
    out = []
    for n, t0 in enumerate(times):
        t1 = times[n + 1] if n + 1 < len(times) else end
        clip = cycle[n % len(cycle)]
        src, zoom, center = moment(clip, n)
        # never run past the clip's last good moment (the defeat panel follows some of them)
        src = min(src, max(0.0, LAST_MOMENT.get(clip, 99) - (t1 - t0)))
        out.append((t0, t1, clip, src, zoom, center))
    return out


def eighths(a, b, step=0.2586):
    out, t = [], a
    while t < b - 0.05:
        out.append(round(t, 3))
        t += step
    return out


def build_cuts():
    cues = _json.load(open("assets/audio/bgm/title_theme.cues.json"))["events"]
    notes = [e[0] for e in cues["note"] if 2.3 < e[0] < 9.5]
    drums = [e[0] for e in cues["drum"] if 17.1 < e[0] < 26.4]
    cuts = [(0.0, 2.4, "art_intro", 0.0, 1, None)]
    # fanfare: a cut on every melody note of the pipes (the king last, right before the logo)
    portraits = ["art_p_fortress", "art_p_rook", "art_p_rotorick", "art_p_shark", "art_p_exec", "art_p_archer", "art_p_hero", "art_p_king"]
    zooms = [1.0, 1.6]
    for n, t0 in enumerate(notes):
        t1 = notes[n + 1] if n + 1 < len(notes) else 9.6
        k = min(n * len(portraits) // len(notes), len(portraits) - 1)
        first = n == 0 or (n * len(portraits) // len(notes)) != ((n - 1) * len(portraits) // len(notes))
        cuts.append((t0, t1, portraits[k], 0.0, 1.0 if first else 1.7, (864, 470)))
    cuts.append((9.6, 12.0, "art_logo", 0.0, 1, None))
    cuts.append((12.0, 17.172, "art_fairies", 0.0, 1, None))
    # war: a cut on every drum
    war_cycle = ["basic", "basic", "hammer2", "daggers", "daggers", "circle", "circle", "chain", "meteor", "chain", "meteor", "chain", "swarm", "swarm", "glutton", "basic", "hammer2", "daggers"]
    cuts += run_cuts([17.172] + [d for d in drums if d > 17.2], 26.483, war_cycle)
    # cyber: an eighth note at a time
    cyber_cycle = ["rotorick", "shark", "king", "chain", "circle", "daggers", "meteor", "hammer2", "swarm", "glutton", "fairies", "basic"]
    cuts += run_cuts(eighths(26.483, 32.69), 32.69, cyber_cycle)
    # build-up: the new faces
    faces = ["art_pn_jester", "art_pn_dragon", "art_pn_cross", "art_pn_rook"]
    bu = eighths(32.69, 34.759)
    for n, t0 in enumerate(bu):
        t1 = bu[n + 1] if n + 1 < len(bu) else 34.759
        cuts.append((t0, t1, faces[(n // 2) % 4], 0.0, 1.0 if n % 2 == 0 else 1.8, (864, 470)))
    # climax, finish
    climax_cycle = ["circle", "chain", "meteor", "daggers", "hammer2", "swarm", "glutton", "rotorick"]
    cuts += run_cuts(eighths(34.759, 36.828), 36.828, climax_cycle)
    finish_cycle = ["fairies", "chain", "glutton", "circle", "hammer2", "swarm", "daggers", "meteor", "shark", "king", "rotorick", "basic"]
    cuts += run_cuts(eighths(36.828, 40.966), 40.966, finish_cycle)
    cuts.append((40.966, 41.85, None, 0.0, 1, None))
    # fusion: the finished title screen, a different part of it on every kick
    spots = [(860, 150), (640, 560), (620, 780), (1500, 600), (1560, 930), (1290, 700), (300, 480), (1330, 940), (860, 150), (1450, 780), (440, 760), (1600, 520), (700, 420), (1200, 760), (330, 800), (860, 600)]
    kicks = [e[0] for e in cues["kick"] if 41.8 < e[0] < 50.2]
    for n, t0 in enumerate(kicks):
        t1 = kicks[n + 1] if n + 1 < len(kicks) else 50.13
        sx, sy = spots[n % len(spots)]
        cuts.append((t0, t1, "title_fusion", t0 - 41.85 + FUSION_LEAD, 2.6, (sx, sy)))
    cuts.append((50.13, SONG_LENGTH, "title_fusion", 50.13 - 41.85 + FUSION_LEAD, 1, None))
    return cuts


# The big hits of the song (the cues' "hit" events): a stronger punch. Every other cut start gets a
# normal one, so each shake of the screen is a new picture; the title screen at the end keeps its
# own kicks (BEATS).
HITS = [9.6, 17.172, 26.483, 34.759, 41.85]
BEATS = []
NO_PUNCH = ("art_intro", "art_fairies")

SHOTS = (["art_intro", "art_logo", "art_fairies", "chain", "rotorick", "shark", "king", "meteor", "basic", "circle", "daggers", "hammer2", "swarm", "glutton", "fairies", "title_fusion"]
         + ["art_p_" + n for n in ("fortress", "prison", "king", "rotorick", "shark", "hero")]
         + ["art_pn_" + n for n in ("jester", "dragon", "cross", "rook")])


def record():
    godot = os.environ.get("GODOT", "godot")
    os.makedirs(CLIPS, exist_ok=True)
    for shot in SHOTS:
        out = f"{CLIPS}/{shot}.avi"
        subprocess.run(["xvfb-run", "-a", godot, "--rendering-driver", "opengl3", "--path", ".", "--write-movie", out,
                        "--fixed-fps", str(FPS), "--resolution", "1728x1080", "--script", "res://tools/pv/pv_shot.gd", "--", shot],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print("recorded", shot)


def crop_for(zoom, center=None):
    if zoom == 1:
        return ""
    w, h = int(1728 / zoom) // 2 * 2, int(1080 / zoom) // 2 * 2
    cx, cy = center if center is not None else (864, 552)
    x = int(min(max(cx - w / 2, 0), 1728 - w))
    y = int(min(max(cy - h / 2, 0), 1080 - h))
    return f"crop={w}:{h}:{x}:{y},"


def punch_filter(cuts):
    """A flash and a push-in at the start of every cut (bigger on the big hits)."""
    bright, zoom = [], []
    starts = [t0 for (t0, t1, clip, src, z, c) in cuts if clip is not None and clip not in NO_PUNCH and t0 > 0.1]
    for a in starts:
        big = any(abs(a - h) < 0.01 for h in HITS)
        bright.append(f"between(t\\,{a:.3f}\\,{a + 0.4:.3f})*{0.34 if big else 0.16}*exp(-max(t-{a:.3f}\\,0)/{0.10 if big else 0.06})")
        zoom.append(f"between(t\\,{a:.3f}\\,{a + 0.5:.3f})*{0.07 if big else 0.045}*exp(-max(t-{a:.3f}\\,0)/{0.14 if big else 0.09})")
    for a, b, p in BEATS:
        phase = f"mod(t-{a}\\,{p})"
        bright.append(f"between(t\\,{a}\\,{b})*0.16*exp(-{phase}/0.06)")
        zoom.append(f"between(t\\,{a}\\,{b})*0.045*exp(-{phase}/0.09)")
    b = "+".join(bright)
    z = "+".join(zoom)
    return (f"eq=brightness='{b}':eval=frame,"
            f"scale=w='1728*(1+{z})':h='1080*(1+{z})':eval=frame:flags=bilinear,crop=1728:1080")


def assemble(out="build/pv/ALAKAZAR_PV.mp4"):
    inputs, parts = [], []
    CUTS = build_cuts()
    # Every cut is cut to a whole number of frames from the song's own frame grid, so rounding never
    # adds up (a cut that starts at song time t starts on frame round(t * 30), whatever came before).
    for n, (t0, t1, clip, src, zoom, center) in enumerate(CUTS):
        frames = max(1, round(t1 * FPS) - round(t0 * FPS))
        if clip is None:
            inputs += ["-f", "lavfi", "-t", f"{frames / FPS + 0.5:.3f}", "-i", f"color=c=black:s=1728x1080:r={FPS}"]
            parts.append(f"[{n}:v]fps={FPS},trim=end_frame={frames},setpts=PTS-STARTPTS,setsar=1[v{n}]")
        else:
            inputs += ["-ss", f"{src:.3f}", "-t", f"{frames / FPS + 0.5:.3f}", "-i", f"{CLIPS}/{clip}.avi"]
            parts.append(f"[{n}:v]fps={FPS},trim=end_frame={frames},setpts=PTS-STARTPTS,{crop_for(zoom, center)}scale=1728:1080:flags=neighbor,setsar=1[v{n}]")
    inputs += ["-i", SONG]
    audio = len(CUTS)
    concat = "".join(f"[v{n}]" for n in range(len(CUTS))) + f"concat=n={len(CUTS)}:v=1:a=0[cat]"
    graph = ";".join(parts + [concat, f"[cat]{punch_filter(CUTS)},pad=1920:1080:96:0:black,format=yuv420p[v]"])
    cmd = [FF, "-v", "error", "-y"] + inputs + ["-filter_complex", graph, "-map", "[v]", "-map", f"{audio}:a",
           "-t", f"{SONG_LENGTH:.3f}", "-c:v", "libx264", "-crf", "17", "-preset", "medium", "-r", str(FPS),
           "-c:a", "aac", "-b:a", "192k", out]
    subprocess.run(cmd, check=True)
    print("wrote", out)


if __name__ == "__main__":
    if "--record" in sys.argv:
        record()
    assemble()
