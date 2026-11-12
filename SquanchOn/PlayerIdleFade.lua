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

-- The 3D portrait cannot take a secret alpha, so it is tied to the frame's
-- fade through geometry instead: it is anchored to the fill of a hidden status
-- bar that the client sets to the same value. Fill full = portrait at its
-- place; fill empty = no width, nothing drawn. Exactly in step with the frame.
local gate, wrapped
local function tie(frame)
    local model = frame.PortraitModel
    if not model or frame.Portrait ~= model or not model.backdrop then return nil end
    if not gate then
        gate = CreateFrame('StatusBar', nil, frame)
        gate:SetStatusBarTexture([[Interface\Buttons\WHITE8X8]])
        gate:GetStatusBarTexture():SetAlpha(0)
        gate:SetMinMaxValues(0, 1); gate:SetValue(1); gate:EnableMouse(false)
    end
    local place = frame.squancherPortraitPlace
    if place and place ~= wrapped then
        local function anchored()
            place()
            local inset = ns.UnitFrames and ns.UnitFrames.BORDER or 1
            gate:ClearAllPoints()
            gate:SetPoint('TOPLEFT', model.backdrop, 'TOPLEFT', inset, -inset)
            gate:SetPoint('BOTTOMRIGHT', model.backdrop, 'BOTTOMRIGHT', -inset, inset)
            model:ClearAllPoints(); model:SetAllPoints(gate:GetStatusBarTexture())
        end
        wrapped = anchored
        frame.squancherPortraitPlace = anchored
        anchored()
    end
    return gate
end
local function modelShown(frame, value)
    local bar = tie(frame)
    if bar then bar:SetValue(value) end
end
-- Other code fades this frame too (range and smooth fades write its alpha
-- after ours). While the frame is idle, any such write is answered with ours.
local writing, guarded = false, {}
local function guard(frame)
    if guarded[frame] then return end
    guarded[frame] = true
    hooksecurefunc(frame, 'SetAlpha', function()
        if writing or Fade.shown ~= false or not quiet() then return end
        local alpha = healthAlpha()
        if alpha == nil then return end
        writing = true
        frame:SetAlpha(alpha)
        writing = false
    end)
end

function Fade:Refresh()
    local frame = _G.SquanchOnUF_Player
    if not frame then return end
    self.frame = frame
    guard(frame)
    if quiet() then
        local alpha = healthAlpha()
        if alpha ~= nil then
            self.shown = false
            writing = true; frame:SetAlpha(alpha); writing = false
            modelShown(frame, alpha)
            -- Aura rows own their cells' rims; they follow the same alpha.
            for _, key in ipairs({ 'Buffs', 'Debuffs' }) do if frame[key] then frame[key]:SetAlpha(alpha) end end
            return
        end
    end
    self.shown = true
    frame:SetAlpha(1)
    modelShown(frame, 1)
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
    if not hooked and ns.LayoutEditor and ns.LayoutEditor.Open then
        hooked = true
        hooksecurefunc(ns.LayoutEditor, 'Open', function() Fade:Refresh() end)
        hooksecurefunc(ns.LayoutEditor, 'Close', function() Fade:Refresh() end)
    end
    if event == 'PLAYER_ENTERING_WORLD' and C_Timer then C_Timer.After(1, function() Fade.frame = nil; Fade:Refresh() end) end
    Fade:Refresh()
end)
