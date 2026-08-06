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
which of the four subcommands actually cover anything here. Last run: **170 annotated, 0
mismatched, 0 selectors absent; 34 constants checked against their bytes.**

## Measured progress

Do not estimate this; measure it. `tools/progress.py` counts every method the runtime metadata
declares, minus the ones no human wrote, against the bodies in this tree:

```sh
cd ../recon-tools && uv run python ../jubeat-src/tools/progress.py \
    ../Jubeat.app/Jubeat ../jubeat-src [ClassName]
```

Excluded as never-hand-written: `.cxx_destruct`, which ARC emits to release strong ivars, and
property accessors — but **only the synthesised ones**. A class can implement an accessor by hand,
and then the whole routine is real work that a name-only test cannot see. The tool separates the two
by body size, using the same threshold as `rctool objc property-accessors`. Excluding accessors
wholesale hid 24 methods and wrongly reported `ScoreRecordManager` as finished.

**As of the last run: 165 of 5036 methods, 3.3%. 52 of 317 classes complete.**

That is the honest denominator for "every class implemented" and it is worth stating plainly: the
binary defines 317 classes and just over five thousand hand-written methods. The largest single
class reached so far, `ChallengeStatus`, has 101 of them on its own. Pass a class name to the tool
to get that class's outstanding selectors with addresses, which is the fastest way to pick the next
unit of work.

