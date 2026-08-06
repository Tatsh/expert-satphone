/** @file
 * The application delegate for jubeat plus: owns the root view controller, exposes the device and
 * client identification the servers are told about, holds the persisted gameplay option flags and
 * store selection state, and drives the application lifecycle and notification handling.
 *
 * Reconstructed from Ghidra program Jubeat (class JubeatAppDelegate, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: complete. The property list is every accessor in the two blocks at
 * 0x8c38-0x8dd4 and 0xb848-0xbb34, all of which were disassembled rather than read from the
 * decompile. The ivar names come from the ObjC ivar offset globals at 0x349600-0x349690, which is
 * runtime metadata and therefore authoritative.
 *
 * Where a property's concrete class has not been proven from the code, the doc comment says so
 * rather than guessing. Those types are tightened as each writer is reconstructed.
 */

#import <UIKit/UIKit.h>

@class RootViewController;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The three skins the game ships.
 *
 * The binary names none of these either, but the classes the transition dispatcher picks between at
 * 0x1a9604 do: theme 1 builds @c TitleViewControllerRpl and anything else builds
 * @c TitleViewControllerOrg, while theme 2 is routed through
 * @c -[RootViewController createKnitTitleViewController] before either test is reached. That fixes
 * all three names without guessing.
 *
 * @c -[KnitColorManager setColorWithType:] indexes its palette table with a value from the same
 * range, which is what ties the colour scheme to the skin.
 */
typedef NS_ENUM(unsigned int, JubeatTheme) {
    /** The game's own livery. Also the value written back when the stored one is missing. */
    JubeatThemeOriginal = 0,
    /** The REFLEC BEAT plus livery. */
    JubeatThemeReflecBeatPlus = 1,
    /** The knit livery, built by a dedicated factory rather than allocated inline. */
    JubeatThemeKnit = 2,
};

/**
 * @brief The device classes this build distinguishes.
 *
 * The binary names none of these; the names below come from the classifier at 0x9748-0x97d0 and
 * 0xa180-0xa25c, which decides purely on @c UIDevice.userInterfaceIdiom, @c UIScreen.scale, and
 * @c UIScreen.bounds.size.height. The two heights it compares against are the pooled doubles at
 * 0x28dfd0 and 0x28dfd8, which decode to 667.0 and 568.0.
 *
 * The ordering is not arbitrary: the four idiom predicates test contiguous ranges of it, which is
 * why the phone classes run 0 to 5 and the pad classes are the top pair.
 */
typedef NS_ENUM(NSInteger, JubeatDeviceType) {
    /** Non-retina phone: idiom Phone, scale neither 2 nor 3. */
    JubeatDeviceTypePhone = 0,
    /** Retina phone, 480-point screen: scale 2, height neither 667 nor 568. */
    JubeatDeviceTypePhoneRetina = 1,
    /** Four-inch retina phone: scale 2, height 568. */
    JubeatDeviceTypePhoneRetina4Inch = 2,
    /** 4.7-inch retina phone: scale 2, height 667. */
    JubeatDeviceTypePhoneRetina47Inch = 3,
    /** Scale-3 phone showing a 667-point screen, which is display zoom on a 5.5-inch device. */
    JubeatDeviceTypePhoneRetinaHD47Inch = 4,
    /** Scale-3 phone at its native height. */
    JubeatDeviceTypePhoneRetinaHD = 5,
    /** Non-retina pad: idiom not Phone, scale not 2. */
    JubeatDeviceTypePad = 6,
    /** Retina pad: idiom not Phone, scale 2. */
    JubeatDeviceTypePadRetina = 7,
};

/**
 * @brief The application delegate for jubeat plus.
 */
@interface JubeatAppDelegate : UIResponder <UIApplicationDelegate>

#pragma mark - Identification

/**
 * @brief The shared application's delegate.
 *
 * The binary forwards @c -[UIApplication delegate] unchanged without a class check; the concrete
 * type is stated here because that is what it is at runtime and what every caller relies on.
 * @ghidraAddress 0x7cf4
 */
@property(class, nonatomic, readonly, nullable) JubeatAppDelegate *appDelegate;
/**
 * @brief The device model identifier, for example @c "iPhone9,3".
 *
 * Reads @c hw.machine through @c sysctlbyname and wraps it in an @c NSString; when the sysctl
 * reports a zero length it falls back to @c UIDevice.currentDevice.model.
 * @ghidraAddress 0x7f78
 */
