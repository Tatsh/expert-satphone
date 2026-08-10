#import "RecommendWebAPI.h"

#import <Foundation/Foundation.h>

#import "ApplilinkConsts.h"
#import "ApplilinkCore.h"
#import "ApplilinkNetworkError.h"
#import "ApplilinkUdid.h"
#import "ApplilinkUtilities.h"
#import "ApplilinkWebAPI.h"
#import "NSStringURLEncoding.h"

// HTTP methods dispatched through the transport.
static NSString *const kRecommendWebAPIMethodGet = @"GET";
static NSString *const kRecommendWebAPIMethodPost = @"POST";

// Endpoint paths appended to ApplilinkConsts.baseUrlSsl.
static NSString *const kRecommendWebAPIPathCheckLoginStatus = @"/ad/auth/checkLoginStatus.php";
static NSString *const kRecommendWebAPIPathLogin = @"/ad/auth/login.php";
static NSString *const kRecommendWebAPIPathExternalDetail = @"/ad/external/detail.php";
static NSString *const kRecommendWebAPIPathAdidIndex = @"/ad/external/adid/index.php";
static NSString *const kRecommendWebAPIPathExternalIndex = @"/ad/external/index.php";
static NSString *const kRecommendWebAPIPathAppInstallRegist =
    @"/ad/external/app/install/regist.php";
static NSString *const kRecommendWebAPIPathBannerDetail = @"/ad/external/banner/detail.php";
static NSString *const kRecommendWebAPIPathAppReadRegist = @"/ad/external/app/read/regist.php";
static NSString *const kRecommendWebAPIPathCheckAllRead = @"/ad/external/app/read/checkAllRead.php";
static NSString *const kRecommendWebAPIPathPreInfoForDisplay =
    @"/ad/external/app/preInfoForDisplay.php";
static NSString *const kRecommendWebAPIPathAllAdDataForDisplay =
    @"/ad/external/app/allAdDataForDisplay.php";
static NSString *const kRecommendWebAPIPathClickRegist = @"/ad/external/click/regist.php";
static NSString *const kRecommendWebAPIPathAppStart = @"/ad/external/app/start.php";
static NSString *const kRecommendWebAPIPathLayoutIndex = @"/ad/external/layout/index.php";

// Request parameter keys.
static NSString *const kRecommendWebAPIParamUserId = @"user_id";
static NSString *const kRecommendWebAPIParamCfr = @"cfr";
static NSString *const kRecommendWebAPIParamAppliId = @"appli_id";
static NSString *const kRecommendWebAPIParamAdIdFrom = @"ad_id_from";
static NSString *const kRecommendWebAPIParamAdIdTo = @"ad_id_to";
static NSString *const kRecommendWebAPIParamCategoryId = @"category_id";
static NSString *const kRecommendWebAPIParamAdType = @"ad_type";
static NSString *const kRecommendWebAPIParamAdModel = @"ad_model";
static NSString *const kRecommendWebAPIParamAdLocation = @"ad_location";
static NSString *const kRecommendWebAPIParamAdIdList = @"ad_id_list";
static NSString *const kRecommendWebAPIParamOtherUdid = @"other_udid";
static NSString *const kRecommendWebAPIParamIsSdk = @"is_sdk";
static NSString *const kRecommendWebAPIParamTestFlg = @"test_flg";
static NSString *const kRecommendWebAPIParamTrue = @"1";

// Response body keys.
static NSString *const kRecommendWebAPIKeyStatus = @"status";
static NSString *const kRecommendWebAPIKeyErrorCode = @"error_code";
static NSString *const kRecommendWebAPIKeyKind = @"kind";
static NSString *const kRecommendWebAPIKeyList = @"list";
static NSString *const kRecommendWebAPIKeyLoginStatus = @"login_status";
static NSString *const kRecommendWebAPIKeyCategoryId = @"category_id";
static NSString *const kRecommendWebAPIKeyCountryCode = @"country_code";
static NSString *const kRecommendWebAPIKeyInfo = @"info";
static NSString *const kRecommendWebAPIKeyExpire = @"expire";
static NSString *const kRecommendWebAPIKeyUnreadCount = @"unread_count";
static NSString *const kRecommendWebAPIKeyBannerDisplayStatus = @"banner_display_status";
static NSString *const kRecommendWebAPIKeyLocation = @"Location";

// kind values that map onto specific error codes.
static NSString *const kRecommendWebAPIKindAuthorization = @"authorization";
static NSString *const kRecommendWebAPIKindParameterError = @"parameter_error";

// Status-dictionary keys used by the pre-info display-status result. These are the camelCase
// client-side names; the server keys are their snake_case counterparts above.
static NSString *const kRecommendWebAPIStatusKeyUnreadCount = @"unreadCount";
static NSString *const kRecommendWebAPIStatusKeyBannerDisplayStatus = @"bannerDisplayStatus";

// NSUserDefaults keys backing the cached detail and per-model display-status cache.
static NSString *const kRecommendWebAPIDefaultsAdDetail = @"ApplilinkRecommend.adDetail";
static NSString *const kRecommendWebAPIDefaultsBannerInfo = @"ApplilinkRecommend.bannerInfo";

// Cache-entry keys inside the per-model banner-info cache.
static NSString *const kRecommendWebAPICacheKeyStatus = @"status";
static NSString *const kRecommendWebAPICacheKeyExpire = @"expire";

// Format that renders an integer parameter into its string form.
static NSString *const kRecommendWebAPIIntegerFormat = @"%d";

// Response sentinel values.
enum {
    // status true and error_code equal to this value marks a successful response.
    kRecommendWebAPISuccessSentinel = 100000000,
    // Additional error_code values mapped to distinct network errors.
    kRecommendWebAPIErrorCodeGeneric = 999999999,
    kRecommendWebAPIErrorCodeAuthorization = 202506497,
    kRecommendWebAPIErrorCodeLoginRequired = 202508473,
};

