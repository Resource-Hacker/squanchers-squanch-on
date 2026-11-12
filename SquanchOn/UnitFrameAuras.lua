-- SPDX-License-Identifier: MIT
-- Independent saved-filter adapter and aura-bar presentation.
-- Load after UnitFrameState.lua. oUF owns icon/aura unit events and tooltip IDs.
local _,ns=...
local unpack=unpack or table.unpack
local UF=ns.UnitFrames
local function public(value) return not (issecretvalue and issecretvalue(value)) end
local function number(value) return public(value) and type(value)=='number' end
local function point(object,...)
    local args={...};for i,v in ipairs(args) do if type(v)=='number' then args[i]=UF:Scale(v) end end
    object:SetPoint(unpack(args))
end
local function entry(filters,list,id)
    local filter=filters and filters[list]
    local spell=filter and filter.spells and filter.spells[id]
    return spell==true or type(spell)=='table' and spell.enable~=false
end
local function personal(aura)
    local value=aura.isFromPlayerOrPlayerPet
    if public(value) and value~=nil then return value end
    local source=aura.sourceUnit
    return public(source) and (source=='player' or source=='pet' or source=='vehicle')
end
local function candidate(aura,key)
    if key=='isFromPlayerOrPlayerPet' then return personal(aura) end
    if key=='isBossOrRoleAura' then
        if not public(aura.isBossAura) or not public(aura.isRoleAura) then return nil end
        return aura.isBossAura or aura.isRoleAura
    end
    local value=aura[key]
    if public(value) then return value end
end
local function filtered(unit,aura,filter)
    if not filter or filter=='' or not C_UnitAuras.IsAuraFilteredOutByInstanceID then return nil end
    if not public(aura.auraInstanceID) then return nil end
    local ok,value=pcall(C_UnitAuras.IsAuraFilteredOutByInstanceID,unit,aura.auraInstanceID,filter)
    if ok and public(value) then return not value end
end
function UF:FilterAura(config,unit,aura,button)
    if not aura then return false end
    local duration,id=aura.duration,aura.spellId
    if number(duration) then
        if (config.minDuration or 0)>0 and duration<config.minDuration then return false end
        if (config.maxDuration or 0)>0 and duration>config.maxDuration then return false end
    end
    if button then button.sqAura=aura;button.sqRank=0 end
    local groups=config.filterLists or (config.friendlyFilter and config.friendlyFilter.filterLists)
    if groups then
        local enabled=false
        for index=1,8 do
            local group=groups['group'..index]
            if group and group.enable then
                enabled=true
                local valid=filtered(unit,aura,group.filter)
                if valid==nil then self.status.restrictedAuraFilter=true;valid=true end
                if valid then
                    if group.useBlocklist and public(id) and entry(self.db.auraFilters,group.blockList,id) then valid=false end
                    if group.useAllowlist and public(id) and not entry(self.db.auraFilters,group.allowList,id) then valid=false end
                    if number(duration) and (group.maxDuration or 0)>0 and duration>group.maxDuration then valid=false end
                    for key,wanted in pairs(group.candidates or {}) do
                        if wanted==true or wanted==1 then
                            local actual=candidate(aura,key)
                            if actual~=nil and (wanted==true and not actual or wanted==1 and actual) then valid=false end
                        end
                    end
                    if valid then if button then button.sqRank=index end;return true end
                end
            end
        end
        if enabled then return false end
    end
    local priority=config.priority or '';if priority=='' then return true end
    local own=personal(aura)
    for token in priority:gmatch('[^,]+') do
        if public(id) and entry(self.db.auraFilters,token,id) then
            local filter=self.db.auraFilters[token];return not filter or filter.type~='Blacklist'
        end
        local key=token:lower()
        if key=='blocknoduration' and number(duration) and duration==0 then return false end
        if key=='personal' and own then return true end
        if key=='nonpersonal' and not own then return true end
        if key=='dispellable' and public(aura.dispelName) and aura.dispelName then
            local dispel=LibStub('LibDispel-1.0',true)
            if dispel and dispel:IsDispellableByMe(aura.dispelName) then return true end
        end
    end
    return not public(duration) or not public(aura.sourceUnit)
end

