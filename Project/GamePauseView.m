#import "GamePauseView.h"

#import <QuartzCore/QuartzCore.h>

#import "AudioManager.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"

// The sound-effect base name is prefixed per theme: SD_RPL_%@, SD_KNT_%@, or SD_%@. The button
// handlers pass the tokens below.
static NSString *const kPauseSoundResume = @"SKIP";
static NSString *const kPauseSoundConfirm = @"OK";

@interface GamePauseView ()
- (nonnull NSString *)soundName:(nonnull NSString *)token;
- (void)pushBtnResume:(nonnull id)sender;
- (void)pushBtnRestart:(nonnull id)sender;
- (void)pushBtnEnd:(nonnull id)sender;
@end

// The dimming backdrop's alpha and the frame panel's size and border.
static const CGFloat kPauseBackdropAlpha = 0.5;
static const CGFloat kPauseFrameWidth = 300.0;  // @ghidraAddress 0x28f2d0
static const CGFloat kPauseFrameHeight = 400.0; // @ghidraAddress 0x28f2e0
static const CGFloat kPauseFrameBorderWidth = 3.0;
static const CGFloat kPauseFrameBackgroundWhite = 0.9; // @ghidraAddress 0x28f448
static const CGFloat kPauseFrameBorderWhite = 0.8;     // @ghidraAddress 0x28e080
static const CGFloat kPauseKntBorderWhite = 0.2;       // @ghidraAddress 0x28f240

// The "paused" heading's y by theme (higher on the themed panels than the default).
static const CGFloat kPausePausedYThemed = 65.0;  // @ghidraAddress 0x291bc0
static const CGFloat kPausePausedYDefault = 35.0; // @ghidraAddress 0x28f6c8

// The button vertical offsets, all relative to the frame's vertical centre. The restart button
// sits above centre; the resume and end buttons step downward, and challenge mode omits the
// restart button and shifts the pair.
static const CGFloat kPauseButtonStep = 100.0;     // @ghidraAddress 0x28f3f0
static const CGFloat kPauseRestartYOffset = -40.0; // @ghidraAddress 0x28e078
static const CGFloat kPauseResumeYOffset = -50.0;  // @ghidraAddress 0x28e068
static const CGFloat kPauseEndYOffset = -60.0;     // @ghidraAddress 0x291bc8

// The half-scale used to centre the panel and its contents.
static const CGFloat kPauseHalf = 0.5;

// The animation timings: the fade duration and the delay before interaction is re-enabled.
static const NSTimeInterval kPauseFadeDuration = 0.3;     // @ghidraAddress 0x28f260
static const NSTimeInterval kPauseInteractionDelay = 0.4; // @ghidraAddress 0x28f268

@implementation GamePauseView {
    UIView *frameView;    // +0x8
    UIButton *btnResume;  // +0x10
    UIButton *btnRestart; // +0x18
    UIButton *btnEnd;     // +0x20
    // _delegate (weak) at +0x28 is synthesised.
}

@synthesize delegate = _delegate;

#pragma mark - Construction