@property(class, nonatomic, readonly) NSString *deviceName;
/**
 * @brief The device model identifier, by a second copy of the same routine.
 *
 * Surprising but faithful: this is byte-for-byte the same algorithm as @c +deviceName — the same
 * @c hw.machine sysctl, the same @c UIDevice.currentDevice.model fallback on a zero length, and the
 * same UTF-8 @c -initWithCString:encoding:. The compiler emitted two complete copies rather than
 * one calling the other, so both are reconstructed rather than collapsed into one.
 * @ghidraAddress 0x7e94
 */
@property(class, nonatomic, readonly) NSString *primDeviceName;
/**
 * @brief The application version.
 *
 * Surprising but faithful: this is not read from the bundle's Info.plist. The binary builds it from
 * a hardcoded C string literal at 0x27dc66, whose bytes are "3.9.11", with
 * @c -initWithCString:encoding: at UTF-8 (encoding 4).
 * @ghidraAddress 0x7e58
 */
@property(class, nonatomic, readonly) NSString *appVersion;
/**
 * @brief The client identification dictionary sent to the servers.
 *
 * Five entries, built with @c +dictionaryWithObjects:forKeys:count: and a count of exactly 5 — the
 * slot count is read from the stack setup at 0x8100-0x81d4 rather than from the decompile, which
 * renders this kind of constructor with only its first argument:
 *
 *   "uuid"    the MD5 hex digest of @c musicListKey with "STORE" appended
 *   "version" @c +appVersion
 *   "device"  @c +deviceName
 *   "os"      @c UIDevice.currentDevice.systemVersion
 *   "locale"  @c NSLocale.currentLocale.localeIdentifier
 *
 * The "uuid" entry is the MD5 of @c musicListKey with "STORE" appended. Despite that selector
 * name, @c musicListKey is not derived from any music list: it is a per-install identifier
 * persisted in the keychain, minted with @c CFUUIDCreate the first time it is missing. So the
 * "uuid" value is a stable per-install identifier after all, though it reaches that state by a
 * route neither key name suggests.
 * @ghidraAddress 0x805c
 */
@property(class, nonatomic, readonly) NSDictionary *clientInfo;

#pragma mark - Standard directories

/**
 * @brief The user Library directory.
 *
 * @c NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) followed by
 * @c -lastObject. The directory constant 5 and the domain mask 1 were read from the immediate
 * @c mov instructions at 0x7d5c-0x7d64.
 * @ghidraAddress 0x7d50
 */
@property(class, nonatomic, readonly) NSString *appLibraryDirectory;
/**
 * @brief The user Documents directory. The directory constant is 9 (@c NSDocumentDirectory).
 * @ghidraAddress 0x7da8
 */
@property(class, nonatomic, readonly) NSString *appDocumentsDirectory;
/**
 * @brief The user Caches directory. The directory constant is 13 (@c NSCachesDirectory).
 * @ghidraAddress 0x7e00
 */
@property(class, nonatomic, readonly) NSString *appCachesDirectory;

#pragma mark - Root view controller

/**
 * @brief The root view controller of the application.
 *
 * Backed by @c _rootViewCtrl (ivar offset global 0x349608). The class is proven rather than
 * assumed: @c -changeTheme: sends @c -changeThemeAndGoTitle to this object, and the only
 * implementation of that selector in the binary is @c -[RootViewController changeThemeAndGoTitle]
 * at 0x1a8a68.
 * @ghidraAddress 0xb848 (getter)
 */
@property(nonatomic, readonly) RootViewController *rootViewCtrl;

#pragma mark - Client identification

/**
 * @brief The User-Agent string sent with the game's web requests.
 *
 * Backed by @c _userAgent (0x34966c). Proven to be an @c NSString by @c -refreshUserAgent at
 * 0xa260, which assigns the result of @c +[NSString stringWithFormat:] straight into the ivar.
 * @ghidraAddress 0xb858 (getter)
 */
@property(nonatomic, readonly) NSString *userAgent;
/**
 * @brief Rebuilds @c userAgent, and mirrors the app version into the user defaults on the way.
 *
 * The User-Agent format is "%\@/%\@ (%\@; iOS %\@; %\@) [%\@]" with six arguments, in order: the
 * literal "jubeatplus", @c +appVersion, @c +deviceName, the system version with every "." replaced
 * by "_", the current locale identifier, and the editor identifier key (empty when none is
 * provisioned).
 *
 * The argument list was read from the stack stores at 0xa498-0xa4a8 rather than from the decompile,
 * which shows a variadic call with only its first argument. Six specifiers against six slots.
 * @ghidraAddress 0xa260
 */
- (void)refreshUserAgent;
/**
 * @brief The device idiom and screen class this build has classified the device as.
 *
 * Backed by @c _deviceType (0x349600), an 8-byte integer rather than an object despite the getter
 * loading a full word.
 * @ghidraAddress 0xb878 (getter)
 */
