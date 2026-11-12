-- SPDX-License-Identifier: MIT
-- The player frame steps aside when there is nothing to read on it: out of
-- combat, at full health and power, with no target and no cast. Alpha only, so
-- it is safe in combat and the frame stays where it is for the layout editor.
local _, ns = ...
local Fade = { shown = true }
ns.PlayerIdleFade = Fade

local function setting()
    return not ns.db or ns.db.playerIdleHide ~= false
end
local function secret(value) return issecretvalue and issecretvalue(value) end
local function full(current, maximum)
    if secret(current) or secret(maximum) then return false end
    return type(current) == 'number' and type(maximum) == 'number' and current >= maximum
end
-- Health may be a secret value to addon code, so "full" is never compared in
-- Lua: the client evaluates a step curve (anything below full -> 1, full -> 0)
-- and the result goes straight into SetAlpha.
local curve
local function healthAlpha()
    if not (C_CurveUtil and C_CurveUtil.CreateCurve and UnitHealthPercent and Enum and Enum.LuaCurveType) then return nil end
    if not curve then
        curve = C_CurveUtil.CreateCurve()
        curve:SetType(Enum.LuaCurveType.Step)
        curve:AddPoint(0, 1)
        curve:AddPoint(0.9995, 0)
    end
    local ok, alpha = pcall(UnitHealthPercent, 'player', true, curve)
    if ok then return alpha end
end
-- Everything except health: true when the frame may step aside.
local function quiet()
    if not setting() then return false end
    if InCombatLockdown() or UnitAffectingCombat('player') then return false end
    if UnitExists('target') or UnitIsDeadOrGhost('player') then return false end
    if UnitCastingInfo and UnitCastingInfo('player') or UnitChannelInfo and UnitChannelInfo('player') then return false end
    if ns.LayoutEditor and ns.LayoutEditor.active then return false end
    return true
end

-- The 3D portrait cannot take a secret alpha, so it is shown or hidden on what
-- addon code may know: the frame is quiet and health has stopped changing
-- (out of combat it regenerates in ticks until it is full).
local lastChange = 0
local function modelShown(frame, show)
    local model = frame.PortraitModel
    if not model or frame.Portrait ~= model then return end
    if show then if frame.USE_PORTRAIT ~= false then model:SetAlpha(1) end else model:SetAlpha(0) end
    if model.SetModelAlpha then pcall(model.SetModelAlpha, model, show and 1 or 0) end
end
function Fade:Refresh()
    local frame = _G.SquanchOnUF_Player
    if not frame then return end
    self.frame = frame
    if quiet() then
        local alpha = healthAlpha()
        if alpha ~= nil then
            self.shown = false
            frame:SetAlpha(alpha)
            modelShown(frame, GetTime() - lastChange < 3.5)
            -- Aura rows own their cells' rims; they follow the same alpha.
            for _, key in ipairs({ 'Buffs', 'Debuffs' }) do if frame[key] then frame[key]:SetAlpha(alpha) end end
            return
        end
    end
    self.shown = true
    frame:SetAlpha(1)
    modelShown(frame, true)
    for _, key in ipairs({ 'Buffs', 'Debuffs' }) do if frame[key] then frame[key]:SetAlpha(1) end end
end

local events = CreateFrame('Frame')
for _, event in ipairs({ 'PLAYER_ENTERING_WORLD', 'PLAYER_REGEN_DISABLED', 'PLAYER_REGEN_ENABLED', 'PLAYER_TARGET_CHANGED',
    'PLAYER_ALIVE', 'PLAYER_DEAD', 'PLAYER_UNGHOST' }) do events:RegisterEvent(event) end
for _, event in ipairs({ 'UNIT_HEALTH', 'UNIT_MAXHEALTH', 'UNIT_POWER_UPDATE', 'UNIT_MAXPOWER', 'UNIT_DISPLAYPOWER',
    'UNIT_SPELLCAST_START', 'UNIT_SPELLCAST_STOP', 'UNIT_SPELLCAST_CHANNEL_START', 'UNIT_SPELLCAST_CHANNEL_STOP' }) do
    events:RegisterUnitEvent(event, 'player')
end
local hooked
events:SetScript('OnEvent', function(_, event)
    if event == 'UNIT_HEALTH' or event == 'UNIT_MAXHEALTH' or event == 'PLAYER_REGEN_ENABLED' then
        lastChange = GetTime()
        if C_Timer then C_Timer.After(3.6, function() Fade:Refresh() end) end
    end
    if not hooked and ns.LayoutEditor and ns.LayoutEditor.Open then
        hooked = true
        hooksecurefunc(ns.LayoutEditor, 'Open', function() Fade:Refresh() end)
        hooksecurefunc(ns.LayoutEditor, 'Close', function() Fade:Refresh() end)
    end
    if event == 'PLAYER_ENTERING_WORLD' and C_Timer then C_Timer.After(1, function() Fade.frame = nil; Fade:Refresh() end) end
    Fade:Refresh()
end)
