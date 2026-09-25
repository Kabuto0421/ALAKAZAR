#!/usr/bin/env python3
"""Draw the rook boss (2x2 tiles) as pixel art.

The boss is a horned heavy trooper with a ram shield, drawn at the same pixel
density as the 28px soldiers (56px for a 2x2 piece). Deterministic output:

    pip install pillow
    python3 tools/generate_boss_sprite.py

Writes assets/sprites/enemies/rook_boss_56.png: a 4x3 atlas of 56px cells.
Columns follow the soldier atlas facing order (up/back, right, down/front,
left); rows are the states idle, brace (charge locked in) and stunned.
"""

import os

from PIL import Image

SIZE = 56
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "enemies", "rook_boss_56.png")

PALETTE = {
    "O": (6, 7, 12),        # outline
    "k": (12, 15, 26),      # inner lines between parts
    "n": (20, 26, 48),      # navy dark
    "N": (34, 46, 84),      # navy mid
    "L": (60, 78, 128),     # navy light
    "s": (44, 48, 58),      # steel dark
    "S": (100, 108, 122),   # steel
    "W": (206, 214, 224),   # steel highlight
    "h": (138, 128, 110),   # horn base
    "H": (224, 214, 190),   # horn
    "c": (18, 111, 128),    # cyan dark
    "C": (41, 216, 240),    # cyan
    "X": (190, 250, 255),   # cyan light
    "o": (122, 62, 22),     # orange off
    "Y": (255, 154, 46),    # orange lit
    "R": (255, 70, 70),     # red visor
    "r": (140, 24, 30),     # red dark
    "g": (60, 64, 72),      # dead visor
    "*": (244, 213, 111),   # stun stars
}
STATES = ("idle", "brace", "stun")


