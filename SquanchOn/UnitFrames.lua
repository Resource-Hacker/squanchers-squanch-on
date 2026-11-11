-- SPDX-License-Identifier: MIT
-- Squanch-On unit-frame layout, MIT. Secure unit state/render updates belong to oUF.
-- Requires the independently MIT licensed oUF_Forever.xml and ## X-oUF: SquanchOnUF.
local addonName, ns = ...
local UF={frames={},headers={},movers={},status={},original=false,objects={},Initialized=false}
ns.UnitFrames=UF
local Import=ns.UnitFrameImport
local oUF=_G.SquanchOnUF
local white='Interface\\Buttons\\WHITE8X8'
local bundledFont='Interface\\AddOns\\SquanchOn\\media\\fonts\\ptsansnarrow_bold.ttf'
local unitNames={player='Player',target='Target',pet='Pet',targettarget='TargetTarget',
    pettarget='PetTarget',targettargettarget='TargetTargetTarget',focus='Focus',focustarget='FocusTarget',
    party='Party',raid1='Raid1',raid2='Raid2',raid3='Raid3',raidpet='Raidpet',tank='Tank',assist='Assist',boss='Boss',arena='Arena'}
local groupTypes={party=true,raid1=true,raid2=true,raid3=true,raidpet=true,tank=true,assist=true}
local function public(value) return not (issecretvalue and issecretvalue(value)) end
local function numeric(value,fallback,low,high) return Import.Number(value,fallback,low,high) end
local function enabled(config) return config and config.enable~=false end
local function element(frame,name,state)
    if frame.squancherBuilding then return end
    if state then frame:EnableElement(name) else frame:DisableElement(name) end
end

function UF:SetStatusBarColor(bar,r,g,b,a) bar:SetStatusBarColor(r,g,b,a or 1) end
function UF:AuraCreated(button) end -- decoration hook; oUF owns icon state
function UF:Font(path)
    local name=type(path)=='string' and path:lower() or ''
    if name:find('harry',1,true) or name:find('homizio',1,true) or name:find('forced',1,true)
        or name:find('expressway',1,true) or name:find('elvui',1,true) or name:find('benik',1,true) then return bundledFont end
    if type(path)=='string' and (path:find('\\') or path:find('/')) then return path end
    local lsm=LibStub and LibStub('LibSharedMedia-3.0',true)
    local resolved=lsm and lsm:Fetch('font',path,true)
    if resolved and not resolved:lower():find('elvui',1,true) and not resolved:lower():find('benik',1,true) then return resolved end
    return bundledFont
end
function UF:Texture(path)
    if type(path)=='string' and (path:find('\\') or path:find('/')) then
        if path:lower():find('elvui',1,true) or path:lower():find('benik',1,true) then return 'Interface\\TargetingFrame\\UI-StatusBar' end
        return path
    end
    local lsm=LibStub and LibStub('LibSharedMedia-3.0',true)
    local resolved=lsm and lsm:Fetch('statusbar',path,true)
    if resolved and not resolved:lower():find('elvui',1,true) and not resolved:lower():find('benik',1,true) then return resolved end
    return 'Interface\\TargetingFrame\\UI-StatusBar'
end
local function font(parent,size,path,outline)
    local fs=parent:CreateFontString(nil,'OVERLAY')
    fs:SetFont(UF:Font(path or UF.db.font),size or UF.db.fontSize,outline=='NONE' and '' or outline or UF.db.fontOutline)
    fs:SetShadowOffset(1,-1)
    return fs
end
local function background(frame)
    local bg=CreateFrame('Frame',nil,frame,'BackdropTemplate')
    bg:SetAllPoints(frame)
    bg:SetFrameLevel(math.max(0,frame:GetFrameLevel()-1))
    bg:SetBackdrop({bgFile=white,edgeFile=white,edgeSize=1})
    bg:SetBackdropColor(.055,.055,.055,.66)
    bg:SetBackdropBorderColor(.70,.532,.294,1)
    frame.backdrop=bg
    return bg
end
local function bar(parent,name)
    local b=CreateFrame('StatusBar',name,parent)
    b:SetStatusBarTexture(UF:Texture(UF.db.statusbar))
    b:SetMinMaxValues(0,1);b:SetValue(1)
    b.bg=b:CreateTexture(nil,'BACKGROUND');b.bg:SetAllPoints();b.bg:SetColorTexture(.055,.055,.055,.66)
    background(b)
    return b
end
local function anchor(frame,region,config,defaultPoint)
    local point=config.position or config.justifyH or defaultPoint or 'CENTER'
    if point=='MIDDLE' then point='CENTER' end
    frame:ClearAllPoints()
    frame:SetPoint(point,region,point,config.xOffset or 0,config.yOffset or 0)
end

local tagMap={['name:medium']='sqon:name', ['name:short']='sqon:shortname', ['namecolor']='sqon:namecolor',
    ['classcolor']='sqon:namecolor',['healthcolor']='sqon:namecolor',['powercolor']='powercolor',
    ['health:current']='curhp',['health:max']='maxhp',['health:percent']='perhp',
    ['power:current']='curpp',['power:max']='maxpp',['power:percent']='perpp',
    ['level']='level',['difficultycolor']='difficulty',['classification:icon']='classification',
    ['class:icon']='sqon:classicon',['faction:icon']='sqon:factionicon'}
