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
  "VideoOptionsFrame", "AudioOptionsFrame", "SquancherNameplateIndicatorOptions",
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
  for _, method in ipairs({"OpenUnitFrameOptions", "OpenTooltipOptions", "OpenNameplateIndicatorOptions", "OpenCameraOptions"}) do
    if self[method] then hooksecurefunc(self, method, function() self:QueueMenuDiscovery() end) end
  end
  self:QueueMenuDiscovery()
end

function addon:AnyMovementActionActive()
  for _, active in pairs(state.movement) do
    if active then return true end
  end
  return false
end

function addon:RefreshMovementFromSpeed()
  return state.speedMoving
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

function addon:ApplyMouselookOverrideBindings()
  if InCombatLockdown() then state.overrideBindingsPending=true;return end
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
  if self.db and self.db.useMouselookOverrideBindings then
    self:ApplyNativeLeftBinding(true)
    -- Right-click is a precision gate, including the owner's action modifiers.
    for _, prefix in ipairs({"", "SHIFT-", "CTRL-", "ALT-", "CTRL-SHIFT-", "ALT-SHIFT-", "ALT-CTRL-", "ALT-CTRL-SHIFT-"}) do
      local command = self.db.nativeCenteredMouseover and "CLICK SQMSHoldMouseoverButton:RightButton"
        or (prefix == "" and (self.db.mouselookButton2Command or "NULL") or nil)
      safeCall(_G.SetMouselookOverrideBinding, prefix .. "BUTTON2", command)
    end
  else
    self:ApplyNativeLeftBinding(true)
    for _, prefix in ipairs({"", "SHIFT-", "CTRL-", "ALT-", "CTRL-SHIFT-", "ALT-SHIFT-", "ALT-CTRL-", "ALT-CTRL-SHIFT-"}) do
      safeCall(_G.SetMouselookOverrideBinding, prefix .. "BUTTON2", nil)
    end
  end
  self:RefreshNativeBindingMap()
  state.overrideBindingsApplied = self.db and self.db.useMouselookOverrideBindings or false
end

-- Keep the native down/up command paired across the whole physical press.
-- The right-held path retains the configured command and old helper bindings.
function addon:ApplyNativeLeftBinding(deferRefresh)
  if InCombatLockdown() then state.leftBindingUpdatePending=true;return end
  if not self.db or not _G.SetMouselookOverrideBinding then return end
  if self:NativeLeftBindingBusy() then
    state.leftBindingUpdatePending = true
    return
  end
  state.leftBindingUpdatePending = false
  local enabled = self.db.useMouselookOverrideBindings
  local chord = enabled and self.db.nativeCombinedClick
  local leftClick = enabled and self.db.nativeLeftClick and self.db.enabled
    and self.db.controlMouselookState
  local rightHeld = state.rightDown
    or (_G.IsMouseButtonDown and _G.IsMouseButtonDown("RightButton"))
  local base = self.db.mouselookButton1Command or "TARGETSCANENEMY"
  local active = chord and state.rightDown and self.db.enabled
    and self.db.nativeCenteredMouseover and self.db.controlMouselookState and not state.inverted
  local command = active and "INTERACTMOUSEOVER"
    or (leftClick and not rightHeld and "CAMERAORSELECTORMOVE" or base)
  for _, prefix in ipairs({"", "SHIFT-", "CTRL-", "ALT-", "CTRL-SHIFT-", "ALT-SHIFT-", "ALT-CTRL-", "ALT-CTRL-SHIFT-"}) do
    safeCall(_G.SetMouselookOverrideBinding, prefix .. "BUTTON1",
      enabled and ((chord or (leftClick and not rightHeld) or prefix == "") and command or nil) or nil)
  end
  local signature = table.concat({tostring(enabled), tostring(chord), tostring(leftClick), command,
    tostring(self.db.nativeCenteredMouseover), self.db.mouselookButton2Command or "NULL"}, ":")
  if signature ~= state.activeBindingSignature then
    state.activeBindingSignature = signature
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

