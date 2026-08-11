#import "RecommendAdAreaView.h"

#import "AnalysisNetworkCore.h"
#import "ApplilinkConsts.h"
#import "ApplilinkCore.h"
#import "ApplilinkParameters.h"
#import "ApplilinkUtilities.h"
#import "ApplilinkViewManager.h"
#import "NSStringURLEncoding.h"
#import "RecommendAdCache.h"
#import "RecommendAdId.h"
#import "RecommendCore.h"
#import "RecommendWebAPI.h"

// Web-view load status stored in webViewStatus.
enum {
    RecommendAdAreaViewStatusIdle = 0,
    RecommendAdAreaViewStatusStarted = 1,
    RecommendAdAreaViewStatusFinished = 2,
};

// Advert models whose advert area scrolls freely rather than being pinned.
enum {
    RecommendAdAreaViewAdModelScrollableBanner = 1,
    RecommendAdAreaViewAdModelScrollableInterstitial = 4,
    RecommendAdAreaViewAdModelFixedInterstitial = 5,
};

// UIWebView cancellation and policy-change error codes ignored during the advert load.
enum {
    RecommendAdAreaViewWebKitFrameLoadInterrupted = 102, // 0x66
    RecommendAdAreaViewWebKitPlugInWillHandleLoad = 204, // 0xcc
    RecommendAdAreaViewURLErrorCancelled = -999,         // NSURLErrorCancelled
    RecommendAdAreaViewURLErrorNotConnectedToInternet = -1009,
};

// The port the applilink external-application scheme listens on.
enum {
    RecommendAdAreaViewExtAppPort = 80,
};

// Result of redirectWithRequest: whether the web view should proceed with the request. The
// external-scheme value is distinct from the load value so a caller can tell the two apart.
enum {
    RecommendAdAreaViewRedirectConsumed = 0,
    RecommendAdAreaViewRedirectLoad = 1,
    RecommendAdAreaViewRedirectExternalScheme = 3,
};

// The advert-tag value that opts the video area into the superview walk in showVideoViewWithQuery:.
enum {
    RecommendAdAreaViewVideoTag = 5,
};

static NSString *const kRecommendAdAreaViewFormatObject = @"%@";
static NSString *const kRecommendAdAreaViewFormatScheme = @"%@://";
static NSString *const kRecommendAdAreaViewFormatQuerySuffix = @"?%@";
static NSString *const kRecommendAdAreaViewWebKitErrorDomain = @"WebKitErrorDomain";

// The applilink external-application redirect scheme, host, path commands, and the full ext-app URL
// prefix stripped from a tapped link.
static NSString *const kRecommendAdAreaViewApplilinkScheme = @"applilink";
static NSString *const kRecommendAdAreaViewExtAppHost = @"ext-app";
static NSString *const kRecommendAdAreaViewExtAppUrl = @"applilink://ext-app:80";
static NSString *const kRecommendAdAreaViewCloseCommand = @"close";
static NSString *const kRecommendAdAreaViewCloseCommandPrefix = @"/close";
static NSString *const kRecommendAdAreaViewMovieCommand = @"movie";
static NSString *const kRecommendAdAreaViewMovieCommandPrefix = @"/movie";
static NSString *const kRecommendAdAreaViewSendCommand = @"send";
static NSString *const kRecommendAdAreaViewSendCommandPrefix = @"/send";
static NSString *const kRecommendAdAreaViewQuerySeparator = @"&";
static NSString *const kRecommendAdAreaViewPathSeparator = @"/";

// The advert-record key holding the advertising identifier registered on load.
static NSString *const kRecommendAdAreaViewAdIdKey = @"ad_id";

