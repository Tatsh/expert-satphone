#import "StorePackView.h"

#import <QuartzCore/QuartzCore.h>

#import "ImageCache.h"
#import "PurchaseManager.h"
#import "StoreUtil.h"

// The artwork thumbnail's fixed frame; the pooled double at 0x28f3f0 sizes both axes.
static const CGFloat kPackArtworkOrigin = 12.0;
static const CGFloat kPackArtworkSize = 100.0; // @ghidraAddress 0x28f3f0

// The artwork's dimming background alpha and drop-shadow settings.
static const CGFloat kPackArtworkBackgroundAlpha = 0.3; // @ghidraAddress 0x28f248
static const CGFloat kPackArtworkShadowOffset = 1.0;
static const float kPackArtworkShadowOpacity = 0.7f; // @ghidraAddress 0x28f3bc
static const CGFloat kPackArtworkShadowRadius = 1.0;

// The name label's layout: inset to the right of the artwork, fixed origin and height, its width
// shrinking with the tile. From the pooled doubles at 0x291d60 (x) and 0x291d58 (width delta).
static const CGFloat kPackNameLabelX = 125.0; // @ghidraAddress 0x291d60
static const CGFloat kPackNameLabelY = 8.0;
static const CGFloat kPackNameLabelWidthDelta = -130.0; // @ghidraAddress 0x291d58
static const CGFloat kPackNameLabelHeight = 20.0;
static const CGFloat kPackNameFontSize = 16.0;
static const CGFloat kPackNameMinimumScaleFactor = 0.6875;

// The purchased badge's colour (0.27, 0, 0.6 at 60% alpha), corner radius, font, and the paddings
// added around its fitted text.
static const CGFloat kPackPurchasedRed = 0.27; // @ghidraAddress 0x291d68
static const CGFloat kPackPurchasedBlue = 0.6;
static const CGFloat kPackPurchasedAlpha = 0.6; // @ghidraAddress 0x28f230
static const CGFloat kPackPurchasedCornerRadius = 4.0;
static const CGFloat kPackPurchasedFontSize = 14.0;
static const CGFloat kPackPurchasedPadX = 10.0;
static const CGFloat kPackPurchasedPadY = 4.0;
static const CGFloat kPackPurchasedInsetRight = -15.0;
static const CGFloat kPackPurchasedInsetBottom = -8.0;

// The comment label's layout: fixed origin, its width and height shrinking with the tile and the
// purchased badge. From the pooled doubles at 0x28fa38 (x), 0x28f458 (y), 0x291d70 (width delta),
// and 0x291d78 (height delta).
static const CGFloat kPackCommentLabelX = 130.0;           // @ghidraAddress 0x28fa38
static const CGFloat kPackCommentLabelY = 32.0;            // @ghidraAddress 0x28f458
static const CGFloat kPackCommentLabelWidthDelta = -140.0; // @ghidraAddress 0x291d70
static const CGFloat kPackCommentLabelHeightDelta = -34.0; // @ghidraAddress 0x291d78
static const CGFloat kPackCommentFontSize = 12.0;

// The price label's layout: aligned under the name, width fixed. From the pooled double at
// 0x28f790.
static const CGFloat kPackPriceLabelWidth = 150.0; // @ghidraAddress 0x28f790
static const CGFloat kPackPriceFontSize = 15.0;

// The extend marker is pushed left of the balloon's right edge by this much.
static const CGFloat kPackExtendMarkerRightInset = -1.0;

// The two status-marker image names.
static NSString *const kPackNewMarkerImageName = @"store_new";
static NSString *const kPackExtendMarkerImageName = @"store_pack_extend_ico";

// The selector the delegate is messaged with, and the localised purchased-badge title key.
static NSString *const kPackPurchasedLabelKey = @"Purchased";

@implementation StorePackView {
    UIImageView *bgView;       // +0x08
    UILabel *labelName;        // +0x10
    UILabel *labelComment;     // +0x18
    UILabel *labelPrice;       // +0x20
    UILabel *labelPurchased;   // +0x28
    UIImageView *newMarker;    // +0x30
    UIImageView *extendMarker; // +0x38
    // _index at +0x40, _artworkView at +0x48, _delegate (weak) at +0x50 are synthesised.
}

@synthesize index = _index;
@synthesize artworkView = _artworkView;
@synthesize delegate = _delegate;

#pragma mark - Construction

