#!/usr/bin/env python3
"""Builds the weapon / fairy catalog PDF: runs tools/make_catalog_pdf.gd (which draws the pages with the
game's own reward cards) and binds the page images into one PDF.

    python3 tools/make_catalog_pdf.py [godot-binary] [output.pdf]

Needs xvfb-run, Pillow and reportlab (pip install pillow reportlab)."""
import glob, os, subprocess, sys, tempfile
from reportlab.pdfgen import canvas
from reportlab.lib.utils import ImageReader

godot = sys.argv[1] if len(sys.argv) > 1 else "godot"
out = sys.argv[2] if len(sys.argv) > 2 else "catalog.pdf"
with tempfile.TemporaryDirectory() as pages:
    env = dict(os.environ, CATALOG_OUT=pages)
    subprocess.run(["xvfb-run", "-a", godot, "--rendering-driver", "opengl3", "--path", ".", "--script", "res://tools/make_catalog_pdf.gd"], check=True, env=env)
    files = sorted(glob.glob(os.path.join(pages, "page_*.png")))
    pdf = canvas.Canvas(out, pagesize=(1152, 806))
    for file in files:
        pdf.drawImage(ImageReader(file), 0, 0, 1152, 806)
        pdf.showPage()
    pdf.save()
print(out, len(files), "pages")
