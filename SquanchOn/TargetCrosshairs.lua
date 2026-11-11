-- SPDX-License-Identifier: MIT
-- Original Squancher target-marker implementation. See PROVENANCE.md.
local addonName, suite = ...

local baseline = {
  enabled = true, showLines = false, size = 64, alpha = 0.65,
  lineAlpha = 0.55, rotationSeconds = 5, healthColor = true,
  showKillShotPulse = true, killShotThreshold = 0.20,
}

local function duplicate(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, item in pairs(value) do result[key] = duplicate(item) end
  return result
end

local function limit(value, fallback, minimum, maximum)
  local number = tonumber(value) or fallback
  return math.min(maximum, math.max(minimum, number))
end

local function available(region)
  return region and (not region.IsForbidden or not region:IsForbidden())
end

local function publicQuery(fn, ...)
  if type(fn) ~= "function" then return end
  local ok, value = pcall(fn, ...)
  if ok and not (issecretvalue and issecretvalue(value)) then return value end
end

local function spellRange(spellID, fallbackName)
  -- Resolve the localized name so native range queries select the learned
  -- rank. Unknown spells/invalid targets return nil, not an inferred distance.
  local name = publicQuery(C_Spell and C_Spell.GetSpellName, spellID) or fallbackName
  local result = publicQuery(_G.IsSpellInRange, name, "target")
  if result == nil then result = publicQuery(C_Spell and C_Spell.IsSpellInRange, name or spellID, "target") end
  return result == true or result == 1
end

local function meleeRange()
  -- Forever's queued Raptor Strike reports true even at Auto Shot distance;
  -- melee Auto Attack has no range verdict. Use Plater's exact five-yard
  -- checker, not an eight/ten-yard interaction fallback or an unknown spell.
  -- A missing, restricted or uncached checker must leave these markers hidden.
  local library = LibStub and LibStub("LibRangeCheck-3.0", true)
  local checker = library and publicQuery(library.GetHarmChecker, library, 5)
  local result = publicQuery(checker, "target")
  return result == true or result == 1
end

-- Melee has priority: Auto Shot's minimum range must not hide melee artwork.
-- Check actual abilities, independently of cooldown/resources/proc readiness.
local function targetRangeMode()
  local _, class = UnitClass("player")
  if class ~= "HUNTER" then return end
  local attackable = publicQuery(UnitCanAttack, "player", "target")
  local dead = publicQuery(UnitIsDead, "target")
  if (attackable ~= true and attackable ~= 1) or (dead ~= false and dead ~= 0) then return end
  if meleeRange() then return "melee" end
  if spellRange(75, "Auto Shot") then return "ranged" end
end

local function plainFraction()
  local ok, fraction = pcall(function()
    local hp, maximum = UnitHealth("target"), UnitHealthMax("target")
    if issecretvalue and (issecretvalue(hp) or issecretvalue(maximum)) then return end
    if type(hp) == "number" and type(maximum) == "number" and maximum > 0 then
      return math.min(1, math.max(0, hp / maximum))
    end
  end)
  if ok then return fraction end
end

local function rgbAt(fraction)
  if fraction <= 0.20 then return 1, 0, 0 end
  if fraction < 0.35 then return 1, (fraction - 0.20) / 0.30, 0 end
  if fraction <= 0.65 then return 1, 0.5, 0 end
  local blend = (fraction - 0.65) / 0.35
  return 1, 0.5 + blend / 2, blend
end

local function healthMaps(cutoff)
  if not (C_CurveUtil and C_CurveUtil.CreateCurve and C_CurveUtil.CreateColorCurve
    and UnitHealthPercent and CreateColor and Enum and Enum.LuaCurveType) then return end
  local ok, maps = pcall(function()
    local result = { color = C_CurveUtil.CreateColorCurve() }
    result.color:SetType(Enum.LuaCurveType.Linear)
    for _, point in ipairs({{0, 1, 0, 0}, {0.20, 1, 0, 0},
      {0.35, 1, 0.5, 0}, {0.65, 1, 0.5, 0}, {1, 1, 1, 1}}) do
      result.color:AddPoint(point[1], CreateColor(point[2], point[3], point[4], 1))
    end
    result.guides, result.execute = C_CurveUtil.CreateCurve(), C_CurveUtil.CreateCurve()
    result.guides:SetType(Enum.LuaCurveType.Step)
    result.execute:SetType(Enum.LuaCurveType.Step)
    result.guides:AddPoint(0, 0)
    if cutoff > 0 then result.guides:AddPoint(0.0001, 0.75) end
    if cutoff < 1 then result.guides:AddPoint(math.max(0.0001, cutoff + 0.0001), 0.05) end
    result.guides:AddPoint(1, 0)
    result.execute:AddPoint(0, 0)
    result.execute:AddPoint(0.0001, 1)
    result.execute:AddPoint(math.min(1, cutoff + 0.0001), 0)
    return result
  end)
  if ok then return maps end
end

function suite:InitializeTargetCrosshairs(database, legacy)
  if self.TargetCrosshairs then return self.TargetCrosshairs end
  assert(type(database) == "table", "Target crosshairs requires the suite database")
  if type(database.targetCrosshairs) ~= "table" then
    database.targetCrosshairs = type(legacy) == "table" and duplicate(legacy) or {}
    database.targetCrosshairsMigration = type(legacy) == "table" and "CrosshairsDB" or "defaults"
  end
  local settings = database.targetCrosshairs
  for key, value in pairs(baseline) do
    if settings[key] == nil then settings[key] = value end
  end

  local marker = { db = settings, inRange = false }
  self.TargetCrosshairs = marker
  local artwork = "Interface\\AddOns\\" .. addonName .. "\\media\\Crosshairs\\"
  local display = CreateFrame("Frame", "SQMSTargetCrosshairsFrame", WorldFrame)
  display:SetFrameStrata("BACKGROUND")
  display:SetFrameLevel(1)
  display:EnableMouse(false)
  display:Hide()

  function marker:SyncTargetFade()
    local owner = _G.SquanchOnUF_Target
    if not available(owner) then display:SetAlpha(1); return end
    if self.fadeOwner ~= owner then
      self.fadeOwner = owner
      local function sync()
        if marker.fadeOwner == owner then
          -- Pass native alpha straight through, including secret alpha. The
          -- target fader owns both directions and every smooth fade step.
          display:SetAlpha(owner:GetAlpha())
        end
      end
      hooksecurefunc(owner, "SetAlpha", sync)
      if owner.SetAlphaFromBoolean then hooksecurefunc(owner, "SetAlphaFromBoolean", sync) end
    end
    display:SetAlpha(owner:GetAlpha())
  end

  local function image(parent, file, layer)
    local texture = parent:CreateTexture(nil, layer)
    texture:SetTexture(artwork .. file .. ".tga")
    texture:SetAllPoints(parent)
    texture:SetBlendMode("ADD")
    return texture
  end
  local ring = image(display, "circle", "OVERLAY")
  local orbit = CreateFrame("Frame", nil, display)
  orbit:SetAllPoints(display)
  orbit:EnableMouse(false)
  local pointers = image(orbit, "arrows", "OVERLAY")
  local rectangles = {}
  -- Match the original arrow centers/radial extent in its 128px artwork.
  -- Rectangles are code-native textures, with no new asset or input owner.
  for index = 1, 4 do
    -- Melee markers stay at the four cardinal points; only ranged arrows orbit.
    local rectangle = display:CreateTexture(nil, "OVERLAY")
    rectangle:SetColorTexture(1, 1, 1, 1)
    rectangle:SetBlendMode("ADD")
    rectangle:Hide()
    rectangles[index] = rectangle
  end
  local guides = {}
  local anchors = {{"RIGHT", "LEFT", 8, 0}, {"LEFT", "RIGHT", -8, 0},
    {"BOTTOM", "TOP", 0, -8}, {"TOP", "BOTTOM", 0, 8}}
  for index, edge in ipairs(anchors) do
    local guide = display:CreateTexture(nil, "ARTWORK")
    guide:SetColorTexture(1, 1, 1, 1)
    guide:SetBlendMode("ADD")
    guide:SetPoint(edge[1], display, edge[2], edge[3], edge[4])
    guides[index] = guide
  end

  -- Friendly targets replace the solid ring with one range-driven dashed ring.
  -- Native regions share the marker's existing visibility and health colors.
  local friendly = CreateFrame("Frame", nil, display)
  friendly:SetAllPoints(display)
  friendly:EnableMouse(false)
  friendly:Hide()
  -- One texture makes the entire dashed circle orbit its common center.
  -- Rotating separate Line regions rotates their individual local axes.
  local friendlyRing = image(friendly, "circle-dashed", "OVERLAY")
  local friendlySpin = friendlyRing:CreateAnimationGroup()
  local friendlyTurn = friendlySpin:CreateAnimation("Rotation")
  friendlyTurn:SetDegrees(-360)
  friendlySpin:SetLooping("REPEAT")

  -- Pause the child texture's orbit while its parent pulses the whole ring.
  -- Native scale animations accumulate, so the return multiplies by 1 / 0.75.
  local clickAnimation = friendly:CreateAnimationGroup()
  for order, scale in ipairs({0.75, 1 / 0.75}) do
    local resize = clickAnimation:CreateAnimation("Scale")
    resize:SetOrder(order)
    resize:SetScale(scale, scale)
    resize:SetDuration(order == 1 and 0.18 or 0.26)
    resize:SetSmoothing(order == 1 and "OUT" or "IN_OUT")
    resize:SetOrigin("CENTER", 0, 0)
  end
  local clickGeneration, clickGUID, pressedGUID = 0, nil, nil
  local function clearClick()
    clickGeneration = clickGeneration + 1
    clickGUID = nil
    pressedGUID = nil
    marker.clickFeedbackActive = false
    clickAnimation:Stop()
  end
  clickAnimation:SetScript("OnFinished", function()
    clearClick()
    marker:RefreshRange()
  end)
  display:HookScript("OnHide", function()
    clearClick()
    friendlySpin:Stop()
  end)

  local function friendlyWorldGUID(worldPressValidated)
    if not settings.enabled or publicQuery(SpellIsTargeting)
      or publicQuery(GetCurrentKeyBoardFocus) then return end
    local input = suite:GetInputState()
    if input.layoutEditing then return end
    -- The native passthrough already checked world focus before dispatch; a
    -- vendor/gossip window opened by that click must not veto its feedback.
    if not worldPressValidated then
      for _, focus in ipairs(GetMouseFoci and GetMouseFoci() or {}) do
        if focus ~= WorldFrame then return end
      end
    end
    -- A click on empty ground must never pulse the previously selected unit.
    if publicQuery(UnitIsFriend, "player", "mouseover") ~= true then return end
    local guid = publicQuery(UnitGUID, "mouseover")
    if type(guid) == "string" then return guid end
  end
  function marker:BeginFriendlyWorldClick()
    -- Capture before the release can open a menu and clear native mouseover.
    pressedGUID = friendlyWorldGUID(false)
  end
  function marker:ObserveFriendlyWorldClick(worldPressValidated)
    local guid = pressedGUID or friendlyWorldGUID(worldPressValidated)
    pressedGUID = nil
    self:QueueFriendlyClick(guid, "click")
  end
  function marker:QueueFriendlyClick(guid, source)
    if type(guid) ~= "string" then return end
    if clickGUID == guid and self.clickFeedbackActive then return end
    clickGeneration = clickGeneration + 1
    local generation = clickGeneration
    C_Timer.After(0, function()
      if generation ~= clickGeneration or not settings.enabled
        or publicQuery(UnitGUID, "target") ~= guid then return end
      self:RefreshTarget()
      if not self.friendly or not display:IsVisible() then return end
      clearClick()
      clickGUID = guid
      self.clickFeedbackActive = true
      friendlySpin:Pause()
      clickAnimation:Play()
      self.lastClickFeedbackSource = source
      self.clickFeedbackCount = (self.clickFeedbackCount or 0) + 1
    end)
  end

  local spin = orbit:CreateAnimationGroup()
  local turn = spin:CreateAnimation("Rotation")
  turn:SetDegrees(-360)
  spin:SetLooping("REPEAT")

  -- Secret alpha belongs on a parent that has no alpha animation of its own.
  local visibility = CreateFrame("Frame", nil, display)
  visibility:SetPoint("CENTER", display, "CENTER")
  visibility:Hide()
  local warning = image(visibility, "circle", "ARTWORK")
  warning:SetVertexColor(1, 0.02, 0.02)
  local pulse = warning:CreateAnimationGroup()
  for order, scale in ipairs({1.22, 1 / 1.22}) do
    local resize = pulse:CreateAnimation("Scale")
    resize:SetOrder(order)
    resize:SetScale(scale, scale)
    resize:SetDuration(0.16)
    local brightness = pulse:CreateAnimation("Alpha")
    brightness:SetOrder(order)
    brightness:SetFromAlpha(order == 1 and 0.35 or 1)
    brightness:SetToAlpha(order == 1 and 1 or 0.35)
    brightness:SetDuration(0.16)
  end
  pulse:SetLooping("REPEAT")

  local bound, boundPlate, maps, cutoff, alpha
  local watched = setmetatable({}, { __mode = "k" })
  local deferred = false
  local healthMode = "unknown"
  local function applyRange(mode)
    marker.rangeMode = mode
    marker.inRange = mode ~= nil
    pointers:SetShown(mode == "ranged")
    for _, rectangle in ipairs(rectangles) do
      rectangle:SetShown(mode == "melee")
      rectangle:SetAlpha(mode == "melee" and alpha or 0)
    end
    orbit:SetAlpha(marker.inRange and alpha or 0)
    if mode ~= "friendly" and not marker.clickFeedbackActive then friendlySpin:Stop() end
  end
  function marker:RefreshRange()
    if not display:IsVisible() then return end
    local mode
    if self.friendly then
      local library = LibStub and LibStub("LibRangeCheck-3.0", true)
      local range = Plater and Plater.RangeCheckRangeFriendly or 40
      -- Friendly NPCs cannot always receive friendly spells/items. Let the
      -- library pick the unit-compatible checker, never wider than this range.
      local checker = library and publicQuery(library.GetSmartMaxChecker, library, range)
      local result = publicQuery(checker, "target")
      if result == true or result == 1 then mode = "friendly" end
    else
      mode = targetRangeMode()
    end
    if self.rangeMode ~= mode then applyRange(mode) end
    if not self.clickFeedbackActive then
      if mode == "friendly" then
        if not friendlySpin:IsPlaying() then friendlySpin:Play() end
      else
        friendlySpin:Stop()
      end
    end
  end

  local function warningState(show, opacity)
    if not show or marker.friendly then
      pulse:Stop()
      visibility:Hide()
      return
    end
    visibility:SetAlpha(opacity)
    visibility:Show()
    if not pulse:IsPlaying() then pulse:Play() end
  end

  local function applyColor(red, green, blue, opacity)
    ring:SetVertexColor(red, green, blue)
    pointers:SetVertexColor(red, green, blue)
    for _, rectangle in ipairs(rectangles) do
      rectangle:SetVertexColor(red, green, blue)
      rectangle:SetAlpha(marker.rangeMode == "melee" and alpha or 0)
    end
    ring:SetAlpha(alpha)
    orbit:SetAlpha(marker.inRange and alpha or 0)
    for _, guide in ipairs(guides) do
      guide:SetVertexColor(red, green, blue)
      guide:SetAlpha(opacity)
    end
    friendlyRing:SetVertexColor(red, green, blue)
  end

  local function paintHealth()
    if maps then
      local ok = pcall(function()
        local color
        if settings.healthColor then
          color = UnitHealthPercent("target", true, maps.color)
        else
          color = CreateColor(1, 1, 1, 1)
        end
        local opacity = UnitHealthPercent("target", true, maps.guides)
        local red, green, blue = color:GetRGB()
        -- Keep secret colors and alpha out of Lua comparisons and arithmetic.
        applyColor(red, green, blue, opacity)
        if settings.showKillShotPulse then
          warningState(true, UnitHealthPercent("target", true, maps.execute))
        else
          warningState(false)
        end
      end)
      if ok then healthMode = "client curves"; return end
    end
    local fraction = plainFraction()
    if fraction == nil then
      applyColor(1, 1, 1, 0)
      warningState(false)
      healthMode = "unknown"
      return
    end
    local red, green, blue = 1, 1, 1
    if settings.healthColor then red, green, blue = rgbAt(fraction) end
    local execute = fraction > 0 and fraction <= cutoff
    local opacity = 0
    if fraction > 0 and fraction < 1 then opacity = execute and 0.75 or 0.05 end
    applyColor(red, green, blue, opacity)
    warningState(settings.showKillShotPulse and execute, 1)
    healthMode = "public health"
  end

  function marker:HideTarget()
    bound = nil
    boundPlate = nil
    applyRange(nil)
    warningState(false)
    display:Hide()
  end

  local function watchVisibility(region)
    if watched[region] then return end
    watched[region] = true
    region:HookScript("OnHide", function(hidden)
      if hidden == boundPlate or hidden == bound then
        -- Keep the binding so its next OnShow can restore this target.
        warningState(false)
        display:Hide()
      end
    end)
    region:HookScript("OnShow", function(shown)
      if shown == boundPlate or shown == bound then marker:RefreshTarget() end
    end)
  end

  function marker:RefreshTarget()
    self:SyncTargetFade()
    if not settings.enabled then self:HideTarget(); return end
    if clickGUID and publicQuery(UnitGUID, "target") ~= clickGUID then clearClick() end
    self.friendly = publicQuery(UnitIsFriend, "player", "target") == true
    if not self.friendly and self.clickFeedbackActive then clearClick() end
    friendly:SetShown(self.friendly)
    ring:SetShown(not self.friendly)
    for _, guide in ipairs(guides) do guide:SetShown(settings.showLines and not self.friendly) end
    local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit("target")
    if not available(plate) then self:HideTarget(); return end
    if boundPlate ~= plate then bound = nil end
    boundPlate = plate
    watchVisibility(plate)
    if not plate:IsShown() or not plate:IsVisible() then
      warningState(false)
      display:Hide()
      return
    end
    local unit = plate.unitFrame or plate.UnitFrame
    local destination = unit and unit.healthBar
    if not available(destination) then destination = plate end
    if destination ~= bound then
      display:ClearAllPoints()
      local ok = pcall(display.SetPoint, display, "CENTER", destination, "CENTER", 0, 0)
      if not ok then self:HideTarget(); return end
      bound = destination
    end
    watchVisibility(destination)
    if not destination:IsShown() or not destination:IsVisible() then
      warningState(false)
      display:Hide()
      return
    end
    paintHealth()
    display:Show()
    self:RefreshRange()
  end

  function marker:ApplyStyle()
    clearClick()
    local size = limit(settings.size, 64, 1, 2048)
    alpha = limit(settings.alpha, 0.65, 0, 1)
    cutoff = limit(settings.killShotThreshold, 0.20, 0, 1)
    maps = healthMaps(cutoff)
    display:SetSize(size, size)
    for index, rectangle in ipairs(rectangles) do
      local horizontal = index < 3
      local direction = index % 2 == 1 and -1 or 1
      rectangle:ClearAllPoints()
      rectangle:SetPoint("CENTER", display, "CENTER",
        horizontal and direction * size * 47.5 / 128 or 0,
        horizontal and 0 or direction * size * 47.5 / 128)
      rectangle:SetSize(size * (horizontal and 13 or 6) / 128,
        size * (horizontal and 6 or 13) / 128)
    end
    visibility:SetSize(size * 1.22, size * 1.22)
    local _, height = GetPhysicalScreenSize()
    local thickness = height and height > 0 and 1536 / height or 1
    friendly:SetAlpha(alpha)
    friendlySpin:Stop()
    friendlyTurn:SetDuration(limit(settings.rotationSeconds, 5, 0.01, 3600))
    for index, guide in ipairs(guides) do
      guide:SetSize(index < 3 and 4000 or thickness, index < 3 and thickness or 4000)
      guide:SetShown(settings.showLines)
    end
    spin:Stop()
    turn:SetDuration(limit(settings.rotationSeconds, 5, 0.01, 3600))
    spin:Play()
    self:RefreshTarget()
  end

  function marker:SetEnabled(enabled)
    settings.enabled = not not enabled
    self:RefreshTarget()
  end

  function marker:PrintStatus()
    print(("|cff33ff99Squancher target marker|r enabled=%s lines=%s plate=%s health=%s range=%s feedback=%s/%d"):format(
      tostring(settings.enabled), tostring(settings.showLines), tostring(bound ~= nil), healthMode, self.rangeMode or "none",
      self.lastClickFeedbackSource or "none", self.clickFeedbackCount or 0))
  end

  function marker:SlashCommand(message)
    local text = (message or ""):lower():match("^%s*(.-)%s*$")
    if text == "on" or text == "off" then
      self:SetEnabled(text == "on")
    elseif text == "lines on" or text == "lines off" then
      settings.showLines = text == "lines on"
      self:ApplyStyle()
    else
      self:PrintStatus()
      print("/sqcrosshairs on | off | lines on | lines off")
    end
  end

  function marker:RegisterSlashCommands()
    SLASH_SQMSTARGETCROSSHAIRS1 = "/sqcrosshairs"
    SlashCmdList.SQMSTARGETCROSSHAIRS = function(message) marker:SlashCommand(message) end
  end

  local events = CreateFrame("Frame")
  events:SetScript("OnEvent", function(_, event, unit)
    if event == "MERCHANT_SHOW" then
      -- The merchant UI can already own mouse focus when native click hooks
      -- run. The opened shop's own unit token is authoritative for this cue.
      local guid = publicQuery(UnitGUID, "npc")
      if type(guid) == "string" and publicQuery(UnitGUID, "target") == guid
        and publicQuery(UnitIsFriend, "player", "target") == true then
        marker:QueueFriendlyClick(guid, "merchant")
      end
    elseif event == "GLOBAL_MOUSE_DOWN" then
      if unit == "LeftButton" and suite.db and suite.db.nativeCombinedClick
        and suite:IsNativeMouseoverOpen() then
        marker:BeginFriendlyWorldClick()
        marker:ObserveFriendlyWorldClick()
      end
    elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
      if unit == "target" then marker:RefreshTarget() end
    elseif event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED"
      or event == "PLAYER_LOGIN" then
      marker:ApplyStyle()
    else
      marker:RefreshTarget()
      if not deferred and C_Timer and C_Timer.After then
        deferred = true
        C_Timer.After(0, function() deferred = false; marker:RefreshTarget() end)
      end
    end
  end)
  for _, event in ipairs({"PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED",
    "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "UNIT_HEALTH", "UNIT_MAXHEALTH",
    "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED", "UNIT_FACTION", "GLOBAL_MOUSE_DOWN", "MERCHANT_SHOW"}) do events:RegisterEvent(event) end
  applyRange(nil)
  marker:ApplyStyle()
  return marker
end
