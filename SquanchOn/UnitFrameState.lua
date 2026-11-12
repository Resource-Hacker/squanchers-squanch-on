-- SPDX-License-Identifier: MIT
-- Independent presentation state. oUF remains the sole unit/action/event engine.
-- Load immediately after UnitFrames.lua, before options and decorations.
local _,ns=...
local unpack=unpack or table.unpack
local UF=ns.UnitFrames
local white='Interface\\Buttons\\WHITE8X8'
local function public(value) return not (issecretvalue and issecretvalue(value)) end
local function truth(value) return public(value) and value==true end
local function scalar(value) return public(value) and type(value)=='number' end
local function flag(func,...)
    if type(func)~='function' then return false end
    local value=func(...);return public(value) and value and true or false
end
local function rgba(c,r,g,b,a) return c and c.r or r,c and c.g or g,c and c.b or b,c and c.a or a end
local function point(object,...) local args={...};for i,v in ipairs(args) do if type(v)=='number' then args[i]=UF:Scale(v) end end;object:SetPoint(unpack(args)) end
local function size(object,w,h) object:SetSize(UF:Scale(w),UF:Scale(h)) end

local function fadeTarget(frame)
    local c=frame.db.fader or {};if not c.enable then return 1 end
    local unit=frame.__unit or frame.unit
    if not public(unit) or not unit then return c.maxAlpha or 1 end
    local reveal=false
    reveal=reveal or (c.hover and frame:IsMouseOver())
    reveal=reveal or (c.combat and flag(UnitAffectingCombat,'player'))
    reveal=reveal or (c.playertarget and flag(UnitExists,'target'))
    reveal=reveal or (c.unittarget and flag(UnitExists,unit..'target'))
    reveal=reveal or (c.focus and flag(UnitExists,'focus'))
    reveal=reveal or (c.vehicle and flag(UnitHasVehicleUI,'player'))
    reveal=reveal or (c.dynamicflight and flag(IsAdvancedFlyableArea))
    if c.casting then
        local name=UnitCastingInfo(unit);local channel=UnitChannelInfo(unit)
        reveal=reveal or not public(name) or not public(channel) or name~=nil or channel~=nil
    end
    if c.health then
        local now,maximum=UnitHealth(unit),UnitHealthMax(unit)
        reveal=reveal or not scalar(now) or not scalar(maximum) or now<maximum
    end
    if c.power then
        local now,maximum=UnitPower(unit),UnitPowerMax(unit)
        reveal=reveal or not scalar(now) or not scalar(maximum) or now<maximum
    end
    if reveal then return c.maxAlpha or 1 end
    if c.range and unit~='player' then
        return UF:RangeState(unit)==false and (c.minAlpha or .35) or (c.maxAlpha or 1)
    end
    return c.minAlpha or 0
end
function UF:RefreshFade(frame)
    if not frame.db then return end
    local target=fadeTarget(frame);local c=frame.db.fader or {}
    if target==frame.squancherFadeTarget then return end
    frame.squancherFadeTarget=target;frame.squancherFadeGeneration=(frame.squancherFadeGeneration or 0)+1
    local generation=frame.squancherFadeGeneration
    local function begin()
        if generation~=frame.squancherFadeGeneration then return end
        local start=frame:GetAlpha();local duration=c.enable and c.smooth or 0
        if not scalar(start) or not duration or duration<=0 then frame:SetAlpha(target);return end
        if not frame.FadeHost then frame.FadeHost=CreateFrame('Frame',nil,frame) end
        local elapsed=0
        frame.FadeHost:SetScript('OnUpdate',function(host,delta)
            elapsed=elapsed+delta;local progress=math.min(1,elapsed/duration)
            frame:SetAlpha(start+(target-start)*progress)
            if progress>=1 or generation~=frame.squancherFadeGeneration then host:SetScript('OnUpdate',nil) end
        end)
    end
    if (c.delay or 0)>0 and target<frame:GetAlpha() then C_Timer.After(c.delay,begin) else begin() end
end

