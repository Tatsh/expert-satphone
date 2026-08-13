#import "JubeatAppDelegate.h"

#include <stdlib.h>
#include <sys/sysctl.h>

#import <AVFoundation/AVFoundation.h>
#import <GameKit/GameKit.h>
#import <Security/Security.h>

#import "ApplilinkNetwork.h"
#import "ChallengeStatus.h"
#import "EditorIDManager.h"
#import "KnitColorManager.h"
#import "LabUtilities.h"
#import "MarkerManager.h"
#import "Md5Utilities.h"
#import "PurchaseManager.h"
#import "RootViewController.h"
#import "ScoreRecordManager.h"
#import "StoreMusicListManager.h"
#import "TweetResourceManager.h"

// The window the delegate builds at launch. It has no accessor pair in either accessor block, and
// its ivar offset global at 0x349660 is named without the leading underscore the synthesised ones
// carry, so it was declared directly rather than as a property.
@interface JubeatAppDelegate () {
    UIWindow *mainWindow;
}
@end

// The bundled plist +initialize seeds NSUserDefaults from, at 0x2d4140 and 0x2d4160.
static NSString *const kDefaultSettingsResourceName = @"DefaultSettings";
static NSString *const kPropertyListResourceType = @"plist";

// The applilink SDK credentials, from the one-character CFStrings at 0x2d4120 and 0x2d4100. Their
// bytes are at 0x27dc3c and 0x27dc3a; the template tree documents env "0" through "4".
static NSString *const kApplilinkApplicationID = @"3";
static NSString *const kApplilinkEnvironment = @"0";

// The sysctl name the binary passes to sysctlbyname, embedded at 0x27dc6d.
static const char *const kHardwareMachineSysctlName = "hw.machine";

// The version string the binary embeds at 0x27dc66. It is a C string literal compiled into the
// text, not a value read from the bundle.
static const char *const kApplicationVersionString = "3.9.11";

// The licence date the binary hardcodes at 0x2d4300. It is a string literal, not a computed date.
static NSString *const kCurrentLicenseDate = @"2015-04-14 17:00:02";

// The localization key the use-policy message is looked up under, from the CFString at 0x2d4320.
static NSString *const kUsePolicyMessageKey = @"Use policy Message";

// The two total-score leaderboard identifiers, at 0x2d4240 and 0x2d4260.
static NSString *const kTotalScoreLeaderboardCategoryPad = @"jubeat.totalscore";
static NSString *const kTotalScoreLeaderboardCategoryPhone = @"jubeat.totalscorephone";

// The user-defaults key the selected theme is persisted under, from the CFString at 0x2d4280.
static NSString *const kThemePreferenceKey = @"PrefTheme";

// The user-defaults key the copious marker unlock is recorded under, from the CFString at 0x2d42a0.
static NSString *const kCopiousUnlockedPreferenceKey = @"PrefCopiousUnlocked";

// The User-Agent format and the pieces that go into it, from the CFStrings at 0x2d4500, 0x2d44e0,
// 0x2d4520, and 0x2d4540. Six specifiers, matching the six stack slots at 0xa498-0xa4a8.
static NSString *const kUserAgentFormat = @"%@/%@ (%@; iOS %@; %@) [%@]";
static NSString *const kInternalVersionDefaultsKey = @"internal_version";
static NSString *const kSystemVersionSeparator = @".";
static NSString *const kUserAgentVersionSeparator = @"_";

// The custom URL scheme and the path vocabulary -application:handleOpenURL: routes on, from the
// CFStrings at 0x2d40e0, 0x2d4380, 0x2d43a0, 0x2d43c0, and 0x2d43e0.
static NSString *const kJubeatURLScheme = @"jubeatplus";
// Each of these appears in two roles. In a notification URL it is the scheme, which is how
// -application:didReceiveLocalNotification: reads it. In a jubeatplus:// URL it is meant to be the
// host, which is what -application:handleOpenURL: fails to read. Same CFStrings in both places.
static NSString *const kStoreURLScheme = @"jbtstore";
static NSString *const kGiftURLScheme = @"jbtgift";
static NSString *const kChallengeURLScheme = @"jbtchallenge";
static NSString *const kStorePackPathComponent = @"pack";
static NSString *const kStoreGenrePathComponent = @"genre";

// The length of "jubeatplus://", an immediate at 0x9134.
static const NSUInteger kJubeatURLSchemePrefixLength = 13;

// The handler only routes a URL with exactly this many path components, tested at 0x9174.
static const NSUInteger kHandledURLPathComponentCount = 3;

// The keychain account the per-install identifier is stored under, from the CFString at 0x2d42c0.
// Its name says what the value really is, unlike the -musicListKey selector that returns it.
static NSString *const kKeychainAccountName = @"ApplicationUniqueID";

// The salt appended to the music-list key before hashing, from the CFString at 0x2d4180.
static NSString *const kClientInfoUuidSalt = @"STORE";

// The five keys of the client-info dictionary, from the CFStrings at 0x2d41a0 through 0x2d4220.
static NSString *const kClientInfoUuidKey = @"uuid";
static NSString *const kClientInfoVersionKey = @"version";
static NSString *const kClientInfoDeviceKey = @"device";
static NSString *const kClientInfoOsKey = @"os";
static NSString *const kClientInfoLocaleKey = @"locale";

// The digit set -digitStringCheck: accepts, from the CFString at 0x2d4340. The binary spells the
// digits out rather than using NSCharacterSet.decimalDigitCharacterSet.
static NSString *const kDecimalDigitCharacters = @"0123456789";

// The knit-colour palette type the hinabita collaboration selects, a bare immediate at 0x86d4.
static const int kHinabitaKnitColorType = 4;

// The APNs payload keys -apsDictionary: reads and writes, from the CFStrings at 0x2d4600, 0x2d4620,
// 0x2d4640, 0x2d4660, 0x2d4400, 0x2d4680, and 0x2d46a0.
static NSString *const kApsPayloadKey = @"aps";
static NSString *const kApsAlertKey = @"alert";
static NSString *const kNotificationBodyKey = @"body";
static NSString *const kNotificationSoundKey = @"sound";
static NSString *const kNotificationURLKey = @"url";
static NSString *const kNotificationIdentifierKey = @"id";