function UF:SortAuraButtons(container)
    local shown={};local config=container.config or {}
    for index=1,container.createdButtons or #container do
        local button=container[index]
        if button and button:IsShown() then shown[#shown+1]=button;button.sqIndex=index end
    end
    local descending=config.sortDirection=='DESCENDING'
    table.sort(shown,function(a,b)
        if a.sqRank~=b.sqRank then return (a.sqRank or 0)<(b.sqRank or 0) end
        local x,y=a.sqAura or {},b.sqAura or {}
        local left,right
        if config.sortMethod=='NAME' then
            left=public(x.name) and x.name or '';right=public(y.name) and y.name or ''
        else
            left=number(x.expirationTime) and x.expirationTime or 0
            right=number(y.expirationTime) and y.expirationTime or 0
        end
        if left==right then return a.sqIndex<b.sqIndex end
        if descending then return left>right else return left<right end
    end)
    local per=math.max(1,config.perrow or 8);local stride=container.size+(container.spacing or config.spacing or 1)
    local sx=(container['growth-x'] or config.growthX)=='LEFT' and -1 or 1
    local sy=(container['growth-y'] or config.growthY)=='DOWN' and -1 or 1
    for index,button in ipairs(shown) do
        if index>(container.visibleLimit or #shown) then button:Hide()
        else
            button:ClearAllPoints()
            point(button,container.initialAnchor,container,container.initialAnchor,((index-1)%per)*stride*sx,math.floor((index-1)/per)*stride*sy)
            self:ApplyFont(button.Count,config.countFont or self.db.font,config.countFontSize or 8,config.countFontOutline or 'OUTLINE')
            button.Count:ClearAllPoints()
            point(button.Count,config.countPosition or 'BOTTOMRIGHT',button,config.countPosition or 'BOTTOMRIGHT',config.countXOffset or 0,config.countYOffset or 0)
        end
    end
end

local function newBar(frame)
    local bar=CreateFrame('StatusBar',nil,frame.AuraBars,'BackdropTemplate')
    bar:SetStatusBarTexture(UF:Texture(UF.db.statusbar))
    bar:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=UF:Scale(1)})
    bar:SetBackdropColor(.054,.054,.054,.75);bar:SetBackdropBorderColor(0,0,0,1)
    bar.Icon=bar:CreateTexture(nil,'ARTWORK');bar.Icon:SetTexCoord(.07,.93,.07,.93)
    bar.Name=bar:CreateFontString(nil,'OVERLAY');bar.Time=bar:CreateFontString(nil,'OVERLAY')
    point(bar.Name,'LEFT',bar,'LEFT',2,0);point(bar.Time,'RIGHT',bar,'RIGHT',-2,0)
    bar.Name:SetPoint('RIGHT',bar.Time,'LEFT',-2,0)
    if UF.SoftShadow then bar.Shadow=UF:SoftShadow(bar,bar);bar.IconShadow=UF:SoftShadow(bar,bar.Icon) end
    bar:EnableMouse(true)
    bar:SetScript('OnEnter',function(self)
        if self.auraInstanceID and not GameTooltip:IsForbidden() then
            GameTooltip:SetOwner(self,'ANCHOR_BOTTOMRIGHT')
            if GameTooltip.SetUnitAuraByAuraInstanceID then GameTooltip:SetUnitAuraByAuraInstanceID(frame.__unit,self.auraInstanceID) end
        end
    end)
    bar:SetScript('OnLeave',function() if not GameTooltip:IsForbidden() then GameTooltip:Hide() end end)
    return bar
