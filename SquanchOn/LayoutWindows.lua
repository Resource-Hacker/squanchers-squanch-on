-- SPDX-License-Identifier: MIT
-- Native windows keep their content, scripts, panel membership and visibility.
-- Item windows receive one measured size match; later editor changes stay owned.
-- Discovery never opens UI or constructs inventory widgets.
local _, ns = ...
local module = { native = {}, applying = {}, itemQueued = {}, contentQueued = {}, contentPending = {},
    settleQueued = {}, settleTries = {} }
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
    { 'ProfessionsFrame', 'Professions' }, { 'ProfessionsBookFrame', 'Professions book' },
    { 'TradeSkillFrame', 'Tradeskill' },
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

-- Windows opened from the chat-header micro buttons default to drawers above
-- chat: scaled to the chat panel's width, bottom-left on its top-left.
local drawers = { CharacterFrame = true, PlayerSpellsFrame = true, SpellBookFrame = true,
    PlayerTalentFrame = true, ProfessionsBookFrame = true, QuestLogFrame = true,
    CommunitiesFrame = true, PVEFrame = true, LFGParentFrame = true,
    CollectionsJournal = true, AchievementFrame = true, EncounterJournal = true }

module.drawers = drawers

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
-- A window attached to its drawer (Social above chat, the world map beside the
-- quest list) has one geometry owner: that drawer, never this module or /sqedit.
local function attached(frame)
    local social, map = ns.SocialDrawer, ns.MapDrawer
    if social and social:Owns(frame) then return social end
    if map and map:Owns(frame) then return map end
end
local function editable(frame)
    return frame and frame:IsVisible() and not maximizedMap(frame) and not attached(frame)
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

-- Returns the chat panel while a window still uses its default drawer place.
-- Only an owner /sqedit record (never an imported legacy one) replaces it.
-- ns.db.windows.drawers = false keeps windows free; read at each open.
-- ns.db.windows.mapDrawer = false keeps the world map free (MapDrawer.lua).
module.defaults = { drawers = true, mapDrawer = true }
function module:Setting(key)
    local values = ns.db and ns.db.windows
    local value
    if type(values) == 'table' then value = values[key] end
    if value == nil then return self.defaults[key] end
    return value
end
function module:DrawerChat(id, frame)
    if not drawers[frame:GetName()] or not self:Setting('drawers') then return end
    local record = ns.LayoutEditor:Read(id)
    -- Only a position the owner set in /sqedit counts; automatic sizing does not.
    if record and record.placed then return end
    return ns.DarkSkin and ns.DarkSkin.chatPanel
end

-- Top edge of a chat drawer window in physical pixels from the screen top:
-- measured while it is open, otherwise where Apply would put it now (its
-- native size is known while closed; the result does not depend on its
-- current scale). Nil when the window is no chat drawer.
function module:DrawerTop(frame)
    local id = frame and self.native[frame]
    local chat = id and self:DrawerChat(id, frame)
    local editor = ns.LayoutEditor
    local target = chat and editor:Rect(chat)
    if not target then return end
    local rect = frame:IsVisible() and editor:Rect(frame)
    if rect then return rect.y end
    local full, height = frame:GetWidth(), frame:GetHeight()
    if not (finite(full) and finite(height)) or full <= 0 or height <= 0 then return end
    local pane = frame == CharacterFrame and math.min(full, self.characterPane or 399) or full
    -- Apply's ratio: the pane matches chat's width, capped by the room above chat.
    return target.y - math.min(height * target.w / pane, math.max(1, target.y - 12))
end

function module:MatchItemWindow(frame)
    local name, id = frame:GetName(), self.native[frame]
    if self:DrawerChat(id, frame) then return end
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
    local called, ok, err = pcall(spec.commit, rect, true, true)
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

-- Drawer contents. The window's scale belongs to the chat-width rule, so its
-- text is sized in screen units by NativeText and, in the windows below, each
-- square icon button is scaled about its own centre until its artwork matches
-- the action bar's. CharacterFrame keeps its own fit and is never visited.
local iconRoots = { PlayerSpellsFrame = true, SpellBookFrame = true, PlayerTalentFrame = true,
    ProfessionsBookFrame = true, CollectionsJournal = true }
