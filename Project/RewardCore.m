//
//  RewardCore.m
//  jubeat plus
//
//  Reconstructed from Ghidra program Jubeat.
//  See RewardCore.h for the class overview.
//

#import "RewardCore.h"

#import "ApplilinkConsts.h"
#import "ApplilinkCore.h"
#import "ApplilinkNetworkError.h"
#import "ApplilinkParameters.h"
#import "ApplilinkPasteBoard.h"
#import "ApplilinkUdid.h"
#import "ApplilinkUtilities.h"
#import "ApplilinkViewManager.h"
#import "NSStringURLEncoding.h"
#import "RewardWebAPI.h"

// RewardWebViewController hosts the reward advert web view. Its reconstructed header does not
// declare -willAnimateRotationToInterfaceOrientation:duration:, so the selectors this file messages
// are forward-declared here. See TYPES_PENDING.md.
@interface RewardWebViewController : UIViewController
- (void)setParentView:(UIView *)parentView;
- (void)setNavigationBarHidden:(BOOL)hidden;
- (void)setSdkDelegate:(id)delegate;
- (void)loadRequestWithURL:(NSString *)url parameters:(NSDictionary *)parameters;
- (void)appliListClosed;
- (void)viewDealloc;
- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)orientation
                                         duration:(NSTimeInterval)duration;
@end

// Applilink error codes used by the reward core.
enum {
    kRewardErrorApplicationIdMissing = 0x3e9,   // No Applilink application identifier is set.
    kRewardErrorNotInitialized = 0x3f2,         // The reward session has not initialised.
    kRewardErrorBannerCacheUnavailable = 0x402, // No cached banner status is available.
    kRewardErrorTrackingDisabled = 0x404,       // Advertising tracking is disabled.
    kRewardErrorNotAuthenticated = 0x406,       // The reward session is not authenticated.
    kRewardErrorAlreadyOpen = 0x40f,            // An advert screen is already open.
};

// Reward app-list request types passed to RewardWebAPI.
enum {
    kRewardListTypeAllAppIds = 1,     // Request every advertised application identifier.
    kRewardListTypeInstalledPost = 2, // Request the install-post application list.
};

// Application-install POST priorities passed to RewardWebAPI.
enum {
    kRewardInstallPriorityNormal = 0,     // Normal application-install post.
    kRewardLoginPriorityInteractive = 1,  // Interactive reward login.
    kRewardInstallPriorityPasteBoard = 2, // Pasteboard-sourced UDID install post.
};

// Result codes returned by -redirectWithRequest:.
enum {
    kRedirectResultOpened = 0,     // A path-segment URL was opened.
    kRedirectResultNotHandled = 1, // Not an Applilink redirect, no route, or an unresolved route.
    kRedirectResultConsumed = 3,   // A default_scheme URL was opened.
    kRedirectResultStoreShown = 4, // An app-store redirect was shown.
    kRedirectResultCloseRoute = 7, // A recognised "close" route.
};

// The campaignFlg sentinel returned when no valid flag is available.
static const int kRewardCampaignFlgNone = -2;

// The reward authentication session lifetime, in seconds (Ghidra: DAT_10028f258).
static const NSTimeInterval kRewardAuthSessionLifetime = 60.0;

// The reward advert index page appended to the SSL base URL.
static NSString *const kRewardIndexPath = @"/reward/app/index.php";

// The Applilink external-app redirect scheme prefix, host, and port.
static NSString *const kApplilinkSchemePrefix = @"applilink";
static NSString *const kApplilinkExtAppHost = @"ext-app";
static NSString *const kApplilinkExtAppPrefix = @"applilink://ext-app:80";
static const int kApplilinkExtAppPort = 80;

// Redirect-query separators and the query-suffix format.
static NSString *const kQueryComponentSeparator = @"&";
static NSString *const kPathComponentSeparator = @"/";
static NSString *const kQuerySuffixFormat = @"?%@";

// Query-parameter name fragments parsed out of the redirect URL. The rangeOfString: probe uses the
// bare name; the substringFromIndex: skips the name plus its '=' (hence the "=" suffix constants).
static NSString *const kRedirectQueryDefaultScheme = @"default_scheme";
static NSString *const kRedirectQueryDefaultSchemeEquals = @"default_scheme=";
static NSString *const kRedirectQueryStoreId = @"store_id";
static NSString *const kRedirectQueryStoreIdEquals = @"store_id=";
static NSString *const kRedirectQueryClose = @"close";

// NSUserDefaults keys owned by the reward session.
static NSString *const kDefaultsCampaignFlg = @"ApplilinkReward.campaignFlg";
static NSString *const kDefaultsStorageIndex = @"ApplilinkReward.storageIndex";
static NSString *const kDefaultsAppliURL = @"ApplilinkReward.appliURL";
static NSString *const kDefaultsParameters = @"ApplilinkReward.parameters";
static NSString *const kDefaultsMethod = @"ApplilinkReward.method";

