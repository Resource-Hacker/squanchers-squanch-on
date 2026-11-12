-- SPDX-License-Identifier: MIT
local addonName, addon = ...

_G.SquancherMouselookSuite = addon -- existing key-binding compatibility
_G.SquanchOn = addon
_G.BINDING_HEADER_SQUANCHERMOUSELOOKSUITE = "Squancher's Squanch-On"
_G.BINDING_NAME_SQMS_INVERTMOUSELOOK = "Hold to release mouselook"
_G.BINDING_NAME_SQMS_TOGGLEMOUSELOOK = "Toggle mouselook"
_G.BINDING_NAME_SQMS_LOCKMOUSELOOK = "Enable mouselook"
_G.BINDING_NAME_SQMS_UNLOCKMOUSELOOK = "Disable mouselook"
_G.BINDING_NAME_SQMS_EDITLAYOUT = "Move and resize UI (10 px grid)"
_G.BINDING_NAME_SQMS_OPENSETTINGS = "Open Squanch-On settings"

local defaults = {
  enabled = true,
  alwaysShowReticle = false,
  hordeReticleEnabled = true,
  nativeCenteredMouseover = true,
  nativeCombinedClick = false,
  nativeLeftClick = true,
  nativeCursorReturn = true,
  reticleAlpha = 0.55,
  reticleLineAlpha = 0.85,
  mouseoverIndicator = true,
  targetRangeIndicator = true,
  enableSafeHelperBindings = true,
  controlMouselookState = true,
  alwaysMouselook = true,
  autoMouselookWhileMoving = true,
  autoMouselookInCombat = true,
  useDeferWorkaround = true,
  useSpellTargetingOverride = true,
  useMouselookOverrideBindings = true,
  mouselookButton1Command = "TARGETSCANENEMY",
  mouselookButton2Command = "NULL",
  rightClickShowsReticle = true,
  aimXOffset = 0,
  aimYOffset = 0,
  cursorCenteredYPos = 0.5,
  invertRelockDelay = 0.08,
}

local state = {
  rightDown = false,
  lastMouselooking = nil,
  pendingBindings = false,
  pendingMouselook = false,
  manualEnabled = false,
  inverted = false,
  speedMoving = false,
  turnOrActionActive = false,
  cameraOrSelectOrMoveActive = false,
  nativeLeftPassthrough = false,
  movementHooksInstalled = false,
  overrideBindingsApplied = false,
  inRematch = false,
  relockTimer = nil,
  movement = {},
  centeringGeneration = 0,
  centeringApplied = nil,
  nativeLockActive = false,
  refreshNativeLock = false,
  spellTargeting = false,
  errors = { api = 0, cvar = 0 },
}

local pendingLeftDelta
-- /sqms receipts on|off. Off: the input path records nothing.
local debugReceipts = false

local MODIFIER_PREFIXES = {"", "SHIFT-", "CTRL-", "ALT-", "CTRL-SHIFT-", "ALT-SHIFT-", "ALT-CTRL-", "ALT-CTRL-SHIFT-"}
local BUTTON1_KEYS, BUTTON2_KEYS = {}, {}
for index, prefix in ipairs(MODIFIER_PREFIXES) do
  BUTTON1_KEYS[index], BUTTON2_KEYS[index] = prefix .. "BUTTON1", prefix .. "BUTTON2"
end

local frame = CreateFrame("Frame")

local function aimOffsets(db)
  return tonumber(db and db.aimXOffset) or 0, tonumber(db and db.aimYOffset) or 0
end

local function copyDefaults(src, dst)
  for key, value in pairs(src) do
    if dst[key] == nil then
      if type(value) == "table" then
        dst[key] = {}
        copyDefaults(value, dst[key])
      else
        dst[key] = value
      end
    elseif type(value) == "table" and type(dst[key]) == "table" then
      copyDefaults(value, dst[key])
    end
  end
end

local function safeCall(fn, ...)
  if not fn then return nil end
  local ok, result = pcall(fn, ...)
  if ok then return result end
  state.errors.api = state.errors.api + 1
  return nil
end

local function setCVar(name, value)
  if _G.SetCVar then
    local ok = pcall(_G.SetCVar, name, tostring(value))
    if not ok then state.errors.cvar = state.errors.cvar + 1 end
    return ok
  end
end

-- For settings that are not transition triggers: no write, and no CVAR_UPDATE
-- for every listener in the interface, when the client already holds the value.
local function setCVarIfChanged(name, value)
  local current = _G.GetCVar and tonumber(_G.GetCVar(name))
  if current ~= nil and current == tonumber(value) then return true end
  return setCVar(name, value)
end

local function isMouselooking()
  return _G.IsMouselooking and _G.IsMouselooking()
end

-- The input loop has no artwork or dependencies on a separate aura engine.
function addon:CreateReticle()
  self.reticle = self.reticle or {throttle = 0}
  frame:SetScript("OnUpdate", function(_, elapsed) addon:OnUpdate(elapsed) end)
end

function addon:UpdateAimPoint()
  if self.HordeReticle and self.HordeReticle.group then
    local x, y = aimOffsets(self.db)
    local relativePoint = "CENTER"
    if _G.GetCursorCenterPosition then
      local ok, centerX, centerY = pcall(GetCursorCenterPosition)
      if ok and type(centerX) == "number" and type(centerY) == "number" then
        -- SetPoint offsets use the positioned frame's effective scale.
        local scale = self.HordeReticle.group:GetEffectiveScale()
        x, y = centerX / scale + x, centerY / scale + y
        relativePoint = "BOTTOMLEFT"
      end
    end
    local reticle = self.HordeReticle
    if reticle.aimX ~= x or reticle.aimY ~= y or reticle.aimRelativePoint ~= relativePoint then
      reticle.group:ClearAllPoints()
      reticle.group:SetPoint("BOTTOMLEFT", UIParent, relativePoint, x, y)
      reticle.aimX, reticle.aimY, reticle.aimRelativePoint = x, y, relativePoint
    end
  end
end

function addon:HideReticleVisuals()
  if self.HordeReticle then
    local preference = self.db.hordeReticleEnabled
    self.HordeReticle:Hide()
    self.db.hordeReticleEnabled = preference
  end
end

function addon:UpdateReticle()
  if not self.db or not self.HordeReticle or not self.HordeReticle.initialized then return end
  local enabled = self.db.enabled and self.db.hordeReticleEnabled ~= false
  if self.HordeReticle.enabled ~= enabled then
    -- Master off is temporary; preserve the user's reticle preference.
    local preference = self.db.hordeReticleEnabled
    self.HordeReticle:SetEnabled(enabled)
    self.db.hordeReticleEnabled = preference
  end
end

function addon:RequestMouselookRematch()
  state.pendingMouselook = true
end

