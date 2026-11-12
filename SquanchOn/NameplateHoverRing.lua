-- SPDX-License-Identifier: MIT
-- Squanch-On nameplates: the friendly mouseover ring (ns.NameplateHoverRing).
--
-- A friendly player's plate shows the name only. While the mouse is over one
-- that is not the target, the plate also shows its faction emblem and, around
-- it, a ring that is the player's health bar: full at 100%, emptying as health
-- drops, the filled arc starting at the top and running clockwise. The selected
-- plate keeps its bar and target ring (TargetCrosshairs.lua) and gets nothing.
--
-- Other units' health is a secret value. The filled arc is two half rings,
-- one behind each half of the ring's square: a texture that paints the left
-- half of the ring, shown through a frame that clips to one half and turned
-- about the ring centre. Its angle comes from a linear curve the client
-- evaluates on the unit's health and goes straight to SetRotation: the right
-- half sweeps in over the first 50%, the left half over the rest. The colour
-- comes from the target ring's health curve with the class colour at full
-- health. Nothing is compared.
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

-- media/Crosshairs/half-<face>-<width>.tga (asset-source/generate-frame-media.py):
-- the left half of ring-<face>-<width>, cut on the centre line.
local ART = 'Interface\\AddOns\\' .. addonName .. '\\media\\Crosshairs\\'
local PI = math.pi

local function build()
  local display = CreateFrame('Frame')
  display:EnableMouse(false)
  display:Hide()
  local function art(parent, layer)
    local texture = parent:CreateTexture(nil, layer)
    texture:SetAllPoints(display)
    -- Moves with the emblem it surrounds: neither is snapped to whole pixels.
    if texture.SetSnapToPixelGrid then texture:SetSnapToPixelGrid(false); texture:SetTexelSnappingBias(0) end
    return texture
  end
  local ring = { display = display, track = art(display, 'BACKGROUND'), glows = {}, halves = {} }
  -- The same mouseover light the selected ring wears: full gloss on the line
  -- and soft additive lines stepping outward, in the ring's colour.
  for index, strength in ipairs({ 0.35, 0.22, 0.14, 0.07 }) do
    local glow = art(display, 'BORDER')
    glow:SetTexture(ART .. 'circle.tga'); glow:SetBlendMode('ADD')
    glow.strength, glow.step = strength, index
    ring.glows[index] = glow
  end
  -- Right half first (health 0..50%), then the left (50..100%). Each clips its
  -- fill and the gloss that follows the fill.
  for index = 1, 2 do
    local clip = CreateFrame('Frame', nil, display)
    clip:EnableMouse(false)
    if index == 1 then clip:SetPoint('TOPLEFT', display, 'TOP'); clip:SetPoint('BOTTOMRIGHT', display, 'BOTTOMRIGHT')
    else clip:SetPoint('TOPLEFT', display, 'TOPLEFT'); clip:SetPoint('BOTTOMRIGHT', display, 'BOTTOM') end
    clip:SetClipsChildren(true)
    local half = { clip = clip, fill = art(clip, 'ARTWORK'), gloss = art(clip, 'OVERLAY') }
    half.gloss:SetBlendMode('ADD')
    ring.halves[index] = half
  end
  return ring
end

-- Radians for a health fraction (a positive rotation turns counter-clockwise;
-- the arc runs clockwise from the top). At rotation 0 the art lies in the left
-- half, so the right clip shows nothing; half a turn fills the right half. The
-- left clip is empty at half a turn and full at a whole one.
local function rightTurn(fraction) return -2 * PI * math.min(fraction, 0.5) end
local function leftTurn(fraction) return -PI - 2 * PI * math.max(fraction - 0.5, 0) end
local turns
local function turnCurves()
  if turns ~= nil then return turns end
  turns = false
  if C_CurveUtil and C_CurveUtil.CreateCurve and UnitHealthPercent and Enum and Enum.LuaCurveType then
    local ok, right, left = pcall(function()
      local first, second = C_CurveUtil.CreateCurve(), C_CurveUtil.CreateCurve()
      first:SetType(Enum.LuaCurveType.Linear); second:SetType(Enum.LuaCurveType.Linear)
      first:AddPoint(0, rightTurn(0)); first:AddPoint(0.5, rightTurn(0.5)); first:AddPoint(1, rightTurn(1))
      second:AddPoint(0, leftTurn(0)); second:AddPoint(0.5, leftTurn(0.5)); second:AddPoint(1, leftTurn(1))
      return first, second
    end)
    if ok then turns = { right, left } end
  end
  return turns
end

-- The health fraction as a plain number where the client gives one.
local function plainFraction(unit)
  local ok, health = pcall(UnitHealth, unit)
  local fine, maximum = pcall(UnitHealthMax, unit)
  if ok and fine and NP.Public(health) and NP.Public(maximum) and type(health) == 'number' and type(maximum) == 'number' and maximum > 0 then
    return math.min(1, math.max(0, health / maximum))
  end
