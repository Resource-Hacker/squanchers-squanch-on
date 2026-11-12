-- SPDX-License-Identifier: MIT
-- Squancher nameplate indicators. Configuration/visual behavior adapted from
-- TargetNameplateIndicator 1.67, Copyright (c) 2013-2016 Choonster (MIT).
-- See LICENSES/TargetNameplateIndicator-LICENSE.txt and CONTRIBUTORS notice.
-- Native frame/event implementation; no Ace3, LNR, or old addon dependency.
local addonName, addon = ...
local module = { frames = {}, status = {}, watchedPlates = {} }
addon.NameplateIndicators = module

local textureRoot = "Interface\\AddOns\\" .. addonName .. "\\media\\native-indicators\\"
local crosshairs = "Interface\\AddOns\\" .. addonName .. "\\media\\Crosshairs\\"
local units = { "target", "focus", "softfriend", "softenemy", "targettarget", "mouseover" }
local priorities = { target = 100, focus = 90, softfriend = 80, softenemy = 70, targettarget = 50, mouseover = 10 }
local reactions = { "self", "friendly", "hostile" }
local hasSecrets = C_Secrets and C_Secrets.ShouldUnitComparisonBeSecret and true or false
module.units, module.reactions = units, reactions
module.textureNames = {"Ring","Chevron","Pointer","Diamond","Horde","Skull"}
local artwork = {
  Ring=crosshairs.."circle.tga", Chevron=textureRoot.."chevron.tga",
  Pointer=textureRoot.."pointer.tga", Diamond=textureRoot.."diamond.tga",
  Horde=[[Interface\Timer\Horde-Logo]], Skull=[[Interface\TargetingFrame\UI-RaidTargetingIcon_8]],
}
-- These names describe a supported migration, never a dependency on the old
-- addon's images. Unknown external/custom paths remain user-owned settings.
local legacyArtwork = {
  Reticule={"Ring"}, RedArrow={"Pointer"}, NeonReticule={"Ring"}, NeonRedArrow={"Pointer"},
  RedChevronArrow={"Chevron"}, PaleRedChevronArrow={"Chevron",1,.45,.45},
  arrow_tip_green={"Pointer",0,1,0}, arrow_tip_red={"Pointer"}, skull={"Skull",1,1,1},
  circles_target={"Ring"}, red_star={"Diamond"}, greenarrowtarget={"Pointer",0,1,0},
  BlueArrow={"Pointer",0,.5,1}, bluearrow1={"Pointer",0,.5,1}, gearsofwar={"Skull",1,1,1},
  malthael={"Skull",1,1,1}, NewRedArrow={"Pointer"}, NewSkull={"Skull",1,1,1},
  PurpleArrow={"Pointer",.7,0,1}, Shield={"Diamond",.7,.8,1}, NeonGreenArrow={"Pointer",0,1,0},
  Q_FelFlamingSkull={"Skull",0,1,0}, Q_RedFlamingSkull={"Skull"}, Q_ShadowFlamingSkull={"Skull",.7,0,1},
  Q_GreenGPS={"Pointer",0,1,0}, Q_RedGPS={"Pointer"}, Q_WhiteGPS={"Pointer",1,1,1},
  Q_GreenTarget={"Ring",0,1,0}, Q_RedTarget={"Ring"}, Q_WhiteTarget={"Ring",1,1,1},
  Hunters_Mark={"Pointer"}, Arrows_Towards={"Pointer"}, Arrows_Away={"Pointer"},
  Arrows_SelfTowards={"Pointer",0,1,0}, Arrows_SelfAway={"Pointer",0,1,0},
  Arrows_FriendTowards={"Pointer",0,1,0}, Arrows_FriendAway={"Pointer",0,1,0},
  Arrows_FocusTowards={"Pointer",.7,0,1}, Arrows_FocusAway={"Pointer",.7,0,1},
  green_arrow_down_11384={"Pointer",0,1,0}, CyanChevronArrow={"Chevron",0,1,1},
  GreenChevronArrow={"Chevron",0,1,0}, PurpleChevronArrow={"Chevron",.7,0,1},
  YellowChevronArrow={"Chevron",1,1,0}, NeonCyanArrow={"Chevron",0,1,1},
  NeonPurpleArrow={"Chevron",.7,0,1}, NeonYellowArrow={"Chevron",1,1,0},
}

