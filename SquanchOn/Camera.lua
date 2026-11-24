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
local asin, deg = math.asin, math.deg
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
      restore = profile.zoomRestoreSetting or "adaptive", transitionEasing = "InOutQuad"},
    -- Aim convergence (original). distance: used when no nameplate is near the
    -- reticle. scale: yards of sideways camera shift per
    -- unit of shoulder offset, negative to turn the other way. pitch: target
    -- focus pitch strength while a zoom is in progress.
    converge = {enabled = false, focus = true, strength = 1, distance = 25, scale = 1.11, pitch = 0, rev = 10, follow = true,
      aim = true, aimLimit = 30, catchUp = true, stay = true, stick = true, stickAngle = 6, softFollow = true}}
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
local speedsHeld, awaitingRegen

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
  end
  deferred[name] = text
  if not awaitingRegen then
    awaitingRegen = true
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
  end
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

-- Zoom easing, handled the way DynamicCam's LibCamera does (MIT, see
-- LICENSES/DynamicCam-MIT.txt): drive at the easing curve's velocity, rebase
-- the clock when the camera is off the curve, finish linearly, and if the
-- target was missed correct it with one native zoom at a temporary speed.
local ease
local EASE_INTERVAL, MAX_POS_ERROR = 1 / 60, 0.5
local function haltZoom() moveOut(0); moveIn(0); stopIn(); stopOut() end
local function endFix()
  local fix = ease and ease.fix
  if fix and fix.oldSpeed then pcall(SetCVar, "cameraZoomSpeed", fix.oldSpeed); fix.oldSpeed = nil end
end
local function stopEase()
  if ease then endFix(); ease = nil; haltZoom() end
end
local function startEase(target, duration, easing, wheel)
  stopEase()                                   -- every zoom starts from a stop
  ease = {to = target, dur = duration, fn = EASE[easing] or EASE.Linear, wheel = wheel, frames = 0}
  Camera:Wake()
end
local function easeValue(e, t) return e.from + e.change * e.fn(max(0, min(1, t / e.dur))) end
local function easeVelocity(e, t)
  local half, d = EASE_INTERVAL / 2, e.dur
  if t > half and t + half < d then return (easeValue(e, t + half) - easeValue(e, t - half)) / EASE_INTERVAL
  elseif t < half and t + EASE_INTERVAL < d then return (easeValue(e, t + EASE_INTERVAL) - easeValue(e, t)) / EASE_INTERVAL
  elseif t + half > d then return (easeValue(e, t) - easeValue(e, t - EASE_INTERVAL)) / EASE_INTERVAL end
end
-- Time at which the curve passes through `zoom` (the curves are monotonic).
local function rebaseTime(e, zoom)
  local lo, hi = 0, e.dur
  for _ = 1, 24 do
    local mid = (lo + hi) / 2
    if (easeValue(e, mid) - zoom) * e.change < 0 then lo = mid else hi = mid end
    if hi - lo < 0.005 then break end
  end
  return (lo + hi) / 2
end
local function stepFix(e, zoom)
  local fix = e.fix
  if not fix.triggered then                    -- one native zoom per frame, so next frame
    fix.triggered = true
    if fix.change > 0 then nativeZoomOut(fix.change) elseif fix.change < 0 then nativeZoomIn(-fix.change) end
  end
  local wrongWay = (fix.change > 0 and fix.last > zoom) or (fix.change < 0 and fix.last < zoom)
  fix.last = zoom
  if GetTime() <= fix.endTime and not wrongWay then return true end
  stopEase()
  return false
end
local function stepEase(zoom)
  local e = ease
  if not e then return false end
  if e.fix then return stepFix(e, zoom) end
  -- The first step runs one frame after the request: take the start here.
  local now = GetTime()
  e.began = e.began or now
  -- A camera that cannot move (locked view, a limit below the requested
  -- distance) is rebased to the start of the curve on every step and would
  -- never finish: give up well after any real ease has ended.
  if now - e.began > e.dur * 4 + 2 then stopEase(); return false end
  e.start = e.start or now
  e.from = e.from or zoom
  e.change = e.change or (e.to - e.from)
  e.frames = e.frames + 1
  local beyond = (e.change > 0 and zoom >= e.to) or (e.change < 0 and zoom <= e.to) or e.change == 0
  if not beyond and e.start + e.dur > now then
    local t = now - e.start
    if e.frames > 1 and abs(zoom - easeValue(e, t)) > MAX_POS_ERROR then
      local tPrime = rebaseTime(e, zoom)
      if tPrime > 0 and tPrime < e.dur then e.start = e.start - (tPrime - t); t = now - e.start end
    end
    local speed
    if e.dur - t > 2 * EASE_INTERVAL then speed = easeVelocity(e, t)
    else speed = (e.to - zoom) / EASE_INTERVAL end       -- linear over the last frames
    if not speed then stopEase(); return false end
    local zoomSpeed = max(0.01, tonumber(GetCVar("cameraZoomSpeed")) or 1)
    if speed > 0 then moveOut(speed / zoomSpeed) elseif speed < 0 then moveIn(-speed / zoomSpeed) end
    return true
  end
  haltZoom()
  -- Missed the target by more than the smallest native step: correct it.
  if abs(zoom - e.to) > 0.05 then
    local change = e.to - zoom
    e.fix = {change = change, endTime = now + 0.1, last = zoom, oldSpeed = GetCVar("cameraZoomSpeed")}
    pcall(SetCVar, "cameraZoomSpeed", abs(min(50, abs(change / 0.1))))
    return true
  end
  ease = nil
  return false
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

