-- SPDX-License-Identifier: MIT
-- Squancher's native dark skin. Original implementation; no skin-addon runtime.
local addonName, ns = ...
local Skin = { panels = {}, byFrame = {}, buttons = {} }
ns.DarkSkin = Skin
-- Reuse the actual Character equipment-slot material for every shared rim.
local BORDER_R, BORDER_G, BORDER_B = 0.90, 0.684, 0.378
local BORDER_ALPHA = 0.95
Skin.borderAlpha = BORDER_ALPHA
-- Action-slot reference for every neutral inner outline.
Skin.innerBorderColor = {0.70, 0.532, 0.294, 1}
local PANEL_GREY, PANEL_ALPHA = 0.054901964962482, 0.66216158866882
local BORDER_ATLAS = "UI-Character-Info-GearSlot"
local WHITE = [[Interface\Buttons\WHITE8X8]]
-- Exact client atlas:55x55 logical units (110x110 raw). The painted rim runs
-- from4.5 to9; the outer black shadow is omitted.13-unit caps retain the diamonds.
local styles = {
    dialog = { edge = 13, offset = 5 },
    unit = { edge = 13, offset = 12 },
    tooltip = { edge = 13, offset = 9 },
    compact = { edge = 13, offset = 5 },
    minimap = { edge = 13, offset = 5, contentFit = true },
    inner = { edge = 5, offset = 1 },
    icon = { edge = 13, offset = 0, paintFit = true },
    row = { edge = 13, offset = 0, contentFit = true },
}
Skin.styles = styles

function Skin:TintChrome(texture, enabled)
    if not texture then return end
    local _, _, _, alpha = texture:GetVertexColor()
    local shade = enabled == false and 0.50 or 1
    texture:SetDesaturated(true)
    texture:SetVertexColor(BORDER_R * shade, BORDER_G * shade, BORDER_B * shade, alpha)
end

local function mouseTransparent(frame)
    frame:EnableMouse(false)
    if frame.EnableMouseWheel then frame:EnableMouseWheel(false) end
    frame.ignoreInLayout = true
end

-- Fit the visible native gold rather than the atlas's shadow margins.
function Skin:FitPanelBorder(border, frame, spec)
    local offset = spec.offset
    if spec.paintFit then offset = spec.edge * 6 / 13
    elseif spec.contentFit then offset = spec.edge * 9 / 13 end
    border:ClearAllPoints()
    border:SetPoint("TOPLEFT", frame, "TOPLEFT", -offset, offset)
    border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", offset, -offset)
end

-- Editor bounds use the painted gold, excluding the atlas's empty halo.
-- Only inspect panels belonging to the explicit moving control, never arbitrary
-- child frames (detached bars and aura containers can have independent anchors).
function Skin:VisitLayoutBorders(frame, visit)
    local function panels(root)
        for _, border in pairs(root and self.byFrame[root] or {}) do
            if border:IsShown() then
                if border.rawViews then visit(border, border:GetWidth()*2/55, border:GetHeight()*2/55)
                elseif border.cornerSize then visit(border, border.cornerSize*2/13, border.cornerSize*2/13) end
            end
        end
    end
    panels(frame)
    -- These explicit native children move with their sheet. Their raised
    -- portrait/title plates can extend beyond the main window's rectangle.
    local owner = frame == WorldMapFrame and frame.BorderFrame or frame
    if owner ~= frame then panels(owner) end
    panels(owner and owner.PortraitContainer)
    if frame == GameMenuFrame then panels(frame.Header) end
    if frame == CharacterFrame then
        for _, tab in ipairs(frame.ModeTabs and frame.ModeTabs.Tabs or {}) do
            if tab:IsVisible() then
                visit(tab, 0, 0)
                -- Native contoured side tabs are tinted in place, with no
                -- registered rectangular panel. Include their visible chrome.
                for _, key in ipairs({"Background", "SelectedTexture", "TabGlow", "HighlightTexture"}) do
                    local art = tab[key]
                    if art and art:IsShown() and art:GetAlpha() > 0 then visit(art, 0, 0) end
                end
            end
        end
    end
end

function Skin:FitPanelBackground(texture, border)
    local parentScale = texture:GetParent():GetEffectiveScale()
    -- The fill and every corner/edge share the exact nine-unit inner boundary.
    -- Independent ceil rounding opens a subpixel seam against the corner pieces.
    local inset = border.cornerSize * 9 / 13 * border:GetEffectiveScale() / parentScale
    if texture.SetSnapToPixelGrid then
        texture:SetSnapToPixelGrid(false);texture:SetTexelSnappingBias(0)
    end
    if texture.SetRoundLayoutToNearestPixel then texture:SetRoundLayoutToNearestPixel(false) end
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", border, "TOPLEFT", inset, -inset)
    texture:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", -inset, inset)
end

local function atlasSlice(texture, x1, y1, x2, y2)
    local info = C_Texture.GetAtlasInfo(BORDER_ATLAS)
    if not info then return end
    texture:SetTexture(info.file)
    local left, top = info.leftTexCoord, info.topTexCoord
    local dx = (info.rightTexCoord - left) / 55
    local dy = (info.bottomTexCoord - top) / 55
    texture:SetTexCoord(left + x1 * dx, left + x2 * dx, top + y1 * dy, top + y2 * dy)
    Skin:TintChrome(texture)
end

-- Measured raw-pixel row spans of the four native diamonds, mirrored into
-- local corner coordinates. Disjoint bands remove only their exterior halo;
-- the inward quadrant stays empty and the original material is never repainted.
local cornerSpans = {
    TopLeftCorner = {{4,5,11,12},{5,6,9,13},{6,7,9,14},{7,8,8,15},{8,9,7,16},{9,11,5,26},{11,13,4,26},{13,15,5,26},{15,16,6,26},{16,17,7,26},{17,18,10,26},{18,21,10,18},{21,26,9,18}},
    TopRightCorner = {{5,6,10,13},{6,7,9,13},{7,8,9,14},{8,9,8,15},{9,10,6,26},{10,11,5,26},{11,13,4,26},{13,14,5,26},{14,15,6,26},{15,16,7,26},{16,17,8,26},{17,18,9,26},{18,21,10,18},{21,26,9,18}},
    BottomLeftCorner = {{4,5,11,12},{5,6,10,13},{6,7,9,14},{7,8,8,15},{8,9,7,16},{9,10,6,26},{10,11,5,26},{11,13,4,26},{13,14,5,26},{14,15,6,26},{15,16,7,26},{16,17,8,26},{17,18,9,26},{18,26,9,18}},
    BottomRightCorner = {{5,6,10,13},{6,7,9,13},{7,8,8,14},{8,9,7,15},{9,10,7,26},{10,11,6,26},{11,13,4,26},{13,14,5,26},{14,15,6,26},{15,16,7,26},{16,17,8,26},{17,18,9,26},{18,26,9,18}},
}
-- The native inward elbow contains six gold texels beyond the straight rim.
-- Restore them only on fitted panels; action slots keep their reference contour.
local panelCornerElbows = {{18,19,18,21},{19,20,18,20},{20,21,18,19}}
local function gearBorder(border, size)
    border.cornerSize = size
    local function corner(name, anchor, x1, y1, x2, y2)
        local cap = CreateFrame("Frame", nil, border)
        mouseTransparent(cap)
        cap:SetRoundLayoutToNearestPixel(false)
        cap:SetSize(size, size)
        cap:SetPoint(anchor, border, anchor)
        local top = anchor:find("TOP") ~= nil
        local left = anchor:find("LEFT") ~= nil
        local function drawBand(span)
            local yStart,yEnd,xStart,xEnd=span[1]/2,span[2]/2,span[3]/2,span[4]/2
            local strip=cap:CreateTexture(nil,"BORDER")
            atlasSlice(strip,left and x1+xStart or x2-xEnd,top and y1+yStart or y2-yEnd,
                left and x1+xEnd or x2-xStart,top and y1+yEnd or y2-yStart)
            strip:SetSnapToPixelGrid(false);strip:SetTexelSnappingBias(0)
            strip:SetPoint(anchor,cap,anchor,(left and 1 or -1)*size*xStart/13,
                (top and -1 or 1)*size*yStart/13)
            strip:SetSize(size*(xEnd-xStart)/13,size*(yEnd-yStart)/13)
        end
        for _,span in ipairs(cornerSpans[name]) do drawBand(span) end
        for _,span in ipairs(panelCornerElbows) do drawBand(span) end
        border[name] = cap
        return cap
    end
    local tl = corner("TopLeftCorner", "TOPLEFT", 0, 0, 13, 13)
    local tr = corner("TopRightCorner", "TOPRIGHT", 42, 0, 55, 13)
    local bl = corner("BottomLeftCorner", "BOTTOMLEFT", 0, 42, 13, 55)
    local br = corner("BottomRightCorner", "BOTTOMRIGHT", 42, 42, 55, 55)
    local function edge(name, x1, y1, x2, y2, first, firstPoint, last, lastPoint, vertical)
        local texture = border:CreateTexture(nil, "BORDER")
        atlasSlice(texture, x1, y1, x2, y2)
        texture:SetSnapToPixelGrid(false);texture:SetTexelSnappingBias(0)
        local outer=size*4.5/13
        if vertical then
            local x=firstPoint=="LEFT" and outer or -outer
            texture:SetWidth(size * 4.5 / 13)
            texture:SetPoint("TOP"..firstPoint, first, "BOTTOM"..firstPoint,x,0)
            texture:SetPoint("BOTTOM"..lastPoint, last, "TOP"..lastPoint,x,0)
        else
            local y=firstPoint=="TOP" and -outer or outer
            texture:SetHeight(size * 4.5 / 13)
            texture:SetPoint(firstPoint.."LEFT", first, firstPoint.."RIGHT",0,y)
            texture:SetPoint(lastPoint.."RIGHT", last, lastPoint.."LEFT",0,y)
        end
        border[name] = texture
    end
    -- Only the rim is sampled. The center includes native decorative art and
    -- must never become an extra opaque panel background.
    edge("TopEdge", 13, 4.5, 42, 9, tl, "TOP", tr, "TOP")
    edge("BottomEdge", 13, 46, 42, 50.5, bl, "BOTTOM", br, "BOTTOM")
    edge("LeftEdge", 4.5, 13, 9, 42, tl, "LEFT", bl, "LEFT", true)
    edge("RightEdge", 46, 13, 50.5, 42, tr, "RIGHT", br, "RIGHT", true)
