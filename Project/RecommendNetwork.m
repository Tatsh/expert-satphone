#import "RecommendNetwork.h"

#import "ApplilinkConsts.h"
#import "ApplilinkCore.h"
#import "ApplilinkNetworkError.h"
#import "ApplilinkParameters.h"

// The recommend SDK collaborators this facade forwards to. Not reconstructed in this tree yet, so
// they are forward-declared. See TYPES_PENDING.md.
@interface RecommendCore : NSObject
+ (instancetype)sharedInstance;
- (int)initializeFlg;
- (void)getAdStatusWithAdModel:(int)adModel callback:(nullable RecommendAdStatusCallback)callback;
- (void)getUnreadCountWithAdModel:(int)adModel
                       adLocation:(nullable NSString *)adLocation
                         callback:(nullable RecommendAdStatusCallback)callback;
- (void)getAdDisplayStatusWithAdModel:(int)adModel
                           adLocation:(nullable NSString *)adLocation
                             callback:(nullable RecommendAdDisplayStatusCallback)callback;
- (void)showOwnAdWithAdLocation:(nullable NSString *)adLocation
                      toAppliId:(nullable NSString *)appliId
                     creativeId:(nullable NSString *)creativeId;
- (void)showOwnAdWithAdLocation:(nullable NSString *)adLocation
                        adModel:(int)adModel
                      toAppliId:(nullable NSString *)appliId
                     creativeId:(nullable NSString *)creativeId;
- (void)touchOwnAdWithAdLocation:(nullable NSString *)adLocation
                       toAppliId:(nullable NSString *)appliId
                      creativeId:(nullable NSString *)creativeId
                     requestCode:(nullable id)requestCode
                        delegate:(nullable id)delegate;
- (void)touchOwnAdWithAdLocation:(nullable NSString *)adLocation
                         adModel:(int)adModel
                       toAppliId:(nullable NSString *)appliId
                      creativeId:(nullable NSString *)creativeId
                     requestCode:(nullable id)requestCode
                        delegate:(nullable id)delegate;
- (void)openAdScreenWithParentView:(nullable UIView *)parentView
                           adModel:(int)adModel
                        adLocation:(nullable NSString *)adLocation
                     verticalAlign:(int)verticalAlign
                       requestCode:(nullable id)requestCode
                          delegate:(nullable id)delegate;
- (void)openAdAreaWithParentView:(nullable UIView *)parentView
                            rect:(CGRect)rect
                         adModel:(int)adModel
                      adLocation:(nullable NSString *)adLocation
                   verticalAlign:(int)verticalAlign
                     requestCode:(nullable id)requestCode
                        delegate:(nullable id)delegate;
- (void)openFullViewControllerWithAdModel:(int)adModel
                               adLocation:(nullable NSString *)adLocation
                            verticalAlign:(int)verticalAlign
                              requestCode:(nullable id)requestCode
                                 delegate:(nullable id)delegate;
- (void)openMovieViewControllerWithAdModel:(int)adModel
                                adLocation:(nullable NSString *)adLocation
                             verticalAlign:(int)verticalAlign
                               requestCode:(nullable id)requestCode
                                  delegate:(nullable id)delegate;
- (void)closeAdScreen;
@end

@interface RecommendWebView : UIView
@end

@interface RecommendAdAreaView : UIView
- (void)closeAdArea;
@end

// Applilink error codes: the SDK-unavailable code when the SDK may not run at all, and the
// fail-open code when an open request is rejected because the SDK never finished initialising.
static const NSInteger kErrorSdkUnavailable = 0x401;
static const NSInteger kErrorOpenFailed = 0x3f2;

// The display-status dictionary keys and their zero placeholders on the SDK-unavailable path.
static NSString *const kUnreadCountKey = @"unreadCount";
static NSString *const kBannerDisplayStatusKey = @"bannerDisplayStatus";
static const int kUnreadCountNone = 0;
static const int kBannerDisplayStatusNone = 0;

// The vertical alignment the app-list, screen, and interstitial flows request; they do not expose
// it.
static const int kVerticalAlignDefault = 0;

@implementation RecommendNetwork

#pragma mark - Status queries

/** @ghidraAddress 0x23f588 */
+ (void)getAppListStatusWithCallback:(RecommendAdStatusCallback)callback {
    [self getAdStatusWithAdModel:RecommendAdModelAppList callback:callback];
}

/** @ghidraAddress 0x23f5a4 */
+ (void)getAdStatusWithAdModel:(RecommendAdModel)adModel
                      callback:(RecommendAdStatusCallback)callback {
    if (![ApplilinkConsts canUseApplilinkSdk]) {
        callback(0, [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorSdkUnavailable]);
        return;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      /** @ghidraAddress 0x23f6a0 */
      [[RecommendCore sharedInstance] getAdStatusWithAdModel:(int)adModel callback:callback];
    });
}

