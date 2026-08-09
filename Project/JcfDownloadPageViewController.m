#import "JcfDownloadPageViewController.h"

#import <Social/Social.h>

#import "AlertViewManager.h"
#import "JubeatAppDelegate.h"
#import "jubeatLabAccess.h"

// The download page's fixed board size on a pad; a phone derives its size from the screen.
static const CGFloat kDownloadPageWidthPad = 540.0;  // @ghidraAddress 0x28f900
static const CGFloat kDownloadPageHeightPad = 576.0; // @ghidraAddress 0x291d88
// Added to the phone screen height to leave room for the navigation bar.
static const CGFloat kDownloadPagePhoneHeightInset = -44.0; // @ghidraAddress 0x28f1d0

// The spinner is a 42-point square placed relative to the board's centre, then doubled in scale.
static const CGFloat kIndicatorSize = 42.0;          // @ghidraAddress 0x28f758
static const CGFloat kIndicatorCentreYInset = -42.0; // @ghidraAddress 0x291dc0

// The dimming cover behind the download modal.
static const CGFloat kTopcoverAlpha = 0.30000001192092896; // @ghidraAddress 0x28f248

// The overlay fade timings. The reveal is a positive 0.2s; the tear-down animations pass a
// negative duration verbatim, which is how the binary was built.
static const NSTimeInterval kRevealDownloadOverlayDuration = 0.2; // @ghidraAddress 0x28e040
static const NSTimeInterval kHideDownloadOverlayDuration = -0.2;  // @ghidraAddress 0x28e050

// The custom URL scheme the download page uses to signal the native side.
static NSString *const kJubeatPlusScheme = @"jubeatplus";
// The Twitter share is signalled by a link with this prefix inside the custom scheme.
static NSString *const kTwitterSharePrefix = @"twitter://";
// The sentinel sequence index the close callback always reports.
static NSString *const kCloseSeqIndexNone = @"none";
// The navigation-bar title shared by every entry point.
static NSString *const kPageTitle = @"jubeat Lab.";
// The class probed at runtime to decide whether Social-framework sharing is available.
static NSString *const kSocialComposerClassName = @"SLComposeViewController";

// The number of characters that separates a custom-download link from an ordinary one: the
// download modal opens only when the trimmed resource specifier is at most this long.
static const NSUInteger kMaxCustomDownloadIDLength = 14;

@implementation JcfDownloadPageViewController {
    UIActivityIndicatorView *indicatorView;                    // +0x08
    NSURLRequest *requestURL;                                  // +0x10
    unsigned int sequenceID;                                   // +0x18
    BOOL bSuccess;                                             // +0x1c
    __weak id<JcfDownloadPageViewControllerDelegate> delegate; // +0x20
    UIWebView *downloadPage;                                   // +0x28
    JcfDownloadView *downloadView;                             // +0x30
    UIView *topcover;                                          // +0x38
    BOOL bDownloading;                                         // +0x40
    NSURLRequest *nextUrlRequest;                              // +0x48
    jubeatLabAccess *sessionDownloader;                        // +0x50
    UIAlertView *sessionAlert;                                 // +0x58
    UIAlertView *webAlert;                                     // +0x60
    EditorIDManager *eidMan;                                   // +0x68
    BOOL bEnableSocialFrameWork;                               // +0x70
    NSString *socialString;                                    // +0x78
    BOOL bOpenTwitter;                                         // +0x80
    BOOL bURLStart;                                            // +0x81
    BOOL _bFromNavigate;                                       // +0x82
    BOOL _bCloseStoreMove;                                     // +0x83
}

#pragma mark - Setup

