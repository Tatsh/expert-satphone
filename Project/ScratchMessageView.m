#import "ScratchMessageView.h"

#import "ChallengeStatus.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"

// The remaining-scratch digit's artwork, from the CFStrings at 0x2d7fa0 and 0x2d8000. The first is
// only loaded to be measured; -setScratchCnt: builds the real name from the format.
static NSString *const kScratchDigitImageName = @"scratch_num_00";
static NSString *const kScratchDigitNameFormat = @"scratch_num_0%d";

// The countdown's prefix, and the shorter one the phone substitutes for it.
static NSString *const kPadCountdownPrefix = @"スクラッチシートの入れ替えまで";
static NSString *const kPhoneCountdownPrefix = @"シートの入れ替えまで";
// Shown instead of a countdown once the sheet has expired.
static NSString *const kExpiredMessage = @"スクラッチシート期限切れ";
static NSString *const kCountdownFormat = @"%@%@";

// Only one digit of artwork exists, so higher counts are clamped.
static const int kMaximumScratchCount = 9;

// The phone's content scale is its screen rate times this. Five twelfths, to float precision.
static const float kPhoneContentScale = 0.4166666567325592f; // @ghidraAddress 0x28f898

// Pad-coordinate layout figures, all scaled on the phone.
static const float kScratchDigitBottom = 53.0f; // @ghidraAddress 0x28f8f0
static const float kScratchDigitX = 48.0f;      // @ghidraAddress 0x28f8f4
static const float kCountdownCentreY = 76.0f;   // @ghidraAddress 0x28f8f8
static const float kCountdownWidth = 290.0f;    // @ghidraAddress 0x28f8fc
static const float kCountdownHeightFactor = 10.0f;

// The pad takes these directly instead of scaling anything.
static const CGFloat kPadScratchDigitY = 22.0;
static const CGFloat kPadCountdownY = 110.0; // @ghidraAddress 0x28f5e8
static const int kPadCountdownHeight = 20;
static const float kPadCountdownX = 12.0f;
static const CGFloat kPadFontSize = 14.0;

// The two fixed-point conversions the binary uses instead of a multiply: fcvtzs with three and
// four fractional bits, which is a scale by eight and by sixteen.
static const float kFontSizeScale = 8.0f;
static const float kCountdownXScale = 16.0f;

// Below this many seconds the countdown is replaced by the expiry message.
static const double kExpiryThreshold = 1.0;

@implementation ScratchMessageView {
    UIImageView *scratchNum;
    UILabel *scratchChangeTime;
    NSString *templateText;
}

/** @ghidraAddress 0x73c20 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        BOOL isPad = JubeatAppDelegate.appDelegate.isPad;

        // On the pad both scales are one and every figure below is used as written.
        float screenRate = 1.0f;
        if (!isPad) {
            screenRate = ChallengeStatus.sharedStatus.phoneScreenRate;
        }
        float contentScale = isPad ? 1.0f : screenRate * kPhoneContentScale;

        UIImage *digitImage = LoadScaledPngImage(kScratchDigitImageName);

        // The pad pins the digit's top; the phone derives it from a baseline and the artwork's
        // own height, then truncates to a whole point.
        CGFloat digitY = kPadScratchDigitY;
        if (!isPad) {
            digitY = (int)(screenRate * kScratchDigitBottom - digitImage.size.height);
        }
        scratchNum = [[UIImageView alloc] initWithFrame:CGRectMake(contentScale * kScratchDigitX,
                                                                   digitY,
                                                                   digitImage.size.width,
                                                                   digitImage.size.height)];
        [self addSubview:scratchNum];

        int fontSize = (int)(screenRate * kFontSizeScale);
        int countdownXUnits = (int)(contentScale * kCountdownXScale);
        int countdownHeight =
            isPad ? kPadCountdownHeight : (int)(screenRate * kCountdownHeightFactor);

        // The pad pins the label's top; the phone centres it on a baseline instead.
        CGFloat countdownY = kPadCountdownY;
        if (!isPad) {
            countdownY = (int)(screenRate * kCountdownCentreY - countdownHeight / 2);
        }

        scratchChangeTime = [[UILabel alloc]
            initWithFrame:CGRectMake(contentScale * (isPad ? kPadCountdownX : countdownXUnits),
                                     countdownY,
                                     contentScale * kCountdownWidth,
                                     countdownHeight)];
        scratchChangeTime.textColor = UIColor.whiteColor;
        scratchChangeTime.font = [UIFont systemFontOfSize:(isPad ? kPadFontSize : fontSize)];
        [self addSubview:scratchChangeTime];

        // Assigned twice on the phone: the longer prefix first, then immediately replaced by the
        // shorter one. Only the pad keeps the first.
        templateText = kPadCountdownPrefix;
        if (!isPad) {
            templateText = kPhoneCountdownPrefix;
        }
    }
    return self;
}

/** @ghidraAddress 0x73fb8 */
- (void)setScratchCnt:(int)scratchCnt {
    int shown = scratchCnt > kMaximumScratchCount ? kMaximumScratchCount : scratchCnt;
    scratchNum.image =
        LoadScaledPngImage([NSString stringWithFormat:kScratchDigitNameFormat, shown]);
}

/** @ghidraAddress 0x74054 */
- (void)timerUpdate {
    ChallengeStatus *status = ChallengeStatus.sharedStatus;
    if ([status getTimeLeft:status.scratchResetDate] < kExpiryThreshold) {
        scratchChangeTime.text = kExpiredMessage;
        return;
    }
    // The remaining time is computed a second time rather than reusing the value just tested.
    NSString *remaining =
        [status timeStringFromInterval:[status getTimeLeft:status.scratchResetDate]];
    scratchChangeTime.text = [NSString stringWithFormat:kCountdownFormat, templateText, remaining];
}

@end
