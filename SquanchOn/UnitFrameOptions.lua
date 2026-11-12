-- SPDX-License-Identifier: MIT
-- Original settings UI. Controls are limited by the renderer's capabilities;
-- unknown imported fields remain intact, including arbitrary custom-text keys.
local _,ns=...
local Options={}
ns.UnitFrameOptions=Options
local points={'CENTER','LEFT','RIGHT','TOP','BOTTOM','TOPLEFT','TOPRIGHT','BOTTOMLEFT','BOTTOMRIGHT'}
local regions={'Frame','Health','Power','InfoPanel'}
local outlines={'NONE','OUTLINE','THICKOUTLINE','MONOCHROMEOUTLINE','SHADOW','SHADOWOUTLINE'}
local fields={
    {'Frame enabled','enable','boolean'},
    {'Frame width','width','number',5,1500},{'Frame height','height','number',1,1000},
    {'Frame orientation','orientation','choice',{'LEFT','MIDDLE','RIGHT'}},
    {'Portrait enabled','portrait.enable','boolean'},
    {'Portrait style','portrait.style','choice',{'3D','2D','Class'}},
    {'Portrait width','portrait.width','number',1,500},
    {'Portrait rotation','portrait.rotation','number',0,360},
    {'Portrait camera distance','portrait.camDistanceScale','number',.01,20},
    {'Portrait model horizontal offset','portrait.xOffset','number',-20,20},
    {'Portrait model vertical offset','portrait.yOffset','number',-20,20},
    {'Portrait overlays health','portrait.overlay','boolean'},
    {'Portrait paused','portrait.paused','boolean'},
    {'Reverse health fill','health.reverseFill','boolean'},
    {'Power bar enabled','power.enable','boolean'},
    {'Power bar height','power.height','number',1,300},
    {'Power bar width mode','power.width','choice',{'fill','spaced','inset','offset'}},
    {'Power bar layout offset','power.offset','number',0,500},
    {'Reverse power fill','power.reverseFill','boolean'},
    {'Detach power bar','power.detachFromFrame','boolean'},
    {'Detached power width','power.detachedWidth','number',3,1500},
    {'Cast bar enabled','castbar.enable','boolean'},
    {'Cast width (when not overlaid)','castbar.width','number',5,1500},
    {'Cast height (when not overlaid)','castbar.height','number',1,300},
    {'Cast overlays region','castbar.overlayOnFrame','choice',{'None','Power','Health'}},
    {'Cast icon','castbar.icon','boolean'},
    {'Cast latency indicator','castbar.latency','boolean'},
    {'Hide cast name','castbar.hideName','boolean'},
    {'Hide cast time','castbar.hideTime','boolean'},
    {'Class resources enabled','classbar.enable','boolean'},
    {'Class resource height','classbar.height','number',1,300},
    {'Class resource spacing','classbar.spacing','number',0,50},
    {'Fade enabled','fader.enable','boolean'},
    {'Fade out-of-range units','fader.range','boolean'},
    {'Fade minimum alpha','fader.minAlpha','number',0,1},
    {'Fade maximum alpha','fader.maxAlpha','number',0,1},
    {'Fade transition duration','fader.smooth','number',0,10},
    {'Fade delay','fader.delay','number',0,30},
    {'Reveal in combat','fader.combat','boolean'},
    {'Reveal with player target','fader.playertarget','boolean'},
    {'Reveal with unit target','fader.unittarget','boolean'},
    {'Reveal on hover','fader.hover','boolean'},
    {'Reveal while casting','fader.casting','boolean'},
    {'Reveal while health is reduced','fader.health','boolean'},
    {'Reveal while power is reduced','fader.power','boolean'},
    {'Reveal when focused','fader.focus','boolean'},
    {'Reveal in vehicle','fader.vehicle','boolean'},
    {'Group horizontal spacing','horizontalSpacing','number',0,200},
    {'Group vertical spacing','verticalSpacing','number',0,200},
    {'Spacing between groups','groupSpacing','number',0,200},
    {'Groups per row or column','groupsPerRowCol','number',1,8},
    {'Number of groups','numGroups','number',1,8},
    {'Group growth','growthDirection','choice',{'DOWN','UP','LEFT','RIGHT','RIGHT_DOWN','RIGHT_UP','LEFT_DOWN','LEFT_UP'}},
    {'Group visibility condition','visibility','string'},
    {'Group by','groupBy','choice',{'GROUP','CLASS','ROLE','ASSIGNEDROLE'}},
    {'Group sort method','sortMethod','choice',{'INDEX','NAME'}},
    {'Group sort direction','sortDir','choice',{'ASC','DESC'}},
}
for _,kind in ipairs({'name','health','power'}) do
    local title=kind:sub(1,1):upper()..kind:sub(2)..' text'
    for _,spec in ipairs({{'tag expression','text_format','string'}, {'font (blank: inherit)','font','string'},
        {'size (blank: inherit)','size','number',5,80},{'outline','fontOutline','choice',outlines},
        {'anchor region','attachTextTo','choice',regions},{'anchor point','position','choice',points},
        {'horizontal offset','xOffset','number',-1000,1000},{'vertical offset','yOffset','number',-1000,1000}}) do
        fields[#fields+1]={title..' '..spec[1],kind..'.'..spec[2],spec[3],spec[4],spec[5]}
    end
end
for _,kind in ipairs({'buffs','debuffs'}) do
    for _,spec in ipairs({{'enabled','enable','boolean'},{'per row','perrow','number',1,40},
        {'rows','numrows','number',1,8},{'icon size (0: fit)','sizeOverride','number',0,150}}) do
        fields[#fields+1]={kind..' '..spec[1],kind..'.'..spec[2],spec[3],spec[4],spec[5]}
    end
end
local conservative={enable=true,width=true,height=true,orientation=true,
    ['portrait.enable']=true,['portrait.style']=true,['portrait.width']=true,
    ['power.enable']=true,['power.height']=true,['health.reverseFill']=true,
    ['name.text_format']=true,['name.xOffset']=true,['name.yOffset']=true}
local function keys(path)
    if type(path)=='table' then return path end
    local result={};for key in path:gmatch('[^.]+') do result[#result+1]=key end;return result
end
local function pathValue(object,path,value,write)
    local pathKeys=keys(path);local current=object
    for index=1,#pathKeys-1 do
        if type(current[pathKeys[index]])~='table' then
            if not write then return end
            current[pathKeys[index]]={}
        end
        current=current[pathKeys[index]]
    end
    if write then current[pathKeys[#pathKeys]]=value else return current[pathKeys[#pathKeys]] end
end
local function supported(path)
    local capabilities=ns.UnitFrames.optionCapabilities or conservative
    if type(path)=='table' then return capabilities['customTexts.*']==true or capabilities['customTexts.'..path[3]]==true end
    return capabilities[path]==true
end
local function label(parent,text,x,y)
    local fs=parent:CreateFontString(nil,'OVERLAY','GameFontNormal')
    fs:SetPoint('TOPLEFT',x,y);fs:SetText(text);return fs
end
local function button(parent,text,width,callback)
    local control=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate')
    control:SetSize(width,24);control:SetText(text);control:SetScript('OnClick',callback);return control
end
local function edit(parent,width)
    local control=CreateFrame('EditBox',nil,parent,'InputBoxTemplate')
    control:SetSize(width,22);control:SetAutoFocus(false)
    control:SetScript('OnEscapePressed',function(self) self:ClearFocus() end)
    return control
end
function Options:Message(text) if self.message then self.message:SetText(text or '') end end
function Options:FieldsForUnit()
    local result={}
    for _,field in ipairs(fields) do if supported(field[2]) then result[#result+1]=field end end
    local customKeys={}
    for name in pairs(self.working.customTexts or {}) do customKeys[#customKeys+1]=name end
    table.sort(customKeys,function(a,b) return tostring(a)<tostring(b) end)
    for _,name in ipairs(customKeys) do
        local config=self.working.customTexts[name]
        if type(config)=='table' then
            for _,spec in ipairs({{'enabled','enable','boolean'},{'tag expression','text_format','string'},
                {'font','font','string'},{'size','size','number',5,100},
                {'outline','fontOutline','choice',outlines},{'anchor region','attachTextTo','choice',regions},
                {'anchor point','justifyH','choice',{'CENTER','LEFT','RIGHT'}},
                {'horizontal offset','xOffset','number',-1000,1000},{'vertical offset','yOffset','number',-1000,1000}}) do
                local path={'customTexts',name,spec[2]}
                if supported(path) then result[#result+1]={tostring(name)..': '..spec[1],path,spec[3],spec[4],spec[5]} end
            end
        end
    end
    return result
end
function Options:DrawRows()
    for _,row in ipairs(self.rows or {}) do row.control:Hide();row.label:Hide();row.field=nil end
    self.rows=self.rows or {}
    local available=self:FieldsForUnit()
    for index,field in ipairs(available) do
        local row=self.rows[index] or {};self.rows[index]=row
        if row.kind~=field[3] then
            if row.control then row.control:Hide() end
            row.kind=field[3]
            if field[3]=='boolean' then
                row.control=CreateFrame('CheckButton',nil,self.body,'UICheckButtonTemplate');row.control:SetSize(25,25)
            elseif field[3]=='choice' then
                row.control=button(self.body,'',235,function(control)
                    local choices=row.field and row.field[4];if not choices then return end
                    local selected=0
                    for i,value in ipairs(choices) do if value==control:GetText() then selected=i;break end end
                    control:SetText(choices[selected%#choices+1])
                end)
            else row.control=edit(self.body,field[3]=='string' and 270 or 115) end
        end
        row.field=field
        row.label=row.label or label(self.body,'',0,0)
        row.label:ClearAllPoints();row.label:SetPoint('TOPLEFT',0,-(index-1)*30-5)
        row.label:SetWidth(335);row.label:SetJustifyH('LEFT');row.label:SetText(field[1]);row.label:Show()
        row.control:ClearAllPoints();row.control:SetPoint('TOPLEFT',350,-(index-1)*30);row.control:Show()
        local value=pathValue(self.working,field[2])
        row.original=value
        if field[3]=='boolean' then row.control:SetChecked(value==true)
        else row.control:SetText(value==nil and '' or tostring(value)) end
    end
    self.body:SetHeight(math.max(1,#available*30))
end
function Options:LoadUnit()
    local UF=ns.UnitFrames
    if not UF or not UF.db then return end
    local unit=ns.UnitFrameImport.units[self.unitIndex or 1]
    self.unitKey=unit;self.unitButton:SetText('Unit: '..unit..' (next)')
    self.working=ns.UnitFrameImport:Copy(UF.db.units[unit] or {})
    self.profileName:SetText(UF.state.profile)
    self:DrawRows();self:Message('')
end
function Options:Commit(copy,unit,profile)
    local UF=ns.UnitFrames
    if UF.state.profile~=profile then self:Message('Profile changed; reopen these edits before applying.');return end
    UF.db.units[unit]=copy
    local ok,reason=UF:Update_AllFrames()
    self:Message(ok and 'Settings applied.' or reason or 'Settings saved; renderer update pending.')
end
function Options:Apply()
    local UF=ns.UnitFrames;local copy=ns.UnitFrameImport:Copy(self.working)
    for _,row in ipairs(self.rows) do
        if row.field then
            local field,control=row.field,row.control;local value
            if field[3]=='boolean' then value=control:GetChecked()==true
            elseif field[3]=='number' then
                local text=control:GetText()
                if text~='' then
                    value=tonumber(text)
                    if not value or value~=value or value<field[4] or value>field[5] then
                        self:Message(field[1]..' must be between '..field[4]..' and '..field[5]..'.');return
                    end
                end
            else
                value=control:GetText()
                if field[3]=='choice' and value=='' and row.original==nil then value=nil end
                if value=='' and row.original==nil and tostring(keys(field[2])[#keys(field[2])])=='font' then value=nil end
            end
            -- An absent inherited field stays absent when its control was not edited.
            if not (row.original==nil and field[3]=='boolean' and value==false) then pathValue(copy,field[2],value,true) end
        end
    end
    if copy.fader and copy.fader.minAlpha and copy.fader.maxAlpha and copy.fader.minAlpha>copy.fader.maxAlpha then
        self:Message('Fade minimum alpha must not exceed maximum alpha.');return
    end
    if InCombatLockdown() then
        self.pending={kind='apply',config=copy,unit=self.unitKey,profile=UF.state.profile}
        self:Message('Validated settings queued until combat ends.');return
    end
    self:Commit(copy,self.unitKey,UF.state.profile)
end
function Options:SelectProfile(name,create)
    local UF=ns.UnitFrames
    name=(name or ''):match('^%s*(.-)%s*$')
    if name=='' or #name>80 then self:Message('Enter a profile name (1–80 characters).');return end
    if InCombatLockdown() then self.pending={kind='profile',name=name,create=create};self:Message('Profile change queued until combat ends.');return end
    if create then
        if UF.state.profiles[name] then self:Message('That profile already exists.');return end
        UF.state.profiles[name]=ns.UnitFrameImport:Copy(UF.db)
    elseif not UF.state.profiles[name] then self:Message('Profile not found.');return end
    UF.state.profile=name
    UF:Update_AllFrames();self:LoadUnit();self:Message('Selected profile: '..name)
end
function Options:Build()
    if self.frame then return self.frame end
    local frame=CreateFrame('Frame','SquanchOnUFOptions',UIParent,'BackdropTemplate')
    frame:SetSize(760,680);frame:SetPoint('CENTER');frame:SetFrameStrata('DIALOG')
    frame:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1})
    frame:SetBackdropColor(.055,.055,.055,.96);frame:SetBackdropBorderColor(.7,.532,.294,1)
    frame:EnableMouse(true);frame:SetMovable(true);frame:RegisterForDrag('LeftButton')
    frame:SetScript('OnDragStart',frame.StartMoving);frame:SetScript('OnDragStop',frame.StopMovingOrSizing)
    label(frame,'Squanch-On · Implemented unit-frame settings',20,-18)
    local close=CreateFrame('Button',nil,frame,'UIPanelCloseButton');close:SetPoint('TOPRIGHT',-2,-2)
    label(frame,'Profile',20,-55)
    self.profileName=edit(frame,190);self.profileName:SetPoint('TOPLEFT',90,-50)
    local select=button(frame,'Select',75,function() self:SelectProfile(self.profileName:GetText(),false) end)
    select:SetPoint('LEFT',self.profileName,'RIGHT',12,0)
    local clone=button(frame,'Copy to new',105,function() self:SelectProfile(self.profileName:GetText(),true) end)
    clone:SetPoint('LEFT',select,'RIGHT',8,0)
    self.unitButton=button(frame,'Unit: player (next)',200,function()
        self.unitIndex=(self.unitIndex or 1)%#ns.UnitFrameImport.units+1;self:LoadUnit()
    end);self.unitButton:SetPoint('TOPLEFT',20,-86)
    local layout=button(frame,'Move & resize',150,function()
        frame:Hide();if ns.LayoutEditor then ns.LayoutEditor:Open() end
    end);layout:SetPoint('LEFT',self.unitButton,'RIGHT',12,0)
    local note=label(frame,'Only implemented controls are shown. Imported unsupported settings are preserved.\nSpecialized aura filters, all-class resources and full ElvUI options are not reproduced.',20,-119)
    note:SetWidth(710);note:SetJustifyH('LEFT')
    local scroll=CreateFrame('ScrollFrame',nil,frame,'UIPanelScrollFrameTemplate')
    scroll:SetPoint('TOPLEFT',20,-160);scroll:SetPoint('BOTTOMRIGHT',-42,90)
    self.body=CreateFrame('Frame',nil,scroll);self.body:SetSize(690,1);scroll:SetScrollChild(self.body)
    self.scroll=scroll
    self.message=label(frame,'',20,-610);self.message:SetWidth(710);self.message:SetJustifyH('LEFT')
    local apply=button(frame,'Apply',100,function() self:Apply() end);apply:SetPoint('BOTTOMRIGHT',-20,18)
    local revert=button(frame,'Revert edits',110,function() self.pending=nil;self:LoadUnit() end);revert:SetPoint('RIGHT',apply,'LEFT',-10,0)
    self.frame=frame
    if UISpecialFrames then table.insert(UISpecialFrames,'SquanchOnUFOptions') end
    if ns.TrackMenuFrame then ns:TrackMenuFrame(frame) end
    return frame
end
function Options:Open()
    if InCombatLockdown() then return false,'Combat' end
    if not ns.UnitFrames or not ns.UnitFrames.Initialized then return false,'Unit frames are not initialized' end
    self:Build():Show();self:LoadUnit();return true
end
function ns:OpenUnitFrameOptions() return Options:Open() end
local events=CreateFrame('Frame');events:RegisterEvent('PLAYER_REGEN_ENABLED')
events:SetScript('OnEvent',function()
    local pending=Options.pending;Options.pending=nil
    if not pending then return end
    if pending.kind=='profile' then Options:SelectProfile(pending.name,pending.create)
    else Options:Commit(pending.config,pending.unit,pending.profile) end
end)
