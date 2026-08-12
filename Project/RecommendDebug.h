/** @file
 * The Applilink recommend SDK's debug-override store.
 *
 * @c RecommendDebug is a stateless utility class: every member is a class method and the class
 * holds no instance state. When debug mode is active it supplies canned advert-model setting,
 * banner-display-status, banner, icon, and movie lists in place of the archived production data,
 * persists the debug-mode flag in @c NSUserDefaults, and exposes the recorded interstitial
 * frequency and display-specification state for inspection. The canned records are the Applilink
 * sandbox test fixtures. This is a closed SDK class, though jubeat's canned records carry ASCII
 * placeholder genre/title/introduction values and jubeat adds a @c movieList the other shipped
 * build lacks.
 *
 * Reconstructed from Ghidra program Jubeat (class RecommendDebug, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The recommend network's debug-override store.
 */
@interface RecommendDebug : NSObject

/**
 * @brief The canned advert-model setting list.
 * @return The debug advert-model setting records.
 * @ghidraAddress 0x248764
 */
+ (NSArray<NSDictionary *> *)adModelSettingList;

/**
 * @brief The canned banner-display-status list.
 * @return The debug banner-display-status records.
 * @ghidraAddress 0x2489d4
 */
+ (NSArray<NSDictionary *> *)bannerDisplayStatusList;

/**
 * @brief The canned banner advert list.
 * @return The debug banner advert records.
 * @ghidraAddress 0x248bdc
 */
+ (NSArray<NSDictionary *> *)bannerList;

/**
 * @brief The canned icon advert list.
 * @return The debug icon advert records.
 * @ghidraAddress 0x24a284
 */
+ (NSArray<NSDictionary *> *)iconList;

/**
 * @brief The canned movie advert list.
 * @return The single debug movie advert record.
 * @ghidraAddress 0x24b9e8
 */
+ (NSArray<NSDictionary *> *)movieList;

/**
 * @brief Persists the debug-mode override flag.
 *
 * Stores @p debugMode in @c NSUserDefaults under the @c applilink.debug.mode key, or removes the
 * key when @p debugMode is @c nil.
 * @param debugMode The debug-mode flag object, or @c nil to clear it.
 * @ghidraAddress 0x24bec8
 */
+ (void)debugMode:(nullable id)debugMode;

/**
 * @brief The persisted debug-mode override flag.
 * @return The stored @c applilink.debug.mode object, or @c nil when debug mode is not active.
 * @ghidraAddress 0x24bfa0
 */
+ (nullable id)getDebugMode;

/**
 * @brief The recorded interstitial-frequency state.
 *
 * Merges the unarchived @c ApplilinkRecommend.frequency counters with the current interstitial
 * location display specification for inspection.
 * @return A dictionary describing the interstitial-frequency state.
 * @ghidraAddress 0x24c00c
 */
+ (NSMutableDictionary *)getFrequencyStatus;

/**
 * @brief The recorded interstitial display-specification state.
 *
 * Merges the unarchived daily and total advert-display counts with the current interstitial
 * display specification for inspection.
 * @return A dictionary describing the interstitial display-specification state.
 * @ghidraAddress 0x24c190
 */
+ (NSMutableDictionary *)getDisplaySpec;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
