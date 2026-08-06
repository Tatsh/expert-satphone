# Pending types

Every declaration in this tree that is still typed `id` because the binary has not yet proven a
concrete class. Nothing may stay `id` permanently: `id` here means "not established yet", never "the
binary really is dynamic".

This file exists because a placeholder type is easy to lose. `JubeatAppDelegate.deviceType` was
typed `id` on the strength of its getter loading a 64-bit word, and turned out to be an `NSInteger`
— the four device-idiom predicates load the same ivar and compare it against the constants 1 to 7.
A wrong type that compiles is exactly the kind of defect the reconstruction rules warn about, so
each entry below names the routine whose reconstruction will settle it.

## Verification

`rctool audit addresses <binary>` is the tree's external check and must be run after touching
annotations. Run it from the `recon-tools` checkout:

```sh
uv run rctool -W /path/to/jubeat-src audit addresses /path/to/Jubeat.app/Jubeat
```

**The annotation must be on the method definition in the `.m`, not only on the header
declaration.** `audit_methods` walks `.m`/`.mm` only, pairing `@implementation` → method →
the `/** @ghidraAddress 0x... */` line directly above it. A tag that lives solely in the header is
invisible to it, and the audit then reports `0 annotated`, which reads like a pass and is not one.
Keep the header tag as well — it is what the reader sees — but the `.m` tag is what gets checked.

What the other subcommands do and do not cover here:

| Subcommand | Coverage in this tree |
| --- | --- |
| `addresses` | Real. 91 method annotations checked against the runtime metadata. |
| `objc properties` | Real, and tree-wide: 1379 properties across 222 classes. It caught `ChallengeStatus.coinRestDate` declared `readonly` when the class ships a setter. |
| `objc ivars` | Real, and tree-wide: 3142 ivars across 276 classes. |
| `objc return-widths` | Real. It caught two parameters declared `int` that encode `I`. |
| `objc methods` | Real. Confirms no coined helper name collides with a selector the binary uses. |
| `objc property-types` | Real, and tree-wide: 406 scalar properties. It caught `JubeatAppDelegate.deviceType` declared over `NSInteger` when the metadata encodes it `Q`, and `challengeMusicID` declared `int` when it encodes `I`. |
| `objc property-accessors` | Real. It reports accessors the binary writes by hand, which a `@property` declaration silently satisfies. |
| `objc frame-arithmetic` | Real, but takes **no** binary argument — passing one is an error, not a clean run. |
| `objc format-calls` | Real, and the check for the variadic rule: it compares each format's specifier count against the arguments the stack setup actually supplies. |
| `literals` | Nearly vacuous. It skips any literal with no character above U+0x2000, so it checks the two Japanese strings in `ChallengeStatus.m` and nothing else. Selector checking covers `@selector()` only; the tree now has two, both verified present. |
| `globals` | Vacuous. No annotated global initialisers here yet. |
| `unwritten-members` | Vacuous. It looks for C++ `m_` members, and this tree has none yet. |

**A constant annotation must be a trailing `//` comment on the declaration line**, not a Doxygen
block above it:

```objc
static const CGFloat kDefaultArrowPosision = 0.3f; // @ghidraAddress 0x28f248
```

Written as `/** @ghidraAddress 0x28f248 */` on the preceding line the audit silently ignores it and
reports `constants: 0 annotated`, which is the same shape of vacuous pass as the `0 annotated`
method case above. The correct form makes the tool read the eight bytes at that address and compare
them, so it is the difference between a documented constant and a checked one.

The check covers **numeric** constants only. A `static NSString *const` or an `NSErrorDomain`
annotated the same way is not read back and not compared — the annotation there is documentation,
not verification, and must not be counted as evidence.

`MachOBinary.method_types()` is keyed by the **image-relative** address, not the absolute one, so
`mt.get(0x1eee00)` works where `mt.get(0x1001eee00)` silently returns `None`. A `None` there reads
as "no type information" when the information is present, which is how two `init`-named methods
nearly got conventional signatures instead of their real ones.

