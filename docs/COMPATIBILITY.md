# Compatibility and rewrite status

## Client and evidence

**0.3.0-rewrite targets Forever interface 16001 and is only partly verified.**
It has been checked live solo, out of combat, with the player targeting
themselves. Hostile targets, debuffs, combat, pet, party/raid frames, the tooltip
and the settings editor have not been verified in this rewrite. Retail, other
Classic clients and Windows gameplay are also unverified. Changing a TOC number
does not establish compatibility.

The reticle control comes from the author's working gameplay setup. The
0.1.0-alpha unit-frame replacement was rejected for visual differences. An
intermediate 0.2.0-candidate used original ElvUI/BenikUI engines; this 0.3 rewrite
supersedes that packaging approach with independently written behavior. Acceptance
of the original-engine setup does not validate this new renderer.

Lua syntax, executable load dependencies and reuse hashes are checked by the
packager. Those checks establish source/artifact integrity, not matching
appearance or working controls. The existing gameplay
images show earlier component examples; their [provenance](images/README.md)
remains explicit and does not certify the rewrite.

## Runtime ownership

The package is one complete `SquanchOn/` addon; no other addon is required. It
embeds separately licensed oUF and LibDispel plus public-domain LibStub, the
GPL-2.0 Horde reticle, and its fonts and textures. Squanch-On owns frame
layout, buff and debuff icons, its settings editor, tooltip presentation,
reticle/mouselook and native UI adapters. oUF owns the secure unit-frame machinery and element lifecycle.
ElvUI and BenikUI engines, original options addons and original profile managers
are neither included nor required.

Blizzard continues to own tooltip content, item comparisons, native health values
and their handlers. Squanch-On's tooltip adapter changes presentation and default
anchoring; it does not recreate ElvUI's custom content extensions. Native item
use, sorting and deposits likewise remain with Blizzard's bags and bank.

Squanch-On has its own camera: every DynamicCam standard setting, zoom curves,
eased wheel zoom and situations built from DynamicCam's built-in conditions. It
does not run while DynamicCam is loaded, so DynamicCam must be disabled
(`/sqms camera takeover`). A DynamicCam profile is imported once; situations
with hand-written Lua conditions are kept as data and stay inactive, and of the
hide-interface options only the whole-interface fade is implemented. None of
this has been accepted in game yet. Plater remains an optional separate
integration. The bundled
LibRangeCheck-3.0 provides conservative melee/proximity cues; unavailable
checks hide those cues. Replacement native window and minimap surfaces
need their own visual and interaction checks.

## Buff and debuff icons

Squanch-On draws its own icons on one line above the player and target frames:
on the player, debuffs on the left and buffs on the right; on the target, buffs
on the left and debuffs on the right. A gap separates the halves and overflow
stacks upward. Two movable bars, "Buff bar" and "Debuff bar" in `/sqedit`,
replace the game's own buff and debuff rows. `/sqauras [count]` fills the rows
with placeholder icons to judge spacing; run it again to return to live auras.

Temporary weapon enchants are not shown on the buff bar. The separate proc,
enhancement and cooldown tracker panels are currently off. Only buffs on the
player and a self-target have been seen live; debuffs and hostile-target auras
are unverified.

## Settings and supported controls

Suite settings and rewritten unit-frame profiles live in `SquanchOnDB`. Original
`SQMS_*` bindings and the `SquancherMouselookSuite` global alias remain for
compatibility. A first run with no saved settings starts from the author's
layout (`SquanchOn/DefaultProfile.lua`). Its positions were authored on a
5120x1440 display; other resolutions may need `/sqedit`. An existing
`SquanchOnDB` is kept as it is. The layout includes nested settings and fields
the rewrite does not implement; they are kept as data, which does not mean every
field has the original engine's behavior. The addon does not read or migrate
ElvUI databases. It reads the DynamicCam profile in use once, to import camera
settings, and never writes DynamicCam's saved variables.

`/squanchon` and `/squancher` open a new capability-limited settings editor,
not the native ElvUI editor. Its controls are selected from the renderer's actual
capability map. Current groups include frame size/orientation, portraits, power
and cast layout, supported unit text/custom text, group layout and sorting.
Profiles can be selected or copied; `/sqedit` provides the supported movers.
Validated setting changes defer protected updates during combat. Specialized
aura filters, all-class resource behavior and the complete native options catalog
are not claimed as reproduced. Unsupported imported settings stay preserved;
unsupported controls are not presented as working settings.

`/squanchon tooltip` edits the tooltip presentation profile: text sizes,
opacity, cursor/fixed anchoring and health-bar height. `/sqedit` can move its
fixed anchor. Native tooltip content and comparison logic remain independent of
those presentation controls. Neither the settings editor nor the tooltip has
been verified live in this rewrite.

## Fonts, textures and reticle

Text uses bundled SIL OFL 1.1 fonts: PT Sans Narrow Bold, Overpass Bold, Afacad
Medium, Oxanium Bold and Almendra Bold. They stand in for the author's original
fonts (Expressway, Homizio, Forced Square, Harry P), which are not distributed,
so text shapes are close but not identical. Frame textures are original and
generated; ready-check icons use the game's own files. The Horde reticle ships
exactly, under GPL-2.0. See [installation](LOCAL-ASSEMBLY.md) and
[component licenses](COMPONENT-LICENSES.md).

## Remaining acceptance

- Check hostile targets, debuffs, pet, target-of-target and enabled group frames,
  portraits, casts, text/tag output, fade behavior and decoration. Inspect actual
  settings changes and mover behavior.
- Exercise combat, group/raid, class resources, specialized filters and range
  behavior in their actual contexts. A solo out-of-combat screenshot cannot
  certify them.
- Verify tooltip border/font/anchor appearance with fresh captures while checking
  native content and comparisons. Custom ElvUI content extensions are outside
  the reproduced presentation surface.
- Confirm physical held-key, right-held mouseover, cursor return and focus-loss
  behavior. Windows input remains a separate check. The historical external
  interact-on-down / target-on-up helper is not included.
- Range describes reach, not cooldown, resources, form or line of sight.

Report the exact client/interface, version, input sequence and expected/observed
behavior with a sanitized error or image. Never upload full WTF directories or
personal settings.
