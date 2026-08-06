#import "ChallengeLoginMessageView.h"

#import "AudioManager.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"

// Artwork, from the CFStrings at 0x2d7440 and 0x2d9980.
static NSString *const kSheetImageName = @"scratch_login_sheet";
static NSString *const kCloseButtonImageName = @"scratch_btn_ok";

// The sound the close button plays, from the CFString at 0x2d6400.
static NSString *const kCloseSoundName = @"SD_LABO_MENU";

// The upper label's format really does begin with U+0008, a backspace, before the first Japanese
// character. It is in the shipped binary at 0x2d9940 and is reproduced here rather than tidied
// away; see TYPES_PENDING.md.
static NSString *const kRemainingScratchesFormat = @"\bあと%d回無料でスクラッチができます！";
static NSString *const kResetNoteText = @"(スクラッチ回数は毎日0:00にリセットされます)";

// The phone enlarges the sheet artwork; the pad uses it at its native size.
static const CGFloat kPhoneArtworkScale = 1.3f; // @ghidraAddress 0x28f718
static const CGFloat kPadArtworkScale = 1.0;

static const CGFloat kPhoneMessageFontSize = 14.0;
static const CGFloat kPadMessageFontSize = 22.0;
static const CGFloat kPhoneNoteFontSize = 12.0;
static const CGFloat kPadNoteFontSize = 18.0;

// The close button's top sits one and a half of its own heights above the sheet's bottom edge.
static const float kCloseButtonHeightFactor = -1.5f;

// The note occupies the middle third of the sheet, and the message the upper half.
static const int kNoteVerticalDivisor = 3;
static const int kMessageVerticalDivisor = 2;

@implementation ChallengeLoginMessageView {
    UIView *bgCtrlView;
    UIImageView *bgView;
    UILabel *loginMessage;
    UILabel *loginMessage2;
    UIButton *closeBtn;
}

/** @ghidraAddress 0xa75fc */
- (instancetype)initWithFrame:(CGRect)frame scratchNum:(int)scratchNum {
    self = [super initWithFrame:frame];
    if (self) {
        BOOL isPad = JubeatAppDelegate.appDelegate.isPad;
        UIImage *sheetImage = LoadScaledPngImage(kSheetImageName);
        CGFloat artworkScale = isPad ? kPadArtworkScale : kPhoneArtworkScale;
        // Truncated to whole points and converted back, so every frame below is integral.
        int sheetWidth = (int)(artworkScale * sheetImage.size.width);
        int sheetHeight = (int)(artworkScale * sheetImage.size.height);
        CGFloat messageFontSize = isPad ? kPadMessageFontSize : kPhoneMessageFontSize;
        CGFloat noteFontSize = isPad ? kPadNoteFontSize : kPhoneNoteFontSize;

        bgCtrlView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, sheetWidth, sheetHeight)];
        // Centred on the passed-in frame's size, not on this view's own bounds.
        bgCtrlView.center = CGPointMake(frame.size.width / 2, frame.size.height / 2);
        [self addSubview:bgCtrlView];

        bgView = [[UIImageView alloc] initWithImage:sheetImage];
        bgView.frame = CGRectMake(0, 0, sheetWidth, sheetHeight);
        [bgCtrlView addSubview:bgView];

        loginMessage = [[UILabel alloc]
            initWithFrame:CGRectMake(0, 0, sheetWidth, sheetHeight / kMessageVerticalDivisor)];
        loginMessage.font = [UIFont systemFontOfSize:messageFontSize];
        loginMessage.text = [NSString stringWithFormat:kRemainingScratchesFormat, scratchNum];
        loginMessage.textAlignment = NSTextAlignmentCenter;
        [bgCtrlView addSubview:loginMessage];

        loginMessage2 =
            [[UILabel alloc] initWithFrame:CGRectMake(0,
                                                      sheetHeight / kNoteVerticalDivisor,
                                                      sheetWidth,
                                                      sheetHeight / kNoteVerticalDivisor)];
        loginMessage2.font = [UIFont systemFontOfSize:noteFontSize];
        // Yes, through stringWithFormat: even though it carries no specifier.
        loginMessage2.text = [NSString stringWithFormat:kResetNoteText];
        loginMessage2.textAlignment = NSTextAlignmentCenter;
        [bgCtrlView addSubview:loginMessage2];

        UIImage *closeImage = LoadScaledPngImage(kCloseButtonImageName);
        int closeWidth = (int)closeImage.size.width;
        int closeHeight = (int)closeImage.size.height;
        // Raw value 1, which today's SDK also spells UIButtonTypeSystem.
        closeBtn = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        // Yes, single precision. The binary computes this one coordinate in float and widens the
        // result, so the reconstruction has to as well or it will not round the same way.
        float closeY = (float)sheetHeight + (float)closeHeight * kCloseButtonHeightFactor;
        closeBtn.frame =
            CGRectMake(sheetWidth / 2 - closeWidth / 2, closeY, closeWidth, closeHeight);
        [closeBtn setBackgroundImage:closeImage forState:UIControlStateNormal];
        [closeBtn addTarget:self
                      action:@selector(closeMessage:)
            forControlEvents:UIControlEventTouchUpInside];
        closeBtn.exclusiveTouch = YES;
        [bgCtrlView addSubview:closeBtn];
    }
    return self;
}

/** @ghidraAddress 0xa7b98 */
- (void)closeMessage:(id)sender {
    // Yes, sender is unused.
    [AudioManager.sharedManager playSeResFile:kCloseSoundName inDirectory:nil];
    // The delegate is fetched twice, once to test and once to send to.
    if ([self.aDelegate respondsToSelector:@selector(closeLoginMessage)]) {
        [self.aDelegate performSelector:@selector(closeLoginMessage)];
    }
}

@end
