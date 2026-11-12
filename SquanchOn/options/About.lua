-- SPDX-License-Identifier: MIT
-- About page: version, a summary of the licenses, and the slash commands.
local addonName, ns = ...
local Options = ns.Options
if not Options then return end

local function metadata(field)
    local read = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    return read and read(addonName, field) or nil
end

Options:Category({ id = 'about', title = 'About', order = 990,
    desc = "Squancher's Squanch-On: reticle-centred mouselook and a unified native interface." })

Options:Add('about', {
    { id = 'about.version', type = 'note', label = 'Version', section = 'Version', keywords = 'version build interface',
        text = function()
            local version = metadata('Version') or (ns.db and ns.db.loadedVersion) or 'unknown'
            local _, _, _, interface = GetBuildInfo()
            return 'Squanch-On ' .. tostring(version) .. '\nGame interface ' .. tostring(interface or 'unknown')
                .. '\n' .. tostring(metadata('X-Website') or '')
        end },
    { id = 'about.licenses', type = 'note', label = 'Licenses', section = 'Licenses', keywords = 'license credits authors mit gpl ofl',
        text = 'Original Squanch-On code and generated artwork: MIT.\n'
            .. 'Horde reticle data and media: GNU GPL version 2, distributed separately from the MIT parts.\n'
            .. 'Bundled fonts: SIL Open Font License 1.1, each beside its own license text.\n'
            .. 'Bundled libraries (oUF, LibDispel, LibStub, LibRangeCheck-3.0 and others in the libs folder) keep their own authors and licenses.\n'
            .. 'Ported parts credit their sources: TargetNameplateIndicator (Choonster, MIT) and the DynamicCam settings model (mpstark and LudiusMaximus, MIT).\n\n'
            .. 'Full notices, authors and provenance: THIRD_PARTY_NOTICES.md and the LICENSES folder inside the addon folder.' },
    { id = 'about.commands', type = 'note', label = 'Slash commands', section = 'Commands', keywords = 'slash commands help chat',
        text = '/squanchon   this window; add words to search, or a page name to open it\n'
            .. '/sqedit   move and resize the interface on the layout grid\n'
            .. '/sqms   mouselook status and switches (on, off, lock, left, native, return, bindings, panic)\n'
            .. '/sqms camera   camera settings\n'
            .. '/sqms mouseover on | off   mouseover casting setup\n'
            .. '/sqcrosshairs   target ring\n'
            .. '/tni  or  /sqnameplates   nameplate indicators\n'
            .. '/sqauras [count]   preview the buff and debuff layout' },
})
