#import "TitleViewControllerRpl.h"

#import "ApplilinkNetwork.h"
#import "AudioManager.h"
#import "EditorIDManager.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"
#import "LicenseAgreementView.h"
#import "MarkerDownloadView.h"
#import "RootViewController.h"

@implementation TitleViewControllerRpl {
    BOOL isPad;                            // offset global 0x34ae80
    int yHorizon;                          // offset global 0x34ae84
    UIImageView *jubeatLogoView;           // offset global 0x34ae88
    NSArray *arrayRippleLayer;             // offset global 0x34ae8c
    NSArray *arrayReflectedRippleLayer;    // offset global 0x34ae90
    UIImageView *touchView;                // offset global 0x34ae94
    UIImageView *copyrightView;            // offset global 0x34ae98
    MarkerDownloadView *markerView;        // offset global 0x34ae9c
    int kcState;                           // offset global 0x34aea0
    NSArray *arraySwipeRecognizer;         // offset global 0x34aea4
    UITapGestureRecognizer *tapRecognizer; // offset global 0x34aea8
    LicenseAgreementView *licenseAgree;    // offset global 0x34aeac
    UIView *coverView;                     // offset global 0x34aeb0
    EditorIDManager *idManager;            // offset global 0x34aeb4
}

// The title-screen resource names, from the __const CFStrings at 0x2dd5c0, 0x2dd5e0, 0x2dd600.
static NSString *const kLogoImageName = @"j_logo_rpl";
static NSString *const kTouchImageName = @"touch_rpl";
static NSString *const kCopyrightImageName = @"copyright_rpl";
// The title BGM and welcome voice, from the CFStrings at 0x2dd620 and 0x2dd640.
static NSString *const kTitleBgmName = @"SD_RPL_BGM_TITLE";
static NSString *const kWelcomeVoiceName = @"SD_RPL_CV_WELCOME";
// The confirm SE played when the title is dismissed (CFString 0x2dd260).
static NSString *const kConfirmSeName = @"SD_RPL_OK";

// The touch-prompt blink animations and their layer keys (CFStrings 0x2dd4a0, 0x2dd4e0). The slow
// blink runs while waiting; -nextScene swaps in a fast blink as it starts the game.
static NSString *const kOpacityKeyPath = @"opacity";
static NSString *const kBlinkAnimationKey = @"AnimationBlink";
static NSString *const kFastBlinkAnimationKey = @"AnimationBlinkFast";
static const CGFloat kBgmFadeOutTime = 1.5; // pooled double 0x3ff8000000000000
static const NSTimeInterval kFastBlinkDuration = 0.1;
static const float kFastBlinkMinOpacity = 0.1f;
static const float kFastBlinkRepeatCount = 10.0f;
// The SE played when the hidden Konami sequence completes (CFString 0x2dd4c0).
static NSString *const kKonamiRevealSeName = @"SD_GRA";

// The half-black cover dropped over the title as the start transition begins (alpha at 0x3fe0).
static const CGFloat kCoverViewAlpha = 0.5;

// The hidden Konami sequence's tap phase. Swipes advance kcState to 8; the two logo hot-spots then
// take it 8 -> 9 -> 10. A tap outside the armed states starts the title instead.
static const int kKonamiTapArmedState = 9;
static const int kKonamiTapFirstState = 8;
static const int kKonamiTapSecondState = 9;
static const int kKonamiCompleteState = 10;
// The two logo hot-spot rects, in jubeatLogoView coordinates, per idiom (pooled doubles 0x292ee0..
// 0x292f10, with the shared y at 0x28f6c8 == 35 on pad, 14 on phone).
static const CGFloat kKonamiRectYPad = 35.0;
static const CGFloat kKonamiRectYPhone = 14.0;
static const CGFloat kKonamiFirstSpotXPad = 189.0;
static const CGFloat kKonamiFirstSpotXPhone = 87.0;
static const CGFloat kKonamiFirstSpotWPad = 88.0;
static const CGFloat kKonamiFirstSpotWPhone = 44.0;
static const CGFloat kKonamiSpotHeightPad = 89.0;
static const CGFloat kKonamiSpotHeightPhone = 44.0;
static const CGFloat kKonamiSecondSpotXPad = 401.0;
static const CGFloat kKonamiSecondSpotXPhone = 188.0;