Run **every** member of the `objc` group, not a habitual subset. Each of the last three rounds has
turned up a real error in already-committed code from a subcommand that had not been run before:
`property-accessors` found three unwritten `ScoreRecordManager` accessors, and `property-types`
found the two width errors above. The `challengeMusicID` case is the sharpest: `return-widths` had
already corrected the *setter's* parameter to `unsigned int` in an earlier session, while the
property kept `int`. Two subcommands covering two halves of one field, and running only one of them
left the tree internally inconsistent.

So a clean run is necessary and nowhere near sufficient, and only the `addresses` number means
anything today.

`yarn format` does **not** work in this tree: there is no `package.json` (the sibling `rbplus-src`
has one). `.clang-format` is present, so run `clang-format -i` on the touched files directly until
the Node tooling is wired up.

## Rules

- Add a row the moment a declaration is written as `id`.
- Remove the row in the same commit that replaces `id` with the real type.
- A row whose evidence column says "proven" but is still `id` is a bug, not a pending item.
- Write the message form the binary sends, never a syntactic sugar that compiles to a different
  selector. `dict[key]` is `objectForKeyedSubscript:`, which appears **nowhere** in this binary
  — searching the whole image for "forKeyedSubscript" returns zero hits. Every dictionary access
  here is `objectForKey:` or `setObject:forKey:`, with `-[RootViewController
  responseRemoteNotification:pushInfo:]` the one place that uses `setValue:forKey:` instead.
  Array subscripting is the opposite case: `objectAtIndexedSubscript:` is genuinely used by
  `-popNotification`, while every other indexed read sends `objectAtIndex:`.
- Run the whole `rctool objc` group, not just `audit addresses`. Unlike the `audit` group, these
  compare against metadata that covers all 317 classes, so they check declarations the tree has not
  reached yet. Three of them have each caught a real error in already-committed code: a `readonly`
  property that ships a setter, and two `int` parameters that encode `I`.
- Declare an **instance** property only when the binary has the accessor pair. An ivar-offset global
  proves an ivar exists and gives its runtime name; it says nothing about a property wrapping it.
  `RootViewController.musicSelectViewCtrl` was declared as a property on that evidence and had to be
  demoted to an ivar. **Class** properties are the exception: they compile to a single class method
  and are indistinguishable from one, so either spelling is defensible there.

## `JubeatAppDelegate`

| Property            | Settled by                                                       | Evidence so far                                         |
| ------------------- | ---------------------------------------------------------------- | ------------------------------------------------------- |
| `markerList`        | the marker loader, not yet located                                | Object by load width only.                              |
| `jcfDownloadID`     | the download starter, not yet located                             | Cleared to nil by `-resetDownLoadIndex` @0x8c38.        |
| `storeGenreID`      | `-setDownloadGenreID:` callers                                    | Retained via `objc_storeStrong`, so an object.          |
| `storePackID`       | `-setDownloadPackID:` callers                                     | Retained via `objc_storeStrong`, so an object.          |
| `storeCampaignID`   | `-setCampaignID:` callers                                         | Retained via `objc_storeStrong`, so an object.          |
| `campaignImageName` | `-setCampaignImageName:` callers                                  | Retained via `objc_storeStrong`, so an object.          |
| `campaignImagePath` | `-setCampaignImagePath:` callers                                  | Retained via `objc_storeStrong`, so an object.          |
| `storeMissionText`  | `-setStoreMissionText:` callers                                   | Retained via `objc_storeStrong`, so an object.          |
| `searchString`      | `-setSearchString:` callers                                       | Retained via `objc_storeStrong`, so an object.          |
| `notificationTime`  | `-downloaderFinished:` @0x1f078 or `-pushClose:` @0x183090        | Retained as handed in; both callers are in unreconstructed classes. |

## Types weakened rather than `id`

These are not `id`, but are less specific than the binary may allow and should be revisited.

