-- SPDX-License-Identifier: MIT
-- Squanch-On nameplates: optional enhancements over the parity look
-- (ns.NameplateEnhance). Everything here is off while "Classic look" is on
-- (the default), and each item has its own switch. Regions are created the
-- first time an item needs them, so the classic look pays nothing.
--
-- Several calls are 12.x additions not confirmed on this client. Each is
-- looked up when used and guarded; a missing one leaves its region hidden.
-- Secret values only reach SetText, SetAlphaFromBoolean and StatusBar setters.
local _, ns = ...
local NP = ns.Nameplates
if not NP then return end
local E = {}
ns.NameplateEnhance = E
local public, ask = NP.Public, NP.Ask
local WHITE = 'Interface\\Buttons\\WHITE8X8'
local GOLD = { 0.90, 0.684, 0.378 }

function E:On(key)
  if self.force ~= nil then return self.force end
  local settings = NP:Settings().enhance
  return settings and not settings.classicLook and settings[key] and true or false
end
local function gold() return ns.DarkSkin and ns.DarkSkin.headerTextColor or GOLD end
local function known(ids)
  for _, id in ipairs(ids) do
    if IsPlayerSpell and ask(IsPlayerSpell, id) == true then return true end
    if IsSpellKnown and ask(IsSpellKnown, id) == true then return true end
  end
  return false
end
-- Abilities whose markers are pointless without them. Looked up in the
-- spellbook; the result is kept until spells change.
local abilities
local EXECUTES = { 53351, 5308, 20662, 24275, 24239 } -- Kill Shot, Execute ranks, Hammer of Wrath ranks
local PURGES = { 19801, 370, 527, 8012, 30449, 19505 } -- Tranquilizing Shot, Purge, Dispel Magic, Spellsteal, Devour Magic
function E:Knows(kind)
  if not abilities then abilities = { execute = known(EXECUTES), purge = known(PURGES) } end
  return abilities[kind]
end
function E:SpellsChanged() abilities = nil end

local function setBoolAlpha(region, value, shown)
  if not region.SetAlphaFromBoolean then region:SetAlpha(public(value) and value and shown or 0); return end
  if public(value) then value = value and true or false end
  if not pcall(region.SetAlphaFromBoolean, region, value, shown, 0) then region:SetAlpha(0) end
end
local function line(parent, layer)
  local art = parent:CreateTexture(nil, layer or 'OVERLAY')
  art:SetTexture(WHITE)
  art:Hide()
  return art
end

-- Emphasis --------------------------------------------------------------------
-- rest, hover (under the reticle while the mouseover hold is open) or target:
-- a scale step animated over half a second and a gold rim around the bar.
local function emphasisRim(frame)
  if frame.npRim then return frame.npRim end
  local rim, health = {}, frame.Health
  for index, points in ipairs({ { 'BOTTOMLEFT', 'TOPLEFT', 'BOTTOMRIGHT', 'TOPRIGHT' }, { 'TOPLEFT', 'BOTTOMLEFT', 'TOPRIGHT', 'BOTTOMRIGHT' },
    { 'TOPRIGHT', 'TOPLEFT', 'BOTTOMRIGHT', 'BOTTOMLEFT' }, { 'TOPLEFT', 'TOPRIGHT', 'BOTTOMLEFT', 'BOTTOMRIGHT' } }) do
    local art = line(frame, 'ARTWORK')
    art:SetPoint(points[1], health, points[2], index > 2 and 0 or -1, 0)
    art:SetPoint(points[3], health, points[4], index > 2 and 0 or 1, 0)
    if index < 3 then art:SetHeight(1) else art:SetWidth(1) end
    rim[index] = art
  end
  frame.npRim = rim
  return rim
end
local function scaleTo(frame, wanted)
  local current = frame.npScale or frame:GetScale() or 1
  if math.abs(current - wanted) < 0.001 then return end
  frame.npScale = wanted
  local group = frame.npScaleGroup
  if not group and frame.CreateAnimationGroup then
    group = frame:CreateAnimationGroup()
    local step = group and group.CreateAnimation and group:CreateAnimation('Scale')
    if step and step.SetScaleFrom and step.SetScaleTo then
      step:SetDuration(0.5)
      if step.SetSmoothing then step:SetSmoothing('OUT') end
      group.step = step
      local function settle() frame:SetScale(frame.npScale) end
      group:SetScript('OnFinished', settle); group:SetScript('OnStop', settle)
      frame.npScaleGroup = group
    else
      group = nil
    end
  end
  if not group or not frame:IsVisible() or current <= 0 then frame:SetScale(wanted); return end
  group:Stop()
  frame:SetScale(current)
  frame.npScale = wanted
  group.step:SetScaleFrom(1, 1); group.step:SetScaleTo(wanted / current, wanted / current)
  group:Play()
