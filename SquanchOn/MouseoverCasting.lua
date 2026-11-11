-- SPDX-License-Identifier: MIT
-- First-use native targeting defaults. No spell dispatch or target selection.
local _, suite = ...

local function characterKey()
  local name, realm = UnitFullName("player")
  return name and (name .. " - " .. ((realm and realm ~= "") and realm or GetRealmName()))
end

function suite:MouseoverCastingStatus()
  return {
    enabled = GetCVar("enableMouseoverCast"),
    modifier = GetModifiedClick("MOUSEOVERCAST"),
    gate = GetCVar("CursorFreelookCentering"),
  }
end

function suite:ConfigureMouseoverCasting(enabled, initial)
  if InCombatLockdown() then
    if not initial then print("Squancher: change mouseover settings after combat.") end
    return false
  end
  local key = characterKey()
  if not self.db or not key then return false end
  self.db.mouseoverSetup = self.db.mouseoverSetup or {}
  if initial and self.db.mouseoverSetup[key] then return true end
  local before = self:MouseoverCastingStatus()
  if before.enabled == nil or not SetModifiedClick then
    if not initial then print("Squancher: this client does not expose native mouseover casting.") end
    return false
  end
  local ok, err = pcall(function()
    SetCVar("enableMouseoverCast", enabled and "1" or "0")
    if enabled then SetModifiedClick("MOUSEOVERCAST", "NONE") end
    SaveBindings(GetCurrentBindingSet())
  end)
  local after = self:MouseoverCastingStatus()
  if ok and after.enabled == (enabled and "1" or "0")
    and (not enabled or after.modifier == "NONE") then
    self.db.mouseoverSetup[key] = self.db.mouseoverSetup[key] or {
      previous = before, appliedAt = time(), revision = 1,
    }
    self.db.mouseoverSetup[key].lastApplied = after
    return true
  end
  self.db.mouseoverSetupError = tostring(err or "Client did not retain mouseover settings")
  return false
end

function suite:MouseoverCastingCommand(message)
  if message == "on" or message == "defaults" or message == "off" then
    self:ConfigureMouseoverCasting(message ~= "off", false)
  end
  local current = self:MouseoverCastingStatus()
  print("Squancher mouseover casting: " .. tostring(current.enabled)
    .. "; modifier=" .. tostring(current.modifier)
    .. ". Hold right-click in mouselook to open the gate; release to close it.")
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function()
  if suite.db and suite:ConfigureMouseoverCasting(true, true) then
    events:UnregisterAllEvents()
  end
end)
