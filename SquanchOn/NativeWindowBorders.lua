-- SPDX-License-Identifier: MIT
-- Original Squancher presentation: one shared border, native window contents.
local _, ns = ...
local events = CreateFrame("Frame")
local hooked = {}
local pending = false
local scheduled = false
local windows = {
    "CharacterFrame", "MerchantFrame", "GossipFrame", "QuestFrame",
    "PlayerSpellsFrame", "FriendsFrame", "WorldMapFrame", "BankFrame",
    "TradeFrame", "ItemTextFrame", "LootFrame", "ContainerFrameCombinedBags",
    "SettingsPanel", "AddonList", "MacroFrame", "MailFrame", "ProfessionsFrame",
    "CollectionsJournal", "PVEFrame", "AchievementFrame", "DressUpFrame",
    "ChannelFrame", "InspectFrame", "PetStableFrame", "QuestLogFrame",
    -- Optional Forever windows stay lazy: absent globals are never created.
    "AuctionHouseFrame", "ClassTrainerFrame", "GuildBankFrame", "CalendarFrame",
    "TaxiFrame", "FlightMapFrame", "HelpFrame", "KeyBindingFrame", "ReadyCheckFrame",
    "DeathRecapFrame", "QuestLogPopupDetailFrame", "OpenMailFrame", "SendMailFrame",
    "ItemSocketingFrame", "ItemUpgradeFrame", "TabardFrame", "PetitionFrame",
    "GuildRegistrarFrame", "PVPUIFrame", "CommunitiesFrame", "ColorPickerFrame",
    "TimeManagerFrame", "LFGDungeonReadyDialog", "StaticPopup1", "StaticPopup2",
    "StaticPopup3", "StaticPopup4",
    "LFGParentFrame", "SocialUIFrame", "LegacySystemFrame", "EncounterJournal",
    -- Independent popup/window definitions in the selected Camelot client.
    "MacroPopupFrame", "ClassTalentLoadoutCreateDialog",
    "ClassTalentLoadoutEditDialog", "ClassTalentLoadoutImportDialog",
    "HeroTalentsSelectionDialog", "CalendarViewHolidayFrame",
    "CalendarViewRaidFrame", "CalendarViewEventFrame",
    "CalendarCreateEventFrame", "CalendarEventPickerFrame",
    "CalendarMassInviteFrame", "CalendarTexturePickerFrame",
    "CooldownViewerSettings", "CooldownViewerImportLayoutDialog",
    "CooldownViewerLayoutDialog", "DamageMeter",
    "ItemInteractionFrame", "PVPMatchResults",
    "PVPMatchScoreboard", "InspectRecipeFrame",
    "SideDressUpFrame", "BankCleanUpConfirmationPopup",
    "CurrencyTransferMenu", "CurrencyTransferLog",
    "GuildBankPopupFrame", "ChatConfigFrame",
    "ClickBindingFrame", "RaidInfoFrame",
    "RolePollPopup", "LFGInvitePopup",
    "PVPReadyDialog",
    -- Additional ordinary Camelot windows/modal dialogs (source-confirmed).
    "AddFriendFrame", "BattleNetInviteFrame",
    "FriendsFriendsFrame", "AddonDialog",
    "CreateChannelPopup", "CommunitiesAvatarPickerDialog",
    "CommunitiesSettingsDialog", "CommunitiesTicketManagerDialog",
    "CommunitiesGuildTextEditFrame", "CommunitiesGuildLogFrame",
    "CommunitiesGuildNewsFiltersFrame", "GuildControlUI",
    "GuildRenameFrame", "GuildInviteFrame",
    "ReportFrame", "ReportCheatingDialog",
    "TransmogFrame", "WardrobeCustomSetEditFrame",
    "EditModeManagerFrame", "EditModeLayoutDialog",
    "EditModeImportLayoutDialog", "EditModeUnsavedChangesDialog",
    "EditModeSystemSettingsDialog", "TutorialFrame",
    "GuideFrame", "BasicMessageDialog",
    "StackSplitFrame", "OpacityFrame",
    "QuickJoinRoleSelectionFrame", "GroupLootHistoryFrame",
    "ModelPreviewFrame", "SubscriptionInterstitialFrame",
}
local equipment = {
    "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist",
    "Hands", "Waist", "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1",
    "MainHand", "SecondaryHand", "Ranged", "Ammo",
}
local edges = {
    "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
    "TopEdge", "BottomEdge", "LeftEdge", "RightEdge",
}

local function hideNativeEdges(owner)
    local slice = owner and owner.NineSlice
    if not slice then return end
    -- NineSlice can also own a Center/background. Suppress ONLY its rim.
    for _, key in ipairs(edges) do
        local texture = slice[key]
        if texture then texture:SetAlpha(0) end
    end
