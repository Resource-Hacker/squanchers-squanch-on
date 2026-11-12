-- SPDX-License-Identifier: MIT
-- Squancher's edit surface uses physical pixels; existing modules own real UI.
local _, ns = ...
local Editor = { specs = {}, handles = {}, rows = {}, undo = {}, grid = 10, stream = true }
ns.LayoutEditor = Editor

function Editor:Copy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, item in pairs(value) do copy[key] = self:Copy(item) end
    return copy
end

-- WoW frame coordinates are floats. Treat sub-.001px drift at a half-pixel
-- boundary as a tie, choosing the adjacent 5px grid size when there is one.
-- The native geometry stays unchanged; preview, readout and validation agree.
function Editor:RoundPhysicalSize(value)
    local lower = math.floor(value)
    if math.abs(value - lower - .5) <= .001 then
        if lower % 5 == 0 then return lower end
        if (lower + 1) % 5 == 0 then return lower + 1 end
    end
    return math.floor(value + .5)
end

function Editor:Metrics()
    local width, height = GetPhysicalScreenSize()
    return width, height, width / UIParent:GetWidth(), height / UIParent:GetHeight()
end

function Editor:Rect(frame)
    if not frame then return end
    local left, bottom, width, height = frame:GetRect()
    if not left or not bottom or not width or not height or width <= 1 or height <= 1 then return end
    local _, ph, ux, uy = self:Metrics()
    local scaleOwner = frame.GetEffectiveScale and frame or frame:GetParent()
    local scale = scaleOwner:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return { x = left * scale * ux, y = ph - (bottom + height) * scale * uy,
        w = width * scale * ux, h = height * scale * uy }
end

-- Visible edit geometry is separate from the native owner's saved rectangle.
-- Explicit roots keep unrelated castbars, auras and detached controls out.
function Editor:Bounds(spec, frame)
    frame = frame or spec.getFrame()
    local native = self:Rect(frame)
    if not native then return end
    local bounds = self:Copy(native)
    local function include(border, insetX, insetY)
        local rect = self:Rect(border)
        if not rect then return end
        insetX, insetY = insetX * rect.w / border:GetWidth(), insetY * rect.h / border:GetHeight()
        local right, bottom = math.max(bounds.x+bounds.w, rect.x+rect.w-insetX), math.max(bounds.y+bounds.h, rect.y+rect.h-insetY)
        bounds.x, bounds.y = math.min(bounds.x, rect.x+insetX), math.min(bounds.y, rect.y+insetY)
        bounds.w, bounds.h = right-bounds.x, bottom-bounds.y
    end
    if ns.DarkSkin then
        local roots = spec.getBoundsFrames and spec.getBoundsFrames(frame) or { frame }
        for _, root in ipairs(roots) do ns.DarkSkin:VisitLayoutBorders(root, include) end
    end
    return bounds, native
end

function Editor:NativeRect(spec, rect, resizing)
    local bounds, native = self:Bounds(spec)
    if not bounds then return end
    local left, top = native.x-bounds.x, native.y-bounds.y
    local horizontal, vertical = bounds.w-native.w, bounds.h-native.h
    local sx, sy = 1, 1
    if resizing and spec.resize == "scale" and spec.fixedBorderSize ~= true then
        sx, sy = rect.w/bounds.w, rect.h/bounds.h
    end
    return { x = rect.x+left*sx, y = rect.y+top*sy,
        w = rect.w-horizontal*sx, h = rect.h-vertical*sy }
end

function Editor:Place(frame, rect)
    if InCombatLockdown() then return end
    local _, ph, ux, uy = self:Metrics()
    local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local clear = frame.ClearAllPointsBase or frame.ClearAllPoints
    local point = frame.SetPointBase or frame.SetPoint
    clear(frame)
    point(frame, "TOPLEFT", UIParent, "BOTTOMLEFT",
        rect.x / ux / scale, (ph - rect.y) / uy / scale)
end

function Editor:Size(frame, width, height)
    if InCombatLockdown() then return end
    local _, _, ux, uy = self:Metrics()
    local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    frame:SetSize(width / ux / scale, height / uy / scale)
end

function Editor:ScaleToWidth(frame, width)
    if InCombatLockdown() then return end
    local rect = self:Rect(frame)
    if rect then (frame.SetScaleBase or frame.SetScale)(frame, frame:GetScale() * width / rect.w) end
end

function Editor:Read(id)
    local layout = ns.db and ns.db.layout
    return layout and layout.targets and layout.targets[id]
end

function Editor:Store(id, rect)
    if not ns.db then return end
    if not ns.db.layout and not rect then return end
    ns.db.layout = ns.db.layout or { version = 1, targets = {} }
    ns.db.layout.targets = ns.db.layout.targets or {}
    ns.db.layout.targets[id] = self:Copy(rect)
end

function Editor:Register(spec)
    self.specs[spec.id] = spec
end

function Editor:Snap(value, origin)
    origin = origin or 0
    return origin + math.floor((value - origin) / self.grid + 0.5) * self.grid
end

