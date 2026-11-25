# Changelog

## 1.0.4 — 2026-11-24

- Camera: zooming with a target selected turns the view onto it, and the view
  now stays there when the zoom stops instead of swinging back. Where the game
  tells addons where a unit stands the turn is worked out from that and is
  exact; for other units the game's own target focus does the turning and is
  taken over as a real turn. Your character keeps its own facing; part of your
  next mouse turns lines the two up again.
- Camera: with nothing selected, holding the reticle open follows the unit
  that comes under it, also while it walks, until you let go.
- Camera: an option (Camera page, "Open reticle: your target waits in the
  focus while you hold it", off by default) makes a selected enemy your
  focus and clears your target while the reticle is held, so the game's own
  soft target and camera follow whatever comes under the reticle, as with
  nothing selected; letting go makes it your target again, unless you
  selected something else meanwhile. The target frames, the target's
  nameplate marker, the target crosshair and the reticle's target marks keep
  showing it. Target and focus can only be changed inside a key press, so
  the reticle's own press does it. Auto-attack and Auto Shot shoot the
  target only: they stop while you hold, and the first harmful spell you
  cast makes its own target your target. A focus you set yourself is
  replaced.
- Camera: with nothing selected, zooming turns the view onto the enemy
  nearest the reticle and leaves it there (Camera page, "Zoom sticks to the
  enemy near the reticle", on by default, with a slider for how near).
  Nothing is held while you are not zooming.
- Camera: the open reticle follows what is under it, selected or not, and
  stays on it until you let go, also while it walks or you strafe; then the
  view comes back to where it rests. A unit the game gives a position for is
  followed by that. Opened on your target, the game's camera focus follows
  the target. With nothing selected, the game's own soft target and camera
  focus keep the enemy in front on the reticle; they are switched on only
  while the reticle is held and put back when you let go (Camera page, "Open
  reticle: other enemies by the game's soft target", on by default). The
  soft target's cone starts at its narrowest and goes wider, step by step,
  until it has taken the unit under the reticle; nothing else it finds is
  followed. With nothing selected that is the only following. With
  something else selected, the game's enemy focus cannot be used (it goes
  to your target wherever you have one; tried: the game does soft-target
  the unit under the reticle beside a selected target, and still turns the
  view to the target). The game has a second camera focus, for what you
  interact with; pointing that at the unit under the reticle can be tried
  (Camera page, "Open reticle: other units by the game's interact focus",
  off by default: one test run looked as if it held a unit that was not the
  target, six more did not). The addon's own following is what is used:
  the view is held on the place of the unit under the reticle: it makes up
  for your own walking and strafing by the
  unit's distance, and it follows a unit that walks. For that it does not
  search (it used to glide to one side and the other looking for a unit
  that had slipped off; with only "under the reticle or not" to go by that
  was a hunt and looked like one). The game tells how fast a unit moves,
  and its nameplate how fast it comes nearer or goes further off; what is
  left of its speed is what it moves across the view, and the view turns
  with it at exactly that rate, at the unit's middle. Two things are not
  told and are found out. How long a kind of unit is: the game
  tells an addon the box about a unit's model (2.94 by 0.90 yards for the
  Dire Mottled Boar), and what the reticle picks of it is a little less
  (2.5 to 2.6 yards walked under a still reticle: 0.87 of the model's
  length), so each kind of unit is asked for once and kept; where the game
  does not tell, the first one that walks right through a still reticle is
  let through and measured. Which way it
  walks: one small step when it walks into the reticle (the view is at its
  middle a fraction of a second after the reticle's dot lights) or out from
  under it. Out from under it the side is told beforehand where it can be:
  the view rides a fifth of a yard behind the unit's middle, so a unit gone
  after less than half its length has walked on as before, and one gone
  after more has turned back. Lost after it turned, the view looks behind
  first. None of these moves lands in one frame any more: beside the even
  turning with the unit, a step or a glide is paid out at twenty degrees a
  second, setting in and leaving off over a frame or two (in the owner's
  log a single frame had turned the view by up to a degree, thirty pixels).
  And the unit's pace is no longer upset by the view's own turning. The
  plate's reading is the unit's distance from the camera, and turning the
  view moves the camera: round the pivot, nearer or further by the
  shoulder's offset for each radian (taken out), and by whatever the
  ground does where it pushes the camera in (a third of a yard at each
  jump in the owner's log, which made the unit seem to rush at the camera,
  stopped the following and brought the next jump: seven in five seconds).
  Where the reading says the unit moves faster than it can while the view
  turns briskly, the reading is left out during such turning. A unit that
  walks straight at the camera or away from it is not turned for: what is
  left of its speed to go across the view is next to nothing then and not
  known (its speed along the view reads a tenth either side of its whole
  speed from moment to moment, over uneven ground), and what seemed left
  had the view drift a degree or two a second to the side it had last
  gone. Where nine tenths of its speed or more seem to go along the view,
  nothing is turned at first; if the unit then leaves the reticle and is
  found ahead, it does move across, and half of what seemed left is turned
  for, then all of it; found behind, less again. A unit that runs in
  close used to be let go at ten yards (by the range checks, about twelve
  from centre to centre), and the view then swung back to where it rests
  at up to three degrees a frame the moment the unit left the reticle: it
  pushed the reticle off a unit running in to melee. It is let go at five
  yards now, and the view then stays where it is until the reticle closes.
  In a fight the game hides every other unit's speed from addons (in
  combat 203 samples of 203; out of it none), and without it nothing
  that moved was followed. Now a unit whose plate says it comes nearer or
  goes off faster than a yard a second, while the character itself stands,
  is taken to run (seven yards a second, or faster where the plate says
  so) until it is found behind a view that ran on ahead of it. A mob
  running in at an angle stays on the reticle 76 to 97 per cent of the time
  in the simulation (was 4 to 12); one crossing straight across the view
  while the character strafes is still not followed.
  Where a model's box is
  much bigger than what the reticle picks (a Clattering Scorpid's box is
  2.93 by 2.13 yards for its claws and legs, its picked body under a
  yard), the glide to the box's middle went out at the unit's far end and
  the step that followed went the wrong way or not far enough. Gone out at
  the far end while the glide was still under way (and the unit had not
  turned meanwhile), the view now steps back to the middle of what it
  went through; two such crossings that agree settle what share of the box
  the reticle picks for that kind of unit, which is kept. Steps in quick
  succession end the
  following for that unit rather than hunt for it (Camera page, "Open
  reticle: follows a held unit that walks", on by default). While your
  mouse is turning the view nothing is asked.
  The distance is read from the unit's nameplate: the game sizes a
  nameplate by its distance from the camera and lets an addon read that
  size, though not where the plate is, so the addon keeps that sizing on at
  a slope too slight to see (a plate 30 yards off is about one per cent
  smaller; the selected plate is not touched) and reads it as yards. Where
  there is no reading (no nameplates, the game's own plates, a plate kept
  secret) the distance comes from the game's range checks instead (five
  yards wide, counted between the two units' hit areas, which is allowed
  for), is kept up as you walk towards the unit or away, and is set right
  whenever a check changes its answer. The game reports your position in
  uneven steps; they are evened
  out, nothing lands in a single frame, and the point the game picks at is
  never moved (that had shifted the reticle and its dot up and down). The
  game does not let soft targeting be switched on in combat,
  so it is switched on when you select an enemy and kept through the fight
  (for when your target is dead or gone), set so that nothing is
  soft-targeted while the reticle is closed and a target is selected; in a
  fight that began with nothing selected the reticle does not follow
  without a target. While a unit is held that way the mouse turns
  the view as ever (Camera page, "Open reticle: the mouse still turns the
  view on a held unit", on by default; off holds the view still on the unit
  against the mouse while it is under the reticle). Off the unit for two
  seconds, or taken well aside by the mouse, the hold rests until the unit
  is under the reticle again; another unit that comes under the reticle and
  stays is the one held from then on.
- Camera: the view is no longer thrown about by the open reticle. A unit
  within ten yards is left to the game's own swivel instead of being turned
  after (every step of such a unit swings the view far round); when the
  game's soft target goes over to another enemy somewhere about, the view no
  longer swings to that one; and your own pet beside you is not followed.
- Camera: when the unit the view was turned onto dies, the view goes back to
  where it rests: with the reticle still held on the corpse, and also after
  a zoom's turn (which stays otherwise). The dead are not followed, and a
  dead target counts as nothing selected.
- Camera: while the reticle is open, zooming no longer pulls the view to
  your target.
- Camera: with nothing selected, a zoom also sticks to an enemy the game
  gives no position for: its soft target is switched on for the length of
  the zoom to find the enemy in front, and put back afterwards (Camera page,
  "Zoom sticks: other enemies by the game's soft target", on by default).
- Camera: experimental setting, off by default: in first person the view
  steps half a yard out while the open reticle follows through the game's
  focus (which does not seem to act in first person).
- Camera: a zoom with a target the game gives no position for takes the
  game's focus over as a turn from the first moment and without pausing;
  before, it waited, turned a little, waited again and then went on, which
  showed as a jerky zoom.
- Camera: after the view was turned onto a unit it comes round behind your
  character as soon as the character moves; before, it stayed askew and the
  character ran sideways across the screen. Standing still, the view stays
  where it was left.
- Camera: quick wheel zooming no longer flickers the shoulder offset and field
  of view. The game reports a false zoom distance for a frame or two while a
  quick zoom is corrected; those readings are now ignored.
- Camera options: the Aim convergence section is rearranged around the above
  (stay, follow, catch-up, a limit for the turn).
- Camera: a game setting borrowed for a zoom or for the open reticle that the
  game refuses to put back in combat is now put back when combat ends, instead
  of staying changed.
- Pet frame: the name is centred on the health area and the happiness face
  sits in the top left corner of the portrait box.
- Short power bars (the pet's energy bar) sit on whole pixels, so their rim is
  complete and no gap shows above them.
- Pet marker: the claw above your pet is half its old size and shows the
  pet's threat: pulsing orange in combat, red while it holds aggro, orange
  while it is losing it, and a larger pulsing yellow once the mob is on you.
- Target frame: the class/reaction colour fill under the bars was missing
  (only the thin highlight showed); it now fills to the bottom rim like the
  player frame.
- Menu icons: the Friends button is exactly the size of the other icons and
  sits on the same spacing.
- Menu icons: the green latency line under the game menu button is gone (the
  button's tooltip still shows latency).
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
- Drawer windows much wider than the chat (the talent trees) come up to the
  character sheet's height instead of being shrunk to the chat's width.
- Camera: "Aim convergence" (Camera page, off by default). Zooming between
  first person and third person turns the camera with the shoulder offset so
  what the reticle is on stays under it.
- The click pulse on a selected target resizes the ring itself, so a ring
  split by the health bar shrinks and returns as a plain circle.
- The world map shows its terrain on the first open after a reload (a loaded
  terrain layer could stay invisible until the map was reopened).

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
