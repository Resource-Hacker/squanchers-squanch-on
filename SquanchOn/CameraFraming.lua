-- SPDX-License-Identifier: MIT
local _, addon = ...

-- DynamicCam owns camera CVars and interpolation. This is a one-time profile
-- setup, not a second camera controller. Later edits in /dc remain authoritative.
local framingProfile = "Squanch-On - Zoom Framing"

local function copy(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, child in pairs(value) do result[key] = copy(child) end
  return result
end

local function setUltrawideFov(dc, profile)
  local standard = profile.standardSettings
  local bounds = dc.cvarRanges and dc.cvarRanges.cameraFov or {min = 60, max = 90}
  local function fov(value)
    return math.max(bounds.min, math.min(bounds.max, value))
  end
  -- Conservative native-CVar tune for the owner's 5120x1440 viewport.
  -- The API does not identify its angle axis/reference aspect; these are NOT
  -- claimed full-width horizontal angles or an exact aspect-ratio conversion.
  -- Distance supplies more coverage while a narrower projection reduces stretch.
  standard.cvars.cameraFov = fov(80)
  standard.cvarsZoomBased = standard.cvarsZoomBased or {}
  standard.cvarsZoomBased.cameraFov = {
    enabled = true,
    points = {{zoom=0, value=fov(80)}, {zoom=5, value=fov(80)},
      {zoom=15, value=fov(75)}, {zoom=25, value=fov(70)},
      {zoom=dc.cameraDistanceMaxZoomFactor_max or 50, value=fov(70)}},
  }
end

local function restoreOriginalPitch(dc, config)
  if (config.revision or 0) >= 2 then return end
  local profile = rawget(dc.db.profiles, config.profile)
  local original = rawget(dc.db.profiles, config.sourceProfile)
  local standard = profile and profile.standardSettings
  local source = original and original.standardSettings
  if not standard or not source then return end
  local name = "test_cameraDynamicPitchBaseFovPad"
  local curve = standard.cvarsZoomBased and standard.cvarsZoomBased[name]
  local points = curve and curve.points
  -- Repair only the exact flat curve installed by revision 1. Preserve any
  -- subsequent owner tuning, and never change the selected profile here.
  if standard.cvars and standard.cvars[name] == 0.25 and curve and curve.enabled
    and points and #points == 2 and points[1].zoom == 0
    and points[2].zoom == (dc.cameraDistanceMaxZoomFactor_max or 50)
    and points[1].value == 0.25 and points[2].value == 0.25 then
    standard.cvars[name] = source.cvars and source.cvars[name]
    standard.cvarsZoomBased[name] = copy(source.cvarsZoomBased and source.cvarsZoomBased[name])
    dc:ResetZoomBasedSettingsCache()
    config.pitchCorrection = "restored-original-zoom-curve"
    print("Squancher: original zoom-dependent vertical pitch restored; shoulder and FoV retained.")
  else
    config.pitchCorrection = "preserved-manual-pitch"
  end
  config.revision = 2
end

function addon:InitializeCameraFraming()
  if not self.db then return end
  if self.db.cameraFraming then
    self.db.cameraFraming.reticleZoomScale = nil
    self.db.cameraFraming.fovAtFive = nil
  end
  local dc = _G.DynamicCam
  if not dc or not dc.db or not dc.SetZoomBasedPoints or not dc.ResetZoomBasedSettingsCache then return end
  if self.db.cameraFraming then
    local config = self.db.cameraFraming
    restoreOriginalPitch(dc, config)
    if (config.revision or 0) < 3 then
      local profile = rawget(dc.db.profiles, config.profile)
      if profile and profile.standardSettings and profile.standardSettings.cvars then
        setUltrawideFov(dc, profile)
        dc:ResetZoomBasedSettingsCache()
        config.revision = 3
        print("Squancher: ultrawide FoV curve installed; reticle size stays fixed.")
      end
    end
    return
  end
  if not self.db.cameraFramingRequested then return end
  local sourceProfile = dc.db:GetCurrentProfile()
  -- Never overwrite an existing named profile, even if another character made it.
  if rawget(dc.db.profiles, framingProfile) then
    print("Squancher: Zoom Framing profile already exists; kept current camera settings.")
    return
  end

  local profile = copy(dc.db.profile)
  local standard = profile.standardSettings
  if not standard or not standard.cvars then return end
  local maxZoom = dc.cameraDistanceMaxZoomFactor_max or 50
  standard.cvarsZoomBased = standard.cvarsZoomBased or {}
  standard.cvars.test_cameraOverShoulder = 1.2
  -- Preserve the source profile's zoom-dependent vertical-pitch compensation.
  standard.cvarsZoomBased.test_cameraOverShoulder = {
    enabled = true,
    points = {{zoom=0, value=0}, {zoom=5, value=1.2}, {zoom=15, value=1.6},
      {zoom=25, value=1.8}, {zoom=maxZoom, value=1.8}},
  }
  setUltrawideFov(dc, profile)
  local mounted = profile.situations and profile.situations["100"]
  if mounted and mounted.situationSettings then
    local settings = mounted.situationSettings
    if settings.cvars then settings.cvars.test_cameraOverShoulder = nil end
    if settings.cvarsZoomBased then settings.cvarsZoomBased.test_cameraOverShoulder = nil end
  end

  -- Build the complete copy before selecting it, so AceDB's normal profile
  -- callback never applies an empty/default intermediate camera profile.
  dc.db.profiles[framingProfile] = profile
  self.db.cameraFraming = {
    revision = 3, status = "pending", sourceProfile = sourceProfile,
    profile = framingProfile,
  }
  local ok, err = pcall(dc.db.SetProfile, dc.db, framingProfile)
  if not ok then
    self.db.cameraFraming.status = "failed"
    self.db.cameraFraming.sourceRestored = pcall(dc.db.SetProfile, dc.db, sourceProfile)
    error(err)
  end
  -- SetProfile's normal callback schedules camera application at the startup
  -- boundary required by DynamicCam; do not bypass its initial delay.
  dc:ResetZoomBasedSettingsCache()
  self.db.cameraFraming.status = "applied"
  print("Squancher: Zoom Framing selected (zoom 5: right 1.2 / FoV " .. standard.cvars.cameraFov
    .. "). Original camera profile retained. /sqms camera for details.")
end

function addon:CameraFramingCommand(command)
  local dc = _G.DynamicCam
  local config = self.db and self.db.cameraFraming
  if command == "setup" and not config then
    self.db.cameraFramingRequested = true
    self:InitializeCameraFraming()
    return
  end
  if command == "restore" and config and dc and dc.db then
    dc.db:SetProfile(config.sourceProfile)
    dc:ResetZoomBasedSettingsCache()
    dc:ApplySettings()
    config.status = "restored"
    self.HordeReticle:ApplyReticleScale()
    print("Squancher: original camera profile restored; automatic setup will not repeat.")
    return
  end
  print("Squancher camera: " .. (dc and dc.db and dc.db:GetCurrentProfile() or "DynamicCam unavailable")
    .. "; zoom=" .. tostring(GetCameraZoom()) .. "; right=" .. tostring(GetCVar("test_cameraOverShoulder"))
    .. "; FoV=" .. tostring(GetCVar("cameraFov")) .. "; reticle size=fixed")
  print("/dc edits the zoom curves. /sqms camera setup creates a separate framing profile; restore selects the original.")
end
