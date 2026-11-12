-- SPDX-License-Identifier: MIT
-- First run only: fit the shipped layout to this screen. The profile was
-- arranged on a 5120x1440 screen at UI scale 1 (2730.667 x 768 UI units).
-- Every element keeps its distance from whichever of left edge, centre or
-- right edge (bottom, middle, top) it was nearest to, then is held on screen.
-- On the authoring screen nothing is touched.
local _, ns = ...
local AUTHOR_WIDTH, AUTHOR_HEIGHT, UNITS_HIGH = 5120, 1440, 768

-- pos: low edge of the element on this axis; size 0 when unknown.
local function axis(pos, size, old, new)
    local centre = pos + size / 2
    local low, middle, high = centre, math.abs(centre - old / 2), old - centre
    if middle <= low and middle <= high then pos = pos + (new - old) / 2
    elseif high < low then pos = pos + new - old end
    return math.max(0, math.min(pos, new - size))
end
local function base(point, extent, lowName, highName)
    return point:find(lowName, 1, true) and 0 or point:find(highName, 1, true) and extent or extent / 2
end
-- A SetPoint(point, UIParent, relativePoint, x, y) pair in units of `scale`.
local function anchored(c, point, relativePoint, x, y, width, height, scale)
    scale, width, height = scale or 1, width or 0, height or 0
    local left = base(relativePoint, c.ow, 'LEFT', 'RIGHT') + x * scale - base(point, width, 'LEFT', 'RIGHT')
    local bottom = base(relativePoint, c.oh, 'BOTTOM', 'TOP') + y * scale - base(point, height, 'BOTTOM', 'TOP')
    left, bottom = axis(left, width, c.ow, c.nw), axis(bottom, height, c.oh, c.nh)
    return (left + base(point, width, 'LEFT', 'RIGHT') - base(relativePoint, c.nw, 'LEFT', 'RIGHT')) / scale,
        (bottom + base(point, height, 'BOTTOM', 'TOP') - base(relativePoint, c.nh, 'BOTTOM', 'TOP')) / scale
end
local function encoded(c, value, width, height)
    if type(value) ~= 'string' then return value end
    local point, relative, relativePoint, x, y = value:match('^([^,]+),([^,]+),([^,]+),([^,]+),([^,]+)$')
    x, y = tonumber(x), tonumber(y)
    if not x or not y or relative ~= 'UIParent' and relative ~= 'ElvUIParent' then return value end
    x, y = anchored(c, point, relativePoint, x, y, width, height)
    return string.format('%s,%s,%s,%.9g,%.9g', point, relative, relativePoint, x, y)
end

local function convert(db, physicalWidth, physicalHeight)
    if physicalWidth == AUTHOR_WIDTH and physicalHeight == AUTHOR_HEIGHT then return end
    local c = { ow = UNITS_HIGH * AUTHOR_WIDTH / AUTHOR_HEIGHT, oh = UNITS_HIGH,
        nw = UNITS_HIGH * physicalWidth / physicalHeight, nh = UNITS_HIGH }
    local oldPixels, newPixels = AUTHOR_HEIGHT / UNITS_HIGH, physicalHeight / UNITS_HIGH

    -- Layout editor records: physical pixels from the top left.
    for _, record in pairs(type(db.layout) == 'table' and db.layout.targets or {}) do
        if type(record.x) == 'number' and type(record.y) == 'number' then
            local width, height = (record.w or 0) / oldPixels, (record.h or 0) / oldPixels
            record.x = axis(record.x / oldPixels, width, c.ow, c.nw) * newPixels
            record.y = axis(record.y / oldPixels, height, c.oh, c.nh) * newPixels
            if record.w and record.h then record.w, record.h = width * newPixels, height * newPixels
            -- A window's size is only known once it is open; its owner finishes the clamp.
            else record.clampToScreen = true end
        elseif type(record.nativeAnchor) == 'table' then
            local point = record.nativeAnchor
            point[3], point[4] = anchored(c, point[1], point[2], point[3], point[4], 0, 0, record.scale)
            record.clampToScreen = true
        end
    end

    local windows = db.nativeWindowImport
    if type(windows) == 'table' and type(windows.points) == 'table' then
        for name, point in pairs(windows.points) do
            if type(point.AN) == 'string' and type(point.RE) == 'string' and type(point.PX) == 'number' and type(point.PY) == 'number' then
                local size = windows.sizes and windows.sizes[name]
                point.PX, point.PY = anchored(c, point.AN, point.RE, point.PX, point.PY, 0, 0, size and tonumber(size.SCALE))
            end
        end
        windows.clampToScreen = true
    end

    local frames = db.unitFrames
    for _, profile in pairs(type(frames) == 'table' and type(frames.profiles) == 'table' and frames.profiles or {}) do
        for key, value in pairs(type(profile.movers) == 'table' and profile.movers or {}) do
            local unit = profile.units and profile.units[key:match('^cast_(.+)$') or key]
            local size = unit and (key:match('^cast_') and unit.castbar or unit) or {}
            local width, height = tonumber(size.width), tonumber(size.height)
            if type(value) == 'table' and type(value.x) == 'number' and type(value.y) == 'number' then
                value.x, value.y = anchored(c, 'TOPLEFT', 'BOTTOMLEFT', value.x, value.y, width, height)
            else profile.movers[key] = encoded(c, value, width, height) end
        end
    end

    local tooltip = type(db.tooltipImport) == 'table' and db.tooltipImport.movers
    if type(tooltip) == 'table' then tooltip.TooltipMover = encoded(c, tooltip.TooltipMover) end
end

function ns:SeedDefaults(profile)
    local width, height = GetPhysicalScreenSize()
    if type(width) == 'number' and type(height) == 'number' and width > 0 and height > 0 then
        convert(profile, width, height)
    else profile.seedPending = true end
    return profile
end

-- Only when the screen size was unknown at load. This file loads first, so its
-- frame is registered ahead of every layout owner's PLAYER_LOGIN handler.
local events = CreateFrame('Frame')
events:RegisterEvent('PLAYER_LOGIN')
events:SetScript('OnEvent', function()
    local db = SquanchOnDB
    if type(db) ~= 'table' or not db.seedPending then return end
    db.seedPending = nil
    convert(db, GetPhysicalScreenSize())
end)
