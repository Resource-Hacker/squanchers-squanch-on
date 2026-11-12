# Changelog

## 0.3.0-rewrite — unreleased, staged

- Independently implement unit-frame layout and presentation inside Squanch-On,
  directly using separately MIT-licensed oUF/LibDispel and public-domain LibStub.
  Remove external ElvUI/BenikUI engine requirements and the five-folder assembly.
- Preserve complete resolved local settings as data, including unsupported fields,
  while the new options editor exposes only declared renderer capabilities.
  Full native ElvUI options and all-class/filter parity are not claimed.
- Add independently written tooltip presentation and anchor handling; retain
  Blizzard's content, item comparisons, native health values and event handlers.
- Keep exact local media and optional original reticle code/assets in a separate
  private overlay with source notices and hashes. The public addon is complete
  with its bundled/game media defaults; exact original appearance may need assets
  excluded from that release.
- Validate public Lua/load/reuse integrity and private assembly. Fresh game loading,
  visual equivalence, settings interaction and combat/group acceptance remain
  pending. Existing gameplay images retain their earlier component provenance.

## 0.2.0-candidate — original-engine baseline

The accepted local baseline remains on this version while 0.3 is evaluated.

- Replace the rejected alpha unit-frame rewrite with the original scoped ElvUI
  renderer, complete native editor, profiles/movers and Benik decoration.
- Restore original tooltip borders, exact font paths, native layout adapters,
  options-menu cursor handling and target marker fade ownership.
- Remove the duplicate oUF/library tree and partial unit-frame editor.
- Add an offline private local assembler with original identities, load checks,
  per-file hashes and explicit redistribution boundaries.
- Preserve existing native frame databases and the suite's current reticle/camera
  behavior. Those original-engine checks do not certify the later independent rewrite.


- Restore a visible gold leading border on General and other exposed chat tabs.
- Strengthen the continuous line beneath the tabs to three physical pixels.
  Both changes were visually checked after reload in the existing Forever setup.
- Match minimap menu-icon backgrounds to the shared translucent panel fill,
  preserving native hover and pressed feedback. Fit their lower edge to the bag
  row's painted border so the differently scaled rows meet without a bright gap.

## 0.1.0-alpha — 2026-11-10

First packaged public developer alpha for Forever interface 16001.

- Reticle-centered native mouselook with a hold-right-to-open real mouseover gate,
  native mouseover casting setup and hardware-cursor release/return.
- Horde reticle feedback and a separate dashed selected-target ring with click
  pulse, conservative melee blocks and learned ranged/healing spell triangles.
- Standalone oUF unit frames and original settings controls; native bags, bars,
  chat, minimap and windows share the dark/gold theme.
- Centered `/sqedit` alignment grid, supported frame resizing and session undo.
- Explicit third-party licenses, source provenance and hash manifests.
- Gameplay example images, a reticle control guide, compatibility notes, checked
  installation ZIP and SHA-256 checksum.

This release packages the new consolidation for evaluation. Full standalone UI,
combat, cross-class and platform acceptance remains in progress.
