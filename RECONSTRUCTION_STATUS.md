# Reconstruction status

A resume map for a task that spans many sessions. It records what is done, what is next with
addresses and sizes, and the method that produced the tree, so a session can start work instead of
re-deriving where it left off.

Addresses are relative to the image base `0x100000000`, matching the `@ghidraAddress` tags.

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

## Next, in order

`JubeatAppDelegate` is finished, so the chase now runs outwards from what its bodies reach. In
rough order of how much each unlocks:

| Target | Address | Notes |
| --- | --- | --- |
| `+[ScratchUtil pushNotificationResponseURL]` | 0x180524 | Straight-line and small; will expose the server host the whole application talks to. |
| `-[LogoViewController start]` | not located yet | The launch sequence continues here; class at 0x348a58. |
| `Downloader` | class at 0x348250 | `-startDownloading` has 98 xrefs, so essentially every server call routes through it. |
| `-[RootViewController fade:durationIn:durationOut:]` | not located yet | The last RootViewController member still declared without a body. |
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
| `RootViewController` | 0x348 (via 0x340430) | — | 3 |
| `ChallengeStatus` | 0x348150 | 116 | 1 |
| `PurchaseManager` | 0x348100 | 81 | 1 |
| `ScoreRecordManager` | 0x3480e0 | 12 | 1 |
| `KnitColorManager` | 0x3480a0 | 7 | 2 |
| `EditorIDManager` | 0x348060 | 126 | 3 |
| `Md5Utilities` (free function) | — | — | 1 |

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
