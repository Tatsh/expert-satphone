#import "ApplilinkCore.h"

#include <sys/sysctl.h>

#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>

#import "AnalysisNetworkCore.h"
#import "ApplilinkConsts.h"
#import "ApplilinkNetworkError.h"
#import "ApplilinkUdid.h"
#import "ApplilinkViewManager.h"
#import "ApplilinkWebAPI.h"

// The reward and recommend cores the initialisation chain drives. Neither is reconstructed as its
// own file yet in this tree; only the selectors this class calls are declared. The full classes
// live in ../rbplus-src.
@interface RewardCore : NSObject
+ (instancetype)sharedInstance;
- (void)startWithCallback:(void (^)(NSError *error))callback;
- (void)clearInitialize;
@end

@interface RecommendCore : NSObject
+ (instancetype)sharedInstance;
- (void)startWithCallback:(void (^)(NSError *error))callback;
- (void)clearInitialize;
- (void)getAllAdStatusWithCallback:(void (^)(NSError *error))callback;
- (void)appliListWithCallBack:(void (^)(NSArray *list, NSError *error))callback;
@end

// The advert-delegate callbacks the fan-out methods dispatch through respondsToSelector:. In the
// binary the delegate is an id conforming to the SDK's advert-view delegate protocol; the selectors
// are gathered here so the messages type-check.
@protocol ApplilinkCoreAdDelegate <NSObject>
@optional
- (void)appListDidStart;
- (void)appListDidStart:(ApplilinkParameters *)appParam;
- (void)appListDidAppear;
- (void)appListDidAppear:(ApplilinkParameters *)appParam;
- (void)appListDidDisappear;
- (void)appListDidDisappear:(ApplilinkParameters *)appParam;
- (void)appListFailOpenWithError:(NSError *)error;
- (void)appListFailOpenWithError:(NSError *)error
         withApplilinkParameters:(ApplilinkParameters *)appParam;
- (void)appListFailLoadWithError:(NSError *)error;
- (void)appListFailLoadWithError:(NSError *)error
         withApplilinkParameters:(ApplilinkParameters *)appParam;
- (void)appListFailWithError:(NSError *)error;
- (void)appListFailWithError:(NSError *)error
     withApplilinkParameters:(ApplilinkParameters *)appParam;
- (void)appListFailLinkWithError:(NSError *)error;
- (void)appListFailLinkWithError:(NSError *)error
         withApplilinkParameters:(ApplilinkParameters *)appParam;
- (void)appListSoundUseStart;
- (void)appListSoundUseFinish;
- (void)appListMovieFinish;
@end

// Localised-error codes passed to +[ApplilinkNetworkError localizedApplilinkErrorWithCode:]. These
// mirror the file-local enumeration in ApplilinkNetworkError.m.
static const NSInteger kApplilinkErrorCodeParameter = 0x3e9;
static const NSInteger kApplilinkErrorCodeSdkVersionNotSupported = 0x401;
static const NSInteger kApplilinkErrorCodeInitializingError = 0x408;
static const NSInteger kApplilinkErrorCodeResumeExecutingError = 0x409;
static const NSInteger kApplilinkErrorCodeSession = 0x40e;

// The success sentinel returned by the session-regenerate endpoint in the error_code field.
static const int kApplilinkSessionSuccessCode = 100000000;

// How long, in seconds, a regenerated authentication session stays valid. Read from the pooled
// double at 0x28f258.
static const NSTimeInterval kApplilinkSessionValidDuration = 60.0;

// NSUserDefaults keys shared with ApplilinkConsts. Addresses are the CFString char-data pointers.
static NSString *const kApplilinkAppliIdKey = @"ApplilinkNetwork.appliId"; // 0x28ad78
static NSString *const kApplilinkEnvKey = @"ApplilinkNetwork.env";         // 0x28aecb
static NSString *const kApplilinkRewardReLoginFlgKey = @"ApplilinkReward.reLoginFlg";
static NSString *const kApplilinkRecommendReLoginFlgKey = @"ApplilinkRecommend.reLoginFlg";
static NSString *const kApplilinkRewardStorageIndexKey = @"ApplilinkReward.storageIndex";

// Keys read out of the SDK's UDID and session-response dictionaries.
static NSString *const kApplilinkUdidValueKey = @"Value";
static NSString *const kApplilinkResponseStatusKey = @"status";
static NSString *const kApplilinkResponseErrorCodeKey = @"error_code";

