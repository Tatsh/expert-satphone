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

**`tools/progress.py` under-counts hand-written accessors, so a class reported at `0 outstanding`
may still owe work.** It excludes accessors by body size, and a short accessor that is nonetheless
hand-written falls under the threshold. `-[StorePackCell isPurchased]` (0xf1878) and
`-setIsPurchased:` (0xf18a4) are the found example: the property carries no `V_` backing in its
attributes because it is stored in `labelPurchased`'s own `hidden` flag, and both accessors invert
it. Neither is synthesised and neither was listed as outstanding. When a property's metadata
attributes lack a `V_` backing ivar, read its accessors rather than trusting the count. The tool is
deliberately left alone — it is the measurement, and adjusting it to flatter the number is not a
fix.

What the other subcommands do and do not cover here:

| Subcommand                | Coverage in this tree                                                                                                                                                                                                                           |
| ------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `addresses`               | Real. 91 method annotations checked against the runtime metadata.                                                                                                                                                                               |
| `objc properties`         | Real, and tree-wide: 1379 properties across 222 classes. It caught `ChallengeStatus.coinRestDate` declared `readonly` when the class ships a setter.                                                                                            |
| `objc ivars`              | Real, and tree-wide: 3142 ivars across 276 classes.                                                                                                                                                                                             |
| `objc return-widths`      | Real. It caught two parameters declared `int` that encode `I`.                                                                                                                                                                                  |
| `objc methods`            | Real. Confirms no coined helper name collides with a selector the binary uses.                                                                                                                                                                  |
| `objc property-types`     | Real, and tree-wide: 406 scalar properties. It caught `JubeatAppDelegate.deviceType` declared over `NSInteger` when the metadata encodes it `Q`, and `challengeMusicID` declared `int` when it encodes `I`.                                     |
| `objc property-accessors` | Real. It reports accessors the binary writes by hand, which a `@property` declaration silently satisfies.                                                                                                                                       |
| `objc frame-arithmetic`   | Real, but takes **no** binary argument — passing one is an error, not a clean run.                                                                                                                                                              |
| `objc format-calls`       | Real, and the check for the variadic rule: it compares each format's specifier count against the arguments the stack setup actually supplies.                                                                                                   |
| `literals`                | Nearly vacuous. It skips any literal with no character above U+0x2000, so it checks the two Japanese strings in `ChallengeStatus.m` and nothing else. Selector checking covers `@selector()` only; the tree now has two, both verified present. |
| `globals`                 | Vacuous. No annotated global initialisers here yet.                                                                                                                                                                                             |
| `unwritten-members`       | Vacuous. It looks for C++ `m_` members, and this tree has none yet.                                                                                                                                                                             |

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
already corrected the _setter's_ parameter to `unsigned int` in an earlier session, while the
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

| Property            | Settled by                                                 | Evidence so far                                                     |
| ------------------- | ---------------------------------------------------------- | ------------------------------------------------------------------- |
| `markerList`        | the marker loader, not yet located                         | Object by load width only.                                          |
| `jcfDownloadID`     | the download starter, not yet located                      | Cleared to nil by `-resetDownLoadIndex` @0x8c38.                    |
| `storeGenreID`      | `-setDownloadGenreID:` callers                             | Retained via `objc_storeStrong`, so an object.                      |
| `storePackID`       | `-setDownloadPackID:` callers                              | Retained via `objc_storeStrong`, so an object.                      |
| `storeCampaignID`   | `-setCampaignID:` callers                                  | Retained via `objc_storeStrong`, so an object.                      |
| `campaignImageName` | `-setCampaignImageName:` callers                           | Retained via `objc_storeStrong`, so an object.                      |
| `campaignImagePath` | `-setCampaignImagePath:` callers                           | Retained via `objc_storeStrong`, so an object.                      |
| `storeMissionText`  | `-setStoreMissionText:` callers                            | Retained via `objc_storeStrong`, so an object.                      |
| `searchString`      | `-setSearchString:` callers                                | Retained via `objc_storeStrong`, so an object.                      |
| `notificationTime`  | `-downloaderFinished:` @0x1f078 or `-pushClose:` @0x183090 | Retained as handed in; both callers are in unreconstructed classes. |

## Types weakened rather than `id`

These are not `id`, but are less specific than the binary may allow and should be revisited.

| Declaration                                    | Weakened to        | Settled by                                                                                                                                                                             |
| ---------------------------------------------- | ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `RootViewController.currentSceneID`            | `NSString`         | proven by `-isEqualToString:`, but the set of scene identifiers is not; "SceneStore" sits beside the two known ones in the string pool                                                 |
| `RootViewController.titleViewCtrl`             | `UIViewController` | it holds either a `TitleViewControllerOrg` or a `TitleViewControllerRpl` depending on the theme, so a common base or protocol is likely; both respond to `-start` and `-stopAnimation` |
| `RootViewController.gameViewCtrl`              | `UIViewController` | never built in any reconstructed routine, only revealed; whatever assigns it will name the class                                                                                       |
| `RootViewController.storeViewCtrl`             | `UIViewController` | as above. It responds to `-loadInitialStoreInfo`; the binary has both `StoreViewController` and `StoreViewControllerV2`, so which one is not settled                                   |
| `RootViewController.editViewCtrl`              | `UIViewController` | as above. It responds to the same `-loadResources`/`-startAnimation`/`-terminate`/`-releaseResources` set as `gameViewCtrl`, so the two share an interface                             |
| `KnitColorManager.setColorWithArray:`          | `NSArray`          | the manager's own body; the delegate passes its argument straight through                                                                                                              |
| `CustomSequencePageNavViewController.delegate` | `id`               | nothing reconstructed sends it anything yet, so no protocol is proven. Held weakly via `objc_storeWeak`                                                                                |
| `StorePackView.delegate`                       | `id`               | as above; `-[StoreTableCell dealloc]` only clears it                                                                                                                                   |

## Declared without a body

A declaration written because a reconstructed caller sends it, whose own body is not recovered yet.
The tree does not compile as a unit until these are filled in, which is deliberate: a stub body
would be indistinguishable from a reconstructed one.

