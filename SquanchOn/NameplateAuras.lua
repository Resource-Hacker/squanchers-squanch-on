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
-- C_UnitAuras read from an addon: "Auras cannot be accessed when secret while
-- tainted" (those functions carry the RequiresUnitAuraAccess precondition,
-- Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua), and single
-- spells can be secret at any time. Then the row hands over to the client's
-- own aura container (Blizzard_AuraContainer, CustomAuraContainerTemplate,
-- which current oUF and Plater use too): its secure code reads the auras
-- through the same filter strings and draws them into buttons this file only
-- dresses. Otherwise the row reads and draws the auras itself, as before.
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

-- Whether aura data is secret right now: then only the client's container can show it.
local function secretAuras()
  local query = C_Secrets and C_Secrets.ShouldAurasBeSecret
  if query then
    local ok, secret = pcall(query)
    if ok and public(secret) then return secret == true end
  end
  return InCombatLockdown()
end
-- TEMPORARY diagnostic (remove once plate auras are confirmed in a fight): the
-- first refused plate aura call of a session prints one chat line.
local reported
local function report(api, err)
  if reported then return end
  reported = true
  print(('|cff33ff99Squanch-On|r TEMPORARY plate-aura check: %s failed (%s, aura data %s): %s'):format(api,
    InCombatLockdown() and 'in combat' or 'out of combat', secretAuras() and 'secret' or 'readable', tostring(err)))
end

-- Set when the client refuses a read during one Refresh.
local refused = false
-- One aura by index; nil and true when the client refused it.
local function read(unit, index, filter)
  local ok, aura = pcall(Source.GetAuraDataByIndex, unit, index, filter)
  if ok then return aura end
  refused = true
  report('C_UnitAuras.GetAuraDataByIndex ' .. filter, aura)
  return nil, true
