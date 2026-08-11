#import "RewardWebAPI.h"

#import "ApplilinkConsts.h"
#import "ApplilinkCore.h"
#import "ApplilinkNetworkError.h"
#import "ApplilinkUdid.h"
#import "ApplilinkUtilities.h"
#import "ApplilinkWebAPI.h"
#import "Crypto.h"
#import "NSStringURLEncoding.h"

// The SDK collaborators whose reconstructed headers do not yet declare these members. See
// TYPES_PENDING.md.
@interface ApplilinkWebAPI (Asynchronous)
+ (void)requestAsynchronousWithURL:(nullable NSString *)url
                            method:(nullable NSString *)method
                        parameters:(nullable NSDictionary *)parameters
                          userInfo:(nullable id)userInfo
                               tag:(NSInteger)tag
                       cachePolicy:(nullable id)cachePolicy
                           timeout:(float)timeout
                             retry:(BOOL)retry
                     finishedBlock:(nullable void (^)(id request, id response))finishedBlock
                       failedBlock:(nullable void (^)(id request, id error))failedBlock;
@end

@interface ApplilinkUtilities (Reward)
+ (nullable NSDictionary *)userAgentParameters;
@end

@interface ApplilinkCore (Reward)
+ (nullable NSString *)currentUdid;
+ (nullable NSString *)signatureKey;
+ (void)updatePasteBoard;
@end

// The request timeout, in seconds, applied to every reward request.
static const float kRequestTimeout = 10.0f;

// The maximum number of installed application identifiers posted in a single install report; any
// overflow is posted recursively.
static const NSUInteger kInstallReportPageSize = 10;

// Applilink error codes reported by the reward web API.
enum {
    kErrorUserIdMissing = 0x3e9,   // No user identifier, or a login parameter error was returned.
    kErrorAuthorization = 0x3ea,   // The reward server rejected the request's authorization.
    kErrorUdidSetupFailed = 0x402, // The UDID parameters could not be assembled.
    kErrorAppIdMissing = 0x405,    // No Applilink application identifier is set.
    kErrorInstallRejected = 0x3ef, // The install-report request was rejected.
    kErrorInstallConflict = 0x3f1, // The install-report request conflicted with server state.
    kErrorGeneric = 1000,          // A generic or unexpected server response.
};

// The reward server's success sentinel returned in the response's error_code field.
static const int kResponseSuccess = 100000000;

// Login-server error codes mapped to the authorization error.
enum {
    kLoginErrorAuthA = 0xc106cbb,
    kLoginErrorAuthB = 0xc106cba,
    kLoginErrorAuthC = 0xc106cb9,
};

// Install-server error codes.
enum {
    kInstallErrorRejected = 999999999,
    kInstallErrorConflict = 0xc106101,
};

// Reward request priorities.
enum {
    kPriorityNormal = 0,     // Normal install / initial login.
    kPriorityThreeKind = 1,  // Retry once three-kind UDIDs are present.
    kPriorityPasteBoard = 2, // Pasteboard-sourced path.
};

// Reward SSL request paths appended to ApplilinkConsts.baseUrlSsl.
static NSString *const kPathAppInstallRegist = @"/reward/app/install/regist.php";
static NSString *const kPathCheckLoginStatus = @"/reward/auth/checkLoginStatus.php";
static NSString *const kPathAuthLogin = @"/reward/auth/login.php";
static NSString *const kPathAppIndex = @"/reward/app/index.php";
static NSString *const kPathAppliIdIndex = @"/reward/app/install/appliid/index.php";
static NSString *const kPathCheckAllInstall = @"/reward/app/checkAllInstall.php";
static NSString *const kPathPreInfoForDisplay = @"/reward/app/preInfoForDisplay.php";
static NSString *const kPathInstallReportRegist = @"/reward/app/install/report/regist.php";
static NSString *const kPathBannerDetail = @"/reward/banner/detail.php";

// HTTP methods.
static NSString *const kHTTPMethodGet = @"GET";
static NSString *const kHTTPMethodPost = @"POST";