function addon:RecordNativeReceipt(reason)
  if not self.db then return end
  local receipts = self.db.nativeReceipts
  if type(receipts) ~= "table" then
    receipts = {}
    self.db.nativeReceipts = receipts
  end
  local cvars, bindings = {}, {}
  for _, name in ipairs({ "CursorFreelookCentering", "CursorStickyCentering", "CursorCenteredYPos" }) do
    cvars[name] = safeCall(_G.GetCVar, name)
  end
  for _, key in ipairs({ "UP", "CAPSLOCK", "F6", "F7", "F8", "F9", "F10", "F11", "F20", "F21" }) do
    bindings[key] = safeCall(_G.GetBindingAction, key, true)
  end
  receipts[#receipts + 1] = {
    reason = reason,
    time = safeCall(_G.GetTime),
    mouselooking = isMouselooking() and true or false,
    nativeEnabled = self.db.nativeCenteredMouseover and true or false,
    inverted = state.inverted,
    rightHeld = state.rightDown,
    cvars = cvars,
    bindings = bindings,
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
  self:UpdateReticle()
  self:RecordNativeReceipt(state.rightDown and "mouseover-open" or "mouseover-closed")
end

-- Native cursor-return candidate. The engine can remember a centered unlock
-- position when it enters mouselook with centering enabled. Use the minimum
-- accepted speed only for that transition, then restore the owner's settings.
local cameraReturnNames = { "cameraYawMoveSpeed", "cameraPitchMoveSpeed" }
local pendingCameraReturn

local function cursorReturnSample()
  local x, y = GetCursorPosition()
  local cx, cy = GetCursorCenterPosition()
  return {x = x, y = y, centerX = cx, centerY = cy,
    mouselooking = isMouselooking() and true or false,
    centering = GetCVar("CursorFreelookCentering"),
    cursorVisible = _G.IsCursorVisible and _G.IsCursorVisible() or false,
    facing = _G.GetPlayerFacing and _G.GetPlayerFacing() or nil}
end

function addon:RestoreNativeLeftDelta(reason, force)
  local pending = pendingLeftDelta
  if not pending then return end
  local receipt = pending.receipt
  local current = safeCall(_G.GetCVar, "CursorFreelookStartDelta")
  receipt.deltaRestoreReason = reason
  if force or tonumber(current) == 0 then
    setCVar("CursorFreelookStartDelta", pending.previous)
    current = safeCall(_G.GetCVar, "CursorFreelookStartDelta")
    receipt.deltaRestored = tonumber(current) == tonumber(pending.previous)
    if receipt.deltaRestored then pendingLeftDelta = nil end
  else
    pendingLeftDelta = nil
    receipt.deltaConcurrentChange = true
  end
  receipt.deltaAfterRestore = current
  receipt.deltaRestoreSample = cursorReturnSample()
end

function addon:PrepareNativeLeftDelta(receipt)
  self:RestoreNativeLeftDelta("superseded-left")
  if pendingLeftDelta then
    receipt.deltaStatus = "previous-restore-failed"
    return
  end
  local previous = safeCall(_G.GetCVar, "CursorFreelookStartDelta")
  receipt.deltaPrevious = previous
  if not tonumber(previous) or not _G.C_Timer or not _G.C_Timer.After then
    receipt.deltaStatus = "unavailable"
    return
  end
  local pending = {previous = previous, receipt = receipt}
  pendingLeftDelta = pending
  if not setCVar("CursorFreelookStartDelta", 0)
    or tonumber(safeCall(_G.GetCVar, "CursorFreelookStartDelta")) ~= 0 then
    receipt.deltaStatus = "rejected"
    self:RestoreNativeLeftDelta("delta-rejected", true)
    return
  end
  receipt.deltaStatus = "armed"
  C_Timer.After(0, function()
    if pendingLeftDelta == pending then addon:RestoreNativeLeftDelta("next-update-fallback") end
  end)
end

function addon:RestoreNativeCursorReturn(reason, force)
  local pending = pendingCameraReturn
  if not pending then return end
  pendingCameraReturn = nil
  local receipt = pending.receipt
  receipt.speedRestore = {}
  receipt.speedsRestored = true
  for _, name in ipairs(cameraReturnNames) do
    local current = GetCVar(name)
    if force or tonumber(current) == 0.1 then
      setCVar(name, pending.values[name])
      local actual = GetCVar(name)
      receipt.speedRestore[name] = actual
      if tonumber(actual) ~= tonumber(pending.values[name]) then
        receipt.speedsRestored = false
      end
    else
      -- Another settings owner changed this value during the transition.
      -- Leave its newer value in place instead of restoring stale preferences.
      receipt.speedRestore[name] = current
      receipt.concurrentSpeedChange = true
    end
  end
  receipt.restoreReason = reason
  receipt.restoredAt = GetTime()
  receipt.afterSpeedRestore = cursorReturnSample()
  -- The camera module owns these two speeds outside this transition.
  if addon.Camera then addon.Camera:HoldSpeeds(false) end
end

local function prepareCenteredReturn(self)
  if not self.db.nativeCursorReturn or not _G.C_Timer or not _G.C_Timer.After then return end
  if (_G.SpellIsTargeting and _G.SpellIsTargeting())
    or (_G.GetCurrentKeyBoardFocus and _G.GetCurrentKeyBoardFocus()) then return end
  local receipt = {method = "native-mouse-lock-transition", status = "preparing",
    time = GetTime(), before = cursorReturnSample(),
    combat = InCombatLockdown() and true or false}
  self.db.lastNativeCursorReturn = receipt
  local before = receipt.before
  if not before.mouselooking and math.abs(before.x - before.centerX) <= 0.5
    and math.abs(before.y - before.centerY) <= 0.5 then
    receipt.status = "already-centered"
    return
  end
  local values = {}
  for _, name in ipairs(cameraReturnNames) do
    values[name] = GetCVar(name)
    if not tonumber(values[name]) then
      receipt.status = "unreadable-camera-speed"
      return
    end
  end
  pendingCameraReturn = {values = values, receipt = receipt}
  if addon.Camera then addon.Camera:HoldSpeeds(true) end
  for _, name in ipairs(cameraReturnNames) do
    if not setCVar(name, 0.1) or tonumber(GetCVar(name)) ~= 0.1 then
      receipt.status = "camera-speed-rejected"
      self:RestoreNativeCursorReturn("rejected-before-centering", true)
      return
    end
  end
  local transition = pendingCameraReturn
  C_Timer.After(0, function()
    if pendingCameraReturn == transition then
      addon:RestoreNativeCursorReturn("next-update")
    end
  end)
  -- This is a single synchronous transition. Do not defer centering until
  -- after Start: that changed mouseover in the failed implementation, not the
  -- pointer position that the engine remembers for the next unlock.
  local ok = pcall(function()
    self:ApplyCursorCentering(true)
    if GetCVar("CursorFreelookCentering") ~= "1"
      or GetCVar("CursorStickyCentering") ~= "1" then error("centering-rejected") end
    MouselookStart()
    MouselookStop()
  end)
  self:ApplyCursorCentering(false)
  receipt.afterTransition = cursorReturnSample()
  ok = ok and not receipt.afterTransition.mouselooking
    and receipt.afterTransition.centering == "0"
  receipt.status = ok and "awaiting-unlock-verification" or "transition-failed"
  if not ok then
    state.errors.api = state.errors.api + 1
    self:RestoreNativeCursorReturn("transition-failed")
  end
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
  setCVar("CursorStickyCentering", 1)
  setCVar("CursorCenteredYPos", tonumber(self.db.cursorCenteredYPos) or defaults.cursorCenteredYPos)
  if isMouselooking() then safeCall(_G.MouselookStop) end
  prepareCenteredReturn(self)
  if isMouselooking() or GetCVar("CursorFreelookCentering") ~= "0" then
    -- A setter or Stop may fail without throwing. Clean up once and verify
    -- the ordinary-start preconditions before entering the camera again.
    state.centeringApplied = nil
    self:ApplyCursorCentering(false)
    safeCall(_G.MouselookStop)
    self:RestoreNativeCursorReturn("incomplete-transition", true)
    if self.db.lastNativeCursorReturn then
      self.db.lastNativeCursorReturn.status = "transition-cleanup-required"
    end
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
  local receipt = {time = GetTime(), afterStop = cursorReturnSample()}
  self.db.lastNativeCursorUnlock = receipt
  local generation = state.centeringGeneration
  if _G.C_Timer and _G.C_Timer.After then
    C_Timer.After(0, function()
      if state.centeringGeneration ~= generation or isMouselooking() then
        receipt.interrupted = true
        return
      end
      receipt.nextUpdate = cursorReturnSample()
      local sample = receipt.nextUpdate
      receipt.engineCentered = sample.centering == "0"
        and math.abs(sample.x - sample.centerX) <= 0.5
        and math.abs(sample.y - sample.centerY) <= 0.5
      -- A coordinate match is not camera, combat or cross-platform acceptance.
    end)
  end
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
  if not self:NativeLeftBindingBusy() then
    if state.leftClickSettingPending then self:ApplyNativeLeftClickSetting() end
    if state.overrideBindingsPending then
      self:ApplyMouselookOverrideBindings()
    elseif state.leftBindingUpdatePending then
      self:ApplyNativeLeftBinding()
    elseif state.bindingRefreshPending then
      self:RefreshNativeBindingMap()
    end
  end

  self:RefreshMovementFromSpeed()
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
        pendingLeftDelta.receipt.nativeCameraStart = cursorReturnSample()
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
      if ownedLeft then
        addon:RematchMouselook()
        if addon.db.lastNativeLeftClick then
          addon.db.lastNativeLeftClick.afterNativeRelease = cursorReturnSample()
        end
      end
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
      for _, prefix in ipairs({"", "SHIFT-", "CTRL-", "ALT-", "CTRL-SHIFT-", "ALT-SHIFT-", "ALT-CTRL-", "ALT-CTRL-SHIFT-"}) do
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
  local receipt = {time = GetTime(), pendingRelock = pendingRelock and true or false,
    relockRemaining = state.relockTimer, before = cursorReturnSample()}
  self.db.lastNativeLeftClick = receipt
  state.nativeLeftPassthrough = true
  state.relockTimer = nil
  -- Stop before preparing a return: another Stop afterward would restore the
  -- temporary camera speeds before the original native CameraStart consumes it.
  self:StopNativeMouselook()
  receipt.afterStop = cursorReturnSample()
  receipt.offCenterAfterStop = math.abs(receipt.afterStop.x - receipt.afterStop.centerX) > 0.5
    or math.abs(receipt.afterStop.y - receipt.afterStop.centerY) > 0.5
  receipt.preparationRequested = pendingRelock or receipt.offCenterAfterStop
  if receipt.preparationRequested then
    setCVar("CursorStickyCentering", 1)
    setCVar("CursorCenteredYPos", tonumber(self.db.cursorCenteredYPos) or defaults.cursorCenteredYPos)
    local previous = self.db.lastNativeCursorReturn
    local ok = pcall(prepareCenteredReturn, self)
    local prepared = self.db.lastNativeCursorReturn
    receipt.preparationStatus = prepared ~= previous and prepared.status or "not-started"
    local preparedOK = receipt.preparationStatus == "already-centered"
      or receipt.preparationStatus == "awaiting-unlock-verification"
    if not ok or not preparedOK or isMouselooking() or GetCVar("CursorFreelookCentering") ~= "0" then
      -- Failed preparation must still leave the original click its free path.
      state.centeringApplied = nil
      self:ApplyCursorCentering(false)
      safeCall(_G.MouselookStop)
      self:RestoreNativeCursorReturn("left-prepare-failed")
      receipt.status = "fallback-prepare-failed"
      if not ok then state.errors.api = state.errors.api + 1 end
    else
      receipt.status = "left-return-prepared"
    end
  else
    receipt.status = "released-owned-lock"
  end
  -- Remain unlocked for this physical press; preparation owns its existing
  -- next-update speed restore. No new click or gameplay action is dispatched.
  receipt.after = cursorReturnSample()
  receipt.centeredAfter = math.abs(receipt.after.x - receipt.after.centerX) <= 0.5
    and math.abs(receipt.after.y - receipt.after.centerY) <= 0.5
  if receipt.preparationRequested and not receipt.centeredAfter and receipt.status == "left-return-prepared" then
    receipt.status = "fallback-return-incomplete"
  end
  -- Zero only the original native down threshold, then restore in its posthook.
  self:PrepareNativeLeftDelta(receipt)
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
  if command == "tooltip" then self:OpenTooltipOptions(); return end
  if command == "settings" and self.OptionsCommand then self:OptionsCommand(""); return end
  if command == "unitframes" or command == "settings" then self:OpenUnitFrameOptions(); return end
  if command == "nameplates" then self:OpenNameplateIndicatorOptions(); return end
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
    print("|cff33ff99/sqms|r status, camera [options], mouseover on/off, nameplates, crosshairs, on, off, reticle on/off, bindings on/off, lock on/off, native on/off, return on/off, left on/off, chord on/off, aim <x> <y>, cursor <0-1>, always on, always off, panic")
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
    -- /squanchon [page | search words]: the unified settings window. Pages that
    -- have not moved into it yet keep their own windows.
    _G.SlashCmdList.SQUANCHER = function(msg)
      local word = string.lower(msg or ""):match("^%s*(.-)%s*$")
      local pages = addon.Options and addon.Options.categories or {}
      if word == "edit" or word == "layout" then addon.LayoutEditor:Toggle()
      elseif word == "tooltip" and not pages.tooltip then addon:OpenTooltipOptions()
      elseif word == "camera" and not pages.camera then addon:OpenCameraOptions()
      elseif word == "unitframes" and not pages.unitframes then addon:OpenUnitFrameOptions()
      elseif word == "nameplates" and not pages.nameplates then addon:OpenNameplateIndicatorOptions()
      elseif addon.OptionsCommand then addon:OptionsCommand(msg)
      else addon:OpenUnitFrameOptions() end
    end
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
  elseif event == "PLAYER_TARGET_CHANGED" or event == "UPDATE_MOUSEOVER_UNIT" then
    self:UpdateReticle()
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
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
