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
    converge = {enabled = false, focus = true, strength = 1, distance = 25, scale = 1.11, pitch = 0, rev = 13, follow = true,
      aim = true, aimLimit = 30, catchUp = true, stay = true, stick = true, stickAngle = 6, softFollow = true, softStick = true, handSteers = true, walks = true, interact = false, firstPersonStep = false}}
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
  if combat and restricted[name] == nil then
    -- The client says which settings it will not have written in combat (SoftTargetEnemy is one): asked
    -- once, and then not tried, so that no blocked action is reported.
    local ok, _, _, _, _, _, secure = pcall(C_CVar.GetCVarInfo, name)
    restricted[name] = ok and secure and true or false
  end
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
--   were found: nothing else follows such a unit). Tried and dropped the
--   same day: strips hung on the unit's nameplate to tell by hover how far
--   off the reticle it stands; while mouselooking the client gives frames
--   no hover (C_GamePad.SetAllowHoverEventsWithFreeLook was already on).
-- * Zoom sticks: with nothing selected and no unit with a position near the
--   reticle, the same soft target is switched on for the length of a zoom
--   and what it finds is treated as the target is (focus and carry).
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
-- The view coming back to where it rests: time constant while the character moves, degrees a second at
-- least, and the time constant after the open reticle's following has ended.
local REALIGN = {time = 0.35, least = 10, home = 0.2}
local GAUGE_YARDS = {400, 200, 100, 60}
local sin, cos, tan, atan, rad, sqrt, exp, atan2 = math.sin, math.cos, math.tan, math.atan, math.rad, math.sqrt, math.exp, math.atan2
local conv = {applied = 0, quiet = huge}
-- (Three constants live in the carry table: this file's main chunk is at the 200 local variables Lua allows.)
local gauge, carry = {}, {
  LAG = 0.14,                       -- seconds by which the engine's answer trails a turn (twice its spring's time)
  FOLLOW_RATE = 120,                -- degrees per second at most while the open reticle's hold is taken over
  NEAR = 10,                        -- yards within which the reticle's hold is left to the engine's own swivel
  FIRST_PERSON_STEP = 0.5,          -- yards the view steps out of first person while the reticle's hold is on (setting)
  SEEK = 0.1,                       -- seconds the soft target is given at each width of its cone to take the unit under the reticle
  BARE = 0.15,                      -- seconds without a unit under the reticle before nothing is taken to be under it
}
local function wrap(angle) return (angle + 180) % 360 - 180 end
-- Dead units are not turned onto, and what the view was turned onto and has died is let go.
function carry.dead(unit)
  local ok, dead = pcall(UnitIsDead, unit)
  return ok and not secret(dead) and dead == true
end
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
local function leaveHome(offset, onto)
  if conv.home == nil then conv.home = conv.applied - convergeAngle(offset, cfg.converge.distance) end
  conv.homing, conv.onto = nil, onto      -- onto: the unit's GUID, for the day it dies
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
-- The unit a zoom turns onto by its position. With the reticle open that is
-- only what is under it: a zoom must not pull the reticle off to the target.
local function aimUnit()
  if gateOpen() then return UnitExists("mouseover") and position("mouseover") and not carry.dead("mouseover") and "mouseover" or nil end
  -- A dead target is as good as none.
  if UnitExists("target") and not carry.dead("target") then return not UnitIsUnit("target", "player") and position("target") and "target" or nil end
  if cfg.converge.stick then return nearUnit() end
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
    local under = sameUnit("mouseover", guid) and position("mouseover") and true
    if under and not carry.dead("mouseover") then return "mouseover" end
    if under then conv.spent = true end
    local token = conv.followToken
    if not (token and sameUnit(token, guid)) then
      token = nil
      for index = 1, 40 do
        if sameUnit("nameplate" .. index, guid) then token = "nameplate" .. index; break end
      end
      conv.followToken = token
    end
    if token and position(token) then
      if not carry.dead(token) then return token end
      conv.spent = true                               -- it has died: see the open reticle's branch
    end
    conv.followGUID, conv.followToken = nil, nil      -- gone or dead: the next unit under the reticle is picked up
  end
  if UnitExists("mouseover") and position("mouseover") and not carry.dead("mouseover") then
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
  local other = c.heldOther
  c.held, c.heldGate, c.heldSoft, c.heldOther = nil, nil, nil, nil
  if other and SetPreferredGamepadInteractTarget then pcall(SetPreferredGamepadInteractTarget) end
  if carry.stepped then               -- back into first person
    carry.stepped = nil
    if nativeZoomIn and GetCameraZoom() < carry.FIRST_PERSON_STEP + 0.3 then nativeZoomIn(carry.FIRST_PERSON_STEP + 0.3) end
  end
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
  if other then
    local icon = addon.MouseoverInteractIcon     -- its keeping soft interact targeting off, which stood back for the hold
    if icon and icon.hold then
      icon.hold = nil
      if icon.ApplyPolicy then pcall(icon.ApplyPolicy, icon) end
    end
  end
  if carry.rearm then carry.rearm() end
end
-- The value a hold puts back: one still waiting to be put back counts, not
-- what an earlier hold left behind.
local function heldValue(name)
  local waiting = deferred[name]
  deferred[name] = nil
  return waiting or GetCVar(name)
end
-- Soft targeting has to be on before a fight starts: the client will not have it switched on in combat
-- (it guards SoftTargetEnemy, its range and SoftTargetForce; the cone and the two "locked" settings it does
-- not: read off the client, 2026-11-24). So while an enemy is selected out of combat, and through the fight
-- that follows, it is kept on, with the narrowest cone and with soft targets beside a selected target
-- switched off: nothing is soft-targeted at rest while a target is selected, and the reticle's hold opens
-- that up for as long as it is held. With nothing selected and no fight it is off, as ever. What the
-- settings were is kept with the settings table, so that a reload in a fight cannot lose it.
carry.ARMED = {SoftTargetEnemy = "3", SoftTargetEnemyArc = "0", SoftTargetWithLocked = "0"}
function carry.rearm(off)
  local c = cfg and cfg.converge
  if type(c) ~= "table" or c.held then return end   -- a hold is on: seen to when it ends
  local locked = InCombatLockdown and InCombatLockdown() and true or false
  local enemy = false
  if not off and UnitExists("target") and not carry.dead("target") then
    local ok, can = pcall(UnitCanAttack, "player", "target")
    enemy = ok and not secret(can) and can and true or false
  end
  local want = not off and Camera.active and c.enabled and c.follow and c.softFollow
    and (enemy or locked and type(c.arm) == "table") and true or false
  if want and type(c.arm) ~= "table" then
    if locked then return end
    local arm = {}
    for name in pairs(carry.ARMED) do arm[name] = heldValue(name) end
    c.arm = arm
    for name, value in pairs(carry.ARMED) do setCVar(name, value) end
  elseif not want and type(c.arm) == "table" then
    if locked then return end                       -- its SoftTargetEnemy cannot be put back in combat: when the fight is over
    local arm = c.arm
    c.arm = nil
    for name, value in pairs(arm) do setCVar(name, value) end
  end
