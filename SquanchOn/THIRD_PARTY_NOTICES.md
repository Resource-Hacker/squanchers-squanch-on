# Third-party notices and provenance

The root MIT license applies to original Squanch-On contributions. It does not
replace the following component licenses or grant rights to game artwork.
Complete notices travel with both the source repository and installable addon.

| Component | Included version and scope | Author / origin | Terms and notice |
| --- | --- | --- | --- |
| oUF | `devel`, exact Forever fork distributed in ElvUI Libraries `v16.01-g9658ff3`; 51 files under `libs/oUF` | Trond A Ekseth, Val Voronov, Adrian L Lange, Rainrider and contributors; [oUF](https://github.com/oUF-wow/oUF), inherited [ElvUI library fork](https://github.com/tukui-org/ElvUI/tree/main/ElvUI_Libraries/Game/Shared/oUF) | [MIT notice](libs/oUF/LICENSE.txt); inherited fork changes retained unchanged |
| LibDispel-1.0 | Minor 33; `libs/LibDispel` | Copyright 2026 Tukui.org; [ElvUI Libraries](https://github.com/tukui-org/ElvUI/tree/main/ElvUI_Libraries) | [MIT notice](libs/LibDispel/LICENSE.txt); unchanged |
| LibStub | Minor 2, SVN source id 103; `libs/LibStub` | Kaelten, Cladhaire, ckknight, Mikk, Ammo, Nevcairiel, joshborke; [LibStub](https://www.wowace.com/projects/libstub) | Explicit public-domain declaration and credits retained in [source header](libs/LibStub/LibStub.lua); unchanged |
| TargetNameplateIndicator code | Compatibility behavior originally ported from v1.67; current `NameplateIndicators.lua` and related adapter | Copyright 2013–2016 Choonster; [upstream](https://github.com/Choonster-WoW-AddOns/TargetNameplateIndicator) | [Full MIT code notice](LICENSES/TargetNameplateIndicator-LICENSE.txt). Ported to the host namespace, native event lifecycle, standalone configuration and new semantic artwork mapping. Former image library is excluded. |
| PT Sans Narrow Bold | Version 2.003, unmodified `ptsansnarrow_bold.ttf` | Copyright 2010 ParaType Ltd.; designers Alexandra Korolkova, Olga Umpeleva, Vladimir Yefimov; [Google Fonts distribution](https://github.com/google/fonts/tree/main/ofl/ptsansnarrow) | [SIL Open Font License 1.1](LICENSES/PTSansNarrow-OFL.txt), reserved names “PT Sans” and “ParaType”; also included beside the font |

The vendor [provenance manifest](libs/provenance.json) records exact
file hashes and the source distribution. These are the tested local fork bytes,
not a claim that they equal the latest oUF upstream checkout. Each included library
has its own distribution notice; no blanket license is inferred for neighboring
ElvUI files. Original upstream copyright and disclaimer text is preserved.

## Original artwork and compatibility references

`TargetCrosshairs.lua`, its circles/arrows and their source generator are original
MIT work. [Provenance](LICENSES/TargetCrosshairs-PROVENANCE.md) describes the
functional reference and independent numerical construction; this is not a claim
of a clean-room process. The dashed ring is generated from source as well.
`media/native-indicators` contains three independently generated polygons with
[source and provenance](asset-source/NATIVE-INDICATORS-PROVENANCE.md).
Neither set traces or incorporates pixels from the replaced image libraries.

Nameplate-indicator code and its historical image library have different rights.
The retained Choonster notice explicitly separates them. No historical TNI images,
PowerAuras textures, exported aura scripts or throwknife audio are distributed.
The previous Expressway, Homizio, Forced Square and Harry P font files are absent.

ElvUI, BenikUI, ProjectAzilroka, MoveAny, Masque, AddOnSkins, Bagnon and Semlar's
Crosshairs supplied functional or settings references for compatibility work.
Their restricted addon implementations, options engines and images are not
repackaged here. The independently licensed library subtrees listed above are the
specific exceptions; they remain identified and attributed as upstream work.
GSE, Pawn, BugSack and BugGrabber code is not included.

## Game resources and optional integrations

Blizzard resource paths and atlas identifiers refer to assets already installed
with World of Warcraft. No extracted Blizzard images, fonts, sounds, FrameXML or
game binaries are included. Blizzard Entertainment retains its rights in those
resources and trademarks.

Plater and DynamicCam are optional external addons with their own licensing and
update ownership. Squanch-On's original adapters call their installed interfaces;
the repository does not include or relicense those addons. Optional libraries
already provided by other addons are not silently bundled.

The names above acknowledge their respective authors. They do not imply
sponsorship, endorsement, ownership transfer or permission beyond the included
component licenses.
