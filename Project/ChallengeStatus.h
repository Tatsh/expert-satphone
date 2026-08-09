/** @file
 * The challenge subsystem's shared state object.
 *
 * Reconstructed from Ghidra program Jubeat (class ChallengeStatus, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base. The class object is at 0x348150.
 *
 * ChallengeStatus is the challenge-mode data hub: a @c +sharedStatus singleton that holds the
 * player's name and search identifier, the coin/nail/cube economy, the scratch-card line-up and
 * per-panel info table, the mission sheets and their rewards, the server/client clock, and the
 * subsystem's various URLs. It parses server-response dictionaries into that state and vends
 * derived values (time-left strings, per-tune enabled times, scratch panel counts).
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class ChallengeModeRootView;
@class ScratchInfo;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Shared state for the challenge mode, including the play-coin economy.
 */
@interface ChallengeStatus : NSObject

#pragma mark - Singleton

/**
 * @brief The shared instance.
 *
 * The selector is @c sharedStatus rather than the @c sharedManager this binary uses elsewhere.
 * Guarded with @c dispatch_once .
 * @ghidraAddress 0x1cac90
 */
@property(class, nonatomic, readonly) ChallengeStatus *sharedStatus;

#pragma mark - Lifecycle

/**
 * @brief Sets the initial economy defaults and computes the phone layout scale.
 * @ghidraAddress 0x1cad10
 */
- (instancetype)init;

/**
 * @brief Clears the URLs, the initialisation flags, and the line-up image cache, and restores the
 * economy defaults.
 * @ghidraAddress 0x1cae84
 */
- (void)resetStatus;

/**
 * @brief Builds the whole state from a server-response dictionary, then marks it initialised.
 * @param dictionary The server-response dictionary.
 * @ghidraAddress 0x1caf8c
 */
- (void)initWithDictionary:(nullable NSDictionary *)dictionary;

#pragma mark - State updates

/**
 * @brief Refreshes the economy, scratch, URL, present, consume, and mission state from a
 * server-response dictionary. Unlike @c -initWithDictionary: it does not touch the user info,
 * scratch identifier, server time, scratch time, or the initialised flag.
 * @param dictionary The server-response dictionary.
 * @ghidraAddress 0x1cb114
 */
- (void)updateState:(nullable NSDictionary *)dictionary;

/**
 * @brief Reads the per-action consume costs (play coin, scratch cube, rest cube) from the
 * dictionary when present.
 * @param dictionary The server-response dictionary.
 * @ghidraAddress 0x1cb238
 */
- (void)updateConsume:(nullable NSDictionary *)dictionary;

/**
 * @brief Stores the player's display name.
 * @param name The new name.
 * @ghidraAddress 0x1cb36c
 */
- (void)updateName:(nullable NSString *)name;

/**
 * @brief Applies a scratch store dictionary to the info-table entry at the given index (only when
 * the dictionary carries a @c music_id ).
 * @param index The scratch panel index.
 * @param dict The store dictionary for that panel.
 * @ghidraAddress 0x1cb380
 */
- (void)setScratchItem:(int)index dict:(nullable NSDictionary *)dict;

/**
 * @brief Reads the unread-present count from the dictionary when present.
 * @param dictionary The server-response dictionary.
 * @ghidraAddress 0x1cb43c
 */
- (void)updatePresentNum:(nullable NSDictionary *)dictionary;

/**
 * @brief Sets the unread-present count directly.
 * @param num The new present count.
 * @ghidraAddress 0x1cb4dc
 */
- (void)setPresentNum:(int)num;

/**
 * @brief Reads the scratch identifier, records whether it changed from the persisted one (setting
 * the refresh flag), and stores it.
 * @param dictionary The server-response dictionary.
 * @ghidraAddress 0x1cb4ec
 */
- (void)updateScratchID:(nullable NSDictionary *)dictionary;

/**
 * @brief Reads the how-to URL when present.
 * @param dictionary The server-response dictionary.
 * @ghidraAddress 0x1cb668
 */
