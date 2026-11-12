-- SPDX-License-Identifier: MIT
-- Layout page: opens the layout editor (/sqedit) and exposes the two values
-- the editor keeps for the session, its grid step and the 16:9 stream guide.
local _, ns = ...
local Options = ns.Options
if not Options then return end

local function editor() return ns.LayoutEditor end
Options:Category({ id = 'layout', title = 'Layout', order = 140,
    desc = 'Move and resize the interface on a pixel grid.',
    hidden = function() return not editor() end })

-- Redraw only an editor that has been built and is showing.
local function redraw()
    local e = editor()
    if e.active and e.root then e:DrawCanvas(); e:Refresh() end
end

Options:Add('layout', {
    { id = 'layout.open', type = 'action', label = 'Move and resize the interface', button = 'Open layout editor',
        section = 'Editor', order = 10, combatSafe = false,
        desc = 'Opens the layout grid: drag a box to move it, drag a bottom corner to resize it. Same as /sqedit.',
        keywords = 'layout editor move resize position unlock sqedit',
        func = function()
            if ns.OptionsWindow and ns.OptionsWindow.frame then ns.OptionsWindow.frame:Hide() end
            if editor():Open() == false then return false, 'Layout editing is available out of combat.' end
        end },
    { id = 'layout.grid', type = 'choice', label = 'Grid step', section = 'Editor', order = 20, combatSafe = true,
        desc = 'Distance in screen pixels that dragged boxes snap to and that the grid lines are drawn at. Arrow keys still move 10 pixels, and the step returns to 10 after a reload.',
        keywords = 'grid snap step pixels',
        values = { 5, 10, 20 }, labels = { '5 px', '10 px', '20 px' }, default = 10,
        get = function() return editor().grid end,
        set = function(_, value) editor().grid = value; redraw() end },
    { id = 'layout.stream', type = 'toggle', label = '16:9 stream guide', section = 'Editor', order = 30, combatSafe = true,
        desc = 'Shades the part of an ultrawide screen that falls outside a centred 16:9 capture. Same as the guide button in the editor; it is on again after a reload.',
        keywords = 'stream guide 16:9 obs crop capture',
        default = true,
        get = function() return editor().stream and true or false end,
        set = function(_, value) editor().stream = value; redraw() end },
})
