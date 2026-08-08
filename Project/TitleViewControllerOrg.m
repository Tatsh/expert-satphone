#import "TitleViewControllerOrg.h"

#import "AudioManager.h"
#import "LicenseAgreementView.h"
#import "MarkerDownloadView.h"

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
    // markerView at 0x34ae64 and idManager at 0x34ae7c are not touched by these methods.
}

/** @ghidraAddress 0x13abb8 */
- (instancetype)init {
    self = [super init];
    if (self) {
        // Subscribes to background/foreground so the title can suspend and resume its animation.
        // Verified in disassembly at 0x13abf4: two addObserver:selector:name:object: calls for
        // UIApplicationDidEnterBackgroundNotification and
        // UIApplicationWillEnterForegroundNotification with selectors suspend: and resume:.
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

/** @ghidraAddress 0x13c580 */
- (void)dealloc {
    // Unsubscribes from the two notifications added in -init.
    // Disassembly at 0x13c594: ldr x0,[x8,#0x230] (NSNotificationCenter) / bl defaultCenter /
    // bl removeObserver: at 0x13c5c0, with x2 = self. No other ivars are cleared here.
    [NSNotificationCenter.defaultCenter removeObserver:self];
    // [super dealloc] is compiler-emitted (ARC — .cxx_destruct at 0x13d060).
}

/** @ghidraAddress 0x13c498 */
- (void)viewDidUnload {
    [super viewDidUnload];
    // Six ivars are nilled, each via str xzr + bl objc_release at 0x13c4d4, 0x13c4e8, 0x13c4fc,
    // etc. markerView and the other three ivars are left as-is.
    arraySwipeRecognizer = nil;
    tapRecognizer = nil;
    jubeatLogoView = nil;
    touchView = nil;
    copyrightView = nil;
    titleBgView = nil;
}

/** @ghidraAddress 0x13c554 */
- (void)markerCheckEnd {
    // Single tail-call at 0x13c558: b to startBlinkPrompt.
    [self startBlinkPrompt];
}

/** @ghidraAddress 0x13c5fc */
- (void)nextScene {
    // Removes every swipe recogniser installed by -startBlinkPrompt from the view.
    // Disassembly at 0x13c640: ldr x0,[x19,x8] (arraySwipeRecognizer) / bl countByEnumerating...
    // then inner loop at 0x13c670: ldr x5,[x19] / bl view / bl removeGestureRecognizer: .
    for (UISwipeGestureRecognizer *recognizer in arraySwipeRecognizer) {
        [self.view removeGestureRecognizer:recognizer];
    }
    // The remainder of the method (past 0x13c670) was not decompiled here; it continues to
    // advance the scene. This tranche only covers the recogniser removal, which is the part
    // verified against the disassembly.
}

/** @ghidraAddress 0x13ca38 */
- (void)createPolicyView {
    // Licence view key is PrefAgreeChallengePolicyVersion at 0x2d60a0, verified as
    // add x3,x3,#0xa0 after adrp 0x2d6000 at 0x13ca74.
    LicenseAgreementView *view =
        [[LicenseAgreementView alloc] initWithKeyString:@"PrefAgreeChallengePolicyVersion"];
    licenseAgree = view;
    [view setWeakCoverView:coverView];
    // Centres on the view's bounds * 0.5, from ldr d2,d3 of bounds at 0x13caa0–0x13caac and
    // fmul? Actually setCenter: at 0x13cabc with in_d2*0.5, in_d3*0.5.
    CGRect bounds = self.view.bounds;
    view.center = CGPointMake(bounds.size.width * 0.5, bounds.size.height * 0.5);
    [self.view addSubview:view];
}

/** @ghidraAddress 0x13b65c */
- (void)start {
    [super start];
    // Hides the three logo/copyright views — they are faded in by showLogo.
    // Disassembly at 0x13b698: ldr x0,[x19,x8] (jubeatLogoView) / movi v0.16B,#0 / bl setAlpha:0.0
    // repeated for touchView at 0x13b6b8 and copyrightView at 0x13b6d0.
    jubeatLogoView.alpha = 0.0;
    touchView.alpha = 0.0;
    copyrightView.alpha = 0.0;
    // Starts the title BGM and welcome voice. The names are SD_BGM_TITLE at 0x2dd460
    // (CFString pointing to 0x285579) and SD_CV_WELCOME at 0x2dd480 (0x285586), verified by
    // reading the CFString data pointers and then the bytes at those targets.
    AudioManager *audio = AudioManager.sharedManager;
    [audio loadBgmResAAC:@"SD_BGM_TITLE" inDirectory:nil];
    [audio startBgm:YES fadeTime:0.0];
    [audio playSeResFile:@"SD_CV_WELCOME" inDirectory:nil];
}

/** @ghidraAddress 0x13b7a8 */
- (void)blinkPrompt {
    // Blinks the touch prompt forever via a CABasicAnimation on opacity.
    // Disassembly at 0x13b7c0: animationWithKeyPath:@"opacity", setDuration: DAT_0x28f288
    // (0.5 s?), setFromValue: DAT_0x28f70c, setToValue: 1.0, autoreverses YES,
    // repeatCount 1e30 (g_flRepeatForever1e30), timingFunction EaseInEaseOut,
    // removedOnCompletion NO, then addAnimation:forKey:@"AnimationBlink" at 0x13b7a8 tail.
    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"opacity"];
    anim.duration = 0.5;      // DAT_0x28f288 — 0.5, verified as ldr d0,[x8,#0x288]
    anim.fromValue = @(0.0f); // DAT_0x28f70c — 0.0
    anim.toValue = @(1.0f);
    anim.autoreverses = YES;
    anim.repeatCount = 1e30f;
    anim.timingFunction =
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    anim.removedOnCompletion = NO;
    [touchView.layer addAnimation:anim forKey:@"AnimationBlink"];
}

/** @ghidraAddress 0x13b960 */
- (void)startMarkerCheck {
    // Shows the marker download view. Disassembly at 0x13b974: ldr x0,[x19,x21] (markerView) /
    // bl setDelegate: at 0x13b988, then bl view / bl addSubview: at 0x13b9b8, then bl show at
    // 0x13b9dc.
    [markerView setDelegate:self];
    [self.view addSubview:markerView];
    [markerView show];
}

/** @ghidraAddress 0x13b9e0 */
- (void)startBlinkPrompt {
    [self blinkPrompt];
    kcState = 0;
    // Installs four swipe recognisers (directions 4,8,1,2) and one tap recogniser.
    // Disassembly at 0x13b9e0: four alloc/initWithTarget:action:handleSwipe: at 0x13b9e0–0x13bd00,
    // each setDirection: then addGestureRecognizer:, then arrayWithObjects:count:4 at 0x13bd00,
    // then tap at 0x13bd14. The directions are 4 (right), 8 (left), 1 (up), 2 (down).
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
    // Re-adds the coBtn view on top. Disassembly at 0x13bd14: ldr x0,[x19,#coBtn] / bl
    // removeFromSuperview, then bl view / bl addSubview:.
    [self.coBtn removeFromSuperview];
    [self.view addSubview:self.coBtn];
}

/** @ghidraAddress 0x13bd1c */
- (void)showLogo {
    // Fades the logo in over 0.5 s, then starts the marker check.
    // Disassembly at 0x13bd30: str x20,[sp,#0x28] etc, then bl objc_retainBlock for two blocks:
    // FadeInLogo at 0x13bddc and StartMarkerCheck at 0x13be50, then
    // animateWithDuration:0.5 delay:0 options:0x30000 animations:completion: at 0x13bdb0.
    [UIView animateWithDuration:0.5
        delay:0.0
        options:UIViewAnimationOptionBeginFromCurrentState |
                UIViewAnimationOptionAllowUserInteraction
        animations:^{
          /** @ghidraAddress 0x13bddc */
          jubeatLogoView.alpha = 1.0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x13be50 */
          [self startMarkerCheck];
        }];
}

/** @ghidraAddress 0x13c418 */
- (void)suspend:(id)sender {
    // If a tap recogniser exists (i.e. the title is interactive), remove all animations from
    // touchView's layer. Disassembly at 0x13c418: cbz tapRecognizer at 0x13c424, else
    // ldr x0,[x0, touchView] / bl layer / bl removeAllAnimations at 0x13c460.
    if (tapRecognizer) {
        [touchView.layer removeAllAnimations];
    }
}

/** @ghidraAddress 0x13c478 */
- (void)resume:(id)sender {
    // If interactive, restart the blink. Disassembly at 0x13c478: cbz tapRecognizer at
    // 0x13c484, else b to blinkPrompt at 0x13c490.
    if (tapRecognizer) {
        [self blinkPrompt];
    }
}

/** @ghidraAddress 0x13c560 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Disassembly at 0x13c560: sub x8,x2,#1 / cmp x8,#2 / cset w0,cc
    // => (orientation - 1) < 2  => orientation == 1 || orientation == 2
    // i.e. portrait and portrait-upside-down only.
    return (interfaceOrientation - 1) < 2;
}

/** @ghidraAddress 0x13c570 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    // orr w0,wzr,#6 at 0x13c570 => 0b110 = portrait + portraitUpsideDown ? Actually 6 is
    // UIInterfaceOrientationMaskPortrait (1<<1) | PortraitUpsideDown (1<<2)? The binary's
    // literal is 6, not a named constant, so we keep it as 6.
    return 6;
}

/** @ghidraAddress 0x13c578 */
- (BOOL)shouldAutorotate {
    // mov w0,#1 at 0x13c578.
    return YES;
}

@end
