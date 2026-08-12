#import "RecommendCore.h"

#import "AnalysisNetworkCore.h"
#import "ApplilinkConsts.h"
#import "ApplilinkCore.h"
#import "ApplilinkFile.h"
#import "ApplilinkNetworkError.h"
#import "ApplilinkParameters.h"
#import "ApplilinkURLConnection.h"
#import "ApplilinkUdid.h"
#import "ApplilinkUtilities.h"
#import "ApplilinkViewManager.h"
#import "NSStringURLEncoding.h"
#import "RecommendAdAreaView.h"
#import "RecommendAdCache.h"
#import "RecommendAdData.h"
#import "RecommendAdId.h"
#import "RecommendFullScreenController.h"
#import "RecommendWebAPI.h"
#import "RecommendWebView.h"
#import "RecommendWebViewController.h"
#import "RewardCore.h"

// Applilink error codes reported to callers and delegates.
typedef enum {
    RecommendCoreErrorCodeParameter = 1001,          // 0x3e9
    RecommendCoreErrorCodeNoAdData = 1034,           // 0x40a
    RecommendCoreErrorCodeNotInitialized = 1010,     // 0x3f2
    RecommendCoreErrorCodeCacheCreate = 1035,        // 0x40b
    RecommendCoreErrorCodeNoBannerData = 1037,       // 0x40d
    RecommendCoreErrorCodeAdTrackingDisabled = 1028, // 0x404
    RecommendCoreErrorCodeNoAppliId = 1029,          // 0x405
} RecommendCoreErrorCode;

// Advert-model identifiers whose banner opens the advert area directly (100, 101) or the
// interstitial (5) rather than gating on the installed-application list.
typedef enum {
    RecommendCoreAdModelInterstitial = 5,
    RecommendCoreAdModelOwnAdBase = 100,
    RecommendCoreAdModelDirectRangeLength = 2,
} RecommendCoreAdModel;

// Advert types passed to the analytics registration.
typedef enum {
    RecommendCoreAdTypeBanner = 2,
    RecommendCoreAdTypeIcon = 3,
    RecommendCoreAdTypeInterstitial = 5,
} RecommendCoreAdType;

// The advert-status value that marks an advert model as available.
static const int kRecommendCoreAdStatusAvailable = 1;

// The cached-banner-status value that marks an advert as available.
static const int kRecommendCoreBannerAvailable = 1;

// The Applilink deep-link scheme, host, and port that a redirect must match.
static NSString *const kRecommendCoreApplilinkScheme = @"applilink";
static NSString *const kRecommendCoreExtAppHost = @"ext-app";
static const int kRecommendCoreExtAppPort = 80;
static NSString *const kRecommendCoreApplilinkExtAppUrl = @"applilink://ext-app:80";
static NSString *const kRecommendCoreChangeDestSuffix = @"#changeDest";
static NSString *const kRecommendCoreCloseHost = @"close";
static NSString *const kRecommendCoreMovieHost = @"movie";

// The bare redirect query keys located with -rangeOfString: and the "key=" prefixes skipped past
// with -substringFromIndex:. The binary searches each component for the bare key and then trims the
// key plus its trailing "=", so both spellings are kept.
static NSString *const kRecommendCoreQueryKeyDefaultScheme = @"default_scheme";
static NSString *const kRecommendCoreQueryKeyAdIdFrom = @"ad_id_from";
static NSString *const kRecommendCoreQueryKeyCountryCode = @"country_code";
static NSString *const kRecommendCoreQueryKeyCategoryId = @"category_id";
static NSString *const kRecommendCoreQueryKeyAdType = @"ad_type";
static NSString *const kRecommendCoreQueryKeyStoreId = @"store_id";

static NSString *const kRecommendCoreQueryDefaultScheme = @"default_scheme=";
static NSString *const kRecommendCoreQueryAdIdFrom = @"ad_id_from=";
static NSString *const kRecommendCoreQueryCountryCode = @"country_code=";
static NSString *const kRecommendCoreQueryCategoryId = @"category_id=";
static NSString *const kRecommendCoreQueryAdType = @"ad_type=";
static NSString *const kRecommendCoreQueryStoreId = @"store_id=";

// Endpoints appended to the SSL base URL.
static NSString *const kRecommendCoreAdExternalIndexPath = @"/ad/external/index.php";
static NSString *const kRecommendCoreMovieEndPath = @"/ad/external/movie/end.php";

// NSUserDefaults keys owned by the recommend network.
static NSString *const kRecommendCorePostInstalledKey = @"ApplilinkRecommend.postInstalled";
static NSString *const kRecommendCoreBannerInfoKey = @"ApplilinkRecommend.bannerInfo";
static NSString *const kRecommendCoreUniqueAdDataKey = @"UniqueAdData";
static NSString *const kRecommendCoreAppliIdKey = @"ApplilinkNetwork.appliId";

// Advert-record, cache, and status dictionary keys.
static NSString *const kRecommendCoreKeyAdId = @"ad_id";
static NSString *const kRecommendCoreKeyAppliId = @"appli_id";
static NSString *const kRecommendCoreKeyDefaultScheme = @"default_scheme";
static NSString *const kRecommendCoreKeyIncentiveType = @"incentive_type";
static NSString *const kRecommendCoreKeyBannerUrl = @"banner_url";
static NSString *const kRecommendCoreKeyBannerIconUrl = @"banner_icon_url";
static NSString *const kRecommendCoreKeyInterstitialBannerUrl = @"interstitial_banner_url";
static NSString *const kRecommendCoreKeyPosterUrlRect = @"poster_url_rect";
static NSString *const kRecommendCoreKeyExpire = @"expire";
static NSString *const kRecommendCoreKeyStatus = @"status";
static NSString *const kRecommendCoreKeyUnreadCount = @"unreadCount";
static NSString *const kRecommendCoreKeyBannerDisplayStatus = @"bannerDisplayStatus";
static NSString *const kRecommendCoreKeyAdIdFrom = @"AdIdFrom";
static NSString *const kRecommendCoreKeyAdType = @"AdType";
static NSString *const kRecommendCoreKeyRewardNone = @"REWARD_NONE";

// Movie-end URL parameter keys.
static NSString *const kRecommendCoreMovieKeyAdIdFrom = @"ad_id_from";
static NSString *const kRecommendCoreMovieKeyAdIdTo = @"ad_id_to";
static NSString *const kRecommendCoreMovieKeyAdModel = @"ad_model";
static NSString *const kRecommendCoreMovieKeyAdLocation = @"ad_location";
static NSString *const kRecommendCoreMovieKeyImpressionId = @"impression_id";
static NSString *const kRecommendCoreMovieKeyCreativeId = @"creative_id";
static NSString *const kRecommendCoreMovieKeyDisplayNumber = @"display_number";
static NSString *const kRecommendCoreMovieKeyInstallFlg = @"install_flg";

// The install flag reported when the advert record carries none. +clearData compares the
// configured server environment against the same literal: the disabled environment is "0".
static NSString *const kRecommendCoreInstallFlgNone = @"0";
static NSString *const kRecommendCoreEnvServerDisabled = @"0";
static NSString *const kRecommendCoreDisplayNumberDefault = @"1";

// The request-parameter keys for the external advert index request.
static NSString *const kRecommendCoreParamIsSdk = @"is_sdk";
static NSString *const kRecommendCoreParamAdLocation = @"ad_location";
static NSString *const kRecommendCoreParamAdModel = @"ad_model";
static NSString *const kRecommendCoreParamVerticalAlign = @"vertical_align";
static NSString *const kRecommendCoreParamInstallAdIdList = @"install_ad_id_list";
static NSString *const kRecommendCoreParamValueOne = @"1";

// Format strings.
static NSString *const kRecommendCoreFormatInteger = @"%d";
static NSString *const kRecommendCoreFormatSchemeOnly = @"%@://";
static NSString *const kRecommendCoreFormatQuery = @"?%@";
static NSString *const kRecommendCoreFormatBannerDisplayStatus =
    @"banner_display_status_list ad_model:%d";
static NSString *const kRecommendCoreFormatAllAdDataMissing =
    @"allAdDataForDisplay fall in line with list by no appliId %@";

// The user-info key these diagnostic messages are filed under.
static NSString *const kErrorUserInfoKey = @"Error";

// The web-load error codes that are silently ignored when they come from WebKit.
static const NSInteger kRecommendCoreWebKitCancelledCode = -999;
static const NSInteger kRecommendCoreWebKitFrameLoadInterruptedCode = 102; // 0x66
static const NSInteger kRecommendCoreWebKitPlugInCancelledCode = 204;      // 0xcc
static NSString *const kRecommendCoreWebKitErrorDomain = @"WebKitErrorDomain";

// The query-component separator and the deep-link path separator.
static NSString *const kRecommendCoreQuerySeparator = @"&";
static NSString *const kRecommendCorePathSeparator = @"/";

// The recommend-login validity window, in seconds.
static const NSTimeInterval kRecommendCoreLoginValiditySeconds = 60.0;

// The install-post priority for the application-install registration.
static const int kRecommendCoreInstallPriority = 1;

// The redirect outcome codes returned to the advert-screen web view.
typedef enum {
    RecommendCoreRedirectOpenedUrl = 0,         // A plain destination URL was opened directly.
    RecommendCoreRedirectDefault = 1,           // Nothing matched; the web view loads the request.
    RecommendCoreRedirectChangeDest = 2,        // "#changeDest" reloaded the ad data and rewrote.
    RecommendCoreRedirectOpenedExternalApp = 3, // The advert's own scheme launched another app.
    RecommendCoreRedirectAppStore = 4,          // The App Store was shown for a store id.
    RecommendCoreRedirectMovie = 5,             // The "movie" host was requested.
    RecommendCoreRedirectClose = 7,             // The "close" host was requested.
} RecommendCoreRedirect;

