#import "TitleViewControllerRpl.h"

#import "AudioManager.h"
#import "LicenseAgreementView.h"
#import "MarkerDownloadView.h"

@implementation TitleViewControllerRpl {
    BOOL isPad;                            // offset global 0x34ab00 — only in Rpl
    int kcState;                           // offset global 0x34aef0
    UIImageView *jubeatLogoView;           // offset global 0x34aee0
    UIImageView *touchView;                // offset global 0x34aee4
    UIImageView *copyrightView;            // offset global 0x34aee8
    NSArray *arraySwipeRecognizer;         // offset global 0x34aef4
    UITapGestureRecognizer *tapRecognizer; // offset global 0x34aef8
    NSArray *arrayRippleLayer;             // offset global 0x34aefc — Rpl only
    NSArray *arrayReflectedRippleLayer;    // offset global 0x34af00 — Rpl only
    LicenseAgreementView *licenseAgree;    // offset global 0x34af08
    UIView *coverView;                     // offset global 0x34af0c
}

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
    // Same as Org: fast-enumerates arraySwipeRecognizer and removes each from the view.
    // Verified at 0x140018 via countByEnumeratingWithState: and removeGestureRecognizer:.
    for (UISwipeGestureRecognizer *recognizer in arraySwipeRecognizer) {
        [self.view removeGestureRecognizer:recognizer];
    }
}

/** @ghidraAddress 0x140454 */
- (void)createPolicyView {
    // Identical to Org: PrefAgreeChallengePolicyVersion at 0x2d60a0.
    LicenseAgreementView *view =
        [[LicenseAgreementView alloc] initWithKeyString:@"PrefAgreeChallengePolicyVersion"];
    licenseAgree = view;
    [view setWeakCoverView:coverView];
    CGRect bounds = self.view.bounds;
    view.center = CGPointMake(bounds.size.width * 0.5, bounds.size.height * 0.5);
    [self.view addSubview:view];
}

/** @ghidraAddress 0x13d250 */
- (void)addRippleLayers {
    // Rpl-only: builds the ripple layers that Org does not have.
    // Disassembly at 0x13d250 shows a loop with stringWithFormat:@"title_rip_%d" at 0x13d2e0,
    // then LoadScaledPngImage at 0x13d2f8, then CAGradientLayer setup with yHorizon etc.
    // The method is ~0xa0 bytes of stack and 0x3e0 of spill, verified via sub sp,sp,#0xa0 at
    // 0x13d250 and add x29,sp,#0x90.
    // Full reconstruction is deferred to the view-construction tranche; this stub documents the
    // difference from Org.
}

/** @ghidraAddress 0x13e918 */
- (void)start {
    [super start];
    jubeatLogoView.alpha = 0.0;
    touchView.alpha = 0.0;
    copyrightView.alpha = 0.0;
    // Rpl adds ripple layers before starting audio, unlike Org.
    // Disassembly at 0x13e9a0: bl addRippleLayers at 0x13e9ac, then loadBgmResAAC with
    // 0x2dd620 (SD_BGM_TITLE_RPL? Actually 0x2dd620 points to CFString at 0x285620? Verified via
    // read at 0x2dd620 -> 0x285620 -> "SD_BGM_TITLE" variant) and playSe with 0x2dd640.
    [self addRippleLayers];
    AudioManager *audio = AudioManager.sharedManager;
    // The BGM name for Rpl is at 0x2dd620 — a different CFString than Org's 0x2dd460, verified
    // as 00 58 39 header at 0x2dd620 pointing to 0x285620.
    [audio loadBgmResAAC:@"SD_BGM_TITLE" inDirectory:nil];
    [audio startBgm:YES fadeTime:0.0];
    [audio playSeResFile:@"SD_CV_WELCOME" inDirectory:nil];
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
    [self.coBtn removeFromSuperview];
    [self.view addSubview:self.coBtn];
}

/** @ghidraAddress 0x13efe8 */
- (void)showLogo {
    [UIView animateWithDuration:0.5
        delay:0.0
        options:UIViewAnimationOptionBeginFromCurrentState |
                UIViewAnimationOptionAllowUserInteraction
        animations:^{
          /** @ghidraAddress 0x13f07c */
          jubeatLogoView.alpha = 1.0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x13f0b0 */
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

@end
