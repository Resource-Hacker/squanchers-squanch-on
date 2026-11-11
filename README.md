# Squancher's Squanch-On

A cohesive World of Warcraft interface with native bags, dark translucent panels,
gold equipment-style borders, configurable unit frames, an adjustable layout grid,
and addon-only mouselook and target indicators.

**Development alpha.** The first package targets the Forever client interface
`16001`. The integrated replacement is undergoing in-game acceptance; Lua syntax,
package contents and configuration migration checks do not establish combat,
visual or interaction parity. Retail and other Classic versions are not yet
advertised as supported.

## Features

- Native Blizzard inventory and bank windows with shared panel and item styling.
  Blizzard continues to own item use, search, sorting, deposits and tooltips.
- Unit frames built on the bundled oUF library, with portraits, health and power,
  casts, aura icons, group headers, profiles and original configuration controls.
- Native action bars, pet bar, minimap, chat, quest and social drawers, menus,
  professions, collections and other native windows using the same theme.
- `/sqedit` for moving and resizing supported components, a centered alignment
  grid, width controls and session undo. Layout changes defer during combat.
- Hardware-cursor mouselook, mouseover casting, a Horde reticle, target markers and
  nameplate indicators using native game APIs and original geometric artwork.
- Native aura panels and a minimap launcher strip. Plater icons can use the same
  skin while Plater retains nameplate policy and behavior.

Plater and DynamicCam are optional, separately installed integrations. They are
not bundled or relicensed. ElvUI, BenikUI, ProjectAzilroka, MoveAny, AddOnSkins,
Bagnon, Masque, Pawn and GSE are not dependencies.

## Install and configure

1. Back up your current `Interface/AddOns` and `WTF` directories.
2. Close the game before installing or replacing addon folders.
3. Copy **`SquanchOn`**, with that exact folder name, into `Interface/AddOns`.
4. Enable Squancher's Squanch-On. Disable overlapping UI owners before evaluating
   the replacement; do not erase their saved settings before accepting migration.

The folder name is a loading and asset-path identity; the display name is
**Squancher's Squanch-On**. Configuration is saved in `SquanchOnDB` in the game's
normal `SavedVariables/SquanchOn.lua` file. The repository ships no account data,
character export, saved macros, private profiles or existing saved variables.

| Command | Purpose |
| --- | --- |
| `/squanchon` or `/squancher` | Unit-frame settings and profiles |
| `/sqedit` or `/squanchon edit` | Move and resize the interface |
| `/squanchon tooltip` | Tooltip text, opacity and anchor options |
| `/sqms` | Native controls and mouselook status/help |
| `/sqms nameplates` | Nameplate-indicator settings |
| `/sqms crosshairs` | Target-crosshair settings |
| `/sqms camera` | DynamicCam framing status |
| `/sqms camera setup` | Explicitly create a separate zoom-framing profile |
| `/sqms camera restore` | Return to the saved source camera profile |
| `/sqms off` | Disable Squanch-On mouselook control |

Mouselook and helper-binding behavior is intentional and configurable through
`/sqms` and the native Key Bindings panel. Existing `SQMS_*` binding identifiers and
the `SquancherMouselookSuite` global alias remain for compatibility. No external
input daemon, custom mouse firmware or virtual controller is required.

## Migration and current limits

A local installer can provide semantic unit-frame, tooltip, native-window and
auxiliary-panel settings to the documented import fields. Imports run once and
later edits remain authoritative. Personal export and installation scripts are
not part of the public addon. A clean install starts with project defaults.

The new unit-frame editor is original code. It does not embed ElvUI's editor or
promise every advanced ElvUI/Benik feature. Specialized aura predicates and sorting,
unused aura-panel status-bar mode and arbitrary legacy visibility macros require
separate acceptance. Spell-range fading uses configured, actually known player spells and native range
results; an unavailable range result stays fully visible. Restricted client values are passed to native widgets where
supported; inaccessible classifications do not become guessed values.

The unlicensed legacy image packs and fonts are deliberately absent. Horde artwork
comes from the installed game, markers are original geometric drawings, and the
bundled font is PT Sans Narrow Bold. These replacements change typography and
some indicator artwork. The native warning sound replaces the former audio file.

## Build a package

Python 3 and Lua 5.1's `luac5.1` are needed for the local package check:

```sh
python tools/package.py
```

The command checks Lua syntax and TOC/XML dependencies, then writes a ZIP and its
SHA-256 digest in `dist/`. It does not launch the game or certify runtime behavior.
Artwork source and notices are included in the package.

## License and credits

Original Squanch-On code and artwork use the [MIT license](LICENSE). Included
third-party components keep their own licenses, copyright notices and source
credits. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and the
[file manifest](reuse-manifest.json) for exact included components and hashes.

Thanks to oUF's authors and contributors, LibDispel and LibStub's authors,
Choonster for TargetNameplateIndicator code, and ParaType's designers for PT Sans
Narrow. ElvUI, BenikUI, MoveAny, ProjectAzilroka, Masque, Bagnon and Crosshairs
informed compatibility goals; their restricted implementation and artwork are not
included under this project's license. World of Warcraft and game-provided art
remain Blizzard's property. This project is not endorsed by those projects or
Blizzard Entertainment.
