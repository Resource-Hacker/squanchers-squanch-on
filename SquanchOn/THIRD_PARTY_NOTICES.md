# Third-party notices and provenance

The MIT license covers original Squanch-On contributions only. It does not
relicense ElvUI, BenikUI, their libraries, third-party fonts or game resources.
The public package contains independently rewritten SquanchOn frame, tooltip and
options behavior. ElvUI and BenikUI engines are not included or required.
See [component licenses and local assembly](https://github.com/Resource-Hacker/squanchers-squanch-on/blob/main/docs/COMPONENT-LICENSES.md).

## Included public material

| Component | Scope and attribution | Terms |
| --- | --- | --- |
| TargetNameplateIndicator compatibility code | Port originally based on v1.67; copyright 2013–2016 Choonster. Adapted namespace, event lifecycle, configuration and artwork mapping. [Upstream](https://github.com/Choonster-WoW-AddOns/TargetNameplateIndicator). | [Full MIT notice](LICENSES/TargetNameplateIndicator-LICENSE.txt). Its historical image library is excluded; the code license does not license those images. |
| PT Sans Narrow Bold 2.003 | Unmodified `media/fonts/ptsansnarrow_bold.ttf`; copyright 2010 ParaType Ltd.; Alexandra Korolkova, Olga Umpeleva and Vladimir Yefimov. Exact file matches [this pinned source](https://github.com/tukui-org/ElvUI/blob/9658ff3f7cdb83019aadffad6a4a7549508f7263/ElvUI/Game/Shared/Media/Fonts/PTSansNarrow.ttf). | [SIL OFL 1.1](LICENSES/PTSansNarrow-OFL.txt), also beside the font. Reserved names PT Sans and ParaType; the font remains OFL. SHA-256 `efc8710f9eb3e41405a7efaf9aba701e41dc0e9bcabd3aa0b08f111441fb247d`. |

`TargetCrosshairs.lua`, its numerical circle/arrow artwork and generator are
original contributions. [Provenance](LICENSES/TargetCrosshairs-PROVENANCE.md)
identifies the functional reference without claiming a clean-room process.
The independently generated polygons in `media/native-indicators` have
[source and provenance](asset-source/NATIVE-INDICATORS-PROVENANCE.md).
No historical TNI image library, PowerAuras texture library, exported aura script
or throwknife audio is distributed here.

## Bundled libraries and private local assets

oUF is separately MIT-licensed by Trond A Ekseth, Val Voronov, Adrian L Lange
and Rainrider; see `libs/oUF/LICENSE.txt`. LibDispel is separately MIT-licensed
by Tukui.org; see `libs/LibDispel/LICENSE.txt`. LibStub is expressly placed in
the public domain by its own source header. Exact preserved source hashes and
the supplying distribution are recorded in `libs/provenance.json` and
`reuse-manifest.json`. The supplying ElvUI distribution does not replace these
individual library licenses. The rewrite uses those libraries directly, without
copying ElvUI or BenikUI frame, tooltip, options or lifecycle implementations.

ElvUI and BenikUI supplied behavioral and owner-settings references. Their
custom engine licenses remain attached to those separate originals; neither
engine is renamed or distributed here. A separate private owner-local assembly
may supply exact locally held fonts, textures and original reticle code/assets.
That private output retains its source notices and per-file provenance, is not a
public release, and grants no redistribution rights. The retired original-engine
assembler cannot build that output.

Exact externally supplied fonts, textures and libraries retain their own rights.
This public package does not supply Expressway, Homizio, Prototype, DOCK11,
Homespun, Action Man, Forced Square or Harry P files. Blizzard paths reference
installed game resources; no extracted game images, fonts, sounds, FrameXML or
binaries are bundled.

Plater and DynamicCam remain optional external addons with their own authors,
licenses and update ownership. ProjectAzilroka, MoveAny, Masque, AddOnSkins,
Bagnon and Semlar's Crosshairs supplied functional/settings references; their
complete implementations and assets are not part of this public package. Their
individual licenses differ; this is a statement of package contents, not a blanket
restriction or permission for those projects.

All names acknowledge their respective authors and imply no endorsement,
sponsorship, ownership transfer or additional permissions.
