# Compatibility and rewrite status

## Client and evidence

**0.3.0-rewrite targets Forever interface 16001 and is only partly verified.**
The author has checked it live only solo on the Forever client. See
[verification status](#verification-status) for what has and has not been
exercised. Retail, other Classic clients and Windows gameplay are unverified.
Changing a TOC number does not establish compatibility.

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
embeds separately licensed oUF, LibDispel, LibRangeCheck-3.0, LibSerialize and
LibDeflate plus public-domain LibStub, the GPL-2.0 Horde reticle, and its fonts
and textures. Squanch-On owns frame layout, buff and debuff icons, the camera,
the bag window, the meter drawer, chat and drawer presentation, its settings
window and profiles, tooltip presentation, reticle/mouselook and native UI
adapters. oUF owns the secure unit-frame machinery and element lifecycle.
ElvUI and BenikUI engines, original options addons and original profile managers
are neither included nor required.

Blizzard continues to own tooltip content, item comparisons, native health values
and their handlers. Squanch-On's tooltip adapter changes presentation and default
anchoring; it does not recreate ElvUI's custom content extensions.

### Range

Plater is no longer needed for range. LibRangeCheck-3.0 (MIT) is bundled, and
the shared range module (`SquanchOn/Range.lua`) answers every distance question
from learned spells, item-range checks, interact distance, nameplate visibility
and, for group members outdoors, the exact group distance. In combat the client
blocks item and interact checks on units the player cannot attack; friendly
range then rests on spells, nameplates and visibility. Unknown range hides the
cue.

### Camera

`SquanchOn/Camera.lua` is Squanch-On's own camera: every DynamicCam standard
setting, zoom curves, eased wheel zoom and situations built from DynamicCam's
built-in conditions. Parts of its logic are ported from DynamicCam under MIT;
the license is in `LICENSES/DynamicCam-MIT.txt`. It stays inactive while
DynamicCam is loaded. `/sqms camera takeover` imports the DynamicCam profile in
use once and disables DynamicCam; `release` hands the camera back; `status`
reports the state; `options` opens the settings page. Situations with
hand-written Lua conditions are kept as data and stay inactive, and of the
hide-interface options only the whole-interface fade is implemented. The
takeover has not been verified in game.

### Nameplates

Squanch-On does not ship nameplates. A native nameplate module is planned, not
shipped. Squanch-On draws the target ring and nameplate indicators on whatever
nameplates are shown. The author uses Plater; it is not required. When Plater is
loaded, small adapters style its icons and health-bar rim, show a health bar on
a selected friendly Horde player, and let the friendly target ring hug Plater's
nameplate icon. Without Plater those adapters do nothing.

The target ring is one solid line. On a friendly player it takes the class
colour, with fit, width and line-thickness settings.

### Chat, drawers, bags and meter

- The chat header holds the micro-menu icons and Friends. Windows opened from
  them appear as drawers above the chat at the chat's width, with an unfold
  animation. The quest list is a drawer above the minimap.
- The bag window is one combined inventory grid that slides out to the left of
  the minimap. Its cells are the game's own item buttons, so use, drag, split
  and selling stay the game's handlers. It has search, sort (the game's own
  clean-up) and money. The bank is not included yet and keeps the game's window.
  The option to replace the game's bag windows takes effect after `/reload`.
- The damage meter is a drawer on the right of the minimap, sized so that
  minimap plus meter equals the chat width. It shows the game's `C_DamageMeter`
  sessions. Addons cannot read the combat log on this client, and amounts are
  hidden from addon arithmetic during combat, so the meter only displays what
  the client returns, in the client's order.

## Buff and debuff icons

Squanch-On draws split rows above the player and target frames: on the player,
debuffs on the left and buffs on the right; on the target, buffs on the left
and debuffs on the right. A gap separates the halves and overflow stacks
upward. Two movable player bars, "Buff bar" and "Debuff bar", replace the
game's own buff and debuff rows. Temporary weapon enchants appear on the buff
bar with their time left; this is display only, and they cannot be cancelled
from it. `/sqauras [count]` fills the rows with placeholder icons to judge
spacing; run it again to return to live auras. Sizes, spacing, text and the
weapon-enchant and game-row toggles are on the Auras & Buffs pages.

The separate proc, enhancement and cooldown tracker panels are off. Only buffs
on the player and a self-target have been seen live; debuffs and
hostile-target auras are unverified.

## Settings and supported controls

