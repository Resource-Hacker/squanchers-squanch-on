# Compatibility and staged rewrite status

## Client and evidence

**0.3.0-rewrite targets Forever interface 16001 and is staged for review.**
Fresh live acceptance of this independent rewrite has not completed. Retail,
other Classic clients and Windows gameplay are also unverified. Changing a TOC
number does not establish compatibility.

The reticle control comes from the author's working gameplay setup. The
0.1.0-alpha unit-frame replacement was rejected for visual differences. An
intermediate 0.2.0-candidate used original ElvUI/BenikUI engines; this 0.3 rewrite
supersedes that packaging approach with independently written behavior. Acceptance
of the original-engine setup does not validate this new renderer.

Lua syntax, executable load dependencies, reuse hashes and private staging have
been checked. Those checks establish source/artifact integrity, not successful
game loading, matching appearance or working controls. The existing gameplay
images show earlier component examples; their [provenance](images/README.md)
remains explicit and does not certify the rewrite.

## Runtime ownership

The public package is one complete `SquanchOn/` addon. It embeds separately
licensed oUF and LibDispel plus public-domain LibStub. Squanch-On owns frame
layout, its settings editor, tooltip presentation, reticle/mouselook and native
UI adapters. oUF owns the secure unit-frame machinery and element lifecycle.
ElvUI and BenikUI engines, original options addons and original profile managers
are neither included nor required.

Blizzard continues to own tooltip content, item comparisons, native health values
and their handlers. Squanch-On's tooltip adapter changes presentation and default
anchoring; it does not recreate ElvUI's custom content extensions. Native item
use, sorting and deposits likewise remain with Blizzard's bags and bank.

Plater and DynamicCam remain optional separate integrations. Plater normally
provides LibRangeCheck-3.0 for conservative melee/proximity cues; unavailable
checks hide those cues. Replacement native window, aura and minimap surfaces
need their own visual and interaction checks.

## Settings and supported controls

Suite settings and rewritten unit-frame profiles live in `SquanchOnDB`. Original
`SQMS_*` bindings and the `SquancherMouselookSuite` global alias remain for
compatibility. The complete resolved local frame/tooltip configuration can be
preserved as data during an explicit migration, including nested settings and
fields the rewrite does not implement. Preservation does not mean every field
has the original engine's behavior. Original ElvUI databases and DynamicCam
profiles should remain separately backed up; neither public packaging nor private
media assembly migrates them.

`/squanchon` and `/squancher` open a new capability-limited settings editor,
not the native ElvUI editor. Its controls are selected from the renderer's actual
capability map. Current groups include frame size/orientation, portraits, power
and cast layout, supported unit text/custom text, group layout and sorting.
Profiles can be selected or copied; `/sqedit` provides the supported movers.
Validated setting changes defer protected updates during combat. Specialized
aura filters, all-class resource behavior and the complete native options catalog
are not claimed as reproduced. Unsupported imported settings stay preserved;
unsupported controls are not presented as working settings.

`/squanchon tooltip` edits the imported tooltip presentation profile when one is
available: text sizes, opacity, cursor/fixed anchoring and health-bar height.
`/sqedit` can move its fixed anchor. Native tooltip content and comparison logic
remain independent of those presentation controls. Public default operation does
not require a personal imported profile.

A separate local media overlay can supply exact original appearance assets and
reticle bytes. The public package uses its bundled font and game resources where
needed. Missing original assets and fallbacks remain a limit on visual matching.
See [local overlays](LOCAL-ASSEMBLY.md) and [component licenses](COMPONENT-LICENSES.md).

## Remaining acceptance

- Compare player, target, pet, target-of-target and enabled group frames, portraits,
  casts, auras, text/tag output, fade behavior and decoration against the current
  accepted reference. Inspect actual settings changes and mover behavior.
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
- Distinguish public replacement artwork/sound from any private original reticle
  overlay when reporting appearance or behavior.

Report the exact client/interface, version, input sequence and expected/observed
behavior with a sanitized error or image. Never upload full WTF directories,
personal settings or private overlay archives.
