-- SPDX-License-Identifier: MIT
-- Fixed player progress bars from Squancher's accepted ElvUI profile.
-- Native status bars and game APIs; no ElvUI/Dominos/LSM runtime dependency.
local addonName, ns = ...
local DataBars = { reputationEnabled = false }
ns.NativeDataBars = DataBars
local texture = [[Interface\TargetingFrame\UI-StatusBar]]

local function makeBar(name, width, height)
    local holder = CreateFrame("Frame", name, UIParent)
    holder:SetSize(width, height)
    local backdrop = holder:CreateTexture(nil, "BACKGROUND")
    backdrop:SetAllPoints()
    backdrop:SetColorTexture(0.0549, 0.0549, 0.0549, 0.75)
    local function layer(level, r, g, b, alpha)
        local bar = CreateFrame("StatusBar", nil, holder)
        bar:SetAllPoints()
        bar:SetFrameLevel(holder:GetFrameLevel() + level)
        bar:SetStatusBarTexture(texture)
        bar:SetStatusBarColor(r, g, b, alpha)
        return bar
    end
    return holder, layer
end

function DataBars:UpdateXP(refreshQuests)
    local holder = self.xp
    if not holder then return end
    local current, maximum = UnitXP("player"), UnitXPMax("player")
    local capped = UnitLevel("player") >= GameRulesUtil.GetEffectiveMaxLevelForPlayer() or maximum <= 0
    holder:SetShown(not InCombatLockdown()) -- exact profile hideInCombat=true, hideAtMaxLevel=false
    if capped then current, maximum = 1, 1 end
    holder.fill:SetMinMaxValues(0, maximum)
    holder.fill:SetValue(current)
    local rested = not capped and GetXPExhaustion() or 0
    holder.rested:SetMinMaxValues(0, maximum)
    holder.rested:SetValue(math.min(current + (rested or 0), maximum))
    holder.rested:SetShown(not capped and rested and rested > 0)
    if refreshQuests then
        self.questXP = 0
        if not capped and C_QuestLog and GetQuestLogRewardXP then
            for index = 1, C_QuestLog.GetNumQuestLogEntries() do
                local info = C_QuestLog.GetInfo(index)
                if info and not info.isHidden and not info.isHeader and info.questID then
                    self.questXP = self.questXP + (GetQuestLogRewardXP(info.questID) or 0)
                end
            end
        end
    end
    holder.quest:SetMinMaxValues(0, maximum)
    holder.quest:SetValue(math.min(current + (self.questXP or 0), maximum))
    holder.quest:SetShown(not capped and (self.questXP or 0) > 0)
    -- textFormat was NONE; showLevel only affects non-NONE formats in ElvUI.
end

function DataBars:UpdateReputation()
    local holder = self.reputation
    if not holder then return end
    local data = C_Reputation.GetWatchedFactionData()
    holder:SetShown(self.reputationEnabled and data and data.factionID ~= 0)
    if not data or not self.reputationEnabled then return end
    local minimum, maximum, current = data.currentReactionThreshold, data.nextReactionThreshold, data.currentStanding
    if maximum <= minimum then minimum, maximum, current = 0, 1, 1 end
    holder.fill:SetMinMaxValues(0, maximum - minimum)
    holder.fill:SetValue(current - minimum)
    local color = FACTION_BAR_COLORS[data.reaction] or NORMAL_FONT_COLOR
    holder.fill:SetStatusBarColor(color.r, color.g, color.b, 0.75)
end

function DataBars:Initialize()
    local holder, layer = makeBar("SquancherExperienceBar", 170, 10)
    self.xp = holder
    holder:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -758, 267)
    holder:SetFrameStrata("DIALOG")
    holder.rested = layer(1, 1, 0, 1, 0.50450432300568)
    holder.quest = layer(2, 0, 1, 0, 0.50900894403458)
    holder.fill = layer(3, 0, 0.40000003576279, 1, 0.50450432300568)
    -- The source profile has 20 XP bubbles. Native texture separators are static.
    holder.ticks = {}
    for index = 1, 19 do
        local tick = holder.fill:CreateTexture(nil, "OVERLAY")
        tick:SetColorTexture(0, 0, 0, 0.55)
        tick:SetSize(1, 10)
        tick:SetPoint("LEFT", holder, "LEFT", 170 * index / 20, 0)
        holder.ticks[index] = tick
    end
    holder:HookScript("OnSizeChanged", function(self, width)
        for index, tick in ipairs(self.ticks) do tick:SetPoint("LEFT", self, "LEFT", width * index / 20, 0) end
    end)
    holder:EnableMouse(true)
    holder:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Level " .. UnitLevel("player"))
        GameTooltip:AddLine(string.format("Experience: %d / %d", UnitXP("player"), UnitXPMax("player")), 1, 1, 1)
        local rested = GetXPExhaustion()
        if rested and rested > 0 then GameTooltip:AddLine("Rested: " .. rested, 0.7, 0.3, 1) end
        if (DataBars.questXP or 0) > 0 then GameTooltip:AddLine("Quest experience: " .. DataBars.questXP, 0.3, 1, 0.3) end
        GameTooltip:AddLine("Alt-drag to move the minimap panel", 0.65, 0.65, 0.65)
        GameTooltip:Show()
    end)
    holder:SetScript("OnLeave", function() GameTooltip:Hide() end)
    if ns.DarkSkin then ns.DarkSkin:Panel(holder, "compact", 0) end

    local reputation, repLayer = makeBar("SquancherReputationBar", 8, 150)
    self.reputation = reputation
    reputation:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -806, 251)
    reputation.fill = repLayer(1, 0, 0.6, 0.1, 0.75)
    reputation.fill:SetOrientation("VERTICAL")
    reputation:Hide() -- ElvUI reputation.enable defaults false and profile did not override.
    if ns.DarkSkin then ns.DarkSkin:Panel(reputation, "compact", 0) end
    self:UpdateXP(true)
    self:UpdateReputation()
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "UPDATE_EXHAUSTION", "QUEST_LOG_UPDATE", "UPDATE_FACTION", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ENABLE_XP_GAIN", "DISABLE_XP_GAIN" }) do events:RegisterEvent(event) end
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then DataBars:Initialize()
    elseif DataBars.xp then
        DataBars:UpdateXP(event == "QUEST_LOG_UPDATE" or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LEVEL_UP")
        if event == "UPDATE_FACTION" or event == "PLAYER_ENTERING_WORLD" then DataBars:UpdateReputation() end
    end
end)
