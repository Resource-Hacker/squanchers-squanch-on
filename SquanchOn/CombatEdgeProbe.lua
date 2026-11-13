-- SPDX-License-Identifier: MIT
-- TEMPORARY DIAGNOSTIC for the combat start/end hitch. Remove this file and its
-- SquanchOn.toc line (listed first, right after the libs) when done.
--
-- One chat line per combat edge, only when Squanch-On's own work there exceeds
-- 5 ms or one of the next frames takes over 50 ms. It times Squanch-On code
-- only: its PLAYER_REGEN_* handlers as one block (from this file's frame, which
-- registers before every other Squanch-On frame, to a frame registered after
-- login), and the methods of the ns.<Module> tables during the 30 frames after
-- the edge, as self time (callees excluded). No Blizzard function, frame or
-- global is wrapped or replaced.
local addonName, ns = ...
local clock = debugprofilestop
local LABEL = { PLAYER_REGEN_DISABLED = 'start', PLAYER_REGEN_ENABLED = 'end' }
local WINDOW = 30
local SKIP = { db = true, global = true, events = true, DefaultProfile = true, Media = true }

local left, edge, edgeAt, handlers, memory = 0, nil, 0, nil, 0
local frameMs, cost, deferred = {}, {}, 0
local depth, children = 0, {}

local function done(label, start, ...)
    local spent = clock() - start
    if depth < 1 then return ... end -- a wrapped call errored earlier this frame
    local own = spent - children[depth]
    depth = depth - 1
    cost[label] = (cost[label] or 0) + own
    if depth > 0 then children[depth] = children[depth] + spent
    elseif handlers then deferred = deferred + spent end
    return ...
end

local function wrap(label, fn)
    return function(...)
        if left == 0 then return fn(...) end
        depth = depth + 1; children[depth] = 0
        return done(label, clock(), fn(...))
    end
end

local function report()
    local top = {}
    for label, ms in pairs(cost) do top[#top + 1] = { label, ms } end
    table.sort(top, function(a, b) return a[2] > b[2] end)
    local ours = (handlers or 0) + deferred
    local slowest, at = 0, 0
    for i, ms in ipairs(frameMs) do if ms > slowest then slowest, at = ms, i end end
    if ours < 5 and slowest < 50 then return end
    local names = {}
    for i = 1, math.min(5, #top) do names[i] = string.format('%s %.1f', top[i][1], top[i][2]) end
    print(string.format('|cff33ff99Squanch-On probe|r combat %s: ours %.1f ms (handlers %s, later %.1f); frames %s; slowest #%d %.0f ms; top: %s; mem %+d KB',
        edge, ours, handlers and string.format('%.1f', handlers) or '?', deferred,
        table.concat({ string.format('%.0f', frameMs[1] or 0), string.format('%.0f', frameMs[2] or 0),
            string.format('%.0f', frameMs[3] or 0) }, '/'),
        at, slowest, #names > 0 and table.concat(names, ', ') or 'none', math.floor(collectgarbage('count') - memory)))
end

local first = CreateFrame('Frame')
first:Hide()
first:RegisterEvent('PLAYER_REGEN_DISABLED')
first:RegisterEvent('PLAYER_REGEN_ENABLED')
first:RegisterEvent('ADDON_LOADED')
first:RegisterEvent('PLAYER_ENTERING_WORLD')
first:SetScript('OnEvent', function(self, event, name)
    if event == 'ADDON_LOADED' then
        if name ~= addonName then return end
        self:UnregisterEvent(event)
        -- Every file has loaded: time the module tables' methods.
        for key, module in pairs(ns) do
            if type(module) == 'table' and not SKIP[key] and type(key) == 'string' and key:match('^%u') then
                for name, fn in pairs(module) do
                    if type(fn) == 'function' and type(name) == 'string' then module[name] = wrap(key .. '.' .. name, fn) end
                end
            end
        end
        return
    elseif event == 'PLAYER_ENTERING_WORLD' then
        -- After login, so it follows the frames modules register at PLAYER_LOGIN.
        self:UnregisterEvent(event)
        local last = CreateFrame('Frame')
        last:RegisterEvent('PLAYER_REGEN_DISABLED')
        last:RegisterEvent('PLAYER_REGEN_ENABLED')
        last:SetScript('OnEvent', function() if left > 0 and not handlers then handlers = clock() - edgeAt end end)
        return
    end
    if left > 0 then report() end
    edge, edgeAt, handlers, deferred, memory = LABEL[event], clock(), nil, 0, collectgarbage('count')
    wipe(frameMs); wipe(cost)
    depth, left = 0, WINDOW
    self:Show()
end)
first:SetScript('OnUpdate', function(self, elapsed)
    frameMs[#frameMs + 1] = elapsed * 1000
    depth = 0
    left = left - 1
    if left <= 0 then
        left = 0
        self:Hide()
        report()
    end
end)
