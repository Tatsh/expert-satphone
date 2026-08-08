#import "StoreCampaignTableViewCell.h"

#import <QuartzCore/QuartzCore.h>

#import "ImageCache.h"

// The campaign info object exposes its identifier; a CampaignItemInfo not reconstructed as its own
// file yet, and the tap delegate is a StoreCampaignViewController with -selectItem:. See
// TYPES_PENDING.md.
@interface NSObject (StoreCampaignItem)
- (int)campaignID;
- (void)selectItem:(int)tag;
@end

@interface StoreCampaignTableViewCell ()
- (CGSize)getArtworkMargin:(BOOL)isPad;
- (CGSize)getItemSize:(BOOL)isPad;
@end

// The cell background art and its uniform resizable cap inset.
static NSString *const kCampaignBackgroundImageName = @"store_pack_bg_0";
static const CGFloat kCampaignBackgroundCapInset = 4.0;

// The row height by idiom.
static const CGFloat kCampaignCellHeightPad = 180.0;  // @ghidraAddress 0x291bd0
static const CGFloat kCampaignCellHeightPhone = 80.0; // @ghidraAddress 0x28f3f8

// The artwork margins by idiom (x, y).
static const CGFloat kCampaignMarginXPad = 12.0;
static const CGFloat kCampaignMarginXPhone = 8.0;
static const CGFloat kCampaignMarginYPad = 10.0;
static const CGFloat kCampaignMarginYPhone = 6.0;

// The item (background banner) size by idiom.
static const CGFloat kCampaignItemWidthPad = 640.0;   // @ghidraAddress 0x291d80
static const CGFloat kCampaignItemWidthPhone = 320.0; // @ghidraAddress 0x28f470
static const CGFloat kCampaignItemHeightPad = 160.0;  // @ghidraAddress 0x28f438
static const CGFloat kCampaignItemHeightPhone = 80.0; // @ghidraAddress 0x28f3f8

// The artwork square size by idiom, and the phone-only upward nudge of its y.
static const CGFloat kCampaignArtworkSizePad = 100.0;  // @ghidraAddress 0x28f3f0
static const CGFloat kCampaignArtworkSizePhone = 64.0; // @ghidraAddress 0x28f1f0
static const int kCampaignArtworkYNudgePhone = 2;

// The pad-only background corner radius.
static const CGFloat kCampaignPadCornerRadius = 5.0;

// The artwork's drop shadow.
static const CGFloat kCampaignShadowOffset = 1.0;
static const float kCampaignShadowOpacity = 0.6f; // @ghidraAddress 0x28f3b8
static const CGFloat kCampaignShadowRadius = 1.0;

// The half-scale used to centre the background banner in the cell.
static const CGFloat kCampaignHalf = 0.5;

// The cell is created with the subtitle style, matching the binary's initWithStyle: argument 3.
static const UITableViewCellStyle kCampaignCellStyle = UITableViewCellStyleSubtitle;

@implementation StoreCampaignTableViewCell {
    int _campaignID; // +0x8
    // _artworkView at +0x10 and _ctrlDelegate (weak) at +0x18 are synthesised.
}

@synthesize artworkView = _artworkView;
@synthesize ctrlDelegate = _ctrlDelegate;
@synthesize campaignID = _campaignID;

#pragma mark - Metrics

/** @ghidraAddress 0xcb700 */
+ (CGFloat)cellHeight:(BOOL)isPad {
    return isPad ? kCampaignCellHeightPad : kCampaignCellHeightPhone;
}

/** @ghidraAddress 0xcb71c */
- (CGSize)getArtworkMargin:(BOOL)isPad {
    return CGSizeMake(isPad ? kCampaignMarginXPad : kCampaignMarginXPhone,
                      isPad ? kCampaignMarginYPad : kCampaignMarginYPhone);
}

/** @ghidraAddress 0xcb73c */
- (CGSize)getItemSize:(BOOL)isPad {
    return CGSizeMake(isPad ? kCampaignItemWidthPad : kCampaignItemWidthPhone,
                      isPad ? kCampaignItemHeightPad : kCampaignItemHeightPhone);
}

#pragma mark - Construction

/** @ghidraAddress 0xcb09c */
- (instancetype)initWithDeviceType:(BOOL)isPad
                   reuseIdentifier:(NSString *)reuseIdentifier
                               tag:(int)tag {
    self = [super initWithStyle:kCampaignCellStyle reuseIdentifier:reuseIdentifier];
    if (!self) {
        return nil;
    }
    self.tag = tag;

    CGSize margin = [self getArtworkMargin:isPad];
    CGSize itemSize = [self getItemSize:isPad];
    CGFloat screenWidth = UIScreen.mainScreen.bounds.size.width;
    CGFloat cellHeight = [StoreCampaignTableViewCell cellHeight:isPad];

    // The stretchable banner background, centred in the cell.
    UIImage *bgImage = [[ImageCache.sharedCache
        getResPNG:[NSString stringWithFormat:@"%@", kCampaignBackgroundImageName]]
        resizableImageWithCapInsets:UIEdgeInsetsMake(kCampaignBackgroundCapInset,
                                                     kCampaignBackgroundCapInset,
                                                     kCampaignBackgroundCapInset,
                                                     kCampaignBackgroundCapInset)];
    UIImageView *bgView = [[UIImageView alloc]
        initWithFrame:CGRectMake((int)((screenWidth - itemSize.width) * kCampaignHalf),
                                 (int)((cellHeight - itemSize.height) * kCampaignHalf),
                                 itemSize.width,
                                 itemSize.height)];
    bgView.image = bgImage;
    if (isPad) {
        bgView.layer.cornerRadius = kCampaignPadCornerRadius;
        bgView.clipsToBounds = YES;
    }
    [self addSubview:bgView];

    // The artwork square sits at the banner's left margin, nudged up by two points on the phone.
    CGFloat artworkSize = isPad ? kCampaignArtworkSizePad : kCampaignArtworkSizePhone;
    int yNudge = isPad ? 0 : kCampaignArtworkYNudgePhone;
    self.artworkView = [[StoreImageView alloc] initWithFrame:CGRectMake((int)margin.width,
                                                                        (int)margin.height - yNudge,
                                                                        artworkSize,
                                                                        artworkSize)];
    self.artworkView.image = nil;
    self.artworkView.layer.shadowOffset = CGSizeMake(kCampaignShadowOffset, kCampaignShadowOffset);
    self.artworkView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.artworkView.layer.shadowOpacity = kCampaignShadowOpacity;
    self.artworkView.layer.shadowRadius = kCampaignShadowRadius;
    self.artworkView.layer.shouldRasterize = YES;
    self.artworkView.alpha = 0;
    self.artworkView.userInteractionEnabled = YES;
    self.artworkView.exclusiveTouch = YES;
    [bgView addSubview:self.artworkView];
    return self;
}

#pragma mark - Content

/** @ghidraAddress 0xcb694 */
- (void)setInfo:(id)info tag:(int)tag {
    self.tag = tag;
    if (info) {
        _campaignID = [info campaignID];
    }
}

#pragma mark - Touch

/** @ghidraAddress 0xcb76c */
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [self.ctrlDelegate selectItem:(int)self.tag];
}

@end
