-- SPDX-License-Identifier: MIT
-- Squancher's fixed layout, using Forever's original action buttons/controllers.
-- Do not load alongside another action-bar replacement.
local _, ns = ...
local Bars = { buttons = {}, frames = {}, pending = false }
ns.NativeActionBars = Bars

local layout = {
    { name = "MainActionBar", point = "BOTTOMRIGHT", x = -10.19927978515625, y = 115.1999969482422, count = 9, scale = 0.5, cellSize = 49, spacing = 0, pad = 0, fade = 1 },
    { name = "MultiBarRight", point = "BOTTOMLEFT", x = 10.199462890625, y = 115.1999969482422, count = 9, scale = 0.5, cellSize = 49, spacing = 0, pad = 0, fade = 1 },
    { name = "MultiBarLeft", point = "TOPRIGHT", relative = "MultiBarRight", relativePoint = "BOTTOMRIGHT", count = 9, scale = 0.5, cellSize = 49, spacing = 0, pad = 0, fade = 1 },
    { name = "MultiBarBottomRight", point = "TOPLEFT", relative = "MainActionBar", relativePoint = "BOTTOMLEFT", count = 9, scale = 0.5, cellSize = 49, spacing = 0, pad = 0, fade = 1 },
    { name = "PetActionBar", point = "BOTTOM", x = 8.699722290039062, y = 177, count = 10, scale = 0.5, spacing = 1, pad = 0, fade = 0.5, pet = true },
    { name = "StanceBar", point = "CENTER", relativePoint = "CENTER", count = 10, scale = 1, spacing = 2, pad = 0, stance = true },
    { name = "PossessActionBar", point = "CENTER", relativePoint = "CENTER", x = 244, count = 2, scale = 1, spacing = 4, pad = 2, stance = true },
}

local function point(frame, anchor, relative, relativeAnchor, x, y)
    local clear = frame.ClearAllPointsBase or frame.ClearAllPoints
    local setPoint = frame.SetPointBase or frame.SetPoint
    clear(frame)
    setPoint(frame, anchor, relative, relativeAnchor, x or 0, y or 0)
end

local function scale(frame, value)
    (frame.SetScaleBase or frame.SetScale)(frame, value)
end

-- The native right-bar writer always restores local scale 1, even for custom
-- positions. Carry only those bars' scale on a parent it does not manage.
local scaleHolders = {}
local function scaleHolder(frame)
    if frame ~= MultiBarRight and frame ~= MultiBarLeft then return end
    local receipt = ns.db and ns.db.nativeBarLayoutMigration
    if not receipt or receipt.revision ~= 1 or not frame.systemInfo or frame.systemInfo.isInDefaultPosition then return end
    local holder = scaleHolders[frame]
    if not holder then
        holder = CreateFrame("Frame", nil, UIParent)
        holder:SetSize(1, 1); holder:SetPoint("CENTER", UIParent, "CENTER")
        holder:EnableMouse(false)
        scaleHolders[frame] = holder
    end
    return holder
end

local function skin(button, kind, owner)
    if ns.DarkSkin and ns.DarkSkin.ActionButton then ns.DarkSkin:ActionButton(button, kind, owner) end
end

-- Transitions run only while a fade is actually in progress. No idle ticker.
local fades = {}
local animator = CreateFrame("Frame")
animator:Hide()
animator:SetScript("OnUpdate", function(self, elapsed)
    local active = false
    for frame, fade in pairs(fades) do
        fade.elapsed = math.min(fade.elapsed + elapsed, fade.duration)
        frame:SetAlpha(fade.from + (fade.target - fade.from) * fade.elapsed / fade.duration)
        if fade.elapsed >= fade.duration then fades[frame] = nil else active = true end
    end
    if not active then self:Hide() end
end)

function Bars:RefreshOpacity(immediate)
    local full = IsModifierKeyDown()
    for frame, config in pairs(self.frames) do
        local hovered = frame:IsMouseOver()
        local target = (full or hovered) and 1 or config.fade
        local running = fades[frame]
        if not running or running.target ~= target then
            if immediate then
                fades[frame] = nil
                frame:SetAlpha(target)
            elseif math.abs(frame:GetAlpha() - target) > 0.001 then
                fades[frame] = { from = frame:GetAlpha(), target = target, elapsed = 0, duration = target == 1 and 0.2 or 0.1 }
                animator:Show()
            end
        end
    end
