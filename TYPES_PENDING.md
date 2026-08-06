# Pending types

Every declaration in this tree that is still typed `id` because the binary has not yet proven a
concrete class. Nothing may stay `id` permanently: `id` here means "not established yet", never "the
binary really is dynamic".

This file exists because a placeholder type is easy to lose. `JubeatAppDelegate.deviceType` was
typed `id` on the strength of its getter loading a 64-bit word, and turned out to be an `NSInteger`
— the four device-idiom predicates load the same ivar and compare it against the constants 1 to 7.
A wrong type that compiles is exactly the kind of defect the reconstruction rules warn about, so
each entry below names the routine whose reconstruction will settle it.

## Rules

- Add a row the moment a declaration is written as `id`.
- Remove the row in the same commit that replaces `id` with the real type.
- A row whose evidence column says "proven" but is still `id` is a bug, not a pending item.

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
| `remotePushInfo`    | `-application:didReceiveRemoteNotification:` @0xb0c8              | Object by load width only.                              |

## Types weakened rather than `id`

These are not `id`, but are less specific than the binary may allow and should be revisited.

| Declaration                             | Weakened to        | Settled by                                        |
| --------------------------------------- | ------------------ | ------------------------------------------------- |
| `JubeatAppDelegate.deviceType`          | `NSInteger`        | the writer, which will give the enumeration its case names |
| `KnitColorManager.setColorWithArray:`   | `NSArray`          | the manager's own body; the delegate passes its argument straight through |

## Declared without a body

A declaration written because a reconstructed caller sends it, whose own body is not recovered yet.
The tree does not compile as a unit until these are filled in, which is deliberate: a stub body
would be indistinguishable from a reconstructed one.

| Declaration                              | Why it is declared                    | Body at   |
| ---------------------------------------- | ------------------------------------- | --------- |
| `CreateMd5HexStringFromCString`          | `+clientInfo` calls it                | 0x7f168   |
| `-[RootViewController changeThemeAndGoTitle]` | `-changeTheme:` sends it         | 0x1a8a68  |
| `-[RootViewController changeTitleTheme]` | `-switchTitleEvent` sends it          | not located yet |
| `-[RootViewController reloadMarkers]`    | `-enableCopiousMarkers` sends it      | not located yet |
| `-[KnitColorManager setColorWithArray:]` | `-setKnitColor:` sends it             | not located yet |
| `-[KnitColorManager setColorWithType:]`  | `-switchTitleEvent` sends it          | not located yet |
| `-[ChallengeStatus createCoinNotification]` | `-applicationDidEnterBackground:` sends it | not located yet |
| `-[PurchaseManager end]`                 | `-applicationWillTerminate:` sends it | not located yet |
| `-[ScoreRecordManager saveRecords]`      | `-applicationWillTerminate:` sends it | not located yet |

## Fully disassembled, body withheld

### `-application:handleOpenURL:` (0x9090)

Read in full — all 171 instructions — and every selector and literal resolved. The body is **not**
written because the control flow contains something that reads as a defect in the binary, and
writing it either way would be asserting an answer this pass has not earned.

The recovered flow:

1. Return `YES` immediately unless `url.scheme` equals `"jubeatplus"` (0x2d40e0). Every path
   returns `YES`; the method never reports a URL as unhandled.
2. `tail = [[NSString stringWithFormat:@"%@", url] substringFromIndex:13]`. The 13 is an immediate
   at 0x9134 and matches the length of `"jubeatplus://"`.
3. `components = url.pathComponents`; the rest runs only when `components.count == 3`.
4. `components[1]` is compared against `"jbtstore"` (0x2d4380) at 0x91ac.
5. **Inside that arm**, `components[1]` is fetched *again* at 0x91e0 and compared against `"pack"`
   (0x2d43c0) and `"genre"` (0x2d43e0), storing `components[2]` into `_storePackID` or
   `_storeGenreID` respectively.
6. Independently, `components[1]` is compared against `"jbtgift"` (0x2d43a0); on a match
   `components[2]` is stored into `_storeCampaignID`.
7. Finally, `if ([self digitStringCheck:tail])` stores `tail` into `_jcfDownloadID`.

**The open question is step 5.** It re-reads index 1, which step 4 has just proven equals
`"jbtstore"`, so both inner comparisons look permanently false and the pack and genre stores look
unreachable. That is either a real bug in the shipped binary or a misreading of the index register.
The register is `w2 = #0x1` at 0x91e0 with `x1 = objectAtIndex:`, the same pair as step 4, so the
instructions are not in doubt — what is in doubt is whether the conclusion is right.

Resolving it needs the callers: what URL shapes actually reach this method. Until then no body is
written, because a reconstruction that silently "fixed" the index to 2 would be a different program,
and one that copied it without comment would hide a defect.

## Settled

Kept as a record of what the evidence was, so a later reader does not have to re-derive it.

| Declaration                      | Was          | Now                    | Proven by                                                |
| -------------------------------- | ------------ | ---------------------- | -------------------------------------------------------- |
| `JubeatAppDelegate.deviceType`   | `id`         | `NSInteger`            | the four idiom predicates compare it against 1 to 7.     |
| `JubeatAppDelegate.currentTheme` | `int`        | `unsigned int`         | `-changeTheme:` boxes it with `+numberWithUnsignedInt:`. |
| `JubeatAppDelegate.rootViewCtrl` | `UIViewController` | `RootViewController` | `-changeTheme:` sends `-changeThemeAndGoTitle`, whose only implementation is `-[RootViewController changeThemeAndGoTitle]` @0x1a8a68. |
| `JubeatAppDelegate.pushNotificationList` | `NSArray` | `NSMutableArray` | `-loadNotification` stores `-mutableCopy` of the unarchived object at 0xa828. |
| `JubeatAppDelegate.deviceToken` | `id` | `NSString` | `-application:didRegisterForRemoteNotificationsWithDeviceToken:` stores the token's `-description` with `<`, `>`, and spaces stripped. |
