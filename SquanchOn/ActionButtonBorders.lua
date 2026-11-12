-- SPDX-License-Identifier: MIT
-- Original narrow skin adapter using Blizzard-owned art and owner profile data.
-- Load after DarkSkin.lua and before NativeActionBars.lua. No Masque/M33 runtime.
local _, ns = ...
local Skin = ns.DarkSkin
if not Skin then return end
local profiles = {}
Skin.actionButtonProfiles = profiles

local function refresh(button)
    local state = profiles[button]
    if not state or state.refreshing then return end
    if InCombatLockdown() then state.pending=true;return end
    state.pending=nil
    state.refreshing = true
    if ns.NativeText then ns.NativeText:Frame(button) end
    local width, height = button:GetSize()
    if state.icon then
        state.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        state.icon:ClearAllPoints()
        if state.kind == "action" then
            -- Fit the art to the rim's visible inner edge, with half a screen
            -- pixel underlap so antialiasing cannot expose a bright hairline.
            local edge = Skin.styles.icon.edge
            local pixel = PixelUtil.GetPixelToUIUnitFactor() / button:GetEffectiveScale()
            local x = math.max(0, edge * 3 / 13 - pixel / 2)
            local top = math.max(0, edge * 3 / 13 - pixel / 2)
            local bottom = math.max(0, edge * 3 / 13 - pixel / 2)
            state.icon:SetPoint("TOPLEFT", button, "TOPLEFT", x, -top)
            state.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -x, bottom)
        else
            state.icon:SetAllPoints(button)
        end
        state.icon:SetDrawLayer("ARTWORK", -1)
    end
    -- The shared cell edge owns the border. Suppress the native normal rim
    -- after art updates so it cannot add padding or a second frame.
    local nativeNormal = button.GetNormalTexture and button:GetNormalTexture()
    if nativeNormal then nativeNormal:SetAlpha(0); nativeNormal:Hide() end
    for _, key in ipairs({ "SlotArt", "SlotBackground" }) do
        if button[key] then button[key]:Hide() end
    end
    -- Each rim owns one chat-matched fill with independent baseline fading.
    state.backdrop:Hide()
    local pushed = button.GetPushedTexture and button:GetPushedTexture()
    if pushed then
        pushed:SetTexture([[Interface\Buttons\UI-Quickslot-Depress]])
        pushed:SetTexCoord(0, 1, 0, 1); pushed:SetVertexColor(1, 1, 1, 1)
        pushed:SetDrawLayer("ARTWORK", 1); pushed:ClearAllPoints(); pushed:SetPoint("CENTER", button, "CENTER")
        pushed:SetSize(width, height)
    end
    if state.kind == "action" and state.icon then
        -- Native checked/mouseover art is fixed at 46x45 and TOPLEFT, while
        -- this skin insets the icon. Fit only these button-state textures;
        -- native checked/hover state, alpha and spell/cooldown effects remain owned by Blizzard.
        for _, method in ipairs({ "GetPushedTexture", "GetCheckedTexture", "GetHighlightTexture" }) do
            local texture = button[method] and button[method](button)
            if texture then
                texture:ClearAllPoints()
                texture:SetAllPoints(state.icon)
            end
        end
    end
    if state.kind == "bag" then
        state.border=Skin:ControlBorder(button,"icon",state.alphaOwner,0.5)
        Skin:BagSlotFill(state.border,button)
        -- The native empty placeholder is opaque artwork, not a bag icon.
        -- Keep real bags/backpack visible as native texture updates arrive.
        if state.icon and button.IsBackpack and button.HasBagEquipped then
            state.icon:SetShown(button:IsBackpack() or button:HasBagEquipped())
        end
    else
        state.border=Skin:RawSlotBorder(button,state.alphaOwner,0.5)
        -- The same neutral inner rim used by native equipment slots.
        if not state.iconRim then state.iconRim=button:CreateTexture(nil,"ARTWORK",nil,0) end
        state.iconRim:SetTexture([[Interface\Buttons\UI-Quickslot2]])
        state.iconRim:SetSize(state.icon:GetWidth()*64/37,state.icon:GetHeight()*64/37)
        state.iconRim:SetPoint("CENTER",state.icon,"CENTER",0,-state.icon:GetHeight()/37)
        state.iconRim:SetDesaturated(true)
        state.iconRim:SetVertexColor(unpack(Skin.innerBorderColor))
    end
    state.refreshing = false
