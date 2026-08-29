/**
 * @file
 * Server endpoint construction.
 *
 * Reconstructed from Ghidra program Jubeat (class ScratchUtil, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The class is complete: all forty-one hand-written class methods are recovered — the full family
 * of server-endpoint URL builders, the scratch/unlock image cache directories, and the tune image
 * and item path builders. The class object is at 0x3482a0.
 *
 * Class properties and bare class methods compile to the same single class method, so declaring
 * @c pushNotificationResponseURL as a class property below claims nothing the binary contradicts.
 * That is unlike an instance property, whose accessor pair is observable — see the note in
 * TYPES_PENDING.md.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Builds the URLs the application talks to.
 */
@interface ScratchUtil : NSObject

/**
 * The endpoint a push-notification receipt is reported to.
 *
 * Built in two formatting steps from four separate literals, and with no branch anywhere in the
 * method — so the endpoint is fixed, with no staging or debug host to select between.
 * @ghidraAddress 0x180524
 */
@property(class, nonatomic, readonly) NSURL *pushNotificationResponseURL;

/**
 * The endpoint the current event type is fetched from.
 *
 * Fetched during @c -[LogoViewController loadView] , so the answer is in hand by the time the
 * splash ends.
 *
 * @return The event-type URL.
 * @ghidraAddress 0x1829e4
 */
+ (nullable NSURL *)getEventTypeURL;

/**
 * The endpoint an inherit code is requested from.
 *
 * Sent by @c -[InheritCodePayView tapCodeOutput:] with the editor identity as its POST body.
 *
 * @return The inherit-code request URL.
 * @ghidraAddress 0x1823cc
 */
+ (nullable NSURL *)getInheritOutputURL;

/**
 * The push-token registration endpoint URL.
 * @return The push-token registration URL.
 * @ghidraAddress 0x180450
 */
+ (nullable NSURL *)pushNotificationIDSendURL;
/**
 * The challenge-mode policy endpoint URL.
 * @return The challenge-mode policy URL.
 * @ghidraAddress 0x1805f8
 */
+ (nullable NSURL *)challengeModePolicyURL;
/**
 * The begin-session endpoint URL.
 * @return The begin-session URL.
 * @ghidraAddress 0x1806cc
 */
+ (nullable NSURL *)challengeSessionURL;
/**
 * The scratch init endpoint URL.
 * @return The scratch-init URL.
 * @ghidraAddress 0x1807a0
 */
+ (nullable NSURL *)challengeInitializeURL;
/**
 * The scratch refresh-display endpoint URL.
 * @return The scratch refresh-display URL.
 * @ghidraAddress 0x180874
 */
+ (nullable NSURL *)challengeSimpleInitializeURL;
/**
 * The previous-scratch-info endpoint URL.
 * @return The previous-scratch-info URL.
 * @ghidraAddress 0x180948
 */
+ (nullable NSURL *)challengePrevScratchURL;
/**
 * The scratch-cell endpoint URL.
 * @return The scratch-cell URL.
 * @ghidraAddress 0x180a1c
 */
+ (nullable NSURL *)nailScratchURL;
/**
 * The exchange-item endpoint URL.
 * @return The exchange-item URL.
 * @ghidraAddress 0x180af0
 */
+ (nullable NSURL *)cubeScratchURL;
/**
 * The music-info endpoint URL.
 * @return The music-info URL.
 * @ghidraAddress 0x180bc4
 */
+ (nullable NSURL *)musicInfoURL;
/**
 * The start-play endpoint URL.
 * @return The start-play URL.
 * @ghidraAddress 0x180c98
 */
+ (nullable NSURL *)playMusicURL;
/**
 * The exchange-item (rest-play-coin) endpoint URL.
 * @return The rest-play-coin URL.
 * @ghidraAddress 0x180d6c
 */
+ (nullable NSURL *)restPlayCoinURL;
/**
 * The send-score endpoint URL.
 * @return The send-score URL.
 * @ghidraAddress 0x180e40
 */
