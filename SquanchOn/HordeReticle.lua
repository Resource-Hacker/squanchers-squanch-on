-- SPDX-License-Identifier: MIT
-- Original reticle renderer; game-owned Horde artwork and original geometry.
local addonName, addon = ...
local config = assert(addon.ReticleConfig, "Load ReticleConfig.lua before HordeReticle.lua")
local data = config.layers
local module = {frames = {}, source = config, enabled = true}
addon.HordeReticle = module

local group, mouseAnchor, driver
local elapsedState = 0
local lastCast
local function public(value)
  return not (_G.issecretvalue and _G.issecretvalue(value))
end
local function query(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, value = pcall(fn, ...)
  if ok and public(value) then return value end
end
local function yes(fn, ...)
  local value = query(fn, ...)
  return value == true or value == 1
end
local function number(fn, ...)
  local value = query(fn, ...)
  return type(value) == "number" and value or nil
end
local function clamp(value)
  return math.max(0, math.min(1, value))
end
local function pulse(seconds, duration)
  return (1 - math.cos(seconds * 2 * math.pi / duration)) / 2
end

local function cooldown(spell)
  if _G.C_Spell and _G.C_Spell.GetSpellCooldown then
    local info = query(_G.C_Spell.GetSpellCooldown, spell)
    if type(info) == "table" and public(info.startTime) and public(info.duration) then
      return info.startTime or 0, info.duration or 0
    end
  end
  if _G.GetSpellCooldown then
    local ok, start, duration = pcall(_G.GetSpellCooldown, spell)
    if ok and public(start) and public(duration) then return start or 0, duration or 0 end
  end
end
local function gcdInfo()
  -- The selected Forever client uses 29515 for its global cooldown.
  local interface = _G.GetBuildInfo and tonumber((select(4, _G.GetBuildInfo())))
  return cooldown(interface == 16001 and 29515 or 61304)
end
local function usableKillShot()
  local usable
  if _G.C_Spell and _G.C_Spell.IsSpellUsable then
    usable = yes(_G.C_Spell.IsSpellUsable, 53351)
  else
    usable = yes(_G.IsUsableSpell, 53351)
  end
  if not usable then return false end
  local start, duration = cooldown(53351)
  if not start then return false end
  if duration == 0 or start + duration <= GetTime() then return true end
  local gcdStart, gcdDuration = gcdInfo()
  -- A global cooldown alone does not make the spell's own cooldown unavailable.
  return gcdStart and math.abs(start - gcdStart) < 0.001
    and math.abs(duration - gcdDuration) < 0.001 or false
end
local function hostile(unit)
  return yes(_G.UnitExists, unit) and yes(_G.UnitIsVisible, unit)
    and yes(_G.UnitCanAttack, "player", unit) and not yes(_G.UnitIsDead, unit)
end
local function autoShotRange(unit)
  local result
  if _G.IsSpellInRange then result = query(_G.IsSpellInRange, "Auto Shot", unit) end
  if result == nil and _G.C_Spell and _G.C_Spell.IsSpellInRange then
    result = query(_G.C_Spell.IsSpellInRange, 75, unit)
  end
  return result == 1 or result == true
end

-- Clip native/owned artwork from the bottom; foreground and background share
-- one coordinate rectangle, including during a global-cooldown fill.
local function setProgressTexture(texture, frame, d, progress)
  progress = math.max(.0001, clamp(progress))
  texture:ClearAllPoints()
  texture:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
  texture:SetSize(frame:GetWidth(), frame:GetHeight() * progress)
  texture:SetTexCoord(0, 1, 1-progress, 1)
end

local function makeFrame(id, index)
  local d = data[id]
  local parent = d.cursor and mouseAnchor or group
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetSize(unpack(d.size))
  frame:SetPoint("CENTER", parent, "CENTER", unpack(d.offset or {0,0}))
  frame:SetFrameStrata(d.strata or "MEDIUM")
  frame:SetFrameLevel(group:GetFrameLevel() + index * 4)
  frame:EnableMouse(false)
  frame:SetAlpha(d.opacity or 1)
  frame:Hide()
  frame.id, frame.data = id, d
  if d.progress then
    local background = frame:CreateTexture(nil,"BACKGROUND")
    background:SetTexture(d.art, "CLAMP", "CLAMP")
    background:SetDesaturated(true)
    background:SetVertexColor(unpack(d.background))
    background:SetBlendMode(d.blend or "BLEND")
    setProgressTexture(background, frame, d, 1)
    frame.background = background
    frame.smoothedProgress = .667
  end
  local foreground = frame:CreateTexture(nil,"ARTWORK")
  foreground:SetTexture(d.art, "CLAMP", "CLAMP")
  if id ~= "Pet Tracker" then foreground:SetDesaturated(true) end
  foreground:SetVertexColor(unpack(d.color))
  foreground:SetBlendMode(d.blend or "BLEND")
  foreground:SetAllPoints(frame)
  if d.progress then setProgressTexture(foreground, frame, d, 1) end
  frame.texture = foreground
  module.frames[id] = frame
end

local function active(frame, show)
  show = show and true or false
  if frame.active == show then return end
  frame.active = show
  local now = GetTime()
  if show then
    frame.shownAt = now
    frame.finishedAt = nil
    frame:Show()
    if frame.id == "Execute" and _G.PlaySound and _G.SOUNDKIT and type(SOUNDKIT.RAID_WARNING) == "number" then
      _G.PlaySound(SOUNDKIT.RAID_WARNING, "Master")
    end
  elseif frame:IsShown() then
    if frame.data.exit then frame.finishedAt = now else frame:Hide() end
  end
end

local function updatePet()
  local frame = module.frames["Pet Tracker"]
  local plate, petUnit
  if _G.C_NamePlate and _G.C_NamePlate.GetNamePlates then
    for _, candidate in ipairs(_G.C_NamePlate.GetNamePlates()) do
      local unit = candidate.namePlateUnitToken
        or (candidate.UnitFrame and candidate.UnitFrame.unit)
      local reaction = unit and number(_G.UnitReaction, "player", unit)
      if unit and yes(_G.UnitIsUnit, unit, "pet") and not yes(_G.UnitIsPlayer, unit)
        and reaction and reaction >= 5 then
        plate, petUnit = candidate, unit
        break
      end
    end
  end
  if frame.plate ~= plate then
    frame.plate = plate
    frame:SetParent(plate or group)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", plate or group, "CENTER", 0, 40)
  end
  frame.unit = petUnit
  active(frame, plate ~= nil)
end

function module:Refresh()
  if not self.initialized then return end
  local combat = yes(_G.UnitAffectingCombat, "player")
  local _, class = _G.UnitClass("player")
  active(self.frames["No Combat"], self.enabled)
  active(self.frames.Combat, self.enabled and combat)
  active(self.frames.Target, self.enabled and yes(_G.UnitExists, "target"))
  active(self.frames["Cursor GCD "], self.enabled and combat)
  local power = number(_G.UnitPower, "player")
  local maximum = number(_G.UnitPowerMax, "player")
  self.powerProgress = power and maximum and maximum > 0 and power / maximum or 0
  active(self.frames["Low Mana"], self.enabled and combat and power ~= nil
    and maximum ~= nil and maximum > 0 and power / maximum * 100 < 15)
  -- Retain the selected raw-health threshold rather than guessing a percentage.
  local health = number(_G.UnitHealth, "player")
  active(self.frames["Low Health"], self.enabled and combat and health ~= nil and health < 20)
  active(self.frames.Execute, self.enabled and combat and usableKillShot())
  if self.frames["Low Mana"].active or self.frames["Low Health"].active or self.frames.Execute.active then
    self.warningPulseStart = self.warningPulseStart or GetTime() + 0.25
  else
    self.warningPulseStart = nil
  end
  local mouseHostile = self.enabled and class == "HUNTER" and hostile("mouseover")
  local mouseInRange = mouseHostile and autoShotRange("mouseover")
  active(self.frames["Mouseover Glow"], mouseHostile)
  active(self.frames["Mouseover Dot"], mouseHostile)
  self.frames["Mouseover Glow"].inRange = mouseInRange
  self.frames["Mouseover Dot"].inRange = mouseInRange
  local targetHostile = self.enabled and class == "HUNTER" and hostile("target")
  active(self.frames["Target Range"], targetHostile)
  self.frames["Target Range"].inRange = targetHostile and autoShotRange("target")
  self.targetAttackable = yes(_G.UnitCanAttack, "player", "target")
  if self.enabled then updatePet() else active(self.frames["Pet Tracker"], false) end
end

local function transition(frame, now)
  local d = frame.data
  local alpha, scale = d.opacity or 1, 1
  local age = now-(frame.shownAt or now)
  if d.enter and age < .25 then
    local progress=age/.25
    if d.enter == "grow" then scale=math.max(.0001,progress) end
    alpha=alpha*progress
  elseif frame.active and d.pulse then
    scale=1+.05*pulse(math.max(0,now-(module.warningPulseStart or frame.shownAt+.25)),.75)
  end
  if frame.finishedAt then
    local duration=d.exit == "ease" and 1 or .25
    local progress=(now-frame.finishedAt)/duration
    if progress>=1 then frame:Hide();return end
    if d.exit == "ease" then progress=1-(1-progress)^3 end
    alpha=(d.opacity or 1)*(1-progress)
    if d.exit == "shrink" then scale=math.max(.0001,1-progress) end
  end
  if frame.id == "Cursor GCD " then scale=1 end
  frame:SetSize((frame.fillWidth or d.size[1])*scale,(frame.fillHeight or d.size[2])*scale)
  frame:SetAlpha(alpha)
end

function module:GetMouseoverDotOpacity()
  return self.mouseoverDotOpacity or 0
end

local function publishMouseoverDot(opacity)
  module.mouseoverDotOpacity = opacity
  local range = module.frames["Target Range"]
  -- Preserve target-range activation, suppressing its duplicate while the
  -- mouseover dot is visible; disabling the group keeps this texture suppressed.
  if range then range.texture:SetAlpha(module.enabled and opacity <= 0 and 1 or 0) end
  if addon.NameplateIndicators and addon.NameplateIndicators.SetMouseoverDotOpacity then
    addon.NameplateIndicators:SetMouseoverDotOpacity(opacity)
  end
end

local function render(now, elapsed)
  local x, y = GetCursorPosition()
  if addon.IsNativeLockCentered and addon:IsNativeLockCentered() and _G.GetCursorCenterPosition then
    x, y = GetCursorCenterPosition()
  end
  local scale = UIParent:GetEffectiveScale()
  mouseAnchor:ClearAllPoints()
  mouseAnchor:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
  for id, frame in pairs(module.frames) do
    if frame:IsShown() then
      transition(frame, now)
      local d = frame.data
      if d.progress then
        setProgressTexture(frame.background, frame, d, 1)
        local target = 1
        if id == "Low Mana" then
          target = module.powerProgress
        elseif id == "Cursor GCD " then
          local start, duration = gcdInfo()
          target = start and duration > 0 and lastCast
            and clamp((start + duration - now) / duration) or 1
        end
        local current = frame.smoothedProgress or target
        local value = _G.FrameDeltaLerp and _G.FrameDeltaLerp(current, target, 0.25)
          or current + (target - current) * math.min(1, elapsed * 15)
        frame.smoothedProgress = math.abs(value - target) < 0.00001 and target or value
        setProgressTexture(frame.texture, frame, d, frame.smoothedProgress)
      end
      if id == "No Combat" then
        local p = pulse(now - (frame.shownAt or now), 2)
        frame.texture:SetVertexColor(0, 0, 0, d.color[4] + (1 - d.color[4]) * p)
      elseif id == "Target" then
        local color = config.targetColors[module.targetAttackable and 1 or 2]
        local p = pulse(now - (module.frames["No Combat"].shownAt or now), 2)
        frame.texture:SetVertexColor(color[1] * (1 - p), color[2] * (1 - p),
          color[3] * (1 - p), color[4] + (1 - color[4]) * p)
      elseif id == "Mouseover Glow" or id == "Mouseover Dot" or id == "Target Range" then
        local color = d.color
        local red, green, blue = color[1], color[2], color[3]
        if id == "Mouseover Dot" then
          local targetColor = data["Target Range"].color
          red, green, blue = targetColor[1] * 0.75, targetColor[2] * 0.75, targetColor[3] * 0.75
        end
        -- A resolved mouseover plate disappears immediately on mouseout. Give
        -- its dot/chevrons the same immediate exit, without caching a stale plate.
        local visible = id == "Mouseover Dot" and frame.active and frame.inRange
          or id ~= "Mouseover Dot" and (not frame.active or frame.inRange)
        frame.texture:SetVertexColor(red, green, blue, visible and color[4] or 0)
      end
    end
  end
  local dot = module.frames["Mouseover Dot"]
  local opacity = 0
  if module.enabled and dot and dot:IsShown() then
    local _, _, _, alpha = dot.texture:GetVertexColor()
    -- This module writes the dot's texture alpha through SetVertexColor only;
    -- count that channel once, alongside the animated parent-frame alpha.
    opacity = dot:GetEffectiveAlpha() * alpha
  end
  publishMouseoverDot(opacity)
end

function module:ApplyReticleScale()
  local scale = tonumber(self.db and self.db.hordeReticleScale) or (2 / 3)
  scale = math.max(0.1, math.min(2, scale))
  -- Two-thirds of the original displayed size, independent of global UI scaling.
  -- Pet Tracker belongs to a nameplate, not the center Horde reticle.
  for id, frame in pairs(self.frames) do
    if id ~= "Pet Tracker" then
      local parentScale = frame:GetParent():GetEffectiveScale()
      frame:SetScale(scale / parentScale)
      if id == "Mouseover Dot" or id == "Mouseover Glow" then
        local effectiveScale = frame:GetEffectiveScale()
        local pixelFactor = PixelUtil.GetPixelToUIUnitFactor()
        local pixel = pixelFactor / effectiveScale
        local halfWidth, halfHeight=config.dotSize[1]/2,config.dotSize[2]/2
        local insetScale=math.max(.0001,1-pixel*math.sqrt(halfWidth^2+halfHeight^2)/(halfWidth*halfHeight))
        frame.fillWidth,frame.fillHeight=2*halfWidth*insetScale,2*halfHeight*insetScale
        local groupScale=group:GetEffectiveScale()/effectiveScale
        frame:ClearAllPoints()
        frame:SetPoint("CENTER",mouseAnchor,"CENTER",group:GetWidth()/2*groupScale,
          group:GetHeight()/2*groupScale+config.dotYOffset)
        frame:SetSize(frame.fillWidth, frame.fillHeight)
      end
    end
  end
end

function module:Initialize()
  if self.initialized then return end
  group = CreateFrame("Frame", "SquancherHordeReticleGroup", UIParent)
  group:SetSize(2, 2)
  -- Preserve the established two-unit group origin used by the aim-point API.
  -- Centered exactly on the screen centre, where the locked cursor rests.
  group:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  group:SetScale(1)
  group:EnableMouse(false)
  mouseAnchor = CreateFrame("Frame", nil, UIParent)
  mouseAnchor:SetSize(1, 1)
  mouseAnchor:EnableMouse(false)
  for index, id in ipairs(config.order) do makeFrame(id, index) end
  self.initialized = true
  self.group = group
  self:ApplyReticleScale()
  self:Refresh()
  self.onUpdate = function(_, elapsed)
    elapsedState = elapsedState + elapsed
    if elapsedState >= 0.05 then
      elapsedState = 0
      module:Refresh()
      addon:UpdateAimPoint()
    end
    render(GetTime(), elapsed)
  end
  driver:SetScript("OnUpdate", self.enabled and self.onUpdate or nil)
end

function module:SetEnabled(enabled)
  self.enabled = enabled and true or false
  if self.db then self.db.hordeReticleEnabled = self.enabled end
  self:Refresh()
  if self.initialized then
    driver:SetScript("OnUpdate", self.enabled and self.onUpdate or nil)
    if not self.enabled then
      for _, frame in pairs(self.frames) do frame:Hide() end
      publishMouseoverDot(0)
    end
  end
end

module.Update = module.Refresh
function module:Hide()
  self:SetEnabled(false)
end

function addon:InitializeHordeReticle(db)
  module.db = db
  if db then
    if db.hordeReticleEnabled == nil then db.hordeReticleEnabled = true end
    if db.hordeReticleScale == nil then db.hordeReticleScale = 2 / 3 end
    module.enabled = db.hordeReticleEnabled and true or false
  end
  module:Initialize()
  module:SetEnabled(module.enabled)
  return module
end

driver = CreateFrame("Frame")
driver:SetScript("OnEvent", function(_, event, unit, ...)
  if not module.initialized then return end
  if event == "UI_SCALE_CHANGED" then module:ApplyReticleScale() end
  if (event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START"
    or event == "UNIT_SPELLCAST_SUCCEEDED") and unit == "player" then lastCast = GetTime() end
  module:Refresh()
end)
for _, event in ipairs({"PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "UI_SCALE_CHANGED", "PLAYER_TARGET_CHANGED",
  "UPDATE_MOUSEOVER_UNIT", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
  "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
  "UNIT_FACTION", "UNIT_PET", "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_USABLE",
  "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_SUCCEEDED",
  "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED"}) do
  driver:RegisterEvent(event)
end
