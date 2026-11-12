-- SPDX-License-Identifier: MIT
-- Squanch-On nameplates: the friendly mouseover ring (ns.NameplateHoverRing).
--
-- A friendly player's plate shows the name only. While the mouse is over one
-- that is not the target, the plate also shows its faction emblem and, around
-- it, a ring that is the player's health bar: full at 100%, emptying as health
-- drops, the filled arc starting at the top and running clockwise. The selected
-- plate keeps its bar and target ring (TargetCrosshairs.lua) and gets nothing.
--
-- Other units' health is a secret value. The ring is SEGMENTS copies of one arc
-- texture, each turned to its place; segment i takes its opacity from a cached
-- step curve (0 below (i - 0.5) / SEGMENTS, 1 above) evaluated by the client
-- and handed straight to SetAlpha. The colour comes from the target ring's
-- health curve with the class colour at full health. Nothing is compared.
--
-- One ring serves the one hovered plate. It listens to that unit's health
-- events only, and to nothing while no friendly player is hovered. Plate
-- regions are never measured: the ring is a child of the plate, anchored to
-- the emblem, and sized from layout numbers by the target ring's own rule.
local addonName, ns = ...
local NP = ns.Nameplates
if not NP then return end
local Hover = {}
ns.NameplateHoverRing = Hover
local ask = NP.Ask
local UnitClass, UnitIsDeadOrGhost = NP.Unit('UnitClass'), NP.Unit('UnitIsDeadOrGhost')

-- media/Crosshairs/segment-<face>-<width>.tga (asset-source/generate-frame-media.py):
-- the arc from the top to 360 / SEGMENTS degrees clockwise of ring-<face>-<width>.
local SEGMENTS = 60
local ART = 'Interface\\AddOns\\' .. addonName .. '\\media\\Crosshairs\\'

local function build()
  local display = CreateFrame('Frame')
  display:EnableMouse(false)
  display:Hide()
  local function art(layer)
    local texture = display:CreateTexture(nil, layer)
    texture:SetAllPoints(display)
    -- Moves with the emblem it surrounds: neither is snapped to whole pixels.
    if texture.SetSnapToPixelGrid then texture:SetSnapToPixelGrid(false); texture:SetTexelSnappingBias(0) end
    return texture
  end
  local ring = { display = display, track = art('BACKGROUND'), segments = {} }
  -- The same mouseover light the selected ring wears: full gloss on the line
  -- and soft additive lines stepping outward, in the ring's colour.
  -- The gloss follows the filled arc: one additive copy per segment.
  ring.gloss = {}
  ring.glows = {}
  for index, strength in ipairs({ 0.35, 0.22, 0.14, 0.07 }) do
    local glow = art('BORDER')
    glow:SetTexture(ART .. 'circle.tga'); glow:SetBlendMode('ADD')
    glow.strength, glow.step = strength, index
    ring.glows[index] = glow
  end
  for index = 1, SEGMENTS do
    local segment = art('ARTWORK')
    -- A positive rotation turns counter-clockwise; the arc runs clockwise.
    segment:SetRotation(-(index - 1) * 2 * math.pi / SEGMENTS)
    ring.segments[index] = segment
    local shine = art('OVERLAY'); shine:SetBlendMode('ADD')
    shine:SetRotation(-(index - 1) * 2 * math.pi / SEGMENTS)
    ring.gloss[index] = shine
  end
  return ring
end

local steps
local function stepCurves()
  if steps ~= nil then return steps end
  steps = false
  if C_CurveUtil and C_CurveUtil.CreateCurve and UnitHealthPercent and Enum and Enum.LuaCurveType then
    local ok, list = pcall(function()
      local curves = {}
      for index = 1, SEGMENTS do
        local curve = C_CurveUtil.CreateCurve()
        curve:SetType(Enum.LuaCurveType.Step)
        curve:AddPoint(0, 0)
        curve:AddPoint((index - 0.5) / SEGMENTS, 1)
        curve:AddPoint(1, 1)
        curves[index] = curve
      end
      return curves
    end)
    if ok then steps = list end
  end
  return steps
end

