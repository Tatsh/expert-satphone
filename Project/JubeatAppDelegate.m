#import "JubeatAppDelegate.h"

#include <stdlib.h>

#include <sys/sysctl.h>

#import <GameKit/GameKit.h>

#import "ChallengeStatus.h"
#import "KnitColorManager.h"
#import "RootViewController.h"
#import "PurchaseManager.h"
#import "ScoreRecordManager.h"

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

// The digit set -digitStringCheck: accepts, from the CFString at 0x2d4340. The binary spells the
// digits out rather than using NSCharacterSet.decimalDigitCharacterSet.
static NSString *const kDecimalDigitCharacters = @"0123456789";

// The knit-colour palette type the hinabita collaboration selects, a bare immediate at 0x86d4.
static const int kHinabitaKnitColorType = 4;

// The key each queued notification stores its fire time under, from the CFString at 0x2d4680.
static NSString *const kNotificationExpireKey = @"expire";

// The two path components of the persisted notification queue, at 0x2d4560 and 0x2d4580.
static NSString *const kNotificationDirectoryName = @"notification";
static NSString *const kNotificationFileName = @"noti.txt";

// The Game Center error code the authentication handler treats as fatal, compared as the immediate
// 16 at 0x84f0. That is GKErrorNotSupported; the binary spells it as a bare number.
static const NSInteger kGameCenterNotSupportedErrorCode = 16;

// The device-type values the four idiom predicates at 0x82c0-0x8328 compare against. The binary
// names none of them, so each is named here after what its predicate proves rather than after a
// device the naming is not evidence for.
enum {
    kFirstPhoneRetinaDeviceType = 1,
    kFirst4inchDeviceType = 2,
    kPhoneRetinaDeviceTypeCount = 5,
    k4inchDeviceTypeCount = 4,
    kDeviceTypePadRetina = 7,
};

@implementation JubeatAppDelegate

#pragma mark - Identification

+ (JubeatAppDelegate *)appDelegate {
    // The binary forwards -delegate with no class check of its own.
    return (JubeatAppDelegate *)UIApplication.sharedApplication.delegate;
}

+ (NSString *)appVersion {
    return [[NSString alloc] initWithCString:kApplicationVersionString
                                    encoding:NSUTF8StringEncoding];
}

#pragma mark - Standard directories

+ (NSString *)appLibraryDirectory {
    return NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).lastObject;
}

+ (NSString *)appDocumentsDirectory {
    return NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)
        .lastObject;
}

+ (NSString *)appCachesDirectory {
    return NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).lastObject;
}

+ (NSString *)deviceName {
    size_t length = 0;
    sysctlbyname(kHardwareMachineSysctlName, NULL, &length, NULL, 0);
    if (length == 0) {
        return UIDevice.currentDevice.model;
    }
    char *machine = malloc(length);
    sysctlbyname(kHardwareMachineSysctlName, machine, &length, NULL, 0);
    NSString *name = [[NSString alloc] initWithCString:machine encoding:NSUTF8StringEncoding];
    free(machine);
    return name;
}

+ (NSString *)primDeviceName {
    // Yes, this duplicates +deviceName exactly. The binary emits two complete copies of the
    // routine at 0x7e94 and 0x7f78 rather than one calling the other, so both are kept.
    size_t length = 0;
    sysctlbyname(kHardwareMachineSysctlName, NULL, &length, NULL, 0);
    if (length == 0) {
        return UIDevice.currentDevice.model;
    }
    char *machine = malloc(length);
    sysctlbyname(kHardwareMachineSysctlName, machine, &length, NULL, 0);
    NSString *name = [[NSString alloc] initWithCString:machine encoding:NSUTF8StringEncoding];
    free(machine);
    return name;
}

#pragma mark - Game Center

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

- (void)disableGameCenter {
    _gameCenterAvailable = NO;
}

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

- (NSString *)totalScoreLeaderboardCategory {
    // A csel, not a branch: both literals are materialised and one is selected.
    return self.isPad ? kTotalScoreLeaderboardCategoryPad : kTotalScoreLeaderboardCategoryPhone;
}

#pragma mark - Presentation mutators

- (void)changeTheme:(unsigned int)theme {
    _currentTheme = theme;
    // The value is boxed with +numberWithUnsignedInt:, which is what fixes the ivar's signedness.
    NSUserDefaults.standardUserDefaults[kThemePreferenceKey] = @(theme);
    [NSUserDefaults.standardUserDefaults synchronize];
    [self.rootViewCtrl changeThemeAndGoTitle];
}

- (void)setKnitColor:(NSArray *)knitColor {
    [KnitColorManager.sharedManager setColorWithArray:knitColor];
}

- (void)switchTitleEvent {
    if (_isHinabitaMode) {
        // A bare immediate in the binary; there is no named constant for the palette type.
        [KnitColorManager.sharedManager setColorWithType:kHinabitaKnitColorType];
    }
    // Sent on both arms, not only the hinabita one.
    [self.rootViewCtrl changeTitleTheme];
}

- (void)enableCopiousMarkers {
    // Unconditional: the current value is never read before being overwritten.
    NSUserDefaults.standardUserDefaults[kCopiousUnlockedPreferenceKey] = @YES;
    [NSUserDefaults.standardUserDefaults synchronize];
    [self.rootViewCtrl reloadMarkers];
}