local function installTags()
    local methods,events=oUF.Tags.Methods,oUF.Tags.Events
    methods['sqon:name']=function(unit)
        local first,last=UnitNameUnmodified(unit)
        if not public(first) or not public(last) then return UnitName(unit) end
        return last and first and first..' '..last or first or ''
    end
    methods['sqon:shortname']=function(unit)
        local name=UnitName(unit)
        if not public(name) then return name end
        return name and name:match('^[^%s%-]+') or ''
    end
    methods['sqon:namecolor']=function(unit)
        local _,class=UnitClass(unit)
        local reaction=UnitReaction(unit,'player')
        local color=public(class) and RAID_CLASS_COLORS[class]
        if not color and public(reaction) and reaction then color=oUF.colors.reaction[reaction] end
        if not color then return '' end
        return string.format('|cff%02x%02x%02x',(color.r or color[1])*255,(color.g or color[2])*255,(color.b or color[3])*255)
    end
    methods['sqon:factionicon']=function(unit)
        local faction=UnitFactionGroup(unit)
        if not public(faction) then return '' end
        if faction=='Horde' or faction=='Alliance' then return '|TInterface\\TargetingFrame\\UI-PVP-'..faction..':0|t' end
        return ''
    end
    methods['sqon:classicon']=function(unit)
        local _,class=UnitClass(unit)
        if not public(class) or not class then return '' end
        return '|A:classicon-'..class..':0:0|a'
    end
    for _,tag in ipairs({'sqon:name','sqon:shortname','sqon:namecolor','sqon:classicon','sqon:factionicon'}) do
        events[tag]='UNIT_NAME_UPDATE UNIT_FACTION UNIT_FLAGS'
    end
end
function UF:TagFormat(value)
    if type(value)~='string' then return '' end
    return (value:gsub('%[([^%]]+)%]',function(tag)
        local mapped=tagMap[tag] or tag
        if oUF.Tags.Methods[mapped] then return '['..mapped..']' end
        self.status.unsupportedTags=self.status.unsupportedTags or {}
        self.status.unsupportedTags[tag]=true
        return ''
    end))
end

local function makeText(frame,key,config,size)
    local fs=font(frame,size or config.size or UF.db.fontSize,config.font,config.fontOutline)
    frame.customTexts=frame.customTexts or {}
    frame.customTexts[key]=fs
    return fs
end
local function textRegion(frame,config)
    return config.attachTextTo=='Health' and frame.Health or config.attachTextTo=='Power' and frame.Power
        or config.attachTextTo=='Portrait' and frame.Portrait or frame
end
local function configureText(frame,fs,config,defaultPoint)
    local region=textRegion(frame,config) or frame
    anchor(fs,region,config,defaultPoint)
    fs:SetJustifyH(config.justifyH or (config.position=='LEFT' and 'LEFT' or config.position=='RIGHT' and 'RIGHT' or 'CENTER'))
    fs:SetFont(UF:Font(config.font or UF.db.font),config.size or UF.db.fontSize,
        config.fontOutline=='NONE' and '' or config.fontOutline or UF.db.fontOutline)
    local value=UF:TagFormat(config.text_format)
    if value=='' or config.enable==false then frame:Untag(fs);fs:SetText('');fs:Hide()
    else frame:Tag(fs,value);fs:Show() end
end

local function tooltipEnter(frame)
    if not frame.__unit or GameTooltip:IsForbidden() then return end
    GameTooltip:SetOwner(frame,'ANCHOR_RIGHT');GameTooltip:SetUnit(frame.__unit)
end
local function tooltipLeave() if not GameTooltip:IsForbidden() then GameTooltip:Hide() end end

local function newAura(frame,key)
    local container=CreateFrame('Frame',frame:GetName()..key,frame)
    container.PostCreateButton=function(self,button)
        button.Icon:SetTexCoord(.07,.93,.07,.93)
        button.Count:SetFont(UF:Font(UF.db.font),8,UF.db.fontOutline)
        button.Text:SetFont(UF:Font(UF.db.font),8,UF.db.fontOutline)
        button.Cooldown:SetDrawEdge(false)
        if ns.DarkSkin then ns.DarkSkin:Panel(button,'inner',0) end
        if UF.AuraCreated then UF:AuraCreated(button) end
    end
    return container
end
local function configureAura(frame,key,config)
    local c=frame[key]
    local perRow=numeric(config.perrow,8,1,40)
    local size=numeric(config.sizeOverride,0,0,100)
    if size==0 then size=math.max(8,(frame:GetWidth()-(perRow-1)*(config.spacing or 1))/perRow) end
    local rows=numeric(config.numrows,1,1,8)
    c.size=size;c.spacing=config.spacing or 1;c.num=enabled(config) and math.floor(perRow*rows) or 0
    c['growth-x']=config.growthX or 'RIGHT';c['growth-y']=config.growthY or 'UP'
    c.initialAnchor=config.anchorPoint or 'TOPLEFT'
    c:SetSize(perRow*(size+c.spacing)-c.spacing,rows*(size+c.spacing)-c.spacing)
    c:ClearAllPoints()
    local relative=config.attachTo=='BUFFS' and frame.Buffs or frame
    local point=config.anchorPoint or (key=='Buffs' and 'TOPLEFT' or 'BOTTOMLEFT')
    c:SetPoint(point,relative,point,config.xOffset or 0,config.yOffset or (key=='Buffs' and 5 or -5))
    c.disableMouse=config.clickThrough or false
    c.showType=key=='Debuffs';c.showStealableBuffs=key=='Buffs'
    c.onlyShowPlayer=config.onlyShowPlayer or false
    c.filter=key=='Buffs' and 'HELPFUL' or 'HARMFUL'
    c.CustomFilter=function(owner,element,unit,button,aura)
        if not aura then return false end
        local duration=aura.duration
        if public(duration) and type(duration)=='number' then
            if (config.minDuration or 0)>0 and duration<config.minDuration then return false end
            if (config.maxDuration or 0)>0 and duration>config.maxDuration then return false end
        end
        local priority=config.priority or ''
        if priority=='' then return true end
        local id=aura.spellId
        local personal=public(button.isPlayer) and button.isPlayer
        for token in priority:gmatch('[^,]+') do
            local filter=UF.db.auraFilters and UF.db.auraFilters[token]
            if filter and public(id) and id then
                local entry=filter.spells and filter.spells[id]
                local active=entry==true or type(entry)=='table' and entry.enable~=false
                if active then return filter.type~='Blacklist' end
            end
            local name=token:lower()
            if name=='blocknoduration' and public(duration) and duration==0 then return false end
            if name=='personal' and personal then return true end
            if name=='nonpersonal' and public(button.isPlayer) and not button.isPlayer then return true end
            if name=='dispellable' then
                local dispel=aura.dispelName
                if public(dispel) and dispel then
                    local library=LibStub('LibDispel-1.0')
                    if library:IsDispellableByMe(dispel) then return true end
                end
            end
        end
        -- Unknown/restricted classification is kept visible rather than guessed.
        return not public(button.isPlayer) or not public(duration)
    end
    if enabled(config) then c:Show() else c:Hide() end