end

-- The target ring module, once it exists (it is created at login).
local function targetRing()
  local marker = ns.TargetCrosshairs
  return marker and marker.FitIcon and marker or nil
end

-- Angles (plain or secret numbers) and colour to the two halves and the glow.
local function apply(ring, right, left, r, g, b)
  local first, second = ring.halves[1], ring.halves[2]
  first.fill:SetRotation(right); first.gloss:SetRotation(right)
  second.fill:SetRotation(left); second.gloss:SetRotation(left)
  first.fill:SetVertexColor(r, g, b); second.fill:SetVertexColor(r, g, b)
  if ring.lit then
    for index = 1, #ring.glows do ring.glows[index]:SetVertexColor(r, g, b) end
  end
end
local function paintPlain(ring, marker, fraction, red, green, blue)
  apply(ring, rightTurn(fraction), leftTurn(fraction), marker.HealthRGB(fraction, red, green, blue))
end
local function paintCurves(ring, marker, unit, curves, key, red, green, blue)
  local r, g, b = UnitHealthPercent(unit, true, marker.ShiftCurve(key, red, green, blue)):GetRGB()
  apply(ring, UnitHealthPercent(unit, true, curves[1]), UnitHealthPercent(unit, true, curves[2]), r, g, b)
end

local function paint(ring, frame)
  local marker, unit = targetRing(), frame.unit
  if not (marker and unit) then return end
  local ok, _, class = pcall(UnitClass, unit)
  local color = ok and NP.Public(class) and type(class) == 'string' and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  local key, red, green, blue = 'white', 1, 1, 1
  if color then key, red, green, blue = class, color.r, color.g, color.b end
  local facts = NP.fake[unit]
  if facts then return paintPlain(ring, marker, (facts.health or 100) / 100, red, green, blue) end
  -- Dead or ghost: the empty track alone.
  if ask(UnitIsDeadOrGhost, unit) == true then return paintPlain(ring, marker, 0, red, green, blue) end
  local curves = turnCurves()
  if curves and pcall(paintCurves, ring, marker, unit, curves, key, red, green, blue) then return end
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
  local grown = marker.SelectedScale and marker.SelectedScale() or tonumber(GetCVar and GetCVar('nameplateSelectedScale')) or 1
  if grown <= 0 then grown = 1 end
  local size, dx, dy = marker.FitIcon('faction', icon, icon, scale * grown, scale * grown, true)
  if grown > 1 then size = size / grown end
  display:SetParent(frame)
  display:SetFrameStrata(frame:GetFrameStrata() or 'BACKGROUND')
  if display.SetFixedFrameLevel then display:SetFixedFrameLevel(true) end
  local level = math.max(0, frame:GetFrameLevel() - 2)
  display:SetFrameLevel(level)
  for index = 1, 2 do
    -- The fills draw over the track, still beneath the plate's own parts.
    local clip = ring.halves[index].clip
    if clip.SetFixedFrameLevel then clip:SetFixedFrameLevel(true) end
    clip:SetFrameLevel(level + 1)
  end
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
  -- Textures are only touched when the art actually changes.
  local key = face .. '-' .. width
  local fresh = ring.art ~= key
  ring.art = key
  local lit = marker.db.hoverGlow ~= false
  ring.lit = lit
  for index = 1, 2 do
    local half = ring.halves[index]
    if fresh then
      half.fill:SetTexture(ART .. 'half-' .. key .. '.tga')
      half.gloss:SetTexture(ART .. 'half-gloss-' .. width .. '.tga')
    end
    half.gloss:SetShown(lit)
  end
  -- The empty part: the plate bar's background colour on the plain ring line.
  local back = settings.health.background
  if fresh then ring.track:SetTexture(ART .. 'ring-flat-' .. width .. '.tga') end
  ring.track:SetVertexColor(back[1] or 0, back[2] or 0, back[3] or 0)
  ring.track:SetAlpha(math.min(1, math.max(0, tonumber(marker.db.hoverRingTrack) or 0.4)))
  local power = math.max(0, math.min(2, tonumber(marker.db.hoverGlowStrength) or 1))
  local pixel = (PixelUtil and PixelUtil.GetPixelToUIUnitFactor and PixelUtil.GetPixelToUIUnitFactor() or 1) / scale
  local outer = size * (width / 2 + 1.25) / 92   -- the ring's outer edge, as on the selected ring
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

-- Emblem and name follow frame.npHoverRing (NameplateStyle.lua): only those
-- two move, so no layout pass is needed.
local function relayout(frame) ns.NameplateStyle:HoverRing(frame) end

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
-- Motion: the ring and emblem appear and leave over 0.15 s; the name
-- glides between its two places instead of jumping. Alpha and Translation
-- animations only: nothing is measured and nothing runs per frame in Lua.
local APPEAR, LEAVE = 0.15, 0.15
local function alphaAnim(region, key)
  local group = region[key]
  if not group then
    group = region:CreateAnimationGroup()
    group.fade = group:CreateAnimation('Alpha')
    group.fade:SetSmoothing('IN_OUT')
    group:SetToFinalAlpha(true)
    region[key] = group
  end
  return group
