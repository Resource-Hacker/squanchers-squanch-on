-- SPDX-License-Identifier: MIT
-- Shared controls for Squanch-On's own settings windows: the same charcoal
-- faces, gold rims and text sizes as the rest of the interface.
local _, ns = ...
local W = {}
ns.OptionWidgets = W
local WHITE = [[Interface\Buttons\WHITE8X8]]
local GOLD = { 0.90, 0.684, 0.378 }

local function fontPath()
    return ns.UnitFrames and ns.UnitFrames.db and ns.UnitFrames:Font(ns.UnitFrames.db.font) or STANDARD_TEXT_FONT
end
function W:Label(parent, text, size, r, g, b)
    local font = parent:CreateFontString(nil, 'OVERLAY')
    font:SetFont(fontPath(), size or 10, '')
    font:SetShadowColor(0, 0, 0, 1); font:SetShadowOffset(1, -1)
    font:SetTextColor(r or .9, g or .9, b or .86)
    font:SetJustifyH('LEFT'); font:SetText(text or '')
    return font
end
function W:Header(parent, text)
    return self:Label(parent, text, 12, GOLD[1], GOLD[2], GOLD[3])
end
function W:Button(parent, text, width, callback, height)
    local control = CreateFrame('Button', nil, parent)
    control:SetSize(width, height or 24)
    control.text = self:Label(control, text, 10); control.text:SetPoint('CENTER'); control.text:SetJustifyH('CENTER')
    control:SetHighlightTexture(WHITE)
    ns.DarkSkin:RaisedButton(control, 'inner')
    function control:SetText(value) self.text:SetText(value) end
    function control:GetText() return self.text:GetText() end
    control:SetScript('OnClick', callback)
    return control
end
function W:Edit(parent, width)
    local control = CreateFrame('EditBox', nil, parent)
    control:SetSize(width, 22); control:SetAutoFocus(false)
    control:SetFont(fontPath(), 10, ''); control:SetTextColor(.9, .9, .86); control:SetTextInsets(6, 6, 0, 0)
    local face = control:CreateTexture(nil, 'BACKGROUND'); face:SetAllPoints(); face:SetColorTexture(.03, .03, .03, .85)
    ns.DarkSkin:Panel(control, 'inner', 0)
    control:SetScript('OnEscapePressed', function(self) self:ClearFocus() end)
    control:SetScript('OnEnterPressed', function(self) self:ClearFocus() end)
    return control
end
function W:Check(parent)
    local control = CreateFrame('CheckButton', nil, parent)
    control:SetSize(20, 20)
    local face = control:CreateTexture(nil, 'BACKGROUND'); face:SetAllPoints(); face:SetColorTexture(.03, .03, .03, .85)
    local mark = control:CreateTexture(nil, 'ARTWORK')
    mark:SetPoint('TOPLEFT', 4, -4); mark:SetPoint('BOTTOMRIGHT', -4, 4)
    mark:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    control:SetCheckedTexture(mark)
    control:SetHighlightTexture(WHITE); control:GetHighlightTexture():SetVertexColor(1, .78, .42, .08)
    ns.DarkSkin:Panel(control, 'inner', 0)
    return control
end
-- A wheel-scrolled body with a slim position marker instead of stock scroll art.
function W:Scroll(parent)
    local scroll = CreateFrame('ScrollFrame', nil, parent)
    local body = CreateFrame('Frame', nil, scroll); body:SetSize(1, 1); scroll:SetScrollChild(body)
    local thumb = parent:CreateTexture(nil, 'OVERLAY'); thumb:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], .7); thumb:SetWidth(3)
    local function refresh()
        local range, height = scroll:GetVerticalScrollRange(), scroll:GetHeight()
        if range <= 0 or height <= 0 then thumb:Hide(); return end
        local size = math.max(24, height * height / (height + range))
        thumb:SetHeight(size); thumb:ClearAllPoints()
        thumb:SetPoint('TOPLEFT', scroll, 'TOPRIGHT', 6, -(height - size) * scroll:GetVerticalScroll() / range)
        thumb:Show()
    end
    scroll:EnableMouseWheel(true)
    scroll:SetScript('OnMouseWheel', function(self, delta)
        local range = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(range, self:GetVerticalScroll() - delta * 60))); refresh()
    end)
    scroll:SetScript('OnScrollRangeChanged', function(self)
        self:SetVerticalScroll(math.min(self:GetVerticalScroll(), self:GetVerticalScrollRange())); refresh()
    end)
    scroll:SetScript('OnSizeChanged', refresh)
    scroll.Refresh = refresh
    return scroll, body
end
function W:Window(name, width, height, title)
    local frame = CreateFrame('Frame', name, UIParent)
    frame:SetSize(width, height); frame:SetPoint('CENTER'); frame:SetFrameStrata('DIALOG'); frame:SetToplevel(true)
    frame:EnableMouse(true); frame:SetMovable(true); frame:SetClampedToScreen(true); frame:RegisterForDrag('LeftButton')
    frame:SetScript('OnDragStart', frame.StartMoving); frame:SetScript('OnDragStop', frame.StopMovingOrSizing)
    local border = ns.DarkSkin:Panel(frame, 'dialog', 0)
    local fill = frame:CreateTexture(nil, 'BACKGROUND'); fill:SetTexture(WHITE)
    ns.DarkSkin:StylePanelBackground(fill, border)
    -- Settings need a readable backing; the shared translucent fill gets a darker underlay.
    local under = frame:CreateTexture(nil, 'BACKGROUND', nil, -8); under:SetAllPoints(fill); under:SetColorTexture(.02, .02, .02, .82)
    frame.title = self:Header(frame, title); frame.title:SetPoint('TOPLEFT', 18, -16)
    local rule = frame:CreateTexture(nil, 'ARTWORK'); rule:SetColorTexture(GOLD[1] * .78, GOLD[2] * .78, GOLD[3] * .78, .9)
    rule:SetHeight(1); rule:SetPoint('TOPLEFT', 14, -38); rule:SetPoint('TOPRIGHT', -14, -38)
    frame.close = self:Button(frame, 'x', 22, function() frame:Hide() end, 22)
    frame.close:SetPoint('TOPRIGHT', -12, -10)
    if UISpecialFrames then table.insert(UISpecialFrames, name) end
    if ns.TrackMenuFrame then ns:TrackMenuFrame(frame) end
    -- Start hidden so the first Show runs the tracked OnShow handlers.
    frame:Hide()
    return frame