@property(nonatomic, readonly) JubeatDeviceType deviceType;
/**
 * @brief The APNs device token, retained as received.
 *
 * Backed by @c _deviceToken (0x349670). An @c NSString, not the @c NSData the callback receives:
 * @c -application:didRegisterForRemoteNotificationsWithDeviceToken: stores the token's
 * @c -description with the angle brackets and spaces stripped out.
 * @ghidraAddress 0xbaf0 (getter)
 */
@property(nonatomic, readonly, nullable) NSString *deviceToken;

#pragma mark - Device idiom predicates

/**
 * @brief Whether this is an iPad.
 *
 * Computed as @c (deviceType @c | @c 1) @c == @c 7, so it is true for device types 6 and 7. The
 * @c orr with 1 folds the pair into a single comparison.
 * @ghidraAddress 0x82c0
 */
@property(nonatomic, readonly) BOOL isPad;
/**
 * @brief Whether this is a retina iPhone.
 *
 * Computed as @c (deviceType @c - @c 1) @c < @c 5 unsigned, so it is true for device types 1 to 5.
 * @ghidraAddress 0x82dc
 */
@property(nonatomic, readonly) BOOL isPhoneRetina;
/**
 * @brief Whether the screen has the taller four-inch aspect ratio.
 *
 * Computed as @c (deviceType @c - @c 2) @c < @c 4 unsigned, so it is true for device types 2 to 5.
 * @ghidraAddress 0x82f8
 */
@property(nonatomic, readonly) BOOL is4inchAspect;
/**
 * @brief Whether this is a retina iPad.
 *
 * Computed as @c deviceType @c == @c 7 exactly, which is the narrower half of @c isPad.
 * @ghidraAddress 0x8314
 */
@property(nonatomic, readonly) BOOL isPadRetina;

#pragma mark - Game Center

/**
 * @brief Whether Game Center is usable in this session.
 *
 * Backed by @c _gameCenterAvailable (0x349604). The getter is a @c ldrb, so the ivar is one byte
 * and the type is @c BOOL rather than a wider integer.
 * @ghidraAddress 0xb868 (getter)
 */
@property(nonatomic, readonly) BOOL gameCenterAvailable;
/**
 * @brief The local player's Game Center alias, or nil when it cannot be had.
 *
 * Computed rather than stored. It returns nil on two separate paths: when @c gameCenterAvailable is
 * NO, and when @c GKLocalPlayer.localPlayer is not authenticated.
 * @ghidraAddress 0x832c
 */
@property(nonatomic, readonly, nullable) NSString *gameCenterName;

/**
 * @brief Marks Game Center unusable for the rest of the session.
 *
 * The whole body is a single store of zero into @c _gameCenterAvailable; nothing is torn down.
 * @ghidraAddress 0x83bc
 */
- (void)disableGameCenter;
/**
 * @brief Starts Game Center authentication, if it is available and not already done.
 *
 * Returns immediately when @c gameCenterAvailable is NO, and also when
 * @c GKLocalPlayer.localPlayer is already authenticated — the handler is only installed on the
 * not-yet-authenticated path.
 * @ghidraAddress 0x83cc
 */
- (void)loginGameCenter;

#pragma mark - Presentation

/**
 * @brief The currently-selected interface theme.
 *
 * Backed by @c _currentTheme (0x34960c). The getter is @c ldr @c w0 — a 4-byte load — so the ivar
 * is a 32-bit integer and is spelled @c unsigned @c int rather than @c NSInteger. The signedness is
 * not a guess: @c -changeTheme: boxes the same value with @c +[NSNumber numberWithUnsignedInt:] at
 * 0x85e4 before writing it to the defaults.
 * @ghidraAddress 0xb888 (getter)
 */
@property(nonatomic, readonly) JubeatTheme currentTheme;
/**
 * @brief The installed marker set, as loaded from disk.
 * @ghidraAddress 0xb9a8 (getter)
 */
@property(nonatomic, readonly) id markerList;

#pragma mark - Download and store selection

/**
 * @brief The identifier of the jcf content download currently in progress.
 *
 * Cleared to nil by @c -resetDownLoadIndex.
 * @ghidraAddress 0xb898 (getter)
 */
@property(nonatomic, readonly) id jcfDownloadID;
/**
 * @brief The genre selected in the store. Backed by @c _storeGenreID (0x349618).
 * @ghidraAddress 0xb968 (getter)
 */
@property(nonatomic, readonly) id storeGenreID;
/**
 * @brief The pack selected in the store. Backed by @c _storePackID (0x34961c).
 * @ghidraAddress 0xb978 (getter)
 */
