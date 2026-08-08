#import "StoreDetailMusicCell.h"

#import "AlertViewManager.h"
#import "ImageCache.h"

// The fixed row height, the pooled double at 0x28f3f8. The same pool slot supplies the music
// title's left inset below, so both read 80.0.
static const CGFloat kMusicCellHeight = 80.0;

// The jacket geometry: an 8.0 inset (an fmov of 0x4020000000000000) on both axes and a 64.0 square
// (the pooled double at 0x28f1f0).
static const CGFloat kArtworkInset = 8.0;
static const CGFloat kArtworkSize = 64.0;

// The jacket's drop shadow. The offset and radius are an fmov of 0x3ff0000000000000 (1.0) and the
// opacity is the pooled float at 0x28f3b8, whose bit pattern 0x3f19999a is 0.6f.
static const CGFloat kArtworkShadowOffset = 1.0;
static const CGFloat kArtworkShadowRadius = 1.0;
static const CGFloat kArtworkShadowOpacity = 0.6f;

// The title and artist labels share a left inset (80.0, pooled at 0x28f3f8) and a width computed as
// the content width less 90.0 (the pooled double at 0x2923e0, stored negative and added). The title
// sits at y 8.0 (an fmov of 0x4020000000000000, the same register as the jacket inset), the artist
// at 26.0 (an fmov of 0x403a000000000000).
static const CGFloat kMusicLabelLeft = 80.0;
static const CGFloat kMusicLabelWidthInset = 90.0;
static const CGFloat kLabelNameTop = 8.0;
static const CGFloat kLabelNameHeight = 18.0;   // fmov 0x4032000000000000
static const CGFloat kLabelArtistTop = 26.0;    // fmov 0x403a000000000000
static const CGFloat kLabelArtistHeight = 15.0; // fmov 0x402e000000000000

// The levels label's fixed frame: pooled doubles at 0x28fa40 (82.0), 0x28f258 (60.0), and 0x28f5e8
// (110.0), with an fmov of 0x402c000000000000 (14.0) for the height.
static const CGFloat kLabelLevelsLeft = 82.0;
static const CGFloat kLabelLevelsTop = 60.0;
static const CGFloat kLabelLevelsWidth = 110.0;
static const CGFloat kLabelLevelsHeight = 14.0;

// Label font sizes: the title is 15.0 (fmov 0x402e000000000000), the artist and levels 12.0
// (fmov 0x4028000000000000).
static const CGFloat kLabelNameFontSize = 15.0;
static const CGFloat kLabelArtistFontSize = 12.0;
static const CGFloat kLabelLevelsFontSize = 12.0;

// The link button is inset 10.0 (an fmov of 0xc024000000000000, -10.0, added) from the content's
// bottom-right corner and sized to its background image.
static const CGFloat kLinkButtonMargin = 10.0;

// The sample overlay's dimming alpha, the pooled double at 0x28f2c0 (0.4), and the 0.5 (fmov
// 0x3fe0000000000000) that halves the overlay's size to place its centre.
static const CGFloat kSampleDimAlpha = 0.4;
static const CGFloat kSampleCentreFraction = 0.5;

// The extend badge's top inset, the pooled double at 0x28f220 (52.0).
static const CGFloat kExtendImageTop = 52.0;

// Resource image names passed to -[ImageCache getResPNG:].
static NSString *const kJacketPlaceholderImageName = @"store_jacket_128";
static NSString *const kITunesButtonImageName = @"store_itunes";
static NSString *const kPlayBadgeImageName = @"store_play";
static NSString *const kExtendBadgeImageName = @"store_pack_extend_ico";

// Localisation keys.
static NSString *const kITunesConfirmTitleKey = @"Show in iTunes Store?";
static NSString *const kITunesConfirmMessageKey = @"iTunesStoreNoticeMsg";
static NSString *const kCancelKey = @"Cancel";
static NSString *const kOKKey = @"OK";

// The alert result key carrying the tapped button index, and the value that means OK.
static NSString *const kAlertButtonMessageKey = @"btnMessage";
static const int kAlertButtonMessageOK = 1;

@implementation StoreDetailMusicCell {
    UIImageView *bgView;
    UIView *sampleView;
    UIActivityIndicatorView *indicator;
    UIImageView *playingView;
    UIButton *buttonLink;
    NSURL *linkURL;
}

