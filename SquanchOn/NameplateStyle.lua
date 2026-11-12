-- SPDX-License-Identifier: MIT
-- Squanch-On nameplates: frame construction, layout and policy
-- (ns.NameplateStyle). Original implementation; no Plater code or art. The
-- rules reproduce what the author's Plater profile did: which kinds draw a
-- bar, the colour order (tapped, threat while the player fights, quest, the
-- client's selection colour), text formats and target artwork.
--
-- Health, power and names can be secret values on this client. They are only
-- handed to widgets that accept them (StatusBar:SetValue through oUF's Health
-- and Power elements, FontString:SetText / SetFormattedText) and are never
-- compared or used in arithmetic; every branch below tests a public value.
local _, ns = ...
local NP = ns.Nameplates
if not NP then return end
local Style = {}
ns.NameplateStyle = Style
local public, ask = NP.Public, NP.Ask
local unpack = unpack or table.unpack
-- Unit facts come through NP.Unit so preview plates can state their own.
local UnitName, UnitIsUnit, UnitIsPlayer, UnitCanAttack, UnitIsFriend = NP.Unit('UnitName'), NP.Unit('UnitIsUnit'), NP.Unit('UnitIsPlayer'), NP.Unit('UnitCanAttack'), NP.Unit('UnitIsFriend')
local UnitReaction, UnitClassification, UnitPlayerControlled, UnitFactionGroup = NP.Unit('UnitReaction'), NP.Unit('UnitClassification'), NP.Unit('UnitPlayerControlled'), NP.Unit('UnitFactionGroup')
local UnitClass, UnitLevel, UnitIsTapDenied, UnitThreatSituation = NP.Unit('UnitClass'), NP.Unit('UnitLevel'), NP.Unit('UnitIsTapDenied'), NP.Unit('UnitThreatSituation')
local UnitAffectingCombat, UnitGUID, UnitIsInMyGuild, GetGuildInfo = NP.Unit('UnitAffectingCombat'), NP.Unit('UnitGUID'), NP.Unit('UnitIsInMyGuild'), NP.Unit('GetGuildInfo')
local UnitHealthPercent, UnitPowerPercent, UnitSelectionColor = NP.Unit('UnitHealthPercent'), NP.Unit('UnitPowerPercent'), NP.Unit('UnitSelectionColor')
local UnitEffectiveLevel, UnitPowerType = NP.Unit('UnitEffectiveLevel'), NP.Unit('UnitPowerType')
local FACTION = { Horde = 'Interface\\PVPFrame\\PVP-Currency-Horde', Alliance = 'Interface\\PVPFrame\\PVP-Currency-Alliance' }
local SIDES = { LEFT = { 'RIGHT', 'LEFT' }, INNERLEFT = { 'LEFT', 'LEFT' }, CENTER = { 'CENTER', 'CENTER' },
  INNERRIGHT = { 'RIGHT', 'RIGHT' }, RIGHT = { 'LEFT', 'RIGHT' } }

local function rgb(color, fallback)
  if type(color) ~= 'table' then color = fallback end
  return color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1
end
local function texture(name)
  return ns.Media and ns.Media:Resolve('statusbar', name) or 'Interface\\TargetingFrame\\UI-StatusBar'
end
local function classRGB(unit)
  local ok, _, token = pcall(UnitClass, unit)
  if not ok then return end
  if public(token) then
    local color = token and (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[token] or RAID_CLASS_COLORS and RAID_CLASS_COLORS[token])
    if color then return color.r, color.g, color.b end
  elseif C_ClassColor and C_ClassColor.GetClassColor then
    local good, color = pcall(C_ClassColor.GetClassColor, token)
    if good and color and color.GetRGB then return color:GetRGB() end
  end
end
local function pixel(frame)
  local scale = ask(frame.GetEffectiveScale, frame)
  local factor = PixelUtil and PixelUtil.GetPixelToUIUnitFactor and PixelUtil.GetPixelToUIUnitFactor() or 1
  return scale and scale > 0 and factor / scale or 1
end

-- Classification --------------------------------------------------------------
-- enemynpc, friendlynpc, enemyplayer, friendlyplayer or self. A unit whose
-- facts are hidden is drawn as an enemy NPC (bar and name, reaction colour).
function Style:Kind(unit)
  if ask(UnitIsUnit, unit, 'player') == true then return 'self' end
  local attackable = ask(UnitCanAttack, 'player', unit)
  if ask(UnitIsPlayer, unit) == true then return attackable and 'enemyplayer' or 'friendlyplayer' end
  if attackable then return 'enemynpc' end
  local reaction = ask(UnitReaction, unit, 'player')
  if type(reaction) == 'number' and reaction >= 5 then return 'friendlynpc' end
  if attackable == false and ask(UnitIsFriend, 'player', unit) == true then return 'friendlynpc' end
  return 'enemynpc'
end
function Style:Classify(frame, unit)
  unit = unit or frame.unit
  local kind = self:Kind(unit)
  frame.npKind = kind
  local class = ask(UnitClassification, unit)
  frame.npRare, frame.npRareElite = class == 'rare' or class == 'rareelite', class == 'rareelite'
  frame.npSize = (class == 'minus' or ns.NameplateEnhance and ns.NameplateEnhance:Trivial(unit)) and 'minor'
    or (kind == 'enemynpc' or kind == 'friendlynpc') and ask(UnitPlayerControlled, unit) == true and 'pet' or nil
  frame.npFaction = (kind == 'enemyplayer' or kind == 'friendlyplayer') and ask(UnitFactionGroup, unit) or nil
  frame.npAttackable = ask(UnitCanAttack, 'player', unit)
  frame.npReaction = ask(UnitReaction, unit, 'player')
  frame.npQuest = (kind == 'enemynpc' or kind == 'friendlynpc') and self:Quest(unit) or false
  frame.npNoCombat, frame.npAggro = nil, nil
  frame:SetShown(kind ~= 'self')
  local config = NP:Settings().types[kind]
  -- Elements follow the plate's kind; oUF ignores a repeated enable or disable.
  if frame.EnableElement then
    if config and config.power then frame:EnableElement('Power') else frame:DisableElement('Power') end
    if config and config.showCast and frame.Castbar then frame:EnableElement('Castbar')
    elseif frame.Castbar then frame:DisableElement('Castbar') end
  end
end

-- Whether this plate draws its bar. Names-only kinds get it back when the
-- selected player belongs to the configured faction; an enemy NPC the player
-- cannot attack shows its name only.
local function barShown(frame, settings, config)
  if frame.npKind == 'enemynpc' and frame.npAttackable == false then return false end
  if config.mode ~= 'nameOnly' then return true end
  return NP:IsTarget(frame) and settings.barWhenTargetedFaction ~= 'NONE'
    and frame.npFaction == settings.barWhenTargetedFaction
end

-- Quest units ------------------------------------------------------------------
-- A unit counts while its tooltip lists one of the player's quests with an
-- unfinished objective (or no countable objective at all).
local questTitles, questDirty = {}, true
local function titles()
  if not questDirty then return questTitles end
  questDirty = false
  for key in pairs(questTitles) do questTitles[key] = nil end
  local log = C_QuestLog
  local count = log and log.GetNumQuestLogEntries and ask(log.GetNumQuestLogEntries) or 0
  for index = 1, type(count) == 'number' and count or 0 do
    local info = log.GetInfo and ask(log.GetInfo, index)
    local title = type(info) == 'table' and not info.isHeader and info.title
    if not info and GetQuestLogTitle then
      local name, _, _, header = GetQuestLogTitle(index)
      title = not header and name
    end
    if public(title) and type(title) == 'string' then questTitles[title] = true end
  end
  return questTitles
end
function Style:Quest(unit)
  if NP.fake[unit] then return NP.fake[unit].quest or false end
  local colors = NP:Settings().colors
  if not colors.quest or not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) then return false end
  if IsInInstance and ask(IsInInstance) == true then return false end
  local guid = ask(UnitGUID, unit)
  if type(guid) ~= 'string' then return false end
  local ok, data = pcall(C_TooltipInfo.GetHyperlink, 'unit:' .. guid)
  if not ok or type(data) ~= 'table' or type(data.lines) ~= 'table' then return false end
  local known, listed, counted = titles(), false, false
  for _, line in ipairs(data.lines) do
    local text = line.leftText
    if not public(text) then return false end
    if type(text) == 'string' then
      if known[text] then
        listed = true
      elseif listed then
        local have, need = text:match('(%d+)/(%d+)')
        local percent = not have and text:match('(%d+)%%')
        if have then
          counted = true
          if tonumber(have) < tonumber(need) then return true end
        elseif percent then
          counted = true
          if tonumber(percent) < 100 then return true end
        end
      end
    end
  end
  return listed and not counted
