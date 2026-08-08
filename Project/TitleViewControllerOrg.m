#import "TitleViewControllerOrg.h"

#import "LicenseAgreementView.h"

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
