#import "NteTitleCoreController.h"

#import <CoreMotion/CoreMotion.h>

#import "AlertViewManager.h"
#import "ApplilinkNetwork.h"
#import "AudioManager.h"
#import "EAGLView.h"
#import "EditorIDManager.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"
#import "LicenseAgreementView.h"
#import "MarkerDownloadView.h"
#import "NteTitleOptionDropView.h"
#import "NteTitleOptionView.h"
#import "SePlayer.h"
#import "Texture2D.h"
#import "UpperBGKnit.h"

// The "repeat forever" animation repeat count, 1e30. A __const literal-pool float, not an exported
// global; the binary loads it inline.
static const float kRepeatForever1e30 = 1e30f;

// The reference width the non-iPad layout scale divides by, from the double at 0x10028f470.
static const CGFloat kTitleReferenceWidth = 320.0;

// The user-defaults key that records the accepted challenge-policy version. When it is absent the
// licence sheet (or the editor-ID provisioning that precedes it) is shown. String at 0x10027fa3f.
static NSString *const kPrefAgreeChallengePolicyVersionKey = @"PrefAgreeChallengePolicyVersion";

// The licence sheet's key string, passed to -[LicenseAgreementView init:keyString:]. Same string
// as the user-defaults key above; the CFString at 0x1002d60a0 points at 0x10027fa3f.
static NSString *const kLicenseKeyString = @"PrefAgreeChallengePolicyVersion";

// CoreAnimation key paths and keys.
static NSString *const kOpacityKeyPath = @"opacity";
static NSString *const kAnimationBlinkKey = @"AnimationBlink";
static NSString *const kAnimationBlinkFastKey = @"AnimationBlinkFast";
static NSString *const kTransitionAnimationID = @"TransitionAnimation";

// Localisation keys for the network-error alert (0x1002d6180 and 0x1002d4d80).
static NSString *const kNetworkErrorMsgKey = @"NetworkErrorMsg";
static NSString *const kOKKey = @"OK";

// Sound-effect and asset resource names, resolved from the CFString data pointers in the binary.
static NSString *const kSeHinabitaUnlock = @"SD_GRA";     // 0x1002dd4c0, tapped concierge unlock
static NSString *const kSeConfirm = @"SD_KNT_OK";         // 0x1002de720, next-scene confirm
static NSString *const kBgmTitle = @"SD_KNT_BGM_TITLE";   // 0x1002df440
static NSString *const kSeWelcome = @"SD_KNT_CV_WELCOME"; // 0x1002df460
static NSString *const kSeCar = @"SD_CAR";                // 0x1002e0f60, run-car flyby
static NSString *const kSeSasaName = @"SD_SASA";          // tap SE player resource base name
static NSString *const kSeSasaType = @"caf";
static NSString *const kTouchPromptImageName = @"touch_knt"; // 0x1002df360
static NSString *const kTitleAnime0Name = @"title_anime_0";  // 0x1002e0ee0, car ornament
static NSString *const kTitleAnime1Name = @"title_anime_1";  // 0x1002e0f00, smog ornament
static NSString *const kTitleLogoName = @"title_n_logo";     // 0x1002e0f20

// The background-page image name format: "<base>_1". Format string %@_1 at 0x100288c8b.
static NSString *const kBgImageNameFormat = @"%@_1";

// The concierge acceleration threshold that triggers a wave plug, pi/8 at the double 0x100293460.
static const double kWavePlugThreshold = M_PI_4 / 2.0; // 0.39269908...

// The concierge hit-test padding: the rect is inset by ten points and offset back by the logo
// view's origin (structural, from getConciergeRect at 0x1d03ac).
enum { kConciergeInset = 10 };

// The tap-count ceiling. tapCnt saturates at 255 (0xff).
enum { kTapCountMax = 255 };

// The Konami-code / Hinabita state-machine terminal values. The swipe/tap sequence walks kcState
// up through these; hnState mirrors it for the tap-driven confirm.
enum {
    kKcStateOptDrop = 10,    // Fully unlocked: taps now drop option ornaments.
    kKcStateHinabitaArm = 8, // The logo-tap arms the Hinabita confirm.
    kKcStateHinabitaGo = 9,  // The second tap in the correct region fires switchTitleEvent.
};

// The concierge shake-recovery frame count seeded on a wave tap (structural).
enum { kConciergeShakeUpFrames = 8 };

// The falling option-drop diameter per idiom, in points (from addOptionDrop at 0x1d04e4).
enum { kOptionDropSizePad = 0x96, kOptionDropSizePhone = 0x4b };

// The GL display link runs at half the screen refresh (frame interval 2).
enum { kDisplayLinkFrameInterval = 2 };

// The number of swipe recognisers installed (up, down, left, right).
enum { kSwipeRecognizerCount = 4 };

// The pulsing prompt-blink fast repeat count used by nextScene (fmov 0x41200000).
static const float kNextSceneBlinkRepeatCount = 10.0f;

