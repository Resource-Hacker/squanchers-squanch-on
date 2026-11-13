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
    -- The world map's breadcrumbs have their own adapter (Controls:NavBar).
    if WorldMapFrame and frame == WorldMapFrame.NavBar then return true end
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
-- Its rim is the small border, as thick on screen as on the unit frames
-- whatever the Options window's scale; half strength while disabled.
local checkFaces = setmetatable({}, { __mode = "k" })
local function compactCheck(button, enabled)
    local face = checkFaces[button]
    if not face then
        face = CreateFrame("Frame", nil, button)
        checkFaces[button] = face
        face.ignoreInLayout = true
        face:EnableMouse(false)
        -- Regions of the button, so the native check stays above them.
        face.fill = button:CreateTexture(nil, "BACKGROUND")
        face.fill:SetAllPoints(face)
        face.fill:SetColorTexture(0.11, 0.11, 0.11, 1)
    end
    local height = button:GetHeight()
    local size = height > 4 and math.min(16, height) or 16
    face:ClearAllPoints()
    face:SetPoint("LEFT", button, "LEFT", 1, 0)
    face:SetSize(size, size)
    ns.DarkSkin:SmallBorder(face):SetAlpha(enabled and 1 or 0.5)
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
        ns.DarkSkin:SmallBox(frame)
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
    ns.DarkSkin:SmallBox(frame)
end

function Controls:Style(frame, explicit)
    if excluded(frame) then return end
    if InCombatLockdown() then pending[frame] = explicit or "auto"; return end
    -- Exact shared InsetFrameTemplate chrome; its marble is decorative.
    -- The enclosing native window supplies the single translucent background.
    if frame.layoutType == "InsetFrameTemplate" then
        hideTrim(frame)
        if frame.Bg then frame.Bg:SetAlpha(0) end
        ns.DarkSkin:SmallBox(frame)
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
    local border = raised and ns.DarkSkin:RaisedButton(frame, "inner") or ns.DarkSkin:SmallBox(frame)
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
-- Options text: soft off-white body, gold headings. Native white (selected),
-- grey (disabled/unbound) and red (warning) colours keep their meaning.
-- The theme's live colour tables; the copies are what regions currently show.
local BODY_TEXT, HEADER_TEXT = ns.DarkSkin.bodyTextColor, ns.DarkSkin.headerTextFlat
local shownBody, shownHeader = { unpack(BODY_TEXT) }, { unpack(HEADER_TEXT) }
local settingsColorHooks = setmetatable({}, { __mode = "k" })
local settingsFonts, settingsFontCount = {}, 0
local function nativeYellow(r, g, b)
    if type(r) ~= "number" or issecretvalue and issecretvalue(r) then return false end
    return r > 0.95 and g > 0.7 and g < 0.9 and b < 0.2
end
local function settingsColor(region)
    local state = settingsColorHooks[region]
    if not state or state.busy then return end
    local r, g, b, a = region:GetTextColor()
    local header = ns.NativeText and ns.NativeText.headers[region]
    local yellow = nativeYellow(r, g, b)
    local color = header and (yellow or r > 0.95 and g > 0.95 and b > 0.95) and HEADER_TEXT
        or not header and yellow and BODY_TEXT
    if not color then return end
    state.busy = true
    region:SetTextColor(color[1], color[2], color[3], a)
    state.busy = false
end
local function settingsTextColor(region)
    if not settingsColorHooks[region] then
        settingsColorHooks[region] = {}
        -- Native rows reassign font objects on reuse, selection and enable.
        hooksecurefunc(region, "SetTextColor", settingsColor)
        hooksecurefunc(region, "SetFontObject", settingsColor)
    end
    settingsColor(region)
