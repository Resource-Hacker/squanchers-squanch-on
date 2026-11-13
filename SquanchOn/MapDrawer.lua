-- SPDX-License-Identifier: MIT
-- The world map slides out sideways as a drawer beside the expanded quest list.
--
-- Blizzard keeps the map: panel management, canvas, quest pins and every way
-- of opening or closing it (M, L, Escape, its close button, quest links). This
-- file owns only where the windowed map sits and its scale; LayoutWindows.lua
-- hands the map to it (see `attached` there). The quests already show in the
-- quest list beside it, so the map opens without its own quest log panel.
--
-- Sequence: the quest list first pulls up (or unfolds, when collapsed) to at
-- least the top of the character sheet as it opens above chat, then the map
-- slides out from the list's edge at exactly the list's height. When the map
-- closes the list returns to its own height.
--
-- Taint: nothing here calls a map method, writes a map field or shows or hides
-- a UI panel. Addon code may not show or hide panels in combat
-- (UIParentPanelManager CheckProtectedFunctionsAllowed), and a map shown from
-- addon code acquires its pins on a tainted path, where SetPassThroughButtons
-- is blocked in combat. So the Map plate and the quest drawer's close button
-- are secure action buttons that click Blizzard's own buttons.
local _, ns = ...
local Drawer = {}
ns.MapDrawer = Drawer

local MARGIN = 12 -- UIParent units kept clear at the screen edge toward the centre

local function enabled() return ns.LayoutWindows:Setting('mapDrawer') ~= false end

function Drawer:Owns(frame)
    return self.ready and frame ~= nil and frame == WorldMapFrame and enabled() or false
end

-- The quest drawer's bottom is the minimap panel's top (the XP bar) and its
-- sides are the panel's sides. The panel is always shown, the drawer not.
-- Returned in UIParent units.
local function panelRect()
    local panel = ns.MinimapPanel and ns.MinimapPanel.frame
    local left, right, top = panel and panel:GetLeft(), panel and panel:GetRight(), panel and panel:GetTop()
    if not (left and right and top) then return end
    local k = panel:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return left * k, right * k, top * k
end
-- The map opens toward the screen centre: leftward from a drawer on the right half.
local function leftward(left, right)
    return not left or left + right > UIParent:GetWidth()
end

-- The quest list's minimum height while the map is out: up to the top of the
-- character sheet as it opens above chat (LayoutWindows:DrawerTop, known even
-- while the sheet is closed), in the quest drawer's frame units. Nil when the
-- sheet is no chat drawer.
local function reachHeight()
    local top = CharacterFrame and ns.LayoutWindows:DrawerTop(CharacterFrame)
    local _, _, base = panelRect()
    if not top or not base then return end
    local _, ph, _, uy = ns.LayoutEditor:Metrics()
    local reach = ((ph - top) / uy - base) * UIParent:GetEffectiveScale() / ns.QuestDrawer.frame:GetEffectiveScale()
    if reach > 0 then return reach end
end

local function place(self)
    local map, drawer = WorldMapFrame, ns.QuestDrawer.frame
    if map:IsMaximized() then
        -- Blizzard sizes the full-screen map from UIParent at the panel's own scale.
        if math.abs(map:GetScale() - 1) > .0005 then map:SetScale(1) end
        return
    end
    -- The quest list opens first. It is protected: in combat that waits.
    if not drawer:IsShown() then
        if InCombatLockdown() then self.pending = true else drawer:Show() end
    end
    local left, right = panelRect()
    local width, height = map:GetSize()
    if not left or width <= 0 or height <= 0 then return end
    local toLeft = leftward(left, right)
    local room = toLeft and left or UIParent:GetWidth() - right
    -- Exactly the quest list's height (bottoms and tops level), at the map's own
    -- aspect, unless the room toward the centre is narrower than that width.
    local tall = drawer:GetHeight() * drawer:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local scale = math.max(.1, math.min((room - MARGIN) / width, tall / height))
    if math.abs(map:GetScale() - scale) > .0005 then map:SetScale(scale) end
    local point, relativePoint = 'BOTTOMLEFT', 'BOTTOMRIGHT'
    if toLeft then point, relativePoint = 'BOTTOMRIGHT', 'BOTTOMLEFT' end
    local current, relative = map:GetPoint(1)
    if map:GetNumPoints() ~= 1 or current ~= point or relative ~= drawer then
        map:ClearAllPoints()
        map:SetPoint(point, drawer, relativePoint, 0, 0)
    end