end

local function createCast(frame)
    local cast=bar(frame,frame:GetName()..'_Castbar')
    cast.Text=font(cast,8);cast.Time=font(cast,8)
    cast.Text:SetPoint('LEFT',4,0);cast.Time:SetPoint('RIGHT',-4,0)
    cast.Text:SetPoint('RIGHT',cast.Time,'LEFT',-4,0)
    cast.Icon=cast:CreateTexture(nil,'ARTWORK');cast.Icon:SetTexCoord(.07,.93,.07,.93)
    cast.Shield=cast:CreateTexture(nil,'OVERLAY');cast.Shield:SetAllPoints()
    cast.Shield:SetColorTexture(.7,.2,.2,.25)
    cast.Spark=cast:CreateTexture(nil,'OVERLAY');cast.Spark:SetColorTexture(1,1,1,.7)
    cast.Spark:SetSize(1,20)
    cast.SafeZone=cast:CreateTexture(nil,'OVERLAY');cast.SafeZone:SetColorTexture(.8,.1,.1,.35)
    cast.PostCastStart=function(self) UF:SetStatusBarColor(self,.70,.532,.294,1) end
    cast.PostChannelStart=cast.PostCastStart
    cast.PostCastInterruptible=function(self) UF:SetStatusBarColor(self,.70,.532,.294,1) end
    cast.PostCastNotInterruptible=function(self) UF:SetStatusBarColor(self,.78,.25,.25,1) end
    return cast
end
local function configureCast(frame,config)
    local cast=frame.Castbar
    local overlay=config.overlayOnFrame
    local region=overlay=='Power' and frame.Power or overlay=='Health' and frame.Health
    cast:ClearAllPoints()
    if region then cast:SetAllPoints(region)
    else
        cast:SetSize(numeric(config.width,frame:GetWidth(),20,1000),numeric(config.height,18,4,100))
        if groupTypes[frame.squancherKey] or frame.squancherKey:match('_target$')
            or frame.squancherKey=='boss' or frame.squancherKey=='arena' then
            cast:SetPoint('TOPLEFT',frame,'BOTTOMLEFT',0,-3)
        else
            local mover=UF:CreateMover('cast_'..frame.squancherKey,cast)
            UF:PlaceMover('cast_'..frame.squancherKey,mover,'TOP',frame,'BOTTOM',0,-8)
            cast:SetPoint('TOPLEFT',mover,'TOPLEFT')
        end
    end
    cast:SetFrameLevel(frame:GetFrameLevel()+4)
    cast:SetReverseFill(config.reverse or false)
    cast.timeToHold=config.timeToHold or 0
    cast.Text:SetShown(not config.hideName);cast.Time:SetShown(not config.hideTime)
    cast.Icon:SetSize(cast:GetHeight(),cast:GetHeight())
    cast.Icon:ClearAllPoints();cast.Icon:SetPoint('RIGHT',cast,'LEFT',-2,0)
    cast.Icon:SetShown(config.icon~=false)
    cast.SafeZone:SetShown(config.latency==true)
    cast.Spark:SetHeight(cast:GetHeight())
    element(frame,'Castbar',enabled(config))
    if not enabled(config) then cast:Hide() end
end

local function configurePortrait(frame,config)
    local desired=config.style=='3D' and frame.PortraitModel or frame.PortraitTexture
    if frame.Portrait~=desired then
        element(frame,'Portrait',false)
        frame.Portrait:Hide();frame.Portrait=desired
    end
    local portrait=frame.Portrait
    frame.Portrait3D=config.style=='3D' and portrait or nil
    portrait:ClearAllPoints()
    if not enabled(config) then portrait:Hide();element(frame,'Portrait',false);return 0 end
    local width=numeric(config.width,35,1,math.max(1,frame:GetWidth()-4))
    local right=frame.squancherConfig.orientation=='RIGHT'
    if config.overlay then portrait:SetAllPoints(frame.Health);portrait:SetAlpha(config.overlayAlpha or .35)
    else
        portrait:SetPoint(right and 'TOPRIGHT' or 'TOPLEFT',frame,right and 'TOPRIGHT' or 'TOPLEFT',0,0)
        portrait:SetSize(width,frame:GetHeight());portrait:SetAlpha(1)
    end
    if portrait:IsObjectType('PlayerModel') then
        portrait.PostUpdate=function(self)
            self:SetCamDistanceScale(config.camDistanceScale or 1.2)
            self:SetPortraitZoom(config.zoom or 1)
            self:SetRotation(math.rad(config.rotation or 0))
            self:SetPosition(0,config.xOffset or 0,config.yOffset or 0)
            if self.SetPaused then self:SetPaused(config.paused~=false) end
        end
        frame.Portrait3D=portrait
    else portrait.useClassBase=config.style=='Class';portrait.customTexture=nil end
    portrait:Show();element(frame,'Portrait',true)
    return config.overlay and 0 or width+1
end

function UF:Configure_Power(frame)
    local c=frame.squancherConfig
    local p=c.power
    local power=frame.Power
    power:ClearAllPoints()
    frame.POWERBAR_DETACHED=p.detachFromFrame==true
    if not enabled(p) then element(frame,'Power',false);power:Hide();return end
    local height=numeric(p.height,10,1,300)
    if p.detachFromFrame then
        power:SetSize(numeric(p.detachedWidth,c.width,15,1000),height)
        local mover=self:CreateMover('power_'..frame.squancherKey,power)
        self:PlaceMover('power_'..frame.squancherKey,mover,'TOP',frame,'BOTTOM',0,-3)
        power:SetPoint('TOPLEFT',mover,'TOPLEFT')
    else
        local region=frame.Health
        local width=region:GetWidth()
        if p.width=='spaced' then width=math.max(1,width-2*math.abs(p.xOffset or 0)) end
        if type(p.width)=='number' then width=p.width end
        power:SetSize(math.max(1,width),height)
        power:SetPoint(p.position or 'BOTTOM',frame,p.position or 'BOTTOM',p.xOffset or 0,p.yOffset or 0)
    end
    power.colorPower=true;power.colorDisconnected=true
    power:SetReverseFill(p.reverseFill or false)
    power:SetOrientation(p.vertical and 'VERTICAL' or 'HORIZONTAL')
    power.smoothing=p.smoothbars and Enum.StatusBarInterpolation.ExponentialEaseOut or Enum.StatusBarInterpolation.Immediate
    power:Show();element(frame,'Power',true)
