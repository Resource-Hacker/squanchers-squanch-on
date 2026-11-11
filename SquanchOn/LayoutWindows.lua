-- SPDX-License-Identifier: MIT
-- Native windows keep their content, scripts, panel membership and visibility.
-- Item windows receive one measured size match; later editor changes stay owned.
-- Discovery never opens UI or constructs inventory widgets.
local _, ns = ...
local module = { native = {}, applying = {}, itemQueued = {} }
ns.LayoutWindows = module

local windows = {
    { 'CharacterFrame', 'Character' }, { 'MerchantFrame', 'Merchant' },
    { 'GossipFrame', 'Gossip' }, { 'QuestFrame', 'Quest dialogue' },
    { 'PlayerSpellsFrame', 'Spells and talents' }, { 'SpellBookFrame', 'Spellbook' },
    { 'PlayerTalentFrame', 'Talents' }, { 'FriendsFrame', 'Friends' },
    { 'WorldMapFrame', 'World map (windowed)' }, { 'BankFrame', 'Native bank' },
    { 'TradeFrame', 'Trade' }, { 'ItemTextFrame', 'Item text' },
    { 'SettingsPanel', 'Settings' }, { 'AddonList', 'Addons' },
    { 'MacroFrame', 'Macros' }, { 'MailFrame', 'Mail' },
    { 'OpenMailFrame', 'Open mail' }, { 'LootFrame', 'Loot' },
    { 'ProfessionsFrame', 'Professions' }, { 'TradeSkillFrame', 'Tradeskill' },
    { 'CraftFrame', 'Crafting' }, { 'CollectionsJournal', 'Collections' },
    { 'PVEFrame', 'Group finder' }, { 'AchievementFrame', 'Achievements' },
    { 'DressUpFrame', 'Dressing room' }, { 'ChannelFrame', 'Channels' },
    { 'InspectFrame', 'Inspect' }, { 'PetStableFrame', 'Pet stable' },
    { 'StableFrame', 'Stable' }, { 'QuestLogFrame', 'Quest log' },
    { 'EncounterJournal', 'Adventure guide' }, { 'CommunitiesFrame', 'Communities' },
    { 'AuctionHouseFrame', 'Auction house' }, { 'AuctionFrame', 'Auctions' },
    { 'GuildBankFrame', 'Native guild bank' }, { 'ClassTrainerFrame', 'Class trainer' },
    { 'ItemSocketingFrame', 'Item sockets' }, { 'ItemUpgradeFrame', 'Item upgrades' },
    { 'TaxiFrame', 'Flight paths' }, { 'CalendarFrame', 'Calendar' },
    { 'TimeManagerFrame', 'Clock' }, { 'GameMenuFrame', 'Game menu' },
    { 'HelpFrame', 'Help' }, { 'KeyBindingFrame', 'Key bindings' },
    { 'FlightMapFrame', 'Flight map' }, { 'ColorPickerFrame', 'Color picker' },
    { 'TabardFrame', 'Tabard' }, { 'PetitionFrame', 'Petition' },
    { 'GuildRegistrarFrame', 'Guild registrar' }, { 'PVPUIFrame', 'Player versus player' },
    { 'LFGParentFrame', 'Group finder' }, { 'SocialUIFrame', 'Social' },
    { 'LegacySystemFrame', 'Legacy' }, { 'QuestLogPopupDetailFrame', 'Quest details' },
    { 'DeathRecapFrame', 'Death recap' },
    { 'ContainerFrameCombinedBags', 'Combined bags' },
    { 'TransmogFrame', 'Transmogrification' }, { 'ChatConfigFrame', 'Chat settings' },
    { 'ProfessionsCustomerOrdersFrame', 'Crafting orders' },
    { 'DelvesCompanionConfigurationFrame', 'Delves companion' },
    { 'DelvesDifficultyPickerFrame', 'Delves difficulty' },
    { 'HeroTalentsSelectionDialog', 'Hero talents' }, { 'ItemInteractionFrame', 'Item interaction' },
    { 'SplashFrame', 'New features' }, { 'ScriptErrorsFrame', 'Script errors' },
    { 'StaticPopup1', 'Primary dialog' },
    { 'StaticPopup2', 'Secondary dialog' },

    { 'ZoneAbilityFrame', 'Zone ability' }, { 'TotemFrame', 'Totems' },
    { 'VehicleSeatIndicator', 'Vehicle seats' }, { 'DurabilityFrame', 'Durability' },
}

