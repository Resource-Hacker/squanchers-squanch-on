-- SPDX-License-Identifier: MIT
-- One attached presentation owner; Blizzard retains quest rows/items and input.
local _,ns=...
local Drawer={pending=false,contentPadding=22}
ns.QuestDrawer=Drawer
local events=CreateFrame('Frame')

-- Session-only presentation state. Native methods and bookkeeping stay untouched.
local collapsedQuests={}
local entryRecords=setmetatable({},{__mode='k'})
local hiddenRegions=setmetatable({},{__mode='k'})
local function restoreRegion(region)
    local alpha=hiddenRegions[region]
    if alpha~=nil then region:SetAlpha(alpha);hiddenRegions[region]=nil end
end
function Drawer:RestoreQuestBodies()
    for region in pairs(hiddenRegions) do restoreRegion(region) end
end
function Drawer:InstallQuestEntries()
    if self.questEntries or not QuestObjectiveTracker then return end
    self.questEntries=QuestObjectiveTracker
    -- GetBlock calls AnchorBlock before SetHeader/AddObjective measure their
    -- strings. Use the drawer's actual content bounds at that native edge;
    -- moving blocks only after measurement leaves heights for another width.
    hooksecurefunc(self.questEntries,'AnchorBlock',function(module,block)
        if not self.ready or InCombatLockdown() then return end
        block:SetPoint('LEFT',module,'LEFT',0,0)
        if not block.fixedWidth then block:SetPoint('RIGHT',module,'RIGHT',0,0) end
    end)
    -- Release is posthooked, never replaced: restore owned alpha before a pooled
    -- region can be acquired by another module, and hide our pooled block button.
    hooksecurefunc(ObjectiveTrackerManager,'ReleaseFrame',function(_,frame)
        restoreRegion(frame)
        local record=entryRecords[frame]
        if record then record.button:Hide() end
    end)
end
function Drawer:FitQuestEntries()
    if InCombatLockdown() then self.pending=true;return end
    local module=self.questEntries
    if not module then return end
    self:RestoreQuestBodies()
    module.Header:Hide()
    -- Native XML starts this container at Header.BOTTOM (26 UI below module
    -- TOP). With the shelf removed, its rows must occupy the whole module;
    -- retaining that inset leaves only a sliver after compact-height fitting.
    local contents=module.ContentsFrame
    if contents then
        contents:ClearAllPoints()
        contents:SetAllPoints(module)
    end
    local block,previous,total=module.firstBlock,nil,0
    while block do
        local nextBlock=block.nextBlock
        if block.used and block.HeaderText and block.HeaderButton then
            local record=entryRecords[block]
            if not record then
                record={}
                entryRecords[block]=record
                local button=CreateFrame('Button',nil,block)
                record.button=button
                button:SetSize(12,12)
                button:SetPoint('TOPRIGHT',block.HeaderText,'TOPLEFT',-2,0)
                button:SetFrameLevel(block.HeaderButton:GetFrameLevel()+1)
                local text=button:CreateFontString(nil,'OVERLAY','GameFontNormal')
                text:SetAllPoints(button)
                if ns.NativeText then ns.NativeText:Header(text,'questHeader') end
                record.text=text
                button:SetScript('OnClick',function()
                    if InCombatLockdown() then return end
                    local id=button:GetParent().id
                    if not id then return end
                    collapsedQuests[id]=not collapsedQuests[id] or nil
                    module:MarkDirty()
                    self:RequestLayout()
                end)
            end
            local collapsed=collapsedQuests[block.id]
            record.text:SetText(collapsed and '+' or '-')
            record.button:Show()
            local height=block.height -- read native full height; never overwrite it
            if collapsed then
                local function conceal(region)
                    if region and hiddenRegions[region]==nil then
                        hiddenRegions[region]=region:GetAlpha();region:SetAlpha(0)
                    end
                end
                height=math.max(12,block.HeaderText:GetHeight())
                for _,line in pairs(block.usedLines or {}) do
                    if line.used then conceal(line) end
                end
                for region in pairs(block.addedRegions or {}) do
                    if region.parentLine then conceal(region)
                    elseif region.used then
                        local top,bottom=block:GetTop(),region:GetBottom()
                        height=math.max(height,top and bottom and top-bottom or region:GetHeight())
                    end
                end
            end
            block:SetHeight(height)
            block:ClearAllPoints()
            block:SetPoint('TOP',previous or module,previous and 'BOTTOM' or 'TOP',0,
                previous and module.fromBlockOffsetY or 0)
            block:SetPoint('LEFT',module,'LEFT',0,0)
            if not block.fixedWidth then block:SetPoint('RIGHT',module,'RIGHT',0,0) end
            block.HeaderText:SetJustifyH('LEFT')
            for _,line in pairs(block.usedLines or {}) do
                if line.Text then line.Text:SetJustifyH('LEFT') end
            end
            total=total+height-(previous and module.fromBlockOffsetY or 0)
            previous=block
        end
        block=nextBlock
    end
    if previous then module:SetHeight(total+(module.bottomSpacing or 0)+(module.heightModifier or 0)) end
    -- Native container modules already anchor to the previous module's BOTTOM,
    -- so shortening this frame also moves every later module without scalar edits.