local function edge(parent,region,level,spacing)
    local glow=CreateFrame('Frame',nil,parent,'BackdropTemplate');glow:EnableMouse(false)
    point(glow,'TOPLEFT',region,'TOPLEFT',-spacing,spacing)
    point(glow,'BOTTOMRIGHT',region,'BOTTOMRIGHT',spacing,-spacing)
    glow:SetFrameLevel(level)
    local texture=UF:Resolve('texture','Interface\\AddOns\\ElvUI\\Game\\Shared\\Media\\Textures\\GlowTex.tga',white)
    glow:SetBackdrop({edgeFile=texture,edgeSize=UF:Scale(4)})
    glow:SetBackdropBorderColor(0,0,0,.6)
    return glow
end
function UF:SoftShadow(parent,region) return edge(parent,region,1,3) end
-- Same construction as the frame-glow element this replaces: a 4px soft edge
-- in BACKGROUND strata, 4px outside the portrait/health block, so it reads as
-- light around the frame and never as a line on the health face.
local function semantic(frame,level)
    local root=CreateFrame('Frame',nil,frame);root:SetAllPoints(frame);root:EnableMouse(false)
    local texture=UF:Resolve('texture','Interface\\AddOns\\ElvUI\\Game\\Shared\\Media\\Textures\\GlowTex.tga',white)
    for _,key in ipairs({'healthGlow','powerGlow'}) do
        local glow=CreateFrame('Frame',nil,root,'BackdropTemplate');glow:EnableMouse(false)
        glow:SetFrameStrata('BACKGROUND');glow:SetFrameLevel(level)
        glow:SetBackdrop({edgeFile=texture,edgeSize=4})
        glow:SetBackdropBorderColor(0,0,0,.9)
        root[key]=glow
    end
    root.HealthGlow=root.healthGlow;root.MainGlow=root.healthGlow;root.PowerGlow=root.powerGlow
    root.SetVertexColor=function() end
    -- Lit only by RefreshGlows or the threat element, never by default.
    root:Hide()
    return root
end
local function positionGlow(frame,root)
    local health=frame.Health and frame.Health.backdrop
    if not health then return end
    local portrait=frame.USE_PORTRAIT and not frame.USE_PORTRAIT_OVERLAY and frame.Portrait and frame.Portrait.backdrop
    local o=4;local main=root.healthGlow
    main:ClearAllPoints()
    -- An attached, populated class bar sits inside the lit outline.
    local class=frame.ClassBarHolder
    local classbar=frame.db and frame.db.classbar
    local top=class and class:IsShown() and frame.ClassPower and frame.ClassPower[1] and frame.ClassPower[1]:IsShown()
        and not (classbar and classbar.detachFromFrame) and class
    main:SetPoint('TOPLEFT',top or frame.ORIENTATION=='LEFT' and portrait or health,'TOPLEFT',-o,o)
    main:SetPoint('TOPRIGHT',top or frame.ORIENTATION=='RIGHT' and portrait or health,'TOPRIGHT',o,o)
    local separate=frame.USE_POWERBAR_OFFSET or frame.USE_MINI_POWERBAR
    local bottom=separate and health or frame
    main:SetPoint('BOTTOMLEFT',bottom,'BOTTOMLEFT',-o,-o)
    main:SetPoint('BOTTOMRIGHT',bottom,'BOTTOMRIGHT',o,-o)
    local power=frame.Power and frame.Power.backdrop
    root.powerGlow:ClearAllPoints()
    if power then
        root.powerGlow:SetPoint('TOPLEFT',power,'TOPLEFT',-o,o)
        root.powerGlow:SetPoint('BOTTOMRIGHT',power,'BOTTOMRIGHT',o,-o)
    end
    root.powerGlow:SetShown(power and separate and frame.Power:IsShown() or false)
end
local function glowColor(frame,config)
    local r,g,b,a=rgba(config and config.color,1,1,1,1)
    if config and config.class then
        local unit=frame.__unit or 'player'
        local player=UnitIsPlayer(unit)
        local c
        if public(player) and player then
            local _,class=UnitClass(unit)
            c=public(class) and class and frame.colors.class[class]
        else
            local reaction=UnitReaction(unit,'player')
            c=public(reaction) and reaction and frame.colors.reaction[reaction]
        end
        if c then r,g,b=c.r,c.g,c.b end
    end
    return r,g,b,a
end
local function paintGlow(glow,...)
    glow.healthGlow:SetBackdropBorderColor(...)
    glow.powerGlow:SetBackdropBorderColor(...)