end

function Drawer:Fit()
    local map = WorldMapFrame
    if self.fitting or not self:Owns(map) or not map:IsShown() then return end
    -- The map has no protected parts, so moving and scaling it is allowed in
    -- combat; were a client ever to protect it, that would wait for combat's end.
    if InCombatLockdown() and map:IsProtected() then self.pending = true; return end
    self.fitting = true
    local ok, err = pcall(place, self)
    self.fitting = false
    if not ok then geterrorhandler()(err) end
end

function Drawer:Queue()
    if self.fitting or self.queued then return end
    self.queued = true
    C_Timer.After(0, function() self.queued = nil; self:Fit() end)
end

-- The map just showed: pull the quest list up to its minimum height (or let
-- it unfold, when collapsed), then slide the map out once that has finished.
-- In combat the list is protected and keeps its height; SetReach records the
-- pull-up for combat's end and the map slides out at once at the current height.
function Drawer:Opened()
    local map, quests = WorldMapFrame, ns.QuestDrawer
    if not self:Owns(map) then return end
    local drawer, delay = quests.frame, 0
    if not map:IsMaximized() then
        local collapsed, before, reach = not drawer:IsShown(), drawer:GetHeight(), reachHeight()
        quests:SetReach(reach)
        if not InCombatLockdown() and (collapsed or reach and reach > before + .5) then
            delay = ns.DrawerMotion:Unfold() or 0
        end
    end
    self:Fit()
    -- Plays only when the map really sits on the drawer (DrawerMotion's anchor
    -- check). Legal in combat: an addon-owned stand-in is sized and the map gets
    -- only a render-only alpha animation and a scale restatement. A protected
    -- map would open instantly instead.
    if not (InCombatLockdown() and map:IsProtected()) then
        ns.DrawerMotion:Open(map, drawer, nil, nil, leftward(panelRect()) and 'left' or 'right', delay)
    end
end

-- Only the windowed map without its quest log panel is this drawer: the
-- maximized map is Blizzard's full-screen panel with its own blackout, and the
-- quests already show beside it. Every opener reads these settings when the
-- map shows (QuestLogOwnerMixin:GetOpenDisplayState, ShouldShowQuestLogPanel;
-- WorldMapMixin:OnShow). Maximizing or opening the panel still works for the
-- map it is done on and is undone when that map closes. L and quest-detail
-- links (ToggleQuestLog, OpenQuestLog) always add the panel; that stays native.
function Drawer:KeepWindowed()
    if not self:Owns(WorldMapFrame) then return end
    if GetCVarBool('miniWorldMap') and not GetCVarBool('questLogOpen') then return end
    if InCombatLockdown() then self.pending = true; return end
    if not GetCVarBool('miniWorldMap') then SetCVar('miniWorldMap', '1') end
    if GetCVarBool('questLogOpen') then SetCVar('questLogOpen', '0') end
end

-- The secure click action refuses buttons with access constraints or that
-- forbid scripted input (SecureTemplates.lua, SECURE_ACTIONS.click).
local function clickable(button)
    if not button or not button.Click then return end
    if button.HasAccessConstraints and button:HasAccessConstraints() then return end
    local aspect = Enum.ForbiddenAspect and Enum.ForbiddenAspect.ScriptedInput
    if aspect and button.HasAnyForbiddenAspects and button:HasAnyForbiddenAspects(aspect) then return end
    return button