// The key each queued notification stores its fire time under, from the CFString at 0x2d4680.
static NSString *const kNotificationExpireKey = @"expire";

// The two path components of the persisted notification queue, at 0x2d4560 and 0x2d4580.
static NSString *const kNotificationDirectoryName = @"notification";
static NSString *const kNotificationFileName = @"noti.txt";

// The Game Center error code the authentication handler treats as fatal, compared as the immediate
// 16 at 0x84f0. That is GKErrorNotSupported; the binary spells it as a bare number.
static const NSInteger kGameCenterNotSupportedErrorCode = 16;

// The two span widths the idiom predicates at 0x82dc and 0x82f8 use. Both predicates subtract a
// JubeatDeviceType and then do an unsigned compare, so these are counts rather than device types
// and have no enumerator of their own.
static const NSUInteger kPhoneRetinaDeviceTypeCount = 5;
static const NSUInteger k4inchAspectDeviceTypeCount = 4;

// The two screen heights the launch handler classifies on, the pooled doubles at 0x28dfd0 and
// 0x28dfd8. Compared with fcmp against UIScreen.bounds.size.height, which arrives in d3.
static const CGFloat kScreenHeight47Inch = 667.0;
static const CGFloat kScreenHeight4Inch = 568.0;

// The two screen scales the launch handler classifies on, both fmov immediates.
static const CGFloat kRetinaScreenScale = 2.0;
static const CGFloat kRetinaHDScreenScale = 3.0;

// The class the Game Center probe looks up by name, from the CFString at 0x2d4440. Its absence is
// the only thing that clears gameCenterAvailable.
static NSString *const kGameCenterLocalPlayerClassName = @"GKLocalPlayer";

// The three further user-defaults keys the launch handler touches, from the CFStrings at 0x2d4460,
// 0x2d4480, and 0x2d44a0. The lower-case "j" in the last one is the binary's spelling.
static NSString *const kAdjustSectorPreferenceKey = @"PrefAdjustSector";
static NSString *const kTwitterBackgroundFramePreferenceKey = @"PrefTwitterBgFrame";
static NSString *const kLabURLPreferenceKey = @"PrefjubeatLabURL";

// The plaintext CreateLabEncryptedData is given on first launch, from the CFString at 0x2d44c0
// whose 62 bytes live at 0x27ddc3. The encrypted form is what gets persisted.
static NSString *const kLabURL = @"https://jubeat-lab.s.game.konami.jp/aqq/contents/ios/index.jsp";

// The audio session parameters, the pooled doubles at 0x28dfe0 and 0x28dfe8.
static const double kPreferredSampleRate = 44100.0;
static const NSTimeInterval kPreferredIOBufferDuration = 0.01;

// The theme written back to user defaults when the stored one is missing or out of range, boxed
// with +numberWithInt: at 0x9884 and 0x98f4.
static const int kDefaultTheme = 0;

@implementation JubeatAppDelegate

#pragma mark - Class setup

/** @ghidraAddress 0x7b60 */
+ (void)initialize {
    // Seeds NSUserDefaults from a bundled plist before anything reads a preference. This is why the
    // launch handler's "missing key" paths are rarely taken in practice.
    NSString *path = [NSBundle.mainBundle pathForResource:kDefaultSettingsResourceName
                                                   ofType:kPropertyListResourceType];
    NSDictionary *defaults = [NSDictionary dictionaryWithContentsOfFile:path];
    // Guarded, so a missing or unreadable plist is silently tolerated.
    if (defaults != nil) {
        [NSUserDefaults.standardUserDefaults registerDefaults:defaults];
    }

    [ApplilinkNetwork initializeWithAppliId:kApplilinkApplicationID
                                        env:kApplilinkEnvironment
                                   callback:^(NSError *error) {
                                     /** @ghidraAddress 0x7c68 */
                                     // A global block: it captures nothing, which is why the
                                     // literal at 0x2c8ab0 is a __NSConcreteGlobalBlock with no
                                     // copy or dispose helper.
                                     //
                                     // Returns on any error, so the user identifier is only sent
                                     // once the SDK is up.
                                     if (error != nil) {
                                         return;
                                     }
                                     NSString *editorKey = [EditorIDManager
                                         getKeyString:EditorIDManager.getEditorIDKey];
                                     // A device with no editor identifier yet simply stays
                                     // anonymous to the ad SDK.
                                     if (editorKey != nil) {
                                         [ApplilinkNetwork setUserId:editorKey];
                                     }
                                   }];
}

#pragma mark - Identification

/** @ghidraAddress 0x7cf4 */
+ (JubeatAppDelegate *)appDelegate {
    // The binary forwards -delegate with no class check of its own.
    return (JubeatAppDelegate *)UIApplication.sharedApplication.delegate;
}

/** @ghidraAddress 0x7e58 */
+ (NSString *)appVersion {
    return [[NSString alloc] initWithCString:kApplicationVersionString
                                    encoding:NSUTF8StringEncoding];
}

/** @ghidraAddress 0x805c */
+ (NSDictionary *)clientInfo {
    // Despite the "uuid" key this is not a device identifier: it is the music-list key with a
    // fixed salt appended, hashed.
    NSString *salted =
        [JubeatAppDelegate.appDelegate.musicListKey stringByAppendingString:kClientInfoUuidSalt];
    NSString *uuid = CreateMd5HexStringFromCString(salted.UTF8String);

    // The count of 5 is an immediate in the call, so the slot list below is exact.
    NSString *keys[] = {
        kClientInfoUuidKey,
        kClientInfoVersionKey,
        kClientInfoDeviceKey,
        kClientInfoOsKey,
        kClientInfoLocaleKey,
    };
    NSString *values[] = {
        uuid,
        JubeatAppDelegate.appVersion,
        JubeatAppDelegate.deviceName,
        UIDevice.currentDevice.systemVersion,
        NSLocale.currentLocale.localeIdentifier,
    };
    return [NSDictionary dictionaryWithObjects:values
                                       forKeys:keys
                                         count:sizeof(keys) / sizeof(keys[0])];
}

#pragma mark - Standard directories

