#import "FrameLockView.h"

#import "ImageLoading.h"
#import "JubeatAppDelegate.h"

// The padlock, in its two states. From the CFStrings at 0x2d8400 and 0x2d8440.
static NSString *const kLockImageName = @"tw_setting_lock";
static NSString *const kLockSelectedImageName = @"tw_setting_lock_s";

// From the CFString at 0x2d8420. One %d, one argument.
static NSString *const kUnlockCountFormat = @"あと%d個のアプリインストールで選択可能";

// The panel dims whatever is behind it to half.
static const CGFloat kDimmingAlpha = 0.5f;

static const CGFloat kPhoneCaptionFontSize = 14.0;
static const CGFloat kPadCaptionFontSize = 20.0;

// The fade-out when the last install lands.
static const NSTimeInterval kUnlockFadeDuration = 0.2; // @ghidraAddress 0x28e040

@implementation FrameLockView {
    UIView *bgView;
    UIImageView *lockIcon;
    UILabel *lockText;
    CGRect parentFrame;
}

/** @ghidraAddress 0x7b0a0 */
- (instancetype)initWithFrame:(CGRect)frame unlockNumber:(int)unlockNumber {
    self = [super initWithFrame:frame];
    if (self) {
        BOOL isPad = JubeatAppDelegate.appDelegate.isPad;
        // Clamped once here and again in the setter, rather than in one shared place.
        int remaining = unlockNumber < 0 ? 0 : unlockNumber;
        parentFrame = frame;

        bgView = [[UIView alloc] initWithFrame:frame];
        bgView.opaque = NO;
        bgView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:kDimmingAlpha];
        if (remaining == 0) {
            bgView.hidden = YES;
        }
        [self addSubview:bgView];

        UIImage *lockImage = LoadScaledPngImage(kLockImageName);
        // Yes, the frame's origin is the frame's own centre and is then immediately overridden by
        // -setCenter:. Only the size the frame carries survives.
        lockIcon = [[UIImageView alloc] initWithFrame:CGRectMake(frame.size.width / 2,
                                                                 frame.size.height / 2,
                                                                 lockImage.size.width,
                                                                 lockImage.size.height)];
        lockIcon.image = lockImage;
        lockIcon.center = CGPointMake(frame.size.width / 2, frame.size.height / 2);
        [bgView addSubview:lockIcon];

        // Exactly covers the padlock, and is added to it rather than to the panel.
        lockText = [[UILabel alloc]
            initWithFrame:CGRectMake(0, 0, lockImage.size.width, lockImage.size.height)];
        lockText.textColor = UIColor.whiteColor;
        lockText.textAlignment = NSTextAlignmentCenter;
        lockText.font =
            [UIFont systemFontOfSize:(isPad ? kPadCaptionFontSize : kPhoneCaptionFontSize)];
        lockText.backgroundColor = UIColor.clearColor;
        lockText.text = [NSString stringWithFormat:kUnlockCountFormat, remaining];
        [lockIcon addSubview:lockText];
    }
    return self;
}

/** @ghidraAddress 0x7b4d4 */
- (void)setUnlockNumber:(int)unlockNumber {
    int remaining = unlockNumber < 0 ? 0 : unlockNumber;
    if (remaining > 0) {
        lockText.text = [NSString stringWithFormat:kUnlockCountFormat, remaining];
    }
    // Only on the transition to zero, and only from visible — so the fade cannot run twice, and a
    // non-zero count never un-hides a panel that has already gone.
    if (remaining == 0 && !self.isHidden) {
        __weak UIView *weakBgView = bgView;
        [UIView animateWithDuration:kUnlockFadeDuration
            delay:0
            options:UIViewAnimationOptionCurveLinear
            animations:^{
              /** @ghidraAddress 0x7b668 */
              weakBgView.alpha = 0.0;
            }
            completion:^(BOOL __attribute__((unused)) finished) {
              /** @ghidraAddress 0x7b6b4 */
              // Captured strongly here, unlike the animation block above.
              self->bgView.hidden = YES;
            }];
    }
}

/** @ghidraAddress 0x7b6e4 */
- (void)setLockTextDisp:(BOOL)lockTextDisp {
    if (lockTextDisp) {
        lockText.alpha = 1.0;
        return;
    }

    // The selected artwork is a different size, so the padlock is re-framed and re-centred against
    // the frame this view was built with rather than against its current bounds.
    UIImage *selectedImage = LoadScaledPngImage(kLockSelectedImageName);
    lockIcon.frame = CGRectMake(parentFrame.size.width / 2,
                                parentFrame.size.height / 2,
                                selectedImage.size.width,
                                selectedImage.size.height);
    lockIcon.image = selectedImage;
    lockIcon.center = CGPointMake(parentFrame.size.width / 2, parentFrame.size.height / 2);
    lockText.alpha = 0.0;
}

@end