end

function Skin:ActionButton(button, kind, alphaOwner)
    if not button then return end
    if profiles[button] then refresh(button); return end
    local icon = button.icon or button.Icon
    if not icon and button:GetName() then icon = _G[button:GetName() .. "Icon"] or _G[button:GetName() .. "IconTexture"] end
    kind = kind or (button.bar == PetActionBar and "pet" or "action")
    -- Clean up the former approximate implementation if this file is integrated
    -- into a staged build that already created its extra edge/backdrop.
    if self.buttons[button] then self.buttons[button]:Hide() end
    local oldPanel = self.byFrame[button] and self.byFrame[button].inner
    if oldPanel then oldPanel:Hide() end
    local state = { kind = kind, icon = icon, alphaOwner = alphaOwner or button.bar or button }
    state.backdrop = button:CreateTexture(nil, "BACKGROUND", nil, -1)
    state.backdrop:SetPoint("CENTER", button, "CENTER")
    profiles[button] = state
    self.buttons[button] = state.backdrop
    -- Icons fitted to their painted rim, shared cell edges and native pressed art.
    for _, method in ipairs({ "SetNormalAtlas", "SetNormalTexture", "SetPushedAtlas", "SetPushedTexture", "SetCheckedAtlas", "SetCheckedTexture", "SetHighlightAtlas", "SetHighlightTexture", "UpdateButtonArt", "UpdateTextures" }) do
        if type(button[method]) == "function" then hooksecurefunc(button, method, function() refresh(button) end) end
    end
    button:HookScript("OnSizeChanged", function() refresh(button) end)
    if icon then
        hooksecurefunc(icon, "SetTexture", function() refresh(button) end)
        hooksecurefunc(icon, "Show", function() refresh(button) end)
        hooksecurefunc(icon, "Hide", function() refresh(button) end)
    end
    refresh(button)
end

-- Unavailable features keep their native disabled icon and interaction state.
-- Their whole-cell alpha must match the rest of the row, including its frame.
local microOpacityHooks = {}
local function uniformMicroOpacity(button)
    button:SetAlpha(1)
end

-- Micro buttons are plain cells of the chat header strip. The chat panel owns
-- their top/right rim, divider and fill; DarkSkin draws one seam per cell.
function Skin:BarControls()
    if not CharacterMicroButton then return end
    if MicroMenu and MicroMenu.GenerateButtonInfos then
        for _, info in ipairs(MicroMenu:GenerateButtonInfos()) do
            local button = info.button
            if button then
                if not microOpacityHooks[button] then
                    microOpacityHooks[button] = true
                    button:HookScript("OnDisable", uniformMicroOpacity)
                end
                uniformMicroOpacity(button)
                -- Retire the per-cell diamond rim and fill of the former layout.
                local rim = self.byFrame[button] and self.byFrame[button].icon
                if rim then
                    rim:Hide()
                    if rim.slotFill then rim.slotFill:Hide() end
                end
                for _, key in ipairs({"Background", "PushedBackground"}) do
                    local texture = button[key]
                    if texture then
                        -- Native SetNormal shows Background again; keep its pixel
                        -- transparent so only the chat fill darkens the resting cell.
                        texture:SetColorTexture(0, 0, 0, key == "PushedBackground" and 0.65 or 0)
                        texture:ClearAllPoints()
                        texture:SetAllPoints(button)
                    end
                end
            end
        end
    end
end

-- Native icon changes remain free of addon geometry while combat-locked.
local pendingSkins=CreateFrame("Frame")
pendingSkins:RegisterEvent("PLAYER_REGEN_ENABLED")
pendingSkins:SetScript("OnEvent",function()
    for button,state in pairs(profiles) do if state.pending then refresh(button) end end
end)