/** @ghidraAddress 0x7d50 */
+ (NSString *)appLibraryDirectory {
    return NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)
        .lastObject;
}

/** @ghidraAddress 0x7da8 */
+ (NSString *)appDocumentsDirectory {
    return NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)
        .lastObject;
}

/** @ghidraAddress 0x7e00 */
+ (NSString *)appCachesDirectory {
    return NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).lastObject;
}

/** @ghidraAddress 0x7f78 */
+ (NSString *)deviceName {
    size_t length = 0;
    sysctlbyname(kHardwareMachineSysctlName, nullptr, &length, nullptr, 0);
    if (length == 0) {
        return UIDevice.currentDevice.model;
    }
    char *machine = malloc(length);
    sysctlbyname(kHardwareMachineSysctlName, machine, &length, nullptr, 0);
    NSString *name = [[NSString alloc] initWithCString:machine encoding:NSUTF8StringEncoding];
    free(machine);
    return name;
}

/** @ghidraAddress 0x7e94 */
+ (NSString *)primDeviceName {
    // Yes, this duplicates +deviceName exactly. The binary emits two complete copies of the
    // routine at 0x7e94 and 0x7f78 rather than one calling the other, so both are kept.
    size_t length = 0;
    sysctlbyname(kHardwareMachineSysctlName, nullptr, &length, nullptr, 0);
    if (length == 0) {
        return UIDevice.currentDevice.model;
    }
    char *machine = malloc(length);
    sysctlbyname(kHardwareMachineSysctlName, machine, &length, nullptr, 0);
    NSString *name = [[NSString alloc] initWithCString:machine encoding:NSUTF8StringEncoding];
    free(machine);
    return name;
}

#pragma mark - Game Center

/** @ghidraAddress 0x832c */
- (NSString *)gameCenterName {
    if (!_gameCenterAvailable) {
        return nil;
    }
    GKLocalPlayer *localPlayer = GKLocalPlayer.localPlayer;
    if (!localPlayer.isAuthenticated) {
        return nil;
    }
    return localPlayer.alias;
}

/** @ghidraAddress 0x83bc */
- (void)disableGameCenter {
    _gameCenterAvailable = NO;
}

/** @ghidraAddress 0x83cc */
- (void)loginGameCenter {
    if (!_gameCenterAvailable) {
        return;
    }
    GKLocalPlayer *localPlayer = GKLocalPlayer.localPlayer;
    // Already-authenticated players are left alone; the handler is installed only on the other arm.
    if (localPlayer.isAuthenticated) {
        return;
    }
    [localPlayer setAuthenticateHandler:^(UIViewController *viewController, NSError *error) {
      /** @ghidraAddress 0x848c */
      if (viewController != nil) {
          [self.rootViewCtrl presentViewController:viewController animated:YES completion:nil];
          return;
      }
      // The binary reaches the delegate through +appDelegate here rather than through the self it
      // captured at +0x20, which the presentation arm above does use.
      if (error.code == kGameCenterNotSupportedErrorCode) {
          [JubeatAppDelegate.appDelegate disableGameCenter];
      }
    }];
}

/** @ghidraAddress 0x8550 */
- (NSString *)totalScoreLeaderboardCategory {
    // A csel, not a branch: both literals are materialised and one is selected.
    return self.isPad ? kTotalScoreLeaderboardCategoryPad : kTotalScoreLeaderboardCategoryPhone;
}

#pragma mark - Presentation mutators

/** @ghidraAddress 0x8584 */
- (void)changeTheme:(JubeatTheme)theme {
    _currentTheme = theme;
    // The value is boxed with +numberWithUnsignedInt:, which is what fixes the ivar's signedness.
    [NSUserDefaults.standardUserDefaults setObject:@(theme) forKey:kThemePreferenceKey];
    [NSUserDefaults.standardUserDefaults synchronize];
    [self.rootViewCtrl changeThemeAndGoTitle];
}

/** @ghidraAddress 0x8f38 */
- (void)setKnitColor:(NSArray *)knitColor {
    [KnitColorManager.sharedManager setColorWithArray:knitColor];
}

/** @ghidraAddress 0x868c */
- (void)switchTitleEvent {
    if (_isHinabitaMode) {
        // A bare immediate in the binary; there is no named constant for the palette type.
        [KnitColorManager.sharedManager setColorWithType:kHinabitaKnitColorType];
    }
    // Sent on both arms, not only the hinabita one.
    [self.rootViewCtrl changeTitleTheme];
}

/** @ghidraAddress 0x871c */
- (void)enableCopiousMarkers {
    // Unconditional: the current value is never read before being overwritten.
    [NSUserDefaults.standardUserDefaults setObject:@YES forKey:kCopiousUnlockedPreferenceKey];
    [NSUserDefaults.standardUserDefaults synchronize];
    [self.rootViewCtrl reloadMarkers];
}

/** @ghidraAddress 0x8f24 */
- (void)rewardEnable {
    // Latched on only, like -markerDownloadComplete.
    _bEnableReward = YES;
}

#pragma mark - Install identifier