-- Transient UI suspension; saved gameplay/invert settings remain untouched.
local menuFrames = setmetatable({}, {__mode = "k"})
local menuWindowNames = {
  "CharacterFrame", "MerchantFrame", "GossipFrame", "QuestFrame", "PlayerSpellsFrame",
  "FriendsFrame", "WorldMapFrame", "BankFrame", "TradeFrame", "ItemTextFrame",
  "LootFrame", "ContainerFrameCombinedBags", "SettingsPanel", "AddonList", "MacroFrame",
  "MailFrame", "ProfessionsFrame", "ProfessionsBookFrame", "CollectionsJournal", "PVEFrame", "AchievementFrame",
  "DressUpFrame", "ChannelFrame", "InspectFrame", "PetStableFrame", "QuestLogFrame",
  "AuctionHouseFrame", "ClassTrainerFrame", "GuildBankFrame", "CalendarFrame", "TaxiFrame",
  "FlightMapFrame", "HelpFrame", "KeyBindingFrame", "ReadyCheckFrame", "DeathRecapFrame",
  "QuestLogPopupDetailFrame", "OpenMailFrame", "SendMailFrame", "ItemSocketingFrame", "ItemUpgradeFrame",
  "TabardFrame", "PetitionFrame", "GuildRegistrarFrame", "PVPUIFrame", "CommunitiesFrame",
  "ColorPickerFrame", "TimeManagerFrame", "LFGDungeonReadyDialog", "StaticPopup1", "StaticPopup2",
  "StaticPopup3", "StaticPopup4", "LFGParentFrame", "SocialUIFrame", "LegacySystemFrame",
  "EncounterJournal", "MacroPopupFrame", "ClassTalentLoadoutCreateDialog", "ClassTalentLoadoutEditDialog", "ClassTalentLoadoutImportDialog",
  "HeroTalentsSelectionDialog", "CalendarViewHolidayFrame", "CalendarViewRaidFrame", "CalendarViewEventFrame", "CalendarCreateEventFrame",
  "CalendarEventPickerFrame", "CalendarMassInviteFrame", "CalendarTexturePickerFrame", "CooldownViewerSettings", "CooldownViewerImportLayoutDialog",
  "CooldownViewerLayoutDialog", "ItemInteractionFrame", "PVPMatchResults", "PVPMatchScoreboard", "InspectRecipeFrame",
  "SideDressUpFrame", "BankCleanUpConfirmationPopup", "CurrencyTransferMenu", "CurrencyTransferLog", "GuildBankPopupFrame",
  "ChatConfigFrame", "ClickBindingFrame", "RaidInfoFrame", "RolePollPopup", "LFGInvitePopup",
  "PVPReadyDialog", "AddFriendFrame", "BattleNetInviteFrame", "FriendsFriendsFrame", "AddonDialog",
  "CreateChannelPopup", "CommunitiesAvatarPickerDialog", "CommunitiesSettingsDialog", "CommunitiesTicketManagerDialog", "CommunitiesGuildTextEditFrame",
  "CommunitiesGuildLogFrame", "CommunitiesGuildNewsFiltersFrame", "GuildControlUI", "GuildRenameFrame", "GuildInviteFrame",
  "ReportFrame", "ReportCheatingDialog", "TransmogFrame", "WardrobeCustomSetEditFrame", "EditModeManagerFrame",
  "EditModeLayoutDialog", "EditModeImportLayoutDialog", "EditModeUnsavedChangesDialog", "EditModeSystemSettingsDialog", "TutorialFrame",
  "GuideFrame", "BasicMessageDialog", "StackSplitFrame", "OpacityFrame", "QuickJoinRoleSelectionFrame",
  "GroupLootHistoryFrame", "ModelPreviewFrame", "SubscriptionInterstitialFrame", "GameMenuFrame", "InterfaceOptionsFrame",
  "VideoOptionsFrame", "AudioOptionsFrame",
}
function addon:RefreshMenuSuspension()
  local open = false
  for window in pairs(menuFrames) do
    if window:IsVisible() then open = true; break end
  end
  if _G.Menu and Menu.GetManager then
    local manager = Menu.GetManager()
    open = open or (manager and manager:IsAnyMenuOpen()) or false
  end
  if state.menuOpen ~= open then
    state.menuOpen = open
    if open then
      self:RestoreNativeLeftDelta("menu-open")
      self:ClearNativeCentering()
    end
    self:RequestMouselookRematch()
  end
end
function addon:TrackMenuFrame(window)
  if not window or not window.HookScript or menuFrames[window]
    or window.IsForbidden and window:IsForbidden() then return end
  menuFrames[window] = true
  window:HookScript("OnShow", function() self:RefreshMenuSuspension() end)
  window:HookScript("OnHide", function()
    self:RefreshMenuSuspension()
    -- Menu managers can remove their open entry after the frame hides.
    self:QueueMenuDiscovery()
  end)
end
function addon:DiscoverMenuFrames()
  for _, name in ipairs(menuWindowNames) do self:TrackMenuFrame(_G[name]) end
  for name in pairs(_G.UIPanelWindows or {}) do self:TrackMenuFrame(_G[name]) end
  for _, name in ipairs(_G.UISpecialFrames or {}) do self:TrackMenuFrame(_G[name]) end
  for i = 1, _G.NUM_CONTAINER_FRAMES or 7 do self:TrackMenuFrame(_G["ContainerFrame" .. i]) end
  -- The expanded quest tracker is persistent HUD, not a modal window. Keeping
  -- it visible must not hold the cursor after the full map/quest dialog closes.
  local engine = _G.ElvUI and ElvUI[1]
  local dialog = engine and engine.Libs and engine.Libs.AceConfigDialog
  if dialog then
    if self.menuOptionsOwner ~= dialog then
      self.menuOptionsOwner = dialog
      hooksecurefunc(dialog, "Open", function() self:QueueMenuDiscovery() end)
    end
    for _, widget in pairs(dialog.OpenFrames or {}) do self:TrackMenuFrame(widget.frame) end
  end
  self:RefreshMenuSuspension()
end
function addon:QueueMenuDiscovery()
  if self.menuDiscoveryQueued then return end
  self.menuDiscoveryQueued = true
  C_Timer.After(0, function()
    self.menuDiscoveryQueued = nil
    self:DiscoverMenuFrames()
  end)
end
function addon:InstallMenuSuspension()
  if self.menuSuspensionInstalled then return end
  self.menuSuspensionInstalled = true
  for _, name in ipairs({"ShowUIPanel", "HideUIPanel", "StaticPopup_Show", "ToggleDropDownMenu",
    "ToggleAllBags", "OpenAllBags", "ToggleBackpack", "ToggleBag"}) do
    if type(_G[name]) == "function" then hooksecurefunc(name, function() self:QueueMenuDiscovery() end) end
  end
  for _, name in ipairs({"ShowUIPanel", "StaticPopupSpecial_Show"}) do
    if type(_G[name]) == "function" then
      hooksecurefunc(name, function(window)
        if type(window) == "table" then self:TrackMenuFrame(window) end
        self:RefreshMenuSuspension()
      end)
    end
  end
  if _G.EventRegistry then
    EventRegistry:RegisterCallback("MenuProxy.OnShow", function(_, menu)
      self:TrackMenuFrame(menu)
      self:RefreshMenuSuspension()
    end, self)
    EventRegistry:RegisterCallback("MenuProxy.OnHide", function()
      self:RefreshMenuSuspension()
      self:QueueMenuDiscovery()
    end, self)
  end
  for i = 1, _G.UIDROPDOWNMENU_MAXLEVELS or 3 do self:TrackMenuFrame(_G["DropDownList" .. i]) end
  self:QueueMenuDiscovery()
end

function addon:AnyMovementActionActive()
  for _, active in pairs(state.movement) do
    if active then return true end
  end
  return false
end

function addon:IsAutoMouselookWanted()
  if not self.db then return false end
  if self.db.autoMouselookInCombat and _G.UnitAffectingCombat and _G.UnitAffectingCombat("player") then
    return true
  end
  if self.db.autoMouselookWhileMoving and (state.speedMoving or self:AnyMovementActionActive()) then
    return true
  end
  return false
end

function addon:ShouldMouselook()
  if state.layoutEditing or state.menuOpen then return false end
  local wanted = self.db.alwaysMouselook or state.manualEnabled or self:IsAutoMouselookWanted()
  if state.inverted then
    wanted = not wanted
  end
  return wanted
end

-- Editing is a transient suspension, never a change to saved gameplay settings.
function addon:SetLayoutEditing(active)
  active = active and true or false
  if state.layoutEditing == active then return end
  state.layoutEditing = active
  state.relockTimer = nil
  if active then
    self:RestoreNativeLeftDelta("layout-edit")
    self:SetMouseoverHeld(false)
    self:ClearNativeCentering()
    if isMouselooking() then safeCall(_G.MouselookStop) end
  end
  self:RequestMouselookRematch()
end

function addon:ShouldDeferStop()
  if not self.db or not self.db.useDeferWorkaround or not _G.IsMouseButtonDown then
    return false
  end
  for i = 1, 5 do
    if _G.IsMouseButtonDown(i) then
      return true
    end
  end
  return false
end

