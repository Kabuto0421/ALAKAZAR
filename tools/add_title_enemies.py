#!/usr/bin/env python3
"""Adds the jester, the dragon-armoured soldier, the X soldier and the storm shark to the title art's enemy side.

The enemy side of the title is two baked layers (assets/title/layer_20_enemies.png and the
"fallen" one shown once the king has been beaten). This pastes the three newcomers into both in a
new front row, saves each as its own picture in assets/title/units/ and lists them in units.json.
Run once from the repository root with the four source pictures:

    python3 tools/add_title_enemies.py JESTER.webp DRAGON_SHEET.webp CROSS_SHEET.webp assets/sprites/boss/storm_shark.png

(JESTER = the asleep jester picture; the dragon and X soldier ones are the 4-pose sheets, their
left-facing pose is used; the shark already faces left.)
It is not idempotent: it works from the baked layers as they are in git, so `git checkout` them first.
"""
import json
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

TITLE = "assets/title/"
HEIGHTS = {"jester": 112, "dragon": 112, "cross": 112, "shark": 128}   # the soldiers run 135-140 px; a row in front looks smaller
FEET_Y = 1010         # where the new front row stands (above the catalogue button, clear of the menu window)
SLOTS = {"jester": 1262, "dragon": 1450, "cross": 1612, "shark": 1775}   # feet centre x


def transparent(im):
    a = np.array(im.convert("RGBA"))
    if a[..., 3].min() > 200:
        white = a[..., :3].astype(int).min(axis=2) >= 240
        h, w = white.shape
        seen = np.zeros_like(white)
        stack = [(0, 0), (0, w - 1), (h - 1, 0), (h - 1, w - 1)]
        while stack:
            y, x = stack.pop()
            if y < 0 or x < 0 or y >= h or x >= w or seen[y, x] or not white[y, x]:
                continue
            seen[y, x] = True
            stack += [(y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)]
        a[seen, 3] = 0
    return Image.fromarray(a)


def last_pose(im):
    """The right-most pose of a 4-pose sheet (the one that faces left)."""
    occ = (np.array(im)[..., 3] > 20).sum(axis=0)
    runs, start = [], None
    for x, v in enumerate(occ):
        if v > 0 and start is None:
            start = x
        if v == 0 and start is not None:
            runs.append((start, x - 1))
            start = None
    if start is not None:
        runs.append((start, len(occ) - 1))
    x0, x1 = runs[-1]
    return im.crop((x0, 0, x1 + 1, im.size[1]))


def fit(im, height):
    im = im.crop(im.getbbox())
    w = round(im.size[0] * height / im.size[1])
    return im.resize((w, height), Image.LANCZOS)


def main(jester_src, dragon_src, cross_src, shark_src):
    sprites = {
        "jester": fit(transparent(Image.open(jester_src)), HEIGHTS["jester"]),
        "dragon": fit(last_pose(transparent(Image.open(dragon_src))), HEIGHTS["dragon"]),
        "cross": fit(last_pose(transparent(Image.open(cross_src))), HEIGHTS["cross"]),
        "shark": fit(Image.open(shark_src).convert("RGBA"), HEIGHTS["shark"]),
    }
    layers = [Image.open(TITLE + n).convert("RGBA") for n in ("layer_20_enemies.png", "layer_20_enemies_fallen.png")]
    units = json.load(open(TITLE + "units.json"))
    z = max(u["z"] for u in units if u["side"] == "enemies") + 1
    names = {"jester": "道化兵", "dragon": "竜装兵", "cross": "バッテン兵", "shark": "嵐鮫"}
    for kid, sprite in sprites.items():
        w, h = sprite.size
        x = SLOTS[kid] - w // 2
        y = FEET_Y - h
        # A soft shadow under the feet, like the rest of the row.
        shadow = Image.new("RGBA", (w + 40, 40), (0, 0, 0, 0))
        ImageDraw.Draw(shadow).ellipse((6, 8, w + 34, 32), fill=(0, 0, 0, 120))
        shadow = shadow.filter(ImageFilter.GaussianBlur(5))
        for layer in layers:
            layer.alpha_composite(shadow, (x - 20, FEET_Y - 26))
            layer.alpha_composite(sprite, (x, y))
        sprite.save(TITLE + f"units/enemies_{kid}.png", optimize=True)
        units.append({"id": kid, "name": names[kid], "side": "enemies", "file": f"units/enemies_{kid}.png", "x": x, "y": y, "w": w, "h": h, "z": z})
        z += 1
    layers[0].save(TITLE + "layer_20_enemies.png", optimize=True)
    layers[1].save(TITLE + "layer_20_enemies_fallen.png", optimize=True)
    json.dump(units, open(TITLE + "units.json", "w"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main(*sys.argv[1:5])
