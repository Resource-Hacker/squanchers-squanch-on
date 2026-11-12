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
local function semantic(frame)
    local root=CreateFrame('Frame',nil,frame);root:SetAllPoints(frame);root:EnableMouse(false)
    root.healthGlow=edge(root,frame.Health,9,3)
    root.powerGlow=edge(root,frame.Power,14,3)
    root.HealthGlow=root.healthGlow;root.MainGlow=root.healthGlow;root.PowerGlow=root.powerGlow
    root.SetVertexColor=function() end
    return root
end
local function glowColor(frame,config)
    if config and config.class then
        local _,class=UnitClass(frame.__unit or 'player')
        local c=public(class) and frame.colors.class[class]
        if c then return c.r,c.g,c.b,config.color and config.color.a or 1 end
    end
    return rgba(config and config.color,1,1,1,1)
end
local function paintGlow(glow,...)
    glow.healthGlow:SetBackdropBorderColor(...)
    glow.powerGlow:SetBackdropBorderColor(...)
end
function UF:RefreshGlows(frame)
    local c=self.db.colors.frameGlow or {};local unit=frame.__unit
    if not unit then return end
    local target=c.targetGlow or {};local hover=c.mouseoverGlow or {};local focus=c.focusGlow or {}
    frame.TargetGlow:SetShown(target.enable==true and not frame.db.disableTargetGlow and flag(UnitIsUnit,unit,'target'))
    frame.MouseGlow:SetShown(hover.enable==true and not frame.db.disableMouseoverGlow and frame:IsMouseOver())
    frame.FocusGlow:SetShown(focus.enable==true and not frame.db.disableFocusGlow and flag(UnitIsUnit,unit,'focus'))
    paintGlow(frame.TargetGlow,glowColor(frame,target));paintGlow(frame.MouseGlow,glowColor(frame,hover));paintGlow(frame.FocusGlow,glowColor(frame,focus))
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
        frame.TargetGlow=semantic(frame);frame.MouseGlow=semantic(frame);frame.FocusGlow=semantic(frame)
        -- oUF threat state paints a real edge. Other owners may clip its child
        -- glows through this explicitly exposed object contract.
        frame.ThreatIndicator=semantic(frame)
        frame.ThreatIndicator.PostUpdate=function(self,unit,status,color)
            if color then paintGlow(self,color:GetRGBA()) end
        end
        frame:HookScript('OnEnter',function() UF:RefreshFade(frame);UF:RefreshGlows(frame) end)
        frame:HookScript('OnLeave',function() UF:RefreshFade(frame);UF:RefreshGlows(frame) end)
        frame:HookScript('OnShow',function() UF:RefreshFade(frame);UF:RefreshGlows(frame);UF:StartRangeClock() end)
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
    self:RefreshFade(frame);self:RefreshGlows(frame);self:StartRangeClock()
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
for _,event in ipairs({'PLAYER_TARGET_CHANGED','PLAYER_FOCUS_CHANGED','PLAYER_REGEN_ENABLED','PLAYER_REGEN_DISABLED',
    'UNIT_TARGET','UNIT_HEALTH','UNIT_MAXHEALTH','UNIT_POWER_UPDATE','UNIT_SPELLCAST_START','UNIT_SPELLCAST_STOP',
    'UNIT_SPELLCAST_CHANNEL_START','UNIT_SPELLCAST_CHANNEL_STOP','UNIT_ENTERED_VEHICLE','UNIT_EXITED_VEHICLE'}) do state:RegisterEvent(event) end
state:SetScript('OnEvent',function(_,event,unit)
    for _,frame in ipairs(UF.objects) do
        if frame.squancherState and (not unit or unit=='player' or unit==frame.__unit or event:match('^PLAYER_')) then
            UF:RefreshFade(frame);UF:RefreshGlows(frame)
        end
    end
end)
for _,field in ipairs({'enable','range','minAlpha','maxAlpha','smooth','delay','casting','combat','health','hover',
    'playertarget','unittarget','focus','power','vehicle'}) do UF.optionCapabilities['fader.'..field]=true end
if UF.Initialized then for _,frame in ipairs(UF.objects) do UF:ConfigureState(frame) end end
