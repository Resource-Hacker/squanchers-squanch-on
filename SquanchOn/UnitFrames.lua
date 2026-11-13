-- SPDX-License-Identifier: MIT
-- Squanch-On unit-frame layout, MIT. Secure unit state/render updates belong to oUF.
-- Requires the independently MIT licensed oUF_Forever.xml and ## X-oUF: SquanchOnUF.
local addonName, ns = ...
local unpack=unpack or table.unpack
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

-- Imported media names are identities, not hints for a substitute font.
function UF:Scale(value)
    local m=self.pixelMult or 1
    if value==0 or m==1 then return value end
    local quantized=m>1 and math.ceil(math.abs(value)/m) or math.floor(math.abs(value)/m)
    return (value<0 and -1 or 1)*quantized*m
end
local function setPoint(object,...)
    local args={...}
    for i,value in ipairs(args) do if type(value)=='number' then args[i]=UF:Scale(value) end end
    object:SetPoint(unpack(args))
end
local function setSize(object,w,h) object:SetSize(UF:Scale(w),UF:Scale(h)) end
local function setWidth(object,w) object:SetWidth(UF:Scale(w)) end
local function setHeight(object,h) object:SetHeight(UF:Scale(h)) end

function UF:Resolve(kind,name,fallback)
    local path=ns.Media and ns.Media:Resolve(kind,name)
    if path then return path end
    self.status.missingMedia=self.status.missingMedia or {}
    self.status.missingMedia[kind..':'..tostring(name)]=true
    if type(name)=='string' and (name:find('\\') or name:find('/'))
        and not name:find('AddOns',1,true) then return name end
    return fallback
end
function UF:Font(name) return self:Resolve('font',name,bundledFont) end
function UF:Texture(name) return self:Resolve('statusbar',name,'Interface\\TargetingFrame\\UI-StatusBar') end
local function color(c,r,g,b,a)
    return c and c.r or r,c and c.g or g,c and c.b or b,c and c.a or a
end
function UF:SetStatusBarColor(bar,r,g,b,a)
    local m=self.db.multiplier or .35
    local fill=bar.isTransparent and math.min(1,m*2) or a or 1
    local back=bar.backgroundMultiplier or (bar.isTransparent and m*.5 or m)
    local br,bg,bb,ba=color(bar.custom_backdrop,r,g,b,back)
    local texture=bar:GetStatusBarTexture()
    if bar.invertColors then
        if texture then texture:SetVertexColor(br,bg,bb,ba) end
        if bar.bg then bar.bg:SetVertexColor(r,g,b,fill) end
    else
        if texture then texture:SetVertexColor(r,g,b,fill) end
        if bar.bg then bar.bg:SetVertexColor(br,bg,bb,ba) end
    end
end
function UF:ApplyFont(object,path,size,outline)
    local style=outline or self.db.fontOutline or ''
    if style=='NONE' then style='' end
    local shadow=style:sub(1,6)=='SHADOW'
    if shadow then style=style:sub(7) end
    object:SetFont(self:Font(path or self.db.font),size or self.db.fontSize,style)
    object:SetShadowColor(0,0,0,shadow and (style=='' and 1 or .6) or 0)
    object:SetShadowOffset(shadow and 1 or 0,shadow and -1 or 0)
end
local function font(parent,size,path,outline)
    local fs=parent:CreateFontString(nil,'OVERLAY')
    UF:ApplyFont(fs,path,size,outline)
    return fs
end
local function background(frame)
    local bg=CreateFrame('Frame',nil,frame,'BackdropTemplate')
    local border=UF.BORDER or 1
    setPoint(bg,'TOPLEFT',frame,'TOPLEFT',-border,border)
    setPoint(bg,'BOTTOMRIGHT',frame,'BOTTOMRIGHT',border,-border)
    bg:SetFrameLevel(math.max(0,frame:GetFrameLevel()-1))
    bg:SetBackdrop({bgFile=white,edgeFile=white,edgeSize=border})
    bg:SetBackdropColor(0,0,0,1);bg:SetBackdropBorderColor(0,0,0,1)
    frame.backdrop=bg
    return bg
end
local function raised(parent,level)
    local f=CreateFrame('Frame',nil,parent);f:SetAllPoints(parent)
    f:SetFrameLevel(level);f:EnableMouse(false);return f
end
local function bar(parent,name)
    local b=CreateFrame('StatusBar',name,parent)
    b:SetStatusBarTexture(UF:Texture(UF.db.statusbar))
    b:SetMinMaxValues(0,1);b:SetValue(1)
    b.bg=b:CreateTexture(nil,'BORDER');b.bg:SetAllPoints();b.bg:SetTexture(white)
    background(b)
    b.ClipFrame=raised(b,b:GetFrameLevel()+1);b.ClipFrame:SetClipsChildren(true)
    b.RaisedElementParent=raised(b,b:GetFrameLevel()+2)
    return b
end
local function anchor(frame,region,config,defaultPoint)
    local point=config.position or config.justifyH or defaultPoint or 'CENTER'
    if point=='MIDDLE' then point='CENTER' end
    frame:ClearAllPoints()
    setPoint(frame,point,region,point,config.xOffset or 0,config.yOffset or 0)
end
function UF:PaintBar(bar,kind,config)
    local colors=self.db.colors
    bar.isTransparent=colors['transparent'..kind]==true
    bar.invertColors=colors['invert'..kind]==true
    local textures=(self.db.benikui or {}).unitframes and self.db.benikui.unitframes.textures or {}
    local name=self.db.statusbar
    if kind=='Power' and textures.enablePower then name=textures.power or name end
    if kind=='Health' and (bar.__ownerKey=='party' or (bar.__ownerKey or ''):match('^raid'))
        and textures.enableHealth and (not bar.isTransparent or textures.ignoreTransparency) then name=textures.health or name end
    local path=bar.isTransparent and white or self:Texture(name)
    bar:SetStatusBarTexture(path);bar.bg:SetTexture(path)
    local br,bg,bb,ba=color(self.db.general.backdropfadecolor,.054,.054,.054,.75)
    if bar.isTransparent then bar.backdrop:SetBackdropColor(br,bg,bb,ba)
    else bar.backdrop:SetBackdropColor(0,0,0,1) end
    local key=kind:lower()
    bar.custom_backdrop=colors['custom'..key..'backdrop'] and colors[key..'_backdrop'] or nil
    bar.backgroundMultiplier=kind=='Health' and colors.healthMultiplier and colors.healthMultiplier>0 and colors.healthMultiplier or nil
    if kind=='Health' then
        -- Only the missing-health region owns the backdrop tint.
        local tex=bar:GetStatusBarTexture();local reverse=config.reverseFill
        bar.bg:ClearAllPoints()
        if reverse then
            setPoint(bar.bg,'TOPRIGHT',tex,'TOPLEFT');setPoint(bar.bg,'BOTTOMRIGHT',tex,'BOTTOMLEFT')
            setPoint(bar.bg,'BOTTOMLEFT',bar,'BOTTOMLEFT')
        else
            setPoint(bar.bg,'TOPLEFT',tex,'TOPRIGHT');setPoint(bar.bg,'BOTTOMLEFT',tex,'BOTTOMRIGHT')
            setPoint(bar.bg,'BOTTOMRIGHT',bar,'BOTTOMRIGHT')
        end
    else bar.bg:SetAllPoints(bar) end
end

local tagMap={['name:medium']='sqon:name',['name:short']='sqon:shortname',
    ['namecolor']='sqon:namecolor',['classcolor']='sqon:classcolor',
    ['healthcolor']='sqon:healthcolor',['health:current']='sqon:health',
    ['health:max']='maxhp',['health:percent']='sqon:healthpercent',
    ['power:current']='curpp',['power:max']='maxpp',['power:percent']='perpp',
    ['difficultycolor']='sqon:difficultycolor',['classification:icon']='sqon:classification',
    ['class:icon']='sqon:classicon',['faction:icon']='sqon:factionicon',
    ['happiness:icon']='sqon:happiness',['smartlevel']='sqon:smartlevel'}