end
local questQueued
function Style:QuestsChanged()
  questDirty = true
  if questQueued then return end
  questQueued = true
  C_Timer.After(0.5, function()
    questQueued = nil
    for frame in pairs(NP.active) do
      local kind = frame.npKind
      if kind == 'enemynpc' or kind == 'friendlynpc' then
        local quest = Style:Quest(frame.unit)
        if quest ~= frame.npQuest then frame.npQuest = quest; Style:Color(frame); Style:Indicators(frame) end
      end
    end
  end)
end

-- Colour ----------------------------------------------------------------------
-- The bar colour outside the threat rules: class for players, tapped, quest,
-- then the client's own selection colour (configured reaction colours when
-- the client gives none).
-- In dungeons, raids and scenarios an enemy NPC is coloured by what it is:
-- boss (two levels up, or a skull), miniboss (a level up), caster (uses mana).
local function typeColor(frame, unit, colors)
  if not colors.unitType or frame.npKind ~= 'enemynpc' then return end
  local zone = NP:Zone(frame)
  if zone ~= 'party' and zone ~= 'raid' and zone ~= 'scenario' then return end
  local mine = frame.npFake and (frame.npFake.playerLevel or 10) or ask(UnitEffectiveLevel, 'player') or ask(UnitLevel, 'player')
  local theirs = ask(UnitEffectiveLevel, unit) or ask(UnitLevel, unit)
  if type(mine) == 'number' and type(theirs) == 'number' then
    if theirs == mine + 2 or theirs == -1 then return colors.boss, 'boss' end
    if theirs >= mine + 1 then return colors.miniboss, 'miniboss' end
  end
  local class = not frame.npFake and UnitClassBase and ask(UnitClassBase, unit)
  if class == 'PALADIN' or ask(UnitPowerType, unit) == 0 then return colors.caster, 'caster' end