end
function E:Emphasis(frame)
  local settings = NP:Settings()
  local base = frame.npBase or tonumber(settings.scale) or 1
  if not self:On('emphasis') then
    if frame.npRim then for _, art in ipairs(frame.npRim) do art:Hide() end end
    if frame.npScaleGroup then frame.npScale = base; frame.npScaleGroup:Stop() end
    return
  end
  local enhance = settings.enhance
  local level = NP:IsTarget(frame) and 'target' or (NP.gate and NP.hoverFrame == frame) and 'hover' or 'rest'
  local color, bar = gold(), frame.Health:IsShown()
  for _, art in ipairs(emphasisRim(frame)) do
    art:SetVertexColor(color[1], color[2], color[3])
    art:SetAlpha(level == 'target' and 1 or 0.6)
    art:SetShown(bar and level ~= 'rest')
  end
  scaleTo(frame, base * (level == 'target' and (enhance.targetScale or 1.15) or level == 'hover' and (enhance.hoverScale or 1.08) or 1))
end

-- Levelling markers -------------------------------------------------------------
local function markers(frame)
  if frame.npMarks then return frame.npMarks end
  local health, overlay = frame.Health, frame.TextLayer
  local marks = { left = line(overlay), right = line(overlay), tick = line(health), quest = overlay:CreateTexture(nil, 'OVERLAY') }
  marks.left:SetPoint('RIGHT', health, 'LEFT', -1, 0); marks.right:SetPoint('LEFT', health, 'RIGHT', 1, 0)
  marks.quest:SetTexture('Interface\\COMMON\\Indicator-Yellow')
  marks.quest:SetPoint('RIGHT', frame.Name, 'LEFT', -1, 0)
  marks.quest:Hide()
  frame.npMarks = marks
  return marks
end
local function levelling(frame, width, height)
  local on = E:On('levelling')
  if not on and not frame.npMarks then return end
  local marks, unit = markers(frame), frame.unit
  local bar = frame.Health:IsShown()
  local class = on and bar and unit and ask(UnitClassification, unit)
  local elite = class == 'elite' or class == 'worldboss' or class == 'rareelite'
  local rare = class == 'rare' or class == 'rareelite'
  local color = gold()
  for _, art in ipairs({ marks.left, marks.right }) do
    art:SetShown(elite or rare)
    art:SetSize(1, height + 4)
    -- Gold for elite, silver for rare; a rare elite gets one of each.
    local silver = rare and (not elite or art == marks.right)
    if silver then art:SetVertexColor(0.78, 0.8, 0.85) else art:SetVertexColor(color[1], color[2], color[3]) end
  end
  local quest = on and unit and (frame.npQuest or C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest
    and ask(C_QuestLog.UnitIsRelatedToActiveQuest, unit) == true)
  marks.quest:SetShown(quest and true or false)
  marks.quest:SetSize(6, 6)
  -- A fixed tick needs no health value. Only with an execute in the spellbook.
  local threshold = tonumber(NP:Settings().enhance.executeThreshold) or 0.2
  local tick = on and bar and E:Knows('execute') and (frame.npKind == 'enemynpc' or frame.npKind == 'enemyplayer')
  marks.tick:SetShown(tick and true or false)
  marks.tick:ClearAllPoints()
  marks.tick:SetPoint('TOPLEFT', frame.Health, 'TOPLEFT', width * threshold, 0)
  marks.tick:SetSize(1, height)
  marks.tick:SetVertexColor(color[1], color[2], color[3])
end
-- Trivial (grey) units take the minor size.
function E:Trivial(unit)
  return self:On('levelling') and UnitIsTrivial and ask(UnitIsTrivial, unit) == true
end

-- Stacking bounds and the behind-camera pointer ----------------------------------
local function stackingBounds(frame)
  local plate = frame:GetParent()
  if frame.npBounds or not E:On('stackingBounds') or not (plate and plate.SetStackingBoundsFrame) or InCombatLockdown() then return end
  local bounds = CreateFrame('Frame', nil, frame)
  bounds:SetPoint('BOTTOMLEFT', frame.Health, 'BOTTOMLEFT', 0, -2)
  bounds:SetPoint('TOPRIGHT', frame.Health, 'TOPRIGHT', 0, 14)
  if pcall(plate.SetStackingBoundsFrame, plate, bounds) then frame.npBounds = bounds end
end
function E:Behind(unit, behind)
  local frame = type(unit) == 'string' and public(unit) and NP:PlateFor(unit)
  if not frame then return end
  if public(behind) then frame.npBehind = behind and true or false end
  local show = self:On('pointer') and frame.npBehind and NP:IsTarget(frame)
  if not show and not frame.npPointer then return end
  if not frame.npPointer then
    local art = frame.TextLayer:CreateTexture(nil, 'OVERLAY')
    art:SetTexture('Interface\\MINIMAP\\MiniMap-QuestArrow')
    art:SetSize(16, 16)
    art:SetPoint('BOTTOM', frame.Name, 'TOP', 0, 2)
    local color = gold()
    art:SetVertexColor(color[1], color[2], color[3])
    frame.npPointer = art
  end
  frame.npPointer:SetShown(show and true or false)