function addon:NativeLeftBindingBusy()
  return state.nativeLeftPassthrough or state.cameraOrSelectOrMoveActive
    or (_G.IsMouseButtonDown and _G.IsMouseButtonDown("LeftButton"))
end

function addon:ApplyNativeLeftClickSetting()
  if not self.db then return end
  if self:NativeLeftBindingBusy() then
    state.leftClickSettingPending = true
    return
  end
  state.leftClickSettingPending = false
  local current = safeCall(_G.GetCVar, "interactOnLeftClick")
  if current == nil then return end
  local enabled = self.db.nativeLeftClick and self.db.enabled
    and self.db.controlMouselookState and self.db.useMouselookOverrideBindings
  if enabled then
    if self.db.nativeLeftClickPreviousInteract == nil then
      self.db.nativeLeftClickPreviousInteract = current
    end
    setCVar("interactOnLeftClick", 1)
    self.db.nativeLeftClickOwnsInteract = safeCall(_G.GetCVar, "interactOnLeftClick") == "1"
  elseif self.db.nativeLeftClickPreviousInteract ~= nil then
    local previous = self.db.nativeLeftClickPreviousInteract
    if self.db.nativeLeftClickOwnsInteract and current == "1" then
      setCVar("interactOnLeftClick", previous)
      if safeCall(_G.GetCVar, "interactOnLeftClick") ~= previous then return end
    end
    self.db.nativeLeftClickPreviousInteract = nil
    self.db.nativeLeftClickOwnsInteract = nil
  end
end

local leftBinding = {}             -- what the eight BUTTON1 bindings were last set to
local bindingMap = {}              -- the values the client's mouselook map was last refreshed for
function addon:ApplyMouselookOverrideBindings()
  -- Waits for PLAYER_REGEN_ENABLED; the update loop does not retry in combat.
  if InCombatLockdown() then state.overrideBindingsPending=true;state.bindingCombatHold=true;return end
  state.bindingCombatHold = false
  if not _G.SetMouselookOverrideBinding then return end
  if self:NativeLeftBindingBusy() then
    state.overrideBindingsPending = true
    return
  end
  state.overrideBindingsPending = false
  if not self.mouseoverHoldButton then
    local hold = CreateFrame("Button", "SQMSHoldMouseoverButton", UIParent)
    hold:RegisterForClicks("AnyDown", "AnyUp")
    hold:SetScript("OnClick", function(_, _, down)
      addon:SetMouseoverHeld(down and true or false)
    end)
    self.mouseoverHoldButton = hold
  end
  -- The full application always writes the left-button bindings again.
  leftBinding.command = nil
  if self.db and self.db.useMouselookOverrideBindings then
    self:ApplyNativeLeftBinding(true)
    -- Right-click is a precision gate, including the owner's action modifiers.
    for index = 1, #BUTTON2_KEYS do
      local command = self.db.nativeCenteredMouseover and "CLICK SQMSHoldMouseoverButton:RightButton"
        or (index == 1 and (self.db.mouselookButton2Command or "NULL") or nil)
      safeCall(_G.SetMouselookOverrideBinding, BUTTON2_KEYS[index], command)
    end
  else
    self:ApplyNativeLeftBinding(true)
    for index = 1, #BUTTON2_KEYS do
      safeCall(_G.SetMouselookOverrideBinding, BUTTON2_KEYS[index], nil)
    end
  end
  self:RefreshNativeBindingMap()
  state.overrideBindingsApplied = self.db and self.db.useMouselookOverrideBindings or false
end

-- Keep the native down/up command paired across the whole physical press.
-- The right-held path retains the configured command and old helper bindings.
function addon:ApplyNativeLeftBinding(deferRefresh)
  if InCombatLockdown() then state.leftBindingUpdatePending=true;state.bindingCombatHold=true;return end
  state.bindingCombatHold = false
  if not self.db or not _G.SetMouselookOverrideBinding then return end
  if self:NativeLeftBindingBusy() then
    state.leftBindingUpdatePending = true
    return
  end
  state.leftBindingUpdatePending = false
  local db = self.db
  local enabled = db.useMouselookOverrideBindings and true or false
  local chord = enabled and db.nativeCombinedClick and true or false
  local leftClick = enabled and db.nativeLeftClick and db.enabled
    and db.controlMouselookState and true or false
  local rightHeld = state.rightDown
    or (_G.IsMouseButtonDown and _G.IsMouseButtonDown("RightButton"))
  local base = db.mouselookButton1Command or "TARGETSCANENEMY"
  local active = chord and state.rightDown and db.enabled
    and db.nativeCenteredMouseover and db.controlMouselookState and not state.inverted
  local command = active and "INTERACTMOUSEOVER"
    or (leftClick and not rightHeld and "CAMERAORSELECTORMOVE" or base)
  -- Every modifier carries the command, or only the bare button does.
  local every = (chord or (leftClick and not rightHeld)) and true or false
  if leftBinding.enabled ~= enabled or leftBinding.every ~= every or leftBinding.command ~= command then
    local written = true
    for index = 1, #BUTTON1_KEYS do
      local ok = pcall(_G.SetMouselookOverrideBinding, BUTTON1_KEYS[index],
        enabled and ((every or index == 1) and command or nil) or nil)
      if not ok then written = false; state.errors.api = state.errors.api + 1 end
    end
    leftBinding.enabled, leftBinding.every, leftBinding.command = enabled, every, written and command or nil
  end
  local centered, button2 = db.nativeCenteredMouseover and true or false, db.mouselookButton2Command or "NULL"
  if bindingMap.enabled ~= enabled or bindingMap.chord ~= chord or bindingMap.leftClick ~= leftClick
    or bindingMap.command ~= command or bindingMap.centered ~= centered or bindingMap.button2 ~= button2 then
    bindingMap.enabled, bindingMap.chord, bindingMap.leftClick = enabled, chord, leftClick
    bindingMap.command, bindingMap.centered, bindingMap.button2 = command, centered, button2
    state.bindingRefreshPending = true
  end
  if not deferRefresh then self:RefreshNativeBindingMap() end
end

function addon:RefreshNativeBindingMap()
  if not state.bindingRefreshPending or self:NativeLeftBindingBusy() then return end
  state.bindingRefreshPending = false
  if not isMouselooking() then return end
  if not self.db.enabled or not self.db.controlMouselookState or not self:ShouldMouselook()
    or (_G.SpellIsTargeting and _G.SpellIsTargeting())
    or (_G.GetCurrentKeyBoardFocus and _G.GetCurrentKeyBoardFocus()) then
    self:RequestMouselookRematch()
    return
  end
  -- This client snapshots its mouselook binding map on entry. Clear centering
  -- before refreshing that map, then restore only a still-valid right-held gate.
  self:ApplyCursorCentering(false)
  safeCall(_G.MouselookStop)
  safeCall(_G.MouselookStart)
  state.centeringGeneration = state.centeringGeneration + 1
  local generation = state.centeringGeneration
  C_Timer.After(0, function()
    if generation == state.centeringGeneration and addon.db.enabled
      and addon.db.controlMouselookState and addon.db.nativeCenteredMouseover
      and addon:ShouldMouselook() and isMouselooking()
      and not (_G.SpellIsTargeting and _G.SpellIsTargeting()) then
      addon:ApplyCursorCentering(state.rightDown and not state.inverted)
    end
  end)
end

-- Diagnostics, off unless /sqms receipts on: one ring of the last 32 input
-- transitions under nativeReceipts.
function addon:RecordNativeReceipt(reason, detail)
  if not debugReceipts or not self.db then return end
  local receipts = self.db.nativeReceipts
  if type(receipts) ~= "table" then
    receipts = {}
    self.db.nativeReceipts = receipts
  end
  local cvars = {}
  for _, name in ipairs({ "CursorFreelookCentering", "CursorStickyCentering", "CursorCenteredYPos",
    "CursorFreelookStartDelta", "cameraYawMoveSpeed", "cameraPitchMoveSpeed" }) do
    cvars[name] = safeCall(_G.GetCVar, name)
  end
  local x, y = GetCursorPosition()
  receipts[#receipts + 1] = {
    reason = reason,
    detail = detail,
    time = safeCall(_G.GetTime),
    mouselooking = isMouselooking() and true or false,
    nativeEnabled = self.db.nativeCenteredMouseover and true or false,
    inverted = state.inverted,
    rightHeld = state.rightDown,
    combat = InCombatLockdown() and true or false,
    cursorX = x, cursorY = y,
    cvars = cvars,
    errors = { api = state.errors.api, cvar = state.errors.cvar },
  }
  while #receipts > 32 do table.remove(receipts, 1) end
