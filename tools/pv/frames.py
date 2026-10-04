#!/usr/bin/env python3
"""Contact sheet of a recorded clip: frames.py build/pv/x.avi [every_seconds] -> /tmp/.../sheet.png"""
import subprocess, sys, os, glob
import imageio_ffmpeg
from PIL import Image
clip = sys.argv[1]
every = float(sys.argv[2]) if len(sys.argv) > 2 else 0.5
out = sys.argv[3] if len(sys.argv) > 3 else "/tmp/claude-0/pv/sheet.png"
os.makedirs("/tmp/claude-0/pv/f", exist_ok=True)
for f in glob.glob("/tmp/claude-0/pv/f/*.png"): os.remove(f)
ff = imageio_ffmpeg.get_ffmpeg_exe()
subprocess.run([ff, "-v", "error", "-i", clip, "-vf", f"fps=1/{every},scale=432:-1", "/tmp/claude-0/pv/f/%03d.png"], check=True)
files = sorted(glob.glob("/tmp/claude-0/pv/f/*.png"))
im0 = Image.open(files[0]); w, h = im0.size
cols = 4; rows = (len(files) + cols - 1) // cols
sheet = Image.new("RGB", (w * cols, h * rows))
for i, f in enumerate(files):
    sheet.paste(Image.open(f), ((i % cols) * w, (i // cols) * h))
sheet.save(out); print(len(files), "frames ->", out)
