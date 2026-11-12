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
    background = 'Interface\\Buttons\\WHITE8X8',
    border = root .. 'media\\borders\\border-pixel.tga',
}
local function key(value) return value:gsub('/', '\\'):lower() end
-- Bundled, freely licensed fonts and textures for the media names a saved
-- layout uses. Matching is by name fragment so legacy addon paths resolve as well.
-- The Squanch fonts are respaced to the metrics those layouts were built with.
local fonts = root .. 'media\\fonts\\'
local textures = root .. 'media\\textures\\'
local bundled = {
    font = { { 'expressway', fonts .. 'SquanchHighway.ttf' }, { 'homizio', fonts .. 'SquanchRound.ttf' },
        { 'harry', fonts .. 'SquanchBolt.ttf' }, { 'forced', fonts .. 'SquanchSquare.ttf' },
        { 'action man', fonts .. 'SquanchComic.ttf' }, { 'pt sans narrow', defaults.font } },
    statusbar = { { 'tukui', textures .. 'bar-smooth.tga' }, { 'flat', 'Interface\\Buttons\\WHITE8X8' },
        { 'skullflower', textures .. 'bar-smooth.tga' } },
    texture = { { 'glowtex', textures .. 'glow-edge.tga' }, { 'roleicons\\tank', textures .. 'role-tank.tga' },
        { 'roleicons\\healer', textures .. 'role-healer.tga' }, { 'roleicons\\dps', textures .. 'role-dps.tga' } },
}
local resolved = { font = {}, statusbar = {}, texture = {} }
-- Selectable media by display name. The kinds match LibSharedMedia's; the
-- private `texture` kind above is never listed or shared.
local registry = { font = {}, statusbar = {}, border = {}, background = {} }
local shared -- the LibSharedMedia instance already given our media, if any
local function share(lsm, kind, name, entry)
    -- Without a mask LibSharedMedia offers a font to western clients only.
    lsm:Register(kind, name, entry.path, entry.cyrillic and lsm.LOCALE_BIT_western + lsm.LOCALE_BIT_ruRU or nil)
end
local function library()
    local lsm = LibStub and LibStub('LibSharedMedia-3.0', true)
    if lsm and lsm ~= shared then
        shared = lsm
        for kind, entries in pairs(registry) do
            for name, entry in pairs(entries) do share(lsm, kind, name, entry) end
        end
    end
    return lsm
end
local function aliased(kind, lowered)
    for _, pair in ipairs(bundled[kind] or {}) do
        if lowered:find(pair[1], 1, true) then return pair[2] end
    end
end
-- `cyrillic` marks a font that also covers Russian.
function Media:Register(kind, name, path, cyrillic)
    local entries = registry[kind]
    if not entries or type(name) ~= 'string' or name == '' or type(path) ~= 'string' or entries[name] then return false end
    entries[name] = { path = path, cyrillic = kind == 'font' and cyrillic or nil }
    local lsm = library()
    if lsm then share(lsm, kind, name, entries[name]) end
    return true
end
-- Sorted display names: bundled media plus whatever other addons shared. A
-- shared name that a legacy alias would capture is left out, since Resolve
-- would not return that addon's file for it.
function Media:List(kind)
    local names, seen = {}, {}
    for name in pairs(registry[kind] or {}) do names[#names + 1] = name; seen[name] = true end
    local lsm = registry[kind] and library()
    for _, name in ipairs(lsm and lsm:List(kind) or {}) do
        local path = not seen[name] and not aliased(kind, key(name)) and lsm:Fetch(kind, name, true)
        if type(path) == 'string' and not key(path):find('interface\\addons\\elvui', 1, true) then
            names[#names + 1] = name; seen[name] = true
        end
    end
    table.sort(names)
    return names
end
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
    local own = registry[kind] and registry[kind][value]
    if own then return own.path end
    local cache = resolved[kind]
    if cache then
        if cache[value] then return cache[value] end
        local path = aliased(kind, key(value))
        if path then cache[value] = path; return path end
    end
    if kind == 'font' and value == 'PT Sans Narrow' then return defaults.font end
    if value:find('\\', 1, true) or value:find('/', 1, true) then
        if not legacy(value) then return value end
    else
        local lsm = library()
        local path = lsm and lsm:Fetch(kind, value, true)
        if type(path) == 'string' and not legacy(path) then return path end
    end
    self.missing[kind .. ':' .. value] = true
    return fallback
end
function Media:Exact()
    return next(self.missing) == nil
end

for _, font in ipairs({
    { 'Squanch Highway', 'SquanchHighway.ttf' }, { 'Squanch Round', 'SquanchRound.ttf' },
    { 'Squanch Square', 'SquanchSquare.ttf' }, { 'Squanch Bolt', 'SquanchBolt.ttf' },
    { 'Squanch Comic', 'SquanchComic.ttf' },
    { 'PT Sans Narrow Bold', 'ptsansnarrow_bold.ttf', true }, { 'Overpass Bold', 'Overpass-Bold.ttf' },
    { 'Afacad Medium', 'Afacad-Medium.ttf' }, { 'Oxanium Bold', 'Oxanium-Bold.ttf' },
    { 'Almendra Bold', 'Almendra-Bold.ttf' }, { 'Barlow Condensed SemiBold', 'BarlowCondensed-SemiBold.ttf' },
    { 'Saira Condensed SemiBold', 'SairaCondensed-SemiBold.ttf' },
    { 'Archivo Narrow SemiBold', 'ArchivoNarrow-SemiBold.ttf' }, { 'Oswald Medium', 'Oswald-Medium.ttf', true },
    { 'Bebas Neue', 'BebasNeue-Regular.ttf' }, { 'Cinzel Bold', 'Cinzel-Bold.ttf' },
    { 'Metamorphous', 'Metamorphous-Regular.ttf' }, { 'Silkscreen', 'Silkscreen-Regular.ttf' },
    { 'Pixelify Sans', 'PixelifySans-Regular.ttf', true }, { 'Share Tech Mono', 'ShareTechMono-Regular.ttf' },
}) do Media:Register('font', font[1], fonts .. font[2], font[3]) end
Media:Register('statusbar', 'Squanch Flat', defaults.texture)
for _, name in ipairs({ 'Smooth', 'Soft', 'Deep', 'Gloss', 'Glass', 'Bevel', 'Round', 'Groove', 'Lines', 'Stripes',
    'Fade', 'Brushed', 'Underline' }) do
    Media:Register('statusbar', 'Squanch ' .. name, textures .. 'bar-' .. name:lower() .. '.tga')
end
for _, name in ipairs({ 'Pixel', 'Thin Bevel', 'Double', 'Rounded', 'Shadow' }) do
    Media:Register('border', 'Squanch ' .. name, root .. 'media\\borders\\border-' .. name:lower():gsub(' ', '-') .. '.tga')
end
Media:Register('border', 'Squanch Glow', textures .. 'glow-edge.tga')
Media:Register('background', 'Squanch Solid', defaults.background)
