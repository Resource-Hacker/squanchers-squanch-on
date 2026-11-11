-- SPDX-License-Identifier: MIT
-- One migration per selected owner profile; later owner font choices win.
local _, ns = ...
local Text = {}
ns.OwnedText = Text
local events = CreateFrame("Frame")
local tooltipHooked, queued = false, false

local function receipts(owner)
    local db = SquanchOnDB
    if not db then return end
    db.gearAtlasProbe = nil
    db.appearance = db.appearance or {}
    local appearance = db.appearance
    appearance.ownedText8 = appearance.ownedText8 or {revision = 1, ElvUI = {}, Plater = {}}
    return appearance.ownedText8[owner]
end

local function comparisonHeaders()
    local E = _G.ElvUI and _G.ElvUI[1]
    local TT = E and E:GetModule("Tooltip", true)
    if not TT or not TT.Initialized or not TT.db then return end
    -- Native SetTooltipFonts sizes shopping line 1 as body text. Keep its
    -- original item-header treatment, following the selected native profile.
    for _, tooltip in ipairs(GameTooltip.shoppingTooltips or {}) do
        local name = tooltip:GetName()
        for _, side in ipairs({"Left", "Right"}) do
            local font = name and _G[name .. "Text" .. side .. "1"]
            if font then
                local face, _, flags = font:GetFont()
                if face then font:SetFont(face, TT.db.headerFontSize, flags) end
            end
        end
    end
    if not tooltipHooked then
        tooltipHooked = true
        hooksecurefunc(TT, "SetTooltipFonts", comparisonHeaders)
    end
end

local function restoreSizes(root, record, prefix)
    for _, change in ipairs(record.before or {}) do
        if not prefix or change.path:sub(1,#prefix) == prefix then
            local object, keys = root, {}
            for key in change.path:gmatch("[^.]+") do keys[#keys+1]=key end
            for i=1,#keys-1 do object=type(object)=="table" and object[keys[i]] or nil end
            if type(object)=="table" then object[keys[#keys]]=change.value end
        end
    end
end
local function restoreNameplates()
    local P=_G.Plater
    if not P or not P.db or not P.db.GetCurrentProfile then return end
    local saved=receipts("Plater")
    local record=saved and saved[P.db:GetCurrentProfile()]
    if not record or record.restored then return end
    restoreSizes(P.db.profile,record)
    P.RefreshDBUpvalues();P.UpdateAllPlates(true);P.UpdateSettingsCache()
    record.restored=true
end

function Text:Apply()
    if InCombatLockdown() then return end
    comparisonHeaders()
    restoreNameplates()
end

for _, event in ipairs({"PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ADDON_LOADED", "PLAYER_REGEN_ENABLED"}) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function()
    if queued then return end
    queued = true
    C_Timer.After(0, function() queued = false; Text:Apply() end)
end)
