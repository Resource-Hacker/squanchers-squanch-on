-- SPDX-License-Identifier: MIT
-- One open motion for every drawer (chat-header windows, Friends, quests).
--
-- The drawer itself is never moved, scaled or resized: it sits at its final
-- place for the whole motion, so layout code that reads its rectangle sees the
-- same values with or without the motion. Two things play instead:
--   1. an addon-owned, unprotected proxy (the empty window shell: shared fill
--      and gold rim) grows upward from the drawer's bottom edge (or sideways
--      from the edge it is attached by), while a render-only Alpha animation
--      holds the drawer invisible;
--   2. the drawer's content fades in and the proxy fades out.
-- Nothing writes the drawer's own alpha, so when the animation ends or is
-- stopped for any reason the drawer shows exactly as it would without it.
-- Closing stays immediate.
--
-- The earlier slide (a zero-duration first order plus ten delayed Translation
-- pieces on the native panel) froze the client on the character sheet. Do not
-- animate the geometry of a native panel here.
local _, ns = ...
local Motion = {
    enabled = true, -- false: every drawer opens instantly
    grow = .32,     -- the shell unfolds, easing out
    fade = .26,     -- content fades in, starting while the shell still settles
    lead = .6,      -- share of the unfold that passes before the content starts to appear
    minHeight = 16, -- the rim's two corner caps need this much room (either axis)
}
ns.DrawerMotion = Motion
-- Shipped values. Edited ones live in ns.db.windows (only keys that were
-- changed) and are read each time a drawer opens.
Motion.defaults = { style = 'unfold', grow = .32, fade = .26 }
function Motion:Setting(key)
    local values = ns.db and ns.db.windows
    local value
    if type(values) == 'table' then value = values[key] end
    if value == nil then return self.defaults[key] end
    return value
end
-- Zero-length steps are avoided: see the note on the earlier slide above.
local function load()
    Motion.enabled = Motion:Setting('style') ~= 'none'
    Motion.grow = math.max(.05, tonumber(Motion:Setting('grow')) or Motion.defaults.grow)
    Motion.fade = math.max(.05, tonumber(Motion:Setting('fade')) or Motion.defaults.fade)
end
-- The unfold's easing (quartic ease-out, a long soft landing), shared with
-- motions outside this file such as the quest list's pull-up.
function Motion:Ease(progress)
    return 1 - (1 - math.max(0, math.min(1, progress))) ^ 4
end
-- The current unfold time, or nil when drawers open instantly.
function Motion:Unfold()
    load()
    return self.enabled and self.grow or nil
end

local states = setmetatable({}, { __mode = 'k' }) -- frame -> state, or false
local rimGroups = setmetatable({}, { __mode = 'k' })

-- Held at 0 for the unfold, then faded in. No SetToFinalAlpha: the region's own
-- alpha is never written, so nothing here can leave it invisible.
local function alphaGroup(region)
    local group = region:CreateAnimationGroup()
    local hold = group:CreateAnimation('Alpha')
    hold:SetOrder(1); hold:SetDuration(Motion.grow * Motion.lead); hold:SetFromAlpha(0); hold:SetToAlpha(0)
    local fade = group:CreateAnimation('Alpha')
    fade:SetOrder(2); fade:SetDuration(Motion.fade); fade:SetFromAlpha(0); fade:SetToAlpha(1)
    group:SetLooping('NONE')
    group.hold, group.fadeIn = hold, fade
    return group
end
-- Groups are kept per frame; the durations follow the current settings.
-- `delay` lengthens the hold for a motion that starts later.
local function play(group, delay)
    group:Stop()
    group.hold:SetDuration((delay or 0) + Motion.grow * Motion.lead); group.fadeIn:SetDuration(Motion.fade)
    group:Play()
end

local function within(region, frame)
    for _ = 1, 40 do
        if region == frame then return true end
        region = region and region.GetParent and region:GetParent()
        if not region then return false end
    end
    return false
end

