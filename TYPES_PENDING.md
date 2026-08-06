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
| `addresses` | Real. 77 method annotations checked against the runtime metadata. |
| `literals` | Nearly vacuous. It skips any literal with no character above U+0x2000, so it checks the two Japanese strings in `ChallengeStatus.m` and nothing else. Selector checking covers `@selector()` only; the tree now has two, both verified present. |
| `globals` | Vacuous. No annotated global initialisers here yet. |
| `unwritten-members` | Vacuous. It looks for C++ `m_` members, and this tree has none yet. |

So a clean run is necessary and nowhere near sufficient, and only the `addresses` number means
anything today.

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
| `RootViewController.editViewCtrl`       | `UIViewController` | as above. It responds to the same `-loadResources`/`-startAnimation`/`-terminate`/`-releaseResources` set as `gameViewCtrl`, so the two share an interface |
| `KnitColorManager.setColorWithArray:`   | `NSArray`          | the manager's own body; the delegate passes its argument straight through |

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
| `-[RootViewController fadeinAnimStop:finished:context:]` | the dispatcher installs it as the animation-stop selector | not located yet |
| `-[RootViewController createKnitTitleViewController]` | the theme switch sends it for theme 2 | not located yet |
| `-[RootViewController titleSwitch]`      | the dispatcher sends it for "AnimTitleSwitch" | not located yet |
| `-[AudioManager stopAllSe]`              | the dispatcher sends it                | not located yet |
| `-[AudioManager releaseBgm:]`            | the dispatcher sends it                | not located yet |
| `+[AudioManager sharedManager]`          | the dispatcher sends it                | not located yet |
| `+[ImageCache sharedCache]`              | the dispatcher sends it                | not located yet |
| `-[ImageCache clear]`                    | the dispatcher sends it                | not located yet |
| `-[MusicSelectViewController startMainBgm]` | the dispatcher sends it             | not located yet |
| `-[MusicSelectViewController stopStoreInfo]` | the dispatcher sends it            | not located yet |
| `-[MusicSelectViewController reloadMarkerSelectView]` | `-reloadMarkers` sends it | not located yet |
| `-[MusicSelectViewController pushNotificate]` | `-pushNotificate` forwards to it | not located yet |
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

## Defects found in the binary

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
