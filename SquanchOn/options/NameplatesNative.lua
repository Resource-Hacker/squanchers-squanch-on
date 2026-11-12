-- SPDX-License-Identifier: MIT
-- Squanch-On's own nameplates: pages under "Nameplates & Target ring". Values
-- live in SquanchOnDB.nameplates; the defaults (Nameplates.lua, NP.defaults)
-- are the layout the author used in Plater. Plates are plain frames, so look
-- and layout edits apply in combat; CVars and the click area wait for it to end.
local _, ns = ...
local Options = ns.Options
local NP = ns.Nameplates
if not Options or not NP then return end

Options:Root('nameplatesOwn', function() return NP:Settings() end)
Options:Root('nameplateType', function(ctx) return NP:Settings().types[ctx and ctx.kind or 'enemynpc'] end)

local function repaint() NP:RefreshAll() end
local function lookup(path)
  local value = NP.defaults
  for part in path:gmatch('[^%.]+') do
    if type(value) ~= 'table' then return nil end
    value = value[tonumber(part) or part]
  end
  return value
end
local function fromArray(value)
  if type(value) ~= 'table' then return nil end
  return { r = value[1], g = value[2], b = value[3], a = value[4] }
end
-- rows: { path, type, label, extra fields }. Order follows the list.
local function add(category, section, rows, base)
  local list = {}
  for index, row in ipairs(rows) do
    local option = row[4] or {}
    option.path, option.type, option.label = row[1], row[2], row[3]
    option.id = category .. '.' .. row[1]
    option.root = option.root or 'nameplatesOwn'
    option.section, option.order = section, (base or 0) + index * 10
    if option.type == 'color' then option.storage = 'array' end
    if option.default == nil then
      local default = lookup(row[1])
      if option.type == 'color' then default = fromArray(default) end
      option.default = default
    end
    if option.combatSafe == nil then option.combatSafe = true end
    if option.apply == nil then option.apply = repaint end
    option.keywords = 'nameplate ' .. (option.keywords or '')
    list[#list + 1] = option
  end
  Options:Add(category, list)
end
local function slider(min, max, step, extra)
  extra = extra or {}
  extra.min, extra.max, extra.step = min, max, step
  return extra
end
local percent = { min = 0, max = 1, step = 0.01, format = '%.0f%%', scale = 100 }
local function alpha(extra)
  local copy = extra or {}
  for key, value in pairs(percent) do copy[key] = value end
  return copy
end

-- General --------------------------------------------------------------------
local ROOT = 'nameplates.own'
Options:Category({ id = ROOT, parent = 'nameplates', title = 'Squanch-On nameplates', order = 100,
  desc = "Squanch-On's own nameplates. They run only while Plater is not loaded; untested in game." })
Options:Add(ROOT, {
  { id = ROOT .. '.enabled', type = 'toggle', label = 'Use Squanch-On nameplates', section = 'Nameplates', order = 10,
    desc = "Draws nameplates with Squanch-On. Turning it off restores the recorded game settings; /reload then returns the game's own plates.",
    keywords = 'nameplate enable plater replace', default = true, combatSafe = false,
    get = function() return NP:Settings().enabled and true or false end,
    set = function(_, value) NP:SetEnabled(value) end },
  { id = ROOT .. '.status', type = 'note', label = 'Status', section = 'Nameplates', order = 20,
    text = function()
      if NP:IsActive() then return 'Squanch-On nameplates are running.' end
      if NP:PlaterLoaded() then return 'Plater is loaded, so these nameplates are off. Disable Plater in the AddOns list and /reload to use them.' end
      if NP.pendingStart then return 'Starting when combat ends.' end
      return 'Squanch-On nameplates are off.'
    end },
})
Options:Add(ROOT, {
  { id = ROOT .. '.preview', type = 'action', label = 'Preview plates', button = 'Toggle preview', section = 'Nameplates', order = 25,
    desc = 'A movable row of made-up plates, one per case, drawn by the same code as real plates. Works while Plater is loaded. Same as /sqplates test.',
    keywords = 'nameplate preview test fake', combatSafe = true,
    func = function() return ns.NameplatePreview:Show(false) and 'Preview shown.' or 'Preview hidden.' end },
  { id = ROOT .. '.previewEnhanced', type = 'action', label = 'Preview with enhancements', button = 'Toggle preview', section = 'Nameplates', order = 26,
    desc = 'The same row with the enhancements on, whatever the Classic look switch says. Same as /sqplates test enh.',
    keywords = 'nameplate preview test fake enhancements', combatSafe = true,
    func = function() return ns.NameplatePreview:Show(true) and 'Preview shown.' or 'Preview hidden.' end },
})
add(ROOT, 'Nameplates', {
  { 'scale', 'slider', 'Overall scale', slider(0.5, 3, 0.05, { desc = 'Multiplies every size on these pages.' }) },
  { 'barWhenTargetedFaction', 'choice', 'Bar on a selected friendly player', { values = { 'Horde', 'Alliance', 'NONE' },
    labels = { 'Horde players', 'Alliance players', 'Never' },
    desc = 'Friendly players show their name only. A selected player of this faction gets the health bar and a solid faction emblem.' } },
  { 'clickSpace.1', 'number', 'Plate area width', { min = 10, max = 400, combatSafe = false,
    desc = 'The area the game reserves per plate when it stacks them. Plates never take clicks.',
    apply = function() if NP.driver and not InCombatLockdown() then local c = NP:Settings().clickSpace; NP.driver:SetSize(c[1], c[2]) end end } },
  { 'clickSpace.2', 'number', 'Plate area height', { min = 10, max = 200, combatSafe = false,
    apply = function() if NP.driver and not InCombatLockdown() then local c = NP:Settings().clickSpace; NP.driver:SetSize(c[1], c[2]) end end } },
}, 20)
add(ROOT, 'Health bar', {
  { 'health.texture', 'statusbar', 'Bar texture' },
  { 'health.background', 'color', 'Background', { hasAlpha = true } },
  { 'border.thickness', 'slider', 'Rim thickness (pixels)', slider(0, 4, 1, { integer = true, desc = 'Drawn inside the bar; a thin bar keeps a visible fill.' }) },
  { 'border.color', 'color', 'Rim colour', { hasAlpha = true } },
  { 'border.theme', 'toggle', 'Rim in the theme line colour', { desc = 'Uses the Squanch-On theme line colour with the opacity above.' } },
  { 'power.height', 'slider', 'Power bar height', slider(0.5, 10, 0.5) },
  { 'power.y', 'slider', 'Power bar offset', slider(-20, 20, 0.5) },
  { 'power.text', 'toggle', 'Power percentage' },
  { 'power.textFont', 'font', 'Power percentage font' },
  { 'power.textSize', 'slider', 'Power percentage size', slider(4, 20, 1, { integer = true }) },
  { 'bigName.font', 'font', 'Name font of an unattackable enemy NPC' },
  { 'bigName.size', 'slider', 'Name size of an unattackable enemy NPC', slider(4, 30, 1, { integer = true }) },
  { 'subtitle.show', 'toggle', 'Title under a name-only NPC', { desc = 'The profession or title line, as "<Innkeeper>", in the colour of the name.' } },
  { 'subtitle.underBar', 'toggle', 'Title under an NPC health bar', { desc = 'Shows the same line, as "<General Goods>", under the health bar of NPCs that have one.' } },
  { 'subtitle.barSize', 'slider', 'Title size under a bar', slider(4, 20, 1, { integer = true }) },
  { 'subtitle.font', 'font', 'Title font' },
  { 'subtitle.size', 'slider', 'Title size', slider(4, 30, 1, { integer = true }) },
  { 'translit', 'toggle', 'Cyrillic names in Latin letters' },
  { 'sizeScale.minor.1', 'slider', 'Minor unit width', alpha() },
  { 'sizeScale.minor.2', 'slider', 'Minor unit height', alpha() },
  { 'sizeScale.pet.1', 'slider', 'Pet and guardian width', alpha() },
  { 'sizeScale.pet.2', 'slider', 'Pet and guardian height', alpha() },
})
add(ROOT, 'Target and hover', {
  { 'target.highlight', 'color', 'Target highlight', { hasAlpha = true } },
  { 'target.highlightHeight', 'slider', 'Target highlight height', slider(0, 40, 1) },
  { 'target.overlayAlpha', 'slider', 'Target sheen on the bar', alpha() },
  { 'target.hoverAlpha', 'slider', 'Hover highlight', alpha() },
  { 'target.ornament', 'toggle', 'Target ornaments at the bar ends', { desc = 'Shown on bars at least four units high.' } },
  { 'target.ornamentColor', 'color', 'Target ornament colour', { hasAlpha = true } },
  { 'target.aggroGlow', 'toggle', 'Warning glow when about to pull' },
  { 'target.aggroFlash.enabled', 'toggle', 'Flash when a unit turns on you', { desc = 'A wash over the bar, in and out, when you take aggro as damage dealer or healer. Not in the first five seconds of a fight.' } },
  { 'target.aggroFlash.instanceOnly', 'toggle', 'Aggro flash in dungeons and raids only' },
  { 'target.aggroFlash.color', 'color', 'Aggro flash colour', { hasAlpha = true } },
  { 'target.aggroFlash.duration', 'slider', 'Aggro flash time each way (seconds)', slider(0.05, 1, 0.05) },
  { 'target.aggroFlash.text', 'toggle', 'Aggro flash shows "-AGGRO-"' },
  { 'target.label.show', 'toggle', "Show the unit's target", { desc = 'The name of whoever the unit is targeting, class coloured, under the bar.' } },
  { 'target.label.font', 'font', "Unit's target font" },
  { 'target.label.size', 'slider', "Unit's target text size", slider(4, 30, 1, { integer = true }) },
  { 'target.label.x', 'slider', "Unit's target offset X", slider(-100, 100, 1) },
  { 'target.label.y', 'slider', "Unit's target offset Y", slider(-100, 100, 1) },
  { 'target.label.alpha', 'slider', "Unit's target opacity", alpha() },
})
add(ROOT, 'Indicators', {
  { 'indicators.size', 'slider', 'Icon size', slider(6, 64, 1) },
  { 'indicators.x', 'slider', 'Faction emblem offset X', slider(-50, 50, 0.5) },
  { 'indicators.y', 'slider', 'Faction emblem offset Y', slider(-50, 50, 0.5) },
  { 'indicators.friendlyFaction', 'toggle', 'Faction emblem on friendly players' },
  { 'indicators.enemyFaction', 'toggle', 'Faction emblem on enemy players' },
  { 'indicators.rare', 'toggle', 'Rare marker', { desc = 'A rare elite carries a gold star beside the grey one.' } },
  { 'indicators.quest', 'toggle', 'Quest badge on friendly quest NPCs' },
  { 'indicators.raidMark', 'toggle', 'Raid target mark' },
})
local function cvar(name, label, min, max, step)
  return { 'cvars.' .. name, 'slider', label, slider(min, max, step, { combatSafe = false, keywords = 'cvar ' .. name,
    desc = 'Game setting ' .. name .. '. The value from before Squanch-On took over is restored when these nameplates are turned off.',
    apply = function() if NP:IsActive() then NP:ApplyCVars() end end }) }
end
local function zones() if NP:IsActive() then NP:ApplyCVars(true) end end
local function zone(key, label) return { 'zoneFriendly.' .. key, 'toggle', label, { combatSafe = false, apply = zones } } end
add(ROOT, 'Friendly plates by zone', {
  { 'zoneFriendly.enabled', 'toggle', 'Switch friendly plates by zone', { combatSafe = false, apply = zones,
    desc = 'Sets the game\'s friendly nameplate switch when you change zone, out of combat.' } },
  zone('party', 'In dungeons'), zone('raid', 'In raids'), zone('arena', 'In arenas and battlegrounds'),
  zone('world', 'In the open world'), zone('cities', 'In cities and inns'),
}, 200)
add(ROOT, 'Game settings', {
  cvar('nameplateMaxDistance', 'Farthest plate (yards)', 10, 100, 1),
  cvar('nameplateTargetBehindMaxDistance', 'Target plate behind you (yards)', 0, 100, 1),
  cvar('nameplateOverlapH', 'Horizontal overlap', 0, 2, 0.05),
  cvar('nameplateOverlapV', 'Vertical overlap', 0, 2, 0.05),
  cvar('nameplateOtherTopInset', 'Top screen inset', -1, 0.5, 0.005),
  cvar('nameplateSelectedScale', 'Selected plate scale', 0.5, 2, 0.05),
  cvar('nameplateMinAlpha', 'Distant plate opacity', 0, 1, 0.05),
  cvar('nameplateOccludedAlphaMult', 'Hidden-behind-wall opacity', 0, 1, 0.05),
})

-- Per kind of plate -----------------------------------------------------------
local TYPES = ROOT .. '.types'
Options:Category({ id = TYPES, parent = 'nameplates', title = 'Plate sizes and text', order = 110,
  desc = 'Sizes, fonts and text for one kind of plate. Pick the kind below.',
  contexts = { { key = 'kind', values = { 'enemynpc', 'friendlynpc', 'enemyplayer', 'friendlyplayer' },
    labels = { 'Enemy NPC', 'Friendly NPC', 'Enemy player', 'Friendly player' } } } })
local sides = { values = { 'LEFT', 'INNERLEFT', 'CENTER', 'INNERRIGHT', 'RIGHT' },
  labels = { 'Left of the bar', 'Inside, left', 'Centre', 'Inside, right', 'Right of the bar' } }
local function side() return { values = sides.values, labels = sides.labels } end
local template = {}
for _, group in ipairs({
  { 'Bar', {
    { 'mode', 'choice', 'Shows', { values = { 'bar', 'nameOnly' }, labels = { 'Bar and name', 'Name only' } } },
    { 'health.1', 'slider', 'Width', slider(10, 300, 1) },
    { 'health.2', 'slider', 'Height', slider(1, 40, 0.5) },
    { 'healthCombat.1', 'slider', 'Width in combat', slider(10, 300, 1) },
    { 'healthCombat.2', 'slider', 'Height in combat', slider(1, 40, 0.5) },
    { 'power', 'toggle', 'Power bar' },
    { 'auraOffset', 'slider', 'Debuff row offset', slider(-60, 60, 1) } } },
  { 'Name', {
    { 'name.font', 'font', 'Font' },
    { 'name.size', 'slider', 'Size', slider(4, 30, 1, { integer = true }) },
    { 'name.outline', 'choice', 'Outline', { values = { 'NONE', 'OUTLINE', 'THICKOUTLINE' }, labels = { 'None', 'Outline', 'Thick outline' } } },
    { 'name.y', 'slider', 'Height above the bar', slider(-40, 60, 1) },
    { 'name.classColor', 'toggle', 'Class colour for players' } } },
  { 'Level', {
    { 'level.show', 'toggle', 'Show the level' },
    { 'level.font', 'font', 'Font' },
    { 'level.size', 'slider', 'Size', slider(4, 30, 1, { integer = true }) },
    { 'level.side', 'choice', 'Position', side() },
    { 'level.x', 'slider', 'Offset X', slider(-60, 60, 0.5) },
    { 'level.y', 'slider', 'Offset Y', slider(-60, 60, 0.5) } } },
  { 'Health percent', {
    { 'percent.show', 'toggle', 'Show the percentage', { desc = 'A bare number without the % sign.' } },
    { 'percent.font', 'font', 'Font' },
    { 'percent.size', 'slider', 'Size', slider(4, 30, 1, { integer = true }) },
    { 'percent.side', 'choice', 'Position', side() },
    { 'percent.x', 'slider', 'Offset X', slider(-60, 60, 0.5) },
    { 'percent.y', 'slider', 'Offset Y', slider(-60, 60, 0.5) },
    { 'percent.alpha', 'slider', 'Opacity', alpha() } } },
  { 'Cast bar', {
    { 'showCast', 'toggle', 'Show the cast bar' },
    { 'cast.1', 'slider', 'Width', slider(10, 300, 1) },
    { 'cast.2', 'slider', 'Height', slider(1, 40, 0.5) },
    { 'castOffset', 'slider', 'Gap under the health bar', slider(-40, 40, 0.5) },
    { 'spell.font', 'font', 'Spell name font' },
    { 'spell.size', 'slider', 'Spell name size', slider(4, 40, 1, { integer = true }) },
    { 'spell.y', 'slider', 'Spell name height', slider(-60, 80, 1) },
    { 'castTime.show', 'toggle', 'Remaining cast time' },
    { 'castTime.font', 'font', 'Cast time font' },
    { 'castTime.size', 'slider', 'Cast time size', slider(4, 30, 1, { integer = true }) },
    { 'castTime.side', 'choice', 'Cast time position', side() },
    { 'castTime.x', 'slider', 'Cast time offset X', slider(-60, 60, 0.5) },
    { 'castTime.y', 'slider', 'Cast time offset Y', slider(-60, 60, 0.5) } } },
}) do
  for index, row in ipairs(group[2]) do
    local option = row[4] or {}
    option.key, option.path, option.type, option.label = row[1], row[1], row[2], row[3]
    option.section, option.order = group[1], index * 10
    option.keywords = 'nameplate ' .. group[1]
    -- Reset returns the selected kind's shipped value.
    option.default = function(ctx) return lookup('types.' .. (ctx and ctx.kind or 'enemynpc') .. '.' .. row[1]) end
    template[#template + 1] = option
  end
end
Options:AddTemplate(TYPES, template, { idPrefix = TYPES .. '.', root = 'nameplateType', combatSafe = true,
  apply = function() NP:RefreshAll() end })

-- Colours ----------------------------------------------------------------------
local COLORS = ROOT .. '.colors'
Options:Category({ id = COLORS, parent = 'nameplates', title = 'Plate colours', order = 120,
  desc = 'Bar and name colours. Players use their class colour.' })
add(COLORS, 'Reaction', {
  { 'colors.hostile', 'color', 'Hostile' }, { 'colors.neutral', 'color', 'Neutral' }, { 'colors.friendly', 'color', 'Friendly' },
  { 'colors.tapped', 'color', "Tapped by someone else" },
  { 'colors.noCombat', 'color', 'Hostile unit outside your fight', { desc = 'While you are in combat, a hostile NPC that is not fighting anyone.' } },
})
add(COLORS, 'Dungeons and raids', {
  { 'colors.unitType', 'toggle', 'Colour enemies by type in instances', { desc = 'In dungeons, raids and scenarios, where no threat colour applies: boss, miniboss, caster.' } },
  { 'colors.boss', 'color', 'Boss (two levels above you, or a skull)' },
  { 'colors.miniboss', 'color', 'Miniboss (a level above you)' },
  { 'colors.caster', 'color', 'Caster (uses mana)' },
})
add(COLORS, 'Quest', {
  { 'colors.quest', 'toggle', 'Colour quest units', { desc = 'Outside instances, where the client can tell that a unit belongs to an active quest.' } },
  { 'colors.questHostile', 'color', 'Hostile quest unit' }, { 'colors.questNeutral', 'color', 'Neutral quest unit' },
  { 'colors.questFriendly', 'color', 'Friendly quest unit' },
})
add(COLORS, 'Threat', {
  { 'colors.threat', 'toggle', 'Colour by threat', { desc = 'Bar colour only, while you are on the unit\'s threat list.' } },
  { 'colors.role', 'choice', 'Your role', { values = { 'dps', 'tank' }, labels = { 'Damage or healing', 'Tank' } } },
  { 'colors.dpsAggro', 'color', 'Damage: it attacks you' }, { 'colors.dpsPulling', 'color', 'Damage: about to pull' },
  { 'colors.dpsNoAggro', 'color', 'Damage: no aggro' },
  { 'colors.tankAggro', 'color', 'Tank: holding it' }, { 'colors.tankPulling', 'color', 'Tank: losing it' },
  { 'colors.tankNoAggro', 'color', 'Tank: not on you' },
})
add(COLORS, 'Names', {
  { 'colors.name', 'color', 'Name' },
  { 'colors.friendColors', 'toggle', 'Mark friends and guild members' },
  { 'colors.friend', 'color', 'Friend' }, { 'colors.guild', 'color', 'Guild member' },
})

-- Cast bar ---------------------------------------------------------------------
local CAST = ROOT .. '.cast'
Options:Category({ id = CAST, parent = 'nameplates', title = 'Plate cast bar', order = 130,
  desc = 'The cast bar under a plate. Its size per kind of plate is on the sizes page.' })
add(CAST, 'Cast bar', {
  { 'cast.texture', 'statusbar', 'Bar texture' },
  { 'cast.background', 'color', 'Background', { hasAlpha = true } },
  { 'cast.normal', 'color', 'Cast', { hasAlpha = true } },
  { 'cast.channel', 'color', 'Channel', { hasAlpha = true } },
  { 'cast.nonInterruptible', 'color', 'Cannot be interrupted', { hasAlpha = true } },
  { 'cast.interrupted', 'color', 'Interrupted or failed', { hasAlpha = true } },
  { 'cast.holdInterrupted', 'slider', 'Stay after an interrupt (seconds)', slider(0, 3, 0.1) },
  { 'cast.fade', 'slider', 'Fade out at the end (seconds)', slider(0, 2, 0.1, { desc = 'Zero: the bar disappears at once and a finished cast shows no flash.' }) },
  { 'cast.finishFlash', 'toggle', 'Flash when a cast finishes' },
  { 'cast.finished', 'color', 'Finished cast', { hasAlpha = true } },
  { 'cast.textShadow', 'color', 'Spell name shadow', { hasAlpha = true } },
  { 'cast.spark', 'toggle', 'Spark' },
  { 'cast.sparkWidth', 'slider', 'Spark width', slider(2, 40, 1) },
  { 'cast.icon', 'toggle', 'Spell icon' },
  { 'cast.iconX', 'slider', 'Spell icon offset', slider(-80, 0, 1) },
  { 'cast.shield', 'toggle', 'Shield on casts that cannot be interrupted' },
  { 'cast.hideNameWhileCasting', 'toggle', 'Hide the unit name while it casts' },
})

-- Debuffs and opacity ----------------------------------------------------------
local AURAS = ROOT .. '.auras'
Options:Category({ id = AURAS, parent = 'nameplates', title = 'Plate debuffs and opacity', order = 140,
  desc = 'The icon row above a plate and how plates fade. Icons share the look set under Auras & Buffs.' })
add(AURAS, 'Debuffs', {
  { 'auras.enabled', 'toggle', 'Show the icon row' },
  { 'auras.mine', 'toggle', 'Debuffs you applied' },
  { 'auras.cc', 'toggle', 'Crowd control from anyone' },
  { 'auras.defensive', 'toggle', 'Major defensive cooldowns on players' },
  { 'auras.size', 'slider', 'Icon size', slider(8, 48, 1, { integer = true }) },
  { 'auras.perRow', 'slider', 'Icons per row', slider(1, 16, 1, { integer = true }) },
  { 'auras.max', 'slider', 'Most icons shown', slider(1, 40, 1, { integer = true }) },
  { 'auras.y', 'slider', 'Height above the bar', slider(0, 100, 1) },
  { 'auras.alpha', 'slider', 'Row opacity on a dimmed plate', alpha() },
  { 'auras.timer', 'toggle', 'Countdown numbers' },
  { 'auras.timerSize', 'slider', 'Countdown text size', slider(5, 20, 1, { integer = true }) },
  { 'auras.stackSize', 'slider', 'Stack count size', slider(5, 20, 1, { integer = true }) },
  { 'auras.tooltip', 'toggle', 'Tooltip while the mouseover hold is open',
    { desc = 'Icons react to the cursor only while you hold the mouseover button; clicks always pass through.' } },
})
add(AURAS, 'Opacity', {
  { 'alpha.inRange', 'slider', 'In range, or the target', alpha() },
  { 'alpha.outOfRange', 'slider', 'Plate out of range', alpha({ desc = 'Also the in-range factor of a plate that is not your target.' }) },
  { 'alpha.healthOutOfRange', 'slider', 'Health bar out of range', alpha() },
  { 'alpha.castOutOfRange', 'slider', 'Cast bar out of range', alpha() },
  { 'alpha.aurasOutOfRange', 'slider', 'Icons out of range', alpha() },
  { 'alpha.rangeYards', 'slider', 'Range (yards)', slider(5, 100, 5, { integer = true }) },
  { 'alpha.nonTargetMultiplier', 'slider', 'Out-of-range plates while you have a target', alpha() },
  { 'alpha.notInCombatEnabled', 'toggle', 'Dim enemies outside your fight' },
  { 'alpha.notInCombat', 'slider', 'Enemy outside your fight', alpha() },
})

-- Enhancements -----------------------------------------------------------------
local ENHANCE = ROOT .. '.enhance'
Options:Category({ id = ENHANCE, parent = 'nameplates', title = 'Plate enhancements', order = 150,
  desc = 'Additions over the previous look. Classic look keeps every one of them off.' })
local function cvars() if NP:IsActive() then NP:ApplyCVars() end; NP:RefreshAll() end
add(ENHANCE, 'Enhancements', {
  { 'enhance.classicLook', 'toggle', 'Classic look (match my previous nameplates exactly)', { combatSafe = false, apply = cvars,
    desc = 'On: none of the enhancements below is drawn. Off: the ones switched on below apply.' } },
  { 'enhance.animatedBars', 'toggle', 'Eased health bars', { desc = 'The client eases the bar to its new value.' } },
  { 'enhance.emphasis', 'toggle', 'Emphasis on the target and the aimed plate', { desc = 'A gold rim and a half-second scale step for the target, and for the plate under the reticle while the mouseover hold is open.' } },
  { 'enhance.hoverScale', 'slider', 'Aimed plate scale', slider(1, 1.5, 0.01) },
  { 'enhance.targetScale', 'slider', 'Target plate scale', slider(1, 1.5, 0.01) },
  { 'enhance.auraRows', 'toggle', 'Removable enemy buffs', { desc = 'Enemy buffs you can remove join the icon row, when you know such an ability.' } },
  { 'enhance.castIntel', 'toggle', 'Cast details', { desc = 'A red frame when the cast is aimed at you, a gold frame on important casts and the cast target name, where the client provides them.' } },
  { 'enhance.hunterThreat', 'toggle', 'Solo threat colours', { desc = 'Alone: on you, held by your pet, or gaining. In a group the role colours apply.' } },
  { 'enhance.onMe', 'color', 'On you' }, { 'enhance.petHolds', 'color', 'Your pet holds it' }, { 'enhance.gaining', 'color', 'Gaining threat' },
  { 'enhance.levelling', 'toggle', 'Levelling markers', { desc = 'Elite and rare bars at the bar ends, a quest dot, small plates for grey units and an execute tick when you know an execute.' } },
  { 'enhance.executeThreshold', 'slider', 'Execute tick', alpha() },
  { 'enhance.pointer', 'toggle', 'Pointer when the target is behind the camera' },
  { 'enhance.offscreen', 'toggle', 'Keep off-screen plates at the screen edge', { combatSafe = false, apply = cvars } },
  { 'enhance.stacking', 'toggle', 'Stack crowded plates', { combatSafe = false, apply = cvars, desc = 'Off: plates overlap.' } },
  { 'enhance.stackingBounds', 'toggle', 'Stack by the drawn size', { desc = 'Where the client supports it; applies to plates created afterwards.' } },
})