end

local function configureClass(frame,config)
    if not frame.ClassPower then return end
    local holder=frame.ClassBarHolder
    holder:ClearAllPoints()
    local width=config.detachFromFrame and config.detachedWidth or frame:GetWidth()
    holder:SetSize(width or frame:GetWidth(),config.height or 10)
    holder:SetPoint('BOTTOMLEFT',frame,'TOPLEFT',0,3)
    local spacing=config.spacing or 3
    local count=10
    for index,power in ipairs(frame.ClassPower) do
        power:ClearAllPoints();power:SetSize(math.max(1,(holder:GetWidth()-spacing*(count-1))/count),holder:GetHeight())
        power:SetPoint('LEFT',holder,'LEFT',(index-1)*(power:GetWidth()+spacing),0)
    end
    frame.ClassPower.PostUpdate=function(element,cur,max)
        -- oUF owns values; only public segment counts affect layout.
        if not public(max) or type(max)~='number' or max<1 then return end
        for index,power in ipairs(element) do
            power:SetWidth(math.max(1,(holder:GetWidth()-spacing*(max-1))/max))
            power:ClearAllPoints();power:SetPoint('LEFT',holder,'LEFT',(index-1)*(power:GetWidth()+spacing),0)
        end
    end
    element(frame,'ClassPower',enabled(config))
    if enabled(config) then holder:Show() else holder:Hide() end
end

function UF:Configure_CustomTexts(frame)
    local c=frame.squancherConfig
    local size=(frame.squancherKey=='pet' or frame.squancherKey=='targettarget') and 8 or self.db.fontSize
    local name=Import:Copy(c.name);name.size=name.size or size
    configureText(frame,frame.Name,name,'CENTER')
    configureText(frame,frame.Health.Text,c.health,'RIGHT')
    configureText(frame,frame.Power.Text,c.power,'RIGHT')
    for key,config in pairs(c.customTexts or {}) do
        if type(config)=='table' then
            local fs=frame.customTexts[key] or makeText(frame,key,config)
            configureText(frame,fs,config)
            fs:SetDrawLayer('OVERLAY',key=='[faction:icon]' and 0 or 1)
        end
    end
    for key,fs in pairs(frame.customTexts) do
        if not c.customTexts[key] then frame:Untag(fs);fs:SetText('');fs:Hide() end
    end
end

function UF:ConfigureFrame(frame)
    if InCombatLockdown() and not frame.squancherBuilding then self.pending=true;return end
    local c=self.db.units[frame.squancherKey]
    if not c then return end
    frame.squancherConfig=c;frame.db=c;frame.unitframeType=frame.squancherKey
    local info=enabled(c.infoPanel) and c.infoPanel.height or 0
    frame:SetSize(c.width,c.height+info)
    local portraitWidth=configurePortrait(frame,c.portrait)
    frame.Health:ClearAllPoints()
    local right=c.orientation=='RIGHT'
    frame.Health:SetPoint('TOPLEFT',frame,'TOPLEFT',right and 0 or portraitWidth,0)
    frame.Health:SetPoint('BOTTOMRIGHT',frame,'BOTTOMRIGHT',right and -portraitWidth or 0,info)
    frame.Health:SetReverseFill(c.health.reverseFill or false)
    frame.Health.colorHealth=true
    frame.Health.colorDisconnected=true
    frame.Health.colorTapping=true
    frame.Health.colorClass=self.db.colors.healthclass or false
    frame.Health.colorReaction=self.db.colors.forcehealthreaction or false
    local health=self.db.colors.health or {r=.1,g=.1,b=.1}
    frame.colors.health:SetRGB(health.r or .1,health.g or .1,health.b or .1)
    for key,prediction in pairs(frame.HealthPrediction or {}) do
        if type(prediction)=='table' and prediction.SetPoint then
            prediction:ClearAllPoints();prediction:SetHeight(frame.Health:GetHeight())
            local reverse=c.health.reverseFill or false
            prediction:SetReverseFill(reverse)
            local point=reverse and 'TOPRIGHT' or 'TOPLEFT'
            local relative=reverse and 'TOPLEFT' or 'TOPRIGHT'
            prediction:SetPoint(point,frame.Health:GetStatusBarTexture(),relative)
        end
    end
    self:Configure_Power(frame)
    self:Configure_CustomTexts(frame)
    configureCast(frame,c.castbar)
    configureClass(frame,c.classbar)
    configureAura(frame,'Buffs',c.buffs)
    configureAura(frame,'Debuffs',c.debuffs)
    element(frame,'HealthPrediction',not c.healPrediction or enabled(c.healPrediction))
    frame:RegisterForClicks(self.db.targetOnMouseDown and 'AnyDown' or 'AnyUp')
    if not frame.squancherBuilding then
        if frame.UpdateAllElements then frame:UpdateAllElements('SquanchOnConfigure') end
        if ns.OriginalUnitFrameBorders then ns.OriginalUnitFrameBorders:RefreshFrame(frame) end
    end
end

