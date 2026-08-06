#import "ChallengeLineupViewCell.h"

#import "ImageLoading.h"
#import "JubeatAppDelegate.h"

// The store button's artwork, from the CFString at 0x2dd840.
static NSString *const kStoreButtonImageName = @"menu_button_store_ch";

// Row metrics. The same figures and the same pool slots ChallengePrevRankingListViewCell uses.
static const CGFloat kPhonePlateWidth = 309.0; // @ghidraAddress 0x28f8e8
static const CGFloat kPadPlateWidth = 460.0;   // @ghidraAddress 0x28f4f0
static const int kPhoneRowHeight = 44;
static const int kPadRowHeight = 88;
static const int kPhoneArtworkInset = 2;
static const int kPadArtworkInset = 4;
static const int kPhoneArtworkSize = 40;
static const int kPadArtworkSize = 80;

// The row's width less the artwork; the label takes this less three insets, and on the pad less
// the store button's width as well.
static const int kPhoneNameWidthAllowance = 269;
static const int kPadNameWidthAllowance = 380;

static const CGFloat kNameLabelHeight = 20.0;
static const int kNameLabelRiseAboveMiddle = 10;

static const CGFloat kPhoneFontSize = 14.0;
static const CGFloat kPadFontSize = 17.0;

@implementation ChallengeLineupViewCell {
    UIButton *storeBtn;
    UIImageView *bgImage;
    UIImageView *artworkImage;
    UILabel *nameLabel;
}

/** @ghidraAddress 0x145a60 */
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        BOOL isPad = JubeatAppDelegate.appDelegate.isPad;
        self.backgroundColor = UIColor.clearColor;

        int rowHeight = isPad ? kPadRowHeight : kPhoneRowHeight;
        int artworkSize = isPad ? kPadArtworkSize : kPhoneArtworkSize;
        int artworkInset = isPad ? kPadArtworkInset : kPhoneArtworkInset;

        // The store button is a pad-only feature. On the phone it is never created, stays nil, and
        // the label below reclaims the width it would have taken.
        int storeButtonWidth = 0;
        if (isPad) {
            UIImage *storeImage = LoadScaledPngImage(kStoreButtonImageName);
            storeButtonWidth = (int)storeImage.size.width;

            storeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            [storeBtn setImage:storeImage forState:UIControlStateNormal];
            [storeBtn addTarget:self
                          action:@selector(tapStoreMove)
                forControlEvents:UIControlEventTouchUpInside];
            // Pinned to the plate's trailing edge and vertically centred in the row.
            storeBtn.frame = CGRectMake(kPadPlateWidth - storeImage.size.width,
                                        (rowHeight - storeImage.size.height) / 2,
                                        storeImage.size.width,
                                        storeImage.size.height);
            storeBtn.exclusiveTouch = YES;
        }

        bgImage = [[UIImageView alloc]
            initWithFrame:CGRectMake(0, 0, isPad ? kPadPlateWidth : kPhonePlateWidth, rowHeight)];
        [self addSubview:bgImage];

        artworkImage = [[UIImageView alloc]
            initWithFrame:CGRectMake(artworkInset, artworkInset, artworkSize, artworkSize)];
        [bgImage addSubview:artworkImage];

        // Inset plus width leaves exactly one inset before the plate's trailing edge on the phone,
        // and one inset before the store button's leading edge on the pad.
        int nameWidthAllowance = isPad ? kPadNameWidthAllowance : kPhoneNameWidthAllowance;
        nameLabel = [[UILabel alloc]
            initWithFrame:CGRectMake(artworkSize + artworkInset * 2,
                                     rowHeight / 2 - kNameLabelRiseAboveMiddle,
                                     nameWidthAllowance - artworkInset * 3 - storeButtonWidth,
                                     kNameLabelHeight)];
        nameLabel.font = [UIFont systemFontOfSize:(isPad ? kPadFontSize : kPhoneFontSize)];
        [bgImage addSubview:nameLabel];

        // Sent unconditionally. On the phone this is -addSubview:nil, which does nothing.
        [self addSubview:storeBtn];
    }
    return self;
}

/** @ghidraAddress 0x145e74 */
- (void)setLineupCell:(UIImage *)lineupCell
                 name:(NSString *)name
                bgImg:(UIImage *)bgImg
            storeType:(int)storeType {
    bgImage.image = bgImg;
    artworkImage.image = lineupCell;
    nameLabel.text = name;

    if (storeType == ChallengeLineupStoreTypeOwned) {
        storeBtn.hidden = NO;
        storeBtn.enabled = NO;
    } else if (storeType == ChallengeLineupStoreTypeAvailable) {
        storeBtn.hidden = NO;
        storeBtn.enabled = YES;
    } else {
        // Any other value hides the button and leaves its enabled state as it was.
        storeBtn.hidden = YES;
    }
}

/** @ghidraAddress 0x145fa8 */
- (void)tapStoreMove {
    // The delegate is loaded from the weak slot three times: once for the nil test, once for
    // -respondsToSelector:, and once to send. The other cells in this tree do only the last two.
    if (self.aDelegate == nil) {
        return;
    }
    if ([self.aDelegate respondsToSelector:@selector(tapStoreBtn:)]) {
        [self.aDelegate performSelector:@selector(tapStoreBtn:) withObject:self];
    }
}

@end
