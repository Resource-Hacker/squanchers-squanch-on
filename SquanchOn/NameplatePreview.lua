-- SPDX-License-Identifier: MIT
-- Squanch-On nameplates: preview plates (ns.NameplatePreview).
-- /sqplates test [on|off] shows a movable row of made-up plates near the screen
-- centre; /sqplates test enh adds the same row with the enhancements on. The
-- plates are built and painted by the same style, cast and aura code as real
-- plates; only the unit facts are made up (NP.fake). They are plain frames
-- under UIParent, so this also works while Plater is loaded and in combat.
-- Nothing exists and nothing runs until the first /sqplates test.
--
-- Scale: plate sizes are UIParent units and a real plate applies UIParent's
-- scale itself, so a preview under UIParent uses the plain setting. The client
-- enlarges the selected plate by nameplateSelectedScale; selected previews
-- apply that CVar's value themselves.
local _, ns = ...
local NP = ns.Nameplates
if not NP then return end
local Preview = { rows = {} }
ns.NameplatePreview = Preview

local function aura(icon, duration, extra)
  local record = { test = true, icon = icon, duration = duration, applications = 1 }
  for key, value in pairs(extra or {}) do record[key] = value end
  return record
end
local MOB = { name = 'Kobold Digger', attack = true, level = 12 }
local function case(caption, facts, base)
  local copy = { caption = caption }
  for key, value in pairs(base or MOB) do copy[key] = value end
  for key, value in pairs(facts or {}) do copy[key] = value end
  return copy
end
local FRIEND = { name = 'Innkeeper', attack = false, reaction = 5, level = 30 }
local HORDE = { name = 'Zugzug', guild = 'Guild Name', attack = false, reaction = 5, level = 24, player = true, class = 'HUNTER', faction = 'Horde' }
local CASES = {
  case('Enemy NPC'),
  case('Target, in combat, debuffs', { target = true, playerCombat = true, combat = true, threat = 3, health = 64,
    auras = { aura(136139, 18, { mine = true }), aura(132204, 12, { mine = true, applications = 3 }), aura(136071, 8, { cc = true }) } }),
  case('Casting', { playerCombat = true, combat = true, threat = 0, cast = { name = 'Fireball', icon = 135812, time = 2.5 } }),
  case('Channelling', { playerCombat = true, combat = true, threat = 0, cast = { name = 'Drain Life', icon = 136169, time = 4, channel = true } }),
  case('Cast, no interrupt', { playerCombat = true, combat = true, threat = 0, cast = { name = 'Shadow Bolt', icon = 136197, time = 3, locked = true } }),
  case('Elite', { classification = 'elite', level = 14 }),
  case('Rare', { classification = 'rare' }),
  case('About to pull', { playerCombat = true, combat = true, threat = 1 }),
  case('Not on you', { playerCombat = true, combat = true, threat = 0 }),
  case('Outside your fight', { playerCombat = true }),
  case('Tapped', { tapped = true }),
  case('Low health', { playerCombat = true, combat = true, threat = 3, health = 15 }),
  case('Quest unit', { quest = true }),
  case('Enemy player', { name = 'Stabby', guild = 'Other Guild', player = true, class = 'ROGUE', faction = 'Alliance', level = 25, power = 70 }),
  case('Friendly NPC', nil, FRIEND),
  case('Friendly NPC, target', { target = true }, FRIEND),
  case('Friendly player', nil, HORDE),
  case('Friendly Horde, target', { target = true }, HORDE),
  case('Other target, out of range', { otherTarget = true, inRange = false }),
}

local function noop() end
local function paint(frame, enhanced)
  local Style, Enhance, facts = ns.NameplateStyle, ns.NameplateEnhance, frame.npFake
  if Enhance then Enhance.force = enhanced and true or false end
  Style:Classify(frame, frame.unit)
  Style:Layout(frame)
  Style:Refresh(frame)
  local health = frame.Health
  health:SetMinMaxValues(0, 100); health:SetValue(facts.health or 100)
  health.PostUpdate(health, frame.unit, facts.health or 100, 100)
  local power = frame.Power
  power:SetMinMaxValues(0, 100); power:SetValue(facts.power or 100); power:SetStatusBarColor(1, 0.96, 0.41)
  power.PostUpdate(power, frame.unit)
  local cast = frame.Castbar
  if facts.cast and frame.npKind ~= 'self' then
    cast.casting, cast.channeling, cast.notInterruptible = not facts.cast.channel, facts.cast.channel or false, facts.cast.locked or false
    cast:SetMinMaxValues(0, facts.cast.time)
    cast.Icon:SetTexture(facts.cast.icon); cast.Text:SetText(facts.cast.name)
    cast.Shield:SetTexture('Interface\\CastingBar\\UI-CastingBar-Small-Shield')
    cast.Shield:SetAlpha(facts.cast.locked and (cast.Shield.alphaValue or 1) or 0)
    cast.PostCastStart(cast, frame.unit)
    cast:Show()
  else
    cast:Hide()
  end
  if ns.NameplateAuras then ns.NameplateAuras:Refresh(frame); ns.NameplateAuras:Alpha(frame, true) end
  if Enhance then Enhance.force = nil end
end

