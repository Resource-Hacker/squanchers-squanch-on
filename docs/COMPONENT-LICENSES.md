# Component licenses and local assembly

Squancher's Squanch-On publishes original integration code under MIT, with the
separately licensed material identified in [third-party notices](../THIRD_PARTY_NOTICES.md).
The original frame engines remain external dependencies. MIT does not replace
their licenses or grant rights to their fonts, textures, libraries or names.

## Public package and private local output

The public addon package contains `SquanchOn`. A user-run assembler combines it
locally with the user's originals, preserving five sibling addon folders:

```
SquanchOn/
ElvUI/
ElvUI_Libraries/
ElvUI_Options/
ElvUI_BenikUI/
```

That assembled installation is private output, not a redistributable SquanchOn
release. Do not upload its imported source, restricted media, saved settings or
private package to the repository or releases. Optional Plater/DynamicCam
installations remain separate. One product or archive name does not change the
contained addons' names, authorship or licenses.

## Original component sources and terms

| Component and author | Identified source | License boundary |
| --- | --- | --- |
| ElvUI; ElvUI authors and contributors, copyright 2009–2026 | v16.01-derived source, commit [`9658ff3f7cdb83019aadffad6a4a7549508f7263`](https://github.com/tukui-org/ElvUI/commit/9658ff3f7cdb83019aadffad6a4a7549508f7263). [Project](https://github.com/tukui-org/ElvUI). | [Custom license](https://github.com/tukui-org/ElvUI/blob/9658ff3f7cdb83019aadffad6a4a7549508f7263/ElvUI/LICENSE.txt): private modifications, explicit GitHub upload exception, unchanged addon/folder name and retained notice. Third-party resources excluded. Original-named ElvUI-owned code can be distributed on GitHub under those conditions; it cannot be renamed into an MIT SquanchOn engine. |
| ElvUI_Options; ElvUI authors and contributors | Same source commit, original folder `ElvUI_Options`. | Its [custom license](https://github.com/tukui-org/ElvUI/blob/9658ff3f7cdb83019aadffad6a4a7549508f7263/ElvUI_Options/LICENSE.txt) has the corresponding GitHub exception, name and notice requirements. |
| ElvUI_Libraries; respective library authors | Same source commit plus the external libraries required by packaging metadata. | The [root license](https://github.com/tukui-org/ElvUI/blob/9658ff3f7cdb83019aadffad6a4a7549508f7263/LICENSE.md) delegates to [individual notices](https://github.com/tukui-org/ElvUI/blob/9658ff3f7cdb83019aadffad6a4a7549508f7263/ThirdPartyNotices.md), including MIT, public-domain, Ace3 and LGPL terms and scopes without an established redistribution grant. No blanket MIT license or blanket ElvUI GitHub exception applies to the whole folder. |
| BenikUI; Benik, copyright 2014–2026 | v5.20, commit [`c221e0ae63d5dcb9469b4feba9e51f939a5993d0`](https://github.com/Benik/BenikUI/commit/c221e0ae63d5dcb9469b4feba9e51f939a5993d0). [Author project](https://github.com/Benik/BenikUI), [official distribution](https://www.curseforge.com/wow/addons/benikui). | [Custom license](https://github.com/Benik/BenikUI/blob/c221e0ae63d5dcb9469b4feba9e51f939a5993d0/ElvUI_BenikUI/LICENSE.txt): private modifications, preserved addon/folder name and retained notice; public upload exception only to tukui.org after permission. No GitHub redistribution grant. |

Calling original engine interfaces and applying original external styling does
not transfer their copyright to SquanchOn. Imported components retain their
notices. The public integration excludes their implementations; this is a
packaging decision, not a claim that every upstream project forbids every reuse.

The pinned [ElvUI source archive](https://codeload.github.com/tukui-org/ElvUI/zip/9658ff3f7cdb83019aadffad6a4a7549508f7263)
and [Benik source archive](https://codeload.github.com/Benik/BenikUI/zip/c221e0ae63d5dcb9469b4feba9e51f939a5993d0)
identify author-hosted source. ElvUI's ZIP alone does not reproduce a complete
installed triplet: its [.pkgmeta](https://github.com/tukui-org/ElvUI/blob/9658ff3f7cdb83019aadffad6a4a7549508f7263/.pkgmeta)
declares external dependencies. Source archives also omit a user's custom
loaders, local integration files and exact settings. Importing a complete known
installation preserves that closure; fetching the latest dependencies does not
prove equivalent bytes or behavior. Local acquisition does not grant republication.

## Exact media and fonts

The public PT Sans Narrow Bold file retains its full ParaType copyright and SIL
OFL 1.1 notice. The exact file is identified in the notices; a different font
catalog revision must not silently replace it.

Other original fonts and textures required for a user's appearance are local
imports with their own provenance. An addon author's license does not
automatically license third-party fonts found beside its code. The installed
Expressway file identifies the Bold face and prohibits distribution; today's free
desktop Regular file is different. [Typodermic's guidance](https://typodermicfonts.com/desktop/)
also separates desktop design from app/game embedding rights. Homizio, Prototype,
DOCK11, Homespun, Action Man, Forced Square and Harry P are not MIT assets merely
because an addon can reference them. Preserve exact locally supplied files; report
missing assets instead of substituting a different face.

Native Blizzard font paths, textures and atlases reference resources already
installed with the game. No extracted Blizzard assets are published here.
Original/generated public artwork and the MIT TargetNameplateIndicator code port
have separate notices; its historical images are not covered by the code's grant.

Upstream names identify their respective authors. They imply no endorsement,
sponsorship or permission beyond the applicable terms.
