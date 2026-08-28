//
//  RewardWebViewController.m
//  jubeat plus
//
//  Reconstructed from Ghidra program Jubeat (image base 0x100000000).
//  See RewardWebViewController.h for the class overview.
//

#import "RewardWebViewController.h"

#import <UIKit/UIKit.h>

#import "ApplilinkConsts.h"
#import "ApplilinkCore.h"
#import "ApplilinkIndicator.h"
#import "ApplilinkMessage.h"
#import "ApplilinkUtilities.h"
#import "ApplilinkViewManager.h"
#import "RewardCore.h"

// The status-bar-relative vertical inset applied to the base view: 44 points when the navigation
// bar is shown, 0 when it is hidden. Read from the __const pool at 0x291e30.
static const CGFloat kNavigationBarInsetShown = 44.0;
static const CGFloat kNavigationBarInsetHidden = 0.0;

// The delay, in seconds, before the loading overlay switches to its touch-active state. Read from
// the __const pool at 0x28f1e0.
static const NSTimeInterval kIndicatorActivationDelay = 45.0;

// The mutable request's timeout, in seconds.
static const NSTimeInterval kRequestTimeout = 30.0;

// The message-table keys for the navigation-bar title and close button.
static NSString *const kAppListTitleKey = @"RewardNetworkAppListTitle";
static NSString *const kAppListCloseButtonKey = @"RewardNetworkAppListCloseButton";

// The advert page signals a close either through a "close" navigation, a "close/" prefix, or a
// "command=close" query. The applilink external-application movie scheme is intercepted and routed
// to the reward-video view.
static NSString *const kCloseNavigation = @"close";
static NSString *const kCloseNavigationPrefix = @"close/";
static NSString *const kCloseCommandQuery = @"command=close";
static NSString *const kApplilinkScheme = @"applilink";
static NSString *const kExtAppHost = @"ext-app";
static NSString *const kExtAppMovieURLPrefix = @"applilink://ext-app:80/movie";
static NSString *const kWebKitErrorDomain = @"WebKitErrorDomain";

// The external-application scheme's port.
static const int kExtAppPort = 80;

// The system version at and above which the navigation bar is tinted and the modern rotation path
// is used. Both are read as fmov immediates in the binary (7.0 at 0x40e00000, 8.0 at 0x41000000).
static const float kSystemVersionIOS7 = 7.0f;
static const float kSystemVersionIOS8 = 8.0f;

// The redirect dispositions returned by RewardCore -redirectWithRequest:.
enum {
    kRedirectPathSegmentOpened = 0,   // A path-segment URL was opened; cancel the request.
    kRedirectNotResolved = 1,         // Not an applilink redirect, no route, or unresolved; load.
    kRedirectReloadWithCookies = 2,   // Reload the request with the applilink cookies attached.
    kRedirectDefaultSchemeOpened = 3, // A default-scheme URL was opened; cancel the request.
    kRedirectAppStoreShown = 4,       // An app-store redirect was shown; cancel the request.
    kRedirectClose = 7,               // A recognised close route.
};

// Web-view/URL error codes handled specially in -webView:didFailLoadWithError:.
enum {
    kWebErrorCancelled = -999,       // NSURLErrorCancelled; always ignored.
    kWebErrorNotConnected = -1009,   // NSURLErrorNotConnectedToInternet; a post-load link failure.
    kWebErrorPlugInLoadFailed = 204, // WebKit plug-in load failure; ignored on the WebKit domain.
    kWebErrorFrameLoadFailed = 102,  // WebKit frame-load failure; ignored on the WebKit domain.
};

@interface RewardWebViewController () <UIWebViewDelegate>

// Set once the view has disappeared or been closed, so a subsequent -loadView just detaches the
// stale view instead of rebuilding it.
@property(nonatomic) BOOL viewCloseFlg;

// The reference bounds the layout is derived from, captured in -loadView.
@property(nonatomic) CGRect baseFrame;

- (void)activeWebView;
- (int)redirectWithRequest:(NSURLRequest *)request;
- (void)appListDidStart;
- (void)appListDidAppear;
- (void)appListDidDisappear;
- (void)appListFailLoadWithError:(NSError *)error;
- (void)appListFailLinkWithError:(NSError *)error;
- (void)btnCloseClicked:(id)sender;
- (BOOL)hasParentViewController:(UIResponder *)responder;
- (void)rotateWebViewWithInterfaceOrientation:(UIInterfaceOrientation)orientation
                                     duration:(NSTimeInterval)duration;

