#import "LogoViewController.h"

#import "Downloader.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"
#import "ScratchUtil.h"
#import "StoreUtil.h"

// The three splash images, in the order they are shown.
static NSString *const kKonamiLogoImageName = @"k_logo";
static NSString *const kBemaniLogoImageName = @"b_logo";
static NSString *const kNonageCautionImageName = @"n_logo";

// The splash's animation steps. -fireAnimation runs one per call and schedules itself again as the
// animation's completion, so the sequence advances one step per finished animation.
//
// Step 7's arm in -fireAnimation is unreachable: the guard at the top of that method intercepts 7
// and above before the switch is reached, so the age notice is never faded out. See
// TYPES_PENDING.md. Step 6 is reachable, but only from -handleTap:, which parks the sequence there
// while it takes over.
enum {
    kLogoAnimationStateWhitenBackground = 0,
    kLogoAnimationStateFadeInKonamiLogo = 1,
    kLogoAnimationStateFadeOutKonamiLogo = 2,
    kLogoAnimationStateFadeInBemaniLogo = 3,
    kLogoAnimationStateFadeOutBemaniLogo = 4,
    kLogoAnimationStateFadeInNonageCaution = 5,
    kLogoAnimationStateIdle = 6,
    kLogoAnimationStateFadeOutNonageCaution = 7,
    kLogoAnimationStateFinished = 8,
};

// The animation timings, in seconds. Fades in run for half a second after a tenth of a second;
// fades out run for four tenths after the logo has been held for nine.
static const NSTimeInterval kFadeInDuration = 0.5;
static const NSTimeInterval kFadeInDelay = 0.1;     // @ghidraAddress 0x28f290
static const NSTimeInterval kFadeOutDuration = 0.4; // @ghidraAddress 0x28f268
static const NSTimeInterval kFadeOutDelay = 0.9;    // @ghidraAddress 0x28e070

// How long the age-rating notice stays up before -end: is sent, and the delay step 7 would have
// used had it been reachable.
static const NSTimeInterval kNonageCautionHold = 3.0;

// Fully transparent and fully opaque, the only two alphas the fades move between.
static const CGFloat kLogoHidden = 0.0;
static const CGFloat kLogoVisible = 1.0;

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

/** @ghidraAddress 0x82414 */
- (instancetype)init {
    // Nothing but the super call: no ivar setup and no nil check on the result.
    return [super init];
}

/** @ghidraAddress 0x8244c */
- (void)loadView {
    [super loadView];

    // Single-touch only, and opaque because the splash covers the whole screen.
    self.view.userInteractionEnabled = YES;
    self.view.multipleTouchEnabled = NO;
    self.view.opaque = YES;

    // The three images are built identically: centred on the view and starting invisible.
    konamiLogoView = [[UIImageView alloc] initWithImage:LoadScaledPngImage(kKonamiLogoImageName)];
    konamiLogoView.center = self.view.center;
    konamiLogoView.alpha = kLogoHidden;
    [self.view addSubview:konamiLogoView];

    bemaniLogoView = [[UIImageView alloc] initWithImage:LoadScaledPngImage(kBemaniLogoImageName)];
    bemaniLogoView.center = self.view.center;
    bemaniLogoView.alpha = kLogoHidden;
    [self.view addSubview:bemaniLogoView];

    nonageCautionView =
        [[UIImageView alloc] initWithImage:LoadScaledPngImage(kNonageCautionImageName)];
    nonageCautionView.center = self.view.center;
    nonageCautionView.alpha = kLogoHidden;
    [self.view addSubview:nonageCautionView];

    // Two fetches start behind the animation, so the wait for the network is hidden by the logos.
    knitBgDownloader = [[Downloader alloc] initWithURL:[StoreUtil knitColorURL] delegate:self];
    [knitBgDownloader startDownloading];

    eventDownloader = [[Downloader alloc] initWithURL:[ScratchUtil getEventTypeURL] delegate:self];
    [eventDownloader startDownloading];
    // imageDownloader is not started here; only these two are.
}

/** @ghidraAddress 0x82fe0 */
- (void)start {
    closing = NO;
    self.view.backgroundColor = UIColor.blackColor;
    // Both logos start invisible and are faded in by -fireAnimation.
    konamiLogoView.alpha = kLogoHidden;
    bemaniLogoView.alpha = kLogoHidden;
    state = kLogoAnimationStateWhitenBackground;
    [self fireAnimation];
}