| Declaration                                                                                                                                           | Why it is declared                                                                       | Body at                      |
| ----------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- | ---------------------------- |
| `-[KnitColorManager setColorWithArray:]`                                                                                                              | `-setKnitColor:` sends it                                                                | not located yet              |
| `+[ChallengeStatus sharedStatus]`                                                                                                                     | `-applicationDidEnterBackground:` sends it                                               | not located yet              |
| `-[ChallengeStatus restCoinNum]`                                                                                                                      | `-createCoinNotification` sends it                                                       | not located yet              |
| `-[ChallengeStatus getTimeLeft:]`                                                                                                                     | `-createCoinNotification` sends it                                                       | not located yet              |
| `-[ChallengeStatus coinRestDate]`                                                                                                                     | `-createCoinNotification` sends it                                                       | not located yet              |
| `-[PurchaseManager end]`                                                                                                                              | `-applicationWillTerminate:` sends it                                                    | not located yet              |
| `-[LogoViewController start]`                                                                                                                         | `-[RootViewController startLogo]` sends it                                               | not located yet              |
| `-[AudioManager stopAllSe]`                                                                                                                           | the dispatcher sends it                                                                  | not located yet              |
| `-[AudioManager releaseBgm:]`                                                                                                                         | the dispatcher sends it                                                                  | not located yet              |
| `+[AudioManager sharedManager]`                                                                                                                       | the dispatcher sends it                                                                  | not located yet              |
| `-[MusicSelectViewController startMainBgm]`                                                                                                           | the dispatcher sends it                                                                  | not located yet              |
| `-[MusicSelectViewController stopStoreInfo]`                                                                                                          | the dispatcher sends it                                                                  | not located yet              |
| `-[MusicSelectViewController reloadMarkerSelectView]`                                                                                                 | `-reloadMarkers` sends it                                                                | not located yet              |
| `-[MusicSelectViewController pushNotificate]`                                                                                                         | `-pushNotificate` forwards to it                                                         | not located yet              |
| `-loadInitialStoreInfo` on the store screen                                                                                                           | `-openStoreAnimStop:finished:context:` sends it                                          | not located yet              |
| `-[MusicSelectViewController checkAndRetryBgm]`, `-requestNewInfo`, `-JcfDownLoad:`, `-schemeMoveStore`, `-notificationDisp`, `-startOpenDetailPanel` | `-fadeinAnimStop:finished:context:` sends them                                           | not located yet              |
| `TitleViewControllerKnt`, `TitleViewControllerNte`                                                                                                    | `-createKnitTitleViewController` and `-titleSwitch` build them                           | not located yet              |
| `-showLogo` on the title screens                                                                                                                      | `-fadeinAnimStop:finished:context:` sends it                                             | not located yet              |
| `-startGame` on the game and edit screens                                                                                                             | `-fadeinAnimStop:finished:context:` sends it                                             | not located yet              |
| `TitleViewControllerOrg`, `TitleViewControllerRpl`                                                                                                    | the theme switch builds them                                                             | not located yet              |
| `+[CJSONSerializer serializer]`                                                                                                                       | `-responseRemoteNotification:pushInfo:` sends it                                         | not located yet              |
| `-[CJSONSerializer serializeDictionary:error:]`                                                                                                       | `-responseRemoteNotification:pushInfo:` sends it                                         | not located yet              |
| `-[Downloader initWithURL:postJsonData:delegate:]`                                                                                                    | `-responseRemoteNotification:pushInfo:` sends it                                         | not located yet              |
| `-[Downloader startDownloading]`                                                                                                                      | `-responseRemoteNotification:pushInfo:` sends it                                         | not located yet              |
| `-[BFCodec cipherInit:]`                                                                                                                              | `CreateLabEncryptedData` sends it                                                        | 0x94a58                      |
| `-[BFCodec encipher:]`                                                                                                                                | `CreateLabEncryptedData` sends it                                                        | 0x94aec                      |
| `+[MarkerManager moveMarkerDataInDoc]`                                                                                                                | `-application:didFinishLaunchingWithOptions:` sends it                                   | not located yet              |
| `+[MarkerManager checkRegularMarkerData]`                                                                                                             | `-application:didFinishLaunchingWithOptions:` sends it                                   | not located yet              |
| `+[TweetResourceManager checkResourceData]`                                                                                                           | `-application:didFinishLaunchingWithOptions:` sends it                                   | not located yet              |
| `+[TweetResourceManager moveResourceDataInDoc]`                                                                                                       | `-application:didFinishLaunchingWithOptions:` sends it                                   | not located yet              |
| `+[TweetResourceManager checkEnableSelecteFrame:]`                                                                                                    | `-application:didFinishLaunchingWithOptions:` sends it                                   | not located yet              |
| `+[StoreMusicListManager sharedManager]`                                                                                                              | `-application:didFinishLaunchingWithOptions:` sends it                                   | not located yet              |
| `-[StoreMusicListManager loadMusicList]`                                                                                                              | `-application:didFinishLaunchingWithOptions:` sends it                                   | not located yet              |
| `-[PurchaseManager start]`                                                                                                                            | `-application:didFinishLaunchingWithOptions:` sends it                                   | not located yet              |
| `-[PurchaseManager loadProductList]`                                                                                                                  | `-application:didFinishLaunchingWithOptions:` sends it                                   | not located yet              |
| `-[PurchaseManager loadPendingList]`                                                                                                                  | `-application:didFinishLaunchingWithOptions:` sends it                                   | not located yet              |
| `-[PurchaseManager loadPendingConsumeList]`                                                                                                           | `-application:didFinishLaunchingWithOptions:` sends it                                   | not located yet              |
| `+[ScoreRecordManager sharedManager]`                                                                                                                 | `-applicationWillTerminate:` sends it                                                    | not located yet              |
| `-[AudioManager playSeResFile:inDirectory:]`                                                                                                          | `-[ChallengeLoginMessageView closeMessage:]` sends it                                    | 0x77f50                      |
| `GetScaledResourcePath`                                                                                                                               | `LoadScaledPngImage` calls it                                                            | 0x7e37c                      |
| `LoadScaledEncryptedTexImage`                                                                                                                         | `-[UnsealDrawController viewDidLoad]` calls it                                           | 0x7e9dc                      |
| `CreateImageFromEncryptedData`                                                                                                                        | `LoadScaledEncryptedTexImage` calls it                                                   | not located yet              |
| `-[StorePromotion initWithPackInfo:imageURL:sampleURL:]`                                                                                              | `BannerView` reads its `imageURL`                                                        | 0x1bd754                     |
| `-[StorePromotion initWithGenreIndex:imageURL:]`                                                                                                      | ditto                                                                                    | 0x1bd88c                     |
| `-[StorePromotion getSampleURL]`                                                                                                                      | ditto                                                                                    | 0x1bd954                     |
| `-[StorePromotion getSampleName]`                                                                                                                     | ditto                                                                                    | 0x1bd9d8                     |
| `MyGetOpenALAudioData`                                                                                                                                | `-[SePlayer initWithPath:]` calls it                                                     | 0x153cd4                     |
| `+[ApplilinkConsts canUseApplilinkSdk]`                                                                                                               | `AnalysisNetwork` guards on it                                                           | 0x22ec4c                     |
| `+[AnalysisNetworkCore postAnalysisDataWithResultId:callback:]`                                                                                       | `AnalysisNetwork` forwards to it                                                         | 0x2395bc                     |
| `+[AnalysisNetworkCore openExternalWebBrowserCore:env:callback:]`                                                                                     | ditto                                                                                    | 0x23a2fc                     |
| `+[AnalysisNetworkCore openWebBrowserWithAppliIdCore:env:callback:]`                                                                                  | ditto                                                                                    | 0x23b04c                     |
| `AnalysisNetworkCore`'s other ten class methods                                                                                                       | reached only through the SDK                                                             | 0x238d98 onwards             |
| `-[StoreRecommendPackView initWithFrame:]`                                                                                                            | `StoreRecommendTableCell` builds two                                                     | 0x1449fc                     |
| `NSDictionary (TypedAccessors)` `numberForKey:`/`stringForKey:`/`arrayForKey:`                                                                        | `-[StorePackInfo setPackInfo:]` and its siblings read the store dictionaries through it  | 0x1ba1ec, 0x1ba264, 0x1ba174 |
| `-[PurchaseManager isPurchased:]`                                                                                                                     | ditto                                                                                    | 0xb61d8                      |
| `-[PurchaseManager isPending:]`                                                                                                                       | ditto                                                                                    | 0xb61f0                      |
| `+[ScratchUtil getInheritOutputURL]`                                                                                                                  | `-[InheritCodePayView tapCodeOutput:]` sends it                                          | 0x1823cc                     |
| `GameViewController` and `EditViewController`                                                                                                         | `-[RootViewController init]` builds one of each                                          | not located yet              |
| `+[MissionAchievementMessage createTitleArray:achieve:]`                                                                                              | the mission wire format it reads is unresolved; the rest of the class is reconstructed   | 0x4d790                      |
| `CreateSha256HexStringFromData` (free function)                                                                                                       | `+[StoreUtil checkStoreResponse:]` calls it                                              | not located yet              |
| `CreateReflectedImage` (free function)                                                                                                                | `-[StoreDetailHeaderView setArtwork:]` calls it                                          | 0x7ecdc                      |
| `+[ScratchUtil cubeVerifyReceiptURL]`                                                                                                                 | `+[StoreUtil verifyReceiptNewURL]` and `-verifyReceiptConsumeURL` call it                | 0x181688                     |
| `StoreViewController` with `-setStartupParameters:`, `-storeClose`, `-openDetail:`, `-openCampaignDetail:`, `-loadInitialStoreInfo`                   | `-[RootViewController openStore:]` and the store callbacks send them                     | not located yet              |
| `-[CampaignItemInfo campaignID]`                                                                                                                      | `-[StoreCampaignTableViewCell setInfo:tag:]` reads it                                    | 0xc8b4                       |
| `-[StoreCampaignViewController selectItem:]`                                                                                                          | `-[StoreCampaignTableViewCell touchesEnded:withEvent:]` forwards to it                   | 0xbfd60                      |
| `ScratchView` (`initWithFrame:`, `setADelegate:`, `updateView:`, `getState`, `setButtonEnable:`, `timerUpdate`)                                       | `-[ScratchBoardView initWithFrame:]` builds sixteen and fans out to them                 | 0x1afc88 onwards             |
| `-[ChallengeStatus myName]`, `-mySearchID`, `-updateName:`, and `-rootView`/`-closeChallengeModeSessionError`                                         | `-[ChallengeNameSettingView …]` reads, updates, and routes dismissal through them        | not located yet              |
| `ChallengePresentListViewCell` (`initWithStyle:reuseIdentifier:`, `setBgImage:text:`, `addBtn`, `setADelegate:`)                                      | `-[ChallengePresentListView tableView:cellForRowAtIndexPath:]` vends and configures them | 0x351588 (class)             |
| `-[ChallengeStatus receivePresent:]` and `-setPresentNum:`                                                                                            | `-[ChallengePresentView downloaderFinished:]` records the accepted present through them  | not located yet              |
| `-[ChallengeStatus nailNum]` and `-scratchablePanelNum`                                                                                               | `-[ScratchBoardView refreshScratchCount]`/`-refreshScratchTable` read them               | 0x1ce164, 0x1cd60c           |
| `-[ChallengeStatus jCubeNum]` and `-timeStringFromInterval:Minute:`                                                                                   | `-[ChallengeStatusView updateDisplayStatus]`/`-timerUpdate` read them                    | not located yet              |
| `-[ChallengeStatus scratchLineUp]`                                                                                                                    | `-[ScratchInfo init:]` resolves a track from it                                          | not located yet              |
| The `cubePurchaseStart:` delegate of `ChallengeStatusView`                                                                                            | `-tapBuyCube:`/`-alertSelect:` send it; no protocol proven                               | not located yet              |
| `RecommendCore` (`+sharedInstance`, `-redirectWithRequest:`, `-redirectViewContollerWithRequest:`, `-showVideoViewWithQuery:`)                        | `-[ApplilinkWebView …]` and `-[RecommendWebViewController …]` route through it           | not located yet              |
| `RewardWebViewController`                                                                                                                             | superclass of `RecommendWebViewController`; forward-declared as a `UIViewController`     | not located yet              |
| `MusicView` (`initWithFrame:artworkSize:colType:labelDisp:`, `setInfo:bArtistNameDisp:`, `imgView`, `clearInfo`, `tuneInfo`)                          | `-[collectionCell initCell:parentDelegate:viewType:labelDisp:]` builds and drives one    | not located yet              |
| `GameNetworkUtil` (`+rewardCheckURL`, `+getStoreTarget`, `+fillInstallAppNum:`)                                                                       | `-[RewardCheck …]` builds and reports its request through it                             | not located yet              |
| `MarkerManager` (`+getMarkerPath:`, `+saveMarker:markerID:`, `+pullOutMarkerBanner:bannerID:`, `+setMarkerInfo:`) and `VerifyMd5Digest`               | `-[MarkerDownloadManager downloaderFinished:]` installs each verified pack through them  | 0x1b884c onwards, 0x7f560    |

