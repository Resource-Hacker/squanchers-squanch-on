-- SPDX-License-Identifier: MIT
-- Damage meter drawer on the right edge of the minimap panel.
--
-- Width: with the drawer open, the painted span [minimap panel + drawer] is as
-- wide as the painted chat panel, in screen pixels. The drawer's left side is
-- the panel's own right rim (the drawer draws no left edge), same top and
-- bottom as the panel.
--
-- Data: the client's C_DamageMeter sessions. Addons may not register the
-- combat log on this API generation. Amounts are secret numbers in combat, so
-- nothing here compares, adds or measures them: they only go to
-- StatusBar:SetValue/SetMinMaxValues, AbbreviateNumbers, string.format,
-- concatenation and FontString:SetText (the operations the client allows on
-- secrets: https://warcraft.wiki.gg/wiki/Secret_Values). The list order is the
-- one the client returns.
--
-- HUD, not a menu: never registered with ns:TrackMenuFrame, and every control
-- except the handle ignores the mouse while mouselook is locked and no
-- modifier is held.
local _, ns = ...
local Meter = { rows = {}, offset = 0, count = 0, visible = 0, closeToken = 0 }
ns.MeterDrawer = Meter

Meter.defaults = {
    enabled = true, open = false, mode = 'DamageDone', segment = 'current',
    texture = 'Squanch Smooth', barHeight = 14,
    showRank = true, showPercent = false, showPerSecond = true, classColors = true, firstNames = true,
    autoOpen = false, autoClose = 10, animate = true, hideNative = true,
}
-- Enum.DamageMeterType keys, in menu order.
local MODES = {
    { 'DamageDone', 'Damage' }, { 'Dps', 'DPS' }, { 'HealingDone', 'Healing' }, { 'Hps', 'HPS' },
    { 'Absorbs', 'Absorbs' }, { 'DamageTaken', 'Damage taken' }, { 'AvoidableDamageTaken', 'Avoidable damage taken' },
    { 'EnemyDamageTaken', 'Enemy damage taken' }, { 'Interrupts', 'Interrupts' }, { 'Dispels', 'Dispels' },
    { 'Deaths', 'Deaths' },
}
local RATE_FIRST = { Dps = true, Hps = true }
local NO_RATE = { Interrupts = true, Dispels = true, Deaths = true }
-- Header labels for the names that do not fit the strip; the tooltip and the
-- list show the full name.
local SHORT = { DamageTaken = 'Dmg taken', AvoidableDamageTaken = 'Avoidable', EnemyDamageTaken = 'Enemy taken' }
local HEADER, PAD, THROTTLE, MIN_WIDTH = 18, 6, .25, 40
-- The table under the title strip: a row of column names, then the rows.
-- Widths in interface units; the name column takes what is left and the
-- optional columns go (share, second value, rank) before it gets under NAME_MIN.
local COLUMNS, CELL, NAME_MIN = 13, 3, 40
local ORDER = { 'rank', 'name', 'value', 'rate', 'percent' }
-- Sized for the drawer beside the minimap (about 157 units inside): all four
-- fixed columns leave the name some 45 units, enough for a first name.
local WIDTH = { rank = 14, value = 38, rate = 32, percent = 28 }
local ALIGN = { rank = 'CENTER', name = 'LEFT', value = 'RIGHT', rate = 'RIGHT', percent = 'RIGHT' }
local VALUE_TITLE = {
    DamageDone = 'Damage', Dps = 'DPS', HealingDone = 'Healing', Hps = 'HPS', Absorbs = 'Absorbs',
    DamageTaken = 'Taken', AvoidableDamageTaken = 'Avoided', EnemyDamageTaken = 'Taken',
    Interrupts = 'Count', Dispels = 'Count', Deaths = 'Time',
}
local WHITE = [[Interface\Buttons\WHITE8X8]]
local FILL, TRACK, ROW_TEXT = .7, .6, { .93, .93, .9 } -- bar brightness, track alpha, row text

local function types() return Enum and Enum.DamageMeterType end
Meter.modeValues, Meter.modeLabels = {}, {}
for _, mode in ipairs(MODES) do
    local known = types()
    if not known or known[mode[1]] ~= nil then
        Meter.modeValues[#Meter.modeValues + 1] = mode[1]
        Meter.modeLabels[mode[1]] = mode[2]
    end
end

function Meter:Settings()
    local db = ns.db
    if type(db) ~= 'table' then return self.defaults end
    local values = db.meter
    if type(values) ~= 'table' then values = {}; db.meter = values end
    if self.filled ~= values then
        self.filled = values
        for key, value in pairs(self.defaults) do if values[key] == nil then values[key] = value end end
        if not self.modeLabels[values.mode] then values.mode = self.defaults.mode end
    end
    return values
end

local function secret(value) return issecretvalue and issecretvalue(value) or false end
-- AbbreviateNumbers is a client function from 12.0 on; string.format also
-- accepts a secret number.
local function amount(value)
    local ok, text = pcall(AbbreviateNumbers, value)
    if ok and text then return text end
    ok, text = pcall(string.format, '%.0f', value)
    return ok and text or '?'
end
-- Per-second values, one decimal at most. A readable number is rounded in
-- Lua. A secret one cannot be: AbbreviateNumbers does it with these
-- breakpoints (shown value = floor(n / significandDivisor) / fractionDivisor,
-- https://warcraft.wiki.gg/wiki/API_AbbreviateNumbers) once two known numbers
-- came out right on this client; otherwise string.format('%.1f'), which the
-- client also runs on secrets.
local function step(from, suffix, significand, fraction)
    return { breakpoint = from, abbreviation = suffix, significandDivisor = significand, fractionDivisor = fraction, abbreviationIsGlobal = false }
end
local RATE = { breakpointData = {
    step(1e9, 'B', 1e8, 10), step(1e6, 'M', 1e5, 10), step(1e4, 'K', 1e3, 1), step(1e3, 'K', 100, 10), step(0, '', .1, 10),
} }
local rateOptions -- nil: untried; false: this client renders them differently
local function rate(value)
    if not secret(value) then
        if type(value) ~= 'number' then return '?' end
        if value >= 1000 then return amount(math.floor(value + .5)) end
        return (string.format('%.1f', value):gsub('%.0$', ''))
    end
    if rateOptions == nil then
        local ok, low, high = pcall(function() return AbbreviateNumbers(10.16, RATE), AbbreviateNumbers(1234, RATE) end)
        rateOptions = ok and low == '10.1' and high == '1.2K' and RATE or false
    end
    if rateOptions then
        local ok, text = pcall(AbbreviateNumbers, value, rateOptions)
        if ok and text then return text end
    end
    local ok, text = pcall(string.format, '%.1f', value)
    return ok and text or '?'
end
-- First word of a readable name, without a "-Realm" suffix. A secret name is
-- passed on untouched.
local function shortName(name)
    if secret(name) or type(name) ~= 'string' then return name end
    local first = name:match('^[^%s%-]+')
    return first or name
end
local function label(parent, size)
    local widgets = ns.OptionWidgets
    if widgets then return widgets:Label(parent, '', size) end
    local text = parent:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    return text
end

-- Geometry -----------------------------------------------------------------
local function rimWidth()
    local spec = ns.DarkSkin.styles.minimap
    return spec.edge * 4.5 / 13 -- the gold a contentFit rim paints outside its frame
end
local function chatPixels()
    local skin = ns.DarkSkin
    local chat = skin.chatPanel
    if not chat then return end
    local spec = skin.styles.compact
    local outside = spec.offset - spec.edge * 4.5 / 13
    return (chat:GetWidth() + outside * 2) * chat:GetEffectiveScale()
end
-- Painted widths in screen pixels: chat panel, minimap panel + open drawer.
function Meter:Widths()
    local panel, frame = self.panel, self.frame
    if not panel or not frame then return end
    local scale, rim = panel:GetEffectiveScale(), rimWidth()
    return chatPixels(), (panel:GetWidth() + frame:GetWidth() + rim * 3) * scale
end

-- Fill and rim of the drawer (and of the proxy that plays its opening).
local function shell(frame)
    local skin = ns.DarkSkin
    local fill = frame:CreateTexture(nil, 'BACKGROUND', nil, -8)
    local border = skin:Panel(frame, 'minimap', 0)
    skin:StylePanelBackground(fill, border)
    -- This edge would lie exactly on the panel's right rim.
    if border.LeftEdge then border.LeftEdge:Hide() end
    return fill, border
end

function Meter:Layout()
    local panel, frame = self.panel, self.frame
    if not panel or not frame then return end
    local skin = ns.DarkSkin
    if skin.chatPanel and not self.chatHooked then
        self.chatHooked = true
        skin.chatPanel:HookScript('OnSizeChanged', function() self:QueueLayout() end)
    end
    local scale, rim = panel:GetEffectiveScale(), rimWidth()
    local pixels = chatPixels()
    local width = pixels and pixels / scale - panel:GetWidth() - rim * 3 or panel:GetWidth()
    width = math.max(MIN_WIDTH, width)
    frame:ClearAllPoints()
    frame:SetPoint('TOPLEFT', panel, 'TOPRIGHT', rim, 0)
    frame:SetPoint('BOTTOMLEFT', panel, 'BOTTOMRIGHT', rim, 0)
    frame:SetWidth(width)
    skin:FitPanelBackground(self.fill, self.border)
    -- Contents are laid out in interface units whatever the panel's scale is.
    local unit = UIParent:GetEffectiveScale() / scale
    self.content:SetScale(unit)
    self.inner = width / unit
    self:UpdateHeader()
    self:LayoutColumns()
    self:LayoutRows(panel:GetHeight() / unit - HEADER - COLUMNS - PAD)
    self:PlaceHandle()
end
function Meter:QueueLayout()
    if self.layoutQueued or not self.open then return end
    self.layoutQueued = true
    C_Timer.After(0, function()
        self.layoutQueued = nil
        if self.open then self:Layout(); self:Refresh() end
    end)
end

function Meter:PlaceHandle()
    local handle = self.handle
    if not handle then return end
    handle:ClearAllPoints()
    -- Centred on the painted outer edge; the arrow's art is the middle of it.
    handle:SetPoint('CENTER', self.open and self.frame or self.panel, 'RIGHT', rimWidth() + 2, 0)
    handle.arrow:SetRotation(self.open and math.pi / 2 or -math.pi / 2)
    handle:SetShown(self:Settings().enabled and true or false)
end

-- Rows ---------------------------------------------------------------------
local function rowEnter(row)
    local src = Meter.sources and Meter.sources[row.index]
    if not src or not GameTooltip then return end
    Meter.tipRow = row
    GameTooltip:SetOwner(row, 'ANCHOR_LEFT')
    if not pcall(GameTooltip.SetText, GameTooltip, src.name) then GameTooltip:SetText('Source') end
    local shown = 0
    pcall(function()
        local kind = types()[Meter:Settings().mode]
        local data
        if Meter.sessionID then
            data = C_DamageMeter.GetCombatSessionSourceFromID(Meter.sessionID, kind, src.sourceGUID, src.sourceCreatureID)
        else
            data = C_DamageMeter.GetCombatSessionSourceFromType(Meter:SessionType(), kind, src.sourceGUID, src.sourceCreatureID)
        end
        for index, spell in ipairs(data and data.combatSpells or {}) do
            if index > 12 then break end
            local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spell.spellID)
            GameTooltip:AddDoubleLine(name or '?', amount(spell.totalAmount), 1, 1, 1, 1, 1, 1)
            shown = shown + 1
        end
    end)
    if shown == 0 then GameTooltip:AddLine('No spell breakdown available right now.', .6, .6, .6) end
    GameTooltip:Show()
end
local function rowLeave(row)
    if Meter.tipRow == row then Meter.tipRow = nil end
    if GameTooltip and GameTooltip:IsOwned(row) then GameTooltip:Hide() end
end

local function texturePath()
    return ns.Media:Resolve('statusbar', Meter:Settings().texture)
end
local function createRow(list)
    local skin = ns.DarkSkin
    local row = CreateFrame('Frame', nil, list)
    row:EnableMouse(Meter.interactive and true or false)
    row:SetScript('OnEnter', rowEnter); row:SetScript('OnLeave', rowLeave)
    -- Only the bar ever holds a secret value; nothing is anchored to it.
    local bar = CreateFrame('StatusBar', nil, row)
    bar:SetAllPoints(row); bar:EnableMouse(false)
    local back = bar:CreateTexture(nil, 'BACKGROUND')
    back:SetAllPoints(bar); back:SetColorTexture(0, 0, 0, TRACK)
    local text = CreateFrame('Frame', nil, row)
    text:SetAllPoints(row); text:SetFrameLevel(bar:GetFrameLevel() + 1)
    local cells = {}
    for _, key in ipairs(ORDER) do
        local cell = label(text, 8)
        cell:SetJustifyH(ALIGN[key]); cell:SetWordWrap(false)
        local path = cell:GetFont()
        if path then cell:SetFont(path, 8, 'OUTLINE') end
        cell:SetTextColor(ROW_TEXT[1], ROW_TEXT[2], ROW_TEXT[3])
        cells[key] = cell
    end
    local line = row:CreateTexture(nil, 'ARTWORK')
    line:SetPoint('TOPLEFT', row, 'BOTTOMLEFT'); line:SetPoint('TOPRIGHT', row, 'BOTTOMRIGHT'); line:SetHeight(1)
    row.line = line
    local inner = skin.lineColor
    line:SetColorTexture(inner[1], inner[2], inner[3], 1)
    row.bar, row.cells = bar, cells
    return row
end

-- Columns ------------------------------------------------------------------
-- Internal lines share the unit frames' inner outline as it appears on screen
-- (Skin.lineColor: the flat equivalent of that tinted outline art).
local function paintRule(line)
    local color = ns.DarkSkin.lineColor
    line:SetColorTexture(color[1], color[2], color[3], 1)
end
local function ruleWidth(frame)
    return 2 * PixelUtil.GetPixelToUIUnitFactor() / frame:GetEffectiveScale()
end
-- Each cell is as wide as its column less the padding, so a long name is cut
-- inside the name column and numbers end on their column's right edge.
local function placeCells(cells, parent, columns)
    for key, cell in pairs(cells) do
        local column = columns[key]
        cell:ClearAllPoints()
        if column then
            cell:SetPoint('LEFT', parent, 'LEFT', column.left + CELL, 0)
            cell:SetWidth(math.max(1, column.width - CELL * 2))
        end
        cell:SetShown(column ~= nil)
    end
end
function Meter:LayoutColumns()
    local settings = self:Settings()
    local mode, inner = settings.mode, self.inner or 150
    local width = {
        rank = settings.showRank and WIDTH.rank or 0,
        value = math.min(WIDTH.value, inner * .5),
        rate = settings.showPerSecond and not NO_RATE[mode] and WIDTH.rate or 0,
        percent = settings.showPercent and mode ~= 'Deaths' and WIDTH.percent or 0,
    }
    for _, key in ipairs({ 'percent', 'rate', 'rank' }) do
        if inner - width.rank - width.value - width.rate - width.percent < NAME_MIN then width[key] = 0 end
    end
    width.name = math.max(1, inner - width.rank - width.value - width.rate - width.percent)
    local columns, left, dividers = {}, 0, 0
    local thick = ruleWidth(self.grid)
    for _, key in ipairs(ORDER) do
        if width[key] > 0 then
            columns[key] = { left = left, width = width[key] }
            if left > 0 then
                dividers = dividers + 1
                local line = self.dividers[dividers]
                if not line then
                    line = self.grid:CreateTexture(nil, 'ARTWORK')
                    paintRule(line)
                    self.dividers[dividers] = line
                end
                line:ClearAllPoints()
                line:SetPoint('TOPLEFT', self.grid, 'TOPLEFT', left - thick * .5, 0)
                line:SetPoint('BOTTOMLEFT', self.grid, 'BOTTOMLEFT', left - thick * .5, 0)
                line:SetWidth(thick)
                line:Show()
            end
            left = left + width[key]
        end
    end
    for index = dividers + 1, #self.dividers do self.dividers[index]:Hide() end
    for _, rule in ipairs(self.rules) do rule:SetHeight(thick) end
    self.columns = columns
    self.columnStamp = (self.columnStamp or 0) + 1
    local titles = self.titles
    titles.rank:SetText('#'); titles.name:SetText('Name'); titles.percent:SetText('%')
    titles.value:SetText(VALUE_TITLE[mode] or self.modeLabels[mode] or '')
    local perSecond = mode:find('Heal') and 'HPS' or mode:find('Damage') and 'DPS' or '/sec'
    titles.rate:SetText(RATE_FIRST[mode] and 'Total' or perSecond)
    placeCells(titles, self.head, columns)
end
-- The dividers run from the column names to the last row shown.
function Meter:SizeGrid(shown)
    self.grid:SetHeight(COLUMNS + math.max(0, shown) * (self.step or 0))
end

function Meter:LayoutRows(height)
    local settings = self:Settings()
    local barHeight = math.max(8, math.min(40, tonumber(settings.barHeight) or self.defaults.barHeight))
    local step = barHeight + 1
    local visible = math.max(1, math.floor(height / step))
    local path = texturePath()
    for index = 1, visible do
        local row = self.rows[index]
        if not row then row = createRow(self.list); self.rows[index] = row end
        row:ClearAllPoints()
        row:SetPoint('TOPLEFT', self.list, 'TOPLEFT', 0, -(index - 1) * step)
        row:SetPoint('TOPRIGHT', self.list, 'TOPRIGHT', 0, -(index - 1) * step)
        row:SetHeight(barHeight)
        if row.texture ~= path then row.texture = path; row.bar:SetStatusBarTexture(path) end
        if row.columnStamp ~= self.columnStamp then
            row.columnStamp = self.columnStamp
            placeCells(row.cells, row, self.columns)
        end
    end
    for index = visible + 1, #self.rows do self.rows[index]:Hide() end
    self.visible, self.step = visible, step
end

-- Data ---------------------------------------------------------------------
function Meter:SessionType()
    local kinds = Enum.DamageMeterSessionType
    return self:Settings().segment == 'overall' and kinds.Overall or kinds.Current
end
local function paint(row, src, rank, settings, top, sum)
    local mode = settings.mode
    local total, perSecond = src.totalAmount, src.amountPerSecond
    local died = mode == 'Deaths'
    if died then
        row.bar:SetMinMaxValues(0, 1); row.bar:SetValue(1)
    else
        row.bar:SetMinMaxValues(0, top); row.bar:SetValue(total)
    end
    local class = src.classFilename
    local color = settings.classColors and not secret(class) and class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if color then row.bar:SetStatusBarColor(color.r * FILL, color.g * FILL, color.b * FILL, 1)
    else
        local muted = ns.DarkSkin.innerBorderColor
        row.bar:SetStatusBarColor(muted[1] * FILL, muted[2] * FILL, muted[3] * FILL, 1)
    end
    -- Every cell is set, shown or not; a hidden column's cell stays hidden.
    local cells = row.cells
    cells.rank:SetText(rank)
    if settings.firstNames then cells.name:SetText(shortName(src.name)) else cells.name:SetText(src.name) end
    local first, second, share = '', '', nil
    if died then
        local ok, clock = pcall(SecondsToClock, src.deathTimeSeconds)
        first = ok and clock or ''
    else
        first, second = amount(total), NO_RATE[mode] and '' or rate(perSecond)
        if RATE_FIRST[mode] then first, second = second, first end
        -- A share needs arithmetic, which secret amounts (in combat) do not allow.
        if not secret(total) and not secret(sum) and type(sum) == 'number' and sum > 0 then
            share = total / sum * 100 + .5
        end
    end
    cells.value:SetText(first); cells.rate:SetText(second)
    if share then cells.percent:SetFormattedText('%d%%', share) else cells.percent:SetText('') end
    row.index = rank
end
local function render(self)
    local settings = self:Settings()
    self.count = 0
    local kind = types() and types()[settings.mode]
    if not C_DamageMeter or kind == nil or not Enum.DamageMeterSessionType then
        return "This game client has no damage meter data for addons."
    end
    if C_DamageMeter.IsDamageMeterAvailable then
        local available, reason = C_DamageMeter.IsDamageMeterAvailable()
        if not available then return "The game's damage meter is not available: " .. tostring(reason or '') end
    end
    local session
    if self.sessionID then session = C_DamageMeter.GetCombatSessionFromID(self.sessionID, kind)
    else session = C_DamageMeter.GetCombatSessionFromType(self:SessionType(), kind) end
    local sources = session and session.combatSources
    self.sources = sources
    local count = 0
    for _ in ipairs(sources or {}) do count = count + 1 end
    self.count = count
    self.offset = math.max(0, math.min(self.offset, count - self.visible))
    local top, sum = session and session.maxAmount, session and session.totalAmount
    for index = 1, self.visible do
        local row, src = self.rows[index], sources and sources[self.offset + index]
        if src then paint(row, src, self.offset + index, settings, top, sum); row:Show() else row:Hide() end
    end
    if count == 0 then
        if GetCVar and GetCVar('damageMeterEnabled') == '0' then
            return "The game's damage meter is turned off in the game options; it supplies this data."
        end
        return 'No combat data yet.'
    end
end
function Meter:Refresh()
    self.dirty, self.last = false, GetTime()
    if not self.frame or not self.frame:IsShown() then return end
    local ok, message = pcall(render, self)
    if not ok then message = 'The game refused meter data: ' .. tostring(message) end
    if not ok or self.count == 0 then
        for _, row in ipairs(self.rows) do row:Hide() end
    end
    self:SizeGrid(ok and math.min(self.visible, self.count - self.offset) or 0)
    self.notice:SetText(message or '')
    self.notice:SetShown(message ~= nil)
end

-- Header -------------------------------------------------------------------
local function choose(key, value)
    local options = ns.Options
    if options and options.byId['meter.' .. key] then options:Set('meter.' .. key, value)
    else Meter:Settings()[key] = value; Meter:Apply() end
end
local function segmentItems()
    local items = { { value = 'current', label = 'Current' }, { value = 'overall', label = 'Overall' } }
    local last = { value = 'reset', label = 'Reset data' }
    pcall(function()
        local sessions = C_DamageMeter.GetAvailableCombatSessions()
        local count = 0
        for _ in ipairs(sessions) do count = count + 1 end
        for index = math.max(1, count - 8), count do
            local session = sessions[index]
            local name = session.name
            if secret(name) or not name or name == '' then name = 'Fight ' .. tostring(session.sessionID) end
            items[#items + 1] = { value = session.sessionID, label = name }
        end
    end)
    items[#items + 1] = last
    return items
end
-- A flat text button: no rim, a faint highlight under the mouse, the full name
-- as its tooltip. getItems/onCommit work as on an OptionWidgets dropdown.
local function headerButton(parent, size, color, popupWidth)
    local widgets = ns.OptionWidgets
    local button = CreateFrame('Button', nil, parent)
    button:SetHeight(HEADER - 4)
    button:SetHighlightTexture(WHITE); button:GetHighlightTexture():SetVertexColor(1, .78, .42, .12)
    button.text = widgets:Label(button, '', size, color and color[1], color and color[2], color and color[3])
    button.text:SetPoint('LEFT', 2, 0); button.text:SetPoint('RIGHT', -2, 0); button.text:SetWordWrap(false)
    button:SetScript('OnClick', function(self)
        if widgets:PopupOwner() == self then widgets:ClosePopup(); return end
        if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
        widgets:OpenPopup(self, self:getItems(), self.value, nil, popupWidth)
    end)
    button:SetScript('OnEnter', function(self)
        if not self.tip or not GameTooltip then return end
        GameTooltip:SetOwner(self, 'ANCHOR_TOP'); GameTooltip:SetText(self.tip); GameTooltip:Show()
    end)
    button:SetScript('OnLeave', function(self) if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
    button:SetScript('OnHide', function(self) if widgets:PopupOwner() == self then widgets:ClosePopup() end end)
    return button
end
-- The fight label takes what its text needs, up to 45% of the strip; the mode
-- name gets the rest and falls back to its short form when it would be cut.
function Meter:UpdateHeader()
    local settings = self:Settings()
    local mode, segment = self.modeBox, self.segmentBox
    local free = math.max(40, (self.inner or 150) - PAD * 2)
    if self.sessionID then segment.value, segment.tip = self.sessionID, self.sessionName or 'Fight'
    else segment.value, segment.tip = settings.segment, settings.segment == 'overall' and 'Overall' or 'Current' end
    segment.text:SetText(segment.tip)
    local segmentWidth = math.min(math.ceil(segment.text:GetStringWidth()) + 6, math.floor(free * .45))
    segment:SetWidth(segmentWidth)
    local full = self.modeLabels[settings.mode] or settings.mode
    mode.value, mode.tip = settings.mode, full
    mode:SetWidth(free - segmentWidth)
    mode.text:SetText(full)
    if SHORT[settings.mode] and mode.text:GetStringWidth() > free - segmentWidth - 4 then mode.text:SetText(SHORT[settings.mode]) end
end

-- Mouse: ignored while mouselook is locked, unless a modifier is held.
function Meter:SetInteractive(on)
    on = on and true or false
    if self.interactive == on then return end
    self.interactive = on
    for _, row in ipairs(self.rows) do row:EnableMouse(on) end
    self.list:EnableMouseWheel(on)
    self.modeBox:EnableMouse(on); self.segmentBox:EnableMouse(on)
    if not on and self.tipRow then rowLeave(self.tipRow) end
end

-- Opening motion -----------------------------------------------------------
-- DrawerMotion unfolds upward; this is the same motion sideways. The drawer is
-- never moved or resized and its own alpha is never written: a render-only
-- Alpha animation holds it invisible while an empty shell grows rightward from
-- the panel, then the drawer fades in over the shell. Stopping at any point
-- leaves the drawer fully shown.
local function finishMotion(state)
    if not state.running then return end
    state.running = nil
    state.proxy:SetScript('OnUpdate', nil)
    state.proxy:Hide()
    if state.group:IsPlaying() then state.group:Stop() end
end
local function buildMotion(frame, panel)
    local proxy = CreateFrame('Frame', nil, panel)
    proxy:Hide(); proxy:EnableMouse(false); proxy.ignoreInLayout = true
    proxy:SetFrameLevel(frame:GetFrameLevel())
    local fill, border = shell(proxy)
    local group = frame:CreateAnimationGroup()
    local hold = group:CreateAnimation('Alpha')
    hold:SetOrder(1); hold:SetFromAlpha(0); hold:SetToAlpha(0)
    local fade = group:CreateAnimation('Alpha')
    fade:SetOrder(2); fade:SetFromAlpha(0); fade:SetToAlpha(1)
    group:SetLooping('NONE')
    local state = { proxy = proxy, fill = fill, border = border, group = group, hold = hold, fade = fade }
    group:SetScript('OnFinished', function() finishMotion(state) end)
    frame:HookScript('OnHide', function() finishMotion(state) end)
    return state
end
local function playMotion(self)
    local frame, panel, motion = self.frame, self.panel, ns.DrawerMotion
    if motion and motion:Setting('style') == 'none' then return end
    local grow = math.max(.05, tonumber(motion and motion:Setting('grow')) or .35)
    local fade = math.max(.05, tonumber(motion and motion:Setting('fade')) or .15)
    local state = self.motion
    if not state then state = buildMotion(frame, panel); self.motion = state end
    if state.running then return end
    local proxy, rim = state.proxy, rimWidth()
    proxy:ClearAllPoints()
    proxy:SetPoint('TOPLEFT', panel, 'TOPRIGHT', rim, 0)
    proxy:SetPoint('BOTTOMLEFT', panel, 'BOTTOMRIGHT', rim, 0)
    proxy:SetWidth(1); proxy:SetAlpha(1)
    ns.DarkSkin:FitPanelBackground(state.fill, state.border)
    state.running = true
    local elapsed, total = 0, grow + fade
    proxy:SetScript('OnUpdate', function(_, delta)
        elapsed = elapsed + delta
        local full = frame:GetWidth()
        if elapsed >= total or not full or full <= 0 or not frame:IsVisible() then finishMotion(state); return end
        if elapsed < grow then
            local eased = 1 - (1 - elapsed / grow) ^ 3
            proxy:SetWidth(math.max(math.min(16, full), full * eased))
        else
            proxy:SetWidth(full)
            proxy:SetAlpha(1 - (elapsed - grow) / fade)
        end
    end)
    proxy:Show()
    state.group:Stop()
    state.hold:SetDuration(grow); state.fade:SetDuration(fade)
    state.group:Play()
    -- The motion ends itself; this only covers one that did not.
    C_Timer.After(total + .1, function() finishMotion(state) end)
end

-- Open, close --------------------------------------------------------------
local METER_EVENTS = { 'DAMAGE_METER_COMBAT_SESSION_UPDATED', 'DAMAGE_METER_CURRENT_SESSION_UPDATED', 'DAMAGE_METER_RESET' }
-- auto: opened or closed by combat; the saved state follows only the handle.
function Meter:Open(auto)
    if not self.frame or self.open or not self:Settings().enabled then return end
    self.open, self.autoOpened = true, auto and true or nil
    if not auto then self:Settings().open = true end
    self:Layout()
    self.frame:Show()
    for _, event in ipairs(METER_EVENTS) do pcall(self.frame.RegisterEvent, self.frame, event) end
    self:PlaceHandle()
    self:UpdateHeader()
    self:Refresh()
    if self:Settings().animate then
        local ok = pcall(playMotion, self)
        if not ok and self.motion then pcall(finishMotion, self.motion) end
    end
end
function Meter:Close(auto)
    if not self.frame or not self.open then return end
    self.open, self.autoOpened = false, nil
    if not auto then self:Settings().open = false end
    self.frame:UnregisterAllEvents()
    self.frame:Hide()
    self.sources = nil
    self:PlaceHandle()
end

-- The game's own meter -----------------------------------------------------
-- Its frame is hidden after the game decides to show it; the game's setting,
-- layout and data collection are left alone.
local function hideNative(native)
    local settings = Meter:Settings()
    if not settings.enabled or not settings.hideNative then return end
    if native.IsEditing and native:IsEditing() then return end
    Meter.nativeHidden = true
    if native:IsShown() then native:Hide() end
end
function Meter:ApplyNative()
    local native = _G.DamageMeter
    if type(native) ~= 'table' or type(native.UpdateShownState) ~= 'function' then return end
    if not self.nativeHooked then
        self.nativeHooked = true
        hooksecurefunc(native, 'UpdateShownState', hideNative)
    end
    local settings = self:Settings()
    if settings.enabled and settings.hideNative then hideNative(native)
    elseif self.nativeHidden and not InCombatLockdown() then
        self.nativeHidden = nil
        pcall(native.UpdateShownState, native)
    end
end

-- Settings changed (options page, header, profile switch).
function Meter:Apply()
    if not self.frame then return end
    local settings = self:Settings()
    self:ApplyNative()
    if not settings.enabled then self:Close(true); self:PlaceHandle(); return end
    if self.open then
        self:Layout(); self:UpdateHeader(); self:Refresh()
    else
        self:PlaceHandle()
    end
end

function Meter:Initialize()
    if self.frame then return true end
    local skin, widgets, owner = ns.DarkSkin, ns.OptionWidgets, ns.MinimapPanel
    if not skin or not widgets or not owner or not owner.Ensure or not ns.Media then return end
    local panel = owner:Ensure()
    self.panel = panel
    local frame = CreateFrame('Frame', 'SquancherMeterDrawer', panel)
    frame:Hide(); frame:EnableMouse(false); frame.ignoreInLayout = true
    frame:SetFrameLevel(panel:GetFrameLevel() + 2)
    self.frame = frame
    self.fill, self.border = shell(frame)

    local content = CreateFrame('Frame', nil, frame)
    content:SetAllPoints(frame); content:EnableMouse(false)
    self.content = content
    local modeBox = headerButton(content, 10, skin.headerTextColor, 150)
    modeBox:SetPoint('TOPLEFT', content, 'TOPLEFT', PAD - 2, -2)
    function modeBox:getItems()
        local items = {}
        for _, value in ipairs(Meter.modeValues) do items[#items + 1] = { value = value, label = Meter.modeLabels[value] } end
        return items
    end
    modeBox.onCommit = function(_, value) choose('mode', value) end
    local segmentBox = headerButton(content, 8)
    segmentBox:SetPoint('TOPRIGHT', content, 'TOPRIGHT', 2 - PAD, -2)
    segmentBox.text:SetJustifyH('RIGHT')
    segmentBox.getItems = segmentItems
    segmentBox.onCommit = function(_, value)
        self.sessionID, self.sessionName, self.offset = nil, nil, 0
        if value == 'reset' then
            if C_DamageMeter and C_DamageMeter.ResetAllCombatSessions then pcall(C_DamageMeter.ResetAllCombatSessions) end
        elseif type(value) == 'number' then
            self.sessionID = value
            for _, item in ipairs(segmentItems()) do if item.value == value then self.sessionName = item.label end end
        elseif self:Settings().segment ~= value then
            choose('segment', value); return
        end
        self:UpdateHeader(); self:Refresh()
    end
    self.modeBox, self.segmentBox = modeBox, segmentBox

    -- Column names, between two rules; the dividers are on a frame above the
    -- rows so the bars do not cover them.
    local head = CreateFrame('Frame', nil, content)
    head:SetPoint('TOPLEFT', content, 'TOPLEFT', 0, -HEADER)
    head:SetPoint('TOPRIGHT', content, 'TOPRIGHT', 0, -HEADER)
    head:SetHeight(COLUMNS); head:EnableMouse(false)
    self.head, self.titles, self.rules, self.dividers = head, {}, {}, {}
    for _, key in ipairs(ORDER) do
        local title = label(head, 8)
        title:SetJustifyH(ALIGN[key]); title:SetWordWrap(false)
        self.titles[key] = title
    end
    for index, edge in ipairs({ 'TOP', 'BOTTOM' }) do
        local rule = head:CreateTexture(nil, 'ARTWORK')
        rule:SetPoint(edge .. 'LEFT', head, edge .. 'LEFT'); rule:SetPoint(edge .. 'RIGHT', head, edge .. 'RIGHT')
        paintRule(rule)
        self.rules[index] = rule
    end
    local list = CreateFrame('Frame', nil, content)
    list:SetPoint('TOPLEFT', head, 'BOTTOMLEFT')
    list:SetPoint('BOTTOMRIGHT', content, 'BOTTOMRIGHT', 0, 0)
    list:EnableMouse(false)
    list:SetScript('OnMouseWheel', function(_, delta)
        local offset = math.max(0, math.min(self.offset - delta, self.count - self.visible))
        if offset ~= self.offset then self.offset = offset; self:Refresh() end
    end)
    self.list = list
    local grid = CreateFrame('Frame', nil, content)
    grid:SetPoint('TOPLEFT', head, 'TOPLEFT'); grid:SetPoint('TOPRIGHT', head, 'TOPRIGHT')
    grid:SetHeight(COLUMNS); grid:EnableMouse(false)
    grid:SetFrameLevel(list:GetFrameLevel() + 5)
    self.grid = grid
    local function theme()
        local color = skin.headerTextColor
        for _, title in pairs(self.titles) do title:SetTextColor(color[1], color[2], color[3]) end
        modeBox.text:SetTextColor(color[1], color[2], color[3])
        for _, rule in ipairs(self.rules) do paintRule(rule) end
        for _, line in ipairs(self.dividers) do paintRule(line) end
        for _, row in ipairs(self.rows or {}) do if row.line then paintRule(row.line) end end
    end
    theme()
    skin:OnTheme(theme)
    local notice = label(list, 8)
    notice:SetPoint('TOPLEFT', list, 'TOPLEFT', PAD, -PAD); notice:SetPoint('TOPRIGHT', list, 'TOPRIGHT', -PAD, -PAD)
    notice:SetWordWrap(true); notice:Hide()
    self.notice = notice
    self.interactive = true -- controls are created mouse-enabled
    self:SetInteractive(false)

    -- Arrow on the panel's right edge; on the drawer's right edge while open.
    local handle = CreateFrame('Button', nil, panel)
    handle.ignoreInLayout = true
    handle:SetSize(18, 22)
    handle:SetFrameLevel(frame:GetFrameLevel() + 20)
    handle:RegisterForClicks('LeftButtonUp')
    local arrow = handle:CreateTexture(nil, 'ARTWORK')
    arrow:SetTexture([[Interface\Buttons\UI-ScrollBar-ScrollUpButton-Up]])
    arrow:SetPoint('CENTER'); arrow:SetSize(22, 18)
    skin:TintChrome(arrow)
    handle.arrow = arrow
    local title = widgets:Label(handle, 'Damage meter', 10, skin.headerTextColor[1], skin.headerTextColor[2], skin.headerTextColor[3])
    title:SetPoint('BOTTOM', handle, 'TOP', 0, 2); title:Hide()
    handle:SetScript('OnEnter', function() title:Show() end)
    handle:SetScript('OnLeave', function() title:Hide() end)
    handle:SetScript('OnHide', function() title:Hide() end)
    handle:SetScript('OnClick', function() if self.open then self:Close() else self:Open() end end)
    self.handle = handle

    -- Runs only while the drawer is shown.
    local waited = 0
    frame:SetScript('OnUpdate', function(_, delta)
        waited = waited + delta
        if waited < .1 then return end
        waited = 0
        self:SetInteractive((IsModifierKeyDown and IsModifierKeyDown()) or not (IsMouselooking and IsMouselooking()))
        if self.dirty and GetTime() - (self.last or 0) >= THROTTLE then self:Refresh() end
    end)
    frame:SetScript('OnEvent', function(_, event)
        if event == 'DAMAGE_METER_RESET' then
            self.sessionID, self.sessionName, self.offset = nil, nil, 0
            self:UpdateHeader()
        end
        self.dirty = true
    end)

    hooksecurefunc(owner, 'LayoutStack', function() self:QueueLayout() end)
    panel:HookScript('OnSizeChanged', function() self:QueueLayout() end)
    if skin.LayoutChat then hooksecurefunc(skin, 'LayoutChat', function() self:QueueLayout() end) end
    if ns.Options and ns.Options.OnChange then
        ns.Options:OnChange(function(_, _, reason) if reason == 'profile' then self:Apply() end end)
    end
    self:PlaceHandle()
    self:ApplyNative()
    if self:Settings().open then self:Open() end
    return true
end

local events = CreateFrame('Frame')
for _, event in ipairs({ 'PLAYER_LOGIN', 'ADDON_LOADED', 'PLAYER_REGEN_DISABLED', 'PLAYER_REGEN_ENABLED', 'UI_SCALE_CHANGED' }) do
    events:RegisterEvent(event)
end
events:SetScript('OnEvent', function(_, event, name)
    if event == 'PLAYER_LOGIN' then
        C_Timer.After(0, function()
            local ok, err = pcall(Meter.Initialize, Meter)
            if not ok and geterrorhandler then geterrorhandler()(err) end
        end)
    elseif not Meter.frame then
        return
    elseif event == 'ADDON_LOADED' then
        if name == 'Blizzard_DamageMeter' then Meter:ApplyNative() end
    elseif event == 'UI_SCALE_CHANGED' then
        Meter:QueueLayout()
    elseif event == 'PLAYER_REGEN_DISABLED' then
        Meter.closeToken = Meter.closeToken + 1
        if Meter:Settings().autoOpen then Meter:Open(true) end
    else -- PLAYER_REGEN_ENABLED
        Meter.dirty = true -- amounts are readable again: shares appear
        local delay = tonumber(Meter:Settings().autoClose) or 0
        if Meter.autoOpened and delay > 0 then
            local token = Meter.closeToken + 1
            Meter.closeToken = token
            C_Timer.After(delay, function()
                if token == Meter.closeToken and Meter.autoOpened and not InCombatLockdown() then Meter:Close(true) end
            end)
        end
    end
end)
