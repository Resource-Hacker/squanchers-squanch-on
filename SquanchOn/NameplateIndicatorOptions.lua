-- SPDX-License-Identifier: MIT
-- Native options for Squancher's nameplate indicators.
local _, addon = ...
local module = addon.NameplateIndicators
local selectedUnit, selectedReaction = "mouseover", "hostile"

local function text(parent, label, x, y, width)
  local font = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  font:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  font:SetWidth(width or 200)
  font:SetJustifyH("LEFT")
  font:SetText(label)
  return font
end

local function button(parent, label, x, y, width, callback)
  local frame = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  frame:SetSize(width or 100, 24)
  frame:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  frame:SetText(label)
  frame:SetScript("OnClick", callback)
  return frame
end

local function editbox(parent, x, y, width, callback)
  local frame = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  frame:SetSize(width or 150, 24)
  frame:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  frame:SetAutoFocus(false)
  frame:SetScript("OnEscapePressed", function(self) self:ClearFocus(); module:RefreshPanel() end)
  frame:SetScript("OnEnterPressed", function(self)
    callback(self:GetText())
    self:ClearFocus()
  end)
  return frame
end

local function nextValue(values, current, direction)
  local index = 1
  for i, value in ipairs(values) do if value == current then index = i; break end end
  return values[((index - 1 + direction) % #values) + 1]
end

local function set(key, value)
  local ok, errorMessage = module:SetOption(selectedUnit, selectedReaction, key, value)
  if not ok then print("Squancher nameplate indicators: " .. errorMessage) end
  module:RefreshPanel()
end

function module:RefreshPanel()
  local panel = self.panel
  if not panel then return end
  panel.profileName:SetText(self.profileName)
  panel.unit:SetText(selectedUnit)
  panel.reaction:SetText(selectedReaction)
  local unitConfig = self.profile[selectedUnit]
  local config = unitConfig[selectedReaction]
  panel.unitEnabled:SetChecked(unitConfig.enable)
  panel.reactionEnabled:SetChecked(config and config.enable or false)
  panel.reactionEnabled:SetEnabled(config ~= nil)
  panel.unsupported:SetText(config and "" or "This reaction is not used by this soft-target indicator.")
  for key, field in pairs(panel.fields) do
    local value = config and config[key]
    if key == "texture" and type(value) == "string" and value:sub(1, #self.textureRoot) == self.textureRoot then
      value = value:match("([^\\]+)$") or value
    end
    if field.SetText then field:SetText(value == nil and "" or tostring(value)) end
    if field.EnableMouse then field:EnableMouse(config ~= nil) end
    field:SetAlpha(config and 1 or 0.4)
  end
  if config then
    self:PaintTexture(panel.preview, config)
  else
    panel.preview:SetTexture(nil)
  end
  -- Capability follows the same detection used by the runtime, not client flavor.
  if C_Secrets and C_Secrets.ShouldUnitComparisonBeSecret then
    panel.restriction:SetText("This client restricts non-target comparisons in combat; target-of-target is unavailable.")
  else
    panel.restriction:SetText("Indicators attach to visible nameplates only; higher priority indicators win on the same unit.")
  end
end

function module:OpenOptions()
  if self.panel then self:RefreshPanel(); self.panel:Show(); return end
  local panel = CreateFrame("Frame", "SquancherNameplateIndicatorOptions", UIParent, "BasicFrameTemplateWithInset")
  self.panel = panel
  panel:SetSize(700, 660)
  panel:SetPoint("CENTER")
  panel:SetFrameStrata("DIALOG")
  panel:SetMovable(true)
  panel:EnableMouse(true)
  panel:RegisterForDrag("LeftButton")
  panel:SetScript("OnDragStart", panel.StartMoving)
  panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
  panel.TitleText:SetText("Squancher · Nameplate Indicators")
  if UISpecialFrames then table.insert(UISpecialFrames, "SquancherNameplateIndicatorOptions") end
  panel.fields = {}

  text(panel, "Profile", 22, -40, 100)
  panel.profileName = editbox(panel, 110, -34, 270, function(value)
    module:SelectProfile(value); module:RefreshPanel()
  end)
  button(panel, "Use / Create", 395, -34, 120, function()
    module:SelectProfile(panel.profileName:GetText()); module:RefreshPanel()
  end)
  button(panel, "Copy From", 525, -34, 100, function()
    local name = panel.profileName:GetText()
    if not module.db.profiles[name] then print("Unknown indicator profile: " .. name); return end
    module:Slash("copy " .. name)
  end)
  text(panel, "Copy From replaces the active profile with the named profile. Enter applies each edit.", 22, -72, 650)

  text(panel, "Unit", 22, -108, 70)
  panel.unit = button(panel, selectedUnit, 110, -100, 180, function()
    selectedUnit = nextValue(module.units, selectedUnit, 1); module:RefreshPanel()
  end)
  panel.unitEnabled = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
  panel.unitEnabled:SetPoint("TOPLEFT", panel, "TOPLEFT", 310, -96)
  panel.unitEnabled:SetScript("OnClick", function(self)
    module:SetOption(selectedUnit, "unit", "enable", self:GetChecked()); module:RefreshPanel()
  end)
  text(panel, "Enable this unit", 345, -106, 200)
  text(panel, "Reaction", 22, -144, 80)
  panel.reaction = button(panel, selectedReaction, 110, -136, 180, function()
    selectedReaction = nextValue(module.reactions, selectedReaction, 1); module:RefreshPanel()
  end)
  panel.reactionEnabled = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
  panel.reactionEnabled:SetPoint("TOPLEFT", panel, "TOPLEFT", 310, -132)
  panel.reactionEnabled:SetScript("OnClick", function(self) set("enable", self:GetChecked()) end)
  text(panel, "Enable this reaction", 345, -142, 250)
  panel.unsupported = text(panel, "", 22, -171, 650)

  text(panel, "Texture", 22, -210, 90)
  panel.fields.texture = editbox(panel, 170, -202, 350, function(value) set("texture", value) end)
  button(panel, "<", 535, -202, 35, function()
    local value = module.profile[selectedUnit][selectedReaction]
    if value then set("texture", nextValue(module.textureNames, value.texture:match("([^\\]+)$"), -1)) end
  end)
  button(panel, ">", 575, -202, 35, function()
    local value = module.profile[selectedUnit][selectedReaction]
    if value then set("texture", nextValue(module.textureNames, value.texture:match("([^\\]+)$"), 1)) end
  end)
  text(panel, "Custom path", 22, -246, 130)
  panel.fields.textureCustom = editbox(panel, 170, -238, 440, function(value) set("textureCustom", value) end)
  text(panel, "Use Ring, Chevron, Pointer, Diamond, Horde, Skull, a game path, or 'custom'.", 22, -274, 650)

  local fields = {
    { "width", "Width", 22, -310 }, { "height", "Height", 325, -310 },
    { "xOffset", "X Offset", 22, -346 }, { "yOffset", "Y Offset", 325, -346 },
    { "opacity", "Opacity (0–1)", 22, -382 },
  }
  for _, entry in ipairs(fields) do
    local key, label, x, y = entry[1], entry[2], entry[3], entry[4]
    text(panel, label, x, y, 140)
    panel.fields[key] = editbox(panel, x + 148, y + 8, 130, function(value) set(key, value) end)
  end
  local choices = {
    { "frameStrata", "Frame Strata", self.stratas },
    { "texturePoint", "Texture Point", self.points },
    { "anchorPoint", "Nameplate Point", self.points },
  }
  for index, entry in ipairs(choices) do
    local key, label, values = entry[1], entry[2], entry[3]
    local y = -418 - (index - 1) * 36
    text(panel, label, 22, y, 145)
    panel.fields[key] = button(panel, "", 170, y + 8, 180, function()
      local config = module.profile[selectedUnit][selectedReaction]
      if config then set(key, nextValue(values, config[key], 1)) end
    end)
  end
  panel.preview = panel:CreateTexture(nil, "OVERLAY")
  panel.preview:SetSize(100, 100)
  panel.preview:SetPoint("TOPLEFT", panel, "TOPLEFT", 460, -405)
  text(panel, "Texture preview", 450, -516, 150)

  panel.restriction = text(panel, "", 22, -552, 650)
  panel.restriction:SetHeight(40)
  text(panel, "/sqnameplates profiles · profile NAME · copy NAME · delete NAME · reset", 22, -601, 650)
  button(panel, "Reset Current Profile", 22, -622, 190, function() module:Slash("reset") end)
  button(panel, "Status", 230, -622, 100, function() module:PrintStatus() end)
  button(panel, "Close", 565, -622, 100, function() panel:Hide() end)
  self:RefreshPanel()
end
