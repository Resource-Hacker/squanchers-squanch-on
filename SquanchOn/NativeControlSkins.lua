-- SPDX-License-Identifier: MIT
-- Squancher presentation only. Native windows retain content, state and input.
-- Original adapter; no ElvUI skin functions or templates are activated here.
local _, ns = ...
local Controls = {}
ns.NativeControlSkins = Controls
local hookedLists = setmetatable({}, { __mode = "k" })
local styled = setmetatable({}, { __mode = "k" })
local pending = setmetatable({}, { __mode = "k" })
local edges = {
    "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
    "TopEdge", "BottomEdge", "LeftEdge", "RightEdge",
}
local buttonFields = {
    "CloseButton", "CancelButton", "OkayButton", "AcceptButton", "ApplyButton",
    "DefaultsButton", "DoneButton", "SaveButton", "DeleteButton", "SearchButton",
    "FilterDropdown", "Dropdown", "IncrementButton", "DecrementButton",
    "PrevPageButton", "NextPageButton", "PreviousButton", "NextButton",
    "Button1", "Button2", "CustomButton", "PushToTalkKeybindButton",
}

local function ownedElsewhere(frame)
    if frame.IsForbidden and frame:IsForbidden() then return true end
    if frame.ignoreInLayout or frame == GameMenuFrame or frame:GetObjectType() == "GameTooltip" then return true end
    local name = frame.GetName and frame:GetName() or ""
    return name:find("Tooltip") or name:find("^ElvUI") or name:find("^Squancher") or name:find("^SquanchOn")
end

local function excluded(frame)
    local kind = type(frame)
    if (kind ~= "table" and kind ~= "userdata") or not frame.GetObjectType or ownedElsewhere(frame) then return true end
    -- Native intrinsic contract, also used by IsDropdownButtonIntrinsic. Some
    -- dropdowns carry icons/data, but only their separate chrome is styled.
    if frame.intrinsic == "DropdownButton" then return false end
    -- Item/spell/action/talent/list-entry content is not ordinary window chrome.
    return frame.Icon or frame.icon or frame.IconBorder or frame.iconBorder or frame.Cooldown
        or frame.cooldown or frame.Spell or frame.spellID or frame.itemID or frame.nodeID
        or frame.GetData or frame.GetElementData
end

local function hideTrim(frame)
    -- Never hide a NineSlice Center, icon, selection, checkmark or state overlay.
    for _, key in ipairs(edges) do
        local texture = frame.NineSlice and frame.NineSlice[key]
        if texture then texture:SetAlpha(0) end
    end
    for _, key in ipairs({ "Left", "Middle", "Center", "Right" }) do
        local texture = frame[key]
        if texture and texture.GetObjectType and texture:GetObjectType() == "Texture" then
            texture:SetAlpha(0)
        end
    end
end

local function textButton(frame)
    if not frame.GetText or not frame.GetFontString or not frame:GetFontString() then return false end
    -- Three-slice text buttons are chrome; naked quest titles/rows are content.
    return frame.Left and (frame.Middle or frame.Center) and frame.Right
end

-- Exact native chrome atlases, not a rule for arbitrary icons/item artwork.
local chromeHooks = setmetatable({}, { __mode = "k" })
local closeAtlases = {
    ["RedButton-Exit"] = true, ["RedButton-Exit-Disabled"] = true,
    ["RedButton-exit-pressed"] = true, ["RedButton-Highlight"] = true,
    ["RedButton-Expand"] = true, ["RedButton-Expand-Pressed"] = true,
    ["RedButton-Expand-Disabled"] = true, ["RedButton-Condense"] = true,
    ["RedButton-Condense-Pressed"] = true, ["RedButton-Condense-disabled"] = true,
}
local modelAtlases = {
    ["common-button-square-gray-up"] = true,
    ["common-button-square-gray-down"] = true,
}
local function scrollAtlas(atlas)
    return atlas and (atlas:find("^!?minimal%-scrollbar%-") or atlas:find("^!?UI%-ScrollBar%-"))
end
local function dropdownAtlas(atlas)
    return atlas == "common-dropdown-textholder" or atlas:find("^common%-dropdown%-[bc]%-button")
end
local function sliderTrackAtlas(atlas)
    return atlas == "Minimal_SliderBar_Left" or atlas == "Minimal_SliderBar_Right"
        or atlas == "_Minimal_SliderBar_Middle"