@interface NteTitleCoreController () {
    // Device and orientation caches, all encoded B in the metadata.
    BOOL isPad;
    BOOL is4Inch;
    BOOL isWave;
    BOOL isPortrait;
    BOOL bEnableOptAnim;
    // The easter-egg state machine and animation counters, all encoded i.
    int kcState;
    int hnState;
    int conMoveFrame;
    int conShakeFrame;
    int conShakeUpFrame;
    int conStopFrame;
    int tapCnt;
    int tapMax;
    int currentPage;
    int nextPage;
    int conType;
    int unsealHeight;
    // The device idiom, encoded Q.
    NSUInteger deviceType;
    // Concierge geometry.
    CGPoint conciergePos;
    CGPoint oldConPos;
    CGSize conciergeSize;
    // The GL background bounds, from initWithNameArray:bounds:.
    CGRect bgBounds;
    // Accelerometer and layout scalars, all encoded f.
    float degOld;
    float degBak;
    float accelaOld;
    float phoneRate;
    // CoreMotion.
    CMMotionManager *motionManager;
    // Views and layers.
    UIImageView *jubeatLogoView;
    UIImageView *touchView;
    UIImageView *bgView;
    NSArray *arraySwipeRecognizer;
    NSMutableArray *texWaveAr;
    NSMutableArray *addOptionView;
    NSArray *fileNameArray;
    UITapGestureRecognizer *tapRecognizer;
    EAGLView *glView;
    UpperBGKnit *upperBgKnt;
    CADisplayLink *displayLink;
    Texture2D *conTex;
    UIImage *replaceImage;
    SePlayer *sePlayer;
    EditorIDManager *idManager;
    LicenseAgreementView *licenseAgree;
    UIView *coverView;
    MarkerDownloadView *markerView;
    NteTitleOptionView *optView;
}
@end

@implementation NteTitleCoreController

#pragma mark - Initialisation

/** @ghidraAddress 0x1ce434 */
- (void)setUnsealHeight:(int)unsealHeight_ {
    unsealHeight = unsealHeight_;
}

/** @ghidraAddress 0x1ce444 */
- (instancetype)initWithNameArray:(nullable NSArray<NSString *> *)nameArray bounds:(CGRect)bounds {
    self = [super init];
    if (self) {
        bgBounds = bounds;
        fileNameArray = [nameArray copy];

        JubeatAppDelegate *app = JubeatAppDelegate.appDelegate;
        isPad = app.isPad;
        deviceType = app.deviceType;
        is4Inch = app.is4inchAspect;
        tapCnt = 0;
        tapMax = 0;
        phoneRate = 1.0f;
        if (!isPad) {
            phoneRate = (float)(bounds.size.width / kTitleReferenceWidth);
        }

        // The EAGLView is built at the full main-screen bounds; its own initWithFrame: ignores the
        // passed frame and uses the screen, so the two mainScreen.bounds reads bracket the alloc.
        (void)UIScreen.mainScreen.bounds; // Yes, the binary reads and discards this.
        glView = [[EAGLView alloc] initWithFrame:UIScreen.mainScreen.bounds];
        glView.opaque = YES;
        glView.multipleTouchEnabled = YES;
        if (app.isPhoneRetina) {
            glView.contentScaleFactor = 2.0;
        }

        NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
        [center addObserver:self
                   selector:@selector(suspend:)
                       name:UIApplicationDidEnterBackgroundNotification
                     object:nil];
        [center addObserver:self
                   selector:@selector(resume:)
                       name:UIApplicationWillEnterForegroundNotification
                     object:nil];

        isWave = NO;
        upperBgKnt = [[UpperBGKnit alloc] init];
        if (!isPad) {
            // The non-iPad arm sizes the wave from the view's frame (read and discarded) and uses
            // the zero-rect overload with the smaller pulse height (20.0).
            (void)glView.frame; // Yes, the binary reads and discards this.
            (void)self.view.frame;
            [upperBgKnt initBg:CGRectZero waveBottom:0.0f waveTop:0.0f pulseHeight:0.0f isPad:NO];
        } else {
            // The iPad arm feeds the GL height (scaled by 0.48) as the wave-top, 768/1024 as the
            // wave bounds size, 60.0 as the pulse baseline, and 30.0 as the pulse height.
            (void)glView.frame; // Yes, the binary reads and discards this.
            [upperBgKnt initBg:CGRectMake(0.0, 0.0, 768.0, 1024.0) // 0x100292460, 0x10028e028
                    waveBottom:0.0f
                       waveTop:(float)(bgBounds.size.height * 0.47999999f) // 0x1002933d0
                   pulseHeight:60.0f                                       // 0x10028f8a0
                         isPad:YES]; // fmov s6 = 30.0 pulse; passed as isPad flag in the binary
        }

        isPortrait = YES;
        motionManager = [[CMMotionManager alloc] init];
        if (motionManager.isDeviceMotionAvailable) {
            degOld = 0.0f;
            motionManager.deviceMotionUpdateInterval = 0.13333334; // 0x100293450
            [motionManager startDeviceMotionUpdates];
            [motionManager startDeviceMotionUpdatesUsingReferenceFrame:
                               CMAttitudeReferenceFrameXTrueNorthZVertical];
            isPortrait = UIApplication.sharedApplication.statusBarOrientation !=
                         UIInterfaceOrientationLandscapeRight;
        }
        if (motionManager.isAccelerometerAvailable) {
            motionManager.accelerometerUpdateInterval = 0.13333334; // 0x100293450
            [motionManager startAccelerometerUpdates];
        }

        addOptionView = [[NSMutableArray alloc] init];
        sePlayer = nil;
    }
    return self;
}

