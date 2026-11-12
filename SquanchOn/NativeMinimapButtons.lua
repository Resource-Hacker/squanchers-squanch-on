-- SPDX-License-Identifier: MIT
-- Original minimap launcher strip. Discovery occurs on addon/world events and
-- LibDBIcon creation callbacks; there is no repeating child scan.
local _, ns = ...
local M = { buttons = {}, order = {} }
ns.NativeMinimapButtons = M
local events = CreateFrame("Frame")
local native = {
    MiniMapMailFrame = true, MiniMapTracking = true, MiniMapTrackingButton = true,
    MiniMapWorldMapButton = true, MinimapZoomIn = true, MinimapZoomOut = true,
    MinimapBackdrop = true, MinimapBorder = true, GameTimeFrame = true,
    QueueStatusMinimapButton = true, MiniMapBattlefieldFrame = true,
    GarrisonLandingPageMinimapButton = true, ExpansionLandingPageMinimapButton = true,
}
local function config()
    local import = ns.db and ns.db.auxiliaryImport or {}
    return import.minimapButtons or import.SquareMinimapButtons or {}
end
local function hover()
    if not M.bar then return end
    if config().BarMouseOver == false then M.bar:SetAlpha(1); return end
    local over = M.bar:IsMouseOver()
    if not over then
        for button in pairs(M.buttons) do if button:IsShown() and button:IsMouseOver() then over = true; break end end
    end
    M.bar:SetAlpha(over and 1 or 0)
end
local function queueHover()
    if M.hoverQueued then return end
    M.hoverQueued = true
    C_Timer.After(.05, function() M.hoverQueued = false; hover() end)
end
local function savePoints(frame)
    local points = {}
    for i = 1, frame:GetNumPoints() do points[i] = { frame:GetPoint(i) } end
    return points