-- The health fraction as a plain number where the client gives one.
local function plainFraction(unit)
  local ok, fraction = pcall(function()
    local health, maximum = UnitHealth(unit), UnitHealthMax(unit)
    if NP.Public(health) and NP.Public(maximum) and type(health) == 'number' and type(maximum) == 'number' and maximum > 0 then
      return math.min(1, math.max(0, health / maximum))
    end
  end)
  if ok then return fraction end
end

-- The target ring module, once it exists (it is created at login).
local function targetRing()
  local marker = ns.TargetCrosshairs
  return marker and marker.FitIcon and marker or nil
end

local function paintPlain(ring, marker, fraction, red, green, blue)
  local r, g, b = marker.HealthRGB(fraction, red, green, blue)
  for index, segment in ipairs(ring.segments) do
    segment:SetVertexColor(r, g, b)
    segment:SetAlpha(fraction > (index - 0.5) / SEGMENTS and 1 or 0)
    ring.gloss[index]:SetAlpha(fraction > (index - 0.5) / SEGMENTS and 1 or 0)
  end
  for _, glow in ipairs(ring.glows) do glow:SetVertexColor(r, g, b) end
end

local function paint(ring, frame)
  local marker, unit = targetRing(), frame.unit
  if not (marker and unit) then return end
  local class = ask(function() return (select(2, UnitClass(unit))) end)
  local color = type(class) == 'string' and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  local key, red, green, blue = 'white', 1, 1, 1
  if color then key, red, green, blue = class, color.r, color.g, color.b end
  local facts = NP.fake[unit]
  if facts then return paintPlain(ring, marker, (facts.health or 100) / 100, red, green, blue) end
  -- Dead or ghost: the empty track alone.
  if ask(UnitIsDeadOrGhost, unit) == true then return paintPlain(ring, marker, 0, red, green, blue) end
  local curves = stepCurves()
  if curves and pcall(function()
    local r, g, b = UnitHealthPercent(unit, true, marker.ShiftCurve(key, red, green, blue)):GetRGB()
    for index, segment in ipairs(ring.segments) do
      segment:SetVertexColor(r, g, b)
      segment:SetAlpha(UnitHealthPercent(unit, true, curves[index]))
      ring.gloss[index]:SetAlpha(UnitHealthPercent(unit, true, curves[index]))
    end
    for _, glow in ipairs(ring.glows) do glow:SetVertexColor(r, g, b) end
  end) then return end
  paintPlain(ring, marker, plainFraction(unit) or 0, red, green, blue)
end

-- Parents the ring to the plate and fits it round the emblem. False when it cannot.
local function attach(ring, frame)
  local marker, settings = targetRing(), NP:Settings()
  local emblem, display = frame.Faction, ring.display
  local scale = ask(frame.GetEffectiveScale, frame)
  local icon = tonumber(settings.indicators.size)
  if not (marker and emblem and scale and scale > 0 and icon and icon > 0) then return false end
  -- The target ring's fit on the selected plate, which the client enlarges; the
  -- same numbers without the enlargement keep ring and emblem in proportion.
  local grown = tonumber(GetCVar and GetCVar('nameplateSelectedScale')) or 1
  if grown <= 0 then grown = 1 end
  local size, dx, dy = marker.FitIcon('faction', icon, icon, scale * grown, scale * grown, true)
  if grown > 1 then size = size / grown end
  display:SetParent(frame)
  display:SetFrameStrata(frame:GetFrameStrata() or 'BACKGROUND')
  if display.SetFixedFrameLevel then display:SetFixedFrameLevel(true) end
  display:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 2))
  -- As solid as the allied emblem, which ignores the plate's range fade.
  if display.SetIgnoreParentAlpha then display:SetIgnoreParentAlpha(true) end
  display:SetScale(1)
  display:SetSize(size, size)
  display:ClearAllPoints()
  if not pcall(display.SetPoint, display, 'CENTER', emblem, 'CENTER', dx, dy) then return false end

  local width = tonumber(marker.db.hoverRingWidth) or 0
  if width <= 0 then
    local factor = PixelUtil and PixelUtil.GetPixelToUIUnitFactor and PixelUtil.GetPixelToUIUnitFactor() or 1
    width = marker.LineWidth(size * scale * grown / factor, true)
  end
  local face = marker.BarFace()
  for _, segment in ipairs(ring.segments) do segment:SetTexture(ART .. 'segment-' .. face .. '-' .. width .. '.tga') end
  -- The empty part: the plate bar's background colour on the plain ring line.
  local back = settings.health.background
  ring.track:SetTexture(ART .. 'ring-flat-' .. width .. '.tga')
  ring.track:SetVertexColor(back[1] or 0, back[2] or 0, back[3] or 0)
  ring.track:SetAlpha(math.min(1, math.max(0, tonumber(marker.db.hoverRingTrack) or 0.4)))
  local lit = marker.db.hoverGlow ~= false
  local power = math.max(0, math.min(2, tonumber(marker.db.hoverGlowStrength) or 1))
  local pixel = (PixelUtil and PixelUtil.GetPixelToUIUnitFactor and PixelUtil.GetPixelToUIUnitFactor() or 1) / scale
  local outer = size * (width / 2 + 1.25) / 92   -- the ring's outer edge, as on the selected ring
  for _, shine in ipairs(ring.gloss) do
    shine:SetTexture(ART .. 'segment-gloss-' .. width .. '.tga')
    shine:SetShown(lit)
  end
  for _, glow in ipairs(ring.glows) do
    local d = outer + pixel * 1.5 * glow.step
    glow:ClearAllPoints()
    glow:SetPoint('TOPLEFT', display, 'TOPLEFT', -d, d)
    glow:SetPoint('BOTTOMRIGHT', display, 'BOTTOMRIGHT', d, -d)
    glow:SetAlpha(math.min(1, glow.strength * power))
    glow:SetShown(lit)
  end
  return true