/** @ghidraAddress 0xc9dd0 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }

    // The background image view fills the tile and is the only interactive subview; the tap
    // recogniser lives on it.
    bgView = [[UIImageView alloc] initWithFrame:self.bounds];
    bgView.userInteractionEnabled = YES;
    bgView.exclusiveTouch = YES;
    [bgView
        addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self
                                                                     action:@selector(handleTap:)]];

    // The artwork thumbnail: a dimmed, aspect-fit square with a soft drop shadow, rasterised.
    self.artworkView = [[UIImageView alloc] initWithFrame:CGRectMake(kPackArtworkOrigin,
                                                                     kPackArtworkOrigin,
                                                                     kPackArtworkSize,
                                                                     kPackArtworkSize)];
    self.artworkView.contentMode = UIViewContentModeScaleAspectFit;
    self.artworkView.opaque = NO;
    self.artworkView.backgroundColor = [UIColor colorWithWhite:0 alpha:kPackArtworkBackgroundAlpha];
    self.artworkView.layer.shadowOffset =
        CGSizeMake(kPackArtworkShadowOffset, kPackArtworkShadowOffset);
    self.artworkView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.artworkView.layer.shadowOpacity = kPackArtworkShadowOpacity;
    self.artworkView.layer.shadowRadius = kPackArtworkShadowRadius;
    self.artworkView.layer.shouldRasterize = YES;

    CGFloat tileWidth = self.frame.size.width;
    CGFloat tileHeight = self.frame.size.height;

    // The name label sits to the right of the artwork and scales its font down to fit.
    labelName = [[UILabel alloc] initWithFrame:CGRectMake(kPackNameLabelX,
                                                          kPackNameLabelY,
                                                          tileWidth + kPackNameLabelWidthDelta,
                                                          kPackNameLabelHeight)];
    labelName.backgroundColor = UIColor.clearColor;
    labelName.font = [UIFont boldSystemFontOfSize:kPackNameFontSize];
    labelName.adjustsFontSizeToFitWidth = YES;
    labelName.minimumScaleFactor = kPackNameMinimumScaleFactor;

    // The purchased badge is sized to its fitted text plus padding, then pinned to the tile's
    // bottom-right corner.
    labelPurchased =
        [[UILabel alloc] initWithFrame:CGRectMake(0, 0, kPackArtworkSize, kPackNameLabelHeight)];
    labelPurchased.backgroundColor = [UIColor colorWithRed:kPackPurchasedRed
                                                     green:0
                                                      blue:kPackPurchasedBlue
                                                     alpha:kPackPurchasedAlpha];
    labelPurchased.clipsToBounds = YES;
    labelPurchased.layer.cornerRadius = kPackPurchasedCornerRadius;
    labelPurchased.textColor = UIColor.whiteColor;
    labelPurchased.font = [UIFont boldSystemFontOfSize:kPackPurchasedFontSize];
    labelPurchased.textAlignment = NSTextAlignmentCenter;
    labelPurchased.text = [NSBundle.mainBundle localizedStringForKey:kPackPurchasedLabelKey
                                                               value:@""
                                                               table:nil];
    [labelPurchased sizeToFit];
    CGFloat purchasedWidth = labelPurchased.frame.size.width + kPackPurchasedPadX;
    CGFloat purchasedHeight = labelPurchased.frame.size.height + kPackPurchasedPadY;
    CGFloat purchasedX = (tileWidth - purchasedWidth) + kPackPurchasedInsetRight;
    CGFloat purchasedY = (tileHeight - purchasedHeight) + kPackPurchasedInsetBottom;
    labelPurchased.frame = CGRectMake(purchasedX, purchasedY, purchasedWidth, purchasedHeight);

    // The comment label runs along the tile below the name, shrinking with the tile and the badge.
    labelComment =
        [[UILabel alloc] initWithFrame:CGRectMake(kPackCommentLabelX,
                                                  kPackCommentLabelY,
                                                  tileWidth + kPackCommentLabelWidthDelta,
                                                  purchasedY + kPackCommentLabelHeightDelta)];
    labelComment.backgroundColor = UIColor.clearColor;
    labelComment.font = [UIFont systemFontOfSize:kPackCommentFontSize];
    labelComment.lineBreakMode = NSLineBreakByTruncatingTail;
    labelComment.baselineAdjustment = UIBaselineAdjustmentAlignBaselines;
    labelComment.numberOfLines = 0;

    // The price label aligns under the name at the badge's vertical band.
    labelPrice = [[UILabel alloc]
        initWithFrame:CGRectMake(
                          kPackNameLabelX, purchasedY, kPackPriceLabelWidth, purchasedHeight)];
    labelPrice.backgroundColor = UIColor.clearColor;
    labelPrice.font = [UIFont boldSystemFontOfSize:kPackPriceFontSize];

    // The "new" marker keeps its image's natural size at the origin.
    UIImage *newImage = [ImageCache.sharedCache getResPNG:kPackNewMarkerImageName];
    newMarker = [[UIImageView alloc] initWithImage:newImage];

    // The "extend" marker is pinned to the balloon's bottom-right, offset in by one point.
    UIImage *extendImage = [ImageCache.sharedCache getResPNG:kPackExtendMarkerImageName];
    extendMarker = [[UIImageView alloc] initWithImage:extendImage];
    CGFloat bgWidth = bgView.frame.size.width;
    extendMarker.frame =
        CGRectMake((bgWidth - extendImage.size.width) + kPackExtendMarkerRightInset,
                   0,
                   extendImage.size.width,
                   extendImage.size.height);

    [self addSubview:bgView];
    [self addSubview:self.artworkView];
    [self addSubview:labelName];
    [self addSubview:labelComment];
    [self addSubview:labelPrice];
    [self addSubview:labelPurchased];
    [self addSubview:newMarker];
    [self addSubview:extendMarker];
    return self;
}

#pragma mark - Content

/** @ghidraAddress 0xca9e4 */
- (void)setBgImage:(UIImage *)image {
    bgView.image = image;
}

/** @ghidraAddress 0xca9fc */
- (void)handleTap:(UITapGestureRecognizer *)recognizer {
    if ([self.delegate respondsToSelector:@selector(storePackViewSelected:)]) {
        [self.delegate performSelector:@selector(storePackViewSelected:) withObject:self];
    }
}

/** @ghidraAddress 0xcaab0 */
- (void)loadPackInfo:(StorePackInfo *)packInfo index:(NSUInteger)index {
    labelName.text = packInfo.packName;
    labelComment.text = packInfo.shortComment;
    newMarker.hidden = !packInfo.isNew;
    extendMarker.hidden = !packInfo.hasExtend;
    labelPrice.attributedText = packInfo.attributedPriceString;

    // The purchased badge shows when the pack is owned or a purchase is pending.
    NSString *productID = [StoreUtil productIDForPackID:packInfo.packID];
    BOOL owned = [PurchaseManager.sharedManager isPurchased:productID];
    if (!owned) {
        owned = [PurchaseManager.sharedManager isPending:productID];
    }
    labelPurchased.hidden = !owned;
    _index = index;
}

@end