local function finite(n)
    return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge
end

local function valid(rect)
    return type(rect) == 'table' and finite(rect.x) and finite(rect.y)
        and finite(rect.w) and finite(rect.h) and rect.w > 0 and rect.h > 0
end

local function maximizedMap(frame)
    return frame == WorldMapFrame and (frame.isMaximized or frame.IsMaximized and frame:IsMaximized())
end
local function editable(frame)
    return frame and frame:IsVisible() and not maximizedMap(frame)
        and not (ns.SocialDrawer and ns.SocialDrawer:Owns(frame))
end

local function applyMaximizedMap(frame, scale)
    if not finite(scale) or scale <= 0 then error('Unavailable native map scale') end
    local point = frame:GetAttribute('UIPanelLayout-maximizePoint')
    local panel = UIPanelWindows and UIPanelWindows[frame:GetName()]
    point = point or panel and panel.maximizePoint
    if type(point) ~= 'string' then error('Unavailable native map anchor') end
    frame:SetScale(scale)
    frame:ClearAllPoints()
    frame:SetPoint(point)
end

-- Measure the visible artwork, not the outer border or native grid pitch.
-- These windows retain their native proportions, fonts and item interactions.
local itemSamples = {
    CharacterFrame = 'CharacterHeadSlot', MerchantFrame = 'MerchantItem1ItemButton',
    InspectFrame = 'InspectHeadSlot', TradeFrame = 'TradePlayerItem1ItemButton',
    MailFrame = 'SendMailAttachment1', OpenMailFrame = 'OpenMailAttachmentButton1',
    LootFrame = 'LootButton1', BankFrame = 'BankFrameItem1',
}

local function iconFor(button)
    if not button then return end
    local function region(value)
        local kind = type(value)
        return (kind == 'table' or kind == 'userdata') and value.GetWidth and value.GetParent
    end
    -- Skip metadata fields; only native texture regions have artwork geometry.
    for _, key in ipairs({'icon', 'Icon', 'IconTexture'}) do
        local value = button[key]
        if region(value) then return value end
    end
    local name = button.GetName and button:GetName()
    if name then
        for _, suffix in ipairs({'IconTexture', 'Icon'}) do
            local value = _G[name .. suffix]
            if region(value) then return value end
        end
    end
end

local function artWidth(icon, owner)
    if type(icon) ~= 'table' and type(icon) ~= 'userdata' then return end
    if not icon.GetWidth or not icon.GetParent then return end
    if icon.IsForbidden and icon:IsForbidden() then return end
    if owner then
        local parent = icon
        for _ = 1, 24 do
            if parent == owner then break end
            parent = parent and parent.GetParent and parent:GetParent()
        end
        if parent ~= owner then return end
    end
    -- Layered textures inherit their parent's scale; not every client exposes
    -- Frame's GetEffectiveScale method on the texture itself.
    local scaleOwner = icon.GetEffectiveScale and icon or icon:GetParent()
    if not scaleOwner or not scaleOwner.GetEffectiveScale then return end
    local width = icon:GetWidth() * scaleOwner:GetEffectiveScale()
    if finite(width) and width > 1 then return width end
end

local function actionArtWidth()
    local profiles = ns.DarkSkin and ns.DarkSkin.actionButtonProfiles
    local profile = profiles and profiles[ActionButton1]
    -- The native bar must have completed its layout/skin before we sample it.
    if not profile or not ns.NativeActionBars or ns.NativeActionBars.layingOut then return end
    return artWidth(profile.icon, MainActionBar)
