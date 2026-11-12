-- SPDX-License-Identifier: MIT
-- Exact Camelot professions-book cards. Native profession state/content owns
-- icons, rank bars, unlearn controls, labels and visibility without interception.
local _, ns = ...
local module = {}
ns.NativeProfessionSkins = module
local backgrounds = setmetatable({}, { __mode = "k" })
local initialized, pending = false, false
local cards = {
    "PrimaryProfession1", "PrimaryProfession2",
    "SecondaryProfession1", "SecondaryProfession2", "SecondaryProfession3",
}

local function skinCard(card)
    if not card or card:IsForbidden() or not ns.DarkSkin then return end
    if InCombatLockdown() then pending = true; return end
    local background = card.Background
    if not background or not background.IsObjectType or not background:IsObjectType("Texture") then return end
    local atlas = background:GetAtlas()
    if not atlas or not atlas:find("^Profession%-overview%-[Cc]ard") then return end
    -- Card illustration, solid brown backing and gold edge are one native atlas.
    -- Keep its exact image/coordinates as a subdued neutral translucent layer.
    -- Use vertex alpha, leaving native Texture/parent alpha transitions intact.
    if backgrounds[background] == nil then
        local _, _, _, alpha = background:GetVertexColor()
        backgrounds[background] = alpha
    end
    background:SetDesaturated(true)
    background:SetVertexColor(0.8, 0.8, 0.8, backgrounds[background] * 0.35)
    ns.DarkSkin:SmallBox(card)
end

function module:Apply()
    local root = ProfessionsFrame
    if not root or root:IsForbidden() then return end
    local content = root.BookPage and root.BookPage.ProfessionsContentFrame
    if not content then return end
    if InCombatLockdown() then pending = true; return end
    pending = false
    for _, key in ipairs(cards) do skinCard(content[key]) end
end

local events = CreateFrame("Frame")
local function initialize()
    if initialized or not ProfessionsFrame or ProfessionsFrame:IsForbidden() then return end
    local page = ProfessionsFrame.BookPage
    if not page or page:IsForbidden() or type(page.FormatProfession) ~= "function" then return end
    initialized = true
    events:UnregisterEvent("ADDON_LOADED")
    -- Native FormatProfession changes primary card atlas for learned/unlearned
    -- state. Post-style that exact card; never call profession updates ourselves.
    hooksecurefunc(page, "FormatProfession", function(_, card) skinCard(card) end)
    page:HookScript("OnShow", function() module:Apply() end)
    module:Apply()
end
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_REGEN_ENABLED" then
        if pending then module:Apply() end
    elseif event == "PLAYER_LOGIN" or name == "Blizzard_Professions" or name == "Blizzard_ProfessionsBook" then
        initialize()
    end
end)
