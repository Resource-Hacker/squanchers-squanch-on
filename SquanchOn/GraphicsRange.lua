-- SPDX-License-Identifier: MIT
-- Graphics range (ns.GraphicsRange): lets the game's graphics sliders run past
-- their own top level, up to what the engine accepts, so nothing is reachable
-- only through console variables.
--
-- The game's sliders (View Distance, Environment Detail, Ground Clutter) store a
-- level 0..9 in a selector CVar; the client then sets the engine CVars for that
-- level itself. Extra steps above the top level are Squanch-On's: each step
-- interpolates the engine CVars linearly from the client's top-level value to
-- the extended maximum in the table below. The extra steps chosen are kept in
-- ns.db.graphics[selector] and exist only while the selector sits at its top
-- level; a lower level, from any source, drops them.
--
-- Nothing is written until the owner moves a slider past the game's top level.
-- Only the normal CVars are written: the RAID*/raidGraphics* variants, which the
-- client applies in raids and battlegrounds when raid settings are on, are left
-- alone.
--
-- The dropdown selectors (shadows, liquid, particles, SSAO, depth and compute
-- effects, outline, textures, spell density, projected textures) are enums whose
-- top entry already is the engine's highest mode; they have no rows here.
local _, ns = ...
local G = { panel = {}, watched = {} }
ns.GraphicsRange = G

-- DATA TABLE. One row per engine CVar:
--   low = client value at level 0, top = client value at the selector's top
--   level, max = extended maximum. max = nil means "needs probe": that CVar is
--   never written. A selector with no max at all gets no extra steps.
-- `extra` is the number of steps added above the game's top level.
-- Sources: [m] measured on this client, [c] this client's Config.wtf at level 9
-- (confirm with the level probe), [w] warcraft.wiki.gg CVar page (not yet
-- confirmed on this client).
G.selectors = {
    { cvar = 'graphicsGroundClutter', key = 'GroundClutter', label = 'Ground clutter', top = 9, extra = 10, engine = {
        { 'groundEffectDensity', low = 16, top = 48, max = 256 },   -- [m] probed: 256 accepted, 257 refused
        { 'groundEffectDist', low = 40, top = 320, max = 500 },     -- [m] probed: 500 accepted, 501 refused
    } },
    { cvar = 'graphicsViewDistance', key = 'ViewDistance', label = 'View distance', top = 9, extra = 10, engine = {
        { 'farclip', low = nil, top = 10000, max = 19600 },         -- top [c]; max [w]
        { 'horizonStart', low = nil, top = 4000, max = 5600 },      -- top [c]; max [w]
        { 'horizonClip', low = nil, top = 10000, max = 19600 },     -- top [c]; not range-checked by the client; kept with farclip
    } },
    { cvar = 'graphicsEnvironmentDetail', key = 'EnvironmentDetail', label = 'Environment detail', top = 9, extra = 10, engine = {
        { 'lodObjectCullSize', low = nil, top = 14, max = 1 },      -- top [c]; smaller draws more; probed: 1 accepted, 0 refused
        { 'lodObjectFadeScale', low = nil, top = 150, max = 400 },  -- top [c]; probed: accepted to 2000; 400 chosen
        { 'doodadLodScale', low = nil, top = 150, max = 300 },      -- top [c]; not range-checked by the client; 300 chosen
        { 'terrainLodDist', low = nil, top = 650, max = 2000 },     -- top [c]; [w] range 128-5248; not range-checked; 2000 chosen
        { 'wmoLodDist', low = nil, top = 400, max = nil },          -- top [c]; needs probe
    } },
}
G.bySelector, G.byEngine = {}, {}
for _, selector in ipairs(G.selectors) do
    G.bySelector[selector.cvar] = selector
    for _, row in ipairs(selector.engine) do G.byEngine[row[1]] = selector end
end

local function getCVar(name)
    local get = (C_CVar and C_CVar.GetCVar) or GetCVar
    return get and get(name)
end
local function store(create)
    local db = ns.db
    if not db then return nil end
    if create and type(db.graphics) ~= 'table' then db.graphics = {} end
    return type(db.graphics) == 'table' and db.graphics or nil
end
local function round(value) return math.floor(value + 0.5) end

-- Extra steps this selector offers: none until at least one maximum is known.
function G:Extra(selector)
    for _, row in ipairs(selector.engine) do
        if row.max and row.top then return selector.extra end
    end
    return 0
end
-- Stored extra steps, clamped to the table.
function G:Stored(selector)
    local saved = store()
    local extra = saved and tonumber(saved[selector.cvar]) or 0
    return math.max(0, math.min(self:Extra(selector), round(extra)))
end
-- Engine value of one row at `extra` steps above the top level; nil = not written.
function G:Value(selector, row, extra)
    if not row.max or not row.top then return nil end
    extra = math.max(0, math.min(selector.extra, extra))
    return round(row.top + (row.max - row.top) * extra / selector.extra)
