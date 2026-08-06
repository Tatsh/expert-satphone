#import "ChallengeRankingListViewCell.h"

#import "JubeatAppDelegate.h"

// The plate. The widths are the same two pool slots the other list rows use; the heights are this
// row's own, and it is the shortest row in the tree.
static const int kPhonePlateWidth = 309; // @ghidraAddress 0x28f8e8 as a double
static const int kPadPlateWidth = 460;   // @ghidraAddress 0x28f4f0 as a double
static const CGFloat kPhonePlateHeight = 24.0;
static const CGFloat kPadPlateHeight = 36.0; // @ghidraAddress 0x28f530

static const CGFloat kPhoneLabelY = 5.0;
static const CGFloat kPadLabelY = 8.0;
static const CGFloat kPhoneLabelHeight = 14.0;
static const CGFloat kPadLabelHeight = 20.0;
static const CGFloat kPhoneFontSize = 12.0;
static const CGFloat kPadFontSize = 18.0;

// The rank label's leading inset. Unlike everything else here it is the same on both idioms, and
// it is also the pad's badge inset, which is why the binary shares one register for the two.
static const CGFloat kLabelLeadingInset = 4.0;
// A gap of the same size sits between the rank and name labels and between the name and score.
static const int kLabelGap = 4;

static const CGFloat kPhoneBadgeInset = 2.0;
static const CGFloat kPadBadgeInset = 4.0;
static const int kPhoneBadgeSize = 20;
static const int kPadBadgeSize = 28;

static const int kPhoneBadgeDigitWidth = 4;
static const int kPadBadgeDigitWidth = 7;
static const CGFloat kPhoneBadgeDigitX = 16.0;
static const CGFloat kPadBadgeDigitX = 21.0;
static const CGFloat kPhoneBadgeDigitY = 12.0;
static const CGFloat kPadBadgeDigitY = 14.0;
static const CGFloat kPhoneBadgeDigitHeight = 8.0;
static const CGFloat kPadBadgeDigitHeight = 14.0;

enum { kBadgeDigitCount = 2 };

@implementation ChallengeRankingListViewCell {
    UIImageView *bgImage;
    UILabel *rankLabel;
    UILabel *nameLabel;
    UILabel *scoreLabel;
    UIImageView *iconImageView;
    UIImageView *iconNumImageView[kBadgeDigitCount];
}

/** @ghidraAddress 0x153f88 */
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        BOOL isPad = JubeatAppDelegate.appDelegate.isPad;
        self.backgroundColor = UIColor.clearColor;

        int plateWidth = isPad ? kPadPlateWidth : kPhonePlateWidth;
        CGFloat labelY = isPad ? kPadLabelY : kPhoneLabelY;
        CGFloat labelHeight = isPad ? kPadLabelHeight : kPhoneLabelHeight;
        CGFloat fontSize = isPad ? kPadFontSize : kPhoneFontSize;

        bgImage = [[UIImageView alloc]
            initWithFrame:CGRectMake(
                              0, 0, plateWidth, isPad ? kPadPlateHeight : kPhonePlateHeight)];
        [self addSubview:bgImage];

        // The row is divided a quarter, a half, a quarter — rank, name, score. Both divisions are
        // unsigned shifts of the plate's width, so an odd width loses a point or two to
        // truncation and the score label ends a little past the plate's trailing edge.
        int quarterWidth = (unsigned int)plateWidth >> 2;
        int halfWidth = (unsigned int)plateWidth >> 1;

        rankLabel = [[UILabel alloc]
            initWithFrame:CGRectMake(kLabelLeadingInset, labelY, quarterWidth, labelHeight)];
        rankLabel.textAlignment = NSTextAlignmentCenter;
        rankLabel.font = [UIFont systemFontOfSize:fontSize];
        [bgImage addSubview:rankLabel];

        nameLabel = [[UILabel alloc]
            initWithFrame:CGRectMake(quarterWidth + kLabelGap, labelY, halfWidth, labelHeight)];
        nameLabel.textAlignment = NSTextAlignmentCenter;
        nameLabel.font = [UIFont systemFontOfSize:fontSize];
        [bgImage addSubview:nameLabel];

        scoreLabel = [[UILabel alloc] initWithFrame:CGRectMake(halfWidth + quarterWidth + kLabelGap,
                                                               labelY,
                                                               quarterWidth,
                                                               labelHeight)];
        scoreLabel.textAlignment = NSTextAlignmentCenter;
        scoreLabel.font = [UIFont systemFontOfSize:fontSize];
        [bgImage addSubview:scoreLabel];

        CGFloat badgeInset = isPad ? kPadBadgeInset : kPhoneBadgeInset;
        int badgeSize = isPad ? kPadBadgeSize : kPhoneBadgeSize;
        iconImageView = [[UIImageView alloc]
            initWithFrame:CGRectMake(badgeInset, badgeInset, badgeSize, badgeSize)];
        // Explicitly cleared, though a fresh image view has no image anyway.
        iconImageView.image = nil;
        [bgImage addSubview:iconImageView];

        // The two digits abut and end flush with the badge's trailing edge: on the pad 21 + 7 = 28
        // and 14 + 7 = 21, on the phone 16 + 4 = 20 and 12 + 4 = 16. Slot 0 is therefore the
        // trailing digit and slot 1 the leading one, which is why -setRivalIcon:… takes them in
        // that order.
        int digitWidth = isPad ? kPadBadgeDigitWidth : kPhoneBadgeDigitWidth;
        CGFloat digitY = isPad ? kPadBadgeDigitY : kPhoneBadgeDigitY;
        CGFloat digitHeight = isPad ? kPadBadgeDigitHeight : kPhoneBadgeDigitHeight;

        iconNumImageView[0] = [[UIImageView alloc]
            initWithFrame:CGRectMake(isPad ? kPadBadgeDigitX : kPhoneBadgeDigitX,
                                     digitY,
                                     digitWidth,
                                     digitHeight)];
        [iconImageView addSubview:iconNumImageView[0]];

        iconNumImageView[1] = [[UIImageView alloc]
            initWithFrame:CGRectMake(badgeSize - digitWidth * 2, digitY, digitWidth, digitHeight)];
        [iconImageView addSubview:iconNumImageView[1]];
    }
    return self;
}

/** @ghidraAddress 0x1544d0 */
- (void)setRivalInfo:(UIImage *)rivalInfo
                rank:(NSString *)rank
                name:(NSString *)name
               score:(NSString *)score {
    BOOL isPad = JubeatAppDelegate.appDelegate.isPad;
    bgImage.image = rivalInfo;
    // Re-framed on every call, not just at construction.
    bgImage.frame = CGRectMake(0,
                               0,
                               isPad ? kPadPlateWidth : kPhonePlateWidth,
                               isPad ? kPadPlateHeight : kPhonePlateHeight);
    rankLabel.text = rank;
    nameLabel.text = name;
    scoreLabel.text = score;
}

/** @ghidraAddress 0x154648 */
- (void)setRivalIcon:(UIImage *)rivalIcon
         digit1Image:(UIImage *)digit1Image
         digit2Image:(UIImage *)digit2Image {
    iconImageView.image = rivalIcon;
    iconNumImageView[0].image = digit1Image;
    iconNumImageView[1].image = digit2Image;
}

@end