end
-- Glows ease in rather than pop; hiding stays immediate so a stale highlight
-- never lingers on the wrong unit.
local function reveal(root,shown)
    if shown and not root:IsShown() then
        if not root.easeIn then
            root.easeIn=root:CreateAnimationGroup()
            local alpha=root.easeIn:CreateAnimation('Alpha')
            alpha:SetFromAlpha(0);alpha:SetToAlpha(1);alpha:SetDuration(.12);alpha:SetSmoothing('OUT')
        end
        root:Show();root.easeIn:Play()
    elseif not shown and root:IsShown() then
        if root.easeIn then root.easeIn:Stop() end
        root:Hide()
    end
end
local function hovered(frame,unit)
    return frame:IsVisible() and (frame:IsMouseOver() or flag(UnitIsUnit,'mouseover',unit))
end
-- Geometry and textures change only with layout; events below just show, hide and tint.
function UF:LayoutGlows(frame)
    for _,key in ipairs({'TargetGlow','MouseGlow','FocusGlow','ThreatIndicator'}) do positionGlow(frame,frame[key]) end
    local texture=frame.HoverWash
    if not texture then
        texture=frame.Health:CreateTexture(nil,'ARTWORK',nil,1);frame.HoverWash=texture;texture:Hide()
        texture:SetPoint('TOPLEFT',frame.Health,'TOPLEFT')
        texture:SetPoint('BOTTOMRIGHT',frame.Health:GetStatusBarTexture(),'BOTTOMRIGHT')
    end
    local wash=(self.db.colors.frameGlow or {}).mouseoverGlow or {}
    texture:SetTexture(self:Texture(wash.texture or self.db.statusbar))
end
function UF:RefreshGlows(frame)
    local c=self.db.colors.frameGlow or {};local unit=frame.__unit
    if not unit then reveal(frame.TargetGlow,false);reveal(frame.MouseGlow,false);reveal(frame.FocusGlow,false);return end
    -- The hover edge follows mainGlow; mouseoverGlow owns the wash over the health fill.
    local target=c.targetGlow or {};local main=c.mainGlow or {};local wash=c.mouseoverGlow or {};local focus=c.focusGlow or {}
    local hover=not frame.db.disableMouseoverGlow and hovered(frame,unit)
    reveal(frame.TargetGlow,target.enable==true and not frame.db.disableTargetGlow and flag(UnitIsUnit,unit,'target'))
    reveal(frame.MouseGlow,main.enable==true and hover)
    reveal(frame.FocusGlow,focus.enable==true and not frame.db.disableFocusGlow and flag(UnitIsUnit,unit,'focus'))
    paintGlow(frame.TargetGlow,glowColor(frame,target));paintGlow(frame.MouseGlow,glowColor(frame,main));paintGlow(frame.FocusGlow,glowColor(frame,focus))
    local texture=frame.HoverWash
    local washed=wash.enable==true and hover
    if washed then texture:SetVertexColor(glowColor(frame,wash)) end
    texture:SetShown(washed)
    -- Leaving a unit in the world raises no event; watch only while something is lit.
    if hover and not self.hoverClock then
        self.hoverClock=C_Timer.NewTicker(.1,function()
            local any=false
            for _,object in ipairs(UF.objects) do
                if object.squancherState and object.__unit then
                    local lit=object.MouseGlow:IsShown() or object.HoverWash and object.HoverWash:IsShown()
                    if lit or hovered(object,object.__unit) then UF:RefreshGlows(object) end
                    any=any or object.MouseGlow:IsShown() or (object.HoverWash and object.HoverWash:IsShown()) or false
                end
            end
            if not any then UF.hoverClock:Cancel();UF.hoverClock=nil end
        end)
    end
end
local function indicator(frame,key,config,element)
    local texture=frame[key]
    if not config or config.enable==false then
        if not frame.squancherBuilding then frame:DisableElement(element) end
        texture:Hide();return
    end
    local region=frame[config.attachTo or config.attachToObject or 'Health'] or frame
    local pos=config.position or config.attachTo or 'CENTER'
    if pos~='TOP' and pos~='BOTTOM' and pos~='LEFT' and pos~='RIGHT' and pos~='TOPLEFT' and pos~='TOPRIGHT'
        and pos~='BOTTOMLEFT' and pos~='BOTTOMRIGHT' then pos='CENTER' end
    texture:ClearAllPoints();point(texture,pos,region,pos,config.xOffset or 0,config.yOffset or 0)
    size(texture,config.size or 12,config.size or 12)
    if not frame.squancherBuilding then frame:EnableElement(element) end