end
-- A Button re-applies its normal font object on every state change, outside
-- the FontString hooks above: give it an off-white copy of that exact font.
local function settingsButtonFont(button)
    local font = button.GetNormalFontObject and button:GetNormalFontObject()
    if not font or not font.GetTextColor or not nativeYellow(font:GetTextColor()) then return end
    local clone = settingsFonts[font]
    if not clone then
        settingsFontCount = settingsFontCount + 1
        clone = CreateFont("SquanchOnSettingsText" .. settingsFontCount)
        clone:CopyFontObject(font)
        clone:SetTextColor(BODY_TEXT[1], BODY_TEXT[2], BODY_TEXT[3])
        settingsFonts[font] = clone
    end
    button:SetNormalFontObject(clone)
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
        settingsButtonFont(frame)
        for _, region in ipairs({ frame:GetRegions() }) do
            if region.IsObjectType and region:IsObjectType("FontString") then
                text:Region(region, false, (text.headers[region] and 12 or 8) / scale)
                settingsTextColor(region)
            end
        end
        for _, child in ipairs({ frame:GetChildren() }) do visit(child, depth + 1) end
    end
    visit(root, 0)
end
-- Rims inside the 0.64 window are drawn at the ordinary UI scale, like every
-- other window's: at 0.64 the 2px atlas rim loses its horizontal edges.
local function settingsRim(frame)
    local skin = ns.DarkSkin
    local border = skin:Panel(frame, "inner", 0)
    border:SetScale(UIParent:GetEffectiveScale() / frame:GetEffectiveScale())
    skin:FitPanelBorder(border, frame, skin.styles.inner)
    if border.raisedFace then skin:FitPanelBackground(border.raisedFace, border) end
    return border
end
-- Boxes there (list, page, tab) wear the small border, inset in screen units.
local function settingsBox(frame)
    return ns.DarkSkin:SmallBox(frame, UIParent:GetEffectiveScale() / frame:GetEffectiveScale())
end
-- One small-border rule on the owner's bottom edge.
local settingsRules = setmetatable({}, { __mode = "k" })
local function settingsRule(owner)
    local line = settingsRules[owner]
    if not line then
        line = owner:CreateTexture(nil, "BORDER")
        settingsRules[owner] = line
        line:SetPoint("BOTTOMLEFT", owner, "BOTTOMLEFT")
        line:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT")
    end
    ns.DarkSkin:SmallRule(line)
end
-- Theme change: retint what this file coloured and still shows that colour.
local function sameColor(r, g, b, color)
    return type(r) == "number" and not (issecretvalue and issecretvalue(r))
        and math.abs(r - color[1]) < 0.004 and math.abs(g - color[2]) < 0.004 and math.abs(b - color[3]) < 0.004
end
ns.DarkSkin:OnTheme(function()
    for texture in pairs(iconHooks) do recolorIcon(texture) end
    for region, state in pairs(settingsColorHooks) do
        local r, g, b, a = region:GetTextColor()
        local header = ns.NativeText and ns.NativeText.headers[region]
        if sameColor(r, g, b, header and shownHeader or shownBody) then
            local color = header and HEADER_TEXT or BODY_TEXT
            state.busy = true
            region:SetTextColor(color[1], color[2], color[3], a)
            state.busy = false
        end
    end
    for _, clone in pairs(settingsFonts) do clone:SetTextColor(BODY_TEXT[1], BODY_TEXT[2], BODY_TEXT[3]) end
    shownBody[1], shownBody[2], shownBody[3] = BODY_TEXT[1], BODY_TEXT[2], BODY_TEXT[3]
    shownHeader[1], shownHeader[2], shownHeader[3] = HEADER_TEXT[1], HEADER_TEXT[2], HEADER_TEXT[3]
end)
local function settingsCategory(row)
    -- Header rows (Gameplay/Accessibility/System) own Background. A full rim
    -- there doubled the list box's top edge: one rule under the title instead.
    if row.Background then
        hideTexture(row.Background)
        if ns.NativeText then ns.NativeText:Header(row.Label) end
        settingsRule(row)
    end
    -- Selected/hover bar: SetAtlas keeps this tint; muted gold, not bright yellow.
    local bar = row.Texture
    if bar and bar.IsObjectType and bar:IsObjectType("Texture") then
        ns.DarkSkin:TintChrome(bar)
        bar:SetAlpha(0.6)
    end
    settingsText(row, 32)
