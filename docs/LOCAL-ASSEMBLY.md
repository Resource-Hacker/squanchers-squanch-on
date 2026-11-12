# Public installation and private exact media

The standalone rewrite public package is a complete addon, with a single
`SquanchOn/` folder. It includes its required oUF, LibDispel and LibStub libraries.
It does not require ElvUI, ElvUI_Libraries, ElvUI_Options or ElvUI_BenikUI. The
former original-engine `tools/assemble_local.py` is retired and refuses that
assembly workflow. Do not use earlier five-folder instructions for this rewrite.

**The rewrite is staged for review, not yet accepted in game.** Building a ZIP or
assembling a private overlay establishes neither visual equivalence nor correct
combat behavior. [Compatibility and remaining acceptance](COMPATIBILITY.md)
describes the current limits.

## Build the public addon

From a source checkout with Python 3, Git and Lua 5.1 (`luac5.1`):

```sh
python3 tools/package.py
```

The default includes Git-tracked addon files, checks Lua syntax, resolves the
TOC/XML load graph and validates reuse hashes. The output is
`dist/SquanchOn-0.3.0-rewrite.zip` and its SHA-256 checksum. For isolated review
of intentional new source before it is tracked, use:

```sh
python3 tools/package.py --working-tree --check-only
python3 tools/package.py --working-tree
```

`--working-tree` is explicit because it includes untracked files under the addon
folder. Both selections reject private-media, private-provenance, LocalMedia.lua,
original reticle data and external required addon dependencies. Neither command
installs files, migrates settings, sends input or starts the game.

## Install with rollback

1. Close the game normally so current settings flush. Back up the working addon
   folders and `WTF` before replacing anything.
2. Extract the public ZIP so `Interface/AddOns/SquanchOn/SquanchOn.toc` exists.
3. Disable overlapping unit-frame and tooltip owners for the review profile.
   Keep their original folders and settings in the backup; the rewrite does not
   need their engines. Plater and DynamicCam remain optional separate addons.
4. Retain existing `SquanchOnDB` when upgrading. An exact transfer from an older
   suite or ElvUI profile is a separate, local settings migration, not a step the
   packager performs. Do not replace current settings with an older alpha import.
5. Review actual loading, errors, reticle controls, frames, tooltip presentation
   and supported settings before accepting the change. Keep a direct way to
   restore the prior addon selection and settings.

No personal profile, account export, saved macro or original engine seed ships in
the public package. Original ElvUI databases can remain untouched as rollback
state; the rewrite's profiles live inside `SquanchOnDB`.

## Optional private overlay

Exact owner appearance can depend on locally held fonts, status-bar textures,
ready/role/glow images or original reticle assets absent from the public package.
A private operator tool maintained separately from this repository can prepare a
new staging tree from explicit local sources. It must not copy the original
ElvUI or BenikUI engines, account settings, WTF or credentials into that tree.
There is no public original-engine assembly command to run.

The overlay's asset seam is `LocalMedia.lua`, loaded immediately after `Core.lua`
and before `Media.lua`. It sets `ns.LocalMedia` maps for `font`, `statusbar` and
`texture`: exact labels and normalized original paths map to files beneath
`Interface\\AddOns\\SquanchOn\\private-media\\`. Source notices and hash
provenance stay in the private output. Without an exact mapping, the public
resolver can use bundled/game defaults and records missing media identities;
a fallback is not a visual match.

An optional original reticle overlay replaces `HordeReticle.lua`, loads its exact
`HordeReticleData.lua` instead of public `ReticleConfig.lua`, and retains the
narrow original image/sound set and source notices. These original bytes and
private provenance must not enter the public package. The original renderer's
addon-relative media paths allow the private folder to remain `SquanchOn`.

Private staging should refuse existing output paths, unsafe paths, symlinks,
case collisions and unexpected file roots, recheck source bytes and validate the
resulting Lua/load closure. A per-file receipt should distinguish public source,
local assets, original reticle bytes and generated load/media maps. Preserve
source notices without inferring further permissions. Keep the output private;
see [component boundaries](COMPONENT-LICENSES.md).

Private media assembly and settings migration are separate operations. Neither
one certifies successful game loading, physical controls, visual equivalence,
group/raid behavior or owner acceptance.
