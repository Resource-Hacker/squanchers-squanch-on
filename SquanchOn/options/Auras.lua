-- SPDX-License-Identifier: MIT
-- Auras & Buffs pages: the player's buff and debuff bars, the rows on the unit
-- frames and the look of one icon. Values live in SquanchOnDB.auras; the
-- defaults (UnitFrames.lua, UF.auraDefaults) are the layout that used to be
-- fixed in code.
local _, ns = ...
local Options = ns.Options
local UF = ns.UnitFrames
if not Options or not UF or not UF.AuraSettings then return end

Options:Root('auras', function() return UF:AuraSettings() end)

Options:Category({ id = 'auras', title = 'Auras & Buffs', order = 50,
    desc = 'Buff and debuff icons: your own bars, the rows on the unit frames and how one icon looks.' })
Options:Category({ id = 'auras.bars', parent = 'auras', title = 'Player bars', order = 10,
    desc = 'Your own buff bar and debuff bar. Move and scale them with /sqedit.' })
Options:Category({ id = 'auras.rows', parent = 'auras', title = 'Frame rows', order = 20,
    desc = 'Buff and debuff icons attached to the unit frames.' })
Options:Category({ id = 'auras.look', parent = 'auras', title = 'Icon look', order = 30,
    desc = 'How one buff or debuff icon is drawn, on every row and bar.' })

local defaults = UF.auraDefaults
-- Icon look, sorting and countdown text: plain frames, safe in combat.
local function look() UF:ApplyAuraSettings(true) end
-- Unit-frame rows are re-laid out with the frame, so they wait for combat to end.
local function rows(unit) return function() if UF.Initialized then UF:ConfigureAuras(unit) end end end

-- Preview: the same two rows on each page, under page-specific ids.
local function preview(page)
    return { id = 'auras.' .. page .. '.preview', type = 'action', label = 'Preview icons', button = 'Toggle preview',
        section = 'Preview', order = 10,
        desc = 'Fills every enabled row and bar with placeholder icons to judge spacing and wrapping. Same as /sqauras.',
        keywords = 'preview test placeholder sqauras', combatSafe = true,
        func = function()
            local shown = UF:AuraTest(UF.auraTest and 0 or UF:AuraSettings().previewCount)
            return shown and ('Previewing ' .. shown .. ' icons per row.') or 'Preview off.'
        end },
    { id = 'auras.' .. page .. '.previewCount', type = 'slider', label = 'Preview icon count', section = 'Preview', order = 20,
        desc = 'How many placeholder icons each row gets while the preview is on.',
        keywords = 'preview count number',
        root = 'auras', path = 'previewCount', min = 1, max = 40, step = 1, integer = true, default = defaults.previewCount,
        drag = true, combatSafe = true,
        apply = function(_, value) if UF.auraTest then UF:AuraTest(value) end end }
end

