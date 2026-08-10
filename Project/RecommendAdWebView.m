#import "RecommendAdWebView.h"

#import "ApplilinkConsts.h"
#import "ApplilinkCore.h"
#import "ApplilinkNetworkError.h"
#import "ApplilinkParameters.h"
#import "ApplilinkUdid.h"
#import "ApplilinkUtilities.h"
#import "ApplilinkViewManager.h"
#import "RecommendCore.h"
#import "RecommendWebAPI.h"

// Applilink error codes reported through appListFailLoadWithError:.
enum {
    kRecommendAdWebViewErrorSdkUnavailable = 0x401,     // The SDK is not usable here.
    kRecommendAdWebViewErrorAdTrackingDisabled = 0x404, // Advertising tracking is disabled.
    kRecommendAdWebViewErrorNoAd = 0x40a,               // No recommend advert is available.
    kRecommendAdWebViewErrorLoadCancelled = 0x40b,      // The advert load was cancelled.
};

// Banner-detail status returned by RecommendWebAPI getBannerDetailWithAdModel:callback:; only this
// value continues the load.
enum {
    kRecommendAdWebViewBannerStatusHasAd = 1,
};

// Web-view load status stored in webViewStatus.
enum {
    kRecommendAdWebViewStatusIdle = 0,
    kRecommendAdWebViewStatusStarted = 1,
    kRecommendAdWebViewStatusFinished = 2,
};

// Advert models whose banner enables free scrolling; adModel 5 additionally takes the extra
// appliListWithParameters: round trip before loading the external page.
enum {
    kRecommendAdWebViewAdModelScrollableBanner = 1,
    kRecommendAdWebViewAdModelScrollableInterstitial = 4,
    kRecommendAdWebViewAdModelExternalList = 5,
};

// UIWebView cancellation and policy-change error codes ignored during the advert load.
enum {
    kRecommendAdWebViewWebKitFrameLoadInterrupted = 102,     // 0x66
    kRecommendAdWebViewWebKitPlugInWillHandleLoad = 204,     // 0xcc
    kRecommendAdWebViewURLErrorCancelled = -999,             // NSURLErrorCancelled
    kRecommendAdWebViewURLErrorFrameLoadInterrupted = -1009, // reported as a link failure
};

// The intercepted movie link's host and its scheme prefix, port, and full-URL prefix.
static NSString *const kRecommendAdWebViewSchemePrefix = @"applilink";
static NSString *const kRecommendAdWebViewMovieHost = @"ext-app";
static const int kRecommendAdWebViewMoviePort = 80;
static NSString *const kRecommendAdWebViewMoviePrefix = @"applilink://ext-app:80/movie";

// The custom-scheme close commands.
static NSString *const kRecommendAdWebViewCloseCommand = @"close";
static NSString *const kRecommendAdWebViewCloseCommandPrefix = @"close/";

// The substring in a finished page's query that signals dismissal back to native code.
static NSString *const kRecommendAdWebViewFinishCloseQuery = @"command=close";

// The external advert page appended to the SSL base URL for a live advert load.
static NSString *const kRecommendAdWebViewExternalAdPath = @"/ad/external/index.php";

// The ad-request parameter keys and the constant is_sdk value.
static NSString *const kRecommendAdWebViewParamIsSdk = @"is_sdk";
static NSString *const kRecommendAdWebViewParamIsSdkValue = @"1";
static NSString *const kRecommendAdWebViewParamAdLocation = @"ad_location";
static NSString *const kRecommendAdWebViewParamAdModel = @"ad_model";
static NSString *const kRecommendAdWebViewParamVerticalAlign = @"vertical_align";
static NSString *const kRecommendAdWebViewParamInstallAdIdList = @"install_ad_id_list";

// The cached advertised-app dictionary keys probed for already-installed apps.
static NSString *const kRecommendAdWebViewEntryDefaultScheme = @"default_scheme";
static NSString *const kRecommendAdWebViewEntryAdId = @"ad_id";

// Web-view request timeout, in seconds, for advert loads. Reaches the code as an fmov immediate
// 0x403e000000000000 at 0x247000 rather than a pooled constant.
static const NSTimeInterval kRecommendAdWebViewTimeout = 30.0;

// The ad-request parameter dictionary's initial capacity.
static const NSUInteger kRecommendAdWebViewParamCapacity = 5;

