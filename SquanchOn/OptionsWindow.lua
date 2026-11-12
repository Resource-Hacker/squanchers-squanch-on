-- SPDX-License-Identifier: MIT
-- The one settings window. It draws whatever Options.lua has registered: a
-- category tree with search on the left, the selected page on the right, and
-- a footer with Undo and Reset. Frames are built on first open and pooled.
--
-- Saved state (one key): ns.db.optionsWindow = {
--   point = { point, relativePoint, x, y },   -- where the window was dragged
--   category = 'general',                     -- last page
--   collapsed = { ['category:Section'] = true },
-- }
local _, ns = ...
local Window = { expanded = {}, counts = {}, results = {}, session = { collapsed = {} } }
ns.OptionsWindow = Window

local WIDTH, HEIGHT, PAD = 560, 420, 12
local TOP, BOTTOM = 36, 40              -- title strip and footer, measured from the frame edges
local LEFT_W = 136                      -- category column
local CONTENT_X = PAD + LEFT_W + 12     -- 160
local CONTENT_W = WIDTH - CONTENT_X - PAD - 10   -- 378; 10 is the scroll marker's lane
-- Raised buttons and dropdowns are 20 high and their rim's corner diamonds
-- reach 3 beyond that, so rows are 26 apart.
local ROW, TREE_ROW = 26, 16
local INDENT, LABEL_W, CONTROL_X, CONTROL_W = 8, 150, 166, 176
local NAME = 'SquanchOnOptions'
local VALUELESS = { action = true, note = true }
local GREY = { 0.62, 0.62, 0.6 }
local BODY_TEXT = ns.DarkSkin.bodyTextColor -- live theme table
local WARN = { 1, 0.6, 0.3 }

local function widgets() return ns.OptionWidgets end
local function registry() return ns.Options end
local function saved()
    local db = ns.db
    if not db then return Window.session end
    if type(db.optionsWindow) ~= 'table' then db.optionsWindow = {} end
    if type(db.optionsWindow.collapsed) ~= 'table' then db.optionsWindow.collapsed = {} end
    return db.optionsWindow
end

-- Pools: frames are created once per kind and reused on every redraw.
local function newPool()
    local pool = { kinds = {} }
    function pool:Acquire(kind, create)
        local list = self.kinds[kind]
        if not list then list = { used = 0 }; self.kinds[kind] = list end
        list.used = list.used + 1
        local item = list[list.used]
        if not item then item = create(); list[list.used] = item end
        return item
    end
    function pool:Release()
        for _, list in pairs(self.kinds) do
            for index = 1, list.used do list[index]:Hide() end
            list.used = 0
        end
    end
    return pool
end

-- Status line ----------------------------------------------------------
function Window:Status(text, problem)
    self.statusText, self.statusProblem = text or '', problem and true or false
    self.dirty = true
end

-- Row behaviour ----------------------------------------------------------
local function rowOf(control) return control.row end
local function enter(control)
    local row = rowOf(control)
    if not row or not row.option then return end
    row.hover:Show()
    if row.option.section then Window.activeSection = row.option.section end
    if row.option.type ~= 'note' then
        widgets():Describe(row, row.option, row.ctx, row.unavailable and 'Unavailable right now.' or nil)
    end
end
local function leave(control)
    local row = rowOf(control)
    if not row then return end
    if not row:IsMouseOver() then row.hover:Hide() end
    widgets():HideDescription(row)
end
local function hookHover(control)
    control:HookScript('OnEnter', enter); control:HookScript('OnLeave', leave)
end

function Window:Commit(option, ctx, value)
    local ok, message = registry():Set(option.id, value, ctx)
    if not ok then self:Status(message, true)
    elseif message == 'queued' then self:Status(option.label .. ' is queued until combat ends.')
    elseif option.requiresReload then self:Status(option.label .. ' takes effect after a reload.')
    else self:Status('') end
    if option.section then self.activeSection = option.section end
    self.dirty = true
end
local function commit(control, value)
    local row = rowOf(control)
    if row and row.option then Window:Commit(row.option, row.ctx, value) end
end

local function createRow()
    local row = CreateFrame('Button', nil, Window.body)
    row:SetSize(CONTENT_W, ROW)
    row.row = row
    row.hover = row:CreateTexture(nil, 'BACKGROUND'); row.hover:SetAllPoints(); row.hover:SetColorTexture(1, .78, .42, .05); row.hover:Hide()
    row.label = widgets():Label(row, '', 8); row.label:SetPoint('TOPLEFT', INDENT, 0)
    row.label:SetSize(LABEL_W, ROW); row.label:SetWordWrap(false); row.label:SetJustifyV('MIDDLE')
    row.tag = widgets():Label(row, '', 8); row.tag:SetPoint('TOPRIGHT', -2, 0); row.tag:SetHeight(ROW)
    row.tag:SetJustifyH('RIGHT'); row.tag:SetJustifyV('MIDDLE')
    row:RegisterForClicks('RightButtonUp')
    row:SetScript('OnEnter', enter); row:SetScript('OnLeave', leave)
    row:SetScript('OnClick', function(self)
        local option = self.option
        if not option or VALUELESS[option.type] or self.unavailable then return end
        local ok, message = registry():Reset(option.id, self.ctx)
        if not ok then Window:Status(message, true)
        elseif message == 'queued' then Window:Status(option.label .. ' reset is queued until combat ends.')
        else Window:Status(option.label .. ' reset to its default.') end
    end)
    return row
