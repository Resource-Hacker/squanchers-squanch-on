-- SPDX-License-Identifier: MIT
-- Layout handles adapt original ElvUI profile fields; original engines own frames.
local _,ns=...
local module={}
ns.LayoutUnitFrames=module

local definitions={
  {'player','Player','ElvUF_PlayerMover'},
  {'target','Target','ElvUF_TargetMover'},
  {'pet','Pet','ElvUF_PetMover'},
  {'focus','Focus','ElvUF_FocusMover'},
  {'targettarget','Target of target','ElvUF_TargetTargetMover'},
  {'targettargettarget','Target of target of target','ElvUF_TargetTargetTargetMover'},
  {'focustarget','Focus target','ElvUF_FocusTargetMover'},
  {'pettarget','Pet target','ElvUF_PetTargetMover'},
  {'party','Party','ElvUF_PartyMover','header'},
  {'raid1','Raid 1','ElvUF_Raid1Mover','header'},
  {'raid2','Raid 2','ElvUF_Raid2Mover','header'},
  {'raid3','Raid 3','ElvUF_Raid3Mover','header'},
  {'raidpet','Raid pets','ElvUF_RaidpetMover','header'},
  {'tank','Main tanks','ElvUF_TankMover','header'},
  {'assist','Main assists','ElvUF_AssistMover','header'},
  {'boss','Boss frames','BossHeaderMover','group'},
  {'arena','Arena frames','ArenaHeaderMover','group'},
}
local castUnits={player=true,target=true,pet=true,focus=true}

local function current(definition,cast)
  local engine=_G.ElvUI and _G.ElvUI[1]
  if not engine or not engine.Initialized or not engine.GetMoverHolder then return end
  local original=engine:GetModule('UnitFrames',true)
  local db=engine.db and engine.db.unitframe
  db=db and db.units and db.units[definition[1]]
  if not original or not original.Initialized or not db or not db.enable then return end
  if cast and (not db.castbar or not db.castbar.enable or db.castbar.overlayOnFrame~='None') then return end
  local name=cast and ('ElvUF_'..definition[1]:gsub('^%l',string.upper)..'CastbarMover') or definition[3]
  local holder,disabled=engine:GetMoverHolder(name)
  if not holder or disabled or not holder.mover then return end
  return engine,original,db,holder.mover,name
end

local function profile(engine)
  return engine.data and engine.data:GetCurrentProfile()
end

local function refresh(original,definition)
  if definition[4]=='header' then original:CreateAndUpdateHeaderGroup(definition[1])
  elseif definition[4]=='group' then original:CreateAndUpdateUFGroup(definition[1],5)
  else original:CreateAndUpdateUF(definition[1]) end
end

local function finite(value)
  return type(value)=='number' and value==value and value~=math.huge and value~=-math.huge
end

local function validRect(rect)
  return type(rect)=='table' and finite(rect.x) and finite(rect.y) and finite(rect.w) and finite(rect.h) and rect.w>0 and rect.h>0
end

local function persist(editor,engine,mover,name,rect)
  editor:Place(mover,rect)
  local point,relative,relativePoint,x,y=mover:GetPoint()
  local relativeName=type(relative)=='string' and relative or relative and relative:GetName()
  if not point or not relativeName or not relativePoint then return false,'Unavailable' end
  engine.db.movers=engine.db.movers or {}
  -- Native SaveMoverPosition rounds offsets to integer UI units, losing pixels
  -- when physical and UI coordinates have different scales.
  engine.db.movers[name]=string.format('%s,%s,%s,%.12g,%.12g',point,relativeName,relativePoint,x or 0,y or 0)
  engine:SetMoverPoints(name)
  return true
end

