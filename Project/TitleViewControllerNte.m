#import "TitleViewControllerNte.h"

#import "JubeatAppDelegate.h"
#import "NteTitleCoreController.h"

// The artwork base names for the top flip-book, from the two arrayWithObjects:count: lists built at
// 0x71ff8 (the default set) and 0x72054 (the 3.5-inch variant). The 3.5-inch phone gets the smaller
// "title35" set; every other idiom gets the standard set.
static NSString *const kTitleImageName01 = @"title_n01";
static NSString *const kTitleImageName02 = @"title_n02";
static NSString *const kTitleImageName03 = @"title_n03";
static NSString *const kTitle35ImageName01 = @"title35_n01";
static NSString *const kTitle35ImageName02 = @"title35_n02";
static NSString *const kTitle35ImageName03 = @"title35_n03";

// The reference width the phone layout scale divides by, from the double at 0x10028f470.
static const CGFloat kTitleReferenceWidth = 320.0;

// The 4-inch-phone strip height multiplier applied to phoneRate, a float at 0x10028f8e0.
static const CGFloat kUnsealStripScale = 70.0;

// The top flip-book strip height per idiom: the double at 0x10028f210 (iPad) and the double at
// 0x10028f8d0 (3.5-inch phone). The 4-inch phone uses phoneRate * kUnsealStripScale instead.
static const CGFloat kTopStripHeightPad = 120.0;
static const CGFloat kTopStripHeightPhone35 = 55.0;

// The bottom strip's origin y (and the value passed to -setUnsealHeight:) per idiom: the double at
// 0x10028f8d8 (iPad, 119) and the double at 0x10028f640 (3.5-inch phone, 54). The 4-inch phone uses
// (int)(phoneRate * kUnsealStripScale - 1) instead. It sits one point above the top strip's
// height, so the two strips overlap by a point; this matches the binary.
static const CGFloat kBottomStripOriginYPad = 119.0;
static const CGFloat kBottomStripOriginYPhone35 = 54.0;

@implementation TitleViewControllerNte

// The binary keeps the ivars under their bare property names rather than the synthesised _-prefixed
// forms, so pin each backing ivar to its property name.
@synthesize topView = topView;
@synthesize bottomView = bottomView;
@synthesize topController = topController;
@synthesize bottomController = bottomController;

#pragma mark - Lifecycle

/** @ghidraAddress 0x71e74 */
- (instancetype)init {
    self = [super init];
    if (!self) {
        return self;
    }
    JubeatAppDelegate *appDelegate = JubeatAppDelegate.appDelegate;
    CGRect screenBounds = UIScreen.mainScreen.bounds;
    CGFloat width = screenBounds.size.width;
    CGFloat height = screenBounds.size.height;
    BOOL isPad = appDelegate.isPad;
    BOOL is4inch = appDelegate.is4inchAspect;

    // The layout scale for phones: the screen width relative to 320 points. The iPad does not
    // scale.
    phoneRate = isPad ? 1.0f : (float)(width / kTitleReferenceWidth);

    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    [center addObserver:self
               selector:@selector(suspend:)
                   name:UIApplicationDidEnterBackgroundNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(resume:)
                   name:UIApplicationWillEnterForegroundNotification
                 object:nil];

    // The 3.5-inch phone (neither iPad nor 4-inch) uses the smaller "title35" artwork set.
    NSArray<NSString *> *nameArray = @[ kTitleImageName01, kTitleImageName02, kTitleImageName03 ];
    if (!isPad && !is4inch) {
        nameArray = @[ kTitle35ImageName01, kTitle35ImageName02, kTitle35ImageName03 ];
    }

    // The top flip-book strip height.
    CGFloat topStripHeight;
    if (isPad) {
        topStripHeight = kTopStripHeightPad;
    } else if (is4inch) {
        topStripHeight = (CGFloat)(int)(phoneRate * kUnsealStripScale);
    } else {
        topStripHeight = kTopStripHeightPhone35;
    }
    topController =
        [[UnsealViewController alloc] initWithNameArray:nameArray
                                                 bounds:CGRectMake(0, 0, width, topStripHeight)];
    [self addChildViewController:topController];
    topController.aDelegate = self;
    [topController didMoveToParentViewController:self];

    // The bottom strip's origin y, also handed to the core controller as its "unseal height". It is
    // one point below the top strip's height per idiom.
    int unsealHeight;
    if (isPad) {
        unsealHeight = (int)kBottomStripOriginYPad;
    } else if (is4inch) {
        unsealHeight = (int)(phoneRate * kUnsealStripScale - 1.0f);
    } else {
        unsealHeight = (int)kBottomStripOriginYPhone35;
    }
    bottomController = [[NteTitleCoreController alloc]
        initWithNameArray:nameArray
                   bounds:CGRectMake(0, 0, width, height - unsealHeight)];
    [bottomController setUnsealHeight:unsealHeight];
    [self addChildViewController:bottomController];
    [bottomController didMoveToParentViewController:self];
    return self;
}

