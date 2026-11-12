-- SPDX-License-Identifier: MIT
-- Original presentation adapter for Forever's Blizzard_Collections canvases.
-- Native collection entries, model scenes and state artwork retain their owners.
local _, ns = ...
local Collections = {}
ns.NativeCollectionSkins = Collections
local pending, initialized = false, false
local edges = {
    "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
    "TopEdge", "BottomEdge", "LeftEdge", "RightEdge",
}
-- Exact decorative regions of Classic/Blizzard_CollectionTemplates.xml.
local decorations = {
    "Bg", "BackgroundTile", "watermark",
    "ShadowCornerTopLeft", "ShadowCornerTopRight",
    "ShadowCornerBottomLeft", "ShadowCornerBottomRight",
    "ShadowCornerTop", "ShadowCornerBottom", "ShadowCornerLeft", "ShadowCornerRight",
    "OverlayShadowTopLeft", "OverlayShadowTopRight",
    "OverlayShadowBottomLeft", "OverlayShadowBottomRight",
    "OverlayShadowTop", "OverlayShadowBottom", "OverlayShadowLeft", "OverlayShadowRight",
    "BGCornerFilagreeBottomLeft", "BGCornerFilagreeBottomRight",
    "BGCornerTopLeft", "BGCornerTopRight", "BGCornerBottomLeft", "BGCornerBottomRight",
    "ShadowLineTop", "ShadowLineBottom",
}

local function hideTexture(texture)
    if texture and texture.IsObjectType and texture:IsObjectType("Texture") then texture:SetAlpha(0) end
end

local function canvas(frame)
    if not frame then return end
    for _, key in ipairs(decorations) do hideTexture(frame[key]) end
    if frame.NineSlice then
        for _, key in ipairs(edges) do hideTexture(frame.NineSlice[key]) end
    end
    ns.DarkSkin:SmallBox(frame)
end

function Collections:Apply()
    if not CollectionsJournal or not ns.DarkSkin then return end
    if InCombatLockdown() then pending = true; return end
    pending = false
    -- One fill only: transparent child canvases must not stack this opacity.
    local background = CollectionsJournal.Bg
    if background and background.IsObjectType and background:IsObjectType("Texture") then
        ns.DarkSkin:PaintFill(background)
        ns.DarkSkin:FitPanelBackground(background, ns.DarkSkin:Panel(CollectionsJournal, "dialog", 0))
    end
    hideTexture(CollectionsJournal.TopTileStreaks)
    ns.DarkSkin:Panel(CollectionsJournal, "dialog", 0)

    if MountJournal then
        canvas(MountJournal.LeftInset)
        canvas(MountJournal.RightInset)
        local display = MountJournal.MountDisplay
        if display then
            -- These are decorative preview backplates, not the mount model.
            hideTexture(display.YesMountsTex)
            hideTexture(display.NoMountsTex)
            if display.ShadowOverlay then display.ShadowOverlay:SetAlpha(0) end
        end
    end
    if PetJournal then
        canvas(PetJournal.LeftInset)
        canvas(PetJournal.RightInset)
        local card = PetJournal.PetCard
        if card then
            hideTexture(card.PetBackground)
            if card.ShadowOverlay then card.ShadowOverlay:SetAlpha(0) end
        end
    end
    if ToyBox then canvas(ToyBox.iconsFrame) end
    if HeirloomsJournal then canvas(HeirloomsJournal.iconsFrame) end
    if WardrobeCollectionFrame then
        canvas(WardrobeCollectionFrame.ItemsCollectionFrame)
        local sets = WardrobeCollectionFrame.SetsCollectionFrame
        if sets then
            canvas(sets.LeftInset)
            canvas(sets.RightInset)
        end
    end
end

local events = CreateFrame("Frame")
local function initialize()
    if initialized or not CollectionsJournal then return end
    initialized = true
    events:UnregisterEvent("ADDON_LOADED")
    CollectionsJournal:HookScript("OnShow", function() Collections:Apply() end)
    -- All selected panels are created by the same load-on-demand addon. Native
    -- tab selection owns visibility; this post-hook changes decorative regions.
    hooksecurefunc("CollectionsJournal_UpdateSelectedTab", function() Collections:Apply() end)
    Collections:Apply()
end
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_REGEN_ENABLED" then
        if pending then Collections:Apply() end
    elseif event == "PLAYER_LOGIN" or name == "Blizzard_Collections" then
        initialize()
    end
end)