| Declaration                             | Weakened to        | Settled by                                        |
| --------------------------------------- | ------------------ | ------------------------------------------------- |
| `RootViewController.currentSceneID`     | `NSString`         | proven by `-isEqualToString:`, but the set of scene identifiers is not; "SceneStore" sits beside the two known ones in the string pool |
| `RootViewController.titleViewCtrl`      | `UIViewController` | it holds either a `TitleViewControllerOrg` or a `TitleViewControllerRpl` depending on the theme, so a common base or protocol is likely; both respond to `-start` and `-stopAnimation` |
| `RootViewController.gameViewCtrl`       | `UIViewController` | never built in any reconstructed routine, only revealed; whatever assigns it will name the class |
| `RootViewController.storeViewCtrl`      | `UIViewController` | as above. It responds to `-loadInitialStoreInfo`; the binary has both `StoreViewController` and `StoreViewControllerV2`, so which one is not settled |
| `RootViewController.editViewCtrl`       | `UIViewController` | as above. It responds to the same `-loadResources`/`-startAnimation`/`-terminate`/`-releaseResources` set as `gameViewCtrl`, so the two share an interface |
| `KnitColorManager.setColorWithArray:`   | `NSArray`          | the manager's own body; the delegate passes its argument straight through |
| `CustomSequencePageNavViewController.delegate` | `id`      | nothing reconstructed sends it anything yet, so no protocol is proven. Held weakly via `objc_storeWeak` |
| `StorePackView.delegate`                | `id`               | as above; `-[StoreTableCell dealloc]` only clears it |

## Declared without a body

A declaration written because a reconstructed caller sends it, whose own body is not recovered yet.
The tree does not compile as a unit until these are filled in, which is deliberate: a stub body
would be indistinguishable from a reconstructed one.