end

-- ---------------------------------------------------------------------------
-- Controls for the unified settings window (OptionsWindow.lua). Everything
-- below is additive; the functions above keep their signatures and behaviour.
-- Shared conventions: body text 8, headers 10, controls 16 high; every control
-- has SetDisabled(flag) and reports through plain fields (onCommit, onPreview)
-- so pooled rows need no per-redraw closures.
local BODY, HEAD, DIM = 8, 10, 0.4
local HOVER = { 1, 0.85, 0.55 }
local GREY = { 0.62, 0.62, 0.6 }
W.bodySize, W.headerSize, W.gold = BODY, HEAD, GOLD

local function rim(frame, style)
    local skin = ns.DarkSkin
    return skin and skin.Panel and skin:Panel(frame, style or 'inner', 0)
end
local function face(frame)
    local texture = frame:CreateTexture(nil, 'BACKGROUND')
    texture:SetAllPoints(); texture:SetColorTexture(.03, .03, .03, .85)
    return texture
end
local function dim(control, disabled)
    control.disabled = disabled and true or false
    control:SetAlpha(disabled and DIM or 1)
end

function W:SmallButton(parent, text, width, callback)
    local control = self:Button(parent, text, width, callback, 16)
    control.text:SetFont(fontPath(), BODY, '')
    function control:SetDisabled(disabled)
        if disabled then self:Disable() else self:Enable() end
        dim(self, disabled)
    end
    return control
end

-- An edit box that commits on Enter or on losing focus and restores on Escape.
-- onCommit(control, text) runs only when the text changed.
function W:ValueEdit(parent, width)
    local control = self:Edit(parent, width)
    control:SetHeight(16); control:SetFont(fontPath(), BODY, ''); control:SetTextInsets(4, 4, 0, 0)
    control.stored = ''
    function control:SetStored(text)
        self.stored = text or ''
        if not self:HasFocus() then self:SetText(self.stored); self:SetCursorPosition(0) end
    end
    function control:SetDisabled(disabled)
        if disabled and self:HasFocus() then self:ClearFocus() end
        self:EnableMouse(not disabled); dim(self, disabled)
    end
    control:SetScript('OnEscapePressed', function(self)
        self.cancelled = true; self:SetText(self.stored); self:ClearFocus()
    end)
    control:SetScript('OnEnterPressed', function(self) self:ClearFocus() end)
    control:SetScript('OnEditFocusGained', function(self) self:HighlightText() end)
    control:SetScript('OnEditFocusLost', function(self)
        self:HighlightText(0, 0)
        if self.cancelled then self.cancelled = nil; return end
        local text = self:GetText()
        if text ~= self.stored and self.onCommit then self.onCommit(self, text) end
    end)
    return control
end

-- A small gold chevron drawn with two lines; SetDirection('down'|'right'|'up').
function W:Chevron(parent, size)
    local frame = CreateFrame('Frame', nil, parent)
    frame:SetSize(size, size)
    local half, quarter = size * 0.32, size * 0.18
    if frame.CreateLine then
        local a, b = frame:CreateLine(nil, 'ARTWORK'), frame:CreateLine(nil, 'ARTWORK')
        a:SetThickness(1.2); b:SetThickness(1.2)
        function frame:SetDirection(direction)
            if direction == 'right' then
                a:SetStartPoint('CENTER', self, -quarter, half); a:SetEndPoint('CENTER', self, quarter, 0)
                b:SetStartPoint('CENTER', self, quarter, 0); b:SetEndPoint('CENTER', self, -quarter, -half)
            else
                local sign = direction == 'up' and -1 or 1
                a:SetStartPoint('CENTER', self, -half, quarter * sign); a:SetEndPoint('CENTER', self, 0, -quarter * sign)
                b:SetStartPoint('CENTER', self, 0, -quarter * sign); b:SetEndPoint('CENTER', self, half, quarter * sign)
            end
        end
        function frame:SetColor(r, g, b2) a:SetColorTexture(r, g, b2, 1); b:SetColorTexture(r, g, b2, 1) end
    else
        local text = W:Label(frame, '', BODY); text:SetPoint('CENTER')
        function frame:SetDirection(direction) text:SetText(direction == 'right' and '>' or direction == 'up' and '^' or 'v') end
        function frame:SetColor(r, g, b2) text:SetTextColor(r, g, b2) end
    end
    frame:SetColor(GOLD[1], GOLD[2], GOLD[3]); frame:SetDirection('down')
    return frame
end

-- Numbers are shown multiplied by `scale` in `format`, or with as many
-- decimals as the step needs.
local function formatNumber(spec, value)
    if type(value) ~= 'number' then return tostring(value) end
    local scale = spec.scale or 1
    local step = (spec.step or 0.01) * scale
    local pattern = spec.format or (step >= 1 and '%.0f' or step >= 0.1 and '%.1f' or step >= 0.01 and '%.2f' or '%.3f')
    return pattern:format(value * scale)
end
-- Hover tooltip: label, description, default and how the change applies.
function W:FormatValue(option, value, ctx)
    if value == nil then return option.emptyLabel or 'inherit' end
    local kind = option.type
    if kind == 'toggle' then return value and 'on' or 'off' end
    if kind == 'slider' or kind == 'number' then return formatNumber(option, value) end
    if kind == 'color' and type(value) == 'table' then
        return string.format('%d, %d, %d', (value.r or 0) * 255 + .5, (value.g or 0) * 255 + .5, (value.b or 0) * 255 + .5)
    end
    if kind == 'choice' and ns.Options then return ns.Options:ChoiceLabel(option, ctx, value) end
    if type(value) == 'table' then return nil end
    return tostring(value)
