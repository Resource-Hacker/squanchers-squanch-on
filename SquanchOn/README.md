# Squancher's Squanch-On — 0.1.0-alpha

**Keep the camera locked. Open mouseover only when you mean it.**

Move the mouse to steer. Hold right mouse to open real WoW mouseover at the
reticle, then release to close that gate while the camera stays locked. Hold the
free-cursor key for the interface; release to return to mouselook.

[Project and example images](https://github.com/Resource-Hacker/squanchers-squanch-on)
· [Reticle guide](https://github.com/Resource-Hacker/squanchers-squanch-on/blob/v0.1.0-alpha/docs/RETICLE.md)
· [Releases](https://github.com/Resource-Hacker/squanchers-squanch-on/releases)

## Install

This alpha targets **Forever interface 16001**. The integrated standalone UI is
still undergoing in-game acceptance. Retail, other Classic clients and Windows
input are not yet advertised as supported.

1. Back up `Interface/AddOns` and `WTF`, and close the game.
2. Place this exact `SquanchOn` folder in `Interface/AddOns`.
3. Confirm `Interface/AddOns/SquanchOn/SquanchOn.toc` exists.
4. Enable Squancher's Squanch-On and disable overlapping UI owners for evaluation.
   Preserve their saved settings until you accept the replacement.
5. Review the controls and native mouseover settings before combat.

Saved settings use `SquanchOnDB` in the normal `SavedVariables/SquanchOn.lua` file.
The download contains no account exports, saved macros or private profiles.

## Controls

| Control | Behavior |
| --- | --- |
| Right mouse held | Open centered mouseover while mouselook continues. |
| Right mouse released | Close centered mouseover without unlocking the camera. |
| Free-cursor key held (default Caps Lock / Up) | Temporarily use the native hardware cursor. |
| Free-cursor key released | Return to the center and resume mouselook. |
| `/sqms` / `/sqms off` | Mouselook help and status / disable control. |
| `/sqms nameplates` / `/sqms crosshairs` | Indicator settings. |
| `/squanchon` | Unit-frame settings and profiles. |
| `/sqedit` | Move and resize supported interface components. |
| `/squanchon tooltip` | Tooltip settings. |
| `/sqms camera` | Optional DynamicCam framing status. |

To replace the Caps Lock/Up preset, run `/sqms bindings off`, then assign
**Hold to release mouselook** in WoW's Key Bindings. This also removes the
historical F8/F9 helper overrides.

First-use setup enables native mouseover casting with no modifier and preserves
later user changes. Explicit-unit macros retain their targets. The gate does not
cast a spell or select a hard target. Native mouselook, the held mouseover gate and
cursor return need no external input helper. The author's historical combined-click
interact-on-down / target-on-up helper is not bundled.

## Range and integrations

The selected-target nameplate uses a dashed ring. Cardinal blocks indicate
conservative five-yard hostile melee reach; rotating triangles indicate a learned damage
or healing spell in range. Mend Pet and Health Funnel apply only to your own pet.

**LibRangeCheck-3.0**, normally provided by optional **Plater**, is needed for
five-yard melee and friendly/NPC proximity checks. It is not bundled; without it,
those cues stay hidden. Friendly ring rotation alone is proximity feedback,
not healing readiness. Unknown range stays hidden. Range does not guarantee
resources, cooldown, form or line of sight. Cross-class/combat acceptance remains
in progress.

Plater and DynamicCam are optional and installed separately. ElvUI, BenikUI,
ProjectAzilroka, MoveAny, AddOnSkins, Bagnon, Masque, Pawn and GSE are not dependencies.
[Compatibility and migration limits](https://github.com/Resource-Hacker/squanchers-squanch-on/blob/v0.1.0-alpha/docs/COMPATIBILITY.md).

## Source and attribution

To build **from a source checkout**, install Python 3, Git and Lua 5.1, then run
`python tools/package.py` in that checkout. Developer tools are intentionally not
inside this installation package. Packaging checks do not certify game behavior.

Original code and geometric artwork use [MIT](LICENSE). Bundled oUF, LibDispel,
LibStub and PT Sans keep their own licenses; Choonster's contribution is credited.
See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md), [reuse-manifest.json](reuse-manifest.json)
and `LICENSES/`. Game-provided art remains Blizzard's property. This project is
not endorsed by Blizzard or the referenced addon projects.