// The keychain service and storage index the advertising-UDID records are reset to on clear.
static NSString *const kApplilinkAdStorageService = @"adStorageIndex"; // 0x28c23d
static NSString *const kApplilinkAdStorageIndex = @"0";

// The default environment string. It is both the value substituted when no environment is supplied
// and the sentinel the clear methods compare against to decide whether a non-default environment is
// configured. The binary uses one shared literal at 0x27dc3a for both roles.
static NSString *const kApplilinkDefaultEnv = @"0";

// The path appended to the SSL base URL for the session-regenerate request.
static NSString *const kApplilinkSessionRegeneratePath =
    @"/app/auth/sessionRegenerate.php"; // 0x28c2cd
static NSString *const kApplilinkHTTPMethodGet = @"GET";
static const float kApplilinkSessionRequestTimeout = 10.0f;

// The Applilink SDK development version components. versionDev renders "<version>.<build>". The
// components are the CFStrings at 0x28ade1 (version) and 0x27dc3a (build); the "%@.%@" format is at
// 0x2880f0.
static NSString *const kApplilinkVersion = @"2.4.0";
static NSString *const kApplilinkVersionBuild = @"0";

// The Applilink SDK signature key, from the CFString at 0x28c24c.
static NSString *const kApplilinkSignatureKey = @"48PEnXUy8cbqKtmKb8leDhL3ayvbVdnOY0hf8YCALaIlPgcU3"
                                                @"EKP8qQrIKfdJo0XS3rrhTda7PzHbyRBAd8npfoSvjFoe5"
                                                @"L7ch1fs4jgnwe80ndjYGLq1UmAngjpAoOP";

// The format used to normalise the advertising UDID in setAdUdid:, at 0x27dd50.
static NSString *const kApplilinkStringFormat = @"%@";

// The %s format used to box each OpenGL C string in saveDeviceInfo, at 0x2812ea.
static NSString *const kApplilinkCStringFormat = @"%s";

// Device-info NSUserDefaults keys, matching the reader keys in ApplilinkUtilities.m.
static NSString *const kDeviceInfoGpuVendorKey = @"ApplilinkNetwork.opengl.vendor";
static NSString *const kDeviceInfoGpuRendererKey = @"ApplilinkNetwork.opengl.renderer";
static NSString *const kDeviceInfoGlVersionKey = @"ApplilinkNetwork.opengl.version";
static NSString *const kDeviceInfoPhysicalMemoryKey = @"ApplilinkNetwork.physmem";
static NSString *const kDeviceInfoWindowWidthKey = @"ApplilinkNetwork.winrectw";
static NSString *const kDeviceInfoWindowHeightKey = @"ApplilinkNetwork.winrecth";
static NSString *const kDeviceInfoWindowScaleKey = @"ApplilinkNetwork.winscale";
static NSString *const kDeviceInfoCpuCoresKey = @"ApplilinkNetwork.CPUCORES";

// The BSD sysctl selectors. getSysInfo: builds a two-level MIB of {CTL_HW, info}; getCpuFrequency
// and hwPhysMem build theirs inline. CTL_HW is 6; the HW_* selectors match <sys/sysctl.h>.
static const int kSysctlCtlHw = 6;
static const int kSysctlHwNCpu = 3;
static const int kSysctlHwPhysMem = 5;
static const int kSysctlHwCpuFrequency = 15;
static const u_int kSysctlHwMibLength = 2;

// The class carries no instance ivars: the whole SDK state is file scope. Each static keeps its
// original 32-bit contiguous block offset from 0x3542a0 as a documentation comment. The four flags
// gathered by the init/session code (init-in-progress, credentials-saved, session-valid, and the
// session expiry date) sit at the head of the block.
static BOOL sInitializingFlg;               // 0x3542a0
static BOOL sInitializeStatusFlg;           // 0x3542a1
static BOOL sSessionValid;                  // 0x3542a2
static BOOL sNavigationBarCommonAppearance; // 0x3542a3
static BOOL sPriorityDeviceLanguages;       // 0x3542a4
static BOOL sUsedInStore;                   // 0x3542a5
static BOOL sBuiltUnderXcode6;              // 0x3542a6
static BOOL sAdUdidResolved;                // 0x3542a7
static BOOL sUdidChecked;                   // 0x3542a8
static BOOL sReLoginPending;                // 0x3542a9
static BOOL sSoundUseStarted;               // 0x3542aa
static BOOL sMoviePlaying;                  // 0x3542ab
static NSDate *sSessionExpiry;              // 0x3542b0
static UIColor *sIndicatorColor;            // 0x3542b8
static NSString *sAdUdidCache;              // 0x3542c0
static NSString *sUdidCache;                // 0x3542c8
static NSString *sOldUdidCache;             // 0x3542d0
static NSString *sPasteBoardUdidCache;      // 0x3542d8