/** @ghidraAddress 0x23f714 */
+ (void)getUnreadCountWithAdModel:(RecommendAdModel)adModel
                       adLocation:(NSString *)adLocation
                         callback:(RecommendAdStatusCallback)callback {
    if (![ApplilinkConsts canUseApplilinkSdk]) {
        callback(0, [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorSdkUnavailable]);
        return;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      /** @ghidraAddress 0x23f83c */
      [[RecommendCore sharedInstance] getUnreadCountWithAdModel:(int)adModel
                                                     adLocation:adLocation
                                                       callback:callback];
    });
}

/** @ghidraAddress 0x23f8f4 */
+ (void)getAdDisplayStatusWithAdModel:(RecommendAdModel)adModel
                           adLocation:(NSString *)adLocation
                             callback:(RecommendAdDisplayStatusCallback)callback {
    if (![ApplilinkConsts canUseApplilinkSdk]) {
        NSMutableDictionary *status = [NSMutableDictionary dictionaryWithCapacity:2];
        [status setValue:@(kUnreadCountNone) forKey:kUnreadCountKey];
        [status setValue:@(kBannerDisplayStatusNone) forKey:kBannerDisplayStatusKey];
        callback(status,
                 [ApplilinkNetworkError localizedApplilinkErrorWithCode:kErrorSdkUnavailable]);
        return;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      /** @ghidraAddress 0x23faf0 */
      [[RecommendCore sharedInstance] getAdDisplayStatusWithAdModel:(int)adModel
                                                         adLocation:adLocation
                                                           callback:callback];
    });
}

#pragma mark - First-party adverts

/** @ghidraAddress 0x23fba8 */
+ (void)showOwnAdWithAdLocation:(NSString *)adLocation
                      toAppliId:(NSString *)appliId
                     creativeId:(NSString *)creativeId {
    if ([ApplilinkConsts canUseApplilinkSdk]) {
        [[RecommendCore sharedInstance] showOwnAdWithAdLocation:adLocation
                                                      toAppliId:appliId
                                                     creativeId:creativeId];
    }
}

/** @ghidraAddress 0x23fc6c */
+ (void)showOwnAdWithAdLocation:(NSString *)adLocation
                        adModel:(RecommendAdModel)adModel
                      toAppliId:(NSString *)appliId
                     creativeId:(NSString *)creativeId {
    if ([ApplilinkConsts canUseApplilinkSdk]) {
        [[RecommendCore sharedInstance] showOwnAdWithAdLocation:adLocation
                                                        adModel:(int)adModel
                                                      toAppliId:appliId
                                                     creativeId:creativeId];
    }
}

/** @ghidraAddress 0x23fd40 */
+ (void)touchOwnAdWithAdLocation:(NSString *)adLocation
                       toAppliId:(NSString *)appliId
                      creativeId:(NSString *)creativeId
                     requestCode:(id)requestCode
                        delegate:(id)delegate {
    if ([ApplilinkConsts checkUseSDKWithAdModel:(int)RecommendAdModelOwnAd
                                     adLocation:adLocation
                                  verticalAlign:kVerticalAlignDefault
                                    requestCode:requestCode
                                       delegate:delegate]) {
        [[RecommendCore sharedInstance] touchOwnAdWithAdLocation:adLocation
                                                       toAppliId:appliId
                                                      creativeId:creativeId
                                                     requestCode:requestCode
                                                        delegate:delegate];
    }
}

/** @ghidraAddress 0x23fe58 */
+ (void)touchOwnAdWithAdLocation:(NSString *)adLocation
                         adModel:(RecommendAdModel)adModel
                       toAppliId:(NSString *)appliId
                      creativeId:(NSString *)creativeId
                     requestCode:(id)requestCode
                        delegate:(id)delegate {
    if ([ApplilinkConsts checkUseSDKWithAdModel:(int)adModel
                                     adLocation:adLocation
                                  verticalAlign:kVerticalAlignDefault
                                    requestCode:requestCode
                                       delegate:delegate]) {
        [[RecommendCore sharedInstance] touchOwnAdWithAdLocation:adLocation
                                                         adModel:(int)adModel
                                                       toAppliId:appliId
                                                      creativeId:creativeId
                                                     requestCode:requestCode
                                                        delegate:delegate];
    }
}

#pragma mark - Application list

/** @ghidraAddress 0x23ff80 */
+ (void)openAppListWithAdLocation:(NSString *)adLocation delegate:(id)delegate {
    [self openAppListWithAdLocation:adLocation requestCode:nil delegate:delegate];
}