## Defects found in the binary

### `-[ApplilinkParameters setRequestWithAdModel:…]` (0x26895c) — the alignment is discarded

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
digit, and whether the pass counter is at most three. The counter is read _before_ it is
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

### `TimerView` (class at 0x34f968) — an entire class that does nothing

Not one method, but all of them. The class ships six ivars, a weak delegate property and four
methods. Three of those methods — `-setTimeFont:`, `-setTimer:` and `-timerStart` — have bodies
consisting of a single `ret`. The fourth, `-initWithFrame:`, calls `[super initWithFrame:]` and
returns its result with nothing in between: no assignment to `self`, no nil check, no ivar setup.

`startTime`, `endTime`, `currentTime`, `timer` and `timeText` are therefore never read and never
written by anything. The only code that touches any of them is the compiler-generated
`.cxx_destruct` at 0x15c924, which releases `timer` and `timeText` — neither of which can ever hold
anything.

Note that `-setTimer:` takes a `double`, per its `v24@0:8d16` encoding, so it is a duration rather
than a setter for the `NSTimer` ivar that shares its name. Even the naming was never reconciled.

Reproduced in full, empty bodies and all. A reader who finds this class and assumes the
reconstruction is incomplete would be wrong, which is exactly why it is recorded here.

### `+[StickerUtility checkExistSticker:]` (0xdc690) — the argument is never read