// Applilink network error codes delivered on the various failure paths. These are the raw integers
// the binary passes to +[ApplilinkNetworkError localizedApplilinkErrorWithCode:userInfo:].
enum {
    kRecommendWebAPINetworkErrorMalformed = 1000,
    kRecommendWebAPINetworkErrorParameter = 1001,
    kRecommendWebAPINetworkErrorLoginRequired = 1002,
    kRecommendWebAPINetworkErrorGeneric = 1007,
    kRecommendWebAPINetworkErrorAuthorization = 1009,
    kRecommendWebAPINetworkErrorUdidUnavailable = 1026,
};

// The banner-detail cache sentinel that marks an available banner and short-circuits the request.
enum { kRecommendWebAPIBannerAvailable = 1 };

// Request timeouts, in seconds.
static const float kRecommendWebAPIShortTimeout = 3.0f;
static const float kRecommendWebAPIStandardTimeout = 10.0f;

// Default expiry, in seconds, for a cache entry stored with a zero expiration.
static const NSTimeInterval kRecommendWebAPIDefaultCacheExpiry = 1.0;

// Lifetime, in seconds, of the cached advert-external detail (ten minutes). The pooled double at
// 0x291c30 is 0x4082C00000000000 = 600.0; this binary uses a far shorter stamp than the sibling
// rbplus build, which caches for seven days.
/** @ghidraAddress 0x291c30 */
static const NSTimeInterval kRecommendWebAPIAdDetailCacheExpiry = 600.0;

// NSURLErrorTimedOut, recognised on the login timeout retry path.
static const NSInteger kRecommendWebAPIURLErrorTimedOut = -1001;

// Builds the generic malformed-response error the binary raises on every response it cannot parse.
static inline NSError *RecommendWebAPIMalformedErrorForResponse(id response) {
    return
        [ApplilinkNetworkError localizedApplilinkErrorWithCode:kRecommendWebAPINetworkErrorMalformed
                                                      userInfo:response];
}

// Maps a login-status response's error code and kind onto an ApplilinkNetworkError.
static inline NSError *RecommendWebAPILoginErrorForResponse(id response) {
    if ([response[kRecommendWebAPIKeyErrorCode] intValue] ==
        kRecommendWebAPIErrorCodeLoginRequired) {
        return [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kRecommendWebAPINetworkErrorLoginRequired
                                   userInfo:response];
    }
    if ([response[kRecommendWebAPIKeyKind] isEqualToString:kRecommendWebAPIKindParameterError]) {
        return [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kRecommendWebAPINetworkErrorParameter
                                   userInfo:response];
    }
    return RecommendWebAPIMalformedErrorForResponse(response);
}

// Maps the response error code and kind onto an ApplilinkNetworkError. This de-inlines the shared
// error dispatch that the binary duplicates across the response handlers.
static inline NSError *RecommendWebAPIErrorForResponse(id response, int errorCode, id kind) {
    if (errorCode == kRecommendWebAPIErrorCodeGeneric) {
        return [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kRecommendWebAPINetworkErrorGeneric
                                   userInfo:response];
    }
    if (errorCode == kRecommendWebAPIErrorCodeAuthorization) {
        return [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kRecommendWebAPINetworkErrorAuthorization
                                   userInfo:response];
    }
    if ([kind isEqualToString:kRecommendWebAPIKindAuthorization]) {
        return [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kRecommendWebAPINetworkErrorLoginRequired
                                   userInfo:response];
    }
    if ([kind isEqualToString:kRecommendWebAPIKindParameterError]) {
        return [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kRecommendWebAPINetworkErrorParameter
                                   userInfo:response];
    }
    return
        [ApplilinkNetworkError localizedApplilinkErrorWithCode:kRecommendWebAPINetworkErrorMalformed
                                                      userInfo:response];
}

@implementation RecommendWebAPI

#pragma mark - Login

+ (void)checkLoginWithCallback:
    (void (^)(BOOL loginStatus, BOOL userIdPresent, NSError *_Nullable error))callback {
    if ([ApplilinkConsts isNeedRecommendLogin]) {
        // The binary passes a third positional argument here even though callers read only the
        // login state and error.
        callback(NO, YES, nil);
        return;
    }
    NSString *userId = [ApplilinkConsts userId];
    NSDictionary *parameters = [ApplilinkUtilities userAgentParameters];
    BOOL userIdPresent = userId != nil;
    NSString *url =
        [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kRecommendWebAPIPathCheckLoginStatus];
    [ApplilinkWebAPI requestAsynchronousWithURL:url
        method:kRecommendWebAPIMethodGet
        parameters:parameters
        userInfo:nil
        tag:0
        cachePolicy:nil
        timeout:kRecommendWebAPIShortTimeout
        retry:NO
        finishedBlock:^(id request, id response) {
          /** @ghidraAddress 0x261320 */
          (void)request;
          if (![response isKindOfClass:[NSDictionary class]]) {
              NSError *error = RecommendWebAPIMalformedErrorForResponse(response);
              callback(NO, NO, error);
              return;
          }
          if (![response[kRecommendWebAPIKeyStatus] boolValue]) {
              NSError *error = RecommendWebAPIMalformedErrorForResponse(response);
              callback(NO, NO, error);
              return;
          }
          BOOL loginStatus = [response[kRecommendWebAPIKeyLoginStatus] boolValue];
          callback(loginStatus, userIdPresent, nil);
        }
        failedBlock:^(id request, NSError *error) {
          /** @ghidraAddress 0x2614e0 */
          (void)request;
          // A 3-second timeout is reported as a successful negative answer, keeping the captured
          // user-id flag; every other failure drops the flag and forwards the error.
          if (error.code == kRecommendWebAPIURLErrorTimedOut) {
              callback(NO, userIdPresent, nil);
              return;
          }
          callback(NO, NO, error);
        }];
}