end

-- Rendering follows the engine's aim center while native lock owns the mouse.
-- This reports state only: it does not enable mouseover or move the cursor.
function addon:IsNativeLockCentered()
  return self.db and self.db.enabled and self.db.nativeCenteredMouseover
    and state.nativeLockActive and not state.inverted and not state.layoutEditing and not state.menuOpen
    and isMouselooking()
    and not (_G.SpellIsTargeting and _G.SpellIsTargeting())
end

function addon:IsNativeMouseoverOpen()
  return state.rightDown and state.centeringApplied == true
    and self:IsNativeLockCentered() and GetCVar("CursorFreelookCentering") == "1"
end

function addon:ApplyCursorCentering(centered)
  if not self.db then return end
  centered = centered and not state.menuOpen and true or false
  if state.centeringApplied == centered then return end
  if setCVar("CursorFreelookCentering", centered and 1 or 0) then
    state.centeringApplied = centered
  end
  if self.MouseoverInteractIcon then self.MouseoverInteractIcon:Refresh() end
end

function addon:SetMouseoverHeld(held)
  local allowed = held and self.db and self.db.enabled and self.db.nativeCenteredMouseover
    and self.db.controlMouselookState and not state.layoutEditing and not state.inverted and not state.menuOpen and isMouselooking()
    and not (_G.SpellIsTargeting and _G.SpellIsTargeting())
  local wasHeld = state.rightDown
  state.rightDown = allowed and true or false
  if state.rightDown ~= wasHeld or (self.db and self.db.nativeLeftClick) then
    self:ApplyNativeLeftBinding()
  end
  -- Release closes mouseover immediately without stopping the locked camera.
  self:ApplyCursorCentering(state.rightDown)
  -- Nameplates learn of the gate on this very call, not on their next tick.
  if self.Nameplates and self.Nameplates.GateChanged then self.Nameplates:GateChanged() end
  self:UpdateReticle()
  self:RecordNativeReceipt(state.rightDown and "mouseover-open" or "mouseover-closed")
end

-- Native cursor-return candidate. The engine can remember a centered unlock
-- position when it enters mouselook with centering enabled. Use the minimum
-- accepted speed only for that transition, then restore the owner's settings.
local cameraReturnNames = { "cameraYawMoveSpeed", "cameraPitchMoveSpeed" }
local pendingCameraReturn

-- More than half a pixel from the engine's aim center (or not knowable).
local function cursorOffCenter()
  if not _G.GetCursorCenterPosition then return true end
  local x, y = GetCursorPosition()
  local centerX, centerY = GetCursorCenterPosition()
  return math.abs(x - centerX) > 0.5 or math.abs(y - centerY) > 0.5
end

function addon:RestoreNativeLeftDelta(reason, force)
  local pending = pendingLeftDelta
  if not pending then return end
  local current = safeCall(_G.GetCVar, "CursorFreelookStartDelta")
  if force or tonumber(current) == 0 then
    setCVar("CursorFreelookStartDelta", pending.previous)
    current = safeCall(_G.GetCVar, "CursorFreelookStartDelta")
    if tonumber(current) == tonumber(pending.previous) then pendingLeftDelta = nil end
  else
    -- Another owner changed it during the press; its newer value stays.
    pendingLeftDelta = nil
  end
  self:RecordNativeReceipt("left-delta-restore", reason)
end

function addon:PrepareNativeLeftDelta()
  self:RestoreNativeLeftDelta("superseded-left")
  if pendingLeftDelta then return end
  local previous = safeCall(_G.GetCVar, "CursorFreelookStartDelta")
  if not tonumber(previous) or not _G.C_Timer or not _G.C_Timer.After then return end
  -- Already zero: the native down needs no change and there is nothing to restore.
  if tonumber(previous) == 0 then return end
  local pending = {previous = previous}
  pendingLeftDelta = pending
  if not setCVar("CursorFreelookStartDelta", 0)
    or tonumber(safeCall(_G.GetCVar, "CursorFreelookStartDelta")) ~= 0 then
    self:RestoreNativeLeftDelta("delta-rejected", true)
    return
  end
  C_Timer.After(0, function()
    if pendingLeftDelta == pending then addon:RestoreNativeLeftDelta("next-update-fallback") end
  end)
end

function addon:RestoreNativeCursorReturn(reason, force)
  local values = pendingCameraReturn
  if not values then return end
  pendingCameraReturn = nil
  for _, name in ipairs(cameraReturnNames) do
    -- A value other than our 0.1 belongs to another settings owner that changed
    -- it during the transition; leave it instead of restoring stale preferences.
    if force or tonumber(GetCVar(name)) == 0.1 then setCVar(name, values[name]) end
  end
  -- The camera module owns these two speeds outside this transition.
  if addon.Camera then addon.Camera:HoldSpeeds(false) end
  self:RecordNativeReceipt("cursor-return-restore", reason)
end

-- This is a single synchronous transition. Do not defer centering until
-- after Start: that changed mouseover in the failed implementation, not the
-- pointer position that the engine remembers for the next unlock.
local function centeredTransition(self)
  self:ApplyCursorCentering(true)
  if GetCVar("CursorFreelookCentering") ~= "1"
    or GetCVar("CursorStickyCentering") ~= "1" then error("centering-rejected") end
  MouselookStart()
  MouselookStop()
end

-- Returns nil when no return is attempted, else its status.
local function prepareCenteredReturn(self)
  if not self.db.nativeCursorReturn or not _G.C_Timer or not _G.C_Timer.After then return end
  if (_G.SpellIsTargeting and _G.SpellIsTargeting())
    or (_G.GetCurrentKeyBoardFocus and _G.GetCurrentKeyBoardFocus()) then return end
  if not isMouselooking() and not cursorOffCenter() then return "already-centered" end
  local values = {}
  for _, name in ipairs(cameraReturnNames) do
    values[name] = GetCVar(name)
    if not tonumber(values[name]) then return "unreadable-camera-speed" end
  end
  pendingCameraReturn = values
  if addon.Camera then addon.Camera:HoldSpeeds(true) end
  for _, name in ipairs(cameraReturnNames) do
    if not setCVar(name, 0.1) or tonumber(GetCVar(name)) ~= 0.1 then
      self:RestoreNativeCursorReturn("rejected-before-centering", true)
      return "camera-speed-rejected"
    end
  end
  C_Timer.After(0, function()
    if pendingCameraReturn == values then
      addon:RestoreNativeCursorReturn("next-update")
    end
  end)
  local ok = pcall(centeredTransition, self)
  self:ApplyCursorCentering(false)
  if not (ok and not isMouselooking() and GetCVar("CursorFreelookCentering") == "0") then
    state.errors.api = state.errors.api + 1
    self:RestoreNativeCursorReturn("transition-failed")
    return "transition-failed"
  end
  return "awaiting-unlock-verification"
end

function addon:ClearNativeCentering(force)
  -- Cancellation releases the temporary speed settings before another owner starts.
  self:RestoreNativeCursorReturn("cancelled-state-change")
  state.centeringGeneration = state.centeringGeneration + 1
  state.nativeLockActive = false
  if force then state.centeringApplied = nil end
  self:ApplyCursorCentering(false)
end