+ (nullable NSURL *)sendMusicScoreURL;
/**
 * The change-name endpoint URL.
 * @return The change-name URL.
 * @ghidraAddress 0x180f14
 */
+ (nullable NSURL *)getUserNameURL;
/**
 * The manage-rival (register) endpoint URL.
 * @return The rival-registration URL.
 * @ghidraAddress 0x180fe8
 */
+ (nullable NSURL *)registRivalURL;
/**
 * The manage-rival (remove) endpoint URL.
 * @return The rival-removal URL.
 * @ghidraAddress 0x1810bc
 */
+ (nullable NSURL *)removeRivalURL;
/**
 * The fetch-name-by-id endpoint URL.
 * @return The fetch-name-by-id URL.
 * @ghidraAddress 0x181190
 */
+ (nullable NSURL *)searchRivalURL;
/**
 * The fetch-rival-list endpoint URL.
 * @return The fetch-rival-list URL.
 * @ghidraAddress 0x181264
 */
+ (nullable NSURL *)rivalListURL;
/**
 * The fetch-ranking endpoint URL.
 * @return The fetch-ranking URL.
 * @ghidraAddress 0x181338
 */
+ (nullable NSURL *)rankingListURL;
/**
 * The fetch-present-list endpoint URL.
 * @return The fetch-present-list URL.
 * @ghidraAddress 0x18140c
 */
+ (nullable NSURL *)presentListURL;
/**
 * The fetch-present endpoint URL.
 * @return The fetch-present URL.
 * @ghidraAddress 0x1814e0
 */
+ (nullable NSURL *)getPresentURL;
/**
 * The fetch-jcube-list endpoint URL.
 * @return The fetch-jcube-list URL.
 * @ghidraAddress 0x1815b4
 */
+ (nullable NSURL *)cubePurchaseListURL;
/**
 * The verify-receipt endpoint URL.
 * @return The verify-receipt URL.
 * @ghidraAddress 0x181688
 */
+ (nullable NSURL *)cubeVerifyReceiptURL;
/**
 * The send-sum-price endpoint URL.
 * @return The send-sum-price URL.
 * @ghidraAddress 0x18175c
 */
+ (nullable NSURL *)registTotalPurchaseURL;
/**
 * The register-age endpoint URL.
 * @return The register-age URL.
 * @ghidraAddress 0x181830
 */
+ (nullable NSURL *)registUserAgeURL;
/**
 * The fetch-sheet-list endpoint URL.
 * @return The fetch-sheet-list URL.
 * @ghidraAddress 0x181d20
 */
+ (nullable NSURL *)getMissionListURL;
/**
 * The fetch-mission-list endpoint URL.
 * @return The fetch-mission-list URL.
 * @ghidraAddress 0x181df4
 */
+ (nullable NSURL *)getMissionSheetURL;
/**
 * The check-achievement endpoint URL.
 * @return The check-achievement URL.
 * @ghidraAddress 0x181ec8
 */
+ (nullable NSURL *)getMissionAchieveURL;
/**
 * The update-achievement endpoint URL.
 * @return The update-achievement URL.
 * @ghidraAddress 0x181f9c
 */
+ (nullable NSURL *)getMissionAchieveCheckURL;
/**
 * The close-mission-achievement endpoint URL.
 * @return The close-mission-achievement URL.
 * @ghidraAddress 0x182070
 */
+ (nullable NSURL *)openMissionAchieveURL;
/**
 * The fetch-reward-list endpoint URL.
 * @return The fetch-reward-list URL.
 * @ghidraAddress 0x182144
 */
+ (nullable NSURL *)getMissionRewardListURL;
/**
 * The fetch-reward-url endpoint URL.
 * @return The fetch-reward-url URL.
 * @ghidraAddress 0x182218
 */