/** @ghidraAddress 0x1e6648 */
- (void)initPageView {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appSuspended:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];

    CGFloat pageWidth;
    CGFloat pageHeight;
    if (JubeatAppDelegate.appDelegate.isPad) {
        pageWidth = kDownloadPageWidthPad;
        pageHeight = kDownloadPageHeightPad;
    } else {
        CGRect screen = UIScreen.mainScreen.bounds;
        pageWidth = screen.size.width;
        pageHeight = screen.size.height + kDownloadPagePhoneHeightInset;
    }

    // The frame origin is the zero of CGRectZero.
    downloadPage = [[UIWebView alloc] initWithFrame:CGRectMake(0.0, 0.0, pageWidth, pageHeight)];
    downloadPage.scalesPageToFit = YES;
    downloadPage.delegate = self;
    downloadPage.dataDetectorTypes = UIDataDetectorTypeNone;
    [self.view addSubview:downloadPage];
    if (requestURL) {
        [downloadPage loadRequest:requestURL];
    }
    _bFromNavigate = NO;

    // The spinner is centred horizontally over the board (half its unscaled width to the left of
    // centre) and raised above the vertical centre by its scaled half-height. The -21.0 x-offset
    // is an fmov immediate.
    CGFloat indicatorX = pageWidth * 0.5 - 21.0;
    CGFloat indicatorY = pageHeight * 0.5 + kIndicatorCentreYInset;
    indicatorView = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [indicatorView setFrame:CGRectMake(indicatorX, indicatorY, kIndicatorSize, kIndicatorSize)];
    // The 2.0 scale factors are fmov immediates.
    indicatorView.transform = CGAffineTransformMakeScale(2.0, 2.0);
    indicatorView.hidesWhenStopped = YES;
    [indicatorView startAnimating];
    [self.view addSubview:indicatorView];

    _bCloseStoreMove = NO;
    bEnableSocialFrameWork = NO;
    if (NSClassFromString(kSocialComposerClassName) != nil) {
        bEnableSocialFrameWork = YES;
    }
}

#pragma mark - Initialisers

/** @ghidraAddress 0x1e699c */
- (instancetype)initWithMusicID:(unsigned int)musicID
                       delegate:(nullable id<JcfDownloadPageViewControllerDelegate>)delegateArg {
    self = [super init];
    if (self) {
        bURLStart = NO;
        bDownloading = NO;
        delegate = delegateArg;
        requestURL =
            [NSURLRequest requestWithURL:[jubeatLabAccess getSequenceSerchURL:(int)musicID]];
        self.navigationItem.title = kPageTitle;
    }
    return self;
}

/** @ghidraAddress 0x1e6ad4 */
- (instancetype)initWithSequenceID:(nullable NSString *)sequenceIDArg
                          delegate:(nullable id<JcfDownloadPageViewControllerDelegate>)delegateArg {
    self = [super init];
    if (self) {
        bURLStart = NO;
        delegate = delegateArg;
        requestURL =
            [NSURLRequest requestWithURL:[jubeatLabAccess getSequencePageURL:sequenceIDArg]];
        self.navigationItem.title = kPageTitle;
    }
    return self;
}

/** @ghidraAddress 0x1e6c1c */
- (instancetype)initWithURL:(nullable NSString *)url
                   delegate:(nullable id<JcfDownloadPageViewControllerDelegate>)delegateArg {
    self = [super init];
    if (self) {
        bURLStart = YES;
        delegate = delegateArg;
        nextUrlRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
        self.navigationItem.title = kPageTitle;
    }
    return self;
}

#pragma mark - UIWebView resource loading

/** @ghidraAddress 0x1e6d68 */
- (nullable NSURLRequest *)uiWebView:(nullable id)webView
                            resource:(nullable id)resource
                     willSendRequest:(nullable NSURLRequest *)request
                    redirectResponse:(nullable NSURLResponse *)redirectResponse
                      fromDataSource:(nullable id)dataSource {
    NSString *userAgent = JubeatAppDelegate.appDelegate.userAgent;
    if (EditorIDManager.isExistEditorID) {
        userAgent = [NSString stringWithFormat:@"%@", JubeatAppDelegate.appDelegate.userAgent];
    }
    [(NSMutableURLRequest *)request setValue:userAgent forHTTPHeaderField:@"User-Agent"];
    return request;
}

#pragma mark - UIWebViewDelegate

/** @ghidraAddress 0x1e6eb0 */
- (void)webViewDidStartLoad:(nullable UIWebView *)webView {
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
}

