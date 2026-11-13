-- SPDX-License-Identifier: MIT
-- One inventory window that unfolds leftward out of the minimap panel.
--
-- Ownership:
--   * The game keeps deciding WHEN bags are open. Its container frames are
--     parked under a hidden parent (never hidden, replaced or called), so every
--     keybind, bag-slot click, merchant/mail/bank open and close, and Escape
--     (CloseAllWindows -> CloseAllBags) still runs the stock code. This window
--     only mirrors "is any stock container frame shown" one frame later.
--     It is therefore not in UISpecialFrames: Escape reaches it through the
--     stock close, and it stays open exactly when stock bags would.
--   * Item cells are the client's own ContainerFrameItemButtonTemplate buttons.
--     The template reads its bag from the parent frame's ID and its slot from
--     its own ID, so each bag has one ID-carrying parent and no button field
--     the click path reads is written here. Use, equip, split, drag, sell and
--     socket are the template's own handlers.
--   * Buttons are created and laid out only out of combat (all slots are
--     pre-created after login and when a bag changes size). In combat the
--     window opens with what exists and keeps updating icons in place.
--   * Nothing runs while the window is hidden except dirty flags.
local _, ns = ...
local Bags = {
    defaults = { enable = true, columnMode = 'auto', columns = 12, cellMode = 'action', cellSize = 32, spacing = 0,
        grouping = 'none', junkDim = true, quality = true, newGlow = true, money = true, search = true,
        sort = 'forward', animation = true, anchor = 'minimap', scale = 1, keyring = false },
    buttons = {}, -- bag -> { slot -> button }
    hosts = {},   -- bag -> parent frame whose ID is the bag
    sizes = {},   -- bag -> slot count the buttons were built for
    tracked = {}, -- bag -> true while it is part of the window
    bags = {},    -- ordered bag list
    titles = {},
}
ns.Bags = Bags

local WHITE = [[Interface\Buttons\WHITE8X8]]
local PAD, ROW, TITLE = 8, 22, 12
local KEYRING = _G.KEYRING_CONTAINER or (Enum and Enum.BagIndex and Enum.BagIndex.Keyring) or -2
local cells = {}  -- button -> state
local dirty = {}  -- bag -> true

function Bags:Setting(key)
    local values = ns.db and ns.db.bags
    local value
    if type(values) == 'table' then value = values[key] end
    if value == nil then return self.defaults[key] end
    return value
end
-- Sparse: a value equal to the shipped default removes the key.
function Bags:Set(key, value)
    local db = ns.db
    if not db then return end
    if type(db.bags) ~= 'table' then db.bags = {} end
    if value == self.defaults[key] then value = nil end
    db.bags[key] = value
end

local function keyringAvailable()
    return C_ActionBar and C_ActionBar.ShouldShowKeyring and C_ActionBar.ShouldShowKeyring() and GetKeyRingSize and true or false
end
Bags.KeyringAvailable = keyringAvailable

local function slotCount(bag)
    if bag == KEYRING then return GetKeyRingSize and GetKeyRingSize() or 0 end
    return C_Container.GetContainerNumSlots(bag) or 0
end

