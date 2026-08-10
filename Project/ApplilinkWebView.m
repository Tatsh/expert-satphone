#import "ApplilinkWebView.h"

// RecommendCore routes a request to a link-scheme action code; not reconstructed as its own file
// yet. See TYPES_PENDING.md.
@interface RecommendCore : NSObject
@property(class, nonatomic, readonly) RecommendCore *sharedInstance;
- (int)redirectWithRequest:(nullable NSURLRequest *)request;
@end

// The load states.
static const int kWebViewStatusIdle = 0;
static const int kWebViewStatusLoading = 1;
static const int kWebViewStatusLoaded = 2;

// The timeout the view forces on every request that does not already carry it.
static const NSTimeInterval kWebViewTimeout = 30.0; // fmov 0x403e000000000000

// The redirect action codes returned by RecommendCore.
static const int kRedirectClose = 0;
static const int kRedirectAllow = 1;
static const int kRedirectStore = 4;
static const int kRedirectRepeat = 5;
static const int kRedirectCloseAlt = 7;

// The custom link URLs and prefixes the view recognises when RecommendCore does not.
static NSString *const kWebViewURLBlank = @"about:blank";
static NSString *const kWebViewURLClose = @"close";
static NSString *const kWebViewURLClosePrefix = @"close:";
static NSString *const kWebViewURLRepeat = @"repeat";
static NSString *const kWebViewURLRepeatPrefix = @"repeat:";
static NSString *const kWebViewURLMovie = @"movie";
static NSString *const kWebViewURLMoviePrefix = @"movie:";

// The WebKit error domain and the error codes that are ignored or reported.
static NSString *const kWebKitErrorDomain = @"WebKitErrorDomain";
static const NSInteger kErrorCancelled = -999;
static const NSInteger kWebKitFrameInterrupted = 102;
static const NSInteger kWebKitPluginError = 204;
static const NSInteger kErrorNotConnected = -1009;
static const NSInteger kErrorCannotFindHost = -1003;

// The close/repeat delegate calls are emitted inline at several branches of
// -webView:shouldStartLoadWithRequest:navigationType:; folded into helpers here.
static inline void ApplilinkWebViewNotifyClose(ApplilinkWebView *self) {
    id<SdkViewDelegate> delegate = self.sdkDelegate;
    if (delegate && [delegate respondsToSelector:@selector(closeNotice:)]) {
        [delegate closeNotice:self];
    }
}

static inline void ApplilinkWebViewNotifyRepeat(ApplilinkWebView *self) {
    id<SdkViewDelegate> delegate = self.sdkDelegate;
    if (delegate && [delegate respondsToSelector:@selector(repeatNotice:)]) {
        [delegate repeatNotice:self];
    }
}

@implementation ApplilinkWebView {
    int _webViewStatus;                      // +0x70
    __weak id<SdkViewDelegate> _sdkDelegate; // +0x78
}

@synthesize sdkDelegate = _sdkDelegate;
@synthesize webViewStatus = _webViewStatus;

#pragma mark - Construction

/** @ghidraAddress 0x22dc50 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.whiteColor;
        self.opaque = NO;
        self.autoresizingMask =
            UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth |
            UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
            UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
        self.contentMode = UIViewContentModeScaleAspectFit;
        self.delegate = self;
        _webViewStatus = kWebViewStatusIdle;
    }
    return self;
}

/** @ghidraAddress 0x22e694 */
- (void)dealloc {
    _sdkDelegate = nil;
    self.delegate = nil;
    // [super dealloc] is compiler-emitted (ARC).
}

#pragma mark - UIWebViewDelegate

/** @ghidraAddress 0x22dd50 */
- (void)webViewDidStartLoad:(UIWebView *)webView {
    if (_webViewStatus == kWebViewStatusIdle) {
        _webViewStatus = kWebViewStatusLoading;
    }
}