end

function Drawer:RequestLayout()
    if self.layouting then return end
    self.pending=true
    if InCombatLockdown() or self.queued then return end
    self.queued=true
    C_Timer.After(0,function()
        self.queued=false
        if InCombatLockdown() then return end
        if not self.ready then self:Initialize() end
        if self.ready then self:Layout() end
    end)
end

local function setWidth(frame,width)
    if frame and math.abs(frame:GetWidth()-width)>.01 then frame:SetWidth(width);return true end
end

local function headerWidth(header,width)
    if not header then return end
    setWidth(header,width)
    -- Native headers reserve their right-hand collapse/filter buttons.
    setWidth(header.Text,math.max(1,width-52))
end

function Drawer:Layout()
    if not self.ready or self.layouting then return end
    if InCombatLockdown() then self.pending=true;return end
    self.layouting=true
    local tracker,frame,skin=self.tracker,self.frame,ns.DarkSkin
    local map=Minimap
    local scale=frame:GetEffectiveScale()
    local mapScale=map:GetEffectiveScale()
    -- Match the equipment atlas's painted edge, not its transparent margins.
    local spec=skin.styles.minimap
    local pixel=PixelUtil.GetPixelToUIUnitFactor()/mapScale
    local outside=spec.edge*9/13-pixel/2-spec.edge*5/13
    local width=(map:GetWidth()+outside*2)*mapScale/scale
    local left=-outside*mapScale/scale
    local xp=ns.NativeDataBars and ns.NativeDataBars.xp
    local anchor=xp or map
    local anchorScale=anchor:GetEffectiveScale()
    local anchorLeft=anchor:GetLeft()
    local anchorTop=anchor:GetTop()
    if not anchorLeft or not anchorTop or width<=35 then
        self.layouting=false;self.pending=true;return
    end
    -- The compact rim's painted edge coincides with its host rectangle.
    frame:ClearAllPoints()
    frame:SetPoint('BOTTOMLEFT',anchor,'TOPLEFT',left,0)
    frame:SetWidth(width)
    self.handle:ClearAllPoints()
    self.handle:SetPoint('BOTTOM',anchor,'TOP',0,0)
    self.handle:SetSize(22,18)
    local available=math.max(64,(UIParent:GetHeight()*UIParent:GetEffectiveScale()
        -anchorTop*anchorScale)/scale-8)
    local contentWidth=width-23 -- collapse control18 and right gutter5
    -- Blizzard's UpdateHeight reads its parent's height on every native show.
    -- The viewport owns available layout space; the drawer owns painted height.
    self.viewport:SetWidth(contentWidth)
    self.viewport:SetHeight(available)
    tracker:SetClampedToScreen(false)
    tracker:SetScale(1)
    setWidth(tracker,contentWidth)
    headerWidth(tracker.Header,contentWidth)
    for _,module in ipairs(tracker.modules or {}) do
        setWidth(module,contentWidth-(module.leftMargin or 0))
        headerWidth(module.Header,module:GetWidth())
        if module==self.questEntries then
            -- Install the final viewport width before the owner measures text.
            local contents=module.ContentsFrame
            if contents then
                contents:ClearAllPoints()
                contents:SetAllPoints(module)
            end
            if module:IsCollapsed() then module:SetCollapsed(false) end
        end
    end
    if math.abs(tracker:GetHeight()-available)>.01 then tracker:SetHeight(available) end
    tracker:ClearAllPoints()
    tracker:SetPoint('TOPLEFT',self.viewport,'TOPLEFT',0,0)
    -- Reflow only through the native owner, preserving block/item scripts.
    self:RestoreQuestBodies()
    if ns.NativeText then ns.NativeText:Tracker(tracker) end
    tracker:Update()
    tracker.Header:Hide()
    self:FitQuestEntries()
    -- Drop the native primary-header reservation using frame anchors only.
    local previousModule
    for _,module in ipairs(tracker.modules or {}) do
        if module:IsShown() and module:GetContentsHeight()>0 then
            module:SetPoint('TOP',previousModule or tracker,
                previousModule and 'BOTTOM' or 'TOP',0,
                previousModule and -(tracker.moduleSpacing or 0) or 0)
            previousModule=module
        end
    end
    self.fitting=true
    skin:FitTracker()
    self.fitting=false
    local shell=skin.questFrame
    local rim=skin.byFrame[shell] and skin.byFrame[shell].compact
    if rim then
        self.titlePlate:SetFrameLevel(rim:GetFrameLevel()+2)
        self.closeButton:SetFrameLevel(self.titlePlate:GetFrameLevel()+1)
    end
    local top,bottom=shell and shell:GetTop(),shell and shell:GetBottom()
    local shellScale=shell and shell:GetEffectiveScale()
    local height=top and bottom and math.max(20,(top-bottom)*shellScale/scale) or 20
    frame:SetHeight(height)
    -- Anchor once more after native managed-frame/header update callbacks.
    tracker:ClearAllPoints()
    tracker:SetPoint('TOPLEFT',self.viewport,'TOPLEFT',0,0)
    self.pending=false
    self.layouting=false