local function bagList()
    local constants = Constants and Constants.InventoryConstants
    local held = constants and constants.NumBagSlots or NUM_BAG_SLOTS or 4
    local reagent = constants and constants.NumReagentBagSlots or 0
    local list = {}
    for bag = 0, held + reagent do list[#list + 1] = bag end
    if Bags:Setting('keyring') and keyringAvailable() then list[#list + 1] = KEYRING end
    return list
end

-- Item cells -----------------------------------------------------------------
local function createButton(self, bag, slot)
    local host = self.hosts[bag]
    if not host then
        host = CreateFrame('Frame', nil, self.grid)
        host:SetID(bag)
        host:SetAllPoints(self.grid)
        self.hosts[bag], self.buttons[bag] = host, {}
    end
    local name = 'SquanchOnBagItem' .. (bag < 0 and 'K' or bag) .. '_' .. slot
    local button = CreateFrame('ItemButton', name, host, 'ContainerFrameItemButtonTemplate')
    button:SetID(slot)
    -- Action-bar cell proportions: a 37-unit icon on a 43-unit pitch. The cell
    -- is scaled as a whole, so the template's art and count text keep their fit.
    button:SetSize(43, 43)
    button:SetFrameLevel(self.frame:GetFrameLevel() + 6)
    local icon = button.icon or button.Icon or _G[name .. 'IconTexture']
    if not icon then icon = button:CreateTexture(nil, 'BORDER') end
    icon:ClearAllPoints()
    icon:SetPoint('CENTER', button, 'CENTER')
    icon:SetSize(37, 37)
    icon:SetTexCoord(.07, .93, .07, .93)
    for _, key in ipairs({ 'IconBorder', 'IconOverlay', 'IconOverlay2', 'IconQuestTexture', 'EmptyBagIcon', 'searchOverlay',
        'ItemContextOverlay', 'NewItemTexture', 'BattlepayItemTexture', 'flash', 'ExtendedSlot', 'Cooldown' }) do
        local region = button[key]
        if region and region.SetAllPoints then region:ClearAllPoints(); region:SetAllPoints(icon) end
    end
    for _, key in ipairs({ 'IconBorder', 'BattlepayItemTexture', 'EmptyBagIcon', 'ExtendedSlot' }) do
        if button[key] then button[key]:Hide() end
    end
    -- The shared slot rim replaces the template's neutral slot art.
    local normal = button.GetNormalTexture and button:GetNormalTexture()
    if normal then normal:SetAlpha(0) end
    for _, method in ipairs({ 'GetPushedTexture', 'GetHighlightTexture' }) do
        local texture = button[method] and button[method](button)
        if texture then texture:ClearAllPoints(); texture:SetAllPoints(icon) end
    end
    if ns.DarkSkin and ns.DarkSkin.RawSlotBorder then ns.DarkSkin:RawSlotBorder(button, self.frame, 1) end
    cells[button] = { icon = icon, bag = bag, slot = slot }
    self.buttons[bag][slot] = button
    button:Show()
    return button
end

local function qualityColor(quality)
    if C_Item and C_Item.GetItemQualityColor then
        local r, g, b = C_Item.GetItemQualityColor(quality)
        if r then return r, g, b end
    end
    local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if color then return color.r, color.g, color.b end
end

-- A thin line just inside the icon; the gold cell rim stays untouched.
local function qualityLines(button, state)
    local lines = state.lines
    if lines then return lines end
    lines = {}
    for index = 1, 4 do
        lines[index] = button:CreateTexture(nil, 'OVERLAY', nil, 1)
        lines[index]:SetTexture(WHITE)
    end
    local icon = state.icon
    lines[1]:SetPoint('TOPLEFT', icon); lines[1]:SetPoint('TOPRIGHT', icon)
    lines[2]:SetPoint('BOTTOMLEFT', icon); lines[2]:SetPoint('BOTTOMRIGHT', icon)
    lines[3]:SetPoint('TOPLEFT', icon); lines[3]:SetPoint('BOTTOMLEFT', icon)
    lines[4]:SetPoint('TOPRIGHT', icon); lines[4]:SetPoint('BOTTOMRIGHT', icon)
    state.lines = lines
    return lines
end

local function updateCooldown(button, state)
    local cooldown = button.Cooldown
    if not cooldown then return end
    if not state.sig or not C_Container.GetContainerItemCooldown or not CooldownFrame_Set then cooldown:Hide(); return end
    -- pcall: a client that hands out restricted cooldown values keeps the old sweep.
    pcall(function()
        local start, duration, enable = C_Container.GetContainerItemCooldown(state.bag, state.slot)
        CooldownFrame_Set(cooldown, start, duration, enable)
    end)
end

-- Search dims non-matches; junk dimming applies when nothing is searched.
local function applyDim(self, button, state)
    local alpha = 1
    local query = self.query
    if query then
        if state.search and not state.search:find(query, 1, true) then alpha = .2 end
    elseif state.junk and self:Setting('junkDim') then
        alpha = .4
    end
    if state.alpha == alpha then return end
    state.alpha = alpha
    state.icon:SetAlpha(alpha)
    if button.Count then button.Count:SetAlpha(alpha) end
    if state.lines then for _, line in ipairs(state.lines) do line:SetAlpha(alpha) end end
end

local function updateSlot(self, button, force)
    local state = cells[button]
    local bag, slot = state.bag, state.slot
    local info = C_Container.GetContainerItemInfo(bag, slot)
    local link = info and info.hyperlink
    local count = info and info.stackCount or 0
    local locked = info and info.isLocked and true or false
    local texture = info and info.iconFileID
    local sig = texture and (tostring(link) .. '|' .. tostring(count) .. '|' .. tostring(locked)) or false
    if not force and state.sig == sig then return end
    state.sig = sig

    local icon = state.icon
    icon:SetTexture(texture)
    icon:SetShown(texture ~= nil)
    icon:SetDesaturated(locked)
    if SetItemButtonCount then SetItemButtonCount(button, count) end
    -- Hover-only state of the template (cursor choice and tooltip refresh).
    button.hasItem = texture and 1 or nil
    button.readable = info and info.isReadable or nil

    local quality = info and info.quality
    if type(quality) ~= 'number' then quality = nil end
    local itemID = info and info.itemID
    local class
    if itemID then
        local instant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
        local _, itemType, subType, _, _, classID
        if instant then _, itemType, subType, _, _, classID = instant(itemID) end
        class = classID
        local name = info.itemName or (link and link:match('%[(.-)%]')) or ''
        local qualityName = quality and _G['ITEM_QUALITY' .. quality .. '_DESC'] or ''
        state.search = (tostring(name) .. '\n' .. tostring(itemType or '') .. '\n' .. tostring(subType or '') .. '\n'
            .. tostring(qualityName)):lower()
    else
        state.search = nil
    end
    if state.class ~= class then state.class = class; self.groupDirty = true end
    state.junk = texture ~= nil and quality == 0 and not info.hasNoValue

    local r, g, b
    if quality and quality >= 2 and self:Setting('quality') then r, g, b = qualityColor(quality) end
    if r then
        local lines, size = qualityLines(button, state), self.lineSize or 1.5
        for index, line in ipairs(lines) do
            line:SetVertexColor(r, g, b, 1)
            if index <= 2 then line:SetHeight(size) else line:SetWidth(size) end
            line:Show()
        end
    elseif state.lines then
        for _, line in ipairs(state.lines) do line:Hide() end
    end

    if button.UpdateQuestItem and C_Container.GetContainerItemQuestInfo then
        local quest = C_Container.GetContainerItemQuestInfo(bag, slot)
        pcall(button.UpdateQuestItem, button, quest and quest.isQuestItem, quest and quest.questID, quest and quest.isActive)
    end
    if button.UpdateNewItem and self:Setting('newGlow') then
        pcall(button.UpdateNewItem, button, quality)
    else
        if button.NewItemTexture then button.NewItemTexture:Hide() end
        if button.BattlepayItemTexture then button.BattlepayItemTexture:Hide() end
        if button.flashAnim and button.flashAnim:IsPlaying() then button.flashAnim:Stop() end
        if button.newitemglowAnim and button.newitemglowAnim:IsPlaying() then button.newitemglowAnim:Stop() end
    end
    if button.JunkIcon then
        button.JunkIcon:SetShown(state.junk and MerchantFrame and MerchantFrame:IsShown() or false)
    end
    updateCooldown(button, state)
    state.alpha = nil
    applyDim(self, button, state)
    if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(button) then
        if texture and button.UpdateTooltip then pcall(button.UpdateTooltip, button) else GameTooltip:Hide() end
    end
end

local function eachShown(self, fn)
    for _, bag in ipairs(self.bags) do
        local row = self.buttons[bag]
        for slot = 1, row and self.sizes[bag] or 0 do fn(row[slot]) end
    end
end

function Bags:ApplySearch()
    eachShown(self, function(button) applyDim(self, button, cells[button]) end)
end

-- Creates missing buttons and hides surplus ones. Out of combat only.
function Bags:EnsureButtons()
    if not self.frame then return end
    if InCombatLockdown() then self.sizeDirty = true; return end
    self.sizeDirty = false
    local list, tracked = bagList(), {}
    for _, bag in ipairs(list) do
        tracked[bag] = true
        local count = slotCount(bag)
        local row = self.buttons[bag]
        for slot = (row and #row or 0) + 1, count do createButton(self, bag, slot) end
        row = self.buttons[bag]
        if row then for slot, button in ipairs(row) do button:SetShown(slot <= count) end end
        if self.sizes[bag] ~= count then
            self.sizes[bag] = count
            self.layoutDirty, dirty[bag] = true, true
        end
    end
    for bag, row in pairs(self.buttons) do
        if not tracked[bag] and (self.sizes[bag] or 0) ~= 0 then
            for _, button in ipairs(row) do button:Hide() end
            self.sizes[bag] = 0
            self.layoutDirty = true
        end
    end
    self.bags, self.tracked = list, tracked
end

-- Header ---------------------------------------------------------------------
local function label(parent, size, r, g, b)
    local W = ns.OptionWidgets
    if W and W.Label then return W:Label(parent, '', size, r, g, b) end
    local font = parent:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    if r then font:SetTextColor(r, g, b) end
    return font
end

function Bags:UpdateMoney()
    if not self.money or not self.money:IsVisible() then return end
    local format = C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString or GetCoinTextureString
    local amount = GetMoney and GetMoney() or 0
    self.money:SetText(format and format(amount) or tostring(amount))
end

function Bags:UpdateFree()
    if not self.free then return end
    local free, total = 0, 0
    for _, bag in ipairs(self.bags) do
        if bag ~= KEYRING then
            total = total + (self.sizes[bag] or 0)
            free = free + (C_Container.GetContainerNumFreeSlots and C_Container.GetContainerNumFreeSlots(bag) or 0)
        end
    end
    self.free:SetText(free .. '/' .. total)
end

-- Open motion ----------------------------------------------------------------
-- DrawerMotion grows its proxy shell upward only (bottom anchors + SetHeight).
-- This is the same two-step motion on the other axis: an empty shell grows
-- leftward from the window's right edge, then the content fades in. The window
-- is addon-owned, so its own alpha is animated; cell rims follow it because the
-- window is their alpha owner.
function Bags:StopOpen()
    local proxy = self.proxy
    if not self.opening then return end
    self.opening = nil
    if proxy then proxy:SetScript('OnUpdate', nil); proxy:Hide() end
    self.frame:SetAlpha(1)
end

function Bags:PlayOpen()
    local frame, motion, skin = self.frame, ns.DrawerMotion, ns.DarkSkin
    if not skin or not self:Setting('animation') then return end
    if motion and motion.Setting and motion:Setting('style') == 'none' then return end
    local grow = math.max(.05, tonumber(motion and motion.Setting and motion:Setting('grow')) or .35)
    local fade = math.max(.05, tonumber(motion and motion.Setting and motion:Setting('fade')) or .15)
    local full = frame:GetWidth()
    if not full or full <= 1 then return end
    local proxy = self.proxy
    if not proxy then
        proxy = CreateFrame('Frame', nil, UIParent)
        proxy:Hide(); proxy:EnableMouse(false)
        proxy.ignoreInLayout = true
        proxy.fill = proxy:CreateTexture(nil, 'BACKGROUND', nil, -8)
        proxy.border = skin:Panel(proxy, 'dialog', 0)
        self.proxy = proxy
    end
    proxy:SetFrameStrata(frame:GetFrameStrata())
    proxy:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
    proxy:SetScale(frame:GetEffectiveScale() / UIParent:GetEffectiveScale())
    proxy:ClearAllPoints()
    proxy:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', 0, 0)
    proxy:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', 0, 0)
    local least = math.min(16, full)
    proxy:SetWidth(least)
    proxy:SetAlpha(1)
    skin:StylePanelBackground(proxy.fill, proxy.border)
    self.opening = true
    frame:SetAlpha(0)
    local elapsed = 0
    proxy:SetScript('OnUpdate', function(_, delta)
        elapsed = elapsed + delta
        if elapsed >= grow + fade or not frame:IsShown() then self:StopOpen(); return end
        if elapsed < grow then
            local eased = 1 - (1 - elapsed / grow) ^ 3
            proxy:SetWidth(math.max(least, full * eased))
        else
            local t = (elapsed - grow) / fade
            proxy:SetWidth(full)
            proxy:SetAlpha(1 - t)
            frame:SetAlpha(t)
        end
    end)
    proxy:Show()
end

-- Layout ---------------------------------------------------------------------
local function sections(self)
    local all = {}
    if self:Setting('grouping') ~= 'class' then
        local list = {}
        eachShown(self, function(button) list[#list + 1] = button end)
        all[1] = { buttons = list }
        return all
    end
    local byClass, order, empty = {}, {}, {}
    eachShown(self, function(button)
        local class = cells[button].class
        if class == nil then empty[#empty + 1] = button; return end
        if not byClass[class] then byClass[class] = {}; order[#order + 1] = class end
        local list = byClass[class]
        list[#list + 1] = button
    end)
    table.sort(order)
    local classInfo = C_Item and C_Item.GetItemClassInfo or GetItemClassInfo
    for _, class in ipairs(order) do
        all[#all + 1] = { title = classInfo and classInfo(class) or tostring(class), buttons = byClass[class] }
    end
    if #empty > 0 then all[#all + 1] = { title = EMPTY or 'Empty', buttons = empty } end
    return all
end

local function gridHeight(list, columns, pitch, spacing)
    local height = 0
    for _, section in ipairs(list) do
        if section.title then height = height + TITLE end
        height = height + math.ceil(#section.buttons / columns) * pitch
    end
    return math.max(0, height - spacing)
end

-- The panel's painted rim reaches this far outside its own rectangle (same
-- measure the quest drawer uses), in panel units.
local function panelOutside(panel)
    local spec = ns.DarkSkin and ns.DarkSkin.styles and ns.DarkSkin.styles.minimap
    if not spec then return 0 end
    local pixel = PixelUtil and PixelUtil.GetPixelToUIUnitFactor and PixelUtil.GetPixelToUIUnitFactor() / panel:GetEffectiveScale() or 0
    return math.max(0, spec.edge * 9 / 13 - pixel / 2 - spec.edge * 5 / 13)
end

local function settingsSignature(self)
    local parts = {}
    for _, key in ipairs({ 'columnMode', 'columns', 'cellMode', 'cellSize', 'spacing', 'grouping', 'money', 'search',
        'anchor', 'scale', 'keyring' }) do parts[#parts + 1] = tostring(self:Setting(key)) end
    local panel = ns.MinimapPanel and ns.MinimapPanel.frame
    if panel then parts[#parts + 1] = string.format('%.2f|%.3f', panel:GetHeight(), panel:GetScale()) end
    return table.concat(parts, '|')
end

function Bags:Layout()
    local frame = self.frame
    if not frame then return end
    if InCombatLockdown() then self.layoutDirty = true; return end
    self.layoutDirty, self.groupDirty = false, false
    self.signature = settingsSignature(self)
    local panel = ns.MinimapPanel and ns.MinimapPanel.frame
    local scale = math.min(2, math.max(.5, tonumber(self:Setting('scale')) or 1))
    -- Same scale as the panel, so both gold rims are the same thickness.
    frame:SetScale((panel and panel:GetScale() or 1) * scale)
    local effective, ui = frame:GetEffectiveScale(), UIParent:GetEffectiveScale()

    local cell
    if self:Setting('cellMode') == 'action' then
        local owner = ns.LayoutWindows
        local art = owner and owner.ActionArtWidth and owner:ActionArtWidth()
        if art then cell = art * 43 / 37 / effective end
        self.cellPending = not art -- the bars were not laid out yet: measure again at the next open
    else
        self.cellPending = false
    end
    if not cell then cell = (tonumber(self:Setting('cellSize')) or 32) * ui / effective end
    local spacing = math.max(0, tonumber(self:Setting('spacing')) or 0) * ui / effective
    local pitch = cell + spacing
    local pixel = PixelUtil and PixelUtil.GetPixelToUIUnitFactor and PixelUtil.GetPixelToUIUnitFactor() or 1
    self.lineSize = math.max(1, 2 * pixel / (effective * cell / 43))

    -- Header: search left; sort, free slots and money from the right. Money
    -- drops to a second row when the window is too narrow for both.
    local showSearch, showMoney = self:Setting('search') and self.search ~= nil, self:Setting('money')
    local list = sections(self)
    local total = 0
    for _, section in ipairs(list) do total = total + #section.buttons end

    local target
    if panel then target = (panel:GetHeight() + panelOutside(panel) * 2) * panel:GetEffectiveScale() / effective end
    local function chrome(columns)
        local width = columns * pitch - spacing
        local rows = (showSearch and showMoney and width < 230) and 2 or 1
        return PAD * 2 + rows * ROW + 4, rows
    end
    -- Column rule. Fixed: the chosen count. Auto: the fewest columns (at least
    -- enough for the header) whose rows fit in the minimap panel's painted
    -- height; the window then takes exactly that height and any spare sits
    -- between the header and the grid.
    local least = math.max(1, math.ceil(120 / pitch))
    local columns = math.max(least, math.floor(tonumber(self:Setting('columns')) or 12))
    local auto = self:Setting('columnMode') ~= 'fixed' and target ~= nil
    if auto then
        columns = nil
        for candidate = least, math.max(least, 40) do
            if chrome(candidate) + gridHeight(list, candidate, pitch, spacing) <= target then columns = candidate; break end
        end
        if not columns then columns, auto = math.max(least, 40), false end
    end
    local chromeHeight, rows = chrome(columns)
    local gridH = gridHeight(list, columns, pitch, spacing)
    local width = PAD * 2 + columns * pitch - spacing
    local height = chromeHeight + gridH
    if auto and target > height then height = target end
    frame:SetSize(width, height)

    local grid = self.grid
    grid:ClearAllPoints()
    grid:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', PAD, PAD)
    grid:SetSize(math.max(1, width - PAD * 2), math.max(1, gridH))

    local cellScale = cell / 43
    local y, titleIndex = 0, 0
    for _, section in ipairs(list) do
        if section.title then
            titleIndex = titleIndex + 1
            local title = self.titles[titleIndex]
            if not title then
                local color = ns.DarkSkin and ns.DarkSkin.headerTextColor or { .9, .684, .378 }
                title = label(grid, 9, color[1], color[2], color[3])
                self.titles[titleIndex] = title
            end
            title:ClearAllPoints()
            title:SetPoint('TOPLEFT', grid, 'TOPLEFT', 2, -y)
            title:SetText(section.title)
            title:Show()
            y = y + TITLE
        end
        for index, button in ipairs(section.buttons) do
            local column, row = (index - 1) % columns, math.floor((index - 1) / columns)
            button:SetScale(cellScale)
            button:ClearAllPoints()
            button:SetPoint('TOPLEFT', grid, 'TOPLEFT', column * pitch / cellScale, -(y + row * pitch) / cellScale)
        end
        y = y + math.ceil(#section.buttons / columns) * pitch
    end
    for index = titleIndex + 1, #self.titles do self.titles[index]:Hide() end

    local right = -PAD
    if self.sort then
        self.sort:ClearAllPoints()
        self.sort:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', right, -PAD)
        right = right - self.sort:GetWidth() - 6
    end
    self.free:ClearAllPoints()
    self.free:SetPoint('RIGHT', frame, 'TOPRIGHT', right, -PAD - ROW / 2 + 1)
    self.money:SetShown(showMoney and true or false)
    self.money:ClearAllPoints()
    if rows == 2 then
        self.money:SetPoint('RIGHT', frame, 'TOPRIGHT', -PAD, -PAD - ROW * 1.5)
    else
        self.money:SetPoint('RIGHT', self.free, 'LEFT', -8, 0)
    end
    if self.search then
        self.search:SetShown(showSearch and true or false)
        if showSearch then
            self.search:ClearAllPoints()
            self.search:SetPoint('TOPLEFT', frame, 'TOPLEFT', PAD, -PAD)
            local taken = (self.sort and self.sort:GetWidth() + 6 or 0) + 44 + (rows == 1 and showMoney and 96 or 0)
            self.search:SetWidth(math.max(40, math.min(140, width - PAD * 2 - taken)))
        end
    end

    -- Place: right edge on the panel's left edge, painted bottoms level.
    local editor = ns.LayoutEditor
    local record = self:Setting('anchor') == 'free' and editor and editor:Read('bags')
    frame:ClearAllPoints()
    if record and record.w then
        frame:SetPoint('CENTER', UIParent, 'CENTER')
        editor:ScaleToWidth(frame, record.w)
        editor:Place(frame, record)
    elseif panel then
        frame:SetPoint('BOTTOMRIGHT', panel, 'BOTTOMLEFT', 0, -panelOutside(panel) * panel:GetEffectiveScale() / effective)
    else
        frame:SetPoint('BOTTOMRIGHT', UIParent, 'BOTTOMRIGHT', -260, 120)
    end
    self:UpdateMoney()
end

-- Marks the layout stale; applied at once while the window is open (out of
-- combat), otherwise at the next open. `repaint` also redraws every cell and
-- `rebuild` rechecks which bags and slots exist.
function Bags:Refresh(repaint, rebuild)
    if not self.frame then return end
    self.layoutDirty = true
    if rebuild then self.sizeDirty = true end
    if self.frame:IsShown() then self:Queue(repaint) end
end

-- Updates --------------------------------------------------------------------
function Bags:Flush()
    local frame = self.frame
    if not frame or not frame:IsShown() then return end
    if self.sizeDirty then self:EnsureButtons() end
    local force = self.force
    self.force = nil
    for _, bag in ipairs(self.bags) do
        if dirty[bag] or force then
            dirty[bag] = nil
            local row = self.buttons[bag]
            for slot = 1, row and self.sizes[bag] or 0 do updateSlot(self, row[slot], force) end
        end
    end
    if self.cooldownDirty then
        self.cooldownDirty = nil
        if not force then eachShown(self, function(button) updateCooldown(button, cells[button]) end) end
    end
    if self.groupDirty and self:Setting('grouping') == 'class' then self.layoutDirty = true end
    self.groupDirty = false
    if self.layoutDirty then self:Layout() end
    self:UpdateFree()
end

-- One pass per rendered frame, however many events arrived.
function Bags:Queue(force)
    if force then self.force = true end
    if self.queued then return end
    self.queued = true
    C_Timer.After(0, function() self.queued = false; self:Flush() end)
end

-- Window ---------------------------------------------------------------------
function Bags:Build()
    if self.frame then return self.frame end
    local skin = ns.DarkSkin
    local frame = CreateFrame('Frame', 'SquanchOnBags', UIParent)
    frame:Hide()
    frame:SetFrameStrata('MEDIUM'); frame:SetFrameLevel(2)
    frame:EnableMouse(true) -- gaps do not click through to the world
    frame:SetSize(200, 100)
    frame:SetPoint('BOTTOMRIGHT', UIParent, 'BOTTOMRIGHT', -260, 120)
    self.frame = frame
    if skin then
        frame.fill = frame:CreateTexture(nil, 'BACKGROUND', nil, -8)
        local rim = skin:Panel(frame, 'dialog', 0)
        skin:StylePanelBackground(frame.fill, rim)
        -- Title plate straddling the top rim, the quest drawer's numbers. A
        -- child of the window (shows and fades with it); it takes no mouse.
        local plate = CreateFrame('Frame', nil, frame)
        plate:SetSize(76, 18)
        -- Centred on the top rim, like every other title plate (owner, 2026-11-12).
        plate:SetPoint('BOTTOM', frame, 'TOP', 0, -4)
        plate:SetFrameLevel(rim:GetFrameLevel() + 2)
        skin:RaisedPlate(plate, 'compact')
        local heading = skin.headerTextColor
        local title = label(plate, 8, heading[1], heading[2], heading[3])
        title:SetAllPoints(plate); title:SetJustifyH('CENTER')
        title:SetText('Bags')
    end
    self.grid = CreateFrame('Frame', nil, frame)
    self.free = label(frame, 10)
    self.money = label(frame, 10)

    local W = ns.OptionWidgets
    if W and W.Edit then
        local search = W:Edit(frame, 120)
        search:SetHeight(ROW - 2)
        local hint = label(search, 10, .5, .5, .5)
        hint:SetPoint('LEFT', search, 'LEFT', 6, 0)
        hint:SetText(SEARCH or 'Search')
        local function changed()
            local text = search:GetText() or ''
            text = text:gsub('^%s+', ''):gsub('%s+$', ''):lower()
            hint:SetShown(text == '' and not search:HasFocus())
            local query = text ~= '' and text or nil
            if query ~= self.query then self.query = query; self:ApplySearch() end
        end
        search:SetScript('OnTextChanged', changed)
        search:HookScript('OnEditFocusGained', changed)
        search:HookScript('OnEditFocusLost', changed)
        self.search = search
    end
    if W and W.SmallButton and C_Container.SortBags then
        self.sort = W:SmallButton(frame, 'Sort', 40, function()
            if InCombatLockdown() then return end
            if C_Container.SetSortBagsRightToLeft then
                C_Container.SetSortBagsRightToLeft(self:Setting('sort') == 'reverse')
            end
            C_Container.SortBags()
            if PlaySound and SOUNDKIT and SOUNDKIT.UI_BAG_SORTING_01 then PlaySound(SOUNDKIT.UI_BAG_SORTING_01) end
        end)
    end

    frame:SetScript('OnShow', function()
        if not InCombatLockdown() then
            if self.sizeDirty then self:EnsureButtons() end
            if self.layoutDirty or self.cellPending or self.signature ~= settingsSignature(self) then self:Layout() end
        end
        self.force = true
        self:Flush()
        self:UpdateMoney()
        if PlaySound and SOUNDKIT and SOUNDKIT.IG_BACKPACK_OPEN then PlaySound(SOUNDKIT.IG_BACKPACK_OPEN) end
        self:PlayOpen()
    end)
    frame:SetScript('OnHide', function()
        self:StopOpen()
        if self.search then
            self.search:ClearFocus()
            if self.query then self.search:SetText('') end
        end
        if PlaySound and SOUNDKIT and SOUNDKIT.IG_BACKPACK_CLOSE then PlaySound(SOUNDKIT.IG_BACKPACK_CLOSE) end
    end)
    -- Mouselook is released while the window is open.
    if ns.TrackMenuFrame then ns:TrackMenuFrame(frame) end
    return frame
end

-- /sqedit handle. Moving or resizing it there switches the anchor to "free".
function Bags:RegisterEditor()
    local editor = ns.LayoutEditor
    if self.editorRegistered or not editor or not editor.Register then return end
    self.editorRegistered = true
    editor:Register({ id = 'bags', label = 'Bags', resize = 'scale', minWidth = 100,
        getFrame = function() return self.frame end,
        snapshot = function()
            return { record = editor:Copy(editor:Read('bags')), anchor = self:Setting('anchor') }
        end,
        commit = function(rect)
            if InCombatLockdown() then return false, 'Combat' end
            editor:Store('bags', rect)
            self:Set('anchor', 'free')
            self:Layout()
        end,
        restore = function(saved)
            if InCombatLockdown() then return end
            editor:Store('bags', saved and saved.record or nil)
            self:Set('anchor', saved and saved.anchor or 'minimap')
            self:Layout()
        end,
    })
end

-- Stock container frames -------------------------------------------------------
local stock = {}
local parking
local function park()
    for _, frame in ipairs(stock) do
        if frame:GetParent() ~= parking then frame:SetParent(parking) end
    end
end
local function sync()
    Bags.syncQueued = false
    local frame = Bags.frame
    if not frame then return end
    local open = false
    for _, container in ipairs(stock) do
        if container:IsShown() then open = true; break end
    end
    if open ~= frame:IsShown() then frame:SetShown(open) end
end
-- Deferred one frame: ToggleAllBags closes and reopens within one call.
local function queueSync()
    if Bags.syncQueued then return end
    Bags.syncQueued = true
    C_Timer.After(0, sync)
end

function Bags:TakeOverStock()
    if parking then return end
    parking = CreateFrame('Frame', nil, UIParent)
    parking:Hide()
    local function add(frame)
        if not frame or frame.IsForbidden and frame:IsForbidden() then return end
        stock[#stock + 1] = frame
        for _, method in ipairs({ 'Show', 'Hide', 'SetShown' }) do hooksecurefunc(frame, method, queueSync) end
    end
    add(_G.ContainerFrameCombinedBags)
    for index = 1, math.max(_G.NUM_CONTAINER_FRAMES or 0, 13) do add(_G['ContainerFrame' .. index]) end
    park()
    -- The stock code moves its frames to a fullscreen parent and back.
    for _, name in ipairs({ 'ContainerFrame_SetFullScreenFrame', 'ContainerFrame_ClearFullScreenFrame' }) do
        if type(_G[name]) == 'function' then hooksecurefunc(name, park) end
    end
    queueSync()
end

-- Events ---------------------------------------------------------------------
local events = CreateFrame('Frame')
local function settle()
    if InCombatLockdown() then return end
    if Bags.sizeDirty then Bags:EnsureButtons() end
end
local handlers = {
    BAG_UPDATE = function(bag)
        if not Bags.tracked[bag] then return end
        dirty[bag] = true
        if slotCount(bag) ~= Bags.sizes[bag] then Bags.sizeDirty = true end
    end,
    BAG_UPDATE_DELAYED = function()
        if Bags.frame:IsShown() then Bags:Queue() else settle() end
    end,
    BAG_CONTAINER_UPDATE = function()
        Bags.sizeDirty = true
        if Bags.frame:IsShown() then Bags:Queue() else settle() end
    end,
    PLAYER_REGEN_ENABLED = function()
        if Bags.frame:IsShown() then
            if Bags.sizeDirty or Bags.layoutDirty then Bags:Queue() end
        else
            settle()
        end
    end,
    ITEM_LOCK_CHANGED = function(bag, slot)
        if not slot or not Bags.frame:IsShown() then return end
        local row = Bags.buttons[bag]
        local button = row and row[slot]
        if button and Bags.tracked[bag] then updateSlot(Bags, button, true) end
    end,
    BAG_UPDATE_COOLDOWN = function()
        if not Bags.frame:IsShown() then return end
        Bags.cooldownDirty = true
        Bags:Queue()
    end,
    PLAYER_MONEY = function() Bags:UpdateMoney() end,
    UNIT_QUEST_LOG_CHANGED = function(unit)
        if unit == 'player' and Bags.frame:IsShown() then Bags:Queue(true) end
    end,
}
-- State that changes without the item changing: repaint every cell once.
for _, event in ipairs({ 'MERCHANT_SHOW', 'MERCHANT_CLOSED', 'BAG_NEW_ITEMS_UPDATED', 'QUEST_ACCEPTED' }) do
    handlers[event] = function() if Bags.frame:IsShown() then Bags:Queue(true) end end
end

function Bags:Start()
    if self.started then return end
    if not self:Setting('enable') then return end
    if not C_Container or not C_Container.GetContainerItemInfo or not ns.DarkSkin then return end
    if InCombatLockdown() then self.startPending = true; return end
    self.started, self.startPending = true, nil
    self:Build()
    self.sizeDirty, self.layoutDirty = true, true
    self:TakeOverStock()
    self:RegisterEditor()
    for event in pairs(handlers) do pcall(events.RegisterEvent, events, event) end
    if ns.MinimapPanel and ns.MinimapPanel.LayoutStack then
        hooksecurefunc(ns.MinimapPanel, 'LayoutStack', function() self:Refresh() end)
    end
    -- Bag sizes and the action-bar art are final a moment after login.
    C_Timer.After(1, function()
        if InCombatLockdown() then return end
        self:EnsureButtons()
        self:Layout()
    end)
end

events:RegisterEvent('PLAYER_LOGIN')
events:RegisterEvent('PLAYER_REGEN_ENABLED')
events:SetScript('OnEvent', function(_, event, ...)
    if event == 'PLAYER_LOGIN' or Bags.startPending then Bags:Start() end
    if not Bags.started then return end
    local handler = handlers[event]
    if handler then handler(...) end
end)
