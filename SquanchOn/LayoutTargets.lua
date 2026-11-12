-- SPDX-License-Identifier: MIT
-- Saved geometry is consumed by the original layout owners. These registrations
-- provide edit handles without replacing native scripts or protected lifetimes.
local _, ns = ...
local Targets = { defaults = {}, registered = {}, applying = {} }
ns.LayoutTargets = Targets

function Targets:Capture(id, frame)
    if self.defaults[id] or not frame then return end
    local saved = { scale = frame:GetScale(), points = {} }
    for i = 1, frame:GetNumPoints() do saved.points[i] = { frame:GetPoint(i) } end
    self.defaults[id] = saved
end

function Targets:RestoreDefault(id, frame)
    local saved = self.defaults[id]
    if not saved or not frame or InCombatLockdown() then return end
    local setScale = frame.SetScaleBase or frame.SetScale
    local clear = frame.ClearAllPointsBase or frame.ClearAllPoints
    local setPoint = frame.SetPointBase or frame.SetPoint
    setScale(frame, saved.scale)
    clear(frame)
    for _, p in ipairs(saved.points) do setPoint(frame, unpack(p)) end
end

function Targets:ApplyScale(id, frame)
    if not frame or InCombatLockdown() or self.applying[id] then return end
    self:Capture(id, frame)
    local editor = ns.LayoutEditor
    local rect = editor:Read(id)
    if not rect then return end
    self.applying[id] = true
    editor:ScaleToWidth(frame, rect.w)
    editor:Place(frame, rect)
    self.applying[id] = nil
end

local function applyBars() if ns.NativeActionBars then ns.NativeActionBars:Apply() end end
local function applyMap()
    if not ns.MinimapPanel then return end
    ns.MinimapPanel:LayoutStack()
    if ns.DarkSkin and ns.DarkSkin.BarControls then ns.DarkSkin:BarControls() end
end
local function applyChat() if ns.DarkSkin then ns.DarkSkin:LayoutChat() end end
local function applyTracker()
    local skin, frame = ns.DarkSkin, ObjectiveTrackerFrame
    if not skin or not frame or InCombatLockdown() then return end
    skin:FitTracker()
end
local function applyAux() if ns.AuxiliaryLayout then ns.AuxiliaryLayout:Apply(true) end end