/** @ghidraAddress 0x22dd6c */
- (void)webViewDidFinishLoad:(UIWebView *)webView {
    // The initial about:blank load does not count as ready.
    if ([webView.request.URL.absoluteString isEqualToString:kWebViewURLBlank]) {
        return;
    }
    _webViewStatus = kWebViewStatusLoaded;
    if (_sdkDelegate && [_sdkDelegate respondsToSelector:@selector(viewReady:)]) {
        [_sdkDelegate viewReady:self];
    }
}

/** @ghidraAddress 0x22dec8 */
- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    // A user cancellation is ignored outright.
    if (error.code == kErrorCancelled) {
        return;
    }
    // Two WebKit-domain errors (a deliberately interrupted frame load and a plug-in error) are
    // ignored.
    if (error.code == kWebKitFrameInterrupted && [error.domain isEqual:kWebKitErrorDomain]) {
        return;
    }
    if (error.code == kWebKitPluginError && [error.domain isEqual:kWebKitErrorDomain]) {
        return;
    }
    // After the page has loaded, a lost connection or unreachable host is reported to the delegate.
    if (_webViewStatus == kWebViewStatusLoaded &&
        (error.code == kErrorNotConnected || error.code == kErrorCannotFindHost)) {
        NSError *reported = [NSError errorWithDomain:error.domain code:error.code userInfo:nil];
        if (_sdkDelegate && [_sdkDelegate respondsToSelector:@selector(linkErrorNotice:error:)]) {
            [_sdkDelegate linkErrorNotice:self error:reported];
        }
    }
}

/** @ghidraAddress 0x22e110 */
- (BOOL)webView:(UIWebView *)webView
    shouldStartLoadWithRequest:(NSURLRequest *)request
                navigationType:(UIWebViewNavigationType)navigationType {
    // Every request is forced to a 30 s timeout; a request that lacks it is reloaded with it and
    // this one is rejected.
    if (request.timeoutInterval != kWebViewTimeout) {
        NSMutableURLRequest *timed = (NSMutableURLRequest *)request;
        timed.timeoutInterval = kWebViewTimeout;
        [webView loadRequest:timed];
        return NO;
    }

    int action = [RecommendCore.sharedInstance redirectWithRequest:request];
    // A "7" from RecommendCore closes outright.
    if (action == kRedirectCloseAlt) {
        ApplilinkWebViewNotifyClose(self);
        return NO;
    }

    // Otherwise the custom link schemes are recognised directly first; a close URL closes and a
    // repeat/movie URL repeats. Any other URL (and a nil request) falls through to the action code.
    if (request) {
        NSString *url = request.URL.absoluteString;
        if ([url isEqualToString:kWebViewURLClose] || [url hasPrefix:kWebViewURLClosePrefix]) {
            ApplilinkWebViewNotifyClose(self);
            return NO;
        }
        if (!([url isEqualToString:kWebViewURLRepeat] || [url hasPrefix:kWebViewURLRepeatPrefix] ||
              [url isEqualToString:kWebViewURLMovie] || [url hasPrefix:kWebViewURLMoviePrefix])) {
            // An unrecognised URL: fall through to the action code below.
        } else {
            ApplilinkWebViewNotifyRepeat(self);
            return NO;
        }
    }

    switch (action) {
    case kRedirectClose:
        ApplilinkWebViewNotifyClose(self);
        return NO;
    case kRedirectAllow:
        return YES;
    case kRedirectStore:
        [self storeAction];
        return NO;
    case kRedirectRepeat:
        ApplilinkWebViewNotifyRepeat(self);
        return NO;
    default:
        return NO;
    }
}

#pragma mark - Store

/** @ghidraAddress 0x22e5dc */
- (void)storeAction {
    if (_sdkDelegate && [_sdkDelegate respondsToSelector:@selector(storeNotice:)]) {
        [_sdkDelegate storeNotice:self];
    }
}

@end
