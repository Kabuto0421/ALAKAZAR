#!/usr/bin/env python3
"""Draws the achievement icons (assets/achievements/*.png, 256x256) from the fairy sprites:
    python3 tools/make_achievement_icons.py
Each icon is a dark rounded panel with a gold border and a soft glow, and the sprites on it."""
import math
import random
from PIL import Image, ImageDraw

S = 256
SPR = "assets/sprites/spirits/%s.png"
OUT = "assets/achievements/%s.png"


def sprite(path):
    im = Image.open(path).convert("RGBA")
    box = im.getbbox()
    return im.crop(box) if box else im


def frame(glow, border=(242, 193, 78), rings=True):
    bg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(bg)
    d.rounded_rectangle((0, 0, S - 1, S - 1), radius=34, fill=(11, 24, 30, 255))
    for i, a in enumerate((60, 40, 24, 12) if rings else ()):
        d.rounded_rectangle((8 + i * 10, 8 + i * 10, S - 9 - i * 10, S - 9 - i * 10), radius=28 - i * 4, outline=glow + (a,), width=10)
    d.rounded_rectangle((2, 2, S - 3, S - 3), radius=32, outline=border + (255,), width=6)
    d.rounded_rectangle((12, 12, S - 13, S - 13), radius=24, outline=border + (90,), width=2)
    return bg


def put(bg, sp, cx, cy, box):
    """Paste `sp` fitted into a box x box square centred on (cx, cy)."""
    k = box / max(sp.size)
    sp = sp.resize((max(1, int(sp.width * k)), max(1, int(sp.height * k))), Image.LANCZOS)
    bg.alpha_composite(sp, (int(cx - sp.width / 2), int(cy - sp.height / 2)))


def save(im, name):
    im.save(OUT % name)


def bolt(d, a, b, color, width=5, seed=1):
    """A jagged lightning line from a to b."""
    rnd = random.Random(seed)
    pts = [a]
    n = 7
    for i in range(1, n):
        t = i / n
        x = a[0] + (b[0] - a[0]) * t
        y = a[1] + (b[1] - a[1]) * t
        nx, ny = -(b[1] - a[1]), (b[0] - a[0])
        norm = math.hypot(nx, ny) or 1
        off = rnd.uniform(-9, 9)
        pts.append((x + nx / norm * off, y + ny / norm * off))
    pts.append(b)
    d.line(pts, fill=color + (70,), width=width + 8)
    d.line(pts, fill=color + (255,), width=width)
    d.line(pts, fill=(255, 255, 255, 255), width=max(1, width - 3))


# 妖精マスター: every fairy there is, packed edge to edge (read from items/*.tres)
import glob
import re
paths = []
for f in sorted(glob.glob("items/*.tres")):
    m = re.search(r'path="res://(assets/sprites/spirits/[^"]+\.png)"', open(f).read())
    if m:
        paths.append(m.group(1))
bg = frame((43, 220, 200), rings=False)
# A soft teal glow behind the crowd instead of the dark ring-shaped panel.
glow_layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
gd = ImageDraw.Draw(glow_layer)
for r, a in ((124, 14), (100, 16), (74, 18)):
    gd.ellipse((128 - r, 128 - r, 128 + r, 128 + r), fill=(43, 220, 200, a))
bg.alpha_composite(glow_layer)
rows = [5, 4, 5, 4, 4]
assert sum(rows) >= len(paths), "more fairies than the icon has room for: add a row"
cell = 47
y = 128 - cell * len(rows) / 2 + cell / 2
k = 0
for count in rows:
    x0 = 128 - cell * count / 2 + cell / 2
    for i in range(count):
        if k < len(paths):
            put(bg, sprite(paths[k]), x0 + i * cell, y, cell)
            k += 1
    y += cell
save(bg, "fairy_master")

# Not earned yet: a question mark in the same frame (red for Y O U　 D I E D).
from PIL import ImageFont
def locked(name, glow, border=(242, 193, 78)):
    bg = frame(glow, border)
    d = ImageDraw.Draw(bg)
    font = ImageFont.truetype("assets/fonts/DotGothic16-Regular.ttf", 170)
    box = d.textbbox((0, 0), "?", font=font)
    at = (128 - (box[0] + box[2]) / 2, 128 - (box[1] + box[3]) / 2)
    d.text(at, "?", font=font, fill=glow + (70,), stroke_width=8, stroke_fill=glow + (40,))
    d.text(at, "?", font=font, fill=(214, 224, 230, 255))
    save(bg, name)
locked("locked", (120, 140, 160))
locked("locked_red", (255, 40, 40), (190, 40, 40))

# ザ・ワールド: the time fairy
bg = frame((200, 170, 255))
put(bg, sprite(SPR % "time_fairy"), S / 2, S / 2, 176)
save(bg, "the_world")