local iconButtons = setmetatable({}, { __mode = 'k' })
local contentHooks = setmetatable({}, { __mode = 'k' })
local dirX = { LEFT = -1, TOPLEFT = -1, BOTTOMLEFT = -1, RIGHT = 1, TOPRIGHT = 1, BOTTOMRIGHT = 1 }
local dirY = { TOP = 1, TOPLEFT = 1, TOPRIGHT = 1, BOTTOM = -1, BOTTOMLEFT = -1, BOTTOMRIGHT = -1 }

local function isTab(button, tabs)
    if tabs[button] then return true end
    local name = button.GetName and button:GetName()
    return type(name) == 'string' and name:find('Tab%d*$') ~= nil
end

-- SetScale also scales the anchor offset. Rewrite the single native anchor so
-- the button's centre stays where the native layout put it; an anchor on
-- another scaled icon follows that icon's shrunken edge back to its native one.
local function recentre(button)
    local state = iconButtons[button]
    if not state or state.busy or button:GetNumPoints() ~= 1 then return end
    local point, rel, relPoint, x, y = button:GetPoint(1)
    if not finite(x) or not finite(y) then return end
    local wrote = state.wrote
    if wrote and wrote.point == point and wrote.rel == rel and wrote.relPoint == relPoint
        and math.abs(wrote.x - x) < .01 and math.abs(wrote.y - y) < .01 then
        x, y = wrote.nx, wrote.ny
    end
    local k = button:GetScale() / state.base
    if not wrote and math.abs(k - 1) < .001 then return end
    local w, h = button:GetSize()
    local dx, dy = (dirX[point] or 0) * w / 2, (dirY[point] or 0) * h / 2
    local rx, ry = 0, 0
    local other = rel and rel ~= button and iconButtons[rel]
    if other then
        local rk, rw, rh = rel:GetScale() / other.base, rel:GetSize()
        rx, ry = (dirX[relPoint] or 0) * rw / 2 * (1 - rk), (dirY[relPoint] or 0) * rh / 2 * (1 - rk)
    end
    local fx, fy = (x - dx + rx) / k + dx, (y - dy + ry) / k + dy
    state.wrote = { point = point, rel = rel, relPoint = relPoint, x = fx, y = fy, nx = x, ny = y }
    state.busy = true
    button:ClearAllPoints()
    button:SetPoint(point, rel, relPoint, fx, fy)
    state.busy = nil
end

local function matchIcon(button, root, wanted)
    local w, h = button:GetSize()
    if not (finite(w) and finite(h) and w >= 12 and h >= 12) or math.abs(w - h) > .15 * math.max(w, h) then return end
    local icon = iconFor(button) or button.iconTexture
    local current = artWidth(icon, root)
    -- The icon must be the button's main artwork, not a small adornment.
    if not current or icon == button or icon:GetWidth() < w * .5 then return end
    local state = iconButtons[button]
    if not state then
        -- Buttons sized by two anchors have no free scale; leave them native.
        if button:GetNumPoints() ~= 1 then return end
        state = { base = button:GetScale() }
        iconButtons[button] = state
        hooksecurefunc(button, 'SetPoint', function(self)
            if iconButtons[self].busy then return end
            if InCombatLockdown() then module.contentPending[root] = true; return end
            pcall(recentre, self)
        end)
    end
    local scale = button:GetScale() * wanted / current
    if not finite(scale) or scale < state.base * .3 or scale > state.base * 3 then return end
    if math.abs(wanted / current - 1) > .01 then
        state.busy = true
        button:SetScale(scale)
        state.busy = nil
    end
    recentre(button)
end

