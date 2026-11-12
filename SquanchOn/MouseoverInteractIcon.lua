-- SPDX-License-Identifier: MIT
-- Native interaction artwork for the selected NPC and the held cursor hit.
-- Soft interaction selection is disabled; this module never selects a unit.
local _, addon = ...
local module = { watched = {} }
addon.MouseoverInteractIcon = module
local ownedCVars = { "SoftTargetInteract", "SoftTargetIconInteract" }
local ownedLower = {}
for _, name in ipairs(ownedCVars) do ownedLower[name:lower()] = name end

local function safe(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, value = pcall(fn, ...)
  if not ok or (issecretvalue and issecretvalue(value)) then return nil end
  return value
end

local function createIcon(name)
  local frame = CreateFrame("Frame", name, UIParent)
  frame:SetFrameStrata("BACKGROUND")
  frame:EnableMouse(false)
  frame:SetSize(24, 24)
  frame.Icon = frame:CreateTexture(nil, "ARTWORK")
  frame.Icon:SetAllPoints(frame)
  frame:Hide()
  return { frame = frame }
end
local mouseover = createIcon("SquancherMouseoverInteractIcon")
local target = createIcon("SquancherTargetInteractIcon")
local displays = { mouseover, target }
module.frame, module.targetFrame = mouseover.frame, target.frame

local function hide(display)
  display.frame:Hide()
  if display.plate then display.frame:ClearAllPoints() end
  display.plate, display.token, display.anchor = nil, nil, nil
end

function module:Hide()
  for _, display in ipairs(displays) do hide(display) end
end

function module:Watch(owner)
  if self.watched[owner] then return end
  self.watched[owner] = true
  owner:HookScript("OnHide", function()
    for _, display in ipairs(displays) do
      if display.plate == owner or display.anchor == owner then hide(display) end
    end
  end)
end

function module:IsInteractableNPC(unit)
  return safe(UnitExists, unit) == true and safe(UnitIsPlayer, unit) == false
    and safe(UnitCanAttack, "player", unit) == false
    and safe(UnitIsInteractable, unit) == true
end

local function refreshIcon(display, unit, enabled)
  if not enabled or not module:IsInteractableNPC(unit) then
    hide(display)
    return
  end
  local plate = C_NamePlate and safe(C_NamePlate.GetNamePlateForUnit, unit)
  local token = plate and (safe(plate.GetUnit, plate) or plate.namePlateUnitToken)
  if not plate or safe(plate.IsShown, plate) ~= true
    or (issecretvalue and issecretvalue(token)) or type(token) ~= "string"
    or safe(UnitIsUnit, unit, token) ~= true then
    hide(display)
    return
  end
  local anchor = plate.unitFrame or plate.UnitFrame or plate
  local frame = display.frame
  if safe(anchor.IsShown, anchor) ~= true
    or safe(SetUnitCursorTexture, frame.Icon, unit, nil, nil, true) ~= true then
    hide(display)
    return
  end
  if display.plate ~= plate or display.anchor ~= anchor then
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOM", anchor, "TOP", 0, -8)
    frame:SetFrameLevel(anchor:GetFrameLevel() + 1)
    display.plate, display.anchor = plate, anchor
    module:Watch(plate)
    module:Watch(anchor)
  end
  display.token = token
  frame:Show()
end

function module:Refresh()
  local enabled = addon.db and addon.db.enabled
  refreshIcon(target, "target", enabled)
  local sameTarget = target.frame:IsShown() and safe(UnitIsUnit, "target", "mouseover") == true
  refreshIcon(mouseover, "mouseover", enabled and not sameTarget and addon:IsNativeMouseoverOpen())
end

function module:ApplyPolicy()
  if self.applyingPolicy then return end
  -- Plater restores its profile after login and whenever its profile changes.
  -- Apply after that restore so its ordinary CVar hook also saves our value.
  if not self.platerHooked and Plater and type(Plater.RestoreProfileCVars) == "function" then
    self.platerHooked = true
    hooksecurefunc(Plater, "RestoreProfileCVars", function() module:ApplyPolicy() end)
  end
  if InCombatLockdown() then self.pendingPolicy = true; return end
  self.applyingPolicy = true
  self.pendingPolicy = nil
  if addon.db and addon.db.mouseoverInteractOriginalSoftTarget == nil then
    addon.db.mouseoverInteractOriginalSoftTarget = GetCVar("SoftTargetInteract")
  end
  if addon.db and addon.db.mouseoverInteractOriginalIcon == nil then
    addon.db.mouseoverInteractOriginalIcon = GetCVar("SoftTargetIconInteract")
  end
  self.policyError = nil
  for _, name in ipairs(ownedCVars) do
    if GetCVar(name) ~= "0" then
      local ok, err = pcall(SetCVar, name, 0)
      if not ok or GetCVar(name) ~= "0" then
        self.policyError = tostring(err or (name .. " did not retain zero"))
      end
    end
  end
  -- Plater can have queued its original restore before our hook was installed.
  -- Align its active profile too, so that queued restore reads the same policy.
  local profile = Plater and Plater.db and Plater.db.profile
  if profile and profile.saved_cvars and GetCVar("SoftTargetInteract") == "0" then
    profile.saved_cvars.SoftTargetInteract = "0"
  end
  self.applyingPolicy = nil
  self:Refresh()
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, unit)
  if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD"
    or (event == "PLAYER_REGEN_ENABLED" and module.pendingPolicy) then
    module:ApplyPolicy()
  elseif event == "CVAR_UPDATE" then
    -- A client that will not hold zero is not asked again on its own echo.
    local name = type(unit) == "string" and ownedLower[unit:lower()]
    if name and not module.policyError and GetCVar(name) ~= "0" then module:ApplyPolicy() end
  elseif event == "PLAYER_LEAVING_WORLD" then
    module:Hide()
  elseif event == "NAME_PLATE_UNIT_REMOVED" then
    for _, display in ipairs(displays) do
      if unit == display.token then hide(display) end
    end
  else
    module:Refresh()
  end
end)
for _, event in ipairs({"PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD",
  "PLAYER_REGEN_ENABLED", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT",
  "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "CVAR_UPDATE"}) do
  events:RegisterEvent(event)
end
