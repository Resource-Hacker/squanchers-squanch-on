-- SPDX-License-Identifier: MIT
-- Nameplate indicator pages: one per unit, with the reaction chosen at the top
-- of the page. Values the module validates are written through
-- module:SetOption, exactly as /tni UNIT REACTION SETTING VALUE does.
local _, ns = ...
local Options = ns.Options
if not Options then return end

local function module() return ns.NameplateIndicators end
local function available() local m = module(); return m and m.profile and true or false end
local function config(ctx)
    local m = module()
    local unit = m and m.profile and ctx and m.profile[ctx.unit]
    return unit and unit[ctx.reaction]
end
local copySource -- session pick for "Copy indicators from"; not saved

Options:Category({ id = 'nameplates', title = 'Nameplates & Target ring', order = 60,
    desc = 'Indicators drawn on nameplates and the ring around the selected target.' })

Options:Add('nameplates', {
    { id = 'nameplates.profile', type = 'choice', label = 'Indicator profile', section = 'Profile', order = 10,
        desc = 'The indicator profile this character uses; indicator profiles are the addon profiles, so this switches the whole addon. Same as /tni profile NAME.',
        keywords = 'profile nameplate indicator select', combatSafe = true,
        hidden = function() return not available() end,
        values = function()
            local names = {}
            for name in pairs(module().db.profiles) do names[#names + 1] = name end
            table.sort(names)
            return names
        end,
        get = function() return module().profileName end,
        set = function(_, value) module():SelectProfile(value) end },
    { id = 'nameplates.reset', type = 'action', label = 'Reset this profile', button = 'Reset indicators', section = 'Profile', order = 20,
        desc = 'Returns every indicator of the current profile to the shipped ring. Same as /tni reset.',
        keywords = 'reset default nameplate indicator', confirm = 'This resets every indicator of the current profile.', combatSafe = true,
        hidden = function() return not available() end,
        func = function() module():Slash('reset'); return 'Indicator profile reset.' end },
    { id = 'nameplates.copySource', type = 'choice', label = 'Copy indicators from', section = 'Profile', order = 22,
        desc = 'Another profile whose indicators the button below copies into the profile in use.',
        keywords = 'copy profile nameplate indicator from', combatSafe = true, allowEmpty = true, emptyLabel = '(none)',
        hidden = function() return not available() end,
        values = function()
            local names = {}
            for name in pairs(module().db.profiles) do
                if name ~= module().profileName then names[#names + 1] = name end
            end
            table.sort(names)
            return names
        end,
        get = function()
            local m = module()
            if copySource and (not m.db.profiles[copySource] or copySource == m.profileName) then copySource = nil end
            return copySource
        end,
        set = function(_, value) copySource = value end },
    { id = 'nameplates.copy', type = 'action', label = 'Replace this profile\'s indicators', button = 'Copy from profile', section = 'Profile', order = 24,
        desc = 'Replaces every indicator of the profile in use with those of the profile chosen above. Same as /tni copy NAME.',
        keywords = 'copy profile nameplate indicator replace', combatSafe = true,
        confirm = 'This replaces every indicator of the current profile.',
        hidden = function() return not available() end,
        disabled = function() return not (copySource and module().db.profiles[copySource]) end,
        func = function()
            local name = copySource
            if not (name and module().db.profiles[name]) then return false, 'Choose a profile to copy from.' end
            module():Slash('copy ' .. name)
            return 'Indicators copied from "' .. name .. '".'
        end },
    { id = 'nameplates.status', type = 'action', label = 'Indicator status', button = 'Print to chat', section = 'Profile', order = 26,
        desc = 'Prints where each indicator is attached right now. Same as /tni status.',
        keywords = 'status debug nameplate indicator', combatSafe = true,
        hidden = function() return not available() end,
        func = function() module():PrintStatus() end },
    { id = 'nameplates.note', type = 'note', label = 'How indicators attach', section = 'Profile', order = 30,
        keywords = 'restriction combat priority visible',
        text = function()
            if C_Secrets and C_Secrets.ShouldUnitComparisonBeSecret then
                return 'This client restricts non-target comparisons in combat; the target-of-target indicator is unavailable.'
            end
            return 'Indicators attach to visible nameplates only; when two apply to the same unit, target wins over focus, soft targets, target of target and mouseover.'
        end },
})

local titles = { target = 'Target', focus = 'Focus', softfriend = 'Soft friend', softenemy = 'Soft enemy',
    targettarget = 'Target of target', mouseover = 'Mouseover' }
local artLabels = { custom = 'Custom path' }

-- A row stored per reaction: read from the profile, written through SetOption.
local function styled(spec)
    local key = spec.key
    spec.get = spec.get or function(ctx) local style = config(ctx); return style and style[key] end
    spec.set = spec.set or function(ctx, value)
        local ok, message = module():SetOption(ctx.unit, ctx.reaction, key, value)
        if not ok then error(message, 0) end
    end
    return spec
end
-- Fields without a validator in the module are written directly and redrawn.
local function direct(ctx, key, value)
    local style = config(ctx)
    if not style then error('Unsupported reaction', 0) end
    style[key] = value
    module():Refresh(true)
end

local template = {
    { key = 'unitEnable', type = 'toggle', label = 'Show for this unit', section = 'Unit', order = 10,
        desc = 'Master switch for this unit, whatever its reaction. Same as /tni UNIT unit enable on.',
        keywords = 'enable unit indicator', default = true,
        get = function(ctx) local m = module(); return m.profile[ctx.unit].enable and true or false end,
        set = function(ctx, value)
            local ok, message = module():SetOption(ctx.unit, 'unit', 'enable', value)
            if not ok then error(message, 0) end
            end },
    { key = 'unsupported', type = 'note', label = 'Unused reaction', section = 'Unit', order = 20,
        text = 'This soft-target indicator does not use the selected reaction.',
        hidden = function(ctx) return config(ctx) ~= nil end },

    styled({ key = 'enable', type = 'toggle', label = 'Show for this reaction', section = 'Artwork', order = 10,
        desc = 'Shows the indicator when the unit has the reaction selected at the top of the page.',
        keywords = 'enable reaction self friendly hostile', default = true,
        get = function(ctx) local style = config(ctx); return style and style.enable and true or false end }),
    styled({ key = 'texture', type = 'choice', label = 'Artwork', section = 'Artwork', order = 20,
        desc = 'The picture drawn on the nameplate. Chevron follows the mouseover dot; Custom path uses the texture named below.',
        keywords = 'texture art ring chevron pointer diamond horde skull custom', default = 'Ring', labels = artLabels,
        values = function(ctx)
            local list, style = {}, config(ctx)
            for index, name in ipairs(module().textureNames) do list[index] = name end
            list[#list + 1] = 'custom'
            local current, known = style and style.texture, false
            for _, name in ipairs(list) do if name == current then known = true end end
            if type(current) == 'string' and not known then list[#list + 1] = current end
            return list
        end }),
    styled({ key = 'textureCustom', type = 'text', label = 'Custom path', section = 'Artwork', order = 30, wide = true,
        desc = 'A game texture path, used when Artwork is set to Custom path.',
        keywords = 'custom texture path file', default = '', maxLetters = 240,
        get = function(ctx) local style = config(ctx); return style and style.textureCustom or '' end,
        disabled = function(ctx) local style = config(ctx); return style ~= nil and style.texture ~= 'custom' end }),
    { key = 'tint', type = 'color', label = 'Tint', section = 'Artwork', order = 40,
        desc = 'Colour multiplied into the artwork. Bundled artwork is red and custom textures are untinted until a tint is chosen.',
        keywords = 'tint colour color',
        get = function(ctx)
            local style = config(ctx)
            if not style then return nil end
            local tint = style.tint
            if type(tint) ~= 'table' then
                local name = style.texture
                local bundled = false
                for _, known in ipairs(module().textureNames) do if known == name then bundled = true end end
                tint = bundled and { 1, 0, 0 } or { 1, 1, 1 }
            end
            return { r = tint[1], g = tint[2], b = tint[3] }
        end,
        set = function(ctx, value) direct(ctx, 'tint', value and { value.r, value.g, value.b } or nil) end },
    styled({ key = 'opacity', type = 'slider', label = 'Opacity', section = 'Artwork', order = 50,
        desc = 'How solid the indicator is drawn.',
        keywords = 'opacity alpha transparency', min = 0, max = 1, step = 0.01, format = '%.0f%%', scale = 100, default = 1 }),
    { key = 'followMouseoverDot', type = 'toggle', label = 'Follow the mouseover dot', section = 'Artwork', order = 60,
        desc = 'The indicator takes its opacity from the reticle mouseover dot, as the Chevron does. Choosing an artwork sets this again.',
        keywords = 'mouseover dot chevron follow', default = false,
        get = function(ctx) local style = config(ctx); return style and style.followMouseoverDot == true or false end,
        set = function(ctx, value) direct(ctx, 'followMouseoverDot', value) end,
        hidden = function(ctx) return ctx.unit ~= 'target' and ctx.unit ~= 'mouseover' end },

    styled({ key = 'width', type = 'number', label = 'Width', section = 'Size and position', order = 10,
        desc = 'Width of the indicator.', keywords = 'size width', min = 1, max = 1000, default = 50 }),
    styled({ key = 'height', type = 'number', label = 'Height', section = 'Size and position', order = 20,
        desc = 'Height of the indicator.', keywords = 'size height', min = 1, max = 1000, default = 50 }),
    styled({ key = 'texturePoint', type = 'choice', label = 'Indicator point', section = 'Size and position', order = 30,
        desc = 'The point of the indicator that is attached to the nameplate.',
        keywords = 'anchor point texture', values = function() return module().points end, default = 'BOTTOM' }),
    styled({ key = 'anchorPoint', type = 'choice', label = 'Nameplate point', section = 'Size and position', order = 40,
        desc = 'The point of the nameplate the indicator is attached to.',
        keywords = 'anchor point nameplate', values = function() return module().points end, default = 'TOP' }),
    styled({ key = 'xOffset', type = 'number', label = 'Offset X', section = 'Size and position', order = 50,
        desc = 'Sideways distance from the nameplate point.', keywords = 'offset horizontal', min = -1000, max = 1000, default = 0 }),
    styled({ key = 'yOffset', type = 'number', label = 'Offset Y', section = 'Size and position', order = 60,
        desc = 'Vertical distance from the nameplate point.', keywords = 'offset vertical', min = -1000, max = 1000, default = 5 }),
    styled({ key = 'frameStrata', type = 'choice', label = 'Layer', section = 'Size and position', order = 70,
        desc = 'Frame strata of the indicator; a higher layer draws over more of the interface.',
        keywords = 'strata layer level', values = function() return module().stratas end, default = 'BACKGROUND' }),
}

for index, unit in ipairs(module() and module().units or {}) do
    local id = 'nameplates.' .. unit
    Options:Category({ id = id, parent = 'nameplates', title = titles[unit] or unit, order = index * 10,
        desc = 'Indicator on the nameplate of your ' .. string.lower(titles[unit] or unit) .. '. Pick the reaction to edit below.',
        context = { unit = unit }, hidden = function() return not available() end,
        contexts = { { key = 'reaction', values = { 'hostile', 'friendly', 'self' }, labels = { 'Hostile', 'Friendly', 'Self' } } } })
    Options:AddTemplate(id, template, { idPrefix = 'indicator.' .. unit .. '.', combatSafe = true,
        disabled = function(option, ctx) return option.key ~= 'unitEnable' and config(ctx) == nil end })
end