local function style(frame,unit,key)
    frame.squancherKey=key;frame.unitframeType=key
    frame.squancherBuilding=true
    frame.squancherConfig=UF.db.units[key]
    local health=UF.db.colors.health or {r=.1,g=.1,b=.1}
    frame.colors=setmetatable({health=CreateColor(health.r or .1,health.g or .1,health.b or .1)}, {__index=oUF.colors})
    frame:HookScript('OnEnter',tooltipEnter);frame:HookScript('OnLeave',tooltipLeave)
    frame.Health=bar(frame,frame:GetName()..'_HealthBar')
    frame.Health.PostUpdateColor=function(bar,unit,color)
        if color then UF:SetStatusBarColor(bar,color:GetRGB()) end
    end
    frame.Power=bar(frame,frame:GetName()..'_PowerBar')
    frame.Health.Text=font(frame,UF.db.fontSize);frame.Power.Text=font(frame,8)
    frame.Name=font(frame,UF.db.fontSize)
    frame.customTexts={}
    frame.PortraitModel=CreateFrame('PlayerModel',nil,frame)
    frame.PortraitTexture=frame:CreateTexture(nil,'ARTWORK')
    frame.PortraitModel:Hide();frame.PortraitTexture:Hide()
    frame.Portrait=frame.squancherConfig.portrait.style=='3D' and frame.PortraitModel or frame.PortraitTexture
    frame.Castbar=createCast(frame)
    frame.Buffs=newAura(frame,'Buffs');frame.Debuffs=newAura(frame,'Debuffs')
    if key=='player' then
        frame.ClassBarHolder=CreateFrame('Frame',nil,frame)
        frame.ClassPower={}
        for index=1,10 do frame.ClassPower[index]=bar(frame.ClassBarHolder,frame:GetName()..'ClassIconButton'..index) end
        frame.AdditionalPower=bar(frame,frame:GetName()..'_AdditionalPower')
        frame.AdditionalPower:SetSize(frame.squancherConfig.width,5)
        frame.AdditionalPower:SetPoint('TOPLEFT',frame,'BOTTOMLEFT',0,-2)
        frame.AdditionalPower.colorPower=true
    end
    frame.RaidTargetIndicator=frame:CreateTexture(nil,'OVERLAY')
    frame.RaidTargetIndicator:SetSize(16,16);frame.RaidTargetIndicator:SetPoint('CENTER',frame,'TOP',0,8)
    frame.GroupRoleIndicator=frame:CreateTexture(nil,'OVERLAY')
    frame.GroupRoleIndicator:SetSize(12,12);frame.GroupRoleIndicator:SetPoint('TOPLEFT',frame,2,-2)
    frame.ReadyCheckIndicator=frame:CreateTexture(nil,'OVERLAY')
    frame.ReadyCheckIndicator:SetSize(18,18);frame.ReadyCheckIndicator:SetPoint('CENTER')
    frame.ResurrectIndicator=frame:CreateTexture(nil,'OVERLAY')
    frame.ResurrectIndicator:SetSize(20,20);frame.ResurrectIndicator:SetPoint('CENTER')
    frame.ThreatIndicator=frame:CreateTexture(nil,'OVERLAY')
    frame.ThreatIndicator:SetAllPoints();frame.ThreatIndicator:SetColorTexture(1,0,0,.2)
    frame.HealthPrediction={incomingHealOverflow=1,maxOverflow=1}
    for _,kind in ipairs({'healingAll','damageAbsorb','healAbsorb'}) do
        local prediction=CreateFrame('StatusBar',nil,frame.Health)
        prediction:SetStatusBarTexture(white)
        prediction:SetHeight(frame.squancherConfig.height)
        prediction:SetPoint('TOPLEFT',frame.Health:GetStatusBarTexture(),'TOPRIGHT')
        prediction:SetStatusBarColor(kind=='healAbsorb' and .6 or .2,kind=='healingAll' and .8 or .45,.75,.45)
        prediction:SetMinMaxValues(0,1);prediction:SetValue(0)
        frame.HealthPrediction[kind]=prediction
    end
    UF.objects[#UF.objects+1]=frame
    UF:ConfigureFrame(frame)
    frame.squancherBuilding=nil
end

function UF:CreateMover(key,owner)
    local mover=self.movers[key]
    if mover then
        mover:SetSize(owner:GetSize());return mover
    end
    mover=CreateFrame('Frame','SquanchOnUF_'..(unitNames[key] or key)..'Mover',UIParent)
    mover:SetSize(owner:GetSize());mover.parent=owner
    self.movers[key]=mover
    owner:HookScript('OnSizeChanged',function(_,width,height)
        if InCombatLockdown() then UF.pending=true;return end
        mover:SetSize(width,height)
    end)
    return mover
end
function UF:PlaceMover(key,mover,point,relative,relativePoint,x,y)
    local saved=self.db.movers[key]
    mover:ClearAllPoints()
    if type(saved)=='table' then
        mover:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',saved.x,saved.y)
    elseif type(saved)=='string' then
        local a,b,c,d,e=saved:match('^([^,]+),([^,]+),([^,]+),([^,]+),([^,]+)$')
        local target=(b=='UIParent' or b=='ElvUIParent') and UIParent or nil
        local allowed={TOP=true,BOTTOM=true,LEFT=true,RIGHT=true,CENTER=true,TOPLEFT=true,TOPRIGHT=true,BOTTOMLEFT=true,BOTTOMRIGHT=true}
        if allowed[a] and allowed[c] and target and tonumber(d) and tonumber(e) then
            mover:SetPoint(a,target,c,tonumber(d),tonumber(e));return
        end
        mover:SetPoint(point,relative,relativePoint,x,y)
    else mover:SetPoint(point,relative,relativePoint,x,y) end
end
local defaultPositions={player={'BOTTOM',UIParent,'BOTTOM',-240,100},target={'BOTTOM',UIParent,'BOTTOM',240,100},
    pet={'TOPLEFT','player','BOTTOMLEFT',0,-22},targettarget={'TOPRIGHT','target','BOTTOMRIGHT',0,-22},
    pettarget={'TOPLEFT','pet','BOTTOMLEFT',0,-10},focus={'CENTER',UIParent,'CENTER',-450,80},
    party={'LEFT',UIParent,'LEFT',35,120},assist={'TOPLEFT','party','TOPLEFT',0,80},
    raid1={'TOPLEFT',UIParent,'TOPLEFT',35,-180},raid2={'TOPLEFT',UIParent,'TOPLEFT',35,-180},
    raid3={'TOPLEFT',UIParent,'TOPLEFT',35,-180},boss={'RIGHT',UIParent,'RIGHT',-60,100},arena={'RIGHT',UIParent,'RIGHT',-60,100}}
local function place(key,owner)
    local p=defaultPositions[key] or {'CENTER',UIParent,'CENTER',0,0}
    local relative=type(p[2])=='string' and (UF.frames[p[2]] or UF.headers[p[2]]) or p[2]
    local mover=UF:CreateMover(key,owner)
    UF:PlaceMover(key,mover,p[1],relative or UIParent,p[3],p[4],p[5])
    owner:ClearAllPoints();owner:SetPoint('TOPLEFT',mover,'TOPLEFT')
end

local function headerAttributes(key,config)
    local party=key=='party'
    local growth=config.growthDirection or 'DOWN'
    local primary,secondary=growth:match('^([^_]+)_?(.*)$')
    local horizontal=primary=='LEFT' or primary=='RIGHT'
    local left=primary=='LEFT'
    local up=primary=='UP'
    local groupSize=5
    local attrs={showParty=party,showRaid=not party,showPlayer=config.showPlayer~=false,showSolo=false,
        point=horizontal and (left and 'RIGHT' or 'LEFT') or (up and 'BOTTOM' or 'TOP'),
        xOffset=horizontal and (left and -1 or 1)*(config.horizontalSpacing or 3) or 0,
        yOffset=horizontal and 0 or (up and 1 or -1)*(config.verticalSpacing or 3),unitsPerColumn=groupSize,
        maxColumns=party and 1 or 8,columnSpacing=config.groupSpacing or 0,
        columnAnchorPoint=horizontal and (secondary=='UP' and 'BOTTOM' or 'TOP') or (secondary=='LEFT' and 'RIGHT' or 'LEFT'),
        sortMethod=config.sortMethod or 'INDEX',sortDir=config.sortDir or 'ASC',
        ['oUF-initialConfigFunction']=string.format('self:SetWidth(%.8f) self:SetHeight(%.8f)',config.width,config.height)}
    if key=='tank' then attrs.groupFilter='MAINTANK';attrs.groupingOrder=nil
    elseif key=='assist' then attrs.groupFilter='MAINASSIST';attrs.groupingOrder=nil
    elseif not party then attrs.groupBy='GROUP';attrs.groupingOrder='1,2,3,4,5,6,7,8' end
    return attrs
end

function UF:ConfigureGroupTargets(key,parentConfig,parentHeader)
    local extra=parentConfig.targetsGroup
    if not extra or not extra.enable then
        local childKey=key..'_target'
        if self.headers[childKey] then
            UnregisterStateDriver(self.headers[childKey],'visibility');self.headers[childKey]:Hide()
        end
        if self.db.units[childKey] then self.db.units[childKey].enable=false end
        return
    end
    local childKey=key..'_target'
    local c=self.db.units[childKey]
    if not c then
        c=Import:DefaultUnit('targettarget')
        c.portrait.enable=false;c.power.enable=false;c.castbar.enable=false
        c.buffs.enable=false;c.debuffs.enable=false;c.name.size=8
        c.name.text_format='[sqon:name]';c.name.attachTextTo='Health'
        self.db.units[childKey]=c
    end
    c.enable=parentConfig.enable and extra.enable
    c.width=extra.width or c.width;c.height=extra.height or c.height
    c.fader=Import:Copy(parentConfig.fader)
    c.growthDirection=parentConfig.growthDirection
    local attrs=headerAttributes(key,parentConfig)
    attrs['oUF-initialConfigFunction']=string.format("self:SetWidth(%.8f) self:SetHeight(%.8f) self:SetAttribute('unitsuffix','target')",c.width,c.height)
    -- Align each secondary secure-header row with its corresponding main row.
    if attrs.point=='TOP' then attrs.yOffset=-(parentConfig.height+(parentConfig.verticalSpacing or 3)-c.height)
    elseif attrs.point=='BOTTOM' then attrs.yOffset=parentConfig.height+(parentConfig.verticalSpacing or 3)-c.height
    elseif attrs.point=='LEFT' then attrs.xOffset=parentConfig.width+(parentConfig.horizontalSpacing or 3)-c.width
    else attrs.xOffset=-(parentConfig.width+(parentConfig.horizontalSpacing or 3)-c.width) end
    local header=self.headers[childKey]
    if not header then
        oUF:RegisterStyle('SquanchOn_'..childKey,function(frame,unit) style(frame,unit,childKey) end)
        oUF:SetActiveStyle('SquanchOn_'..childKey)
        header=oUF:SpawnHeader('SquanchOnUF_'..unitNames[key]..'TargetsHeader',nil,attrs)
        self.headers[childKey]=header
    end
    for name,value in pairs(attrs) do header:SetAttribute(name,value) end
    header:ClearAllPoints()
    local left=extra.anchorPoint=='LEFT'
    header:SetPoint('TOPLEFT',parentHeader,'TOPLEFT',(left and -c.width or parentConfig.width)+(extra.xOffset or 0),extra.yOffset or 0)
    RegisterStateDriver(header,'visibility',parentConfig.visibility or (key=='party' and '[group:raid] hide;[group:party] show;hide' or '[group:raid] show;hide'))
    for _,frame in ipairs(self.objects) do if frame.squancherKey==childKey then self:ConfigureFrame(frame) end end
end

function UF:CreateAndUpdateHeaderGroup(key)
    if InCombatLockdown() then self.pending=true;return end
    local c=self.db.units[key]
    if not c or not c.enable then return end
    local header=self.headers[key]
    if not header then
        oUF:SetActiveStyle('SquanchOn_'..key)
        header=oUF:SpawnHeader('SquanchOnUF_'..unitNames[key]..'Header',key=='raidpet' and 'SecureGroupPetHeaderTemplate' or nil,headerAttributes(key,c))
        self.headers[key]=header;self[key]=header
        if key=='party' then oUF:DisableBlizzard('party') end
    end
    local attrs=headerAttributes(key,c)
    for name,value in pairs(attrs) do header:SetAttribute(name,value) end
    place(key,header)
    RegisterStateDriver(header,'visibility',c.visibility or (key=='party' and '[group:raid] hide;[group:party] show;hide' or '[group:raid] show;hide'))
    for _,frame in ipairs(self.objects) do if frame.squancherKey==key then self:ConfigureFrame(frame) end end
    self:ConfigureGroupTargets(key,c,header)
end
function UF:CreateAndUpdateUF(key)
    if InCombatLockdown() then self.pending=true;return end
    local c=self.db.units[key]
    if not c or not c.enable then return end
    local frame=self.frames[key]
    if not frame then
        oUF:SetActiveStyle('SquanchOn_'..key)
        frame=oUF:Spawn(key,'SquanchOnUF_'..unitNames[key])
        self.frames[key]=frame
    end
    self:ConfigureFrame(frame);place(key,frame)
end
function UF:CreateAndUpdateUFGroup(key,count)
    if InCombatLockdown() then self.pending=true;return end
    local c=self.db.units[key]
    if not c or not c.enable then return end
    local holder=self.headers[key]
    if not holder then
        holder=CreateFrame('Frame','SquanchOnUF_'..unitNames[key]..'Header',UIParent)
        self.headers[key]=holder;self[key]=holder
        holder:SetSize(c.width,c.height)
    end
    place(key,holder)
    for index=1,count do
        local token=key..index
        local frame=self.frames[token]
        if not frame then
            oUF:SetActiveStyle('SquanchOn_'..key)
            frame=oUF:Spawn(token,'SquanchOnUF_'..unitNames[key]..index)
            self.frames[token]=frame
        end
        self:ConfigureFrame(frame);frame:ClearAllPoints()
        local horizontal=c.growthDirection=='LEFT' or c.growthDirection=='RIGHT'
        frame:SetPoint('TOPLEFT',holder,'TOPLEFT',horizontal and (index-1)*(c.width+(c.spacing or 12)) or 0,
            horizontal and 0 or -(index-1)*(c.height+(c.spacing or 12)))
    end
end

function UF:Update_AllFrames()
    if InCombatLockdown() then self.pending=true;return false,'Combat' end
    local config,state=Import:Initialize()
    if not config then return false,state end
    self.db=config;self.state=state
    if self.Engine then self.Engine.db.unitframe=config;self.Engine.db.movers=config.movers end
    for _,key in ipairs(Import.units) do
        if groupTypes[key] then self:CreateAndUpdateHeaderGroup(key)
        elseif key=='boss' or key=='arena' then self:CreateAndUpdateUFGroup(key,5)
        else self:CreateAndUpdateUF(key) end
    end
    for _,frame in ipairs(self.objects) do
        local c=self.db.units[frame.squancherKey]
        if c and c.enable then
            if frame.squancherUnitHidden then frame.squancherUnitHidden=nil;RegisterUnitWatch(frame) end
        else UnregisterUnitWatch(frame);frame:Hide();frame.squancherUnitHidden=true end
    end
    for key,header in pairs(self.headers) do
        local parentKey=key:match('^(.-)_target$')
        if not self.db.units[key] or not self.db.units[key].enable or parentKey and not self.db.units[parentKey].enable then
            UnregisterStateDriver(header,'visibility');header:Hide()
        end
    end
    self.pending=false
    self:RegisterLayoutTargets()
    return true
end

function UF:RegisterLayoutTargets()
    local editor=ns.LayoutEditor
    if not editor or not self.Initialized then return end
    self.layoutRegistered=self.layoutRegistered or {}
    for key,mover in pairs(self.movers) do
        if not self.layoutRegistered[key] then
            local id=key
            editor:Register({id='uf_'..id,label=(unitNames[id] or id)..' unit frame',resize=not groupTypes[id] and id~='boss' and id~='arena' and 'free' or false,fixedBorderSize=true,
                getFrame=function() return UF.movers[id] end,
                getBoundsFrames=function()
                    if groupTypes[id] or id=='boss' or id=='arena' then
                        local frames={}
                        for _,frame in ipairs(UF.objects) do if frame.squancherKey==id then frames[#frames+1]=frame end end
                        return frames
                    end
                    return {UF.movers[id].parent}
                end,
                snapshot=function() return {profile=UF.state.profile,mover=Import:Copy(UF.db.movers[id]),
                    width=UF.db.units[id] and UF.db.units[id].width,height=UF.db.units[id] and UF.db.units[id].height} end,
                commit=function(rect,resizing)
                    if InCombatLockdown() then return false,'Combat' end
                    local current=UF.movers[id]
                    if not current or not rect or rect.w<=0 or rect.h<=0 then return false,'Unavailable' end
                    if resizing and UF.db.units[id] then
                        local before=editor:Rect(current)
                        local width,height=current:GetSize()
                        if not before then return false,'Unavailable' end
                        UF.db.units[id].width=numeric(rect.w*width/before.w,100,15,1000)
                        UF.db.units[id].height=numeric(rect.h*height/before.h,34,5,500)
                        UF:Update_AllFrames()
                    end
                    editor:Place(current,rect)
                    UF.db.movers[id]={x=current:GetLeft(),y=current:GetTop()}
                    return true
                end,
                restore=function(saved)
                    if InCombatLockdown() then return false,'Combat' end
                    if not saved or saved.profile~=UF.state.profile then return false,'Profile changed' end
                    UF.db.movers[id]=Import:Copy(saved.mover)
                    if UF.db.units[id] then UF.db.units[id].width=saved.width;UF.db.units[id].height=saved.height end
                    UF:Update_AllFrames()
                    local p=defaultPositions[id] or {'CENTER',UIParent,'CENTER',0,0}
                    local relative=type(p[2])=='string' and UF.frames[p[2]] or p[2]
                    UF:PlaceMover(id,UF.movers[id],p[1],relative or UIParent,p[3],p[4],p[5]);return true
                end})
            self.layoutRegistered[key]=true
        end
    end
end

local function rangeBoolean(func,...)
    if type(func)~='function' then return nil end
    local ok,value=pcall(func,...)
    if not ok or not public(value) then return nil end
    if value==true or value==1 then return true end
    if value==false or value==0 then return false end
end

function UF:KnownRangeSpells(kind)
    local _,class=UnitClass('player')
    if not public(class) or type(class)~='string' then return {} end
    local source=self.db.rangeCheck
    if not self.rangeCache or self.rangeCache.source~=source or self.rangeCache.class~=class then
        self.rangeCache={source=source,class=class}
    end
    local cache=self.rangeCache
    if cache[kind] then return cache[kind] end
    local known={}
    local bank=Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    local configured=source and source[kind] and source[kind][class] or {}
    for _,id in ipairs(configured) do
        local selected
        if C_SpellBook and C_SpellBook.IsSpellKnown and bank then
            selected=rangeBoolean(C_SpellBook.IsSpellKnown,id,bank)
        elseif IsPlayerSpell then selected=rangeBoolean(IsPlayerSpell,id) end
        if selected==true then known[#known+1]=id end
    end
    cache[kind]=known
    return known
end

function UF:RangeState(unit)
    if not public(unit) or type(unit)~='string' then return nil end
    if rangeBoolean(UnitIsConnected,unit)==false then return nil end
    local kind
    if rangeBoolean(UnitIsUnit,unit,'pet')==true then kind='PET'
    elseif rangeBoolean(UnitCanAttack,'player',unit)==true then kind='ENEMY'
    elseif rangeBoolean(UnitCanAssist,'player',unit)==true then
        local dead=rangeBoolean(UnitIsDeadOrGhost,unit)
        if dead==true then kind='RESURRECT' elseif dead==false then kind='FRIENDLY' end
    end
    if kind and C_Spell and C_Spell.IsSpellInRange then
        for _,id in ipairs(self:KnownRangeSpells(kind)) do
            local inRange=rangeBoolean(C_Spell.IsSpellInRange,id,unit)
            if inRange~=nil then return inRange end
        end
    end
    -- Native group range remains useful when no configured spell can answer.
    local ok,inRange,checked=pcall(UnitInRange,unit)
    if ok and public(inRange) and public(checked) and checked==true then
        if inRange==true then return true elseif inRange==false then return false end
    end
    return nil
end

local function fade(frame)
    local c=frame.squancherConfig.fader
    if not c.enable then frame.squancherFadeAlpha=nil;frame:SetAlpha(1);return end
    local unit=frame.__unit
    local alpha=c.maxAlpha or 1
    if c.range and unit~='player' then
        if UF:RangeState(unit)==false then alpha=c.minAlpha or .35 end
    elseif frame.squancherKey=='player' then
        local combat=UnitAffectingCombat('player')
        local visible=(c.combat and public(combat) and combat) or (c.hover and frame:IsMouseOver())
            or (c.playertarget and UnitExists('target')) or (c.casting and (UnitCastingInfo('player') or UnitChannelInfo('player')))
        if c.health then
            local current,maximum=UnitHealth('player'),UnitHealthMax('player')
            if not public(current) or not public(maximum) then visible=true
            elseif current<maximum then visible=true end
        end
        if not visible then alpha=c.minAlpha or 0 end
    end
    if frame.squancherFadeAlpha~=alpha then
        frame.squancherFadeAlpha=alpha;frame:SetAlpha(alpha)
    end
end

function UF.GetProfile() return UF.db and {unitframe=UF.db,movers=UF.db.movers} end
function UF:RequestReload()
    if InCombatLockdown() then self.reloadAfterCombat=true;return false,'Combat' end
    ReloadUI();return true
end
function UF.RefreshStatus()
    UF.status.initialized=UF.Initialized;UF.status.originalEngine=false
    UF.status.profile=UF.state and UF.state.profile;UF.status.frameCount=#UF.objects
    return UF.status
end
local function initialize()
    if UF.Initialized then return end
    if not oUF then UF.status.error='SquanchOnUF engine did not load (check X-oUF and load order)';return end
    if InCombatLockdown() then UF.pending=true;return end
    local config,state=Import:Initialize()
    if not config then UF.status.error=state;return end
    UF.db=config;UF.state=state;installTags()
    -- A local adapter for Squancher's existing decoration code, never _G.ElvUI.
    local engine={db={unitframe=config,movers=config.movers},oUF=oUF,Initialized=true,mult=1,
        media={bordercolor={r=.70,g=.532,b=.294},unitframeBorderColor={r=.70,g=.532,b=.294}},
        data={GetCurrentProfile=function() return UF.state.profile end}}
    function engine:GetModule(name) if name=='UnitFrames' then return UF end end
    function engine:ClassColor(class) return RAID_CLASS_COLORS[class] end
    function engine:Scale(value) return value end
    function engine:LoadMovers() UF:RegisterLayoutTargets() end
    function engine:UpdateAll() return UF:Update_AllFrames() end
    UF.Engine=engine;UF.Original=UF;UF.units=UF.frames
    for _,key in ipairs(Import.units) do
        local unit=key
        oUF:RegisterStyle('SquanchOn_'..unit,function(frame,token) style(frame,token,unit) end)
    end
    -- oUF takes a per-layout color table through .colors; avoid changing global shared data.
    UF.Initialized=true
    oUF:RegisterInitCallback(function(frame)
        if frame.squancherKey then UF:ConfigureFrame(frame) end
    end)
    UF:Update_AllFrames();UF.RefreshStatus()
    local updater=CreateFrame('Frame')
    local elapsed=0
    updater:SetScript('OnUpdate',function(_,delta)
        elapsed=elapsed+delta
        if elapsed<.2 then return end
        elapsed=0
        for _,frame in ipairs(UF.objects) do if frame:IsVisible() then fade(frame) end end
    end)
end
local events=CreateFrame('Frame')
events:RegisterEvent('PLAYER_LOGIN');events:RegisterEvent('PLAYER_REGEN_ENABLED');events:RegisterEvent('ADDON_LOADED')
events:RegisterEvent('SPELLS_CHANGED');events:RegisterEvent('PLAYER_SPECIALIZATION_CHANGED')
events:SetScript('OnEvent',function(_,event,loaded)
    if event=='SPELLS_CHANGED' or event=='PLAYER_SPECIALIZATION_CHANGED' then UF.rangeCache=nil;return end
    if event=='ADDON_LOADED' and (loaded~=addonName or not IsLoggedIn()) then return end
    if event=='PLAYER_REGEN_ENABLED' and UF.reloadAfterCombat then ReloadUI();return end
    if not UF.Initialized then initialize()
    elseif UF.pending then UF:Update_AllFrames() end
end)
if IsLoggedIn() then initialize() end
