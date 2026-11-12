-- SPDX-License-Identifier: MIT
-- Appearance pages: the shared theme (DarkSkin.lua) and native text sizes
-- (NativeText.lua). Every default is the constant those modules shipped with.
local _, ns = ...
local Options, Skin, Text = ns.Options, ns.DarkSkin, ns.NativeText
if not Options or not Skin or not Text then return end

-- A row stored sparsely in ns.db.<area>: a value equal to the shipped default
-- removes the key, so an untouched or reset setting is exactly the default.
local function same(a, b)
    if type(a) == 'number' and type(b) == 'number' then return math.abs(a - b) < 1e-6 end
    if type(a) == 'table' and type(b) == 'table' then return same(a.r, b.r) and same(a.g, b.g) and same(a.b, b.b) end
    return a == b
end
local function row(area, module, key, spec)
    local default = (module.themeDefaults or module.defaults)[key]
    if default ~= '' then spec.default = Options.Copy(default) end
    spec.get = function()
        local value = (module.Theme or module.Setting)(module, key)
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

Options:Category({ id = 'appearance', title = 'Appearance', order = 120,
    desc = 'The shared look of every Squanch-On panel, and the text sizes of game windows.' })
Options:Category({ id = 'appearance.theme', parent = 'appearance', title = 'Theme', order = 10,
    desc = 'Rim, fill and text colours shared by chat, the minimap, action bars, unit frames, windows, menus and tooltips.' })
Options:Category({ id = 'appearance.text', parent = 'appearance', title = 'Text sizes', order = 20,
    desc = 'Sizes and fonts of text in game windows, menus and the quest list. Unit frames, nameplates and chat have their own.' })

local function theme() Skin:ApplyTheme() end
local function percent(spec)
    spec.type, spec.step, spec.format, spec.scale, spec.drag = 'slider', 0.01, '%.0f%%', 100, true
    return spec
end

Options:Add('appearance.theme', {
    row('theme', Skin, 'rim', { id = 'theme.rim', type = 'color', label = 'Rim colour', section = 'Rims', order = 10,
        desc = 'Colour of the outer rim on every panel, slot, window and tooltip, and of tinted arrows and glyphs.',
        keywords = 'border gold frame edge outline tint', apply = theme }),
    row('theme', Skin, 'rimAlpha', percent({ id = 'theme.rimAlpha', label = 'Rim opacity', section = 'Rims', order = 20,
        desc = 'Resting opacity of the outer rims. Bars and frames that fade still fade from this level.',
        keywords = 'border alpha transparency', min = 0, max = 1, apply = theme })),
    row('theme', Skin, 'inner', { id = 'theme.inner', type = 'color', label = 'Inner outline colour', section = 'Rims', order = 30,
        desc = 'Colour of the thin inner outlines on unit frames, icons and check boxes. Some follow at their next update.',
        keywords = 'border inner outline icon unit frame', apply = theme }),

    row('theme', Skin, 'fill', { id = 'theme.fill', type = 'color', label = 'Panel fill colour', section = 'Panels', order = 10,
        desc = 'Background colour behind chat, the quest list, windows, menus and bag and action slots.',
        keywords = 'background grey panel body', apply = theme }),
    row('theme', Skin, 'fillAlpha', percent({ id = 'theme.fillAlpha', label = 'Panel fill opacity', section = 'Panels', order = 20,
        desc = 'How solid the panel background is. Chat can use its own value on the Chat page.',
        keywords = 'background alpha transparency translucent', min = 0, max = 1, apply = theme })),
    row('theme', Skin, 'buttonBrightness', percent({ id = 'theme.buttonBrightness', label = 'Button face brightness', section = 'Panels', order = 30,
        desc = 'Brightness of the charcoal gradient on raised buttons, title plates and chat tabs.',
        keywords = 'button gradient raised plate header dark light', min = 0.5, max = 2, step = 0.05, apply = theme })),

    row('theme', Skin, 'headerText', { id = 'theme.headerText', type = 'color', label = 'Heading text colour', section = 'Text', order = 10,
        desc = 'Colour of gold labels such as unselected chat tabs.',
        keywords = 'title header gold label font', apply = theme }),
    row('theme', Skin, 'bodyText', { id = 'theme.bodyText', type = 'color', label = 'Body text colour', section = 'Text', order = 20,
        desc = 'Colour of ordinary text in the game settings lists and in this window.',
        keywords = 'body font white label', apply = theme }),
})

local function text()
    Text:Apply()
    -- Quest rows are measured by the game after their font is set.
    if Skin.started and not InCombatLockdown() then Skin:FitTracker() end
end
local function size(key, label, order, min, max, desc, keywords)
    return row('text', Text, key, { id = 'text.' .. key, type = 'slider', label = label, section = 'Sizes', order = order,
        desc = desc, keywords = keywords, min = min, max = max, step = 0.5, format = '%.1f', drag = true, apply = text })
end
local function family(key, label, order, desc)
    return row('text', Text, key, { id = 'text.' .. key, type = 'font', label = label, section = 'Fonts', order = order,
        desc = desc, keywords = 'font family typeface face', allowEmpty = true, emptyLabel = 'Game fonts', apply = text })
end

Options:Add('appearance.text', {
    size('body', 'Body size', 10, 6, 14, 'Size of ordinary text in game windows, menus and tracker lines.', 'font size small text'),
    size('header', 'Heading size', 20, 8, 18, 'Size of titles and headings in ordinary windows and menus.', 'font size title header'),
    size('compactHeader', 'Heading size in drawers', 30, 8, 18,
        'Size of headings on the character sheet, in windows opened above chat and in the quest list header.',
        'font size title header character drawer'),
    size('questHeader', 'Quest title size', 40, 6, 14, 'Size of quest names in the quest list.', 'font size quest tracker objective title'),
    size('questBody', 'Quest objective size', 50, 6, 14, 'Size of quest objectives in the quest list.', 'font size quest tracker objective'),
    row('text', Text, 'questBrightness', { id = 'text.questBrightness', type = 'slider', label = 'Quest objective brightness',
        section = 'Sizes', order = 60, desc = "Brightness that replaces the game's grey for unfinished quest objectives.",
        keywords = 'quest tracker grey gray colour color', min = 0.6, max = 1, step = 0.01, format = '%.0f%%', scale = 100,
        drag = true, apply = text }),
    family('bodyFont', 'Body font', 10, 'Font of ordinary window text. Game fonts keeps each text in its own font.'),
    family('headerFont', 'Heading font', 20, 'Font of titles and headings. Game fonts keeps each heading in its own font.'),
})
