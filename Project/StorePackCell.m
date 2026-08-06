#import "StorePackCell.h"

#import "ImageCache.h"
#import "PurchaseManager.h"
#import "StoreUtil.h"

// The artwork thumbnail, top-left, with a soft drop shadow.
static const CGFloat kArtworkX = 10.0;
static const CGFloat kArtworkY = 8.0;
static const CGFloat kArtworkSize = 64.0; // @ghidraAddress 0x28f1f0
static const CGFloat kArtworkShadowExtent = 1.0;
static const float kArtworkShadowOpacity = 0.6f; // @ghidraAddress 0x28f3b8

// The name and price share a left edge to the right of the artwork.
static const CGFloat kTextX = 85.0; // @ghidraAddress 0x28f760

// The pack name, on the first line.
static const CGFloat kNameY = 10.0;
static const CGFloat kNameWidthInset = -90.0; // @ghidraAddress 0x2923e0
static const CGFloat kNameHeight = 20.0;
static const CGFloat kNameFontSize = 16.0;
static const CGFloat kNameMinimumScaleFactor = 0.8125;

// The price and the owned marker share the second line.
static const CGFloat kSecondLineY = 54.0; // @ghidraAddress 0x28f640
static const CGFloat kSecondLineHeight = 18.0;
static const CGFloat kPriceWidth = 120.0; // @ghidraAddress 0x28f210
static const CGFloat kPriceWhite = 0.3f;  // @ghidraAddress 0x28f248
static const CGFloat kPriceFontSize = 14.0;

static const CGFloat kPurchasedXInset = -110.0; // @ghidraAddress 0x2923e8
static const CGFloat kPurchasedWidth = 100.0;   // @ghidraAddress 0x28f3f0
static const CGFloat kPurchasedWhite = 0.4f;    // @ghidraAddress 0x28f2c0
static const CGFloat kPurchasedFontSize = 13.0;

// The extend marker hangs off the row's left edge, below the artwork.
static const CGFloat kExtendMarkerY = 52.0; // @ghidraAddress 0x28f220

static NSString *const kNewMarkerImageName = @"store_new";
static NSString *const kExtendMarkerImageName = @"store_pack_extend_ico";

@implementation StorePackCell {
    UIImageView *bgView;
    UILabel *labelName;
    UILabel *labelPrice;
    UILabel *labelPurchased;
    UIImageView *newMarker;
    UIImageView *extendMarker;
}

/** @ghidraAddress 0xf0e48 */
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

        // The background image is the cell's own backgroundView, not a subview, which is why
        // -setBgImage: reaches the whole row rather than a panel inside it.
        bgView = [[UIImageView alloc] initWithFrame:self.bounds];
        self.backgroundView = bgView;
        self.backgroundView.autoresizingMask =
            UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

        // Every horizontal measurement below is taken against the content view's width once, here.
        // The autoresizing masks are what keep the fixed offsets right when that width changes.
        CGFloat contentWidth = self.contentView.frame.size.width;

        _artworkView = [[UIImageView alloc]
            initWithFrame:CGRectMake(kArtworkX, kArtworkY, kArtworkSize, kArtworkSize)];
        _artworkView.layer.shadowOffset = CGSizeMake(kArtworkShadowExtent, kArtworkShadowExtent);
        _artworkView.layer.shadowColor = UIColor.blackColor.CGColor;
        _artworkView.layer.shadowOpacity = kArtworkShadowOpacity;
        _artworkView.layer.shadowRadius = kArtworkShadowExtent;
        _artworkView.layer.shouldRasterize = YES;

        labelName = [[UILabel alloc]
            initWithFrame:CGRectMake(kTextX, kNameY, contentWidth + kNameWidthInset, kNameHeight)];
        labelName.backgroundColor = UIColor.clearColor;
        labelName.highlightedTextColor = UIColor.whiteColor;
        labelName.font = [UIFont boldSystemFontOfSize:kNameFontSize];
        labelName.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        labelName.adjustsFontSizeToFitWidth = YES;
        labelName.minimumScaleFactor = kNameMinimumScaleFactor;

        labelPrice = [[UILabel alloc]
            initWithFrame:CGRectMake(kTextX, kSecondLineY, kPriceWidth, kSecondLineHeight)];
        labelPrice.backgroundColor = UIColor.clearColor;
        labelPrice.textColor = [UIColor colorWithWhite:kPriceWhite alpha:1.0];
        labelPrice.highlightedTextColor = UIColor.whiteColor;
        labelPrice.font = [UIFont boldSystemFontOfSize:kPriceFontSize];

        // The owned marker shares the price's line, pinned to the right instead of the left, which
        // is what the flexible left margin below preserves.
        labelPurchased = [[UILabel alloc] initWithFrame:CGRectMake(contentWidth + kPurchasedXInset,
                                                                   kSecondLineY,
                                                                   kPurchasedWidth,
                                                                   kSecondLineHeight)];
        labelPurchased.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        labelPurchased.backgroundColor = UIColor.clearColor;
        labelPurchased.textColor = [UIColor colorWithWhite:kPurchasedWhite alpha:1.0];
        labelPurchased.highlightedTextColor = UIColor.whiteColor;
        labelPurchased.font = [UIFont boldSystemFontOfSize:kPurchasedFontSize];
        labelPurchased.textAlignment = NSTextAlignmentRight;
        labelPurchased.text = NSLocalizedString(@"Purchased", nil);

        // The new marker keeps whatever frame -initWithImage: gives it: nothing sets one, so it
        // sits at the content view's origin at the image's natural size.
        newMarker = [[UIImageView alloc]
            initWithImage:[ImageCache.sharedCache getResPNG:kNewMarkerImageName]];

        UIImage *extendImage = [ImageCache.sharedCache getResPNG:kExtendMarkerImageName];
        extendMarker = [[UIImageView alloc] initWithImage:extendImage];
        extendMarker.frame =
            CGRectMake(0, kExtendMarkerY, extendImage.size.width, extendImage.size.height);

        // Six subviews go on the content view; bgView is not among them, being the backgroundView.
        // The name is added after the new marker, so the marker sits behind it.
        [self.contentView addSubview:_artworkView];
        [self.contentView addSubview:newMarker];
        [self.contentView addSubview:labelName];
        [self.contentView addSubview:labelPrice];
        [self.contentView addSubview:labelPurchased];
        [self.contentView addSubview:extendMarker];
    }
    return self;
}

/** @ghidraAddress 0xf1878 */
- (BOOL)isPurchased {
    return !labelPurchased.hidden;
}

/** @ghidraAddress 0xf18a4 */
- (void)setIsPurchased:(BOOL)isPurchased {
    labelPurchased.hidden = !isPurchased;
}

/** @ghidraAddress 0xf18c0 */
- (void)loadPackInfo:(StorePackInfo *)packInfo {
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
    // The label is hidden directly rather than through self.isPurchased, which would do the same
    // thing. The setter exists and this method does not use it.
    labelPurchased.hidden = !owned;
}

/** @ghidraAddress 0xf1ad4 */
- (void)setBgImage:(UIImage *)bgImg {
    bgView.image = bgImg;
}

@end