// Request parameter keys and fixed values.
static NSString *const kParamUserId = @"user_id";
static NSString *const kParamAppliId = @"appli_id";
static NSString *const kParamAppliIdList = @"appli_id_list";
static NSString *const kParamType = @"type";
static NSString *const kParamFormat = @"format";
static NSString *const kParamFormatJson = @"json";
static NSString *const kParamCfr = @"cfr";
static NSString *const kParamCfrValue = @"1";
static NSString *const kParamSignature = @"signature";

// Response dictionary keys.
static NSString *const kResponseStatus = @"status";
static NSString *const kResponseErrorCode = @"error_code";
static NSString *const kResponseLoginStatus = @"login_status";
static NSString *const kResponseAllInstallFlg = @"all_install_flg";
static NSString *const kResponseKind = @"kind";
static NSString *const kResponseCampaignFlg = @"campaign_flg";

// Response "kind" discriminators for login and install errors.
static NSString *const kResponseKindAuthorization = @"authorization";
static NSString *const kResponseKindParameterError = @"parameter_error";

// The temporary-cache key and NSUserDefaults key for the persisted install/campaign flag.
static NSString *const kCacheKeyAppInstallFlg = @"appInstallFlg";
static NSString *const kDefaultsCampaignFlg = @"ApplilinkReward.campaignFlg";

// The keys of the archived temporary-cache entry dictionary.
static NSString *const kCacheKeyValue = @"Value";
static NSString *const kCacheKeyExpire = @"Expire";

// The parameter-pair and signature-source formats.
static NSString *const kSignPairArrayFormat = @"%@[]=%@";
static NSString *const kSignPairFormat = @"%@=%@";
static NSString *const kSignJoinSeparator = @"&";
static NSString *const kSignSourceFormat = @"%@&%@";
static NSString *const kFlagStringFormat = @"%@";

// Whether a JSON response is a well-formed reward success: an NSDictionary whose status is true and
// whose error_code is the success sentinel.
static BOOL RewardResponseIsSuccess(id response) {
    if (![response isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    if (![response[kResponseStatus] boolValue]) {
        return NO;
    }
    return [response[kResponseErrorCode] intValue] == kResponseSuccess;
}

@implementation RewardWebAPI

#pragma mark - Install

/** @ghidraAddress 0x253fd4 */
+ (void)postApplicationInstallWithPriority:(int)priority
                                  callback:(void (^)(NSError *error))callback {
    NSString *appliId = [ApplilinkConsts appliId];
    if (appliId == nil) {
        callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorAppIdMissing]);
        return;
    }
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:2];
    [parameters setValue:appliId forKey:kParamAppliId];
    if (![ApplilinkUdid setUdidParameters:parameters isUDIDPriorityType:priority]) {
        callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorUdidSetupFailed]);
        return;
    }
    NSDictionary *signedParameters =
        [ApplilinkUtilities userAgentParametersJoinDictionary:parameters];
    NSString *url = [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kPathAppInstallRegist];
    [ApplilinkWebAPI requestAsynchronousWithURL:url
        method:kHTTPMethodPost
        parameters:signedParameters
        userInfo:nil
        tag:0
        cachePolicy:nil
        timeout:kRequestTimeout
        retry:NO
        finishedBlock:^(id __attribute__((unused)) request, id response) {
          /** @ghidraAddress 0x2542b8 */
          if (![response isKindOfClass:[NSDictionary class]]) {
              callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorGeneric
                                                                     userInfo:response]);
              return;
          }
          BOOL statusOk = [response[kResponseStatus] boolValue];
          int errorCode = [response[kResponseErrorCode] intValue];
          NSString *kind = response[kResponseKind];
          if (![kind isKindOfClass:[NSString class]]) {
              kind = nil;
          }
          if (statusOk && errorCode == kResponseSuccess) {
              if (priority == kPriorityNormal && [ApplilinkUdid isUdidThreeKinds]) {
                  [RewardWebAPI postApplicationInstallWithPriority:kPriorityThreeKind
                                                          callback:callback];
                  return;
              }
              if (priority != kPriorityPasteBoard) {
                  NSString *campaignFlg = response[kResponseCampaignFlg];
                  if ([campaignFlg isKindOfClass:[NSString class]]) {
                      [[NSUserDefaults standardUserDefaults] setObject:campaignFlg
                                                                forKey:kDefaultsCampaignFlg];
                      [ApplilinkUdid setUdidKeychainFromPasteBoard];
                      [[NSUserDefaults standardUserDefaults] synchronize];
                  }
                  NSString *currentUdid = [ApplilinkCore currentUdid];
                  if (currentUdid != nil) {
                      [ApplilinkUdid setOldUdid:currentUdid error:nil];
                  }
                  [ApplilinkCore updatePasteBoard];
              }
              callback(nil);
              return;
          }
          if (errorCode == kInstallErrorRejected) {
              callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorInstallRejected
                                                                     userInfo:response]);
          } else if (errorCode == kInstallErrorConflict) {
              callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorInstallConflict
                                                                     userInfo:response]);
          } else if ([kind isEqualToString:kResponseKindAuthorization]) {
              callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorAuthorization
                                                                     userInfo:response]);
          } else if ([kind isEqualToString:kResponseKindParameterError]) {
              callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorUserIdMissing
                                                                     userInfo:response]);
          } else {
              callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorGeneric
                                                                     userInfo:response]);
          }
        }
        failedBlock:^(id __attribute__((unused)) request, id error) {
          /** @ghidraAddress 0x2547a0 */
          callback(error);
        }];
}

