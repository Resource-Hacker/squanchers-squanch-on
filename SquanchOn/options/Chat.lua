-- SPDX-License-Identifier: MIT
-- Chat page: tab row, header icons, toasts and fill of the chat panel
-- (DarkSkin.lua). Every default is the constant the panel shipped with.
local _, ns = ...
local Options, Skin = ns.Options, ns.DarkSkin
if not Options or not Skin then return end

-- A row stored sparsely in ns.db.<area>: a value equal to the shipped default
-- removes the key, so an untouched or reset setting is exactly the default.
local function same(a, b)
    if type(a) == 'number' and type(b) == 'number' then return math.abs(a - b) < 1e-6 end
    if type(a) == 'table' and type(b) == 'table' then return same(a.r, b.r) and same(a.g, b.g) and same(a.b, b.b) end
    return a == b
end
local function row(area, module, key, spec)
    local default = module.chatDefaults[key]
    spec.default = Options.Copy(default)
    spec.get = function()
        local value = module:ChatSetting(key)
        if value == '' then return nil end
        return value
    end
    spec.set = function(_, value)
        local db = ns.db
        if type(db[area]) ~= 'table' then db[area] = {} end
        if type(value) == 'table' then value = { r = value.r, g = value.g, b = value.b } end
        if value == nil or same(value, default) then db[area][key] = nil else db[area][key] = value end
    end
    return spec
end

Options:Category({ id = 'chat', title = 'Chat', order = 80,
    desc = 'Tabs, header icons, timestamps and friend toasts of the chat panel. Move and resize it in the layout editor.' })

local function chat() return Skin:ApplyChat() end
local function option(key, spec)
    spec.id = 'chat.' .. key
    if spec.apply == nil and not spec.requiresReload then spec.apply = chat end
    return row('chat', Skin, key, spec)
end

Options:Add('chat', {
    option('tabFont', { type = 'font', label = 'Tab font', section = 'Tabs', order = 10,
        desc = 'Font of the chat tab labels.', keywords = 'tab font label typeface' }),
    option('tabSize', { type = 'slider', label = 'Tab text size', section = 'Tabs', order = 20,
        desc = 'Size of the chat tab labels.', keywords = 'tab font size label', min = 6, max = 16, step = 1, integer = true, drag = true }),
    option('tabHeight', { type = 'slider', label = 'Tab row height', section = 'Tabs', order = 30,
        desc = 'Height of the tab row and of the icons beside it. The message area takes the rest of the panel.',
        keywords = 'tab row header height strip', min = 16, max = 32, step = 1, integer = true }),

    option('iconStrip', { type = 'toggle', label = 'Menu icons in the chat header', section = 'Header icons', order = 10,
        desc = 'Places the micro menu and Friends at the right end of the tab row. Off leaves them where the game puts them.',
        keywords = 'micro menu icons strip header buttons',
        -- The strip is built once and the action-bar module reparents the micro menu into it; neither is undone live.
        requiresReload = true }),
    option('friends', { type = 'toggle', label = 'Friends button', section = 'Header icons', order = 20,
        desc = 'Shows the Friends button as the last header icon. Hiding it also hides quick-join toasts.',
        keywords = 'friends social quick join button',
        disabled = function() return not Skin:ChatSetting('iconStrip') end }),
    option('voice', { type = 'toggle', label = 'Channel and volume button', section = 'Header icons', order = 30,
        desc = 'Shows the voice channel button, and text to speech when it is on, after the last tab.',
        keywords = 'voice volume channel speaker text to speech tts' }),

    option('fillAlpha', { type = 'number', label = 'Chat fill opacity', section = 'Panel', order = 10,
        desc = 'Opacity of the chat background from 0 to 1. Empty follows the panel fill opacity on the Theme page.',
        keywords = 'background alpha transparency translucent', min = 0, max = 1, allowEmpty = true, emptyLabel = 'theme' }),
    { id = 'chat.timestamps', type = 'toggle', label = 'Timestamps', section = 'Messages', order = 10,
        desc = 'Starts each new chat line with its time as [HH:MM]. This is the game\'s own timestamp setting.',
        keywords = 'time clock timestamp', default = true, combatSafe = true,
        get = function() return C_CVar.GetCVar('showTimestamps') ~= 'none' end,
        set = function(_, value) C_CVar.SetCVar('showTimestamps', value and Skin.chatTimestampFormat or 'none') end },
    option('compactChannels', { type = 'toggle', label = 'Short channel labels', section = 'Messages', order = 20,
        desc = 'Shows numbered channels as [1] instead of [1. General] on new lines.',
        keywords = 'channel prefix number general trade compact', combatSafe = true, apply = false }),

    option('toastTheme', { type = 'toggle', label = 'Friend toasts on the chat panel', section = 'Toasts', order = 10,
        desc = 'Friend-online and quick-join toasts sit on the chat panel\'s top edge with the shared rim and fill.',
        keywords = 'toast friend online battle.net notification popup',
        -- Turning it off must give the anchor, scale and native chrome back to the game, which re-creates them only at load.
        requiresReload = true }),
    option('toastScale', { type = 'slider', label = 'Toast size', section = 'Toasts', order = 20,
        desc = 'Size of those toasts as a share of the game\'s own. A toast never grows wider than the chat panel.',
        keywords = 'toast scale size friend', min = 0.4, max = 1.2, step = 0.01, format = '%.0f%%', scale = 100,
        disabled = function() return not Skin:ChatSetting('toastTheme') end }),
})
