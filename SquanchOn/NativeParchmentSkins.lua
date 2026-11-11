-- SPDX-License-Identifier: MIT
-- Exact Forever page surfaces only. Native layout, spell/quest icons and state
-- colors remain owned by their original engines; shared quest fonts are scoped.
local _, ns = ...
local module = { fills = {}, hidden = {}, text = {}, roots = {}, hooks = {} }
ns.NativeParchmentSkins = module
local GREY, ALPHA = 0.054901964962482, 0.66216158866882

local function public(value)
    return not (_G.issecretvalue and _G.issecretvalue(value))
end

local function number(value)
    return public(value) and type(value) == 'number' and value == value
end

local function within(object, root)
    for _ = 1, 16 do
        if object == root then return true end
        object = object and object.GetParent and object:GetParent()
        if not object then return false end
    end
    return false
end

-- Shared helper for other explicit native-surface adapters. One fill per owner;
-- callers identify and suppress their own exact decorative background regions.
function module:Fill(frame)
    if not frame then return end
    if not self.fills[frame] then
        if InCombatLockdown() then self.pending = true; return end
        local fill = frame:CreateTexture(nil, 'BACKGROUND', nil, -8)
        fill:SetColorTexture(GREY, GREY, GREY, ALPHA)
        self.fills[frame] = fill
    end
    ns.DarkSkin:FitPanelBackground(self.fills[frame], ns.DarkSkin:Panel(frame, 'dialog', 0))
    return self.fills[frame]
end

local function suppress(texture)
    if not texture or not texture.IsObjectType or not texture:IsObjectType('Texture') then return end
    texture:SetAlpha(0)
    if module.hidden[texture] then return end
    module.hidden[texture] = true
    hooksecurefunc(texture, 'SetAlpha', function(self, alpha)
        if public(alpha) and alpha ~= 0 then self:SetAlpha(0) end
    end)
end

local function matchesColor(r, g, b, color)
    if not color or not color.GetRGB then return false end
    local x, y, z = color:GetRGB()
    return number(x) and number(y) and number(z)
        and math.abs(r-x) < .001 and math.abs(g-y) < .001 and math.abs(b-z) < .001
end

local function pageInk(r, g, b)
    if not number(r) or not number(g) or not number(b) then return false end
    -- Leave danger/quality/completion colors intact. Include the client's exact
    -- brown book/material ink, rather than brightening arbitrary colored text.
    if math.max(r,g,b) <= .45 and math.max(r,g,b)-math.min(r,g,b) <= .08 then return true end
    for _, name in ipairs({ 'SPELLBOOK_FONT_COLOR', 'DEFAULT_MATERIAL_TEXT_COLOR',
        'DEFAULT_MATERIAL_TITLETEXT_COLOR', 'PARCHMENT_MATERIAL_TEXT_COLOR', 'PARCHMENT_MATERIAL_TITLETEXT_COLOR' }) do
        if matchesColor(r,g,b,_G[name]) then return true end
    end
    return false
end

local function inlineInk(text)
    if not public(text) or type(text) ~= 'string' then return text end
    return (text:gsub('|c([fF][fF])(%x%x)(%x%x)(%x%x)', function(alpha,r,g,b)
        local red, green, blue = tonumber(r,16), tonumber(g,16), tonumber(b,16)
        if red == green and red == blue and red <= 85 then
            local value = red == 0 and 'e6' or 'a0'
            return '|c' .. alpha .. value .. value .. value
        end
        return '|c' .. alpha .. r .. g .. b
    end))
end

local function refreshText(font)
    local record = module.text[font]
    if not record or record.changing then return end
    local active
    for root, style in pairs(record.styles) do
        if within(font, root) then active = style; break end
    end
    local color = record.nativeColor
    record.changing = true
    if color and number(color[1]) and number(color[2]) and number(color[3]) then
        if active and pageInk(color[1],color[2],color[3]) then
            font:SetTextColor(active[1],active[2],active[3],color[4])
        else
            font:SetTextColor(unpack(color))
        end
    end
    local current = font:GetText()
    if public(current) and (not public(record.paintedText) or current ~= record.paintedText) then record.nativeText = current end
    local text = active and inlineInk(record.nativeText) or record.nativeText
    if public(current) and public(text) and current ~= text then font:SetText(text) end
    record.paintedText = text
    record.changing = nil
