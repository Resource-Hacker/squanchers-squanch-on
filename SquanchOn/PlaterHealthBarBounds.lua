-- SPDX-License-Identifier: MIT
-- Keep Plater's existing dark rim inside the health bar instead of outside it.
local _, addon = ...
local module = { watched = setmetatable({}, { __mode = "k" }) }
addon.PlaterHealthBarBounds = module

local points = {
  Left = {"TOPLEFT", "BOTTOMLEFT"}, Right = {"TOPRIGHT", "BOTTOMRIGHT"},
  Top = {"TOPLEFT", "TOPRIGHT"}, Bottom = {"BOTTOMLEFT", "BOTTOMRIGHT"},
}
local function fit(bar)
  for side, anchors in pairs(points) do
    local texture = bar.border[side]
    texture:ClearAllPoints()
    texture:SetPoint(anchors[1], bar, anchors[1], 0, 0)
    texture:SetPoint(anchors[2], bar, anchors[2], 0, 0)
  end
end

function module:Watch(plate)
  local bar = plate and plate.unitFrame and plate.unitFrame.healthBar
  local border = bar and bar.border
  if not border or (bar.IsForbidden and bar:IsForbidden()) then return end
  if not self.watched[border] then
    self.watched[border] = true
    -- Native scale/size refreshes also rebuild these anchors.
    hooksecurefunc(border, "UpdateSizes", function() fit(bar) end)
  end
  fit(bar)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function()
  if not Plater or not Plater.UpdatePlateBorderThickness then return end
  hooksecurefunc(Plater, "UpdatePlateBorderThickness", function(plate) module:Watch(plate) end)
  for _, plate in ipairs(Plater.GetAllShownPlates()) do module:Watch(plate) end
end)
