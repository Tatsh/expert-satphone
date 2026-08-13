#import "SettingsTimingAdjustViewController.h"

#import <QuartzCore/QuartzCore.h>

#import "AdjustTestView.h"
#import "AlertViewManager.h"
#import "AudioManager.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"

// The user-defaults key the calibration offset is persisted under.
static NSString *const kPrefAdjustSectorKey = @"PrefAdjustSector";
// The user-defaults key holding the current marker identifier the preview loads.
static NSString *const kPrefCurrentMarkerIDKey = @"PrefCurrentMarkerID";

// The background-music-finished notification the preview posts through AudioManager.
static NSString *const kFinishBgmNotificationName = @"JubeatAudioManagerFinishBgmNotifacation";

// The alert-info dictionary key carrying the tapped button index.
static NSString *const kBtnMessageKey = @"btnMessage";

// The navigation title, localised through the bundle.
static NSString *const kTitleKey = @"Adjust Timing";
// The localised heading the value label is formatted into.
static NSString *const kCurrentValueKey = @"Current Value";
// Localised button titles reused by the auto-calibration alerts.
static NSString *const kCancelKey = @"Cancel";
static NSString *const kOKKey = @"OK";

// The static maximum and minimum labels bracketing the slider.
static NSString *const kMaxLabelText = @"10";
static NSString *const kMinLabelText = @"-10";

// The auto-calibration confirmation message and its success message. Both are verbatim Japanese
// literals from the binary's __const CFString pool.
static NSString *const kAutoSettingConfirmMessage = @"ネットワークに接続し、最適な値を取得します。";
static NSString *const kAutoSettingDoneMessage = @"自動設定したよ！";

// The scaled-PNG base names for the background and the play/pause button graphics.
static NSString *const kBackgroundImageName = @"setting_adjust_timing2";
static NSString *const kMarkerTitleImageName = @"timing_btn_title";
static NSString *const kButtonBaseImageName = @"timing_btn_pbase";
static NSString *const kButtonPlayImageName = @"timing_btn_play";
static NSString *const kButtonPausedImageName = @"timing_btn_paused";

// The theme-prefixed sound-effect base names (see -soundName:).
static NSString *const kSoundNameRipplesFormat = @"SD_RPL_%@";
static NSString *const kSoundNameKnitFormat = @"SD_KNT_%@";
static NSString *const kSoundNameDefaultFormat = @"SD_%@";
// The two test sounds fed to -soundName:.
static NSString *const kSoundMusicSelect = @"MUSIC_SELECT";
static NSString *const kSoundSkip = @"SKIP";

// Pooled layout constants, each read from __const by the address in its trailing comment.
static const CGFloat kPadLayoutWidth = 540.0;  // @ghidraAddress 0x28f900
static const CGFloat kLabelHeight = 50.0;      // @ghidraAddress 0x28f2c8
static const CGFloat kBackgroundWhite = 0.8;   // @ghidraAddress 0x28e080
static const CGFloat kValueWidthDelta = -80.0; // @ghidraAddress 0x28f468
static const CGFloat kMaxLabelXDelta = -40.0;  // @ghidraAddress 0x28e078
static const CGFloat kSideInset = 40.0;        // @ghidraAddress 0x28f1f8
static const float kSliderMinimum = -40.0f;    // @ghidraAddress 0x293438
static const float kSliderMaximum = 40.0f;     // @ghidraAddress 0x292568

// The preview square's edge length: 288 on iPad, 144 on iPhone.
static const int kPadPreviewSize = 288;
static const int kPhonePreviewSize = 144;

// Per-idiom vertical shift applied to every control: 0 on iPad, -10 on iPhone.
static const int kPhoneTopOffset = -10;

@implementation SettingsTimingAdjustViewController {
    UISlider *adjustSlider;
    UILabel *adjustTxt;
    UILabel *valueTxt;
    UILabel *maxTxt;
    UILabel *minTxt;
    UIImageView *bgImg;
    AdjustTestView *testView;
    UIButton *prevBtn;
    BOOL prevPause;
    float delaySector;
}

#pragma mark - Lifecycle

/**
 * @ghidraAddress 0x1745e0
 */
