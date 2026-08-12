#import "SettingsTwCustomViewController.h"

#import "JubeatAppDelegate.h"
#import "ResultTweet.h"

// Not yet reconstructed. ResultTweet vends the composed decoration images; its class object is at
// 0x348268 and only +getTwitterImagePath: is declared in its header so far. These two class
// factories are declared here until ResultTweet is fully reconstructed.
@interface ResultTweet (SettingsTwCustomPreview)
+ (UIImage *)getSampleImage:(NSString *)frameName;
+ (UIImage *)getAccessoryImage:(NSString *)accessoryName;
@end

// The private preview helpers and the ivars, none of which the header exposes.
@interface SettingsTwCustomViewController () {
    UIImageView *frameImage;    // The scaled background-frame sample. // +0x8
    UIImageView *accImage;      // The accessory composited over the frame. // +0x10
    NSMutableArray *frameTable; // The selectable frame themes, each a mutable row. // +0x18
    int windowWidth;            // The preview window width. // +0x20
    int selectedItem;           // The chosen row, or kNoSelection. // +0x24
    float fScale;               // The device scale applied to every preview rect. // +0x28
}

/**
 * @brief The frame row whose identifier matches the stored selected frame.
 * @return The matching row, or @c nil when none matches.
 * @ghidraAddress 0x1c511c
 */
- (NSArray *)getSelectedFrame;

/**
 * @brief Reloads the frame image from the stored selected-frame default.
 * @ghidraAddress 0x1c52f4
 */
- (void)refreshFrame;

/**
 * @brief Scales a rect's every component by the device scale @c fScale .
 * @param rect The unscaled rect.
 * @return The scaled rect.
 * @ghidraAddress 0x1c4784
 */
- (CGRect)makeRect:(CGRect)rect;
@end

// The row layout of each frame theme. Element 0 is a sequential identifier that is never read.
enum {
    kFrameRowNameIndex = 1,       // The display name.
    kFrameRowIdentifierIndex = 2, // The frame identifier compared against the stored default.
    kFrameRowCostIndex = 3        // The point cost.
};

// The sentinel meaning no row is selected.
static const int kNoSelection = -1;

// The point cost of the free default frame, and of a locked theme.
static const int kFreeFrameCost = 0;
static const int kLockedFrameCost = 100;

// The navigation title, from the CFString at 0x2e0800.
static NSString *const kNavigationTitle = @"Twitter Customize";

// The frame theme strings. Row 0 pairs a distinct display name with its resource identifier; the
// other rows reuse one string for both. From the CFStrings at 0x2e0820, 0x2d8240, 0x2d8280,
// 0x2d82c0, and 0x2d8300.
static NSString *const kFrameNameDefault = @"default";
static NSString *const kFrameIdentifierShareData = @"shareData";
static NSString *const kFrameThemeClassic = @"classic";
static NSString *const kFrameThemeRipples = @"ripples";
static NSString *const kFrameThemeKnit = @"knit";

// The user-defaults key holding the currently selected Twitter frame identifier.
static NSString *const kSelectedFrameDefaultsKey = @"PrefTwitterBgFrame";

// The empty accessory identifier passed at load time (the CFString at 0x2d42e0 wraps "").
static NSString *const kInitialAccessoryIdentifier = @"";

// The scale applied on iPad: the preview is shown at its native size.
static const float kPadScale = 1.0f; // fmov immediate at 0x1c4d50 (0x3f800000).

// The reference width the phone scale divides the screen width by, from the double at 0x28f900.
static const CGFloat kScaleReferenceWidth = 540.0; // @ghidraAddress 0x28f900

// The dimmed backdrop's white component and alpha. The white is not a predefined class colour.
static const CGFloat kBackdropWhite = 0.8; // @ghidraAddress 0x28e080
static const CGFloat kBackdropAlpha = 1.0; // fmov immediate at 0x1c4e98 (0x3ff0000000000000).

// The unscaled frame-preview rect: {0, 100, 540, 380}. The x is a zeroed vector; the others are
// __const doubles.
static const CGFloat kFramePreviewX = 0.0;        // movi at 0x1c4fe4.
static const CGFloat kFramePreviewY = 100.0;      // @ghidraAddress 0x28f3f0
static const CGFloat kFramePreviewWidth = 540.0;  // @ghidraAddress 0x28f900
static const CGFloat kFramePreviewHeight = 380.0; // @ghidraAddress 0x28f918

// The unscaled accessory-preview rect: {22, 22, 130, 130}.
static const CGFloat kAccessoryPreviewOrigin = 22.0; // fmov immediate at 0x1c50b4 (22.0).
static const CGFloat kAccessoryPreviewSize = 130.0;  // @ghidraAddress 0x28fa38

@implementation SettingsTwCustomViewController

#pragma mark - Construction