/** @ghidraAddress 0x97400 */
- (instancetype)init {
    self = [super initWithFrame:UIScreen.mainScreen.bounds];
    if (!self) {
        return nil;
    }
    self.opaque = NO;
    self.backgroundColor = [UIColor colorWithWhite:0 alpha:kPauseBackdropAlpha];

    // The frame panel, centred on the overlay.
    frameView =
        [[UIView alloc] initWithFrame:CGRectMake(0, 0, kPauseFrameWidth, kPauseFrameHeight)];
    frameView.backgroundColor = UIColor.blackColor;
    frameView.layer.borderColor = [UIColor colorWithWhite:kPauseFrameBorderWhite alpha:1].CGColor;
    frameView.layer.borderWidth = kPauseFrameBorderWidth;
    frameView.center =
        CGPointMake(self.frame.size.width * kPauseHalf, self.frame.size.height * kPauseHalf);
    [self addSubview:frameView];

    // The panel background and button art vary by theme.
    JubeatTheme theme = JubeatAppDelegate.appDelegate.currentTheme;
    NSString *pausedImageName;
    NSString *resumeImageName;
    NSString *endImageName;
    NSString *restartImageName;
    CGFloat pausedY;
    if (theme == JubeatThemeReflecBeatPlus) {
        frameView.backgroundColor = [UIColor colorWithWhite:kPauseFrameBackgroundWhite alpha:1];
        frameView.layer.borderColor =
            [UIColor colorWithWhite:kPauseFrameBorderWhite alpha:1].CGColor;
        [frameView
            addSubview:[[UIImageView alloc] initWithImage:LoadScaledPngImage(@"pause_bg_rpl")]];
        pausedImageName = @"pause_paused_rpl";
        resumeImageName = @"pause_btn_resume_rpl";
        endImageName = @"pause_btn_end_rpl";
        restartImageName = @"pause_btn_restart_rpl";
        pausedY = kPausePausedYThemed;
    } else if (theme == JubeatThemeKnit) {
        frameView.backgroundColor = [UIColor colorWithWhite:kPauseFrameBackgroundWhite alpha:1];
        frameView.layer.borderColor = [UIColor colorWithWhite:kPauseKntBorderWhite alpha:1].CGColor;
        UIImageView *bg = [[UIImageView alloc] initWithImage:LoadScaledPngImage(@"pause_bg_knt")];
        bg.center = CGPointMake(kPauseFrameWidth * kPauseHalf, kPauseFrameHeight * kPauseHalf);
        [frameView addSubview:bg];
        pausedImageName = @"pause_paused_knt";
        resumeImageName = @"pause_btn_resume_knt";
        endImageName = @"pause_btn_end_knt";
        restartImageName = @"pause_btn_restart_knt";
        pausedY = kPausePausedYThemed;
    } else {
        frameView.backgroundColor = UIColor.blackColor;
        frameView.layer.borderColor =
            [UIColor colorWithWhite:kPauseFrameBorderWhite alpha:1].CGColor;
        pausedImageName = @"pause_paused";
        resumeImageName = @"pause_btn_resume";
        endImageName = @"pause_btn_end";
        restartImageName = @"pause_btn_restart";
        pausedY = kPausePausedYDefault;
    }

    // The "paused" heading, centred horizontally at its theme's y.
    UIImageView *pausedView =
        [[UIImageView alloc] initWithImage:LoadScaledPngImage(pausedImageName)];
    pausedView.center = CGPointMake(kPauseFrameWidth * kPauseHalf, pausedY);
    [frameView addSubview:pausedView];

    CGFloat centerX = kPauseFrameWidth * kPauseHalf;
    CGFloat centerY = kPauseFrameHeight * kPauseHalf;
    BOOL challengeMode = JubeatAppDelegate.appDelegate.bChallengeMode;

    // The restart button is only present outside challenge mode, above the vertical centre.
    if (!challengeMode) {
        UIImage *restartImage = LoadScaledPngImage(restartImageName);
        btnRestart = [UIButton buttonWithType:UIButtonTypeCustom];
        btnRestart.frame = CGRectMake(0, 0, restartImage.size.width, restartImage.size.height);
        [btnRestart setBackgroundImage:restartImage forState:UIControlStateNormal];
        btnRestart.center = CGPointMake(centerX, centerY + kPauseRestartYOffset);
        [btnRestart addTarget:self
                       action:@selector(pushBtnRestart:)
             forControlEvents:UIControlEventTouchUpInside];
        btnRestart.exclusiveTouch = YES;
        [frameView addSubview:btnRestart];
    }

    // The resume button. In challenge mode it sits at the centre; otherwise it steps down and up.
    UIImage *resumeImage = LoadScaledPngImage(resumeImageName);
    btnResume = [UIButton buttonWithType:UIButtonTypeCustom];
    btnResume.frame = CGRectMake(0, 0, resumeImage.size.width, resumeImage.size.height);
    [btnResume setBackgroundImage:resumeImage forState:UIControlStateNormal];
    CGFloat step = centerY;
    if (challengeMode) {
        btnResume.center = CGPointMake(centerX, step);
        step = step + kPauseButtonStep;
    } else {
        step = step + kPauseButtonStep;
        btnResume.center = CGPointMake(centerX, step + kPauseResumeYOffset);
    }
    [btnResume addTarget:self
                  action:@selector(pushBtnResume:)
        forControlEvents:UIControlEventTouchUpInside];
    btnResume.exclusiveTouch = YES;
    [frameView addSubview:btnResume];

    // The end button, one step below resume (a further step and offset outside challenge mode).
    UIImage *endImage = LoadScaledPngImage(endImageName);
    btnEnd = [UIButton buttonWithType:UIButtonTypeCustom];
    btnEnd.frame = CGRectMake(0, 0, endImage.size.width, endImage.size.height);
    [btnEnd setBackgroundImage:endImage forState:UIControlStateNormal];
    CGFloat endY = step;
    if (!challengeMode) {
        endY = step + kPauseButtonStep + kPauseEndYOffset;
    } else {
        endY = step + kPauseButtonStep;
    }
    btnEnd.center = CGPointMake(centerX, endY);
    [btnEnd addTarget:self
                  action:@selector(pushBtnEnd:)
        forControlEvents:UIControlEventTouchUpInside];
    btnEnd.exclusiveTouch = YES;
    [frameView addSubview:btnEnd];
    return self;
}

