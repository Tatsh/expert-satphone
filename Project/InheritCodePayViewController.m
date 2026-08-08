#import "InheritCodePayViewController.h"

#import "InheritCodePayView.h"
#import "JubeatAppDelegate.h"

// The navigation title shown above the inherit-code issue panel ("issue inherit code").
static NSString *const kInheritCodePayTitle = @"引き継ぎコード発行";

// On the pad the hosted panel uses a fixed area; on the phone it follows the screen bounds. Both
// have the navigation-bar height subtracted from the panel height.
static const CGFloat kPadPanelWidth = 540.0;
static const CGFloat kPadPanelHeight = 620.0;

// The white component of the dimming overlay drawn behind the panel (the binary uses the full
// colorWithWhite:alpha: component call at 80% white, fully opaque).
static const CGFloat kOverlayWhite = 0.8;

// The raw supported-orientation mask the binary returns: 6, i.e. portrait and portrait-upside-down
// (UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown).
static const UIInterfaceOrientationMask kSupportedOrientations =
    UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;

@interface InheritCodePayViewController () {
    InheritCodePayView *inheritView; // +0x8
}
@end

@implementation InheritCodePayViewController

#pragma mark - Construction

/** @ghidraAddress 0xaeb90 */
- (instancetype)init {
    self = [super init];
    if (!self) {
        return self;
    }
    self.navigationItem.title = kInheritCodePayTitle;
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self
               selector:@selector(appSuspended:)
                   name:UIApplicationDidEnterBackgroundNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(appResume:)
                   name:UIApplicationWillEnterForegroundNotification
                 object:nil];
    return self;
}

/** @ghidraAddress 0xaec98 */
- (void)loadView {
    [super loadView];

    // The pad uses a fixed 540×620 panel; the phone follows the screen bounds.
    CGFloat width = kPadPanelWidth;
    CGFloat height = kPadPanelHeight;
    if (![JubeatAppDelegate appDelegate].isPad) {
        CGRect bounds = [UIScreen mainScreen].bounds;
        width = bounds.size.width;
        height = bounds.size.height;
    }

    // The panel height loses the navigation bar's height. Only the bar frame's height is used; the
    // rest of the frame is discarded.
    CGFloat navBarHeight = self.navigationController.navigationBar.frame.size.height;
    height -= navBarHeight;

    // A dimming overlay covering the whole view, sized to the view's own bounds.
    UIView *overlay = [[UIView alloc] initWithFrame:self.view.bounds];
    overlay.opaque = NO;
    overlay.backgroundColor = [UIColor colorWithWhite:kOverlayWhite alpha:1.0];
    overlay.hidden = NO;
    [self.view addSubview:overlay];

    inheritView = [[InheritCodePayView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    [self.view addSubview:inheritView];
    inheritView.parentCtrl = self;
}

#pragma mark - Lifecycle

/** @ghidraAddress 0xaef78 */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

/** @ghidraAddress 0xaefb0 */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

/** @ghidraAddress 0xaefe8 */
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

/** @ghidraAddress 0xaf05c */
- (void)viewDidDisappear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super viewDidDisappear:animated];
}

#pragma mark - Rotation

/** @ghidraAddress 0xaf0e8 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Portrait and portrait-upside-down (orientations 1 and 2), matching the mask of 6. Tested
    // unsigned, so orientation 0 (unknown) underflows and is refused.
    return (NSUInteger)(interfaceOrientation - 1) < 2;
}

/** @ghidraAddress 0xaf0f8 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return kSupportedOrientations;
}

/** @ghidraAddress 0xaf100 */
- (BOOL)shouldAutorotate {
    return YES;
}

#pragma mark - Alerts

/** @ghidraAddress 0xaf108 */
- (void)alertSelect:(id)sender {
    // Empty in the binary.
}

#pragma mark - Teardown

/** @ghidraAddress 0xaf10c */
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    // [super dealloc] is compiler-emitted (ARC).
}

@end