@end

@implementation RewardWebViewController

#pragma mark - Lifecycle

/** @ghidraAddress 0x24c39c */
- (instancetype)init {
    return [super init];
}

/** @ghidraAddress 0x24cb88 */
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

/** @ghidraAddress 0x24cbc4 */
- (void)viewDidLoad {
    [super viewDidLoad];
    if ([self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) {
        [self setNeedsStatusBarAppearanceUpdate];
    }
}

/** @ghidraAddress 0x24c3d8 */
- (void)loadView {
    [super loadView];
    // When the view was closed, this reload just detaches the stale view and returns.
    if (self.viewCloseFlg) {
        self.viewCloseFlg = NO;
        [self.view removeFromSuperview];
        return;
    }
    _baseFrame = self.view.bounds;
    self.view.userInteractionEnabled = YES;
    self.view.backgroundColor = UIColor.whiteColor;

    BOOL navigationBarHidden = self.isNavigationBarHidden;
    (void)UIScreen.mainScreen.bounds; // Yes, the binary evaluates and discards this.
    if (self.parentView) {
        _baseFrame = self.parentView.frame;
    }

    self.baseView = [[UIView alloc] init];
    self.baseView.backgroundColor = UIColor.whiteColor;
    self.baseView.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight |
        UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin |
        UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    CGFloat inset = navigationBarHidden ? kNavigationBarInsetHidden : kNavigationBarInsetShown;
    self.baseView.frame =
        CGRectMake(0, inset, _baseFrame.size.width, _baseFrame.size.height - inset);

    self.webView = [[UIWebView alloc]
        initWithFrame:CGRectMake(0, 0, _baseFrame.size.width, _baseFrame.size.height - inset)];
    self.webView.delegate = self;
    self.webView.backgroundColor = UIColor.whiteColor;
    if (self.webView) {
        self.webView.scrollView.bounces = !self.webViewBounces;
    }
    self.webViewBounces = NO;

    [self.view addSubview:self.baseView];
    [self.baseView addSubview:self.webView];

    if (!navigationBarHidden) {
        self.navigationBar = [[UINavigationBar alloc] initWithFrame:CGRectZero];
        UINavigationItem *item = [[UINavigationItem alloc]
            initWithTitle:[ApplilinkMessage localizedMessage:kAppListTitleKey]];
        item.leftBarButtonItem = [[UIBarButtonItem alloc]
            initWithTitle:[ApplilinkMessage localizedMessage:kAppListCloseButtonKey]
                    style:UIBarButtonItemStyleDone
                   target:self
                   action:@selector(btnCloseClicked:)];
        if (![ApplilinkCore isNavigationBarCommonAppearance]) {
            if (UIDevice.currentDevice.systemVersion.floatValue >= kSystemVersionIOS7) {
                self.navigationBar.barTintColor = UIColor.whiteColor;
            }
        }
        [self.navigationBar pushNavigationItem:item animated:NO];
        [self.view addSubview:self.navigationBar];

        self.indicator = [[ApplilinkIndicator alloc] initWithFrame:self.view.bounds];
        [self.view addSubview:self.indicator];
    }

    [self rotateWebViewWithInterfaceOrientation:UIApplication.sharedApplication.statusBarOrientation
                                       duration:0.0];
    [self appListDidStart];
}

/** @ghidraAddress 0x24f264 */
- (void)dealloc {
    [self clearDelegate];
    _viewCloseFlg = NO;
    // The binary's -[super dealloc] is elided: ARC synthesises the superclass teardown and the
    // strong-ivar release (the binary's .cxx_destruct at 0x24f504).
}

/** @ghidraAddress 0x24cc40 */
- (void)viewDidDisappear:(BOOL)animated {
    self.viewCloseFlg = YES;
}

#pragma mark - Status bar and rotation

/** @ghidraAddress 0x24cd74 */
- (BOOL)prefersStatusBarHidden {
    return YES;
}

/** @ghidraAddress 0x24e0f0 */
- (BOOL)shouldAutorotate {
    return YES;
}

/** @ghidraAddress 0x24e0f8 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    // The binary returns the raw mask 0x1e = UIInterfaceOrientationMaskAll.
    return UIInterfaceOrientationMaskAll;
}

/** @ghidraAddress 0x24e080 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
    if (![self shouldAutorotate]) {
        return NO;
    }
    // The binary indexes a table of masks (2, 4, 8, 0x10 at 0x2944f0) by orientation - 1. Those are
    // the same values the named masks hold, since each mask is defined as 1 << its orientation, so
    // the shift is reproduced here for fidelity rather than because it differs.
    NSUInteger bit;
    switch (orientation) {
    case UIInterfaceOrientationPortrait:
    case UIInterfaceOrientationPortraitUpsideDown:
    case UIInterfaceOrientationLandscapeLeft:
    case UIInterfaceOrientationLandscapeRight:
        bit = (NSUInteger)1 << orientation;
        break;
    default:
        return NO;
    }
    return ([self supportedInterfaceOrientations] & bit) != 0;
}

/** @ghidraAddress 0x24f058 */
- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)orientation
                                         duration:(NSTimeInterval)duration {
    [self rotateWebViewWithInterfaceOrientation:UIApplication.sharedApplication.statusBarOrientation
                                       duration:duration];
}