# ALAKAZAR's KING: the Prison King's silhouette, red light behind
bg = frame((255, 70, 70), border=(255, 120, 90))
glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(glow).ellipse((48, 48, 208, 208), fill=(255, 40, 40, 90))
bg.alpha_composite(glow)
put(bg, sprite("assets/title/units/enemies_king.png"), S / 2, S / 2 + 4, 176)
save(bg, "alakazar_king")

# 天の守護神、ここにあり。: the guardian in the middle, the allies it calls (all but the glutton) around it
bg = frame((255, 220, 120))
for sp, cx, cy in (("acorn_fairy", 52, 54), ("lone_wolf", 204, 54), ("holy_spirit", 50, 204), ("stealth_fairy", 206, 204)):
    put(bg, sprite(SPR % sp), cx, cy, 66)
put(bg, sprite(SPR % "guardian_fairy"), S / 2, S / 2 + 4, 150)
save(bg, "guardian_sky")

# YOU DIED: the glutton, red
bg = frame((255, 40, 40), border=(190, 40, 40))
put(bg, sprite(SPR % "glutton_fairy"), S / 2, S / 2, 172)
save(bg, "you_died")

# 戦場の庭師: lance cannon, vane cannon, firework, capacitor
bg = frame((255, 160, 90))
for sp, cx, cy in (("cannon_fairy", 78, 78), ("vane_cannon", 178, 78), ("firework_fairy", 78, 178), ("capacitor_fairy", 178, 178)):
    put(bg, sprite(SPR % sp), cx, cy, 84)
save(bg, "garden")

# ばよえ〜ん！: three placed fairies joined by their own attacks
bg = frame((120, 200, 255))
d = ImageDraw.Draw(bg)
points = {"cannon_fairy": (62, 188), "vane_cannon": (194, 188), "capacitor_fairy": (128, 66)}
bolt(d, points["cannon_fairy"], points["vane_cannon"], (255, 210, 90), seed=3)
bolt(d, points["vane_cannon"], points["capacitor_fairy"], (255, 120, 120), seed=5)
bolt(d, points["capacitor_fairy"], points["cannon_fairy"], (120, 220, 255), seed=8)
for sp, (cx, cy) in points.items():
    put(bg, sprite(SPR % sp), cx, cy, 78)
save(bg, "chain")

# え、これできるんだ...: the magic bolt fairy and the lance cannon, a spark between
bg = frame((120, 255, 200))
d = ImageDraw.Draw(bg)
bolt(d, (96, 128), (160, 128), (140, 255, 220), width=6, seed=2)
put(bg, sprite(SPR % "magic_bolt_fairy"), 70, 128, 96)
put(bg, sprite(SPR % "cannon_fairy"), 188, 128, 96)
save(bg, "surprise")

# 魔法陣最高！: a magic circle
bg = frame((190, 190, 255))
d = ImageDraw.Draw(bg, "RGBA")
cx = cy = S / 2
for r, a, w in ((98, 255, 5), (86, 200, 3), (66, 170, 2)):
    d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=(228, 238, 255, a), width=w)
for k in range(48):
    a = k * math.tau / 48
    ln = 9 if k % 4 == 0 else 5
    d.line((cx + math.cos(a) * 98, cy + math.sin(a) * 98, cx + math.cos(a) * (98 - ln), cy + math.sin(a) * (98 - ln)), fill=(228, 238, 255, 230), width=2)
rnd = random.Random(7)
for k in range(16):
    a = k * math.tau / 16
    gx, gy = cx + math.cos(a) * 76, cy + math.sin(a) * 76
    glyph = [(gx + rnd.uniform(-5, 5), gy + rnd.uniform(-6, 6)) for _ in range(4)]
    d.line(glyph, fill=(255, 211, 91, 255), width=2)
for flip in (0, math.pi):
    tri = [(cx + math.cos(-math.pi / 2 + flip + k * math.tau / 3) * 56, cy + math.sin(-math.pi / 2 + flip + k * math.tau / 3) * 56) for k in range(4)]
    d.line(tri, fill=(255, 255, 255, 255), width=4)
d.ellipse((cx - 56, cy - 56, cx + 56, cy + 56), outline=(255, 211, 91, 255), width=3)
pent = [(cx + math.cos(-math.pi / 2 + k * math.tau * 2 / 5) * 30, cy + math.sin(-math.pi / 2 + k * math.tau * 2 / 5) * 30) for k in range(6)]
d.line(pent, fill=(120, 230, 255, 255), width=3)
d.ellipse((cx - 9, cy - 9, cx + 9, cy + 9), fill=(255, 255, 255, 255))
save(bg, "circle")

# これは一体、どうなっちゃうんだ〜！？: the meteor fairy
bg = frame((255, 140, 70))
put(bg, sprite(SPR % "meteor_fairy"), S / 2, S / 2, 176)
save(bg, "meteor_hell")