function module:PaintTexture(texture, style)
  local name = style.texture == "custom" and style.textureCustom or style.texture
  texture:SetTexture(artwork[name] or name)
  local tint = style.tint or (artwork[name] and {1,0,0} or {1,1,1})
  texture:SetVertexColor(tint[1],tint[2],tint[3])
  texture:SetAlpha(style.opacity)
end

local function safe(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, value = pcall(fn, ...)
  if not ok or (issecretvalue and issecretvalue(value)) then return nil end
  return value
end

local function copy(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, child in pairs(value) do result[key] = copy(child) end
  return result
end

local function fill(defaults, dest)
  for key, value in pairs(defaults) do
    if dest[key] == nil then
      dest[key] = copy(value)
    elseif type(value) == "table" and type(dest[key]) == "table" then
      fill(value, dest[key])
    end
  end
end

local function validReaction(unit, reaction)
  return not (unit == "softenemy" and reaction ~= "hostile")
    and not (unit == "softfriend" and reaction == "hostile")
end

local function newProfile()
  local profile = {}
  for _, unit in ipairs(units) do
    profile[unit] = { enable = true }
    for _, reaction in ipairs(reactions) do
      if validReaction(unit, reaction) then
        profile[unit][reaction] = {
          enable = true, texture = "Ring", height = 50, width = 50,
          frameStrata = "BACKGROUND", opacity = 1, texturePoint = "BOTTOM",
          anchorPoint = "TOP", xOffset = 0, yOffset = 5,
        }
      end
    end
  end
  return profile
end

local function remapTextures(profiles)
  for _, profile in pairs(profiles) do
    for _, unit in ipairs(units) do
      local group=profile[unit]
      if type(group)=="table" then
        for _, reaction in ipairs(reactions) do
          local style=group[reaction]
          if type(style)=="table" and not style.nativeArtworkRevision then
            local path=style.texture=="custom" and style.textureCustom or style.texture
            local old=type(path)=="string" and path:lower()
            local name=type(path)=="string" and path:match("([^\\/]+)$")
            if name then name=name:gsub("%.[Tt][Gg][Aa]$","") end
            local mapped=legacyArtwork[name]
            if mapped and (old:find("targetnameplateindicator",1,true)
              or old:find("nameplate-indicators",1,true)) then
              style.texture=mapped[1]
              style.tint={mapped[2] or 1,mapped[3] or 0,mapped[4] or 0}
              style.followMouseoverDot=mapped[1]=="Chevron"
            end
            style.nativeArtworkRevision=1
          end
        end
      end
    end
  end
end

local function characterKey()
  -- AceDB's standard character key; preserve every imported key/profile too.
  return (safe(UnitName, "player") or "Player") .. " - " .. (safe(GetRealmName) or "Realm")
end

-- The indicators are one table inside the active addon profile
-- (nameplateIndicators). self.db is a session view for the callers that list
-- profiles by name: each addon profile's indicator table. Nothing in it is saved.
function module:UseProfile()
  local profiles = addon.Profiles
  local active = profiles:Bootstrap()
  if type(rawget(active, "nameplateIndicators")) ~= "table" then
    -- A migration seed avoids depending on loading the disabled addon's own SV file.
    local legacy = type(_G.TargetNameplateIndicatorDB) == "table" and _G.TargetNameplateIndicatorDB
    local chosen = legacy and type(legacy.profileKeys) == "table" and legacy.profileKeys[characterKey()] or "Default"
    active.nameplateIndicators = copy(legacy and type(legacy.profiles) == "table" and legacy.profiles[chosen] or {})
    local receipts = profiles:Receipts("nameplateIndicatorReceipts")
    if receipts.schemaVersion == nil then receipts.importedLegacy, receipts.schemaVersion = legacy and true or false, 1 end
  end
  local view = { profiles = {}, profileKeys = {} }
  for _, name in ipairs(profiles:Names()) do
    local stored = rawget(profiles:Get(name), "nameplateIndicators")
    if type(stored) == "table" then view.profiles[name] = stored end
  end
  self.db = view
  self.profileName = profiles:Current()
  self.profile = active.nameplateIndicators
  remapTextures({ self.profile })
  fill(newProfile(), self.profile)
  self:Refresh()
end

-- Indicator profiles are the addon's profiles: selecting one switches the whole addon.
function module:SelectProfile(name)
  if type(name) ~= "string" or name == "" then return false end
  if name == self.profileName then self:Refresh(); return true end
  local ok, message = addon.Profiles:Select(name)
  if message then print("Squancher nameplate indicators: " .. message) end
  return ok and true or false
end

function module:ReplaceProfile(profile)
  addon.Profiles:Bootstrap().nameplateIndicators = profile
  self:UseProfile()
end

function module:Initialize()
  if self.db then return end
  self:UseProfile()
  addon.Profiles:OnChanged(function() module:UseProfile() end)
end

local function comparisonBlocked(unit)
  -- Match upstream's Retail restriction policy, including targettarget removal.
  if unit == "targettarget" and hasSecrets then return true end
  if unit ~= "target" and hasSecrets then
    return safe(C_Secrets.ShouldUnitComparisonBeSecret, unit, "nameplate1") ~= false
  end
  return false
end

local function reactionFor(unit)
  local isSelf = safe(UnitIsUnit, "player", unit)
  if isSelf == nil then return nil end
  if isSelf then return "self" end
  local friendly = safe(UnitIsFriend, "player", unit)
  if friendly == nil then return nil end
  return friendly and "friendly" or "hostile"
end

local function plateUnit(plate)
  if type(plate.GetUnit) == "function" then return safe(plate.GetUnit, plate) end
  return plate.namePlateUnitToken
end

local function resolve(unit)
  if comparisonBlocked(unit) then return nil, "restricted" end
  if not safe(UnitExists, unit) then return nil, "absent" end
  if not C_NamePlate or type(C_NamePlate.GetNamePlateForUnit) ~= "function" then return nil, "API unavailable" end
  local plate = safe(C_NamePlate.GetNamePlateForUnit, unit)
  if not plate or not safe(plate.IsShown, plate) then return nil, "offscreen" end
  local token = plateUnit(plate)
  if (issecretvalue and issecretvalue(token)) or type(token) ~= "string" then return nil, "unbound plate" end
  if safe(UnitIsUnit, unit, token) ~= true then return nil, "unbound plate" end
  return plate
end

function module:HideIndicator(frame)
  if frame.plate or frame.config then
    frame:Hide()
    frame:ClearAllPoints()
  end
  frame.plate = nil
  frame.plateToken = nil
  frame.config = nil
end

function module:WatchPlate(plate)
  if self.watchedPlates[plate] or type(plate.HookScript) ~= "function" then return end
  self.watchedPlates[plate] = true
  -- An addon may hide a plate without removing its unit. Anchoring follows
  -- native motion, while these hooks mirror native visibility without polling.
  pcall(plate.HookScript, plate, "OnHide", function()
    for _, indicator in pairs(module.frames) do
      if indicator.plate == plate then module:HideIndicator(indicator) end
    end
  end)
  pcall(plate.HookScript, plate, "OnShow", function() module:QueueRefresh() end)
end

-- Only named chevron art follows the mouseover dot. Reticule/ring indicators
-- and focus/soft-target indicators retain their independent configured owners.
local function dotChevron(unit, style)
  return (unit == "target" or unit == "mouseover") and style and style.followMouseoverDot == true
end
local dotUnits = {"target", "mouseover"}
-- Called from the reticle's render: nothing is written while the opacity holds.
function module:SetMouseoverDotOpacity(opacity)
  local previous = self.mouseoverDotOpacity
  if previous == opacity then return end
  self.mouseoverDotOpacity = opacity
  if ((previous or 0) > 0) ~= (opacity > 0) then self:Refresh() end
  for index = 1, #dotUnits do
    local unit = dotUnits[index]
    local frame = self.frames[unit]
    if frame and dotChevron(unit, frame.config) then frame:SetAlpha(opacity) end
  end
end

local claimed = {}
local shownStatus = { self = "shown self", friendly = "shown friendly", hostile = "shown hostile" }
function module:Refresh(force)
  if not self.profile then return end
  for plate in pairs(claimed) do claimed[plate] = nil end
  for _, unit in ipairs(units) do
    local frame = self.frames[unit]
    local config = self.profile[unit]
    local plate, reason
    local reaction, style
    if config.enable then
      plate, reason = resolve(unit)
      if plate then
        reaction = reactionFor(unit)
        style = reaction and config[reaction]
      end
    else
      reason = "disabled"
    end
    local followsDot = dotChevron(unit, style)
    if followsDot and (self.mouseoverDotOpacity or 0) <= 0 then
      plate = nil
      reason = "mouseover dot hidden"
    end
    local lowerPriority = plate and claimed[plate]
    -- Upstream's unit-level priority applies even when its reaction is disabled.
    if plate and not lowerPriority then claimed[plate] = priorities[unit] end
    if plate and style and style.enable and not lowerPriority then
      if frame.plate ~= plate or frame.config ~= style or force then
        self:WatchPlate(plate)
        frame:ClearAllPoints()
        frame:SetFrameStrata(style.frameStrata)
        frame:SetSize(style.width, style.height)
        frame:SetPoint(style.texturePoint, plate, style.anchorPoint, style.xOffset, style.yOffset)
        self:PaintTexture(frame.Texture, style)
        frame.plate = plate
        frame.plateToken = plateUnit(plate)
        frame.config = style
      end
      frame:SetAlpha(followsDot and (self.mouseoverDotOpacity or 0) or 1)
      frame:Show()
      self.status[unit] = shownStatus[reaction]
    else
      self:HideIndicator(frame)
      self.status[unit] = reason or (lowerPriority and "lower priority" or "reaction disabled")
    end
  end
end

function module:CreateIndicators()
  for _, unit in ipairs(units) do
    local frame = CreateFrame("Frame", "SquancherNameplateIndicator_" .. unit, UIParent)
    frame:SetFrameStrata("BACKGROUND")
    frame:EnableMouse(false)
    frame.Texture = frame:CreateTexture(nil, "OVERLAY")
    frame.Texture:SetAllPoints(frame)
    frame:Hide()
    self.frames[unit] = frame
  end
end

module.stratas = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }
module.points = { "TOP", "RIGHT", "BOTTOM", "LEFT", "TOPRIGHT", "TOPLEFT", "BOTTOMLEFT", "BOTTOMRIGHT", "CENTER" }
local function contains(values, value)
  for _, item in ipairs(values) do if item == value then return true end end
  return false
end

function module:SetOption(unit, reaction, key, value)
  local config = self.profile and self.profile[unit]
  if not config then return false, "Unknown unit" end
  if reaction == "unit" and key == "enable" then
    config.enable = value == true or value == "true" or value == "on" or value == "1"
  else
    config = config[reaction]
    if not config then return false, "Unsupported reaction" end
    if key == "enable" then
      config.enable = value == true or value == "true" or value == "on" or value == "1"
    elseif key == "width" or key == "height" or key == "opacity" or key == "xOffset" or key == "yOffset" then
      local number = tonumber(value)
      if not number or number ~= number or number == math.huge or number == -math.huge
        or ((key == "width" or key == "height") and number <= 0)
        or (key == "opacity" and (number < 0 or number > 1)) then return false, "Invalid number" end
      config[key] = number
    elseif key == "frameStrata" then
      value = tostring(value):upper()
      if not contains(self.stratas, value) then return false, "Invalid frame strata" end
      config[key] = value
    elseif key == "texturePoint" or key == "anchorPoint" then
      value = tostring(value):upper()
      if not contains(self.points, value) then return false, "Invalid anchor point" end
      config[key] = value
    elseif key == "texture" then
      if value ~= "custom" then
        if type(value) ~= "string" or value == "" then return false, "Invalid texture" end
      end
      config.texture = value
      config.followMouseoverDot = value == "Chevron"
    elseif key == "textureCustom" then
      config.textureCustom = tostring(value)
    else
      return false, "Unknown setting"
    end
  end
  self:Refresh(true)
  return true
end

function module:PrintStatus()
  print("Squancher nameplate indicators: profile " .. self.profileName)
  for _, unit in ipairs(units) do print("  " .. unit .. ": " .. (self.status[unit] or "unknown")) end
end

function module:Slash(message)
  message = (message or ""):match("^%s*(.-)%s*$")
  if message == "" or message == "options" then addon:OpenOptions("nameplates"); return end
  if message == "status" then self:PrintStatus(); return end
  if message == "profiles" then
    for name in pairs(self.db.profiles) do print("Squancher indicator profile: " .. name) end
    return
  end
  local action, text = message:match("^(%S+)%s+(.+)$")
  if action == "profile" then self:SelectProfile(text); return end
  if action == "copy" and self.db.profiles[text] then
    self:ReplaceProfile(copy(self.db.profiles[text])); return
  end
  if action == "delete" then print("Profiles are deleted on the Profiles page: /squanchon profiles"); return end
  if message == "reset" then
    self:ReplaceProfile(newProfile()); return
  end
  local unit, reaction, key, value = message:match("^(%S+)%s+(%S+)%s+(%S+)%s+(.+)$")
  if unit then
    local ok, errorMessage = self:SetOption(unit, reaction, key, value)
    if not ok then print("Squancher nameplate indicators: " .. errorMessage) end
    return
  end
  print("/sqnameplates [options|status|profiles|profile NAME|copy NAME|delete NAME|reset]")
  print("/sqnameplates UNIT REACTION SETTING VALUE; REACTION: self, friendly, hostile, or unit (enable only)")
end

local controller = CreateFrame("Frame")
-- An event burst re-resolves the six units; an indicator is re-anchored and
-- repainted only when its plate or style changed (settings edits force it).
local function refreshQueued(self)
  self:SetScript("OnUpdate", nil)
  module.refreshQueued = nil
  module:Refresh()
end
function module:QueueRefresh()
  if self.refreshQueued then return end
  self.refreshQueued = true
  -- Only one next-frame callback per burst; no callback remains while idle.
  controller:SetScript("OnUpdate", refreshQueued)
end

controller:RegisterEvent("ADDON_LOADED")
controller:SetScript("OnEvent", function(_, event, arg)
  if event == "ADDON_LOADED" then
    if arg ~= addonName then return end
    module:CreateIndicators()
    module:Initialize()
    SLASH_SQUANCHERNAMEPLATES1 = "/sqnameplates"
    SLASH_SQUANCHERNAMEPLATES2 = "/tni"
    SLASH_SQUANCHERNAMEPLATES3 = "/targetnameplateindicator"
    SlashCmdList.SQUANCHERNAMEPLATES = function(message) module:Slash(message) end
    controller:UnregisterEvent("ADDON_LOADED")
    module.unsupportedEvents = {}
    for _, name in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT",
      "PLAYER_FOCUS_CHANGED", "UNIT_FACTION", "UNIT_FLAGS",
      "UNIT_CONNECTION", "UNIT_PET", "GROUP_ROSTER_UPDATE", "PLAYER_FLAGS_CHANGED",
      "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED",
      "PLAYER_SOFT_ENEMY_CHANGED", "PLAYER_SOFT_FRIEND_CHANGED" }) do
      -- Classic-family clients can omit soft-target/focus events. Unknown event
      -- registration must not prevent supported indicators from initializing.
      local ok = pcall(controller.RegisterEvent, controller, name)
      if not ok then module.unsupportedEvents[name] = true end
    end
    -- Only the target's own target matters (the targettarget indicator).
    if not pcall(controller.RegisterUnitEvent, controller, "UNIT_TARGET", "target") then
      pcall(controller.RegisterEvent, controller, "UNIT_TARGET")
    end
    if hasSecrets then pcall(controller.RegisterEvent, controller, "ADDON_RESTRICTION_STATE_CHANGED") end
    module:QueueRefresh()
  elseif event == "NAME_PLATE_UNIT_REMOVED" then
    -- Hide before the pooled frame can be assigned to its next unit.
    for _, frame in pairs(module.frames) do
      if frame.plateToken == arg then module:HideIndicator(frame) end
    end
    module:QueueRefresh()
  else
    module:QueueRefresh()
  end
end)