+ (void)startLoginWithCallback:(void (^)(NSError *_Nullable error))callback {
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
    if (![ApplilinkUdid setUdidParameters:parameters]) {
        NSError *error = [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kRecommendWebAPINetworkErrorUdidUnavailable];
        callback(error);
        return;
    }
    NSString *encodedUserId = [NSStringURLEncoding URLEncodedString:[ApplilinkConsts userId]];
    [parameters setValue:encodedUserId forKey:kRecommendWebAPIParamUserId];
    [parameters setValue:kRecommendWebAPIParamTrue forKey:kRecommendWebAPIParamCfr];
    NSDictionary *merged = [ApplilinkUtilities userAgentParametersJoinDictionary:parameters];
    NSString *url =
        [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kRecommendWebAPIPathLogin];
    [ApplilinkWebAPI requestAsynchronousWithURL:url
        method:kRecommendWebAPIMethodGet
        parameters:merged
        userInfo:nil
        tag:0
        cachePolicy:nil
        timeout:kRecommendWebAPIStandardTimeout
        retry:NO
        finishedBlock:^(id request, id response) {
          /** @ghidraAddress 0x261854 */
          (void)request;
          if (![response isKindOfClass:[NSDictionary class]]) {
              NSError *error = RecommendWebAPIMalformedErrorForResponse(response);
              callback(error);
              return;
          }
          if ([response[kRecommendWebAPIKeyStatus] boolValue] &&
              [response[kRecommendWebAPIKeyErrorCode] intValue] ==
                  kRecommendWebAPISuccessSentinel) {
              callback(nil);
              return;
          }
          callback(RecommendWebAPILoginErrorForResponse(response));
        }
        failedBlock:^(id request, NSError *error) {
          /** @ghidraAddress 0x261ad4 */
          (void)request;
          callback(error);
        }];
}

#pragma mark - Advert detail

+ (void)getAdDetailWithCallback:(void (^)(id _Nullable categoryId,
                                          id _Nullable countryCode,
                                          NSError *_Nullable error))callback {
    id cachedData =
        [[NSUserDefaults standardUserDefaults] objectForKey:kRecommendWebAPIDefaultsAdDetail];
    if (cachedData != nil) {
        NSDate *expiry = [NSKeyedUnarchiver unarchiveObjectWithData:cachedData];
        if (expiry != nil && [expiry compare:[NSDate date]] != NSOrderedAscending) {
            NSString *categoryId = [ApplilinkConsts categoryId];
            NSString *countryCode = [ApplilinkConsts countryCode];
            if (categoryId != nil && countryCode != nil) {
                callback(categoryId, countryCode, nil);
                return;
            }
        }
    }
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:2];
    if (![ApplilinkUdid setUdidParameters:parameters]) {
        NSError *error = [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kRecommendWebAPINetworkErrorUdidUnavailable];
        callback(nil, nil, error);
        return;
    }
    [parameters setValue:[ApplilinkConsts appliId] forKey:kRecommendWebAPIParamAppliId];
    NSDictionary *merged = [ApplilinkUtilities userAgentParametersJoinDictionary:parameters];
    NSString *url =
        [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kRecommendWebAPIPathExternalDetail];
    [ApplilinkWebAPI requestAsynchronousWithURL:url
        method:kRecommendWebAPIMethodGet
        parameters:merged
        userInfo:nil
        tag:0
        cachePolicy:nil
        timeout:kRecommendWebAPIStandardTimeout
        retry:NO
        finishedBlock:^(id request, id response) {
          /** @ghidraAddress 0x261ef8 */
          (void)request;
          if (![response isKindOfClass:[NSDictionary class]]) {
              NSError *error = RecommendWebAPIMalformedErrorForResponse(response);
              callback(nil, nil, error);
              return;
          }
          id status = response[kRecommendWebAPIKeyStatus];
          if (![status isKindOfClass:[NSString class]] &&
              ![status isKindOfClass:[NSNumber class]]) {
              status = nil;
          }
          id errorCode = response[kRecommendWebAPIKeyErrorCode];
          BOOL errorCodeSuccess;
          if ([errorCode isKindOfClass:[NSString class]] ||
              [errorCode isKindOfClass:[NSNumber class]]) {
              errorCodeSuccess =
                  errorCode != nil && [errorCode intValue] == kRecommendWebAPISuccessSentinel;
          } else {
              // A missing or wrong-typed error_code counts as success on this endpoint.
              errorCodeSuccess = YES;
          }
          if ([status boolValue] && errorCodeSuccess) {
              id categoryId = response[kRecommendWebAPIKeyCategoryId];
              id countryCode = response[kRecommendWebAPIKeyCountryCode];
              if ([categoryId isKindOfClass:[NSString class]]) {
                  [ApplilinkConsts setCategoryId:categoryId];
              }
              if ([countryCode isKindOfClass:[NSString class]]) {
                  [ApplilinkConsts setCountryCode:countryCode];
              }
              NSDate *expiryDate =
                  [[NSDate date] dateByAddingTimeInterval:kRecommendWebAPIAdDetailCacheExpiry];
              NSData *expiry = [NSKeyedArchiver archivedDataWithRootObject:expiryDate];
              [[NSUserDefaults standardUserDefaults] setObject:expiry
                                                        forKey:kRecommendWebAPIDefaultsAdDetail];
              [[NSUserDefaults standardUserDefaults] synchronize];
              callback(categoryId, countryCode, nil);
              return;
          }
          NSError *error = RecommendWebAPIMalformedErrorForResponse(response);
          callback(nil, nil, error);
        }
        failedBlock:^(id request, NSError *error) {
          /** @ghidraAddress 0x262348 */
          (void)request;
          callback(nil, nil, error);
        }];
}

