-- SPDX-License-Identifier: MIT
-- Squanch-On shared range module (ns.Range).
--
-- The client has no distance API for units outside the group, only yes/no
-- checks at fixed distances. This module combines them into a bracket
-- (minYards < distance <= maxYards) and answers every range question from it.
--
-- Sources, in priority order (each bound records where it came from):
--   1 group distance  UnitDistanceSquared: exact, group members only, outdoors.
--   2 spell           C_Spell.IsSpellInRange on learned spells from the
--                     registered provider. Spells of 5 yards or less are
--                     ignored: Raptor Strike reports true at Auto Shot distance
--                     on this client and melee Auto Attack has no verdict.
--   3 item            C_Item.IsItemInRange by item ID (items need not be
--                     owned), binary search over the 5-yard steps below.
--   4 interact        CheckInteractDistance duel/follow, only when no item answered.
--   5 nameplate       a plate exists only inside nameplateMaxDistance.
--   6 visible         UnitIsVisible false means beyond about 100 yards.
--
-- Item and interact checks on a unit the player cannot attack are protected in
-- combat: the call raises a blocked-action error that pcall does not hide, so
-- they are never called there. Attackable units are exempt (same rule as
-- LibRangeCheck-3.0's InCombatLockdownRestriction).
--
--   unit kind            out of combat                    in combat
--   hostile              spell + harm items 5..45,100     same (items allowed):
--                        -> 5-yard brackets               5-yard brackets
--   friendly, grouped    exact when outdoors, else as     exact when outdoors, else
--                        ungrouped                        as ungrouped
--   friendly, ungrouped  spell + friend items 5..50,100   spell only (bound = that
--   (also pet, dead)     -> 5-yard brackets               spell's range); without a
--                                                         spell: plate (<= CVar) and
--                                                         visible (>= 100) only
--   neither              as friendly                      plate and visible only
--
-- UnitInRange is not used: it returns a secret value on this client.
-- Nothing here creates a frame, timer, event or OnUpdate: evaluation is on
-- demand and shared between callers for CACHE_SECONDS per unit GUID.
local _, ns = ...
local Range = {}
ns.Range = Range

local CACHE_SECONDS = 0.1
local ITEM_BUDGET = 6 -- item checks per evaluation
local MELEE_YARDS = 5
local FRIEND_YARDS = 40

-- {yards, itemID, ...}. Item IDs are data from LibRangeCheck-3.0 (MIT,
-- copyright 2023 The WeakAuras Team), its Era/Forever FriendItems and
-- HarmItems tables; a few candidates per distance, pre-1.12 items first.
local FRIEND_ITEMS = {
  {5, 1970, 8149, 15826, 16991}, {10, 17626, 17689, 21267, 23164},
  {15, 1251, 2581, 3530, 6450}, {20, 12450, 12451, 17757, 21519},
  {25, 13289}, {30, 954, 955, 1180, 1181}, {35, 18904},
  {40, 1713, 5205, 5323, 18662, 18640}, {45, 221316}, {50, 221315},
  {100, 5418, 17162, 23715},
}
local HARM_ITEMS = {
  {5, 8149, 15826, 16308, 17117}, {10, 9606, 9618, 10699, 17626},
  {15, 4559}, {20, 1191, 4388, 10645, 13892}, {25, 13289},
  {30, 835, 1404, 4941, 7734}, {35, 1399, 1402, 18904}, {40, 4945, 8348},
  {45, 221316}, {100, 5418, 17162, 23715},
}
-- CheckInteractDistance index, yards when true, yards when false. The distance
-- varies by race (duel 6-8, follow 25-28), so each answer uses its safe end.
local INTERACT = {{3, 8, 6}, {4, 28, 25}}

local function public(value) return not (issecretvalue and issecretvalue(value)) end

-- true/false for a plain boolean answer, nil for errors, secrets and no answer.
local function answer(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, value = pcall(fn, ...)
  if not ok or not public(value) then return nil end
  if value == true or value == 1 then return true end
  if value == false or value == 0 then return false end
end

local function atMost(entry, yards, source)
  if not entry.max or yards < entry.max then entry.max, entry.maxSource = yards, source end
end
local function atLeast(entry, yards, source)
  if not entry.min or yards > entry.min then entry.min, entry.minSource = yards, source end
end

local itemLists
local function itemList(attackable)
  if not itemLists then
    local exists = C_Item and C_Item.DoesItemExistByID
    local request = C_Item and C_Item.RequestLoadItemDataByID
    local function build(source)
      local list = {}
      for _, row in ipairs(source) do
        local items = {}
        for index = 2, #row do
          if answer(exists, row[index]) ~= false then
            items[#items + 1] = row[index]
            if request then pcall(request, row[index]) end
          end
        end
        if #items > 0 then list[#list + 1] = {yards = row[1], items = items, good = 1} end
      end
      return list
    end
    itemLists = {friend = build(FRIEND_ITEMS), harm = build(HARM_ITEMS)}
  end
  return attackable and itemLists.harm or itemLists.friend
end

-- One distance: the candidate that answered last time first, then one other.
local function probe(row, unit, budget)
  local items = row.items
  local result = answer(C_Item.IsItemInRange, items[row.good], unit)
  budget = budget - 1
  if result == nil and #items > 1 and budget > 0 then
    row.good = row.good % #items + 1
    result = answer(C_Item.IsItemInRange, items[row.good], unit)
    budget = budget - 1
  end
  return result, budget
end

-- Binary search between the bounds already known. A distance without an
-- answer (item data missing, item cannot target the unit) is stepped over.
local function searchItems(entry, unit, list)
  local low, high = 1, #list
  while low <= high and entry.min and list[low].yards <= entry.min do low = low + 1 end
  while high >= low and entry.max and list[high].yards >= entry.max do high = high - 1 end
  local budget = ITEM_BUDGET
  while low <= high and budget > 0 do
    local middle = math.floor((low + high) / 2)
    local index, result = middle, nil
    while index <= high and budget > 0 do
      result, budget = probe(list[index], unit, budget)
      if result ~= nil then break end
      index = index + 1
    end
    if result == true then
      atMost(entry, list[index].yards, "item"); entry.itemAnswered = true; high = middle - 1
    elseif result == false then
      atLeast(entry, list[index].yards, "item"); entry.itemAnswered = true; low = index + 1
    else
      high = middle - 1
    end
  end
end

local spellRanges = {}
local function spellRange(spellID, now)
  local known = spellRanges[spellID]
  if known and now - known.time < 5 then return known.min, known.max end
  local minimum, maximum
  local info = C_Spell and C_Spell.GetSpellInfo and select(2, pcall(C_Spell.GetSpellInfo, spellID))
  if type(info) == "table" then
    minimum, maximum = info.minRange, info.maxRange
  elseif GetSpellInfo then
    local ok, _, _, _, _, low, high = pcall(GetSpellInfo, spellID)
    if ok then minimum, maximum = low, high end
  end
  if not public(minimum) or type(minimum) ~= "number" then minimum = 0 end
  if not public(maximum) or type(maximum) ~= "number" then maximum = nil end
  if known then
    known.min, known.max, known.time = minimum, maximum, now
  else
    spellRanges[spellID] = {min = minimum, max = maximum, time = now}
  end
  return minimum, maximum
end

local function checkSpells(entry, unit, spells, now)
  if type(spells) ~= "table" or not (C_Spell and C_Spell.IsSpellInRange) then return end
  for _, spellID in ipairs(spells) do
    local minimum, maximum = spellRange(spellID, now)
    if not maximum or maximum > MELEE_YARDS then
      local reaches = answer(C_Spell.IsSpellInRange, spellID, unit)
      if reaches ~= nil and maximum and (not entry.reach or maximum > entry.reach) then entry.reach = maximum end
      if reaches == true then
        entry.spellHit = true
        if maximum then atMost(entry, maximum, "spell") end
        if minimum > 0 then atLeast(entry, minimum, "spell") end
      elseif reaches == false and maximum then
        if minimum <= 0 then
          atLeast(entry, maximum, "spell")
        else
          -- Too close or too far: decided once another check rules out "too close".
          entry.deadZone = entry.deadZone or {}
          entry.deadZone[#entry.deadZone + 1] = {minimum, maximum}
        end
      end
    end
  end
end

local function evaluate(unit, now, combat)
  local entry = {}
  if answer(UnitExists, unit) ~= true then return entry end
  entry.kind = Range:Kind(unit)
  if answer(UnitIsUnit, unit, "player") == true then
    entry.min, entry.max, entry.minSource, entry.maxSource = 0, 0, "self", "self"
    return entry
  end
  if UnitDistanceSquared then
    local ok, squared, checked = pcall(UnitDistanceSquared, unit)
    if ok and public(squared) and public(checked) and checked == true and type(squared) == "number" then
      local yards = math.sqrt(squared)
      entry.min, entry.max, entry.minSource, entry.maxSource = yards, yards, "group distance", "group distance"
    end
  end
  local provider = Range.spellProvider
  if entry.kind and provider then
    local ok, spells = pcall(provider, entry.kind)
    if ok then checkSpells(entry, unit, spells, now) end
  end
  if entry.minSource ~= "group distance" then
    local attackable = entry.kind == "ENEMY"
    if (attackable or not combat) and C_Item and C_Item.IsItemInRange then
      searchItems(entry, unit, itemList(attackable))
      if not entry.itemAnswered and CheckInteractDistance then
        for _, row in ipairs(INTERACT) do
          local near = answer(CheckInteractDistance, unit, row[1])
          if near == true then atMost(entry, row[2], "interact")
          elseif near == false then atLeast(entry, row[3], "interact") end
        end
      end
    end
    if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
      local limit = tonumber(GetCVar("nameplateMaxDistance"))
      local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
      if limit and ok and plate then atMost(entry, limit, "nameplate") end
    end
    if answer(UnitIsVisible, unit) == false then atLeast(entry, 100, "visible") end
  end
  if entry.deadZone then
    for _, zone in ipairs(entry.deadZone) do
      if entry.min and entry.min >= zone[1] then atLeast(entry, zone[2], "spell") end
    end
  end
  return entry
end

local cache, cacheTime, cacheCombat = {}, 0, nil
local function bracket(unit)
  if type(unit) ~= "string" or not public(unit) then return {} end
  local now, combat = GetTime(), InCombatLockdown() and true or false
  if now - cacheTime > CACHE_SECONDS or combat ~= cacheCombat then
    for key in pairs(cache) do cache[key] = nil end
    cacheTime, cacheCombat = now, combat
  end
  local ok, guid = pcall(UnitGUID, unit)
  local key = ok and public(guid) and type(guid) == "string" and guid or unit
  local entry = cache[key]
  if not entry then
    entry = evaluate(unit, now, combat)
    cache[key] = entry
  end
  return entry
end

-- 'PET', 'ENEMY', 'FRIENDLY', 'RESURRECT' or nil; also the provider's argument.
function Range:Kind(unit)
  if answer(UnitIsUnit, unit, "pet") == true then return "PET" end
  if answer(UnitCanAttack, "player", unit) == true then return "ENEMY" end
  if answer(UnitCanAssist, "player", unit) == true then
    local dead = answer(UnitIsDeadOrGhost, unit)
    if dead == true then return "RESURRECT" elseif dead == false then return "FRIENDLY" end
  end
end

-- Range.spellProvider = function(kind) return {learned spell IDs} end (optional).

-- minYards, maxYards (either may be nil), then the source of each bound.
function Range:Bracket(unit)
  local entry = bracket(unit)
  return entry.min, entry.max, entry.minSource, entry.maxSource
end

-- true = within yards, false = beyond, nil = the available checks cannot tell.
function Range:Within(unit, yards)
  local entry = bracket(unit)
  if entry.max and entry.max <= yards then return true end
  if entry.min and entry.min >= yards then return false end
end

-- Melee reach to an attackable unit, from the 5-yard check (never a melee spell).
function Range:Melee(unit)
  if bracket(unit).kind ~= "ENEMY" then return nil end
  return self:Within(unit, MELEE_YARDS)
end

-- "Can I act on this unit": a learned spell reaches, or the unit is within the
-- longest answering spell's range (so melee and a ranged spell's minimum
-- distance count as reachable). Without such a spell: melee for attackable
-- units, 40 yards for the others. nil when nothing can answer.
function Range:Reach(unit)
  local entry = bracket(unit)
  if not entry.kind then return nil end
  if entry.spellHit then return true end
  return self:Within(unit, entry.reach or (entry.kind == "ENEMY" and MELEE_YARDS or FRIEND_YARDS))
end