end

function Drawer:Initialize()
    if self.ready then return true end
    local map, quests, skin = WorldMapFrame, ns.QuestDrawer, ns.DarkSkin
    if not (map and map.BorderFrame and quests.ready and skin) then return end
    -- The minimap's zone button runs ToggleWorldMap, exactly what M does. The
    -- theme conceals it, which does not stop Button:Click (only a disabled
    -- button ignores it). Blizzard's Map & Quest Log micro button
    -- (ToggleQuestLog, which always adds the quest panel) serves a client without it.
    self.openTarget = clickable(MinimapCluster and MinimapCluster.ZoneTextButton) or clickable(QuestLogMicroButton)
    -- On a closed map this button does nothing: HideUIPanel returns for a hidden frame.
    self.closeTarget = clickable(map.BorderFrame.CloseButton)
    quests.closeButton:SetAttribute('clickbutton', self.closeTarget)
    -- The Map plate: a raised plate on the quest drawer's top rim, at the end
    -- facing the screen centre, beside the centred Quests title.
    local handle = CreateFrame('Button', nil, quests.frame, 'SecureActionButtonTemplate')
    handle:SetSize(40, 18)
    handle:RegisterForClicks('LeftButtonUp')
    handle:SetAttribute('useOnKeyDown', false)
    handle:SetAttribute('type', 'click')
    handle:SetAttribute('clickbutton', self.openTarget)
    skin:RaisedButton(handle, 'compact')
    local label = handle:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    label:SetAllPoints(handle)
    label:SetText('Map')
    if ns.NativeText then ns.NativeText:Header(label, 'questHeader') end
    quests:HeadingLook(label)
    self.handle = handle
    -- Panel management re-anchors the map to its native place whenever panels
    -- change; place it back at once, before a frame is drawn there.
    hooksecurefunc(map, 'SetPoint', function() self:Fit() end)
    map:HookScript('OnShow', function() self:Opened() end)
    map:HookScript('OnHide', function()
        self:KeepWindowed()
        ns.QuestDrawer:SetReach(nil)
    end)
    self.ready = true
    self:KeepWindowed()
    return true
end

-- After every full quest drawer layout (out of combat only): the plate's side
-- and the close button's map action.
function Drawer:Attach()
    local quests = ns.QuestDrawer
    if InCombatLockdown() or not quests.ready or not self:Initialize() then return end
    local on, frame, handle = enabled(), quests.frame, self.handle
    quests.closeButton:SetAttribute('type', on and self.closeTarget and 'click' or nil)
    handle:SetShown(on and self.openTarget ~= nil)
    handle:ClearAllPoints()
    if leftward(panelRect()) then handle:SetPoint('BOTTOMLEFT', frame, 'TOPLEFT', 4, -4)
    else handle:SetPoint('BOTTOMRIGHT', frame, 'TOPRIGHT', -4, -4) end
    handle:SetFrameLevel(quests.titlePlate:GetFrameLevel())
end

hooksecurefunc(ns.QuestDrawer, 'Layout', function() Drawer:Attach() end)
-- The map's height follows the list's in the same frame: after each native
-- quest pass (Refit) and each step of the pull-up (FitReach).
hooksecurefunc(ns.QuestDrawer, 'Refit', function() Drawer:Fit() end)
hooksecurefunc(ns.QuestDrawer, 'FitReach', function() Drawer:Fit() end)

local events = CreateFrame('Frame')
events:RegisterEvent('PLAYER_REGEN_ENABLED')
events:SetScript('OnEvent', function()
    -- Only work that combat deferred: the quest list's show, the settings, a
    -- refit. A held-back pull-up resumes in QuestDrawer.lua.
    if not Drawer.pending then return end
    Drawer.pending = nil
    Drawer:KeepWindowed()
    Drawer:Fit()
end)