#pragma mark - Login

/** @ghidraAddress 0x2547c8 */
+ (void)checkLoginWithBlock:(void (^)(BOOL valid, NSError *error))block {
    if ([ApplilinkCore udid] != nil && [ApplilinkCore old_udid] == nil) {
        [ApplilinkUdid setUdidKeychainFromPasteBoard];
    }
    if ([ApplilinkConsts isNeedRewardLogin]) {
        block(NO, nil);
        return;
    }
    NSString *url = [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kPathCheckLoginStatus];
    [ApplilinkWebAPI requestAsynchronousWithURL:url
        method:kHTTPMethodGet
        parameters:nil
        userInfo:nil
        tag:0
        cachePolicy:nil
        timeout:kRequestTimeout
        retry:NO
        finishedBlock:^(id __attribute__((unused)) request, id response) {
          /** @ghidraAddress 0x2549f8 */
          if (![response isKindOfClass:[NSDictionary class]]) {
              block(NO,
                    [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorGeneric
                                                                  userInfo:response]);
              return;
          }
          if ([response[kResponseStatus] boolValue]) {
              block([response[kResponseLoginStatus] boolValue], nil);
              return;
          }
          block(NO,
                [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorGeneric
                                                              userInfo:response]);
        }
        failedBlock:^(id __attribute__((unused)) request, id error) {
          /** @ghidraAddress 0x254b84 */
          block(NO, error);
        }];
}

