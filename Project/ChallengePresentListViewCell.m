#import "ChallengePresentListViewCell.h"

#import "JubeatAppDelegate.h"

// The row plate. The widths are the same two slots ChallengeListViewCell uses; the heights are not,
// since this row is three lines tall.
static const CGFloat kPhonePlateWidth = 309.0; // @ghidraAddress 0x28f8e8
static const CGFloat kPadPlateWidth = 460.0;   // @ghidraAddress 0x28f4f0
static const CGFloat kPhonePlateHeight = 60.0; // @ghidraAddress 0x28f258
static const CGFloat kPadPlateHeight = 96.0;   // @ghidraAddress 0x28f908

static const CGFloat kPhoneTextInset = 10.0;
static const CGFloat kPadTextInset = 20.0;
static const CGFloat kPhoneTextWidth = 299.0; // @ghidraAddress 0x292a10
static const CGFloat kPadTextWidth = 440.0;   // @ghidraAddress 0x292f50

static const CGFloat kPhoneFontSize = 12.0;
static const CGFloat kPadFontSize = 20.0;

static const NSInteger kTextLineCount = 3;

@implementation ChallengePresentListViewCell {
    UIImageView *bgImage;
    UILabel *listText;
}

/** @ghidraAddress 0x1fc1cc */
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        BOOL isPad = JubeatAppDelegate.appDelegate.isPad;
        CGFloat plateHeight = isPad ? kPadPlateHeight : kPhonePlateHeight;

        bgImage = [[UIImageView alloc]
            initWithFrame:CGRectMake(0, 0, isPad ? kPadPlateWidth : kPhonePlateWidth, plateHeight)];
        [self addSubview:bgImage];
        self.backgroundColor = UIColor.clearColor;

        // The label's inset plus its width is exactly the plate's width on both idioms — 10 + 299
        // and 20 + 440 — so it ends flush with the plate. ChallengeListViewCell, otherwise the
        // same class, reuses the plate's own width here and overhangs by one inset.
        listText =
            [[UILabel alloc] initWithFrame:CGRectMake(isPad ? kPadTextInset : kPhoneTextInset,
                                                      0,
                                                      isPad ? kPadTextWidth : kPhoneTextWidth,
                                                      plateHeight)];
        listText.numberOfLines = kTextLineCount;
        listText.font = [UIFont systemFontOfSize:(isPad ? kPadFontSize : kPhoneFontSize)];
        [self addSubview:listText];
    }
    return self;
}

/** @ghidraAddress 0x1fc40c */
- (void)setBgImage:(UIImage *)bgImg text:(NSString *)text {
    bgImage.image = bgImg;
    listText.text = text;
}

@end
