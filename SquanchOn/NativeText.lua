-- SPDX-License-Identifier: MIT
-- Native owners keep font faces, flags and layout; quest body text has a brighter neutral color.
local _, ns = ...
local Text = { records = setmetatable({}, {__mode = 'k'}), headers = setmetatable({}, {__mode = 'k'}), hooked = setmetatable({}, {__mode = 'k'}) }
ns.NativeText = Text
local titleNames = { 'QuestInfoTitleHeader', 'QuestInfoDescriptionHeader', 'QuestInfoObjectivesHeader',
    'QuestProgressTitleText', 'QuestProgressRequiredItemsText', 'CurrentQuestsText', 'AvailableQuestsText' }
local function public(value) return not (issecretvalue and issecretvalue(value)) end
local questColorHooks = setmetatable({}, {__mode = 'k'})
local function brightenQuestBody(region, r, g, b, a)
    local row = region:GetParent()
    local block = row and row.parentBlock
    if not block or block.parentModule ~= QuestObjectiveTracker then return end
    -- Lift only ordinary gray text; native hover, completion and failure colors stay meaningful.
    if public(r) and public(g) and public(b) and type(r) == 'number'
        and type(g) == 'number' and type(b) == 'number'
        and math.abs(r-.8) < .001 and math.abs(g-.8) < .001 and math.abs(b-.8) < .001 then
        region:SetTextColor(.94, .94, .94, a or 1)
    end
end
local function safe(region)
    if not public(region) or type(region) ~= 'table' and type(region) ~= 'userdata' then return false end
    return region and region.GetFont and region.SetFont and not (region.IsForbidden and region:IsForbidden())
end
local function font(region)
    local ok, path, size, flags = pcall(region.GetFont, region)
    if ok and public(path) and public(size) and public(flags) and type(path) == 'string' and type(size) == 'number' then
        return path, size, flags
    end
end
local function characterRegion(region)
    if not CharacterFrame then return false end
    local parent = region
    for _ = 1, 32 do
        if parent == CharacterFrame then return true end
        parent = parent and parent.GetParent and parent:GetParent()
        if not parent then return false end
    end
    return false
end
local function refresh(region)
    local record = Text.records[region]
    if not record or record.busy or not safe(region) then return end
    local path, size, flags = font(region)
    if not path then return end
    local wanted = record.size or (Text.headers[region] and 12 or 8)
    record.character = characterRegion(region)
    local scaleOwner = region.GetEffectiveScale and region or region.GetParent and region:GetParent()
    if record.character and scaleOwner and scaleOwner.GetEffectiveScale and UIParent then
        local scale = scaleOwner:GetEffectiveScale()
        local uiScale = UIParent:GetEffectiveScale()
        if public(scale) and public(uiScale) and type(scale) == 'number'
            and type(uiScale) == 'number' and scale > 0 and uiScale > 0 then
            -- Keep body/headings readable after proportional window scaling.
            wanted = (Text.headers[region] and 10 or math.max(record.size or 8, 8)) * uiScale / scale
        end
    end
    if size == wanted then return end
    record.busy = true
    pcall(region.SetFont, region, path, wanted, flags)
    record.busy = nil
end
local function queueCharacterRefresh()
    if Text.characterRefreshQueued then return end
    Text.characterRefreshQueued = true
    C_Timer.After(0, function()
        Text.characterRefreshQueued = nil
        for region, record in pairs(Text.records) do
            if record.character or characterRegion(region) then refresh(region) end
        end
    end)
end
local parentHooks = setmetatable({}, {__mode = 'k'})
function Text:Region(region, header, size)
    if not safe(region) then return end
    if header then self.headers[region] = true end
    local record = self.records[region]
    if not record then
        local path, size = font(region)
        if not path then return end
        record = { nativeSize = size }
        self.records[region] = record
        hooksecurefunc(region, 'SetFont', function(self, _, requested)
            local saved = Text.records[self]
            if saved.busy then return end
            if public(requested) and type(requested) == 'number' then saved.nativeSize = requested end
            refresh(self)
        end)
        if region.SetFontObject then
            hooksecurefunc(region, 'SetFontObject', function(self)
                local saved = Text.records[self]
                if saved.busy then return end
                local _, size = font(self)
                if size then saved.nativeSize = size end
                refresh(self)
            end)
        end
        if region.SetParent then hooksecurefunc(region, 'SetParent', refresh) end
    end
    if size then record.size=size end
    refresh(region)
end
function Text:Header(region, size)
    self:Region(region, true, size)
