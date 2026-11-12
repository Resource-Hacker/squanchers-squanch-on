-- SPDX-License-Identifier: MIT
-- Settings registry: categories and option records declared as data, with one
-- path for reading, validating, writing, undoing and (in combat) queueing a
-- change. It builds no frames; OptionsWindow.lua draws what is registered here.
local _, ns = ...
local Options = {
    categories = {},      -- id -> category record
    byId = {},            -- option id -> option record
    roots = {},           -- storage root name -> resolver(ctx)
    queue = {},           -- changes waiting for combat to end, in request order
    queued = {},          -- change key -> queue entry
    journal = {},         -- undo entries, newest last
    previews = {},        -- change key -> { old = value } while a control is dragged
    listeners = {},
    reloadWanted = false,
    undoDepth = 30,
}
ns.Options = Options

local sequence = 0
local TYPES = { toggle = true, number = true, slider = true, choice = true, color = true, font = true,
    statusbar = true, border = true, text = true, curve = true, list = true, action = true, note = true }
local VALUELESS = { action = true, note = true }
local MEDIA = { font = true, statusbar = true, border = true }

local function copy(value, depth)
    if type(value) ~= 'table' then return value end
    depth = depth or 0
    local result = {}
    if depth < 12 then for k, v in pairs(value) do result[k] = copy(v, depth + 1) end end
    return result
end
local function equal(a, b, depth)
    if a == b then return true end
    if type(a) ~= 'table' or type(b) ~= 'table' then return false end
    depth = depth or 0
    if depth > 12 then return false end
    for k, v in pairs(a) do if not equal(v, b[k], depth + 1) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
Options.Copy, Options.Equal = copy, equal

local function inCombat()
    return InCombatLockdown and InCombatLockdown() and true or false
