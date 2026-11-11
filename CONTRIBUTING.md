# Contributing

Keep changes focused on the reticle control contract or a clearly identified UI
surface. Describe what changes for a player and how it was observed.

- Preserve the right-held mouseover gate: closed during ordinary mouselook,
  open while held, closed on release without unlocking the camera.
- Preserve native input, explicit macro targeting, combat deferral and hardware
  cursor behavior. Keep visual feedback separate from input dispatch.
- Keep account data, saved variables, private profiles, macros and external input
  helpers out of the repository and release archives.
- Retain upstream licenses and provenance. Update both reuse manifests when an
  attributed file changes; document the source revision and any modifications.

From a source checkout with Python 3, Git and `luac5.1` installed:

```sh
python tools/package.py
```

Only Git-tracked files under `SquanchOn/` enter the package. Stage intentional new
addon files before building. Documentation and CI stay in the source repository;
the public integration ZIP has one top-level `SquanchOn/` folder. The separate
local assembler combines it with the four exact original-name runtime folders.
Those local inputs, assembled archives and private presentation seeds must stay
outside this repository. See [component licenses](docs/COMPONENT-LICENSES.md).

Use a backed-up game profile for manual validation and report the exact client,
class and input sequence. Separate source/package checks from actual gameplay
results. New automatic test infrastructure is not required for a contribution.
