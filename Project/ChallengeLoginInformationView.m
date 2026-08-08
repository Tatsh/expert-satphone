#import "ChallengeLoginInformationView.h"

#import "AlertViewManager.h"
#import "AudioManager.h"
#import "ChallengeStatus.h"
#import "EditorIDManager.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"

// ChallengeStatus vends the challenge information page URL through -informationURL, which the
// class's own header does not yet declare; declared here until ChallengeStatus is extended.
@interface ChallengeStatus (ChallengeLoginInformation)
- (nullable NSString *)informationURL;
@end

// The sheet's background art, and the two close-button images selected by buttonType.
static NSString *const kBackgroundImageName = @"scratch_login_sheet";
static NSString *const kCloseCancelImageName = @"scratch_btn_cancel";
static NSString *const kCloseBackImageName = @"scratch_btn_back";

// The close-button sound, played from the default resource directory when the sheet is independent.
static NSString *const kCloseSoundName = @"SD_LABO_MENU";

// The buttonType value that selects the "back" close image rather than "cancel".
static const int kButtonTypeBack = 1;

// The container's fixed size on iPad.
static const int kPadContainerWidth = 572;
static const int kPadContainerHeight = 611;

// The phone container derives from the frame: the width gains this margin on each side (scaled by
// the phone screen rate), and the height is the frame height plus these scaled insets less a fixed
// amount.
static const CGFloat kPhoneWidthMarginUnit = 8.0;
static const CGFloat kPhoneHeightMargin = -44.0; // 0x10028f1d0
static const CGFloat kPhoneHeightUnit10 = 10.0;
static const CGFloat kPhoneHeightUnit27 = 27.0;

// The close button's inset from the container's top-left, per idiom. The X inset is scaled by the
// container-to-art width ratio; the Y base is offset by half the button image's height and scaled
// by the height ratio.
static const CGFloat kCloseInsetXPad = 16.0;
static const CGFloat kCloseInsetXPhone = 8.0;
static const CGFloat kCloseBaseYPad = 28.0;
static const CGFloat kCloseBaseYPhone = 14.0;
static const CGFloat kCloseImageHalf = 0.5;

// The web view's horizontal inset, the gap below the close button, and the amount trimmed off the
// remaining height, per idiom. On phone each is scaled by the phone screen rate.
static const CGFloat kWebViewInsetXPad = 16.0;
static const CGFloat kWebViewInsetXPhoneUnit = 8.0;
static const CGFloat kWebViewGapPad = 8.0;
static const CGFloat kWebViewGapPhoneUnit = 10.0;
static const CGFloat kWebViewTrimPad = 27.0;
static const CGFloat kWebViewTrimPhoneUnit = 27.0;

// The loading indicator: a fixed 42-point square placed relative to the container centre, drawn at
// double scale.
static const CGFloat kIndicatorSize = 42.0; // 0x10028f758
static const int kIndicatorOffsetX = 21;
static const int kIndicatorOffsetY = 42;
static const CGFloat kIndicatorScale = 2.0;

// The half factor used to centre the container in the frame.
static const CGFloat kCenterHalf = 0.5;

// The screen rate used on iPad, where no phone scaling applies.
static const CGFloat kPadScreenRate = 1.0;

// The request timeout when building the request from dispURL.
static const NSTimeInterval kRequestTimeout = 10.0;

// The custom link schemes and prefixes the sheet recognises, the replacement scheme for external
// links, and the store path segment.
static NSString *const kTwitterPrefix = @"twitter://";
static NSString *const kOpenURLPrefix = @"openurl://";
static NSString *const kHTTPSPrefix = @"https://";
static NSString *const kStoreScheme = @"jbtstore";
static NSString *const kStorePackComponent = @"pack";

// The number of path components a jbtstore://pack/<id> URL carries, and the indices of the "pack"
// keyword and its identifier.
static const NSUInteger kStorePathComponentCount = 3;
static const NSUInteger kStorePackKeywordIndex = 1;
static const NSUInteger kStorePackIdentifierIndex = 2;

// The HTTP header the sheet stamps with the app's user agent.
static NSString *const kUserAgentHeaderField = @"User-Agent";

// The network-error alert message; a Japanese literal in the binary, "communication error".
static NSString *const kNetworkErrorMessage = @"通信エラー";

// The key under which the OK button title is localised.
static NSString *const kOKKey = @"OK";

// The script that disables the WebKit touch callout once a page has loaded.
static NSString *const kDisableTouchCalloutScript =
    @"document.documentElement.style.webkitTouchCallout='none';";

