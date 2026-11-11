# Private local runtime assembly

`tools/assemble_local.py` builds an offline, owner-local runtime ZIP from an
explicit **already installed and scoped** original addon tree plus the SquanchOn
ZIP produced by `tools/package.py`. It neither downloads nor installs anything.
An upstream source archive is insufficient: it lacks the exact scoped loaders,
owner-confinement lifecycle, private seed and expected original media.

The ZIP contains five original-name addon folders: `ElvUI`, `ElvUI_Libraries`,
`ElvUI_Options`, `ElvUI_BenikUI`, and `SquanchOn`. Original files and attached
licenses remain byte-identical. The private owner seed is deliberately preserved
for this local assembly. Existing native profiles remain in their existing game
SavedVariables; the tool does not copy, import or rewrite them.

**Do not publish, upload, attach to an issue, push to GitHub, or redistribute the
assembled ZIP or extracted original trees.** Some included components and assets
have redistribution restrictions. This private assembly grants no additional
rights. Keep the output outside the repository and do not add it to a release.

From the candidate source checkout, first create the public SquanchOn package
using the normal package workflow. The new bridge/layout files must be included
by that workflow's tracked-file policy. Then run:

```bash
python3 tools/assemble_local.py \
  --source-addons '/absolute/path/to/scoped/AddOns' \
  --squanchon-zip '/absolute/path/to/checkout/dist/SquanchOn-0.2.0-candidate.zip' \
  --output-dir '/absolute/path/to/new-private-assembly'
```

The three paths above are mandatory. To retain the owner's existing reticle
artwork, warning visuals and sound in the **private output only**, add:

```bash
  --reticle-addon '/absolute/path/to/installed/SquancherMouselookSuite'
```

This optional input reads only original `HordeReticle.lua`,
`HordeReticleData.lua`, five named `Aura*.tga` files and `throwknife.ogg` under
`media/horde-reticle/`, the existing world-target `media/Crosshairs/circle-dashed.tga`,
plus their inspected license/provenance paths. The
installed donor's `licenses/M33-GPLv2.txt` supplies the private copy of
`LICENSE-M33-GPLv2.txt` when the header-named root file is absent. Optional
`REPORT.md`, `licenses/HordeReticle-PROVENANCE.md` and
`licenses/HordeReticle-ASSETS.json` are retained when present. Notices live under
`SquanchOn/private-provenance/reticle/`; original Lua headers remain unchanged.

The private ZIP replaces `SquanchOn/HordeReticle.lua` byte for byte, loads the
original `HordeReticleData.lua` in place of `ReticleConfig.lua`, removes the
unused public `ReticleConfig.lua`, and includes the exact original assets. The
original renderer derives its media path from the addon name, so no Lua rewrite
is needed. No other modules are imported; camera and public source files are
unchanged. Without this flag, the supplied public package's reticle stays intact.
These private reticle files and their provenance must not be copied into the
public repository or uploaded with a release.

The output directory must not exist, its parent
must already exist, and it must be outside both this repository and the source
addon tree. The tool rejects symlink paths, unsafe ZIP members, additional addon
roots, nonregular input files, oversized inputs, case-colliding paths and private
WTF/SavedVariables/credential paths. Only the four explicitly selected original
addon folders are read; adjacent addons and game state are excluded.

Before writing output, the tool checks executable TOC and XML closure for the
Forever `camelot` game type, including backslash paths and bounded relative XML
references. It verifies the scoped top-level loaders, required dependencies,
matching native core/library/options versions, Benik's minimum ElvUI version,
original ElvUF metadata, original lazy options, required media/licenses, and the
absence of the alpha's second active unit-frame/tooltip renderer. It rechecks
original input bytes before output and verifies every archived file afterward.

The private output directory has mode `0700`; output files have mode `0600`:

- `SquanchOn-PRIVATE-local-runtime.zip`: deterministic ZIP metadata, five addon
  folders and a private notice.
- `SquanchOn-PRIVATE-local-runtime.zip.sha256`: archive checksum.
- `manifest.json`: individual file SHA-256 hashes, byte counts, native versions
  and the admitted executable dependency closure; no absolute input paths. It
  separately records the unmodified public package's per-file hashes, every
  owner-local reticle override's input/output hashes, the private TOC change,
  the removed public configuration file and per-file source classifications.
- `PRIVATE-NOT-FOR-REDISTRIBUTION.txt`: the private-only notice.

This is static assembly and byte verification. It does not establish successful
game loading, visual equivalence, combat correctness or owner acceptance. Close
the game and use a separately reviewed, rollback-protected installation procedure
if deployment is later requested. Never run the earlier standalone-alpha private
installer unchanged: its removal list deletes the original dependencies needed
by this native-engine runtime.
