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
-- closes the list returns to its own height. While the list pulls up the map
-- is held invisible (DrawerMotion's delay) at the size it will have when the
-- list arrives; it is not rescaled with every step of the pull-up.
--
-- Opening and closing: an arrow on the quest list's side toward the screen
-- centre (the minimap panel's side arrow, DarkSkin:DrawerArrow) pulls the map
-- out; while the map is out that arrow is hidden and a second one, on the
-- map's edge beside the list and pointing back at it, slides the map back in.
-- The map's own title plate ("Map", NativeWindowBorders.lua) and the quest
-- drawer's close button close it too. Blizzard's quest-panel toggle on the
-- map's corner is hidden while the map is this drawer: the quests are beside it.
--
-- Taint: nothing here calls a map method, writes a map field or shows or hides
-- a UI panel (the quest-panel toggle is a plain overlay button of the map,
-- not a panel). Addon code may not show or hide panels in combat
-- (UIParentPanelManager CheckProtectedFunctionsAllowed), and a map shown from
-- addon code acquires its pins on a tainted path, where SetPassThroughButtons
-- is blocked in combat. So both arrows, the click on the Map plate and the
-- quest drawer's close button are secure action buttons that click Blizzard's
-- own buttons. Secure buttons are shown, hidden and moved only out of combat,
-- and are never anchored to the map: that would protect the map, which must
-- stay movable in combat (Fit).
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
    -- During the pull-up before the slide (Opened) that is the height the list
    -- is growing to: the map, held invisible meanwhile, keeps one scale instead
    -- of being rescaled on every step (opened that way, the frame-buffered map
    -- showed its pins on bare parchment, without its detail tiles).
    local listHeight = drawer:GetHeight()
    if self.finalHeight then
        if InCombatLockdown() or listHeight >= self.finalHeight - .5 then self.finalHeight = nil
        else listHeight = self.finalHeight end
    end
    local tall = listHeight * drawer:GetEffectiveScale() / UIParent:GetEffectiveScale()
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
    self:QueueCloser()
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
    self.finalHeight = nil
    if not map:IsMaximized() then
        local collapsed, before, reach = not drawer:IsShown(), drawer:GetHeight(), reachHeight()
        quests:SetReach(reach)
        if not InCombatLockdown() and (collapsed or reach and reach > before + .5) then
            delay = ns.DrawerMotion:Unfold() or 0
            -- Where the pull-up ends (QuestDrawer:SetReach's target); place()
            -- sizes the held map for it.
            if delay > 0 and reach then self.finalHeight = math.max(reach, quests.naturalHeight or before) end
        end
    end
    self.openedAt, self.openDelay = GetTime(), delay
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
    -- The Map arrow: the minimap panel's side arrow, here a secure action
    -- button on the quest list that clicks the map's opener (a toggle).
    local arrow = skin:DrawerArrow(quests.frame, 'Map', 'SecureActionButtonTemplate')
    arrow:SetAttribute('useOnKeyDown', false)
    arrow:SetAttribute('type', 'click')
    arrow:SetAttribute('clickbutton', self.openTarget)
    self.arrow = arrow
    -- The click on the map's title plate: a secure button with no art over the
    -- plate (which belongs to the map), a child of the quest list and placed
    -- by rectangle (PlaceCloser), so it is never anchored to the map.
    local closer = CreateFrame('Button', nil, quests.frame, 'SecureActionButtonTemplate')
    closer:Hide()
    closer:RegisterForClicks('LeftButtonUp')
    closer:SetAttribute('useOnKeyDown', false)
    closer:SetAttribute('type', 'click')
    closer:SetAttribute('clickbutton', self.closeTarget)
    -- The plate lights under the mouse like a raised button.
    local function light(hovered)
        local plate = skin.titlePlates[map.BorderFrame]
        if plate then plate.paint(true, false, hovered) end
    end
    closer:HookScript('OnEnter', function() light(true) end)
    closer:HookScript('OnLeave', function() light(false) end)
    self.closer = closer
    -- The way back: the same drawer arrow on the map's edge beside the list,
    -- pointing at the list, clicking the map's close button. Also a child of
    -- the quest list placed by rectangle (PlaceCloser), drawn above the map.
    local back = skin:DrawerArrow(quests.frame, 'Map', 'SecureActionButtonTemplate')
    back:Hide()
    back:SetAttribute('useOnKeyDown', false)
    back:SetAttribute('type', 'click')
    back:SetAttribute('clickbutton', self.closeTarget)
    -- A map closed in combat leaves it shown (it then clicks nothing) until
    -- combat ends; its art and name stay invisible meanwhile (SyncArrow).
    back:HookScript('OnEnter', function() if back.arrow:GetAlpha() == 0 then back.label:Hide() end end)
    self.back = back
    -- Panel management re-anchors the map to its native place whenever panels
    -- change; place it back at once, before a frame is drawn there.
    hooksecurefunc(map, 'SetPoint', function() self:Fit() end)
    map:HookScript('OnShow', function()
        self:Opened()
        self:SyncArrow()
    end)
    map:HookScript('OnHide', function()
        self.finalHeight = nil
        self:KeepWindowed()
        ns.QuestDrawer:SetReach(nil)
        self:SyncArrow()
        self:QueueCloser()
    end)
    -- Blizzard's quest-panel toggle on the canvas corner (WorldMapMixin:
    -- AddOverlayFrames). QuestLogOwnerMixin:SynchronizeDisplayState shows it
    -- on every open of the windowed map; it stays hidden while the map is
    -- this drawer and native otherwise (the setting applies at the next open).
    -- A plain unprotected button: hiding it is allowed in combat.
    local toggle = map.SidePanelToggle
    local function hideToggle()
        if toggle:IsShown() and self:Owns(map) and not map:IsMaximized() then toggle:Hide() end
    end
    if toggle then toggle:HookScript('OnShow', hideToggle) end
    self.ready = true
    if toggle then hideToggle() end
    self:KeepWindowed()
    return true
end

-- The arrow points toward the screen centre: it pulls the map out. While the
-- map is shown it is hidden; in combat, where a secure button cannot be
-- hidden, it is turned back instead (still the same toggle) until combat ends.
function Drawer:SyncArrow()
    local arrow, back = self.arrow, self.back
    if not arrow then return end
    local open = WorldMapFrame:IsShown()
    local toLeft = leftward(panelRect())
    ns.DarkSkin:PointDrawerArrow(arrow, (toLeft ~= open) and 'left' or 'right')
    -- The way back points at the list. Its art goes as the map closes: in
    -- combat it cannot be hidden, otherwise PlaceCloser hides it next frame
    -- (texture alpha is not protected). A map reopened before then finds it
    -- still in place: its art returns with the map's content.
    ns.DarkSkin:PointDrawerArrow(back, toLeft and 'right' or 'left')
    if not open then
        back.arrow:SetAlpha(0); back.label:Hide()
    elseif back:IsShown() and back.arrow:GetAlpha() == 0 then
        back.arrow:SetAlpha(1)
        ns.DrawerMotion:Reveal(back.arrow, self.openDelay)
    end
    if InCombatLockdown() then self.pending = true; return end
    arrow:SetShown(enabled() and self.openTarget ~= nil and not open)
end

-- The closer covers the map's title plate while the map is out beside the
-- list; the way-back arrow sits on the map's edge beside the list. Out of
-- combat only: a map opened in combat gets them when combat ends (M, Escape,
-- its X and the list's close button work throughout), and one closed in combat
-- leaves them, clicking nothing, until then.
function Drawer:PlaceCloser()
    local closer, back, map, drawer = self.closer, self.back, WorldMapFrame, ns.QuestDrawer.frame
    if not closer then return end
    if InCombatLockdown() then self.pending = true; return end
    local skin = ns.DarkSkin
    local plate = skin.titlePlates[map.BorderFrame]
    local open = self:Owns(map) and self.closeTarget and map:IsShown() and not map:IsMaximized()
    local dleft, dbottom = drawer:GetLeft(), drawer:GetBottom()
    local left, bottom, width, height
    if open and plate and plate:IsVisible() then left, bottom, width, height = plate:GetRect() end
    if left and dleft and dbottom then
        local k = plate:GetEffectiveScale() / drawer:GetEffectiveScale()
        closer:ClearAllPoints()
        closer:SetPoint('BOTTOMLEFT', drawer, 'BOTTOMLEFT', left * k - dleft, bottom * k - dbottom)
        closer:SetSize(width * k, height * k)
        closer:SetFrameLevel(self.arrow:GetFrameLevel())
        closer:Show()
    else
        closer:Hide()
    end
    left, bottom, width, height = nil, nil, nil, nil
    if open then left, bottom, width, height = map:GetRect() end
    if not (left and dleft and dbottom) then back:Hide(); return end
    -- The opener's place on the list's side (Attach), mirrored onto the map:
    -- as far inside the map's edge that meets the list as the opener sits
    -- outside the list, centred on the map's height. List frame units, like
    -- the opener's offset.
    local k = map:GetEffectiveScale() / drawer:GetEffectiveScale()
    local inset = skin.styles.compact.offset - skin.styles.compact.edge * 4.5 / 13 + 2
    local x = leftward(panelRect()) and (left + width) * k - inset or left * k + inset
    back:ClearAllPoints()
    back:SetPoint('CENTER', drawer, 'BOTTOMLEFT', x - dleft, (bottom + height / 2) * k - dbottom)
    -- Above the map and its border frame (HIGH), so it shows over the canvas.
    local rim = skin.byFrame[map.BorderFrame] and skin.byFrame[map.BorderFrame].dialog
    back:SetFrameStrata(map.BorderFrame:GetFrameStrata())
    back:SetFrameLevel((rim or map.BorderFrame):GetFrameLevel() + 3)
    back.arrow:SetAlpha(1)
    if not back:IsShown() then
        back:Show()
        -- It appears with the map's content: the open motion's remaining hold, then its fade.
        local delay = self.openedAt and (self.openDelay or 0) - (GetTime() - self.openedAt) or 0
        ns.DrawerMotion:Reveal(back.arrow, math.max(0, delay))
    end
end
-- The plate's rectangle settles with the map's placement: read it next frame.
function Drawer:QueueCloser()
    if not self.closer or self.closerQueued then return end
    self.closerQueued = true
    C_Timer.After(0, function() self.closerQueued = nil; self:PlaceCloser() end)
end

-- After every full quest drawer layout (out of combat only): the arrow's side
-- and the close button's map action.
function Drawer:Attach()
    local quests = ns.QuestDrawer
    if InCombatLockdown() or not quests.ready or not self:Initialize() then return end
    local frame, arrow, skin = quests.frame, self.arrow, ns.DarkSkin
    quests.closeButton:SetAttribute('type', enabled() and self.closeTarget and 'click' or nil)
    -- Centred on that side, 2 beyond the compact rim's painted outer edge: the
    -- meter arrow's place on the minimap panel's side.
    local out = skin.styles.compact.offset - skin.styles.compact.edge * 4.5 / 13 + 2
    arrow:ClearAllPoints()
    if leftward(panelRect()) then arrow:SetPoint('CENTER', frame, 'LEFT', -out, 0)
    else arrow:SetPoint('CENTER', frame, 'RIGHT', out, 0) end
    arrow:SetFrameLevel(quests.titlePlate:GetFrameLevel() + 1)
    self:SyncArrow()
    self:QueueCloser()
end

hooksecurefunc(ns.QuestDrawer, 'Layout', function() Drawer:Attach() end)
-- The map's height follows the list's in the same frame: after each native
-- quest pass (Refit) and each step of a pull-up (FitReach) that runs while the
-- map is shown (after combat); the pull-up that precedes the slide is
-- absorbed by place()'s final height.
hooksecurefunc(ns.QuestDrawer, 'Refit', function() Drawer:Fit() end)
hooksecurefunc(ns.QuestDrawer, 'FitReach', function() Drawer:Fit() end)

local events = CreateFrame('Frame')
events:RegisterEvent('PLAYER_REGEN_ENABLED')
events:SetScript('OnEvent', function()
    -- Only work that combat deferred: the quest list's show, the settings, a
    -- refit, the arrow's and closer's visibility. A held-back pull-up resumes
    -- in QuestDrawer.lua.
    if not Drawer.pending then return end
    Drawer.pending = nil
    Drawer:KeepWindowed()
    Drawer:Fit()
    Drawer:SyncArrow()
    Drawer:QueueCloser()
end)