+ (nullable NSURL *)getMissionRewardURL;
/**
 * The skip-mission endpoint URL.
 * @return The skip-mission URL.
 * @ghidraAddress 0x1822f8
 */
+ (nullable NSURL *)getMissionSkipURL;
/**
 * The confirm-user-id endpoint URL.
 * @return The confirm-user-id URL.
 * @ghidraAddress 0x1824a0
 */
+ (nullable NSURL *)getInheritInputURL;
/**
 * The finish-transfer-user-id endpoint URL.
 * @return The finish-transfer-user-id URL.
 * @ghidraAddress 0x182574
 */
+ (nullable NSURL *)getInheritReplaceURL;
/**
 * The recommend-pack endpoint URL.
 * @return The recommend-pack URL.
 * @ghidraAddress 0x182910
 */
+ (nullable NSURL *)recommendPackListURL;
/**
 * The fetch-campaign-map endpoint URL.
 * @return The fetch-campaign-map URL.
 * @ghidraAddress 0x182ab8
 */
+ (nullable NSURL *)getOchazukeURL;
/**
 * The inquiry endpoint URL.
 * @return The inquiry URL.
 * @ghidraAddress 0x182874
 */
+ (nullable NSURL *)getInquiryURL;

/**
 * The mission sheet-set URL; forwards to @c +challengeSampleURL .
 * @return Whatever @c +challengeSampleURL returns, so always nil in the shipped build.
 * @ghidraAddress 0x1822ec
 */
+ (nullable NSURL *)getMissionSheetSetURL;
/**
 * A sample-scratch URL. Always nil in the shipped build.
 * @return Always nil in the shipped build.
 * @ghidraAddress 0x180448
 */
+ (nullable NSURL *)challengeSampleURL;

/**
 * The scratch-image cache directory, created on first use.
 * @return The directory path, or nil when it cannot be created.
 * @ghidraAddress 0x181904
 */
+ (nullable NSString *)scratchImageDirectory;
/**
 * The unlock-panel-image cache directory, created on first use.
 * @return The directory path, or nil when it cannot be created.
 * @ghidraAddress 0x182648
 */
+ (nullable NSString *)unlockPanelImageDirectory;
/**
 * The temporary panel-data path inside the scratch-image directory.
 * @return The panel-data path.
 * @ghidraAddress 0x18273c
 */
+ (nullable NSString *)panelDataPath;

/**
 * The scratch image path for a tune.
 *
 * A zero identifier maps to the bundled @c scratch_btn_scratch_00.png ; otherwise
 * @c "<scratchImageDirectory>/aw%09d.img" .
 * @param musicID The tune identifier.
 * @return The scratch image path for the tune.
 * @ghidraAddress 0x1819f8
 */
+ (nullable NSString *)imagePathForMusicID:(unsigned int)musicID;
/**
 * The tune data path, preferring the downloaded store file when present.
 *
 * When the tune is in the store list and its @c +[StoreUtil filePathForMusicID:] exists on disk
 * that path is returned; otherwise @c "<scratchImageDirectory>/%09d.jbt" .
 * @param musicID The tune identifier.
 * @return The downloaded store file path when it exists, otherwise the scratch-directory path.
 * @ghidraAddress 0x181b24
 */
+ (nullable NSString *)itemPathForMusicID:(unsigned int)musicID;
/**
 * The unlock-panel image path for an item.
 * @param itemID The item identifier.
 * @return The unlock-panel image path for the item.
 * @ghidraAddress 0x1827b0
 */
+ (nullable NSString *)panelImagePathForItemID:(int)itemID;
/**
 * A regular-panel-image check. Always nil in the shipped build.
 * @return Always nil in the shipped build.
 * @ghidraAddress 0x18286c
 */
+ (nullable NSString *)checkRegularPanelImage;

/**
 * Clears the scratch-image cache directory and recreates it empty.
 * @ghidraAddress 0x181c8c
 */
+ (void)clearScratchData;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