end
function W:Describe(owner, option, ctx, note)
    if not GameTooltip or not option then return end
    GameTooltip:SetOwner(owner, 'ANCHOR_RIGHT')
    GameTooltip:SetText(option.label or '', GOLD[1], GOLD[2], GOLD[3], 1, true)
    local desc = option.desc
    if type(desc) == 'function' then desc = desc(ctx) end
    if desc and desc ~= '' then GameTooltip:AddLine(desc, .9, .9, .86, true) end
    local registry = ns.Options
    if registry and option.type ~= 'action' and option.type ~= 'note' and registry:HasDefault(option) then
        local text = self:FormatValue(option, registry:Default(option, ctx), ctx)
        if text then GameTooltip:AddLine('Default: ' .. text, GREY[1], GREY[2], GREY[3], true) end
        GameTooltip:AddLine('Right-click resets this setting.', GREY[1], GREY[2], GREY[3], true)
    end
    if option.requiresReload then GameTooltip:AddLine('Needs a reload to take effect.', 1, .6, .3, true)
    elseif not option.combatSafe then GameTooltip:AddLine('In combat the change waits until combat ends.', GREY[1], GREY[2], GREY[3], true) end
    if note then GameTooltip:AddLine(note, 1, .6, .3, true) end
    GameTooltip:Show()
end
function W:HideDescription(owner)
    if GameTooltip and (not owner or GameTooltip:GetOwner() == owner) then GameTooltip:Hide() end
end

-- Escape closes one layer at a time: while a popup or the colour picker is
-- open, the settings window is taken out of UISpecialFrames.
local holds = 0
local function special(name, present)
    if not UISpecialFrames or not name then return end
    for index = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[index] == name then
            if present then return end
            table.remove(UISpecialFrames, index)
        end
    end
    if present then table.insert(UISpecialFrames, name) end
end
function W:SetEscapeWindow(name)
    self.escapeWindow = name
    special(name, holds == 0)
end
function W:HoldEscape(hold)
    if hold then
        holds = holds + 1
        special(self.escapeWindow, false)
        return
    end
    holds = math.max(0, holds - 1)
    -- Restore after the current Escape has finished walking UISpecialFrames.
    local function restore() if holds == 0 then special(W.escapeWindow, true) end end
    if C_Timer and C_Timer.After then C_Timer.After(0, restore) else restore() end
end

-- Slider with a typed value. Configure{min,max,step,softMin,softMax,format,scale};
-- onPreview(control, value) while dragging, onCommit(control, value) on release
-- or typed entry. The mouse wheel is left to the page scroll.
function W:Slider(parent, width)
    local holder = CreateFrame('Frame', nil, parent)
    holder:SetSize(width, 16)
    local slider = CreateFrame('Slider', nil, holder)
    slider:SetOrientation('HORIZONTAL'); slider:SetPoint('LEFT', 0, 0); slider:SetSize(width - 50, 12)
    slider:EnableMouseWheel(false)
    local track = slider:CreateTexture(nil, 'BACKGROUND')
    track:SetColorTexture(.03, .03, .03, .85); track:SetHeight(4)
    track:SetPoint('LEFT', 0, 0); track:SetPoint('RIGHT', 0, 0)
    local edge = slider:CreateTexture(nil, 'BACKGROUND', nil, -1)
    edge:SetColorTexture(GOLD[1] * .55, GOLD[2] * .55, GOLD[3] * .55, .9)
    edge:SetPoint('TOPLEFT', track, -1, 1); edge:SetPoint('BOTTOMRIGHT', track, 1, -1)
    local thumb = slider:CreateTexture(nil, 'OVERLAY')
    thumb:SetColorTexture(1, 1, 1, 1); thumb:SetSize(6, 12); thumb:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
    slider:SetThumbTexture(thumb)
    local fill = slider:CreateTexture(nil, 'ARTWORK')
    fill:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], .6); fill:SetHeight(4)
    fill:SetPoint('LEFT', track, 'LEFT'); fill:SetPoint('RIGHT', thumb, 'CENTER')
    local edit = self:ValueEdit(holder, 44)
    edit:SetPoint('RIGHT', 0, 0); edit:SetJustifyH('RIGHT')
    holder.slider, holder.edit, holder.spec = slider, edit, {}

    local function paint()
        if holder.dragging then thumb:SetVertexColor(1, 1, 1)
        elseif holder.hovered then thumb:SetVertexColor(HOVER[1], HOVER[2], HOVER[3])
        else thumb:SetVertexColor(GOLD[1], GOLD[2], GOLD[3]) end
    end
    function holder:Snap(value)
        local spec = self.spec
        if spec.step and spec.step > 0 then
            local base = spec.min or 0
            value = base + math.floor((value - base) / spec.step + 0.5) * spec.step
        end
        if spec.min and value < spec.min then value = spec.min end
        if spec.max and value > spec.max then value = spec.max end
        return value
    end
    function holder:Configure(spec)
        self.spec = spec
        local low, high = spec.softMin or spec.min or 0, spec.softMax or spec.max or 1
        if high <= low then high = low + 1 end
        slider:SetMinMaxValues(low, high)
        slider:SetValueStep(spec.step and spec.step > 0 and spec.step or (high - low) / 100)
        if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
    end
    function holder:SetValue(value)
        self.value = value
        if self.dragging then return end
        local low = slider:GetMinMaxValues()
        slider:SetValue(type(value) == 'number' and value or low)
        edit:SetStored(type(value) == 'number' and formatNumber(self.spec, value) or '')
    end
    function holder:SetDisabled(disabled)
        if disabled then self.dragging = false end
        slider:EnableMouse(not disabled); edit:SetDisabled(disabled); dim(self, disabled); paint()
    end
    slider:SetScript('OnEnter', function() holder.hovered = true; paint(); if holder.onEnter then holder.onEnter(holder) end end)
    slider:SetScript('OnLeave', function() holder.hovered = false; paint(); if holder.onLeave then holder.onLeave(holder) end end)
    slider:SetScript('OnMouseDown', function(_, button)
        if button == 'LeftButton' and not holder.disabled then holder.dragging = true; paint() end
    end)
    slider:SetScript('OnValueChanged', function(_, value)
        if not holder.dragging then return end
        value = holder:Snap(value)
        if value == holder.shown then return end
        holder.shown = value
        edit:SetText(formatNumber(holder.spec, value))
        if holder.onPreview then holder.onPreview(holder, value) end
    end)
    slider:SetScript('OnMouseUp', function(self)
        if not holder.dragging then return end
        holder.dragging, holder.shown = false, nil
        paint()
        if holder.onCommit then holder.onCommit(holder, holder:Snap(self:GetValue())) end
    end)
    slider:SetScript('OnHide', function() holder.dragging, holder.shown, holder.hovered = false, nil, false; paint() end)
    edit.onCommit = function(box, text)
        local typed = tonumber((text:gsub(',', '.'):match('%-?%d*%.?%d+')))
        if typed and holder.onCommit then holder.onCommit(holder, typed / (holder.spec.scale or 1))
        else box:SetStored(box.stored) end
    end
    return holder