// Stage 5 (terminal) of loadRequest for adModel 5, de-inlined from the appliListWithParameters:
// callBack: block at 0x246054. Loads the external advert page if the server returned a non-empty
// list.
static inline void RecommendAdWebViewLoadExternalAdPage(RecommendAdWebView *self,
                                                        NSArray *appliList,
                                                        NSDictionary *parameters,
                                                        NSError *error) {
    if (error != nil) {
        self.loadComplete = YES;
        [self appListFailLoadWithError:error];
        return;
    }
    if (self.cancelFlg) {
        self.loadComplete = YES;
        [self appListFailLoadWithError:
                  [ApplilinkNetworkError
                      localizedApplilinkErrorWithCode:kRecommendAdWebViewErrorLoadCancelled]];
        return;
    }
    // Only the list's emptiness is tested; its contents are consumed server-side.
    if (appliList != nil && appliList.count != 0) {
        self.loadComplete = YES;
        NSString *url =
            [ApplilinkConsts.baseUrlSsl stringByAppendingString:kRecommendAdWebViewExternalAdPath];
        [self loadRequestWithURL:url parameters:parameters];
        return;
    }
    self.loadComplete = YES;
    [self
        appListFailLoadWithError:[ApplilinkNetworkError
                                     localizedApplilinkErrorWithCode:kRecommendAdWebViewErrorNoAd]];
}

// Stage 4 of loadRequest, de-inlined from the appliListCacheWithCallBack: block at 0x245a2c. Works
// out which advertised apps are already installed, builds the ad-request parameter dictionary, and
// dispatches the final load.
static inline void RecommendAdWebViewBuildAdRequestParameters(RecommendAdWebView *self,
                                                              NSArray *appliList,
                                                              NSError *error) {
    if (error != nil) {
        self.loadComplete = YES;
        [self appListFailLoadWithError:error];
        return;
    }
    if (self.cancelFlg) {
        self.loadComplete = YES;
        [self appListFailLoadWithError:
                  [ApplilinkNetworkError
                      localizedApplilinkErrorWithCode:kRecommendAdWebViewErrorLoadCancelled]];
        return;
    }
    NSMutableArray *installedAdIds = [[NSMutableArray alloc] init];
    for (id entry in appliList) {
        if (![entry isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        id scheme = entry[kRecommendAdWebViewEntryDefaultScheme];
        id adId = entry[kRecommendAdWebViewEntryAdId];
        if (![scheme isKindOfClass:[NSString class]]) {
            continue;
        }
        if ([[RecommendCore sharedInstance] isInstalledAppliWithScheme:scheme] && adId != nil) {
            [installedAdIds addObject:adId];
        }
    }
    NSMutableDictionary *parameters =
        [NSMutableDictionary dictionaryWithCapacity:kRecommendAdWebViewParamCapacity];
    [parameters setValue:kRecommendAdWebViewParamIsSdkValue forKey:kRecommendAdWebViewParamIsSdk];
    if (self.adLocation != nil) {
        [parameters setValue:self.adLocation forKey:kRecommendAdWebViewParamAdLocation];
    }
    if (self.adModel != 0) {
        [parameters setValue:[NSString stringWithFormat:@"%d", self.adModel]
                      forKey:kRecommendAdWebViewParamAdModel];
    }
    if (self.verticalAlign != 0) {
        [parameters setValue:[NSString stringWithFormat:@"%d", self.verticalAlign]
                      forKey:kRecommendAdWebViewParamVerticalAlign];
    }
    if (installedAdIds.count != 0) {
        parameters[kRecommendAdWebViewParamInstallAdIdList] = installedAdIds;
    }
    if (self.adModel == kRecommendAdWebViewAdModelExternalList) {
        RecommendAdWebView *blockSelf = self;
        [RecommendWebAPI appliListWithParameters:parameters
                                        callBack:^(id externalList, NSError *listError) {
                                          /** @ghidraAddress 0x246054 */
                                          RecommendAdWebViewLoadExternalAdPage(
                                              blockSelf, externalList, parameters, listError);
                                        }];
    } else {
        self.loadComplete = YES;
        NSString *url =
            [ApplilinkConsts.baseUrlSsl stringByAppendingString:kRecommendAdWebViewExternalAdPath];
        [self loadRequestWithURL:url parameters:parameters];
    }
}

@implementation RecommendAdWebView

#pragma mark - Initialisation

/** @ghidraAddress 0x245058 */
- (instancetype)init {
    self = [super init];
    if (self) {
        [self setInitParam];
    }
    return self;
}

/** @ghidraAddress 0x2450bc */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setInitParam];
    }
    return self;
}

/** @ghidraAddress 0x245120 */
- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self setInitParam];
    }
    return self;
}