end
-- The engine's focus. For the length of a zoom (reticle nil): on the target,
-- when the client gives no position for it; with nothing selected (zoom
-- sticks) on what the engine's soft target finds in front. For as long as
-- the open reticle is held: on the target it was opened on ("target"); or,
-- with nothing selected ("soft"), on what the soft target, its cone at the
-- narrowest, takes in front; or, with something ELSE selected ("other"), on the unit under the reticle, by
-- the game's second focus. All of it is put back afterwards.
--
-- "other": the game has two camera focuses, one for the enemy target and one for what is being interacted
-- with. The first goes for the selected target wherever there is one. The second follows the unit named to
-- it as the preferred interact target (SetPreferredGamepadInteractTarget), and that may be an enemy that is
-- not the target, at range (the owner's own test of 2026-11-24, which they had said would work: with that
-- focus on, a boar that was not the target was under the reticle 90 per cent of the time after the view had
-- been turned 5 degrees off it, and never with it off; the game listed no soft interact target the while).
-- So with something else selected the enemy focus is switched off for the hold and the interact focus on,
-- on the unit under the reticle; the target stays the target. The settings are those of that test.
-- NOT BORNE OUT since: six more runs of the same test the owner made straight after (read at their next
-- reload) did not show it. In the four clean ones, the unit standing 26 to 39 yards off, the view turned 5
-- degrees off it did not come back with the focus on; and the one run above fits a boar that walked the way
-- the test turned (its body takes a second to cross the reticle). The setting is off by default
-- (converge.interact); what remains to be tried is whether the focus holds a WALKING unit for as long as it
-- stays under the reticle.
local function beginFocus(reticle)
  local c = cfg.converge
  if not c.enabled or transFn then return end
  carry.since, carry.still = nil, nil   -- a release that was waiting: the gesture goes on
  if c.held then return end
  local want, soft, other = {}, nil, nil
  if reticle == "other" then
    if not SetPreferredGamepadInteractTarget then return false end
    local ok, guid = pcall(UnitGUID, "mouseover")
    if not ok or secret(guid) or type(guid) ~= "string" or carry.dead("mouseover") then return false end
    if not pcall(SetPreferredGamepadInteractTarget, "mouseover") then return false end
    other = guid
    local icon = addon.MouseoverInteractIcon
    if icon then icon.hold = true end                -- it keeps soft interact targeting off: not for the length of this
    want.SoftTargetInteract, want.SoftTargetInteractArc, want.SoftTargetInteractRange, want.SoftTargetInteractRangeIsHard = 3, 2, 45, 0
    want.softTargettingInteractKeySound, want.SoftTargetIconInteract = 0, 0
    want.SoftTargetWithLocked, want.SoftTargetMatchLocked = 2, 0
  elseif reticle == "soft" then
    -- The client does not let its soft targeting be switched on in combat: nothing is held then, and with
    -- nothing selected the reticle does not follow.
    if GetCVar("SoftTargetEnemy") ~= "3" and InCombatLockdown and InCombatLockdown() then return false end
    want.SoftTargetEnemy, want.SoftTargetEnemyArc, soft = 3, 0, true
  elseif reticle == "target" then
    -- The focus alone: the target is what it follows.
  elseif gateOpen() then return                      -- a zoom with the reticle open leaves the view where the reticle has it
  elseif UnitExists("target") and not carry.dead("target") then
    if not c.focus or UnitIsUnit("target", "player") then return end
    if c.aim and aimUnit() then return end           -- a unit with a position is aimed at by a real turn
  else
    if not (c.stick and c.softStick) or gateOpen() then return end
    if c.aim and aimUnit() then return end           -- the enemy near the reticle gives its position
    want.SoftTargetEnemy, want.SoftTargetEnemyArc, soft = 3, 1, true
  end
  for index, name in ipairs(FOCUS) do
    local kind = index % 3            -- 1 yaw strength, 2 pitch strength, 0 enable
    want[name] = kind == 1 and c.strength or kind == 2 and c.pitch or 1
  end
  if soft and reticle then
    -- The game's focus stays off until its soft target has taken what the reticle is to follow (stepCarry):
    -- it would turn the view to whatever else the soft target finds, or to the target.
    want[FOCUS[3]], want[FOCUS[6]] = 0, 0
    -- A corpse still selected must not stand in the soft target's way (neither setting is refused in combat).
    want.SoftTargetWithLocked, want.SoftTargetMatchLocked = 2, 0
  end
  if other then want[FOCUS[3]] = 0 end               -- the enemy focus would take the view to the target
  local held = {}
  for name in pairs(want) do held[name] = heldValue(name) end
  c.held, c.heldGate, c.heldSoft, c.heldOther = held, reticle and true or nil, soft, other
  for name, value in pairs(want) do
    if held[name] ~= nil then setCVar(name, value) end
  end
  -- The engine's focus does not seem to act in first person: while the
  -- reticle is held the view may sit a step outside it (setting, off).
  if reticle and c.firstPersonStep and nativeZoomOut and GetCameraZoom() < 0.05 then
    carry.stepped = true
    nativeZoomOut(carry.FIRST_PERSON_STEP)
  end
  carry.total, carry.psi, carry.blind, carry.time, carry.release, carry.stage, carry.ratio, carry.mark, carry.trail, carry.wide, carry.peak = 0, nil, 0, 0, nil, nil, nil, nil, nil, nil, nil
  carry.guid, carry.gone, carry.narrow = nil, nil, nil
  carry.live, carry.arc, carry.seek, carry.seekOff, carry.bare = nil, nil, nil, nil, nil
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
-- The open reticle's hold ends: what swivel the engine still holds is turned
-- as it lets go, so the view stays where the following left it.
local function releaseGate()
  local rest = gauge.saved and carry.psi or 0
  endFocus(); gaugeEnd()
  carry.psi, carry.since, carry.facing, carry.still, carry.wide, carry.guid, carry.gone, carry.narrow = nil, nil, nil, nil, nil, nil, nil, nil
  carry.live, carry.arc, carry.seek, carry.seekOff = nil, nil, nil, nil
  if abs(rest) > 0.05 then carry.release = {turn = rest, time = 0, done = 0} end
  Camera:Wake()
end
-- A reticle's soft hold that follows nothing any more: the game's focus off again and the cone narrow, until
-- the soft target has taken the next unit the reticle is to follow.
function carry.idle()
  local c = cfg.converge
  if not (c.heldGate and c.heldSoft and carry.live) then return end
  carry.live, carry.arc, carry.seek, carry.wide = nil, nil, nil, nil
  setCVar(FOCUS[3], 0)
  setCVar("SoftTargetEnemyArc", 0)
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
  if not c.held then
    gaugeEnd()
    carry.psi, carry.since, carry.facing, carry.still = nil, nil, nil, nil
    return false
  end
  local soft = c.heldGate and c.heldSoft and UnitExists("softenemy")
  if c.heldGate and c.heldSoft then
    -- The game's focus is let onto the soft target only once that is what the reticle is to follow: the very
    -- unit under it; or, with nothing under it and nothing selected, what stands straight ahead (the
    -- narrowest cone), as ever.
    local over = UnitExists("mouseover") and not carry.dead("mouseover")
    local okm, onIt = pcall(UnitIsUnit, "softenemy", "mouseover")
    onIt = soft and over and okm and not secret(onIt) and onIt and true or false
    -- Nothing under the reticle: for a moment's length, not for the single frames the picking misses.
    carry.bare = over and 0 or (carry.bare or 0) + elapsed
    local bare = carry.bare > carry.BARE
    if not carry.live then
      -- The narrowest cone takes only what stands straight ahead of the character, which the unit under the
      -- reticle often does not (the owner's presses of 2026-11-24: nothing taken at 8-15 and at 40-45 yards,
      -- and often not at 17-22). While that unit is not what the soft target has, the cone goes a step
      -- wider, twice; not to be had even then, the cone is narrow again until the reticle is on something else.
      if over and not onIt and not carry.seekOff and not carry.narrow then
        carry.seek = (carry.seek or 0) + elapsed
        if carry.seek > carry.SEEK then
          carry.seek = 0
          if (carry.arc or 0) < 2 then carry.arc = (carry.arc or 0) + 1
          else carry.arc, carry.seekOff = nil, true end
          setCVar("SoftTargetEnemyArc", carry.arc or 0)
        end
      elseif bare then
        carry.seek, carry.seekOff = nil, nil
        if carry.arc then
          carry.arc = nil
          setCVar("SoftTargetEnemyArc", 0)
          return true                               -- what the soft target has now, it took with the wider cone
        end
      end
      if not (onIt or (soft and bare and not carry.arc)) then return true end
      carry.live = true
      setCVar(FOCUS[3], 1)
    end
  end
  if soft and carry.guid and not sameUnit("softenemy", carry.guid) then
    -- Its cone wide, the game has gone over to another unit somewhere about (the first has died, or the
    -- other stands better for it; seen live: the view a quarter turn off, to a boar beside the character).
    -- That one is followed only if it is what is under the reticle.
    local ok, same = pcall(UnitIsUnit, "softenemy", "mouseover")
    if ok and not secret(same) and same then
      local okg, guid = pcall(UnitGUID, "softenemy")
      carry.guid = okg and not secret(guid) and guid or nil
    else carry.gone, carry.narrow = true, true end
  end
  if c.heldGate and c.heldSoft and (carry.gone or not soft) then
    carry.empty = (carry.empty or 0) + elapsed
    if conv.home == nil then
      carry.gone, carry.guid = nil, nil             -- the view is where it rests: as when the reticle was opened
      if carry.empty > 0.4 then carry.idle() end
    elseif carry.gone or carry.empty > 0.4 then
      -- What the soft target had is gone: the view comes back to where it
      -- rests, and the cone is narrow again for the next unit.
      if carry.wide then
        carry.wide = nil
        setCVar("SoftTargetEnemyArc", 0)
      end
      gaugeEnd()
      carry.psi = nil
      local extra = conv.applied - convergeAngle(shoulderAt(zoom), c.distance) - conv.home
      if abs(extra) < 0.05 then
        conv.home, carry.gone, carry.guid = nil, nil, nil
        carry.idle()
      else
        local share = min(abs(extra), max(abs(extra) * (1 - exp(-elapsed / REALIGN.home)), REALIGN.least * elapsed))
        turn(extra > 0 and -share or share)
      end
      return true
    end
  else carry.empty = nil end
  local facing = readFacing()
  local psi
  if c.heldSoft and not gauge.saved and not UnitExists("softenemy") then
    -- Nothing in front for the soft target to take: no waypoint for nothing.
  elseif c.stay and facing then
    -- Snapped: the reticle's unit must not be dropped for no longer standing
    -- straight ahead of the character (strafing does that at once). The
    -- soft target's cone goes to its widest for the rest of the hold.
    -- (Not again once the game has used the wide cone to go over to another unit.)
    if soft and not carry.guid then
      local ok, guid = pcall(UnitGUID, "softenemy")
      carry.guid = ok and not secret(guid) and guid or nil
    end
    if c.heldGate and c.heldSoft and not carry.wide and not carry.narrow then
      carry.wide = true
      setCVar("SoftTargetEnemyArc", 2)
    end
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
    local okg, onto = true, c.heldOther
    if not onto then okg, onto = pcall(UnitGUID, c.heldSoft and "softenemy" or "target") end
    leaveHome(offset, okg and not secret(onto) and onto or nil)
    -- The reticle's hold has to keep up with a unit that walks and an owner who strafes.
    local rate, ratio = c.heldGate and carry.FOLLOW_RATE or CARRY_RATE, carry.ratio or 1
    -- The engine's answer trails the turns by its spring: they are compared
    -- through a copy that trails alike. Only while the zoom stands still,
    -- its own shift of the unit would spoil the answer; and once per hold.
    local trail = carry.trail or carry.total
    trail = trail + (carry.total - trail) * (1 - exp(-elapsed / carry.LAG))
    carry.trail = trail
    if not carry.stage and was and conv.quiet > 0.05 and not c.heldGate then
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
    -- A long zoom never stands still for that answer. Turning far more than
    -- the swivel ever was without bringing it down is the same case: a unit
    -- too near (seen live: 29 degrees turned on a swivel of 3).
    carry.peak = max(carry.peak or 0, abs(psi))
    if not carry.stage and not c.heldGate and abs(carry.total) > 2.5 * carry.peak + 3 then carry.stage = "given" end
    -- A release that is due: no more turns, so that the swivel read at the end is where the engine has settled.
    if carry.still then rate = 0 end
    local step = carry.stage == "given" and 0 or psi * ratio * (1 - exp(-elapsed / CARRY_TIME))
    if c.heldGate and step ~= 0 and addon.Range then
      -- A unit close by is left to the engine's own swivel, which turns the view in place. Taken over, the
      -- view would have to swing right round the character for every step such a unit takes (seen live: a
      -- boar beside the character, and the view a quarter turn off in a second).
      local unit = c.heldSoft and "softenemy" or "target"
      if c.heldOther then unit = sameUnit("mouseover", c.heldOther) and "mouseover" or "none" end
      local ok, near = pcall(addon.Range.Within, addon.Range, unit, carry.NEAR)
      if not (ok and near == false) then step = 0 end   -- nor one that is not known to be further off
    end
    local limit = rate * elapsed
    step = max(-limit, min(limit, step))
    -- A zoom turns by no more than the owner allows; nothing ever turns far off the character's own line.
    local away = conv.applied - convergeAngle(offset, c.distance) - conv.home
    if (not c.heldGate and abs(carry.total + step) > c.aimLimit) or abs(away + step) > AWAY_LIMIT then step = 0 end
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
  leaveHome(offset, key)
  if conv.mode ~= mode or conv.followed ~= key then conv.tracked = nil end
  conv.followed = key
  track(wanted, elapsed, FOLLOW_TIME)
  conv.mode, conv.unit, conv.distance, conv.source = mode, unit, distance, unit .. " position"
  conv.bias = conv.applied - convergeAngle(offset, distance)
  conv.live, conv.aim, conv.watch = nil, nil, nil    -- a zoom meanwhile is carried by the holding itself
