#import "NotificationPageViewController.h"

#import "AlertViewManager.h"
#import "JubeatAppDelegate.h"

// The navigation-bar title, the constant "INFORMATION" at 0x289078.
static NSString *const kNotificationTitle = @"INFORMATION";

// The web view / indicator geometry. On iPad the web view is a fixed size; on the handset it
// follows the screen bounds less a top inset. This matches the inquiry page's layout.
static const CGFloat kPadWidth = 540.0;         // 0x28f900
static const CGFloat kPadHeight = 576.0;        // 0x291d88
static const CGFloat kPhoneHeightInset = -44.0; // 0x28f1d0

// The loading indicator: a fixed 42-point square centred on the web view, offset by half its size
// horizontally and by 42 points vertically, and drawn at double scale. The horizontal offset of
// -21.0 and the centre and scale factors (0.5 and 2.0) reach the code as fmov immediates (the
// -21.0 fmov immediate is at 0x1ea720).
static const CGFloat kIndicatorSize = 42.0;      // 0x28f758
static const CGFloat kIndicatorHalfSize = -21.0; // fmov immediate at 0x1ea720
static const CGFloat kIndicatorOffsetY = -42.0;  // 0x291dc0
static const CGFloat kCentreHalf = 0.5;
static const CGFloat kIndicatorScale = 2.0;

// The default request timeout the notification request uses (the fmov immediate 10.0 at 0x1ea8a4).
static const NSTimeInterval kRequestTimeout = 10.0;

// The custom link schemes the page emits. A twitter:// link is blocked, an openurl:// link opens
// externally as https://, and a jbtstore://.../pack/<id> link moves the delegate to the store.
static NSString *const kTwitterScheme = @"twitter://";
static NSString *const kOpenURLPrefix = @"openurl://";
static NSString *const kHTTPSPrefix = @"https://";
static NSString *const kStoreScheme = @"jbtstore";
static NSString *const kPackPathComponent = @"pack";

// The number of path components a store deep link carries: the leading "/", the "pack" segment,
// and the pack identifier.
static const NSInteger kStorePathComponentCount = 3;
static const NSInteger kPackSegmentIndex = 1;
static const NSInteger kPackIDIndex = 2;

// The HTTP header the resource hook stamps with the app's user agent.
static NSString *const kUserAgentHeaderField = @"User-Agent";

// The JavaScript the finished callback injects to disable the WebKit touch-callout menu.
static NSString *const kDisableTouchCalloutJS =
    @"document.documentElement.style.webkitTouchCallout='none';";

// The network-error alert message, a Japanese literal in the binary, "communication error".
static NSString *const kNetworkErrorMessage = @"通信エラー";

// The key under which the OK button title is localised.
static NSString *const kOKKey = @"OK";

@implementation NotificationPageViewController {
    UIWebView *notificationPage;                                // +0x8
    __weak id<NotificationPageViewControllerDelegate> delegate; // +0x10
    UIActivityIndicatorView *indicatorView;                     // +0x18
    EditorIDManager *idManager;                                 // +0x20
    NSURLRequest *firstRequest;                                 // +0x28
}

#pragma mark - Construction

/** @ghidraAddress 0x1ea528 */
- (void)initPage:(id<NotificationPageViewControllerDelegate>)delegateIn {
    self.navigationItem.title = kNotificationTitle;
    delegate = delegateIn;

    CGFloat width;
    CGFloat height;
    if (JubeatAppDelegate.appDelegate.isPad) {
        width = kPadWidth;
        height = kPadHeight;
    } else {
        CGRect bounds = UIScreen.mainScreen.bounds;
        width = bounds.size.width;
        height = bounds.size.height + kPhoneHeightInset;
    }

    notificationPage = [[UIWebView alloc] initWithFrame:CGRectMake(0.0, 0.0, width, height)];
    notificationPage.scalesPageToFit = YES;
    notificationPage.delegate = self;
    notificationPage.dataDetectorTypes = UIDataDetectorTypeNone;
    [self.view addSubview:notificationPage];

    indicatorView = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    [indicatorView setFrame:CGRectMake(width * kCentreHalf + kIndicatorHalfSize,
                                       height * kCentreHalf + kIndicatorOffsetY,
                                       kIndicatorSize,
                                       kIndicatorSize)];
    indicatorView.transform = CGAffineTransformMakeScale(kIndicatorScale, kIndicatorScale);
    indicatorView.hidesWhenStopped = YES;
    [indicatorView startAnimating];
    [self.view addSubview:indicatorView];
}

