#import "SettingsPolicyViewController.h"

#import "JubeatAppDelegate.h"
#import "ScratchUtil.h"
#import "SessionDownloader.h"

// The per-policy-type navigation-bar titles (Japanese in the shipped binary).
static NSString *const kTitleContent = @"「jubeat plus」コンテンツ利用規約";
static NSString *const kTitleCurrency = @"ゲーム内通貨利用規約";
static NSString *const kTitlePaymentServices = @"資金決済法について";
static NSString *const kTitleMinors = @"未成年の方へ";

// The signed-request parameter keys and values. The document region is always Japan; the revision
// is left unpinned at -1 so the server returns its current text; the type selects the document.
static NSString *const kRequestKeyTarget = @"target";
static NSString *const kRequestKeyRevision = @"revision";
static NSString *const kRequestKeyType = @"type";
static NSString *const kRequestTargetJP = @"JP";
static const int kRequestRevisionLatest = -1;

// The response keys the finished handler reads.
static NSString *const kResponseKeyStatus = @"status";
static NSString *const kResponseKeyErrorMessage = @"err_message";
static NSString *const kResponseKeyPolicy = @"policy";

// The localised string shown whenever the download fails or returns no usable policy text.
static NSString *const kNetworkErrorMessageKey = @"NetworkErrorMsg";

// The pad text-view frame and font. On the handset the frame follows the screen bounds less a top
// inset, and the font is a point smaller.
// @ghidraAddress 0x28f900 (width), 0x291d88 (height)
static const CGFloat kPadWidth = 540.0;
static const CGFloat kPadHeight = 576.0;
// @ghidraAddress 0x28f1d0
static const CGFloat kPhoneHeightInset = -44.0;
static const CGFloat kPadFontSize = 20.0;
static const CGFloat kPhoneFontSize = 18.0;

// The raw supported-orientation mask the binary returns: 6, i.e. portrait and portrait-upside-down
// (UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown). Kept as the
// literal the binary uses rather than a named mask, since it is not one of the common combinations.
static const UIInterfaceOrientationMask kSupportedOrientations =
    UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;

@interface SettingsPolicyViewController () {
    SessionDownloader *policyDownloader; // +0x8
    UITextView *policyView;              // +0x10
    int policyType;                      // +0x18
}
@end

@implementation SettingsPolicyViewController

#pragma mark - Construction

/** @ghidraAddress 0x1d3bf4 */
- (instancetype)initViewController:(SettingsPolicyType)type {
    self = [super init];
    if (!self) {
        return self;
    }
    policyType = type;
    switch (type) {
    case SettingsPolicyTypeContent:
        self.navigationItem.title = kTitleContent;
        break;
    case SettingsPolicyTypeCurrency:
        self.navigationItem.title = kTitleCurrency;
        break;
    case SettingsPolicyTypePaymentServices:
        self.navigationItem.title = kTitlePaymentServices;
        break;
    case SettingsPolicyTypeMinors:
        self.navigationItem.title = kTitleMinors;
        break;
    default:
        break;
    }
    // An iOS 7 property, reached by selector so the class still builds against an older SDK.
    if ([self respondsToSelector:@selector(setExtendedLayoutIncludesOpaqueBars:)]) {
        [self performSelector:@selector(setExtendedLayoutIncludesOpaqueBars:) withObject:nil];
    }
    return self;
}

#pragma mark - View construction

/** @ghidraAddress 0x1d3d94 */
- (void)loadView {
    [super loadView];
    self.view.backgroundColor = UIColor.whiteColor;

    NSURL *url = [ScratchUtil challengeModePolicyURL];
    NSDictionary *post = @{
        kRequestKeyTarget : kRequestTargetJP,
        kRequestKeyRevision : @(kRequestRevisionLatest),
        kRequestKeyType : @(policyType)
    };
    policyDownloader = [[SessionDownloader alloc] initWithURL:url
                                               postDictionary:post
                                                     delegate:self];
    [policyDownloader startDownloading];

    CGRect frame;
    CGFloat fontSize;
    if ([JubeatAppDelegate appDelegate].isPad) {
        frame = CGRectMake(0.0, 0.0, kPadWidth, kPadHeight);
        fontSize = kPadFontSize;
    } else {
        CGRect bounds = [UIScreen mainScreen].bounds;
        frame = CGRectMake(0.0, 0.0, bounds.size.width, bounds.size.height + kPhoneHeightInset);
        fontSize = kPhoneFontSize;
    }

    policyView = [[UITextView alloc] initWithFrame:frame];
    policyView.textAlignment = NSTextAlignmentLeft;
    policyView.font = [UIFont systemFontOfSize:fontSize];
    policyView.editable = NO;
    [self.view addSubview:policyView];
}

#pragma mark - DownloaderDelegate

/** @ghidraAddress 0x1d415c */
- (void)downloaderFinished:(Downloader *)downloader {
    NSDictionary *json = [downloader getDataInJSON];
    id status = json[kResponseKeyStatus];
    if (status && [json[kResponseKeyStatus] intValue] == 0) {
        id policy = json[kResponseKeyPolicy];
        if (![policy isKindOfClass:[NSString class]]) {
            policyView.text = [NSBundle.mainBundle localizedStringForKey:kNetworkErrorMessageKey
                                                                   value:@""
                                                                   table:nil];
            return;
        }
        policyView.text = json[kResponseKeyPolicy];
        return;
    }

    NSString *message = json[kResponseKeyErrorMessage];
    if (!message) {
        message = [NSBundle.mainBundle localizedStringForKey:kNetworkErrorMessageKey
                                                       value:@""
                                                       table:nil];
    }
    policyView.text = message;
}

/** @ghidraAddress 0x1d43a4 */
- (void)downloaderError:(Downloader *)downloader {
    policyView.text = [NSBundle.mainBundle localizedStringForKey:kNetworkErrorMessageKey
                                                           value:@""
                                                           table:nil];
}

#pragma mark - Lifecycle

/** @ghidraAddress 0x1d443c */
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

/** @ghidraAddress 0x1d4474 */
- (void)viewDidUnload {
    [super viewDidUnload];
}

/** @ghidraAddress 0x1d44ac */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

/** @ghidraAddress 0x1d44e4 */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

/** @ghidraAddress 0x1d451c */
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

/** @ghidraAddress 0x1d4554 */
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

#pragma mark - Rotation

/** @ghidraAddress 0x1d458c */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Portrait and portrait-upside-down (orientations 1 and 2), matching the mask of 6 below. The
    // binary tests (orientation - 1) as unsigned, so any other value (including 0) is refused.
    return (unsigned int)(interfaceOrientation - 1) < 2;
}

/** @ghidraAddress 0x1d459c */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return kSupportedOrientations;
}

/** @ghidraAddress 0x1d45a4 */
- (BOOL)shouldAutorotate {
    return YES;
}

@end