end
-- The native minimal checkbox paints a black square over its whole 30-unit hit
-- frame. Keep that frame, state and click area; draw one stepper-sized face.
local checkFaces = setmetatable({}, { __mode = "k" })
local function compactCheck(button, enabled)
    local face = checkFaces[button]
    if not face then
        face = CreateFrame("Frame", nil, button)
        checkFaces[button] = face
        face.ignoreInLayout = true
        face:EnableMouse(false)
        -- The fill is a region of the button so the native check stays above it.
        face.fill = button:CreateTexture(nil, "BACKGROUND")
        face.fill:SetAllPoints(face)
        face.fill:SetColorTexture(0.055, 0.055, 0.055, 0.9)
        ns.DarkSkin:Panel(face, "inner", 0)
    end
    local height = button:GetHeight()
    local size = height > 4 and math.min(16, height) or 16
    face:ClearAllPoints()
    face:SetPoint("LEFT", button, "LEFT", 1, 0)
    face:SetSize(size, size)
    for _, method in ipairs({ "GetNormalTexture", "GetPushedTexture" }) do
        local texture = button[method] and button[method](button)
        if texture then texture:SetAlpha(0) end
    end
    for _, method in ipairs({ "GetCheckedTexture", "GetDisabledCheckedTexture", "GetHighlightTexture" }) do
        local texture = button[method] and button[method](button)
        if texture then
            texture:ClearAllPoints()
            texture:SetAllPoints(face)
            if method ~= "GetHighlightTexture" then
                ns.DarkSkin:TintChrome(texture, enabled and method == "GetCheckedTexture")
            end
        end
    end
end
local function neutralChrome(texture, allowed, enabled)
    local atlas = texture and texture.GetAtlas and texture:GetAtlas()
    if not atlas or not allowed(atlas) then return end
    -- Keep the exact bitmap, texcoords, alpha and native state changes. The X
    -- and scrollbar arrows are composite artwork; their glyph shapes stay intact.
    ns.DarkSkin:TintChrome(texture, enabled)
end
local function refreshChrome(button, role)
    local enabled = not button.IsEnabled or button:IsEnabled()
    if role == "scroll" then
        for _, key in ipairs({ "Texture", "Overlay", "Begin", "Middle", "End" }) do
            neutralChrome(button[key], scrollAtlas, enabled)
        end
    elseif role == "dropdown" then
        -- Arrow, selected text, checks and menu remain under native ownership.
        neutralChrome(button.Background, dropdownAtlas, enabled)
    elseif role == "settingscheck" then
        compactCheck(button, enabled)
    else
        local atlases = role == "close" and closeAtlases or modelAtlases
        for _, method in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
            if button[method] then
                neutralChrome(button[method](button), function(atlas) return atlases[atlas] end, enabled)
            end
        end
        -- ModelSceneControlButton.Icon and its native pressed displacement stay untouched.
    end
end
local function finishChromeButton(button, role)
    if not button or not button.HookScript then return end
    if not chromeHooks[button] then
        chromeHooks[button] = role
        local function refresh(self) refreshChrome(self, role) end
        if type(button.OnButtonStateChanged) == "function" then
            hooksecurefunc(button, "OnButtonStateChanged", refresh)
        end
        -- MinimalScrollBar OnEnable desaturates its hierarchy after changing
        -- atlas. Reapply only these exact regions after the native state handler.
        button:HookScript("OnEnable", refresh)
        button:HookScript("OnDisable", refresh)
        button:HookScript("OnShow", refresh)
    end
    refreshChrome(button, role)
end

-- Neutral icon rims are presentation; item rarity and red unusable states
-- retain their native owners. These are exact current-client normal/border art.
local iconHooks = setmetatable({}, {__mode = "k"})
local iconButtons = setmetatable({}, {__mode = "k"})
local iconAtlases = {
    ["spellbook-item-iconframe"] = 1,
    ["talents-node-circle-gray"] = 1,
    ["spellbook-item-iconframe-inactive"] = 0.5,
    ["spellbook-item-iconframe-passive-inactive"] = 0.5,
}
local quickslot = GetFileIDFromPath([[Interface\Buttons\UI-Quickslot2]])
local function recolorIcon(texture)
    local state = iconHooks[texture]
    if not state or state.busy then return end
    local atlas = texture:GetAtlas()
    local shade = atlas and iconAtlases[atlas]
    if not shade and texture:GetTexture() ~= quickslot then return end
    if not shade then
        local r,g,b = unpack(state.native)
        if math.abs(r-g)>0.001 or math.abs(g-b)>0.001 then return end
        shade = 1
    end
    local _,_,_,alpha=texture:GetVertexColor()
    state.busy=true
    texture:SetDesaturated(true)
    local color=ns.DarkSkin.innerBorderColor
    texture:SetVertexColor(color[1]*shade, color[2]*shade, color[3]*shade, alpha)
    state.busy=false
