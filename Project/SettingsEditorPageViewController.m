#import "SettingsEditorPageViewController.h"

#import <Social/Social.h>

#import "AlertViewManager.h"
#import "JubeatAppDelegate.h"
#import "jubeatLabAccess.h"

// The navigation-bar title, the constant "jubeat Lab." at 0x283a4c.
static NSString *const kEditorTitle = @"jubeat Lab.";

// The web view geometry. On iPad the web view is a fixed size; on the handset it follows the
// screen bounds. Unlike the inquiry page there is no top inset here.
static const CGFloat kPadWidth = 540.0;  // 0x28f900
static const CGFloat kPadHeight = 576.0; // 0x291d88

// The custom scheme the page emits for a Twitter share, stripped before the text is composed.
static NSString *const kTwitterScheme = @"twitter://";

// The HTTP header the resource hook stamps with the app's user agent.
static NSString *const kUserAgentHeaderField = @"User-Agent";

// The provisioning-response JSON keys the finished callback reads.
static NSString *const kStatusKey = @"Status";
static NSString *const kMsgUserKey = @"MsgUser";

// The status code that marks an editor-account switch (see +[EditorIDManager replaceKeyChain:]).
static const int kStatusKeychainSwitch = 0x75da;

// The network-error alert message, a Japanese literal in the binary, "communication error". It
// doubles as the default editor-id error message when the server supplies none.
static NSString *const kNetworkErrorMessage = @"通信エラー";

// The key under which the OK button title is localised.
static NSString *const kOKKey = @"OK";

// The alert tags the binary passes: a load failure uses 1, every session/provisioning failure
// uses 2.
static const int kAlertTagLoadFailed = 1;
static const int kAlertTagSessionFailed = 2;

@implementation SettingsEditorPageViewController {
    UIWebView *editorPage;              // +0x8
    NSURLRequest *nextUrlRequest;       // +0x10
    jubeatLabAccess *sessionDownloader; // +0x18
    EditorIDManager *eidMan;            // +0x20
    NSString *socialString;             // +0x28
}

#pragma mark - Construction

/** @ghidraAddress 0x1f7a88 */
- (NSURLRequest *)createEditorPageURL {
    return [NSURLRequest requestWithURL:jubeatLabAccess.getUserPageURL];
}

/** @ghidraAddress 0x1f7af0 */
- (void)openStartPage {
    [editorPage loadRequest:nextUrlRequest];
}

/** @ghidraAddress 0x1f7b18 */
- (void)sessionCreate {
    sessionDownloader = [[jubeatLabAccess alloc] initSessionApi:self];
    [sessionDownloader startAccess];
}

/** @ghidraAddress 0x1f7b7c */
- (instancetype)init {
    self = [super init];
    if (self) {
        self.navigationItem.title = kEditorTitle;
        nextUrlRequest = [self createEditorPageURL];

        CGFloat width;
        CGFloat height;
        if (JubeatAppDelegate.appDelegate.isPad) {
            width = kPadWidth;
            height = kPadHeight;
        } else {
            CGRect bounds = UIScreen.mainScreen.bounds;
            width = bounds.size.width;
            height = bounds.size.height;
        }

        editorPage = [[UIWebView alloc] initWithFrame:CGRectMake(0.0, 0.0, width, height)];
        editorPage.scalesPageToFit = YES;
        editorPage.delegate = self;
        editorPage.dataDetectorTypes = UIDataDetectorTypeNone;
        [self.view addSubview:editorPage];

        if (EditorIDManager.isExistEditorID) {
            [self sessionCreate];
        } else {
            eidMan = [[EditorIDManager alloc] initWithDelegate:self];
        }
    }
    return self;
}

#pragma mark - UIWebViewDelegate

/** @ghidraAddress 0x1f7dfc */
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

/** @ghidraAddress 0x1f7f44 */
- (BOOL)webView:(UIWebView *)webView
    shouldStartLoadWithRequest:(NSURLRequest *)request
                navigationType:(UIWebViewNavigationType)navigationType {
    if ([request.URL isEqual:jubeatLabAccess.getUserPageSessionFailedURL]) {
        // The page navigated to the session-failed URL; re-open a session instead.
        sessionDownloader = [[jubeatLabAccess alloc] initSessionApi:self];
        [sessionDownloader startAccess];
        return NO;
    }
    // Only a user-clicked link (navigation type 0) is inspected; other navigations pass through.
    if (navigationType == UIWebViewNavigationTypeLinkClicked) {
        NSString *absoluteString = request.URL.absoluteString;
        if ([absoluteString rangeOfString:kTwitterScheme].location != NSNotFound) {
            // A twitter:// link becomes share text and is sent to Twitter.
            socialString = [absoluteString stringByReplacingOccurrencesOfString:kTwitterScheme
                                                                     withString:@""];
            [self sendTwitter];
            return NO;
        }
        nextUrlRequest = request;
    }
    return YES;
}

