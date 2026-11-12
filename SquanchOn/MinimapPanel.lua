-- SPDX-License-Identifier: MIT
-- One owner for the XP -> map -> bags stack (the micro menu lives in the chat header). Native controls keep
-- their own scripts, bindings, state drivers and secure action ownership.
local _, ns = ...
local Panel = { width = 174.933349609375 }
ns.MinimapPanel = Panel

local function point(frame, anchor, relative, relativeAnchor, x, y)
    local clear = frame.ClearAllPointsBase or frame.ClearAllPoints
    local setPoint = frame.SetPointBase or frame.SetPoint
    clear(frame)
    setPoint(frame, anchor, relative, relativeAnchor, x or 0, y or 0)
end
local function scale(frame, value)
    (frame.SetScaleBase or frame.SetScale)(frame, value)
end
local function adopt(frame, parent)
    -- DynamicCam temporarily owns parentage while hiding the UI.
    if not frame.ludius_parentBeforeFadeOut and frame:GetParent() ~= parent then frame:SetParent(parent) end
end

function Panel:Ensure()
    if self.frame then return self.frame end
    local frame = CreateFrame("Frame", "SquancherMinimapPanel", UIParent)
    frame:SetFrameStrata("MEDIUM"); frame:SetFrameLevel(10)
    frame:SetMovable(true); frame:SetClampedToScreen(true); frame:SetDontSavePosition(true)
    frame:EnableMouse(false)
    local position = SquanchOnDB and SquanchOnDB.minimapPanelPosition
    if position and position.point and position.relativePoint and type(position.x) == "number" and type(position.y) == "number" then
        frame:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
    else
        -- Preserve the map's exact old position; add the XP header above it.
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOM", 434.86669921875, 81.0667037963867 + self.width + 10)
    end
    self.frame = frame
    local rules = CreateFrame("Frame", nil, frame)
    rules:SetAllPoints(); rules:EnableMouse(false); rules.ignoreInLayout = true
    rules:SetFrameLevel(200)
    -- The bag cells own the map/bag seam; do not stack a second rim there.
    self.xpDivider = ns.DarkSkin:Divider(rules, self.width)
    ns.DarkSkin:Panel(frame, "minimap", 0)
    return frame
end

function Panel:LayoutStack()
    if InCombatLockdown() then self.pending = true; return end
    if self.layoutActive then return end
    self.layoutActive = true
    local frame = self:Ensure()
    local width, y = self.width, 10
    if Minimap then
        adopt(Minimap, frame)
        Minimap:SetFrameStrata("MEDIUM")
        Minimap:SetFrameLevel(frame:GetFrameLevel() + 1)
        point(Minimap, "TOPLEFT", frame, "TOPLEFT", 0, -y)
        Minimap:SetSize(width, width)
        local old = ns.DarkSkin.byFrame[Minimap]
        if old and old.minimap then old.minimap:Hide() end
    end
    local xp = ns.NativeDataBars and ns.NativeDataBars.xp
    if xp then
        adopt(xp, frame); scale(xp, 1)
        point(xp, "TOPLEFT", frame, "TOPLEFT")
        xp:SetWidth(width)
        local old = ns.DarkSkin.byFrame[xp]
        if old and old.compact then old.compact:Hide() end
        if not self.dragInstalled then
            self.dragInstalled = true
            xp:RegisterForDrag("LeftButton")
            xp:HookScript("OnDragStart", function()
                if IsAltKeyDown() and not InCombatLockdown() then frame:StartMoving(); self.dragging = true end
            end)
            xp:HookScript("OnDragStop", function()
                if not self.dragging then return end
                frame:StopMovingOrSizing(); self.dragging = nil
                local anchor, _, relativeAnchor, x, vertical = frame:GetPoint()
                if ns.LayoutEditor and ns.LayoutEditor:Read("minimap_panel") then
                    local rect = ns.LayoutEditor:Rect(frame)
                    rect.x = math.floor(rect.x / 10 + 0.5) * 10
                    rect.y = math.floor(rect.y / 10 + 0.5) * 10
                    ns.LayoutEditor:Store("minimap_panel", rect)
                    ns.LayoutEditor:Place(frame, rect)
                else
                    SquanchOnDB.minimapPanelPosition = {point = anchor, relativePoint = relativeAnchor, x = x, y = vertical}
                end
            end)
        end
    end
    point(self.xpDivider, "TOPLEFT", frame, "TOPLEFT", 0, -10 + self.xpDivider.paintCenter)
    y = y + width
    if self.bagHeight then
        point(BagsBar, "TOP", frame, "TOP", 0, -y / BagsBar:GetScale())
        y = y + self.bagHeight
    end
    frame:SetSize(width, y)
    if ns.LayoutTargets then ns.LayoutTargets:ApplyScale("minimap_panel", frame) end
    self.pending, self.layoutActive = false, false
    self:QueueActionSlotMatch()
