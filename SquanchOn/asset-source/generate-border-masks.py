#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Alpha masks for the gear-slot borders (owner, 2026-11-12).

The file names carry a version: the game keeps a texture it has loaded until
the client restarts, so a changed mask needs a new name to show after /reload.

The border art is cut from the game's own atlas at run time; these masks only
say which parts of it to keep. They are built from the measured contour that
DarkSkin.lua used to draw as ~17 separate textures per corner: one masked
texture per corner now does the same job, and every texture costs the game
time at each combat start and end.

Writes media/borders/slot-mask-v2.tga (whole 55-unit action slot: open except
the corner boxes) and
media/borders/corner-mask-v2-{TL,TR,BL,BR}.tga (13-unit panel corners).
"""
from pathlib import Path
from PIL import Image, ImageDraw

SCALE = 8  # pixels per half-unit of the 110-half-unit slot
OUT = Path(__file__).resolve().parent.parent / 'media' / 'borders'

# Row spans (y1, y2, x1, x2) in half-units within a 26-half-unit corner box.
CORNERS = {
    'TL': [(4,5,11,12),(5,6,9,13),(6,7,9,14),(7,8,8,15),(8,9,7,16),(9,11,5,26),(11,13,4,26),(13,15,5,26),(15,16,6,26),(16,17,7,26),(17,18,10,26),(18,21,10,18),(21,26,9,18)],
    'TR': [(5,6,10,13),(6,7,9,13),(7,8,9,14),(8,9,8,15),(9,10,6,26),(10,11,5,26),(11,13,4,26),(13,14,5,26),(14,15,6,26),(15,16,7,26),(16,17,8,26),(17,18,9,26),(18,21,10,18),(21,26,9,18)],
    'BL': [(4,5,11,12),(5,6,10,13),(6,7,9,14),(7,8,8,15),(8,9,7,16),(9,10,6,26),(10,11,5,26),(11,13,4,26),(13,14,5,26),(14,15,6,26),(15,16,7,26),(16,17,8,26),(17,18,9,26),(18,26,9,18)],
    'BR': [(5,6,10,13),(6,7,9,13),(7,8,8,14),(8,9,7,15),(9,10,7,26),(10,11,6,26),(11,13,4,26),(13,14,5,26),(14,15,6,26),(15,16,7,26),(16,17,8,26),(17,18,9,26),(18,26,9,18)],
}
# Six gold texels of the inward elbow that panels keep (half-units).
ELBOWS = [(18,19,18,21),(19,20,18,20),(20,21,18,19)]

def corner_boxes(name, origin_x, origin_y, size, extra=()):
    """Half-unit rectangles of one corner, mirrored into place."""
    left, top = name[1] == 'L', name[0] == 'T'
    for y1, y2, x1, x2 in list(CORNERS[name]) + list(extra):
        xa, xb = (x1, x2) if left else (size - x2, size - x1)
        ya, yb = (y1, y2) if top else (size - y2, size - y1)
        yield origin_x + xa, origin_y + ya, origin_x + xb, origin_y + yb

def save(boxes, half_units, path, open_except=None):
    side = half_units * SCALE
    # open_except: the mask is opaque everywhere except these boxes, where only
    # `boxes` are opaque. The straight edges then keep every pixel their texture
    # rectangle draws (a soft mask edge had thinned the outer rim row).
    image = Image.new('LA', (side, side), (255, 0 if open_except is None else 255))
    draw = ImageDraw.Draw(image)
    for x1, y1, x2, y2 in open_except or ():
        draw.rectangle([x1 * SCALE, y1 * SCALE, x2 * SCALE - 1, y2 * SCALE - 1], fill=(255, 0))
    for x1, y1, x2, y2 in boxes:
        draw.rectangle([x1 * SCALE, y1 * SCALE, x2 * SCALE - 1, y2 * SCALE - 1], fill=(255, 255))
    # Power-of-two output for the game: 256 for the slot, 64 for a corner,
    # downscaled smoothly so the mask edge stays soft like the drawn pieces.
    target = 512 if half_units > 64 else 128
    image = image.resize((target, target), Image.LANCZOS)
    image.convert('RGBA').save(path, compression='tga_rle')
    print('wrote', path, image.size)

OUT.mkdir(parents=True, exist_ok=True)
# Action slot: 110 half-units; four straight edges plus the four corners.
slot, corners = [], []
for name, ox, oy in (('TL', 0, 0), ('TR', 84, 0), ('BL', 0, 84), ('BR', 84, 84)):
    slot += list(corner_boxes(name, ox, oy, 26))
    corners.append((ox, oy, ox + 26, oy + 26))
save(slot, 110, OUT / 'slot-mask-v2.tga', open_except=corners)
# Panel corners: one 26-half-unit box each, with the elbow texels.
for name in CORNERS:
    save(list(corner_boxes(name, 0, 0, 26, ELBOWS)), 26, OUT / f'corner-mask-v2-{name}.tga')