-- Player bars --------------------------------------------------------------
local bars = { preview('bars') }
for index, key in ipairs({ 'Buffs', 'Debuffs' }) do
    local section = index == 1 and 'Buff bar' or 'Debuff bar'
    local word = index == 1 and 'buff' or 'debuff'
    local base, d = 'bars.' .. key .. '.', defaults.bars[key]
    local function add(option)
        option.id = 'auras.' .. base .. option.path
        option.path, option.root, option.section = base .. option.path, 'auras', section
        option.default = d[option.id:match('[^.]+$')]
        option.keywords = word .. ' bar player ' .. (option.keywords or '')
        if option.apply == nil then option.apply = look end
        bars[#bars + 1] = option
    end
    add({ path = 'enable', type = 'toggle', label = 'Show the ' .. word .. ' bar', order = 10, combatSafe = true,
        desc = 'Your own ' .. word .. 's as a bar of touching icons.' })
    add({ path = 'size', type = 'slider', label = 'Icon size', order = 20, min = 16, max = 64, step = 1, integer = true,
        desc = 'Size of one icon before the /sqedit scale. A geometry saved in /sqedit keeps its on-screen icon scale.',
        keywords = 'size bigger smaller' })
    add({ path = 'perRow', type = 'slider', label = 'Icons per row', order = 30, min = 4, max = 24, step = 1, integer = true,
        keywords = 'row wrap columns' })
    add({ path = 'max', type = 'slider', label = 'Most icons shown', order = 40, min = 12, max = 72, step = 1, integer = true,
        combatSafe = true, keywords = 'limit maximum' })
    add({ path = 'growthX', type = 'choice', label = 'Fill direction', order = 50, values = { 'LEFT', 'RIGHT' },
        labels = { 'Right to left', 'Left to right' }, keywords = 'grow direction horizontal' })
    add({ path = 'growthY', type = 'choice', label = 'Further rows', order = 60, values = { 'DOWN', 'UP' },
        labels = { 'Below', 'Above' }, keywords = 'grow direction vertical', combatSafe = true })
    add({ path = 'sortMethod', type = 'choice', label = 'Sort by', order = 70, values = { 'TIME_REMAINING', 'NAME' },
        labels = { 'Time left', 'Name' }, combatSafe = true, keywords = 'sort order' })
    add({ path = 'sortDirection', type = 'choice', label = 'Sort order', order = 80, values = { 'DESCENDING', 'ASCENDING' },
        labels = { 'Descending', 'Ascending' }, combatSafe = true, keywords = 'sort order reverse' })
    add({ path = 'countdown', type = 'toggle', label = 'Countdown numbers', order = 90, combatSafe = true,
        desc = 'Time left as a number on each icon.', keywords = 'timer duration text' })
    add({ path = 'countdownSize', type = 'slider', label = 'Countdown text size', order = 100, min = 6, max = 20, step = 1,
        integer = true, combatSafe = true, keywords = 'timer duration text font' })
    add({ path = 'countSize', type = 'slider', label = 'Stack count size', order = 110, min = 6, max = 20, step = 1,
        integer = true, combatSafe = true, keywords = 'stacks charges applications font' })
end
bars[#bars + 1] = { id = 'auras.weaponEnchants', type = 'toggle', label = 'Temporary weapon enchants', section = 'Buff bar', order = 120,
    desc = 'Poisons, oils, sharpening stones and shaman weapon buffs appear on the buff bar with their time left and charges.',
    keywords = 'weapon enchant poison oil stone imbue temporary',
    root = 'auras', path = 'weaponEnchants', default = defaults.weaponEnchants, combatSafe = true, apply = look,
    hidden = function() return not GetWeaponEnchantInfo end }
bars[#bars + 1] = { id = 'auras.hideBlizzard', type = 'toggle', label = "Hide the game's buff and debuff rows", section = 'Game rows', order = 10,
    desc = "Parks the game's own top-right rows. Turned off, they return with their next update; /reload gives the exact stock state.",
    keywords = 'blizzard default native buff frame hide',
    root = 'auras', path = 'hideBlizzard', default = defaults.hideBlizzard, combatSafe = false,
    apply = function() UF:ApplyNativeAuraRows() end }
Options:Add('auras.bars', bars)

-- Frame rows ---------------------------------------------------------------
local frameRows = { preview('rows') }
for index, unit in ipairs({ 'player', 'target' }) do
    local section = index == 1 and 'Player frame' or 'Target frame'
    local base, d, apply = 'split.' .. unit .. '.', defaults.split[unit], rows(unit)
    local function add(option)
        option.id = 'auras.' .. base .. option.path
        if option.default == nil then option.default = d[option.path] end
        option.path, option.root, option.section, option.apply = base .. option.path, 'auras', section, apply
        option.keywords = unit .. ' frame split line ' .. (option.keywords or '')
        frameRows[#frameRows + 1] = option
    end
    add({ path = 'enable', type = 'toggle', label = 'Buffs and debuffs on one line', order = 10,
        desc = 'One kind from each end of the frame, growing toward the middle. Off: the two rows saved in the profile.' })
    add({ path = 'left', type = 'choice', label = 'Left end', order = 20, values = { 'Debuffs', 'Buffs' },
        desc = 'Which kind starts at the left end; the other starts at the right end.', keywords = 'swap side' })
    add({ path = 'cells', type = 'number', label = 'Icons across the frame', order = 30, min = 4, max = 40, integer = true,
        allowEmpty = true, desc = "Icon size is the frame width divided by this. Empty: the frame's saved icons per row.",
        keywords = 'size per row columns' })
    add({ path = 'gap', type = 'slider', label = 'Empty icons in the middle', order = 40, min = 0, max = 10, step = 1, integer = true,
        desc = 'Each side takes half of what is left after this gap.', keywords = 'gap space middle' })
    add({ path = 'rows', type = 'slider', label = 'Most rows', order = 50, min = 1, max = 8, step = 1, integer = true })
    add({ path = 'yOffset', type = 'slider', label = 'Distance from the frame', order = 60, min = -20, max = 60, step = 1,
        integer = true, keywords = 'vertical offset' })
    add({ path = 'grow', type = 'choice', label = 'Rows sit', order = 70, values = { 'UP', 'DOWN' },
        labels = { 'Above the frame', 'Below the frame' }, keywords = 'grow direction up down' })
    add({ path = 'allBuffs', type = 'toggle', label = 'Show every buff', order = 80,
        desc = "Ignores the frame's saved buff filter on this line.", keywords = 'filter all' })
end
for index, item in ipairs({ { 'targettarget', 'Target of target' }, { 'targettargettarget', 'Target of target of target' },
    { 'pettarget', 'Pet target' }, { 'focustarget', 'Focus target' } }) do
    local unit = item[1]
    frameRows[#frameRows + 1] = { id = 'auras.small.' .. unit, type = 'toggle', label = item[2], section = 'Small frames', order = index * 10,
        desc = "Lets this frame's saved buff and debuff rows show. Off: the frame carries no aura icons.",
        keywords = 'small secondary frame rows ' .. unit,
        root = 'auras', path = 'small.' .. unit, default = defaults.small[unit], apply = rows(unit) }
end
Options:Add('auras.rows', frameRows)

-- Icon look ----------------------------------------------------------------
local lookRows = { preview('look') }
for _, option in ipairs({
    { id = 'auras.cell.rim', type = 'toggle', label = 'Action-bar rim', section = 'Icon', order = 10,
        desc = 'The gold cell rim of the action bars around every icon. Off: the icon fills its cell.',
        keywords = 'border rim gold frame', root = 'auras', path = 'cell.rim', default = defaults.cell.rim,
        combatSafe = true, apply = look },
    { id = 'auras.cell.desaturate', type = 'choice', label = "Grey out others' debuffs", section = 'Icon', order = 20,
        desc = 'Debuffs that are not yours lose their colour.', keywords = 'desaturate grey gray personal',
        values = { 'SAVED', 'ALWAYS', 'NEVER' }, labels = { "Each frame's saved choice", 'Always', 'Never' },
        root = 'auras', path = 'cell.desaturate', default = defaults.cell.desaturate, combatSafe = true, apply = look },
    { id = 'auras.cell.swipe', type = 'toggle', label = 'Cooldown swipe', section = 'Icon', order = 30,
        desc = 'The dark sweep that shows how much time is left.', keywords = 'swipe spiral clock duration',
        root = 'auras', path = 'cell.swipe', default = defaults.cell.swipe, combatSafe = true, apply = look },
    { id = 'auras.cell.numbers', type = 'toggle', label = 'Countdown numbers on frame rows', section = 'Icon', order = 40,
        desc = 'Time left as a number on unit-frame icons. The player bars have their own switch.',
        keywords = 'timer duration text numbers', root = 'auras', path = 'cell.numbers', default = defaults.cell.numbers,
        combatSafe = true, apply = look },
    { id = 'auras.cell.countFont', type = 'font', label = 'Stack count font', section = 'Stack count', order = 10,
        allowEmpty = true, emptyLabel = "(each row's own)", keywords = 'stacks charges applications font',
        root = 'auras', path = 'cell.countFont', combatSafe = true, apply = look },
    { id = 'auras.cell.countSize', type = 'number', label = 'Stack count size on frame rows', section = 'Stack count', order = 20,
        min = 5, max = 30, integer = true, allowEmpty = true, desc = "Empty: each row's saved size.",
        keywords = 'stacks charges applications size', root = 'auras', path = 'cell.countSize', combatSafe = true, apply = look },
    { id = 'auras.cell.countPosition', type = 'choice', label = 'Stack count corner on frame rows', section = 'Stack count', order = 30,
        allowEmpty = true, emptyLabel = "(each row's own)",
        values = { 'TOPLEFT', 'TOP', 'TOPRIGHT', 'LEFT', 'CENTER', 'RIGHT', 'BOTTOMLEFT', 'BOTTOM', 'BOTTOMRIGHT' },
        labels = { 'Top left', 'Top', 'Top right', 'Left', 'Centre', 'Right', 'Bottom left', 'Bottom', 'Bottom right' },
        keywords = 'stacks charges applications position', root = 'auras', path = 'cell.countPosition',
        combatSafe = true, apply = look },
}) do lookRows[#lookRows + 1] = option end
Options:Add('auras.look', lookRows)
