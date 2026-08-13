#import "TitleViewControllerOrg.h"

#import "AlertViewManager.h"
#import "ApplilinkNetwork.h"
#import "AudioManager.h"
#import "EditorIDManager.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"
#import "LicenseAgreementView.h"
#import "MarkerDownloadView.h"
#import "RootViewController.h"

@implementation TitleViewControllerOrg {
    int kcState;                           // offset global 0x34ae68
    UIImageView *jubeatLogoView;           // offset global 0x34ae58
    UIImageView *titleBgView;              // offset global 0x34ae54
    UIImageView *touchView;                // offset global 0x34ae5c
    UIImageView *copyrightView;            // offset global 0x34ae60
    NSArray *arraySwipeRecognizer;         // offset global 0x34ae6c
    UITapGestureRecognizer *tapRecognizer; // offset global 0x34ae70
    LicenseAgreementView *licenseAgree;    // offset global 0x34ae74
    UIView *coverView;                     // offset global 0x34ae78
    MarkerDownloadView *markerView;        // offset global 0x34ae64
    EditorIDManager *idManager;            // offset global 0x34ae7c
}

// The title-screen resource names, from the __const CFStrings at 0x2dd420, 0x2dd440, and 0x2d4820.
static NSString *const kLogoImageName = @"j_logo";
static NSString *const kTouchImageName = @"touch";
static NSString *const kCopyrightImageName = @"copyright";

// The cube background: five JPEG frames named tit_cubes00..04, from the format string at 0x2dd3e0
// and the type at 0x2dd400, cycling a frame every 0.35 s (pooled double 0x292ea0).
static NSString *const kCubeImageNameFormat = @"tit_cubes%02d";
static NSString *const kCubeImageType = @"jpg";
// An enumeration rather than a static const, so the frame buffer is a fixed-size array with an
// initialiser, matching the five zeroed stack slots the binary fills from sp+0xa0.
enum { kCubeFrameCount = 5 };
static const NSTimeInterval kCubeAnimationDuration = 0.35;
// The cube view is inset vertically at both edges. The binary keeps the inset an integer and
// doubles it with a shift before converting (the csel of 0x50 and 0x32 at 0x13ae4c).
static const int kCubeInsetPad = 80;
static const int kCubeInsetPhone = 50;
// The two fade gradients over the cube view (pooled doubles 0x28f3f0 and 0x28f258).
static const CGFloat kGradientHeightPad = 100.0;
static const CGFloat kGradientHeightPhone = 60.0;
// The logo and prompt centres, as fractions of the view height. Both slots hold a float widened to
// a double — 0x291cb0 is 0x3fd6666660000000 and 0x28f230 is 0x3fe3333340000000 — so the literals
// carry the f suffix. 0x291cb0 is a different slot from kCubeAnimationDuration's 0x292ea0, even
// though both read 0.35.
static const CGFloat kLogoCenterYFraction = 0.35f;
static const CGFloat kTouchCenterYFraction = 0.6f;
// The copyright sits this far above the bottom edge: the pooled 50 at 0x28f2c8 on pad, the fmov
// immediate 30 at 0x13b524 on phone.
static const CGFloat kCopyrightBottomInsetPad = 50.0;
static const CGFloat kCopyrightBottomInsetPhone = 30.0;

// The logo and copyright fade in over 0.5 s (fmov immediate at 0x13bd9c).
static const NSTimeInterval kLogoFadeDuration = 0.5;

// The audio resource names, from the CFStrings at 0x2dd460, 0x2dd480, 0x2d7100, and 0x2dd4c0.
static NSString *const kTitleBgmName = @"SD_BGM_TITLE";
static NSString *const kWelcomeVoiceName = @"SD_CV_WELCOME";
static NSString *const kConfirmSeName = @"SD_OK";
static NSString *const kKonamiRevealSeName = @"SD_GRA";
// The BGM fades out over 1.5 s as the title is dismissed (fmov immediate at 0x13c7c0).
static const NSTimeInterval kBgmFadeOutTime = 1.5;

