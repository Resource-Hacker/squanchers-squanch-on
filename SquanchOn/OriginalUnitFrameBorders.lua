-- SPDX-License-Identifier: MIT
-- Original material adapter for Squanch-On unit frames.
local _, ns = ...
local Borders = { attached = {}, installed = false, pending = false, records = {}, pendingFrames = {} }
ns.OriginalUnitFrameBorders = Borders
local records = Borders.records
local function mainline() return WOW_PROJECT_ID == WOW_PROJECT_MAINLINE or WOW_PROJECT_ID == WOW_PROJECT_CAMELOT end
local function unitDB(unit)
    local E = ns.UnitFrames and ns.UnitFrames.Engine
    return E and E.db and E.db.unitframe and E.db.unitframe.units[unit]
end
local function resolve(path)
    local object = _G
    for key in path:gmatch('[^.]+') do object = object and object[key] end
    return object
end
local function add(id, path, styles, strata, predicate)
    records[#records + 1] = { id = id, path = path, styles = styles or { 'unit' },
        strata = strata, predicate = predicate }
end

-- frameStrata1 means Inherited; frameStrata2 means BACKGROUND in original M33.
add('SquanchOnUF Player', 'SquanchOnUF_Player', { 'unit' })
add('SquanchOnUF Target', 'SquanchOnUF_Target', { 'unit' })
for _, name in ipairs({ 'TargetTarget', 'TargetTargetTarget', 'Pet', 'PetTarget' }) do
    add('SquanchOnUF ' .. name, 'SquanchOnUF_' .. name, nil, 'BACKGROUND')
end
for _, name in ipairs({ 'Focus', 'FocusTarget' }) do
    add('SquanchOnUF ' .. name, 'SquanchOnUF_' .. name, nil, 'BACKGROUND', mainline)
end
for index = 1, 5 do
    local stem = 'SquanchOnUF_PartyHeaderUnitButton' .. index
    add('SquanchOnUF Party' .. index, stem, nil, 'BACKGROUND')
    add('SquanchOnUF PartyTarget' .. index, stem .. 'Target', nil, 'BACKGROUND')
    add('SquanchOnUF PartyPet' .. index, stem .. 'Pet', nil, 'BACKGROUND')
    add('SquanchOnUF Boss' .. index, 'SquanchOnUF_Boss' .. index, nil, 'BACKGROUND', mainline)
    add('SquanchOnUF Arena' .. index, 'SquanchOnUF_Arena' .. index, nil, 'BACKGROUND', mainline)
end
add('SquanchOnUF Player.Power', 'SquanchOnUF_Player_PowerBar.backdrop', nil, 'BACKGROUND', function()
    local db = unitDB('player')
    return mainline() and db and db.power and db.power.enable and db.power.detachFromFrame
end)
add('SquanchOnUF Player.ClassPower', 'SquanchOnUF_Player.ClassBarHolder', nil, 'BACKGROUND', function()
    local db = unitDB('player')
    return resolve('SquanchOnUF_PlayerClassIconButton1') and db and db.classbar and db.classbar.enable and db.classbar.detachFromFrame
end)
add('SquanchOnUF Player.RunePower', 'SquanchOnUF_Player.ClassBarHolder', nil, 'BACKGROUND', function()
    local _, class = UnitClass('player')
    return class == 'DEATHKNIGHT' and resolve('SquanchOnUF_PlayerRuneButton1')
end)
add('SquanchOnUF Player.AdditionalPower', 'AdditionalPowerBar.backdrop', nil, 'BACKGROUND', function()
    local db = unitDB('player')
    return mainline() and db and db.classbar and db.classbar.enable and db.classbar.detachFromFrame
end)
-- Other native unit types are acquired at RefreshFrame below; compact group
-- cells keep a fitted inner rim so decoration never expands their native spacing.