- (void)updateHowtoURL:(nullable NSDictionary *)dictionary;

/**
 * @brief Reads the information URL, storing it only when it differs from the persisted one.
 * @param dictionary The server-response dictionary.
 * @ghidraAddress 0x1cb6d4
 */
- (void)updateInformationURL:(nullable NSDictionary *)dictionary;

/**
 * @brief Persists the current information URL to @c NSUserDefaults and clears the in-memory copy.
 * @ghidraAddress 0x1cb7b4
 */
- (void)saveInformationURL;

/**
 * @brief Reads the personal-information URL, storing it only when it differs from the persisted
 * one.
 * @param dictionary The server-response dictionary.
 * @ghidraAddress 0x1cb880
 */
- (void)updatePersonalInformationURL:(nullable NSDictionary *)dictionary;

/**
 * @brief Persists the current personal-information URL to @c NSUserDefaults and clears the
 * in-memory copy.
 *
 * The selector keeps the binary's "Persision" misspelling.
 * @ghidraAddress 0x1cb960
 */
- (void)savePersionalInformationURL;

/**
 * @brief Clears the on-disk scratch data when the refresh flag is set, then clears the flag.
 * @ghidraAddress 0x1cba2c
 */
- (void)updateScratchItemDir;

/**
 * @brief Rebuilds the scratch info table (16 panels) from the @c scratch_panel array, placing each
 * store item at its @c position .
 * @param dictionary The server-response dictionary.
 * @ghidraAddress 0x1cba70
 */
- (void)updateScratchTable:(nullable NSDictionary *)dictionary;

/**
 * @brief Rebuilds the scratch line-up from the @c music_list array.
 * @param dictionary The server-response dictionary.
 * @ghidraAddress 0x1cbd64
 */
- (void)updateScratchLineup:(nullable NSDictionary *)dictionary;

/**
 * @brief Reads the player's name and search identifier, falling back to the Editor account key when
 * no search identifier is present.
 * @param dictionary The server-response dictionary.
 * @ghidraAddress 0x1cbea4
 */
- (void)updateUserInfo:(nullable NSDictionary *)dictionary;

/**
 * @brief Parses the scratch-reset end time (@c end , JST) into @c scratchResetDate .
 * @param dictionary The server-response dictionary.
 * @ghidraAddress 0x1cc00c
 */
- (void)updateScratchTimeState:(nullable NSDictionary *)dictionary;

/**
 * @brief Parses the server time (@c server_time , JST), resets the monthly purchase counters when
 * the month rolled over, records the client time, and computes the server-time delay.
 * @param dictionary The server-response dictionary.
 * @ghidraAddress 0x1cc158
 */
- (void)updateServerTime:(nullable NSDictionary *)dictionary;

/**
 * @brief Reads the cube count (@c jCube ) when present.
 * @param dictionary The server-response dictionary.
 * @ghidraAddress 0x1cc4b0
 */
- (void)updateCubeState:(nullable NSDictionary *)dictionary;

/**
 * @brief Reads the coin regeneration time, coin limit, and coin count, then recomputes the coin
 * regeneration start date.
 * @param dictionary The server-response dictionary.
 * @ghidraAddress 0x1cc550
 */
- (void)updateCoinState:(nullable NSDictionary *)dictionary;

/**
 * @brief Reads the scratch nail count (@c scratch_nail ) when present.
 * @param dictionary The server-response dictionary.
 * @ghidraAddress 0x1cc840
 */
- (void)updateNailState:(nullable NSDictionary *)dictionary;

/**
 * @brief Advances the coin count and regeneration date for every fully regenerated coin.
 * @ghidraAddress 0x1cc8e0
 */
- (void)restCoinNum;

/**
 * @brief Rebuilds the enabled mission sheets from the @c sheet_list dictionary, ordered ascending
 * by numeric sheet identifier.
 * @param dictionary The server-response dictionary.
 * @ghidraAddress 0x1cc9d0
 */
- (void)updateChallengeMission:(nullable NSDictionary *)dictionary;