// The prompt blink and the fast blink that replaces it on the way out. The key path and the two
// layer keys are the CFStrings at 0x2d5da0, 0x2dd4a0, and 0x2dd4e0. Both animations dim to the
// same pooled float at 0x28f70c: the slow one runs 0.6 s a half-cycle (pooled double 0x28f288)
// forever (pooled float 0x28f3c4), the fast one 0.1 s (pooled double 0x28f290) ten times (fmov
// immediate at 0x13c900). The full-opacity end of each is an fmov immediate, so it stays a literal.
static NSString *const kOpacityKeyPath = @"opacity";
static NSString *const kBlinkAnimationKey = @"AnimationBlink";
static NSString *const kFastBlinkAnimationKey = @"AnimationBlinkFast";
static const CFTimeInterval kBlinkDuration = 0.6;
static const float kBlinkDimOpacity = 0.1f;
static const float kBlinkRepeatForever = 1e30f;
static const CFTimeInterval kFastBlinkDuration = 0.1;
static const float kFastBlinkRepeatCount = 10.0f;

// The hidden sequence: eight swipes walk kcState to 8, then the two logo hot-spots take it to 9
// and to 10. Past 10 the sequence is spent and every tap starts the game.
static const int kKonamiTapArmedState = 9;
static const int kKonamiTapFirstState = 8;
static const int kKonamiTapSecondState = 9;
static const int kKonamiCompleteState = 10;
// The two hot-spots, in the logo view's own coordinate space. Both are square and share a y, so
// only the x differs. The pad first-spot x and the phone second-spot x read the same pool slot,
// which is why one address appears twice.
static const CGFloat kKonamiFirstSpotXPad = 188.0;    // Pooled double 0x28f418.
static const CGFloat kKonamiFirstSpotXPhone = 87.0;   // Pooled double 0x291de8.
static const CGFloat kKonamiSecondSpotXPad = 399.0;   // Pooled double 0x292ea8.
static const CGFloat kKonamiSecondSpotXPhone = 188.0; // Pooled double 0x28f418.
static const CGFloat kKonamiSpotYPad = 34.0;          // Pooled double 0x28f648.
static const CGFloat kKonamiSpotYPhone = 14.0;        // fmov immediate at 0x13bf54.
static const CGFloat kKonamiSpotSidePad = 80.0;       // Pooled double 0x28f3f8.
static const CGFloat kKonamiSpotSidePhone = 44.0;     // Pooled double 0x291e30.
// Completing the sequence is its own reward: the cube background speeds up from 0.35 s a frame to
// 0.2 s (pooled double 0x28e040).
static const NSTimeInterval kKonamiCubeAnimationDuration = 0.2;

// The invisible cover dropped over the title while the licence sheet is up (fmov immediate at
// 0x13c1fc). It is added at alpha 0, so the licence view raises it.
static const CGFloat kCoverViewAlpha = 0.5;

// The challenge-policy defaults key, the CFString at 0x2d60a0.
static NSString *const kPrefAgreeChallengePolicyVersion = @"PrefAgreeChallengePolicyVersion";

/** @ghidraAddress 0x13abb8 */
- (instancetype)init {
    self = [super init];
    if (self) {
        // The binary sends -defaultCenter once and holds the result for both registrations.
        NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
        [center addObserver:self
                   selector:@selector(suspend:)
                       name:UIApplicationDidEnterBackgroundNotification
                     object:nil];
        [center addObserver:self
                   selector:@selector(resume:)
                       name:UIApplicationWillEnterForegroundNotification
                     object:nil];
    }
    return self;
}