end
local settingsSliderHooks = {}
local function refreshSettingsSlider(slider)
    for _, key in ipairs({ "Left", "Middle", "Right" }) do
        neutralChrome(slider[key], sliderTrackAtlas, slider:IsEnabled())
    end
end
-- Settings buttons are not three-slice text buttons (keybinding buttons are a
-- nine-piece stretch template, the value face an intrinsic dropdown, steppers
-- state-texture squares), so textButton() never gave them the raised face.
local settingsArt = setmetatable({}, { __mode = "k" }) -- textures this file draws
local settingsButtonHooks = setmetatable({}, { __mode = "k" })
local keptArt = { "Arrow", "SelectedHighlight", "Icon", "icon" }
local function ownRaised(button)
    local panels = ns.DarkSkin.byFrame[button]
    local border = panels and panels.inner
    if not border or not border.raisedFace then return end
    settingsArt[border.raisedFace] = true
    for _, edge in pairs(border.raisedEdges) do settingsArt[edge] = true end
end
local function stripArt(button)
    ownRaised(button)
    local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
    for index, region in ipairs({ button:GetRegions() }) do
        if index > 64 then break end
        if region ~= highlight and not settingsArt[region] and region.IsObjectType and region:IsObjectType("Texture") then
            local keep = false
            for _, key in ipairs(keptArt) do keep = keep or button[key] == region end
            if not keep then region:SetAlpha(0) end
        end
    end
    local slice = button.NineSlice
    if slice and slice.SetAlpha then slice:SetAlpha(0) end
end
-- direction: -1/1 for a stepper, which gets its own arrow glyph; nil otherwise.
local function settingsButton(button, direction)
    if not button or not button.HookScript or not button.GetRegions or not button.IsEnabled
        or button.IsForbidden and button:IsForbidden() then return end
    stripArt(button)
    ns.DarkSkin:RaisedButton(button, "inner")
    ownRaised(button)
    settingsRim(button)
    local state = settingsButtonHooks[button]
    if not state then
        state = {}
        settingsButtonHooks[button] = state
        if direction then
            local glyph = button:CreateTexture(nil, "ARTWORK")
            settingsArt[glyph] = true
            glyph:SetTexture([[Interface\ChatFrame\ChatFrameExpandArrow]])
            if direction < 0 then glyph:SetTexCoord(1, 0, 0, 1) end
            glyph:SetPoint("CENTER")
            state.glyph = glyph
        end
        local function refresh(self)
            -- Native enable/disable swaps or re-shows its state textures.
            stripArt(self)
            local enabled = self:IsEnabled()
            if state.glyph then ns.DarkSkin:TintChrome(state.glyph, enabled) end
            if self.Arrow then ns.DarkSkin:TintChrome(self.Arrow, enabled) end
        end
        state.refresh = refresh
        button:HookScript("OnEnable", refresh)
        button:HookScript("OnDisable", refresh)
        button:HookScript("OnShow", refresh)
    end
    if state.glyph then
        local size = math.max(6, math.min(button:GetWidth(), button:GetHeight()) * 0.5)
        state.glyph:SetSize(size, size)
    end
    state.refresh(button)
end
local function settingsBindings(owner)
    for _, key in ipairs({ "Button1", "Button2", "CustomButton", "PushToTalkKeybindButton" }) do
        settingsButton(owner[key])
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
    -- SettingsDropdownWithButtons: value face plus previous/next steppers.
    local control = owner.Control
    if type(control) == "table" or type(control) == "userdata" then
        settingsButton(control.Dropdown)
        settingsButton(control.DecrementButton, -1)
        settingsButton(control.IncrementButton, 1)
    end
    settingsBindings(owner)
    local pool = owner.bindingsPool
    if pool and pool.EnumerateActive then
        local count = 0
        for panel in pool:EnumerateActive() do
            count = count + 1
            if count > 128 then break end
            settingsBindings(panel)
        end
    end
    for index, child in ipairs(owner.Controls or {}) do
        if index > 16 then break end
        finishSettingsControls(child, (depth or 0) + 1)
    end
