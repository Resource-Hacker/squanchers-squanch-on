# Open mouseover at the reticle

Squanch-On's defining interaction is a **hold-to-open mouseover gate during
persistent native mouselook**. Camera control continues across both edges of the
right-button press.

![Steer with mouseover closed, hold right mouse to open it, release to close it.](images/reticle-control.svg)

## Three states, one camera

1. **Steer.** Native mouselook is active and the native cursor is hidden. Centered
   mouseover is closed; the reticle artwork can remain visible.
2. **Hold right mouse.** The native down/up binding opens centered mouseover.
   The unit picked by the game under its aim center becomes available through
   WoW's real `mouseover` unit token. Continue steering and press the ability
   you want to use.
3. **Release right mouse.** Mouseover closes immediately. Mouselook remains active.

This lets the player deliberately decide when the aim center should participate
in mouseover targeting. A selected target can remain separate from the unit
under the reticle. The gate itself never casts or selects a hard target.

First-use character setup enables native mouseover casting and sets its modifier
to None. A one-time receipt preserves subsequent user changes. Ordinary action
buttons use the client's targeting behavior; explicit macro targets such as
`[@target]`, `[@focus]` and `[@player]` remain authoritative. Valid unit, spell
range, resources, cooldown and line of sight still matter.

## Getting the cursor back

Hold the free-cursor binding to temporarily release mouselook and use the UI.
Release that binding to return to the center and relock. The default override
bindings are **Caps Lock and Up**, including their modifier combinations.
The native Key Bindings panel exposes the free-cursor action and manual
toggle/lock/unlock actions. `/sqms` shows controls and status; `/sqms off` turns
off this mouselook controller.

Supported menus, layout editing, text entry and ground-targeted abilities suspend
or defer the lock as appropriate. Reopening the lock starts with mouseover closed;
only a still-valid held right-button state can open it again. Protected binding
updates defer during combat.

The cursor is the **native hardware cursor**. Mouselook, the mouseover gate and
cursor return run inside the addon. The author's separate legacy combined-click
helper (interact on left-down, target on left-up while right is held) is not
bundled or required for these features; that historical chord is not an advertised
portable feature of this release.

## Target range feedback

The screen-center reticle and selected-target nameplate marker have different
jobs. The first exposes mouseover when held; the second keeps an existing target
visible and adds range feedback.

![Illustrated range marker legend.](images/range-guide.svg)

| Marker | Meaning | Evidence needed |
| --- | --- | --- |
| Dashed ring | The selected target's visible nameplate; validated world clicks briefly pulse the whole ring. | Current target and matching visible nameplate. |
| Cardinal blocks | Conservative five-yard melee reach. | An affirmative compatible LibRangeCheck-3.0 check. |
| Rotating triangles, hostile | A learned ranged damage ability is in range. | Native spell range; Hunter Auto Shot retains its own check. |
| Rotating triangles, friendly | A learned healing ability is in range. | A known spellbook rank with an affirmative native range result. |
| Friendly ring rotation without triangles | Proximity feedback, also usable for compatible NPCs. | A compatible proximity check within the configured threshold. |

LibRangeCheck-3.0 is optional and normally comes with Plater; Squanch-On does not
bundle it. Without it, five-yard melee and friendly/NPC proximity fallbacks stay
hidden. Native learned-spell checks remain separate. Unknown, restricted or
unavailable range data never enables a range marker.

Healing candidates cover learned spells for Druid, Paladin, Priest and Shaman on
the target client. Hunter Mend Pet and Warlock Health Funnel are restricted to the
player's own pet. Spellbook, specialization and form changes refresh the cache.
This is range feedback, not a promise that a spell is currently castable. Class
coverage in source is not a completed in-game acceptance matrix.

## What makes this control scheme distinctive

The important combination is **persistent native mouselook + a deliberately held
real-mouseover gate + native mouseover casting**. That is the project's focus.
The broader addon ecosystem already has camera, crosshair and targeting tools,
and Squanch-On does not claim to be the first or only reticle addon.

A source comparison on 2026-11-10 found that Action Combat Mode's inspected
reticle preset disables native mouseover casting and uses soft targeting, with a
macro-building click-casting layer. It also has persistent freelook and a similar
native cursor-return technique. The distinction described here concerns those
default targeting contracts, not every possible configuration.
[Pinned CVar preset](https://github.com/ThericGames/combatmode/blob/f8d2fc22bd3f908591722cce61461384141f36d8/CombatMode/Constants/CVars.lua),
[freelook controller](https://github.com/ThericGames/combatmode/blob/f8d2fc22bd3f908591722cce61461384141f36d8/CombatMode/Core/FreeLook/FreeLookController.lua),
[targeting macro builder](https://github.com/ThericGames/combatmode/blob/f8d2fc22bd3f908591722cce61461384141f36d8/CombatMode/Core/ClickCasting/TargetingMacroBuilder.lua).

Other adjacent projects include [MouselookHandler](https://github.com/MouselookHandler/MouselookHandler)
for persistent/inverted mouselook, [ConsolePort](https://github.com/seblindfors/ConsolePort)
for a native controller interface, and [Crosshairs](https://www.wowace.com/projects/crosshairs)
for selected-target nameplate visibility. These links are context, not bundled dependencies.

## Implementation and limits

- [`Core.lua`](../SquanchOn/Core.lua) owns native mouselook, right-button down/up,
  `SetMouseoverHeld`, free-cursor inversion and cursor return.
- [`MouseoverCasting.lua`](../SquanchOn/MouseoverCasting.lua) owns one-time native
  casting settings; it does not dispatch spells.
- [`HordeReticle.lua`](../SquanchOn/HordeReticle.lua) renders feedback from current
  state; it does not choose units.
- [`TargetCrosshairs.lua`](../SquanchOn/TargetCrosshairs.lua) owns the separate
  selected-target range markers.

Native world picking remains subject to camera geometry, overlapping models and
UI interception. The reticle is not an independent world-ray targeting API.
Native cursor return briefly reduces camera speed and restores the exact previous
values on the next update; small residual rotation is possible. Full combat,
focus-loss, platform and client coverage remain subject to
[alpha acceptance](COMPATIBILITY.md).
