-- SPDX-License-Identifier: MIT
-- Target ring page: the settings TargetCrosshairs.lua already stores. Every
-- change goes through marker:ApplyStyle(), which clamps and redraws.
local _, ns = ...
local Options = ns.Options
if not Options then return end

local function marker() return ns.TargetCrosshairs end
Options:Root('targetring', function() local ring = marker(); return ring and ring.db end)
Options:Category({ id = 'nameplates', title = 'Nameplates & Target ring', order = 60,
    desc = 'Indicators drawn on nameplates and the ring around the selected target.' })
Options:Category({ id = 'targetring', parent = 'nameplates', title = 'Target ring', order = 70,
    desc = 'The ring on the selected target, its fit on friendly targets, guide lines and health colouring.',
    hidden = function() return not marker() end })

local function style() marker():ApplyStyle() end
-- Friendly-fit values are read at the next target refresh.
local function refit() local ring = marker(); ring:ApplyStyle(); ring:RefreshTarget() end
-- The mouseover ring and its preview plate follow at once.
local function hover()
    if ns.NameplateHoverRing then ns.NameplateHoverRing:Refresh() end
    if ns.NameplatePreview then ns.NameplatePreview:Refresh() end
end
local function noHover() local ring = marker(); return not (ring and ring.db.hoverRing ~= false) end
local function noFit() local ring = marker(); return not (ring and ring.db.friendlyFit ~= false) end
local function row(spec)
    spec.root, spec.combatSafe = 'targetring', true
    spec.apply = spec.apply or style
    return spec
end