end
-- Game/AddOns: one charcoal plate per tab, from the native art's top (the
-- selected tab stands taller) down onto the category box's top edge.
local settingsTabs = {}
local function refreshSettingsTab(tab)
    local state = settingsTabs[tab]
    if not state then return end
    for _, key in ipairs({ "Left", "Middle", "Right" }) do
        local texture = tab[key]
        if texture and texture.IsObjectType and texture:IsObjectType("Texture") then texture:SetAlpha(0) end
    end
    local left = tab.Left
    local atlas = left and left.GetAtlas and left:GetAtlas()
    local selected
    if tab.IsSelected then selected = tab:IsSelected() and true or false
    else selected = atlas ~= nil and tab.upLeftTexture ~= nil and atlas ~= tab.upLeftTexture end
    -- Regions and the tab share one coordinate space.
    local top, artTop, bottom = tab:GetTop(), left and left.GetTop and left:GetTop(), tab:GetBottom()
    local box = SettingsPanel and SettingsPanel.CategoryList
    local boxTop = box and box:GetTop()
    local height = tab:GetHeight()
    local drop = top and artTop and top - artTop or 0
    local reach = bottom and boxTop and bottom - boxTop or 0
    -- Unexpected geometry falls back to the tab's own rectangle.
    if drop < 0 or drop >= height then drop = 0 end
    if math.abs(reach) >= height then reach = 0 end
    state.holder:ClearAllPoints()
    state.holder:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, -drop)
    state.holder:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 0, -reach)
    local high, low = 0.12, 0.045
    if selected then high, low = 0.23, 0.085 elseif state.hovered then high, low = 0.17, 0.055 end
    state.fill:SetGradient("VERTICAL", CreateColor(low, low, low, 1), CreateColor(high, high, high, 1))
end
local function finishSettingsTab(tab)
    if not tab or not tab.HookScript or not ns.DarkSkin then return end
    if not settingsTabs[tab] then
        local state = { holder = CreateFrame("Frame", nil, tab) }
        settingsTabs[tab] = state
        state.holder.ignoreInLayout = true
        state.holder:EnableMouse(false)
        -- The fill is a region of the tab, so the native label stays above it.
        state.fill = tab:CreateTexture(nil, "BACKGROUND")
        state.fill:SetTexture([[Interface\Buttons\WHITE8X8]])
        state.fill:SetAllPoints(settingsBox(state.holder))
        for _, method in ipairs({ "UpdateAtlas", "SetSelected" }) do
            if type(tab[method]) == "function" then hooksecurefunc(tab, method, refreshSettingsTab) end
        end
        tab:HookScript("OnShow", refreshSettingsTab)
        tab:HookScript("OnSizeChanged", refreshSettingsTab)
        tab:HookScript("OnEnter", function(self) state.hovered = true; refreshSettingsTab(self) end)
        tab:HookScript("OnLeave", function(self) state.hovered = false; refreshSettingsTab(self) end)
    end
    refreshSettingsTab(tab)
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

local function clearBackdrop(owner)
    if not owner then return end
    for _, key in ipairs({ "Bg", "BG", "Background", "InsetBg" }) do hideTexture(owner[key]) end
    hideTexture(owner.NineSlice and owner.NineSlice.Center)
end
local settingsBackground
local function finishSettingsBackground(frame)
    -- SettingsFrameTemplate.Bg is a FRAME of flat panel pieces, not the Texture
    -- Bg handled by the generic native-window adapter. Every decorative layer
    -- goes, so the body is exactly the one shared chat fill: nothing darker.
    local bg = frame.Bg
    if bg and bg.GetRegions and not (bg.IsObjectType and bg:IsObjectType("Texture")) then
        for index, region in ipairs({ bg:GetRegions() }) do
            if index > 32 then break end
            hideTexture(region)
        end
    end
    local container = frame.Container
    local list = container and container.SettingsList
    local categories = frame.CategoryList
    clearBackdrop(frame); clearBackdrop(categories); clearBackdrop(container); clearBackdrop(list)
    clearBackdrop(categories and categories.ScrollBox); clearBackdrop(list and list.ScrollBox)
    if not settingsBackground then settingsBackground = frame:CreateTexture(nil, "BACKGROUND", nil, -7) end
    ns.DarkSkin:StylePanelBackground(settingsBackground, ns.DarkSkin:Panel(frame, "dialog", 0))
    hideAtlas(frame, "Options_InnerFrame")
    finishSettingsTab(frame.GameTab)
    finishSettingsTab(frame.AddOnsTab)
