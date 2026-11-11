-- SPDX-License-Identifier: MIT
-- Original native-tooltip styling. Blizzard owns content, comparisons and values.
local addonName, ns = ...
local Tooltip = { hooked = setmetatable({}, {__mode='k'}) }
ns.TooltipSkin = Tooltip
local font = 'Interface\\AddOns\\' .. addonName .. '\\media\\fonts\\ptsansnarrow_bold.ttf'
local names = {'GameTooltip','ShoppingTooltip1','ShoppingTooltip2','ItemRefTooltip',
    'ItemRefShoppingTooltip1','ItemRefShoppingTooltip2','FriendsTooltip','QuickKeybindTooltip',
    'GameSmallHeaderTooltip','LibDBIconTooltip','SettingsTooltip','WorldMapTooltip'}
local function settings()
    if not ns.db then return end
    ns.db.tooltip = ns.db.tooltip or {headerSize=12,bodySize=8,alpha=.5,cursor=false,
        point='BOTTOM',relativePoint='BOTTOM',x=285,y=165,healthHeight=6}
    return ns.db.tooltip
end
local function public(value) return not (issecretvalue and issecretvalue(value)) end
function Tooltip:Anchor(tt)
    local db=settings()
    if not db or not tt or tt:IsForbidden() then return end
    if db.cursor then tt:SetOwner(tt:GetOwner() or UIParent,'ANCHOR_CURSOR');return end
    tt:ClearAllPoints();tt:SetPoint('BOTTOM',self.mover,'BOTTOM')
end
function Tooltip:Style(tt)
    local db=settings()
    if not db or not tt or tt:IsForbidden() or tt.IsEmbedded then return end
    local skin=ns.DarkSkin
    if not skin then return end
    -- An independently acquired tooltip keeps native dimensions and content.
    if not self.hooked[tt] then
        if InCombatLockdown() then return end
        self.hooked[tt]=true
        tt:HookScript('OnShow',function() self:Style(tt) end)
        tt:HookScript('OnSizeChanged',function() self:Style(tt) end)
    end
    if self.styling then return end
    self.styling=true
    local border=skin:Panel(tt,'tooltip',0)
    skin:FitPanelBorder(border,tt,skin.styles.tooltip)
    if tt.SetBackdropColor then tt:SetBackdropColor(.035,.035,.035,db.alpha) end
    local nine=tt.NineSlice
    if nine and nine.SetCenterColor then nine:SetCenterColor(.035,.035,.035,db.alpha) end
    -- Preserve native line colors, wrapping and item-quality information.
    local name=tt:GetName()
    if name then
        for i=1,tt.NumLines and tt:NumLines() or 0 do
            for _,side in ipairs({'Left','Right'}) do
                local text=_G[name..'Text'..side..i]
                if text then text:SetFont(font,i==1 and db.headerSize or db.bodySize,'OUTLINE') end
            end
        end
    end
    local bar=GameTooltipStatusBar
    if tt==GameTooltip and bar and not InCombatLockdown() then
        bar:SetHeight(db.healthHeight)
        bar:ClearAllPoints();bar:SetPoint('TOPLEFT',tt,'BOTTOMLEFT',0,-2)
        bar:SetPoint('TOPRIGHT',tt,'BOTTOMRIGHT',0,-2)
        if bar:IsShown() then
            border:SetPoint('BOTTOMRIGHT',tt,'BOTTOMRIGHT',skin.styles.tooltip.offset,
                -skin.styles.tooltip.offset-db.healthHeight-2)
        end
    end
    self.styling=nil