end
-- Always leaves the bar coloured; frame.npColorSource names the rule (/sqplates debug).
local function baseColor(frame, unit, colors)
  local kind, bar = frame.npKind, frame.Health
  if kind == 'enemyplayer' or kind == 'friendlyplayer' then
    local r, g, b = classRGB(unit)
    if r then bar:SetStatusBarColor(r, g, b); frame.npColorSource = 'class'; return end
  elseif ask(UnitIsTapDenied, unit) == true then
    bar:SetStatusBarColor(rgb(colors.tapped)); frame.npColorSource = 'tapped'; return
  elseif frame.npQuest then
    local reaction = frame.npReaction
    local color = kind == 'friendlynpc' and colors.questFriendly or reaction == 4 and colors.questNeutral or colors.questHostile
    bar:SetStatusBarColor(rgb(color)); frame.npColorSource = 'quest'; return
  else
    local color, source = typeColor(frame, unit, colors)
    if color then bar:SetStatusBarColor(rgb(color)); frame.npColorSource = source; return end
  end
  local ok, r, g, b = pcall(UnitSelectionColor, unit)
  if ok and not (public(r) and r == nil) and pcall(bar.SetStatusBarColor, bar, r, g, b) then frame.npColorSource = 'selection'; return end
  local reaction = frame.npReaction
  local color
  if type(reaction) == 'number' then color = reaction >= 5 and colors.friendly or reaction == 4 and colors.neutral or colors.hostile
  else color = (kind == 'friendlynpc' or kind == 'friendlyplayer') and colors.friendly or colors.hostile end
  bar:SetStatusBarColor(rgb(color)); frame.npColorSource = 'reaction'
end
-- The flash when a unit turns on the player (not for tanks): a white wash over
-- the bar, in and out, with "-AGGRO-". Built on first use.
function Style:Flash(frame)
  local settings = NP:Settings().target.aggroFlash
  local flash = frame.npFlash
  if not flash then
    local health = frame.Health
    flash = CreateFrame('Frame', nil, health)
    flash:SetFrameLevel(health:GetFrameLevel() + 3)
    flash:SetAllPoints(health)
    flash.art = flash:CreateTexture(nil, 'ARTWORK')
    flash.art:SetAllPoints(flash)
    flash.art:SetBlendMode('ADD')
    flash.text = flash:CreateFontString(nil, 'OVERLAY')
    flash.text:SetPoint('CENTER', flash, 'CENTER', 0, 0)
    flash.text:SetTextColor(0.7, 0.7, 0.7)
    local group = flash.art.CreateAnimationGroup and flash.art:CreateAnimationGroup()
    local rise = group and group.CreateAnimation and group:CreateAnimation('Alpha')
    local fall = rise and group:CreateAnimation('Alpha')
    if fall and rise.SetFromAlpha and rise.SetOrder then
      rise:SetOrder(1); rise:SetFromAlpha(0); rise:SetToAlpha(1)
      fall:SetOrder(2); fall:SetFromAlpha(1); fall:SetToAlpha(0)
      group:SetScript('OnFinished', function() flash:Hide() end)
      flash.group, flash.rise, flash.fall = group, rise, fall
    end
    frame.npFlash = flash
  end
  local duration = math.max(0.05, tonumber(settings.duration) or 0.2)
  flash.art:SetColorTexture(rgb(settings.color))
  NP:Font(flash.text, STANDARD_TEXT_FONT or 'Fonts\\FRIZQT__.TTF', 12, 'NONE')
  flash.text:SetText(settings.text and '-AGGRO-' or '')
  flash:Show()
  if flash.group then
    flash.group:Stop()
    flash.rise:SetDuration(duration); flash.fall:SetDuration(duration)
    flash.group:Play()
  else
    C_Timer.After(duration * 2, function() flash:Hide() end)
  end
end
local function aggro(frame, unit, settings)
  local has = ask(UnitThreatSituation, 'player', unit) == 3
  local flash = settings.target.aggroFlash
  if has and frame.npAggro == false and flash.enabled and settings.colors.role ~= 'tank' and frame.Health:IsShown() then
    local zone = NP:Zone(frame)
    -- Not in the first five seconds of a fight, when everything turns at once.
    if (not flash.instanceOnly or zone == 'party' or zone == 'raid') and GetTime() >= (NP.combatSince or 0) + 5 then
      Style:Flash(frame)
    end
  end
  frame.npAggro = has
end
-- Threat applies to enemy NPCs and only while the player is in combat. Sets
-- frame.npNoCombat for a unit that is outside the fight (dimmed by the alpha
-- pass) and shows the warning glow when the player is about to take or lose it.
local function threatColor(frame, unit, colors, settings)
  local glow = false
  frame.npNoCombat = nil
  local ok, status = pcall(UnitThreatSituation, 'player', unit)
  if not ok or not public(status) then return nil, glow end
  local tank = colors.role == 'tank'
  local color
  if type(status) == 'number' and status >= 2 then
    if tank then
      color = status == 3 and colors.tankAggro or colors.tankPulling
      glow = status == 2
    else
      color = colors.dpsAggro
    end
  elseif status == nil or tank then
    if ask(UnitAffectingCombat, unit) == true then
      color = tank and colors.tankNoAggro or colors.dpsNoAggro
    elseif not frame.npQuest then
      -- Not fighting anyone: neutral units keep their colour, both are dimmed.
      if frame.npReaction ~= 4 then color = colors.noCombat end
      if settings.alpha.notInCombatEnabled then frame.npNoCombat = true end
    end
  elseif status == 1 then
    color, glow = colors.dpsPulling, true
  else
    color = colors.dpsNoAggro
  end
  return color, glow