end

-- These exact Camelot atlases contain decorative gold rims, not item quality.
local function goldGearRim(owner)
    if not owner or not owner.GetRegions then return end
    for _, region in ipairs({owner:GetRegions()}) do
        local atlas = region.GetAtlas and region:GetAtlas()
        if atlas == "UI-Character-Info-GearSlot" or atlas == "UI-Character-Info-GearSlotSmall" then
            ns.DarkSkin:TintChrome(region)
        end
    end
end

-- These exact native64px empty-slot glyphs have a baked silver perimeter.
-- Crop that perimeter only; actual equipment and its quality overlays stay native.
local emptySlotIcons = {
    [136512]=true,[136513]=true,[136514]=true,[136515]=true,[136516]=true,
    [136517]=true,[136518]=true,[136519]=true,[136520]=true,[136524]=true,
    [136525]=true,[136526]=true,[136527]=true,[136528]=true,[136529]=true,[136530]=true,
}
local slotIconHooks=setmetatable({}, {__mode="k"})
local function finishSlotIcon(button)
    local icon=button.icon or button.Icon
    if not icon or slotIconHooks[icon] then return end
    local state={coords={icon:GetTexCoord()}}
    slotIconHooks[icon]=state
    local function apply()
        if state.busy then return end
        local id=button:GetID()
        local empty=id and id>0 and not GetInventoryItemID("player",id)
        state.busy=true
        if empty and emptySlotIcons[icon:GetTexture()] then
            icon:SetTexCoord(.0625,.9375,.0625,.9375)
        else
            icon:SetTexCoord(unpack(state.coords))
        end
        state.busy=false
    end
    hooksecurefunc(icon,"SetTexCoord",function(_, ...)
        if state.busy then return end
        state.coords={...};apply()
    end)
    hooksecurefunc(icon,"SetTexture",apply)
    apply()
end

local function styleCharacterTabs(skin, frame)
    local tabs = frame.ModeTabs and frame.ModeTabs.Tabs
    if not tabs then return end
    for _, tab in ipairs(tabs) do
        tab.squancherCleanSideTab = true
        -- The native artwork follows the icon mask's angled corners. Tint that
        -- single contoured rim; a rectangular Dialog overlay cannot fit it.
        for _, key in ipairs({ "Background", "SelectedTexture", "TabGlow", "HighlightTexture" }) do
            if tab[key] then skin:TintChrome(tab[key]) end
        end
    end
end

local portraitHeaders = setmetatable({}, {__mode = "k"})
local lootHeaders = setmetatable({}, {__mode = "k"})
local function styleLootWindow(skin, frame, border)
    -- Forever LootFrame uses ScrollingFlatPanelTemplate: Bg is a decorative
    -- FlatPanelBackgroundTemplate FRAME, rather than the usual Bg texture.
    -- Its four native background regions otherwise stack behind our fill.
    if frame.Bg then frame.Bg:SetAlpha(0) end
    if frame.NineSlice and frame.NineSlice.Center then frame.NineSlice.Center:SetAlpha(0) end
    local state=lootHeaders[frame]
    if not state then
        state={}
        lootHeaders[frame]=state
        state.fill=frame:CreateTexture(nil,"BACKGROUND",nil,-8)
    end
    skin:StylePanelBackground(state.fill,border)
    local title,close=frame.TitleContainer,frame.ClosePanelButton
    if not title or not close then return end
    if not state.header then
        local header=CreateFrame("Frame",nil,frame)
        state.header=header
        header.ignoreInLayout=true
        header:EnableMouse(false)
        -- Keep native title/close input above the presentation-only plate.
        header:SetFrameLevel(math.max(0,math.min(title:GetFrameLevel(),close:GetFrameLevel())-2))
        skin:RaisedPlate(header,"compact")
    end
    local header=state.header
    local inset=border.cornerSize*9/13*border:GetEffectiveScale()/frame:GetEffectiveScale()
    header:ClearAllPoints()
    header:SetPoint("TOPLEFT",border,"TOPLEFT",inset,-inset)
    header:SetPoint("TOPRIGHT",border,"TOPRIGHT",-inset,-inset)
    -- Native ScrollBox starts at -22: occupy only its existing title band.
    header:SetHeight(title:GetHeight())
end