- (instancetype)init {
    self = [super init];
    if (self) {
        NSBundle *bundle = NSBundle.mainBundle;
        self.navigationItem.title = [bundle localizedStringForKey:@"ADJUSTMENT TIMING"
                                                            value:@""
                                                            table:nil];
        delaySector = [NSUserDefaults.standardUserDefaults floatForKey:kPrefAdjustSectorKey];
        NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
        [center addObserver:self
                   selector:@selector(appSuspended:)
                       name:UIApplicationDidEnterBackgroundNotification
                     object:nil];
        [center addObserver:self
                   selector:@selector(appResume:)
                       name:UIApplicationWillEnterForegroundNotification
                     object:nil];
        [self startAnimation];
    }
    return self;
}

/**
 * @ghidraAddress 0x174740
 */
- (void)loadView {
    [super loadView];

    JubeatAppDelegate *appDelegate = JubeatAppDelegate.appDelegate;
    BOOL isPad = appDelegate.isPad;

    // Layout width: the pooled 540 on iPad, otherwise the main screen's width.
    CGFloat layoutWidth = kPadLayoutWidth;
    if (!isPad) {
        layoutWidth = UIScreen.mainScreen.bounds.size.width;
    }

    // The navigation bar's frame is fetched purely for effect; the result is discarded.
    (void)self.navigationController.navigationBar.frame; // Yes, the binary discards this frame.

    const int topOffset = isPad ? 0 : kPhoneTopOffset;
    const CGFloat labelInset = isPad ? 40.0 : 34.0; // fmov immediates 40.0 and 34.0.
    const CGFloat fontSize = isPad ? 20.0 : 18.0;   // fmov immediates 20.0 (0x4034) and 18.0.

    UIView *rootView = [[UIView alloc] initWithFrame:self.view.bounds];
    [rootView setOpaque:NO];
    // The binary builds this with colorWithWhite:0.8 alpha:1.0.
    rootView.backgroundColor = [UIColor colorWithWhite:kBackgroundWhite alpha:1.0];
    [rootView setHidden:NO];
    [self.view addSubview:rootView];

    // Background: a 50-inset stretchable image filling most of the width.
    UIImage *bgSource = LoadScaledPngImage(kBackgroundImageName);
    UIImage *bgResizable =
        [bgSource resizableImageWithCapInsets:UIEdgeInsetsMake(0.0, kLabelHeight, 0.0, kLabelHeight)
                                 resizingMode:UIImageResizingModeStretch];
    bgImg = [[UIImageView alloc] initWithImage:bgResizable];
    // x is the fmov immediate 10.0; width is layoutWidth - 20.0 (fmov immediate -20.0); the height
    // is the source image's natural height, read from [bgSource size].
    [bgImg setFrame:CGRectMake(
                        10.0, (CGFloat)(topOffset + 40), layoutWidth - 20.0, bgSource.size.height)];
    [self.view addSubview:bgImg];

    // Heading label.
    adjustTxt = [[UILabel alloc] initWithFrame:CGRectMake(labelInset,
                                                          (CGFloat)(topOffset + 50),
                                                          layoutWidth - (labelInset * 2.0),
                                                          kLabelHeight)];
    adjustTxt.text = [NSBundle.mainBundle localizedStringForKey:kTitleKey value:@"" table:nil];
    adjustTxt.font = [UIFont systemFontOfSize:fontSize];
    adjustTxt.numberOfLines = 2;
    [self.view addSubview:adjustTxt];

    // The reusable value-label width, layoutWidth - 80.
    const CGFloat valueWidth = layoutWidth + kValueWidthDelta;

    // The current-value read-out.
    valueTxt = [[UILabel alloc] initWithFrame:CGRectMake(20.0,
                                                         (CGFloat)(topOffset + 126),
                                                         valueWidth,
                                                         20.0)]; // fmov immediates 20.0.
    [self.view addSubview:valueTxt];

    // The "10" maximum marker on the right.
    maxTxt = [[UILabel alloc] initWithFrame:CGRectMake(layoutWidth + kMaxLabelXDelta -
                                                           25.0, // -25.0 is an fmov immediate.
                                                       (CGFloat)(topOffset + 146),
                                                       valueWidth,
                                                       kLabelHeight)];
    maxTxt.text = kMaxLabelText;
    maxTxt.textColor = UIColor.grayColor;
    [self.view addSubview:maxTxt];

    // The "-10" minimum marker on the left.
    minTxt = [[UILabel alloc]
        initWithFrame:CGRectMake(kSideInset, (CGFloat)(topOffset + 146), valueWidth, kLabelHeight)];
    minTxt.text = kMinLabelText;
    minTxt.textColor = UIColor.grayColor;
    [self.view addSubview:minTxt];

    // The offset slider.
    adjustSlider = [[UISlider alloc]
        initWithFrame:CGRectMake(kSideInset, (CGFloat)(topOffset + 180), valueWidth, kSideInset)];
    adjustSlider.minimumValue = kSliderMinimum;
    adjustSlider.maximumValue = kSliderMaximum;
    // The offset maps to the slider as delaySector * 4.0 / 10.0 (both fmov immediates).
    adjustSlider.value = (delaySector * 4.0f) / 10.0f;
    adjustSlider.continuous = YES;
    [adjustSlider addTarget:self
                     action:@selector(changeTiming:)
           forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:adjustSlider];

    [self refreshValue];

    @autoreleasepool {
        // The autorelease pool push at 0x174f6c wraps the preview construction.
        // Preview width: 540 on iPad, the main-screen width on iPhone.
        CGFloat previewLayoutWidth = kPadLayoutWidth;
        if (!isPad) {
            previewLayoutWidth = UIScreen.mainScreen.bounds.size.width;
        }
        const int previewSize = isPad ? kPadPreviewSize : kPhonePreviewSize;
        const int centerX = (int)((previewLayoutWidth - (CGFloat)previewSize) * 0.5); // fmov 0.5.
        const CGFloat previewY = (CGFloat)(topOffset + 260);

        // The rounded black container behind the preview square, sized to the background image.
        const CGRect bgFrame = bgImg.frame;
        UIView *previewContainer =
            [[UIView alloc] initWithFrame:CGRectMake(bgFrame.origin.x,
                                                     (CGFloat)(topOffset + 255),
                                                     bgFrame.size.width,
                                                     (CGFloat)(previewSize | 0xa))];
        previewContainer.backgroundColor = UIColor.blackColor;
        previewContainer.layer.masksToBounds = YES;
        previewContainer.layer.cornerRadius = 10.0; // fmov immediate 10.0.
        [self.view addSubview:previewContainer];

        // The decorative marker-title graphic, repositioned to the button origin.
        UIImageView *markerImageView =
            [[UIImageView alloc] initWithImage:LoadScaledPngImage(kMarkerTitleImageName)];
        const CGFloat buttonX = (CGFloat)((previewSize | 8) + centerX);
        [markerImageView setFrame:CGRectMake(buttonX,
                                             previewY,
                                             markerImageView.frame.size.width,
                                             markerImageView.frame.size.height)];
        [self.view addSubview:markerImageView];

        // The play/pause button, sized to its base graphic.
        UIImage *buttonBase = LoadScaledPngImage(kButtonBaseImageName);
        prevBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [prevBtn
            setFrame:CGRectMake(buttonX, previewY, buttonBase.size.width, buttonBase.size.height)];
        prevBtn.exclusiveTouch = YES;
        [prevBtn addTarget:self
                      action:@selector(switchPrev:)
            forControlEvents:UIControlEventTouchUpInside];
        [prevBtn setBackgroundImage:buttonBase forState:UIControlStateNormal];
        [prevBtn setImage:LoadScaledPngImage(kButtonPlayImageName) forState:UIControlStateNormal];
        [self.view addSubview:prevBtn];

        // Start paused.
        prevPause = YES;

        // The OpenGL preview square, centred horizontally.
        testView = [[AdjustTestView alloc] initWithFrame:CGRectMake((CGFloat)centerX,
                                                                    previewY,
                                                                    (CGFloat)previewSize,
                                                                    (CGFloat)previewSize)];
        NSString *markerID =
            [NSUserDefaults.standardUserDefaults objectForKey:kPrefCurrentMarkerIDKey];
        [testView loadMarkerTex:markerID];
        [self.view addSubview:testView];

        const float sector = [NSUserDefaults.standardUserDefaults floatForKey:kPrefAdjustSectorKey];
        [testView setAdjust:(int)sector];
    }
}

