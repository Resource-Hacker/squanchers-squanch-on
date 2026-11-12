-- SPDX-License-Identifier: MIT
-- Camera pages: every standard setting (with its optional zoom curve), the
-- wheel-zoom parameters and the situations, declared for the settings window.
-- Values are read from and written to Camera:Config(); each change ends in
-- Camera:SettingsChanged(), the module's own apply path. The camera defers the
-- CVar writes the client refuses in combat itself, so rows are combat-safe.
local _, ns = ...
local Options, Camera = ns.Options, ns.Camera
if not Options or not Camera then return end

local shippedCache
local function shipped()
    shippedCache = shippedCache or Camera:ShippedDefaults()
    return shippedCache
end
local function config()
    local cfg = Camera:Config()
    if not cfg then error('The camera settings load at login.', 0) end
    return cfg
end
local function changed() Camera:SettingsChanged() end
local function notReady() return not Camera:Config() end
local function dynamicCamLoaded()
    return _G.DynamicCam ~= nil or (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded('DynamicCam')) or false
end
local SHARED = { idPrefix = 'camera.', combatSafe = true, apply = changed, disabled = notReady }

-- label, description, search words, slider step
local META = {
    test_cameraOverShoulder = { 'Shoulder offset', 'Moves the camera sideways off the character: positive to the right, negative to the left.',
        'shoulder over offset sideways right left actioncam', 0.05 },
    cameraFov = { 'Field of view', 'Camera viewing angle in degrees, limited to the range the client allows.',
        'fov field view angle wide narrow', 1 },
    cameraDistanceMaxZoomFactor = { 'Maximum zoom factor', 'How far the camera may zoom out, as a multiple of 15 yards.',
        'max maximum zoom distance far out factor' },
    cameraZoomSpeed = { 'Zoom speed', 'How fast the camera travels to a new zoom distance, in yards per second.',
        'zoom speed fast slow' },
    test_cameraHeadMovementStrength = { 'Head movement', "The camera follows the motion of the character's head.",
        'head movement bob tracking actioncam' },
    test_cameraHeadMovementStandingStrength = { 'Standing strength', 'How strongly the camera follows the head while the character stands still.',
        'head standing strength', 0.01 },
    test_cameraHeadMovementStandingDampRate = { 'Standing damp rate', 'Smoothing rate of head following while the character stands still.',
        'head standing damp smoothing', 0.1 },
    test_cameraHeadMovementMovingStrength = { 'Moving strength', 'How strongly the camera follows the head while the character moves.',
        'head moving strength', 0.01 },
    test_cameraHeadMovementMovingDampRate = { 'Moving damp rate', 'Smoothing rate of head following while the character moves.',
        'head moving damp smoothing', 0.1 },
    test_cameraHeadMovementFirstPersonDampRate = { 'First-person damp rate', 'Smoothing rate of head following in first person.',
        'head first person damp smoothing' },
    test_cameraHeadMovementRangeScale = { 'Range scale', 'Scales the range of camera distances over which head movement applies.',
        'head range scale distance' },
    test_cameraHeadMovementDeadZone = { 'Dead zone', 'Amount of head motion the camera ignores before it starts to follow.',
        'head dead zone threshold' },
    test_cameraDynamicPitch = { 'Dynamic pitch', 'Pitches the camera up so the character sits lower on the screen; this moves the aim point relative to the reticle.',
        'dynamic pitch tilt aim reticle actioncam' },
    test_cameraDynamicPitchBaseFovPad = { 'Base FoV pad', 'Share of the view kept below the character; larger values pitch the camera up further.',
        'pitch pad fov base', 0.01 },
    test_cameraDynamicPitchBaseFovPadFlying = { 'Base FoV pad (flying)', 'The same pad while the character is flying.',
        'pitch pad fov flying', 0.01 },
    test_cameraDynamicPitchBaseFovPadDownScale = { 'Base FoV pad down scale', 'Scales the pad while the camera looks down on the character.',
        'pitch pad down scale', 0.01 },
    test_cameraDynamicPitchSmartPivotCutoffDist = { 'Smart pivot cutoff distance', "Distance setting of the client's smart pivot, which changes how the camera pitches when it meets the ground.",
        'pitch smart pivot cutoff distance ground' },
    test_cameraTargetFocusEnemyEnable = { 'Enemy target focus', 'Turns the camera toward your enemy target; this moves the aim point relative to the reticle.',
        'target focus tracking enemy aim reticle actioncam' },
    test_cameraTargetFocusEnemyStrengthYaw = { 'Enemy yaw strength', 'How strongly the camera turns sideways toward an enemy target.',
        'target focus tracking enemy yaw sideways strength', 0.01 },
    test_cameraTargetFocusEnemyStrengthPitch = { 'Enemy pitch strength', 'How strongly the camera tilts up or down toward an enemy target.',
        'target focus tracking enemy pitch tilt strength', 0.01 },
    test_cameraTargetFocusInteractEnable = { 'Interact target focus', 'Turns the camera toward the character you are interacting with; this moves the aim point relative to the reticle.',
        'target focus tracking interact npc aim reticle actioncam' },
    test_cameraTargetFocusInteractStrengthYaw = { 'Interact yaw strength', 'How strongly the camera turns sideways toward the character you are interacting with.',
        'target focus tracking interact npc yaw sideways strength', 0.01 },
    test_cameraTargetFocusInteractStrengthPitch = { 'Interact pitch strength', 'How strongly the camera tilts up or down toward the character you are interacting with.',
        'target focus tracking interact npc pitch tilt strength', 0.01 },
    cameraYawMoveSpeed = { 'Yaw (turn) speed', 'Sideways camera turning speed, in degrees per second.',
        'yaw turn speed rotate sideways' },
    cameraPitchMoveSpeed = { 'Pitch speed', 'Up and down camera turning speed, in degrees per second.',
        'pitch speed rotate up down' },
}

