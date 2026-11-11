#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Original elementary geometry. Reads no reference images, fonts or assets.
from pathlib import Path
import struct

DEST = Path(__file__).resolve().parent.parent / 'media' / 'native-indicators'
DEST.mkdir(parents=True, exist_ok=True)
SIZE = 64
SAMPLES = 4

def inside_polygon(x, y, points):
    odd = False
    last_x, last_y = points[-1]
    for px, py in points:
        if (py > y) != (last_y > y) and x < (last_x-px)*(y-py)/(last_y-py)+px:
            odd = not odd
        last_x, last_y = px, py
    return odd

shapes = {
    'diamond': [(32,0),(64,32),(32,64),(0,32)],
    'chevron': [(7,12),(32,33),(57,12),(57,27),(32,49),(7,27)],
    'pointer': [(10,9),(54,9),(32,55)],
}
for name, points in shapes.items():
    pixels = bytearray()
    for y in range(SIZE):
        for x in range(SIZE):
            hits = sum(inside_polygon(x+(sx+.5)/SAMPLES,y+(sy+.5)/SAMPLES,points)
                       for sy in range(SAMPLES) for sx in range(SAMPLES))
            pixels += bytes((255,255,255,round(255*hits/(SAMPLES*SAMPLES))))
    header = struct.pack('<BBBHHBHHHHBB',0,0,2,0,0,0,0,0,SIZE,SIZE,32,0x28)
    (DEST/(name+'.tga')).write_bytes(header+pixels)
