#import "AnalysisNetworkCore.h"

#import <UIKit/UIKit.h>

#import "ApplilinkConsts.h"
#import "ApplilinkCore.h"
#import "ApplilinkNetworkError.h"
#import "ApplilinkUdid.h"
#import "ApplilinkUtilities.h"
#import "ApplilinkWebAPI.h"
#import "NSStringURLEncoding.h"

// The advertising-identifier accessor is not yet reconstructed in this tree's ApplilinkCore stub;
// declare the class method the browser posters call. The full class lives in ../rbplus-src.
@interface ApplilinkCore (AnalysisNetworkCore)
+ (nullable NSString *)ad_udid;
@end

// Analytics action-type codes posted in the request's action_type parameter.
enum {
    kAnalysisActionTypeNone = 0,
    kAnalysisActionTypeInitalize = 1,
    kAnalysisActionTypeDau = 2,
    kAnalysisActionTypeResult = 3,
    kAnalysisActionTypeSetUserID = 14,
};

// Applilink error codes forwarded to the caller's completion callback.
enum {
    kApplilinkErrorGeneric = 1000,          // Non-success server response.
    kApplilinkErrorMissingParameter = 1001, // A required parameter was nil.
    kApplilinkErrorUdidParameters = 1026,   // ApplilinkUdid could not supply UDID parameters.
    kApplilinkErrorTrackingDisabled = 1028, // Advertising tracking is disabled.
};

// The server response is a success when its status is truthy and its error_code equals this value.
static const int kApplilinkResponseSuccessCode = 100000000;

// The response browser flag value that means the conversion has already been performed.
static const int kBrowserConversionAlreadyDone = 1;

// Request timeout, in seconds, for every analytics request.
static const float kAnalysisRequestTimeout = 10.0f;

// Request parameter and response key strings.
static NSString *const kAnalysisParamActionType = @"action_type";
static NSString *const kAnalysisParamResultId = @"result_id";
static NSString *const kAnalysisParamUserId = @"user_id";
static NSString *const kAnalysisParamUdidSrc = @"udid_src";
static NSString *const kAnalysisParamAdLocation = @"ad_location";
static NSString *const kAnalysisParamImpressionId = @"impression_id";
static NSString *const kAnalysisParamSystem = @"system";
static NSString *const kAnalysisParamAdType = @"ad_type";
static NSString *const kAnalysisParamAdModel = @"ad_model";
static NSString *const kAnalysisParamAppliIdToList = @"appli_id_to_list";
static NSString *const kAnalysisParamCreativeIdList = @"creative_id_list";
static NSString *const kAnalysisParamIncentiveTypeList = @"incentive_type_list";
static NSString *const kAnalysisParamInstallFlgList = @"install_flg_list";
static NSString *const kAnalysisParamAppliIdTo = @"appli_id_to";
static NSString *const kAnalysisParamCreativeId = @"creative_id";
static NSString *const kAnalysisParamDisplayNumber = @"display_number";
static NSString *const kAnalysisParamIncentiveType = @"incentive_type";
static NSString *const kAnalysisParamInstallFlg = @"install_flg";
static NSString *const kAnalysisParamStatus = @"status";
static NSString *const kAnalysisParamFormat = @"format";
static NSString *const kAnalysisParamUaAppliId = @"ua_appli_id";
static NSString *const kAnalysisParamUdid = @"udid";
static NSString *const kAnalysisParamIdfa = @"idfa";
static NSString *const kAnalysisSystemValueAd = @"ad";
static NSString *const kAnalysisFormatValueJson = @"json";

static NSString *const kAnalysisResponseKeyStatus = @"status";
static NSString *const kAnalysisResponseKeyErrorCode = @"error_code";
static NSString *const kAnalysisResponseKeyBrowser = @"browser";
static NSString *const kAnalysisResponseKeyVersion = @"version";
static NSString *const kAnalysisResponseKeyUrl = @"url";