-- DarkSkin control rims and slot fills ignore their parent's alpha, so the
-- drawer's animation does not reach them. Returns those inside `frame`.
local function ignoringRims(frame)
    local found = {}
    local function consider(region)
        if region and region.IsIgnoringParentAlpha and region:IsIgnoringParentAlpha() then
            found[#found + 1] = region
        end
    end
    for owner, byStyle in pairs(ns.DarkSkin and ns.DarkSkin.byFrame or {}) do
        if within(owner, frame) then
            for _, border in pairs(byStyle) do
                consider(border); consider(border.slotFill)
            end
        end
    end
    return found
end

-- A rim's stored alpha is derived from its control's effective alpha. One that
-- was (re)computed while the drawer was held invisible is recomputed by its
-- owner's existing SetAlpha posthook; the owner's alpha itself is unchanged.
local function refreshRims(frame)
    local seen = {}
    for owner, byStyle in pairs(ns.DarkSkin and ns.DarkSkin.byFrame or {}) do
        if within(owner, frame) then
            for _, border in pairs(byStyle) do
                local alphaOwner = border.alphaOwner
                if alphaOwner and not seen[alphaOwner] then
                    seen[alphaOwner] = true
                    alphaOwner:SetAlpha(alphaOwner:GetAlpha())
                end
            end
        end
    end
end

-- The first time a window opens under the animation, the client can leave its
-- children's anchors unresolved (measured on the character sheet: equipment
-- slots shown at full alpha with no rectangle, so nothing drew). Re-stating
-- the scale resolves them; done as the motion starts, so the content is in
-- place while it fades in, and once more when it ends.
local function settle(frame)
    if InCombatLockdown() and frame:IsProtected() then return end
    local scale = frame:GetScale()
    frame:SetScale(scale * 1.0001)
    frame:SetScale(scale)
end

local function finish(state)
    if not state.running then return end
    state.running = nil
    state.proxy:SetScript('OnUpdate', nil)
    state.proxy:Hide()
    if state.group:IsPlaying() then state.group:Stop() end
    for _, group in ipairs(state.rims or {}) do
        if group:IsPlaying() then group:Stop() end
    end
    state.rims = nil
    if state.frame:IsVisible() then settle(state.frame) end
    if state.frame:IsVisible() then pcall(refreshRims, state.frame) end
    -- A fill created during the first show can keep an unresolved rectangle
    -- (see settle); refit it now that the window has settled.
    local parchment = ns.NativeParchmentSkins
    if parchment and parchment.fills and parchment.fills[state.frame] and state.frame:IsVisible()
        and not InCombatLockdown() then
        pcall(parchment.Fill, parchment, state.frame)
    end
end

local function build(frame, style)
    local skin = ns.DarkSkin
    local proxy = CreateFrame('Frame', nil, UIParent)
    proxy:Hide()
    proxy:EnableMouse(false)
    proxy.ignoreInLayout = true
    local fill = proxy:CreateTexture(nil, 'BACKGROUND', nil, -8)
    -- Fixed-size corner caps: the rim does not stretch while the proxy grows.
    local border = skin:Panel(proxy, style, 0)
    local state = { frame = frame, proxy = proxy, fill = fill, border = border,
        group = alphaGroup(frame) }
    state.group:SetScript('OnFinished', function() finish(state) end)
    frame:HookScript('OnHide', function()
        state.played = nil
        finish(state)
    end)
    return state
end

local function anchoredTo(frame, anchor)
    for i = 1, frame:GetNumPoints() do
        local _, relative = frame:GetPoint(i)
        if relative == anchor then return true end
    end
end

