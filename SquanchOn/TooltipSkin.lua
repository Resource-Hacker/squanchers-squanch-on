-- SPDX-License-Identifier: MIT
-- Independently written presentation adapter. Blizzard owns tooltip content,
-- comparisons, health values and their event handlers; imported settings survive.
local _, ns = ...
local Tooltip = {hooked=setmetatable({}, {__mode='k'})}
ns.TooltipSkin = Tooltip
local names={'GameTooltip','ShoppingTooltip1','ShoppingTooltip2','ShoppingTooltip3',
    'ItemRefTooltip','ItemRefShoppingTooltip1','ItemRefShoppingTooltip2','FriendsTooltip',
    'QuickKeybindTooltip','GameSmallHeaderTooltip','LibDBIconTooltip','SettingsTooltip','WorldMapTooltip'}
local inverse={TOP='BOTTOM',BOTTOM='TOP',LEFT='RIGHT',RIGHT='LEFT',TOPLEFT='BOTTOMRIGHT',
    TOPRIGHT='BOTTOMLEFT',BOTTOMLEFT='TOPRIGHT',BOTTOMRIGHT='TOPLEFT',CENTER='CENTER'}
local defaults={font='Bui Homizio',headerFont='Bui Homizio',headerFontSize=12,textFontSize=8,
    smallTextFontSize=8,fontOutline='OUTLINE',headerFontOutline='OUTLINE',colorAlpha=.5,
    cursorAnchor=false,cursorAnchorType='ANCHOR_CURSOR',cursorAnchorX=60,cursorAnchorY=-128,
    xOffset=0,yOffset=18,itemQuality=true,healthBar={height=6,statusPosition='BOTTOM',text=false}}
local function public(value) return not (issecretvalue and issecretvalue(value)) end
local function usable(tt) return tt and (not tt.IsForbidden or not tt:IsForbidden()) end
local function copy(value)
    if type(value)~='table' then return value end
    local result={};for key,child in pairs(value) do result[key]=copy(child) end;return result
end
local function input()
    if not ns.db then return end
    -- Never migrate through the old lossy ns.db.tooltip alpha schema.
    if type(ns.db.tooltipImport)~='table' or type(ns.db.tooltipImport.tooltip)~='table' then return end
    return ns.db.tooltipImport
end
local function settings() local source=input();return source and source.tooltip end
local function setting(db,key) if db[key]~=nil then return db[key] end;return defaults[key] end
local function media(kind,name)
    if ns.Media and ns.Media.Resolve then return ns.Media:Resolve(kind,name) end
end
local function pixel(frame)
    local _,physicalHeight=GetPhysicalScreenSize()
    return 768 / physicalHeight / frame:GetEffectiveScale()
end
local function quantize(value,frame)
    if value==0 then return 0 end
    local step=pixel(frame)
    if step==1 then return value end
    local magnitude=math.abs(value)/step
    local count=step<1 and math.floor(magnitude) or math.ceil(magnitude)
    return (value<0 and -1 or 1)*count*step
end
local function setFont(object,name,size,outline)
    if not object or not object.SetFont then return end
    local path=media('font',name)
    if path then
        object:SetFont(path,size,outline=='NONE' and '' or outline or '')
        if object.SetShadowOffset then object:SetShadowOffset(0,0) end
    end
end
function Tooltip:Quadrant()
    local x,y=self.mover:GetCenter()
    if not x or not y then return 'BOTTOMRIGHT' end
    local width,height=UIParent:GetWidth(),UIParent:GetHeight()
    local vertical=y>height*2/3 and 'TOP' or y<height/3 and 'BOTTOM' or ''
    local horizontal=x<width/3 and 'LEFT' or x>width*2/3 and 'RIGHT' or ''
    local point=vertical..horizontal
    if point=='LEFT' then return 'BOTTOMLEFT' end
    if point=='RIGHT' or point=='' then return 'BOTTOMRIGHT' end
    return point