| Declaration                              | Why it is declared                    | Body at   |
| ---------------------------------------- | ------------------------------------- | --------- |
| `-[KnitColorManager setColorWithArray:]` | `-setKnitColor:` sends it             | not located yet |
| `+[ChallengeStatus sharedStatus]`        | `-applicationDidEnterBackground:` sends it | not located yet |
| `-[ChallengeStatus restCoinNum]`         | `-createCoinNotification` sends it    | not located yet |
| `-[ChallengeStatus getTimeLeft:]`        | `-createCoinNotification` sends it    | not located yet |
| `-[ChallengeStatus coinRestDate]`        | `-createCoinNotification` sends it    | not located yet |
| `+[EditorIDManager getEditorIDKey]`      | `+isExistEditorID` sends it           | not located yet |
| `+[EditorIDManager getEditorPassKey]`    | `+isExistEditorID` sends it           | not located yet |
| `+[EditorIDManager getKeyQuery:]`        | `+isExistEditorID` sends it           | not located yet |
| `+[EditorIDManager deleteKeychain]`      | `+isExistEditorID` sends it           | not located yet |
| `-[PurchaseManager end]`                 | `-applicationWillTerminate:` sends it | not located yet |
| `-[LogoViewController start]`            | `-[RootViewController startLogo]` sends it | not located yet |
| `-[AudioManager stopAllSe]`              | the dispatcher sends it                | not located yet |
| `-[AudioManager releaseBgm:]`            | the dispatcher sends it                | not located yet |
| `+[AudioManager sharedManager]`          | the dispatcher sends it                | not located yet |
| `-[MusicSelectViewController startMainBgm]` | the dispatcher sends it             | not located yet |
| `-[MusicSelectViewController stopStoreInfo]` | the dispatcher sends it            | not located yet |
| `-[MusicSelectViewController reloadMarkerSelectView]` | `-reloadMarkers` sends it | not located yet |
| `-[MusicSelectViewController pushNotificate]` | `-pushNotificate` forwards to it | not located yet |
| `-loadInitialStoreInfo` on the store screen | `-openStoreAnimStop:finished:context:` sends it | not located yet |
| `-[MusicSelectViewController checkAndRetryBgm]`, `-requestNewInfo`, `-JcfDownLoad:`, `-schemeMoveStore`, `-notificationDisp`, `-startOpenDetailPanel` | `-fadeinAnimStop:finished:context:` sends them | not located yet |
| `TitleViewControllerKnt`, `TitleViewControllerNte` | `-createKnitTitleViewController` and `-titleSwitch` build them | not located yet |
| `-showLogo` on the title screens | `-fadeinAnimStop:finished:context:` sends it | not located yet |
| `-startGame` on the game and edit screens | `-fadeinAnimStop:finished:context:` sends it | not located yet |
| `TitleViewControllerOrg`, `TitleViewControllerRpl` | the theme switch builds them | not located yet |
| `+[CJSONSerializer serializer]`           | `-responseRemoteNotification:pushInfo:` sends it | not located yet |
| `-[CJSONSerializer serializeDictionary:error:]` | `-responseRemoteNotification:pushInfo:` sends it | not located yet |
| `-[Downloader initWithURL:postJsonData:delegate:]` | `-responseRemoteNotification:pushInfo:` sends it | not located yet |
| `-[Downloader startDownloading]`          | `-responseRemoteNotification:pushInfo:` sends it | not located yet |
| `-[BFCodec cipherInit:]`                 | `CreateLabEncryptedData` sends it      | 0x94a58   |
| `-[BFCodec encipher:]`                   | `CreateLabEncryptedData` sends it      | 0x94aec   |
| `+[MarkerManager moveMarkerDataInDoc]`    | `-application:didFinishLaunchingWithOptions:` sends it | not located yet |
| `+[MarkerManager checkRegularMarkerData]` | `-application:didFinishLaunchingWithOptions:` sends it | not located yet |
| `+[TweetResourceManager checkResourceData]` | `-application:didFinishLaunchingWithOptions:` sends it | not located yet |
| `+[TweetResourceManager moveResourceDataInDoc]` | `-application:didFinishLaunchingWithOptions:` sends it | not located yet |
| `+[TweetResourceManager checkEnableSelecteFrame:]` | `-application:didFinishLaunchingWithOptions:` sends it | not located yet |
| `+[StoreMusicListManager sharedManager]`  | `-application:didFinishLaunchingWithOptions:` sends it | not located yet |
| `-[StoreMusicListManager loadMusicList]`  | `-application:didFinishLaunchingWithOptions:` sends it | not located yet |
| `-[PurchaseManager start]`                | `-application:didFinishLaunchingWithOptions:` sends it | not located yet |
| `-[PurchaseManager loadProductList]`      | `-application:didFinishLaunchingWithOptions:` sends it | not located yet |
| `-[PurchaseManager loadPendingList]`      | `-application:didFinishLaunchingWithOptions:` sends it | not located yet |
| `-[PurchaseManager loadPendingConsumeList]` | `-application:didFinishLaunchingWithOptions:` sends it | not located yet |
| `+[ScoreRecordManager sharedManager]`    | `-applicationWillTerminate:` sends it | not located yet |
| `-[AudioManager playSeResFile:inDirectory:]` | `-[ChallengeLoginMessageView closeMessage:]` sends it | 0x77f50 |
| `GetScaledResourcePath`                   | `LoadScaledPngImage` calls it          | 0x7e37c |
| `LoadScaledEncryptedTexImage`             | `-[UnsealDrawController viewDidLoad]` calls it | 0x7e9dc |
| `CreateImageFromEncryptedData`            | `LoadScaledEncryptedTexImage` calls it | not located yet |
| `-[CubePurchaseInfo initWithDictionary:]`  | `CubePurchaseListViewCell` is its consumer | 0x63b68 |
| `-[CubePurchaseInfo updateProduct:]`       | ditto                                  | 0x63c48 |
| `-[CubePurchaseInfo getProductID]`         | ditto                                  | 0x63c5c |
| `-[CubePurchaseInfo getProduct]`           | ditto                                  | 0x63d10 |
| `-[CubePurchaseInfo getName]`              | ditto                                  | 0x63d38 |
| `-[StorePromotion initWithPackInfo:imageURL:sampleURL:]` | `BannerView` reads its `imageURL` | 0x1bd754 |
| `-[StorePromotion initWithGenreIndex:imageURL:]` | ditto                          | 0x1bd88c |
| `-[StorePromotion getSampleURL]`           | ditto                                  | 0x1bd954 |
| `-[StorePromotion getSampleName]`          | ditto                                  | 0x1bd9d8 |
| `MyGetOpenALAudioData`                     | `-[SePlayer initWithPath:]` calls it    | 0x153cd4 |
| `+[ApplilinkConsts canUseApplilinkSdk]`    | `AnalysisNetwork` guards on it         | 0x22ec4c |
| `+[AnalysisNetworkCore postAnalysisDataWithResultId:callback:]` | `AnalysisNetwork` forwards to it | 0x2395bc |
| `+[AnalysisNetworkCore openExternalWebBrowserCore:env:callback:]` | ditto              | 0x23a2fc |
| `+[AnalysisNetworkCore openWebBrowserWithAppliIdCore:env:callback:]` | ditto           | 0x23b04c |
| `AnalysisNetworkCore`'s other ten class methods | reached only through the SDK       | 0x238d98 onwards |
| `-[StoreRecommendPackView initWithFrame:]`  | `StoreRecommendTableCell` builds two | 0x1449fc |
| `-[StorePackInfo packID]` and four siblings | `-[StoreRecommendPackView loadPackInfo:index:]` reads them | 0xbe3d0, 0xbe410, 0xbe3e0, 0xbe3f0, 0xbd6b4 |
| `+[StoreUtil productIDForPackID:]`          | ditto                                | 0xbab70 |
| `-[PurchaseManager isPurchased:]`           | ditto                                | 0xb61d8 |
| `-[PurchaseManager isPending:]`             | ditto                                | 0xb61f0 |