#pragma mark - Installed-application list

+ (void)installAppliListWithCallBack:(void (^)(id _Nullable list,
                                               NSError *_Nullable error))callback {
    NSString *url =
        [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kRecommendWebAPIPathAdidIndex];
    [ApplilinkWebAPI requestAsynchronousWithURL:url
        method:kRecommendWebAPIMethodGet
        parameters:nil
        userInfo:nil
        tag:0
        cachePolicy:nil
        timeout:kRecommendWebAPIShortTimeout
        retry:NO
        finishedBlock:^(id request, id response) {
          /** @ghidraAddress 0x2624f4 */
          (void)request;
          if (![response isKindOfClass:[NSDictionary class]]) {
              NSError *error = RecommendWebAPIMalformedErrorForResponse(response);
              callback(nil, error);
              return;
          }
          BOOL success = [response[kRecommendWebAPIKeyStatus] boolValue];
          int errorCode = [response[kRecommendWebAPIKeyErrorCode] intValue];
          id kind = response[kRecommendWebAPIKeyKind];
          if (![kind isKindOfClass:[NSString class]]) {
              kind = nil;
          }
          if (success && errorCode == kRecommendWebAPISuccessSentinel) {
              [ApplilinkConsts setAppInstallList:response[kRecommendWebAPIKeyList]];
              callback(nil, nil);
              return;
          }
          if (errorCode == kRecommendWebAPIErrorCodeGeneric) {
              NSError *error = [ApplilinkNetworkError
                  localizedApplilinkErrorWithCode:kRecommendWebAPINetworkErrorGeneric
                                         userInfo:response];
              callback(nil, error);
              return;
          }
          if (errorCode == kRecommendWebAPIErrorCodeAuthorization) {
              NSError *error = [ApplilinkNetworkError
                  localizedApplilinkErrorWithCode:kRecommendWebAPINetworkErrorAuthorization
                                         userInfo:response];
              callback(nil, error);
              return;
          }
          if ([kind isEqualToString:kRecommendWebAPIKindAuthorization]) {
              [ApplilinkCore appAuthSessionRegenerateWithBlock:^(NSError *regenError) {
                /** @ghidraAddress 0x2628d0 */
                // On a successful regeneration the caller's callback is never invoked; only a
                // regeneration failure reports back, carrying the original response as userInfo.
                if (regenError != nil) {
                    NSError *error = [ApplilinkNetworkError
                        localizedApplilinkErrorWithCode:kRecommendWebAPINetworkErrorLoginRequired
                                               userInfo:response];
                    callback(nil, error);
                }
              }];
              return;
          }
          NSError *error;
          if ([kind isEqualToString:kRecommendWebAPIKindParameterError]) {
              error = [ApplilinkNetworkError
                  localizedApplilinkErrorWithCode:kRecommendWebAPINetworkErrorParameter
                                         userInfo:response];
          } else {
              error = RecommendWebAPIMalformedErrorForResponse(response);
          }
          callback(nil, error);
        }
        failedBlock:^(id request, NSError *error) {
          /** @ghidraAddress 0x2629ac */
          (void)request;
          (void)error;
          // The binary forwards a single nil here and drops the transport error.
          callback(nil, nil);
        }];
}

+ (void)appliListWithParameters:(NSDictionary *)parameters
                       callBack:(void (^)(id _Nullable list, NSError *_Nullable error))callBack {
    NSMutableDictionary *merged = [NSMutableDictionary dictionaryWithDictionary:parameters];
    [merged setValue:kRecommendWebAPIParamTrue forKey:kRecommendWebAPIParamTestFlg];
    NSString *url =
        [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kRecommendWebAPIPathExternalIndex];
    [ApplilinkWebAPI requestAsynchronousWithURL:url
        method:kRecommendWebAPIMethodGet
        parameters:merged
        userInfo:nil
        tag:0
        cachePolicy:nil
        timeout:kRecommendWebAPIShortTimeout
        retry:NO
        finishedBlock:^(id request, id response) {
          /** @ghidraAddress 0x262bc8 */
          (void)request;
          if (![response isKindOfClass:[NSDictionary class]]) {
              NSError *error = RecommendWebAPIMalformedErrorForResponse(response);
              callBack(nil, error);
              return;
          }
          BOOL success = [response[kRecommendWebAPIKeyStatus] boolValue];
          int errorCode = [response[kRecommendWebAPIKeyErrorCode] intValue];
          id kind = response[kRecommendWebAPIKeyKind];
          if (![kind isKindOfClass:[NSString class]]) {
              kind = nil;
          }
          if (success && errorCode == kRecommendWebAPISuccessSentinel) {
              callBack(response[kRecommendWebAPIKeyList], nil);
              return;
          }
          NSError *error = RecommendWebAPIErrorForResponse(response, errorCode, kind);
          callBack(nil, error);
        }
        failedBlock:^(id request, NSError *error) {
          /** @ghidraAddress 0x262f50 */
          (void)request;
          (void)error;
          // The binary forwards a single nil here and drops the transport error.
          callBack(nil, nil);
        }];
}

#pragma mark - Application install

