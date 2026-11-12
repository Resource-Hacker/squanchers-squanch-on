-- SPDX-License-Identifier: MIT
-- General page: the master switch and the reticle basics. Only settings whose
-- handlers exist today are declared; each `apply` repeats what the matching
-- /sqms command does.
local _, ns = ...
local Options = ns.Options
if not Options then return end

Options:Category({ id = 'general', title = 'General', order = 10,
    desc = 'The master switch, the centre reticle and recovery.' })

Options:Add('general', {
    { id = 'general.enabled', type = 'toggle', label = 'Squanch-On input', section = 'Input', order = 10,
        desc = 'Master switch for mouselook control, the click bindings and the reticle. Same as /sqms on and /sqms off.',
        keywords = 'enable disable master mouselook on off',
        root = 'db', path = 'enabled', default = true, combatSafe = false,
        apply = function(_, value)
            if not value and ns.StopLockedMouselook then ns:StopLockedMouselook() end
            ns:ApplyNativeLeftClickSetting(); ns:ApplyMouselookOverrideBindings(); ns:ApplySafeBindings()
            if value then ns:RequestMouselookRematch(); ns:UpdateReticle() else ns:HideReticleVisuals() end
        end },
    { id = 'general.cursorReturn', type = 'toggle', label = 'Cursor returns to centre', section = 'Input', order = 20,
        desc = 'After the free-cursor key is released, the cursor goes back to the reticle before mouselook locks again. Same as /sqms return on and off.',
        keywords = 'cursor return centre center free release',
        root = 'db', path = 'nativeCursorReturn', default = true, combatSafe = true },

    { id = 'reticle.enabled', type = 'toggle', label = 'Show centre reticle', section = 'Reticle', order = 10,
        desc = 'The Horde reticle at the aim point. Same as /sqms reticle on and off.',
        keywords = 'reticle crosshair horde centre center',
        root = 'db', path = 'hordeReticleEnabled', default = true, combatSafe = true,
        apply = function() ns:UpdateReticle() end },
    { id = 'reticle.scale', type = 'slider', label = 'Reticle size', section = 'Reticle', order = 20,
        desc = 'Size of the centre reticle as a share of its original artwork. It does not follow the interface scale.',
        keywords = 'reticle size scale bigger smaller',
        root = 'db', path = 'hordeReticleScale', min = 0.1, max = 2, step = 0.01, format = '%.0f%%', scale = 100,
        default = 2 / 3, drag = true, combatSafe = true,
        disabled = function() return not ns.HordeReticle end,
        apply = function() ns.HordeReticle:ApplyReticleScale() end },

    { id = 'general.layout', type = 'action', label = 'Move and resize the interface', button = 'Open layout editor',
        section = 'Layout', order = 10, combatSafe = false,
        desc = 'Opens the 10-pixel layout grid. Same as /sqedit.',
        keywords = 'layout editor move resize position grid unlock',
        hidden = function() return not ns.LayoutEditor end,
        func = function()
            if ns.OptionsWindow and ns.OptionsWindow.frame then ns.OptionsWindow.frame:Hide() end
            ns.LayoutEditor:Toggle()
        end },

    { id = 'general.panic', type = 'action', label = 'Panic reset', button = 'Release mouselook', section = 'Recovery', order = 10,
        desc = 'Turns off the mouselook lock and the helper bindings and hides the reticle, as /sqms panic does. Turn them back on with /sqms lock on and /sqms bindings on.',
        keywords = 'panic stuck reset recover unlock emergency',
        confirm = 'This turns off the mouselook lock and helper bindings.', combatSafe = false,
        func = function()
            local db = ns.db
            db.enableSafeHelperBindings, db.controlMouselookState, db.alwaysMouselook = false, false, false
            ns:StopLockedMouselook(); ns:ApplyNativeLeftClickSetting(); ns:ApplyMouselookOverrideBindings()
            ns:ClearSafeBindings(); ns:HideReticleVisuals()
            return 'Mouselook lock and helper bindings are off.'
        end },
})