/** @ghidraAddress 0x72288 */
- (void)loadView {
    [super loadView];
    [topController loadView];
    [bottomController loadView];
}

/** @ghidraAddress 0x72494 */
- (void)viewDidLoad {
    [super viewDidLoad];
    JubeatAppDelegate *appDelegate = JubeatAppDelegate.appDelegate;
    BOOL isPad = appDelegate.isPad;
    BOOL is4inch = appDelegate.is4inchAspect;
    CGRect screenBounds = UIScreen.mainScreen.bounds;
    CGFloat width = screenBounds.size.width;
    CGFloat height = screenBounds.size.height;

    // The bottom container fills the screen below the top strip.
    CGFloat bottomStripY;
    if (isPad) {
        bottomStripY = kBottomStripOriginYPad;
    } else if (is4inch) {
        bottomStripY = (CGFloat)(int)(phoneRate * kUnsealStripScale - 1.0f);
    } else {
        bottomStripY = kBottomStripOriginYPhone35;
    }
    bottomView =
        [[UIView alloc] initWithFrame:CGRectMake(0, bottomStripY, width, height - bottomStripY)];
    bottomController.view.frame = bottomView.bounds;
    [bottomView addSubview:bottomController.view];
    [self.view addSubview:bottomView];

    // The top container holds the flip-book strip.
    CGFloat topStripHeight;
    if (isPad) {
        topStripHeight = kTopStripHeightPad;
    } else if (is4inch) {
        topStripHeight = (CGFloat)(int)(phoneRate * kUnsealStripScale);
    } else {
        topStripHeight = kTopStripHeightPhone35;
    }
    topView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, topStripHeight)];
    topView.backgroundColor = UIColor.clearColor;
    topController.view.frame = topView.bounds;
    [topView addSubview:topController.view];
    [self.view addSubview:topView];
}

/** @ghidraAddress 0x72868 */
- (void)viewDidUnload {
    [super viewDidUnload];
}

/** @ghidraAddress 0x728c8 */
- (void)dealloc {
    topView = nil;
    bottomView = nil;
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

#pragma mark - Title lifecycle

/** @ghidraAddress 0x722f8 */
- (void)start {
    [super start];
    [bottomController start];
}

/** @ghidraAddress 0x72354 */
- (void)showLogo {
    [bottomController showLogo];
}

/** @ghidraAddress 0x7236c */
- (void)stopAnimation {
    // This override tears down both child controllers and stops the bottom controller. It does not
    // chain up to the base -stopAnimation, so the base's network teardown is deliberately skipped.
    [topController willMoveToParentViewController:nil];
    [topController.view removeFromSuperview];
    [topController removeFromParentViewController];
    topController = nil;
    [bottomController stopAnimation];
    [bottomController willMoveToParentViewController:nil];
    [bottomController.view removeFromSuperview];
    [bottomController removeFromParentViewController];
    bottomController = nil;
}

#pragma mark - Notifications

/** @ghidraAddress 0x7248c */
- (void)suspend:(NSNotification *)notification {
    // Intentionally empty.
}

/** @ghidraAddress 0x72490 */
- (void)resume:(NSNotification *)notification {
    // Intentionally empty.
}

#pragma mark - UnsealViewControllerDelegate

/** @ghidraAddress 0x72474 */
- (void)changeSelectedImage:(int)index completed:(BOOL)completed {
    [bottomController changeTitleBg:index completed:completed];
}

#pragma mark - Rotation

/** @ghidraAddress 0x728a0 */
- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                duration:(NSTimeInterval)duration {
    // Intentionally empty.
}

/** @ghidraAddress 0x728a4 */
- (void)viewWillTransitionToSize:(CGSize)size
       withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    // Intentionally empty.
}

/** @ghidraAddress 0x728a8 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // The binary tests (unsigned)(orientation - 1) < 2, which is exactly the two portrait cases:
    // UIInterfaceOrientationPortrait (1) and UIInterfaceOrientationPortraitUpsideDown (2).
    return interfaceOrientation == UIInterfaceOrientationPortrait ||
           interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown;
}

/** @ghidraAddress 0x728b8 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

/** @ghidraAddress 0x728c0 */
- (BOOL)shouldAutorotate {
    return YES;
}

@end