// Whether an advert screen or advert view is currently open, guarding re-entry.
static BOOL g_fAdScreenOpenInProgress = NO;

// The absolute time until which the recommend login remains valid; nil forces a re-login.
static NSDate *g_pRecommendSessionExpiry = nil;

// The singleton and its serial queue, allocated once through +allocWithZone: so that every
// allocation of a RecommendCore yields the same object.
static RecommendCore *g_pRecommendCoreShared = nil;
static dispatch_queue_t g_hRecommendCoreQueue = nil;

@interface RecommendCore () <ApplilinkViewDelegate>
@end

// The block bodies below are de-inlined into file-private C functions rather than methods, because
// the shipped class metadata carries no selector for any of them.

// The installed-application-list completion for the ad-screen flow (Ghidra: 0x26b05c).
static void RecommendCoreLoadAdScreenRequest(RecommendCore *core,
                                             id appliList,
                                             NSError *error,
                                             id delegate,
                                             NSString *adLocation,
                                             int adModel,
                                             int verticalAlign);

// The session-gated impression-registration completion for -showOwnAd... (Ghidra: 0x26ecb0).
static void RecommendCorePostOwnAdImpression(RecommendCore *core,
                                             NSError *error,
                                             NSString *adLocation,
                                             NSString *toAppliId,
                                             NSString *creativeId,
                                             int adType,
                                             int adModel);

// The session-gated click-registration completion for -touchOwnAd... (Ghidra: 0x26f424).
static void RecommendCorePostOwnAdClickRegist(RecommendCore *core,
                                              NSError *error,
                                              NSString *adLocation,
                                              id requestCode,
                                              id delegate,
                                              NSString *toAppliId,
                                              NSString *creativeId,
                                              int adModel,
                                              int adType);

@implementation RecommendCore

#pragma mark - Singleton

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      /** @ghidraAddress 0x268e08 */
      [RecommendCore alloc];
    });
    return g_pRecommendCoreShared;
}

/**
 * @ghidraAddress 0x268cac
 * @brief Routes every allocation through a single super-allocation so the class is a true
 * singleton, and creates the serial queue used to serialise its work. Unlike its three
 * applilink-singleton twins, this one also resets initializeFlg to 0 on the freshly allocated
 * instance.
 */
+ (instancetype)allocWithZone:(NSZone *)zone {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      /** @ghidraAddress 0x268d24 */
      g_hRecommendCoreQueue = dispatch_queue_create("RecommendCore", nil);
      if (g_pRecommendCoreShared == nil) {
          g_pRecommendCoreShared = [super allocWithZone:zone];
          g_pRecommendCoreShared.initializeFlg = 0;
      }
    });
    return g_pRecommendCoreShared;
}

- (instancetype)init {
    // The super-init runs synchronously on the serial queue (dispatch_once body at 0x268bc4), so
    // every initialisation of the singleton is serialised against its other work.
    __block RecommendCore *result = nil;
    dispatch_sync(g_hRecommendCoreQueue, ^{
      /** @ghidraAddress 0x268be8 */
      result = [super init];
    });
    return result;
}

#pragma mark - Initialisation state

- (BOOL)isInitialized {
    return self.initializeFlg == kRecommendCoreAdStatusAvailable;
}

- (void)clearInitialize {
    self.initializeFlg = 0;
    g_pRecommendSessionExpiry = nil;
    [RecommendAdCache clearAllAdData];
    [RecommendAdCache clearAllAdDataInfoExpire];
    [ApplilinkFile delateFolder];
}

- (BOOL)isInstalledAppliWithScheme:(NSString *)scheme {
    NSURL *url =
        [NSURL URLWithString:[NSString stringWithFormat:kRecommendCoreFormatSchemeOnly, scheme]];
    return [[UIApplication sharedApplication] canOpenURL:url];
}

#pragma mark - Start and session

- (void)startWithCallback:(void (^)(NSError *error))callback {
    if ([ApplilinkConsts appliId] == nil) {
        // Unguarded in the binary: unlike the other exits, this one calls the block without a nil
        // test.
        callback([ApplilinkNetworkError
            localizedApplilinkErrorWithCode:RecommendCoreErrorCodeNoAppliId]);
        return;
    }
    if (![ApplilinkCore checkUdid]) {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kRecommendCorePostInstalledKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    if ([RecommendCore sharedInstance].initializeFlg == 0) {
        if (![[RewardCore sharedInstance] createUdidWithBlock:callback]) {
            [[NSUserDefaults standardUserDefaults] setBool:NO
                                                    forKey:kRecommendCorePostInstalledKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
            if (callback) {
                callback(nil);
            }
            return;
        }
    }
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
      /** @ghidraAddress 0x2692ec */
      // The recommend API invokes this block with (categoryId, countryCode, error); the binary
      // ignores the first two arguments here and re-reads them from ApplilinkConsts below, so they
      // are left unnamed.
      [RecommendWebAPI getAdDetailWithCallback:^(id, id, NSError *error) {
        /** @ghidraAddress 0x269384 */
        if (error != nil) {
            if (callback) {
                callback(error);
            }
            return;
        }
        self.initializeFlg = YES;
        if ([[NSUserDefaults standardUserDefaults] boolForKey:kRecommendCorePostInstalledKey]) {
            if (callback) {
                callback(nil);
            }
            return;
        }
        NSString *countryCode = [ApplilinkConsts countryCode];
        NSString *categoryId = [ApplilinkConsts categoryId];
        RecommendAdId *adId = [[RecommendAdId alloc] initWithCountryCode:countryCode
                                                              categoryId:categoryId];
        NSError *lookupError = nil;
        NSDictionary *record = [adId getWithCountryCode:countryCode
                                             categoryId:categoryId
                                                  error:&lookupError];
        NSString *adIdFrom = nil;
        NSString *adType = nil;
        if (lookupError == nil && record != nil) {
            adIdFrom = record[kRecommendCoreKeyAdIdFrom];
            if (![adIdFrom isKindOfClass:[NSString class]]) {
                adIdFrom = nil;
            }
            adType = record[kRecommendCoreKeyAdType];
            if (![adType isKindOfClass:[NSString class]]) {
                adType = nil;
            }
        }
        [RecommendWebAPI
            postApplicationInstallWithAdIdFrom:adIdFrom
                                    categoryId:categoryId
                                        adType:adType
                                      priority:kRecommendCoreInstallPriority
                                      callback:^(NSError *postError) {
                                        /** @ghidraAddress 0x269720 */
                                        if (postError != nil) {
                                            if (callback) {
                                                callback(postError);
                                            }
                                            return;
                                        }
                                        [adId deleteWithCountryCode:countryCode
                                                         categoryId:categoryId
                                                              error:nil];
                                        [[NSUserDefaults standardUserDefaults]
                                            setBool:YES
                                             forKey:kRecommendCorePostInstalledKey];
                                        [[NSUserDefaults standardUserDefaults] synchronize];
                                        if (callback) {
                                            callback(nil);
                                        }
                                      }];
      }];
    });
}

- (void)startSessionWithCallback:(void (^)(NSError *error))callback {
    // Unlike -startWithCallback:, nothing on this path nil-tests the block before invoking it.
    if (![ApplilinkUdid isAdvertisingTrackingEnabled]) {
        callback([ApplilinkNetworkError
            localizedApplilinkErrorWithCode:RecommendCoreErrorCodeAdTrackingDisabled]);
        return;
    }
    [ApplilinkCore appAuthSessionRegenerateWithBlock:^(NSError *error) {
      /** @ghidraAddress 0x269a38 */
      if (error != nil) {
          callback(error);
          return;
      }
      if (g_pRecommendSessionExpiry == nil || [ApplilinkConsts isNeedRecommendLogin] ||
          [g_pRecommendSessionExpiry timeIntervalSinceNow] < 0.0) {
          // The recommend API invokes this block with (loginStatus, userIdPresent, error); the
          // binary reads only the login status and the error, ignoring userIdPresent.
          [RecommendWebAPI checkLoginWithCallback:^(BOOL loggedIn,
                                                    BOOL __attribute__((unused)) userIdPresent,
                                                    NSError *checkError) {
            /** @ghidraAddress 0x269b34 */
            if (checkError != nil) {
                callback(checkError);
                return;
            }
            if (!loggedIn) {
                [RecommendWebAPI startLoginWithCallback:^(NSError *loginError) {
                  /** @ghidraAddress 0x269c68 */
                  if (loginError != nil) {
                      callback(loginError);
                      return;
                  }
                  [ApplilinkUdid setUdidKeychainFromPasteBoard];
                  [ApplilinkConsts loggedInRecommend];
                  g_pRecommendSessionExpiry =
                      [[NSDate date] dateByAddingTimeInterval:kRecommendCoreLoginValiditySeconds];
                  callback(nil);
                }];
                return;
            }
            g_pRecommendSessionExpiry =
                [[NSDate date] dateByAddingTimeInterval:kRecommendCoreLoginValiditySeconds];
            callback(nil);
          }];
          return;
      }
      callback(nil);
    }];
}

#pragma mark - Installed-application list

- (void)appliListWithCallBack:(void (^)(id list, NSError *error))callback {
    [self startSessionWithCallback:^(NSError *error) {
      /** @ghidraAddress 0x269e1c */
      if (error != nil) {
          callback(nil, error);
          return;
      }
      [self appliListCacheWithCallBack:callback];
    }];
}

