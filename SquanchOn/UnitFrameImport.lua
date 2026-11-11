-- SPDX-License-Identifier: MIT
-- Squanch-On: original configuration adapter. No upstream UI implementation.
-- Optional private input: ns.db.unitFrameImport={unitframe=...,movers=...}.
-- The installer supplies resolved values; account identities never ship here.
local _, ns = ...
local Import = {}
ns.UnitFrameImport = Import

local units = {'player','target','pet','targettarget','pettarget','targettargettarget',
    'focus','focustarget','party','raid1','raid2','raid3','raidpet','tank','assist','boss','arena'}
Import.units = units
Import.moverNames = {
    player='ElvUF_PlayerMover',target='ElvUF_TargetMover',pet='ElvUF_PetMover',
    targettarget='ElvUF_TargetTargetMover',pettarget='ElvUF_PetTargetMover',
    targettargettarget='ElvUF_TargetTargetTargetMover',focus='ElvUF_FocusMover',
    focustarget='ElvUF_FocusTargetMover',party='ElvUF_PartyMover',raid1='ElvUF_Raid1Mover',
    raid2='ElvUF_Raid2Mover',raid3='ElvUF_Raid3Mover',raidpet='ElvUF_RaidpetMover',
    tank='ElvUF_TankMover',assist='ElvUF_AssistMover',boss='BossHeaderMover',arena='ArenaHeaderMover',
}

function Import:Copy(value, depth)
    depth = depth or 0
    if type(value) ~= 'table' then return value end
    if depth > 12 then return nil end
    local copy = {}
    for key, child in pairs(value) do
        if type(key) == 'string' or type(key) == 'number' then
            local kind = type(child)
            if kind == 'table' or kind == 'number' or kind == 'string' or kind == 'boolean' then
                copy[key] = self:Copy(child, depth + 1)
            end
        end
    end
    return copy
end

local function number(value, fallback, low, high)
    if type(value) ~= 'number' or value ~= value or value == math.huge or value == -math.huge then return fallback end
    return math.max(low, math.min(high, value))
end
Import.Number = number

