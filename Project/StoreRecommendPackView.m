#import "StoreRecommendPackView.h"

#import "ImageCache.h"
#import "PurchaseManager.h"
#import "StoreUtil.h"

// The artwork thumbnail: a square inset equally from the tile's top-left corner.
static const CGFloat kArtworkInset = 12.0;
static const CGFloat kArtworkSize = 100.0;           // @ghidraAddress 0x28f3f0
static const CGFloat kArtworkBackgroundAlpha = 0.3f; // @ghidraAddress 0x28f248
static const CGFloat kArtworkShadowExtent = 1.0;
static const float kArtworkShadowOpacity = 0.7f; // @ghidraAddress 0x28f3bc

// The pack name, to the right of the artwork.
static const CGFloat kNameX = 125.0; // @ghidraAddress 0x291d60
static const CGFloat kNameY = 8.0;
static const CGFloat kNameWidthInset = -130.0; // @ghidraAddress 0x291d58
static const CGFloat kNameHeight = 40.0;       // @ghidraAddress 0x28f1f8
static const CGFloat kNameFontSize = 16.0;
static const CGFloat kNameMinimumScaleFactor = 0.6875;

// The "Purchased" badge. It is laid out twice: once at a nominal size, then again from the size
// -sizeToFit gives it, pinned to the tile's bottom-right corner.
static const CGFloat kPurchasedNominalWidth = 100.0; // @ghidraAddress 0x28f3f0
static const CGFloat kPurchasedNominalHeight = 20.0;
static const CGFloat kPurchasedBackgroundRed = 0.27f; // @ghidraAddress 0x291d68
static const CGFloat kPurchasedBackgroundBlue = 0.6f; // @ghidraAddress 0x28f230
static const CGFloat kPurchasedCornerRadius = 4.0;
static const CGFloat kPurchasedFontSize = 14.0;
static const CGFloat kPurchasedPaddingX = 10.0;
static const CGFloat kPurchasedPaddingY = 4.0;
static const CGFloat kPurchasedRightMargin = 15.0;
static const CGFloat kPurchasedBottomMargin = 8.0;

// The description, below the name and above the price row.
static const CGFloat kCommentX = 130.0;           // @ghidraAddress 0x28fa38
static const CGFloat kCommentY = 32.0;            // @ghidraAddress 0x28f458
static const CGFloat kCommentWidthInset = -140.0; // @ghidraAddress 0x291d70
static const CGFloat kCommentHeightInset = -34.0; // @ghidraAddress 0x291d78
static const CGFloat kCommentFontSize = 12.0;

// The price, sharing the badge's row on the left.
static const CGFloat kPriceWidth = 150.0; // @ghidraAddress 0x28f790
static const CGFloat kPriceFontSize = 15.0;

// The extend marker sits one point up from the background's bottom edge.
static const CGFloat kExtendMarkerBottomMargin = 1.0;

static NSString *const kNewMarkerImageName = @"store_new";
static NSString *const kExtendMarkerImageName = @"store_pack_extend_ico";

@implementation StoreRecommendPackView {
    UIImageView *bgView;
    UILabel *labelName;
    UILabel *labelPurchased;
    UILabel *labelComment;
    UILabel *labelPrice;
    UIImageView *newMarker;
    UIImageView *extendMarker;
}