+ (void)postApplicationInstallWithAdIdFrom:(NSString *)adIdFrom
                                categoryId:(NSString *)categoryId
                                    adType:(NSString *)adType
                                  priority:(int)priority
                                  callback:(void (^)(NSError *_Nullable error))callback {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:4];
    if (adIdFrom != nil) {
        [parameters setValue:adIdFrom forKey:kRecommendWebAPIParamAdIdFrom];
    }
    if (categoryId != nil) {
        [parameters setValue:categoryId forKey:kRecommendWebAPIParamCategoryId];
    }
    if (adType != nil) {
        [parameters setValue:adType forKey:kRecommendWebAPIParamAdType];
    }
    if (priority != 0 && ![ApplilinkUdid setUdidParameters:parameters]) {
        NSError *error = [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kRecommendWebAPINetworkErrorUdidUnavailable];
        callback(error);
        return;
    }
    NSString *udid = [ApplilinkCore udid];
    if (udid != nil && ![[ApplilinkCore currentUdid] isEqualToString:udid]) {
        [parameters setValue:udid forKey:kRecommendWebAPIParamOtherUdid];
    }
    NSString *url =
        [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kRecommendWebAPIPathAppInstallRegist];
    [ApplilinkWebAPI requestAsynchronousWithURL:url
        method:kRecommendWebAPIMethodPost
        parameters:parameters
        userInfo:nil
        tag:0
        cachePolicy:nil
        timeout:kRecommendWebAPIStandardTimeout
        retry:NO
        finishedBlock:^(id request, id response) {
          /** @ghidraAddress 0x2632fc */
          (void)request;
          if ([response[kRecommendWebAPIKeyStatus] boolValue] &&
              [response[kRecommendWebAPIKeyErrorCode] intValue] ==
                  kRecommendWebAPISuccessSentinel) {
              callback(nil);
              return;
          }
          int errorCode = [response[kRecommendWebAPIKeyErrorCode] intValue];
          // This handler tests the authorization sentinel before the generic one, the reverse of
          // the sibling list handlers; the shared error mapping reaches the same result either way.
          NSError *error = RecommendWebAPIErrorForResponse(
              response, errorCode, response[kRecommendWebAPIKeyKind]);
          callback(error);
        }
        failedBlock:^(id request, NSError *error) {
          /** @ghidraAddress 0x2635fc */
          (void)request;
          callback(error);
        }];
}

#pragma mark - Advert status queries

+ (void)getBannerDetailWithAdModel:(int)adModel
                          callback:(void (^)(NSInteger status, NSError *_Nullable error))callback {
    id cached = [self getTemporaryCacheWithAdModel:adModel];
    if ([cached intValue] == kRecommendWebAPIBannerAvailable) {
        callback([cached intValue], nil);
        return;
    }
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:2];
    [parameters setValue:[NSString stringWithFormat:kRecommendWebAPIIntegerFormat, adModel]
                  forKey:kRecommendWebAPIParamAdModel];
    NSDictionary *merged = [ApplilinkUtilities userAgentParametersJoinDictionary:parameters];
    NSString *url =
        [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kRecommendWebAPIPathBannerDetail];
    [ApplilinkWebAPI requestAsynchronousWithURL:url
        method:kRecommendWebAPIMethodGet
        parameters:merged
        userInfo:nil
        tag:0
        cachePolicy:nil
        timeout:kRecommendWebAPIStandardTimeout
        retry:NO
        finishedBlock:^(id request, id response) {
          /** @ghidraAddress 0x2638e4 */
          (void)request;
          if (![response isKindOfClass:[NSDictionary class]]) {
              NSError *error = RecommendWebAPIMalformedErrorForResponse(response);
              callback(0, error);
              return;
          }
          if ([response[kRecommendWebAPIKeyStatus] boolValue] &&
              [response[kRecommendWebAPIKeyErrorCode] intValue] ==
                  kRecommendWebAPISuccessSentinel) {
              id info = response[kRecommendWebAPIKeyInfo];
              NSInteger status = 0;
              if (info != nil) {
                  id expireValue = info[kRecommendWebAPIKeyExpire];
                  int expire = 0;
                  if ([expireValue isKindOfClass:[NSString class]] ||
                      [expireValue isKindOfClass:[NSNumber class]]) {
                      expire = [expireValue intValue];
                  }
                  // The binary computes the expiry date here but discards it; only the integer
                  // offset feeds the cache write below.
                  (void)[[NSDate date] dateByAddingTimeInterval:expire];
                  id statusValue = info[kRecommendWebAPIKeyStatus];
                  if ([statusValue isKindOfClass:[NSString class]] ||
                      [statusValue isKindOfClass:[NSNumber class]]) {
                      status = [statusValue intValue];
                  }
                  if (status != 0) {
                      [self setTemporaryCacheWithAdModel:adModel value:status expiration:expire];
                  }
              }
              callback(status, nil);
              return;
          }
          NSError *error = RecommendWebAPIMalformedErrorForResponse(response);
          callback(0, error);
        }
        failedBlock:^(id request, NSError *error) {
          /** @ghidraAddress 0x263c80 */
          (void)request;
          (void)error;
          callback(0, nil);
        }];
}

+ (void)readRegistWithAdType:(int)adType
                    adIdList:(NSArray *)adIdList
                    callback:(void (^)(NSError *_Nullable error))callback {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:2];
    if (adType != 0) {
        [parameters setValue:[NSString stringWithFormat:kRecommendWebAPIIntegerFormat, adType]
                      forKey:kRecommendWebAPIParamAdType];
    }
    if (adIdList.count != 0) {
        parameters[kRecommendWebAPIParamAdIdList] = adIdList;
    }
    NSString *url =
        [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kRecommendWebAPIPathAppReadRegist];
    [ApplilinkWebAPI requestAsynchronousWithURL:url
        method:kRecommendWebAPIMethodGet
        parameters:parameters
        userInfo:nil
        tag:0
        cachePolicy:nil
        timeout:kRecommendWebAPIStandardTimeout
        retry:NO
        finishedBlock:^(id request, id response) {
          /** @ghidraAddress 0x263f10 */
          (void)request;
          if (![response isKindOfClass:[NSDictionary class]]) {
              NSError *error = RecommendWebAPIMalformedErrorForResponse(response);
              callback(error);
              return;
          }
          BOOL success = NO;
          if ([response[kRecommendWebAPIKeyStatus] boolValue]) {
              success = [response[kRecommendWebAPIKeyErrorCode] intValue] ==
                        kRecommendWebAPISuccessSentinel;
          }
          if (success) {
              callback(nil);
              return;
          }
          NSError *error = RecommendWebAPIMalformedErrorForResponse(response);
          callback(error);
        }
        failedBlock:^(id request, NSError *error) {
          /** @ghidraAddress 0x2640bc */
          (void)request;
          callback(error);
        }];
}