- (void)appliListCacheWithCallBack:(void (^)(id list, NSError *error))callback {
    id list = [ApplilinkConsts appInstallList];
    if (list == nil) {
        [RecommendWebAPI installAppliListWithCallBack:callback];
        return;
    }
    callback(list, nil);
}

#pragma mark - Advert status queries

- (void)getAdStatusWithAdModel:(int)adModel
                      callback:(void (^)(NSInteger status, NSError *error))callback {
    NSError *error;
    if (adModel == 0) {
        error =
            [ApplilinkNetworkError localizedApplilinkErrorWithCode:RecommendCoreErrorCodeParameter];
    } else if ([RecommendCore sharedInstance].initializeFlg == 0 &&
               ![ApplilinkCore isInitializeStatusFlg]) {
        error = [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:RecommendCoreErrorCodeNotInitialized];
    } else if (![ApplilinkUdid isAdvertisingTrackingEnabled]) {
        error = [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:RecommendCoreErrorCodeAdTrackingDisabled];
    } else {
        NSNumber *cached = [self getTemporaryCacheWithAdModel:adModel];
        if ([cached intValue] == kRecommendCoreBannerAvailable) {
            callback([cached intValue], nil); // Yes, the binary sends -intValue a second time.
            return;
        }
        [self startSessionWithCallback:^(NSError *sessionError) {
          /** @ghidraAddress 0x26a160 */
          if (sessionError != nil) {
              callback(0, sessionError);
              return;
          }
          [RecommendWebAPI getBannerDetailWithAdModel:adModel callback:callback];
        }];
        return;
    }
    callback(0, error);
}

- (void)getUnreadCountWithAdModel:(int)adModel
                       adLocation:(NSString *)adLocation
                         callback:(void (^)(NSInteger status, NSError *error))callback {
    NSError *error;
    if (adLocation == nil || adModel == 0) {
        error =
            [ApplilinkNetworkError localizedApplilinkErrorWithCode:RecommendCoreErrorCodeParameter];
    } else if ([RecommendCore sharedInstance].initializeFlg == 0 &&
               ![ApplilinkCore isInitializeStatusFlg]) {
        error = [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:RecommendCoreErrorCodeNotInitialized];
    } else if (![ApplilinkUdid isAdvertisingTrackingEnabled]) {
        error = [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:RecommendCoreErrorCodeAdTrackingDisabled];
    } else {
        [self startSessionWithCallback:^(NSError *sessionError) {
          /** @ghidraAddress 0x26a39c */
          if (sessionError != nil) {
              callback(0, sessionError);
              return;
          }
          [RecommendWebAPI getUnreadCountWithAdModel:adModel
                                          adLocation:adLocation
                                            callback:callback];
        }];
        return;
    }
    callback(0, error);
}

- (void)getAdDisplayStatusWithAdModel:(int)adModel
                           adLocation:(NSString *)adLocation
                             callback:(void (^)(NSDictionary *status, NSError *error))callback {
    NSMutableDictionary *status = [NSMutableDictionary dictionaryWithCapacity:2];
    [status setValue:@(0) forKey:kRecommendCoreKeyUnreadCount];
    [status setValue:@(0) forKey:kRecommendCoreKeyBannerDisplayStatus];
    NSError *error;
    if (adLocation == nil || adModel == 0) {
        error =
            [ApplilinkNetworkError localizedApplilinkErrorWithCode:RecommendCoreErrorCodeParameter];
    } else if ([RecommendCore sharedInstance].initializeFlg == 0 &&
               ![ApplilinkCore isInitializeStatusFlg]) {
        error = [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:RecommendCoreErrorCodeNotInitialized];
    } else if (![ApplilinkUdid isAdvertisingTrackingEnabled]) {
        error = [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:RecommendCoreErrorCodeAdTrackingDisabled];
    } else {
        [self startSessionWithCallback:^(NSError *sessionError) {
          /** @ghidraAddress 0x26a700 */
          if (sessionError != nil) {
              callback(status, sessionError);
              return;
          }
          [RecommendWebAPI getPreInfoWithAdModel:adModel adLocation:adLocation callback:callback];
        }];
        return;
    }
    callback(status, error);
}

- (void)getAllAdStatusWithCallback:(void (^)(NSError *error))callback {
    NSError *error;
    if ([RecommendCore sharedInstance].initializeFlg == 0 &&
        ![ApplilinkCore isInitializeStatusFlg]) {
        error = [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:RecommendCoreErrorCodeNotInitialized];
    } else if (![ApplilinkUdid isAdvertisingTrackingEnabled]) {
        error = [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:RecommendCoreErrorCodeAdTrackingDisabled];
    } else {
        [self startSessionWithCallback:^(NSError *sessionError) {
          /** @ghidraAddress 0x26a924 */
          if (sessionError == nil) {
              (void)[RecommendAdCache getAllAdStatus]; // Yes, the binary discards this result.
          }
          callback(sessionError);
        }];
        return;
    }
    callback(error);
}

- (void)clearAllAdData {
    [RecommendAdCache clearAllAdData];
}

- (void)reloadAllAdData {
    [RecommendAdCache clearAllAdData];
    [ApplilinkFile delateFolder];
    [RecommendAdCache clearAllAdDataInfoExpire];
    [self getAllAdStatusWithCallback:^(NSError *__attribute__((unused)) error){
        /** @ghidraAddress 0x26aa1c */
        // The binary passes a global no-op block here.
    }];
}

#pragma mark - Presentation

- (void)openAdScreenWithParentView:(UIView *)parentView
                           adModel:(int)adModel
                        adLocation:(NSString *)adLocation
                     verticalAlign:(int)verticalAlign
                       requestCode:(id)requestCode
                          delegate:(id)delegate {
    if (g_fAdScreenOpenInProgress) {
        ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
        [appParam setRequestWithAdModel:adModel adLocation:adLocation requestCode:requestCode];
        [ApplilinkCore toDelegateFailOpenWithError:
                           [ApplilinkNetworkError
                               localizedApplilinkErrorWithCode:RecommendCoreErrorCodeCacheCreate]
                                          appParam:appParam
                                          delegate:delegate];
        return;
    }
    g_fAdScreenOpenInProgress = YES;
    self.adScreenviewCloseFlg = NO;
    if (self.applilinkParams == nil) {
        self.applilinkParams = [[ApplilinkParameters alloc] init];
    }
    [self.applilinkParams setRequestWithAdModel:adModel
                                     adLocation:adLocation
                                    requestCode:requestCode];
    self.applilinkDelegate = delegate;
    [self
        setNavigationBarHidden:(parentView != nil && adModel == RecommendCoreAdModelInterstitial)];
    dispatch_async(dispatch_get_main_queue(), ^{
      /** @ghidraAddress 0x26acec */
      if (self.adScreenViewController == nil) {
          self.adScreenViewController = [[RecommendWebViewController alloc] init];
      }
      [self.adScreenViewController setSdkDelegate:self];
      [self.adScreenViewController setNavigationBarHidden:self.navigationBarHidden];
      if (parentView == nil) {
          UIWindow *window = [ApplilinkCore mainWindow];
          if (window != nil) {
              [window addSubview:self.adScreenViewController.view];
          }
      } else {
          [self.adScreenViewController setParentView:parentView];
          [parentView addSubview:self.adScreenViewController.view];
      }
      [self.adScreenViewController updateIndicator:YES];
      if (adModel == RecommendCoreAdModelInterstitial) {
          [self.adScreenViewController setWebViewBounces:NO];
      }
      if ((unsigned int)(adModel - RecommendCoreAdModelOwnAdBase) <
              RecommendCoreAdModelDirectRangeLength ||
          adModel == RecommendCoreAdModelInterstitial) {
          UIView *baseView = self.adScreenViewController.baseView;
          CGRect baseFrame = baseView.frame;
          // The rect is the base view's size placed at the origin, and the binary hands itself in
          // as the delegate rather than the caller's.
          [self openAdAreaWithParentView:baseView
                                    rect:CGRectMake(
                                             0.0, 0.0, baseFrame.size.width, baseFrame.size.height)
                                 adModel:adModel
                              adLocation:adLocation
                           verticalAlign:verticalAlign
                             requestCode:requestCode
                                delegate:self];
          g_fAdScreenOpenInProgress = NO;
      } else {
          [self appliListWithCallBack:^(id list, NSError *error) {
            /** @ghidraAddress 0x26b05c */
            RecommendCoreLoadAdScreenRequest(
                self, list, error, delegate, adLocation, adModel, verticalAlign);
          }];
      }
    });
}