/** @ghidraAddress 0x245184 */
- (void)setInitParam {
    self.backgroundColor = UIColor.clearColor;
    self.opaque = NO;
    self.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
                            UIViewAutoresizingFlexibleRightMargin |
                            UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleHeight |
                            UIViewAutoresizingFlexibleBottomMargin;
    self.contentMode = UIViewContentModeScaleAspectFit;
    _loadComplete = YES;
    _reloadFlg = NO;
    _cancelFlg = NO;
    _scrollFlg = NO;
}

#pragma mark - Teardown

/** @ghidraAddress 0x245260 */
- (void)removeFromSuperview {
    _cancelFlg = YES;
    [self unloadRecommendView];
    if (_applilinkDelegate) {
        _applilinkDelegate = nil;
    }
    if (self.delegate) {
        self.delegate = nil;
    }
    [super removeFromSuperview];
}

/** @ghidraAddress 0x247954 */
- (void)dealloc {
    if (_applilinkDelegate) {
        _applilinkDelegate = nil;
    }
    if (self.delegate) {
        self.delegate = nil;
    }
}

#pragma mark - Loading

/** @ghidraAddress 0x24533c */
- (void)loadRequestWithAdModel:(int)adModel
                    adLocation:(NSString *)adLocation
                 verticalAlign:(int)verticalAlign
                   requestCode:(id)requestCode
                      delegate:(id<ApplilinkViewDelegate>)delegate {
    _adModel = adModel;
    if (adLocation == nil) {
        _adLocation = nil;
    } else {
        _adLocation = [NSString stringWithFormat:@"%@", adLocation];
    }
    _verticalAlign = verticalAlign;
    _requestCode = requestCode;
    _applilinkDelegate = delegate;
    if (adModel == kRecommendAdWebViewAdModelScrollableBanner ||
        adModel == kRecommendAdWebViewAdModelScrollableInterstitial) {
        [self setScrollEnabled:YES];
    } else {
        if (!_scrollFlg) {
            [self setScrollBoundsEnabled:NO];
        }
        [self setScrollBarEnabled:NO];
    }
    [self loadRequest];
}

/** @ghidraAddress 0x2454c4 */
- (void)loadRequest {
    _webViewStatus = kRecommendAdWebViewStatusIdle;
    if (!ApplilinkConsts.canUseApplilinkSdk) {
        [self appListFailLoadWithError:
                  [ApplilinkNetworkError
                      localizedApplilinkErrorWithCode:kRecommendAdWebViewErrorSdkUnavailable]];
        return;
    }
    if (![ApplilinkUdid isAdvertisingTrackingEnabled]) {
        [self appListFailLoadWithError:
                  [ApplilinkNetworkError
                      localizedApplilinkErrorWithCode:kRecommendAdWebViewErrorAdTrackingDisabled]];
        return;
    }
    self.delegate = self;
    _loadComplete = NO;
    RecommendAdWebView *blockSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
      /** @ghidraAddress 0x245618 */
      if (!blockSelf.reloadFlg) {
          blockSelf.backgroundColor = UIColor.clearColor;
          blockSelf.opaque = NO;
      }
      [[RecommendCore sharedInstance] startSessionWithCallback:^(NSError *sessionError) {
        /** @ghidraAddress 0x245738 */
        if (sessionError != nil) {
            blockSelf.loadComplete = YES;
            [blockSelf appListFailLoadWithError:sessionError];
            return;
        }
        if (blockSelf.cancelFlg) {
            blockSelf.loadComplete = YES;
            [blockSelf appListFailLoadWithError:[ApplilinkNetworkError
                                                    localizedApplilinkErrorWithCode:
                                                        kRecommendAdWebViewErrorLoadCancelled]];
            return;
        }
        [RecommendWebAPI
            getBannerDetailWithAdModel:blockSelf.adModel
                              callback:^(NSInteger status, NSError *detailError) {
                                /** @ghidraAddress 0x245884 */
                                if (detailError != nil) {
                                    blockSelf.loadComplete = YES;
                                    [blockSelf appListFailLoadWithError:detailError];
                                    return;
                                }
                                if (blockSelf.cancelFlg) {
                                    blockSelf.loadComplete = YES;
                                    [blockSelf appListFailLoadWithError:
                                                   [ApplilinkNetworkError
                                                       localizedApplilinkErrorWithCode:
                                                           kRecommendAdWebViewErrorLoadCancelled]];
                                    return;
                                }
                                if (status != kRecommendAdWebViewBannerStatusHasAd) {
                                    blockSelf.loadComplete = YES;
                                    [blockSelf appListFailLoadWithError:
                                                   [ApplilinkNetworkError
                                                       localizedApplilinkErrorWithCode:
                                                           kRecommendAdWebViewErrorNoAd]];
                                    return;
                                }
                                [[RecommendCore sharedInstance]
                                    appliListCacheWithCallBack:^(id appliList,
                                                                 NSError *cacheError) {
                                      /** @ghidraAddress 0x245a2c */
                                      RecommendAdWebViewBuildAdRequestParameters(
                                          blockSelf, appliList, cacheError);
                                    }];
                              }];
      }];
    });
}

