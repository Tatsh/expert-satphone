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
| `deviceToken`       | `-application:didRegisterForRemoteNotificationsWithDeviceToken:` @0xa8a4 | Object by load width only.                     |
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
| `-[JubeatAppDelegate musicListKey]`      | `+clientInfo` sends it                | 0x8814    |
| `CreateMd5HexStringFromCString`          | `+clientInfo` calls it                | 0x7f168   |
| `-[RootViewController changeThemeAndGoTitle]` | `-changeTheme:` sends it         | 0x1a8a68  |
| `-[RootViewController changeTitleTheme]` | `-switchTitleEvent` sends it          | not located yet |
| `-[RootViewController reloadMarkers]`    | `-enableCopiousMarkers` sends it      | not located yet |
| `-[KnitColorManager setColorWithArray:]` | `-setKnitColor:` sends it             | not located yet |
| `-[KnitColorManager setColorWithType:]`  | `-switchTitleEvent` sends it          | not located yet |
| `-[ChallengeStatus createCoinNotification]` | `-applicationDidEnterBackground:` sends it | not located yet |
| `-[PurchaseManager end]`                 | `-applicationWillTerminate:` sends it | not located yet |
| `-[ScoreRecordManager saveRecords]`      | `-applicationWillTerminate:` sends it | not located yet |

## Settled

Kept as a record of what the evidence was, so a later reader does not have to re-derive it.

| Declaration                      | Was          | Now                    | Proven by                                                |
| -------------------------------- | ------------ | ---------------------- | -------------------------------------------------------- |
| `JubeatAppDelegate.deviceType`   | `id`         | `NSInteger`            | the four idiom predicates compare it against 1 to 7.     |
| `JubeatAppDelegate.currentTheme` | `int`        | `unsigned int`         | `-changeTheme:` boxes it with `+numberWithUnsignedInt:`. |
| `JubeatAppDelegate.rootViewCtrl` | `UIViewController` | `RootViewController` | `-changeTheme:` sends `-changeThemeAndGoTitle`, whose only implementation is `-[RootViewController changeThemeAndGoTitle]` @0x1a8a68. |
| `JubeatAppDelegate.pushNotificationList` | `NSArray` | `NSMutableArray` | `-loadNotification` stores `-mutableCopy` of the unarchived object at 0xa828. |
