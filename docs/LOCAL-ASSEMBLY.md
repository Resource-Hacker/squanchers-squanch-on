# Installation

Squanch-On is one addon folder. It includes its libraries (oUF, LibDispel,
LibRangeCheck-3.0, LibSerialize, LibDeflate, LibStub), the Horde reticle, fonts
and textures. No other addon and no build or
assembly step is required.

1. Close the game. Back up `Interface/AddOns` and `WTF` if you want a way back.
2. Copy the `SquanchOn/` folder into `Interface/AddOns`, so that
   `Interface/AddOns/SquanchOn/SquanchOn.toc` exists.
3. Disable other addons that own unit frames, tooltips, bags or the buff and
   debuff rows.
4. Log in.

With no saved settings, the first run starts from the author's layout. Its
positions were authored on a 5120x1440 display; on other resolutions, use
`/sqedit` to move and resize things. An existing `SquanchOnDB` is kept: at first
login it is migrated into a profile, and a backup of the earlier settings stays
in the saved file. `/squanchon` opens the settings window.

## Other addons

No other addon is required.

- **Nameplates.** Squanch-On does not ship nameplates yet; a native nameplate
  module is planned. The author uses **Plater**. It is not required, and the
  range cues no longer depend on it: LibRangeCheck-3.0 is bundled. With Plater
  loaded, the friendly target ring hugs its nameplate icon.
- **DynamicCam.** Squanch-On has its own camera, which stays inactive while
  DynamicCam is loaded. `/sqms camera takeover` imports the DynamicCam profile
  in use and disables DynamicCam; `/sqms camera release` hands the camera back.
- **LibSharedMedia.** Not bundled and not needed. If another addon has loaded
  it, Squanch-On registers its fonts and textures there.

## From a source checkout

`python3 tools/package.py` checks the addon and writes
`dist/SquanchOn-0.3.0-rewrite.zip` with a SHA-256 checksum; see
[contributing](../CONTRIBUTING.md). Copying the `SquanchOn/` folder directly
works as well.

## Status

Checked live only solo on the Forever client (interface 16001) by the author.
See [compatibility](COMPATIBILITY.md#verification-status) for what has not been
verified.
