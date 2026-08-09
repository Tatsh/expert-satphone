#import "SettingsInquiryViewController.h"

#import "AlertViewManager.h"
#import "EditorIDManager.h"
#import "JubeatAppDelegate.h"
#import "ScratchUtil.h"

// The navigation-bar title, a Japanese literal in the binary, "inquiry"/"contact".
static NSString *const kInquiryTitle = @"お問い合わせ";

// The web view / indicator geometry. On iPad the web view is a fixed size; on the handset it
// follows the screen bounds less a top inset.
static const CGFloat kPadWidth = 540.0;         // 0x28f900
static const CGFloat kPadHeight = 576.0;        // 0x291d88
static const CGFloat kPhoneHeightInset = -44.0; // 0x28f1d0

// The loading indicator: a fixed 42-point square centred on the web view, offset by half its size
// horizontally and by 42 points vertically, and drawn at double scale. The horizontal offset of
// -21.0 and the centre and scale factors (0.5 and 2.0) reach the code as fmov immediates (the
// -21.0 fmov immediate is at 0xd8bac).
static const CGFloat kIndicatorSize = 42.0;      // 0x28f758
static const CGFloat kIndicatorHalfSize = -21.0; // fmov immediate at 0xd8bac
static const CGFloat kIndicatorOffsetY = -42.0;  // 0x291dc0
static const CGFloat kCentreHalf = 0.5;
static const CGFloat kIndicatorScale = 2.0;

// The custom link scheme the page emits, and its external-load replacement.
static NSString *const kOpenURLPrefix = @"openurl://";
static NSString *const kHTTPSPrefix = @"https://";

// The HTTP header the resource hook stamps with the app's user agent.
static NSString *const kUserAgentHeaderField = @"User-Agent";

// The network-error alert message, a Japanese literal in the binary, "communication error".
static NSString *const kNetworkErrorMessage = @"通信エラー";

// The key under which the OK button title is localised.
static NSString *const kOKKey = @"OK";

@implementation SettingsInquiryViewController {
    UIActivityIndicatorView *indicatorView; // +0x8
    BOOL bSuccess;                          // +0x10
    UIWebView *InquiryPage;                 // +0x18
    NSURLRequest *nextUrlRequest;           // +0x20
    EditorIDManager *eidMan;                // +0x28
    BOOL bURLStart;                         // +0x30
}

#pragma mark - Construction

/** @ghidraAddress 0xd8908 */
- (instancetype)init {
    self = [super init];
    if (self) {
        [self initPageView];
    }
    return self;
}

/** @ghidraAddress 0xd8964 */
- (void)initPageView {
    nextUrlRequest = [NSURLRequest requestWithURL:ScratchUtil.getInquiryURL];
    self.navigationItem.title = kInquiryTitle;

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

    InquiryPage = [[UIWebView alloc] initWithFrame:CGRectMake(0.0, 0.0, width, height)];
    InquiryPage.scalesPageToFit = YES;
    InquiryPage.delegate = self;
    InquiryPage.dataDetectorTypes = UIDataDetectorTypeNone;
    [self.view addSubview:InquiryPage];
    [InquiryPage loadRequest:nextUrlRequest];

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

/** @ghidraAddress 0xd8ccc */
- (instancetype)initWithURL:(NSString *)url {
    self = [super init];
    if (self) {
        bURLStart = YES;
        nextUrlRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
        self.navigationItem.title = kInquiryTitle;
    }
    return self;
}

#pragma mark - UIWebViewDelegate

/** @ghidraAddress 0xd8de4 */
- (void)webViewDidStartLoad:(UIWebView *)webView {
    [NSURLCache.sharedURLCache removeAllCachedResponses];
}

/** @ghidraAddress 0xd8e2c */
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

/** @ghidraAddress 0xd8f74 */
- (BOOL)webView:(UIWebView *)webView
    shouldStartLoadWithRequest:(NSURLRequest *)request
                navigationType:(UIWebViewNavigationType)navigationType {
    // The binary does not gate on navigationType here; only the URL scheme matters.
    if (request.URL != nil) {
        NSString *absoluteString = request.URL.absoluteString;
        if ([absoluteString rangeOfString:kOpenURLPrefix].location != NSNotFound) {
            // An openurl:// link opens externally as https:// and pops this controller.
            NSString *external = [absoluteString stringByReplacingOccurrencesOfString:kOpenURLPrefix
                                                                           withString:kHTTPSPrefix];
            [UIApplication.sharedApplication openURL:[NSURL URLWithString:external]];
            [self.navigationController popViewControllerAnimated:NO];
            return NO;
        }
    }
    return YES;
}

/** @ghidraAddress 0xd912c */
- (void)webViewDidFinishLoad:(UIWebView *)webView {
    if (indicatorView != nil) {
        [indicatorView stopAnimating];
        [indicatorView removeFromSuperview];
        indicatorView = nil;
    }
}

/** @ghidraAddress 0xd9188 */
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
}

#pragma mark - Rotation

/** @ghidraAddress 0xd9270 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Portrait and portrait-upside-down (orientations 1 and 2), matching the mask of 6 below. The
    // binary tests (orientation - 1) as unsigned, so any other value (including 0) is refused.
    return (unsigned int)(interfaceOrientation - 1) < 2;
}

/** @ghidraAddress 0xd9280 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    // The binary returns the literal 6, i.e. portrait and portrait-upside-down.
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

/** @ghidraAddress 0xd9288 */
- (BOOL)shouldAutorotate {
    return YES;
}

#pragma mark - Lifecycle

/** @ghidraAddress 0xd9290 */
- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

/** @ghidraAddress 0xd930c */
- (void)viewWillDisappear:(BOOL)animated {
    [AlertViewManager.sharedManager closeAlert];
}

/** @ghidraAddress 0xd9354 */
- (void)viewDidAppear:(BOOL)animated {
    // The binary's implementation is empty (it does not chain up to super).
}

@end
