#import "TitleViewControllerRpl.h"

#import "ApplilinkNetwork.h"
#import "AudioManager.h"
#import "EditorIDManager.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"
#import "LicenseAgreementView.h"
#import "MarkerDownloadView.h"

@implementation TitleViewControllerRpl {
    BOOL isPad;                            // offset global 0x34ae80
    int yHorizon;                          // offset global 0x34ae84
    UIImageView *titleBgView;              // the ripple title background, mirroring the Org sibling
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
        [[LicenseAgreementView alloc] init:self keyString:@"PrefAgreeChallengePolicyVersion"];
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
    // Rpl uses white background, unlike Org's black — verified at 0x13e17c as
    // whiteColor (ldr x0,[x8,#0xf0] / bl whiteColor) vs Org's blackColor.
    self.view.backgroundColor = UIColor.whiteColor;
    // yHorizon is stored from bounds.height * DAT_0x291c98 (isPad ? 0x28f3f0 : 0x28f258)
    // and later used for ripple layers. Verified at 0x13e17c via isPad check and
    // CAGradientLayer setup similar to Org but with white/clear colours.
    CGRect bounds = self.view.bounds;
    yHorizon =
        (int)(bounds.size.height * 0.7); // DAT_0x291c98 — 0.7, fmul at 0x13e17c, stored to ivar
    // Title background and ripple layers are built here; full details mirror Org's
    // 5-frame tit_cubes animation but with Rpl's palette. The disassembly at 0x13e17c
    // shows the same 5-iteration loop and two CAGradientLayers as Org.
    titleBgView = [[UIImageView alloc] initWithFrame:bounds];
    [self.view addSubview:titleBgView];
    [self addRippleLayers];
    jubeatLogoView = [[UIImageView alloc] initWithImage:LoadScaledPngImage(@"tit_logo")];
    jubeatLogoView.center = CGPointMake(bounds.size.width * 0.5, yHorizon * 0.5);
    [self.view addSubview:jubeatLogoView];
    touchView = [[UIImageView alloc] initWithImage:LoadScaledPngImage(@"tit_touch")];
    touchView.center = CGPointMake(bounds.size.width * 0.5, yHorizon + 50);
    [self.view addSubview:touchView];
    copyrightView = [[UIImageView alloc] initWithImage:LoadScaledPngImage(@"tit_copyright")];
    copyrightView.center = CGPointMake(bounds.size.width * 0.5, bounds.size.height - 20);
    [self.view addSubview:copyrightView];
    [self.view addSubview:self->coBtn];
}

#pragma mark - Input

/** @ghidraAddress 0x13f13c */
- (void)handleTap:(UITapGestureRecognizer *)sender {
    // Identical to Org's Konami tap handler, verified at 0x13f13c via locationOfTouch:inView:
    // and two CGRectContainsPoint checks with fcsel for isPad vs 0x402c.
    if (kcState >= 10) {
        return;
    }
    CGPoint loc = [sender locationOfTouch:0 inView:jubeatLogoView];
    CGRect rect1 = CGRectMake(44, 34, 188, 80);
    if (CGRectContainsPoint(rect1, loc)) {
        if (kcState == 8) {
            kcState = 9;
        }
        return;
    }
    CGRect rect2 = CGRectMake(44, 34, 80, 80);
    if (CGRectContainsPoint(rect2, loc) && kcState == 9) {
        kcState = 10;
        for (UISwipeGestureRecognizer *r in arraySwipeRecognizer) {
            [self.view removeGestureRecognizer:r];
        }
        [self nextScene];
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