/** @ghidraAddress 0x254bac */
+ (void)startLoginWithUserId:(NSString *)userId
                withPriority:(int)priority
                    callback:(void (^)(NSError *error))callback {
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
    if (userId == nil) {
        callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorUserIdMissing]);
        return;
    }
    [parameters setValue:[NSStringURLEncoding URLEncodedString:userId] forKey:kParamUserId];
    if (![ApplilinkUdid setUdidParameters:parameters isUDIDPriorityType:priority]) {
        callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorUdidSetupFailed]);
        return;
    }
    // The merge helper declares NSDictionary * but always returns the NSMutableDictionary it built;
    // the signature and cfr entries are added to it below.
    NSMutableDictionary *signedParameters =
        (NSMutableDictionary *)[ApplilinkUtilities userAgentParametersJoinDictionary:parameters];
    [parameters removeAllObjects];
    [RewardWebAPI setSignatureWithParameters:signedParameters];
    [signedParameters setValue:kParamCfrValue forKey:kParamCfr];
    NSString *url = [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kPathAuthLogin];
    [ApplilinkWebAPI requestAsynchronousWithURL:url
        method:kHTTPMethodPost
        parameters:signedParameters
        userInfo:nil
        tag:0
        cachePolicy:nil
        timeout:kRequestTimeout
        retry:NO
        finishedBlock:^(id __attribute__((unused)) request, id response) {
          /** @ghidraAddress 0x254f04 */
          if (![response isKindOfClass:[NSDictionary class]]) {
              callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorGeneric
                                                                     userInfo:response]);
              return;
          }
          if ([response[kResponseStatus] boolValue] &&
              [response[kResponseErrorCode] intValue] == kResponseSuccess) {
              if (priority == kPriorityNormal && [ApplilinkUdid isUdidThreeKinds]) {
                  [RewardWebAPI startLoginWithUserId:userId
                                        withPriority:kPriorityThreeKind
                                            callback:callback];
                  return;
              }
              if (priority == kPriorityPasteBoard) {
                  [RewardWebAPI startLoginWithUserId:userId
                                        withPriority:kPriorityPasteBoard
                                            callback:callback];
                  return;
              }
              callback(nil);
              return;
          }
          int errorCode = [response[kResponseErrorCode] intValue];
          if (errorCode == kLoginErrorAuthA || errorCode == kLoginErrorAuthB ||
              errorCode == kLoginErrorAuthC) {
              callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorAuthorization
                                                                     userInfo:response]);
              return;
          }
          if ([response[kResponseKind] isEqualToString:kResponseKindParameterError]) {
              callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorUserIdMissing
                                                                     userInfo:response]);
          } else {
              callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorGeneric
                                                                     userInfo:response]);
          }
        }
        failedBlock:^(id __attribute__((unused)) request, id error) {
          /** @ghidraAddress 0x255318 */
          callback(error);
        }];
}

#pragma mark - Application lists

/** @ghidraAddress 0x255340 */
+ (void)appListWithCampaignId:(NSString *)campaignId
                    inCompany:(NSString *)company
                       offset:(NSString *)offset
                        limit:(NSString *)limit
                     callback:(void (^)(NSDictionary *result, NSError *error))callback {
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
    [parameters setValue:kParamFormatJson forKey:kParamFormat];
    NSString *url = [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kPathAppIndex];
    [ApplilinkWebAPI requestAsynchronousWithURL:url
        method:kHTTPMethodGet
        parameters:parameters
        userInfo:nil
        tag:0
        cachePolicy:nil
        timeout:kRequestTimeout
        retry:NO
        finishedBlock:^(id __attribute__((unused)) request, id response) {
          /** @ghidraAddress 0x255528 */
          if (RewardResponseIsSuccess(response)) {
              callback(response, nil);
              return;
          }
          callback(nil,
                   [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorGeneric
                                                                 userInfo:response]);
        }
        failedBlock:^(id __attribute__((unused)) request, id error) {
          /** @ghidraAddress 0x2556dc */
          callback(nil, error);
        }];
    [parameters removeAllObjects]; // Yes, the binary clears the dictionary after dispatching.
}

/** @ghidraAddress 0x255704 */
+ (void)appliIdListWithType:(int)type
                   callback:(void (^)(NSDictionary *result, NSError *error))callback {
    NSDictionary *parameters = [NSDictionary dictionaryWithObject:@(type) forKey:kParamType];
    NSString *url = [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kPathAppliIdIndex];
    [ApplilinkWebAPI requestAsynchronousWithURL:url
        method:kHTTPMethodGet
        parameters:parameters
        userInfo:nil
        tag:0
        cachePolicy:nil
        timeout:kRequestTimeout
        retry:NO
        finishedBlock:^(id __attribute__((unused)) request, id response) {
          /** @ghidraAddress 0x2558f4 */
          if (RewardResponseIsSuccess(response)) {
              callback(response, nil);
              return;
          }
          callback(nil,
                   [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorGeneric
                                                                 userInfo:response]);
        }
        failedBlock:^(id __attribute__((unused)) request, id error) {
          /** @ghidraAddress 0x255aa8 */
          callback(nil, error);
        }];
}

