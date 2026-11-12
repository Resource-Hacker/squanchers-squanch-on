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
        power={enable=unit~='assist' and unit~='tank' and unit~='pettarget' and unit~='raid3',height=small and 7 or 15,position='BOTTOM',xOffset=0,yOffset=0,
            detachFromFrame=false,detachedWidth=200,width='fill',text_format=small and '' or '[power:current]'},
        name={position='CENTER',attachTextTo=unit == 'targettarget' and 'Health' or 'Frame',xOffset=0,
            yOffset=small and 0 or 7,text_format='[name]'},
        health={position=unit == 'target' and 'LEFT' or 'RIGHT',attachTextTo='Health',xOffset=unit == 'target' and 4 or -4,
            yOffset=0,reverseFill=unit == 'target',text_format=small and '' or '[health:current]'},
        castbar={enable=unit=='player' or unit=='target' or unit=='focus' or unit=='party' or unit=='boss' or unit=='arena',width=205,height=18,overlayOnFrame='Power',icon=true,latency=unit == 'player',
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
        general={},benikui={},statusbar='Interface\\Buttons\\WHITE8X8',targetOnMouseDown=true,colors={health={r=.1,g=.1,b=.1,a=1}},
        healthPrediction=true,showRaidTarget=true,showReadyCheck=true}
    for _,unit in ipairs(units) do profile.units[unit]=self:DefaultUnit(unit) end
    return profile
end

-- Version 2 preserves the complete resolved profile, including nested filters,
-- colors, cutaway, indicators and per-element strata. Configuration is data;
-- support is reported by the renderer rather than erased during import.
local function merge(base, source)
    for key,value in pairs(source or {}) do
        if type(value)=='table' then
            if type(base[key])~='table' then base[key]={} end
            merge(base[key],value)
        elseif type(value)=='string' or type(value)=='number' or type(value)=='boolean' then
            base[key]=value
        end
    end
    return base
end
function Import:Normalize(source)
    source=type(source)=='table' and source or {}
    local raw=source.unitframe or source
    local profile=merge(self:Defaults(),self:Copy(raw))
    profile.units=profile.units or {}
    for _,unit in ipairs(units) do
        profile.units[unit]=merge(self:DefaultUnit(unit),profile.units[unit])
        local c=profile.units[unit]
        c.width=number(c.width,100,1,1000);c.height=number(c.height,34,1,500)
    end
    profile.general=self:Copy(source.general or {})
    profile.benikui=self:Copy(source.benikui or {})
    profile.private=self:Copy(source.private or {})
    profile.filters=self:Copy(source.filters or {})
    local global=source.global and source.global.unitframe or {}
    profile.auraFilters=self:Copy(global.aurafilters or (source.filters or {}).aurafilters or raw.filters or {})
    profile.rangeCheck=self:RangePreferences(global.rangeCheck or (source.filters or {}).rangeCheck or source.rangeCheck)
    profile.rangeCheckImported=type(global.rangeCheck or (source.filters or {}).rangeCheck or source.rangeCheck)=='table'
    profile.sourceMovers=merge(self:Copy(source.defaultMovers or {}),source.movers or {})
    profile.movers={}
    for unit,oldName in pairs(self.moverNames) do
        local value=profile.sourceMovers[oldName]
        if type(value)=='string' then profile.movers[unit]=value end
        local castName=oldName:gsub('Mover$','CastbarMover')
        value=profile.sourceMovers[castName]
        if type(value)=='string' then profile.movers['cast_'..unit]=value end
    end
    profile.modernLegacyTagsInactive=source.modern~=false
    profile.importVersion=2
    return profile
end

-- The unit-frame settings are one table inside the active addon profile
-- (ns.db.unitFrames). The second result keeps the fields callers read from
-- the old inner-profile state: `profile` (the addon profile's name), `profiles`
-- (that one table) and the per-account import receipts.
function Import:Initialize()
    if not ns.db then return nil,'Saved variables are not initialized' end
    local receipts=ns.Profiles:Receipts('unitFrameReceipts')
    local name,profile=ns.Profiles:Current(),rawget(ns.db,'unitFrames')
    if type(ns.db.unitFrameImport)=='table' and receipts.importVersion~=2 then
        -- Keep the rejected schema intact as rollback, then consume the fresh
        -- complete private import exactly once. Later option edits are retained.
        if receipts.imported and type(profile)=='table' then receipts.preVersion2Profiles={[name]=self:Copy(profile)} end
        profile=self:Normalize(ns.db.unitFrameImport)
        receipts.imported=true;receipts.importVersion=2;receipts.version=2
    end
    if type(profile)~='table' then profile=self:Defaults() end
    ns.db.unitFrames=profile
    local state=setmetatable({profile=name,profiles={[name]=profile}},
        {__index=receipts,__newindex=function(_,key,value) receipts[key]=value end})
    return profile,state
end
