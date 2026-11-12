-- SPDX-License-Identifier: MIT
-- Bags page: the one-window inventory beside the minimap (Bags.lua). Values
-- live sparsely in ns.db.bags; every default is Bags.defaults.
local _, ns = ...
local Options, Bags = ns.Options, ns.Bags
if not Options or not Bags then return end

local function row(key, spec)
    spec.id = 'bags.' .. key
    spec.default = Bags.defaults[key]
    spec.get = function() return Bags:Setting(key) end
    spec.set = function(_, value) Bags:Set(key, value) end
    spec.keywords = 'bag bags inventory backpack ' .. (spec.keywords or '')
    return spec
end
-- Geometry waits for combat to end (the registry queues it); cell paint does not.
local function layout() Bags:Refresh() end
local function paint() Bags:Refresh(true) end
local function fixed() return Bags:Setting('columnMode') ~= 'fixed' end
local function custom() return Bags:Setting('cellMode') ~= 'custom' end

Options:Category({ id = 'bags', title = 'Bags', order = 95,
    desc = 'One inventory window that slides out of the left side of the minimap when bags are open.' })

Options:Add('bags', {
    row('enable', { type = 'toggle', label = 'Use the one-window bag', section = 'Window', order = 10,
        desc = "Replaces the game's bag windows. Turning it off or on takes effect after /reload: the game's bags return untouched.",
        keywords = 'enable disable stock default blizzard', requiresReload = true }),
    row('anchor', { type = 'choice', label = 'Place', section = 'Window', order = 20,
        values = { 'minimap', 'free' }, labels = { 'Left of the minimap', 'Free (move it in /sqedit)' },
        desc = 'Beside the minimap it follows the map panel. Moving or resizing it in /sqedit switches to Free.',
        keywords = 'anchor position side move sqedit', apply = layout }),
    row('scale', { type = 'slider', label = 'Scale', section = 'Window', order = 30, min = 0.5, max = 2, step = 0.05,
        format = '%.2f', desc = 'Relative to the minimap panel, whose rim it shares at 1.00.', keywords = 'size bigger smaller',
        apply = layout }),
    row('animation', { type = 'toggle', label = 'Slide-out motion', section = 'Window', order = 40, combatSafe = true,
        desc = 'The empty window grows leftward out of the minimap, then its content fades in. Timing follows Windows & Drawers.',
        keywords = 'animation motion unfold slide open' }),

    row('columnMode', { type = 'choice', label = 'Columns', section = 'Grid', order = 10,
        values = { 'auto', 'fixed' }, labels = { 'Match the minimap height', 'Fixed' },
        desc = 'Match: the fewest columns whose rows fit in the height of the minimap panel.', keywords = 'columns rows width height auto',
        apply = layout }),
    row('columns', { type = 'slider', label = 'Fixed columns', section = 'Grid', order = 20, min = 4, max = 30, step = 1,
        integer = true, keywords = 'columns width', apply = layout, disabled = fixed }),
    row('cellMode', { type = 'choice', label = 'Cell size', section = 'Grid', order = 30,
        values = { 'action', 'custom' }, labels = { 'Follow the action bars', 'Custom' },
        desc = 'Follow: item icons are drawn at the size of the action-bar icons.', keywords = 'icon size cell slot',
        apply = layout }),
    row('cellSize', { type = 'slider', label = 'Custom cell size', section = 'Grid', order = 40, min = 16, max = 64, step = 1,
        integer = true, keywords = 'icon size cell slot', apply = layout, disabled = custom }),
    row('spacing', { type = 'slider', label = 'Spacing', section = 'Grid', order = 50, min = 0, max = 8, step = 1, integer = true,
        desc = '0: cells touch and share one rim line, like the action bars.', keywords = 'gap padding', apply = layout }),
    row('grouping', { type = 'choice', label = 'Grouping', section = 'Grid', order = 60,
        values = { 'none', 'class' }, labels = { 'One grid, in bag order', 'By item type, with headers' },
        desc = 'Groups are re-sorted out of combat; in combat a changed slot stays where it is.',
        keywords = 'category categories group type class headers', apply = layout }),
    row('keyring', { type = 'toggle', label = 'Include the keyring', section = 'Grid', order = 70,
        keywords = 'keys keyring', apply = function() Bags:Refresh(true, true) end,
        hidden = function() return not Bags.KeyringAvailable() end }),

    row('quality', { type = 'toggle', label = 'Quality borders', section = 'Items', order = 10, combatSafe = true,
        desc = 'A thin line in the quality colour inside the cell, for uncommon and better.', keywords = 'rarity color colour border',
        apply = paint }),
    row('newGlow', { type = 'toggle', label = 'New-item glow', section = 'Items', order = 20, combatSafe = true,
        desc = 'Glows on items picked up since you last pointed at them.', keywords = 'new glow flash', apply = paint }),
    row('junkDim', { type = 'toggle', label = 'Dim junk', section = 'Items', order = 30, combatSafe = true,
        desc = 'Poor-quality items that sell to a vendor are dimmed.', keywords = 'junk grey gray poor trash', apply = paint }),

    row('search', { type = 'toggle', label = 'Search box', section = 'Header', order = 10,
        desc = 'Dims everything that does not match by name, item type or quality (for example "epic" or "potion").',
        keywords = 'search find filter', apply = layout }),
    row('money', { type = 'toggle', label = 'Money', section = 'Header', order = 20, keywords = 'gold silver copper coins',
        apply = layout }),
    row('sort', { type = 'choice', label = 'Sort button fills from', section = 'Header', order = 30, combatSafe = true,
        values = { 'forward', 'reverse' }, labels = { 'The first bag', 'The last bag' },
        desc = "Direction used by the game's own bag clean-up when you press Sort.", keywords = 'sort clean up order direction',
        hidden = function() return not (C_Container and C_Container.SortBags) end }),
})