end
function Tooltip:Anchor(tt,parent)
    if InCombatLockdown() then self.pending=true;return end
    local db=settings()
    if not db or not usable(tt) or not self.mover then return end
    if tt.GetAnchorType and tt:GetAnchorType()~='ANCHOR_NONE' then return end
    if setting(db,'cursorAnchor') then
        parent=parent or tt:GetOwner() or UIParent
        if usable(parent) then tt:SetOwner(parent,setting(db,'cursorAnchorType'),
            setting(db,'cursorAnchorX'),setting(db,'cursorAnchorY')) end
        return
    end
    -- Only the native default-anchor call comes here. Explicit widget-owned
    -- anchors and comparison placement are left to their native owners.
    local point=self:Quadrant()
    tt:ClearAllPoints()
    tt:SetPoint(point,self.mover,inverse[point],quantize(setting(db,'xOffset'),tt),quantize(setting(db,'yOffset'),tt))
end
local function paint(frame,color,alpha)
    local edge=frame.SquanchOnTooltipEdge
    if not edge then
        edge=CreateFrame('Frame',nil,frame,'BackdropTemplate')
        edge:EnableMouse(false);edge:SetAllPoints(frame)
        edge:SetFrameLevel(math.max(0,frame:GetFrameLevel()-1))
        frame.SquanchOnTooltipEdge=edge
    end
    edge:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=quantize(1,frame)})
    edge:SetBackdropColor(color.r or .054,color.g or .054,color.b or .054,alpha)
    return edge
end
function Tooltip:ItemBorder(tt,edge,db,general)
    local color=general.bordercolor or {};local r,g,b=color.r or 0,color.g or 0,color.b or 0
    if setting(db,'itemQuality') and C_Item and C_Item.GetItemQualityByID then
        local get=TooltipUtil and TooltipUtil.GetDisplayedItem or tt.GetItem
        if get then
            local ok,_,link=pcall(get,tt)
            if ok and public(link) and link then
                local qualityOK,quality=pcall(C_Item.GetItemQualityByID,link)
                if qualityOK and public(quality) and type(quality)=='number' and quality>1 then
                    local qualityColor=ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
                    if qualityColor then r,g,b=qualityColor.r,qualityColor.g,qualityColor.b end
                end
            end
        end
    end
    edge:SetBackdropBorderColor(r,g,b,1)
end
function Tooltip:Fonts(tt,db)
    local comparison=tt==ShoppingTooltip1 or tt==ShoppingTooltip2 or tt==_G.ShoppingTooltip3
        or tt==ItemRefShoppingTooltip1 or tt==ItemRefShoppingTooltip2
    local name=tt:GetName()
    if name then
        for i=1,tt.NumLines and tt:NumLines() or 0 do
            for _,side in ipairs({'Left','Right'}) do
                local heading=i==1 and not comparison
                setFont(_G[name..'Text'..side..i],setting(db,heading and 'headerFont' or 'font'),
                    setting(db,heading and 'headerFontSize' or comparison and 'smallTextFontSize' or 'textFontSize'),
                    setting(db,heading and 'headerFontOutline' or 'fontOutline'))
            end
        end
    end
    if tt==GameTooltip and tt.hasMoney then
        for i=1,tt.numMoneyFrames or 0 do
            for _,suffix in ipairs({'PrefixText','SuffixText','GoldButtonText','SilverButtonText','CopperButtonText'}) do
                setFont(_G['GameTooltipMoneyFrame'..i..suffix],setting(db,'font'),setting(db,'textFontSize'),setting(db,'fontOutline'))
            end
        end
    end
    if comparison then
        for _,region in ipairs({tt:GetRegions()}) do
            if region.IsObjectType and region:IsObjectType('FontString') then
                setFont(region,setting(db,'font'),setting(db,'smallTextFontSize'),setting(db,'fontOutline'))
            end
        end
        -- The accepted Squancher treatment keeps comparison item names at
        -- heading size after native small-body styling.
        for _,side in ipairs({'Left','Right'}) do
            setFont(name and _G[name..'Text'..side..'1'],setting(db,'headerFont'),
                setting(db,'headerFontSize'),setting(db,'headerFontOutline'))
        end
    end