end
-- Hold by the mouseover alone. For a unit the client gives no position for,
-- and on which its own focus cannot be put because something else is
-- selected (the focus goes for the selected target then, whatever the soft
-- target is: tried live twice on 2026-11-24), all that is known is whether
-- the unit is under the reticle, and roughly how far off it is. (With nothing
-- selected this is not used: the soft target follows there or nothing does,
-- the owner's choice of 2026-11-24.)
--
-- This used to go after the unit: when it slipped out from under the reticle
-- the view glided to one side and the other to find it again, and learnt a
-- rate for it from where it was found. With one bit to go by that is a hunt,
-- and it looked like one: the owner's log of 2026-11-24 had the view
-- searching for 61 per cent of a press on a unit 42 yards off, and their
-- word was that it must not swing at all, only make up for their own
-- movement. So that is all it does now:
-- * What the character moves sideways is taken out by the unit's distance:
--   the view stays on the place the unit was held at while the owner walks
--   and strafes. Nothing else turns the view. The mouse turns it as ever.
-- * That distance is what the range checks say (a bracket five yards wide,
--   measured between the two units' reaches, see REACH), moved within the
--   bracket by the character's own steps towards the unit and away, and set
--   right at once when the bracket changes.
-- * A unit that walks out from under the reticle is not gone after: the
--   owner's hand brings the reticle back to it. Meanwhile the view goes on
--   making up for the character's movement about the place the unit was
--   held at (slipped off a standing unit by a wrong distance, the reticle
--   stays beside it that way). Taken well aside by the hand, or with the
--   unit out of sight, the hold rests (nothing is taken out) until the unit
--   is under the reticle again.
-- * Another unit that comes under the reticle and stays is the one held from
--   then on.
local lock = {
  SLEW = 120,                       -- degrees a second at most for what is turned: nothing lands in one frame
  -- Yards the range checks leave out. They compare a range with the distance between the two units' centres
  -- less both their combat reaches (the server emulators' Spell::CheckRange and GetCombatDistance; a
  -- character's reach is 1.5, a boar's or a scorpid's 0.6 to 0.85, an elder boar's 1.0), so a unit "between
  -- 30 and 35 yards" stands 32.3 to 37.3 from the character. Left out, the unit was taken to be about 8 per
  -- cent nearer than it is and the view turned that much too far for every step to the side.
  REACH = 2.3,
  ASK = 0.1,                        -- seconds between questions of range
  -- The unit's nameplate as a rangefinder (lock.plate). least: the plate's size at far yards from the camera;
  -- base: the furthest this client shows nameplates, from which it counts the far end of the sizing.
  SPAN = {least = 0.96, far = 145, base = 45},
  EASE = 0.06,                      -- seconds by which a plate's size trails its distance (measured: 0.692, then 0.5002 after 0.45 s on the way to 0.5)
  PULL = 0.25,                      -- seconds over which the distance is taken from the plate's reading
  SLACK = 1.5,                      -- yards a plate's reading may lie outside the range bracket and still be believed
  -- Following a unit that walks (lock.walk).
  MOVING = 0.3,                     -- yards a second from which the unit is taken to walk
  TEST = 0.14,                      -- degrees as seen: the one step that asks which way the unit went
  WAIT = 3,                         -- frames a step is given to show the unit under the reticle (and 0.03 s)
  ASKS = 8,                         -- steps in quick succession (they are forgotten at one and a half a second) after which the following gives up
  INTO = 0.3,                       -- yards inside an end of it that the view rides where its length is not known
  BACK = 0.2,                       -- yards behind its middle that the view rides where its length is known
  WIDE = 0.4,                       -- a unit's width as a share of its length (a boar: about 0.9 by 2.4 yards)
  CALM = 0.25,                      -- seconds the hand has to have been still before a step is taken
  DWELL = 0.3,                      -- seconds another unit is under the reticle before that one is held
  ASIDE = 6,                        -- degrees the hand has taken the view from the unit after which the hold rests
  GONE = 1,                         -- seconds without the unit's nameplate (out of range, or dead) after which the hold rests
}
-- (The picking's height, CursorCenteredYPos, was moved up and down the reticle's column for a while to go
-- after units that slip out from under the reticle's point. Everything drawn at the centred cursor went with
-- it: the owner saw the reticle and its dot shifting vertically, twice, and it is not done any more.)
-- The client reports the character's position in uneven steps (the owner's log of 2026-11-24: a frame with
-- twice the movement, then one with none), and turning by each report as it came made the view judder
-- whenever the character moved sideways. What is owed for that movement is paid out evenly: at the pace of
-- the last moments, plus a share of what is still outstanding.
function lock.sway(raw, elapsed)
  local dt = max(elapsed, 0.001)
  lock.flow = (lock.flow or 0) + (raw / dt - (lock.flow or 0)) * (1 - exp(-dt / 0.06))
  local owed = (lock.owed or 0) + raw
  local out = lock.flow * dt
  out = out + (owed - out) * (1 - exp(-dt / 0.12))
  lock.owed = owed - out
  return out
end
function lock.release()
  lock.guid, lock.token, lock.north, lock.west, lock.offset, lock.low, lock.high = nil, nil, nil, nil, nil, nil, nil
  lock.off, lock.aside, lock.other, lock.rest, lock.asked, lock.gone, lock.plated = nil, nil, nil, nil, nil, nil, nil
  lock.flow, lock.owed, lock.left = nil, nil, nil
  lock.pace, lock.ranged, lock.seen, lock.read, lock.away = nil, nil, nil, nil, nil
  lock.mode, lock.ask, lock.way, lock.into, lock.gap, lock.calm, lock.towards, lock.handed, lock.handedFor = nil, nil, nil, nil, nil, nil, nil, nil, nil
  lock.slow, lock.inside, lock.margin, lock.walked, lock.asks, lock.tired = nil, nil, nil, nil, nil, nil
  lock.long, lock.sure, lock.turned, lock.awayWas, lock.awayAt, lock.radial, lock.behind, lock.shift = nil, nil, nil, nil, nil, nil, nil, nil
  lock.wide, lock.at = nil, nil
end
-- Close by, a unit is wide under the reticle and every step it or the character takes would swing the view
-- far round: it is not followed. Nor is one of which the range checks cannot say that it is further off
-- (seen live: the character's own pet, three yards away, taken for a unit at the fallback distance, and the
-- view held on it while the character turned a quarter circle under it).
function lock.near()
  if not addon.Range then return false end
  local ok, near = pcall(addon.Range.Within, addon.Range, "mouseover", carry.NEAR)
  return not (ok and near == false)
end
-- Between which distances from the character the unit is, as far as the range checks can tell.
function lock.range(unit)
  if not addon.Range then return end
  local ok, low, high = pcall(addon.Range.Bracket, addon.Range, unit)
  if not ok then return end
  if low and high and high - low > 10 then high = low * 1.3 end   -- beyond the furthest check that answers
  -- (From the camera's pivot, which is a little ahead of the character.)
  return low and low + lock.REACH - PIVOT, high and high + lock.REACH - PIVOT
end
-- The unit's distance by its nameplate. The client sizes a nameplate by its distance from the camera, and an
-- addon may read a plate's scale although it may not ask where the plate is (the owner's idea of 2026-11-24:
-- "an invisible frame on the nameplate that has that fade value 1:1 for every distance unit"; tried live the
-- same hour with the sizing switched on for a second: the scale of the plate of the unit under the reticle
-- followed its distance as a smooth number, 0.5622 at about 39 yards from the camera with the sizing set from
-- 1 at the camera to 0.5 at 45 yards, and its alpha agreed). Nameplates.lua keeps that sizing on, so slight
-- that it is not seen (four per cent over 145 yards). With the unit under the reticle the camera, the pivot
-- and the unit are in line, so the unit is that distance less the zoom from the pivot. The selected plate is
-- sized otherwise (1.2) and says nothing; nor does a plate beyond the far end, or one the client keeps secret.
function lock.plate(unit, zoom)
  local span = addon.Nameplates and addon.Nameplates.rangefinder
  if not (span and C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return end
  local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
  if not (ok and plate) then return end
  local read, scale = pcall(plate.GetScale, plate)
  if not read or secret(scale) or type(scale) ~= "number" or scale >= 0.9999 or scale <= span.least + 0.0001 then return end
  return span.far * (1 - scale) / (1 - span.least) - zoom, scale
end
-- How fast the unit moves, as the game tells it (it does not tell which way), or nothing.
function lock.speed(unit)
  if not GetUnitSpeed then return end
  local ok, speed = pcall(GetUnitSpeed, unit)
  if ok and not secret(speed) and type(speed) == "number" then return speed end
end
-- A unit that walks is followed (the owner, 2026-11-24: "it should follow the mob"), and without looking for
-- it. The game tells how fast a unit moves; its nameplate tells how fast it comes nearer or goes further off;
-- what is left of its speed is what it moves across the view, and that over its distance is the rate the view
-- has to turn at. Two things are not told: which side it goes to, and how long it is.
--
-- How long: what the reticle picks of a unit is a box about its body, and a walking boar's is some 2.4 yards
-- long along its path (the owner's log of 2026-11-24: 2.3 and 2.5 yards walked across the view under a
-- reticle that stood still). Riding just inside its tail, as the first version did, is a yard from its
-- middle. So the length of each kind of unit is learnt, the first time one walks right through a reticle
-- that stands still (from the dot lighting up to its going out: what it walked across the view), and kept
-- (lock.sizes, saved). Seen at an angle a box is shorter across the view: by the share of its speed that
-- goes across, plus a part for its width. With the length known the middle is half of it in from an end.
--
-- Which side, three cases:
-- * It walks INTO a reticle that stands still: its head is at the reticle the moment the dot lights. One
--   small step to one side tells where its body is (under the reticle still: on that side; gone: on the
--   other, and it is walking towards the reticle, which need only wait for it), and so which way it walks.
--   Its length known, the view goes to its middle at once and turns with it; else it is let walk through
--   once, to be measured, and followed from its tail's passing.
-- * It stood under the reticle and walks out: one small step to one side, and one to the other side of
--   where it must be by then if it is not there. First: where the hand was last going; else by how far it
--   walked before its tail passed, where that says something; else back from its last walk.
-- * Lost while following: ahead first (the view turns a shade slower than the unit, so its tail is where a
--   unit lost is), then behind; found behind, it is taken to have turned round if its coming nearer or going
--   off changed with it, else the view had run ahead.
-- From then on the view turns with the unit, at its middle, until the game says it has stopped. With the
-- hand turning the view nothing is asked: the hand is doing the following. Steps in quick succession end it
-- for that unit: it must never look like a hunt.
-- vel: the unit's speed (nil: not told). spin: degrees a second about the pivot that it moves across the
-- view (nil: not known, or it stands). Returns the degrees to turn this frame.
lock.sizes = {}                                           -- yards a kind of unit is long, by its id; filled from the saved settings
function lock.kind(guid)
  return type(guid) == "string" and (guid:match("^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)%-") or guid:match("^(%a+)%-")) or nil
end
-- Yards of the unit that lie across the view, from its length and width: nil where they are not known.
function lock.extent(vel)
  local long = lock.long
  if not (long and vel and vel > 0) then return end
  local share = min(1, abs(lock.away or 0) / vel)         -- of its speed along the view
  return long * sqrt(1 - share * share) + (lock.wide or long * lock.WIDE) * share
end
-- How big a kind of unit is, from the game itself (the owner asked for a database of sizes; this is one): a
-- model scene's actor given the unit's model says what box is about it, and that box is what the reticle
-- picks (read live 2026-11-24: 2.31 by 0.90 yards for the Dire Mottled Boar, against 2.3 to 2.5 yards walked
-- across the view under a still reticle). Asked once per kind, hidden; the answer comes a frame or so later.
function lock.measure(unit, kind)
  if lock.asking or lock.boxless or not kind then return end
  if not lock.actor then
    local ok, scene = pcall(CreateFrame, "ModelScene", nil, UIParent)
    local actor
    if ok and scene then
      pcall(function()
        scene:SetSize(4, 4)
        scene:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
        scene:SetAlpha(0)
        if scene.EnableMouse then scene:EnableMouse(false) end
        actor = scene:CreateActor()
      end)
    end
    if not (actor and actor.SetModelByUnit and actor.IsLoaded and actor.GetActiveBoundingBox) then lock.boxless = true; return end
    lock.scene, lock.actor = scene, actor
  end
  local ok, took = pcall(lock.actor.SetModelByUnit, lock.actor, unit)
  if ok and took ~= false then lock.asking = {kind = kind, t = 0} end
end
-- The answer, when it is there: the kind it is for.
function lock.measured(elapsed)
  local ask = lock.asking
  if not ask then return end
  ask.t = ask.t + elapsed
  local actor = lock.actor
  local ok, loaded = pcall(actor.IsLoaded, actor)
  if not (ok and loaded) then
    if ask.t > 2 then
      lock.asking = nil
      if actor.ClearModel then pcall(actor.ClearModel, actor) end
    end
    return
  end
  lock.asking = nil
  local read, x1, y1, z1, x2, y2 = pcall(actor.GetActiveBoundingBox, actor)
  if actor.ClearModel then pcall(actor.ClearModel, actor) end
  if not read then return end
  if type(x1) == "table" and type(y1) == "table" then     -- (as two corners, where the client gives it so)
    x1, y1, x2, y2 = x1.x, x1.y, y1.x, y1.y
  end
  for _, value in ipairs({x1, y1, x2, y2}) do
    if secret(value) or type(value) ~= "number" then return end
  end
  if x1 == nil or x2 == nil or y1 == nil or y2 == nil then return end
  local long, wide = abs(x2 - x1), abs(y2 - y1)
  if long < 0.2 or long > 40 or wide < 0.1 or wide > 40 then return end
  lock.sizes[ask.kind] = {math.floor(long * 100 + 0.5) / 100, math.floor(wide * 100 + 0.5) / 100}
  return ask.kind
end
-- What is known of the held unit's size is taken up.
function lock.sized(kind)
  local size = kind and lock.sizes[kind]
  if type(size) == "table" then lock.long, lock.wide, lock.sure = tonumber(size[1]), tonumber(size[2]), true
  elseif type(size) == "number" then lock.long, lock.sure = size, true end
end
-- A walk through measured, or half of one: the unit's length from it.
function lock.learn(yards, vel, whole)
  if not (vel and vel > 0 and yards > 0.3 and yards < 12) then return end
  local share = min(1, abs(lock.away or 0) / vel)
  local across = sqrt(1 - share * share)
  if across < 0.5 then return end                         -- walking nearly along the view: too little of its length shows
  local long = yards / (across + lock.WIDE * share)
  if whole then
    local kind = lock.kind(lock.guid)
    local known = kind and lock.sizes[kind]
    if type(known) == "table" then return end              -- the game's own figure stands
    long = known and known + (long - known) * 0.5 or long -- a second look counts for half
    if kind then lock.sizes[kind] = math.floor(long * 100 + 0.5) / 100 end
  end
  lock.long, lock.sure = long, whole or lock.sure
end
function lock.walk(on, steered, zoom, elapsed, vel, spin, ahead)
  if abs(steered) > 0.02 then
    lock.calm, lock.handed, lock.handedFor = 0, steered > 0 and 1 or -1, 0
  else
    lock.calm = (lock.calm or 1) + elapsed
    lock.handedFor = (lock.handedFor or 9) + elapsed
    if lock.handedFor > 1.5 then lock.handed = nil end
  end
  lock.gap = on and 0 or (lock.gap or 0) + 1
  -- Steps are counted: more than a few in a short while and the unit is not being followed but hunted, which
  -- is what this must never look like. Then nothing more is asked until it is under the reticle and standing.
  lock.asks = max(0, (lock.asks or 0) - elapsed * 1.5)
  if lock.tired and on and not spin then lock.tired = nil end
  local test = lock.TEST * (ahead + zoom) / ahead        -- the step, in degrees about the pivot
  local testYards = rad(lock.TEST) * (ahead + zoom)       -- and what it is across the unit
  local across = spin and rad(spin) * ahead or 0         -- yards a second the unit moves across the view
  -- Its going along the view has changed sharply: it has turned, and may be walking the other way across.
  local away = lock.away or 0
  if vel and vel > lock.MOVING then
    if lock.awayWas and abs(away - lock.awayWas) > 0.35 * vel then lock.turned = 0.8 end
    lock.awayAt = (lock.awayAt or 0) + elapsed
    if lock.awayAt > 0.25 or not lock.awayWas then lock.awayWas, lock.awayAt = away, 0 end
  else
    lock.awayWas, lock.awayAt = nil, nil                 -- it stands: its next walk is not a turn
  end
  if lock.turned then
    lock.turned = lock.turned - elapsed
    if lock.turned <= 0 then lock.turned = nil end
  end
  -- It has come round to walking straight along the view and on round: a unit that turns in a curve walks
  -- the other way across the view from there on.
  local along = vel and vel > lock.MOVING and abs(away) / vel or 0
  if along > 0.93 then
    lock.radial = true
  elseif lock.radial and along < 0.85 then
    lock.radial = nil
    if lock.mode == "follow" then lock.way, lock.inside = -lock.way, nil end
  end
  if lock.behind then
    lock.behind = lock.behind - elapsed
    if lock.behind <= 0 then lock.behind = nil end
  end
  if lock.at and steered ~= 0 then lock.at = lock.at + rad(steered) * ahead end   -- the hand moves the reticle within it
  local mode = lock.mode
  if lock.tired then
    lock.mode, lock.ask = nil, nil
    return 0
  end
  -- To the unit's middle from an end of it that the reticle is at: `inside` yards in already, `towards` the
  -- side its body lies on. The glide that takes the view there.
  -- (Not quite its middle: a little behind it, lock.BACK. Where in the unit the view rests is then known
  -- (lock.at: yards to the left of its middle), and when it next walks out from under the reticle, how far
  -- it walked before it was gone says which way it went: less than half its length, and the near end passed.)
  local function middle(inside, towards)
    local extent = lock.extent(vel)
    local want = extent and extent / 2 + (towards == lock.way and -lock.BACK or lock.BACK) or lock.INTO
    lock.into = towards * deg(max(0, want - inside) / ahead)
    lock.inside = extent and towards == lock.way and inside or nil   -- (yards in from its tail, where that is the end)
    lock.at = extent and -lock.way * lock.BACK or nil
  end
  if mode == "enter" then
    -- It walked into a reticle that stood still: its head is at the reticle.
    local ask = lock.ask
    if lock.calm == 0 or not spin then                   -- the hand has taken over, or it stands: held as it is
      lock.mode, lock.ask = nil, nil
      return 0
    end
    ask.t, ask.wait = ask.t + elapsed, ask.wait + 1
    if ask.stage == 0 then
      ask.stage, ask.wait, lock.asks = 1, 0, lock.asks + 1
      return ask.side * test
    elseif ask.stage == 1 then
      if ask.wait < lock.WAIT then return 0 end
      if on then
        -- Still under the reticle: its body is on that side, and it walks the other way, over the reticle.
        lock.way = -ask.side
        local inside = testYards + across * ask.t
        if lock.long then
          lock.mode, lock.ask = "follow", nil
          middle(inside, ask.side)
        else
          lock.mode, lock.ask = "pass", {walked = inside}
        end
      else
        -- Gone: its body is on the other side and it walks towards the reticle, which waits for it.
        lock.way = ask.side
        ask.stage, ask.wait, ask.t = 2, 0, 0
      end
      return 0
    else
      if on then
        if lock.long then
          lock.mode, lock.ask = "follow", nil
          middle(0, -lock.way)
        else
          lock.mode, lock.ask = "pass", {walked = 0}
        end
      elseif ask.t > 0.4 then
        lock.mode, lock.ask = nil, nil                    -- it did not come: held as it is
      end
      return 0
    end
  end
  if mode == "pass" then
    -- Its length is not known: it is let walk through once, the view standing still, and measured.
    local ask = lock.ask
    if lock.calm == 0 or not spin then
      lock.mode, lock.ask = nil, nil
      return 0
    end
    if lock.gap >= 2 then
      -- Its tail has passed: that was its length across the view. On after it, to its middle.
      lock.learn(ask.walked - across * 2 * elapsed, vel, true)
      lock.mode, lock.ask, lock.gap = "follow", nil, -2   -- (the step is given the picking's frames before it counts as lost)
      middle(testYards, lock.way)
      return lock.way * (test + spin * 2 * elapsed)
    end
    ask.walked = ask.walked + across * elapsed
    return 0
  end
  if mode == "ask" then
    local ask = lock.ask
    if lock.calm == 0 or not vel then                    -- the hand has taken over, or the unit is no longer told of
      lock.mode, lock.ask = nil, nil
      return 0
    end
    if lock.asks > lock.ASKS then                        -- too many: enough
      lock.mode, lock.ask, lock.tired, lock.towards, lock.margin = nil, nil, true, nil, nil
      return 0
    end
    ask.held = (ask.held or 0) + elapsed
    local rate = spin or 0                               -- (it may have stopped meanwhile: then it is where it stopped)
    ask.t, ask.wait = ask.t + elapsed, ask.wait + 1
    local step = ask.way * rate * elapsed                -- with the unit, should this be its way
    if on then
      local way = ask.way
      lock.ask = nil
      if ask.stage ~= 1 and ask.from == "follow" and not lock.turned and not lock.behind then
        -- Found behind where the view was following, and nothing says it turned: the view had run ahead.
        -- It walks on as before; the reticle is at its head. (Found behind again soon after: it had turned.)
        way = -ask.way
        lock.way, lock.behind = way, 1.5
        if spin then lock.mode = "follow"; middle(testYards, -way) else lock.mode, lock.towards = nil, way end
        return 0
      end
      lock.way = way
      if spin then
        lock.mode = "follow"
        if ask.from ~= "follow" then lock.slow = 0.3 end
        middle(testYards, way)
      else
        lock.mode, lock.towards, lock.margin = nil, way, testYards   -- it had stopped: held where it is
      end
    elseif ask.wait > lock.WAIT and ask.held > 0.03 then
      if ask.stage == 1 then
        -- Not there: it went the other way, and has gone on that way meanwhile.
        step = step - ask.way * ((ask.took or test) + test + 2 * rate * (ask.t + 2 * elapsed))
        ask.stage, ask.way, ask.wait, ask.held = 2, -ask.way, 0, 0
        lock.asks = lock.asks + 1
      elseif ask.stage == 2 then
        step = step + ask.way * 1.5 * test                -- a little further that way, once
        ask.stage, ask.wait, ask.held = 3, 0, 0
        lock.asks = lock.asks + 1
      else
        -- Neither way: nothing more is done until it is under the reticle again.
        lock.mode, lock.ask, lock.rest, lock.flow, lock.owed, lock.left = nil, nil, true, nil, nil, nil
        lock.towards, lock.margin, lock.at = nil, nil, nil
      end
    end
    return step
  end
  if mode == "follow" then
    if not spin then
      -- It has stopped (or is no longer told of): held where it is. Stopped just as the reticle slipped
      -- off its tail: it is one step ahead.
      if lock.at and lock.into then lock.at = lock.at - rad(lock.into) * ahead end
      lock.mode, lock.towards, lock.margin, lock.into, lock.slow = nil, lock.way, lock.inside, nil, nil
      if vel and not on and lock.calm > lock.CALM then
        lock.mode, lock.ask, lock.asks = "ask", {stage = 1, way = lock.way, wait = 0, t = 0, from = "follow"}, lock.asks + 1
        return lock.way * test
      end
      return 0
    end
    -- For a moment after the start the view turns clearly less than the unit: how much of its speed goes
    -- across the view is not well known yet, and a view that falls behind finds the unit again ahead of it
    -- without a doubt, where one that has run ahead cannot tell that from a unit that turned round.
    local slow = lock.slow
    if slow then
      slow = slow - elapsed
      lock.slow = slow > 0 and slow or nil
    end
    local share = slow and 0.85 or 1
    local step = lock.way * spin * share * elapsed
    local inside = lock.inside and lock.inside - (1 - share) * across * elapsed
    if lock.at then lock.at = lock.at - lock.way * (1 - share) * across * elapsed end   -- falling back in it
    -- Where in it the view is, is kept account of: it is drawn, gently, to its place a little behind the middle.
    if lock.at and not lock.into and on then
      local move = (-lock.way * lock.BACK - lock.at) * (1 - exp(-elapsed / 0.4))
      step, lock.at = step + deg(move / ahead), lock.at + move
    end
    local into = lock.into
    if into and on then
      local part = into * (1 - exp(-elapsed / 0.07))
      step, into = step + part, into - part
      lock.into = abs(into) > 0.01 and into or nil
      if inside then inside = inside + (part * lock.way > 0 and 1 or -1) * rad(abs(part)) * ahead end
    end
    lock.inside = inside
    if lock.gap == 2 then
      if lock.calm > lock.CALM then
        -- Lost while following. Its going along the view changed a moment ago: it has turned, and a unit that
        -- turned and is lost walks the other way across now (had it kept its side, the view would have kept
        -- it): behind first. Else the view fell behind, as it is made to: ahead first.
        -- (Behind: the view and the unit have been going opposite ways since it went, so it is further off.)
        local first = lock.turned and -lock.way or lock.way
        local took = test + (first ~= lock.way and 6 * spin * elapsed or 0)
        lock.mode, lock.ask, lock.asks = "ask", {stage = 1, way = first, wait = 0, t = 2 * elapsed, from = "follow", took = took}, lock.asks + 1
        step = step + first * took
      else
        lock.mode, lock.towards, lock.margin = nil, nil, nil   -- the hand took the reticle off it
      end
    end
    return step
  end
  -- Held still on it. How far it walks across the view while it is still under the reticle:
  if spin and on then
    lock.walked = (lock.walked or 0) + across * elapsed
  elseif on and lock.walked then
    lock.walked, lock.margin, lock.at = nil, nil, nil    -- it stopped again under the reticle: where in it the view rests is no longer known
  end
  -- It has just walked out from under the reticle.
  if lock.gap == 2 and spin and not lock.rest and lock.calm > lock.CALM then
    local way
    local extent = lock.extent(vel)
    if lock.at and extent and lock.walked and abs(lock.at) > 0.1 then
      -- Where in it the view rested is known. Gone after less than half its length: the end on the view's
      -- side of its middle has passed, so it walks away from that side; after more: the far end, the other way.
      local side = lock.at > 0 and 1 or -1
      way = lock.walked - 2 * across * elapsed < extent / 2 and -side or side
    end
    way = way or lock.handed
    if not way then                                      -- nothing to go by: one side and the other by turns
      lock.entries = (lock.entries or 0) + 1
      way = lock.entries % 2 == 0 and 1 or -1
    end
    lock.mode, lock.ask, lock.asks = "ask", {stage = 1, way = way, wait = 0, t = 2 * elapsed, walked = lock.walked}, lock.asks + 1
    lock.walked = nil
    return way * (test + spin * 2 * elapsed)
  end
  if lock.gap == 2 then lock.walked = nil end
  return 0
end
-- The unit to ask: under the reticle it is the mouseover, else its nameplate.
function lock.unit(on)
  if on then return "mouseover" end
  local token = lock.token
  if token and sameUnit(token, lock.guid) then return token end
  for index = 1, 40 do
    token = "nameplate" .. index
    if sameUnit(token, lock.guid) then lock.token, lock.plated = token, true; return token end
  end
  lock.token = nil
end
function lock.begin(c, offset, entered)
  local ok, guid = pcall(UnitGUID, "mouseover")
  if not ok or secret(guid) or type(guid) ~= "string" or carry.dead("mouseover") or lock.near() then return false end
  lock.release()
  local low, high = lock.range("mouseover")
  lock.guid, lock.low, lock.high = guid, low, high
  lock.dist = max(3, low and high and (low + high) / 2 or high or low and low * 1.2 or c.distance)
  local seen = lock.plate("mouseover", GetCameraZoom())
  if seen and (not low or seen > low - lock.SLACK) and (not high or seen < high + lock.SLACK) then
    lock.dist, lock.ranged, lock.seen = max(3, seen), true, seen
  end
  lock.read = seen
  lock.off, lock.aside, lock.asked = 0, 0, 0
  local kind = lock.kind(guid)
  lock.sized(kind)
  if not lock.long or not lock.wide then lock.measure("mouseover", kind) end
  -- It came under a reticle that had been open and still, and it is walking: it walked in, head first.
  if entered and c.walks then
    local vel = lock.speed("mouseover")
    if vel and vel > lock.MOVING then
      lock.entries = (lock.entries or 0) + 1
      lock.mode, lock.ask, lock.calm = "enter", {stage = 0, wait = 0, t = 0, side = lock.entries % 2 == 0 and 1 or -1}, 1
    end
  end
  return true
end
-- One frame. False once the unit is let go.
function lock.step(c, facing, steered, zoom, offset, elapsed)
  local guid = lock.guid
  local on = sameUnit("mouseover", guid)
  local died = on and carry.dead("mouseover")
  if died then conv.spent = true end
  if died or on and lock.near() then
    lock.close = on and not died or nil   -- come close: the view stays as it is while the unit is under the reticle
    lock.release()
    return false
  end
  if on then
    lock.off, lock.aside, lock.other, lock.rest, lock.gone = 0, 0, nil, nil, nil
  else
    lock.off, lock.aside = lock.off + elapsed, lock.aside + steered
    -- Another living unit has come under the reticle and stayed there: that one is held from the next frame
    -- on (the target by the game's own focus; the reticle's branch sees to either).
    if UnitExists("mouseover") and not carry.dead("mouseover") then
      lock.other = (lock.other or 0) + elapsed
      if lock.other > lock.DWELL then
        lock.close = true                               -- the view stays as it is meanwhile
        lock.release()
        return false
      end
    else
      lock.other = nil
    end
  end
  -- How far off the unit is; and off the reticle, whether it is still there at all.
  lock.asked = lock.asked + elapsed
  if lock.asked >= lock.ASK then
    lock.asked = 0
    local unit = lock.unit(on)
    if unit then
      if not on and carry.dead(unit) then               -- it has died beside the reticle: nothing to stay turned for
        conv.spent = true
        lock.release()
        return false
      end
      lock.low, lock.high, lock.gone = lock.range(unit)
      if on then lock.unit(false) end                   -- its nameplate, for the moment it leaves the reticle
    elseif lock.plated then                             -- (with enemy nameplates hidden there is no telling)
      lock.gone = (lock.gone or 0) + lock.ASK
    end
  end
  if not on and not lock.rest and (abs(lock.aside) > lock.ASIDE or (lock.gone or 0) > lock.GONE) then
    lock.rest, lock.flow, lock.owed, lock.left = true, nil, nil, nil
  end
  local step = 0
  local beside = offset * cfg.converge.scale
  local north, west = position("player")
  if north and lock.north then
    local heading = rad(facing + conv.applied)
    local toNorth, toWest = north - lock.north, west - lock.west
    if abs(toNorth) + abs(toWest) < 5 then              -- a jump is no movement
      -- Towards the unit or away: its distance changes by as much. (The view's line passes beside the
      -- pivot by the shoulder's offset, so the unit stands that much to the right of where the view looks.)
      local toward = heading - rad(convergeAngle(offset, lock.dist))
      local nearer = toNorth * cos(toward) + toWest * sin(toward)
      lock.pace = (lock.pace or 0) + (nearer / max(elapsed, 0.001) - (lock.pace or 0)) * (1 - exp(-elapsed / 0.1))
      local dist = lock.dist - nearer
      local slack = lock.ranged and lock.SLACK or 0     -- a plate's reading is believed a little beyond the bracket
      if lock.low and dist < lock.low - slack then dist = lock.low - slack end
      if lock.high and dist > lock.high + slack then dist = lock.high + slack end
      lock.dist = max(3, dist)
      -- To the left of the view or the right: taken out by how far along the view the unit is.
      if not lock.rest then
        local ahead = sqrt(max(1, lock.dist * lock.dist - beside * beside))
        step = lock.sway(-deg((toWest * cos(heading) - toNorth * sin(heading)) / ahead), elapsed)
      end
    end
  end
  lock.north, lock.west = north, west
  -- Its nameplate's reading, where there is one: what the character's own steps have changed of it since the
  -- plate last caught up is added, and the distance is drawn to it. (Read after the view was turned for this
  -- frame's steps: the distance is for the next.)
  if lock.asking and lock.measured(elapsed) then lock.sized(lock.kind(guid)) end
  local token = on and "mouseover" or lock.token or lock.unit(false)
  local vel = token and lock.speed(token)
  local spin
  do
    local seen = token and lock.plate(token, zoom)
    if seen then
      -- What the unit itself moves along the view: the reading's change, less the character's own steps.
      -- A reading that changes faster than the unit can move is a plate still finding its size (one that has
      -- just appeared eases in over a quarter of a second: 6 yards too far at first in the owner's log).
      local rate = lock.read and (seen - lock.read) / max(elapsed, 0.001) + (lock.pace or 0)
      lock.read = seen
      local steady = rate and abs(rate) <= (vel or 9) + 3
      if steady then lock.away = (lock.away or rate) + (rate - (lock.away or rate)) * (1 - exp(-elapsed / 0.06)) end
      seen = seen - lock.EASE * (lock.pace or 0)
      lock.seen = seen
      if steady then
        -- The camera may stand nearer than its zoom says (the ground behind it pushes it in; after a zoom
        -- out it is still on its way): the reading is short by as much, whatever the unit does (the owner's
        -- log of 2026-11-24: a scorpid 39 to 43 yards off by the range checks read 25 to 26 at zoom 25, and
        -- the following never began). What the reading is out by is kept and moved only as far as the range
        -- checks demand, so that the unit's own coming and going is still followed to the inch. A reading
        -- the range checks agree with is taken as it is.
        local low, high = lock.low and lock.low - lock.SLACK, lock.high and lock.high + lock.SLACK
        local shift = lock.shift or 0
        if (not low or seen > low) and (not high or seen < high) then
          shift = 0
        else
          local want = seen + shift
          if low and want < low then shift = shift + low - want elseif high and want > high then shift = shift + high - want end
        end
        lock.shift = shift
        lock.dist = max(3, lock.dist + (seen + shift - lock.dist) * (lock.ranged and 1 - exp(-elapsed / lock.PULL) or 1))
        lock.ranged = true
      end
      -- Across the view: what is left of its speed. Degrees a second about the pivot.
      if steady and vel and vel > lock.MOVING and lock.ranged then
        spin = deg(sqrt(max(0, vel * vel - lock.away * lock.away)) / sqrt(max(1, lock.dist * lock.dist - beside * beside)))
      end
    else
      lock.seen, lock.read = nil, nil
    end
  end
  if c.walks then
    step = step + lock.walk(on, steered, zoom, elapsed, vel, spin, sqrt(max(1, lock.dist * lock.dist - beside * beside)))
  end
  if on and not c.handSteers then step = step - steered end   -- the setting is off: the view is held still on the unit against the hand
  -- A zoom shifts the unit by the shoulder's convergence.
  if lock.offset and lock.offset ~= offset then
    step = step + convergeAngle(offset, lock.dist) - convergeAngle(lock.offset, lock.dist)
  end
  lock.offset = offset
  leaveHome(offset, guid)
  -- Nothing lands in one frame: what is wanted beyond a quick turn's pace is carried into the next frames.
  step = step + (lock.left or 0)
  local most = lock.SLEW * elapsed
  local out = max(-most, min(most, step))
  lock.left = step - out
  step = out
  -- Never far off the character's own line: beyond that the view goes with the mouse again.
  if abs(conv.applied + step - convergeAngle(offset, c.distance) - conv.home) > AWAY_LIMIT then step, lock.left = 0, nil end
  turn(step)
  conv.mode, conv.unit, conv.distance, conv.source, conv.followed = "follow", "mouseover", lock.dist, "mouseover alone", guid
  conv.bias = conv.applied - convergeAngle(offset, lock.dist)
  conv.live, conv.aim, conv.watch = nil, nil, nil    -- a zoom meanwhile is carried by the holding itself
  conv.gateFollow = true
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
  if conv.home == nil then conv.homing = nil; return false end
  local extra = conv.applied - convergeAngle(offset, c.distance) - conv.home
  if abs(extra) < 0.05 then conv.home, conv.homing = nil, nil; return false end
  -- What the open reticle followed is gone (or the reticle closed): the
  -- view comes back to where it rests, by itself.
  if conv.homing then
    local share = min(abs(extra), max(abs(extra) * (1 - exp(-elapsed / REALIGN.home)), REALIGN.least * elapsed))
    turn(extra > 0 and -share or share)
    return true
  end
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
    lock.release()
    return false
  end
  local facing = readFacing()
  local steered = conv.steer and facing and wrap(facing - conv.steer) or 0
  conv.steer = facing
  conv.still = abs(steered) > 0.02 and 0 or (conv.still or 0) + elapsed
  local moving = was ~= nil and abs(zoom - was) > 0.0005
  conv.quiet = moving and 0 or conv.quiet + elapsed
  local offset = shoulderAt(zoom)
  if c.enabled and moving and not conv.live then    -- a zoom the wheel did not start
    -- Leaving first person, the first frame may already carry the offset.
    beginConverge(zoom, was < 0.05 and was or zoom)
  end

  -- The open reticle follows the unit under it, selected or not, and stays
  -- on it until the reticle closes.
  local gate = c.enabled and c.follow and gateOpen()
  lock.close = nil
  if gate and facing and (not c.held or c.heldGate) then
    local unit = c.aim and followUnit() or nil
    local wanted, distance
    if unit then wanted, distance = aimAngle(unit, facing, zoom) end
    -- Never far off the character's own line: beyond that the view goes with the mouse again.
    if wanted and abs(wanted) <= AWAY_LIMIT then
      if c.heldGate then releaseGate() end             -- by its position: the engine's focus is not needed
      lock.release()
      hold(unit, wanted, distance, offset, elapsed, "follow", conv.followGUID)
      conv.gateFollow = true
      return true
    end
    if not wanted then
      -- The game gives no position for what is there.
      if lock.guid then
        if lock.step(c, facing, steered, zoom, offset, elapsed) then return true end
      elseif not c.held then
        -- The dead are not followed, and a dead target is as good as none.
        local over = UnitExists("mouseover") and not carry.dead("mouseover")
        local target = UnitExists("target") and not carry.dead("target")
        if not over then conv.bare = (conv.bare or 0) + elapsed end   -- open on nothing, for this long
        local ok, same = pcall(UnitIsUnit, "mouseover", "target")
        if target and over and ok and not secret(same) and same then
          beginFocus("target")                         -- opened on the target: the engine's focus follows it
        elseif not target then
          -- Nothing selected: what the engine's soft target takes, and nothing else. Followed by the
          -- mouseover alone a unit was held worse than by the soft target, and the owner would rather have
          -- no following than that one here (2026-11-24). Not again in a press whose unit has died: the
          -- view goes back to where it rests instead of on to the next enemy in front.
          if c.softFollow and not conv.spent then beginFocus("soft") end
        elseif over then
          -- Something else is selected: by the mouseover alone. The game does have a soft target beside
          -- a selected target (SoftTargetWithLocked 2, SoftTargetMatchLocked 0), and it was the very unit
          -- under the reticle when tried live on 2026-11-24; but the game's focus, switched on then, went
          -- for the target all the same and took the view 2.7 and 12 degrees off that unit. The focus
          -- follows the target wherever there is one.
          -- The game's second focus first (beginFocus, "other"); where that is not to be had, or has not
          -- held the unit in this press, the hold by the mouseover alone.
          if c.interact and not conv.noOther and not (carry.noOther and InCombatLockdown()) and not lock.near() then
            carry.noOther = nil
            beginFocus("other")
            if c.heldOther then conv.otherOff, conv.otherNew = 0, nil; return true end
          end
          -- (Come under a reticle that was open on nothing and still: it walked in.)
          local entered = (conv.bare or 0) > 0.15 and (conv.still or 0) > lock.CALM
          conv.bare = nil
          if lock.begin(c, offset, entered) then return true end
          lock.close = lock.near() or nil              -- close by: nothing is turned, and nothing is turned back while it is there
        end
      elseif c.heldGate and c.heldOther then
        -- Held by the game's second focus. Dead: the hold ends and the view goes back. Not under the reticle
        -- for a second: the game is not holding it (out of the focus's reach, or a setting it would not take
        -- in a fight), and the hold by the mouseover alone has the rest of this press. Another unit under
        -- the reticle and staying: that one is named instead.
        local on = sameUnit("mouseover", c.heldOther)
        if on and carry.dead("mouseover") then
          releaseGate()
          conv.spent = true
        else
          conv.otherOff = on and 0 or (conv.otherOff or 0) + elapsed
          local stranger = not on and UnitExists("mouseover") and not carry.dead("mouseover")
          conv.otherNew = stranger and (conv.otherNew or 0) + elapsed or nil
          if conv.otherNew and conv.otherNew > lock.DWELL then
            local ok, same = pcall(UnitIsUnit, "mouseover", "target")
            releaseGate()                              -- (opened anew on it in the next frame: the target by its own focus)
            conv.otherNew = nil
            if ok and not secret(same) and same then conv.noOther = nil end
          elseif conv.otherOff > 0.35 then
            -- (In a fight the game may not have taken the settings: not tried again until it is over.)
            releaseGate()
            conv.noOther = true
            carry.noOther = InCombatLockdown() and true or nil
          end
        end
      elseif c.heldGate and not c.heldSoft then
        -- Opened on the target, and the target has died or is no more: the hold ends, the view goes back.
        if not UnitExists("target") or carry.dead("target") then
          releaseGate()
          conv.spent = true
        end
      end
    end
  else
    if c.heldGate then releaseGate() end               -- the reticle closed
    lock.release()
    conv.bare = nil
    if not gate then
      conv.followGUID, conv.followToken = nil, nil
      conv.spent, conv.noOther, conv.otherOff, conv.otherNew = nil, nil, nil, nil
    end
  end
  -- The reticle's following has ended (closed, or the unit is gone): back to where the view rests.
  if gate and (c.heldGate or lock.close) then conv.gateFollow = true
  elseif conv.gateFollow then
    conv.gateFollow = nil
    if conv.home ~= nil then conv.homing = true end
  end
  if not conv.live then
    conv.mode = gate and (c.heldGate and (c.heldSoft and "follow (the game's soft target)" or c.heldOther and "follow (the game's interact focus)" or "follow (the game's focus on the target)")
      or UnitExists("mouseover") and "follow (no position for this unit)" or "follow (nothing under the reticle)") or nil
    if conv.died and not c.held and not lock.guid then
      -- What the view was last turned onto has died (a zoom's turn stays otherwise): nothing to stay
      -- turned for, so back to where the view rests.
      if conv.died == conv.onto and conv.home ~= nil then conv.homing = true end
      conv.died = nil
    end
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
      leaveHome(offset, conv.aimGUID)
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
    if cfg.converge.heldGate then releaseGate() end
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
  -- rev 11: the open reticle follows by the mouseover alone; the soft target
  -- there is for whoever switches it on again.
  if config.converge.rev < 11 then config.converge.softFollow, config.converge.rev = nil, 11 end
  -- rev 12: with nothing selected the soft target is the default again. Tried live side by side, it keeps a
  -- walking unit on the reticle throughout where the mouseover alone slips and searches.
  if config.converge.rev < 12 then config.converge.softFollow, config.converge.rev = nil, 12 end
  -- rev 13: the hold by the game's interact focus was on by default for three minutes on 2026-11-24, on the
  -- strength of one test run. Six more runs the owner made straight after, read at their next reload, did
  -- not bear it out (four clean ones, the unit standing 26 to 39 yards off: the view turned 5 degrees off it
  -- did not come back with the focus on; the one run that had looked like it is explained by a boar walking
  -- the way the test turned). Off unless chosen, until it is shown to hold.
  if config.converge.rev < 13 then config.converge.interact, config.converge.rev = nil, 13 end
  for key, value in pairs(shipped.converge) do if config.converge[key] == nil then config.converge[key] = value end end
  -- How long each kind of unit is, as the reticle's following has measured it (lock.learn): by its id.
  if type(config.converge.sizes) ~= "table" then config.converge.sizes = {} end
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
  if cfg and not self.active then endFocus(); carry.rearm(true) end   -- a zoom the last session did not finish; soft targeting it left on
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
    "UNIT_EXITED_VEHICLE", "PLAYER_CONTROL_GAINED", "CINEMATIC_STOP", "PLAYER_LOGOUT", "PLAYER_TARGET_CHANGED",
    "NAME_PLATE_UNIT_REMOVED", "PLAYER_REGEN_ENABLED"}) do
    pcall(events.RegisterEvent, events, event)
  end
  pcall(events.RegisterUnitEvent, events, "UNIT_HEALTH", "target")
  self.active = true
  current, entered, delayUntil, lastZoom = nil, false, nil, nil
  clear(lastSituationZoom); clear(cameFrom)
  self:SettingsChanged()
end
events:SetScript("OnEvent", function(self, event, unit)
  if event == "UNIT_HEALTH" or event == "NAME_PLATE_UNIT_REMOVED" then
    -- What the view was turned onto has died: noted, and seen to by the driver.
    if conv.onto and conv.home ~= nil and type(unit) == "string" and sameUnit(unit, conv.onto) and carry.dead(unit) then
      conv.died = conv.onto
      Camera:Wake()
    end
    return
  end
  if event == "PLAYER_REGEN_ENABLED" then
    awaitingRegen = nil
    for name, text in pairs(deferred) do deferred[name] = nil; setCVar(name, text) end
    carry.rearm()                                  -- the fight is over: soft targeting off again unless an enemy is selected
    return
  end
  if event == "PLAYER_LOGOUT" then gaugeEnd(); endFocus(); carry.rearm(true); return end
  if event == "PLAYER_TARGET_CHANGED" then
    -- The unit the focus was on is no longer the target: nothing to stay on.
    if cfg and cfg.converge.held then endFocus(); gaugeEnd() end
    carry.rearm()
    if conv.home ~= nil then Camera:Wake() end     -- the catch-up may start now, or has to stand down
    return
  end
  lastZoom = nil
  Camera:Wake()
end)

-- For Nameplates.lua: the sizing of nameplates by distance that the reticle's hold reads (lock.plate), or
-- nothing while the reticle follows nothing.
function Camera:Rangefinder()
  local c = cfg and cfg.converge
  return self.active and c and c.enabled and c.follow and lock.SPAN or nil
end
function lock.plates()
  local plates = addon.Nameplates
  if plates and plates.started and plates.ApplyCVars then plates:ApplyCVars() end
end
-- Call after any edit of the settings table.
function Camera:SettingsChanged()
  if not cfg then return end
  normalize(cfg)
  lock.sizes = cfg.converge.sizes
  lock.plates()
  if not self.active then return end
  gaugeEnd(); endFocus(); stopConverge(); lock.release()
  carry.rearm()
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
    gaugeEnd(); stopConverge(); lock.release()
    if faded then fadeUI(1, 0) end
    current = nil
    driver:Hide()
    events:UnregisterAllEvents(); sitEvents:UnregisterAllEvents()
    awaitingRegen = nil
    clear(deferred)
    endFocus()                         -- after the clear: a write refused in combat is deferred again
    carry.rearm(true)
    if ticker then ticker:Cancel(); ticker = nil end
    if CameraZoomIn == zoomInHook then CameraZoomIn = nativeZoomIn end
    if CameraZoomOut == zoomOutHook then CameraZoomOut = nativeZoomOut end
    self.active = false
    lock.plates()                      -- the rangefinder's sizing of nameplates goes with it
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
  print(("Positions: yours %s, target %s, under the reticle %s. Game focus: %s; last: %s")
    :format(position("player") and "given" or "not given", UnitExists("target") and (position("target") and "given" or "not given") or "-",
      UnitExists("mouseover") and (position("mouseover") and "given" or "not given") or "-",
      c.held and ("on, swivel %s"):format(carry.psi and ("%.2f"):format(carry.psi) or "not read") or "off",
      conv.handed or "none yet"))
  print("/sqms camera status | on | off | restore | capture | options | takeover | release")
end