static NSString *const kAnalysisPathData = @"/analysis/regist.php";
static NSString *const kAnalysisPathListRegist = @"/analysis/list/regist.php";
static NSString *const kAnalysisPathClickRegist = @"/analysis/click/regist.php";
static NSString *const kAnalysisPathMovieRegist = @"/analysis/movie/regist.php";
static NSString *const kAnalysisPathGetSyncStatus = @"/analysis/app/getSyncStatus.php";
static NSString *const kAnalysisPathGetSyncUrl = @"/analysis/app/getSyncUrl.php";

static NSString *const kHTTPMethodGet = @"GET";
static NSString *const kHTTPMethodPost = @"POST";

static NSString *const kAnalysisDefaultsInitalizeKey = @"ApplilinkAnalysis.initialize";
static NSString *const kAnalysisDefaultsDauDateKey = @"ApplilinkAnalysis.dauMeasurementDate";
static NSString *const kAnalysisDefaultsEnvKey = @"ApplilinkNetwork.env";
static NSString *const kAnalysisDefaultsBrowserConversionFirstKey =
    @"ApplilinkNetwork.BrowserConversionFirst";
static NSString *const kAnalysisDefaultsBrowserConversionVersionKey =
    @"ApplilinkNetwork.BrowserConversionVersion";
static NSString *const kAnalysisDefaultsBrowserConversionIdfaKey =
    @"ApplilinkNetwork.BrowserConversionIdfa";

// Whether a parsed applilink response envelope reports success.
static BOOL AnalysisResponseIsSuccess(NSDictionary *response) {
    return [response[kAnalysisResponseKeyStatus] boolValue] &&
           [response[kAnalysisResponseKeyErrorCode] intValue] == kApplilinkResponseSuccessCode;
}

@implementation AnalysisNetworkCore

#pragma mark - Analysis posting

+ (void)postInitalizeWithCallback:(ApplilinkAnalysisCallback)callback {
    if ([self getInitalizeFlg]) {
        callback(nil);
        return;
    }

    NSDate *now = [NSDate date];
    [self postAnalysisDataWithActionType:kAnalysisActionTypeInitalize
        resultId:nil
        uesrId:nil
        finishedBlock:^(id request, id result) {
          /** @ghidraAddress 0x238f1c */
          (void)request;
          NSDictionary *response = (NSDictionary *)result;
          if (AnalysisResponseIsSuccess(response)) {
              [[NSUserDefaults standardUserDefaults] setObject:now
                                                        forKey:kAnalysisDefaultsInitalizeKey];
              [[NSUserDefaults standardUserDefaults] synchronize];
              callback(nil);
              return;
          }
          callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:kApplilinkErrorGeneric
                                                                 userInfo:response]);
        }
        failedBlock:^(id request, NSError *error) {
          /** @ghidraAddress 0x239124 */
          (void)request;
          (void)error;
          callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:kApplilinkErrorGeneric]);
        }
        callback:callback];
}

+ (void)postDAUWithCallback:(ApplilinkAnalysisCallback)callback {
    if ([self getSendDauFlg]) {
        callback(nil);
        return;
    }

    NSString *userId = [ApplilinkConsts userId];
    NSDate *now = [NSDate date];
    [self postAnalysisDataWithActionType:kAnalysisActionTypeDau
        resultId:nil
        uesrId:userId
        finishedBlock:^(id request, id result) {
          /** @ghidraAddress 0x239344 */
          (void)request;
          NSDictionary *response = (NSDictionary *)result;
          if (AnalysisResponseIsSuccess(response)) {
              [[NSUserDefaults standardUserDefaults] setObject:now
                                                        forKey:kAnalysisDefaultsDauDateKey];
              [[NSUserDefaults standardUserDefaults] synchronize];
              callback(nil);
              return;
          }
          callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:kApplilinkErrorGeneric
                                                                 userInfo:response]);
        }
        failedBlock:^(id request, NSError *error) {
          /** @ghidraAddress 0x23954c */
          (void)request;
          (void)error;
          callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:kApplilinkErrorGeneric]);
        }
        callback:callback];
}