/** @ghidraAddress 0x1449fc */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // The background fills the tile, and it — not the tile — carries the tap recogniser.
        bgView = [[UIImageView alloc] initWithFrame:self.bounds];
        bgView.userInteractionEnabled = YES;
        bgView.exclusiveTouch = YES;
        [bgView addGestureRecognizer:[[UITapGestureRecognizer alloc]
                                         initWithTarget:self
                                                 action:@selector(handleTap:)]];

        self.artworkView = [[UIImageView alloc]
            initWithFrame:CGRectMake(kArtworkInset, kArtworkInset, kArtworkSize, kArtworkSize)];
        self.artworkView.contentMode = UIViewContentModeScaleAspectFit;
        self.artworkView.opaque = NO;
        self.artworkView.backgroundColor = [UIColor colorWithWhite:0 alpha:kArtworkBackgroundAlpha];
        self.artworkView.layer.shadowOffset =
            CGSizeMake(kArtworkShadowExtent, kArtworkShadowExtent);
        self.artworkView.layer.shadowColor = UIColor.blackColor.CGColor;
        self.artworkView.layer.shadowOpacity = kArtworkShadowOpacity;
        self.artworkView.layer.shadowRadius = kArtworkShadowExtent;
        self.artworkView.layer.shouldRasterize = YES;

        labelName =
            [[UILabel alloc] initWithFrame:CGRectMake(kNameX,
                                                      kNameY,
                                                      self.frame.size.width + kNameWidthInset,
                                                      kNameHeight)];
        labelName.numberOfLines = 2;
        labelName.lineBreakMode = NSLineBreakByWordWrapping;
        labelName.backgroundColor = UIColor.clearColor;
        labelName.font = [UIFont boldSystemFontOfSize:kNameFontSize];
        labelName.adjustsFontSizeToFitWidth = YES;
        labelName.minimumScaleFactor = kNameMinimumScaleFactor;

        labelPurchased = [[UILabel alloc]
            initWithFrame:CGRectMake(0, 0, kPurchasedNominalWidth, kPurchasedNominalHeight)];
        labelPurchased.backgroundColor = [UIColor colorWithRed:kPurchasedBackgroundRed
                                                         green:0
                                                          blue:kPurchasedBackgroundBlue
                                                         alpha:1.0];
        labelPurchased.clipsToBounds = YES;
        labelPurchased.layer.cornerRadius = kPurchasedCornerRadius;
        labelPurchased.textColor = UIColor.whiteColor;
        labelPurchased.font = [UIFont boldSystemFontOfSize:kPurchasedFontSize];
        labelPurchased.textAlignment = NSTextAlignmentCenter;
        labelPurchased.text = NSLocalizedString(@"Purchased", nil);
        [labelPurchased sizeToFit];

        // The nominal frame above only existed to give -sizeToFit something to shrink. The real
        // one is the fitted text plus padding, pinned to the tile's bottom-right corner.
        CGFloat badgeWidth = labelPurchased.frame.size.width + kPurchasedPaddingX;
        CGFloat badgeHeight = labelPurchased.frame.size.height + kPurchasedPaddingY;
        CGFloat badgeX = self.frame.size.width - badgeWidth - kPurchasedRightMargin;
        CGFloat badgeY = self.frame.size.height - badgeHeight - kPurchasedBottomMargin;
        labelPurchased.frame = CGRectMake(badgeX, badgeY, badgeWidth, badgeHeight);

        // The comment's height is measured down to the badge's row rather than given outright, so
        // it grows and shrinks with the badge. Its top, 32, sits inside the name's 8..48 box: a
        // two-line name overlaps it, and since the comment is added later it draws on top.
        labelComment =
            [[UILabel alloc] initWithFrame:CGRectMake(kCommentX,
                                                      kCommentY,
                                                      self.frame.size.width + kCommentWidthInset,
                                                      badgeY + kCommentHeightInset)];
        labelComment.backgroundColor = UIColor.clearColor;
        labelComment.font = [UIFont systemFontOfSize:kCommentFontSize];
        labelComment.lineBreakMode = NSLineBreakByClipping;
        labelComment.baselineAdjustment = UIBaselineAdjustmentAlignBaselines;
        labelComment.numberOfLines = 0;

        // The price shares the badge's row, on the left.
        labelPrice =
            [[UILabel alloc] initWithFrame:CGRectMake(kNameX, badgeY, kPriceWidth, badgeHeight)];
        labelPrice.backgroundColor = UIColor.clearColor;
        labelPrice.font = [UIFont boldSystemFontOfSize:kPriceFontSize];

        // The new marker keeps whatever frame -initWithImage: gives it: nothing sets one, so it
        // sits at the tile's origin at the image's natural size.
        newMarker = [[UIImageView alloc]
            initWithImage:[ImageCache.sharedCache getResPNG:kNewMarkerImageName]];

        UIImage *extendImage = [ImageCache.sharedCache getResPNG:kExtendMarkerImageName];
        extendMarker = [[UIImageView alloc] initWithImage:extendImage];
        extendMarker.frame = CGRectMake(0,
                                        bgView.frame.size.height - extendImage.size.height -
                                            kExtendMarkerBottomMargin,
                                        extendImage.size.width,
                                        extendImage.size.height);

        // The order matters: the comment is added after the name, and the badge after the price.
        [self addSubview:bgView];
        [self addSubview:self.artworkView];
        [self addSubview:labelName];
        [self addSubview:labelComment];
        [self addSubview:labelPrice];
        [self addSubview:labelPurchased];
        [self addSubview:newMarker];
        [self addSubview:extendMarker];
    }
    return self;
}

/** @ghidraAddress 0x145638 */
- (void)setBgImage:(UIImage *)bgImg {
    bgView.image = bgImg;
}

/** @ghidraAddress 0x145704 */
- (void)loadPackInfo:(StorePackInfo *)packInfo index:(NSUInteger)index {
    labelName.text = packInfo.packName;
    newMarker.hidden = !packInfo.isNew;
    extendMarker.hidden = !packInfo.hasExtend;
    labelPrice.attributedText = packInfo.attributedPriceString;

    NSString *productID = [StoreUtil productIDForPackID:packInfo.packID];
    // A pending purchase counts as owned for display. The manager is fetched afresh for each
    // question rather than held, and the second is only asked when the first says no.
    BOOL owned = [PurchaseManager.sharedManager isPurchased:productID];
    if (!owned) {
        owned = [PurchaseManager.sharedManager isPending:productID];
    }
    labelPurchased.hidden = !owned;

    _index = index;
    // Note labelComment is left untouched here: nothing in this method writes it.
}

/** @ghidraAddress 0x145650 */
- (void)handleTap:(id)sender {
    // Yes, sender is unused: the delegate is handed the tile rather than the recogniser. The
    // delegate is loaded from the weak slot twice, once to test and once to send to.
    if ([self.delegate respondsToSelector:@selector(storePackViewSelected:)]) {
        [self.delegate performSelector:@selector(storePackViewSelected:) withObject:self];
    }
}

@end