/**
 * @brief Applies a nail-exchange response: refreshes the nail and cube counts.
 * @param dictionary The server-response dictionary.
 * @ghidraAddress 0x1cce10
 */
- (void)exchangeNail:(nullable NSDictionary *)dictionary;

/**
 * @brief Applies an open-scratch response: refreshes nail and cube counts and stores the panel's
 * store item.
 * @param dictionary The server-response dictionary.
 * @param index The scratch panel index.
 * @ghidraAddress 0x1cce70
 */
- (void)openScratch:(nullable NSDictionary *)dictionary index:(int)index;

/**
 * @brief Applies a rest-play response: refreshes the coin and cube state.
 * @param dictionary The server-response dictionary.
 * @ghidraAddress 0x1cceec
 */
- (void)restPlayCoin:(nullable NSDictionary *)dictionary;

/**
 * @brief Applies a change-scratch-nail response: refreshes the nail and cube counts.
 * @param dictionary The server-response dictionary.
 * @ghidraAddress 0x1ccf4c
 */
- (void)changeScratchNail:(nullable NSDictionary *)dictionary;

/**
 * @brief Applies a cube-purchase-success response: refreshes the cube count.
 * @param dictionary The server-response dictionary.
 * @ghidraAddress 0x1ccfac
 */
- (void)cubePurchaseSuccess:(nullable NSDictionary *)dictionary;

/**
 * @brief Applies a music-detail response to the panel's scratch info, then refreshes the server
 * time.
 * @param dictionary The server-response dictionary.
 * @param index The scratch panel index.
 * @ghidraAddress 0x1ccfb8
 */
- (void)openMusicDetail:(nullable NSDictionary *)dictionary index:(int)index;

/**
 * @brief Stores the session seed and refreshes the coin state.
 * @param dictionary The server-response dictionary.
 * @ghidraAddress 0x1cd064
 */
- (void)playMusic:(nullable NSDictionary *)dictionary;

/**
 * @brief Applies a present-received response: refreshes the coin, cube, and nail counts.
 * @param dictionary The server-response dictionary.
 * @ghidraAddress 0x1cd0ec
 */
- (void)receivePresent:(nullable NSDictionary *)dictionary;

/**
 * @brief Updates the scratch info entry matching @p musicID with a fresh rank, then returns.
 * @param musicID The tune identifier to match.
 * @param diff The difficulty index.
 * @param rank The new rank.
 * @param index The new index.
 * @ghidraAddress 0x1cd160
 */
- (void)updateMusicRanking:(int)musicID diff:(int)diff rank:(int)rank index:(int)index;

#pragma mark - Derived time values

/**
 * @brief Renders a second count as @c "m:ss" , clamping the minutes to 200.
 * @param interval The interval in seconds.
 * @ghidraAddress 0x1cd2d0
 */
- (nullable NSString *)timeStringFromInterval_Minute:(double)interval;

/**
 * @brief Renders a second count as @c "hh:mm:ss" , clamping the hours to 999.
 * @param interval The interval in seconds.
 * @ghidraAddress 0x1cd35c
 */
- (nullable NSString *)timeStringFromInterval:(double)interval;

/**
 * @brief Seconds remaining until the given date, corrected by the server-time delay.
 * @param date The target date.
 * @ghidraAddress 0x1cd3e8
 */
- (double)getTimeLeft:(nullable NSDate *)date;

/**
 * @brief Seconds until the given panel's tune stops being playable, or -1 when the panel is closed.
 * @param index The scratch panel index.
 * @ghidraAddress 0x1cd47c
 */
- (double)getMusicEnableTime:(int)index;

/**
 * @brief The given panel's enabled time as display text.
 * @param index The scratch panel index.
 * @ghidraAddress 0x1cd54c
 */
- (nullable NSString *)getMusicEnableTimeString:(int)index;

#pragma mark - Line-up image cache

/**
 * @brief Caches a tune's square artwork keyed by its music identifier.
 * @param image The artwork.
 * @param musicID The tune identifier key.
 * @ghidraAddress 0x1cd580
 */
