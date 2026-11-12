# Component licenses and package contents

Squancher's Squanch-On publishes original addon code under MIT, alongside the
separately licensed material identified in [third-party notices](../THIRD_PARTY_NOTICES.md).
The standalone rewrite supplies its own unit-frame layout, tooltip presentation
and settings editor. ElvUI and BenikUI engines and options addons are neither
bundled nor required. Their behavior and existing configuration supplied
references; that does not relicense their implementations or media.

## Public standalone package

The public ZIP contains one top-level `SquanchOn/` addon folder, including its
runtime modules, required libraries, public artwork and attached notices. The
libraries remain distinct attributed components:

| Component | Included scope and terms |
| --- | --- |
| oUF | Independently MIT-licensed framework by Trond A Ekseth, Val Voronov, Adrian L Lange and Rainrider. Its full notice is in `SquanchOn/libs/oUF/LICENSE.txt`. The Forever load graph is embedded directly; no ElvUI engine is loaded. |
| LibDispel | Separately MIT-licensed library, copyright 2026 Tukui.org. Full notice: `SquanchOn/libs/LibDispel/LICENSE.txt`. |
| LibStub | The source expressly places this versioning stub in the public domain and retains contributor credits in `SquanchOn/libs/LibStub/LibStub.lua`. |
| PT Sans Narrow Bold 2.003 | Unmodified ParaType font with its SIL OFL 1.1 notice retained beside the font and in the license notices. |
| TargetNameplateIndicator compatibility port | MIT code attributed to Choonster. The historical upstream image library is excluded. |
| Original Squanch-On artwork | Numerical geometric constructions and their generators; provenance distinguishes functional references from copied images. |

`SquanchOn/libs/provenance.json` identifies the supplying distribution and exact
preserved library files. Both reuse manifests record attributed file hashes.
A supplying distribution's overall license does not replace each library's own
notice. See [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md) for full attribution
and source links.

## Private exact media overlay

A separate owner-local overlay can supply exact locally held fonts, textures and
an original reticle renderer/data/assets. It still has a single `SquanchOn/`
addon folder; it does not restore the former five-folder engine assembly. That
private output is separate from the public release and retains source notices
and per-file provenance. Local availability does not establish redistribution
permission. Keep private files, manifests and output outside the repository,
issues and release assets.

Expressway, Homizio, Prototype, DOCK11, Homespun, Action Man, Forced Square,
Harry P and the original ElvUI/BenikUI textures are not supplied by the public
package. Their presence beside addon source does not make them MIT assets.
An overlay must identify the actual local file and preserve its attached
provenance; a similarly named replacement is not evidence of matching appearance.
The public package can use its bundled font and game-provided texture defaults
without an overlay. Such fallbacks do not reproduce an absent original asset.

The original ElvUI and BenikUI distributions retain their own notices and terms.
This project makes no general redistribution claim about those distributions,
third-party media or a user's locally assembled output. The former
`tools/assemble_local.py` original-engine workflow is retired; see
[public installation and local overlays](LOCAL-ASSEMBLY.md).

Native Blizzard paths and atlases reference resources already installed with the
game. No extracted Blizzard fonts, textures or sound files are published here.
Gameplay screenshots retain their documented provenance and Blizzard's rights;
the code's MIT license does not relicense game content.

Names identify their respective authors and projects and imply no endorsement.