function addon:StartNativeMouselook()
  self:ClearNativeCentering(true)
  setCVarIfChanged("CursorStickyCentering", 1)
  setCVarIfChanged("CursorCenteredYPos", tonumber(self.db.cursorCenteredYPos) or defaults.cursorCenteredYPos)
  if isMouselooking() then safeCall(_G.MouselookStop) end
  prepareCenteredReturn(self)
  if isMouselooking() or GetCVar("CursorFreelookCentering") ~= "0" then
    -- A setter or Stop may fail without throwing. Clean up once and verify
    -- the ordinary-start preconditions before entering the camera again.
    state.centeringApplied = nil
    self:ApplyCursorCentering(false)
    safeCall(_G.MouselookStop)
    self:RestoreNativeCursorReturn("incomplete-transition", true)
    if isMouselooking() or GetCVar("CursorFreelookCentering") ~= "0" then
      return
    end
  end
  safeCall(_G.MouselookStart)
  state.nativeLockActive = isMouselooking() and true or false
  state.refreshNativeLock = false
  local generation = state.centeringGeneration
  local function centerAfterStart()
    if generation ~= state.centeringGeneration or not state.nativeLockActive
      or not addon.db.enabled or not addon.db.controlMouselookState
      or not addon:ShouldMouselook() or not isMouselooking()
      or (addon.db.useSpellTargetingOverride and _G.SpellIsTargeting and _G.SpellIsTargeting()) then
      return
    end
    addon:ApplyCursorCentering(addon.db.nativeCenteredMouseover and state.rightDown)
    addon:RecordNativeReceipt("native-lock")
  end
  -- The final ordinary start hides the cursor. Only the right-held gate may
  -- enable steady mouseover after the temporary return-position transition.
  if _G.C_Timer and _G.C_Timer.After then
    _G.C_Timer.After(0, centerAfterStart)
  else
    centerAfterStart()
  end
end

function addon:StopNativeMouselook()
  self:ClearNativeCentering(true)
  safeCall(_G.MouselookStop)
  self:RecordNativeReceipt("native-unlock")
end

function addon:RematchMouselook()
  if state.inRematch or not self.db or not self.db.enabled or not self.db.controlMouselookState then
    state.pendingMouselook = false
    return
  end
  if state.relockTimer and not state.menuOpen then
    state.pendingMouselook = false
    return
  end
  local wanted = self:ShouldMouselook()
  if self.db.useSpellTargetingOverride and _G.SpellIsTargeting and _G.SpellIsTargeting() then
    wanted = false
  end
  -- Busy native actions defer locking only. A Caps-held release must remain
  -- reachable even if a prior native action lost its matching stop callback.
  if wanted and (state.nativeLeftPassthrough or state.turnOrActionActive or state.cameraOrSelectOrMoveActive) then return end

  state.inRematch = true
  state.pendingMouselook = false
  local current = isMouselooking() and true or false
  local focused = _G.GetCurrentKeyBoardFocus and _G.GetCurrentKeyBoardFocus()
  if wanted and not focused and (not current or not state.nativeLockActive or state.refreshNativeLock) then
    self:StartNativeMouselook()
  elseif not wanted then
    if current and (state.inverted or state.menuOpen or not self:ShouldDeferStop()) then
      self:StopNativeMouselook()
    else
      self:ClearNativeCentering()
      if current then state.pendingMouselook = true end
    end
  end
  state.inRematch = false
  self:UpdateReticle()
end

function addon:OnUpdate(elapsed)
  if not self.reticle then return end
  -- Close-only recovery if focus or modifier changes swallow the binding's up edge.
  -- A physical press must open through the native click binding, never polling.
  if state.rightDown and _G.IsMouseButtonDown and not _G.IsMouseButtonDown("RightButton") then
    self:SetMouseoverHeld(false)
  end

  if state.nativeLeftPassthrough and _G.IsMouseButtonDown
    and not _G.IsMouseButtonDown("LeftButton") then
    -- Recovery closes our own press only; it never creates a click or movement.
    self:RestoreNativeLeftDelta("lost-left-up")
    state.nativeLeftPassthrough = false
    state.cameraOrSelectOrMoveActive = false
    state.leftBindingUpdatePending = true
    self:RequestMouselookRematch()
  end
  -- Reconcile only actions started by a physical mouse press. Keyboard-bound
  -- camera actions retain their own native start/stop lifecycle.
  if state.cameraOrSelectOrMoveActive and state.cameraMouseOwned and not IsMouseButtonDown("LeftButton") then
    state.cameraOrSelectOrMoveActive = false
    state.cameraMouseOwned = false
    self:RequestMouselookRematch()
  end
  if state.turnOrActionActive and state.turnMouseOwned and not IsMouseButtonDown("RightButton") then
    state.turnOrActionActive = false
    state.turnMouseOwned = false
    self:RequestMouselookRematch()
  end
  -- Deferred binding work. A write refused by combat lockdown waits for
  -- PLAYER_REGEN_ENABLED instead of being retried here every frame.
  local bindingsPending = state.overrideBindingsPending or state.leftBindingUpdatePending
  if (state.leftClickSettingPending or (bindingsPending and not state.bindingCombatHold)
    or (not bindingsPending and state.bindingRefreshPending)) and not self:NativeLeftBindingBusy() then
    if state.leftClickSettingPending then self:ApplyNativeLeftClickSetting() end
    if bindingsPending then
      if state.bindingCombatHold then
        -- still in combat
      elseif state.overrideBindingsPending then
        self:ApplyMouselookOverrideBindings()
      else
        self:ApplyNativeLeftBinding()
      end
    elseif state.bindingRefreshPending then
      self:RefreshNativeBindingMap()
    end
  end

  if state.relockTimer then
    state.relockTimer = state.relockTimer - elapsed
    if state.relockTimer <= 0 then
      state.relockTimer = nil
      self:RequestMouselookRematch()
    end
  end
  if state.pendingMouselook then
    self:RematchMouselook()
  end
  self.reticle.throttle = self.reticle.throttle + elapsed
  if self.reticle.throttle < 0.05 then return end
  self.reticle.throttle = 0

  -- Reuse the existing 50ms observer; range also changes while both units move.
  if self.TargetCrosshairs then self.TargetCrosshairs:RefreshRange() end
  -- Shares the existing observer; cursor art can change without a unit change.
  if self.MouseoverInteractIcon then self.MouseoverInteractIcon:Refresh() end

  local keyboardFocused = _G.GetCurrentKeyBoardFocus and _G.GetCurrentKeyBoardFocus() ~= nil
  if state.keyboardFocused ~= keyboardFocused then
    state.keyboardFocused = keyboardFocused
    if not keyboardFocused then self:RequestMouselookRematch() end
  end

  local mouselooking = isMouselooking() and true or false
  if state.lastMouselooking ~= mouselooking then
    state.lastMouselooking = mouselooking
    if not mouselooking then self:ClearNativeCentering() end
    self:RequestMouselookRematch()
    self:RecordNativeReceipt("mouselook-transition")
  end
  -- Targeting can begin/end without a movement edge. Observe its state only;
  -- centering CVars are written by transitions, never by the update loop.
  local targeting = self.db.useSpellTargetingOverride and _G.SpellIsTargeting and _G.SpellIsTargeting() and true or false
  if state.spellTargeting ~= targeting then
    state.spellTargeting = targeting
    self:RequestMouselookRematch()
  end

  self:UpdateReticle()
end

function addon:SetMovementAction(action, active)
  if state.movement[action] == active then return end
  state.movement[action] = active
  self:RequestMouselookRematch()
end

