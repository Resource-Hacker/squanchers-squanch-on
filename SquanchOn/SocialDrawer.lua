-- SPDX-License-Identifier: MIT
-- Native Social UI opens upward from chat. Native tabs/list/actions own content.
local _,ns=...
local Drawer={scrollHooks=setmetatable({}, {__mode='k'})}
ns.SocialDrawer=Drawer
local contentKeys={'FriendsList','RecentAlliesList','QuickJoinFrame','RecruitAFriendFrame','RaidFrame'}
function Drawer:Owns(frame) return frame and frame==SocialUIFrame end
local function point(frame,...)
 local clear=frame.ClearAllPointsBase or frame.ClearAllPoints
 local set=frame.SetPointBase or frame.SetPoint
 clear(frame)
 set(frame,...)
end
-- Native FriendsListSocialView mixes headers/spacers with recycled cards.
-- Decorate only FriendsListSocialCardTemplate; keep its native art and input.
function Drawer:StyleFriendCard(card)
 if not card or not card.PartyButton or not card.InitializeBackground then return end
 local rim=ns.DarkSkin:Panel(card,'inner',0)
 if card.Background then ns.DarkSkin:FitPanelBackground(card.Background,rim) end
end
function Drawer:StyleFriendCards()
 local list=SocialUIFrame and SocialUIFrame.FriendsList
 local scroll=list and list.ScrollBox
 if not scroll or not scroll.GetView or not scroll:GetView() then return end
 if self.friendScroll~=scroll then
  self.friendScroll=scroll
  scroll:RegisterCallback(ScrollBoxListMixin.Event.OnInitializedFrame,function(_,card)
   self:StyleFriendCard(card)
  end,self)
 end
 scroll:ForEachFrame(function(card) self:StyleFriendCard(card) end)