/**
 * @ghidraAddress 0x1754b8
 */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

/**
 * @ghidraAddress 0x1754f0
 */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

/**
 * @ghidraAddress 0x175528
 */
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
#ifdef ENABLE_PATCHES
    // Preservation patch, not in the binary. -startAnimation runs from -init and nothing ever
    // takes the link down again: -stopAnimation (0x1762a8) is dead code in the shipped binary --
    // its selector has 18 call sites and none is inside this class -- and neither
    // -viewWillDisappear: (0x175528), -viewDidDisappear: (0x1755b8) nor -dealloc (0x17596c)
    // touches it. Because CADisplayLink retains its target, the controller then outlives the pop
    // and keeps firing -loop: at 30 Hz on NSRunLoopCommonModes forever, driving -[AdjustTestView
    // draw] and its -presentRenderbuffer: into a CAEAGLLayer that UIKit is concurrently animating
    // and re-parenting. Take the link down before the transition starts instead.
    [self stopAnimation];
#endif
    [testView pausePreview];
    [NSUserDefaults.standardUserDefaults synchronize];
}

/**
 * @ghidraAddress 0x1755b8
 */
- (void)viewDidDisappear:(BOOL)animated {
    testView = nil;
    [NSNotificationCenter.defaultCenter removeObserver:self];
    [super viewDidDisappear:animated];
}

