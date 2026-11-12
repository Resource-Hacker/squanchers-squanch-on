-- SPDX-License-Identifier: MIT
-- Squanch-On's own camera: every DynamicCam standard setting (optionally driven
-- by a zoom curve), eased wheel zoom, and situations that override them.
--
-- The driver, the zoom/rotation tracking, the condition model, the CVar write
-- path and the import are original. Ported from DynamicCam (MIT, copyright
-- 2016-2020 Michael P. Starkweather, 2020-2026 LudiusMaximus; see
-- LICENSES/DynamicCam-MIT.txt) so its settings keep their meaning: the setting
-- and situation catalogue with its priorities, the wheel-increment rules
-- (MouseZoom.lua), the precedence of situation values and curves over standard
-- ones and the toggle-group transitions (ZoomBasedSettings.lua), and the
-- situation selection, delay, zoom-action and zoom-restore rules
-- (SituationManager.lua).
local _, addon = ...
local Camera = {}
addon.Camera = Camera

local abs, min, max, huge = math.abs, math.min, math.max, math.huge
local GetCameraZoom, GetCVar, GetTime = GetCameraZoom, GetCVar, GetTime
local YAW, PITCH = "cameraYawMoveSpeed", "cameraPitchMoveSpeed"
local POPUP = "EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED"

-- min/max mark a setting that may follow a zoom curve (curve output is clamped
-- to them). children: strengths eased to/from zero when the toggle flips during
-- a transition. parent: curve is not driven while that toggle is 0.
local SETTINGS = {
  {name = "test_cameraOverShoulder", group = "shoulder", label = "Shoulder offset (right +, left -)", min = -15, max = 15},
  {name = "cameraFov", group = "fov", label = "Field of view", min = 60, max = 90, clampFixed = true},
  {name = "cameraDistanceMaxZoomFactor", group = "zoom", label = "Maximum zoom factor (x 15 yards)", instant = true},
  {name = "cameraZoomSpeed", group = "zoom", label = "Native zoom speed"},
  {name = "test_cameraHeadMovementStrength", group = "head", label = "Head movement (0 off, 1 on)", toggle = true,
    children = {"test_cameraHeadMovementStandingStrength", "test_cameraHeadMovementMovingStrength"}},
  {name = "test_cameraHeadMovementStandingStrength", group = "head", label = "Standing strength", min = 0, max = 1},
  {name = "test_cameraHeadMovementStandingDampRate", group = "head", label = "Standing damp rate", min = 0, max = 20, floor = 0.01},
  {name = "test_cameraHeadMovementMovingStrength", group = "head", label = "Moving strength", min = 0, max = 1},
  {name = "test_cameraHeadMovementMovingDampRate", group = "head", label = "Moving damp rate", min = 0, max = 20, floor = 0.01},
  {name = "test_cameraHeadMovementFirstPersonDampRate", group = "head", label = "First-person damp rate", floor = 0.01},
  {name = "test_cameraHeadMovementRangeScale", group = "head", label = "Range scale"},
  {name = "test_cameraHeadMovementDeadZone", group = "head", label = "Dead zone"},
  {name = "test_cameraDynamicPitch", group = "pitch", label = "Dynamic pitch (0 off, 1 on)", toggle = true, switch = true},
  {name = "test_cameraDynamicPitchBaseFovPad", group = "pitch", label = "Base FoV pad", min = 0, max = 0.99},
  {name = "test_cameraDynamicPitchBaseFovPadFlying", group = "pitch", label = "Base FoV pad (flying)", min = 0, max = 1},
  {name = "test_cameraDynamicPitchBaseFovPadDownScale", group = "pitch", label = "Base FoV pad down scale", min = 0, max = 1},
  {name = "test_cameraDynamicPitchSmartPivotCutoffDist", group = "pitch", label = "Smart pivot cutoff distance"},
  {name = "test_cameraTargetFocusEnemyEnable", group = "focus", label = "Enemy target focus (0 off, 1 on)", toggle = true,
    children = {"test_cameraTargetFocusEnemyStrengthYaw", "test_cameraTargetFocusEnemyStrengthPitch"}},
  {name = "test_cameraTargetFocusEnemyStrengthYaw", group = "focus", label = "Enemy yaw strength", min = 0, max = 1},
  {name = "test_cameraTargetFocusEnemyStrengthPitch", group = "focus", label = "Enemy pitch strength", min = 0, max = 1},
  {name = "test_cameraTargetFocusInteractEnable", group = "focus", label = "Interact target focus (0 off, 1 on)", toggle = true,
    children = {"test_cameraTargetFocusInteractStrengthYaw", "test_cameraTargetFocusInteractStrengthPitch"}},
  {name = "test_cameraTargetFocusInteractStrengthYaw", group = "focus", label = "Interact yaw strength", min = 0, max = 1},
  {name = "test_cameraTargetFocusInteractStrengthPitch", group = "focus", label = "Interact pitch strength", min = 0, max = 1},
  {name = YAW, group = "speeds", label = "Yaw (turn) speed"},
  {name = PITCH, group = "speeds", label = "Pitch speed"},
}
local DEF = {}
for _, def in ipairs(SETTINGS) do DEF[def.name] = def end
for _, def in ipairs(SETTINGS) do
  local parent = def.name:match("^test_cameraDynamicPitch.") and "test_cameraDynamicPitch"
    or def.name:match("^test_cameraHeadMovement") and def.name ~= "test_cameraHeadMovementStrength" and "test_cameraHeadMovementStrength"
    or def.name:match("^test_cameraTargetFocusEnemyStrength") and "test_cameraTargetFocusEnemyEnable"
    or def.name:match("^test_cameraTargetFocusInteractStrength") and "test_cameraTargetFocusInteractEnable"
  def.parent = parent or nil
end
Camera.SETTINGS, Camera.DEF = SETTINGS, DEF
-- Forced off with an active shoulder offset or dynamic pitch, as the client requires.
local COMPANIONS = {"CameraKeepCharacterCentered", "CameraReduceUnexpectedMovement"}

local EASE = {
  Linear = function(t) return t end,
  InQuad = function(t) return t * t end,
  OutQuad = function(t) return 1 - (1 - t) * (1 - t) end,
  InOutQuad = function(t) if t < 0.5 then return 2 * t * t end return 1 - 2 * (1 - t) * (1 - t) end,
}
Camera.EASINGS = {"OutQuad", "InOutQuad", "InQuad", "Linear"}

-- ---------------------------------------------------------------------------
-- Situation conditions. A condition is a list of atoms that must all hold:
-- "name", "!name" (negated) or "name:argument". No Lua from saved data is run.
-- ---------------------------------------------------------------------------
local function idSet(text)
  local set = {}
  for item in tostring(text or ""):gmatch("[^,]+") do
    item = item:match("^%s*(.-)%s*$")
    set[tonumber(item) or item] = true
  end
  return set
end
local function spellName(id)
  if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
  if GetSpellInfo then return (GetSpellInfo(id)) end
end
local function secret(value) return issecretvalue and issecretvalue(value) end
-- The spell being cast or channelled is one of the listed ids or names.
local function spellMatches(set, name, id)
  if not name or secret(name) then return false end
  if id and not secret(id) and set[id] then return true end
  if set[name] then return true end
  for key in pairs(set) do
    if type(key) == "number" and spellName(key) == name then return true end
  end
  return false
end
local CAST_EVENTS = {"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_CHANNEL_START",
  "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_INTERRUPTED"}
