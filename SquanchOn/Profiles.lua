-- SPDX-License-Identifier: MIT
-- Profiles: the saved-variable shape, one addon-wide profile per character,
-- the one-time migration from the flat schema-1 root, and export/import strings.
--
-- SquanchOnDB = {
--   schema = 2,
--   profileKeys = { [character] = profile name },
--   profiles = { Default = { ...every preference, under the key names modules have always used... } },
--   global = { receipts = { ...one-time records and diagnostics, per account... } },
--   backup = { at, schema = 1, data = <the untouched pre-migration root> },  -- dropped by a later version
-- }
--
-- ns.db stays the ACTIVE PROFILE table, so `ns.db.<key>` in every module is
-- unchanged. Two metatables keep the remaining access paths working (the game
-- saves raw fields only, so neither is written to disk):
--   * the active profile: a receipt key read or written through ns.db lives
--     in global.receipts;
--   * the root: `SquanchOnDB.<key>` forwards to ns.db.
local _, ns = ...
local Profiles = { listeners = {}, ui = { name = '', import = '', export = '' } }
ns.Profiles = Profiles

local SCHEMA, DEFAULT, PREFIX = 2, 'Default', '!SQO1!'
local FORMAT = 1
-- Import bounds. A whole profile is about 41,000 characters as a string.
local MAX_STRING, MAX_SERIALIZED, MAX_DEPTH, MAX_NODES, MAX_NAME = 200000, 8000000, 24, 400000, 48

-- Receipts and diagnostics --------------------------------------------------
local RECEIPTS = {}
for _, key in ipairs({ 'loadedVersion', 'nativeReturnRevision', 'nativeReceipts', 'combinedClickBlocked',
    'mouseoverSetup', 'chatTimestampRestored', 'settingsCompactScale', 'settingsTopPlacement',
    'itemWindowSizing', 'minimapItemSizing', 'migrations', 'nativeLeftClickOwnsInteract',
    'generalChat20261110', 'drawerNativeLayouts', 'unitFrameImport', 'unitframes', 'optionsWindow',
    'unitFrameReceipts', 'nameplateIndicatorReceipts' }) do RECEIPTS[key] = true end