// The redirect query-parameter match keys, tested with rangeOfString:, without a trailing equals
// sign.
static NSString *const kRecommendAdAreaViewKeyDefaultScheme = @"default_scheme";
static NSString *const kRecommendAdAreaViewKeyAdType = @"ad_type";
static NSString *const kRecommendAdAreaViewKeyAdModel = @"ad_model";
static NSString *const kRecommendAdAreaViewKeyAdLocation = @"ad_location";
static NSString *const kRecommendAdAreaViewKeyAdIdFrom = @"ad_id_from";
static NSString *const kRecommendAdAreaViewKeyAdIdTo = @"ad_id_to";
static NSString *const kRecommendAdAreaViewKeyCountryCode = @"country_code";
static NSString *const kRecommendAdAreaViewKeyCategoryId = @"category_id";
static NSString *const kRecommendAdAreaViewKeyCreativeId = @"creative_id";
static NSString *const kRecommendAdAreaViewKeyIncentiveType = @"incentive_type";
static NSString *const kRecommendAdAreaViewKeyInstallFlg = @"install_flg";
static NSString *const kRecommendAdAreaViewKeyDisplayNumber = @"display_number";
static NSString *const kRecommendAdAreaViewKeyStoreId = @"store_id";
static NSString *const kRecommendAdAreaViewKeyAppliIdTo = @"appli_id_to";

// The redirect query-parameter strip prefixes, each including its trailing equals sign, used to
// drop the leading key before URL-decoding the value.
static NSString *const kRecommendAdAreaViewPrefixDefaultScheme = @"default_scheme=";
static NSString *const kRecommendAdAreaViewPrefixAdType = @"ad_type=";
static NSString *const kRecommendAdAreaViewPrefixAdModel = @"ad_model=";
static NSString *const kRecommendAdAreaViewPrefixAdLocation = @"ad_location=";
static NSString *const kRecommendAdAreaViewPrefixAdIdFrom = @"ad_id_from=";
static NSString *const kRecommendAdAreaViewPrefixAdIdTo = @"ad_id_to=";
static NSString *const kRecommendAdAreaViewPrefixCountryCode = @"country_code=";
static NSString *const kRecommendAdAreaViewPrefixCategoryId = @"category_id=";
static NSString *const kRecommendAdAreaViewPrefixCreativeId = @"creative_id=";
static NSString *const kRecommendAdAreaViewPrefixIncentiveType = @"incentive_type=";
static NSString *const kRecommendAdAreaViewPrefixInstallFlg = @"install_flg=";
static NSString *const kRecommendAdAreaViewPrefixDisplayNumber = @"display_number=";
static NSString *const kRecommendAdAreaViewPrefixStoreId = @"store_id=";
static NSString *const kRecommendAdAreaViewPrefixAppliIdTo = @"appli_id_to=";

@interface RecommendAdAreaView ()

// Redeclared writable so the class can assign it internally; publicly read-only.
@property(nonatomic, strong, readwrite, nullable) NSString *impressionId;

@end

// URL-decode the tail of a query component after stripping its leading key prefix.
static inline NSString *RecommendAdAreaViewDecodedValueFrom(NSString *component, NSString *prefix) {
    return [NSStringURLEncoding URLDecodedString:[component substringFromIndex:prefix.length]];
}

@implementation RecommendAdAreaView

#pragma mark - Initialisation

/** @ghidraAddress 0x271ac0 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.opaque = NO;
        self.autoresizingMask =
            UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
            UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
            UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
        self.contentMode = UIViewContentModeScaleAspectFit;
    }
    return self;
}

/** @ghidraAddress 0x274978 */
- (void)dealloc {
    if (_applilinkDelegate) {
        _applilinkDelegate = nil;
    }
    if (_sdkDelegate) {
        _sdkDelegate = nil;
    }
    if (self.delegate != nil) {
        self.delegate = nil;
    }
    _adLocation = nil;
    _impressionId = nil;
    _requestCode = nil;
}

#pragma mark - Configuration

/** @ghidraAddress 0x271e88 */
- (void)setImpressionId:(NSString *)impressionId {
    if (impressionId == nil) {
        _impressionId = nil;
    } else {
        _impressionId = [NSString stringWithFormat:kRecommendAdAreaViewFormatObject, impressionId];
    }
}

/** @ghidraAddress 0x271b9c */
- (void)startPath:(NSString *)path {
    self.delegate = self;
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL fileURLWithPath:path]];
    [self loadRequest:request];
    self.backgroundColor = UIColor.clearColor;
    self.opaque = NO;
}

