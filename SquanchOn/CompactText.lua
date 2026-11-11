-- SPDX-License-Identifier: MIT
-- Preserve the owner's pre-migration ElvUI scale without the ElvUI engine.
local _, ns = ...
local Text = {}
ns.CompactText = Text
function Text:SetScale(value)
  value = tonumber(value)
  if not value or value < 0.65 or value > 1.5 then return false end
  local db = SquanchOnDB
  db.appearance = db.appearance or {}
  db.appearance.textScale = value
  C_CVar.SetCVar("userFontScale", value)
  C_CVar.SetCVar("userFontScaleGlue", value)
  return true
end
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self)
  if InCombatLockdown() then self:RegisterEvent("PLAYER_REGEN_ENABLED");return end
  self:UnregisterAllEvents()
  local db = SquanchOnDB
  db.appearance = db.appearance or {}
  if not db.appearance.previousSizeRestored then
    local before = db.appearance.compactTextApplied and db.appearance.compactTextApplied.before or {}
    Text:SetScale(tonumber(before.userFontScale) or 1)
    C_CVar.SetCVar("userFontScaleGlue", tonumber(before.userFontScaleGlue) or 1.39)
    db.appearance.previousSizeRestored = time()
  end
  -- ElvUI previously applied exactly 1 on every load. Native automatic scale
  -- falls to .64 on this monitor when that owner disappears.
  UIParent:SetScale(1)
  if ns.HordeReticle then ns.HordeReticle:ApplyReticleScale() end
  if ns.UpdateAimPoint then ns:UpdateAimPoint() end
end)