end
local function iconTexture(texture)
    if not texture then return end
    local atlas=texture:GetAtlas()
    if texture:GetTexture() ~= quickslot and not (atlas and iconAtlases[atlas]) then return end
    if not iconHooks[texture] then
        local r,g,b=texture:GetVertexColor()
        if issecretvalue and (issecretvalue(r) or issecretvalue(g) or issecretvalue(b)) then return end
        iconHooks[texture]={native={r,g,b}}
        hooksecurefunc(texture,"SetVertexColor",function(self,r,g,b)
            local state=iconHooks[self]
            if state.busy then return end
            if issecretvalue and (issecretvalue(r) or issecretvalue(g) or issecretvalue(b)) then return end
            state.native={r,g,b};recolorIcon(self)
        end)
        hooksecurefunc(texture,"SetAtlas",recolorIcon)
        hooksecurefunc(texture,"SetTexture",recolorIcon)
    end
    recolorIcon(texture)
end
function Controls:Icon(frame)
    local normal=frame.GetNormalTexture and frame:GetNormalTexture()
    iconTexture(normal)
    local border=frame.Border
    if border and border.GetAtlas and iconAtlases[border:GetAtlas()] then iconTexture(border) end
    if not iconButtons[frame] and frame.SetNormalTexture then
        iconButtons[frame]=true
        hooksecurefunc(frame,"SetNormalTexture",function(self) iconTexture(self:GetNormalTexture()) end)
    end
end

function Controls:FinishChrome(frame)
    self:Icon(frame)
    if InCombatLockdown() then pending[frame] = "chrome"; return end
    -- Exact LargeSideTabButtonTemplate, shared by Character, Collections,
    -- Professions and Social. Keep icon, mask and native selection/fade states.
    local background = frame.Background
    if not frame.squancherCleanSideTab and frame.Icon and frame.Mask and background and background.GetAtlas
        and background:GetAtlas() == "common-sidetab" then
        for _, key in ipairs({ "Background", "SelectedTexture", "TabGlow", "HighlightTexture" }) do
            local texture = frame[key]
            if texture then
                ns.DarkSkin:TintChrome(texture, not frame.IsEnabled or frame:IsEnabled())
            end
        end
    end
    local normal = frame.GetNormalTexture and frame:GetNormalTexture()
    if normal and closeAtlases[normal:GetAtlas()] then
        finishChromeButton(frame, "close")
        ns.DarkSkin:Panel(frame, "inner", 0)
    end
    -- Minimal/WowTrim scrollbars are EventFrames with EventButton steppers and
    -- a split thumb, not Slider objects. Restrict this adapter to their schema.
    local track = frame.Track
    local thumb = track and track.Thumb
    local middle = thumb and thumb.Middle
    if not (frame.Back and frame.Forward and frame.GetScrollPercentage
        and middle and scrollAtlas(middle:GetAtlas())) then return end
    for _, owner in ipairs({ frame.Background or track, track }) do
        for _, key in ipairs({ "Begin", "Middle", "End" }) do
            neutralChrome(owner[key], scrollAtlas, true)
        end
    end
    finishChromeButton(frame.Back, "scroll")
    finishChromeButton(frame.Forward, "scroll")
    finishChromeButton(thumb, "scroll")
    ns.DarkSkin:Panel(frame, "inner", 0)
end