// The installed-application-list completion for the advert-screen presentation.
/** @ghidraAddress 0x26b05c */
static void RecommendCoreLoadAdScreenRequest(RecommendCore *core,
                                             id appliList,
                                             NSError *error,
                                             id delegate,
                                             NSString *adLocation,
                                             int adModel,
                                             int verticalAlign) {
    if (error != nil) {
        [core releaseAdScreenViewController];
        [ApplilinkCore toDelegateFailOpenWithError:error
                                          appParam:core.applilinkParams
                                          delegate:delegate];
        return;
    }
    if (core.adScreenviewCloseFlg) {
        [core releaseAdScreenViewController];
        [ApplilinkCore toDelegateFailOpenWithError:nil
                                          appParam:core.applilinkParams
                                          delegate:delegate];
        return;
    }
    NSMutableArray *installedAdIds = [[NSMutableArray alloc] init];
    for (id entry in appliList) {
        if (![entry isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSString *scheme = entry[kRecommendCoreKeyDefaultScheme];
        NSString *adId = entry[kRecommendCoreKeyAdId];
        if ([scheme isKindOfClass:[NSString class]] && [core isInstalledAppliWithScheme:scheme] &&
            adId != nil) {
            [installedAdIds addObject:adId];
        }
    }
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:5];
    [parameters setValue:kRecommendCoreParamValueOne forKey:kRecommendCoreParamIsSdk];
    if (adLocation != nil) {
        [parameters setValue:adLocation forKey:kRecommendCoreParamAdLocation];
    }
    if (adModel != 0) {
        [parameters setValue:[NSString stringWithFormat:kRecommendCoreFormatInteger, adModel]
                      forKey:kRecommendCoreParamAdModel];
    }
    if (verticalAlign != 0) {
        [parameters setValue:[NSString stringWithFormat:kRecommendCoreFormatInteger, verticalAlign]
                      forKey:kRecommendCoreParamVerticalAlign];
    }
    if (installedAdIds.count != 0) {
        parameters[kRecommendCoreParamInstallAdIdList] = installedAdIds;
    }
    NSString *url =
        [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kRecommendCoreAdExternalIndexPath];
    [core.adScreenViewController loadRequestWithURL:url parameters:parameters];
    g_fAdScreenOpenInProgress = NO;
}

- (void)openAdAreaWithParentView:(UIView *)parentView
                            rect:(CGRect)rect
                         adModel:(int)adModel
                      adLocation:(NSString *)adLocation
                   verticalAlign:(int)verticalAlign
                     requestCode:(id)requestCode
                        delegate:(id)delegate {
    ApplilinkParameters *appParam;
    NSError *error;
    if (rect.size.width <= 0.0 || rect.size.height <= 0.0) {
        appParam = [[ApplilinkParameters alloc] init];
        [appParam setRequestWithAdModel:adModel adLocation:adLocation requestCode:requestCode];
        error =
            [ApplilinkNetworkError localizedApplilinkErrorWithCode:RecommendCoreErrorCodeParameter];
    } else if ([RecommendAdData getAdStatusByAdModel:adModel] != kRecommendCoreAdStatusAvailable) {
        appParam = [[ApplilinkParameters alloc] init];
        [appParam setRequestWithAdModel:adModel adLocation:adLocation requestCode:requestCode];
        error = [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:RecommendCoreErrorCodeNoBannerData];
    } else {
        self.adAreaDelegate = delegate;
        if ((unsigned int)(adModel - RecommendCoreAdModelOwnAdBase) >=
                RecommendCoreAdModelDirectRangeLength &&
            adModel != RecommendCoreAdModelInterstitial) {
            BOOL usedMainWindow = parentView == nil;
            UIView *hostView = parentView;
            if (usedMainWindow) {
                hostView = [ApplilinkCore mainWindow];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
              /** @ghidraAddress 0x26bee8 */
              RecommendWebView *webView = [[RecommendWebView alloc] initWithFrame:rect];
              [hostView addSubview:webView];
              if (usedMainWindow) {
                  if (self.interstitialViewController != nil) {
                      [hostView bringSubviewToFront:self.interstitialViewController.view];
                  }
                  if (self.adScreenViewController != nil) {
                      [hostView bringSubviewToFront:self.adScreenViewController.view];
                  }
              }
              [webView loadRequestWithAdModel:adModel
                                   adLocation:adLocation
                                verticalAlign:verticalAlign
                                  requestCode:requestCode
                                     delegate:delegate];
            });
            return;
        }
        NSString *impressionId = [ApplilinkUtilities getImpressionId];
        NSError *createError = [RecommendAdCache createHtmlWithAdModel:adModel
                                                            adLocation:adLocation
                                                         verticalAlign:verticalAlign
                                                          impressionId:impressionId];
        appParam = [[ApplilinkParameters alloc] init];
        [appParam setRequestWithAdModel:adModel adLocation:adLocation requestCode:requestCode];
        if (createError != nil) {
            [ApplilinkCore toDelegateFailOpenWithError:createError
                                              appParam:appParam
                                              delegate:delegate];
            return;
        }
        NSString *templatePath = [ApplilinkFile getTemplatePathWithAdModel:adModel
                                                                adLocation:adLocation];
        BOOL isDirectory = NO;
        if (![[NSFileManager defaultManager] fileExistsAtPath:templatePath
                                                  isDirectory:&isDirectory]) {
            [ApplilinkCore toDelegateFailOpenWithError:[ApplilinkNetworkError
                                                           localizedApplilinkErrorWithCode:
                                                               RecommendCoreErrorCodeCacheCreate]
                                              appParam:appParam
                                              delegate:delegate];
            return;
        }
        int adType = [RecommendAdData getAdTypeWithAdModel:adModel adLocation:adLocation];
        BOOL usedMainWindow = parentView == nil;
        UIView *hostView = parentView;
        if (usedMainWindow) {
            hostView = [ApplilinkCore mainWindow];
        }
        ApplilinkParameters *startParam = appParam;
        dispatch_async(dispatch_get_main_queue(), ^{
          /** @ghidraAddress 0x26bca8 */
          RecommendAdAreaView *areaView = [[RecommendAdAreaView alloc] initWithFrame:rect];
          [areaView setAdModel:adModel
                    adLocation:adLocation
                        adType:adType
                   requestCode:requestCode
                      delegate:delegate];
          [areaView setImpressionId:impressionId];
          [areaView startPath:templatePath];
          [hostView addSubview:areaView];
          [ApplilinkCore toDelegateDidStart:startParam delegate:delegate];
          if (usedMainWindow) {
              if (self.interstitialViewController != nil) {
                  [hostView bringSubviewToFront:self.interstitialViewController.view];
              }
              if (self.adScreenViewController != nil) {
                  [hostView bringSubviewToFront:self.adScreenViewController.view];
              }
          }
        });
        return;
    }
    [ApplilinkCore toDelegateFailOpenWithError:error appParam:appParam delegate:delegate];
}

- (void)openFullViewControllerWithAdModel:(int)adModel
                               adLocation:(NSString *)adLocation
                            verticalAlign:(int)verticalAlign
                              requestCode:(id)requestCode
                                 delegate:(id)delegate {
    if (g_fAdScreenOpenInProgress) {
        ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
        [appParam setRequestWithAdModel:adModel adLocation:adLocation requestCode:requestCode];
        [ApplilinkCore toDelegateFailOpenWithError:
                           [ApplilinkNetworkError
                               localizedApplilinkErrorWithCode:RecommendCoreErrorCodeCacheCreate]
                                          appParam:appParam
                                          delegate:delegate];
        return;
    }
    if ([RecommendAdData getAdStatusByAdModel:adModel] == kRecommendCoreAdStatusAvailable) {
        g_fAdScreenOpenInProgress = YES;
        self.adScreenviewCloseFlg = NO;
        if (self.applilinkParams == nil) {
            self.applilinkParams = [[ApplilinkParameters alloc] init];
        }
        [self.applilinkParams setRequestWithAdModel:adModel
                                         adLocation:adLocation
                                        requestCode:requestCode];
        self.applilinkDelegate = delegate;
        dispatch_async(dispatch_get_main_queue(), ^{
          /** @ghidraAddress 0x26c43c */
          if (self.interstitialViewController == nil) {
              self.interstitialViewController = [[RecommendFullScreenController alloc] init];
          }
          self.interstitialViewController.view.frame = [UIScreen mainScreen].bounds;
          [self.interstitialViewController openAdViewWithAdModel:adModel
                                                      adLocation:adLocation
                                                   verticalAlign:verticalAlign
                                                 applilinkParams:self.applilinkParams
                                                        delegate:delegate
                                                   closeDelegate:self];
        });
        return;
    }
    NSDictionary *userInfo = [NSDictionary
        dictionaryWithObjectsAndKeys:[NSString
                                         stringWithFormat:kRecommendCoreFormatBannerDisplayStatus,
                                                          adModel],
                                     kErrorUserInfoKey,
                                     nil];
    NSError *error =
        [ApplilinkNetworkError localizedApplilinkErrorWithCode:RecommendCoreErrorCodeNoBannerData
                                                      userInfo:userInfo];
    ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
    [appParam setRequestWithAdModel:adModel adLocation:adLocation requestCode:requestCode];
    [ApplilinkCore toDelegateFailOpenWithError:error appParam:appParam delegate:delegate];
}

