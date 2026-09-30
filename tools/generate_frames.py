"""Seamless pixel-art material tiles for the reward card frames.

    python3 tools/generate_frames.py

Writes assets/sprites/ui/frame_{wood,jade,lapis,gold}.png: 32x32 tiles at one texel per UI pixel
with nearest-neighbour so they read as chunky pixels. The frame is drawn along a
horizontal strip, so the grain runs left to right (the vertical sides use the
tile turned 90 degrees).
"""
import math
import random
from pathlib import Path

from PIL import Image

N = 32
SCALE = 1
OUT = Path(__file__).resolve().parent.parent / "assets" / "sprites" / "ui"


def value_noise(seed, cells):
    """Smooth, seamless noise on an N x N grid with `cells` lattice cells per side."""
    rng = random.Random(seed)
    lattice = [[rng.random() for _ in range(cells)] for _ in range(cells)]

    def at(x, y):
        fx, fy = x / N * cells, y / N * cells
        x0, y0 = int(fx), int(fy)
        tx, ty = fx - x0, fy - y0
        tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
        a = lattice[y0 % cells][x0 % cells]
        b = lattice[y0 % cells][(x0 + 1) % cells]
        c = lattice[(y0 + 1) % cells][x0 % cells]
        d = lattice[(y0 + 1) % cells][(x0 + 1) % cells]
        return (a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty

    return at


def mix(c1, c2, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(round(c1[i] + (c2[i] - c1[i]) * t)) for i in range(3))


def ramp(stops, t):
    """Pick a colour from a list of (position, rgb) stops, stepped for a pixel look."""
    t = max(0.0, min(0.999, t))
    for k in range(len(stops) - 1):
        if stops[k][0] <= t < stops[k + 1][0]:
            return stops[k][1]
    return stops[-1][1]


def hexrgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def wood():
    grain = value_noise(3, 4)
    fine = value_noise(7, 16)
    img = Image.new("RGB", (N, N))
    for y in range(N):
        for x in range(N):
            # Long grain lines running along the strip, bent by low-frequency noise.
            v = math.sin((y + grain(x, y) * 6.0) * 2 * math.pi / 8.0) * 0.5 + 0.5
            v = v * 0.75 + fine(x, y) * 0.25
            img.putpixel((x, y), ramp([(0.0, hexrgb("5a3519")), (0.3, hexrgb("7a4a24")), (0.62, hexrgb("94602f")), (0.85, hexrgb("ad7840"))], v))
    # A small knot.
    for y in range(N):
        for x in range(N):
            d = math.hypot((x - 22) * 0.9, (y - 16) * 1.6)
            if d < 3.2:
                img.putpixel((x, y), hexrgb("4a2a12") if d < 1.6 else hexrgb("6a3e1c"))
    return img


def jade():
    cloud = value_noise(11, 3)
    detail = value_noise(13, 8)
    milk = value_noise(17, 5)
    rng = random.Random(19)
    img = Image.new("RGB", (N, N))
    for y in range(N):
        for x in range(N):
            v = cloud(x, y) * 0.6 + detail(x, y) * 0.4
            c = ramp([(0.0, hexrgb("1c6040")), (0.3, hexrgb("27784f")), (0.55, hexrgb("369566")), (0.78, hexrgb("56b482"))], v)
            # Milky, translucent clouds inside the stone.
            m = milk(x, y)
            if m > 0.66:
                c = mix(c, hexrgb("b8e8c8"), (m - 0.66) * 1.6)
            img.putpixel((x, y), c)
    for _ in range(5):
        img.putpixel((rng.randrange(N), rng.randrange(N)), hexrgb("d8f5e2"))
    return img


def lapis():
    cloud = value_noise(21, 4)
    detail = value_noise(23, 10)
    rng = random.Random(29)
    img = Image.new("RGB", (N, N))
    for y in range(N):
        for x in range(N):
            v = cloud(x, y) * 0.6 + detail(x, y) * 0.4
            img.putpixel((x, y), ramp([(0.0, hexrgb("132a6e")), (0.4, hexrgb("1d3d99")), (0.7, hexrgb("2a56c2")), (0.9, hexrgb("4a78e0"))], v))
    # Pyrite flecks (gold) and a few pale calcite specks.
    for _ in range(14):
        x, y = rng.randrange(N), rng.randrange(N)
        img.putpixel((x, y), hexrgb("f2cf5a"))
        if rng.random() < 0.4:
            img.putpixel(((x + 1) % N, y), hexrgb("c9a23a"))
    for _ in range(6):
        img.putpixel((rng.randrange(N), rng.randrange(N)), hexrgb("a9c2f0"))
    return img


def gold():
    brush = value_noise(31, 16)
    img = Image.new("RGB", (N, N))
    for y in range(N):
        for x in range(N):
            # Brushed along the strip (the frame adds the bevel light and shade).
            v = brush(x, y) * 0.55 + math.sin(y * 2 * math.pi / 5.0) * 0.12 + 0.35
            img.putpixel((x, y), ramp([(0.0, hexrgb("7a5410")), (0.25, hexrgb("a8781c")), (0.5, hexrgb("d6a12e")), (0.72, hexrgb("f2c94c")), (0.9, hexrgb("fff0a8"))], v))
    return img


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, make in [("wood", wood), ("jade", jade), ("lapis", lapis), ("gold", gold)]:
        tile = make().resize((N * SCALE, N * SCALE), Image.NEAREST)
        tile.save(OUT / f"frame_{name}.png")
        print("wrote", OUT / f"frame_{name}.png")


if __name__ == "__main__":
    main()
