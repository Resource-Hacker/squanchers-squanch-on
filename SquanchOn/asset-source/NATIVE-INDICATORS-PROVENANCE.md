# Original indicator geometry

`generate-native-indicators.py` and its three `media/native-indicators/*.tga`
outputs were independently authored for Squancher in 2026 and are MIT licensed.
The generator uses only Python's standard library. It reads no images, fonts or
external assets. Each64x64 image is uncompressed32-bit TGA with4x4 subpixel alpha
sampling. The source defines elementary polygon vertices for a diamond, a
V-shaped chevron and a downward triangle. No previous addon pixels, paths or
tracings appear in these outputs.

`ReticleConfig.lua` and the refactored original renderer reference Blizzard's
`Interface/Timer/Horde-Logo` and the native pet emblem by game resource path.
The nameplate Skull option references `UI-RaidTargetingIcon_8` the same way.
Those game-owned resources are not distributed in this package. Existing
`media/Crosshairs/circle.tga` and `arrows.tga` are the project's independently
created MIT geometry described in `LICENSES/TargetCrosshairs-PROVENANCE.md`.

The nameplate compatibility implementation retains the upstream MIT code notice
and `LICENSES/TargetNameplateIndicator-LICENSE.txt`. That license does not
cover its former image library, and no image from that library belongs in this
release. The47 old names remain only as settings-migration identifiers mapped
to new original/game artwork, preserving profile enablement and placement.