#pragma mark - Background images

/** @ghidraAddress 0x1ce9f8 */
- (nullable UIImage *)getBgImage:(int)index {
    NSString *base = fileNameArray[(NSUInteger)index];
    NSString *name = [NSString stringWithFormat:kBgImageNameFormat, base];
    return LoadScaledEncryptedTexImage(name);
}

#pragma mark - Lifecycle

/** @ghidraAddress 0x1cea98 */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self becomeFirstResponder];
}

/** @ghidraAddress 0x1ceaec */
- (void)loadView {
    [super loadView];
    self.view.userInteractionEnabled = YES;
    self.view.multipleTouchEnabled = NO;
    self.view.opaque = YES;
    self.view.clipsToBounds = YES;
    self.view.backgroundColor = UIColor.whiteColor;
    [self.view addSubview:glView];
    (void)JubeatAppDelegate.appDelegate; // Yes, the binary fetches and discards this here.

    bgView = [[UIImageView alloc]
        initWithFrame:CGRectMake(0.0, 0.0, bgBounds.size.width, bgBounds.size.height)];
    bgView.contentMode = UIViewContentModeScaleToFill;
    bgView.image = [self getBgImage:0];
    [self.view addSubview:bgView];

    // The option ornament spans both artwork widths: it is placed left of x=0 by the combined
    // width and given a width of that combined width. Its height is the first artwork's width
    // (title_anime_0), truncated to an integer, matching the binary.
    CGSize anime0Size = LoadScaledEncryptedTexImage(kTitleAnime0Name).size;
    CGSize anime1Size = LoadScaledEncryptedTexImage(kTitleAnime1Name).size;
    int anime0Width = (int)(anime0Size.width + 0.0);
    int combinedWidth = (int)((double)anime0Width + anime1Size.width);
    optView = [[NteTitleOptionView alloc]
        initWithFrame:CGRectMake(
                          (double)-combinedWidth, 0.0, (double)combinedWidth, (double)anime0Width)];
    [self.view addSubview:optView];

    // The jubeat logo view is sized from the logo artwork scaled by phoneRate.
    UIImage *logoImage = LoadScaledEncryptedTexImage(kTitleLogoName);
    CGFloat logoWidth = logoImage.size.width * (double)phoneRate;
    CGFloat logoHeight = logoImage.size.height * (double)phoneRate;
    jubeatLogoView =
        [[UIImageView alloc] initWithFrame:CGRectMake(0.0, 0.0, logoWidth, logoHeight)];
    (void)jubeatLogoView.frame; // Yes, the binary reads and discards this.

    // The logo's vertical centre is idiom-dependent. deviceType 1 (the 3.5-inch phone) centres it
    // half its own frame height plus 10 points down; every other idiom uses a base offset (48 on
    // iPad, phoneRate*48 otherwise) plus half the logo height.
    CGFloat logoBaseOffset = 48.0; // 0x10028f450
    if (!isPad) {
        logoBaseOffset = (double)(phoneRate * 48.0f); // 0x10028f8f4
    }
    CGFloat halfBg = bgBounds.size.width * 0.5;
    CGFloat logoCenterY;
    if (JubeatAppDelegate.appDelegate.deviceType == 1) {
        CGFloat frameHeight = jubeatLogoView.frame.size.height;
        logoCenterY = (double)(float)(frameHeight * 0.5 + 10.0);
    } else {
        logoCenterY = (double)(float)(logoHeight * 0.5 + logoBaseOffset);
    }
    [jubeatLogoView setCenter:CGPointMake(halfBg, logoCenterY)];
    [self.view addSubview:jubeatLogoView];

    // The touch prompt is placed below the logo, offset by half the logo height plus its own frame.
    touchView = [[UIImageView alloc] initWithImage:LoadScaledPngImage(kTouchPromptImageName)];
    CGFloat logoFrameHeight = jubeatLogoView.frame.size.height;
    CGFloat touchFrameHeight = touchView.frame.size.height;
    [touchView setCenter:CGPointMake(halfBg,
                                     (double)(float)(logoCenterY + logoFrameHeight * 0.5 +
                                                     touchFrameHeight))];
    [self.view addSubview:touchView];

    [self.view addSubview:coBtn];

    // The marker view is translated up by unsealHeight so it sits above the unseal strip.
    markerView = [[MarkerDownloadView alloc] init];
    markerView.transform = CGAffineTransformMakeTranslation(0.0, (double)-unsealHeight);
    [self.view addSubview:markerView];
}

/** @ghidraAddress 0x1cf22c */
- (void)start {
    [super start];
    jubeatLogoView.alpha = 0.0;
    touchView.alpha = 0.0;

    AudioManager *audio = AudioManager.sharedManager;
    [audio loadBgmResAAC:kBgmTitle inDirectory:nil];
    [audio startBgm:YES fadeTime:0.0];
    [audio playSeResFile:kSeWelcome inDirectory:nil];

    if (displayLink == nil) {
        displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(loop:)];
        displayLink.frameInterval = kDisplayLinkFrameInterval;
        [displayLink addToRunLoop:NSRunLoop.currentRunLoop forMode:NSRunLoopCommonModes];
    }
}