#pragma mark - Metrics

/** @ghidraAddress 0xfbebc */
+ (CGFloat)cellHeight {
    return kMusicCellHeight;
}

#pragma mark - Lifecycle

/** @ghidraAddress 0xfbec8 */
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self != nil) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        // The background image view is stored in the bgView ivar and installed as the cell's
        // backgroundView, then stretched with the cell.
        bgView = [[UIImageView alloc] initWithFrame:self.bounds];
        self.backgroundView = bgView;
        self.backgroundView.autoresizingMask =
            UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

        // The jacket artwork, a shadowed square in the top-left corner.
        self.artworkView = [[UIImageView alloc]
            initWithFrame:CGRectMake(kArtworkInset, kArtworkInset, kArtworkSize, kArtworkSize)];
        self.artworkView.image = [ImageCache.sharedCache getResPNG:kJacketPlaceholderImageName];
        self.artworkView.layer.shadowOffset =
            CGSizeMake(kArtworkShadowOffset, kArtworkShadowOffset);
        self.artworkView.layer.shadowColor = UIColor.blackColor.CGColor;
        self.artworkView.layer.shadowOpacity = kArtworkShadowOpacity;
        self.artworkView.layer.shadowRadius = kArtworkShadowRadius;
        self.artworkView.layer.shouldRasterize = YES;

        // The binary reads the content view's frame twice, once for the width and once for the
        // height; both feed the flexible label width and the link button's bottom-right placement.
        CGFloat contentWidth = CGRectGetWidth(self.contentView.frame);
        CGFloat contentHeight = CGRectGetHeight(self.contentView.frame);

        self.labelName =
            [[UILabel alloc] initWithFrame:CGRectMake(kMusicLabelLeft,
                                                      kLabelNameTop,
                                                      contentWidth - kMusicLabelWidthInset,
                                                      kLabelNameHeight)];
        self.labelName.backgroundColor = UIColor.clearColor;
        self.labelName.font = [UIFont boldSystemFontOfSize:kLabelNameFontSize];
        self.labelName.autoresizingMask = UIViewAutoresizingFlexibleWidth;

        self.labelArtist =
            [[UILabel alloc] initWithFrame:CGRectMake(kMusicLabelLeft,
                                                      kLabelArtistTop,
                                                      contentWidth - kMusicLabelWidthInset,
                                                      kLabelArtistHeight)];
        self.labelArtist.backgroundColor = UIColor.clearColor;
        self.labelArtist.font = [UIFont systemFontOfSize:kLabelArtistFontSize];
        self.labelArtist.autoresizingMask = UIViewAutoresizingFlexibleWidth;

        self.labelLevels = [[UILabel alloc] initWithFrame:CGRectMake(kLabelLevelsLeft,
                                                                     kLabelLevelsTop,
                                                                     kLabelLevelsWidth,
                                                                     kLabelLevelsHeight)];
        self.labelLevels.backgroundColor = UIColor.clearColor;
        self.labelLevels.font = [UIFont boldSystemFontOfSize:kLabelLevelsFontSize];

        // The iTunes link button, pinned to the content's bottom-right corner.
        buttonLink = [UIButton buttonWithType:UIButtonTypeCustom];
        buttonLink.exclusiveTouch = YES;
        UIImage *itunesImage = [ImageCache.sharedCache getResPNG:kITunesButtonImageName];
        CGSize itunesSize = itunesImage.size;
        buttonLink.frame = CGRectMake(contentWidth - itunesSize.width - kLinkButtonMargin,
                                      contentHeight - itunesSize.height - kLinkButtonMargin,
                                      itunesSize.width,
                                      itunesSize.height);
        buttonLink.autoresizingMask =
            UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
        [buttonLink setBackgroundImage:itunesImage forState:UIControlStateNormal];
        [buttonLink addTarget:self
                       action:@selector(handleLink:)
             forControlEvents:UIControlEventTouchUpInside];

        // The sample overlay covers the jacket and dims it, hosting the spinner and play badge.
        sampleView = [[UIView alloc] initWithFrame:self.artworkView.frame];
        sampleView.opaque = NO;
        sampleView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:kSampleDimAlpha];
        CGFloat sampleCentreX = CGRectGetWidth(sampleView.frame) * kSampleCentreFraction;
        CGFloat sampleCentreY = CGRectGetHeight(sampleView.frame) * kSampleCentreFraction;

        indicator = [[UIActivityIndicatorView alloc]
            initWithFrame:CGRectMake(0.0, 0.0, sampleCentreX, sampleCentreY)];
        indicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
        indicator.hidesWhenStopped = YES;
        indicator.center = CGPointMake(sampleCentreX, sampleCentreY);
        [sampleView addSubview:indicator];

        playingView = [[UIImageView alloc]
            initWithImage:[ImageCache.sharedCache getResPNG:kPlayBadgeImageName]];
        playingView.center = CGPointMake(sampleCentreX, sampleCentreY);
        playingView.hidden = YES;
        [sampleView addSubview:playingView];

        // The extend badge, sized to its image and added to the cell itself below.
        UIImage *extendImage = [ImageCache.sharedCache getResPNG:kExtendBadgeImageName];
        self.extendImg = [[UIImageView alloc] initWithImage:extendImage];
        CGSize extendSize = extendImage.size;
        self.extendImg.frame =
            CGRectMake(0.0, kExtendImageTop, extendSize.width, extendSize.height);

        [self.contentView addSubview:self.artworkView];
        [self.contentView addSubview:self.labelName];
        [self.contentView addSubview:self.labelArtist];
        [self.contentView addSubview:self.labelLevels];
        [self.contentView addSubview:sampleView];
        [self.contentView addSubview:buttonLink];
        // The extend badge is added to the cell, not the content view.
        [self addSubview:self.extendImg];
    }
    return self;
}