@property(nonatomic, readonly) id storePackID;
/**
 * @brief The campaign selected in the store. Backed by @c _storeCampaignID (0x349620).
 * @ghidraAddress 0xb988 (getter)
 */
@property(nonatomic, readonly) id storeCampaignID;
/**
 * @brief The banner image file name for the current campaign.
 * @ghidraAddress 0xb9b8 (getter)
 * @ghidraAddress 0xb9c8 (setter)
 */
@property(nonatomic, strong) id campaignImageName;
/**
 * @brief The on-disk path of the current campaign's banner image.
 * @ghidraAddress 0xb9dc (getter)
 * @ghidraAddress 0xb9ec (setter)
 */
@property(nonatomic, strong) id campaignImagePath;
/**
 * @brief The mission text shown on the store screen.
 * @ghidraAddress 0xbb00 (getter)
 * @ghidraAddress 0xbb10 (setter)
 */
@property(nonatomic, strong) id storeMissionText;
/**
 * @brief The music-list search term currently in effect.
 * @ghidraAddress 0xb998 (getter)
 */
@property(nonatomic, readonly) id searchString;
/**
 * @brief The running total of in-app purchases.
 *
 * A 4-byte load, so @c int rather than @c NSInteger.
 * @ghidraAddress 0xba40 (getter)
 */
@property(nonatomic, readonly) int totalPurchaseAmount;

#pragma mark - Gameplay option flags

/**
 * @brief Whether the random-note option is enabled. Written by @c -setRandomFlag:.
 * @ghidraAddress 0xb8c8 (getter)
 */
@property(nonatomic, readonly) BOOL isRandom;
/**
 * @brief Whether the extend option is enabled. Written by @c -setExtendFlag:.
 * @ghidraAddress 0xb8e8 (getter)
 */
@property(nonatomic, readonly) BOOL isExtend;
/**
 * @brief Whether the hold option is enabled. Written by @c -setHoldFlag:.
 * @ghidraAddress 0xb8f8 (getter)
 */
@property(nonatomic, readonly) BOOL isHold;
/**
 * @brief Whether the installed marker set is licensed for play.
 *
 * Latched to YES by @c -markerDownloadComplete and never cleared by any compiled setter.
 * @ghidraAddress 0xb8d8 (getter)
 */
@property(nonatomic, readonly) BOOL isMarkerLegal;
/**
 * @brief Whether the rectangle-wave sound option is enabled.
 * @ghidraAddress 0xb908 (getter)
 * @ghidraAddress 0xb918 (setter)
 */
@property(nonatomic) BOOL isRectangleWave;
/**
 * @brief Whether marker direction is randomised.
 * @ghidraAddress 0xb928 (getter)
 * @ghidraAddress 0xb938 (setter)
 */
@property(nonatomic) BOOL isMarkerDirRandom;
/**
 * @brief Whether automatic play is enabled.
 * @ghidraAddress 0xb948 (getter)
 * @ghidraAddress 0xb958 (setter)
 */
@property(nonatomic) BOOL bEnableAutoPlay;
/**
 * @brief Whether the reward feature is enabled for this session.
 * @ghidraAddress 0xbac0 (getter)
 */
@property(nonatomic, readonly) BOOL bEnableReward;

#pragma mark - Collaboration modes

/**
 * @brief Whether the naga/cora collaboration mode is active.
 * @ghidraAddress 0xba80 (getter)
 * @ghidraAddress 0xba90 (setter)
 */
@property(nonatomic) BOOL isNagaCoraMode;
/**
 * @brief Whether the hinabita collaboration mode is active.
 * @ghidraAddress 0xbaa0 (getter)
 * @ghidraAddress 0xbab0 (setter)
 */
@property(nonatomic) BOOL isHinabitaMode;

#pragma mark - Challenge state

/**
 * @brief Whether the challenge is open.
 * @ghidraAddress 0xba00 (getter)
 */
@property(nonatomic, readonly) BOOL bChallengeOpen;
/**
 * @brief Whether challenge mode is engaged. Written by @c -setChallengeMode:.
 * @ghidraAddress 0xba10 (getter)
 */
@property(nonatomic, readonly) BOOL bChallengeMode;
/**
 * @brief The music identifier for the current challenge. A 4-byte load, so @c int.
 * @ghidraAddress 0xba20 (getter)
 */
@property(nonatomic, readonly) int challengeMusicID;
/**
 * @brief The difficulty for the current challenge. A 4-byte load, so @c int.
 * @ghidraAddress 0xba30 (getter)
 */
@property(nonatomic, readonly) int challengeDifficulty;

#pragma mark - Notifications