end

function Panel:QueueActionSlotMatch()
    if self.slotMatchQueued or not ns.db or ns.db.minimapItemSizing then return end
    self.slotMatchQueued = true
    C_Timer.After(0, function()
        local owner, editor, frame = ns.LayoutWindows, ns.LayoutEditor, self.frame
        if InCombatLockdown() then
            self.pending = true
        elseif owner and editor and frame and ns.LayoutTargets then
            local wanted = owner:ActionArtWidth()
            local current = owner:IconArtWidth(MainMenuBarBackpackButton, frame)
            local rect = editor:Rect(frame)
            if wanted and current and rect then
                local before = { record = editor:Copy(editor:Read('minimap_panel')), scale = frame:GetScale() }
                local ratio = wanted / current
                rect.w, rect.h = rect.w * ratio, rect.h * ratio
                -- Scale the common parent: XP, map and bag row
                -- retain their relative sizes and contiguous native layout.
                editor:Store('minimap_panel', rect)
                self:LayoutStack()
                ns.db.minimapItemSizing = { before = before, actionArtWidth = wanted }
                if ns.DarkSkin then ns.DarkSkin:BarControls() end
                if ns.QuestDrawer then ns.QuestDrawer:RequestLayout() end
            end
        end
        self.slotMatchQueued = nil
    end)
end

-- Camelot adds both an outer atlas and pooled dividers. Their native layout
-- remains authoritative, but the shared theme owns all visible bag borders.
function Panel:HideNativeBagBorders()
    if BagsBar.BorderArt then BagsBar.BorderArt:SetAlpha(0); BagsBar.BorderArt:Hide() end
    if BagsBar.HorizontalDividersPool then BagsBar.HorizontalDividersPool:ReleaseAll() end
    if BagsBar.VerticalDividersPool then BagsBar.VerticalDividersPool:ReleaseAll() end
end

function Panel:LayoutBags(buttons)
    local frame = self:Ensure()
    adopt(BagsBar, frame); scale(BagsBar, 0.5)
    self:HideNativeBagBorders()
    if not self.bagDividersHooked and BagsBar.UpdateDividers then
        self.bagDividersHooked = true
        hooksecurefunc(BagsBar, "UpdateDividers", function() self:HideNativeBagBorders() end)
    end
    BagsBar:SetFrameStrata("MEDIUM")
    BagsBar:SetFrameLevel(frame:GetFrameLevel() + 10)
    local width, height = 0, 0
    for _, button in ipairs(buttons) do
        button:SetFrameStrata("MEDIUM")
        button:SetFrameLevel(BagsBar:GetFrameLevel() + 1)
        point(button, "TOPLEFT", BagsBar, "TOPLEFT", width, 0)
        width = width + button:GetWidth()
        height = math.max(height, button:GetHeight())
    end
    width = math.max(1, width)
    scale(BagsBar, self.width / width)
    BagsBar:SetSize(width, math.max(1, height))
    self.bagHeight = height * BagsBar:GetScale()
    self:LayoutStack()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN"); events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then C_Timer.After(0, function() Panel:LayoutStack() end)
    elseif Panel.pending then Panel:LayoutStack() end
end)