function Controls:Style(frame, explicit)
    if excluded(frame) then return end
    if InCombatLockdown() then pending[frame] = explicit or "auto"; return end
    -- Exact shared InsetFrameTemplate chrome; its marble is decorative.
    -- The enclosing native window supplies the single translucent background.
    if frame.layoutType == "InsetFrameTemplate" then
        hideTrim(frame)
        if frame.Bg then frame.Bg:SetAlpha(0) end
        ns.DarkSkin:Panel(frame, "inner", 0)
        return
    end
    local kind = frame:GetObjectType()
    local edit = kind == "EditBox"
    local check = kind == "CheckButton"
    local slider = kind == "Slider"
    local dropdown = frame.intrinsic == "DropdownButton"
    local settingsTab = SettingsPanel and (frame == SettingsPanel.GameTab or frame == SettingsPanel.AddOnsTab)
    local button = dropdown or kind == "Button" and (explicit or textButton(frame))
    -- The tab frame is taller than its art, a minimal slider taller than its
    -- track: a frame-sized rim there is a stray box. finishSettingsTab,
    -- finishSettingsControls and compactCheck own those three.
    if settingsTab or not (edit or check or slider or button) then return end
    local normal = check and frame:GetNormalTexture()
    if normal and normal:GetAtlas() == "checkbox-minimal" then finishChromeButton(frame, "settingscheck"); return end
    if slider and frame.Left and frame.Left.GetAtlas and sliderTrackAtlas(frame.Left:GetAtlas()) then return end
    local raised = kind == "Button" and not dropdown and textButton(frame)
    -- Ordinary three-slice text art is replaced by the shared raised face.
    -- Keep native icons, selected tabs, checks, thumbs and dropdown glyphs.
    if raised then
        hideTrim(frame)
        for _, key in ipairs({ "Left", "Middle", "Center", "Right" }) do
            local texture = frame[key]
            if texture and texture.IsObjectType and texture:IsObjectType("Texture") then texture:Hide() end
        end
    elseif edit or button and not dropdown then hideTrim(frame) end
    if dropdown then finishChromeButton(frame, "dropdown") end
    if styled[frame] then return end
    styled[frame] = true
    local border = raised and ns.DarkSkin:RaisedButton(frame, "inner") or ns.DarkSkin:Panel(frame, "inner", 0)
    border.ignoreInLayout = true
    frame:HookScript("OnShow", function(self) Controls:Style(self, explicit) end)
end

local function listRows(list)
    if InCombatLockdown() then pending[list] = "scan"; return end
    -- A newly shown native ScrollBox can Update before its view is assigned.
    if list.GetView and not list:GetView() then return end
    local count = 0
    list:ForEachFrame(function(row)
        count = count + 1
        if count <= 64 then Controls:Scan(row, 96) end
    end)
end

function Controls:Scan(root, limit)
    if not root or not ns.DarkSkin then return end
    if InCombatLockdown() then pending[root] = "scan"; return end
    local seen, count = {}, 0
    local function visit(frame, depth)
        if not frame or seen[frame] or depth > 7 or count >= (limit or 512) then return end
        seen[frame] = true
        if ownedElsewhere(frame) then return end
        count = count + 1
        if ns.NativeText then
            if frame.ButtonText and SocialUIScrollableHeaderMixin
                and frame.Initialize == SocialUIScrollableHeaderMixin.Initialize then
                ns.NativeText:Header(frame.ButtonText)
            end
            ns.NativeText:Frame(frame)
        end
        -- A semantic entry can contain a normal checkbox/edit control; inspect
        -- descendants but never treat that entry itself as a chrome button.
        Controls:Style(frame)
        Controls:FinishChrome(frame)
        for _, key in ipairs(buttonFields) do Controls:Style(frame[key], true) end
        if type(frame.ForEachFrame) == "function" and type(frame.Update) == "function" and not hookedLists[frame] then
            hookedLists[frame] = true
            -- Native ScrollBox owns pooled acquisition/reuse; no polling/ticker.
            hooksecurefunc(frame, "Update", listRows)
        end
        if frame.bindingsPool and frame.bindingsPool.EnumerateActive then
            local n = 0
            for panel in frame.bindingsPool:EnumerateActive() do
                n = n + 1
                if n > 128 then break end
                for _, key in ipairs({ "Button1", "Button2", "CustomButton" }) do
                    Controls:Style(panel[key], true)
                end
            end
        end
        if frame.GetChildren then
            for _, child in ipairs({ frame:GetChildren() }) do visit(child, depth + 1) end
        end
    end
    visit(root, 0)
end

-- These exact Forever canvases pool decorative headers separately from controls.
local finishHooks, expansionHooks = {}, {}
local function hideTexture(region)
    if region and region.IsObjectType and region:IsObjectType('Texture') then region:SetAlpha(0) end
