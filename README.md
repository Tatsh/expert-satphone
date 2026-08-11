# jubeat plus source reconstruction

<!-- WISWA-GENERATED-README:START -->

[![GitHub tag (with filter)](https://img.shields.io/github/v/tag/Tatsh/expert-satphone)](https://github.com/Tatsh/expert-satphone/tags)
[![License](https://img.shields.io/github/license/Tatsh/expert-satphone)](https://github.com/Tatsh/expert-satphone/blob/master/LICENSE.txt)
[![GitHub commits since latest release (by SemVer including pre-releases)](https://img.shields.io/github/commits-since/Tatsh/expert-satphone/v3.9.11/master)](https://github.com/Tatsh/expert-satphone/compare/v3.9.11...master)
[![Dependabot](https://img.shields.io/badge/Dependabot-enabled-blue?logo=dependabot)](https://github.com/dependabot)
[![pages-build-deployment](https://github.com/Tatsh/expert-satphone/actions/workflows/pages/pages-build-deployment/badge.svg)](https://tatsh.github.io/expert-satphone/)
[![Stargazers](https://img.shields.io/github/stars/Tatsh/expert-satphone?logo=github&style=flat)](https://github.com/Tatsh/expert-satphone/stargazers)
[![pre-commit.ci status](https://results.pre-commit.ci/badge/github/Tatsh/expert-satphone/master.svg)](https://results.pre-commit.ci/latest/github/Tatsh/expert-satphone/master)
[![Prettier](https://img.shields.io/badge/Prettier-black?logo=prettier)](https://prettier.io/)

[![@Tatsh](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fpublic.api.bsky.app%2Fxrpc%2Fapp.bsky.actor.getProfile%2F%3Factor=did%3Aplc%3Auq42idtvuccnmtl57nsucz72&query=%24.followersCount&label=Follow+%40Tatsh&logo=bluesky&style=social)](https://bsky.app/profile/Tatsh.bsky.social)
[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-Tatsh-black?logo=buymeacoffee)](https://buymeacoffee.com/Tatsh)
[![Libera.Chat](https://img.shields.io/badge/Libera.Chat-Tatsh-black?logo=liberadotchat)](irc://irc.libera.chat/Tatsh)
[![Mastodon Follow](https://img.shields.io/mastodon/follow/109370961877277568?domain=hostux.social&style=social)](https://hostux.social/@Tatsh)
[![Patreon](https://img.shields.io/badge/Patreon-Tatsh2-F96854?logo=patreon)](https://www.patreon.com/Tatsh2)

<!-- WISWA-GENERATED-README:STOP -->

A source-level reconstruction of the iOS game _jubeat plus_, recovered from its shipped arm64
Mach-O binary with Ghidra.

## Scope

Reconstruction proceeds outwards from the entry point: `main` calls `UIApplicationMain` with the
delegate class `JubeatAppDelegate`, and every routine reachable from there is recovered in turn.

## Layout

| Path        | Contents                                                        |
| ----------- | --------------------------------------------------------------- |
| `Project/`  | Reconstructed sources, one class per header and implementation. |
| `.claude/`  | Rules governing reconstruction fidelity and coding style.       |
| `STATUS.md` | The routines still to reconstruct.                              |

Nearly the whole binary is reconstructed and audited. What remains is a fixed, shrinking work list
in [STATUS.md](STATUS.md): the outstanding Objective-C methods and C/C++ functions and blocks, each
row a routine in `-[ClassName selector]` (or function) form with its Ghidra address, cross-reference
count, and byte length. A routine drops off the list once its source lands. Regenerate the file with
`tools/status_tables_gen.py` after landing new work.

## Provenance

Every reconstructed routine carries a `@ghidraAddress` Doxygen tag giving its address in the
original binary, relative to the image base `0x100000000`. The tag is what makes a claim in this
tree checkable against the binary, so it is required rather than decorative.
