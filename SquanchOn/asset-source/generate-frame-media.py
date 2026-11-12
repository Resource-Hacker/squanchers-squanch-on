#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Original numerical constructions for unit-frame media. Reads no images or fonts.
from pathlib import Path
import struct

DEST = Path(__file__).resolve().parent.parent / 'media' / 'textures'
DEST.mkdir(parents=True, exist_ok=True)

def tga(name, width, height, pixel, dest=None):
    data = bytearray()
    for y in range(height - 1, -1, -1):  # bottom-up rows
        for x in range(width):
            r, g, b, a = pixel(x, y)
            data += bytes((b, g, r, a))
    header = struct.pack('<BBBHHBHHHHBB', 0, 0, 2, 0, 0, 0, 0, 0, width, height, 32, 8)
    (dest or DEST).mkdir(parents=True, exist_ok=True)
    ((dest or DEST) / name).write_bytes(header + data)

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

# Selectable status-bar faces. Grey level v goes to R, G and B and the bar colour
# tints it; t runs from the top row (0) to the bottom row (1). Faces constant
# along the bar are 32 x 32, patterned ones 256 x 32.
import math
H = 32
def smooth(t):
    return 196 - 54 * (t * t * (3 - 2 * t))
def tri(p):
    p %= 1.0
    return 1 - abs(2 * p - 1)
def noise(row, run):  # fixed integer hash, -1..1
    n = (row * 73856093) ^ (run * 19349663) ^ 0x5bd1e995
    n = (n * 1103515245 + 12345) & 0x7fffffff
    return (n >> 8) % 2001 / 1000.0 - 1
faces = {
    'bar-soft.tga': lambda t: 240 - 40 * t,
    'bar-deep.tga': lambda t: 250 - 120 * t,
    'bar-gloss.tga': lambda t: 150 - 22 * t + 105 * math.exp(-((t - .22) / .16) ** 2),
    'bar-glass.tga': lambda t: 230 - 60 * t if t < .5 else 170 - 40 * (t - .5),
    'bar-round.tga': lambda t: 140 + 115 * math.sin(math.pi * t) ** .6,
    'bar-groove.tga': lambda t: 230 - 85 * math.sin(math.pi * t),
}
for name, face in faces.items():
    tga(name, H, H, lambda x, y, face=face: (clamp(face(y / (H - 1))),) * 3 + (255,))
tga('bar-bevel.tga', H, H, lambda x, y: ((255 if y == 0 else 110 if y == H - 1 else 205),) * 3 + (255,))
tga('bar-lines.tga', H, H, lambda x, y: ((195 if y % 2 else 235),) * 3 + (255,))
tga('bar-underline.tga', H, H, lambda x, y: (255, 255, 255, 255 if y >= H - 4 else 70))
def stripes(x, y):
    band = sum(tri((x + (i + .5) / 4 + y + (j + .5) / 4) / 12) for i in range(4) for j in range(4)) / 16
    return (clamp(smooth(y / (H - 1)) * (.88 + .12 * band)),) * 3 + (255,)