**Read a jump table's bytes; do not infer cases from the branch structure.** `-[BalloonView
contentRect]`'s four arms looked like two, because cases 1 and 3 enter the *middle* of the blocks
cases 0 and 2 begin — ordinary tail sharing. Reading the branch layout alone gave "the down and
right arrows are not accounted for", which would have been recorded as a defect in the shipped
binary. The table at 0x1ba5dc says otherwise and all four directions are handled correctly.

**Ghidra prints a negative `fmov` immediate wrongly.** It shows neither the value nor its bit
pattern — `-0x3fd8000000000000` for -12.0, `-0x4010000000000000` for -1.0. Decode `imm8` from the
instruction encoding instead: bits 20:13, expanded as sign, `NOT(bit6)`, `bit6`×8, bits 5:4, then
bits 3:0 as the mantissa's top nibble. This has already produced two wrong constants when trusted.

A superclass is **not** in the file. The class object's superclass slot is a dyld bind target and
reads as zero on disk, so it has to come from the binding. `get_xrefs_from` on the slot address in
Ghidra resolves it — that is how `DetailTextView` and `UnselectableTextView` were shown to derive
from `UITextView`, and `PagingScrollView` from `UIScrollView`, rather than being guessed from the
class name.

The applilink SDK is shared with the sibling binary, so `../rbplus-src` already reconstructs several
of these classes. Comparing against it is worthwhile in both directions: it corroborated
`+[ApplilinkBundle rewardBundle]` line for line, and it exposed a genuine difference — that build
ends the method with an `NSLog` on failure, and this one does not. `+[ApplilinkMessage
localizedMessage:]` is a larger divergence still: the sibling recognises two message keys, this
build recognises six and guards the bundle against nil. This binary carries the later SDK revision,
so a disagreement with the template is evidence about versions, not a reason to doubt either
reading.

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
| `Project/JubeatAppDelegate.m` | **Complete**, confirmed by `tools/progress.py`: 0 outstanding. 63 methods. |
| `Project/Md5Utilities.m` | Complete; a free function. |
| `Project/LabUtilities.m` | Complete; a free function. Reaches `BFCodec`. |
| `Project/ScratchUtil.m` | One of two known members. The API host is `agx11.s.konaminet.jp`. |
| `Project/ScoreRecordManager.m` | **Complete**, and this time verified with `objc property-accessors` too. The whole Core Data stack. |
| `Project/DetailTextView.m` | **Complete.** One method. |
| `Project/UnselectableTextView.m` | **Complete.** One method. |
| `Project/PagingScrollView.m` | **Complete.** One method. |
| `Project/GenrePagingScrollView.m` | **Complete.** One method, identical to the above. |
| `Project/UnselectableTextViewV2.m` | **Complete.** One method. |
| `Project/InfoLabel.m` | **Complete.** One method. |
| `Project/SessionClass.m` | **Complete.** Initialiser plus 13 properties from metadata. |
| `Project/NoMenuTextView.m` | **Complete.** Two methods. |
| `Project/MarkerDownloadTask.m` | **Complete.** One method. |
| `Project/StoreDownloadTask.m` | **Complete.** One method, identical to the above. |
| `Project/ApplilinkBundle.m` | **Complete.** One method. Cross-checked against ../rbplus-src. |
| `Project/ApplilinkMessage.m` | **Complete.** One method. Six keys here against the sibling's two. |
| `Project/MusicListScroll.m` | **Complete.** Two methods. |
| `Project/StoreDetailCopyrightCell.m` | **Complete.** One method. |
| `Project/StoreManageTableViewCell.m` | **Complete.** One method. |
| `Project/CustomSequencePageNavViewController.m` | **Complete.** One method. |
| `Project/ChallengeMissionReward.m` | **Complete.** Two methods; documents the reward wire format. |
| `Project/ChallengeMissionTerms.m` | **Complete.** Two methods; documents the mission wire format. |
| `Project/StoreMusicInfo.m` | **Complete.** Two methods; documents the store's track wire format. |
| `Project/ScoreMigrationPolicy.m` | **Complete.** Two methods; the Core Data score-store migration. |
| `Project/ShadowView.m` | **Complete.** Two methods; the inner-shadow renderer. |
| `Project/accessoryTableCell.m` | **Complete.** Two methods. |
| `Project/degreeTableCell.m` | **Complete.** Two methods. Sibling of the above, but the bodies differ. |
| `Project/frameTableCell.m` | **Complete.** Two methods. Third sibling; ticks the row matching `PrefTwitterBgFrame`. |
| `Project/StoreTableCell.m` | **Complete.** Two methods, including the tree's first `-dealloc`. |
| `Project/EditorInfoCell.m` | **Complete.** Two methods; badge selected from a three-entry table. |
| `Project/SePlayer.m` | **Complete.** Three methods; the tree's first OpenAL code. |
| `Project/BannerView.m` | **Complete.** Three methods; the tree's first nested blocks and weak capture. |
| `Project/StoreLinkButton.m` | **Complete.** Three methods; draws its own chevron in the title's colour. |
| `Project/ChallengeMissionPlayTerm.m` | **Complete.** Three methods; carries ~380 instructions of dead work, reproduced. |
| `Project/ChallengeMissionAchieve.m` | **Complete.** Three methods; documents the mission-achievement wire format. |
| `Project/EditButtonViewController.m` | **Complete.** Two methods; a weak delegate and an NS_TYPED_ENUM payload. |
| `Project/ChallengeRewardListCell.m` | **Complete.** Three methods; every subview is built lazily by the setters. |
| `Project/ChallengeListViewCell.m` | **Complete.** Two methods; its label overhangs its plate. |
| `Project/ChallengePresentListViewCell.m` | **Complete.** Two methods; the same class done right. |
| `Project/ShadeView.m` | **Complete.** Two methods; a dimming overlay that reports taps. |
| `Project/AppliView.m` | **Complete.** Two methods; ships an NSLog in the release build. |
| `Project/ApplilinkParameters.m` | **Complete.** Two methods; the longer one discards its alignment argument. |
| `Project/NSStringURLEncoding.m` | **Complete.** Two methods; agrees with ../rbplus-src line for line. |
| `Project/ApplilinkNetworkError.m` | **Complete.** Two methods; 43 error codes against the sibling's 40. |
| `Project/CubePurchaseListViewCell.m` | **Complete.** Two methods; draws the cube count from per-digit artwork. Two defects recorded. |
| `Project/ChallengePrevRankingListViewCell.m` | **Complete.** Two methods; the pad's metrics are exactly double the phone's. |
| `Project/UnsealDrawController.m` | **Complete.** Two methods; chains to plain -init, so no nib. |
| `Project/ImageLoading.m` | **Complete.** `LoadScaledPngImage`, the app's own +imageNamed: with 479 call sites. |
| `Project/ChallengeLoginMessageView.m` | **Complete.** Two methods; the daily-login sheet. Carries a backspace in a shipped label. |
| `Project/BalloonView.m` | **Complete.** Three methods; the speech-balloon path with a four-way arrow. |
| `Project/RootViewController.m` | Twelve methods: both fade dispatchers, both store callbacks, the theme factory. |

## Next, in order

`JubeatAppDelegate` is finished, so the chase now runs outwards from what its bodies reach. In
rough order of how much each unlocks:

| Target | Address | Notes |
| --- | --- | --- |
| `-[LogoViewController start]` | not located yet | The launch sequence continues here; class at 0x348a58. |
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