/** @ghidraAddress 0x8814 */
- (NSString *)musicListKey {
    NSString *service = NSBundle.mainBundle.bundleIdentifier;

    NSString *queryKeys[] = {
        (__bridge NSString *)kSecClass,
        (__bridge NSString *)kSecAttrAccount,
        (__bridge NSString *)kSecAttrService,
        (__bridge NSString *)kSecMatchLimit,
        (__bridge NSString *)kSecReturnAttributes,
    };
    id queryValues[] = {
        (__bridge id)kSecClassGenericPassword,
        kKeychainAccountName,
        service,
        (__bridge id)kSecMatchLimitOne,
        (__bridge id)kCFBooleanTrue,
    };
    NSDictionary *query =
        [NSDictionary dictionaryWithObjects:queryValues
                                    forKeys:queryKeys
                                      count:sizeof(queryKeys) / sizeof(queryKeys[0])];

    // The branch at 0x8970 is cbz on an OSStatus, so zero is errSecSuccess and this is the
    // item-found arm.
    CFTypeRef attributes = nullptr;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)query, &attributes) == errSecSuccess) {
        // The found attributes are reused as the basis of a second query that asks for the payload.
        NSMutableDictionary *fetch =
            [NSMutableDictionary dictionaryWithDictionary:(__bridge NSDictionary *)attributes];
        fetch[(__bridge NSString *)kSecClass] = (__bridge id)kSecClassGenericPassword;
        fetch[(__bridge NSString *)kSecReturnData] = (__bridge id)kCFBooleanTrue;
        CFRelease(attributes);

        CFTypeRef payload = nullptr;
        NSString *stored = nil;
        if (SecItemCopyMatching((__bridge CFDictionaryRef)fetch, &payload) == errSecSuccess) {
            NSData *bytes = (__bridge NSData *)payload;
            stored = [[NSString alloc] initWithBytes:bytes.bytes
                                              length:bytes.length
                                            encoding:NSUTF8StringEncoding];
        }
        if (stored != nil) {
            return stored;
        }
        // A present-but-undecodable payload falls through and mints a replacement, rather than
        // returning nil. The branch back to the create path is the cbz at 0x8bec.
    }

    CFUUIDRef uuid = CFUUIDCreate(nullptr);
    CFStringRef uuidString = CFUUIDCreateString(nullptr, uuid);
    NSString *key = [NSString stringWithString:(__bridge NSString *)uuidString];
    CFRelease(uuidString);
    CFRelease(uuid);

    NSString *addKeys[] = {
        (__bridge NSString *)kSecClass,
        (__bridge NSString *)kSecAttrAccount,
        (__bridge NSString *)kSecAttrService,
        (__bridge NSString *)kSecAttrLabel,
        (__bridge NSString *)kSecAttrDescription,
        (__bridge NSString *)kSecAttrAccessible,
        (__bridge NSString *)kSecValueData,
    };
    id addValues[] = {
        (__bridge id)kSecClassGenericPassword,
        kKeychainAccountName,
        service,
        @"",
        @"",
        (__bridge id)kSecAttrAccessibleAfterFirstUnlock,
        [key dataUsingEncoding:NSUTF8StringEncoding],
    };
    // The result of SecItemAdd is discarded: a failure to persist is not reported and the freshly
    // minted key is returned regardless.
    SecItemAdd((__bridge CFDictionaryRef)
                   [NSDictionary dictionaryWithObjects:addValues
                                               forKeys:addKeys
                                                 count:sizeof(addKeys) / sizeof(addKeys[0])],
               nullptr);
    return key;
}

#pragma mark - Validation

/** @ghidraAddress 0x8fa8 */
- (BOOL)digitStringCheck:(NSString *)string {
    if (string.length == 0) {
        return NO;
    }
    NSCharacterSet *digits =
        [NSCharacterSet characterSetWithCharactersInString:kDecimalDigitCharacters];
    // A localized scanner, not the plain +scannerWithString:.
    NSScanner *scanner = [NSScanner localizedScannerWithString:string];
    // Disables the default whitespace skipping; without this, spaces would pass the check.
    scanner.charactersToBeSkipped = nil;
    [scanner scanCharactersFromSet:digits intoString:nil];
    return scanner.isAtEnd;
}

#pragma mark - Licence

/** @ghidraAddress 0x8dd4 */
- (NSString *)getCurrentLicenseDate {
    return kCurrentLicenseDate;
}

/** @ghidraAddress 0x8e00 */
- (NSString *)getCurrentLicenseMessage {
    NSString *message = [NSBundle.mainBundle localizedStringForKey:kUsePolicyMessageKey
                                                             value:@""
                                                             table:nil];
    // An untranslated key comes back as the empty default, which is reported as nil rather than as
    // an empty string.
    if ([message isEqualToString:@""]) {
        return nil;
    }
    return message;
}

#pragma mark - Challenge mutators

/** @ghidraAddress 0x8ea0 */
- (void)dropChallengeOpenFlag {
    _bChallengeOpen = NO;
}

/** @ghidraAddress 0x8eb0 */
- (void)moveChallengeOpenFlag {
    if (_bChallengeOpen) {
        _bChallengeMode = YES;
    }
    // Cleared on both arms: the flag is consumed whether or not it fired.
    _bChallengeOpen = NO;
}

/** @ghidraAddress 0x8ed8 */
- (void)setChallengeMode:(BOOL)challengeMode {
    _bChallengeMode = challengeMode;
}

/** @ghidraAddress 0x8ee8 */
- (void)setChallengeMusic:(unsigned int)musicID diff:(int)difficulty {
    // Engaging challenge mode is a side effect the selector name does not advertise.
    _bChallengeMode = YES;
    _challengeDifficulty = difficulty;
    _challengeMusicID = musicID;
}

/** @ghidraAddress 0x8f14 */
- (void)setTotalAmount:(int)amount {
    _totalPurchaseAmount = amount;
}

#pragma mark - Notification persistence

/** @ghidraAddress 0xa530 */
- (NSString *)getNotificationFilePath {
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSString *directory = [JubeatAppDelegate.appCachesDirectory
        stringByAppendingPathComponent:kNotificationDirectoryName];
    if (![fileManager fileExistsAtPath:directory]) {
        NSError *error = nil;
        [fileManager createDirectoryAtPath:directory
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:&error];
    }
    NSString *path = [directory stringByAppendingPathComponent:kNotificationFileName];
    (void)[fileManager fileExistsAtPath:path]; // Yes, the binary discards this call's result.
    return path;
}

/** @ghidraAddress 0xa7a4 */
- (void)loadNotification {
    NSData *data = [[NSData alloc] initWithContentsOfFile:self.getNotificationFilePath];
    // A missing or unreadable file leaves the queue as it was; nothing is cleared on this path.
    if (data == nil) {
        return;
    }
    _pushNotificationList = [[NSKeyedUnarchiver unarchiveObjectWithData:data] mutableCopy];
}

/** @ghidraAddress 0xa66c */
- (void)saveNotification {
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSString *path = self.getNotificationFilePath;
    // The archive is built unconditionally, before the emptiness test below.
    NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:self.pushNotificationList];
    // The property is fetched a second time here rather than reusing the value just archived.
    if (self.pushNotificationList.count == 0) {
        [fileManager removeItemAtPath:path error:nil];
    } else {
        [fileManager createFileAtPath:path contents:archive attributes:nil];
    }
}