-- Import IDs only. Labels, translations and upstream implementation are omitted.
function Import:RangePreferences(source)
    local result={}
    for _,kind in ipairs({'ENEMY','FRIENDLY','RESURRECT','PET'}) do
        result[kind]={}
        for class,settings in pairs(type(source)=='table' and source[kind] or {}) do
            if type(class)=='string' and class:match('^[A-Z]+$') and type(settings)=='table' then
                local ids,seen={},{}
                local function add(value)
                    local id=tonumber(value)
                    if id and id>0 and id<10000000 and id==math.floor(id) and not seen[id] and #ids<64 then
                        seen[id]=true;ids[#ids+1]=id
                    end
                end
                local count=#settings
                for _,id in ipairs(settings) do add(id) end
                local remaining={}
                for id,value in pairs(settings) do
                    if not (type(id)=='number' and id>=1 and id<=count) and value~=false then
                        local numeric=tonumber(id)
                        if numeric then remaining[#remaining+1]=numeric end
                    end
                end
                table.sort(remaining)
                for _,id in ipairs(remaining) do add(id) end
                result[kind][class]=ids
            end
        end
    end
    return result
end

function Import:DefaultUnit(unit)
    local small = unit == 'pet' or unit == 'targettarget' or unit == 'pettarget'
    local group = unit == 'party' or unit:match('^raid') or unit == 'tank' or unit == 'assist'
    local enabled = not (unit == 'targettargettarget' or unit == 'focustarget' or unit == 'raidpet' or unit == 'tank' or unit == 'arena')
    return {
        enable=enabled,width=group and 100 or small and 100 or 205,height=group and 32 or small and 34 or 48,
        orientation=unit == 'target' and 'RIGHT' or 'LEFT',
        portrait={enable=not group and unit ~= 'focus',style=small and 'Class' or '3D',width=small and 25 or 45,
            overlay=false,paused=true,camDistanceScale=1.2,rotation=unit == 'target' and 336 or 0,xOffset=0,yOffset=0},
        power={enable=true,height=small and 7 or 15,position='BOTTOM',xOffset=0,yOffset=0,
            detachFromFrame=false,detachedWidth=200,width='fill',text_format=small and '' or '[power:current]'},
        name={position='CENTER',attachTextTo=unit == 'targettarget' and 'Health' or 'Frame',xOffset=0,
            yOffset=small and 0 or 7,text_format='[name]'},
        health={position=unit == 'target' and 'LEFT' or 'RIGHT',attachTextTo='Health',xOffset=unit == 'target' and 4 or -4,
            yOffset=0,reverseFill=unit == 'target',text_format=small and '' or '[health:current]'},
        castbar={enable=not small,width=205,height=18,overlayOnFrame='Power',icon=true,latency=unit == 'player',
            hideName=false,hideTime=false,reverse=false,timeToHold=0},
        classbar={enable=unit == 'player',height=10,spacing=3,detachFromFrame=false,detachedWidth=205},
        fader={enable=unit ~= 'player',range=true,minAlpha=0.35,maxAlpha=1},
        buffs={enable=not group,perrow=8,numrows=1,spacing=2,sizeOverride=20,anchorPoint='TOPLEFT',
            growthX='RIGHT',growthY='UP',xOffset=0,yOffset=5,countFontSize=8},
        debuffs={enable=not group,perrow=8,numrows=1,spacing=2,sizeOverride=20,anchorPoint='BOTTOMLEFT',
            growthX='RIGHT',growthY='DOWN',xOffset=0,yOffset=-5,countFontSize=8},
        customTexts={},infoPanel={enable=false,height=0},horizontalSpacing=3,verticalSpacing=3,
        groupSpacing=0,groupsPerRowCol=1,growthDirection='DOWN',showPlayer=true,
    }
end

function Import:Defaults()
    local profile={units={},movers={},font='PT Sans Narrow',fontSize=11,fontOutline='OUTLINE',
        statusbar='Interface\\Buttons\\WHITE8X8',targetOnMouseDown=true,colors={health={r=.1,g=.1,b=.1,a=1}},
        healthPrediction=true,showRaidTarget=true,showReadyCheck=true}
    for _,unit in ipairs(units) do profile.units[unit]=self:DefaultUnit(unit) end
    return profile
end

local sections={'portrait','power','name','health','castbar','classbar','fader','buffs','debuffs','infoPanel',
    'targetsGroup','petsGroup','healPrediction','raidRoleIcons','roleIcon','resurrectIcon','readycheckIcon'}
local scalars={'enable','width','height','orientation','horizontalSpacing','verticalSpacing','groupSpacing',
    'groupsPerRowCol','growthDirection','showPlayer','visibility','groupBy','groupingOrder','sortMethod','sortDir',
    'raidWideSorting','numGroups','spacing','raidRoleIcons','rdebuffs'}

function Import:Normalize(source)
    source=type(source)=='table' and source or {}
    local raw=source.unitframe or source
    local profile=self:Defaults()
    for _,key in ipairs({'font','fontSize','fontOutline','statusbar','targetOnMouseDown'}) do
        if type(raw[key])==type(profile[key]) then profile[key]=raw[key] end
    end
    if type(raw.colors)=='table' then profile.colors=self:Copy(raw.colors) end
    local global=source.global and source.global.unitframe
    profile.auraFilters=global and self:Copy(global.aurafilters) or {}
    profile.rangeCheck=self:RangePreferences(global and global.rangeCheck)
    profile.rangeCheckImported=global and type(global.rangeCheck)=='table' or false
    for _,unit in ipairs(units) do
        local input=raw.units and raw.units[unit]
        local output=profile.units[unit]
        if type(input)=='table' then
            for _,key in ipairs(scalars) do
                if type(input[key])=='number' or type(input[key])=='boolean' or type(input[key])=='string' then output[key]=input[key] end
            end
            for _,key in ipairs(sections) do
                if type(input[key])=='table' then
                    output[key]=output[key] or {}
                    for setting,value in pairs(input[key]) do
                        if type(value)=='string' or type(value)=='number' or type(value)=='boolean' then output[key][setting]=value end
                    end
                end
            end
            if type(input.customTexts)=='table' then output.customTexts=self:Copy(input.customTexts) end
        end
        output.width=number(output.width,100,15,1000)
        output.height=number(output.height,34,5,500)
        output.power.height=number(output.power.height,10,1,300)
        output.portrait.width=number(output.portrait.width,30,1,300)
        output.fader.minAlpha=number(output.fader.minAlpha,.35,0,1)
        output.fader.maxAlpha=number(output.fader.maxAlpha,1,0,1)
    end
    -- Legacy anchor tokens are configuration data only; no globals are aliased.
    for unit,oldName in pairs(self.moverNames) do
        local value=source.movers and source.movers[oldName]
        if type(value)=='string' then profile.movers[unit]=value:gsub('ElvUIParent','UIParent') end
        local castName='ElvUF_'..unit:gsub('^%l',string.upper)..'CastbarMover'
        value=source.movers and source.movers[castName]
        if type(value)=='string' then profile.movers['cast_'..unit]=value:gsub('ElvUIParent','UIParent') end
    end
    profile.fontSize=number(profile.fontSize,11,5,40)
    return profile
end

function Import:Initialize()
    if not ns.db then return nil,'Saved variables are not initialized' end
    local state=ns.db.unitFrames
    if type(state)~='table' then state={version=1,profile='Default',profiles={}};ns.db.unitFrames=state end
    state.profiles=state.profiles or {};state.profile=state.profile or 'Default'
    if not state.imported and type(ns.db.unitFrameImport)=='table' then
        state.profiles[state.profile]=self:Normalize(ns.db.unitFrameImport)
        state.imported=true
    end
    if not state.profiles[state.profile] then state.profiles[state.profile]=self:Defaults() end
    local profile=state.profiles[state.profile]
    local input=ns.db.unitFrameImport
    local global=input and input.global and input.global.unitframe
    if not profile.rangeCheckImported and global and type(global.rangeCheck)=='table' then
        profile.rangeCheck=self:RangePreferences(global.rangeCheck);profile.rangeCheckImported=true
    end
    return state.profiles[state.profile],state
end