/** @ghidraAddress 0x1c47a8 */
- (instancetype)init {
    self = [super init];
    if (self) {
        self.navigationItem.title = kNavigationTitle;
        NSArray *dataSource = @[
            @[ @0, kFrameNameDefault, kFrameIdentifierShareData, @(kFreeFrameCost) ],
            @[ @1, kFrameThemeClassic, kFrameThemeClassic, @(kLockedFrameCost) ],
            @[ @2, kFrameThemeRipples, kFrameThemeRipples, @(kLockedFrameCost) ],
            @[ @3, kFrameThemeKnit, kFrameThemeKnit, @(kLockedFrameCost) ]
        ];
        frameTable = [[NSMutableArray alloc] init];
        // Deep-copy each supplied row into its own mutable array.
        for (NSUInteger i = 0; i < dataSource.count; ++i) {
            [frameTable addObject:[NSMutableArray arrayWithArray:dataSource[i]]];
        }
        if ([NSUserDefaults.standardUserDefaults objectForKey:kSelectedFrameDefaultsKey] == nil) {
            // Seeds the default from the first row's element 1 (its display name), not its
            // identifier at element 2 that everything else matches against.
            [NSUserDefaults.standardUserDefaults setObject:frameTable[0][kFrameRowNameIndex]
                                                    forKey:kSelectedFrameDefaultsKey];
        }
        selectedItem = kNoSelection;
    }
    return self;
}

#pragma mark - View lifecycle

/** @ghidraAddress 0x1c4cc4 */
- (void)loadView {
    [super loadView];
    if ([JubeatAppDelegate.appDelegate isPad]) {
        fScale = kPadScale;
    } else {
        fScale = (float)(UIScreen.mainScreen.bounds.size.width / kScaleReferenceWidth);
    }

    // The navigation bar's frame is fetched only for effect; the result is discarded.
    (void)self.navigationController.navigationBar.frame;

    UIView *backdrop = [[UIView alloc] initWithFrame:self.view.bounds];
    backdrop.opaque = NO;
    backdrop.backgroundColor = [UIColor colorWithWhite:kBackdropWhite alpha:kBackdropAlpha];
    backdrop.hidden = NO;
    [self.view addSubview:backdrop];

    UIImage *frameSample = [ResultTweet getSampleImage:[NSUserDefaults.standardUserDefaults
                                                           objectForKey:kSelectedFrameDefaultsKey]];
    frameImage = [[UIImageView alloc] initWithImage:frameSample];
    frameImage.frame = [self
        makeRect:CGRectMake(
                     kFramePreviewX, kFramePreviewY, kFramePreviewWidth, kFramePreviewHeight)];
    frameImage.userInteractionEnabled = YES;
    [self.view addSubview:frameImage];

    UIImage *accessorySample = [ResultTweet getAccessoryImage:kInitialAccessoryIdentifier];
    accImage = [[UIImageView alloc] initWithImage:accessorySample];
    accImage.frame = [self makeRect:CGRectMake(kAccessoryPreviewOrigin,
                                               kAccessoryPreviewOrigin,
                                               kAccessoryPreviewSize,
                                               kAccessoryPreviewSize)];
    [frameImage addSubview:accImage];
}

/** @ghidraAddress 0x1c5524 */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

/** @ghidraAddress 0x1c555c */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

/** @ghidraAddress 0x1c5594 */
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [NSUserDefaults.standardUserDefaults synchronize];
}

/** @ghidraAddress 0x1c5608 */
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

#pragma mark - Preview

/** @ghidraAddress 0x1c4784 */
- (CGRect)makeRect:(CGRect)rect {
    CGFloat scale = fScale;
    return CGRectMake(rect.origin.x * scale,
                      rect.origin.y * scale,
                      rect.size.width * scale,
                      rect.size.height * scale);
}

/** @ghidraAddress 0x1c511c */
- (NSArray *)getSelectedFrame {
    NSString *stored = [NSUserDefaults.standardUserDefaults objectForKey:kSelectedFrameDefaultsKey];
    for (NSArray *row in frameTable) {
        if ([stored isEqualToString:row[kFrameRowIdentifierIndex]]) {
            return row;
        }
    }
    return nil;
}

/** @ghidraAddress 0x1c52f4 */
- (void)refreshFrame {
    NSString *stored = [NSUserDefaults.standardUserDefaults objectForKey:kSelectedFrameDefaultsKey];
    frameImage.image = [ResultTweet getSampleImage:stored];
}

#pragma mark - SettingsTwFrameSelectViewDelegate

/** @ghidraAddress 0x1c53b0 */
- (void)frameChange:(NSString *)identifier {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    // Preview the highlighted frame without persisting: swap it in, refresh, then restore.
    NSString *stored = [defaults objectForKey:kSelectedFrameDefaultsKey];
    [defaults setObject:identifier forKey:kSelectedFrameDefaultsKey];
    [self refreshFrame];
    [defaults setObject:stored forKey:kSelectedFrameDefaultsKey];
}

/** @ghidraAddress 0x1c5494 */
- (void)frameSelected:(NSString *)identifier {
    [self frameChange:identifier];
    [NSUserDefaults.standardUserDefaults setObject:identifier forKey:kSelectedFrameDefaultsKey];
}

#pragma mark - Orientation

/** @ghidraAddress 0x1c5640 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Portrait (1) and portrait-upside-down (2): the unsigned (orientation - 1) < 2 test.
    return (NSUInteger)(interfaceOrientation - 1) < 2;
}

/** @ghidraAddress 0x1c5650 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

/** @ghidraAddress 0x1c5658 */
- (BOOL)shouldAutorotate {
    return YES;
}

@end