+ (void)postAnalysisDataWithResultId:(NSString *)resultId
                            callback:(ApplilinkAnalysisCallback)callback {
    if (resultId == nil) {
        callback([ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kApplilinkErrorMissingParameter]);
        return;
    }

    NSString *userId = [ApplilinkConsts userId];
    [self postAnalysisDataWithActionType:kAnalysisActionTypeResult
        resultId:resultId
        uesrId:userId
        finishedBlock:^(id request, id result) {
          /** @ghidraAddress 0x239760 */
          (void)request;
          NSDictionary *response = (NSDictionary *)result;
          if (AnalysisResponseIsSuccess(response)) {
              callback(nil);
              return;
          }
          callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:kApplilinkErrorGeneric
                                                                 userInfo:response]);
        }
        failedBlock:^(id request, NSError *error) {
          /** @ghidraAddress 0x2398a8 */
          (void)request;
          (void)error;
          callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:kApplilinkErrorGeneric]);
        }
        callback:callback];
}

+ (void)postSetUserIDWithCallback:(ApplilinkAnalysisCallback)callback {
    NSString *userId = [ApplilinkConsts userId];
    if (userId == nil) {
        callback([ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kApplilinkErrorMissingParameter]);
        return;
    }

    [self postAnalysisDataWithActionType:kAnalysisActionTypeSetUserID
        resultId:nil
        uesrId:userId
        finishedBlock:^(id request, id result) {
          /** @ghidraAddress 0x239aa0 */
          (void)request;
          NSDictionary *response = (NSDictionary *)result;
          if (AnalysisResponseIsSuccess(response)) {
              callback(nil);
              return;
          }
          callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:kApplilinkErrorGeneric
                                                                 userInfo:response]);
        }
        failedBlock:^(id request, NSError *error) {
          /** @ghidraAddress 0x239be8 */
          (void)request;
          (void)error;
          callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:kApplilinkErrorGeneric]);
        }
        callback:callback];
}

+ (void)postAnalysisDataWithActionType:(int)actionType
                              resultId:(NSString *)resultId
                                uesrId:(NSString *)uesrId
                         finishedBlock:(ApplilinkWebAPIFinishedBlock)finishedBlock
                           failedBlock:(ApplilinkWebAPIFailedBlock)failedBlock
                              callback:(ApplilinkAnalysisCallback)callback {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:4];
    NSError *error;
    if (actionType == kAnalysisActionTypeNone) {
        error =
            [ApplilinkNetworkError localizedApplilinkErrorWithCode:kApplilinkErrorMissingParameter];
    } else {
        parameters[kAnalysisParamActionType] = [NSString stringWithFormat:@"%d", actionType];
        if (![ApplilinkUdid setUdidParameters:parameters]) {
            error = [ApplilinkNetworkError
                localizedApplilinkErrorWithCode:kApplilinkErrorUdidParameters];
        } else if (![ApplilinkUdid isAdvertisingTrackingEnabled]) {
            error = [ApplilinkNetworkError
                localizedApplilinkErrorWithCode:kApplilinkErrorTrackingDisabled];
        } else {
            if (resultId && resultId.length != 0) {
                parameters[kAnalysisParamResultId] = resultId;
            }
            if (uesrId && uesrId.length != 0) {
                parameters[kAnalysisParamUserId] = [NSStringURLEncoding URLEncodedString:uesrId];
            }

            NSString *udidSource = [ApplilinkUdid isAdvertisingTrackingOSVersion] ?
                                       [ApplilinkUdid getAdUdid] :
                                       [ApplilinkUdid getCFUUID];
            if (udidSource) {
                parameters[kAnalysisParamUdidSrc] = udidSource;
            }

            NSDictionary *merged =
                [ApplilinkUtilities userAgentParametersJoinDictionary:parameters];
            NSString *url =
                [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kAnalysisPathData];
            [ApplilinkWebAPI requestAsynchronousWithURL:url
                                                 method:kHTTPMethodPost
                                             parameters:merged
                                               userInfo:nil
                                                    tag:0
                                            cachePolicy:nil
                                                timeout:kAnalysisRequestTimeout
                                                  retry:NO
                                          finishedBlock:finishedBlock
                                            failedBlock:failedBlock];
            return;
        }
    }
    callback(error);
}

