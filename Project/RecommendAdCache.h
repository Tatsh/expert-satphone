/** @file
 * Reconstructed interface for the applilink recommend SDK's @c RecommendAdCache store.
 *
 * @c RecommendAdCache is the recommend network's advert-cache store: a pure class-method utility
 * (no instances, no ivars) that refreshes the aggregated advert-status table, fetches every
 * advert-data record through the recommend session and persists it, pre-loads banner, resource,
 * and cached-movie files through @c ApplilinkFile, downloads and stores the advert HTML templates,
 * renders the cached HTML advert body from those templates, tracks per-advert display counts
 * (daily and total) in @c NSUserDefaults with a daily reset, and stores and reads the cached HTML
 * advert records. The advert-data expiry is held in a process-lifetime global rather than in
 * @c NSUserDefaults. The class has no instance state; every member is a class method.
 *
 * Reconstructed from Ghidra program Jubeat (class @c RecommendAdCache, image base
 * @c 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * This is Konami's applilink SDK. This build diverges from an older shipped build of the same
 * class: the
 * HTML builder gained an @c impressionId parameter and a nine-part fill selector taking a self
 * list and a common-resource payload, and the movie-player and movie-query surfaces are new.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Completion block for a full advert-data fetch.
 * @param data Always @c nil on every path the binary takes.
 * @param error The fetch error, or @c nil on success.
 */
typedef void (^RecommendAdCacheAllAdDataCallback)(id _Nullable data, NSError *_Nullable error);

/**
 * @brief The recommend network's advert-cache store.
 */
@interface RecommendAdCache : NSObject

/**
 * @brief Refresh the aggregated advert-status table.
 *
 * If the cached advert-data expiry date is still in the future the call returns early; otherwise it
 * recreates the cache folder and requests a fresh layout index from the web API, then refreshes
 * the templates, wipes the on-disk caches, and kicks off a full advert-data fetch.
 * @ghidraAddress 0x274d3c
 */
+ (void)getAllAdStatus;

/**
 * @brief Fetch every advert-data record through the recommend session, then report completion.
 * @param callBack The completion callback. Its first argument is always @c nil; only the error
 *        ever carries a value.
 * @ghidraAddress 0x27525c
 */
+ (void)getAllAdDataWithCallBack:(RecommendAdCacheAllAdDataCallback)callBack;

/**
 * @brief Clear the cached aggregated advert-data record from @c NSUserDefaults.
 * @ghidraAddress 0x275a54
 */
+ (void)clearAllAdData;

/**
 * @brief The cached advert-data expiry date.
 *
 * The expiry archive is held in a process-lifetime global, not in @c NSUserDefaults.
 * @return The expiry date, or @c nil when no valid date is cached.
 * @ghidraAddress 0x275aac
 */
+ (nullable NSDate *)getAllAdDataInfoExpire;

/**
 * @brief Clear the in-memory expiry record for the cached advert data.
 * @ghidraAddress 0x275b74
 */
+ (void)clearAllAdDataInfoExpire;

/**
 * @brief Pre-load the banner images for a list of advert records, up to a success quota.
 * @param list The advert-image URLs whose files should be cached.
 * @param max The maximum number of successful downloads before stopping.
 * @ghidraAddress 0x275b84
 */
+ (void)getBannerDataWithList:(nullable NSArray *)list max:(int)max;

/**
 * @brief Fetch and cache every resource file in a list.
 * @param list The resource-image URLs to cache.
 * @return @c YES when every fetch succeeded, @c NO as soon as one fails.
 * @ghidraAddress 0x275d74
 */
+ (BOOL)getResourceDataWithList:(nullable NSArray *)list;

/**
 * @brief Pre-load the cached-data (movie) files for a list, up to a success quota.
 * @param list The data-file URLs whose files should be cached.
 * @param max The maximum number of successful downloads before stopping.
 * @ghidraAddress 0x275eb4
 */
+ (void)getCacheDataWithList:(nullable NSArray *)list max:(int)max;

/**
 * @brief Download and cache every advert template file listed in the SDK template list.
 * @ghidraAddress 0x2760a4
 */
+ (void)getTemplateFiles;

/**
 * @brief Write template data into the contents folder, creating the intermediate directories named
 * by @p path.
 * @param data The template data to write.
 * @param path The slash-separated relative directory path.
 * @param file The template file name.
 * @ghidraAddress 0x2762ac
 */
+ (void)saveTemplateData:(nullable NSData *)data
                    path:(nullable NSString *)path
                    file:(nullable NSString *)file;

