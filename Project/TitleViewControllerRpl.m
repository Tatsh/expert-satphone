#import "TitleViewControllerRpl.h"

#import "LicenseAgreementView.h"

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