/** @ghidraAddress 0x13c580 */
- (void)dealloc {
    // Unsubscribes from the two notifications added in -init. No other ivars are cleared here.
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

/** @ghidraAddress 0x13c498 */
- (void)viewDidUnload {
    [super viewDidUnload];
    // Six ivars are nilled, at 0x13c4d0 through 0x13c53c. The four object ivars left untouched are
    // markerView, licenseAgree, coverView, and idManager. This callback has not been invoked since
    // iOS 6, so in practice none of them is ever nilled today.
    arraySwipeRecognizer = nil;
    tapRecognizer = nil;
    jubeatLogoView = nil;
    touchView = nil;
    copyrightView = nil;
    titleBgView = nil;
}

/** @ghidraAddress 0x13c554 */
- (void)markerCheckEnd {
    // A tail-call to -startBlinkPrompt at 0x13c558. This is the only caller of -startBlinkPrompt in
    // the class, so the title is not tappable until the marker check resolves.
    [self startBlinkPrompt];
}

/** @ghidraAddress 0x13c5fc */
- (void)nextScene {
    // Leaves the title: drop every gesture recogniser, play the confirm sound, fade the BGM out,
    // swap the prompt's slow blink for a fast one, and hand off to the root controller. There is no
    // re-entry guard, so a second call would start a second fade; nilling tapRecognizer is what
    // prevents that in practice.
    for (UISwipeGestureRecognizer *recognizer in arraySwipeRecognizer) {
        [self.view removeGestureRecognizer:recognizer];
    }
    [self.view removeGestureRecognizer:tapRecognizer];
    // Only the tap recogniser is cleared; arraySwipeRecognizer keeps its detached recognisers.
    tapRecognizer = nil;

    // The binary re-fetches the shared manager for each message, at 0x13c770 and 0x13c7a8.
    [AudioManager.sharedManager playSeResFile:kConfirmSeName inDirectory:nil];
    [AudioManager.sharedManager fadeoutBgm:kBgmFadeOutTime];

    [touchView.layer removeAnimationForKey:kBlinkAnimationKey];
    touchView.alpha = 1.0;
    CABasicAnimation *fastBlink = [CABasicAnimation animationWithKeyPath:kOpacityKeyPath];
    fastBlink.duration = kFastBlinkDuration;
    fastBlink.fromValue = @(1.0f);
    fastBlink.toValue = @(kBlinkDimOpacity);
    fastBlink.autoreverses = YES;
    fastBlink.repeatCount = kFastBlinkRepeatCount;
    // The fast blink is linear, unlike the slow one in -blinkPrompt, which eases in and out.
    fastBlink.timingFunction =
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    fastBlink.removedOnCompletion = NO;
    [touchView.layer addAnimation:fastBlink forKey:kFastBlinkAnimationKey];

    // The transition itself. No controller is constructed here; the root controller fades into the
    // music-select screen.
    [JubeatAppDelegate.appDelegate.rootViewCtrl endTitle];
}

/** @ghidraAddress 0x13ca38 */
- (void)createPolicyView {
    // The freshly built view is stored straight into the licenseAgree ivar at 0x13ca90, releasing
    // the previous value; the binary keeps no local for it.
    licenseAgree = [[LicenseAgreementView alloc] init:self
                                            keyString:kPrefAgreeChallengePolicyVersion];
    // This coverView is the class's own ivar at +0x68, a distinct ivar from the superclass's.
    licenseAgree.weakCoverView = coverView;
    // The halving factor is the fmov immediate 0.5 at 0x13caec, and the binary re-reads the view's
    // bounds once per component (0x13cae8 and 0x13cb10).
    licenseAgree.center =
        CGPointMake(self.view.bounds.size.width * 0.5, self.view.bounds.size.height * 0.5);
    [self.view addSubview:licenseAgree];
}

/** @ghidraAddress 0x13b65c */
- (void)start {
    [super start];
    // Hidden here and faded in by -showLogo.
    jubeatLogoView.alpha = 0.0;
    touchView.alpha = 0.0;
    copyrightView.alpha = 0.0;
    // The binary sends -sharedManager three separate times rather than reusing one result, and
    // discards the result of -loadBgmResAAC:inDirectory: .
    (void)[AudioManager.sharedManager loadBgmResAAC:kTitleBgmName inDirectory:nil];
    [AudioManager.sharedManager startBgm:YES fadeTime:0.0];
    [AudioManager.sharedManager playSeResFile:kWelcomeVoiceName inDirectory:nil];
}

/** @ghidraAddress 0x13b7a8 */
- (void)blinkPrompt {
    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:kOpacityKeyPath];
    anim.duration = kBlinkDuration;
    anim.fromValue = @(kBlinkDimOpacity);
    anim.toValue = @(1.0f);
    anim.autoreverses = YES;
    anim.repeatCount = kBlinkRepeatForever;
    anim.timingFunction =
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    anim.removedOnCompletion = NO;
    [touchView.layer addAnimation:anim forKey:kBlinkAnimationKey];
}