The method is encoded `B24@0:8@16`, so it takes an object and returns a boolean. The body never
touches `x2`. What it actually does is ask `NSFileManager` for the app group's container URL and
test whether _that directory_ exists.

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

The challenge cell gives its label the plate's _own_ width, 309 or 460, while still insetting it by
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

```text
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

Inside the arm guarded by `components[1] == "jbtstore"`, the code fetches `components[1]` _again_ at
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

It adds one of its own: `-apsDictionary:` is called at 0xb150, _before_ the `applicationState`
split at 0xb17c. Only the foreground arm reads the result, at 0xb3ac. On the routing path the
dictionary is built and then released at 0xb50c without ever being used — every URL-routed remote
notification allocates and discards an `NSMutableDictionary`.

### `+[Crypto sha1:]` (0x266b14) and `+[Crypto sha256:]` (0x266c9c) — UTF-8 bytes, UTF-16 count

Both build the buffer they hash the same way, and both get its length from the wrong measure:

```text
100266b6c: bl 0x10027cef0  ; [x19 cStringUsingEncoding:0x4]   -> the UTF-8 bytes
100266b90: bl 0x10027cef0  ; [x19 length]                     -> the UTF-16 character count
100266bb8: bl 0x10027cef0  ; [NSData dataWithBytes:x21 length:x19]
```

The same three, in the same order, sit at 0x266cf4, 0x266d18, and 0x266d40 in `+sha256:`.

`x19` is the same string in both calls, and `w2` is 4, `NSUTF8StringEncoding`. So the pointer is to
a UTF-8 encoding while the count is of UTF-16 code units. The two agree only when every character
is ASCII, which is the only case the method was evidently tested on. For anything else the count is
too small — a string of _n_ Japanese characters yields 3*n* UTF-8 bytes and a length of _n_, so
two-thirds of the input is dropped and the digest is of a truncated prefix that is itself not valid
UTF-8. The correct measure is `-lengthOfBytesUsingEncoding:NSUTF8StringEncoding`.

The consequence is a hash that is stable but wrong: it still returns the same digest for the same
input, so nothing visibly breaks, and any server computing the digest correctly disagrees with it.

`+createHash:` (0x266a44) does not have the fault, because it takes an `NSData` and asks it for its
own `-length`.

### `+[Crypto cryptorToData:value:key:]` (0x266e24) — the key length is a constant

The key argument's own length is never read. `w4` is set from an immediate:

```text
100266f44: mov w4,#0x10
```

so `CCCrypt` is always told the key is sixteen bytes whatever the `NSData` actually holds. A shorter
key is read past its end; a longer one is silently truncated to AES-128. `x5` is likewise zero, so
there is no initialisation vector and the cipher runs in ECB — identical plaintext blocks encrypt to
identical ciphertext blocks.

### `-[DestinationCore destinationRegistWithCountryCode:url:delegate:]` (0x250d24) — a dead delegate

The three-argument method takes a delegate and never reads it. Its arguments arrive in `x2`, `x3`
and `x4`; the prologue saves the first two and not the third:

```text
100250d40: mov x21,x3    ; url
100250d44: mov x22,x2    ; countryCode
100250d48: mov x19,x0    ; self
```

`x4` is never read anywhere in the body — the only appearance of the register is a `mov x4,x21` at
0x250eb8, which writes it. The connection is then handed `self`:

```text
100250f10: mov x3,x19
100250f14: bl 0x10027cef0  ; [ApplilinkURLConnection loadRequestWithRequest:… delegate:x19]
```

So every caller's delegate is silently replaced by the `DestinationCore` itself. That would matter
less if the class did anything with the callbacks, but it does not: `-failLoadWithError:` (0x250f50)
and `-finishLoadWithResponse:` (0x250f54) are each a single `ret`, and `-redirectStartLoad:`
(0x250f58) is `mov w0,#0x0` then `ret`. The registration's outcome is therefore unobservable to
anyone, which is presumably why the discarded argument was never noticed.

