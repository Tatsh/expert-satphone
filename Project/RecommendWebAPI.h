/** @file
 * Reconstructed interface for the applilink recommend SDK's @c RecommendWebAPI web-API facade.
 *
 * @c RecommendWebAPI is the recommend network's high-level web API. Each request method builds a
 * parameter dictionary, merges it with the user-agent parameters through @c ApplilinkUtilities,
 * and dispatches a single asynchronous request through
 * @c ApplilinkWebAPI @c +requestAsynchronousWithURL:method:parameters:userInfo:tag:cachePolicy:
 * timeout:retry:finishedBlock:failedBlock:, against an @c "/ad/..." path appended to
 * @c ApplilinkConsts.baseUrlSsl. Each request pairs a finished handler that validates the JSON
 * response (an @c NSDictionary with @c status true and @c error_code equal to the success
 * sentinel), maps the various @c error_code and @c kind values onto @c ApplilinkNetworkError
 * codes, and forwards the outcome to the caller's callback, with a failed handler that either
 * forwards the transport error or drops it. Two request builders return a ready-made
 * @c NSURLRequest for a first-party click or application-start advert. The advert-status cache is
 * persisted in @c NSUserDefaults under the @c ApplilinkRecommend.bannerInfo default, and the
 * advert-external detail freshness stamp under @c ApplilinkRecommend.adDetail. The class is
 * stateless: it exposes only class methods. The applilink SDK ships as a closed third-party
 * library. Reconstructed from Ghidra program Jubeat, image base 0x100000000.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The recommend network's web-API facade.
 */
@interface RecommendWebAPI : NSObject

/**
 * @brief Check whether the recommend session is still logged in.
 *
 * When @c ApplilinkConsts reports a fresh login is required, the callback is invoked immediately;
 * otherwise the login-status endpoint is queried.
 * @param callback The completion callback invoked with the login state, a secondary flag, and an
 * error.
 * @ghidraAddress 0x261104
 */
+ (void)checkLoginWithCallback:
    (nullable void (^)(BOOL loginStatus, BOOL userIdPresent, NSError *_Nullable error))callback;

/**
 * @brief Start a recommend login for the stored user identifier.
 * @param callback The completion callback invoked with an error.
 * @ghidraAddress 0x26156c
 */
+ (void)startLoginWithCallback:(nullable void (^)(NSError *_Nullable error))callback;

/**
 * @brief Fetch the advert-external detail, refreshing the cached category and country codes.
 *
 * When the cached detail is still valid the cached category and country codes are returned without
 * a network request.
 * @param callback The completion callback invoked with the category identifier, country code, and
 * an error.
 * @ghidraAddress 0x261afc
 */
+ (void)getAdDetailWithCallback:(nullable void (^)(id _Nullable categoryId,
                                                   id _Nullable countryCode,
                                                   NSError *_Nullable error))callback;

/**
 * @brief Fetch the installed-application list and store it on @c ApplilinkConsts.
 * @param callback The completion callback invoked with the list and an error.
 * @ghidraAddress 0x26237c
 */
+ (void)installAppliListWithCallBack:(nullable void (^)(id _Nullable list,
                                                        NSError *_Nullable error))callback;

/**
 * @brief Fetch the installed-application list for the given parameters, forcing the test flag.
 * @param parameters The base request parameters.
 * @param callBack The completion callback invoked with the list and an error.
 * @ghidraAddress 0x2629d4
 */
+ (void)appliListWithParameters:(nullable NSDictionary *)parameters
                       callBack:
                           (nullable void (^)(id _Nullable list, NSError *_Nullable error))callBack;

/**
 * @brief Post the application-install record for the current advertising identifier.
 * @param adIdFrom The source advertising identifier.
 * @param categoryId The advert category identifier.
 * @param adType The advert-type string.
 * @param priority The install priority; zero skips the UDID-parameter requirement check.
 * @param callback The completion callback invoked with an error.
 * @ghidraAddress 0x262f78
 */
+ (void)postApplicationInstallWithAdIdFrom:(nullable NSString *)adIdFrom
                                categoryId:(nullable NSString *)categoryId
                                    adType:(nullable NSString *)adType
                                  priority:(int)priority
                                  callback:(nullable void (^)(NSError *_Nullable error))callback;

/**
 * @brief Fetch the banner-detail display status for an advert model.
 *
 * When the per-model cache holds an available banner the cached status is returned without a
 * network request.
 * @param adModel The advert-model identifier.
 * @param callback The completion callback invoked with the display status and an error.
 * @ghidraAddress 0x263624
 */
+ (void)getBannerDetailWithAdModel:(int)adModel
                          callback:(nullable void (^)(NSInteger status,
                                                      NSError *_Nullable error))callback;

