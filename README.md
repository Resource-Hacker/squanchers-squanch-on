# Squancher's Squanch-On

![Squanch-On: keep the camera locked, open mouseover only when you mean it. Steer, hold right mouse, release.](docs/images/reticle-control.svg)

**Keep the camera locked. Open mouseover only when you mean it.**

Squanch-On builds a World of Warcraft interface around a deliberate reticle control:
move the mouse to steer, **hold right mouse to open real mouseover at the reticle**,
then release to close mouseover while the camera stays locked. Hold the free-cursor
key when you need the interface; release it to return to mouselook.

[**Download the alpha**](https://github.com/Resource-Hacker/squanchers-squanch-on/releases/tag/v0.1.0-alpha)
· [How the reticle works](docs/RETICLE.md)
· [Install and configure](#install-and-configure)
· [Changelog](CHANGELOG.md)
· [Report an issue](https://github.com/Resource-Hacker/squanchers-squanch-on/issues/new?template=bug_report.md)

**0.1.0-alpha · Forever interface 16001.** The reticle controls come from the
author's working gameplay setup. The newly consolidated standalone UI is still
undergoing in-game acceptance; Retail, other Classic clients and Windows gameplay
are not yet advertised as supported. See [compatibility](docs/COMPATIBILITY.md).

## The reticle is the control

Normal locked mouselook keeps centered mouseover **closed**. Holding right mouse
temporarily makes the unit under the aim center available to WoW's actual
`mouseover` system. Releasing right mouse closes that gate immediately, with
mouselook still active. You decide when aiming should affect a mouseover ability.

| What you do | What happens |
| --- | --- |
| Move the mouse | Steer the camera with the native cursor hidden; centered mouseover stays closed. |
| **Hold right mouse** | **Open true mouseover at the reticle, keeping the camera locked.** |
| Press an ability while holding | WoW's native mouseover casting can use that unit, subject to the ability's normal rules. |
| **Release right mouse** | **Close centered mouseover immediately; keep steering.** |
| Hold the free-cursor key | Use the native hardware cursor for the interface. Default preset: Caps Lock / Up; [rebinding instructions](docs/RETICLE.md#getting-the-cursor-back). |
| Release the free-cursor key | Return the cursor to the center and resume mouselook. |

First-use setup enables native mouseover casting with no modifier; later user
changes are preserved. Explicit-unit macros retain their own targeting rules.
Opening the gate does not cast a spell or automatically select a hard target.
The native mouselook, hold-to-open mouseover and cursor-return features run inside
the addon. [Controls, safeguards and implementation details →](docs/RETICLE.md)

## In game

<table>
  <tr>
    <td width="58%"><img src="docs/images/horde-reticle-gameplay.png" alt="Gameplay detail showing the Horde reticle in the world near a friendly NPC." width="580"></td>
    <td width="42%"><img src="docs/images/target-ring-gameplay.png" alt="Selected Duokna nameplate with the dashed target ring and merchant icon." width="360"></td>
  </tr>
  <tr>
    <td><strong>The world reticle.</strong> A compact Horde marker keeps the aim point visible during the author's mouselook playstyle.</td>
    <td><strong>The selected-target ring.</strong> A separate dashed marker follows the target's visible nameplate.</td>
  </tr>
</table>

These are real development gameplay details from the author's existing setup,
with Plater. They illustrate the reticle and target artwork; a still image does
not demonstrate the hold/release transition or certify the new standalone UI.
[Image provenance and credits](docs/images/README.md).

## Read range at a glance

![Range legend: cardinal blocks for melee reach; triangles for a learned ranged damage or healing spell; a dashed ring identifies the selected target.](docs/images/range-guide.svg)

The selected visible target has a dashed ring and a brief whole-ring click pulse.
Cardinal blocks indicate conservative five-yard melee reach on hostile targets. Rotating triangles
indicate a learned ranged damage ability against a hostile target, or a learned
healing ability against a friendly target. Hunter Auto Shot keeps its native
range check; Mend Pet and Health Funnel apply only to the player's own pet.

Five-yard melee and friendly/NPC proximity checks need **LibRangeCheck-3.0**,
normally supplied by optional **Plater**. Those cues stay hidden when no library
is available. Friendly ring rotation alone is proximity feedback; healing range
uses the triangles. Range feedback does not guarantee mana, cooldown, form or line
of sight. [Exact marker meanings and current limits](docs/RETICLE.md#target-range-feedback).

## An interface built around that playstyle

- **Native bags and bank:** Blizzard owns item use, sorting, deposits and tooltips;
  Squanch-On supplies the shared visual treatment.
- **Unit frames:** bundled oUF, health and power, casts, portraits, auras, group
  headers, profiles and original configuration controls.
- **A consistent theme:** dark translucent panels, gold equipment-style borders,
  native action and pet bars, chat, minimap, menus and other native windows.
- **A layout you can tune:** `/sqedit` moves and resizes supported components with
  a centered alignment grid, width controls and session undo.
- **Optional integrations:** Plater retains nameplate behavior; DynamicCam can
  own camera framing. Both are installed separately.

ElvUI, BenikUI, ProjectAzilroka, MoveAny, AddOnSkins, Bagnon, Masque, Pawn and GSE
are not dependencies.

## Install and configure

1. Back up `Interface/AddOns` and `WTF`, then close the game.
2. Download **`SquanchOn-0.1.0-alpha.zip`** from the
   [release page](https://github.com/Resource-Hacker/squanchers-squanch-on/releases/tag/v0.1.0-alpha).
   Choose the named addon ZIP from **Assets**; GitHub's automatic source archives
   contain the development repository.
3. Extract it into your client's `Interface/AddOns`. The result must be
   `Interface/AddOns/SquanchOn/SquanchOn.toc`.
4. Enable **Squancher's Squanch-On**. Disable overlapping UI owners while trying
   the replacement; preserve their saved settings until you accept the migration.
5. Review the mouselook bindings and mouseover-casting settings before combat.

The release includes a `.sha256` checksum. After downloading both files, an
optional integrity check is `sha256sum -c SquanchOn-0.1.0-alpha.zip.sha256`.

| Command | Purpose |
| --- | --- |
| `/sqms` | Mouselook controls, status and help |
| `/sqms off` | Disable Squanch-On mouselook control |
| `/sqms nameplates` / `/sqms crosshairs` | Indicator settings |
| `/squanchon` or `/squancher` | Unit-frame settings and profiles |
| `/sqedit` or `/squanchon edit` | Move and resize the interface |
| `/squanchon tooltip` | Tooltip text, opacity and anchors |
| `/sqms camera` | DynamicCam framing status |
| `/sqms camera setup` / `/sqms camera restore` | Create a separate framing profile / restore the saved source profile |

Saved settings live in the normal `SavedVariables/SquanchOn.lua` file as
`SquanchOnDB`. A clean install starts with project defaults. Account exports,
saved macros and the author's private profiles are not part of the download.

## Development and attribution

From a **source checkout**, install Python 3 and Lua 5.1 (`luac5.1`), then run:

```sh
python tools/package.py
```

The builder checks Lua syntax, TOC/XML dependencies and recorded reuse hashes,
then packages tracked addon files into `dist/` with a SHA-256 checksum. GitHub
Actions runs the same packaging checks. These checks do not certify game behavior.
See [contribution guidance](CONTRIBUTING.md) and [compatibility](docs/COMPATIBILITY.md).

Original code and geometric artwork use the [MIT license](LICENSE). Bundled oUF,
LibDispel, LibStub and PT Sans retain their own licenses and credits; Choonster's
TargetNameplateIndicator contribution is attributed. See
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and
[reuse-manifest.json](reuse-manifest.json) for exact scopes and file hashes.
Game-provided art and gameplay images retain Blizzard's rights. This project is
not endorsed by Blizzard or the referenced addon projects.
