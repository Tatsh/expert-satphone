#import "ChallengeMissionMessageView.h"

#import "AudioManager.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"

// The panel's three pieces of artwork.
static NSString *const kBackgroundImageName = @"scratch_login_sheet";
static NSString *const kCloseButtonImageName = @"cm_btn_close";
static NSString *const kCheckButtonImageName = @"cm_btn_check";

// Both buttons play the same sound.
static NSString *const kButtonSoundName = @"SD_LABO_MENU";

// The phone enlarges the background; the pad takes it at its own size.
static const CGFloat kPadBackgroundScale = 1.0;
static const CGFloat kPhoneBackgroundScale = 1.3f; // @ghidraAddress 0x28f718

static const CGFloat kPadFontSize = 22.0;
static const CGFloat kPhoneFontSize = 12.0;

// The message occupies everything above the button row, which is reserved one and a half button
// heights. Computed at single precision, as the fmul and fadd on s registers are.
static const float kButtonRowHeightFactor = -1.5f;

// Two buttons laid out with an equal gap either side of each and between them.
enum {
    kButtonCount = 2,
    kButtonGapCount = 3,
};

static const CGFloat kHalf = 0.5;

@implementation ChallengeMissionMessageView {
    UIView *bgCtrlView;
    UIImageView *bgView;
    UILabel *loginMessage;
    UIButton *closeBtn;
    UIButton *checkBtn;
}

/** @ghidraAddress 0x62558 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        BOOL isPad = JubeatAppDelegate.appDelegate.isPad;

        UIImage *background = LoadScaledPngImage(kBackgroundImageName);
        // The phone gets the larger factor, not the pad.
        CGFloat scale = isPad ? kPadBackgroundScale : kPhoneBackgroundScale;
        // Truncated to whole points, so the panel never lands on a half pixel.
        int panelWidth = (int)(scale * background.size.width);
        int panelHeight = (int)(scale * background.size.height);
        CGFloat fontSize = isPad ? kPadFontSize : kPhoneFontSize;

        // The panel is sized from its artwork and only positioned from the frame.
        bgCtrlView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, panelWidth, panelHeight)];
        bgCtrlView.center = CGPointMake(frame.size.width * kHalf, frame.size.height * kHalf);
        [self addSubview:bgCtrlView];

        bgView = [[UIImageView alloc] initWithImage:background];
        bgView.frame = CGRectMake(0, 0, panelWidth, panelHeight);
        [bgCtrlView addSubview:bgView];

        UIImage *closeImage = LoadScaledPngImage(kCloseButtonImageName);
        int buttonWidth = (int)closeImage.size.width;
        int buttonHeight = (int)closeImage.size.height;
        // Three equal gaps: margin, button, gap, button, margin. The arithmetic closes exactly —
        // 3 * gap + 2 * buttonWidth is the panel's width.
        int buttonGap = (panelWidth - buttonWidth * kButtonCount) / kButtonGapCount;
        int messageHeight =
            (int)((float)panelHeight + (float)buttonHeight * kButtonRowHeightFactor);

        loginMessage = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, panelWidth, messageHeight)];
        loginMessage.font = [UIFont systemFontOfSize:fontSize];
        // A format string with no specifiers and no arguments — the call formats nothing.
        loginMessage.text =
            [NSString stringWithFormat:@"新しいミッションシートがあります。\n確認しますか？"];
        loginMessage.numberOfLines = 0;
        loginMessage.textAlignment = NSTextAlignmentCenter;
        [bgCtrlView addSubview:loginMessage];

        // The dismiss button is the right-hand one, despite being built first.
        closeBtn = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        closeBtn.frame =
            CGRectMake(buttonWidth + buttonGap * 2, messageHeight, buttonWidth, buttonHeight);
        [closeBtn setBackgroundImage:closeImage forState:UIControlStateNormal];
        [closeBtn addTarget:self
                      action:@selector(closeMessage:)
            forControlEvents:UIControlEventTouchUpInside];
        closeBtn.exclusiveTouch = YES;
        [bgCtrlView addSubview:closeBtn];

        UIImage *checkImage = LoadScaledPngImage(kCheckButtonImageName);
        checkBtn = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        // Sized from the *close* button's artwork, not its own.
        checkBtn.frame = CGRectMake(buttonGap, messageHeight, buttonWidth, buttonHeight);
        [checkBtn setBackgroundImage:checkImage forState:UIControlStateNormal];
        [checkBtn addTarget:self
                      action:@selector(openMission:)
            forControlEvents:UIControlEventTouchUpInside];
        checkBtn.exclusiveTouch = YES;
        [bgCtrlView addSubview:checkBtn];
    }
    return self;
}

/** @ghidraAddress 0x62aa4 */
- (void)closeMessage:(id)sender {
    [AudioManager.sharedManager playSeResFile:kButtonSoundName inDirectory:nil];
    if ([self.aDelegate respondsToSelector:@selector(closeMissionMessage)]) {
        [self.aDelegate performSelector:@selector(closeMissionMessage)];
    }
}

/** @ghidraAddress 0x62b98 */
- (void)openMission:(id)sender {
    // Instruction for instruction the same as the method above but for the selector, including the
    // sound.
    [AudioManager.sharedManager playSeResFile:kButtonSoundName inDirectory:nil];
    if ([self.aDelegate respondsToSelector:@selector(openMissionList)]) {
        [self.aDelegate performSelector:@selector(openMissionList)];
    }
}

@end