local function installTags()
    local methods,events=oUF.Tags.Methods,oUF.Tags.Events
    local function boundedName(unit,limit)
        local name=UnitName(unit)
        if not public(name) or type(name)~='string' then return name end
        local count=0
        for offset in name:gmatch('()[^\128-\191]') do
            count=count+1
            if count>limit then return name:sub(1,offset-1) end
        end
        return name
    end
    methods['sqon:name']=function(unit) return boundedName(unit,15) end
    methods['sqon:shortname']=function(unit) return boundedName(unit,10) end
    local function hex(c)
        if not c then return '' end
        if c.GenerateHexColorMarkup then return c:GenerateHexColorMarkup() end
        return string.format('|cff%02x%02x%02x',c.r*255,c.g*255,c.b*255)
    end
    methods['sqon:classcolor']=function(unit)
        local _,class=UnitClass(unit)
        return hex(public(class) and (UF.palette.class[class] or RAID_CLASS_COLORS[class]))
    end
    methods['sqon:namecolor']=function(unit)
        local isPlayer=UnitIsPlayer(unit)
        if public(isPlayer) and isPlayer then return methods['sqon:classcolor'](unit) end
        local reaction=UnitReaction(unit,'player')
        return hex(public(reaction) and UF.palette.reaction[reaction])
    end
    methods['sqon:healthcolor']=function(unit)
        local frameColor=UF.palette.health
        if UnitHealthPercent and CurveConstants then
            local percentage=UnitHealthPercent(unit,true,CurveConstants.ScaleTo100)
            if public(percentage) and type(percentage)=='number' then
                local r,g,b=oUF:ColorGradient(percentage/100,1,0,0,1,1,0,0,1,0)
                return hex(CreateColor(r,g,b))
            end
        end
        return hex(frameColor)
    end
    local function status(unit)
        local connected=UnitIsConnected(unit)
        if public(connected) and not connected then return 'OFFLINE' end
        local dead=UnitIsDeadOrGhost(unit)
        if public(dead) and dead then return 'DEAD' end
    end
    methods['sqon:health']=function(unit) return status(unit) or methods.curhp(unit) end
    methods['sqon:healthpercent']=function(unit)
        local state=status(unit);if state then return state end
        local value=methods.perhp(unit)
        if public(value) then return value and tostring(value)..'%' end
        if C_StringUtil and C_StringUtil.WrapString then return C_StringUtil.WrapString(value,'','%') end
        return value
    end
    methods['sqon:factionicon']=function(unit)
        local faction=UnitFactionGroup(unit)
        if not public(faction) then return '' end
        if faction=='Horde' or faction=='Alliance' then
            return '|TInterface\\FriendsFrame\\PlusManz-'..faction..':16:16|t'
        end
        return ''
    end
    methods['sqon:classicon']=function(unit)
        local _,class=UnitClass(unit)
        if not public(class) or not class then return '' end
        local coords=CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
        if coords then
            return string.format('|TInterface\\WorldStateFrame\\Icons-Classes:0:0:0:0:256:256:%d:%d:%d:%d|t',
                coords[1]*256,coords[2]*256,coords[3]*256,coords[4]*256)
        end
        return ''
    end
    methods['sqon:classification']=function(unit)
        local class=UnitClassification(unit)
        if not public(class) then return '' end
        if class=='elite' or class=='worldboss' then return '|A:nameplates-icon-elite-gold:16:16|a' end
        if class=='rare' or class=='rareelite' then return '|A:nameplates-icon-elite-silver:16:16|a' end
        return ''
    end
    methods['sqon:difficultycolor']=function(unit)
        local level=UnitEffectiveLevel and UnitEffectiveLevel(unit) or UnitLevel(unit)
        if not public(level) then return '' end
        return hex(GetCreatureDifficultyColor(level))
    end
    methods['sqon:smartlevel']=function(unit)
        local level=UnitLevel(unit)
        if public(level) and level==-1 then return '??' end
        return level
    end
    methods['sqon:happiness']=function(unit)
        local happinessAPI=C_PetInfo and C_PetInfo.GetPetHappiness or GetPetHappiness
        if not happinessAPI then return '' end
        local isPet=UnitIsUnit(unit,'pet')
        if public(isPet) and isPet then
            local happiness=happinessAPI()
            if public(happiness) and happiness then
                local left=(3-happiness)*.1875
                return string.format('|TInterface\\PetPaperDollFrame\\UI-PetHappiness:16:16:0:0:128:64:%d:%d:0:23|t',left*128,(left+.1875)*128)
            end
        end
        return ''
    end
    -- Each tag listens only for what it reads, so a health tick rebuilds the
    -- health texts and nothing else. A unit swap refreshes every tag through
    -- oUF's own frame update. Tags not listed keep the full list.
    local own={
        ['sqon:name']='UNIT_NAME_UPDATE',['sqon:shortname']='UNIT_NAME_UPDATE',
        ['sqon:classcolor']='UNIT_NAME_UPDATE',['sqon:classicon']='UNIT_NAME_UPDATE',
        ['sqon:namecolor']='UNIT_NAME_UPDATE UNIT_FACTION UNIT_FLAGS',
        ['sqon:factionicon']='UNIT_NAME_UPDATE UNIT_FACTION',
        ['sqon:classification']='UNIT_NAME_UPDATE UNIT_CLASSIFICATION_CHANGED',
        ['sqon:difficultycolor']='UNIT_LEVEL PLAYER_LEVEL_UP',['sqon:smartlevel']='UNIT_LEVEL PLAYER_LEVEL_UP'}
    for key in pairs(methods) do
        if type(key)=='string' and key:match('^sqon:') then
            events[key]=own[key] or 'UNIT_NAME_UPDATE UNIT_FACTION UNIT_FLAGS UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION UNIT_LEVEL'
        end
    end
end
function UF:TagFormat(value)
    if type(value)~='string' then return '' end
    return (value:gsub('%[([^%]]+)%]',function(spec)
        local prefix,tag,suffix=spec:match('^(.-)>([^<]+)(.*)$')
        if not tag then tag,suffix=spec:match('^([^<]+)(.*)$');prefix='' else prefix=prefix..'>' end
        local inactive={['healthcolor']=true,['health:current']=true,['health:percent']=true,['power:current']=true}
        if self.db.modernLegacyTagsInactive and inactive[tag] then
            self.status.preservedInactiveTags=self.status.preservedInactiveTags or {};self.status.preservedInactiveTags[tag]=true
            return ''
        end
        local mapped=tagMap[tag] or tag
        if oUF.Tags.Methods[mapped] then return '['..prefix..mapped..(suffix or '')..']' end
        self.status.unsupportedTags=self.status.unsupportedTags or {};self.status.unsupportedTags[tag]=true
        return ''
    end))
end

local function makeText(frame,key,config,size)
    local fs=font(frame.TextOverlay,size or config.size or UF.db.fontSize,config.font,config.fontOutline)
    frame.customTexts=frame.customTexts or {}
    frame.customTexts[key]=fs
    return fs
end
local function textRegion(frame,config)
    return config.attachTextTo=='Health' and frame.Health or config.attachTextTo=='Power' and frame.Power
        or config.attachTextTo=='Portrait' and frame.Portrait or frame
end
local function configureText(frame,fs,config,defaultPoint)
    local value=UF:TagFormat(config.text_format)
    if value=='' or config.enable==false then frame:Untag(fs);fs:SetText('');fs:Hide();return end
    local region=textRegion(frame,config) or frame
    anchor(fs,region,config,defaultPoint)
    fs:SetJustifyH(config.justifyH or (config.position=='LEFT' and 'LEFT' or config.position=='RIGHT' and 'RIGHT' or 'CENTER'))
    UF:ApplyFont(fs,config.font or UF.db.font,config.size or UF.db.fontSize,config.fontOutline or UF.db.fontOutline)
    frame:Tag(fs,value);fs:Show()
end

local function tooltipEnter(frame)
    if not frame.__unit or GameTooltip:IsForbidden() then return end
    GameTooltip:SetOwner(frame,'ANCHOR_RIGHT');GameTooltip:SetUnit(frame.__unit)
end
local function tooltipLeave() if not GameTooltip:IsForbidden() then GameTooltip:Hide() end end

local function newAura(frame,key)
    -- Icons are created and painted by UnitFrameAuras.lua (the embedded oUF
    -- registers no aura element on this client).
    return CreateFrame('Frame',frame:GetName()..key,frame)
end
-- Aura settings (SquanchOnDB.auras). The defaults are the layout that was fixed
-- in code before these settings existed.
-- split: player and target carry both rows on one line beside the frame: one
-- kind from each end, growing toward the middle and leaving a clear gap, with
-- overflow stacking on its own side. `left` names the kind on the left end;
-- `cells` (optional) replaces the frame's saved icons-per-row.
-- small: false keeps the frame without aura rows (owner, 2026-11-11); true
-- lets its saved rows apply.
-- cell: optional countFont, countSize and countPosition replace each row's saved value.
UF.auraDefaults={
    split={
        player={enable=true,left='Debuffs',gap=1,rows=4,yOffset=5,grow='UP',allBuffs=true},
        target={enable=true,left='Buffs',gap=1,rows=4,yOffset=5,grow='UP',allBuffs=false}},
    small={targettarget=false,targettargettarget=false,pettarget=false,focustarget=false},
    cell={rim=true,desaturate='SAVED',swipe=true,numbers=false},
    bars={
        Buffs={enable=true,size=30,perRow=12,max=36,growthX='LEFT',growthY='DOWN',sortMethod='TIME_REMAINING',
            sortDirection='DESCENDING',countdown=true,countdownSize=11,countSize=10},
        Debuffs={enable=true,size=30,perRow=12,max=36,growthX='LEFT',growthY='DOWN',sortMethod='TIME_REMAINING',
            sortDirection='DESCENDING',countdown=true,countdownSize=11,countSize=10}},
    hideBlizzard=true,weaponEnchants=true,previewCount=6}
local function fillAuraDefaults(target,defaults)
    for key,value in pairs(defaults) do
        if type(value)=='table' then
            if type(target[key])~='table' then target[key]={} end
            fillAuraDefaults(target[key],value)
        elseif target[key]==nil then target[key]=value end
    end
end
local auraFilled
function UF:AuraSettings()
    local db=ns.db;if not db then return self.auraDefaults end
    local settings=db.auras
    if type(settings)~='table' then settings={};db.auras=settings end
    if auraFilled~=settings then fillAuraDefaults(settings,self.auraDefaults);auraFilled=settings end
    return settings