/** @ghidraAddress 0x1e6fe8 */
- (BOOL)webView:(nullable UIWebView *)webView
    shouldStartLoadWithRequest:(nullable NSURLRequest *)request
                navigationType:(UIWebViewNavigationType)navigationType {
    if ([request.URL isEqual:[jubeatLabAccess getUserPageSessionFailedURL]]) {
        sessionDownloader = [[jubeatLabAccess alloc] initTopPageSessionApi:self];
        [sessionDownloader startAccess];
        return NO;
    }

    if (navigationType != UIWebViewNavigationTypeLinkClicked) {
        return YES;
    }
    if (bDownloading) {
        return NO;
    }

    if ([request.URL.scheme isEqualToString:kJubeatPlusScheme]) {
        NSString *customID = [request.URL.resourceSpecifier substringFromIndex:2];
        if (customID.length <= kMaxCustomDownloadIDLength) {
            topcover = [[UIView alloc] initWithFrame:self.view.bounds];
            topcover.center =
                CGPointMake(self.view.bounds.size.width * 0.5, self.view.bounds.size.height * 0.5);
            topcover.opaque = NO;
            // The original used the full component call.
            topcover.backgroundColor = [UIColor colorWithWhite:0.0 alpha:kTopcoverAlpha];

            downloadView = [[JcfDownloadView alloc] initWithID:customID delegate:self];
            [downloadView startDownload];
            [self.view addSubview:topcover];
            [self.view addSubview:downloadView];
            downloadView.center =
                CGPointMake(self.view.bounds.size.width * 0.5, self.view.bounds.size.height * 0.5);
            downloadView.alpha = 0.0;

            __weak UIView *weakTopcover = topcover;
            __weak JcfDownloadView *weakDownloadView = downloadView;
            [UIView animateWithDuration:kRevealDownloadOverlayDuration
                             animations:^{
                               /** @ghidraAddress 0x1e7748 */
                               weakTopcover.alpha = 1.0;
                               weakDownloadView.alpha = 1.0;
                             }
                             completion:^(BOOL finished){
                                 /** @ghidraAddress 0x1e781c */
                             }];

            if (_bFromNavigate) {
                [self.navigationItem setHidesBackButton:YES];
            } else {
                self.navigationItem.leftBarButtonItem.enabled = NO;
            }
            bDownloading = YES;
            return NO;
        }
        nextUrlRequest = request;
    }

    if ([request.URL.absoluteString rangeOfString:kTwitterSharePrefix].location == NSNotFound) {
        return YES;
    }
    socialString = [[request.URL.absoluteString stringByRemovingPercentEncoding]
        stringByReplacingOccurrencesOfString:kTwitterSharePrefix
                                  withString:@""];
    [self sendTwitter];
    return NO;
}

/** @ghidraAddress 0x1e7820 */
- (void)webViewDidFinishLoad:(nullable UIWebView *)webView {
    if (indicatorView != nil) {
        [indicatorView stopAnimating];
        [indicatorView removeFromSuperview];
        indicatorView = nil;
    }
}

/** @ghidraAddress 0x1e787c */
- (void)webView:(nullable UIWebView *)webView didFailLoadWithError:(nullable NSError *)error {
    NSString *okTitle = [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil];
    // The default "communication error" message, read from __const at 0x2d7200.
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:self
                                            tag:0
                                          title:nil
                                            msg:@"通信エラー"
                                         cancel:okTitle
                                        btnText:nil
                                           show:YES
                                 viewController:self];
}

#pragma mark - Download modal

/** @ghidraAddress 0x1e7964 */
- (void)removeDownloadView {
    [topcover removeFromSuperview];
    topcover = nil;
    [downloadView removeFromSuperview];
    downloadView = nil;
    if (_bFromNavigate) {
        [self.navigationItem setHidesBackButton:NO];
    } else {
        self.navigationItem.leftBarButtonItem.enabled = YES;
    }
}