/** @ghidraAddress 0x271cc8 */
- (void)setAdModel:(int)adModel
        adLocation:(NSString *)adLocation
            adType:(int)adType
       requestCode:(id)requestCode
          delegate:(id<ApplilinkViewDelegate>)delegate {
    _webViewStatus = RecommendAdAreaViewStatusIdle;
    _adType = adType;
    _adModel = adModel;
    if (adLocation == nil) {
        _adLocation = nil;
    } else {
        _adLocation = [NSString stringWithFormat:kRecommendAdAreaViewFormatObject, adLocation];
    }
    _requestCode = requestCode;
    _applilinkDelegate = delegate;
    if (adModel == RecommendAdAreaViewAdModelScrollableBanner ||
        adModel == RecommendAdAreaViewAdModelFixedInterstitial ||
        adModel == RecommendAdAreaViewAdModelScrollableInterstitial) {
        // A fixed interstitial disables scrolling; the scrollable models enable it.
        [self setScrollEnabled:adModel != RecommendAdAreaViewAdModelFixedInterstitial];
    } else {
        self.scrollView.bounces = NO;
        [self setScrollBoundsEnabled:NO];
        [self setScrollBarEnabled:NO];
    }
}

/** @ghidraAddress 0x271f04 */
- (void)removeFromSuperview {
    [super removeFromSuperview];
}

/** @ghidraAddress 0x271f40 */
- (void)closeAdArea {
    [self appListDidDisappear];
}

#pragma mark - Scrolling

/** @ghidraAddress 0x271f50 */
- (void)setScrollEnabled:(BOOL)scrollEnabled {
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

/** @ghidraAddress 0x272240 */
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

/** @ghidraAddress 0x27250c */
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

/** @ghidraAddress 0x2726dc */
- (void)webViewDidStartLoad:(UIWebView *)webView {
    if (_webViewStatus == RecommendAdAreaViewStatusIdle) {
        _webViewStatus = RecommendAdAreaViewStatusStarted;
    }
}

/** @ghidraAddress 0x2726f8 */
- (void)webViewDidFinishLoad:(UIWebView *)webView {
    _webViewStatus = RecommendAdAreaViewStatusFinished;
    NSMutableArray *adIdList = [NSMutableArray array];
    NSArray *records = [RecommendAdCache getHtmlAdDataWithAdModel:_adModel adLocation:_adLocation];
    for (NSDictionary *record in records) {
        NSString *adId = record[kRecommendAdAreaViewAdIdKey];
        if (adId != nil) {
            [adIdList addObject:adId];
        }
    }
    [RecommendWebAPI readRegistWithAdType:_adType
                                 adIdList:adIdList
                                 callback:^(NSError *_Nullable __attribute__((unused)) error){
                                     /** @ghidraAddress 0x2729b4 */
                                 }];
    // The impression identifier is only assigned once; a reload keeps the first one.
    if (_impressionId == nil) {
        _impressionId = [ApplilinkUtilities getImpressionId];
    }
    [[RecommendCore sharedInstance] postAnalysisListRegistWithAdType:_adType
                                                             AdModel:_adModel
                                                          adLocation:_adLocation
                                                        impressionId:_impressionId];
    [self appListDidAppear];
}

/** @ghidraAddress 0x2729b8 */
- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    if (error.code == RecommendAdAreaViewURLErrorCancelled) {
        return;
    }
    if (error.code == RecommendAdAreaViewWebKitFrameLoadInterrupted &&
        [error.domain isEqual:kRecommendAdAreaViewWebKitErrorDomain]) {
        return;
    }
    if (error.code == RecommendAdAreaViewWebKitPlugInWillHandleLoad &&
        [error.domain isEqual:kRecommendAdAreaViewWebKitErrorDomain]) {
        return;
    }
    NSError *reportError = [NSError errorWithDomain:error.domain code:error.code userInfo:nil];
    if (_webViewStatus == RecommendAdAreaViewStatusFinished) {
        if (error.code != RecommendAdAreaViewURLErrorNotConnectedToInternet) {
            return;
        }
        [self appListFailLinkWithError:reportError];
    } else {
        [self appListFailLoadWithError:reportError];
    }
}

