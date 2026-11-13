# Changelog

## Unreleased

- Chat header: the tab row is narrower and fitted to the menu icons, each icon
  centred in its own cell with even space all round; Friends matches them.
- Quest mobs: an enemy you still need for a quest shows a small skull on its
  plate (setting on the nameplate page), and its health number moves just
  right of the bar while the skull shows.
- Title plates on the damage meter and the bag window are centred on their top
  rims, like every other window.
- The target's red highlight hugs its health bar (3 units instead of 11).
- Target frame range fade follows the target ring's marks exactly while the
  ring shows: blocks or circling triangles light it, no marks fade it.
- Character sheet: opens as its drawer even with the map or other windows
  open; its name shows only in the title plate; the pane line reaches the
  top rim.
- Map breadcrumbs (World › continent › zone) form an even row; the current
  zone is marked by its white label.
- Action-slot border masks keep every pixel of the straight edges.
- The quest list re-lays itself out when a native update measured its text at
  another width (text could stop wrapping after turning quests in).

## 1.0.2 — 2026-11-12

- Combat start and end no longer redo the whole action-bar layout: Blizzard
  repositions its bars up to eight times at each transition and Squanch-On
  re-laid out every bar after each call, rewriting every position and scale and
  re-applying every button's art. Writes that change nothing are now skipped,
  each bar's scale is fitted in one step, and re-layouts no longer re-apply
  button art. This was the hitch of 100–170 ms at every combat start and end.
- Action-slot borders are 8 textures under one mask instead of 58 pieces, and
  panel corners one masked texture each instead of ~17; the look is the same.
  The masks are generated from measured contour data
  (`asset-source/generate-border-masks.py`).
- The target frame is lit whenever the target ring shows its range marks, and
  Auto Shot counts for its own range check (asked by name when the spell ID
  cannot answer).
- Nameplates: shown as far out as the client allows; only a definite
  out-of-range dims a plate; friendly mouseover ring fades 0.2 s.
- The world map drawer: the map is sized once before it slides out (its terrain
  could draw blank after a quest-list pull-up), and an arrow on the map slides
  it back in place of Blizzard's quest-panel toggle.
- The character sheet's pane line runs up to the top rim; the chat-header menu
  icons keep the game's own look.

## 1.0.1 — 2026-11-12

- The login line and About page show the release number from the TOC, so each
  release names itself.
- Debuffs on enemy nameplates, the unit frames' aura rows, the target's aura
  bars and the player's buff and debuff bars keep working in combat: while the
  game keeps aura data secret, the client's own aura container draws them.
- The world map opens as a drawer that slides out sideways from the quest list
  (side arrow on the quest pane, or M), at the quest list's height, without
  the duplicate quest panel; themed World › zone breadcrumbs.
- Every themed window wears the same raised title plate as the drawers (the
  character sheet shows the character's name there).
- Quest rows no longer jump after quest updates, map opening or combat.
- Drawers open in place during combat; the first spellbook open after a reload
  no longer flashes at the top left.
- Chat header icons stay in the header when a toast or a vehicle bar appears.
- The target frame's range fade follows ElvUI's rules (Auto Shot counts).
- Click pulse on a selected target's split ring squeezes toward the bar.
- Mouseover ring fades are 0.2 s; the reticle's dot sits on the game's pick
  point with the emblem's diamond around it; the in-range glow is back.
- Nameplates: cleaner name outlines, a line-of-sight fade setting, countdown
  text 6, no subtitle under pets and companions.

## 1.0.0 — 2026-11-12

- An action-MMO setup first, made for a Horde Hunter: the README and reticle
  documentation now say so up front, and explain what sets the reticle apart.
- Reticle: the red dot sits on the client's mouseover pick point (measured to
  within a quarter of a pixel) and the Horde emblem is placed so its diamond
  surrounds it; one piece of code now positions the emblem. The round in-range
  glow is back. `/run SquanchOn.HordeReticle:Test()` previews dot and glow.
- The mouseover gate reaches the nameplates on the press itself, so mouseover
  feedback starts on the first frame the game reports a unit.
- Friendly mouseover ring: 0.2 s fade in and out, also when a unit walks under
  a held-open gate.
- Nameplate names get a clean dark edge from offset copies; the vector outline
  left spikes and nicks on letters such as U, Y and B.
- The small border is used on the game's own controls too: edit boxes,
  dropdowns, checkboxes, sliders, scrollbars, close buttons, insets and cards.
- Efficiency sweep: the target ring and nameplates are event-driven, aura updates are coalesced and refits gated.
- Removed the old unit-frame, nameplate-indicator and tooltip option windows (their last functions moved to the `/squanchon` pages), the retired aura panels, the unloaded LibRangeCheck-3.0 source file and the unused dashed ring art.
- The player frame fades out when idle: out of combat, full health, no target, no cast (setting under Unit Frames).
- Damage meter: column names sit against the top rim; the mode title moved to the right end; the quest title is centred.

- Ship everything in one `SquanchOn/` folder. No other addon, assembly step or
  separately supplied media is needed. Unit-frame layout and presentation are
  independently implemented on separately licensed oUF, LibDispel and LibStub;
  the ElvUI/BenikUI engines and the five-folder assembly are gone.
