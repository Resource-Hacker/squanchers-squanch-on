# Squancher's Squanch-On

![Squanch-On: keep the camera locked, open mouseover only when you mean it. Steer, hold right mouse, release.](docs/images/reticle-control.svg)

**Keep the camera locked. Open mouseover only when you mean it.**

Squanch-On builds a World of Warcraft interface around a deliberate reticle control:
move the mouse to steer, **hold right mouse to open real mouseover at the reticle**,
then release to close mouseover while the camera stays locked. Hold the free-cursor
key when you need the interface; release it to return to mouselook.

[**Build the equivalence candidate**](docs/LOCAL-ASSEMBLY.md)
· [How the reticle works](docs/RETICLE.md)
· [Install and configure](#install-and-configure)
· [Changelog](CHANGELOG.md)
· [Report an issue](https://github.com/Resource-Hacker/squanchers-squanch-on/issues/new?template=bug_report.md)

**0.2.0-candidate · Forever interface 16001.** This candidate restores the actual
ElvUI unit-frame engine and complete native editor used by the author's accepted
setup. The previous 0.1.0-alpha replacement did not preserve its appearance.
The candidate needs in-game acceptance before a release is recommended.
See [compatibility](docs/COMPATIBILITY.md).

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
- **Unit frames:** original ElvUI health and power, casts, portraits, auras, group
  headers, profiles, filters and complete native configuration, with Benik styling.
  The duplicate alpha renderer and its partial editor have been removed.
- **A consistent theme:** dark translucent panels, gold equipment-style borders,
  native action and pet bars, chat, minimap, menus and other native windows.
- **A layout you can tune:** `/sqedit` moves and resizes supported components with
  a centered alignment grid, width controls and session undo.
- **Optional integrations:** Plater retains nameplate behavior; DynamicCam can
  own camera framing. Both are installed separately.

The exact local package contains **SquanchOn, ElvUI, ElvUI_Libraries,
ElvUI_Options and ElvUI_BenikUI**. Original names, engine ownership and licenses
stay intact. This is one locally assembled installation with five addon folders;
it is not a renamed copy of those projects. The scoped runtime activates only
ElvUI unit frames/tooltips and Benik unit decoration, leaving Squanch-On's other
native surfaces in control. Do not substitute an unscoped stock installation.

Some components and exact fonts cannot be redistributed under this project's
MIT license. The public repository supplies the integration; the private local
assembler takes legitimate, complete scoped originals from an existing install.
The resulting private package must not be uploaded as a public release.
[Component licenses and acquisition limits](docs/COMPONENT-LICENSES.md).

## Install and configure

1. Preserve the currently working addon folders and `WTF`; assemble outside the
   active installation while the game runs.
2. Follow [local assembly](docs/LOCAL-ASSEMBLY.md) with the original scoped
   dependency trees. The builder checks their native identities, versions,
   executable load graph and exact file hashes.
3. Inspect the private candidate and migration plan. Install only with the game
   closed so current settings have flushed and a fresh rollback can be captured.
4. Preserve `ElvDB`, `ElvPrivateDB`, `ElvCharacterDB`, native mover/profile
   identities and DynamicCam settings. Migrate the suite's own settings into
   `SquanchOnDB` separately; do not feed the alpha's reduced import into ElvUI.
5. Enable the assembled five-folder runtime, with Plater/DynamicCam if used.
   Retire overlapping owners only as part of the backed-up, reviewed switch.
6. Compare the actual frames and editor before accepting the candidate.

`tools/package.py` creates the public **integration-only** ZIP and checksum.
That ZIP alone is not a complete runtime. `tools/assemble_local.py` creates the
private complete local archive described above. Neither script installs or
changes a running game. The old 0.1.0-alpha release remains historical and does
not represent this equivalence work.

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
`SquanchOnDB`. Native unit-frame settings stay in the original ElvUI databases.
The public integration contains no account exports, saved macros or private
profiles; the owner-specific assembled runtime can contain a private presentation
seed and must remain local.

## Development and attribution

From a **source checkout**, install Python 3 and Lua 5.1 (`luac5.1`), then run:

```sh
python tools/package.py
```

The builder checks Lua syntax, TOC/XML dependencies and recorded reuse hashes,
then packages tracked addon files into `dist/` with a SHA-256 checksum. GitHub
Actions runs the same packaging checks. These checks do not certify game behavior.
See [contribution guidance](CONTRIBUTING.md) and [compatibility](docs/COMPATIBILITY.md).

Original Squanch-On code and geometric artwork use the [MIT license](LICENSE).
Bundled PT Sans and Choonster's TargetNameplateIndicator contribution retain
their own notices. Required original-name runtime components keep their separate
licenses; the MIT grant does not cover them. See
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and
[reuse-manifest.json](reuse-manifest.json) for exact scopes and file hashes.
Game-provided art and gameplay images retain Blizzard's rights. This project is
not endorsed by Blizzard or the referenced addon projects.
