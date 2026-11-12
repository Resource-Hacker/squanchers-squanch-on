-- SPDX-License-Identifier: MIT
-- Squanch-On nameplates: the owner module (ns.Nameplates).
--
-- Plates are spawned through the bundled oUF nameplate driver, which hides the
-- game's own plate art, keeps its widget and soft-target frames, and skips
-- forbidden plates (C_NamePlate.GetNamePlateForUnit returns nil for those, so
-- the game keeps drawing them). The driver creates each frame as
-- `plate.unitFrame`, the field Plater also uses, so the two cannot run
-- together: this module refuses to start while Plater is loaded.
--
-- Work is event driven. One shared 0.2 s ticker (alpha, hover and the aura
-- tooltip gate; range for a fifth of the plates per tick) runs only while at
-- least one plate is on screen.
-- NameplateStyle.lua, NameplateCast.lua and NameplateAuras.lua build and paint
-- the frame; settings live in SquanchOnDB.nameplates (NP.defaults below).
local _, ns = ...
-- generation: bumped by every settings edit; a plate re-applies fonts, textures
-- and colours only when it differs from the one it was last dressed for.
local NP = { active = {}, count = 0, generation = 0 }
ns.Nameplates = NP
local oUF = _G.SquanchOnUF

local function public(value) return not (issecretvalue and issecretvalue(value)) end
NP.Public = public
-- A plain (non-secret) answer, or nil for errors and secrets.
local function ask(fn, ...)
  if type(fn) ~= 'function' then return nil end
  local ok, value = pcall(fn, ...)
  if ok and public(value) then return value end
end
NP.Ask = ask

-- Preview plates (NameplatePreview.lua) run the same style code on made-up
-- units. NP.fake maps a preview token to its facts; the style files read unit
-- facts through these wrappers, which pass every real unit straight through.
NP.fake = {}
local FAKE = {
  UnitName = function(f) return f.name end,
  UnitIsUnit = function(f, a, b) return (a == 'player' or b == 'player') and f.self or false end,
  UnitIsPlayer = function(f) return f.player or false end,
  UnitCanAttack = function(f) return f.attack or false end,
  UnitCanAssist = function(f) return not f.attack end,
  UnitIsFriend = function(f) if f.friend ~= nil then return f.friend end return not f.attack end,
  UnitReaction = function(f) return f.reaction or (f.attack and 2 or 5) end,
  UnitClassification = function(f) return f.classification or 'normal' end,
  UnitPlayerControlled = function(f) return f.player or false end,
  UnitFactionGroup = function(f) return f.faction end,
  UnitClass = function(f) return f.class, f.class end,
  UnitLevel = function(f) return f.level or 10 end,
  UnitIsTapDenied = function(f) return f.tapped or false end,
  UnitThreatSituation = function(f, who) if who == 'pet' then return f.petThreat end return f.threat end,
  UnitAffectingCombat = function(f) return f.combat or false end,
  UnitGUID = function() return nil end,
  UnitIsInMyGuild = function(f) return f.guildMate or false end,
  GetGuildInfo = function(f) return f.guild end,
  UnitHealthPercent = function(f) return f.health or 100 end,
  UnitPowerPercent = function(f) return f.power or 100 end,
  UnitSelectionColor = function(f)
    if f.reaction == 4 then return 1, 1, 0, 1 end
    if f.attack then return 1, 0, 0, 1 end
    return 0, 1, 0, 1
  end,
  UnitIsTrivial = function(f) return f.trivial or false end,
  UnitEffectiveLevel = function(f) return f.level or 10 end,
  UnitPowerType = function(f) return f.mana and 0 or 1 end,
}
function NP.Unit(name)
  local fake = FAKE[name]
  return function(a, b, ...)
    local facts = NP.fake[a] or (b ~= nil and NP.fake[b]) or nil
    if facts then
      if fake then return fake(facts, a, b, ...) end
      return nil
    end
    local real = _G[name]
    if real then return real(a, b, ...) end
  end
end
-- The same idea for the two aura reads the icon row makes.
NP.Auras = {
  GetAuraDataByIndex = function(unit, index, filter)
    local facts = NP.fake[unit]
    if not facts then return C_UnitAuras.GetAuraDataByIndex(unit, index, filter) end
    local seen = 0
    for _, aura in ipairs(facts.auras or {}) do
      if (aura.helpful and 'HELPFUL' or 'HARMFUL') == filter then
        seen = seen + 1
        if seen == index then return aura end
      end
    end
  end,
  IsAuraFilteredOut = function(unit, aura, filter)
    if NP.fake[unit] then
      if filter:find('CROWD_CONTROL', 1, true) then return not aura.cc end
      if filter:find('DISPELLABLE', 1, true) then return not aura.purge end
      if filter:find('DEFENSIVE', 1, true) then return not aura.defensive end
      return not aura.mine
    end
    return C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, aura.auraInstanceID, filter)
  end,
}