#pragma mark - Sound

/** @ghidraAddress 0x98044 */
- (NSString *)soundName:(NSString *)token {
    JubeatTheme theme = JubeatAppDelegate.appDelegate.currentTheme;
    if (theme == JubeatThemeReflecBeatPlus) {
        return [NSString stringWithFormat:@"SD_RPL_%@", token];
    }
    if (theme == JubeatThemeKnit) {
        return [NSString stringWithFormat:@"SD_KNT_%@", token];
    }
    return [NSString stringWithFormat:@"SD_%@", token];
}

#pragma mark - Presentation

/** @ghidraAddress 0x98134 */
- (void)showInView:(UIView *)view animated:(BOOL)animated {
    if (!animated) {
        [view addSubview:self];
        self.alpha = 1.0;
        return;
    }
    [UIApplication.sharedApplication beginIgnoringInteractionEvents];
    [view addSubview:self];
    self.alpha = 0;
    __weak GamePauseView *weakSelf = self;
    [UIView animateWithDuration:kPauseFadeDuration
                     animations:^{
                       /** @ghidraAddress 0x982ec */
                       weakSelf.alpha = 1.0;
                     }];
    [UIApplication.sharedApplication performSelector:@selector(endIgnoringInteractionEvents)
                                          withObject:nil
                                          afterDelay:kPauseInteractionDelay];
}

#pragma mark - Button handlers

/** @ghidraAddress 0x98338 */
- (void)pushBtnResume:(id)sender {
    [AudioManager.sharedManager playSeResFile:[self soundName:kPauseSoundResume] inDirectory:nil];
    [UIApplication.sharedApplication beginIgnoringInteractionEvents];
    __weak GamePauseView *weakSelf = self;
    [UIView animateWithDuration:kPauseFadeDuration
        delay:0
        options:UIViewAnimationOptionCurveLinear
        animations:^{
          /** @ghidraAddress 0x985d0 */
          weakSelf.alpha = 0;
        }
        completion:^(BOOL __attribute__((unused)) finished) {
          /** @ghidraAddress 0x9861c */
          [weakSelf removeFromSuperview];
          [weakSelf.delegate resumeInPauseView];
        }];
    [UIApplication.sharedApplication performSelector:@selector(endIgnoringInteractionEvents)
                                          withObject:nil
                                          afterDelay:kPauseInteractionDelay];
    // A second sound, "OK", plays after the resume "SKIP" — kept verbatim from the binary.
    [AudioManager.sharedManager playSeResFile:[self soundName:kPauseSoundConfirm] inDirectory:nil];
}

/** @ghidraAddress 0x986a8 */
- (void)pushBtnRestart:(id)sender {
    [UIApplication.sharedApplication beginIgnoringInteractionEvents];
    __weak GamePauseView *weakSelf = self;
    [UIView animateWithDuration:kPauseFadeDuration
        delay:0
        options:UIViewAnimationOptionCurveLinear
        animations:^{
          /** @ghidraAddress 0x98900 */
          weakSelf.alpha = 0;
        }
        completion:^(BOOL __attribute__((unused)) finished) {
          /** @ghidraAddress 0x9894c */
          [weakSelf removeFromSuperview];
        }];
    [UIApplication.sharedApplication performSelector:@selector(endIgnoringInteractionEvents)
                                          withObject:nil
                                          afterDelay:kPauseInteractionDelay];
    [AudioManager.sharedManager playSeResFile:[self soundName:kPauseSoundConfirm] inDirectory:nil];
    [self.delegate restartInPauseView];
}

/** @ghidraAddress 0x98994 */
- (void)pushBtnEnd:(id)sender {
    [AudioManager.sharedManager playSeResFile:[self soundName:kPauseSoundConfirm] inDirectory:nil];
    [self.delegate endInPauseView];
}

@end