end
-- Also oUF's colour pass (it calls frame, event, unit).
local function updateColor(frame)
  local unit = frame.unit
  if not unit then return end
  local settings = NP:Settings()
  local colors = settings.colors
  local color, glow = nil, false
  local wasDimmed = frame.npNoCombat
  frame.npNoCombat = nil
  if NP:Fighting(frame) and colors.threat and frame.npKind == 'enemynpc' and frame.npAttackable ~= false
    and ask(UnitIsTapDenied, unit) ~= true then
    local enhance = ns.NameplateEnhance
    color = enhance and enhance:Threat(frame, unit) or nil
    if not color then color, glow = threatColor(frame, unit, colors, settings) end
    aggro(frame, unit, settings)
  else
    frame.npAggro = nil
  end
  if color then frame.Health:SetStatusBarColor(rgb(color)); frame.npColorSource = 'threat' else baseColor(frame, unit, colors) end
  glow = glow and settings.target.aggroGlow and frame.Health:IsShown() or false
  frame.GlowUpper:SetShown(glow); frame.GlowLower:SetShown(glow)
  if wasDimmed ~= frame.npNoCombat and ns.NameplateAuras then ns.NameplateAuras:Alpha(frame, true) end
end
function Style:Color(frame) updateColor(frame) end

-- Texts -----------------------------------------------------------------------
local function percentText(element, unit, current, maximum)
  local text = element.__owner.Percent
  if not text:IsShown() then return end
  do
    local scale = CurveConstants and CurveConstants.ScaleTo100
    local ok, value = pcall(UnitHealthPercent, unit, true, scale)
    -- A secret percentage is formatted by the client; no "%" sign (owner).
    if ok and pcall(text.SetFormattedText, text, '%d', value) then return end
  end
  if public(current) and public(maximum) and type(current) == 'number' and type(maximum) == 'number' and maximum > 0 then
    text:SetFormattedText('%d', math.floor(current / maximum * 100))
  else
    text:SetText('')
  end
end
local function nameColor(frame, unit, colors, config)
  local kind = frame.npKind
  if kind == 'friendlyplayer' and colors.friendColors then
    if ask(UnitIsInMyGuild, unit) == true then return rgb(colors.guild) end
    local guid = ask(UnitGUID, unit)
    if guid and C_FriendList and C_FriendList.IsFriend and ask(C_FriendList.IsFriend, guid) == true then return rgb(colors.friend) end
  end
  if config.name.classColor and (kind == 'enemyplayer' or kind == 'friendlyplayer') then
    local r, g, b = classRGB(unit)
    if r then return r, g, b end
  end
  if kind == 'enemynpc' and frame.npAttackable == false then
    local ok, r, g, b = pcall(UnitSelectionColor, unit)
    if ok and public(r) and r then return r, g, b end
    return 1, 1, 0
  end
  return rgb(colors.name)
end
-- Cyrillic to Latin, letter by letter (two-byte UTF-8 sequences).
local LATIN = {}
do
  local lower = { 'a', 'b', 'v', 'g', 'd', 'e', 'zh', 'z', 'i', 'y', 'k', 'l', 'm', 'n', 'o', 'p', 'r', 's', 't', 'u', 'f', 'kh', 'ts',
    'ch', 'sh', 'shch', '', 'y', '', 'e', 'yu', 'ya' }
  for index, latin in ipairs(lower) do
    -- U+0430.. (lower case) and U+0410.. (upper case)
    local code = 0x430 + index - 1
    LATIN[string.char(0xC0 + math.floor(code / 64), 0x80 + code % 64)] = latin
    code = 0x410 + index - 1
    LATIN[string.char(0xC0 + math.floor(code / 64), 0x80 + code % 64)] = latin:sub(1, 1):upper() .. latin:sub(2)
  end
  LATIN['\209\145'], LATIN['\208\129'] = 'yo', 'Yo'
end
local function latin(name)
  if not name:find('[\208\209]') then return name end
  return (name:gsub('[\208\209][\128-\191]', LATIN))
end
-- An NPC's profession or title: the second tooltip line unless that is its level.
local function title(frame, unit)
  if frame.npFake then return frame.npFake.title end
  if not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) then return end
  local guid = ask(UnitGUID, unit)
  if type(guid) ~= 'string' then return end
  local ok, data = pcall(C_TooltipInfo.GetHyperlink, 'unit:' .. guid)
  local line = ok and type(data) == 'table' and type(data.lines) == 'table' and data.lines[2 + (tonumber(ask(GetCVar, 'colorblindMode')) or 0)]
  local text = type(line) == 'table' and line.leftText
  if not public(text) or type(text) ~= 'string' or text == '' then return end
  local level = type(UNIT_LEVEL_TEMPLATE) == 'string' and (UNIT_LEVEL_TEMPLATE:lower():gsub('%%d', '.*')) or 'level .*'
  local fine, found = pcall(string.match, text:lower(), level)
  if not fine or found then return end
  return text