end
function Tooltip:HealthBar(tt,db,general)
    if InCombatLockdown() then self.pending=true;return 0 end
    local bar=GameTooltipStatusBar
    if tt~=GameTooltip or not usable(bar) then return 0 end
    local health=db.healthBar or defaults.healthBar
    local position=health.statusPosition or 'BOTTOM'
    bar:SetAlpha(position=='DISABLED' and 0 or 1)
    bar:SetHeight(quantize(health.height or 6,bar))
    local texture=media('statusbar','ElvUI Norm')
    if texture then bar:SetStatusBarTexture(texture) end
    local edge=paint(bar,general.backdropfadecolor or {},(general.backdropfadecolor or {}).a or .75)
    local outside=quantize(1,bar)
    edge:ClearAllPoints();edge:SetPoint('TOPLEFT',bar,'TOPLEFT',-outside,outside)
    edge:SetPoint('BOTTOMRIGHT',bar,'BOTTOMRIGHT',outside,-outside)
    edge:SetBackdropBorderColor(0,0,0,1)
    local border=quantize(1,tt) -- imported reference uses pixelPerfect=true.
    bar:ClearAllPoints()
    if position=='TOP' then
        bar:SetPoint('BOTTOMLEFT',tt,'TOPLEFT',border,0)
        bar:SetPoint('BOTTOMRIGHT',tt,'TOPRIGHT',-border,0)
    elseif position=='BOTTOM' then
        bar:SetPoint('TOPLEFT',tt,'BOTTOMLEFT',border,0)
        bar:SetPoint('TOPRIGHT',tt,'BOTTOMRIGHT',-border,0)
    end
    -- No OnValueChanged replacement, unit query or duplicate health writer.
    if position=='BOTTOM' and bar:IsShown() then
        return bar:GetHeight()*bar:GetEffectiveScale()/tt:GetEffectiveScale()+pixel(tt)
    end
    return 0
end
function Tooltip:Style(tt)
    local source=input();local db=source and source.tooltip
    if not db or not usable(tt) or tt.IsEmbedded then return end
    if tt.GetWidth and not public(tt:GetWidth()) then return end
    if InCombatLockdown() then self.pending=true;return end
    if self.styling then return end
    self.styling=true
    if not self.hooked[tt] then
        self.hooked[tt]=true
        tt:HookScript('OnShow',function() self:Style(tt) end)
        tt:HookScript('OnSizeChanged',function() self:Style(tt) end)
    end
    if tt.NineSlice then tt.NineSlice:SetAlpha(0) end
    if tt.SetBackdrop then tt:SetBackdrop(nil) end
    for _,key in ipairs({'Delimiter1','Delimiter2'}) do if tt[key] then tt[key]:SetAlpha(0) end end
    local general=source.general or {}
    local edge=paint(tt,general.backdropfadecolor or {},setting(db,'colorAlpha'))
    self:ItemBorder(tt,edge,db,general)
    if usable(tt.CompareHeader) then
        local header=tt.CompareHeader
        if header.NineSlice then header.NineSlice:SetAlpha(0) end
        local headerEdge=paint(header,general.backdropcolor or {r=.025,g=.025,b=.025},1)
        headerEdge:SetBackdropBorderColor(0,0,0,1)
    end
    self:Fonts(tt,db)
    local extra=self:HealthBar(tt,db,general)
    local skin=ns.DarkSkin
    if skin then
        local rim=skin:Panel(tt,'tooltip',0)
        skin:FitPanelBorder(rim,tt,skin.styles.tooltip)
        if extra>0 then rim:SetPoint('BOTTOMRIGHT',tt,'BOTTOMRIGHT',skin.styles.tooltip.offset,-skin.styles.tooltip.offset-extra) end
    end
    self.styling=nil