@implementation ChallengeLoginInformationView {
    UIView *bgCtrlView;                     // +0x8
    UIImageView *bgView;                    // +0x10
    UIButton *closeBtn;                     // +0x18
    NSString *dispURL;                      // +0x20
    BOOL bMenuView;                         // +0x28
    UIWebView *drawWebView;                 // +0x30
    UIActivityIndicatorView *indicatorView; // +0x38
    NSURLRequest *firstRequest;             // +0x40
    int buttonType;                         // +0x48
}

#pragma mark - Construction

/** @ghidraAddress 0xaf19c */
- (instancetype)initWithFrame:(CGRect)frame dispURL:(NSString *)inDispURL btnType:(int)btnType {
    dispURL = inDispURL;
    buttonType = btnType;
    return [self initWithFrame:frame];
}

/** @ghidraAddress 0xaf244 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _bIndependMenu = NO;
        BOOL isPad = JubeatAppDelegate.appDelegate.isPad;
        CGFloat rate = isPad ? kPadScreenRate : ChallengeStatus.sharedStatus.phoneScreenRate;

        UIImage *bgImage = LoadScaledPngImage(kBackgroundImageName);
        CGSize bgImageSize = bgImage.size;

        int containerWidth;
        int containerHeight;
        if (isPad) {
            containerWidth = kPadContainerWidth;
            containerHeight = kPadContainerHeight;
        } else {
            containerWidth = (int)(frame.size.width +
                                   (rate * kPhoneWidthMarginUnit + rate * kPhoneWidthMarginUnit));
            containerHeight =
                (int)(rate * kPhoneHeightUnit27 +
                      (frame.size.height + kPhoneHeightMargin + rate * kPhoneHeightUnit10));
        }

        bgCtrlView =
            [[UIView alloc] initWithFrame:CGRectMake(0, 0, containerWidth, containerHeight)];
        bgCtrlView.center =
            CGPointMake(frame.size.width * kCenterHalf, frame.size.height * kCenterHalf);
        [self addSubview:bgCtrlView];

        bgView = [[UIImageView alloc] initWithImage:bgImage];
        [bgView setFrame:CGRectMake(0, 0, containerWidth, containerHeight)];
        [bgCtrlView addSubview:bgView];

        UIImage *closeImage = LoadScaledPngImage(kCloseCancelImageName);
        if (buttonType == kButtonTypeBack) {
            closeImage = LoadScaledPngImage(kCloseBackImageName);
        }
        CGSize closeImageSize = closeImage.size;

        closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];

        CGFloat closeInsetX = isPad ? kCloseInsetXPad : kCloseInsetXPhone;
        CGFloat closeBaseY = isPad ? kCloseBaseYPad : kCloseBaseYPhone;
        int closeX = (int)(closeInsetX * (containerWidth / bgImageSize.width));
        int closeY = (int)((containerHeight / bgImageSize.height) *
                           (closeBaseY - closeImageSize.height * kCloseImageHalf));
        [closeBtn setFrame:CGRectMake(closeX, closeY, closeImageSize.width, closeImageSize.height)];
        [closeBtn setBackgroundImage:closeImage forState:UIControlStateNormal];
        [closeBtn addTarget:self
                      action:@selector(closeMessage:)
            forControlEvents:UIControlEventTouchUpInside];
        closeBtn.exclusiveTouch = YES;
        [bgCtrlView addSubview:closeBtn];

        CGFloat webViewInsetX = isPad ? kWebViewInsetXPad : rate * kWebViewInsetXPhoneUnit;
        CGFloat webViewGap = isPad ? kWebViewGapPad : rate * kWebViewGapPhoneUnit;
        CGFloat webViewTrim = isPad ? kWebViewTrimPad : rate * kWebViewTrimPhoneUnit;
        int webViewY = (int)(closeY + webViewGap + closeImageSize.height);
        drawWebView = [[UIWebView alloc]
            initWithFrame:CGRectMake(webViewInsetX,
                                     webViewY,
                                     containerWidth - webViewInsetX * 2.0,
                                     (containerHeight - webViewY) - webViewTrim)];
        drawWebView.scalesPageToFit = NO;
        drawWebView.backgroundColor = UIColor.clearColor;
        drawWebView.delegate = self;

        bMenuView = YES;
        if (dispURL == nil) {
            bMenuView = NO;
            dispURL = ChallengeStatus.sharedStatus.informationURL;
        }
        [bgCtrlView addSubview:drawWebView];

        indicatorView = [[UIActivityIndicatorView alloc]
            initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        [indicatorView setFrame:CGRectMake((containerWidth >> 1) - kIndicatorOffsetX,
                                           (containerHeight >> 1) - kIndicatorOffsetY,
                                           kIndicatorSize,
                                           kIndicatorSize)];
        indicatorView.transform = CGAffineTransformMakeScale(kIndicatorScale, kIndicatorScale);
        indicatorView.hidesWhenStopped = YES;
        [indicatorView startAnimating];
        [bgCtrlView addSubview:indicatorView];

        [self notificationRequest];
    }
    return self;
}

#pragma mark - Loading

/** @ghidraAddress 0xaf914 */
- (void)notificationRequest {
    NSURLRequest *request = firstRequest;
    if (request == nil) {
        NSURL *url = [NSURL URLWithString:dispURL];
        request = [NSURLRequest requestWithURL:url
                                   cachePolicy:NSURLRequestUseProtocolCachePolicy
                               timeoutInterval:kRequestTimeout];
    }
    [drawWebView loadRequest:request];
}