- (void)openMovieViewControllerWithAdModel:(int)adModel
                                adLocation:(NSString *)adLocation
                             verticalAlign:(int)verticalAlign
                               requestCode:(id)requestCode
                                  delegate:(id)delegate {
    if (g_fAdScreenOpenInProgress) {
        ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
        [appParam setRequestWithAdModel:adModel adLocation:adLocation requestCode:requestCode];
        [ApplilinkCore toDelegateFailOpenWithError:
                           [ApplilinkNetworkError
                               localizedApplilinkErrorWithCode:RecommendCoreErrorCodeCacheCreate]
                                          appParam:appParam
                                          delegate:delegate];
        return;
    }
    if ([RecommendAdData getAdStatusByAdModel:adModel] == kRecommendCoreAdStatusAvailable) {
        g_fAdScreenOpenInProgress = YES;
        self.adScreenviewCloseFlg = NO;
        if (self.applilinkParams == nil) {
            self.applilinkParams = [[ApplilinkParameters alloc] init];
        }
        [self.applilinkParams setRequestWithAdModel:adModel
                                         adLocation:adLocation
                                        requestCode:requestCode];
        self.applilinkDelegate = delegate;
        dispatch_async(dispatch_get_main_queue(), ^{
          /** @ghidraAddress 0x26c970 */
          if (self.interstitialViewController == nil) {
              self.interstitialViewController = [[RecommendFullScreenController alloc] init];
          }
          self.interstitialViewController.view.frame = [UIScreen mainScreen].bounds;
          [self.interstitialViewController openMovieWithAdModel:adModel
                                                     adLocation:adLocation
                                                  verticalAlign:verticalAlign
                                                applilinkParams:self.applilinkParams
                                                       delegate:delegate
                                                  closeDelegate:self];
        });
        return;
    }
    NSDictionary *userInfo = [NSDictionary
        dictionaryWithObjectsAndKeys:[NSString
                                         stringWithFormat:kRecommendCoreFormatBannerDisplayStatus,
                                                          adModel],
                                     kErrorUserInfoKey,
                                     nil];
    NSError *error =
        [ApplilinkNetworkError localizedApplilinkErrorWithCode:RecommendCoreErrorCodeNoBannerData
                                                      userInfo:userInfo];
    ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
    [appParam setRequestWithAdModel:adModel adLocation:adLocation requestCode:requestCode];
    [ApplilinkCore toDelegateFailOpenWithError:error appParam:appParam delegate:delegate];
}

- (void)closeAdScreen {
    if (!self.adScreenviewCloseFlg) {
        [self.adScreenViewController appliListClosed];
    }
    if (self.interstitialViewController != nil) {
        if ([self.interstitialViewController isVisible]) {
            [ApplilinkCore toDelegateDidDisappear:self.applilinkParams
                                         delegate:self.applilinkDelegate];
        } else {
            [ApplilinkCore toDelegateFailOpenWithError:[ApplilinkNetworkError
                                                           localizedApplilinkErrorWithCode:
                                                               RecommendCoreErrorCodeCacheCreate]
                                              appParam:self.applilinkParams
                                              delegate:self.applilinkDelegate];
        }
        self.applilinkDelegate = nil;
        [self releaseInterstitialViewController];
    }
    self.adScreenviewCloseFlg = YES;
    g_fAdScreenOpenInProgress = NO;
    self.adScreenViewController = nil;
}

- (void)showVideoViewWithQuery:(NSString *)query {
    if (self.adScreenViewController != nil) {
        [[ApplilinkViewManager sharedInstance]
            showVideoViewWithUIView:self.adScreenViewController.view
                   parentWindowFlag:YES
                              query:query
                           autoPlay:NO
                    applilinkParams:self.applilinkParams
                           delegate:self.applilinkDelegate];
    }
}

- (void)rotateWithInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
                              duration:(NSTimeInterval)duration {
    if (self.adScreenViewController != nil) {
        [self.adScreenViewController willAnimateRotationToInterfaceOrientation:interfaceOrientation
                                                                      duration:duration];
    }
    if (self.interstitialViewController != nil) {
        [self.interstitialViewController
            willAnimateRotationToInterfaceOrientation:interfaceOrientation
                                             duration:duration];
    }
}

#pragma mark - Redirect

- (int)redirectViewContollerWithRequest:(NSURLRequest *)request {
    return [self redirectWithRequest:request appParam:self.applilinkParams];
}

- (int)redirectWithRequest:(NSURLRequest *)request {
    return [self redirectWithRequest:request appParam:nil];
}

- (int)redirectWithRequest:(NSURLRequest *)request appParam:(ApplilinkParameters *)appParam {
    // The binary rewrites the request URL in place, so it is always an NSMutableURLRequest.
    NSMutableURLRequest *mutableRequest = (NSMutableURLRequest *)request;
    NSURL *url = request.URL;
    NSString *scheme = url.scheme;
    NSString *host = url.host;
    int port = [url.port intValue];
    NSString *path = url.path;
    NSString *query = url.query;
    if ([scheme hasPrefix:kRecommendCoreApplilinkScheme] &&
        [host isEqualToString:kRecommendCoreExtAppHost] && port == kRecommendCoreExtAppPort) {
        self.urlString = nil;
        NSString *adIdTo = nil;
        NSString *storeId = nil;
        NSString *countryCode = nil;
        NSString *categoryId = nil;
        NSString *adType = nil;
        NSString *defaultScheme = nil;
        BOOL handledScheme = NO;
        BOOL openedExternalApp = NO;
        if (query != nil) {
            NSArray *components = [query componentsSeparatedByString:kRecommendCoreQuerySeparator];
            for (NSString *component in components) {
                if ([component rangeOfString:kRecommendCoreQueryKeyDefaultScheme].location !=
                    NSNotFound) {
                    NSString *value =
                        [component substringFromIndex:kRecommendCoreQueryDefaultScheme.length];
                    defaultScheme = [NSStringURLEncoding URLDecodedString:value];
                    NSURL *appUrl = [NSURL
                        URLWithString:[NSString stringWithFormat:kRecommendCoreFormatSchemeOnly,
                                                                 defaultScheme]];
                    if (appUrl != nil && [[UIApplication sharedApplication] canOpenURL:appUrl]) {
                        [[UIApplication sharedApplication] openURL:appUrl];
                        openedExternalApp = YES;
                    }
                    // Whether or not the app launched, the default_scheme case ends the scan.
                    handledScheme = YES;
                    break;
                } else if ([component rangeOfString:kRecommendCoreQueryKeyAdIdFrom].location !=
                           NSNotFound) {
                    adIdTo = [NSStringURLEncoding
                        URLDecodedString:[component substringFromIndex:kRecommendCoreQueryAdIdFrom
                                                                           .length]];
                } else if ([component rangeOfString:kRecommendCoreQueryKeyCountryCode].location !=
                           NSNotFound) {
                    countryCode = [NSStringURLEncoding
                        URLDecodedString:[component
                                             substringFromIndex:kRecommendCoreQueryCountryCode
                                                                    .length]];
                } else if ([component rangeOfString:kRecommendCoreQueryKeyCategoryId].location !=
                           NSNotFound) {
                    categoryId = [NSStringURLEncoding
                        URLDecodedString:[component substringFromIndex:kRecommendCoreQueryCategoryId
                                                                           .length]];
                } else if ([component rangeOfString:kRecommendCoreQueryKeyAdType].location !=
                           NSNotFound) {
                    adType = [NSStringURLEncoding
                        URLDecodedString:[component
                                             substringFromIndex:kRecommendCoreQueryAdType.length]];
                } else if ([component rangeOfString:kRecommendCoreQueryKeyStoreId].location !=
                           NSNotFound) {
                    storeId = [NSStringURLEncoding
                        URLDecodedString:[component
                                             substringFromIndex:kRecommendCoreQueryStoreId.length]];
                }
            }
        }
        // The default_scheme case that actually launched an app stops the redirect here; one that
        // could not be opened falls through and the rest of the routine still runs.
        if (handledScheme && openedExternalApp) {
            return RecommendCoreRedirectOpenedExternalApp;
        }
        if (adIdTo != nil && countryCode != nil && categoryId != nil) {
            RecommendAdId *adId = [[RecommendAdId alloc] initWithCountryCode:countryCode
                                                                  categoryId:categoryId];
            [adId setWithAdIdFrom:adIdTo
                      countryCode:countryCode
                       categoryId:categoryId
                           adType:adType
                            error:nil];
        }
        // The binary rebuilds the "applilink://ext-app:80" prefix with stringWithFormat: and a
        // literal format string carrying no specifiers, so it is just the constant below.
        NSString *extAppPrefix = kRecommendCoreApplilinkExtAppUrl;
        NSString *tail = path;
        if ([url.absoluteString hasPrefix:extAppPrefix]) {
            tail = [url.absoluteString substringFromIndex:extAppPrefix.length];
            if (query.length != 0) {
                NSString *querySuffix =
                    [NSString stringWithFormat:kRecommendCoreFormatQuery, query];
                if ([tail hasSuffix:querySuffix]) {
                    tail = [tail substringToIndex:tail.length - querySuffix.length];
                }
            }
        }
        if (tail.length == 0) {
            return RecommendCoreRedirectDefault;
        }
        NSArray *segments =
            [[tail substringFromIndex:1] componentsSeparatedByString:kRecommendCorePathSeparator];
        if (segments.count == 0) {
            return RecommendCoreRedirectDefault;
        }
        NSString *destination = [NSStringURLEncoding URLDecodedString:segments[0]];
        if ([destination hasSuffix:kRecommendCoreChangeDestSuffix]) {
            [self reloadAllAdData];
            NSURL *destUrl = [NSURL
                URLWithString:[destination substringToIndex:destination.length -
                                                            kRecommendCoreChangeDestSuffix.length]];
            [mutableRequest setURL:destUrl];
            return RecommendCoreRedirectChangeDest;
        }
        if ([destination isEqualToString:kRecommendCoreCloseHost]) {
            return RecommendCoreRedirectClose;
        }
        if ([destination isEqualToString:kRecommendCoreMovieHost]) {
            return RecommendCoreRedirectMovie;
        }
        self.urlString = [NSString stringWithString:destination];
        if ([ApplilinkCore showAppStoreId:storeId appParam:appParam delegate:self]) {
            return RecommendCoreRedirectAppStore;
        }
        NSURL *destUrl = [NSURL URLWithString:destination];
        [mutableRequest setURL:destUrl];
        if (destUrl != nil && [[UIApplication sharedApplication] canOpenURL:destUrl]) {
            [ApplilinkCore toDelegateDidAppear:appParam delegate:self.uniqueAdDelegate];
            [[UIApplication sharedApplication] openURL:destUrl];
            return RecommendCoreRedirectOpenedUrl;
        }
    }
    return RecommendCoreRedirectDefault;
}