// Temporary-cache archive keys and response/request dictionary keys.
static NSString *const kCacheKeyValue = @"Value";
static NSString *const kCacheKeyExpire = @"Expire";
static NSString *const kResponseKeyStorageIndex = @"StorageIndex";
static NSString *const kStatusKeyAllInstallFlg = @"allInstallFlg";
static NSString *const kCacheKeyAppInstallFlg = @"appInstallFlg";
static NSString *const kStatusKeyBannerDisplayStatus = @"bannerDisplayStatus";
static NSString *const kResponseKeyList = @"list";
static NSString *const kResponseKeyInfo = @"info";
static NSString *const kResponseKeyStatus = @"status";
static NSString *const kResponseKeyExpire = @"expire";
static NSString *const kResponseKeyAppliInfo = @"appli_info";
static NSString *const kResponseKeyAppliId = @"appli_id";
static NSString *const kResponseKeyDefaultScheme = @"default_scheme";
static NSString *const kRequestKeyAdLocation = @"ad_location";
static NSString *const kRequestKeyAppliIdList = @"appli_id_list";

// URL-scheme separator used when normalising an install-probe scheme.
static NSString *const kSchemeSeparator = @"://";

// Whether reward-video playback starts automatically when relayed to the view manager.
static const BOOL kRewardVideoAutoPlay = NO;

// Reward-session shared state (Ghidra: DAT_100354240..DAT_100354278). The singleton owns no
// per-request state for these; they are file-scope in the binary, so they stay file-scope here.
static BOOL gRewardAdScreenOpen;        // Ghidra: DAT_100354240 — a request is in flight.
static BOOL gRewardAdScreenCancelled;   // Ghidra: DAT_100354241 — the user cancelled the open.
static NSDate *gRewardAuthExpiry;       // Ghidra: DAT_100354268 — reward auth session expiry.
static NSDictionary *gRewardBannerInfo; // Ghidra: DAT_100354270 — cached banner info dictionary.
static NSDate *gRewardBannerExpiry;     // Ghidra: DAT_100354278 — cached banner info expiry.

// The singleton and its serial queue, allocated once through +allocWithZone: so that every
// allocation of a RewardCore yields the same object (Ghidra: DAT_100354248 singleton,
// DAT_100354250 queue).
static RewardCore *gRewardCoreInstance;
static dispatch_queue_t gRewardCoreQueue;

@implementation RewardCore

#pragma mark Singleton

// @ghidraAddress 0x23148c
+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      /** @ghidraAddress 0x2314d0 */
      gRewardCoreInstance = [[RewardCore alloc] init];
      gRewardCoreInstance.initializeFlg = 0;
    });
    return gRewardCoreInstance;
}

/**
 * @ghidraAddress 0x231374
 * @brief Routes every allocation through a single super-allocation so the class is a true
 * singleton, and creates the serial queue used to serialise its work.
 */
+ (instancetype)allocWithZone:(NSZone *)zone {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      /** @ghidraAddress 0x2313ec */
      gRewardCoreQueue = dispatch_queue_create("RewardCore", nil);
      if (gRewardCoreInstance == nil) {
          gRewardCoreInstance = [super allocWithZone:zone];
          gRewardCoreInstance.initializeFlg = 0;
      }
    });
    return gRewardCoreInstance;
}

/** @ghidraAddress 0x2311a4 */
- (instancetype)init {
    // The super-init runs synchronously on the serial queue, so every initialisation of the
    // singleton is serialised against its other work.
    __block RewardCore *result = nil;
    dispatch_sync(gRewardCoreQueue, ^{
      /** @ghidraAddress 0x2312b0 */
      result = [super init];
    });
    return result;
}

#pragma mark Properties

// @ghidraAddress 0x23153c. Advertising-tracking-gated override of the synthesised getter.
- (int)initializeFlg {
    if (![ApplilinkUdid isAdvertisingTrackingEnabled]) {
        return 0;
    }
    return _initializeFlg;
}

// The @c isNavigationBarHidden property setter shares its ivar with @c setNavigationBarHidden:.
// @ghidraAddress 0x235238.
- (void)setNavigationBarHidden:(BOOL)navigationBarHidden {
    _isNavigationBarHidden = navigationBarHidden;
}

#pragma mark Session lifecycle

// @ghidraAddress 0x231588.
- (void)clearInitialize {
    _initializeFlg = 0;
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kDefaultsCampaignFlg];
    [[NSUserDefaults standardUserDefaults] synchronize];
    gRewardAuthExpiry = nil;
}

