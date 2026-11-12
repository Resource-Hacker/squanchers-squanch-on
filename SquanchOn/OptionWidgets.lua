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