end
local function finishList(box, callback)
    if not box or not box.ForEachFrame or not box.Update then return end
    local function apply(list)
        if InCombatLockdown() then pending[list] = 'finish'; return end
        if list.GetView and not list:GetView() then return end
        local count = 0
        list:ForEachFrame(function(row) count = count + 1; if count <= 128 then callback(row) end end)
    end
    if not finishHooks[box] then finishHooks[box] = apply; hooksecurefunc(box, 'Update', apply) end
    apply(box)
end
local function characterCategory(row)
    if ns.NativeText then ns.NativeText:Header(row.Title); ns.NativeText:Frame(row) end
    -- Native stat rows alternate bronze backgrounds; the root owns the one
    -- translucent body. Only category headings receive an opaque raised face.
    hideTexture(row.Background)
    if row.Title and row.Background then ns.DarkSkin:RaisedPlate(row, 'inner') end
end
local sideCategoryHooks = setmetatable({}, { __mode = "k" })
local function finishSideCategories(pane)
    if ownedElsewhere(pane) then return end
    if InCombatLockdown() then pending[pane] = "sidecategories"; return end
    local pools = pane.rowPools
    local pool = pools and pools.GetPool and pools:GetPool("CharacterFrameSidePaneCategoryTemplate")
    if not pool then return end
    local count = 0
    for row in pool:EnumerateActive() do
        count = count + 1
        if count > 128 then break end
        -- These category rows use Label, unlike the stat ScrollBox's Title.
        -- Never touch the separate reward icon/content row pools.
        if row.Label and row.Background then
            if ns.NativeText then ns.NativeText:Header(row.Label) end
            hideTexture(row.Background)
            ns.DarkSkin:RaisedPlate(row, "inner")
        end
    end
end
-- Native settings layout is drawn for 12-unit text at scale 1. NativeText's
-- 8-unit body would shrink with the compact window, so size it in screen units.
local function settingsText(root, limit)
    local text = ns.NativeText
    if not text or not root or not SettingsPanel then return end
    local scale = SettingsPanel:GetEffectiveScale() / UIParent:GetEffectiveScale()
    if not (scale > 0) then return end
    local count = 0
    local function visit(frame, depth)
        if depth > 7 or count >= limit or not frame.GetObjectType or ownedElsewhere(frame) then return end
        count = count + 1
        if frame:GetObjectType() == "EditBox" then text:Region(frame, false, 8 / scale) end
        for _, region in ipairs({ frame:GetRegions() }) do
            if region.IsObjectType and region:IsObjectType("FontString") then
                text:Region(region, false, (text.headers[region] and 12 or 8) / scale)
            end
        end
        for _, child in ipairs({ frame:GetChildren() }) do visit(child, depth + 1) end
    end
    visit(root, 0)
end
local function settingsCategory(row)
    if row.Background then hideTexture(row.Background); ns.DarkSkin:Panel(row, 'inner', 0) end
    -- Selected/hover bar: SetAtlas keeps this tint; muted gold, not bright yellow.
    local bar = row.Texture
    if bar and bar.IsObjectType and bar:IsObjectType("Texture") then
        ns.DarkSkin:TintChrome(bar)
        bar:SetAlpha(0.6)
    end
    settingsText(row, 32)
end
local settingsSliderHooks, settingsTabHooks = {}, {}
local settingsBackground, settingsUnderlay, settingsDivider
local function refreshSettingsSlider(slider)
    for _, key in ipairs({ "Left", "Middle", "Right" }) do
        neutralChrome(slider[key], sliderTrackAtlas, slider:IsEnabled())
    end
end
local function finishSettingsControls(owner, depth)
    if not owner or (depth or 0) > 3 then return end
    local check = owner.Checkbox
    local normal = check and check.GetNormalTexture and check:GetNormalTexture()
    if normal and normal:GetAtlas() == "checkbox-minimal" then finishChromeButton(check, "settingscheck") end
    local wrapper = owner.SliderWithSteppers
    local slider = wrapper and wrapper.Slider
    if slider and slider.Left and slider.Left.GetAtlas and slider.Left:GetAtlas() == "Minimal_SliderBar_Left" then
        if not settingsSliderHooks[slider] then
            settingsSliderHooks[slider] = true
            hooksecurefunc(slider, "SetEnabled", refreshSettingsSlider)
            slider:HookScript("OnShow", refreshSettingsSlider)
        end
        refreshSettingsSlider(slider)
    end
    for index, control in ipairs(owner.Controls or {}) do
        if index > 16 then break end
        finishSettingsControls(control, (depth or 0) + 1)
    end
