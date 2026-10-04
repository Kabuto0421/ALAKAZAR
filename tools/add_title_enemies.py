#!/usr/bin/env python3
"""Adds the jester, the dragon-armoured soldier, the X soldier and the storm shark (peeking out of the water) to the title art's enemy side.

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
HEIGHTS = {"dragon": 116, "jester": 112, "cross": 112}   # the soldiers run 135-140 px; a row in front looks smaller
ORDER = ["dragon", "jester", "cross"]   # nearest the heroes (left) first: the dragon leads, the jester is second
FEET_Y = 1010         # where the new front row stands (above the catalogue button)
START_X = 1214        # right next to the menu window (its right edge is x 1205)
GAP = 1               # sprites stand shoulder to shoulder without overlapping, leaving room on the right for more enemies
SHARK_HEIGHT = 240    # a boss: the biggest of the row; only the part above the water shows
SHARK_ABOVE = 0.62    # fraction of the shark standing out of the water


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


def shark_in_water(shark):
    """The storm shark peeking out of the water: the upper part of its body over a ripple pool."""
    shark = fit(shark, SHARK_HEIGHT)
    w, h = shark.size
    keep = round(h * SHARK_ABOVE)
    body = shark.crop((0, 0, w, keep))
    pad = 16
    pool_h = 70
    canvas = Image.new("RGBA", (w + pad * 2, keep + pool_h), (0, 0, 0, 0))
    cy = keep   # the waterline
    cx = canvas.size[0] // 2
    draw = ImageDraw.Draw(canvas)
    # The pool seen from a slant: a dark body of water with rings spreading from the shark.
    draw.ellipse((cx - w // 2 - pad + 4, cy - 18, cx + w // 2 + pad - 4, cy + 34), fill=(14, 38, 66, 230))
    for k, alpha in ((0, 200), (1, 130), (2, 70)):
        grow = k * 9
        draw.ellipse((cx - w // 2 - pad + 4 - 0 + k * 3, cy - 18 + k * 2, cx + w // 2 + pad - 4 - k * 3, cy + 34 - k * 2), outline=(110, 220, 255, alpha), width=2)
    canvas.alpha_composite(body, (pad, 0))
    # The water in front of the body hides where it was cut: a lip of surface, foam where the two meet.
    front = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    fd = ImageDraw.Draw(front)
    fd.ellipse((cx - w // 2 - 6, cy - 12, cx + w // 2 + 6, cy + 24), fill=(22, 66, 108, 245))
    fd.ellipse((cx - w // 2 - 6, cy - 12, cx + w // 2 + 6, cy + 24), outline=(190, 245, 255, 235), width=3)
    fd.ellipse((cx - w // 2 + 8, cy - 6, cx + w // 2 - 8, cy + 16), outline=(120, 215, 255, 150), width=2)
    # Foam flecks and a few drops thrown up beside the head and the tail.
    for fx, fy, r in ((-0.52, -0.02, 4), (-0.44, -0.12, 3), (0.5, 0.0, 4), (0.42, -0.1, 3), (0.1, 0.1, 3), (-0.2, 0.12, 3)):
        px, py = cx + int(fx * w), cy + int(fy * 60)
        fd.ellipse((px - r, py - r, px + r, py + r), fill=(230, 250, 255, 220))
    canvas.alpha_composite(front)
    return canvas


def main(jester_src, dragon_src, cross_src, shark_src):
    sprites = {
        "jester": fit(transparent(Image.open(jester_src)), HEIGHTS["jester"]),
        "dragon": fit(last_pose(transparent(Image.open(dragon_src))), HEIGHTS["dragon"]),
        "cross": fit(last_pose(transparent(Image.open(cross_src))), HEIGHTS["cross"]),
    }
    layers = [Image.open(TITLE + n).convert("RGBA") for n in ("layer_20_enemies.png", "layer_20_enemies_fallen.png")]
    units = json.load(open(TITLE + "units.json"))
    z = max(u["z"] for u in units if u["side"] == "enemies") + 1
    names = {"jester": "道化兵", "dragon": "竜装兵", "cross": "バッテン兵", "shark": "嵐鮫"}
    placed = []
    x = START_X
    for kid in ORDER:
        sprite = sprites[kid]
        placed.append((kid, sprite, x, FEET_Y - sprite.size[1], True))
        x += sprite.size[0] + GAP
    shark = shark_in_water(Image.open(shark_src).convert("RGBA"))
    # The shark stands last in the row; new enemies go into ORDER above (before the shark).
    placed.append(("shark", shark, x - 6, FEET_Y - shark.size[1] + 40, False))
    for kid, sprite, x, y, shadow_wanted in placed:
        w, h = sprite.size
        if shadow_wanted:
            shadow = Image.new("RGBA", (w + 40, 40), (0, 0, 0, 0))
            ImageDraw.Draw(shadow).ellipse((6, 8, w + 34, 32), fill=(0, 0, 0, 120))
            shadow = shadow.filter(ImageFilter.GaussianBlur(5))
            for layer in layers:
                layer.alpha_composite(shadow, (x - 20, FEET_Y - 26))
        for layer in layers:
            layer.alpha_composite(sprite, (x, y))
        sprite.save(TITLE + f"units/enemies_{kid}.png", optimize=True)
        units.append({"id": kid, "name": names[kid], "side": "enemies", "file": f"units/enemies_{kid}.png", "x": x, "y": y, "w": w, "h": h, "z": z})
        z += 1
    layers[0].save(TITLE + "layer_20_enemies.png", optimize=True)
    layers[1].save(TITLE + "layer_20_enemies_fallen.png", optimize=True)
    json.dump(units, open(TITLE + "units.json", "w"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main(*sys.argv[1:5])