@implementation ApplilinkCore

#pragma mark - Initialisation

+ (void)initializeWithAppliId:(NSString *)appliId
                          env:(NSString *)env
                       resume:(BOOL)resume
                     callback:(void (^)(NSError *error))callback {
    [self saveDeviceInfo];
    if (![ApplilinkConsts canUseApplilinkSdk]) {
        if (callback) {
            callback([ApplilinkNetworkError
                localizedApplilinkErrorWithCode:kApplilinkErrorCodeSdkVersionNotSupported]);
        }
        return;
    }
    if (!appliId) {
        if (callback) {
            callback([ApplilinkNetworkError
                localizedApplilinkErrorWithCode:kApplilinkErrorCodeParameter]);
        }
        return;
    }
    if (sInitializingFlg) {
        if (callback) {
            NSInteger code = resume ? kApplilinkErrorCodeResumeExecutingError :
                                      kApplilinkErrorCodeInitializingError;
            callback([ApplilinkNetworkError localizedApplilinkErrorWithCode:code]);
        }
        return;
    }
    sInitializingFlg = YES;
    if (!resume) {
        [[NSUserDefaults standardUserDefaults] setObject:appliId forKey:kApplilinkAppliIdKey];
        [[NSUserDefaults standardUserDefaults] setObject:env forKey:kApplilinkEnvKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
        sInitializeStatusFlg = YES;
    }
    if (!env) {
        // The default environment is materialised but not captured; the block below captures only
        // the callback.
        env = [NSString stringWithString:kApplilinkDefaultEnv];
    }
    [self appAuthSessionRegenerateWithBlock:^(NSError *__attribute__((unused)) authError) {
      /** @ghidraAddress 0x2422c8 */
      // The auth error is intentionally ignored: initialisation proceeds to the reward core
      // regardless of a session-regeneration failure.
      [[RewardCore sharedInstance] startWithCallback:^(NSError *rewardError) {
        /** @ghidraAddress 0x242370 */
        if (rewardError && callback) {
            sInitializingFlg = NO;
            callback(rewardError);
            return;
        }
        [[RecommendCore sharedInstance] startWithCallback:^(NSError *recommendError) {
          /** @ghidraAddress 0x24245c */
          if (recommendError && callback) {
              sInitializingFlg = NO;
              callback(recommendError);
              return;
          }
          [AnalysisNetworkCore postAnalysisDataWithCallback:^(NSError *analysisError) {
            /** @ghidraAddress 0x24251c */
            if (callback) {
                callback(analysisError);
            }
            sInitializingFlg = NO;
            [[RecommendCore sharedInstance]
                getAllAdStatusWithCallback:^(NSError *__attribute__((unused)) adStatusError) {
                  /** @ghidraAddress 0x2425b8 */
                  // After the ad-status refresh, prefetch the installed-application list (its
                  // result is discarded — a warm-up of the appli-list cache).
                  [[RecommendCore sharedInstance]
                      appliListWithCallBack:^(NSArray *__attribute__((unused)) list,
                                              NSError *__attribute__((unused)) listError){
                          /** @ghidraAddress 0x242610 */
                      }];
                }];
          }];
        }];
      }];
    }];
}

+ (void)resume {
    [self closeAppStore];
    [[ApplilinkViewManager sharedInstance] closeVideoView];
    NSString *appliId = [ApplilinkConsts appliId];
    NSString *env = [ApplilinkConsts envServer];
    if (!appliId) {
        return;
    }
    if (!sSessionValid || !sSessionExpiry || [sSessionExpiry timeIntervalSinceNow] < 0.0) {
        sSessionValid = NO;
        [ApplilinkWebAPI setSessionStatus:NO];
    }
    [self initializeWithAppliId:appliId env:env resume:YES callback:nil];
}

+ (void)appAuthSessionRegenerateWithBlock:(void (^)(NSError *error))block {
    if (sSessionValid) {
        // Unlike initializeWithAppliId:…:callback:, this method invokes its block without a nil
        // check, so a nil block is a caller error rather than a no-op.
        block(nil);
        return;
    }
    NSString *url =
        [[ApplilinkConsts baseUrlSsl] stringByAppendingString:kApplilinkSessionRegeneratePath];
    [ApplilinkWebAPI requestAsynchronousWithURL:url
        method:kApplilinkHTTPMethodGet
        parameters:nil
        userInfo:nil
        tag:0
        cachePolicy:nil
        timeout:kApplilinkSessionRequestTimeout
        retry:NO
        finishedBlock:^(id __attribute__((unused)) request, id response) {
          /** @ghidraAddress 0x243ae8 */
          NSError *error = nil;
          if ([response isKindOfClass:[NSDictionary class]] &&
              [response[kApplilinkResponseStatusKey] boolValue] &&
              [response[kApplilinkResponseErrorCodeKey] intValue] == kApplilinkSessionSuccessCode) {
              sSessionValid = YES;
              sSessionExpiry =
                  [[NSDate date] dateByAddingTimeInterval:kApplilinkSessionValidDuration];
              block(nil);
          } else {
              error =
                  [ApplilinkNetworkError localizedApplilinkErrorWithCode:kApplilinkErrorCodeSession
                                                                userInfo:response];
              block(error);
          }
          // The stale-flag quirk of the binary: nothing here ever clears sSessionValid, so a
          // failure after an earlier success still reports YES to ApplilinkWebAPI.
          [ApplilinkWebAPI setSessionStatus:sSessionValid];
          [ApplilinkWebAPI setSessionConnectionWait:NO];
        }
        failedBlock:^(id __attribute__((unused)) request, NSError *error) {
          /** @ghidraAddress 0x243d30 */
          [ApplilinkWebAPI setSessionConnectionWait:NO];
          block(error);
        }];
}

+ (void)clearInitialize {
    [[RewardCore sharedInstance] clearInitialize];
    [[RecommendCore sharedInstance] clearInitialize];
    [AnalysisNetworkCore clearDAU];
    sInitializeStatusFlg = NO;
    sSessionValid = NO;
}

#pragma mark - Appearance configuration

+ (void)setNavigationBarCommonAppearance:(BOOL)navigationBarCommonAppearance {
    sNavigationBarCommonAppearance = navigationBarCommonAppearance;
}

+ (BOOL)isNavigationBarCommonAppearance {
    return sNavigationBarCommonAppearance;
}

+ (void)setPriorityDeviceLanguages:(BOOL)priorityDeviceLanguages {
    sPriorityDeviceLanguages = priorityDeviceLanguages;
}

+ (BOOL)isPriorityDeviceLanguages {
    return sPriorityDeviceLanguages;
}

+ (void)setIndicatorColor:(UIColor *)indicatorColor {
    sIndicatorColor = indicatorColor;
}

+ (UIColor *)getIndicatorColor {
    if (!sIndicatorColor) {
        return UIColor.whiteColor;
    }
    return sIndicatorColor;
}

#pragma mark - Build and store flags

+ (void)unusedInStore {
    // Yes, the binary's unusedInStore sets the used-in-store flag.
    sUsedInStore = YES;
}

+ (BOOL)isUsedInStore {
    return sUsedInStore;
}

+ (void)buildUnderXcode6 {
    sBuiltUnderXcode6 = YES;
}

+ (BOOL)isBuildXcode6 {
    // Yes, the binary returns the inverse of the flag buildUnderXcode6 sets.
    return !sBuiltUnderXcode6;
}

#pragma mark - Window and status

+ (UIWindow *)mainWindow {
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (![keyWindow isMemberOfClass:[UIWindow class]]) {
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (![window isKindOfClass:NSClassFromString(@"_UIModalItemHostingWindow")] &&
                [window isMemberOfClass:[UIWindow class]]) {
                return window;
            }
        }
    }
    return [UIApplication sharedApplication].keyWindow;
}