end
function Drawer:FitTabSpine(tabs)
 if #tabs==0 then if self.tabSpine then self.tabSpine:Hide() end;return end
 local host=self.tabSpine
 if not host then
  host=CreateFrame('Frame',nil,SocialUIFrame)
  host:EnableMouse(false)
  host:EnableMouseWheel(false)
  host.ignoreInLayout=true
  host:SetWidth(5)
  local rim=ns.DarkSkin:Panel(host,'inner',0)
  -- Reuse just the material's vertical edge: no extra panel fill or box.
  for _,key in ipairs({'TopLeftCorner','TopRightCorner','BottomLeftCorner','BottomRightCorner','TopEdge','BottomEdge','RightEdge'}) do
   rim[key]:Hide()
  end
  local edge=rim.LeftEdge
  local outer=rim.cornerSize*4.5/13
  edge:ClearAllPoints()
  edge:SetPoint('TOPLEFT',host,'TOPLEFT',outer,0)
  edge:SetPoint('BOTTOMLEFT',host,'BOTTOMLEFT',outer,0)
  self.tabSpine=host
 end
 point(host,'TOPLEFT',tabs[1],'TOPLEFT',-2,0)
 host:SetPoint('BOTTOMLEFT',tabs[#tabs],'BOTTOMLEFT',-2,0)
 host:Show()
end
function Drawer:Queue()
 if self.fitting or self.queued then return end
 self.queued=true
 C_Timer.After(0,function() self.queued=nil;self:Fit() end)
end
function Drawer:Fit()
 local frame,chat=SocialUIFrame,ns.DarkSkin and ns.DarkSkin.chatPanel
 if not frame or not chat or self.fitting then return end
 if InCombatLockdown() then self.pending=true;return end
 self.pending=nil;self.fitting=true
 local scale=frame:GetEffectiveScale()
 local ratio=chat:GetEffectiveScale()/scale
 local width=chat:GetWidth()*ratio
 local available=(UIParent:GetHeight()*UIParent:GetEffectiveScale()-chat:GetTop()*chat:GetEffectiveScale())/scale-12
 local column=frame.GetTabColumnWidth and frame:GetTabColumnWidth() or 48
 -- This attached owner already bounds height to the room above chat. Native
 -- screen clamping can translate the root away from its requested chat anchor.
 frame:SetClampedToScreen(false)
 frame:SetWidth(width)
 point(frame,'BOTTOMLEFT',chat,'TOPLEFT',0,0)
 local bar=frame.BattleNetBar
 if bar then
  point(bar,'TOPLEFT',frame,'TOPLEFT',4,-30)
  bar:SetPoint('TOPRIGHT',frame,'TOPRIGHT',-4,-30)
  if bar.Background then
   -- Native friends-frame-infobg is an atlas-sized centered413px texture.
   -- The bar starts four units inside the root; retain a physical-pixel inset
   -- so its fill also clears the root rim's inward rounding.
   local pixel=PixelUtil.GetPixelToUIUnitFactor()/bar:GetEffectiveScale()
   bar.Background:ClearAllPoints()
   bar.Background:SetPoint('TOPLEFT',bar,'TOPLEFT',pixel,0)
   bar.Background:SetPoint('BOTTOMRIGHT',bar,'BOTTOMRIGHT',-pixel,0)
  end
 end
 local active
 for _,key in ipairs(contentKeys) do
  local content=frame[key]
  if content then
   point(content,'TOPLEFT',bar,'BOTTOMLEFT',0,5)
   content:SetPoint('BOTTOMRIGHT',frame,'BOTTOMRIGHT',-column-5,2)
   if content.BottomDivider then
    local divider=content.BottomDivider
    point(divider,'BOTTOMLEFT',content,'BOTTOMLEFT',5,42)
    divider:SetPoint('BOTTOMRIGHT',content,'BOTTOMRIGHT',-5,42)
   end
   if content:IsShown() then active=content end
   local scroll=content.ScrollBox
   if scroll and not self.scrollHooks[scroll] then
    self.scrollHooks[scroll]=true
    if scroll.Update then hooksecurefunc(scroll,'Update',function() self:Queue() end) end
    if scroll.SetDataProvider then hooksecurefunc(scroll,'SetDataProvider',function() self:Queue() end) end
   end
  end
 end
 local desired=675
 local scroll=active and active.ScrollBox
 local view=scroll and scroll.GetView and scroll:GetView()
 local extent=view and view.GetExtent and view:GetExtent()
 if type(extent)=='number' and extent>0 and scroll:GetHeight()>0 then
  desired=frame:GetHeight()-scroll:GetHeight()+extent
 end
 local height=math.min(math.max(280,desired),math.max(220,available))
 if math.abs(frame:GetHeight()-height)>.1 then frame:SetHeight(height) end
 -- Reassert after native resize callbacks, not before the final root height.
 point(frame,'BOTTOMLEFT',chat,'TOPLEFT',0,0)
 if frame.EnumerateTabs then
  local tabs={}
  for tab in frame:EnumerateTabs() do tabs[#tabs+1]=tab end
  table.sort(tabs,function(a,b) return (a.tabData.tabOrder or a.tabData.tabType or 0)<(b.tabData.tabOrder or b.tabData.tabType or 0) end)
  for i,tab in ipairs(tabs) do
   point(tab,'TOPRIGHT',frame,'TOPRIGHT',-4,-122-(i-1)*(tab:GetHeight()+3))
  end
  self:FitTabSpine(tabs)
 end
 for _,key in ipairs({'TopFade','BottomFade'}) do if frame[key] then frame[key]:Hide() end end
 self:StyleFriendCards()
 self.fitting=nil
end
function Drawer:Initialize()
 local frame=SocialUIFrame
 if not frame or not ns.DarkSkin.chatPanel or self.initialized then return end
 if InCombatLockdown() then self.pending=true;return end
 self.initialized=true;self.scrollHooks=setmetatable({}, {__mode='k'})
 frame:HookScript('OnShow',function() self:Queue();ns.DrawerMotion:Open(frame,ns.DarkSkin.chatPanel) end)
 frame:HookScript('OnSizeChanged',function() self:Queue() end)
 for _,method in ipairs({'SetPoint','SetScale','RefreshTabs','SelectTab','TryRefreshUIPanelPositions'}) do
  if frame[method] then hooksecurefunc(frame,method,function() self:Queue() end) end
 end
 if frame.SetPointBase then hooksecurefunc(frame,'SetPointBase',function() self:Queue() end) end
 ns.DarkSkin.chatPanel:HookScript('OnSizeChanged',function() self:Queue() end)
 hooksecurefunc(ns.DarkSkin,'LayoutChat',function() self:Queue() end)
 self:Fit()
end
local events=CreateFrame('Frame')
for _,event in ipairs({'PLAYER_LOGIN','ADDON_LOADED','PLAYER_REGEN_ENABLED'}) do events:RegisterEvent(event) end
events:SetScript('OnEvent',function()
 C_Timer.After(0,function() Drawer:Initialize();if Drawer.initialized then Drawer:Fit() end end)
end)