end

-- Media names for the pickers. Media.lua and LibSharedMedia are optional here.
local knownMedia = {
    font = { 'PT Sans Narrow', 'Expressway', 'Homizio', 'Harry', 'Forced', 'Action Man' },
    statusbar = { 'Tukui', 'Flat', 'Skullflower' },
    border = {},
}
local function sharedMedia()
    return type(LibStub) == 'table' and LibStub('LibSharedMedia-3.0', true) or nil
end
function W:MediaList(kind)
    local names, seen = {}, {}
    local function add(list)
        if type(list) ~= 'table' then return end
        for _, name in ipairs(list) do
            if type(name) == 'string' and name ~= '' and not seen[name] then seen[name] = true; names[#names + 1] = name end
        end
    end
    local media = ns.Media
    if media and media.List then
        local ok, list = pcall(media.List, media, kind)
        if ok then add(list) end
    else
        add(knownMedia[kind])
    end
    local shared = sharedMedia()
    if shared then
        local ok, list = pcall(shared.List, shared, kind)
        if ok then add(list) end
    end
    return names, seen
end
function W:MediaPath(kind, name)
    if type(name) ~= 'string' or name == '' then return nil end
    local media, path = ns.Media, nil
    if kind ~= 'border' and media and media.Resolve then
        local ok, result = pcall(media.Resolve, media, kind, name)
        path = ok and result or nil
    else
        local shared = sharedMedia()
        local ok, result = pcall(function() return shared and shared:Fetch(kind, name, true) end)
        path = ok and result or nil
    end
    return type(path) == 'string' and path or nil
end
-- Items for a media dropdown: optional "(inherit)", the current name first when
-- it is not a listed one, then every listed name.
function W:MediaItems(kind, current, allowEmpty, emptyLabel)
    local names, seen = self:MediaList(kind)
    local items = {}
    if allowEmpty then items[#items + 1] = { label = emptyLabel or '(inherit)', plain = true } end
    if type(current) == 'string' and current ~= '' and not seen[current] then
        local media = ns.Media
        local canonical
        if media and media.Canonical then
            local ok, result = pcall(media.Canonical, media, kind, current)
            canonical = ok and result or nil
        end
        if not (canonical and seen[canonical]) then
            local missing = media and media.missing and media.missing[kind .. ':' .. current]
            items[#items + 1] = { value = current, label = (missing and '(missing) ' or '') .. current, missing = missing and true or false }
        end
    end
    for _, name in ipairs(names) do items[#items + 1] = { value = name, label = name } end
    return items
end

-- One shared popup list for every dropdown: at most 12 rows of 16, wheel
-- scrolled, with a filter box for long lists. Not built on UIDropDownMenu.
local POPUP_ROW, POPUP_ROWS = 16, 12
local popup
local function classColor()
    local _, class = UnitClass and UnitClass('player')
    local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if color then return color.r, color.g, color.b end
    return GOLD[1], GOLD[2], GOLD[3]
end
local function paintPreview(row, kind, item, size)
    local label = row.label or row.text
    local path = not item.plain and kind and W:MediaPath(kind, item.value) or nil
    local offset = 6
    if row.strip then row.strip:Hide() end
    if row.sample then row.sample:Hide() end
    -- A font file that fails to load leaves the default in place.
    label:SetFont(fontPath(), size, '')
    if kind == 'font' and path then label:SetFont(path, size, '') end
    if kind == 'statusbar' and path then
        row.strip = row.strip or row:CreateTexture(nil, 'ARTWORK')
        row.strip:SetTexture(path); row.strip:SetVertexColor(classColor())
        row.strip:ClearAllPoints(); row.strip:SetPoint('LEFT', 6, 0); row.strip:SetSize(row.stripWidth or 110, size)
        row.strip:Show(); offset = 12 + (row.stripWidth or 110)
    elseif kind == 'border' and path then
        if not row.sample then
            row.sample = CreateFrame('Frame', nil, row, BackdropTemplateMixin and 'BackdropTemplate' or nil)
            row.sample:SetPoint('LEFT', 6, 0); row.sample:SetSize(60, 14)
        end
        if row.sample.SetBackdrop then
            row.sample:SetBackdrop({ edgeFile = path, edgeSize = 8 })
            row.sample:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 1)
            row.sample:Show(); offset = 72
        end
    end
    label:ClearAllPoints(); label:SetPoint('LEFT', offset, 0); label:SetPoint('RIGHT', -14, 0)
    if item.missing then label:SetTextColor(1, .35, .3) else label:SetTextColor(.9, .9, .86) end
    label:SetText(item.label or tostring(item.value))
end
local function popupRefresh()
    local view = popup.view
    local shown = math.min(#view, POPUP_ROWS)
    popup.offset = math.max(0, math.min(popup.offset, #view - shown))
    for index = 1, POPUP_ROWS do
        local row = popup.rows[index]
        local item = view[popup.offset + index]
        if item then
            row.item = item
            paintPreview(row, popup.kind, item, HEAD)
            if item.value == popup.current then row.mark:Show() else row.mark:Hide() end
            row:Show()
        else
            row.item = nil; row:Hide()
        end
    end
    local top = popup.filter:IsShown() and 26 or 6
    popup:SetHeight(top + math.max(1, shown) * POPUP_ROW + 6)
    popup.empty:SetShown(#view == 0)
    if #view > shown then
        local span = shown * POPUP_ROW
        local size = math.max(12, span * shown / #view)
        popup.thumb:SetHeight(size); popup.thumb:ClearAllPoints()
        popup.thumb:SetPoint('TOPRIGHT', -4, -top - (span - size) * popup.offset / (#view - shown))
        popup.thumb:Show()
    else
        popup.thumb:Hide()
    end
end
local function popupFilter(text)
    local view = popup.view
    for index = #view, 1, -1 do view[index] = nil end
    text = (text or ''):lower()
    for _, item in ipairs(popup.items) do
        if text == '' or tostring(item.label or item.value):lower():find(text, 1, true) then view[#view + 1] = item end
    end
    popupRefresh()
end
local function buildPopup()
    popup = CreateFrame('Frame', 'SquanchOnOptionsPopup', UIParent)
    popup:SetFrameStrata('FULLSCREEN_DIALOG'); popup:SetFrameLevel(20)
    popup:SetClampedToScreen(true); popup:EnableMouse(true); popup:EnableMouseWheel(true); popup:Hide()
    local border = rim(popup, 'compact')
    local fill = popup:CreateTexture(nil, 'BACKGROUND'); fill:SetTexture(WHITE)
    if border and ns.DarkSkin.StylePanelBackground then ns.DarkSkin:StylePanelBackground(fill, border) else fill:SetAllPoints() end
    local under = popup:CreateTexture(nil, 'BACKGROUND', nil, -8); under:SetAllPoints(fill); under:SetColorTexture(.02, .02, .02, .92)
    -- Any click outside the list closes it.
    local blocker = CreateFrame('Button', nil, UIParent)
    blocker:SetFrameStrata('FULLSCREEN_DIALOG'); blocker:SetFrameLevel(10); blocker:SetAllPoints(UIParent)
    blocker:RegisterForClicks('AnyUp'); blocker:Hide()
    blocker:SetScript('OnClick', function() popup:Hide() end)
    popup.filter = W:ValueEdit(popup, 100)
    popup.filter:SetPoint('TOPLEFT', 6, -6); popup.filter:SetPoint('TOPRIGHT', -6, -6)
    popup.filter:SetScript('OnTextChanged', function(self) popup.offset = 0; popupFilter(self:GetText()) end)
    popup.filter:SetScript('OnEscapePressed', function() popup:Hide() end)
    popup.filter:SetScript('OnEditFocusLost', nil)
    popup.empty = W:Label(popup, 'Nothing matches.', BODY, GREY[1], GREY[2], GREY[3]); popup.empty:SetPoint('BOTTOMLEFT', 8, 10)
    popup.thumb = popup:CreateTexture(nil, 'OVERLAY'); popup.thumb:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], .7); popup.thumb:SetWidth(3)
    popup.rows, popup.view, popup.offset = {}, {}, 0
    for index = 1, POPUP_ROWS do
        local row = CreateFrame('Button', nil, popup)
        row:SetHeight(POPUP_ROW)
        row:SetHighlightTexture(WHITE); row:GetHighlightTexture():SetVertexColor(1, .78, .42, .12)
        row:SetPushedTexture(WHITE); row:GetPushedTexture():SetVertexColor(1, .78, .42, .22)
        row.label = W:Label(row, '', HEAD); row.label:SetWordWrap(false)
        row.mark = row:CreateTexture(nil, 'OVERLAY'); row.mark:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
        row.mark:SetSize(4, 4); row.mark:SetPoint('RIGHT', -10, 0)
        row:SetScript('OnClick', function(self)
            local owner, item = popup.owner, self.item
            popup:Hide()
            if owner and item and owner.onCommit then owner.onCommit(owner, item.value) end
        end)
        popup.rows[index] = row
    end
    popup:SetScript('OnMouseWheel', function(_, delta) popup.offset = popup.offset - delta * 3; popupRefresh() end)
    popup:SetScript('OnShow', function() blocker:Show(); W:HoldEscape(true) end)
    popup:SetScript('OnHide', function()
        blocker:Hide(); popup.filter:ClearFocus(); popup.owner = nil; W:HoldEscape(false)
    end)
    if UISpecialFrames then table.insert(UISpecialFrames, 'SquanchOnOptionsPopup') end
end
-- items: { { value =, label =, missing =, plain = }, ... }. The owner's
-- onCommit(owner, value) receives the pick. kind: nil | 'font' | 'statusbar' | 'border'.
function W:OpenPopup(owner, items, current, kind, width)
    if not popup then buildPopup() end
    if popup:IsShown() then popup:Hide() end
    popup.owner, popup.items, popup.current, popup.kind, popup.offset = owner, items, current, kind, 0
    popup:SetScale(owner:GetEffectiveScale() / UIParent:GetEffectiveScale())
    width = math.max(width or 0, owner:GetWidth(), kind == 'statusbar' and 260 or kind == 'border' and 220 or 120)
    popup:SetWidth(width)
    local top = #items > POPUP_ROWS and 26 or 6
    popup.filter:SetShown(#items > POPUP_ROWS); popup.filter:SetText('')
    for index, row in ipairs(popup.rows) do
        row.stripWidth = 110
        row:ClearAllPoints()
        row:SetPoint('TOPLEFT', 4, -top - (index - 1) * POPUP_ROW); row:SetPoint('TOPRIGHT', -9, -top - (index - 1) * POPUP_ROW)
    end
    popupFilter('')
    -- Start with the current choice in view.
    for index, item in ipairs(popup.view) do
        if item.value == current then popup.offset = index - math.ceil(POPUP_ROWS / 2); break end
    end
    popupRefresh()
    popup:ClearAllPoints(); popup:SetPoint('TOPLEFT', owner, 'BOTTOMLEFT', 0, -3)
    popup:Show()
end
function W:ClosePopup()
    if popup and popup:IsShown() then popup:Hide(); return true end
    return false
end
function W:PopupOwner()
    return popup and popup:IsShown() and popup.owner or nil
end

-- Dropdown face. Set control.getItems(control) -> items, or control.items.
-- kind makes it a media picker whose face and rows preview the item.
function W:Dropdown(parent, width, kind)
    local control = CreateFrame('Button', nil, parent)
    control:SetSize(width, 16)
    control:SetHighlightTexture(WHITE)
    if ns.DarkSkin and ns.DarkSkin.RaisedButton then ns.DarkSkin:RaisedButton(control, 'inner') end
    control.text = self:Label(control, '', BODY); control.text:SetWordWrap(false)
    control.text:SetPoint('LEFT', 6, 0); control.text:SetPoint('RIGHT', -14, 0)
    control.chevron = self:Chevron(control, 8); control.chevron:SetPoint('RIGHT', -4, 0)
    control.kind, control.stripWidth = kind, 48
    local shown = {}
    function control:SetValue(value, label, missing)
        self.value = value
        shown.value, shown.label, shown.missing, shown.plain = value, label or (value ~= nil and tostring(value) or ''), missing, value == nil
        paintPreview(self, self.kind, shown, BODY)
    end
    function control:SetDisabled(disabled)
        if disabled then self:Disable() else self:Enable() end
        dim(self, disabled)
    end
    control:SetScript('OnClick', function(self)
        if W:PopupOwner() == self then W:ClosePopup(); return end
        local items = self.getItems and self:getItems() or self.items
        if items then W:OpenPopup(self, items, self.value, self.kind) end
    end)
    control:SetScript('OnHide', function(self) if W:PopupOwner() == self then W:ClosePopup() end end)
    return control
end
function W:MediaPicker(parent, kind, width)
    local control = self:Dropdown(parent, width, kind)
    function control:getItems() return W:MediaItems(self.kind, self.value, self.allowEmpty, self.emptyLabel) end
    return control
end

-- Colour swatch opening the client's picker. onPreview(control, color) while
-- the picker moves, onCommit(control, color) when it closes with a change,
-- onCancel(control) on Cancel, and onClose(control) always, last. onOpen(control)
-- runs as a session starts.
local picking
local function pickerColor(state)
    local r, g, b = ColorPickerFrame:GetColorRGB()
    local a = nil
    if state.hasAlpha then
        if ColorPickerFrame.GetColorAlpha then a = ColorPickerFrame:GetColorAlpha()
        elseif OpacitySliderFrame then a = 1 - OpacitySliderFrame:GetValue() end
    end
    return { r = r, g = g, b = b, a = a or state.original.a }
end
function W:PickColor(control)
    if not ColorPickerFrame or control.disabled then return end
    local color = control.color or { r = 1, g = 1, b = 1 }
    local state = { control = control, hasAlpha = control.hasAlpha and true or false,
        original = { r = color.r, g = color.g, b = color.b, a = color.a } }
    local function changed()
        if picking ~= state then return end
        state.last = pickerColor(state)
        control:Paint(state.last)
        if control.onPreview then control.onPreview(control, state.last) end
    end
    local function cancelled()
        if picking ~= state then return end
        state.cancelled = true
        control:Paint(state.original)
        if control.onCancel then control.onCancel(control) end
    end
    -- A picker session still open (ours or not) ends before this one starts.
    if W.pickerHooked and ColorPickerFrame:IsShown() then ColorPickerFrame:Hide() end
    if not W.pickerHooked then
        W.pickerHooked = true
        ColorPickerFrame:HookScript('OnHide', function()
            local done = picking
            picking = nil
            if not done then return end
            W:HoldEscape(false)
            if not done.cancelled and done.last and done.control.onCommit then done.control.onCommit(done.control, done.last) end
            if done.control.onClose then done.control.onClose(done.control) end
        end)
    end
    if control.onOpen then control.onOpen(control) end
    W:HoldEscape(true)
    picking = state
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({ r = color.r, g = color.g, b = color.b, opacity = color.a or 1,
            hasOpacity = state.hasAlpha, swatchFunc = changed, opacityFunc = changed, cancelFunc = cancelled })
    else
        -- Older picker: fields on the frame, opacity stored inverted.
        ColorPickerFrame.func, ColorPickerFrame.opacityFunc, ColorPickerFrame.cancelFunc = changed, changed, cancelled
        ColorPickerFrame.hasOpacity, ColorPickerFrame.opacity = state.hasAlpha, 1 - (color.a or 1)
        ColorPickerFrame.previousValues = { color.r, color.g, color.b, color.a }
        ColorPickerFrame:SetColorRGB(color.r, color.g, color.b)
        ColorPickerFrame:Show()
    end
end
function W:Swatch(parent)
    local control = CreateFrame('Button', nil, parent)
    control:SetSize(16, 16)
    face(control)
    -- Checker underlay, visible through a translucent colour.
    for index = 0, 3 do
        local check = control:CreateTexture(nil, 'BORDER')
        check:SetSize(6, 6); check:SetPoint('TOPLEFT', 2 + (index % 2) * 6, -2 - math.floor(index / 2) * 6)
        local shade = (index == 0 or index == 3) and .55 or .25
        check:SetColorTexture(shade, shade, shade, 1)
    end
    local paint = control:CreateTexture(nil, 'ARTWORK')
    paint:SetPoint('TOPLEFT', 2, -2); paint:SetPoint('BOTTOMRIGHT', -2, 2)
    control:SetHighlightTexture(WHITE); control:GetHighlightTexture():SetVertexColor(1, .78, .42, .18)
    control:SetPushedTexture(WHITE); control:GetPushedTexture():SetVertexColor(0, 0, 0, .25)
    rim(control)
    function control:Paint(color)
        paint:SetColorTexture(color.r or 1, color.g or 1, color.b or 1, self.hasAlpha and (color.a or 1) or 1)
    end
    function control:SetValue(color, hasAlpha)
        self.hasAlpha = hasAlpha and true or false
        self.color = color or { r = 1, g = 1, b = 1, a = 1 }
        self:Paint(self.color)
    end
    function control:SetDisabled(disabled)
        if disabled then self:Disable() else self:Enable() end
        dim(self, disabled)
    end
    control:SetScript('OnClick', function(self) W:PickColor(self) end)
    return control
end

-- Collapsible section header: chevron, gold title, rule, and a "Reset" link
-- that appears on hover. onToggle(control), onReset(control).
function W:Section(parent, width)
    local control = CreateFrame('Button', nil, parent)
    control:SetSize(width, 20)
    control.chevron = self:Chevron(control, 8); control.chevron:SetPoint('LEFT', 2, 0)
    control.title = self:Label(control, '', HEAD, GOLD[1], GOLD[2], GOLD[3]); control.title:SetPoint('LEFT', 16, 0)
    local reset = CreateFrame('Button', nil, control)
    reset:SetSize(34, 16); reset:SetPoint('RIGHT', 0, 0)
    reset.text = self:Label(reset, 'Reset', BODY, GREY[1], GREY[2], GREY[3]); reset.text:SetPoint('RIGHT', -2, 0)
    local rule = control:CreateTexture(nil, 'ARTWORK')
    rule:SetColorTexture(GOLD[1] * .78, GOLD[2] * .78, GOLD[3] * .78, .6); rule:SetHeight(1)
    rule:SetPoint('LEFT', control.title, 'RIGHT', 8, 0); rule:SetPoint('RIGHT', reset, 'LEFT', -6, 0)
    control.reset = reset
    local function hover()
        local over = control:IsMouseOver()
        if over then control.title:SetTextColor(HOVER[1], HOVER[2], HOVER[3]); control.chevron:SetColor(HOVER[1], HOVER[2], HOVER[3])
        else control.title:SetTextColor(GOLD[1], GOLD[2], GOLD[3]); control.chevron:SetColor(GOLD[1], GOLD[2], GOLD[3]) end
        reset:SetAlpha(over and control.canReset and 1 or 0)
        if reset:IsMouseOver() and control.canReset then reset.text:SetTextColor(HOVER[1], HOVER[2], HOVER[3])
        else reset.text:SetTextColor(GREY[1], GREY[2], GREY[3]) end
    end
    function control:Set(title, collapsed, canReset)
        self.title:SetText(title); self.canReset = canReset and true or false
        self.chevron:SetDirection(collapsed and 'right' or 'down')
        hover()
    end
    for _, region in ipairs({ control, reset }) do
        region:SetScript('OnEnter', hover); region:SetScript('OnLeave', hover)
    end
    control:SetScript('OnShow', hover)
    control:SetScript('OnMouseDown', function(self) self.title:SetPoint('LEFT', 17, -1) end)
    control:SetScript('OnMouseUp', function(self) self.title:SetPoint('LEFT', 16, 0) end)
    control:SetScript('OnClick', function(self) if self.onToggle then self.onToggle(self) end end)
    reset:SetScript('OnMouseDown', function(self) self.text:SetPoint('RIGHT', -1, -1) end)
    reset:SetScript('OnMouseUp', function(self) self.text:SetPoint('RIGHT', -2, 0) end)
    reset:SetScript('OnClick', function() if control.canReset and control.onReset then control.onReset(control) end end)
    return control
end

-- A row of abutting buttons with one selected (gold text). onPick(control, index).
function W:Segmented(parent)
    local holder = CreateFrame('Frame', nil, parent)
    holder:SetSize(1, 16)
    holder.buttons = {}
    function holder:SetOptions(labels, selected, width)
        width = width or 64
        for index, label in ipairs(labels) do
            local button = self.buttons[index]
            if not button then
                button = W:SmallButton(self, '', width, function(pressed)
                    if holder.onPick then holder.onPick(holder, pressed.index) end
                end)
                button.index = index
                button:SetPoint('LEFT', (index - 1) * width, 0)
                self.buttons[index] = button
            end
            button:SetWidth(width); button:SetText(label)
            if index == selected then button.text:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
            else button.text:SetTextColor(.9, .9, .86) end
            button:Show()
        end
        for index = #labels + 1, #self.buttons do self.buttons[index]:Hide() end
        self:SetWidth(#labels * width)
    end
    return holder
end

-- Search box: placeholder and a clear button. onChanged(control, text), onEnter(control).
function W:SearchBox(parent, width, placeholder)
    local control = self:ValueEdit(parent, width)
    control:SetTextInsets(4, 16, 0, 0)
    local hint = self:Label(control, placeholder or 'Search', BODY, GREY[1], GREY[2], GREY[3]); hint:SetPoint('LEFT', 5, 0)
    local clear = CreateFrame('Button', nil, control)
    clear:SetSize(14, 14); clear:SetPoint('RIGHT', -1, 0)
    clear.text = self:Label(clear, 'x', BODY, GREY[1], GREY[2], GREY[3]); clear.text:SetPoint('CENTER', 0, 1)
    clear:SetScript('OnEnter', function(self) self.text:SetTextColor(HOVER[1], HOVER[2], HOVER[3]) end)
    clear:SetScript('OnLeave', function(self) self.text:SetTextColor(GREY[1], GREY[2], GREY[3]) end)
    clear:SetScript('OnMouseDown', function(self) self.text:SetPoint('CENTER', 1, 0) end)
    clear:SetScript('OnMouseUp', function(self) self.text:SetPoint('CENTER', 0, 1) end)
    clear:SetScript('OnClick', function() control:SetText(''); control:ClearFocus() end)
    control:SetScript('OnEditFocusGained', nil); control:SetScript('OnEditFocusLost', nil)
    control:SetScript('OnTextChanged', function(self)
        local text = self:GetText()
        hint:SetShown(text == ''); clear:SetShown(text ~= '')
        if self.onChanged then self.onChanged(self, text) end
    end)
    control:SetScript('OnEscapePressed', function(self)
        if self:GetText() ~= '' then self:SetText('') else self:ClearFocus() end
    end)
    control:SetScript('OnEnterPressed', function(self)
        self:ClearFocus()
        if self.onEnter then self.onEnter(self) end
    end)
    clear:Hide()
    return control
end

-- Curve editor: one row per point (x, y, remove) and "Add point".
-- SetValue(points, spec) lays it out and sets its height; onCommit(control, points).
function W:Curve(parent, width)
    local holder = CreateFrame('Frame', nil, parent)
    holder:SetSize(width, 16)
    holder.rows, holder.points, holder.spec = {}, {}, {}
    holder.xLabel = self:Label(holder, '', BODY, GREY[1], GREY[2], GREY[3]); holder.xLabel:SetPoint('TOPLEFT', 0, -3)
    holder.yLabel = self:Label(holder, '', BODY, GREY[1], GREY[2], GREY[3]); holder.yLabel:SetPoint('TOPLEFT', 72, -3)
    local function gather(skip)
        local points = {}
        for index = 1, #holder.points do
            if index ~= skip then
                local row = holder.rows[index]
                local x, y = tonumber((row.x:GetText():gsub(',', '.'))), tonumber((row.y:GetText():gsub(',', '.')))
                points[#points + 1] = { x = x or holder.points[index].x, y = y or holder.points[index].y }
            end
        end
        return points
    end
    local function commit(points) if holder.onCommit then holder.onCommit(holder, points) end end
    local function edited() commit(gather()) end
    holder.add = self:SmallButton(holder, 'Add point', 64, function()
        local points = gather()
        local last, spec = points[#points], holder.spec
        local x = last and last.x + (spec.step or 1) or spec.xMin or 0
        if spec.xMax and x > spec.xMax then x = spec.xMax end
        points[#points + 1] = { x = x, y = last and last.y or spec.yMin or 0 }
        commit(points)
    end)
    function holder:SetValue(points, spec)
        self.spec = spec or self.spec
        self.points = type(points) == 'table' and points or {}
        self.xLabel:SetText(self.spec.xLabel or 'At'); self.yLabel:SetText(self.spec.yLabel or 'Value')
        for index, point in ipairs(self.points) do
            local row = self.rows[index]
            if not row then
                row = CreateFrame('Frame', nil, self)
                row:SetSize(width, 16); row:SetPoint('TOPLEFT', 0, -16 - (index - 1) * 20)
                row.x = W:ValueEdit(row, 56); row.x:SetPoint('LEFT', 0, 0); row.x.onCommit = edited
                row.arrow = W:Chevron(row, 8); row.arrow:SetPoint('LEFT', 60, 0); row.arrow:SetDirection('right')
                row.y = W:ValueEdit(row, 56); row.y:SetPoint('LEFT', 72, 0); row.y.onCommit = edited
                row.remove = W:SmallButton(row, 'Remove', 52, function(button) commit(gather(button.index)) end)
                row.remove:SetPoint('LEFT', 136, 0); row.remove.index = index
                self.rows[index] = row
            end
            row.x:SetStored(tostring(point.x)); row.y:SetStored(tostring(point.y))
            row.x:SetDisabled(self.disabled); row.y:SetDisabled(self.disabled)
            row.remove:SetDisabled(self.disabled or #self.points <= (self.spec.minPoints or 1))
            row:Show()
        end
        for index = #self.points + 1, #self.rows do self.rows[index]:Hide() end
        self.add:ClearAllPoints(); self.add:SetPoint('TOPLEFT', 0, -16 - #self.points * 20)
        self.add:SetDisabled(self.disabled)
        self:SetHeight(16 + #self.points * 20 + 16)
    end
    function holder:SetDisabled(disabled)
        self.disabled = disabled and true or false
    end
    return holder
end

-- List editor: one row per item with "Remove", then a box and "Add".
-- SetItems({ { key =, label = }, ... }); onAdd(control, text), onRemove(control, key).
function W:ListEditor(parent, width)
    local holder = CreateFrame('Frame', nil, parent)
    holder:SetSize(width, 16)
    holder.rows = {}
    holder.entry = self:ValueEdit(holder, 120)
    local function add()
        local text = holder.entry:GetText():gsub('^%s+', ''):gsub('%s+$', '')
        holder.entry:SetText(''); holder.entry.stored = ''
        if text ~= '' and holder.onAdd then holder.onAdd(holder, text) end
    end
    holder.entry.onCommit = nil
    holder.entry:SetScript('OnEnterPressed', add)
    holder.add = self:SmallButton(holder, 'Add', 40, add)
    function holder:SetItems(items)
        items = type(items) == 'table' and items or {}
        for index, item in ipairs(items) do
            local row = self.rows[index]
            if not row then
                row = CreateFrame('Frame', nil, self)
                row:SetSize(width, 16); row:SetPoint('TOPLEFT', 0, -(index - 1) * 18)
                row.label = W:Label(row, '', BODY); row.label:SetPoint('LEFT', 4, 0); row.label:SetWidth(width - 64); row.label:SetWordWrap(false)
                row.remove = W:SmallButton(row, 'Remove', 52, function(button)
                    if holder.onRemove then holder.onRemove(holder, button.key) end
                end)
                row.remove:SetPoint('RIGHT', 0, 0)
                self.rows[index] = row
            end
            row.label:SetText(tostring(item.label or item.key)); row.remove.key = item.key
            row.remove:SetDisabled(self.disabled)
            row:Show()
        end
        for index = #items + 1, #self.rows do self.rows[index]:Hide() end
        self.entry:ClearAllPoints(); self.entry:SetPoint('TOPLEFT', 0, -#items * 18)
        self.add:ClearAllPoints(); self.add:SetPoint('LEFT', self.entry, 'RIGHT', 6, 0)
        self.entry:SetDisabled(self.disabled); self.add:SetDisabled(self.disabled)
        self:SetHeight(#items * 18 + 16)
    end
    function holder:SetDisabled(disabled)
        self.disabled = disabled and true or false
    end
    return holder
end