end
local function fade(region, from, to, seconds, done)
  local group = alphaAnim(region, 'sqHoverFade')
  group:Stop()
  -- Start from the first value at once: without this the region shows at its
  -- old alpha for one frame before the animation takes hold (a visible flash).
  region:SetAlpha(from)
  group.fade:SetFromAlpha(from); group.fade:SetToAlpha(to); group.fade:SetDuration(seconds)
  group:SetScript('OnFinished', done)
  group:Play()
end
-- How far the name sits above its name-only place while the ring shows: from
-- the layout's own numbers (bar height, name offset, font size, lines).
local function nameRise(frame)
  local settings = NP:Settings()
  local config = settings.types[frame.npKind]
  if not config then return 0 end
  local size = tonumber(config.name.size) or 10
  local lines = config.guild and 2 or 1
  return (tonumber(frame.npBarHeight) or 5) / 2 + (tonumber(config.name.y) or 0) + size * lines / 2 - 10
end
local function glide(frame, seconds, down)
  local name = frame.Name
  if not name or not name.CreateAnimationGroup then return end
  local group = name.sqHoverGlide
  if not group then
    group = name:CreateAnimationGroup()
    group.move = group:CreateAnimation('Translation')
    group.move:SetSmoothing('OUT')
    name.sqHoverGlide = group
  end
  group:Stop()
  local rise = nameRise(frame)
  -- Up: laid out high already, so it starts `rise` lower and travels to rest.
  -- Down: still laid out high; it travels down and the layout takes over there.
  group.move:SetOffset(0, -rise)
  group.move:SetDuration(seconds)
  if down then group:Play() else group:Play(true) end
end

local function teardown(ring, frame)
  ring.display:Hide()
  ring.leaving = nil
  if frame.sqHoverRing == ring then
    frame.sqHoverRing = nil
    frame.npHoverRing = nil
    if frame.Name and frame.Name.sqHoverGlide then frame.Name.sqHoverGlide:Stop() end
    if NP.active[frame] then relayout(frame) else ns.NameplateStyle:Indicators(frame) end
    if frame.Faction then frame.Faction:SetAlpha(1) end
  end
end

-- Two rings: one for the plate under the mouse, one still fading on the plate
-- the mouse just left.
local pool = {}
local function freeRing()
  for _, ring in ipairs(pool) do if not ring.display:IsShown() then return ring end end
  if #pool < 3 then pool[#pool + 1] = build(); return pool[#pool] end
  -- All busy: finish the oldest fade now.
  for _, ring in ipairs(pool) do
    if ring.leaving then teardown(ring, ring.leaving); return ring end
  end
end

Hover.builds = 0
function Hover:Set(frame, shown)
  -- A plate that left the screen while its ring was fading loses it at once.
  if not shown and frame and frame ~= current and frame.sqHoverRing and not NP.active[frame] then
    teardown(frame.sqHoverRing, frame)
  end
  if not shown and frame ~= current then return end
  if shown and frame == current and current and eligible(frame) then return end
  local wanted = shown and frame and eligible(frame) and frame or nil
  if wanted == current then
    if current then paint(live, current) end
    return
  end
  if current then
    local left, ring = current, live
    current, live = nil, nil
    events:UnregisterAllEvents()
    -- Selected or gone: the target ring takes over at once. Otherwise fade.
    if NP.active[left] and eligible(left) and ring.display:IsShown() then
      ring.leaving = left
      fade(ring.display, ring.display:GetAlpha(), 0, LEAVE, function() teardown(ring, left) end)
      if left.Faction then fade(left.Faction, left.Faction:GetAlpha(), 0, LEAVE) end
      glide(left, LEAVE, true)
    else
      teardown(ring, left)
    end
  end
  if not wanted then return end
  -- Hovered again while its ring was still fading out: take that ring back.
  local ring = wanted.sqHoverRing
  local taken = false
  if ring and ring.leaving == wanted then
    ring.leaving = nil
    taken = true
    if wanted.Name and wanted.Name.sqHoverGlide then wanted.Name.sqHoverGlide:Stop() end
  else
    ring = freeRing()
    if not ring then return end
    self.builds = self.builds + 1
    if not show(ring, wanted) then return end
    wanted.sqHoverRing = ring
    ring.display:SetAlpha(0)
    glide(wanted, APPEAR, false)
  end
  fade(ring.display, ring.display:GetAlpha(), 1, APPEAR)
  if wanted.Faction then fade(wanted.Faction, taken and wanted.Faction:GetAlpha() or 0, 1, APPEAR) end
  live, current = ring, wanted
  events:RegisterUnitEvent('UNIT_HEALTH', wanted.unit)
  events:RegisterUnitEvent('UNIT_MAXHEALTH', wanted.unit)
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
