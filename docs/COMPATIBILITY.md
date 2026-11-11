# Compatibility and alpha status

## Supported release target

**0.1.0-alpha targets the Forever client with interface number 16001.** Retail,
other Classic clients and Windows gameplay have not completed acceptance. Editing
the TOC interface number alone does not establish compatibility.

The reticle/mouselook behavior has been exercised in the author's existing
Forever gameplay setup. The new single-folder standalone UI consolidation has
not completed its full live acceptance. Development screenshots are component
examples from that existing setup, not proof that every standalone screen has
been accepted. Lua/package checks establish load syntax and artifact integrity,
not combat, visual or interaction parity.

## Optional integrations

| Component | Integration |
| --- | --- |
| Plater | Nameplate behavior and optional icon styling; normally provides LibRangeCheck-3.0. |
| LibRangeCheck-3.0 | Conservative melee and friendly/NPC proximity checks; cues stay hidden if unavailable. Not bundled. |
| DynamicCam | Optional camera framing. Explicit setup creates a separate profile; restore returns to the saved source profile. |

oUF, LibDispel, LibStub and the licensed font are included. ElvUI, BenikUI,
ProjectAzilroka, MoveAny, AddOnSkins, Bagnon, Masque, Pawn and GSE are not required.
Disable competing owners of the same unit frames, bars or mouselook while trying
the consolidated addon. Keep their saved settings for rollback.

## Settings and migration

The package installs as `SquanchOn` and saves to `SquanchOnDB`. Existing `SQMS_*`
binding identifiers and the `SquancherMouselookSuite` global alias are retained
for compatibility. Clean installs use project defaults.

Import fields can accept semantic unit-frame, tooltip, window and auxiliary-panel
settings once; later user edits remain authoritative. Private migration/install
scripts and personal exports are deliberately outside this repository. The addon
does not automatically recover an arbitrary ElvUI profile from someone else's setup.

## Remaining acceptance

- The new original unit-frame editor does not promise every advanced ElvUI or
  BenikUI feature. Specialized aura predicates/sorting, unused aura-panel bar
  mode and arbitrary legacy visibility macros need separate acceptance.
- Range results are guarded; unavailable unit-frame range data leaves a frame
  visible. Restricted client values are passed to native widgets where supported.
- Range markers need live cross-class/combat acceptance; native spell checks
  describe range rather than cooldown, resources, form or line-of-sight readiness.
- Full combat and held-key focus-loss behavior, Windows input and other clients
  remain unverified. Native cursor return can leave a small residual rotation.
- The historical external interact-on-down / target-on-up chord is not included.
  Native mouselook, the right-held gate and cursor return do not need that helper.

Game-native art, original geometric markers and licensed PT Sans Narrow replace
unlicensed legacy media. Typography and some indicator artwork therefore differ
from the author's older setup. The native warning sound replaces the old audio file.

Report reproducible issues with client build/interface, addon version, optional
addons, input sequence, expected/observed behavior and a sanitized error or image.
Do not upload entire `WTF` directories or private account exports.