-- ---------------------------------------------------------------------------
-- Aim convergence: what is under the reticle stays there while the zoom, and
-- with it the shoulder offset, changes.
-- ---------------------------------------------------------------------------
-- Measured in game on 2026-11-23 (the navigation marker of a far waypoint
-- shows where the view really points):
-- * FlipCameraYaw turns the camera only, exactly, on the next frame. The
--   character keeps its facing, the mouse then turns both together, and
--   nothing an addon may call brings the two back in line (moving does not,
--   nor does restarting mouselook; a reload does). conv.applied is that
--   angle, camera minus facing, summed over every turn made here.
-- * The camera sits beside a pivot about PIVOT yards ahead of the character,
--   by the shoulder setting times the scale setting (1.11 on an orc). A point
--   D yards from the pivot is on the reticle when the camera looks
--   asin(side / D) left of its bearing, whatever the zoom.
-- * UnitPosition answers for some kinds of unit only (there: every Mottled
--   Boar, at any distance and bearing, also in combat; no Scorpid Worker,
--   not even one selected and under the reticle; no pet, no other player).
--   Where it answers, the turn that puts the unit on the reticle is exact.
-- * The engine's target focus works on every attackable target. It swivels
--   the camera where it stands, up to about 20 degrees, onto the unit (fully
--   from a strength of about 0.6; a strength above 1 adds nothing), allows
--   for the turns made here, and when released lets go as a critically
--   damped spring of 0.07 s: the view swings back. A swivel is not a turn
--   about the character: only for far units are the two alike, a near unit
--   needs a much larger turn to stay on the reticle.
-- What is done with that:
-- * Aim: a zoom turns onto a unit with a position by a real turn and holds
--   it there: the unit under the open reticle, else the target, else (zoom
--   sticks) the enemy nearest the reticle among the nameplate units.
-- * Follow: the open reticle keeps turning onto the unit under it by its
--   position. For any other unit the engine's own soft target and focus do
--   the following for as long as the reticle is held (the owner's choice,
--   2026-11-23, knowing it is what the open reticle did before positions
--   were found: nothing else follows such a unit), with the client's
--   selection disc hidden meanwhile; or, with that switched off, the unit's
--   nameplate is gone by (see plate, below).
--   Nothing is ever held at rest with the reticle closed, and at rest the
--   client's soft targeting is left as the owner has it.
-- * Focus and carry: a zoom with a target that gives no position is caught
--   by the engine's focus. While that is on, the swivel it holds is read from
--   the marker and taken over bit by bit as a real turn, the engine keeping
--   the unit on the reticle all the while. At the release what little swivel
--   is left is turned in step with the engine letting go, so nothing swings
--   back. With nothing selected such a unit is left alone.
-- * Distance: with no unit, the centre ray keeps crossing the character's
--   forward line `distance` yards ahead.
-- * Catch-up: a view turned onto a unit is off the character's facing.
--   Afterwards a share of the owner's own turning closes that gap instead of
--   moving the view.
-- The focus values to put back live in the saved settings, so a session that
-- ends mid-zoom is repaired at next login.
local FOCUS = {"test_cameraTargetFocusEnemyStrengthYaw", "test_cameraTargetFocusEnemyStrengthPitch", "test_cameraTargetFocusEnemyEnable",
  "test_cameraTargetFocusInteractStrengthYaw", "test_cameraTargetFocusInteractStrengthPitch", "test_cameraTargetFocusInteractEnable"}
local FOCUS_SETTLE = 0.3            -- seconds the focus stays on after the zoom stops
local CARRY_TIME = 0.3              -- seconds: time constant of taking the engine's swivel over as a turn
local CARRY_RATE = 12               -- degrees per second at most: the engine trails each turn, and the unit strays that much meanwhile
local CARRY_LAG = 0.14              -- seconds by which the engine's answer trails a turn (twice its spring's time)
local AWAY_LIMIT = 75               -- degrees the view is ever turned away from the character's own line
local CARRY_REST = 0.6              -- degrees of swivel a release may still find
local CARRY_PATIENCE = 1.3          -- seconds a release waits for the swivel to come down to that
local CARRY_SETTLE = 0.15           -- seconds without a turn before the release, for the engine to catch up
local RELEASE_TIME = 0.07           -- seconds: the engine lets its focus go as e0 (1 + t/T) exp(-t/T)
local CONVERGE_MAX_RATE = 600       -- degrees per second
local FIRST_PERSON_TIME = 0.075     -- seconds the client takes to slide the shoulder offset in or out
local AIM_TIME = 0.07               -- seconds: time constant of the turn onto a unit during a zoom
local AIM_SETTLE = 0.25             -- seconds an aim keeps turning after the zoom stopped
local FOLLOW_TIME = 0.035           -- the same for the open reticle
local NEAR_RANGE = 50               -- yards within which a zoom sticks to an enemy
local PIVOT = 0.5                   -- yards from the character's position to the camera's pivot, ahead
local CATCH_UP = 0.3                -- share of the owner's turning that goes into realigning
local REALIGN = {time = 0.35, least = 10}   -- while the character moves: seconds (time constant) and degrees a second at least, of the view coming round behind it
local GAUGE_YARDS = {400, 200, 100, 60}
local sin, cos, tan, atan, rad, sqrt, exp, atan2 = math.sin, math.cos, math.tan, math.atan, math.rad, math.sqrt, math.exp, math.atan2
local conv = {applied = 0, quiet = huge}
local gauge, carry = {}, {}
local function wrap(angle) return (angle + 180) % 360 - 180 end
-- Yards north and west of a unit, or nothing where the client keeps them back.
local function position(unit)
  local ok, north, west = pcall(UnitPosition, unit)
  if ok and not secret(north) and not secret(west) and type(north) == "number" and type(west) == "number" then return north, west end
end
-- First person has no shoulder offset whatever the curve says at zoom 0.
local function shoulderAt(zoom) return zoom < 0.05 and 0 or (resolve("test_cameraOverShoulder", zoom) or 0) end
local function convergeAngle(offset, distance)
  return deg(asin(max(-1, min(1, offset * cfg.converge.scale / max(1, distance)))))
end
local function gateOpen() return addon.IsNativeMouseoverOpen and addon:IsNativeMouseoverOpen() and true or false end
-- The character's facing in degrees, growing to the left. Only the mouse turns
-- it, and only while mouselooking is the camera tied to it.
local function readFacing()
  if not (IsMouselooking and IsMouselooking()) then return end
  local ok, facing = pcall(GetPlayerFacing)
  if ok and not secret(facing) and type(facing) == "number" then return deg(facing) end
end
local function turn(step)
  if step ~= 0 then
    FlipCameraYaw(step)
    conv.applied = conv.applied + step
  end
end
-- A unit is about to be turned onto, off the resting line: that line is noted
-- once, as the angle beyond the plain convergence.
local function leaveHome(offset)
  if conv.home == nil then conv.home = conv.applied - convergeAngle(offset, cfg.converge.distance) end
end

-- The angle, camera minus facing, that puts a unit on the reticle, and the
-- unit's distance from the pivot.
local function aimAngle(unit, facing, zoom)
  local north, west = position("player")
  local unitNorth, unitWest = position(unit)
  if not (north and unitNorth) then return end
  local heading = rad(facing)
  north, west = unitNorth - north - PIVOT * cos(heading), unitWest - west - PIVOT * sin(heading)
  local distance = sqrt(north * north + west * west)
  if distance < 3 then return end     -- on top of the character: no sensible angle
  return wrap(deg(atan2(west, north)) + convergeAngle(shoulderAt(zoom), distance) - facing), distance
end
-- With nothing selected a zoom sticks to the enemy nearest the reticle:
-- among the units with a nameplate and a position, the one seen within the
-- owner's angle of it.
local function nearUnit()
  local facing, zoom = readFacing(), GetCameraZoom()
  if not facing then return end
  local best, bestOff
  for index = 1, 40 do
    local unit = "nameplate" .. index
    local ok, enemy, dead = pcall(function() return UnitExists(unit) and UnitCanAttack("player", unit), UnitIsDead(unit) end)
    if ok and not secret(enemy) and not secret(dead) and enemy and not dead then
      local wanted, distance = aimAngle(unit, facing, zoom)
      if wanted and distance <= NEAR_RANGE then
        -- How far from the reticle it is seen: the camera stands the zoom behind the pivot the turn is about.
        local turned = rad(wrap(wanted - conv.applied))
        local off = abs(deg(atan2(distance * sin(turned), distance * cos(turned) + zoom)))
        if off <= cfg.converge.stickAngle and (not bestOff or off < bestOff) then best, bestOff = unit, off end
      end
    end
  end
  return best