local ZONE_EVENTS = {"ZONE_CHANGED_INDOORS", "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA", "SPELL_UPDATE_USABLE"}
local NPC_FRAMES = {"AuctionHouseFrame", "BagnonBankFrame1", "BankFrame", "ClassTrainerFrame", "GossipFrame", "GuildRegistrarFrame",
  "MerchantFrame", "PetStableFrame", "QuestFrame", "TabardFrame", "WardrobeFrame"}
local function shown(name) local frame = _G[name]; return frame and frame.IsShown and frame:IsShown() end
local ATOMS = {
  resting = {label = "in a rest area", events = {"PLAYER_UPDATE_RESTING"}, test = function() return IsResting() end},
  indoors = {label = "indoors", events = ZONE_EVENTS, test = function() return IsIndoors() end},
  outdoors = {label = "outdoors", events = ZONE_EVENTS, test = function() return IsOutdoors() end},
  instance = {label = "in an instance", events = {"ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD"}, parse = function(text) return text ~= "" and idSet(text) or nil end,
    test = function(kinds) local inside, kind = IsInInstance(); return inside and (not kinds or kinds[kind] == true) end},
  combat = {label = "in combat", events = {"PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED"}, test = function() return UnitAffectingCombat("player") end},
  encounter = {label = "boss encounter", events = {"ENCOUNTER_START", "ENCOUNTER_END", "INSTANCE_ENCOUNTER_ENGAGE_UNIT"},
    test = function() return IsEncounterInProgress() end},
  mounted = {label = "mounted", events = {"PLAYER_MOUNT_DISPLAY_CHANGED", "UNIT_AURA"}, test = function() return IsMounted() end},
  taxi = {label = "on a taxi", events = {"PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED"}, test = function() return UnitOnTaxi("player") end},
  afk = {label = "AFK", events = {"PLAYER_FLAGS_CHANGED"}, test = function() return UnitIsAFK("player") end},
  -- No event reports entering water: checked once a second while a situation uses it.
  swimming = {label = "swimming", events = {"UNIT_AURA"}, poll = true, test = function() return IsSwimming() end},
  form = {label = "shapeshift form", events = {"UPDATE_SHAPESHIFT_FORM"}, parse = idSet,
    test = function(forms) local form = GetShapeshiftFormID(); return form ~= nil and forms[form] == true end},
  aura = {label = "has aura", events = {"UNIT_AURA"}, parse = idSet, test = function(ids)
    for id in pairs(ids) do if C_UnitAuras.GetPlayerAuraBySpellID(id) then return true end end
    return false
  end},
  channel = {label = "channelling", events = CAST_EVENTS, parse = idSet, test = function(ids)
    local name, _, _, _, _, _, _, id = UnitChannelInfo("player")
    return spellMatches(ids, name, id)
  end},
  cast = {label = "casting", events = CAST_EVENTS, parse = idSet, test = function(ids)
    local name, _, _, _, _, _, _, _, id = UnitCastingInfo("player")
    return spellMatches(ids, name, id)
  end},
  npc = {label = "NPC interaction", events = {"AUCTION_HOUSE_CLOSED", "AUCTION_HOUSE_SHOW", "BANKFRAME_CLOSED", "BANKFRAME_OPENED",
    "CLOSE_TABARD_FRAME", "GOSSIP_CLOSED", "GOSSIP_SHOW", "GUILD_REGISTRAR_CLOSED", "GUILD_REGISTRAR_SHOW", "MERCHANT_CLOSED",
    "MERCHANT_SHOW", "OPEN_TABARD_FRAME", "PET_STABLE_CLOSED", "PET_STABLE_SHOW", "PLAYER_INTERACTION_MANAGER_FRAME_HIDE",
    "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "PLAYER_TARGET_CHANGED", "QUEST_COMPLETE", "QUEST_DETAIL", "QUEST_FINISHED",
    "QUEST_GREETING", "QUEST_PROGRESS", "TRAINER_CLOSED", "TRAINER_SHOW"},
    test = function()
      if shown("FlightMapFrame") or not UnitExists("npc") then return false end
      for _, name in ipairs(NPC_FRAMES) do if shown(name) then return true end end
      return false
    end},
  mailbox = {label = "mailbox open", events = {"MAIL_SHOW", "MAIL_CLOSED", "GOSSIP_CLOSED", "PLAYER_INTERACTION_MANAGER_FRAME_SHOW",
    "PLAYER_INTERACTION_MANAGER_FRAME_HIDE"}, test = function() return shown("MailFrame") end},
  professions = {label = "professions window open", events = {"TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE"},
    test = function() return shown("ProfessionsFrame") or shown("TradeSkillFrame") end},
  target = {label = "target is", events = {"PLAYER_TARGET_CHANGED"}, test = function(kind)
    if not UnitExists("target") then return false end
    if kind == "enemy" then return UnitCanAttack("player", "target") end
    if kind == "friendly" then return not UnitCanAttack("player", "target") end
    return true
  end},
}
Camera.ATOMS = ATOMS

-- DynamicCam's built-in situations that can occur on this client. The spell
-- lists of 200 and 320 are trimmed to the original-era spell ids.
local party = "instance:party,scenario"
local BUILTIN = {
  ["001"] = {"City", 1, {"resting"}},
  ["002"] = {"City (Indoors)", 11, {"resting", "indoors"}},
  ["004"] = {"World", 0, {"!resting", "!instance"}},
  ["005"] = {"World (Indoors)", 10, {"!resting", "!instance", "indoors"}},
  ["006"] = {"World (Combat)", 50, {"!instance", "combat"}},
  ["020"] = {"Dungeon/Scenario", 2, {party}},
  ["021"] = {"Dungeon/Scenario (Outdoors)", 12, {party, "outdoors"}},
  ["023"] = {"Dungeon/Scenario (Combat, Boss)", 302, {party, "combat", "encounter"}},
  ["024"] = {"Dungeon/Scenario (Combat, Trash)", 202, {party, "combat", "!encounter"}},
  ["030"] = {"Raid", 3, {"instance:raid"}},
  ["031"] = {"Raid (Outdoors)", 13, {"instance:raid", "outdoors"}},
  ["033"] = {"Raid (Combat, Boss)", 303, {"instance:raid", "combat", "encounter"}},
  ["034"] = {"Raid (Combat, Trash)", 203, {"instance:raid", "combat", "!encounter"}},
  ["050"] = {"Arena", 3, {"instance:arena"}},
  ["051"] = {"Arena (Combat)", 203, {"instance:arena", "combat"}},
  ["060"] = {"Battleground", 3, {"instance:pvp"}},
  ["061"] = {"Battleground (Combat)", 203, {"instance:pvp", "combat"}},
  ["100"] = {"Mounted (any)", 100, {"mounted", "!taxi"}},
  ["112"] = {"Shaman Ghost Wolf", 100, {"form:16,48"}},
  ["115"] = {"Druid Travel Form", 100, {"form:3,4,27,29"}},
  ["160"] = {"Taxi", 1000, {"taxi"}},
  ["200"] = {"Hearth/Teleport", 130, {"cast:556,3561,3562,3563,3565,3566,3567,8690,18960,23442,23453"}},
  ["201"] = {"Annoying Spells", 1000, {"aura:46924,51690,188499,210152"}},
  ["300"] = {"NPC Interaction", 110, {"npc"}},
  ["301"] = {"Mailbox", 110, {"mailbox"}},
  ["302"] = {"Fishing", 20, {"channel:7620"}, 1},
  ["303"] = {"AFK", 120, {"afk"}},
  ["320"] = {"Gathering", 120, {"cast:2575,2576,3564,10248,29354,50310,8613,8617,8618,10768,32678,50305,2366,2368,3570,11993,28695,50300"}},
  ["323"] = {"Swimming", 105, {"swimming"}},
  ["325"] = {"Camping", 40, {"aura:1229739"}, 6},
  ["330"] = {"Professions Frame Open", 1100, {"professions"}},
}

