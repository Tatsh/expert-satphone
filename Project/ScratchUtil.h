/** @file
 * Server endpoint construction.
 *
 * Reconstructed from Ghidra program Jubeat (class ScratchUtil, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: only the one member reached so far is recovered. The class object is at
 * 0x3482a0 and has a sibling @c +pushNotificationIDSendURL at 0x180450 that nothing reconstructed
 * reaches yet, so it is not declared.
 *
 * Class properties and bare class methods compile to the same single class method, so declaring
 * @c pushNotificationResponseURL as a class property below claims nothing the binary contradicts.
 * That is unlike an instance property, whose accessor pair is observable — see the note in
 * TYPES_PENDING.md.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Builds the URLs the application talks to.
 */
@interface ScratchUtil : NSObject

/**
 * @brief The endpoint a push-notification receipt is reported to.
 *
 * Built in two formatting steps from four separate literals, and with no branch anywhere in the
 * method — so the endpoint is fixed, with no staging or debug host to select between.
 * @ghidraAddress 0x180524
 */
@property(class, nonatomic, readonly) NSURL *pushNotificationResponseURL;

/**
 * @brief The endpoint the current event type is fetched from.
 *
 * Fetched during @c -[LogoViewController loadView] , so the answer is in hand by the time the
 * splash ends.
 *
 * @return The event-type URL.
 * @ghidraAddress 0x1829e4
 */
+ (nullable NSURL *)getEventTypeURL;

/**
 * @brief The endpoint an inherit code is requested from.
 *
 * Sent by @c -[InheritCodePayView tapCodeOutput:] with the editor identity as its POST body.
 *
 * @return The inherit-code request URL.
 * @ghidraAddress 0x1823cc
 */
+ (nullable NSURL *)getInheritOutputURL;

/**
 * @brief The push-token registration endpoint URL.
 * @ghidraAddress 0x180450
 */
+ (nullable NSURL *)pushNotificationIDSendURL;
/**
 * @brief The challenge-mode policy endpoint URL.
 * @ghidraAddress 0x1805f8
 */
+ (nullable NSURL *)challengeModePolicyURL;
/**
 * @brief The begin-session endpoint URL.
 * @ghidraAddress 0x1806cc
 */
+ (nullable NSURL *)challengeSessionURL;
/**
 * @brief The scratch init endpoint URL.
 * @ghidraAddress 0x1807a0
 */
+ (nullable NSURL *)challengeInitializeURL;
/**
 * @brief The scratch refresh-display endpoint URL.
 * @ghidraAddress 0x180874
 */
+ (nullable NSURL *)challengeSimpleInitializeURL;
/**
 * @brief The previous-scratch-info endpoint URL.
 * @ghidraAddress 0x180948
 */
+ (nullable NSURL *)challengePrevScratchURL;
/**
 * @brief The scratch-cell endpoint URL.
 * @ghidraAddress 0x180a1c
 */
+ (nullable NSURL *)nailScratchURL;
/**
 * @brief The exchange-item endpoint URL.
 * @ghidraAddress 0x180af0
 */
+ (nullable NSURL *)cubeScratchURL;
/**
 * @brief The music-info endpoint URL.
 * @ghidraAddress 0x180bc4
 */
+ (nullable NSURL *)musicInfoURL;
/**
 * @brief The start-play endpoint URL.
 * @ghidraAddress 0x180c98
 */
+ (nullable NSURL *)playMusicURL;
/**
 * @brief The exchange-item (rest-play-coin) endpoint URL.
 * @ghidraAddress 0x180d6c
 */
+ (nullable NSURL *)restPlayCoinURL;
/**
 * @brief The send-score endpoint URL.
 * @ghidraAddress 0x180e40
 */
+ (nullable NSURL *)sendMusicScoreURL;
/**
 * @brief The change-name endpoint URL.
 * @ghidraAddress 0x180f14
 */
+ (nullable NSURL *)getUserNameURL;
/**
 * @brief The manage-rival (register) endpoint URL.
 * @ghidraAddress 0x180fe8
 */
