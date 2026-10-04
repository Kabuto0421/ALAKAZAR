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

# (song start, song end, clip, seconds into the clip, zoom)  -- clip None = black.
# Every cut starts on a drum or kick (cues.json): 1.2 s apart in the fanfare, 1.034 s in the war
# section, 0.517 s from the cyber part on. zoom 1.5 / 2 crops into the board (the boards are small).
CUTS = [
    (0.00, 2.40, "art_intro", 0.0, 1),
    # fanfare: one cut per timpani/bagpipe beat
    (2.40, 3.60, "art_p_fortress", 0.0, 1),
    (3.60, 4.80, "art_p_rook", 0.0, 1),
    (4.80, 6.00, "art_p_rotorick", 0.0, 1),
    (6.00, 7.20, "art_p_shark", 0.0, 1),
    (7.20, 8.40, "art_p_hero", 0.0, 1),
    (8.40, 9.60, "art_p_king", 0.0, 1),
    (9.60, 12.00, "art_logo", 0.0, 1),
    (12.00, 17.172, "art_fairies", 0.0, 1),
    # war: one thing per drum; no fairy is shown twice (the guardian scene is one long cut)
    (17.172, 18.207, "basic", 5.30, 1.25, (864, 620)),
    (18.207, 19.241, "hammer2", 1.10, 1.25, (864, 620)),
    (19.241, 20.276, "daggers", 1.20, 1.25, (864, 620)),
    (20.276, 21.310, "daggers", 3.75, 1.25, (864, 620)),
    (21.310, 22.345, "circle", 0.70, 1.25, (864, 620)),
    (22.345, 23.379, "circle", 2.40, 1.25, (864, 620)),
    (23.379, 24.414, "circle", 4.15, 1.25, (864, 620)),
    (24.414, 26.483, "guardian_boss", 6.10, 2.0, (640, 540)),
    # cyber: every kick is a cut
    (26.483, 27.000, "rotorick", 1.80, 1),
    (27.000, 27.517, "rotorick", 2.40, 1),
    (27.517, 28.034, "rotorick", 4.20, 1),
    (28.034, 28.552, "rotorick", 5.40, 1),
    (28.552, 29.069, "shark", 3.00, 1),
    (29.069, 29.586, "shark", 6.00, 1),
    (29.586, 30.103, "shark", 7.30, 1),
    (30.103, 30.621, "shark", 8.10, 1),
    (30.621, 31.138, "king", 1.20, 1),
    (31.138, 31.655, "king", 2.40, 1),
    (31.655, 32.172, "king", 5.40, 1),
    (32.172, 32.690, "king", 6.20, 1),
    # build-up: the new faces, four to the bar (no names)
    (32.690, 33.207, "art_p_jester", 0.0, 1),
    (33.207, 33.724, "art_p_dragon", 0.0, 1),
    (33.724, 34.241, "art_p_cross", 0.0, 1),
    (34.241, 34.759, "art_p_rook", 0.0, 1),
    # climax and finish: the fairies, each once
    (34.759, 35.793, "meteor", 1.40, 1.5),
    (35.793, 36.828, "chain", 1.50, 1.5),
    (36.828, 37.862, "f_axe_spirit", 1.30, 1.5),
    (37.862, 38.897, "f_shadow_stitch", 1.50, 1.5),
    (38.897, 39.931, "f_blessing_fairy", 2.30, 1.5),
    (39.931, 40.448, "glutton", 2.30, 1.5),
    (40.448, 40.966, "art_p_king", 0.25, 1),
    (40.966, 41.85, None, 0.0, 1),
    # fusion: the finished title screen, with weapon fights cut in on the kicks
    (41.850, 42.884, "title_fusion", 0.15, 1),
    (42.884, 43.918, "hammer2", 1.40, 1.25, (864, 620)),
    (43.918, 44.952, "title_fusion", 2.10, 1.6, (1450, 800)),
    (44.952, 45.986, "daggers", 3.75, 1.25, (864, 620)),
    (45.986, 47.020, "title_fusion", 4.20, 1.6, (330, 520)),
    (47.020, 48.054, "circle", 4.15, 1.25, (864, 620)),
    (48.054, 49.088, "title_fusion", 6.20, 1.6, (860, 200)),
    (49.088, 50.130, "basic", 5.30, 1.25, (864, 620)),
    (50.130, SONG_LENGTH, "title_fusion", 8.28, 1),
]

# Where the kicks fall (start, end, period) for the punch (a flash and a push-in) on every beat,
# and the big hits of the song (the cues' "hit" events).
BEATS = [(2.4, 9.6, 1.2), (17.172, 26.483, 1.0345), (26.483, 41.0, 0.5172), (41.85, 50.2, 0.5172)]
HITS = [9.6, 17.172, 26.483, 34.759, 41.85]

SHOTS = (["art_intro", "art_logo", "art_fairies", "chain", "rotorick", "shark", "king", "meteor", "basic", "circle", "daggers", "hammer2", "glutton", "guardian_boss", "f_axe_spirit", "f_shadow_stitch", "f_blessing_fairy", "title_fusion"]
         + ["art_p_" + n for n in ("fortress", "rook", "king", "rotorick", "shark", "hero")]
         + ["art_p_" + n for n in ("jester", "dragon", "cross", "rook")])


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


def punch_filter():
    """A flash and a push-in on every kick, bigger on the big hits."""
    bright, zoom = [], []
    for a, b, p in BEATS:
        phase = f"mod(t-{a}\\,{p})"
        bright.append(f"between(t\\,{a}\\,{b})*0.16*exp(-{phase}/0.06)")
        zoom.append(f"between(t\\,{a}\\,{b})*0.045*exp(-{phase}/0.09)")
    for h in HITS:
        bright.append(f"between(t\\,{h}\\,{h + 0.6})*0.35*exp(-(t-{h})/0.10)")
        zoom.append(f"between(t\\,{h}\\,{h + 0.6})*0.07*exp(-(t-{h})/0.14)")
    b = "+".join(bright)
    z = "+".join(zoom)
    return (f"eq=brightness='{b}':eval=frame,"
            f"scale=w='1728*(1+{z})':h='1080*(1+{z})':eval=frame:flags=bilinear,crop=1728:1080")


def assemble(out="build/pv/ALAKAZAR_PV.mp4"):
    inputs, parts = [], []
    for n, cut in enumerate(CUTS):
        t0, t1, clip, src, zoom = cut[:5]
        center = cut[5] if len(cut) > 5 else None
        # whole frames on the song's own 30 fps grid, so rounding never adds up
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
    graph = ";".join(parts + [concat, f"[cat]{punch_filter()},pad=1920:1080:96:0:black,format=yuv420p[v]"])
    cmd = [FF, "-v", "error", "-y"] + inputs + ["-filter_complex", graph, "-map", "[v]", "-map", f"{audio}:a",
           "-t", f"{SONG_LENGTH:.3f}", "-c:v", "libx264", "-crf", "17", "-preset", "medium", "-r", str(FPS),
           "-c:a", "aac", "-b:a", "192k", out]
    subprocess.run(cmd, check=True)
    print("wrote", out)


if __name__ == "__main__":
    if "--record" in sys.argv:
        record()
    assemble()