function addon:InstallMovementHooks()
  if state.movementHooksInstalled then return end
  state.movementHooksInstalled = true

  local actions = {
    "MoveForward",
    "MoveBackward",
    "StrafeLeft",
    "StrafeRight",
    "MoveAndSteer",
    "TurnLeft",
    "TurnRight",
  }

  for _, action in ipairs(actions) do
    if _G[action .. "Start"] then
      hooksecurefunc(action .. "Start", function()
        addon:SetMovementAction(action, true)
      end)
    end
    if _G[action .. "Stop"] then
      hooksecurefunc(action .. "Stop", function()
        addon:SetMovementAction(action, false)
      end)
    end
  end

  if _G.TurnOrActionStart then
    hooksecurefunc("TurnOrActionStart", function()
      state.turnOrActionActive = true
      state.turnMouseOwned = IsMouseButtonDown("RightButton")
    end)
  end
  if _G.TurnOrActionStop then
    hooksecurefunc("TurnOrActionStop", function()
      state.turnOrActionActive = false
      state.turnMouseOwned = false
      addon:RequestMouselookRematch()
    end)
  end
  if _G.CameraOrSelectOrMoveStart then
    hooksecurefunc("CameraOrSelectOrMoveStart", function()
      state.cameraOrSelectOrMoveActive = true
      state.cameraMouseOwned = IsMouseButtonDown("LeftButton")
      if state.cameraMouseOwned and addon.TargetCrosshairs then
        addon.TargetCrosshairs:BeginWorldClick()
      end
      if state.nativeLeftPassthrough and pendingLeftDelta then
        addon:RestoreNativeLeftDelta("native-camera-start")
      end
    end)
  end
  if _G.CameraOrSelectOrMoveStop then
    hooksecurefunc("CameraOrSelectOrMoveStop", function()
      if state.cameraMouseOwned and addon.TargetCrosshairs then
        addon.TargetCrosshairs:ObserveWorldClick(state.nativeLeftPassthrough)
      end
      state.cameraOrSelectOrMoveActive = false
      state.cameraMouseOwned = false
      local ownedLeft = state.nativeLeftPassthrough
      if ownedLeft then
        addon:RestoreNativeLeftDelta("native-left-release")
        state.nativeLeftPassthrough = false
        state.leftBindingUpdatePending = true
      end
      -- Map writes wait until the next update; our released press relocks now.
      addon:RequestMouselookRematch()
      if ownedLeft then addon:RematchMouselook() end
    end)
  end
end

function addon:InvertMouselook(active)
  self:RestoreNativeLeftDelta("invert-change")
  state.inverted = active and true or false
  if state.inverted then
    state.relockTimer = nil
    self:SetMouseoverHeld(false)
    self:ClearNativeCentering()
  else
    self:ClearNativeCentering()
    state.relockTimer = tonumber(self.db and self.db.invertRelockDelay) or defaults.invertRelockDelay
  end
  self:RequestMouselookRematch()
end

function addon:ToggleMouselook()
  state.manualEnabled = not state.manualEnabled
  self:RequestMouselookRematch()
end

function addon:LockMouselook()
  state.manualEnabled = true
  self:RequestMouselookRematch()
end

function addon:UnlockMouselook()
  state.manualEnabled = false
  state.inverted = false
  self:RequestMouselookRematch()
end

function addon:CreateSafeButtons()
  if self.bindingOwner then return end
  self.bindingOwner = CreateFrame("Frame", "SquancherMouselookSuiteBindingOwner", UIParent)
end

function addon:ApplySafeBindings()
  if not self.db or not self.db.enableSafeHelperBindings then
    self:ClearSafeBindings()
    return
  end
  if _G.InCombatLockdown and _G.InCombatLockdown() then
    state.pendingBindings = true
    return
  end

  self:CreateSafeButtons()
  if _G.ClearOverrideBindings then
    safeCall(_G.ClearOverrideBindings, self.bindingOwner)
  end
  if _G.SetOverrideBinding then
    if self.db.enabled and self.db.controlMouselookState then
      for _, prefix in ipairs(MODIFIER_PREFIXES) do
        safeCall(_G.SetOverrideBinding, self.bindingOwner, true, prefix .. "CAPSLOCK", "SQMS_INVERTMOUSELOOK")
        safeCall(_G.SetOverrideBinding, self.bindingOwner, true, prefix .. "UP", "SQMS_INVERTMOUSELOOK")
      end
    end
    safeCall(_G.SetOverrideBinding, self.bindingOwner, true, "F8", "INTERACTMOUSEOVER")
    safeCall(_G.SetOverrideBinding, self.bindingOwner, true, "F9", "TARGETMOUSEOVER")
  end
  state.pendingBindings = false
end

function addon:StopLockedMouselook()
  self:RestoreNativeLeftDelta("stop-locked")
  state.rightDown = false
  self:ApplyNativeLeftBinding()
  state.manualEnabled = false
  state.inverted = false
  self:ClearNativeCentering()
  if _G.MouselookStop and isMouselooking() then
    safeCall(_G.MouselookStop)
  end
  self:RecordNativeReceipt("stop")
  self:UpdateReticle()
end

function addon:ClearSafeBindings()
  if self.bindingOwner and _G.ClearOverrideBindings and (not _G.InCombatLockdown or not _G.InCombatLockdown()) then
    safeCall(_G.ClearOverrideBindings, self.bindingOwner)
  end
  state.pendingBindings = false
end

function addon:BeginNativeLeftClick(button)
  if state.layoutEditing or button ~= "LeftButton" or not self.db or not self.db.nativeLeftClick
    or not self.db.enabled or not self.db.controlMouselookState
    or not self.db.useMouselookOverrideBindings
    or state.nativeLeftPassthrough or state.inverted or state.menuOpen
    or not _G.IsMouseButtonDown or not _G.IsMouseButtonDown("LeftButton")
    or state.rightDown or _G.IsMouseButtonDown("RightButton")
    or (_G.SpellIsTargeting and _G.SpellIsTargeting())
    or (_G.GetCurrentKeyBoardFocus and _G.GetCurrentKeyBoardFocus()) then return end
  local pendingRelock = state.relockTimer ~= nil and self:ShouldMouselook()
  if not pendingRelock and not (state.nativeLockActive and isMouselooking()) then return end
  -- A real UI click during the relock gap stays at its free-cursor position.
  if _G.GetMouseFoci then
    for _, focus in ipairs(_G.GetMouseFoci()) do
      if focus ~= WorldFrame then return end
    end
  end
  state.nativeLeftPassthrough = true
  state.relockTimer = nil
  -- Stop before preparing a return: another Stop afterward would restore the
  -- temporary camera speeds before the original native CameraStart consumes it.
  self:StopNativeMouselook()
  local status = "released-owned-lock"
  if pendingRelock or cursorOffCenter() then
    setCVarIfChanged("CursorStickyCentering", 1)
    setCVarIfChanged("CursorCenteredYPos", tonumber(self.db.cursorCenteredYPos) or defaults.cursorCenteredYPos)
    local ok, prepared = pcall(prepareCenteredReturn, self)
    local preparedOK = ok and (prepared == "already-centered" or prepared == "awaiting-unlock-verification")
    if not preparedOK or isMouselooking() or GetCVar("CursorFreelookCentering") ~= "0" then
      -- Failed preparation must still leave the original click its free path.
      state.centeringApplied = nil
      self:ApplyCursorCentering(false)
      safeCall(_G.MouselookStop)
      self:RestoreNativeCursorReturn("left-prepare-failed")
      status = "fallback-prepare-failed"
      if not ok then state.errors.api = state.errors.api + 1 end
    else
      status = "left-return-prepared"
    end
  end
  -- Remain unlocked for this physical press; preparation owns its existing
  -- next-update speed restore. No new click or gameplay action is dispatched.
  -- Zero only the original native down threshold, then restore in its posthook.
  self:PrepareNativeLeftDelta()
  self:RecordNativeReceipt("left-click", status)
end

function addon:InstallMouseHooks()
  if self.mouseHooksInstalled then return end
  self.mouseHooksInstalled = true

  WorldFrame:HookScript("OnMouseDown", function(_, button)
    if button ~= "RightButton" then return end
    addon:SetMouseoverHeld(true)
  end)

  WorldFrame:HookScript("OnMouseUp", function(_, button)
    if button ~= "RightButton" then return end
    addon:SetMouseoverHeld(false)
    addon:RequestMouselookRematch()
  end)
end