+ (void)postAnalysisDeviceDataWithActionType:(ApplilinkAnalysisCallback)callback {
    // The sole argument is the callback; the binary posts a fixed user-identifier action (type 14)
    // and forwards the block as both the success and failure completion callback.
    [self postAnalysisDataWithActionType:kAnalysisActionTypeSetUserID
        resultId:nil
        uesrId:nil
        finishedBlock:^(id request, id result) {
          /** @ghidraAddress 0x23a144 */
          (void)request;
          NSDictionary *response = (NSDictionary *)result;
          if (AnalysisResponseIsSuccess(response)) {
              callback(nil);
              return;
          }
          callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:kApplilinkErrorGeneric
                                                                 userInfo:response]);
        }
        failedBlock:^(id request, NSError *error) {
          /** @ghidraAddress 0x23a28c */
          (void)request;
          (void)error;
          callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:kApplilinkErrorGeneric]);
        }
        callback:callback];
}

+ (void)postAnalysisDataWithCallback:(ApplilinkAnalysisCallback)callback {
    [self postInitalizeWithCallback:^(NSError *dataError) {
      /** @ghidraAddress 0x23cbc0 */
      // The DAU ping is sent unconditionally, even when the initialisation post failed.
      [self postDAUWithCallback:^(NSError *dauError) {
        /** @ghidraAddress 0x23cc70 */
        // Forward the initialisation error when it occurred, otherwise the DAU error.
        callback(dataError ? dataError : dauError);
      }];
    }];
}

#pragma mark - Web browser

+ (void)openExternalWebBrowserCore:(NSString *)url
                               env:(NSString *)env
                          callback:(ApplilinkAnalysisCallback)callback {
    NSMutableDictionary *baseParameters = [[NSMutableDictionary alloc] init];
    baseParameters[kAnalysisParamFormat] = kAnalysisFormatValueJson;

    if (![ApplilinkUdid isAdvertisingTrackingEnabled]) {
        callback([ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kApplilinkErrorTrackingDisabled]);
        return;
    }

    NSString *idfa = [ApplilinkUdid isAdvertisingTrackingOSVersion] ? [ApplilinkUdid getAdUdid] :
                                                                      [ApplilinkUdid getCFUUID];
    NSMutableDictionary *parameters = (NSMutableDictionary *)[ApplilinkUtilities
        userAgentParametersJoinDictionary:baseParameters];
    if (url == nil) {
        // The binary neither sends the request nor invokes the callback when the appli id is nil.
        return;
    }
    parameters[kAnalysisParamUaAppliId] = url;
    [[NSUserDefaults standardUserDefaults] setObject:env forKey:kAnalysisDefaultsEnvKey];

    NSString *requestUrl =
        [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kAnalysisPathGetSyncStatus];
    [ApplilinkWebAPI
        requestAsynchronousWithURL:requestUrl
                            method:kHTTPMethodGet
                        parameters:parameters
                          userInfo:nil
                               tag:0
                       cachePolicy:nil
                           timeout:kAnalysisRequestTimeout
                             retry:NO
                     finishedBlock:^(id request, id result) {
                       /** @ghidraAddress 0x23a658 */
                       (void)request;
                       NSDictionary *response = (NSDictionary *)result;
                       if (!AnalysisResponseIsSuccess(response)) {
                           callback([ApplilinkNetworkError
                               localizedApplilinkErrorWithCode:kApplilinkErrorGeneric
                                                      userInfo:response]);
                           return;
                       }
                       // The callback is reached only on the error path above; every success path
                       // returns without signalling completion.
                       if (![response[kAnalysisResponseKeyBrowser] boolValue]) {
                           return;
                       }

                       NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                       id storedFirst =
                           [defaults objectForKey:kAnalysisDefaultsBrowserConversionFirstKey];
                       NSInteger storedVersion =
                           [defaults integerForKey:kAnalysisDefaultsBrowserConversionVersionKey];
                       NSString *storedIdfa =
                           [defaults objectForKey:kAnalysisDefaultsBrowserConversionIdfaKey];

                       BOOL firstRun = storedFirst == nil || ![storedIdfa isEqualToString:idfa];
                       if (!firstRun) {
                           if ([response[kAnalysisResponseKeyBrowser] intValue] ==
                               kBrowserConversionAlreadyDone) {
                               return;
                           }
                           if (storedVersion == [response[kAnalysisResponseKeyVersion] intValue]) {
                               return;
                           }
                       }

                       [self openWebBrowserWithSyncUrl];
                       [defaults setBool:YES forKey:kAnalysisDefaultsBrowserConversionFirstKey];
                       int responseVersion = [response[kAnalysisResponseKeyVersion] intValue];
                       if (responseVersion != 0) {
                           [defaults setInteger:responseVersion
                                         forKey:kAnalysisDefaultsBrowserConversionVersionKey];
                       }
                       if (idfa) {
                           [defaults setObject:idfa
                                        forKey:kAnalysisDefaultsBrowserConversionIdfaKey];
                       }
                       [defaults synchronize];
                     }
                       failedBlock:^(id __attribute__((unused)) request,
                                     NSError *__attribute__((unused)) error){
                           /** @ghidraAddress 0x23ac9c */
                           // A global empty block; the transport failure is discarded.
                       }];
}

