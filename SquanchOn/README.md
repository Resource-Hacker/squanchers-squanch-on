# Squancher's Squanch-On — 0.3.0-rewrite

**Keep the camera locked. Open mouseover only when you mean it.**

Move the mouse to steer. Hold right mouse to open real WoW mouseover at the
reticle, then release to close that gate while the camera stays locked. Hold the
free-cursor key for the interface; release to return to mouselook.

[Project and example images](https://github.com/Resource-Hacker/squanchers-squanch-on)
· [Reticle guide](https://github.com/Resource-Hacker/squanchers-squanch-on/blob/main/docs/RETICLE.md)
· [Releases](https://github.com/Resource-Hacker/squanchers-squanch-on/releases)

## Install

Copy this `SquanchOn` folder into `Interface/AddOns`. Nothing else is required:
mouselook and reticle, camera, unit frames, nameplates, buff and debuff bars,
chat drawers, bag window, damage meter, settings, fonts and textures are all in
this one folder. Plater and DynamicCam are not needed. It targets **Forever interface 16001**.

With no saved settings, the first login starts from the author's layout. It was
arranged on a 5120x1440 display; on other resolutions use `/sqedit` to move
things. Settings live in `SquanchOnDB` as profiles; one profile is selected per
character, and settings from an earlier version are migrated at first login
with a backup kept in the saved file.

The author has checked this version live only solo and out of combat on the
Forever client. Combat (including nameplates on hostile mobs, their cast bars,
auras and threat colours), hostile-target debuffs, pet/party/raid frames,
profile switching, export and import, theme recolouring, the camera while
mounted or in combat, bag interactions beyond opening the window, the meter in
combat and other resolutions still need verification.

## Controls

| Control | Behavior |
| --- | --- |
| Right mouse held | Open centered mouseover while mouselook continues. |
| Right mouse released | Close centered mouseover without unlocking the camera. |
| Free-cursor key held (default Caps Lock / Up) | Temporarily use the native hardware cursor. |
| Free-cursor key released | Return to the center and resume mouselook. |
| `/sqms` / `/sqms off` | Mouselook help and status / disable control. |
| `/sqms nameplates` / `/sqms crosshairs` | Indicator settings. |
| `/squanchon` | The settings window: category tree, search, undo, reset, profiles. |
| `/sqedit` | Move and resize supported interface components. |
| `/sqms camera` | Camera status; `options` opens its settings, `on`, `off` and `restore` control it. |
| `/sqms camera takeover` | Import the DynamicCam profile in use and disable DynamicCam (then `/reload`). |
| `/sqauras [count]` | Preview placeholder buffs and debuffs to judge layout. |
| `/sqplates test [on\|off\|enh]` | Preview nameplates with made-up units; `/sqplates debug` prints one line per visible plate. |

To replace the Caps Lock/Up preset, run `/sqms bindings off`, then assign
**Hold to release mouselook** in WoW's Key Bindings. This also removes the
historical F8/F9 helper overrides.

First-use setup enables native mouseover casting with no modifier and preserves
later user changes. Explicit-unit macros retain their targets. The gate does not
cast a spell or select a hard target. Native mouselook, the held mouseover gate and
cursor return need no external input helper. The author's historical combined-click
interact-on-down / target-on-up helper is not bundled.

## Range, camera and nameplates

The selected-target nameplate uses a solid ring, drawn inside the plate and cut
around its health bar. Cardinal blocks indicate conservative five-yard hostile
melee reach; rotating triangles indicate a learned damage or healing spell in
range. Mend Pet and Health Funnel apply only to your own pet. On players the
ring wears the health bar's texture and colour by default; NPCs keep the plain
ring coloured by health.

The bundled MIT-licensed **LibRangeCheck-3.0** and the shared range module
(`Range.lua`) answer distance questions from learned spells and item-range
checks; no other addon is needed. Unknown range stays hidden. Friendly ring
rotation alone is proximity feedback, not healing readiness. Range does not
guarantee resources, cooldown, form or line of sight. Cross-class and combat
acceptance remains in progress.

Squanch-On has its own camera (`Camera.lua`): every DynamicCam setting, zoom
curves and situations; wheel zoom follows DynamicCam's easing algorithm. It
stays inactive while DynamicCam is loaded; `/sqms camera takeover` imports the
DynamicCam profile once and disables DynamicCam.

Squanch-On draws its own nameplates. Their defaults reproduce the author's
previous nameplate layout; optional enhancements stay off while "Classic look"
is on (the default). They stay off while Plater is loaded; then the friendly
ring fits Plater's nameplate icon and its icons take the shared look. Seen live
so far: friendly NPC and player plates out of combat, and the preview.
[Compatibility notes](https://github.com/Resource-Hacker/squanchers-squanch-on/blob/main/docs/COMPATIBILITY.md).

## Source and attribution

To build **from a source checkout**, install Python 3, Git and Lua 5.1, then run
`python tools/package.py` in that checkout. Developer tools are intentionally not
inside this installation package. Packaging checks do not certify game behavior.

Original Squanch-On code and generated artwork use [MIT](LICENSE). The Horde
reticle module and its media are GPL-2.0; bundled fonts are SIL OFL 1.1; oUF,
LibDispel, LibRangeCheck-3.0, LibSerialize, LibDeflate, LibStub, the DynamicCam
parts of `Camera.lua` and Choonster's contribution keep their own notices.
See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md), [reuse-manifest.json](reuse-manifest.json)
and `LICENSES/`. Game-provided art remains Blizzard's property. This project is
not endorsed by Blizzard or the referenced addon projects.