// The horizon sits at 70% of the view height (pooled double 0x291c98); the sky gradient fills above
// it and the reflection gradient below.
static const CGFloat kHorizonFraction = 0.7;
// The four greys of the two vertical gradients (pooled doubles 0x292eb8, 0x292ec0, 0x292ec8), all
// at full alpha. The sky runs from 0.86328125 white down to full white; the reflection from
// 0.58984375 to 0.8203125.
static const CGFloat kSkyGradientTopWhite = 0.86328125;
static const CGFloat kSkyGradientBottomWhite = 1.0;
static const CGFloat kReflectionGradientTopWhite = 0.58984375;
static const CGFloat kReflectionGradientBottomWhite = 0.8203125;

// The logo centres, as fractions of the view size (pooled doubles 0x28f248 and 0x292ed0) with the
// copyright inset from the bottom (0x28f1f8 phone, 0x28f210 pad).
static const CGFloat kLogoCenterYFraction = 0.3;
static const CGFloat kTouchCenterYFraction = 0.55;
static const CGFloat kCopyrightBottomInsetPhone = 40.0;
static const CGFloat kCopyrightBottomInsetPad = 120.0;

/** @ghidraAddress 0x13d140 */
- (instancetype)init {
    self = [super init];
    if (self) {
        // Rpl records isPad at construction, unlike Org which checks it each time.
        // Disassembly at 0x13d150: adrp 0x348080 / ldr x0 / bl isPad / strb w0,[x19, isPad]
        isPad = JubeatAppDelegate.appDelegate.isPad;
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(suspend:)
                                                   name:UIApplicationDidEnterBackgroundNotification
                                                 object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(resume:)
                                                   name:UIApplicationWillEnterForegroundNotification
                                                 object:nil];
    }
    return self;
}

/** @ghidraAddress 0x13ff9c */
- (void)dealloc {
    // Verified at 0x13ff9c: ldr x0,[x8,#0x230] / bl defaultCenter / bl removeObserver: / bl dealloc
    [NSNotificationCenter.defaultCenter removeObserver:self];
    // [super dealloc] is compiler-emitted (ARC — .cxx_destruct at 0x140a7c).
}

/** @ghidraAddress 0x13fea0 */
- (void)viewDidUnload {
    [super viewDidUnload];
    // Seven ivars are nilled, including the two ripple arrays that Org does not have.
    // Disassembly at 0x13fea0: seven str xzr + bl objc_release at 0x13fea0 tail, vs Org's six.
    arraySwipeRecognizer = nil;
    tapRecognizer = nil;
    arrayRippleLayer = nil;
    arrayReflectedRippleLayer = nil;
    jubeatLogoView = nil;
    touchView = nil;
    copyrightView = nil;
}

/** @ghidraAddress 0x13ff70 */
- (void)markerCheckEnd {
    [self startBlinkPrompt];
}

/** @ghidraAddress 0x140018 */
- (void)nextScene {
    // The start action: drop every gesture recogniser, play the confirm SE, fade the BGM out,
    // switch the touch prompt from its slow blink to a fast one, and hand off to the root
    // controller to leave the title.
    for (UISwipeGestureRecognizer *recognizer in arraySwipeRecognizer) {
        [self.view removeGestureRecognizer:recognizer];
    }
    [self.view removeGestureRecognizer:tapRecognizer];
    tapRecognizer = nil;

    [AudioManager.sharedManager playSeResFile:kConfirmSeName inDirectory:nil];
    [AudioManager.sharedManager fadeoutBgm:kBgmFadeOutTime];

    [touchView.layer removeAnimationForKey:kBlinkAnimationKey];
    touchView.alpha = 1.0;
    CABasicAnimation *fastBlink = [CABasicAnimation animationWithKeyPath:kOpacityKeyPath];
    fastBlink.duration = kFastBlinkDuration;
    fastBlink.fromValue = @(1.0f);
    fastBlink.toValue = @(kFastBlinkMinOpacity);
    fastBlink.autoreverses = YES;
    fastBlink.repeatCount = kFastBlinkRepeatCount;
    fastBlink.timingFunction =
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    fastBlink.removedOnCompletion = NO;
    [touchView.layer addAnimation:fastBlink forKey:kFastBlinkAnimationKey];

    [JubeatAppDelegate.appDelegate.rootViewCtrl endTitle];
}