/**
 * @ghidraAddress 0x17596c
 */
- (void)dealloc {
    // The binary tears down only the preview view and the notification observers here; ARC inserts
    // the [super dealloc].
    testView = nil;
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

#pragma mark - Rotation

/**
 * @ghidraAddress 0x175658
 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Portrait (1) and portrait-upside-down (2) only.
    return (unsigned long long)(interfaceOrientation - 1) < 2;
}

/**
 * @ghidraAddress 0x175668
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    // 6 == portrait | portrait-upside-down.
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

/**
 * @ghidraAddress 0x175670
 */
- (BOOL)shouldAutorotate {
    return YES;
}

#pragma mark - Auto-calibration

/**
 * @ghidraAddress 0x175678
 */
- (void)tapAutoSetting:(id)sender {
    NSBundle *bundle = NSBundle.mainBundle;
    NSString *cancel = [bundle localizedStringForKey:kCancelKey value:@"" table:nil];
    NSString *ok = [bundle localizedStringForKey:kOKKey value:@"" table:nil];
    NSArray<NSString *> *otherButtons = @[ ok ];
    [AlertViewManager.sharedManager makeAlert:0
                                     delegate:self
                                          tag:0
                                        title:nil
                                          msg:kAutoSettingConfirmMessage
                                       cancel:cancel
                                      btnText:otherButtons
                                         show:YES
                               viewController:self];
}

/**
 * @ghidraAddress 0x17582c
 */
- (void)alertSelect:(NSDictionary *)info {
    if ([info[kBtnMessageKey] intValue] != 0) {
        NSString *ok = [NSBundle.mainBundle localizedStringForKey:kOKKey value:@"" table:nil];
        [AlertViewManager.sharedManager makeAlert:0
                                         delegate:nil
                                              tag:0
                                            title:nil
                                              msg:kAutoSettingDoneMessage
                                           cancel:ok
                                          btnText:nil
                                             show:YES
                                   viewController:self];
    }
}

#pragma mark - Slider

/**
 * @ghidraAddress 0x1759fc
 */
- (void)changeTiming:(id)sender {
    UISlider *slider = sender;
    // Snap the slider to the nearest integer (frinta), then map it to the offset.
    float snapped = roundf(slider.value);
    [slider setValue:snapped];
    snapped = slider.value;
    // fmov immediates 10.0 and 0.25: delaySector = value * 10 * 0.25.
    delaySector = snapped * 10.0f * 0.25f;
    [self refreshValue];
    [testView setAdjust:(int)(delaySector * 0.25f)];
    [NSUserDefaults.standardUserDefaults setFloat:delaySector forKey:kPrefAdjustSectorKey];
}

/**
 * @ghidraAddress 0x175b04
 */
- (void)refreshValue {
    float value = adjustSlider.value;
    // A zero slider reads as an exact 0; otherwise scale by 0.25 (fmov immediate).
    float magnitude = ((int)value == 0) ? 0.0f : (value * 0.25f);
    NSString *numberText = [NSString stringWithFormat:@"%.1f", (double)magnitude];
    // Use two decimals when the tenths digit is neither 0 nor 5.
    int tenths = (int)(magnitude * 10.0f) % 10;
    if (tenths != 0 && tenths != 5) {
        numberText = [NSString stringWithFormat:@"%.2f", (double)magnitude];
    }
    NSString *format = [NSBundle.mainBundle localizedStringForKey:kCurrentValueKey
                                                            value:@""
                                                            table:nil];
    valueTxt.text = [NSString stringWithFormat:format, numberText];
}

#pragma mark - Playback

/**
 * @ghidraAddress 0x175cb8
 */
- (void)switchPrev:(id)sender {
    BOOL wasPaused = prevPause;
    prevPause = !prevPause;
    // The icon reflects the previous state; the behaviour below follows the new state.
    UIImage *icon = LoadScaledPngImage(wasPaused ? kButtonPausedImageName : kButtonPlayImageName);
    [prevBtn setImage:icon forState:UIControlStateNormal];

    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    NSString *soundName;
    if (prevPause) {
        [testView pausePreview];
        [center removeObserver:self name:kFinishBgmNotificationName object:nil];
        soundName = [self soundName:kSoundSkip];
    } else {
        [testView startPreview];
        [center addObserver:self
                   selector:@selector(finishMusic:)
                       name:kFinishBgmNotificationName
                     object:nil];
        soundName = [self soundName:kSoundMusicSelect];
    }
    [AudioManager.sharedManager playSeResFile:soundName inDirectory:nil];
}

/**
 * @ghidraAddress 0x175ec0
 */
- (void)appSuspended:(NSNotification *)notification {
    [self pauseAnimation];
    if (prevPause) {
        return;
    }
    prevPause = YES;
    [prevBtn setImage:LoadScaledPngImage(kButtonPlayImageName) forState:UIControlStateNormal];
    [testView suspendPreview];
}

/**
 * @ghidraAddress 0x175f60
 */
- (void)appResume:(NSNotification *)notification {
    [testView resumePreview];
    [self resumeAnimation];
}

/**
 * @ghidraAddress 0x175fa0
 */
- (void)finishMusic:(NSNotification *)notification {
    prevPause = YES;
    [prevBtn setImage:LoadScaledPngImage(kButtonPlayImageName) forState:UIControlStateNormal];
    [testView pausePreview];
    [NSNotificationCenter.defaultCenter removeObserver:self
                                                  name:kFinishBgmNotificationName
                                                object:nil];
}

#pragma mark - Display link

/**
 * @ghidraAddress 0x17606c
 */
- (void)startAnimation {
    if (self.displayLink) {
        return;
    }
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(loop:)];
    self.displayLink.frameInterval = 2;
    [self.displayLink addToRunLoop:NSRunLoop.currentRunLoop forMode:NSRunLoopCommonModes];
}

/**
 * @ghidraAddress 0x1761a0
 */
- (void)pauseAnimation {
    if (self.displayLink) {
        self.displayLink.paused = YES;
    }
}

/**
 * @ghidraAddress 0x176224
 */
- (void)resumeAnimation {
    if (self.displayLink) {
        self.displayLink.paused = NO;
    }
}

/**
 * @ghidraAddress 0x1762a8
 */
- (void)stopAnimation {
    if (self.displayLink) {
        [self.displayLink invalidate];
        self.displayLink = nil;
    }
}

/**
 * @ghidraAddress 0x17633c
 */
- (void)loop:(CADisplayLink *)sender {
    [testView draw];
}

#pragma mark - Sound naming

/**
 * @ghidraAddress 0x176354
 */
- (NSString *)soundName:(NSString *)name {
    JubeatTheme theme = JubeatAppDelegate.appDelegate.currentTheme;
    if (theme == JubeatThemeRipples) {
        return [NSString stringWithFormat:kSoundNameRipplesFormat, name];
    }
    if (theme == JubeatThemeKnit) {
        return [NSString stringWithFormat:kSoundNameKnitFormat, name];
    }
    return [NSString stringWithFormat:kSoundNameDefaultFormat, name];
}

@end
