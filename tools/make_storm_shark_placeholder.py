#!/usr/bin/env python3
"""A stand-in for the storm shark's artwork: assets/sprites/boss/storm_shark.png (512x512,
facing left). Replace the file with the real picture, same name.   python3 tools/make_storm_shark_placeholder.py"""
from PIL import Image, ImageDraw
S = 512
im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
EDGE = (20, 40, 60, 255)
BODY = (60, 170, 190, 255)
BELLY = (170, 235, 240, 255)
PLATE = (40, 100, 130, 255)
# tail, body, dorsal fin, pectoral fin
d.polygon([(400, 250), (500, 150), (470, 250), (500, 350)], fill=BODY, outline=EDGE)
d.polygon([(40, 270), (120, 170), (260, 130), (400, 190), (410, 300), (260, 380), (110, 350)], fill=BODY, outline=EDGE)
d.polygon([(120, 300), (260, 360), (390, 300), (400, 320), (260, 390), (110, 350)], fill=BELLY, outline=EDGE)
d.polygon([(220, 140), (290, 40), (340, 150)], fill=PLATE, outline=EDGE)
d.polygon([(200, 330), (230, 430), (290, 340)], fill=PLATE, outline=EDGE)
# armour plates
for x in range(150, 390, 48):
    d.rounded_rectangle((x, 160 + abs(x - 270) // 6, x + 36, 250), radius=8, fill=PLATE, outline=EDGE)
# jaw, teeth and eye
d.polygon([(40, 270), (120, 285), (190, 330), (120, 345)], fill=(25, 60, 85, 255), outline=EDGE)
for k in range(5):
    x = 60 + k * 26
    d.polygon([(x, 275 + k * 6), (x + 12, 275 + k * 6), (x + 6, 300 + k * 6)], fill=(245, 250, 255, 255))
d.ellipse((98, 205, 132, 239), fill=(230, 255, 250, 255), outline=EDGE)
d.ellipse((110, 215, 128, 233), fill=(255, 80, 90, 255))
im.save("assets/sprites/boss/storm_shark.png")