## Defects found in the binary

### `-[ApplilinkParameters setRequestWithAdModel:adLocation:verticalAlign:requestCode:]` (0x26895c) — the alignment is discarded

The four-argument setter never reads its `verticalAlign` argument. `x4` is untouched from entry to
return, and the ivar at 0x34c684 receives `x5`, the request code. The body is otherwise identical
instruction for instruction to the three-argument setter at 0x2688d0, so the only reason to call
the longer one is the thing it throws away.

`verticalAlign` is a real ivar with a real synthesised accessor pair, so a caller can still set it
through the property. Nothing inside the class ever writes it.

The sibling `../rbplus-src` reaches the same conclusion from the other binary independently, which
makes this a property of the SDK rather than of this build.

### `-[CubePurchaseListViewCell setBgImage:info:cache:aDelegate:]` (0x64328) — a sixth digit

The row owns exactly five digit image views (`numImg` is `[5@"UIImageView"]`), but the loop that
counts the cube total's digits can return six.

The counting loop divides by ten and then tests two things: whether the quotient still exceeds one
digit, and whether the pass counter is at most three. The counter is read *before* it is
incremented — `ccmp w9,#3,#0,cs` at 0x64438 sets the flags, and the `add w9,w9,#1` two instructions
later does not touch them — so four back-edges are allowed and the counter reaches five. The digit
count is that plus one.

The fill loop then walks `numImg[digitCount - 1]` down to `numImg[0]`, so a count of six writes one
element past the array. It needs a cube total of at least 100000 to trigger, which the store's
packs presumably never reach, so it is latent rather than live. Reproduced as written.

### `-[ChallengeMissionPlayTerm initWithData:achieve:]` (0x1ef338) — ~380 instructions of dead work

The routine compares each play-term row against row 0 twice, in two near-identical blocks. The
second block's result is stored as `historyDup`. The first block's is discarded.

The first block allocates a seven-entry flag array at 0x1ef63c, populates it across the whole
detail list, and releases it at 0x1efa3c. Between those two points `x28` is only ever the receiver
of `setObject:atIndexedSubscript:`; no instruction stores it into an ivar or anywhere else. Its
four scratch values live in `[sp+0x90]`, `[sp+0x88]`, `[sp+0x84]` and `[sp+0x80]`, read only inside
its own loop, and `[sp+0x90]` is overwritten with the terms object at 0x1efa4c the moment the block
ends. The live block further down uses a different set of slots for the same four values, so the
two do not feed each other.

The two blocks are also not equivalent, which is what makes the dead one look like an earlier draft
rather than a copy:

- the dead one starts every flag `NO` and sets `YES` on a mismatch; the live one starts `YES` and
  sets `NO`;