end

local function watchText(font, root, r, g, b)
    if not font or not font.GetTextColor or not font.SetTextColor or not font.GetText then return end
    local record = module.text[font]
    if not record then
        record = { nativeColor = {font:GetTextColor()}, nativeText = font:GetText(), styles = {} }
        module.text[font] = record
        hooksecurefunc(font, 'SetTextColor', function(self, ...)
            local saved = module.text[self]
            if saved.changing then return end
            saved.nativeColor = {...}
            refreshText(self)
        end)
        hooksecurefunc(font, 'SetFontObject', function(self)
            local saved = module.text[self]
            if saved.changing then return end
            saved.nativeColor = {self:GetTextColor()}
            refreshText(self)
        end)
        hooksecurefunc(font, 'SetText', refreshText)
        hooksecurefunc(font, 'SetFormattedText', refreshText)
        hooksecurefunc(font, 'SetParent', refreshText)
    end
    record.styles[root] = { r or .93, g or .93, b or .93 }
    refreshText(font)
end

local function watchButton(button, root)
    if not button then return end
    local font = button.GetFontString and button:GetFontString()
    watchText(font, root)
    if font and not module.hooks[button] then
        module.hooks[button] = true
        -- Button's C-side text setters need not call the FontString Lua method.
        hooksecurefunc(button, 'SetText', function() refreshText(font) end)
        hooksecurefunc(button, 'SetFormattedText', function() refreshText(font) end)
    end
end

local function rootFill(root)
    module:Fill(root)
    suppress(root.Bg) -- exact UI-Background-Rock texture from the native template
end

function module:SpellBook()
    local root = PlayerSpellsFrame
    local book = root and root.SpellBookFrame
    if not book then return end
    if InCombatLockdown() then self.pending = true; return end
    rootFill(root)
    for _, key in ipairs({'BookBGHalved','BookBGLeft','BookBGRight','BookCornerFlipbook','Bookmark'}) do suppress(book[key]) end
    local pages = book.PagedSpellsFrame
    if pages and pages.EnumerateFrames then
        for _, row in pages:EnumerateFrames() do
            if row.Button then ns.NativeControlSkins:Icon(row.Button) end
            watchText(row.Text, root, 1,.82,.2) -- pooled book section header
            watchText(row.Name, root)
            watchText(row.SubName, root, .72,.75,.78)
            watchText(row.RequiredLevel, root)
            if ns.NativeText then
                ns.NativeText:Header(row.Text)
                ns.NativeText:Frame(row)
            end
            if row.Text then
                suppress(row.Backplate)
                if row.Border and row.Border:GetAtlas() == "spellbook-divider" then ns.DarkSkin:TintChrome(row.Border) end
            elseif row.Backplate and row.Backplate:GetAtlas() == 'spellbook-item-backplate' then
                -- Native resting/hover alpha belongs to the row. Replace only
                -- the pale paper bitmap, retaining those state transitions.
                local alpha = row.Backplate:GetAlpha()
                row.Backplate:SetColorTexture(GREY, GREY, GREY, ALPHA)
                row.Backplate:SetAlpha(alpha)
            end
        end
        local controls = pages.PagingControls
        watchText(controls and controls.PageText, root)
    end
    if not self.roots[book] then
        self.roots[book] = true
        book:HookScript('OnShow', function() self:SpellBook() end)
        hooksecurefunc(book, 'SetMinimized', function() self:SpellBook() end)
        hooksecurefunc(book, 'UpdateDisplayedSpells', function() self:SpellBook() end)
    end
end