function addon:GetInputState()
  local visibleMenus = {}
  local visibleMenuCount = 0
  for window in pairs(menuFrames) do
    if window:IsVisible() then
      visibleMenuCount = visibleMenuCount + 1
      if #visibleMenus < 12 then visibleMenus[#visibleMenus + 1] = window:GetName() or "anonymous" end
    end
  end
  table.sort(visibleMenus)
  local focus = _G.GetCurrentKeyBoardFocus and _G.GetCurrentKeyBoardFocus()
  local manager = _G.Menu and Menu.GetManager and Menu.GetManager()
  local drawer = self.QuestDrawer and self.QuestDrawer.frame
  return {inverted=state.inverted, rightDown=state.rightDown,
    menuOpen=state.menuOpen, visibleMenus=visibleMenus, layoutEditing=state.layoutEditing,
    visibleMenuCount=visibleMenuCount, menuManagerOpen=manager and manager:IsAnyMenuOpen(),
    questDrawerVisible=drawer and drawer:IsVisible(),
    spellTargeting=state.spellTargeting, keyboardFocused=focus ~= nil,
    keyboardFocusName=focus and focus:GetName(), keyboardFocusVisible=focus and focus:IsVisible(),
    nativeLeftPassthrough=state.nativeLeftPassthrough,
    cameraOrSelectOrMoveActive=state.cameraOrSelectOrMoveActive,
    turnOrActionActive=state.turnOrActionActive, nativeLockActive=state.nativeLockActive,
    pendingMouselook=state.pendingMouselook, relockTimer=state.relockTimer,
    wanted=self.db and self:ShouldMouselook()}
end

function addon:PrintStatus()
  local mouselooking = isMouselooking() and "yes" or "no"
  local rightDown = state.rightDown and "yes" or "no"
  local safeBindings = self.db.enableSafeHelperBindings and "on" or "off"
  local lockControl = self.db.controlMouselookState and "on" or "off"
  local alwaysMouselook = self.db.alwaysMouselook and "on" or "off"
  local centerReticle = self.db.hordeReticleEnabled and "on" or "off"
  local inverted = state.inverted and "yes" or "no"
  local nativeCentered = self.db.nativeCenteredMouseover and "on" or "off"
  print("|cff33ff99Squanch-On|r safe addon loaded; mouselooking="
    .. mouselooking .. " rightDown=" .. rightDown .. " helperBindings=" .. safeBindings
    .. " lockControl=" .. lockControl .. " alwaysMouselook=" .. alwaysMouselook
    .. " centerReticle=" .. centerReticle
    .. " inverted=" .. inverted .. " nativeCenteredMouseover=" .. nativeCentered
    .. " nativeLeftClick=" .. tostring(self.db.nativeLeftClick))
end

function addon:SlashCommand(msg)
  local command = msg or ""
  if command == "camera" or command:match("^camera%s+") then
    self.Camera:Command(command:match("^camera%s+(.*)$") or "")
    return
  end
  if command == "edit" or command == "layout" or command == "unlock" then self.LayoutEditor:Toggle(); return end
  if command == "settings" then self:OpenOptions(); return end
  if command == "tooltip" or command == "unitframes" or command == "nameplates" then self:OpenOptions(command); return end
  if command:match("^nameplates%s+") then self.NameplateIndicators:Slash(command:match("^nameplates%s+(.+)$")); return end
  if command:match("^crosshairs%s*") then self.TargetCrosshairs:SlashCommand(command:match("^crosshairs%s*(.*)$")); return end
  if command:match("^mouseover%s*") then self:MouseoverCastingCommand(command:match("^mouseover%s*(.*)$")); return end
  local reticleScale = command:match("^reticle%s+scale%s+([%d%.]+)$")
  if reticleScale then
    local value = tonumber(reticleScale)
    if value and value >= 0.1 and value <= 2 then
      self.db.hordeReticleScale = value
      self.HordeReticle:ApplyReticleScale()
      print("Squancher: Horde reticle size " .. math.floor(value * 100 + 0.5) .. "% of original.")
    else
      print("Squancher: reticle scale must be between 0.1 and 2 (1 is original size).")
    end
    return
  end
  msg = string.lower(command)
  if msg == "on" then
    self.db.enabled = true
    self:ApplyNativeLeftClickSetting()
    self:ApplyMouselookOverrideBindings()
    self:ApplySafeBindings()
    self:RequestMouselookRematch()
    self:UpdateReticle()
    print("|cff33ff99Squanch-On|r enabled")
  elseif msg == "off" then
    self.db.enabled = false
    self:StopLockedMouselook()
    self:ApplyNativeLeftClickSetting()
    self:ApplyMouselookOverrideBindings()
    self:ApplySafeBindings()
    self:HideReticleVisuals()
    print("|cff33ff99Squanch-On|r disabled")
  elseif msg == "reticle on" then
    self.db.hordeReticleEnabled = true
    self:UpdateReticle()
    print("|cff33ff99Squanch-On|r center reticle enabled")
  elseif msg == "reticle off" then
    self.db.hordeReticleEnabled = false
    self:UpdateReticle()
    print("|cff33ff99Squanch-On|r Horde reticle disabled")
  elseif msg == "bindings on" then
    self.db.enableSafeHelperBindings = true
    self:ApplySafeBindings()
    print("|cff33ff99Squanch-On|r helper bindings enabled")
  elseif msg == "bindings off" then
    self.db.enableSafeHelperBindings = false
    self:ClearSafeBindings()
    print("|cff33ff99Squanch-On|r helper bindings disabled")
  elseif msg == "chord on" or msg == "chord off" then
    self.db.nativeCombinedClick = msg == "chord on"
    self:ApplyMouselookOverrideBindings()
    print("SQMS native interaction binding: " .. (self.db.nativeCombinedClick and "on" or "off"))
  elseif msg == "left on" or msg == "left off" then
    self.db.nativeLeftClick = msg == "left on"
    if not self.db.nativeLeftClick then self:RestoreNativeLeftDelta("left-disabled") end
    self:ApplyNativeLeftClickSetting()
    self:ApplyMouselookOverrideBindings()
    self:RequestMouselookRematch()
    print("SQMS native left click: " .. (self.db.nativeLeftClick and "on" or "off"))
  elseif msg == "return on" or msg == "return off" then
    self.db.nativeCursorReturn = msg == "return on"
    print("Squancher native cursor return: " .. (self.db.nativeCursorReturn and "on" or "off"))
  elseif msg == "receipts on" or msg == "receipts off" then
    debugReceipts = msg == "receipts on"
    self.db.debugReceipts = debugReceipts or nil
    if not debugReceipts then self.db.nativeReceipts = nil end
    print("Squancher input receipts: " .. (debugReceipts and "on (last 32 transitions are saved)" or "off"))
  elseif msg == "native on" or msg == "native off" then
    self.db.nativeCenteredMouseover = msg == "native on"
    self:ApplyMouselookOverrideBindings()
    state.refreshNativeLock = true
    self:RequestMouselookRematch()
  elseif msg == "lock on" then
    self.db.controlMouselookState = true
    self.db.alwaysMouselook = true
    self:ApplyNativeLeftClickSetting()
    self:ApplyMouselookOverrideBindings()
    self:ApplySafeBindings()
    self:RequestMouselookRematch()
    print("|cff33ff99Squanch-On|r mouselook lock helper enabled")
  elseif msg == "lock off" then
    self.db.alwaysMouselook = false
    self.db.controlMouselookState = false
    self:StopLockedMouselook()
    self:ApplyNativeLeftClickSetting()
    self:ApplyMouselookOverrideBindings()
    self:ApplySafeBindings()
    print("|cff33ff99Squanch-On|r mouselook lock helper disabled")
  elseif msg == "panic" then
    self.db.enableSafeHelperBindings = false
    self.db.controlMouselookState = false
    self.db.alwaysMouselook = false
    self:StopLockedMouselook()
    self:ApplyNativeLeftClickSetting()
    self:ApplyMouselookOverrideBindings()
    self:ClearSafeBindings()
    self:HideReticleVisuals()
    print("|cff33ff99Squanch-On|r panic reset complete")
  elseif msg == "always on" then
    self.db.alwaysShowReticle = true
    self:UpdateReticle()
  elseif msg == "always off" then
    self.db.alwaysShowReticle = false
    self:UpdateReticle()
  elseif msg:match("^aim%s+") then
    local x, y = msg:match("^aim%s+(-?%d+)%s+(-?%d+)$")
    if x and y then
      self.db.aimXOffset = tonumber(x)
      self.db.aimYOffset = tonumber(y)
      self:UpdateAimPoint()
      self:UpdateReticle()
      print("|cff33ff99Squanch-On|r aim offset set to " .. x .. ", " .. y)
    else
      print("|cff33ff99/sqms aim <x> <y>|r, for example /sqms aim 0 -80")
    end
  elseif msg:match("^cursor%s+") then
    local y = tonumber(msg:match("^cursor%s+([%d%.]+)$"))
    if y then
      self.db.cursorCenteredYPos = math.max(0, math.min(1, y))
      state.refreshNativeLock = true
      self:RequestMouselookRematch()
      print("|cff33ff99Squanch-On|r cursor centered Y set to " .. self.db.cursorCenteredYPos)
    else
      print("|cff33ff99/sqms cursor <0-1>|r, for example /sqms cursor 0.444")
    end
  else
    self:PrintStatus()
    print("|cff33ff99/sqms|r status, camera [options], mouseover on/off, nameplates, crosshairs, on, off, reticle on/off, bindings on/off, lock on/off, native on/off, return on/off, left on/off, chord on/off, receipts on/off, aim <x> <y>, cursor <0-1>, always on, always off, panic")
  end
