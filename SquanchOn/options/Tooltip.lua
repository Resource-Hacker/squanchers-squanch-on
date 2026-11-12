-- SPDX-License-Identifier: MIT
-- Tooltip page: the fields TooltipSkin.lua reads from the imported tooltip
-- profile. Each change writes the same key the old window wrote and then
-- calls Tooltip:Refresh(). Imported content switches the skin does not
-- implement stay in the saved table and get no control.
local _, ns = ...
local Options = ns.Options
if not Options then return end

local function settings() return Options.roots.tooltip() end
Options:Category({ id = 'tooltip', title = 'Tooltip', order = 110,
    desc = 'Anchor, text sizes, fonts and health bar of the game tooltip.',
    hidden = function() return not (ns.TooltipSkin and settings()) end })

local outlines = { 'NONE', 'OUTLINE', 'THICKOUTLINE', 'MONOCHROMEOUTLINE', 'SHADOW', 'SHADOWOUTLINE' }
local outlineLabels = { NONE = 'None', OUTLINE = 'Outline', THICKOUTLINE = 'Thick outline',
    MONOCHROMEOUTLINE = 'Monochrome outline', SHADOW = 'Shadow', SHADOWOUTLINE = 'Shadow and outline' }

-- key is a field of the tooltip table, or 'healthBar.<field>'. A missing value
-- reads as the skin's own fallback, which is the row's default.
local function row(spec)
    local group, field = spec.key:match('^(%w+)%.(%w+)$')
    spec.get = function()
        local db = settings()
        local value
        if group then value = type(db[group]) == 'table' and db[group][field] or nil else value = db[spec.key] end
        if value == nil then return spec.default end
        return value
    end
    spec.set = function(_, value)
        local db = settings()
        if group then
            if type(db[group]) ~= 'table' then db[group] = {} end
            db[group][field] = value
        else
            db[spec.key] = value
        end
    end
    spec.id, spec.combatSafe = 'tooltip.' .. spec.key, false
    spec.apply = function() ns.TooltipSkin:Refresh() end
    return spec
end
local function cursor() return settings().cursorAnchor == true end
local function fixed() return not cursor() end