local F2002, MOK, MORPHEUS, FRIZ = 'Fonts\\2002B.TTF', 'Fonts\\K_Pagetext.TTF', 'Fonts\\MORPHEUS.TTF', 'Fonts\\FRIZQT__.TTF'
local function npc(health, levelX, spellY)
  return { mode = 'bar', health = { 50, health }, healthCombat = { 50, 4 }, cast = { 50, 3 }, castOffset = -2, showCast = true,
    power = false, auraOffset = -10,
    name = { font = F2002, size = 7, outline = 'OUTLINE', y = 5, classColor = false },
    level = { show = true, font = 'Expressway', size = 7, outline = 'NONE', side = 'LEFT', x = levelX, y = 0 },
    percent = { show = true, font = FRIZ, size = 6, outline = 'OUTLINE', side = 'CENTER', x = 0, y = 0, alpha = 1 },
    spell = { font = 'Harry P', size = 14, y = spellY },
    castTime = { show = true, font = 'Expressway', size = 10, outline = 'OUTLINE', side = 'INNERRIGHT', x = 20, y = 0 } }
end
local function player(font, mode, cast, power)
  local friendly = mode == 'nameOnly'
  return { mode = mode, health = { 75, 5 }, healthCombat = { 75, 5 }, cast = { 75, friendly and 5 or 4 },
    castOffset = friendly and -10 or -1, showCast = cast,
    power = power, auraOffset = 0,
    guild = true,
    name = { font = font, size = 10, outline = 'OUTLINE', y = 10, classColor = true },
    level = { show = true, font = 'Expressway', size = 8, outline = 'OUTLINE', side = 'INNERLEFT', x = 0, y = 8 },
    percent = { show = true, font = 'Expressway', size = 8, outline = 'OUTLINE', side = 'INNERRIGHT', x = 0, y = 8, alpha = friendly and 0.75 or 0.9 },
    spell = { font = 'Harry P', size = 18, y = friendly and 0 or 20 },
    castTime = { show = true, font = 'Expressway', size = 8, outline = 'OUTLINE', side = 'RIGHT', x = 5, y = 0 } }