/** @ghidraAddress 0x1e7a4c */
- (void)jcfDownloadEnd:(nullable JcfDownloadView *)view {
    __weak UIView *weakTopcover = topcover;
    __weak JcfDownloadView *weakDownloadView = downloadView;
    [UIView animateWithDuration:kHideDownloadOverlayDuration
        animations:^{
          /** @ghidraAddress 0x1e7d00 */
          weakTopcover.alpha = 0.0;
          weakDownloadView.alpha = 0.0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x1e7dc8 */
          [self removeDownloadView];
        }];

    // The binary passes the delegate itself as the callback's object argument.
    if ([delegate respondsToSelector:@selector(downloadEnd:)]) {
        [delegate performSelector:@selector(downloadEnd:) withObject:delegate];
    }
    NSNumber *musicID = @([downloadView getDownloadMusicID]);
    if ([delegate respondsToSelector:@selector(downloadEnd:musicID:)]) {
        [delegate performSelector:@selector(downloadEnd:musicID:)
                       withObject:delegate
                       withObject:musicID];
    }
    bDownloading = NO;
}

/** @ghidraAddress 0x1e7de8 */
- (void)jcfDownloadMoveStore:(nullable JcfDownloadView *)view packID:(nullable NSString *)packID {
    __weak UIView *weakTopcover = topcover;
    __weak JcfDownloadView *weakDownloadView = downloadView;
    [UIView animateWithDuration:kHideDownloadOverlayDuration
        animations:^{
          /** @ghidraAddress 0x1e7ff0 */
          weakTopcover.alpha = 0.0;
          weakDownloadView.alpha = 0.0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x1e80b8 */
          [self removeDownloadView];
        }];

    // The binary passes the delegate itself as the callback's first object argument.
    if ([delegate respondsToSelector:@selector(moveStore:packID:)]) {
        [delegate performSelector:@selector(moveStore:packID:)
                       withObject:delegate
                       withObject:packID];
    }
}

#pragma mark - Rotation

/** @ghidraAddress 0x1e80d8 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return interfaceOrientation == UIInterfaceOrientationPortrait ||
           interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown;
}

/** @ghidraAddress 0x1e80e8 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

/** @ghidraAddress 0x1e80f0 */
- (BOOL)shouldAutorotate {
    return YES;
}

#pragma mark - Teardown

/** @ghidraAddress 0x1e80f8 */
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    // [super dealloc] is compiler-emitted (ARC).
}

#pragma mark - Session

/** @ghidraAddress 0x1e8174 */
- (void)openStartPage {
    [downloadPage loadRequest:nextUrlRequest];
}

/** @ghidraAddress 0x1e819c */
- (void)sessionCreate {
    sessionDownloader = [[jubeatLabAccess alloc] initTopPageSessionApi:self];
    [sessionDownloader startAccess];
}

/** @ghidraAddress 0x1e8200 */
- (void)jubeatLabAccessProceed:(nullable jubeatLabAccess *)access {
}

/** @ghidraAddress 0x1e8204 */
- (void)jubeatLabAccessError:(nullable jubeatLabAccess *)access {
    if (sessionDownloader == access) {
        sessionDownloader = nil;
    }
    NSString *okTitle = [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil];
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:self
                                            tag:0
                                          title:nil
                                            msg:@"通信エラー"
                                         cancel:okTitle
                                        btnText:nil
                                           show:YES
                                 viewController:self];
}

/** @ghidraAddress 0x1e8328 */
- (void)jubeatLabAccessFinished:(nullable jubeatLabAccess *)access {
    if (sessionDownloader != access) {
        return;
    }
    NSDictionary *json = [access getDataInJSON];
    sessionDownloader = nil;

    int status = [json[@"Status"] intValue];
    if (status == 0x75da) {
        [EditorIDManager replaceKeyChain:json];
        if (!EditorIDManager.isExistEditorID) {
            return;
        }
        [self sessionCreate];
        return;
    }
    if (status == 0) {
        [self openStartPage];
        return;
    }

    NSString *msg = json[@"MsgUser"];
    if (msg == nil) {
        return;
    }
    NSString *okTitle = [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil];
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:self
                                            tag:0
                                          title:nil
                                            msg:msg
                                         cancel:okTitle
                                        btnText:nil
                                           show:YES
                                 viewController:self];
}

#pragma mark - EditorIDManagerDelegate