+ (BOOL)isInitializingFlg {
    return sInitializingFlg;
}

+ (BOOL)isInitializeStatusFlg {
    return sInitializeStatusFlg;
}

+ (NSString *)appliId {
    return [[NSUserDefaults standardUserDefaults] objectForKey:kApplilinkAppliIdKey];
}

#pragma mark - UDID accessors

+ (NSString *)currentUdid {
    if (!sAdUdidCache && !sUdidCache && !sOldUdidCache) {
        return nil;
    }
    if ([ApplilinkUdid isAdvertisingTrackingOSVersion]) {
        return sAdUdidCache;
    }
    if (sUdidCache) {
        return sUdidCache;
    }
    return sOldUdidCache;
}

+ (NSString *)udid_cache {
    return sUdidCache;
}

+ (NSString *)ad_udid_cache {
    return sAdUdidCache;
}

+ (NSString *)old_udid_cache {
    return sOldUdidCache;
}

+ (NSString *)udid {
    if (![ApplilinkConsts canUseApplilinkSdk]) {
        return nil;
    }
    if (sUdidCache || sAdUdidResolved) {
        return sUdidCache;
    }
    NSError *error = nil;
    NSDictionary *record = [ApplilinkUdid udidForFirstInvalidDataWithError:&error];
    if (record) {
        sUdidCache = record[kApplilinkUdidValueKey];
        return sUdidCache;
    }
    (void)[ApplilinkUdid isAdvertisingTrackingOSVersion]; // Yes, the binary discards this result.
    if ([self ad_udid]) {
        sAdUdidResolved = YES;
    }
    sUdidChecked = YES;
    return sUdidCache;
}

