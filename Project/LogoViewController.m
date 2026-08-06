#import "LogoViewController.h"

#import "Downloader.h"
#import "JubeatAppDelegate.h"

// The animation's opening step. The rest of the state machine lives in -fireAnimation, which is not
// reconstructed yet, so only the value -start writes is named here.
enum {
    kLogoAnimationStateStart = 0,
};

@implementation LogoViewController {
    // Declared in this order by the runtime metadata, which is not the order the ivar offset
    // globals sit in; the offsets are what the code actually indexes by.
    unsigned int state;             // offset global 0x34a000
    BOOL closing;                   // offset global 0x34a004
    UIImageView *konamiLogoView;    // offset global 0x349fec
    UIImageView *bemaniLogoView;    // offset global 0x349ff0
    UIImageView *nonageCautionView; // offset global 0x349ff4
    // Weak, from the objc_storeWeak in -end: and the objc_loadWeakRetained in -dealloc. A scheduled
    // timer is owned by the run loop, so this does not keep it alive. The ivar's own encoding is a
    // bare @"NSTimer" and records none of that.
    __weak NSTimer *endTimer;     // offset global 0x34a008
    Downloader *knitBgDownloader; // offset global 0x349ff8
    Downloader *imageDownloader;  // offset global 0x34a00c
    Downloader *eventDownloader;  // offset global 0x349ffc
}

/** @ghidraAddress 0x82fe0 */
- (void)start {
    closing = NO;
    self.view.backgroundColor = UIColor.blackColor;
    // Both logos start invisible and are faded in by -fireAnimation.
    konamiLogoView.alpha = 0.0;
    bemaniLogoView.alpha = 0.0;
    state = kLogoAnimationStateStart;
    [self fireAnimation];
}

/** @ghidraAddress 0x830bc */
- (void)end:(id)sender {
    endTimer = nil;
    closing = YES;
    [JubeatAppDelegate.appDelegate.rootViewCtrl endLogo];
}

/** @ghidraAddress 0x8335c */
- (void)viewDidUnload {
    [super viewDidUnload];

    konamiLogoView = nil;
    bemaniLogoView = nil;
    // nonageCautionView is not dropped here, unlike the two logo views above.
    endTimer = nil;

    if (knitBgDownloader) {
        [knitBgDownloader cancel];
        knitBgDownloader = nil;
    }
    if (imageDownloader) {
        [imageDownloader cancel];
        imageDownloader = nil;
    }
    // eventDownloader is left running; only the other two are cancelled.
}

/** @ghidraAddress 0x8342c */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

/** @ghidraAddress 0x83464 */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

/** @ghidraAddress 0x8349c */
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

/** @ghidraAddress 0x834d4 */
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

/** @ghidraAddress 0x8350c */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return UIInterfaceOrientationIsPortrait(interfaceOrientation);
}

/** @ghidraAddress 0x8351c */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

/** @ghidraAddress 0x83524 */
- (BOOL)shouldAutorotate {
    return YES;
}

/** @ghidraAddress 0x8352c */
- (void)dealloc {
    // Loaded through the weak slot, so this is nil if the timer has already gone.
    [endTimer invalidate];
    // [super dealloc] is compiler-emitted (ARC — .cxx_destruct at 0x840a4).
}

@end