- (void)setLineupImage:(nullable UIImage *)image musicID:(nullable id)musicID;

/**
 * @brief The cached square artwork for a tune, keyed by its music identifier.
 * @param musicID The tune identifier key.
 * @ghidraAddress 0x1cd5dc
 */
- (nullable UIImage *)getLineupImage:(nullable id)musicID;

/**
 * @brief Empties the line-up image cache.
 * @ghidraAddress 0x1cd5f4
 */
- (void)clearLineupImage;

#pragma mark - Scratch panel counts

/**
 * @brief The number of scratch panels not yet opened (those whose info entry has no music
 * identifier).
 * @ghidraAddress 0x1cd60c
 */
- (int)scratchablePanelNum;

/**
 * @brief The number of scratch panels already opened (those whose info entry has a music
 * identifier).
 * @ghidraAddress 0x1cd740
 */
- (int)scratchOpenedPanelNum;

#pragma mark - Notifications

/**
 * @brief Schedules the local notification announcing that play coins have refilled.
 *
 * Called from @c -[JubeatAppDelegate applicationDidEnterBackground:], its only call site. Returns
 * without scheduling when the state is not initialised or when the coin count is not below the
 * limit.
 * @ghidraAddress 0x1cd874
 */
- (void)createCoinNotification;

#pragma mark - Mission sheets

/**
 * @brief Reads the selected sheet identifier (@c select_sheet_id ), defaulting to 0 when absent.
 * @param dictionary The server-response dictionary.
 * @ghidraAddress 0x1cdc30
 */
- (void)updateMissionSheet:(nullable NSDictionary *)dictionary;

/**
 * @brief The currently selected mission sheet, looked up in the mission-file manager.
 * @ghidraAddress 0x1cdcdc
 */
- (nullable ChallengeMissionSheet *)getSelectedMissionSheet;

/**
 * @brief Selects a mission sheet and rebuilds the enabled-sheets list with it re-sorted into place
 * by identifier.
 * @param sheet The sheet to select.
 * @ghidraAddress 0x1cdd48
 */
- (void)setSelectedMissionSheet:(nullable ChallengeMissionSheet *)sheet;

/**
 * @brief The currently selected mission sheet identifier.
 * @ghidraAddress 0x1cdf68
 */
- (int)getSelectedMissionSheetID;

/**
 * @brief Marks the mission-reward items as downloaded.
 * @ghidraAddress 0x1cdf78
 */
- (void)missionRewardDownload;

/**
 * @brief Stores the challenge-mode root view (weak).
 * @param rootView The root view.
 * @ghidraAddress 0x1cdf8c
 */
- (void)setChallengeRootView:(nullable ChallengeModeRootView *)rootView;

#pragma mark - Properties

/**
 * @brief The challenge-mode root view. Weak, per the @c R,W metadata; stored by
 * @c -setChallengeRootView: rather than a synthesised setter.
 * @ghidraAddress 0x1cdfa0
 */
@property(nonatomic, weak, readonly, nullable) ChallengeModeRootView *rootView;

/**
 * @brief The player's display name.
 * @ghidraAddress 0x1cdfc0
 */
@property(nonatomic, strong, nullable) NSString *myName;
/**
 * @brief The player's search identifier.
 * @ghidraAddress 0x1cdfe4
 */
@property(nonatomic, strong, nullable) NSString *mySearchID;
/**
 * @brief The current scratch identifier.
 * @ghidraAddress 0x1ce008
 */
@property(nonatomic, strong, readonly, nullable) NSNumber *scratchID;
/**
 * @brief The parsed server time.
 * @ghidraAddress 0x1ce018
 */
@property(nonatomic, strong, nullable) NSDate *serverDate;
/**
 * @brief The client time captured alongside the server time.
 * @ghidraAddress 0x1ce03c
 */
@property(nonatomic, strong, nullable) NSDate *clientDate;
/**
 * @brief The moment the current coin's regeneration started.
 * @ghidraAddress 0x1ce060
 */
