# Contributing

Keep changes focused on the reticle control contract or a clearly identified UI
surface. Describe what changes for a player and how it was observed.

- Preserve the right-held mouseover gate: closed during ordinary mouselook,
  open while held, closed on release without unlocking the camera.
- Preserve native input, explicit macro targeting, combat deferral and hardware
  cursor behavior. Keep visual feedback separate from input dispatch.
- Register settings through `SquanchOn/Options.lua` so they get search, undo,
  reset and combat queueing, and store them in the active profile.
- Keep account data, raw saved variables, per-character records, macros and
  external input helpers out of the repository and release archives. The shipped
  default layout is regenerated with `tools/export_defaults.lua`, not edited by hand.
- Retain upstream licenses and provenance, including separately MIT-licensed
  oUF, LibDispel, LibSerialize and the LibRangeCheck-3.0 item data in `Range.lua`, zlib-licensed LibDeflate,
  LibStub's public-domain source declaration, the DynamicCam (MIT) parts of
  `Camera.lua`, the GPL-2.0-only Horde reticle and the SIL OFL fonts. Update both reuse manifests when an
  attributed file changes; document the source revision and any modifications.

From a source checkout with Python 3, Git and `luac5.1` installed:

```sh
python tools/package.py
```

Only Git-tracked files under `SquanchOn/` enter the package. Stage intentional new
addon files before building. Documentation and CI stay in the source repository;
the addon ZIP has one top-level `SquanchOn/` folder.
For isolated review, `--working-tree` explicitly includes untracked addon source;
`--check-only` validates without an archive. Both refuse `WTF` and
`SavedVariables` content. No ElvUI/BenikUI engine or other addon is required or
bundled. Add only media whose license permits redistribution, with its license
text beside it. See [component licenses](docs/COMPONENT-LICENSES.md).

Use a backed-up game profile for manual validation and report the exact client,
class and input sequence. Separate source/package checks from actual gameplay
results. New automatic test infrastructure is not required for a contribution.