+ (NSString *)pasteBoard_udid {
    if (![ApplilinkConsts canUseApplilinkSdk]) {
        return nil;
    }
    if (sPasteBoardUdidCache || sUdidChecked) {
        return sPasteBoardUdidCache;
    }
    NSError *error = nil;
    NSDictionary *record = [ApplilinkUdid udidOldForFirstInvalidDataWithError:&error];
    if (record) {
        sPasteBoardUdidCache = record[kApplilinkUdidValueKey];
        return sPasteBoardUdidCache;
    }
    (void)[ApplilinkUdid isAdvertisingTrackingOSVersion]; // Yes, the binary discards this result.
    sUdidChecked = YES;
    return sPasteBoardUdidCache;
}

+ (NSString *)ad_udid {
    if (![ApplilinkConsts canUseApplilinkSdk]) {
        return nil;
    }
    if (sAdUdidCache) {
        return sAdUdidCache;
    }
    if (![ApplilinkUdid isAdvertisingTrackingOSVersion]) {
        return nil;
    }
    NSError *error = nil;
    sAdUdidCache = [ApplilinkUdid getAdvertisingRewardUdidWithError:&error];
    if ([sAdUdidCache isEqualToString:[ApplilinkUdid getAdvertisingUdid]]) {
        return sAdUdidCache;
    }
    sReLoginPending = YES;
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kApplilinkRewardReLoginFlgKey];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kApplilinkRecommendReLoginFlgKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    return sAdUdidCache;
}

+ (NSString *)old_udid {
    if (![ApplilinkConsts canUseApplilinkSdk]) {
        return nil;
    }
    if (sOldUdidCache) {
        return sOldUdidCache;
    }
    NSError *error = nil;
    sOldUdidCache = [ApplilinkUdid getOldUdidWithError:&error];
    return sOldUdidCache;
}

+ (BOOL)checkUdid {
    NSString *udid = [self udid];
    NSString *adUdid = [self ad_udid];
    return udid != nil || adUdid != nil;
}

#pragma mark - UDID maintenance

+ (void)clearUDID {
    NSString *env = [ApplilinkConsts envServer];
    if (env && ![env isEqualToString:kApplilinkDefaultEnv]) {
        [ApplilinkUdid deleteAllUDID];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kApplilinkRewardStorageIndexKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [self clearInitialize];
    }
    sUdidCache = nil;
    sAdUdidResolved = NO;
}

+ (void)setAdUdid:(NSString *)adUdid {
    sAdUdidCache = [NSString stringWithFormat:kApplilinkStringFormat, adUdid];
    sOldUdidCache = nil;
}

+ (void)clearKeyChainOldUDID {
    NSString *env = [ApplilinkConsts envServer];
    if (env && ![env isEqualToString:kApplilinkDefaultEnv]) {
        NSError *error = nil;
        [ApplilinkUdid deleteOldUdidWithError:&error];
    }
    NSString *adUdid = [ApplilinkCore ad_udid];
    NSString *udid = [ApplilinkCore udid];
    NSString *oldUdid = [ApplilinkCore old_udid];
    if (!adUdid && !udid && !oldUdid) {
        [self clearInitialize];
    }
    sOldUdidCache = nil;
}

