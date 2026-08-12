/** @file
 * The Applilink advert-SDK debug console's facade.
 *
 * @c ApplilinkDebug is a stateless utility class: every member is a class method and the class
 * holds no instance state. Each method is a thin forwarder exposing an SDK internal to the debug UI
 * — identity and configuration values, the recommend frequency and display-spec state, and the
 * debug reset actions. The concrete work lives in @c ApplilinkConsts , @c ApplilinkCore ,
 * @c RewardCore , @c RecommendCore , @c AnalysisNetworkCore , @c RecommendAdCache , and
 * @c RecommendDebug .
 *
 * Reconstructed from Ghidra program Jubeat (image base 0x100000000). All @ghidraAddress values are
 * offsets relative to that image base. The class object is at 0x352488.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The Applilink advert-SDK debug console's facade.
 */
@interface ApplilinkDebug : NSObject

/** @brief The configured country code. @ghidraAddress 0x250f60 */
+ (nullable NSString *)countryCode;
/** @brief The configured advert category identifier. @ghidraAddress 0x250f78 */
+ (nullable NSString *)categoryId;
/** @brief The cached device UDID. @ghidraAddress 0x250f90 */
+ (nullable NSString *)udid;
/** @brief The cached advertising UDID. @ghidraAddress 0x250fa8 */
+ (nullable NSString *)ad_udid;
/** @brief The cached old UDID. @ghidraAddress 0x250fc0 */
+ (nullable NSString *)old_udid;
/** @brief Clears the stored device UDID. @ghidraAddress 0x250fd8 */
+ (void)clearUDID;
/** @brief Clears the stored old UDID keychain entry. @ghidraAddress 0x250ff0 */
+ (void)clearKeyChainOldUDID;
/** @brief Clears the stored advertising UDID. @ghidraAddress 0x251008 */
+ (void)clearAdUDID;
/** @brief The SDK development version string. @ghidraAddress 0x251020 */
+ (nullable NSString *)versionDev;
/** @brief Clears the reward and recommend sessions. @ghidraAddress 0x25106c */
+ (void)clearSession;
/** @brief Clears the reward and recommend advert status. @ghidraAddress 0x2510f8 */
+ (void)clearAdStatus;
/** @brief Clears the analytics initialisation marker. @ghidraAddress 0x251184 */
+ (void)clearInitalize;
/** @brief Clears the analytics daily-active-user date. @ghidraAddress 0x2511c0 */
+ (void)clearDAU;
/** @brief Sets the recommend debug-mode override. @ghidraAddress 0x2511d8 */
+ (void)debugMode:(nullable id)debugMode;
/** @brief The recommend debug-mode override. @ghidraAddress 0x2511f0 */
+ (nullable id)getDebugMode;
/** @brief Clears every cached banner image. @ghidraAddress 0x251208 */
+ (void)allClearCacheBannerImage;
/** @brief The recommend interstitial frequency state. @ghidraAddress 0x251220 */
+ (nullable NSMutableDictionary *)getFrequencyStatus;
/** @brief The recommend display-specification state. @ghidraAddress 0x251238 */
+ (nullable NSMutableDictionary *)getDisplaySpec;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