-- The author's settings, in DynamicCam's saved-profile shape so that shipped
-- defaults and an imported profile go through the same builder.
local function flat(...)
  local points, values = {}, {...}
  for i = 1, #values, 2 do points[#points + 1] = {zoom = values[i], value = values[i + 1]} end
  return points
end
local instant = {timeToEnter = 0, timeToExit = 0}
local SHIPPED = {
  zoomRestoreSetting = "never",
  standardSettings = {
    reactiveZoomAddIncrements = 0, reactiveZoomIncAddDifference = 2.5, reactiveZoomMaxZoomTime = 0.75,
    cvars = {
      cameraDistanceMaxZoomFactor = 1.6666666666667, cameraFov = 80, cameraPitchMoveSpeed = 25, cameraYawMoveSpeed = 50,
      cameraZoomSpeed = 1, test_cameraOverShoulder = 1.2,
      test_cameraDynamicPitch = 0,                      -- aim stability: off unless turned on in the options
      test_cameraDynamicPitchBaseFovPad = 0.2, test_cameraDynamicPitchBaseFovPadDownScale = 0,
      test_cameraDynamicPitchBaseFovPadFlying = 1, test_cameraDynamicPitchSmartPivotCutoffDist = 20,
      test_cameraHeadMovementStrength = 1, test_cameraHeadMovementStandingStrength = 2,
      test_cameraHeadMovementStandingDampRate = 25.01, test_cameraHeadMovementMovingStrength = 2,
      test_cameraHeadMovementMovingDampRate = 10.01, test_cameraHeadMovementRangeScale = 50,
      test_cameraHeadMovementDeadZone = 0.5,
      test_cameraTargetFocusEnemyEnable = 0, test_cameraTargetFocusEnemyStrengthYaw = 1,
      test_cameraTargetFocusEnemyStrengthPitch = 1,
      test_cameraTargetFocusInteractEnable = 0, test_cameraTargetFocusInteractStrengthPitch = 1,
      -- Not listed: InteractStrengthYaw and FirstPersonDampRate use the client default.
    },
    cvarsZoomBased = {
      test_cameraOverShoulder = {enabled = true, points = flat(0, 0.75, 5, 1.2, 15, 1.6, 25, 1.8)},
      cameraFov = {enabled = true, points = flat(0, 80, 5, 80, 15, 75, 25, 70)},
      test_cameraDynamicPitchBaseFovPad = {enabled = true, points = flat(0, 0.25, 39, 0.6)},
      test_cameraDynamicPitchBaseFovPadDownScale = {enabled = false, points = flat(0, 0, 39, 1)},
    },
  },
  situations = {
    ["006"] = {enabled = true, transitionTime = instant},
    ["023"] = {enabled = true, transitionTime = instant},
    ["033"] = {enabled = true, transitionTime = instant},
    ["060"] = {enabled = true, transitionTime = instant},
    ["100"] = {enabled = true, transitionTime = instant, situationSettings = {cvars = {test_cameraHeadMovementStrength = 1}}},
    ["302"] = {enabled = true, transitionTime = instant},
    ["303"] = {condition = "\n", priority = 0, transitionTime = instant},
  },
}

