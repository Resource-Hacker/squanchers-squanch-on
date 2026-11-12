-- SPDX-License-Identifier: MIT
-- Squanch-On nameplates: the cast bar (ns.NameplateCast). oUF's Castbar element
-- owns the events, the timer (duration objects on this client) and the hold
-- after a failed cast; this file owns the look.
--
-- Whether a cast can be interrupted may be a secret boolean. It is never
-- branched on: the grey fill and the shield take their alpha from it through
-- Region:SetAlphaFromBoolean, as oUF does for the shield.
local _, ns = ...
local NP = ns.Nameplates
if not NP then return end
local Cast = {}
ns.NameplateCast = Cast
local public = NP.Public

local function rgb(color) return color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1 end
local function lock(region, value, shown)
  if region.SetAlphaFromBoolean then
    if public(value) then value = value and true or false end
    if pcall(region.SetAlphaFromBoolean, region, value, shown, 0) then return end
  end
  region:SetAlpha(public(value) and value and shown or 0)
end

local function started(element)
  local settings = NP:Settings().cast
  element:SetStatusBarColor(rgb(element.channeling and settings.channel or settings.normal))
  element.Spark:SetShown(settings.spark and true or false)
  lock(element.Block, element.notInterruptible, 1)
  if ns.NameplateEnhance then ns.NameplateEnhance:CastStart(element, element.__owner and element.__owner.unit) end
end
local function interruptible(element)
  lock(element.Block, element.notInterruptible, 1)
end
-- Failed and interrupted casts: oUF has filled the bar and holds it for
-- timeToHold seconds with its "Interrupted" / "Failed" text.
local function failed(element, _, _, interruptedBy)
  element:SetStatusBarColor(rgb(NP:Settings().cast.interrupted))
  element.Spark:Hide()
  element.Block:SetAlpha(0)
  element.Time:SetText('')
  -- "Interrupted [Name]" with the interrupter in class colour, when the client names them.
  if public(interruptedBy) and type(interruptedBy) == 'string' and GetPlayerInfoByGUID then
    local ok, _, class, _, _, _, name = pcall(GetPlayerInfoByGUID, interruptedBy)
    if ok and public(name) and type(name) == 'string' and name ~= '' then
      local color = public(class) and class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
      if color then name = string.format('|cff%02x%02x%02x%s|r', math.floor(color.r * 255 + 0.5), math.floor(color.g * 255 + 0.5), math.floor(color.b * 255 + 0.5), name) end
      element.Text:SetText((INTERRUPTED or 'Interrupted') .. ' [' .. name .. ']')
    end
  end
end
-- Remaining time as "1.2". The value can be secret; the client formats it.
local function clock(self, elapsed)
  self.elapsed = (self.elapsed or 0) + elapsed
  if self.elapsed < 0.1 then return end
  self.elapsed = 0
  local cast = self:GetParent()
  if not cast.Time:IsShown() or not (cast.casting or cast.channeling) then return end
  local duration = cast.GetTimerDuration and cast:GetTimerDuration()
  if not duration then return end
  local ok, left = pcall(duration.GetRemainingDuration, duration)
  if ok then pcall(cast.Time.SetFormattedText, cast.Time, '%.1f', left) end
end
local SIDES = { LEFT = { 'RIGHT', 'LEFT' }, INNERLEFT = { 'LEFT', 'LEFT' }, CENTER = { 'CENTER', 'CENTER' },
  INNERRIGHT = { 'RIGHT', 'RIGHT' }, RIGHT = { 'LEFT', 'RIGHT' } }
local function nameShown(element, shown)
  local frame = element.__owner or element:GetParent()
  if shown or NP:Settings().cast.hideNameWhileCasting then frame.Name:SetShown(shown) end
  if shown and ns.NameplateEnhance then ns.NameplateEnhance:CastStop(element) end
  if ns.NameplateAuras and frame.unit then ns.NameplateAuras:Alpha(frame, true) end
end