end

local function cutaway(frame,key,current,maximum)
    local c=frame.db.cutaway and frame.db.cutaway[key:lower()]
    if not c or not c.enabled then return end
    if not scalar(current) or not scalar(maximum) then UF.status.secretCutawayDeferred=true;return end
    local bar=frame[key];local previous=bar.cutawayValue;bar.cutawayValue=current
    if not previous or current>=previous or maximum<=0 then return end
    local echo=bar.Cutaway
    if not echo then
        echo=CreateFrame('StatusBar',nil,bar.ClipFrame);echo:SetAllPoints(bar)
        echo:SetStatusBarTexture(white);bar.Cutaway=echo
    end
    echo:SetReverseFill(bar:GetReverseFill());echo:SetMinMaxValues(0,maximum);echo:SetValue(previous)
    echo:SetStatusBarColor(.8,.8,.8,.7);echo:SetAlpha(1);echo:Show()
    local elapsed=0;local hold=c.lengthBeforeFade or .3;local duration=c.fadeOutTime or .6
    echo:SetScript('OnUpdate',function(self,delta)
        elapsed=elapsed+delta
        if elapsed>hold then self:SetAlpha(math.max(0,1-(elapsed-hold)/duration)) end
        if elapsed>=hold+duration then self:SetScript('OnUpdate',nil);self:Hide() end
    end)
end

function UF:ConfigureState(frame)
    local c=frame.db
    if not frame.squancherState then
        frame.squancherState=true
        frame.Shadow=edge(frame,frame,1,3)
        frame.TargetGlow=semantic(frame,4);frame.MouseGlow=semantic(frame,5);frame.FocusGlow=semantic(frame,3)
        -- oUF threat state paints a real edge. Other owners may clip its child
        -- glows through this explicitly exposed object contract.
        frame.ThreatIndicator=semantic(frame,2);positionGlow(frame,frame.ThreatIndicator)
        frame.ThreatIndicator.PostUpdate=function(self,unit,status,color)
            if color then paintGlow(self,color:GetRGBA()) end
        end
        frame:HookScript('OnEnter',function() UF:RefreshFade(frame);UF:RefreshGlows(frame) end)
        frame:HookScript('OnLeave',function() UF:RefreshFade(frame);UF:RefreshGlows(frame) end)
        frame:HookScript('OnShow',function() UF:LayoutGlows(frame);UF:RefreshFade(frame);UF:RefreshGlows(frame);UF:StartRangeClock() end)
        frame:HookScript('OnHide',function() UF:StartRangeClock() end)
        local health=frame.Health.PostUpdate
        frame.Health.PostUpdate=function(self,unit,current,maximum,...)
            if health then health(self,unit,current,maximum,...) end
            cutaway(frame,'Health',current,maximum);UF:RefreshFade(frame)
        end
        local power=frame.Power.PostUpdate
        frame.Power.PostUpdate=function(self,unit,current,minimum,maximum,...)
            if power then power(self,unit,current,minimum,maximum,...) end
            cutaway(frame,'Power',current,maximum);UF:RefreshFade(frame)
        end
        frame.GroupRoleIndicator.PostUpdate=function(self,role)
            local options=frame.db.roleIcon or {}
            if not public(role) then return end
            local key=role=='TANK' and 'tank' or role=='HEALER' and 'healer' or 'damager'
            if options[key]==false then self:Hide();return end
            local art=role=='DAMAGER' and 'dps' or role:lower()
            local path=UF:Resolve('texture','Interface\\AddOns\\ElvUI_BenikUI\\media\\textures\\roleIcons\\'..art..'.tga')
            if path then self:SetTexture(path);self:SetTexCoord(0,1,0,1) end
        end
    end
    frame.Shadow:SetShown(not (frame.USE_MINI_POWERBAR or frame.USE_POWERBAR_OFFSET))
    frame.GroupRoleIndicator.combatHide=c.roleIcon and c.roleIcon.combatHide
    indicator(frame,'GroupRoleIndicator',c.roleIcon,'GroupRoleIndicator')
    indicator(frame,'ReadyCheckIndicator',c.readycheckIcon,'ReadyCheckIndicator')
    indicator(frame,'RaidTargetIndicator',c.raidicon,'RaidTargetIndicator')
    indicator(frame,'ResurrectIndicator',c.resurrectIcon,'ResurrectIndicator')
    for _,pair in ipairs({{'readyTexture','ready','Ready'},{'notReadyTexture','notready','NotReady'},{'waitingTexture','waiting','Waiting'}}) do
        frame.ReadyCheckIndicator[pair[1]]=self:Resolve('texture','Interface\\AddOns\\ElvUI_BenikUI\\media\\textures\\'..pair[2]..'.blp',
            'Interface\\RaidFrame\\ReadyCheck-'..pair[3])
    end
    if not frame.squancherBuilding then
        if c.threatStyle=='NONE' then frame:DisableElement('ThreatIndicator') else frame:EnableElement('ThreatIndicator') end
    end
    local colors=self.db.colors.healPrediction or {}
    for key,name in pairs({healingAll='others',damageAbsorb='absorbs',healAbsorb='healAbsorbs'}) do
        local prediction=frame.HealthPrediction[key]
        if prediction then prediction:SetStatusBarColor(rgba(colors[name],0,1,0,.5)) end
    end
    self:LayoutGlows(frame);self:RefreshFade(frame);self:RefreshGlows(frame);self:StartRangeClock()