Options:Add('targetring', {
    row({ id = 'targetring.enabled', type = 'toggle', label = 'Show target ring', section = 'Ring', order = 10,
        desc = 'Draws the ring on the nameplate of the selected target. Same as /sqcrosshairs on and off.',
        keywords = 'crosshairs target marker ring enable', path = 'enabled', default = true,
        apply = function(_, value) marker():SetEnabled(value) end }),
    row({ id = 'targetring.size', type = 'slider', label = 'Ring size', section = 'Ring', order = 20,
        desc = 'Width of the ring in interface units.',
        keywords = 'crosshairs ring size diameter', path = 'size', min = 1, max = 2048, softMin = 24, softMax = 256, step = 1,
        default = 64, drag = true }),
    row({ id = 'targetring.alpha', type = 'slider', label = 'Ring opacity', section = 'Ring', order = 30,
        desc = 'How solid the ring is drawn.',
        keywords = 'crosshairs ring opacity alpha transparency', path = 'alpha', min = 0, max = 1, step = 0.01,
        format = '%.0f%%', scale = 100, default = 0.65, drag = true }),
    row({ id = 'targetring.rotation', type = 'slider', label = 'Rotation period', section = 'Ring', order = 40,
        desc = 'Seconds the ring and its range marks take for one full turn.',
        keywords = 'crosshairs rotation spin speed seconds', path = 'rotationSeconds', min = 0.01, max = 3600, softMin = 1, softMax = 20,
        step = 0.5, format = '%.1f s', default = 5 }),

    row({ id = 'targetring.friendlyFit', type = 'toggle', label = 'Hug the icon', section = 'Friendly target', order = 10,
        desc = 'On a friendly target the ring shrinks to sit around the faction or class icon on its nameplate.',
        keywords = 'friendly ring icon emblem fit hug', path = 'friendlyFit', default = true, apply = refit }),
    row({ id = 'targetring.friendlyTighten', type = 'slider', label = 'Fit', section = 'Friendly target', order = 20,
        desc = 'Share of the measured icon size the ring is fitted to. Lower is tighter.',
        keywords = 'friendly ring tight snug fit size', path = 'friendlyTighten', min = 0.3, max = 2, softMin = 0.5, softMax = 1.25,
        step = 0.01, format = '%.0f%%', scale = 100, default = 0.75, drag = true, apply = refit, disabled = noFit }),
    row({ id = 'targetring.friendlyGrow', type = 'slider', label = 'Extra width', section = 'Friendly target', order = 30,
        desc = 'Screen pixels added to the fitted ring width.',
        keywords = 'friendly ring wider pixels width', path = 'friendlyGrow', min = -40, max = 80, softMin = -10, softMax = 30,
        step = 1, format = '%d px', default = 9, drag = true, apply = refit, disabled = noFit }),
    row({ id = 'targetring.friendlyThickness', type = 'slider', label = 'Line thickness', section = 'Friendly target', order = 40,
        desc = 'Screen pixels added to the thickness of the friendly ring line, at the same radius.',
        keywords = 'friendly ring line thick thickness', path = 'friendlyThickness', min = 0, max = 12, softMax = 8,
        step = 1, format = '+%d px', default = 1, drag = true, apply = refit, disabled = noFit }),

    row({ id = 'targetring.friendlyClassColor', type = 'toggle', label = 'Class colour', section = 'Friendly target', order = 50,
        desc = 'On a friendly player the ring takes that player\'s class colour instead of the health colour. Applies while the health bar look is off or the plate bar has no colour to give.',
        keywords = 'friendly ring class colour color', path = 'friendlyClassColor', default = true, apply = refit }),

    row({ id = 'targetring.barLookThickness', type = 'slider', label = 'Health bar look: extra thickness', section = 'Friendly target', order = 58,
        desc = 'Screen pixels added to the line of a ring that wears the health bar look. The ring keeps its radius; the line moves to the nearest drawn width.',
        keywords = 'ring bar look line thick thickness', path = 'barLookThickness', min = 0, max = 12, softMax = 6, step = 1, default = 1, apply = refit }),

    row({ id = 'targetring.hoverGlow', type = 'toggle', label = 'Glow on mouseover', section = 'Friendly target', order = 56,
        desc = 'While the mouse is over the selected player, the ring brightens and gains a soft glow around its outside.',
        keywords = 'ring mouseover hover glow highlight', path = 'hoverGlow', default = true, apply = refit }),
    row({ id = 'targetring.hoverGlowStrength', type = 'slider', label = 'Mouseover glow strength', section = 'Friendly target', order = 57,
        keywords = 'ring mouseover hover glow strength', path = 'hoverGlowStrength', min = 0, max = 2, step = 0.05, default = 1, drag = true, apply = refit }),

    row({ id = 'targetring.friendlyBarLook', type = 'toggle', label = 'Health bar look on players', section = 'Friendly target', order = 60,
        desc = 'On a friendly player the ring takes the texture of the nameplate health bar and the colour that bar shows.',
        keywords = 'friendly ring bar look texture colour color nameplate health', path = 'friendlyBarLook', default = true, apply = refit }),

    row({ id = 'targetring.friendlyNpcBarLook', type = 'toggle', label = 'Health bar look on NPCs', section = 'Friendly target', order = 65,
        desc = 'Off keeps the plain ring on friendly NPCs, coloured white to orange to red by health.',
        keywords = 'friendly npc ring bar look texture colour color nameplate health', path = 'friendlyNpcBarLook', default = false, apply = refit }),

    row({ id = 'targetring.hoverRing', type = 'toggle', label = 'Health ring on mouseover', section = 'Friendly mouseover', order = 10,
        desc = 'While the mouse is over a friendly player who is not your target, the nameplate shows the faction emblem inside a ring that is the health bar: full at 100%, emptying clockwise from the top, class colour shifting to orange and red.',
        keywords = 'friendly mouseover hover ring radial health emblem faction', path = 'hoverRing', default = true, apply = hover }),
    row({ id = 'targetring.hoverRingWidth', type = 'choice', label = 'Line width', section = 'Friendly mouseover', order = 20,
        desc = 'Thickness of the ring line. Same as target ring follows the line the ring takes once the player is selected.',
        keywords = 'friendly mouseover hover ring line width thick thickness', path = 'hoverRingWidth',
        values = { 0, 3, 5, 8, 12 }, labels = { 'Same as target ring', 'Thin', 'Medium', 'Thick', 'Heavy' },
        default = 0, apply = hover, disabled = noHover }),
    row({ id = 'targetring.hoverRingTrack', type = 'slider', label = 'Empty part opacity', section = 'Friendly mouseover', order = 30,
        desc = 'How solid the missing-health part of the ring is drawn, in the colour of the nameplate bar background.',
        keywords = 'friendly mouseover hover ring track background empty opacity', path = 'hoverRingTrack', min = 0, max = 1, step = 0.01,
        format = '%.0f%%', scale = 100, default = 0.4, drag = true, apply = hover, disabled = noHover }),

    row({ id = 'targetring.hostilePlayerBarLook', type = 'toggle', label = 'Health bar look on players', section = 'Hostile target', order = 10,
        desc = 'On a hostile player the ring takes the texture and colour of the nameplate health bar. The execute pulse and range marks stay as they are.',
        keywords = 'hostile enemy player ring bar look texture colour color nameplate', path = 'hostilePlayerBarLook', default = true, apply = refit }),
    row({ id = 'targetring.hostilePlayerHealthShift', type = 'toggle', label = 'Player health shift', section = 'Hostile target', order = 15,
        desc = 'A hostile player\'s ring starts at the class colour and shifts to orange and red as health drops, like the plain ring. Needs Colour by health.',
        keywords = 'hostile enemy player ring health shift class colour color orange red', path = 'hostilePlayerHealthShift', default = true, apply = refit,
        disabled = function() local ring = marker(); return not (ring and ring.db.hostilePlayerBarLook ~= false and ring.db.healthColor) end }),
    row({ id = 'targetring.hostileNpcBarLook', type = 'toggle', label = 'Health bar look on NPCs', section = 'Hostile target', order = 20,
        desc = 'On a hostile or neutral NPC the ring follows the nameplate health bar, threat colours included, instead of the plain ring coloured by health.',
        keywords = 'hostile enemy neutral npc ring bar look texture colour color threat nameplate', path = 'hostileNpcBarLook', default = false, apply = refit }),

    row({ id = 'targetring.lines', type = 'toggle', label = 'Guide lines', section = 'Guide lines', order = 10,
        desc = 'Draws thin lines from the ring to the screen edges. Same as /sqcrosshairs lines on and off.',
        keywords = 'crosshairs guide lines cross', path = 'showLines', default = false }),

    row({ id = 'targetring.healthColor', type = 'toggle', label = 'Colour by health', section = 'Health', order = 10,
        desc = 'The ring shifts from white through orange to red as the target loses health.',
        keywords = 'health colour color red orange', path = 'healthColor', default = true }),
    row({ id = 'targetring.pulse', type = 'toggle', label = 'Execute pulse', section = 'Health', order = 20,
        desc = 'The ring pulses while the target is below the execute threshold.',
        keywords = 'execute kill shot pulse low health', path = 'showKillShotPulse', default = true }),
    row({ id = 'targetring.threshold', type = 'slider', label = 'Execute threshold', section = 'Health', order = 30,
        desc = 'Health share below which the execute pulse starts.',
        keywords = 'execute kill shot threshold percent', path = 'killShotThreshold', min = 0, max = 1, step = 0.01,
        format = '%.0f%%', scale = 100, default = 0.20,
        disabled = function() local ring = marker(); return not (ring and ring.db.showKillShotPulse) end }),
})