local function copy(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, child in pairs(value) do result[key] = copy(child) end
  return result
end
local function clear(t) for key in pairs(t) do t[key] = nil end end
local function pick(value, fallback) if value == nil then return fallback end return value end
local function byZoom(a, b) return a.zoom < b.zoom end

-- Copy a curve. DynamicCam closes every curve with a point at its maximum
-- distance; where that only repeats the previous value, clamping already does it.
local function importCurve(points)
  local result = {}
  for _, point in ipairs(points or {}) do
    if tonumber(point.zoom) and tonumber(point.value) then result[#result + 1] = {zoom = tonumber(point.zoom), value = tonumber(point.value)} end
  end
  table.sort(result, byZoom)
  if #result > 2 and result[#result].zoom >= 39 and result[#result].value == result[#result - 1].value then result[#result] = nil end
  return result
end
local function importSettings(target, source)
  for name, value in pairs(source and source.cvars or {}) do
    if DEF[name] and tonumber(value) then target[name] = target[name] or {}; target[name].value = tonumber(value) end
  end
  for name, data in pairs(source and source.cvarsZoomBased or {}) do
    if DEF[name] and DEF[name].min and type(data) == "table" then
      target[name] = target[name] or {}
      target[name].curve, target[name].curveOn = importCurve(data.points), data.enabled and true or false
    end
  end
end
local ZOOM_KEYS = {reactive = "reactiveZoomEnabled", addAlways = "reactiveZoomAddIncrementsAlways", addIncrements = "reactiveZoomAddIncrements",
  incAddDifference = "reactiveZoomIncAddDifference", maxZoomTime = "reactiveZoomMaxZoomTime", easing = "reactiveZoomEasingFunc"}

-- profile: a DynamicCam profile table (possibly with its defaults stripped).
-- defaults: DynamicCam's live default profile when it is loaded, to tell an
-- unmodified built-in condition from an edited one.
local function build(profile, defaults)
  local standard, saved = {}, profile.standardSettings or {}
  for _, def in ipairs(SETTINGS) do
    -- Absent from a stripped profile means DynamicCam's default: the client default.
    standard[def.name] = {value = GetCVarDefault and tonumber(GetCVarDefault(def.name)) or nil}
  end
  importSettings(standard, saved)
  local cfg = {enabled = true, standard = standard, situations = {},
    zoom = {reactive = saved.reactiveZoomEnabled ~= false, addAlways = pick(saved.reactiveZoomAddIncrementsAlways, 1),
      addIncrements = pick(saved.reactiveZoomAddIncrements, 2.5), incAddDifference = pick(saved.reactiveZoomIncAddDifference, 1.2),
      maxZoomTime = pick(saved.reactiveZoomMaxZoomTime, 0.1), easing = saved.reactiveZoomEasingFunc or "OutQuad",
      restore = profile.zoomRestoreSetting or "adaptive", transitionEasing = "InOutQuad"}}
  local ids, seen = {}, {}
  for id in pairs(BUILTIN) do ids[#ids + 1] = id; seen[id] = true end
  for id in pairs(profile.situations or {}) do if not seen[id] then ids[#ids + 1] = tostring(id) end end
  table.sort(ids)
  local defaultSituations = defaults and defaults.situations or {}
  for _, id in ipairs(ids) do
    local s, base, original = profile.situations and profile.situations[id] or {}, BUILTIN[id], defaultSituations[id]
    local time, zoom, rotation, hide = s.transitionTime or {}, s.viewZoom or {}, s.rotation or {}, s.hideUI or {}
    local situation = {id = id, name = s.name or base and base[1] or id, enabled = s.enabled and true or false,
      priority = tonumber(s.priority) or base and base[2] or 0, delay = tonumber(s.delay) or base and base[4] or 0,
      enter = pick(tonumber(time.timeToEnter), 1), exit = pick(tonumber(time.timeToExit), 1),
      zoom = {enabled = zoom.enabled and true or false, mode = zoom.viewZoomType or "zoom", type = zoom.zoomType or "set",
        value = pick(zoom.zoomValue, 10), min = pick(zoom.zoomMin, 5), max = pick(zoom.zoomMax, 15),
        timeIsMax = zoom.zoomTimeIsMax and true or false, view = pick(zoom.viewNumber, 2), viewRestore = zoom.viewRestore ~= false,
        viewInstant = zoom.viewInstant and true or false, restoreView = pick(zoom.restoreDefaultViewNumber, 1)},
      rotation = {enabled = rotation.enabled and true or false, type = rotation.rotationType or "continuous",
        speed = pick(rotation.rotationSpeed, 10), yaw = pick(rotation.yawDegrees, 0), pitch = pick(rotation.pitchDegrees, 0),
        back = rotation.rotateBack ~= false},
      hideUI = copy(hide), overrides = {}, zoomSettings = {}}
    situation.hideUI.enabled = hide.enabled and true or false
    situation.hideUI.fadeOpacity = pick(hide.fadeOpacity, 0.6)
    -- A condition equal to DynamicCam's own is the built-in; anything else is
    -- kept as text and never executed.
    local edited = type(s.condition) == "string" and not (original and original.condition == s.condition)
    if base and not edited then situation.condition = copy(base[3])
    else situation.source = {condition = s.condition or original and original.condition,
      executeOnInit = s.executeOnInit, executeOnEnter = s.executeOnEnter, executeOnExit = s.executeOnExit} end
    importSettings(situation.overrides, s.situationSettings)
    for key, name in pairs(ZOOM_KEYS) do
      local value = s.situationSettings and s.situationSettings[name]
      if value ~= nil then situation.zoomSettings[key] = value end
    end
    cfg.situations[#cfg.situations + 1] = situation
  end
  return cfg
end
function Camera:ShippedDefaults() return build(SHIPPED) end

-- The DynamicCam profile in use: the live addon's when it is loaded, else the
-- saved one for this character. Read only.
function Camera:BuildFromDynamicCam(db, profileName)
  local live = _G.DynamicCam
  local profile, defaults
  if not profileName and live and live.db and live.db.profile and live.db.GetCurrentProfile then
    profile, profileName = live.db.profile, live.db:GetCurrentProfile()
    defaults = live.defaults and live.defaults.profile
  elseif type(db) == "table" and type(db.profiles) == "table" then
    if not profileName and UnitName and GetRealmName then
      profileName = db.profileKeys and db.profileKeys[UnitName("player") .. " - " .. GetRealmName()]
    end
    profile = profileName and db.profiles[profileName]
  end
  if type(profile) ~= "table" then return nil end
  local cfg = build(profile, defaults)
  local custom = 0
  for _, situation in ipairs(cfg.situations) do if not situation.condition then custom = custom + 1 end end
  cfg.receipt = {source = "DynamicCam", profile = profileName, version = profile.version, time = date and date("%Y-%m-%d %H:%M") or nil,
    situations = #cfg.situations, custom = custom}
  return cfg
end

-- ---------------------------------------------------------------------------
-- CVar writes
-- ---------------------------------------------------------------------------
local cfg                         -- SquanchOnDB.camera
local errors = 0
local restricted, deferred = {}, {}
local events = CreateFrame("Frame")
local speedsHeld

local function setCVar(name, value)
  -- Core.lua borrows the two turn speeds for one frame during cursor return.
  if speedsHeld and (name == YAW or name == PITCH) then return false end
  local text = tostring(value)
  if GetCVar(name) == text then deferred[name] = nil; return true end
  local combat = InCombatLockdown and InCombatLockdown()
  if not (combat and restricted[name]) then
    local ok, result = pcall(SetCVar, name, text)
    if ok and result ~= false then deferred[name] = nil; return true end
    if not combat then errors = errors + 1; return false end
    -- Refused in combat: remember the CVar and write it when combat ends.
    restricted[name] = true
    if cfg then cfg.combatDeferred = cfg.combatDeferred or {}; cfg.combatDeferred[name] = true end
  end
  deferred[name] = text
  events:RegisterEvent("PLAYER_REGEN_ENABLED")
  return false
end

-- ---------------------------------------------------------------------------
-- Effective values: situation curve > situation value > standard curve > standard value
-- ---------------------------------------------------------------------------
local current                     -- active situation table or nil
local segment = {}
local fovMin, fovMax = 60, 90

local function hasCurve(entry) return entry and entry.curveOn and entry.curve and #entry.curve >= 2 end
local function entryFor(name)
  local override = current and current.overrides[name]
  if override then
    if hasCurve(override) then return override, true end
    if override.value ~= nil then return override, false end
  end
  local entry = cfg.standard[name]
  return entry, hasCurve(entry)
end
local function curveValue(name, points, zoom)
  local n = #points
  if zoom <= points[1].zoom then return points[1].value end
  if zoom >= points[n].zoom then return points[n].value end
  local i = segment[name]
  if not (i and i < n and points[i].zoom <= zoom and zoom <= points[i + 1].zoom) then
    i = 1
    while points[i + 1].zoom < zoom do i = i + 1 end
    segment[name] = i
  end
  local a, b = points[i], points[i + 1]
  if b.zoom == a.zoom then return b.value end
  return a.value + (zoom - a.zoom) / (b.zoom - a.zoom) * (b.value - a.value)
end
local function resolve(name, zoom)
  local entry, curved = entryFor(name)
  local def, value = DEF[name], nil
  if curved then
    value = curveValue(name, entry.curve, zoom)
    local low, high = def.min, def.max
    if name == "cameraFov" then low, high = fovMin, fovMax end
    value = max(low, min(high, value))
  else
    value = entry and entry.value
    if value ~= nil and def.clampFixed then value = max(fovMin, min(fovMax, value)) end
  end
  if value ~= nil and def.floor and value < def.floor then value = def.floor end
  return value
end
Camera.Resolve = resolve
function Camera:SetConfig(config) cfg = config end     -- offline checks only

local trans, pendingToggle = {}, {}
local transFn, transStart, transDur
local dynamic, lastValue = {}, {}

-- Which settings follow the zoom right now.
local function rebuild()
  clear(dynamic); clear(lastValue); clear(segment)
  for _, def in ipairs(SETTINGS) do
    local _, curved = entryFor(def.name)
    -- As in DynamicCam, a curve is left alone while its master toggle is off.
    def.suspended = curved and def.parent ~= nil and (resolve(def.parent, 0) or 0) == 0
    def.dynamic = curved and not def.suspended
    if def.dynamic then dynamic[#dynamic + 1] = def end
  end
end
local function applyZoom(zoom, force)
  for i = 1, #dynamic do
    local def = dynamic[i]
    local name = def.name
    if not trans[name] then
      local value = resolve(name, zoom)
      if force or abs(value - (lastValue[name] or huge)) >= (def.max - def.min) * 0.00001 then
        lastValue[name] = value
        setCVar(name, value)
      end
    end
  end
end

-- Native functions captured before any hook, so the driver never wakes itself.
local nativeZoomIn, nativeZoomOut = CameraZoomIn, CameraZoomOut
local moveIn, moveOut, stopIn, stopOut = MoveViewInStart, MoveViewOutStart, MoveViewInStop, MoveViewOutStop
local function maxDistance() return (tonumber(GetCVar("cameraDistanceMaxZoomFactor")) or 1) * 15 end
local function nudge(distance)
  if distance > 0.01 then nativeZoomOut(distance) elseif distance < -0.01 then nativeZoomIn(-distance) end
end

local function applyStatic()
  for _, def in ipairs(SETTINGS) do
    local name = def.name
    if not (def.dynamic or def.suspended or trans[name] or pendingToggle[name] ~= nil) then
      local value = resolve(name, 0)
      if value ~= nil then setCVar(name, value) end
    end
  end
  local shoulder = DEF.test_cameraOverShoulder.dynamic or (resolve("test_cameraOverShoulder", 0) or 0) ~= 0
  if shoulder or resolve("test_cameraDynamicPitch", 0) == 1 then setCVar(COMPANIONS[1], 0) end
  if shoulder then setCVar(COMPANIONS[2], 0) end
  local zoom = GetCameraZoom()
  applyZoom(zoom, true)
  nudge(min(0, maxDistance() - zoom))       -- a lowered maximum takes effect at once
end

-- ---------------------------------------------------------------------------
-- Driver: awake only while the zoom moves or something is animating
-- ---------------------------------------------------------------------------
local driver = CreateFrame("Frame")
driver:Hide()                     -- a hidden frame receives no OnUpdate
function Camera:Wake()
  if self.active then self.quiet = 0; driver:Show() end
end

-- Zoom easing: each frame steer toward where the curve will be one frame on.
local ease
local function haltZoom() moveOut(0); moveIn(0); stopIn(); stopOut() end
local function stopEase()
  if ease then ease = nil; haltZoom() end
end
local function startEase(target, duration, easing, wheel)
  local zoom = GetCameraZoom()
  local sign = target >= zoom and 1 or -1
  -- Re-aiming an ease that already travels this way must not halt the camera:
  -- stopping and restarting on every wheel notch is felt as a stutter.
  if not (ease and ease.direction == sign) then stopEase() end
  if duration < 0.03 then stopEase(); nudge(target - zoom); Camera:Wake(); return end
  ease = {from = zoom, to = target, start = GetTime(), dur = duration, fn = EASE[easing] or EASE.Linear, wheel = wheel,
    sign = sign, direction = ease and ease.direction or nil,
    speed = max(0.01, tonumber(GetCVar("cameraZoomSpeed")) or 1)}
  Camera:Wake()
end
-- An ease only ever moves toward its target. Overshoot (the client clamps at
-- first person and at maximum distance, and frame times vary) is never
-- corrected by driving backward: that reversal is the visible "bump back".
local function stepEase(zoom, elapsed)
  local e = ease
  if not e then return false end
  local t = GetTime() - e.start
  local remaining = (e.to - zoom) * e.sign
  if t >= e.dur or remaining <= 0.02 then
    ease = nil
    haltZoom()
    -- Finish only forward, and only a meaningful shortfall; never pull back.
    if remaining > 0.05 then nudge(e.to - zoom) end
    return false
  end
  local ahead = max(elapsed, 0.005)
  local goal = e.from + (e.to - e.from) * e.fn(min(1, (t + ahead) / e.dur))
  local speed = max(0, (goal - zoom) * e.sign) / ahead / e.speed
  if e.sign == 1 then
    if e.direction == -1 then moveIn(0); stopIn() end
    e.direction = 1; moveOut(speed)
  else
    if e.direction == 1 then moveOut(0); stopOut() end
    e.direction = -1; moveIn(speed)
  end
  return true
end

-- Setting transitions between situations.
local function flushTransition()
  transFn = nil
  clear(trans)
  for name, value in pairs(pendingToggle) do pendingToggle[name] = nil; setCVar(name, value) end
end
local function beginTransition(duration, targetZoom)
  flushTransition()
  if duration <= 0 then return end
  local handled = {}
  for _, def in ipairs(SETTINGS) do
    if def.children then
      local now, target = tonumber(GetCVar(def.name)) or 0, resolve(def.name, targetZoom)
      local on, willBe = abs(now) > 0.0001, target ~= nil and abs(target) > 0.0001
      if target ~= nil and on ~= willBe then
        handled[def.name] = true
        if on then pendingToggle[def.name] = target else setCVar(def.name, target) end
        for _, child in ipairs(def.children) do
          handled[child] = true
          if on then
            local strength = tonumber(GetCVar(child)) or 0
            if abs(strength) > 0.0001 then trans[child] = {from = strength, to = 0} end
          elseif abs(resolve(child, targetZoom) or 0) > 0.0001 then
            setCVar(child, 0)
            trans[child] = {from = 0}
          end
        end
      end
    end
  end
  for _, def in ipairs(SETTINGS) do
    local name = def.name
    local target = resolve(name, targetZoom)
    if handled[name] or target == nil or def.suspended then
    elseif def.switch or def.instant then setCVar(name, target)
    else
      local now = tonumber(GetCVar(name)) or 0
      if def.dynamic or abs(now - target) > 0.0001 then trans[name] = {from = now} end
    end
  end
  if next(trans) or next(pendingToggle) then
    transFn, transStart, transDur = EASE[cfg.zoom.transitionEasing] or EASE.InOutQuad, GetTime(), duration
    Camera:Wake()
  end
end
local function stepTransition(zoom)
  if not transFn then return false end
  local t = (GetTime() - transStart) / transDur
  if t >= 1 then flushTransition(); applyStatic(); return false end
  local blend = transFn(t)
  for name, item in pairs(trans) do
    local target = item.to or resolve(name, zoom)
    if target then setCVar(name, item.from + (target - item.from) * blend) end
  end
  return true
end

-- Rotation. The client reports no camera angle, so turns are tracked by the
-- commanded speed over time.
local AXIS = {
  yaw = {MoveViewRightStart, MoveViewLeftStart, MoveViewRightStop, MoveViewLeftStop, YAW},
  pitch = {MoveViewUpStart, MoveViewDownStart, MoveViewUpStop, MoveViewDownStop, PITCH},
}
local turns, turned = {}, {yaw = 0, pitch = 0}
local function drive(axis, speed)       -- degrees per second; 0 stops
  local a = AXIS[axis]
  if speed == 0 then a[3](); a[4](); return end
  local scale = tonumber(GetCVar(a[5])) or 1
  if scale <= 0 then scale = 1 end
  if speed > 0 then a[4](); a[1](speed / scale) else a[3](); a[2](-speed / scale) end
end
local function account(job)
  local now = GetTime()
  job.done, job.stamp = job.done + job.last * (now - job.stamp), now
end
local function addTurn(axis, degrees, duration, continuousSpeed)
  local now = GetTime()
  turns[#turns + 1] = {axis = axis, total = degrees, speed = continuousSpeed, start = now, stamp = now,
    dur = max(duration or 0, 0.1), done = 0, last = 0}
  Camera:Wake()
end
local function stepTurns(elapsed)
  local busy = false
  for i = #turns, 1, -1 do
    local job = turns[i]
    account(job)
    local t = (job.stamp - job.start) / job.dur
    if job.total then
      if t >= 1 then
        drive(job.axis, 0)
        turned[job.axis] = turned[job.axis] + job.done
        table.remove(turns, i)
      else
        local ahead = max(elapsed, 0.005)
        job.last = (job.total * EASE.InOutQuad(min(1, t + ahead / job.dur)) - job.done) / ahead
        drive(job.axis, job.last)
        busy = true
      end
    elseif t < 1 then
      job.last = job.speed * t
      drive(job.axis, job.last)
      busy = true
    elseif job.last ~= job.speed then
      job.last = job.speed
      drive(job.axis, job.last)
    end
  end
  return busy
end
local function cancelTurns()
  for i = #turns, 1, -1 do
    local job = turns[i]
    account(job)
    drive(job.axis, 0)
    turned[job.axis] = turned[job.axis] + job.done
    turns[i] = nil
  end
end
local function startRotation(situation, duration)
  local r = situation.rotation
  turned.yaw, turned.pitch = 0, 0
  if not r.enabled then return end
  if r.type == "continuous" then addTurn("yaw", nil, duration, r.speed)
  else
    if r.yaw ~= 0 then addTurn("yaw", r.yaw, duration) end
    if r.pitch ~= 0 then addTurn("pitch", r.pitch, duration) end
  end
end
local function stopRotation(situation, duration)
  local r = situation.rotation
  if not r.enabled then return end
  cancelTurns()
  local yaw, pitch = turned.yaw, turned.pitch
  turned.yaw, turned.pitch = 0, 0
  if not r.back then return end
  if r.type == "continuous" then
    yaw, pitch = yaw % 360, 0
    if yaw > 180 then yaw = yaw - 360 end
  end
  if abs(yaw) > 0.1 then addTurn("yaw", -yaw, duration) end
  if abs(pitch) > 0.1 then addTurn("pitch", -pitch, duration) end
end

-- Hide UI: fades the whole interface. DynamicCam's per-frame keep list is kept
-- as data only.
local fade, faded
local function fadeUI(alpha, duration)
  if alpha >= 1 and not faded then return end
  faded = alpha < 1
  if duration <= 0 then fade = nil; UIParent:SetAlpha(alpha); return end
  fade = {from = UIParent:GetAlpha(), to = alpha, start = GetTime(), dur = duration}
  Camera:Wake()
end
local function stepFade()
  if not fade then return false end
  local t = (GetTime() - fade.start) / fade.dur
  if t >= 1 then UIParent:SetAlpha(fade.to); fade = nil; return false end
  UIParent:SetAlpha(fade.from + (fade.to - fade.from) * t)
  return true
end

local lastZoom
driver:SetScript("OnUpdate", function(self, elapsed)
  local zoom = GetCameraZoom()
  local busy = stepEase(zoom, elapsed)
  if stepTransition(zoom) then busy = true end
  if stepTurns(elapsed) then busy = true end
  if stepFade() then busy = true end
  if zoom ~= lastZoom then
    lastZoom, Camera.quiet = zoom, 0
    applyZoom(zoom)
  elseif busy then Camera.quiet = 0
  else
    Camera.quiet = Camera.quiet + elapsed
    if Camera.quiet > 0.5 then
      applyZoom(zoom, true)       -- land on the exact curve values before sleeping
      self:Hide()
    end
  end
end)

-- ---------------------------------------------------------------------------
-- Wheel zoom
-- ---------------------------------------------------------------------------
local function zoomSetting(key)
  local value = current and current.zoomSettings[key]
  if value == nil then value = cfg.zoom[key] end
  return value
end
local function wheel(zoomIn, increments)
  if increments == 0 then return end          -- the client's empty in/out echo
  increments = increments or 1
  local native = zoomIn and nativeZoomIn or nativeZoomOut
  if not Camera.active then return native(increments) end
  if not zoomSetting("reactive") or increments ~= 1 then
    stopEase()
    Camera:Wake()
    return native(increments + (zoomSetting("reactive") and 0 or zoomSetting("addAlways")))
  end
  local zoom = GetCameraZoom()
  local target = ease and ease.wheel and ease.to or nil
  local step = 1 + zoomSetting("addAlways")
  if target and abs(target - zoom) > zoomSetting("incAddDifference") then step = step + zoomSetting("addIncrements") end
  if target and ((zoomIn and target > zoom) or (not zoomIn and target < zoom)) then target = nil end
  target = target or zoom
  -- At a limit there is nothing to ease toward; drop any pending ease so the
  -- camera does not keep pushing against first person or maximum distance.
  if (zoomIn and zoom <= 0.01) or (not zoomIn and zoom >= maxDistance() - 0.01) then
    if ease and ease.wheel then stopEase() end
    if zoomIn or zoom > 0 then return end
  end
  if zoomIn then target = max(0, target - step)
  elseif zoom == 0 then                       -- first person -> nearest third person
    stopEase()
    Camera:Wake()
    return native(0.05)
  else target = min(maxDistance(), target + step) end
  if abs(target - zoom) < 0.01 then return end
  local speed = max(0.01, tonumber(GetCVar("cameraZoomSpeed")) or 1)
  startEase(target, min(zoomSetting("maxZoomTime"), abs(target - zoom) / speed), zoomSetting("easing"), true)
end
local function zoomInHook(increments) wheel(true, increments) end
local function zoomOutHook(increments) wheel(false, increments) end

-- ---------------------------------------------------------------------------
-- Situations
-- ---------------------------------------------------------------------------
local compiled = {}
local lastSituationZoom, cameFrom = {}, {}
local entered, delayUntil, queued
local sitEvents = CreateFrame("Frame")

local function gotoView(view, viewInstant)
  if not view then return end
  stopEase(); cancelTurns()
  if viewInstant then SetView(view) end
  SetView(view)
end
local function shouldRestoreZoom(old, new)
  local mode = cfg.zoom.restore
  if mode == "never" then return false end
  if not new then return lastSituationZoom.none ~= nil, lastSituationZoom.none end
  local restore = lastSituationZoom[new]
  local z = new.zoom
  if not restore or (z.enabled and z.mode == "view") then return false end
  if mode == "always" then return true, restore end
  if old and cameFrom[old] ~= new then return false end
  if not z.enabled or z.mode ~= "zoom" or z.type == "set" then return false end
  if z.type == "range" then return z.min <= restore + 0.5 and z.max >= restore - 0.5, restore end
  local zoom = GetCameraZoom()
  if z.type == "in" then return z.value >= restore - 0.5 and zoom > restore, restore end
  return z.value <= restore + 0.5 and zoom < restore, restore
end

local function change(old, new)
  local zoom = GetCameraZoom()
  stopEase()
  local settingView, viewInstant = false, false
  if old then
    lastSituationZoom[old] = zoom
    local duration = new and new.enter or old.exit
    stopRotation(old, duration)
    local z = old.zoom
    if z.enabled and z.mode == "view" and not (new and new.zoom.enabled and new.zoom.mode == "view") then
      if GetCVar("cameraSmoothStyle") == "0" then
        if z.viewRestore then gotoView(1, z.viewInstant); settingView, viewInstant = true, z.viewInstant end
      elseif z.restoreView then
        ResetView(z.restoreView)
        gotoView(z.restoreView, z.viewInstant)
        settingView, viewInstant = true, z.viewInstant
      end
    end
    if old.hideUI.enabled then fadeUI(1, duration) end
  elseif entered then lastSituationZoom.none = zoom end
  if new then
    cameFrom[new] = old
    local z = new.zoom
    if z.enabled and z.mode == "view" then
      if z.viewRestore then SaveView(1) end
      gotoView(z.view, z.viewInstant)
      settingView, viewInstant = true, z.viewInstant
    end
    if new.hideUI.enabled then fadeUI(new.hideUI.fadeOpacity, new.enter) end
  end

  local target, restoring = zoom, false
  if not settingView then
    local restore
    restoring, restore = shouldRestoreZoom(old, new)
    if restoring then target = restore
    elseif new and new.zoom.enabled and new.zoom.mode == "zoom" then
      local z = new.zoom
      if z.type == "set" or (z.type == "in" and zoom > z.value) or (z.type == "out" and zoom < z.value) then target = z.value
      elseif z.type == "range" then target = max(z.min, min(z.max, zoom)) end
    end
  end
  local duration
  if not entered then duration = 0
  elseif restoring and old then duration = old.exit
  elseif settingView then duration = viewInstant and 0 or 0.5
  elseif new then duration = new.enter
  else duration = old and old.exit or 0 end

  current = new
  rebuild()
  local zoomTime = duration
  if new and duration > 0 and new.zoom.enabled and new.zoom.mode == "zoom" and new.zoom.timeIsMax then
    local distance, speed = abs(target - zoom), resolve("cameraZoomSpeed", 0) or 1
    if distance / duration < speed then zoomTime = max(0.1, distance / speed) end
  end
  beginTransition(duration, target)
  applyStatic()
  if not settingView and abs(target - zoom) > 0.01 then
    startEase(max(0, min(maxDistance(), target)), zoomTime, cfg.zoom.transitionEasing)
  end
  if new then startRotation(new, duration) end
  lastZoom = nil
  Camera:Wake()
end

local queueEvaluate
local function holds(situation)
  local list = compiled[situation]
  if not list then return false end
  for i = 1, #list do
    local atom = list[i]
    local ok, result = pcall(atom.test, atom.arg)
    result = ok and result and not secret(result) and true or false
    if result == atom.negate then return false end
  end
  return true
end
local function evaluate()
  local top, best = nil, -huge
  for _, situation in ipairs(cfg.situations) do
    if situation.enabled and holds(situation) and situation.priority > best then top, best = situation, situation.priority end
  end
  if current and top ~= current and current.delay > 0 then
    local now = GetTime()
    if not delayUntil then
      delayUntil = now + current.delay
      C_Timer.After(current.delay, queueEvaluate)
      return
    elseif now < delayUntil - 0.001 then return end
  end
  delayUntil = nil
  if top ~= current then change(current, top) end
  entered = true
end
queueEvaluate = function()
  if queued then return end
  queued = true
  C_Timer.After(0, function()
    queued = false
    if Camera.active then evaluate() end
  end)
end
sitEvents:SetScript("OnEvent", queueEvaluate)

local ticker
local function compile()
  sitEvents:UnregisterAllEvents()
  clear(compiled)
  if ticker then ticker:Cancel(); ticker = nil end
  for _, situation in ipairs(cfg.situations) do
    local list = situation.enabled and situation.condition and {} or nil
    for _, text in ipairs(list and situation.condition or {}) do
      local negate, name, argument = tostring(text):match("^(!?)(%a+):?(.*)$")
      local atom = ATOMS[name or ""]
      if not atom then list = nil; break end
      local arg = argument
      if atom.parse then arg = atom.parse(argument) elseif argument == "" then arg = nil end
      list[#list + 1] = {test = atom.test, arg = arg, negate = negate == "!"}
    end
    if list then
      compiled[situation] = list
      for _, text in ipairs(situation.condition) do
        local atom = ATOMS[tostring(text):match("^!?(%a+)")]
        if atom.poll and not ticker then ticker = C_Timer.NewTicker(1, queueEvaluate) end
        for _, event in ipairs(atom.events) do
          if event:sub(1, 5) == "UNIT_" then pcall(sitEvents.RegisterUnitEvent, sitEvents, event, "player")
          else pcall(sitEvents.RegisterEvent, sitEvents, event) end
        end
      end
    end
  end
end
function Camera:SituationStatus(situation)
  if not situation.condition then return "custom (inactive)" end
  if situation == current then return "active now" end
  return situation.enabled and "" or "off"
end
function Camera:ConditionText(situation)
  if not situation.condition then return "custom condition kept as data; not run" end
  local parts = {}
  for _, text in ipairs(situation.condition) do
    local negate, name, argument = tostring(text):match("^(!?)(%a+):?(.*)$")
    local atom = ATOMS[name or ""]
    parts[#parts + 1] = (negate == "!" and "not " or "") .. (atom and atom.label or tostring(text)) .. (argument ~= "" and " " .. argument or "")
  end
  return table.concat(parts, ", ")
end

-- ---------------------------------------------------------------------------
-- Lifetime
-- ---------------------------------------------------------------------------
local function dynamicCamLoaded()
  return _G.DynamicCam ~= nil or (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("DynamicCam")) or false
end
-- The client asks to confirm "experimental" ActionCam CVars at login; DynamicCam
-- drops that event the same way.
local function suppressActionCamWarning()
  if GameEvent and GameEvent.UnregisterInternalEvent then pcall(GameEvent.UnregisterInternalEvent, POPUP) end
  pcall(UIParent.UnregisterEvent, UIParent, POPUP)
  if StaticPopup_Hide then
    StaticPopup_Hide(POPUP)
    C_Timer.After(0, function() StaticPopup_Hide(POPUP) end)
  end
end
-- Fill anything a saved or shipped table lacks; never merges curve points.
local shippedCache
local function normalize(config)
  shippedCache = shippedCache or build(SHIPPED)
  local shipped = shippedCache
  if config.enabled == nil then config.enabled = true end
  config.standard = type(config.standard) == "table" and config.standard or {}
  for name, entry in pairs(shipped.standard) do
    if type(config.standard[name]) ~= "table" then config.standard[name] = copy(entry) end
  end
  config.zoom = type(config.zoom) == "table" and config.zoom or {}
  for key, value in pairs(shipped.zoom) do if config.zoom[key] == nil then config.zoom[key] = value end end
  if type(config.situations) ~= "table" then config.situations = copy(shipped.situations) end
  local template = shipped.situations[1]
  for _, situation in ipairs(config.situations) do
    for key, value in pairs(template) do
      if key ~= "condition" and key ~= "source" and situation[key] == nil then situation[key] = copy(value) end
    end
    for _, key in ipairs({"zoom", "rotation", "hideUI"}) do
      for field, value in pairs(template[key]) do if situation[key][field] == nil then situation[key][field] = value end end
    end
  end
  for _, entry in pairs(config.standard) do if entry.curve then table.sort(entry.curve, byZoom) end end
  for _, situation in ipairs(config.situations) do
    for _, entry in pairs(situation.overrides) do if entry.curve then table.sort(entry.curve, byZoom) end end
  end
end

local hooked
function Camera:Enable()
  if self.active or not cfg or not cfg.enabled then return end
  if dynamicCamLoaded() then           -- one camera owner at a time
    if not self.blocked then
      print("Squanch-On camera: waiting, DynamicCam is loaded. /sqms camera takeover disables it (then /reload).")
    end
    self.blocked = true
    return
  end
  self.blocked = nil
  if not cfg.previous then             -- what to put back on restore
    cfg.previous = {}
    for _, def in ipairs(SETTINGS) do cfg.previous[def.name] = GetCVar(def.name) end
    for _, name in ipairs(COMPANIONS) do cfg.previous[name] = GetCVar(name) end
  end
  for _, def in ipairs(SETTINGS) do    -- "client default" settings become explicit once
    local entry = cfg.standard[def.name]
    if entry.value == nil then entry.value = tonumber(GetCVarDefault(def.name)) end
  end
  if GetCameraFOVDefaults then
    local _, low, high = GetCameraFOVDefaults()
    fovMin, fovMax = tonumber(low) or fovMin, tonumber(high) or fovMax
  end
  suppressActionCamWarning()
  CameraZoomIn, CameraZoomOut = zoomInHook, zoomOutHook
  if not hooked then
    hooked = true
    local wake = function() Camera:Wake() end
    for _, name in ipairs({"MoveViewInStart", "MoveViewOutStart", "SetView", "ResetView"}) do
      if _G[name] then hooksecurefunc(name, wake) end
    end
  end
  for _, event in ipairs({"PLAYER_ENTERING_WORLD", "PLAYER_MOUNT_DISPLAY_CHANGED", "UNIT_ENTERED_VEHICLE",
    "UNIT_EXITED_VEHICLE", "PLAYER_CONTROL_GAINED", "CINEMATIC_STOP"}) do
    pcall(events.RegisterEvent, events, event)
  end
  self.active = true
  current, entered, delayUntil, lastZoom = nil, false, nil, nil
  clear(lastSituationZoom); clear(cameFrom)
  self:SettingsChanged()
end
events:SetScript("OnEvent", function(self, event)
  if event == "PLAYER_REGEN_ENABLED" then
    self:UnregisterEvent(event)
    for name, text in pairs(deferred) do deferred[name] = nil; setCVar(name, text) end
    return
  end
  lastZoom = nil
  Camera:Wake()
end)

-- Call after any edit of the settings table.
function Camera:SettingsChanged()
  if not cfg then return end
  normalize(cfg)
  if not self.active then return end
  if current and not current.enabled then change(current, nil) end
  compile()
  rebuild()
  applyStatic()
  queueEvaluate()
  lastZoom = nil
  self:Wake()
end

function Camera:Disable(restore)
  if self.active then
    stopEase(); cancelTurns(); flushTransition()
    if faded then fadeUI(1, 0) end
    current = nil
    driver:Hide()
    events:UnregisterAllEvents(); sitEvents:UnregisterAllEvents()
    clear(deferred)
    if ticker then ticker:Cancel(); ticker = nil end
    if CameraZoomIn == zoomInHook then CameraZoomIn = nativeZoomIn end
    if CameraZoomOut == zoomOutHook then CameraZoomOut = nativeZoomOut end
    self.active = false
  end
  if restore and cfg and cfg.previous then
    for name, value in pairs(cfg.previous) do setCVar(name, value) end
    cfg.previous = nil
  end
end

-- Core.lua's cursor return sets both turn speeds to their minimum for one
-- frame; while it does, this module leaves them alone and afterwards makes
-- sure they hold the configured values.
function Camera:HoldSpeeds(held)
  speedsHeld = held and true or false
  if not speedsHeld and self.active then
    for _, name in ipairs({YAW, PITCH}) do
      if not trans[name] then
        local value = resolve(name, 0)
        if value ~= nil then setCVar(name, value) end
      end
    end
  end
end

function Camera:Config() return cfg end
function Camera:CurrentSituation() return current end
function Camera:IsAwake() return driver:IsShown() and true or false end

-- Called from Core.lua at PLAYER_LOGIN.
function addon:InitializeCamera()
  local db = self.db
  local existing = type(db.camera) == "table" and db.camera or nil
  if not (existing and existing.receipt) then
    -- Once: carry over the DynamicCam profile in use, if its saved variables are loaded.
    local imported = _G.DynamicCamDB and Camera:BuildFromDynamicCam(_G.DynamicCamDB)
    if imported then
      db.camera = imported
      print(("Squanch-On camera: imported DynamicCam profile \"%s\" (%d situations, %d with custom conditions kept inactive).")
        :format(tostring(imported.receipt.profile), imported.receipt.situations, imported.receipt.custom))
    else
      db.camera = existing or Camera:ShippedDefaults()
      db.camera.receipt = {source = "defaults", time = date("%Y-%m-%d %H:%M")}
    end
  end
  cfg = db.camera
  -- The retired DynamicCam profile helper's record: kept, no longer acted on.
  if db.cameraFraming then cfg.legacyFraming, db.cameraFraming = db.cameraFraming, nil end
  db.cameraFramingRequested, db.cameraFramingError = nil, nil
  normalize(cfg)
  -- The camera ignores CVars written during the first moments of a session.
  C_Timer.After(0.1, function() Camera:Enable() end)
end

-- Swap in a whole new settings table, keeping the takeover records.
local function replace(fresh)
  if Camera.active and current then change(current, nil) end
  flushTransition()
  fresh.previous, fresh.legacyFraming, fresh.enabled = cfg.previous, cfg.legacyFraming, cfg.enabled
  fresh.receipt = fresh.receipt or cfg.receipt
  addon.db.camera, cfg = fresh, fresh
  Camera:SettingsChanged()
end

-- With DynamicCam still loaded: take its selected profile again, and for
-- settings without a curve record what the client actually holds.
function Camera:Capture()
  local imported = _G.DynamicCamDB and self:BuildFromDynamicCam(_G.DynamicCamDB)
  if not imported then return false end
  local live = _G.DynamicCam
  imported.receipt.source = "capture"
  if not (live and live.currentSituationID) then
    imported.receipt.clientValues = {}
    for _, def in ipairs(SETTINGS) do
      local entry, value = imported.standard[def.name], tonumber(GetCVar(def.name))
      if value and not hasCurve(entry) and entry.value ~= value then
        imported.receipt.clientValues[def.name] = {profile = entry.value, client = value}
        entry.value = value
      end
    end
  end
  replace(imported)
  return true
end
function Camera:Reset() replace(self:ShippedDefaults()) end

local function setAddOn(enable)
  local api = C_AddOns or {}
  local call = enable and (api.EnableAddOn or EnableAddOn) or (api.DisableAddOn or DisableAddOn)
  return call and pcall(call, "DynamicCam") or false
end
function Camera:Command(command)
  command = (command or ""):lower():match("^%s*(.-)%s*$")
  if not cfg then print("Squanch-On camera: not initialized yet."); return end
  if command == "options" then
    if addon.OpenCameraOptions then addon:OpenCameraOptions() end
    return
  elseif command == "on" then
    cfg.enabled = true
    self:Enable()
  elseif command == "off" or command == "restore" then
    cfg.enabled = false
    self:Disable(command == "restore")
    print("Squanch-On camera: off" .. (command == "restore" and "; the camera CVars from before the first takeover are back." or "; camera CVars left as they are."))
  elseif command == "capture" then
    print("Squanch-On camera: " .. (self:Capture() and "DynamicCam profile and live values captured." or "DynamicCam is not loaded; nothing captured."))
  elseif command == "takeover" then
    if dynamicCamLoaded() and (cfg.receipt or {}).source == "defaults" then self:Capture() end
    cfg.enabled = true
    print(setAddOn(false) and "Squanch-On camera: DynamicCam disabled; type /reload to let Squanch-On drive the camera."
      or "Squanch-On camera: could not disable DynamicCam; untick it in the AddOns list, then /reload.")
    return
  elseif command == "release" then
    cfg.enabled = false
    self:Disable(true)
    print(setAddOn(true) and "Squanch-On camera: off and restored; DynamicCam enabled again, type /reload."
      or "Squanch-On camera: off and restored; tick DynamicCam in the AddOns list, then /reload.")
    return
  end
  local zoom = GetCameraZoom()
  local waiting = 0
  for _ in pairs(deferred) do waiting = waiting + 1 end
  print(("Squanch-On camera: %s; zoom=%.2f; right=%s (set %.3f); FoV=%s (set %.1f); dynamicPitch=%s; situation=%s; driver=%s; errors=%d; waiting for combat end=%d")
    :format(self.active and "active" or self.blocked and "blocked by DynamicCam" or "off", zoom,
      tostring(GetCVar("test_cameraOverShoulder")), resolve("test_cameraOverShoulder", zoom) or 0,
      tostring(GetCVar("cameraFov")), resolve("cameraFov", zoom) or 0, tostring(GetCVar("test_cameraDynamicPitch")),
      current and current.name or "none", self:IsAwake() and "running" or "asleep", errors, waiting))
  print("/sqms camera status | on | off | restore | capture | options | takeover | release")
end