/**
 * @brief The URL of the in-game notification page.
 *
 * Proven to be an @c NSURL: @c -setNotificationPageURL:updateTime: builds it with
 * @c +[NSURL URLWithString:] at 0x8d1c, whose class pointer at 0x3480b0 resolves to
 * @c _OBJC_CLASS_$_NSURL.
 * @ghidraAddress 0xb8a8 (getter)
 */
@property(nonatomic, readonly, nullable) NSURL *notificationURL;
/**
 * @brief The update timestamp that accompanies @c notificationURL.
 *
 * Retained as handed in by @c -setNotificationPageURL:updateTime:. Its concrete class is not yet
 * proven; the two callers, @c -downloaderFinished: at 0x1f078 and @c -pushClose: at 0x183090,
 * belong to classes that have not been reconstructed.
 * @ghidraAddress 0xb8b8 (getter)
 */
@property(nonatomic, readonly, nullable) id notificationTime;
/**
 * @brief The queued push notifications, persisted to disk between launches.
 *
 * Proven mutable: @c -loadNotification stores the result of sending @c -mutableCopy to the
 * unarchived object at 0xa828, so the ivar holds a mutable array rather than an immutable one.
 * @ghidraAddress 0xba50 (getter)
 */
@property(nonatomic, readonly) NSMutableArray *pushNotificationList;
/**
 * @brief The payload of the remote push that launched the application.
 *
 * Written in exactly one place: @c -application:didFinishLaunchingWithOptions: stores a @c -copy of
 * @c launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey] at 0x96b0, which is why the
 * type is @c NSDictionary. It stays nil on an ordinary launch, and the launch handler uses its
 * being non-nil as the signal to report the notification back to the servers.
 * @ghidraAddress 0xbb24 (getter)
 */
@property(nonatomic, readonly, nullable) NSDictionary *remotePushInfo;
/**
 * @brief Whether the device token still needs to be sent to the servers.
 * @ghidraAddress 0xbad0 (getter)
 * @ghidraAddress 0xbae0 (setter)
 */
@property(nonatomic) BOOL bSendPushID;

#pragma mark - Recommendations

/**
 * @brief The number of unseen recommendation entries. A 4-byte load, so @c int.
 * @ghidraAddress 0xba60 (getter)
 * @ghidraAddress 0xba70 (setter)
 */
@property(nonatomic) int hasNewRecommendNum;

/**
 * @brief The Game Center leaderboard identifier for the total-score board.
 *
 * Two literals selected by @c isPad: "jubeat.totalscore" on iPad and "jubeat.totalscorephone"
 * elsewhere. The binary picks between them with a @c csel rather than a branch.
 * @ghidraAddress 0x8550
 */
@property(nonatomic, readonly) NSString *totalScoreLeaderboardCategory;

#pragma mark - Presentation mutators

/**
 * @brief Selects the interface theme, persists it, and returns to the title screen.
 *
 * Writes @c _currentTheme, mirrors it into @c NSUserDefaults under the key "PrefTheme" as an
 * @c NSNumber, synchronises, and then sends @c -changeThemeAndGoTitle to @c rootViewCtrl.
 * @ghidraAddress 0x8584
 */
- (void)changeTheme:(JubeatTheme)theme;
/**
 * @brief Hands a colour array to the knit-colour manager.
 * @ghidraAddress 0x8f38
 */
- (void)setKnitColor:(NSArray *)knitColor;
/**
 * @brief Switches the title screen to the current event's presentation.
 *
 * When @c isHinabitaMode is set it first tells the knit-colour manager to use colour type 4; the
 * type is a bare immediate in the binary, not a named constant. It then sends
 * @c -changeTitleTheme to @c rootViewCtrl unconditionally, so the non-hinabita path still
 * refreshes the title.
 * @ghidraAddress 0x868c
 */
- (void)switchTitleEvent;
/**
 * @brief Unlocks the copious marker set and reloads the markers.
 *
 * Writes @c YES to @c NSUserDefaults under "PrefCopiousUnlocked", synchronises, and then sends
 * @c -reloadMarkers to @c rootViewCtrl. Unconditional: there is no check of the current value, so
 * calling it again rewrites the same flag and reloads again.
 * @ghidraAddress 0x871c
 */
- (void)enableCopiousMarkers;

/**
 * @brief The per-install identifier, persisted in the keychain.
 *
 * The selector name is misleading and is the binary's own: this has nothing to do with any music
 * list. It looks up a generic-password item keyed on the account "ApplicationUniqueID" and the
 * bundle identifier as the service, and returns its stored UTF-8 payload. When the item is absent,
 * or is present but its payload does not decode, it mints a fresh @c CFUUID, adds it to the
 * keychain, and returns that.
 *
 * Because the item is stored with @c kSecAttrAccessibleAfterFirstUnlock and never deleted, the
 * value survives reinstalling the application, which is what makes @c +clientInfo's "uuid" entry a
 * stable per-install identifier.
 * @ghidraAddress 0x8814
 */