end

local function observeHover(frame)
    if frame.SquancherBarHover then return end
    frame.SquancherBarHover = true
    frame:HookScript("OnEnter", function() Bars:RefreshOpacity() end)
    frame:HookScript("OnLeave", function() C_Timer.After(0, function() Bars:RefreshOpacity() end) end)
end

-- All 12 native buttons remain in actionButtons with their original IDs/parents.
-- Slots 10-12 are transparent/noninteractive; native visibility and count fields
-- remain untouched, so later protected native show/hide branches keep their owner.
local barTargets = { MainActionBar = "actions_right", MultiBarBottomRight = "actions_right",
    MultiBarRight = "actions_left", MultiBarLeft = "actions_left", PetActionBar = "pet_bar",
    StanceBar = "stance_bar", PossessActionBar = "possess_bar" }
function Bars:LayoutActionBar(frame, config)
    if InCombatLockdown() then self.pending = true; return end
    if self.layingOut then return end
    self.layingOut = true
    -- This bar has a custom owner. Native ManageFramePositions otherwise resets
    -- its scale to 1 outside the edit-mode writers when panels/targets change.
    if frame == MainActionBar then
        -- SetUserPlaced requires a movable frame. This does not add drag handlers.
        frame:SetMovable(true)
        frame:SetUserPlaced(true)
    end
    local count = config.stance and math.min(frame.numButtonsShowable or config.count, config.count) or config.count
    frame:SetFrameStrata("MEDIUM")
    local holder = scaleHolder(frame)
    if holder then
        if frame.ludius_parentBeforeFadeOut then self.pending=true; self.layingOut=false; return end
        if frame:GetParent() ~= holder then frame:SetParent(holder) end
        holder:SetScale(config.scale)
        scale(frame, 1)
    else
        if scaleHolders[frame] and frame:GetParent() == scaleHolders[frame] then frame:SetParent(UIParent) end
        scale(frame, config.scale)
    end
    point(frame, config.point, _G[config.relative] or UIParent, config.relativePoint or "BOTTOM", config.x, config.y)
    local pad, width, height = config.pad, 0, 0
    local rect = ns.LayoutTargets and barTargets[config.name] and ns.LayoutEditor:Read(barTargets[config.name])
    for index, button in ipairs(frame.actionButtons) do
        local container = button.container
        -- Native edit-mode icon size scales the container independently of the
        -- bar. Dominos reparented the button directly, so preserve that one-scale
        -- geometry here while retaining the native container/action owner.
        container:SetScale(1)
        button:SetScale(1)
        if index <= count then
            if config.cellSize then button:SetSize(config.cellSize, config.cellSize) end
            local bw, bh = button:GetSize()
            local left, right, top, bottom = button:GetHitRectInsets()
            local visibleWidth, visibleHeight = bw - left - right, bh - top - bottom
            point(container, "TOPLEFT", frame, "TOPLEFT", pad + width - left, -pad + top)
            point(button, "CENTER", container, "CENTER")
            container:SetSize(bw, bh)
            width = width + visibleWidth + config.spacing
            height = math.max(height, visibleHeight)
            button:SetAlpha(1)
            container:SetAlpha(1)
            button:EnableMouse(true)
            if button.Name then button.Name:SetAlpha(0) end
            -- With a saved rectangle the bar's scale is still to change: the
            -- cells are skinned once, after it applies (below).
            if not rect then skin(button, config.pet and "pet" or nil, frame) end
            observeHover(button)
        else
            -- Keep native lifetime/action registration and key dispatch intact.
            button:SetAlpha(0)
            container:SetAlpha(0)
            button:EnableMouse(false)
            point(container, "TOPLEFT", frame, "TOPLEFT", pad, -pad)
        end
    end
    frame:SetSize(math.max(1, width - config.spacing + 2 * pad), math.max(1, height + 2 * pad))
    if rect then
        ns.LayoutEditor:ScaleToWidth(frame, rect.w)
        if holder then
            -- Preserve the editor's effective scale while returning the
            -- native bar to the local scale its secure manager will use.
            holder:SetScale(holder:GetScale() * frame:GetScale())
            scale(frame, 1)
        end
        if not config.relative then ns.LayoutEditor:Place(frame, rect) end
        -- Refit physical-pixel artwork after the saved bar scale applies.
        for index, button in ipairs(frame.actionButtons) do
            if index <= count then skin(button, config.pet and "pet" or "action", frame) end
        end
    end
    for _, key in ipairs({ "EndCaps", "BorderArt", "Background", "ActionBarPageNumber" }) do
        if frame[key] then frame[key]:SetAlpha(0) end
    end
    if frame.HorizontalDividersPool then frame.HorizontalDividersPool:ReleaseAll() end
    if frame.VerticalDividersPool then frame.VerticalDividersPool:ReleaseAll() end
    self.layingOut = false
