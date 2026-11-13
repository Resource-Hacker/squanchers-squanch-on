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
-- Set when the client refuses a read (aura data turned secret, see UF:AurasSecret):
-- the row being drawn then hands over to the client's container.
local refused=false
local function read(unit,index,filter)
    local ok,aura=pcall(C_UnitAuras.GetAuraDataByIndex,unit,index,filter)
    if ok then return aura end
    refused=true
    UF:AuraReport('C_UnitAuras.GetAuraDataByIndex '..tostring(filter),aura)
end
local function auraAt(unit,filter,index)
    if not shared then return read(unit,index,filter) end
    local byUnit=shared[unit]
    if not byUnit then byUnit={};shared[unit]=byUnit end
    local list=byUnit[filter]
    if not list then
        list={};byUnit[filter]=list
        local earlier=refused;refused=false
        for i=1,255 do
            local aura=read(unit,i,filter)
            if not aura then break end
            list[i]=aura
        end
        -- A refused read leaves the list short: every row reading it hands over.
        list.refused=refused or nil
        refused=refused or earlier
    end
    if list.refused then refused=true end
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
-- Stack count style of a row: font, size, outline, corner and offsets. The
-- cell settings win over the row's saved values, except on the player's bars,
-- which keep their own size and corner (container.ownCount).
local function countStyle(container)
    local config=container.config or empty
    local own=container.ownCount
    return countFont or config.countFont or UF.db.font,not own and countSize or config.countFontSize or 8,
        config.countFontOutline or 'OUTLINE',not own and countPosition or config.countPosition or 'BOTTOMRIGHT',
        config.countXOffset or 0,config.countYOffset or 0
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
                local font,size,outline,corner,x,y=countStyle(container)
                self:ApplyFont(button.Count,font,size,outline)
                button.Count:ClearAllPoints()
                point(button.Count,corner,button,corner,x,y)
            end
        end
    end
end

-- The client's own aura container ---------------------------------------------
-- Addon code may read auras only while aura data is readable. In combat (and in
-- encounters, keystones and PvP matches) the client refuses every C_UnitAuras
-- read from an addon with an error: "Auras cannot be accessed when secret while
-- tainted" (those functions carry RequiresUnitAuraAccess,
-- Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua). Then the unit
-- frame rows, the target's aura bars, the player's bars and the nameplate debuff
-- row (NameplateAuras.lua) hand over to the client's own container
-- (Blizzard_AuraContainer, CustomAuraContainerTemplate, which current oUF and
-- Plater use too): its secure code reads the auras through filter strings and
-- candidate filters, draws them into buttons dressed here, shows their tooltips
-- and can cancel a buff. Once aura data is readable again the row reads and
-- paints itself as before and the container is hidden and idle. One container
-- per owner (row, bar holder or plate row), made the first time the owner is
-- drawn for a unit (mostly out of combat, so a fight never waits for it). Its
-- buttons accept addon calls only while aura data is readable: they are dressed
-- when made and restyled only then.

-- Whether aura data is secret right now: then only the client's container can show it.
function UF:AurasSecret()
    local query=C_Secrets and C_Secrets.ShouldAurasBeSecret
    if query then
        local ok,secret=pcall(query)
        if ok and public(secret) then return secret==true end
    end
    return InCombatLockdown()
end
-- TEMPORARY diagnostic (remove once the rows are confirmed in a fight): the
-- first refused aura call of a session prints one chat line.
local reported
function UF:AuraReport(api,err)
    if reported then return end
    reported=true
    print(('|cff33ff99Squanch-On|r TEMPORARY aura check: %s failed (%s, aura data %s): %s'):format(api,
        InCombatLockdown() and 'in combat' or 'out of combat',self:AurasSecret() and 'secret' or 'readable',tostring(err)))
end
local function call(object,method,...)
    local ok,err=pcall(object[method],object,...)
    if not ok then UF:AuraReport('AuraContainer:'..method,err) end
    return ok
end
-- The shared rim, cut from the atlas of DarkSkin's raw slot rim: its four
-- straight edges as they are and each corner as one square (eight textures
-- instead of 58 halo-free strips, as the client makes these buttons in tens).
-- Not registered with DarkSkin, whose passes would have to touch them in combat.
local RIM_ATLAS='UI-Character-Info-GearSlot'
local RIM={{13,4.5,42,9},{13,46,42,50.5},{4.5,13,9,42},{46,13,50.5,42},
    {2,2,13,13},{42,2,53,13},{2,42,13,53},{42,42,53,53}}
local rimAtlas
local function rimPiece(button,rect)
    local texture=button:CreateTexture(nil,'BACKGROUND')
    if rimAtlas==nil then rimAtlas=C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(RIM_ATLAS) or false end
    if rimAtlas then
        local left,top=rimAtlas.leftTexCoord,rimAtlas.topTexCoord
        local dx,dy=(rimAtlas.rightTexCoord-left)/55,(rimAtlas.bottomTexCoord-top)/55
        texture:SetTexture(rimAtlas.file)
        texture:SetTexCoord(left+rect[1]*dx,left+rect[3]*dx,top+rect[2]*dy,top+rect[4]*dy)
    end
    texture:SetSnapToPixelGrid(false);texture:SetTexelSnappingBias(0)
    return texture