end
local function configureAura(frame,key,config)
    local c=frame[key]
    local settings=UF:AuraSettings()
    if settings.small[frame.squancherKey]==false then config=Import:Copy(config);config.enable=false end
    local split=settings.split[frame.squancherKey]
    local side=split and split.enable and (split.left==key and 'LEFT' or 'RIGHT')
    if side then
        local cells=numeric(split.cells or config.perrow,10,4,40)
        local down=split.grow=='DOWN'
        local lift=numeric(split.yOffset,5,-100,100)
        config=Import:Copy(config)
        config.enable=true;config.attachTo='FRAME';config.sizeOverride=0
        config.anchorPoint=(down and 'BOTTOM' or 'TOP')..side
        config.growthX=side=='LEFT' and 'RIGHT' or 'LEFT';config.growthY=down and 'DOWN' or 'UP'
        config.xOffset=0;config.yOffset=down and -lift or lift
        config.perrow=math.max(1,math.floor((cells-numeric(split.gap,1,0,38))/2));config.numrows=numeric(split.rows,4,1,8)
        -- The player's saved buff filter keeps only defensives (it was written
        -- for a hidden row); on the shared line every buff is shown.
        if split.allBuffs and key=='Buffs' then config.filterLists=nil;config.priority='' end
        c.cellsAcross=cells;c.splitLift=down and 0 or lift
    else c.cellsAcross=nil;c.splitLift=nil end
    local perRow=numeric(config.perrow,8,1,40)
    local size=numeric(config.sizeOverride,0,0,100)
    -- Cells abut like the action bars; the saved spacing only applies to a fixed size.
    local gap=size==0 and 0 or config.spacing or 1
    if size==0 then size=math.max(8,frame:GetWidth()/(c.cellsAcross or perRow)) end
    local rows=numeric(config.numrows,1,1,8)
    c.size=size;c.spacing=gap
    c.visibleLimit=math.floor(perRow*rows);c.config=config
    -- Placement rule of the layout being reproduced: the row hangs off the
    -- chosen frame corner and grows away from it, it does not sit inside it.
    local anchorPoint=config.anchorPoint or (key=='Buffs' and 'TOPLEFT' or 'BOTTOMLEFT')
    local growthX=(anchorPoint=='LEFT' or anchorPoint=='RIGHT') and anchorPoint or config.growthX or 'RIGHT'
    local growthY=(anchorPoint=='TOP' or anchorPoint=='BOTTOM') and anchorPoint=='TOP' and 'UP'
        or anchorPoint=='BOTTOM' and 'DOWN' or config.growthY or 'UP'
    c['growth-x']=growthX;c['growth-y']=growthY
    local inverse={TOP='BOTTOM',BOTTOM='TOP',LEFT='RIGHT',RIGHT='LEFT'}
    c.initialAnchor=inverse[anchorPoint]
        or (growthY=='DOWN' and 'TOP' or 'BOTTOM')..(growthX=='LEFT' and 'RIGHT' or 'LEFT')
    setSize(c,perRow*(size+c.spacing)-c.spacing,rows*(size+c.spacing)-c.spacing)
    c:ClearAllPoints()
    local attach=config.attachTo
    local relative=attach=='BUFFS' and key~='Buffs' and frame.Buffs or attach=='DEBUFFS' and key~='Debuffs' and frame.Debuffs
        or attach=='HEALTH' and frame.Health or attach=='POWER' and frame.Power or frame
    local fx,fy=0,UF.SPACING
    if attach=='HEALTH' or attach=='POWER' then fx,fy=-UF.BORDER,UF.BORDER
    elseif relative==frame then fx,fy=UF.SPACING,0 end
    local signs={TOP={0,1},TOPLEFT={1,1},TOPRIGHT={-1,1},BOTTOM={0,-1},BOTTOMLEFT={1,-1},
        BOTTOMRIGHT={-1,-1},LEFT={-1,0},RIGHT={1,0},CENTER={0,0}}
    local sign=signs[anchorPoint] or signs.CENTER;local sx,sy=sign[1],sign[2]
    local x=sx*fx+(config.xOffset or 0)+(relative==frame and frame.ORIENTATION~='LEFT' and frame.POWERBAR_OFFSET or 0)
    local y=sy*fy+(config.yOffset or 0)
    -- Split rows clear an attached class bar while it shows segments.
    c.squancherPlace=function()
        local bar,first=frame.db.classbar,frame.ClassPower and frame.ClassPower[1]
        local lifted=side and growthY=='UP' and first and first:IsShown() and frame.ClassBarHolder:IsShown() and not (bar and bar.detachFromFrame)
        c.classLift=lifted and (bar and bar.height or 10)+3 or 0
        c:ClearAllPoints();setPoint(c,c.initialAnchor,relative,anchorPoint,x,y+c.classLift)
    end
    c.squancherPlace()
    if side and frame.ClassPower and frame.ClassPower[1] and not frame.squancherClassLift then
        frame.squancherClassLift=true
        -- Aura rows, glows and aura bars are unprotected children: safe in combat.
        local function place()
            for _,row in ipairs({frame.Buffs,frame.Debuffs}) do if row.squancherPlace then row.squancherPlace() end end
            if UF.LayoutGlows and frame.squancherState then UF:LayoutGlows(frame) end
            if UF.RefreshAuraBars and frame.db then UF:RefreshAuraBars(frame) end
        end
        frame.ClassPower[1]:HookScript('OnShow',place);frame.ClassPower[1]:HookScript('OnHide',place)
    end
    c.disableMouse=config.clickThrough or false
    c.filter=key=='Buffs' and 'HELPFUL' or 'HARMFUL'
    if enabled(config) then c:Show() else c:Hide() end
end
-- Live re-layout after an aura setting changes. Rows are unprotected children,
-- but the caller still keeps this out of combat.
function UF:ConfigureAuras(key)
    for _,frame in ipairs(self.objects) do
        local c=frame.db
        if c and frame.Buffs and frame.Debuffs and (not key or frame.squancherKey==key) then
            configureAura(frame,'Buffs',c.buffs);configureAura(frame,'Debuffs',c.debuffs)
            if self.LayoutGlows and frame.squancherState then self:LayoutGlows(frame) end
            if self.RefreshAuraIcons then self:RefreshAuraIcons(frame);self:RefreshAuraBars(frame) end
        end
    end
end

local function castColor(cast,failed)
    local frame=cast.__owner;local c=frame.db.castbar;local colors=UF.db.colors
    local custom=c.customColor;local interrupted=failed==true
    local restricted=not public(cast.notInterruptible)
    local locked=not restricted and cast.notInterruptible
    local selected=interrupted and colors.castInterruptedColor or locked and colors.castNoInterrupt or colors.castColor
    if custom and custom.enable then selected=interrupted and custom.colorInterrupted or locked and custom.colorNoInterrupt or custom.color
    elseif not interrupted and not locked and colors.castReactionColor then
        local reaction=UnitReaction(frame.__unit,'player')
        selected=public(reaction) and frame.colors.reaction[reaction] or selected
    end
    UF:SetStatusBarColor(cast,color(selected,.1,.1,.1,.9))
    local benik=UF.db.benikui.unitframes or {};local textures=benik.textures or {}
    if not cast.isTransparent and textures.enableCastbar then cast:SetStatusBarTexture(UF:Texture(textures.castbar or 'BuiFlat')) end
    local back=benik.castbarColor
    if back and back.enable then
        local r,g,b,a=color(back.castbarBackdropColor,.054,.054,.054,.75)
        cast.bg:SetColorTexture(r,g,b,1);cast.backdrop:SetBackdropColor(r,g,b,a)
    end
end
local function createCast(frame)
    local cast=bar(frame,frame:GetName()..'_Castbar');cast.__owner=frame
    cast.Text=font(cast,UF.db.fontSize);cast.Time=font(cast,UF.db.fontSize)
    setPoint(cast.Text,'LEFT',4,0);setPoint(cast.Time,'RIGHT',-4,0)
    setPoint(cast.Text,'RIGHT',cast.Time,'LEFT',-4,0)
    cast.ButtonIcon=cast:CreateTexture(nil,'ARTWORK');cast.ButtonIcon:SetTexCoord(.07,.93,.07,.93)
    cast.Icon=cast.ButtonIcon
    cast.Shield=cast:CreateTexture(nil,'OVERLAY');cast.Shield:SetAllPoints();cast.Shield:SetColorTexture(.78,.25,.25,.9)
    cast.Spark=cast:CreateTexture(nil,'OVERLAY');cast.Spark:SetColorTexture(1,1,1,.7);setSize(cast.Spark,1,20)
    cast.LatencyTexture=cast:CreateTexture(nil,'OVERLAY');cast.LatencyTexture:SetColorTexture(.8,.1,.1,.35)
    cast.SafeZone=cast.LatencyTexture
    cast.PostCastStart=function(self) castColor(self) end
    cast.PostCastInterruptible=function(self) castColor(self) end
    cast.PostCastInterrupted=function(self) castColor(self,true) end
    cast.PostCastFail=cast.PostCastInterrupted
    cast:HookScript('OnShow',function(self)
        if frame.db.castbar.overlayOnFrame=='Power' then frame.Power:SetAlpha(0);frame.Power.Text:SetAlpha(0) end
        if UF.RefreshFade then UF:RefreshFade(frame) end
    end)
    cast:HookScript('OnHide',function(self)
        frame.Power:SetAlpha(1);frame.Power.Text:SetAlpha(1)
        if UF.RefreshFade then UF:RefreshFade(frame) end
    end)
    return cast