/** @ghidraAddress 0x1e8538 */
- (void)successIDDownload:(nullable id)manager {
    eidMan = nil;
    if (EditorIDManager.isExistEditorID) {
        [self sessionCreate];
    } else {
        [self errorIDDownload:manager msgStr:nil];
    }
}

/** @ghidraAddress 0x1e85bc */
- (void)errorIDDownload:(nullable id)manager msgStr:(nullable NSString *)msgStr {
    eidMan = nil;
    NSString *msg = msgStr;
    if (msg == nil) {
        // The default "communication error" message, read from __const at 0x2d7200.
        msg = @"通信エラー";
    }
    NSString *okTitle = [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil];
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:nil
                                            tag:0
                                          title:nil
                                            msg:msg
                                         cancel:okTitle
                                        btnText:nil
                                           show:YES
                                 viewController:self];
}

#pragma mark - Appearance

/** @ghidraAddress 0x1e86f0 */
- (void)viewWillDisappear:(BOOL)animated {
    [[AlertViewManager sharedManager] closeAlert];
}

/** @ghidraAddress 0x1e8954 */
- (void)viewDidAppear:(BOOL)animated {
    [self initPageView];
    if (!bURLStart) {
        return;
    }
    if (EditorIDManager.isExistEditorID) {
        [self sessionCreate];
        return;
    }
    eidMan = [[EditorIDManager alloc] initWithDelegate:self];
}

#pragma mark - Social sharing

/** @ghidraAddress 0x1e8738 */
- (void)socialSend:(nullable NSString *)serviceType {
    SLComposeViewController *composer =
        [SLComposeViewController composeViewControllerForServiceType:serviceType];
    [composer setInitialText:socialString ? socialString : @""];
    [composer setCompletionHandler:^(SLComposeViewControllerResult result) {
      /** @ghidraAddress 0x1e8860 */
      if (result == SLComposeViewControllerResultDone) {
          [self dismissViewControllerAnimated:YES
                                   completion:^{
                                       /** @ghidraAddress 0x1e88ac */
                                   }];
      } else if (result == SLComposeViewControllerResultCancelled) {
          [self dismissViewControllerAnimated:YES
                                   completion:^{
                                       /** @ghidraAddress 0x1e88a8 */
                                   }];
      }
    }];
    [self presentViewController:composer animated:YES completion:nil];
    bOpenTwitter = YES;
}

/** @ghidraAddress 0x1e88c0 */
- (void)sendTwitter {
    [self socialSend:SLServiceTypeTwitter];
}

/** @ghidraAddress 0x1e88d8 */
- (void)sendFaceBook {
    if (bEnableSocialFrameWork) {
        [self socialSend:SLServiceTypeFacebook];
    }
}

/** @ghidraAddress 0x1e8904 */
- (void)appSuspended:(nullable NSNotification *)notification {
    if (bOpenTwitter) {
        [self dismissViewControllerAnimated:NO
                                 completion:^{
                                     /** @ghidraAddress 0x1e8950 */
                                 }];
        bOpenTwitter = NO;
    }
}

#pragma mark - Navigation

/** @ghidraAddress 0x1e6ef8 */
- (void)pushClose:(nullable id)sender {
    if (downloadView == nil) {
        [[NSUserDefaults standardUserDefaults] synchronize];
        if ([delegate respondsToSelector:@selector(customWebViewClose:seqIndex:)]) {
            [delegate performSelector:@selector(customWebViewClose:seqIndex:)
                           withObject:self
                           withObject:kCloseSeqIndexNone];
        }
    }
}

#pragma mark - Accessors

/** @ghidraAddress 0x1e89fc */
- (BOOL)bFromNavigate {
    return _bFromNavigate;
}

/** @ghidraAddress 0x1e8a0c */
- (void)setBFromNavigate:(BOOL)bFromNavigate {
    _bFromNavigate = bFromNavigate;
}

/** @ghidraAddress 0x1e8a1c */
- (BOOL)bCloseStoreMove {
    return _bCloseStoreMove;
}

/** @ghidraAddress 0x1e8a2c */
- (void)setBCloseStoreMove:(BOOL)bCloseStoreMove {
    _bCloseStoreMove = bCloseStoreMove;
}

@end