#pragma mark - Run-car flyby

/** @ghidraAddress 0x1cf408 */
- (void)startRunCar {
    if (!bEnableOptAnim) {
        return;
    }
    kcState = kKcStateOptDrop;
    (void)UIScreen.mainScreen.bounds; // Yes, the binary reads and discards this.
    CGRect optFrame = optView.frame;
    int optWidth = (int)optFrame.size.width;

    // The horizontal start/end pair is {-optWidth, optWidth + screenWidth}; the vertical band pair
    // is {600,200} on iPad and {300,100} otherwise. A random bit selects which x is the start and
    // which vertical value each of the two laps uses.
    NSArray<NSNumber *> *xEnds =
        @[ @(-optWidth), @((int)(optFrame.size.width + (double)optWidth)) ];
    NSArray<NSNumber *> *yBand = @[ @(isPad ? 600 : 300), @(isPad ? 200 : 100) ];

    uint32_t r0 = arc4random();
    uint32_t startPick = r0 & 1;
    uint32_t yPick0 = arc4random() & 1;
    uint32_t yPick1 = arc4random() & 1;

    // The start x gets a +optWidth nudge only when the low bit is clear.
    int startNudge = (r0 & 1) ? 0 : optWidth;
    CGAffineTransform startXform =
        CGAffineTransformMakeTranslation((double)(xEnds[startPick].intValue + startNudge),
                                         (double)((float)yBand[yPick0].intValue * phoneRate));
    CGAffineTransform endXform =
        CGAffineTransformMakeTranslation((double)(xEnds[startPick ^ 1].intValue),
                                         (double)((float)yBand[yPick1].intValue * phoneRate));

    if (sePlayer == nil) {
        NSString *path = [NSBundle.mainBundle pathForResource:kSeSasaName ofType:kSeSasaType];
        sePlayer = [[SePlayer alloc] initWithPath:path];
    }
    [AudioManager.sharedManager playSeResFile:kSeCar inDirectory:nil];

    // The option direction mask: bit 1 set when the first vertical value is the larger, bit 2 set
    // when the second is the larger, ORed onto the start-pick low bit.
    uint32_t direction = startPick;
    if (yPick0 > yPick1) {
        direction |= 2;
    }
    if (yPick1 > yPick0) {
        direction |= 4;
    }
    [optView setOptDirection:(int)direction];

    optView.transform = startXform;
    __weak NteTitleOptionView *weakOpt = optView;
    [UIView animateWithDuration:4.0
        delay:0.0
        options:UIViewAnimationOptionCurveLinear
        animations:^{
          /** @ghidraAddress 0x1cfa1c */
          weakOpt.transform = endXform;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x1cfa90 */
          [self startRunCar];
        }];
}

#pragma mark - Display-link loop

/** @ghidraAddress 0x1cfab0 */
- (void)loop:(nullable CADisplayLink *)sender {
    [glView prepareToRender];
    if (motionManager.isAccelerometerAvailable) {
        CMAccelerometerData *data = motionManager.accelerometerData;
        if (motionManager.isDeviceMotionAvailable) {
            // The x-acceleration delta drives a wave plug when its magnitude exceeds pi/8, then the
            // last x acceleration is remembered. Each -acceleration send re-reads the live struct;
            // the binary reads .x on every one, so the delta and its sign use the same component.
            double delta = data.acceleration.x - (double)accelaOld;
            double magnitude = (data.acceleration.x - (double)accelaOld >= 0.0) ? delta : -delta;
            if (magnitude > kWavePlugThreshold) {
                double x = data.acceleration.x;
                double signedX = (x >= 0.0) ? x : -x;
                [upperBgKnt plugWave:(float)signedX];
                accelaOld = (float)data.acceleration.x;
            }
            (void)motionManager.deviceMotion.gravity; // Yes, the binary reads and discards this.
        }
    }
    [glView swapBuffer];
}

#pragma mark - Prompt and marker check

/** @ghidraAddress 0x1cfc54 */
- (void)blinkPrompt {
    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:kOpacityKeyPath];
    anim.duration = 0.6;      // 0x10028f288
    anim.fromValue = @(0.1f); // 0x10028f70c
    anim.toValue = @(1.0f);
    anim.autoreverses = YES;
    anim.repeatCount = kRepeatForever1e30;
    anim.timingFunction =
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    anim.removedOnCompletion = NO;
    [touchView.layer addAnimation:anim forKey:kAnimationBlinkKey];
}

/** @ghidraAddress 0x1cfe0c */
- (void)startMarkerCheck {
    markerView.delegate = self;
    markerView.parentView = self.view;
    [markerView show];
}