local SUFFIXES = { 'Audit', 'Probe', 'Inspection', 'Diagnostic', 'Migration', 'Receipts', 'Calls', 'Error' }
local function isReceipt(key)
    if type(key) ~= 'string' then return false end
    if RECEIPTS[key] or key:find('Original', 1, true) or key:find('Previous', 1, true) or key:find('^last%u') then return true end
    for _, suffix in ipairs(SUFFIXES) do if key:sub(-#suffix) == suffix then return true end end
    return false
end
Profiles.IsReceipt = isReceipt

-- Plain helpers ---------------------------------------------------------------
local function clone(value, depth)
    if type(value) ~= 'table' then return value end
    depth = depth or 0
    local result = {}
    if depth < 64 then for key, child in pairs(value) do result[key] = clone(child, depth + 1) end end
    return result
end
local function equal(a, b)
    if a == b then return true end
    if type(a) ~= 'table' or type(b) ~= 'table' then return false end
    for key, value in pairs(a) do if not equal(value, b[key]) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end
local function characterKey()
    -- The key the indicator profiles used, so their per-character choices carry over.
    local ok, name = pcall(UnitName, 'player')
    local good, realm = pcall(GetRealmName)
    return (ok and type(name) == 'string' and name or 'Player') .. ' - ' .. (good and type(realm) == 'string' and realm or 'Realm')
end
local function freeName(profiles, wanted)
    if not profiles[wanted] then return wanted end
    local index = 2
    while profiles[wanted .. ' ' .. index] do index = index + 1 end
    return wanted .. ' ' .. index
end
local function validName(name)
    if type(name) ~= 'string' then return nil, 'Type a profile name first.' end
    name = name:match('^%s*(.-)%s*$')
    if name == '' then return nil, 'Type a profile name first.' end
    if #name > MAX_NAME then return nil, 'A profile name is limited to ' .. MAX_NAME .. ' characters.' end
    if name:find('[%c|]') then return nil, 'A profile name cannot contain | or control characters.' end
    return name
end

-- Shipped defaults ------------------------------------------------------------
-- DefaultProfile.lua stays in memory: New, Reset and a missing Default need it.
local function fresh()
    local profile = clone(ns.DefaultProfile or {})
    for key in pairs(profile) do if isReceipt(key) then profile[key] = nil end end
    if ns.SeedDefaults then ns:SeedDefaults(profile) end
    return profile
end
local function firstRun()
    local receipts = {}
    for key, value in pairs(ns.DefaultProfile or {}) do if isReceipt(key) then receipts[key] = clone(value) end end
    return { schema = SCHEMA, profileKeys = {}, profiles = { [DEFAULT] = fresh() }, global = { receipts = receipts } }
end

-- Migration from the flat root ------------------------------------------------
-- Nothing is dropped: every old leaf ends in profiles.Default, in another
-- profile made from an extra inner profile, or in global.receipts; the old
-- root is also kept whole under `backup`.
local function migrate(old)
    local backup = { at = time and time() or 0, schema = tonumber(old.schema) or 1, data = clone(old) }
    local main, receipts, profiles, keys = {}, {}, {}, {}
    for key, value in pairs(old) do
        if key ~= 'unitFrames' and key ~= 'nameplateIndicators' then
            if isReceipt(key) then receipts[key] = value else main[key] = value end
        end
    end
    profiles[DEFAULT] = main
    local extras = {} -- { name, field, table }: inner profiles other than the selected ones

    local frames = old.unitFrames
    if type(frames) == 'table' then
        local state, active = {}, frames.profile
        for key, value in pairs(frames) do if key ~= 'profiles' then state[key] = value end end
        receipts.unitFrameReceipts = state
        local inner = type(frames.profiles) == 'table' and frames.profiles or {}
        if inner[active] == nil then active = next(inner) end
        for name, value in pairs(inner) do
            if name == active then main.unitFrames = value
            else extras[#extras + 1] = { tostring(name), 'unitFrames', value } end
        end
    end

    local indicators, renamed = old.nameplateIndicators, {}
    if type(indicators) == 'table' then
        local state = {}
        for key, value in pairs(indicators) do if key ~= 'profiles' and key ~= 'profileKeys' then state[key] = value end end
        receipts.nameplateIndicatorReceipts = state
        local inner = type(indicators.profiles) == 'table' and indicators.profiles or {}
        local chosen = type(indicators.profileKeys) == 'table' and indicators.profileKeys or {}
        local active = chosen[characterKey()]
        if inner[active] == nil then active = inner[DEFAULT] ~= nil and DEFAULT or next(inner) end
        for name, value in pairs(inner) do
            if name == active then main.nameplateIndicators = value; renamed[name] = DEFAULT
            else extras[#extras + 1] = { tostring(name), 'nameplateIndicators', value } end
        end
        for character, name in pairs(chosen) do keys[character] = name end
    end

    -- An extra inner profile becomes a whole profile: Default with that one part swapped.
    table.sort(extras, function(a, b) if a[1] ~= b[1] then return a[1] < b[1] end return a[2] < b[2] end)
    for _, extra in ipairs(extras) do
        local name, field, value = extra[1], extra[2], extra[3]
        local profile = clone(main)
        profile[field] = value
        name = freeName(profiles, name)
        profiles[name] = profile
        if field == 'nameplateIndicators' then renamed[extra[1]] = name end
    end
    for character, name in pairs(keys) do keys[character] = renamed[name] or DEFAULT end

    if GetPhysicalScreenSize then
        local width, height = GetPhysicalScreenSize()
        if type(width) == 'number' and type(height) == 'number' and width > 0 and height > 0 then
            for _, profile in pairs(profiles) do profile.screen = { width, height } end
        end
    end
    return { schema = SCHEMA, profileKeys = keys, profiles = profiles, global = { receipts = receipts }, backup = backup }
end
Profiles.Migrate = migrate -- offline checks

-- Activation --------------------------------------------------------------------
local profileMeta = {}
local rootMeta = {
    __index = function(_, key) local db = ns.db; if db then return db[key] end end,
    __newindex = function(root, key, value)
        local db = ns.db
        if db then db[key] = value else rawset(root, key, value) end
    end,
}
local function activate(name)
    local root, old = Profiles.root, ns.db
    if old then setmetatable(old, nil) end
    local profile = root.profiles[name]
    ns.db = setmetatable(profile, profileMeta)
    Profiles.current = name
    root.profileKeys[Profiles.key] = name
    if Profiles.prepare then Profiles.prepare(profile) end
    return old
end

-- Idempotent. Core.lua passes `prepare(profile)`, which fills its scalar
-- defaults into every profile that becomes active. Returns the active profile.
function Profiles:Bootstrap(prepare)
    if prepare then self.prepare = prepare end
    if not self.ready then
        local root = SquanchOnDB
        if type(root) ~= 'table' then root = firstRun()
        elseif type(root.schema) ~= 'number' or root.schema < SCHEMA then root = migrate(root) end
        SquanchOnDB = root
        for _, key in ipairs({ 'profileKeys', 'profiles', 'global' }) do
            if type(rawget(root, key)) ~= 'table' then rawset(root, key, {}) end
        end
        if type(root.global.receipts) ~= 'table' then root.global.receipts = {} end
        if type(root.profiles[DEFAULT]) ~= 'table' then root.profiles[DEFAULT] = fresh() end
        local receipts = root.global.receipts
        profileMeta.__index = receipts
        profileMeta.__newindex = function(profile, key, value)
            if isReceipt(key) then receipts[key] = value else rawset(profile, key, value) end
        end
        self.root, self.key, ns.global = root, characterKey(), root.global
        local name = root.profileKeys[self.key]
        if type(root.profiles[name]) ~= 'table' then name = DEFAULT end
        setmetatable(root, rootMeta)
        self.ready = true
        activate(name)
    elseif prepare and ns.db then prepare(ns.db) end
    return ns.db
end

-- Queries -------------------------------------------------------------------------
function Profiles:Current() return self.current or DEFAULT end
function Profiles:Exists(name) return self.root ~= nil and type(self.root.profiles[name]) == 'table' end
function Profiles:Get(name) return self.root and self.root.profiles[name] end
function Profiles:Names()
    local names = {}
    for name in pairs(self.root and self.root.profiles or {}) do names[#names + 1] = name end
    table.sort(names)
    return names
end
-- A per-account record table under global.receipts, created on first use.
function Profiles:Receipts(name)
    local receipts = self.root.global.receipts
    if type(receipts[name]) ~= 'table' then receipts[name] = {} end
    return receipts[name]
end
-- fn(reason, name): 'select', 'create', 'delete', 'rename', 'reset', 'import'.
function Profiles:OnChanged(fn) self.listeners[#self.listeners + 1] = fn end
local function fire(reason, name)
    for _, fn in ipairs(Profiles.listeners) do
        local ok, err = pcall(fn, reason, name)
        if not ok and geterrorhandler then geterrorhandler()(err) end
    end
    if ns.Options and ns.Options.Fire then ns.Options:Fire(nil, nil, 'profile') end
end

-- Live re-apply ---------------------------------------------------------------------
-- Tables whose owners re-read ns.db when asked. Every other table is read once
-- at load (layout, windows, camera, crosshairs, the unit-frame decoration
-- adapter), so a difference there asks for a reload instead of pretending.
local LIVE = { auras = true, theme = true, chat = true, text = true, tooltipImport = true,
    nameplateIndicators = true, screen = true }
local function try(object, method, ...)
    local fn = object and object[method]
    if type(fn) ~= 'function' then return end
    local ok, err = pcall(fn, object, ...)
    if not ok and geterrorhandler then geterrorhandler()(err) end
end
local function reapply(old, new)
    if not new.enabled then try(ns, 'StopLockedMouselook') end
    try(ns, 'ApplyNativeLeftClickSetting'); try(ns, 'ApplyMouselookOverrideBindings'); try(ns, 'ApplySafeBindings')
    local reticle = ns.HordeReticle
    if reticle and reticle.initialized then
        reticle.db = new
        try(reticle, 'SetEnabled', new.hordeReticleEnabled ~= false)
        try(reticle, 'ApplyReticleScale')
    end
    if new.enabled then try(ns, 'RequestMouselookRematch'); try(ns, 'UpdateReticle') else try(ns, 'HideReticleVisuals') end
    -- Nameplate indicators follow through their own OnChanged listener.
    local frames = ns.UnitFrames
    if frames and frames.Initialized then try(frames, 'Update_AllFrames'); try(frames, 'ApplyAuraSettings') end
    try(ns.DarkSkin, 'ApplyTheme'); try(ns.DarkSkin, 'ApplyChat'); try(ns.NativeText, 'Apply')
    try(ns.TooltipSkin, 'Refresh')
    local reload = false
    local function compare(key)
        if LIVE[key] or reload then return end
        local before, after = rawget(old, key), rawget(new, key)
        if (type(before) == 'table' or type(after) == 'table') and not equal(before, after) then reload = true end
    end
    for key in pairs(old) do compare(key) end
    for key in pairs(new) do compare(key) end
    return reload
end
local function switch(name)
    local old = activate(name)
    if ns.Options and ns.Options.ClearJournal then ns.Options:ClearJournal() end
    local reload = old ~= ns.db and reapply(old, ns.db) or false
    if reload and ns.Options then ns.Options.reloadWanted = true end
    fire('select', name)
    return reload
end
local function inCombat() return InCombatLockdown and InCombatLockdown() and true or false end

-- Operations: each returns ok, message ----------------------------------------------
function Profiles:Select(name)
    if not self:Exists(name) then return false, 'There is no profile named "' .. tostring(name) .. '".' end
    if name == self.current then return true, '"' .. name .. '" is already in use.' end
    if inCombat() then
        self.pending = name
        return true, '"' .. name .. '" will be used when combat ends.'
    end
    self.pending = nil
    local reload = switch(name)
    return true, 'Now using "' .. name .. '".' .. (reload and ' Reload the interface to finish applying layout, camera and frame changes.' or '')
end
function Profiles:UseForAll()
    for character in pairs(self.root.profileKeys) do self.root.profileKeys[character] = self.current end
    return true, 'Every known character now uses "' .. self.current .. '".'
end
-- A profile made elsewhere keeps this install's camera takeover records.
local function adopt(profile)
    local mine, theirs = ns.db and rawget(ns.db, 'camera'), profile.camera
    if type(mine) == 'table' and type(theirs) == 'table' then
        for _, key in ipairs({ 'previous', 'receipt' }) do
            if theirs[key] == nil then theirs[key] = clone(mine[key]) end
        end
    end
    return profile
end
local function add(self, name, profile, reason)
    local checked, message = validName(name)
    if not checked then return false, message end
    if self:Exists(checked) then return false, 'A profile named "' .. checked .. '" already exists.' end
    self.root.profiles[checked] = profile
    fire(reason, checked)
    return true, checked
end
function Profiles:Create(name)
    local ok, result = add(self, name, adopt(fresh()), 'create')
    if not ok then return false, result end
    return true, 'Created "' .. result .. '" from the shipped defaults.'
end
function Profiles:Copy(name, source)
    source = source or self.current
    if not self:Exists(source) then return false, 'There is no profile named "' .. tostring(source) .. '".' end
    local ok, result = add(self, name, clone(self.root.profiles[source]), 'create')
    if not ok then return false, result end
    return true, 'Copied "' .. source .. '" to "' .. result .. '".'
end
function Profiles:Rename(old, name)
    old = old or self.current
    if old == DEFAULT then return false, 'The Default profile keeps its name; copy it to a new name instead.' end
    if not self:Exists(old) then return false, 'There is no profile named "' .. tostring(old) .. '".' end
    local checked, message = validName(name)
    if not checked then return false, message end
    if self:Exists(checked) then return false, 'A profile named "' .. checked .. '" already exists.' end
    local root = self.root
    root.profiles[checked], root.profiles[old] = root.profiles[old], nil
    for character, used in pairs(root.profileKeys) do if used == old then root.profileKeys[character] = checked end end
    if self.current == old then self.current = checked end
    if self.pending == old then self.pending = checked end
    fire('rename', checked)
    return true, 'Renamed "' .. old .. '" to "' .. checked .. '".'
end
function Profiles:Delete(name)
    if name == DEFAULT then return false, 'The Default profile cannot be deleted.' end
    if name == self.current then return false, 'Switch to another profile before deleting this one.' end
    if not self:Exists(name) then return false, 'There is no profile named "' .. tostring(name) .. '".' end
    local root = self.root
    root.profiles[name] = nil
    for character, used in pairs(root.profileKeys) do if used == name then root.profileKeys[character] = DEFAULT end end
    if self.pending == name then self.pending = nil end
    fire('delete', name)
    return true, 'Deleted "' .. name .. '". Characters that used it now use Default.'
end
-- The replaced settings are kept as "<name> (before reset)".
function Profiles:Reset(name)
    name = name or self.current
    if not self:Exists(name) then return false, 'There is no profile named "' .. tostring(name) .. '".' end
    if name == self.current and inCombat() then return false, 'Reset the profile in use after combat.' end
    local root = self.root
    local kept = freeName(root.profiles, (name .. ' (before reset)'):sub(1, MAX_NAME + 16))
    local old = root.profiles[name]
    local replacement = adopt(fresh())
    root.profiles[kept], root.profiles[name] = old, replacement
    local reload = false
    if name == self.current then
        setmetatable(old, nil)
        ns.db = nil -- activate() must not treat the replaced table as live
        activate(name)
        if ns.Options and ns.Options.ClearJournal then ns.Options:ClearJournal() end
        reload = reapply(old, replacement)
        if reload and ns.Options then ns.Options.reloadWanted = true end
    end
    fire('reset', name)
    return true, '"' .. name .. '" is back at the shipped defaults; the old settings are kept as "' .. kept .. '".'
        .. (reload and ' Reload the interface to finish applying.' or '')
end

-- Export and import -------------------------------------------------------------------
local function libraries()
    local stub = _G.LibStub
    local serialize, deflate = stub and stub('LibSerialize', true), stub and stub('LibDeflate', true)
    if not serialize or not deflate then return nil, nil, 'The export libraries did not load.' end
    return serialize, deflate
end
-- Plain data only: string or number keys; string, number, boolean or table
-- values. Returns nil, reason when the bounds are exceeded.
local function plain(value, depth, budget)
    if depth > MAX_DEPTH then return nil, 'it is nested too deeply' end
    local result = {}
    for key, child in pairs(value) do
        local keyKind, kind = type(key), type(child)
        if keyKind == 'string' or (keyKind == 'number' and key == key) then
            budget.nodes = budget.nodes + 1
            if budget.nodes > MAX_NODES then return nil, 'it holds too many values' end
            if kind == 'table' then
                local copy, reason = plain(child, depth + 1, budget)
                if not copy then return nil, reason end
                result[key] = copy
            elseif kind == 'string' or kind == 'boolean'
                or (kind == 'number' and child == child and child ~= math.huge and child ~= -math.huge) then
                result[key] = child
            end
        end
    end
    return result
end
local function exportable(profile)
    local data = plain(profile, 0, { nodes = 0 })
    if not data then return nil end
    for key in pairs(data) do if isReceipt(key) or key == 'seedPending' then data[key] = nil end end
    return data
end
function Profiles:Export(name)
    name = name or self.current
    local profile = self:Get(name)
    if not profile then return nil, 'There is no profile named "' .. tostring(name) .. '".' end
    local serialize, deflate, missing = libraries()
    if not serialize then return nil, missing end
    local data = exportable(profile)
    if not data then return nil, 'This profile is too large to export.' end
    local width, height
    if GetPhysicalScreenSize then width, height = GetPhysicalScreenSize() end
    local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata('SquanchOn', 'Version') or nil
    local payload = { format = FORMAT, kind = 'profile', addon = version, name = name,
        screen = type(data.screen) == 'table' and data.screen or (width and height and { width, height }) or nil, data = data }
    local ok, text = pcall(function()
        return PREFIX .. deflate:EncodeForPrint(deflate:CompressZlib(serialize:Serialize(payload), { level = 9 }))
    end)
    if not ok or type(text) ~= 'string' then return nil, 'The profile could not be exported.' end
    return text
end
-- Decodes and validates; never runs anything from the string. Returns the payload or nil, message.
function Profiles:Decode(text)
    if type(text) ~= 'string' then return nil, 'Paste a profile string first.' end
    text = text:gsub('%s+', '')
    if text == '' then return nil, 'Paste a profile string first.' end
    if #text > MAX_STRING then return nil, 'That string is too long to be a Squanch-On profile.' end
    if text:sub(1, #PREFIX) ~= PREFIX then
        if text:find('^!SQO%d+!') then return nil, 'That profile string was made by a newer version of Squanch-On.' end
        return nil, 'That is not a Squanch-On profile string.'
    end
    local serialize, deflate, missing = libraries()
    if not serialize then return nil, missing end
    local damaged = 'The profile string is damaged or incomplete.'
    local ok, packed = pcall(deflate.DecodeForPrint, deflate, text:sub(#PREFIX + 1))
    if not ok or type(packed) ~= 'string' then return nil, damaged end
    local good, raw = pcall(deflate.DecompressZlib, deflate, packed) -- verifies the Adler-32 checksum
    if not good or type(raw) ~= 'string' then return nil, damaged end
    if #raw > MAX_SERIALIZED then return nil, 'That profile is too large.' end
    local done, success, payload = pcall(serialize.Deserialize, serialize, raw)
    if not done or not success or type(payload) ~= 'table' then return nil, damaged end
    if payload.format ~= FORMAT then return nil, 'That profile string uses a format this version does not read.' end
    if payload.kind ~= 'profile' or type(payload.data) ~= 'table' then return nil, 'That string does not hold a whole profile.' end
    local data, reason = plain(payload.data, 0, { nodes = 0 })
    if not data then return nil, 'That profile was refused: ' .. reason .. '.' end
    for key in pairs(data) do if isReceipt(key) or key == 'seedPending' then data[key] = nil end end
    local screen = payload.screen
    if not (type(screen) == 'table' and type(screen[1]) == 'number' and type(screen[2]) == 'number'
        and screen[1] > 0 and screen[2] > 0 and screen[1] < 100000 and screen[2] < 100000) then screen = nil end
    return { name = type(payload.name) == 'string' and payload.name or nil, screen = screen and { screen[1], screen[2] } or nil, data = data }
end
-- The profile arrives under a new name and is not switched to.
function Profiles:Import(text, name)
    local payload, message = self:Decode(text)
    if not payload then return false, message end
    local checked, problem = validName((type(name) == 'string' and name:find('%S')) and name or payload.name or 'Imported')
    if not checked then return false, problem end
    checked = freeName(self.root.profiles, checked)
    local profile = payload.data
    profile.screen = payload.screen
    -- Another install's camera takeover records would restore that install's values here.
    if type(profile.camera) == 'table' then profile.camera.previous, profile.camera.receipt = nil, nil end
    adopt(profile)
    if profile.screen and ns.SeedDefaults then ns:SeedDefaults(profile) end -- fits positions to this screen
    self.root.profiles[checked] = profile
    fire('import', checked)
    return true, 'Imported as "' .. checked .. '". Select it above to use it.'
end

local events = CreateFrame('Frame')
events:RegisterEvent('PLAYER_REGEN_ENABLED')
events:SetScript('OnEvent', function()
    local name = Profiles.pending
    if not name then return end
    Profiles.pending = nil
    local _, message = Profiles:Select(name)
    if message and print then print('|cff33ff99Squanch-On|r: ' .. message) end
end)