local materials = {'Bg','MaterialTopLeft','MaterialTopRight','MaterialBotLeft','MaterialBotRight','SealMaterialBG'}
local questPanels = {'QuestFrameDetailPanel','QuestFrameGreetingPanel','QuestFrameProgressPanel','QuestFrameRewardPanel'}
local questBody = {'QuestInfoDescriptionText','QuestInfoObjectivesText','QuestInfoGroupSize','QuestInfoRewardText',
    'QuestInfoTimerText','QuestInfoQuestType','QuestInfoSpellObjectiveLearnLabel','QuestInfoRequiredMoneyText',
    'QuestProgressText','QuestProgressRequiredMoneyText','GreetingText'}
local questTitles = {'QuestInfoTitleHeader','QuestInfoDescriptionHeader','QuestInfoObjectivesHeader',
    'QuestProgressTitleText','QuestProgressRequiredItemsText','CurrentQuestsText','AvailableQuestsText'}

function module:Quest()
    local root = QuestFrame
    if not root then return end
    if InCombatLockdown() then self.pending = true; return end
    rootFill(root)
    for _, name in ipairs(questPanels) do
        local panel = _G[name]
        if panel then for _, key in ipairs(materials) do suppress(panel[key]) end end
    end
    for _, name in ipairs(questBody) do watchText(_G[name], root) end
    for _, name in ipairs(questTitles) do watchText(_G[name], root, 1,.82,.2) end
    local objectives = QuestInfoObjectivesFrame and QuestInfoObjectivesFrame.Objectives
    for _, font in ipairs(objectives or {}) do watchText(font, root) end
    local rewards = QuestInfoRewardsFrame
    if rewards then
        watchText(rewards.Header, root, 1,.82,.2)
        for _, key in ipairs({'ItemChooseText','ItemReceiveText','PlayerTitleText','QuestSessionBonusReward'}) do watchText(rewards[key], root) end
        watchText(rewards.XPFrame and rewards.XPFrame.ReceiveText, root)
        for _, item in ipairs(rewards.RewardButtons or {}) do watchText(item.Name, root) end
        for _, key in ipairs({'HonorFrame','ArtifactXPFrame','TitleFrame','SkillPointFrame'}) do
            watchText(rewards[key] and rewards[key].Name, root)
        end
    end
    for i = 1, MAX_REQUIRED_ITEMS or 6 do watchText(_G['QuestProgressItem' .. i .. 'Name'], root) end
    local greeting = QuestFrameGreetingPanel
    if greeting and greeting.titleButtonPool then
        for button in greeting.titleButtonPool:EnumerateActive() do watchButton(button, root) end
    end
    -- QuestInfo shares individual fonts/frames with the map. Restore their exact
    -- requested native colors/text whenever their parent is outside this root.
    for font, record in pairs(self.text) do if record.styles[root] then refreshText(font) end end
    if not self.roots[root] then
        self.roots[root] = true
        root:HookScript('OnShow', function() self:Quest() end)
    end
end

-- QuestMap detail art is independent of the already-dark quest-list page.
-- Expose WorldMap's single chat-matched fill; do not stack a second underlay.
function module:MapQuest()
    local quests = QuestMapFrame and QuestMapFrame.QuestsFrame
    local root = quests and quests.DetailsFrame
    if not root then return end
    if InCombatLockdown() then self.pending = true; return end
    suppress(root.Bg)
    suppress(root.SealMaterialBG)
    local trim = root.BorderFrame
    if trim then suppress(trim.Border); suppress(trim.TopDetail) end
    local back = root.BackFrame
    if back then
        -- This exact native host owns only its anonymous decorative header
        -- Texture; BackButton and AccountCompletedNotice are separate children.
        -- The live client's atlas identity can differ from the extracted XML.
        for _, region in ipairs({back:GetRegions()}) do
            suppress(region)
        end
    end
    local container = root.RewardsFrameContainer
    local rewards = container and container.RewardsFrame
    if rewards then
        for _, key in ipairs({'Top','Bottom','Background'}) do suppress(rewards[key]) end
    end
    ns.DarkSkin:Panel(root, 'inner', 0)
    for _, name in ipairs(questBody) do watchText(_G[name], root) end
    for _, name in ipairs(questTitles) do watchText(_G[name], root, 1,.82,.2) end
    local objectives = QuestInfoObjectivesFrame and QuestInfoObjectivesFrame.Objectives
    for _, font in ipairs(objectives or {}) do watchText(font, root) end
    -- Only explanatory reward labels; item names, quality colors, icons, money
    -- and the native reward/action controls retain their original presentation.
    local info = MapQuestInfoRewardsFrame
    if info then
        for _, key in ipairs({'ItemChooseText','ItemReceiveText','PlayerTitleText','QuestSessionBonusReward'}) do
            watchText(info[key], root)
        end
    end
    if not self.roots[root] then
        self.roots[root] = true
        root:HookScript('OnShow', function() self:MapQuest() end)
    end