end

function Bars:GroupBorders()
    if self.groupsReady or InCombatLockdown() then return end
    self.groupsReady = true
    self.borderGroups = {}
    for _, pair in ipairs({{MainActionBar, MultiBarBottomRight}, {MultiBarRight, MultiBarLeft}}) do
        local top, bottom = pair[1], pair[2]
        local holder = CreateFrame("Frame", nil, UIParent)
        holder:EnableMouse(false); holder.ignoreInLayout = true
        holder:SetFrameStrata("MEDIUM"); holder:SetFrameLevel(1)
        holder:SetPoint("TOPLEFT", top, "TOPLEFT")
        holder:SetPoint("BOTTOMRIGHT", bottom, "BOTTOMRIGHT")
        holder:SetAlpha(top:GetAlpha())
        -- Each cell carries the exact equipment-slot rim. Keep this transparent
        -- group holder for the layout editor, without a second outside bevel.
        hooksecurefunc(top, "SetAlpha", function(_, alpha) holder:SetAlpha(alpha) end)
        local function visibility() holder:SetShown(top:IsVisible() and bottom:IsVisible()) end
        top:HookScript("OnShow", visibility); top:HookScript("OnHide", visibility)
        bottom:HookScript("OnShow", visibility); bottom:HookScript("OnHide", visibility)
        visibility()
        holder.layoutBoundsBars = { top, bottom }
        self.borderGroups[#self.borderGroups + 1] = holder
    end
end

local function shouldShowMicro(info)
    local button = info.button
    if not button or button == GuildMicroButton then return false end
    if info.gameRule and C_GameRules.IsGameRuleActive(info.gameRule) then return false end
    if info.callback and info.callback() then return false end
    if button == StoreMicroButton then return C_StorePublic.IsEnabled() end
    if button == HelpMicroButton then return not C_StorePublic.IsEnabled() end
    return true
end

-- Micro buttons, their menu/container and Friends are plain native frames, so
-- their placement also holds in combat. Defer only when a secure frame depends
-- on one of them (explicit/implicit protection or a secure anchor chain).
local function combatLocked(...)
    if not InCombatLockdown() then return false end
    for index = 1, select("#", ...) do
        local frame = select(index, ...)
        if frame and (frame:IsProtected() or frame:IsAnchoringRestricted()) then return true end
    end
    return false
end

-- The micro menu lives in the chat header strip, flush against the panel's
-- inner right rim with Friends as its last cell. Native buttons keep their
-- scripts; only parent, scale and anchors change.
function Bars:LayoutMicroMenu()
    if combatLocked(MicroMenuContainer, MicroMenu, QuickJoinToastButton) then self.pending = true; return end
    local skin = ns.DarkSkin
    local panel, strip = skin and skin.chatPanel, skin and skin.chatIconStrip
    if self.menuLayout or not panel or not strip or not strip:GetRight() or not MicroMenu then return end
    -- DynamicCam temporarily owns parentage while hiding the UI.
    if MicroMenuContainer.ludius_parentBeforeFadeOut then self.pending = true; return end
    self.menuLayout = true
    -- Vehicle and pet-battle bars borrow the menu (OverrideMicroMenuPosition);
    -- it stays in the chat header, inside its native container.
    if MicroMenu:GetParent() ~= MicroMenuContainer then MicroMenu:SetParent(MicroMenuContainer) end
    local friends = QuickJoinToastButton
    if friends and not (friends:GetParent() == panel and friends:IsShown()) then friends = nil end
    if MicroMenuContainer:GetParent() ~= panel then MicroMenuContainer:SetParent(panel) end
    scale(MicroMenuContainer, 1)
    local strata, level = "LOW", panel:GetFrameLevel() + 8
    MicroMenuContainer:SetFrameStrata(strata); MicroMenuContainer:SetFrameLevel(level)
    MicroMenu:SetFrameStrata(strata); MicroMenu:SetFrameLevel(level + 1)
    local buttons, rawWidth, rawHeight = {}, 0, 0
    for _, info in ipairs(MicroMenu:GenerateButtonInfos()) do
        local button = info.button
        if button then
            if shouldShowMicro(info) then
                buttons[#buttons + 1] = button
                button:Show()
                button:SetFrameStrata(strata); button:SetFrameLevel(level + 2)
                rawWidth = rawWidth + button:GetWidth()
                rawHeight = math.max(rawHeight, button:GetHeight())
                observeHover(button)
            else
                button:Hide()
            end
        end
    end
    rawWidth, rawHeight = math.max(1, rawWidth), math.max(1, rawHeight)
    -- Friends is one more cell of the same raw size as a micro button.
    local cellWidth = #buttons > 0 and rawWidth / #buttons or rawHeight * 0.8
    local totalWidth = rawWidth + (friends and cellWidth or 0)
    -- Room between the left group (chat tabs, then the voice controls) and the
    -- panel's inner right rim, in panel units. Cells fill the header height and
    -- shrink before tabs yield; half height is the floor that keeps them usable.
    local unit = panel:GetEffectiveScale()
    local leftRight = panel:GetLeft() * unit
    local function reach(frame)
        if frame and frame:IsShown() and frame:GetRight() then
            leftRight = math.max(leftRight, frame:GetRight() * frame:GetEffectiveScale())
        end
    end
    for _, chat in ipairs(GeneralDockManager and GeneralDockManager.DOCKED_CHAT_FRAMES or {}) do
        reach(_G[chat:GetName() .. "Tab"])
    end
    for _, control in ipairs({ ChatFrameChannelButton, TextToSpeechButton }) do
        if control and control:GetParent() == panel then reach(control) end
    end
    local header = strip:GetHeight()
    if not header or header < 1 then header = 20 end
    local room = (strip:GetRight() * strip:GetEffectiveScale() - leftRight) / unit - 4
    local useScale = math.max(header * 0.5 / rawHeight, math.min(header / rawHeight, room / totalWidth))
    scale(MicroMenu, useScale)
    local x = 0
    for _, button in ipairs(buttons) do
        point(button, "TOPLEFT", MicroMenu, "TOPLEFT", x, 0)
        x = x + button:GetWidth()
    end
    MicroMenu:SetSize(rawWidth, rawHeight)
    MicroMenuContainer:SetSize(rawWidth * useScale, rawHeight * useScale)
    point(MicroMenu, "CENTER", MicroMenuContainer, "CENTER")
    -- Cell widths in panel units, from the right rim leftward. The strip is the
    -- row's only anchor: the chat alert container re-anchors Friends whenever a
    -- toast shows or hides, and must not carry the micro buttons with it.
    local widths = {}
    if friends then
        skin:PinChatFriends(cellWidth, rawHeight, useScale)
        widths[1] = cellWidth * useScale
    end
    point(MicroMenuContainer, "RIGHT", strip, "RIGHT", -(widths[1] or 0), 0)
    for index = #buttons, 1, -1 do widths[#widths + 1] = buttons[index]:GetWidth() * useScale end
    skin:FitChatIconStrip(widths)
    for _, key in ipairs({"BorderArt", "BackgroundArt"}) do if MicroMenu[key] then MicroMenu[key]:SetAlpha(0) end end
    self.menuLayout = false
    if skin.BarControls then skin:BarControls() end
end

function Bars:QueueMicroMenu()
    if self.menuQueued then return end
    self.menuQueued = true
    C_Timer.After(0, function() self.menuQueued = nil; self:LayoutMicroMenu() end)
end

function Bars:LayoutBags()
    if InCombatLockdown() then self.pending = true; return end
    if self.bagLayout or not BagsBar then return end
    self.bagLayout = true
    local buttons = {}
    if CharacterReagentBag0Slot then buttons[#buttons + 1] = CharacterReagentBag0Slot end
    for slot = NUM_BAG_SLOTS - 1, 0, -1 do
        local button = _G["CharacterBag" .. slot .. "Slot"]
        if button then buttons[#buttons + 1] = button end
    end
    buttons[#buttons + 1] = MainMenuBarBackpackButton
    ns.MinimapPanel:LayoutBags(buttons)
    for _, button in ipairs(buttons) do
        button:Show()
        skin(button, "bag", BagsBar)
        observeHover(button)
    end
    if BagBarExpandToggle then BagBarExpandToggle:Hide() end
    if KeyRingButton then KeyRingButton:Hide() end
    self.bagLayout = false
    if ns.DarkSkin and ns.DarkSkin.BarControls then ns.DarkSkin:BarControls() end
end

function Bars:LayoutCastAndExtras()
    if InCombatLockdown() then self.pending = true; return end
    local cast = PlayerCastingBarFrame or CastingBarFrame
    if cast then
        scale(cast, 0.75)
        point(cast, "BOTTOM", UIParent, "BOTTOM", 0, 147.1999816894531)
        cast:SetSize(300, 20)
    end
    local leave = MainMenuBarVehicleLeaveButton
    if leave then
        leave:SetParent(UIParent)
        scale(leave, 1)
        point(leave, "BOTTOMRIGHT", UIParent, "BOTTOM", -441.5999526977539, 88.00006866455078)
    end
    local extra = ExtraAbilityContainer or ExtraActionBarFrame
    if extra then point(extra, "TOP", UIParent, "CENTER", -3.1998291015625, -74.39997863769531) end
    if ns.LayoutTargets then
        ns.LayoutTargets:ApplyScale("cast_bar", cast)
        ns.LayoutTargets:ApplyScale("vehicle_leave", leave)
        ns.LayoutTargets:ApplyScale("extra_action", extra)
    end
end

function Bars:Apply()
    if InCombatLockdown() then self.pending = true; return end
    for _, config in ipairs(layout) do
        local frame = _G[config.name]
        if frame and frame.actionButtons then self:LayoutActionBar(frame, config) end
    end
    self:LayoutMicroMenu()
    self:LayoutBags()
    self:GroupBorders()
    self:LayoutCastAndExtras()
    -- The imported XP bar was 1x1 at scale0.5, with no labels. Keep it invisible.
    if StatusTrackingBarManager then StatusTrackingBarManager:SetAlpha(0); StatusTrackingBarManager:EnableMouse(false) end
    self.pending = false
    self:RefreshOpacity(true)
end

-- Persist a copied DTO only. Never call manager Lua movement/save helpers:
-- their writes would taint the metadata read by secure combat positioning.
local nativeLayoutRevision = 1
local ownedBarNames = { "MainActionBar", "MultiBarRight", "MultiBarLeft", "MultiBarBottomRight" }
function Bars:MigrateNativeLayout()
    if InCombatLockdown() or self.nativeLayoutSaving or not ns.db then return end
    local migration = ns.db.nativeBarLayoutMigration
    if migration and migration.revision == nativeLayoutRevision then return end
    if not C_EditMode or not C_EditMode.GetLayouts or not C_EditMode.SaveLayouts then return end
    local original = C_EditMode.GetLayouts()
    local presetCount = Enum.EditModePresetLayoutsMeta.NumValues
    local managerLayouts = EditModeManagerFrame and EditModeManagerFrame.layoutInfo and EditModeManagerFrame.layoutInfo.layouts
    if not original or not original.layouts or not original.activeLayout or not managerLayouts then return end
    if migration and migration.submitted then
        local saved = original.layouts[migration.targetIndex - presetCount]
        local matches = original.activeLayout == migration.targetIndex and saved and saved.systems
        for _, expected in ipairs(migration.systems) do
            local found
            for _, info in ipairs(saved and saved.systems or {}) do
                if info.system == expected.system and info.systemIndex == expected.systemIndex then
                    local a, b = info.anchorInfo, expected.anchorInfo
                    found = not info.isInDefaultPosition and a and a.point == b.point and a.relativeTo == b.relativeTo
                        and a.relativePoint == b.relativePoint and math.abs(a.offsetX-b.offsetX)<0.1 and math.abs(a.offsetY-b.offsetY)<0.1
                    break
                end
            end
            matches = matches and found
        end
        -- The live native reload must also own the false flags before holders activate.
        for _, name in ipairs(ownedBarNames) do
            local frame = _G[name]
            matches = matches and frame and frame.systemInfo and not frame.systemInfo.isInDefaultPosition
                and issecurevariable(frame.systemInfo, "isInDefaultPosition")
        end
        if matches then
            migration.revision=nativeLayoutRevision; migration.status="verified"; migration.error=nil
            return
        end
        if migration.schema == 2 then
            migration.status="not_applied"
            migration.error="Native layout readback did not match; scale holders remain disabled."
            return
        end
        -- One bounded schema amendment for the old compact-only submission.
        -- Reuse its exact target/anchors/backup, never append a duplicate layout.
        if not saved then migration.error="Original migration target is missing."; return end
    elseif migration and migration.error then return end
    local dto = CopyTable(original)
    local index = migration and migration.targetIndex - presetCount or dto.activeLayout - presetCount
    local selected = dto.layouts[index]
    local added = not migration and index <= 0
    if added then
        local preset = managerLayouts[dto.activeLayout]
        if not preset or preset.layoutType ~= Enum.EditModeLayoutType.Preset then return end
        selected = CopyTable(preset)
        local count = 0
        for _, info in ipairs(dto.layouts) do if info.layoutType == Enum.EditModeLayoutType.Character then count=count+1 end end
        if count >= Constants.EditModeConsts.EditModeMaxLayoutsPerType then return end
        selected.layoutType=Enum.EditModeLayoutType.Character; selected.layoutName="Squancher Native Bars"
        dto.layouts[#dto.layouts+1]=selected; index=#dto.layouts
    end
    if not selected or not selected.systems then return end
    local expected = migration and migration.systems or {}
    for i, name in ipairs(ownedBarNames) do
        local frame = _G[name]
        if not frame or frame.ludius_parentBeforeFadeOut then return end
        local system
        for _, info in ipairs(selected.systems) do
            if info.system == frame.system and info.systemIndex == frame.systemIndex then system=info; break end
        end
        if not system then return end
        if not migration then
            local left, bottom, width, height = frame:GetRect()
            if not left or not bottom or not width or not height then return end
            -- Side bars will use holder scale + native local 1 after verification.
            local localScale = (frame == MultiBarRight or frame == MultiBarLeft) and 1 or frame:GetScale()
            expected[i] = {system=system.system,systemIndex=system.systemIndex,anchorInfo={point="TOPLEFT",
                relativeTo="UIParent",relativePoint="BOTTOMLEFT",offsetX=left*localScale,offsetY=(bottom+height)*localScale}}
        end
        system.anchorInfo=CopyTable(expected[i].anchorInfo)
        system.anchorInfo2=nil; system.isInDefaultPosition=false
    end
    -- Ordinary native SaveLayouts passes preset slots followed by saved slots.
    -- Match that full indexed payload, preserving each preset without editing it.
    local savedLayouts=dto.layouts; dto.layouts={}
    for i=1,presetCount do
        local preset=managerLayouts[i]
        if not preset or preset.layoutType~=Enum.EditModeLayoutType.Preset then return end
        dto.layouts[i]=CopyTable(preset)
    end
    for _, saved in ipairs(savedLayouts) do dto.layouts[#dto.layouts+1]=saved end
    local targetIndex=index+presetCount
    migration=migration or {backup=CopyTable(original),targetIndex=targetIndex,systems=expected}
    migration.schema=2; migration.submitted=true; migration.status="submitted"; migration.error=nil
    ns.db.nativeBarLayoutMigration=migration
    self.nativeLayoutSaving=true
    local ok,err=pcall(function()
        C_EditMode.SaveLayouts(dto)
        if added then
            C_EditMode.OnLayoutAdded(targetIndex,true,false)
        else
            -- Saving alone need not reload an already active layout. Use native
            -- selection events to reload it, without invoking manager Lua methods.
            if original.activeLayout==targetIndex then C_EditMode.SetActiveLayout(1) end
            C_EditMode.SetActiveLayout(targetIndex)
        end
    end)
    self.nativeLayoutSaving=nil
    if not ok then
        migration.error=tostring(err); migration.status="failed"
        pcall(C_EditMode.SetActiveLayout,original.activeLayout)
    end
end

function Bars:Initialize()
    if self.ready then return end
    -- Initialization must be atomic with respect to combat: no hooks, settings,
    -- frame references or protected attributes are installed while combat-locked.
    if InCombatLockdown() then self.initializationPending = true; return end
    self.initializationPending = nil
    -- Fail closed if a bar replacement remains enabled; never compete for buttons.
    if Dominos or ElvUI and ElvUI[1] and ElvUI[1].private and ElvUI[1].private.actionbar and ElvUI[1].private.actionbar.enable then
        self.blocked = "Disable Dominos/ElvUI action bars before loading Squancher native bars."
        return
    end
    if not MainActionBar or not MainActionBar.actionButtons then self.blocked = "Forever native action bars not loaded"; return end
    for _, config in ipairs(layout) do
        local frame = _G[config.name]
        if frame and frame.actionButtons then
            if config.fade then self.frames[frame] = config; observeHover(frame) end
            hooksecurefunc(frame, "UpdateGridLayout", function() self:LayoutActionBar(frame, config) end)
            hooksecurefunc(frame, "Layout", function() self:LayoutActionBar(frame, config) end)
            hooksecurefunc(frame, "UpdateShownButtons", function() self:LayoutActionBar(frame, config) end)
            if frame.ApplySystemAnchor then hooksecurefunc(frame, "ApplySystemAnchor", function() self:LayoutActionBar(frame, config) end) end
        end
    end
    -- Native manager layout is a later writer than ApplySystemAnchor: it can
    -- restore local scale1 and default bottom/right anchors after our first apply.
    -- Post-hook that event boundary, without changing its native state tables.
    if EditModeManagerFrame then
        -- These are the actual writers. UpdateActionBarPositions, manager events
        -- and OverrideActionBar also call them without UpdateActionBarLayout.
        for _, method in ipairs({ "UpdateBottomActionBarPositions", "UpdateRightActionBarPositions" }) do
            if EditModeManagerFrame[method] then
                hooksecurefunc(EditModeManagerFrame, method, function()
                    if self.layingOut then return end
                    for _, config in ipairs(layout) do
                        local frame = _G[config.name]
                        if frame and frame.actionButtons then self:LayoutActionBar(frame, config) end
                    end
                end)
            end
        end
    end
    if BagsBar then
        self.frames[BagsBar] = { fade = 0.5 }
        hooksecurefunc(BagsBar, "Layout", function() self:LayoutBags() end)
        if BagsBar.ApplySystemAnchor then
            hooksecurefunc(BagsBar,"ApplySystemAnchor",function() self:LayoutBags() end)
        end
        -- Native OnLoad captures the original Layout callback before our
        -- method hook. Its late SetSize includes the hidden keyring and can
        -- overwrite the fitted row. Reflow once after that layout completes.
        BagsBar:HookScript("OnSizeChanged",function()
            if self.bagLayout or self.bagReflowQueued then return end
            self.bagReflowQueued=true
            C_Timer.After(0,function()
                self.bagReflowQueued=nil
                self:LayoutBags()
            end)
        end)
        observeHover(BagsBar)
    end
    if MicroMenuContainer and MicroMenu then
        self.frames[MicroMenuContainer] = { fade = 0.9 }
        hooksecurefunc(MicroMenu, "Layout", function() self:LayoutMicroMenu() end)
        hooksecurefunc(MicroMenu, "ResetMicroMenuPosition", function() self:LayoutMicroMenu() end)
        hooksecurefunc(MicroMenu, "OverrideMicroMenuPosition", function() self:LayoutMicroMenu() end)
        hooksecurefunc(MicroMenuContainer, "Layout", function() self:LayoutMicroMenu() end)
        if MicroMenuContainer.ApplySystemAnchor then hooksecurefunc(MicroMenuContainer, "ApplySystemAnchor", function() self:LayoutMicroMenu() end) end
        if MicroMenu.UpdateScale then hooksecurefunc(MicroMenu, "UpdateScale", function() self:LayoutMicroMenu() end) end
        observeHover(MicroMenuContainer)
        -- Chat geometry and tab changes move the room this row may use.
        if ns.DarkSkin then
            hooksecurefunc(ns.DarkSkin, "LayoutChat", function() self:QueueMicroMenu() end)
            hooksecurefunc(ns.DarkSkin, "AlignChatTabs", function() self:QueueMicroMenu() end)
        end
    end
    for _, frame in ipairs({ PlayerCastingBarFrame or CastingBarFrame, MainMenuBarVehicleLeaveButton, ExtraAbilityContainer or ExtraActionBarFrame }) do
        if frame and frame.ApplySystemAnchor then hooksecurefunc(frame, "ApplySystemAnchor", function() self:LayoutCastAndExtras() end) end
    end
    -- Keep the saved native bar-visibility choices. Settings.SetValue dispatches
    -- ActionBarController's MultiActionBar_Update callback in addon context,
    -- tainting native snap metadata later read by protected combat positioning.
    -- Native initialization/events apply those choices without an addon callback.
    self:Apply()
    -- Use a restricted controller for permanent show-empty and right-click
    -- attributes. Do not write native Lua visibility/count/grid fields: those
    -- values are later read by protected Blizzard SetShown branches in combat.
    self.secure = CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate")
    for _, config in ipairs(layout) do
        local frame = _G[config.name]
        if frame and frame.actionButtons and not config.stance and not config.pet then
            for _, button in ipairs(frame.actionButtons) do
                self.secure:SetFrameRef("button", button)
                self.secure:Execute([[
                    local target = self:GetFrameRef("button")
                    local grid = target:GetAttribute("showgrid") or 0
                    if grid % 64 < 32 then grid = grid + 32 end
                    target:SetAttribute("showgrid", grid)
                    target:SetAttribute("*unit2", "player")
                ]])
            end
        end
    end
    -- Native events and the secure attribute handlers own visibility updates.
    -- Calling UpdateShownButtons/MultiActionBar_Update here taints their cached
    -- native visibility tables before later protected combat/target updates.
    self:Apply()
    self.ready = true
    self:MigrateNativeLayout()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("MODIFIER_STATE_CHANGED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
events:SetScript("OnEvent", function(_, event)
    if event == "EDIT_MODE_LAYOUTS_UPDATED" then
        C_Timer.After(0, function()
            if Bars.ready then
                Bars:MigrateNativeLayout()
                if InCombatLockdown() then Bars.pending=true else Bars:Apply() end
            end
        end)
    elseif event == "PLAYER_LOGIN" then C_Timer.After(0, function() Bars:Initialize() end)
    elseif event == "PLAYER_REGEN_ENABLED" and Bars.initializationPending then Bars:Initialize()
    elseif Bars.ready then
        if event == "PLAYER_REGEN_ENABLED" and Bars.pending or event == "PLAYER_ENTERING_WORLD" then Bars:Apply() end
        if event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" then Bars:MigrateNativeLayout() end
        Bars:RefreshOpacity()
    end
end)
