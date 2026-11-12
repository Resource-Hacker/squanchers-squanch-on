-- SPDX-License-Identifier: MIT
-- Profiles page: which profile this character uses, the profile list, and
-- export/import strings. Every row calls ns.Profiles; the name and string
-- boxes hold session text only.
local _, ns = ...
local Options, Profiles = ns.Options, ns.Profiles
if not Options or not Profiles then return end

local ui = Profiles.ui
-- An edit box keeps focus when a button is clicked; releasing it commits its text first.
local function settle()
    local focus = GetCurrentKeyboardFocus and GetCurrentKeyboardFocus()
    if focus and focus.ClearFocus then focus:ClearFocus() end
end
-- Runs a Profiles call that returns ok, message, as an action row expects.
local function run(method, ...)
    settle()
    local ok, message = Profiles[method](Profiles, ...)
    if not ok then return false, message end
    return message
end
local function others()
    local names = {}
    for _, name in ipairs(Profiles:Names()) do
        if name ~= Profiles:Current() and name ~= 'Default' then names[#names + 1] = name end
    end
    return names
end
local function session(key)
    return function() return ui[key] or '' end, function(_, value) ui[key] = value or '' end
end
local getName, setName = session('name')
local getImport, setImport = session('import')

Options:Category({ id = 'profiles', title = 'Profiles', order = 150,
    desc = 'A profile holds every setting of the addon. Each character uses one; several characters can share it.' })

Options:Add('profiles', {
    { id = 'profiles.current', type = 'choice', label = 'Profile in use', section = 'This character', order = 10,
        desc = 'The profile this character uses. Switching applies what can change at once and asks for a reload for the rest (layout, camera, frame decoration).',
        keywords = 'profile select switch character', combatSafe = false,
        values = function() return Profiles:Names() end,
        get = function() return Profiles:Current() end,
        set = function(_, value)
            local ok, message = Profiles:Select(value)
            if not ok then error(message, 0) end
        end },
    { id = 'profiles.all', type = 'action', label = 'Share with every character', button = 'Use for all characters',
        section = 'This character', order = 20, combatSafe = true,
        desc = 'Every character that has logged in with Squanch-On uses the current profile from its next login.',
        keywords = 'account all characters share',
        confirm = 'Every known character will use this profile.',
        func = function() return run('UseForAll') end },

    { id = 'profiles.name', type = 'text', label = 'Name', section = 'Manage', order = 10, combatSafe = true,
        desc = 'The name used by New, Copy, Rename and Import.',
        keywords = 'name new copy rename', maxLetters = 48, get = getName, set = setName },
    { id = 'profiles.create', type = 'action', label = 'New profile', button = 'New from defaults', section = 'Manage', order = 20,
        desc = 'Creates a profile with the shipped defaults under the name above. It is not switched to.',
        keywords = 'new create defaults', combatSafe = true,
        func = function() return run('Create', ui.name) end },
    { id = 'profiles.copy', type = 'action', label = 'Copy this profile', button = 'Copy to name', section = 'Manage', order = 30,
        desc = 'Copies the profile in use to the name above. It is not switched to.',
        keywords = 'copy duplicate', combatSafe = true,
        func = function() return run('Copy', ui.name) end },
    { id = 'profiles.rename', type = 'action', label = 'Rename this profile', button = 'Rename to name', section = 'Manage', order = 40,
        desc = 'Gives the profile in use the name above. Default keeps its name.',
        keywords = 'rename', combatSafe = true,
        disabled = function() return Profiles:Current() == 'Default' end,
        func = function() return run('Rename', nil, ui.name) end },
    { id = 'profiles.reset', type = 'action', label = 'Reset this profile', button = 'Reset to defaults', section = 'Manage', order = 50,
        desc = 'Returns the profile in use to the shipped defaults. The settings it replaces are kept as "<name> (before reset)".',
        keywords = 'reset defaults restore', combatSafe = false,
        confirm = 'This replaces every setting of the profile in use with the shipped defaults.',
        func = function() return run('Reset') end },
    { id = 'profiles.target', type = 'choice', label = 'Other profile', section = 'Manage', order = 60, combatSafe = true,
        desc = 'The profile Delete removes. The profile in use and Default are not listed.',
        keywords = 'delete remove other', allowEmpty = true, emptyLabel = '(none)',
        values = others,
        get = function()
            if ui.target and (not Profiles:Exists(ui.target) or ui.target == Profiles:Current()) then ui.target = nil end
            return ui.target
        end,
        set = function(_, value) ui.target = value end },
    { id = 'profiles.delete', type = 'action', label = 'Delete other profile', button = 'Delete', section = 'Manage', order = 70,
        desc = 'Deletes the profile chosen above. Characters that used it go back to Default.',
        keywords = 'delete remove', combatSafe = true,
        confirm = 'This deletes the chosen profile. It cannot be undone.',
        disabled = function() return not (ui.target and Profiles:Exists(ui.target)) end,
        func = function()
            local target = ui.target
            ui.target = nil
            return run('Delete', target)
        end },

    { id = 'profiles.export', type = 'action', label = 'Export this profile', button = 'Create string', section = 'Share', order = 10,
        desc = 'Writes the profile in use as one line of text into the box below. Click the box to select all of it, then copy.',
        keywords = 'export share string copy', combatSafe = true,
        func = function()
            settle()
            local text, message = Profiles:Export()
            if not text then return false, message end
            ui.export = text
            return ('Exported %d characters. Click the box, then copy.'):format(#text)
        end },
    { id = 'profiles.exportText', type = 'text', label = 'Exported string', section = 'Share', order = 20, wide = true, combatSafe = true,
        desc = 'The exported profile. Clicking the box selects the whole string.',
        keywords = 'export string',
        get = function() return ui.export or '' end, set = function() end },
    { id = 'profiles.importText', type = 'text', label = 'String to import', section = 'Share', order = 30, wide = true, combatSafe = true,
        desc = 'Paste a Squanch-On profile string here. It is read as data only.',
        keywords = 'import paste string', get = getImport, set = setImport },
    { id = 'profiles.import', type = 'action', label = 'Import as new profile', button = 'Import', section = 'Share', order = 40,
        desc = 'Adds the pasted string as a new profile, under the name in Manage or the name stored in the string. Nothing existing is replaced, and it is not switched to.',
        keywords = 'import paste string', combatSafe = true,
        func = function()
            settle()
            local ok, message = Profiles:Import(ui.import, ui.name)
            if not ok then return false, message end
            ui.import = ''
            return message
        end },
})