tga('bar-stripes.tga', 256, H, stripes)
tga('bar-fade.tga', 256, H, lambda x, y: (clamp(255 * (.55 + .45 * x / 255)),) * 3 + (255,))
tga('bar-brushed.tga', 256, H, lambda x, y: (clamp(smooth(y / (H - 1)) + 9 * noise(y, x // 8)),) * 3 + (255,))

# Selectable borders, in the same eight-tile edge layout as the glow above.
# `inward` is the distance in pixels from the side that touches the framed area.
BORDERS = DEST.parent / 'borders'
def edge(name, size, paint, corner=max, samples=1):
    def at(u, v, tile):
        if tile in (0, 2):
            return paint(size - u)
        if tile in (1, 3):
            return paint(u)
        cx = size if tile in (4, 6) else 0
        cy = size if tile in (4, 5) else 0
        return paint(corner(abs(u - cx), abs(v - cy)))
    def pixel(x, y):
        total = [0.0] * 4
        for sy in range(samples):
            for sx in range(samples):
                value = at(x % size + (sx + .5) / samples, y + (sy + .5) / samples, x // size)
                for i in range(3):
                    total[i] += value[i] * value[3]
                total[3] += value[3]
        if not total[3]:
            return 255, 255, 255, 0
        return tuple(clamp(total[i] / total[3]) for i in range(3)) + (clamp(total[3] / samples / samples),)
    tga(name, 8 * size, size, pixel, BORDERS)
def line(*spans):  # (from, to, grey) bands measured inward-out
    def paint(inward):
        for start, stop, grey in spans:
            if start <= inward < stop:
                return grey, grey, grey, 255
        return 255, 255, 255, 0
    return paint
edge('border-pixel.tga', 8, line((0, 1, 255)))
edge('border-thin-bevel.tga', 8, line((0, 1, 150), (1, 2, 255)))
edge('border-double.tga', 8, line((0, 1, 255), (3, 4, 255)))
edge('border-rounded.tga', 8, line((3, 4, 255)), corner=math.hypot, samples=4)
edge('border-shadow.tga', T, lambda inward: (0, 0, 0, falloff(inward)), corner=math.hypot)

# Target rings that read as a status bar bent into a circle (TargetCrosshairs.lua).
# The ring keeps circle.tga's geometry (128 px, mean radius 46); across its
# thickness it repeats the bar face's 32 rows, bar top on the outer edge and bar
# bottom on the inner one, so the same vertex colour tints ring and bar alike.
# One file per face constant along the bar and per line thickness in texture
# pixels; patterned faces use the ring of their vertical ramp (see the Lua map).
# Texels outside the line keep the nearest end row's grey at zero opacity, so
# filtering fades the line out without pulling its end rows towards white.
RINGS = DEST.parent / 'Crosshairs'
RING, RADIUS, RING_SAMPLES, RING_WIDTHS = 128, 46, 4, (3, 5, 8, 12)
ring_rows = {name[4:-4]: [clamp(face(y / (H - 1))) for y in range(H)] for name, face in faces.items()}
ring_rows['smooth'] = [clamp(smooth(y / (H - 1))) for y in range(H)]
ring_rows['bevel'] = [255] + [205] * (H - 2) + [110]
ring_rows['flat'] = [255] * H
# The client's default status bar (Interface\TargetingFrame\UI-StatusBar) at
# mid length: its eight grey rows as measured, stretched as the client
# stretches them over a bar (linear between row centres).
DEFAULT_BAR = (136, 189, 216, 189, 144, 101, 122, 101)
def stretched(rows, t):
    v = min(max(t * len(rows) - .5, 0), len(rows) - 1)
    low = min(int(v), len(rows) - 2)
    return rows[low] + (rows[low + 1] - rows[low]) * (v - low)
ring_rows['default'] = [clamp(stretched(DEFAULT_BAR, (y + .5) / H)) for y in range(H)]
# The plate border is drawn inside the bar: the default two-pixel line on the
# default eleven-pixel bar covers this share of the face at either end.
RIM = 2 / 11
ring_rows['rim'] = [255] * H
for name, rows in sorted(ring_rows.items()):
    for width in RING_WIDTHS:
        def pixel(x, y, rows=rows, width=width, rim=name == 'rim'):
            total = count = 0
            for sy in range(RING_SAMPLES):
                for sx in range(RING_SAMPLES):
                    px, py = x + (sx + .5) / RING_SAMPLES - RING / 2, y + (sy + .5) / RING_SAMPLES - RING / 2
                    t = (RADIUS + width / 2 - math.hypot(px, py)) / width
                    if 0 <= t < 1 and not (rim and RIM <= t < 1 - RIM):
                        total += rows[int(t * H)]
                        count += 1
            if not count:
                t = (RADIUS + width / 2 - math.hypot(x + .5 - RING / 2, y + .5 - RING / 2)) / width
                grey = rows[0 if t < .5 else H - 1]
            else:
                grey = clamp(total / count)
            return grey, grey, grey, clamp(255 * count / RING_SAMPLES ** 2)
        tga(f'ring-{name}-{width}.tga', RING, RING, pixel, RINGS)

# The left half of each ring for the friendly mouseover ring (NameplateHoverRing.lua),
# which is a radial health bar: two copies of this texture, each shown through a
# frame that clips to one half of the ring and turned about the ring centre by
# the health fraction. The half is cut exactly on the centre column (no
# anti-aliasing across it), so two halves meet without a seam and the cut is
# the moving end of the filled arc.
for name, rows in sorted(ring_rows.items()):
    if name == 'rim':
        continue
    for width in RING_WIDTHS:
        def pixel(x, y, rows=rows, width=width):
            total = count = 0
            if x < RING // 2:
                for sy in range(RING_SAMPLES):
                    for sx in range(RING_SAMPLES):
                        px, py = x + (sx + .5) / RING_SAMPLES - RING / 2, y + (sy + .5) / RING_SAMPLES - RING / 2
                        t = (RADIUS + width / 2 - math.hypot(px, py)) / width
                        if 0 <= t < 1:
                            total += rows[int(t * H)]
                            count += 1
            if not count:
                t = (RADIUS + width / 2 - math.hypot(x + .5 - RING / 2, y + .5 - RING / 2)) / width
                grey = rows[0 if t < .5 else H - 1]
            else:
                grey = clamp(total / count)
            return grey, grey, grey, clamp(255 * count / RING_SAMPLES ** 2)
        tga(f'half-{name}-{width}.tga', RING, RING, pixel, RINGS)