local function toPoints(curve)
    if type(curve) ~= 'table' then return nil end
    local points = {}
    for index, point in ipairs(curve) do points[index] = { x = point.zoom, y = point.value } end
    return points
end

-- The rows of one camera setting: its value and, where it may follow a zoom
-- curve, the "follow zoom" switch and the curve. entryOf(ctx, forWrite) returns
-- the stored { value, curve, curveOn } table, shippedOf(ctx) the shipped one;
-- gate(ctx) hides the rows (a situation that does not override the setting).
local function settingRows(list, def, section, entryOf, shippedOf, gate)
    local name, meta = def.name, META[def.name]
    local value = { key = name, label = meta[1], desc = meta[2], keywords = meta[3], section = section, hidden = gate,
        get = function(ctx)
            local entry = entryOf(ctx)
            if not entry then return nil end
            if def.toggle then return (entry.value or 0) ~= 0 end
            return entry.value
        end,
        set = function(ctx, new)
            if def.toggle then new = new and 1 or 0 end
            entryOf(ctx, true).value = new
        end,
        default = function(ctx)
            local entry = shippedOf(ctx)
            if def.toggle then return ((entry and entry.value) or 0) ~= 0 end
            return entry and entry.value
        end }
    if def.toggle then value.type = 'toggle'
    elseif def.min then
        -- The slider track spans the curve range; only FoV is clamped above it,
        -- as in the camera itself (fixed values may exceed the track by typing).
        value.type, value.min, value.max, value.softMax = 'slider', def.min, def.clampFixed and def.max or nil, def.max
        value.step, value.drag = meta[4], true
    else value.type, value.step = 'number', 0.01 end
    list[#list + 1] = value
    if not def.min then return end

    list[#list + 1] = { key = name .. '.follow', type = 'toggle', label = meta[1] .. ' follows zoom', section = section, hidden = gate,
        desc = meta[1] .. ' takes its value from the zoom curve below instead of the fixed value.',
        keywords = meta[3] .. ' follow zoom curve',
        get = function(ctx) local entry = entryOf(ctx); return entry and entry.curveOn == true or false end,
        set = function(ctx, on)
            local entry = entryOf(ctx, true)
            entry.curveOn = on
            if on and not (entry.curve and #entry.curve >= 2) then
                local fixed = entry.value or Camera.Resolve(name, 0) or 0
                entry.curve = { { zoom = 0, value = fixed }, { zoom = 25, value = fixed } }
            end
        end,
        default = function(ctx) local entry = shippedOf(ctx); return entry and entry.curveOn == true or false end }
    list[#list + 1] = { key = name .. '.curve', type = 'curve', label = meta[1] .. ' by zoom distance', section = section,
        desc = 'Value at each zoom distance in yards: linear between the rows, flat before the first and after the last.',
        keywords = meta[3] .. ' zoom curve points',
        xLabel = 'Zoom', yLabel = 'Value', xMin = 0, xMax = 50, yMin = def.min, yMax = def.max, minPoints = 2, step = 5,
        hidden = function(ctx)
            local entry = entryOf(ctx)
            return not (entry and entry.curveOn) or (gate and gate(ctx)) or false
        end,
        get = function(ctx) local entry = entryOf(ctx); return entry and toPoints(entry.curve) end,
        set = function(ctx, points)
            local curve = {}
            for index, point in ipairs(points or {}) do curve[index] = { zoom = point.x, value = point.y } end
            entryOf(ctx, true).curve = curve
        end,
        default = function(ctx)
            local entry = shippedOf(ctx)
            if not entry then return nil end
            if entry.curve and #entry.curve >= 2 then return toPoints(entry.curve) end
            if entry.value == nil then return nil end
            return { { x = 0, y = entry.value }, { x = 25, y = entry.value } }
        end }
end

-- Camera (root page): status and the /sqms camera commands ------------------
Options:Category({ id = 'camera', title = 'Camera', order = 30,
    desc = "Squanch-On's own camera: shoulder offset, field of view, eased zoom and situations.",
    keywords = 'camera dynamiccam actioncam' })

local function command(name, done)
    return function() Camera:Command(name); return done end
end
Options:Add('camera', {
    { id = 'camera.status', type = 'note', label = 'Status', section = 'Status', keywords = 'status active waiting off dynamiccam',
        text = function()
            local cfg = Camera:Config()
            if not cfg then return 'The camera settings load at login.' end
            local state = Camera.active and 'Active: Squanch-On drives the camera.'
                or Camera.blocked and 'Waiting: DynamicCam is loaded and owns the camera. Use "Take over" to switch.'
                or 'Off: the camera CVars are left alone.'
            local current = Camera:CurrentSituation()
            return state .. '\nSituation: ' .. (current and current.name or 'none') .. '. Settings from: '
                .. tostring(cfg.receipt and cfg.receipt.source or 'unknown') .. '.'
        end },
    { id = 'camera.enabled', type = 'toggle', label = 'Squanch-On drives the camera', section = 'Status',
        desc = 'Turns the camera module on or off, leaving the camera CVars as they are. Same as /sqms camera on and off.',
        keywords = 'camera enable disable on off', default = true, combatSafe = true, disabled = notReady,
        get = function() local cfg = Camera:Config(); return cfg and cfg.enabled == true or false end,
        set = function(_, on) config().enabled = on end,
        apply = function(_, on) if on then Camera:Enable() else Camera:Disable(false) end end },

    { id = 'camera.takeover', type = 'action', label = 'Take over from DynamicCam', button = 'Take over', section = 'DynamicCam',
        desc = 'Imports the DynamicCam profile if needed and disables DynamicCam; a reload then lets Squanch-On drive. Same as /sqms camera takeover.',
        keywords = 'takeover take over dynamiccam disable import',
        disabled = function() return notReady() or not dynamicCamLoaded() end,
        func = command('takeover', 'DynamicCam disabled; reload to let Squanch-On drive the camera.') },
    { id = 'camera.capture', type = 'action', label = 'Capture DynamicCam settings', button = 'Capture', section = 'DynamicCam',
        desc = "Imports DynamicCam's selected profile again and records the live values. Same as /sqms camera capture.",
        keywords = 'capture import dynamiccam profile', confirm = 'This replaces the camera settings with the DynamicCam profile.',
        disabled = function() return notReady() or not dynamicCamLoaded() end,
        func = command('capture', 'See chat for the capture result.') },
    { id = 'camera.release', type = 'action', label = 'Release to DynamicCam', button = 'Release', section = 'DynamicCam',
        desc = 'Turns the camera off, restores the earlier CVars and enables DynamicCam again; then reload. Same as /sqms camera release.',
        keywords = 'release dynamiccam enable give back', confirm = 'This turns the Squanch-On camera off and enables DynamicCam.',
        disabled = notReady, func = command('release', 'Camera off and restored; reload to hand over to DynamicCam.') },

    { id = 'camera.restore', type = 'action', label = 'Restore the earlier camera', button = 'Restore', section = 'Recovery',
        desc = 'Turns the camera off and writes back the camera CVars recorded before the first takeover. Same as /sqms camera restore.',
        keywords = 'restore revert cvars before off', confirm = 'This turns the camera off and restores the earlier CVars.',
        disabled = notReady, func = command('restore', 'Camera off; the earlier camera CVars are back.') },
    { id = 'camera.defaults', type = 'action', label = 'Shipped camera defaults', button = 'Load defaults', section = 'Recovery',
        desc = 'Replaces every camera setting and situation with the values Squanch-On ships.',
        keywords = 'reset defaults shipped all', confirm = 'This replaces every camera setting and situation.',
        disabled = notReady, func = function() Camera:Reset(); return 'Shipped camera defaults loaded.' end },
})

-- Standard settings, one page per group ------------------------------------
local AIM_NOTE = 'These settings move the aim point relative to the reticle.'
local PAGES = {
    { 'shoulder', 'Shoulder offset', 'Sideways camera offset, fixed or following the zoom distance.', 'Offset' },
    { 'fov', 'Field of view', 'Viewing angle, fixed or following the zoom distance.', 'Field of view' },
    { 'zoom', 'Zoom', 'Eased wheel zoom, the zoom limit and the zoom speed.', 'Limits' },
    { 'head', 'Head movement', "How the camera follows the character's head.", 'Head movement' },
    { 'pitch', 'Dynamic pitch', 'Pitches the camera up as it zooms.', 'Dynamic pitch', AIM_NOTE },
    { 'focus', 'Target focus', 'Target tracking: turns the camera toward an enemy or interaction target.', nil, AIM_NOTE },
    { 'speeds', 'Speeds', 'Camera turning speeds.', 'Turn speeds' },
}
local function standardEntry(name)
    return function()
        local cfg = Camera:Config()
        return cfg and cfg.standard[name]
    end, function() return shipped().standard[name] end
end
local function zoomField(key, spec)
    spec.key = 'zoom.' .. key
    spec.get = function() local cfg = Camera:Config(); return cfg and cfg.zoom[key] end
    spec.set = function(_, value) config().zoom[key] = value end
    spec.default = function() return shipped().zoom[key] end
    return spec
end

for index, page in ipairs(PAGES) do
    local group, id = page[1], 'camera.' .. page[1]
    Options:Category({ id = id, parent = 'camera', title = page[2], desc = page[3], order = index * 10 })
    local rows = {}
    if page[5] then
        rows[#rows + 1] = { key = group .. '.note', type = 'note', label = 'Aim point', text = page[5], keywords = 'aim point reticle' }
    end
    if group == 'zoom' then
        local wheel = 'Wheel zoom'
        rows[#rows + 1] = zoomField('reactive', { type = 'toggle', label = 'Eased wheel zoom', section = wheel,
            desc = 'Each wheel notch glides to its new distance instead of jumping.', keywords = 'reactive smooth eased wheel zoom' })
        rows[#rows + 1] = zoomField('addAlways', { type = 'slider', label = 'Extra yards per wheel notch', section = wheel, min = 0, max = 10, step = 0.1,
            desc = 'Yards added to the one yard a wheel notch moves the camera.', keywords = 'wheel notch increment yards step' })
        rows[#rows + 1] = zoomField('addIncrements', { type = 'slider', label = 'Further yards while behind', section = wheel, min = 0, max = 10, step = 0.1,
            desc = 'Yards added per notch while the camera is still catching up with earlier notches.', keywords = 'wheel notch catch up faster yards' })
        rows[#rows + 1] = zoomField('incAddDifference', { type = 'slider', label = 'Behind by more than (yards)', section = wheel, min = 0.1, max = 10, step = 0.1,
            desc = 'How far the camera must lag its target before the further yards are added.', keywords = 'wheel notch catch up threshold difference' })
        rows[#rows + 1] = zoomField('maxZoomTime', { type = 'slider', label = 'Longest ease time (seconds)', section = wheel, min = 0, max = 5, step = 0.05,
            desc = 'Upper limit for the time one eased zoom takes.', keywords = 'zoom time duration ease seconds' })
        rows[#rows + 1] = zoomField('easing', { type = 'choice', label = 'Wheel easing', section = wheel, values = Camera.EASINGS,
            desc = 'Shape of the eased wheel zoom over time.', keywords = 'easing curve quad linear' })
    end
    for _, def in ipairs(Camera.SETTINGS) do
        if def.group == group then
            local section = page[4] or (def.name:find('Interact', 1, true) and 'Interact target' or 'Enemy target')
            settingRows(rows, def, section, standardEntry(def.name))
        end
    end
    Options:AddTemplate(id, rows, SHARED)