/** @ghidraAddress 0xb534 */
- (BOOL)pushActiveCheck:(NSInteger)fireTime {
    // fcvtzs truncates toward zero rather than rounding.
    NSInteger now = (NSInteger)NSDate.date.timeIntervalSince1970;
    // cset le: inclusive, so a notification due this very second is still active.
    return now <= fireTime;
}

/** @ghidraAddress 0xb594 */
- (NSDictionary *)popNotification {
    // An already-empty queue returns without persisting; only the two loop exits below save.
    if (self.pushNotificationList.count == 0) {
        return nil;
    }
    while (true) {
        // Every entry inspected is removed, so expired ones are discarded on the way past.
        NSDictionary *entry = self.pushNotificationList[0];
        [self.pushNotificationList removeObjectAtIndex:0];
        NSInteger expire = [[entry objectForKey:kNotificationExpireKey] longValue];
        if ([self pushActiveCheck:expire]) {
            [self saveNotification];
            return entry;
        }
        if (self.pushNotificationList.count == 0) {
            [self saveNotification];
            return nil;
        }
    }
}

#pragma mark - Client identification

/** @ghidraAddress 0xa260 */
- (void)refreshUserAgent {
    NSString *systemVersion = UIDevice.currentDevice.systemVersion;
    NSString *appVersion = JubeatAppDelegate.appVersion;

    // Mirrors the version into the defaults, but only when it has actually changed.
    if (appVersion != nil) {
        NSString *stored =
            [NSUserDefaults.standardUserDefaults stringForKey:kInternalVersionDefaultsKey];
        if (![stored isEqualToString:appVersion]) {
            [NSUserDefaults.standardUserDefaults setObject:appVersion
                                                    forKey:kInternalVersionDefaultsKey];
        }
    }

    NSString *editorKey = @"";
    if (EditorIDManager.isExistEditorID) {
        editorKey = [EditorIDManager getKeyString:EditorIDManager.getEditorIDKey];
    }

    // The first argument is the literal URL scheme string reused as the product name; it is the
    // same CFString at 0x2d40e0 that -application:handleOpenURL: matches against.
    _userAgent = [NSString
        stringWithFormat:kUserAgentFormat,
                         kJubeatURLScheme,
                         appVersion,
                         JubeatAppDelegate.deviceName,
                         [systemVersion
                             stringByReplacingOccurrencesOfString:kSystemVersionSeparator
                                                       withString:kUserAgentVersionSeparator],
                         NSLocale.currentLocale.localeIdentifier,
                         editorKey];
}

#pragma mark - Launch

/** @ghidraAddress 0x933c */
- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Result discarded. arc4random seeds itself on first use, so this buys nothing.
    arc4random();

    if (launchOptions != nil) {
        NSDictionary *remoteNotification =
            [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
        if (remoteNotification != nil) {
            // The third copy of the scheme routing, identical to the one in
            // -application:didReceiveRemoteNotification: down to the missing guards. All arms fall
            // through to the copy below.
            NSURL *url =
                [NSURL URLWithString:[remoteNotification objectForKey:kNotificationURLKey]];
            if ([url.scheme isEqualToString:kStoreURLScheme]) {
                if (url.pathComponents.count == kHandledURLPathComponentCount) {
                    if ([[url.pathComponents objectAtIndex:1]
                            isEqualToString:kStorePackPathComponent]) {
                        _storePackID = [url.pathComponents objectAtIndex:2];
                    }
                    if ([[url.pathComponents objectAtIndex:1]
                            isEqualToString:kStoreGenrePathComponent]) {
                        _storeGenreID = [url.pathComponents objectAtIndex:2];
                    }
                }
            } else if ([url.scheme isEqualToString:kChallengeURLScheme]) {
                _bChallengeOpen = YES;
            } else if ([url.scheme isEqualToString:kGiftURLScheme]) {
                _storeCampaignID = [url.pathComponents objectAtIndex:2];
            }
            _remotePushInfo = [remoteNotification copy];
        }
    }

    // Device classification. Nothing here reads the model name; the whole decision is idiom, scale,
    // and height. The scale read is shared between the two idiom arms, and the phone arm reads both
    // scale and height again rather than holding on to them.
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        if (UIScreen.mainScreen.scale == kRetinaScreenScale) {
            if (UIScreen.mainScreen.bounds.size.height == kScreenHeight47Inch) {
                _deviceType = JubeatDeviceTypePhoneRetina47Inch;
            } else if (UIScreen.mainScreen.bounds.size.height == kScreenHeight4Inch) {
                _deviceType = JubeatDeviceTypePhoneRetina4Inch;
            } else {
                _deviceType = JubeatDeviceTypePhoneRetina;
            }
        } else if (UIScreen.mainScreen.scale == kRetinaHDScreenScale) {
            if (UIScreen.mainScreen.bounds.size.height == kScreenHeight47Inch) {
                _deviceType = JubeatDeviceTypePhoneRetinaHD47Inch;
            } else {
                _deviceType = JubeatDeviceTypePhoneRetinaHD;
            }
        } else {
            _deviceType = JubeatDeviceTypePhone;
        }
    } else {
        _deviceType = UIScreen.mainScreen.scale == kRetinaScreenScale ? JubeatDeviceTypePadRetina :
                                                                        JubeatDeviceTypePad;
    }
    _bEnableAutoPlay = NO;

    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSNumber *storedTheme = [defaults objectForKey:kThemePreferenceKey];
    if (storedTheme == nil) {
        _currentTheme = kDefaultTheme;
        [defaults setObject:@(kDefaultTheme) forKey:kThemePreferenceKey];
    } else {
        // Tested in the order 2, 1, 0, which is the order the compares appear in.
        switch (storedTheme.unsignedIntegerValue) {
        case 2:
            _currentTheme = 2;
            break;
        case 1:
            _currentTheme = 1;
            break;
        case 0:
            // Already the stored value, so unlike the other two exits this one writes nothing
            // back.
            _currentTheme = 0;
            break;
        default:
            _currentTheme = kDefaultTheme;
            [defaults setObject:@(kDefaultTheme) forKey:kThemePreferenceKey];
            break;
        }
    }

    _gameCenterAvailable = YES;
    // Retained into a local and released at the very end of the method without ever being read.
    // Whatever version test this fed has been removed; only the class probe below survives.
    NSString *systemVersion __unused = UIDevice.currentDevice.systemVersion;
    if (NSClassFromString(kGameCenterLocalPlayerClassName) == nil) {
        _gameCenterAvailable = NO;
    }

    // Called for its side effect only: the getter mints and stores the keychain identifier on first
    // launch. The result is claimed and dropped at 0x999c.
    (void)self.musicListKey;
    [self refreshUserAgent];
    _bEnableReward = NO;

    if ([NSUserDefaults.standardUserDefaults objectForKey:kAdjustSectorPreferenceKey] == nil) {
        // The 0.0f is a movi of the whole vector register, so the default offset is zero.
        [NSUserDefaults.standardUserDefaults setFloat:0.0f forKey:kAdjustSectorPreferenceKey];
    }

    [KnitColorManager.sharedManager setColorWithType:0];
    _isMarkerLegal = YES;

    [MarkerManager moveMarkerDataInDoc];
    [MarkerManager checkRegularMarkerData];
    if (![TweetResourceManager checkResourceData]) {
        [TweetResourceManager moveResourceDataInDoc];
    }

    id twitterBackgroundFrame = [defaults objectForKey:kTwitterBackgroundFramePreferenceKey];
    if (twitterBackgroundFrame != nil &&
        ![TweetResourceManager checkEnableSelecteFrame:twitterBackgroundFrame]) {
        [defaults removeObjectForKey:kTwitterBackgroundFramePreferenceKey];
    }

    if ([NSUserDefaults.standardUserDefaults objectForKey:kLabURLPreferenceKey] == nil) {
        // Ciphertext, not a URL string: what is persisted is an NSMutableData blob.
        NSMutableData *encryptedLabURL = CreateLabEncryptedData(kLabURL);
        if (encryptedLabURL != nil) {
            [NSUserDefaults.standardUserDefaults setObject:encryptedLabURL
                                                    forKey:kLabURLPreferenceKey];
        }
    }

    // Discards the whole in-memory object graph before anything has used it.
    [ScoreRecordManager.sharedManager.managedObjectContext reset];
    UIApplication.sharedApplication.idleTimerDisabled = YES;

    mainWindow = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    mainWindow.autoresizesSubviews = NO;
    mainWindow.opaque = YES;
    mainWindow.backgroundColor = UIColor.blackColor;