#pragma mark - Banner cache

- (id)getTemporaryCacheWithAdModel:(int)adModel {
    NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:kRecommendCoreBannerInfoKey];
    if (data == nil) {
        return nil;
    }
    NSDictionary *table = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    if (table == nil) {
        return nil;
    }
    // The binary boxes the model with -numberWithUnsignedInt:, not -numberWithInt:.
    NSString *modelKey = [@((unsigned int)adModel) stringValue];
    NSDictionary *entry = table[modelKey];
    if (entry == nil) {
        return nil;
    }
    if ([entry[kRecommendCoreKeyExpire] compare:[NSDate date]] != NSOrderedAscending) {
        return entry[kRecommendCoreKeyStatus];
    }
    NSMutableDictionary *mutableTable = [table mutableCopy];
    [mutableTable removeObjectForKey:[@((unsigned int)adModel) stringValue]];
    NSData *archived = [NSKeyedArchiver archivedDataWithRootObject:mutableTable];
    [[NSUserDefaults standardUserDefaults] setObject:archived forKey:kRecommendCoreBannerInfoKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    return nil;
}

- (BOOL)canUseBannerCache {
    NSString *udid = [ApplilinkCore udid];
    NSString *adUdid = [ApplilinkCore ad_udid];
    NSString *oldUdid = [ApplilinkCore old_udid];
    if (udid == nil && oldUdid == nil && adUdid == nil) {
        [self clearAdStatus];
    }
    return udid != nil || oldUdid != nil || adUdid != nil;
}

- (void)clearAdStatus {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kRecommendCoreBannerInfoKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)clearSession {
    NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *cookie in storage.cookies) {
        [storage deleteCookie:cookie];
    }
}

/** @ghidraAddress 0x26e33c */
+ (void)clearData {
    NSString *env = [ApplilinkConsts envServer];
    if (env != nil && ![env isEqualToString:kRecommendCoreEnvServerDisabled]) {
        [ApplilinkUdid deleteAllUDID];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kRecommendCorePostInstalledKey];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kRecommendCoreAppliIdKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

#pragma mark - Analytics and first-party adverts

- (void)postAnalysisListRegistWithAdType:(int)adType
                                 AdModel:(int)adModel
                              adLocation:(NSString *)adLocation
                            impressionId:(NSString *)impressionId {
    // The binary builds a fifth array of ad_id values and never passes it to the post, so the four
    // lists actually posted are appli_id, the creative URL file names, incentive types, and install
    // flags.
    NSMutableArray *adIdList = [NSMutableArray array];
    NSMutableArray *appliIdList = [NSMutableArray array];
    NSMutableArray *creativeIdList = [NSMutableArray array];
    NSMutableArray *incentiveTypeList = [NSMutableArray array];
    NSMutableArray *installFlgList = [NSMutableArray array];
    NSArray *records = [RecommendAdCache getHtmlAdDataWithAdModel:adModel adLocation:adLocation];
    for (NSDictionary *record in records) {
        NSString *adId = record[kRecommendCoreKeyAdId];
        if (adId != nil) {
            [adIdList addObject:adId];
        }
        NSString *appliId = record[kRecommendCoreKeyAppliId];
        if (appliId != nil) {
            [appliIdList addObject:appliId];
        }
        NSString *creativeUrl = nil;
        if (adType == RecommendCoreAdTypeInterstitial) {
            if ([RecommendAdData checkMovieWithAdData:record]) {
                creativeUrl = record[kRecommendCoreKeyPosterUrlRect];
            } else {
                creativeUrl = record[kRecommendCoreKeyInterstitialBannerUrl];
            }
        } else if (adType == RecommendCoreAdTypeIcon) {
            creativeUrl = record[kRecommendCoreKeyBannerIconUrl];
        } else if (adType == RecommendCoreAdTypeBanner) {
            creativeUrl = record[kRecommendCoreKeyBannerUrl];
        }
        if (creativeUrl != nil) {
            NSString *fileName = [ApplilinkUtilities getFileNameFromPath:creativeUrl];
            if (fileName != nil) {
                [creativeIdList addObject:fileName];
            }
        }
        NSString *incentiveType = record[kRecommendCoreKeyIncentiveType];
        if (incentiveType != nil) {
            [incentiveTypeList addObject:incentiveType];
        }
        NSString *installFlg = [RecommendAdData getInstallFlgWithAdData:record];
        if (installFlg != nil) {
            [installFlgList addObject:installFlg];
        }
    }
    [AnalysisNetworkCore
        postAnalysisListRegistWithAdType:[NSString
                                             stringWithFormat:kRecommendCoreFormatInteger, adType]
                                 adModel:[NSString
                                             stringWithFormat:kRecommendCoreFormatInteger, adModel]
                              adLocation:adLocation
                            impressionId:impressionId
                             appliIdList:appliIdList
                          creativeIdList:creativeIdList
                       incentiveTypeList:incentiveTypeList
                          installFlgList:installFlgList
                                callback:^(NSError *error) {
                                  /** @ghidraAddress 0x26e9f0 */
                                  if (error != nil) {
                                      return;
                                  }
                                  [self setUniqueAdWithAdLocation:adLocation
                                                     impressionId:impressionId];
                                }];
}

- (void)showOwnAdWithAdLocation:(NSString *)adLocation
                      toAppliId:(NSString *)appliId
                     creativeId:(NSString *)creativeId {
    [self showOwnAdWithAdLocation:adLocation
                          adModel:RecommendCoreAdModelOwnAdBase
                        toAppliId:appliId
                       creativeId:creativeId];
}

- (void)showOwnAdWithAdLocation:(NSString *)adLocation
                        adModel:(int)adModel
                      toAppliId:(NSString *)appliId
                     creativeId:(NSString *)creativeId {
    if (adLocation == nil || adModel == 0) {
        return;
    }
    if (!([RecommendCore sharedInstance].initializeFlg != 0 ||
          [ApplilinkCore isInitializeStatusFlg]) ||
        ![ApplilinkUdid isAdvertisingTrackingEnabled]) {
        return;
    }
    int adType = [RecommendAdData getAdTypeWithAdModel:adModel adLocation:adLocation];
    [self startSessionWithCallback:^(NSError *error) {
      /** @ghidraAddress 0x26ecb0 */
      RecommendCorePostOwnAdImpression(
          self, error, adLocation, appliId, creativeId, adType, adModel);
    }];
}

// The session-gated impression-registration completion for a first-party advert.
/** @ghidraAddress 0x26ecb0 */
static void RecommendCorePostOwnAdImpression(RecommendCore *core,
                                             NSError *error,
                                             NSString *adLocation,
                                             NSString *toAppliId,
                                             NSString *creativeId,
                                             int adType,
                                             int adModel) {
    if (error != nil) {
        return;
    }
    NSMutableArray *appliIdList = [NSMutableArray array];
    NSMutableArray *creativeIdList = [NSMutableArray array];
    NSMutableArray *incentiveTypeList = [NSMutableArray array];
    NSMutableArray *installFlgList = [NSMutableArray array];
    NSString *impressionId = [ApplilinkUtilities getImpressionId];
    [core setUniqueAdWithAdLocation:adLocation impressionId:impressionId];
    if (toAppliId != nil && creativeId != nil) {
        NSDictionary *record = [RecommendAdData getAdDataWithAppliId:toAppliId];
        NSString *installFlg = kRecommendCoreInstallFlgNone;
        if (record != nil) {
            installFlg = [RecommendAdData getInstallFlgWithAdData:record];
        }
        [appliIdList addObject:toAppliId];
        [creativeIdList addObject:creativeId];
        [incentiveTypeList addObject:kRecommendCoreKeyRewardNone];
        [installFlgList addObject:installFlg];
    }
    [AnalysisNetworkCore
        postAnalysisListRegistWithAdType:[NSString
                                             stringWithFormat:kRecommendCoreFormatInteger, adType]
                                 adModel:[NSString
                                             stringWithFormat:kRecommendCoreFormatInteger, adModel]
                              adLocation:adLocation
                            impressionId:impressionId
                             appliIdList:appliIdList
                          creativeIdList:creativeIdList
                       incentiveTypeList:incentiveTypeList
                          installFlgList:installFlgList
                                callback:^(NSError *__attribute__((unused)) registerError){
                                    /** @ghidraAddress 0x26ef8c */
                                    // The binary passes a global no-op block here.
                                }];
}

- (void)touchOwnAdWithAdLocation:(NSString *)adLocation
                       toAppliId:(NSString *)appliId
                      creativeId:(NSString *)creativeId
                     requestCode:(id)requestCode
                        delegate:(id)delegate {
    [self touchOwnAdWithAdLocation:adLocation
                           adModel:RecommendCoreAdModelOwnAdBase
                         toAppliId:appliId
                        creativeId:creativeId
                       requestCode:requestCode
                          delegate:delegate];
}

- (void)touchOwnAdWithAdLocation:(NSString *)adLocation
                         adModel:(int)adModel
                       toAppliId:(NSString *)appliId
                      creativeId:(NSString *)creativeId
                     requestCode:(id)requestCode
                        delegate:(id)delegate {
    NSError *error;
    if (adLocation == nil || appliId == nil || creativeId == nil || adModel == 0) {
        error =
            [ApplilinkNetworkError localizedApplilinkErrorWithCode:RecommendCoreErrorCodeParameter];
    } else if ([RecommendCore sharedInstance].initializeFlg == 0 &&
               ![ApplilinkCore isInitializeStatusFlg]) {
        error = [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:RecommendCoreErrorCodeNotInitialized];
    } else if (![ApplilinkUdid isAdvertisingTrackingEnabled]) {
        error = [ApplilinkNetworkError
            localizedApplilinkErrorWithCode:RecommendCoreErrorCodeAdTrackingDisabled];
    } else {
        int adType = [RecommendAdData getAdTypeWithAdModel:adModel adLocation:adLocation];
        [self startSessionWithCallback:^(NSError *sessionError) {
          /** @ghidraAddress 0x26f424 */
          RecommendCorePostOwnAdClickRegist(self,
                                            sessionError,
                                            adLocation,
                                            requestCode,
                                            delegate,
                                            appliId,
                                            creativeId,
                                            adModel,
                                            adType);
        }];
        return;
    }
    ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
    [appParam setRequestWithAdModel:adModel adLocation:adLocation requestCode:requestCode];
    [ApplilinkCore toDelegateFailOpenWithError:error appParam:appParam delegate:delegate];
}

// The session-gated click-registration completion for a first-party advert touch.
/** @ghidraAddress 0x26f424 */
static void RecommendCorePostOwnAdClickRegist(RecommendCore *core,
                                              NSError *error,
                                              NSString *adLocation,
                                              id requestCode,
                                              id delegate,
                                              NSString *toAppliId,
                                              NSString *creativeId,
                                              int adModel,
                                              int adType) {
    if (error != nil) {
        ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
        [appParam setRequestWithAdModel:adModel adLocation:adLocation requestCode:requestCode];
        [ApplilinkCore toDelegateFailOpenWithError:error appParam:appParam delegate:delegate];
        return;
    }
    NSString *impressionId = [core getUniqueAdWithAdLocation:adLocation];
    if ([impressionId length] == 0) {
        impressionId = [ApplilinkUtilities getImpressionId];
    }
    NSDictionary *record = [RecommendAdData getAdDataWithAppliId:toAppliId];
    if (record == nil) {
        NSDictionary *userInfo = [NSDictionary
            dictionaryWithObjectsAndKeys:[NSString
                                             stringWithFormat:kRecommendCoreFormatAllAdDataMissing,
                                                              toAppliId],
                                         kErrorUserInfoKey,
                                         nil];
        NSError *noDataError =
            [ApplilinkNetworkError localizedApplilinkErrorWithCode:RecommendCoreErrorCodeNoAdData
                                                          userInfo:userInfo];
        ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
        [appParam setRequestWithAdModel:adModel adLocation:adLocation requestCode:requestCode];
        [ApplilinkCore toDelegateFailOpenWithError:noDataError appParam:appParam delegate:delegate];
        return;
    }
    NSString *adId = record[kRecommendCoreKeyAdId];
    NSString *installFlg = [RecommendAdData getInstallFlgWithAdData:record];
    NSString *defaultScheme = record[kRecommendCoreKeyDefaultScheme];
    [AnalysisNetworkCore
        postAnalysisClickRegistWithAdType:[NSString
                                              stringWithFormat:kRecommendCoreFormatInteger, adType]
                                  adModel:[NSString
                                              stringWithFormat:kRecommendCoreFormatInteger, adModel]
                               adLocation:adLocation
                             impressionId:impressionId
                                appliIdTo:toAppliId
                               creativeId:creativeId
                            displayNumber:kRecommendCoreDisplayNumberDefault
                            incentiveType:kRecommendCoreKeyRewardNone
                               installFlg:installFlg
                                 callback:^(NSError *clickError) {
                                   /** @ghidraAddress 0x26f8d8 */
                                   if (clickError != nil) {
                                       ApplilinkParameters *appParam =
                                           [[ApplilinkParameters alloc] init];
                                       [appParam setRequestWithAdModel:adModel
                                                            adLocation:adLocation
                                                           requestCode:requestCode];
                                       [ApplilinkCore toDelegateFailOpenWithError:clickError
                                                                         appParam:appParam
                                                                         delegate:delegate];
                                       return;
                                   }
                                   if (core.uniqueApplilinkParams == nil) {
                                       core.uniqueApplilinkParams =
                                           [[ApplilinkParameters alloc] init];
                                   }
                                   // The binary hard-codes ad model 100 here, not the caller's.
                                   [core.uniqueApplilinkParams
                                       setRequestWithAdModel:RecommendCoreAdModelOwnAdBase
                                                  adLocation:adLocation
                                                 requestCode:requestCode];
                                   NSString *adTypeString =
                                       [NSString stringWithFormat:kRecommendCoreFormatInteger,
                                                                  RecommendCoreAdTypeBanner];
                                   NSString *adModelString =
                                       [NSString stringWithFormat:kRecommendCoreFormatInteger,
                                                                  RecommendCoreAdModelOwnAdBase];
                                   [core linkActionWithDefaultScheme:defaultScheme
                                                              adIdTo:adId
                                                              adType:adTypeString
                                                             adModel:adModelString
                                                            delegate:delegate];
                                 }];
}

- (void)linkActionWithDefaultScheme:(NSString *)defaultScheme
                             adIdTo:(NSString *)adIdTo
                             adType:(NSString *)adType
                            adModel:(NSString *)adModel
                           delegate:(id)delegate {
    self.uniqueAdDelegate = delegate;
    self.redirectFlg = NO;
    NSURL *schemeUrl = [NSURL
        URLWithString:[NSString stringWithFormat:kRecommendCoreFormatSchemeOnly, defaultScheme]];
    BOOL canOpenScheme = NO;
    if (schemeUrl != nil) {
        canOpenScheme = [[UIApplication sharedApplication] canOpenURL:schemeUrl];
    }
    NSString *adIdFrom = [ApplilinkConsts adId];
    NSURLRequest *request;
    if (!canOpenScheme) {
        request = [RecommendWebAPI clickRegistWithAdIdFrom:adIdFrom
                                                    adIdTo:adIdTo
                                                   adModel:[adModel intValue]];
    } else {
        request = [RecommendWebAPI appStartWithAdIdFrom:adIdFrom
                                                 adIdTo:adIdTo
                                                 adType:[adType intValue]];
    }
    ApplilinkURLConnection *connection = [[ApplilinkURLConnection alloc] init];
    [connection loadRequestWithRequest:request delegate:self];
}

- (void)linkActionWithURL:(NSString *)url delegate:(id)delegate {
    self.uniqueAdDelegate = delegate;
    self.redirectFlg = NO;
    NSURL *requestUrl = [NSURL URLWithString:url];
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:requestUrl];
    ApplilinkURLConnection *connection = [[ApplilinkURLConnection alloc] init];
    [connection loadRequestWithRequest:request delegate:self];
}

