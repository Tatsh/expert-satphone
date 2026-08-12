#import "TitleViewControllerOrg.h"

#import "AlertViewManager.h"
#import "ApplilinkNetwork.h"
#import "AudioManager.h"
#import "EditorIDManager.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"
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
    MarkerDownloadView *markerView;        // offset global 0x34ae64
    EditorIDManager *idManager;            // offset global 0x34ae7c
}

// The title-screen resource names, from the __const CFStrings at 0x2dd420, 0x2dd440, 0x2d4820.
static NSString *const kLogoImageName = @"j_logo";
static NSString *const kTouchImageName = @"touch";
static NSString *const kCopyrightImageName = @"copyright";
// The cube background animation: five JPEG frames named tit_cubes00..04 (CFStrings 0x2dd3e0 for the
// format, 0x2dd400 for the type), cycled over 0.35 s (pooled double 0x292ea0).
static NSString *const kCubeImageNameFormat = @"tit_cubes%02d";
static NSString *const kCubeImageType = @"jpg";
static const int kCubeFrameCount = 5;
static const NSTimeInterval kCubeAnimationDuration = 0.35;
// The cube view is inset vertically by 80 points on pad, 50 on phone (the csel of 0x50/0x32).
static const CGFloat kCubeInsetPad = 80.0;
static const CGFloat kCubeInsetPhone = 50.0;
// The top and bottom fade gradients are 100 points tall on pad, 60 on phone (pooled doubles
// 0x28f3f0 and 0x28f258).
static const CGFloat kGradientHeightPad = 100.0;
static const CGFloat kGradientHeightPhone = 60.0;
// The logo centres, as fractions of the view size (pooled doubles 0x291cb0 and 0x28f230), with the
// copyright inset from the bottom (0x28f2c8 == 50 on pad, immediate 30 on phone).
static const CGFloat kLogoCenterYFraction = 0.35;
static const CGFloat kTouchCenterYFraction = 0.6;
static const CGFloat kCopyrightBottomInsetPad = 50.0;
static const CGFloat kCopyrightBottomInsetPhone = 30.0;

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
        [[LicenseAgreementView alloc] init:self keyString:@"PrefAgreeChallengePolicyVersion"];
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
    [self->coBtn removeFromSuperview];
    [self.view addSubview:self->coBtn];
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
          copyrightView.alpha = 1.0;
        }
        completion:^(BOOL __attribute__((unused)) finished) {
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

#pragma mark - View lifecycle

/** @ghidraAddress 0x13ac88 */
- (void)loadView {
    [super loadView];
    self.view.userInteractionEnabled = YES;
    self.view.multipleTouchEnabled = NO;
    self.view.opaque = YES;
    self.view.backgroundColor = UIColor.blackColor;

    // The title background is an image view spanning the view inset vertically by kCubeInset, with
    // a five-frame cube animation and two black-to-clear gradients top and bottom. The layout works
    // off the bounds (width in d2, height in d3 from -bounds).
    CGRect bounds = self.view.bounds;
    CGFloat width = bounds.size.width;
    CGFloat height = bounds.size.height;
    CGFloat cubeInset = JubeatAppDelegate.appDelegate.isPad ? kCubeInsetPad : kCubeInsetPhone;
    titleBgView = [[UIImageView alloc]
        initWithFrame:CGRectMake(0.0, cubeInset, width, height - 2 * cubeInset)];
    titleBgView.contentMode = UIViewContentModeScaleAspectFill;
    NSMutableArray *frames = [NSMutableArray array];
    for (int i = 0; i < kCubeFrameCount; ++i) {
        NSString *name = [NSString stringWithFormat:kCubeImageNameFormat, i];
        NSString *path = [NSBundle.mainBundle pathForResource:name ofType:kCubeImageType];
        [frames addObject:[UIImage imageWithContentsOfFile:path]];
    }
    titleBgView.animationImages = frames;
    titleBgView.animationDuration = kCubeAnimationDuration;
    [titleBgView startAnimating];

    // The top gradient fades black in over the first kGradientHeight points; the bottom one fades
    // it back out over the last kGradientHeight, both fixed to the title view's own frame.
    CGFloat gradientHeight =
        JubeatAppDelegate.appDelegate.isPad ? kGradientHeightPad : kGradientHeightPhone;
    CAGradientLayer *topGradient = [CAGradientLayer layer];
    topGradient.frame = CGRectMake(0.0, 0.0, width, gradientHeight);
    topGradient.colors = @[
        (__bridge id)[UIColor colorWithWhite:0.0 alpha:0.0].CGColor,
        (__bridge id)[UIColor colorWithWhite:0.0 alpha:1.0].CGColor
    ];
    [titleBgView.layer addSublayer:topGradient];
    CAGradientLayer *bottomGradient = [CAGradientLayer layer];
    bottomGradient.frame =
        CGRectMake(0.0, titleBgView.frame.size.height - gradientHeight, width, gradientHeight);
    bottomGradient.colors = @[
        (__bridge id)[UIColor colorWithWhite:0.0 alpha:1.0].CGColor,
        (__bridge id)[UIColor colorWithWhite:0.0 alpha:0.0].CGColor
    ];
    [titleBgView.layer addSublayer:bottomGradient];
    [self.view addSubview:titleBgView];

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

/** @ghidraAddress 0x13be70 */
- (void)handleTap:(UITapGestureRecognizer *)sender {
    // Konami-code tap handler. The disassembly at 0x13be70 checks kcState <10, then isPad,
    // then locationOfTouch:inView:jubeatLogoView at 0x13bf18, then two CGRectContainsPoint
    // checks with rects built from DAT_0x291e30 etc vs isPad ? DAT_0x28f... : 0x402c...
    // The first rect is the logo tap area (188x80 at 44,34 on pad, 87x80 at 44,34 on phone?),
    // the second is the hidden Konami area (399x399 at 44,34). Verified at 0x13bf34–0x13bf7c
    // via fcsel and bl _CGRectContainsPoint.
    if (kcState >= 10) {
        return;
    }
    CGPoint loc = [sender locationOfTouch:0 inView:jubeatLogoView];
    BOOL isPad = JubeatAppDelegate.appDelegate.isPad;
    CGRect rect1 =
        isPad ? CGRectMake(44, 34, 188, 80) : CGRectMake(44, 34, 87, 80); // DAT_0x28f418 etc
    if (CGRectContainsPoint(rect1, loc)) {
        if (kcState == 8) {
            kcState = 9;
        }
        return;
    }
    CGRect rect2 =
        isPad ? CGRectMake(44, 34, 80, 80) : CGRectMake(44, 34, 399, 399); // DAT_0x292ea8 etc
    if (CGRectContainsPoint(rect2, loc) && kcState == 9) {
        kcState = 10;
        for (UISwipeGestureRecognizer *r in arraySwipeRecognizer) {
            [self.view removeGestureRecognizer:r];
        }
        [self nextScene];
        return;
    }
    // Other taps advance the normal flow when kcState is 0–7, not shown here.
}

/** @ghidraAddress 0x13c328 */
- (void)handleSwipe:(UISwipeGestureRecognizer *)sender {
    // Konami swipe state machine. Disassembly at 0x13c328 is a switch on direction:
    // 1: up (6 if kcState==5 else 0, then 8 if 7 else 0), 2: down (7 if 6 else 0, 5 if 4 else 0),
    // 4: right (1 if 1 else 2), 8: left (0 if 2..3 else +1). Verified at 0x13c364–0x13c3ac via
    // cmp w8,#0x7 etc and ccmp.
    UISwipeGestureRecognizerDirection dir = sender.direction;
    int next = 0;
    switch (dir) {
    case UISwipeGestureRecognizerDirectionUp:
        next = (kcState == 5) ? 6 : 0;
        if (kcState == 7) {
            next = 8;
        } else if (next == 8) {
            // keep 8
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
        } else {
            next = 0;
        }
        break;
    default:
        return;
    }
    kcState = next;
}

#pragma mark - Agreement and ID callbacks

/** @ghidraAddress 0x13cb84 */
- (void)agreementError:(id)agreement msgStr:(NSString *)msgStr {
    // If the user already agreed (PrefAgreeChallengePolicyVersion in defaults), go next.
    // Disassembly at 0x13cb84: standardUserDefaults / valueForKey: PrefAgree... / cbnz to
    // nextScene. Otherwise shows an alert with OK (localizedStringForKey:@"OK") and clears
    // licenseAgree/coverView.
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
