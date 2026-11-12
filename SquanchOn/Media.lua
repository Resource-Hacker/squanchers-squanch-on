-- SPDX-License-Identifier: MIT
-- Media identities are configuration, not an addon dependency. Every name a
-- shipped layout uses resolves to a bundled, freely licensed file.
local addonName, ns = ...
local Media = { missing = {} }
ns.Media = Media
local root = 'Interface\\AddOns\\' .. addonName .. '\\'
local defaults = {
    font = root .. 'media\\fonts\\ptsansnarrow_bold.ttf',
    statusbar = 'Interface\\TargetingFrame\\UI-StatusBar',
    texture = 'Interface\\Buttons\\WHITE8X8',
}
local function key(value) return value:gsub('/', '\\'):lower() end
-- Bundled, freely licensed stand-ins for the media names a saved layout uses.
-- Matching is by name fragment so legacy addon paths resolve as well.
local fonts = root .. 'media\\fonts\\'
local textures = root .. 'media\\textures\\'
local bundled = {
    font = { { 'expressway', fonts .. 'Overpass-Bold.ttf' }, { 'homizio', fonts .. 'Afacad-Medium.ttf' },
        { 'harry', fonts .. 'Almendra-Bold.ttf' }, { 'forced', fonts .. 'Oxanium-Bold.ttf' },
        { 'action man', fonts .. 'Overpass-Bold.ttf' }, { 'pt sans narrow', defaults.font } },
    statusbar = { { 'tukui', textures .. 'bar-smooth.tga' }, { 'flat', 'Interface\\Buttons\\WHITE8X8' },
        { 'skullflower', textures .. 'bar-smooth.tga' } },
    texture = { { 'glowtex', textures .. 'glow-edge.tga' }, { 'roleicons\\tank', textures .. 'role-tank.tga' },
        { 'roleicons\\healer', textures .. 'role-healer.tga' }, { 'roleicons\\dps', textures .. 'role-dps.tga' } },
}
local resolved = { font = {}, statusbar = {}, texture = {} }
local function legacy(value)
    value = key(value)
    return value:find('interface\\addons\\elvui', 1, true) ~= nil
end
function Media:Resolve(kind, value)
    local fallback = defaults[kind] or defaults.texture
    if type(value) ~= 'string' or value == '' then return fallback end
    local private = ns.LocalMedia and ns.LocalMedia[kind]
    local mapped = private and (private[value] or private[key(value)])
    if type(mapped) == 'string' and mapped ~= '' then return mapped end
    local cache = resolved[kind]
    if cache then
        if cache[value] then return cache[value] end
        local lowered = key(value)
        for _, pair in ipairs(bundled[kind]) do
            if lowered:find(pair[1], 1, true) then cache[value] = pair[2]; return pair[2] end
        end
    end
    if kind == 'font' and value == 'PT Sans Narrow' then return defaults.font end
    if value:find('\\', 1, true) or value:find('/', 1, true) then
        if not legacy(value) then return value end
    else
        local lsm = LibStub and LibStub('LibSharedMedia-3.0', true)
        local path = lsm and lsm:Fetch(kind, value, true)
        if type(path) == 'string' and not legacy(path) then return path end
    end
    self.missing[kind .. ':' .. value] = true
    return fallback
end
function Media:Exact()
    return next(self.missing) == nil
end
