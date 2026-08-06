#import "ChallengeRewardListCell.h"

#import "JubeatAppDelegate.h"

// A nominal text height used only for the vertical centring arithmetic. Neither label ever has a
// font set on it, so this figure does not actually size any text.
static const int kPhoneNominalTextHeight = 12;
static const int kPadNominalTextHeight = 16;

// The labels are two points taller than that nominal height. The binary spells this as ORR #2
// rather than an add, which it can because bit 1 is clear in both constants.
static const int kLabelHeightPadding = 2;

@implementation ChallengeRewardListCell {
    UILabel *sheetTitle;
    UILabel *sheetPeriod;
    UIImageView *bgView;
}

/** @ghidraAddress 0xaa4fc */
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    return self;
}

/** @ghidraAddress 0xaa7e0 */
- (void)setBgImage:(UIImage *)bgImg {
    if (bgView == nil) {
        bgView = [[UIImageView alloc]
            initWithFrame:CGRectMake(0, 0, bgImg.size.width, bgImg.size.height)];
        [self addSubview:bgView];
    }
    bgView.image = bgImg;
}

/** @ghidraAddress 0xaa598 */
- (void)setTitle:(NSString *)title period:(NSString *)period {
    // Every coordinate below is measured off the plate, so without it there is nothing to do.
    if (bgView == nil) {
        return;
    }

    BOOL isPad = JubeatAppDelegate.appDelegate.isPad;
    int nominalTextHeight = isPad ? kPadNominalTextHeight : kPhoneNominalTextHeight;
    int labelHeight = nominalTextHeight + kLabelHeightPadding;
    // The single-label centre line, truncated to a whole number.
    int textY = (int)((bgView.frame.size.height - nominalTextHeight) / 2);

    if (period != nil) {
        int halfLabel = labelHeight / 2;
        if (sheetPeriod == nil) {
            // Yes, half the plate's *height* is used as the left inset, and the period label then
            // takes the plate's full width — so it runs one inset past the plate's trailing edge.
            // The title label below takes half the width instead.
            sheetPeriod = [[UILabel alloc] initWithFrame:CGRectMake(bgView.frame.size.height / 2,
                                                                    textY + halfLabel,
                                                                    bgView.frame.size.width,
                                                                    labelHeight)];
            [self addSubview:sheetPeriod];
        }
        sheetPeriod.text = period;
        // With a period present the title moves up by half a label, so the pair straddles the
        // centre line the single label would have sat on.
        textY -= halfLabel;
    }

    if (sheetTitle == nil) {
        sheetTitle = [[UILabel alloc] initWithFrame:CGRectMake(bgView.frame.size.height / 2,
                                                               textY,
                                                               bgView.frame.size.width / 2,
                                                               labelHeight)];
        [self addSubview:sheetTitle];
    }
    sheetTitle.text = title;
}

@end