local function open(frame, anchor, shell, style, direction, delay)
    if not ns.DarkSkin or not frame:IsVisible() then return end
    if anchor and not anchoredTo(frame, anchor) then return end
    shell = shell or frame
    local state = states[frame]
    if state == nil then
        -- A client missing any of these methods opens instantly, every time.
        local ok, built = pcall(build, frame, style or 'dialog')
        state = ok and built or false
        states[frame] = state
    end
    if not state or state.played or state.running then return end
    state.played = true
    delay = math.max(0, tonumber(delay) or 0)

    local proxy, skin = state.proxy, ns.DarkSkin
    -- 'left' grows from the shell's right edge toward the left, 'right' the
    -- reverse; anything else is the upward unfold from the bottom edge.
    local sideways = direction == 'left' or direction == 'right'
    local extent = sideways and proxy.SetWidth or proxy.SetHeight
    local measure = sideways and shell.GetWidth or shell.GetHeight
    -- The stand-in takes the shell's place when it starts to grow: after a
    -- delay the shell may have changed size meanwhile (the quest list's pull-up).
    local function place()
        proxy:SetFrameStrata(frame:GetFrameStrata())
        proxy:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
        proxy:SetScale(shell:GetEffectiveScale() / UIParent:GetEffectiveScale())
        proxy:ClearAllPoints()
        if sideways then
            local edge = direction == 'left' and 'RIGHT' or 'LEFT'
            proxy:SetPoint('TOP' .. edge, shell, 'TOP' .. edge, 0, 0)
            proxy:SetPoint('BOTTOM' .. edge, shell, 'BOTTOM' .. edge, 0, 0)
        else
            proxy:SetPoint('BOTTOMLEFT', shell, 'BOTTOMLEFT', 0, 0)
            proxy:SetPoint('BOTTOMRIGHT', shell, 'BOTTOMRIGHT', 0, 0)
        end
        extent(proxy, 1)
        proxy:SetAlpha(1)
        skin:StylePanelBackground(state.fill, state.border)
    end
    local placed = delay == 0
    if placed then place() else proxy:SetAlpha(0) end

    state.running = true
    local hold = Motion.grow * Motion.lead
    local elapsed, total = 0, math.max(Motion.grow, hold + Motion.fade)
    local _, _, _, fillAlpha = skin:FillColor()
    fillAlpha = math.min(.98, tonumber(fillAlpha) or .66)
    proxy:SetScript('OnUpdate', function(_, delta)
        elapsed = elapsed + delta
        local full = measure(shell)
        if elapsed >= delay + total or not full or full <= 0 or not frame:IsVisible() then
            finish(state)
            return
        end
        if not state.rims then
            settle(frame)
            -- First tick: every OnShow handler has run and created its rims.
            state.rims = {}
            for _, rim in ipairs(ignoringRims(frame)) do
                local group = rimGroups[rim]
                if not group then group = alphaGroup(rim); rimGroups[rim] = group end
                play(group, math.max(0, delay - elapsed))
                state.rims[#state.rims + 1] = group
            end
        end
        -- The delay: the drawer is held invisible and no stand-in shows yet.
        local t = elapsed - delay
        if t < 0 then return end
        if not placed then place(); placed = true end
        -- Unfold: a long, soft landing (quartic ease-out).
        extent(proxy, math.max(math.min(Motion.minHeight, full), full * Motion:Ease(t / Motion.grow)))
        -- Hand-over: the window's own translucent shell fades in over the
        -- stand-in. Fading the stand-in linearly would let the two fills add up
        -- unevenly (a visible pulse); this keeps their combined opacity constant.
        local shown = math.max(0, math.min(1, (t - hold) / Motion.fade))
        proxy:SetAlpha((1 - shown) / (1 - fillAlpha * shown))
    end)
    proxy:Show()
    play(state.group, delay)
    -- The motion ends itself; this only covers one that did not.
    C_Timer.After(delay + total + .1, function() finish(state) end)
end

-- A region outside the drawer that belongs to it (the map's way-back arrow on
-- the quest list): held invisible for `delay` plus the drawer's hold, then
-- faded in with its content. Render-only, like the drawer's own animation.
function Motion:Reveal(region, delay)
    load()
    if not self.enabled or not region or not region.CreateAnimationGroup then return end
    local group = rimGroups[region]
    if not group then group = alphaGroup(region); rimGroups[region] = group end
    play(group, math.max(0, tonumber(delay) or 0))
end

-- Call from the drawer's OnShow, after its placement code. Plays at most once
-- per shown state. With `anchor`, it plays only when the drawer really sits on
-- that anchor (a drawer combat leaves unplaced keeps its native place and opens
-- instantly). `shell` is the frame whose rectangle is the painted window and
-- `style` its DarkSkin rim style; they default to the drawer and 'dialog'.
-- `direction` 'left' or 'right' slides the shell out sideways from the edge
-- the drawer is attached by, with the same timing and easing; it defaults to
-- the upward unfold. `delay` seconds hold the drawer invisible before its
-- shell starts to grow (default none). Any error means an instant open.
function Motion:Open(frame, anchor, shell, style, direction, delay)
    load()
    if not self.enabled or not frame or not frame.CreateAnimationGroup then return end
    local ok = pcall(open, frame, anchor, shell, style, direction, delay)
    if not ok and states[frame] then pcall(finish, states[frame]) end
end
