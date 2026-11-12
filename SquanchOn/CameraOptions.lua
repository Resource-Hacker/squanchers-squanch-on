-- SPDX-License-Identifier: MIT
-- Settings page for Squanch-On's camera (/sqms camera options). Every edit is
-- applied at once; curve and situation rows are rebuilt when their shape changes.
local _, ns = ...
local Options = {}
ns.CameraOptions = Options
local BODY, LABEL, X, ROW = 590, 250, 262, 23
local GREY = {.62, .62, .6}
local GROUPS = {
    {'shoulder', 'Shoulder offset'},
    {'fov', 'Field of view'},
    {'zoom', 'Zoom'},
    {'head', 'Head movement'},
    {'pitch', 'Dynamic pitch', 'Moves the aim point relative to the reticle; it is off by default for aim stability.'},
    {'focus', 'Target focus (enemy / interact)', 'Turns the camera toward the target, which moves the aim point relative to the reticle.'},
    {'speeds', 'Speeds'},
}
local ZOOM_ROWS = {
    {'Eased wheel zoom', 'reactive', 'check'},
    {'Extra yards per wheel notch (1 + this)', 'addAlways', 'number', 0, 10},
    {'Further yards while behind the target', 'addIncrements', 'number', 0, 10},
    {'... when behind by more than (yards)', 'incAddDifference', 'number', 0.1, 10},
    {'Longest ease time (seconds)', 'maxZoomTime', 'number', 0, 5},
    {'Wheel easing', 'easing', 'choice', ns.Camera.EASINGS},
    {'Restore zoom after a situation', 'restore', 'choice', {'never', 'adaptive', 'always'}},
    {'Situation transition easing', 'transitionEasing', 'choice', ns.Camera.EASINGS},
}

local function fmt(value)
    if value == nil then return '' end
    local text = ('%.4f'):format(value):gsub('0+$', ''):gsub('%.$', '')
    return text
end

-- Controls are reused between redraws.
local pools, counts = {}, {}
local function acquire(kind, create)
    local pool = pools[kind] or {}
    pools[kind] = pool
    local index = (counts[kind] or 0) + 1
    counts[kind] = index
    local item = pool[index]
    if not item then item = create(); pool[index] = item end
    item:Show()
    return item
end
function Options:Place(control, x, y)
    control:ClearAllPoints(); control:SetPoint('TOPLEFT', self.body, 'TOPLEFT', x, -y)
end
function Options:Text(x, y, text, width, color)
    local W = ns.OptionWidgets
    local label = acquire('label', function()
        local font = W:Label(self.body, '', 10); font:SetJustifyV('MIDDLE'); font:SetWordWrap(false)
        return font
    end)
    color = color or {.9, .9, .86}
    label:SetTextColor(color[1], color[2], color[3]); label:SetSize(width, ROW - 3); label:SetText(text)
    self:Place(label, x, y)
    return label
end
function Options:Header(title, note)
    local W = ns.OptionWidgets
    if self.y > 0 then self.y = self.y + 10 end
    local header = acquire('header', function()
        local font = W:Header(self.body, '')
        font.rule = self.body:CreateTexture(nil, 'ARTWORK'); font.rule:SetColorTexture(.70, .532, .294, .6); font.rule:SetHeight(1)
        return font
    end)
    header:SetText(title); self:Place(header, 0, self.y + 4)
    header.rule:ClearAllPoints(); header.rule:Show()
    header.rule:SetPoint('TOPLEFT', self.body, 'TOPLEFT', 0, -self.y - 22); header.rule:SetPoint('TOPRIGHT', self.body, 'TOPRIGHT', 0, -self.y - 22)
    self.y = self.y + 28
    if note then self:Text(8, self.y, note, BODY - 16, GREY); self.y = self.y + ROW end
