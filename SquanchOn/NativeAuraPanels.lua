-- SPDX-License-Identifier: MIT
-- Original Squanch-On aura/cooldown presentation. No external aura engine.
local _, ns = ...
local M = { panels = {} }
ns.NativeAuraPanels = M
local events = CreateFrame("Frame")
local MAX_ICONS, MAX_AURAS, MAX_SPELLS = 32, 128, 256
local specs = {
    Buffs = { "player", "HELPFUL", "BOTTOM", -300, 161 },
    RaidDebuffs = { "player", "HARMFUL", "TOPLEFT", -351, -203 },
    Procs = { "player", "HELPFUL", "BOTTOMLEFT", -57, -52 },
    Enhancements = { "player", "HELPFUL", "BOTTOMRIGHT", -351, 161 },
    TargetDebuffs = { "target", "HARMFUL|PLAYER", "TOPLEFT", 283, -207 },
    Cooldowns = { "player", nil, "BOTTOMRIGHT", -71, -109 },
    ItemCooldowns = { "player", nil, "BOTTOMRIGHT", -71, -109 },
    FocusBuffs = { "focus", "HELPFUL", "TOPRIGHT", -53, 53 },
    FocusDebuffs = { "focus", "HARMFUL", "TOPRIGHT", -53, 53 },
}
local function public(v) return not (issecretvalue and issecretvalue(v)) end
local function number(v) return public(v) and type(v) == "number" end
local function option(t, key, default)
    local value = t and t[key]
    if value == nil then return default end
    return value
end
local function bounded(value, default, low, high)
    if not number(value) then return default end
    return math.max(low, math.min(high, value))
end
local function enabled(panel)
    return M.settings.Enable ~= false and panel.db.Enable ~= false
end
local function skin(button)
    if not InCombatLockdown() and ns.DarkSkin then
        button.SquanchOnBorder = ns.DarkSkin:ControlBorder(button, "icon", button, 1)
    end
end
local function icon(panel, index)
    if panel.icons[index] then return panel.icons[index] end
    local button = CreateFrame("Button", nil, panel)
    button:EnableMouse(false)
    button.Icon = button:CreateTexture(nil, "ARTWORK")
    button.Icon:SetAllPoints()
    button.Icon:SetTexCoord(.07, .93, .07, .93)
    button.Cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    button.Cooldown:SetAllPoints()
    button.Cooldown:SetDrawEdge(false)
    button.Cooldown:SetHideCountdownNumbers(false)
    button.Cooldown:SetScript("OnCooldownDone", function()
        -- Native cooldown completion is the only wake needed for opaque times.
        if panel.cooldowns and not M.updating then M:QueueCooldowns() end
    end)
    button.Count = button.Cooldown:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    button.Count:SetPoint("BOTTOMRIGHT", -1, 1)
    panel.icons[index] = button
    skin(button)
    return button
end
local function layout(panel)
    local cfg = panel.db
    local size = bounded(cfg.Size, 28, 8, 96)
    local gap = bounded(cfg.Spacing, 4, 0, 30)
    local columns = math.floor(bounded(cfg.NumPerRow, 12, 1, MAX_ICONS))
    local direction = option(cfg, "Direction", "RIGHT")
    local horizontal = direction == "LEFT" and -1 or 1
    local vertical = direction == "DOWN" and -1 or 1
    for i, button in ipairs(panel.icons) do
        button:SetSize(size, size)
        local column, row = (i - 1) % columns, math.floor((i - 1) / columns)
        button:ClearAllPoints()
        button:SetPoint(horizontal == -1 and "BOTTOMRIGHT" or "BOTTOMLEFT", panel,
            horizontal == -1 and "BOTTOMRIGHT" or "BOTTOMLEFT",
            column * (size + gap) * horizontal, row * (size + gap) * vertical)
        skin(button)
    end
    panel:SetSize(columns * (size + gap) - gap, size)
end
local function finish(panel, count)
    for i = count + 1, #panel.icons do panel.icons[i]:Hide() end
    panel.visibleCount = count
    panel:SetShown(enabled(panel))
    layout(panel)