end
local function configureCast(frame,config)
    local cast=frame.Castbar;local overlay=config.overlayOnFrame
    local region=overlay=='Power' and frame.Power or overlay=='Health' and frame.Health
    cast:ClearAllPoints()
    if region then
        local height=region:GetHeight();local icon=config.icon and config.iconAttached and height+2*(UF.BORDER+UF.SPACING)-1 or 0
        local right=frame.ORIENTATION=='RIGHT'
        setPoint(cast,'TOPLEFT',region,'TOPLEFT',right and 0 or icon,0)
        setPoint(cast,'BOTTOMRIGHT',region,'BOTTOMRIGHT',right and -icon or 0,0)
    else
        setSize(cast,numeric(config.width,frame:GetWidth(),3,1000)-2*(UF.BORDER+UF.SPACING),
            numeric(config.height,18,3,100)-2*(UF.BORDER+UF.SPACING))
        if groupTypes[frame.squancherKey] or frame.squancherKey:match('_target$')
            or frame.squancherKey=='boss' or frame.squancherKey=='arena' then
            local pos=config.positionsGroup or {}
            setPoint(cast,'TOPLEFT',frame,'BOTTOMLEFT',pos.xOffset or 0,pos.yOffset or -3)
        else
            local mover=UF:CreateMover('cast_'..frame.squancherKey,cast)
            UF:PlaceMover('cast_'..frame.squancherKey,mover,'TOP',frame,'BOTTOM',0,-8)
            setPoint(cast,'TOPLEFT',mover,'TOPLEFT')
        end
    end
    local strata=config.strataAndLevel or {}
    cast:SetFrameStrata(strata.useCustomStrata and strata.frameStrata or ((frame.squancherKey=='player' or frame.squancherKey=='target') and 'HIGH' or 'LOW'))
    cast:SetFrameLevel(strata.useCustomLevel and strata.frameLevel or 6)
    cast:SetReverseFill(config.reverse or false);cast.timeToHold=config.timeToHold or 0
    cast.Text:SetShown(not config.hideName);cast.Time:SetShown(not config.hideTime)
    for _,entry in ipairs({{'Text','customTextFont'},{'Time','customTimeFont'}}) do
        local f=config[entry[2]] or {};local object=cast[entry[1]]
        UF:ApplyFont(object,f.enable and f.font or UF.db.font,f.enable and f.fontSize or UF.db.fontSize,
            f.enable and f.fontStyle or UF.db.fontOutline)
    end
    cast.Text:ClearAllPoints();setPoint(cast.Text,'LEFT',cast,'LEFT',config.xOffsetText or 4,config.yOffsetText or 0)
    cast.Time:ClearAllPoints();setPoint(cast.Time,'RIGHT',cast,'RIGHT',config.xOffsetTime or -4,config.yOffsetTime or 0)
    setPoint(cast.Text,'RIGHT',cast.Time,'LEFT',-4,0)
    cast.ButtonIcon:ClearAllPoints()
    local iconSize=config.iconAttached and cast:GetHeight()+2*UF.BORDER or config.iconSize or cast:GetHeight()
    setSize(cast.ButtonIcon,iconSize,iconSize)
    if config.iconAttached and frame.ORIENTATION=='RIGHT' then setPoint(cast.ButtonIcon,'LEFT',cast,'RIGHT',0,0)
    elseif config.iconAttached then setPoint(cast.ButtonIcon,'RIGHT',cast,'LEFT',0,0)
    else
        local point=config.iconPosition or 'LEFT';local opposite={LEFT='RIGHT',RIGHT='LEFT',TOP='BOTTOM',BOTTOM='TOP'}
        setPoint(cast.ButtonIcon,opposite[point] or 'RIGHT',config.iconAttachedTo=='Frame' and frame or cast,
            point,config.iconXOffset or 0,config.iconYOffset or 0)
    end
    cast.Icon=config.icon~=false and cast.ButtonIcon or nil;cast.ButtonIcon:SetShown(config.icon~=false)
    cast.SafeZone=config.latency and frame.squancherKey=='player' and cast.LatencyTexture or nil
    cast.LatencyTexture:SetShown(cast.SafeZone~=nil)
    setHeight(cast.Spark,cast:GetHeight());cast.isTransparent=UF.db.colors.transparentCastbar==true
    castColor(cast)
    element(frame,'Castbar',enabled(config))
    if not enabled(config) then cast:Hide() end
end

local function configurePortrait(frame,config)
    local desired=config.style=='3D' and frame.PortraitModel or frame.PortraitTexture
    if frame.Portrait~=desired then
        element(frame,'Portrait',false)
        if frame.Portrait then frame.Portrait:Hide();frame.Portrait.backdrop:Hide() end
        frame.Portrait=desired
    end
    local portrait=frame.Portrait
    frame.Portrait3D=config.style=='3D' and portrait or nil
    frame.Portrait2D=config.style~='3D' and portrait or nil
    portrait.db=config;portrait:ClearAllPoints();portrait.backdrop:ClearAllPoints()
    if not frame.USE_PORTRAIT then portrait:Hide();portrait.backdrop:Hide();element(frame,'Portrait',false);return end
    if frame.USE_PORTRAIT_OVERLAY then
        local health=frame.Health;local texture=health:GetStatusBarTexture()
        if config.fullOverlay then portrait:SetAllPoints(health)
        elseif frame.squancherConfig.health.reverseFill then
            setPoint(portrait,'TOPLEFT',texture,'TOPLEFT');setPoint(portrait,'BOTTOMRIGHT',health,'BOTTOMRIGHT')
        else
            setPoint(portrait,'TOPLEFT',health,'TOPLEFT');setPoint(portrait,'BOTTOMRIGHT',texture,'BOTTOMRIGHT')
        end
        portrait:SetAlpha(config.overlayAlpha or .5);portrait.backdrop:Hide()
        frame.squancherPortraitPlace=nil
    else
        -- Re-applied whenever the unit button is shown again: the client can
        -- leave these child anchors unresolved after a hide/show, drawing nothing.
        local function place()
            portrait:ClearAllPoints();portrait.backdrop:ClearAllPoints()
            local right=frame.ORIENTATION=='RIGHT';local B,S=UF.BORDER,UF.SPACING
            local bar=(frame.USE_MINI_POWERBAR or frame.USE_POWERBAR_OFFSET or frame.USE_INSET_POWERBAR
                or frame.POWERBAR_DETACHED or not frame.USE_POWERBAR) and frame.Health or frame.Power
            setPoint(portrait.backdrop,right and 'TOPRIGHT' or 'TOPLEFT',frame,right and 'TOPRIGHT' or 'TOPLEFT',right and -S or S,-S)
            setPoint(portrait.backdrop,right and 'BOTTOMLEFT' or 'BOTTOMRIGHT',bar.backdrop,
                right and 'BOTTOMRIGHT' or 'BOTTOMLEFT',right and -B+3*S or B-3*S,0)
            setPoint(portrait,'TOPLEFT',portrait.backdrop,'TOPLEFT',B,-B)
            setPoint(portrait,'BOTTOMRIGHT',portrait.backdrop,'BOTTOMRIGHT',-B,B)
        end
        frame.squancherPortraitPlace=place;place()
        local general=UF.db.general
        local c=frame.squancherKey=='party' and general.backdropcolor or general.backdropfadecolor
        portrait.backdrop:SetBackdropColor(color(c,.054,.054,.054,frame.squancherKey=='party' and 1 or .75))
        portrait:SetAlpha(1);portrait.backdrop:Show()
    end
    if portrait:IsObjectType('PlayerModel') then
        portrait:SetFrameLevel(frame.Health:GetFrameLevel())
        portrait.backdrop:SetFrameLevel(portrait:GetFrameLevel()-1)
        portrait.PostUpdate=function(self,unit,changed)
            if self.state then
                self:SetCamDistanceScale(config.camDistanceScale or 1.2)
                if self.SetViewTranslation then self:SetViewTranslation((config.xOffset or 0)*100,(config.yOffset or 0)*100) end
                self:SetRotation(math.rad(config.rotation or 0))
            end
            if self.SetDesaturation then self:SetDesaturation(config.desaturation or 0) end
            if self.SetPaused then self:SetPaused(config.paused==true) end
            local shown=frame:GetAlpha()
            if issecretvalue and issecretvalue(shown) then -- left as it is; PlayerIdleFade hides the model
            else self:SetModelAlpha(shown*(frame.USE_PORTRAIT_OVERLAY and (config.overlayAlpha or .5) or 1)) end
        end
    else
        portrait.useClassBase=false
        portrait.customTexture=config.style=='Class' and 'Interface\\WorldStateFrame\\Icons-Classes' or nil
        portrait.PostUpdate=function(self,unit)
            if config.style~='Class' then self:SetTexCoord(.15,.85,.15,.85);return end
            self:SetTexture(self.customTexture)
            local _,class=UnitClass(unit);local c=public(class) and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
            if c then
                local l,r,t,b=c[1],c[2],c[3],c[4]
                if not config.keepSizeRatio then
                    local w,h=self:GetSize()
                    if w>h then local trim=(1-h/w)*(b-t)/2;t=t+trim;b=b-trim
                    elseif h>w then local trim=(1-w/h)*(r-l)/2;l=l+trim;r=r-trim end
                end
                self:SetTexCoord(l,r,t,b)
            end
        end
    end
    portrait:Show();element(frame,'Portrait',true)
end

