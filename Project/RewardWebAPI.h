/** @file
 * The Applilink reward network's web-API client.
 *
 * A stateless class-method facade over @c ApplilinkWebAPI that builds, signs, and posts the reward
 * server's install, login, application-list, status-flag, install-report, and banner requests, and
 * maps each JSON response to a localised error.
 *
 * Reconstructed from Ghidra program Jubeat (class RewardWebAPI, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base. The class object is at 0x352578.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The reward network's web-API client.
 */
@interface RewardWebAPI : NSObject

/**
 * @brief Posts the application-install registration for a UDID priority.
 * @param priority The UDID priority (0 normal, 1 three-kind retry, 2 pasteboard).
 * @param callback Invoked with an error, or nil on success.
 * @ghidraAddress 0x253fd4
 */
+ (void)postApplicationInstallWithPriority:(int)priority
                                  callback:(nullable void (^)(NSError *_Nullable error))callback;

/**
 * @brief Checks the reward login status.
 * @param block Invoked with whether the login is valid and an optional error.
 * @ghidraAddress 0x2547c8
 */
+ (void)checkLoginWithBlock:(nullable void (^)(BOOL valid, NSError *_Nullable error))block;

/**
 * @brief Starts a reward login for a user id at a UDID priority.
 * @param userId The user identifier.
 * @param priority The UDID priority.
 * @param callback Invoked with an error, or nil on success.
 * @ghidraAddress 0x254bac
 */
+ (void)startLoginWithUserId:(nullable NSString *)userId
                withPriority:(int)priority
                    callback:(nullable void (^)(NSError *_Nullable error))callback;

/**
 * @brief Fetches the reward application list.
 * @param campaignId The campaign identifier.
 * @param company The company filter.
 * @param offset The result offset.
 * @param limit The result limit.
 * @param callback Invoked with the result dictionary and an optional error.
 * @ghidraAddress 0x255340
 */
+ (void)appListWithCampaignId:(nullable NSString *)campaignId
                    inCompany:(nullable NSString *)company
                       offset:(nullable NSString *)offset
                        limit:(nullable NSString *)limit
                     callback:(nullable void (^)(NSDictionary *_Nullable result,
                                                 NSError *_Nullable error))callback;

/**
 * @brief Fetches the reward application-id list of a type.
 * @param type The list type.
 * @param callback Invoked with the result dictionary and an optional error.
 * @ghidraAddress 0x255704
 */
+ (void)appliIdListWithType:(int)type
                   callback:(nullable void (^)(NSDictionary *_Nullable result,
                                               NSError *_Nullable error))callback;

/**
 * @brief Fetches the all-install flag, caching it.
 * @param callback Invoked with the flag and an optional error.
 * @ghidraAddress 0x255ad0
 */
+ (void)allInstallFlgWithCallback:(nullable void (^)(NSInteger flg,
                                                     NSError *_Nullable error))callback;

/**
 * @brief Fetches the pre-info display flag, caching it.
 * @param callback Invoked with the flag and an optional error.
 * @ghidraAddress 0x256044
 */
+ (void)getPreInfoWithCallback:(nullable void (^)(NSInteger flg, NSError *_Nullable error))callback;

/**
 * @brief Posts an install report, paging the application list in chunks of ten.
 * @param appliList The installed application identifiers.
 * @param callback Invoked with an error, or nil on success.
 * @ghidraAddress 0x256588
 */
+ (void)postAppliInstallReportWithAppliList:(nullable NSArray *)appliList
                                   callback:(nullable void (^)(NSError *_Nullable error))callback;

/**
 * @brief Fetches the reward banner detail.
 * @param block Invoked with the result dictionary and an optional error.
 * @ghidraAddress 0x256adc
 */
+ (void)bannerInfoWithBlock:(nullable void (^)(NSDictionary *_Nullable result,
                                               NSError *_Nullable error))block;

/**
 * @brief Adds a SHA-256 signature over the sorted, joined parameters to a request dictionary.
 * @param parameters The request parameters to sign in place.
 * @ghidraAddress 0x256e64
 */
+ (void)setSignatureWithParameters:(nullable NSMutableDictionary *)parameters;

/**
 * @brief Archives a value with an expiry into @c NSUserDefaults under a key.
 * @param key The defaults key.
 * @param value The value to cache.
 * @param expiration The lifetime in seconds, or 0 for one second.
 * @ghidraAddress 0x257324
 */
+ (void)setTemporaryCacheWithKey:(nullable NSString *)key
                           value:(nullable id)value
                      expiration:(NSInteger)expiration;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