end

function UF:StartRangeClock()
    local active=false
    for _,frame in ipairs(self.objects) do
        if frame:IsShown() and frame.db and frame.db.fader and frame.db.fader.enable and frame.db.fader.range then active=true;break end
    end
    if active and not self.rangeClock then
        self.rangeClock=C_Timer.NewTicker(.2,function()
            for _,frame in ipairs(UF.objects) do if frame:IsShown() and frame.db.fader.range then UF:RefreshFade(frame) end end
            UF:StartRangeClock()
        end)
    elseif not active and self.rangeClock then self.rangeClock:Cancel();self.rangeClock=nil end
end

local state=CreateFrame('Frame')
for _,event in ipairs({'UPDATE_MOUSEOVER_UNIT','PLAYER_TARGET_CHANGED','PLAYER_FOCUS_CHANGED','PLAYER_REGEN_ENABLED','PLAYER_REGEN_DISABLED',
    'UNIT_TARGET','UNIT_SPELLCAST_START','UNIT_SPELLCAST_STOP',
    'UNIT_SPELLCAST_CHANNEL_START','UNIT_SPELLCAST_CHANNEL_STOP','UNIT_ENTERED_VEHICLE','UNIT_EXITED_VEHICLE'}) do state:RegisterEvent(event) end
-- Health and power reach the fader through their own element callbacks; this
-- handler only sees the rarer state changes, and skips hidden or unfaded frames.
local glowEvents={UPDATE_MOUSEOVER_UNIT=true,PLAYER_TARGET_CHANGED=true,PLAYER_FOCUS_CHANGED=true,UNIT_TARGET=true}
state:SetScript('OnEvent',function(_,event,unit)
    local glow=glowEvents[event]
    local global=not unit or unit=='player' or glow
    for _,frame in ipairs(UF.objects) do
        if frame.squancherState and frame:IsShown() and (global or unit==frame.__unit) then
            if event=='PLAYER_TARGET_CHANGED' and frame.squancherPortraitPlace then frame.squancherPortraitPlace() end
            if event~='UPDATE_MOUSEOVER_UNIT' and frame.db.fader and frame.db.fader.enable then UF:RefreshFade(frame) end
            if glow then UF:RefreshGlows(frame) end
        end
    end
end)
for _,field in ipairs({'enable','range','minAlpha','maxAlpha','smooth','delay','casting','combat','health','hover',
    'playertarget','unittarget','focus','power','vehicle'}) do UF.optionCapabilities['fader.'..field]=true end
if UF.Initialized then for _,frame in ipairs(UF.objects) do UF:ConfigureState(frame) end end
