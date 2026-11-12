-- SPDX-License-Identifier: MIT
-- One migration per selected owner profile; later owner font choices win.
-- It runs once after login (after combat, if login was in combat) and then
-- stops listening.
local _, ns = ...
local Text = {}
ns.OwnedText = Text
local events = CreateFrame("Frame")
local queued, finished = false, false

local function restoreSizes(root, record)
    for _, change in ipairs(record.before or {}) do
        local object, keys = root, {}
        for key in change.path:gmatch("[^.]+") do keys[#keys+1]=key end
        for i=1,#keys-1 do object=type(object)=="table" and object[keys[i]] or nil end
        if type(object)=="table" then object[keys[#keys]]=change.value end
    end
end
-- True once there is nothing left to restore.
local function restoreNameplates()
    local db = SquanchOnDB
    if not db then return false end
    db.gearAtlasProbe = nil
    local saved = db.appearance and db.appearance.ownedText8 and db.appearance.ownedText8.Plater
    if not saved or not next(saved) then return true end
    local P=_G.Plater
    if not P then return true end
    if not P.db or not P.db.GetCurrentProfile then return false end
    local record=saved[P.db:GetCurrentProfile()]
    if not record or record.restored then return true end
    restoreSizes(P.db.profile,record)
    P.RefreshDBUpvalues();P.UpdateAllPlates(true);P.UpdateSettingsCache()
    record.restored=true
    return true
end

function Text:Apply()
    if finished or InCombatLockdown() then return end
    if restoreNameplates() then finished = true; events:UnregisterAllEvents() end
end

for _, event in ipairs({"PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED"}) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function()
    if queued then return end
    queued = true
    C_Timer.After(0, function() queued = false; Text:Apply() end)
end)