- (NSString *)musicListKey;

#pragma mark - Validation

/**
 * @brief Whether a string is non-empty and consists only of decimal digits.
 *
 * Scans with an explicit character set built from the literal "0123456789" rather than using
 * @c NSCharacterSet.decimalDigitCharacterSet, so the non-ASCII digits that predefined set would
 * accept are rejected here.
 *
 * Two details are easy to lose. The scanner comes from
 * @c +[NSScanner localizedScannerWithString:], not the plain @c +scannerWithString:, so it carries
 * the current locale. And its @c charactersToBeSkipped is explicitly set to nil, which disables the
 * default whitespace skipping — without that a string of spaces and digits would pass.
 * @ghidraAddress 0x8fa8
 */
- (BOOL)digitStringCheck:(nullable NSString *)string;
/**
 * @brief Latches @c bEnableReward on.
 *
 * As with @c -markerDownloadComplete, this only ever sets the flag; nothing clears it.
 * @ghidraAddress 0x8f24
 */
- (void)rewardEnable;

#pragma mark - Licence

/**
 * @brief The build's licence date.
 *
 * Surprising but faithful: this is a hardcoded string literal, not a computed or stored date. The
 * CFString at 0x2d4300 points at 19 bytes reading "2015-04-14 17:00:02", and the method returns it
 * through @c objc_retainAutorelease with no formatting of any kind.
 * @ghidraAddress 0x8dd4
 */
- (NSString *)getCurrentLicenseDate;
/**
 * @brief The localized use-policy message, or nil when the bundle has no translation for it.
 *
 * Looks up the key "Use policy Message" with @c -localizedStringForKey:value:table:, passing an
 * empty default and a nil table. When the lookup comes back equal to that empty default the method
 * returns nil rather than the empty string, so callers can test for absence.
 * @ghidraAddress 0x8e00
 */
- (nullable NSString *)getCurrentLicenseMessage;

#pragma mark - Challenge mutators

/** @brief Clears @c bChallengeOpen. @ghidraAddress 0x8ea0 */
- (void)dropChallengeOpenFlag;
/**
 * @brief Promotes a pending challenge into challenge mode.
 *
 * When @c bChallengeOpen is set this sets @c bChallengeMode; either way it then clears
 * @c bChallengeOpen, so the flag is consumed whether or not it fired.
 * @ghidraAddress 0x8eb0
 */
- (void)moveChallengeOpenFlag;
/** @brief Sets @c bChallengeMode. @ghidraAddress 0x8ed8 */
- (void)setChallengeMode:(BOOL)challengeMode;
/**
 * @brief Selects the challenge's music and difficulty, and engages challenge mode.
 *
 * Note that it also sets @c bChallengeMode to YES as a side effect, which the selector name does
 * not suggest.
 * @ghidraAddress 0x8ee8
 */
- (void)setChallengeMusic:(int)musicID diff:(int)difficulty;
/** @brief Sets @c totalPurchaseAmount. @ghidraAddress 0x8f14 */
- (void)setTotalAmount:(int)amount;

#pragma mark - Notification persistence

/**
 * @brief The on-disk path of the persisted notification queue, creating its directory if needed.
 *
 * Builds @c <caches>/notification, creates that directory with intermediate directories when it
 * does not already exist, and returns @c <caches>/notification/noti.txt.
 * @ghidraAddress 0xa530
 */
- (NSString *)getNotificationFilePath;
/**
 * @brief Reads the persisted notification queue back into @c pushNotificationList.
 *
 * A missing or unreadable file leaves the property untouched rather than clearing it.
 * @ghidraAddress 0xa7a4
 */
- (void)loadNotification;
/**
 * @brief Writes @c pushNotificationList to disk, or deletes the file when the queue is empty.
 *
 * The archive is built before the emptiness test, so an empty queue archives an empty array and
 * then throws the result away.
 * @ghidraAddress 0xa66c
 */
- (void)saveNotification;
/**
 * @brief Whether a scheduled fire time is still in the future.
 *
 * Compares the current Unix time, truncated toward zero from
 * @c -[NSDate timeIntervalSince1970], against @c fireTime and answers YES when the current time is
 * less than or equal to it. Note the comparison is inclusive, so a notification due at exactly the
 * current second still counts as active.
 * @ghidraAddress 0xb534
 */