end

-- Called at the end of every layout pass.
function E:Apply(frame, width, height)
  local health = frame.Health
  -- Client-side easing; the cast bar already runs on a client timer.
  local eased = self:On('animatedBars') and Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut
  health.smoothing = eased or (Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate) or nil
  levelling(frame, width, height)
  stackingBounds(frame)
  self:Emphasis(frame)
  if frame.npPointer or frame.npBehind then self:Behind(frame.unit) end
end

-- Hunter solo threat ---------------------------------------------------------------
-- on me / my pet holds it / gaining. nil hands the unit back to the group rules
-- (in a group, without an answer, or when the client hides the status).
function E:Threat(frame, unit)
  if not self:On('hunterThreat') or (IsInGroup and ask(IsInGroup) == true) then return end
  local ok, me = pcall(UnitThreatSituation, 'player', unit)
  local good, pet = pcall(UnitThreatSituation, 'pet', unit)
  if not ok or not good or not public(me) or not public(pet) then return end
  local enhance = NP:Settings().enhance
  if me == 3 then return enhance.onMe end
  if type(pet) == 'number' and pet >= 2 then return enhance.petHolds end
  if me ~= nil then return enhance.gaining end
end

-- Cast intelligence -----------------------------------------------------------------
local function castRegions(cast)
  if cast.npYou then return end
  local color = gold()
  cast.npYou = cast:CreateTexture(nil, 'BACKGROUND', nil, -2)
  cast.npYou:SetTexture(WHITE); cast.npYou:SetVertexColor(1, 0.15, 0.1)
  cast.npYou:SetPoint('TOPLEFT', cast, 'TOPLEFT', -2, 2); cast.npYou:SetPoint('BOTTOMRIGHT', cast, 'BOTTOMRIGHT', 2, -2)
  cast.npImportant = cast:CreateTexture(nil, 'BACKGROUND', nil, -1)
  cast.npImportant:SetTexture(WHITE); cast.npImportant:SetVertexColor(color[1], color[2], color[3])
  cast.npImportant:SetPoint('TOPLEFT', cast, 'TOPLEFT', -1, 1); cast.npImportant:SetPoint('BOTTOMRIGHT', cast, 'BOTTOMRIGHT', 1, -1)
  cast.npTarget = cast:CreateFontString(nil, 'OVERLAY')
  cast.npTarget:SetFont(STANDARD_TEXT_FONT or 'Fonts\\FRIZQT__.TTF', 7, 'OUTLINE')
  cast.npTarget:SetPoint('TOP', cast, 'BOTTOM', 0, -1)
  cast.npYou:SetAlpha(0); cast.npImportant:SetAlpha(0)
end
function E:CastStart(cast, unit)
  if not self:On('castIntel') then
    if cast.npYou then self:CastStop(cast) end
    return
  end
  castRegions(cast)
  unit = unit or cast.__owner and cast.__owner.unit
  local ok, value = pcall(PlayerIsSpellTarget or error, unit)
  if ok then setBoolAlpha(cast.npYou, value, 0.9) else cast.npYou:SetAlpha(0) end
  ok, value = pcall(C_Spell and C_Spell.IsSpellImportant or error, cast.spellID)
  if ok then setBoolAlpha(cast.npImportant, value, 1) else cast.npImportant:SetAlpha(0) end
  local good, name = pcall(UnitSpellTargetName or error, unit)
  if good then
    cast.npTarget:SetText(name)
    local fine, class = pcall(UnitSpellTargetClass or error, unit)
    local color = fine and public(class) and class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if color then cast.npTarget:SetTextColor(color.r, color.g, color.b) else cast.npTarget:SetTextColor(1, 1, 1) end
  else
    cast.npTarget:SetText('')
  end
end
function E:CastStop(cast)
  if not cast.npYou then return end
  cast.npYou:SetAlpha(0); cast.npImportant:SetAlpha(0); cast.npTarget:SetText('')
end

local events = CreateFrame('Frame')
events:RegisterEvent('SPELLS_CHANGED')
events:SetScript('OnEvent', function(_, event, unit, behind)
  if event == 'SPELLS_CHANGED' then E:SpellsChanged() elseif NP.started then E:Behind(unit, behind) end
end)
-- The pointer event exists only on newer clients.
function E:Listen() pcall(events.RegisterEvent, events, 'NAME_PLATE_UNIT_BEHIND_CAMERA_CHANGED') end
