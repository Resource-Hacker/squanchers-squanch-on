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
local empty,auraKeys={},{'Buffs','Debuffs'}
-- Cell look from SquanchOnDB.auras, read once per change by UF:ApplyAuraSettings
-- (below); painting compares one revision number and reads only these locals.
local styleRev,cellRim,cellSwipe,cellNumbers,desatAll,desatSaved=0,true,true,false,false,true
local countFont,countSize,countPosition,showEnchants
-- One read of a unit's auras per filter serves every row drawn for the same
-- event (unit frame rows, aura bars, the player's bars). Outside the aura
-- event handler nothing is kept.
local shared
-- While the queued aura events of one rendered frame are drawn: the instance
-- IDs those events named for the unit being painted. An icon that already shows
-- an aura outside this set keeps its texture, swipe and count. nil paints all.
local keep
local function auraAt(unit,filter,index)
    if not shared then return C_UnitAuras.GetAuraDataByIndex(unit,index,filter) end
    local byUnit=shared[unit]
    if not byUnit then byUnit={};shared[unit]=byUnit end
    local list=byUnit[filter]
    if not list then
        list={};byUnit[filter]=list
        for i=1,255 do
            local aura=C_UnitAuras.GetAuraDataByIndex(unit,i,filter)
            if not aura then break end
            list[i]=aura
        end
    end
    return list[index]
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
                    for key,wanted in pairs(group.candidates or empty) do
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

local sorted,sortConfig,sortDescending={},empty,false
local function auraOrder(a,b)
    if a.sqRank~=b.sqRank then return (a.sqRank or 0)<(b.sqRank or 0) end
    local x,y=a.sqAura or empty,b.sqAura or empty
    local left,right
    if sortConfig.sortMethod=='NAME' then
        left=public(x.name) and x.name or '';right=public(y.name) and y.name or ''
    else
        left=number(x.expirationTime) and x.expirationTime or 0
        right=number(y.expirationTime) and y.expirationTime or 0
    end
    if left==right then return a.sqIndex<b.sqIndex end
    if sortDescending then return left>right else return left<right end
end
function UF:SortAuraButtons(container)
    local config=container.config or empty
    local count=0
    for index=1,container.createdButtons or #container do
        local button=container[index]
        if button and button:IsShown() then count=count+1;sorted[count]=button;button.sqIndex=index end
    end
    for index=#sorted,count+1,-1 do sorted[index]=nil end
    sortConfig=config;sortDescending=config.sortDirection=='DESCENDING'
    table.sort(sorted,auraOrder)
    local per=math.max(1,config.perrow or 8)
    -- One quantised pitch for every cell, so neighbours share an edge exactly
    -- (rounding each offset on its own left 1 px seams).
    local cell=self:Scale(container.size)+self:Scale(container.spacing or config.spacing or 1)
    local anchor=container.initialAnchor
    local dx=((container['growth-x'] or config.growthX)=='LEFT' and -1 or 1)*cell
    local dy=((container['growth-y'] or config.growthY)=='DOWN' and -1 or 1)*cell
    local limit=container.visibleLimit or count
    for index=1,count do
        local button=sorted[index]
        if index>limit then button:Hide()
        else
            if button.sqSlot~=index or button.sqPer~=per or button.sqDX~=dx or button.sqDY~=dy or button.sqAnchor~=anchor then
                button.sqSlot,button.sqPer,button.sqDX,button.sqDY,button.sqAnchor=index,per,dx,dy,anchor
                button:ClearAllPoints()
                button:SetPoint(anchor,container,anchor,((index-1)%per)*dx,math.floor((index-1)/per)*dy)
            end
            if button.sqCountConfig~=config or button.sqCountRev~=styleRev then
                -- Count style depends only on the row's settings; set it once per button.
                -- The player's bars keep their own size and corner (container.ownCount).
                button.sqCountConfig=config;button.sqCountRev=styleRev
                local own=container.ownCount
                local corner=not own and countPosition or config.countPosition or 'BOTTOMRIGHT'
                self:ApplyFont(button.Count,countFont or config.countFont or self.db.font,
                    not own and countSize or config.countFontSize or 8,config.countFontOutline or 'OUTLINE')
                button.Count:ClearAllPoints()
                point(button.Count,corner,button,corner,config.countXOffset or 0,config.countYOffset or 0)
            end
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
local barsDescending=false
local function barOrder(a,b)
    local x=number(a.expirationTime) and a.expirationTime or 0
    local y=number(b.expirationTime) and b.expirationTime or 0
    if x==y then return (number(a.auraInstanceID) and a.auraInstanceID or 0)<(number(b.auraInstanceID) and b.auraInstanceID or 0) end
    if barsDescending then return x>y else return x<y end
end
-- The seconds text is rewritten when its whole number changes, not every frame.
local function barTick(self)
    local left=math.max(0,self.expires-GetTime())
    local whole=math.floor(left+.5)
    if whole~=self.shownLeft then self.shownLeft=whole;self.Time:SetFormattedText('%.0f',left) end
    if not self.SetTimerDuration then self:SetValue(left) end
end
local plainBar={r=.1,g=.1,b=.1,a=1}
function UF:RefreshAuraBars(frame)
    frame.sqBarsDirty=nil
    local config=frame.db.aurabar
    if not config or not config.enable then if frame.AuraBars then frame.AuraBars:Hide() end;return end
    local unit=frame.__unit;if not unit or not C_UnitAuras.GetAuraDataByIndex then return end
    if not frame.AuraBars then frame.AuraBars=CreateFrame('Frame',nil,frame);frame.AuraBars.bars={} end
    local holder=frame.AuraBars;holder:Show()
    local friendly=UnitCanAssist('player',unit)
    friendly=public(friendly) and friendly or false
    local filter=friendly and config.friendlyAuraType or config.enemyAuraType
    filter=filter or 'HARMFUL'
    -- FilterAura only reads this table: one reused shallow overlay, no deep copy per event.
    local filterConfig=holder.filterConfig or {};holder.filterConfig=filterConfig
    wipe(filterConfig)
    for key,value in pairs(config) do filterConfig[key]=value end
    local subset=friendly and config.friendlyFilter or config.enemyFilter
    if subset then for key,value in pairs(subset) do filterConfig[key]=value end end
    local auras=holder.list or {};holder.list=auras
    wipe(auras)
    for index=1,255 do
        local aura=auraAt(unit,filter,index)
        if not aura then break end
        if self:FilterAura(filterConfig,unit,aura) then auras[#auras+1]=aura end
    end
    barsDescending=config.sortDirection=='DESCENDING'
    table.sort(auras,barOrder)
    local h=config.height or 15;local spacing=config.spacing or 5;local max=config.maxBars or 3
    local w=frame.db.width-3-4*(self.BORDER+self.SPACING)-h+1
    holder:ClearAllPoints()
    local split=frame.Buffs and frame.Buffs.cellsAcross and frame.Buffs
    if split then
        -- Split rows are narrow corner blocks, not a frame-wide strip: the bars
        -- stay on the frame and clear however many rows are in use.
        local rows=0
        for _,key in ipairs(auraKeys) do
            local row=frame[key]
            if row and row:IsShown() and row['growth-y']~='DOWN' then
                local per=math.max(1,row.config and row.config.perrow or 8)
                rows=math.max(rows,math.ceil(math.min(row.visibleButtons or 0,row.visibleLimit or 0)/per))
            end
        end
        holder:SetPoint('BOTTOMLEFT',frame,'TOPLEFT',self:Scale(h+spacing+3),
            self:Scale((config.yOffset or 0)+(split.splitLift or 0)+(split.classLift or 0))+rows*self:Scale(split.size))
    else
        local region=config.attachTo=='DEBUFFS' and frame.Debuffs or config.attachTo=='BUFFS' and frame.Buffs or frame
        point(holder,'BOTTOMLEFT',region,'TOPLEFT',h+spacing+3,config.yOffset or 0)
    end
    holder:SetSize(self:Scale(w),self:Scale(max*(h+spacing)))
    for index=1,math.max(max,#holder.bars) do
        local bar=holder.bars[index]
        local aura=index<=max and auras[index]
        if aura then
            if not bar then bar=newBar(frame);holder.bars[index]=bar end
            -- Geometry and fonts follow the settings, not each aura event.
            local mult,font,fontSize,outline=self.pixelMult,self.db.font,self.db.fontSize,self.db.fontOutline
            if bar.sqW~=w or bar.sqH~=h or bar.sqGap~=spacing or bar.sqMult~=mult then
                bar.sqW,bar.sqH,bar.sqGap,bar.sqMult=w,h,spacing,mult
                bar:ClearAllPoints();point(bar,'BOTTOMLEFT',holder,'BOTTOMLEFT',0,(index-1)*(h+spacing))
                bar:SetSize(self:Scale(w),self:Scale(h));bar.Icon:SetSize(self:Scale(h),self:Scale(h))
                bar.Icon:ClearAllPoints();point(bar.Icon,'RIGHT',bar,'LEFT',-spacing-3,0)
            end
            if bar.sqFont~=font or bar.sqFontSize~=fontSize or bar.sqOutline~=outline then
                bar.sqFont,bar.sqFontSize,bar.sqOutline=font,fontSize,outline
                self:ApplyFont(bar.Name,font,fontSize,outline)
                self:ApplyFont(bar.Time,font,fontSize,outline)
            end
            bar.Icon:SetTexture(aura.icon)
            bar.Name:SetText(aura.name);bar.auraInstanceID=aura.auraInstanceID
            local duration=C_UnitAuras.GetAuraDuration and C_UnitAuras.GetAuraDuration(unit,aura.auraInstanceID)
            if duration and bar.SetTimerDuration then
                bar:SetTimerDuration(duration,Enum.StatusBarInterpolation.Immediate,Enum.StatusBarTimerDirection.RemainingTime)
            elseif number(aura.duration) and number(aura.expirationTime) then
                bar:SetMinMaxValues(0,math.max(1,aura.duration));bar:SetValue(math.max(0,aura.expirationTime-GetTime()))
            else self.status.restrictedAuraBarTiming=true;bar:SetMinMaxValues(0,1);bar:SetValue(1) end
            local c=self.db.colors[filter=='HELPFUL' and 'auraBarBuff' or 'auraBarDebuff'] or plainBar
            bar:SetStatusBarColor(c.r,c.g,c.b,c.a);bar:SetReverseFill(config.reverseFill==true)
            if number(aura.expirationTime) then
                bar.expires=aura.expirationTime;bar.shownLeft=nil
                if not bar.ticking then bar.ticking=true;bar:SetScript('OnUpdate',barTick) end
            else
                if bar.ticking then bar.ticking=nil;bar:SetScript('OnUpdate',nil) end
                bar.Time:SetText('')
            end
            bar:Show()
        elseif bar then
            bar:Hide()
            if bar.ticking then bar.ticking=nil;bar:SetScript('OnUpdate',nil) end
        end
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
    if button.sqSize~=size or button.sqStyle~=styleRev then
        -- Geometry and the 58-piece rim follow the cell size and the look
        -- settings only, not each repaint.
        button.sqSize=size;button.sqStyle=styleRev
        button:SetSize(size,size)
        -- Same cell material as the action bars: cells touch and share one rim line,
        -- the icon sits inside the painted inner edge. Without the rim it fills the cell.
        local inner=cellRim and size*37/43 or size
        button.Icon:SetSize(inner,inner)
        if cellRim and ns.DarkSkin and ns.DarkSkin.RawSlotBorder then button.sqRim=ns.DarkSkin:RawSlotBorder(button,frame,1) end
        if button.sqRim then button.sqRim:SetShown(cellRim) end
        if button.Cooldown.SetDrawSwipe then button.Cooldown:SetDrawSwipe(cellSwipe) end
        if button.Cooldown.SetHideCountdownNumbers then
            local numbers=container.countdown;if numbers==nil then numbers=cellNumbers end
            button.Cooldown:SetHideCountdownNumbers(not numbers)
        end
    end
    local mouse=not container.disableMouse
    if button.sqMouse~=mouse then button.sqMouse=mouse;button:EnableMouse(mouse) end
    local id=not aura.test and public(aura.auraInstanceID) and aura.auraInstanceID or nil
    button.auraInstanceID=id
    if keep and id and button.sqPainted==id and not keep[id] then button:Show();return end
    button.sqPainted=id
    button.Icon:SetTexture(aura.icon)
    button.Icon:SetDesaturated(key=='Debuffs' and (desatAll or desatSaved and config.desaturate==true) and personal(aura)==false)
    -- Preview icons and weapon enchants carry their own start time.
    local timed=aura.start~=nil
    if timed then button.Cooldown:SetCooldown(aura.start,aura.duration) end
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
-- The cell constructor and painter, shared with the nameplate debuff row.
UF.NewAuraIcon,UF.PaintAuraIcon=newIcon,paintIcon
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
-- `dirtyOnly` (the queued-event pass) redraws just the rows an event touched.
function UF:RefreshAuraIcons(frame,dirtyOnly)
    local unit=frame.__unit
    frame.sqAuraDirty=nil
    for _,key in ipairs(auraKeys) do
        local container=frame[key];local config=container and container.config
        if container and (not dirtyOnly or container.sqDirty) then
            container.sqDirty=nil
            local used=0
            if self.auraTest and config and config.enable~=false and frame:IsShown() then
                -- Layout preview: placeholder icons, no unit data, no filters.
                for index=1,self.auraTest do
                    local button=container[index]
                    if not button then button=newIcon(container,frame);container[index]=button end
                    local aura={test=true,icon=testIcons[key][(index-1)%#testIcons[key]+1],duration=30+index*15,start=GetTime()-(30+index*15)*.4,
                        expirationTime=GetTime()+index*20,applications=index%3==0 and index or 1,name=key..index}
                    button.sqAura=aura;button.sqRank=0;used=index
                    paintIcon(button,container,frame,unit or 'player',aura,key)
                end
            elseif config and config.enable~=false and unit and frame:IsShown() and C_UnitAuras.GetAuraDataByIndex then
                local filter=container.filter or (key=='Buffs' and 'HELPFUL' or 'HARMFUL')
                for index=1,255 do
                    local aura=auraAt(unit,filter,index)
                    if not aura then break end
                    local button=container[used+1]
                    if not button then button=newIcon(container,frame);container[used+1]=button end
                    if self:FilterAura(config,unit,aura,button) then
                        used=used+1;paintIcon(button,container,frame,unit,aura,key)
                    end
                end
            end
            for index=used+1,#container do
                local spare=container[index]
                spare:Hide();spare.sqAura=nil;spare.sqPainted=nil
            end
            container.createdButtons=#container;container.visibleButtons=used
            container:SetShown(config and config.enable~=false or false)
            self:SortAuraButtons(container)
        end
    end
end

-- Aura work is queued and drawn once per rendered frame: several events in
-- one frame (a unit update plus its target change, a burst of UNIT_AURA) cost
-- one read of the unit and one repaint of the rows they touched.
local playerBars={}
local driver=CreateFrame('Frame');driver:Hide()
local touched,rowsFull,playerFull={},{},false
local function mark(frame,bars,full)
    for _,key in ipairs(auraKeys) do if frame[key] then frame[key].sqDirty=true end end
    frame.sqAuraDirty=true
    if full then frame.sqAuraFull=true end
    if bars and frame.db and frame.db.aurabar and frame.db.aurabar.enable then frame.sqBarsDirty=true end
    driver:Show()
end
local function kindOf(aura)
    if type(aura)~='table' then return nil end
    local helpful,harmful=aura.isHelpful,aura.isHarmful
    if public(helpful) and helpful==true then return 'HELPFUL' end
    if public(harmful) and harmful==true then return 'HARMFUL' end
end
local unitFrames={}
-- Rows of `unit` that draw `filter` auras (nil: every row).
local function markKind(unit,filter)
    for _,frame in ipairs(unitFrames) do
        for _,key in ipairs(auraKeys) do
            local row=frame[key]
            if row and (not filter or (row.filter or (key=='Buffs' and 'HELPFUL' or 'HARMFUL'))==filter) then row.sqDirty=true;frame.sqAuraDirty=true end
        end
    end
    if unit=='player' then
        for _,bar in ipairs(playerBars) do if not filter or bar.filter==filter then bar.sqDirty=true end end
    end
end
-- Rows that show this aura now; an aura no row shows cannot change one by leaving.
local function markShown(unit,id)
    for _,frame in ipairs(unitFrames) do
        for _,key in ipairs(auraKeys) do
            local row=frame[key]
            if row and not row.sqDirty then
                for index=1,#row do
                    local button=row[index]
                    if button.sqAura and button.auraInstanceID==id then row.sqDirty=true;frame.sqAuraDirty=true;break end
                end
            end
        end
    end
    if unit=='player' then
        for _,bar in ipairs(playerBars) do
            if not bar.sqDirty then
                for index=1,#bar do
                    local button=bar[index]
                    if button.sqAura and button.auraInstanceID==id then bar.sqDirty=true;break end
                end
            end
        end
    end
end
-- UNIT_AURA names what changed. Anything unreadable falls back to a full redraw.
local function auraEvent(unit,info)
    wipe(unitFrames)
    for _,frame in ipairs(UF.objects) do if frame.__unit==unit then unitFrames[#unitFrames+1]=frame end end
    if #unitFrames==0 and unit~='player' then return end
    local full=not public(info) or type(info)~='table' or not public(info.isFullUpdate) or info.isFullUpdate
    local added,updated,removed
    if not full then
        added,updated,removed=info.addedAuras or empty,info.updatedAuraInstanceIDs or empty,info.removedAuraInstanceIDs or empty
        for _,list in ipairs({added,updated,removed}) do
            if not public(list) or type(list)~='table' then full=true end
        end
    end
    local changed=false
    if not full then
        local ids=touched[unit]
        if not ids then ids={};touched[unit]=ids end
        for _,aura in ipairs(added) do
            changed=true;markKind(unit,kindOf(aura))
        end
        for _,id in ipairs(updated) do
            if not number(id) then full=true;break end
            changed=true;ids[id]=true
            local aura=C_UnitAuras.GetAuraDataByAuraInstanceID and C_UnitAuras.GetAuraDataByAuraInstanceID(unit,id)
            -- A changed aura may newly pass a duration filter: its whole kind is redrawn.
            if aura then markKind(unit,kindOf(aura)) else markShown(unit,id) end
        end
        for _,id in ipairs(not full and removed or empty) do
            if not number(id) then full=true;break end
            changed=true;markShown(unit,id)
        end
    end
    if full then
        rowsFull[unit]=true
        if unit=='player' then playerFull=true end
        markKind(unit,nil)
    elseif not changed then return end
    for _,frame in ipairs(unitFrames) do
        if frame.db and frame.db.aurabar and frame.db.aurabar.enable then frame.sqBarsDirty=true end
    end
    driver:Show()
end
local scans={}
local function drain()
    for _,frame in ipairs(UF.objects) do
        local unit=frame.__unit
        if frame.sqAuraDirty then
            if frame.sqAuraFull or not unit or rowsFull[unit] then keep=nil else keep=touched[unit] or empty end
            UF:RefreshAuraIcons(frame,true)
        end
        frame.sqAuraFull=nil
        if frame.sqBarsDirty then UF:RefreshAuraBars(frame) end
    end
    if playerFull then keep=nil else keep=touched.player or empty end
    UF:RefreshPlayerBars(true)
end
driver:SetScript('OnUpdate',function(self)
    self:Hide()
    wipe(scans);shared=scans
    local ok,err=pcall(drain)
    shared=nil;keep=nil;playerFull=false
    wipe(rowsFull)
    for _,ids in pairs(touched) do wipe(ids) end
    if not ok then geterrorhandler()(err) end
end)

local configure=UF.ConfigureState
function UF:ConfigureState(frame)
    configure(self,frame)
    if not frame.squancherAuraShow then
        frame.squancherAuraShow=true
        -- oUF runs this on show and whenever a group button is given another
        -- unit, which raises no aura event. Its timed poll of eventless units
        -- ('OnUpdate') is left out: those rows follow UNIT_TARGET as before.
        -- A configure has just drawn the rows itself.
        local function refresh(_,event)
            if event~='OnUpdate' and event~='SquanchOnConfigure' then mark(frame,true,true) end
        end
        if frame.UpdateAllElements then hooksecurefunc(frame,'UpdateAllElements',refresh)
        else frame:HookScript('OnShow',refresh) end
    end
    self:RefreshAuraIcons(frame);self:RefreshAuraBars(frame)
end
-- Only frames whose unit the event can have changed are redrawn.
local function dispatch(event,unit,info)
    local exact,second,prefix
    if event=='PLAYER_TARGET_CHANGED' then prefix='^target'
    elseif event=='PLAYER_FOCUS_CHANGED' then prefix='^focus'
    elseif event=='INSTANCE_ENCOUNTER_ENGAGE_UNIT' then prefix='^boss'
    elseif event=='ARENA_OPPONENT_UPDATE' then prefix='^arena'
    elseif not public(unit) or type(unit)~='string' then return
    elseif event=='UNIT_AURA' then return auraEvent(unit,info)
    elseif event=='UNIT_TARGET' then exact=unit..'target'
    else -- UNIT_PET: the owner's pet and that pet's target
        exact=unit=='player' and 'pet' or (unit:gsub('^(%a+)(%d+)$','%1pet%2'));second=exact..'target'
    end
    local bars=event=='PLAYER_TARGET_CHANGED'
    for _,frame in ipairs(UF.objects) do
        local own=frame.__unit
        -- The unit behind the token changed: instance IDs start over.
        if own and (own==exact or own==second or prefix and own:find(prefix)) then mark(frame,bars,true) end
    end
end
local events=CreateFrame('Frame');events:RegisterEvent('UNIT_AURA');events:RegisterEvent('PLAYER_TARGET_CHANGED');events:RegisterEvent('UNIT_TARGET');events:RegisterEvent('PLAYER_FOCUS_CHANGED');events:RegisterEvent('UNIT_PET')
-- Boss and arena tokens change hands without an aura event; not every client has both events.
pcall(events.RegisterEvent,events,'INSTANCE_ENCOUNTER_ENGAGE_UNIT');pcall(events.RegisterEvent,events,'ARENA_OPPONENT_UPDATE')
events:SetScript('OnEvent',function(_,event,unit,info) dispatch(event,unit,info) end)
if UF.Initialized then for _,frame in ipairs(UF.objects) do UF:RefreshAuraIcons(frame);UF:RefreshAuraBars(frame) end end

-- The player's own buff and debuff bars, replacing the game's top-right rows
-- with the same touching action-bar cells. /sqedit moves and scales each bar.
local function playerBar(key,filter,y)
    local bar=CreateFrame('Frame','SquanchOnPlayer'..key,UIParent)
    bar.__unit='player';bar.key=key;bar.filter=filter;bar.defaultY=y
    bar.spacing=0;bar.ownCount=true;bar.enabled=true;bar:SetFrameStrata('LOW')
    playerBars[#playerBars+1]=bar
    return bar
end
playerBar('Buffs','HELPFUL',-12);playerBar('Debuffs','HARMFUL',-112)
local function countdownFont(bar)
    if not UF.db then return end
    local name='SquanchOnAuraCountdown'..bar.key
    if not bar.countdownFont then bar.countdownFont=CreateFont(name) end
    bar.countdownFont:SetFont(UF:Font(UF.db.font),bar.countdownSize or 11,'OUTLINE')
    return name
end
local function clamp(value,fallback,low,high)
    if not number(value) then return fallback end
    return math.max(low,math.min(high,math.floor(value+.5)))
end
-- One bar's settings become the fields the shared row code already reads.
-- `live` (a setting was just edited, out of combat) keeps a geometry saved by
-- /sqedit at the same on-screen icon scale when the bar's natural width changes.
local function applyBar(bar,s,live)
    local size,per=clamp(s.size,30,16,64),clamp(s.perRow,12,1,24)
    local oldWidth,oldSize,oldLeft=bar.size and bar.size*bar.config.perrow,bar.size,bar['growth-x']=='LEFT'
    bar.size=size;bar.visibleLimit=clamp(s.max,36,1,80)
    bar['growth-x']=s.growthX=='RIGHT' and 'RIGHT' or 'LEFT';bar['growth-y']=s.growthY=='UP' and 'UP' or 'DOWN'
    bar.initialAnchor=(bar['growth-y']=='DOWN' and 'TOP' or 'BOTTOM')..(bar['growth-x']=='LEFT' and 'RIGHT' or 'LEFT')
    bar.config={perrow=per,sortMethod=s.sortMethod=='NAME' and 'NAME' or 'TIME_REMAINING',
        sortDirection=s.sortDirection=='ASCENDING' and 'ASCENDING' or 'DESCENDING',countPosition='BOTTOMRIGHT',countYOffset=2,
        countFontSize=clamp(s.countSize,10,6,24),tooltipAnchorType='ANCHOR_BOTTOMLEFT'}
    bar.countdown=s.countdown~=false;bar.countdownSize=clamp(s.countdownSize,11,6,24)
    bar.enabled=s.enable~=false
    bar:SetSize(per*size,size);bar:SetShown(bar.enabled)
    countdownFont(bar)
    local width=per*size
    if not live or not oldWidth or oldWidth==width and oldLeft==(bar['growth-x']=='LEFT') then return false end
    local editor=ns.LayoutEditor
    local rect=editor and editor.Read and editor:Read('player_'..bar.key:lower())
    if rect and number(rect.w) and number(rect.x) then
        local wide=rect.w*width/oldWidth
        if oldLeft then rect.x=rect.x+rect.w-wide end -- the anchored right end stays put
        rect.w=wide
        if number(rect.h) then rect.h=rect.h*size/oldSize end
    end
    return true
end
for _,bar in ipairs(playerBars) do applyBar(bar,UF.auraDefaults.bars[bar.key]) end
local function cancel(button)
    -- Out of combat only: the client refuses addon cancels during combat.
    -- Weapon enchants are not cancelled here: CancelItemTempEnchantment is
    -- reserved for secure code.
    if InCombatLockdown() or not button.auraInstanceID then return end
    for index=1,255 do
        local aura=C_UnitAuras.GetAuraDataByIndex('player',index,'HELPFUL')
        if not aura then return end
        if public(aura.auraInstanceID) and aura.auraInstanceID==button.auraInstanceID then
            pcall(CancelUnitBuff,'player',index,'HELPFUL');return
        end
    end
end
local function playerIcon(bar,index)
    local button=bar[index]
    if not button then
        button=newIcon(bar,bar);bar[index]=button
        local font=button.Cooldown.SetCountdownFont and (bar.countdownFont and bar.countdownFont:GetName() or countdownFont(bar))
        if font then button.Cooldown:SetCountdownFont(font) end
        if bar.key=='Buffs' then
            button:RegisterForClicks('RightButtonUp');button:SetScript('OnClick',cancel)
            button:HookScript('OnEnter',function(self)
                if not self.sqEnchant or GameTooltip:IsForbidden() then return end
                GameTooltip:SetOwner(self,'ANCHOR_BOTTOMLEFT')
                if GameTooltip.SetInventoryItem then GameTooltip:SetInventoryItem('player',15+self.sqEnchant) end
            end)
        end
    end
    return button
end
-- Temporary weapon enchants (main hand 1, off hand 2) join the buff bar. The
-- client reports only the time left, so the first value seen is the swipe's span.
local enchantState,enchantList={},{}
local enchantTicker,enchantSeen,lastMain,lastOff
local function enchantAura(hand,has,left,charges,id)
    local state=enchantState[hand]
    if not public(has) or not has or not number(left) then enchantState[hand]=nil;return end
    if not public(id) then id=nil end
    local expires=GetTime()+left/1000
    if not state or state.id~=id or expires>state.expires+2 then
        state={id=id,total=math.max(1,left/1000),aura={enchant=hand,name='WeaponEnchant'..hand}};enchantState[hand]=state
    end
    state.expires=expires
    local aura=state.aura
    aura.icon=GetInventoryItemTexture and GetInventoryItemTexture('player',15+hand) or 134400
    aura.duration=state.total;aura.start=expires-state.total;aura.expirationTime=expires
    aura.applications=number(charges) and charges or 0
    return aura
end
local function text(value) return public(value) and tostring(value) or '?' end
local function enchantTick()
    local main,mainLeft,mainCharges,mainID,off,offLeft,offCharges,offID=GetWeaponEnchantInfo()
    local seen=text(main)..text(mainCharges)..text(mainID)..text(off)..text(offCharges)..text(offID)
    local renewed=number(mainLeft) and lastMain and mainLeft>lastMain+2000 or number(offLeft) and lastOff and offLeft>lastOff+2000
    lastMain,lastOff=number(mainLeft) and mainLeft or nil,number(offLeft) and offLeft or nil
    if seen~=enchantSeen or renewed then enchantSeen=seen;UF:RefreshPlayerBars() end
end
local function weaponEnchants()
    local count=0
    if showEnchants and GetWeaponEnchantInfo then
        local main,mainLeft,mainCharges,mainID,off,offLeft,offCharges,offID=GetWeaponEnchantInfo()
        local aura=enchantAura(1,main,mainLeft,mainCharges,mainID)
        if aura then count=count+1;enchantList[count]=aura end
        aura=enchantAura(2,off,offLeft,offCharges,offID)
        if aura then count=count+1;enchantList[count]=aura end
    end
    -- The 1 s check runs only while an enchant is up (expiry raises no reliable event).
    if count>0 and not enchantTicker and C_Timer and C_Timer.NewTicker then enchantTicker=C_Timer.NewTicker(1,enchantTick)
    elseif count==0 and enchantTicker then enchantTicker:Cancel();enchantTicker=nil;enchantSeen=nil end
    return count
end
-- `dirtyOnly` (the queued-event pass) redraws just the bars an event touched.
function UF:RefreshPlayerBars(dirtyOnly)
    if not self.db then return end
    for _,bar in ipairs(playerBars) do if not dirtyOnly or bar.sqDirty then
        bar.sqDirty=nil
        local used=0
        if not bar.enabled then -- hidden bar: nothing is read or drawn
        elseif self.auraTest then
            for index=1,self.auraTest do
                local button=playerIcon(bar,index)
                local aura={test=true,icon=testIcons[bar.key][(index-1)%#testIcons[bar.key]+1],duration=30+index*15,start=GetTime()-(30+index*15)*.4,
                    expirationTime=GetTime()+index*20,applications=index%3==0 and index or 1,name=bar.key..index}
                button.sqAura=aura;button.sqRank=0;button.sqEnchant=nil;used=index
                paintIcon(button,bar,bar,'player',aura,bar.key)
            end
        else
            for index=1,255 do
                local aura=auraAt('player',bar.filter,index)
                if not aura then break end
                local button=playerIcon(bar,index)
                button.sqAura=aura;button.sqRank=0;button.sqEnchant=nil;used=index
                paintIcon(button,bar,bar,'player',aura,bar.key)
            end
            if bar.key=='Buffs' then
                for index=1,weaponEnchants() do
                    local aura=enchantList[index]
                    used=used+1
                    local button=playerIcon(bar,used)
                    button.sqAura=aura;button.sqRank=0;button.sqEnchant=aura.enchant
                    paintIcon(button,bar,bar,'player',aura,bar.key)
                end
            end
        end
        for index=used+1,#bar do
            local spare=bar[index]
            spare:Hide();spare.sqAura=nil;spare.sqPainted=nil
        end
        bar.createdButtons=#bar
        self:SortAuraButtons(bar)
    end end
end
-- The bars are plain frames, so a first placement is legal in combat (login or
-- /reload mid-fight). The saved /sqedit geometry is applied by LayoutTargets,
-- which waits for combat to end itself; returns false while that is outstanding.
function UF:PlacePlayerBars()
    local combat=InCombatLockdown()
    for _,bar in ipairs(playerBars) do
        if not combat or not bar.placed then
            bar.placed=true
            bar:SetScale(1);bar:ClearAllPoints();bar:SetPoint('TOPRIGHT',UIParent,'TOPRIGHT',-263,bar.defaultY)
            if ns.LayoutTargets then ns.LayoutTargets:ApplyScale('player_'..bar.key:lower(),bar) end
        end
    end
    return not combat
end
-- The game's own rows are parked under a hidden parent and stop listening.
-- No Show hook and no Hide call: nothing here runs in combat, so it is safe
-- whether or not this client protects those frames, and SetShown or a
-- parent-driven show cannot bring them back.
local attic=CreateFrame('Frame');attic:Hide()
-- Frames cannot list their events; these are the ones the game's aura rows use.
local nativeEvents={'UNIT_AURA','PLAYER_ENTERING_WORLD','GROUP_ROSTER_UPDATE','PLAYER_SPECIALIZATION_CHANGED',
    'WEAPON_ENCHANT_CHANGED','UNIT_INVENTORY_CHANGED','PLAYER_REGEN_ENABLED','PLAYER_REGEN_DISABLED',
    'UNIT_ENTERED_VEHICLE','UNIT_EXITED_VEHICLE','CVAR_UPDATE','EDIT_MODE_LAYOUTS_UPDATED'}
local retired={}
local function retire(native)
    if not native or native:GetParent()==attic then return true end
    if InCombatLockdown() then return false end
    local saved={parent=native:GetParent(),events={}}
    for _,event in ipairs(nativeEvents) do
        local ok,registered,unit,second=pcall(native.IsEventRegistered,native,event)
        if ok and registered then saved.events[event]={unit,second} end
    end
    retired[native]=saved
    native:UnregisterAllEvents();native:SetParent(attic)
    return true
end
-- Back under its own parent with the events it had. No native method is called
-- from here (that would taint its state): it redraws on its next own event.
local function restore(native)
    local saved=native and retired[native]
    if not saved or native:GetParent()~=attic then return true end
    if InCombatLockdown() then return false end
    native:SetParent(saved.parent)
    for event,units in pairs(saved.events) do
        if type(units[1])=='string' then pcall(native.RegisterUnitEvent,native,event,units[1],units[2])
        else pcall(native.RegisterEvent,native,event) end
    end
    retired[native]=nil
    return true
end
local playerPending
local function settle()
    local change=UF:AuraSettings().hideBlizzard~=false and retire or restore
    local done=change(BuffFrame)
    done=change(DebuffFrame) and done
    local placed=UF:PlacePlayerBars()
    -- UF.db is missing until the unit frames initialise, which also waits for combat.
    playerPending=not (done and placed and UF.db) or nil
    UF:ApplyAuraSettings()
end
-- Reads SquanchOnDB.auras into the locals and row fields the painters use, then
-- repaints. `live` marks an edit made in the options window.
function UF:ApplyAuraSettings(live)
    local settings=self:AuraSettings();local cell=settings.cell
    styleRev=styleRev+1
    cellRim,cellSwipe,cellNumbers=cell.rim~=false,cell.swipe~=false,cell.numbers==true
    desatAll,desatSaved=cell.desaturate=='ALWAYS',cell.desaturate~='ALWAYS' and cell.desaturate~='NEVER'
    countFont=type(cell.countFont)=='string' and cell.countFont~='' and cell.countFont or nil
    countSize=number(cell.countSize) and cell.countSize or nil
    countPosition=type(cell.countPosition)=='string' and cell.countPosition or nil
    showEnchants=settings.weaponEnchants~=false
    local moved=false
    for _,bar in ipairs(playerBars) do moved=applyBar(bar,settings.bars[bar.key],live) or moved end
    if moved then self:PlacePlayerBars() end
    if not self.db then return end
    for _,frame in ipairs(self.objects) do if frame.db then self:RefreshAuraIcons(frame) end end
    self:RefreshPlayerBars()
end
-- The "hide the game's rows" switch; false while combat postpones it.
function UF:ApplyNativeAuraRows()
    settle()
    return not playerPending
end
local playerEvents=CreateFrame('Frame')
playerEvents:RegisterEvent('PLAYER_LOGIN');playerEvents:RegisterEvent('PLAYER_ENTERING_WORLD');playerEvents:RegisterEvent('PLAYER_REGEN_ENABLED')
playerEvents:RegisterEvent('UNIT_INVENTORY_CHANGED');pcall(playerEvents.RegisterEvent,playerEvents,'WEAPON_ENCHANT_CHANGED')
playerEvents:SetScript('OnEvent',function(_,event,unit)
    if event=='UNIT_INVENTORY_CHANGED' or event=='WEAPON_ENCHANT_CHANGED' then
        if showEnchants and (event~='UNIT_INVENTORY_CHANGED' or unit=='player') then UF:RefreshPlayerBars() end
    elseif event~='PLAYER_REGEN_ENABLED' then settle()
    -- Next frame: the unit frames finish their own post-combat start first.
    elseif playerPending then C_Timer.After(0,settle) end
end)