end
function Options:Number(x, y, width, value, set, low, high, redraw)
    local W = ns.OptionWidgets
    local edit = acquire('edit', function()
        local control = W:Edit(self.body, 70); control:SetHeight(20)
        control:SetScript('OnEditFocusLost', function(box) if box.commit and box:IsShown() then box.commit(box:GetText()) end end)
        return control
    end)
    edit.commit = nil
    edit:SetWidth(width); edit:SetText(fmt(value)); edit:SetCursorPosition(0)
    edit.shown = edit:GetText()
    edit.commit = function(text)
        if text == edit.shown then return end
        local number = tonumber(text)
        if not number or number ~= number or (low and number < low) or (high and number > high) then
            edit:SetText(edit.shown)
            self:Message(low and ('Enter a number of at least ' .. fmt(low) .. (high and ', at most ' .. fmt(high) or '') .. '.') or 'Enter a number.')
            return
        end
        edit.shown = text
        set(number); self:Changed(redraw)
    end
    self:Place(edit, x, y)
    return edit
end
function Options:Check(x, y, checked, set, redraw)
    local W = ns.OptionWidgets
    local check = acquire('check', function()
        local control = W:Check(self.body)
        control:SetScript('OnClick', function(box) if box.commit then box.commit(box:GetChecked() and true or false) end end)
        return control
    end)
    check:SetChecked(checked and true or false)
    check.commit = function(on) set(on); self:Changed(redraw) end
    self:Place(check, x, y + 1)
    return check
end
function Options:Button(x, y, width, text, click)
    local W = ns.OptionWidgets
    local button = acquire('button', function()
        return W:Button(self.body, '', 60, function(control) if control.click then control.click() end end, 20)
    end)
    button:SetWidth(width); button:SetText(text); button.click = click
    self:Place(button, x, y + 1)
    return button