end
-- One key per option and context, so the same template row on two unit pages
-- undoes and queues independently.
local function changeKey(id, ctx)
    if not ctx or next(ctx) == nil then return id end
    local names = {}
    for name in pairs(ctx) do names[#names + 1] = tostring(name) end
    table.sort(names)
    local parts = { id }
    for _, name in ipairs(names) do parts[#parts + 1] = name .. '=' .. tostring(ctx[name]) end
    return table.concat(parts, '|')
end
local function segments(option)
    if not option.segments then
        local list = {}
        for part in tostring(option.path):gmatch('[^%.]+') do list[#list + 1] = tonumber(part) or part end
        option.segments = list
    end
    return option.segments
end

-- Categories ---------------------------------------------------------------
-- Declaring a category again merges into the existing record, so a child page
-- may load before its parent and a later package may add a page body.
function Options:Category(spec)
    assert(type(spec) == 'table' and type(spec.id) == 'string', 'Options:Category needs an id')
    local category = self.categories[spec.id]
    if not category then
        sequence = sequence + 1
        category = { id = spec.id, options = {}, sequence = sequence }
        self.categories[spec.id] = category
    end
    for key, value in pairs(spec) do category[key] = value end
    -- `custom` hosts an existing hand-built page; `build` is the same hook.
    category.build = category.build or category.custom
    category.title = category.title or category.id
    self.treeDirty = true
    return category
end

function Options:Root(name, resolver)
    self.roots[name] = resolver
end

-- Options ------------------------------------------------------------------
function Options:Add(categoryId, list)
    local category = self.categories[categoryId] or self:Category({ id = categoryId })
    for _, option in ipairs(list) do
        assert(type(option.id) == 'string', 'option needs an id')
        assert(TYPES[option.type], 'unknown option type for ' .. option.id)
        local previous = self.byId[option.id]
        if previous then -- a later declaration replaces and may move the row
            local rows = previous.category.options
            for index = #rows, 1, -1 do if rows[index] == previous then table.remove(rows, index) end end
            previous.category.sorted = nil
        end
        sequence = sequence + 1
        option.sequence, option.category = sequence, category
        option.label = option.label or option.id
        if option.combatSafe == nil then option.combatSafe = false end
        if not option.get and not option.path and not VALUELESS[option.type] then
            error('option ' .. option.id .. ' needs a path or get/set')
        end
        category.options[#category.options + 1] = option
        self.byId[option.id] = option
    end
    category.sorted = nil
    self.treeDirty = true
end

-- One field template instanced for a context (for example one unit frame).
-- shared: idPrefix, root, combatSafe, apply, hidden(option, ctx), disabled(option, ctx).
function Options:AddTemplate(categoryId, template, shared)
    shared = shared or {}
    local list = {}
    for _, field in ipairs(template) do
        local option = {}
        for key, value in pairs(field) do option[key] = value end
        option.key = option.key or option.path
        option.id = (shared.idPrefix or categoryId .. '.') .. tostring(option.key)
        option.path = option.path or option.key
        for _, name in ipairs({ 'root', 'combatSafe', 'apply', 'requiresReload' }) do
            if option[name] == nil then option[name] = shared[name] end
        end
        for _, name in ipairs({ 'hidden', 'disabled' }) do
            local own, common = option[name], shared[name]
            if common then
                option[name] = function(ctx) return (own and own(ctx)) or common(option, ctx) or false end
            end
        end
        list[#list + 1] = option
    end
    self:Add(categoryId, list)
end

-- Rows of a category in drawing order: sections in order of first appearance
-- (or `sectionOrder`), then `order`, then declaration order. Cached.
function Options:Sorted(categoryId)
    local category = self.categories[categoryId]
    if not category then return nil end
    if not category.sorted then
        local rank, next = {}, 0
        for _, option in ipairs(category.options) do
            local section = option.section or ''
            if not rank[section] then next = next + 1; rank[section] = option.sectionOrder or next end
        end
        local sorted = {}
        for index, option in ipairs(category.options) do sorted[index] = option end
        table.sort(sorted, function(a, b)
            local ra, rb = rank[a.section or ''], rank[b.section or '']
            if ra ~= rb then return ra < rb end
            local oa, ob = a.order or 1e9, b.order or 1e9
            if oa ~= ob then return oa < ob end
            return a.sequence < b.sequence
        end)
        category.sorted = sorted
    end
    return category.sorted
end

-- Root categories in order, each with a sorted `children` array. Cached.
function Options:Tree()
    if self.treeDirty or not self.tree then
        local roots = {}
        for _, category in pairs(self.categories) do category.children = {} end
        for _, category in pairs(self.categories) do
            local parent = category.parent and self.categories[category.parent]
            local list = parent and parent.children or roots
            list[#list + 1] = category
        end
        local function order(a, b)
            local oa, ob = a.order or 1e9, b.order or 1e9
            if oa ~= ob then return oa < ob end
            return a.sequence < b.sequence
        end
        table.sort(roots, order)
        for _, category in pairs(self.categories) do table.sort(category.children, order) end
        self.tree, self.treeDirty = roots, false
    end
    return self.tree
end

-- A category is shown when it is not hidden and has something to show.
function Options:Visible(category)
    if not category or (category.hidden and category.hidden()) then return false end
    if category.build or #category.options > 0 then return true end
    for _, child in ipairs(category.children or {}) do if self:Visible(child) then return true end end
    return false
end

-- Storage ------------------------------------------------------------------
local function fromArray(value)
    if type(value) ~= 'table' then return nil end
    return { r = value[1], g = value[2], b = value[3], a = value[4] }
end
function Options:Read(option, ctx)
    local value
    if option.get then
        value = option.get(ctx)
    else
        local resolver = self.roots[option.root or 'db']
        value = resolver and resolver(ctx)
        for _, part in ipairs(segments(option)) do
            if type(value) ~= 'table' then value = nil; break end
            value = value[part]
        end
    end
    if option.type == 'color' and option.storage == 'array' then return fromArray(value) end
    return copy(value)
end
function Options:Write(option, ctx, value)
    if option.type == 'color' and option.storage == 'array' and type(value) == 'table' then
        value = { value.r, value.g, value.b, value.a }
    end
    if option.set then return option.set(ctx, copy(value)) end
    local resolver = self.roots[option.root or 'db']
    local node = resolver and resolver(ctx)
    if type(node) ~= 'table' then error('Storage for ' .. option.id .. ' is not available', 0) end
    local path = segments(option)
    for index = 1, #path - 1 do
        local child = node[path[index]]
        if type(child) ~= 'table' then child = {}; node[path[index]] = child end
        node = child
    end
    local key, existing = path[#path], node[path[#path]]
    if option.type == 'color' and type(existing) == 'table' and type(value) == 'table' then
        -- Keep the stored table's identity: renderers may hold a reference.
        for k in pairs(existing) do if value[k] == nil and (type(k) == 'number' or k == 'a') then existing[k] = nil end end
        for k, v in pairs(value) do existing[k] = v end
    else
        node[key] = copy(value)
    end
end
function Options:Default(option, ctx)
    local value = option.default
    if type(value) == 'function' then value = value(ctx) end
    return copy(value)
end
function Options:HasDefault(option)
    return option.default ~= nil or option.allowEmpty == true
end

-- values, labels for a choice. `labels` may be parallel to values or keyed by value.
function Options:Choices(option, ctx)
    local values, labels = option.values, option.labels
    if type(values) == 'function' then values = values(ctx) end
    if type(labels) == 'function' then labels = labels(ctx) end
    return values or {}, labels
end
function Options:ChoiceLabel(option, ctx, value)
    local values, labels = self:Choices(option, ctx)
    if labels and value ~= nil then
        if labels[1] == nil then
            if labels[value] ~= nil then return tostring(labels[value]) end
        else
            for index, candidate in ipairs(values) do
                if candidate == value then return tostring(labels[index] or value) end
            end
        end
    end
    if value == nil then return option.emptyLabel or '(inherit)' end
    return tostring(value)
end

-- Validation: returns true, normalizedValue or false, message.
local function number(option, value)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then return false, 'Enter a number.' end
    -- `step` is the slider's drag granularity; typed values and defaults (for
    -- example two thirds) are kept exact within min and max.
    if option.integer then value = math.floor(value + 0.5) end
    value = tonumber(string.format('%.6f', value))
    if (option.min and value < option.min) or (option.max and value > option.max) then
        return false, string.format('%s must be between %s and %s.', option.label, tostring(option.min or '-'), tostring(option.max or '-'))
    end
    return true, value
end
local function unit(value) return type(value) == 'number' and value == value and value >= 0 and value <= 1 end
function Options:Check(option, value, ctx)
    local kind = option.type
    if VALUELESS[kind] then return false, 'This row has no value.' end
    if value == nil then
        if option.allowEmpty or (kind == 'curve' and option.allowDisable) then return true, nil end
        return false, option.label .. ' needs a value.'
    end
    if kind == 'toggle' then
        if type(value) ~= 'boolean' then return false, option.label .. ' is on or off.' end
    elseif kind == 'number' or kind == 'slider' then
        local ok, result = number(option, value)
        if not ok then return false, result end
        value = result
    elseif kind == 'choice' then
        local found = false
        for _, candidate in ipairs((self:Choices(option, ctx))) do if candidate == value then found = true; break end end
        if not found then return false, tostring(value) .. ' is not a choice for ' .. option.label .. '.' end
    elseif kind == 'color' then
        if type(value) ~= 'table' or not (unit(value.r) and unit(value.g) and unit(value.b))
            or (value.a ~= nil and not unit(value.a)) then return false, 'Colour channels run from 0 to 1.' end
        value = { r = value.r, g = value.g, b = value.b, a = option.hasAlpha and (value.a or 1) or value.a }
    elseif MEDIA[kind] or kind == 'text' then
        if type(value) ~= 'string' then return false, option.label .. ' needs text.' end
        if option.maxLetters and #value > option.maxLetters then
            return false, string.format('%s is limited to %d characters.', option.label, option.maxLetters)
        end
    elseif kind == 'curve' then
        if type(value) ~= 'table' then return false, option.label .. ' needs points.' end
        local points = {}
        for index, point in ipairs(value) do
            local x, y = type(point) == 'table' and tonumber(point.x), type(point) == 'table' and tonumber(point.y)
            if not x or not y or x ~= x or y ~= y then return false, 'Point ' .. index .. ' needs two numbers.' end
            if (option.xMin and x < option.xMin) or (option.xMax and x > option.xMax)
                or (option.yMin and y < option.yMin) or (option.yMax and y > option.yMax) then
                return false, 'Point ' .. index .. ' is outside the allowed range.'
            end
            points[index] = { x = x, y = y }
        end
        if #points < (option.minPoints or 1) then return false, option.label .. ' needs at least ' .. (option.minPoints or 1) .. ' point(s).' end
        table.sort(points, function(a, b) return a.x < b.x end)
        value = points
    elseif kind == 'list' then
        if type(value) ~= 'table' then return false, option.label .. ' needs a list.' end
        value = copy(value)
    end
    if option.validate then
        local ok, message = option.validate(value, ctx)
        if ok == false then return false, message or (option.label .. ' was not accepted.') end
    end
    return true, value
end

-- Change notifications --------------------------------------------------
-- fn(id, ctx, reason); id is nil for wholesale events ('queue', 'undo', 'flush').
function Options:OnChange(fn)
    self.listeners[#self.listeners + 1] = fn
end
function Options:Fire(id, ctx, reason)
    for _, fn in ipairs(self.listeners) do
        local ok, err = pcall(fn, id, ctx, reason)
        if not ok and geterrorhandler then geterrorhandler()(err) end
    end
end

-- Runtime ------------------------------------------------------------------
function Options:Get(id, ctx)
    local option = self.byId[id]
    if not option or VALUELESS[option.type] then return nil end
    return self:Read(option, ctx)
end

function Options:Journal(option, ctx, old, new)
    local entry = { id = option.id, ctx = copy(ctx), old = copy(old), new = copy(new) }
    if self.batch then self.batch[#self.batch + 1] = entry; return end
    local journal = self.journal
    journal[#journal + 1] = entry
    while #journal > self.undoDepth do table.remove(journal, 1) end
end

local function applied(self, option, ctx, value, current)
    local ok, err = pcall(self.Write, self, option, ctx, value)
    if not ok then return false, tostring(err) end
    if not option.requiresReload and option.apply then
        local good, result, reason = pcall(option.apply, ctx, value, current)
        -- A renderer may refuse with `false, reason` instead of raising.
        if not good or result == false then
            pcall(self.Write, self, option, ctx, current) -- never leave a half-applied value
            return false, tostring((not good and result) or reason or 'The change could not be applied.')
        end
    end
    return true
end

-- source: nil (user), 'slash', 'undo', 'queue', 'reset'.
-- Returns true | true, 'queued' | false, message.
function Options:Set(id, value, ctx, source)
    local option = self.byId[id]
    if not option then return false, 'Unknown setting: ' .. tostring(id) end
    if option.disabled and option.disabled(ctx) then return false, option.label .. ' is unavailable.' end
    -- Undo may restore "no stored value" (an inherited field) for any option.
    if not (source == 'undo' and value == nil) then
        local ok, checked = self:Check(option, value, ctx)
        if not ok then return false, checked end
        value = checked
    end
    local key = changeKey(id, ctx)
    if not option.combatSafe and inCombat() then
        local entry = self.queued[key]
        if not entry then
            entry = { id = id, ctx = copy(ctx), key = key }
            self.queue[#self.queue + 1] = entry; self.queued[key] = entry
        end
        entry.value, entry.source = copy(value), source
        self:Fire(id, ctx, 'queued')
        return true, 'queued'
    end
    local current = self:Read(option, ctx)
    local preview = self.previews[key]
    self.previews[key] = nil
    local old = current
    if preview then old = preview.old end
    if not equal(current, value) then
        local good, message = applied(self, option, ctx, value, current)
        if not good then self:Fire(id, ctx, 'failed'); return false, message end
    end
    if equal(old, value) then
        if preview then self:Fire(id, ctx, 'set') end
        return true
    end
    if source ~= 'undo' then self:Journal(option, ctx, old, value) end
    if option.requiresReload then self.reloadWanted = true end
    self:Fire(id, ctx, 'set')
    return true
end

-- Live preview while a slider or the colour picker is being dragged: writes
-- and applies without journaling. The following Set (or CancelPreview) closes it.
function Options:Preview(id, value, ctx)
    local option = self.byId[id]
    if not option or option.requiresReload or (not option.combatSafe and inCombat()) then return false end
    if option.disabled and option.disabled(ctx) then return false end
    local ok, checked = self:Check(option, value, ctx)
    if not ok then return false, checked end
    local key, current = changeKey(id, ctx), self:Read(option, ctx)
    if equal(current, checked) then return true end
    local good, message = applied(self, option, ctx, checked, current)
    if not good then return false, message end
    if not self.previews[key] then self.previews[key] = { old = current } end
    return true
end
function Options:CancelPreview(id, ctx)
    local option, key = self.byId[id], changeKey(id, ctx)
    local preview = self.previews[key]
    self.previews[key] = nil
    if not option or not preview then return false end
    local current = self:Read(option, ctx)
    if not equal(current, preview.old) then applied(self, option, ctx, preview.old, current) end
    self:Fire(id, ctx, 'set')
    return true
end

function Options:Reset(id, ctx)
    local option = self.byId[id]
    if not option then return false, 'Unknown setting: ' .. tostring(id) end
    if VALUELESS[option.type] or not self:HasDefault(option) then return false, option.label .. ' has no default.' end
    return self:Set(id, self:Default(option, ctx), ctx, 'reset')
end

-- Every visible, enabled option of one section (or of the whole category when
-- section is nil) back to its default, as a single undo entry. Returns the count.
function Options:ResetSection(categoryId, section, ctx)
    local sorted = self:Sorted(categoryId)
    if not sorted then return 0 end
    local outer = self.batch
    self.batch = outer or {}
    local changed, failed = 0, nil
    for _, option in ipairs(sorted) do
        if (section == nil or (option.section or '') == section) and not VALUELESS[option.type]
            and self:HasDefault(option) and not (option.hidden and option.hidden(ctx)) then
            local before = #self.batch
            local ok, message = self:Set(option.id, self:Default(option, ctx), ctx, 'reset')
            if ok and (message == 'queued' or #self.batch > before) then changed = changed + 1
            elseif not ok and not (option.disabled and option.disabled(ctx)) then failed = message end
        end
    end
    if not outer then
        local batch = self.batch
        self.batch = nil
        if #batch > 0 then
            self.journal[#self.journal + 1] = { batch = batch, label = section }
            while #self.journal > self.undoDepth do table.remove(self.journal, 1) end
        end
    end
    return changed, failed
end

function Options:CanUndo()
    return #self.journal > 0
end
function Options:Undo()
    local entry = table.remove(self.journal)
    if not entry then return false, 'Nothing to undo.' end
    local list = entry.batch or { entry }
    local message
    for index = #list, 1, -1 do
        local change = list[index]
        if self.byId[change.id] then
            local ok, result = self:Set(change.id, change.old, change.ctx, 'undo')
            if not ok or result == 'queued' then message = result end
        end
    end
    self:Fire(nil, nil, 'undo')
    return true, message
end
function Options:ClearJournal()
    self.journal = {}
end

-- Combat queue ---------------------------------------------------------
function Options:Pending()
    return #self.queue, self.queue
end
-- true, value when a change to this option waits for combat to end.
function Options:Queued(id, ctx)
    local entry = self.queued[changeKey(id, ctx)]
    if entry then return true, entry.value end
    return false
end
function Options:Flush()
    if inCombat() or #self.queue == 0 then return 0 end
    local queue = self.queue
    self.queue, self.queued = {}, {}
    local done = 0
    for _, entry in ipairs(queue) do
        local ok = self:Set(entry.id, entry.value, entry.ctx, entry.source or 'queue')
        if ok then done = done + 1 end
    end
    self:Fire(nil, nil, 'flush')
    return done
end

-- Actions ------------------------------------------------------------------
function Options:Run(id, ctx)
    local option = self.byId[id]
    if not option or option.type ~= 'action' or not option.func then return false, 'Unknown action: ' .. tostring(id) end
    if option.disabled and option.disabled(ctx) then return false, option.label .. ' is unavailable.' end
    if not option.combatSafe and inCombat() then return false, option.label .. ' is available after combat.' end
    local ok, result, reason = pcall(option.func, ctx)
    if not ok then return false, tostring(result) end
    if result == false then return false, reason or (option.label .. ' did not complete.') end
    self:Fire(id, ctx, 'action')
    return true, type(result) == 'string' and result or nil
end

-- Search -------------------------------------------------------------------
local function haystack(category, option)
    local parent = category.parent and Options.categories[category.parent]
    local parts = { category.title or '', parent and parent.title or '' }
    if option then
        parts[#parts + 1] = option.label or ''
        parts[#parts + 1] = type(option.desc) == 'string' and option.desc or ''
        parts[#parts + 1] = option.keywords or ''
        parts[#parts + 1] = option.section or ''
        if option.type == 'note' and type(option.text) == 'string' then parts[#parts + 1] = option.text end
    else
        parts[#parts + 1] = category.desc or ''
        parts[#parts + 1] = category.keywords or ''
    end
    return table.concat(parts, ' '):lower()
end
-- Every word must occur. Returns { { category =, option = }, ... } in tree
-- order; option is nil for a hand-built page matched by its own title.
function Options:Search(text)
    local words = {}
    for word in tostring(text or ''):lower():gmatch('%S+') do words[#words + 1] = word end
    local results = {}
    if #words == 0 then return results end
    local function matches(hay)
        for _, word in ipairs(words) do if not hay:find(word, 1, true) then return false end end
        return true
    end
    local function visit(category)
        if category.hidden and category.hidden() then return end
        if category.build or #category.options == 0 then
            category.haystack = category.haystack or haystack(category)
            if self:Visible(category) and matches(category.haystack) then results[#results + 1] = { category = category } end
        end
        for _, option in ipairs(self:Sorted(category.id)) do
            option.haystack = option.haystack or haystack(category, option)
            if matches(option.haystack) then results[#results + 1] = { category = category, option = option } end
        end
        for _, child in ipairs(category.children) do visit(child) end
    end
    for _, category in ipairs(self:Tree()) do visit(category) end
    return results
end

-- Entry points -------------------------------------------------------------
-- target: nil (last page), a category id, or search words.
function Options:Open(target)
    if not ns.OptionsWindow then
        print('Squanch-On: the settings window is not loaded.')
        return false
    end
    return ns.OptionsWindow:Open(target)
end
function ns:OpenOptions(pageId)
    return Options:Open(pageId)
end
-- Body for the /squanchon and /squancher slash commands.
function ns:OptionsCommand(msg)
    msg = tostring(msg or ''):gsub('^%s+', ''):gsub('%s+$', '')
    local word = msg:lower()
    if (word == 'edit' or word == 'layout') and ns.LayoutEditor then ns.LayoutEditor:Toggle(); return end
    return Options:Open(msg ~= '' and msg or nil)
end
_G.SquanchOn_OpenOptions = function(msg) return ns:OptionsCommand(type(msg) == 'string' and msg or nil) end
_G.SquanchOn_OnAddonCompartmentClick = function() return Options:Open() end

-- Storage roots. Paths stay valid when the profile package moves the tables.
Options:Root('db', function() return ns.db end)
Options:Root('tooltip', function() return ns.db and ns.db.tooltipImport and ns.db.tooltipImport.tooltip end)
Options:Root('uf', function() return ns.UnitFrames and ns.UnitFrames.db end)
Options:Root('unit', function(ctx)
    local db = ns.UnitFrames and ns.UnitFrames.db
    return db and db.units and ctx and db.units[ctx.unit]
end)
Options:Root('indicator', function(ctx)
    local profile = ns.NameplateIndicators and ns.NameplateIndicators.profile
    local unit = profile and ctx and profile[ctx.unit]
    return unit and unit[ctx.reaction]
end)

if CreateFrame then
    local events = CreateFrame('Frame')
    events:RegisterEvent('PLAYER_REGEN_ENABLED')
    events:SetScript('OnEvent', function() Options:Flush() end)
    Options.events = events
end