end
local plainBar={r=.1,g=.1,b=.1,a=1}
-- The owner's look (container.sqSpec, see SPEC) on one button: the painter's
-- cell (size, rim, swipe, countdown and stack numbers, grey for others'
-- debuffs) or an aura bar (texture, colour per kind, icon, fonts).
local function restyle(button,container)
    local spec=container.sqSpec
    local width,height=spec.width,spec.height
    button:SetSize(width,height)
    if button.sqBar then
        local bar,icon=button.sqBar,button.sqIcon
        bar:SetStatusBarTexture(spec.texture);bar:SetReverseFill(spec.reverse==true)
        local color
        if button.sqKind=='HELPFUL' then color=spec.buffColor else color=spec.debuffColor end
        color=color or plainBar
        bar:SetStatusBarColor(color.r,color.g,color.b,color.a)
        icon:SetSize(height,height);icon:ClearAllPoints();icon:SetPoint('RIGHT',bar,'LEFT',-spec.iconGap,0)
        UF:ApplyFont(button.sqName,spec.font,spec.fontSize,spec.fontOutline)
        UF:ApplyFont(button.sqTime,spec.font,spec.fontSize,spec.fontOutline)
    else
        button.sqIcon:SetSize(cellRim and width*37/43 or width,cellRim and height*37/43 or height)
        local group=container.sqGroups[button.sqGroup]
        button.sqIcon:SetDesaturated(group and group.desaturate or false)
        local cooldown=button.sqCooldown
        if cooldown.SetDrawSwipe then cooldown:SetDrawSwipe(cellSwipe) end
        if cooldown.SetHideCountdownNumbers then cooldown:SetHideCountdownNumbers(not spec.numbers) end
        if spec.countdownFont and cooldown.SetCountdownFont then cooldown:SetCountdownFont(spec.countdownFont) end
        UF:ApplyFont(button.sqCount,spec.countFont,spec.countSize,spec.countOutline)
        button.sqCount:ClearAllPoints()
        point(button.sqCount,spec.countCorner,button,spec.countCorner,spec.countX,spec.countY)
        -- The rim inherits the owner's alpha like any child.
        local skin=ns.DarkSkin
        local color,alpha,size=skin and skin.rimColor,skin and skin.borderAlpha or .95,width*55/43
        for index,piece in ipairs(button.sqRim) do
            local rect=RIM[index]
            piece:ClearAllPoints()
            piece:SetPoint('TOPLEFT',button,'CENTER',size*(rect[1]/55-.5),size*(.5-rect[2]/55))
            piece:SetSize(size*(rect[3]-rect[1])/55,size*(rect[4]-rect[2])/55)
            if color then piece:SetDesaturated(true);piece:SetVertexColor(color[1],color[2],color[3]) end
            piece:SetAlpha(alpha)
            piece:SetShown(cellRim)
        end
    end
    -- The client shows the tooltip itself; right-click cancel only where set
    -- (the player's buffs; never a weapon enchant, as on the painted bar).
    local mouse=spec.mouse and true or false
    button:EnableMouse(mouse)
    if mouse then pcall(button.SetTooltipAnchorPoint,button,spec.tooltip or 'ANCHOR_BOTTOMLEFT',spec.tooltipX or 0,spec.tooltipY or 0) end
    local cancel=button.sqGroup~='enchant' and spec.cancel or nil
    if button.sqCancel~=cancel then button.sqCancel=cancel;button:SetCancelAuraButtons(cancel) end
end
-- Called by the client for each button it makes, before it closes them to addons.
local function dress(button,container,key)
    local ok,err=pcall(function()
        button:EnableMouse(false)
        local icon=button:CreateTexture(nil,'ARTWORK');icon:SetTexCoord(.07,.93,.07,.93)
        button.sqIcon,button.sqGroup=icon,key
        if container.sqKind=='bar' then
            -- The painted aura bar (newBar below): bar, icon left of it, name and time.
            local bar=CreateFrame('StatusBar',nil,button,'BackdropTemplate');bar:SetAllPoints()
            bar:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=UF:Scale(1)})
            bar:SetBackdropColor(.054,.054,.054,.75);bar:SetBackdropBorderColor(0,0,0,1)
            local name,time=bar:CreateFontString(nil,'OVERLAY'),bar:CreateFontString(nil,'OVERLAY')
            point(name,'LEFT',bar,'LEFT',2,0);point(time,'RIGHT',bar,'RIGHT',-2,0)
            name:SetPoint('RIGHT',time,'LEFT',-2,0)
            if UF.SoftShadow then UF:SoftShadow(bar,bar);UF:SoftShadow(bar,icon) end
            button.sqBar,button.sqName,button.sqTime,button.sqKind=bar,name,time,key:match('^%u+')
            restyle(button,container)
            button:SetIcon(icon);button:SetSpellName(name);button:SetDurationText(time)
            button:SetDurationBar(bar,{interpolation=Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate,
                direction=Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime})
        else
            icon:SetPoint('CENTER')
            local cooldown=CreateFrame('Cooldown',nil,button,'CooldownFrameTemplate')
            cooldown:SetAllPoints(icon);cooldown:SetReverse(true);cooldown:SetDrawEdge(false)
            local overlay=CreateFrame('Frame',nil,button)
            overlay:SetAllPoints();overlay:SetFrameLevel(cooldown:GetFrameLevel()+1)
            local rim={}
            for index,rect in ipairs(RIM) do rim[index]=rimPiece(button,rect) end
            button.sqCooldown,button.sqCount,button.sqRim=cooldown,overlay:CreateFontString(nil,'OVERLAY'),rim
            restyle(button,container)
            -- The client draws icon, swipe and stack count from the aura itself.
            button:SetIcon(icon);button:SetDurationCooldown(cooldown);button:SetApplicationCount(button.sqCount)
        end
        container.sqButtons[#container.sqButtons+1]=button
    end)
    if not ok then UF:AuraReport('aura button setup',err) end
