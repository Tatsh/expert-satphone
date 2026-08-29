/**
 * @file
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
 * The Applilink advert-SDK debug console's facade.
 */
@interface ApplilinkDebug : NSObject

/**
 * The configured country code.
 * @return The country code.
 * @ghidraAddress 0x250f60
 */
+ (nullable NSString *)countryCode;
/**
 * The configured advert category identifier.
 * @return The advert category identifier.
 * @ghidraAddress 0x250f78
 */
+ (nullable NSString *)categoryId;
/**
 * The cached device UDID.
 * @return The device UDID.
 * @ghidraAddress 0x250f90
 */
+ (nullable NSString *)udid;
/**
 * The cached advertising UDID.
 * @return The advertising UDID.
 * @ghidraAddress 0x250fa8
 */
+ (nullable NSString *)ad_udid;
/**
 * The cached old UDID.
 * @return The old UDID.
 * @ghidraAddress 0x250fc0
 */
+ (nullable NSString *)old_udid;
/** Clears the stored device UDID. @ghidraAddress 0x250fd8 */
+ (void)clearUDID;
/** Clears the stored old UDID keychain entry. @ghidraAddress 0x250ff0 */
+ (void)clearKeyChainOldUDID;
/** Clears the stored advertising UDID. @ghidraAddress 0x251008 */
+ (void)clearAdUDID;
/**
 * The SDK development version string.
 * @return The development version string.
 * @ghidraAddress 0x251020
 */
+ (nullable NSString *)versionDev;
/** Clears the reward and recommend sessions. @ghidraAddress 0x25106c */
+ (void)clearSession;
/** Clears the reward and recommend advert status. @ghidraAddress 0x2510f8 */
+ (void)clearAdStatus;
/** Clears the analytics initialisation marker. @ghidraAddress 0x251184 */
+ (void)clearInitalize;
/** Clears the analytics daily-active-user date. @ghidraAddress 0x2511c0 */
+ (void)clearDAU;
/**
 * Sets the recommend debug-mode override.
 * @param debugMode The override to install.
 * @ghidraAddress 0x2511d8
 */
+ (void)debugMode:(nullable id)debugMode;
/**
 * The recommend debug-mode override.
 * @return The installed override.
 * @ghidraAddress 0x2511f0
 */
+ (nullable id)getDebugMode;
/** Clears every cached banner image. @ghidraAddress 0x251208 */
+ (void)allClearCacheBannerImage;
/**
 * The recommend interstitial frequency state.
 * @return The interstitial frequency state.
 * @ghidraAddress 0x251220
 */
+ (nullable NSMutableDictionary *)getFrequencyStatus;
/**
 * The recommend display-specification state.
 * @return The display-specification state.
 * @ghidraAddress 0x251238
 */
+ (nullable NSMutableDictionary *)getDisplaySpec;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
