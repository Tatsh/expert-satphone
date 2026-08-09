#import "SettingsButtonAreaViewController.h"

#import <QuartzCore/QuartzCore.h>

#import "EAGLView.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"
#import "Texture2D.h"

// The persisted preview button width, stored as a float.
static NSString *const kButtonWidthDefaultsKey = @"PrefButtonWidth";

// Slider end-cap images and the button atlas.
static NSString *const kSliderMaxImageName = @"button_area_max";
static NSString *const kSliderMinImageName = @"button_area_min";
static NSString *const kButtonAtlasImageName = @"button_test_tex";
static NSString *const kButtonAtlasPlistName = @"button_test_tex_pn";
static NSString *const kButtonAtlasPlistRetinaName = @"button_test_tex_pn2";
static NSString *const kAdviceImageName = @"button_area_advice";

// Localised caption shown beside the preview.
static NSString *const kCaptionKey = @"TouchAreaMessage";

// The preview column is a fixed 320-point-wide area, centred horizontally within the screen.
static const CGFloat kContentSize = 320.0; // @ghidraAddress 0x28f470

// Slider geometry (points).
static const int kSliderInsetX = 10;
static const CGFloat kSliderTopFourInch = 100.0; // @ghidraAddress 0x28f3f0
static const CGFloat kSliderTop = 70.0;          // @ghidraAddress 0x28f6a0
static const CGFloat kSliderWidth = 300.0;       // @ghidraAddress 0x28f2d0
static const CGFloat kSliderHeight = 32.0;       // @ghidraAddress 0x28f458

// Vertical offset of the preview grid, larger on a taller 4-inch screen.
static const CGFloat kGridTopFourInch = 234.0; // @ghidraAddress 0x292908
static const CGFloat kGridTop = 160.0;         // @ghidraAddress 0x28f438

// Caption area geometry (points).
static const int kCaptionInsetX = 5;
static const int kCaptionTopFourInch = 20;
static const int kCaptionTop = 5;
static const CGFloat kCaptionAreaHeight = 60.0; // @ghidraAddress 0x28f258
static const CGFloat kCaptionWidthBase = 305.0; // @ghidraAddress 0x292910
static const int kAdviceRightInset = 316;

// Button grid layout. The 4x4 grid is drawn on an 80-point cell pitch.
static const unsigned int kButtonCount = 16;
static const unsigned int kButtonGridColumns = 4;
static const CGFloat kButtonCellPitch = 80.0;
static const CGFloat kButtonHitBaseSize = 80.0f;  // @ghidraAddress 0x28e018
static const CGFloat kButtonMarkerOffsetX = 40.0; // @ghidraAddress 0x28f1f8

// Each unit of slider width grows a button's hit rectangle by this many points per side; the
// scale is an fmov immediate at 0x1119ec (20.0).
static const CGFloat kButtonWidthHitScale = 20.0f;

// Sprite indices in the button atlas.
static const NSUInteger kSpritePressed = 0;
static const NSUInteger kSpriteReleased = 1;
static const NSUInteger kSpriteMarker = 2;

@implementation SettingsButtonAreaViewController {
    unsigned int buttonDown;
    unsigned int buttonUp;
    unsigned int buttonPress;
    unsigned int buttonPressOld;
    BOOL paused;
}

#pragma mark - Construction

/** @ghidraAddress 0x111854 */
- (instancetype)init {
    self = [super init];
    if (self) {
        self.navigationItem.title = @"TOUCH AREA";
        // The opaque-bar opt-out only exists on iOS 7 and later.
        if ([self respondsToSelector:@selector(setExtendedLayoutIncludesOpaqueBars:)]) {
            [self performSelector:@selector(setExtendedLayoutIncludesOpaqueBars:) withObject:nil];
        }
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self
                   selector:@selector(appSuspended:)
                       name:UIApplicationDidEnterBackgroundNotification
                     object:nil];
        [center addObserver:self
                   selector:@selector(appResumed:)
                       name:UIApplicationWillEnterForegroundNotification
                     object:nil];
        paused = NO;
    }
    return self;
}