+ (void)openWebBrowserWithSyncUrl {
    NSString *adUdid = [ApplilinkCore ad_udid];
    NSString *idfa = [ApplilinkUdid isAdvertisingTrackingOSVersion] ? [ApplilinkUdid getAdUdid] :
                                                                      [ApplilinkUdid getCFUUID];
    NSMutableDictionary *baseParameters = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *parameters = (NSMutableDictionary *)[ApplilinkUtilities
        userAgentParametersJoinDictionary:baseParameters];
    if (adUdid) {
        parameters[kAnalysisParamUdid] = adUdid;
    }
    if (idfa) {
        parameters[kAnalysisParamIdfa] = idfa;
    }

    NSString *requestUrl =
        [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kAnalysisPathGetSyncUrl];
    [ApplilinkWebAPI requestAsynchronousWithURL:requestUrl
                                         method:kHTTPMethodGet
                                     parameters:parameters
                                       userInfo:nil
                                            tag:0
                                    cachePolicy:nil
                                        timeout:kAnalysisRequestTimeout
                                          retry:NO
                                  finishedBlock:^(id request, id result) {
                                    /** @ghidraAddress 0x23aee0 */
                                    (void)request;
                                    NSDictionary *response = (NSDictionary *)result;
                                    if (AnalysisResponseIsSuccess(response)) {
                                        NSURL *openUrl =
                                            [NSURL URLWithString:response[kAnalysisResponseKeyUrl]];
                                        [[UIApplication sharedApplication] openURL:openUrl];
                                    }
                                  }
                                    failedBlock:^(id __attribute__((unused)) request,
                                                  NSError *__attribute__((unused)) error){
                                        /** @ghidraAddress 0x23b048 */
                                        // A global empty block; the transport failure is discarded.
                                    }];
}

+ (void)openWebBrowserWithAppliIdCore:(NSString *)appliId
                                  env:(NSString *)env
                             callback:(ApplilinkAnalysisCallback)callback {
    if (![ApplilinkUdid isAdvertisingTrackingEnabled]) {
        // The disabled-tracking path signals nil, not an error, unlike the other posters.
        callback(nil);
        return;
    }

    NSMutableDictionary *baseParameters = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *parameters = (NSMutableDictionary *)[ApplilinkUtilities
        userAgentParametersJoinDictionary:baseParameters];
    if (appliId == nil) {
        // The binary neither sends the request nor invokes the callback when the appli id is nil.
        return;
    }
    parameters[kAnalysisParamUaAppliId] = appliId;
    [[NSUserDefaults standardUserDefaults] setObject:env forKey:kAnalysisDefaultsEnvKey];

    NSString *adUdid = [ApplilinkCore ad_udid];
    NSString *idfa = [ApplilinkUdid isAdvertisingTrackingOSVersion] ? [ApplilinkUdid getAdUdid] :
                                                                      [ApplilinkUdid getCFUUID];
    if (adUdid) {
        parameters[kAnalysisParamUdid] = adUdid;
    }
    if (idfa) {
        parameters[kAnalysisParamIdfa] = idfa;
    }

    NSString *requestUrl =
        [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kAnalysisPathGetSyncUrl];
    [ApplilinkWebAPI requestAsynchronousWithURL:requestUrl
        method:kHTTPMethodGet
        parameters:parameters
        userInfo:nil
        tag:0
        cachePolicy:nil
        timeout:kAnalysisRequestTimeout
        retry:NO
        finishedBlock:^(id request, id result) {
          /** @ghidraAddress 0x23b3dc */
          (void)request;
          NSDictionary *response = (NSDictionary *)result;
          if (AnalysisResponseIsSuccess(response)) {
              // The callback here carries the server's URL string rather than an error.
              callback(response[kAnalysisResponseKeyUrl]);
              return;
          }
          callback(nil);
        }
        failedBlock:^(id request, NSError *error) {
          /** @ghidraAddress 0x23b518 */
          (void)request;
          (void)error;
          // No error is constructed; the URL-carrying callback signals failure with nil.
          callback(nil);
        }];
}