/** @ghidraAddress 0x272b84 */
- (BOOL)webView:(UIWebView *)webView
    shouldStartLoadWithRequest:(NSURLRequest *)request
                navigationType:(UIWebViewNavigationType)navigationType {
    int redirect = [self redirectWithRequest:request];
    if (redirect != RecommendAdAreaViewRedirectLoad) {
        _webViewStatus = RecommendAdAreaViewStatusFinished;
    }
    return redirect == RecommendAdAreaViewRedirectLoad;
}

#pragma mark - Video

/** @ghidraAddress 0x2746f0 */
- (void)showVideoViewWithQuery:(NSString *)query {
    // For the video advert tag, walk up to two superview levels so the player is presented on the
    // hosting window rather than the advert area itself; other tags present on self.
    UIView *host = self;
    BOOL parentWindowFlag = YES;
    if (self.tag == RecommendAdAreaViewVideoTag) {
        if (self != nil && self.superview != nil) {
            host = self.superview;
            parentWindowFlag = NO;
        }
        if (host != nil && host.superview != nil) {
            host = host.superview;
        }
    }
    ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
    [appParam setRequestWithAdModel:_adModel adLocation:_adLocation requestCode:_requestCode];
    [[ApplilinkViewManager sharedInstance] showVideoViewWithUIView:host
                                                  parentWindowFlag:parentWindowFlag
                                                             query:query
                                                          autoPlay:NO
                                                   applilinkParams:appParam
                                                          delegate:_applilinkDelegate];
}

#pragma mark - Advert-tap redirect