end
local templateReady
-- The container of `owner`, made on first use; nil where this client has none.
-- `kind` 'bar' dresses aura bars instead of cells.
function UF:NativeAuras(owner,kind)
    local container=owner.sqNative
    if container~=nil then return container or nil end
    owner.sqNative=false
    if templateReady==nil then
        local ok,info=false,nil
        if C_XMLUtil and C_XMLUtil.GetTemplateInfo then ok,info=pcall(C_XMLUtil.GetTemplateInfo,'CustomAuraContainerTemplate') end
        templateReady=ok and info~=nil
    end
    if not templateReady then return end
    local ok,made=pcall(CreateFrame,'AuraContainer',nil,owner,'CustomAuraContainerTemplate')
    if not ok then self:AuraReport('CreateFrame AuraContainer',made);return end
    made:SetSize(1,1);made:Hide()
    made.sqOwner,made.sqKind,made.sqGroups,made.sqEnchants,made.sqButtons,made.sqSpec=owner,kind,{},{},{},{}
    owner.sqNative=made
    return made
end
-- An owner's settings (`spec`, a flat table the owner fills; see the builders below):
--   anchor, growX, growY  start corner of the row and its growth ('LEFT'/'RIGHT', 'UP'/'DOWN')
--   width, height, spacing, line  cell or bar size, gap, maximum line length
--   numbers, countdownFont, countFont/Size/Outline/Corner, countX/Y  cell text
--   mouse, tooltip, tooltipX/Y, cancel  tooltip anchor, click tokens that cancel
--   enchants, enchantsFirst  the player's weapon enchants (nil: none)
--   texture, reverse, buffColor, debuffColor, iconGap, font, fontSize, fontOutline  bars
--   gen  owner's settings generation (a change restyles)
-- prefix (group key prefix) is read but not compared.
local SPEC={'anchor','growX','growY','width','height','spacing','line','numbers','countdownFont','countFont','countSize',
    'countOutline','countCorner','countX','countY','mouse','tooltip','tooltipX','tooltipY','cancel','enchants','enchantsFirst',
    'texture','reverse','buffColor','debuffColor','iconGap','font','fontSize','fontOutline','gen'}
local FLOW={LEFT=-1,RIGHT=1,UP=1,DOWN=-1}
local layoutScratch,enchantScratch={},{}
local function groupLayout(spec,order,into)
    local layout=into or layoutScratch
    layout.elementSpacing,layout.lineSpacing,layout.groupSpacing=spec.spacing,spec.spacing,spec.spacing
    layout.forceNewLine,layout.elementWidth,layout.elementHeight,layout.layoutIndex=false,spec.width,spec.height,order
    return layout
end
local function enchantLayout(spec)
    local layout=groupLayout(spec,nil,enchantScratch)
    local placement=CustomAuraContainerItemEnchantmentPlacement or empty
    layout.placement=spec.enchantsFirst and placement.BeforeAuraGroups or placement.AfterAuraGroups
    return layout
end
local function sortMethod(sort)
    local methods=AuraContainerSortMethod or empty
    return sort=='NAME' and methods.NameOnly or methods.ExpirationOnly
end
local function sortDirection(reverse)
    local directions=AuraContainerSortDirection or empty
    return reverse and directions.Reverse or directions.Normal
end
local enchantSlots
local function slots()
    if enchantSlots==nil then
        local slot=AuraContainerItemEnchantmentSlot
        enchantSlots=slot and {slot.MainHand,slot.OffHand} or false
    end
    return enchantSlots or empty
