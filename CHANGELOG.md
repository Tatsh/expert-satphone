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

- Low-resolution app icon on installation. `CFBundleIconFiles` listed only the 29x29 `icon.png`
  variants, so iOS upscaled a 29px image into the iPad home-screen slot. The correctly sized icons
  already shipped in the bundle are now referenced, and per-idiom `CFBundleIcons` and
  `CFBundleIcons~ipad` dictionaries give iPad its own icon list.

## [0.0.1] - 2026-00-00

First version.

[unreleased]: https://github.com/Tatsh/expert-satphone/compare/v3.9.11...HEAD
[0.0.1]: https://github.com/Tatsh/expert-satphone/releases/tag/v3.9.11