+ (nullable NSURL *)registRivalURL;
/**
 * @brief The manage-rival (remove) endpoint URL.
 * @ghidraAddress 0x1810bc
 */
+ (nullable NSURL *)removeRivalURL;
/**
 * @brief The fetch-name-by-id endpoint URL.
 * @ghidraAddress 0x181190
 */
+ (nullable NSURL *)searchRivalURL;
/**
 * @brief The fetch-rival-list endpoint URL.
 * @ghidraAddress 0x181264
 */
+ (nullable NSURL *)rivalListURL;
/**
 * @brief The fetch-ranking endpoint URL.
 * @ghidraAddress 0x181338
 */
+ (nullable NSURL *)rankingListURL;
/**
 * @brief The fetch-present-list endpoint URL.
 * @ghidraAddress 0x18140c
 */
+ (nullable NSURL *)presentListURL;
/**
 * @brief The fetch-present endpoint URL.
 * @ghidraAddress 0x1814e0
 */
+ (nullable NSURL *)getPresentURL;
/**
 * @brief The fetch-jcube-list endpoint URL.
 * @ghidraAddress 0x1815b4
 */
+ (nullable NSURL *)cubePurchaseListURL;
/**
 * @brief The verify-receipt endpoint URL.
 * @ghidraAddress 0x181688
 */
+ (nullable NSURL *)cubeVerifyReceiptURL;
/**
 * @brief The send-sum-price endpoint URL.
 * @ghidraAddress 0x18175c
 */
+ (nullable NSURL *)registTotalPurchaseURL;
/**
 * @brief The register-age endpoint URL.
 * @ghidraAddress 0x181830
 */
+ (nullable NSURL *)registUserAgeURL;
/**
 * @brief The fetch-sheet-list endpoint URL.
 * @ghidraAddress 0x181d20
 */
+ (nullable NSURL *)getMissionListURL;
/**
 * @brief The fetch-mission-list endpoint URL.
 * @ghidraAddress 0x181df4
 */
+ (nullable NSURL *)getMissionSheetURL;
/**
 * @brief The check-achievement endpoint URL.
 * @ghidraAddress 0x181ec8
 */
+ (nullable NSURL *)getMissionAchieveURL;
/**
 * @brief The update-achievement endpoint URL.
 * @ghidraAddress 0x181f9c
 */
+ (nullable NSURL *)getMissionAchieveCheckURL;
/**
 * @brief The close-mission-achievement endpoint URL.
 * @ghidraAddress 0x182070
 */
+ (nullable NSURL *)openMissionAchieveURL;
/**
 * @brief The fetch-reward-list endpoint URL.
 * @ghidraAddress 0x182144
 */
+ (nullable NSURL *)getMissionRewardListURL;
/**
 * @brief The fetch-reward-url endpoint URL.
 * @ghidraAddress 0x182218
 */
+ (nullable NSURL *)getMissionRewardURL;
/**
 * @brief The skip-mission endpoint URL.
 * @ghidraAddress 0x1822f8
 */
+ (nullable NSURL *)getMissionSkipURL;
/**
 * @brief The confirm-user-id endpoint URL.
 * @ghidraAddress 0x1824a0
 */
+ (nullable NSURL *)getInheritInputURL;
/**
 * @brief The finish-transfer-user-id endpoint URL.
 * @ghidraAddress 0x182574
 */
+ (nullable NSURL *)getInheritReplaceURL;
/**
 * @brief The recommend-pack endpoint URL.
 * @ghidraAddress 0x182910
 */
+ (nullable NSURL *)recommendPackListURL;
/**
 * @brief The fetch-campaign-map endpoint URL.
 * @ghidraAddress 0x182ab8
 */
+ (nullable NSURL *)getOchazukeURL;
/**
 * @brief The inquiry endpoint URL.
 * @ghidraAddress 0x182874
 */
+ (nullable NSURL *)getInquiryURL;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
