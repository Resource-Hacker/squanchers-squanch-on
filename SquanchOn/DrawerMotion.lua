-- SPDX-License-Identifier: MIT
-- One open motion for every drawer (chat-header windows, Friends, quests).
--
-- The drawer itself is never moved, scaled or resized: it sits at its final
-- place for the whole motion, so layout code that reads its rectangle sees the
-- same values with or without the motion. Two things play instead:
--   1. an addon-owned, unprotected proxy (the empty window shell: shared fill
--      and gold rim) grows upward from the drawer's bottom edge, while a
--      render-only Alpha animation holds the drawer invisible;
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
    grow = .35,     -- proxy unfolds, ease-out
    fade = .15,     -- content fades in; owner: half a second in total
    minHeight = 16, -- the rim's two corner caps need this much room
}
ns.DrawerMotion = Motion

local states = setmetatable({}, { __mode = 'k' }) -- frame -> state, or false
local rimGroups = setmetatable({}, { __mode = 'k' })

-- Held at 0 for the unfold, then faded in. No SetToFinalAlpha: the region's own
-- alpha is never written, so nothing here can leave it invisible.
local function alphaGroup(region)
    local group = region:CreateAnimationGroup()
    local hold = group:CreateAnimation('Alpha')
    hold:SetOrder(1); hold:SetDuration(Motion.grow); hold:SetFromAlpha(0); hold:SetToAlpha(0)
    local fade = group:CreateAnimation('Alpha')
    fade:SetOrder(2); fade:SetDuration(Motion.fade); fade:SetFromAlpha(0); fade:SetToAlpha(1)
    group:SetLooping('NONE')
    return group
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
    if state.frame:IsVisible() then pcall(refreshRims, state.frame) end
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

local function open(frame, anchor, shell, style)
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

    local proxy, skin = state.proxy, ns.DarkSkin
    proxy:SetFrameStrata(frame:GetFrameStrata())
    proxy:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
    proxy:SetScale(shell:GetEffectiveScale() / UIParent:GetEffectiveScale())
    proxy:ClearAllPoints()
    proxy:SetPoint('BOTTOMLEFT', shell, 'BOTTOMLEFT', 0, 0)
    proxy:SetPoint('BOTTOMRIGHT', shell, 'BOTTOMRIGHT', 0, 0)
    proxy:SetHeight(1)
    proxy:SetAlpha(1)
    skin:StylePanelBackground(state.fill, state.border)

    state.running = true
    local elapsed, total = 0, Motion.grow + Motion.fade
    proxy:SetScript('OnUpdate', function(_, delta)
        elapsed = elapsed + delta
        local full = shell:GetHeight()
        if elapsed >= total or not full or full <= 0 or not frame:IsVisible() then
            finish(state)
            return
        end
        if not state.rims then
            -- First tick: every OnShow handler has run and created its rims.
            state.rims = {}
            for _, rim in ipairs(ignoringRims(frame)) do
                local group = rimGroups[rim]
                if not group then group = alphaGroup(rim); rimGroups[rim] = group end
                group:Stop(); group:Play()
                state.rims[#state.rims + 1] = group
            end
        end
        if elapsed < Motion.grow then
            local eased = 1 - (1 - elapsed / Motion.grow) ^ 3
            proxy:SetHeight(math.max(math.min(Motion.minHeight, full), full * eased))
        else
            proxy:SetHeight(full)
            proxy:SetAlpha(1 - (elapsed - Motion.grow) / Motion.fade)
        end
    end)
    proxy:Show()
    state.group:Play()
    -- The motion ends itself; this only covers one that did not.
    C_Timer.After(total + .1, function() finish(state) end)
end

-- Call from the drawer's OnShow, after its placement code. Plays at most once
-- per shown state. With `anchor`, it plays only when the drawer really sits on
-- that anchor (a window shown in combat keeps its native place and opens
-- instantly). `shell` is the frame whose rectangle is the painted window and
-- `style` its DarkSkin rim style; they default to the drawer and 'dialog'.
-- Any error means an instant open.
function Motion:Open(frame, anchor, shell, style)
    if not self.enabled or not frame or not frame.CreateAnimationGroup then return end
    local ok = pcall(open, frame, anchor, shell, style)
    if not ok and states[frame] then pcall(finish, states[frame]) end
end