`/squanchon` (or `/squancher`) opens one settings window with a category tree:
General, Mouselook & Reticle, Camera, Unit Frames, Auras & Buffs, Nameplates &
Target ring, Chat, Damage meter, Bags, Windows & Drawers, Tooltip, Appearance,
Layout, Profiles and About. It has search, undo and reset. Changes apply live;
a change that is restricted in combat is queued and applied when combat ends.
`/squanchon` followed by a page name or search words opens that page or search.
`/sqedit` moves and resizes the supported components.

Settings live in `SquanchOnDB` as named profiles. A profile holds every setting
of the addon; each character selects one, and several characters can share it.
Profiles can be created, copied, renamed, deleted and reset, and exported or
imported as a text string (LibSerialize and LibDeflate; an imported string is
read as data and never run). Settings from an earlier version are migrated at
first login, and the untouched earlier settings are kept as a backup in the
saved file. Switching profiles applies what can change at once and asks for a
reload for the rest.

Original `SQMS_*` bindings and the `SquancherMouselookSuite` global alias remain
for compatibility. A first run with no saved settings starts from the author's
layout (`SquanchOn/DefaultProfile.lua`). Its positions were authored on a
5120x1440 display; other resolutions may need `/sqedit`. The layout includes
nested settings and fields the rewrite does not implement; they are kept as
data, which does not mean every field has the original engine's behavior. The
addon does not read or migrate ElvUI databases. It reads the DynamicCam profile
in use once, to import camera settings, and never writes DynamicCam's saved
variables.

The Unit Frames pages are not the native ElvUI editor. Their controls come from
the renderer's actual capability map: frame size/orientation, portraits, power
and cast layout, supported unit text/custom text, group layout and sorting.
Specialized aura filters, all-class resource behavior and the complete native
options catalog are not claimed as reproduced. Unsupported imported settings
stay preserved; unsupported controls are not presented as working settings.

The Tooltip page edits presentation: text sizes, opacity, cursor/fixed anchoring
and health-bar height. `/sqedit` can move its fixed anchor. Native tooltip
content and comparison logic remain independent of those controls.

## Fonts, textures and reticle

Text uses bundled SIL OFL 1.1 fonts. The shipped layout uses PT Sans Narrow
Bold, Overpass Bold, Afacad Medium, Oxanium Bold and Almendra Bold; they stand
in for the author's original fonts (Expressway, Homizio, Forced Square, Harry
P), which are not distributed, so text shapes are close but not identical. The
font pickers also offer Barlow Condensed, Saira Condensed, Archivo Narrow,
Oswald, Bebas Neue, Cinzel, Metamorphous, Silkscreen, Pixelify Sans and Share
Tech Mono. Status-bar textures and borders are original and generated by
`SquanchOn/asset-source/generate-frame-media.py`; ready-check icons use the
game's own files. LibSharedMedia is not bundled: Squanch-On registers its fonts
and textures there only when another addon has loaded it. The Horde reticle
ships exactly, under GPL-2.0. See [installation](LOCAL-ASSEMBLY.md) and
[component licenses](COMPONENT-LICENSES.md).

## Verification status

Everything below was checked by the author only, solo, on the Forever client
(interface 16001). Nothing has been checked by anyone else, in a group, or on
another client.

| Area | Seen live, solo | Not verified |
| --- | --- | --- |
| Mouselook, reticle, mouseover gate | Ordinary solo use | Combat, focus loss with keys held, Windows input |
| Target ring and range cues | Ring on selected targets, friendly class colour and icon fit | Range cues in combat, other classes |
| Unit frames | Player, target, target-of-target with a self-target | Hostile targets in combat, pet, party and raid frames, class resources |
| Buff and debuff icons | Buffs on the player and a self-target, `/sqauras` preview | Debuffs, hostile-target auras, combat |
| Settings window | Opened out of combat | Every control; combat queueing |
| Profiles | — | First-login migration beyond the author's own settings; switching, create/copy/rename/delete/reset, export and import in game |
| Theme and text | The shipped look | Recolouring the theme in game |
| Camera | — | The takeover from DynamicCam; zoom curves and situations in play |
| Chat header and drawers | Opening windows as drawers, Friends, quest drawer | Combat |
| Bag window | Opening it | Use, drag, split, vendor, combat |
| Damage meter | Drawer open out of combat | Meter in combat |
| Tooltip | — | Appearance, anchors, native content and comparisons |
| Fresh install | Offline conversion check of the default layout only | A fresh install in game; other resolutions |

Combat behaviour in general is unverified. Range describes reach, not cooldown,
resources, form or line of sight. The historical external interact-on-down /
target-on-up helper is not included.

Report the exact client/interface, version, input sequence and expected/observed
behavior with a sanitized error or image. Never upload full WTF directories or
personal settings.