end
local function finishSettingsTab(tab)
    if not tab or tab.upLeftTexture ~= "Options_Tab_Left" then return end
    local function refresh(self)
        for _, key in ipairs({ "Left", "Middle", "Right" }) do
            -- Preserve native selected/unselected atlas and alpha differences.
            neutralChrome(self[key], function(atlas) return atlas:find("^Options_Tab_") end, self:IsEnabled())
        end
    end
    if not settingsTabHooks[tab] then
        settingsTabHooks[tab] = true
        hooksecurefunc(tab, "UpdateAtlas", refresh)
    end
    refresh(tab)
end
local function hideAtlas(owner, atlas)
    for _, region in ipairs({ owner:GetRegions() }) do
        if region.GetAtlas and region:GetAtlas() == atlas then hideTexture(region) end
    end
end
local function finishCharacterBackground(frame)
    -- Exact Camelot decorative layers sit ABOVE CharacterFrame.Bg. Removing
    -- only these lets the shared translucent root show through both panes.
    local left, right = frame.LeftPaneHost, frame.RightPaneHost
    if left then hideAtlas(left, "UI-Character-Info-General-BG") end
    if right then
        hideAtlas(right, "UI-Character-Info-Stat-BG")
        hideTexture(right.StoneBg)
    end
    local strip = PaperDollFrame and PaperDollFrame.TopBackgroundStripHost
    if strip then
        hideTexture(strip.TopBackgroundStrip)
        hideTexture(strip.TopBackgroundStripBottomEdge)
    end
    local model = CharacterModelScene
    if model then
        for _, key in ipairs({ "BackgroundTopLeft", "BackgroundTopRight",
            "BackgroundBotLeft", "BackgroundBotRight", "BackgroundOverlay" }) do
            local texture = model[key]
            -- Hide survives the native race-overlay SetAlpha and texture updates.
            -- The scene, actor, equipment and model controls remain untouched.
            if texture and texture.IsObjectType and texture:IsObjectType("Texture") then texture:Hide() end
        end
    end
    local player, pet = CharacterStatsPaneScrollBox, CharacterStatsPanePetScrollBox
    hideTexture(player and player.ClassBackground)
    hideTexture(pet and pet.ClassBackground)
end

local function finishSettingsBackground(frame)
    -- SettingsFrameTemplate.Bg is a FRAME with four flat panel pieces, not the
    -- Texture Bg handled by the generic native-window adapter. Replace only
    -- these known decorative pieces with one chat-matched underlay.
    local bg = frame.Bg
    if bg then
        for _, key in ipairs({ "BottomLeft", "BottomRight", "BottomEdge", "TopSection" }) do hideTexture(bg[key]) end
    end
    if not settingsBackground then
        -- Dense text needs a readable backing: near-black beneath the shared fill.
        settingsUnderlay = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
        settingsUnderlay:SetColorTexture(0.02, 0.02, 0.02, 0.85)
        settingsBackground = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    end
    local border = ns.DarkSkin:Panel(frame, "dialog", 0)
    ns.DarkSkin:FitPanelBackground(settingsUnderlay, border)
    ns.DarkSkin:StylePanelBackground(settingsBackground, border)
    hideAtlas(frame, "Options_InnerFrame")
    finishSettingsTab(frame.GameTab)
    finishSettingsTab(frame.AddOnsTab)
end
local function settingsRow(row)
    -- A section's native group trim goes; rows are not controls and get no rim.
    if row.NineSlice then hideTrim(row) end
    Controls:Style(row.Button, true)
    finishSettingsControls(row)
    Controls:Scan(row, 128)
    settingsText(row, 128)
    if row.EvaluateVisibility and not expansionHooks[row] then
        expansionHooks[row] = true
        hooksecurefunc(row, 'EvaluateVisibility', function(self)
            Controls:Scan(self, 128); settingsText(self, 128)
        end)
    end