end
-- The author's previous Plater layout as plain numbers. Colours are {r, g, b[, a]}.
NP.defaults = {
  enabled = true,
  scale = 1,
  clickSpace = { 100, 50 },
  -- Visibility toggles the owner flips by key binding (nameplateShowEnemies,
  -- nameplateShowFriends, nameplateShowAll) and nameplateMotion are not owned.
  cvars = {
    NamePlateHorizontalScale = 1, NamePlateVerticalScale = 1, ShowClassColorInNameplate = 1,
    clampTargetNameplateToScreen = 1, nameplateGlobalScale = 1, nameplateMaxDistance = 60,
    nameplateMinAlpha = 0.90135484, nameplateMinAlphaDistance = -158489.31924611, nameplateMinScale = 1,
    nameplateMotion = 0, nameplateMotionSpeed = 0.1, nameplateNotSelectedAlpha = 1, nameplateOccludedAlphaMult = 0.4,
    nameplateOtherAtBase = 0, nameplateOtherTopInset = 0.085, nameplateOverlapH = 1, nameplateOverlapV = 0.5,
    nameplatePersonalHideDelaySeconds = 0.2, nameplatePersonalShowAlways = 1, nameplatePersonalShowInCombat = 1,
    nameplatePersonalShowWithTarget = 1, nameplateRemovalAnimation = 0, nameplateSelectedAlpha = 1,
    nameplateSelectedScale = 1.2, nameplateSelfAlpha = 1, nameplateSelfBottomInset = 0.2, nameplateSelfScale = 1,
    nameplateSelfTopInset = 0.5, nameplateShowEnemyMinions = 1, nameplateShowEnemyMinus = 1, nameplateShowEnemyPets = 1,
    nameplateShowEnemyTotems = 1, nameplateShowFriendlyBuffs = 0, nameplateShowFriendlyGuardians = 1,
    nameplateShowFriendlyMinions = 1, nameplateShowFriendlyNPCs = 1, nameplateShowFriendlyPets = 1,
    nameplateShowFriendlyPlayerMinions = 1, nameplateShowFriendlyPlayers = 1, nameplateShowFriendlyTotems = 1,
    nameplateShowOffscreen = 0, nameplateShowOnlyNames = 1, nameplateShowPersonalCooldowns = 0, nameplateShowSelf = 0,
    nameplateSimplifiedTypes = 'K', nameplateStackingTypes = 'A', nameplateTargetBehindMaxDistance = 41,
    nameplateTargetRadialPosition = 1, nameplateUseClassColorForFriendlyPlayerUnitNames = 1,
  },
  border = { thickness = 2, color = { 0.098, 0.098, 0.098, 0.25 }, theme = false },
  health = { texture = 'Interface\\TargetingFrame\\UI-StatusBar', background = { 0.098, 0.098, 0.098, 0.506 } },
  types = {
    enemynpc = npc(2, -2, 20),
    friendlynpc = npc(3, -2.5, 30),
    enemyplayer = player(MORPHEUS, 'bar', true, true),
    friendlyplayer = player(MOK, 'nameOnly', false, false),
  },
  barWhenTargetedFaction = 'Horde',
  -- An enemy NPC the player cannot attack shows its name only, in this font.
  bigName = { font = 'Expressway', size = 10, outline = 'OUTLINE' },
  -- Its profession or title line ("<Innkeeper>"), in the name's colour.
  smoothMotion = true,
  subtitle = { show = true, font = 'Expressway', size = 10, outline = 'OUTLINE', underBar = true, barSize = 7, barGap = 2 },
  -- Cyrillic names in Latin letters.
  translit = true,
  -- Friendly plates by kind of zone (out of combat, on zone changes).
  zoneFriendly = { enabled = true, party = false, raid = false, arena = true, world = true, cities = true },
  power = { height = 1.5, y = -2, text = true, textFont = 'Expressway', textSize = 6 },
  sizeScale = { minor = { 0.5, 0.55 }, pet = { 0.95, 0.95 } },
  colors = {
    hostile = { 0.918, 0.129, 0.071 }, neutral = { 0.925, 0.8, 0.267 }, friendly = { 0.024, 0.824, 0.024 },
    tapped = { 0.392, 0.392, 0.392 }, noCombat = { 0.505, 0.003, 0 },
    quest = true, questHostile = { 1, 0.369, 0 }, questNeutral = { 1, 0.65, 0 }, questFriendly = { 0.5, 1, 0 },
    threat = true, role = 'dps',
    dpsAggro = { 1, 0.11, 0 }, dpsPulling = { 1, 0.8, 0 }, dpsNoAggro = { 0.5, 0.5, 1 },
    tankAggro = { 0.5, 0.5, 1 }, tankPulling = { 1, 1, 0 }, tankNoAggro = { 1, 0, 0 },
    -- Dungeons, raids and scenarios, outside the threat colours.
    unitType = true, boss = { 0.424, 0.173, 0.69 }, miniboss = { 0.278, 0.259, 1 }, caster = { 0, 0.82, 1 },
    name = { 1, 1, 1 }, friend = { 0.71, 1, 1 }, guild = { 0.498, 1, 0.2 }, friendColors = true,
  },
  cast = {
    texture = 'Squanch Smooth', background = { 0.114, 0.114, 0.114, 0.1 },
    normal = { 1, 0.7, 0, 0.96 }, channel = { 0, 1, 0, 0.96 }, nonInterruptible = { 0.5, 0.5, 0.5, 1 },
    interrupted = { 1, 0.1, 0.1, 1 },
    spark = true, sparkWidth = 17, icon = true, iconX = -15, shield = true, hideNameWhileCasting = true,
    -- Cast end: a finished cast flashes and fades; an interrupted one stays, then fades.
    holdInterrupted = 1, fade = 0.5, finishFlash = true, finished = { 0, 1, 0, 1 },
    textShadow = { 0, 0, 0, 0.5 },
  },
  auras = {
    enabled = true, size = 15, perRow = 8, max = 16, y = 35, alpha = 0.7, timer = true, timerSize = 8, stackSize = 10,
    mine = true, cc = true, defensive = true, tooltip = true,
  },
  target = {
    highlight = { 0.588, 0, 0.118, 0.109 }, highlightHeight = 11, overlayAlpha = 0.6, hoverAlpha = 0.5,
    ornament = true, ornamentColor = { 1, 0, 0, 0.7 }, aggroGlow = true,
    -- White flash over the bar when a unit turns on a damage dealer or healer.
    aggroFlash = { enabled = true, instanceOnly = true, duration = 0.2, color = { 1, 1, 1, 1 }, text = true },
    label = { show = true, font = F2002, size = 7, outline = 'OUTLINE', x = 25, y = -10, alpha = 0.66 },
  },
  -- The out-of-range values double as the in-range factor for plates that are
  -- not the target (Plater's "range + non-target" behaviour with division).
  alpha = { inRange = 0.9, outOfRange = 0.9, healthOutOfRange = 0.9, castOutOfRange = 0.5, aurasOutOfRange = 0.9,
    nonTargetMultiplier = 0.5, notInCombatEnabled = true, notInCombat = 0.25, rangeYards = 40 },
  -- Size 12 and offset (-0.5, -8) at the previous 1.5 icon scale.
  indicators = { size = 18, x = -0.75, y = -12, friendlyFaction = true, enemyFaction = true, rare = true, raidMark = true, quest = true },
  -- Additions over the previous look. All off while classicLook is on.
  enhance = {
    classicLook = true,
    animatedBars = true, emphasis = true, auraRows = true, castIntel = true, hunterThreat = true, levelling = true,
    pointer = true, stackingBounds = true, offscreen = true, stacking = true,
    hoverScale = 1.08, targetScale = 1.15, executeThreshold = 0.2,
    onMe = { 1, 0.11, 0 }, petHolds = { 0.3, 0.75, 0.45 }, gaining = { 1, 0.8, 0 },
  },
}

local function fill(target, defaults)
  for key, value in pairs(defaults) do
    if type(value) == 'table' then
      if type(target[key]) ~= 'table' then target[key] = {} end
      fill(target[key], value)
    elseif target[key] == nil then
      target[key] = value
    end
  end
end
local filled
function NP:Settings()
  local db = ns.db
  if not db then return self.defaults end
  local settings = db.nameplates
  if type(settings) ~= 'table' then settings = {}; db.nameplates = settings end
  if filled ~= settings then
    -- Revision 2: the interrupt hold became holdInterrupted, and the name-only
    -- font follows the previous profile; untouched earlier defaults move along.
    if settings.revision ~= 2 then
      if type(settings.cast) == 'table' then settings.cast.hold = nil end
      local big = settings.bigName
      if type(big) == 'table' and big.font == 'Fonts\\ARIALN.TTF' and big.size == 9 then big.font, big.size = nil, nil end
      local icons = settings.indicators
      if type(icons) == 'table' and icons.x == -0.5 and icons.y == -8 then icons.x, icons.y = nil, nil end
      settings.revision = 2
    end
    fill(settings, self.defaults); filled = settings
  end
  return settings
end

-- shadow: an {r, g, b, a} override of the black drop shadow.
function NP:Font(object, name, size, outline, shadow)
  local path = ns.Media and ns.Media:Resolve('font', name) or name
  if not object:SetFont(path, size, outline == 'NONE' and '' or outline or '') then
    object:SetFont(STANDARD_TEXT_FONT or 'Fonts\\FRIZQT__.TTF', size, outline == 'NONE' and '' or outline or '')
  end
  -- The previous plates drew every text with a black one-unit drop shadow; it
  -- is what keeps a bar from showing through the hollows of the digits.
  if type(shadow) == 'table' then object:SetShadowColor(shadow[1] or 0, shadow[2] or 0, shadow[3] or 0, shadow[4] or 1)
  else object:SetShadowColor(0, 0, 0, 1) end
  object:SetShadowOffset(1, -1)
end

function NP:PlaterLoaded()
  if _G.Plater ~= nil then return true end
  return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded('Plater') and true or false
end
function NP:IsActive() return self.started == true end
-- The Squanch-On frame on a unit's visible plate, if this module drew it.
function NP:PlateFor(unit)
  local plate = C_NamePlate and ask(C_NamePlate.GetNamePlateForUnit, unit)
  local frame = plate and plate.unitFrame
  if frame and self.active[frame] then return frame, plate end
end
function NP:IsTarget(frame)
  if frame and frame.npFake then return frame.npFake.target or false end
  return frame ~= nil and frame == self.targetFrame
end
-- Whether the player is fighting, as this plate sees it (previews state it).
function NP:Fighting(frame)
  if frame and frame.npFake then return frame.npFake.playerCombat or false end
  return self.combat or false
end
-- 'party', 'raid', 'scenario', 'pvp', 'arena' or 'none' (previews state theirs).
function NP:Zone(frame)
  if frame and frame.npFake then return frame.npFake.zone or 'none' end
  return self.zone or 'none'
end
function NP:ZoneChanged()
  local ok, _, kind = pcall(IsInInstance or error)
  local zone = ok and public(kind) and type(kind) == 'string' and kind or 'none'
  local resting = IsResting and ask(IsResting) == true
  if zone == self.zone and resting == self.resting then return end
  local changed = zone ~= self.zone
  self.zone, self.resting = zone, resting
  if not self.started then return end
  if self:Settings().zoneFriendly.enabled then self:ApplyCVars(true) end
  if changed then self:RefreshAll() end
end
function NP:FriendlyRange() return tonumber(self:Settings().alpha.rangeYards) or 40 end

-- One-time read of the Plater profile this character uses. PlaterDB exists only
-- while Plater is loaded, so this runs even when the module then refuses to
-- start. Nothing is ever written to Plater's saved variables.
function NP:ImportPlater()
  local settings = self:Settings()
  local db = _G.PlaterDB
  if settings == self.defaults or settings.importVersion or type(db) ~= 'table' or type(db.profiles) ~= 'table' then return end
  local name = ask(UnitName, 'player')
  local realm = ask(GetRealmName)
  -- The profile this character has selected; some clients key it by name alone.
  local keys = type(db.profileKeys) == 'table' and db.profileKeys or {}
  local chosen = name and (realm and keys[name .. ' - ' .. realm] or keys[name])
  local profile = chosen and db.profiles[chosen]
  if type(profile) ~= 'table' then return end
  local function number(source, key, target, field, low, high)
    local value = type(source) == 'table' and source[key]
    if type(value) == 'number' and value >= low and value <= high then target[field] = value end
  end
  local function pair(source, key, target, field)
    local value = type(source) == 'table' and source[key]
    if type(value) == 'table' and type(value[1]) == 'number' and type(value[2]) == 'number'
      and value[1] > 0 and value[1] <= 400 and value[2] > 0 and value[2] <= 100 then target[field] = { value[1], value[2] } end
  end
  local function color(source, key, target, field)
    local value = type(source) == 'table' and source[key]
    if type(value) ~= 'table' then return end
    local r, g, b, a = value[1] or value.r, value[2] or value.g, value[3] or value.b, value[4] or value.a
    if type(r) == 'number' and type(g) == 'number' and type(b) == 'number' then
      target[field] = { r, g, b, type(a) == 'number' and a or target[field] and target[field][4] or nil }
    end
  end
  for kind, own in pairs(settings.types) do
    local source = type(profile.plate_config) == 'table' and profile.plate_config[kind]
    pair(source, 'health', own, 'health'); pair(source, 'health_incombat', own, 'healthCombat')
    pair(source, 'cast', own, 'cast')
    number(source, 'castbar_offset', own, 'castOffset', -50, 50)
    number(source, 'buff_frame_y_offset', own, 'auraOffset', -100, 100)
    number(source, 'actorname_text_size', own.name, 'size', 4, 40)
    number(source, 'level_text_size', own.level, 'size', 4, 40)
    number(source, 'percent_text_size', own.percent, 'size', 4, 40)
    number(source, 'spellname_text_size', own.spell, 'size', 4, 40)
  end
  number(profile, 'aura_width', settings.auras, 'size', 6, 64)
  number(profile, 'auras_per_row_amount', settings.auras, 'perRow', 1, 20)
  number(profile, 'aura_alpha', settings.auras, 'alpha', 0, 1)
  number(profile, 'not_affecting_combat_alpha', settings.alpha, 'notInCombat', 0, 1)
  if type(profile.not_affecting_combat_enabled) == 'boolean' then settings.alpha.notInCombatEnabled = profile.not_affecting_combat_enabled end
  number(profile, 'range_check_in_range_or_target_alpha', settings.alpha, 'inRange', 0, 1)
  number(profile, 'range_check_alpha', settings.alpha, 'outOfRange', 0, 1)
  number(profile, 'range_check_health_bar_alpha', settings.alpha, 'healthOutOfRange', 0, 1)
  number(profile, 'range_check_cast_bar_alpha', settings.alpha, 'castOutOfRange', 0, 1)
  number(profile, 'range_check_buffs_alpha', settings.alpha, 'aurasOutOfRange', 0, 1)
  number(profile, 'border_thickness', settings.border, 'thickness', 0, 8)
  color(profile, 'border_color', settings.border, 'color')
  color(profile, 'tap_denied_color', settings.colors, 'tapped')
  color(profile, 'cast_statusbar_color', settings.cast, 'normal')
  color(profile, 'cast_statusbar_color_channeling', settings.cast, 'channel')
  color(profile, 'cast_statusbar_color_nointerrupt', settings.cast, 'nonInterruptible')
  color(profile, 'cast_statusbar_color_interrupted', settings.cast, 'interrupted')
  settings.importVersion = 1
end

-- /sqplates debug: one line per visible plate. Secrets print as "secret".
function NP:Debug()
  local function show(value)
    if not public(value) then return 'secret' end
    return tostring(value)
  end
  local function fact(fn, ...)
    if type(fn) ~= 'function' then return 'no-api' end
    local ok, value = pcall(fn, ...)
    return ok and show(value) or 'error'
  end
  local function text(region, why)
    if not region then return 'none' end
    if not region:IsShown() then return 'hidden(' .. why .. ')' end
    local ok, value = pcall(region.GetText, region)
    return ok and ('"' .. show(value) .. '"') or 'shown'
  end
  print(('Squanch-On plates: started=%s active=%d zone=%s combat=%s'):format(tostring(self.started), self.count, tostring(self.zone), tostring(self.combat)))
  for frame in pairs(self.active) do
    local unit = frame.unit
    local bar = frame.Health and frame.Health:IsShown()
    local cast = frame.Castbar and frame.Castbar:IsShown()
    print(('%s oUF=%s kind=%s size=%s class=%s reaction=%s attack=%s player=%s bar=%s colour=%s name=%s level=%s alpha=%s'):format(
      show(unit), show(frame.__unit), tostring(frame.npKind), tostring(frame.npSize or 'normal'),
      unit and fact(UnitClassification, unit) or '-', unit and fact(UnitReaction, unit, 'player') or '-',
      unit and fact(UnitCanAttack, 'player', unit) or '-', unit and fact(UnitIsPlayer, unit) or '-',
      tostring(bar), tostring(frame.npColorSource or 'unset'),
      text(frame.Name, cast and 'casting' or 'unknown'), text(frame.Level, bar and 'level off' or 'no bar'), tostring(frame.npAlpha)))
  end
end

-- CVars ----------------------------------------------------------------------
local function same(current, wanted)
  local a, b = tonumber(current), tonumber(wanted)
  if a and b then return math.abs(a - b) < 0.0001 end
  return tostring(current) == tostring(wanted)
end
-- Previous values are recorded once (an account receipt) and restored on disable.
-- zone: also set the friendly-plates switch for the kind of zone. Only zone
-- changes, the start and the zone options ask for it, so a key binding that
-- flips the switch keeps its say until the next zone.
function NP:ApplyCVars(zone)
  if zone then self.pendingZone = true end
  if InCombatLockdown() then self.pendingCVars = true; return false end
  self.pendingCVars = nil
  zone, self.pendingZone = self.pendingZone, nil
  local previous = ns.db.nameplateCVarsPrevious
  if type(previous) ~= 'table' then previous = {}; ns.db.nameplateCVarsPrevious = previous end
  local wanted = {}
  for name, value in pairs(self:Settings().cvars) do wanted[name] = value end
  local enhance = ns.NameplateEnhance
  if enhance and enhance:On('pointer') and enhance:On('offscreen') then wanted.nameplateShowOffscreen = 1 end
  if enhance and enhance:On('stacking') then wanted.nameplateMotion = 1 end
  local friendly = self:Settings().zoneFriendly
  if zone and friendly.enabled then
    local zone = self.zone
    local shown
    if zone == 'party' or zone == 'raid' then shown = friendly[zone]
    elseif zone == 'arena' or zone == 'pvp' then shown = friendly.arena
    elseif self.resting then shown = friendly.cities else shown = friendly.world end
    -- Newer clients split friendly players from the binding-owned master switch.
    local name = ask(GetCVar, 'nameplateShowFriendlyPlayers') ~= nil and 'nameplateShowFriendlyPlayers' or 'nameplateShowFriends'
    wanted[name] = shown and 1 or 0
  end
  for name, value in pairs(wanted) do
    local current = ask(GetCVar, name) -- nil: this client has no such CVar
    if current ~= nil then
      if previous[name] == nil then previous[name] = current end
      if not same(current, value) then pcall(SetCVar, name, value) end
    end
  end
  -- The rings keep nameplateSelectedScale; it may just have changed.
  if ns.TargetCrosshairs and ns.TargetCrosshairs.ScaleChanged then ns.TargetCrosshairs:ScaleChanged() end
  return true
end
function NP:RestoreCVars()
  local previous = ns.db and ns.db.nameplateCVarsPrevious
  if type(previous) ~= 'table' then return true end
  if InCombatLockdown() then self.pendingRestore = true; return false end
  self.pendingRestore = nil
  for name, value in pairs(previous) do
    if ask(GetCVar, name) ~= nil then pcall(SetCVar, name, value) end
  end
  if ns.TargetCrosshairs and ns.TargetCrosshairs.ScaleChanged then ns.TargetCrosshairs:ScaleChanged() end
  ns.db.nameplateCVarsPrevious = nil
  return true
end

-- Driver ---------------------------------------------------------------------
-- Mouseover ending raises no event. While a plate is hovered (and only then)
-- a watcher asks each frame whether the mouse is still on it, so the highlight
-- ends on the very frame the mouse leaves, like the reticle's chevrons. Asked
-- by plate, the way the mouseover event finds it: comparing unit tokens can
-- come back unreadable for players.
local watcher = CreateFrame('Frame')
watcher:Hide()
function NP:HoverCheck()
  local hovered = self.hoverFrame
  if not hovered then watcher:Hide(); return end
  if self:PlateFor('mouseover') == hovered then
    -- The plate under the mouse gets a fresh range answer every frame (one
    -- item/spell range call for one unit): its fade is never behind.
    if ns.NameplateAuras then ns.NameplateAuras:Alpha(hovered, false, true) end
    return
  end
  self.hoverFrame = nil
  watcher:Hide()
  ns.NameplateStyle:SetHover(hovered, false)
  if ns.NameplateEnhance then ns.NameplateEnhance:Emphasis(hovered) end
end
watcher:SetScript('OnUpdate', function() NP:HoverCheck() end)
local ticker
local function tick() NP:Tick() end
function NP:Tick()
  local gate = ns.IsNativeMouseoverOpen and ns:IsNativeMouseoverOpen() and true or false
  if gate ~= self.gate then
    self.gate = gate
    if ns.NameplateAuras then ns.NameplateAuras:SetMouse(gate) end
    if self.hoverFrame and ns.NameplateEnhance then ns.NameplateEnhance:Emphasis(self.hoverFrame) end
  end
  local Style, Auras = ns.NameplateStyle, ns.NameplateAuras
  self:HoverCheck()
  -- Range costs item and spell checks: each plate asks on its own tick out of
  -- five (once a second), the hovered plate on every tick; the others reuse
  -- their last answer.
  local slot = ((self.rangeSlot or 0) + 1) % 5
  self.rangeSlot = slot
  local hovered = self.hoverFrame
  for frame in pairs(self.active) do
    -- Threat and "not in combat" follow the fight without a reliable event.
    if self.combat and frame.npKind == 'enemynpc' then Style:Color(frame) end
    if Auras then Auras:Alpha(frame, false, frame.npRangeSlot == slot or frame == hovered or frame == self.targetFrame) end
  end
end

function NP:Added(frame, unit)
  -- The bundled oUF keeps a plate's token privately (frame.__unit); every
  -- nameplate module reads frame.unit, so publish it here.
  frame.unit = unit
  local plate = frame:GetParent()
  -- The record TargetCrosshairs fits the friendly ring to (as Plater's list).
  plate.IconIndicators = frame.npIcons
  if not self.active[frame] then self.active[frame] = true; self.count = self.count + 1 end
  -- Another unit: the last range answer is not this one's. Plates take the
  -- five range ticks in turn.
  frame.npRangeAt = nil
  self.nextSlot = ((self.nextSlot or 0) + 1) % 5
  frame.npRangeSlot = self.nextSlot
  if ask(C_NamePlate.GetNamePlateForUnit, 'target') == plate then self.targetFrame = frame end
  local Style = ns.NameplateStyle
  Style:Classify(frame, unit)
  Style:Layout(frame)
  Style:Refresh(frame)
  if ns.NameplateAuras then ns.NameplateAuras:Refresh(frame); ns.NameplateAuras:Alpha(frame, true) end
  if not ticker and C_Timer and C_Timer.NewTicker then ticker = C_Timer.NewTicker(0.2, tick) end
end
function NP:Removed(frame)
  frame.unit = nil
  if self.active[frame] then self.active[frame] = nil; self.count = math.max(0, self.count - 1) end
  if self.targetFrame == frame then self.targetFrame = nil end
  if self.hoverFrame == frame then ns.NameplateStyle:SetHover(frame, false); self.hoverFrame = nil end
  if self.count == 0 and ticker then ticker:Cancel(); ticker = nil end
end

-- Combat edge: NPC bars change height (healthCombat) and enemy NPCs take or
-- drop their threat colours. Nothing else of a plate depends on it.
function NP:CombatEdge()
  local Style, Auras = ns.NameplateStyle, ns.NameplateAuras
  for frame in pairs(self.active) do
    Style:Arrange(frame)
    if frame.npKind == 'enemynpc' then Style:Color(frame) end
    if Auras then Auras:Alpha(frame, true) end
  end
end

-- Re-lays out and repaints every visible plate (settings edit, zone change).
function NP:RefreshAll()
  self.generation = self.generation + 1
  if ns.NameplatePreview then ns.NameplatePreview:Refresh() end
  if not self.started then return end
  local Style = ns.NameplateStyle
  for frame in pairs(self.active) do
    Style:Classify(frame, frame.unit)
    Style:Layout(frame)
    Style:Refresh(frame)
    if ns.NameplateCast then ns.NameplateCast:Style(frame) end
    if ns.NameplateAuras then ns.NameplateAuras:Refresh(frame); ns.NameplateAuras:Alpha(frame, true) end
  end
end

function NP:Retarget(frame)
  if not (frame and self.active[frame]) then return end
  local Style = ns.NameplateStyle
  Style:Arrange(frame); Style:Refresh(frame)
  if ns.NameplateAuras then ns.NameplateAuras:Refresh(frame) end
end
function NP:TargetChanged()
  local frame = self:PlateFor('target')
  local previous = self.targetFrame
  self.targetFrame = frame
  -- A hovered plate that becomes (or stops being) the target moves its highlight.
  if self.hoverFrame and ns.NameplateStyle and C_Timer then
    local hovered = self.hoverFrame
    C_Timer.After(0, function() if NP.hoverFrame == hovered then ns.NameplateStyle:SetHover(hovered, true) end end)
  end
  -- The mouseover ring hands over to (or takes over from) the target ring at once.
  if ns.NameplateHoverRing then ns.NameplateHoverRing:Set(self.hoverFrame, self.hoverFrame ~= nil) end
  -- The plate that lost the target and the one that got it: bar shown, strips,
  -- ornaments (no fonts or textures), then what follows the unit.
  if previous ~= frame then self:Retarget(previous) end
  self:Retarget(frame)
  if ns.NameplateAuras then
    for shown in pairs(self.active) do ns.NameplateAuras:Alpha(shown) end
  end
  -- The friendly ring fits the faction emblem this just showed or hid.
  local marker = ns.TargetCrosshairs
  if marker and marker.RefreshTarget then marker:RefreshTarget() end
end

-- The driver's size, hit-test and (unused) CVar setters are protected calls
-- that oUF makes unguarded, so this runs out of combat only.
function NP:Start()
  if self.started or self.refused then return false end
  local settings = self:Settings()
  if settings == self.defaults then return false end
  self:ImportPlater()
  if not settings.enabled then return false end
  if self:PlaterLoaded() then
    self.refused = true
    print("|cff33ff99Squanch-On|r nameplates are off while Plater is loaded. Disable Plater in the AddOns list and /reload to use them.")
    return false
  end
  if not (oUF and oUF.SpawnNamePlates and ns.NameplateStyle and C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return false end
  self.Listen()
  if InCombatLockdown() then self.pendingStart = true; return false end
  self.pendingStart = nil
  if not self.styled then
    self.styled = true
    oUF:RegisterStyle('SquanchOnNameplate', function(frame, unit) ns.NameplateStyle:Build(frame, unit) end)
  end
  local previous = oUF:GetActiveStyle()
  oUF:SetActiveStyle('SquanchOnNameplate')
  local driver = oUF:SpawnNamePlates('SquanchOnNP')
  if previous then oUF:SetActiveStyle(previous) end
  if not driver then return false end
  self.driver, self.started = driver, true
  driver:SetAddedCallback(function(frame, _, unit) NP:Added(frame, unit) end)
  driver:SetRemovedCallback(function(frame) NP:Removed(frame) end)
  -- Plates are information only: native world models own cursor picking
  -- (WorldModelPicking.lua applies the same empty hit area).
  driver.enemyNonInteractible, driver.friendlyNonInteractible = true, true
  local click = settings.clickSpace
  driver:SetSize(tonumber(click[1]) or 100, tonumber(click[2]) or 50)
  self.zone = nil; self:ZoneChanged()
  self:ApplyCVars(true)
  if ns.NameplateEnhance then ns.NameplateEnhance:Listen() end
  -- Plates already on screen (a start delayed by combat) raise no new event.
  local handler = driver:GetScript('OnEvent')
  for _, plate in ipairs(C_NamePlate.GetNamePlates and C_NamePlate.GetNamePlates() or {}) do
    local unit = plate.namePlateUnitToken
    if public(unit) and type(unit) == 'string' then handler(driver, 'NAME_PLATE_UNIT_ADDED', unit) end
  end
  return true
end

-- The options switch. Enabling starts at once (out of combat); disabling
-- restores the recorded CVars, and a reload returns the game's own plates.
function NP:SetEnabled(enabled)
  self:Settings().enabled = enabled and true or false
  if enabled then return self:Start() end
  if self.started then
    self:RestoreCVars()
    print("|cff33ff99Squanch-On|r nameplates off: /reload returns the game's own nameplates.")
  end
end

local events = CreateFrame('Frame')
local listening
-- Inert with Plater or when switched off: only PLAYER_LOGIN is ever heard.
local function listen()
  if listening then return end
  listening = true
  for _, name in ipairs({ 'PLAYER_REGEN_ENABLED', 'PLAYER_REGEN_DISABLED', 'PLAYER_TARGET_CHANGED', 'UPDATE_MOUSEOVER_UNIT',
    'QUEST_LOG_UPDATE', 'PLAYER_ENTERING_WORLD', 'ZONE_CHANGED_NEW_AREA', 'PLAYER_UPDATE_RESTING' }) do
    events:RegisterEvent(name)
  end
end
NP.Listen = listen
events:RegisterEvent('PLAYER_LOGIN')
events:SetScript('OnEvent', function(_, event)
  if event == 'PLAYER_LOGIN' then NP:Start(); return end
  if event == 'PLAYER_REGEN_ENABLED' then
    if NP.pendingStart then NP:Start() end
    if NP.pendingCVars then NP:ApplyCVars() end
    if NP.pendingRestore then NP:RestoreCVars() end
  end
  if not NP.started then return end
  if event == 'QUEST_LOG_UPDATE' then
    ns.NameplateStyle:QuestsChanged()
  elseif event == 'PLAYER_ENTERING_WORLD' or event == 'ZONE_CHANGED_NEW_AREA' or event == 'PLAYER_UPDATE_RESTING' then
    NP:ZoneChanged()
  elseif event == 'PLAYER_TARGET_CHANGED' then
    NP:TargetChanged()
  elseif event == 'UPDATE_MOUSEOVER_UNIT' then
    local frame = NP:PlateFor('mouseover')
    if frame ~= NP.hoverFrame then
      if NP.hoverFrame then ns.NameplateStyle:SetHover(NP.hoverFrame, false) end
      local left = NP.hoverFrame
      NP.hoverFrame = frame
      watcher:SetShown(frame ~= nil)
      if frame and ns.NameplateAuras then ns.NameplateAuras:Alpha(frame, true, true) end
      if frame then ns.NameplateStyle:SetHover(frame, true) end
      if ns.NameplateEnhance then
        if left then ns.NameplateEnhance:Emphasis(left) end
        if frame then ns.NameplateEnhance:Emphasis(frame) end
      end
    end
  else
    -- Combat edge: enemy and friendly NPC bars change height.
    NP.combat = event == 'PLAYER_REGEN_DISABLED'
    if NP.combat then NP.combatSince = GetTime() end
    NP:CombatEdge()
  end
end)