// @ghidraAddress 0x23163c.
- (int)campaignFlg {
    if ([ApplilinkUdid isAdvertisingTrackingEnabled] &&
        [RewardCore sharedInstance].initializeFlg == 1) {
        NSString *stored =
            [[NSUserDefaults standardUserDefaults] stringForKey:kDefaultsCampaignFlg];
        if (stored) {
            return stored.intValue;
        }
    }
    return kRewardCampaignFlgNone;
}

// @ghidraAddress 0x231740.
- (void)startWithCallback:(void (^)(NSError *error))callback {
    if (![ApplilinkUdid isAdvertisingTrackingEnabled]) {
        callback(
            [ApplilinkNetworkError localizedApplilinkErrorWithCode:kRewardErrorTrackingDisabled]);
        return;
    }
    if (![ApplilinkConsts appliId]) {
        callback([ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kRewardErrorApplicationIdMissing]);
        return;
    }
    if (![ApplilinkCore checkUdid]) {
        [RewardCore sharedInstance].initializeFlg = 0;
    }
    if ([RewardCore sharedInstance].initializeFlg == 1) {
        callback(nil);
        return;
    }
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
      /** @ghidraAddress 0x231954 (Block_RewardCoreStartAfterUdid) */
      if ([self createUdidWithBlock:callback]) {
          [RewardWebAPI
              postApplicationInstallWithPriority:kRewardInstallPriorityNormal
                                        callback:^(NSError *error) {
                                          /** @ghidraAddress 0x231a58
                                           * (Block_RewardCoreFinishInstallPost) */
                                          if (error) {
                                              [RewardCore sharedInstance].initializeFlg = 0;
                                              callback(error);
                                              return;
                                          }
                                          if ([ApplilinkUdid isUdidSDKPasteBoard]) {
                                              // The shipped build passes an empty global block
                                              // here (Ghidra: Block_NoOpErrorHandlerH), not nil.
                                              [RewardWebAPI
                                                  postApplicationInstallWithPriority:
                                                      kRewardInstallPriorityPasteBoard
                                                                            callback:^(
                                                                                NSError
                                                                                    *__attribute__((
                                                                                        unused))
                                                                                    pasteBoardError){
                                                                                /** @ghidraAddress
                                                                                   0x231b70 */
                                                                            }];
                                          }
                                          [RewardCore sharedInstance].initializeFlg = 1;
                                          callback(nil);
                                        }];
      } else {
          [RewardCore sharedInstance].initializeFlg = 0;
          if (callback) {
              callback(nil);
          }
      }
    });
}

// @ghidraAddress 0x231be8.
- (void)startSessionWithBlock:(void (^)(NSError *error))block {
    if (![ApplilinkUdid isAdvertisingTrackingEnabled]) {
        block([ApplilinkNetworkError localizedApplilinkErrorWithCode:kRewardErrorTrackingDisabled]);
        return;
    }
    // The login-needed query runs before the expiry test rather than being short-circuited by it,
    // so it is read into a local to preserve that ordering.
    BOOL needRewardLogin = [ApplilinkConsts isNeedRewardLogin];
    if (gRewardAuthExpiry != nil && !needRewardLogin &&
        gRewardAuthExpiry.timeIntervalSinceNow >= 0.0) {
        block(nil);
        return;
    }
    [RewardWebAPI checkLoginWithBlock:^(BOOL valid, NSError *__attribute__((unused)) error) {
      /** @ghidraAddress 0x231d38 (Block_RewardCoreStartSessionAfterInit) */
      if (valid) {
          gRewardAuthExpiry = [[NSDate date] dateByAddingTimeInterval:kRewardAuthSessionLifetime];
          block(nil);
          return;
      }
      NSString *userId = [ApplilinkConsts userId];
      if (!userId) {
          if (block) {
              block([ApplilinkNetworkError
                  localizedApplilinkErrorWithCode:kRewardErrorNotAuthenticated]);
          }
          return;
      }
      [ApplilinkCore appAuthSessionRegenerateWithBlock:^(NSError *regenError) {
        /** @ghidraAddress 0x231ee0 (Block_RewardCoreLoginAfterAuthRegenerate) */
        (void)regenError; // The regenerate error is not consumed here; login reports its own.
        // The user identifier is captured by the enclosing block rather than fetched again.
        [RewardWebAPI startLoginWithUserId:userId
                              withPriority:kRewardLoginPriorityInteractive
                                  callback:^(NSError *loginError) {
                                    /** @ghidraAddress 0x231f6c
                                     * (Block_RewardCoreFinishRewardLogin) */
                                    if (loginError) {
                                        [ApplilinkUtilities debugLog];
                                        block(loginError);
                                        return;
                                    }
                                    [ApplilinkUdid setUdidKeychainFromPasteBoard];
                                    [ApplilinkConsts loggedInReward];
                                    gRewardAuthExpiry = [[NSDate date]
                                        dateByAddingTimeInterval:kRewardAuthSessionLifetime];
                                    block(nil);
                                  }];
      }];
    }];
}