function UF:Configure_Power(frame)
    local c=frame.squancherConfig;local p=c.power;local power=frame.Power
    power:ClearAllPoints();power.origParent=frame
    if not frame.USE_POWERBAR then element(frame,'Power',false);power:Hide();return end
    local B,S=self.BORDER,self.SPACING;local inset=B+S;local H=frame.POWERBAR_HEIGHT
    if frame.POWERBAR_DETACHED then
        local width=numeric(p.detachedWidth,c.width,3,1000)
        local mover=self:CreateMover('power_'..frame.squancherKey,power)
        setSize(mover,width,H);self:PlaceMover('power_'..frame.squancherKey,mover,'TOP',frame,'BOTTOM',0,-20)
        setPoint(power,'TOPLEFT',mover,'TOPLEFT',inset,-inset)
        setSize(power,math.max(1,width-2*inset),math.max(1,H-2*inset));power:SetFrameLevel(50)
    elseif frame.USE_MINI_POWERBAR then
        setSize(power,math.max(1,frame.POWERBAR_WIDTH-2*B),math.max(1,H-2*inset))
        local right=frame.ORIENTATION=='RIGHT'
        if frame.ORIENTATION=='MIDDLE' then
            setPoint(power,'LEFT',frame,'BOTTOMLEFT',2*B+4,(H-B)/2)
            setPoint(power,'RIGHT',frame,'BOTTOMRIGHT',-(2*B+4),(H-B)/2)
        else
            setPoint(power,right and 'LEFT' or 'RIGHT',frame,right and 'BOTTOMLEFT' or 'BOTTOMRIGHT',
                (right and 1 or -1)*(2*B+4),(H-B)/2)
        end
        power:SetFrameLevel(50)
    elseif frame.USE_POWERBAR_OFFSET then
        local offset=frame.POWERBAR_OFFSET;local sign=frame.ORIENTATION=='RIGHT' and -1 or 1
        setPoint(power,'TOPLEFT',frame.Health,'TOPLEFT',sign*offset,-offset)
        setPoint(power,'BOTTOMRIGHT',frame.Health,'BOTTOMRIGHT',sign*offset,-offset)
        power:SetFrameLevel(5)
    elseif frame.USE_INSET_POWERBAR then
        setHeight(power,math.max(1,H-2*inset))
        setPoint(power,'BOTTOMLEFT',frame.Health,'BOTTOMLEFT',3*B,3*B)
        setPoint(power,'BOTTOMRIGHT',frame.Health,'BOTTOMRIGHT',-3*B,3*B);power:SetFrameLevel(50)
    else
        setPoint(power,'TOPLEFT',frame.Health.backdrop,'BOTTOMLEFT',B,-3*S)
        setPoint(power,'TOPRIGHT',frame.Health.backdrop,'BOTTOMRIGHT',-B,-3*S)
        setHeight(power,math.max(1,H-2*inset));power:SetFrameLevel(15)
    end
    local strata=p.strataAndLevel or {}
    power:SetFrameStrata(strata.useCustomStrata and strata.frameStrata or 'LOW')
    if strata.useCustomLevel then power:SetFrameLevel(strata.frameLevel) end
    power.backdrop:SetFrameLevel(math.max(0,power:GetFrameLevel()-1))
    power.RaisedElementParent:SetFrameLevel(power:GetFrameLevel()+2)
    power.colorPower=true;power.colorDisconnected=false;power.colorTapping=false
    power.displayAltPower=p.displayAltPower;power.useAtlas=p.useAtlas==true
    power.colorClass=self.db.colors.powerclass or nil
    power.colorReaction=power.colorClass;power.colorSelection=self.db.colors.powerselection or nil
    power:SetReverseFill(p.reverseFill or false);power:SetOrientation(p.vertical and 'VERTICAL' or 'HORIZONTAL')
    power.smoothing=p.smoothbars and Enum.StatusBarInterpolation.ExponentialEaseOut or Enum.StatusBarInterpolation.Immediate
    self:PaintBar(power,'Power',p)
    power:Show();element(frame,'Power',true)
end

local function configureClass(frame,config)
    if not frame.ClassPower then return end
    local holder=frame.ClassBarHolder
    holder:ClearAllPoints()
    local width=config.detachFromFrame and config.detachedWidth or frame:GetWidth()
    setSize(holder,width or frame:GetWidth(),config.height or 10)
    setPoint(holder,'BOTTOMLEFT',frame,'TOPLEFT',0,3)
    local spacing=config.spacing or 3
    local count=10
    for index,power in ipairs(frame.ClassPower) do
        power:ClearAllPoints();setSize(power,math.max(1,(holder:GetWidth()-spacing*(count-1))/count),holder:GetHeight())
        setPoint(power,'LEFT',holder,'LEFT',(index-1)*(power:GetWidth()+spacing),0)
    end
    frame.ClassPower.PostUpdate=function(element,cur,max)
        -- oUF owns values; only public segment counts affect layout.
        if not public(max) or type(max)~='number' or max<1 then return end
        for index,power in ipairs(element) do
            setWidth(power,math.max(1,(holder:GetWidth()-spacing*(max-1))/max))
            power:ClearAllPoints();setPoint(power,'LEFT',holder,'LEFT',(index-1)*(power:GetWidth()+spacing),0)
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
            local active=config.enable~=false and self:TagFormat(config.text_format)~=''
            local fs=frame.customTexts[key]
            if active then
                fs=fs or makeText(frame,key,config)
                configureText(frame,fs,config)
                fs:SetDrawLayer('OVERLAY',key=='[faction:icon]' and 0 or 1)
            elseif fs then frame:Untag(fs);fs:SetText('');fs:Hide() end
        end
    end
    for key,fs in pairs(frame.customTexts) do
        if not c.customTexts[key] then frame:Untag(fs);fs:SetText('');fs:Hide() end
    end
end

function UF:ConfigureFrame(frame)
    if InCombatLockdown() and not frame.squancherBuilding then self.pending=true;return end
    local c=self.db.units[frame.squancherKey];if not c then return end
    frame.squancherConfig=c;frame.db=c;frame.unitframeType=frame.squancherKey:gsub("_target$","target")
    frame.ORIENTATION=c.orientation or 'LEFT';frame.UNIT_WIDTH=c.width;frame.UNIT_HEIGHT=c.height
    frame.USE_POWERBAR=c.power.enable~=false;frame.POWERBAR_DETACHED=c.power.detachFromFrame==true
    frame.USE_MINI_POWERBAR=frame.USE_POWERBAR and not frame.POWERBAR_DETACHED and c.power.width=='spaced'
    frame.USE_INSET_POWERBAR=frame.USE_POWERBAR and not frame.POWERBAR_DETACHED and c.power.width=='inset'
    frame.USE_POWERBAR_OFFSET=frame.USE_POWERBAR and not frame.POWERBAR_DETACHED and c.power.width=='offset' and (c.power.offset or 0)~=0
    frame.POWERBAR_HEIGHT=frame.USE_POWERBAR and c.power.height or 0
    frame.POWERBAR_OFFSET=frame.USE_POWERBAR_OFFSET and c.power.offset or 0
    frame.POWERBAR_WIDTH=frame.USE_MINI_POWERBAR and (c.width-2*self.BORDER)/2 or c.width-2*(self.BORDER+self.SPACING)
    frame.USE_PORTRAIT=c.portrait.enable~=false
    frame.USE_PORTRAIT_OVERLAY=frame.USE_PORTRAIT and (c.portrait.overlay or frame.ORIENTATION=='MIDDLE')
    frame.PORTRAIT_WIDTH=frame.USE_PORTRAIT and not frame.USE_PORTRAIT_OVERLAY and c.portrait.width or 0
    frame.POWERBAR_SHOWN=frame.USE_POWERBAR;frame.CLASSBAR_YOFFSET=0
    frame.USE_INFO_PANEL=c.infoPanel.enable==true;frame.INFO_PANEL_HEIGHT=frame.USE_INFO_PANEL and c.infoPanel.height or 0
    frame.BOTTOM_OFFSET=(frame.USE_POWERBAR and not frame.POWERBAR_DETACHED and not frame.USE_INSET_POWERBAR and
        (frame.POWERBAR_HEIGHT-(self.BORDER-self.SPACING)) or 0)+frame.INFO_PANEL_HEIGHT
    setSize(frame,c.width,c.height+frame.INFO_PANEL_HEIGHT)
    local strata=c.strataAndLevel or {};frame:SetFrameStrata(strata.useCustomStrata and strata.frameStrata or 'LOW')
    frame:SetFrameLevel(strata.useCustomLevel and strata.frameLevel or 1)
    local B,S=self.BORDER,self.SPACING;local edge=B+S;local right=frame.ORIENTATION=='RIGHT'
    local bottom=edge+frame.BOTTOM_OFFSET
    if frame.USE_MINI_POWERBAR then bottom=S+frame.POWERBAR_HEIGHT/2 end
    if frame.USE_POWERBAR_OFFSET then bottom=edge+frame.POWERBAR_OFFSET end
    frame.Health:ClearAllPoints()
    setPoint(frame.Health,'TOPLEFT',frame,'TOPLEFT',edge+(right and frame.POWERBAR_OFFSET or frame.PORTRAIT_WIDTH),-edge)
    setPoint(frame.Health,'BOTTOMRIGHT',frame,'BOTTOMRIGHT',-edge-(right and frame.PORTRAIT_WIDTH or frame.POWERBAR_OFFSET),bottom)
    frame.Health:SetFrameLevel(10);frame.Health.backdrop:SetFrameLevel(9)
    frame.Health.RaisedElementParent:SetFrameLevel(12)
    frame.Health:SetReverseFill(c.health.reverseFill or false)
    frame.Health:SetOrientation(c.health.orientation or 'HORIZONTAL')
    frame.Health.colorHealth=true;frame.Health.colorDisconnected=true;frame.Health.colorTapping=true
    frame.Health.colorClass=nil;frame.Health.colorReaction=nil;frame.Health.colorSmooth=nil;frame.Health.colorSelection=nil
    if c.colorOverride=='FORCE_ON' or c.colorOverride=='ALWAYS' then
        frame.Health.colorClass=true;frame.Health.colorReaction=true
    elseif c.colorOverride~='FORCE_OFF' and self.db.colors.healthselection then frame.Health.colorSelection=true
    elseif self.db.colors.healthclass then
        frame.Health.colorClass=not self.db.colors.forcehealthreaction;frame.Health.colorReaction=true
    elseif self.db.colors.colorhealthbyvalue then frame.Health.colorSmooth=true end
    frame.Health.smoothing=c.health.smoothbars and Enum.StatusBarInterpolation.ExponentialEaseOut or Enum.StatusBarInterpolation.Immediate
    self:PaintBar(frame.Health,'Health',c.health)
    for _,key in ipairs({'healingAll','healingPlayer','healingOther','damageAbsorb','healAbsorb'}) do
        local prediction=frame.HealthPrediction and frame.HealthPrediction[key]
        if prediction then
            prediction:ClearAllPoints();setHeight(prediction,frame.Health:GetHeight());prediction:SetReverseFill(c.health.reverseFill or false)
            local point=c.health.reverseFill and 'TOPRIGHT' or 'TOPLEFT'
            local relative=c.health.reverseFill and 'TOPLEFT' or 'TOPRIGHT'
            setPoint(prediction,point,frame.Health:GetStatusBarTexture(),relative)
        end
    end
    self:Configure_Power(frame);configurePortrait(frame,c.portrait)
    self:Configure_CustomTexts(frame);configureCast(frame,c.castbar);configureClass(frame,c.classbar)
    configureAura(frame,'Buffs',c.buffs);configureAura(frame,'Debuffs',c.debuffs)
    element(frame,'HealthPrediction',c.healPrediction and c.healPrediction.enable==true)
    frame:RegisterForClicks(self.db.targetOnMouseDown and 'AnyDown' or 'AnyUp')
    if self.ConfigureState then self:ConfigureState(frame) end
    if not frame.squancherBuilding then
        if frame.UpdateAllElements then frame:UpdateAllElements('SquanchOnConfigure') end
        -- The one border and light pass of a configure; it fits in full.
        if ns.UnitFrameLighting then ns.UnitFrameLighting:Invalidate(frame) end
        if ns.OriginalUnitFrameBorders then ns.OriginalUnitFrameBorders:RefreshFrame(frame) end
    end