#pragma mark - Advert impression, click, and movie registration

+ (void)postAnalysisListRegistWithAdType:(NSString *)adType
                                 adModel:(NSString *)adModel
                              adLocation:(NSString *)adLocation
                            impressionId:(NSString *)impressionId
                             appliIdList:(NSArray *)appliIdList
                          creativeIdList:(NSArray *)creativeIdList
                       incentiveTypeList:(NSArray *)incentiveTypeList
                          installFlgList:(NSArray *)installFlgList
                                callback:(ApplilinkAnalysisCallback)callback {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:9];
    if (adLocation == nil) {
        callback([ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kApplilinkErrorMissingParameter]);
        return;
    }
    parameters[kAnalysisParamAdLocation] = adLocation;

    if (impressionId == nil) {
        callback([ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kApplilinkErrorMissingParameter]);
        return;
    }
    parameters[kAnalysisParamImpressionId] = impressionId;
    parameters[kAnalysisParamSystem] = kAnalysisSystemValueAd;
    if (adType) {
        parameters[kAnalysisParamAdType] = adType;
    }
    if (adModel) {
        parameters[kAnalysisParamAdModel] = adModel;
    }

    if (appliIdList.count != 0 && creativeIdList.count != 0 && incentiveTypeList.count != 0 &&
        installFlgList.count != 0) {
        parameters[kAnalysisParamAppliIdToList] = appliIdList;
        parameters[kAnalysisParamCreativeIdList] = creativeIdList;
        parameters[kAnalysisParamIncentiveTypeList] = incentiveTypeList;
        parameters[kAnalysisParamInstallFlgList] = installFlgList;
    }

    NSString *url = [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kAnalysisPathListRegist];
    [ApplilinkWebAPI requestAsynchronousWithURL:url
        method:kHTTPMethodPost
        parameters:parameters
        userInfo:nil
        tag:0
        cachePolicy:nil
        timeout:kAnalysisRequestTimeout
        retry:NO
        finishedBlock:^(id request, id result) {
          /** @ghidraAddress 0x23b9b0 */
          (void)request;
          NSDictionary *response = (NSDictionary *)result;
          if (AnalysisResponseIsSuccess(response)) {
              callback(nil);
              return;
          }
          callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:kApplilinkErrorGeneric
                                                                 userInfo:response]);
        }
        failedBlock:^(id request, NSError *error) {
          /** @ghidraAddress 0x23baf8 */
          (void)request;
          (void)error;
          callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:kApplilinkErrorGeneric]);
        }];
}

