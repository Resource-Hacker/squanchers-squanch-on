# Third-party notices and provenance

The MIT license covers original Squanch-On contributions only. It does not
relicense the GPL-2.0 Horde reticle, the bundled fonts and libraries, ElvUI,
BenikUI or game resources. The package contains independently rewritten SquanchOn
frame, tooltip and options behavior. ElvUI and BenikUI engines are not included
or required. See [component licenses](../docs/COMPONENT-LICENSES.md).

## Included material

| Component | Scope and attribution | Terms |
| --- | --- | --- |
| TargetNameplateIndicator compatibility code | Port originally based on v1.67; copyright 2013–2016 Choonster. Adapted namespace, event lifecycle, configuration and artwork mapping. [Upstream](https://github.com/Choonster-WoW-AddOns/TargetNameplateIndicator). | [Full MIT notice](LICENSES/TargetNameplateIndicator-LICENSE.txt). Its historical image library is excluded; the code license does not license those images. |
| PT Sans Narrow Bold 2.003 | Unmodified `media/fonts/ptsansnarrow_bold.ttf`; copyright 2010 ParaType Ltd.; Alexandra Korolkova, Olga Umpeleva and Vladimir Yefimov. Exact file matches [this pinned source](https://github.com/tukui-org/ElvUI/blob/9658ff3f7cdb83019aadffad6a4a7549508f7263/ElvUI/Game/Shared/Media/Fonts/PTSansNarrow.ttf). | [SIL OFL 1.1](LICENSES/PTSansNarrow-OFL.txt), also beside the font. Reserved names PT Sans and ParaType; the font remains OFL. SHA-256 `efc8710f9eb3e41405a7efaf9aba701e41dc0e9bcabd3aa0b08f111441fb247d`. |

`TargetCrosshairs.lua`, its numerical circle/arrow artwork and generator are
original contributions. [Provenance](LICENSES/TargetCrosshairs-PROVENANCE.md)
identifies the functional reference without claiming a clean-room process.
The independently generated polygons in `media/native-indicators` have
[source and provenance](asset-source/NATIVE-INDICATORS-PROVENANCE.md).
No historical TNI image library is distributed here. The Horde reticle's own
GPL-2.0 data and media are listed in their section below.

## Bundled libraries and references

oUF is separately MIT-licensed by Trond A Ekseth, Val Voronov, Adrian L Lange
and Rainrider; see `libs/oUF/LICENSE.txt`. LibDispel is separately MIT-licensed
by Tukui.org; see `libs/LibDispel/LICENSE.txt`. LibStub is expressly placed in
the public domain by its own source header. Exact preserved source hashes and
the supplying distribution are recorded in `libs/provenance.json` and
`reuse-manifest.json`. The supplying ElvUI distribution does not replace these
individual library licenses. The rewrite uses those libraries directly, without
copying ElvUI or BenikUI frame, tooltip, options or lifecycle implementations.

ElvUI and BenikUI supplied behavioral and settings references. Their custom
engine licenses remain attached to those separate originals; neither engine is
renamed or distributed here.

The fonts the author's original setup used (Expressway, Homizio, Forced Square,
Harry P) and the original ElvUI/BenikUI textures are not distributed; the
bundled fonts and textures described below take their place. Blizzard paths
reference installed game resources, including the ready-check icons; no
extracted Blizzard images, fonts, sounds, FrameXML or binaries are bundled.

Plater and DynamicCam remain optional external addons with their own authors,
licenses and update ownership. ProjectAzilroka, MoveAny, Masque, AddOnSkins,
Bagnon and Semlar's Crosshairs supplied functional/settings references; their
complete implementations and assets are not part of this package. Their
individual licenses differ; this is a statement of package contents, not a blanket
restriction or permission for those projects.

All names acknowledge their respective authors and imply no endorsement,
sponsorship, ownership transfer or additional permissions.

## Horde reticle (GPL-2.0)

`HordeReticle.lua`, `HordeReticleData.lua` and `media/horde-reticle/` are
distributed under the GNU General Public License version 2
(`LICENSES/GPL-2.0.txt`), separately from the MIT-licensed remainder. They are a
standalone rendering of the author's own "The Terminator" aura group, built in
M33kAuras (a WeakAuras fork, GPL-2.0, <https://github.com/m33shoq/M33kAuras>).
Several layers began as the Wago imports <https://wago.io/OWg3rTo0a> and
<https://wago.io/jxJdu2yc6>. The five textures and `throwknife.ogg` are unmodified
PowerAurasMedia files as shipped inside that GPL-2.0 package; the package carries
no separate per-file authorship or license statement for them.

## Bundled layout fonts (SIL OFL 1.1)

Besides PT Sans Narrow Bold above, the shipped layout's text uses four freely
licensed fonts in `media/fonts`, each beside its own license text: Overpass
Bold, Afacad Medium, Oxanium Bold (static instances cut from the projects'
variable fonts) and Almendra Bold (unmodified). They stand in for the
differently licensed fonts the author's original setup used, so text shapes are
close to, not identical with, that setup.

## Unit-frame textures

`media/textures` (glow edge, status-bar face, role marks) are original numerical
constructions produced by `asset-source/generate-frame-media.py`, MIT.
