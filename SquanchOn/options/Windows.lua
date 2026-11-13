-- SPDX-License-Identifier: MIT
-- Windows & Drawers page: chat drawers (LayoutWindows.lua) and their open
-- motion (DrawerMotion.lua).
-- Every default is the constant the motion shipped with.
local _, ns = ...
local Options, Motion = ns.Options, ns.DrawerMotion
if not Options or not Motion then return end

-- A row stored sparsely in ns.db.<area>: a value equal to the shipped default
-- removes the key, so an untouched or reset setting is exactly the default.
local function same(a, b)
    if type(a) == 'number' and type(b) == 'number' then return math.abs(a - b) < 1e-6 end
    if type(a) == 'table' and type(b) == 'table' then return same(a.r, b.r) and same(a.g, b.g) and same(a.b, b.b) end
    return a == b
end
local function row(area, module, key, spec)
    local default = module.defaults[key]
    spec.default = Options.Copy(default)
    spec.get = function()
        local value = module:Setting(key)
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

Options:Category({ id = 'windows', title = 'Windows & Drawers', order = 100,
    desc = 'How windows above chat, Friends and the quest list open.' })

local function off() return Motion:Setting('style') == 'none' end
local function seconds(key, label, order, desc)
    return row('windows', Motion, key, { id = 'windows.' .. key, type = 'slider', label = label, section = 'Opening motion',
        order = order, desc = desc, keywords = 'animation duration speed time seconds drawer',
        min = 0.05, max = 1, step = 0.05, format = '%.2f s', combatSafe = true, disabled = off })
end

Options:Add('windows', {
    row('windows', ns.LayoutWindows, 'drawers', { id = 'windows.drawers', type = 'toggle', label = 'Open windows as chat drawers', section = 'Drawers', order = 5,
        desc = 'Windows such as the character sheet, spellbook and quest log open above chat at its width. Off leaves them at their own place and size. A window you placed in /sqedit keeps that place either way. Used the next time a window opens.',
        keywords = 'drawer chat window dock attach above position free' }),
    row('windows', ns.LayoutWindows, 'mapDrawer', { id = 'windows.mapDrawer', type = 'toggle', label = 'Open the world map beside the quest list', section = 'Drawers', order = 6,
        desc = 'The world map (M, or the Map plate on the expanded quest list) slides out beside the quest list at the list\'s height, with its quest pins but without its own quest log. The list first grows to at least the top of the character sheet. Collapsing the quest list closes the map. Off leaves the map at its own place and size. Used the next time the map opens.',
        keywords = 'world map quest log drawer attach beside M' }),
    row('windows', Motion, 'style', { id = 'windows.style', type = 'choice', label = 'Opening motion', section = 'Opening motion', order = 10,
        desc = 'Unfold grows the empty window upward from its bottom edge and then fades its content in. None opens at once.',
        keywords = 'animation motion unfold instant drawer open enabled disable',
        values = { 'unfold', 'none' }, labels = { 'Unfold', 'None' }, combatSafe = true }),
    seconds('grow', 'Unfold time', 20, 'How long the empty window takes to grow. Used the next time a drawer opens.'),
    seconds('fade', 'Fade time', 30, 'How long the content takes to fade in afterwards.'),
})