end
local function updateName(frame)
  local unit, settings = frame.unit, NP:Settings()
  local config = unit and settings.types[frame.npKind]
  if not config then return end
  local kind = frame.npKind
  local ok, name = pcall(UnitName, unit)
  -- UnitName gives a character's first name only on this client; the client's
  -- own GetUnitName carries the surname as shown in the world.
  if ok and type(unit) == 'string' and (kind == 'enemyplayer' or kind == 'friendlyplayer') and GetUnitName then
    local fine, full = pcall(GetUnitName, unit, false)
    if fine and full ~= nil and (not public(full) or full ~= '') then name = full end
  end
  if ok then
    if settings.translit and public(name) and type(name) == 'string' then name = latin(name) end
    -- Players carry their guild on a second line, as "<Guild>".
    local guild = config.guild and (kind == 'enemyplayer' or kind == 'friendlyplayer') and ask(GetGuildInfo, unit)
    if public(name) and type(name) == 'string' and type(guild) == 'string' and guild ~= '' then
      frame.Name:SetText(name .. '\n<' .. guild .. '>')
    else
      frame.Name:SetText(name)
    end
  end
  local r, g, b = nameColor(frame, unit, settings.colors, config)
  frame.Name:SetTextColor(r, g, b)
  -- A name-only NPC carries its title underneath, in the name's colour.
  local line = settings.subtitle.show and (kind == 'enemynpc' or kind == 'friendlynpc') and not frame.Health:IsShown() and title(frame, unit)
  frame.npTitle = line and true or false
  if line then
    frame.Subtitle:SetText('<' .. line .. '>')
    frame.Subtitle:SetTextColor(r, g, b)
  end
  frame.Subtitle:SetShown(frame.npTitle and frame.Name:IsShown())
end
local function updateLevel(frame)
  local unit = frame.unit
  if not unit or not frame.Level:IsShown() then return end
  local ok, level = pcall(UnitLevel, unit)
  if not ok then return end
  if public(level) and type(level) == 'number' then
    frame.Level:SetText(level > 0 and level or '??')
    local color = level > 0 and GetCreatureDifficultyColor and GetCreatureDifficultyColor(level)
    if color then frame.Level:SetTextColor(color.r, color.g, color.b) else frame.Level:SetTextColor(1, 0.1, 0.1) end
  else
    frame.Level:SetText(level); frame.Level:SetTextColor(1, 1, 1)
  end
end
-- The unit's own target, class coloured (the "target name on plate" label).
local function updateLabel(frame)
  local label, unit = frame.TargetName, frame.unit
  if not unit or not label:IsShown() then return end
  local target = unit .. 'target'
  local ok, name = pcall(UnitName, target)
  if not ok then label:SetText(''); return end
  label:SetText(name)
  local r, g, b = classRGB(target)
  label:SetTextColor(r or 1, g or 1, b or 1)
end
local function updateIndicators(frame)
  local settings = NP:Settings()
  local indicators, kind = settings.indicators, frame.npKind
  local config = settings.types[kind]
  local bar = config and barShown(frame, settings, config)
  -- A hovered friendly player carries the emblem without the bar (NameplateHoverRing.lua).
  local art = (bar or frame.npHoverRing) and frame.npFaction and FACTION[frame.npFaction]
  local wanted = art and (kind == 'friendlyplayer' and indicators.friendlyFaction or kind == 'enemyplayer' and indicators.enemyFaction)
  if wanted and kind == 'enemyplayer' and IsInInstance then
    -- No enemy emblem in battlegrounds and arenas.
    local ok, _, where = pcall(IsInInstance)
    if ok and (where == 'pvp' or where == 'arena') then wanted = false end
  end
  local emblem = frame.Faction
  if wanted then
    emblem:SetTexture(art)
    -- The allied emblem stays solid while the bar fades with range or selection.
    local solid = kind == 'friendlyplayer'
    emblem:SetIgnoreParentAlpha(solid)
    emblem:SetAlpha(1)
  end
  emblem:SetShown(wanted and true or false)
  local rare = indicators.rare and frame.npRare and bar and not wanted and true or false
  -- A rare elite carries a gold star before the grey one; a friendly NPC that
  -- is an objective of one of the player's quests carries the quest badge.
  -- The first icon takes the anchor, the next ones follow to its right.
  local previous
  for _, entry in ipairs({ { emblem, wanted }, { frame.Elite, rare and frame.npRareElite }, { frame.Rare, rare },
    { frame.QuestIcon, indicators.quest and kind == 'friendlynpc' and frame.npQuest and bar } }) do
    local icon, shown = entry[1], entry[2] and true or false
    icon:SetShown(shown)
    if shown then
      icon:ClearAllPoints()
      if previous then icon:SetPoint('LEFT', previous, 'RIGHT', 1.5, 0)
      else
        icon:SetPoint('BOTTOM', frame.Health, 'TOP', indicators.x or 0, indicators.y or 0)
        -- Where the first icon's centre sits above the bar's centre (for the target ring).
        frame.npIconRise = (frame.npBarHeight or 0) / 2 + (indicators.y or 0) + (indicators.size or 0) / 2
        frame.npIconSize = indicators.size
      end
      previous = icon
    end
  end
end
function Style:Indicators(frame) updateIndicators(frame) end

function Style:SetHover(frame, shown)
  -- The selected plate shows mouseover on its target ring instead of its bar.
  local ring = ns.TargetCrosshairs
  local selected = NP.targetFrame == frame and ring and ring.SetHovered and ring.barLookActive
  if ring and ring.SetHovered then ring:SetHovered(frame, shown and selected and true or false) end
  frame.Hover:SetShown(shown and not selected and frame.Health:IsShown() or false)
  if ns.NameplateHoverRing then ns.NameplateHoverRing:Set(frame, shown) end
end

-- Layout ----------------------------------------------------------------------
local function place(text, spec, bar)
  NP:Font(text, spec.font, spec.size, spec.outline)
  local side = SIDES[spec.side] or SIDES.CENTER
  text:ClearAllPoints()
  text:SetPoint(side[1], bar, side[2], spec.x or 0, spec.y or 0)
  text:SetShown(spec.show ~= false)