end

-- The combined map panel uses this same artwork measurement for its bag row.
function module:ActionArtWidth() return actionArtWidth() end
function module:IconArtWidth(button, owner) return artWidth(iconFor(button), owner) end

function module:MatchItemWindow(frame)
    local name, id = frame:GetName(), self.native[frame]
    local sample = itemSamples[name] and _G[itemSamples[name]]
    if name == 'QuestFrame' then
        local rewards = QuestInfoRewardsFrame and QuestInfoRewardsFrame.RewardButtons
        sample = rewards and rewards[1]
    end
    local wanted, current = actionArtWidth(), artWidth(iconFor(sample), frame)
    if not wanted or not current then return end
    local profile = '__native'
    local receipts = ns.db.itemWindowSizing
    -- A migrated window already received its measured size under its previous
    -- geometry owner. Keep that size instead of applying the ratio twice.
    if receipts and receipts[id] and next(receipts[id]) then return end
    local previous = ns.LayoutEditor:Read(id)
    if previous and previous.importedGeometry then return end
    local rect = ns.LayoutEditor:Rect(frame)
    if not valid(rect) then return end
    local spec, ratio = ns.LayoutEditor.specs[id], wanted / current
    local saved = spec.snapshot()
    rect.w, rect.h = rect.w * ratio, rect.h * ratio
    local called, ok, err = pcall(spec.commit, rect, true)
    if not called or not ok then
        spec.restore(saved)
        error((called and err or ok) or 'Could not size item window')
    end
    ns.db.itemWindowSizing = receipts or {}
    receipts = ns.db.itemWindowSizing
    receipts[id] = receipts[id] or {}
    receipts[id][profile] = { beforeScale = saved.scale, scale = frame:GetScale(),
        actionArtWidth = wanted }
end

function module:QueueItemSizing(frame)
    if self.itemQueued[frame] or not frame:IsVisible() then return end
    if not itemSamples[frame:GetName()] and frame ~= QuestFrame then return end
    self.itemQueued[frame] = true
    -- OnShow can precede native item allocation; wait for that layout to finish.
    C_Timer.After(0, function()
        if not InCombatLockdown() and frame:IsVisible() and ns.db then
            local ok, err = pcall(self.MatchItemWindow, self, frame)
            if not ok then geterrorhandler()(err) end
        end
        self.itemQueued[frame] = nil
    end)
end

function module:Refresh()
    if self.refreshQueued or not ns.LayoutEditor.active then return end
    self.refreshQueued = true
    C_Timer.After(0, function()
        self.refreshQueued = nil
        ns.LayoutEditor:Refresh()
    end)
end

function module:Apply(id, frame)
    if ns.SocialDrawer and ns.SocialDrawer:Owns(frame) then ns.SocialDrawer:Queue();return end
    if InCombatLockdown() or self.applying[frame] or not frame:IsVisible() then return end
    if ns.NativeWindowPlacement then ns.NativeWindowPlacement:Import(frame:GetName(), id, frame) end
    local record = ns.LayoutEditor:Read(id)
    if not record or not finite(record.scale) or record.scale <= 0 then return end
    self.applying[frame] = true
    local ok, err = pcall(function()
        if maximizedMap(frame) then
            applyMaximizedMap(frame, record.nativeScale or self.mapDefaultScale)
        else
            frame:SetScale(record.scale)
            if record.nativeAnchor then
                local point = record.nativeAnchor
                frame:ClearAllPoints()
                frame:SetPoint(point[1], UIParent, point[2], point[3], point[4])
            else
                ns.LayoutEditor:Place(frame, record)
            end
        end
    end)
    self.applying[frame] = nil
    if not ok then return false, err end
    return true
end

