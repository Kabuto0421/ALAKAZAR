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
    (3.60, 4.80, "art_p_prison", 0.0, 1),
    (4.80, 6.00, "art_p_king", 0.0, 1),
    (6.00, 7.20, "art_p_rotorick", 0.0, 1),
    (7.20, 8.40, "art_p_shark", 0.0, 1),
    (8.40, 9.60, "art_p_hero", 0.0, 1),
    (9.60, 12.00, "art_logo", 0.0, 1),
    (12.00, 17.172, "art_fairies", 0.0, 1),
    # war: the plainest weapons first, then the hammer, the cross daggers, the magic circle, the swarm
    (17.172, 18.207, "basic", 1.30, 2),
    (18.207, 19.241, "basic", 5.30, 2),
    (19.241, 20.276, "basic", 6.30, 2),
    (20.276, 21.310, "hammer2", 1.40, 1.5),
    (21.310, 22.345, "daggers", 3.40, 1.5),
    (22.345, 23.379, "circle", 1.00, 1.5),
    (23.379, 24.414, "circle", 2.80, 1.5),
    (24.414, 25.448, "circle", 3.90, 1.5),
    (25.448, 26.483, "swarm", 2.00, 1.3),
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
    # build-up: the new faces, four to the bar
    (32.690, 33.207, "art_pn_jester", 0.0, 1),
    (33.207, 33.724, "art_pn_dragon", 0.0, 1),
    (33.724, 34.241, "art_pn_cross", 0.0, 1),
    (34.241, 34.759, "art_pn_rook", 0.0, 1),
    # climax: meteors and the circle's 99s
    (34.759, 35.276, "meteor", 1.40, 1.5),
    (35.276, 35.793, "meteor", 1.90, 1.5),
    (35.793, 36.310, "chain", 2.10, 1.5),
    (36.310, 36.828, "chain", 2.50, 1.5),
    # finish
    (36.828, 37.345, "fairies", 1.00, 1.5),
    (37.345, 37.862, "fairies", 7.20, 1.5),
    (37.862, 38.379, "glutton", 2.00, 1.5),
    (38.379, 38.897, "fairies", 13.20, 1.5),
    (38.897, 39.414, "glutton", 2.35, 1.5),
    (39.414, 39.931, "chain", 3.00, 1.5),
    (39.931, 40.448, "swarm", 3.60, 1.3),
    (40.448, 40.966, "art_p_king", 0.0, 1),
    (40.966, 41.85, None, 0.0, 1),
    (41.85, SONG_LENGTH, "title_fusion", 0.0, 1),
]

# Where the kicks fall (start, end, period) for the punch (a flash and a push-in) on every beat,
# and the big hits of the song (the cues' "hit" events).
BEATS = [(2.4, 9.6, 1.2), (17.172, 26.483, 1.0345), (26.483, 41.0, 0.5172), (41.85, 50.2, 0.5172)]
HITS = [9.6, 17.172, 26.483, 34.759, 41.85]

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


def crop_for(zoom):
    if zoom == 1:
        return ""
    w, h = int(1728 / zoom), int(1080 / zoom)
    return f"crop={w}:{h}:{(1728 - w) // 2}:{int(552 - h / 2)},"


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
    for n, (t0, t1, clip, src, zoom) in enumerate(CUTS):
        length = t1 - t0
        if clip is None:
            inputs += ["-f", "lavfi", "-t", f"{length:.3f}", "-i", f"color=c=black:s=1728x1080:r={FPS}"]
            parts.append(f"[{n}:v]fps={FPS},setsar=1[v{n}]")
        else:
            inputs += ["-i", f"{CLIPS}/{clip}.avi"]
            parts.append(f"[{n}:v]trim=start={src:.3f}:duration={length:.3f},setpts=PTS-STARTPTS,fps={FPS},{crop_for(zoom)}scale=1728:1080:flags=neighbor,setsar=1[v{n}]")
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