+ (void)getUnreadCountWithAdModel:(int)adModel
                       adLocation:(NSString *)adLocation
                         callback:(void (^)(NSInteger status, NSError *_Nullable error))callback {
    if (adLocation == nil || adModel == 0) {
        NSError *error = [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kRecommendWebAPINetworkErrorParameter];
        callback(0, error);
        return;
    }
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:2];
    [parameters setValue:adLocation forKey:kRecommendWebAPIParamAdLocation];
    [parameters setValue:[NSString stringWithFormat:kRecommendWebAPIIntegerFormat, adModel]
                  forKey:kRecommendWebAPIParamAdModel];
    NSDictionary *merged = [ApplilinkUtilities userAgentParametersJoinDictionary:parameters];
    NSString *url =
        [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kRecommendWebAPIPathCheckAllRead];
    [ApplilinkWebAPI requestAsynchronousWithURL:url
        method:kRecommendWebAPIMethodGet
        parameters:merged
        userInfo:nil
        tag:0
        cachePolicy:nil
        timeout:kRecommendWebAPIStandardTimeout
        retry:NO
        finishedBlock:^(id request, id response) {
          /** @ghidraAddress 0x2643a8 */
          (void)request;
          if (![response isKindOfClass:[NSDictionary class]]) {
              NSError *error = RecommendWebAPIMalformedErrorForResponse(response);
              callback(0, error);
              return;
          }
          if ([response[kRecommendWebAPIKeyStatus] boolValue] &&
              [response[kRecommendWebAPIKeyErrorCode] intValue] ==
                  kRecommendWebAPISuccessSentinel) {
              id unreadCount = response[kRecommendWebAPIKeyUnreadCount];
              NSInteger status = unreadCount != nil ? [unreadCount intValue] : 0;
              callback(status, nil);
              return;
          }
          NSError *error = RecommendWebAPIMalformedErrorForResponse(response);
          callback(0, error);
        }
        failedBlock:^(id request, NSError *error) {
          /** @ghidraAddress 0x26459c */
          (void)request;
          (void)error;
          callback(0, nil);
        }];
}

+ (void)getPreInfoWithAdModel:(int)adModel
                   adLocation:(NSString *)adLocation
                     callback:(void (^)(NSDictionary *_Nullable status,
                                        NSError *_Nullable error))callback {
    NSMutableDictionary *status = [NSMutableDictionary dictionaryWithCapacity:2];
    [status setValue:@(0) forKey:kRecommendWebAPIStatusKeyUnreadCount];
    [status setValue:@(0) forKey:kRecommendWebAPIStatusKeyBannerDisplayStatus];
    if (adLocation == nil || adModel == 0) {
        NSError *error = [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kRecommendWebAPINetworkErrorParameter];
        callback(status, error);
        return;
    }
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:2];
    [parameters setValue:adLocation forKey:kRecommendWebAPIParamAdLocation];
    [parameters setValue:[NSString stringWithFormat:kRecommendWebAPIIntegerFormat, adModel]
                  forKey:kRecommendWebAPIParamAdModel];
    NSDictionary *merged = [ApplilinkUtilities userAgentParametersJoinDictionary:parameters];
    NSString *url = [[ApplilinkConsts baseUrlSsl]
        stringByAppendingString:kRecommendWebAPIPathPreInfoForDisplay];
    [ApplilinkWebAPI requestAsynchronousWithURL:url
        method:kRecommendWebAPIMethodGet
        parameters:merged
        userInfo:nil
        tag:0
        cachePolicy:nil
        timeout:kRecommendWebAPIStandardTimeout
        retry:NO
        finishedBlock:^(id request, id response) {
          /** @ghidraAddress 0x264964 */
          (void)request;
          if ([response isKindOfClass:[NSDictionary class]] &&
              [response[kRecommendWebAPIKeyStatus] boolValue] &&
              [response[kRecommendWebAPIKeyErrorCode] intValue] ==
                  kRecommendWebAPISuccessSentinel) {
              id unreadCount = response[kRecommendWebAPIKeyUnreadCount];
              int unread = unreadCount != nil ? [unreadCount intValue] : 0;
              id bannerStatus = response[kRecommendWebAPIKeyBannerDisplayStatus];
              int banner = bannerStatus != nil ? [bannerStatus intValue] : 0;
              [status setValue:@(unread) forKey:kRecommendWebAPIStatusKeyUnreadCount];
              [status setValue:@(banner) forKey:kRecommendWebAPIStatusKeyBannerDisplayStatus];
              callback(status, nil);
              return;
          }
          NSError *error = RecommendWebAPIMalformedErrorForResponse(response);
          callback(status, error);
        }
        failedBlock:^(id request, NSError *error) {
          /** @ghidraAddress 0x264c88 */
          (void)request;
          (void)error;
          // The binary forwards only the captured status dictionary here and drops the transport
          // error.
          callback(status, nil);
        }];
}

#pragma mark - Display-status cache

