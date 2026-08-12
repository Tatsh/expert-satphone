#import "RewardNetwork.h"

#import "ApplilinkConsts.h"
#import "ApplilinkCore.h"
#import "ApplilinkMessage.h"
#import "ApplilinkNetworkError.h"
#import "ApplilinkParameters.h"
#import "RewardCore.h"

// Applilink error codes messaged as the localised-error factory argument.
enum {
    kErrorSdkUnavailable = 0x401, // The SDK cannot run on this device.
    kErrorNotInitialized = 0x3f2, // The SDK has not finished initialising.
};

// The reward app-list navigation-bar title key, looked up in the reward message bundle.
static NSString *const kAppListTitleKey = @"RewardNetworkAppListTitle";

// The ad-display-status dictionary keys and their default values.
static NSString *const kStatusKeyAllInstallFlg = @"allInstallFlg";
static NSString *const kStatusKeyBannerDisplayStatus = @"bannerDisplayStatus";

@implementation RewardNetwork

/** @ghidraAddress 0x24f590 */
+ (void)openAdScreenWithAdLocation:(NSString *)adLocation
                       requestCode:(id)requestCode
                          delegate:(id)delegate {
    [RewardNetwork openAdScreenWithParentView:nil
                                   adLocation:adLocation
                                  requestCode:requestCode
                                     delegate:delegate];
}

/** @ghidraAddress 0x24f604 */
+ (void)openAdScreenWithParentView:(UIView *)parentView
                        adLocation:(NSString *)adLocation
                          delegate:(id)delegate {
    [RewardNetwork openAdScreenWithParentView:parentView
                                   adLocation:adLocation
                                  requestCode:nil
                                     delegate:delegate];
}

/** @ghidraAddress 0x24f678 */
+ (void)openAdScreenWithParentView:(UIView *)parentView
                        adLocation:(NSString *)adLocation
                       requestCode:(id)requestCode
                          delegate:(id)delegate {
    if (![ApplilinkConsts checkUseSDKWithAdModel:0
                                      adLocation:adLocation
                                   verticalAlign:0
                                     requestCode:requestCode
                                        delegate:delegate]) {
        return;
    }
    if ([RewardCore sharedInstance].initializeFlg == 0 && ![ApplilinkCore isInitializeStatusFlg]) {
        ApplilinkParameters *params = [[ApplilinkParameters alloc] init];
        [params setRequestWithAdModel:0 adLocation:adLocation requestCode:requestCode];
        [ApplilinkCore
            toDelegateFailOpenWithError:[ApplilinkNetworkError
                                            localizedApplilinkErrorWithCode:kErrorNotInitialized]
                               appParam:params
                               delegate:delegate];
        return;
    }
    [[RewardCore sharedInstance] openAdScreenWithParentView:parentView
                                                 adLocation:adLocation
                                                requestCode:requestCode
                                                   delegate:delegate];
}

/** @ghidraAddress 0x24f874 */
+ (void)closeAdScreen {
    if ([ApplilinkConsts canUseApplilinkSdk]) {
        [[RewardCore sharedInstance] closeAdScreen];
    }
}

/** @ghidraAddress 0x24f8ec */
+ (void)allInstallFlgWithCallback:(void (^)(NSInteger flg, NSError *error))callback {
    if (![ApplilinkConsts canUseApplilinkSdk]) {
        callback(0, [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorSdkUnavailable]);
        return;
    }
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
      /** @ghidraAddress 0x24f9dc */
      // Forward to the RewardCore all-install query on a background queue.
      [[RewardCore sharedInstance] allInstallFlgWithCallback:callback];
    });
}

/** @ghidraAddress 0x24fa4c */
+ (void)getAdDisplayStatusWithCallback:(void (^)(NSDictionary *status, NSError *error))callback {
    NSMutableDictionary *defaultStatus = [NSMutableDictionary dictionaryWithCapacity:2];
    [defaultStatus setValue:@(0) forKey:kStatusKeyAllInstallFlg];
    [defaultStatus setValue:@(0) forKey:kStatusKeyBannerDisplayStatus];
    if (![ApplilinkConsts canUseApplilinkSdk]) {
        callback(defaultStatus,
                 [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorSdkUnavailable]);
        return;
    }
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
      /** @ghidraAddress 0x24fc10 */
      // Forward to the RewardCore ad-display query on a background queue.
      [[RewardCore sharedInstance] getAdDisplayStatusWithCallback:callback];
    });
}

/** @ghidraAddress 0x24fc80 */
+ (void)getAdStatusWithBlock:(void (^)(NSInteger status, NSError *error))block {
    if (![ApplilinkConsts canUseApplilinkSdk]) {
        block(0, [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorSdkUnavailable]);
        return;
    }
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
      /** @ghidraAddress 0x24fd70 */
      // Forward to the RewardCore app-list status query on a background queue.
      [[RewardCore sharedInstance] getAppListStatusWithBlock:block];
    });
}

/** @ghidraAddress 0x24fde0 */
+ (void)setNavigationBarHidden:(BOOL)navigationBarHidden {
    [[RewardCore sharedInstance] setNavigationBarHidden:navigationBarHidden];
}

/** @ghidraAddress 0x24fe38 */
+ (NSString *)getNavigationTitle {
    return [ApplilinkMessage localizedMessage:kAppListTitleKey];
}

@end