local function native(definition)
    local name, label = unpack(definition)
    local frame = _G[name]
    if not frame or frame.IsForbidden and frame:IsForbidden() or module.native[frame] then return end
    if frame == WorldMapFrame then module.mapDefaultScale = frame:GetScale() end
    local id, editor = 'window_' .. name, ns.LayoutEditor
    module.native[frame] = id
    if ns.NativeWindowPlacement then ns.NativeWindowPlacement:Import(name, id, frame) end
    editor:Register({
        id = id, label = label, resize = 'scale', minWidth = 30,
        getFrame = function() if editable(frame) then return frame end end,
        snapshot = function()
            local saved = { record = editor:Copy(editor:Read(id)), scale = frame:GetScale(), points = {} }
            for i = 1, frame:GetNumPoints() do saved.points[i] = { frame:GetPoint(i) } end
            return saved
        end,
        commit = function(rect, resizing)
            if InCombatLockdown() then return false, 'Combat' end
            if not editable(frame) or not valid(rect) then return false, 'Unavailable' end
            local current = editor:Rect(frame)
            if not valid(current) then return false, 'Unavailable' end
            local scale = frame:GetScale() * (resizing and rect.w / current.w or 1)
            if not finite(scale) or scale <= 0 then return false, 'Invalid scale' end
            -- Keep native dimensions dynamic; a tab changing width never causes
            -- a later open to be stretched back to an old width/height.
            local previous = editor:Read(id)
            editor:Store(id, { x = rect.x, y = rect.y, scale = scale,
                nativeScale = frame == WorldMapFrame and (previous and previous.nativeScale or module.mapDefaultScale) or nil })
            return module:Apply(id, frame)
        end,
        restore = function(saved)
            if InCombatLockdown() then return false, 'Combat' end
            if not saved then return false, 'Unavailable' end
            editor:Store(id, saved.record)
            module.applying[frame] = true
            local ok, err = pcall(function()
                if maximizedMap(frame) then
                    applyMaximizedMap(frame, saved.record and saved.record.nativeScale or module.mapDefaultScale)
                    return
                end
                frame:SetScale(saved.scale)
                frame:ClearAllPoints()
                for _, point in ipairs(saved.points) do frame:SetPoint(unpack(point)) end
            end)
            module.applying[frame] = nil
            if not ok then return false, err end
            return true
        end,
    })
    local function update()
        if module.applying[frame] then return end
        module:Apply(id, frame)
        module:QueueItemSizing(frame)
        module:Refresh()
    end
    frame:HookScript('OnShow', update)
    frame:HookScript('OnHide', function() module:Refresh() end)
    frame:HookScript('OnSizeChanged', function() module:Refresh() end)
    -- UIPanel positioning can run after OnShow and when adjacent panels close.
    -- Posthook only this allowlisted frame; never mutate UIPanelWindows,
    -- UIPanelLayout attributes, protected visibility or user-placed flags.
    hooksecurefunc(frame, 'SetPoint', update)
    hooksecurefunc(frame, 'SetScale', update)
    if frame == WorldMapFrame then
        if frame.Maximize then hooksecurefunc(frame, 'Maximize', update) end
        if frame.Minimize then hooksecurefunc(frame, 'Minimize', update) end
    end
    module:Apply(id, frame)
    module:QueueItemSizing(frame)
end

function module:Register()
    if InCombatLockdown() then return end
    if not self.questItemsHooked and type(QuestInfo_Display) == 'function' then
        self.questItemsHooked = true
        hooksecurefunc('QuestInfo_Display', function()
            if QuestFrame then module:QueueItemSizing(QuestFrame) end
        end)
    end
    for _, definition in ipairs(windows) do native(definition) end
    -- A natural show/position event in combat is deferred until this event path.
    for frame, id in pairs(self.native) do self:Apply(id, frame); self:QueueItemSizing(frame) end
    self:Refresh()
end

local events = CreateFrame('Frame')
events:RegisterEvent('PLAYER_LOGIN')
events:RegisterEvent('ADDON_LOADED')
events:RegisterEvent('PLAYER_REGEN_ENABLED')
events:SetScript('OnEvent', function()
    C_Timer.After(0, function() module:Register() end)
end)