function Cast:Build(frame)
  local cast = CreateFrame('StatusBar', nil, frame)
  cast.bg = cast:CreateTexture(nil, 'BACKGROUND')
  cast.bg:SetAllPoints(cast)
  cast.Block = cast:CreateTexture(nil, 'ARTWORK', nil, 1)
  cast.Block:SetAlpha(0)
  cast.Spark = cast:CreateTexture(nil, 'OVERLAY')
  cast.Spark:SetTexture('Interface\\CastingBar\\UI-CastingBar-Spark')
  cast.Spark:SetBlendMode('ADD')
  cast.IconRim = cast:CreateTexture(nil, 'ARTWORK', nil, -1)
  cast.Icon = cast:CreateTexture(nil, 'ARTWORK')
  cast.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  cast.Shield = cast:CreateTexture(nil, 'OVERLAY')
  cast.Shield:SetAlpha(0)
  cast.Text = cast:CreateFontString(nil, 'OVERLAY')
  cast.Text:SetFont(STANDARD_TEXT_FONT or 'Fonts\\FRIZQT__.TTF', 10, 'OUTLINE')
  cast.Text:SetWordWrap(false)
  cast.Time = cast:CreateFontString(nil, 'OVERLAY')
  cast.Time:SetFont(STANDARD_TEXT_FONT or 'Fonts\\FRIZQT__.TTF', 8, 'OUTLINE')
  -- Its own clock frame: oUF replaces the bar's OnUpdate when it enables the
  -- element. A child only ticks while the cast bar is on screen.
  CreateFrame('Frame', nil, cast):SetScript('OnUpdate', clock)
  cast.PostCastStart = started
  cast.PostCastInterruptible = interruptible
  cast.PostCastFail, cast.PostCastInterrupted = failed, failed
  cast:HookScript('OnShow', function(self) nameShown(self, false) end)
  cast:HookScript('OnHide', function(self) nameShown(self, true) end)
  frame.Castbar = cast
  self:Style(frame)
end

-- Textures and colours from the settings (also after an options edit).
function Cast:Style(frame)
  local cast, settings = frame.Castbar, NP:Settings().cast
  if not cast then return end
  cast:SetStatusBarTexture(ns.Media and ns.Media:Resolve('statusbar', settings.texture) or 'Interface\\TargetingFrame\\UI-StatusBar')
  local fill = cast:GetStatusBarTexture()
  cast.Block:ClearAllPoints()
  if fill then cast.Block:SetAllPoints(fill) else cast.Block:SetAllPoints(cast) end
  cast.Block:SetColorTexture(rgb(settings.nonInterruptible))
  cast.Spark:ClearAllPoints()
  cast.Spark:SetPoint('CENTER', fill or cast, 'RIGHT', 0, 0)
  cast.bg:SetColorTexture(rgb(settings.background))
  cast.timeToHold = tonumber(settings.hold) or 0
  cast.Icon:SetShown(settings.icon and true or false)
  cast.IconRim:SetShown(settings.icon and true or false)
  local line = ns.DarkSkin and ns.DarkSkin.lineColor or { 0.34, 0.26, 0.145 }
  cast.IconRim:SetColorTexture(line[1], line[2], line[3], 1)
  cast.Shield.alphaValue = settings.shield and settings.icon and 1 or 0
end

function Cast:Layout(frame, config, width, height)
  local cast, settings = frame.Castbar, NP:Settings().cast
  if not cast then return end
  local health = frame.Health
  local offset = config.castOffset or 0
  local castWidth = config.cast[1] * width / math.max(1, (NP:Fighting(frame) and config.healthCombat or config.health)[1])
  cast:ClearAllPoints()
  cast:SetPoint('TOP', health, 'BOTTOM', 0, offset)
  cast:SetSize(castWidth, config.cast[2])
  -- The icon spans the health bar and the cast bar, left of both.
  local size = height + math.abs(offset) + config.cast[2]
  cast.Icon:ClearAllPoints()
  cast.Icon:SetPoint('TOPRIGHT', health, 'TOPLEFT', settings.iconX or -15, 0)
  cast.Icon:SetSize(size, size)
  local scale = cast.GetEffectiveScale and cast:GetEffectiveScale() or 1
  local pixel = (PixelUtil and PixelUtil.GetPixelToUIUnitFactor and PixelUtil.GetPixelToUIUnitFactor() or 1) / (scale > 0 and scale or 1)
  cast.IconRim:ClearAllPoints()
  cast.IconRim:SetPoint('TOPLEFT', cast.Icon, 'TOPLEFT', -pixel, pixel)
  cast.IconRim:SetPoint('BOTTOMRIGHT', cast.Icon, 'BOTTOMRIGHT', pixel, -pixel)
  cast.Shield:ClearAllPoints()
  cast.Shield:SetPoint('CENTER', cast.Icon, 'CENTER', 0, 0)
  cast.Shield:SetSize(size * 1.6, size * 1.6)
  cast.Spark:SetSize(settings.sparkWidth or 17, config.cast[2] * 2.6)
  NP:Font(cast.Text, config.spell.font, config.spell.size, 'OUTLINE')
  cast.Text:ClearAllPoints()
  cast.Text:SetPoint('CENTER', cast, 'CENTER', 0, config.spell.y or 0)
  local time = config.castTime
  NP:Font(cast.Time, time.font, time.size, time.outline)
  local side = SIDES[time.side] or SIDES.INNERRIGHT
  cast.Time:ClearAllPoints()
  cast.Time:SetPoint(side[1], cast, side[2], time.x or 0, time.y or 0)
  cast.Time:SetShown(time.show ~= false)
  if cast:IsShown() and settings.hideNameWhileCasting then frame.Name:Hide() end
end