### `StoreLeafletCell` (class at 0x350958) — unfinished scaffolding that shipped

Not one defect but a class that was never finished, and four separate pieces of evidence say so
rather than one ambiguous one:

- The button's frame is `{100, 100, 100, 50}` — a constant, with the origin and the width all
  loaded from the same pool slot at 0x28f3f0. The `frame` the initialiser is handed is passed to
  `super` and then never consulted, so the control sits at the same place whatever size the row is.
- The button is a bare `UIButtonTypeCustom` filled with `UIColor.blueColor` and captioned `open`
  (CFString at 0x2e0840, four bytes at 0x2884e9). Nothing else in this tree uses an unmodified
  primary blue.
- `-opendetail` (0x1c5870) asks its delegate to open the literal `@"10001"` (CFString at 0x2e0860,
  five bytes at 0x2884ee). The row holds no pack of its own to substitute.
- The `isPad` ivar is written in the initialiser and never read. `get_xrefs_to` on its offset
  global at 0x34ba40 returns exactly two results binary-wide: the ivar-list entry at 0x324f88 and
  the single write at 0x1c5758.

`-cache:willEvictObject:` (0x1c5928) is a lone `ret`, so the declared `NSCacheDelegate` conformance
does nothing either. `-dealloc` (0x1c592c) is likewise empty — its only instruction is the super
call, which is compiler-emitted, since the class has a `.cxx_destruct` at 0x1c5998 and is therefore
ARC.

The class is reconstructed faithfully, placeholder and all. It is recorded here so a later reader
does not take the hardcoded pack identifier for a reconstruction error.

### `-[StorePromotion getSampleName]` (0x1bd9d8) — the guard its sibling has

`-getSampleURL` (0x1bd954) tests the sample list before indexing it:

```text
1001bd96c: ldr x0,[x8, x9, LSL #0x0]   ; _sampleList
1001bd970: cbz x0,0x1001bd9c4          ; nil -> return nil
```

`-getSampleName` has no equivalent branch. It loads `_sampleList`, loads `playSlot`, and sends
`objectAtIndexedSubscript:` straight away. Messaging nil returns nil twice over, so a genre
promotion — which sets `_sampleList` to nil in its initialiser — gets nil rather than a crash, and
the difference never shows. It is recorded because the two getters are otherwise line-for-line
identical and the asymmetry looks like a reconstruction slip.

Both are exposed to the same real hazard, which the nil guard does not cover: `playSlot` is only
constrained when the list is non-empty, since `-initWithPackInfo:imageURL:sampleURL:` sets it to
zero for an empty list and then both getters index element zero of an empty array. Nothing in the
class prevents that; whether a caller can supply an empty list is not established here.

A near miss worth recording so it is not re-derived: the slot is picked with `rand()` at 0x27cfbc,
**not** `arc4random`, and the modulo is a 32-bit _signed_ `sdiv`/`msub` pair. Had the source been
`arc4random`, whose full 32-bit range makes the signed interpretation negative half the time, the
remainder would have been negative and the sign-extending `ldrsw` in both getters would have turned
it into an enormous `NSUInteger` index. `rand()` returns a non-negative `int`, so the signed modulo
is safe. The instruction selection alone does not tell you that — the imported symbol does.

### `-[ChallengeMissionListCell setTitle:period:]` (0xa9e64) — both labels overhang their background

Each label is placed at `x = bgView.frame.size.height / 2` and given `bgView.frame.size.width` as
its width, so each one's right edge lands half the background's height past the background's right
edge. The two are laid out by the same pair of instructions, once per label:

```text
1000a9f80: fmul d9,d3,d11        ; d9 = bgView height * 0.5   -> becomes the label's x
...
1000a9f9c: bl <[bgView frame]>   ; leaves d2 = bgView width   -> stays in v2 as the width
1000a9fa4: scvtf d3,w8           ; d3 = labelHeight
1000a9fbc: bl <initWithFrame:>   ; (d9, d10, d2, d3)
```

The `x` is not the mistake. `-setIconImage:selectedImage:` (0xaa248) centres the icon horizontally
inside `bgView.frame.size.height / 2` — the same expression — so that value is the icon's column and
starting the text after it is deliberate. What is missing is the matching reduction in width: it
should be the background's width _less_ that column, and it is the full width instead.

Nothing clips it. The labels are subviews of the cell rather than of `bgView`, and a
`UITableViewCell` does not clip by default, so the text simply runs on. Left-aligned text short
enough to fit would never reveal it, which is presumably why it survived.

Both labels are also built once and never re-laid-out: the frame is computed only inside the
`if (!label)` arm, and a later call to the setter reaches `-setText:` alone. A row reused for a
sheet with a period after one without still has its title on the single-line centre.

### `-[LatelyJcfListManager addJcfOwner:]` (0x1e2b14) — the eviction keeps the wrong end

Once the list holds its twenty entries, a new owner overwrites one of them. The scan that picks
which is a straightforward maximum-finder, and the maximum of a set of dates is the _newest_:

```text
1001e2cb4: bl <[chosenDate compare:candidateDate]>
1001e2cb8: cmn x0,#0x1        ; x0 + 1
1001e2cbc: b.ne 0x1001e2ce0   ; skip unless x0 == -1
1001e2cc0: …                  ; adopt candidate as the new chosen entry
```

`cmn x0,#1` is zero exactly when the comparison returned -1, so the adopt arm runs on
`NSOrderedAscending` — that is, when the entry held so far is _earlier_ than the candidate. Each
iteration therefore moves the choice towards the later date, and the index handed to
`replaceObjectAtIndex:` at 0x1e2d18 is the newest entry's. For a list whose whole purpose is
recency, the entry that should survive is the one that gets thrown away.

