-- SPDX-License-Identifier: MIT
-- Exact Forever macro-editor and macro-popup chrome; macro data/input is native.
local _, ns = ...
local Macros = {}
ns.NativeMacroSkins = Macros
local initialized, pending = false, false
local edges = {
    "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
    "TopEdge", "BottomEdge", "LeftEdge", "RightEdge",
}

local function hideTexture(texture)
    if texture and texture.IsObjectType and texture:IsObjectType("Texture") then texture:SetAlpha(0) end
end

local function hideRim(slice)
    if not slice then return end
    for _, key in ipairs(edges) do hideTexture(slice[key]) end
end

function Macros:Apply()
    local skin, frame = ns.DarkSkin, MacroFrame
    if not skin or not frame then return end
    if InCombatLockdown() then pending = true; return end
    pending = false

    local editor = MacroFrameTextBackground
    if editor then
        -- TooltipBackdropTemplate owns both the blue Center and gold rim.
        -- The root's single theme fill shows through; no stacked editor fill.
        hideRim(editor.NineSlice)
        hideTexture(editor.NineSlice and editor.NineSlice.Center)
        skin:Panel(editor, "inner", 0)
    end

    local native = MacroHorizontalBarLeft
    if native then
        -- XML's anonymous right half uses this exact same native bitmap.
        -- Limit inspection to MacroFrame's own regions, never its macro slots.
        local bitmap = native:GetTexture()
        for _, region in ipairs({frame:GetRegions()}) do
            if region.IsObjectType and region:IsObjectType("Texture") and region:GetTexture() == bitmap then
                region:SetAlpha(0)
            end
        end
        if not self.divider then
            self.divider = skin:Divider(frame, frame:GetWidth() - 7)
            self.divider:SetPoint("TOPLEFT", native, "TOPLEFT", 0, -(native:GetHeight() / 2 - self.divider.paintCenter))
        end
        skin:SizeDivider(self.divider, frame:GetWidth() - 7)
    end

    local popup = MacroPopupFrame
    local box = popup and popup.BorderBox
    if box then
        -- SelectionFrameTemplate IS a NineSlicePanel, rather than owning one.
        -- Its composite macropopup-* edges include the decorative section bars.
        hideRim(box)
        local rim = skin:Panel(popup, "dialog", 0)
        if popup.BG then
            skin:PaintFill(popup.BG)
            skin:FitPanelBackground(popup.BG, rim)
        end
        local name = box.IconSelectorEditBox
        if name then
            hideTexture(name.IconSelectorPopupNameLeft)
            hideTexture(name.IconSelectorPopupNameMiddle)
            hideTexture(name.IconSelectorPopupNameRight)
            skin:Panel(name, "inner", 0)
        end
        if ns.NativeControlSkins then
            ns.NativeControlSkins:Style(box.OkayButton, true)
            ns.NativeControlSkins:Style(box.CancelButton, true)
            ns.NativeControlSkins:Style(box.IconTypeDropdown, true)
        end
    end
end

local events = CreateFrame("Frame")
local function initialize()
    if initialized or not MacroFrame then return end
    initialized = true
    events:UnregisterEvent("ADDON_LOADED")
    MacroFrame:HookScript("OnShow", function() Macros:Apply() end)
    if MacroPopupFrame then MacroPopupFrame:HookScript("OnShow", function() Macros:Apply() end) end
    Macros:Apply()
end
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event, addon)
    if event == "PLAYER_REGEN_ENABLED" then
        if pending then Macros:Apply() end
    elseif event == "PLAYER_LOGIN" or addon == "Blizzard_MacroUI" then
        initialize()
    end
end)