end
-- 920x724 native units x 0.64 = 589x463 UI units; 8-unit body text is then
-- 12.5 native units, the size this layout was drawn for.
local SETTINGS_SCALE = 0.64
local function compactSettings(frame)
    frame:SetClampedToScreen(true)
    -- HUD panels are MEDIUM; popups and menus stay above at DIALOG and higher.
    local strata = frame:GetFrameStrata()
    if strata == "BACKGROUND" or strata == "LOW" or strata == "MEDIUM" then frame:SetFrameStrata("HIGH") end
    local db = ns.db
    if not db or db.settingsCompactScale then return end
    -- One-time, through the window's geometry owner (LayoutWindows reapplies the
    -- stored scale after native resets); later editor resizing wins.
    local id, editor, windows = "window_SettingsPanel", ns.LayoutEditor, ns.LayoutWindows
    local record = editor and editor:Copy(editor:Read(id))
    local old = record and type(record.scale) == "number" and record.scale > 0 and record.scale or frame:GetScale()
    if old > SETTINGS_SCALE then
        if record then
            local anchor = record.nativeAnchor
            -- Offsets are in the window's own scale: keep the same screen anchor.
            if anchor then anchor[3], anchor[4] = anchor[3] * old / SETTINGS_SCALE, anchor[4] * old / SETTINGS_SCALE end
            record.scale = SETTINGS_SCALE
        else
            record = { scale = SETTINGS_SCALE, nativeAnchor = { "CENTER", "CENTER", 0, 0 } }
        end
        if editor and windows then
            editor:Store(id, record)
            windows:Apply(id, frame)
        else
            frame:SetScale(SETTINGS_SCALE)
        end
    end
    db.settingsCompactScale = SETTINGS_SCALE
end
function Controls:FinishWindow(frame)
    if InCombatLockdown() then pending[frame] = 'window'; return end
    if frame == CharacterFrame then
        finishCharacterBackground(frame)
        for index, pane in ipairs(frame.SidePanes or {}) do
            if index > 32 then break end
            if not ownedElsewhere(pane) and type(pane.AddCategory) == "function" then
                if not sideCategoryHooks[pane] then
                    sideCategoryHooks[pane] = true
                    -- AddCategory acquires/shows the exact native category row
                    -- and assigns Label before this presentation posthook runs.
                    hooksecurefunc(pane, "AddCategory", finishSideCategories)
                end
                finishSideCategories(pane)
            end
        end
        local model = _G.CharacterModelScene
        local controls = model and model.ControlFrame
        if controls then
            for _, key in ipairs({ "zoomInButton", "zoomOutButton", "rotateLeftButton", "rotateRightButton", "resetButton" }) do
                local button = controls[key]
                local normal = button and button:GetNormalTexture()
                if normal and modelAtlases[normal:GetAtlas()] then
                    finishChromeButton(button, "model")
                    ns.DarkSkin:Panel(button, "inner", 0)
                end
            end
        end
        local right = frame.RightPaneHost
        if right then hideTexture(right.StoneBg); ns.DarkSkin:Panel(right, 'inner', 0) end
        local player, pet = _G.CharacterStatsPaneScrollBox, _G.CharacterStatsPanePetScrollBox
        finishList(player and player.ScrollBox, characterCategory)
        finishList(pet and pet.ScrollBox, characterCategory)
    elseif frame == SettingsPanel then
        compactSettings(frame)
        finishSettingsBackground(frame)
        local categories, container = frame.CategoryList, frame.Container
        if categories then ns.DarkSkin:Panel(categories, 'inner', 0) end
        if container then ns.DarkSkin:Panel(container, 'inner', 0) end
        finishList(categories and categories.ScrollBox, settingsCategory)
        local list = container and container.SettingsList
        local header = list and list.Header
        if header then
            hideAtlas(header, "Options_HorizontalDivider")
            if not settingsDivider then
                settingsDivider = ns.DarkSkin:Divider(header, header:GetWidth())
                settingsDivider:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, settingsDivider.paintCenter)
            end
            ns.DarkSkin:SizeDivider(settingsDivider, header:GetWidth())
        end
        finishList(list and list.ScrollBox, settingsRow)
        self:Style(frame.ClosePanelButton, true)
        settingsText(frame, 512)
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function()
    local work = pending
    pending = setmetatable({}, { __mode = "k" })
    for frame, mode in pairs(work) do
        if mode == 'finish' and finishHooks[frame] then finishHooks[frame](frame)
        elseif mode == "sidecategories" then finishSideCategories(frame)
        elseif mode == "chrome" then Controls:FinishChrome(frame)
        elseif mode == 'window' then Controls:FinishWindow(frame)
        elseif mode == "scan" then Controls:Scan(frame)
        else Controls:Style(frame, mode ~= "auto") end
    end
end)