// Lays the base view, navigation bar, web view, and indicator out to follow the interface
// orientation, compensating for the status-bar inset and, on the pre-iOS 8 path, applying a manual
// rotation transform to a free-standing (window or detached) presentation. The original is a long
// branch-heavy frame-arithmetic routine keyed on system version, Xcode-6 build, and hosting mode;
// this reconstruction preserves that structure and the observable frames rather than every
// intermediate register.
/** @ghidraAddress 0x24e100 */
- (void)rotateWebViewWithInterfaceOrientation:(UIInterfaceOrientation)orientation
                                     duration:(NSTimeInterval)duration {
    CGRect screenBounds = UIScreen.mainScreen.bounds;
    if (UIDevice.currentDevice.systemVersion.floatValue < kSystemVersionIOS7) {
        screenBounds = UIScreen.mainScreen.applicationFrame;
    }
    CGFloat width = screenBounds.size.width;
    CGFloat height = screenBounds.size.height;

    // Determine the status-bar inset. It is dropped for a hidden navigation bar on iOS 7+ and for a
    // hosted (non-window, parented) presentation.
    CGFloat statusInset;
    BOOL hosted = self.parentView && ![self.parentView isKindOfClass:[UIWindow class]] &&
                  [ApplilinkUtilities hasParentViewController:self.parentView];
    if (self.isNavigationBarHidden &&
        UIDevice.currentDevice.systemVersion.floatValue >= kSystemVersionIOS7) {
        statusInset = 0.0;
    } else if (hosted) {
        statusInset = 0.0;
    } else {
        CGRect statusBarFrame = UIApplication.sharedApplication.statusBarFrame;
        statusInset = statusBarFrame.size.height;
        if (width < statusInset) {
            statusInset = width;
        }
    }

    // The manual rotation transform is only applied on the pre-iOS 8 (or non-Xcode 6 build) path,
    // where UIKit does not rotate the window's content for us.
    BOOL legacyRotation = UIDevice.currentDevice.systemVersion.floatValue < kSystemVersionIOS8 ||
                          ![ApplilinkCore isBuildXcode6];
    CGFloat portraitWidth = MIN(width, height);
    CGFloat portraitHeight = MAX(width, height);
    if (legacyRotation) {
        CGAffineTransform transform;
        CGFloat viewWidth = portraitWidth;
        CGFloat viewHeight = portraitHeight;
        switch (orientation) {
        case UIInterfaceOrientationPortraitUpsideDown:
            // Rotate by pi (g_dPi at 0x28f278).
            transform = CGAffineTransformMakeRotation((CGFloat)M_PI);
            break;
        case UIInterfaceOrientationLandscapeRight:
            // pi/2, from the __const pool at 0x28f460.
            transform = CGAffineTransformMakeRotation((CGFloat)M_PI_2);
            viewWidth = portraitHeight;
            viewHeight = portraitWidth;
            break;
        case UIInterfaceOrientationLandscapeLeft:
            // -pi/2, from the __const pool at 0x291c00.
            transform = CGAffineTransformMakeRotation((CGFloat)(-M_PI_2));
            viewWidth = portraitHeight;
            viewHeight = portraitWidth;
            break;
        default:
            transform = CGAffineTransformMakeRotation(0);
            break;
        }
        if (hosted) {
            self.view.bounds = CGRectMake(0, statusInset, viewWidth, viewHeight);
        } else {
            CGRect boundsRect = CGRectMake(0, statusInset, viewWidth, viewHeight);
            [UIView animateWithDuration:duration
                             animations:^{
                               /** @ghidraAddress 0x24ef8c */
                               self.view.transform = transform;
                               self.view.bounds = boundsRect;
                             }];
        }
    }

    // Re-align the view frame for the current orientation and status inset.
    CGFloat originX = 0.0;
    CGFloat originY = 0.0;
    CGFloat viewWidth = _baseFrame.size.width;
    CGFloat viewHeight = _baseFrame.size.height;
    if (self.parentView) {
        viewWidth = self.parentView.frame.size.width;
        viewHeight = self.parentView.frame.size.height;
    }
    if (statusInset > 0.0) {
        float version = UIDevice.currentDevice.systemVersion.floatValue;
        if (version >= kSystemVersionIOS7) {
            if (version >= kSystemVersionIOS8 && [ApplilinkCore isBuildXcode6]) {
                UIInterfaceOrientation now = UIApplication.sharedApplication.statusBarOrientation;
                if (now == UIInterfaceOrientationLandscapeLeft) {
                    originX = statusInset;
                    originY = 0.0;
                } else if (now == UIInterfaceOrientationPortrait) {
                    originX = 0.0;
                    originY = statusInset;
                    viewHeight -= statusInset;
                }
            }
        } else {
            UIInterfaceOrientation now = UIApplication.sharedApplication.statusBarOrientation;
            if (now == UIInterfaceOrientationLandscapeLeft) {
                originX = statusInset;
            } else if (now == UIInterfaceOrientationPortrait) {
                originY = statusInset;
            }
        }
    }
    self.view.frame = CGRectMake(originX, originY, viewWidth, viewHeight);

    CGRect baseFrame = self.baseView.frame;
    if (self.isNavigationBarHidden) {
        [self.navigationBar removeFromSuperview];
        baseFrame = self.baseView.frame;
        baseFrame.origin.y = statusInset;
        baseFrame.size.height -= statusInset;
    } else {
        [self.navigationBar sizeToFit];
        baseFrame = self.baseView.frame;
        CGRect navFrame = self.navigationBar.frame;
        CGFloat baseInset = statusInset + navFrame.size.height;
        baseFrame.origin.y = baseInset;
        baseFrame.size.height -= baseInset;
        self.navigationBar.frame =
            CGRectMake(navFrame.origin.x, statusInset, navFrame.size.width, navFrame.size.height);
    }
    self.baseView.frame = baseFrame;

    self.indicator.frame = self.view.bounds;
    // The web view fills the base view starting from its origin.
    self.webView.frame =
        CGRectMake(0, 0, self.baseView.frame.size.width, self.baseView.frame.size.height);
}

