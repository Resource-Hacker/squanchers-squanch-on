-- SPDX-License-Identifier: MIT
-- Squanch-On nameplates: the debuff row and plate alpha (ns.NameplateAuras).
--
-- The row uses the same cell as the unit frames (UnitFrameAuras.lua exports its
-- constructor and painter), so icons carry the shared rim, swipe and stack
-- count. Aura facts can be secret: which debuffs are shown is decided by the
-- client through C_UnitAuras.IsAuraFilteredOutByInstanceID filter strings.
-- Cells need the unit-frame settings (fonts, pixel grid); until the unit
-- frames have initialised no row is drawn.
local _, ns = ...
local NP = ns.Nameplates
if not NP then return end
local Auras = {}
ns.NameplateAuras = Auras
local public, ask = NP.Public, NP.Ask
local UF = ns.UnitFrames
local Source = NP.Auras
local UnitExists, UnitIsUnit, UnitCanAssist = UnitExists, UnitIsUnit, NP.Unit('UnitCanAssist')

-- true = the client shows this aura under the filter, false = filtered out,
-- nil = it cannot say (no API, an unknown filter word, a secret answer).
local function passes(unit, aura, filter)
  if not NP.fake[unit] and not C_UnitAuras.IsAuraFilteredOutByInstanceID then return nil end
  local ok, hidden = pcall(Source.IsAuraFilteredOut, unit, aura, filter)
  if ok and public(hidden) and hidden ~= nil then return not hidden end
end
-- Debuffs: the player's own, and crowd control from anyone.
local function wanted(unit, aura, settings)
  if settings.cc and passes(unit, aura, 'HARMFUL|CROWD_CONTROL') == true then return true end
  if not settings.mine then return false end
  local shown = passes(unit, aura, 'HARMFUL|PLAYER')
  if shown == nil then
    local own = aura.isFromPlayerOrPlayerPet
    shown = public(own) and own == true
  end
  return shown
end
-- Buffs: major defensive cooldowns on players and on units the player can assist.
local function defensive(unit, aura)
  return passes(unit, aura, 'HELPFUL|BIG_DEFENSIVE') == true or passes(unit, aura, 'HELPFUL|EXTERNAL_DEFENSIVE') == true
end

local countdownFont
local function countdown(size)
  if not CreateFont then return end
  countdownFont = countdownFont or CreateFont('SquanchOnNameplateCountdown')
  countdownFont:SetFont(ns.Media and ns.Media:Resolve('font', 'Expressway') or STANDARD_TEXT_FONT, size or 8, 'OUTLINE')
  return 'SquanchOnNameplateCountdown'
end
-- Hovering shows the tooltip; clicks always fall through to the world.
local function mouse(button, enabled)
  button.sqMouse = enabled
  button:EnableMouse(enabled)
  if enabled and button.SetMouseClickEnabled then button:SetMouseClickEnabled(false) end
end

function Auras:Build(frame)
  local row = CreateFrame('Frame', nil, frame)
  row.spacing, row.ownCount, row.initialAnchor = 0, true, 'BOTTOMLEFT'
  row['growth-x'], row['growth-y'] = 'RIGHT', 'UP'
  row.config = { sortMethod = 'TIME_REMAINING', sortDirection = 'ASCENDING', countPosition = 'BOTTOMRIGHT' }
  row.disableMouse = true
  row:Hide()
  frame.AuraRow = row
  -- Several aura events in one frame repaint the row once.
  pcall(frame.RegisterEvent, frame, 'UNIT_AURA', function(self)
    if self.npAuraQueued then return end
    self.npAuraQueued = true
    C_Timer.After(0, function() self.npAuraQueued = nil; if NP.active[self] then Auras:Refresh(self) end end)
  end)
end

function Auras:Layout(frame, config)
  local row, settings = frame.AuraRow, NP:Settings().auras
  if not row then return end
  row.size, row.visibleLimit, row.countdown = settings.size, settings.max, settings.timer and true or false
  row.config.perrow, row.config.countFontSize = settings.perRow, settings.stackSize
  row.disableMouse = not (settings.tooltip and NP.gate)
  row:ClearAllPoints()
  row:SetPoint('BOTTOMLEFT', frame.Health, 'TOPLEFT', 0, (settings.y or 0) + (config.auraOffset or 0))
  row:SetSize(math.max(1, settings.perRow * settings.size), math.max(1, settings.size))
  local font = countdown(settings.timerSize)
  for index = 1, #row do
    local button = row[index]
    button.sqCountConfig = nil -- stack size is re-read on the next sort
    if font and button.Cooldown.SetCountdownFont then button.Cooldown:SetCountdownFont(font) end
  end
end