/** @ghidraAddress 0x1cfe94 */
- (void)startBlinkPrompt {
    [self blinkPrompt];
    kcState = 0;
    hnState = 0;

    UISwipeGestureRecognizerDirection directions[] = {UISwipeGestureRecognizerDirectionRight,
                                                      UISwipeGestureRecognizerDirectionLeft,
                                                      UISwipeGestureRecognizerDirectionUp,
                                                      UISwipeGestureRecognizerDirectionDown};
    UISwipeGestureRecognizer *swipes[kSwipeRecognizerCount];
    for (int i = 0; i < kSwipeRecognizerCount; ++i) {
        UISwipeGestureRecognizer *swipe =
            [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
        swipe.direction = directions[i];
        [self.view addGestureRecognizer:swipe];
        swipes[i] = swipe;
    }
    arraySwipeRecognizer = [NSArray arrayWithObjects:swipes count:kSwipeRecognizerCount];

    tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                            action:@selector(handleTap:)];
    [self.view addGestureRecognizer:tapRecognizer];

    // The explain and copyright buttons are re-parented onto this controller's view.
    [explainBtn removeFromSuperview];
    [self.view addSubview:explainBtn];
    [coBtn removeFromSuperview];
    [self.view addSubview:coBtn];
}

/** @ghidraAddress 0x1d0228 */
- (void)showLogo {
    __weak NteTitleCoreController *weakSelf = self;
    [UIView animateWithDuration:0.5
        delay:0.0
        options:UIViewAnimationOptionCurveLinear
        animations:^{
          /** @ghidraAddress 0x1d0334 */
          self->jubeatLogoView.alpha = 1.0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x1d0364 */
          [weakSelf startMarkerCheck];
        }];
}

#pragma mark - Hit geometry

/** @ghidraAddress 0x1d03ac */
- (CGRect)getConciergeRect {
    CGRect logoFrame = jubeatLogoView.frame;
    (void)jubeatLogoView.frame; // Yes, the binary reads the frame twice.
    CGRect rect;
    rect.origin.x = (double)((int)conciergePos.x - kConciergeInset) - logoFrame.origin.x;
    rect.origin.y = (double)((int)conciergePos.y - kConciergeInset) - logoFrame.origin.y;
    rect.size = conciergeSize;
    return rect;
}

/** @ghidraAddress 0x1d0444 */
- (CGRect)getOptViewRect {
    return optView.layer.presentationLayer.frame;
}

/** @ghidraAddress 0x1d04e4 */
- (void)addOptionDrop:(CGPoint)point {
    [sePlayer sePlay];
    int size = isPad ? kOptionDropSizePad : kOptionDropSizePhone;
    double topY = point.y - (double)(size >> 1);
    double side = (double)size;

    // Two drops: the first at the tap x, the second shifted left by half the size.
    NteTitleOptionDropView *dropA = [[NteTitleOptionDropView alloc]
        initWithMoveType:CGRectMake((double)(int)point.x, topY, side, side)
                    type:0];
    dropA.aDelegate = self;
    [self.view insertSubview:dropA belowSubview:optView];
    [addOptionView addObject:dropA];

    NteTitleOptionDropView *dropB = [[NteTitleOptionDropView alloc]
        initWithMoveType:CGRectMake((double)(int)(point.x - (double)(size >> 1)), topY, side, side)
                    type:1];
    dropB.aDelegate = self;
    [self.view insertSubview:dropB belowSubview:optView];
    [addOptionView addObject:dropB];
}

#pragma mark - Gestures