// @ghidraAddress 0x232100.
- (void)startWithBlock:(void (^)(NSError *error))block {
    [self startWithCallback:^(NSError *error) {
      /** @ghidraAddress 0x232198 (Block_RewardCoreChainSessionAfterStart) */
      if (error) {
          block(error);
          return;
      }
      [self startSessionWithBlock:block];
    }];
}

// @ghidraAddress 0x232214.
- (BOOL)createUdidWithBlock:(void (^)(NSError *error))block {
    NSError *error = nil;
    if (![self createCFUdidWithError:&error] || error != nil) {
        block(error);
        return NO;
    }
    (void)[ApplilinkCore udid]; // Read for effect, matching the binary.
    NSError *rewardError = nil;
    [ApplilinkUdid createAdvertisingRewardUdidWithError:&rewardError];
    if (rewardError != nil) {
        block(rewardError);
        return NO;
    }
    (void)[ApplilinkCore ad_udid]; // Read for effect, matching the binary.
    if ([ApplilinkUdid isPasteBoardStatus]) {
        NSString *currentUdid = [ApplilinkCore currentUdid];
        if (currentUdid) {
            [ApplilinkUdid writeUDIDForFirstEmptyLocationWithUdid:currentUdid];
        }
    }
    return YES;
}

// @ghidraAddress 0x2323bc.
- (BOOL)createCFUdidWithError:(NSError **)error {
    if ([ApplilinkCore udid] != nil && [ApplilinkCore old_udid] == nil) {
        [ApplilinkUdid setUdidKeychainFromPasteBoard];
    }
    if ([ApplilinkUdid isAdvertisingTrackingOSVersion]) {
        return YES;
    }
    NSString *storedIndex =
        [[NSUserDefaults standardUserDefaults] stringForKey:kDefaultsStorageIndex];
    NSString *serviceName = [[[ApplilinkPasteBoard alloc] init] getServiceName];
    if (storedIndex != nil) {
        if ([ApplilinkUdid udidWithServiceName:serviceName
                                  storageIndex:storedIndex.intValue
                                         error:nil] != nil) {
            return YES;
        }
    }
    NSDictionary *written = [ApplilinkUdid writeUDIDForFirstEmptyLocationWithError:error];
    if (written == nil) {
        return NO;
    }
    NSString *index = [written[kResponseKeyStorageIndex] stringValue];
    [[NSUserDefaults standardUserDefaults] setValue:index forKey:kDefaultsStorageIndex];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kDefaultsCampaignFlg];
    [[NSUserDefaults standardUserDefaults] synchronize];
    return YES;
}

#pragma mark Status queries

// @ghidraAddress 0x2326cc.
- (void)allInstallFlgWithCallback:(void (^)(NSInteger flg, NSError *error))callback {
    id cached = [[RewardCore sharedInstance] getTemporaryCacheWithKey:kCacheKeyAppInstallFlg];
    if (cached != nil) {
        callback([cached intValue], nil);
        return;
    }
    if (![ApplilinkUdid isAdvertisingTrackingEnabled]) {
        callback(
            0,
            [ApplilinkNetworkError localizedApplilinkErrorWithCode:kRewardErrorTrackingDisabled]);
        return;
    }
    if ([RewardCore sharedInstance].initializeFlg == 0 && ![ApplilinkCore isInitializeStatusFlg]) {
        callback(
            0, [ApplilinkNetworkError localizedApplilinkErrorWithCode:kRewardErrorNotInitialized]);
        return;
    }
    [self startWithBlock:^(NSError *error) {
      /** @ghidraAddress 0x2328d0 (Block_RewardCoreFetchAllInstallFlg) */
      if (error) {
          callback(-1, error);
          return;
      }
      [RewardWebAPI allInstallFlgWithCallback:callback];
    }];
}

// @ghidraAddress 0x232924.
- (void)getAdDisplayStatusWithCallback:(void (^)(NSDictionary *status, NSError *error))callback {
    NSMutableDictionary *status = [NSMutableDictionary dictionaryWithCapacity:2];
    [status setValue:@(0) forKey:kStatusKeyAllInstallFlg];
    [status setValue:@(0) forKey:kStatusKeyBannerDisplayStatus];
    [self allInstallFlgWithCallback:^(NSInteger allInstallFlg, NSError *error) {
      /** @ghidraAddress 0x232ab8 (Block_RewardCoreFetchAppListStatus) */
      if (error) {
          callback(status, error);
          return;
      }
      [self getAppListStatusWithBlock:^(NSInteger bannerStatus, NSError *statusError) {
        /** @ghidraAddress 0x232b7c (Block_RewardCorePackAdDisplayStatus) */
        if (statusError) {
            callback(status, statusError);
            return;
        }
        [status setValue:@((int)allInstallFlg) forKey:kStatusKeyAllInstallFlg];
        [status setValue:@((int)bannerStatus) forKey:kStatusKeyBannerDisplayStatus];
        callback(status, nil);
      }];
    }];
}