/** @ghidraAddress 0x140454 */
- (void)createPolicyView {
    // Identical to Org: PrefAgreeChallengePolicyVersion at 0x2d60a0.
    LicenseAgreementView *view =
        [[LicenseAgreementView alloc] init:self keyString:@"PrefAgreeChallengePolicyVersion"];
    licenseAgree = view;
    [view setWeakCoverView:coverView];
    CGRect bounds = self.view.bounds;
    view.center = CGPointMake(bounds.size.width * 0.5, bounds.size.height * 0.5);
    [self.view addSubview:view];
}

/** @ghidraAddress 0x13d250 */
- (void)addRippleLayers {
    // Rpl-only: forty ripple sprites drift up the sky and forty mirrored copies drift down the
    // reflection below the horizon, each with a forever-repeating position.x/position.y pair. The
    // four source frames are title_rip_0..3 (0x13d2e0), picked at random per layer. The per-layer
    // random ranges, positions, and the two animations' from/to/duration/timeOffset values are
    // aliased in the decompile and must be transcribed from the disassembly at 0x13d250 before this
    // is filled in; leaving it a stub for now keeps the sky and reflection gradients (built in
    // -loadView) as the visible background rather than shipping a mis-derived animation.
}

/** @ghidraAddress 0x13e918 */
- (void)start {
    [super start];
    // The three logo views start invisible and are faded in by -showLogo; the ripple layers are
    // built here, after the base start, unlike Org which has none.
    jubeatLogoView.alpha = 0.0;
    touchView.alpha = 0.0;
    copyrightView.alpha = 0.0;
    [self addRippleLayers];
    AudioManager *audio = AudioManager.sharedManager;
    [audio loadBgmResAAC:kTitleBgmName inDirectory:nil];
    [audio startBgm:YES fadeTime:0.0];
    [audio playSeResFile:kWelcomeVoiceName inDirectory:nil];
}

/** @ghidraAddress 0x13ea74 */
- (void)blinkPrompt {
    // Identical to Org: CABasicAnimation on opacity with 0.5 s, 1e30 repeats.
    // Verified at 0x13ea74: animationWithKeyPath:@"opacity", setDuration:0x28f288, etc.
    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"opacity"];
    anim.duration = 0.5;
    anim.fromValue = @(0.0f);
    anim.toValue = @(1.0f);
    anim.autoreverses = YES;
    anim.repeatCount = 1e30f;
    anim.timingFunction =
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    anim.removedOnCompletion = NO;
    [touchView.layer addAnimation:anim forKey:@"AnimationBlink"];
}

/** @ghidraAddress 0x13ec2c */
- (void)startMarkerCheck {
    [markerView setDelegate:self];
    [self.view addSubview:markerView];
    [markerView show];
}

