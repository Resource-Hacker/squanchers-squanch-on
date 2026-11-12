# Squancher's Squanch-On

![Squanch-On: keep the camera locked, open mouseover only when you mean it. Steer, hold right mouse, release.](docs/images/reticle-control.svg)

**Keep the camera locked. Open mouseover only when you mean it.**

Squanch-On builds a World of Warcraft interface around a deliberate reticle control:
move the mouse to steer, **hold right mouse to open real mouseover at the reticle**,
then release to close mouseover while the camera stays locked. Hold the free-cursor
key when you need the interface; release it to return to mouselook.

[**Build the standalone candidate**](docs/LOCAL-ASSEMBLY.md)
· [How the reticle works](docs/RETICLE.md)
· [Install and configure](#install-and-configure)
· [Changelog](CHANGELOG.md)
· [Report an issue](https://github.com/Resource-Hacker/squanchers-squanch-on/issues/new?template=bug_report.md)

**0.3.0-rewrite · Forever interface 16001 · staged, not yet accepted in game.**
This candidate independently implements the unit-frame layout, tooltip presentation
and settings controls inside Squanch-On, using bundled, separately licensed
libraries. It requires no ElvUI or BenikUI engine. Source/package checks have
passed; visual equivalence, settings behavior and combat/group acceptance remain
unverified. See [compatibility](docs/COMPATIBILITY.md).

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
- **Unit frames:** independently written health/power layout, portraits, casts,
  text, auras and group presentation built on oUF. The new editor exposes the
  renderer's supported controls; it does not reproduce the full ElvUI editor.
- **Tooltips:** shared presentation and default anchors while Blizzard retains
  tooltip content, comparisons and native health handling.
- **A consistent theme:** dark translucent panels, gold equipment-style borders,
  native action and pet bars, chat, minimap, menus and other native windows.
- **A layout you can tune:** `/sqedit` moves and resizes supported components with
  a centered alignment grid, width controls and session undo.
- **Optional integrations:** Plater retains nameplate behavior; DynamicCam can
  own camera framing. Both are installed separately.

The public package is one complete **SquanchOn** addon folder, including its
required oUF, LibDispel and LibStub libraries with their own notices. ElvUI and
BenikUI implementations are not copied into the rewrite or loaded as dependencies.
Existing resolved settings can be preserved as local data without implying that
every imported option has been implemented.

A separate private overlay can retain exact locally held fonts, textures and an
original reticle. Those files remain outside the public release. The public addon
uses bundled/game defaults when exact media is absent; those fallbacks do not
establish matching appearance. [Package and component boundaries](docs/COMPONENT-LICENSES.md).

## Install and configure

1. Back up the working addon folders and `WTF`, then close the game normally
   before replacing files or migrating settings.
2. Build the public package using [the installation guide](docs/LOCAL-ASSEMBLY.md),
   and extract its single `SquanchOn/` folder under `Interface/AddOns`.
3. For a migrated setup, preserve the complete current configuration separately
   and transfer it deliberately into `SquanchOnDB`; keep original ElvUI databases
   and DynamicCam settings as rollback state. Packaging does not migrate settings.
4. Disable overlapping frame/tooltip owners for the review profile. Optional
   Plater and DynamicCam remain separate. Retain originals for rollback.
5. Review actual loading, reticle controls, frame appearance, supported settings,
   tooltips and movers before accepting the candidate.

`tools/package.py` creates the complete public addon ZIP and checksum. A private
exact-media overlay is optional and separate; the former original-engine
`tools/assemble_local.py` workflow is retired. Neither packaging nor private
staging demonstrates successful game loading or behavioral equivalence.

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
`SquanchOnDB`, including the rewrite's unit-frame profiles. The new editor shows
supported renderer controls and preserves other imported settings as data.
Tooltip presentation editing needs an imported tooltip profile; Blizzard still
owns content and comparisons. The public package includes no personal settings,
account exports, macros or private media. [Supported controls and limits](docs/COMPATIBILITY.md#settings-and-supported-controls).

## Development and attribution

From a **source checkout**, install Python 3 and Lua 5.1 (`luac5.1`), then run:

```sh
python tools/package.py
```

The builder checks Lua syntax, TOC/XML dependencies and recorded reuse hashes,
then packages tracked addon files into `dist/` with a SHA-256 checksum.
For isolated review before new source is tracked, explicit `--working-tree`
includes those addon files; `--check-only` validates without creating a ZIP. GitHub
Actions runs the same packaging checks. These checks do not certify game behavior.
See [contribution guidance](CONTRIBUTING.md) and [compatibility](docs/COMPATIBILITY.md).

Original Squanch-On code and geometric artwork use the [MIT license](LICENSE).
Bundled PT Sans, Choonster's TargetNameplateIndicator contribution, oUF and
LibDispel retain their own notices; LibStub retains its public-domain declaration.
Private local originals and media remain outside the public package. See
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and
[reuse-manifest.json](reuse-manifest.json) for exact scopes and file hashes.
Game-provided art and gameplay images retain Blizzard's rights. This project is
not endorsed by Blizzard or the referenced addon projects.