end

-- A small continuous bevel for unit-frame interiors, sampled from the same
-- equipment-slot material. Top/bottom own the corners so no diagonal gaps form.
function Skin:SetUnitOutlineOccluded(frame, active)
    for _,texture in pairs(frame.unitInnerTextures or {}) do texture:SetAlpha(active and 0 or 1) end
    for _,pieces in pairs(frame.unitInnerOcclusionTextures or {}) do
        for _,texture in ipairs(pieces) do texture:SetAlpha(active and 1 or 0) end
    end
end
function Skin:TexturedUnitOutline(frame, width, exclusion)
    local textures=frame.unitInnerTextures
    if not textures then
        textures={}
        frame.unitInnerOcclusionTextures={}
        for _,name in ipairs({'top','bottom','left','right'}) do
            textures[name]=frame:CreateTexture(nil,'OVERLAY')
            frame.unitInnerOcclusionTextures[name]={frame:CreateTexture(nil,'OVERLAY'),frame:CreateTexture(nil,'OVERLAY')}
        end
        frame.unitInnerTextures=textures
    end
    local w,h=frame:GetWidth(),frame:GetHeight()
    if w<=width*2 or h<=width*2 then
        for _,texture in pairs(textures) do texture:Hide() end
        for _,pieces in pairs(frame.unitInnerOcclusionTextures) do for _,texture in ipairs(pieces) do texture:Hide() end end
        return
    end
    local rects={top={0,h-width,w,h},bottom={0,0,w,width},left={0,width,width,h-width},right={w-width,width,w,h-width}}
    local samples={top={13,5,42,9},bottom={13,46,42,50},left={5,13,9,42},right={46,13,50,42}}
    local function place(texture,r,sample)
        texture:ClearAllPoints()
        if r[3]<=r[1] or r[4]<=r[2] then texture:Hide();return end
        texture:SetPoint('BOTTOMLEFT',frame,'BOTTOMLEFT',r[1],r[2])
        texture:SetSize(r[3]-r[1],r[4]-r[2])
        texture:SetSnapToPixelGrid(false);texture:SetTexelSnappingBias(0)
        atlasSlice(texture,unpack(sample))
        texture:SetVertexColor(unpack(Skin.innerBorderColor))
        texture:Show()
    end
    for name,r in pairs(rects) do
        local sample=samples[name]
        place(textures[name],r,sample)
        local pieces=frame.unitInnerOcclusionTextures[name]
        local horizontal=name=='top' or name=='bottom'
        local axis=horizontal and 1 or 2
        local finish=axis+2
        local cut=exclusion and exclusion[1]<r[3] and exclusion[3]>r[1] and exclusion[2]<r[4] and exclusion[4]>r[2]
        local low=cut and math.max(r[axis],exclusion[axis]) or r[finish]
        local high=cut and math.min(r[finish],exclusion[finish]) or r[finish]
        for index,interval in ipairs({{r[axis],low},{high,r[finish]}}) do
            local part={unpack(r)};part[axis],part[finish]=interval[1],interval[2]
            local uv={unpack(sample)}
            local fraction1=(interval[1]-r[axis])/(r[finish]-r[axis])
            local fraction2=(interval[2]-r[axis])/(r[finish]-r[axis])
            if horizontal then
                uv[1]=sample[1]+(sample[3]-sample[1])*fraction1
                uv[3]=sample[1]+(sample[3]-sample[1])*fraction2
            else -- Source V grows down while local UI Y grows up.
                uv[2]=sample[4]-(sample[4]-sample[2])*fraction2
                uv[4]=sample[4]-(sample[4]-sample[2])*fraction1
            end
            place(pieces[index],part,uv)
        end
    end
    self:SetUnitOutlineOccluded(frame,exclusion~=nil)
end

function Skin:StylePanelBackground(texture, border)
    texture:SetVertexColor(1, 1, 1, 1)
    texture:SetColorTexture(PANEL_GREY, PANEL_GREY, PANEL_GREY, PANEL_ALPHA)
    self:FitPanelBackground(texture, border)
end

-- Preserve the source tint/opacity through native bar fades. Icon corners follow
-- the native button scale; normalizing them would make small-cell corners overlap.
local controlBorders, alphaOwners = {}, {}
local function controlAlpha(border)
    local owner = border.alphaOwner
    local alpha = owner:GetAlpha()
    local inherited = alpha > 0 and border.control:GetEffectiveAlpha() / alpha or 0
    local fade = math.min(1, alpha / border.restingAlpha)
    border:SetAlpha(border.baseAlpha * inherited * fade)
    if border.slotFill then border.slotFill:SetAlpha(inherited * fade) end
end
-- Rims are kept per alpha owner, so a fading frame visits only its own.
local function ownRim(border, owner)
    local previous = border.alphaOwner
    if previous and previous ~= owner and alphaOwners[previous] then alphaOwners[previous][border] = nil end
    border.alphaOwner = owner
    local rims = alphaOwners[owner]
    if not rims then
        rims = {}
        alphaOwners[owner] = rims
        hooksecurefunc(owner, "SetAlpha", function() for rim in pairs(rims) do controlAlpha(rim) end end)
    end
    rims[border] = true
end
function Skin:ControlBorder(frame, style, alphaOwner, restingAlpha)
    local existing = self.byFrame[frame] and self.byFrame[frame][style]
    if InCombatLockdown() and not existing then return end
    local border = existing or self:Panel(frame, style, 0)
    border.control = frame
    ownRim(border, alphaOwner or frame)
    border.restingAlpha = restingAlpha or 1
    if not controlBorders[border] then
        controlBorders[border] = true
        border:SetIgnoreParentAlpha(true)
    end
    if not InCombatLockdown() then
        border:SetScale(style == "icon" and 1 or UIParent:GetEffectiveScale() / frame:GetEffectiveScale())
        self:FitPanelBorder(border, frame, styles[style])
    end
    controlAlpha(border)
    return border
end
-- Bag cells share the action slots' fill and baseline-fade compensation.
function Skin:BagSlotFill(border, frame)
    if not border then return end
    local fill=border.slotFill
    if not fill then
        fill=CreateFrame("Frame",nil,frame)
        mouseTransparent(fill)
        fill:SetIgnoreParentAlpha(true)
        fill.texture=fill:CreateTexture(nil,"BACKGROUND")
        fill.texture:SetAllPoints(fill)
        fill.texture:SetColorTexture(PANEL_GREY,PANEL_GREY,PANEL_GREY,PANEL_ALPHA)
        border.slotFill=fill
    end
    self:FitPanelBackground(fill, border)
    fill:SetFrameLevel(math.max(0,frame:GetFrameLevel()-1))
    controlAlpha(border)
    return fill
end

-- Square action cells use the unmodified native atlas, never panel slices.
-- Character slots have37-unit icons on a43-unit pitch under55-unit artwork.
-- Retain native coordinates/scale while excluding the bitmap's exterior black
-- shadow. Each disjoint rectangle maps source to destination at the same scale;
-- unlike panel caps, no corner or straight run is stretched independently.
local rawSlotRects = {{13,4.5,42,9},{13,46,42,50.5},{4.5,13,9,42},{46,13,50.5,42}}
for _,corner in ipairs({
    {"TopLeftCorner",true,true},{"TopRightCorner",false,true},
    {"BottomLeftCorner",true,false},{"BottomRightCorner",false,false},
}) do
    local left,top=corner[2],corner[3]
    for _,span in ipairs(cornerSpans[corner[1]]) do
        local y1,y2,x1,x2=span[1]/2,span[2]/2,span[3]/2,span[4]/2
        rawSlotRects[#rawSlotRects+1]={left and x1 or 55-x2,top and y1 or 55-y2,
            left and x2 or 55-x1,top and y2 or 55-y1}
    end