/** @ghidraAddress 0x273194 */
- (int)redirectWithRequest:(NSURLRequest *)request {
    NSURL *url = request.URL;
    NSString *scheme = url.scheme;
    NSString *host = url.host;
    NSInteger port = url.port.intValue;
    NSString *path = url.path;
    NSString *query = url.query;
    if (scheme == nil || ![scheme hasPrefix:kRecommendAdAreaViewApplilinkScheme] || host == nil ||
        ![host isEqualToString:kRecommendAdAreaViewExtAppHost] ||
        port != RecommendAdAreaViewExtAppPort) {
        return RecommendAdAreaViewRedirectLoad;
    }

    if (path != nil) {
        if ([path isEqualToString:kRecommendAdAreaViewCloseCommand] ||
            [path hasPrefix:kRecommendAdAreaViewCloseCommandPrefix]) {
            [self appListDidDisappear];
            [self removeFromSuperview];
            return RecommendAdAreaViewRedirectConsumed;
        }
        if (([path isEqualToString:kRecommendAdAreaViewMovieCommand] ||
             [path hasPrefix:kRecommendAdAreaViewMovieCommandPrefix]) &&
            query != nil) {
            [self showVideoViewWithQuery:query];
            return RecommendAdAreaViewRedirectConsumed;
        }
    }

    if (query == nil) {
        return RecommendAdAreaViewRedirectLoad;
    }

    NSString *defaultScheme = nil;
    NSString *adType = nil;
    NSString *adModel = nil;
    NSString *adIdFrom = nil;
    NSString *adIdTo = nil;
    NSString *countryCode = nil;
    NSString *categoryId = nil;
    NSString *creativeId = nil;
    NSString *incentiveType = nil;
    NSString *installFlg = nil;
    NSString *displayNumber = nil;
    NSString *storeId = nil;
    NSString *appliIdTo = nil;
    NSArray *components = [query componentsSeparatedByString:kRecommendAdAreaViewQuerySeparator];
    for (NSString *component in components) {
        if ([component rangeOfString:kRecommendAdAreaViewKeyDefaultScheme].location != NSNotFound) {
            defaultScheme = RecommendAdAreaViewDecodedValueFrom(
                component, kRecommendAdAreaViewPrefixDefaultScheme);
        } else if ([component rangeOfString:kRecommendAdAreaViewKeyAdType].location != NSNotFound) {
            adType =
                RecommendAdAreaViewDecodedValueFrom(component, kRecommendAdAreaViewPrefixAdType);
        } else if ([component rangeOfString:kRecommendAdAreaViewKeyAdModel].location !=
                   NSNotFound) {
            adModel =
                RecommendAdAreaViewDecodedValueFrom(component, kRecommendAdAreaViewPrefixAdModel);
        } else if ([component rangeOfString:kRecommendAdAreaViewKeyAdLocation].location !=
                   NSNotFound) {
            // Yes, the binary parses ad_location and then reads the _adLocation ivar at the call
            // sites below, so the decoded value is discarded.
            (void)RecommendAdAreaViewDecodedValueFrom(component,
                                                      kRecommendAdAreaViewPrefixAdLocation);
        } else if ([component rangeOfString:kRecommendAdAreaViewKeyAdIdFrom].location !=
                   NSNotFound) {
            adIdFrom =
                RecommendAdAreaViewDecodedValueFrom(component, kRecommendAdAreaViewPrefixAdIdFrom);
        } else if ([component rangeOfString:kRecommendAdAreaViewKeyAdIdTo].location != NSNotFound) {
            adIdTo =
                RecommendAdAreaViewDecodedValueFrom(component, kRecommendAdAreaViewPrefixAdIdTo);
        } else if ([component rangeOfString:kRecommendAdAreaViewKeyCountryCode].location !=
                   NSNotFound) {
            countryCode = RecommendAdAreaViewDecodedValueFrom(
                component, kRecommendAdAreaViewPrefixCountryCode);
        } else if ([component rangeOfString:kRecommendAdAreaViewKeyCategoryId].location !=
                   NSNotFound) {
            categoryId = RecommendAdAreaViewDecodedValueFrom(component,
                                                             kRecommendAdAreaViewPrefixCategoryId);
        } else if ([component rangeOfString:kRecommendAdAreaViewKeyCreativeId].location !=
                   NSNotFound) {
            creativeId = RecommendAdAreaViewDecodedValueFrom(component,
                                                             kRecommendAdAreaViewPrefixCreativeId);
        } else if ([component rangeOfString:kRecommendAdAreaViewKeyIncentiveType].location !=
                   NSNotFound) {
            incentiveType = RecommendAdAreaViewDecodedValueFrom(
                component, kRecommendAdAreaViewPrefixIncentiveType);
        } else if ([component rangeOfString:kRecommendAdAreaViewKeyInstallFlg].location !=
                   NSNotFound) {
            installFlg = RecommendAdAreaViewDecodedValueFrom(component,
                                                             kRecommendAdAreaViewPrefixInstallFlg);
        } else if ([component rangeOfString:kRecommendAdAreaViewKeyDisplayNumber].location !=
                   NSNotFound) {
            displayNumber = RecommendAdAreaViewDecodedValueFrom(
                component, kRecommendAdAreaViewPrefixDisplayNumber);
        } else if ([component rangeOfString:kRecommendAdAreaViewKeyStoreId].location !=
                   NSNotFound) {
            storeId =
                RecommendAdAreaViewDecodedValueFrom(component, kRecommendAdAreaViewPrefixStoreId);
        } else if ([component rangeOfString:kRecommendAdAreaViewKeyAppliIdTo].location !=
                   NSNotFound) {
            appliIdTo =
                RecommendAdAreaViewDecodedValueFrom(component, kRecommendAdAreaViewPrefixAppliIdTo);
        }
    }

    if (path == nil || (![path isEqualToString:kRecommendAdAreaViewSendCommand] &&
                        ![path hasPrefix:kRecommendAdAreaViewSendCommandPrefix])) {
        // Non-send taps drive an external App Store or scheme transition.
        NSString *extAppPrefix = [NSString
            stringWithFormat:kRecommendAdAreaViewFormatObject, kRecommendAdAreaViewExtAppUrl];
        NSString *destination = path;
        if ([url.absoluteString hasPrefix:extAppPrefix]) {
            destination = [url.absoluteString substringFromIndex:extAppPrefix.length];
            if (query.length != 0) {
                NSString *querySuffix =
                    [NSString stringWithFormat:kRecommendAdAreaViewFormatQuerySuffix, query];
                if ([destination hasSuffix:querySuffix]) {
                    destination =
                        [destination substringToIndex:destination.length - querySuffix.length];
                }
            }
        }

        if (destination.length == 0) {
            return RecommendAdAreaViewRedirectLoad;
        }

        NSURL *schemeUrl =
            [NSURL URLWithString:[NSString stringWithFormat:kRecommendAdAreaViewFormatScheme,
                                                            defaultScheme]];
        if (schemeUrl != nil && [[UIApplication sharedApplication] canOpenURL:schemeUrl]) {
            [[UIApplication sharedApplication] openURL:schemeUrl];
            return RecommendAdAreaViewRedirectExternalScheme;
        }

        NSArray *segments = [[destination substringFromIndex:1]
            componentsSeparatedByString:kRecommendAdAreaViewPathSeparator];
        if (segments.count != 0) {
            // The first path segment is decoded but the store id parsed from the query drives the
            // presentation.
            (void)[NSStringURLEncoding URLDecodedString:segments[0]];
            ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
            [appParam setRequestWithAdModel:_adModel
                                 adLocation:_adLocation
                                requestCode:_requestCode];
            if (![ApplilinkCore showAppStoreId:storeId appParam:appParam delegate:self]) {
                NSURL *destinationUrl = [NSURL URLWithString:destination];
                ((NSMutableURLRequest *)request).URL = destinationUrl;
                if (destinationUrl != nil &&
                    [[UIApplication sharedApplication] canOpenURL:destinationUrl]) {
                    [[UIApplication sharedApplication] openURL:destinationUrl];
                    [self appListDidDisappear];
                    [self removeFromSuperview];
                }
            }
        }
        return RecommendAdAreaViewRedirectConsumed;
    }

    // A send tap registers the click analytics and then loads the target advert once the
    // registration completes.
    if (adIdFrom != nil && countryCode != nil && categoryId != nil) {
        RecommendAdId *adId = [[RecommendAdId alloc] initWithCountryCode:countryCode
                                                              categoryId:categoryId];
        [adId setWithAdIdFrom:adIdFrom
                  countryCode:countryCode
                   categoryId:categoryId
                       adType:adType
                        error:nil];
    }
    RecommendAdAreaView *blockSelf = self;
    NSString *blockDefaultScheme = defaultScheme;
    NSString *blockAdIdTo = adIdTo;
    NSString *blockAdIdFrom = adIdFrom;
    [AnalysisNetworkCore
        postAnalysisClickRegistWithAdType:adType
                                  adModel:adModel
                               adLocation:_adLocation
                             impressionId:_impressionId
                                appliIdTo:appliIdTo
                               creativeId:creativeId
                            displayNumber:displayNumber
                            incentiveType:incentiveType
                               installFlg:installFlg
                                 callback:^(NSError *_Nullable __attribute__((unused)) error) {
                                   /** @ghidraAddress 0x2744d4 */
                                   NSURL *schemeUrl = [NSURL
                                       URLWithString:[NSString stringWithFormat:
                                                                   kRecommendAdAreaViewFormatScheme,
                                                                   blockDefaultScheme]];
                                   NSURLRequest *loadRequest;
                                   if (schemeUrl != nil &&
                                       [[UIApplication sharedApplication] canOpenURL:schemeUrl]) {
                                       // The target app is installed: report the start with the
                                       // consts-supplied source id and the advert type.
                                       NSString *appliIdFrom = ApplilinkConsts.adId;
                                       loadRequest =
                                           [RecommendWebAPI appStartWithAdIdFrom:appliIdFrom
                                                                          adIdTo:blockAdIdTo
                                                                          adType:blockSelf.adType];
                                   } else {
                                       // Not installed: register the click with the query's source
                                       // id and the advert model.
                                       loadRequest = [RecommendWebAPI
                                           clickRegistWithAdIdFrom:blockAdIdFrom
                                                            adIdTo:blockAdIdTo
                                                           adModel:blockSelf.adModel];
                                   }
                                   [blockSelf loadRequest:loadRequest];
                                 }];
    return RecommendAdAreaViewRedirectConsumed;
}

