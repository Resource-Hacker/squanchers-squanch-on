# Contributing

Keep changes focused on the reticle control contract or a clearly identified UI
surface. Describe what changes for a player and how it was observed.

- Preserve the right-held mouseover gate: closed during ordinary mouselook,
  open while held, closed on release without unlocking the camera.
- Preserve native input, explicit macro targeting, combat deferral and hardware
  cursor behavior. Keep visual feedback separate from input dispatch.
- Keep account data, saved variables, private profiles, macros and external input
  helpers out of the repository and release archives.
- Retain upstream licenses and provenance, including separately MIT-licensed oUF
  and LibDispel and LibStub's public-domain source declaration. Update both reuse manifests when an
  attributed file changes; document the source revision and any modifications.

From a source checkout with Python 3, Git and `luac5.1` installed:

```sh
python tools/package.py
```

Only Git-tracked files under `SquanchOn/` enter the package. Stage intentional new
addon files before building. Documentation and CI stay in the source repository;
the complete public addon ZIP has one top-level `SquanchOn/` folder.
For isolated review, `--working-tree` explicitly includes untracked addon source;
`--check-only` validates without an archive. Both paths reject private overlay
files. No original ElvUI/BenikUI engine is required or bundled. Private exact
media, original reticle overlays and owner settings must remain outside this
repository; the former original-engine assembler is retired. See [component licenses](docs/COMPONENT-LICENSES.md).

Use a backed-up game profile for manual validation and report the exact client,
class and input sequence. Separate source/package checks from actual gameplay
results. New automatic test infrastructure is not required for a contribution.