end
local function paint(panel, index, texture, count, durationObject, start, duration, rate)
    local button = icon(panel, index)
    button.Icon:SetTexture(texture)
    if public(count) then button.Count:SetText(number(count) and count > 1 and count or "")
    else button.Count:SetText(count) end -- native FontString accepts opaque counts
    if durationObject and button.Cooldown.SetCooldownFromDurationObject then
        button.Cooldown:SetCooldownFromDurationObject(durationObject)
        button.Cooldown:Show()
    elseif number(start) and number(duration) and duration > 0 then
        button.Cooldown:SetCooldown(start, duration, number(rate) and rate or 1)
        button.Cooldown:Show()
    else
        button.Cooldown:Clear()
        button.Cooldown:Hide()
    end
    button:Show()
end
local function accept(panel, data)
    if number(data.duration) and data.duration == 0 then return false end
    local spell = data.spellId
    local mode = option(panel.db, "FilterByList", "None")
    if mode == "Whitelist" or mode == "Blacklist" then
        if not number(spell) then return false end
        local list = panel.db[mode] or {}
        return mode == "Whitelist" and list[spell] == true
            or mode == "Blacklist" and not list[spell]
    end
    local source = data.sourceUnit
    local own = public(source) and (source == "player" or source == "pet" or source == "vehicle")
    if panel.kind == "Procs" then
        if not own or not number(spell) then return false end
        return not (IsPlayerSpell and IsPlayerSpell(spell))
    end
    return own or (public(data.isFromPlayerOrPlayerPet) and data.isFromPlayerOrPlayerPet == true)
end
function M:UpdateAuras(unit)
    if not self.settings or not C_UnitAuras then return end
    for _, panel in pairs(self.panels) do
        if panel.unit == unit and panel.filter then
            local count = 0
            if enabled(panel) and UnitExists(unit) then
                for index = 1, MAX_AURAS do
                    local data = C_UnitAuras.GetAuraDataByIndex(unit, index, panel.filter)
                    if not data then break end
                    if accept(panel, data) then
                        count = count + 1
                        local durationObject
                        if number(data.auraInstanceID) and C_UnitAuras.GetAuraDuration then
                            durationObject = C_UnitAuras.GetAuraDuration(unit, data.auraInstanceID)
                        end
                        local start = number(data.duration) and number(data.expirationTime)
                            and data.expirationTime - data.duration or nil
                        paint(panel, count, data.icon, data.applications, durationObject, start, data.duration)
                        if count == MAX_ICONS then break end
                    end
                end
            end
            finish(panel, count)
        end
    end
end
function M:QueueCooldowns()
    if self.cooldownQueued then return end
    self.cooldownQueued = true
    C_Timer.After(0, function()
        self.cooldownQueued = false
        if self.settings then self:UpdateCooldowns() end
    end)