end
local function settingsRow(row)
    -- A section's native group trim goes; rows are not controls and get no rim.
    if row.NineSlice then hideTrim(row) end
    Controls:Style(row.Button, true)
    Controls:Scan(row, 128)
    finishSettingsControls(row)
    settingsText(row, 128)
    if row.EvaluateVisibility and not expansionHooks[row] then
        expansionHooks[row] = true
        hooksecurefunc(row, 'EvaluateVisibility', function(self)
            if InCombatLockdown() then pending[self] = "scan"; return end
            Controls:Scan(self, 128); finishSettingsControls(self); settingsText(self, 128)
        end)
    end
end
-- Free dragging by any part of the window that is not a control. The drop is
-- an owner placement: it goes through the window's LayoutWindows record (the
-- same non-automatic commit /sqedit makes), which then re-places the frame.
local SETTINGS_ID = "window_SettingsPanel"
local settingsMoving, settingsDragHooked
local function commitSettingsDrop(frame)
    if InCombatLockdown() then pending[frame] = "settingsdrop"; return end
    local editor = ns.LayoutEditor
    local spec = editor and editor.specs and editor.specs[SETTINGS_ID]
    local rect = spec and editor:Rect(frame)
    if not rect then return end
    local ok, result = pcall(spec.commit, editor:Clamp(rect), false, false)
    if not ok then geterrorhandler()(result) end
end
local function stopSettingsDrag(frame)
    if not settingsMoving then return end
    settingsMoving = false
    frame:StopMovingOrSizing()
    -- The layout record is the one position owner, not the client layout cache.
    if frame.SetUserPlaced then frame:SetUserPlaced(false) end
    if frame:IsVisible() then commitSettingsDrop(frame) end
end
local function settingsDraggable(frame)
    if settingsDragHooked then return end
    settingsDragHooked = true
    if frame:GetScript("OnDragStart") then
        -- Already natively draggable: keep its handlers, only persist the drop.
        frame:HookScript("OnDragStop", function(self) if self:IsVisible() then commitSettingsDrop(self) end end)
        return
    end
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:HookScript("OnDragStart", function(self)
        if InCombatLockdown() and self:IsProtected() then return end
        if ns.LayoutEditor and ns.LayoutEditor.active then return end
        settingsMoving = true
        self:StartMoving()
    end)
    frame:HookScript("OnDragStop", stopSettingsDrag)
    frame:HookScript("OnHide", stopSettingsDrag)
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
    -- One-time default place: top centre, clear of the HUD along the bottom of
    -- the screen (the body is as translucent as the chat). A placement the
    -- owner made by dragging or in /sqedit is never replaced.
    if db and not db.settingsTopPlacement and ns.LayoutEditor and ns.LayoutWindows then
        local id, editor = "window_SettingsPanel", ns.LayoutEditor
        local record = editor:Copy(editor:Read(id)) or { scale = SETTINGS_SCALE }
        if not record.placed then
            record.x, record.y = nil, nil
            record.nativeAnchor = { "TOP", "TOP", 0, -12 / (record.scale or SETTINGS_SCALE) }
            editor:Store(id, record)
            ns.LayoutWindows:Apply(id, frame)
        end
        db.settingsTopPlacement = true
    end
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
-- The world map's breadcrumbs (NavigationBar.lua: home "World", one button per
-- zone with an optional dropdown arrow, an overflow menu). NavBar keeps its
-- buttons, widths, order, frame levels, menus and clicks; only their art, the
-- label's anchors and font change. Each button wears the raised charcoal face
-- with a thin gold rim, 22 high in its 30; the current map (the last button,
-- which NavBar disables) is drawn like the selected chat tab: pressed, white.
local navBars, navStates = setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })
local navHidden = setmetatable({}, { __mode = "k" })
-- The NavButtonTemplate dropdown's square face is alpha 0 at rest and set to 1
-- by its own OnEnter; keep it at 0 (the gold arrow and highlight remain).
local function keepHidden(texture)
    if not texture or navHidden[texture] then return end
    navHidden[texture] = true
    texture:SetAlpha(0)
    hooksecurefunc(texture, "SetAlpha", function(self, alpha) if alpha ~= 0 then self:SetAlpha(0) end end)