- (void)rewardEnable {
    // Latched on only, like -markerDownloadComplete.
    _bEnableReward = YES;
}

#pragma mark - Validation

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

- (NSString *)getCurrentLicenseDate {
    return kCurrentLicenseDate;
}

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

- (void)dropChallengeOpenFlag {
    _bChallengeOpen = NO;
}

- (void)moveChallengeOpenFlag {
    if (_bChallengeOpen) {
        _bChallengeMode = YES;
    }
    // Cleared on both arms: the flag is consumed whether or not it fired.
    _bChallengeOpen = NO;
}

- (void)setChallengeMode:(BOOL)challengeMode {
    _bChallengeMode = challengeMode;
}

- (void)setChallengeMusic:(int)musicID diff:(int)difficulty {
    // Engaging challenge mode is a side effect the selector name does not advertise.
    _bChallengeMode = YES;
    _challengeDifficulty = difficulty;
    _challengeMusicID = musicID;
}

- (void)setTotalAmount:(int)amount {
    _totalPurchaseAmount = amount;
}

#pragma mark - Notification persistence

- (NSString *)getNotificationFilePath {
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSString *directory =
        [JubeatAppDelegate.appCachesDirectory stringByAppendingPathComponent:
            kNotificationDirectoryName];
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

- (void)loadNotification {
    NSData *data = [[NSData alloc] initWithContentsOfFile:self.getNotificationFilePath];
    // A missing or unreadable file leaves the queue as it was; nothing is cleared on this path.
    if (data == nil) {
        return;
    }
    _pushNotificationList = [[NSKeyedUnarchiver unarchiveObjectWithData:data] mutableCopy];
}

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

- (BOOL)pushActiveCheck:(NSInteger)fireTime {
    // fcvtzs truncates toward zero rather than rounding.
    NSInteger now = (NSInteger)NSDate.date.timeIntervalSince1970;
    // cset le: inclusive, so a notification due this very second is still active.
    return now <= fireTime;
}

- (NSDictionary *)popNotification {
    // An already-empty queue returns without persisting; only the two loop exits below save.
    if (self.pushNotificationList.count == 0) {
        return nil;
    }
    while (true) {
        // Every entry inspected is removed, so expired ones are discarded on the way past.
        NSDictionary *entry = self.pushNotificationList[0];
        [self.pushNotificationList removeObjectAtIndex:0];
        NSInteger expire = [entry[kNotificationExpireKey] longValue];
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

#pragma mark - Application lifecycle

- (void)applicationDidEnterBackground:(UIApplication *)application {
    [ChallengeStatus.sharedStatus createCoinNotification];
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Yes, the compiled method at 0xb740 is a bare ret.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // The binary re-reads the shared application twice rather than using the argument.
    [UIApplication.sharedApplication setApplicationIconBadgeNumber:0];
    [UIApplication.sharedApplication cancelAllLocalNotifications];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    [PurchaseManager.sharedManager end];
    [ScoreRecordManager.sharedManager saveRecords];
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    // Yes, the compiled method at 0xb844 is a bare ret. Nothing is freed on a memory warning.
}

#pragma mark - Device idiom predicates

// Each predicate below is a set-membership test on _deviceType, written the way the binary computes
// it rather than as an equivalent range check, so the compiled form stays recognisable.

- (BOOL)isPad {
    // orr x8, x8, #1 then cmp #7: true for device types 6 and 7.
    return (_deviceType | 1) == kDeviceTypePadRetina;
}

- (BOOL)isPhoneRetina {
    // sub #1 then unsigned cmp #5: true for device types 1 to 5.
    return (NSUInteger)(_deviceType - kFirstPhoneRetinaDeviceType) < kPhoneRetinaDeviceTypeCount;
}

- (BOOL)is4inchAspect {
    // sub #2 then unsigned cmp #4: true for device types 2 to 5.
    return (NSUInteger)(_deviceType - kFirst4inchDeviceType) < k4inchDeviceTypeCount;
}

- (BOOL)isPadRetina {
    return _deviceType == kDeviceTypePadRetina;
}

#pragma mark - Download selection mutators

- (void)resetDownLoadIndex {
    _jcfDownloadID = nil;
}

- (void)resetDownloadGenreID {
    _storeGenreID = nil;
}

- (void)setDownloadGenreID:(id)genreID {
    _storeGenreID = genreID;
}

- (void)resetDownloadPackID {
    _storePackID = nil;
}

- (void)setDownloadPackID:(id)packID {
    _storePackID = packID;
}

- (void)resetCampaignID {
    _storeCampaignID = nil;
}

- (void)setCampaignID:(id)campaignID {
    _storeCampaignID = campaignID;
}

#pragma mark - Notification page mutators

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

- (void)setRandomFlag:(BOOL)flag {
    _isRandom = flag;
}

- (void)setExtendFlag:(BOOL)flag {
    _isExtend = flag;
}

- (void)setHoldFlag:(BOOL)flag {
    _isHold = flag;
}

- (void)setSearchString:(id)searchString {
    _searchString = searchString;
}

- (void)markerDownloadComplete {
    // Latched on only. No compiled setter ever clears this flag.
    _isMarkerLegal = YES;
}

@end