local function build(row, index, facts, enhanced)
  local unit = 'sqpreview' .. (enhanced and 'e' or '') .. index
  local data = {}
  for key, value in pairs(facts) do data[key] = value end
  data.selectedScale = tonumber(GetCVar('nameplateSelectedScale')) or 1
  data.auras = {}
  for position, source in ipairs(facts.auras or {}) do
    local copy = {}
    for key, value in pairs(source) do copy[key] = value end
    copy.start, copy.expirationTime, copy.auraInstanceID = GetTime(), GetTime() + copy.duration, position
    data.auras[position] = copy
  end
  NP.fake[unit] = data
  NP.fake[unit .. 'target'] = { name = UnitName('player'), class = select(2, UnitClass('player')) }
  local frame = CreateFrame('Frame', nil, row)
  frame:SetSize(1, 1)
  frame:SetPoint('CENTER', row, 'LEFT', (index - 0.5) * 100, 0)
  frame.unit, frame.__unit, frame.npFake = unit, unit, data
  frame.RegisterEvent, frame.EnableElement, frame.DisableElement = noop, noop, noop
  local Enhance = ns.NameplateEnhance
  if Enhance then Enhance.force = enhanced and true or false end
  ns.NameplateStyle:Build(frame)
  if Enhance then Enhance.force = nil end
  frame.Health.__owner, frame.Castbar.__owner, frame.Power.__owner = frame, frame, frame
  frame.Health.ForceUpdate = noop
  local caption = row:CreateFontString(nil, 'OVERLAY')
  caption:SetFont(STANDARD_TEXT_FONT or 'Fonts\\FRIZQT__.TTF', 7, 'OUTLINE')
  caption:SetPoint('TOP', frame, 'CENTER', 0, -24)
  caption:SetWidth(96)
  caption:SetText(facts.caption)
  return frame
end

-- Cast bars and aura timers loop; the clock exists only while a row is shown.
local function animate(row, elapsed)
  row.clock = (row.clock or 0) + elapsed
  if row.clock < 0.05 then return end
  row.clock = 0
  local now = GetTime()
  for _, frame in ipairs(row.frames) do
    local facts, cast = frame.npFake, frame.Castbar
    if facts.cast then
      local time = facts.cast.time
      local passed = (now - row.started) % (time + 0.6)
      local left = math.max(0, time - passed)
      cast:SetValue(facts.cast.channel and left or math.min(time, passed))
      cast.Time:SetFormattedText('%.1f', left)
    end
    local expired = false
    for _, record in ipairs(facts.auras) do
      if now >= record.expirationTime then record.start, record.expirationTime, expired = now, now + record.duration, true end
    end
    if expired and ns.NameplateAuras then
      local Enhance = ns.NameplateEnhance
      if Enhance then Enhance.force = row.enhanced end
      ns.NameplateAuras:Refresh(frame)
      if Enhance then Enhance.force = nil end
    end
  end
end

function Preview:Row(enhanced)
  local key = enhanced and 'enhanced' or 'classic'
  local row = self.rows[key]
  if row then return row end
  row = CreateFrame('Frame', enhanced and 'SquanchOnPlatePreviewEnhanced' or 'SquanchOnPlatePreview', UIParent)
  row:SetSize(#CASES * 100, 110)
  row:SetPoint('CENTER', UIParent, 'CENTER', 0, enhanced and 40 or 180)
  row:SetFrameStrata('MEDIUM')
  row:SetMovable(true); row:EnableMouse(true); row:RegisterForDrag('LeftButton')
  row:SetScript('OnDragStart', row.StartMoving); row:SetScript('OnDragStop', row.StopMovingOrSizing)
  row.title = row:CreateFontString(nil, 'OVERLAY')
  row.title:SetFont(STANDARD_TEXT_FONT or 'Fonts\\FRIZQT__.TTF', 9, 'OUTLINE')
  row.title:SetPoint('BOTTOMLEFT', row, 'TOPLEFT', 0, 2)
  row.title:SetText(enhanced and 'Squanch-On preview plates: enhancements on (drag to move)' or 'Squanch-On preview plates: classic look (drag to move)')
  row.enhanced, row.frames, row.started = enhanced and true or false, {}, GetTime()
  for index, facts in ipairs(CASES) do row.frames[index] = build(row, index, facts, enhanced) end
  row:SetScript('OnUpdate', animate)
  row:Hide()
  self.rows[key] = row
  return row
end
-- Repaints shown rows (also after a settings edit).
function Preview:Refresh()
  for _, row in pairs(self.rows) do
    if row:IsShown() then
      for _, frame in ipairs(row.frames) do paint(frame, row.enhanced) end
    end
  end
end
function Preview:Show(enhanced, shown)
  if not ns.NameplateStyle or not ns.db then return false end
  local key = enhanced and 'enhanced' or 'classic'
  if shown == nil then shown = not (self.rows[key] and self.rows[key]:IsShown()) end
  if not shown and not self.rows[key] then return false end
  local row = self:Row(enhanced)
  row:SetShown(shown)
  if shown then row.started = GetTime(); self:Refresh() end
  return shown
end

SLASH_SQUANCHONPLATES1 = '/sqplates'
SlashCmdList.SQUANCHONPLATES = function(message)
  local word, option = (message or ''):lower():match('^%s*(%S*)%s*(%S*)')
  if word ~= 'test' then print('/sqplates test [on|off]   preview plates   |   /sqplates test enh   the same row with enhancements'); return end
  local enhanced = option == 'enh'
  local wanted = nil
  if option == 'on' then wanted = true elseif option == 'off' then wanted = false end
  local shown = Preview:Show(enhanced, wanted)
  if option == 'off' and Preview.rows.enhanced then Preview.rows.enhanced:Hide() end
  print('Squanch-On preview plates' .. (enhanced and ' (enhancements)' or '') .. ': ' .. (shown and 'shown' or 'hidden'))
end
