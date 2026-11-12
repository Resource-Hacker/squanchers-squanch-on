-- SPDX-License-Identifier: GPL-2.0-only
-- Standalone rendering of the author's exported The Terminator aura group.
-- See THIRD_PARTY_NOTICES.md and LICENSES/GPL-2.0.txt for data/media provenance.
local addonName, addon = ...
local data = assert(addon.HordeReticleData, "Load HordeReticleData.lua before HordeReticle.lua")
local module = {frames = {}, source = data, enabled = true}
addon.HordeReticle = module

local media = "Interface\\AddOns\\" .. addonName .. "\\media\\horde-reticle\\"
local strata = {[2] = "BACKGROUND", [4] = "MEDIUM", [5] = "HIGH", [9] = "TOOLTIP"}
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
local function texturePath(path)
  if type(path) ~= "string" then return path end
  if not path:find("\\PowerAurasMedia\\Auras\\", 1, true) then return path end
  local name = path:match("\\([^\\]+)$")
  return name and media .. name or path
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
  -- Forever's own M33 GCD watcher uses 29515, other clients use 61304.
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

-- Linear progress artwork is clipped geometrically. Cropping uses the exact
-- saved zoom (1 + crop) and artwork rotation, including non-square Execute UVs.
local function setProgressTexture(texture, frame, d, progress)
  progress = math.max(0.0001, clamp(progress))
  texture:ClearAllPoints()
  texture:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
  texture:SetSize(frame:GetWidth(), frame:GetHeight() * progress)
  local hordeFill = frame.id == "Cursor GCD "
  local radians = math.rad(d.rotation or 0)
  local cosine, sine = math.cos(radians), math.sin(radians)
  local function uv(u, v)
    -- GCD fills the existing Horde silhouette; its imported crop/23.5px
    -- rectangle otherwise renders the same art at only 71.2% of the base.
    local x = (u - 0.5) * (hordeFill and 1 or 1.4142 / (1 + (d.crop_x or 0)))
    local y = (v - 0.5) * (hordeFill and 1 or 1.4142 / (1 + (d.crop_y or 0)))
    return 0.5 + x * cosine - y * sine - (d.user_x or 0),
      0.5 + x * sine + y * cosine + (d.user_y or 0)
  end
  local ulx, uly = uv(0, 1 - progress)
  local llx, lly = uv(0, 1)
  local urx, ury = uv(1, 1 - progress)
  local lrx, lry = uv(1, 1)
  texture:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
end

local function makeFrame(id, index)
  local d = data[id]
  local parent = d.anchorFrameType == "MOUSE" and mouseAnchor or group
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetSize(d.width, d.height)
  frame:SetPoint(d.selfPoint, parent, "CENTER", d.xOffset, d.yOffset)
  -- Owner-selected foreground mouseover glow; the imported aura used BACKGROUND.
  frame:SetFrameStrata(id == "Mouseover Glow" and "TOOLTIP" or (strata[d.frameStrata] or "MEDIUM"))
  frame:SetFrameLevel(group:GetFrameLevel() + index * 4)
  frame:EnableMouse(false)
  frame:SetAlpha(d.alpha or 1)
  frame:Hide()
  frame.id, frame.data = id, d
  if id == "Cursor GCD " then
    frame.fillWidth, frame.fillHeight = data["No Combat"].width, data["No Combat"].height
    frame:SetSize(frame.fillWidth, frame.fillHeight)
  end
  if d.regionType == "progresstexture" then
    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetTexture(texturePath(d.sameTexture and d.foregroundTexture or d.backgroundTexture), "CLAMP", "CLAMP")
    background:SetVertexColor(unpack(d.backgroundColor))
    background:SetBlendMode(d.blendMode)
    setProgressTexture(background, frame, d, 1)
    frame.background = background
    frame.smoothedProgress = 0.667
  end
  local foreground = frame:CreateTexture(nil, "ARTWORK")
  foreground:SetTexture(texturePath(d.regionType == "progresstexture" and d.foregroundTexture or d.texture),
    d.regionType == "texture" and "CLAMPTOBLACKADDITIVE" or "CLAMP",
    d.regionType == "texture" and "CLAMPTOBLACKADDITIVE" or "CLAMP")
  foreground:SetVertexColor(unpack(d.regionType == "progresstexture" and d.foregroundColor or d.color))
  foreground:SetBlendMode(d.blendMode)
  foreground:SetAllPoints(frame)
  if d.regionType == "progresstexture" then setProgressTexture(foreground, frame, d, 1) end
  if id == "Mouseover Dot" then
    -- Aura104 supplies the central-diamond shape used by the dot. Its only
    -- nontransparent pixels occupy [51,77) x [32,62) in the 128px source.
    foreground:SetTexture(media .. "Aura104", "CLAMP", "CLAMP")
    foreground:SetTexCoord(0, 1, 0, 1)
  elseif id == "Mouseover Glow" then
    -- Owner: the soft round glow of the original aura (Aura22, additive)
    -- around the dot while the hostile mouseover is in range.
    foreground:SetTexture(media .. "Aura22", "CLAMP", "CLAMP")
    foreground:SetTexCoord(0, 1, 0, 1)
  end
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
    if frame.id == "Execute" and _G.PlaySoundFile then
      _G.PlaySoundFile(media .. "throwknife.ogg", "Master")
    end
  elseif frame:IsShown() then
    local finish = frame.data.animation.finish
    if finish and finish.type ~= "none" then frame.finishedAt = now else frame:Hide() end
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
  -- Explicit correction: the saved Conditions trigger ignored its raw HP <20
  -- filter. Honor that stored filter, without inventing a percentage threshold.
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
  -- /run SquanchOn.HordeReticle:Test() shows the dot and glow without a target.
  if self.test then mouseHostile, mouseInRange = true, true end
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
  local alpha, scale = d.alpha or 1, 1
  local start = d.animation.start
  local age = now - (frame.shownAt or now)
  if start and start.type == "preset" and age < 0.25 then
    local progress = age / 0.25
    if start.preset == "shrink" then scale = math.max(0.0001, progress) end
    alpha = alpha * progress
  elseif frame.active and d.animation.main.type == "preset"
    and d.animation.main.preset == "pulse" then
    scale = 1 + 0.05 * pulse(math.max(0, now - (module.warningPulseStart or frame.shownAt + 0.25)), 0.75)
  end
  if frame.finishedAt then
    local finish = d.animation.finish
    local duration = finish.type == "custom" and (tonumber(finish.duration) or 1) or 0.25
    local progress = (now - frame.finishedAt) / duration
    if progress >= 1 then frame:Hide(); return end
    if finish.type == "custom" and finish.easeType == "easeOut" then
      progress = 1 - (1 - progress) ^ (finish.easeStrength or 3)
    end
    alpha = (d.alpha or 1) * (1 - progress)
    if finish.preset == "shrink" and finish.type == "preset" then
      scale = math.max(0.0001, 1 - progress)
    end
  end
  -- Keep the progress silhouette registered to its base during fades too.
  if frame.id == "Cursor GCD " then scale = 1 end
  frame:SetSize((frame.fillWidth or d.width) * scale, (frame.fillHeight or d.height) * scale)
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
  if module.test and _G.GetCursorCenterPosition then x, y = GetCursorCenterPosition() end
  mouseAnchor:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
  module:PlaceArt()
  for id, frame in pairs(module.frames) do
    if frame:IsShown() then
      transition(frame, now)
      local d = frame.data
      if d.regionType == "progresstexture" then
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
        local color = module.targetAttackable and d.conditions[1].changes[1].value
          or d.conditions[2].changes[1].value
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

