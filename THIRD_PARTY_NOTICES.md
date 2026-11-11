# Third-party notices and provenance

The MIT license covers original Squanch-On contributions only. It does not
relicense ElvUI, BenikUI, their libraries, third-party fonts or game resources.
The public package contains the SquanchOn integration. Its original frame engines
are required local dependencies, retaining their original names and licenses.
See [component licenses and local assembly](docs/COMPONENT-LICENSES.md).

## Included public material

| Component | Scope and attribution | Terms |
| --- | --- | --- |
| TargetNameplateIndicator compatibility code | Port originally based on v1.67; copyright 2013–2016 Choonster. Adapted namespace, event lifecycle, configuration and artwork mapping. [Upstream](https://github.com/Choonster-WoW-AddOns/TargetNameplateIndicator). | [Full MIT notice](LICENSES/TargetNameplateIndicator-LICENSE.txt). Its historical image library is excluded; the code license does not license those images. |
| PT Sans Narrow Bold 2.003 | Unmodified `SquanchOn/media/fonts/ptsansnarrow_bold.ttf`; copyright 2010 ParaType Ltd.; Alexandra Korolkova, Olga Umpeleva and Vladimir Yefimov. Exact file matches [this pinned source](https://github.com/tukui-org/ElvUI/blob/9658ff3f7cdb83019aadffad6a4a7549508f7263/ElvUI/Game/Shared/Media/Fonts/PTSansNarrow.ttf). | [SIL OFL 1.1](LICENSES/PTSansNarrow-OFL.txt), also beside the font. Reserved names PT Sans and ParaType; the font remains OFL. SHA-256 `efc8710f9eb3e41405a7efaf9aba701e41dc0e9bcabd3aa0b08f111441fb247d`. |

`TargetCrosshairs.lua`, its numerical circle/arrow artwork and generator are
original contributions. [Provenance](LICENSES/TargetCrosshairs-PROVENANCE.md)
identifies the functional reference without claiming a clean-room process.
The independently generated polygons in `media/native-indicators` have
[source and provenance](SquanchOn/asset-source/NATIVE-INDICATORS-PROVENANCE.md).
No historical TNI image library, PowerAuras texture library, exported aura script
or throwknife audio is distributed here.

## External originals and private local assembly

ElvUI and its contributors supply the original ElvUI engine, options and library
integration. Benik supplies BenikUI. The required local core has five sibling
folders: `SquanchOn`, `ElvUI`, `ElvUI_Libraries`, `ElvUI_Options` and
`ElvUI_BenikUI`. A user-run assembler works locally with the user's originals;
its private assembled output is separate from the public SquanchOn package.

ElvUI's [custom license](https://github.com/tukui-org/ElvUI/blob/main/ElvUI/LICENSE.txt)
contains a GitHub upload exception, requires retaining its addon/folder name and
notice, and excludes third-party resources. This is not a blanket MIT license or
permission to rename ElvUI into SquanchOn. Its libraries retain individual terms.
BenikUI's [custom license](https://github.com/Benik/BenikUI/blob/development/ElvUI_BenikUI/LICENSE.txt)
permits private modifications and restricts public redistribution, with no GitHub
bundle exception. This public integration does not contain either original engine
or their restricted assets. Local imports do not grant republication rights.

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