end
function M:AddButton(button, nativeClock)
    if not button or self.buttons[button] or not button.IsObjectType or not button:IsObjectType("Button") then return end
    if InCombatLockdown() then self.pending = true; return end
    if button:IsProtected() then return end
    local name = button:GetName()
    if name and native[name] and not nativeClock then return end
    self.buttons[button] = {
        parent = button:GetParent(), points = savePoints(button), width = button:GetWidth(), height = button:GetHeight(),
    }
    local old = self.buttons[button]
    local art = button.icon or button.Icon
    if art and art.GetTexCoord then
        old.art, old.artPoints, old.coords = art, savePoints(art), { art:GetTexCoord() }
    end
    old.regions = {}
    for _, key in ipairs({ "border", "background" }) do
        local region = button[key]
        if region and region.GetAlpha then old.regions[region] = region:GetAlpha() end
    end
    self.order[#self.order + 1] = button
    button:HookScript("OnShow", function() self:QueueLayout() end)
    button:HookScript("OnHide", function() self:QueueLayout() end)
    button:HookScript("OnEnter", hover)
    button:HookScript("OnLeave", queueHover)
    -- Respect the button owner's native click, tooltip and broker callbacks.
    hooksecurefunc(button, "SetPoint", function()
        if not self.layingOut and button:GetParent() == self.bar then self:QueueLayout() end
    end)
end
function M:QueueLayout()
    if self.layoutQueued then return end
    self.layoutQueued = true
    C_Timer.After(0, function() self.layoutQueued = false; self:Layout() end)
end
function M:Layout()
    if not self.bar then return end
    if InCombatLockdown() then self.pending = true; return end
    self.pending = nil
    local cfg = config()
    local enabled = cfg.Enable ~= false and cfg.BarEnabled ~= false
    self.layingOut = true
    if not enabled then
        for button, old in pairs(self.buttons) do
            button:SetParent(old.parent)
            button:SetSize(old.width, old.height)
            button:ClearAllPoints()
            for _, point in ipairs(old.points) do button:SetPoint(unpack(point)) end
            if old.art then
                old.art:SetTexCoord(unpack(old.coords))
                old.art:ClearAllPoints()
                for _, point in ipairs(old.artPoints) do old.art:SetPoint(unpack(point)) end
            end
            for region, alpha in pairs(old.regions) do region:SetAlpha(alpha) end
            if button.SquanchOnStripBorder then button.SquanchOnStripBorder:Hide() end
        end
        self.bar:Hide()
        self.laidOut = #self.order
        self.layingOut = false
        return
    end
    local size = math.max(8, math.min(64, tonumber(cfg.IconSize) or 15))
    local gap = math.max(0, math.min(20, tonumber(cfg.ButtonSpacing) or 1))
    local columns = math.max(1, math.min(24, tonumber(cfg.ButtonsPerRow) or 1))
    table.sort(self.order, function(a, b) return (a:GetName() or "") < (b:GetName() or "") end)
    local visible = {}
    for _, button in ipairs(self.order) do if button:IsShown() then visible[#visible + 1] = button end end
    local shown = 0
    for _, button in ipairs(self.order) do
        -- IsShown is local visibility, independent of its previous parent.
        button:SetParent(self.bar)
        if button:IsShown() then
            local index = shown
            if cfg.ReverseDirection then index = #visible - shown - 1 end
            button:SetSize(size, size)
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", self.bar, "TOPLEFT", (index % columns) * (size + gap),
                -math.floor(index / columns) * (size + gap))
            local art = button.icon or button.Icon
            if art and art.SetTexCoord then art:SetTexCoord(.07, .93, .07, .93); art:ClearAllPoints(); art:SetAllPoints(button) end
            for region in pairs(self.buttons[button].regions) do region:SetAlpha(0) end
            if ns.DarkSkin then
                button.SquanchOnStripBorder = ns.DarkSkin:ControlBorder(button, "icon", self.bar, 1)
                if button.SquanchOnStripBorder then button.SquanchOnStripBorder:Show() end
            end
            shown = shown + 1
        end
    end
    self.bar:SetSize(math.max(1, math.min(columns, shown) * (size + gap) - gap),
        math.max(1, math.ceil(shown / columns) * (size + gap) - gap))
    self.bar:SetShown(shown > 0 and not self.petBattle)
    self.laidOut = #self.order
    self.layingOut = false
    hover()
end
function M:Discover(force)
    if not ns.db then return end
    if not self.bar then
        self.bar = CreateFrame("Frame", "SquanchOnMinimapButtons", UIParent)
        self.bar:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -367, 100)
        self.bar:SetFrameStrata("MEDIUM")
        self.bar:SetFrameLevel(12)
        self.bar:EnableMouse(true)
        self.bar:SetScript("OnEnter", hover)
        self.bar:SetScript("OnLeave", queueHover)
    end
    local library = LibStub and LibStub("LibDBIcon-1.0", true)
    if library then
        for _, name in ipairs(library:GetButtonList()) do self:AddButton(library:GetMinimapButton(name)) end
        if not self.brokerHook and library.RegisterCallback then
            self.brokerHook = true
            library.RegisterCallback(self, "LibDBIcon_IconCreated", function(_, button)
                self:AddButton(button); self:QueueLayout()
            end)
        end
    end
    if Minimap then
        local children = { Minimap:GetChildren() }
        for _, child in ipairs(children) do
            local name = child:GetName()
            if name and not native[name] and (name:find("LibDBIcon10_", 1, true)
                or name:find("MinimapButton", 1, true)) then self:AddButton(child) end
        end
    end
    if config().MoveGameTimeFrame ~= false and GameTimeFrame then self:AddButton(GameTimeFrame, true) end
    local garrison = GarrisonLandingPageMinimapButton or ExpansionLandingPageMinimapButton
    if garrison and config().HideGarrison ~= false and not InCombatLockdown() then
        garrison:Hide()
        if not self.garrisonHook then
            self.garrisonHook = true
            garrison:HookScript("OnShow", function(button)
                if config().HideGarrison ~= false and not InCombatLockdown() then button:Hide() end
            end)
        end
    end
    -- Discovery runs on every addon load; lay out only when it found a new
    -- launcher or a layout is still owed.
    if #self.order ~= self.laidOut or self.pending or force then self:Layout() end
end
function M:Refresh() self:Discover(true) end
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PET_BATTLE_OPENING_START")
events:RegisterEvent("PET_BATTLE_CLOSE")
events:SetScript("OnEvent", function(_, event)
    if event == "PET_BATTLE_OPENING_START" then
        M.petBattle = true
        if M.bar then M.bar:Hide() end
    else
        if event == "PET_BATTLE_CLOSE" then M.petBattle = nil end
        if event == "PLAYER_REGEN_ENABLED" and not M.pending then return end
        if M.discoveryQueued then return end
        M.discoveryQueued = true
        local force = event ~= "ADDON_LOADED"
        C_Timer.After(0, function() M.discoveryQueued = false; M:Discover(force) end)
    end
end)