+ (void)clearAdUDID {
    NSString *env = [ApplilinkConsts envServer];
    if (env && ![env isEqualToString:kApplilinkDefaultEnv]) {
        [ApplilinkUdid deleteAllAdvertisingUDID];
        [ApplilinkUdid setService:kApplilinkAdStorageService
                 withStorageIndex:kApplilinkAdStorageIndex];
        [self clearInitialize];
    }
    sAdUdidCache = nil;
}

+ (void)updatePasteBoard {
    if (!sReLoginPending) {
        return;
    }
    NSString *udid = [ApplilinkCore currentUdid];
    if (udid) {
        [ApplilinkUdid writeUDIDForFirstEmptyLocationWithUdid:udid];
        sReLoginPending = NO;
    }
}

#pragma mark - Store

+ (BOOL)showAppStoreId:(NSString *)appStoreId
              appParam:(ApplilinkParameters *)appParam
              delegate:(id<SdkViewDelegate>)delegate {
    if ([ApplilinkCore isUsedInStore] || [appStoreId length] == 0) {
        return NO;
    }
    return [[ApplilinkStore sharedInstance] showSKStore:appStoreId
                                               appParam:appParam
                                               delegate:delegate];
}

+ (void)closeAppStore {
    [[ApplilinkStore sharedInstance] closeSKStore];
}

#pragma mark - Metadata

+ (NSString *)signatureKey {
    return kApplilinkSignatureKey;
}

+ (NSString *)versionDev {
    return [NSString stringWithFormat:@"%@.%@", kApplilinkVersion, kApplilinkVersionBuild];
}

#pragma mark - Delegate fan-out

+ (void)toDelegateDidStart:(ApplilinkParameters *)appParam delegate:(id)delegate {
    id<ApplilinkCoreAdDelegate> adDelegate = delegate;
    if (!adDelegate) {
        return;
    }
    if ([adDelegate respondsToSelector:@selector(appListDidStart:)] && [appParam requestCode]) {
        [adDelegate appListDidStart:appParam];
    } else if ([adDelegate respondsToSelector:@selector(appListDidStart)]) {
        [adDelegate appListDidStart];
    }
}

+ (void)toDelegateDidAppear:(ApplilinkParameters *)appParam delegate:(id)delegate {
    id<ApplilinkCoreAdDelegate> adDelegate = delegate;
    if (!adDelegate) {
        return;
    }
    if ([adDelegate respondsToSelector:@selector(appListDidAppear:)] && [appParam requestCode]) {
        [adDelegate appListDidAppear:appParam];
    } else if ([adDelegate respondsToSelector:@selector(appListDidAppear)]) {
        [adDelegate appListDidAppear];
    }
}

+ (void)toDelegateDidDisappear:(ApplilinkParameters *)appParam delegate:(id)delegate {
    id<ApplilinkCoreAdDelegate> adDelegate = delegate;
    if (!adDelegate) {
        return;
    }
    if ([adDelegate respondsToSelector:@selector(appListDidDisappear:)] && [appParam requestCode]) {
        [adDelegate appListDidDisappear:appParam];
    } else if ([adDelegate respondsToSelector:@selector(appListDidDisappear)]) {
        [adDelegate appListDidDisappear];
    }
}

+ (void)toDelegateFailOpenWithError:(NSError *)error
                           appParam:(ApplilinkParameters *)appParam
                           delegate:(id)delegate {
    id<ApplilinkCoreAdDelegate> adDelegate = delegate;
    if (!adDelegate) {
        return;
    }
    if ([adDelegate
            respondsToSelector:@selector(appListFailOpenWithError:withApplilinkParameters:)] &&
        [appParam requestCode]) {
        [adDelegate appListFailOpenWithError:error withApplilinkParameters:appParam];
    } else if ([adDelegate respondsToSelector:@selector(appListFailOpenWithError:)]) {
        [adDelegate appListFailOpenWithError:error];
    }
    [self toDelegateFailWithError:error appParam:appParam delegate:delegate];
}

