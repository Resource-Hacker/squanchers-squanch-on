-- SPDX-License-Identifier: MIT
-- Unit-frame pages. "Unit Frames" holds the profile-level settings the
-- renderer reads; each unit has a child page built from one field template.
-- A change writes one key of UF.db (the active profile) and then calls
-- UF:Update_AllFrames(). Rows are
-- shown only where the renderer reports support (UF.optionCapabilities), a
-- field that was never stored stays absent until its row is edited, and
-- unknown imported fields are never touched.
local _, ns = ...
local Options = ns.Options
local Import = ns.UnitFrameImport
if not Options or not Import then return end

local function UF() return ns.UnitFrames end
local function ready() local uf = UF(); return uf and uf.db and uf.state and true or false end
local function update() return UF():Update_AllFrames() end
local function openEditor()
    if ns.OptionsWindow and ns.OptionsWindow.frame then ns.OptionsWindow.frame:Hide() end
    if ns.LayoutEditor:Open() == false then return false, 'Layout editing is available out of combat.' end
end

-- Name typed on the page for "Select by name" and "Copy to new"; not saved.
local profileName = ''
local function switchProfile(create)
    -- The name box keeps focus when a button is clicked; releasing it commits its text first.
    local focus = GetCurrentKeyboardFocus and GetCurrentKeyboardFocus()
    if focus and focus.ClearFocus then focus:ClearFocus() end
    local uf = UF()
    local name = profileName:match('^%s*(.-)%s*$')
    if name == '' or #name > 80 then return false, 'Enter a profile name (1–80 characters).' end
    if create then
        if uf.state.profiles[name] then return false, 'That profile already exists.' end
        uf.state.profiles[name] = Import:Copy(uf.db)
    elseif not uf.state.profiles[name] then
        return false, 'Profile not found.'
    end
    uf.state.profile = name
    update()
    return 'Selected profile: ' .. name
end

local points = { 'CENTER', 'LEFT', 'RIGHT', 'TOP', 'BOTTOM', 'TOPLEFT', 'TOPRIGHT', 'BOTTOMLEFT', 'BOTTOMRIGHT' }
local regions = { 'Frame', 'Health', 'Power', 'InfoPanel' }
local regionLabels = { Frame = 'Frame', Health = 'Health bar', Power = 'Power bar', InfoPanel = 'Info panel' }
local outlines = { 'NONE', 'OUTLINE', 'THICKOUTLINE', 'MONOCHROMEOUTLINE', 'SHADOW', 'SHADOWOUTLINE' }
local outlineLabels = { NONE = 'None', OUTLINE = 'Outline', THICKOUTLINE = 'Thick outline',
    MONOCHROMEOUTLINE = 'Monochrome outline', SHADOW = 'Shadow', SHADOWOUTLINE = 'Shadow and outline' }

-- Profile level ---------------------------------------------------------------
Options:Category({ id = 'unitframes', title = 'Unit Frames', order = 40,
    desc = 'Settings shared by every unit frame. Each frame has its own page below.',
    hidden = function() return not ready() end })

local function shared(spec)
    spec.root, spec.combatSafe = 'uf', false
    if spec.apply == nil then spec.apply = update end
    return spec
end
local function colorMode(key, label, order, desc)
    return shared({ id = 'uf.colors.' .. key, type = 'toggle', label = label, section = 'Bar colours', order = order,
        desc = desc, keywords = 'colour color class reaction bar', path = 'colors.' .. key })
end