end

-- Situations ----------------------------------------------------------------
-- The page context names the situation being edited; the "Situation" row
-- changes it. Undo and the combat queue key on it, one situation at a time.
local selected = { situation = shipped().situations[1].id }
local stash = setmetatable({}, { __mode = 'k' })     -- overrides switched off this session, per situation
local function situation(ctx)
    local cfg, id = Camera:Config(), ctx and ctx.situation
    for _, entry in ipairs(cfg and cfg.situations or {}) do if entry.id == id then return entry end end
end
local function shippedSituation(ctx)
    for _, entry in ipairs(shipped().situations) do if entry.id == (ctx and ctx.situation) then return entry end end
end
local function statusSuffix(entry)
    local status = entry and Camera:SituationStatus(entry) or ''
    return (status ~= '' and status ~= 'off') and ' - ' .. status or ''
end

Options:Category({ id = 'camera.situations', parent = 'camera', title = 'Situations', order = 90, context = selected,
    desc = 'The highest-priority enabled situation that applies overrides the standard camera settings.',
    keywords = 'situation combat mounted city raid dungeon' })

local rows = {
    zoomField('restore', { type = 'choice', label = 'Restore zoom after a situation', section = 'All situations',
        values = { 'never', 'adaptive', 'always' },
        desc = 'Whether leaving a situation returns the camera to the zoom distance it had before.', keywords = 'restore zoom return leave' }),
    zoomField('transitionEasing', { type = 'choice', label = 'Transition easing', section = 'All situations', values = Camera.EASINGS,
        desc = 'Shape of the zoom and setting changes when a situation starts or ends.', keywords = 'transition easing curve' }),
}
Options:AddTemplate('camera.situations', rows, SHARED)