end

function UF:PrepareProfile()
    self.db.general=self.db.general or {};self.db.benikui=self.db.benikui or {}
    local _,physicalHeight=GetPhysicalScreenSize()
    self.pixelMult=768/physicalHeight
    self.BORDER=self.db.thinBorders==false and 2 or 1;self.SPACING=self.db.thinBorders==false and 1 or 0
    self.palette=setmetatable({}, {__index=oUF.colors})
    for key,value in pairs(self.db.colors or {}) do
        if type(value)=='table' then
            if value.r then self.palette[key]=oUF:CreateColor(value.r,value.g,value.b,value.a or 1)
            elseif oUF.colors[key] then
                local palette=setmetatable({}, {__index=oUF.colors[key]})
                for token,c in pairs(value) do
                    if type(c)=='table' and c.r then palette[tonumber(token) or token]=oUF:CreateColor(c.r,c.g,c.b,c.a or 1) end
                end
                self.palette[key]=palette
            end
        end
    end
    -- oUF may select power by either token or numeric ID. Its stock table
    -- aliases both keys to the same Color object; preserve that relationship
    -- inside our independent configured palette instead of inheriting the
    -- numeric default after replacing only the named color.
    if self.palette.power then
        local aliases={}
        for token,configured in pairs(self.palette.power) do
            if type(token)=='string' then
                local original=oUF.colors.power[token]
                if original then
                    for id,source in pairs(oUF.colors.power) do
                        if type(id)=='number' and source==original then aliases[id]=configured end
                    end
                end
            end
        end
        for id,configured in pairs(aliases) do self.palette.power[id]=configured end
        if self.palette.power.ALT_POWER then
            self.palette.power[Enum.PowerType.Alternate or 10]=self.palette.power.ALT_POWER
        end
    end
    if self.palette.health and self.palette.health.SetCurve then
        local health=self.palette.health
        health:SetCurve({[0]=CreateColor(1,0,0),[.5]=CreateColor(1,1,0),[1]=CreateColor(health.r,health.g,health.b)})
    end
    for _,frame in ipairs(self.objects) do frame.colors=self.palette end
end

-- oUF recolours the health bar after every value update. The colour reads the
-- unit's connection, tap, reaction and selection state, never its health
-- (unless colour-by-value is on), so a value tick with those unchanged keeps
-- the painted colour and the light behind it.
local healthValueEvents={UNIT_HEALTH=true,UNIT_MAXHEALTH=true,UNIT_HEALTH_FREQUENT=true,UNIT_MAX_HEALTH_MODIFIERS_CHANGED=true}
local function healthColor(frame,event,unit)
    if not unit or frame.__unit~=unit then return end
    local element=frame.Health
    local connected,tapped,reaction=UnitIsConnected(unit),UnitIsTapDenied(unit),UnitReaction(unit,'player')
    local selection=UnitSelectionType and UnitSelectionType(unit,true)
    local readable=public(connected) and public(tapped) and public(reaction) and public(selection)
    if readable and healthValueEvents[event] and not element.colorSmooth and element.sqColorKnown
        and element.sqConnected==connected and element.sqTapped==tapped and element.sqReaction==reaction
        and element.sqSelection==selection then return end
    element.sqColorKnown=readable
    element.sqConnected,element.sqTapped,element.sqReaction,element.sqSelection=connected,tapped,reaction,selection
    -- oUF exposes its colour pass only through the element's forced update,
    -- which repeats the (cheap) value update; step aside for that one call.
    if not element.ForceUpdate then element.UpdateColor=nil;return end
    element.UpdateColor=nil
    element:ForceUpdate()
    element.UpdateColor=healthColor
end