+ (void)setTemporaryCacheWithAdModel:(int)adModel
                               value:(NSInteger)value
                          expiration:(NSInteger)expiration {
    NSDate *expiry = [[NSDate alloc]
        initWithTimeIntervalSinceNow:expiration == 0 ? kRecommendWebAPIDefaultCacheExpiry :
                                                       (double)expiration];
    NSString *statusString = [@(value) stringValue];
    NSDictionary *entry = @{
        kRecommendWebAPICacheKeyStatus : statusString,
        kRecommendWebAPICacheKeyExpire : expiry,
    };
    NSString *adModelKey = [@((unsigned int)adModel) stringValue];
    id cachedData =
        [[NSUserDefaults standardUserDefaults] objectForKey:kRecommendWebAPIDefaultsBannerInfo];
    NSMutableDictionary *cache = nil;
    if (cachedData != nil) {
        cache = [[NSKeyedUnarchiver unarchiveObjectWithData:cachedData] mutableCopy];
    }
    NSData *archived;
    if (cache == nil) {
        NSDictionary *root = [NSDictionary dictionaryWithObject:entry forKey:adModelKey];
        archived = [NSKeyedArchiver archivedDataWithRootObject:root];
    } else {
        cache[adModelKey] = entry;
        archived = [NSKeyedArchiver archivedDataWithRootObject:cache];
    }
    [[NSUserDefaults standardUserDefaults] setObject:archived
                                              forKey:kRecommendWebAPIDefaultsBannerInfo];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (id)getTemporaryCacheWithAdModel:(int)adModel {
    id cachedData =
        [[NSUserDefaults standardUserDefaults] objectForKey:kRecommendWebAPIDefaultsBannerInfo];
    if (cachedData == nil) {
        return nil;
    }
    NSDictionary *cache = [NSKeyedUnarchiver unarchiveObjectWithData:cachedData];
    if (cache == nil) {
        return nil;
    }
    NSString *adModelKey = [@((unsigned int)adModel) stringValue];
    NSDictionary *entry = cache[adModelKey];
    if (entry == nil) {
        return nil;
    }
    if ([entry[kRecommendWebAPICacheKeyExpire] compare:[NSDate date]] != NSOrderedAscending) {
        return entry[kRecommendWebAPICacheKeyStatus];
    }
    NSMutableDictionary *mutableCache = [cache mutableCopy];
    [mutableCache removeObjectForKey:adModelKey];
    NSData *archived = [NSKeyedArchiver archivedDataWithRootObject:mutableCache];
    [[NSUserDefaults standardUserDefaults] setObject:archived
                                              forKey:kRecommendWebAPIDefaultsBannerInfo];
    [[NSUserDefaults standardUserDefaults] synchronize];
    return nil;
}

#pragma mark - Click and start registration

+ (void)clickRegistWithAdIdFrom:(NSString *)adIdFrom
                         adIdTo:(NSString *)adIdTo
                        adModel:(int)adModel
                       callback:
                           (void (^)(id _Nullable location, NSError *_Nullable error))callback {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:4];
    [parameters setValue:adIdFrom forKey:kRecommendWebAPIParamAdIdFrom];
    [parameters setValue:adIdTo forKey:kRecommendWebAPIParamAdIdTo];
    [parameters setValue:[NSString stringWithFormat:kRecommendWebAPIIntegerFormat, adModel]
                  forKey:kRecommendWebAPIParamAdModel];
    [parameters setValue:kRecommendWebAPIParamTrue forKey:kRecommendWebAPIParamIsSdk];
    NSDictionary *merged = [ApplilinkUtilities userAgentParametersJoinDictionary:parameters];
    NSString *url =
        [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kRecommendWebAPIPathClickRegist];
    [ApplilinkWebAPI requestAsynchronousWithURL:url
        method:kRecommendWebAPIMethodGet
        parameters:merged
        userInfo:nil
        tag:0
        cachePolicy:nil
        timeout:kRecommendWebAPIStandardTimeout
        retry:NO
        finishedBlock:^(id request, id response) {
          /** @ghidraAddress 0x2656f0 */
          (void)request;
          if ([response isKindOfClass:[NSDictionary class]] &&
              [response[kRecommendWebAPIKeyStatus] boolValue] &&
              [response[kRecommendWebAPIKeyErrorCode] intValue] ==
                  kRecommendWebAPISuccessSentinel) {
              callback(response[kRecommendWebAPIKeyLocation], nil);
              return;
          }
          NSError *error = RecommendWebAPIMalformedErrorForResponse(response);
          callback(nil, error);
        }
        failedBlock:^(id request, NSError *error) {
          /** @ghidraAddress 0x2658e8 */
          (void)request;
          (void)error;
          callback(nil, nil);
        }];
}

+ (void)appStartWithAdIdFrom:(NSString *)adIdFrom
                      adIdTo:(NSString *)adIdTo
                      adType:(int)adType
                    callback:(void (^)(NSError *_Nullable error))callback {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:3];
    [parameters setValue:adIdFrom forKey:kRecommendWebAPIParamAdIdFrom];
    [parameters setValue:adIdTo forKey:kRecommendWebAPIParamAdIdTo];
    [parameters setValue:[NSString stringWithFormat:kRecommendWebAPIIntegerFormat, adType]
                  forKey:kRecommendWebAPIParamAdType];
    NSString *url =
        [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kRecommendWebAPIPathAppStart];
    [ApplilinkWebAPI requestAsynchronousWithURL:url
        method:kRecommendWebAPIMethodGet
        parameters:parameters
        userInfo:nil
        tag:0
        cachePolicy:nil
        timeout:kRecommendWebAPIStandardTimeout
        retry:NO
        finishedBlock:^(id request, id response) {
          /** @ghidraAddress 0x265b88 */
          (void)request;
          if (![response isKindOfClass:[NSDictionary class]]) {
              NSError *error = RecommendWebAPIMalformedErrorForResponse(response);
              callback(error);
              return;
          }
          BOOL success = NO;
          if ([response[kRecommendWebAPIKeyStatus] boolValue]) {
              success = [response[kRecommendWebAPIKeyErrorCode] intValue] ==
                        kRecommendWebAPISuccessSentinel;
          }
          if (success) {
              callback(nil);
              return;
          }
          NSError *error = RecommendWebAPIMalformedErrorForResponse(response);
          callback(error);
        }
        failedBlock:^(id request, NSError *error) {
          /** @ghidraAddress 0x265d34 */
          (void)request;
          callback(error);
        }];
}

