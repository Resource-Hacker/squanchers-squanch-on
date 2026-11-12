# Installation

Squanch-On is one addon folder. It includes its libraries (oUF, LibDispel,
LibStub), the Horde reticle, fonts and textures. No other addon and no build or
assembly step is required.

1. Close the game. Back up `Interface/AddOns` and `WTF` if you want a way back.
2. Copy the `SquanchOn/` folder into `Interface/AddOns`, so that
   `Interface/AddOns/SquanchOn/SquanchOn.toc` exists.
3. Disable other addons that own unit frames, tooltips or the buff and debuff
   rows.
4. Log in.

With no saved settings, the first run starts from the author's layout. Its
positions were authored on a 5120x1440 display; on other resolutions, use
`/sqedit` to move and resize things. An existing `SquanchOnDB` is kept.

## Optional integrations

- **Plater** keeps nameplate behavior and normally supplies LibRangeCheck-3.0
  for the melee and proximity range cues. Without it those cues stay hidden.
- **DynamicCam** can own camera framing (`/sqms camera`).

Both are installed separately and are not required.

## From a source checkout

`python3 tools/package.py` checks the addon and writes
`dist/SquanchOn-0.3.0-rewrite.zip` with a SHA-256 checksum; see
[contributing](../CONTRIBUTING.md). Copying the `SquanchOn/` folder directly
works as well.

## Status

Checked live only solo, out of combat, on the Forever client (interface 16001),
with self-target. See [compatibility](COMPATIBILITY.md) for what has not been
verified.