local function boundsFrames(frame)
    local frames={frame}
    for _,bar in ipairs(frame.layoutBoundsBars or {frame}) do
        local config=ns.NativeActionBars and ns.NativeActionBars.frames[bar]
        for index,button in ipairs(bar.actionButtons or {}) do
            if not config or index<=(config.stance and math.min(bar.numButtonsShowable or config.count,config.count) or config.count) then
                frames[#frames+1]=button
            end
        end
    end
    return frames
end

local function register(id, label, getFrame, resize, apply, minWidth, minHeight)
    if Targets.registered[id] or not getFrame() then return end
    Targets.registered[id] = true
    local editor = ns.LayoutEditor
    local function snapshot()
        local frame = getFrame()
        Targets:Capture(id, frame)
        return { record = editor:Copy(editor:Read(id)), rect = frame and editor:Rect(frame), scale = frame and frame:GetScale(),
            mapPosition = id == 'minimap_panel' and editor:Copy(ns.db.minimapPanelPosition) or nil }
    end
    editor:Register({ id = id, label = label, getFrame = getFrame, resize = resize,
        minWidth = minWidth, minHeight = minHeight,
        getBoundsFrames = boundsFrames,
        snapshot = snapshot,
        commit = function(rect)
            if InCombatLockdown() then return end
            editor:Store(id, rect)
            apply()
        end,
        restore = function(saved)
            if InCombatLockdown() then return end
            editor:Store(id, saved and saved.record or nil)
            if id == 'minimap_panel' then ns.db.minimapPanelPosition = saved and editor:Copy(saved.mapPosition) or nil end
            if not saved or not saved.record then
                Targets:RestoreDefault(id, getFrame())
                -- Chat and action owners regenerate their exact default sizes.
                -- Dynamic native tracker/extra sizes remain native-owned.
            end
            apply()
            if saved and not saved.record and saved.rect and id ~= 'actions_left' and id ~= 'actions_right' and id ~= 'chat' then
                local frame = getFrame()
                if frame then
                    local setScale = frame.SetScaleBase or frame.SetScale
                    setScale(frame, saved.scale)
                    editor:Place(frame, saved.rect)
                end
            end
        end,
    })
end

-- The tracker root includes unused native available height. Edit the fitted
-- visible shell, then convert its desired rectangle into root position/scale.
local function registerTracker()
    if ns.QuestDrawer then return end
    local root = ObjectiveTrackerFrame
    local shell = ns.DarkSkin and ns.DarkSkin.questFrame
    if Targets.registered.quest_tracker or not root or not shell then return end
    local editor = ns.LayoutEditor
    Targets:Capture('quest_tracker', root)
    Targets.registered.quest_tracker = true
    editor:Register({
        id = 'quest_tracker', label = 'Quest tracker', resize = 'scale', minWidth = 100,
        getFrame = function() return ns.DarkSkin and ns.DarkSkin.questFrame end,
        snapshot = function()
            local saved = { record = editor:Copy(editor:Read('quest_tracker')), scale = root:GetScale(), points = {} }
            for i = 1, root:GetNumPoints() do saved.points[i] = { root:GetPoint(i) } end
            return saved
        end,
        commit = function(rect)
            if InCombatLockdown() then return end
            local currentRoot = editor:Rect(root)
            local currentShell = editor:Rect(shell)
            if not currentRoot or not currentShell or currentShell.w <= 0 then return end
            local ratio = rect.w / currentShell.w
            editor:Store('quest_tracker', {
                x = rect.x + (currentRoot.x - currentShell.x) * ratio,
                y = rect.y + (currentRoot.y - currentShell.y) * ratio,
                w = currentRoot.w * ratio,
                h = currentRoot.h * ratio,
            })
            applyTracker()
        end,
        restore = function(saved)
            if InCombatLockdown() then return end
            editor:Store('quest_tracker', saved and saved.record or nil)
            if saved then
                local setScale = root.SetScaleBase or root.SetScale
                local clear = root.ClearAllPointsBase or root.ClearAllPoints
                local setPoint = root.SetPointBase or root.SetPoint
                setScale(root, saved.scale)
                clear(root)
                for _, point in ipairs(saved.points) do setPoint(root, unpack(point)) end
            else
                Targets:RestoreDefault('quest_tracker', root)
            end
            applyTracker()
        end,
    })
end

-- Apply the requested widths once through the existing native layout owners.
-- Later manual edits remain authoritative; retain exact prior records for undo.
local function centerOwnerBars()
    if not ns.db then return end
    ns.db.appearance = ns.db.appearance or {}
    if ns.db.appearance.centeredBars30020261110 then return end
    local editor, ids = ns.LayoutEditor, { 'cast_bar', 'pet_bar' }
    local record = { before = {}, after = {} }
    local rectangles = {}
    for _, id in ipairs(ids) do
        local spec = editor.specs[id]
        local bounds = spec and spec.getFrame() and editor:Bounds(spec)
        if not bounds then return end
        record.before[id] = spec.snapshot()
        local desired = editor:Copy(bounds)
        desired.w, desired.h = 300, bounds.h * 300 / bounds.w
        desired.x = (editor:Metrics() - desired.w) / 2
        rectangles[id] = desired
    end
    local undoCount = #editor.undo
    for _, id in ipairs(ids) do
        local ok = editor:Commit(id, rectangles[id], true)
        local actual = editor:Bounds(editor.specs[id])
        if not ok or not actual or math.abs(actual.w-300)>.05
            or math.abs(actual.x+actual.w/2-editor:Metrics()/2)>.05 then
            for _, previous in ipairs(ids) do editor.specs[previous].restore(record.before[previous]) end
            while #editor.undo > undoCount do table.remove(editor.undo) end
            return
        end
        record.after[id] = editor:Copy(actual)
    end
    ns.db.appearance.centeredBars30020261110 = record
end

function Targets:Register()
    if InCombatLockdown() then self.pending = true; return end
    self.pending = nil
    register('actions_right', 'Right action block', function() return ns.NativeActionBars and ns.NativeActionBars.borderGroups and ns.NativeActionBars.borderGroups[1] end, 'scale', applyBars, 100)
    register('actions_left', 'Left action block', function() return ns.NativeActionBars and ns.NativeActionBars.borderGroups and ns.NativeActionBars.borderGroups[2] end, 'scale', applyBars, 100)
    register('minimap_panel', 'Map, XP, menu and bags', function() return ns.MinimapPanel and ns.MinimapPanel.frame end, 'scale', applyMap, 100)
    register('chat', 'Chat', function() return ns.DarkSkin and ns.DarkSkin.chatPanel end, 'free', applyChat, 200, 100)
    registerTracker()
    for _, item in ipairs({
        { 'pet_bar', 'Pet action bar', 'PetActionBar' },
        { 'stance_bar', 'Stance bar', 'StanceBar' },
        { 'possess_bar', 'Possess bar', 'PossessActionBar' },
        { 'cast_bar', 'Player cast bar', PlayerCastingBarFrame and 'PlayerCastingBarFrame' or 'CastingBarFrame' },
        { 'vehicle_leave', 'Vehicle leave', 'MainMenuBarVehicleLeaveButton' },
        { 'extra_action', 'Extra ability', ExtraAbilityContainer and 'ExtraAbilityContainer' or 'ExtraActionBarFrame' },
    }) do
        local id, label, name = unpack(item)
        register(id, label, function() return _G[name] end, 'scale', applyBars, 25)
    end
    -- The retired aura panel has no handle; its place is taken by the buff and debuff bars.
    for _, item in ipairs({ { 'minimap_buttons', 'Minimap addon buttons', 'SquanchOnMinimapButtons' } }) do
        local id, label, name = unpack(item)
        register(id, label, function() return _G[name] end, 'scale', applyAux, 25)
    end
    for _, item in ipairs({ { 'player_buffs', 'Buff bar', 'SquanchOnPlayerBuffs' },
        { 'player_debuffs', 'Debuff bar', 'SquanchOnPlayerDebuffs' } }) do
        local id, label, name = unpack(item)
        register(id, label, function() return _G[name] end, 'scale',
            function() if ns.UnitFrames and ns.UnitFrames.PlacePlayerBars then ns.UnitFrames:PlacePlayerBars() end end, 60)
    end
    centerOwnerBars()
    if ObjectiveTrackerFrame and ObjectiveTrackerFrame.ApplySystemAnchor and not self.trackerHooked then
        self.trackerHooked = true
        hooksecurefunc(ObjectiveTrackerFrame, 'ApplySystemAnchor', applyTracker)
    end
end
local events = CreateFrame('Frame')
for _, event in ipairs({ 'PLAYER_LOGIN', 'ADDON_LOADED', 'PLAYER_REGEN_ENABLED' }) do events:RegisterEvent(event) end
events:SetScript('OnEvent', function(_, event)
    if event == 'ADDON_LOADED' and not Targets.started then return end
    if event == 'PLAYER_LOGIN' then Targets.started = true end
    -- Combat end repeats the registration only when combat deferred it.
    if event == 'PLAYER_REGEN_ENABLED' and not Targets.pending then return end
    if Targets.started then C_Timer.After(0, function() Targets:Register() end) end
end)