function Auras:Refresh(frame)
  local row, unit = frame.AuraRow, frame.unit
  if not row then return end
  local settings, kind, used = NP:Settings().auras, frame.npKind, 0
  local function show(aura, key)
    used = used + 1
    local button = row[used]
    if not button then
      button = UF.NewAuraIcon(row, frame); row[used] = button
      local font = countdown(settings.timerSize)
      if font and button.Cooldown.SetCountdownFont then button.Cooldown:SetCountdownFont(font) end
    end
    button.sqAura, button.sqRank = aura, 0
    UF.PaintAuraIcon(button, row, frame, unit, aura, key)
    if button.sqMouse and button.SetMouseClickEnabled then button:SetMouseClickEnabled(false) end
  end
  -- The row belongs to the bar: a plate that shows its name only has none.
  if settings.enabled and unit and kind ~= 'self' and frame.Health:IsShown() and UF and UF.db and UF.NewAuraIcon
    and C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
    for index = 1, 40 do
      local ok, aura = pcall(Source.GetAuraDataByIndex, unit, index, 'HARMFUL')
      if not ok or not aura then break end
      if wanted(unit, aura, settings) then show(aura, 'Debuffs') end
    end
    -- Enhancement: enemy buffs the player can remove, when such an ability is known.
    local enhance = ns.NameplateEnhance
    if enhance and enhance:On('auraRows') and (kind == 'enemynpc' or kind == 'enemyplayer') and enhance:Knows('purge') then
      for index = 1, 40 do
        local ok, aura = pcall(Source.GetAuraDataByIndex, unit, index, 'HELPFUL')
        if not ok or not aura then break end
        if passes(unit, aura, 'HELPFUL|RAID_PLAYER_DISPELLABLE') == true then show(aura, 'Buffs') end
      end
    end
    if settings.defensive and (kind == 'enemyplayer' or kind == 'friendlyplayer' or NP.Ask(UnitCanAssist, 'player', unit) == true) then
      for index = 1, 40 do
        local ok, aura = pcall(Source.GetAuraDataByIndex, unit, index, 'HELPFUL')
        if not ok or not aura then break end
        if defensive(unit, aura) then show(aura, 'Buffs') end
      end
    end
  end
  for index = used + 1, #row do row[index]:Hide(); row[index].sqAura = nil end
  row.createdButtons, row.visibleButtons, frame.npAuras = #row, used, used
  row:SetShown(used > 0)
  if used > 0 then UF:SortAuraButtons(row) end
end

-- The aura tooltip is offered only while the held mouseover gate is open, so
-- an icon never takes the cursor from the world outside that hold.
function Auras:SetMouse(open)
  local enabled = open and NP:Settings().auras.tooltip and true or false
  for frame in pairs(NP.active) do
    local row = frame.AuraRow
    if row then
      row.disableMouse = not enabled
      for index = 1, #row do
        if row[index].sqMouse ~= enabled then mouse(row[index], enabled) end
      end
    end
  end
  if not enabled and GameTooltip and not GameTooltip:IsForbidden() then
    local owner = GameTooltip:GetOwner()
    if owner and owner.sqAura then GameTooltip:Hide() end
  end
end

-- Plate alpha, as the author's Plater profile computed it ("range and
-- non-target", with division):
--   in range      plate, bar, cast and icons at inRange; a plate that is not
--                 the target multiplies each by its out-of-range value
--   out of range  the out-of-range values (the target keeps inRange), times
--                 nonTargetMultiplier when another unit is the target
--   an enemy NPC outside the fight while the player is in combat: notInCombat
-- Bar, cast bar and icon row are children of the plate frame, so their alphas
-- multiply with the plate's. Range costs item and spell checks and is asked
-- only when the two outcomes differ. Called from the shared ticker and on
-- target, cast and combat edges; plates with icons re-assert the plate alpha
-- so the icon rims, which ignore parent alpha, follow the game's own fade.
local function apply(frame, key, widget, value, force)
  if widget and (force or frame[key] ~= value) then frame[key] = value; widget:SetAlpha(value) end
end
function Auras:Alpha(frame, force)
  local unit = frame.unit
  if not unit or frame.npKind == 'self' then return end
  local all = NP:Settings()
  local settings, cast = all.alpha, frame.Castbar
  local plate, bar, casting, icons
  if frame.npNoCombat then
    plate, bar, casting, icons = settings.notInCombat, 1, 1, all.auras.alpha
  else
    local target, fake = NP:IsTarget(frame), frame.npFake
    local other
    if fake then other = fake.otherTarget or false
    else other = not target and ask(UnitExists, 'target') == true and ask(UnitIsUnit, 'target', 'player') ~= true end
    local near, mult = settings.inRange, other and settings.nonTargetMultiplier or 1
    local inPlate, outPlate = near * (other and settings.outOfRange or 1), (target and near or settings.outOfRange) * mult
    local inBar, outBar = near * (other and settings.healthOutOfRange or 1), (target and near or settings.healthOutOfRange) * mult
    local inCast, outCast = near * (other and settings.castOutOfRange or 1), (target and near or settings.castOutOfRange) * mult
    local inIcons, outIcons = near * (other and settings.aurasOutOfRange or 1), (target and near or settings.aurasOutOfRange) * mult
    local differs = inPlate ~= outPlate or inBar ~= outBar or inIcons ~= outIcons
      or (inCast ~= outCast and cast and cast:IsShown())
    local inRange
    if fake then inRange = fake.inRange ~= false
    else inRange = not differs or (ns.Range and ns.Range:Within(unit, settings.rangeYards or 40) == true) end
    if inRange then plate, bar, casting, icons = inPlate, inBar, inCast, inIcons
    else plate, bar, casting, icons = outPlate, outBar, outCast, outIcons end
  end
  apply(frame, 'npAlpha', frame, plate, force or (frame.npAuras or 0) > 0)
  apply(frame, 'npBarAlpha', frame.Health, bar, force)
  apply(frame, 'npCastAlpha', cast, casting, force)
  apply(frame, 'npRowAlpha', frame.AuraRow, icons, force)
end