#ifdef ENABLE_PATCHES
    // Preservation patch, not in the binary: this build predates iOS 13, so every colour it picks
    // assumes the light appearance. Under the dark appearance the system-drawn surfaces invert
    // while the app's own artwork does not. Pinning the window covers every view controller
    // presented from it.
    if (@available(iOS 13.0, *)) {
        mainWindow.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
    }
#endif
    _rootViewCtrl = [[RootViewController alloc] init];
    // Assigns through the getter rather than reusing the ivar just written.
    mainWindow.rootViewController = self.rootViewCtrl;
    [mainWindow makeKeyAndVisible];

    if (self.remotePushInfo != nil) {
        // YES for the cold-launch case, against the NO that
        // -application:didReceiveRemoteNotification: passes.
        [_rootViewCtrl responseRemoteNotification:YES pushInfo:self.remotePushInfo];
    }

    // Four separate +sharedManager sends, one per call.
    [PurchaseManager.sharedManager start];
    [PurchaseManager.sharedManager loadProductList];
    [PurchaseManager.sharedManager loadPendingList];
    [PurchaseManager.sharedManager loadPendingConsumeList];
    [StoreMusicListManager.sharedManager loadMusicList];

    AVAudioSession *audioSession = AVAudioSession.sharedInstance;
    // Each of the four calls gets its own error variable and not one of them is examined.
    NSError *categoryError = nil;
    [audioSession setCategory:AVAudioSessionCategorySoloAmbient error:&categoryError];
    NSError *sampleRateError = nil;
    [audioSession setPreferredSampleRate:kPreferredSampleRate error:&sampleRateError];
    NSError *bufferDurationError = nil;
    [audioSession setPreferredIOBufferDuration:kPreferredIOBufferDuration
                                         error:&bufferDurationError];
    NSError *activationError = nil;
    [audioSession setActive:YES error:&activationError];

    [self.rootViewCtrl startLogo];
    _bSendPushID = NO;
    UIApplication.sharedApplication.applicationIconBadgeNumber = 0;
    [self loadNotification];
    if (_pushNotificationList == nil) {
        // -loadNotification leaves it nil when there is no saved queue.
        _pushNotificationList = [[NSMutableArray alloc] init];
    }

    UIUserNotificationSettings *notificationSettings = [UIUserNotificationSettings
        settingsForTypes:UIUserNotificationTypeBadge | UIUserNotificationTypeSound |
                         UIUserNotificationTypeAlert
              categories:nil];
    // This order is backwards from Apple's: the settings that decide what the user is asked for are
    // registered after remote registration has already been requested. Reproduced as compiled.
    [UIApplication.sharedApplication registerForRemoteNotifications];
    [UIApplication.sharedApplication registerUserNotificationSettings:notificationSettings];
    return YES;
}

#pragma mark - URL scheme

/** @ghidraAddress 0x9090 */
- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    if (![url.scheme isEqualToString:kJubeatURLScheme]) {
        return YES;
    }

    // The 13 is an immediate at 0x9134 and is the length of "jubeatplus://".
    NSString *tail =
        [[NSString stringWithFormat:@"%@", url] substringFromIndex:kJubeatURLSchemePrefixLength];
    NSArray *components = url.pathComponents;

    if (components.count == kHandledURLPathComponentCount) {
        if ([[components objectAtIndex:1] isEqualToString:kStoreURLScheme]) {
            id value = [components objectAtIndex:2];
            // Yes, index 1 again, not 2. The enclosing test has just proven this element equals
            // "jbtstore", so neither comparison below can ever be true and both stores are dead
            // code. Reproduced as compiled: no URL shape satisfies both tests, since one element
            // cannot equal two different strings.
            id key = [components objectAtIndex:1];
            if ([key isEqualToString:kStorePackPathComponent]) {
                _storePackID = value;
            }
            if ([key isEqualToString:kStoreGenrePathComponent]) {
                _storeGenreID = value;
            }
        }
        if ([[components objectAtIndex:1] isEqualToString:kGiftURLScheme]) {
            _storeCampaignID = [components objectAtIndex:2];
        }
    }

    if ([self digitStringCheck:tail]) {
        _jcfDownloadID = tail;
    }
    return YES;
}

