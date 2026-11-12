-- SPDX-License-Identifier: MIT
-- Reticle page. The two rows keep the ids first declared on the General page,
-- so declaring them here moves them: one row per setting, on the page the
-- category tree names for it. `apply` repeats /sqms reticle.
local _, ns = ...
local Options = ns.Options
if not Options then return end

Options:Category({ id = 'reticle', parent = 'mouselook', title = 'Reticle', order = 30,
    desc = 'The Horde reticle drawn at the aim point. Its position is set on the Mouselook page.' })

Options:Add('reticle', {
    { id = 'reticle.enabled', type = 'toggle', label = 'Show centre reticle', section = 'Reticle', order = 10,
        desc = 'The Horde reticle at the aim point. Same as /sqms reticle on and off.',
        keywords = 'reticle crosshair horde centre center show hide',
        root = 'db', path = 'hordeReticleEnabled', default = true, combatSafe = true,
        apply = function() ns:UpdateReticle() end },
    { id = 'reticle.scale', type = 'slider', label = 'Reticle size', section = 'Reticle', order = 20,
        desc = 'Size of the centre reticle as a share of its original artwork. It does not follow the interface scale. Same as /sqms reticle scale.',
        keywords = 'reticle size scale bigger smaller',
        root = 'db', path = 'hordeReticleScale', min = 0.1, max = 2, step = 0.01, format = '%.0f%%', scale = 100,
        default = 2 / 3, drag = true, combatSafe = true,
        disabled = function() return not ns.HordeReticle end,
        apply = function() ns.HordeReticle:ApplyReticleScale() end },
})
