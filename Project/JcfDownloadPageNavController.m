#import "JcfDownloadPageNavController.h"

#import "JcfDownloadPageViewController.h"
#import "JubeatAppDelegate.h"

// The local web page resource loaded from the app documents directory.
static NSString *const kDownloadTestPageName = @"DlTestPage.html";
// The empty-string placeholder passed as the seqIndex argument when closing.
static NSString *const kNoneSeqIndex = @"none";

// The navigation-bar tint white components (from the __const pool). The alpha (1.0) and the
// background whiteColor components arrive as fmov immediates.
static const CGFloat kBarTintWhiteResponds = 0.6; // 0x28f230, when -setBarTintColor: exists
static const CGFloat kBarTintWhiteLegacy = 0.9;   // 0x28f448, when it does not

@implementation JcfDownloadPageNavController {
    NSURLRequest *requestURL;                                 // +0x08
    unsigned int sequenceID;                                  // +0x10
    BOOL bSuccess;                                            // +0x14
    __weak id<JcfDownloadPageNavControllerDelegate> delegate; // +0x18, objc_storeWeak
    UIWebView *downloadPage;                                  // +0x20
    JcfDownloadPageViewController *ctrl;                      // +0x28
    unsigned int loadMid;                                     // +0x30
    NSString *loadSeqID;                                      // +0x38
    NSString *loadURL;                                        // +0x40
}

#pragma mark - Construction

/** @ghidraAddress 0x1e5914 */
- (NSURLRequest *)createCustomSequenceURL:(unsigned int)sequenceIDArg {
    NSString *path = [JubeatAppDelegate.appDocumentsDirectory
        stringByAppendingPathComponent:kDownloadTestPageName];
    return [NSURLRequest requestWithURL:[NSURL fileURLWithPath:path]];
}

/** @ghidraAddress 0x1e59d8 */
- (void)initNavigationBar {
    self.modalPresentationStyle = UIModalPresentationFormSheet;
    self.navigationBar.barStyle = UIBarStyleBlack;
    self.navigationBar.translucent = NO;
    if ([self.navigationBar respondsToSelector:@selector(setBarTintColor:)]) {
        // The binary uses -performSelector:withObject: for -setBarTintColor: on older systems.
        [self.navigationBar performSelector:@selector(setBarTintColor:)
                                 withObject:[UIColor colorWithWhite:kBarTintWhiteResponds
                                                              alpha:1.0]];
        self.navigationBar.tintColor = [UIColor colorWithWhite:kBarTintWhiteLegacy alpha:1.0];
    } else {
        self.navigationBar.tintColor = [UIColor colorWithWhite:kBarTintWhiteResponds alpha:1.0];
    }
    // The binary spells out colorWithRed:green:blue:alpha: with all components 1.0 (whiteColor).
    self.view.backgroundColor = UIColor.whiteColor;
}

/** @ghidraAddress 0x1e5c20 */
- (instancetype)initWithMusicID:(unsigned int)musicID
                       delegate:(id<JcfDownloadPageNavControllerDelegate>)delegateArg {
    loadMid = 0;
    loadSeqID = nil;
    loadURL = nil;
    self = [super init];
    if (self) {
        delegate = delegateArg;
        [self initNavigationBar];
        loadMid = musicID;
        UIBarButtonItem *closeButton = [[UIBarButtonItem alloc]
            initWithTitle:[NSBundle.mainBundle localizedStringForKey:@"Close" value:@"" table:nil]
                    style:UIBarButtonItemStyleDone
                   target:self
                   action:@selector(pushClose:)];
        ctrl = [[JcfDownloadPageViewController alloc]
            initWithMusicID:musicID
                   delegate:(id<JcfDownloadPageViewControllerDelegate>)delegateArg];
        ctrl.navigationItem.leftBarButtonItem = closeButton;
        [self setViewControllers:@[ ctrl ]];
    }
    return self;
}

/** @ghidraAddress 0x1e5e8c */
- (instancetype)initWithSequenceID:(NSString *)sequenceIDArg
                          delegate:(id<JcfDownloadPageNavControllerDelegate>)delegateArg {
    loadMid = 0;
    loadSeqID = nil;
    loadURL = nil;
    self = [super init];
    if (self) {
        delegate = delegateArg;
        [self initNavigationBar];
        loadSeqID = sequenceIDArg;
        UIBarButtonItem *closeButton = [[UIBarButtonItem alloc]
            initWithTitle:[NSBundle.mainBundle localizedStringForKey:@"Close" value:@"" table:nil]
                    style:UIBarButtonItemStyleDone
                   target:self
                   action:@selector(pushClose:)];
        ctrl = [[JcfDownloadPageViewController alloc]
            initWithSequenceID:sequenceIDArg
                      delegate:(id<JcfDownloadPageViewControllerDelegate>)delegateArg];
        ctrl.navigationItem.leftBarButtonItem = closeButton;
        [self setViewControllers:@[ ctrl ]];
    }
    return self;
}

/** @ghidraAddress 0x1e6118 */
- (instancetype)initWithURL:(NSString *)url
                   delegate:(id<JcfDownloadPageNavControllerDelegate>)delegateArg {
    loadMid = 0;
    loadSeqID = nil;
    loadURL = nil;
    self = [super init];
    if (self) {
        delegate = delegateArg;
        [self initNavigationBar];
        loadURL = url;
        UIBarButtonItem *closeButton = [[UIBarButtonItem alloc]
            initWithTitle:[NSBundle.mainBundle localizedStringForKey:@"Close" value:@"" table:nil]
                    style:UIBarButtonItemStyleDone
                   target:self
                   action:@selector(pushClose:)];
        ctrl = [[JcfDownloadPageViewController alloc]
            initWithURL:url
               delegate:(id<JcfDownloadPageViewControllerDelegate>)delegateArg];
        ctrl.navigationItem.leftBarButtonItem = closeButton;
        [self setViewControllers:@[ ctrl ]];
    }
    return self;
}

#pragma mark - Actions

/** @ghidraAddress 0x1e63a4 */
- (void)pushClose:(id)sender {
    [NSUserDefaults.standardUserDefaults synchronize];
    if ([delegate respondsToSelector:@selector(customWebViewClose:seqIndex:)]) {
        [delegate performSelector:@selector(customWebViewClose:seqIndex:)
                       withObject:self
                       withObject:kNoneSeqIndex];
    }
}

#pragma mark - Lifecycle

/** @ghidraAddress 0x1e6484 */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

/** @ghidraAddress 0x1e64bc */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

/** @ghidraAddress 0x1e64f4 */
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

/** @ghidraAddress 0x1e652c */
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

#pragma mark - Orientation

/** @ghidraAddress 0x1e6564 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Portrait or portrait-upside-down: the binary tests (orientation - 1) < 2 unsigned.
    return (unsigned)(interfaceOrientation - 1) < 2;
}

/** @ghidraAddress 0x1e6574 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

/** @ghidraAddress 0x1e657c */
- (BOOL)shouldAutorotate {
    return YES;
}

@end