/** @ghidraAddress 0x2462b8 */
- (void)loadRequestWithURL:(NSString *)URL parameters:(NSDictionary *)parameters {
    NSString *urlString = [ApplilinkUtilities appendParametersToURL:URL parameters:parameters];
    NSMutableURLRequest *request =
        [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    request.timeoutInterval = kRecommendAdWebViewTimeout;
    request.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    [self loadRequest:request];
}

#pragma mark - Closing

/** @ghidraAddress 0x2463cc */
- (void)closeAdArea {
    if (self.isLoading) {
        [self stopLoading];
    }
    [self appliListClosed];
}

/** @ghidraAddress 0x246bb8 */
- (void)unloadRecommendView {
    [self stopLoading];
}

/** @ghidraAddress 0x246bcc */
- (void)appliListClosed {
    [self unloadRecommendView];
    if (_adLocation != nil) {
        _adLocation = nil;
    }
    [self appListDidDisappear];
}

/** @ghidraAddress 0x246bc8 */
- (void)viewDidDisappear:(BOOL)viewDidDisappear {
}

#pragma mark - Scrolling

/** @ghidraAddress 0x246420 */
- (void)setScrollEnabled:(BOOL)scrollEnabled {
    _scrollFlg = scrollEnabled;
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIScrollView class]]) {
            UIScrollView *scrollView = (UIScrollView *)subview;
            scrollView.scrollEnabled = scrollEnabled;
            scrollView.bounces = scrollEnabled;
            for (UIView *inner in scrollView.subviews) {
                if ([inner isKindOfClass:[UIImageView class]]) {
                    inner.hidden = !scrollEnabled;
                }
            }
        }
    }
}

/** @ghidraAddress 0x24671c */
- (void)setScrollBoundsEnabled:(BOOL)scrollBoundsEnabled {
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIScrollView class]]) {
            UIScrollView *scrollView = (UIScrollView *)subview;
            scrollView.bounces = scrollBoundsEnabled;
            for (UIView *inner in scrollView.subviews) {
                if ([inner isKindOfClass:[UIImageView class]]) {
                    inner.hidden = !scrollBoundsEnabled;
                }
            }
        }
    }
}

/** @ghidraAddress 0x2469e8 */
- (void)setScrollBarEnabled:(BOOL)scrollBarEnabled {
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIScrollView class]]) {
            UIScrollView *scrollView = (UIScrollView *)subview;
            scrollView.showsVerticalScrollIndicator = scrollBarEnabled;
            scrollView.showsHorizontalScrollIndicator = scrollBarEnabled;
        }
    }
}

#pragma mark - UIWebViewDelegate

/** @ghidraAddress 0x246c20 */
- (void)webViewDidStartLoad:(UIWebView *)webView {
    if (_webViewStatus == kRecommendAdWebViewStatusIdle) {
        _webViewStatus = kRecommendAdWebViewStatusStarted;
    }
    [self appListDidStart];
}

/** @ghidraAddress 0x246c48 */
- (void)webViewDidFinishLoad:(UIWebView *)webView {
    _webViewStatus = kRecommendAdWebViewStatusFinished;
    NSString *query = webView.request.URL.query;
    if (query == nil ||
        [query rangeOfString:kRecommendAdWebViewFinishCloseQuery].location == NSNotFound) {
        _reloadFlg = YES;
        RecommendAdWebView *blockSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
          /** @ghidraAddress 0x246d98 */
          [blockSelf appListDidAppear];
        });
    } else {
        [self appliListClosed];
    }
}

/** @ghidraAddress 0x246dbc */
- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    if (error.code == kRecommendAdWebViewURLErrorCancelled) {
        return;
    }
    if (error.code == kRecommendAdWebViewWebKitFrameLoadInterrupted &&
        [error.domain isEqual:@"WebKitErrorDomain"]) {
        return;
    }
    if (error.code == kRecommendAdWebViewWebKitPlugInWillHandleLoad &&
        [error.domain isEqual:@"WebKitErrorDomain"]) {
        return;
    }
    NSError *reportError = [NSError errorWithDomain:error.domain code:error.code userInfo:nil];
    if (_webViewStatus == kRecommendAdWebViewStatusFinished) {
        if (error.code == kRecommendAdWebViewURLErrorFrameLoadInterrupted) {
            [self appListFailLinkWithError:reportError];
            return;
        }
    } else {
        [self appListFailLoadWithError:reportError];
    }
    [self appliListClosed];
}