+ (void)postAnalysisClickRegistWithAdType:(NSString *)adType
                                  adModel:(NSString *)adModel
                               adLocation:(NSString *)adLocation
                             impressionId:(NSString *)impressionId
                                appliIdTo:(NSString *)appliIdTo
                               creativeId:(NSString *)creativeId
                            displayNumber:(NSString *)displayNumber
                            incentiveType:(NSString *)incentiveType
                               installFlg:(NSString *)installFlg
                                 callback:(ApplilinkAnalysisCallback)callback {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:9];
    NSError *error;
    if (adLocation == nil) {
        error =
            [ApplilinkNetworkError localizedApplilinkErrorWithCode:kApplilinkErrorMissingParameter];
    } else {
        parameters[kAnalysisParamAdLocation] = adLocation;
        if (impressionId == nil) {
            error = [ApplilinkNetworkError
                localizedApplilinkErrorWithCode:kApplilinkErrorMissingParameter];
        } else {
            parameters[kAnalysisParamImpressionId] = impressionId;
            if (appliIdTo == nil) {
                error = [ApplilinkNetworkError
                    localizedApplilinkErrorWithCode:kApplilinkErrorMissingParameter];
            } else {
                parameters[kAnalysisParamAppliIdTo] = appliIdTo;
                if (creativeId == nil) {
                    error = [ApplilinkNetworkError
                        localizedApplilinkErrorWithCode:kApplilinkErrorMissingParameter];
                } else {
                    parameters[kAnalysisParamCreativeId] = creativeId;
                    if (displayNumber == nil) {
                        error = [ApplilinkNetworkError
                            localizedApplilinkErrorWithCode:kApplilinkErrorMissingParameter];
                    } else {
                        parameters[kAnalysisParamDisplayNumber] = displayNumber;
                        if (incentiveType == nil) {
                            error = [ApplilinkNetworkError
                                localizedApplilinkErrorWithCode:kApplilinkErrorMissingParameter];
                        } else {
                            parameters[kAnalysisParamIncentiveType] = incentiveType;
                            if (installFlg == nil) {
                                error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:
                                                                   kApplilinkErrorMissingParameter];
                            } else {
                                parameters[kAnalysisParamInstallFlg] = installFlg;
                                parameters[kAnalysisParamSystem] = kAnalysisSystemValueAd;
                                if (adType) {
                                    parameters[kAnalysisParamAdType] = adType;
                                }
                                if (adModel) {
                                    parameters[kAnalysisParamAdModel] = adModel;
                                }

                                NSString *url = [[ApplilinkConsts baseUrlSsl]
                                    stringByAppendingString:kAnalysisPathClickRegist];
                                [ApplilinkWebAPI requestAsynchronousWithURL:url
                                    method:kHTTPMethodPost
                                    parameters:parameters
                                    userInfo:nil
                                    tag:0
                                    cachePolicy:nil
                                    timeout:kAnalysisRequestTimeout
                                    retry:NO
                                    finishedBlock:^(id request, id result) {
                                      /** @ghidraAddress 0x23c064 */
                                      (void)request;
                                      NSDictionary *response = (NSDictionary *)result;
                                      if (AnalysisResponseIsSuccess(response)) {
                                          callback(nil);
                                          return;
                                      }
                                      callback([ApplilinkNetworkError
                                          localizedApplilinkErrorWithCode:kApplilinkErrorGeneric
                                                                 userInfo:response]);
                                    }
                                    failedBlock:^(id request, NSError *failure) {
                                      /** @ghidraAddress 0x23c1ac */
                                      (void)request;
                                      (void)failure;
                                      callback([ApplilinkNetworkError
                                          localizedApplilinkErrorWithCode:kApplilinkErrorGeneric]);
                                    }];
                                return;
                            }
                        }
                    }
                }
            }
        }
    }
    callback(error);
}