end
function UF:RefreshAuraBars(frame)
    local config=frame.db.aurabar
    if not config or not config.enable then if frame.AuraBars then frame.AuraBars:Hide() end;return end
    local unit=frame.__unit;if not unit or not C_UnitAuras.GetAuraDataByIndex then return end
    if not frame.AuraBars then frame.AuraBars=CreateFrame('Frame',nil,frame);frame.AuraBars.bars={} end
    local holder=frame.AuraBars;holder:Show()
    local friendly=UnitCanAssist('player',unit)
    friendly=public(friendly) and friendly or false
    local filter=friendly and config.friendlyAuraType or config.enemyAuraType
    filter=filter or 'HARMFUL'
    local filterConfig=ns.UnitFrameImport:Copy(config)
    local subset=friendly and config.friendlyFilter or config.enemyFilter
    if subset then for key,value in pairs(subset) do filterConfig[key]=value end end
    local auras={}
    for index=1,255 do
        local aura=C_UnitAuras.GetAuraDataByIndex(unit,index,filter)
        if not aura then break end
        if self:FilterAura(filterConfig,unit,aura) then auras[#auras+1]=aura end
    end
    table.sort(auras,function(a,b)
        local x=number(a.expirationTime) and a.expirationTime or 0
        local y=number(b.expirationTime) and b.expirationTime or 0
        if x==y then return (number(a.auraInstanceID) and a.auraInstanceID or 0)<(number(b.auraInstanceID) and b.auraInstanceID or 0) end
        if config.sortDirection=='DESCENDING' then return x>y else return x<y end
    end)
    local h=config.height or 15;local spacing=config.spacing or 5;local max=config.maxBars or 3
    local w=frame.db.width-3-4*(self.BORDER+self.SPACING)-h+1
    local region=config.attachTo=='DEBUFFS' and frame.Debuffs or config.attachTo=='BUFFS' and frame.Buffs or frame
    holder:ClearAllPoints();point(holder,'BOTTOMLEFT',region,'TOPLEFT',h+spacing+3,config.yOffset or 0)
    holder:SetSize(self:Scale(w),self:Scale(max*(h+spacing)))
    for index=1,math.max(max,#holder.bars) do
        local bar=holder.bars[index]
        local aura=index<=max and auras[index]
        if aura then
            if not bar then bar=newBar(frame);holder.bars[index]=bar end
            bar:ClearAllPoints();point(bar,'BOTTOMLEFT',holder,'BOTTOMLEFT',0,(index-1)*(h+spacing))
            bar:SetSize(self:Scale(w),self:Scale(h));bar.Icon:SetSize(self:Scale(h),self:Scale(h))
            bar.Icon:ClearAllPoints();point(bar.Icon,'RIGHT',bar,'LEFT',-spacing-3,0);bar.Icon:SetTexture(aura.icon)
            self:ApplyFont(bar.Name,self.db.font,self.db.fontSize,self.db.fontOutline)
            self:ApplyFont(bar.Time,self.db.font,self.db.fontSize,self.db.fontOutline)
            bar.Name:SetText(aura.name);bar.auraInstanceID=aura.auraInstanceID
            local duration=not timed and C_UnitAuras.GetAuraDuration and C_UnitAuras.GetAuraDuration(unit,aura.auraInstanceID)
            if duration and bar.SetTimerDuration then
                bar:SetTimerDuration(duration,Enum.StatusBarInterpolation.Immediate,Enum.StatusBarTimerDirection.RemainingTime)
            elseif number(aura.duration) and number(aura.expirationTime) then
                bar:SetMinMaxValues(0,math.max(1,aura.duration));bar:SetValue(math.max(0,aura.expirationTime-GetTime()))
            else self.status.restrictedAuraBarTiming=true;bar:SetMinMaxValues(0,1);bar:SetValue(1) end
            local c=self.db.colors[filter=='HELPFUL' and 'auraBarBuff' or 'auraBarDebuff'] or {r=.1,g=.1,b=.1,a=1}
            bar:SetStatusBarColor(c.r,c.g,c.b,c.a);bar:SetReverseFill(config.reverseFill==true)
            if number(aura.expirationTime) then
                bar.expires=aura.expirationTime
                bar:SetScript('OnUpdate',function(self)
                    local left=math.max(0,self.expires-GetTime());self.Time:SetFormattedText('%.0f',left)
                    if not self.SetTimerDuration then self:SetValue(left) end
                end)
            else bar:SetScript('OnUpdate',nil);bar.Time:SetText('') end
            bar:Show()
        elseif bar then bar:Hide();bar:SetScript('OnUpdate',nil) end
    end
end

-- Icon rows. The embedded oUF registers no aura element on Forever-era
-- clients, so Squanch-On reads and lays out the rows itself.
local function newIcon(container,frame)
    local button=CreateFrame('Button',nil,container)
    button.Icon=button:CreateTexture(nil,'ARTWORK');button.Icon:SetPoint('CENTER')
    button.Icon:SetTexCoord(.07,.93,.07,.93)
    button.Cooldown=CreateFrame('Cooldown',nil,button,'CooldownFrameTemplate')
    button.Cooldown:SetAllPoints(button.Icon);button.Cooldown:SetReverse(true);button.Cooldown:SetDrawEdge(false)
    if button.Cooldown.SetHideCountdownNumbers then button.Cooldown:SetHideCountdownNumbers(true) end
    local overlay=CreateFrame('Frame',nil,button);overlay:SetAllPoints()
    overlay:SetFrameLevel(button.Cooldown:GetFrameLevel()+1)
    button.Count=overlay:CreateFontString(nil,'OVERLAY');button.Text=overlay:CreateFontString(nil,'OVERLAY')
    button.Text:SetPoint('CENTER')
    button:SetScript('OnEnter',function(self)
        if not self.auraInstanceID or GameTooltip:IsForbidden() then return end
        local config=container.config or {}
        GameTooltip:SetOwner(self,config.tooltipAnchorType or 'ANCHOR_BOTTOMRIGHT',config.tooltipAnchorX or 0,config.tooltipAnchorY or 0)
        if GameTooltip.SetUnitAuraByAuraInstanceID then GameTooltip:SetUnitAuraByAuraInstanceID(frame.__unit,self.auraInstanceID) end
    end)
    button:SetScript('OnLeave',function() if not GameTooltip:IsForbidden() then GameTooltip:Hide() end end)
    UF:ApplyFont(button.Text,UF.db.font,8,UF.db.fontOutline)
    UF:ApplyFont(button.Count,UF.db.font,8,UF.db.fontOutline)
    return button
end
local function paintIcon(button,container,frame,unit,aura,key)
    local config=container.config or {}
    local size=UF:Scale(container.size)
    button:SetSize(size,size)
    -- Same cell material as the action bars: cells touch and share one rim line,
    -- the icon sits inside the painted inner edge.
    button.Icon:SetSize(size*37/43,size*37/43)
    if ns.DarkSkin and ns.DarkSkin.RawSlotBorder then ns.DarkSkin:RawSlotBorder(button,frame,1) end
    button:EnableMouse(not container.disableMouse)
    button.auraInstanceID=not aura.test and aura.auraInstanceID or nil
    button.Icon:SetTexture(aura.icon)
    button.Icon:SetDesaturated(key=='Debuffs' and config.desaturate==true and personal(aura)==false)
    local timed=aura.test==true
    if timed then button.Cooldown:SetCooldown(GetTime()-aura.duration*.4,aura.duration) end
    local duration=not timed and C_UnitAuras.GetAuraDuration and C_UnitAuras.GetAuraDuration(unit,aura.auraInstanceID)
    if duration and button.Cooldown.SetCooldownFromDurationObject then
        timed=pcall(button.Cooldown.SetCooldownFromDurationObject,button.Cooldown,duration)
    end
    if not timed then
        if number(aura.duration) and number(aura.expirationTime) and aura.duration>0 then
            button.Cooldown:SetCooldown(aura.expirationTime-aura.duration,aura.duration)
        else button.Cooldown:Clear() end
    end
    if number(aura.applications) then button.Count:SetText(aura.applications>1 and aura.applications or '')
    elseif C_UnitAuras.GetAuraApplicationDisplayCount then
        button.Count:SetText(C_UnitAuras.GetAuraApplicationDisplayCount(unit,aura.auraInstanceID,2,999))
    else button.Count:SetText('') end
    button:Show()
end
local testIcons={
    Buffs={136075,135932,136085,132333,135987,136048,135915,136096},
    Debuffs={136139,136118,136207,132090,136197,135817,136066,136188}}
-- /sqauras [count]: fill every enabled row with placeholder icons to judge
-- spacing, wrapping and overlap. Run it again (or /sqauras 0) to return to live auras.
function UF:AuraTest(count)
    count=tonumber(count)
    if count==nil then count=not self.auraTest and 6 or 0 end
    self.auraTest=count>0 and math.min(40,math.floor(count)) or nil
    for _,frame in ipairs(self.objects) do if frame.db then self:RefreshAuraIcons(frame) end end
    if self.RefreshPlayerBars then self:RefreshPlayerBars() end
    return self.auraTest
end
SLASH_SQUANCHONAURAS1='/sqauras'
SlashCmdList.SQUANCHONAURAS=function(message)
    local shown=UF:AuraTest(message~='' and message or nil)
    print(shown and ('Squanch-On: previewing '..shown..' buffs and debuffs per row. /sqauras to stop.') or 'Squanch-On: aura preview off.')
end
function UF:RefreshAuraIcons(frame)
    local unit=frame.__unit
    for _,key in ipairs({'Buffs','Debuffs'}) do
        local container=frame[key];local config=container and container.config
        if container then
            local used=0
            if self.auraTest and config and config.enable~=false and frame:IsShown() then
                -- Layout preview: placeholder icons, no unit data, no filters.
                for index=1,self.auraTest do
                    local button=container[index]
                    if not button then button=newIcon(container,frame);container[index]=button end
                    local aura={test=true,icon=testIcons[key][(index-1)%#testIcons[key]+1],duration=30+index*15,
                        expirationTime=GetTime()+index*20,applications=index%3==0 and index or 1,name=key..index}
                    button.sqAura=aura;button.sqRank=0;used=index
                    paintIcon(button,container,frame,unit or 'player',aura,key)
                end
            elseif config and config.enable~=false and unit and frame:IsShown() and C_UnitAuras.GetAuraDataByIndex then
                for index=1,255 do
                    local aura=C_UnitAuras.GetAuraDataByIndex(unit,index,container.filter or (key=='Buffs' and 'HELPFUL' or 'HARMFUL'))
                    if not aura then break end
                    local button=container[used+1]
                    if not button then button=newIcon(container,frame);container[used+1]=button end
                    if self:FilterAura(config,unit,aura,button) then
                        used=used+1;paintIcon(button,container,frame,unit,aura,key)
                    end
                end
            end
            for index=used+1,#container do container[index]:Hide();container[index].sqAura=nil end
            container.createdButtons=#container;container.visibleButtons=used
            container:SetShown(config and config.enable~=false or false)
            self:SortAuraButtons(container)
        end
    end
end

local configure=UF.ConfigureState
function UF:ConfigureState(frame)
    configure(self,frame)
    if not frame.squancherAuraShow then
        frame.squancherAuraShow=true
        frame:HookScript('OnShow',function() UF:RefreshAuraIcons(frame) end)
    end
    self:RefreshAuraIcons(frame);self:RefreshAuraBars(frame)
end
local events=CreateFrame('Frame');events:RegisterEvent('UNIT_AURA');events:RegisterEvent('PLAYER_TARGET_CHANGED');events:RegisterEvent('UNIT_TARGET');events:RegisterEvent('PLAYER_FOCUS_CHANGED');events:RegisterEvent('UNIT_PET')
events:SetScript('OnEvent',function(_,event,unit)
    for _,frame in ipairs(UF.objects) do
        local own=frame.__unit
        if own and (unit==own or event=='PLAYER_TARGET_CHANGED' or event=='PLAYER_FOCUS_CHANGED' or event=='UNIT_PET'
            or event=='UNIT_TARGET' and type(unit)=='string' and own==unit..'target') then UF:RefreshAuraIcons(frame) end
        if frame.db.aurabar and frame.db.aurabar.enable and (unit==frame.__unit or event=='PLAYER_TARGET_CHANGED') then UF:RefreshAuraBars(frame) end
    end
end)
if UF.Initialized then for _,frame in ipairs(UF.objects) do UF:RefreshAuraIcons(frame);UF:RefreshAuraBars(frame) end end

-- The player's own buff and debuff bars, replacing the game's top-right rows
-- with the same touching action-bar cells. /sqedit moves and scales each bar.
local playerBars={}
local function playerBar(key,filter,y)
    local bar=CreateFrame('Frame','SquanchOnPlayer'..key,UIParent)
    bar.__unit='player';bar.key=key;bar.filter=filter;bar.defaultY=y
    bar.size=30;bar.spacing=0;bar.visibleLimit=36;bar.initialAnchor='TOPRIGHT'
    bar['growth-x']='LEFT';bar['growth-y']='DOWN'
    bar.config={perrow=12,sortMethod='TIME_REMAINING',sortDirection='DESCENDING',countPosition='BOTTOMRIGHT',countYOffset=2,
        countFontSize=10,tooltipAnchorType='ANCHOR_BOTTOMLEFT'}
    bar:SetSize(12*30,30);bar:SetFrameStrata('LOW')
    playerBars[#playerBars+1]=bar
    return bar
end
playerBar('Buffs','HELPFUL',-12);playerBar('Debuffs','HARMFUL',-112)
local function cancel(button)
    -- Out of combat only: the client refuses addon cancels during combat.
    if InCombatLockdown() or not button.auraInstanceID then return end
    for index=1,255 do
        local aura=C_UnitAuras.GetAuraDataByIndex('player',index,'HELPFUL')
        if not aura then return end
        if public(aura.auraInstanceID) and aura.auraInstanceID==button.auraInstanceID then
            pcall(CancelUnitBuff,'player',index,'HELPFUL');return
        end
    end
end
function UF:RefreshPlayerBars()
    if not self.db then return end
    for _,bar in ipairs(playerBars) do
        local used=0
        local function take()
            local button=bar[used+1]
            if not button then
                button=newIcon(bar,bar);bar[used+1]=button
                button.Cooldown:SetHideCountdownNumbers(false)
                if button.Cooldown.SetCountdownFont then
                    if not UF.auraCountdownFont then
                        UF.auraCountdownFont=CreateFont('SquanchOnAuraCountdown')
                        UF.auraCountdownFont:SetFont(UF:Font(UF.db.font),11,'OUTLINE')
                    end
                    button.Cooldown:SetCountdownFont('SquanchOnAuraCountdown')
                end
                if bar.key=='Buffs' then
                    button:RegisterForClicks('RightButtonUp');button:SetScript('OnClick',cancel)
                end
            end
            return button
        end
        if self.auraTest then
            for index=1,self.auraTest do
                local button=take()
                local aura={test=true,icon=testIcons[bar.key][(index-1)%#testIcons[bar.key]+1],duration=30+index*15,
                    expirationTime=GetTime()+index*20,applications=index%3==0 and index or 1,name=bar.key..index}
                button.sqAura=aura;button.sqRank=0;used=index
                paintIcon(button,bar,bar,'player',aura,bar.key)
            end
        else
            for index=1,255 do
                local aura=C_UnitAuras.GetAuraDataByIndex('player',index,bar.filter)
                if not aura then break end
                local button=take()
                button.sqAura=aura;button.sqRank=0;used=used+1
                paintIcon(button,bar,bar,'player',aura,bar.key)
            end
        end
        for index=used+1,#bar do bar[index]:Hide();bar[index].sqAura=nil end
        bar.createdButtons=#bar
        self:SortAuraButtons(bar)
    end
end
function UF:PlacePlayerBars()
    if InCombatLockdown() then return end
    for _,bar in ipairs(playerBars) do
        bar:SetScale(1);bar:ClearAllPoints();bar:SetPoint('TOPRIGHT',UIParent,'TOPRIGHT',-263,bar.defaultY)
        if ns.LayoutTargets then ns.LayoutTargets:ApplyScale('player_'..bar.key:lower(),bar) end
    end
end
local function retire(native)
    if not native or native.squanchOnRetired then return end
    native.squanchOnRetired=true
    hooksecurefunc(native,'Show',function(self) self:Hide() end)
    native:Hide()
end
local playerEvents=CreateFrame('Frame')
playerEvents:RegisterEvent('PLAYER_LOGIN');playerEvents:RegisterEvent('PLAYER_ENTERING_WORLD');playerEvents:RegisterEvent('UNIT_AURA')
playerEvents:SetScript('OnEvent',function(_,event,unit)
    if event=='UNIT_AURA' then if unit=='player' then UF:RefreshPlayerBars() end;return end
    retire(BuffFrame);retire(DebuffFrame)
    UF:PlacePlayerBars();UF:RefreshPlayerBars()
end)