- (BOOL)pushActiveCheck:(NSInteger)fireTime;
/**
 * @brief Removes queued notifications from the front until one has not expired, and returns it.
 *
 * Every entry it inspects is removed from the queue whether or not it is returned, so expired
 * entries are discarded as a side effect of looking for a live one. Each entry's fire time is read
 * from its "expire" key.
 *
 * The queue is only persisted when the loop actually ran: an already-empty queue returns nil
 * without calling @c -saveNotification, whereas both loop exits do call it.
 * @ghidraAddress 0xb594
 */
- (nullable NSDictionary *)popNotification;

#pragma mark - Launch

/**
 * @brief Classifies the device, restores preferences, builds the window, and starts every manager.
 *
 * The largest method in the class at 0xF24 bytes, and the one that reaches most of the application.
 * It runs, in order: a discarded @c arc4random; the launch-options remote-notification route, which
 * is a third copy of the scheme routing and ends by stashing the payload in @c remotePushInfo; the
 * device classifier that fills in @c deviceType; the theme restore; the Game Center probe; the
 * keychain identifier and User-Agent; three user-defaults repairs; the Core Data reset; the window
 * and root controller; the purchase and store managers; the audio session; and finally notification
 * registration. It always returns YES.
 *
 * Several small oddities are reproduced rather than corrected and are listed in TYPES_PENDING.md:
 * the discarded @c arc4random and @c systemVersion, the four unread @c NSError out-parameters, and
 * the notification registration calls being made in the opposite order to Apple's.
 * @ghidraAddress 0x933c
 */
- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(nullable NSDictionary *)launchOptions;

#pragma mark - URL scheme

/**
 * @brief Handles a @c jubeatplus:// URL, routing it to the store or to a content download.
 *
 * Always returns YES, on every path including the one where the scheme does not match, so the
 * application never reports a URL as unhandled.
 *
 * Two of its four routes are unreachable as compiled — see the implementation comment at the
 * "jbtstore" arm.
 * @ghidraAddress 0x9090
 */
- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url;

#pragma mark - Push payload

/**
 * @brief Flattens an APNs payload into the shape the notification queue stores.
 *
 * Returns nil when the payload has no "aps" entry. Otherwise it copies, each only when present:
 * "alert" from inside "aps" — stored under the different key "body" — plus "sound" from inside
 * "aps", and "url", "expire", and "id" from the top level.
 *
 * The "alert" to "body" rename is the only key that changes name; every other entry keeps its own.
 * @ghidraAddress 0xa990
 */
- (nullable NSMutableDictionary *)apsDictionary:(NSDictionary *)userInfo;

#pragma mark - Notification registration

/**
 * @brief Proceeds to remote-notification registration once the user has answered the prompt.
 *
 * The settings argument is ignored: the binary does not inspect which types were granted, so this
 * registers even when the user allowed nothing.
 * @ghidraAddress 0xa868
 */
- (void)application:(UIApplication *)application
    didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings;
/**
 * @brief Stores the APNs device token as a bare hexadecimal string.
 *
 * Takes @c -description of the @c NSData and strips the three literals "<", ">", and " " from it in
 * that order. This is the pre-iOS-13 idiom for turning a token into hex; it depends on
 * @c NSData.description's format and is reproduced as written.
 * @ghidraAddress 0xa8a4
 */
- (void)application:(UIApplication *)application
    didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken;
/**
 * @brief Does nothing.
 *
 * Surprising but faithful: the compiled method at 0xa98c is a single @c ret. A failed registration
 * is neither recorded nor reported, so @c deviceToken simply stays nil.
 * @ghidraAddress 0xa98c
 */
- (void)application:(UIApplication *)application
    didFailToRegisterForRemoteNotificationsWithError:(NSError *)error;

#pragma mark - Notification delivery

/**
 * @brief Queues a local notification for in-app display, or routes it if the user tapped it.
 *
 * A notification with no @c userInfo is dropped. Otherwise the payload is flattened through
 * @c -apsDictionary: and the application state decides which of two unrelated things happens.
 *
 * In @c UIApplicationStateActive the system shows no banner, so the payload is appended to
 * @c pushNotificationList, persisted, and handed to the root controller to present. Otherwise the
 * notification was tapped, and the @c "url" entry is routed by scheme: @c jbtstore:// fills in
 * @c storePackID or @c storeGenreID, @c jbtchallenge:// raises @c bChallengeOpen, and
 * @c jbtgift:// fills in @c storeCampaignID.
 *
 * This is the working twin of @c -application:handleOpenURL:. Both route the same three tokens, but
 * this one reads them off @c NSURL.scheme, where they are, rather than off a path component.
 * @ghidraAddress 0xac48
 */