// @ghidraAddress 0x232d2c.
- (void)postInstalledAppWithCallback:(void (^)(NSError *error))callback {
    [RewardWebAPI
        appliIdListWithType:kRewardListTypeInstalledPost
                   callback:^(NSDictionary *result, NSError *error) {
                     /** @ghidraAddress 0x232dc8
                      * (Block_RewardCoreReportInstalledApps) */
                     if (error) {
                         callback(error);
                         return;
                     }
                     if (![result isKindOfClass:[NSDictionary class]]) {
                         callback(nil);
                         return;
                     }
                     NSMutableArray *installed = [[NSMutableArray alloc] init];
                     for (NSDictionary *entry in result[kResponseKeyList]) {
                         NSDictionary *info = entry[kResponseKeyAppliInfo];
                         NSString *appliId = info[kResponseKeyAppliId];
                         NSString *scheme = info[kResponseKeyDefaultScheme];
                         if (scheme == nil || [scheme isKindOfClass:[NSNull class]]) {
                             continue;
                         }
                         if ([scheme rangeOfString:kSchemeSeparator].location == NSNotFound) {
                             scheme = [scheme stringByAppendingString:kSchemeSeparator];
                         }
                         NSURL *url = [NSURL URLWithString:scheme];
                         if ([[UIApplication sharedApplication] canOpenURL:url]) {
                             [installed addObject:appliId];
                         }
                     }
                     if (installed.count == 0) {
                         callback(nil);
                         return;
                     }
                     [RewardWebAPI postAppliInstallReportWithAppliList:installed callback:callback];
                   }];
}

// @ghidraAddress 0x23320c.
- (void)getInstalledAppWithCallback:(void (^)(NSArray *appIdList, NSError *error))callback {
    [RewardWebAPI appliIdListWithType:kRewardListTypeAllAppIds
                             callback:^(NSDictionary *result, NSError *error) {
                               /** @ghidraAddress 0x2332a8
                                * (Block_RewardCoreCollectAdvertisedAppIds) */
                               if (error) {
                                   callback(nil, error);
                                   return;
                               }
                               if (![result isKindOfClass:[NSDictionary class]]) {
                                   callback(nil, nil);
                                   return;
                               }
                               NSMutableArray *ids = [[NSMutableArray alloc] init];
                               for (NSDictionary *entry in result[kResponseKeyList]) {
                                   NSString *appliId =
                                       entry[kResponseKeyAppliInfo][kResponseKeyAppliId];
                                   if (appliId) {
                                       [ids addObject:appliId];
                                   }
                               }
                               callback(ids.count == 0 ? nil : ids, nil);
                             }];
}

// @ghidraAddress 0x233568.
- (void)getAppListStatusWithBlock:(void (^)(NSInteger status, NSError *error))block {
    if (![ApplilinkUdid isAdvertisingTrackingEnabled]) {
        block(0,
              [ApplilinkNetworkError localizedApplilinkErrorWithCode:kRewardErrorTrackingDisabled]);
        return;
    }
    NSError *error = nil;
    if (![ApplilinkConsts appliId]) {
        error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:kRewardErrorNotInitialized];
    } else if ([RewardCore sharedInstance].initializeFlg == 0 &&
               ![ApplilinkCore isInitializeStatusFlg]) {
        error = [ApplilinkNetworkError localizedApplilinkErrorWithCode:kRewardErrorNotInitialized];
    } else if (![self canUseBannerCache]) {
        error = [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:kRewardErrorBannerCacheUnavailable];
    } else if (gRewardBannerInfo == nil || gRewardBannerExpiry == nil ||
               gRewardBannerExpiry.timeIntervalSinceNow < 0.0) {
        [self startWithBlock:^(NSError *sessionError) {
          /** @ghidraAddress 0x233854 (Block_RewardCoreFetchBannerInfo) */
          if (sessionError) {
              block(0, sessionError);
              return;
          }
          [RewardWebAPI bannerInfoWithBlock:^(NSDictionary *result, NSError *bannerError) {
            /** @ghidraAddress 0x2338fc (Block_RewardCoreCacheBannerInfo) */
            if (bannerError || ![result isKindOfClass:[NSDictionary class]]) {
                block(0, bannerError);
                return;
            }
            gRewardBannerInfo = result[kResponseKeyInfo];
            NSInteger status = 0;
            if (gRewardBannerInfo != nil) {
                id expire = gRewardBannerInfo[kResponseKeyExpire];
                int expireSeconds = 0;
                if ([expire isKindOfClass:[NSString class]] ||
                    [expire isKindOfClass:[NSNumber class]]) {
                    expireSeconds = [expire intValue];
                }
                gRewardBannerExpiry = [[NSDate date] dateByAddingTimeInterval:expireSeconds];
                id statusValue = gRewardBannerInfo[kResponseKeyStatus];
                if ([statusValue isKindOfClass:[NSString class]] ||
                    [statusValue isKindOfClass:[NSNumber class]]) {
                    status = [statusValue intValue];
                }
            }
            block(status, nil);
          }];
        }];
        return;
    } else {
        id statusValue = gRewardBannerInfo[kResponseKeyStatus];
        NSInteger status =
            [statusValue isKindOfClass:[NSString class]] ? [statusValue intValue] : 0;
        block(status, nil);
        return;
    }
    block(0, error);
}