#pragma mark - Push payload

/** @ghidraAddress 0xa990 */
- (NSMutableDictionary *)apsDictionary:(NSDictionary *)userInfo {
    NSDictionary *aps = [userInfo objectForKey:kApsPayloadKey];
    if (aps == nil) {
        return nil;
    }
    NSMutableDictionary *flattened = [[NSMutableDictionary alloc] init];
    // Every entry below is looked up twice, once to test and once to fetch, as compiled.
    if ([aps objectForKey:kApsAlertKey] != nil) {
        // The only key that is renamed on the way across: "alert" in, "body" out.
        [flattened setObject:[aps objectForKey:kApsAlertKey] forKey:kNotificationBodyKey];
    }
    if ([aps objectForKey:kNotificationSoundKey] != nil) {
        [flattened setObject:[aps objectForKey:kNotificationSoundKey] forKey:kNotificationSoundKey];
    }
    if ([userInfo objectForKey:kNotificationURLKey] != nil) {
        [flattened setObject:[userInfo objectForKey:kNotificationURLKey]
                      forKey:kNotificationURLKey];
    }
    if ([userInfo objectForKey:kNotificationExpireKey] != nil) {
        [flattened setObject:[userInfo objectForKey:kNotificationExpireKey]
                      forKey:kNotificationExpireKey];
    }
    if ([userInfo objectForKey:kNotificationIdentifierKey] != nil) {
        [flattened setObject:[userInfo objectForKey:kNotificationIdentifierKey]
                      forKey:kNotificationIdentifierKey];
    }
    return flattened;
}

#pragma mark - Notification registration

/** @ghidraAddress 0xa868 */
- (void)application:(UIApplication *)application
    didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings {
    // The granted types are never inspected; registration proceeds either way.
    [application registerForRemoteNotifications];
}

/** @ghidraAddress 0xa8a4 */
- (void)application:(UIApplication *)application
    didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    // Depends on NSData.description's "<xxxx xxxx>" format, stripped literal by literal.
    _deviceToken = [[[deviceToken.description stringByReplacingOccurrencesOfString:@"<"
                                                                        withString:@""]
        stringByReplacingOccurrencesOfString:@">"
                                  withString:@""] stringByReplacingOccurrencesOfString:@" "
                                                                            withString:@""];
}

/** @ghidraAddress 0xa98c */
- (void)application:(UIApplication *)application
    didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    // Yes, the compiled method at 0xa98c is a bare ret. The failure is neither recorded nor
    // reported, so deviceToken stays nil.
}

#pragma mark - Notification delivery

/** @ghidraAddress 0xac48 */
- (void)application:(UIApplication *)application
    didReceiveLocalNotification:(UILocalNotification *)notification {
    if (notification.userInfo == nil) {
        return;
    }
    // userInfo is sent again rather than the value just tested being reused, here and once more in
    // the routing arm below. Three sends in total.
    NSMutableDictionary *payload = [self apsDictionary:notification.userInfo];

    if (application.applicationState == UIApplicationStateActive) {
        // In the foreground iOS presents nothing, so the notification is queued and the root
        // controller is asked to show it. Note payload is not nil-checked before -addObject:, even
        // though -apsDictionary: returns nil for a userInfo with no "aps" entry.
        [_pushNotificationList addObject:payload];
        // The result is loaded into d0 and never read: no store, and -saveNotification takes no
        // argument. Kept because removing it would not be the same program.
        [NSDate.date timeIntervalSince1970];
        [self saveNotification];
        [_rootViewCtrl pushNotificate];
        return;
    }

    // Otherwise the user tapped the notification, and its "url" entry decides where to go. This is
    // the routing -application:handleOpenURL: was meant to perform: the token is read off the
    // scheme here, which is where it actually lives.
    NSURL *url = [NSURL URLWithString:[notification.userInfo objectForKey:kNotificationURLKey]];
    if ([url.scheme isEqualToString:kStoreURLScheme]) {
        if (url.pathComponents.count != kHandledURLPathComponentCount) {
            return;
        }
        // pathComponents is re-sent for every one of these five subscripts, as compiled.
        if ([[url.pathComponents objectAtIndex:1] isEqualToString:kStorePackPathComponent]) {
            _storePackID = [url.pathComponents objectAtIndex:2];
        }
        if ([[url.pathComponents objectAtIndex:1] isEqualToString:kStoreGenrePathComponent]) {
            _storeGenreID = [url.pathComponents objectAtIndex:2];
        }
        return;
    }
    if ([url.scheme isEqualToString:kChallengeURLScheme]) {
        // Only a flag; the challenge screen is opened later by whoever reads it.
        _bChallengeOpen = YES;
        return;
    }
    if ([url.scheme isEqualToString:kGiftURLScheme]) {
        // No count guard on this arm, unlike the store arm above, so a jbtgift URL with fewer than
        // three path components raises NSRangeException.
        _storeCampaignID = [url.pathComponents objectAtIndex:2];
    }
}