Options:Add('unitframes', {
    { id = 'uf.profile', type = 'choice', label = 'Unit-frame profile', section = 'Profile', order = 10,
        desc = 'The stored unit-frame profile in use. The rows below select a profile by its name or copy this one to a new name.',
        keywords = 'profile select switch', combatSafe = false,
        values = function()
            local names = {}
            for name in pairs(UF().state.profiles) do names[#names + 1] = name end
            table.sort(names)
            return names
        end,
        get = function() return UF().state.profile end,
        set = function(_, value)
            local uf = UF()
            if not uf.state.profiles[value] then error('Profile not found.', 0) end
            uf.state.profile = value
        end,
        apply = update },
    { id = 'uf.profileName', type = 'text', label = 'Profile name', section = 'Profile', order = 12, combatSafe = true,
        desc = 'The name used by Select by name and Copy to new.', keywords = 'profile name new copy select', maxLetters = 80,
        get = function() return profileName end, set = function(_, value) profileName = value or '' end },
    { id = 'uf.profileSelect', type = 'action', label = 'Select by name', button = 'Select', section = 'Profile', order = 14,
        desc = 'Switches to the stored unit-frame profile with the name above.',
        keywords = 'profile select switch name', combatSafe = false, func = function() return switchProfile(false) end },
    { id = 'uf.profileCopy', type = 'action', label = 'Copy this profile', button = 'Copy to new', section = 'Profile', order = 16,
        desc = 'Copies the unit-frame profile in use to the name above and switches to the copy.',
        keywords = 'profile copy new duplicate create', combatSafe = false, func = function() return switchProfile(true) end },
    { id = 'uf.layout', type = 'action', label = 'Move and resize frames', button = 'Open layout editor', section = 'Profile', order = 20,
        desc = 'Drag unit frames and their cast bars on the layout grid. Same as /sqedit.',
        keywords = 'move resize position layout editor', combatSafe = false,
        hidden = function() return not ns.LayoutEditor end, func = openEditor },
    { id = 'uf.note', type = 'note', label = 'Supported settings', section = 'Profile', order = 30, keywords = 'imported supported',
        text = 'Only settings the renderer supports are shown; other imported settings are kept unchanged.' },

    shared({ id = 'uf.font', type = 'font', label = 'Font', section = 'Text', order = 10,
        desc = 'Font of unit-frame text that does not name its own font.', keywords = 'font typeface text', path = 'font' }),
    shared({ id = 'uf.fontSize', type = 'slider', label = 'Font size', section = 'Text', order = 20,
        desc = 'Size of unit-frame text that does not set its own size.', keywords = 'font size text',
        path = 'fontSize', min = 5, max = 40, step = 1, default = 11 }),
    shared({ id = 'uf.fontOutline', type = 'choice', label = 'Font outline', section = 'Text', order = 30,
        desc = 'Outline of unit-frame text that does not set its own outline.', keywords = 'font outline shadow',
        path = 'fontOutline', values = outlines, labels = outlineLabels, default = 'OUTLINE' }),

    shared({ id = 'uf.statusbar', type = 'statusbar', label = 'Bar texture', section = 'Bars', order = 10,
        desc = 'Texture of health, power and cast bars.', keywords = 'statusbar texture bar', path = 'statusbar' }),
    shared({ id = 'uf.multiplier', type = 'slider', label = 'Bar background darkness', section = 'Bars', order = 20,
        desc = 'Brightness of the empty part of a bar as a share of its fill colour.', keywords = 'background backdrop multiplier dark',
        path = 'multiplier', min = 0, max = 1, step = 0.01, format = '%.0f%%', scale = 100, default = 0.35 }),
    shared({ id = 'uf.thinBorders', type = 'toggle', label = 'Thin borders', section = 'Bars', order = 30,
        desc = 'One-pixel frame borders instead of two pixels with a spacing line.', keywords = 'border thin pixel',
        path = 'thinBorders', default = true, requiresReload = true }),
    shared({ id = 'uf.colors.transparentHealth', type = 'toggle', label = 'Transparent health bars', section = 'Bars', order = 40,
        desc = 'Health bars are drawn as a faint fill over a tinted background.', keywords = 'transparent health',
        path = 'colors.transparentHealth' }),
    shared({ id = 'uf.colors.transparentPower', type = 'toggle', label = 'Transparent power bars', section = 'Bars', order = 50,
        desc = 'Power bars are drawn as a faint fill over a tinted background.', keywords = 'transparent power',
        path = 'colors.transparentPower' }),
    shared({ id = 'uf.colors.transparentCastbar', type = 'toggle', label = 'Transparent cast bars', section = 'Bars', order = 60,
        desc = 'Cast bars are drawn as a faint fill over a tinted background.', keywords = 'transparent cast castbar',
        path = 'colors.transparentCastbar' }),

    colorMode('healthselection', 'Health by selection colour', 10, "Health bars take the game's selection colour of the unit; this wins over the modes below."),
    colorMode('healthclass', 'Health by class', 20, 'Health bars take the class colour for players and the reaction colour for other units.'),
    colorMode('forcehealthreaction', 'Reaction colour for players', 30, 'With health by class, players are coloured by reaction instead of class.'),
    colorMode('colorhealthbyvalue', 'Health by remaining value', 40, 'Health bars shift colour as health drops, when neither mode above is on.'),
    colorMode('powerclass', 'Power by class', 50, 'Power bars take the class or reaction colour instead of the power-type colour.'),
    colorMode('powerselection', 'Power by selection colour', 60, "Power bars take the game's selection colour of the unit."),

    shared({ id = 'uf.targetOnMouseDown', type = 'toggle', label = 'Target on mouse down', section = 'Clicks', order = 10,
        desc = 'Clicking a frame targets on the press instead of on the release.', keywords = 'click target press release',
        path = 'targetOnMouseDown', default = true }),
})

-- Per unit --------------------------------------------------------------------
-- { section, label, key, type, min, max | choices, description }
-- 'slider' and 'number' both accept a typed value.
local rows = {
    { 'Frame', 'Enabled', 'enable', 'toggle', nil, nil, 'Shows this frame.' },
    { 'Frame', 'Width', 'width', 'number', 5, 1500, 'Width of the frame.' },
    { 'Frame', 'Height', 'height', 'number', 1, 1000, 'Height of the frame.' },
    { 'Frame', 'Orientation', 'orientation', 'choice', { 'LEFT', 'MIDDLE', 'RIGHT' }, nil, 'Side of the frame the portrait sits on.' },

    { 'Portrait', 'Enabled', 'portrait.enable', 'toggle', nil, nil, 'Shows a portrait of the unit.' },
    { 'Portrait', 'Style', 'portrait.style', 'choice', { '3D', '2D', 'Class' }, nil, 'A live model, a flat picture or the class icon.' },
    { 'Portrait', 'Width', 'portrait.width', 'number', 1, 500, 'Width of the portrait beside the bars.' },
    { 'Portrait', 'Rotation', 'portrait.rotation', 'slider', 0, 360, 'Turns the 3D model, in degrees.' },
    { 'Portrait', 'Camera distance', 'portrait.camDistanceScale', 'number', .01, 20, 'Distance of the camera from the 3D model; larger is farther away.' },
    { 'Portrait', 'Model offset X', 'portrait.xOffset', 'slider', -20, 20, 'Moves the 3D model sideways inside the portrait.', .1 },
    { 'Portrait', 'Model offset Y', 'portrait.yOffset', 'slider', -20, 20, 'Moves the 3D model up or down inside the portrait.', .1 },
    { 'Portrait', 'Overlay on health', 'portrait.overlay', 'toggle', nil, nil, 'Draws the portrait across the health bar instead of beside it.' },
    { 'Portrait', 'Paused', 'portrait.paused', 'toggle', nil, nil, 'Freezes the 3D model animation.' },

    { 'Health', 'Reverse fill', 'health.reverseFill', 'toggle', nil, nil, 'The health bar empties from the other side.' },

    { 'Power', 'Enabled', 'power.enable', 'toggle', nil, nil, 'Shows the power bar.' },
    { 'Power', 'Height', 'power.height', 'number', 1, 300, 'Height of the power bar.' },
    { 'Power', 'Width mode', 'power.width', 'choice', { 'fill', 'spaced', 'inset', 'offset' }, nil, 'How the power bar is fitted to the frame.' },
    { 'Power', 'Layout offset', 'power.offset', 'number', 0, 500, 'Distance used by the offset width mode.' },
    { 'Power', 'Reverse fill', 'power.reverseFill', 'toggle', nil, nil, 'The power bar empties from the other side.' },
    { 'Power', 'Detach from frame', 'power.detachFromFrame', 'toggle', nil, nil, 'The power bar becomes a separate bar with its own position.' },
    { 'Power', 'Detached width', 'power.detachedWidth', 'number', 3, 1500, 'Width of the power bar while detached.' },

    { 'Cast bar', 'Enabled', 'castbar.enable', 'toggle', nil, nil, 'Shows a cast bar for this unit.' },
    { 'Cast bar', 'Width', 'castbar.width', 'number', 5, 1500, 'Width of the cast bar when it does not overlay the frame.' },
    { 'Cast bar', 'Height', 'castbar.height', 'number', 1, 300, 'Height of the cast bar when it does not overlay the frame.' },
    { 'Cast bar', 'Overlay region', 'castbar.overlayOnFrame', 'choice', { 'None', 'Power', 'Health' }, nil, 'Draws the cast bar over the power or health bar instead of on its own.' },
    { 'Cast bar', 'Icon', 'castbar.icon', 'toggle', nil, nil, 'Shows the spell icon beside the cast bar.' },
    { 'Cast bar', 'Latency indicator', 'castbar.latency', 'toggle', nil, nil, 'Marks the part of the cast covered by network latency.' },
    { 'Cast bar', 'Hide name', 'castbar.hideName', 'toggle', nil, nil, 'Leaves out the spell name.' },
    { 'Cast bar', 'Hide time', 'castbar.hideTime', 'toggle', nil, nil, 'Leaves out the remaining cast time.' },

    { 'Class resources', 'Enabled', 'classbar.enable', 'toggle', nil, nil, 'Shows combo points and other class resources.' },
    { 'Class resources', 'Height', 'classbar.height', 'number', 1, 300, 'Height of the class resource bar.' },
    { 'Class resources', 'Spacing', 'classbar.spacing', 'slider', 0, 50, 'Gap between class resource segments.' },

    { 'Fading', 'Enabled', 'fader.enable', 'toggle', nil, nil, 'Fades the frame unless one of the reveal conditions holds.' },
    { 'Fading', 'Fade out-of-range units', 'fader.range', 'toggle', nil, nil, 'Fades units that are out of range.' },
    { 'Fading', 'Minimum opacity', 'fader.minAlpha', 'slider', 0, 1, 'Opacity of a faded frame.', .01 },
    { 'Fading', 'Maximum opacity', 'fader.maxAlpha', 'slider', 0, 1, 'Opacity of a revealed frame.', .01 },
    { 'Fading', 'Transition duration', 'fader.smooth', 'slider', 0, 10, 'Seconds a fade takes.', .05 },
    { 'Fading', 'Delay', 'fader.delay', 'slider', 0, 30, 'Seconds before a frame starts to fade.', .1 },
    { 'Fading', 'Reveal in combat', 'fader.combat', 'toggle', nil, nil, 'Shows the frame while in combat.' },
    { 'Fading', 'Reveal with player target', 'fader.playertarget', 'toggle', nil, nil, 'Shows the frame while you have a target.' },
    { 'Fading', 'Reveal with unit target', 'fader.unittarget', 'toggle', nil, nil, 'Shows the frame while its unit has a target.' },
    { 'Fading', 'Reveal on hover', 'fader.hover', 'toggle', nil, nil, 'Shows the frame under the mouse.' },
    { 'Fading', 'Reveal while casting', 'fader.casting', 'toggle', nil, nil, 'Shows the frame while its unit casts.' },
    { 'Fading', 'Reveal on reduced health', 'fader.health', 'toggle', nil, nil, 'Shows the frame while health is below full.' },
    { 'Fading', 'Reveal on reduced power', 'fader.power', 'toggle', nil, nil, 'Shows the frame while power is below full.' },
    { 'Fading', 'Reveal when focused', 'fader.focus', 'toggle', nil, nil, 'Shows the frame while a focus exists.' },
    { 'Fading', 'Reveal in vehicle', 'fader.vehicle', 'toggle', nil, nil, 'Shows the frame while in a vehicle.' },

    { 'Group layout', 'Horizontal spacing', 'horizontalSpacing', 'slider', 0, 200, 'Gap between members side by side.' },
    { 'Group layout', 'Vertical spacing', 'verticalSpacing', 'slider', 0, 200, 'Gap between members above one another.' },
    { 'Group layout', 'Spacing between groups', 'groupSpacing', 'slider', 0, 200, 'Gap between raid groups.' },
    { 'Group layout', 'Groups per row or column', 'groupsPerRowCol', 'slider', 1, 8, 'Number of groups before a new row or column starts.' },
    { 'Group layout', 'Number of groups', 'numGroups', 'slider', 1, 8, 'How many raid groups are shown.' },
    { 'Group layout', 'Growth', 'growthDirection', 'choice', { 'DOWN', 'UP', 'LEFT', 'RIGHT', 'RIGHT_DOWN', 'RIGHT_UP', 'LEFT_DOWN', 'LEFT_UP' }, nil, 'Direction members and groups are added in.' },
    { 'Group layout', 'Visibility condition', 'visibility', 'text', nil, nil, 'Macro condition that shows or hides the group, for example [@raid6,exists] hide; show.' },
    { 'Group layout', 'Group by', 'groupBy', 'choice', { 'GROUP', 'CLASS', 'ROLE', 'ASSIGNEDROLE' }, nil, 'What members are grouped by.' },
    { 'Group layout', 'Sort method', 'sortMethod', 'choice', { 'INDEX', 'NAME' }, nil, 'Members are ordered by raid index or by name.' },
    { 'Group layout', 'Sort direction', 'sortDir', 'choice', { 'ASC', 'DESC' }, nil, 'Ascending or descending member order.' },
    { 'Group layout', 'Raid-wide sorting', 'raidWideSorting', 'toggle', nil, nil, 'Sorts the whole raid as one list instead of group by group.' },
}
for _, kind in ipairs({ 'name', 'health', 'power' }) do
    local section = kind:sub(1, 1):upper() .. kind:sub(2) .. ' text'
    for _, spec in ipairs({
        { 'Text format', 'text_format', 'text', nil, nil, 'Tag expression that produces the text, for example [name] or [health:current].' },
        { 'Font', 'font', 'font', nil, nil, 'Font of this text; empty uses the unit-frame font.' },
        { 'Size', 'size', 'number', 5, 80, 'Size of this text; empty uses the unit-frame font size.' },
        { 'Outline', 'fontOutline', 'choice', outlines, nil, 'Outline of this text.' },
        { 'Attach to', 'attachTextTo', 'choice', regions, nil, 'Part of the frame the text is placed on.' },
        { 'Anchor point', 'position', 'choice', points, nil, 'Point of that part the text is anchored at.' },
        { 'Offset X', 'xOffset', 'number', -1000, 1000, 'Sideways distance from the anchor point.' },
        { 'Offset Y', 'yOffset', 'number', -1000, 1000, 'Vertical distance from the anchor point.' } }) do
        rows[#rows + 1] = { section, spec[1], kind .. '.' .. spec[2], spec[3], spec[4], spec[5], spec[6] }
    end
end
for _, kind in ipairs({ 'buffs', 'debuffs' }) do
    local section = kind:sub(1, 1):upper() .. kind:sub(2)
    for _, spec in ipairs({
        { 'Enabled', 'enable', 'toggle', nil, nil, 'Shows the row of ' .. kind .. ' on this frame.' },
        { 'Per row', 'perrow', 'slider', 1, 40, 'Icons in one row.' },
        { 'Rows', 'numrows', 'slider', 1, 8, 'Number of rows.' },
        { 'Icon size', 'sizeOverride', 'slider', 0, 150, 'Icon size; 0 fits the icons to the frame width.' } }) do
        rows[#rows + 1] = { section, spec[1], kind .. '.' .. spec[2], spec[3], spec[4], spec[5], spec[6] }
    end
end

local labelMaps = { [outlines] = outlineLabels, [regions] = regionLabels }
local inherits = { font = true, size = true } -- text font and size may be empty: inherit
local reloads = { raidWideSorting = true }    -- the renderer refuses this change without a reload
local wide = { text_format = true, visibility = true }
local function fadeOrder(key)
    local other = key == 'fader.minAlpha' and 'maxAlpha' or 'minAlpha'
    return function(value, ctx)
        local unit = UF().db.units[ctx.unit]
        local peer = unit and unit.fader and unit.fader[other]
        if type(peer) ~= 'number' then return true end
        if (other == 'maxAlpha' and value > peer) or (other == 'minAlpha' and value < peer) then
            return false, 'Fade minimum opacity must not exceed maximum opacity.'
        end
        return true
    end
end

local template = {}
for index, spec in ipairs(rows) do
    local key, kind, leaf = spec[3], spec[4], spec[3]:match('([^.]+)$')
    local field = { key = key, type = kind, label = spec[2], section = spec[1], order = index, desc = spec[7] }
    if kind == 'choice' then
        field.values, field.labels = spec[5], labelMaps[spec[5]]
    elseif kind == 'number' or kind == 'slider' then
        field.min, field.max, field.step = spec[5], spec[6], spec[8] or 1
        if kind == 'slider' and field.max == 1 then field.format, field.scale = '%.0f%%', 100 end
    elseif kind == 'text' then
        field.wide, field.maxLetters = wide[leaf], 400
    end
    if spec[1]:match(' text$') and inherits[leaf] then field.allowEmpty, field.emptyLabel = true, '(unit-frame default)' end
    if reloads[key] then field.requiresReload = true end
    if key == 'fader.minAlpha' or key == 'fader.maxAlpha' then field.validate = fadeOrder(key) end
    template[#template + 1] = field
end

-- Custom texts: the names are profile data, so one set of rows edits the text
-- picked in the first row. The pick is page state and is not saved. `apply =
-- false` keeps a row from inheriting the template's frame update.
local picked = {}
local function customNames(ctx)
    local names = {}
    local unit = ready() and UF().db.units[ctx.unit]
    for name, config in pairs(unit and unit.customTexts or {}) do
        if type(config) == 'table' then names[#names + 1] = name end
    end
    table.sort(names, function(a, b) return tostring(a) < tostring(b) end)
    return names
end
local function customConfig(ctx)
    local names = customNames(ctx)
    local name = picked[ctx.unit]
    local known = false
    for _, candidate in ipairs(names) do if candidate == name then known = true end end
    if not known then name = names[1] end
    return name and UF().db.units[ctx.unit].customTexts[name], name
end
local function customSupported(key)
    local capabilities = UF() and UF().optionCapabilities or {}
    return capabilities['customTexts.*'] == true or capabilities['customTexts.' .. key] == true
end
local function custom(label, key, kind, a, b, desc)
    local field = { key = 'customTexts.' .. key, customKey = key, type = kind, label = label, section = 'Custom texts', desc = desc,
        get = function(ctx) local config = customConfig(ctx); return config and config[key] end,
        set = function(ctx, value)
            local config = customConfig(ctx)
            if not config then error('This frame has no custom text.', 0) end
            config[key] = value
        end }
    if kind == 'choice' then field.values, field.labels = a, labelMaps[a]
    elseif kind == 'number' then field.min, field.max = a, b
    elseif kind == 'text' then field.wide, field.maxLetters = true, 400 end
    if key == 'font' then field.allowEmpty, field.emptyLabel = true, '(unit-frame default)' end
    return field
end
template[#template + 1] = { key = 'customTexts', type = 'choice', label = 'Custom text', section = 'Custom texts',
    desc = 'Which stored custom text the rows below edit.', keywords = 'custom text tag pick select',
    combatSafe = true, apply = false, values = customNames,
    get = function(ctx) return select(2, customConfig(ctx)) end,
    set = function(ctx, value)
        -- Queued edits and undo entries name the unit, not the text they were made on.
        if Options:Pending() > 0 then error('Wait until the queued changes have been applied.', 0) end
        Options:ClearJournal()
        picked[ctx.unit] = value
    end }
for _, field in ipairs({
    custom('Enabled', 'enable', 'toggle', nil, nil, 'Shows this custom text.'),
    custom('Text format', 'text_format', 'text', nil, nil, 'Tag expression that produces the text.'),
    custom('Font', 'font', 'font', nil, nil, 'Font of this text; empty uses the unit-frame font.'),
    custom('Size', 'size', 'number', 5, 100, 'Size of this text.'),
    custom('Outline', 'fontOutline', 'choice', outlines, nil, 'Outline of this text.'),
    custom('Attach to', 'attachTextTo', 'choice', regions, nil, 'Part of the frame the text is placed on.'),
    custom('Alignment', 'justifyH', 'choice', { 'CENTER', 'LEFT', 'RIGHT' }, nil, 'Side of that part the text is aligned to.'),
    custom('Offset X', 'xOffset', 'number', -1000, 1000, 'Sideways distance from its aligned position.'),
    custom('Offset Y', 'yOffset', 'number', -1000, 1000, 'Vertical distance from its aligned position.') }) do
    template[#template + 1] = field
end
for index, field in ipairs(template) do field.order = index end
template[#template + 1] = { key = 'layout', type = 'action', label = 'Move and resize', button = 'Open layout editor', section = 'Frame',
    order = 0, desc = 'Drag this frame on the layout grid. Same as /sqedit.', keywords = 'move resize position layout editor',
    apply = false, func = openEditor }

local titles = { player = 'Player', target = 'Target', pet = 'Pet', targettarget = 'Target of target', pettarget = 'Pet target',
    targettargettarget = 'Target of target of target', focus = 'Focus', focustarget = 'Focus target', party = 'Party',
    raid1 = 'Raid 1', raid2 = 'Raid 2', raid3 = 'Raid 3', raidpet = 'Raid pets', tank = 'Tanks', assist = 'Assists',
    boss = 'Boss', arena = 'Arena' }
local function lookup(node, key)
    for part in key:gmatch('[^.]+') do
        if type(node) ~= 'table' then return nil end
        node = node[part]
    end
    return node
end
local function hidden(option, ctx)
    if option.key == 'layout' then return not ns.LayoutEditor end
    local uf = UF()
    if option.customKey or option.key == 'customTexts' then
        return not ready() or #customNames(ctx) == 0 or (option.customKey ~= nil and not customSupported(option.customKey))
    end
    if option.key == 'raidWideSorting' and not ctx.unit:match('^raid%d$') then return true end
    return not (uf and uf.optionCapabilities and uf.optionCapabilities[option.key] == true)
end

for index, unit in ipairs(Import.units) do
    local id, prefix = 'unitframes.' .. unit, 'uf.' .. unit .. '.'
    Options:Category({ id = id, parent = 'unitframes', title = titles[unit] or unit, order = index, context = { unit = unit },
        desc = 'The ' .. string.lower(titles[unit] or unit) .. ' frame. Only settings the renderer supports are shown.',
        hidden = function() return not ready() end })
    Options:AddTemplate(id, template, { idPrefix = prefix, root = 'unit', combatSafe = false, apply = update, hidden = hidden })
    -- Reset targets: the built-in layout of this unit, where it defines the field.
    local defaults = Import:DefaultUnit(unit)
    for _, field in ipairs(template) do
        if not field.customKey and field.key ~= 'customTexts' and field.type ~= 'action' then
            Options.byId[prefix .. field.key].default = lookup(defaults, field.key)
        end
    end
end