The list is not sorted anywhere in the class, so position does not stand in for age either: entries
are appended in arrival order below the cap and then overwritten in place, which scrambles it.

### `-[LatelyJcfListManager addJcfOwner:]` (0x1e2b14) — the duplicate check has two holes

The same method is meant to avoid recording an owner twice, and the check misses in two ways.

It only exists on the full path. Below twenty entries the method runs straight from building the
entry to `[list addObject:]` at 0x1e2d28 with no comparison at all, so the first twenty additions
of the same owner all land.

Even on the full path it starts at index one. Entry zero is read before the loop, but only for its
date, to seed the candidate:

```text
1001e2bec: bl <[list objectAtIndex:0]>
1001e2c08: bl <[… objectAtIndex:1]>   ; its date, not its owner
1001e2bfc: mov w25,#0x1               ; the loop starts here
```

The `isEqualToString:` at 0x1e2c78 is inside the loop, so the owner in slot zero is never compared
against the incoming one.

### `+[EditFileListViewController layerClass]` (0x208318) — a `UIView` hook on a view controller

The method returns `CAGradientLayer` and is never called. `+layerClass` is a `UIView` class method;
UIKit asks a _view_ for the class of the layer to back it with, and never asks a view controller.
This class derives from `UITableViewController` — confirmed from the dyld bind at its superclass
slot 0x351770 — so nothing consults it.

Worth recording for two reasons. The pattern is widespread in this binary: `CAGradientLayer`'s
classref at 0x348488 has twenty-six cross-references, split between `+layerClass` and `-loadView`
implementations, and most of those belong to real `UIView` subclasses where the override does work.
This one is the odd member of that set.

And the obvious guess is wrong. An OpenGL application overriding `+layerClass` almost always returns
`CAEAGLLayer` — which is exactly what the sibling tree's `neGLView` does — so reading the idiom
rather than the classref would have produced a plausible, checkable-looking, incorrect line. The
class object at 0x38a500 is `CAGradientLayer`.

### `-[HoldMarkerRender renderHoldLine:…addLength:]` (0xe7eb8) — an unguarded default

The tail's rectangle is built in one of four arms selected by `vector`, and the range check does not
protect the draw:

```text
1000e7f14: cmp w2,#0x3
1000e7f18: b.hi 0x1000e8038   ; out of range -> straight to the draw
1000e7f24: ldrsw x10,[x11, x10, LSL #0x2]
1000e7f2c: br x10             ; 0..3 -> the four arms
```

