# Original Squancher target marker

The public component consists of TargetCrosshairs.lua, the newly generated
circle.tga and arrows.tga, their SVG/generator source, and this documentation.
They were authored for Squancher on 2026-11-06 and are licensed under LICENSE.

The installed Crosshairs 12.0.7-local.11-forever1 was inspected as the owner's
functional and configuration reference. Its two images were viewed to understand
their approximate purpose: a ring and four rotating corner pointers. Its local
health behavior and exact saved settings supplied the requested compatibility
specification. The new Lua file was independently written with different local
functions, rendering organization and event lifecycle; no upstream method body
or source comment was imported into the new implementation. Shared public WoW
API calls, necessary curve knot values, timing constants and setting names are
used to provide the requested behavior. This is not a claim of a clean-room
process or identical artwork.

The new images were constructed from numeric geometry by asset-source/generate.py.
The generator uses only Python's standard library, reads no input image, and
outputs both SVG source and uncompressed 32-bit TGA. Circle: center 64,64,
radius 46, stroke 2.5 on a 128x128 canvas. Arrows: four filled triangles whose
initial vertices are 58,10;70,10;64,24, rotated in 90-degree steps. Raster alpha
uses a 4x4 sample grid per pixel. No fonts, image tracing, upstream pixels or
third-party drawing assets are used.

Semlar's Crosshairs remains separately owned. Its project currently lists
All Rights Reserved: https://www.curseforge.com/wow/addons/crosshairs . This
component does not relicense that project or claim permission to publish it.

No historical reference package or third-party image is included in this project.