+ (void)toDelegateFailLoadWithError:(NSError *)error
                           appParam:(ApplilinkParameters *)appParam
                           delegate:(id)delegate {
    id<ApplilinkCoreAdDelegate> adDelegate = delegate;
    if (!adDelegate) {
        return;
    }
    if ([adDelegate
            respondsToSelector:@selector(appListFailLoadWithError:withApplilinkParameters:)] &&
        [appParam requestCode]) {
        [adDelegate appListFailLoadWithError:error withApplilinkParameters:appParam];
    } else if ([adDelegate respondsToSelector:@selector(appListFailLoadWithError:)]) {
        [adDelegate appListFailLoadWithError:error];
    }
    [self toDelegateFailWithError:error appParam:appParam delegate:delegate];
}

+ (void)toDelegateFailWithError:(NSError *)error
                       appParam:(ApplilinkParameters *)appParam
                       delegate:(id)delegate {
    id<ApplilinkCoreAdDelegate> adDelegate = delegate;
    if (!adDelegate) {
        return;
    }
    if ([adDelegate respondsToSelector:@selector(appListFailWithError:withApplilinkParameters:)] &&
        [appParam requestCode]) {
        [adDelegate appListFailWithError:error withApplilinkParameters:appParam];
    } else if ([adDelegate respondsToSelector:@selector(appListFailWithError:)]) {
        [adDelegate appListFailWithError:error];
    }
}

+ (void)toDelegateFailLinkWithError:(NSError *)error
                           appParam:(ApplilinkParameters *)appParam
                           delegate:(id)delegate {
    id<ApplilinkCoreAdDelegate> adDelegate = delegate;
    if (!adDelegate) {
        return;
    }
    if ([adDelegate
            respondsToSelector:@selector(appListFailLinkWithError:withApplilinkParameters:)] &&
        [appParam requestCode]) {
        [adDelegate appListFailLinkWithError:error withApplilinkParameters:appParam];
    } else if ([adDelegate respondsToSelector:@selector(appListFailLinkWithError:)]) {
        [adDelegate appListFailLinkWithError:error];
    }
}

+ (void)toDelegateSoundUseStart:(id)delegate {
    id<ApplilinkCoreAdDelegate> adDelegate = delegate;
    if (!adDelegate) {
        return;
    }
    if ([adDelegate respondsToSelector:@selector(appListSoundUseStart)]) {
        sSoundUseStarted = YES;
        sMoviePlaying = YES;
        [adDelegate appListSoundUseStart];
    }
}

+ (void)toDelegateSoundUseFinish:(id)delegate {
    id<ApplilinkCoreAdDelegate> adDelegate = delegate;
    if (!adDelegate || !sSoundUseStarted) {
        return;
    }
    if ([adDelegate respondsToSelector:@selector(appListSoundUseFinish)]) {
        sSoundUseStarted = NO;
        [adDelegate appListSoundUseFinish];
    }
}

+ (void)toDelegateMovieFinish:(id)delegate {
    id<ApplilinkCoreAdDelegate> adDelegate = delegate;
    if (!adDelegate || !sMoviePlaying) {
        return;
    }
    if ([adDelegate respondsToSelector:@selector(appListMovieFinish)]) {
        sMoviePlaying = NO;
        [adDelegate appListMovieFinish];
    }
}

#pragma mark - Device information

+ (void)collectDeviceInfoCore {
    [ApplilinkCore saveDeviceInfo];
    [AnalysisNetworkCore
        postAnalysisDeviceDataWithActionType:^(NSError *__attribute__((unused)) error){
            /** @ghidraAddress 0x2446a0 */
            // A no-op completion handler; the analytics post's result is not observed here.
        }];
}