Options:Add('tooltip', {
    row({ key = 'cursorAnchor', type = 'toggle', label = 'Anchor to cursor', section = 'Anchor', order = 10,
        desc = 'Default tooltips follow the cursor instead of the fixed anchor.',
        keywords = 'cursor mouse follow anchor position', default = false }),
    row({ key = 'cursorAnchorType', type = 'choice', label = 'Cursor side', section = 'Anchor', order = 20,
        desc = 'Where a cursor-anchored tooltip sits relative to the cursor.',
        keywords = 'cursor anchor left right', default = 'ANCHOR_CURSOR', disabled = fixed,
        values = { 'ANCHOR_CURSOR', 'ANCHOR_CURSOR_LEFT', 'ANCHOR_CURSOR_RIGHT' }, labels = { 'Above', 'Left', 'Right' } }),
    row({ key = 'cursorAnchorX', type = 'number', label = 'Cursor offset X', section = 'Anchor', order = 30,
        desc = 'Sideways distance from the cursor when the tooltip sits left or right of it.',
        keywords = 'cursor offset horizontal', min = -1000, max = 1000, default = 60, disabled = fixed }),
    row({ key = 'cursorAnchorY', type = 'number', label = 'Cursor offset Y', section = 'Anchor', order = 40,
        desc = 'Vertical distance from the cursor when the tooltip sits left or right of it.',
        keywords = 'cursor offset vertical', min = -1000, max = 1000, default = -128, disabled = fixed }),
    row({ key = 'xOffset', type = 'number', label = 'Fixed anchor offset X', section = 'Anchor', order = 50,
        desc = 'Sideways distance between the fixed anchor and the tooltip.',
        keywords = 'fixed anchor offset horizontal', min = -1000, max = 1000, default = 0, disabled = cursor }),
    row({ key = 'yOffset', type = 'number', label = 'Fixed anchor offset Y', section = 'Anchor', order = 60,
        desc = 'Vertical distance between the fixed anchor and the tooltip.',
        keywords = 'fixed anchor offset vertical', min = -1000, max = 1000, default = 18, disabled = cursor }),
    { id = 'tooltip.moveAnchor', type = 'action', label = 'Fixed anchor position', button = 'Open layout editor', section = 'Anchor', order = 70,
        desc = 'Drag the box named Tooltip anchor on the layout grid. Same as /sqedit.',
        keywords = 'move anchor position layout editor', combatSafe = false,
        hidden = function() return not ns.LayoutEditor end, disabled = cursor,
        func = function()
            if ns.OptionsWindow and ns.OptionsWindow.frame then ns.OptionsWindow.frame:Hide() end
            ns.LayoutEditor:Open()
        end },

    row({ key = 'headerFont', type = 'font', label = 'Heading font', section = 'Text', order = 10,
        desc = 'Font of the first tooltip line.', keywords = 'font header title name', default = 'Bui Homizio' }),
    row({ key = 'headerFontSize', type = 'slider', label = 'Heading size', section = 'Text', order = 20,
        desc = 'Text size of the first tooltip line.', keywords = 'font size header title', min = 6, max = 40, step = 1, default = 12 }),
    row({ key = 'headerFontOutline', type = 'choice', label = 'Heading outline', section = 'Text', order = 30,
        desc = 'Outline drawn around the first tooltip line.', keywords = 'font outline shadow header',
        values = outlines, labels = outlineLabels, default = 'OUTLINE' }),
    row({ key = 'font', type = 'font', label = 'Body font', section = 'Text', order = 40,
        desc = 'Font of every tooltip line after the first.', keywords = 'font body text', default = 'Bui Homizio' }),
    row({ key = 'textFontSize', type = 'slider', label = 'Body size', section = 'Text', order = 50,
        desc = 'Text size of every tooltip line after the first.', keywords = 'font size body text', min = 6, max = 40, step = 1, default = 8 }),
    row({ key = 'smallTextFontSize', type = 'slider', label = 'Comparison size', section = 'Text', order = 60,
        desc = 'Text size inside item comparison tooltips.', keywords = 'font size comparison shopping small', min = 6, max = 40, step = 1, default = 8 }),
    row({ key = 'fontOutline', type = 'choice', label = 'Body outline', section = 'Text', order = 70,
        desc = 'Outline drawn around body and comparison text.', keywords = 'font outline shadow body',
        values = outlines, labels = outlineLabels, default = 'OUTLINE' }),

    row({ key = 'colorAlpha', type = 'slider', label = 'Background opacity', section = 'Look', order = 10,
        desc = 'How solid the tooltip background is drawn.', keywords = 'background opacity alpha transparency',
        min = 0, max = 1, step = 0.01, format = '%.0f%%', scale = 100, default = 0.5 }),
    row({ key = 'itemQuality', type = 'toggle', label = 'Quality-coloured edge', section = 'Look', order = 20,
        desc = 'The thin tooltip edge takes the quality colour of the item shown.', keywords = 'item quality rarity border edge colour color', default = true }),

    row({ key = 'healthBar.statusPosition', type = 'choice', label = 'Health bar', section = 'Health bar', order = 10,
        desc = 'Where the unit health bar is attached to the tooltip.', keywords = 'health bar status position hide',
        values = { 'BOTTOM', 'TOP', 'DISABLED' }, labels = { 'Below', 'Above', 'Hidden' }, default = 'BOTTOM' }),
    row({ key = 'healthBar.height', type = 'slider', label = 'Health bar height', section = 'Health bar', order = 20,
        desc = 'Thickness of the unit health bar.', keywords = 'health bar height thickness', min = 1, max = 40, step = 1, default = 6 }),

    { id = 'tooltip.note', type = 'note', label = 'What the tooltip skin changes', section = 'About', keywords = 'content comparison blizzard imported',
        text = 'The game owns tooltip content and item comparison. Imported content preferences are kept in the saved profile; the content extensions of the imported interface are not available.' },
})