-- `node` is the window itself or one ScrollBox inside it whose rows changed.
function module:DrawerContent(frame, node)
    local text, name = ns.NativeText, frame:GetName()
    if not frame:IsVisible() then return end
    local combat = InCombatLockdown()
    if combat then self.contentPending[frame] = true end
    local wanted = not combat and iconRoots[name] and actionArtWidth()
    local tabs, count = {}, 0
    for _, list in ipairs({ frame.Tabs, frame.tabs, frame.TabSystem and frame.TabSystem.tabs }) do
        if type(list) == 'table' then for _, tab in ipairs(list) do tabs[tab] = true end end
    end
    local function visit(child, depth)
        if depth > 10 or count >= 1500 or child.IsForbidden and child:IsForbidden() then return end
        count = count + 1
        local button = child ~= frame and child.IsObjectType and child:IsObjectType('Button')
        local tab = button and isTab(child, tabs)
        if text then
            if button then pcall(text.Button, text, child, tab) end
            text:Frame(child)
        end
        if not contentHooks[child] then
            -- Rows acquired by a ScrollBox and panels shown by a tab are styled
            -- when the native owner fills or shows them; nothing polls.
            if type(child.ForEachFrame) == 'function' and type(child.Update) == 'function' then
                contentHooks[child] = true
                hooksecurefunc(child, 'Update', function() module:QueueContent(frame, child) end)
            elseif depth > 0 and depth <= 2 and child.HookScript and child:GetObjectType() == 'Frame' then
                contentHooks[child] = true
                child:HookScript('OnShow', function() module:QueueContent(frame) end)
            end
        end
        if wanted and button and not tab then pcall(matchIcon, child, frame, wanted) end
        if child.GetChildren then
            for _, grandchild in ipairs({ child:GetChildren() }) do visit(grandchild, depth + 1) end
        end
    end
    visit(node or frame, node and 3 or 0)
end