/** @ghidraAddress 0x112ef0 */
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.displayLink invalidate];
    // ARC emits the [super dealloc] the binary calls here.
}

#pragma mark - View lifecycle

/** @ghidraAddress 0x111df8 */
- (void)loadView {
    BOOL is4inch = JubeatAppDelegate.appDelegate.is4inchAspect;
    [super loadView];
    self.view.backgroundColor = UIColor.blackColor;

    int screenWidth = (int)CGRectGetWidth(UIScreen.mainScreen.bounds);
    int originX = (screenWidth - (int)kContentSize) / 2;

    self.slider =
        [[UISlider alloc] initWithFrame:CGRectMake(originX + kSliderInsetX,
                                                   is4inch ? kSliderTopFourInch : kSliderTop,
                                                   kSliderWidth,
                                                   kSliderHeight)];
    self.slider.backgroundColor = UIColor.clearColor;
    [self.slider addTarget:self
                    action:@selector(buttonWidthChanged:)
          forControlEvents:UIControlEventValueChanged];
    self.slider.continuous = NO;
    self.slider.value = [NSUserDefaults.standardUserDefaults floatForKey:kButtonWidthDefaultsKey];
    self.slider.maximumValueImage = LoadScaledPngImage(kSliderMaxImageName);
    self.slider.minimumValueImage = LoadScaledPngImage(kSliderMinImageName);
    [self.view addSubview:self.slider];

    CGFloat navBarHeight = CGRectGetHeight(self.navigationController.navigationBar.frame);
    self.glView = [[EAGLView alloc]
        initWithFrame:CGRectMake(originX,
                                 (is4inch ? kGridTopFourInch : kGridTop) - navBarHeight,
                                 kContentSize,
                                 kContentSize)];
    self.glView.opaque = YES;
    self.glView.multipleTouchEnabled = YES;
    if (JubeatAppDelegate.appDelegate.isPhoneRetina) {
        self.glView.contentScaleFactor = 2.0;
    }
    [self.glView createFramebuffer];
    [self.glView set2dSpace:CGSizeMake(kContentSize, kContentSize)];
    // The binary sends -self before -view; the extra hop is preserved for fidelity.
    [self.view addSubview:self.glView];

    self.texButtons = [[Texture2D alloc] initWithImage:LoadScaledPngImage(kButtonAtlasImageName)];
    NSString *plistName = kButtonAtlasPlistName;
    if (JubeatAppDelegate.appDelegate.isPhoneRetina) {
        self.texButtons.isScale2x = YES;
        plistName = kButtonAtlasPlistRetinaName;
    }
    NSString *plistPath = [NSBundle.mainBundle pathForResource:plistName ofType:@"plist"];
    if (plistPath) {
        self.texButtons.sprites = [[NSArray alloc] initWithContentsOfFile:plistPath];
    }
    [self loop:nil];

    UIImageView *adviceView =
        [[UIImageView alloc] initWithImage:LoadScaledPngImage(kAdviceImageName)];
    adviceView.layer.borderColor = UIColor.whiteColor.CGColor;
    adviceView.layer.borderWidth = JubeatAppDelegate.appDelegate.isPhoneRetina ? 0.5 : 1.0;
    adviceView.layer.cornerRadius = 4.0;
    CGSize adviceSize = adviceView.frame.size;
    int captionTop = is4inch ? kCaptionTopFourInch : kCaptionTop;
    adviceView.frame = CGRectMake((originX + kAdviceRightInset) - adviceSize.width,
                                  captionTop + (int)(kCaptionAreaHeight - adviceSize.height) / 2,
                                  adviceSize.width,
                                  adviceSize.height);
    [self.view addSubview:adviceView];

    UILabel *caption =
        [[UILabel alloc] initWithFrame:CGRectMake(originX + kCaptionInsetX,
                                                  captionTop,
                                                  kCaptionWidthBase - adviceSize.width,
                                                  kCaptionAreaHeight)];
    caption.backgroundColor = UIColor.clearColor;
    caption.textColor = UIColor.whiteColor;
    caption.numberOfLines = 0;
    caption.font = [UIFont systemFontOfSize:14.0];
    caption.text = [NSBundle.mainBundle localizedStringForKey:kCaptionKey value:@"" table:nil];
    [self.view addSubview:caption];
}

