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
| `RootViewController.musicSelectViewCtrl` | `UIViewController` | whatever constructs it; it responds to `-reloadMarkerSelectView`, which `UIViewController` does not declare |
| `KnitColorManager.setColorWithArray:`   | `NSArray`          | the manager's own body; the delegate passes its argument straight through |

## Declared without a body

A declaration written because a reconstructed caller sends it, whose own body is not recovered yet.
The tree does not compile as a unit until these are filled in, which is deliberate: a stub body
would be indistinguishable from a reconstructed one.

| Declaration                              | Why it is declared                    | Body at   |
| ---------------------------------------- | ------------------------------------- | --------- |
| `-[RootViewController fade:durationIn:durationOut:]` | all three reconstructed methods send it | not located yet |
| `-[UIViewController reloadMarkerSelectView]` | `-reloadMarkers` sends it        | not located yet |
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
| `-[RootViewController pushNotificate]`   | `-application:didReceiveLocalNotification:` sends it | 0x1aaaa4 |
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

## Settled

Kept as a record of what the evidence was, so a later reader does not have to re-derive it.

| Declaration                      | Was          | Now                    | Proven by                                                |
| -------------------------------- | ------------ | ---------------------- | -------------------------------------------------------- |
| `JubeatAppDelegate.deviceType`   | `id`         | `NSInteger`            | the four idiom predicates compare it against 1 to 7.     |
| `JubeatAppDelegate.currentTheme` | `int`        | `unsigned int`         | `-changeTheme:` boxes it with `+numberWithUnsignedInt:`. |
| `JubeatAppDelegate.rootViewCtrl` | `UIViewController` | `RootViewController` | `-changeTheme:` sends `-changeThemeAndGoTitle`, whose only implementation is `-[RootViewController changeThemeAndGoTitle]` @0x1a8a68. |
| `JubeatAppDelegate.pushNotificationList` | `NSArray` | `NSMutableArray` | `-loadNotification` stores `-mutableCopy` of the unarchived object at 0xa828. |
| `JubeatAppDelegate.deviceToken` | `id` | `NSString` | `-application:didRegisterForRemoteNotificationsWithDeviceToken:` stores the token's `-description` with `<`, `>`, and spaces stripped. |
