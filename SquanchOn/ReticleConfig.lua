-- SPDX-License-Identifier: MIT
-- Original compact presentation schema. Numeric dimensions/colors retain the
-- owner's selected geometry; no aura exports, triggers, UIDs or custom scripts.
local addonName, addon = ...
local owned = 'Interface\\AddOns\\' .. addonName .. '\\media\\native-indicators\\'
local crosshairs = 'Interface\\AddOns\\' .. addonName .. '\\media\\Crosshairs\\'
local horde = [[Interface\Timer\Horde-Logo]] -- game-owned; referenced, not bundled
addon.ReticleConfig = {
  order = {'Pet Tracker','No Combat','Combat','Target','Cursor GCD ','Low Mana',
    'Low Health','Execute','Mouseover Glow','Mouseover Dot','Target Range'},
  targetColors = {{.7843,.1647,.1333,.754}, {0,.7843,0,.754}},
  dotSize = {7.1,8.2}, dotYOffset = 4.65,
  layers = {
    ['Pet Tracker'] = {strata='BACKGROUND', size={50,50}, offset={0,40}, art=[[Interface\PVPFrame\Icons\PVP-Banner-Emblem-99]], color={1,1,1,.76}},
    ['No Combat'] = {size={35,35}, art=horde, color={0,0,0,.754}, opacity=.75},
    Combat = {size={35,35}, art=horde, color={.3922,0,0,.75}, opacity=.5, blend='ADD'},
    Target = {size={35,35}, art=horde, color={0,0,0,.75}, opacity=.5},
    ['Cursor GCD '] = {strata='HIGH', size={35,35}, art=horde, progress=true, color={1,0,.0353,.75},
      background={0,0,0,.34}, opacity=.5, enter='grow', exit='shrink'},
    ['Low Mana'] = {strata='BACKGROUND', blend='ADD', size={200,200}, offset={0,2.5}, art=crosshairs..'circle.tga', progress=true,
      color={0,0,1,1}, background={0,0,1,1}, enter='grow', exit='fade', pulse=true},
    ['Low Health'] = {strata='BACKGROUND', blend='ADD', size={75,75}, offset={0,2.5}, art=crosshairs..'circle.tga', progress=true,
      color={1,0,0,.5}, background={1,0,0,.3373}, enter='grow', exit='fade', pulse=true},
    Execute = {strata='BACKGROUND', blend='ADD', size={75,50}, art=crosshairs..'arrows.tga', progress=true,
      color={1,0,.0353,1}, background={0,0,0,0}, enter='grow', exit='ease', pulse=true},
    ['Mouseover Glow'] = {size={7.1,8.2}, art=owned..'diamond.tga', cursor=true, strata='TOOLTIP', blend='ADD',
      color={.6902,0,.0039,1}, opacity=.35, enter='grow', exit='fade'},
    ['Mouseover Dot'] = {strata='TOOLTIP', size={7.1,8.2}, art=owned..'diamond.tga', cursor=true,
      color={.6902,0,.0039,1}, enter='fade', exit='fade'},
    ['Target Range'] = {strata='TOOLTIP', size={5.1,6.1}, offset={0,4.45}, art=owned..'diamond.tga',
      color={1,0,.00784,1}, enter='grow', exit='fade'},
  },
}
