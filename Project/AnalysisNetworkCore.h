/**
 * @file
 * The applilink SDK's analytics and advert-tracking transport.
 *
 * Reconstructed from Ghidra program Jubeat (class AnalysisNetworkCore, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base. The class object is at
 * 0x348bf8.
 *
 * @c AnalysisNetworkCore is the advert-analytics core of Konami's applilink SDK: a stateless class
 * (no ivars, no properties, only class methods) that posts analytics events to the applilink
 * servers. It handles install/initialisation registration, daily-active-user (DAU) measurement,
 * user-identifier registration, generic action-data posting, advert impression (list), click, and
 * click-movie registrations, and opening the external and appli web browsers. Success markers are
 * persisted to @c NSUserDefaults under the @c ApplilinkAnalysis.initialize and
 * @c ApplilinkAnalysis.dauMeasurementDate keys.
 *
 * @c AnalysisNetwork is the guarded facade in front of this class. Compared with the other shipped
 * build of the same SDK class, this build carries five more
 * methods (device-data, external and appli browsers, the sync-URL opener, and the click-movie
 * registration).
 */

#import <Foundation/Foundation.h>

#import "ApplilinkWebAPI.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * The callback every analytics call answers with, carrying an error or nil.
 *
 * The browser methods reuse this type although they answer with a URL string rather than an error;
 * the block ABI is identical and the shipped facade passes the same block type.
 */
typedef void (^ApplilinkAnalysisCallback)(NSError *_Nullable error);

/**
 * The applilink advert SDK's advert-analytics core.
 *
 * All members are class methods; the class holds no state of its own and persists its markers to
 * @c NSUserDefaults.
 */
@interface AnalysisNetworkCore : NSObject

#pragma mark Analysis posting

/**
 * Post the install/initialisation registration if it has not yet succeeded.
 *
 * When @c getInitalizeFlg is already set, the callback is invoked immediately with @c nil.
 * Otherwise an initialisation action (type @c 1) is posted, capturing the current date; on success
 * the @c ApplilinkAnalysis.initialize marker is persisted. The selector preserves the binary's
 * @c Initalize misspelling.
 * @param callback The completion callback invoked with an error, or @c nil on success.
 * @ghidraAddress 0x238d98
 */
+ (void)postInitalizeWithCallback:(nullable ApplilinkAnalysisCallback)callback;

/**
 * Post the daily-active-user measurement if it has not yet been sent today.
 *
 * When @c getSendDauFlg is already set, the callback is invoked immediately with @c nil. Otherwise
 * a DAU action (type @c 2) is posted for the current @c ApplilinkConsts userId, capturing the
 * current date; on success the @c ApplilinkAnalysis.dauMeasurementDate marker is persisted.
 * @param callback The completion callback invoked with an error, or @c nil on success.
 * @ghidraAddress 0x239194
 */
+ (void)postDAUWithCallback:(nullable ApplilinkAnalysisCallback)callback;

/**
 * Post a result registration for the given result identifier.
 *
 * When @p resultId is @c nil, the callback is invoked with error code @c 1001. Otherwise a result
 * action (type @c 3) is posted for the current @c ApplilinkConsts userId.
 * @param resultId The result identifier.
 * @param callback The completion callback invoked with an error, or @c nil on success.
 * @ghidraAddress 0x2395bc
 */
+ (void)postAnalysisDataWithResultId:(nullable NSString *)resultId
                            callback:(nullable ApplilinkAnalysisCallback)callback;

/**
 * Post the user-identifier registration.
 *
 * When @c ApplilinkConsts userId is @c nil, the callback is invoked with error code @c 1001.
 * Otherwise a user-identifier action (type @c 14) is posted.
 * @param callback The completion callback invoked with an error, or @c nil on success.
 * @ghidraAddress 0x239918
 */
+ (void)postSetUserIDWithCallback:(nullable ApplilinkAnalysisCallback)callback;

/**
 * Post a generic analytics action to the server.
 *
 * Builds the request parameters (action type, optional result and user identifiers, and the UDID
 * source), merges the user-agent parameters, and posts them to @c /analysis/regist.php. The
 * selector preserves the binary's @c uesrId misspelling.
 * @param actionType The analytics action-type code (@c 1 for initialisation, @c 2 for DAU, @c 3 for
 * a result, or @c 14 for a user-identifier registration).
 * @param resultId The optional result identifier, sent when non-empty.
 * @param uesrId The optional user identifier, URL-encoded before sending.
 * @param finishedBlock The block invoked with the server response on success.
 * @param failedBlock The block invoked with the request and error on failure.
 * @param callback The completion callback invoked with an error when a parameter is missing.
 * @ghidraAddress 0x239c58
 */