end

function addon:OnEvent(event, ...)
  if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
    local blockedAddon, blockedFunction = ...
    if self.db and (blockedAddon == addonName or blockedAddon == "UNKNOWN") then
      self.db.combinedClickBlocked = self.db.combinedClickBlocked or {}
      local blocked = self.db.combinedClickBlocked
      blocked[#blocked + 1] = {event = event, addon = blockedAddon, action = blockedFunction, time = GetTime()}
      while #blocked > 16 do table.remove(blocked, 1) end
    end
  elseif event == "GLOBAL_MOUSE_DOWN" then
    self:BeginNativeLeftClick(...)
  elseif event == "ADDON_LOADED" then
    local loaded = ...
    if loaded ~= addonName then
      if self.db then self:QueueMenuDiscovery() end
      return
    end

    -- Profiles.lua owns the saved-variable shape: the first-run seed from the
    -- shipped layout, the one-time migration, and which profile this character
    -- uses. self.db is that active profile; it calls back for every profile
    -- that becomes active.
    self.db = addon.Profiles:Bootstrap(function(profile)
      copyDefaults(defaults, profile)
      -- Retired cursor-peek / AHK settings have no owner in this native version.
      for _, key in ipairs({"enablePetConfirmBindings", "useNativePeekActionButtons", "syncFreelookCentering"}) do
        profile[key] = nil
      end
    end)
    self.db.loadedVersion = "1.0.0"
    debugReceipts = self.db.debugReceipts == true
    if not self.db.nativeReturnRevision then
      self.db.nativeCombinedClick = false
      self.db.nativeReturnRevision = 1
    end
    for _, key in ipairs({"nativeLeftBindingReceipts", "nativeReleaseReceipts", "nativeBindingCalls",
      "combinedClickReceipts", "cursorRegistryAudit", "nativePadModeProbe", "nativeReturnDiagnostic", "cursorInputAllowance",
      "nativeLeftClickProbe", "hiddenClickProbe", "hiddenCursorEnterResult", "hiddenCursorResult",
      "deltaTrial", "deltaTrialPrevious", "oldGateTrial", "hiddenCursorFoci", "leftClickAudit", "consolidationAudit", "drawCenterReticle"}) do
      self.db[key] = nil
    end
    self:CreateReticle()
    self:InstallMouseHooks()
    self:InstallMovementHooks()
    self:InstallMenuSuspension()

    _G.SLASH_SQMS1 = "/sqms"
    _G.SLASH_SQUANCHER1 = "/squancher"
    _G.SLASH_SQUANCHER2 = "/squanchon"
    -- /squanchon [edit | page | search words]: the unified settings window or the layout editor.
    _G.SlashCmdList.SQUANCHER = function(msg) addon:OptionsCommand(msg) end
    _G.SlashCmdList.SQMS = function(msg) addon:SlashCommand(msg) end
  elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
    self:QueueMenuDiscovery()
    if event == "PLAYER_LOGIN" then
      -- Owner-selected native cursor; keep it out of the game render path.
      setCVar("HardwareCursor", 1)
      self:InitializeHordeReticle(self.db)
      -- A camera failure must not abort native input setup.
      local cameraOK, cameraError = pcall(self.InitializeCamera, self)
      self.db.cameraError = not cameraOK and tostring(cameraError) or nil
      if not cameraOK then print("Squancher: camera setup failed; native controls remain available.") end
      self:UpdateAimPoint()
      self:InitializeTargetCrosshairs(self.db, _G.CrosshairsDB):RegisterSlashCommands()
    end
    self:RestoreNativeLeftDelta(event)
    state.rightDown = false
    state.nativeLeftPassthrough = false
    state.cameraOrSelectOrMoveActive = false
    state.cameraMouseOwned = false
    state.turnOrActionActive = false
    state.turnMouseOwned = false
    self:ClearNativeCentering(true)
    state.refreshNativeLock = true
    self:ApplyNativeLeftClickSetting()
    self:ApplySafeBindings()
    self:ApplyMouselookOverrideBindings()
    self:RequestMouselookRematch()
    self:UpdateReticle()
    self:RecordNativeReceipt(event)
    if event == "PLAYER_LOGIN" then
      print("Squanch-On 1.0 loaded. /squanchon opens settings; /sqedit opens the layout grid.")
    end
  elseif event == "PLAYER_LOGOUT" or event == "PLAYER_LEAVING_WORLD" then
    self:RestoreNativeLeftDelta(event)
    state.nativeLeftPassthrough = false
    state.cameraOrSelectOrMoveActive = false
    state.cameraMouseOwned = false
    state.turnOrActionActive = false
    state.turnMouseOwned = false
    self:ClearNativeCentering(true)
    self:RecordNativeReceipt(event)
  elseif event == "CURRENT_SPELL_CAST_CHANGED" then
    if _G.SpellIsTargeting and _G.SpellIsTargeting() then
      self:RestoreNativeLeftDelta("spell-targeting")
      self:ClearNativeCentering()
    end
    self:RequestMouselookRematch()
  elseif event == "PLAYER_REGEN_ENABLED" then
    if state.pendingBindings then
      self:ApplySafeBindings()
    end
    -- The update loop applies binding writes that combat lockdown deferred.
    state.bindingCombatHold = false
    self:RequestMouselookRematch()
  elseif event == "PLAYER_REGEN_DISABLED" then
    self:RequestMouselookRematch()
  elseif event == "PLAYER_STARTED_MOVING" then
    state.speedMoving = true
    self:RequestMouselookRematch()
  elseif event == "PLAYER_STOPPED_MOVING" then
    state.speedMoving = false
    self:RequestMouselookRematch()
  elseif event == "PLAYER_STARTED_TURNING" then
    self:SetMovementAction("TurnEvent", true)
  elseif event == "PLAYER_STOPPED_TURNING" then
    self:SetMovementAction("TurnEvent", false)
  end
end

frame:SetScript("OnEvent", function(_, event, ...)
  addon:OnEvent(event, ...)
end)

frame:RegisterEvent("GLOBAL_MOUSE_DOWN")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("ADDON_ACTION_BLOCKED")
frame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("PLAYER_LEAVING_WORLD")
frame:RegisterEvent("CURRENT_SPELL_CAST_CHANGED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_STARTED_MOVING")
frame:RegisterEvent("PLAYER_STOPPED_MOVING")
frame:RegisterEvent("PLAYER_STARTED_TURNING")
frame:RegisterEvent("PLAYER_STOPPED_TURNING")
