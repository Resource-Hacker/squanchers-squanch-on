-- SPDX-License-Identifier: MIT
-- Graphics page: the game's level sliders on their full scale. Each row reads
-- and writes through ns.GraphicsRange, whose data table (GraphicsRange.lua)
-- decides how far past the game's top level a slider goes.
local _, ns = ...
local Options, G = ns.Options, ns.GraphicsRange
if not Options or not G then return end

Options:Category({ id = 'graphics', title = 'Graphics', order = 35,
    desc = "The game's detail sliders, continued past their top level up to what the engine accepts." })

local rows = {}
for index, selector in ipairs(G.selectors) do
    local top = selector.top + 1
    rows[#rows + 1] = { id = 'graphics.' .. selector.cvar, type = 'slider', label = selector.label, section = 'Detail',
        order = index * 10, min = 1, max = top + G:Extra(selector), step = 1, integer = true, drag = true, combatSafe = true,
        keywords = 'graphics video quality detail ' .. selector.cvar .. ' ' .. selector.label:lower(),
        desc = function() return G:Describe(selector) end,
        disabled = function() return G:Level(selector) == nil end,
        get = function() return (G:Level(selector) or selector.top) + 1 end,
        set = function(_, value) G:SetLevel(selector, value - 1) end,
        -- Right-click: back to the game's own scale.
        default = function() return math.min((G:Level(selector) or selector.top) + 1, top) end }
end
rows[#rows + 1] = { id = 'graphics.extendPanel', type = 'toggle', label = "Extend the game's own graphics sliders",
    section = 'Game settings', order = 10, combatSafe = true, default = true,
    keywords = 'graphics blizzard native settings panel slider extend',
    desc = function()
        local text = "In the game's Graphics settings, sliders with higher engine values run past 10. Off: the game's sliders stay 1 to 10 and the higher levels are set here."
        if not G:PanelAvailable() then text = text .. " Not active: this client's Graphics settings could not be extended." end
        return text
    end,
    get = function() return G:PanelEnabled() end,
    set = function(_, value) ns.db.graphicsExtendPanel = value and true or false end,
    apply = function() G:RefreshPanel() end }
rows[#rows + 1] = { id = 'graphics.reset', type = 'action', label = 'Reset to game defaults', button = 'Reset',
    section = 'Game settings', order = 20, combatSafe = true,
    desc = "Removes every level above the game's own top level and restores the game's values for it.",
    keywords = 'graphics reset default restore',
    func = function() G:Reset(); return "The game's own graphics levels are back." end }
Options:Add('graphics', rows)