+ (void)postAnalysisDataWithActionType:(int)actionType
                              resultId:(nullable NSString *)resultId
                                uesrId:(nullable NSString *)uesrId
                         finishedBlock:(nullable ApplilinkWebAPIFinishedBlock)finishedBlock
                           failedBlock:(nullable ApplilinkWebAPIFailedBlock)failedBlock
                              callback:(nullable ApplilinkAnalysisCallback)callback;

/**
 * Post a device-data registration (a user-identifier action, type @c 14).
 *
 * Despite the @c ActionType: selector keyword, the sole argument is the completion callback: the
 * binary posts a fixed action type of @c 14 and forwards the block as the success/failure callback.
 * @param callback The completion callback invoked with an error, or @c nil on success.
 * @ghidraAddress 0x23a040
 */
+ (void)postAnalysisDeviceDataWithActionType:(nullable ApplilinkAnalysisCallback)callback;

/**
 * Post the queued advert-analysis data to the analytics server.
 *
 * Runs the install/initialisation registration and then the daily-active-user measurement in
 * sequence. The callback receives the initialisation error when one occurred, otherwise the DAU
 * error (or @c nil when both succeeded).
 * @param callback The completion callback invoked with an error, or @c nil on success.
 * @ghidraAddress 0x23cb28
 */
+ (void)postAnalysisDataWithCallback:(nullable ApplilinkAnalysisCallback)callback;

#pragma mark Web browser

/**
 * Query the advert sync status and, when instructed, open the sync URL in the browser.
 *
 * Posts a @c GET to @c /analysis/app/getSyncStatus.php carrying the appli identifier and stores the
 * @p env under @c ApplilinkNetwork.env. On a successful response whose @c browser flag is set, the
 * browser conversion is applied (opening the sync URL and persisting the conversion markers). The
 * callback is invoked only on the error path.
 * @param url The appli identifier sent as @c ua_appli_id.
 * @param env The SDK environment, persisted to @c NSUserDefaults.
 * @param callback The completion callback, invoked only when the envelope is unsuccessful.
 * @ghidraAddress 0x23a2fc
 */
+ (void)openExternalWebBrowserCore:(nullable NSString *)url
                               env:(nullable NSString *)env
                          callback:(nullable ApplilinkAnalysisCallback)callback;

/**
 * Request the sync URL and open it in the external browser.
 *
 * Posts a @c GET to @c /analysis/app/getSyncUrl.php carrying the UDID and advertising identifier;
 * the empty global response blocks open the returned URL with @c UIApplication. Takes no arguments.
 * @ghidraAddress 0x23aca0
 */
+ (void)openWebBrowserWithSyncUrl;

/**
 * Request the browser URL for one application identifier and hand it to the callback.
 *
 * Posts a @c GET to @c /analysis/app/getSyncUrl.php carrying the appli identifier and stores the
 * @p env under @c ApplilinkNetwork.env. The callback receives the server's @c url string on
 * success, or @c nil on any failure.
 * @param appliId The appli identifier sent as @c ua_appli_id.
 * @param env The SDK environment, persisted to @c NSUserDefaults.
 * @param callback The completion callback, invoked with the URL string or @c nil.
 * @ghidraAddress 0x23b04c
 */
+ (void)openWebBrowserWithAppliIdCore:(nullable NSString *)appliId
                                  env:(nullable NSString *)env
                             callback:(nullable ApplilinkAnalysisCallback)callback;

#pragma mark Advert impression, click, and movie registration

/**
 * Register an impression list for the displayed adverts.
 *
 * Posts to @c /analysis/list/regist.php. When @p adLocation or @p impressionId is @c nil the
 * callback is invoked with error code @c 1001. The four list parameters are only sent when all of
 * them are non-empty.
 * @param adType The advert-type string.
 * @param adModel The advert-model string.
 * @param adLocation The advert-location identifier.
 * @param impressionId The impression identifier.
 * @param appliIdList The advert application identifiers.
 * @param creativeIdList The advert creative identifiers.
 * @param incentiveTypeList The incentive-type strings.
 * @param installFlgList The install-flag strings.
 * @param callback The completion callback invoked with an error, or @c nil on success.
 * @ghidraAddress 0x23b540
 */
