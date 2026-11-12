-- SPDX-License-Identifier: MIT
-- Windows & Drawers page: the open motion of drawers (DrawerMotion.lua).
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
    row('windows', Motion, 'style', { id = 'windows.style', type = 'choice', label = 'Opening motion', section = 'Opening motion', order = 10,
        desc = 'Unfold grows the empty window upward from its bottom edge and then fades its content in. None opens at once.',
        keywords = 'animation motion unfold instant drawer open enabled disable',
        values = { 'unfold', 'none' }, labels = { 'Unfold', 'None' }, combatSafe = true }),
    seconds('grow', 'Unfold time', 20, 'How long the empty window takes to grow. Used the next time a drawer opens.'),
    seconds('fade', 'Fade time', 30, 'How long the content takes to fade in afterwards.'),
})