end
local function navLabel(button)
    return navStates[button] and navStates[button].label or button.text
end
-- Like the chat tabs' labels: tab font and size in interface units, whatever
-- the map's scale. Heading gold; the current map white.
local function paintNavButton(button)
    local state = navStates[button]
    local list = button:GetParent() and button:GetParent().navList
    local current = list and list[#list] == button
    state.paint(true, current or state.down, not current and state.hovered)
    local label = navLabel(button)
    if not label then return end
    local path, size, flags = ns.DarkSkin:HeadingFont()
    -- NavBar sizes each button to its label at the native font, so the label
    -- never grows past that size or it spills over the button's ends.
    if not state.nativeSize then
        local _, native = label:GetFont()
        state.nativeSize = type(native) == "number" and native > 0 and native or 12
    end
    local scale = button:GetEffectiveScale()
    if scale > 0 then size = size * UIParent:GetEffectiveScale() / scale end
    label:SetFont(path, math.min(state.nativeSize - 1, size), flags)
    local color = current and { 1, 1, 1, 1 } or ns.DarkSkin.headerTextColor
    label:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end
local function skinNavButton(button, glyph)
    if not button or navStates[button] then return end
    -- Every texture here is NavBar art: faces, chevrons, the selection and the
    -- home button's shadow. State changes swap them; none resets their alpha.
    for _, region in ipairs({ button:GetRegions() }) do
        if region:IsObjectType("Texture") then region:SetAlpha(0) end
    end
    local paint, border = ns.DarkSkin:RaisedPlate(button, "inner")
    local state = { paint = paint }
    navStates[button] = state
    -- The next button is anchored `xoffset` into this one (home -15, overflow
    -- -18) and drawn below it: end the face where that button begins.
    local overlap = math.max(0, -(button.xoffset or 0))
    local edge = ns.DarkSkin.styles.inner.offset
    border:ClearAllPoints()
    border:SetPoint("TOPLEFT", button, "TOPLEFT", -edge, -4)
    border:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", edge - overlap, 4)
    state.overlap = overlap
    if glyph then
        -- The overflow menu's glyph was its art: a label in its place.
        state.label = button:CreateFontString(nil, "OVERLAY")
        state.label:SetText(glyph)
    end
    local arrow = button.MenuArrowButton
    if arrow then
        keepHidden(arrow.NormalTexture); keepHidden(arrow.PushedTexture)
        ns.DarkSkin:TintChrome(arrow.Art)
        ns.DarkSkin:TintChrome(arrow:GetHighlightTexture())
        -- One small-border rule sets the dropdown apart; it shows with the arrow.
        local rule = arrow:CreateTexture(nil, "ARTWORK")
        ns.DarkSkin:SmallRule(rule, true)
        rule:SetPoint("TOPLEFT", arrow, "TOPLEFT", 0, -8)
        rule:SetPoint("BOTTOMLEFT", arrow, "BOTTOMLEFT", 0, 8)
    end
    local function refresh() paintNavButton(button) end
    button:HookScript("OnEnter", function() state.hovered = true; refresh() end)
    button:HookScript("OnLeave", function() state.hovered = false; state.down = false; refresh() end)
    button:HookScript("OnMouseDown", function(_, mouse) if mouse == "LeftButton" then state.down = true; refresh() end end)
    button:HookScript("OnMouseUp", function() state.down = false; refresh() end)
    button:HookScript("OnHide", function() state.hovered, state.down = false, false end)
end
-- The label centred on the face, left of a shown dropdown arrow. Its native
-- height (12) would clip the scaled font: 0 lets the text size it.
local function placeNavLabel(button)
    local label, state = navLabel(button), navStates[button]
    if not label then return end
    local arrow = button.MenuArrowButton
    label:ClearAllPoints()
    label:SetPoint("LEFT", button, "LEFT", 4, 0)
    if arrow and arrow:IsShown() then label:SetPoint("RIGHT", arrow, "LEFT", -2, 0)
    else label:SetPoint("RIGHT", button, "RIGHT", -4 - state.overlap, 0) end
    label:SetHeight(0)
    label:SetJustifyH("CENTER")
end
-- After every NavBar change (NavBar_CheckLength ends each add, reset and trim):
-- new buttons get the look, and the current map moves to the last one.
function Controls:FinishNavBar(bar)
    for _, button in ipairs(bar.navList or {}) do
        skinNavButton(button)
        placeNavLabel(button)
        paintNavButton(button)
    end
    local overflow = bar.overflowButton
    if overflow then
        skinNavButton(overflow, "...")
        placeNavLabel(overflow)
        paintNavButton(overflow)
    end
end
function Controls:NavBar(bar)
    if not bar or not bar.navList then return end
    if not navBars[bar] then
        navBars[bar] = true
        -- The bar's own parchment, overlay and inset trim: the map window's
        -- shared fill shows through. Buttons, menus and gamepad icons remain.
        for _, owner in ipairs({ bar, bar.overlay }) do
            for _, region in ipairs({ owner:GetRegions() }) do
                if region:IsObjectType("Texture") then region:SetAlpha(0) end
            end
        end
        if not self.navHooked then
            self.navHooked = true
            hooksecurefunc("NavBar_CheckLength", function(owner)
                if navBars[owner] then Controls:FinishNavBar(owner) end
            end)
        end
        -- Label sizes follow the map's scale (MapDrawer fits it to the quest list).
        local map = bar:GetParent()
        if map and map.SetScale then hooksecurefunc(map, "SetScale", function() Controls:FinishNavBar(bar) end) end
    end
    self:FinishNavBar(bar)
end

function Controls:FinishWindow(frame)
    if InCombatLockdown() then pending[frame] = 'window'; return end
    if WorldMapFrame and frame == WorldMapFrame then self:NavBar(frame.NavBar) end
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
                    ns.DarkSkin:SmallBox(button)
                end
            end
        end
        local right = frame.RightPaneHost
        if right then hideTexture(right.StoneBg); ns.DarkSkin:SmallBox(right) end
        local player, pet = _G.CharacterStatsPaneScrollBox, _G.CharacterStatsPanePetScrollBox
        finishList(player and player.ScrollBox, characterCategory)
        finishList(pet and pet.ScrollBox, characterCategory)
    elseif frame == SettingsPanel then
        compactSettings(frame)
        settingsDraggable(frame)
        finishSettingsBackground(frame)
        local categories, container = frame.CategoryList, frame.Container
        if categories then settingsBox(categories) end
        if container then settingsBox(container) end
        finishList(categories and categories.ScrollBox, settingsCategory)
        local list = container and container.SettingsList
        local header = list and list.Header
        if header then
            hideAtlas(header, "Options_HorizontalDivider")
            settingsRule(header)
            settingsButton(header.DefaultsButton)
        end
        finishList(list and list.ScrollBox, settingsRow)
        self:Style(frame.ClosePanelButton, true)
        settingsButton(frame.CloseButton)
        settingsButton(frame.ApplyButton)
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
        elseif mode == "settingsdrop" then commitSettingsDrop(frame)
        elseif mode == "scan" then Controls:Scan(frame)
        else Controls:Style(frame, mode ~= "auto") end
    end
end)
