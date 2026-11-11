-- SPDX-License-Identifier: MIT
-- Selected friendly Horde players use Plater's existing health bar and faction
-- indicator. Unselected players retain the profile's normal name-only policy.
local _, addon = ...
local module = { opaqueIcons = setmetatable({}, { __mode = "k" }) }
addon.FriendlyTargetNameplate = module

local function public(fn, ...)
  local ok, value = pcall(fn, ...)
  if ok and not (issecretvalue and issecretvalue(value)) then return value end
end

local function friendlyHorde(plate)
  if not plate or plate.actorType ~= "friendlyplayer" then return end
  local frame = plate.unitFrame
  if not frame or not frame.PlaterOnScreen then return end
  local unit = frame.namePlateUnitToken
  if type(unit) ~= "string" or (issecretvalue and issecretvalue(unit)) then return end
  if public(UnitFactionGroup, unit) == "Horde" then return frame, unit end
end

function module:Initialize()
  if self.initialized or not Plater or not Plater.ParseHealthSettingForPlayer then return end
  self.initialized = true
  hooksecurefunc(Plater, "ClearIndicators", function(plate)
    for _, icon in ipairs(plate.IconIndicators) do
      local original = module.opaqueIcons[icon]
      if original then
        icon:SetIgnoreParentAlpha(original.ignoreParentAlpha)
        icon:SetAlpha(original.alpha)
        module.opaqueIcons[icon] = nil
      end
    end
  end)
  hooksecurefunc(Plater, "AddIndicator", function(plate, indicator)
    if indicator ~= "Horde" or not friendlyHorde(plate) then return end
    local icon = plate.IconIndicators[plate.IconIndicators.Next - 1]
    if not icon then return end
    -- The bar may fade with range/selection; the allied faction emblem stays solid.
    -- Restore these properties before Plater reuses this texture for another unit.
    module.opaqueIcons[icon] = module.opaqueIcons[icon] or {
      alpha = icon:GetAlpha(), ignoreParentAlpha = icon:IsIgnoringParentAlpha(),
    }
    icon:SetIgnoreParentAlpha(true)
    icon:SetAlpha(1)
  end)
  hooksecurefunc(Plater, "ParseHealthSettingForPlayer", function(plate)
    local frame, unit = friendlyHorde(plate)
    if frame and public(UnitIsUnit, unit, "target") == true and not frame.healthBar:IsShown() then
      -- This also restores Plater's normal name, auras and faction-icon parent.
      Plater.ShowHealthBar(frame)
    end
  end)
  hooksecurefunc(Plater, "UpdateTarget", function(plate)
    local frame, unit = friendlyHorde(plate)
    if not frame then return end
    -- Re-evaluate both the newly selected and previously selected plate. Plater
    -- owns deselection, damage-only settings, plate recycling and all artwork.
    Plater.ParseHealthSettingForPlayer(plate)
    frame.targetOverlayTexture:SetShown(public(UnitIsUnit, unit, "target") == true
      and frame.healthBar:IsShown())
  end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function() module:Initialize() end)