/**
 * @brief Create the cached HTML advert body for an advert model, writing it to the contents folder.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier.
 * @param verticalAlign The vertical-alignment identifier.
 * @param impressionId The impression identifier embedded in the rendered HTML.
 * @return A localised error when the body could not be created, otherwise @c nil.
 * @ghidraAddress 0x276598
 */
+ (nullable NSError *)createHtmlWithAdModel:(int)adModel
                                 adLocation:(nullable NSString *)adLocation
                              verticalAlign:(int)verticalAlign
                               impressionId:(nullable NSString *)impressionId;

/**
 * @brief Fill the advert-type HTML template with the banner list, self list, common-resource
 * payload, and environment placeholders.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier.
 * @param adType The advert-type identifier, selecting the @c ad_type<adType>.html template.
 * @param verticalAlign The vertical-alignment identifier.
 * @param bannerList The banner records to embed.
 * @param impressionId The impression identifier, embedded only when non-@c nil.
 * @param selfList The self advert records to embed.
 * @param comResData The common-resource payload to embed.
 * @return The rendered HTML string.
 * @ghidraAddress 0x276a80
 */
+ (nullable NSString *)convertHtmlWithAdModel:(int)adModel
                                   adLocation:(nullable NSString *)adLocation
                                       adType:(int)adType
                                verticalAlign:(int)verticalAlign
                                   bannerList:(nullable id)bannerList
                                 impressionId:(nullable NSString *)impressionId
                                     selfList:(nullable id)selfList
                                   comResData:(nullable id)comResData;

/**
 * @brief Build and store the click-through target URL on every banner record.
 * @param targetUrl The mutable banner records to annotate with their target URLs.
 * @param adType The advert-type identifier.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier.
 * @ghidraAddress 0x277150
 */
+ (void)setTargetUrl:(nullable NSArray *)targetUrl
              adType:(int)adType
             adModel:(int)adModel
          adLocation:(nullable NSString *)adLocation;

/**
 * @brief Increment both the daily and the total display counters for an advert identifier.
 * @param adId The advert identifier.
 * @ghidraAddress 0x2777b8
 */
+ (void)setAdDisplayCountWithAdId:(nullable NSString *)adId;

/**
 * @brief Increment the daily display counter for an advert identifier, resetting it at the start of
 * a new local day.
 * @param adId The advert identifier.
 * @ghidraAddress 0x277820
 */
+ (void)setAdDisplayCountDailyWithAdId:(nullable NSString *)adId;

/**
 * @brief Increment the lifetime total display counter for an advert identifier.
 * @param adId The advert identifier.
 * @ghidraAddress 0x277d50
 */
+ (void)setAdDisplayCountTotalWithAdId:(nullable NSString *)adId;

/**
 * @brief Clear both the daily and the total display counters.
 * @ghidraAddress 0x277fa4
 */
+ (void)clearAdDisplayCount;

/**
 * @brief Store the cached HTML advert records for an advert model at an ad location.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier.
 * @param bannerList The advert records to cache.
 * @ghidraAddress 0x278014
 */
+ (void)setHtmlAdDataWithAdModel:(int)adModel
                      adLocation:(nullable NSString *)adLocation
                      bannerList:(nullable id)bannerList;

/**
 * @brief The cached HTML advert records for an advert model at an ad location.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier.
 * @return The advert records.
 * @ghidraAddress 0x2781e4
 */
+ (nullable NSArray *)getHtmlAdDataWithAdModel:(int)adModel
                                    adLocation:(nullable NSString *)adLocation;

/**
 * @brief Pre-load the movie-player icon resource files.
 * @return @c YES when every resource fetch succeeded.
 * @ghidraAddress 0x278320
 */
+ (BOOL)getMoviePlayerIcon;

/**
 * @brief Build the interstitial movie query records, or report why none is available.
 *
 * On success the first interstitial record (with its target URL filled and its display counter
 * incremented) is returned. On failure @c nil is returned and @p errorObj is set to a localised
 * error. The selector keeps the binary's misspellings "Moview" and "Quary" verbatim, and the
 * @p verticalAlign and @p impressionId arguments are accepted but never read.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier.
 * @param verticalAlign Ignored. The body never reads it.
 * @param impressionId Ignored. The body never reads it.
 * @param errorObj On failure, set to the localised error.
 * @return The interstitial movie query record, or @c nil on failure.
 * @ghidraAddress 0x278524
 */
+ (nullable id)getMoviewQuaryWithAdModel:(int)adModel
                              adLocation:(nullable NSString *)adLocation
                           verticalAlign:(int)verticalAlign
                            impressionId:(nullable NSString *)impressionId
                                errorObj:(NSError *_Nullable *_Nullable)errorObj;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