end
-- Attach a pooled control to its row in the control column (or full width below the label).
local function attach(control, row, below)
    control.row = row
    control:SetParent(row); control:ClearAllPoints()
    if below then control:SetPoint('TOPLEFT', row, 'TOPLEFT', INDENT, -ROW)
    else control:SetPoint('LEFT', row, 'TOPLEFT', CONTROL_X, -ROW / 2) end
    control:Show()
    return control
end

local factories = {}
function factories.toggle()
    local control = widgets():Check(Window.body)
    control:SetSize(14, 14)
    control:SetScript('OnClick', function(self) commit(self, self:GetChecked() == true) end)
    function control:SetDisabled(disabled)
        if disabled then self:Disable() else self:Enable() end
        self:SetAlpha(disabled and 0.4 or 1)
    end
    hookHover(control)
    return control
end
function factories.slider()
    local control = widgets():Slider(Window.body, CONTROL_W)
    control.onEnter, control.onLeave = enter, leave
    control.onPreview = function(self, value)
        local row = rowOf(self)
        if row and row.option and row.option.drag then registry():Preview(row.option.id, value, row.ctx) end
    end
    control.onCommit = commit
    hookHover(control.edit); control.edit.row = nil
    return control
end
function factories.number()
    local control = widgets():ValueEdit(Window.body, 60)
    control:SetJustifyH('RIGHT')
    control.onCommit = function(self, text)
        local row = rowOf(self)
        if not row or not row.option then return end
        text = text:gsub('^%s+', ''):gsub('%s+$', ''):gsub(',', '.')
        if text == '' and row.option.allowEmpty then commit(self, nil); return end
        local value = tonumber(text)
        if value then commit(self, value) else Window:Status('Enter a number for ' .. row.option.label .. '.', true) end
    end
    hookHover(control)
    return control
end
function factories.text()
    local control = widgets():ValueEdit(Window.body, CONTROL_W)
    control.onCommit = function(self, text)
        local row = rowOf(self)
        if row and row.option and text == '' and row.option.allowEmpty then commit(self, nil) else commit(self, text) end
    end
    hookHover(control)
    return control