end
function Options:Choice(x, y, width, list, value, set, redraw)
    return self:Button(x, y, width, tostring(value), function()
        local index = 0
        for i, item in ipairs(list) do if item == value then index = i end end
        set(list[index % #list + 1]); self:Changed(redraw == nil or redraw)
    end)
end
-- A labelled row for one field of a plain table.
function Options:Field(indent, label, target, key, kind, low, high)
    local y = self.y
    self:Text(8 + indent, y, label, LABEL - indent)
    if kind == 'check' then self:Check(X, y, target[key], function(on) target[key] = on end)
    elseif kind == 'choice' then self:Choice(X, y, 110, low, target[key], function(item) target[key] = item end)
    else self:Number(X, y, 70, target[key], function(number) target[key] = number end, low, high) end
    self.y = y + ROW
end
-- One camera setting: value, optional zoom curve, optional Remove (situation overrides).
function Options:Setting(def, entries, indent, removable)
    local Camera = ns.Camera
    local entry, y = entries[def.name], self.y
    self:Text(8 + indent, y, def.label, LABEL - indent)
    if def.toggle then
        self:Check(X, y, (entry.value or 0) ~= 0, function(on) entry.value = on and 1 or 0 end)
    else
        self:Number(X, y, 70, entry.value, function(number) entry.value = number end, def.min, def.clampFixed and def.max or nil)
    end
    if def.min then
        self:Check(X + 84, y, entry.curveOn, function(on)
            entry.curveOn = on
            if on and not (entry.curve and #entry.curve >= 2) then
                local value = entry.value or Camera.Resolve(def.name, 0) or 0
                entry.curve = {{zoom = 0, value = value}, {zoom = 25, value = value}}
            end
        end, true)
        self:Text(X + 110, y, entry.curveOn and 'follows zoom:' or (entry.curve and 'follow zoom (curve kept)' or 'follow zoom'), 150, GREY)
    end
    if removable then self:Button(BODY - 70, y, 66, 'Remove', function() entries[def.name] = nil; self:Changed(true) end) end
    self.y = y + ROW
    if not (def.min and entry.curveOn and entry.curve) then return end
    for index, point in ipairs(entry.curve) do
        y = self.y
        self:Text(X - 76, y, 'at zoom', 60, GREY)
        self:Number(X, y, 50, point.zoom, function(number) point.zoom = number end, 0, 50, true)
        self:Text(X + 62, y, 'value', 40, GREY)
        self:Number(X + 104, y, 60, point.value, function(number) point.value = number end, def.min, def.max)
        if #entry.curve > 2 then
            self:Button(X + 174, y, 22, 'x', function() table.remove(entry.curve, index); self:Changed(true) end)
        end
        self.y = y + ROW
    end
    self:Button(X, self.y, 80, '+ point', function()
        local last = entry.curve[#entry.curve]
        entry.curve[#entry.curve + 1] = {zoom = math.min(50, last.zoom + 5), value = last.value}
        self:Changed(true)
    end)
    self.y = self.y + ROW + 4
end
function Options:Situation(situation)
    local Camera = ns.Camera
    local y, open = self.y, self.selected == situation
    self:Check(8, y, situation.enabled, function(on) situation.enabled = on end, true)
    local status = Camera:SituationStatus(situation)
    self:Text(36, y, situation.name .. (status ~= '' and '  (' .. status .. ')' or ''), 330,
        (not situation.condition or not situation.enabled) and GREY or nil)
    self:Text(372, y, 'priority ' .. fmt(situation.priority), 100, GREY)
    self:Button(BODY - 70, y, 66, open and 'Close' or 'Edit', function()
        self.selected = not open and situation or nil; self:Redraw()
    end)
    self.y = y + ROW
    if not open then return end
    self:Text(36, self.y, 'When: ' .. Camera:ConditionText(situation), BODY - 44, GREY); self.y = self.y + ROW
    self:Field(28, 'Priority (highest active wins)', situation, 'priority', 'number', -1000, 10000)
    self:Field(28, 'Leave delay (seconds)', situation, 'delay', 'number', 0, 600)
    self:Field(28, 'Transition time entering (seconds)', situation, 'enter', 'number', 0, 60)
    self:Field(28, 'Transition time leaving (seconds)', situation, 'exit', 'number', 0, 60)
    local zoom, rotation, hide = situation.zoom, situation.rotation, situation.hideUI
    self:Field(28, 'Zoom action', zoom, 'enabled', 'check')
    self:Field(48, 'Use', zoom, 'mode', 'choice', {'zoom', 'view'})
    if zoom.mode == 'zoom' then
        self:Field(48, 'Zoom rule', zoom, 'type', 'choice', {'set', 'in', 'out', 'range'})
        if zoom.type == 'range' then
            self:Field(48, 'Nearest zoom', zoom, 'min', 'number', 0, 50)
            self:Field(48, 'Farthest zoom', zoom, 'max', 'number', 0, 50)
        else self:Field(48, 'Zoom value', zoom, 'value', 'number', 0, 50) end
        self:Field(48, 'Transition time is only a maximum', zoom, 'timeIsMax', 'check')
    else
        self:Field(48, 'Saved view number', zoom, 'view', 'number', 1, 5)
        self:Field(48, 'Return to the previous view after', zoom, 'viewRestore', 'check')
        self:Field(48, 'Switch instantly', zoom, 'viewInstant', 'check')
    end
    self:Field(28, 'Rotation action', rotation, 'enabled', 'check')
    self:Field(48, 'Kind', rotation, 'type', 'choice', {'continuous', 'degrees'})
    if rotation.type == 'continuous' then self:Field(48, 'Degrees per second', rotation, 'speed', 'number', -360, 360)
    else
        self:Field(48, 'Yaw degrees (right +)', rotation, 'yaw', 'number', -1440, 1440)
        self:Field(48, 'Pitch degrees (up +)', rotation, 'pitch', 'number', -90, 90)
    end
    self:Field(48, 'Rotate back when leaving', rotation, 'back', 'check')
    self:Field(28, 'Fade the interface', hide, 'enabled', 'check')
    self:Field(48, 'Interface opacity while active', hide, 'fadeOpacity', 'number', 0, 1)
    self:Text(36, self.y, 'Settings this situation overrides:', BODY - 44, GREY); self.y = self.y + ROW
    local free = {}
    for _, def in ipairs(Camera.SETTINGS) do
        if situation.overrides[def.name] then self:Setting(def, situation.overrides, 28, true) else free[#free + 1] = def end
    end
    if #free > 0 then
        local index = self.pick or 1
        if index > #free then index = 1 end
        local pick = free[index]
        y = self.y
        self:Button(36, y, 300, pick.label, function() self.pick = index % #free + 1; self:Redraw() end)
        self:Button(344, y, 110, 'Add override', function()
            situation.overrides[pick.name] = {value = Camera:Config().standard[pick.name].value or 0}
            self.pick = nil; self:Changed(true)
        end)
        self.y = y + ROW + 6
    end
end
function Options:Draw()
    local Camera = ns.Camera
    local cfg = Camera:Config()
    if not cfg then return end
    for kind, pool in pairs(pools) do
        counts[kind] = 0
        for _, item in ipairs(pool) do
            item:Hide()
            if item.rule then item.rule:Hide() end
        end
    end
    self.y = 0
    for _, group in ipairs(GROUPS) do
        self:Header(group[2], group[3])
        for _, def in ipairs(Camera.SETTINGS) do
            if def.group == group[1] then self:Setting(def, cfg.standard, 0) end
        end
        if group[1] == 'zoom' then
            for _, row in ipairs(ZOOM_ROWS) do self:Field(0, row[1], cfg.zoom, row[2], row[3], row[4], row[5]) end
        end
    end
    self:Header('Situations', 'The highest-priority enabled situation that applies overrides the settings above.')
    for _, situation in ipairs(cfg.situations) do self:Situation(situation) end
    self.body:SetHeight(math.max(1, self.y + 8))
    self.scroll.Refresh()
    self.toggle:SetText(cfg.enabled and 'Turn camera off' or 'Turn camera on')
end
function Options:Redraw()
    if self.pending then return end
    self.pending = true
    -- Next frame: the control whose handler asked for this is done by then.
    C_Timer.After(0, function()
        self.pending = nil
        if self.frame and self.frame:IsShown() then self:Draw() end
    end)
end
function Options:Changed(redraw)
    ns.Camera:SettingsChanged()
    self:Message(ns.Camera.active and 'Applied.' or 'Saved. The camera is not driving right now (/sqms camera).')
    if redraw then self:Redraw() end
end
function Options:Message(text) self.message:SetText(text or '') end
function Options:Build()
    if self.frame then return self.frame end
    local W, Camera = ns.OptionWidgets, ns.Camera
    local frame = W:Window('SquanchOnCameraOptions', 660, 640, 'Squanch-On · Camera')
    local scroll, body = W:Scroll(frame)
    scroll:SetPoint('TOPLEFT', 22, -50); scroll:SetPoint('BOTTOMRIGHT', -30, 56)
    body:SetSize(BODY, 1)
    self.scroll, self.body = scroll, body
    self.message = W:Label(frame, '', 10); self.message:SetPoint('BOTTOMLEFT', 18, 16); self.message:SetSize(250, 24)
    self.message:SetJustifyV('MIDDLE')
    local defaults = W:Button(frame, 'Shipped defaults', 120, function()
        Camera:Reset(); self.selected = nil; self:Message('Shipped defaults loaded.'); self:Redraw()
    end)
    defaults:SetPoint('BOTTOMRIGHT', -18, 16)
    self.toggle = W:Button(frame, '', 120, function()
        Camera:Command(Camera:Config().enabled and 'off' or 'on'); self:Redraw()
    end)
    self.toggle:SetPoint('RIGHT', defaults, 'LEFT', -8, 0)
    local status = W:Button(frame, 'Status', 70, function() Camera:Command('status') end)
    status:SetPoint('RIGHT', self.toggle, 'LEFT', -8, 0)
    self.frame = frame
    return frame
end
function ns:OpenCameraOptions()
    if not ns.Camera or not ns.Camera:Config() then return false end
    Options:Build():Show(); Options:Draw()
    return true
end