end
function Skin:RawSlotBorder(frame, alphaOwner, restingAlpha)
    local byStyle=self.byFrame[frame]
    local border=byStyle and byStyle.rawSlot
    if not border then
        border=CreateFrame("Frame",nil,frame)
        mouseTransparent(border)
        border:SetIgnoreParentAlpha(true)
        -- Sparse native-coordinate views omit the opaque center and outer
        -- black halo. They retain the complete measured gold/diamond contour.
        border.rawViews={}
        for _,rect in ipairs(rawSlotRects) do
            local texture=border:CreateTexture(nil,"BACKGROUND")
            atlasSlice(texture,unpack(rect))
            texture:SetSnapToPixelGrid(false);texture:SetTexelSnappingBias(0)
            border.rawViews[#border.rawViews+1]={texture=texture,rect=rect}
        end
        local fill=CreateFrame("Frame",nil,border)
        mouseTransparent(fill)
        fill:SetIgnoreParentAlpha(true)
        fill.texture=fill:CreateTexture(nil,"BACKGROUND")
        fill.texture:SetAllPoints(fill)
        fill.texture:SetColorTexture(PANEL_GREY,PANEL_GREY,PANEL_GREY,PANEL_ALPHA)
        border.slotFill=fill
        border.baseAlpha=BORDER_ALPHA
        border.control=frame
        border.restingAlpha=restingAlpha or 1
        ownRim(border, alphaOwner or frame)
        controlBorders[border]=true
        self.byFrame[frame]=byStyle or {}
        self.byFrame[frame].rawSlot=border
    end
    border:SetPoint("CENTER",frame,"CENTER")
    border:SetSize(frame:GetWidth()*55/43,frame:GetHeight()*55/43)
    border:SetFrameLevel(math.max(0,frame:GetFrameLevel()-1))
    local width,height=border:GetSize()
    for _,view in ipairs(border.rawViews) do
        local r=view.rect
        view.texture:ClearAllPoints()
        view.texture:SetPoint("TOPLEFT",border,"TOPLEFT",width*r[1]/55,-height*r[2]/55)
        view.texture:SetSize(width*(r[3]-r[1])/55,height*(r[4]-r[2])/55)
    end
    border.slotFill:SetPoint("CENTER",border,"CENTER")
    border.slotFill:SetSize(width*37/55,height*37/55)
    border.slotFill:SetFrameLevel(math.max(0,border:GetFrameLevel()-1))
    controlAlpha(border)
    return border
end

hooksecurefunc(UIParent, "SetAlpha", function()
    for border in pairs(controlBorders) do controlAlpha(border) end
end)

-- The background is a region on the control itself, BELOW its art and children.
-- The child frame paints only the border, so it never dims text, icons or maps.
function Skin:Panel(frame, style, fillAlpha)
    if not frame then return end
    style = style or "dialog"
    local byStyle = self.byFrame[frame]
    if byStyle and byStyle[style] then return byStyle[style] end
    local spec = styles[style] or styles.dialog
    local parent = frame
    if spec.paintFit then
        -- Keep a separate decoration host for group fitting, but allow every
        -- equipment-slot corner diamond to paint beyond the cell boundary.
        parent = CreateFrame("Frame", nil, frame)
        mouseTransparent(parent)
        parent:SetAllPoints(frame)
        parent:SetClipsChildren(false)
        parent:SetRoundLayoutToNearestPixel(true)
        parent:SetFrameLevel(frame:GetFrameLevel() + 1)
    end
    local border = CreateFrame("Frame", nil, parent)
    mouseTransparent(border)
    border:SetFrameLevel(parent:GetFrameLevel() + 1)
    border:SetRoundLayoutToNearestPixel(true)
    border.clip = parent ~= frame and parent or nil
    self:FitPanelBorder(border, frame, spec)
    gearBorder(border, spec.edge)
    border.baseAlpha = BORDER_ALPHA
    -- Source M33 black textures use ADD: black contributes no filled pixels.
    border.fillAlpha = fillAlpha == nil and 0 or fillAlpha
    if border.fillAlpha ~= 0 then
        local background = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
        self:FitPanelBackground(background, border)
        background:SetColorTexture(0, 0, 0, border.fillAlpha)
        border.background = background
    end
    border:SetAlpha(border.baseAlpha)
    self.byFrame[frame] = byStyle or {}
    self.byFrame[frame][style] = border
    self.panels[#self.panels + 1] = border
    return border
end

-- The same equipment-slot top bevel supplies section rules.
function Skin:Divider(parent, width)
    local line = parent:CreateTexture(nil, "BORDER")
    atlasSlice(line, 13, 4.5, 42, 9)
    line:SetAlpha(BORDER_ALPHA)
    line:SetHeight(4.5)
    line.paintCenter = 2.25
    self:SizeDivider(line, width)
    return line
end
function Skin:SizeDivider(line, width)
    line:SetWidth(width)
end

local function hide(object)
    if object and object.Hide then object:Hide() end
end

-- Hide only source-retired art/controls, keeping native owners and scripts.
-- Reappearance from native events is suppressed without replacing Show methods.
local function conceal(object)
    if not object then return end
    if object.GetObjectType and object:GetObjectType() == "Texture" then
        object:SetAlpha(0)
        return
    end
    object:Hide()
    if object.HookScript and not object.squancherConcealed then
        object.squancherConcealed = true
        object:HookScript("OnShow", function(self) self:Hide() end)
    end
end

local function tintHeader(header)
    if not header then return end
    if ns.NativeText then ns.NativeText:Header(header.Text,10) end
    -- Native headers keep their text, collapse/filter controls and layout.
    -- A thin Quests rule separates the expanded list without boxing each entry.
    -- Native AddAnim restores alpha to1; hide the art so it cannot repaint the slab.
    if header.Background then header.Background:Hide() end
    if not ObjectiveTrackerFrame or header ~= ObjectiveTrackerFrame.Header then
        if header.squancherDarkHeader then header.squancherDarkHeader:Hide() end
        if QuestObjectiveTracker and header == QuestObjectiveTracker.Header then
            if not header.squancherSectionDivider then
                local line = Skin:Divider(header, header:GetWidth() + 31)
                line:SetHeight(4)
                line:SetPoint("TOPLEFT", header, "BOTTOMLEFT", -28, 4 * 7 / 28)
                header.squancherSectionDivider = line
                if type(header.SetCollapsed) == "function" then
                    hooksecurefunc(header, "SetCollapsed", function(_, collapsed)
                        line:SetShown(not collapsed)
                    end)
                end
            end
            Skin:SizeDivider(header.squancherSectionDivider, header:GetWidth() + 31)
            header.squancherSectionDivider:SetShown(not header.isCollapsed)
        end
        return
    end
    if not header.squancherDarkHeader then
        local line = Skin:Divider(header, header:GetWidth() + 35)
        line:SetPoint("TOPLEFT", header, "BOTTOMLEFT", -30, line.paintCenter)
        header.squancherDarkHeader = line
    end
    Skin:SizeDivider(header.squancherDarkHeader, header:GetWidth() + 35)
    -- Align the primary title with the fitted shell's left padding.
    header.Text:ClearAllPoints()
    header.Text:SetPoint("LEFT", header, "LEFT", -23, 0)
    local minimize = header.MinimizeButton
    if minimize and not minimize.squancherTinted then
        minimize.squancherTinted = true
        local function tintControl()
            for _, getter in ipairs({"GetNormalTexture", "GetPushedTexture", "GetHighlightTexture"}) do
                local texture = minimize[getter](minimize)
                if texture then texture:SetDesaturated(true); texture:SetVertexColor(0.85, 0.85, 0.85) end
            end
        end
        hooksecurefunc(minimize, "SetNormalAtlas", tintControl)
        hooksecurefunc(minimize, "SetPushedAtlas", tintControl)
        tintControl()
    end
end

local function tintTrackerBlocks(module)
    -- Native quest gutters and indentation stay intact inside one fitted shell.
    -- A separate rectangle around every title/objective made nested boxes collide.
    tintHeader(module.Header)
    for _,blocks in pairs(module.usedBlocks or {}) do
        for _,block in pairs(blocks) do
            if ns.NativeText then ns.NativeText:Header(block.HeaderText,module == QuestObjectiveTracker and 8 or 9) end
            -- Native title links remain; omit the oversized map-navigation orb.
            local poi=block.poiButton
            if poi then poi:SetAlpha(0) end
        end
    end
end

function Skin:FitTracker()
    local tracker = ObjectiveTrackerFrame
    local drawer = ns.QuestDrawer
    if drawer and drawer.ready and not drawer.fitting then drawer:RequestLayout(); return end
    if tracker and ns.LayoutTargets and not (drawer and drawer.ready) and not InCombatLockdown() then
        ns.LayoutTargets:ApplyScale("quest_tracker", tracker)
    end
    if not tracker or not tracker.Header then return end
    if drawer and drawer.ready then
        tracker.Header:Hide()
    else
        tintHeader(tracker.Header)
    end
    for _,module in ipairs(tracker.modules or {}) do tintTrackerBlocks(module) end
    if not self.questFrame then
        local shell = CreateFrame("Frame", nil, tracker)
        mouseTransparent(shell)
        self:Panel(shell, "compact", 0)
        -- Draw on the tracker beneath its native content, not on the raised rim.
        -- Use the exact same color/opacity as the chat panel, including in combat.
        local background = tracker:CreateTexture(nil, "BACKGROUND", nil, -8)
        background:SetAllPoints(shell)
        background:SetColorTexture(PANEL_GREY, PANEL_GREY, PANEL_GREY, PANEL_ALPHA)
        self.questBackground = background
        self.questFrame = shell
    end
    local bottom = tracker.Header
    if not tracker:IsCollapsed() then
        for _, module in ipairs(tracker.modules or {}) do
            if module:IsShown() and module:GetContentsHeight() > 0 then bottom = module end
        end
    end
    local shell = self.questFrame
    shell:ClearAllPoints()
    -- Match the native container's authored -30/+5 content gutters: quest POI
    -- buttons extend left of HeaderText and must sit inside the decorative rim.
    -- Extra right room also keeps collapse/filter controls clear of its corners.
    if drawer and drawer.ready then
        shell:SetPoint("TOPLEFT", drawer.frame, "TOPLEFT", 0, 0)
        shell:SetPoint("TOPRIGHT", drawer.frame, "TOPRIGHT", 0, 0)
    else
        shell:SetPoint("TOPLEFT", tracker.Header, "TOPLEFT", -30, 0)
        shell:SetPoint("TOPRIGHT", tracker.Header, "TOPRIGHT", 5, 0)
    end
    local bottomPadding = drawer and drawer.ready and drawer.contentPadding or 12
    shell:SetPoint("BOTTOM", bottom, "BOTTOM", 0, -bottomPadding)
    self:FitPanelBackground(self.questBackground, self.byFrame[shell].compact)
    if tracker.Header.squancherDarkHeader then
        tracker.Header.squancherDarkHeader:SetShown(not (drawer and drawer.ready) and not tracker:IsCollapsed())
    end
    if tracker.NineSlice then tracker.NineSlice:SetAlpha(0) end
end

function Skin:Tracker()
    if ns.NativeText then ns.NativeText:Tracker(ObjectiveTrackerFrame) end
    local tracker = ObjectiveTrackerFrame
    if not tracker then return end
    tintHeader(tracker.Header)
    local names = { "ScenarioObjectiveTracker", "UIWidgetObjectiveTracker",
        "CampaignQuestObjectiveTracker", "QuestObjectiveTracker", "AdventureObjectiveTracker",
        "AchievementObjectiveTracker", "MonthlyActivitiesObjectiveTracker",
        "ProfessionsRecipeTracker", "BonusObjectiveTracker", "WorldQuestObjectiveTracker",
        "InitiativeTasksObjectiveTracker" }
    for _, name in ipairs(names) do
        local module = _G[name]
        if module then
            tintHeader(module.Header)
            tintTrackerBlocks(module)
            if module.EndLayout and not module.squancherDarkBlocksHooked then
                module.squancherDarkBlocksHooked = true
                hooksecurefunc(module, "EndLayout", tintTrackerBlocks)
            end
        end
    end
    if not self.trackerFitHooked then
        self.trackerFitHooked = true
        hooksecurefunc(tracker, "Update", function() Skin:FitTracker() end)
    end
    self:FitTracker()
    if Menu and Menu.ModifyMenu and not self.questContextMenuHooked then
        self.questContextMenuHooked = true
        Menu.ModifyMenu("MENU_QUEST_OBJECTIVE_TRACKER", function(_, rootDescription)
            rootDescription:AddMenuAcquiredCallback(function(menuFrame)
                Skin:Panel(menuFrame, "compact", 0):Show()
            end)
            rootDescription:AddMenuReleasedCallback(function(menuFrame)
                local panels = Skin.byFrame[menuFrame]
                if panels and panels.compact then panels.compact:Hide() end
            end)
        end)
    end
end

function Skin:RaisedPlate(frame, style)
    local border = self:Panel(frame, style or "inner", 0)
    if border.raisedPaint then return border.raisedPaint, border end
    local face = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    face:SetTexture(WHITE)
    self:FitPanelBackground(face, border)
    local edges = {}
    for _, side in ipairs({"TOP", "LEFT", "BOTTOM", "RIGHT"}) do
        local edge = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
        if side == "TOP" or side == "BOTTOM" then
            edge:SetPoint(side.."LEFT", face, side.."LEFT")
            edge:SetPoint(side.."RIGHT", face, side.."RIGHT")
        else
            edge:SetPoint("TOP"..side, face, "TOP"..side)
            edge:SetPoint("BOTTOM"..side, face, "BOTTOM"..side)
        end
        edges[side] = edge
    end
    local stateEnabled, statePressed, stateHovered = true, false, false
    local function paint(enabled, pressed, hovered)
        stateEnabled, statePressed, stateHovered = enabled, pressed, hovered
        local pixel = PixelUtil.GetPixelToUIUnitFactor() / frame:GetEffectiveScale()
        local top, bottom = 0.17, 0.055
        if not enabled then top, bottom = 0.09, 0.045
        elseif pressed then top, bottom = 0.045, 0.12
        elseif hovered then top, bottom = 0.23, 0.085 end
        face:SetGradient("VERTICAL", CreateColor(bottom, bottom, bottom, 1),
            CreateColor(top, top, top, 1))
        local gold = enabled and (hovered and 1 or 0.70 / BORDER_R) or 0.30 / BORDER_R
        for side, edge in pairs(edges) do
            if side == "TOP" or side == "BOTTOM" then edge:SetHeight(2 * pixel)
            else edge:SetWidth(2 * pixel) end
            local lit = side == "TOP" or side == "LEFT"
            if pressed then lit = not lit end
            if lit then edge:SetColorTexture(BORDER_R * gold, BORDER_G * gold, BORDER_B * gold, 1)
            else edge:SetColorTexture(0.025, 0.022, 0.018, 1) end
        end
    end
    border.raisedPaint, border.raisedFace, border.raisedEdges = paint, face, edges
    frame:HookScript("OnSizeChanged", function() paint(stateEnabled, statePressed, stateHovered) end)
    paint(true, false, false)
    return paint, border
end

function Skin:RaisedButton(button, style)
    local paint, border = self:RaisedPlate(button, style)
    if border.raisedButton then return border end
    border.raisedButton = true
    local hovered, down = false, false
    local function refresh()
        local enabled = button:IsEnabled()
        paint(enabled, enabled and (down or button:GetButtonState() == "PUSHED"), enabled and hovered)
    end
    button:HookScript("OnEnter", function() hovered = true; refresh() end)
    button:HookScript("OnLeave", function() hovered = false; refresh() end)
    button:HookScript("OnMouseDown", function(_, mouse) if mouse == "LeftButton" then down = true; refresh() end end)
    button:HookScript("OnMouseUp", function() down = false; refresh() end)
    button:HookScript("OnEnable", refresh)
    button:HookScript("OnDisable", function() down = false; refresh() end)
    button:HookScript("OnShow", function() hovered, down = false, false; refresh() end)
    button:HookScript("OnHide", function() hovered, down = false, false end)
    hooksecurefunc(button, "SetButtonState", refresh)
    if button.GetHighlightTexture then
        local highlight = button:GetHighlightTexture()
        if highlight then highlight:SetColorTexture(1, 0.78, 0.42, 0.04) end
    end
    refresh()
    return border
end

local function menuButton(button)
    if ns.NativeText then ns.NativeText:Frame(button) end
    if button.squancherDarkMenu then return end
    button.squancherDarkMenu = true
    -- ThreeSlice updates its atlas on every state change; keep only native input.
    hide(button.Left); hide(button.Center); hide(button.Right)
    Skin:RaisedButton(button, "compact")
end

function Skin:Menu()
    local menu = GameMenuFrame
    if not menu then return end
    if ns.NativeText and menu.Header then
        for _, region in ipairs({menu.Header:GetRegions()}) do
            if region.IsObjectType and region:IsObjectType("FontString") then ns.NativeText:Header(region) end
        end
    end
    if not menu.squancherDarkMenu then
        menu.squancherDarkMenu = true
        hide(menu.Border); hide(menu.NineSlice)
        -- Keep native title text above a raised charcoal and gold title plate.
        if menu.Header and menu.Header.GetRegions then
            for _, region in ipairs({menu.Header:GetRegions()}) do
                if region.GetObjectType and region:GetObjectType() == "Texture" then
                    hide(region)
                end
            end
            self:RaisedPlate(menu.Header, "compact")
        end
        local border = self:Panel(menu, "dialog", 0)
        -- Match the translucent chat/quest body; raised controls own their faces.
        local background = menu:CreateTexture(nil, "BACKGROUND", nil, -8)
        self:StylePanelBackground(background, border)
        self.menuBackground = background
        menu:HookScript("OnShow", function() Skin:Menu() end)
        if menu.AddButton then
            hooksecurefunc(menu, "AddButton", function() Skin:Menu() end)
        end
    end
    if menu.buttonPool and menu.buttonPool.EnumerateActive then
        for button in menu.buttonPool:EnumerateActive() do menuButton(button) end
    else
        for _, button in ipairs({menu:GetChildren()}) do
            if button.GetObjectType and button:GetObjectType() == "Button" then menuButton(button) end
        end
    end
end

function Skin:Minimap()
    local map = Minimap
    if not map then return end
    -- These are the exact native extras suppressed by the former map owner.
    for _, name in ipairs({"GameTimeFrame", "TimeManagerClockButton", "MiniMapMailBorder",
        "MinimapNorthTag", "MiniMapWorldMapButton", "MinimapZoneTextButton",
        "MinimapCompassTexture", "MinimapCompassTextureUnderlay", "MinimapBorder", "MinimapBorderTop"}) do
        conceal(_G[name])
    end
    conceal(map.ZoomIn); conceal(map.ZoomOut)
    local cluster = MinimapCluster
    if cluster then
        conceal(cluster.ZoneTextButton); conceal(cluster.DielFrame)
        if cluster.MinimapContainer then conceal(cluster.MinimapContainer.PlayerCoords) end
    end
    -- Formerly anchored to the calendar at the screen's top right; source
    -- compartment placement is the map's RIGHT, offset(-5,+10), size18.
    local compartment = AddonCompartmentFrame
    if compartment and not self.compartmentPlaced then
        self.compartmentPlaced = true
        compartment:SetParent(map)
        compartment:ClearAllPoints()
        compartment:SetPoint("RIGHT", map, "RIGHT", -5, 10)
        compartment:SetSize(18,18)
        compartment:SetFrameStrata("MEDIUM"); compartment:SetFrameLevel(20)
        if compartment.Text then
            compartment.Text:SetFont(ns.Media:Resolve("font","Expressway"),13,"")
            compartment.Text:SetShadowColor(0,0,0,1); compartment.Text:SetShadowOffset(1,-1)
        end
    end
    if self.minimapPlaced then return end
    self.minimapPlaced = true
    map:SetParent(UIParent)
    map:ClearAllPoints()
    -- Current saved runtime geometry, anchored relative to the bottom-centre.
    -- UI units inherit the current scale. These are never physical-screen pixels.
    map:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", 434.86669921875, 81.0667037963867)
    map:SetSize(174.933349609375, 174.933349609375)
    map:SetMaskTexture(WHITE)
    local rim = self:Panel(map, "minimap", 0)
    rim:SetFrameStrata("BACKGROUND")
    hide(MinimapBorder); hide(MinimapBorderTop)
    hide(MinimapCompassTexture); hide(MinimapCompassTextureUnderlay)
    if cluster then
        hide(cluster.ZoneTextButton)
        if cluster.MinimapContainer then
            -- Remove the empty native container's hit area; the map owns input.
            cluster.MinimapContainer:EnableMouse(false)
        end
        cluster:EnableMouse(false)
        if cluster.IndicatorFrame then
            cluster.IndicatorFrame:SetParent(map)
            cluster.IndicatorFrame:ClearAllPoints()
            cluster.IndicatorFrame:SetPoint("TOPRIGHT", map, "TOPRIGHT", 3, 4)
        end
        -- Keep the tracking menu reachable on the square map.
        if cluster.Tracking then
            cluster.Tracking:SetParent(map)
            cluster.Tracking:ClearAllPoints()
            cluster.Tracking:SetPoint("BOTTOMLEFT", map, "BOTTOMLEFT", 3, 3)
            cluster.Tracking:SetScale(1.2)
        end
    end
    -- The active runtime has calendar.hide=true; do not reintroduce it.
    hide(GameTimeFrame)
    -- Conventional minimap shape hint for native-compatible addon launchers.
    if not GetMinimapShape then
        _G.GetMinimapShape = function() return "SQUARE" end
    end

end

local function stripRegions(owner)
    if not owner or not owner.GetRegions then return end
    for _,region in ipairs({owner:GetRegions()}) do
        if region.GetObjectType and region:GetObjectType()=="Texture" then region:SetAlpha(0) end
    end
end

-- Native hover fades explicitly raise these textures' alpha. Hide the retired
-- chrome rather than fighting its fade; the custom panel remains the fill owner.
local hiddenChatChrome = setmetatable({}, {__mode="k"})
local function hideNativeChatChrome(chat)
    local name = chat:GetName()
    for _, suffix in ipairs(CHAT_FRAME_TEXTURES or {}) do
        local region = chat[suffix] or _G[name..suffix]
        if region and region.IsObjectType and region:IsObjectType("Texture") then
            if UIFrameFadeRemoveFrame then UIFrameFadeRemoveFrame(region) end
            region:Hide()
            if not hiddenChatChrome[region] then
                hiddenChatChrome[region] = true
                hooksecurefunc(region, "Show", function(self) self:Hide() end)
            end
        end
    end
end

local function nativeTabAlpha(chat)
    local name=chat and chat.GetName and chat:GetName()
    if not name or not name:match("^ChatFrame%d+$") then return end
    local tab=_G[name.."Tab"]
    if not tab then return end
    local selected=not chat.isDocked or (GeneralDockManager and FCFDock_GetSelectedWindow
        and chat==FCFDock_GetSelectedWindow(GeneralDockManager))
    local alpha=selected and 1 or .6
    -- Native per-tab storage isolates this presentation write from later secure
    -- readers. Both hover endpoints match the original always-readable tab style.
    if UIFrameFadeRemoveFrame then UIFrameFadeRemoveFrame(tab) end
    if ChatFrameUtil and ChatFrameUtil.SetTabAlphas then ChatFrameUtil.SetTabAlphas(tab,alpha,alpha) end
    tab:SetAlpha(alpha)
end

local chatTabPlates = {}
local function chatBorderWidth(frame)
    return 2 * PixelUtil.GetPixelToUIUnitFactor() / frame:GetEffectiveScale()
end
-- The compact panel rim is a scale-1 child of the chat panel, so its painted
-- inner boundary (FitPanelBackground's 9/13 rule) is constant in panel units.
local function chatInnerInset()
    return styles.compact.edge * 9 / 13 - styles.compact.offset
end
local function fitChatTabBorder(tab, state)
    local border = state.border
    -- Blizzard reparents docked tabs. Keep their rim above the native face.
    border:SetFrameStrata(tab:GetFrameStrata())
    border:SetFrameLevel(tab:GetFrameLevel()+1)
    -- Docked on the panel, the panel rim is the General tab's left edge; only
    -- an undocked General tab needs its own.
    if tab==ChatFrame1Tab then state.joinedLeft=state.docked and Skin.chatDockPlaced and true or false end
    local width = chatBorderWidth(tab)
    border.raisedFace:ClearAllPoints()
    border.raisedFace:SetPoint("TOPLEFT", tab, "TOPLEFT", state.joinedLeft and 0 or width, -width)
    border.raisedFace:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -width, width)
    -- Full-width top/bottom own the corners; one right edge owns each seam.
    for _, side in ipairs({"Top", "Bottom"}) do
        local edge = border[side.."Edge"]
        if side == "Top" then atlasSlice(edge, 13, 5, 42, 9)
        else atlasSlice(edge, 13, 46, 42, 50) end
        edge:ClearAllPoints()
        edge:SetPoint(side:upper().."LEFT", tab, side:upper().."LEFT")
        edge:SetPoint(side:upper().."RIGHT", tab, side:upper().."RIGHT")
        edge:SetHeight(width)
        -- The dock's single continuous rule owns every docked tab bottom.
        edge:SetShown(side ~= "Bottom" or not state.docked)
    end
    for _, side in ipairs({"Left", "Right"}) do
        local edge = border[side.."Edge"]
        -- The native left slice collapses to shadow at two physical pixels.
        -- Use the visible right bevel on both sides of these thin tab rims.
        atlasSlice(edge, 46, 13, 50, 42)
        local inset = side == "Left" and 0 or -width
        edge:ClearAllPoints()
        edge:SetPoint("TOPLEFT", tab, "TOP"..side:upper(), inset, -width)
        edge:SetPoint("BOTTOMLEFT", tab, "BOTTOM"..side:upper(), inset, width)
        edge:SetWidth(width)
        edge:SetShown(side == "Right" or not state.joinedLeft)
    end
end
local function nativeTabStyle(tab, selected, joinedLeft)
    local name=tab and tab.GetName and tab:GetName()
    if not name or not name:match("^ChatFrame%d+Tab$") or not tab.Text then return end
    for _,state in ipairs({"","Selected","Active","Highlight"}) do
        for _,side in ipairs({"Left","Middle","Right"}) do
            local region=tab[state..side] or _G[name..state..side]
            if region then region:SetAlpha(0) end
        end
    end
    tab.Text:SetFont(ns.Media:Resolve("font","Bui Homizio"),10,"OUTLINE")
    tab:SetHeight(22)
    tab.Text:ClearAllPoints();tab.Text:SetPoint("CENTER",tab,"CENTER",0,-1)
    local state = chatTabPlates[tab]
    if not state then
        local paint, border = Skin:RaisedPlate(tab, "inner")
        state = { selected=false, hovered=false, down=false, border=border }
        chatTabPlates[tab] = state
        for _, edge in pairs(border.raisedEdges) do edge:Hide() end
        for _, corner in ipairs({"TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner"}) do
            border[corner]:Hide()
        end
        tab:HookScript("OnSizeChanged", function() fitChatTabBorder(tab, state) end)
        local function refresh()
            local enabled = tab:IsEnabled()
            paint(enabled, enabled and (state.selected or state.down), enabled and state.hovered)
        end
        state.refresh = refresh
        tab:HookScript("OnEnter", function() state.hovered=true;refresh() end)
        tab:HookScript("OnLeave", function() state.hovered=false;state.down=false;refresh() end)
        tab:HookScript("OnMouseDown", function(_, mouse) if mouse=="LeftButton" then state.down=true;refresh() end end)
        tab:HookScript("OnMouseUp", function() state.down=false;refresh() end)
        tab:HookScript("OnDragStop", function() state.down=false;refresh() end)
        tab:HookScript("OnShow", function() state.hovered=false;state.down=false;refresh() end)
        tab:HookScript("OnHide", function() state.hovered=false;state.down=false end)
        tab:HookScript("OnEnable", refresh)
        tab:HookScript("OnDisable", refresh)
    end
    if joinedLeft ~= nil then state.joinedLeft = joinedLeft end
    local chat = _G[name:sub(1, -4)]
    state.docked = chat and chat.isDocked and Skin.chatTabDivider ~= nil
    if not chat or not chat.isDocked then state.joinedLeft = false end
    state.selected = selected and true or false
    state.refresh()
    fitChatTabBorder(tab, state)
    local title=FCF_GetChatWindowInfo and FCF_GetChatWindowInfo(tab:GetID())
    if not title or issecretvalue and issecretvalue(title) then return end
    -- The raised face carries selection; native docking, alerts and input stay intact.
    tab.Text:SetText(title)
    if selected then tab.Text:SetTextColor(1,1,1) else tab.Text:SetTextColor(BORDER_R,BORDER_G,BORDER_B) end
end

-- Native dynamic tabs use an extra -1 offset and resize after the color hook.
-- Keep native widths/order/scrolling, then align the whole row and its labels.
function Skin:AlignChatTabs(dock)
    if dock ~= GeneralDockManager or not self.chatDockPlaced then return end
    local scroll = dock.scrollFrame
    local child = scroll and scroll:GetScrollChild()
    if not child then return end
    for i = 1, scroll:GetNumPoints() do
        local point, relative, relativePoint, x = scroll:GetPoint(i)
        if point == "BOTTOMRIGHT" then
            scroll:SetPoint(point, relative, relativePoint, x, 0)
            break
        end
    end
    scroll:SetHeight(22);child:SetHeight(22)
    local lastStatic, lastDynamic
    local hasStatic = false
    for _, chat in ipairs(dock.DOCKED_CHAT_FRAMES or {}) do
        if chat.isStaticDocked then hasStatic = true;break end
    end
    local selected = FCFDock_GetSelectedWindow(dock)
    for _, chat in ipairs(dock.DOCKED_CHAT_FRAMES or {}) do
        local tab = _G[chat:GetName().."Tab"]
        if tab then
            local joined
            if chat.isStaticDocked then
                joined = lastStatic ~= nil
                if lastStatic then
                    tab:SetPoint("LEFT", lastStatic, "RIGHT", 0, 0)
                else
                    -- The primary tab starts exactly on the dock's left edge,
                    -- which is the panel rim's painted inner boundary.
                    for i = 1, tab:GetNumPoints() do
                        local point, relative, relativePoint, _, y = tab:GetPoint(i)
                        if relative == dock and point:find("LEFT") then
                            tab:SetPoint(point, relative, relativePoint, 0, y)
                            break
                        end
                    end
                end
                -- The first tab sits on the panel rim, which is its left edge:
                -- its own left line would double it with a dark pixel between.
                joined = true
                lastStatic = tab
            else
                joined = lastDynamic ~= nil or hasStatic
                tab:SetPoint("LEFT", lastDynamic or child, lastDynamic and "RIGHT" or "LEFT", 0, 0)
                lastDynamic = tab
            end
            nativeTabStyle(tab, chat == selected, joined)
        end
    end
    -- The voice control follows the last tab; nothing else anchors to it.
    local voice = ChatFrameChannelButton
    local last = dock.overflowButton and dock.overflowButton:IsShown() and dock.overflowButton or lastDynamic or lastStatic
    if voice and voice.squancherPinned and last then
        voice:ClearAllPoints()
        voice:SetPoint("LEFT", last, "RIGHT", 2, 0)
    end
end

-- Header icon strip: micro buttons, then Friends, ending on the panel rim's
-- inner right boundary. The panel's top rim, right rim and tab divider are its
-- outer edges; each cell owns only one thin seam on its left, drawn with the
-- chat tabs' seam slice and thickness. NativeActionBars supplies cell widths
-- in panel units, from the right rim leftward.
function Skin:FitChatIconStrip(widths)
    local strip = self.chatIconStrip
    if not strip then return end
    local width = chatBorderWidth(strip)
    local x = 0
    for index, cell in ipairs(widths) do
        x = x + cell
        local seam = strip.seams[index]
        if not seam then
            seam = strip:CreateTexture(nil, "BORDER")
            atlasSlice(seam, 46, 13, 50, 42)
            seam:SetAlpha(BORDER_ALPHA)
            strip.seams[index] = seam
        end
        seam:ClearAllPoints()
        -- End on the divider's upper edge so the junction is not doubled.
        seam:SetPoint("TOPLEFT", strip, "TOPRIGHT", -x, 0)
        seam:SetPoint("BOTTOMLEFT", strip, "BOTTOMRIGHT", -x, width * .5)
        seam:SetWidth(width)
        seam:Show()
    end
    for index = #widths + 1, #strip.seams do strip.seams[index]:Hide() end
    strip:SetWidth(math.max(1, x))
end

-- Friends is the strip's last cell: a micro-button-sized cell with no chrome
-- of its own. Native click, tooltip, count and toasts stay with the button.
function Skin:PinChatFriends(width, height, cellScale)
    local friends, strip = QuickJoinToastButton, self.chatIconStrip
    if not friends or not strip or friends.squancherPinning then return end
    if InCombatLockdown() then self.pending = true; return end
    if width then self.chatIconCell = { width, height, cellScale } end
    local cell = self.chatIconCell or { 32, 40, 0.5 }
    friends.squancherPinning = true
    friends:SetParent(self.chatPanel);friends:ClearAllPoints()
    friends:SetSize(cell[1], cell[2]);friends:SetScale(cell[3])
    friends:SetPoint("RIGHT", strip, "RIGHT")
    friends:SetFrameStrata("LOW")
    friends:SetFrameLevel(self.chatPanel:GetFrameLevel() + 8)
    friends.squancherPinning = nil
    self:FitChatToasts()
end

-- Friend-online and quick-join toasts sit as one compact strip on the chat
-- panel's top edge: 70% of native size, painted rims aligned with the panel's
-- left rim and a 2-unit gap above its top rim. Native icon, text, click, sound
-- and fade animations stay with the toast; only its anchor, scale and chrome
-- change. DIALOG (BNToastFrame's native strata) keeps the transient toast
-- above any drawer window opened on the same edge.
local CHAT_TOAST_SCALE, CHAT_TOAST_GAP, CHAT_TOAST_TEXT = 0.7, 2, 8
function Skin:FitChatToast(toast)
    local panel = self.chatPanel
    if not toast or not panel or toast.squancherToastFitting then return end
    toast.squancherToastFitting = true
    local parent = toast:GetParent() or UIParent
    local panelScale, parentScale = panel:GetEffectiveScale(), parent:GetEffectiveScale()
    local width = toast:GetWidth()
    local scale = CHAT_TOAST_SCALE
    if width > 0 then scale = math.min(scale, panel:GetWidth() / width) end
    toast:SetScale(scale * panelScale / parentScale)
    local ratio = panelScale / toast:GetEffectiveScale()
    -- Quick-join toasts are permanently shown frames whose own art fades in and
    -- out; a rim and fill on them would sit above the chat as an empty box.
    if toast ~= BNToastFrame then
        toast:SetFrameStrata("DIALOG")
        toast:ClearAllPoints()
        toast:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 0, CHAT_TOAST_GAP * ratio)
        toast.squancherToastFitting = nil
        return
    end
    local border = self:Panel(toast, "compact", 0)
    -- The rim keeps the panel's own thickness instead of shrinking with the toast.
    border:SetScale(ratio)
    self:FitPanelBorder(border, toast, styles.compact)
    if not toast.squancherToastFill then
        toast.squancherToastFill = toast:CreateTexture(nil, "BACKGROUND", nil, -8)
        if toast.NineSlice then toast.NineSlice:SetAlpha(0) end
        if toast.GetBackdrop and toast:GetBackdrop() then
            toast:SetBackdropColor(0, 0, 0, 0);toast:SetBackdropBorderColor(0, 0, 0, 0)
        end
        if toast.Background then toast.Background:SetAlpha(0) end
        local name = toast:GetName()
        local glow = toast.glowFrame or name and _G[name .. "GlowFrame"]
        if glow then glow:SetAlpha(0) end
    end
    self:StylePanelBackground(toast.squancherToastFill, border)
    -- Body text keeps at least the shared 8-unit size after scaling.
    local floor = CHAT_TOAST_TEXT * ratio
    for _, region in ipairs({ toast:GetRegions() }) do
        if region:GetObjectType() == "FontString" then
            local file, size, flags = region:GetFont()
            if file and size and size < floor - 0.01 then region:SetFont(file, floor, flags) end
        end
    end
    toast:SetFrameStrata("DIALOG")
    -- Both rims paint (edge*2/13 - offset) outside their frames, in panel units.
    local paint = styles.compact.offset - styles.compact.edge * 2 / 13
    toast:ClearAllPoints()
    toast:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 0, (2 * paint + CHAT_TOAST_GAP) * ratio)
    toast.squancherToastFitting = nil
end

function Skin:FitChatToasts()
    local friends = QuickJoinToastButton
    -- Any of these may be absent on this client; a table would stop at a gap.
    local function own(toast)
        if type(toast) ~= "table" or not toast.SetPoint then return end
        if not toast.squancherToastHooked then
            toast.squancherToastHooked = true
            local function fit() Skin:FitChatToast(toast) end
            -- Blizzard's UpdateAnchor and toast animations re-anchor via SetPoint.
            hooksecurefunc(toast, "SetPoint", fit)
            toast:HookScript("OnShow", fit)
        end
        self:FitChatToast(toast)
    end
    own(BNToastFrame)
    if friends then own(friends.Toast);own(friends.Toast2) end
end

-- Rename the existing primary window once; its normal conversation/reward
-- subscriptions and native zone channels already form the desired General view.
function Skin:ConfigureGeneralChat()
    local settings=SquanchOnDB
    local character=UnitGUID("player")
    if not settings or not character or not ChatFrame1 or InCombatLockdown() then return end
    settings.generalChat20261110=settings.generalChat20261110 or {}
    if settings.generalChat20261110[character] then return end
    local before=GetChatWindowInfo(1)
    if before~="G, S & W" then return end
    local record={before=before,after=GENERAL or "General",groups={}}
    for _,group in pairs(ChatFrame1.messageTypeList or {}) do
        record.groups[#record.groups+1]=group
    end
    FCF_SetWindowName(ChatFrame1,record.after)
    -- The observed extra General window has no subscriptions. Close it only
    -- after confirming it also has no history; preserve any history as Archive.
    local duplicate=ChatFrame4
    if duplicate and not duplicate.isTemporary and GetChatWindowInfo(4)==record.after
        and type(duplicate.messageTypeList)=="table" and not next(duplicate.messageTypeList)
        and type(duplicate.channelList)=="table" and not next(duplicate.channelList)
        and type(duplicate.zoneChannelList)=="table" and not next(duplicate.zoneChannelList) then
        record.duplicate={before=record.after,docked=duplicate.isDocked and true or false}
        if duplicate:GetNumMessages()==0 then
            FCF_Close(duplicate)
            record.duplicate.action="closed_empty"
        else
            FCF_SetWindowName(duplicate,"Archive")
            record.duplicate.action="renamed_archive"
        end
    end
    settings.generalChat20261110[character]=record
    if GeneralDockManager then FCFDock_UpdateTabs(GeneralDockManager,true) end
end

function Skin:Chat()
    self:ConfigureGeneralChat()
    local settings=SquanchOnDB
    if settings and settings.chatTimestampRestored~=2 then
        -- Native formatter uses this string verbatim; source brackets and its
        -- custom RGB(.7,.7,.7) colour are literal parts of the format.
        C_CVar.SetCVar("showTimestamps", "|cffb2b2b2[%H:%M]|r ")
        settings.chatTimestampRestored=2
    end
    if not self.chatCompactPrefixInstalled and ChatFrameUtil and ChatFrameUtil.ResolvePrefixedChannelName then
        self.chatCompactPrefixInstalled=true
        local resolve=ChatFrameUtil.ResolvePrefixedChannelName
        -- This helper supplies display text only. Native MessageFormatter keeps
        -- the actual channel hyperlink ID, message/event owner and metadata.
        ChatFrameUtil.ResolvePrefixedChannelName=function(channel)
            if type(channel)=="string" and (not issecretvalue or not issecretvalue(channel)) then
                local number=channel:match("^([1-9]%d*)%. ")
                if number then return number end
            end
            return resolve(channel)
        end
    end
    if not ChatFrame1 then return end
    if not self.chatPlaced then
        self.chatPlaced=true
        local panel=CreateFrame("Frame","SquancherChatPanel",UIParent)
        panel:SetFrameStrata("BACKGROUND");panel:SetFrameLevel(300)
        mouseTransparent(panel)
        panel:SetPoint("BOTTOMLEFT",UIParent,"BOTTOM",-783.3333740234375,30)
        panel:SetSize(349.86669921875,174.933349609375)
        self.chatPanel=panel
        local fill=panel:CreateTexture(nil,"BACKGROUND",nil,-8)
        fill:SetAllPoints(panel)
        -- Actual old panelColor. The black ADD aura never darkened this fill.
        fill:SetColorTexture(PANEL_GREY, PANEL_GREY, PANEL_GREY, PANEL_ALPHA)
        local rim=self:Panel(panel,"compact",0);rim:SetFrameStrata("BACKGROUND")
        self.chatBackground=fill
        self:FitPanelBackground(fill,rim)
    end
    local panel=self.chatPanel
    local selected=GeneralDockManager and FCFDock_GetSelectedWindow and FCFDock_GetSelectedWindow(GeneralDockManager)
    local font=ns.Media:Resolve("font","Bui Homizio")
    -- Ordinary chat text shares the owner-requested 8-point body size.
    for i=1,NUM_CHAT_WINDOWS or 10 do
        local chat=_G["ChatFrame"..i]
        if chat and (i==1 or chat.isDocked) then
            if not chat.squancherChatStyled then
                chat.squancherChatStyled=true
                chat:SetParent(panel);chat:SetFrameStrata("BACKGROUND");chat:SetFrameLevel(304)
                chat:ClearAllPoints();chat:SetPoint("BOTTOMLEFT",panel,"BOTTOMLEFT",5,5)
                chat:SetSize(340,i==2 and 119 or 143)
                -- Size is presentation only; native chat geometry stays intact.
                local size=8
                chat:SetFont(font,size,"");chat:SetShadowColor(0,0,0,1);chat:SetShadowOffset(1,-1)
                chat:SetClampRectInsets(0,0,0,0);chat:SetClampedToScreen(false)
                if chat.FontStringContainer then
                    chat.FontStringContainer:ClearAllPoints()
                    chat.FontStringContainer:SetPoint("TOPLEFT",chat,"TOPLEFT",-3,3)
                    chat.FontStringContainer:SetPoint("BOTTOMRIGHT",chat,"BOTTOMRIGHT",3,-3)
                end
                local editbox=chat.editBox or _G["ChatFrame"..i.."EditBox"]
                if editbox then
                    stripRegions(editbox)
                    for _,part in ipairs({"focusLeft","focusMid","focusRight"}) do
                        if editbox[part] then editbox[part]:SetAlpha(0) end
                    end
                    local fittingEntry
                    local function fitEntry()
                        if fittingEntry or InCombatLockdown() then return end
                        fittingEntry=true
                        editbox:ClearAllPoints()
                        editbox:SetPoint("BOTTOMLEFT",panel,"TOPLEFT",0,0)
                        editbox:SetPoint("TOPRIGHT",panel,"TOPRIGHT",0,22)
                        fittingEntry=nil
                    end
                    fitEntry()
                    hooksecurefunc(editbox,"SetPoint",fitEntry)
                    editbox:HookScript("OnShow",fitEntry)
                    editbox:SetFont(font,size,"");editbox:SetShadowColor(0,0,0,1);editbox:SetShadowOffset(1,-1)
                    if editbox.header then editbox.header:SetFont(font,size,"") end
                    local bg=editbox:CreateTexture(nil,"BACKGROUND",nil,-8)
                    bg:SetColorTexture(.025,.025,.025,1)
                    local entryRim=self:Panel(editbox,"dialog",0)
                    self:FitPanelBackground(bg,entryRim)
                    local function entryFocus()
                        fitEntry()
                        local focused=editbox:HasFocus()
                        bg:SetShown(focused);entryRim:SetShown(focused)
                    end
                    editbox:HookScript("OnEditFocusGained",entryFocus)
                    editbox:HookScript("OnEditFocusLost",entryFocus)
                    entryFocus()
                end
            end
            -- Default floating chat art adds another black background and chrome.
            -- Source removed all these regions and hid the side/scroll controls.
            stripRegions(chat)
            hideNativeChatChrome(chat)
            conceal(chat.buttonFrame);conceal(chat.ScrollBar);conceal(chat.ScrollToBottomButton)
            conceal(_G["ChatFrame"..i.."ThumbTexture"]);conceal(_G["ChatFrame"..i.."MinimizeButton"])
            nativeTabStyle(_G["ChatFrame"..i.."Tab"],chat==selected)
            nativeTabAlpha(chat)
        end
    end
    local dock=GeneralDockManager
    if dock and not self.chatDockPlaced then
        self.chatDockPlaced=true
        dock:SetParent(panel);dock:ClearAllPoints()
        -- Tabs start on the left rim's painted inner boundary.
        local inset=chatInnerInset()
        dock:SetPoint("TOPLEFT",panel,"TOPLEFT",inset,-2)
        dock:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-inset,-2)
        dock:SetHeight(22)
        if GeneralDockManagerScrollFrame then GeneralDockManagerScrollFrame:SetHeight(22) end
        if GeneralDockManagerScrollFrameChild then GeneralDockManagerScrollFrameChild:SetHeight(22) end
    end
    if dock and not self.chatTabDivider then
        local line = panel:CreateTexture(nil, "BORDER")
        -- Three physical pixels, with the extra pixel below the tab faces.
        -- Keep the top aligned with the vertical rims so the corners stay closed.
        -- A solid gold rule avoids dark bands from the compressed atlas strip.
        line:SetColorTexture(BORDER_R * .5, BORDER_G * .5, BORDER_B * .5, 1)
        self:TintChrome(line)
        local width = chatBorderWidth(panel)
        line:SetAlpha(1)
        line:SetHeight(width * 1.5)
        line:SetPoint("BOTTOMLEFT", dock, "BOTTOMLEFT", 0, -width * .5)
        line:SetPoint("BOTTOMRIGHT", dock, "BOTTOMRIGHT", 0, -width * .5)
        self.chatTabDivider = line
    end
    if dock and not self.chatIconStrip then
        -- Top rim boundary down to the tab divider, flush with the right rim.
        local strip=CreateFrame("Frame",nil,panel)
        mouseTransparent(strip)
        strip:SetFrameStrata("BACKGROUND");strip:SetFrameLevel(panel:GetFrameLevel()+2)
        local inset=chatInnerInset()
        strip:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-inset,-inset)
        strip:SetPoint("BOTTOMRIGHT",dock,"BOTTOMRIGHT")
        strip:SetWidth(1)
        strip.seams={}
        self.chatIconStrip=strip
    end
    -- Keep the original native voice action in the tab row, immediately right of
    -- the last tab (AlignChatTabs anchors it); remove its default button chrome
    -- and the separate TTS frame omitted by the old owner.
    local voice=ChatFrameChannelButton
    if voice and dock and not voice.squancherPinned then
        voice.squancherPinned=true;voice:SetParent(panel);voice:ClearAllPoints()
        voice:SetScale(22/math.max(1,voice:GetHeight()))
        voice:SetPoint("LEFT",dock,"LEFT")
        if voice.Icon then voice.Icon:SetDesaturated(true) end
        for _,method in ipairs({"GetNormalTexture","GetPushedTexture","GetHighlightTexture","GetDisabledTexture"}) do
            local texture=voice[method] and voice[method](voice)
            if texture then texture:SetAlpha(0) end
        end
    end
    conceal(TextToSpeechButtonFrame)
    if TextToSpeechButton and voice and dock and not TextToSpeechButton.squancherPinned then
        TextToSpeechButton.squancherPinned=true;TextToSpeechButton:SetParent(panel)
        TextToSpeechButton:SetScale(22/math.max(1,TextToSpeechButton:GetHeight()))
        TextToSpeechButton:ClearAllPoints()
        -- As before: beside the voice control when TTS is on, otherwise over it.
        if GetCVarBool and GetCVarBool("textToSpeech") then
            TextToSpeechButton:SetPoint("LEFT",voice,"RIGHT")
        else
            TextToSpeechButton:SetPoint("CENTER",voice,"CENTER")
        end
    end
    -- The dock/chat message frames live in BACKGROUND. Native controls must
    -- receive pointer hits above that subtree, including its scrolling region.
    if voice and dock then
        voice:SetFrameStrata("LOW")
        voice:SetFrameLevel(math.max(panel:GetFrameLevel(),dock:GetFrameLevel())+4)
    end
    -- Keep the native Friends action/count/toasts as the strip's last cell.
    local friends=QuickJoinToastButton
    if friends and self.chatIconStrip then
        if not friends.squancherPinHooked then
            friends.squancherPinHooked=true
            local function pinFriends() Skin:PinChatFriends() end
            hooksecurefunc(friends,"SetPoint",pinFriends)
            hooksecurefunc(friends,"SetParent",pinFriends)
            friends:HookScript("OnShow",pinFriends)
        end
        self:PinChatFriends()
        if friends.FriendsButton then self:TintChrome(friends.FriendsButton) end
        -- Retire the separate box the former layout drew around Friends.
        local box=self.byFrame[friends] and self.byFrame[friends].inner
        if box then
            box:Hide()
            if box.background then box.background:Hide() end
        end
    end
    if not self.chatTabHooked and FCFTab_UpdateColors then
        self.chatTabHooked=true;hooksecurefunc("FCFTab_UpdateColors",nativeTabStyle)
    end
    if not self.chatTabAlphaHooked and FCFTab_UpdateAlpha then
        self.chatTabAlphaHooked=true;hooksecurefunc("FCFTab_UpdateAlpha",nativeTabAlpha)
    end
    if not self.chatTabAlignHooked and FCFDock_UpdateTabs then
        self.chatTabAlignHooked=true
        hooksecurefunc("FCFDock_UpdateTabs",function(owner) Skin:AlignChatTabs(owner) end)
    end
    self:AlignChatTabs(dock)