end
-- true = the client shows this aura under the filter, false = filtered out,
-- nil = it cannot say (no API, an unknown filter word, a secret answer).
local function passes(unit, aura, filter)
  if not NP.fake[unit] and not C_UnitAuras.IsAuraFilteredOutByInstanceID then return nil end
  local ok, hidden = pcall(Source.IsAuraFilteredOut, unit, aura, filter)
  if not ok then
    refused = true
    report('C_UnitAuras.IsAuraFilteredOutByInstanceID ' .. filter, hidden)
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
  if self.npNativeOn and secretAuras() then return end
  -- A plate that shows its name only has no row to change.
  if not self.Health:IsShown() and (self.npAuras or 0) == 0 and not self.npNativeOn then return end
  -- Update details the client keeps secret count as a change.
  local ok, changes = pcall(concerns, row, info)
  if ok and not changes then return end
  self.npAuraQueued = true
  queue[#queue + 1] = self
  if not queued then queued = true; C_Timer.After(0, flush) end
end

-- The client's container ------------------------------------------------------
-- One per plate, made the first time the row is drawn for a real unit (mostly
-- out of combat, so a fight never waits for it) and kept hidden and disabled
-- while the row reads auras itself. Groups follow the row's lists, in its
-- order; each is added the first time it is wanted (the client then makes ten
-- buttons for it at once). The buttons accept addon calls only while aura data
-- is readable: they are dressed when made and restyled only then, and they take
-- no mouse (no tooltip; the cursor and clicks reach the world).
local GROUPS = { 'mine', 'cc', 'purge', 'big', 'external' }
local ORDER = { mine = 1, cc = 2, purge = 3, big = 4, external = 5 }
local function groupFilter(key, settings)
  if key == 'mine' then return 'HARMFUL|PLAYER' end
  -- Crowd control from anyone; the player's own is already in 'mine'.
  if key == 'cc' then return settings.mine and 'HARMFUL|CROWD_CONTROL|!PLAYER' or 'HARMFUL|CROWD_CONTROL' end
  if key == 'purge' then return 'HELPFUL|RAID_PLAYER_DISPELLABLE' end
  if key == 'big' then return 'HELPFUL|BIG_DEFENSIVE' end
  return 'HELPFUL|EXTERNAL_DEFENSIVE|!BIG_DEFENSIVE'
end
local function call(object, method, ...)
  local ok, err = pcall(object[method], object, ...)
  if not ok then report('AuraContainer:' .. method, err) end
  return ok
end
-- The shared rim, cut from the atlas of DarkSkin's raw slot rim: its four
-- straight edges as they are and each corner as one square (eight textures
-- instead of 58 halo-free strips, as the client makes these buttons in tens).
-- Not registered with DarkSkin, whose passes would have to touch them in combat.
local RIM_ATLAS = 'UI-Character-Info-GearSlot'
local RIM = { { 13, 4.5, 42, 9 }, { 13, 46, 42, 50.5 }, { 4.5, 13, 9, 42 }, { 46, 13, 50.5, 42 },
  { 2, 2, 13, 13 }, { 42, 2, 53, 13 }, { 2, 42, 13, 53 }, { 42, 42, 53, 53 } }
local rimAtlas
local function rimPiece(button, rect)
  local texture = button:CreateTexture(nil, 'BACKGROUND')
  if rimAtlas == nil then rimAtlas = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(RIM_ATLAS) or false end
  if rimAtlas then
    local left, top = rimAtlas.leftTexCoord, rimAtlas.topTexCoord
    local dx, dy = (rimAtlas.rightTexCoord - left) / 55, (rimAtlas.bottomTexCoord - top) / 55
    texture:SetTexture(rimAtlas.file)
    texture:SetTexCoord(left + rect[1] * dx, left + rect[3] * dx, top + rect[2] * dy, top + rect[4] * dy)
  end
  texture:SetSnapToPixelGrid(false); texture:SetTexelSnappingBias(0)
  return texture
end
-- The row painter's look (UnitFrameAuras.lua): cell size, rim, swipe, countdown
-- numbers and stack count. The rim inherits the plate's alpha like any child.
local function restyle(button, settings)
  local rim, swipe, countFont, desaturate = UF:AuraCellLook()
  local cell = UF:Scale(settings.size)
  button:SetSize(cell, cell)
  local inner = rim and cell * 37 / 43 or cell
  button.sqIcon:SetSize(inner, inner)
  -- As the painter: others' debuffs turn grey only under the 'always' setting.
  button.sqIcon:SetDesaturated(desaturate and button.sqGroup == 'cc' and settings.mine and true or false)
  local cooldown = button.sqCooldown
  if cooldown.SetDrawSwipe then cooldown:SetDrawSwipe(swipe) end
  if cooldown.SetHideCountdownNumbers then cooldown:SetHideCountdownNumbers(not settings.timer) end
  local font = countdown(settings.timerSize)
  if font and cooldown.SetCountdownFont then cooldown:SetCountdownFont(font) end
  UF:ApplyFont(button.sqCount, countFont or UF.db.font, settings.stackSize or 8, 'OUTLINE')
  local skin = ns.DarkSkin
  local color, alpha, size = skin and skin.rimColor, skin and skin.borderAlpha or 0.95, cell * 55 / 43
  for index, piece in ipairs(button.sqRim) do
    local rect = RIM[index]
    piece:ClearAllPoints()
    piece:SetPoint('TOPLEFT', button, 'CENTER', size * (rect[1] / 55 - 0.5), size * (0.5 - rect[2] / 55))
    piece:SetSize(size * (rect[3] - rect[1]) / 55, size * (rect[4] - rect[2]) / 55)
    if color then piece:SetDesaturated(true); piece:SetVertexColor(color[1], color[2], color[3]) end
    piece:SetAlpha(alpha)
    piece:SetShown(rim)
  end
end
-- Called by the client for each button it makes, before it closes them to addons.
local function dress(button, container, key)
  local ok, err = pcall(function()
    button:EnableMouse(false)
    local icon = button:CreateTexture(nil, 'ARTWORK')
    icon:SetPoint('CENTER'); icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local cooldown = CreateFrame('Cooldown', nil, button, 'CooldownFrameTemplate')
    cooldown:SetAllPoints(icon); cooldown:SetReverse(true); cooldown:SetDrawEdge(false)
    local overlay = CreateFrame('Frame', nil, button)
    overlay:SetAllPoints(); overlay:SetFrameLevel(cooldown:GetFrameLevel() + 1)
    local count = overlay:CreateFontString(nil, 'OVERLAY')
    count:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', 0, 0)
    local rim = {}
    for index, rect in ipairs(RIM) do rim[index] = rimPiece(button, rect) end
    button.sqIcon, button.sqCooldown, button.sqCount, button.sqRim, button.sqGroup = icon, cooldown, count, rim, key
    restyle(button, NP:Settings().auras)
    -- The client draws icon, swipe and stack count from the aura itself.
    button:SetIcon(icon); button:SetDurationCooldown(cooldown); button:SetApplicationCount(count)
    container.sqButtons[#container.sqButtons + 1] = button
  end)
  if not ok then report('aura button setup', err) end
end
local templateReady
local function containerFor(frame)
  local container = frame.npContainer
  if container ~= nil then return container or nil end
  frame.npContainer = false
  if templateReady == nil then
    local ok, info = false, nil
    if C_XMLUtil and C_XMLUtil.GetTemplateInfo then ok, info = pcall(C_XMLUtil.GetTemplateInfo, 'CustomAuraContainerTemplate') end
    templateReady = ok and info ~= nil
  end
  if not templateReady then return end
  local ok, made = pcall(CreateFrame, 'AuraContainer', nil, frame.AuraRow, 'CustomAuraContainerTemplate')
  if not ok then report('CreateFrame AuraContainer', made); return end
  -- Anchored once, before any group: the client sizes it from then on.
  made:SetPoint('BOTTOMLEFT', frame.AuraRow, 'BOTTOMLEFT')
  made:SetSize(1, 1)
  made:Hide()
  local flow = AnchorUtil and AnchorUtil.FlowDirection
  call(made, 'SetFlowLayoutAnchorPoint', 'BOTTOMLEFT')
  call(made, 'SetFlowLayoutGrowthDirection', flow and flow.Right or 1, flow and flow.Up or 1)
  made.sqGroups, made.sqOn, made.sqButtons = {}, {}, {}
  frame.npContainer = made
  return made
end
local function groupLayout(cell, key)
  return { elementSpacing = 0, lineSpacing = 0, groupSpacing = 0, forceNewLine = false,
    elementWidth = cell, elementHeight = cell, layoutIndex = ORDER[key] }
end
-- Line width, cell size and cap follow the settings at once; the buttons' own
-- look only while aura data is readable (otherwise on a later pass).
local function fitNative(container, settings)
  local cell = UF:Scale(settings.size)
  local max = math.max(1, math.floor(tonumber(settings.max) or 16))
  local per = math.max(1, math.floor(tonumber(settings.perRow) or 8))
  if container.sqCell ~= cell or container.sqPer ~= per or container.sqMax ~= max then
    container.sqCell, container.sqPer, container.sqMax, container.sqGen = cell, per, max, nil
    -- Half a cell of slack, so a full line never wraps on rounding.
    call(container, 'SetFlowLayoutMaximumLineSize', per * cell + cell / 2)
    for key in pairs(container.sqGroups) do
      call(container, 'SetAuraGroupLayout', key, groupLayout(cell, key))
      call(container, 'SetAuraGroupMaxFrameCount', key, max)
    end
  end
  local _, _, _, _, revision = UF:AuraCellLook()
  if (container.sqGen ~= NP.generation or container.sqRev ~= revision) and not secretAuras() then
    container.sqGen, container.sqRev = NP.generation, revision
    for _, button in ipairs(container.sqButtons) do pcall(restyle, button, settings) end
  end
end
-- Brings the plate's container in line with the row: the wanted groups, and
-- shown and reading only while `on`. `wants` false: hidden and idle.
local function syncNative(container, unit, settings, wants, on)
  if wants then
    fitNative(container, settings)
    for _, key in ipairs(GROUPS) do
      local wanted = wants[key]
      -- A group the client rejected is not asked for again (false).
      if wanted and container.sqGroups[key] == nil then
        local filter = groupFilter(key, settings)
        local added = call(container, 'AddAuraGroup', key, filter, {
          maxFrameCount = container.sqMax,
          sortMethod = AuraContainerSortMethod and AuraContainerSortMethod.ExpirationOnly,
          sortDirection = AuraContainerSortDirection and AuraContainerSortDirection.Normal,
          layout = groupLayout(container.sqCell, key),
          initializeFrame = function(button) dress(button, container, key) end,
        })
        container.sqGroups[key] = added and filter or false
        if added then container.sqOn[key] = true end
      end
      local filter = container.sqGroups[key]
      if filter then
        local now = groupFilter(key, settings)
        if now ~= filter and call(container, 'SetAuraGroupFilterString', key, now) then container.sqGroups[key] = now end
        if container.sqOn[key] ~= wanted and call(container, 'SetAuraGroupEnabled', key, wanted) then
          container.sqOn[key] = wanted
        end
      end
    end
    if on then call(container, 'SetUnit', unit) end
  end
  on = on and wants and true or false
  if container.sqEnabled ~= on and call(container, 'SetEnabled', on) then container.sqEnabled = on end
  container:SetShown(on)
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
  if frame.npContainer then fitNative(frame.npContainer, settings) end
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
  local container = frame.npContainer or nil
  if real then container = containerFor(frame) end
  -- Secret aura data, or a read the client refuses: its container draws the row.
  local handed = real and container and secretAuras() or false
  foundCount, refused = 0, false
  if drawn and not handed then
    gather(unit, wants, container ~= nil)
    if container and refused then
      handed = true
      for index = 1, foundCount do found[index][1] = nil end
      foundCount = 0
    end
  end
  if container then syncNative(container, unit, settings, real and wants, handed) end
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

-- Aura data turns secret or readable at combat and restriction edges. Plates
-- whose row is in the other mode are redrawn on the next frame, once the
-- client's restriction state has settled after its event.
local edges, edgeQueued = CreateFrame('Frame'), false
local function edge()
  edgeQueued = false
  local secret = secretAuras()
  for frame in pairs(NP.active) do
    if (frame.npNativeOn or false) ~= secret then Auras:Refresh(frame) end
  end
end
edges:RegisterEvent('PLAYER_REGEN_DISABLED'); edges:RegisterEvent('PLAYER_REGEN_ENABLED')
pcall(edges.RegisterEvent, edges, 'ADDON_RESTRICTION_STATE_CHANGED')
edges:SetScript('OnEvent', function()
  if edgeQueued or not C_Timer then return end
  edgeQueued = true
  C_Timer.After(0, edge)
end)

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
