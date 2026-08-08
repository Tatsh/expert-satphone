#import "UnsealViewController.h"

#import "UnsealDrawController.h"

// Each page's artwork file name is the array entry with this suffix appended, matching the
// binary's @c stringWithFormat: template at 0x15c3b0.
static NSString *const kUnsealPageNameFormat = @"%@_0";

@implementation UnsealViewController {
    UIPageViewController *unsealCtrl;
    NSMutableArray<UnsealDrawController *> *pageArray;
    NSArray<NSString *> *fileArray;
    int currentIndex;
    BOOL bDrawNextPage;
    CGRect bgBounds;
}

#pragma mark - Construction

/** @ghidraAddress 0x15c094 */
- (instancetype)initWithNameArray:(NSArray<NSString *> *)nameArray bounds:(CGRect)bounds {
    // Chains to plain -init, not -initWithNibName:bundle:, so there is no nib.
    self = [super init];
    if (self) {
        bgBounds = bounds;
        fileArray = [nameArray copy];
    }
    return self;
}

#pragma mark - View lifecycle

/** @ghidraAddress 0x15c154 */
- (void)loadView {
    [super loadView];
    // A page-curl, horizontally paged viewer with no options dictionary.
    unsealCtrl = [[UIPageViewController alloc]
        initWithTransitionStyle:UIPageViewControllerTransitionStylePageCurl
          navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal
                        options:nil];
    unsealCtrl.delegate = self;
    unsealCtrl.dataSource = self;
    for (UIGestureRecognizer *recognizer in unsealCtrl.gestureRecognizers) {
        recognizer.delegate = self;
    }
    pageArray = [[NSMutableArray alloc] init];
    CGRect pageBounds = bgBounds;
    for (NSUInteger i = 0; i < fileArray.count; ++i) {
        NSString *fileName = [NSString stringWithFormat:kUnsealPageNameFormat, fileArray[i]];
        UnsealDrawController *page = [[UnsealDrawController alloc] initWithFileName:fileName
                                                                              frame:pageBounds];
        page.pageTag = (int)i;
        [pageArray addObject:page];
    }
    [unsealCtrl setViewControllers:@[ pageArray[0] ]
                         direction:UIPageViewControllerNavigationDirectionForward
                          animated:YES
                        completion:nil];
    [self addChildViewController:unsealCtrl];
    // The binary reads the view frame twice: once at 0x15c50c just for its height, once at
    // 0x15c550 for the rest. The height is floored to a whole number by the fcvtzs/scvtf pair at
    // 0x15c510/0x15c554, the origin is zeroed, and the width is kept as-is.
    CGFloat height = (CGFloat)(int)self.view.frame.size.height;
    CGRect frame = self.view.frame;
    frame.origin = CGPointZero;
    frame.size.height = height;
    unsealCtrl.view.frame = frame;
    [self.view addSubview:unsealCtrl.view];
    [unsealCtrl didMoveToParentViewController:self];
}

/** @ghidraAddress 0x15c634 */
- (void)viewDidLoad {
    [super viewDidLoad];
}

/** @ghidraAddress 0x15c7a4 */
- (void)viewDidUnload {
    [super viewDidUnload];
}

#pragma mark - UIPageViewControllerDataSource

/** @ghidraAddress 0x15c66c */
- (nullable UIViewController *)pageViewController:(UIPageViewController *)pageViewController
                viewControllerAfterViewController:(UIViewController *)viewController {
    // There is never a page after the current one; a turn only ever goes backwards.
    return nil;
}

/** @ghidraAddress 0x15c674 */
- (nullable UIViewController *)pageViewController:(UIPageViewController *)pageViewController
               viewControllerBeforeViewController:(UIViewController *)viewController {
    bDrawNextPage = YES;
    int currentTag = ((UnsealDrawController *)viewController).pageTag;
    int index = rand();
    NSUInteger count = pageArray.count;
    if (count != 0) {
        index = index % (int)count;
    }
    // Never repeat the current page: step past it, wrapping back to the first page.
    if (currentTag == index) {
        ++index;
    }
    if (count <= (NSUInteger)index) {
        index = 0;
    }
    currentIndex = index;
    return pageArray[index];
}

#pragma mark - UIPageViewControllerDelegate

/** @ghidraAddress 0x15c730 */
- (void)pageViewController:(UIPageViewController *)pageViewController
         didFinishAnimating:(BOOL)finished
    previousViewControllers:(NSArray<UIViewController *> *)previousViewControllers
        transitionCompleted:(BOOL)completed {
    bDrawNextPage = NO;
    [self.aDelegate changeSelectedImage:currentIndex completed:completed];
}

/** @ghidraAddress 0x15c79c */
- (UIPageViewControllerSpineLocation)pageViewController:(UIPageViewController *)pageViewController
                   spineLocationForInterfaceOrientation:(UIInterfaceOrientation)orientation {
    return UIPageViewControllerSpineLocationMax;
}

#pragma mark - UIGestureRecognizerDelegate

/** @ghidraAddress 0x15bf28 */
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if ([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
        UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gestureRecognizer;
        CGPoint velocity = [pan velocityInView:pan.view];
        // Refuse a leftward pan (negative horizontal velocity); only rightward turns are allowed.
        if (velocity.x < 0.0) {
            return NO;
        }
    }
    return YES;
}

/** @ghidraAddress 0x15bfdc */
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
       shouldReceiveTouch:(UITouch *)touch {
    if ([gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]) {
        return NO;
    }
    if ([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]] && bDrawNextPage) {
        return NO;
    }
    return YES;
}

@end