end
function Tooltip:PositionMover()
    if InCombatLockdown() then self.pending=true;return end
    local source=input();if not source then return end
    local encoded=source.movers and source.movers.TooltipMover
    local p,relative,rp,x,y
    if type(encoded)=='string' then p,relative,rp,x,y=encoded:match('^([^,]+),([^,]+),([^,]+),([^,]+),([^,]+)$') end
    if not p then p,rp,x,y='TOPLEFT','BOTTOMLEFT',1584.00012207,186.666671753 end
    x,y=tonumber(x),tonumber(y)
    if not inverse[p] or not inverse[rp] or not x or not y then return end
    self.mover:ClearAllPoints();self.mover:SetPoint(p,UIParent,rp,x,y)
end
function Tooltip:Refresh()
    local db=settings();if not db then return end
    if InCombatLockdown() then self.pending=true;return end
    self.pending=nil
    if not self.mover then
        self.mover=CreateFrame('Frame','SquanchOnTooltipAnchor',UIParent)
        self.mover:SetSize(quantize(130,UIParent),quantize(20,UIParent));self.mover:EnableMouse(false)
    end
    self:PositionMover()
    setFont(GameTooltipHeaderText,setting(db,'headerFont'),setting(db,'headerFontSize'),setting(db,'headerFontOutline'))
    setFont(GameTooltipText,setting(db,'font'),setting(db,'textFontSize'),setting(db,'fontOutline'))
    setFont(GameTooltipTextSmall,setting(db,'font'),setting(db,'smallTextFontSize'),setting(db,'fontOutline'))
    if not self.anchorHooked then
        self.anchorHooked=true
        hooksecurefunc('GameTooltip_SetDefaultAnchor',function(tt,parent) self:Anchor(tt,parent);self:Style(tt) end)
        if type(SharedTooltip_SetBackdropStyle)=='function' then
            hooksecurefunc('SharedTooltip_SetBackdropStyle',function(tt) self:Style(tt) end)
        end
        if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
            local callback=function(tt) self:Style(tt) end
            if TooltipDataProcessor.AllTypes then TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes,callback)
            elseif Enum and Enum.TooltipDataType then
                local seen={}
                for _,kind in pairs(Enum.TooltipDataType) do
                    if type(kind)=='number' and not seen[kind] then
                        seen[kind]=true;TooltipDataProcessor.AddTooltipPostCall(kind,callback)
                    end
                end
            end
        end
        if usable(GameTooltipStatusBar) then
            for _,event in ipairs({'OnShow','OnHide','OnSizeChanged'}) do
                GameTooltipStatusBar:HookScript(event,function() self:Style(GameTooltip) end)
            end
        end
    end
    local editor=ns.LayoutEditor
    if editor and not self.registered then
        self.registered=true
        editor:Register({id='tooltip_anchor',label='Tooltip anchor',resize=false,
            getFrame=function() local current=settings();return current and not current.cursorAnchor and self.mover end,
            snapshot=function() return copy(input()) end,
            commit=function(rect)
                if InCombatLockdown() then return end
                editor:Place(self.mover,rect)
                local point,_,relativePoint,x,y=self.mover:GetPoint()
                local source=input();source.movers=source.movers or {}
                source.movers.TooltipMover=table.concat({point,'UIParent',relativePoint,x,y},',')
            end,
            restore=function(saved)
                if InCombatLockdown() or not saved then return end
                ns.db.tooltipImport=copy(saved);self:Refresh()
            end})
    end
    for _,name in ipairs(names) do self:Style(_G[name]) end
    if QuestScrollFrame then self:Style(QuestScrollFrame.StoryTooltip);self:Style(QuestScrollFrame.CampaignTooltip) end