+ (void)postAnalysisListRegistWithAdType:(nullable NSString *)adType
                                 adModel:(nullable NSString *)adModel
                              adLocation:(nullable NSString *)adLocation
                            impressionId:(nullable NSString *)impressionId
                             appliIdList:(nullable NSArray *)appliIdList
                          creativeIdList:(nullable NSArray *)creativeIdList
                       incentiveTypeList:(nullable NSArray *)incentiveTypeList
                          installFlgList:(nullable NSArray *)installFlgList
                                callback:(nullable ApplilinkAnalysisCallback)callback;

/**
 * Register a click for a displayed advert.
 *
 * Posts to @c /analysis/click/regist.php. When any of @p adLocation, @p impressionId,
 * @p appliIdTo, @p creativeId, @p displayNumber, @p incentiveType, or @p installFlg is @c nil the
 * callback is invoked with error code @c 1001.
 * @param adType The advert-type string.
 * @param adModel The advert-model string.
 * @param adLocation The advert-location identifier.
 * @param impressionId The impression identifier.
 * @param appliIdTo The destination advert application identifier.
 * @param creativeId The advert creative identifier.
 * @param displayNumber The advert display-number string.
 * @param incentiveType The incentive-type string.
 * @param installFlg The install-flag string.
 * @param callback The completion callback invoked with an error, or @c nil on success.
 * @ghidraAddress 0x23bb68
 */
+ (void)postAnalysisClickRegistWithAdType:(nullable NSString *)adType
                                  adModel:(nullable NSString *)adModel
                               adLocation:(nullable NSString *)adLocation
                             impressionId:(nullable NSString *)impressionId
                                appliIdTo:(nullable NSString *)appliIdTo
                               creativeId:(nullable NSString *)creativeId
                            displayNumber:(nullable NSString *)displayNumber
                            incentiveType:(nullable NSString *)incentiveType
                               installFlg:(nullable NSString *)installFlg
                                 callback:(nullable ApplilinkAnalysisCallback)callback;

/**
 * Register a click for an advert movie.
 *
 * Posts to @c /analysis/movie/regist.php. Behaves like the click registration with the same
 * missing-parameter guards, and additionally sends @p movieStatus under the @c status key,
 * formatted with @c %d.
 * @param adType The advert-type string.
 * @param adModel The advert-model string.
 * @param adLocation The advert-location identifier.
 * @param impressionId The impression identifier.
 * @param appliIdTo The destination advert application identifier.
 * @param creativeId The advert creative identifier.
 * @param displayNumber The advert display-number string.
 * @param incentiveType The incentive-type string.
 * @param installFlg The install-flag string.
 * @param movieStatus The movie-status code, sent as the @c status parameter.
 * @param callback The completion callback invoked with an error, or @c nil on success.
 * @ghidraAddress 0x23c21c
 */
+ (void)postAnalysisClickMovieWithAdType:(nullable NSString *)adType
                                 adModel:(nullable NSString *)adModel
                              adLocation:(nullable NSString *)adLocation
                            impressionId:(nullable NSString *)impressionId
                               appliIdTo:(nullable NSString *)appliIdTo
                              creativeId:(nullable NSString *)creativeId
                           displayNumber:(nullable NSString *)displayNumber
                           incentiveType:(nullable NSString *)incentiveType
                              installFlg:(nullable NSString *)installFlg
                             movieStatus:(int)movieStatus
                                callback:(nullable ApplilinkAnalysisCallback)callback;

#pragma mark Persistence flags

/**
 * Whether the analytics-initialisation marker has been persisted.
 *
 * The selector preserves the binary's @c Initalize misspelling.
 * @return @c YES when the @c ApplilinkAnalysis.initialize key exists in @c NSUserDefaults.
 * @ghidraAddress 0x23c914
 */
+ (BOOL)getInitalizeFlg;

/**
 * Whether daily-active-user measurement has already been sent today.
 * @return @c YES when the persisted @c ApplilinkAnalysis.dauMeasurementDate is the same calendar
 * day as now, or later.
 * @ghidraAddress 0x23c990
 */
+ (BOOL)getSendDauFlg;

/**
 * Clear the persisted analytics-initialisation marker.
 *
 * Removes the @c ApplilinkAnalysis.initialize key from @c NSUserDefaults and synchronises. The
 * selector preserves the binary's @c Initalize misspelling.
 * @ghidraAddress 0x23cd40
 */
+ (void)clearInitalize;

/**
 * Clear the persisted daily-active-user measurement date.
 *
 * Removes the @c ApplilinkAnalysis.dauMeasurementDate key from @c NSUserDefaults and synchronises.
 * @ghidraAddress 0x23cdd4
 */
+ (void)clearDAU;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