#pragma mark - Loading

/** @ghidraAddress 0x24cd7c */
- (void)loadRequestWithURL:(NSString *)url parameters:(NSDictionary *)parameters {
    self.webViewStatus = RewardWebViewControllerWebViewStatusIdle;
    self.viewCloseFlg = NO;
    if (self.parentView) {
        [self.parentView addSubview:self.view];
    } else {
        UIWindow *mainWindow = [ApplilinkCore mainWindow];
        if (mainWindow) {
            [mainWindow addSubview:self.view];
        }
    }

    NSString *full = [ApplilinkUtilities appendParametersToURL:url parameters:parameters];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:full]];
    request.timeoutInterval = kRequestTimeout;
    request.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;

    if (!self.webView) {
        [self loadView];
    }
    [self rotateWebViewWithInterfaceOrientation:UIApplication.sharedApplication.statusBarOrientation
                                       duration:0.0];
    [self.webView loadRequest:request];
}

#pragma mark - Indicator

/** @ghidraAddress 0x24d130 */
- (void)updateIndicator:(BOOL)show {
    if (!self.indicator) {
        return;
    }
    if (show) {
        [self.indicator show];
        [RewardWebViewController cancelPreviousPerformRequestsWithTarget:self];
        [self performSelector:@selector(activeWebView)
                   withObject:nil
                   afterDelay:kIndicatorActivationDelay];
        return;
    }
    [self.indicator close];
    [RewardWebViewController cancelPreviousPerformRequestsWithTarget:self];
}

/** @ghidraAddress 0x24d1f4 */
- (void)activeWebView {
    if (self.indicator) {
        [self.indicator touchEventActived];
    }
}