end
function Style:Layout(frame)
  local settings = NP:Settings()
  local config = settings.types[frame.npKind]
  if not config then return end
  local health = frame.Health
  local size = NP:Fighting(frame) and config.healthCombat or config.health
  local factor = frame.npSize and settings.sizeScale[frame.npSize]
  local width, height = size[1] * (factor and factor[1] or 1), size[2] * (factor and factor[2] or 1)
  -- Sizes are UIParent units, as they were with Plater; a real plate hangs
  -- under WorldFrame, so it takes UIParent's scale explicitly. The client
  -- scales the selected plate itself (nameplateSelectedScale).
  frame.npBase = (tonumber(settings.scale) or 1) * (frame.npFake and (frame.npFake.target and frame.npFake.selectedScale or 1)
    or UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1)
  if not frame.npScaleGroup then frame:SetScale(frame.npBase) end
  health:SetSize(width, height)
  -- Recorded for the target ring: nameplate regions cannot be measured.
  frame.npBarWidth, frame.npBarHeight = width, height
  health:SetStatusBarTexture(texture(settings.health.texture))
  health.bg:SetColorTexture(rgb(settings.health.background))
  local bar = barShown(frame, settings, config)
  health:SetShown(bar)

  -- Rim inside the bar, never thicker than leaves a visible fill.
  local unit = pixel(health)
  local lines = math.max(0, math.min(tonumber(settings.border.thickness) or 0, math.floor((height / unit - 1) / 2)))
  local r, g, b, a = rgb(settings.border.color)
  if settings.border.theme and ns.DarkSkin and ns.DarkSkin.lineColor then r, g, b = unpack(ns.DarkSkin.lineColor) end
  for index, rim in ipairs(health.rim) do
    rim:SetShown(lines > 0)
    rim:SetColorTexture(r, g, b, a)
    if index < 3 then rim:SetHeight(lines * unit) else rim:SetWidth(lines * unit) end
  end

  local nameFont = frame.npKind == 'enemynpc' and not bar and settings.bigName or config.name
  place(frame.Name, { font = nameFont.font, size = nameFont.size, outline = nameFont.outline }, health)
  frame.Name:ClearAllPoints()
  -- Without a bar the name sits ten units above the plate's centre; under the
  -- mouseover ring it keeps the place it has above a bar, clear of the emblem.
  if bar or frame.npHoverRing then frame.Name:SetPoint('BOTTOM', health, 'TOP', 0, config.name.y or 0)
  else frame.Name:SetPoint('CENTER', frame, 'CENTER', 0, 10) end
  place(frame.Level, config.level, health)
  place(frame.Percent, config.percent, health)
  frame.Percent:SetAlpha(config.percent.alpha or 1)
  if not bar then frame.Level:Hide(); frame.Percent:Hide() end
  local sub = settings.subtitle
  NP:Font(frame.Subtitle, sub.font, sub.size, sub.outline)
  frame.Subtitle:ClearAllPoints()
  frame.Subtitle:SetPoint('TOP', frame.Name, 'BOTTOM', 0, -2)
  local label = settings.target.label
  NP:Font(frame.TargetName, label.font, label.size, label.outline)
  frame.TargetName:ClearAllPoints()
  frame.TargetName:SetPoint('TOPRIGHT', health, 'BOTTOMRIGHT', label.x or 0, label.y or 0)
  frame.TargetName:SetAlpha(label.alpha or 1)
  frame.TargetName:SetShown(label.show and bar and frame.npKind ~= 'friendlyplayer' or false)

  local indicators = settings.indicators
  for _, icon in ipairs({ frame.Faction, frame.Rare, frame.Elite }) do icon:SetSize(indicators.size, indicators.size) end
  frame.QuestIcon:SetSize(indicators.size * 5 / 6, indicators.size * 5 / 6)
  -- Shown only while the unit carries a mark: the element decides, never the
  -- layout (an unmarked icon shows the whole sheet of eight marks).
  do
    local mark = frame.RaidTargetIndicator
    mark:Hide()
    if indicators.raidMark and frame.unit then
      local ok, index = pcall(GetRaidTargetIndex, frame.unit)
      if ok and index ~= nil then
        if pcall(SetRaidTargetIconTexture, mark, index) then mark:Show() end
      end
    end
  end
  frame.RaidTargetIndicator:SetSize(indicators.size, indicators.size)

  local power = frame.Power
  power:ClearAllPoints()
  power:SetPoint('BOTTOMLEFT', health, 'BOTTOMLEFT', 0, settings.power.y or 0)
  power:SetPoint('BOTTOMRIGHT', health, 'BOTTOMRIGHT', 0, settings.power.y or 0)
  power:SetHeight(settings.power.height or 1.5)
  power:SetStatusBarTexture(texture(settings.health.texture))
  power:SetShown(config.power and bar and true or false)
  NP:Font(power.Text, settings.power.textFont, settings.power.textSize, 'OUTLINE')
  power.Text:SetShown(settings.power.text and true or false)

  local target = NP:IsTarget(frame) and bar
  -- Highlight strips above and below the bar: attackable enemies only.
  local enemy = (frame.npKind == 'enemynpc' or frame.npKind == 'enemyplayer') and frame.npAttackable ~= false
  local hr, hg, hb, ha = rgb(settings.target.highlight)
  for index, strip in ipairs(frame.Highlight) do
    strip:SetShown(target and enemy)
    strip:SetHeight(settings.target.highlightHeight or 11)
    -- Solid at the bar, fading away from it.
    local near, far = CreateColor and CreateColor(hr, hg, hb, ha), CreateColor and CreateColor(hr, hg, hb, 0)
    if not (near and strip.SetGradient and pcall(strip.SetGradient, strip, 'VERTICAL', index == 1 and near or far, index == 1 and far or near)) then
      strip:SetColorTexture(hr, hg, hb, ha)
    end
  end
  -- Two mirrored ornaments at the bar ends, scaled with the bar; none on a
  -- bar thinner than four units.
  local ornament = target and settings.target.ornament and height >= 4
  local scale = height / 12
  local orr, org, orb, ora = rgb(settings.target.ornamentColor)
  for _, side in ipairs(frame.Ornament) do
    side:SetShown(ornament)
    side:SetSize(8 * scale, 12 * scale * 1.2)
    side:SetVertexColor(orr, org, orb)
    side:SetAlpha(ora)
  end
  health.overlay:SetShown(target and (settings.target.overlayAlpha or 0) > 0)
  health.overlay:SetAlpha(settings.target.overlayAlpha or 0)
  frame.Hover:SetAlpha(settings.target.hoverAlpha or 0.5)
  if not bar then frame.Hover:Hide() end

  if ns.NameplateCast then ns.NameplateCast:Layout(frame, config, width, height) end
  if ns.NameplateAuras then ns.NameplateAuras:Layout(frame, config) end
  if ns.NameplateEnhance then ns.NameplateEnhance:Apply(frame, width, height) end