- Range no longer needs Plater or a range library. A shared range module
  (`Range.lua`) answers distance questions from learned spells and item-range
  checks; its item list derives from LibRangeCheck-3.0 (MIT).
- Add Squanch-On's own camera (`Camera.lua`): every DynamicCam setting, zoom
  curves, eased wheel zoom and situations, with logic partly ported from
  DynamicCam under MIT. Wheel zoom follows DynamicCam's easing algorithm and no
  longer drives backward or halts between notches. It stays inactive while
  DynamicCam is loaded; `/sqms camera takeover|release|status|options`. A
  DynamicCam profile is imported once. `CameraFraming.lua` and
  `/sqms camera setup` are removed. DynamicCam is no longer needed: the author
  now plays on Squanch-On's camera.
- Add one settings window (`/squanchon`) with a category tree, search, undo and
  reset. Changes apply live; combat-restricted changes are queued. Pages:
  General, Mouselook & Reticle, Camera, Unit Frames, Auras & Buffs, Nameplates &
  Target ring, Chat, Damage meter, Bags, Windows & Drawers, Tooltip, Appearance,
  Layout, Profiles, About.
- Add `GraphicsRange.lua` and a Graphics page: the game's detail sliders run past level 10 to the engine's range (ground clutter up to density 256), with no console variables needed.
- Add profiles: one addon-wide profile selected per character; create, copy,
  rename, delete, reset; export and import as a text string (LibSerialize, MIT,
  and LibDeflate, zlib, bundled). Existing settings are migrated at first login
  and a backup is kept in the saved file.
- Add theme, text, chat and drawer settings, and a media library: generated
  status-bar textures and borders (`asset-source/generate-frame-media.py`) and
  SIL OFL fonts (PT Sans Narrow, Overpass, Afacad, Oxanium, Almendra, Barlow
  Condensed, Saira Condensed, Archivo Narrow, Oswald, Bebas Neue, Cinzel,
  Metamorphous, Silkscreen, Pixelify Sans, Share Tech Mono). The author's
  original fonts are not distributed.
- Fonts: five remade SIL OFL fonts (Squanch Highway, Round, Square, Bolt and
  Comic, built by `asset-source/build-fonts.py` from Red Hat Display, Orbitron,
  Amarante and Comic Neue) replace the looser stand-ins in the shipped layout.
  They are rescaled and respaced to the layout's text metrics; Squanch Bolt is
  an original lightning-bolt redraw. The earlier stand-ins stay selectable.
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
  sized so that minimap plus meter equals the chat width. It is a table with
  column headers (#, Name, amount, DPS or HPS, %) and shows first names only by
  default. The mode button is a raised title plate whose menu also lists the
  fights.
- Bags and the settings window get matching title plates. Heading text is drawn
  like an unselected chat tab label; the quest drawer title uses the shared
  heading colour. Fix the scale of the character drawer.
- Target ring: one solid line that lives inside the selected nameplate, is cut
  around the health bar and keeps its size from before the selected plate's
  enlargement, fitted around the faction emblem. On players it can wear the
  health bar's texture and colour ("health bar look": on by default for
  friendly and hostile players; NPCs keep the plain health-coloured ring). A
  hostile player's ring shifts from the class colour with health and pulses in
  execute range. The ring art (`media/Crosshairs/ring-*.tga`) is generated by
  `asset-source/generate-frame-media.py`.
- Add Squanch-On's own nameplates (`Nameplates.lua`, `NameplateStyle.lua`,
  `NameplateCast.lua`, `NameplateAuras.lua`, `NameplateEnhance.lua`,
  `NameplatePreview.lua`). They stay off while Plater is loaded and their
  defaults reproduce the author's previous layout; optional enhancements stay
  off behind a "Classic look" switch (on by default). Player plates show
  surnames and a guild line. A raid mark shows only on a marked unit.
  `/sqplates test [on|off|enh]` shows preview rows, also while Plater is
  loaded; `/sqplates debug` prints one line per visible plate. Plater is no
  longer needed for anything: the author now plays without it.
- Add independently written tooltip presentation and anchor handling; Blizzard
  keeps content, item comparisons and native health values.
- Ship the exact Horde reticle (`HordeReticle.lua`, `HordeReticleData.lua`,
  `media/horde-reticle/`) under GPL-2.0-only. The earlier approximate reticle and
  `ReticleConfig.lua` are removed.
- Start a first run with no saved settings from the author's layout
  (`DefaultProfile.lua`). Positions were authored on a 5120x1440 display; other
  resolutions may need `/sqedit`.
- Verification: checked live only solo and out of combat on the Forever client
  (interface 16001) by the author. Seen: friendly NPC and player nameplates,
  names with surnames and guild lines, the selected-plate treatment and the
  preview cases; the camera takeover at four zoom distances. Not verified:
  combat behaviour in general; nameplates on hostile mobs in combat, cast bars
  and auras on real units, threat colours, the aggro flash, instances and the
  enhancements; the camera while mounted, in combat and on cursor return;
  hostile-target debuffs, pet/party/raid frames, profile switching, export and
  import in game, theme recolouring in game, bag interactions beyond opening
  (use, drag, split, vendor, combat), the meter in combat, the tooltip, and a
  fresh install on other resolutions (offline conversion check only).

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