local function refresh(record)
    if InCombatLockdown() then Borders.pending = true; return end
    local target = resolve(record.path)
    local enabled = target and (not record.predicate or record.predicate())
    if not enabled then
        for _, panel in ipairs(record.panels or {}) do panel:Hide() end
        return
    end
    if record.target == target and record.panels then
        for _, panel in ipairs(record.panels) do panel:Show() end
        if ns.UnitFrameLighting then ns.UnitFrameLighting:Attach(target,record.panels[1]) end
        return
    end
    -- A new child of a secure unit button can inherit protection. Defer its
    -- creation/anchors until combat ends; do not introduce a protected mutation.
    if record.target and record.target ~= target then
        for _, panel in ipairs(record.panels or {}) do panel:Hide() end
    end
    local panels = {}
    local alpha = ns.DarkSkin.borderAlpha -- the theme's current rim opacity
    for _, style in ipairs(record.styles) do
        local panel = ns.DarkSkin:Panel(target, style, 0)
        if record.strata then panel:SetFrameStrata(record.strata) end
        panel.baseAlpha = alpha
        panel:SetAlpha(InCombatLockdown() and 1 or alpha)
        panels[#panels + 1] = panel
    end
    record.target, record.panels = target, panels
    Borders.attached[record.id] = target
    if ns.UnitFrameLighting then ns.UnitFrameLighting:Attach(target,panels[1]) end
end

-- Recolor native neutral outlines with the shared icon gold. Keeping the native
-- edge geometry also preserves its alpha, state colors and exact icon dimensions.
local auraHooks = setmetatable({}, {__mode='k'})
local function public(value) return not (issecretvalue and issecretvalue(value)) end
local neutralTints=setmetatable({}, {__mode='k'})
local function tintNeutralEdge(texture,backdrop,ownerFrame,texturedOnly)
    if not texture or texture.IsForbidden and texture:IsForbidden() then return end
    if neutralTints[texture] then
        if ownerFrame then neutralTints[texture].ownerFrame=ownerFrame end
        if backdrop then neutralTints[texture].fitOuter() end
        return
    end
    local E=ns.UnitFrames and ns.UnitFrames.Engine
    local baseline=E and E.media and (backdrop and E.media.unitframeBorderColor or E.media.bordercolor)
    local setter=backdrop and 'SetBackdropBorderColor' or 'SetVertexColor'
    local getter=backdrop and 'GetBackdropBorderColor' or 'GetVertexColor'
    if not baseline or not texture[setter] or not texture[getter] or texture.forcedBorderColors then return end
    local record={ownerFrame=ownerFrame,texturedOnly=texturedOnly,edgeAlpha={}}
    neutralTints[texture]=record
    local function nativeEdges()
        -- Portraits carry the same single textured line as the bars; a flat
        -- edge left beneath it reads as a bright ring.
        if not (record.ownerFrame or record.texturedOnly) then return end
        for _,host in ipairs({texture,texture.iborder or false,texture.oborder or false}) do
            if host then
                for _,key in ipairs({'TopLeftCorner','TopRightCorner','BottomLeftCorner','BottomRightCorner','TopEdge','BottomEdge','LeftEdge','RightEdge'}) do
                    local edge=host[key]
                    if edge then
                        if record.edgeAlpha[edge]==nil then
                            local alpha=edge:GetAlpha()
                            if public(alpha) then record.edgeAlpha[edge]=alpha end
                        end
                        if record.edgeAlpha[edge]~=nil then edge:SetAlpha(record.neutral and 0 or record.edgeAlpha[edge]) end
                    end
                end
            end
        end
    end
    local function paintOuter()
        nativeEdges()
        if record.outer then record.outer:SetAlpha(record.neutral and not record.missingExclusion and (record.alpha or 1) or 0) end
    end
    local function occluded()
        local frame=record.ownerFrame
        local power=frame and frame.Power
        return frame and not frame.POWERBAR_DETACHED and frame.USE_POWERBAR and power and power:IsShown() and power.backdrop and power.backdrop:IsShown()
    end
    function record.visibility()
        if not record.outer then return end
        local active=occluded()
        record.missingExclusion=active and not record.hasExclusion
        ns.DarkSkin:SetUnitOutlineOccluded(record.outer,active and record.hasExclusion or false)
        paintOuter()
    end
    local function physical(frame)
        local l,b,w,h=frame:GetRect()
        local scale=frame:GetEffectiveScale()
        if l==nil or b==nil or w==nil or h==nil or scale==nil then return end
        for _,v in ipairs({l,b,w,h,scale}) do
            if not public(v) or type(v)~='number' or v~=v or v==math.huge or v==-math.huge then return end
        end
        if w<=0 or h<=0 or scale<=0 then return end
        return l*scale,b*scale,(l+w)*scale,(b+h)*scale
    end
    function record.fitOuter()
        if not backdrop then return end
        if InCombatLockdown() then
            if record.ownerFrame then Borders.pendingFrames[record.ownerFrame]=true end
            Borders.pending=true;record.visibility();return
        end
        if not record.outer then
            -- Texture only the original thin outline; no extra outside pixel,
            -- native fill mutation, icon resize or layout participation.
            record.outer=CreateFrame('Frame',nil,texture)
            record.outer:EnableMouse(false);record.outer.ignoreInLayout=true
        end
        record.outer:SetFrameLevel(texture:GetFrameLevel()+1)
        record.outer:SetAllPoints(texture)
        local exclusion
        local owner=record.ownerFrame
        local power=owner and owner.Power
        if power and power.backdrop and not owner.POWERBAR_DETACHED and owner.USE_POWERBAR then
            local l,b,r,t=physical(texture)
            local pl,pb,pr,pt=physical(power.backdrop)
            if l and pl then
                local scale=record.outer:GetEffectiveScale()
                exclusion={(pl-l)/scale,(pb-b)/scale,(pr-l)/scale,(pt-b)/scale}
            end
            for _,host in ipairs({power,power.backdrop}) do
                if not auraHooks[host] then
                    auraHooks[host]=true
                    local function changed()
                        if InCombatLockdown() then record.visibility(); Borders.pendingFrames[owner]=true;Borders.pending=true
                        else record.fitOuter() end
                    end
                    host:HookScript('OnShow',changed);host:HookScript('OnHide',changed)
                end
            end
        end
        record.hasExclusion=exclusion~=nil
        ns.DarkSkin:TexturedUnitOutline(record.outer,1/texture:GetEffectiveScale(),exclusion)
        record.visibility()
        paintOuter()
    end
    local function outerEdge(self,neutral,alpha)
        record.neutral,record.alpha=neutral,alpha
        if not record.outer then record.fitOuter() else paintOuter() end
    end
    local function tint(self,r,g,b,a)
        if record.busy then return end
        if not public(r) or not public(g) or not public(b) or not public(a) then outerEdge(self,false);return end
        if type(r)~='number' or type(g)~='number' or type(b)~='number' then return end
        local br,bg,bb=baseline.r or baseline[1],baseline.g or baseline[2],baseline.b or baseline[3]
        local nativeNeutral=math.abs(r-br)<=.001 and math.abs(g-bg)<=.001 and math.abs(b-bb)<=.001
        local color=ns.DarkSkin.innerBorderColor
        local retainedGold=record.neutral and math.abs(r-color[1])<.004 and math.abs(g-color[2])<.004 and math.abs(b-color[3])<.004
        if not nativeNeutral and not retainedGold then outerEdge(self,false);return end
        outerEdge(self,true,a)
        record.busy=true
        -- Recolor only the native neutral request. Dispel-type engine writes
        -- and nonneutral/secret semantic requests retain native ownership.
        self[setter](self,color[1],color[2],color[3],a or 1)
        record.busy=false
    end
    hooksecurefunc(texture,setter,tint)
    tint(texture,texture[getter](texture))
end
local function decorateAura(button)
    if not button or button.IsForbidden and button:IsForbidden() then return end
    if button.dispelBorder then
        local container=button.container
        if container and not container.isAuraBar and container.isUnitframe then
            tintNeutralEdge(button.border)
            tintNeutralEdge(button.dispelBorder)
        end
    elseif button.SetBackdropBorderColor then tintNeutralEdge(button,true)
    end
end
function Borders:RefreshIcons(frame)
    if not frame or frame.IsForbidden and frame:IsForbidden() then return end
    -- Keep the native thin bar outline and its semantic updates; only its
    -- neutral black color becomes the same gold line as the icon rims.
    tintNeutralEdge(frame.Health and frame.Health.backdrop,true,frame)
    tintNeutralEdge(frame.Power and frame.Power.backdrop,true)
    tintNeutralEdge(frame.Castbar and frame.Castbar.backdrop,true)
    local portrait = frame.Portrait
    tintNeutralEdge(portrait and portrait.backdrop,true,nil,true)
    local portrait3D = frame.Portrait3D
    tintNeutralEdge(portrait3D and portrait3D.backdrop,true,nil,true)
    local cast = frame.Castbar
    tintNeutralEdge(cast and cast.ButtonIcon and cast.ButtonIcon.bg,true)
    local spec = frame.PVPSpecIcon
    tintNeutralEdge(spec and spec.bg,true)
    for _, key in ipairs({'Auras','Buffs','Debuffs'}) do
        local container=frame[key]
        if container and not (container.IsForbidden and container:IsForbidden()) then
            if container.PostCreateButton and not auraHooks[container] then
                auraHooks[container]=true
                hooksecurefunc(container,'PostCreateButton',function(_,button) decorateAura(button) end)
            end
            local count=0
            for _,button in ipairs(container) do
                count=count+1; if count>128 then break end
                decorateAura(button)
            end
            for button in pairs(container.buttons or {}) do
                count=count+1; if count>256 then break end
                decorateAura(button)
            end
        end
    end
end

function Borders:RefreshFrame(frame)
    if not frame or not frame.GetName then return end
    self:RefreshIcons(frame)
    local name = frame:GetName()
    if not name then return end
    local lighting=ns.UnitFrameLighting
    local eligible=lighting and lighting:IsUnitFrame(frame)
    if eligible and InCombatLockdown() then
        self.pendingFrames[frame]=true; self.pending=true; return
    end
    for _, record in ipairs(records) do
        -- Parent names include subregions like Castbar/ClassBarHolder, which
        -- already exist when the engine's post-style initialization callback runs.
        if record.path == name or record.path:sub(1, #name + 1) == name .. '.'
            or name == 'SquanchOnUF_Player' and record.id:match('^SquanchOnUF Player%.') then refresh(record) end
    end
    if eligible then
        local existing=ns.DarkSkin.byFrame[frame]
        local panel=existing and (existing.unit or existing.inner)
        -- Raid/assist/tank cells have no historical outer rim. Use the same
        -- material fitted inside those cells instead of overlapping neighbors.
        panel=panel or ns.DarkSkin:Panel(frame,'inner',0)
        lighting:Attach(frame,panel)
        self.pendingFrames[frame]=nil
    end
end
function Borders:RefreshAll()
    self.pending = false
    for _, record in ipairs(records) do refresh(record) end
    local E=ns.UnitFrames and ns.UnitFrames.Engine
    for _,frame in ipairs(E and E.oUF and E.oUF.objects or {}) do self:RefreshFrame(frame) end
    for frame in pairs(self.pendingFrames) do self:RefreshFrame(frame) end
end
function Borders:Install()
    if self.installed and self.configureHooked then return end
    local E = ns.UnitFrames and ns.UnitFrames.Engine
    local engine = E and E.oUF
    if not engine or not engine.RegisterInitCallback or not ns.DarkSkin then return end
    if not self.installed then
        engine:RegisterInitCallback(function(frame) self:RefreshFrame(frame) end)
        self.installed = true
    end
    local UF = E:GetModule('UnitFrames', true)
    if UF and UF.ConfigureFrame and not self.configureHooked then
        hooksecurefunc(UF, 'ConfigureFrame', function(_, frame) self:RefreshFrame(frame) end)
        self.configureHooked = true
    end
    if UF and UF.Configure_Power and not self.powerHooked then
        hooksecurefunc(UF,'Configure_Power',function(_,frame) self:RefreshFrame(frame) end)
        self.powerHooked=true
    end
    if UF and UF.AuraCreated and not self.modernIconHooked then
        self.modernIconHooked=true
        hooksecurefunc(UF,'AuraCreated',function(_,button) decorateAura(button) end)
    end
    for _, frame in ipairs(engine.objects or {}) do self:RefreshFrame(frame) end
    self:RefreshAll()
end

local events = CreateFrame('Frame')
events:RegisterEvent('ADDON_LOADED')
events:RegisterEvent('PLAYER_LOGIN')
events:RegisterEvent('PLAYER_REGEN_ENABLED')
events:SetScript('OnEvent', function(_, event, addon)
    if event == 'ADDON_LOADED' then
        if addon == 'SquanchOn' then Borders:Install() end
    elseif event == 'PLAYER_LOGIN' then Borders:Install(); if Borders.installed then Borders:RefreshAll() end
    elseif Borders.installed and event == 'PLAYER_REGEN_ENABLED' then Borders:RefreshAll()
    end
end)
Borders:Install()