end
-- Level on the single scale 0 .. top + Extra; nil when the selector CVar is absent.
function G:Level(selector)
    local level = tonumber(getCVar(selector.cvar))
    if not level then return nil end
    if level >= selector.top then return selector.top + self:Stored(selector) end
    return level
end

-- Writes one CVar unless it already holds the value. Secure CVars wait for the
-- end of combat. Returns false when the write was put off.
function G:Write(name, value)
    local current = getCVar(name)
    if current == nil then return true end -- not a CVar of this client
    if tonumber(current) == value then return true end
    -- The client answered this same write with what it holds now (a clamp or
    -- a refusal): writing again would only repeat on its CVAR_UPDATE, every frame.
    local kept = self.kept and self.kept[name]
    if kept and kept.value == value and kept.held == current then return true end
    local secure = C_CVar and C_CVar.GetCVarInfo and select(6, C_CVar.GetCVarInfo(name))
    if secure and InCombatLockdown and InCombatLockdown() then self.deferred = true; return false end
    local set = (C_CVar and C_CVar.SetCVar) or SetCVar
    self.writing = true
    pcall(set, name, tostring(value))
    self.writing = false
    local held = getCVar(name)
    if tonumber(held) ~= value then
        self.kept = self.kept or {}
        self.kept[name] = { value = value, held = held }
    end
    return true