end
function Tooltip:Refresh()
    local db=settings()
    if not db then return end
    if not self.mover and not InCombatLockdown() then
        self.mover=CreateFrame('Frame','SquanchOnTooltipAnchor',UIParent)
        self.mover:SetSize(140,20);self.mover:EnableMouse(false)
        self.mover:SetPoint(db.point,UIParent,db.relativePoint,db.x,db.y)
    end
    if not self.mover then return end
    if not self.anchorHooked then
        self.anchorHooked=true
        hooksecurefunc('GameTooltip_SetDefaultAnchor',function(tt) self:Anchor(tt) end)
        if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
            TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes,function(tt) self:Style(tt) end)
        end
        if GameTooltipStatusBar then
            GameTooltipStatusBar:HookScript('OnShow',function() self:Style(GameTooltip) end)
            GameTooltipStatusBar:HookScript('OnHide',function() self:Style(GameTooltip) end)
        end
    end
    local editor=ns.LayoutEditor
    if editor and not self.registered then
        self.registered=true
        editor:Register({id='tooltip_anchor',label='Tooltip anchor',getFrame=function()
            if not settings().cursor then return self.mover end
        end,resize=false,snapshot=function() return editor:Copy(settings()) end,
        commit=function(rect)
            if InCombatLockdown() then return end
            editor:Place(self.mover,rect)
            local point,relative,relativePoint,x,y=self.mover:GetPoint()
            db.point=point;db.relativePoint=relativePoint;db.x=x;db.y=y
        end,
        restore=function(saved)
            if InCombatLockdown() or not saved then return end
            ns.db.tooltip=editor:Copy(saved);db=settings()
            self.mover:ClearAllPoints();self.mover:SetPoint(db.point,UIParent,db.relativePoint,db.x,db.y)
        end})
    end
    for _,name in ipairs(names) do self:Style(_G[name]) end
end
function ns:OpenTooltipOptions()
    if InCombatLockdown() then print('Squanch-On: tooltip settings are available after combat.');return end
    Tooltip:Refresh()
    if not Tooltip.options then
        local frame=CreateFrame('Frame','SquanchOnTooltipOptions',UIParent,'BasicFrameTemplateWithInset')
        frame:SetSize(370,245);frame:SetPoint('CENTER');frame:SetFrameStrata('DIALOG')
        frame.TitleText:SetText("Squanch-On: tooltips")
        table.insert(UISpecialFrames,'SquanchOnTooltipOptions')
        self:TrackMenuFrame(frame)
        local caption=frame:CreateFontString(nil,'OVERLAY','GameFontHighlight')
        caption:SetPoint('TOPLEFT',20,-40);caption:SetText('Move the fixed anchor in /sqedit.')
        local check=CreateFrame('CheckButton',nil,frame,'UICheckButtonTemplate')
        check:SetPoint('TOPLEFT',16,-65);check.Text:SetText('Anchor tooltips to the cursor')
        check:SetScript('OnClick',function(button) settings().cursor=button:GetChecked();Tooltip:Refresh() end)
        frame.check=check;frame.fields={}
        for i,spec in ipairs({{'headerSize','Heading size',6,24},{'bodySize','Body size',6,24},
            {'alpha','Background opacity',0,1},{'healthHeight','Health bar height',2,30}}) do
            local field=CreateFrame('EditBox',nil,frame,'InputBoxTemplate')
            field:SetSize(55,20);field:SetPoint('TOPRIGHT',-30,-95-(i-1)*30);field:SetAutoFocus(false)
            local label=frame:CreateFontString(nil,'OVERLAY','GameFontHighlight')
            label:SetPoint('RIGHT',field,'LEFT',-15,0);label:SetText(spec[2])
            field:SetScript('OnEnterPressed',function(box)
                local n=tonumber(box:GetText())
                if n and public(n) then settings()[spec[1]]=math.max(spec[3],math.min(spec[4],n)) end
                box:SetText(tostring(settings()[spec[1]]));box:ClearFocus();Tooltip:Refresh()
            end)
            frame.fields[spec[1]]=field
        end
        Tooltip.options=frame
    end
    local frame=Tooltip.options;frame.check:SetChecked(settings().cursor)
    for key,field in pairs(frame.fields) do field:SetText(tostring(settings()[key])) end
    frame:Show()
end
local events=CreateFrame('Frame')
for _,event in ipairs({'PLAYER_LOGIN','PLAYER_REGEN_ENABLED','ADDON_LOADED'}) do events:RegisterEvent(event) end
events:SetScript('OnEvent',function() if ns.db then Tooltip:Refresh() end end)