#pragma mark - Advert-list delegate notifications

/** @ghidraAddress 0x272bd8 */
- (void)appListDidAppear {
    id<SdkViewDelegate> sdkDelegate = _sdkDelegate;
    if (sdkDelegate != nil && [sdkDelegate respondsToSelector:@selector(openedNotice)]) {
        [sdkDelegate openedNotice];
    }
    ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
    [appParam setRequestWithAdModel:_adModel adLocation:_adLocation requestCode:_requestCode];
    [ApplilinkCore toDelegateDidAppear:appParam delegate:_applilinkDelegate];
}

/** @ghidraAddress 0x272d20 */
- (void)appListDidDisappear {
    id<SdkViewDelegate> sdkDelegate = _sdkDelegate;
    if (sdkDelegate != nil) {
        if ([sdkDelegate respondsToSelector:@selector(closeNotice)]) {
            [sdkDelegate closeNotice];
        }
        _sdkDelegate = nil;
    }
    [[RecommendCore sharedInstance] appListSoundUseFinish];
    ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
    [appParam setRequestWithAdModel:_adModel adLocation:_adLocation requestCode:_requestCode];
    [ApplilinkCore toDelegateDidDisappear:appParam delegate:_applilinkDelegate];
    _applilinkDelegate = nil;
}

/** @ghidraAddress 0x272ec0 */
- (void)appListFailLoadWithError:(NSError *)error {
    id<SdkViewDelegate> sdkDelegate = _sdkDelegate;
    if (sdkDelegate != nil) {
        if ([sdkDelegate respondsToSelector:@selector(failOpenNoticeWithError:)]) {
            [sdkDelegate failOpenNoticeWithError:error];
        }
        _sdkDelegate = nil;
    }
    ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
    [appParam setRequestWithAdModel:_adModel adLocation:_adLocation requestCode:_requestCode];
    [ApplilinkCore toDelegateFailLoadWithError:error appParam:appParam delegate:_applilinkDelegate];
}