function Editor:SnapPosition(x, y)
    local pw, ph = self:Metrics()
    return self:Snap(x, pw / 2), self:Snap(y, ph / 2)
end

function Editor:SnapSize(value, minimum, maximum)
    local low, high = math.ceil(minimum / 5) * 5, math.floor(maximum / 5) * 5
    if low > high then return end
    return math.max(low, math.min(math.floor(value / 5 + .5) * 5, high))
end

function Editor:SnapScale(width, ratio, minWidth, maxWidth, heightOffset)
    heightOffset = heightOffset or 0
    -- Uniform scaling can produce fractional physical extents. Search the 5px
    -- readout bins for a scale whose real width AND height round into those bins;
    -- do not stretch the frame or round its labels independently of its geometry.
    local epsilon, best, distance = .01, nil, math.huge
    local first = math.max(5, math.ceil((minWidth - .5 + epsilon) / 5) * 5)
    local last = math.floor((maxWidth + .5 - epsilon) / 5) * 5
    for bin = first, last, 5 do
        local low = math.max(minWidth, bin - .5 + epsilon)
        local high = math.min(maxWidth, bin + .5 - epsilon)
        if low <= high then
            local firstHeight = math.max(5, math.ceil((low / ratio + heightOffset - .5 + epsilon) / 5) * 5)
            local lastHeight = math.floor((high / ratio + heightOffset + .5 - epsilon) / 5) * 5
            if firstHeight <= lastHeight then
                local height = math.max(firstHeight, math.min(math.floor((width / ratio + heightOffset) / 5 + .5) * 5, lastHeight))
                local start = math.max(low, (height - heightOffset - .5 + epsilon) * ratio)
                local finish = math.min(high, (height - heightOffset + .5 - epsilon) * ratio)
                if start <= finish then
                    local candidate = math.max(start, math.min(width, finish))
                    local delta = math.abs(candidate - width)
                    if delta < distance then best, distance = candidate, delta end
                end
            end
        end
    end
    if best then return best, best / ratio + heightOffset end
end

function Editor:Cursor()
    local x, y = GetCursorPosition()
    local _, ph, ux, uy = self:Metrics()
    local scale = UIParent:GetEffectiveScale()
    return x / scale * ux, ph - y / scale * uy
end

local function label(parent, text, size)
    local font = parent:CreateFontString(nil, "OVERLAY")
    font:SetFont(STANDARD_TEXT_FONT, size or 8, "")
    font:SetTextColor(.9, .93, .96)
    font:SetText(text)
    return font
end

local function fill(parent, r, g, b, a)
    local texture = parent:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints(); texture:SetColorTexture(r, g, b, a)
    return texture
end

local function outline(parent, r, g, b, a, size)
    local edges = {}
    for i = 1, 4 do
        local edge = parent:CreateTexture(nil, "BORDER")
        edge:SetColorTexture(r, g, b, a)
        edges[i] = edge
    end
    edges[1]:SetPoint("TOPLEFT"); edges[1]:SetPoint("TOPRIGHT"); edges[1]:SetHeight(size or 1)
    edges[2]:SetPoint("BOTTOMLEFT"); edges[2]:SetPoint("BOTTOMRIGHT"); edges[2]:SetHeight(size or 1)
    edges[3]:SetPoint("TOPLEFT"); edges[3]:SetPoint("BOTTOMLEFT"); edges[3]:SetWidth(size or 1)
    edges[4]:SetPoint("TOPRIGHT"); edges[4]:SetPoint("BOTTOMRIGHT"); edges[4]:SetWidth(size or 1)
    return edges
end

local function button(parent, text, width, callback)
    local control = CreateFrame("Button", nil, parent)
    control:SetSize(width, 28)
    control.text = label(control, text, 8); control.text:SetPoint("CENTER")
    control:SetHighlightTexture([[Interface\Buttons\WHITE8X8]])
    ns.DarkSkin:RaisedButton(control, "inner")
    control:SetScript("OnClick", callback)
    return control
end

function Editor:Message(text)
    if self.status then self.status:SetText(text) end
end