end
-- The unit a zoom turns onto by its position.
local function aimUnit()
  if gateOpen() and UnitExists("mouseover") and position("mouseover") then return "mouseover" end
  if UnitExists("target") then return not UnitIsUnit("target", "player") and position("target") and "target" or nil end
  if cfg.converge.stick and not gateOpen() then return nearUnit() end
end
-- The unit the open reticle follows by its position: the one that comes
-- under it, and from then on that same unit for as long as the reticle stays
-- open, by its nameplate when the reticle slips off the model (it does: the
-- reticle keeps its height while the unit walks nearer or further).
local function sameUnit(unit, guid)
  if not UnitExists(unit) then return false end
  local ok, other = pcall(UnitGUID, unit)
  return ok and not secret(other) and other == guid
end
local function followUnit()
  local guid = conv.followGUID
  if guid then
    if sameUnit("mouseover", guid) and position("mouseover") then return "mouseover" end
    local token = conv.followToken
    if not (token and sameUnit(token, guid)) then
      token = nil
      for index = 1, 40 do
        if sameUnit("nameplate" .. index, guid) then token = "nameplate" .. index; break end
      end
      conv.followToken = token
    end
    if token and position(token) then return token end
    conv.followGUID, conv.followToken = nil, nil      -- gone: the next unit under the reticle is picked up
  end
  if UnitExists("mouseover") and position("mouseover") then
    local ok, found = pcall(UnitGUID, "mouseover")
    conv.followGUID, conv.followToken = ok and not secret(found) and found or nil, nil
    return "mouseover"
  end
end
-- Without positions: the unit whose range estimates the distance. unit, yards, source.
local function reticleUnit()
  local c = cfg.converge
  if c.held then return nil, c.distance, "target focus" end
  local unit = gateOpen() and UnitExists("mouseover") and "mouseover" or UnitExists("target") and "target" or nil
  if unit and addon.Range then
    local ok, low, high = pcall(addon.Range.Bracket, addon.Range, unit)
    local yards = ok and (low and high and (low + high) / 2 or high or low and low * 1.2)
    if yards then return unit, max(1, yards), unit .. " range" end
  end
  return unit, c.distance, "fallback"
end

-- The gauge: a waypoint far along the view. Its navigation marker shows, one
-- frame later, where the view points. The owner's own waypoint and tracked
-- quest are put back when it ends.
local function gaugeEnd()
  local saved = gauge.saved
  if not saved then return end
  gauge.saved = nil
  pcall(function()
    C_SuperTrack.SetSuperTrackedUserWaypoint(false)
    if saved.point then C_Map.SetUserWaypoint(saved.point) else C_Map.ClearUserWaypoint() end
    if saved.user and saved.point then C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    elseif saved.quest and saved.quest ~= 0 then C_SuperTrack.SetSuperTrackedQuestID(saved.quest) end
  end)
end
-- heading: degrees, where the view is taken to point.
local function gaugeBegin(heading)
  local saved = gauge.saved           -- set anew while one is up: what was there before stays noted
  local ok, set = pcall(function()
    local track, map = C_SuperTrack, C_Map
    if not (track and map and C_Navigation and C_Navigation.GetFrame and UiMapPoint) then return false end
    if track.IsSuperTrackingCorpse and track.IsSuperTrackingCorpse() then return false end
    local north, west = position("player")
    local id = map.GetBestMapForUnit("player")
    if not (north and id) or (map.CanSetUserWaypointOnMap and not map.CanSetUserWaypointOnMap(id)) then return false end
    local spot = map.GetPlayerMapPosition(id, "player")
    local width, height = map.GetMapWorldSize(id)
    if not (spot and width and height) or width <= 0 or height <= 0 then return false end
    local toNorth, toWest = cos(rad(heading)), sin(rad(heading))
    for _, yards in ipairs(GAUGE_YARDS) do
      -- Map x grows to the east and y to the south.
      local x, y = spot.x - toWest * yards / width, spot.y - toNorth * yards / height
      if x > 0.002 and x < 0.998 and y > 0.002 and y < 0.998 then
        gauge.saved = saved or {point = map.HasUserWaypoint() and map.GetUserWaypoint() or nil,
          user = track.IsSuperTrackingUserWaypoint() and true or false, quest = track.GetSuperTrackedQuestID()}
        map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(id, x, y))
        track.SetSuperTrackedUserWaypoint(true)
        gauge.north, gauge.west = north + toNorth * yards, west + toWest * yards
        return true
      end
    end
    return false
  end)
  if ok and set then return true end
  gaugeEnd()
  return false
end
-- Degrees the engine's focus has the camera swivelled to the left, and how far
-- right of the view axis the marker stands; nothing until the marker shows
-- the gauge. facing: the character's, as of the frame the marker shows.
local function gaugeRead(zoom, facing)
  local navigation = C_Navigation
  local frame = navigation.GetFrame()
  if not frame or navigation.HasValidScreenPosition() == false or navigation.WasClampedToScreen() then return end
  local north, west = position("player")
  if not north then return end
  local heading = rad(facing)
  north, west = gauge.north - north - PIVOT * cos(heading), gauge.west - west - PIVOT * sin(heading)
  local distance = sqrt(north * north + west * west)
  local yards = navigation.GetDistance()
  if not yards or abs(yards - distance) > max(3, distance * 0.05) then return end   -- still what was tracked before
  local x = frame:GetCenter()
  if not x then return end
  local scale = WorldFrame:GetEffectiveScale()
  -- Units per unit of tangent. Flips of known size at seven fields of view
  -- gave a vertical angle of 0.6263 x cameraFov + 0.52 degrees.
  local focal = WorldFrame:GetHeight() * scale / 2 / tan(rad(0.6263 * (tonumber(GetCVar("cameraFov")) or 90) + 0.52) / 2)
  local centre = WorldFrame:GetCenter()
  local right = atan((x * frame:GetEffectiveScale() - centre * scale) / focal)
  -- Where the marker would stand without the swivel: the camera looks along
  -- the character's facing plus the turns made here, from beside and behind
  -- the pivot.
  local off = rad(facing + conv.applied) - atan2(west, north)
  local rest = atan2(distance * sin(off) - shoulderAt(zoom) * cfg.converge.scale, distance * cos(off) + zoom)
  return deg(right - rest), deg(right)
end

local function sameValue(a, b)
  if a == b then return true end
  local x, y = tonumber(a), tonumber(b)
  return x ~= nil and y ~= nil and abs(x - y) < 0.0001
end
local function endFocus()
  local c = cfg and cfg.converge
  local held = type(c) == "table" and c.held
  if not held then return end
  c.held, c.heldGate = nil, nil
  for name, value in pairs(held) do
    setCVar(name, value)
    -- The client refuses some of these in combat without a word (seen once,
    -- from a situation change in combat): such a value is put back when
    -- combat ends, or it would stay as the hold left it.
    if not sameValue(GetCVar(name), tostring(value)) then
      deferred[name] = tostring(value)
      if not awaitingRegen then
        awaitingRegen = true
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
      end
    end
  end
