-- SPDX-License-Identifier: MIT
-- Damage meter page: the drawer on the right of the minimap panel
-- (MeterDrawer.lua). Values live in ns.db.meter.
local _, ns = ...
local Options, Meter = ns.Options, ns.MeterDrawer
if not Options or not Meter then return end

Options:Root('meter', function() return Meter:Settings() end)
Options:Category({ id = 'meter', title = 'Damage meter', order = 90,
    desc = "A drawer that slides out of the minimap panel's right edge and makes it as wide as the chat panel. It shows the game's own combat totals." })

local defaults = Meter.defaults
local function apply() Meter:Apply() end
local list = {}
local function add(key, option)
    option.id = 'meter.' .. key
    option.root, option.path, option.default = 'meter', key, defaults[key]
    option.combatSafe = true -- plain frames only
    if option.apply == nil then option.apply = apply end
    option.keywords = 'dps damage meter ' .. (option.keywords or '')
    list[#list + 1] = option
end

add('enabled', { type = 'toggle', label = 'Damage meter drawer', section = 'Drawer', order = 10,
    desc = "Shows the arrow on the minimap panel's right edge. Click it to open or close the meter." })
add('autoOpen', { type = 'toggle', label = 'Open when combat starts', section = 'Drawer', order = 20,
    keywords = 'auto combat open' })
add('autoClose', { type = 'slider', label = 'Close after combat', section = 'Drawer', order = 30,
    min = 0, max = 60, step = 1, integer = true, format = '%.0f s',
    desc = 'Seconds after combat ends before a drawer that combat opened closes again. 0 keeps it open.',
    keywords = 'auto combat close delay' })
add('animate', { type = 'toggle', label = 'Slide open', section = 'Drawer', order = 40,
    desc = 'Plays the drawer motion set under Windows & Drawers. Off: the drawer opens at once.',
    keywords = 'animation motion slide unfold' })

add('mode', { type = 'choice', label = 'Shows', section = 'Meter', order = 10,
    values = Meter.modeValues, labels = Meter.modeLabels, keywords = 'mode damage healing dps hps interrupts dispels deaths' })
add('segment', { type = 'choice', label = 'Fight', section = 'Meter', order = 20,
    values = { 'current', 'overall' }, labels = { 'Current', 'Overall' },
    desc = "Earlier fights are picked from the drawer's own menu.", keywords = 'segment session current overall' })

add('texture', { type = 'statusbar', label = 'Bar texture', section = 'Bars', order = 10, keywords = 'statusbar texture' })
add('barHeight', { type = 'slider', label = 'Bar height', section = 'Bars', order = 20,
    min = 8, max = 40, step = 1, integer = true, keywords = 'row size height' })
add('classColors', { type = 'toggle', label = 'Class colours', section = 'Bars', order = 30,
    desc = 'Off: every bar uses the theme gold.', keywords = 'class color colour' })
add('showRank', { type = 'toggle', label = 'Rank number', section = 'Bars', order = 40, keywords = 'rank position number' })
add('showPerSecond', { type = 'toggle', label = 'Second value in brackets', section = 'Bars', order = 50,
    desc = 'The per-second rate beside a total, or the total beside a rate.', keywords = 'per second dps hps total' })
add('showPercent', { type = 'toggle', label = 'Share of the total', section = 'Bars', order = 60,
    desc = 'Appears out of combat only: the game hides the amounts from addons while you fight.',
    keywords = 'percent percentage share' })

add('hideNative', { type = 'toggle', label = "Hide the game's own meter", section = 'Game meter', order = 10,
    desc = "Hides the game's meter window while it keeps collecting the data shown here. Turned off, it returns out of combat; /reload gives the exact stock state.",
    keywords = 'blizzard default native hide' })

Options:Add('meter', list)
