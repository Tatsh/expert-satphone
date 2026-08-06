#import "ChallengePrevRankingListViewCell.h"

#import "JubeatAppDelegate.h"

// Row metrics, one pair per device idiom. Everything but the label's height doubles on the pad.
static const CGFloat kPhoneRowWidth = 309.0; // @ghidraAddress 0x28f8e8
static const CGFloat kPadRowWidth = 460.0;   // @ghidraAddress 0x28f4f0
static const int kPhoneRowHeight = 44;
static const int kPadRowHeight = 88;
static const int kPhoneArtworkInset = 2;
static const int kPadArtworkInset = 4;
static const int kPhoneArtworkSize = 40;
static const int kPadArtworkSize = 80;

// The row's width less the artwork. The label takes this less three insets, which leaves it ending
// one inset short of the row's trailing edge: 44 + 263 + 2 = 309, and 88 + 368 + 4 = 460.
static const int kPhoneNameWidthAllowance = 269;
static const int kPadNameWidthAllowance = 380;

static const CGFloat kNameLabelHeight = 20.0;
// The label is placed by its top, so it clears the row's midpoint by this much.
static const int kNameLabelRiseAboveMiddle = 10;

@implementation ChallengePrevRankingListViewCell {
    UIImageView *bgImage;
    UIImageView *artworkImage;
    UILabel *nameLabel;
}

/** @ghidraAddress 0x72ba0 */
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        BOOL isPad = JubeatAppDelegate.appDelegate.isPad;
        CGFloat rowWidth = isPad ? kPadRowWidth : kPhoneRowWidth;
        int rowHeight = isPad ? kPadRowHeight : kPhoneRowHeight;
        int artworkInset = isPad ? kPadArtworkInset : kPhoneArtworkInset;
        int artworkSize = isPad ? kPadArtworkSize : kPhoneArtworkSize;
        int nameWidthAllowance = isPad ? kPadNameWidthAllowance : kPhoneNameWidthAllowance;

        self.backgroundColor = UIColor.clearColor;

        bgImage = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, rowWidth, rowHeight)];
        [self addSubview:bgImage];

        artworkImage = [[UIImageView alloc]
            initWithFrame:CGRectMake(artworkInset, artworkInset, artworkSize, artworkSize)];
        [bgImage addSubview:artworkImage];

        nameLabel =
            [[UILabel alloc] initWithFrame:CGRectMake(artworkSize + artworkInset * 2,
                                                      rowHeight / 2 - kNameLabelRiseAboveMiddle,
                                                      nameWidthAllowance - artworkInset * 3,
                                                      kNameLabelHeight)];
        [bgImage addSubview:nameLabel];
    }
    return self;
}

/** @ghidraAddress 0x72de8 */
- (void)setLineupCell:(UIImage *)lineupCell name:(NSString *)name bgImg:(UIImage *)bgImg {
    bgImage.image = bgImg;
    artworkImage.image = lineupCell;
    nameLabel.text = name;
}

@end