/** @ghidraAddress 0x246fac */
- (BOOL)webView:(UIWebView *)webView
    shouldStartLoadWithRequest:(NSURLRequest *)request
                navigationType:(UIWebViewNavigationType)navigationType {
    if (request.timeoutInterval != kRecommendAdWebViewTimeout) {
        NSMutableURLRequest *mutableRequest = (NSMutableURLRequest *)request;
        mutableRequest.timeoutInterval = kRecommendAdWebViewTimeout;
        [webView loadRequest:mutableRequest];
        return NO;
    }
    int redirect = [[RecommendCore sharedInstance] redirectWithRequest:request];
    BOOL shouldLoad = redirect == 1;
    if (redirect != 1) {
        _webViewStatus = kRecommendAdWebViewStatusFinished;
    }
    NSString *absoluteString = request.URL.absoluteString;
    if (request != nil && ([absoluteString isEqualToString:kRecommendAdWebViewCloseCommand] ||
                           [absoluteString hasPrefix:kRecommendAdWebViewCloseCommandPrefix])) {
        [self appListDidDisappear];
        [self appliListClosed];
        [self removeFromSuperview];
        return NO;
    }
    // The SDK's custom movie link: applilink://ext-app:80/movie?<query>. A nil request falls
    // through here harmlessly because every accessor below returns nil.
    NSURL *url = request.URL;
    NSString *scheme = url.scheme;
    NSString *host = url.host;
    int port = url.port.intValue;
    NSString *query = url.query;
    if (scheme != nil && [scheme hasPrefix:kRecommendAdWebViewSchemePrefix] && host != nil &&
        [host isEqualToString:kRecommendAdWebViewMovieHost] &&
        port == kRecommendAdWebViewMoviePort && request != nil) {
        if ([request.URL.absoluteString hasPrefix:kRecommendAdWebViewMoviePrefix] && query != nil) {
            [self showVideoViewWithQuery:query];
            shouldLoad = NO;
        }
    }
    return shouldLoad;
}

#pragma mark - Video

/** @ghidraAddress 0x2473d4 */
- (void)showVideoViewWithQuery:(NSString *)query {
    UIWindow *mainWindow = [ApplilinkCore mainWindow];
    ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
    [appParam setRequestWithAdModel:_adModel adLocation:_adLocation requestCode:_requestCode];
    [[ApplilinkViewManager sharedInstance] showVideoViewWithUIView:mainWindow
                                                  parentWindowFlag:NO
                                                             query:query
                                                          autoPlay:NO
                                                   applilinkParams:appParam
                                                          delegate:_applilinkDelegate];
}

#pragma mark - Delegate notifications

/** @ghidraAddress 0x247518 */
- (void)appListDidStart {
    id<ApplilinkViewDelegate> delegate = _applilinkDelegate;
    if (delegate && [delegate respondsToSelector:@selector(appListDidStart)]) {
        [delegate appListDidStart];
    }
}

/** @ghidraAddress 0x2475cc */
- (void)appListDidAppear {
    ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
    [appParam setRequestWithAdModel:_adModel adLocation:_adLocation requestCode:_requestCode];
    [ApplilinkCore toDelegateDidAppear:appParam delegate:_applilinkDelegate];
}

/** @ghidraAddress 0x247694 */
- (void)appListDidDisappear {
    ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
    [appParam setRequestWithAdModel:_adModel adLocation:_adLocation requestCode:_requestCode];
    [ApplilinkCore toDelegateDidDisappear:appParam delegate:_applilinkDelegate];
    _applilinkDelegate = nil;
}

/** @ghidraAddress 0x24776c */
- (void)appListFailLoadWithError:(NSError *)error {
    ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
    [appParam setRequestWithAdModel:_adModel adLocation:_adLocation requestCode:_requestCode];
    [ApplilinkCore toDelegateFailLoadWithError:error appParam:appParam delegate:_applilinkDelegate];
    _applilinkDelegate = nil;
}

/** @ghidraAddress 0x24786c */
- (void)appListFailLinkWithError:(NSError *)error {
    ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
    [appParam setRequestWithAdModel:_adModel adLocation:_adLocation requestCode:_requestCode];
    [ApplilinkCore toDelegateFailLinkWithError:error appParam:appParam delegate:_applilinkDelegate];
}

@end