end
function Text:Frame(frame)
    if not frame or frame.IsForbidden and frame:IsForbidden() then return end
    if frame == CharacterFrame and not self.characterScaleHooked then
        self.characterScaleHooked = true
        hooksecurefunc(frame, 'SetScale', queueCharacterRefresh)
    end
    if frame.SetParent and characterRegion(frame) and not parentHooks[frame] then
        parentHooks[frame] = true
        local wasCharacter = characterRegion(frame)
        hooksecurefunc(frame, 'SetParent', function()
            local isCharacter = characterRegion(frame)
            if wasCharacter or isCharacter then queueCharacterRefresh() end
            wasCharacter = isCharacter
        end)
    end
    -- Explicit references protect headings even when they use body font objects.
    for _, key in ipairs({'Title', 'title', 'TitleText', 'HeaderText'}) do self:Header(frame[key]) end
    local title = frame.TitleContainer
    if title then self:Header(title.TitleText) end
    local header = frame.Header
    if type(header) == 'table' or type(header) == 'userdata' then
        self:Header(header); self:Header(header.Text); self:Header(header.Title)
    end
    for _, name in ipairs(titleNames) do self:Header(_G[name]) end
    for _, poolName in ipairs({'spellHeaderPool'}) do
        local pool = frame[poolName]
        if pool and pool.EnumerateActive then
            local count = 0
            for region in pool:EnumerateActive() do
                count = count + 1; if count > 128 then break end
                self:Header(region)
            end
        end
    end
    if frame.GetObjectType and frame:GetObjectType() == 'EditBox' then self:Region(frame) end
    if frame.GetRegions then
        local count = 0
        for _, region in ipairs({frame:GetRegions()}) do
            count = count + 1; if count > 128 then break end
            if region.IsObjectType and region:IsObjectType('FontString') then self:Region(region) end
        end
    end
end
function Text:Block(block)
    if not block then return end
    local quest = block.parentModule == QuestObjectiveTracker
    self:Header(block.HeaderText,quest and 8 or 9)
    if quest and block.HeaderText then
        block.HeaderText:SetWordWrap(true)
        block.HeaderText:SetNonSpaceWrap(true)
    end
    if self.hooked[block] then return end
    self.hooked[block] = true
    local function line(owner, key)
        local row = owner.usedLines and owner.usedLines[key]
        if row then
            local quest = owner.parentModule == QuestObjectiveTracker
            Text:Region(row.Text,false,quest and 7 or 8); Text:Region(row.Dash,false,quest and 7 or 8)
            if quest then
                for _, region in ipairs({row.Text, row.Dash}) do
                    if not questColorHooks[region] then
                        questColorHooks[region] = true
                        hooksecurefunc(region, 'SetTextColor', brightenQuestBody)
                    end
                    brightenQuestBody(region, region:GetTextColor())
                end
            end
            if quest and row.Text then
                -- GetLine runs before AddObjective sets and measures the text.
                -- Keep the native dash gutter and right-edge/item reservation.
                row.Text:SetWordWrap(true)
                row.Text:SetNonSpaceWrap(true)
                row.Text:ClearAllPoints()
                row.Text:SetPoint('TOP',row,'TOP',0,0)
                if row.Dash then row.Text:SetPoint('LEFT',row.Dash,'RIGHT',0,0)
                else row.Text:SetPoint('LEFT',row,'LEFT',0,0) end
                row.Text:SetPoint('RIGHT',row,'RIGHT',0,0)
            end
        end
    end
    if block.GetLine then hooksecurefunc(block, 'GetLine', line) end
    local count = 0
    for key in pairs(block.usedLines or {}) do
        count = count + 1; if count > 128 then break end
        line(block, key)
    end
end
function Text:Tracker(tracker)
    if not tracker then return end
    self:Header(tracker.Header and tracker.Header.Text)
    for index, module in ipairs(tracker.modules or {}) do
        if index > 32 then break end
        self:Header(module.Header and module.Header.Text,module == QuestObjectiveTracker and 8 or 12)
        if module.GetBlock and module.GetExistingBlock and not self.hooked[module] then
            self.hooked[module] = true
            hooksecurefunc(module, 'GetBlock', function(owner, id, template)
                Text:Block(owner:GetExistingBlock(id, template))
            end)
        end
        local count = 0
        for _, blocks in pairs(module.usedBlocks or {}) do
            for _, block in pairs(blocks) do
                count = count + 1; if count > 128 then break end
                self:Block(block)
            end
            if count > 128 then break end
        end
    end
end

-- Blizzard_Menu lends FontString proxies that forbid even looking up SetFont.
-- Its supported SetFontObject lane keeps the compositor's pool reset intact.
local menuFonts, menuSources, menuFontCount = {}, {}, 0
function Text:Menu(menu)
    for index, row in ipairs({menu:GetChildren()}) do
        if index > 128 then break end
        local region = row.fontString or row.Text
        if region and region.GetFontObject then
            local original = region:GetFontObject()
            original = menuSources[original] or original
            local size = row:GetObjectType() == "Frame" and 12 or 8
            local bySize = menuFonts[original]
            if original then
                if not bySize then bySize={};menuFonts[original]=bySize end
                if not bySize[size] then
                    menuFontCount=menuFontCount+1
                    local clone=CreateFont("SquancherMenuText"..menuFontCount)
                    clone:CopyFontObject(original)
                    local file,_,flags=clone:GetFont()
                    clone:SetFont(file,size,flags)
                    bySize[size]=clone
                    menuSources[clone]=original
                end
                region:SetFontObject(bySize[size])
            end
        end
    end
end