end
-- The value a hold puts back: one still waiting to be put back counts, not
-- what an earlier hold left behind.
local function heldValue(name)
  local waiting = deferred[name]
  deferred[name] = nil
  return waiting or GetCVar(name)
end
-- The engine's focus: for the length of a zoom with a target the client
-- gives no position for; and (reticle) for as long as the open reticle is
-- held with nothing selected. There the engine's soft target, its cone at
-- the narrowest, takes the enemy in front and the focus keeps the view on
-- it; the client's selection disc is hidden meanwhile. All of it is put
-- back when the reticle closes.
local function beginFocus(reticle)
  local c = cfg.converge
  if not c.enabled or transFn then return end
  carry.since, carry.still = nil, nil   -- a release that was waiting: the gesture goes on
  if c.held then return end
  local want = {}
  if reticle then
    want.SoftTargetEnemy, want.SoftTargetEnemyArc, want.ObjectSelectionCircle = 3, 0, 0
  else
    if not (c.focus and UnitExists("target") and not UnitIsUnit("target", "player")) then return end
    if c.aim and aimUnit() then return end           -- a unit with a position is aimed at by a real turn
  end
  for index, name in ipairs(FOCUS) do
    local kind = index % 3            -- 1 yaw strength, 2 pitch strength, 0 enable
    want[name] = kind == 1 and c.strength or kind == 2 and c.pitch or 1
  end
  local held = {}
  for name in pairs(want) do held[name] = heldValue(name) end
  c.held, c.heldGate = held, reticle and true or nil
  for name, value in pairs(want) do
    if held[name] ~= nil then setCVar(name, value) end
  end
  carry.total, carry.psi, carry.blind, carry.time, carry.release, carry.stage, carry.ratio, carry.mark, carry.trail = 0, nil, 0, 0, nil, nil, nil, nil, nil
  Camera:Wake()                     -- the driver ends the hold, also when the zoom is already at its limit
end
-- The zoom is over. A swivel that is still large is carried a moment longer
-- first.
local function releaseFocus()
  local c = cfg.converge
  if not c.held then return end
  if not (c.stay and gauge.saved) then
    endFocus(); gaugeEnd()
    return
  end
  carry.since = carry.since or 0
  Camera:Wake()