#pragma mark Advert screen

// @ghidraAddress 0x233bc4.
- (void)openAdScreenWithParentView:(UIView *)parentView
                        adLocation:(NSString *)adLocation
                       requestCode:(id)requestCode
                          delegate:(id<ApplilinkViewDelegate>)delegate {
    if (gRewardAdScreenOpen) {
        ApplilinkParameters *params = [[ApplilinkParameters alloc] init];
        [params setRequestWithAdModel:0 adLocation:adLocation requestCode:requestCode];
        [ApplilinkCore
            toDelegateFailOpenWithError:[ApplilinkNetworkError
                                            localizedApplilinkErrorWithCode:kRewardErrorAlreadyOpen]
                               appParam:params
                               delegate:delegate];
        return;
    }
    gRewardAdScreenOpen = YES;
    if (self.applilinkParams == nil) {
        self.applilinkParams = [[ApplilinkParameters alloc] init];
    }
    [self.applilinkParams setRequestWithAdModel:0 adLocation:adLocation requestCode:requestCode];
    gRewardAdScreenCancelled = NO;
    __weak id<ApplilinkViewDelegate> weakDelegate = delegate;
    [self startWithBlock:^(NSError *error) {
      /** @ghidraAddress 0x233e8c (Block_RewardCoreAdScreenPostInstalledApps) */
      if (error) {
          [self appListFailLoadWithError:error delegate:weakDelegate];
          gRewardAdScreenOpen = NO;
          return;
      }
      if (gRewardAdScreenCancelled) {
          gRewardAdScreenCancelled = NO;
          gRewardAdScreenOpen = NO;
          return;
      }
      [self postInstalledAppWithCallback:^(NSError *postError) {
        /** @ghidraAddress 0x234018 (Block_RewardCoreAdScreenGetAppIdList) */
        if (postError) {
            [self appListFailLoadWithError:postError delegate:weakDelegate];
            gRewardAdScreenOpen = NO;
            return;
        }
        if (gRewardAdScreenCancelled) {
            gRewardAdScreenCancelled = NO;
            gRewardAdScreenOpen = NO;
            return;
        }
        [self getInstalledAppWithCallback:^(NSArray *appIdList, NSError *getError) {
          /** @ghidraAddress 0x2341a4 (Block_RewardCoreAdScreenBuildParams) */
          if (getError) {
              [self appListFailLoadWithError:getError delegate:weakDelegate];
              gRewardAdScreenOpen = NO;
              return;
          }
          if (gRewardAdScreenCancelled) {
              gRewardAdScreenCancelled = NO;
              gRewardAdScreenOpen = NO;
              return;
          }
          NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
          if (adLocation) {
              [params setValue:adLocation forKey:kRequestKeyAdLocation];
          }
          if (appIdList) {
              [params setValue:appIdList forKey:kRequestKeyAppliIdList];
          }
          dispatch_async(dispatch_get_main_queue(), ^{
            /** @ghidraAddress 0x23436c (Block_RewardCoreAdScreenPresent) */
            if (self.rewardViewController == nil) {
                self.rewardViewController = [[RewardWebViewController alloc] init];
            }
            if (parentView) {
                [self.rewardViewController setParentView:parentView];
                [self.rewardViewController setNavigationBarHidden:self.isNavigationBarHidden];
            } else {
                [self.rewardViewController setNavigationBarHidden:NO];
            }
            [self.rewardViewController setSdkDelegate:self];
            self.applilinkDelegate = weakDelegate;
            NSString *url = [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kRewardIndexPath];
            [self.rewardViewController loadRequestWithURL:url parameters:params];
            gRewardAdScreenOpen = NO;
          });
        }];
      }];
    }];
}

