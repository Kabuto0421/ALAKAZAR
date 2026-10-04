#!/usr/bin/env python3
"""Labelled contact sheet: sheet.py clip.avi step_seconds out.png [start] [end]"""
import subprocess, sys, os, glob
import imageio_ffmpeg
from PIL import Image, ImageDraw
clip, step, out = sys.argv[1], float(sys.argv[2]), sys.argv[3]
start = float(sys.argv[4]) if len(sys.argv) > 4 else 0.0
end = float(sys.argv[5]) if len(sys.argv) > 5 else 999.0
d = "/tmp/claude-0/pv/sf"; os.makedirs(d, exist_ok=True)
for f in glob.glob(d + "/*.png"): os.remove(f)
ff = imageio_ffmpeg.get_ffmpeg_exe()
args = [ff, "-v", "error", "-ss", str(start)] + (["-t", str(end - start)] if end < 900 else []) + ["-i", clip, "-vf", f"fps=1/{step},scale=384:-1", d + "/%03d.png"]
subprocess.run(args, check=True)
files = sorted(glob.glob(d + "/*.png"))
w, h = Image.open(files[0]).size
cols = 5; rows = (len(files) + cols - 1) // cols
sheet = Image.new("RGB", (w * cols, h * rows))
dr = ImageDraw.Draw(sheet)
for i, f in enumerate(files):
    x, y = (i % cols) * w, (i // cols) * h
    sheet.paste(Image.open(f), (x, y))
    dr.rectangle((x, y, x + 46, y + 16), fill=(0, 0, 0)); dr.text((x + 3, y + 2), f"{start + i * step:.1f}", fill=(255, 255, 0))
sheet.save(out)