+ (void)saveDeviceInfo {
    if (![EAGLContext currentContext]) {
        return;
    }
    const GLubyte *vendor = glGetString(GL_VENDOR);
    const GLubyte *renderer = glGetString(GL_RENDERER);
    const GLubyte *version = glGetString(GL_VERSION);
    CGRect bounds = [UIScreen mainScreen].bounds;
    CGFloat scale = [UIScreen mainScreen].scale;
    int numCpus = [self getNumCpus];
    long long physMem = [self hwPhysMem];
    NSString *vendorString = [NSString stringWithFormat:kApplilinkCStringFormat, vendor];
    NSString *rendererString = [NSString stringWithFormat:kApplilinkCStringFormat, renderer];
    NSString *versionString = [NSString stringWithFormat:kApplilinkCStringFormat, version];
    NSNumber *physMemNumber = @(physMem);
    NSNumber *widthNumber = @((int)bounds.size.width);
    NSNumber *heightNumber = @((int)bounds.size.height);
    NSNumber *scaleNumber = @((int)scale);
    NSNumber *cpuCoresNumber = @(numCpus);
    if (vendor) {
        [[NSUserDefaults standardUserDefaults] setObject:vendorString
                                                  forKey:kDeviceInfoGpuVendorKey];
    }
    if (renderer) {
        [[NSUserDefaults standardUserDefaults] setObject:rendererString
                                                  forKey:kDeviceInfoGpuRendererKey];
    }
    if (version) {
        [[NSUserDefaults standardUserDefaults] setObject:versionString
                                                  forKey:kDeviceInfoGlVersionKey];
    }
    if (physMem) {
        [[NSUserDefaults standardUserDefaults] setObject:physMemNumber
                                                  forKey:kDeviceInfoPhysicalMemoryKey];
    }
    if (bounds.size.width != 0.0) {
        [[NSUserDefaults standardUserDefaults] setObject:widthNumber
                                                  forKey:kDeviceInfoWindowWidthKey];
    }
    if (bounds.size.height != 0.0) {
        [[NSUserDefaults standardUserDefaults] setObject:heightNumber
                                                  forKey:kDeviceInfoWindowHeightKey];
    }
    if (scale != 0.0) {
        [[NSUserDefaults standardUserDefaults] setObject:scaleNumber
                                                  forKey:kDeviceInfoWindowScaleKey];
    }
    if (numCpus) {
        [[NSUserDefaults standardUserDefaults] setObject:cpuCoresNumber
                                                  forKey:kDeviceInfoCpuCoresKey];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (NSDictionary *)getDeviceInfo {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *vendor = [defaults stringForKey:kDeviceInfoGpuVendorKey];
    NSString *renderer = [defaults stringForKey:kDeviceInfoGpuRendererKey];
    NSString *version = [defaults stringForKey:kDeviceInfoGlVersionKey];
    NSNumber *physMem = [defaults objectForKey:kDeviceInfoPhysicalMemoryKey];
    NSNumber *width = [defaults objectForKey:kDeviceInfoWindowWidthKey];
    NSNumber *height = [defaults objectForKey:kDeviceInfoWindowHeightKey];
    NSNumber *scale = [defaults objectForKey:kDeviceInfoWindowScaleKey];
    NSNumber *cpuCores = [defaults objectForKey:kDeviceInfoCpuCoresKey];
    NSMutableDictionary *deviceInfo = [NSMutableDictionary dictionary];
    if (vendor) {
        deviceInfo[kDeviceInfoGpuVendorKey] = vendor;
    }
    if (renderer) {
        deviceInfo[kDeviceInfoGpuRendererKey] = renderer;
    }
    if (version) {
        deviceInfo[kDeviceInfoGlVersionKey] = version;
    }
    if (physMem) {
        deviceInfo[kDeviceInfoPhysicalMemoryKey] = physMem;
    }
    if (width) {
        deviceInfo[kDeviceInfoWindowWidthKey] = width;
    }
    if (height) {
        deviceInfo[kDeviceInfoWindowHeightKey] = height;
    }
    if (scale) {
        deviceInfo[kDeviceInfoWindowScaleKey] = scale;
    }
    if (cpuCores) {
        deviceInfo[kDeviceInfoCpuCoresKey] = cpuCores;
    }
    return deviceInfo;
}

+ (int)getSysInfo:(int)info {
    int mib[] = {kSysctlCtlHw, info};
    int value = 0;
    size_t length = sizeof(value);
    sysctl(mib, kSysctlHwMibLength, &value, &length, nullptr, 0);
    return value;
}

+ (int)getCpuFrequency {
    int mib[] = {kSysctlCtlHw, kSysctlHwCpuFrequency};
    int value = 0;
    size_t length = sizeof(value);
    sysctl(mib, kSysctlHwMibLength, &value, &length, nullptr, 0);
    return value;
}

+ (int)getNumCpus {
    return [self getSysInfo:kSysctlHwNCpu];
}

+ (NSInteger)hwPhysMem {
    int mib[] = {kSysctlCtlHw, kSysctlHwPhysMem};
    long long value = 0;
    size_t length = sizeof(value);
    if (sysctl(mib, kSysctlHwMibLength, &value, &length, nullptr, 0) != 0) {
        value = -1;
    }
    return value;
}

@end
