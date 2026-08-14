<!-- markdownlint-configure-file {"MD024": { "siblings_only": true } } -->

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.1/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [unreleased]

### Added

- Animated ripple background on the title screen's ripples (Rpl) theme.
  `-[TitleViewControllerRpl addRippleLayers]` was a stub, so only the static sky and reflection
  gradients were drawn; it now builds the forty drifting ripple sprites and their dimmed mirrored
  copies below the horizon.

### Fixed

- Decryption of the bundled encrypted assets. Four of the eight bytes of `kFixedChainVector`, the
  fixed chaining vector `BFCodec` uses for every Blowfish payload, were transposed: the middle four
  are written by one little-endian word store, which the reconstruction had transcribed in
  big-endian reading order. Only the first eight bytes of each payload were affected, and anything
  the app enciphered itself round-tripped through the same wrong vector, so the damage was confined
  to ciphertext shipped in the bundle. The default marker list in `DefaultSettings.plist` failed to
  unarchive, leaving no markers and crashing the app with an `NSRangeException` on the music select
  screen; encrypted `.tex` textures and the other bundled preference blobs were corrupted the same
  way.
- Low-resolution app icon on installation. `CFBundleIconFiles` listed only the 29x29 `icon.png`
  variants, so iOS upscaled a 29px image into the iPad home-screen slot. The correctly sized icons
  already shipped in the bundle are now referenced, and per-idiom `CFBundleIcons` and
  `CFBundleIcons~ipad` dictionaries give iPad its own icon list.

### Removed

- `tools/repack_ipa.py`. Nothing in it was specific to this project, so it now lives in
  [recon-tools](https://github.com/Tatsh/recon-tools) as `rctool ipa repack --overlay`, which reads
  the repository from this working tree's GitHub remote and derives the entries the fresh build
  owns from its own `Info.plist` rather than hard-coding them:

  <!-- prettier-ignore -->
  ```shell
  rctool ipa repack --overlay -a Jubeat-adhoc-ipa <resources-dir> Jubeat-signed.ipa
  ```

## [0.0.1] - 2026-00-00

First version.

[unreleased]: https://github.com/Tatsh/expert-satphone/compare/v3.9.11...HEAD
[0.0.1]: https://github.com/Tatsh/expert-satphone/releases/tag/v3.9.11