/** @ghidraAddress 0x1ea82c */
- (void)notificationRequest {
    NSURLRequest *request = firstRequest;
    if (request == nil) {
        request = [NSURLRequest requestWithURL:JubeatAppDelegate.appDelegate.notificationURL
                                   cachePolicy:NSURLRequestUseProtocolCachePolicy
                               timeoutInterval:kRequestTimeout];
    }
    [notificationPage loadRequest:request];
}

/** @ghidraAddress 0x1ea914 */
- (instancetype)init:(id<NotificationPageViewControllerDelegate>)delegateIn {
    self = [super init];
    if (self) {
        [self initPage:delegateIn];
        firstRequest = [NSURLRequest requestWithURL:JubeatAppDelegate.appDelegate.notificationURL
                                        cachePolicy:NSURLRequestUseProtocolCachePolicy
                                    timeoutInterval:kRequestTimeout];
        if (EditorIDManager.isExistEditorID) {
            [self notificationRequest];
        } else {
            idManager = [[EditorIDManager alloc] initWithDelegate:self];
        }
    }
    return self;
}

/** @ghidraAddress 0x1eaa8c */
- (instancetype)initWithURL:(NSURL *)url
                   delegate:(id<NotificationPageViewControllerDelegate>)delegateIn {
    self = [super init];
    if (self) {
        [self initPage:delegateIn];
        firstRequest = [NSURLRequest requestWithURL:url];
        if (EditorIDManager.isExistEditorID) {
            [self notificationRequest];
        } else {
            idManager = [[EditorIDManager alloc] initWithDelegate:self];
        }
    }
    return self;
}

#pragma mark - UIWebViewDelegate

/** @ghidraAddress 0x1eabc0 */
- (NSURLRequest *)uiWebView:(id)uiWebView
                   resource:(id)resource
            willSendRequest:(NSMutableURLRequest *)request
           redirectResponse:(NSURLResponse *)redirectResponse
             fromDataSource:(id)dataSource {
    NSString *userAgent = JubeatAppDelegate.appDelegate.userAgent;
    if (EditorIDManager.isExistEditorID) {
        // A no-op reformat of the same user agent through "%@", as the binary does.
        userAgent = [NSString stringWithFormat:@"%@", JubeatAppDelegate.appDelegate.userAgent];
    }
    [request setValue:userAgent forHTTPHeaderField:kUserAgentHeaderField];
    return request;
}