end
-- Brings `container` in line with its owner: settings, groups (each
-- {filter, candidates, sort ('NAME' or nil), reverse, max, desaturate, key?,
-- order?}; kept by key, a group no longer listed is disabled) and the weapon
-- enchants; shown, reading `unit` and fully refreshed only while `on`. Without
-- `groups` the container is hidden and idle.
function UF:SyncNativeAuras(container,unit,spec,groups,on)
    if groups then
        local have=container.sqSpec
        local changed=false
        for _,key in ipairs(SPEC) do if have[key]~=spec[key] then have[key]=spec[key];changed=true end end
        if changed then
            container.sqStyled=nil
            if container.sqAnchor~=spec.anchor then
                container.sqAnchor=spec.anchor
                local ok,err=pcall(function()
                    container:ClearAllPoints();container:SetPoint(spec.anchor,container.sqOwner,spec.anchor)
                end)
                if not ok then self:AuraReport('AuraContainer:SetPoint',err) end
            end
            call(container,'SetFlowLayoutAnchorPoint',spec.anchor)
            call(container,'SetFlowLayoutGrowthDirection',FLOW[spec.growX] or 1,FLOW[spec.growY] or 1)
            call(container,'SetFlowLayoutMaximumLineSize',spec.line)
            for key,group in pairs(container.sqGroups) do
                if group then call(container,'SetAuraGroupLayout',key,groupLayout(spec,group.order)) end
            end
            if next(container.sqEnchants) then call(container,'SetItemEnchantmentLayout',enchantLayout(spec)) end
        end
        if container.sqRev~=styleRev then container.sqRev=styleRev;container.sqStyled=nil end
        for _,group in pairs(container.sqGroups) do if group then group.wanted=false end end
        for index,want in ipairs(groups) do
            local key=want.key or (spec.prefix or 'g')..index
            local order=want.order or index
            local group=container.sqGroups[key]
            if group==nil then
                -- Registered first: the client dresses the group's first ten buttons at once.
                group={filter=want.filter,candidates=want.candidates,sort=want.sort,reverse=want.reverse,max=want.max,
                    order=order,desaturate=want.desaturate,on=true}
                container.sqGroups[key]=group
                local added=call(container,'AddAuraGroup',key,want.filter,{
                    maxFrameCount=want.max,candidateFilters=want.candidates,
                    sortMethod=sortMethod(want.sort),sortDirection=sortDirection(want.reverse),
                    layout=groupLayout(spec,order),
                    initializeFrame=function(button) dress(button,container,key) end,
                })
                -- A group the client rejected is not asked for again (false).
                if not added then group=false;container.sqGroups[key]=false end
            end
            if group then
                group.wanted=true
                if group.filter~=want.filter and call(container,'SetAuraGroupFilterString',key,want.filter) then group.filter=want.filter end
                if group.candidates~=want.candidates and call(container,'SetAuraGroupCandidateFilters',key,want.candidates) then
                    group.candidates=want.candidates
                end
                if (group.sort~=want.sort or group.reverse~=want.reverse)
                    and call(container,'SetAuraGroupSortMethod',key,sortMethod(want.sort),sortDirection(want.reverse)) then
                    group.sort,group.reverse=want.sort,want.reverse
                end
                if group.max~=want.max and call(container,'SetAuraGroupMaxFrameCount',key,want.max) then group.max=want.max end
                if group.order~=order and call(container,'SetAuraGroupLayout',key,groupLayout(spec,order)) then group.order=order end
                if group.desaturate~=want.desaturate then group.desaturate=want.desaturate;container.sqStyled=nil end
            end
        end
        for key,group in pairs(container.sqGroups) do
            if group and group.on~=group.wanted and call(container,'SetAuraGroupEnabled',key,group.wanted) then group.on=group.wanted end
        end
        if spec.enchants~=nil then
            for _,slot in ipairs(slots()) do
                local state=container.sqEnchants[slot]
                if state==nil and spec.enchants then
                    state={on=true};container.sqEnchants[slot]=state
                    if call(container,'AddItemEnchantment',slot,{initializeFrame=function(button) dress(button,container,'enchant') end}) then
                        call(container,'SetItemEnchantmentLayout',enchantLayout(spec))
                    else state=false;container.sqEnchants[slot]=false end
                end
                if state and state.on~=spec.enchants and call(container,'SetItemEnchantmentEnabled',slot,spec.enchants) then
                    state.on=spec.enchants
                end
            end
        end
        if not container.sqStyled and not self:AurasSecret() then
            container.sqStyled=true
            for _,button in ipairs(container.sqButtons) do
                local ok,err=pcall(restyle,button,container)
                if not ok then self:AuraReport('aura button style',err) end
            end
        end
        -- The same token can name another unit now (target, focus, party
        -- slots): the client re-reads it, as its own target frame does.
        if on then call(container,'SetUnit',unit);call(container,'UpdateAllAuras') end
    end
    on=on and groups and true or false
    if container.sqEnabled~=on and call(container,'SetEnabled',on) then container.sqEnabled=on end
    container:SetShown(on)