/** @ghidraAddress 0x23ffd8 */
+ (void)openAppListWithAdLocation:(NSString *)adLocation
                      requestCode:(id)requestCode
                         delegate:(id)delegate {
    if (![ApplilinkConsts checkUseSDKWithAdModel:(int)RecommendAdModelAppList
                                      adLocation:adLocation
                                   verticalAlign:kVerticalAlignDefault
                                     requestCode:requestCode
                                        delegate:delegate]) {
        return;
    }
    RecommendCore *core = [RecommendCore sharedInstance];
    if (core.initializeFlg == 0 && ![ApplilinkCore isInitializeStatusFlg]) {
        ApplilinkParameters *params = [[ApplilinkParameters alloc] init];
        [params setRequestWithAdModel:(int)RecommendAdModelAppList
                           adLocation:adLocation
                          requestCode:requestCode];
        [ApplilinkCore
            toDelegateFailOpenWithError:[ApplilinkNetworkError
                                            localizedApplilinkErrorWithCode:kErrorOpenFailed]
                               appParam:params
                               delegate:delegate];
        return;
    }
    [core openAdScreenWithParentView:nil
                             adModel:(int)RecommendAdModelAppList
                          adLocation:adLocation
                       verticalAlign:kVerticalAlignDefault
                         requestCode:requestCode
                            delegate:delegate];
}

#pragma mark - Advert screen

/** @ghidraAddress 0x2401c4 */
+ (void)openAdScreenWithAdModel:(RecommendAdModel)adModel
                     adLocation:(NSString *)adLocation
                       delegate:(id)delegate {
    [self openAdScreenWithAdModel:adModel adLocation:adLocation requestCode:nil delegate:delegate];
}

/** @ghidraAddress 0x240224 */
+ (void)openAdScreenWithAdModel:(RecommendAdModel)adModel
                     adLocation:(NSString *)adLocation
                    requestCode:(id)requestCode
                       delegate:(id)delegate {
    if (![ApplilinkConsts checkUseSDKWithAdModel:(int)adModel
                                      adLocation:adLocation
                                   verticalAlign:kVerticalAlignDefault
                                     requestCode:requestCode
                                        delegate:delegate]) {
        return;
    }
    RecommendCore *core = [RecommendCore sharedInstance];
    if (core.initializeFlg == 0 && ![ApplilinkCore isInitializeStatusFlg]) {
        ApplilinkParameters *params = [[ApplilinkParameters alloc] init];
        [params setRequestWithAdModel:(int)adModel adLocation:adLocation requestCode:requestCode];
        [ApplilinkCore
            toDelegateFailOpenWithError:[ApplilinkNetworkError
                                            localizedApplilinkErrorWithCode:kErrorOpenFailed]
                               appParam:params
                               delegate:delegate];
        return;
    }
    [core openAdScreenWithParentView:nil
                             adModel:(int)adModel
                          adLocation:adLocation
                       verticalAlign:kVerticalAlignDefault
                         requestCode:requestCode
                            delegate:delegate];
}

#pragma mark - Advert area

/** @ghidraAddress 0x240414 */
+ (void)openAdAreaWithParentView:(UIView *)parentView
                            rect:(CGRect)rect
                         adModel:(RecommendAdModel)adModel
                      adLocation:(NSString *)adLocation
                   verticalAlign:(int)verticalAlign
                        delegate:(id)delegate {
    [self openAdAreaWithParentView:parentView
                              rect:rect
                           adModel:adModel
                        adLocation:adLocation
                     verticalAlign:verticalAlign
                       requestCode:nil
                          delegate:delegate];
}

/** @ghidraAddress 0x2404d0 */
+ (void)openAdAreaWithParentView:(UIView *)parentView
                            rect:(CGRect)rect
                         adModel:(RecommendAdModel)adModel
                      adLocation:(NSString *)adLocation
                   verticalAlign:(int)verticalAlign
                     requestCode:(id)requestCode
                        delegate:(id)delegate {
    if (![ApplilinkConsts checkUseSDKWithAdModel:(int)adModel
                                      adLocation:adLocation
                                   verticalAlign:verticalAlign
                                     requestCode:requestCode
                                        delegate:delegate]) {
        return;
    }
    RecommendCore *core = [RecommendCore sharedInstance];
    if (core.initializeFlg == 0 && ![ApplilinkCore isInitializeStatusFlg]) {
        ApplilinkParameters *params = [[ApplilinkParameters alloc] init];
        [params setRequestWithAdModel:(int)adModel adLocation:adLocation requestCode:requestCode];
        [ApplilinkCore
            toDelegateFailOpenWithError:[ApplilinkNetworkError
                                            localizedApplilinkErrorWithCode:kErrorOpenFailed]
                               appParam:params
                               delegate:delegate];
        return;
    }
    [core openAdAreaWithParentView:parentView
                              rect:rect
                           adModel:(int)adModel
                        adLocation:adLocation
                     verticalAlign:verticalAlign
                       requestCode:requestCode
                          delegate:delegate];
}

#pragma mark - Interstitial