end

-- Emblem and name follow frame.npHoverRing (NameplateStyle.lua).
local function relayout(frame)
  local Style = ns.NameplateStyle
  Style:Layout(frame)
  Style:Indicators(frame)
end

local function eligible(frame)
  local marker = targetRing()
  return marker and marker.db.hoverRing ~= false and frame.npKind == 'friendlyplayer' and not NP:IsTarget(frame)
    and frame.unit ~= nil and not (frame.IsForbidden and frame:IsForbidden())
end

local live, current
local events = CreateFrame('Frame')
events:SetScript('OnEvent', function() if current then paint(live, current) end end)

local function show(ring, frame)
  frame.npHoverRing = true
  relayout(frame)
  if attach(ring, frame) then
    paint(ring, frame)
    ring.display:Show()
    return true
  end
  frame.npHoverRing = nil
  relayout(frame)
  ring.display:Hide()
  return false
end

-- Called with every mouseover change of a plate, and when the target changes.
function Hover:Set(frame, shown)
  if not shown and frame ~= current then return end
  local wanted = shown and frame and eligible(frame) and frame or nil
  if wanted == current then
    if current then paint(live, current) end
    return
  end
  if current then
    local left = current
    current = nil
    events:UnregisterAllEvents()
    live.display:Hide()
    left.npHoverRing = nil
    -- A removed plate is laid out again when it returns; its emblem goes now.
    if NP.active[left] then relayout(left) else ns.NameplateStyle:Indicators(left) end
  end
  if not wanted then return end
  live = live or build()
  if show(live, wanted) then
    current = wanted
    events:RegisterUnitEvent('UNIT_HEALTH', wanted.unit)
    events:RegisterUnitEvent('UNIT_MAXHEALTH', wanted.unit)
  end
end

-- Settings edit: refit and repaint the ring on screen.
function Hover:Refresh()
  local frame = current
  if not frame then return end
  self:Set(frame, false)
  self:Set(frame, true)
end

-- Preview plates (NameplatePreview.lua) each keep a ring of their own, painted
-- from the made-up health number.
function Hover:Preview(frame)
  local marker = targetRing()
  local wanted = marker and marker.db.hoverRing ~= false and frame.npFake and frame.npFake.hover and not NP:IsTarget(frame)
  if not wanted then
    if frame.npHoverRing then frame.npHoverRing = nil; relayout(frame) end
    if frame.npHoverArt then frame.npHoverArt.display:Hide() end
    return
  end
  frame.npHoverArt = frame.npHoverArt or build()
  show(frame.npHoverArt, frame)
end