function module:QueueContent(frame, node)
    node = node or frame
    if self.contentQueued[node] or frame == CharacterFrame or not drawers[frame:GetName()] then return end
    self.contentQueued[node] = true
    -- Native OnShow/tab code allocates rows and talent buttons before this runs.
    C_Timer.After(0, function()
        self.contentQueued[node] = nil
        local ok, err = pcall(self.DrawerContent, self, frame, node ~= frame and node or nil)
        if not ok then geterrorhandler()(err) end
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

-- Protected (explicitly or through a protected child) or anchor-restricted:
-- in combat such a frame can be neither moved nor used as an anchor.
local function restricted(frame)
    return frame:IsProtected() or (frame.IsAnchoringRestricted and frame:IsAnchoringRestricted()) or false
end

function module:Apply(id, frame)
    local owner = attached(frame)
    if owner then owner:Queue(); return end
    if self.applying[frame] or not frame:IsVisible() then return end
    -- Placement skipped by combat is repeated when it ends. A chat drawer is
    -- placed in combat too unless the window itself is restricted. The chat
    -- panel holds the micro menu, so it can be restricted; then the window
    -- takes the same place by rectangle on UIParent and is re-anchored to
    -- chat when combat ends. Otherwise the native panel manager's combat open
    -- (its left or centre slot) would stand until combat ends.
    local byRect
    if InCombatLockdown() then
        local chat = self:DrawerChat(id, frame)
        if not chat or restricted(frame) then self.pending = true; return end
        byRect = restricted(chat)
        if byRect then self.pending = true end
    end
    if ns.NativeWindowPlacement then ns.NativeWindowPlacement:Import(frame:GetName(), id, frame) end
    local chat = self:DrawerChat(id, frame)
    local record = ns.LayoutEditor:Read(id)
    if not chat and (not record or not finite(record.scale) or record.scale <= 0) then return end
    -- Chat is read guarded: in combat it may be a restricted frame.
    local readable, target = pcall(ns.LayoutEditor.Rect, ns.LayoutEditor, chat)
    target = chat and readable and target or nil
    local rect = chat and ns.LayoutEditor:Rect(frame)
    -- No rectangle yet (the window is still being laid out): try the next frame.
    if chat and (not target or not rect) then self:QueueSettle(id, frame); return end
    self.applying[frame] = true
    local ok, err = pcall(function()
        if chat then
            -- Width-match by scale; cap so the window fits the room above chat
            -- (rect.y is the physical-pixel distance from the screen top).
            -- The character sheet matches chat with its stats sidebar closed; an
            -- open sidebar extends past the chat at that same scale.
            local width = rect.w
            if frame == CharacterFrame then
                -- The left pane has one fixed width in the sheet's own units. Measure
                -- it while the stats shelf is open (up to the shelf's inset) and keep
                -- it; with the shelf closed the sheet may be only that wide, so the
                -- scale must not change when the shelf opens or closes.
                local full, left = frame:GetWidth(), frame:GetLeft()
                local side = CharacterFrameInsetRight
                local edge = side and side:IsShown() and side:GetLeft()
                local measured = left and edge and edge - left
                if measured and full and measured > 100 and measured < full then module.characterPane = measured end
                local pane = full and math.min(full, module.characterPane or 399)
                if pane and full and full > 0 then width = rect.w * pane / full end
            end
            local ratio = math.min(target.w / width, math.max(1, target.y - 12) / rect.h)
            -- Owner: a window much wider than chat (the talent trees) was
            -- squashed to chat's width. Such a window comes up as high as the
            -- character sheet does, widening past the chat, within the screen.
            if frame ~= CharacterFrame and CharacterFrame then
                local sheetTop = module:DrawerTop(CharacterFrame)
                local tall = sheetTop and target.y - sheetTop
                if tall and tall > rect.h * ratio + 1 then
                    local screenWidth = ns.LayoutEditor:Metrics()
                    local wide = (screenWidth - target.x - 8) / rect.w
                    ratio = math.min(tall / rect.h, wide, math.max(1, target.y - 12) / rect.h)
                end
            end
            if math.abs(ratio - 1) > 0.0005 then frame:SetScale(frame:GetScale() * ratio) end
            frame:ClearAllPoints()
            if byRect then
                -- Chat's measured top-left (physical pixels from the screen's
                -- top-left) in this window's units; UIParent spans the screen.
                local _, ph, ux, uy = ns.LayoutEditor:Metrics()
                local k = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
                frame:SetPoint('BOTTOMLEFT', UIParent, 'BOTTOMLEFT', target.x / ux * k, (ph - target.y) / uy * k)
            else
                frame:SetPoint('BOTTOMLEFT', chat, 'TOPLEFT', 0, 0)
            end
            return
        end
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
            if record.clampToScreen then
                -- Shipped placement fitted to another screen shape (DefaultSeed.lua):
                -- the window's size is first known here.
                local rect, pw, ph = ns.LayoutEditor:Rect(frame), ns.LayoutEditor:Metrics()
                if rect then
                    local x = math.max(0, math.min(rect.x, pw - rect.w))
                    local y = math.max(0, math.min(rect.y, ph - rect.h))
                    if x ~= rect.x or y ~= rect.y then ns.LayoutEditor:Place(frame, { x = x, y = y }) end
                end
            end
        end
    end)
    self.applying[frame] = nil
    if not ok then return false, err end
    return true
end

-- One more placement on the frame after a window shows. Another panel opened
-- in the same instant can make the client reposition this one while Apply's
-- own writes are being ignored, and nothing else would restate its place.
-- At most three passes per show, so a window that never resolves cannot loop.
function module:QueueSettle(id, frame)
    local tries = self.settleTries[frame] or 0
    if self.settleQueued[frame] or tries >= 3 then return end
    self.settleQueued[frame], self.settleTries[frame] = true, tries + 1
    C_Timer.After(0, function()
        self.settleQueued[frame] = nil
        if frame:IsVisible() then self:Apply(id, frame) end
    end)
end

-- Each panel open, close or relayout (ShowUIPanel, HideUIPanel,
-- UpdateUIPanelPositions) lets the native panel manager re-anchor every open
-- panel to its left/centre/right slot. With the world map open beside it,
-- the character sheet was left in the manager's centre slot although the
-- SetPoint posthooks below should have moved it back; so, not relying on
-- them, every open window is placed again right after each such call, and
-- once more next frame.
function module:Restate()
    for frame, id in pairs(self.native) do
        if frame:IsVisible() then
            self:Apply(id, frame)
            self.settleTries[frame] = nil
            self:QueueSettle(id, frame)
        end
    end
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
        commit = function(rect, resizing, automatic)
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
                placed = not automatic or (previous and previous.placed) or nil,
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
        module:QueueContent(frame)
        module:Refresh()
    end
    frame:HookScript('OnShow', update)
    frame:HookScript('OnShow', function()
        module.settleTries[frame] = nil
        module:QueueSettle(id, frame)
    end)
    if drawers[name] and frame ~= CharacterFrame then
        if ns.NativeText then ns.NativeText:ScaledRoot(frame) end
        if frame == PlayerSpellsFrame and EventRegistry then
            -- A page turn or filter re-acquires the pooled spell rows.
            EventRegistry:RegisterCallback('PlayerSpellsFrame.SpellBookFrame.DisplayedSpellsChanged',
                function() module:QueueContent(frame) end, module)
        end
    end
    if drawers[name] then
        frame:HookScript('OnShow', function()
            local chat = module:DrawerChat(id, frame)
            if chat then ns.DrawerMotion:Open(frame, chat) end
        end)
    end
    frame:HookScript('OnHide', function() module:Refresh() end)
    -- A drawer refits when its native width changes (e.g. the stats pane).
    frame:HookScript('OnSizeChanged', drawers[name] and update or function() module:Refresh() end)
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
    module:QueueContent(frame)
end

function module:Register()
    if InCombatLockdown() then self.pending = true; return end
    self.pending = nil
    if not self.questItemsHooked and type(QuestInfo_Display) == 'function' then
        self.questItemsHooked = true
        hooksecurefunc('QuestInfo_Display', function()
            if QuestFrame then module:QueueItemSizing(QuestFrame) end
        end)
    end
    for _, definition in ipairs(windows) do native(definition) end
    self.registered = true
    if not self.panelsHooked then
        self.panelsHooked = true
        -- Posthooks of the global entry points: their dispatch to the panel
        -- manager has finished when these run. Placement only, no panel calls.
        for _, name in ipairs({ 'ShowUIPanel', 'HideUIPanel', 'UpdateUIPanelPositions' }) do
            if type(_G[name]) == 'function' then hooksecurefunc(name, function() module:Restate() end) end
        end
    end
    if not self.chatHooked and ns.DarkSkin and ns.DarkSkin.LayoutChat then
        self.chatHooked = true
        hooksecurefunc(ns.DarkSkin, 'LayoutChat', function()
            for frame, id in pairs(self.native) do
                if drawers[frame:GetName()] then self:Apply(id, frame) end
            end
        end)
    end
    -- A natural show/position event in combat is deferred until this event path.
    for frame, id in pairs(self.native) do self:Apply(id, frame); self:QueueItemSizing(frame) end
    -- Icon sizing skipped in combat resumes here (PLAYER_REGEN_ENABLED).
    for frame in pairs(self.contentPending) do self.contentPending[frame] = nil; self:QueueContent(frame) end
    self:Refresh()
end

local events = CreateFrame('Frame')
events:RegisterEvent('PLAYER_LOGIN')
events:RegisterEvent('ADDON_LOADED')
events:RegisterEvent('PLAYER_REGEN_ENABLED')
events:SetScript('OnEvent', function(_, event)
    -- Combat end repeats the pass only when combat deferred part of it.
    if event == 'PLAYER_REGEN_ENABLED' and not module.pending and not next(module.contentPending) then return end
    -- A load-on-demand window (spellbook and talents, professions book,
    -- collections, ...) is created inside LoadAddOn and shown by the same
    -- call, before the deferred pass below runs: hook it now, while it is
    -- still hidden, so its first show is placed (and unfolds) in its drawer
    -- instead of drawing at the native panel position until the next frame.
    if event == 'ADDON_LOADED' and module.registered and not InCombatLockdown() then
        for _, definition in ipairs(windows) do native(definition) end
    end
    C_Timer.After(0, function() module:Register() end)
end)