@property(nonatomic, strong, nullable) NSDate *coinRestDate;
/**
 * @brief The date the free-scratch allowance next resets.
 * @ghidraAddress 0x1ce084
 */
@property(nonatomic, strong, nullable) NSDate *scratchResetDate;
/**
 * @brief The current scratch line-up: an array of per-tune dictionaries.
 * @ghidraAddress 0x1ce0a8
 */
@property(nonatomic, strong, nullable) NSArray *scratchLineUp;
/**
 * @brief The scratch info table: one @c ScratchInfo per panel.
 * @ghidraAddress 0x1ce0cc
 */
@property(nonatomic, strong, nullable) NSArray<ScratchInfo *> *scratchInfoTable;
/**
 * @brief The stamp table.
 * @ghidraAddress 0x1ce0f0
 */
@property(nonatomic, strong, readonly, nullable) NSArray *stampTable;
/**
 * @brief The current play-session seed.
 * @ghidraAddress 0x1ce100
 */
@property(nonatomic, strong, nullable) NSString *sessionSeed;

/**
 * @brief The maximum number of play coins. Backed by @c _coinLim .
 * @ghidraAddress 0x1ce124
 */
@property(nonatomic, assign) int coinLim;
/**
 * @brief The number of play coins the player currently holds. Backed by @c _coinNum .
 * @ghidraAddress 0x1ce144
 */
@property(nonatomic, assign) int coinNum;
/**
 * @brief The scratch nail count.
 * @ghidraAddress 0x1ce164
 */
@property(nonatomic, assign) int nailNum;
/**
 * @brief The cube count.
 * @ghidraAddress 0x1ce184
 */
@property(nonatomic, assign) int jCubeNum;
/**
 * @brief Whether the challenge state has been loaded. Backed by @c _bInitialized .
 * @ghidraAddress 0x1ce1a4
 */
@property(nonatomic, assign, readonly) BOOL bInitialized;
/**
 * @brief The number of unread presents shown on the menu's badge. Backed by @c _presentNum .
 * @ghidraAddress 0x1ce1b4
 */
@property(nonatomic, assign, readonly) int presentNum;
/**
 * @brief Whether the mission-reward items have been downloaded. Backed by @c _bItemDownload .
 * @ghidraAddress 0x1ce1c4
 */
@property(nonatomic, assign, readonly) BOOL bItemDownload;
/**
 * @brief The play-coin consume cost.
 * @ghidraAddress 0x1ce1d4
 */
@property(nonatomic, assign) int consumePlayCoin;
/**
 * @brief The scratch-cube consume cost.
 * @ghidraAddress 0x1ce1f4
 */
@property(nonatomic, assign) int consumeScratchCube;
/**
 * @brief The rest-cube consume cost.
 * @ghidraAddress 0x1ce214
 */
@property(nonatomic, assign) int consumeRestCube;
/**
 * @brief The phone's layout scale relative to the pad's. Single precision, per the @c f encoding.
 *
 * Views that lay out in pad coordinates multiply by this on the phone and by nothing on the pad.
 * @ghidraAddress 0x1ce234
 */
@property(nonatomic, assign, readonly) float phoneScreenRate;
/**
 * @brief The how-to URL.
 * @ghidraAddress 0x1ce244
 */
@property(nonatomic, strong, nullable) NSString *howtoURL;
/**
 * @brief The information URL.
 * @ghidraAddress 0x1ce268
 */
@property(nonatomic, strong, nullable) NSString *informationURL;
/**
 * @brief The personal-information URL.
 * @ghidraAddress 0x1ce28c
 */
@property(nonatomic, strong, readonly, nullable) NSString *personalInfoURL;
/**
 * @brief The enabled mission sheets, ordered by identifier.
 * @ghidraAddress 0x1ce29c
 */
@property(nonatomic, strong, readonly, nullable) NSArray *enableMissionSheets;
/**
 * @brief The measured client-to-server clock delay, in seconds.
 * @ghidraAddress 0x1ce2ac
 */
@property(nonatomic, assign) double serverTimeDelay;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
