#!/usr/bin/env python3
"""The title screen once the Prison King has been beaten: assets/title/layer_20_enemies_fallen.png
is the enemy layer with the king's black silhouette (assets/title/units/enemies_king.png) rubbed
out and the king himself, seated and in his own blue colours (the first frame of
assets/sprites/boss/prison_king_idle.png), put where he sat.   python3 tools/make_fallen_king.py"""
import numpy as np
from PIL import Image, ImageFilter

layer = Image.open("assets/title/layer_20_enemies.png").convert("RGBA")
king = Image.open("assets/title/units/enemies_king.png").convert("RGBA")
X, Y = 1572, 418
# Rub out only the pixels that really are the king's (his dark body), not the soldiers
# standing in front of him whose pixels share his rectangle.
pixels = np.array(layer)
kx = np.array(king)
region = pixels[Y:Y + 392, X:X + 276]
same = (kx[:, :, 3] > 0) & (np.abs(region[:, :, :3].astype(int) - kx[:, :, :3].astype(int)).max(axis=2) <= 10)
mask = np.zeros(pixels.shape[:2], bool)
mask[Y:Y + 392, X:X + 276] = same
# ...and the fringe of edge pixels next to them that are as dark as he is.
ring = np.array(Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))) > 0
dark = pixels[:, :, :3].astype(int).max(axis=2) < 70
pixels[(mask | (ring & dark)), 3] = 0
layer = Image.fromarray(pixels)

sheet = Image.open("assets/sprites/boss/prison_king_idle.png").convert("RGBA")
frame = sheet.crop((0, 0, 256, 256))
frame = frame.crop(frame.getbbox())
scale = 0.9 * 392 / frame.height
frame = frame.resize((round(frame.width * scale), round(frame.height * scale)), Image.NEAREST)
under = Image.new("RGBA", layer.size, (0, 0, 0, 0))
under.alpha_composite(frame, (X + 138 - frame.width // 2, Y + 392 - frame.height))
# He sits behind the soldiers who stood in front of the silhouette.
under.alpha_composite(layer)
under.save("assets/title/layer_20_enemies_fallen.png")