local function boundsFrames(definition,cast,mover)
  local root=mover and mover.parent
  if not root then return {} end
  if cast or not definition[4] then return {root} end
  local frames={}
  local E=_G.ElvUI and _G.ElvUI[1]
  -- Select real primary member units, not their aura/castbar subtrees. Boss and
  -- arena buttons are siblings anchored to the header mover, not its children.
  for _,frame in ipairs(E and E.oUF and E.oUF.objects or {}) do
    if frame.unitframeType==definition[1] then frames[#frames+1]=frame end
  end
  return frames
end

-- Native pixel rounding is piecewise constant. Build the legal choices once
-- per drag; previews only binary-search them and commit one native update.
local function prepareResize(definition,cast,rect,corner)
  local editor=ns.LayoutEditor
  local E,UF,db,mover=current(definition,cast)
  if not E then return nil,'Unavailable' end
  local grouped=not cast and definition[4]~=nil
  local header=grouped and UF[definition[1]]
  if grouped and definition[4]=='header' and not (header and header.numGroups) then
    return nil,'This dynamic group cannot guarantee a 5px resize.'
  end
  local m=E.mult
  if not finite(m) or m<=0 then return nil,'Native pixel scale is unavailable.' end
  local settings=cast and db.castbar or db
  local w,h=settings.width,settings.height
  local info=not cast and db.infoPanel and db.infoPanel.enable and db.infoPanel.height or 0
  local native=editor:Rect(mover)
  local rw,rh=mover:GetSize()
  if not validRect(native) or not rw or not rh or rw<=0 or rh<=0 then return nil,'Unavailable' end
  local fx,fy=native.w/rw,native.h/rh
  local function model(a,b)
    local W,H=E:Scale(a),E:Scale(b+info)
    if not grouped then return W,H end
    if definition[4]=='group' then
      local n=definition[1]=='arena' and 5 or MAX_BOSS_FRAMES
      if not n then return nil end
      local spacing=E:Scale(db.spacing)
      if db.growthDirection=='LEFT' or db.growthDirection=='RIGHT' then return n*W+(n-1)*spacing,H end
      return W,n*H+(n-1)*spacing
    end
    local n,k=header.numGroups,definition[1]=='party' and 1 or db.groupsPerRowCol
    if not n or not k or k<1 then return nil end
    local A,B=math.ceil(n/k),math.min(n,k)
    local hs,vs,gs=E:Scale(db.horizontalSpacing),E:Scale(db.verticalSpacing),E:Scale(db.groupSpacing)
    if db.growthDirection:match('^LEFT') or db.growthDirection:match('^RIGHT') then
      return 5*B*(W+hs)+(B-1)*gs-hs,A*(H+vs)+(A-1)*gs-vs
    end
    return A*(W+hs)+(A-1)*gs-hs,5*B*(H+vs)+(B-1)*gs-vs
  end
  local baseW,baseH=model(w,h)
  if not baseW then return nil,'Unavailable group geometry' end
  -- Calibrate fixed border/spacing additions from the actual painted bounds.
  local bx,by=rect.w-fx*baseW,rect.h-fy*baseH
  local pw,ph=editor:Metrics()
  local maxW=corner=='BOTTOMLEFT' and rect.x+rect.w or pw-rect.x
  local maxH=ph-rect.y
  local function legal(v) return editor:RoundPhysicalSize(v)%5==0 end
  local function choose(list,value)
    local low,high=1,#list
    while low<high do local mid=math.floor((low+high)/2);if list[mid].size<value then low=mid+1 else high=mid end end
    if low>1 and math.abs(list[low-1].size-value)<=math.abs(list[low].size-value) then low=low-1 end
    return list[low]
  end
  local minW,maxRawW=cast and 50 or 15,cast and E.screenWidth or 1000
  local minH,maxRawH=5,cast and 85 or 500
  if (maxRawW+maxRawH)/m>20000 then return nil,'Native pixel grid is too fine for bounded resizing.' end
  if m==1 then
    local function payload(a,b) return {width=a,height=b,beforeW=w,beforeH=h,profile=profile(E)} end
    if not grouped then
      return function(width,height)
        local W=editor:SnapSize(width,fx*minW+bx,math.min(maxW,fx*maxRawW+bx))
        local H=editor:SnapSize(height,fy*(minH+info)+by,math.min(maxH,fy*(maxRawH+info)+by))
        if not W or not H then return nil end
        return W,H,payload((W-bx)/fx,(H-by)/fy-info)
      end
    end
    -- Without native quantization the fixed topology is affine in member scale.
    local doubleW,doubleH=model(2*w,2*h)
    local aW,aH=fx*(doubleW-baseW),fy*(doubleH-baseH)
    local bW,bH=rect.w-aW,rect.h-aH
    if aW<=0 or aH<=0 then return nil,'Unavailable group geometry' end
    local ratio=aW/aH
    local offset=bH-bW/ratio
    local low,high=math.max(minW/w,minH/h),math.min(maxRawW/w,maxRawH/h)
    return function(width)
      local W,H=editor:SnapScale(width,ratio,aW*low+bW,
        math.min(aW*high+bW,maxW,(maxH-offset)*ratio),offset)
      if not W then return nil end
      local t=(W-bW)/aW
      return W,H,payload(w*t,h*t)
    end
  end
  local choices={}
  if grouped then
    local low,high=math.max(minW/w,minH/h),math.min(maxRawW/w,maxRawH/h)
    local cuts={low,high}
    for _,axis in ipairs({{w,0},{h,info}}) do
      for j=math.ceil((axis[1]*low+axis[2])/m),math.floor((axis[1]*high+axis[2])/m) do
        local t=(j*m-axis[2])/axis[1];if t>low and t<high then cuts[#cuts+1]=t end
      end
    end
    table.sort(cuts)
    for i=2,#cuts do
      if cuts[i]-cuts[i-1]>1e-8 then
        local t=(cuts[i]+cuts[i-1])/2
        local W,H=model(w*t,h*t);W,H=fx*W+bx,fy*H+by
        if W>1 and H>1 and W<=maxW and H<=maxH and legal(W) and legal(H) then
          choices[#choices+1]={size=W,w=W,h=H,rawW=w*t,rawH=h*t}
        end
      end
    end
    if #choices==0 then return nil,'No native 5px size fits this group.' end
    return function(width)
      local c=choose(choices,width)
      return c.w,c.h,{width=c.rawW,height=c.rawH,beforeW=w,beforeH=h,profile=profile(E)}
    end
  end
  local function axisChoices(minimum,maximum,offset,factor,addition,cap)
    local list={}
    for j=math.floor((minimum+offset)/m)-1,math.ceil((maximum+offset)/m)+1 do
      local raw=(j+.5)*m-offset
      if raw>=minimum and raw<=maximum then
        local size=factor*E:Scale(raw+offset)+addition
        if size>1 and size<=cap and legal(size) then list[#list+1]={size=size,raw=raw} end
      end
    end
    return list
  end
  local widths=axisChoices(minW,maxRawW,0,fx,bx,maxW)
  local heights=axisChoices(minH,maxRawH,info,fy,by,maxH)
  if #widths==0 or #heights==0 then return nil,'No native 5px size fits this element.' end
  return function(width,height)
    local a,b=choose(widths,width),choose(heights,height)
    return a.size,b.size,{width=a.raw,height=b.raw,beforeW=w,beforeH=h,profile=profile(E)}
  end
end

local function register(definition,cast)
  local editor=ns.LayoutEditor
  if not editor then return end
  local engine= current(definition,cast)
  if not engine then return end
  local key=definition[1]
  local id=(cast and 'cast_' or 'uf_')..key
  if module.registered[id] then return end
  local grouped=not cast and definition[4]~=nil
  editor:Register({
    id=id,
    label=definition[2]..(cast and ' castbar' or ''),
    resize=grouped and 'scale' or 'free',
    fixedBorderSize=true,
    prepareResize=function(rect,corner) return prepareResize(definition,cast,rect,corner) end,
    getBoundsFrames=function(mover) return boundsFrames(definition,cast,mover) end,
    getFrame=function()
      local _,_,_,mover=current(definition,cast)
      return mover
    end,
    snapshot=function()
      local owner,_,db,_,name=current(definition,cast)
      if not owner then return nil end
      local settings=cast and db.castbar or db
      return {
        profile=profile(owner),
        mover=owner.db.movers and owner.db.movers[name],
        hadMovers=owner.db.movers~=nil,
        width=settings.width,height=settings.height,
        castbarWidth=not cast and db.castbar and db.castbar.width or nil,
      }
    end,
    commit=function(rect,resizing)
      if InCombatLockdown() then return false,'Combat' end
      local owner,original,db,mover,name=current(definition,cast)
      if not owner then return false,'Unavailable' end
      if not validRect(rect) then return false,'Invalid rectangle' end
      if resizing then
        local before=editor:Rect(mover)
        if not validRect(before) then return false,'Unavailable' end
        local settings=cast and db.castbar or db
        local width,height
        local prepared=rect.nativeSize
        if prepared then
          if prepared.profile~=profile(owner) or prepared.beforeW~=settings.width or prepared.beforeH~=settings.height then return false,'Frame size changed during drag' end
          width,height=prepared.width,prepared.height
        elseif grouped then
          -- Resize member dimensions uniformly; preserve topology and spacing.
          local ratio=rect.w/before.w
          ratio=math.max(15/settings.width,5/settings.height,math.min(ratio,1000/settings.width,500/settings.height))
          width,height=settings.width*ratio,settings.height*ratio
        else
          local rawWidth,rawHeight=mover:GetSize()
          if not rawWidth or not rawHeight or rawWidth<=0 or rawHeight<=0 then return false,'Unavailable' end
          width=rect.w*rawWidth/before.w
          height=rect.h*rawHeight/before.h
          if not cast and db.infoPanel and db.infoPanel.enable then height=height-(db.infoPanel.height or 0) end
          width=math.max(cast and 50 or 15,math.min(width,cast and (owner.screenWidth or width) or 1000))
          height=math.max(5,math.min(height,cast and 85 or 500))
        end
        -- Match the original editor's coupled-width behavior for unit frames.
        if not cast and definition[4]~='header' and db.castbar and db.castbar.width==settings.width then db.castbar.width=width end
        settings.width,settings.height=width,height
        refresh(original,definition)
        local _,_,_,updated=current(definition,cast)
        if not updated then return false,'Unavailable' end
        mover=updated
      end
      -- Movement never rewrites frame size or any unrelated configuration.
      return persist(editor,owner,mover,name,rect)
    end,
    restore=function(saved)
      if InCombatLockdown() then return false,'Combat' end
      local owner,original,db,_,name=current(definition,cast)
      if not owner then return false,'Unavailable' end
      if type(saved)~='table' or saved.profile~=profile(owner) then return false,'Profile changed' end
      local settings=cast and db.castbar or db
      settings.width,settings.height=saved.width,saved.height
      if not cast and db.castbar then db.castbar.width=saved.castbarWidth end
      refresh(original,definition)
      owner.db.movers=owner.db.movers or {}
      owner.db.movers[name]=saved.mover
      if not saved.hadMovers and not next(owner.db.movers) then owner.db.movers=nil end
      owner:SetMoverPoints(name)
      return true
    end,
  })
  module.registered[id]=true
end

-- Tooltip content chooses its own dimensions. Move its original fixed anchor;
-- original tooltip settings continue to own fonts, offsets and cursor anchoring.
local function registerTooltip()
  local editor=ns.LayoutEditor
  local function owner()
    local engine=_G.ElvUI and _G.ElvUI[1]
    local tooltip=engine and engine:GetModule('Tooltip',true)
    if not engine or not engine.Initialized or not tooltip or not tooltip.Initialized or engine.db.tooltip.cursorAnchor then return end
    local holder,disabled=engine:GetMoverHolder('TooltipMover')
    if holder and not disabled then return engine,holder.mover end
  end
  local engine=owner()
  if not engine or module.registered.tooltip_anchor then return end
  editor:Register({
    id='tooltip_anchor',label='Tooltip anchor',resize=false,
    getFrame=function() local _,mover=owner();return mover end,
    snapshot=function()
      local current=owner()
      return current and {profile=profile(current),mover=current.db.movers and current.db.movers.TooltipMover,hadMovers=current.db.movers~=nil}
    end,
    commit=function(rect)
      if InCombatLockdown() then return false,'Combat' end
      local current,mover=owner()
      if not current or not validRect(rect) then return false,'Unavailable' end
      return persist(editor,current,mover,'TooltipMover',rect)
    end,
    restore=function(saved)
      if InCombatLockdown() then return false,'Combat' end
      local current=owner()
      if not current or not saved or saved.profile~=profile(current) then return false,'Profile changed' end
      current.db.movers=current.db.movers or {};current.db.movers.TooltipMover=saved.mover
      if not saved.hadMovers and not next(current.db.movers) then current.db.movers=nil end
      current:SetMoverPoints('TooltipMover');return true
    end,
  })
  module.registered.tooltip_anchor=true
end

module.registered={}
local queued=false
local hooked
local schedule
function module:Register()
  if not ns.LayoutEditor or InCombatLockdown() then return end
  local engine=_G.ElvUI and _G.ElvUI[1]
  if engine and engine.Initialized and hooked~=engine then
    hooked=engine
    local original=engine:GetModule('UnitFrames',true)
    hooksecurefunc(engine,'LoadMovers',schedule)
    if original then
      hooksecurefunc(original,'CreateAndUpdateUF',schedule)
      hooksecurefunc(original,'CreateAndUpdateUFGroup',schedule)
      hooksecurefunc(original,'CreateAndUpdateHeaderGroup',schedule)
    end
  end
  registerTooltip()
  for _,definition in ipairs(definitions) do
    register(definition,false)
    if castUnits[definition[1]] then register(definition,true) end
  end
end
schedule=function()
  if queued then return end
  queued=true
  C_Timer.After(0,function() queued=false;module:Register() end)
end
local events=CreateFrame('Frame')
events:RegisterEvent('PLAYER_LOGIN')
events:RegisterEvent('PLAYER_REGEN_ENABLED')
events:RegisterEvent('ADDON_LOADED')
events:SetScript('OnEvent',function(_,event,addon)
  if event~='ADDON_LOADED' or addon=='ElvUI' or addon=='ElvUI_BenikUI' then schedule() end
end)
if IsLoggedIn() then schedule() end
