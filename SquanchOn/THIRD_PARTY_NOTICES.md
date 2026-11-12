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
| Camera settings model | `Camera.lua` ports parts of [DynamicCam](https://github.com/Mpstark/DynamicCam) 2.21.5: the setting and situation catalogue, wheel-increment rules, situation precedence, transition and zoom-restore rules, and the wheel-zoom easing procedure of its LibCamera. Copyright 2016–2020 Michael P. Starkweather (mpstark), 2020–2026 LudiusMaximus. The driver, zoom and rotation tracking, condition model, import and settings page are original. | [MIT](LICENSES/DynamicCam-MIT.txt) |
| PT Sans Narrow Bold 2.003 | Unmodified `media/fonts/ptsansnarrow_bold.ttf`; copyright 2010 ParaType Ltd.; Alexandra Korolkova, Olga Umpeleva and Vladimir Yefimov. Exact file matches [this pinned source](https://github.com/tukui-org/ElvUI/blob/9658ff3f7cdb83019aadffad6a4a7549508f7263/ElvUI/Game/Shared/Media/Fonts/PTSansNarrow.ttf). | [SIL OFL 1.1](LICENSES/PTSansNarrow-OFL.txt), also beside the font. Reserved names PT Sans and ParaType; the font remains OFL. SHA-256 `efc8710f9eb3e41405a7efaf9aba701e41dc0e9bcabd3aa0b08f111441fb247d`. |

`TargetCrosshairs.lua`, its numerical circle/arrow artwork and generator are
original contributions. [Provenance](LICENSES/TargetCrosshairs-PROVENANCE.md)
identifies the functional reference without claiming a clean-room process.
The independently generated polygons in `media/native-indicators` have
[source and provenance](asset-source/NATIVE-INDICATORS-PROVENANCE.md).
No historical TNI image library is distributed here. The Horde reticle's own
GPL-2.0 data and media are listed in their section below.

## Camera

`Camera.lua` replaces the DynamicCam addon for this package. It contains
logic ported from DynamicCam (MIT; Michael P. Starkweather and LudiusMaximus,
license text in `LICENSES/DynamicCam-MIT.txt`) alongside original code; the
file header lists which is which. DynamicCam's libraries (LibCamera, LibEasing,
Ace3), options, curve editor and interface-hiding module are not included as
files; the wheel-zoom easing follows LibCamera's procedure, rewritten inside
`Camera.lua`.

## Bundled libraries and references

oUF is separately MIT-licensed by Trond A Ekseth, Val Voronov, Adrian L Lange
and Rainrider; see `libs/oUF/LICENSE.txt`. LibDispel is separately MIT-licensed
by Tukui.org; see `libs/LibDispel/LICENSE.txt`. LibStub is expressly placed in
the public domain by its own source header. Exact preserved source hashes and
the supplying distribution are recorded in `libs/provenance.json` and
`reuse-manifest.json`. The supplying ElvUI distribution does not replace these
individual library licenses. The rewrite uses those libraries directly, without
copying ElvUI or BenikUI frame, tooltip, options or lifecycle implementations.

LibRangeCheck-3.0 (MINOR 39) is separately MIT-licensed, copyright 2023 The
WoWUIDev Community (original author mitch0); see
`libs/LibRangeCheck-3.0/LICENSE`. The library itself is not shipped or loaded;
item identifiers from the range tables of
[upstream commit 3f9e454](https://github.com/WeakAuras/LibRangeCheck-3.0/tree/3f9e454971a011d08fc1b5c73c0a0ad4168c2f44)
are used by `Range.lua` (see "Range item identifiers" below).

LibSerialize v1.2.3 (MINOR 7) is separately MIT-licensed, copyright 2020 Ross
Nichols; see `libs/LibSerialize/LICENSE`. LibDeflate 1.0.2-release is
separately zlib-licensed, copyright 2018-2020 Haoqian He; see
`libs/LibDeflate/LICENSE.txt`. Both are the unmodified source files from
their tagged upstream commits
([LibSerialize aa6e50d](https://github.com/rossnichols/LibSerialize/tree/aa6e50dddad28f8dfa6c27c9b1e15ae40262b4a5),
[LibDeflate 6831edc](https://github.com/SafeteeWoW/LibDeflate/tree/6831edcaa915154e7769d622e0de72ee5d25a882)),
not taken from the ElvUI distribution. Together they write and read the
profile export strings; an imported string is decoded as data and never run.

ElvUI and BenikUI supplied behavioral and settings references. Their custom
engine licenses remain attached to those separate originals; neither engine is
renamed or distributed here.

The fonts the author's original setup used (Expressway, Homizio, Forced Square,
Harry P, Action Man) and the original ElvUI/BenikUI textures are not distributed:
none of those fonts' licenses permits redistribution. The bundled fonts and
textures described below take their place. Blizzard paths
reference installed game resources, including the ready-check icons; no
extracted Blizzard images, fonts, sounds, FrameXML or binaries are bundled.

Plater is a separate nameplate addon with its own authors, license and update
ownership; it is not required or bundled. Squanch-On's own nameplates
(`Nameplates.lua` and the `Nameplate*.lua` files beside it) are original MIT
code on the bundled oUF nameplate driver. Their defaults and rules reproduce
what the author's Plater profile did, and settings can be read once from a
Plater profile; they contain no Plater code or art. DynamicCam is not required
or bundled. ProjectAzilroka, MoveAny, Masque, AddOnSkins,
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

Besides PT Sans Narrow Bold above, the shipped layout's text uses five fonts in
`media/fonts` that are Modified Versions of openly licensed fonts. They are
built by `asset-source/build-fonts.py` from the unmodified upstream files alone:
outlines rescaled and respaced to the heights, advance widths and line metrics
the layout was designed with, hinting removed, renamed. They contain no outline,
hinting, table or name of the differently licensed fonts the author's original
setup used; letter shapes are those of the upstream fonts, so they resemble
that setup without reproducing it. `media/fonts/Squanch-FONTLOG.txt` records
the changes. Hashes are in `reuse-manifest.json`.

| Font | Upstream, copyright and changes | Terms |
| --- | --- | --- |
| Squanch Highway 1.000 | [Red Hat Display](https://github.com/RedHatOfficial/RedHatFont) 1.030 at weight 900; Copyright 2024 The Red Hat Project Authors. [File](https://github.com/google/fonts/tree/main/ofl/redhatdisplay). | SIL OFL 1.1, `media/fonts/SquanchHighway-OFL.txt`. No Reserved Font Name. |
| Squanch Round 1.000 | Red Hat Display 1.030 at weight 700; as above. | SIL OFL 1.1, `media/fonts/SquanchRound-OFL.txt`. No Reserved Font Name. |
| Squanch Square 1.000 | [Orbitron](https://github.com/theleagueof/orbitron) 2.001 at weight 900, with its own alternate I, J, V, W, Y and w; Copyright 2018 The Orbitron Project Authors. [File](https://github.com/google/fonts/tree/main/ofl/orbitron). | SIL OFL 1.1, `media/fonts/SquanchSquare-OFL.txt`. Reserved Font Name "Orbitron", not used. |
| Squanch Bolt 2.000 | [Amarante](https://github.com/google/fonts/tree/main/ofl/amarante) 1.001 Regular, redrawn by the build script as a lightning-bolt face (thickened strokes, generated zigzag bolts and spikes on stems, uneven baseline); Copyright 2012 Sorkin Type Co. | SIL OFL 1.1, `media/fonts/SquanchBolt-OFL.txt`. Reserved Font Name "Amarante", not used. |
| Squanch Comic 1.000 | [Comic Neue](https://github.com/crozynski/comicneue) 2.003 Bold Italic, lowercase drawn as capitals; Copyright 2014 The Comic Neue Project Authors. [File](https://github.com/google/fonts/tree/main/ofl/comicneue). | SIL OFL 1.1, `media/fonts/SquanchComic-OFL.txt`. No Reserved Font Name. |

Overpass Bold, Afacad Medium, Oxanium Bold (static instances cut from the
projects' variable fonts) and Almendra Bold (unmodified), which earlier releases
used in their place, stay bundled and selectable, each beside its license text.

## Unit-frame textures

`media/textures` (glow edge, status-bar face, role marks) are original numerical
constructions produced by `asset-source/generate-frame-media.py`, MIT.

## Selectable media library

The fonts below are offered in the font pickers. Each is the unmodified static
file published by its project (no instancing, subsetting or renaming) and sits
in `media/fonts` beside its own license text. Hashes are in `reuse-manifest.json`.

| Font | Copyright and source | Terms |
| --- | --- | --- |
| Barlow Condensed SemiBold 1.408 | Copyright 2017 The Barlow Project Authors. [Upstream](https://github.com/jpt/barlow); [file](https://raw.githubusercontent.com/google/fonts/main/ofl/barlowcondensed/BarlowCondensed-SemiBold.ttf). | SIL OFL 1.1, `media/fonts/BarlowCondensed-OFL.txt`. No Reserved Font Name. |
| Saira Condensed SemiBold 0.072 | Copyright 2016 The Saira Project Authors. [Upstream](https://github.com/Omnibus-Type/Saira); [file](https://raw.githubusercontent.com/google/fonts/main/ofl/sairacondensed/SairaCondensed-SemiBold.ttf). | SIL OFL 1.1, `media/fonts/SairaCondensed-OFL.txt`. Reserved Font Name "Saira". |
| Archivo Narrow SemiBold 3.002 | Copyright 2019 The Archivo Narrow Project Authors. [Upstream](https://github.com/Omnibus-Type/ArchivoNarrow); [file](https://raw.githubusercontent.com/Omnibus-Type/ArchivoNarrow/master/fonts/ttf/ArchivoNarrow-SemiBold.ttf). | SIL OFL 1.1, `media/fonts/ArchivoNarrow-OFL.txt`. No Reserved Font Name. |
| Oswald Medium 4.103 | Copyright 2016 The Oswald Project Authors. [Upstream](https://github.com/googlefonts/OswaldFont); [file](https://raw.githubusercontent.com/googlefonts/OswaldFont/main/fonts/ttf/Oswald-Medium.ttf). | SIL OFL 1.1, `media/fonts/Oswald-OFL.txt`. No Reserved Font Name. |
| Bebas Neue Regular 2.000 | Copyright 2010 Dharma Type; 2019 The Bebas Neue Project Authors. [Upstream](https://github.com/dharmatype/Bebas-Neue); [file](https://raw.githubusercontent.com/google/fonts/main/ofl/bebasneue/BebasNeue-Regular.ttf). | SIL OFL 1.1, `media/fonts/BebasNeue-OFL.txt`. No Reserved Font Name. |
| Cinzel Bold 2.000 | Copyright 2020 The Cinzel Project Authors. [Upstream](https://github.com/NDISCOVER/Cinzel); [file](https://raw.githubusercontent.com/NDISCOVER/Cinzel/master/fonts/ttf/Cinzel-Bold.ttf). | SIL OFL 1.1, `media/fonts/Cinzel-OFL.txt`. No Reserved Font Name. |
| Metamorphous Regular 1.001 | Copyright 2011-2012 Sorkin Type Co. [Upstream](https://github.com/SorkinType/Metamorphous); [file](https://raw.githubusercontent.com/google/fonts/main/ofl/metamorphous/Metamorphous-Regular.ttf). | SIL OFL 1.1, `media/fonts/Metamorphous-OFL.txt`. Reserved Font Name "Metamorphous". |
| Silkscreen Regular 1.001 | Copyright 2001 The Silkscreen Project Authors. [Upstream](https://github.com/googlefonts/silkscreen); [file](https://raw.githubusercontent.com/google/fonts/main/ofl/silkscreen/Silkscreen-Regular.ttf). | SIL OFL 1.1, `media/fonts/Silkscreen-OFL.txt`. No Reserved Font Name. |
| Pixelify Sans Regular 1.000 | Copyright 2021 The Pixelify Sans Project Authors. [Upstream](https://github.com/eifetx/Pixelify-Sans); [file](https://raw.githubusercontent.com/eifetx/Pixelify-Sans/main/fonts/ttf/PixelifySans-Regular.ttf). | SIL OFL 1.1, `media/fonts/PixelifySans-OFL.txt`. No Reserved Font Name. |
| Share Tech Mono Regular 1.003 | Copyright 2012 Carrois Type Design, Ralph du Carrois. [Upstream](https://github.com/google/fonts/tree/main/ofl/sharetechmono); [file](https://raw.githubusercontent.com/google/fonts/main/ofl/sharetechmono/ShareTechMono-Regular.ttf). | SIL OFL 1.1, `media/fonts/ShareTechMono-OFL.txt`. Reserved Font Name "Share". |

The selectable status-bar faces (`media/textures/bar-*.tga`) and borders
(`media/borders`) are original numerical constructions produced by
`asset-source/generate-frame-media.py`, MIT. The same script produces the
target rings that wear a status bar's look (`media/Crosshairs/ring-*.tga`).
It reads and copies no image. One ring face, `ring-default-*`, is computed from
eight grey levels measured from the client's standard status-bar texture
(`Interface\TargetingFrame\UI-StatusBar`), written as numbers in the script, so
that it matches a bar drawn with that game texture; the other faces come from
the script's own formulas. LibSharedMedia-3.0 is not
bundled; when another addon has loaded it, Squanch-On registers these fonts and
textures with it and lists what it offers.

## Range item identifiers

`Range.lua` contains item identifiers taken from the range tables of
LibRangeCheck-3.0 (MIT, The WoWUIDev Community), whose license text is kept in
`libs/LibRangeCheck-3.0/LICENSE`.