-- Owner: the dot is the centre. The aim point (where the engine rests the
-- locked cursor and picks mouseover) holds the dot, and the emblem is placed
-- so its diamond, texel (64.5, 46.5) of the 128-texel art, surrounds it.
local placedX, placedY, placedScale
function module:PlaceArt()
  if not group then return end
  local shadow = self.frames["No Combat"]
  if not shadow then return end
  local cx, cy
  if _G.GetCursorCenterPosition then cx, cy = GetCursorCenterPosition() end
  local ui = UIParent:GetEffectiveScale()
  if not (cx and cy) then cx, cy = UIParent:GetWidth() * ui / 2, UIParent:GetHeight() * ui / 2 end
  local art = shadow:GetEffectiveScale()
  if cx == placedX and cy == placedY and art == placedScale then return end
  placedX, placedY, placedScale = cx, cy, art
  local size = shadow.data.height
  local dx, dy = size * (64.5 - 64) / 128 * art, size * (64 - 46.5) / 128 * art   -- screen pixels
  group:ClearAllPoints()
  group:SetPoint("CENTER", UIParent, "BOTTOMLEFT", (cx - dx) / ui, (cy - dy) / ui)
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
        -- The original aura's sizes (dot 28x31, glow 50x50, whole textures).
        -- The dot IS the aim point: its diamond (texel 63.9, 46.1 in its 28x31
        -- frame) and the glow's centre (texel 64.6, 60.3 in its 50x50 frame)
        -- sit exactly on it. PlaceArt puts the emblem's diamond around it.
        frame.fillWidth, frame.fillHeight = nil, nil
        local targetX, targetY = 0, 0
        local d = frame.data
        local ownX, ownY
        if id == "Mouseover Dot" then ownX, ownY = d.width * (63.9 - 64) / 128, d.height * (64 - 46.1) / 128
        else ownX, ownY = d.width * (64.6 - 64) / 128, d.height * (64 - 60.3) / 128 end
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", mouseAnchor, "CENTER", targetX - ownX, targetY - ownY)
        frame:SetSize(d.width, d.height)
      end
    end
  end
  placedScale = nil
  self:PlaceArt()
end

function module:Initialize()
  if self.initialized then return end
  group = CreateFrame("Frame", "SquancherHordeReticleGroup", UIParent)
  group:SetSize(2, 2)
  -- M33's groupOffset=true anchors this exact two-unit group by BOTTOMLEFT.
  -- Centered exactly on the screen centre, where the locked cursor rests.
  group:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  group:SetScale(data["The Terminator"].scale)
  group:EnableMouse(false)
  mouseAnchor = CreateFrame("Frame", nil, UIParent)
  mouseAnchor:SetSize(1, 1)
  mouseAnchor:EnableMouse(false)
  for index, id in ipairs(data["The Terminator"].controlledChildren) do makeFrame(id, index) end
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

function module:Test()
  self.test = not self.test or nil
  self:Refresh()
  print("Squanch-On reticle: mouseover dot and glow preview " .. (self.test and "on" or "off"))
end