end
-- Aura data turns secret or readable at combat and restriction edges. Each
-- watcher (the rows below, NameplateAuras.lua) gets the new state on the next
-- frame, once the client's restriction state has settled after its event, and
-- redraws whatever is in the other mode.
local edgeWatchers,edgeQueued={},false
function UF:OnAuraSecrecyEdge(watcher) edgeWatchers[#edgeWatchers+1]=watcher end
local function edge()
    edgeQueued=false
    local secret=UF:AurasSecret()
    for _,watcher in ipairs(edgeWatchers) do
        local ok,err=pcall(watcher,secret)
        if not ok then geterrorhandler()(err) end
    end
end
local edges=CreateFrame('Frame')
edges:RegisterEvent('PLAYER_REGEN_DISABLED');edges:RegisterEvent('PLAYER_REGEN_ENABLED')
pcall(edges.RegisterEvent,edges,'ADDON_RESTRICTION_STATE_CHANGED')
edges:SetScript('OnEvent',function()
    if edgeQueued or not C_Timer then return end
    edgeQueued=true
    C_Timer.After(0,edge)
end)

-- The row's saved filters as the container's groups ----------------------------
-- A group takes a filter string and candidate filters: the aura's flags, spell
-- ID lists and a maximum duration (Blizzard_CustomAuraContainer.lua). Saved
-- filter groups map one to one. A priority list maps token by token, each group
-- excluding what an earlier token took, so an aura shows once, under its first
-- match, as in UF:FilterAura. Not expressible natively: minimum durations,
-- maximum durations on groups that keep permanent auras, and spell lists where
-- the client forbids matching by spell (helpful auras on enemies, harmful auras
-- on friends; an excluded list is ignored there, an included list shows nothing).
local FLAGS={isFromPlayerOrPlayerPet=true,isRoleAura=true,isPriorityAura=true,isStealable=true,nameplateShowAll=true,
    nameplateShowPersonal=true,canApplyAura=true,isBossAura=true,isBossOrRoleAura=true}
local function spellSet(name)
    local list=UF.db.auraFilters and UF.db.auraFilters[name]
    if type(list)~='table' or type(list.spells)~='table' then return nil end
    local set
    for id,spell in pairs(list.spells) do
        id=tonumber(id)
        if id and (spell==true or type(spell)=='table' and spell.enable~=false) then set=set or {};set[id]=true end
    end
    return set
end
local function union(a,b)
    if not a then return b end
    if not b then return a end
    local set={}
    for id in pairs(a) do set[id]=true end
    for id in pairs(b) do set[id]=true end
    return set
end
-- A saved filter string ('HARMFUL||PLAYER') as a clean one with the row's kind;
-- nil when it names the other kind (the row never reads those).
local function kindFilter(filter,kind)
    filter=type(filter)=='string' and filter:gsub('|+','|'):gsub('^|',''):gsub('|$','') or ''
    local padded='|'..filter..'|'
    if padded:find('|'..(kind=='HELPFUL' and 'HARMFUL' or 'HELPFUL')..'|',1,true) then return nil end
    if not padded:find('|'..kind..'|',1,true) then filter=filter=='' and kind or kind..'|'..filter end
    return filter
end
-- One group. A row that greys others' debuffs splits a group admitting both
-- into the player's own and everyone else's, so each is dressed as the painter would.
local function addGroup(out,filter,candidates,grey)
    local padded='|'..filter..'|'
    local own=candidates and candidates.isFromPlayerOrPlayerPet
    if own==nil then
        if padded:find('|!PLAYER|',1,true) then own=false elseif padded:find('|PLAYER|',1,true) then own=true end
    end
    if grey and own==nil then
        local mine,others={},{}
        for key,value in pairs(candidates or empty) do mine[key]=value;others[key]=value end
        mine.isFromPlayerOrPlayerPet,others.isFromPlayerOrPlayerPet=true,false
        out[#out+1]={filter=filter,candidates=mine,desaturate=false}
        out[#out+1]={filter=filter,candidates=others,desaturate=true}
    else
        out[#out+1]={filter=filter,candidates=candidates,desaturate=grey and own==false or false}
    end
end
local function nativeGroups(config,kind,grey)
    local out={}
    local lists=config.filterLists or (config.friendlyFilter and config.friendlyFilter.filterLists)
    if lists then
        local enabled=false
        for index=1,8 do
            local group=lists['group'..index]
            if group and group.enable then
                enabled=true
                local filter=kindFilter(group.filter,kind)
                if filter then
                    local candidates
                    for key,wanted in pairs(group.candidates or empty) do
                        if FLAGS[key] and (wanted==true or wanted==1) then candidates=candidates or {};candidates[key]=wanted==true end
                    end
                    local exclude=group.useBlocklist and spellSet(group.blockList) or nil
                    local include=group.useAllowlist and (spellSet(group.allowList) or {}) or nil
                    if exclude or include then
                        candidates=candidates or {};candidates.excludeSpellIDs,candidates.includeSpellIDs=exclude,include
                    end
                    addGroup(out,filter,candidates,grey)
                end
            end
        end
        if enabled then return out end
    end
    local priority=config.priority or ''
    if priority=='' then addGroup(out,kind,nil,grey);return out end
    local exclude,earlier,permanent=nil,{},true
    local function add(word,include)
        local filter=kind..(word and '|'..word or '')
        for _,taken in ipairs(earlier) do
            -- An earlier token with the same word already took every one of these.
            if taken==word then return end
            local negated=taken:sub(1,1)=='!' and taken:sub(2) or '!'..taken
            if negated~=word then filter=filter..'|'..negated end
        end
        local candidates
        if include or exclude or not permanent then
            candidates={includeSpellIDs=include,excludeSpellIDs=exclude}
            -- Without permanent auras a maximum duration means the same here.
            if not permanent then candidates.maxDuration=number(config.maxDuration) and config.maxDuration>0 and config.maxDuration or math.huge end
        end
        addGroup(out,filter,candidates,grey)
        if word then earlier[#earlier+1]=word end
    end
    for token in priority:gmatch('[^,]+') do
        local list=UF.db.auraFilters and UF.db.auraFilters[token]
        local key=token:lower()
        if type(list)=='table' then
            local set=spellSet(token)
            if set then
                if list.type~='Blacklist' then add(nil,set) end
                exclude=union(exclude,set)
            end
        elseif key=='blocknoduration' then permanent=false
        elseif key=='personal' then add('PLAYER')
        elseif key=='nonpersonal' then add('!PLAYER')
        elseif key=='dispellable' then add(kind=='HARMFUL' and 'RAID' or 'RAID_PLAYER_DISPELLABLE') end
    end
    return out
end
-- One row's look and layout as container settings (one reused table).
local scratch={}
local function rowSpec(row)
    local spec=wipe(scratch)
    local config=row.config or empty
    local cell,gap=UF:Scale(row.size),UF:Scale(row.spacing or config.spacing or 1)
    local per=math.max(1,config.perrow or 8)
    spec.anchor=row.initialAnchor or 'BOTTOMLEFT'
    spec.growX=row['growth-x'] or config.growthX or 'RIGHT'
    spec.growY=row['growth-y'] or config.growthY or 'UP'
    spec.width,spec.height,spec.spacing=cell,cell,gap
    -- Half a cell of slack, so a full line never wraps on rounding.
    spec.line=per*(cell+gap)-gap+cell/2
    local numbers=row.countdown;if numbers==nil then numbers=cellNumbers end
    spec.numbers=numbers and true or false
    spec.countdownFont=row.countdownFont and row.countdownFont:GetName() or nil
    spec.countFont,spec.countSize,spec.countOutline,spec.countCorner,spec.countX,spec.countY=countStyle(row)
    spec.mouse=not row.disableMouse
    spec.tooltip,spec.tooltipX,spec.tooltipY=config.tooltipAnchorType or 'ANCHOR_BOTTOMRIGHT',config.tooltipAnchorX or 0,config.tooltipAnchorY or 0
    return spec
end
-- A unit frame row: its saved filters, sort and cap per group; `on` hands it over.
local function syncRow(row,key,unit,on)
    local native=UF:NativeAuras(row)
    if not native then return end
    local config=row.config or empty
    if not row.sqNativeGroups or row.sqNativeRev~=styleRev then
        local grey=key=='Debuffs' and (desatAll or desatSaved and config.desaturate==true) or false
        row.sqNativeGroups,row.sqNativeRev=nativeGroups(config,row.filter or (key=='Buffs' and 'HELPFUL' or 'HARMFUL'),grey),styleRev
    end
    local sort,reverse=config.sortMethod=='NAME' and 'NAME' or nil,config.sortDirection=='DESCENDING'
    -- The row's cap applies to each group here (the client caps groups, not rows).
    local max=math.max(1,math.floor(row.visibleLimit or 40))
    for _,group in ipairs(row.sqNativeGroups) do group.sort,group.reverse,group.max=sort,reverse,max end
    UF:SyncNativeAuras(native,unit,rowSpec(row),row.sqNativeGroups,on)
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
-- The target's aura bars in the client's container: the saved filters per
-- reaction (group keys carry the kind, which picks the bar colour); bars stack
-- upward from the holder's corner as painted.
local function syncBars(holder,config,filterConfig,kind,unit,w,h,spacing,max,on)
    local native=UF:NativeAuras(holder,'bar')
    if not native then return end
    local cache=holder.sqNativeGroups
    if not cache or holder.sqNativeRev~=styleRev then cache={};holder.sqNativeGroups,holder.sqNativeRev=cache,styleRev end
    local groups=cache[kind]
    if not groups then groups=nativeGroups(filterConfig,kind,false);cache[kind]=groups end
    for _,group in ipairs(groups) do
        group.reverse,group.max=config.sortDirection=='DESCENDING',math.max(1,math.floor(max))
    end
    local spec=wipe(scratch)
    spec.prefix,spec.anchor,spec.growX,spec.growY=kind,'BOTTOMLEFT','RIGHT','UP'
    spec.width,spec.height,spec.spacing=UF:Scale(w),UF:Scale(h),UF:Scale(spacing)
    spec.line=spec.width*1.5 -- one bar per line
    spec.iconGap=UF:Scale(spacing+3)
    spec.texture,spec.reverse=UF:Texture(UF.db.statusbar),config.reverseFill==true
    spec.buffColor,spec.debuffColor=UF.db.colors.auraBarBuff,UF.db.colors.auraBarDebuff
    spec.font,spec.fontSize,spec.fontOutline=UF.db.font,UF.db.fontSize,UF.db.fontOutline
    spec.mouse,spec.tooltip=true,'ANCHOR_BOTTOMRIGHT'
    UF:SyncNativeAuras(native,unit,spec,groups,on)
end
function UF:RefreshAuraBars(frame)
    frame.sqBarsDirty=nil
    local config=frame.db.aurabar
    local holder=frame.AuraBars
    if not config or not config.enable then
        if holder then
            holder:Hide();holder.sqHanded=nil
            if holder.sqNative then self:SyncNativeAuras(holder.sqNative) end
        end
        return
    end
    local unit=frame.__unit;if not unit or not C_UnitAuras.GetAuraDataByIndex then return end
    if not holder then holder=CreateFrame('Frame',nil,frame);holder.bars={};frame.AuraBars=holder end
    holder:Show()
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
    -- Secret aura data, or a read the client refuses: its container draws the bars.
    local handed=self:AurasSecret()
    if not handed then
        refused=false
        for index=1,255 do
            local aura=auraAt(unit,filter,index)
            if not aura then break end
            if self:FilterAura(filterConfig,unit,aura) then auras[#auras+1]=aura end
        end
        if refused then handed=true;wipe(auras) end
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
    if handed or holder.sqHanded or holder.sqNative==nil or not holder.sqNativeGroups then
        syncBars(holder,config,filterConfig,filter:find('HELPFUL',1,true) and 'HELPFUL' or 'HARMFUL',unit,w,h,spacing,max,handed)
    end
    holder.sqHanded=handed or nil
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
-- The cell look, for the nameplate debuff row's settings (NameplateAuras.lua).
function UF:AuraCellLook() return cellRim,cellSwipe,countFont,desatAll,styleRev end
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
-- While aura data is secret a row hands over to the client's container
-- (syncRow) and reads nothing; it keeps its last count for the aura bars' lift.
function UF:RefreshAuraIcons(frame,dirtyOnly)
    local unit=frame.__unit
    frame.sqAuraDirty=nil
    -- A full redraw follows a settings edit or configure: filters are translated again.
    if not dirtyOnly and frame.AuraBars then frame.AuraBars.sqNativeGroups=nil end
    for _,key in ipairs(auraKeys) do
        local container=frame[key];local config=container and container.config
        if container and (not dirtyOnly or container.sqDirty) then
            container.sqDirty=nil
            if not dirtyOnly then container.sqNativeGroups=nil end
            local used=0
            local live=not self.auraTest and config and config.enable~=false and unit and frame:IsShown()
                and C_UnitAuras.GetAuraDataByIndex and true or false
            local handed=live and self:AurasSecret()
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
            elseif live and not handed then
                local filter=container.filter or (key=='Buffs' and 'HELPFUL' or 'HARMFUL')
                refused=false
                for index=1,255 do
                    local aura=auraAt(unit,filter,index)
                    if not aura then break end
                    local button=container[used+1]
                    if not button then button=newIcon(container,frame);container[used+1]=button end
                    if self:FilterAura(config,unit,aura,button) then
                        used=used+1;paintIcon(button,container,frame,unit,aura,key)
                    end
                end
                -- A read the client refused: its container takes the row over.
                if refused then handed=true;used=0 end
            end
            -- Settings reach the container on full redraws; an aura event out of
            -- combat changes nothing there once it exists and is idle.
            if live and (handed or container.sqHanded or not dirtyOnly or container.sqNative==nil) then
                syncRow(container,key,unit,handed)
            elseif not live and container.sqNative then self:SyncNativeAuras(container.sqNative) end
            container.sqHanded=handed or nil
            for index=used+1,#container do
                local spare=container[index]
                spare:Hide();spare.sqAura=nil;spare.sqPainted=nil
            end
            container.createdButtons=#container
            if not handed then container.visibleButtons=used end
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
    -- Secret aura data: the client's containers follow this event themselves.
    -- Nothing is read; a row still drawn here hands over on its redraw.
    if UF:AurasSecret() then
        local any=false
        for _,frame in ipairs(unitFrames) do
            for _,key in ipairs(auraKeys) do
                local row=frame[key]
                if row and row:IsShown() and not row.sqHanded then row.sqDirty=true;frame.sqAuraDirty=true;any=true end
            end
            local holder=frame.AuraBars
            if holder and holder:IsShown() and not holder.sqHanded then frame.sqBarsDirty=true;any=true end
        end
        if unit=='player' then
            for _,bar in ipairs(playerBars) do if bar.enabled and not bar.sqHanded then bar.sqDirty=true;any=true end end
        end
        if any then driver:Show() end
        return
    end
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
            local ok,aura=true,nil
            if C_UnitAuras.GetAuraDataByAuraInstanceID then ok,aura=pcall(C_UnitAuras.GetAuraDataByAuraInstanceID,unit,id) end
            -- Refused: aura data just turned secret, the redraw hands the rows over.
            if not ok then full=true;break end
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
-- At a combat or restriction edge every row, aura bar holder and player bar in
-- the other mode is redrawn once: it hands over or reads again.
UF:OnAuraSecrecyEdge(function(secret)
    local any=false
    for _,frame in ipairs(UF.objects) do
        for _,key in ipairs(auraKeys) do
            local row=frame[key]
            if row and row:IsShown() and (row.sqHanded or false)~=secret then row.sqDirty=true;frame.sqAuraDirty=true;any=true end
        end
        local holder=frame.AuraBars
        if holder and holder:IsShown() and (holder.sqHanded or false)~=secret then frame.sqBarsDirty=true;any=true end
    end
    for _,bar in ipairs(playerBars) do
        if bar.enabled and (bar.sqHanded or false)~=secret then bar.sqDirty=true;any=true end
    end
    if any then driver:Show() end
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
    -- Out of combat only: the client refuses addon cancels during combat (and
    -- while aura data is secret the client's container, which cancels itself,
    -- shows the bar). Weapon enchants are not cancelled here:
    -- CancelItemTempEnchantment is reserved for secure code.
    if InCombatLockdown() or UF:AurasSecret() or not button.auraInstanceID then return end
    for index=1,255 do
        local ok,aura=pcall(C_UnitAuras.GetAuraDataByIndex,'player',index,'HELPFUL')
        if not ok or not aura then return end
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
-- A player bar in the client's container: every buff or debuff in the bar's
-- order and cap, the weapon enchants on the buff bar, right-click cancel of a
-- buff (the client's secure cancel, as its own buff frame offers).
local function syncPlayerBar(bar,on)
    local native=UF:NativeAuras(bar)
    if not native then return end
    local config=bar.config
    local group=bar.sqNativeGroups and bar.sqNativeGroups[1]
    if not group then group={};bar.sqNativeGroups={group} end
    group.filter,group.sort,group.reverse=bar.filter,config.sortMethod=='NAME' and 'NAME' or nil,config.sortDirection=='DESCENDING'
    group.max=math.max(1,math.floor(bar.visibleLimit or 36))
    local spec=rowSpec(bar)
    if bar.key=='Buffs' then
        spec.cancel,spec.enchants='RightButtonUp',showEnchants and true or false
        -- Longest first: the enchants' long timers lead the bar.
        spec.enchantsFirst=group.reverse
    end
    UF:SyncNativeAuras(native,'player',spec,bar.sqNativeGroups,on)
end
-- `dirtyOnly` (the queued-event pass) redraws just the bars an event touched.
function UF:RefreshPlayerBars(dirtyOnly)
    if not self.db then return end
    for _,bar in ipairs(playerBars) do if not dirtyOnly or bar.sqDirty then
        bar.sqDirty=nil
        local used=0
        local live=bar.enabled and not self.auraTest and true or false
        local handed=live and self:AurasSecret()
        if not bar.enabled then -- hidden bar: nothing is read or drawn
        elseif self.auraTest then
            for index=1,self.auraTest do
                local button=playerIcon(bar,index)
                local aura={test=true,icon=testIcons[bar.key][(index-1)%#testIcons[bar.key]+1],duration=30+index*15,start=GetTime()-(30+index*15)*.4,
                    expirationTime=GetTime()+index*20,applications=index%3==0 and index or 1,name=bar.key..index}
                button.sqAura=aura;button.sqRank=0;button.sqEnchant=nil;used=index
                paintIcon(button,bar,bar,'player',aura,bar.key)
            end
        elseif not handed then
            refused=false
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
            -- A read the client refused: its container takes the bar over.
            if refused then handed=true;used=0 end
        end
        if live and (handed or bar.sqHanded or not dirtyOnly or bar.sqNative==nil) then syncPlayerBar(bar,handed)
        elseif not live and bar.sqNative then self:SyncNativeAuras(bar.sqNative) end
        bar.sqHanded=handed or nil
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
-- The weapon-enchant part of the buff bar. UNIT_INVENTORY_CHANGED also fires
-- for every arrow a Hunter fires, so only a real enchant change redraws, and
-- never in combat: there the player's auras can be secret, and reading them
-- from this tainted path failed on every shot (one error per shot, a
-- visible hitch). Combat's end redraws once if anything changed meanwhile.
local enchantSignature,enchantPending
local function enchantChanged()
    if not GetWeaponEnchantInfo then return true end
    local hasMain,_,_,mainID,hasOff,_,_,offID,hasRanged,_,_,rangedID=GetWeaponEnchantInfo()
    local signature=tostring(hasMain)..':'..tostring(mainID)..':'..tostring(hasOff)..':'..tostring(offID)
        ..':'..tostring(hasRanged)..':'..tostring(rangedID)
    if signature==enchantSignature then return false end
    enchantSignature=signature
    return true
end
playerEvents:SetScript('OnEvent',function(_,event,unit)
    if event=='UNIT_INVENTORY_CHANGED' or event=='WEAPON_ENCHANT_CHANGED' then
        if not showEnchants or (event=='UNIT_INVENTORY_CHANGED' and unit~='player') then return end
        if InCombatLockdown() then enchantPending=true
        elseif enchantChanged() then UF:RefreshPlayerBars() end
    elseif event~='PLAYER_REGEN_ENABLED' then settle()
    else
        if enchantPending then
            enchantPending=nil
            if enchantChanged() then UF:RefreshPlayerBars() end
        end
        -- Next frame: the unit frames finish their own post-combat start first.
        if playerPending then C_Timer.After(0,settle) end
    end
end)