end
function M:UpdateCooldowns()
    if not self.settings then return end
    if self.transition then self.transition:Cancel(); self.transition = nil end
    self.updating = true
    local now, nextWake = GetTime(), nil
    local function wake(delay)
        if delay > .01 and (not nextWake or delay < nextWake) then nextWake = delay end
    end
    local spells = self.panels.Cooldowns
    local count = 0
    if enabled(spells) and C_Spell then
        for _, spellID in ipairs(self.spells) do
            local info = C_Spell.GetSpellCooldown(spellID)
            local charges = C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(spellID)
            local charging = charges and public(charges.isActive) and charges.isActive == true
            local active = charging or (info and public(info.isActive) and info.isActive == true)
            -- Older public clients expose numeric starts without isActive.
            if info and public(info.isActive) and info.isActive == nil and number(info.startTime) and number(info.duration) then
                active = info.startTime > 0 and info.duration > 1.5
            end
            -- Never use Lua and/or selection on an opaque timing/count value.
            local start, duration, rate, stacks
            if charging then
                start, duration, rate, stacks = charges.cooldownStartTime, charges.cooldownDuration,
                    charges.chargeModRate, charges.currentCharges
            elseif info then
                start, duration, rate = info.startTime, info.duration, info.modRate
            end
            local remaining = number(start) and number(duration) and start + duration - now or nil
            local show = active and not (info and public(info.isOnGCD) and info.isOnGCD and not charging)
            if remaining then
                local ignore = bounded(spells.db.IgnoreDuration, 300, 2, 86400)
                local suppress = bounded(spells.db.SuppressDuration, 60, 2, ignore)
                if remaining >= suppress then wake(remaining - suppress + .05) end
                if remaining > 0 then wake(remaining + .05) end
                show = show and remaining > 1.5 and remaining < suppress and remaining < ignore
            end
            if show and count < MAX_ICONS then
                local durationObject
                if charging and C_Spell.GetSpellChargeDuration then
                    durationObject = C_Spell.GetSpellChargeDuration(spellID)
                elseif C_Spell.GetSpellCooldownDuration then
                    durationObject = C_Spell.GetSpellCooldownDuration(spellID, true)
                end
                local data = C_Spell.GetSpellInfo(spellID)
                if data then
                    count = count + 1
                    paint(spells, count, data.iconID, stacks,
                        durationObject, start, duration, rate)
                end
            end
        end
    end
    finish(spells, count)
    local items = self.panels.ItemCooldowns
    count = 0
    if enabled(items) and C_Container then
        local seen = {}
        for bag = 0, (NUM_BAG_SLOTS or 4) do
            for slot = 1, math.min(C_Container.GetContainerNumSlots(bag), 64) do
                local id = C_Container.GetContainerItemID(bag, slot)
                local start, duration, available = C_Container.GetContainerItemCooldown(bag, slot)
                if number(id) and not seen[id] and number(start) and number(duration)
                    and public(available) and (available == 1 or available == true) then
                    local remaining = start + duration - now
                    if duration > 1.5 and remaining > 0 then
                        seen[id] = true
                        wake(remaining + .05)
                        if count < MAX_ICONS then
                            local data = C_Container.GetContainerItemInfo(bag, slot)
                            if data then
                                count = count + 1
                                paint(items, count, data.iconFileID, nil, nil, start, duration)
                            end
                        end
                    end
                end
            end
        end
    end
    finish(items, count)
    self.updating = false
    -- One one-shot transition, no permanent ticker or hidden-panel OnUpdate.
    if nextWake then self.transition = C_Timer.NewTimer(nextWake, function() self:UpdateCooldowns() end) end
end
function M:Refresh()
    if not ns.db then return end
    self.settings = (ns.db.auxiliaryImport or {}).iFilger or {}
    for name, spec in pairs(specs) do
        local panel = self.panels[name]
        if not panel then
            panel = CreateFrame("Frame", "SquanchOn" .. name, UIParent)
            panel.kind, panel.unit, panel.filter, panel.icons = name, spec[1], spec[2], {}
            panel.cooldowns = not spec[2]
            panel:SetPoint(spec[3], UIParent, "CENTER", spec[4], spec[5])
            self.panels[name] = panel
        end
        panel.db = self.settings[name] or {}
        layout(panel)
    end
    self.spells = {}
    local selected = (self.settings.Cooldowns or {}).SpellCDs or {}
    for spellID, tracked in pairs(selected) do
        if number(spellID) and tracked == true then self.spells[#self.spells + 1] = spellID end
    end
    table.sort(self.spells)
    for i = #self.spells, MAX_SPELLS + 1, -1 do self.spells[i] = nil end
    self:UpdateAuras("player"); self:UpdateAuras("target"); self:UpdateAuras("focus")
    self:UpdateCooldowns()
end
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("UNIT_AURA")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:RegisterEvent("PLAYER_FOCUS_CHANGED")
events:RegisterEvent("SPELL_UPDATE_COOLDOWN")
events:RegisterEvent("SPELL_UPDATE_CHARGES")
events:RegisterEvent("BAG_UPDATE_COOLDOWN")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("SPELLS_CHANGED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" or event == "SPELLS_CHANGED" then
        M:Refresh()
    elseif not M.settings then return
    elseif event == "UNIT_AURA" then M:UpdateAuras(unit)
    elseif event == "PLAYER_TARGET_CHANGED" then M:UpdateAuras("target")
    elseif event == "PLAYER_FOCUS_CHANGED" then M:UpdateAuras("focus")
    elseif event == "PLAYER_REGEN_ENABLED" then
        for _, panel in pairs(M.panels) do layout(panel) end
    else M:QueueCooldowns() end
end)