end
-- Carry: while the engine's focus is on, the swivel it holds is taken over as
-- a real turn. The engine sees each turn and swivels that much less, keeping
-- the unit on the reticle throughout. How much less tells how near the unit
-- is: one degree per degree for a far unit, a fraction for a near one, which
-- would take a turn right around the character to stay on the reticle. The
-- taking over starts with the first swivel read and never pauses (pauses
-- showed as a jerky zoom); the answer is read off the turns already made,
-- once the zoom stands still, and the rest is then carried at that ratio,
-- or the swivel is left as it is and only the view's direction is kept at
-- the release.
local function stepCarry(zoom, elapsed)
  local c = cfg.converge
  local release = carry.release
  if release then                   -- the focus is off: the rest of its swivel is turned as the engine lets go
    release.time = release.time + elapsed
    local t = release.time / RELEASE_TIME
    local due = t > 10 and release.turn or release.turn * (1 - (1 + t) * exp(-t))
    local step = due - release.done
    release.done = due
    turn(step)
    if conv.bias then conv.bias = conv.bias + step end   -- a zoom begun meanwhile must not turn this back
    if t > 10 then carry.release = nil; return false end
    return true
  end
  if not c.held or c.heldGate then      -- the open reticle's hold is the engine's alone: nothing is taken over
    gaugeEnd()
    carry.psi, carry.since, carry.facing, carry.still = nil, nil, nil, nil
    return false
  end
  local facing = readFacing()
  local psi
  if c.stay and facing then
    if not gauge.saved then
      if (carry.retry or 0) <= GetTime() then
        if gaugeBegin(facing + conv.applied + (carry.psi or 0)) then carry.blind = 0
        else carry.retry, conv.handed = GetTime() + 1, "no waypoint can be set here: the view swings back" end
      end
    else
      local ok, value, right = pcall(gaugeRead, zoom, carry.facing or facing)
      if ok and value then
        psi, carry.blind = value, 0
        -- The view has turned far from the waypoint: a new one, along the view, for the next frames.
        if abs(right) > 25 then gaugeBegin(facing + conv.applied + psi) end
      else
        carry.blind = (carry.blind or 0) + 1
        if carry.blind > 8 then gaugeBegin(facing + conv.applied + (carry.psi or 0)); carry.blind = 0 end
      end
    end
  end
  carry.facing = facing
  if psi then
    local was = carry.psi
    carry.psi = psi
    carry.time = (carry.time or 0) + elapsed
    local offset = shoulderAt(zoom)
    leaveHome(offset)
    local rate, ratio = CARRY_RATE, carry.ratio or 1
    -- The engine's answer trails the turns by its spring: they are compared
    -- through a copy that trails alike. Only while the zoom stands still,
    -- its own shift of the unit would spoil the answer; and once per hold.
    local trail = carry.trail or carry.total
    trail = trail + (carry.total - trail) * (1 - exp(-elapsed / CARRY_LAG))
    carry.trail = trail
    if not carry.stage and was and conv.quiet > 0.05 then
      local mark = carry.mark
      if not mark then
        mark = {psi, trail}
        carry.mark = mark
      end
      local turned = trail - mark[2]
      if abs(turned) > 1.5 then
        local gain = (mark[1] - psi) / turned
        -- All of it at this ratio: more than the owner allows per zoom means a unit too near (or out of the focus's reach).
        if gain < 0.12 or abs(carry.total) + abs(psi) / gain > c.aimLimit then carry.stage = "given"
        else carry.stage, carry.ratio = "go", 1 / max(0.34, min(1, gain)) end
        ratio = carry.ratio or 1
      end
    elseif not carry.stage then carry.mark = nil end
    -- A release that is due: no more turns, so that the swivel read at the end is where the engine has settled.
    if carry.still then rate = 0 end
    local step = carry.stage == "given" and 0 or psi * ratio * (1 - exp(-elapsed / CARRY_TIME))
    local limit = rate * elapsed
    step = max(-limit, min(limit, step))
    -- A zoom turns by no more than the owner allows; nothing ever turns far off the character's own line.
    local away = conv.applied - convergeAngle(offset, c.distance) - conv.home
    if abs(carry.total + step) > c.aimLimit or abs(away + step) > AWAY_LIMIT then step = 0 end
    turn(step)
    carry.total = carry.total + step
  end
  if carry.since then
    carry.since = carry.since + elapsed
    local left = gauge.saved and carry.psi or 0
    local given = carry.stage == "given"
    local due = given or abs(left) <= (carry.still and 2 or 1) * CARRY_REST or carry.since > CARRY_PATIENCE
    if due and not given and gauge.saved and carry.psi then
      carry.still = (carry.still or 0) + elapsed
      due = carry.still > CARRY_SETTLE
    else carry.still = nil end        -- the swivel grew again (the unit walks): carried on
    if due then
      -- What is left of the swivel is turned one for one as the engine lets
      -- go: the view keeps its direction. After a full carry that is a rest
      -- of a degree and the unit stays on the reticle; for a unit that was
      -- not carried it is the whole swivel, and the unit, seen from a camera
      -- that has moved round, slips off by part of it.
      local rest = left
      if abs(carry.total + rest) > c.aimLimit then rest = 0 end
      conv.handed = ("%.1f degrees turned in place of the game's focus%s"):format(carry.total + rest,
        rest == 0 and abs(left) > 0.3 and (": more than the limit, %.1f swing back"):format(left)
        or given and ": the view stays; the unit is too near (or too far to the side) to be held on the reticle within the limit" or "")
      endFocus(); gaugeEnd()
      carry.psi, carry.since, carry.facing, carry.still = nil, nil, nil, nil
      if abs(rest) < 0.05 then return false end
      carry.release = {turn = rest, time = 0, done = 0}
      conv.live = nil                 -- the gesture is over: the plain convergence must not turn this back
      return stepCarry(zoom, elapsed) -- in step with the engine: this frame's turn lands with its first step
    end
  end
  return true
end

-- Turns toward the wanted angle: what that angle moved since the last frame
-- (a walking unit, the owner's own turning) at once, and a share of the rest
-- per frame, so a unit in motion is held without trailing behind it.
local function track(wanted, elapsed, time)
  local owed = wrap(wanted - conv.applied)
  local moved = conv.tracked and wrap(wanted - conv.tracked) or 0
  conv.tracked = wanted
  if abs(moved) > 3 then moved = 0 end          -- another unit or a jump: nothing to carry over
  local share = 1 - exp(-elapsed / time)
  local step = abs(owed) < 0.01 and owed or owed * share + moved * (1 - share)
  local limit = CONVERGE_MAX_RATE * elapsed
  turn(max(-limit, min(limit, step)))
end
local function stopConverge()
  conv.ramp, conv.live, conv.aim, conv.mode, conv.quiet = nil, nil, nil, nil, huge
end
-- The view is kept on a unit by its position (open reticle). key: what is
-- being held, so that a change of unit starts the turn afresh.
local function hold(unit, wanted, distance, offset, elapsed, mode, key)
  leaveHome(offset)
  if conv.mode ~= mode or conv.followed ~= key then conv.tracked = nil end
  conv.followed = key
  track(wanted, elapsed, FOLLOW_TIME)
  conv.mode, conv.unit, conv.distance, conv.source = mode, unit, distance, unit .. " position"
  conv.bias = conv.applied - convergeAngle(offset, distance)
  conv.live, conv.aim, conv.watch = nil, nil, nil    -- a zoom meanwhile is carried by the holding itself
end
-- Follow without a position. The client will not say where a nameplate is
-- (every measurement of one, and of anything anchored to one, is refused),
-- but it does tell a frame that the cursor is over it. While the open
-- reticle follows a unit, screen-high strips hang on that unit's nameplate:
-- one on its centre line and a row to either side, each a known angle wide.
-- The strip under the centred cursor tells how far off the reticle the unit
-- stands, and the view turns until it is the middle one. The strips take
-- mouse motion only and pass it on: clicks and the world's own picking are
-- untouched.
local plate = {
  EDGES = {0.25, 0.6, 1.2, 2.4, 4.8, 9, 16, 26},   -- degrees from the centre line at which one strip ends and the next begins
  TIME = 0.08,                      -- seconds: time constant of the turn toward the middle strip
  LEARN = 20,                       -- how fast the unit's own rate across the screen is picked up (per second squared)
  LOST = 0.6,                       -- seconds with no strip under the cursor and the unit not under it either: let go
  strips = {},
}
function plate.build()
  if plate.ready ~= nil then return plate.ready end
  if InCombatLockdown() then return false end       -- passing motion on cannot be set in combat: built after it
  local holder
  local ok, problem = pcall(function()
    holder = CreateFrame("Frame", nil, UIParent)
    holder:SetSize(1, 1)
    holder:Hide()
    for side = -1, 1 do                               -- 1: right of the centre line
      for index = 1, side == 0 and 1 or #plate.EDGES - 1 do
        local strip = CreateFrame("Frame", nil, holder)
        strip.side, strip.index = side, index
        strip.angle = side * (plate.EDGES[index] + plate.EDGES[index + 1]) / 2
        strip:SetFrameStrata("BACKGROUND")
        strip:EnableMouse(true)
        strip:SetMouseClickEnabled(false)
        strip:SetPropagateMouseMotion(true)
        strip:SetScript("OnEnter", function(self) self.over = true end)
        strip:SetScript("OnLeave", function(self) self.over = nil end)
        strip:SetScript("OnHide", function(self) self.over = nil end)
        plate.strips[#plate.strips + 1] = strip
      end
    end
  end)
  plate.holder, plate.ready, plate.problem = holder, ok, not ok and tostring(problem) or nil
  return ok
end
function plate.attach(token)
  local found, frame = pcall(C_NamePlate.GetNamePlateForUnit, token)
  if not (found and frame) or not plate.build() then return false end
  local holder = plate.holder
  -- Screen units per unit of tangent (see gaugeRead), in the strips' own scale.
  local focal = WorldFrame:GetHeight() * WorldFrame:GetEffectiveScale() / 2
    / tan(rad(0.6263 * (tonumber(GetCVar("cameraFov")) or 90) + 0.52) / 2) / holder:GetEffectiveScale()
  local ok, problem = pcall(function()
    for _, strip in ipairs(plate.strips) do
      strip:ClearAllPoints()
      strip.over = nil
      if strip.side == 0 then
        strip:SetSize(2 * focal * tan(rad(plate.EDGES[1])), 4000)
        strip:SetPoint("CENTER", frame, "CENTER")
      else
        local near, far = focal * tan(rad(plate.EDGES[strip.index])), focal * tan(rad(plate.EDGES[strip.index + 1]))
        strip:SetSize(far - near, 4000)
        if strip.side > 0 then strip:SetPoint("LEFT", frame, "CENTER", near, 0) else strip:SetPoint("RIGHT", frame, "CENTER", -near, 0) end
      end
    end
    holder:Show()
  end)
  if not ok then
    plate.problem = tostring(problem)
    holder:Hide()
    return false
  end
  plate.frame = frame
  return true
end
function plate.release()
  plate.guid, plate.token, plate.frame, plate.rate, plate.lost, plate.last, plate.since, plate.age = nil, nil, nil, nil, nil, nil, nil, nil
  if plate.holder then plate.holder:Hide() end
end
-- Degrees the unit stands left of the reticle, by the strip the cursor is
-- over; nil when it is over none. A strip right of the nameplate's centre
-- line under the cursor: the unit is left of the reticle.
function plate.read()
  local best
  for _, strip in ipairs(plate.strips) do
    local over = strip.over
    if not over and plate.poll ~= false then        -- a strip that slid under a resting cursor
      local ok, focus = pcall(strip.IsMouseMotionFocus, strip)
      if ok and not secret(focus) then over = focus == true else plate.poll = false end
    end
    if over and (not best or strip.index < best.index or strip.side == 0) then best = strip end
  end
  return best and best.angle
end
-- One frame of following the open reticle's unit by its nameplate. False
-- when there is nothing to follow that way.
function plate.step(c, elapsed, offset)
  local guid = plate.guid
  if not guid then
    local ok, found = pcall(UnitGUID, "mouseover")    -- the unit that has come under the reticle
    if not ok or secret(found) or type(found) ~= "string" then return false end
    local token
    for index = 1, 40 do
      if sameUnit("nameplate" .. index, found) then token = "nameplate" .. index; break end
    end
    if not (token and plate.attach(token)) then return false end
    plate.guid, plate.token, plate.rate, plate.lost, plate.age, plate.hid, plate.seen = found, token, 0, 0, 0, 0, 0
    guid = found
  end
  local ok, frame = pcall(C_NamePlate.GetNamePlateForUnit, plate.token)
  if not (ok and frame == plate.frame and sameUnit(plate.token, guid)) then      -- the nameplate went, or passed to another unit
    plate.release()
    return false
  end
  local off = plate.read()
  local under = sameUnit("mouseover", guid)
  -- The unit was under the cursor when the strips went up. If from then on
  -- the game no longer sees it there whenever a strip is, the strips are
  -- keeping the mouse from the world (motion is not passed on in this
  -- client): they must go, for good, or mouseover casting would suffer.
  if plate.age < 0.3 then
    plate.age = plate.age + elapsed
    if off then
      plate.seen = plate.seen + 1
      if not under then plate.hid = plate.hid + 1 end
    end
    if plate.age >= 0.3 and plate.seen >= 8 and plate.hid >= plate.seen * 0.8 then
      plate.problem, plate.ready = "the strips hid the unit from the game's own picking", false
      plate.release()
      return false
    end
  end
  plate.lost = (off or under) and 0 or plate.lost + elapsed
  if plate.lost > plate.LOST then plate.release(); return false end
  off = off or 0
  -- A strip that goes on answering while the view turns well past what it
  -- spans is not telling where the unit is: no more of this until a reload.
  if off ~= plate.last then plate.last, plate.since = off, conv.applied end
  if off ~= 0 and abs(conv.applied - plate.since) > 8 * abs(off) + 2 then
    plate.problem, plate.ready = "a strip kept answering while the view turned past it", false
    plate.release()
    return false
  end
  if off * plate.rate < 0 then plate.rate = 0 end     -- it stopped or turned back: no carrying on past it
  plate.rate = plate.rate + off * plate.LEARN * elapsed
  local limit = CONVERGE_MAX_RATE * elapsed
  local step = max(-limit, min(limit, (plate.rate + off / plate.TIME) * elapsed))
  leaveHome(offset)
  -- Never far off the character's own line.
  if abs(conv.applied + step - convergeAngle(offset, c.distance) - conv.home) > AWAY_LIMIT then step, plate.rate = 0, 0 end
  turn(step)
  conv.mode, conv.unit, conv.distance, conv.source, conv.followed = "follow", plate.token, c.distance, "nameplate", guid
  conv.bias = conv.applied - convergeAngle(offset, c.distance)
  conv.live, conv.aim, conv.watch = nil, nil, nil    -- a zoom meanwhile is carried by the following itself
  return true
end
-- A zoom gesture begins; its choices stay until it settles.
local function beginConverge(zoom, from)
  local c = cfg.converge
  conv.live, conv.quiet, conv.aim, conv.tracked = true, 0, nil, nil
  local facing = readFacing()
  local unit = facing and not c.held and aimUnit()
  local wanted, distance
  if unit then wanted, distance = aimAngle(unit, facing, from) end
  if wanted then
    conv.unit, conv.distance, conv.source = unit, distance, unit .. " position"
    -- Far off to the side it is not what the owner is looking at: the zoom
    -- then only keeps its own point steady, by that unit's true distance.
    if c.aim and abs(wrap(wanted - conv.applied)) <= c.aimLimit and abs(wanted) <= AWAY_LIMIT then
      conv.aim = unit
      local ok, guid = pcall(UnitGUID, unit)       -- a nameplate's name can pass to another unit
      conv.aimGUID = ok and not secret(guid) and guid or nil
    end
  else
    conv.unit, conv.distance, conv.source = reticleUnit()
  end
  conv.bias = conv.applied - convergeAngle(shoulderAt(from), conv.distance)
end
local function armConverge()
  if cfg.converge.enabled and not conv.live and not transFn and #turns == 0 then
    local zoom = GetCameraZoom()
    beginConverge(zoom, zoom)
  end
end
-- Back to the resting line: with the owner's own turning, and at once when
-- the character moves (left askew, it would run sideways across the
-- screen). True while there is a gap this could close, so the driver keeps
-- watching the facing.
local function catchUp(c, facing, steered, offset, elapsed)
  if conv.home == nil then return false end
  local extra = conv.applied - convergeAngle(offset, c.distance) - conv.home
  if abs(extra) < 0.05 then conv.home = nil; return false end
  -- Not while the reticle is held open: there the aim must move exactly as the mouse does.
  if not (c.catchUp and facing) or gateOpen() then return false end
  local share = abs(steered) < 30 and min(abs(extra), abs(steered) * CATCH_UP) or 0
  local ok, speed = pcall(GetUnitSpeed, "player")
  if ok and not secret(speed) and type(speed) == "number" and speed > 0 then
    share = max(share, min(abs(extra), max(abs(extra) * (1 - exp(-elapsed / REALIGN.time)), REALIGN.least * elapsed)))
  end
  if share > 0 then turn(extra > 0 and -share or share) end
  return true
end
local function stepConverge(zoom, elapsed)
  local c = cfg.converge
  local was = conv.seen
  conv.seen = zoom
  -- Not during a situation's own turn or setting transition.
  if not c.enabled or transFn or #turns > 0 then
    if conv.live then stopConverge() end
    conv.steer, conv.watch, conv.followGUID, conv.followToken = nil, nil, nil, nil
    if plate.guid then plate.release() end
    return false
  end
  local facing = readFacing()
  local steered = conv.steer and facing and wrap(facing - conv.steer) or 0
  conv.steer = facing
  local moving = was ~= nil and abs(zoom - was) > 0.0005
  conv.quiet = moving and 0 or conv.quiet + elapsed
  local offset = shoulderAt(zoom)
  if c.enabled and moving and not conv.live then    -- a zoom the wheel did not start
    -- Leaving first person, the first frame may already carry the offset.
    beginConverge(zoom, was < 0.05 and was or zoom)
  end

  -- The open reticle follows the unit under it.
  local gate = c.enabled and c.follow and gateOpen()
  if gate and facing and (not c.held or c.heldGate) and not UnitExists("target") then
    local unit = c.aim and followUnit() or nil
    local wanted, distance
    if unit then wanted, distance = aimAngle(unit, facing, zoom) end
    -- Never far off the character's own line: beyond that the view goes with the mouse again.
    if wanted and abs(wanted) <= AWAY_LIMIT then
      if plate.guid then plate.release() end
      if c.heldGate then endFocus() end                -- by its position: the engine's soft target is not needed
      hold(unit, wanted, distance, offset, elapsed, "follow", conv.followGUID)
      return true
    end
    if not wanted then
      -- The game gives no position for what is there: its own soft target
      -- and focus follow until the reticle closes; or, with that switched
      -- off, the unit's nameplate is gone by.
      if c.softFollow then
        if not c.held then beginFocus(true) end
      elseif (plate.guid or UnitExists("mouseover")) and plate.step(c, elapsed, offset) then return true end
    end
  else
    if plate.guid then plate.release() end
    if c.heldGate then endFocus() end                  -- the reticle closed, or something was selected
    if not gate then conv.followGUID, conv.followToken = nil, nil end
  end
  if not conv.live then
    conv.mode = gate and (c.heldGate and "follow (the game's soft target)"
      or UnitExists("mouseover") and "follow (no position and no nameplate to go by)" or "follow (nothing under the reticle)") or nil
    conv.watch = not c.held and catchUp(c, facing, steered, offset, elapsed)
    return gate
  end
  conv.watch = nil

  -- Zoom gesture: onto a unit by its position.
  if conv.aim then
    local wanted, distance
    if facing and (conv.aimGUID and sameUnit(conv.aim, conv.aimGUID) or not conv.aimGUID and UnitExists(conv.aim)) then
      wanted, distance = aimAngle(conv.aim, facing, zoom)
    end
    if wanted then
      -- Held through the zoom and a moment longer, then let go: the view
      -- stays where the zoom left it, also when the unit walks on.
      if conv.quiet > AIM_SETTLE then conv.live, conv.aim = nil, nil; return false end
      leaveHome(offset)
      conv.mode, conv.distance = "aim", distance
      track(wanted, elapsed, AIM_TIME)
      conv.bias = conv.applied - convergeAngle(offset, distance)
      return true
    end
    conv.aim = nil                    -- the unit is gone: on by its last distance, from the yaw turned so far
    conv.bias = conv.applied - convergeAngle(offset, conv.distance)
  end
  -- The client's own focus is turning the view onto the target: a turn made
  -- here would only fight it.
  if c.held then
    conv.mode, conv.source, conv.unit = "target focus", "target focus", "target"
    conv.bias = conv.applied - convergeAngle(offset, conv.distance)
    if conv.quiet > 0.5 then conv.live = nil end
    return false
  end
  -- First person looks along the character: an aim left over from before is dropped there.
  if zoom < 0.05 and conv.home ~= nil then
    conv.bias, conv.distance, conv.home = conv.home, c.distance, nil
  end
  local wanted = zoom < 0.05 and 0 or conv.bias + convergeAngle(offset, conv.distance)
  conv.wanted, conv.mode = wanted, "distance"
  local owed = wanted - conv.applied
  local busy = abs(owed) > 0.002
  -- Leaving or entering first person the client slides the shoulder offset
  -- in over about 75 ms (measured), so the turn it calls for is spread over
  -- the same time; ordinary zoom steps are applied as they come.
  if abs(owed) > 0.3 and not conv.ramp then conv.ramp = abs(owed) / FIRST_PERSON_TIME end
  if not busy then conv.ramp = nil end
  if busy then
    local limit = (conv.ramp or CONVERGE_MAX_RATE) * elapsed
    turn(max(-limit, min(limit, owed)))
  end
  if not busy and conv.quiet > 0.5 then conv.live = nil end
  return busy
end
-- Core's gate changes: the open reticle follows from this very call on.
local function gateChanged()
  if not (Camera.active and cfg and cfg.converge.follow) then return end
  if not gateOpen() then
    if cfg.converge.heldGate then endFocus() end
    conv.followGUID, conv.followToken = nil, nil
  end
  Camera:Wake()                     -- to follow, or for the catch-up to watch the facing
end

-- On quick wheel notches the eased zoom overshoots: for the frame or two
-- until its correction lands, the client reports a distance far outside the
-- step (measured: 25 -> 17.4 -> 23 on the first notch, 23 -> 0 -> 21 on the
-- next ones) while the picture zooms on smoothly. Such a reading is not where
-- the camera is; the curves and the aim keep the last sound one.
local soundZoom
local function steadyZoom(zoom)
  local e = ease
  if e and e.from and soundZoom
    and (zoom < min(e.from, e.to) - 0.5 or zoom > max(e.from, e.to) + 0.5) then return soundZoom end
  soundZoom = zoom
  return zoom
end

local lastZoom
driver:SetScript("OnUpdate", function(self, elapsed)
  local zoom = GetCameraZoom()
  local busy = stepEase(zoom)
  zoom = steadyZoom(zoom)
  if stepTransition(zoom) then busy = true end
  if stepTurns(elapsed) then busy = true end
  if stepFade() then busy = true end
  local carrying = stepCarry(zoom, elapsed)
  if stepConverge(zoom, elapsed) then busy = true end
  -- Changes below a two-thousandth of a yard do not keep the driver awake; the
  -- forced pass before sleeping lands on the exact values.
  if not lastZoom or abs(zoom - lastZoom) > 0.0005 then
    lastZoom, Camera.quiet = zoom, 0
    applyZoom(zoom)
  elseif busy then Camera.quiet = 0
  else
    Camera.quiet = Camera.quiet + elapsed
    if Camera.quiet > FOCUS_SETTLE and not cfg.converge.heldGate then releaseFocus() end
    if Camera.quiet > 0.5 and not conv.watch and not carrying then
      conv.steer = nil            -- the facing is not watched while asleep: no steering is read into the gap
      stopConverge()              -- the next gesture picks its distance afresh; offset changes made while asleep are not turned
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
  beginFocus()
  armConverge()
  if not zoomSetting("reactive") or increments ~= 1 then
    stopEase()
    Camera:Wake()
    return native(increments + (zoomSetting("reactive") and 0 or zoomSetting("addAlways")))
  end
  local zoom = GetCameraZoom()
  local target = ease and ease.wheel and not ease.fix and ease.to or nil
  local step = 1 + zoomSetting("addAlways")
  if target and abs(target - zoom) > zoomSetting("incAddDifference") then step = step + zoomSetting("addIncrements") end
  -- A change of direction starts again from where the camera is.
  if target and ((zoomIn and target > zoom) or (not zoomIn and target < zoom)) then target = nil end
  target = target or zoom
  local raw = step
  if zoomIn then
    if target - step < 0 then
      -- Going to first person: the un-eased fallback below must cover the whole
      -- remaining distance or it stops short of it.
      if target > 0 then raw = zoom end
      target = 0
    else target = target - step end
  elseif zoom == 0 then                       -- first person -> nearest third person
    stopEase()
    Camera:Wake()
    return native(0.05)
  else target = min(maxDistance(), target + step) end
  -- Already at the limit being asked for.
  if (target == 0 and zoom == 0) or (target >= maxDistance() and zoom >= maxDistance()) then return end
  local speed = max(0.01, tonumber(GetCVar("cameraZoomSpeed")) or 1)
  local duration = min(zoomSetting("maxZoomTime"), abs(target - zoom) / speed)
  if duration < EASE_INTERVAL then             -- too short to ease: plain native zoom
    stopEase()
    Camera:Wake()
    return native(raw)
  end
  startEase(target, duration, zoomSetting("easing"), true)
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
  endFocus(); stopConverge()
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
local function runEvaluate()
  queued = false
  if Camera.active then evaluate() end
end
queueEvaluate = function()
  if queued then return end
  queued = true
  C_Timer.After(0, runEvaluate)
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
  config.converge = type(config.converge) == "table" and config.converge or {}
  -- The first default distance (25) was too short for the untargeted fallback.
  -- rev 2: back to 25 yards. Measured in game on an NPC 22 yards away, 40 left
  -- it about 47 pixels off between first and third person; a stored 40 was
  -- the rev 1 default, not a choice.
  if (config.converge.rev or 1) < 2 then
    if config.converge.distance == 40 then config.converge.distance = nil end
    config.converge.rev = 2
  end
  -- rev 3: the open reticle follows the unit under it (owner request); the
  -- stored false was the default of an option that could not work.
  if config.converge.rev < 3 then config.converge.follow, config.converge.rev = nil, 3 end
  -- rev 4: target focus off for zooms (owner request). The engine lets the
  -- view swing back when the focus is released after a zoom; the turn by the
  -- target's distance stays where the zoom left it.
  if config.converge.rev < 4 then config.converge.focus, config.converge.rev = nil, 4 end
  -- rev 5: focus back on. It is what brings the reticle onto the target; the
  -- swing back is now prevented by holding it while that target stays selected.
  if config.converge.rev < 5 then config.converge.focus, config.converge.rev = nil, 5 end
  -- rev 6: the camera's sideways offset measured in game is 1.11 times the
  -- shoulder setting (orc); a stored 1 was the default, not a choice.
  if config.converge.rev < 6 then
    if config.converge.scale == 1 then config.converge.scale = nil end
    config.converge.rev = 6
  end
  config.converge.followStrength = nil      -- measured: a focus strength above 1 adds nothing
  -- rev 7: the limit now also bounds the turn that stands in for the game's
  -- focus; a stored 45 was the default of the build before.
  if config.converge.rev < 7 then
    if config.converge.aimLimit == 45 then config.converge.aimLimit = nil end
    config.converge.rev = 7
  end
  -- rev 10: soft targeting is no longer used by anything here; keys of
  -- builds that never left the owner's machine go with it.
  if config.converge.rev < 10 then
    local old = config.converge
    old.soft, old.softMode, old.heldSoft, old.heldFocus, old.heldGate, old.stickArc, old.rev = nil, nil, nil, nil, nil, nil, 10
  end
  for key, value in pairs(shipped.converge) do if config.converge[key] == nil then config.converge[key] = value end end
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
  if cfg and not self.active then endFocus() end     -- a zoom the last session did not finish
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
    if addon.SetMouseoverHeld then hooksecurefunc(addon, "SetMouseoverHeld", gateChanged) end
  end
  for _, event in ipairs({"PLAYER_ENTERING_WORLD", "PLAYER_MOUNT_DISPLAY_CHANGED", "UNIT_ENTERED_VEHICLE",
    "UNIT_EXITED_VEHICLE", "PLAYER_CONTROL_GAINED", "CINEMATIC_STOP", "PLAYER_LOGOUT", "PLAYER_TARGET_CHANGED"}) do
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
    awaitingRegen = nil
    for name, text in pairs(deferred) do deferred[name] = nil; setCVar(name, text) end
    return
  end
  if event == "PLAYER_LOGOUT" then gaugeEnd(); endFocus(); return end
  if event == "PLAYER_TARGET_CHANGED" then
    -- The unit the focus was on is no longer the target: nothing to stay on.
    if cfg and cfg.converge.held then endFocus(); gaugeEnd() end
    if conv.home ~= nil then Camera:Wake() end     -- the catch-up may start now, or has to stand down
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
  gaugeEnd(); endFocus(); stopConverge(); plate.release()
  if cfg.converge.enabled and cfg.converge.follow then plate.build() end
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
    gaugeEnd(); stopConverge(); plate.release()
    if faded then fadeUI(1, 0) end
    current = nil
    driver:Hide()
    events:UnregisterAllEvents(); sitEvents:UnregisterAllEvents()
    awaitingRegen = nil
    clear(deferred)
    endFocus()                         -- after the clear: a write refused in combat is deferred again
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
    for index = 1, 2 do
      local name = index == 1 and YAW or PITCH
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
  cfg.combatDeferred = nil           -- a record earlier versions wrote and nothing read
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
  endFocus()
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
    addon:OpenOptions("camera")
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
  local c = cfg.converge
  print(("Aim convergence: %s; fallback distance=%s; scale=%s; target focus=%s (strength %s, pitch %s)%s; enemy focus CVar=%s; interact=%s")
    :format(c.enabled and "on" or "off", tostring(c.distance), tostring(c.scale), c.focus and "on" or "off", tostring(c.strength),
      tostring(c.pitch), c.held and (", held now, yaw CVar " .. tostring(GetCVar(FOCUS[1]))) or "", tostring(GetCVar(FOCUS[3])), tostring(GetCVar(FOCUS[6]))))
  local offAxis = conv.home and conv.applied - convergeAngle(shoulderAt(zoom), c.distance) - conv.home
  print(("Aim convergence yaw: %s; now=%s; last: unit=%s, distance=%s (%s); camera %.3f deg left of the character's facing%s; aim=%s (limit %s), follow=%s (other units by the game's soft target: %s), zoom sticks=%s (%s deg), stay=%s, catch-up=%s; gate %s")
    :format(conv.live and "zooming" or "idle", conv.mode or "none", conv.unit or "none",
      conv.distance and ("%.1f"):format(conv.distance) or "none", conv.source or "none", conv.applied,
      offAxis and (", %.3f of it from aiming"):format(offAxis) or "",
      c.aim and "on" or "off", tostring(c.aimLimit), c.follow and "on" or "off", c.softFollow and "on" or "off", c.stick and "on" or "off", tostring(c.stickAngle),
      c.stay and "on" or "off", c.catchUp and "on" or "off",
      gateOpen() and "open" or "closed"))
  print(("Positions: yours %s, target %s, under the reticle %s. Game focus: %s; last: %s. Nameplate following: %s")
    :format(position("player") and "given" or "not given", UnitExists("target") and (position("target") and "given" or "not given") or "-",
      UnitExists("mouseover") and (position("mouseover") and "given" or "not given") or "-",
      c.held and ("on, swivel %s"):format(carry.psi and ("%.2f"):format(carry.psi) or "not read") or "off",
      conv.handed or "none yet",
      plate.problem and ("failed: " .. plate.problem) or plate.guid and "on a unit now" or plate.ready and "ready" or "not used yet"))
  print("/sqms camera status | on | off | restore | capture | options | takeover | release")
end