/** @ghidraAddress 0x1d06cc */
- (void)handleTap:(nullable UITapGestureRecognizer *)recognizer {
    if (!bEnableTap) {
        return;
    }
    int state = kcState;
    if (state <= kKcStateHinabitaGo) {
        (void)[recognizer locationOfTouch:0 inView:jubeatLogoView];
        // The two logo hit regions. The first (left) region: on iPad {189, 35, 89, 89}; otherwise
        // {phoneRate*87, phoneRate*14, phoneRate*44, phoneRate*44}. The second (right) region:
        // {401, 35, 89} on iPad; {phoneRate*188, phoneRate*14, phoneRate*44} otherwise.
        CGRect leftRegion;
        CGRect rightRegion;
        if (isPad) {
            // Left: x 189, y 35, w 88, h 89 (0x293cd0, 0x28f6c8, 0x292400, 0x293cc8).
            leftRegion = CGRectMake(189.0, 35.0, 88.0, 89.0);
            // Right: x 401, y 35, w 89, h 89 (0x293cd8, 0x28f6c8, 0x293cc8).
            rightRegion = CGRectMake(401.0, 35.0, 89.0, 89.0);
        } else {
            leftRegion = CGRectMake((double)(phoneRate * 87.0f),
                                    (double)(phoneRate * 14.0f),
                                    (double)(phoneRate * 44.0f),
                                    (double)(phoneRate * 44.0f));
            rightRegion = CGRectMake((double)(phoneRate * 188.0f),
                                     (double)(phoneRate * 14.0f),
                                     (double)(phoneRate * 44.0f),
                                     (double)(phoneRate * 44.0f));
        }
        CGPoint loc = [recognizer locationOfTouch:0 inView:jubeatLogoView];
        // Both region arms share a trailing "if the state just matched, return" (the binary's
        // joined_r0x1d097c). bWasArmed captures that per-arm match before startRunCar mutates it.
        if (CGRectContainsPoint(leftRegion, loc)) {
            BOOL bWasArmed = (kcState == kKcStateHinabitaArm);
            if (bWasArmed) {
                kcState = kKcStateHinabitaGo;
            }
            if (hnState == kKcStateHinabitaGo) {
                bEnableOptAnim = NO;
                JubeatAppDelegate.appDelegate.isHinabitaMode = YES;
                [JubeatAppDelegate.appDelegate switchTitleEvent];
                return;
            }
            if (bWasArmed) {
                return;
            }
        } else if (CGRectContainsPoint(rightRegion, loc)) {
            BOOL bWasGo = (kcState == kKcStateHinabitaGo);
            if (bWasGo) {
                [AudioManager.sharedManager playSeResFile:kSeHinabitaUnlock inDirectory:nil];
                bEnableOptAnim = YES;
                [self startRunCar];
            }
            if (hnState == kKcStateHinabitaArm) {
                hnState = kKcStateHinabitaGo;
                return;
            }
            if (bWasGo) {
                return;
            }
        }
        state = kcState;
    }

    if (state == kKcStateOptDrop) {
        CGPoint loc = [recognizer locationOfTouch:0 inView:self.view];
        if (CGRectContainsPoint([self getOptViewRect], loc)) {
            [self addOptionDrop:loc];
            return;
        }
    }

    if (isWave) {
        CGRect conRect = [self getConciergeRect];
        CGPoint loc = [recognizer locationOfTouch:0 inView:jubeatLogoView];
        if (CGRectContainsPoint(conRect, loc)) {
            [sePlayer sePlay];
            if (tapCnt < kTapCountMax) {
                ++tapCnt;
            } else {
                tapCnt = kTapCountMax;
            }
            if (tapMax < tapCnt) {
                tapMax = tapCnt;
            }
            // Ripple all four wave columns with a random rise height.
            for (int column = 0; column < 4; ++column) {
                [upperBgKnt riseUp:column riseColumn:(arc4random() & 3)];
            }
            if (conShakeUpFrame == 0) {
                conShakeUpFrame = kConciergeShakeUpFrames;
            }
            return;
        }
    }

    if (licenseAgree == nil) {
        id agreed =
            [NSUserDefaults.standardUserDefaults valueForKey:kPrefAgreeChallengePolicyVersionKey];
        if (agreed == nil) {
            coverView = [[UIView alloc] initWithFrame:self.view.bounds];
            coverView.opaque = NO;
            // The binary builds this with colorWithWhite:0.0 alpha:0.5; black at half alpha.
            coverView.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.5];
            coverView.alpha = 0.0;
            [self.view addSubview:coverView];
            if (!EditorIDManager.isExistEditorID) {
                idManager = [[EditorIDManager alloc] initWithDelegate:self];
                return;
            }
        }
        [self createPolicyView];
    }
}

/** @ghidraAddress 0x1d0d58 */
- (void)handleSwipe:(nullable UISwipeGestureRecognizer *)recognizer {
    // The four-direction code walks kcState/hnState in lock-step. Right/left advance the horizontal
    // legs (states 5-7), up/down the vertical legs (states 1-4).
    int next;
    switch (recognizer.direction) {
    case UISwipeGestureRecognizerDirectionUp: {
        int candidate = (kcState == 5) ? 6 : 0;
        next = (kcState == 7) ? 8 : candidate;
        break;
    }
    case UISwipeGestureRecognizerDirectionDown: {
        int candidate = (kcState == 6) ? 7 : 0;
        next = (kcState == 4) ? 5 : candidate;
        break;
    }
    case UISwipeGestureRecognizerDirectionRight:
        next = (kcState == 1) ? 2 : 1;
        break;
    case UISwipeGestureRecognizerDirectionLeft:
        next = ((unsigned int)kcState & 0xfffffffe) == 2 ? (unsigned int)kcState + 1 : 0;
        break;
    default:
        return;
    }
    kcState = next;
    hnState = next;
}

#pragma mark - Page-curl transition

/** @ghidraAddress 0x1d0e54 */
- (void)changeTitleBg:(int)index completed:(BOOL)completed {
    [UIApplication.sharedApplication beginIgnoringInteractionEvents];
    nextPage = index;
    [UIView beginAnimations:kTransitionAnimationID context:nil];
    [UIView setAnimationDelay:0.0];
    SEL didStop;
    if (completed) {
        [UIView setAnimationDuration:0.5];
        currentPage = index;
        didStop = @selector(curlAnimEnd);
    } else {
        [UIView setAnimationDuration:0.4]; // 0x10028f268
        didStop = @selector(needReverseEnd);
    }
    [UIView setAnimationDidStopSelector:didStop];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationTransition:UIViewAnimationTransitionCurlUp forView:bgView cache:YES];
    bgView.image = [self getBgImage:index];
    [UIView commitAnimations];
}

/** @ghidraAddress 0x1d0fd0 */
- (void)needReverseEnd {
    [UIView beginAnimations:kTransitionAnimationID context:nil];
    [UIView setAnimationDuration:0.1]; // 0x10028f290
    [UIView setAnimationDidStopSelector:@selector(curlAnimEnd)];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationTransition:UIViewAnimationTransitionCurlDown forView:bgView cache:YES];
    bgView.image = [self getBgImage:currentPage];
    [UIView commitAnimations];
}