- (void)application:(UIApplication *)application
    didReceiveLocalNotification:(UILocalNotification *)notification;
/**
 * @brief The remote twin of @c -application:didReceiveLocalNotification:, plus a report back.
 *
 * Clears the badge, then runs the same two arms on the same @c applicationState test and with the
 * same scheme routing. Three differences from the local variant, all verified rather than assumed:
 *
 * - There is no @c userInfo nil test at all. The remote payload is the argument itself, so the
 *   three sends the local variant makes to fetch it are absent.
 * - The routing arms fall through rather than returning, converging on the report at 0xb4e4. Even
 *   a URL matching no scheme is reported.
 * - @c -apsDictionary: is called before the split, so on the routing path the dictionary is built
 *   and released without ever being read.
 *
 * The report is @c -responseRemoteNotification:pushInfo: with @c NO, meaning the notification
 * arrived at a running app. @c -application:didFinishLaunchingWithOptions: passes @c YES for the
 * cold-launch case at 0x9dfc.
 * @ghidraAddress 0xb0c8
 */
- (void)application:(UIApplication *)application
    didReceiveRemoteNotification:(NSDictionary *)userInfo;

#pragma mark - Application lifecycle

/**
 * @brief Schedules the coin-refill notification as the application leaves the foreground.
 *
 * The whole body is @c [[ChallengeStatus sharedStatus] createCoinNotification]; the
 * @c UIApplication argument is ignored.
 * @ghidraAddress 0xb6f8
 */
- (void)applicationDidEnterBackground:(UIApplication *)application;
/**
 * @brief Does nothing.
 *
 * Surprising but faithful: the compiled method is a single @c ret. It is present only to satisfy
 * the delegate protocol.
 * @ghidraAddress 0xb740
 */
- (void)applicationWillResignActive:(UIApplication *)application;
/**
 * @brief Clears the icon badge and cancels every pending local notification.
 *
 * Note that it messages @c UIApplication.sharedApplication twice rather than reusing the argument
 * it was handed, which is ignored.
 * @ghidraAddress 0xb744
 */
- (void)applicationDidBecomeActive:(UIApplication *)application;
/**
 * @brief Shuts the purchase manager down and flushes the score records.
 * @ghidraAddress 0xb7c8
 */
- (void)applicationWillTerminate:(UIApplication *)application;
/**
 * @brief Does nothing.
 *
 * As with @c -applicationWillResignActive:, the compiled method is a single @c ret. The binary
 * takes no action on a memory warning.
 * @ghidraAddress 0xb844
 */
- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application;

#pragma mark - Download selection mutators

/** @brief Clears @c jcfDownloadID. @ghidraAddress 0x8c38 */
- (void)resetDownLoadIndex;
/** @brief Clears @c storeGenreID. @ghidraAddress 0x8c50 */
- (void)resetDownloadGenreID;
/** @brief Sets @c storeGenreID. @ghidraAddress 0x8c68 */
- (void)setDownloadGenreID:(nullable id)genreID;
/** @brief Clears @c storePackID. @ghidraAddress 0x8c7c */
- (void)resetDownloadPackID;
/** @brief Sets @c storePackID. @ghidraAddress 0x8c94 */
- (void)setDownloadPackID:(nullable id)packID;
/** @brief Clears @c storeCampaignID. @ghidraAddress 0x8ca8 */
- (void)resetCampaignID;
/** @brief Sets @c storeCampaignID. @ghidraAddress 0x8cc0 */
- (void)setCampaignID:(nullable id)campaignID;

#pragma mark - Notification page mutators

/**
 * @brief Records the notification page endpoint and the timestamp that goes with it.
 *
 * A nil @c pageURL clears @c notificationURL rather than storing a URL built from nil.
 * @ghidraAddress 0x8cd4
 */
- (void)setNotificationPageURL:(nullable NSString *)pageURL updateTime:(nullable id)updateTime;

#pragma mark - Option flag mutators

/** @brief Sets @c isRandom. @ghidraAddress 0x8d7c */
- (void)setRandomFlag:(BOOL)flag;
/** @brief Sets @c isExtend. @ghidraAddress 0x8d8c */
- (void)setExtendFlag:(BOOL)flag;
/** @brief Sets @c isHold. @ghidraAddress 0x8d9c */
- (void)setHoldFlag:(BOOL)flag;
/** @brief Sets @c searchString. @ghidraAddress 0x8dac */
- (void)setSearchString:(nullable id)searchString;
/** @brief Latches @c isMarkerLegal to YES. @ghidraAddress 0x8dc0 */
- (void)markerDownloadComplete;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
