-- SPDX-License-Identifier: MIT
-- Squanch-On: original native settings panel and profile controls, MIT.
local _,ns=...
local Options={}
ns.UnitFrameOptions=Options
local fields={
    {'Frame enabled','enable','boolean'},
    {'Width','width','number',15,1000},{'Height','height','number',5,500},
    {'Portrait','portrait.enable','boolean'},
    {'Portrait style','portrait.style','choice',{'3D','2D','Class'}},
    {'Portrait width','portrait.width','number',1,300},
    {'Portrait rotation','portrait.rotation','number',0,360},
    {'Portrait camera distance','portrait.camDistanceScale','number',.01,20},
    {'Portrait horizontal offset','portrait.xOffset','number',-20,20},
    {'Portrait vertical offset','portrait.yOffset','number',-20,20},
    {'Portrait overlay','portrait.overlay','boolean'},
    {'Portrait paused','portrait.paused','boolean'},
    {'Name text','name.text_format','string'},
    {'Name size','name.size','number',5,40},
    {'Name region','name.attachTextTo','choice',{'Frame','Health','Power'}},
    {'Name horizontal offset','name.xOffset','number',-500,500},
    {'Name vertical offset','name.yOffset','number',-500,500},
    {'Health text','health.text_format','string'},
    {'Reverse health fill','health.reverseFill','boolean'},
    {'Power bar','power.enable','boolean'},
    {'Power height','power.height','number',1,300},
    {'Power horizontal offset','power.xOffset','number',-500,500},
    {'Power vertical offset','power.yOffset','number',-500,500},
    {'Detached power','power.detachFromFrame','boolean'},
    {'Detached power width','power.detachedWidth','number',15,1000},
    {'Power text','power.text_format','string'},
    {'Cast bar','castbar.enable','boolean'},
    {'Cast width','castbar.width','number',20,1000},
    {'Cast height','castbar.height','number',4,100},
    {'Cast position','castbar.overlayOnFrame','choice',{'None','Power','Health'}},
    {'Cast icon','castbar.icon','boolean'},
    {'Cast latency','castbar.latency','boolean'},
    {'Hide cast name','castbar.hideName','boolean'},
    {'Hide cast time','castbar.hideTime','boolean'},
    {'Class resources','classbar.enable','boolean'},
    {'Class resource height','classbar.height','number',1,100},
    {'Class resource spacing','classbar.spacing','number',0,30},
    {'Buffs','buffs.enable','boolean'},
    {'Buffs per row','buffs.perrow','number',1,40},
    {'Buff rows','buffs.numrows','number',1,8},
    {'Buff icon size (0: fit)','buffs.sizeOverride','number',0,100},
    {'Debuffs','debuffs.enable','boolean'},
    {'Debuffs per row','debuffs.perrow','number',1,40},
    {'Debuff rows','debuffs.numrows','number',1,8},
    {'Debuff icon size (0: fit)','debuffs.sizeOverride','number',0,100},
    {'Fade enabled','fader.enable','boolean'},
    {'Range fade','fader.range','boolean'},
    {'Fade minimum alpha','fader.minAlpha','number',0,1},
    {'Fade maximum alpha','fader.maxAlpha','number',0,1},
    {'Show player in combat','fader.combat','boolean'},
    {'Show player with target','fader.playertarget','boolean'},
    {'Show player on hover','fader.hover','boolean'},
    {'Show player while casting','fader.casting','boolean'},
    {'Show player while hurt','fader.health','boolean'},
    {'Group horizontal spacing','horizontalSpacing','number',0,100},
    {'Group vertical spacing','verticalSpacing','number',0,100},
    {'Group growth','growthDirection','choice',{'DOWN','UP','LEFT','RIGHT','RIGHT_DOWN','RIGHT_UP','LEFT_DOWN','LEFT_UP'}},
    {'Group visibility condition','visibility','string'},
}
for _,name in ipairs({'Unit name','[faction:icon]','[health:percent]','[level]','[class:icon]'}) do
    local prefix='customTexts.'..name..'.'
    fields[#fields+1]={name..' enabled',prefix..'enable','boolean'}
    fields[#fields+1]={name..' text',prefix..'text_format','string'}
    fields[#fields+1]={name..' size',prefix..'size','number',5,80}
    fields[#fields+1]={name..' font',prefix..'font','string'}
    fields[#fields+1]={name..' region',prefix..'attachTextTo','choice',{'Frame','Health','Power'}}
    fields[#fields+1]={name..' alignment',prefix..'justifyH','choice',{'CENTER','LEFT','RIGHT'}}
    fields[#fields+1]={name..' horizontal offset',prefix..'xOffset','number',-500,500}
    fields[#fields+1]={name..' vertical offset',prefix..'yOffset','number',-500,500}
end
local function pathValue(object,path,value,write)
    local current=object
    local keys={}
    for key in path:gmatch('[^.]+') do keys[#keys+1]=key end
    for index=1,#keys-1 do
        if type(current[keys[index]])~='table' then
            if not write then return end
            current[keys[index]]={}
        end
        current=current[keys[index]]
    end
    if write then current[keys[#keys]]=value else return current[keys[#keys]] end
end
local function label(parent,text,x,y)
    local fs=parent:CreateFontString(nil,'OVERLAY','GameFontNormal')
    fs:SetPoint('TOPLEFT',x,y);fs:SetText(text);return fs
end
local function button(parent,text,width,callback)
    local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate')
    b:SetSize(width,24);b:SetText(text);b:SetScript('OnClick',callback);return b
end
local function edit(parent,width)
    local e=CreateFrame('EditBox',nil,parent,'InputBoxTemplate')
    e:SetSize(width,22);e:SetAutoFocus(false)
    e:SetScript('OnEscapePressed',function(self) self:ClearFocus() end)
    return e
end
function Options:Message(text)
    if self.message then self.message:SetText(text or '') end
end
function Options:LoadUnit()
    local UF=ns.UnitFrames
    if not UF.db then return end
    local key=ns.UnitFrameImport.units[self.unitIndex or 1]
    self.unitKey=key;self.unitButton:SetText(key)
    self.working=ns.UnitFrameImport:Copy(UF.db.units[key])
    self.profileName:SetText(UF.state.profile)
    for _,row in ipairs(self.rows) do
        local value=pathValue(self.working,row.field[2])
        if row.field[3]=='boolean' then row.control:SetChecked(value==true)
        else row.control:SetText(value==nil and '' or tostring(value)) end
    end
    self:Message('')
end
function Options:Apply()
    local UF=ns.UnitFrames
    if InCombatLockdown() then self:Message('Settings can be applied after combat.');return end
    local copy=ns.UnitFrameImport:Copy(self.working)
    for _,row in ipairs(self.rows) do
        local field,control=row.field,row.control
        local value
        if field[3]=='boolean' then value=control:GetChecked()==true
        elseif field[3]=='number' then
            local text=control:GetText()
            if text~='' then
                value=tonumber(text)
                if not value or value~=value or value<field[4] or value>field[5] then
                    self:Message(field[1]..' must be between '..field[4]..' and '..field[5]..'.');return
                end
            end
        else value=control:GetText() end
        pathValue(copy,field[2],value,true)
    end
    UF.db.units[self.unitKey]=copy
    local ok,reason=UF:Update_AllFrames()
    self:Message(ok and 'Settings applied.' or reason)
end
function Options:SelectProfile(name,create)
    local UF=ns.UnitFrames
    if InCombatLockdown() then self:Message('Profiles can be changed after combat.');return end
    name=(name or ''):match('^%s*(.-)%s*$')
    if name=='' or #name>80 then self:Message('Enter a profile name (1–80 characters).');return end
    if create then
        if UF.state.profiles[name] then self:Message('That profile already exists.');return end
        UF.state.profiles[name]=ns.UnitFrameImport:Copy(UF.db)
    elseif not UF.state.profiles[name] then self:Message('Profile not found.');return end
    UF.state.profile=name
    UF:Update_AllFrames();self:LoadUnit()
    self:Message('Selected profile: '..name)
end
function Options:Build()
    if self.frame then return self.frame end
    local frame=CreateFrame('Frame','SquanchOnUFOptions',UIParent,'BackdropTemplate')
    frame:SetSize(720,650);frame:SetPoint('CENTER');frame:SetFrameStrata('DIALOG')
    frame:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1})
    frame:SetBackdropColor(.055,.055,.055,.96);frame:SetBackdropBorderColor(.7,.532,.294,1)
    frame:EnableMouse(true);frame:SetMovable(true);frame:RegisterForDrag('LeftButton')
    frame:SetScript('OnDragStart',frame.StartMoving);frame:SetScript('OnDragStop',frame.StopMovingOrSizing)
    label(frame,"Squancher's Squanch-On · Unit frames",20,-18)
    local close=CreateFrame('Button',nil,frame,'UIPanelCloseButton');close:SetPoint('TOPRIGHT',-2,-2)
    label(frame,'Profile',20,-55)
    self.profileName=edit(frame,190);self.profileName:SetPoint('TOPLEFT',90,-50)
    local select=button(frame,'Select',75,function() self:SelectProfile(self.profileName:GetText(),false) end)
    select:SetPoint('LEFT',self.profileName,'RIGHT',12,0)
    local clone=button(frame,'Copy to new',105,function() self:SelectProfile(self.profileName:GetText(),true) end)
    clone:SetPoint('LEFT',select,'RIGHT',8,0)
    local unitButton=button(frame,'player',180,function()
        self.unitIndex=(self.unitIndex or 1)%#ns.UnitFrameImport.units+1;self:LoadUnit()
    end)
    unitButton:SetPoint('TOPLEFT',20,-86);self.unitButton=unitButton
    local layout=button(frame,'Move & resize',150,function()
        frame:Hide();if ns.LayoutEditor then ns.LayoutEditor:Open() end
    end);layout:SetPoint('LEFT',unitButton,'RIGHT',12,0)
    local scroll=CreateFrame('ScrollFrame',nil,frame,'UIPanelScrollFrameTemplate')
    scroll:SetPoint('TOPLEFT',20,-125);scroll:SetPoint('BOTTOMRIGHT',-42,90)
    local body=CreateFrame('Frame',nil,scroll);body:SetSize(640,#fields*30)
    scroll:SetScrollChild(body)
    self.rows={}
    for index,field in ipairs(fields) do
        local y=-(index-1)*30
        label(body,field[1],0,y-5)
        local control
        if field[3]=='boolean' then
            control=CreateFrame('CheckButton',nil,body,'UICheckButtonTemplate');control:SetSize(25,25)
        elseif field[3]=='choice' then
            control=button(body,'',220,function(self)
                local index=0
                for i,value in ipairs(field[4]) do if value==self:GetText() then index=i;break end end
                self:SetText(field[4][index%#field[4]+1])
            end)
        else control=edit(body,field[3]=='string' and 300 or 100) end
        control:SetPoint('TOPLEFT',310,y)
        self.rows[#self.rows+1]={field=field,control=control}
    end
    self.message=label(frame,'',20,-580);self.message:SetWidth(670);self.message:SetJustifyH('LEFT')
    local apply=button(frame,'Apply',100,function() self:Apply() end);apply:SetPoint('BOTTOMRIGHT',-20,18)
    local revert=button(frame,'Revert edits',110,function() self:LoadUnit() end);revert:SetPoint('RIGHT',apply,'LEFT',-10,0)
    self.frame=frame
    if UISpecialFrames then table.insert(UISpecialFrames,'SquanchOnUFOptions') end
    return frame
end
function Options:Open()
    if InCombatLockdown() then return false,'Combat' end
    if not ns.UnitFrames or not ns.UnitFrames.Initialized then return false,'Unit frames are not initialized' end
    self:Build():Show();self:LoadUnit();return true
end
function ns:OpenUnitFrameOptions() return Options:Open() end
