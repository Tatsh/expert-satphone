/** @file
 * The application delegate for jubeat plus: owns the root view controller, exposes the device and
 * client identification the servers are told about, holds the persisted gameplay option flags and
 * store selection state, and drives the application lifecycle and notification handling.
 *
 * Reconstructed from Ghidra program Jubeat (class JubeatAppDelegate, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: the property list below is complete — it is every accessor in the two
 * blocks at 0x8c38-0x8dd4 and 0xb848-0xbb34, all of which were disassembled rather than read from
 * the decompile. The ivar names come from the ObjC ivar offset globals at 0x349600-0x349690, which
 * is runtime metadata and therefore authoritative. The declared methods are those whose bodies have
 * been recovered; the class's remaining methods (notably
 * -application:didFinishLaunchingWithOptions: at 0x933c and the notification handlers) are not
 * declared yet.
 *
 * Where a property's concrete class has not been proven from the code, the doc comment says so
 * rather than guessing. Those types are tightened as each writer is reconstructed.
 */

#import <UIKit/UIKit.h>

@class RootViewController;

NS_ASSUME_NONNULL_BEGIN

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
 * @brief The device idiom and screen class this build has classified the device as.
 *
 * Backed by @c _deviceType (0x349600). This is an INTEGER, not an object, despite the getter
 * loading a full 64-bit word: the four predicates below load the same ivar and compare it against
 * the small constants 1 to 7, which only makes sense for a scalar. It is 8 bytes wide, so it is
 * spelled @c NSInteger.
 *
 * The individual values are not named here because the binary never names them; what is proven is
 * the set membership each predicate tests. The writer has not been reconstructed yet, so the
 * enumeration's spelling is deliberately left open.
 * @ghidraAddress 0xb878 (getter)
 */
@property(nonatomic, readonly) NSInteger deviceType;
/**
 * @brief The APNs device token, retained as received.
 *
 * Backed by @c _deviceToken (0x349670). Written by
 * @c -application:didRegisterForRemoteNotificationsWithDeviceToken: at 0xa8a4, which is not yet
 * reconstructed, so the concrete class is not asserted.
 * @ghidraAddress 0xbaf0 (getter)
 */
@property(nonatomic, readonly) id deviceToken;

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
@property(nonatomic, readonly) unsigned int currentTheme;
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
 * @brief The payload of the remote push that launched or resumed the application.
 * @ghidraAddress 0xbb24 (getter)
 */
@property(nonatomic, readonly) id remotePushInfo;
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
- (void)changeTheme:(unsigned int)theme;
/**
 * @brief Hands a colour array to the knit-colour manager.
 * @ghidraAddress 0x8f38
 */
- (void)setKnitColor:(NSArray *)knitColor;
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