- the dead one guards all four comparisons behind a single `expected music == -1` test, so an
  unconstrained music column suppresses the other three; the live one guards each column with its
  own `-1` test;
- the live one also maintains an "everything agreed" boolean that decides whether `playHistory` is
  filled at all.

Reproduced in full. It is inert, but removing it would make the source disagree with the binary in
a way no later reader could detect.

### `-[ChallengeMissionPlayTerm initWithData:achieve:]` (0x1ef338) — the sort that makes removal safe

The tail removes achieved rows from a mutable copy of the mission list with
`removeObjectAtIndex:`, iterating the achievement keys. Removing by index while walking a key list
is the classic shifting-index bug, and it is not one here: the keys are sorted through the global
comparator block at 0x1f0a28, which boxes both arguments and answers `[second compare:first]` —
reversed, so **descending**. Each index is therefore removed before any lower index can shift.

Recorded because the safety is entirely in the comparator, four hundred instructions away from the
removal, and a reader checking only the loop would reasonably conclude it was broken.

### `+[StickerUtility checkExistSticker:]` (0xdc690) — the argument is never read

The method is encoded `B24@0:8@16`, so it takes an object and returns a boolean. The body never
touches `x2`. What it actually does is ask `NSFileManager` for the app group's container URL and
test whether *that directory* exists.

The container exists whenever the app group is provisioned, so the method answers the same value
for every sticker name it is given, including names that were never saved. A caller using it to
decide whether to re-download a sticker would skip every download.

Reproduced with the argument declared and unused, and the header says plainly that the name does
not do what it says.

Related, in the same class: `+cleanStickerList` removes the name dictionary but does not call
`-synchronize`, where `+saveSticker:displayName:data:` does — and it deletes no files, so the
sticker images survive with no names attached. Neither is obviously wrong on its own; together they
mean the file set and the name dictionary can disagree in both directions.

### `-[ChallengeListViewCell initWithStyle:reuseIdentifier:]` (0x2087e0) — the label overhangs its plate

`ChallengeListViewCell` and `ChallengePresentListViewCell` are the same class twice over: same
ivars, same properties, same two selectors, same plate widths from the same two pool slots. They
disagree on one piece of arithmetic.

The present cell gives its label a width of 299 on the phone and 440 on the pad, against an inset of
10 and 20 and a plate width of 309 and 460 — so `inset + width` is exactly the plate width and the
label ends flush with it.

The challenge cell gives its label the plate's *own* width, 309 or 460, while still insetting it by
10 or 20. `inset + width` therefore exceeds the plate by one inset and the label overhangs its
trailing edge.

Both labels are subviews of the cell rather than of the plate, so this clips nothing and crashes
nothing; long text simply runs past the artwork. Recorded because the two classes are otherwise
identical, which makes the difference deliberate-looking when it is much more likely a copy that
missed one subtraction.

### `-[CubePurchaseListViewCell addBtn]` (0x64728) — a property nothing ever assigns

`addBtn` is declared readonly over the `_addBtn` ivar and has a getter, but the class defines no
setter and neither of its two other methods writes the ivar. Since the ivar is private, nothing can
write it, so the property returns nil for the lifetime of every instance. Only `.cxx_destruct`
touches it. Declared faithfully, with the fact noted at the declaration.

### `-[ChallengeLoginMessageView initWithFrame:scratchNum:]` (0xa75fc) — a backspace in a label

The upper label's format string, the CFString at 0x2d9940, is twenty UTF-16 units long and the
first is **U+0008**, a backspace, ahead of the first Japanese character:

```
U+0008 U+3042 U+3068 U+0025 U+0064 U+56DE ...
```

It is worth saying why this is the string and not a misread, because the alternative is plausible.
The data begins at 0x2c0dfe and the next constant string begins at 0x2c0e28; nineteen units from
0x2c0e00 and twenty units from 0x2c0dfe both end at the same address, so alignment alone cannot
decide it. The CFString's own two fields do: it records `ptr = 0x2c0dfe` and `length = 20`. Had the
text been the nineteen visible characters the compiler would have emitted the later pointer and the
smaller length.