end

function module:Gossip()
    local root = GossipFrame
    if not root then return end
    if InCombatLockdown() then self.pending = true; return end
    rootFill(root)
    suppress(root.Background)
    local panel = root.GreetingPanel
    if panel then
        for _, key in ipairs(materials) do
            suppress(panel[key])
            local name = panel:GetName()
            if name then suppress(_G[name .. key]) end
        end
        local box = panel.ScrollBox
        if box and box.ForEachFrame then
            box:ForEachFrame(function(row)
                watchText(row.GreetingText, root)
                watchButton(row, root)
            end)
            if not self.hooks[box] then
                self.hooks[box] = true
                hooksecurefunc(box, 'Update', function() self:Gossip() end)
            end
        end
    end
    if not self.roots[root] then
        self.roots[root] = true
        root:HookScript('OnShow', function() self:Gossip() end)
        hooksecurefunc(root, 'Update', function() self:Gossip() end)
    end
end

local function hookGlobal(name, callback)
    if type(_G[name]) == 'function' and not module.hooks[name] then
        module.hooks[name] = true
        hooksecurefunc(name, callback)
    end
end

function module:Install()
    if InCombatLockdown() then self.pending = true; return end
    self.pending = nil
    self:SpellBook(); self:Quest(); self:MapQuest(); self:Gossip()
    -- The map tiles retain their native ownership. Both quest-page backgrounds
    -- expose the enclosing window's single fill.
    local quests = QuestMapFrame and QuestMapFrame.QuestsFrame
    local scroll = quests and quests.ScrollFrame
    suppress(scroll and scroll.Background)
    for _, name in ipairs({'QuestInfo_Display','QuestInfo_ShowObjectives','QuestInfo_ShowRewards',
        'QuestFrame_SetMaterial','QuestFrameProgressItems_Update','QuestFrameGreetingPanel_OnShow'}) do
        hookGlobal(name, function()
            self:Quest(); self:MapQuest()
            -- QuestInfo_Display reparents shared element containers AFTER its
            -- text setters. Re-evaluate all watched fonts after that move,
            -- restoring native bytes/colors for any unthemed consumer.
            for font in pairs(self.text) do refreshText(font) end
        end)
    end
    hookGlobal('QuestMapFrame_ShowQuestDetails', function() self:MapQuest() end)
end

if EventRegistry then
    EventRegistry:RegisterCallback('PlayerSpellsFrame.SpellBookFrame.DisplayedSpellsChanged', function() module:SpellBook() end, module)
end
local events = CreateFrame('Frame')
for _, event in ipairs({'PLAYER_LOGIN','ADDON_LOADED','PLAYER_REGEN_ENABLED'}) do events:RegisterEvent(event) end
events:SetScript('OnEvent', function(_, event, addon)
    if event == 'PLAYER_LOGIN' or event == 'PLAYER_REGEN_ENABLED' and module.pending
        or event == 'ADDON_LOADED' and (addon == 'Blizzard_PlayerSpells' or addon == 'Blizzard_UIPanels_Game') then
        module:Install()
    end
end)