end

-- The drawer title wears the shared heading look (the unselected chat tab's
-- label): heading gold at the tab's opacity. NativeText keeps owning its font
-- size; only the colour is set here and again on theme changes.
local headings={}
function Drawer:HeadingLook(region)
    local skin=ns.DarkSkin
    if not skin or not skin.headerTextColor then return end
    local function paint()
        local color=skin.headerTextColor
        region:SetTextColor(color[1],color[2],color[3],color[4] or 1)
    end
    if not headings[region] then
        headings[region]=true
        if skin.OnTheme then skin:OnTheme(paint) end
    end
    paint()
end

function Drawer:Initialize()
    if self.ready then return true end
    if InCombatLockdown() then self.pending=true;return end
    local panel=ns.MinimapPanel and ns.MinimapPanel.frame
    local tracker,skin=ObjectiveTrackerFrame,ns.DarkSkin
    if not panel or not tracker or not tracker.Header or not skin or not skin.questFrame then return end
    local frame=CreateFrame('Frame',nil,panel,'SecureHandlerShowHideTemplate')
    frame:Hide()
    frame.ignoreInLayout=true
    frame:SetSize(ns.MinimapPanel.width,32)
    frame:SetFrameStrata(tracker:GetFrameStrata())
    local handle=CreateFrame('Button',nil,panel,'SecureHandlerClickTemplate')
    handle.ignoreInLayout=true
    handle:EnableMouse(true)
    handle:SetSize(22,18)
    handle:RegisterForClicks('LeftButtonUp')
    local arrow=handle:CreateTexture(nil,'ARTWORK')
    arrow:SetTexture([[Interface\Buttons\UI-ScrollBar-ScrollUpButton-Up]])
    arrow:SetAllPoints(handle)
    skin:TintChrome(arrow)
    local title=handle:CreateFontString(nil,'OVERLAY','GameFontNormal')
    title:SetPoint('BOTTOM',handle,'TOP',0,2)
    title:SetText(QUESTS_LABEL or 'Quests')
    if ns.NativeText then ns.NativeText:Header(title,'questHeader') end
    Drawer:HeadingLook(title)
    title:Hide()
    -- Hover is presentation only. It never changes secure drawer visibility.
    handle:HookScript('OnEnter',function() title:Show() end)
    handle:HookScript('OnLeave',function() title:Hide() end)
    handle:HookScript('OnHide',function() title:Hide() end)
    handle:SetFrameRef('drawer',frame)
    handle:SetAttribute('_onclick',[[
        if button == 'LeftButton' then self:GetFrameRef('drawer'):Show();self:Hide() end
    ]])
    frame:SetFrameRef('handle',handle)
    frame:SetAttribute('_onshow',[[self:GetFrameRef('handle'):Hide()]])
    -- Same half-second open as the chat drawers; the painted window is the compact quest shell.
    frame:HookScript('OnShow',function() ns.DrawerMotion:Open(frame,nil,skin.questFrame,'compact') end)
    frame:SetAttribute('_onhide',[[self:GetFrameRef('handle'):Show()]])
    local content=CreateFrame('Frame',nil,frame)
    content:SetPoint('TOPLEFT',frame,'TOPLEFT',0,-self.contentPadding)
    content:SetPoint('TOPRIGHT',frame,'TOPRIGHT',0,-self.contentPadding)
    content:SetHeight(1)
    local viewport=CreateFrame('Frame',nil,frame)
    viewport:SetPoint('TOPLEFT',content,'TOPLEFT',18,0)
    viewport:SetSize(math.max(1,ns.MinimapPanel.width-23),800)
    -- Ordinary frames do not clip children; its extent is never painted or hit.
    viewport:EnableMouse(false)
    tracker:SetParent(viewport)
    local plate=CreateFrame('Frame',nil,frame)
    plate:SetSize(76,18)
    plate:SetPoint('BOTTOMLEFT',frame,'TOPLEFT',10,-4)
    plate:SetFrameLevel(tracker:GetFrameLevel()+3)
    skin:RaisedPlate(plate,'compact')
    local label=plate:CreateFontString(nil,'OVERLAY','GameFontNormal')
    label:SetAllPoints(plate)
    label:SetText(QUESTS_LABEL or 'Quests')
    if ns.NativeText then ns.NativeText:Header(label,'questHeader') end
    Drawer:HeadingLook(label)
    local close=CreateFrame('Button',nil,frame,'SecureHandlerClickTemplate')
    close:SetSize(16,16)
    close:SetPoint('TOPRIGHT',frame,'TOPRIGHT',-4,-2)
    close:SetFrameLevel(plate:GetFrameLevel()+1)
    close:RegisterForClicks('LeftButtonUp')
    local native=tracker.Header.MinimizeButton
    local function copyArt(getter,setter)
        local source=native and native[getter] and native[getter](native)
        if not source then return end
        local texture=close:CreateTexture(nil,'ARTWORK')
        local atlas=source.GetAtlas and source:GetAtlas()
        if atlas then texture:SetAtlas(atlas,false)
        else texture:SetTexture(source:GetTexture());texture:SetTexCoord(source:GetTexCoord()) end
        texture:SetAllPoints(close)
        skin:TintChrome(texture)
        close[setter](close,texture)
    end
    copyArt('GetNormalTexture','SetNormalTexture')
    copyArt('GetPushedTexture','SetPushedTexture')
    copyArt('GetHighlightTexture','SetHighlightTexture')
    close:SetFrameRef('drawer',frame)
    close:SetFrameRef('opener',handle)
    close:SetAttribute('_onclick',[[
        if button == 'LeftButton' then
            self:GetFrameRef('drawer'):Hide()
            self:GetFrameRef('opener'):Show()
        end
    ]])
    self.frame,self.handle,self.tracker=frame,handle,tracker
    self.titlePlate,self.contentAnchor,self.closeButton=plate,content,close
    self.viewport=viewport
    self.ready=true
    self:InstallQuestEntries()
    -- Native Update explicitly calls Header:Show(), including updates arriving
    -- after our pass. Suppress that obsolete presentation at its actual owner.
    tracker.Header:SetAlpha(0)
    tracker.Header:Hide()
    hooksecurefunc(tracker.Header,'Show',function(header)
        if not InCombatLockdown() then header:Hide() end
    end)
    -- Refit once after native child show scripts run. UpdateHeight now reads
    -- the available-height viewport, independent of our compact painted shell.
    frame:HookScript('OnShow',function()
        if self.questEntries and not InCombatLockdown() then self.questEntries:MarkDirty() end
        self:RequestLayout()
    end)
    -- Keep native root/module state expanded behind the hidden secure parent.
    if tracker:IsCollapsed() then tracker:SetCollapsed(false) end
    tracker:Show()
    hooksecurefunc(tracker,'Update',function() self:RequestLayout() end)
    -- The native dirty callback captured Update before addon posthooks existed.
    -- Its dynamically looked-up padding method still observes every native pass.
    -- Refit after that pass, without tainting native padding/bookkeeping fields.
    hooksecurefunc(tracker,'UpdateTopPadding',function() self:RequestLayout() end)
    hooksecurefunc(tracker,'UpdateHeight',function() self:RequestLayout() end)
    hooksecurefunc(ns.MinimapPanel,'LayoutStack',function() self:RequestLayout() end)
    panel:HookScript('OnDragStop',function() self:RequestLayout() end)
    panel:HookScript('OnSizeChanged',function() self:RequestLayout() end)
    self:Layout()
    return true
end

events:RegisterEvent('PLAYER_LOGIN')
events:RegisterEvent('ADDON_LOADED')
events:RegisterEvent('PLAYER_REGEN_ENABLED')
events:SetScript('OnEvent',function(_,event)
    if event=='PLAYER_LOGIN' then Drawer.loggedIn=true end
    if event=='PLAYER_REGEN_ENABLED' and Drawer.questEntries then
        Drawer.questEntries:MarkDirty()
    end
    if Drawer.loggedIn then Drawer:RequestLayout() end
end)
