-- SPDX-License-Identifier: MIT
-- Preserve the two active third-party movers previously hosted by ElvUI.
local _, ns = ...
local anchors = {
  SquanchOnBuffs = { "BOTTOM", "BOTTOM", -300, 161 },
  SquanchOnMinimapButtons = { "BOTTOMRIGHT", "BOTTOMRIGHT", -367, 100 },
}
local module = {}
ns.AuxiliaryLayout = module
local frame = CreateFrame("Frame")
local done = {}
function module:Apply(force)
  if InCombatLockdown() then frame:RegisterEvent("PLAYER_REGEN_ENABLED"); return end
  frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
  for name, position in pairs(anchors) do
    local target = _G[name]
    if target and (force or not done[name]) then
      target:ClearAllPoints()
      target:SetPoint(position[1], UIParent, position[2], position[3], position[4])
      if ns.LayoutTargets then
        ns.LayoutTargets:ApplyScale(name == "SquanchOnBuffs" and "ifilger_buffs" or "minimap_buttons", target)
      end
      done[name] = true
    end
  end
end
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, name)
  if event == "PLAYER_LOGIN" or event == "PLAYER_REGEN_ENABLED"
    or name == "SquanchOn" then C_Timer.After(0, function() module:Apply() end) end
end)
