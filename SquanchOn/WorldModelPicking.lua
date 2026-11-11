-- SPDX-License-Identifier: MIT
-- Nameplates display information; native world models own cursor picking.
local _, addon = ...
local module = {}
addon.WorldModelPicking = module

function module:Apply()
  if InCombatLockdown() then self.pending = true; return end
  self.pending = nil
  local config = Plater and Plater.db and Plater.db.profile.plate_config
  if config then
    for _, kind in ipairs({"friendlyplayer", "enemyplayer"}) do
      if config[kind] then config[kind].click_through = true end
    end
  end
  local manager, kinds = C_NamePlateManager, Enum and Enum.NamePlateType
  if manager and manager.SetNamePlateHitTestInsets and kinds
    and kinds.Friendly and kinds.Enemy then
    -- Same empty hit area Plater uses for friendly click-through. Apply both
    -- kinds: its current manager-API branch does not apply the enemy setting.
    for _, kind in ipairs({kinds.Friendly, kinds.Enemy}) do
      manager.SetNamePlateHitTestInsets(kind, 10000, 10000, 10000, 10000)
    end
  elseif C_NamePlate then
    if C_NamePlate.SetNamePlateFriendlyClickThrough then
      C_NamePlate.SetNamePlateFriendlyClickThrough(true)
    end
    if C_NamePlate.SetNamePlateEnemyClickThrough then
      C_NamePlate.SetNamePlateEnemyClickThrough(true)
    end
  end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    if Plater and Plater.UpdatePlateClickSpace then
      hooksecurefunc(Plater, "UpdatePlateClickSpace", function() module:Apply() end)
    end
    module:Apply()
  elseif module.pending then
    module:Apply()
  end
end)
