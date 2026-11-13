-- SPDX-License-Identifier: MIT
-- Squanch-On nameplates: the debuff row and plate alpha (ns.NameplateAuras).
--
-- The row uses the same cell as the unit frames (UnitFrameAuras.lua exports its
-- constructor and painter), so icons carry the shared rim, swipe and stack
-- count. Which auras are shown is decided by the client through aura filter
-- strings: the player's own debuffs ('HARMFUL|PLAYER'), crowd control from
-- anyone, and the optional buff lists (see `want`).
--
-- Addon code may read auras only while aura data is readable. In combat (and
-- in encounters, keystones and PvP matches) the client refuses every
-- C_UnitAuras read from an addon, and single spells can be secret at any time.
-- Then the row hands over to the client's own aura container, shared with the
-- unit frame rows (UnitFrameAuras.lua, UF:SyncNativeAuras): its secure code
-- reads the auras through the same filter strings and draws them into buttons
-- dressed with the row's cell look. Otherwise the row reads and draws the
-- auras itself, as before. Cells need the unit-frame settings (fonts, pixel
-- grid); until the unit frames have initialised no row is drawn.
local _, ns = ...
local NP = ns.Nameplates
if not NP then return end
local Auras = {}
ns.NameplateAuras = Auras
local public, ask = NP.Public, NP.Ask
local UF = ns.UnitFrames
local Source = NP.Auras
local UnitExists, UnitIsUnit, UnitCanAssist = UnitExists, UnitIsUnit, NP.Unit('UnitCanAssist')

-- Set when the client refuses a read during one Refresh.
local refused = false
-- One aura by index; nil and true when the client refused it.
local function read(unit, index, filter)
  local ok, aura = pcall(Source.GetAuraDataByIndex, unit, index, filter)
  if ok then return aura end
  refused = true
  UF:AuraReport('C_UnitAuras.GetAuraDataByIndex ' .. filter, aura)
  return nil, true
end
-- true = the client shows this aura under the filter, false = filtered out,
-- nil = it cannot say (no API, an unknown filter word, a secret answer).
local function passes(unit, aura, filter)
  if not NP.fake[unit] and not C_UnitAuras.IsAuraFilteredOutByInstanceID then return nil end
  local ok, hidden = pcall(Source.IsAuraFilteredOut, unit, aura, filter)
  if not ok then
    refused = true
    UF:AuraReport('C_UnitAuras.IsAuraFilteredOutByInstanceID ' .. filter, hidden)
    return nil
  end
  if public(hidden) and hidden ~= nil then return not hidden end
end
-- Debuffs: the player's own, and crowd control from anyone (see gather).
local ownIDs = {}
-- Buffs: major defensive cooldowns on players and on units the player can assist.
local function defensive(unit, aura)
  return passes(unit, aura, 'HELPFUL|BIG_DEFENSIVE') == true or passes(unit, aura, 'HELPFUL|EXTERNAL_DEFENSIVE') == true
end
-- Which lists the row shows on this plate (one table, refilled per call).
local wanted = {}
local function want(settings, kind, unit)
  local enhance = ns.NameplateEnhance
  wanted.mine, wanted.cc = settings.mine and true or false, settings.cc and true or false
  -- Enhancement: enemy buffs the player can remove, when such an ability is known.
  wanted.purge = enhance and enhance:On('auraRows') and (kind == 'enemynpc' or kind == 'enemyplayer')
    and enhance:Knows('purge') and true or false
  local guard = settings.defensive and (kind == 'enemyplayer' or kind == 'friendlyplayer'
    or ask(UnitCanAssist, 'player', unit) == true) and true or false
  wanted.big, wanted.external = guard, guard
  return wanted
end

-- One font object for every countdown number: set again only when its size changes.
local auraEvent
local countdownFont, countdownSize
local function countdown(size)
  if not CreateFont then return end
  size = size or 8
  if not countdownFont or countdownSize ~= size then
    countdownFont = countdownFont or CreateFont('SquanchOnNameplateCountdown')
    countdownSize = size
    countdownFont:SetFont(ns.Media and ns.Media:Resolve('font', 'Expressway') or STANDARD_TEXT_FONT, size, 'OUTLINE')
    countdownFont:SetShadowColor(0, 0, 0, 1); countdownFont:SetShadowOffset(1, -1)
  end
  return 'SquanchOnNameplateCountdown'
