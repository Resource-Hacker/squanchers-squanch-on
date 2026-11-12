-- SPDX-License-Identifier: MIT
-- Mouselook pages: lock rules, aim point, clicks and mouseover. Every option
-- repeats what the matching /sqms command does; settings without a command
-- call the refresh their reader needs. Keys in the saved table that no code
-- reads (reticleAlpha, mouseoverIndicator and the like) get no control.
local _, ns = ...
local Options = ns.Options
if not Options then return end

Options:Category({ id = 'mouselook', title = 'Mouselook & Reticle', order = 20,
    desc = 'Locked mouselook, the click bindings used while it is locked, and the centre reticle.' })
Options:Category({ id = 'mouselook.lock', parent = 'mouselook', title = 'Mouselook', order = 10,
    desc = 'When the camera stays locked to the mouse and where the aim point sits.' })
Options:Category({ id = 'mouselook.clicks', parent = 'mouselook', title = 'Clicks & Mouseover', order = 20,
    desc = 'What the mouse buttons do while mouselook is locked.' })

local function rematch() ns:RequestMouselookRematch() end
local function rebind() ns:ApplyMouselookOverrideBindings() end
local function locked() return ns.db and ns.db.alwaysMouselook and ns.db.controlMouselookState and true or false end

-- Binding commands offered for a locked mouse button. A saved command that is
-- not listed stays selectable so opening the page never loses it.
local commandLabels = {
    TARGETSCANENEMY = 'Target enemy at the reticle', TARGETNEARESTENEMY = 'Target nearest enemy',
    TARGETMOUSEOVER = 'Target mouseover', INTERACTMOUSEOVER = 'Interact with mouseover',
    INTERACTTARGET = 'Interact with target', NULL = 'Nothing',
}
local commandOrder = { 'TARGETSCANENEMY', 'TARGETNEARESTENEMY', 'TARGETMOUSEOVER', 'INTERACTMOUSEOVER', 'INTERACTTARGET', 'NULL' }
local function commands(key)
    return function()
        local list, current = {}, ns.db and ns.db[key]
        for index, command in ipairs(commandOrder) do list[index] = command end
        if type(current) == 'string' and not commandLabels[current] then list[#list + 1] = current end
        return list
    end
end

Options:Add('mouselook.lock', {
    { id = 'mouselook.lock', type = 'toggle', label = 'Keep mouselook locked', section = 'Lock', order = 10,
        desc = 'The camera follows the mouse and the cursor stays hidden until a window opens or the free-cursor key is held. Same as /sqms lock on and off.',
        keywords = 'lock always mouselook camera cursor hidden',
        default = true, combatSafe = false,
        get = locked,
        set = function(_, value)
            local db = ns.db
            db.controlMouselookState, db.alwaysMouselook = value, value
            if not value then ns:StopLockedMouselook() end
            ns:ApplyNativeLeftClickSetting(); ns:ApplyMouselookOverrideBindings(); ns:ApplySafeBindings()
            if value then ns:RequestMouselookRematch() end
        end },
    { id = 'mouselook.whileMoving', type = 'toggle', label = 'Lock while moving', section = 'Lock', order = 20,
        desc = 'Mouselook locks whenever the character is moving.',
        keywords = 'auto move moving run walk',
        root = 'db', path = 'autoMouselookWhileMoving', default = true, combatSafe = true, apply = rematch },
    { id = 'mouselook.inCombat', type = 'toggle', label = 'Lock in combat', section = 'Lock', order = 30,
        desc = 'Mouselook locks whenever the character is in combat.',
        keywords = 'auto combat fight',
        root = 'db', path = 'autoMouselookInCombat', default = true, combatSafe = true, apply = rematch },
    { id = 'mouselook.spellTargeting', type = 'toggle', label = 'Release for ground-targeted spells', section = 'Lock', order = 40,
        desc = 'The lock lets go while a spell waits for a place on the ground, so the targeting circle can be aimed.',
        keywords = 'ground aoe targeting circle spell release',
        root = 'db', path = 'useSpellTargetingOverride', default = true, combatSafe = true, apply = rematch },

    { id = 'mouselook.cursorHeight', type = 'slider', label = 'Aim point height', section = 'Aim point', order = 10,
        desc = 'Height of the locked aim point on the screen, from the bottom (0%) to the top (100%). Same as /sqms cursor.',
        keywords = 'cursor centre center height vertical aim position',
        min = 0, max = 1, step = 0.005, format = '%.1f%%', scale = 100, default = 0.5, combatSafe = false,
        get = function() return tonumber(ns.db.cursorCenteredYPos) or 0.5 end,
        -- The command also restarts an active lock, through state private to Core.lua.
        set = function(_, value) ns:SlashCommand(string.format('cursor %.4f', value)) end },
    { id = 'mouselook.aimX', type = 'number', label = 'Reticle offset X', section = 'Aim point', order = 20,
        desc = 'Moves the reticle sideways from the aim point, in interface units. Same as /sqms aim.',
        keywords = 'aim offset horizontal reticle position',
        root = 'db', path = 'aimXOffset', min = -500, max = 500, integer = true, default = 0, combatSafe = true,
        apply = function() ns:UpdateAimPoint(); ns:UpdateReticle() end },
    { id = 'mouselook.aimY', type = 'number', label = 'Reticle offset Y', section = 'Aim point', order = 30,
        desc = 'Moves the reticle up or down from the aim point, in interface units. Same as /sqms aim.',
        keywords = 'aim offset vertical reticle position',
        root = 'db', path = 'aimYOffset', min = -500, max = 500, integer = true, default = 0, combatSafe = true,
        apply = function() ns:UpdateAimPoint(); ns:UpdateReticle() end },

    { id = 'mouselook.relockDelay', type = 'slider', label = 'Relock delay', section = 'Advanced', order = 10,
        desc = 'Pause between releasing the free-cursor key and mouselook locking again.',
        keywords = 'invert free cursor relock delay seconds',
        root = 'db', path = 'invertRelockDelay', min = 0, max = 0.5, step = 0.01, format = '%.2f s', default = 0.08, combatSafe = true },
    { id = 'mouselook.deferStop', type = 'toggle', label = 'Wait for mouse buttons before unlocking', section = 'Advanced', order = 20,
        desc = 'An automatic unlock waits until every mouse button is released, which avoids a stuck camera drag.',
        keywords = 'defer workaround stuck button unlock',
        root = 'db', path = 'useDeferWorkaround', default = true, combatSafe = true },
})

Options:Add('mouselook.clicks', {
    { id = 'mouselook.native', type = 'toggle', label = 'Hold right button for mouseover', section = 'Right button', order = 10,
        desc = 'Holding the right button opens mouseover at the reticle and releasing it closes mouseover again. Same as /sqms native on and off.',
        keywords = 'right click hold mouseover gate centered native',
        default = true, combatSafe = false,
        get = function() return ns.db.nativeCenteredMouseover and true or false end,
        -- The command also restarts an active lock, through state private to Core.lua.
        set = function(_, value) ns:SlashCommand(value and 'native on' or 'native off') end },
    { id = 'mouselook.button2', type = 'choice', label = 'Right button command', section = 'Right button', order = 20,
        desc = 'What the right button does while locked when it does not open mouseover.',
        keywords = 'right button binding command',
        root = 'db', path = 'mouselookButton2Command', values = commands('mouselookButton2Command'), labels = commandLabels,
        default = 'NULL', combatSafe = false, apply = rebind,
        disabled = function() return ns.db.nativeCenteredMouseover and true or false end },

    { id = 'mouselook.leftClick', type = 'toggle', label = 'Native left click', section = 'Left button', order = 10,
        desc = 'A left click while locked selects and interacts as the game does without the addon. Same as /sqms left on and off.',
        keywords = 'left click select interact camera native',
        root = 'db', path = 'nativeLeftClick', default = true, combatSafe = false,
        apply = function(_, value)
            if not value then ns:RestoreNativeLeftDelta('left-disabled') end
            ns:ApplyNativeLeftClickSetting(); ns:ApplyMouselookOverrideBindings(); ns:RequestMouselookRematch()
        end },
    { id = 'mouselook.button1', type = 'choice', label = 'Left button command', section = 'Left button', order = 20,
        desc = 'What the left button does while locked when native left click is off, or while the right button is held.',
        keywords = 'left button binding command target',
        root = 'db', path = 'mouselookButton1Command', values = commands('mouselookButton1Command'), labels = commandLabels,
        default = 'TARGETSCANENEMY', combatSafe = false, apply = rebind },
    { id = 'mouselook.chord', type = 'toggle', label = 'Combined click', section = 'Left button', order = 30,
        desc = 'While the right button is held, a left click interacts with the mouseover unit. Same as /sqms chord on and off.',
        keywords = 'chord combined click interact both buttons',
        root = 'db', path = 'nativeCombinedClick', default = false, combatSafe = false, apply = rebind },

    { id = 'mouselook.mouseoverCast', type = 'toggle', label = 'Mouseover casting', section = 'Mouseover', order = 10,
        desc = "Turns on the game's own mouseover casting with no modifier key, so action buttons cast at the unit under the reticle while the right button is held. Same as /sqms mouseover on and off.",
        keywords = 'mouseover cast casting modifier heal',
        default = true, combatSafe = false,
        get = function() return GetCVar('enableMouseoverCast') == '1' end,
        set = function(_, value)
            if not ns:ConfigureMouseoverCasting(value, false) then
                error('The game did not accept the mouseover casting setting.', 0)
            end
        end },

    { id = 'mouselook.overrideBindings', type = 'toggle', label = 'Use locked-mouse bindings', section = 'Bindings', order = 10,
        desc = 'Lets the addon bind the mouse buttons while mouselook is locked. With this off, the buttons keep the game defaults.',
        keywords = 'override bindings mouse buttons',
        root = 'db', path = 'useMouselookOverrideBindings', default = true, combatSafe = false,
        apply = function() ns:ApplyNativeLeftClickSetting(); ns:ApplyMouselookOverrideBindings(); ns:RequestMouselookRematch() end },
    { id = 'mouselook.helperBindings', type = 'toggle', label = 'Helper bindings', section = 'Bindings', order = 20,
        desc = 'Binds Caps Lock and Up as the free-cursor key, and F8 and F9 to interact with and target the mouseover unit. Same as /sqms bindings on and off.',
        keywords = 'helper safe bindings keys free cursor caps lock f8 f9',
        root = 'db', path = 'enableSafeHelperBindings', default = true, combatSafe = false,
        apply = function(_, value) if value then ns:ApplySafeBindings() else ns:ClearSafeBindings() end end },
})
