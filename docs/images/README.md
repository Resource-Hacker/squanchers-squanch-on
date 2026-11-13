# Images and provenance

| File | Origin and purpose |
| --- | --- |
| `reticle-control.png` | README banner, 2560x1280, composed from real captures; no game pixel is repainted. All of it comes from the author's passive 60 fps screen recording of version 1.0 on 2026-11-12 (5120x1440 HEVC, video only, file `155620-seg1.mkv`, started 15:56:20). Background: the Durotar coast at 76.2 s, a HUD-free 2160x1080 region scaled to 2560x1280 and darkened behind the text. Panels 01 and 02 are frames of one approach to a Clattering Scorpid: 48.05 s (steering, mouseover closed) and 48.60 s (right mouse held: the reticle's red mouseover dot and glow on the scorpid, its plate highlighted). The release after that hold (51.10 s) left the emblem hidden on the scorpid's body, and the gate reopened at 51.25 s, so no readable frame of that release exists. Panel 03 is the closest readable real frame: 45.38 s, an earlier hold, just after its dot went out as the camera turned off the scorpid, with the emblem over open ground. From that picture alone the release cannot be told apart from the reticle leaving the unit; the closed reticle looks the same either way. Each panel is the 254x172 game pixels around the aim point, enlarged 3x nearest-neighbour; the header shows the recording time. Which button was held is read from what the game drew, not from an input log. Title, labels and frame lines are project layout in the bundled OFL fonts Overpass and PT Sans Narrow. |
| `horde-reticle-gameplay.png` | Author's lossless Forever screenshot of version 1.0, 2026-11-12 15:52, Durotar. A HUD-free 1877x1056 region scaled to 1600x900 (Lanczos). Inset: the 72x72 game pixels around the reticle, enlarged 6x nearest-neighbour; the reticle is closed (no target, no mouseover). The gold square, leader line and label are layout. Replaces the 2026-11-10 capture from the earlier Plater setup. |
| `reticle-dot-closeup.png` | 480x480: a real 60x60 crop of the in-game reticle preview (`/run SquanchOn.HordeReticle:Test()`), captured by the author on 2026-11-12 around 15:51, enlarged 8x nearest-neighbour. Shows the red dot and the glow in the emblem's diamond; a preview, not a live target. |
| `range-guide.png` | Selected-target marker legend. All four panels are real captures from the same 2026-11-12 recording; none is a composite of shipped textures. Each is 190x190 game pixels enlarged 3x nearest-neighbour: `160620-seg2.mkv` (started 16:06:20) at 470.0 s, Master Vornal, a selected friendly NPC with the plain ring; `155620-seg1.mkv` at about 102.5 s, a Makrura Clacker at 42% health with the melee blocks; the same file at 93.0 s, a Makrura Clacker at full health with Hunter's Mark and the ranged triangles; `160620-seg2.mkv` at 58.7 s, the friendly player Kabrik Theclaw under the open gate with the ring around their faction emblem (the friendly mouseover ring, not the selected-target ring). A selected friendly player's ring around the emblem was not in the recording; it appears only in `ui-nameplate-preview.png`. Captions and frame lines are layout. |
| `target-ring-gameplay.png` | Author's Forever gameplay development detail, captured 2026-11-10; copied without further image editing. Shows Duokna's dashed selected-target ring and merchant icon. |
| `ui-settings-window.png`, `ui-settings-unit-frames.png`, `ui-settings-camera.png`, `ui-chat-header.png` | Author's Forever captures of the 0.3 standalone interface, 2026-11-11; cropped. They show the settings window and the chat header. |
| `ui-layout-editor.png` | Author's Forever capture of the layout editor over the 0.3 standalone interface, replaced 2026-11-12. Nothing in the picture is covered or retouched; the author's character name is visible. |
| `ui-nameplate-preview.png` | Author's Forever capture of the `/sqplates test on` preview rows (classic look), 2026-11-12. Every plate is a preview drawn for a made-up unit ("Kobold Digger", "Innkeeper" and so on): enemy and friendly NPCs and players, casts, elite, rare and boss units, threat states, tapped, low health, quest units and a selected friendly player with the target ring. It is not live combat and shows no real player. |

`target-ring-gameplay.png` shows the author's earlier setup with Plater
nameplates, before Squanch-On drew its own; its dashed ring is the earlier art,
and the ring is now one solid line inside the selected plate. The other
gameplay images show version 1.0. Stills illustrate the artwork; they are not
proof of an input transition. No private chat, account exports or diagnostic
overlays are included in these example images; other players' and NPCs' names
appear as the game showed them.

Layout elements (titles, captions, frame lines) are original project artwork.
World of Warcraft, its characters, game environments and game-provided artwork
retain Blizzard Entertainment's rights. Screenshot game content is not relicensed under the code's MIT license.
The repository does not distribute extracted Blizzard textures as addon assets.

`ui-bags-minimap-meter.png`, `ui-character-drawer.png`, `ui-hud-strip.png` and `ui-settings-graphics.png` are the author's Forever captures of version 1.0, 2026-11-12, cropped only. Other players' and NPCs' names appear as the game showed them.

`gifs/*.gif` are the author's Forever gameplay, recorded 2026-11-12 between 15:56 and 17:26 at 5120x1440 and 60 fps (video only), then cropped, scaled and converted to GIF; nothing in them is retouched. Chat lines are cropped out. Other players' and NPCs' names appear as the game showed them.

