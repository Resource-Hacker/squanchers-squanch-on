-- SPDX-License-Identifier: MIT
-- Native inventory presentation only. Blizzard owns slots, allocation, search,
-- sorting, bag settings, currencies, deposits, tooltips, click and drag handlers.
local _, ns = ...
local module = {}
ns.NativeContainerSkins = module
local windows, items = setmetatable({}, {__mode='k'}), setmetatable({}, {__mode='k'})
local queued, pending = false, false
local normalAtlases = {
    ['bags-item-slot64']=true, ['bags-item-slot-blank']=true,
    ['bank-frame-item-slotframe']=true, ['bank-frame-bag-slotframe']=true,
}
local edgeNames = {'TopLeftCorner','TopRightCorner','BottomLeftCorner','BottomRightCorner',
    'TopEdge','BottomEdge','LeftEdge','RightEdge'}
local quickslot = GetFileIDFromPath([[Interface\Buttons\UI-Quickslot2]])

local function styleItem(button)
    if not button or button.IsForbidden and button:IsForbidden() then return end
    if InCombatLockdown() then pending=true; return end
    local skin = ns.DarkSkin
    if not skin then return end
    local state = items[button]
    if state and state.busy then return end
    if not state then
        state = {}; items[button] = state
        button:HookScript('OnShow', styleItem)
        -- Recycled bank cells change their normal atlas after Refresh; bags
        -- change empty-slot appearance after every item/lock update.
        for _, method in ipairs({'Refresh','SyncAppearanceWithHasItem','SetNormalTexture','SetNormalAtlas'}) do
            if type(button[method]) == 'function' then hooksecurefunc(button, method, styleItem) end
        end
        button:HookScript('OnSizeChanged', styleItem)
    end
    state.busy = true
    -- Only the native neutral slot art is replaced. Quality/quest/new-item,
    -- locked/search fades, empty-bag icons and button states remain untouched.
    local normal = button.GetNormalTexture and button:GetNormalTexture()
    if normal and (normalAtlases[normal:GetAtlas()] or normal:GetTexture() == quickslot) then
        normal:SetAlpha(0)
    end
    local border = skin:ControlBorder(button, 'icon', button, 1)
    skin:BagSlotFill(border, button)
    state.busy = nil
end

local function styleSort(button)
    if not button then return end
    for _, method in ipairs({'GetNormalTexture','GetPushedTexture'}) do
        local texture = button[method] and button[method](button)
        local atlas = texture and texture:GetAtlas()
        if atlas == 'bags-button-autosort-up' or atlas == 'bags-button-autosort-down' then
            ns.DarkSkin:TintChrome(texture, not button.IsEnabled or button:IsEnabled())
        end
    end
end

local function styleWindow(frame)
    if InCombatLockdown() then pending=true; return end
    if not frame or not frame:IsVisible() then return end
    local skin = ns.DarkSkin
    if not skin then return end
    if frame == BankFrame and frame.Background then
        local border = skin:Panel(frame, 'dialog', 0)
        if frame.Bg and frame.Bg.IsObjectType and frame.Bg:IsObjectType('Texture') then
            frame.Background:SetAlpha(0)
            skin:StylePanelBackground(frame.Bg, border)
        else
            skin:StylePanelBackground(frame.Background, border)
        end
    end
    -- Existing NativeWindowBorders owns the outside window. BankPanel is an
    -- inset within that window, so keep its geometry and suppress its trim only.
    if frame == (BankFrame and BankFrame.BankPanel) then
        if frame.NineSlice then
            for _, key in ipairs(edgeNames) do
                if frame.NineSlice[key] then frame.NineSlice[key]:SetAlpha(0) end
            end
            if frame.NineSlice.Center then frame.NineSlice.Center:SetAlpha(0) end
        end
    end
    if frame.Items then
        for _, button in ipairs(frame.Items) do styleItem(button) end
    end
    if frame.itemButtonPool and frame.itemButtonPool.EnumerateActive then
        for button in frame.itemButtonPool:EnumerateActive() do styleItem(button) end
    end
    if frame.itemButtonBagPool and frame.itemButtonBagPool.EnumerateActive then
        for button in frame.itemButtonBagPool:EnumerateActive() do styleItem(button) end
    end
    styleSort(frame.AutoSortButton)
    if frame == ContainerFrame1 or frame == ContainerFrameCombinedBags then styleSort(BagItemAutoSortButton) end
    if ns.NativeControlSkins then ns.NativeControlSkins:Scan(frame) end
end

local function register(frame)
    if not frame or frame.IsForbidden and frame:IsForbidden() then return end
    if not windows[frame] then
        windows[frame] = true
        frame:HookScript('OnShow', styleWindow)
        -- Hook real instances, never modify shared native mixin tables.
        for _, method in ipairs({'Update','UpdateItemSlots','RefreshBankPanel','RefreshAllItemsForSelectedTab',
            'GenerateItemSlotsForSelectedTab','RefreshBagButtons','RefreshAll'}) do
            if type(frame[method]) == 'function' then hooksecurefunc(frame, method, styleWindow) end
        end
    end
    styleWindow(frame)
end

function module:Apply()
    if InCombatLockdown() then pending=true; return end
    pending = false
    register(ContainerFrameCombinedBags)
    for i=1, NUM_CONTAINER_FRAMES or 7 do register(_G['ContainerFrame'..i]) end
    register(BankFrame)
    register(BankFrame and BankFrame.BankPanel)
end

local function queue()
    if queued then return end
    queued = true
    C_Timer.After(0, function() queued=false; module:Apply() end)
end
local events=CreateFrame('Frame')
events:RegisterEvent('PLAYER_LOGIN')
events:RegisterEvent('ADDON_LOADED')
events:RegisterEvent('PLAYER_REGEN_ENABLED')
events:RegisterEvent('BAG_UPDATE_DELAYED')
events:SetScript('OnEvent',function(_,event)
    if event ~= 'PLAYER_REGEN_ENABLED' or pending then queue() end
end)