#pragma mark - UIWebViewDelegate

/** @ghidraAddress 0x24d59c */
- (BOOL)webView:(UIWebView *)webView
    shouldStartLoadWithRequest:(NSURLRequest *)request
                navigationType:(UIWebViewNavigationType)navigationType {
    int redirect = [self redirectWithRequest:request];
    switch (redirect) {
    case kRedirectPathSegmentOpened:
    case kRedirectAppStoreShown:
        // A URL was opened or the store was shown; cancel the request.
        return NO;

    case kRedirectReloadWithCookies: {
        // Re-issue the redirect with the applilink-domain cookies attached.
        NSMutableURLRequest *mutableRequest = (NSMutableURLRequest *)request;
        mutableRequest.timeoutInterval = kRequestTimeout;
        mutableRequest.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        NSMutableArray<NSHTTPCookie *> *cookies = [NSMutableArray array];
        for (NSHTTPCookie *cookie in NSHTTPCookieStorage.sharedHTTPCookieStorage.cookies) {
            if ([cookie.domain hasSuffix:ApplilinkConsts.cookieDomain]) {
                [cookies addObject:cookie];
            }
        }
        if (cookies.count != 0) {
            mutableRequest.allHTTPHeaderFields =
                [NSHTTPCookie requestHeaderFieldsWithCookies:cookies];
        }
        [self.webView loadRequest:mutableRequest];
        return NO;
    }

    case kRedirectClose:
        [self btnCloseClicked:nil];
        return NO;

    default:
        break;
    }

    // The default routes (not resolved, or a default-scheme URL opened) test the request itself for
    // a close navigation, then for the applilink ext-app movie scheme.
    if (request) {
        NSString *absolute = request.URL.absoluteString;
        if ([absolute isEqualToString:kCloseNavigation] ||
            [request.URL.absoluteString hasPrefix:kCloseNavigationPrefix]) {
            [self btnCloseClicked:nil];
            return NO;
        }
    }

    NSURL *url = request.URL;
    NSString *scheme = url.scheme;
    NSString *host = url.host;
    int port = url.port.intValue;
    NSString *query = url.query;
    if (scheme && [scheme hasPrefix:kApplilinkScheme] && host &&
        [host isEqualToString:kExtAppHost] && port == kExtAppPort && request) {
        if ([request.URL.absoluteString hasPrefix:kExtAppMovieURLPrefix] && query) {
            [self showVideoViewWithQuery:query];
            return NO;
        }
    }
    // Only the genuinely unresolved route proceeds with the load.
    return redirect == kRedirectNotResolved;
}

/** @ghidraAddress 0x24d22c */
- (void)webViewDidStartLoad:(UIWebView *)webView {
    if (self.webViewStatus == RewardWebViewControllerWebViewStatusIdle) {
        self.webViewStatus = RewardWebViewControllerWebViewStatusLoading;
    }
    [self updateIndicator:YES];
}

/** @ghidraAddress 0x24d258 */
- (void)webViewDidFinishLoad:(UIWebView *)webView {
    self.webViewStatus = RewardWebViewControllerWebViewStatusFinished;
    [self updateIndicator:NO];
    NSString *query = webView.request.URL.query;
    if (query && [query rangeOfString:kCloseCommandQuery].location != NSNotFound) {
        [self btnCloseClicked:nil];
    } else {
        [self appListDidAppear];
    }
}

/** @ghidraAddress 0x24d38c */
- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    [self updateIndicator:NO];
    if (error.code == kWebErrorCancelled) {
        return;
    }
    if (error.code == kWebErrorFrameLoadFailed && [error.domain isEqual:kWebKitErrorDomain]) {
        return;
    }
    if (error.code == kWebErrorPlugInLoadFailed && [error.domain isEqual:kWebKitErrorDomain]) {
        return;
    }
    if (self.webViewStatus == RewardWebViewControllerWebViewStatusFinished &&
        error.code == kWebErrorNotConnected) {
        NSError *linkError = [NSError errorWithDomain:error.domain code:error.code userInfo:nil];
        [self appListFailLinkWithError:linkError];
    } else {
        [self appListFailLoadWithError:error];
        [self btnCloseClicked:nil];
    }
}

/** @ghidraAddress 0x24dbe0 */
- (int)redirectWithRequest:(NSURLRequest *)request {
    return [[RewardCore sharedInstance] redirectWithRequest:request];
}

