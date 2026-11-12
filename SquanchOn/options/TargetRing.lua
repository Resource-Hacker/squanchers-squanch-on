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
        step = 1, format = '+%d px', default = 2, drag = true, apply = refit, disabled = noFit }),

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
