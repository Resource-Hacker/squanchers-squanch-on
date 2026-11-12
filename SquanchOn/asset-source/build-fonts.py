#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Build the Squanch layout fonts from openly licensed upstream fonts.

Each output is a modified version of one SIL OFL 1.1 font: its outlines are
scaled and respaced so text occupies the same space as in the layout the
author's original setup used. The numbers below are layout measurements only
(heights, advance widths, line metrics, per 1000 units). No outline, hinting,
table or name of any other font is read or copied; the build needs nothing but
the upstream files named on the command line.

    python3 build-fonts.py OUTDIR \
        --redhatdisplay 'RedHatDisplay[wght].ttf' --orbitron 'Orbitron[wght].ttf' \
        --amarante Amarante-Regular.ttf --comicneue ComicNeue-BoldItalic.ttf

Upstream files: https://github.com/google/fonts/tree/main/ofl/<family>.
Requires fontTools >= 4.40. The outputs stay under the SIL OFL 1.1.
"""
import argparse
import math
import os
import unicodedata
import zlib

from fontTools.pens.recordingPen import DecomposingRecordingPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont, newTable
from fontTools.ttLib.tables import otTables
from fontTools.ttLib.ttVisitor import TTVisitor
from fontTools.varLib import instancer

# Advance widths for U+0020..U+007E; None where the layout defines no width.
FACES = {
    'highway': dict(
        source='redhatdisplay', axes={'wght': 900}, family='Squanch Highway', file='SquanchHighway.ttf',
        base='Red Hat Display', cap=692, xh=541, asc=729, hhea=(954, -192, 29), typo=(768, -232, 57), win=(954, 192),
        adv=[318, 199, 310, 565, 475, 677, 662, 148, 263, 265, 433, 377, 209, 392, 176, 372, 578, 256, 556, 554,
             578, 584, 582, 536, 582, 581, 183, 210, 465, 409, 475, 470, 709, 616, 594, 593, 610, 475, 448, 623,
             578, 207, 512, 583, 486, 723, 592, 641, 560, 640, 601, 595, 517, 580, 616, 847, 644, 606, 515, 227,
             371, 228, 372, 551, 238, 505, 516, 477, 501, 513, 262, 509, 479, 206, 227, 484, 207, 755, 498, 518,
             503, 514, 349, 463, 340, 487, 508, 703, 561, 509, 494, 312, 145, 311, 520]),
    'round': dict(
        source='redhatdisplay', axes={'wght': 700}, family='Squanch Round', file='SquanchRound.ttf',
        base='Red Hat Display', cap=700, xh=500, asc=714, hhea=(911, -209, 27), typo=(714, -205, 53), win=(911, 209),
        adv=[274, 175, 271, 572, 404, 733, 684, 161, 297, 296, 399, 462, 209, 363, 174, 433, 484, 284, 466, 442,
             487, 432, 472, 458, 469, 473, 181, 213, 442, 502, 452, 407, 797, 633, 480, 610, 602, 430, 396, 612,
             585, 172, 317, 542, 397, 729, 614, 709, 458, 701, 513, 471, 498, 568, 627, 899, 614, 565, 570, 251,
             433, 251, 472, 498, 273, 444, 489, 461, 490, 477, 354, 502, 449, 172, 320, 446, 256, 725, 468, 529,
             490, 490, 308, 394, 326, 467, 495, 692, 507, 505, 486, 272, 170, 271, 481]),
    # `glyphs` selects upstream's own alternate drawings (and its circumflex for the missing caret).
    'square': dict(
        source='orbitron', axes={'wght': 900}, family='Squanch Square', file='SquanchSquare.ttf', flex=0.4,
        glyphs={'I': 'I.alt', 'J': 'J.alt', 'V': 'V.alt3', 'W': 'W.alt4', 'Y': 'Y.alt', 'w': 'w.alt',
                '^': 'circumflex'},
        base='Orbitron', cap=523, xh=416, asc=550, hhea=(603, -172, 36), typo=(603, -172, 36), win=(724, 172),
        adv=[343, 217, 330, 627, 522, 638, 633, 199, 292, 300, 411, 519, 175, 493, 201, 467, 419, 409, 407, 417,
             427, 428, 427, 417, 419, 421, 201, 209, 405, 533, 407, 530, 688, 627, 635, 638, 622, 638, 634, 629,
             629, 540, 545, 626, 535, 626, 627, 638, 629, 642, 629, 629, 519, 634, 617, 634, 612, 638, 625, 329,
             486, 325, 529, 570, 263, 524, 531, 525, 523, 523, 396, 523, 523, 210, 208, 477, 204, 631, 523, 527,
             523, 535, 422, 523, 419, 521, 479, 629, 509, 521, 527, 407, 184, 411, 569]),
    # `bounce` leans and lifts each letter by a fixed pseudo-random amount (degrees, units).
    'bolt': dict(
        source='amarante', axes=None, family='Squanch Bolt', file='SquanchBolt.ttf', bounce=(4.0, 30),
        base='Amarante', cap=678, xh=496, asc=733, hhea=(803, -200, 0), typo=(803, -190, 0), win=(803, 190),
        adv=[342, 176, 364, None, 451, 745, None, 176, 300, 300, 376, 416, 229, 483, 229, 451, 487, 288, 443,
             419, 531, 487, 451, 531, 419, 451, 247, 241, None, 483, None, 443, None, 505, 419, 487, 487, 441,
             383, 487, 505, 203, 487, 492, 527, 704, 575, 487, 408, 487, 383, 451, 623, 487, 590, 703, 523, 498,
             516, None, 451, None, 279, None, None, 279, 293, 274, 311, 274, 315, 348, 325, 176, 179, 395, 160,
             453, 298, 288, 336, 336, 232, 262, 202, 293, 279, 443, 362, 336, 344, None, 288, None, None]),
    # `caps` draws every lowercase letter as its capital, as an all-capitals comic face does.
    'comic': dict(
        source='comicneue', axes=None, family='Squanch Comic', file='SquanchComic.ttf', caps=True,
        base='Comic Neue', cap=652, xh=652, asc=652, hhea=(661, -158, 0), typo=(661, -158, 0), win=(1095, 279),
        adv=[375, 223, 343, 474, 426, 596, 513, 197, 397, 396, 371, 356, 197, 438, 216, 373, 499, 233, 517, 503,
             467, 509, 474, 465, 483, 473, 208, 221, 366, 450, 365, 473, 703, 553, 560, 530, 549, 529, 457, 574,
             541, 507, 519, 518, 507, 737, 562, 533, 466, 513, 585, 533, 544, 501, 504, 639, 525, 468, 518, 379,
             374, 380, 359, 566, 170, 521, 559, 518, 509, 530, 432, 531, 536, 229, 518, 542, 436, 646, 523, 551,
             446, 521, 572, 531, 517, 528, 449, 669, 542, 469, 540, 345, 209, 344, 522]),
}
SAMPLE = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
FLEX = 0.14  # how far one glyph's width factor may leave the face's overall factor
DROP = ('fpgm', 'prep', 'cvt ', 'hdmx', 'VDMX', 'LTSH', 'DSIG', 'STAT', 'MVAR', 'HVAR', 'BASE', 'meta', 'FFTM')
OFL = ('This Font Software is licensed under the SIL Open Font License, Version 1.1. '
       'This license is available with a FAQ at: https://openfontlicense.org')


class Scaler(TTVisitor):
    def __init__(self, kx, ky):
        self.kx, self.ky = kx, ky


@Scaler.register_attrs((
    (otTables.ValueRecord, ('XAdvance', 'XPlacement', 'YAdvance', 'YPlacement')),
    (otTables.Anchor, ('XCoordinate', 'YCoordinate')),
))
def visit(visitor, obj, attr, value):
    setattr(obj, attr, round(value * (visitor.kx if attr.startswith('X') else visitor.ky)))


def top(glyphs, name):
    pen = DecomposingRecordingPen(glyphs)
    glyphs[name].draw(pen)
    return max(p[1] for _, pts in pen.value for p in pts if p is not None)


def build(face, source, target):
    font = TTFont(source)
    if 'fvar' in font:
        axes = {axis.axisTag: axis.defaultValue for axis in font['fvar'].axes}
        axes.update(face['axes'] or {})
        instancer.instantiateVariableFont(font, axes, inplace=True)
    for table in font['cmap'].tables:
        for char, name in face.get('glyphs', {}).items():
            table.cmap[ord(char)] = name
    cmap = font.getBestCmap()
    glyphs, hmtx, glyf = font.getGlyphSet(), font['hmtx'], font['glyf']
    width = {name: hmtx[name][0] for name in font.getGlyphOrder()}
    ky = face['cap'] / top(glyphs, cmap[ord('H')])
    wanted = {chr(32 + i): value for i, value in enumerate(face['adv']) if value is not None}
    overall = sum(wanted[c] for c in SAMPLE) / sum(width[cmap[ord(c)]] * ky for c in SAMPLE)
    kx = ky * overall
    # Lowercase heights: the x-height and ascender move separately from the capitals.
    xh0, asc0 = top(glyphs, cmap[ord('x')]) * ky, top(glyphs, cmap[ord('l')]) * ky
    xh1, asc1 = (xh0, asc0) if face.get('caps') else (face['xh'], face['asc'])

    def lower(y):
        if y <= 0:
            return y
        if y <= xh0:
            return y * xh1 / xh0
        return xh1 + (y - xh0) * (asc1 - xh1) / (asc0 - xh0)

    codes = {}
    for code, name in sorted(cmap.items()):
        codes.setdefault(name, code)
    rebuilt, metrics = {}, {}
    for name in font.getGlyphOrder():
        code = codes.get(name)
        char = chr(code) if code is not None else ''
        root = unicodedata.normalize('NFD', char)[:1]
        capital = cmap.get(ord(char.upper())) if face.get('caps') and len(char.upper()) == 1 else None
        drawn = capital or name
        record = DecomposingRecordingPen(glyphs)
        glyphs[drawn].draw(record)
        xs = [p[0] for _, points in record.value for p in points if p is not None]
        factor, advance = kx, width[drawn] * kx
        shift = 0.0
        if root in wanted and width[drawn]:
            base = cmap[ord(root.upper() if capital else root)]
            flex = face.get('flex', FLEX)
            share = wanted[root] / width[base]
            factor = min(max(share, kx * (1 - flex)), kx * (1 + flex))
            if root == char or width[drawn] == width[base]:
                advance = wanted[root]
            else:
                advance = width[drawn] * factor
            left, right = (min(xs), width[drawn] - max(xs)) if xs else (0, 0)
            if xs and left >= 0 and right >= 0:
                # Keep the drawing inside its new width and split the rest as upstream did.
                ink = max(xs) - min(xs)
                factor = min(factor, advance * 0.96 / ink) if ink else factor
                spare = advance - ink * factor
                shift = (spare * left / (left + right) if left + right else spare / 2) - left * factor
            else:
                shift = (advance - width[drawn] * factor) / 2
        small = char != '' and unicodedata.category(char) == 'Ll' and not face.get('caps')
        lean = lift = 0.0
        if face.get('bounce') and char and unicodedata.category(char)[0] == 'L':
            seed = zlib.crc32(root.encode())
            lean = math.tan(math.radians(face['bounce'][0] * ((seed % 201) / 100 - 1)))
            lift = face['bounce'][1] * ((seed // 201 % 201) / 100 - 1)
        middle = face['xh'] / 2

        def place(point):
            if point is None:
                return None
            x, y = point[0] * factor + shift, point[1] * ky
            if small:
                y = lower(y)
            return round(x + (y - middle) * lean), round(y + lift)

        pen = TTGlyphPen(None)
        for operator, points in record.value:
            getattr(pen, operator)(*[place(p) for p in points])
        glyph = pen.glyph()
        rebuilt[name] = glyph
        left = int(glyph.coordinates.calcBounds()[0]) if glyph.numberOfContours > 0 else 0
        metrics[name] = (round(advance), left)
    for name, glyph in rebuilt.items():
        glyf[name] = glyph
        hmtx[name] = metrics[name]

    for tag in DROP:
        if tag in font:
            del font[tag]
    for tag in ('GPOS',):
        if tag in font:
            Scaler(kx, ky).visit(font[tag].table)
    if 'kern' in font:
        for table in font['kern'].kernTables:
            for pair in table.kernTable:
                table.kernTable[pair] = round(table.kernTable[pair] * kx)
    gasp = font['gasp'] = newTable('gasp')
    gasp.gaspRange = {0xFFFF: 0x000A}
    head, hhea, os2, post = font['head'], font['hhea'], font['OS/2'], font['post']
    head.unitsPerEm = 1000
    head.flags &= ~0x0018
    hhea.ascent, hhea.descent, hhea.lineGap = face['hhea']
    os2.sTypoAscender, os2.sTypoDescender, os2.sTypoLineGap = face['typo']
    os2.usWinAscent, os2.usWinDescent = face['win']
    os2.fsSelection &= ~0x0080  # line spacing follows hhea, as measured
    os2.fsType = 0
    os2.achVendID = 'NONE'
    if os2.version >= 2:
        os2.sxHeight, os2.sCapHeight = face['xh'], face['cap']
    for field in ('ySubscriptXSize', 'ySubscriptYSize', 'ySubscriptXOffset', 'ySubscriptYOffset',
                  'ySuperscriptXSize', 'ySuperscriptYSize', 'ySuperscriptXOffset', 'ySuperscriptYOffset',
                  'yStrikeoutSize', 'yStrikeoutPosition'):
        setattr(os2, field, round(getattr(os2, field) * ky))
    os2.xAvgCharWidth = round(sum(m[0] for m in metrics.values()) / len(metrics))
    post.underlinePosition = round(post.underlinePosition * ky)
    post.underlineThickness = round(post.underlineThickness * ky)

    names = font['name']
    copyright = names.getDebugName(0) or ''
    version = (names.getDebugName(5) or '').split(';')[0]
    names.names = []
    family, postscript = face['family'], face['family'].replace(' ', '') + '-Regular'
    for identifier, text in (
        (0, copyright + ' Modified version Copyright 2026 The Squanch-On contributors.'),
        (1, family), (2, 'Regular'), (3, postscript + ';1.000'), (4, family), (5, 'Version 1.000'),
        (6, postscript),
        (10, 'Modified version of %s (%s): outlines rescaled and respaced, hinting removed, renamed. '
             'See FONTLOG.txt.' % (face['base'], version)),
        (13, OFL), (14, 'https://openfontlicense.org'),
    ):
        names.setName(text, identifier, 3, 1, 0x409)
        names.setName(text, identifier, 1, 0, 0)
    head.fontRevision = 1.0
    head.modified = head.created  # reproducible
    font.recalcTimestamp = False
    font.save(target)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('outdir')
    for source in sorted({face['source'] for face in FACES.values()}):
        parser.add_argument('--' + source, required=True, help='upstream %s font file' % source)
    arguments = parser.parse_args()
    for face in FACES.values():
        target = os.path.join(arguments.outdir, face['file'])
        build(face, getattr(arguments, face['source']), target)
        print(target)


if __name__ == '__main__':
    main()
