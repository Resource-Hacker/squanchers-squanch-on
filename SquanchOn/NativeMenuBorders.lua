-- SPDX-License-Identifier: MIT
-- Original Squancher decoration for Blizzard_Menu's pooled menu frames.
-- The native lease emits these events after setup and before compositor reset.
-- Keep native rows, checkmarks, highlights and input handlers.
local _, ns = ...
local module = {}
ns.NativeMenuBorders = module

local function showBorder(_, menu)
    local skin = ns.DarkSkin
    if not skin or not menu then return end
    if ns.NativeText then ns.NativeText:Menu(menu) end
    -- Panel's external byFrame cache survives native pool/proxy key flushing.
    -- Reuse the existing quest-menu compact rim instead of adding a second one.
    local border = skin:Panel(menu, "compact", 0)
    -- These two native menu styles attach one composite decorative background.
    -- Reuse that pooled texture for a fitted fill rather than stacking rims or
    -- leaving its native transparent margins between the fill and our border.
    for _, region in ipairs({menu:GetRegions()}) do
        local atlas = region.GetAtlas and region:GetAtlas()
        if atlas == "common-dropdown-bg" or atlas == "common-dropdown-c-bg" then
            -- Pooled by the client: painted per show, never recorded for retinting.
            region:SetColorTexture(skin:FillColor())
            region:SetAlpha(1)
            skin:FitPanelBackground(region, border)
        end
    end
    border:SetFrameLevel(menu:GetFrameLevel() + 1)
    border:Show()
end

local function hideBorder(_, menu)
    local skin = ns.DarkSkin
    local styles = skin and skin.byFrame[menu]
    if styles and styles.compact then styles.compact:Hide() end
end

local events = CreateFrame("Frame")
local function install()
    if module.installed or not Menu or not Menu.GetManager or not EventRegistry then return end
    module.installed = true
    -- MenuProxy.OnShow is emitted for root and submenu acquisitions AFTER their
    -- final frame level is set. OnHide fires on release BEFORE compositor flush.
    -- These native lease events avoid attaching scripts that the pool discards.
    EventRegistry:RegisterCallback("MenuProxy.OnShow", showBorder, module)
    EventRegistry:RegisterCallback("MenuProxy.OnHide", hideBorder, module)
    events:UnregisterAllEvents()
    -- Loading this optional adapter must not require closing an existing menu.
    local menu = Menu.GetManager():GetOpenMenu()
    if menu then showBorder(module, menu) end
end
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", install)
install()