local function fitWindowPortrait(frame)
    if InCombatLockdown() then pending = true; return end
    local container = frame.PortraitContainer
    local portrait = container and container.portrait
    if not portrait then return end
    container:ClearAllPoints()
    local drawer=ns.SocialDrawer and ns.SocialDrawer:Owns(frame)
    container:SetPoint("TOPLEFT", frame, "TOPLEFT", drawer and 3 or -7, drawer and -3 or 10)
    container:SetSize(drawer and 28 or 62, drawer and 28 or 62)
    container:SetFrameLevel(frame.TitleContainer:GetFrameLevel() + 1)
    portrait:ClearAllPoints()
    portrait:SetPoint("TOPLEFT", container, "TOPLEFT", 2, -2)
    portrait:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -2, 2)
end

local function styleWindowHeader(skin, frame)
    local container, title, close = frame.PortraitContainer, frame.TitleContainer, frame.CloseButton
    if not (container and container.portrait and title and close) then return end
    local characterHeader = portraitHeaders[frame]
    if not characterHeader then
        -- Keep the native portrait texture/source, name and close-button action.
        -- The square sits proud of the sheet like the Escape-menu title plate.
        if container.CircleMask then container.portrait:RemoveMaskTexture(container.CircleMask) end
        fitWindowPortrait(frame)
        skin:RaisedPlate(container, "compact")
        characterHeader = CreateFrame("Frame", nil, frame)
        portraitHeaders[frame] = characterHeader
        characterHeader.ignoreInLayout = true
        characterHeader:EnableMouse(false)
        characterHeader:SetFrameLevel(title:GetFrameLevel() - 2)
        characterHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", ns.SocialDrawer and ns.SocialDrawer:Owns(frame) and 36 or 55, 0)
        characterHeader:SetPoint("BOTTOMRIGHT", close, "BOTTOMRIGHT", 0, 0)
        skin:RaisedPlate(characterHeader, "compact")
        title:ClearAllPoints()
        title:SetPoint("TOPLEFT", characterHeader, "TOPLEFT", 8, -1)
        title:SetPoint("BOTTOMRIGHT", close, "BOTTOMLEFT", -6, 1)
        if frame.UpdatePortrait then hooksecurefunc(frame, "UpdatePortrait", fitWindowPortrait) end
    end
    fitWindowPortrait(frame)
end

local function applyWindow(frame)
    if InCombatLockdown() then pending = true; return end
    local skin = ns.DarkSkin
    if not skin then return end
    hideNativeEdges(frame)
    -- WorldMap's border host also owns title/close controls; keep that host.
    local owner = frame == WorldMapFrame and frame.BorderFrame or frame
    hideNativeEdges(owner)
    local border = skin:Panel(owner, "dialog", 0)
    if frame==LootFrame then styleLootWindow(skin,frame,border) end
    -- Shared native panel Bg is decorative rock/marble, never the map/model
    -- content. Keep one chat-matched fill while child insets remain transparent.
    if owner.Bg and owner.Bg.IsObjectType and owner.Bg:IsObjectType("Texture") then
        skin:StylePanelBackground(owner.Bg, border)
    elseif frame == CharacterFrame and ns.NativeParchmentSkins then
        -- Camelot uses PortraitFrameBaseTemplate, with no root Bg texture.
        -- Its removed pane/race art must reveal one shared translucent underlay.
        ns.NativeParchmentSkins:Fill(frame)
    end
    -- Any native portrait window gets the same offset square and title plate.
    -- The helper is a no-op for ordinary windows without a portrait header.
    styleWindowHeader(skin, owner)
    if frame == CharacterFrame then
        for _, slot in ipairs(equipment) do
            local button = _G["Character" .. slot .. "Slot"]
            if button then
                -- The anonymous BACKGROUND atlas in BorderFrame is the gold
                -- gear rim; IconBorder is native item quality and stays intact.
                finishSlotIcon(button)
                goldGearRim(button.BorderFrame)
                goldGearRim(button) -- ammo's small rim is on the button itself
            end
        end
        styleCharacterTabs(skin, frame)
    end
    if ns.NativeControlSkins then
        ns.NativeControlSkins:Scan(frame)
        ns.NativeControlSkins:FinishWindow(frame)
    end
end

local function registerWindow(frame)
    if not frame or frame.IsForbidden and frame:IsForbidden() then return end
    if not hooked[frame] then
        hooked[frame] = true
        frame:HookScript("OnShow", applyWindow)
    end
    if frame:IsVisible() then applyWindow(frame) end
end

local function apply()
    if InCombatLockdown() then pending = true; return end
    pending = false
    for _, name in ipairs(windows) do registerWindow(_G[name]) end
    -- Native XML supplies these named bags; no global frame enumeration.
    for i = 1, NUM_CONTAINER_FRAMES or 7 do
        registerWindow(_G["ContainerFrame" .. i])
    end
end

events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
    if (event ~= "PLAYER_REGEN_ENABLED" or pending) and not scheduled then
        scheduled = true
        C_Timer.After(0, function() scheduled = false; apply() end)
    end
end)