/** @ghidraAddress 0x1d10d0 */
- (void)curlAnimEnd {
    [UIApplication.sharedApplication endIgnoringInteractionEvents];
}

#pragma mark - Suspend and resume

/** @ghidraAddress 0x1d1118 */
- (void)suspend:(nullable NSNotification *)notification {
    if (tapRecognizer != nil) {
        [touchView.layer removeAllAnimations];
    }
    if (displayLink != nil) {
        [displayLink invalidate];
        displayLink = nil;
    }
}

/** @ghidraAddress 0x1d11bc */
- (void)resume:(nullable NSNotification *)notification {
    if (tapRecognizer != nil) {
        [self blinkPrompt];
    }
    if (displayLink == nil) {
        displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(loop:)];
        displayLink.frameInterval = kDisplayLinkFrameInterval;
        [displayLink addToRunLoop:NSRunLoop.currentRunLoop forMode:NSRunLoopCommonModes];
    }
    if (motionManager.isDeviceMotionAvailable) {
        [motionManager startDeviceMotionUpdatesUsingReferenceFrame:
                           CMAttitudeReferenceFrameXTrueNorthZVertical];
    }
}

/** @ghidraAddress 0x1d12e8 */
- (void)stopAnimation {
    if (displayLink != nil) {
        [displayLink invalidate];
        displayLink = nil;
    }
    if (motionManager.isDeviceMotionAvailable) {
        [motionManager stopDeviceMotionUpdates];
    }
    [AudioManager.sharedManager stopAllSe];
}

/** @ghidraAddress 0x1d1388 */
- (void)viewDidUnload {
    [super viewDidUnload];
    [optView stopAnimation];
    [optView.layer removeAllAnimations];
    [optView removeFromSuperview];
    optView = nil;
    [bgView.layer removeAllAnimations];
    [bgView removeFromSuperview];
    bgView = nil;
    arraySwipeRecognizer = nil;
    tapRecognizer = nil;
    jubeatLogoView = nil;
    touchView = nil;
    if (texWaveAr != nil) {
        [texWaveAr removeAllObjects];
        texWaveAr = nil;
    }
    conTex = nil;
}

/** @ghidraAddress 0x1d1520 */
- (void)dropAnimEnd:(nullable NteTitleOptionDropView *)dropView {
    [dropView removeFromSuperview];
    [addOptionView removeObject:dropView];
}

/** @ghidraAddress 0x1d1580 */
- (void)markerCheckEnd {
    [self startBlinkPrompt];
}

#pragma mark - Rotation

/** @ghidraAddress 0x1d158c */
- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                duration:(NSTimeInterval)duration {
    isPortrait = YES;
    if (UIApplication.sharedApplication.statusBarOrientation !=
        UIInterfaceOrientationLandscapeRight) {
        isPortrait = NO;
    }
}

/** @ghidraAddress 0x1d1604 */
- (void)viewWillTransitionToSize:(CGSize)size
       withTransitionCoordinator:(nullable id<UIViewControllerTransitionCoordinator>)coordinator {
    isPortrait = YES;
    if (UIApplication.sharedApplication.statusBarOrientation !=
        UIInterfaceOrientationLandscapeRight) {
        isPortrait = NO;
    }
}

/** @ghidraAddress 0x1d167c */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (unsigned long)(interfaceOrientation - 1) < 2;
}

/** @ghidraAddress 0x1d168c */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscape;
}

/** @ghidraAddress 0x1d1694 */
- (BOOL)shouldAutorotate {
    return YES;
}

#pragma mark - Teardown

/** @ghidraAddress 0x1d169c */
- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
    if (optView != nil) {
        [optView stopAnimation];
        [optView removeFromSuperview];
        [optView.layer removeAllAnimations];
        optView = nil;
    }
    if (texWaveAr != nil) {
        [texWaveAr removeAllObjects];
    }
    if (motionManager.isDeviceMotionAvailable) {
        [motionManager startDeviceMotionUpdatesUsingReferenceFrame:
                           CMAttitudeReferenceFrameXTrueNorthZVertical];
    }
    if (sePlayer != nil) {
        [sePlayer terminate];
        sePlayer = nil;
    }
}

#pragma mark - Scene transition

/** @ghidraAddress 0x1d17fc */
- (void)nextScene {
    bEnableOptAnim = NO;
    for (UIGestureRecognizer *swipe in arraySwipeRecognizer) {
        [self.view removeGestureRecognizer:swipe];
    }
    [self.view removeGestureRecognizer:tapRecognizer];
    tapRecognizer = nil;

    [AudioManager.sharedManager playSeResFile:kSeConfirm inDirectory:nil];
    [AudioManager.sharedManager fadeoutBgm:1.5];

    [touchView.layer removeAnimationForKey:kAnimationBlinkKey];
    touchView.alpha = 1.0;

    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:kOpacityKeyPath];
    anim.duration = 0.1; // 0x10028f290
    anim.fromValue = @(1.0f);
    anim.toValue = @(0.1f); // 0x10028f70c
    anim.autoreverses = YES;
    anim.repeatCount = kNextSceneBlinkRepeatCount;
    anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    anim.removedOnCompletion = NO;
    [touchView.layer addAnimation:anim forKey:kAnimationBlinkFastKey];

    [JubeatAppDelegate.appDelegate.rootViewCtrl endTitle];
}