// @ghidraAddress 0x2346fc.
- (void)closeAdScreen {
    if (gRewardAdScreenCancelled) {
        return;
    }
    gRewardAdScreenCancelled = YES;
    if (self.rewardViewController != nil) {
        [self.rewardViewController appliListClosed];
        [self.rewardViewController viewDealloc];
        [self appListDidDisappear:self.applilinkDelegate];
    }
    self.rewardViewController = nil;
    gRewardAdScreenOpen = NO;
}

// @ghidraAddress 0x2347b4.
- (void)rotateAdScreenWithInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
                                      duration:(NSTimeInterval)duration {
    if (self.rewardViewController != nil) {
        [self.rewardViewController willAnimateRotationToInterfaceOrientation:interfaceOrientation
                                                                    duration:duration];
    }
}

// @ghidraAddress 0x2347d8.
- (void)showVideoViewWithQuery:(NSString *)query {
    if (self.rewardViewController != nil) {
        [[ApplilinkViewManager sharedInstance]
            showVideoViewWithUIView:self.rewardViewController.view
                   parentWindowFlag:YES
                              query:query
                           autoPlay:kRewardVideoAutoPlay
                    applilinkParams:self.applilinkParams
                           delegate:self.applilinkDelegate];
    }
}

// @ghidraAddress 0x2348e8.
- (int)redirectWithRequest:(NSURLRequest *)request {
    NSURL *url = request.URL;
    NSString *scheme = url.scheme;
    NSString *host = url.host;
    int port = url.port.intValue;
    NSString *query = url.query;
    if (scheme == nil || ![scheme hasPrefix:kApplilinkSchemePrefix] || host == nil ||
        ![host isEqualToString:kApplilinkExtAppHost] || port != kApplilinkExtAppPort) {
        return kRedirectResultNotHandled;
    }
    // Walk the query components. A default_scheme parameter whose decoded URL can be opened is the
    // only early exit; store_id is recorded for the app-store fall-back, and every other outcome
    // (including a default_scheme that cannot be opened) drops through to the path handling below.
    NSString *storeId = nil;
    if (query != nil) {
        for (NSString *component in [query componentsSeparatedByString:kQueryComponentSeparator]) {
            if ([component rangeOfString:kRedirectQueryDefaultScheme].location != NSNotFound) {
                NSString *value = [NSStringURLEncoding
                    URLDecodedString:[component substringFromIndex:kRedirectQueryDefaultSchemeEquals
                                                                       .length]];
                NSURL *schemeURL = [NSURL URLWithString:value];
                if (schemeURL != nil && [[UIApplication sharedApplication] canOpenURL:schemeURL]) {
                    [[UIApplication sharedApplication] openURL:schemeURL];
                    return kRedirectResultConsumed;
                }
                break;
            }
            if ([component rangeOfString:kRedirectQueryStoreId].location != NSNotFound) {
                storeId = [NSStringURLEncoding
                    URLDecodedString:[component
                                         substringFromIndex:kRedirectQueryStoreIdEquals.length]];
            }
        }
    }
    // The binary builds the prefix with -stringWithFormat: over a specifier-free literal, so it is
    // just the constant string.
    NSString *prefix = [NSString stringWithFormat:kApplilinkExtAppPrefix];
    NSString *path = nil;
    if ([url.absoluteString hasPrefix:prefix]) {
        path = [url.absoluteString substringFromIndex:prefix.length];
        if (query.length) {
            NSString *suffix = [NSString stringWithFormat:kQuerySuffixFormat, query];
            if ([path hasSuffix:suffix]) {
                path = [path substringToIndex:(path.length - suffix.length)];
            }
        }
    }
    if (path.length == 0) {
        return kRedirectResultNotHandled;
    }
    NSArray *segments =
        [[path substringFromIndex:1] componentsSeparatedByString:kPathComponentSeparator];
    if (segments.count == 0) {
        return kRedirectResultNotHandled;
    }
    // RewardCore is handed to the store view as its delegate even though it implements none of the
    // all-optional SdkViewDelegate methods; the binary passes the raw self pointer here.
    if ([ApplilinkCore showAppStoreId:storeId appParam:nil delegate:(id<SdkViewDelegate>)self]) {
        return kRedirectResultStoreShown;
    }
    NSString *first = [NSStringURLEncoding URLDecodedString:segments[0]];
    NSURL *firstURL = [NSURL URLWithString:first];
    if (firstURL != nil && [[UIApplication sharedApplication] canOpenURL:firstURL]) {
        [[UIApplication sharedApplication] openURL:firstURL];
        return kRedirectResultOpened;
    }
    // A recognised "close" route yields the close code; any other unresolved route is not handled.
    return [first isEqualToString:kRedirectQueryClose] ? kRedirectResultCloseRoute :
                                                         kRedirectResultNotHandled;
}

#pragma mark Temporary cache

