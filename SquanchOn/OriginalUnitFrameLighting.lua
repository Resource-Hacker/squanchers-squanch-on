-- SPDX-License-Identifier: MIT
-- Fitted decorative light; Squanch-On owns bars, values and profiles.
local _,ns=...
local Lighting={states={},byBar={}}
ns.UnitFrameLighting=Lighting
local WHITE=[[Interface\Buttons\WHITE8X8]]
local unitTypes={
    player=true,target=true,targettarget=true,targettargettarget=true,
    pet=true,pettarget=true,focus=true,focustarget=true,
    party=true,partytarget=true,partypet=true,
    raid1=true,raid2=true,raid3=true,raidpet=true,arena=true,boss=true,
    tank=true,tanktarget=true,assist=true,assisttarget=true,
}
function Lighting:IsUnitFrame(frame)
    return frame and not frame.isNameplate and unitTypes[frame.unitframeType]
        and frame.Health and frame.Health.IsObjectType and frame.Health:IsObjectType('StatusBar')
end
local function public(value) return not (issecretvalue and issecretvalue(value)) end
local function rgb(r,g,b)
    return public(r) and public(g) and public(b)
        and type(r)=='number' and type(g)=='number' and type(b)=='number'
end
-- Geometry is converted to physical coordinates before rectangle subtraction.
-- Never inspect a statusbar value or its variable-width fill texture.
local function number(value)
    return public(value) and type(value)=='number' and value==value
        and value>-math.huge and value<math.huge
end
local function rectangle(region,scale)
    if not region then return end
    local x,y,w,h=region:GetRect()
    scale=scale or region:GetEffectiveScale()
    if not (number(x) and number(y) and number(w) and number(h)
        and number(scale) and scale>0 and w>0 and h>0) then return end
    return {x*scale,y*scale,(x+w)*scale,(y+h)*scale}
end
local function hidePieces(state)
    state.activePieces=0
    for _,piece in ipairs(state.pieces) do piece.class:Hide() end
end
local function paintPieces(state)
    for index,piece in ipairs(state.pieces) do
        local active=index<=state.activePieces
        local c=state.classRGB
        if active and c then
            piece.class:SetColorTexture(c[1],c[2],c[3],.68)
            piece.class:Show()
        else piece.class:Hide() end

    end