#pragma mark - Configuration

/** @ghidraAddress 0xfcfc0 */
- (void)setBgImage:(UIImage *)image {
    bgView.image = image;
}

/** @ghidraAddress 0xfcfd8 */
- (void)setLink:(NSString *)link {
    linkURL = link != nil ? [NSURL URLWithString:link] : nil;
    buttonLink.hidden = (linkURL == nil);
}

#pragma mark - Sample state

/** @ghidraAddress 0xfd094 */
- (void)sampleStop {
    [indicator stopAnimating];
    sampleView.hidden = YES;
}

/** @ghidraAddress 0xfd0e0 */
- (void)sampleDownloading {
    [indicator startAnimating];
    playingView.hidden = YES;
    sampleView.hidden = NO;
}

/** @ghidraAddress 0xfd148 */
- (void)samplePlaying {
    [indicator stopAnimating];
    playingView.hidden = NO;
    sampleView.hidden = NO;
}

#pragma mark - Link handling

/** @ghidraAddress 0xfcd5c */
- (void)handleLink:(id)sender {
    // Both localised strings are resolved before the guard, matching the binary.
    NSString *title = [NSBundle.mainBundle localizedStringForKey:kITunesConfirmTitleKey
                                                           value:@""
                                                           table:nil];
    NSString *message = [NSBundle.mainBundle localizedStringForKey:kITunesConfirmMessageKey
                                                             value:@""
                                                             table:nil];
    if (linkURL != nil) {
        NSString *cancel = [NSBundle.mainBundle localizedStringForKey:kCancelKey
                                                                value:@""
                                                                table:nil];
        NSString *ok = [NSBundle.mainBundle localizedStringForKey:kOKKey value:@"" table:nil];
        [AlertViewManager.sharedManager makeAlert:0
                                         delegate:self
                                              tag:0
                                            title:title
                                              msg:message
                                           cancel:cancel
                                          btnText:@[ ok ]
                                             show:YES];
    }
}

/** @ghidraAddress 0xfd1b0 */
- (void)alertSelect:(NSDictionary *)info {
    if ([info[kAlertButtonMessageKey] intValue] == kAlertButtonMessageOK) {
        if ([self.viewController respondsToSelector:@selector(storeDetailViewOpenItunesWithURL:)]) {
            [self.viewController performSelector:@selector(storeDetailViewOpenItunesWithURL:)
                                      withObject:linkURL];
        }
    }
}

#pragma mark - Teardown

/** @ghidraAddress 0xfd2b8 */
- (void)terminate {
    // The binary's implementation is empty.
}

/** @ghidraAddress 0xfd2bc */
- (void)detailClose {
    [AlertViewManager.sharedManager closeAlert];
}

@end