local function style(frame,unit,key)
    frame.squancherKey=key;frame.unitframeType=key:gsub("_target$","target")
    frame.squancherBuilding=true
    frame.squancherConfig=UF.db.units[key]
    frame.colors=UF.palette
    frame:HookScript('OnEnter',tooltipEnter);frame:HookScript('OnLeave',tooltipLeave)
    frame.RaisedElementParent=raised(frame,100)
    frame.Health=bar(frame,frame:GetName()..'_HealthBar');frame.Health.__ownerKey=key
    frame.Health.PostUpdateColor=function(bar,unit,color)
        if color then UF:SetStatusBarColor(bar,color:GetRGB()) end
    end
    frame.Health.UpdateColor=healthColor
    frame.Power=bar(frame,frame:GetName()..'_PowerBar');frame.Power.__ownerKey=key
    frame.Power.PostUpdateColor=function(self,unit,c,r,g,b)
        if c then r,g,b=c:GetRGB() end
        if r then UF:SetStatusBarColor(self,r,g,b) end
    end
    -- Parent regions draw beneath child StatusBars regardless of draw layer.
    -- Keep labels and indicators above bars/predictions, below the castbar.
    frame.TextOverlay=CreateFrame('Frame',nil,frame)
    frame.TextOverlay:SetAllPoints(frame)
    frame.TextOverlay:SetFrameLevel(100)
    frame.TextOverlay:EnableMouse(false)
    frame.Health.Text=font(frame.TextOverlay,UF.db.fontSize);frame.Power.Text=font(frame.TextOverlay,8)
    frame.Name=font(frame.TextOverlay,UF.db.fontSize)
    frame.customTexts={}
    frame.PortraitModel=CreateFrame('PlayerModel',nil,frame)
    frame.PortraitTexture=frame:CreateTexture(nil,'ARTWORK')
    -- The model is anchored to its backdrop, so the backdrop must not be the
    -- model's child: after the unit button hides and shows again the client
    -- leaves that parent-anchored-to-child pair unresolved and draws neither.
    background(frame.PortraitModel):SetParent(frame)
    frame.PortraitTexture.backdrop=CreateFrame('Frame',nil,frame,'BackdropTemplate')
    frame.PortraitTexture.backdrop:SetBackdrop({bgFile=white,edgeFile=white,edgeSize=1})
    frame.PortraitTexture.backdrop:SetBackdropBorderColor(0,0,0,1)
    frame.PortraitModel:SetIgnoreParentAlpha(true)
    hooksecurefunc(frame,'SetAlpha',function(_,alpha)
        local portrait=frame.Portrait3D
        if not portrait then return end
        -- A secret alpha (the idle fade) is passed through untouched.
        if issecretvalue and issecretvalue(alpha) then return end   -- the model refuses secret alpha; PlayerIdleFade hides it
        portrait:SetModelAlpha(alpha*(frame.USE_PORTRAIT_OVERLAY and (frame.db.portrait.overlayAlpha or .5) or 1))
    end)
    frame.PortraitModel:Hide();frame.PortraitModel.backdrop:Hide();frame.PortraitTexture:Hide()
    frame:HookScript('OnShow',function(self) if self.squancherPortraitPlace and self.USE_PORTRAIT and not self.USE_PORTRAIT_OVERLAY then self.squancherPortraitPlace() end end)
    frame.Portrait=frame.squancherConfig.portrait.style=='3D' and frame.PortraitModel or frame.PortraitTexture
    frame.Castbar=createCast(frame)
    frame.Buffs=newAura(frame,'Buffs');frame.Debuffs=newAura(frame,'Debuffs')
    if key=='player' then
        frame.ClassBarHolder=CreateFrame('Frame',nil,frame)
        frame.ClassPower={}
        for index=1,10 do frame.ClassPower[index]=bar(frame.ClassBarHolder,frame:GetName()..'ClassIconButton'..index) end
        frame.AdditionalPower=bar(frame,frame:GetName()..'_AdditionalPower')
        setSize(frame.AdditionalPower,frame.squancherConfig.width,5)
        setPoint(frame.AdditionalPower,'TOPLEFT',frame,'BOTTOMLEFT',0,-2)
        frame.AdditionalPower.colorPower=true
    end
    frame.RaidTargetIndicator=frame.TextOverlay:CreateTexture(nil,'OVERLAY')
    setSize(frame.RaidTargetIndicator,16,16);setPoint(frame.RaidTargetIndicator,'CENTER',frame,'TOP',0,8)
    frame.GroupRoleIndicator=frame.TextOverlay:CreateTexture(nil,'OVERLAY')
    setSize(frame.GroupRoleIndicator,12,12);setPoint(frame.GroupRoleIndicator,'TOPLEFT',frame,2,-2)
    frame.ReadyCheckIndicator=frame.TextOverlay:CreateTexture(nil,'OVERLAY')
    setSize(frame.ReadyCheckIndicator,18,18);setPoint(frame.ReadyCheckIndicator,'CENTER')
    frame.ResurrectIndicator=frame.TextOverlay:CreateTexture(nil,'OVERLAY')
    setSize(frame.ResurrectIndicator,20,20);setPoint(frame.ResurrectIndicator,'CENTER')
    frame.HealthPrediction={incomingHealOverflow=1,maxOverflow=1}
    for _,kind in ipairs({'healingAll','damageAbsorb','healAbsorb'}) do
        local prediction=CreateFrame('StatusBar',nil,frame.Health.ClipFrame)
        prediction:SetStatusBarTexture(white)
        setHeight(prediction,frame.squancherConfig.height)
        setPoint(prediction,'TOPLEFT',frame.Health:GetStatusBarTexture(),'TOPRIGHT')
        prediction:SetStatusBarColor(kind=='healAbsorb' and .6 or .2,kind=='healingAll' and .8 or .45,.75,.45)
        prediction:SetMinMaxValues(0,1);prediction:SetValue(0)
        frame.HealthPrediction[kind]=prediction
    end
    UF.objects[#UF.objects+1]=frame
    UF:ConfigureFrame(frame)
    -- A header child built in combat had its protected sizing refused; redo it after.
    if InCombatLockdown() then UF.pending=true end
    frame.squancherBuilding=nil
end

function UF:CreateMover(key,owner)
    local mover=self.movers[key]
    if mover then
        setSize(mover,owner:GetSize());return mover
    end
    mover=CreateFrame('Frame','SquanchOnUF_'..(unitNames[key] or key)..'Mover',UIParent)
    setSize(mover,owner:GetSize());mover.parent=owner
    self.movers[key]=mover
    owner:HookScript('OnSizeChanged',function(_,width,height)
        if InCombatLockdown() then UF.pending=true;return end
        setSize(mover,width,height)
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
        if not target then
            local token=b:match('^ElvUF_(.+)$')
            if token then
                for unit,label in pairs(unitNames) do if label==token then target=self.frames[unit] or self.headers[unit];break end end
            end
        end
        local allowed={TOP=true,BOTTOM=true,LEFT=true,RIGHT=true,CENTER=true,TOPLEFT=true,TOPRIGHT=true,BOTTOMLEFT=true,BOTTOMRIGHT=true}
        if allowed[a] and allowed[c] and target and tonumber(d) and tonumber(e) then
            mover:SetPoint(a,target,c,tonumber(d),tonumber(e));return
        end
        setPoint(mover,point,relative,relativePoint,x,y)
    else setPoint(mover,point,relative,relativePoint,x,y) end
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
    owner:ClearAllPoints();setPoint(owner,'TOPLEFT',mover,'TOPLEFT')
end

local function headerAttributes(key,config)
    local party=key=='party';local primary,secondary=(config.growthDirection or 'DOWN_RIGHT'):match('^([^_]+)_?(.*)$')
    local horizontal=primary=='LEFT' or primary=='RIGHT';local sign=(primary=='LEFT' or primary=='DOWN') and -1 or 1
    local groups=math.floor(numeric(config.numGroups,8,1,8))
    local attrs={showParty=party,showRaid=not party,showPlayer=config.showPlayer~=false,showSolo=false,
        point=horizontal and (sign<0 and 'RIGHT' or 'LEFT') or (sign<0 and 'TOP' or 'BOTTOM'),
        xOffset=horizontal and UF:Scale(sign*(config.horizontalSpacing or 0)) or 0,
        yOffset=horizontal and 0 or UF:Scale(sign*(config.verticalSpacing or 0)),
        unitsPerColumn=config.raidWideSorting and math.floor(numeric(config.groupsPerRowCol,1,1,8))*5 or 5,
        maxColumns=party and 1 or groups,columnSpacing=UF:Scale(config.groupSpacing or 0),
        columnAnchorPoint=horizontal and (secondary=='UP' and 'BOTTOM' or 'TOP') or (secondary=='LEFT' and 'RIGHT' or 'LEFT'),
        sortMethod=config.sortMethod or 'INDEX',sortDir=config.sortDir or 'ASC',
        ['oUF-initialConfigFunction']=string.format('self:SetWidth(%.8f) self:SetHeight(%.8f)',UF:Scale(config.width),UF:Scale(config.height))}
    if key=='tank' then attrs.groupFilter='MAINTANK'
    elseif key=='assist' then attrs.groupFilter='MAINASSIST'
    elseif not party then
        local order={};for i=1,groups do order[i]=tostring(i) end
        attrs.groupFilter=table.concat(order,',');attrs.groupBy=config.groupBy or 'GROUP'
        attrs.groupingOrder=config.groupingOrder or attrs.groupFilter
    end
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
        for setting,value in pairs(extra) do c[setting]=Import:Copy(value) end
        c.portrait.enable=false;c.power.enable=false;c.castbar.enable=false
        c.buffs.enable=false;c.debuffs.enable=false;c.name.size=8
        c.name=Import:Copy(extra.name or c.name);c.name.attachTextTo=c.name.attachTextTo or 'Health'
        self.db.units[childKey]=c
    end
    c.enable=parentConfig.enable and extra.enable
    c.width=extra.width or c.width;c.height=extra.height or c.height
    c.fader=Import:Copy(parentConfig.fader)
    c.growthDirection=parentConfig.growthDirection
    local attrs=headerAttributes(key,parentConfig)
    attrs['oUF-initialConfigFunction']=string.format("self:SetWidth(%.8f) self:SetHeight(%.8f) self:SetAttribute('unitsuffix','target')",UF:Scale(c.width),UF:Scale(c.height))
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
    setPoint(header,'TOPLEFT',parentHeader,'TOPLEFT',(left and -c.width or parentConfig.width)+(extra.xOffset or 0),extra.yOffset or 0)
    RegisterStateDriver(header,'visibility',parentConfig.visibility or (key=='party' and '[group:raid] hide;[group:party] show;hide' or '[group:raid] show;hide'))
    for _,frame in ipairs(self.objects) do if frame.squancherKey==childKey then self:ConfigureFrame(frame) end end
end

function UF:CreateAndUpdateHeaderGroup(key)
    if InCombatLockdown() then self.pending=true;return end
    local c=self.db.units[key]
    if not c or not c.enable then return end
    if key:match('^raid%d$') and not c.raidWideSorting then
        local holder=self.headers[key]
        if not holder then
            holder=CreateFrame('Frame','SquanchOnUF_'..unitNames[key]..'Header',UIParent)
            self.headers[key]=holder;self[key]=holder
        end
        setSize(holder,c.width,c.height);place(key,holder)
        holder.squancherGroups=holder.squancherGroups or {}
        local primary,secondary=(c.growthDirection or 'DOWN_RIGHT'):match('^([^_]+)_?(.*)$')
        local horizontal=primary=='LEFT' or primary=='RIGHT'
        local per=math.floor(numeric(c.groupsPerRowCol,1,1,8))
        local count=math.floor(numeric(c.numGroups,8,1,8))
        for index=1,8 do
            local group=holder.squancherGroups[index]
            if index<=count then
                local attrs=headerAttributes(key,c);attrs.groupFilter=tostring(index);attrs.maxColumns=1
                if not group then
                    oUF:SetActiveStyle('SquanchOn_'..key)
                    group=oUF:SpawnHeader('SquanchOnUF_'..unitNames[key]..'Group'..index,nil,attrs)
                    group:SetParent(holder);holder.squancherGroups[index]=group
                end
                for name,value in pairs(attrs) do group:SetAttribute(name,value) end
                group:ClearAllPoints()
                local slot=(index-1)%per;local row=math.floor((index-1)/per)
                local strideX=c.width+(c.horizontalSpacing or 0);local strideY=c.height+(c.verticalSpacing or 0)
                local x,y
                if horizontal then
                    x=(primary=='LEFT' and -1 or 1)*row*strideX*5
                    y=(secondary=='UP' and 1 or -1)*slot*(strideY+(c.groupSpacing or 0))
                else
                    x=(secondary=='LEFT' and -1 or 1)*slot*(strideX+(c.groupSpacing or 0))
                    y=(primary=='UP' and 1 or -1)*row*strideY*5
                end
                setPoint(group,'TOPLEFT',holder,'TOPLEFT',x,y);group:Show()
            elseif group then group:Hide() end
        end
        RegisterStateDriver(holder,'visibility',c.visibility or '[group:raid] show;hide')
        for _,frame in ipairs(self.objects) do if frame.squancherKey==key then self:ConfigureFrame(frame) end end
        return
    end
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
        setSize(holder,c.width,c.height)
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
        setPoint(frame,'TOPLEFT',holder,'TOPLEFT',horizontal and (c.growthDirection=='LEFT' and -1 or 1)*(index-1)*(c.width+(c.spacing or 12)) or 0,
            horizontal and 0 or (c.growthDirection=='UP' and 1 or -1)*(index-1)*(c.height+(c.spacing or 12)))
    end
end

function UF:Update_AllFrames()
    if InCombatLockdown() then self.pending=true;return false,'Combat' end
    local config,state=Import:Initialize()
    if not config then return false,state end
    self.db=config;self.state=state;self:PrepareProfile()
    self.headerModes=self.headerModes or {}
    for _,key in ipairs({'raid1','raid2','raid3'}) do
        local c=config.units[key];local mode=c.raidWideSorting and 'wide' or 'subgroups'
        if self.headerModes[key] and self.headerModes[key]~=mode then
            self.status.topologyReloadRequired=true
            return false,'Changing raid-wide sorting requires a UI reload.'
        end
        if c.enable then self.headerModes[key]=mode end
    end
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
            editor:Register({id='uf_'..id,label=id:match('^cast_') and (unitNames[id:sub(6)] or id:sub(6))..' cast bar' or id:match('^power_') and (unitNames[id:sub(7)] or id:sub(7))..' power bar' or (unitNames[id] or id)..' unit frame',resize=not groupTypes[id] and id~='boss' and id~='arena' and 'free' or false,fixedBorderSize=true,
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
        -- As ElvUI: in the spellbook, overrides included (Auto Shot is there).
        if C_SpellBook and C_SpellBook.IsSpellInSpellBook then
            selected=rangeBoolean(C_SpellBook.IsSpellInSpellBook,id,nil,true)
        end
        if selected~=true and C_SpellBook and C_SpellBook.IsSpellKnown and bank then
            selected=rangeBoolean(C_SpellBook.IsSpellKnown,id,bank)
        end
        -- Some general abilities (Auto Shot) are not reported as spellbook spells.
        if selected~=true and IsPlayerSpell then selected=rangeBoolean(IsPlayerSpell,id) end
        if selected==true then known[#known+1]=id end
    end
    -- An empty answer is not kept: early after login the spellbook is not
    -- loaded yet, and a cached empty list made every target look out of range.
    if #known>0 then cache[kind]=known end
    return known
end
-- Learning, unlearning or a spellbook (re)load can change the answer.
local rangeSpellEvents=CreateFrame('Frame')
for _,event in ipairs({'SPELLS_CHANGED','LEARNED_SPELL_IN_TAB','PLAYER_TALENT_UPDATE'}) do
    pcall(rangeSpellEvents.RegisterEvent,rangeSpellEvents,event)
end
rangeSpellEvents:SetScript('OnEvent',function() UF.rangeCache=nil end)

-- Range fade state: true = reachable, false = out of reach, nil = cannot tell
-- (no fade). The same rules as ElvUI's unit-frame range (UF:UpdateRange):
-- a unit is out of range only when the class's range spells all say so. If no
-- spell can answer, out of combat the 28-yard follow check decides, and in
-- combat it counts as in range. Friends also use the game's group range.
-- By ID first; spells whose range comes from the weapon (Auto Shot) answer
-- only the by-name check on this client, as the reticle's glow uses.
local spellNames={}
local function spellName(id)
    local name=spellNames[id]
    if name==nil then
        local ok,info=pcall(C_Spell and C_Spell.GetSpellInfo or GetSpellInfo,id)
        if ok and type(info)=='table' then info=info.name end
        name=ok and public(info) and type(info)=='string' and info or false
        spellNames[id]=name
    end
    return name or nil
end
local function spellsReach(unit,spells)
    local failed
    for _,id in ipairs(spells) do
        local reach=rangeBoolean(C_Spell and C_Spell.IsSpellInRange,id,unit)
        if reach==nil and IsSpellInRange and spellName(id) then reach=rangeBoolean(IsSpellInRange,spellName(id),unit) end
        if reach==true then return true elseif reach==false then failed=true end
    end
    if failed then return false end
end
local function inSpellsRange(unit,kind)
    local spells=UF.db and UF:KnownRangeSpells(kind) or {}
    local reach=#spells>0 and spellsReach(unit,spells) or nil
    if reach==nil and not InCombatLockdown() and CheckInteractDistance then
        local near=rangeBoolean(CheckInteractDistance,unit,4)
        if near~=nil then return near end
    end
    if reach==nil then return nil end
    return reach
end
function UF:RangeState(unit)
    -- The shared Range module (nameplates, target ring) asks the same spell list.
    local range=ns.Range
    if range and not range.spellProvider then
        range.spellProvider=function(kind) return UF.db and UF:KnownRangeSpells(kind) end
    end
    if not public(unit) or type(unit)~='string' then return nil end
    if rangeBoolean(UnitExists,unit)~=true or rangeBoolean(UnitIsUnit,unit,'player')==true then return nil end
    -- Owner: when the target ring shows its range marks (blocks or circling
    -- triangles) the target is in reach, and its frame is lit.
    local ring=ns.TargetCrosshairs
    if ring and ring.rangeMode and (unit=='target' or rangeBoolean(UnitIsUnit,unit,'target')==true) then return true end
    if rangeBoolean(UnitIsDeadOrGhost,unit)==true then return inSpellsRange(unit,'RESURRECT')==true end
    if rangeBoolean(UnitCanAttack,'player',unit)==true then return inSpellsRange(unit,'ENEMY') end
    if rangeBoolean(UnitIsUnit,'pet',unit)==true then return inSpellsRange(unit,'PET') end
    if rangeBoolean(UnitIsConnected,unit)==false then return false end
    -- The game's own group range: a checked "out of range" is final.
    if UnitInRange then
        local ok,inRange,checked=pcall(UnitInRange,unit)
        if ok and public(inRange) and public(checked) and checked and not inRange then return false end
    end
    return inSpellsRange(unit,'FRIENDLY')
end

local function initialize()
    if UF.Initialized then return end
    if not oUF then UF.status.error='SquanchOnUF engine did not load (check X-oUF and load order)';return end
    if InCombatLockdown() then UF.pending=true;return end
    local config,state=Import:Initialize()
    if not config then UF.status.error=state;return end
    -- Optional owner-local text placements, merged once per revision.
    local localMedia=ns.LocalMedia
    if localMedia and localMedia.unitText and state.localTextRev~=localMedia.unitTextRev then
        for unit,texts in pairs(localMedia.unitText) do
            local custom=config.units[unit] and config.units[unit].customTexts
            for key,fields in pairs(texts) do
                if custom and custom[key] then for field,value in pairs(fields) do custom[key][field]=value end end
            end
        end
        state.localTextRev=localMedia.unitTextRev
    end
    UF.db=config;UF.state=state;UF:PrepareProfile();installTags()
    -- A local adapter for Squancher's existing decoration code, never _G.ElvUI.
    local engine={db={unitframe=config,movers=config.movers},oUF=oUF,
        -- Bars are created with the profile's neutral black edge; the border
        -- adapter recognises exactly that colour and replaces it with the gold line.
        media={bordercolor={r=0,g=0,b=0},unitframeBorderColor={r=0,g=0,b=0}}}
    function engine:GetModule(name) if name=='UnitFrames' then return UF end end
    function engine:ClassColor(class) return RAID_CLASS_COLORS[class] end
    UF.Engine=engine
    for _,key in ipairs(Import.units) do
        local unit=key
        oUF:RegisterStyle('SquanchOn_'..unit,function(frame,token) style(frame,token,unit) end)
    end
    -- oUF takes a per-layout color table through .colors; avoid changing global shared data.
    UF.Initialized=true
    oUF:RegisterInitCallback(function(frame)
        if frame.squancherKey then UF:ConfigureFrame(frame) end
    end)
    UF:Update_AllFrames()

end
UF.optionCapabilities={['customTexts.*']=true}
for _,path in ipairs({'enable','width','height','orientation','portrait.enable','portrait.style','portrait.width',
    'portrait.rotation','portrait.camDistanceScale','portrait.xOffset','portrait.yOffset','portrait.overlay','portrait.paused',
    'health.reverseFill','power.enable','power.height','power.width','power.offset','power.reverseFill','power.detachFromFrame',
    'power.detachedWidth','castbar.enable','castbar.width','castbar.height','castbar.overlayOnFrame','castbar.icon',
    'castbar.latency','castbar.hideName','castbar.hideTime','horizontalSpacing','verticalSpacing','groupSpacing',
    'groupsPerRowCol','numGroups','growthDirection','visibility','groupBy','sortMethod','sortDir','raidWideSorting'}) do UF.optionCapabilities[path]=true end
for _,section in ipairs({'name','health','power'}) do
    for _,field in ipairs({'text_format','font','size','fontOutline','attachTextTo','position','xOffset','yOffset'}) do UF.optionCapabilities[section..'.'..field]=true end
end
local events=CreateFrame('Frame')
events:RegisterEvent('PLAYER_LOGIN');events:RegisterEvent('PLAYER_REGEN_ENABLED');events:RegisterEvent('ADDON_LOADED')
events:RegisterEvent('SPELLS_CHANGED');events:RegisterEvent('PLAYER_SPECIALIZATION_CHANGED')
events:SetScript('OnEvent',function(_,event,loaded)
    if event=='SPELLS_CHANGED' or event=='PLAYER_SPECIALIZATION_CHANGED' then UF.rangeCache=nil;return end
    if event=='ADDON_LOADED' and (loaded~=addonName or not IsLoggedIn()) then return end
    if not UF.Initialized then initialize()
    elseif UF.pending then UF:Update_AllFrames() end
end)
-- ADDON_LOADED fires after every file in this addon has loaded. Do not
-- initialize here: state and aura presentation modules follow this file.
