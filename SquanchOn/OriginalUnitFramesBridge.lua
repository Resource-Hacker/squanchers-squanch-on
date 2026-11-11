-- SPDX-License-Identifier: MIT
-- Adapt the original scoped engines without importing or rewriting profiles.
local addonName,ns=...
local module={status={},frames={},headers={},original=true}
ns.UnitFrames=module
local function refresh()
  local engine=_G.ElvUI and _G.ElvUI[1]
  if not engine then module.status.error='Original unit-frame dependency did not load';return end
  local original=engine:GetModule('UnitFrames')
  if not module.nameLayerHook then
    module.nameLayerHook=true
    hooksecurefunc(original,'Configure_CustomTexts',function(_,frame)
      local texts=frame.unit=='targettarget' and frame.customTexts
      if texts and texts['Unit name'] and texts['[faction:icon]'] then
        texts['[faction:icon]']:SetDrawLayer('OVERLAY',0)
        texts['Unit name']:SetDrawLayer('OVERLAY',1)
      end
    end)
  end
  module.Original=original;module.Engine=engine
  module.frames=original.units or {}
  module.headers={party=original.party,raid1=original.raid1,raid2=original.raid2,raid3=original.raid3,assist=original.assist,tank=original.tank}
  local player=_G.ElvUF_Player
  module.status.initialized=engine.Initialized and original.Initialized and player and player:GetWidth()>0 or false
  module.status.profile=engine.data and engine.data:GetCurrentProfile()
  module.status.originalEngine=true
  local tooltip=engine:GetModule('Tooltip',true)
  module.status.tooltipInitialized=tooltip and tooltip.Initialized or false
  module.status.tooltipStyled=tooltip and tooltip.isStyled or false
  module.status.scope=engine.SquancherUnitFramesScope
  module.status.actionbarOwnerActive=engine:GetModule('ActionBars').Initialized or false
  module.status.nameplateOwnerActive=engine:GetModule('NamePlates').Initialized or false
  module.status.chatOwnerActive=engine:GetModule('Chat').Initialized or false
  module.status.bagOwnerActive=engine:GetModule('Bags').Initialized or false
  local benik=_G.ElvUI_BenikUI and _G.ElvUI_BenikUI[1]
  module.status.benikUnits=benik and benik:GetModule('Units').initialized or false
end
function module.GetProfile()
  local engine=_G.ElvUI and _G.ElvUI[1]
  if not engine then return nil end
  return {unitframe=engine.db.unitframe,movers=engine.db.movers,benikui=engine.db.benikui,global=engine.global,private=engine.private}
end
function module:RequestReload()
  if InCombatLockdown() then self.reloadAfterCombat=true;return false,'combat' end
  ReloadUI();return true
end
local function openOptions(section)
  local engine=_G.ElvUI and _G.ElvUI[1]
  if not engine then return end
  if InCombatLockdown() then engine.ShowOptions=true;return end
  engine:ToggleOptions(section)
  local options=engine.Options and engine.Options.args and engine.Options.args.unitframe
  if options and options.args then
    options.args.squancherLayout={type='execute',name='Move & resize UI',order=0.1,width='full',
      desc='Open the 10-pixel grid and 16:9 streaming guide.',
      func=function() engine:ToggleOptions();ns.LayoutEditor:Open() end}
    if engine.Libs.AceConfigRegistry then engine.Libs.AceConfigRegistry:NotifyChange('ElvUI') end
  end
  local dialog=engine.Libs.AceConfigDialog
  if dialog.OpenFrames and dialog.OpenFrames.ElvUI then dialog:SelectGroup('ElvUI',section) end
end
function ns:OpenUnitFrameOptions() openOptions('unitframe') end
function ns:OpenTooltipOptions() openOptions('tooltip') end
module.RefreshStatus=refresh
local events=CreateFrame('Frame')
events:RegisterEvent('PLAYER_LOGIN');events:RegisterEvent('PLAYER_ENTERING_WORLD');events:RegisterEvent('PLAYER_REGEN_ENABLED')
events:SetScript('OnEvent',function(_,event)
  if event=='PLAYER_REGEN_ENABLED' and module.reloadAfterCombat then ReloadUI();return end
  refresh()
end)
refresh()
