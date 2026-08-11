#import "ChallengeMissionListCell.h"

#import "JubeatAppDelegate.h"

// Type sizes, per idiom. The pad gets two points more on each line than the phone.
enum {
    kTitleFontSizePad = 18,
    kTitleFontSizePhone = 16,
    kPeriodFontSizePad = 16,
    kPeriodFontSizePhone = 12,
};

// Both labels are given the title's height, whichever line they carry.
static const int kLabelHeightPadding = 2;

// How far the two lines sit either side of the background's vertical centre, on top of half the
// period line's own height.
static const int kLineGap = 3;

// The chosen border: three points of a yellow-green, drawn on the background rather than the icon.
// The three components are at 0x291c60, 0x291c68 and 0x291c70, and each is exactly n/255 at float
// precision, so they are written as the division rather than as a decimal. That form is not one the
// address audit can check, hence no annotation.
static const CGFloat kSelectedBorderWidth = 3.0;
static const CGFloat kSelectedBorderRed = 115.0f / 255.0f;
static const CGFloat kSelectedBorderGreen = 179.0f / 255.0f;
static const CGFloat kSelectedBorderBlue = 13.0f / 255.0f;

static const CGFloat kHalf = 0.5;

@implementation ChallengeMissionListCell {
    UILabel *sheetTitle;
    UILabel *sheetPeriod;
    UIImageView *bgView;
    UIImageView *iconView;
}

/** @ghidraAddress 0xa9dc8 */
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        // Nothing else. The four subviews are built by the setters below.
    }
    return self;
}

/** @ghidraAddress 0xaa160 */
- (void)setBgImage:(UIImage *)bgImg {
    if (!bgView) {
        bgView = [[UIImageView alloc]
            initWithFrame:CGRectMake(0, 0, bgImg.size.width, bgImg.size.height)];
        [self addSubview:bgView];
    }
    bgView.image = bgImg;
}

/** @ghidraAddress 0xa9e64 */
- (void)setTitle:(NSString *)title period:(NSString *)period {
    // The whole body is guarded on the background existing: it is what everything is measured
    // against, so without it the row silently keeps whatever text it had.
    if (!bgView) {
        return;
    }

    BOOL isPad = JubeatAppDelegate.appDelegate.isPad;
    int titleFontSize = isPad ? kTitleFontSizePad : kTitleFontSizePhone;
    int periodFontSize = isPad ? kPeriodFontSizePad : kPeriodFontSizePhone;
    int labelHeight = titleFontSize + kLabelHeightPadding;

    // The text starts where the icon's column ends — see -setIconImage:selectedImage:, which
    // centres the icon inside the leftmost half-height of the background.
    CGFloat textX = bgView.frame.size.height * kHalf;
    // Truncated to a whole point, so a line never lands on a half pixel.
    int lineY = (int)((bgView.frame.size.height - titleFontSize) * kHalf);

    if (period) {
        int halfPeriodHeight = (periodFontSize + kLabelHeightPadding) / 2;
        if (!sheetPeriod) {
            sheetPeriod =
                [[UILabel alloc] initWithFrame:CGRectMake(textX,
                                                          halfPeriodHeight + lineY + kLineGap,
                                                          bgView.frame.size.width,
                                                          labelHeight)];
            sheetPeriod.font = [UIFont systemFontOfSize:periodFontSize];
            [self addSubview:sheetPeriod];
        }
        sheetPeriod.text = period;
        // Having pushed the period down, push the title up by the same amount.
        lineY = lineY - kLineGap - halfPeriodHeight;
    }

    if (!sheetTitle) {
        sheetTitle = [[UILabel alloc]
            initWithFrame:CGRectMake(textX, lineY, bgView.frame.size.width, labelHeight)];
        sheetTitle.font = [UIFont systemFontOfSize:titleFontSize];
        [self addSubview:sheetTitle];
    }
    sheetTitle.text = title;
}

/** @ghidraAddress 0xaa248 */
- (void)setIconImage:(UIImage *)iconImg selectedImage:(BOOL)selectedImage {
    if (!bgView) {
        return;
    }

    if (selectedImage) {
        bgView.layer.borderWidth = kSelectedBorderWidth;
        bgView.layer.borderColor = [UIColor colorWithRed:kSelectedBorderRed
                                                   green:kSelectedBorderGreen
                                                    blue:kSelectedBorderBlue
                                                   alpha:1.0]
                                       .CGColor;
    } else {
        // Only the width is cleared; whatever colour was last set stays on the layer.
        bgView.layer.borderWidth = 0;
    }

    if (!iconView) {
        // The icon view is only ever built from a real image, so a first call with a nil icon
        // leaves the row without one for good.
        if (!iconImg) {
            return;
        }
        // Centred vertically in the background, and horizontally inside its leftmost half-height —
        // the column the labels above begin after.
        int iconX = (int)((bgView.frame.size.height * kHalf - iconImg.size.width) * kHalf);
        int iconY = (int)((bgView.frame.size.height - iconImg.size.height) * kHalf);
        iconView = [[UIImageView alloc]
            initWithFrame:CGRectMake(iconX, iconY, iconImg.size.width, iconImg.size.height)];
        [self addSubview:iconView];
    }
    iconView.image = iconImg;
}

@end