end
function ns:OpenTooltipOptions()
    if InCombatLockdown() then print('Squanch-On: tooltip settings are available after combat.');return end
    if not settings() then print('Squanch-On: import the complete tooltip profile before editing it.');return end
    Tooltip:Refresh()
    if not Tooltip.options then
        local frame=CreateFrame('Frame','SquanchOnTooltipOptions',UIParent,'BasicFrameTemplateWithInset')
        frame:SetSize(440,420);frame:SetPoint('CENTER');frame:SetFrameStrata('DIALOG')
        frame.TitleText:SetText('Squanch-On: Tooltip presentation')
        table.insert(UISpecialFrames,'SquanchOnTooltipOptions')
        if self.TrackMenuFrame then self:TrackMenuFrame(frame) end
        local caption=frame:CreateFontString(nil,'OVERLAY','GameFontHighlight')
        caption:SetPoint('TOPLEFT',20,-40);caption:SetWidth(400);caption:SetJustifyH('LEFT')
        caption:SetText('Move the fixed anchor with /sqedit. Blizzard owns content and item comparison. Imported content preferences are preserved; custom ElvUI content extensions are unavailable.')
        local check=CreateFrame('CheckButton',nil,frame,'UICheckButtonTemplate')
        check:SetPoint('TOPLEFT',16,-108);check.Text:SetText('Anchor default tooltips to the cursor')
        check:SetScript('OnClick',function(button)
            settings().cursorAnchor=button:GetChecked()==true;Tooltip:Refresh()
        end)
        frame.check=check;frame.fields={}
        for i,spec in ipairs({{'headerFontSize','Heading size',6,40},{'textFontSize','Body size',6,40},
            {'smallTextFontSize','Comparison text size',6,40},{'colorAlpha','Background opacity',0,1},
            {'xOffset','Fixed anchor horizontal offset',-1000,1000},{'yOffset','Fixed anchor vertical offset',-1000,1000},
            {'healthHeight','Health bar height',1,40}}) do
            local field=CreateFrame('EditBox',nil,frame,'InputBoxTemplate')
            field:SetSize(65,20);field:SetPoint('TOPRIGHT',-30,-143-(i-1)*32);field:SetAutoFocus(false)
            local label=frame:CreateFontString(nil,'OVERLAY','GameFontHighlight')
            label:SetPoint('RIGHT',field,'LEFT',-15,0);label:SetText(spec[2])
            local function read() local db=settings();return spec[1]=='healthHeight' and (db.healthBar or {}).height or setting(db,spec[1]) end
            field:SetScript('OnEscapePressed',function(box) box:SetText(tostring(read() or ''));box:ClearFocus() end)
            field:SetScript('OnEnterPressed',function(box)
                local value=tonumber(box:GetText())
                if value and public(value) and value==value and value>=spec[3] and value<=spec[4] then
                    local db=settings()
                    if spec[1]=='healthHeight' then db.healthBar=db.healthBar or {};db.healthBar.height=value
                    else db[spec[1]]=value end
                end
                box:SetText(tostring(read() or ''));box:ClearFocus();Tooltip:Refresh()
            end)
            frame.fields[spec[1]]={control=field,read=read}
        end
        Tooltip.options=frame
    end
    local frame=Tooltip.options;frame.check:SetChecked(settings().cursorAnchor==true)
    for _,field in pairs(frame.fields) do field.control:SetText(tostring(field.read() or '')) end
    frame:Show()
end
local events=CreateFrame('Frame')
for _,event in ipairs({'PLAYER_LOGIN','PLAYER_REGEN_ENABLED','ADDON_LOADED','UI_SCALE_CHANGED','DISPLAY_SIZE_CHANGED'}) do events:RegisterEvent(event) end
events:SetScript('OnEvent',function() if ns.db then Tooltip:Refresh() end end)
