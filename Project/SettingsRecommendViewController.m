#import "SettingsRecommendViewController.h"

#import "AlertViewManager.h"
#import "JubeatAppDelegate.h"

// The recommend ad-area API this controller drives, and the informal view-delegate callbacks it
// implements. RecommendNetwork is not reconstructed in this tree yet. See TYPES_PENDING.md.
@interface RecommendNetwork : NSObject
+ (void)openAdAreaWithParentView:(nullable UIView *)parentView
                            rect:(CGRect)rect
                         adModel:(int)adModel
                      adLocation:(nullable NSString *)adLocation
                   verticalAlign:(int)verticalAlign
                        delegate:(nullable id)delegate;
+ (void)closeAdAreaWithParentView:(nullable UIView *)parentView;
@end

// The ad location the settings recommend area is opened at.
static NSString *const kAdLocationTop = @"ADL_TOP";

// The pad frame dimensions; on the phone the frame follows the screen bounds less a top inset.
static const CGFloat kPadWidth = 540.0;
static const CGFloat kPadHeight = 576.0;
static const CGFloat kPhoneHeightInset = -44.0;

// The loading spinner's scale-up factor.
static const float kIndicatorScale = 1.5f;

// The raw supported-orientation mask the binary returns: 6, i.e. portrait and portrait-upside-down
// (UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown). Kept as the
// literal the binary uses rather than a named mask, since it is not one of the common combinations.
static const UIInterfaceOrientationMask kSupportedOrientations =
    UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;

@interface SettingsRecommendViewController () {
    UIView *bgView;           // +0x8
    UIWebView *recommendView; // +0x10
}
- (void)appListDidAppear;
- (void)appListDidDisappear;
- (void)appListFailLoadWithError:(nullable NSError *)error;
@end

@implementation SettingsRecommendViewController

@synthesize indicatorView = _indicatorView;

#pragma mark - Construction

/** @ghidraAddress 0xcf890 */
- (instancetype)init {
    self = [super init];
    if (!self) {
        return self;
    }
    // The pad uses a fixed 540×576 area; the phone follows the screen bounds less a 44 pt top
    // inset.
    CGFloat width = kPadWidth;
    CGFloat height = kPadHeight;
    if (![JubeatAppDelegate appDelegate].isPad) {
        CGRect bounds = [UIScreen mainScreen].bounds;
        width = bounds.size.width;
        height = bounds.size.height + kPhoneHeightInset;
    }

    bgView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    bgView.backgroundColor = UIColor.grayColor;
    [self.view addSubview:bgView];

    recommendView = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    [self.view addSubview:recommendView];
    recommendView.alpha = 0;
    [RecommendNetwork openAdAreaWithParentView:recommendView
                                          rect:CGRectMake(0, 0, width, height)
                                       adModel:1
                                    adLocation:kAdLocationTop
                                 verticalAlign:0
                                      delegate:self];

    self.indicatorView = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    [self.indicatorView.layer setValue:@(kIndicatorScale) forKeyPath:@"transform.scale"];
    self.indicatorView.center = bgView.center;
    [self.indicatorView startAnimating];
    [bgView addSubview:self.indicatorView];
    return self;
}

#pragma mark - Recommend ad-area delegate

/** @ghidraAddress 0xcfca0 */
- (void)appListDidAppear {
    [self.indicatorView stopAnimating];
    recommendView.alpha = 0;
    __weak UIWebView *weakRecommendView = recommendView;
    [UIView animateWithDuration:0.5
        animations:^{
          /** @ghidraAddress 0xcfe08 */
          weakRecommendView.alpha = 1.0;
        }
        completion:^(BOOL __attribute__((unused)) finished) {
          /** @ghidraAddress 0xcfe54 */
          weakRecommendView.alpha = 1.0;
        }];
}

/** @ghidraAddress 0xcfe84 */
- (void)appListDidDisappear {
    // Empty in the binary.
}

/** @ghidraAddress 0xcfe88 */
- (void)appListFailLoadWithError:(NSError *)error {
    [self.indicatorView stopAnimating];
    (void)[error code]; // Yes, the binary reads the code and discards it.
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil];
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:nil
                                            tag:0
                                          title:nil
                                            msg:@"通信エラー"
                                         cancel:ok
                                        btnText:nil
                                           show:YES
                                 viewController:self];
}

#pragma mark - Lifecycle and rotation

/** @ghidraAddress 0xcffcc */
- (void)viewWillDisappear:(BOOL)animated {
    [JubeatAppDelegate appDelegate].hasNewRecommendNum = 0;
    [RecommendNetwork closeAdAreaWithParentView:recommendView];
    [[AlertViewManager sharedManager] closeAlert];
}

/** @ghidraAddress 0xd0070 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Landscape-left and landscape-right (the two orientations numbered 1 and 2 above portrait).
    return (NSInteger)interfaceOrientation - 1 < 2;
}

/** @ghidraAddress 0xd0080 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return kSupportedOrientations;
}

/** @ghidraAddress 0xd0088 */
- (BOOL)shouldAutorotate {
    return YES;
}

/** @ghidraAddress 0xd0090 */
- (void)dealloc {
    // [super dealloc] is compiler-emitted (ARC).
}

@end
