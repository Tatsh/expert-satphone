# Reconstruction status

A resume map for a task that spans many sessions. It records what is done, what is next with
addresses and sizes, and the method that produced the tree, so a session can start work instead of
re-deriving where it left off.

Addresses are relative to the image base `0x100000000`, matching the `@ghidraAddress` tags.

**Run the external check before believing any of this.** From the `recon-tools` checkout:

```sh
uv run rctool -W /path/to/jubeat-src audit addresses /path/to/Jubeat.app/Jubeat
```

It must report a non-zero `annotated` count. A `0 annotated` line reads like a pass and is not one;
see the *Verification* section of [TYPES_PENDING.md](TYPES_PENDING.md) for what that means and for
which of the four subcommands actually cover anything here. Last run: **80 annotated, 0
mismatched, 0 selectors absent.**

## Method

Applied to every routine, in this order, without exception:

1. Decompile to get oriented.
2. **Disassemble the whole routine.** Never a partial read; never write from a decompile.
3. Resolve every selector, class, and constant from its pointer address — never from a decompiler
   label and never by guessing a plausible name.
4. Write the reconstruction, flagging surprising-but-faithful behaviour at the line.
5. Record anything unproven in `TYPES_PENDING.md` rather than guessing it.

Six routines were deferred mid-reconstruction because a read was partial, a decompile was
unverified, or a question was unresolved. **All six, when finally read in full, contained something
the partial view had missed or reversed** — that is the evidence for step 2, not a principle:

| Routine | What the partial view would have got wrong |
| --- | --- |
| `-loginGameCenter` | the block's two arms reach the same object by different routes |
| `-enableCopiousMarkers` | the tail holds `synchronize` and `-reloadMarkers` |
| `-saveNotification` | archive built before the emptiness test; property fetched twice |
| `-musicListKey` | keychain-backed; `cbz` on an `OSStatus` inverts the arms |
| `-application:handleOpenURL:` | two of four routes are dead code |
| `-refreshUserAgent` | decompile transposed two format arguments and dropped one |
| `-application:didReceiveLocalNotification:` | a discarded `timeIntervalSince1970`, and the scheme reads that prove `handleOpenURL:`'s bug |
| `-application:didFinishLaunchingWithOptions:` | the decompile mis-rendered the whole device classifier; `d8` holds the scale, then the height |

## Done

| Artifact | State |
| --- | --- |
| `Project/main.m` | Complete. |
| `Project/JubeatAppDelegate.h` | 36 properties, all accessors from both blocks. |
| `Project/JubeatAppDelegate.m` | **Complete.** 62 methods, every one reached. |
| `Project/Md5Utilities.m` | Complete; a free function. |
| `Project/LabUtilities.m` | Complete; a free function. Reaches `BFCodec`. |
| `Project/ScratchUtil.m` | One of two known members. The API host is `agx11.s.konaminet.jp`. |
| `Project/RootViewController.m` | Ten methods, including both transition dispatchers and the theme factory. |

## Next, in order

`JubeatAppDelegate` is finished, so the chase now runs outwards from what its bodies reach. In
rough order of how much each unlocks:

| Target | Address | Notes |
| --- | --- | --- |
| `-[LogoViewController start]` | not located yet | The launch sequence continues here; class at 0x348a58. |
| `-[RootViewController openStoreAnimStop:...]`, `-endStoreAnimStop:...` | 0x1a81b4, 0x1a8d7c | Two more animation callbacks in the class, not yet reached by anything reconstructed. |
| `AudioManager` | class at 0x348038 | 357 xrefs, the most of any class reached. Every sound goes through it. |
| `MusicSelectViewController`, `TitleViewControllerOrg`, `TitleViewControllerRpl` | 0x348a68, 0x348a78, 0x348a70 | The three screens the dispatcher builds. |
| `ImageCache` | class at 0x348468 | 132 xrefs. |
| `Downloader` | class at 0x348250 | `-startDownloading` has 98 xrefs, so essentially every server call routes through it. |
| `PurchaseManager` | class at 0x348100 | Four launch-time entry points plus `-end`. 81 xrefs, so this is the largest unstarted class. |
| `MarkerManager`, `TweetResourceManager`, `StoreMusicListManager` | 0x3480d0, 0x3480d8, 0x348108 | Declared-only stubs; each has two or three known members. |

The pattern that has held for every method so far still applies: read the whole routine's
disassembly before writing any of it, and resolve every constant from memory rather than from the
decompile's rendering of it.

### Classes reached, no bodies yet

Each was created because a reconstructed caller sends to it. Members declared so far are listed in
`TYPES_PENDING.md` under *Declared without a body*.

| Class | Class object | Xrefs | Members declared |
| --- | --- | --- | --- |
| `RootViewController` | via 0x340430 | — | **7 implemented**, 3 declared |
| `ChallengeStatus` | 0x348150 | 116 | 1 |
| `PurchaseManager` | 0x348100 | 81 | 1 |
| `ScoreRecordManager` | 0x3480e0 | 12 | 1 |
| `KnitColorManager` | 0x3480a0 | 7 | 2 |
| `EditorIDManager` | 0x348060 | 126 | 3 |
| `Md5Utilities` (free function) | — | — | **implemented** |
| `AudioManager` | 0x348038 | 357 | 3 |
| `Downloader` | 0x348250 | — | 2 |
| `ImageCache` | 0x348468 | 132 | 2 |
| `BFCodec` | 0x3481d8 | 189 (`-cipherInit:`) | 2 |
| `MusicSelectViewController` | 0x348a68 | — | 4 |
| `TitleViewControllerOrg` / `Rpl` | 0x348a78 / 0x348a70 | — | 2 each |
| `LogoViewController` | 0x348a58 | — | 1 |
| `MarkerManager` / `TweetResourceManager` / `StoreMusicListManager` | 0x3480d0 / 0x3480d8 / 0x348108 | — | 2 / 3 / 2 |
| `ScratchUtil` | 0x3482a0 | — | **implemented** |
| `CJSONSerializer` (3rdparty) | 0x348248 | — | 2 |

`ScoreRecordManager` is the cheapest to finish at 12 cross-references; `EditorIDManager` and
`ChallengeStatus` are the largest at 126 and 116.

## Scale

The binary has 12,388 functions. The recursive closure from `main` covers a large share of them, and
this tree deliberately trades speed for the fidelity described above. Completion is many sessions
away and the count of reconstructed methods is not the measure of progress — every line carrying a
verifiable address is.

## What the trackers have caught

`TYPES_PENDING.md` is not bookkeeping for its own sake. It has caught five types that were declared
from an accessor's load width and later corrected by reading a method body, and it holds one defect
found in the shipped binary that a later reader might otherwise "fix" into disagreeing with it.