/** @ghidraAddress 0x1ead08 */
- (BOOL)webView:(UIWebView *)webView
    shouldStartLoadWithRequest:(NSURLRequest *)request
                navigationType:(UIWebViewNavigationType)navigationType {
    // Only a user-clicked link (navigation type 0) is inspected; other navigations pass through.
    if (navigationType != UIWebViewNavigationTypeLinkClicked) {
        return YES;
    }
    if (request.URL == nil) {
        return YES;
    }
    NSString *absoluteString = request.URL.absoluteString;
    NSURL *url = request.URL;
    // A twitter:// link is blocked without further action.
    if ([absoluteString rangeOfString:kTwitterScheme].location != NSNotFound) {
        return NO;
    }
    if ([absoluteString rangeOfString:kOpenURLPrefix].location != NSNotFound) {
        // An openurl:// link opens externally as https://.
        NSString *external = [absoluteString stringByReplacingOccurrencesOfString:kOpenURLPrefix
                                                                       withString:kHTTPSPrefix];
        [UIApplication.sharedApplication openURL:[NSURL URLWithString:external]];
        return NO;
    }
    // A jbtstore://.../pack/<id> link is turned into a {@"pack": <id>} dictionary and delivered to
    // the delegate. Any other scheme passes through.
    if (![url.scheme isEqualToString:kStoreScheme]) {
        return YES;
    }
    NSDictionary<NSString *, NSString *> *packInfomation = nil;
    if (url.pathComponents.count == kStorePathComponentCount &&
        [url.pathComponents[kPackSegmentIndex] isEqualToString:kPackPathComponent]) {
        packInfomation = @{kPackPathComponent : url.pathComponents[kPackIDIndex]};
    }
    if ([delegate respondsToSelector:@selector(clickPackInfomation:)]) {
        [delegate performSelector:@selector(clickPackInfomation:) withObject:packInfomation];
    }
    return NO;
}

/** @ghidraAddress 0x1eb108 */
- (void)stopIndicator {
    if (indicatorView != nil) {
        [indicatorView stopAnimating];
        [indicatorView removeFromSuperview];
        indicatorView = nil;
    }
}

/** @ghidraAddress 0x1eb164 */
- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    NSString *okTitle = [NSBundle.mainBundle localizedStringForKey:kOKKey value:@"" table:nil];
    [AlertViewManager.sharedManager makeAlert:0
                                     delegate:nil
                                          tag:0
                                        title:nil
                                          msg:kNetworkErrorMessage
                                       cancel:okTitle
                                      btnText:nil
                                         show:YES
                               viewController:self];
    [self stopIndicator];
}

/** @ghidraAddress 0x1eb25c */
- (void)webViewDidStartLoad:(UIWebView *)webView {
    [NSURLCache.sharedURLCache removeAllCachedResponses];
}

/** @ghidraAddress 0x1eb2a4 */
- (void)webViewDidFinishLoad:(UIWebView *)webView {
    [self stopIndicator];
    [webView stringByEvaluatingJavaScriptFromString:kDisableTouchCalloutJS];
}

#pragma mark - Store navigation

/** @ghidraAddress 0x1eb314 */
- (void)moveStore:(id)store packID:(NSString *)packID {
    if ([delegate respondsToSelector:@selector(moveStore:packID:)]) {
        // The binary reloads the delegate and passes it back as the "store" argument, so the
        // delegate receives itself here rather than a distinct store object.
        [delegate performSelector:@selector(moveStore:packID:)
                       withObject:delegate
                       withObject:packID];
    }
}

#pragma mark - EditorIDManagerDelegate

/** @ghidraAddress 0x1eb404 */
- (void)errorIDDownload:(id)manager msgStr:(NSString *)msgStr {
    [self notificationRequest];
}

/** @ghidraAddress 0x1eb410 */
- (void)successIDDownload:(id)manager {
    [self notificationRequest];
}

#pragma mark - Rotation

/** @ghidraAddress 0x1eb41c */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Portrait and portrait-upside-down (orientations 1 and 2), matching the mask of 6 below. The
    // binary tests (orientation - 1) as unsigned, so any other value (including 0) is refused.
    return (unsigned int)(interfaceOrientation - 1) < 2;
}

/** @ghidraAddress 0x1eb42c */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    // The binary returns the literal 6, i.e. portrait and portrait-upside-down.
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

/** @ghidraAddress 0x1eb434 */
- (BOOL)shouldAutorotate {
    return YES;
}

#pragma mark - Lifecycle

/** @ghidraAddress 0x1eb3bc */
- (void)viewWillDisappear:(BOOL)animated {
    [AlertViewManager.sharedManager closeAlert];
}

@end