/** @ghidraAddress 0xb0c8 */
- (void)application:(UIApplication *)application
    didReceiveRemoteNotification:(NSDictionary *)userInfo {
    // Sent to the shared application rather than to the argument, which is the same object.
    UIApplication.sharedApplication.applicationIconBadgeNumber = 0;

    // Computed before the split even though only the foreground arm reads it. On the routing path
    // below the dictionary is built and released without ever being used.
    NSMutableDictionary *payload = [self apsDictionary:userInfo];

    if (application.applicationState == UIApplicationStateActive) {
        // Identical to the foreground arm of -application:didReceiveLocalNotification:, down to the
        // discarded -timeIntervalSince1970 result. Note this arm alone skips the response report at
        // the end of the method.
        [_pushNotificationList addObject:payload];
        [NSDate.date timeIntervalSince1970];
        [self saveNotification];
        [_rootViewCtrl pushNotificate];
        return;
    }

    // Unlike the local variant there is no userInfo nil test anywhere in this method, and the
    // routing arms fall through to the report below instead of returning.
    NSURL *url = [NSURL URLWithString:[userInfo objectForKey:kNotificationURLKey]];
    if ([url.scheme isEqualToString:kStoreURLScheme]) {
        if (url.pathComponents.count == kHandledURLPathComponentCount) {
            if ([[url.pathComponents objectAtIndex:1] isEqualToString:kStorePackPathComponent]) {
                _storePackID = [url.pathComponents objectAtIndex:2];
            }
            if ([[url.pathComponents objectAtIndex:1] isEqualToString:kStoreGenrePathComponent]) {
                _storeGenreID = [url.pathComponents objectAtIndex:2];
            }
        }
    } else if ([url.scheme isEqualToString:kChallengeURLScheme]) {
        _bChallengeOpen = YES;
    } else if ([url.scheme isEqualToString:kGiftURLScheme]) {
        _storeCampaignID = [url.pathComponents objectAtIndex:2];
    }

    // Reached from every path above, including a URL that matched no scheme and a jbtstore URL with
    // the wrong component count. NO here means the notification reached an already-running app;
    // -application:didFinishLaunchingWithOptions: passes YES at 0x9dfc for the launch case.
    [_rootViewCtrl responseRemoteNotification:NO pushInfo:userInfo];
}

#pragma mark - Application lifecycle

/** @ghidraAddress 0xb6f8 */
- (void)applicationDidEnterBackground:(UIApplication *)application {
    [ChallengeStatus.sharedStatus createCoinNotification];
}

/** @ghidraAddress 0xb740 */
- (void)applicationWillResignActive:(UIApplication *)application {
    // Yes, the compiled method at 0xb740 is a bare ret.
}

/** @ghidraAddress 0xb744 */
- (void)applicationDidBecomeActive:(UIApplication *)application {
    // The binary re-reads the shared application twice rather than using the argument.
    [UIApplication.sharedApplication setApplicationIconBadgeNumber:0];
    [UIApplication.sharedApplication cancelAllLocalNotifications];
}

/** @ghidraAddress 0xb7c8 */
- (void)applicationWillTerminate:(UIApplication *)application {
    [PurchaseManager.sharedManager end];
    [ScoreRecordManager.sharedManager saveRecords];
}

/** @ghidraAddress 0xb844 */
- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    // Yes, the compiled method at 0xb844 is a bare ret. Nothing is freed on a memory warning.
}

#pragma mark - Device idiom predicates

// Each predicate below is a set-membership test on _deviceType, written the way the binary computes
// it rather than as an equivalent range check, so the compiled form stays recognisable.

/** @ghidraAddress 0x82c0 */
- (BOOL)isPad {
    // orr x8, x8, #1 then cmp #7: folds the two pad classes into one comparison.
    return (_deviceType | 1) == JubeatDeviceTypePadRetina;
}

/** @ghidraAddress 0x82dc */
- (BOOL)isPhoneRetina {
    // sub #1 then unsigned cmp #5: every retina phone class, 1 through 5.
    return (NSUInteger)(_deviceType - JubeatDeviceTypePhoneRetina) < kPhoneRetinaDeviceTypeCount;
}

/** @ghidraAddress 0x82f8 */
- (BOOL)is4inchAspect {
    // sub #2 then unsigned cmp #4: classes 2 through 5, which the launch classifier shows are
    // exactly the 16:9 screens. The name is the binary's own idea, not a claim that all four are
    // four inches.
    return (NSUInteger)(_deviceType - JubeatDeviceTypePhoneRetina4Inch) <
           k4inchAspectDeviceTypeCount;
}

/** @ghidraAddress 0x8314 */
- (BOOL)isPadRetina {
    return _deviceType == JubeatDeviceTypePadRetina;
}

#pragma mark - Download selection mutators

/** @ghidraAddress 0x8c38 */
- (void)resetDownLoadIndex {
    _jcfDownloadID = nil;
}

/** @ghidraAddress 0x8c50 */
- (void)resetDownloadGenreID {
    _storeGenreID = nil;
}

/** @ghidraAddress 0x8c68 */
- (void)setDownloadGenreID:(id)genreID {
    _storeGenreID = genreID;
}

/** @ghidraAddress 0x8c7c */
- (void)resetDownloadPackID {
    _storePackID = nil;
}

/** @ghidraAddress 0x8c94 */
- (void)setDownloadPackID:(id)packID {
    _storePackID = packID;
}

/** @ghidraAddress 0x8ca8 */
- (void)resetCampaignID {
    _storeCampaignID = nil;
}

/** @ghidraAddress 0x8cc0 */
- (void)setCampaignID:(id)campaignID {
    _storeCampaignID = campaignID;
}

#pragma mark - Notification page mutators

/** @ghidraAddress 0x8cd4 */
- (void)setNotificationPageURL:(NSString *)pageURL updateTime:(id)updateTime {
    // A nil page URL clears the stored URL rather than building one from nil: the binary branches
    // on the argument at 0x8d04 and only reaches +[NSURL URLWithString:] on the non-nil arm.
    if (pageURL != nil) {
        _notificationURL = [NSURL URLWithString:pageURL];
    } else {
        _notificationURL = nil;
    }
    _notificationTime = updateTime;
}

#pragma mark - Option flag mutators

/** @ghidraAddress 0x8d7c */
- (void)setRandomFlag:(BOOL)flag {
    _isRandom = flag;
}

/** @ghidraAddress 0x8d8c */
- (void)setExtendFlag:(BOOL)flag {
    _isExtend = flag;
}

/** @ghidraAddress 0x8d9c */
- (void)setHoldFlag:(BOOL)flag {
    _isHold = flag;
}

/** @ghidraAddress 0x8dac */
- (void)setSearchString:(id)searchString {
    _searchString = searchString;
}

/** @ghidraAddress 0x8dc0 */
- (void)markerDownloadComplete {
    // Latched on only. No compiled setter ever clears this flag.
    _isMarkerLegal = YES;
}

@end