end

-- Geometry is replayable independently of one-time native chat styling.
function Skin:LayoutChat()
    if InCombatLockdown() then self.pending = true; return end
    local panel, editor = self.chatPanel, ns.LayoutEditor
    if not panel or not editor then return end
    local rect = editor:Read("chat")
    if rect then
        editor:Place(panel, rect)
        editor:Size(panel, rect.w, rect.h)
    else
        panel:ClearAllPoints()
        panel:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", -783.3333740234375, 30)
        panel:SetSize(349.86669921875, 174.933349609375)
    end
    self:FitPanelBackground(self.chatBackground,self.byFrame[panel].compact)
    if self.chatTabDivider then self.chatTabDivider:SetHeight(chatBorderWidth(panel)) end
    local width, height = panel:GetSize()
    for i = 1, NUM_CHAT_WINDOWS or 10 do
        local chat = _G["ChatFrame" .. i]
        if chat and chat.squancherChatStyled and (i == 1 or chat.isDocked) then
            chat:ClearAllPoints()
            chat:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 5, 5)
            if rect then
                chat:SetSize(math.max(50, width - 9.86669921875), math.max(40, height - (i == 2 and 55.933349609375 or 31.933349609375)))
            else
                chat:SetSize(340, i == 2 and 119 or 143)
            end
        end
    end
end

-- The independent tooltip adapter owns its native anchors and content styling.
function Skin:Tooltips()
    if ns.TooltipSkin then ns.TooltipSkin:Refresh() end
end

function Skin:Interface()
    if InCombatLockdown() then self.pending = true; return end
    self.pending = false
    self:Minimap()
    self:Chat()
    self:LayoutChat()
    self:Tracker()
    self:Menu()
    self:Tooltips()
    -- Native visibility controls hide/show attached decorative borders.
    -- BNToastFrame is fitted and rimmed by FitChatToasts.
    self:FitChatToasts()
    for _, name in ipairs({ "StaticPopup1", "StaticPopup2", "QueueStatusFrame" }) do
        local frame = _G[name]
        if frame then self:Panel(frame, "dialog", 0) end
    end
end

function Skin:Start()
    self.started = true
    self:Interface()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
    if event == "ADDON_LOADED" then
        if not Skin.started then return end
    elseif event == "PLAYER_LOGIN" then
        Skin.started = true
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Combat must not replace the configured translucent fills or border alpha.
        return
    end
    if Skin.started then Skin:Interface() end
end)