end
local function subtract(rect,cut,out)
    local l,b=math.max(rect[1],cut[1]),math.max(rect[2],cut[2])
    local r,t=math.min(rect[3],cut[3]),math.min(rect[4],cut[4])
    if l>=r or b>=t then out[#out+1]=rect;return end
    if rect[1]<l then out[#out+1]={rect[1],rect[2],l,rect[4]} end
    if r<rect[3] then out[#out+1]={r,rect[2],rect[3],rect[4]} end
    if rect[2]<b then out[#out+1]={l,rect[2],r,b} end
    if t<rect[4] then out[#out+1]={l,t,r,rect[4]} end
end
local cutKeys={'Health','Portrait','Power'}
local glowKeys={'TargetGlow','MouseGlow','FocusGlow'}
local shadeSpecs={
    {'top','VERTICAL','TOPLEFT','TOPRIGHT',0,.88},
    {'bottom','VERTICAL','BOTTOMLEFT','BOTTOMRIGHT',.88,0},
    {'left','HORIZONTAL','TOPLEFT','BOTTOMLEFT',.88,0},
    {'right','HORIZONTAL','TOPRIGHT','BOTTOMRIGHT',0,.88},
}
-- Everything the fit below reads, as plain numbers. An unchanged signature
-- means a repeat fit would write exactly what is already on screen.
local probe,probed={},0
local function push(region,scale)
    local x,y,w,h=region:GetRect()
    scale=scale or region:GetEffectiveScale()
    if not (number(x) and number(y) and number(w) and number(h) and number(scale)) then return false end
    local count=probed
    probe[count+1],probe[count+2],probe[count+3],probe[count+4],probe[count+5]=x,y,w,h,scale
    probed=count+5
    return true
end
local function signature(state)
    probed=0
    local frame=state.frame
    if not push(state.host) or not push(state.classFill,state.host:GetEffectiveScale()) then return nil end
    for _,key in ipairs(cutKeys) do
        local bar=frame[key]
        local included=bar and bar:IsShown() and (key~='Power' or not frame.POWERBAR_DETACHED)
        probed=probed+1;probe[probed]=included and bar or false
        if included and not push(bar.backdrop or bar) then return nil end
    end
    return probed
end
local function unchanged(state,count)
    local last=state.signature
    if not count or not last or last.count~=count then return false end
    for index=1,count do if last[index]~=probe[index] then return false end end
    return true
end
local function remember(state,count)
    if not count then state.signature=nil;return end
    local last=state.signature or {};state.signature=last
    for index=1,count do last[index]=probe[index] end
    last.count=count
end
local function fitPieces(state)
    hidePieces(state)
    local bounds=rectangle(state.classFill,state.host:GetEffectiveScale())
    local scale=state.host:GetEffectiveScale()
    local origin=rectangle(state.host)
    if not bounds or not origin or not number(scale) or scale<=0 then return end
    local rects={bounds}
    for _,key in ipairs(cutKeys) do
        local bar=state.frame[key]
        local included=bar and bar:IsShown() and (key~='Power' or not state.frame.POWERBAR_DETACHED)
        if included then
            -- Missing/unresolved visible geometry fails closed for this pass.
            local cut=rectangle(bar.backdrop or bar)
            if not cut then return false end
            local nextRects={}
            for _,rect in ipairs(rects) do subtract(rect,cut,nextRects) end
            rects=nextRects
        end
    end
    for index,rect in ipairs(rects) do
        local piece=state.pieces[index]
        if not piece then
            piece={class=state.host:CreateTexture(nil,'BACKGROUND',nil,-7)}
            state.pieces[index]=piece
        end
        local texture=piece.class
        texture:ClearAllPoints()
        texture:SetPoint('BOTTOMLEFT',state.host,'BOTTOMLEFT',
            (rect[1]-origin[1])/scale,(rect[2]-origin[2])/scale)
        texture:SetSize((rect[3]-rect[1])/scale,(rect[4]-rect[2])/scale)
    end
    state.activePieces=#rects
    paintPieces(state)
end
-- Darken the fitted fill toward all four gold edges. These static gradients
-- sit on the decorative host, below native bars/icons, and cannot tint the rim.
local function fitEdgeShade(state)
    local fill=state.classFill
    local width,height=fill:GetSize()
    local depth=math.max(.5,math.min(9,width*.45,height*.45))
    for _,spec in ipairs(shadeSpecs) do
        local shade=state.edgeShades[spec[1]]
        if not shade then
            shade=state.host:CreateTexture(nil,'BACKGROUND',nil,-6)
            shade:SetTexture(WHITE)
            shade:SetGradient(spec[2],CreateColor(0,0,0,spec[5]),CreateColor(0,0,0,spec[6]))
            state.edgeShades[spec[1]]=shade
        end
        shade:ClearAllPoints()
        shade:SetPoint(spec[3],fill,spec[3]);shade:SetPoint(spec[4],fill,spec[4])
        if spec[2]=='VERTICAL' then shade:SetHeight(depth) else shade:SetWidth(depth) end
    end
end
-- Same native inverse-rectangle mask used by the installed LibCustomGlow:
-- empty inside its anchors, opaque outside via CLAMPTOWHITE. Mask only health
-- artwork behind attached power; native values, dimensions and alpha stay owned
-- by ElvUI. A separate alpha-independent host keeps range fading applied once.
local EMPTY=[[Interface\AdventureMap\BrokenIsles\AM_29]]
local function syncHealthOcclusion(state)
    local power=state.frame.Power
    if state.healthMask then
        local active=power and power.backdrop and power:IsShown() and power.backdrop:IsShown()
            and state.frame.USE_POWERBAR and not state.frame.POWERBAR_DETACHED and true or false
        if state.maskActive==active then return end
        state.maskActive=active
        state.healthMask:SetTexture(active and EMPTY or WHITE,'CLAMPTOWHITE','CLAMPTOWHITE','NEAREST')
    end
end
local function fitHealthOcclusion(state)
    local health,power=state.frame.Health,state.frame.Power
    if not power or not power.backdrop then return end
    if not state.healthMask then
        state.maskHost=CreateFrame('Frame',nil,state.frame)
        state.maskHost:EnableMouse(false);state.maskHost.ignoreInLayout=true
        state.maskHost:SetIgnoreParentAlpha(true)
        state.healthMask=state.maskHost:CreateMaskTexture()
        state.maskedTextures={}
        hooksecurefunc(health,'SetStatusBarTexture',function() state.signature=nil;Lighting:Refit(state) end)
    end
    state.healthMask:ClearAllPoints()
    state.healthMask:SetAllPoints(power.backdrop)
    local function include(texture)
        if texture and texture.AddMaskTexture and not state.maskedTextures[texture] then
            texture:AddMaskTexture(state.healthMask)
            state.maskedTextures[texture]=true
        end
    end
    include(health:GetStatusBarTexture());include(health.bg)
    if health.backdrop then
        for _,texture in ipairs({health.backdrop:GetRegions()}) do include(texture) end
    end
    -- The native clip subtree contains cutaway and heal/absorb artwork only.
    local function includeClip(host)
        for _,texture in ipairs({host:GetRegions()}) do include(texture) end
        for _,child in ipairs({host:GetChildren()}) do includeClip(child) end
    end
    if health.ClipFrame then includeClip(health.ClipFrame) end
    -- Keep native target/mouse/focus/threat indications around the frame,
    -- but exclude the portions hidden behind the attached resource face.
    for _,key in ipairs(glowKeys) do
        local glow=state.frame[key]
        if glow then
            includeClip(glow)
            if glow.powerGlow then includeClip(glow.powerGlow) end
        end
    end
    local threat=state.frame.ThreatIndicator
    if threat then
        if threat.MainGlow then includeClip(threat.MainGlow) end
        if threat.PowerGlow then includeClip(threat.PowerGlow) end
    end
    for _,shade in pairs(state.edgeShades) do include(shade) end
    syncHealthOcclusion(state)
end
local function classColor(state)
    local frame,E=state.frame,ns.UnitFrames and ns.UnitFrames.Engine
    local unit=frame.__unit or frame.unit
    local color
    if E and public(unit) and type(unit)=='string' then
        local player=UnitIsPlayer(unit)
        if public(player) then
            if player then
                local _,token=UnitClass(unit)
                if public(token) and type(token)=='string' then color=E:ClassColor(token) end
            else
                local reaction=UnitReaction(unit,'player')
                if public(reaction) and type(reaction)=='number' then
                    color=frame.colors and frame.colors.reaction[reaction]
                end
            end
        end
    end
    local r,g,b
    if color and rgb(color.r,color.g,color.b) then r,g,b=color.r,color.g,color.b end
    -- Same colour as painted: the pieces already show it.
    local c=state.classRGB
    if not r then
        if not c then return end
        state.classRGB=nil
    elseif c then
        if c[1]==r and c[2]==g and c[3]==b then return end
        c[1],c[2],c[3]=r,g,b
    else state.classRGB={r,g,b} end
    paintPieces(state)
end
-- All light comes from the health/class region. Resource bars retain their
-- own face/outline but neither colored spill nor a second semantic glow.
local mutedPowerGlows=setmetatable({}, {__mode='k'})
local function mutePowerGlow(glow)
    if not glow or mutedPowerGlows[glow] then return end
    mutedPowerGlows[glow]=true
    local busy=false
    hooksecurefunc(glow,'SetAlpha',function()
        if busy then return end
        busy=true;glow:SetAlpha(0);busy=false
    end)
    glow:SetAlpha(0)
end
local function healthOnlyGlows(frame)
    for _,key in ipairs(glowKeys) do
        local glow=frame[key]
        mutePowerGlow(glow and glow.powerGlow)
    end
    mutePowerGlow(frame.ThreatIndicator and frame.ThreatIndicator.PowerGlow)
end
-- A configure can change what the fit reads without moving anything (bar
-- texture, new child art): the next Attach fits in full.
function Lighting:Invalidate(frame)
    local state=self.states[frame]
    if state then state.signature=nil end
end
function Lighting:Refit(state)
    syncHealthOcclusion(state)
    self:Attach(state.frame,state.panel)
end
function Lighting:Attach(frame,panel)
    if not self:IsUnitFrame(frame) or not panel then return end
    local state=self.states[frame]
    if not state then
        if InCombatLockdown() then ns.OriginalUnitFrameBorders.pendingFrames[frame]=true;return end
        local host=CreateFrame('Frame',nil,frame)
        host:EnableMouse(false);host.ignoreInLayout=true;host:SetAllPoints(frame)
        state={frame=frame,panel=panel,host=host,edgeShades={},pieces={},activePieces=0}
        state.classFill=host:CreateTexture(nil,'BACKGROUND',nil,-7)
        -- Invisible bounds only: all color lives in the subtracted gap pieces.
        state.classFill:SetAlpha(0)
        self.states[frame]=state
        self.byBar[frame.Health]=state
        local function refit() Lighting:Refit(state) end
        if frame.Power then
            frame.Power:HookScript('OnShow',refit);frame.Power:HookScript('OnHide',refit)
            if frame.Power.backdrop then
                frame.Power.backdrop:HookScript('OnShow',refit);frame.Power.backdrop:HookScript('OnHide',refit)
            end
        end
        frame:HookScript('OnShow',refit)
        if frame.Portrait and frame.Portrait.HookScript then
            frame.Portrait:HookScript('OnShow',refit);frame.Portrait:HookScript('OnHide',refit)
        end
    end
    local level=math.max(0,frame:GetFrameLevel()-1)
    if state.hostLevel~=level then state.hostLevel=level;state.host:SetFrameLevel(level) end
    -- The fill follows its panel through anchors; only a new panel, corner
    -- size or scale ratio needs the inset computed again.
    local corner,ratio=panel.cornerSize,panel:GetEffectiveScale()/state.host:GetEffectiveScale()
    if state.panel~=panel or state.fillCorner~=corner or state.fillRatio~=ratio or not state.signature then
        state.panel,state.fillCorner,state.fillRatio=panel,corner,ratio
        ns.DarkSkin:FitPanelBackground(state.classFill,panel)
        state.signature=nil
    end
    healthOnlyGlows(frame)
    -- The frame, its power bar, its backdrop and its portrait all report a
    -- show or hide, and a configure passes here too: fit once per real change.
    local count=signature(state)
    if state.activePieces>0 and unchanged(state,count) then
        syncHealthOcclusion(state);classColor(state)
        return
    end
    -- An existing light is refitted in combat too: its host, textures and mask
    -- are unprotected children. The borders get their pass for this frame afterwards.
    if InCombatLockdown() then ns.OriginalUnitFrameBorders.pendingFrames[frame]=true end
    -- A unit button that has just been shown can report child geometry one
    -- frame late. Retry once instead of leaving the frame without its light.
    local fitted=fitPieces(state)
    if (fitted==false or state.activePieces==0) and not state.retry and (state.retries or 0)<5 then
        state.retry=true;state.retries=(state.retries or 0)+1
        C_Timer.After(0,function() state.retry=nil;if frame:IsShown() then Lighting:Refit(state) end end)
    end
    if state.activePieces>0 then state.retries=0 end
    fitEdgeShade(state)
    fitHealthOcclusion(state)
    classColor(state)
    remember(state,state.activePieces>0 and count or nil)
    local E=ns.UnitFrames and ns.UnitFrames.Engine
    local UF=E and E:GetModule('UnitFrames',true)
    if UF and not self.hooked then
        self.hooked=true
        -- Posthook the color delivery, never read health/power values or replace
        -- native PostUpdate callbacks. Target swaps follow it; power color never drives the light.
        hooksecurefunc(UF,'SetStatusBarColor',function(_,bar)
            local owner=Lighting.byBar[bar]
            if owner then classColor(owner) end
        end)
    end
end
local events=CreateFrame('Frame')
events:RegisterEvent('PLAYER_TARGET_CHANGED')
events:SetScript('OnEvent',function()
    -- Only frames that follow the target can have changed unit.
    for frame,state in pairs(Lighting.states) do
        local unit=frame.__unit or frame.unit
        if not public(unit) or type(unit)~='string' or unit:find('target',1,true) then classColor(state) end
    end
end)