Reproduced verbatim as `@"\bあと%d回無料でスクラッチができます！"`. The neighbouring note label at
0x2d9960 has no such prefix, so this is one string and not a pattern.

### `-[KnitColorManager setColorWithType:]` (0x1660d8) — type 5 reads past the table

The palette table at 0x353d78 has five rows; the bytes immediately after row 4 are `__DATA` pointers,
not floats. The method indexes it as `type * 0x30` with no range check, so type 5 reads one row past
the end and interprets pointers as colour components.

Type 5 is not an arbitrary out-of-range value either: the flag computation two instructions earlier
singles it out alongside type 0 as a type that does not "differ" from the default. So the binary has
a named type it cannot actually look up. Only type 4 is known to reach this method in practice, from
`-[JubeatAppDelegate switchTitleEvent]`.

### Row 2's wave colour is out of range

Row 2's wave group reads `2290, 0, 18, 1`. `-makeColor:` divides the first three components by 255,
giving 8.98 for red, which `UIColor` clamps to 1.0 — so it renders as pure red rather than the
intended shade. Transcribed as-is; it is the binary's value, not a transcription error.


Behaviour that is faithfully reproduced but is a bug in the shipped application. Recorded here so a
later reader does not "fix" the reconstruction into disagreeing with the binary.

### `-application:handleOpenURL:` (0x9090) — dead pack and genre routes

Inside the arm guarded by `components[1] == "jbtstore"`, the code fetches `components[1]` *again* at
0x91e0 and compares it against `"pack"` and `"genre"`. One array element cannot equal two different
strings, so neither comparison can succeed and the `_storePackID` and `_storeGenreID` stores are
unreachable under every URL shape. Index 2 is fetched separately at 0x91c0 and used only as the
value.

The instructions are not ambiguous: `w2 = #0x1` at 0x91e0 with the same `objectAtIndex:` selector
as the enclosing test. The `"jbtgift"` route at 0x9280 and the `digitStringCheck:` route at 0x92cc
are both reachable, so only two of the four routes work.

`-application:didReceiveLocalNotification:` (0xac48) settles what was meant. It routes the same
three tokens — `"jbtstore"`, `"jbtgift"`, `"jbtchallenge"` — and reads each off `[url scheme]` at
0xad80, 0xafb8, and 0xb004. `handleOpenURL:` reads `components[1]` instead. The two methods share
their CFStrings, so this is one routing idea written twice, correctly once.

### `-application:didReceiveLocalNotification:` (0xac48) — `timeIntervalSince1970` result discarded

At 0xaf84 the foreground arm sends `-timeIntervalSince1970` to a fresh `[NSDate date]` and never
reads `d0`. No store follows, and the next call is `-saveNotification`, whose selector at 0x340738
takes no argument, so the value cannot be reaching it. The date object is still released at 0xb08c,
so it is dead computation rather than a leak. Most likely a stamping step that was gutted, leaving
each queued notification without its own fire time — `expire` comes from the payload instead.

### `-application:didReceiveLocalNotification:` (0xac48) — unguarded arms

Two missing guards, both faithful:

- `-apsDictionary:` returns nil for a `userInfo` with no `"aps"` entry, and the result is passed
  straight to `-addObject:` at 0xaf58 with no nil test. A local notification carrying `userInfo`
  but no `aps` therefore raises `NSInvalidArgumentException`.
- The `jbtstore` arm checks `pathComponents.count == 3` at 0xadf0. The `jbtgift` arm at 0xb034 goes
  directly to `objectAtIndex:2` with no count check, so a short `jbtgift://` URL raises
  `NSRangeException`.

### `-application:didFinishLaunchingWithOptions:` (0x933c) — four discarded computations

None of these is a guess about intent; each is a value the instructions produce and then never read.

- `arc4random()` at 0x9370. The result is not stored and `x0` is dead at the next instruction.
  `arc4random` seeds itself, so calling it to "prime" the generator does nothing.