// @ghidraAddress 0x235248.
- (void)setTemporaryCacheWithKey:(NSString *)key value:(id)value expiration:(NSInteger)expiration {
    NSDate *expiry =
        [[NSDate alloc] initWithTimeIntervalSinceNow:(expiration == 0 ? 1.0 : (double)expiration)];
    NSDictionary *entry = [NSDictionary
        dictionaryWithObjectsAndKeys:value, kCacheKeyValue, expiry, kCacheKeyExpire, nil];
    [[NSUserDefaults standardUserDefaults]
        setObject:[NSKeyedArchiver archivedDataWithRootObject:entry]
           forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

// @ghidraAddress 0x2353fc.
- (id)getTemporaryCacheWithKey:(NSString *)key {
    NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    if (data == nil) {
        return nil;
    }
    NSDictionary *entry = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    if (entry == nil) {
        return nil;
    }
    NSDate *expiry = entry[kCacheKeyExpire];
    if (expiry != nil && [expiry compare:[NSDate date]] == NSOrderedAscending) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
        [[NSUserDefaults standardUserDefaults] synchronize];
        return nil;
    }
    return entry[kCacheKeyValue];
}

#pragma mark Delegate notifications

// @ghidraAddress 0x2355f0.
- (void)appListDidStart:(id<ApplilinkViewDelegate>)delegate {
    [ApplilinkCore toDelegateDidStart:self.applilinkParams delegate:delegate];
}

// @ghidraAddress 0x23561c.
- (void)appListDidAppear:(id<ApplilinkViewDelegate>)delegate {
    [ApplilinkCore toDelegateDidAppear:self.applilinkParams delegate:delegate];
}

// @ghidraAddress 0x235648.
- (void)appListDidDisappear:(id<ApplilinkViewDelegate>)delegate {
    [ApplilinkCore toDelegateDidDisappear:self.applilinkParams delegate:delegate];
}

// @ghidraAddress 0x235674.
- (void)appListFailLoadWithError:(NSError *)error delegate:(id<ApplilinkViewDelegate>)delegate {
    [ApplilinkCore toDelegateFailLoadWithError:error
                                      appParam:self.applilinkParams
                                      delegate:delegate];
}

// @ghidraAddress 0x2356d8.
- (void)appListFailLinkWithError:(NSError *)error delegate:(id<ApplilinkViewDelegate>)delegate {
    [ApplilinkCore toDelegateFailLinkWithError:error
                                      appParam:self.applilinkParams
                                      delegate:delegate];
}

#pragma mark Web-view notices

// @ghidraAddress 0x23573c.
- (void)startedNotice {
    [self appListDidStart:self.applilinkDelegate];
}

// @ghidraAddress 0x235788.
- (void)openedNotice {
    [self appListDidAppear:self.applilinkDelegate];
}

// @ghidraAddress 0x2357d4.
- (void)closeNotice {
    if (self.rewardViewController != nil) {
        gRewardAdScreenCancelled = YES;
        [self.rewardViewController viewDealloc];
        self.rewardViewController = nil;
    }
    gRewardAdScreenOpen = NO;
    [self appListDidDisappear:self.applilinkDelegate];
}

// @ghidraAddress 0x235868.
- (void)failOpenNoticeWithError:(NSError *)error {
    [self appListFailLoadWithError:error delegate:self.applilinkDelegate];
}

// @ghidraAddress 0x2358d8.
- (void)failLinkNoticeWithError:(NSError *)error {
    [self appListFailLinkWithError:error delegate:self.applilinkDelegate];
}

// @ghidraAddress 0x235948. The shipped build ignores the cancellation error.
- (void)openCancelWithError:(NSError *)error {
    (void)error; // Yes, the binary discards this argument.
}

#pragma mark Cache and session teardown

// @ghidraAddress 0x23594c.
- (BOOL)canUseBannerCache {
    NSString *udid = [ApplilinkCore udid];
    NSString *adUdid = [ApplilinkCore ad_udid];
    NSString *oldUdid = [ApplilinkCore old_udid];
    if (udid == nil && oldUdid == nil && adUdid == nil) {
        gRewardBannerInfo = nil;
        gRewardBannerExpiry = nil;
    }
    return udid != nil || oldUdid != nil || adUdid != nil;
}

// @ghidraAddress 0x235a28.
- (void)clearAdStatus {
    gRewardBannerInfo = nil;
    gRewardBannerExpiry = nil;
}

// @ghidraAddress 0x235a5c.
- (void)clearSession {
    NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *cookie in storage.cookies) {
        [storage deleteCookie:cookie];
    }
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kDefaultsAppliURL];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kDefaultsParameters];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kDefaultsMethod];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

// @ghidraAddress 0x235c90. The binary's -dealloc only chains to @c NSObject; under ARC that super
// call is implicit, so the body is empty.
- (void)dealloc {
}

@end