function Editor:Build()
    if self.root then return end
    local root = CreateFrame("Frame", "SquancherLayoutEditor", UIParent)
    self.root = root
    root:Hide(); root:SetFrameStrata("DIALOG"); root:SetFrameLevel(100)
    root:EnableMouse(true); root:EnableKeyboard(true); root:SetPropagateKeyboardInput(true)
    root:SetScript("OnHide", function() if self.active then self:Close() end end)
    root:SetScript("OnKeyDown", function(frame, key)
        if self.widthEdit and self.widthEdit:HasFocus() then
            frame:SetPropagateKeyboardInput(false)
            return
        end
        local handled = key == "ESCAPE" or (key == "Z" and IsControlKeyDown())
        local directions = { LEFT = {-10, 0}, RIGHT = {10, 0}, UP = {0, -10}, DOWN = {0, 10} }
        if self.selected and directions[key] then handled = true end
        frame:SetPropagateKeyboardInput(not handled)
        if key == "ESCAPE" then self:Close()
        elseif key == "Z" and IsControlKeyDown() then self:Undo()
        elseif self.selected and directions[key] and not self.drag then
            local spec = self.specs[self.selected]
            local rect = spec and self:Bounds(spec)
            if rect then
                -- Nudge from the current position so a centered fractional edge
                -- stays centered on its grid phase when moved back again.
                rect.x, rect.y = rect.x + directions[key][1], rect.y + directions[key][2]
                self:Commit(self.selected, self:Clamp(rect), false)
            end
        end
    end)
    UISpecialFrames[#UISpecialFrames + 1] = "SquancherLayoutEditor"
    self.lines = {}
    self.alignmentLines = {}
    self.alignmentGuide = CreateFrame("Frame", nil, root)
    self.alignmentGuide:SetAllPoints(root); self.alignmentGuide:SetFrameLevel(125)
    self.alignmentGuide:EnableMouse(false)
    self.centerLine = self.alignmentGuide:CreateTexture(nil, "BACKGROUND")
    self.centerLine:SetColorTexture(1, .12, .12, .95)
    self.sizeHint = CreateFrame("Frame", nil, root)
    self.sizeHint:SetFrameLevel(140); self.sizeHint:EnableMouse(false)
    self.sizeHint:SetClampedToScreen(true)
    fill(self.sizeHint, .035, .035, .035, .96)
    ns.DarkSkin:SmallBorder(self.sizeHint)
    self.sizeHint.text = label(self.sizeHint, "", 12)
    self.sizeHint.text:SetPoint("CENTER")
    self.sizeHint:Hide()
    self.shades = {}
    for i = 1, 4 do
        local shade = root:CreateTexture(nil, "BACKGROUND", nil, -7)
        shade:SetColorTexture(0, 0, 0, .43); self.shades[i] = shade
    end
    self.guide = CreateFrame("Frame", nil, root)
    self.guide:SetFrameLevel(101); self.guide:EnableMouse(false)
    outline(self.guide, 1, .74, .3, .95, 2)
    self.guideTitle = label(self.guide, "", 12)
    self.guideTitle:SetPoint("BOTTOM", self.guide, "BOTTOM", 0, 12)

    local toolbar = CreateFrame("Frame", nil, root)
    toolbar:SetSize(940, 134); toolbar:SetPoint("TOP", root, "TOP", 0, -14)
    toolbar:SetFrameLevel(130); toolbar:EnableMouse(true)
    local toolbarBorder = ns.DarkSkin:Panel(toolbar, "dialog", 0)
    local toolbarBackground = fill(toolbar, 0, 0, 0, 0)
    ns.DarkSkin:StylePanelBackground(toolbarBackground, toolbarBorder)
    local title = label(toolbar, "Squancher Layout  |  10 × 10 px", 12)
    title:SetPoint("TOPLEFT", 14, -12)
    local done = button(toolbar, "Done", 76, function() self:Close() end)
    done:SetPoint("TOPRIGHT", -12, -10)
    local undo = button(toolbar, "Undo", 76, function() self:Undo() end)
    undo:SetPoint("RIGHT", done, "LEFT", -8, 0)
    local options = button(toolbar, "Unit-frame settings", 160, function() self:Close(); ns:OpenOptions("unitframes") end)
    options:SetPoint("RIGHT", undo, "LEFT", -8, 0)
    self.guideToggle = button(toolbar, "16:9 guide: On", 140, function()
        self.stream = not self.stream; self:DrawCanvas()
    end)
    self.guideToggle:SetPoint("TOPLEFT", 14, -49)
    local help = label(toolbar, "Drag a box • Resize a bottom corner • Arrow keys: 10 px • Ctrl+Z: undo", 8)
    help:SetPoint("LEFT", self.guideToggle, "RIGHT", 14, 0)
    local widthLabel = label(toolbar, "Width (px)", 8)
    widthLabel:SetPoint("TOPLEFT", 14, -101)
    local widthEdit = CreateFrame("EditBox", nil, toolbar, "InputBoxTemplate")
    self.widthEdit = widthEdit
    widthEdit:SetSize(72, 28); widthEdit:SetPoint("LEFT", widthLabel, "RIGHT", 12, 0)
    widthEdit:SetAutoFocus(false); widthEdit:SetNumeric(true); widthEdit:SetMaxLetters(5)
    widthEdit:SetScript("OnEscapePressed", function(frame) frame:ClearFocus() end)
    widthEdit:SetScript("OnEnterPressed", function() self:ApplyWidth() end)
    widthEdit:SetScript("OnEditFocusGained", function() self.root:SetPropagateKeyboardInput(false) end)
    widthEdit:SetScript("OnEditFocusLost", function() self.root:SetPropagateKeyboardInput(true) end)
    widthEdit:SetScript("OnKeyDown", function(frame) frame:SetPropagateKeyboardInput(false) end)
    local applyWidth = button(toolbar, "Apply", 70, function() self:ApplyWidth() end)
    applyWidth:SetPoint("LEFT", widthEdit, "RIGHT", 12, 0)
    local center = button(toolbar, "Center X", 94, function() self:CenterX() end)
    center:SetPoint("LEFT", applyWidth, "RIGHT", 8, 0)
    local widthHelp = label(toolbar, "Exact painted width • Proportional height for scaled elements", 8)
    widthHelp:SetPoint("LEFT", center, "RIGHT", 14, 0)
    self.status = label(root, "", 8)
    self.status:SetPoint("TOP", toolbar, "BOTTOM", 0, -12)

    local sidebar = CreateFrame("Frame", nil, root)
    sidebar:SetPoint("TOPLEFT", 16, -166); sidebar:SetSize(250, 640)
    sidebar:SetFrameLevel(130); sidebar:EnableMouse(true)
    local sidebarBorder = ns.DarkSkin:Panel(sidebar, "dialog", 0)
    local sidebarBackground = fill(sidebar, 0, 0, 0, 0)
    ns.DarkSkin:StylePanelBackground(sidebarBackground, sidebarBorder)
    local heading = label(sidebar, "Select an element", 12); heading:SetPoint("TOPLEFT", 12, -12)
    self.list = CreateFrame("ScrollFrame", nil, sidebar, "UIPanelScrollFrameTemplate")
    self.list:SetPoint("TOPLEFT", 8, -38); self.list:SetPoint("BOTTOMRIGHT", -28, 10)
    self.listChild = CreateFrame("Frame", nil, self.list)
    self.listChild:SetSize(210, 1); self.list:SetScrollChild(self.listChild)
    self.sidebar = sidebar
end

function Editor:DrawCanvas()
    local pw, ph, ux = self:Metrics()
    self.root:SetScale(1 / ux)
    self.root:ClearAllPoints(); self.root:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT")
    self.root:SetSize(pw, ph)
    self.centerLine:ClearAllPoints(); self.centerLine:SetPoint("TOP", self.root, "TOP")
    self.centerLine:SetSize(2, ph)
    self.sidebar:SetHeight(math.min(760, ph - 190))
    local index = 0
    local function line(x, y, width, height, major)
        index = index + 1
        local texture = self.lines[index]
        if not texture then texture = self.root:CreateTexture(nil, "BACKGROUND", nil, -6); self.lines[index] = texture end
        texture:ClearAllPoints(); texture:SetPoint("TOPLEFT", self.root, "TOPLEFT", x, -y)
        texture.major = major
        texture:SetSize(width, height); texture:Show()
    end
    for step = math.ceil(-pw / 2 / self.grid), math.floor((pw / 2 - 1) / self.grid) do
        line(pw / 2 + step * self.grid, 0, 1, ph, (step * self.grid) % 100 == 0)
    end
    for step = math.ceil(-ph / 2 / self.grid), math.floor((ph / 2 - 1) / self.grid) do
        line(0, ph / 2 + step * self.grid, pw, 1, (step * self.grid) % 100 == 0)
    end
    for i = index + 1, #self.lines do self.lines[i]:Hide() end
    self:HighlightGrid(self.drag ~= nil)
    local width, height = math.min(pw, ph * 16 / 9), math.min(ph, pw * 9 / 16)
    local x, y = (pw - width) / 2, (ph - height) / 2
    self.crop = { x = x, y = y, w = width, h = height }
    self.guide:ClearAllPoints(); self.guide:SetPoint("TOPLEFT", self.root, "TOPLEFT", x, -y)
    self.guide:SetSize(width, height); self.guide:SetShown(self.stream)
    self.guideTitle:SetText(string.format("16:9 stream area · %.0f × %.0f crop → 1920 × 1080 output · OBS crop L/R %.0f px, T/B %.0f px", width, height, x, y))
    local rectangles = {{0,0,x,ph},{x+width,0,x,ph},{x,0,width,y},{x,y+height,width,y}}
    for i, rect in ipairs(rectangles) do
        local shade = self.shades[i]; shade:ClearAllPoints()
        shade:SetPoint("TOPLEFT", self.root, "TOPLEFT", rect[1], -rect[2])
        shade:SetSize(math.max(1, rect[3]), math.max(1, rect[4]))
        shade:SetShown(self.stream and rect[3] > 0 and rect[4] > 0)
    end
    self.guideToggle.text:SetText(self.stream and "16:9 guide: On" or "16:9 guide: Off")
end

function Editor:HighlightGrid(active)
    for _, texture in ipairs(self.lines) do
        local alpha = active and (texture.major and .42 or .2) or (texture.major and .27 or .09)
        texture:SetColorTexture(.5, .65, .75, alpha)
    end
end

function Editor:ClearAlignment()
    for _, texture in ipairs(self.alignmentLines) do texture:Hide() end
end

function Editor:DrawAlignment(id, rect)
    local pw, ph = self:Metrics()
    local spec = self.specs[id]
    local selectedFrame = spec and spec.getFrame()
    local anchorsX, anchorsY = { rect.x, rect.x + rect.w / 2, rect.x + rect.w },
        { rect.y, rect.y + rect.h / 2, rect.y + rect.h }
    local matchedX, matchedY, index = {}, {}, 0
    local function match(anchors, targets, matched, vertical)
        for _, target in ipairs(targets) do
            for _, anchor in ipairs(anchors) do
                if math.abs(anchor - target) <= 1 and target >= 0 and target < (vertical and pw or ph) then
                    local duplicate = false
                    for _, coordinate in ipairs(matched) do
                        if math.abs(coordinate - target) <= 1 then duplicate = true; break end
                    end
                    if not duplicate then
                        matched[#matched + 1] = target
                        index = index + 1
                        local texture = self.alignmentLines[index]
                        if not texture then
                            texture = self.alignmentGuide:CreateTexture(nil, "OVERLAY")
                            texture:SetColorTexture(1, .12, .12, .95)
                            self.alignmentLines[index] = texture
                        end
                        texture:ClearAllPoints()
                        texture:SetPoint("TOPLEFT", self.root, "TOPLEFT", vertical and target or 0, vertical and 0 or -target)
                        texture:SetSize(vertical and 1 or pw, vertical and ph or 1)
                        texture:Show()
                    end
                    break
                end
            end
        end
    end
    for otherID, other in pairs(self.specs) do
        local frame = otherID ~= id and other.getFrame()
        if frame and frame ~= selectedFrame and (frame:IsVisible() or frame.parent and frame.parent:IsVisible()) then
            local target = self:Bounds(other, frame)
            if target and target.x < pw and target.y < ph and target.x + target.w > 0 and target.y + target.h > 0 then
                match(anchorsX, { target.x, target.x + target.w / 2, target.x + target.w }, matchedX, true)
                match(anchorsY, { target.y, target.y + target.h / 2, target.y + target.h }, matchedY, false)
            end
        end
    end
    for i = index + 1, #self.alignmentLines do self.alignmentLines[i]:Hide() end
end

function Editor:Select(id)
    if self.widthEdit then self.widthEdit:ClearFocus() end
    self.selected = id
    for name, handle in pairs(self.handles) do
        handle:SetFrameLevel(name == id and 115 or 105)
        handle.fill:SetColorTexture(.15, .65, .85, name == id and .24 or .08)
    end
    local spec = self.specs[id]
    local rect = spec and self:Bounds(spec)
    if rect then
        if self.widthEdit then self.widthEdit:SetText(tostring(self:RoundPhysicalSize(rect.w))) end
        self:Describe(spec, rect)
    end
end

function Editor:ApplyWidth()
    local width = self.widthEdit and tonumber(self.widthEdit:GetText())
    if self.widthEdit then self.widthEdit:ClearFocus() end
    if InCombatLockdown() or self.drag then return end
    local spec = self.selected and self.specs[self.selected]
    local rect = spec and self:Bounds(spec)
    if not rect then self:Message("Select an element first."); return end
    if not spec.resize then self:Message("This element does not support resizing."); return end
    if spec.prepareResize then
        self:Message("Use this element's native resize handles; exact width is unavailable.")
        return
    end
    if not width or width ~= width or width == math.huge or width < (spec.minWidth or 30) then
        self:Message("Enter a width at least " .. tostring(spec.minWidth or 30) .. " physical pixels.")
        return
    end
    local height = rect.h
    if spec.resize == "scale" then
        local ratio, offset = rect.w / rect.h, 0
        if spec.fixedBorderSize then
            local bounds, native = self:Bounds(spec)
            ratio = native.w / native.h
            offset = bounds.h-native.h-(bounds.w-native.w)/ratio
        end
        height = width / ratio + offset
    end
    local pw, ph = self:Metrics()
    if width > pw-rect.x or height > ph-rect.y or height < (spec.minHeight or 1) then
        self:Message("That width does not fit this element's proportions and screen bounds.")
        return
    end
    rect.w, rect.h = width, height
    self:Commit(self.selected, rect, true)
end

function Editor:CenterX()
    if self.widthEdit then self.widthEdit:ClearFocus() end
    if InCombatLockdown() or self.drag then return end
    local spec = self.selected and self.specs[self.selected]
    local rect = spec and self:Bounds(spec)
    if not rect then self:Message("Select an element first."); return end
    local pw = self:Metrics()
    if rect.w > pw then self:Message("This element is wider than the screen."); return end
    rect.x = (pw-rect.w)/2
    self:Commit(self.selected, rect, false)
end

function Editor:ResizeCorners(rect)
    local width = self:Metrics()
    return rect.x < width / 2, rect.x + rect.w > width / 2
end

function Editor:PositionText(rect)
    local left, right = self:ResizeCorners(rect)
    if left and right then
        return string.format("BL X %.0f  ·  BR X %.0f  ·  Y %.0f", rect.x, rect.x + rect.w, rect.y + rect.h)
    end
    return string.format("%s X %.0f  Y %.0f", left and "BL" or "BR", left and rect.x or rect.x + rect.w, rect.y + rect.h)
end

function Editor:Describe(spec, rect)
    local outside = self.stream and (rect.x < self.crop.x - .5 or rect.y < self.crop.y - .5
        or rect.x + rect.w > self.crop.x + self.crop.w + .5 or rect.y + rect.h > self.crop.y + self.crop.h + .5)
    self:Message(string.format("%s  ·  %s  ·  %.0f × %.0f px%s%s", spec.label, self:PositionText(rect), self:RoundPhysicalSize(rect.w), self:RoundPhysicalSize(rect.h),
        spec.resize == "scale" and "  ·  proportional resize" or "", outside and "  ·  outside stream area" or ""))
end

function Editor:DrawHandle(handle, rect)
    handle:ClearAllPoints(); handle:SetPoint("TOPLEFT", self.root, "TOPLEFT", rect.x, -rect.y)
    handle:SetSize(rect.w, rect.h)
    local left, right = self:ResizeCorners(rect)
    for corner, grip in pairs(handle.grips or {}) do
        local dragging = self.drag and self.drag.resizing and self.handles[self.drag.id] == handle and self.drag.corner == corner
        grip:SetShown(dragging or (corner == "BOTTOMLEFT" and left) or (corner == "BOTTOMRIGHT" and right))
    end
end

function Editor:ShowSize(id, rect, corner)
    if not self.active then return end
    local handle, spec = self.handles[id], self.specs[id]
    if not handle or not handle.grips or not spec then return end
    rect = rect or self:Bounds(spec)
    if not rect then return end
    corner = corner or (self:ResizeCorners(rect) and "BOTTOMLEFT" or "BOTTOMRIGHT")
    local grip = handle.grips[corner]
    local hint = self.sizeHint
    hint.text:SetText(string.format("W %.0f × H %.0f px\n%s", self:RoundPhysicalSize(rect.w), self:RoundPhysicalSize(rect.h), self:PositionText(rect)))
    hint:SetSize(hint.text:GetStringWidth() + 16, hint.text:GetStringHeight() + 12)
    hint:ClearAllPoints()
    if corner == "BOTTOMLEFT" then hint:SetPoint("BOTTOMLEFT", grip, "TOPRIGHT", 6, 6)
    else hint:SetPoint("BOTTOMRIGHT", grip, "TOPLEFT", -6, 6) end
    hint:Show()
end

function Editor:Refresh()
    if not self.active then return end
    self.sizeHint:Hide()
    local available = {}
    for _, handle in pairs(self.handles) do handle:Hide() end
    for _, row in ipairs(self.rows) do row:Hide() end
    for _, spec in pairs(self.specs) do
        local rect = self:Bounds(spec)
        if rect then available[#available + 1] = { spec = spec, rect = rect } end
    end
    table.sort(available, function(a,b) return a.spec.label < b.spec.label end)
    for index, item in ipairs(available) do
        local spec, rect = item.spec, item.rect
        local handle = self.handles[spec.id]
        if not handle then
            handle = CreateFrame("Frame", nil, self.root)
            handle:SetFrameLevel(105); handle:EnableMouse(true)
            handle.fill = fill(handle, .15, .65, .85, .08)
            outline(handle, .25, .8, 1, .9)
            local name = label(handle, spec.label, 12); name:SetPoint("CENTER")
            handle:SetScript("OnMouseDown", function(_, key) if key == "LeftButton" then self:Begin(spec.id, false) end end)
            handle:SetScript("OnMouseUp", function(_, key) if key == "LeftButton" then self:Finish() end end)
            if spec.resize then
                handle.grips = {}
                for _, corner in ipairs({"BOTTOMLEFT", "BOTTOMRIGHT"}) do
                    local grip = CreateFrame("Button", nil, handle)
                    handle.grips[corner] = grip
                    grip:SetSize(18, 18); grip:SetPoint(corner); grip:SetFrameLevel(120)
                    fill(grip, .12, .5, .65, .95)
                    local symbol = label(grip, "+", 12); symbol:SetPoint("CENTER")
                    grip:SetScript("OnMouseDown", function(_, key) if key == "LeftButton" then self:Begin(spec.id, true, corner) end end)
                    grip:SetScript("OnMouseUp", function(_, key) if key == "LeftButton" then self:Finish() end end)
                    grip:SetScript("OnEnter", function() if not self.drag then self:ShowSize(spec.id, nil, corner) end end)
                    grip:SetScript("OnLeave", function() if not (self.drag and self.drag.resizing) then self.sizeHint:Hide() end end)
                end
            end
            self.handles[spec.id] = handle
        end
        self:DrawHandle(handle, rect); handle:Show()
        local row = self.rows[index]
        if not row then
            row = button(self.listChild, "", 208, function(control) self:Select(control.target) end)
            row:SetHeight(25); row:SetPoint("TOPLEFT", 0, -(index-1)*29); self.rows[index] = row
        end
        row.target = spec.id; row.text:SetText(spec.label); row:Show()
    end
    self.listChild:SetHeight(math.max(1, #available * 29))
    if self.selected then self:Select(self.selected) end
end

function Editor:Clamp(rect)
    local pw, ph = self:Metrics()
    rect.x = math.max(0, math.min(rect.x, math.max(0, pw-rect.w)))
    rect.y = math.max(0, math.min(rect.y, math.max(0, ph-rect.h)))
    return rect
end

function Editor:Begin(id, resizing, corner)
    if InCombatLockdown() or not self.active then return end
    local spec = self.specs[id]
    local rect = spec and self:Bounds(spec)
    if not rect then return end
    local predictor, reason
    if resizing and spec.prepareResize then
        predictor, reason = spec.prepareResize(rect, corner or "BOTTOMRIGHT")
        if not predictor then self:Message(reason or "No native 5px size is available."); return end
    end
    self:Select(id)
    local x, y = self:Cursor()
    self.drag = { id = id, resizing = resizing, corner = corner or "BOTTOMRIGHT", original = rect, x = x, y = y, predictor = predictor }
    if resizing then self:ShowSize(id, rect, self.drag.corner) else self.sizeHint:Hide() end
    self:ClearAlignment(); self:HighlightGrid(true)
    self.root:SetScript("OnUpdate", function() self:DragUpdate() end)
end

function Editor:DragUpdate()
    local drag = self.drag
    if not drag then return end
    if InCombatLockdown() then self:Close(); return end
    if not IsMouseButtonDown("LeftButton") then self:Finish(); return end
    local x, y = self:Cursor()
    local dx, dy = x-drag.x, y-drag.y
    if not drag.moved and math.abs(dx)+math.abs(dy) < 3 then return end
    drag.moved = true
    local spec, original = self.specs[drag.id], drag.original
    local rect = self:Copy(original)
    if drag.resizing then
        local pw, ph = self:Metrics()
        local fromLeft = drag.corner == "BOTTOMLEFT"
        local width, height = original.w + (fromLeft and -dx or dx), original.h + dy
        local maxWidth = fromLeft and original.x + original.w or pw - original.x
        local maxHeight = ph - original.y
        if drag.predictor then
            if spec.resize == "scale" and math.abs(dy/original.h) > math.abs(dx/original.w) then width = height*original.w/original.h end
            rect.w, rect.h, rect.nativeSize = drag.predictor(width,height)
        elseif spec.resize == "scale" then
            if math.abs(dy/original.h) > math.abs(dx/original.w) then width = height*original.w/original.h end
            local ratio, offset = original.w / original.h, 0
            if spec.fixedBorderSize then
                local bounds, native = self:Bounds(spec)
                if bounds and native then
                    ratio = native.w/native.h
                    offset = bounds.h-native.h-(bounds.w-native.w)/ratio
                end
            end
            -- These owners scale uniformly. Quantize width alone so an exact
            -- 300px width is not displaced to make its proportional height 5px.
            rect.w = self:SnapSize(width,
                math.max(spec.minWidth or 30, ((spec.minHeight or 0)-offset) * ratio), math.min(maxWidth, (maxHeight-offset) * ratio))
            rect.h = rect.w and rect.w / ratio + offset
        else
            rect.w = self:SnapSize(width, spec.minWidth or 30, maxWidth)
            rect.h = self:SnapSize(height, spec.minHeight or 20, maxHeight)
        end
        if not rect.w or not rect.h then
            self:Message("No permitted size fits this element's proportions and screen bounds.")
            return
        end
        if fromLeft then rect.x = original.x + original.w - rect.w end
    else
        rect.x, rect.y = self:SnapPosition(original.x+dx, original.y+dy)
        local pw = self:Metrics()
        local centered = (pw-rect.w)/2
        if math.abs(original.x+dx-centered) <= self.grid/2 then rect.x = centered end
    end
    drag.preview = drag.resizing and rect or self:Clamp(rect)
    self:DrawHandle(self.handles[drag.id], drag.preview)
    if drag.resizing then self:ShowSize(drag.id, drag.preview, drag.corner) end
    self:DrawAlignment(drag.id, drag.preview)
    self:Describe(spec, drag.preview)
end

function Editor:Finish()
    local drag = self.drag
    if not drag then return end
    self.drag = nil; self.root:SetScript("OnUpdate", nil)
    self:ClearAlignment(); self:HighlightGrid(false)
    if drag.moved and drag.preview and not InCombatLockdown() then
        self:Commit(drag.id, drag.preview, drag.resizing)
    else self:Refresh() end
    local handle = self.handles[drag.id]
    for corner, grip in pairs(handle and handle.grips or {}) do
        if grip:IsVisible() and grip:IsMouseOver() then self:ShowSize(drag.id, nil, corner); break end
    end
end

function Editor:Commit(id, rect, resizing)
    if InCombatLockdown() then return false, "Combat" end
    local spec = self.specs[id]
    if not spec or not spec.getFrame() then return false, "Unavailable" end
    local native = self:NativeRect(spec, rect, resizing)
    if not native or native.w <= 1 or native.h <= 1 then return false, "Invalid painted bounds" end
    native.nativeSize = rect.nativeSize
    local snapshot = spec.snapshot and spec.snapshot()
    local ok, result, reason = pcall(spec.commit, native, resizing)
    if ok and result ~= false and resizing and spec.prepareResize then
        local actual = self:Bounds(spec)
        if not actual or math.abs(actual.w-rect.w)>.25 or math.abs(actual.h-rect.h)>.25
            or self:RoundPhysicalSize(actual.w)%5~=0 or self:RoundPhysicalSize(actual.h)%5~=0 then
            result, reason = false, "Native frame did not retain its predicted 5px size"
        end
    end
    if not ok or result == false then
        if snapshot and spec.restore then pcall(spec.restore, snapshot) end
        self:Refresh(); self:Message("Could not apply: " .. tostring(ok and reason or result))
        return false, reason or result
    end
    self.undo[#self.undo+1] = { id = id, snapshot = snapshot }
    if #self.undo > 30 then table.remove(self.undo, 1) end
    self:Refresh()
    return true
end

function Editor:Undo()
    if InCombatLockdown() or self.drag then return end
    local action = self.undo[#self.undo]
    if not action then self:Message("No layout changes to undo."); return end
    local spec = self.specs[action.id]
    local ok, result, reason = pcall(spec.restore, action.snapshot)
    if not ok or result == false then self:Message("Could not undo: " .. tostring(ok and reason or result)); return end
    table.remove(self.undo); self:Refresh(); self:Select(action.id)
end

function Editor:Open()
    if InCombatLockdown() then print("Squancher: layout editing is available out of combat."); return false end
    self:Build()
    if ns.LayoutTargets then ns.LayoutTargets:Register() end
    if ns.LayoutWindows then ns.LayoutWindows:Register() end
    ns:SetLayoutEditing(true)
    self.active = true; self.root:Show(); self:DrawCanvas(); self:Refresh()
    self:Message("Select or drag an element. Changes save on release; Undo restores the previous layout.")
    return true
end

function Editor:Close()
    self.drag = nil
    if self.widthEdit then self.widthEdit:ClearFocus() end
    if self.sizeHint then self.sizeHint:Hide() end
    if self.alignmentLines then self:ClearAlignment(); self:HighlightGrid(false) end
    if self.root then self.root:SetScript("OnUpdate", nil) end
    self.active = false
    if self.root then self.root:Hide() end
    ns:SetLayoutEditing(false)
end

function Editor:Toggle()
    if self.active then self:Close() else self:Open() end
end

-- Saved geometry is in physical pixels and is converted with the screen metrics
-- at the time of each placement, so a new display size, UI scale, graphics
-- restart or Edit Mode layout needs every owner's placement run again. One pass
-- on the next frame; each further event queues another, so the last metrics
-- win. Combat defers the pass to PLAYER_REGEN_ENABLED. Only existing public
-- entry points are called.
local function relayout()
    local skin, frames = ns.DarkSkin, ns.UnitFrames
    local steps = {
        function() if ns.NativeActionBars and ns.NativeActionBars.ready then ns.NativeActionBars:Apply() end end,
        -- Its hooks carry the quest drawer, the meter drawer and the bag window.
        function() if ns.MinimapPanel and ns.MinimapPanel.frame then ns.MinimapPanel:LayoutStack() end end,
        function() if skin and skin.started then skin:ApplyChat() end end,
        function() if ns.AuxiliaryLayout then ns.AuxiliaryLayout:Apply(true) end end,
        function() if ns.LayoutWindows then ns.LayoutWindows:Register() end end,
        function() if ns.SocialDrawer and ns.SocialDrawer.initialized then ns.SocialDrawer:Queue() end end,
        function() if ns.TooltipSkin and ns.db then ns.TooltipSkin:Refresh() end end,
        function() if skin and skin.RepaintRaised then skin:RepaintRaised() end end,
        function()
            if not frames or not frames.Initialized then return end
            frames:Update_AllFrames()
            if frames.PlacePlayerBars then frames:PlacePlayerBars() end
        end,
    }
    for _, step in ipairs(steps) do
        local ok, err = pcall(step)
        if not ok and geterrorhandler then geterrorhandler()(err) end
    end
end
function Editor:RequestRelayout()
    if self.relayoutQueued then return end
    self.relayoutQueued = true
    C_Timer.After(0, function()
        self.relayoutQueued = nil
        if InCombatLockdown() then self.relayoutPending = true; return end
        self.relayoutPending = nil
        relayout()
    end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED"); events:RegisterEvent("PLAYER_REGEN_ENABLED")
-- GX_RESTARTED follows a graphics restart on clients that have it.
for _, event in ipairs({ "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED", "GX_RESTARTED" }) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if Editor.relayoutPending then Editor:RequestRelayout() end
        return
    end
    if Editor.active and (event == "PLAYER_REGEN_DISABLED" or event == "DISPLAY_SIZE_CHANGED") then Editor:Close() end
    if event ~= "PLAYER_REGEN_DISABLED" and IsLoggedIn() then Editor:RequestRelayout() end
end)
SLASH_SQUANCHEREDIT1 = "/sqedit"
SlashCmdList.SQUANCHEREDIT = function() Editor:Toggle() end
