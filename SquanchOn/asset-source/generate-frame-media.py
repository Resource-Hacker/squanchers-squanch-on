#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Original numerical constructions for unit-frame media. Reads no images or fonts.
from pathlib import Path
import struct

DEST = Path(__file__).resolve().parent.parent / 'media' / 'textures'
DEST.mkdir(parents=True, exist_ok=True)

def tga(name, width, height, pixel):
    data = bytearray()
    for y in range(height - 1, -1, -1):  # bottom-up rows
        for x in range(width):
            r, g, b, a = pixel(x, y)
            data += bytes((b, g, r, a))
    header = struct.pack('<BBBHHBHHHHBB', 0, 0, 2, 0, 0, 0, 0, 0, width, height, 32, 8)
    (DEST / name).write_bytes(header + data)

def clamp(v):
    return max(0, min(255, int(round(v))))

# Soft glow edge in the eight-tile backdrop edge layout (left, right, top,
# bottom, then the four corners). Opacity eases from the inner side outward.
T = 16
def falloff(distance):
    t = max(0.0, 1.0 - distance / T)
    return clamp(255 * t * t * (3 - 2 * t))
def glow(x, y):
    tile, u, v = x // T, x % T + .5, y + .5
    if tile in (0, 2):
        d = T - u
    elif tile in (1, 3):
        d = u
    else:
        cx = T if tile in (4, 6) else 0
        cy = T if tile in (4, 5) else 0
        d = ((u - cx) ** 2 + (v - cy) ** 2) ** .5
    return 255, 255, 255, falloff(d)
tga('glow-edge.tga', 8 * T, T, glow)

# Status bar face: a gentle top-lit vertical ramp, constant along the bar.
def bar(x, y):
    t = y / 31
    v = clamp(196 - 54 * (t * t * (3 - 2 * t)))
    return v, v, v, 255
tga('bar-smooth.tga', 256, 32, bar)

# Role marks: shield, cross and blade silhouettes with a dark rim.
S, N = 32, 4
def polygon(points):
    def inside(x, y):
        odd, (lx, ly) = False, points[-1]
        for px, py in points:
            if (py > y) != (ly > y) and x < (lx - px) * (y - py) / (ly - py) + px:
                odd = not odd
            lx, ly = px, py
        return odd
    return inside
def grow(shape, amount):
    def inside(x, y):
        return any(shape(x + dx * amount, y + dy * amount)
                   for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1), (.7, .7), (-.7, .7), (.7, -.7), (-.7, -.7)))
    return inside
roles = {
    'role-tank.tga': (polygon([(6, 5), (26, 5), (26, 16), (16, 28), (6, 16)]), (70, 130, 220)),
    'role-healer.tga': (polygon([(12, 5), (20, 5), (20, 12), (27, 12), (27, 20), (20, 20), (20, 27), (12, 27), (12, 20), (5, 20), (5, 12), (12, 12)]), (80, 200, 90)),
    'role-dps.tga': (polygon([(16, 3), (21, 19), (26, 19), (26, 23), (18, 23), (18, 29), (14, 29), (14, 23), (6, 23), (6, 19), (11, 19)]), (215, 70, 60)),
}
for name, (shape, color) in roles.items():
    rim = grow(shape, 1.6)
    def pixel(x, y, shape=shape, rim=rim, color=color):
        fill = edge = 0
        for sy in range(N):
            for sx in range(N):
                px, py = x + (sx + .5) / N, y + (sy + .5) / N
                fill += shape(px, py)
                edge += rim(px, py)
        f, e = fill / N / N, edge / N / N
        return clamp(color[0] * f), clamp(color[1] * f), clamp(color[2] * f), clamp(255 * e)
    tga(name, S, S, pixel)