/** @ghidraAddress 0x13ecac */
- (void)startBlinkPrompt {
    [self blinkPrompt];
    kcState = 0;
    UISwipeGestureRecognizer *swipeRight =
        [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
    swipeRight.direction = UISwipeGestureRecognizerDirectionRight;
    [self.view addGestureRecognizer:swipeRight];
    UISwipeGestureRecognizer *swipeLeft =
        [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
    swipeLeft.direction = UISwipeGestureRecognizerDirectionLeft;
    [self.view addGestureRecognizer:swipeLeft];
    UISwipeGestureRecognizer *swipeUp =
        [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
    swipeUp.direction = UISwipeGestureRecognizerDirectionUp;
    [self.view addGestureRecognizer:swipeUp];
    UISwipeGestureRecognizer *swipeDown =
        [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
    swipeDown.direction = UISwipeGestureRecognizerDirectionDown;
    [self.view addGestureRecognizer:swipeDown];
    arraySwipeRecognizer = @[ swipeRight, swipeLeft, swipeUp, swipeDown ];
    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    tapRecognizer = tap;
    [self.view addGestureRecognizer:tap];
    [self->coBtn removeFromSuperview];
    [self.view addSubview:self->coBtn];
}

/** @ghidraAddress 0x13efe8 */
- (void)showLogo {
    [UIView animateWithDuration:0.5
        delay:0.0
        options:UIViewAnimationOptionBeginFromCurrentState |
                UIViewAnimationOptionAllowUserInteraction
        animations:^{
          /** @ghidraAddress 0x13f0a8 */
          jubeatLogoView.alpha = 1.0;
          copyrightView.alpha = 1.0;
        }
        completion:^(BOOL __attribute__((unused)) finished) {
          /** @ghidraAddress 0x13f11c */
          [self startMarkerCheck];
        }];
}

/** @ghidraAddress 0x13fa80 */
- (void)suspend:(id)sender {
    if (tapRecognizer) {
        [touchView.layer removeAllAnimations];
    }
}

/** @ghidraAddress 0x13fca4 */
- (void)resume:(id)sender {
    if (tapRecognizer) {
        [self blinkPrompt];
    }
}

/** @ghidraAddress 0x13ff7c */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (interfaceOrientation - 1) < 2;
}

/** @ghidraAddress 0x13ff8c */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return 6;
}

/** @ghidraAddress 0x13ff94 */
- (BOOL)shouldAutorotate {
    return YES;
}

#pragma mark - View lifecycle

/** @ghidraAddress 0x13e17c */
- (void)loadView {
    [super loadView];
    self.view.userInteractionEnabled = YES;
    self.view.multipleTouchEnabled = NO;
    self.view.opaque = YES;
    self.view.backgroundColor = UIColor.whiteColor;

    // The layout works off the frame, not the bounds: width in frame.size.width, height in
    // frame.size.height (the d2/d3 pair from -frame). The horizon is 70% of the height.
    CGRect frame = self.view.frame;
    CGFloat width = frame.size.width;
    CGFloat height = frame.size.height;
    yHorizon = (int)(height * kHorizonFraction);

    // The sky gradient fills from the top down to the horizon.
    CAGradientLayer *skyLayer = [[CAGradientLayer alloc] init];
    skyLayer.frame = CGRectMake(0.0, 0.0, width, yHorizon);
    skyLayer.colors = @[
        (__bridge id)[UIColor colorWithWhite:kSkyGradientTopWhite alpha:1.0].CGColor,
        (__bridge id)[UIColor colorWithWhite:kSkyGradientBottomWhite alpha:1.0].CGColor
    ];
    [self.view.layer addSublayer:skyLayer];

    // The reflection gradient fills from the horizon down to the bottom.
    CAGradientLayer *reflectionLayer = [[CAGradientLayer alloc] init];
    reflectionLayer.frame = CGRectMake(0.0, yHorizon, width, height - yHorizon);
    reflectionLayer.colors = @[
        (__bridge id)[UIColor colorWithWhite:kReflectionGradientTopWhite alpha:1.0].CGColor,
        (__bridge id)[UIColor colorWithWhite:kReflectionGradientBottomWhite alpha:1.0].CGColor
    ];
    [self.view.layer addSublayer:reflectionLayer];

    jubeatLogoView = [[UIImageView alloc] initWithImage:LoadScaledPngImage(kLogoImageName)];
    jubeatLogoView.center = CGPointMake((int)(width * 0.5), (int)(height * kLogoCenterYFraction));
    [self.view addSubview:jubeatLogoView];

    touchView = [[UIImageView alloc] initWithImage:LoadScaledPngImage(kTouchImageName)];
    touchView.center = CGPointMake((int)(width * 0.5), (int)(height * kTouchCenterYFraction));
    [self.view addSubview:touchView];

    copyrightView = [[UIImageView alloc] initWithImage:LoadScaledPngImage(kCopyrightImageName)];
    CGFloat copyrightInset =
        JubeatAppDelegate.appDelegate.isPad ? kCopyrightBottomInsetPad : kCopyrightBottomInsetPhone;
    copyrightView.center = CGPointMake((int)(width * 0.5), height - copyrightInset);
    [self.view addSubview:copyrightView];

    [self.view addSubview:self->coBtn];

    markerView = [[MarkerDownloadView alloc] init];
}

#pragma mark - Input

/** @ghidraAddress 0x13f13c */
- (void)handleTap:(UITapGestureRecognizer *)sender {
    // A tap either advances the hidden Konami sequence (tapping the two logo hot-spots after the
    // swipe run) or, on any other tap, begins the start flow. The two hot-spots are on the logo, in
    // per-idiom rects, and only matter while the swipe sequence has reached kcState 8/9.
    if (kcState <= kKonamiTapArmedState) {
        CGPoint loc = [sender locationOfTouch:0 inView:jubeatLogoView];
        CGFloat rectY = isPad ? kKonamiRectYPad : kKonamiRectYPhone;
        CGRect firstSpot = CGRectMake(isPad ? kKonamiFirstSpotXPad : kKonamiFirstSpotXPhone,
                                      rectY,
                                      isPad ? kKonamiFirstSpotWPad : kKonamiFirstSpotWPhone,
                                      isPad ? kKonamiSpotHeightPad : kKonamiSpotHeightPhone);
        if (CGRectContainsPoint(firstSpot, loc)) {
            if (kcState == kKonamiTapFirstState) {
                kcState = kKonamiTapSecondState;
                return;
            }
            [self startTitleTransition];
            return;
        }
        CGRect secondSpot = CGRectMake(isPad ? kKonamiSecondSpotXPad : kKonamiSecondSpotXPhone,
                                       rectY,
                                       isPad ? kKonamiSpotHeightPad : kKonamiSpotHeightPhone,
                                       isPad ? kKonamiSpotHeightPad : kKonamiSpotHeightPhone);
        if (!CGRectContainsPoint(secondSpot, loc) || kcState != kKonamiTapSecondState) {
            [self startTitleTransition];
            return;
        }
        // The sequence is complete: play the reveal SE and bounce the logo and every ripple layer.
        // This is the hidden cheat's own effect and does not leave the title.
        kcState = kKonamiCompleteState;
        [self playKonamiCompleteEffect];
        return;
    }
    [self startTitleTransition];
}

// The completed-Konami flourish, de-inlined from -handleTap: at 0x13f2a0: removes the swipe
// recognisers, plays SD_GRA, and runs a scale-bounce transform on the logo and on every ripple and
// reflected-ripple layer.
- (void)playKonamiCompleteEffect {
    for (UISwipeGestureRecognizer *recognizer in arraySwipeRecognizer) {
        [self.view removeGestureRecognizer:recognizer];
    }
    [AudioManager.sharedManager playSeResFile:kKonamiRevealSeName inDirectory:nil];
    // The scale-bounce transform applied to the logo and every ripple layer is a decorative cheat
    // effect; its animation is not reconstructed here and, unlike -nextScene, it does not leave the
    // title. The ripple-layer loops depend on -addRippleLayers, which is still a stub.
}

// The start flow shared by an ordinary tap and a completed Konami sequence, de-inlined from the
// tail of -handleTap: at 0x13f7bc: guarded by an existing licence view, it drops a half-black cover
// over the title and then either shows the challenge policy (when an editor identity already
// exists) or kicks off the editor-ID download.
- (void)startTitleTransition {
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

/** @ghidraAddress 0x13f990 */
- (void)handleSwipe:(UISwipeGestureRecognizer *)sender {
    // Identical to Org's Konami swipe state machine, verified at 0x13f990 via switch on
    // direction and ccmp for kcState.
    UISwipeGestureRecognizerDirection dir = sender.direction;
    int next = 0;
    switch (dir) {
    case UISwipeGestureRecognizerDirectionUp:
        next = (kcState == 5) ? 6 : 0;
        if (kcState == 7) {
            next = 8;
        }
        break;
    case UISwipeGestureRecognizerDirectionDown:
        next = (kcState == 6) ? 7 : 0;
        if (kcState == 4) {
            next = 5;
        }
        break;
    case UISwipeGestureRecognizerDirectionRight:
        next = (kcState == 1) ? 2 : 1;
        break;
    case UISwipeGestureRecognizerDirectionLeft:
        if ((kcState & ~1) == 2) {
            next = kcState + 1;
        }
        break;
    default:
        return;
    }
    kcState = next;
}

#pragma mark - Agreement and ID callbacks

/** @ghidraAddress 0x1405a0 */
- (void)agreementError:(id)agreement msgStr:(NSString *)msgStr {
    if ([NSUserDefaults.standardUserDefaults valueForKey:@"PrefAgreeChallengePolicyVersion"]) {
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

/** @ghidraAddress 0x140740 */
- (void)agreementSuccess:(id)agreement {
    [licenseAgree removeFromSuperview];
    licenseAgree = nil;
    [coverView removeFromSuperview];
    coverView = nil;
    [self nextScene];
}

/** @ghidraAddress 0x1407b8 */
- (void)agreementFailed:(id)agreement {
    [licenseAgree removeFromSuperview];
    licenseAgree = nil;
    [coverView removeFromSuperview];
    coverView = nil;
}

/** @ghidraAddress 0x140820 */
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

/** @ghidraAddress 0x1409c8 */
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