/** @ghidraAddress 0x1f8134 */
- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    NSString *okTitle = [NSBundle.mainBundle localizedStringForKey:kOKKey value:@"" table:nil];
    [AlertViewManager.sharedManager makeAlert:0
                                     delegate:nil
                                          tag:kAlertTagLoadFailed
                                        title:nil
                                          msg:kNetworkErrorMessage
                                       cancel:okTitle
                                      btnText:nil
                                         show:YES
                               viewController:self];
}

/** @ghidraAddress 0x1f821c */
- (void)webViewDidStartLoad:(UIWebView *)webView {
    [NSURLCache.sharedURLCache removeAllCachedResponses];
}

#pragma mark - jubeatLabAccess delegate

/** @ghidraAddress 0x1f8264 */
- (void)jubeatLabAccessProceed:(id)access {
    // The binary's implementation is empty.
}

/** @ghidraAddress 0x1f8268 */
- (void)jubeatLabAccessError:(id)access {
    if (sessionDownloader == access) {
        sessionDownloader = nil;
    }
    NSString *okTitle = [NSBundle.mainBundle localizedStringForKey:kOKKey value:@"" table:nil];
    [AlertViewManager.sharedManager makeAlert:0
                                     delegate:nil
                                          tag:kAlertTagSessionFailed
                                        title:nil
                                          msg:kNetworkErrorMessage
                                       cancel:okTitle
                                      btnText:nil
                                         show:YES
                               viewController:self];
}

/** @ghidraAddress 0x1f838c */
- (void)jubeatLabAccessFinished:(id)access {
    if (sessionDownloader != access) {
        return;
    }
    NSDictionary *response = [access getDataInJSON];
    sessionDownloader = nil;
    int status = [response[kStatusKey] intValue];
    if (status == kStatusKeychainSwitch) {
        [EditorIDManager replaceKeyChain:response];
        if (EditorIDManager.isExistEditorID) {
            [self sessionCreate];
        }
    } else if (status == 0) {
        [self openStartPage];
    } else {
        NSString *msg = response[kMsgUserKey];
        if (msg == nil) {
            return;
        }
        NSString *okTitle = [NSBundle.mainBundle localizedStringForKey:kOKKey value:@"" table:nil];
        [AlertViewManager.sharedManager makeAlert:0
                                         delegate:nil
                                              tag:kAlertTagSessionFailed
                                            title:nil
                                              msg:msg
                                           cancel:okTitle
                                          btnText:nil
                                             show:YES
                                   viewController:self];
    }
}

#pragma mark - EditorIDManagerDelegate

/** @ghidraAddress 0x1f859c */
- (void)successIDDownload:(id)manager {
    eidMan = nil;
    if (EditorIDManager.isExistEditorID) {
        [self sessionCreate];
    } else {
        [self errorIDDownload:manager msgStr:nil];
    }
}

/** @ghidraAddress 0x1f8620 */
- (void)errorIDDownload:(id)manager msgStr:(NSString *)msgStr {
    eidMan = nil;
    NSString *msg = msgStr;
    if (msg == nil) {
        msg = kNetworkErrorMessage;
    }
    NSString *okTitle = [NSBundle.mainBundle localizedStringForKey:kOKKey value:@"" table:nil];
    [AlertViewManager.sharedManager makeAlert:0
                                     delegate:nil
                                          tag:kAlertTagSessionFailed
                                        title:nil
                                          msg:msg
                                       cancel:okTitle
                                      btnText:nil
                                         show:YES
                               viewController:self];
}

#pragma mark - Rotation

/** @ghidraAddress 0x1f8754 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Portrait and portrait-upside-down (orientations 1 and 2), matching the mask of 6 below. The
    // binary tests (orientation - 1) as unsigned, so any other value (including 0) is refused.
    return (unsigned int)(interfaceOrientation - 1) < 2;
}

/** @ghidraAddress 0x1f8764 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    // The binary returns the literal 6, i.e. portrait and portrait-upside-down.
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

/** @ghidraAddress 0x1f876c */
- (BOOL)shouldAutorotate {
    return YES;
}

#pragma mark - Lifecycle

/** @ghidraAddress 0x1f8774 */
- (void)viewWillDisappear:(BOOL)animated {
    [AlertViewManager.sharedManager closeAlert];
}

#pragma mark - Social sharing

/** @ghidraAddress 0x1f87f4 */
- (void)socialSend:(NSString *)serviceType {
    SLComposeViewController *composer =
        [SLComposeViewController composeViewControllerForServiceType:serviceType];
    [composer setInitialText:(socialString != nil ? socialString : @"")];
    composer.completionHandler = ^(SLComposeViewControllerResult result) {
      /** @ghidraAddress 0x1f890c */
      // Dismiss the composer on either outcome (cancelled or done).
      if (result == SLComposeViewControllerResultCancelled ||
          result == SLComposeViewControllerResultDone) {
          [self dismissViewControllerAnimated:YES completion:nil];
      }
    };
    [self presentViewController:composer animated:YES completion:nil];
}

/** @ghidraAddress 0x1f8944 */
- (void)sendTwitter {
    [self socialSend:SLServiceTypeTwitter];
}

/** @ghidraAddress 0x1f895c */
- (void)sendFaceBook {
    [self socialSend:SLServiceTypeFacebook];
}

@end
