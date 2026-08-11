#import "EditHowtoViewController.h"

#import "ImageLoading.h"
#import "JubeatAppDelegate.h"

// The format producing the two help-image base names: edithelp01 and edithelp02.
static NSString *const kHowtoImageNameFormat = @"edithelp%02d";

// The pad frame dimensions; on the phone the frame follows the screen bounds. Unlike the settings
// "how to" screen, this one does not subtract the navigation bar's height. @ghidraAddress
// 0x28f900 (width), 0x291c78 (height).
static const CGFloat kPadWidth = 540.0;
static const CGFloat kPadHeight = 620.0;

// The number of help pages, and the horizontal content multiplier (one screen width per page).
static const NSInteger kPageCount = 2;
static const CGFloat kContentWidthMultiplier = 2.0;

// The page control's frame: width kPageControlWidth centred horizontally by insetting the parent
// width by that same amount, pinned to the top, height kPageControlHeight. @ghidraAddress
// 0x291e20 (inset), 0x28f210 (width).
static const CGFloat kPageControlWidthInset = -120.0;
static const CGFloat kPageControlWidth = 120.0;
static const CGFloat kPageControlHeight = 20.0;

// The raw supported-orientation mask the binary returns: 6, i.e. portrait and portrait-upside-down
// (UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown). Kept as the
// literal the binary uses rather than a named mask, since it is not one of the common combinations.
static const UIInterfaceOrientationMask kSupportedOrientations =
    UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;

@implementation EditHowtoViewController

#pragma mark - Construction

/** @ghidraAddress 0x209894 */
- (instancetype)init {
    self = [super init];
    if (self) {
        self.preferredContentSize = CGSizeMake(kPadWidth, kPadHeight);
    }
    return self;
}

#pragma mark - View construction

/** @ghidraAddress 0x209900 */
- (void)loadView {
    [super loadView];

    // The pad uses a fixed 540×620 area; the phone follows the screen bounds. Neither idiom
    // subtracts the navigation bar's height here.
    CGFloat width = kPadWidth;
    CGFloat height = kPadHeight;
    if (![JubeatAppDelegate appDelegate].isPad) {
        CGRect bounds = [UIScreen mainScreen].bounds;
        width = bounds.size.width;
        height = bounds.size.height;
    }

    self.scrView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    self.scrView.backgroundColor = UIColor.blackColor;
    self.scrView.pagingEnabled = YES;
    self.scrView.contentSize = CGSizeMake(width * kContentWidthMultiplier, height);
    self.scrView.showsVerticalScrollIndicator = NO;
    self.scrView.showsHorizontalScrollIndicator = NO;

    for (NSInteger page = 1; page <= kPageCount; ++page) {
        NSString *imageName = [NSString stringWithFormat:kHowtoImageNameFormat, (int)page];
        UIImage *image = LoadScaledPngImage(imageName);
        if (image) {
            UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
            // Each page's image is centred in its own screen-width column: page 1's centre sits at
            // half a width, page 2's at one and a half.
            imageView.center = CGPointMake(width * (CGFloat)(2 * page - 1) * 0.5, height * 0.5);
            [self.scrView addSubview:imageView];
        }
    }

    self.scrView.delegate = self;
    [self.view addSubview:self.scrView];

    self.pageCtrl =
        [[UIPageControl alloc] initWithFrame:CGRectMake((width + kPageControlWidthInset) * 0.5,
                                                        0,
                                                        kPageControlWidth,
                                                        kPageControlHeight)];
    self.pageCtrl.numberOfPages = kPageCount;
    self.pageCtrl.currentPage = 0;
    self.pageCtrl.autoresizingMask = UIViewAutoresizingNone;
    self.pageCtrl.userInteractionEnabled = NO;
    [self.view addSubview:self.pageCtrl];
}

#pragma mark - Scroll view delegate

/** @ghidraAddress 0x209f10 */
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat width = self.scrView.frame.size.width;
    self.pageCtrl.currentPage =
        (NSInteger)(floor((self.scrView.contentOffset.x - width * 0.5) / width) + 1.0);
}

#pragma mark - Lifecycle

/** @ghidraAddress 0x209fec */
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

/** @ghidraAddress 0x20a024 */
- (void)viewDidUnload {
    [super viewDidUnload];
    self.scrView = nil;
    self.pageCtrl = nil;
}

/** @ghidraAddress 0x20a090 */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

/** @ghidraAddress 0x20a0c8 */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

/** @ghidraAddress 0x20a100 */
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

/** @ghidraAddress 0x20a138 */
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

#pragma mark - Rotation

/** @ghidraAddress 0x20a170 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Portrait and portrait-upside-down (orientations 1 and 2), matching the mask of 6 above. The
    // binary tests (orientation - 1) as unsigned, so any other value — including 0 — is refused.
    return (unsigned int)(interfaceOrientation - 1) < 2;
}

/** @ghidraAddress 0x20a180 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return kSupportedOrientations;
}

/** @ghidraAddress 0x20a188 */
- (BOOL)shouldAutorotate {
    return YES;
}

@end