+ (void)postAnalysisClickMovieWithAdType:(NSString *)adType
                                 adModel:(NSString *)adModel
                              adLocation:(NSString *)adLocation
                            impressionId:(NSString *)impressionId
                               appliIdTo:(NSString *)appliIdTo
                              creativeId:(NSString *)creativeId
                           displayNumber:(NSString *)displayNumber
                           incentiveType:(NSString *)incentiveType
                              installFlg:(NSString *)installFlg
                             movieStatus:(int)movieStatus
                                callback:(ApplilinkAnalysisCallback)callback {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:9];
    NSError *error;
    if (adLocation == nil) {
        error =
            [ApplilinkNetworkError localizedApplilinkErrorWithCode:kApplilinkErrorMissingParameter];
    } else {
        parameters[kAnalysisParamAdLocation] = adLocation;
        if (impressionId == nil) {
            error = [ApplilinkNetworkError
                localizedApplilinkErrorWithCode:kApplilinkErrorMissingParameter];
        } else {
            parameters[kAnalysisParamImpressionId] = impressionId;
            if (appliIdTo == nil) {
                error = [ApplilinkNetworkError
                    localizedApplilinkErrorWithCode:kApplilinkErrorMissingParameter];
            } else {
                parameters[kAnalysisParamAppliIdTo] = appliIdTo;
                if (creativeId == nil) {
                    error = [ApplilinkNetworkError
                        localizedApplilinkErrorWithCode:kApplilinkErrorMissingParameter];
                } else {
                    parameters[kAnalysisParamCreativeId] = creativeId;
                    if (displayNumber == nil) {
                        error = [ApplilinkNetworkError
                            localizedApplilinkErrorWithCode:kApplilinkErrorMissingParameter];
                    } else {
                        parameters[kAnalysisParamDisplayNumber] = displayNumber;
                        if (incentiveType == nil) {
                            error = [ApplilinkNetworkError
                                localizedApplilinkErrorWithCode:kApplilinkErrorMissingParameter];
                        } else {
                            parameters[kAnalysisParamIncentiveType] = incentiveType;
                            if (installFlg == nil) {
                                error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:
                                                                   kApplilinkErrorMissingParameter];
                            } else {
                                parameters[kAnalysisParamInstallFlg] = installFlg;
                                parameters[kAnalysisParamSystem] = kAnalysisSystemValueAd;
                                if (adType) {
                                    parameters[kAnalysisParamAdType] = adType;
                                }
                                if (adModel) {
                                    parameters[kAnalysisParamAdModel] = adModel;
                                }
                                parameters[kAnalysisParamStatus] =
                                    [NSString stringWithFormat:@"%d", movieStatus];

                                NSString *url = [[ApplilinkConsts baseUrlSsl]
                                    stringByAppendingString:kAnalysisPathMovieRegist];
                                [ApplilinkWebAPI requestAsynchronousWithURL:url
                                    method:kHTTPMethodPost
                                    parameters:parameters
                                    userInfo:nil
                                    tag:0
                                    cachePolicy:nil
                                    timeout:kAnalysisRequestTimeout
                                    retry:NO
                                    finishedBlock:^(id request, id result) {
                                      /** @ghidraAddress 0x23c75c */
                                      (void)request;
                                      NSDictionary *response = (NSDictionary *)result;
                                      if (AnalysisResponseIsSuccess(response)) {
                                          callback(nil);
                                          return;
                                      }
                                      callback([ApplilinkNetworkError
                                          localizedApplilinkErrorWithCode:kApplilinkErrorGeneric
                                                                 userInfo:response]);
                                    }
                                    failedBlock:^(id request, NSError *failure) {
                                      /** @ghidraAddress 0x23c8a4 */
                                      (void)request;
                                      (void)failure;
                                      callback([ApplilinkNetworkError
                                          localizedApplilinkErrorWithCode:kApplilinkErrorGeneric]);
                                    }];
                                return;
                            }
                        }
                    }
                }
            }
        }
    }
    callback(error);
}

#pragma mark - Persistence flags

+ (BOOL)getInitalizeFlg {
    return
        [[NSUserDefaults standardUserDefaults] objectForKey:kAnalysisDefaultsInitalizeKey] != nil;
}

+ (BOOL)getSendDauFlg {
    NSDate *persisted =
        [[NSUserDefaults standardUserDefaults] objectForKey:kAnalysisDefaultsDauDateKey];
    NSDate *now = [NSDate date];
    if (persisted) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateStyle = NSDateFormatterMediumStyle;
        formatter.timeStyle = NSDateFormatterNoStyle;
        NSString *persistedDay = [formatter stringFromDate:persisted];
        NSString *nowDay = [formatter stringFromDate:now];
        // Comparing the two formatted day strings collapses any difference within the same day.
        if ([persistedDay compare:nowDay] != NSOrderedAscending) {
            return YES;
        }
    }
    return NO;
}

+ (void)clearInitalize {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kAnalysisDefaultsInitalizeKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (void)clearDAU {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kAnalysisDefaultsDauDateKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end
