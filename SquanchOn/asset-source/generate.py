#!/usr/bin/env python3
"""SPDX-License-Identifier: MIT
Original geometric art for Squancher, made from circles and triangles.
No input images, tracing, font, third-party rasterizer, or external assets.
Run from any directory; output remains inside this component's staging tree.
"""
from pathlib import Path
import math
import struct

ROOT = Path(__file__).resolve().parents[1]
MEDIA = ROOT / "media" / "Crosshairs"
MEDIA.mkdir(parents=True, exist_ok=True)
SIZE, SAMPLES = 128, 4


def triangle(angle):
    points = [(58, 10), (70, 10), (64, 24)]
    c, s = math.cos(angle), math.sin(angle)
    return [((x - 64) * c - (y - 64) * s + 64,
             (x - 64) * s + (y - 64) * c + 64) for x, y in points]


TRIANGLES = [triangle(i * math.pi / 2) for i in range(4)]


def contains(points, x, y):
    sides = []
    for i, (ax, ay) in enumerate(points):
        bx, by = points[(i + 1) % 3]
        sides.append((bx - ax) * (y - ay) - (by - ay) * (x - ax))
    return all(v >= 0 for v in sides) or all(v <= 0 for v in sides)


def save_tga(name, covered):
    # Uncompressed 32-bit BGRA, top-left origin, eight alpha bits.
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0,
                         0, 0, SIZE, SIZE, 32, 0x28)
    pixels = bytearray()
    for y in range(SIZE):
        for x in range(SIZE):
            count = sum(covered(x + (sx + 0.5) / SAMPLES,
                                y + (sy + 0.5) / SAMPLES)
                        for sy in range(SAMPLES) for sx in range(SAMPLES))
            pixels.extend((255, 255, 255, round(255 * count / SAMPLES ** 2)))
    (MEDIA / (name + ".tga")).write_bytes(header + pixels)


save_tga("circle", lambda x, y: abs(math.hypot(x - 64, y - 64) - 46) <= 1.25)
save_tga("arrows", lambda x, y: any(contains(points, x, y) for points in TRIANGLES))

circle = '<circle cx="64" cy="64" r="46" fill="none" stroke="white" stroke-width="2.5"/>'
arrows = "\n".join('<polygon fill="white" points="' +
                   " ".join(f"{x:.6g},{y:.6g}" for x, y in points) + '"/>'
                   for points in TRIANGLES)
for name, shapes in [("circle", circle), ("arrows", arrows)]:
    (ROOT / "asset-source" / (name + ".svg")).write_text(
        '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">\n'
        '<!-- Original Squancher geometric artwork; SPDX-License-Identifier: MIT -->\n'
        + shapes + "\n</svg>\n")

# Original dashed variant: 24 sectors, 58% duty, a radius-46 ring.
SIZE = 256
def dashed(x, y):
    x, y = x / 2 - 64, y / 2 - 64
    radius = math.hypot(x, y)
    phase = (math.atan2(y, x) / (2 * math.pi) * 24) % 1
    return 44 <= radius <= 48 and phase < .58
save_tga("circle-dashed", dashed)