end
-- Engine CVars for the stored extra steps (extra 0 = the client's top values).
function G:Apply(selector, extra)
    if tonumber(getCVar(selector.cvar)) ~= selector.top then return end
    for _, row in ipairs(selector.engine) do
        local value = self:Value(selector, row, extra or self:Stored(selector))
        if value then self:Write(row[1], value) end
    end
end
local function save(selector, extra)
    local saved = store(extra ~= nil)
    if saved then saved[selector.cvar] = extra end
    if saved and next(saved) == nil then ns.db.graphics = nil end
end
-- Drops the extra steps; at the top level the client's own values come back.
function G:Clear(selector)
    if self:Stored(selector) > 0 then self:Apply(selector, 0) end
    save(selector, nil)
end

-- Sets a level on the single scale. `setLevel(level)` writes the game's own
-- level (the panel passes its setting; default: the selector CVar directly).
function G:SetLevel(selector, level, setLevel)
    level = math.max(0, math.min(selector.top + self:Extra(selector), round(level)))
    setLevel = setLevel or function(value) self:Write(selector.cvar, value) end
    if level > selector.top then
        save(selector, level - selector.top)
        setLevel(selector.top)
        self:Apply(selector)
        self:Queue() -- once more next frame, after the client's own preset for the top level
    else
        self:Clear(selector)
        setLevel(level)
    end
    self:Changed()
end
-- Back to the game's own mapping for every selector.
function G:Reset()
    for _, selector in ipairs(self.selectors) do self:Clear(selector) end
    if ns.db then ns.db.graphics = nil end
    self:Changed()
end

-- After a login, a preset change or combat: keep stored steps applied, and
-- forget them where the game's level has gone below its top.
function G:Reconcile()
    self.queued, self.deferred = false, false
    for _, selector in ipairs(self.selectors) do
        if self:Stored(selector) > 0 then
            local level = tonumber(getCVar(selector.cvar))
            if level and level < selector.top then save(selector, nil) else self:Apply(selector) end
        end
    end
    self:Changed()
end
function G:Queue()
    if self.queued then return end
    self.queued = true
    if C_Timer and C_Timer.After then C_Timer.After(0, function() self:Reconcile() end) else self:Reconcile() end
end
function G:Changed()
    self:SyncPanel()
    if ns.Options and ns.Options.Fire then ns.Options:Fire(nil, nil, 'graphics') end
end

-- Text for tooltips and the options page: what the extra steps set, and now.
function G:Describe(selector)
    local ranged, current, unknown = {}, {}, {}
    for _, row in ipairs(selector.engine) do
        if row.max and row.top then ranged[#ranged + 1] = string.format('%s %s to %s', row[1], row.top, row.max)
        else unknown[#unknown + 1] = row[1] end
        local value = getCVar(row[1])
        if value then current[#current + 1] = row[1] .. ' ' .. value end
    end
    local top, text = selector.top + 1, nil
    if #ranged > 0 then
        text = string.format("Levels 1 to %d are the game's own. Levels %d to %d raise %s.", top, top + 1,
            top + selector.extra, table.concat(ranged, ', '))
    else
        text = string.format("Levels 1 to %d are the game's own. No higher engine values are established yet.", top)
    end
    if #unknown > 0 then text = text .. ' Not extended until measured: ' .. table.concat(unknown, ', ') .. '.' end
    if #current > 0 then text = text .. ' Now: ' .. table.concat(current, ', ') .. '.' end
    return text
end

-- The game's Graphics panel ---------------------------------------------------
-- The game's slider and its setting stay untouched (they only accept 0..9). An
-- identical slider owned by Squanch-On, from the same template, takes its place
-- with the longer scale: levels up to the top go to the game's setting as usual
-- (pending until Apply), higher ones apply at once.
function G:PanelEnabled()
    return not (ns.db and ns.db.graphicsExtendPanel == false)
end
function G:PanelAvailable()
    return self.panelHooked == true and not self.panelError
end
local function panelLevel(selector, setting)
    local level = tonumber(setting:GetValue()) or 0
    if level >= selector.top then return selector.top + G:Stored(selector) end
    return level
end
function G:SyncPanel()
    if not self.settings then return end
    for cvar, slider in pairs(self.panel) do
        local setting = self.settings[cvar]
        if setting and slider:IsShown() then
            self.syncing = true
            pcall(slider.SetValue, slider, panelLevel(self.bySelector[cvar], setting))
            self.syncing = false
        end
    end
end
local function buildPanelSlider(selector, control, setting)
    local native = control.SliderWithSteppers
    local slider = CreateFrame('Frame', nil, control, 'MinimalSliderWithSteppersTemplate')
    slider:SetAllPoints(native)
    slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        if G.syncing then return end
        local live = G.settings and G.settings[selector.cvar]
        if not live then return end
        G:SetLevel(selector, value, function(level) live:SetValue(level, level == selector.top and G:Stored(selector) > 0) end)
    end, G)
    slider.Slider:HookScript('OnEnter', function(owner)
        if not GameTooltip then return end
        GameTooltip:SetOwner(owner, 'ANCHOR_TOP')
        GameTooltip:SetText(selector.label, 1, 1, 1)
        GameTooltip:AddLine(G:Describe(selector), nil, nil, nil, true)
        GameTooltip:Show()
    end)
    slider.Slider:HookScript('OnLeave', function() if GameTooltip then GameTooltip:Hide() end end)
    if not G.watched[selector.cvar] and Settings and Settings.SetOnValueChangedCallback then
        G.watched[selector.cvar] = true
        Settings.SetOnValueChangedCallback(setting:GetVariable(), function() G:SyncPanel() end, G)
    end
    return slider
end
function G:RefreshPanel()
    local controls, settings = self.controls, self.settings
    if not controls or not settings then return end
    for _, selector in ipairs(self.selectors) do
        local control, setting = controls[selector.key], settings[selector.cvar]
        local native = control and control.SliderWithSteppers
        if native and setting then
            local slider = self.panel[selector.cvar]
            if self:PanelEnabled() and self:Extra(selector) > 0 and not self.panelError then
                if not slider or slider:GetParent() ~= control then
                    slider = buildPanelSlider(selector, control, setting)
                    self.panel[selector.cvar] = slider
                end
                local last = selector.top + self:Extra(selector)
                self.syncing = true
                slider:Init(panelLevel(selector, setting), 0, last, last,
                    { [MinimalSliderWithSteppersMixin.Label.Right] = function(value) return round(value) + 1 end })
                self.syncing = false
                slider:Show(); native:Hide()
            else
                if slider then slider:Hide() end
                native:Show()
            end
        end
    end
end
function G:InstallPanel()
    if self.panelHooked then return end
    local mixin = _G.SettingsAdvancedQualityControlsMixin
    if type(mixin) ~= 'table' or type(mixin.Init) ~= 'function' or not hooksecurefunc
        or type(_G.MinimalSliderWithSteppersMixin) ~= 'table' then return end
    -- Frames copy the mixin when they are created, which happens the first time
    -- the Graphics page is shown, so this hook reaches them.
    hooksecurefunc(mixin, 'Init', function(controls, settings, raid)
        if raid or type(settings) ~= 'table' then return end
        G.controls, G.settings = controls, settings
        local ok, err = pcall(G.RefreshPanel, G)
        if not ok then -- leave the game's own sliders in charge
            G.panelError = tostring(err)
            pcall(G.RefreshPanel, G)
        end
    end)
    self.panelHooked = true
end

local events = CreateFrame('Frame')
events:RegisterEvent('PLAYER_LOGIN')
events:RegisterEvent('PLAYER_ENTERING_WORLD')
events:RegisterEvent('PLAYER_REGEN_ENABLED')
events:RegisterEvent('CVAR_UPDATE')
events:SetScript('OnEvent', function(_, event, name)
    if event == 'PLAYER_LOGIN' then
        G:InstallPanel()
    elseif event == 'PLAYER_ENTERING_WORLD' then
        G.ready = true
        G:Queue()
    elseif event == 'PLAYER_REGEN_ENABLED' then
        if G.deferred then G:Queue() end
    elseif G.ready and not G.writing and store()
        and (name == 'graphicsQuality' or G.bySelector[name] or G.byEngine[name]) then
        G:Queue() -- the client set a level or re-applied its preset
    end
end)