/**
 * @brief Register a read for an advert type across a list of advertising identifiers.
 * @param adType The advert-type identifier; zero omits the advert-type parameter.
 * @param adIdList The advertising identifiers to mark read.
 * @param callback The completion callback invoked with an error.
 * @ghidraAddress 0x263ca8
 */
+ (void)readRegistWithAdType:(int)adType
                    adIdList:(nullable NSArray *)adIdList
                    callback:(nullable void (^)(NSError *_Nullable error))callback;

/**
 * @brief Fetch the unread advert count for an advert model at an ad location.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier.
 * @param callback The completion callback invoked with the count and an error.
 * @ghidraAddress 0x2640e4
 */
+ (void)getUnreadCountWithAdModel:(int)adModel
                       adLocation:(nullable NSString *)adLocation
                         callback:(nullable void (^)(NSInteger status,
                                                     NSError *_Nullable error))callback;

/**
 * @brief Fetch the pre-info display status for an advert model at an ad location.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier.
 * @param callback The completion callback invoked with the status dictionary and an error.
 * @ghidraAddress 0x2645c4
 */
+ (void)getPreInfoWithAdModel:(int)adModel
                   adLocation:(nullable NSString *)adLocation
                     callback:(nullable void (^)(NSDictionary *_Nullable status,
                                                 NSError *_Nullable error))callback;

/**
 * @brief Persist the display-status cache entry for an advert model with an expiry.
 * @param adModel The advert-model identifier used as the cache key.
 * @param value The status value to cache.
 * @param expiration The expiry, in seconds from now; zero caches for one second.
 * @ghidraAddress 0x264cf0
 */
+ (void)setTemporaryCacheWithAdModel:(int)adModel
                               value:(NSInteger)value
                          expiration:(NSInteger)expiration;

/**
 * @brief Read the still-valid cached display status for an advert model.
 *
 * An expired entry is removed from the cache and @c nil is returned.
 * @param adModel The advert-model identifier used as the cache key.
 * @return The cached status, or @c nil when absent or expired.
 * @ghidraAddress 0x2650f4
 */
+ (nullable id)getTemporaryCacheWithAdModel:(int)adModel;

/**
 * @brief Register a click for a first-party advert and return its resolved location.
 * @param adIdFrom The source advertising identifier.
 * @param adIdTo The destination advertising identifier.
 * @param adModel The advert-model identifier.
 * @param callback The completion callback invoked with the resolved location and an error.
 * @ghidraAddress 0x26542c
 */
+ (void)clickRegistWithAdIdFrom:(nullable NSString *)adIdFrom
                         adIdTo:(nullable NSString *)adIdTo
                        adModel:(int)adModel
                       callback:(nullable void (^)(id _Nullable location,
                                                   NSError *_Nullable error))callback;

/**
 * @brief Register an application start for a first-party advert.
 * @param adIdFrom The source advertising identifier.
 * @param adIdTo The destination advertising identifier.
 * @param adType The advert-type identifier.
 * @param callback The completion callback invoked with an error.
 * @ghidraAddress 0x265910
 */
+ (void)appStartWithAdIdFrom:(nullable NSString *)adIdFrom
                      adIdTo:(nullable NSString *)adIdTo
                      adType:(int)adType
                    callback:(nullable void (^)(NSError *_Nullable error))callback;

/**
 * @brief Fetch every advert-data record for display and forward the raw response.
 * @param callback The completion callback invoked with the response data and an error.
 * @ghidraAddress 0x265d5c
 */
+ (void)allAdDataWithCallBack:(nullable void (^)(id _Nullable data,
                                                 NSError *_Nullable error))callback;

/**
 * @brief Fetch the recommend layout index and store the template list on @c ApplilinkConsts.
 * @param callback The completion callback invoked with an error.
 * @ghidraAddress 0x26625c
 */
+ (void)layoutIndexWithCallback:(nullable void (^)(NSError *_Nullable error))callback;

/**
 * @brief Build the click-registration request for a first-party advert.
 * @param adIdFrom The source advertising identifier.
 * @param adIdTo The destination advertising identifier.
 * @param adModel The advert-model identifier.
 * @return The click-registration request.
 * @ghidraAddress 0x2665e0
 */
+ (nullable NSURLRequest *)clickRegistWithAdIdFrom:(nullable NSString *)adIdFrom
                                            adIdTo:(nullable NSString *)adIdTo
                                           adModel:(int)adModel;

/**
 * @brief Build the application-start request for a first-party advert.
 * @param adIdFrom The source advertising identifier.
 * @param adIdTo The destination advertising identifier.
 * @param adType The advert-type identifier.
 * @return The application-start request.
 * @ghidraAddress 0x266820
 */
+ (nullable NSURLRequest *)appStartWithAdIdFrom:(nullable NSString *)adIdFrom
                                         adIdTo:(nullable NSString *)adIdTo
                                         adType:(int)adType;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