/** @ghidraAddress 0x828ec */
- (void)fireAnimation {
    // Everything from step 7 up is the end of the sequence, which is what makes the switch's own
    // step 7 arm unreachable.
    if (state >= kLogoAnimationStateFadeOutNonageCaution) {
        // The sequence is over. Arm the timer that ends the splash, unless it is already ending or
        // the timer is already armed.
        if (closing) {
            return;
        }
        if (endTimer) {
            return;
        }
        endTimer = [NSTimer timerWithTimeInterval:kNonageCautionHold
                                           target:self
                                         selector:@selector(end:)
                                         userInfo:nil
                                          repeats:NO];
        // Added to the common modes so the countdown survives a scroll or a tracking run loop.
        [NSRunLoop.currentRunLoop addTimer:endTimer forMode:NSRunLoopCommonModes];
        return;
    }

    // Replaced by whichever step runs. The default is an empty block, and the default timings are
    // zero, so an unhandled step would animate nothing for no time.
    void (^animations)(void) = ^{
    };
    NSTimeInterval duration = 0.0;
    NSTimeInterval delay = 0.0;

    switch (state) {
    case kLogoAnimationStateWhitenBackground:
        state = kLogoAnimationStateFadeInKonamiLogo;
        animations = ^{
          /** @ghidraAddress 0x82e1c */
          self.view.backgroundColor = UIColor.whiteColor;
        };
        duration = kFadeInDuration;
        delay = 0.0;
        break;

    case kLogoAnimationStateFadeInKonamiLogo:
        state = kLogoAnimationStateFadeOutKonamiLogo;
        animations = ^{
          /** @ghidraAddress 0x82ea0 */
          self->konamiLogoView.alpha = kLogoVisible;
        };
        duration = kFadeInDuration;
        delay = kFadeInDelay;
        break;

    case kLogoAnimationStateFadeOutKonamiLogo:
        state = kLogoAnimationStateFadeInBemaniLogo;
        animations = ^{
          /** @ghidraAddress 0x82ed0 */
          self->konamiLogoView.alpha = kLogoHidden;
        };
        duration = kFadeOutDuration;
        delay = kFadeOutDelay;
        break;

    case kLogoAnimationStateFadeInBemaniLogo:
        state = kLogoAnimationStateFadeOutBemaniLogo;
        // The screen only becomes tappable here, so the Konami logo cannot be skipped.
        [self.view addGestureRecognizer:[[UITapGestureRecognizer alloc]
                                            initWithTarget:self
                                                    action:@selector(handleTap:)]];
        animations = ^{
          /** @ghidraAddress 0x82f00 */
          self->bemaniLogoView.alpha = kLogoVisible;
        };
        duration = kFadeInDuration;
        delay = kFadeInDelay;
        break;

    case kLogoAnimationStateFadeOutBemaniLogo:
        state = kLogoAnimationStateFadeInNonageCaution;
        animations = ^{
          /** @ghidraAddress 0x82f30 */
          self->bemaniLogoView.alpha = kLogoHidden;
        };
        duration = kFadeOutDuration;
        delay = kFadeOutDelay;
        break;

    case kLogoAnimationStateFadeInNonageCaution:
        // Steps to 7, not 6, so the notice is never faded out and the guard above takes over.
        state = kLogoAnimationStateFadeOutNonageCaution;
        animations = ^{
          /** @ghidraAddress 0x82f60 */
          self->nonageCautionView.alpha = kLogoVisible;
        };
        duration = kFadeInDuration;
        delay = kFadeInDelay;
        break;

    case kLogoAnimationStateIdle:
        // Reached only when -handleTap: has taken over and parked the sequence here. Doing nothing
        // is the point: it swallows the completion of the animation the tap interrupted.
        return;

    case kLogoAnimationStateFadeOutNonageCaution:
        // Unreachable: the guard at the top of this method catches 7 before the switch.
        state = kLogoAnimationStateFinished;
        animations = ^{
          /** @ghidraAddress 0x82f90 */
          self->nonageCautionView.alpha = kLogoHidden;
        };
        duration = kFadeOutDuration;
        delay = kNonageCautionHold;
        break;

    default:
        break;
    }

    [UIView animateWithDuration:duration
                          delay:delay
                        options:UIViewAnimationOptionBeginFromCurrentState |
                                UIViewAnimationOptionAllowUserInteraction
                     animations:animations
                     completion:^(BOOL finished) {
                       /** @ghidraAddress 0x82fc0 */
                       // The step's completion drives the next step, so the sequence is a chain
                       // of animations rather than a timer.
                       [self fireAnimation];
                     }];
}

/** @ghidraAddress 0x830bc */
- (void)end:(id)sender {
    endTimer = nil;
    closing = YES;
    [JubeatAppDelegate.appDelegate.rootViewCtrl endLogo];
}

/** @ghidraAddress 0x8314c */
- (void)handleTap:(id)sender {
    unsigned int current = state;

    // Masking the low bit makes this "either BEMANI logo step", so a tap during the fade in and a
    // tap during the fade out are handled the same way.
    if ((current & ~1u) == kLogoAnimationStateFadeOutBemaniLogo) {
        [bemaniLogoView.layer removeAllAnimations];

        // Parked on the idle step first. The interrupted animation's completion still fires, and
        // this is what it lands on so that it advances nothing.
        state = kLogoAnimationStateIdle;

        [UIView animateWithDuration:kFadeInDuration
            delay:0.0
            options:UIViewAnimationOptionBeginFromCurrentState |
                    UIViewAnimationOptionAllowUserInteraction
            animations:^{
              /** @ghidraAddress 0x832f8 */
              self->bemaniLogoView.alpha = kLogoHidden;
            }
            completion:^(BOOL finished) {
              /** @ghidraAddress 0x83328 */
              // Rejoins the sequence one step back, so the next -fireAnimation runs the age
              // notice's fade in.
              self->state = kLogoAnimationStateFadeInNonageCaution;
              [self fireAnimation];
            }];

        // Re-read, but the completion above has not run yet, so this still sees the idle step.
        current = state;
    }

    // A tap while the age notice is up skips the three-second hold instead.
    if (current == kLogoAnimationStateFadeOutNonageCaution && !closing) {
        if (endTimer) {
            [endTimer invalidate];
        }
        [self end:nil];
    }
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