#pragma mark - Actions

/** @ghidraAddress 0xaf9e0 */
- (void)closeMessage:(id)sender {
    if (_bIndependMenu) {
        [AudioManager.sharedManager playSeResFile:kCloseSoundName inDirectory:nil];
    }
    if ([self.aDelegate respondsToSelector:@selector(closeLoginInformation)]) {
        [self.aDelegate performSelector:@selector(closeLoginInformation)];
    } else if ([self.aDelegate respondsToSelector:@selector(closeMenu)]) {
        [self.aDelegate performSelector:@selector(closeMenu)];
    }
}

#pragma mark - UIWebViewDelegate

/** @ghidraAddress 0xafb4c */
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

/** @ghidraAddress 0xafc94 */
- (BOOL)webView:(UIWebView *)webView
    shouldStartLoadWithRequest:(NSURLRequest *)request
                navigationType:(UIWebViewNavigationType)navigationType {
    if (navigationType != UIWebViewNavigationTypeLinkClicked) {
        return YES;
    }
    if (request.URL == nil) {
        return YES;
    }
    NSString *absoluteString = request.URL.absoluteString;
    NSURL *url = request.URL;

    // A twitter:// link is simply blocked.
    if ([absoluteString rangeOfString:kTwitterPrefix].location != NSNotFound) {
        return NO;
    }

    if ([absoluteString rangeOfString:kOpenURLPrefix].location != NSNotFound) {
        // An openurl:// link opens externally as https://.
        NSString *external = [absoluteString stringByReplacingOccurrencesOfString:kOpenURLPrefix
                                                                       withString:kHTTPSPrefix];
        [UIApplication.sharedApplication openURL:[NSURL URLWithString:external]];
        return NO;
    }

    if (![url.scheme isEqualToString:kStoreScheme]) {
        return YES;
    }

    // A jbtstore://pack/<id> link forwards the pack identifier to the delegate.
    NSDictionary *info = nil;
    if (url.pathComponents.count == kStorePathComponentCount &&
        [url.pathComponents[kStorePackKeywordIndex] isEqualToString:kStorePackComponent]) {
        info = @{kStorePackComponent : url.pathComponents[kStorePackIdentifierIndex]};
    }
    if ([self.aDelegate respondsToSelector:@selector(clickPackInfomation:)]) {
        [self.aDelegate performSelector:@selector(clickPackInfomation:) withObject:info];
    }
    return NO;
}

/** @ghidraAddress 0xb00a8 */
- (void)stopIndicator {
    if (indicatorView != nil) {
        [indicatorView stopAnimating];
        [indicatorView removeFromSuperview];
        indicatorView = nil;
    }
}

/** @ghidraAddress 0xb0104 */
- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    NSString *okTitle = [NSBundle.mainBundle localizedStringForKey:kOKKey value:@"" table:nil];
    [AlertViewManager.sharedManager makeAlert:0
                                     delegate:nil
                                          tag:0
                                        title:nil
                                          msg:kNetworkErrorMessage
                                       cancel:okTitle
                                      btnText:nil
                                         show:YES];
    [self stopIndicator];
}

/** @ghidraAddress 0xb01f8 */
- (void)webViewDidStartLoad:(UIWebView *)webView {
    [NSURLCache.sharedURLCache removeAllCachedResponses];
}

/** @ghidraAddress 0xb0240 */
- (void)webViewDidFinishLoad:(UIWebView *)webView {
    [self stopIndicator];
    [webView stringByEvaluatingJavaScriptFromString:kDisableTouchCalloutScript];
}

@end