- `[UIDevice.currentDevice systemVersion]` at 0x995c. It is retained into the stack slot at
  `sp+0x20` and released at 0xa138, and nothing between those two points reads the slot. Only the
  `NSClassFromString(@"GKLocalPlayer")` probe that follows decides `gameCenterAvailable`, so the
  version check this fed has been removed.
- All four `AVAudioSession` calls are given a separate `NSError *` out-parameter — at `sp+0x58`,
  `sp+0x50`, `sp+0x48`, and `sp+0x40` — and each is retained and released without being examined.
  A failure to set the category, sample rate, buffer duration, or active state is silent.

A fifth oddity is an ordering rather than a discard: `registerForRemoteNotifications` is sent at
0xa0d4 and `registerUserNotificationSettings:` only at 0xa104. Apple's order is the reverse, since
the settings are what determine the permission prompt.

### `-application:didReceiveRemoteNotification:` (0xb0c8) — inherits all three, plus one

The remote twin repeats the discarded `timeIntervalSince1970` at 0xb3dc and the unguarded
`objectAtIndex:2` at 0xb4b4, and drops even the `userInfo` nil test.

It adds one of its own: `-apsDictionary:` is called at 0xb150, *before* the `applicationState`
split at 0xb17c. Only the foreground arm reads the result, at 0xb3ac. On the routing path the
dictionary is built and then released at 0xb50c without ever being used — every URL-routed remote
notification allocates and discards an `NSMutableDictionary`.

## Settled

Kept as a record of what the evidence was, so a later reader does not have to re-derive it.

| Declaration                      | Was          | Now                    | Proven by                                                |
| -------------------------------- | ------------ | ---------------------- | -------------------------------------------------------- |
| `JubeatAppDelegate.deviceType`   | `id`         | `NSInteger`            | the four idiom predicates compare it against 1 to 7.     |
| `JubeatAppDelegate.currentTheme` | `int`        | `unsigned int`         | `-changeTheme:` boxes it with `+numberWithUnsignedInt:`. |
| `JubeatAppDelegate.rootViewCtrl` | `UIViewController` | `RootViewController` | `-changeTheme:` sends `-changeThemeAndGoTitle`, whose only implementation is `-[RootViewController changeThemeAndGoTitle]` @0x1a8a68. |
| `JubeatAppDelegate.pushNotificationList` | `NSArray` | `NSMutableArray` | `-loadNotification` stores `-mutableCopy` of the unarchived object at 0xa828. |
| `JubeatAppDelegate.deviceToken` | `id` | `NSString` | `-application:didRegisterForRemoteNotificationsWithDeviceToken:` stores the token's `-description` with `<`, `>`, and spaces stripped. |
| `JubeatAppDelegate.remotePushInfo` | `id` | `NSDictionary` | `-application:didFinishLaunchingWithOptions:` stores a `-copy` of `launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey]` at 0x96b0; it is the only writer. |
| `JubeatAppDelegate.deviceType` | `NSInteger` | `JubeatDeviceType` | the classifier at 0x9748-0x97d0 and 0xa180-0xa25c assigns all eight values; see below. |

### The `deviceType` enumeration

Settled by disassembling the classifier, which the decompile rendered wrongly — it presented the
scale as re-read per comparison and lost that `d8` holds the scale for the first test and then
`bounds.size.height` (register `v3`) for the second. The real decision is:

| Value | Idiom | Scale | `bounds.size.height` |
| --- | --- | --- | --- |
| 0 | Phone | neither 2 nor 3 | not consulted |
| 1 | Phone | 2 | neither 667 nor 568 |
| 2 | Phone | 2 | 568 |
| 3 | Phone | 2 | 667 |
| 4 | Phone | 3 | 667 |
| 5 | Phone | 3 | not 667 |
| 6 | not Phone | not 2 | not consulted |
| 7 | not Phone | 2 | not consulted |

The two heights are the pooled doubles at 0x28dfd0 and 0x28dfd8, decoded from memory as 667.0 and
568.0 rather than guessed.

This also explains `is4inchAspect`, which was the odd one of the four predicates: it accepts 2
through 5, and the table shows those are exactly the 16:9 screens. The predicate's name is the
binary's own idea, not a claim that all four devices are four inches.
