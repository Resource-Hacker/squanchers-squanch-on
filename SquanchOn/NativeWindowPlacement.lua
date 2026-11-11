-- SPDX-License-Identifier: MIT
-- Original geometry migration; no MoveAny runtime or implementation is retained.
-- The installer may seed nativeWindowImport with the enabled current profile's
-- FRAMES POINTS/SIZES plus its four enable flags. Disabled addons do not load SVs.
local _, ns = ...
local Placement = {}
ns.NativeWindowPlacement = Placement
local anchors = { TOPLEFT=true, TOP=true, TOPRIGHT=true, LEFT=true, CENTER=true,
    RIGHT=true, BOTTOMLEFT=true, BOTTOM=true, BOTTOMRIGHT=true }
local function finite(n)
    return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge
end

function Placement:Import(name, id, frame)
    if InCombatLockdown() or not ns.db then return end
    local source = ns.db.nativeWindowImport
    if type(source) ~= 'table' or type(source.profile) ~= 'string' then return end
    ns.db.nativeWindowMigration = ns.db.nativeWindowMigration or {}
    if ns.db.nativeWindowMigration[id] then return end
    local editor = ns.LayoutEditor
    local record = editor:Copy(editor:Read(id))
    -- Existing Squancher edits win. A profile-bound record is converted only
    -- when the installer supplied the exact profile that owned those edits.
    if record then
        if record.moveAnyProfile and record.moveAnyProfile ~= source.profile then return end
        record.moveAnyProfile = nil
        record.importedGeometry = true
        editor:Store(id, record)
        ns.db.nativeWindowMigration[id] = source.profile
        return
    end
    local point = source.moveFrames and source.savePosition and source.points and source.points[name]
    local size = source.scaleFrames and source.saveScale and source.sizes and source.sizes[name]
    local scale = size and size.SCALE
    if not finite(scale) or scale <= 0 then scale = frame:GetScale() end
    local positioned = type(point) == 'table' and anchors[point.AN] and anchors[point.RE]
        and finite(point.PX) and finite(point.PY)
    local scaled = size and finite(size.SCALE) and size.SCALE > 0
    if positioned or scaled then
        record = {scale = scale, importedGeometry = true}
        if positioned then
            -- Same UIParent anchor/scale coordinate convention as the native
            -- SetPoint API; convert to editor physical pixels on the next edit.
            record.nativeAnchor = {point.AN, point.RE, point.PX, point.PY}
        else
            local rect = editor:Rect(frame)
            if not rect then return end
            record.x, record.y = rect.x, rect.y
        end
        if frame == WorldMapFrame then record.nativeScale = frame:GetScale() end
        editor:Store(id, record)
    end
    ns.db.nativeWindowMigration[id] = source.profile
end