- (void)setUniqueAdWithAdLocation:(NSString *)adLocation impressionId:(NSString *)impressionId {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSData *data = [defaults dataForKey:kRecommendCoreUniqueAdDataKey];
    NSMutableDictionary *table;
    if (data == nil) {
        table = [NSMutableDictionary dictionary];
    } else {
        table = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    }
    if (impressionId == nil) {
        [table removeObjectForKey:adLocation];
    } else {
        [table setObject:impressionId forKey:adLocation];
    }
    NSData *archived = [NSKeyedArchiver archivedDataWithRootObject:table];
    [defaults setObject:archived forKey:kRecommendCoreUniqueAdDataKey];
    [defaults synchronize];
}

- (id)getUniqueAdWithAdLocation:(NSString *)adLocation {
    NSData *data = [[NSUserDefaults standardUserDefaults] dataForKey:kRecommendCoreUniqueAdDataKey];
    if (data == nil) {
        return nil;
    }
    NSDictionary *table = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    return table[adLocation];
}

- (NSString *)getMovideEndUrlWithAdIdFrom:(NSString *)adIdFrom
                                   adIdTo:(NSString *)adIdTo
                                  adModel:(NSString *)adModel
                               adLocation:(NSString *)adLocation
                             impressionId:(NSString *)impressionId
                               creativeId:(NSString *)creativeId
                            displayNumber:(NSString *)displayNumber
                               installFlg:(NSString *)installFlg {
    if (adIdFrom == nil || adIdTo == nil || adModel == nil || adLocation == nil ||
        impressionId == nil || creativeId == nil || displayNumber == nil || installFlg == nil) {
        return nil;
    }
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:8];
    [parameters setValue:adIdFrom forKey:kRecommendCoreMovieKeyAdIdFrom];
    [parameters setValue:adIdTo forKey:kRecommendCoreMovieKeyAdIdTo];
    [parameters setValue:adModel forKey:kRecommendCoreMovieKeyAdModel];
    [parameters setValue:adLocation forKey:kRecommendCoreMovieKeyAdLocation];
    [parameters setValue:impressionId forKey:kRecommendCoreMovieKeyImpressionId];
    [parameters setValue:creativeId forKey:kRecommendCoreMovieKeyCreativeId];
    [parameters setValue:displayNumber forKey:kRecommendCoreMovieKeyDisplayNumber];
    [parameters setValue:installFlg forKey:kRecommendCoreMovieKeyInstallFlg];
    NSString *url =
        [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kRecommendCoreMovieEndPath];
    return [ApplilinkUtilities appendParametersToURL:url parameters:parameters];
}

#pragma mark - Click connection callbacks