end
-- Hovering shows the tooltip; clicks always fall through to the world.
local function mouse(button, enabled)
  button.sqMouse = enabled
  button:EnableMouse(enabled)
  if enabled and button.SetMouseClickEnabled then button:SetMouseClickEnabled(false) end
end

-- Whether an aura event can change the row. A full update and a new aura can;
-- a change or removal only when it concerns an icon the row shows. Without
-- update details (or with unreadable ones) the answer is yes.
local function listed(row, ids)
  if type(ids) ~= 'table' then return ids ~= nil end
  for index = 1, #ids do
    local id = ids[index]
    if not public(id) or row.shownIDs[id] then return true end
  end
  return false
end
local function concerns(row, info)
  if type(info) ~= 'table' or not public(info.isFullUpdate) or info.isFullUpdate then return true end
  local added = info.addedAuras
  if added ~= nil and (type(added) ~= 'table' or #added > 0) then return true end
  return listed(row, info.updatedAuraInstanceIDs) or listed(row, info.removedAuraInstanceIDs)
end
-- Several aura events in one frame repaint the row once.
local queue, queued = {}, false
local function flush()
  queued = false
  for index = 1, #queue do
    local frame = queue[index]
    queue[index] = nil
    frame.npAuraQueued = nil
    if NP.active[frame] then Auras:Refresh(frame) end
  end
end
auraEvent = function(self, _, _, info)
  local row = self.AuraRow
  if self.npAuraQueued or not row then return end
  -- The client's container follows the unit's aura events itself.
  if self.npNativeOn and UF:AurasSecret() then return end
  -- A plate that shows its name only has no row to change.
  if not self.Health:IsShown() and (self.npAuras or 0) == 0 and not self.npNativeOn then return end
  -- Update details the client keeps secret count as a change.
  local ok, changes = pcall(concerns, row, info)
  if ok and not changes then return end
  self.npAuraQueued = true
  queue[#queue + 1] = self
  if not queued then queued = true; C_Timer.After(0, flush) end
end

-- The client's container (UnitFrameAuras.lua, UF:SyncNativeAuras) ----------------
-- One per plate, kept hidden and idle while the row reads auras itself. Groups
-- follow the row's lists, in its order; each is added the first time it is
-- wanted. The buttons take no mouse (no tooltip; the cursor and clicks reach the world).
local GROUPS = { 'mine', 'cc', 'purge', 'big', 'external' }
local function groupFilter(key, settings)
  if key == 'mine' then return 'HARMFUL|PLAYER' end
  -- Crowd control from anyone; the player's own is already in 'mine'.
  if key == 'cc' then return settings.mine and 'HARMFUL|CROWD_CONTROL|!PLAYER' or 'HARMFUL|CROWD_CONTROL' end
  if key == 'purge' then return 'HELPFUL|RAID_PLAYER_DISPELLABLE' end
  if key == 'big' then return 'HELPFUL|BIG_DEFENSIVE' end
  return 'HELPFUL|EXTERNAL_DEFENSIVE|!BIG_DEFENSIVE'
end
-- The wanted groups (one reused list) and the row's look (one reused table).
local nativeGroups, groupOf, nativeSpec = {}, {}, {}
for index, key in ipairs(GROUPS) do groupOf[key] = { key = key, order = index } end
local function groups(settings, wants)
  local _, _, _, desaturate = UF:AuraCellLook()
  local max = math.max(1, math.floor(tonumber(settings.max) or 16))
  for index = #nativeGroups, 1, -1 do nativeGroups[index] = nil end
  for _, key in ipairs(GROUPS) do
    if wants[key] then
      local group = groupOf[key]
      group.filter, group.max = groupFilter(key, settings), max
      -- As the painter: others' debuffs turn grey only under the 'always' setting.
      group.desaturate = desaturate and key == 'cc' and settings.mine and true or false
      nativeGroups[#nativeGroups + 1] = group
    end
  end
  return nativeGroups
end
local function look(settings)
  local spec = nativeSpec
  local cell = UF:Scale(settings.size)
  local per = math.max(1, math.floor(tonumber(settings.perRow) or 8))
  local _, _, countFont = UF:AuraCellLook()
  spec.anchor, spec.growX, spec.growY = 'BOTTOMLEFT', 'RIGHT', 'UP'
  spec.width, spec.height, spec.spacing = cell, cell, 0
  -- Half a cell of slack, so a full line never wraps on rounding.
  spec.line = per * cell + cell / 2
  spec.numbers, spec.countdownFont = settings.timer and true or false, countdown(settings.timerSize)
  spec.countFont, spec.countSize, spec.countOutline = countFont or UF.db.font, settings.stackSize or 8, 'OUTLINE'
  spec.countCorner, spec.countX, spec.countY = 'BOTTOMRIGHT', 0, 0
  spec.mouse, spec.gen = false, NP.generation
  return spec
end

function Auras:Build(frame)
  local row = CreateFrame('Frame', nil, frame)
  row.spacing, row.ownCount, row.initialAnchor = 0, true, 'BOTTOMLEFT'
  row['growth-x'], row['growth-y'] = 'RIGHT', 'UP'
  row.config = { sortMethod = 'TIME_REMAINING', sortDirection = 'ASCENDING', countPosition = 'BOTTOMRIGHT' }
  row.disableMouse = true
  row:Hide()
  frame.AuraRow = row
  row.shownIDs = {}
  pcall(frame.RegisterEvent, frame, 'UNIT_AURA', auraEvent)
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
  -- The client's container follows the settings on the next Refresh.
end

-- The row being filled (one at a time), and the auras read for it.
local fillRow, fillFrame, fillUnit, fillUsed, fillSettings
local found, foundCount = {}, 0
local function add(aura, key)
  foundCount = foundCount + 1
  local entry = found[foundCount]
  if not entry then entry = {}; found[foundCount] = entry end
  entry[1], entry[2] = aura, key
end
local function show(aura, key)
  fillUsed = fillUsed + 1
  local row = fillRow
  local button = row[fillUsed]
  if not button then
    button = UF.NewAuraIcon(row, fillFrame); row[fillUsed] = button
    local font = countdown(fillSettings.timerSize)
    if font and button.Cooldown.SetCountdownFont then button.Cooldown:SetCountdownFont(font) end
  end
  button.sqAura, button.sqRank = aura, 0
  local id = aura.auraInstanceID
  if id ~= nil and public(id) then row.shownIDs[id] = true end
  UF.PaintAuraIcon(button, row, fillFrame, fillUnit, aura, key)
  if button.sqMouse and button.SetMouseClickEnabled then button:SetMouseClickEnabled(false) end
end
-- Reads the row's auras into `found`. A refused read skips that one aura, so an
-- aura the client keeps from addon code never empties the rest of the row;
-- with a container to hand over to (`stop`), the first refusal ends reading.
local function gather(unit, wants, stop)
  for id in pairs(ownIDs) do ownIDs[id] = nil end
  if wants.mine then
    for index = 1, 40 do
      local aura, denied = read(unit, index, 'HARMFUL|PLAYER')
      if denied then
        if stop then return end
      elseif not aura then break
      else
        local id = aura.auraInstanceID
        if id ~= nil and public(id) then ownIDs[id] = true end
        add(aura, 'Debuffs')
      end
    end
  end
  if wants.cc then
    for index = 1, 40 do
      local aura, denied = read(unit, index, 'HARMFUL')
      if denied then
        if stop then return end
      elseif not aura then break
      else
        local id = aura.auraInstanceID
        if not (id ~= nil and public(id) and ownIDs[id]) and passes(unit, aura, 'HARMFUL|CROWD_CONTROL') == true then
          add(aura, 'Debuffs')
        end
        if stop and refused then return end
      end
    end
  end
  if wants.purge or wants.big then
    for index = 1, 40 do
      local aura, denied = read(unit, index, 'HELPFUL')
      if denied then
        if stop then return end
      elseif not aura then break
      else
        if wants.purge and passes(unit, aura, 'HELPFUL|RAID_PLAYER_DISPELLABLE') == true then add(aura, 'Buffs') end
        if wants.big and defensive(unit, aura) then add(aura, 'Buffs') end
        if stop and refused then return end
      end
    end
  end
end
function Auras:Refresh(frame)
  local row, unit = frame.AuraRow, frame.unit
  if not row then return end
  local settings, kind = NP:Settings().auras, frame.npKind
  for id in pairs(row.shownIDs) do row.shownIDs[id] = nil end
  -- The row belongs to the bar: a plate that shows its name only has none.
  local drawn = settings.enabled and unit and kind ~= 'self' and frame.Health:IsShown() and UF and UF.db and UF.NewAuraIcon
    and C_UnitAuras and C_UnitAuras.GetAuraDataByIndex and true or false
  local real = drawn and not NP.fake[unit]
  local wants = drawn and want(settings, kind, unit)
  local container = row.sqNative or nil
  if real then container = UF:NativeAuras(row) end
  -- Secret aura data, or a read the client refuses: its container draws the row.
  local handed = real and container and UF:AurasSecret() or false
  foundCount, refused = 0, false
  if drawn and not handed then
    gather(unit, wants, container ~= nil)
    if container and refused then
      handed = true
      for index = 1, foundCount do found[index][1] = nil end
      foundCount = 0
    end
  end
  if container then
    if real and wants then UF:SyncNativeAuras(container, unit, look(settings), groups(settings, wants), handed)
    else UF:SyncNativeAuras(container) end
  end
  frame.npNativeOn = handed or nil
  fillRow, fillFrame, fillUnit, fillUsed, fillSettings = row, frame, unit, 0, settings
  for index = 1, foundCount do
    local entry = found[index]
    show(entry[1], entry[2])
    entry[1] = nil
  end
  local used = fillUsed
  fillRow, fillFrame, fillUnit, fillSettings = nil, nil, nil, nil
  for index = used + 1, #row do row[index]:Hide(); row[index].sqAura = nil end
  row.createdButtons, row.visibleButtons, frame.npAuras = #row, used, used
  row:SetShown(used > 0 or handed)
  if used > 0 then UF:SortAuraButtons(row) end
end

-- Aura data turns secret or readable at combat and restriction edges
-- (UF:OnAuraSecrecyEdge): plates whose row is in the other mode are redrawn.
if UF and UF.OnAuraSecrecyEdge then
  UF:OnAuraSecrecyEdge(function(secret)
    for frame in pairs(NP.active) do
      if (frame.npNativeOn or false) ~= secret then Auras:Refresh(frame) end
    end
  end)
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
-- only when the two outcomes differ, and then only when `probe` says it is
-- this plate's turn (NP:Tick) or its last answer is missing or older than
-- RANGE_KEEP seconds; otherwise the last answer stands. Called from the shared
-- ticker and on target, cast and combat edges; plates with icons re-assert the
-- plate alpha so the icon rims, which ignore parent alpha, follow the game's own fade.
-- Line of sight is that fade: the client multiplies its NamePlate frame (this
-- frame's parent) by nameplateOccludedAlphaMult while it sees the unit hidden
-- behind walls, and no API answers it otherwise. Real plates inherit it on top
-- of everything here, the target included; a preview plate has no such parent,
-- so a made-up `occluded` unit takes the same factor here.
local RANGE_KEEP = 1.5
local function apply(frame, key, widget, value, force)
  if widget and (force or frame[key] ~= value) then frame[key] = value; widget:SetAlpha(value) end
end
function Auras:Alpha(frame, force, probe)
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
    elseif not differs then inRange = true
    else
      local now = GetTime()
      if probe or not frame.npRangeAt or now - frame.npRangeAt > RANGE_KEEP then
        frame.npRangeAt = now
        frame.npInRange = ns.Range and ns.Range:Within(unit, settings.rangeYards or 40) == true or false
      end
      inRange = frame.npInRange
    end
    if inRange then plate, bar, casting, icons = inPlate, inBar, inCast, inIcons
    else plate, bar, casting, icons = outPlate, outBar, outCast, outIcons end
  end
  if frame.npFake and frame.npFake.occluded then plate = plate * (tonumber(all.cvars.nameplateOccludedAlphaMult) or 1) end
  apply(frame, 'npAlpha', frame, plate, force or (frame.npAuras or 0) > 0)
  apply(frame, 'npBarAlpha', frame.Health, bar, force)
  apply(frame, 'npCastAlpha', cast, casting, force)
  apply(frame, 'npRowAlpha', frame.AuraRow, icons, force)
end
