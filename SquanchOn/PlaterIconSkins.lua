-- SPDX-License-Identifier: MIT
-- Original narrow adapter for real Plater icon objects. Plater retains aura
-- policy, timers, dispel colors, cast shields, tooltips and animations.
local _, ns = ...
local M = { seen = setmetatable({}, { __mode = "k" }), pending = setmetatable({}, { __mode = "k" }) }
ns.PlaterIconSkins = M
local events = CreateFrame("Frame")
local function nativeAura(button)
    -- Native AuraContainer buttons reject script hooks and expose secret
    -- visibility. Plater supplies their own borders during initialization,
    -- before its later auraContainer marker is assigned.
    return button and (type(button.SetApplicationCount) == "function"
        or type(button.SetDurationCooldown) == "function")
end
local function visible(button)
    local shown = button:IsVisible()
    return not (issecretvalue and issecretvalue(shown)) and shown
end
local function apply(button)
    if not button or not button.GetObjectType or nativeAura(button) then return end
    -- Plater preallocates large hidden pools. Do not build material rims for
    -- those unused objects or force a hidden pool into the render graph.
    if button.IsVisible and not visible(button) then return end
    local art = button.Icon or button.Texture
    if not art or not art.SetTexCoord then return end
    if InCombatLockdown() then M.pending[button] = true; return end
    if ns.DarkSkin then
        button.SquanchOnBorder = ns.DarkSkin:ControlBorder(button, "icon", button, 1)
    end
    art:SetTexCoord(.07, .93, .07, .93)
    if button.Cooldown and button.Cooldown.SetDrawEdge then button.Cooldown:SetDrawEdge(false) end
    M.pending[button] = nil
end
function M:Icon(button)
    if not button or not button.HookScript or nativeAura(button) then return end
    local shown = button:IsVisible()
    if issecretvalue and issecretvalue(shown) then return end
    if not self.seen[button] then
        self.seen[button] = true
        button:HookScript("OnShow", apply)
        button:HookScript("OnSizeChanged", apply)
    end
    if shown then apply(button) end
end
function M:Row(row)
    if not row then return end
    -- Current Plater supports both native aura containers and legacy DF rows.
    for _, key in ipairs({ "auraButtons", "PlaterBuffList", "IconPool" }) do
        local list = row[key]
        if type(list) == "table" then
            for i = 1, math.min(#list, 128) do self:Icon(list[i]) end
        end
    end
end
function M:Cast(castBar)
    if not castBar then return end
    local art = castBar.Icon
    if not art or not art.GetObjectType then return end
    if art:GetObjectType() == "Texture" then
        if InCombatLockdown() then self.pendingCasts[castBar] = true; return end
        local holder = castBar.SquanchOnIconHolder
        if not holder then
            holder = CreateFrame("Frame", nil, castBar)
            holder:EnableMouse(false)
            holder.Icon = art
            castBar.SquanchOnIconHolder = holder
        end
        holder:ClearAllPoints(); holder:SetAllPoints(art)
        self:Icon(holder)
        self.pendingCasts[castBar] = nil
    else self:Icon(art) end
end
M.pendingCasts = setmetatable({}, { __mode = "k" })
function M:UnitFrame(unitFrame)
    if not unitFrame then return end
    for _, key in ipairs({ "BuffFrame", "BuffFrame2", "ExtraIconFrame", "BossModIconFrame" }) do self:Row(unitFrame[key]) end
    self:Cast(unitFrame.castBar)
end
function M:Plate(unit)
    -- UNIT_AURA also delivers targettarget/pet/party tokens. This API only
    -- accepts plate tokens here; NAME_PLATE_UNIT_ADDED supplies their identity.
    if type(unit) ~= "string" or (issecretvalue and issecretvalue(unit))
        or not unit:match("^nameplate%d+$") then return end
    if not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then return end
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if plate then self:UnitFrame(plate.unitFrame) end
end
function M:Install()
    local plater = _G.Plater
    if not plater or self.installed then return end
    if ns.db and plater.db and plater.db.profile then
        ns.db.migrations=ns.db.migrations or {}
        local profile=plater.db:GetCurrentProfile()
        ns.db.migrations.platerMasque=ns.db.migrations.platerMasque or {}
        if not ns.db.migrations.platerMasque[profile] then
            plater.db.profile.enable_masque_support=false
            ns.db.migrations.platerMasque[profile]=true
        end
    end
    self.installed = true
    -- Secure post-hooks observe actual object arguments; no monkey-patched
    -- constructors, global CreateFrame interception or imitation Masque API.
    if type(plater.AddAura) == "function" then
        hooksecurefunc(plater, "AddAura", function(_, button) self:Icon(button) end)
    end
    if type(plater.UpdateIconAspecRatio) == "function" then
        hooksecurefunc(plater, "UpdateIconAspecRatio", function(button) self:Icon(button) end)
    end
    if type(plater.AddExtraIcon) == "function" then
        hooksecurefunc(plater, "AddExtraIcon", function(container) self:Row(container and container.ExtraIconFrame) end)
    end
    if type(plater.CreateOrUpdateAuraContainers) == "function" then
        hooksecurefunc(plater, "CreateOrUpdateAuraContainers", function(unitFrame) self:UnitFrame(unitFrame) end)
    end
    if type(plater.UpdateBossModAuras) == "function" then
        hooksecurefunc(plater, "UpdateBossModAuras", function(unitFrame) self:Row(unitFrame and unitFrame.BossModIconFrame) end)
    end
    if type(plater.UpdateCastbarIcon) == "function" then
        hooksecurefunc(plater, "UpdateCastbarIcon", function(castBar) self:Cast(castBar) end)
    end
    if C_NamePlate and C_NamePlate.GetNamePlates then
        for _, plate in ipairs(C_NamePlate.GetNamePlates()) do self:UnitFrame(plate.unitFrame) end
    end
end
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
events:RegisterEvent("UNIT_AURA")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGIN" or (event == "ADDON_LOADED" and unit == "Plater") then M:Install()
    elseif event == "PLAYER_REGEN_ENABLED" then
        for button in pairs(M.pending) do apply(button) end
        for castBar in pairs(M.pendingCasts) do M:Cast(castBar) end
    elseif event == "NAME_PLATE_UNIT_ADDED" or event == "UNIT_AURA" then
        if not M.installed or type(unit) ~= "string" or (issecretvalue and issecretvalue(unit))
            or not unit:match("^nameplate%d+$") then return end
        -- A coalesced event edge sees icons created by Plater's own handler.
        M.queuedUnits = M.queuedUnits or {}
        if not M.queuedUnits[unit] then
            M.queuedUnits[unit] = true
            C_Timer.After(0, function() M.queuedUnits[unit] = nil; M:Plate(unit) end)
        end
    end
end)
