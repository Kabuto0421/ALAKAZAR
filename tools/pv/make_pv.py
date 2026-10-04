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

# (song start, song end, clip, seconds into the clip)  -- clip None = black
CUTS = [
    (0.00, 2.40, "art_intro", 0.0),
    (2.40, 4.80, "art_fortress", 0.0),
    (4.80, 7.20, "art_king", 0.0),
    (7.20, 9.60, "art_hero", 0.0),
    (9.60, 12.00, "art_logo", 0.0),
    (12.00, 17.172, "art_fairies", 0.0),
    (17.172, 22.00, "guardian", 1.30),
    (22.00, 26.483, "chain", 0.95),
    (26.483, 28.55, "rotorick", 0.90),
    (28.55, 30.62, "shark", 6.60),
    (30.62, 32.69, "king", 1.20),
    (32.69, 34.759, "art_montage", 0.0),
    (34.759, 36.828, "king", 5.35),
    (36.828, 40.966, "meteor", 1.80),
    (40.966, 41.85, None, 0.0),
    (41.85, SONG_LENGTH, "title_fusion", 0.0),
]

SHOTS = ["art_intro", "art_fortress", "art_king", "art_hero", "art_logo", "art_fairies", "guardian",
         "chain", "rotorick", "shark", "king", "art_montage", "meteor", "title_fusion"]


def record():
    godot = os.environ.get("GODOT", "godot")
    os.makedirs(CLIPS, exist_ok=True)
    for shot in SHOTS:
        out = f"{CLIPS}/{shot}.avi"
        subprocess.run(["xvfb-run", "-a", godot, "--rendering-driver", "opengl3", "--path", ".", "--write-movie", out,
                        "--fixed-fps", str(FPS), "--resolution", "1728x1080", "--script", "res://tools/pv/pv_shot.gd", "--", shot],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print("recorded", shot)


def assemble(out="build/pv/ALAKAZAR_PV.mp4"):
    inputs, parts = [], []
    index = 0
    for n, (t0, t1, clip, src) in enumerate(CUTS):
        length = t1 - t0
        if clip is None:
            inputs += ["-f", "lavfi", "-t", f"{length:.3f}", "-i", f"color=c=black:s=1728x1080:r={FPS}"]
            parts.append(f"[{index}:v]fps={FPS},setsar=1[v{n}]")
        else:
            inputs += ["-i", f"{CLIPS}/{clip}.avi"]
            parts.append(f"[{index}:v]trim=start={src:.3f}:duration={length:.3f},setpts=PTS-STARTPTS,fps={FPS},scale=1728:1080:flags=neighbor,setsar=1[v{n}]")
        index += 1
    inputs += ["-i", SONG]
    audio = index
    concat = "".join(f"[v{n}]" for n in range(len(CUTS))) + f"concat=n={len(CUTS)}:v=1:a=0[cat]"
    graph = ";".join(parts + [concat, f"[cat]pad=1920:1080:96:0:black,format=yuv420p[v]"])
    cmd = [FF, "-v", "error", "-y"] + inputs + ["-filter_complex", graph, "-map", "[v]", "-map", f"{audio}:a",
           "-t", f"{SONG_LENGTH:.3f}", "-c:v", "libx264", "-crf", "17", "-preset", "medium", "-r", str(FPS),
           "-c:a", "aac", "-b:a", "192k", out]
    subprocess.run(cmd, check=True)
    print("wrote", out)


if __name__ == "__main__":
    if "--record" in sys.argv:
        record()
    assemble()