end

-- Everything that follows the unit rather than the layout.
function Style:Refresh(frame)
  if not frame.unit then return end
  updateName(frame); updateLevel(frame); updateLabel(frame); updateIndicators(frame)
  updateColor(frame)
  if frame.Health.ForceUpdate and frame.Health:IsShown() then frame.Health:ForceUpdate() end
end

-- Construction ------------------------------------------------------------------
local function fontString(parent)
  local text = parent:CreateFontString(nil, 'OVERLAY')
  text:SetFont(STANDARD_TEXT_FONT or 'Fonts\\FRIZQT__.TTF', 8, 'OUTLINE')
  text:SetWordWrap(false)
  return text
end
local handlers = {
  UNIT_NAME_UPDATE = updateName,
  UNIT_LEVEL = updateLevel,
  UNIT_TARGET = updateLabel,
  UNIT_THREAT_SITUATION_UPDATE = updateColor,
  UNIT_THREAT_LIST_UPDATE = updateColor,
  UNIT_FLAGS = updateColor,
  UNIT_CLASSIFICATION_CHANGED = function(frame)
    if not frame.unit then return end -- a plate off screen still hears its old token
    Style:Classify(frame, frame.unit); Style:Layout(frame); Style:Refresh(frame)
  end,
  -- A duel, a faction flag or mind control turns one kind of plate into another.
  UNIT_FACTION = function(frame)
    if not frame.unit then return end
    local before = frame.npKind
    Style:Classify(frame, frame.unit)
    if frame.npKind ~= before then Style:Layout(frame) end
    Style:Refresh(frame)
  end,
}
function Style:Build(frame)
  local settings = NP:Settings()
  frame:SetFrameStrata('BACKGROUND')
  -- World markers (the target ring, level 1-3 of the same strata) stay behind
  -- every part of a plate, whatever level the client gives the plate's base.
  if frame.SetFixedFrameLevel then frame:SetFixedFrameLevel(true) end
  frame:SetFrameLevel(20)

  local health = CreateFrame('StatusBar', nil, frame)
  health:SetPoint('CENTER', frame, 'CENTER', 0, 0)
  health:SetStatusBarTexture(texture(settings.health.texture))
  health.bg = health:CreateTexture(nil, 'BACKGROUND')
  health.bg:SetAllPoints(health)
  health.rim = {}
  for index, points in ipairs({ { 'TOPLEFT', 'TOPRIGHT' }, { 'BOTTOMLEFT', 'BOTTOMRIGHT' }, { 'TOPLEFT', 'BOTTOMLEFT' }, { 'TOPRIGHT', 'BOTTOMRIGHT' } }) do
    local rim = health:CreateTexture(nil, 'OVERLAY')
    rim:SetPoint(points[1], health, points[1], 0, 0)
    rim:SetPoint(points[2], health, points[2], 0, 0)
    health.rim[index] = rim
  end
  health.overlay = health:CreateTexture(nil, 'ARTWORK', nil, 2)
  health.overlay:SetAllPoints(health)
  health.overlay:SetTexture(texture('Squanch Gloss'))
  health.overlay:SetBlendMode('ADD')
  health.overlay:Hide()
  -- These flags only make oUF listen for the events the colour pass needs.
  health.colorTapping, health.colorReaction, health.colorThreat = true, true, true
  health.UpdateColor = updateColor
  health.PostUpdate = percentText
  frame.Health, frame.healthBar = health, health -- healthBar: the ring and icon anchors

  local hover = health:CreateTexture(nil, 'OVERLAY', nil, 1)
  hover:SetAllPoints(health); hover:SetColorTexture(1, 1, 1, 1); hover:SetBlendMode('ADD'); hover:Hide()
  frame.Hover = hover
  frame.Highlight, frame.Ornament = {}, {}
  for index = 1, 2 do
    local strip = frame:CreateTexture(nil, 'BACKGROUND')
    strip:SetTexture('Interface\\Buttons\\WHITE8X8')
    local own, other = index == 1 and 'BOTTOM' or 'TOP', index == 1 and 'TOP' or 'BOTTOM'
    strip:SetPoint(own .. 'LEFT', health, other .. 'LEFT', 0, 0)
    strip:SetPoint(own .. 'RIGHT', health, other .. 'RIGHT', 0, 0)
    strip:Hide()
    frame.Highlight[index] = strip
    local side = health:CreateTexture(nil, 'OVERLAY', nil, 2)
    side:SetTexture('Interface\\Challenges\\challenges-besttime-bg')
    if index == 1 then side:SetTexCoord(89 / 512, 123 / 512, 0, 1); side:SetPoint('LEFT', health, 'LEFT', 0, 0)
    else side:SetTexCoord(123 / 512, 89 / 512, 0, 1); side:SetPoint('RIGHT', health, 'RIGHT', 0, 0) end
    side:Hide()
    frame.Ornament[index] = side
  end
  -- Warning glow above and below the bar (about to pull, or losing a tanked unit).
  local function glow(top, bottom, own, other)
    local art = frame:CreateTexture(nil, 'BACKGROUND', nil, -4)
    art:SetTexture('Interface\\BUTTONS\\UI-Panel-Button-Glow')
    art:SetTexCoord(0, 95 / 128, top, bottom)
    art:SetBlendMode('ADD')
    art:SetHeight(4)
    art:SetPoint(own .. 'LEFT', health, other .. 'LEFT', -3, 0)
    art:SetPoint(own .. 'RIGHT', health, other .. 'RIGHT', 3, 0)
    art:Hide()
    return art
  end
  frame.GlowUpper, frame.GlowLower = glow(0, 9 / 64, 'BOTTOM', 'TOP'), glow(30 / 64, 38 / 64, 'TOP', 'BOTTOM')

  local power = CreateFrame('StatusBar', nil, health)
  power:SetFrameLevel(health:GetFrameLevel() + 1)
  power.colorPower = true
  power.Text = power:CreateFontString(nil, 'OVERLAY')
  power.Text:SetFont(STANDARD_TEXT_FONT or 'Fonts\\FRIZQT__.TTF', 6, 'OUTLINE')
  power.Text:SetPoint('CENTER', power, 'CENTER', 0, 0)
  -- Power as a bare percentage; the value can be secret, so the client formats it.
  power.PostUpdate = function(element, unit)
    if not element.Text:IsShown() then return end
    local ok, value = pcall(UnitPowerPercent, unit, nil, true, CurveConstants and CurveConstants.ScaleTo100)
    if not (ok and pcall(element.Text.SetFormattedText, element.Text, '%d', value)) then element.Text:SetText('') end
  end
  frame.Power = power

  local overlay = CreateFrame('Frame', nil, frame)
  overlay:SetAllPoints(health)
  overlay:SetFrameLevel(health:GetFrameLevel() + 4)
  frame.TextLayer = overlay
  frame.Name, frame.Level, frame.Percent, frame.TargetName = fontString(overlay), fontString(overlay), fontString(overlay), fontString(overlay)
  -- Two lines for players ("<Guild>" underneath); an unwrapped string with a
  -- line break is cut to "Name...".
  frame.Name:SetWordWrap(true)
  frame.Faction = overlay:CreateTexture(nil, 'ARTWORK')
  -- The target ring hugs this icon; both skip pixel snapping so they move as one.
  if frame.Faction.SetSnapToPixelGrid then frame.Faction:SetSnapToPixelGrid(false); frame.Faction:SetTexelSnappingBias(0) end
  frame.Rare = overlay:CreateTexture(nil, 'ARTWORK')
  -- The star of the game's add-on list icons, grey as a rare marker.
  frame.Rare:SetTexture('Interface\\GLUES\\CharacterSelect\\Glues-AddOn-Icons')
  frame.Rare:SetTexCoord(0.75, 1, 0, 1)
  frame.Rare:SetDesaturated(true)
  frame.Elite = overlay:CreateTexture(nil, 'ARTWORK')
  frame.Elite:SetTexture('Interface\\GLUES\\CharacterSelect\\Glues-AddOn-Icons')
  frame.Elite:SetTexCoord(0.75, 1, 0, 1)
  frame.Elite:SetVertexColor(1, 0.8, 0)
  frame.Elite:Hide()
  frame.Rare:Hide(); frame.Faction:Hide()
  frame.Subtitle = fontString(overlay)
  frame.Subtitle:Hide()
  frame.QuestIcon = overlay:CreateTexture(nil, 'ARTWORK')
  frame.QuestIcon:SetTexture('Interface\\TargetingFrame\\PortraitQuestBadge')
  frame.QuestIcon:SetTexCoord(2 / 32, 26 / 32, 1 / 32, 31 / 32)
  frame.QuestIcon:Hide()
  frame.RaidTargetIndicator = overlay:CreateTexture(nil, 'OVERLAY')
  frame.RaidTargetIndicator:SetPoint('RIGHT', health, 'LEFT', -14, 0)
  -- The list the target ring reads to fit a friendly target's emblem.
  frame.npIcons = { frame.Faction }

  if ns.NameplateCast then ns.NameplateCast:Build(frame) end
  if ns.NameplateAuras then ns.NameplateAuras:Build(frame) end

  -- oUF registers these for the frame's own nameplate token only.
  for event, handler in pairs(handlers) do pcall(frame.RegisterEvent, frame, event, handler) end
end