#pragma mark - Status flags

/** @ghidraAddress 0x255ad0 */
+ (void)allInstallFlgWithCallback:(void (^)(NSInteger flg, NSError *error))callback {
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
    [parameters setValue:kParamFormatJson forKey:kParamFormat];
    NSString *url = [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kPathCheckAllInstall];
    [ApplilinkWebAPI requestAsynchronousWithURL:url
        method:kHTTPMethodGet
        parameters:parameters
        userInfo:nil
        tag:0
        cachePolicy:nil
        timeout:kRequestTimeout
        retry:NO
        finishedBlock:^(id __attribute__((unused)) request, id response) {
          /** @ghidraAddress 0x255d70 */
          if (![response isKindOfClass:[NSDictionary class]]) {
              callback(0,
                       [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorGeneric
                                                                     userInfo:response]);
              return;
          }
          if ([response[kResponseStatus] boolValue] &&
              [response[kResponseErrorCode] intValue] == kResponseSuccess) {
              id flg = response[kResponseAllInstallFlg];
              if (flg != nil) {
                  [RewardWebAPI
                      setTemporaryCacheWithKey:kCacheKeyAppInstallFlg
                                         value:[NSString stringWithFormat:kFlagStringFormat, flg]
                                    expiration:0];
                  callback([flg intValue], nil);
                  return;
              }
              callback(-1,
                       [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorGeneric
                                                                     userInfo:response]);
              return;
          }
          callback(0,
                   [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorGeneric
                                                                 userInfo:response]);
        }
        failedBlock:^(id __attribute__((unused)) request, id error) {
          /** @ghidraAddress 0x25601c */
          callback(0, error);
        }];
}

/** @ghidraAddress 0x256044 */
+ (void)getPreInfoWithCallback:(void (^)(NSInteger flg, NSError *error))callback {
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
    [parameters setValue:kParamFormatJson forKey:kParamFormat];
    NSString *url = [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kPathPreInfoForDisplay];
    [ApplilinkWebAPI requestAsynchronousWithURL:url
        method:kHTTPMethodGet
        parameters:parameters
        userInfo:nil
        tag:0
        cachePolicy:nil
        timeout:kRequestTimeout
        retry:NO
        finishedBlock:^(id __attribute__((unused)) request, id response) {
          /** @ghidraAddress 0x2562b4 */
          if (![response isKindOfClass:[NSDictionary class]]) {
              callback(0,
                       [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorGeneric
                                                                     userInfo:response]);
              return;
          }
          if ([response[kResponseStatus] boolValue] &&
              [response[kResponseErrorCode] intValue] == kResponseSuccess) {
              id flg = response[kResponseAllInstallFlg];
              if (flg != nil) {
                  [RewardWebAPI
                      setTemporaryCacheWithKey:kCacheKeyAppInstallFlg
                                         value:[NSString stringWithFormat:kFlagStringFormat, flg]
                                    expiration:0];
                  callback([flg intValue], nil);
                  return;
              }
              callback(-1,
                       [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorGeneric
                                                                     userInfo:response]);
              return;
          }
          callback(0,
                   [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorGeneric
                                                                 userInfo:response]);
        }
        failedBlock:^(id __attribute__((unused)) request, id error) {
          /** @ghidraAddress 0x256560 */
          callback(0, error);
        }];
}

#pragma mark - Install report