#pragma mark - All advert data

+ (void)allAdDataWithCallBack:(void (^)(id _Nullable data, NSError *_Nullable error))callback {
    NSString *url = [[ApplilinkConsts baseUrlSsl]
        stringByAppendingString:kRecommendWebAPIPathAllAdDataForDisplay];
    [ApplilinkWebAPI requestAsynchronousWithURL:url
        method:kRecommendWebAPIMethodGet
        parameters:nil
        userInfo:nil
        tag:0
        cachePolicy:nil
        timeout:kRecommendWebAPIShortTimeout
        retry:NO
        finishedBlock:^(id request, id response) {
          /** @ghidraAddress 0x265ed4 */
          (void)request;
          if (![response isKindOfClass:[NSDictionary class]]) {
              NSError *error = RecommendWebAPIMalformedErrorForResponse(response);
              callback(nil, error);
              return;
          }
          int errorCode = [response[kRecommendWebAPIKeyErrorCode] intValue];
          BOOL success = [response[kRecommendWebAPIKeyStatus] boolValue] &&
                         errorCode == kRecommendWebAPISuccessSentinel;
          id kind = response[kRecommendWebAPIKeyKind];
          if (![kind isKindOfClass:[NSString class]]) {
              kind = nil;
          }
          if (success) {
              callback(response, nil);
              return;
          }
          NSError *error = RecommendWebAPIErrorForResponse(response, errorCode, kind);
          callback(nil, error);
        }
        failedBlock:^(id request, NSError *error) {
          /** @ghidraAddress 0x266234 */
          (void)request;
          (void)error;
          // The binary forwards a single nil here and drops the transport error.
          callback(nil, nil);
        }];
}

#pragma mark - Layout index

+ (void)layoutIndexWithCallback:(void (^)(NSError *_Nullable error))callback {
    NSString *url =
        [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kRecommendWebAPIPathLayoutIndex];
    [ApplilinkWebAPI requestAsynchronousWithURL:url
        method:kRecommendWebAPIMethodGet
        parameters:nil
        userInfo:nil
        tag:0
        cachePolicy:nil
        timeout:kRecommendWebAPIStandardTimeout
        retry:NO
        finishedBlock:^(id request, id response) {
          /** @ghidraAddress 0x2663d4 */
          (void)request;
          if (![response isKindOfClass:[NSDictionary class]]) {
              NSError *error = RecommendWebAPIMalformedErrorForResponse(response);
              callback(error);
              return;
          }
          if ([response[kRecommendWebAPIKeyStatus] boolValue] &&
              [response[kRecommendWebAPIKeyErrorCode] intValue] ==
                  kRecommendWebAPISuccessSentinel) {
              [ApplilinkConsts setTemplateList:response[kRecommendWebAPIKeyList]];
              callback(nil);
              return;
          }
          NSError *error = RecommendWebAPIMalformedErrorForResponse(response);
          callback(error);
        }
        failedBlock:^(id request, NSError *error) {
          /** @ghidraAddress 0x2665b8 */
          (void)request;
          callback(error);
        }];
}

#pragma mark - Request builders

+ (NSURLRequest *)clickRegistWithAdIdFrom:(NSString *)adIdFrom
                                   adIdTo:(NSString *)adIdTo
                                  adModel:(int)adModel {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:4];
    [parameters setValue:adIdFrom forKey:kRecommendWebAPIParamAdIdFrom];
    [parameters setValue:adIdTo forKey:kRecommendWebAPIParamAdIdTo];
    [parameters setValue:[NSString stringWithFormat:kRecommendWebAPIIntegerFormat, adModel]
                  forKey:kRecommendWebAPIParamAdModel];
    [parameters setValue:kRecommendWebAPIParamTrue forKey:kRecommendWebAPIParamIsSdk];
    NSDictionary *merged = [ApplilinkUtilities userAgentParametersJoinDictionary:parameters];
    ApplilinkWebAPI *api = [[ApplilinkWebAPI alloc] init];
    NSString *url =
        [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kRecommendWebAPIPathClickRegist];
    return [api requestWithURL:url
                        method:kRecommendWebAPIMethodGet
                    parameters:merged
                       timeout:kRecommendWebAPIStandardTimeout
                   cachePolicy:nil];
}

+ (NSURLRequest *)appStartWithAdIdFrom:(NSString *)adIdFrom
                                adIdTo:(NSString *)adIdTo
                                adType:(int)adType {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:3];
    [parameters setValue:adIdFrom forKey:kRecommendWebAPIParamAdIdFrom];
    [parameters setValue:adIdTo forKey:kRecommendWebAPIParamAdIdTo];
    [parameters setValue:[NSString stringWithFormat:kRecommendWebAPIIntegerFormat, adType]
                  forKey:kRecommendWebAPIParamAdType];
    NSDictionary *merged = [ApplilinkUtilities userAgentParametersJoinDictionary:parameters];
    ApplilinkWebAPI *api = [[ApplilinkWebAPI alloc] init];
    NSString *url =
        [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kRecommendWebAPIPathAppStart];
    return [api requestWithURL:url
                        method:kRecommendWebAPIMethodGet
                    parameters:merged
                       timeout:kRecommendWebAPIStandardTimeout
                   cachePolicy:nil];
}

@end