#pragma mark - Video and close relays

/** @ghidraAddress 0x24d018 */
- (void)showVideoViewWithQuery:(NSString *)query {
    [[RewardCore sharedInstance] showVideoViewWithQuery:query];
}

/** @ghidraAddress 0x24dc64 */
- (void)closeNotice:(id)view {
    [[ApplilinkViewManager sharedInstance] closeNotice:view];
}

/** @ghidraAddress 0x24d008 */
- (void)btnCloseClicked:(id)sender {
    [self appListDidDisappear];
}

/** @ghidraAddress 0x24d090 */
- (void)appliListClosed {
    [RewardWebViewController cancelPreviousPerformRequestsWithTarget:self];
    if (self.viewCloseFlg) {
        return;
    }
    self.viewCloseFlg = YES;
    if (self.webView.isLoading) {
        [self.webView stopLoading];
    }
    [self viewDealloc];
}

/** @ghidraAddress 0x24cc54 */
- (void)viewDealloc {
    [self.indicator removeFromSuperview];
    if (self.webView) {
        self.webView.delegate = nil;
        if (self.webView) {
            [self.webView removeFromSuperview];
        }
    }
    [self.navigationBar removeFromSuperview];
    _indicator = nil;
    _navigationBar = nil;
    _webView = nil;
    _parentView = nil;
    [self.view removeFromSuperview];
}

/** @ghidraAddress 0x24f208 */
- (void)clearDelegate {
    self.sdkDelegate = nil;
    if (self.webView) {
        self.webView.delegate = nil;
    }
}

// This SDK-facing alias stores straight into the isNavigationBarHidden backing ivar.
/** @ghidraAddress 0x24cd64 */
- (void)setNavigationBarHidden:(BOOL)navigationBarHidden {
    _isNavigationBarHidden = navigationBarHidden;
}

// The backing store is inverted: the getter returns the raw flag but the setter stores its
// complement, so a caller asking to enable bounces clears the stored value that -loadView negates.
/** @ghidraAddress 0x24d218 */
- (void)setWebViewBounces:(BOOL)webViewBounces {
    _webViewBounces = !webViewBounces;
}

#pragma mark - Delegate notices

/** @ghidraAddress 0x24dcdc */
- (void)appListDidStart {
    if (self.sdkDelegate && [self.sdkDelegate respondsToSelector:@selector(startedNotice)]) {
        [self.sdkDelegate startedNotice];
    }
}

/** @ghidraAddress 0x24dd90 */
- (void)appListDidAppear {
    if (self.sdkDelegate && [self.sdkDelegate respondsToSelector:@selector(openedNotice)]) {
        [self.sdkDelegate openedNotice];
    }
}

/** @ghidraAddress 0x24de44 */
- (void)appListDidDisappear {
    if (self.sdkDelegate) {
        if ([self.sdkDelegate respondsToSelector:@selector(closeNotice)]) {
            [self.sdkDelegate closeNotice];
        }
        self.sdkDelegate = nil;
    }
}

/** @ghidraAddress 0x24df04 */
- (void)appListFailLoadWithError:(NSError *)error {
    if (self.sdkDelegate) {
        if ([self.sdkDelegate respondsToSelector:@selector(failOpenNoticeWithError:)]) {
            [self.sdkDelegate failOpenNoticeWithError:error];
        }
        self.sdkDelegate = nil;
    }
}

/** @ghidraAddress 0x24dfc8 */
- (void)appListFailLinkWithError:(NSError *)error {
    if (self.sdkDelegate &&
        [self.sdkDelegate respondsToSelector:@selector(failLinkNoticeWithError:)]) {
        [self.sdkDelegate failLinkNoticeWithError:error];
    }
}

#pragma mark - Responder chain

// Walks a responder up its chain to decide whether it resolves to a presentable host: a window or
// application does not, a plain view recurses to its next responder, and a view controller does.
/** @ghidraAddress 0x24f0d4 */
- (BOOL)hasParentViewController:(UIResponder *)responder {
    if ([responder isKindOfClass:[UIWindow class]] ||
        [responder isKindOfClass:[UIApplication class]]) {
        return NO;
    }
    if ([responder isKindOfClass:[UIView class]]) {
        return [self hasParentViewController:responder.nextResponder];
    }
    return [responder isKindOfClass:[UIViewController class]];
}

@end