class Canvas:
    def __init__(self):
        self.px = [[None] * SIZE for _ in range(SIZE)]

    def dot(self, x, y, c):
        if 0 <= x < SIZE and 0 <= y < SIZE:
            self.px[y][x] = c

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.dot(x, y, c)

    def ellipse(self, cx, cy, rx, ry, c):
        for y in range(cy - ry, cy + ry + 1):
            for x in range(cx - rx, cx + rx + 1):
                if ((x - cx) / (rx + 0.5)) ** 2 + ((y - cy) / (ry + 0.5)) ** 2 <= 1:
                    self.dot(x, y, c)

    def poly(self, pts, c):
        ys = [p[1] for p in pts]
        for y in range(min(ys), max(ys) + 1):
            for x in range(SIZE):
                if _inside(x + 0.5, y + 0.5, pts):
                    self.dot(x, y, c)

    def line(self, pts, c, width=1):
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            steps = max(abs(x1 - x0), abs(y1 - y0), 1)
            for i in range(steps + 1):
                x = round(x0 + (x1 - x0) * i / steps)
                y = round(y0 + (y1 - y0) * i / steps)
                for w in range(width):
                    self.dot(x, y + w, c)

    def stroke_rect(self, x0, y0, x1, y1, fill, edge="k"):
        self.rect(x0, y0, x1, y1, edge)
        self.rect(x0 + 1, y0 + 1, x1 - 1, y1 - 1, fill)

    def stroke_ellipse(self, cx, cy, rx, ry, fill, edge="k"):
        self.ellipse(cx, cy, rx, ry, edge)
        self.ellipse(cx, cy, rx - 1, ry - 1, fill)

    def horn(self, p0, p1, p2, width=2.4):
        """Tapered quadratic curve: thick base, bright tip."""
        steps = 28
        for i in range(steps + 1):
            t = i / steps
            x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0]
            y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]
            r = width * (1 - t) + 0.4
            c = "h" if t < 0.4 else "H" if t < 0.9 else "W"
            ri = int(r)
            if ri < 1:
                self.dot(round(x), round(y), c)
            else:
                self.ellipse(round(x), round(y), ri, ri, c)

    def shade(self):
        """Light from above: brighten the top edge of each part, darken its bottom edge."""
        top = {"n": "N", "N": "L", "S": "W", "s": "S"}
        bottom = {"N": "n", "L": "N", "S": "s", "n": "k", "s": "k"}
        src = [row[:] for row in self.px]
        for y in range(SIZE):
            for x in range(SIZE):
                c = src[y][x]
                above = src[y - 1][x] if y > 0 else None
                below = src[y + 1][x] if y < SIZE - 1 else None
                if c in top and above != c and above not in top.values() and above != "k":
                    self.px[y][x] = top[c]
                elif c in bottom and below != c:
                    self.px[y][x] = bottom[c]

    def outline(self):
        edge = []
        for y in range(SIZE):
            for x in range(SIZE):
                if self.px[y][x] is None and any(
                        0 <= x + dx < SIZE and 0 <= y + dy < SIZE and self.px[y + dy][x + dx] not in (None, "O", "*")
                        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    edge.append((x, y))
        for x, y in edge:
            self.px[y][x] = "O"

    def mirrored(self):
        out = Canvas()
        out.px = [row[::-1] for row in self.px]
        return out

    def image(self):
        img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        for y in range(SIZE):
            for x in range(SIZE):
                c = self.px[y][x]
                if c:
                    img.putpixel((x, y), PALETTE[c] + (255,))
        return img


def _inside(x, y, pts):
    hit = False
    for (x0, y0), (x1, y1) in zip(pts, pts[1:] + pts[:1]):
        if (y0 > y) != (y1 > y) and x < x0 + (x1 - x0) * (y - y0) / (y1 - y0):
            hit = not hit
    return hit


def stars(cv, cx, cy):
    for x, y in ((cx - 7, cy + 1), (cx, cy - 2), (cx + 7, cy + 1)):
        cv.dot(x, y, "*")
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            cv.dot(x + dx, y + dy, "*")


def visor_colors(state):
    return {"idle": ("C", "X"), "brace": ("R", "Y"), "stun": ("g", "g")}[state]


# --- front (facing down, toward the viewer) ---------------------------------

def horns_front(cv, hx, hy, state, flip=False):
    for sd in (-1, 1):
        if state == "idle":
            pts = [(hx + sd * 6, hy - 2), (hx + sd * 15, hy - 4), (hx + sd * 13, hy - 12)]
        elif state == "brace":
            pts = [(hx + sd * 6, hy - 2), (hx + sd * 13, hy - 3), (hx + sd * 18, hy - 7)]
        else:
            pts = [(hx + sd * 6, hy - 2), (hx + sd * 13, hy - 3), (hx + sd * 15, hy - 9)]
        cv.horn(*pts)


def legs_front(cv, dy, spread, back=False):
    for sd in (-1, 1):
        x0 = 28 + sd * (7 + spread) - 4
        cv.stroke_rect(x0, 40 + dy // 2, x0 + 8, 51, "n")
        if not back:
            cv.rect(x0 + 3, 46, x0 + 5, 49, "c")          # shin light
            cv.dot(x0 + 4, 47, "C")
            cv.stroke_ellipse(x0 + 4, 43 + dy // 2, 3, 2, "S")
        cv.stroke_rect(x0 - 1, 49, x0 + 9, 54, "s")
        cv.rect(x0, 50, x0 + 8, 50, "S")


def front(state):
    cv = Canvas()
    dy = {"idle": 0, "brace": 3, "stun": 2}[state]
    lean = 1 if state == "stun" else 0
    spread = 2 if state == "brace" else 0
    visor, glint = visor_colors(state)
    lit = "Y" if state == "brace" else "o"
    hx, hy = 28 + lean + (2 if state == "stun" else 0), 14 + dy

    horns_front(cv, hx, hy, state)
    legs_front(cv, dy, spread)
    # tassets
    cv.stroke_rect(14 + lean, 38 + dy, 42 + lean, 44 + dy, "N")
    for x in (21, 28, 35):
        cv.rect(x + lean, 39 + dy, x + lean, 43 + dy, "k")
    # torso and chest plate
    cv.poly([(13 + lean, 22 + dy), (43 + lean, 22 + dy), (41 + lean, 40 + dy), (15 + lean, 40 + dy)], "k")
    cv.poly([(14 + lean, 23 + dy), (42 + lean, 23 + dy), (40 + lean, 39 + dy), (16 + lean, 39 + dy)], "N")
    cv.poly([(18 + lean, 24 + dy), (38 + lean, 24 + dy), (36 + lean, 34 + dy), (20 + lean, 34 + dy)], "L")
    cv.line([(28 + lean, 24 + dy), (28 + lean, 26 + dy)], "k")
    cv.stroke_rect(24 + lean, 27 + dy, 32 + lean, 32 + dy, "c")
    cv.rect(26 + lean, 28 + dy, 30 + lean, 30 + dy, "g" if state == "stun" else "C")
    if state != "stun":
        cv.dot(26 + lean, 28 + dy, "X")
    cv.stroke_rect(15 + lean, 36 + dy, 41 + lean, 39 + dy, "s")
    cv.rect(27 + lean, 37 + dy, 29 + lean, 38 + dy, lit)
    # free arm with spiked gauntlet
    cv.stroke_rect(5 + lean, 29 + dy, 13 + lean, 41 + dy, "n")
    cv.stroke_rect(4 + lean, 40 + dy, 14 + lean, 46 + dy, "S")
    for y in (41, 44):
        cv.dot(3 + lean, y + dy, "W")
        cv.dot(2 + lean, y + dy, "S")
    # pauldrons with warning lights and rivets
    for sd in (-1, 1):
        cx = 28 + sd * 16 + lean
        cv.stroke_ellipse(cx, 25 + dy, 9, 6, "S")
        cv.ellipse(cx - 2, 22 + dy, 4, 1, "W")
        cv.rect(cx - 1, 26 + dy, cx, 27 + dy, lit)
        cv.dot(cx - 6, 25 + dy, "W")
        cv.dot(cx + 6, 25 + dy, "W")

    if state == "idle":
        cv.stroke_rect(40, 23, 54, 49, "s")
        cv.stroke_rect(42, 25, 52, 47, "N")
        cv.rect(46, 28, 48, 44, "C")
        cv.rect(46, 28, 46, 44, "X")
        for x, y in ((43, 26), (51, 26), (43, 46), (51, 46)):
            cv.dot(x, y, "W")
    elif state == "stun":
        cv.stroke_rect(37, 46, 55, 52, "s")
        cv.stroke_rect(39, 47, 53, 51, "N")
        cv.rect(42, 49, 51, 49, "c")

    # helmet
    cv.stroke_ellipse(hx, hy, 8, 8, "n")
    cv.ellipse(hx - 1, hy - 4, 4, 2, "L")
    cv.stroke_rect(hx - 7, hy + 1, hx + 7, hy + 7, "N")
    cv.rect(hx - 6, hy - 1, hx + 6, hy + 2, "k")
    cv.rect(hx - 5, hy, hx + 5, hy + 1, visor)
    cv.dot(hx - 4, hy, glint)
    cv.rect(hx - 1, hy + 3, hx + 1, hy + 6, "k")
    cv.stroke_rect(hx - 4, hy + 7, hx + 4, hy + 9, "s")

    if state == "brace":
        # ram shield thrust over the torso, spike aimed at the viewer
        cv.stroke_rect(14, 25 + dy, 42, 48, "s")
        cv.stroke_rect(16, 27 + dy, 40, 46, "N")
        cy = 37 + dy // 2 + 1
        cv.stroke_ellipse(28, cy, 7, 7, "S")
        cv.ellipse(28, cy, 4, 4, "W")
        cv.ellipse(28, cy, 2, 2, "S")
        cv.dot(27, cy - 1, "W")
        for x in (19, 37):
            cv.rect(x, 30 + dy, x, 44, "R")
        for x, y in ((16, 27 + dy), (40, 27 + dy), (16, 46), (40, 46)):
            cv.dot(x, y, "W")
    cv.shade()
    cv.outline()
    if state == "stun":
        stars(cv, hx, hy - 13)
    return cv


# --- side (facing right) -----------------------------------------------------

def side(state):
    cv = Canvas()
    dy = {"idle": 0, "brace": 3, "stun": 2}[state]
    fwd = {"idle": 0, "brace": 3, "stun": -2}[state]
    visor, glint = visor_colors(state)
    lit = "Y" if state == "brace" else "o"
    hx, hy = 31 + fwd, 14 + dy

    # rear horn stub and forward horn
    cv.horn((hx - 3, hy - 4), (hx - 7, hy - 7), (hx - 7, hy - 11), 1.6)
    if state == "idle":
        cv.horn((hx + 2, hy - 3), (hx + 11, hy - 5), (hx + 11, hy - 15))
    elif state == "brace":
        cv.horn((hx + 3, hy - 2), (hx + 12, hy - 3), (hx + 19, hy - 1))
    else:
        cv.horn((hx + 2, hy - 3), (hx + 8, hy - 5), (hx + 7, hy - 13))
    # power pack with thruster vents
    px = 9 + fwd // 2
    cv.stroke_rect(px, 21 + dy, px + 9, 37 + dy, "n")
    cv.rect(px + 1, 22 + dy, px + 8, 23 + dy, "L")
    vent = {"idle": "c", "brace": "C", "stun": "g"}[state]
    cv.stroke_rect(px + 2, 29 + dy, px + 4, 35 + dy, vent)
    if state == "brace":
        for i, x in enumerate(range(1, px + 1)):
            cv.dot(x, 31 + dy + (i % 2), "C" if i > 3 else "c")
            cv.dot(x, 33 + dy, "X" if i > 5 else "c")
    # legs: rear then front
    cv.stroke_rect(17, 40 + dy // 2, 25, 51, "n")
    cv.stroke_rect(16, 49, 26, 54, "s")
    fx = 27 + fwd // 2
    cv.stroke_rect(fx, 40 + dy // 2, fx + 8, 51, "N")
    cv.rect(fx + 6, 45, fx + 7, 49, "c")
    cv.dot(fx + 7, 46, "C")
    cv.stroke_ellipse(fx + 4, 43 + dy // 2, 3, 2, "S")
    cv.stroke_rect(fx, 49, fx + 12, 54, "s")
    cv.rect(fx + 1, 50, fx + 11, 50, "S")
    # torso
    cv.poly([(16 + fwd, 22 + dy), (36 + fwd, 22 + dy), (38 + fwd, 42 + dy), (16, 42 + dy)], "k")
    cv.poly([(17 + fwd, 23 + dy), (35 + fwd, 23 + dy), (37 + fwd, 41 + dy), (17, 41 + dy)], "N")
    cv.poly([(28 + fwd, 24 + dy), (35 + fwd, 24 + dy), (36 + fwd, 35 + dy), (29 + fwd, 35 + dy)], "L")
    cv.stroke_rect(16, 37 + dy, 38 + fwd, 40 + dy, "s")
    cv.rect(31 + fwd, 38 + dy, 32 + fwd, 39 + dy, lit)
    # near pauldron
    cv.stroke_ellipse(25 + fwd, 25 + dy, 9, 6, "S")
    cv.ellipse(23 + fwd, 22 + dy, 4, 1, "W")
    cv.rect(21 + fwd, 26 + dy, 22 + fwd, 27 + dy, lit)
    cv.dot(18 + fwd, 25 + dy, "W")
    cv.dot(31 + fwd, 25 + dy, "W")
    # helmet
    cv.stroke_ellipse(hx, hy, 7, 8, "n")
    cv.ellipse(hx - 1, hy - 4, 4, 2, "L")
    cv.stroke_rect(hx - 1, hy + 1, hx + 7, hy + 7, "N")
    cv.rect(hx + 1, hy - 1, hx + 7, hy + 2, "k")
    cv.rect(hx + 2, hy, hx + 7, hy + 1, visor)
    cv.dot(hx + 6, hy, glint)
    cv.stroke_rect(hx - 3, hy + 7, hx + 3, hy + 9, "s")
    # ram shield carried in front
    sx = {"idle": 38, "brace": 42, "stun": 37}[state]
    if state == "stun":
        cv.poly([(33, 45), (51, 42), (53, 48), (35, 52)], "k")
        cv.poly([(35, 46), (50, 43), (51, 47), (36, 50)], "N")
    else:
        spike_y = 35 + dy // 2
        tip = 55 if state == "brace" else 50
        cv.poly([(sx + 5, spike_y - 3), (tip, spike_y), (sx + 5, spike_y + 3)], "S")
        cv.line([(sx + 6, spike_y - 1), (tip - 2, spike_y)], "W")
        cv.stroke_rect(sx, 23 + dy, sx + 6, 49, "s")
        cv.stroke_rect(sx + 1, 25 + dy, sx + 5, 47, "N")
        cv.rect(sx + 4, 27 + dy, sx + 4, 45, "C" if state == "idle" else "R")
        cv.dot(sx + 2, 26 + dy, "W")
        cv.dot(sx + 2, 46, "W")
    cv.shade()
    cv.outline()
    if state == "stun":
        stars(cv, hx, hy - 13)
    return cv


# --- back (facing up, away from the viewer) ---------------------------------

def back(state):
    cv = Canvas()
    dy = {"idle": 0, "brace": 3, "stun": 2}[state]
    spread = 2 if state == "brace" else 0
    hx, hy = 28 + (2 if state == "stun" else 0), 14 + dy

    horns_front(cv, hx, hy, state)
    legs_front(cv, dy, spread, back=True)
    cv.stroke_rect(14, 38 + dy, 42, 44 + dy, "N")
    cv.poly([(13, 22 + dy), (43, 22 + dy), (41, 40 + dy), (15, 40 + dy)], "k")
    cv.poly([(14, 23 + dy), (42, 23 + dy), (40, 39 + dy), (16, 39 + dy)], "N")
    if state != "stun":
        cv.stroke_rect(42, 25, 48, 48, "s")
        cv.rect(43, 27, 47, 46, "n")
    for sd in (-1, 1):
        cx = 28 + sd * 16
        cv.stroke_ellipse(cx, 25 + dy, 9, 6, "S")
        cv.ellipse(cx + 2 * sd, 22 + dy, 4, 1, "W")
    # power pack with twin thrusters
    cv.stroke_rect(18, 21 + dy, 38, 39 + dy, "n")
    cv.rect(19, 22 + dy, 37, 23 + dy, "L")
    cv.stroke_rect(26, 25 + dy, 30, 37 + dy, "s")
    vent = {"idle": "c", "brace": "C", "stun": "g"}[state]
    for x in (21, 32):
        cv.stroke_rect(x, 29 + dy, x + 3, 38 + dy, vent)
        if state == "brace":
            cv.rect(x + 1, 40 + dy, x + 2, 43 + dy, "C")
            cv.rect(x + 1, 40 + dy, x + 1, 45 + dy, "X")
    cv.stroke_ellipse(hx, hy, 8, 8, "n")
    cv.ellipse(hx, hy - 3, 5, 3, "N")
    cv.ellipse(hx - 1, hy - 5, 3, 1, "L")
    cv.rect(hx - 5, hy + 4, hx + 5, hy + 4, "k")
    cv.shade()
    cv.outline()
    if state == "stun":
        stars(cv, hx, hy - 13)
    return cv


def main():
    atlas = Image.new("RGBA", (SIZE * 4, SIZE * len(STATES)), (0, 0, 0, 0))
    for row, state in enumerate(STATES):
        right = side(state)
        frames = [back(state), right, front(state), right.mirrored()]
        for col, cv in enumerate(frames):
            atlas.paste(cv.image(), (col * SIZE, row * SIZE))
    atlas.save(OUT)
    print(os.path.normpath(OUT), atlas.size)


if __name__ == "__main__":
    main()