/** @ghidraAddress 0x240718 */
+ (void)openInterstitialWithAdLocation:(NSString *)adLocation delegate:(id)delegate {
    [self openInterstitialWithAdLocation:adLocation requestCode:nil delegate:delegate];
}

/** @ghidraAddress 0x240770 */
+ (void)openInterstitialWithAdLocation:(NSString *)adLocation
                           requestCode:(id)requestCode
                              delegate:(id)delegate {
    if (![ApplilinkConsts checkUseSDKWithAdModel:(int)RecommendAdModelInterstitial
                                      adLocation:adLocation
                                   verticalAlign:kVerticalAlignDefault
                                     requestCode:requestCode
                                        delegate:delegate]) {
        return;
    }
    RecommendCore *core = [RecommendCore sharedInstance];
    if (core.initializeFlg == 0 && ![ApplilinkCore isInitializeStatusFlg]) {
        ApplilinkParameters *params = [[ApplilinkParameters alloc] init];
        [params setRequestWithAdModel:(int)RecommendAdModelInterstitial
                           adLocation:adLocation
                          requestCode:requestCode];
        [ApplilinkCore
            toDelegateFailOpenWithError:[ApplilinkNetworkError
                                            localizedApplilinkErrorWithCode:kErrorOpenFailed]
                               appParam:params
                               delegate:delegate];
        return;
    }
    [core openFullViewControllerWithAdModel:(int)RecommendAdModelInterstitial
                                 adLocation:adLocation
                              verticalAlign:kVerticalAlignDefault
                                requestCode:requestCode
                                   delegate:delegate];
}

/** @ghidraAddress 0x240958 */
+ (void)openInterstitialMovieWithAdLocation:(NSString *)adLocation delegate:(id)delegate {
    [self openInterstitialMovieWithAdLocation:adLocation requestCode:nil delegate:delegate];
}

/** @ghidraAddress 0x2409b0 */
+ (void)openInterstitialMovieWithAdLocation:(NSString *)adLocation
                                requestCode:(id)requestCode
                                   delegate:(id)delegate {
    if (![ApplilinkConsts checkUseSDKWithAdModel:(int)RecommendAdModelInterstitial
                                      adLocation:adLocation
                                   verticalAlign:kVerticalAlignDefault
                                     requestCode:requestCode
                                        delegate:delegate]) {
        return;
    }
    RecommendCore *core = [RecommendCore sharedInstance];
    if (core.initializeFlg == 0 && ![ApplilinkCore isInitializeStatusFlg]) {
        ApplilinkParameters *params = [[ApplilinkParameters alloc] init];
        [params setRequestWithAdModel:(int)RecommendAdModelInterstitial
                           adLocation:adLocation
                          requestCode:requestCode];
        [ApplilinkCore
            toDelegateFailOpenWithError:[ApplilinkNetworkError
                                            localizedApplilinkErrorWithCode:kErrorOpenFailed]
                               appParam:params
                               delegate:delegate];
        return;
    }
    [core openMovieViewControllerWithAdModel:(int)RecommendAdModelInterstitial
                                  adLocation:adLocation
                               verticalAlign:kVerticalAlignDefault
                                 requestCode:requestCode
                                    delegate:delegate];
}

#pragma mark - Teardown

/** @ghidraAddress 0x240b98 */
+ (void)closeAdScreen {
    if ([ApplilinkConsts canUseApplilinkSdk]) {
        [[RecommendCore sharedInstance] closeAdScreen];
    }
}

/** @ghidraAddress 0x240c10 */
+ (void)closeAdAreaWithParentView:(UIView *)parentView {
    if (![ApplilinkConsts canUseApplilinkSdk]) {
        return;
    }
    UIView *host = parentView ?: [ApplilinkCore mainWindow];
    for (UIView *subview in host.subviews) {
        BOOL isWebView = [subview isKindOfClass:[RecommendWebView class]];
        BOOL isAreaView = [subview isKindOfClass:[RecommendAdAreaView class]];
        if (isWebView || isAreaView) {
            if (isAreaView) {
                [(RecommendAdAreaView *)subview closeAdArea];
            }
            [subview removeFromSuperview];
        }
    }
}

/** @ghidraAddress 0x240e54 */
+ (void)setAdAreaVisibleWithParentView:(UIView *)parentView flag:(BOOL)flag {
    if (![ApplilinkConsts canUseApplilinkSdk]) {
        return;
    }
    UIView *host = parentView ?: [ApplilinkCore mainWindow];
    for (UIView *subview in host.subviews) {
        BOOL isWebView = [subview isKindOfClass:[RecommendWebView class]];
        BOOL isAreaView = [subview isKindOfClass:[RecommendAdAreaView class]];
        if (isWebView || isAreaView) {
            subview.hidden = !flag;
        }
    }
}

@end