#pragma mark - Licence and editor-ID flow

/** @ghidraAddress 0x1d1c44 */
- (void)createPolicyView {
    licenseAgree = [[LicenseAgreementView alloc] init:self keyString:kLicenseKeyString];
    licenseAgree.alpha = 0.0;
    // The sheet is centred horizontally and shifted up by unsealHeight on iPad only.
    BOOL onPad = isPad;
    int unseal = unsealHeight;
    CGRect viewBounds = self.view.bounds;
    (void)self.view.bounds; // Yes, the binary reads bounds twice.
    CGFloat offset = onPad ? (double)(long)unseal : 0.0;
    [licenseAgree
        setCenter:CGPointMake(viewBounds.size.width * 0.5, viewBounds.size.height * 0.5 - offset)];
    [self.view addSubview:licenseAgree];

    __weak UIView *weakCover = coverView;
    __weak LicenseAgreementView *weakSheet = licenseAgree;
    [UIView animateWithDuration:0.2 // 0x10028e040
                     animations:^{
                       /** @ghidraAddress 0x1d1eb4 */
                       weakCover.alpha = 1.0;
                       weakSheet.alpha = 1.0;
                     }
                     completion:^(BOOL finished){
                         // The binary's completion here is the shared empty global block (invoke
                         // 0x1d1f88); it does nothing.
                         /** @ghidraAddress 0x1d1f88 */
                     }];
}

/** @ghidraAddress 0x1d1f8c */
- (void)agreementError:(nullable id)manager msgStr:(nullable NSString *)msgStr {
    if (msgStr == nil || [msgStr isEqualToString:@""]) {
        msgStr = [NSBundle.mainBundle localizedStringForKey:kNetworkErrorMsgKey
                                                      value:@""
                                                      table:nil];
    }
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:kOKKey value:@"" table:nil];
    [AlertViewManager.sharedManager makeAlert:0
                                     delegate:nil
                                          tag:0
                                        title:@""
                                          msg:msgStr
                                       cancel:ok
                                      btnText:nil
                                         show:YES];
    [licenseAgree removeFromSuperview];
    licenseAgree = nil;
    [coverView removeFromSuperview];
    coverView = nil;
}

/** @ghidraAddress 0x1d2168 */
- (void)agreementSuccess:(nullable id)sender {
    [licenseAgree removeFromSuperview];
    licenseAgree = nil;
    [coverView removeFromSuperview];
    coverView = nil;
    [self nextScene];
}

/** @ghidraAddress 0x1d21e0 */
- (void)agreementFailed:(nullable id)sender {
    [licenseAgree removeFromSuperview];
    licenseAgree = nil;
    [coverView removeFromSuperview];
    coverView = nil;
}

/** @ghidraAddress 0x1d2248 */
- (void)errorIDDownload:(nullable id)manager msgStr:(nullable NSString *)msgStr {
    if (msgStr == nil || [msgStr isEqualToString:@""]) {
        msgStr = [NSBundle.mainBundle localizedStringForKey:kNetworkErrorMsgKey
                                                      value:@""
                                                      table:nil];
    }
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:kOKKey value:@"" table:nil];
    [AlertViewManager.sharedManager makeAlert:0
                                     delegate:nil
                                          tag:0
                                        title:@""
                                          msg:msgStr
                                       cancel:ok
                                      btnText:nil
                                         show:YES];
    idManager = nil;
}

/** @ghidraAddress 0x1d23f0 */
- (void)successIDDownload:(nullable id)manager {
    idManager = nil;
    NSString *editorId = [EditorIDManager getKeyString:EditorIDManager.getEditorIDKey];
    if (editorId != nil) {
        [ApplilinkNetwork setUserId:editorId];
    }
    [self createPolicyView];
}

#pragma mark - Motion (shake) events

/** @ghidraAddress 0x1d24a4 */
- (BOOL)checkShakeEvent:(nullable UIEvent *)event {
    return event.type == UIEventTypeMotion && event.subtype == UIEventSubtypeMotionShake;
}

/** @ghidraAddress 0x1d250c */
- (BOOL)canBecomeFirstResponder {
    return YES;
}

/** @ghidraAddress 0x1d2514 */
- (void)motionBegan:(UIEventSubtype)motion withEvent:(nullable UIEvent *)event {
    [self checkShakeEvent:event];
}

/** @ghidraAddress 0x1d2524 */
- (void)motionCancelled:(UIEventSubtype)motion withEvent:(nullable UIEvent *)event {
    [self checkShakeEvent:event];
}

/** @ghidraAddress 0x1d2534 */
- (void)motionEnded:(UIEventSubtype)motion withEvent:(nullable UIEvent *)event {
    if ([self checkShakeEvent:event]) {
        [sePlayer sePlay];
    }
}

@end