/** @ghidraAddress 0x13b960 */
- (void)startMarkerCheck {
    markerView.delegate = self;
    [self.view addSubview:markerView];
    [markerView show];
}

/** @ghidraAddress 0x13b9e0 */
- (void)startBlinkPrompt {
    [self blinkPrompt];
    kcState = 0;
    // The recognisers are created in the order up, down, right, left, and the array keeps that
    // order: the +arrayWithObjects:count: at 0x13bbe8 reads the four stack slots written at sp+0x8,
    // +0x10, +0x18, and +0x20 with a count of exactly four. The binary sets no tap or touch counts,
    // no delegate, and neither cancelsTouchesInView nor delaysTouchesBegan.
    UISwipeGestureRecognizer *swipeUp =
        [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
    swipeUp.direction = UISwipeGestureRecognizerDirectionUp;
    [self.view addGestureRecognizer:swipeUp];
    UISwipeGestureRecognizer *swipeDown =
        [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
    swipeDown.direction = UISwipeGestureRecognizerDirectionDown;
    [self.view addGestureRecognizer:swipeDown];
    UISwipeGestureRecognizer *swipeRight =
        [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
    swipeRight.direction = UISwipeGestureRecognizerDirectionRight;
    [self.view addGestureRecognizer:swipeRight];
    UISwipeGestureRecognizer *swipeLeft =
        [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
    swipeLeft.direction = UISwipeGestureRecognizerDirectionLeft;
    [self.view addGestureRecognizer:swipeLeft];
    arraySwipeRecognizer = @[ swipeUp, swipeDown, swipeRight, swipeLeft ];

    tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                            action:@selector(handleTap:)];
    [self.view addGestureRecognizer:tapRecognizer];
    // The corporate button is re-parented so it stays above the newly installed recognisers. It is
    // the only thing that ever parents it: -[TitleViewController setCorporateButton] builds it but
    // never adds it to a superview.
    [self->coBtn removeFromSuperview];
    [self.view addSubview:self->coBtn];
}

/** @ghidraAddress 0x13bd1c */
- (void)showLogo {
    // Both blocks capture self strongly. The completion ignores its finished flag, so the marker
    // check runs even when the fade is cut short, and touchView is deliberately left hidden here.
    [UIView animateWithDuration:kLogoFadeDuration
        delay:0.0
        options:UIViewAnimationOptionCurveLinear
        animations:^{
          /** @ghidraAddress 0x13bddc */
          jubeatLogoView.alpha = 1.0;
          copyrightView.alpha = 1.0;
        }
        completion:^(BOOL __attribute__((unused)) finished) {
          /** @ghidraAddress 0x13be50 */
          [self startMarkerCheck];
        }];
}

/** @ghidraAddress 0x13c418 */
- (void)suspend:(id)sender {
    // If a tap recogniser exists the title is interactive, so the blink is taken down.
    if (tapRecognizer) {
        [touchView.layer removeAllAnimations];
    }
}

/** @ghidraAddress 0x13c478 */
- (void)resume:(id)sender {
    if (tapRecognizer) {
        [self blinkPrompt];
    }
}

/** @ghidraAddress 0x13c560 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // The whole body is sub x8,x2,#1 / cmp x8,#2 / cset w0,cc. The compare is unsigned, so
    // orientation 0 wraps and returns NO. UIKit has not called this since iOS 6; the rotation
    // policy now comes from -supportedInterfaceOrientations and -shouldAutorotate.
    return (NSUInteger)(interfaceOrientation - 1) < 2;
}

/** @ghidraAddress 0x13c570 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    // The binary returns the literal 6 via orr w0,wzr,#0x6.
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

/** @ghidraAddress 0x13c578 */
- (BOOL)shouldAutorotate {
    return YES;
}

#pragma mark - View lifecycle

/** @ghidraAddress 0x13ac88 */
- (void)loadView {
    [super loadView];
    self.view.userInteractionEnabled = YES;
    self.view.multipleTouchEnabled = NO;
    self.view.opaque = YES;
    self.view.backgroundColor = UIColor.blackColor;

    // The delegate is fetched once at 0x13adec, spilled, and reused by all three idiom tests.
    JubeatAppDelegate *appDelegate = JubeatAppDelegate.appDelegate;
    CGRect bounds = self.view.bounds;
    CGFloat width = bounds.size.width;
    CGFloat height = bounds.size.height;

    // The cube background spans the full width and is inset vertically at both edges. The binary
    // keeps the inset an integer and doubles it in integer before converting.
    const int cubeInset = appDelegate.isPad ? kCubeInsetPad : kCubeInsetPhone;
    titleBgView = [[UIImageView alloc]
        initWithFrame:CGRectMake(0.0, cubeInset, width, height - (cubeInset * 2))];
    titleBgView.contentMode = UIViewContentModeScaleAspectFill;
    UIImage *cubeImages[kCubeFrameCount] = {nil};
    for (int i = 0; i < kCubeFrameCount; ++i) {
        NSString *name = [NSString stringWithFormat:kCubeImageNameFormat, i];
        NSString *path = [NSBundle.mainBundle pathForResource:name ofType:kCubeImageType];
        cubeImages[i] = [UIImage imageWithContentsOfFile:path];
    }
    // The binary passes the raw five-slot array with no nil check, so a missing frame would raise.
    titleBgView.animationImages = [NSArray arrayWithObjects:cubeImages count:kCubeFrameCount];
    titleBgView.animationDuration = kCubeAnimationDuration;
    [titleBgView startAnimating];

    // The top gradient runs from opaque black at the top edge down to clear, and the bottom one is
    // its mirror. Neither sets locations or end points. The original built the opaque colour with
    // colorWithWhite:0 alpha:1.
    CGFloat gradientHeight = appDelegate.isPad ? kGradientHeightPad : kGradientHeightPhone;
    CAGradientLayer *topGradient = [[CAGradientLayer alloc] init];
    topGradient.frame = CGRectMake(0.0, 0.0, width, gradientHeight);
    topGradient.colors = @[
        (__bridge id)UIColor.blackColor.CGColor,
        (__bridge id)[UIColor colorWithWhite:0.0 alpha:0.0].CGColor
    ];
    [titleBgView.layer addSublayer:topGradient];
    // The bottom gradient takes both its y and its width from the cube view's own frame rather than
    // from the controller view's bounds; the binary sends -frame twice for them.
    CAGradientLayer *bottomGradient = [[CAGradientLayer alloc] init];
    bottomGradient.frame = CGRectMake(0.0,
                                      titleBgView.frame.size.height - gradientHeight,
                                      titleBgView.frame.size.width,
                                      gradientHeight);
    bottomGradient.colors = @[
        (__bridge id)[UIColor colorWithWhite:0.0 alpha:0.0].CGColor,
        (__bridge id)UIColor.blackColor.CGColor
    ];
    [titleBgView.layer addSublayer:bottomGradient];
    [self.view addSubview:titleBgView];

    // All three foreground views share one truncated half-width: the binary converts it with fcvtzs
    // once, into d9, and reuses that register for each -setCenter: call.
    CGFloat centerX = (int)(width * 0.5);
    jubeatLogoView = [[UIImageView alloc] initWithImage:LoadScaledPngImage(kLogoImageName)];
    jubeatLogoView.center = CGPointMake(centerX, (int)(height * kLogoCenterYFraction));
    [self.view addSubview:jubeatLogoView];

    touchView = [[UIImageView alloc] initWithImage:LoadScaledPngImage(kTouchImageName)];
    touchView.center = CGPointMake(centerX, (int)(height * kTouchCenterYFraction));
    [self.view addSubview:touchView];

    copyrightView = [[UIImageView alloc] initWithImage:LoadScaledPngImage(kCopyrightImageName)];
    CGFloat copyrightInset =
        appDelegate.isPad ? kCopyrightBottomInsetPad : kCopyrightBottomInsetPhone;
    // The copyright's y is not truncated, unlike the two views above it.
    copyrightView.center = CGPointMake(centerX, height - copyrightInset);
    [self.view addSubview:copyrightView];

    [self.view addSubview:self->coBtn];
    markerView = [[MarkerDownloadView alloc] init];
}

#pragma mark - Input

/** @ghidraAddress 0x13be70 */
- (void)handleTap:(UITapGestureRecognizer *)sender {
    // The two hidden hot-spots are live only until the sequence is spent. The gate at 0x13becc is
    // cmp #9 / b.gt, which skips the hot-spot tests rather than returning, so every other outcome —
    // including a hot-spot hit at the wrong step — falls through to the start flow below.
    if (kcState <= kKonamiTapArmedState) {
        // The idiom is resolved before the touch location, as in the binary.
        BOOL isPad = JubeatAppDelegate.appDelegate.isPad;
        // The location is taken in the logo's own coordinate space, so both rects are logo-local.
        CGPoint loc = [sender locationOfTouch:0 inView:jubeatLogoView];
        CGFloat spotY = isPad ? kKonamiSpotYPad : kKonamiSpotYPhone;
        CGFloat spotSide = isPad ? kKonamiSpotSidePad : kKonamiSpotSidePhone;
        CGRect firstSpot = CGRectMake(
            isPad ? kKonamiFirstSpotXPad : kKonamiFirstSpotXPhone, spotY, spotSide, spotSide);
        if (CGRectContainsPoint(firstSpot, loc)) {
            if (kcState == kKonamiTapFirstState) {
                kcState = kKonamiTapSecondState;
                return;
            }
        } else {
            CGRect secondSpot = CGRectMake(
                isPad ? kKonamiSecondSpotXPad : kKonamiSecondSpotXPhone, spotY, spotSide, spotSide);
            if (CGRectContainsPoint(secondSpot, loc) && kcState == kKonamiTapSecondState) {
                // The sequence is complete. The whole reward is that the swipe recognisers go away,
                // the reveal sound plays, and the cube background runs faster. The title is not
                // left: 0x13c148 branches to the epilogue, not to the start flow.
                kcState = kKonamiCompleteState;
                for (UISwipeGestureRecognizer *recognizer in arraySwipeRecognizer) {
                    [self.view removeGestureRecognizer:recognizer];
                }
                [AudioManager.sharedManager playSeResFile:kKonamiRevealSeName inDirectory:nil];
                [titleBgView stopAnimating];
                titleBgView.animationDuration = kKonamiCubeAnimationDuration;
                [titleBgView startAnimating];
                return;
            }
        }
    }
    // The start flow every ordinary tap takes, at 0x13c14c. Five sites branch here. It does not
    // advance the scene itself: it drops an invisible cover over the title and hands over to the
    // challenge-policy sheet or the editor-identifier download, either of which reaches -nextScene
    // through -agreementSuccess: or -agreementError:msgStr: .
    if (licenseAgree) {
        return;
    }
    coverView = [[UIView alloc] initWithFrame:self.view.bounds];
    coverView.opaque = NO;
    coverView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:kCoverViewAlpha];
    coverView.alpha = 0.0;
    [self.view addSubview:coverView];
    if (EditorIDManager.isExistEditorID) {
        [self createPolicyView];
    } else {
        idManager = [[EditorIDManager alloc] initWithDelegate:self];
    }
}

/** @ghidraAddress 0x13c328 */
- (void)handleSwipe:(UISwipeGestureRecognizer *)sender {
    // The hidden code is up, up, down, down, left, right, left, right, which walks kcState from 0
    // to 8; -handleTap: then carries it to 9 and 10 for the final two presses. A swipe out of
    // sequence restarts the code, except that up falls back to 1 rather than 0 because up is itself
    // the first step. The small values are sequence positions, not domain values. Any direction
    // other than these four leaves kcState untouched: the dispatch is bounded unsigned at 0x13c34c,
    // so direction 0 wraps and takes the default arm.
    int state;
    switch (sender.direction) {
    case UISwipeGestureRecognizerDirectionRight: {
        int stepSix = (kcState == 5) ? 6 : 0;
        state = (kcState == 7) ? 8 : stepSix;
        break;
    }
    case UISwipeGestureRecognizerDirectionLeft: {
        int stepSeven = (kcState == 6) ? 7 : 0;
        state = (kcState == 4) ? 5 : stepSeven;
        break;
    }
    case UISwipeGestureRecognizerDirectionUp:
        state = (kcState == 1) ? 2 : 1;
        break;
    case UISwipeGestureRecognizerDirectionDown:
        // The binary masks the low bit and compares with 2, which selects exactly 2 and 3.
        state = (kcState == 2 || kcState == 3) ? kcState + 1 : 0;
        break;
    default:
        return;
    }
    kcState = state;
}

#pragma mark - Agreement and ID callbacks

/** @ghidraAddress 0x13cb84 */
- (void)agreementError:(id)agreement msgStr:(NSString *)msgStr {
    // If the user already agreed, the title advances anyway.
    if ([NSUserDefaults.standardUserDefaults valueForKey:kPrefAgreeChallengePolicyVersion]) {
        [self nextScene];
        return;
    }
    // The msgStr argument is discarded: the alert always shows the fixed communication-error copy.
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:nil
                                            tag:0
                                          title:@"通信エラー"
                                            msg:@"サーバに接続できません。\nネットワーク接続をご確"
                                                @"認下さい。\n初期起動時のみ通信が必須となります。"
                                         cancel:[NSBundle.mainBundle localizedStringForKey:@"OK"
                                                                                     value:@""
                                                                                     table:nil]
                                        btnText:nil
                                           show:YES];
    [licenseAgree removeFromSuperview];
    licenseAgree = nil;
    [coverView removeFromSuperview];
    coverView = nil;
}

/** @ghidraAddress 0x13cd24 */
- (void)agreementSuccess:(id)agreement {
    [licenseAgree removeFromSuperview];
    licenseAgree = nil;
    [coverView removeFromSuperview];
    coverView = nil;
    [self nextScene];
}

/** @ghidraAddress 0x13cd9c */
- (void)agreementFailed:(id)agreement {
    [licenseAgree removeFromSuperview];
    licenseAgree = nil;
    [coverView removeFromSuperview];
    coverView = nil;
}

/** @ghidraAddress 0x13ce04 */
- (void)errorIDDownload:(id)download msgStr:(NSString *)msgStr {
    if (!msgStr || [msgStr isEqualToString:@""]) {
        msgStr = [NSBundle.mainBundle localizedStringForKey:@"NetworkErrorMsg" value:@"" table:nil];
    }
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:nil
                                            tag:0
                                          title:@""
                                            msg:msgStr
                                         cancel:[NSBundle.mainBundle localizedStringForKey:@"OK"
                                                                                     value:@""
                                                                                     table:nil]
                                        btnText:nil
                                           show:YES];
    idManager = nil;
}

/** @ghidraAddress 0x13cfac */
- (void)successIDDownload:(id)download {
    idManager = nil;
    NSString *key = [EditorIDManager getEditorIDKey];
    NSString *keyStr = [EditorIDManager getKeyString:key];
    if (keyStr) {
        [ApplilinkNetwork setUserId:keyStr];
    }
    [self createPolicyView];
}

@end