end
function factories.choice()
    local control = widgets():Dropdown(Window.body, CONTROL_W)
    function control:getItems()
        local row, items = rowOf(self), {}
        if not row or not row.option then return items end
        local option = row.option
        if option.allowEmpty then items[#items + 1] = { label = option.emptyLabel or '(inherit)' } end
        for _, value in ipairs((registry():Choices(option, row.ctx))) do
            items[#items + 1] = { value = value, label = registry():ChoiceLabel(option, row.ctx, value) }
        end
        return items
    end
    control.onCommit = commit
    hookHover(control)
    return control
end
local function mediaFactory(kind)
    return function()
        local control = widgets():MediaPicker(Window.body, kind, CONTROL_W)
        control.onCommit = commit
        hookHover(control)
        return control
    end
end
factories.font, factories.statusbar, factories.border = mediaFactory('font'), mediaFactory('statusbar'), mediaFactory('border')
function factories.color()
    local control = widgets():Swatch(Window.body)
    -- The picker outlives a redraw, so it keeps its own option and context.
    control.onOpen = function(self)
        local row = rowOf(self)
        if not row or not row.option then return end
        self.pickOption, self.pickCtx = row.option, registry().Copy(row.ctx)
        Window.picking = self
    end
    control.onPreview = function(self, color)
        if self.pickOption then registry():Preview(self.pickOption.id, color, self.pickCtx) end
    end
    control.onCommit = function(self, color)
        if self.pickOption then Window:Commit(self.pickOption, self.pickCtx, color) end
    end
    control.onCancel = function(self)
        if self.pickOption then registry():CancelPreview(self.pickOption.id, self.pickCtx) end
    end
    control.onClose = function(self)
        self.pickOption, self.pickCtx = nil, nil
        if Window.picking == self then Window.picking = nil end
        Window.dirty = true
    end
    hookHover(control)
    return control
end
function factories.action()
    local control = widgets():SmallButton(Window.body, '', CONTROL_W, function(self)
        local row = rowOf(self)
        local option = row and row.option
        if not option then return end
        if option.confirm and Window.confirming ~= option.id then
            Window.confirming = option.id
            Window:Status(option.confirm, true)
            if C_Timer and C_Timer.After then
                C_Timer.After(4, function()
                    if Window.confirming == option.id then Window.confirming = nil; Window:Status('') end
                end)
            end
            return
        end
        Window.confirming = nil
        local ok, message = registry():Run(option.id, row.ctx)
        Window:Status(message or (ok and (option.label .. ': done.') or ''), not ok)
    end)
    hookHover(control)
    return control
end
function factories.note()
    local label = widgets():Label(Window.body, '', 8, GREY[1], GREY[2], GREY[3])
    label:SetWidth(CONTENT_W - INDENT * 2); label:SetWordWrap(true); label:SetJustifyV('TOP')
    if label.SetSpacing then label:SetSpacing(2) end
    return label
end
function factories.curve()
    local control = widgets():Curve(Window.body, CONTENT_W - INDENT * 2)
    control.onCommit = commit
    return control
end
function factories.list()
    local control = widgets():ListEditor(Window.body, CONTENT_W - INDENT * 2)
    local function change(self, callback, argument)
        local row = rowOf(self)
        local option = row and row.option
        if not option then return end
        if not option.combatSafe and InCombatLockdown() and option.items then
            Window:Status(option.label .. ' can be edited after combat.', true); return
        end
        if option.items then
            local handler = option[callback]
            if handler then
                local ok, result, reason = pcall(handler, row.ctx, argument)
                if not ok or result == false then Window:Status(tostring((not ok and result) or reason or 'Not accepted.'), true) end
                registry():Fire(option.id, row.ctx, 'list')
            end
            return
        end
        -- A plain array value: edit a copy and commit it as one undoable change.
        local list = registry():Read(option, row.ctx)
        if type(list) ~= 'table' then list = {} end
        if callback == 'add' then
            local value = argument
            if option.numeric then value = tonumber(argument) end
            if value == nil then Window:Status('Enter a number for ' .. option.label .. '.', true); return end
            list[#list + 1] = value
        else
            table.remove(list, argument)
        end
        commit(self, list)
    end
    control.onAdd = function(self, text) change(self, 'add', text) end
    control.onRemove = function(self, key) change(self, 'remove', key) end
    return control
end

-- Each drawer binds a pooled control to the row and returns the row height.
local drawers = {}
function drawers.toggle(row, option, _, value, disabled)
    local control = attach(Window.pool:Acquire('toggle', factories.toggle), row)
    control:SetChecked(value == true); control:SetDisabled(disabled)
end
function drawers.slider(row, option, _, value, disabled)
    local control = attach(Window.pool:Acquire('slider', factories.slider), row)
    control.edit.row = row
    control:Configure(option); control:SetValue(value); control:SetDisabled(disabled)
end
function drawers.number(row, option, _, value, disabled)
    local control = attach(Window.pool:Acquire('number', factories.number), row)
    control:SetStored(type(value) == 'number' and tostring(tonumber(string.format('%.4f', value))) or '')
    control:SetDisabled(disabled)
end
function drawers.text(row, option, _, value, disabled)
    local control = attach(Window.pool:Acquire('text', factories.text), row, option.wide)
    control:SetWidth(option.wide and CONTENT_W - INDENT * 2 or CONTROL_W)
    if control.SetMaxLetters then control:SetMaxLetters(option.maxLetters or 0) end
    control:SetStored(type(value) == 'string' and value or ''); control:SetDisabled(disabled)
    return option.wide and ROW * 2 or ROW
end
function drawers.choice(row, option, ctx, value, disabled)
    local control = attach(Window.pool:Acquire('choice', factories.choice), row)
    control:SetValue(value, registry():ChoiceLabel(option, ctx, value)); control:SetDisabled(disabled)
end
local function media(row, option, _, value, disabled)
    local kind = option.type
    local control = attach(Window.pool:Acquire('media:' .. kind, factories[kind]), row)
    control.allowEmpty, control.emptyLabel = option.allowEmpty, option.emptyLabel
    local missing = type(value) == 'string' and ns.Media and ns.Media.missing and ns.Media.missing[kind .. ':' .. value]
    control:SetValue(value, value == nil and (option.emptyLabel or '(inherit)') or nil, missing and true or false)
    control:SetDisabled(disabled)
end
drawers.font, drawers.statusbar, drawers.border = media, media, media
function drawers.color(row, option, _, value, disabled)
    local control = attach(Window.pool:Acquire('color', factories.color), row)
    if not control.pickOption then control:SetValue(type(value) == 'table' and value or nil, option.hasAlpha) end
    control:SetDisabled(disabled)
end
function drawers.action(row, option, _, _, disabled)
    local control = attach(Window.pool:Acquire('action', factories.action), row)
    control:SetText(Window.confirming == option.id and 'Click again to confirm' or option.button or 'Run')
    control:SetDisabled(disabled)
end
function drawers.note(row, option, ctx)
    local label = Window.pool:Acquire('note', factories.note)
    local text = option.text
    if type(text) == 'function' then text = text(ctx) end
    label:SetParent(row); label:ClearAllPoints(); label:SetPoint('TOPLEFT', row, 'TOPLEFT', INDENT, -4)
    label:SetText(text or option.label or ''); label:Show()
    row.label:SetText('')
    return math.max(ROW, math.ceil(label:GetStringHeight()) + 8)
end
function drawers.curve(row, option, _, value, disabled)
    local control = attach(Window.pool:Acquire('curve', factories.curve), row, true)
    control:SetDisabled(disabled); control:SetValue(value, option)
    return ROW + control:GetHeight() + 4
end
function drawers.list(row, option, ctx, value, disabled)
    local control = attach(Window.pool:Acquire('list', factories.list), row, true)
    local items
    if option.items then
        local ok, result = pcall(option.items, ctx)
        items = ok and result or {}
    else
        items = {}
        for index, entry in ipairs(type(value) == 'table' and value or {}) do items[index] = { key = index, label = tostring(entry) } end
    end
    control:SetDisabled(disabled); control:SetItems(items)
    return ROW + control:GetHeight() + 4
end

function Window:DrawRow(option, ctx, y)
    local options = registry()
    local row = self.pool:Acquire('row', createRow)
    row.option, row.ctx = option, ctx
    row:ClearAllPoints(); row:SetPoint('TOPLEFT', self.body, 'TOPLEFT', 0, -y)
    row.hover:Hide()
    local disabled = option.disabled and option.disabled(ctx) and true or false
    row.unavailable = disabled
    local value
    if not VALUELESS[option.type] then
        local queued, waiting = options:Queued(option.id, ctx)
        if queued then value = waiting
        else
            local ok, result = pcall(options.Read, options, option, ctx)
            if ok then value = result else disabled = true end
        end
        if queued then row.tag:SetText('queued'); row.tag:SetTextColor(WARN[1], WARN[2], WARN[3])
        elseif option.requiresReload then row.tag:SetText('reload'); row.tag:SetTextColor(GREY[1], GREY[2], GREY[3])
        elseif not option.combatSafe and InCombatLockdown() then row.tag:SetText('combat'); row.tag:SetTextColor(GREY[1], GREY[2], GREY[3])
        else row.tag:SetText('') end
    else
        row.tag:SetText('')
    end
    row.label:SetText(option.label)
    if disabled then row.label:SetTextColor(.45, .45, .43) else row.label:SetTextColor(BODY_TEXT[1], BODY_TEXT[2], BODY_TEXT[3]) end
    local height = drawers[option.type](row, option, ctx, value, disabled) or ROW
    row:SetHeight(height); row:Show()
    if option.id == self.flashId then self.flashRow, self.flashY = row, y end
    return height
end

-- Page -----------------------------------------------------------------
local function createSection()
    local header = widgets():Section(Window.body, CONTENT_W)
    header.onToggle = function(self)
        local collapsed = saved().collapsed
        collapsed[self.key] = not collapsed[self.key] or nil
        Window.dirty = true
    end
    header.onReset = function(self) Window:ResetSection(self.section) end
    return header
end
local function createSegmented()
    local control = widgets():Segmented(Window.body)
    control.onPick = function(self, index)
        local choice = Window.contextChoice[Window.category]
        choice[self.context.key] = self.context.values[index]
        Window:BuildContext()
        Window.dirty = true
    end
    return control
end

-- ctx = the category's fixed context plus the page selectors' current values.
-- One table per category, updated in place; the registry copies what it keeps.
function Window:BuildContext()
    local category = registry().categories[self.category]
    self.contexts = self.contexts or {}
    self.contextChoice = self.contextChoice or {}
    local ctx = self.contexts[self.category]
    if not ctx then ctx = {}; self.contexts[self.category] = ctx end
    local choice = self.contextChoice[self.category]
    if not choice then choice = {}; self.contextChoice[self.category] = choice end
    for key in pairs(ctx) do ctx[key] = nil end
    if category then
        for key, value in pairs(category.context or {}) do ctx[key] = value end
        for _, selector in ipairs(category.contexts or {}) do
            if choice[selector.key] == nil then choice[selector.key] = selector.values[1] end
            ctx[selector.key] = choice[selector.key]
        end
    end
    self.ctx = ctx
    return ctx
end

function Window:DrawPage()
    local options = registry()
    local category = options.categories[self.category]
    if not category then
        self.title:SetText('Squanch-On'); self.desc:SetText('No settings are registered yet.')
        return 40
    end
    local parent = category.parent and options.categories[category.parent]
    self.title:SetText(parent and (parent.title .. '  >  ' .. category.title) or category.title)
    self.desc:SetText(category.desc or '')
    local y = 16 + (category.desc and category.desc ~= '' and math.ceil(self.desc:GetStringHeight()) + 4 or 0) + 4
    local ctx = self.ctx or self:BuildContext()
    for _, selector in ipairs(category.contexts or {}) do
        local control = self.pool:Acquire('segmented', createSegmented)
        control.context = selector
        local selected = 1
        for index, value in ipairs(selector.values) do if value == ctx[selector.key] then selected = index end end
        control:SetOptions(selector.labels or selector.values, selected, math.min(80, math.floor((CONTENT_W - INDENT) / #selector.values)))
        control:ClearAllPoints(); control:SetPoint('TOPLEFT', self.body, 'TOPLEFT', INDENT, -y)
        control:Show()
        y = y + 28
    end
    if category.build then
        if category.page == nil then
            local ok, frame, height = pcall(category.build, self.body, CONTENT_W)
            if ok and frame then category.page, category.pageHeight = frame, height
            else category.page = false; category.pageError = not ok and tostring(frame) or 'The page returned no frame.' end
        end
        if category.page then
            local page = category.page
            page:SetParent(self.body); page:ClearAllPoints(); page:SetPoint('TOPLEFT', self.body, 'TOPLEFT', 0, -y)
            page:Show()
            self.customPage = page
            if category.refresh then pcall(category.refresh, page, ctx) end
            y = y + (category.pageHeight or page:GetHeight() or 0)
        else
            self.desc:SetText('This page could not be built: ' .. tostring(category.pageError))
            y = y + 24
        end
    end
    local collapsedState = saved().collapsed
    local section, header, collapsed = false, nil, false
    self.firstSection = nil
    for _, option in ipairs(options:Sorted(category.id)) do
        if not (option.hidden and option.hidden(ctx)) then
            local name = option.section or ''
            if name ~= section then
                section, header, collapsed = name, nil, false
                if name ~= '' then
                    self.firstSection = self.firstSection or name
                    local key = category.id .. ':' .. name
                    collapsed = collapsedState[key] and true or false
                    header = self.pool:Acquire('section', createSection)
                    header.key, header.section = key, name
                    header:ClearAllPoints(); header:SetPoint('TOPLEFT', self.body, 'TOPLEFT', 0, -(y + 4))
                    header:Set(name, collapsed, false); header:Show()
                    y = y + 26
                end
            end
            if header and not header.canReset and not VALUELESS[option.type] and options:HasDefault(option) then
                header.canReset = true
            end
            if not collapsed then y = y + self:DrawRow(option, ctx, y) end
        end
    end
    return y
end

-- Search results: a flat list grouped by category; a click opens the page
-- and flashes the row.
local function createResultHeader()
    local control = CreateFrame('Button', nil, Window.body)
    control:SetSize(CONTENT_W, 20)
    control.text = widgets():Label(control, '', 10, widgets().headerText[1], widgets().headerText[2], widgets().headerText[3]); control.text:SetPoint('LEFT', 0, 0)
    control:SetScript('OnEnter', function(self) self.text:SetTextColor(1, .85, .55) end)
    control:SetScript('OnLeave', function(self) self.text:SetTextColor(widgets().headerText[1], widgets().headerText[2], widgets().headerText[3], widgets().headerText[4]) end)
    control:SetScript('OnMouseDown', function(self) self.text:SetPoint('LEFT', 1, -1) end)
    control:SetScript('OnMouseUp', function(self) self.text:SetPoint('LEFT', 0, 0) end)
    control:SetScript('OnClick', function(self) Window:Jump(self.category) end)
    return control
end
local function createResult()
    local control = CreateFrame('Button', nil, Window.body)
    control:SetSize(CONTENT_W, 18)
    control:SetHighlightTexture([[Interface\Buttons\WHITE8X8]]); control:GetHighlightTexture():SetVertexColor(1, .78, .42, .10)
    control.text = widgets():Label(control, '', 8); control.text:SetPoint('LEFT', INDENT, 0); control.text:SetWidth(220); control.text:SetWordWrap(false)
    control.section = widgets():Label(control, '', 8, GREY[1], GREY[2], GREY[3]); control.section:SetPoint('RIGHT', -4, 0)
    control.section:SetWidth(130); control.section:SetJustifyH('RIGHT'); control.section:SetWordWrap(false)
    control:SetScript('OnMouseDown', function(self) self.text:SetPoint('LEFT', INDENT + 1, -1) end)
    control:SetScript('OnMouseUp', function(self) self.text:SetPoint('LEFT', INDENT, 0) end)
    control:SetScript('OnClick', function(self) Window:Jump(self.category, self.option) end)
    return control
end
function Window:DrawResults()
    local options = registry()
    local results = self.results
    self.title:SetText('Search')
    self.desc:SetText(#results == 0 and ('Nothing matches "' .. self.searchText .. '".')
        or (#results .. (#results == 1 and ' setting matches "' or ' settings match "') .. self.searchText .. '".'))
    local y, current = 36, nil
    for _, result in ipairs(results) do
        local category = result.category
        if category ~= current then
            current = category
            local header = self.pool:Acquire('resultHeader', createResultHeader)
            local parent = category.parent and options.categories[category.parent]
            header.category = category.id
            header.text:SetText(parent and (parent.title .. '  >  ' .. category.title) or category.title)
            header:ClearAllPoints(); header:SetPoint('TOPLEFT', self.body, 'TOPLEFT', 0, -(y + 4)); header:Show()
            y = y + 24
        end
        if result.option then
            local row = self.pool:Acquire('result', createResult)
            row.category, row.option = category.id, result.option.id
            row.text:SetText(result.option.label); row.section:SetText(result.option.section or '')
            row:ClearAllPoints(); row:SetPoint('TOPLEFT', self.body, 'TOPLEFT', 0, -y); row:Show()
            y = y + 18
        end
    end
    return y
end

function Window:Redraw()
    self.dirty = false
    self.pool:Release()
    if self.customPage then self.customPage:Hide(); self.customPage = nil end
    self.flashRow, self.flashY = nil, nil
    local y = self.searchText and self:DrawResults() or self:DrawPage()
    local height = y + 12
    self.body:SetSize(CONTENT_W, math.max(1, height))
    self.scroll:UpdateScrollChildRect()
    local range = math.max(0, height - self.scroll:GetHeight())
    local wanted = self.scroll:GetVerticalScroll()
    if self.scrollReset then wanted = 0 end
    if self.flashRow then
        wanted = math.max(0, self.flashY - 60)
        self.flash:SetParent(self.flashRow); self.flash:ClearAllPoints(); self.flash:SetAllPoints(self.flashRow)
        self.flash:Show(); self.flash.fade:Stop(); self.flash.fade:Play()
    end
    self.scrollReset, self.flashId = nil, nil
    self.scroll:SetVerticalScroll(math.min(range, wanted))
    self.scroll.Refresh()
    self:UpdateFooter()
end

-- Tree -------------------------------------------------------------------
local function hasPage(category)
    return category.build ~= nil or #category.options > 0
end
local function createTreeRow()
    local W = widgets()
    local row = CreateFrame('Button', nil, Window.treeBody)
    row:SetSize(LEFT_W - 6, TREE_ROW)
    row:SetHighlightTexture([[Interface\Buttons\WHITE8X8]]); row:GetHighlightTexture():SetVertexColor(1, .78, .42, .08)
    row.bar = row:CreateTexture(nil, 'ARTWORK'); W:Flat(row.bar, W.gold, 1)
    row.bar:SetPoint('TOPLEFT', 0, -1); row.bar:SetPoint('BOTTOMLEFT', 0, 1); row.bar:SetWidth(2)
    row.chevron = W:Chevron(row, 8)
    row.text = W:Label(row, '', 8); row.text:SetWordWrap(false)
    row.count = W:Label(row, '', 8, GREY[1], GREY[2], GREY[3]); row.count:SetPoint('RIGHT', -4, 0)
    row:SetScript('OnMouseDown', function(self) self.text:SetPoint('LEFT', self.indent + 1, -1) end)
    row:SetScript('OnMouseUp', function(self) self.text:SetPoint('LEFT', self.indent, 0) end)
    row:SetScript('OnClick', function(self) Window:TreeClick(self.category) end)
    return row
end
function Window:DrawTree()
    self.treeDirty = false
    self.treePool:Release()
    local options = registry()
    local W = widgets()
    local searching = self.searchText ~= nil
    local counts = self.counts
    local y = 0
    local function matched(category)
        if counts[category.id] then return true end
        for _, child in ipairs(category.children) do if matched(child) then return true end end
        return false
    end
    local function add(category, depth)
        if not options:Visible(category) or (searching and not matched(category)) then return end
        local children = false
        for _, child in ipairs(category.children) do
            if options:Visible(child) and (not searching or matched(child)) then children = true; break end
        end
        local open = children and (searching or self.expanded[category.id])
        local row = self.treePool:Acquire('tree', createTreeRow)
        row.category = category.id
        row.indent = 14 + depth * 10
        row:ClearAllPoints(); row:SetPoint('TOPLEFT', self.treeBody, 'TOPLEFT', 0, -y)
        row.text:ClearAllPoints(); row.text:SetPoint('LEFT', row.indent, 0); row.text:SetPoint('RIGHT', -22, 0)
        row.text:SetText(category.title)
        local selected = not searching and category.id == self.category
        if selected then row.text:SetTextColor(W.headerText[1], W.headerText[2], W.headerText[3], W.headerText[4]) else row.text:SetTextColor(BODY_TEXT[1], BODY_TEXT[2], BODY_TEXT[3]) end
        row.bar:SetShown(selected)
        row.chevron:SetShown(children)
        if children then
            row.chevron:ClearAllPoints(); row.chevron:SetPoint('LEFT', row.indent - 11, 0)
            row.chevron:SetDirection(open and 'down' or 'right')
        end
        row.count:SetText(searching and counts[category.id] and tostring(counts[category.id]) or '')
        row:Show()
        y = y + TREE_ROW
        if open then for _, child in ipairs(category.children) do add(child, depth + 1) end end
    end
    for _, category in ipairs(options:Tree()) do add(category, 0) end
    self.treeBody:SetSize(LEFT_W - 6, math.max(1, y))
    self.treeScroll:UpdateScrollChildRect()
    self.treeScroll:SetVerticalScroll(math.min(self.treeScroll:GetVerticalScroll(), math.max(0, y - self.treeScroll:GetHeight())))
    self.treeScroll.Refresh()
end

-- The page a category row leads to: itself, or its first child with a page.
function Window:Landing(category)
    local options = registry()
    if not category or not options:Visible(category) then return nil end
    if hasPage(category) then return category end
    for _, child in ipairs(category.children or {}) do
        local found = self:Landing(child)
        if found then return found end
    end
    return nil
end
function Window:First()
    for _, category in ipairs(registry():Tree()) do
        local found = self:Landing(category)
        if found then return found end
    end
    return nil
end
function Window:Select(id, optionId)
    local options = registry()
    options:Tree()
    local category = self:Landing(options.categories[id]) or self:First()
    if not category then self.category = nil; self.dirty = true; return false end
    self.category = category.id
    saved().category = category.id
    local parent = category.parent
    while parent do
        self.expanded[parent] = true
        parent = options.categories[parent] and options.categories[parent].parent
    end
    self:BuildContext()
    local target = optionId and options.byId[optionId]
    if target and target.section then saved().collapsed[category.id .. ':' .. target.section] = nil end
    self.flashId, self.scrollReset, self.activeSection = optionId, true, nil
    self.dirty, self.treeDirty = true, true
    return true
end
function Window:TreeClick(id)
    local options = registry()
    local category = options.categories[id]
    if not category then return end
    if self.searchText then self:Jump(id); return end
    local children = false
    for _, child in ipairs(category.children or {}) do if options:Visible(child) then children = true; break end end
    if children and not hasPage(category) and self.expanded[id] then
        self.expanded[id] = nil; self.treeDirty = true   -- a pure group row folds on the second click
        return
    end
    if children then self.expanded[id] = true end
    self:Select(id)
end
-- Leave search, open the page and flash the row.
function Window:Jump(categoryId, optionId)
    self.search:SetText(''); self:SetSearch('')
    self.search:ClearFocus()
    self:Select(categoryId, optionId)
end
function Window:SetSearch(text)
    text = (text or ''):gsub('^%s+', ''):gsub('%s+$', '')
    for key in pairs(self.counts) do self.counts[key] = nil end
    if text == '' then
        self.searchText, self.results = nil, {}
    else
        self.searchText = text
        self.results = registry():Search(text)
        for _, result in ipairs(self.results) do
            local id = result.category.id
            self.counts[id] = (self.counts[id] or 0) + 1
        end
    end
    self.scrollReset, self.dirty, self.treeDirty = true, true, true
end

-- Footer -------------------------------------------------------------------
function Window:Section()
    local category = registry().categories[self.category or '']
    if not category or self.searchText then return nil end
    local wanted = self.activeSection
    if wanted then
        for _, option in ipairs(category.options) do if option.section == wanted then return wanted end end
    end
    return self.firstSection
end
function Window:ResetSection(section)
    if not section then return end
    local count, failed = registry():ResetSection(self.category, section, self.ctx)
    if failed then self:Status(failed, true)
    elseif count == 0 then self:Status(section .. ' is already at its defaults.')
    else self:Status(section .. ': ' .. count .. (count == 1 and ' setting reset.' or ' settings reset.') .. ' Undo reverts it.') end
    self.dirty = true
end
function Window:UpdateFooter()
    local options = registry()
    local profile = ns.Profiles and ns.Profiles:Current() or 'Default'
    self.profile:SetValue(profile, tostring(profile))
    self.profileNote:SetText('profile: ' .. tostring(profile))
    self.undo:SetDisabled(not options:CanUndo())
    self.reset:SetDisabled(self:Section() == nil)
    self.reload:SetShown(options.reloadWanted)
    self.status:ClearAllPoints()
    self.status:SetPoint('LEFT', self.reset, 'RIGHT', 8, 0)
    self.status:SetPoint('RIGHT', options.reloadWanted and self.reload or self.closeButton, 'LEFT', -8, 0)
    local waiting = options:Pending()
    if waiting > 0 then
        self.status:SetText(waiting .. (waiting == 1 and ' change waits' or ' changes wait') .. ' for combat to end.')
        self.status:SetTextColor(WARN[1], WARN[2], WARN[3])
    else
        self.status:SetText(self.statusText or '')
        if self.statusProblem then self.status:SetTextColor(1, .45, .35) else self.status:SetTextColor(GREY[1], GREY[2], GREY[3]) end
    end
end

-- Construction -----------------------------------------------------------
function Window:Build()
    local W, skin = widgets(), ns.DarkSkin
    local gold, heading = W.gold, W.headerText
    local frame = CreateFrame('Frame', NAME, UIParent)
    self.frame = frame
    frame:SetSize(WIDTH, HEIGHT); frame:SetFrameStrata('DIALOG'); frame:SetToplevel(true)
    frame:EnableMouse(true); frame:SetMovable(true); frame:SetClampedToScreen(true)
    frame:Hide()
    local border = skin and skin:Panel(frame, 'dialog', 0)
    local fill = frame:CreateTexture(nil, 'BACKGROUND'); fill:SetTexture([[Interface\Buttons\WHITE8X8]])
    if border then skin:StylePanelBackground(fill, border) else fill:SetAllPoints(); fill:SetVertexColor(.05, .05, .05, .7) end
    local under = frame:CreateTexture(nil, 'BACKGROUND', nil, -8); under:SetAllPoints(fill); under:SetColorTexture(.02, .02, .02, 0) -- owner: same body as the chat panel
    local point = saved().point
    if type(point) == 'table' and point[1] then frame:SetPoint(point[1], UIParent, point[2] or point[1], point[3] or 0, point[4] or 0)
    else frame:SetPoint('CENTER') end

    -- Title strip: drag handle, name, profile, close.
    local drag = CreateFrame('Frame', nil, frame)
    drag:SetPoint('TOPLEFT', 0, 0); drag:SetPoint('TOPRIGHT', 0, 0); drag:SetHeight(TOP)
    drag:EnableMouse(true); drag:RegisterForDrag('LeftButton')
    drag:SetScript('OnDragStart', function() frame:StartMoving() end)
    drag:SetScript('OnDragStop', function()
        frame:StopMovingOrSizing()
        local anchor, _, relative, x, y = frame:GetPoint(1)
        saved().point = { anchor, relative, x, y }
    end)
    local name = W:Label(frame, 'Squanch-On', 10, heading[1], heading[2], heading[3]); name:SetPoint('LEFT', frame, 'TOPLEFT', PAD + 6, -PAD - 10)
    self.closeX = W:SmallButton(frame, 'x', 20, function() frame:Hide() end)
    self.closeX:SetPoint('RIGHT', frame, 'TOPRIGHT', -PAD - 2, -PAD - 10)
    self.profileNote = W:Label(frame, '', 8, GREY[1], GREY[2], GREY[3]); self.profileNote:SetPoint('RIGHT', self.closeX, 'LEFT', -10, 0)
    local function rule(y, fromBottom)
        local line = frame:CreateTexture(nil, 'ARTWORK')
        W:Flat(line, W.line, 1); line:SetHeight(1)
        line:SetPoint(fromBottom and 'BOTTOMLEFT' or 'TOPLEFT', PAD, y); line:SetPoint(fromBottom and 'BOTTOMRIGHT' or 'TOPRIGHT', -PAD, y)
        return line
    end
    rule(-TOP); rule(BOTTOM, true)
    local divider = frame:CreateTexture(nil, 'ARTWORK')
    W:Flat(divider, W.line, 1); divider:SetWidth(1)
    divider:SetPoint('TOPLEFT', PAD + LEFT_W + 4, -TOP); divider:SetPoint('BOTTOMLEFT', PAD + LEFT_W + 4, BOTTOM)

    -- Left column: search and the category tree.
    self.search = W:SearchBox(frame, LEFT_W - 12, 'Search settings')
    self.search:SetPoint('TOPLEFT', PAD + 4, -TOP - 8)
    self.search.onChanged = function(_, text) Window:SetSearch(text) end
    self.search.onEnter = function()
        local first = Window.results[1]
        if first then Window:Jump(first.category.id, first.option and first.option.id) end
    end
    self.treeScroll, self.treeBody = W:Scroll(frame)
    self.treeScroll:SetPoint('TOPLEFT', PAD, -TOP - 32); self.treeScroll:SetPoint('BOTTOMLEFT', PAD, BOTTOM + 6)
    self.treeScroll:SetWidth(LEFT_W - 6)
    self.treePool = newPool()

    -- Content pane.
    self.scroll, self.body = W:Scroll(frame)
    self.scroll:SetPoint('TOPLEFT', CONTENT_X, -TOP - 8); self.scroll:SetPoint('BOTTOMLEFT', CONTENT_X, BOTTOM + 6)
    self.scroll:SetWidth(CONTENT_W)
    self.title = W:Label(self.body, '', 10, heading[1], heading[2], heading[3]); self.title:SetPoint('TOPLEFT', 0, -2)
    self.desc = W:Label(self.body, '', 8, GREY[1], GREY[2], GREY[3]); self.desc:SetPoint('TOPLEFT', 0, -18)
    self.desc:SetWidth(CONTENT_W - INDENT); self.desc:SetWordWrap(true)
    self.pool = newPool()
    self.flash = self.body:CreateTexture(nil, 'BORDER'); W:Flat(self.flash, gold, .35); self.flash:Hide()
    self.flash.fade = self.flash:CreateAnimationGroup()
    local fade = self.flash.fade:CreateAnimation('Alpha')
    fade:SetFromAlpha(1); fade:SetToAlpha(0); fade:SetDuration(1.4); fade:SetStartDelay(0.3)
    self.flash.fade:SetScript('OnFinished', function() Window.flash:Hide() end)

    -- Footer.
    local base = 12 -- 20-high buttons centred between the window rim and the footer rule
    self.profile = W:Dropdown(frame, 130)
    self.profile:SetPoint('BOTTOMLEFT', PAD + 2, base)
    -- The profile this character uses; picking another switches the whole addon.
    function self.profile:getItems()
        local items = {}
        for _, name in ipairs(ns.Profiles and ns.Profiles:Names() or {}) do items[#items + 1] = { value = name, label = name } end
        return items
    end
    self.profile.onCommit = function(_, name)
        local ok, message = ns.Profiles:Select(name)
        Window:Status(message or '', not ok)
        Window.dirty = true
    end
    self.undo = W:SmallButton(frame, 'Undo', 50, function()
        local ok, message = registry():Undo()
        Window:Status(message == 'queued' and 'The undo is queued until combat ends.' or message or (ok and 'Undone.' or ''), not ok)
    end)
    self.undo:SetPoint('LEFT', self.profile, 'RIGHT', 8, 0)
    self.reset = W:SmallButton(frame, 'Reset section', 84, function() Window:ResetSection(Window:Section()) end)
    self.reset:SetPoint('LEFT', self.undo, 'RIGHT', 8, 0)
    self.reset:HookScript('OnEnter', function(button)
        local section = Window:Section()
        if not section or not GameTooltip then return end
        GameTooltip:SetOwner(button, 'ANCHOR_TOP')
        GameTooltip:SetText('Reset section', heading[1], heading[2], heading[3], 1, true)
        GameTooltip:AddLine('Returns every setting under "' .. section .. '" to its default. One Undo reverts it.', BODY_TEXT[1], BODY_TEXT[2], BODY_TEXT[3], true)
        GameTooltip:Show()
    end)
    self.reset:HookScript('OnLeave', function(button) W:HideDescription(button) end)
    self.closeButton = W:SmallButton(frame, 'Close', 50, function() frame:Hide() end)
    self.closeButton:SetPoint('BOTTOMRIGHT', -PAD - 2, base)
    self.reload = W:SmallButton(frame, 'Reload UI', 64, function() if ReloadUI then ReloadUI() end end)
    self.reload:SetPoint('RIGHT', self.closeButton, 'LEFT', -8, 0); self.reload:Hide()
    self.status = W:Label(frame, '', 8, GREY[1], GREY[2], GREY[3]); self.status:SetHeight(16)
    self.status:SetWordWrap(false); self.status:SetJustifyV('MIDDLE')

    -- Behaviour.
    W:SetEscapeWindow(NAME)
    if ns.TrackMenuFrame then ns:TrackMenuFrame(frame) end
    frame:SetScript('OnShow', function() Window.dirty, Window.treeDirty = true, true end)
    frame:SetScript('OnHide', function()
        W:ClosePopup(); W:HideDescription()
        Window.search:ClearFocus()
        Window.confirming = nil
    end)
    frame:SetScript('OnUpdate', function()
        if Window.treeDirty or registry().treeDirty then Window:DrawTree() end
        -- A redraw rebinds pooled controls, so it waits for an open list or picker.
        if Window.dirty and not Window.picking and not W:PopupOwner() then Window:Redraw() end
    end)
    frame:RegisterEvent('PLAYER_REGEN_DISABLED'); frame:RegisterEvent('PLAYER_REGEN_ENABLED')
    frame:SetScript('OnEvent', function(_, event)
        if event == 'PLAYER_REGEN_DISABLED' then
            if frame:IsShown() then Window.reopen = true; frame:Hide() end
        else
            Window.dirty = true
            if Window.reopen then Window.reopen = nil; frame:Show() end
        end
    end)
    registry():OnChange(function(_, _, reason)
        Window.dirty = true
        if reason == 'flush' then Window:Status('Queued changes applied.') end
    end)
    return frame
end

-- target: nil (last page), a category id or title, or search words.
function Window:Open(target)
    local options, W = registry(), widgets()
    if not options or not W or not CreateFrame then return false end
    if not self.frame then self:Build() end
    options:Tree()
    local text = type(target) == 'string' and target:gsub('^%s+', ''):gsub('%s+$', '') or ''
    local found
    if text ~= '' then
        local wanted = text:lower()
        for id, category in pairs(options.categories) do
            if (id:lower() == wanted or tostring(category.title):lower() == wanted) and self:Landing(category) then found = id; break end
        end
    end
    if found then
        self.search:SetText(''); self:SetSearch('')
        self:Select(found)
    elseif text ~= '' then
        self.search:SetText(text); self:SetSearch(text)
        if not self.category then self:Select(saved().category) end
    elseif not self.category or not self:Landing(options.categories[self.category]) then
        self:Select(saved().category)
    end
    self.reopen = nil
    self.frame:Show()
    if self.frame.Raise then self.frame:Raise() end
    return true
end
function Window:Toggle()
    if self.frame and self.frame:IsShown() then self.frame:Hide(); return false end
    return self:Open()
end
_G.SquanchOn_ToggleOptions = function() return Window:Toggle() end