/** @ghidraAddress 0x112ba0 */
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

/** @ghidraAddress 0x112bd8 */
- (void)viewDidUnload {
    [super viewDidUnload];
    self.slider = nil;
    self.glView = nil;
    self.texButtons = nil;
}

/** @ghidraAddress 0x112c58 */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

/** @ghidraAddress 0x112c90 */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!self.displayLink) {
        self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(loop:)];
        self.displayLink.frameInterval = 2;
        [self.displayLink addToRunLoop:NSRunLoop.currentRunLoop forMode:NSRunLoopCommonModes];
    }
}

/** @ghidraAddress 0x112de4 */
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.displayLink) {
        [self.displayLink invalidate];
        self.displayLink = nil;
    }
}

/** @ghidraAddress 0x112e98 */
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

#pragma mark - Render loop

/** @ghidraAddress 0x1119a0 */
- (void)loop:(CADisplayLink *)displayLink {
    if (paused) {
        return;
    }

    CGFloat width = [self.slider value];
    [self.glView prepareToRender];

    buttonPressOld = buttonPress;
    buttonPress = 0;

    CGFloat hitInset = width * kButtonWidthHitScale;
    CGFloat hitSize = hitInset + hitInset + kButtonHitBaseSize;
    for (UITouch *touch in [self.glView touches]) {
        CGPoint point = [touch locationInView:self.glView];
        for (unsigned int i = 0; i < kButtonCount; ++i) {
            CGRect hitRect = CGRectMake((i % kButtonGridColumns) * kButtonCellPitch - hitInset,
                                        (i / kButtonGridColumns) * kButtonCellPitch - hitInset,
                                        hitSize,
                                        hitSize);
            if (CGRectContainsPoint(hitRect, point)) {
                buttonPress |= (1u << i);
            }
        }
    }

    buttonDown = buttonPress & ~buttonPressOld;
    buttonUp = buttonPressOld & ~buttonPress;

    for (unsigned int i = 0; i < kButtonCount; ++i) {
        CGFloat x = (i % kButtonGridColumns) * kButtonCellPitch;
        CGFloat y = (i / kButtonGridColumns) * kButtonCellPitch;
        if (buttonPress & (1u << i)) {
            [self.texButtons drawSprite:kSpritePressed atPoint:CGPointMake(x, y)];
        } else {
            [self.texButtons drawSprite:kSpriteReleased atPoint:CGPointMake(x, y)];
            [self.texButtons drawSprite:kSpriteMarker
                                atPoint:CGPointMake(x + kButtonMarkerOffsetX, y)
                              transform:1
                                  alpha:1.0f];
        }
    }

    [self.texButtons commitDraw];
    [self.glView swapBuffer];
}

#pragma mark - Slider

/** @ghidraAddress 0x1129f4 */
- (void)buttonWidthChanged:(UISlider *)sender {
    [NSUserDefaults.standardUserDefaults setFloat:[self.slider value]
                                           forKey:kButtonWidthDefaultsKey];
}

#pragma mark - Application state

/** @ghidraAddress 0x112a7c */
- (void)appSuspended:(NSNotification *)notification {
    paused = YES;
    if (self.displayLink) {
        self.displayLink.paused = YES;
    }
}

/** @ghidraAddress 0x112b10 */
- (void)appResumed:(NSNotification *)notification {
    paused = NO;
    if (self.displayLink) {
        self.displayLink.paused = NO;
    }
}

#pragma mark - Rotation

/** @ghidraAddress 0x112ed0 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Portrait and portrait-upside-down (orientations 1 and 2), matching the mask of 6 below. The
    // binary tests (orientation - 1) as unsigned, so any other value is refused.
    return (unsigned int)(interfaceOrientation - 1) < 2;
}

/** @ghidraAddress 0x112ee0 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

/** @ghidraAddress 0x112ee8 */
- (BOOL)shouldAutorotate {
    return YES;
}

@end