/** @ghidraAddress 0x256588 */
+ (void)postAppliInstallReportWithAppliList:(NSArray *)appliList
                                   callback:(void (^)(NSError *error))callback {
    NSArray *page;
    NSArray *remaining;
    if (appliList.count < kInstallReportPageSize + 1) {
        page = [appliList copy];
        remaining = nil;
    } else {
        NSIndexSet *pageRange =
            [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, kInstallReportPageSize)];
        page = [appliList objectsAtIndexes:pageRange];
        NSIndexSet *remainingRange = [NSIndexSet
            indexSetWithIndexesInRange:NSMakeRange(kInstallReportPageSize,
                                                   appliList.count - kInstallReportPageSize)];
        remaining = [appliList objectsAtIndexes:remainingRange];
    }
    NSDictionary *parameters = [NSDictionary dictionaryWithObject:page forKey:kParamAppliIdList];
    NSString *url = [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kPathInstallReportRegist];
    [ApplilinkWebAPI requestAsynchronousWithURL:url
        method:kHTTPMethodPost
        parameters:parameters
        userInfo:nil
        tag:0
        cachePolicy:nil
        timeout:kRequestTimeout
        retry:NO
        finishedBlock:^(id __attribute__((unused)) request, id response) {
          /** @ghidraAddress 0x256890 */
          if (![response isKindOfClass:[NSDictionary class]]) {
              callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorGeneric
                                                                     userInfo:response]);
              return;
          }
          if ([response[kResponseStatus] boolValue] &&
              [response[kResponseErrorCode] intValue] == kResponseSuccess) {
              if (remaining != nil && remaining.count != 0) {
                  [RewardWebAPI postAppliInstallReportWithAppliList:remaining callback:callback];
                  return;
              }
              callback(nil);
              return;
          }
          callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorGeneric
                                                                 userInfo:response]);
        }
        failedBlock:^(id __attribute__((unused)) request, id result) {
          /** @ghidraAddress 0x256ab4 */
          callback(result);
        }];
}

#pragma mark - Banner

/** @ghidraAddress 0x256adc */
+ (void)bannerInfoWithBlock:(void (^)(NSDictionary *result, NSError *error))block {
    NSDictionary *parameters = [ApplilinkUtilities userAgentParameters];
    NSString *url = [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kPathBannerDetail];
    [ApplilinkWebAPI requestAsynchronousWithURL:url
        method:kHTTPMethodGet
        parameters:parameters
        userInfo:nil
        tag:0
        cachePolicy:nil
        timeout:kRequestTimeout
        retry:NO
        finishedBlock:^(id __attribute__((unused)) request, id response) {
          /** @ghidraAddress 0x256c88 */
          if (RewardResponseIsSuccess(response)) {
              block(response, nil);
              return;
          }
          block(nil,
                [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorGeneric
                                                              userInfo:response]);
        }
        failedBlock:^(id __attribute__((unused)) request, id error) {
          /** @ghidraAddress 0x256e3c */
          block(nil, error);
        }];
}

#pragma mark - Signing and cache

/** @ghidraAddress 0x256e64 */
+ (void)setSignatureWithParameters:(NSMutableDictionary *)parameters {
    NSArray *sortedKeys =
        [[parameters allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    NSMutableArray *pairs = [NSMutableArray array];
    for (NSString *key in sortedKeys) {
        id value = parameters[key];
        if ([value isKindOfClass:[NSArray class]]) {
            for (NSUInteger i = 0; i < [value count]; ++i) {
                [pairs addObject:[NSString stringWithFormat:kSignPairArrayFormat, key, value[i]]];
            }
        } else {
            [pairs addObject:[NSString stringWithFormat:kSignPairFormat, key, value]];
        }
    }
    NSString *joined = [pairs componentsJoinedByString:kSignJoinSeparator];
    NSString *signatureSource =
        [NSString stringWithFormat:kSignSourceFormat, joined, [ApplilinkCore signatureKey]];
    NSString *signature = [Crypto sha256:[NSStringURLEncoding URLDecodedString:signatureSource]];
    parameters[kParamSignature] = signature;
}

/** @ghidraAddress 0x257324 */
+ (void)setTemporaryCacheWithKey:(NSString *)key value:(id)value expiration:(NSInteger)expiration {
    NSDate *expiry =
        [[NSDate alloc] initWithTimeIntervalSinceNow:(expiration == 0 ? 1.0 : (double)expiration)];
    NSDictionary *cacheEntry = [NSDictionary
        dictionaryWithObjectsAndKeys:value, kCacheKeyValue, expiry, kCacheKeyExpire, nil];
    [[NSUserDefaults standardUserDefaults]
        setObject:[NSKeyedArchiver archivedDataWithRootObject:cacheEntry]
           forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end
