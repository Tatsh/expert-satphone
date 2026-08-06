#import "ChallengeListViewCell.h"

#import "JubeatAppDelegate.h"

// The row plate. The same two widths ChallengePrevRankingListViewCell uses, from the same pool
// slots.
static const CGFloat kPhonePlateWidth = 309.0; // @ghidraAddress 0x28f8e8
static const CGFloat kPadPlateWidth = 460.0;   // @ghidraAddress 0x28f4f0
static const CGFloat kPhonePlateHeight = 20.0;
static const CGFloat kPadPlateHeight = 32.0; // @ghidraAddress 0x28f458

static const CGFloat kPhoneTextInset = 10.0;
static const CGFloat kPadTextInset = 20.0;

static const CGFloat kPhoneFontSize = 12.0;
static const CGFloat kPadFontSize = 20.0;

@implementation ChallengeListViewCell {
    UIImageView *bgImage;
    UILabel *listText;
}

/** @ghidraAddress 0x2087e0 */
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        BOOL isPad = JubeatAppDelegate.appDelegate.isPad;
        CGFloat plateWidth = isPad ? kPadPlateWidth : kPhonePlateWidth;
        CGFloat plateHeight = isPad ? kPadPlateHeight : kPhonePlateHeight;

        bgImage = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, plateWidth, plateHeight)];
        [self addSubview:bgImage];
        self.backgroundColor = UIColor.clearColor;

        // Both subviews go on the cell, not on the plate. Note that the label takes the plate's
        // full width while also being inset from the left, so it ends one inset beyond the plate's
        // trailing edge. ChallengePresentListViewCell, otherwise identical, subtracts the inset.
        listText = [[UILabel alloc]
            initWithFrame:CGRectMake(
                              isPad ? kPadTextInset : kPhoneTextInset, 0, plateWidth, plateHeight)];
        listText.font = [UIFont systemFontOfSize:(isPad ? kPadFontSize : kPhoneFontSize)];
        [self addSubview:listText];
    }
    return self;
}

/** @ghidraAddress 0x2089f4 */
- (void)setBgImage:(UIImage *)bgImg text:(NSString *)text {
    bgImage.image = bgImg;
    listText.text = text;
}

@end
