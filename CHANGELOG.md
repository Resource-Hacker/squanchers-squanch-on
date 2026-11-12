# Changelog

## 0.3.0-rewrite — unreleased

- Ship everything in one `SquanchOn/` folder. No other addon, assembly step or
  separately supplied media is needed. Unit-frame layout and presentation are
  independently implemented on separately licensed oUF, LibDispel and LibStub;
  the ElvUI/BenikUI engines and the five-folder assembly are gone.
- Range no longer needs Plater. LibRangeCheck-3.0 (MIT) is bundled and a shared
  range module (`Range.lua`) answers distance questions from learned spells and
  item-range checks.
- Add Squanch-On's own camera (`Camera.lua`): every DynamicCam setting, zoom
  curves, eased wheel zoom and situations, with logic partly ported from
  DynamicCam under MIT. It stays inactive while DynamicCam is loaded;
  `/sqms camera takeover|release|status|options`. A DynamicCam profile is
  imported once. `CameraFraming.lua` and `/sqms camera setup` are removed.
- Add one settings window (`/squanchon`) with a category tree, search, undo and
  reset. Changes apply live; combat-restricted changes are queued. Pages:
  General, Mouselook & Reticle, Camera, Unit Frames, Auras & Buffs, Nameplates &
  Target ring, Chat, Damage meter, Bags, Windows & Drawers, Tooltip, Appearance,
  Layout, Profiles, About.
- Add profiles: one addon-wide profile selected per character; create, copy,
  rename, delete, reset; export and import as a text string (LibSerialize, MIT,
  and LibDeflate, zlib, bundled). Existing settings are migrated at first login
  and a backup is kept in the saved file.
- Add theme, text, chat and drawer settings, and a media library: generated
  status-bar textures and borders (`asset-source/generate-frame-media.py`) and
  SIL OFL fonts (PT Sans Narrow, Overpass, Afacad, Oxanium, Almendra, Barlow
  Condensed, Saira Condensed, Archivo Narrow, Oswald, Bebas Neue, Cinzel,
  Metamorphous, Silkscreen, Pixelify Sans, Share Tech Mono). The shipped layout's
  fonts stand in for the author's original fonts, which are not distributed.
  LibSharedMedia is not bundled; Squanch-On registers into it only when another
  addon has loaded it.
- Auras: split buff/debuff rows on the player and target frames, player buff
  and debuff bars replacing the game's rows, temporary weapon enchants on the
  buff bar (display only), `/sqauras` preview; all configurable. The separate
  proc, enhancement and cooldown tracker panels are off.
- Move the micro-menu icons and Friends into the chat header. Windows opened
  from them appear as drawers above the chat at the chat's width, with an
  unfold animation. The quest list is a drawer above the minimap.
- Add a bag window left of the minimap: one combined inventory grid with the
  game's real item buttons, search, sort and money. The bank is not included yet.
- Add a damage meter drawer on the right of the minimap, fed by the game's
  `C_DamageMeter` data (addons cannot read the combat log on this client) and
  sized so that minimap plus meter equals the chat width.
- Target ring: one solid line. On friendly players it hugs the nameplate icon
  and takes the class colour, with fit, width and thickness settings.
- Add Squanch-On's own nameplates (untested in game). They start only when
  Plater is not loaded and reproduce the author's previous layout; optional
  enhancements stay off behind a "Classic look" switch. `/sqplates test` shows
  preview plates, also while Plater is loaded.
- Add independently written tooltip presentation and anchor handling; Blizzard
  keeps content, item comparisons and native health values.
- Ship the exact Horde reticle (`HordeReticle.lua`, `HordeReticleData.lua`,
  `media/horde-reticle/`) under GPL-2.0-only. The earlier approximate reticle and
  `ReticleConfig.lua` are removed.
- Start a first run with no saved settings from the author's layout
  (`DefaultProfile.lua`). Positions were authored on a 5120x1440 display; other
  resolutions may need `/sqedit`.
- Verification: checked live only solo on the Forever client (interface 16001)
  by the author. Not verified: combat behaviour in general, hostile-target
  debuffs, pet/party/raid frames, profile switching, export and import in game,
  theme recolouring in game, the camera takeover, bag interactions beyond
  opening (use, drag, split, vendor, combat), the meter in combat, the tooltip,
  and a fresh install on other resolutions (offline conversion check only).

## 0.2.0-candidate — original-engine baseline

The accepted local baseline remains on this version while 0.3 is evaluated.

- Replace the rejected alpha unit-frame rewrite with the original scoped ElvUI
  renderer, complete native editor, profiles/movers and Benik decoration.
- Restore original tooltip borders, exact font paths, native layout adapters,
  options-menu cursor handling and target marker fade ownership.
- Remove the duplicate oUF/library tree and partial unit-frame editor.
- Add an offline private local assembler with original identities, load checks,
  per-file hashes and explicit redistribution boundaries.
- Preserve existing native frame databases and the suite's current reticle/camera
  behavior. Those original-engine checks do not certify the later independent rewrite.


- Restore a visible gold leading border on General and other exposed chat tabs.
- Strengthen the continuous line beneath the tabs to three physical pixels.
  Both changes were visually checked after reload in the existing Forever setup.
- Match minimap menu-icon backgrounds to the shared translucent panel fill,
  preserving native hover and pressed feedback. Fit their lower edge to the bag
  row's painted border so the differently scaled rows meet without a bright gap.

## 0.1.0-alpha — 2026-11-10

First packaged public developer alpha for Forever interface 16001.

- Reticle-centered native mouselook with a hold-right-to-open real mouseover gate,
  native mouseover casting setup and hardware-cursor release/return.
- Horde reticle feedback and a separate dashed selected-target ring with click
  pulse, conservative melee blocks and learned ranged/healing spell triangles.
- Standalone oUF unit frames and original settings controls; native bags, bars,
  chat, minimap and windows share the dark/gold theme.
- Centered `/sqedit` alignment grid, supported frame resizing and session undo.
- Explicit third-party licenses, source provenance and hash manifests.
- Gameplay example images, a reticle control guide, compatibility notes, checked
  installation ZIP and SHA-256 checksum.

This release packages the new consolidation for evaluation. Full standalone UI,
combat, cross-class and platform acceptance remains in progress.
