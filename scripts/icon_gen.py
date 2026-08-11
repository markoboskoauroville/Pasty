#!/usr/bin/env python3
"""Regenerate assets/icon_1024.png.

The mark is the Mantra soundwave, measured column by column off the original
logo and rebuilt as rounded bars on a baseline. Edit BARS to reshape it.

    python3 scripts/icon_gen.py && bash scripts/make_icon.sh
"""
from PIL import Image, ImageDraw
import pathlib

S, SS = 1024, 4
W = S * SS

# (source_x, row_min, row_max) on the original 39x22 logo grid
BARS = [(12, 11, 12), (13, 11, 11), (14, 9, 11), (15, 9, 14), (16, 9, 14),
        (17, 10, 12), (18, 8, 11), (19, 7, 17), (20, 6, 17), (21, 6, 15),
        (22, 10, 13), (23, 9, 13), (24, 8, 14), (25, 9, 14), (26, 12, 13)]
X0, X1 = 11, 28
ROW_C = 11.5

ORANGE = (210, 105, 30, 255)          # dark orange
BG_TOP, BG_BOT = (24, 24, 27), (9, 9, 11)

img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

margin = W * 0.085
corner = (W - margin * 2) * 0.225
plate = Image.new("RGBA", (W, W), (0, 0, 0, 0))
pd = ImageDraw.Draw(plate)
for y in range(int(margin), int(W - margin)):
    t = (y - margin) / (W - 2 * margin)
    c = tuple(int(BG_TOP[i] + (BG_BOT[i] - BG_TOP[i]) * t) for i in range(3))
    pd.line([(0, y), (W, y)], fill=c + (255,))
mask = Image.new("L", (W, W), 0)
ImageDraw.Draw(mask).rounded_rectangle([margin, margin, W - margin, W - margin],
                                       radius=corner, fill=255)
img.paste(plate, (0, 0), mask)

unit = (W * 0.70) / (X1 - X0)
cx = cy = W / 2
px = lambda sx: cx + (sx - (X0 + X1) / 2) * unit
py = lambda sy: cy + (sy - ROW_C) * unit

bar_w = unit * 0.72
bl = unit * 0.30
d.rounded_rectangle([px(X0) - bl / 2, py(12) - bl / 2, px(X1) + bl / 2, py(12) + bl / 2],
                    radius=bl / 2, fill=ORANGE)
for sx, r0, r1 in BARS:
    x, top, bot = px(sx), py(r0), py(r1 + 1)
    if bot - top < bar_w:
        bot = top + bar_w
    d.rounded_rectangle([x - bar_w / 2, top, x + bar_w / 2, bot],
                        radius=bar_w / 2, fill=ORANGE)

out = pathlib.Path(__file__).resolve().parent.parent / "assets" / "icon_1024.png"
out.parent.mkdir(exist_ok=True)
img.resize((S, S), Image.LANCZOS).save(out)
print("wrote", out)