-- Catalogue: one switch per shipped situation.
rows = { { id = 'camera.situations.note', type = 'note', label = 'Catalogue', section = 'Catalogue', keywords = 'custom inactive condition',
    text = 'A situation marked "custom (inactive)" carries a condition script from DynamicCam; it is kept as data, never run, and cannot be switched on.' } }
for _, entry in ipairs(shipped().situations) do
    local ctx, option = { situation = entry.id }, nil
    option = { id = 'camera.situation.' .. entry.id .. '.enabled', type = 'toggle', label = entry.name, section = 'Catalogue',
        keywords = 'situation enable ' .. entry.name, default = entry.enabled, combatSafe = true, apply = changed,
        desc = function()
            local live = situation(ctx)
            if not live then return 'Use the camera settings of this situation while it applies.' end
            return ('Applies when: %s. Priority %s.'):format(Camera:ConditionText(live), tostring(live.priority))
        end,
        get = function() local live = situation(ctx); return live and live.enabled == true or false end,
        set = function(_, on)
            local live = situation(ctx)
            if not (live and live.condition) then error(entry.name .. ' has a custom condition and stays inactive.', 0) end
            live.enabled = on
        end,
        disabled = function() local live = situation(ctx); return not (live and live.condition) end,
        -- Rows take a fixed label; this runs before each draw, so the status
        -- ("custom (inactive)", "active now") is refreshed here.
        hidden = function() option.label = entry.name .. statusSuffix(situation(ctx)); return false end }
    rows[#rows + 1] = option
end
Options:Add('camera.situations', rows)

-- One declaration for the situation named by ctx.situation.
local function field(sub, key, spec)
    spec.key = (sub and sub .. '.' or '') .. key
    local function target(entry) return entry and (sub and entry[sub] or not sub and entry) or nil end
    spec.get = function(ctx) local t = target(situation(ctx)); return t and t[key] end
    spec.set = function(ctx, value)
        local t = target(situation(ctx))
        if not t then error('Choose a situation first.', 0) end
        t[key] = value
    end
    spec.default = function(ctx) local t = target(shippedSituation(ctx)); return t and t[key] end
    return spec
end
local function zoomPart(mode, ranged)       -- hidden unless the zoom action is in this mode
    return function(ctx)
        local entry = situation(ctx)
        local zoom = entry and entry.zoom
        if not zoom or zoom.mode ~= mode then return true end
        return ranged ~= nil and (zoom.type == 'range') ~= ranged
    end
end
local function rotationPart(kind)
    return function(ctx) local entry = situation(ctx); return not entry or entry.rotation.type ~= kind end
end
local EDIT, ZOOM, TURN, FADE = 'Edit a situation', 'Zoom action', 'Rotation action', 'Interface fade'
rows = {
    { key = 'selected', type = 'choice', label = 'Situation', section = EDIT, keywords = 'situation select edit choose',
        desc = 'The situation whose timing, actions and overrides the rows below edit.',
        values = function()
            local ids, cfg = {}, Camera:Config() or shipped()
            for index, entry in ipairs(cfg.situations) do ids[index] = entry.id end
            return ids
        end,
        labels = function()
            local names, cfg = {}, Camera:Config() or shipped()
            for _, entry in ipairs(cfg.situations) do names[entry.id] = entry.name .. statusSuffix(entry) end
            return names
        end,
        default = shipped().situations[1].id, apply = false,
        get = function() return selected.situation end,
        set = function(_, id)
            selected.situation = id
            local window = ns.OptionsWindow
            if window and window.category == 'camera.situations' and window.BuildContext then window:BuildContext() end
        end },
    { key = 'when', type = 'note', label = 'Condition', section = EDIT, keywords = 'condition when applies',
        text = function(ctx)
            local entry = situation(ctx)
            if not entry then return 'The camera settings load at login.' end
            local status = Camera:SituationStatus(entry)
            return 'When: ' .. Camera:ConditionText(entry) .. (status ~= '' and '\nStatus: ' .. status or '')
        end },
    field(nil, 'priority', { type = 'number', label = 'Priority', section = EDIT, min = -1000, max = 10000, step = 1,
        desc = 'Of the enabled situations that apply, the one with the highest priority wins.', keywords = 'priority order wins' }),
    field(nil, 'delay', { type = 'number', label = 'Leave delay (seconds)', section = EDIT, min = 0, max = 600, step = 0.1,
        desc = 'How long the situation stays active after its condition stops applying.', keywords = 'delay leave linger seconds' }),
    field(nil, 'enter', { type = 'number', label = 'Transition time entering (seconds)', section = EDIT, min = 0, max = 60, step = 0.05,
        desc = 'Time over which the camera changes to this situation.', keywords = 'transition time enter seconds' }),
    field(nil, 'exit', { type = 'number', label = 'Transition time leaving (seconds)', section = EDIT, min = 0, max = 60, step = 0.05,
        desc = 'Time over which the camera changes back when this situation ends.', keywords = 'transition time exit leave seconds' }),

    field('zoom', 'enabled', { type = 'toggle', label = 'Zoom action', section = ZOOM,
        desc = 'Entering the situation moves the camera to a zoom distance or a saved view.', keywords = 'zoom action situation' }),
    field('zoom', 'mode', { type = 'choice', label = 'Use', section = ZOOM, values = { 'zoom', 'view' }, labels = { 'Zoom distance', 'Saved view' },
        desc = 'Whether the action sets a zoom distance or switches to one of the saved views.', keywords = 'zoom view mode' }),
    field('zoom', 'type', { type = 'choice', label = 'Zoom rule', section = ZOOM, values = { 'set', 'in', 'out', 'range' },
        labels = { 'Set to', 'Zoom in to at most', 'Zoom out to at least', 'Keep within a range' }, hidden = zoomPart('zoom'),
        desc = 'How the zoom value is applied to the current zoom distance.', keywords = 'zoom rule set in out range' }),
    field('zoom', 'value', { type = 'slider', label = 'Zoom value (yards)', section = ZOOM, min = 0, max = 50, step = 0.5, hidden = zoomPart('zoom', false),
        desc = 'Zoom distance used by the zoom rule.', keywords = 'zoom value distance yards' }),
    field('zoom', 'min', { type = 'slider', label = 'Nearest zoom (yards)', section = ZOOM, min = 0, max = 50, step = 0.5, hidden = zoomPart('zoom', true),
        desc = 'Closest zoom distance the situation allows.', keywords = 'zoom range nearest minimum' }),
    field('zoom', 'max', { type = 'slider', label = 'Farthest zoom (yards)', section = ZOOM, min = 0, max = 50, step = 0.5, hidden = zoomPart('zoom', true),
        desc = 'Farthest zoom distance the situation allows.', keywords = 'zoom range farthest maximum' }),
    field('zoom', 'timeIsMax', { type = 'toggle', label = 'Transition time is only a maximum', section = ZOOM, hidden = zoomPart('zoom'),
        desc = 'A short zoom change finishes sooner than the transition time, at the zoom speed.', keywords = 'zoom time maximum faster' }),
    field('zoom', 'view', { type = 'number', label = 'Saved view number', section = ZOOM, min = 1, max = 5, integer = true, step = 1, hidden = zoomPart('view'),
        desc = 'Which of the five saved camera views the situation switches to.', keywords = 'saved view number' }),
    field('zoom', 'viewRestore', { type = 'toggle', label = 'Return to the previous view after', section = ZOOM, hidden = zoomPart('view'),
        desc = 'Leaving the situation goes back to the view that was active before.', keywords = 'view restore return' }),
    field('zoom', 'viewInstant', { type = 'toggle', label = 'Switch view instantly', section = ZOOM, hidden = zoomPart('view'),
        desc = 'The view changes at once instead of gliding.', keywords = 'view instant' }),

    field('rotation', 'enabled', { type = 'toggle', label = 'Rotation action', section = TURN,
        desc = 'The camera turns while the situation is active.', keywords = 'rotation rotate turn spin' }),
    field('rotation', 'type', { type = 'choice', label = 'Kind', section = TURN, values = { 'continuous', 'degrees' },
        labels = { 'Continuous', 'By degrees' },
        desc = 'Turn continuously, or turn once by a number of degrees.', keywords = 'rotation continuous degrees' }),
    field('rotation', 'speed', { type = 'slider', label = 'Degrees per second', section = TURN, min = -360, max = 360, step = 1, hidden = rotationPart('continuous'),
        desc = 'Speed of the continuous turn; negative turns the other way.', keywords = 'rotation speed degrees second' }),
    field('rotation', 'yaw', { type = 'number', label = 'Yaw degrees (right +)', section = TURN, min = -1440, max = 1440, step = 1, hidden = rotationPart('degrees'),
        desc = 'Sideways turn made when the situation starts.', keywords = 'rotation yaw degrees sideways' }),
    field('rotation', 'pitch', { type = 'number', label = 'Pitch degrees (up +)', section = TURN, min = -90, max = 90, step = 1, hidden = rotationPart('degrees'),
        desc = 'Up or down turn made when the situation starts.', keywords = 'rotation pitch degrees up down' }),
    field('rotation', 'back', { type = 'toggle', label = 'Rotate back when leaving', section = TURN,
        desc = 'Leaving the situation undoes the turn.', keywords = 'rotation back return' }),

    field('hideUI', 'enabled', { type = 'toggle', label = 'Fade the interface', section = FADE,
        desc = 'The whole interface fades while the situation is active.', keywords = 'hide ui fade interface' }),
    field('hideUI', 'fadeOpacity', { type = 'slider', label = 'Interface opacity while active', section = FADE, min = 0, max = 1, step = 0.01,
        format = '%.0f%%', scale = 100, desc = 'How visible the interface stays while it is faded.', keywords = 'hide ui fade opacity alpha' }),
}

-- Per-situation overrides of the standard settings.
local GROUP_TITLE = {}
for _, page in ipairs(PAGES) do GROUP_TITLE[page[1]] = page[2] end
for _, def in ipairs(Camera.SETTINGS) do
    local name, meta, section = def.name, META[def.name], 'Overrides: ' .. GROUP_TITLE[def.group]
    local function entryOf(ctx, forWrite)
        local entry = situation(ctx)
        local override = entry and entry.overrides[name]
        if not override and forWrite then error('Turn the override on first.', 0) end
        return override
    end
    local function shippedOf(ctx)
        local entry = shippedSituation(ctx)
        return entry and entry.overrides[name] or shipped().standard[name]
    end
    rows[#rows + 1] = { key = name .. '.override', type = 'toggle', label = 'Override: ' .. meta[1], section = section,
        desc = 'While this situation is active it uses its own ' .. meta[1] .. ' instead of the standard one.',
        keywords = meta[3] .. ' override situation',
        get = function(ctx) return entryOf(ctx) ~= nil end,
        set = function(ctx, on)
            local entry = situation(ctx)
            if not entry then error('Choose a situation first.', 0) end
            stash[entry] = stash[entry] or {}
            if on then
                entry.overrides[name] = entry.overrides[name] or stash[entry][name] or { value = config().standard[name].value or 0 }
            else
                stash[entry][name], entry.overrides[name] = entry.overrides[name], nil
            end
        end,
        default = function(ctx) local entry = shippedSituation(ctx); return entry ~= nil and entry.overrides[name] ~= nil end }
    settingRows(rows, def, section, entryOf, shippedOf, function(ctx) return entryOf(ctx) == nil end)
end
Options:AddTemplate('camera.situations', rows, { idPrefix = 'camera.situation.', combatSafe = true, apply = changed, disabled = notReady })
