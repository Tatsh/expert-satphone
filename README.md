# jubeat plus source reconstruction

A source-level reconstruction of the iOS game *jubeat plus*, recovered from its shipped arm64
Mach-O binary with Ghidra.

## Scope

Reconstruction proceeds outwards from the entry point: `main` calls `UIApplicationMain` with the
delegate class `JubeatAppDelegate`, and every routine reachable from there is recovered in turn.

## Layout

| Path         | Contents                                                        |
| ------------ | --------------------------------------------------------------- |
| `Project/`   | Reconstructed sources, one class per header and implementation.  |
| `.claude/`   | Rules governing reconstruction fidelity and coding style.        |

## Provenance

Every reconstructed routine carries a `@ghidraAddress` Doxygen tag giving its address in the
original binary, relative to the image base `0x100000000`. The tag is what makes a claim in this
tree checkable against the binary, so it is required rather than decorative.

The binary embeds the same Konami "applilink" advertising SDK as *REFLEC BEAT plus*, whose
reconstruction lives in the sibling `rbplus-src` tree.