/** @ghidraAddress 0x273030 */
- (void)appListFailLinkWithError:(NSError *)error {
    id<SdkViewDelegate> sdkDelegate = _sdkDelegate;
    if (sdkDelegate != nil &&
        [sdkDelegate respondsToSelector:@selector(failLinkNoticeWithError:)]) {
        [sdkDelegate failLinkNoticeWithError:error];
    }
    ApplilinkParameters *appParam = [[ApplilinkParameters alloc] init];
    [appParam setRequestWithAdModel:_adModel adLocation:_adLocation requestCode:_requestCode];
    [ApplilinkCore toDelegateFailLinkWithError:error appParam:appParam delegate:_applilinkDelegate];
}

#pragma mark - App Store notices

/** @ghidraAddress 0x2748fc */
- (void)openedNotice {
}

/** @ghidraAddress 0x274900 */
- (void)closeNotice {
    [self appListDidDisappear];
    [self removeFromSuperview];
}

/** @ghidraAddress 0x27493c */
- (void)openErrorNotice {
}

/** @ghidraAddress 0x274940 */
- (void)appStoreOpenedNotice {
}

/** @ghidraAddress 0x274944 */
- (void)appStoreCloseNotice {
    if (_adModel == RecommendAdAreaViewAdModelFixedInterstitial) {
        [self closeNotice];
    }
}

/** @ghidraAddress 0x27496c */
- (void)appStoreClosedNotice {
}

/** @ghidraAddress 0x274970 */
- (void)appStoreFailLoadNoticeWithError:(NSError *)error {
}

/** @ghidraAddress 0x274974 */
- (void)appStoreTransitionNotice {
}

@end
