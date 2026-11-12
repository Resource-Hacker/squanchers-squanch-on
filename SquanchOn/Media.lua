-- SPDX-License-Identifier: MIT
-- Media identities are configuration, not an addon dependency. Exact personal
-- media can be supplied in a private local assembly; it never enters releases.
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