0xe8038 is the draw itself, not a return. The four values the rectangle is assembled in — `d12`,
`d9`, `d10` and `d11` — are callee-saved, and on the out-of-range path only `d9` has been written
(it holds the first point's `y`, saved at entry). The other three still hold whatever the caller
left in them, and they go to `-drawSprite:inRect:transform:alpha:` as a width, a height and an `x`.

So a `vector` outside 0–3 does not draw nothing; it draws the sprite at an arbitrary rectangle. The
reconstruction reproduces this by leaving the `CGRect` uninitialised on the default arm.

The jump table at 0xe8094 was read rather than inferred: its four entries are -356, -288, -220 and
-156 relative to the table's own address, landing on 0xe7f30, 0xe7f74, 0xe7fb8 and 0xe7ff8 — the
four blocks in source order, with no tail sharing this time.

### `-[TuneInfo infoDict]` (0x775d0) — one of three optional strings is unguarded

The method copies three string properties into a dictionary. Two are tested first and one is not:

```text
1000777c0: cbz x23,0x1000777fc   ; nameYomi nil -> skip
100077820: cbz x23,0x10007785c   ; artist   nil -> skip
100077790: bl <[dict setObject:name forKey:@"Name"]>   ; no test at all
```

`-setObject:forKey:` raises on a nil object, so a `TuneInfo` whose `Name` key was missing from the
catalogue reaches `-infoDict` and throws. The initialiser does nothing to prevent that: it assigns
`[dictionary objectForKey:@"Name"]` straight through, nil included.

### `-[TuneInfo compareYomi:]` (0x779c4) — the fallback sorts the other way

When both tunes have a reading the order is `-localizedCaseInsensitiveCompare:`, which is ascending.
When neither does, the method falls back to the identifier and reverses:

```text
100077ac4: cmp w22,w0
100077ac8: b.ls 0x100077ad4
100077acc: mov x20,#-0x1        ; self.tuneID > other.tuneID -> NSOrderedAscending
```

A larger identifier sorts _first_. Both comparisons are unsigned, matching the property's `I`
encoding, so this is a deliberate reversal rather than a sign error. It only shows for a pair of
tunes that both lack a reading, which is presumably why it survived.

### `-[CampaignItemInfo initWithDictionary:]` (0xbca0) — four URL fields, three levels of checking

The entry carries four URL-shaped strings and each is treated differently:

| Key            | Where from       | Checked                         | Stored as  |
| -------------- | ---------------- | ------------------------------- | ---------- |
| `bannerUrl`    | nested `v2`      | not at all                      | `NSString` |
| `iconUrl`      | nested `v2`      | `+[StoreUtil isValidURL:]`      | `NSString` |
| `thumbnailUrl` | nested `v2`      | `+[StoreUtil isValidURL:]`      | `NSURL`    |
| `foreignUrl`   | the entry itself | `isValidURL:` **and** `-length` | `NSURL`    |

The extra length test on `foreignUrl` is a genuine short-circuit pair, not one call:

```text
10000be4c: cbz w0,0x10000be9c    ; !isValidURL -> skip
10000be5c: bl <[foreignURL length]>
10000be60: cbz x0,0x10000be9c    ; length == 0 -> skip
```

Whether the difference matters depends on what `+isValidURL:` does with an empty string, which is
not reconstructed yet — but the author evidently did not trust it to, on one field out of four.
`bannerUrl` is not checked at all, so an empty or malformed banner address reaches the UI as-is.

`hideType` is read from the entry here and then set back to zero by `-termCheck` — but only on the
unlocked path. A locked item keeps whatever the entry said, an unlocked one always reports zero, so
the field only ever carries the entry's value for items the player cannot have.

### `-[SEManager play:]` (0x790ec) — the one unlocked access to a locked set

Four of the class's five real methods bracket their use of `playingSEs` with `objc_sync_enter` /
`objc_sync_exit` on the set itself. `-play:` does not:

```text
100079128: bl <[player setDelegate:self]>
100079144: bl <[playingSEs addObject:player]>   ; no objc_sync_enter anywhere in this method
```

The lock is not decorative — `-audioPlayerDidFinishPlaying:successfully:` and
`-audioPlayerBeginInterruption:` are delegate callbacks, which is exactly the case the locking is
for. `-play:` mutates the same set from whichever thread starts a sound.

Two smaller asymmetries in the same class. `-audioPlayerDidFinishPlaying:successfully:` never reads
its `successfully` flag, so a player that failed leaves the set by the same path as one that
finished. And `-audioPlayerDecodeErrorDidOccur:error:` (0x79380) is a lone `ret`, so a decode
failure is the one way a player can stay in the set for good — every other exit removes it.

### `RotateStoreProductViewController` (class at 0x352898) — three overrides that add nothing

`-initWithNibName:bundle:` (0x274c34), `-viewDidLoad` (0x274cac) and `-didReceiveMemoryWarning`
(0x274ce8) each contain a single `objc_msgSendSuper2` call and nothing else — no ivar access, no
other message send, no constant. They are behaviourally identical to not overriding at all.

The class's reason to exist is the other three members: `-shouldAutorotate` and
`-shouldAutorotateToInterfaceOrientation:` both return YES unconditionally, and
`-supportedInterfaceOrientations` returns 0x1e, which is `UIInterfaceOrientationMaskAll`. Subclassing
`SKStoreProductViewController` purely to unlock its rotation is the whole point; the other three
appear to be template leftovers.

### `-[BFCodec cipherInit:length:]` (0x949e0) — the chaining vector is a literal

Every call to this method writes the same eight bytes into `_iv`, immediate by immediate:

```text
100094a18: mov  w9,#0xe3
100094a1c: strb w9,[x8]              ; _iv[0]
100094a20: mov  w9,#0x2cda0000
100094a24: movk w9,#0x3166
100094a28: stur w9,[x8, #0x1]        ; _iv[1..4] = DA 2C 66 31
100094a2c: mov  w9,#0xa085
100094a30: sturh w9,[x8, #0x5]       ; _iv[5..6] = 85 A0
100094a34: mov  w9,#0x64
100094a38: strb w9,[x8, #0x7]        ; _iv[7]
```

So the CBC initialisation vector is `E3 DA 2C 66 31 85 A0 64`, fixed in the code and reset on every
key change. It does not depend on the key, on the buffer, or on anything the caller supplies, and it
is not stored alongside the ciphertext because it does not need to be — it is the same every time.

Two buffers encrypted under the same key therefore chain from the same place, so identical
plaintext prefixes produce identical ciphertext prefixes. `-cipherInit:` has 189 cross-references,
so this applies to essentially every encrypted asset and request in the application.

This is recorded as a property of the shipped binary, not as something to change. It is exactly the
kind of detail a reconstruction is for: invisible in the class's interface, and only findable by
reading what the initialiser stores.

### `-[ApplilinkIndicator close]` (0x250284) — the spinner is abandoned, not removed

`-close` stops the spinner and then clears the ivar without taking the view out of the hierarchy:

```text
1002502c4: bl <[_indicator stopAnimating]>
1002502c8: ldr x0,[x19, x20, LSL #0x0]   ; the old spinner
1002502cc: str xzr,[x19, x20, LSL #0x0]  ; _indicator = nil
1002502d8: b  <objc_release>             ; …and released
```

There is no `-removeFromSuperview` anywhere in the class, so the `UIActivityIndicatorView` stays a
subview of the sheet, held only by the superview's own array. Nothing can reach it again.

That makes `-close` one-way. `-show` afterwards un-hides the sheet but its `if (self.indicator)`
guard fails, so no spinner starts, and `-layoutSubviews` skips positioning for the same reason —
leaving a dimmed black sheet with a stationary spinner on it, which is the opposite of what the
method names suggest.

`-touchEventActived` is the escape from that: it clears the background colour and sets
`userInteractionEnabled` to **NO**, so the sheet stops dimming and stops swallowing touches. The
name reads as enabling something and what it does is disable this view's own handling.

### `-[NotificationPageNavController init:]` (0x182b8c) — an object passed where a `BOOL` is wanted

Two iOS 7 properties are set through `-performSelector:withObject:` behind `-respondsToSelector:`
guards, which is the ordinary way to touch a newer API from an older SDK. The two calls do not pass
the same kind of thing:

```text
100182ca4: mov x3,#0x0    ; setExtendedLayoutIncludesOpaqueBars: withObject:nil
…
100182cd8: mov x3,x20     ; setAutomaticallyAdjustsScrollViewInsets: withObject:self
```

`-setAutomaticallyAdjustsScrollViewInsets:` takes a `BOOL`. Under `-performSelector:withObject:` the
object pointer lands in `x2` and the setter reads its low byte, so the flag ends up as
`(char)(uintptr_t)self` — the _address_ of the controller, truncated.

Objects are sixteen-byte aligned, so that byte is one of `0x00, 0x10, …, 0xF0`. Fifteen times in
sixteen it is non-zero and the property comes out YES, which is presumably what was meant. One time
in sixteen the allocation lands on a 256-byte boundary and it comes out NO, and the page's scroll
view is laid out differently for no reason the code expresses.

The nil in the first call is the same idiom used correctly: nil is a reliable NO. There is no
literal that gives a reliable YES this way, which is the trap — `-performSelector:withObject:` cannot
pass a scalar, and the author appears to have reached for the nearest non-nil object.

### `-[LogoViewController fireAnimation]` (0x828ec) — the age notice never fades out

The splash is a state machine that runs one animation per call and passes itself as that
animation's completion. One of its eight arms cannot run, and it is the fade-out of the age-rating
notice.

The method opens with `cmp w8, #0x7` / `b.cc` at 0x82918, so anything from 7 upwards skips the
switch entirely and goes to the branch that arms the end timer. The switch is therefore only ever
entered with a value of 0 through 6. Its own bound is `cmp w8, #0x7` / `b.hi` at 0x82a2c and the
jump table at 0x82df8 has eight entries, so the compiler emitted an arm for 7 that no path reaches.
That arm — at 0x82d04, block at 0x82f90 — sets the notice's alpha back to 0 and steps to 8. The
only writer of 7 is step 5 (`orr w8, wzr, #0x7` at 0x82c9c), and the guard catches it on the way
back in.

The visible consequence is that the age-rating notice fades in over half a second and then stays at
full opacity until `-end:` tears the whole controller down three seconds later. Whether that is the
intent or a missed step is not decidable from the binary; what is decidable is that the code to fade
it out was written, compiled, and cannot execute.

This was read from the jump table's bytes rather than inferred from the branch structure. The
decompile presents a `case 7` alongside a guard that excludes it and gives no hint that the two
disagree.

**Correction.** This entry first claimed the arm for step 6 was dead too, on the reasoning that
nothing writes 6. That was wrong, and reading `-handleTap:` (0x8314c) is what disproved it:
`orr w8, wzr, #0x6` at 0x831c4 writes exactly that value. The arm is not dead but load-bearing.
When a tap interrupts either BEMANI logo step, `-handleTap:` strips the layer's animations and
parks the sequence on 6 before running its own fade; the interrupted animation's completion still
fires and calls `-fireAnimation`, which lands on the step-6 arm and does nothing. Its table entry
points at 0x82dd4 — the epilogue — because doing nothing is the whole job. The tap's own completion
then sets 5 and rejoins the sequence at the age notice's fade in.

The lesson is narrower than "verify more". Reachability is not a property of one routine: a value
absent from every write in the method that switches on it can still arrive from a sibling. The
first reading had examined every writer inside `-fireAnimation` and `-start` and stopped there.

### `LogoViewController` (class at 0x34d3e8) — `eventDownloader` is never cleaned up

The splash owns three `Downloader` ivars and treats one of them differently in all three places
that matter. `-viewDidUnload` (0x8335c) cancels `knitBgDownloader` and `imageDownloader` and clears
both, and does not touch `eventDownloader`. `-downloaderError:` (0x83c90) clears the same two and
again omits it. `-downloaderFinished:` (0x83598) clears `knitBgDownloader` and `imageDownloader` on
their branches, and its `eventDownloader` branch ends without clearing.

That is three independent sites agreeing, which is what rules out a misread. It was worth ruling
out: `imageDownloader` really is created later than the other two — only in `-downloaderFinished:`,
when the campaign banner is not already cached — so an early reading of `-viewDidUnload` alone
could plausibly have been "the third one does not exist yet". `-loadView` (0x8244c) disproves that.
It creates `eventDownloader` immediately after `knitBgDownloader` and starts it the same way.

The consequence is bounded rather than serious. The ivar is strong, so the request survives
`-viewDidUnload` and is only released when the controller is deallocated, and its completion
handler writes to the app delegate rather than to any view. A response arriving after the splash
has gone will still switch the app into hinabita or NagaCora mode, which is very likely what was
wanted; nothing observable leaks. It is recorded because the asymmetry is deliberate-looking and a
later reader should not "fix" it.

## Settled

Kept as a record of what the evidence was, so a later reader does not have to re-derive it.

| Declaration                              | Was                | Now                  | Proven by                                                                                                                                                            |
| ---------------------------------------- | ------------------ | -------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `JubeatAppDelegate.deviceType`           | `id`               | `NSInteger`          | the four idiom predicates compare it against 1 to 7.                                                                                                                 |
| `JubeatAppDelegate.currentTheme`         | `int`              | `unsigned int`       | `-changeTheme:` boxes it with `+numberWithUnsignedInt:`.                                                                                                             |
| `JubeatAppDelegate.rootViewCtrl`         | `UIViewController` | `RootViewController` | `-changeTheme:` sends `-changeThemeAndGoTitle`, whose only implementation is `-[RootViewController changeThemeAndGoTitle]` @0x1a8a68.                                |
| `JubeatAppDelegate.pushNotificationList` | `NSArray`          | `NSMutableArray`     | `-loadNotification` stores `-mutableCopy` of the unarchived object at 0xa828.                                                                                        |
| `JubeatAppDelegate.deviceToken`          | `id`               | `NSString`           | `-application:didRegisterForRemoteNotificationsWithDeviceToken:` stores the token's `-description` with `<`, `>`, and spaces stripped.                               |
| `JubeatAppDelegate.remotePushInfo`       | `id`               | `NSDictionary`       | `-application:didFinishLaunchingWithOptions:` stores a `-copy` of `launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey]` at 0x96b0; it is the only writer. |
| `JubeatAppDelegate.deviceType`           | `NSInteger`        | `JubeatDeviceType`   | the classifier at 0x9748-0x97d0 and 0xa180-0xa25c assigns all eight values; see below.                                                                               |

### The `deviceType` enumeration

Settled by disassembling the classifier, which the decompile rendered wrongly — it presented the
scale as re-read per comparison and lost that `d8` holds the scale for the first test and then
`bounds.size.height` (register `v3`) for the second. The real decision is:

| Value | Idiom     | Scale           | `bounds.size.height` |
| ----- | --------- | --------------- | -------------------- |
| 0     | Phone     | neither 2 nor 3 | not consulted        |
| 1     | Phone     | 2               | neither 667 nor 568  |
| 2     | Phone     | 2               | 568                  |
| 3     | Phone     | 2               | 667                  |
| 4     | Phone     | 3               | 667                  |
| 5     | Phone     | 3               | not 667              |
| 6     | not Phone | not 2           | not consulted        |
| 7     | not Phone | 2               | not consulted        |

The two heights are the pooled doubles at 0x28dfd0 and 0x28dfd8, decoded from memory as 667.0 and
568.0 rather than guessed.

This also explains `is4inchAspect`, which was the odd one of the four predicates: it accepts 2
through 5, and the table shows those are exactly the 16:9 screens. The predicate's name is the
binary's own idea, not a claim that all four devices are four inches.
