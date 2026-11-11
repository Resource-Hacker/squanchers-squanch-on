# Compatibility and candidate status

## Client and acceptance

**0.2.0-candidate targets Forever interface 16001.** Retail, other Classic
clients and Windows gameplay have not completed acceptance. Changing a TOC
number does not establish compatibility.

The reticle control comes from the author's working gameplay setup. The previous
0.1.0-alpha unit-frame rewrite was rejected for visual differences. This candidate
uses the exact original native renderer, full settings schema and options, fonts,
textures and Benik decoration. Syntax, dependency and hash checks establish
artifact integrity; fresh in-game comparison is still required before calling
this candidate equivalent.

## Runtime components

The local assembly contains original-name `ElvUI`, `ElvUI_Libraries`,
`ElvUI_Options`, `ElvUI_BenikUI`, and `SquanchOn`. It requires the scoped original
runtime used by this project. A source-only upstream ElvUI ZIP lacks packaged
external libraries and the project's scope adapters, so it is not a substitute.
The local assembler validates those inputs and never changes the source install.

ElvUI owns unit frames, secure unit handling, native profiles/movers, filters and
tooltips. Benik owns its original unit decoration. Squanch-On owns its reticle,
mouselook, shared borders and native UI adapters. It loads no second oUF tree.
The full original options addon remains on demand. Other ElvUI owners stay scoped
off; a stock broad ElvUI activation would conflict with the native surfaces.

Plater and DynamicCam remain optional separate integrations. Plater normally
provides LibRangeCheck-3.0 for conservative melee/proximity cues; unavailable
checks hide those cues. Native bags replace Bagnon, while native window, aura
and minimap adapters replace MoveAny/ProjectAzilroka surfaces. Their detailed
visual/interaction equivalence is a separate acceptance concern from unit frames.

## Settings

`SquanchOnDB` stores suite settings. Original `SQMS_*` bindings and the
`SquancherMouselookSuite` global alias remain compatible. Exact owner migration
copies the fresh suite database while preserving its receipts and independent
DynamicCam profile. It leaves native ElvUI databases and profile selection intact.
There is no reduced alpha schema conversion in the native renderer path.

Public source contains no personal profile or private settings export. The
owner-local assembly can include its existing private presentation seed. Keep
that assembled archive local. See [licenses](COMPONENT-LICENSES.md) and
[assembly](LOCAL-ASSEMBLY.md).

## Remaining acceptance limits

- Player, target, pet, target-of-target, casts, auras, borders, text and native
  options need fresh live comparison with the accepted original runtime.
- Combat/group/raid and cross-class range behavior require their actual contexts;
  an out-of-combat solo observation cannot certify them.
- Input keeps the native hardware cursor and right-held mouseover gate. Physical
  held-key/focus-loss behavior and Windows input remain separate checks.
- Range describes reach, not cooldown, resources, form or line of sight.
- The historical external interact-on-down / target-on-up helper is not included.
- Independent geometric target markers and the native warning sound retain the
  public project's licensed replacements. The optional private reticle import
  preserves the owner's original renderer, textures and warning sound locally.

Report exact client/interface, version, input sequence, expected/observed behavior
and a sanitized error/image. Never upload entire WTF directories or private
assembled archives.