- (void)failLoadWithError:(NSError *)error {
    if (error.code == kRecommendCoreWebKitCancelledCode) {
        return;
    }
    if (error.code == kRecommendCoreWebKitFrameLoadInterruptedCode &&
        [error.domain isEqual:kRecommendCoreWebKitErrorDomain]) {
        return;
    }
    if (error.code == kRecommendCoreWebKitPlugInCancelledCode &&
        [error.domain isEqual:kRecommendCoreWebKitErrorDomain]) {
        return;
    }
    if (!self.redirectFlg) {
        [ApplilinkCore toDelegateFailOpenWithError:error
                                          appParam:self.uniqueApplilinkParams
                                          delegate:self.uniqueAdDelegate];
        self.uniqueAdDelegate = nil;
    }
}

- (void)finishLoadWithResponse:(id)response {
    [ApplilinkCore toDelegateDidAppear:self.uniqueApplilinkParams delegate:self.uniqueAdDelegate];
}

- (BOOL)redirectStartLoad:(NSURLRequest *)request {
    NSMutableURLRequest *mutableRequest = [NSMutableURLRequest requestWithURL:request.URL];
    if ([self redirectWithRequest:mutableRequest] == RecommendCoreRedirectDefault) {
        self.redirectFlg = YES;
    }
    return NO;
}

#pragma mark - Controller teardown

- (void)releaseAdScreenViewController {
    if (self.adScreenViewController != nil) {
        [self.adScreenViewController viewDealloc];
        self.adScreenViewController = nil;
    }
    g_fAdScreenOpenInProgress = NO;
}

- (void)releaseInterstitialViewController {
    if (self.interstitialViewController != nil) {
        [self.interstitialViewController.view removeFromSuperview];
        self.interstitialViewController = nil;
    }
    g_fAdScreenOpenInProgress = NO;
}

#pragma mark - Installed-application list notices

- (void)appListDidStart {
    if (self.applilinkDelegate != nil) {
        if ([self.applilinkDelegate respondsToSelector:@selector(appListDidStart)]) {
            [self.applilinkDelegate appListDidStart];
        }
    }
    if (self.adScreenViewController != nil) {
        [ApplilinkCore toDelegateDidAppear:self.applilinkParams delegate:self.applilinkDelegate];
    }
}

- (void)appListDidAppear {
    if (self.adScreenViewController == nil) {
        ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
        [appParam setRequestWithAdModel:0 adLocation:nil requestCode:nil];
        [ApplilinkCore toDelegateDidAppear:appParam delegate:self.adAreaDelegate];
    } else {
        [self.adScreenViewController updateIndicator:NO];
        [ApplilinkCore toDelegateDidAppear:self.applilinkParams delegate:self.applilinkDelegate];
    }
}

- (void)appListDidDisappear {
    [self appListSoundUseFinish];
    if (self.adScreenViewController != nil) {
        [self.adScreenViewController clearDelegate];
        [self releaseAdScreenViewController];
        [ApplilinkCore toDelegateDidDisappear:self.applilinkParams delegate:self.applilinkDelegate];
        self.applilinkDelegate = nil;
        return;
    }
    ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
    [appParam setRequestWithAdModel:0 adLocation:nil requestCode:nil];
    [ApplilinkCore toDelegateDidDisappear:appParam delegate:self.adAreaDelegate];
    self.adAreaDelegate = nil;
}

- (void)appListFailOpenWithError:(NSError *)error {
    if (self.adScreenViewController == nil) {
        if (self.adAreaDelegate != self) {
            ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
            [appParam setRequestWithAdModel:0 adLocation:nil requestCode:nil];
            [ApplilinkCore toDelegateFailOpenWithError:error
                                              appParam:appParam
                                              delegate:self.adAreaDelegate];
            self.adAreaDelegate = nil;
        }
    } else {
        [self.adScreenViewController clearDelegate];
        [self releaseAdScreenViewController];
        if (self.applilinkDelegate != self) {
            [ApplilinkCore toDelegateFailOpenWithError:error
                                              appParam:self.applilinkParams
                                              delegate:self.applilinkDelegate];
            self.applilinkDelegate = nil;
        }
    }
}

- (void)appListFailLoadWithError:(NSError *)error {
    if (self.adScreenViewController == nil) {
        if (self.adAreaDelegate != self) {
            ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
            [appParam setRequestWithAdModel:0 adLocation:nil requestCode:nil];
            [ApplilinkCore toDelegateFailLoadWithError:error
                                              appParam:appParam
                                              delegate:self.adAreaDelegate];
            self.adAreaDelegate = nil;
        }
    } else {
        [self.adScreenViewController clearDelegate];
        [self releaseAdScreenViewController];
        if (self.applilinkDelegate != self) {
            [ApplilinkCore toDelegateFailLoadWithError:error
                                              appParam:self.applilinkParams
                                              delegate:self.applilinkDelegate];
            self.applilinkDelegate = nil;
        }
    }
}

- (void)appListFailWithError:(NSError *)error {
    if (self.adScreenViewController == nil) {
        if (self.adAreaDelegate != self) {
            ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
            [appParam setRequestWithAdModel:0 adLocation:nil requestCode:nil];
            [ApplilinkCore toDelegateFailLoadWithError:error
                                              appParam:appParam
                                              delegate:self.adAreaDelegate];
            self.adAreaDelegate = nil;
        }
    } else {
        [self.adScreenViewController clearDelegate];
        [self releaseAdScreenViewController];
        if (self.applilinkDelegate != self) {
            [ApplilinkCore toDelegateFailLoadWithError:error
                                              appParam:self.applilinkParams
                                              delegate:self.applilinkDelegate];
            self.applilinkDelegate = nil;
        }
    }
}

- (void)appListSoundUseStart {
    [ApplilinkCore toDelegateSoundUseStart:self.applilinkDelegate];
}

- (void)appListSoundUseFinish {
    [ApplilinkCore toDelegateSoundUseFinish:self.applilinkDelegate];
}

#pragma mark - Advert-lifecycle notices

- (void)startedNotice {
    [ApplilinkCore toDelegateDidStart:self.applilinkParams delegate:self.applilinkDelegate];
}

- (void)openedNotice {
    [ApplilinkCore toDelegateDidAppear:self.applilinkParams delegate:self.applilinkDelegate];
    if (self.adScreenViewController != nil) {
        [self.adScreenViewController updateIndicator:NO];
    }
}

- (void)closeNotice {
    if (self.adScreenViewController != nil) {
        [self.adScreenViewController clearDelegate];
    }
    [self releaseAdScreenViewController];
    [self appListSoundUseFinish];
    [ApplilinkCore toDelegateDidDisappear:self.applilinkParams delegate:self.applilinkDelegate];
    self.applilinkDelegate = nil;
}

- (void)failOpenNoticeWithError:(NSError *)error {
    if (self.adScreenViewController != nil) {
        [self.adScreenViewController clearDelegate];
    }
    [self releaseAdScreenViewController];
    [ApplilinkCore toDelegateFailLoadWithError:error
                                      appParam:self.applilinkParams
                                      delegate:self.applilinkDelegate];
    self.applilinkDelegate = nil;
}

- (void)failLinkNoticeWithError:(NSError *)error {
    [ApplilinkCore toDelegateFailLinkWithError:error
                                      appParam:self.applilinkParams
                                      delegate:self.applilinkDelegate];
}

- (void)appStoreOpenedNoticeWithAppParam:(ApplilinkParameters *)appParam {
    if (self.adScreenViewController != nil) {
        return;
    }
    [ApplilinkCore toDelegateDidAppear:self.uniqueApplilinkParams delegate:self.uniqueAdDelegate];
}

- (void)appStoreCloseNoticeWithAppParam:(ApplilinkParameters *)appParam {
    // The binary's implementation is intentionally empty.
}

- (void)appStoreClosedNoticeWithAppParam:(ApplilinkParameters *)appParam {
    if (self.adScreenViewController != nil) {
        return;
    }
    id delegate;
    ApplilinkParameters *params = appParam;
    if (self.uniqueApplilinkParams != nil) {
        delegate = self.uniqueAdDelegate;
        params = self.uniqueApplilinkParams;
    } else {
        if (appParam == nil) {
            return;
        }
        delegate = self.applilinkDelegate;
    }
    [ApplilinkCore toDelegateDidDisappear:params delegate:delegate];
}

- (void)appStoreFailLoadNoticeWithError:(NSError *)error appParam:(ApplilinkParameters *)appParam {
    // A pending App Store deep link (recorded in urlString by -redirectWithRequest:appParam:) is
    // launched directly and short-circuits the delegate notification.
    if (self.urlString != nil) {
        NSURL *pendingUrl = [NSURL URLWithString:self.urlString];
        // The binary sends -setURL: to nil here, so it is a no-op kept for effect.
        [(NSMutableURLRequest *)nil setURL:pendingUrl];
        self.urlString = nil;
        if (pendingUrl != nil && [[UIApplication sharedApplication] canOpenURL:pendingUrl]) {
            [[UIApplication sharedApplication] openURL:pendingUrl];
            return;
        }
    }
    // The unique-advert path fails open; the advert-screen path fails the link. The appParam
    // argument is unused.
    if (self.adScreenViewController == nil) {
        [ApplilinkCore toDelegateFailOpenWithError:error
                                          appParam:self.uniqueApplilinkParams
                                          delegate:self.uniqueAdDelegate];
    } else {
        [ApplilinkCore toDelegateFailLinkWithError:error
                                          appParam:self.applilinkParams
                                          delegate:self.applilinkDelegate];
    }
}

- (void)appStoreTransitionNoticeWithAppParam:(ApplilinkParameters *)appParam {
    // The binary's implementation is intentionally empty.
}

@end
