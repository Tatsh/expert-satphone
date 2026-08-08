#import "StorePackRecommendPackView.h"

#import <QuartzCore/QuartzCore.h>

#import "ImageCache.h"

// The resource images.
static NSString *const kRecommendBackgroundImageName = @"store_pack_bg_0";
static NSString *const kRecommendNoArtworkImageName = @"store_jacket_100";
static NSString *const kRecommendSampleImageName = @"store_sample_1";
static NSString *const kRecommendSampleStopImageName = @"store_sample_2";
static NSString *const kRecommendItunesImageName = @"store_itunes";
static NSString *const kRecommendExtendImageName = @"store_pack_extend_ico";

// The background art's uniform resizable cap inset.
static const CGFloat kRecommendBackgroundCapInset = 4.0;

// The label common inset and the title/artist/levels metrics.
static const CGFloat kRecommendLabelX = 12.0;
static const CGFloat kRecommendLabelWidth = 244.0; // @ghidraAddress 0x28fab0
static const CGFloat kRecommendNameY = 8.0;
static const CGFloat kRecommendNameHeight = 22.0;
static const CGFloat kRecommendNameFontSize = 17.0;
static const CGFloat kRecommendNameMinimumScaleFactor =
    0.9411764740943909;                        // @ghidraAddress 0x28fab8
static const CGFloat kRecommendArtistY = 32.0; // @ghidraAddress 0x28f458
static const CGFloat kRecommendArtistHeight = 20.0;
static const CGFloat kRecommendArtistFontSize = 15.0;
static const CGFloat kRecommendLevelsXDelta = -170.0; // @ghidraAddress 0x28fac0
static const CGFloat kRecommendLevelsY = 136.0;       // @ghidraAddress 0x28f768
static const CGFloat kRecommendLevelsWidth = 150.0;   // @ghidraAddress 0x28f790
static const CGFloat kRecommendLevelsFontSize = 16.0;

// The jacket's frame and drop shadow.
static const CGFloat kRecommendArtworkY = 56.0;     // @ghidraAddress 0x28f878
static const CGFloat kRecommendArtworkSize = 100.0; // @ghidraAddress 0x28f3f0
static const CGFloat kRecommendArtworkShadowOffset = 1.0;
static const float kRecommendArtworkShadowOpacity = 0.6f; // @ghidraAddress 0x28f3b8
static const CGFloat kRecommendArtworkShadowRadius = 1.0;

// The sample button's frame: pinned to the right, fixed size.
static const CGFloat kRecommendSampleXDelta = -50.0; // @ghidraAddress 0x28e068
static const CGFloat kRecommendSampleXNudge = -1.0;
static const CGFloat kRecommendSampleY = 5.0;
static const CGFloat kRecommendSampleSize = 50.0; // @ghidraAddress 0x28f2c8

// The iTunes link button's y; its size comes from the image.
static const CGFloat kRecommendLinkY = 80.0; // @ghidraAddress 0x28f3f8

// The extend marker's one-point upward nudge.
static const CGFloat kRecommendExtendYNudge = -1.0;

// The half-scale used to centre the spinner in the sample button.
static const CGFloat kRecommendHalf = 0.5;

@implementation StorePackRecommendPackView

@synthesize artworkView = _artworkView;
@synthesize labelName = _labelName;
@synthesize labelArtist = _labelArtist;
@synthesize labelLevels = _labelLevels;
@synthesize buttonSample = _buttonSample;
@synthesize buttonLink = _buttonLink;
@synthesize extendImg = _extendImg;
@synthesize indicatorSample = _indicatorSample;

#pragma mark - Construction

/** @ghidraAddress 0x87d94 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }
    CGFloat viewWidth = frame.size.width;

    // The stretchable background fills the tile.
    UIImageView *background = [[UIImageView alloc] initWithFrame:self.bounds];
    background.image = [[ImageCache.sharedCache getResPNG:kRecommendBackgroundImageName]
        resizableImageWithCapInsets:UIEdgeInsetsMake(kRecommendBackgroundCapInset,
                                                     kRecommendBackgroundCapInset,
                                                     kRecommendBackgroundCapInset,
                                                     kRecommendBackgroundCapInset)];
    [self addSubview:background];

    // The name label scales its font down to fit.
    self.labelName = [[UILabel alloc] initWithFrame:CGRectMake(kRecommendLabelX,
                                                               kRecommendNameY,
                                                               kRecommendLabelWidth,
                                                               kRecommendNameHeight)];
    self.labelName.opaque = NO;
    self.labelName.backgroundColor = UIColor.clearColor;
    self.labelName.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    self.labelName.font = [UIFont boldSystemFontOfSize:kRecommendNameFontSize];
    self.labelName.adjustsFontSizeToFitWidth = YES;
    self.labelName.minimumScaleFactor = kRecommendNameMinimumScaleFactor;

    // The artist label.
    self.labelArtist = [[UILabel alloc] initWithFrame:CGRectMake(kRecommendLabelX,
                                                                 kRecommendArtistY,
                                                                 kRecommendLabelWidth,
                                                                 kRecommendArtistHeight)];
    self.labelArtist.opaque = NO;
    self.labelArtist.backgroundColor = UIColor.clearColor;
    self.labelArtist.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    self.labelArtist.font = [UIFont systemFontOfSize:kRecommendArtistFontSize];

    // The jacket, a URL-loading image view with a soft drop shadow.
    self.artworkView = [[StoreImageView alloc] initWithFrame:CGRectMake(kRecommendLabelX,
                                                                        kRecommendArtworkY,
                                                                        kRecommendArtworkSize,
                                                                        kRecommendArtworkSize)];
    self.artworkView.image = [ImageCache.sharedCache getResPNG:kRecommendNoArtworkImageName];
    self.artworkView.layer.shadowOffset =
        CGSizeMake(kRecommendArtworkShadowOffset, kRecommendArtworkShadowOffset);
    self.artworkView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.artworkView.layer.shadowOpacity = kRecommendArtworkShadowOpacity;
    self.artworkView.layer.shadowRadius = kRecommendArtworkShadowRadius;
    self.artworkView.layer.shouldRasterize = YES;

    // The sample button, pinned to the tile's right edge.
    self.buttonSample = [UIButton buttonWithType:UIButtonTypeCustom];
    self.buttonSample.frame =
        CGRectMake(viewWidth + kRecommendSampleXDelta + kRecommendSampleXNudge,
                   kRecommendSampleY,
                   kRecommendSampleSize,
                   kRecommendSampleSize);
    self.buttonSample.contentMode = UIViewContentModeCenter;
    [self.buttonSample setImage:[ImageCache.sharedCache getResPNG:kRecommendSampleImageName]
                       forState:UIControlStateNormal];

    // The difficulty-levels label.
    self.labelLevels = [[UILabel alloc] initWithFrame:CGRectMake(viewWidth + kRecommendLevelsXDelta,
                                                                 kRecommendLevelsY,
                                                                 kRecommendLevelsWidth,
                                                                 kRecommendArtistHeight)];
    self.labelLevels.opaque = NO;
    self.labelLevels.backgroundColor = UIColor.clearColor;
    self.labelLevels.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    self.labelLevels.font = [UIFont boldSystemFontOfSize:kRecommendLevelsFontSize];

    // The download spinner, centred in the sample button and only visible while animating.
    CGFloat spinnerSide = self.buttonSample.frame.size.width * kRecommendHalf;
    self.indicatorSample =
        [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0, 0, spinnerSide, spinnerSide)];
    self.indicatorSample.center = CGPointMake(self.buttonSample.frame.size.width * kRecommendHalf,
                                              self.buttonSample.frame.size.height * kRecommendHalf);
    self.indicatorSample.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
    self.indicatorSample.hidesWhenStopped = YES;
    [self.buttonSample addSubview:self.indicatorSample];

    // The iTunes link button, sized to its image.
    self.buttonLink = [UIButton buttonWithType:UIButtonTypeCustom];
    self.buttonLink.exclusiveTouch = YES;
    UIImage *itunesImage = [ImageCache.sharedCache getResPNG:kRecommendItunesImageName];
    self.buttonLink.frame = CGRectMake(viewWidth + kRecommendLevelsXDelta,
                                       kRecommendLinkY,
                                       itunesImage.size.width,
                                       itunesImage.size.height);
    [self.buttonLink setBackgroundImage:itunesImage forState:UIControlStateNormal];

    // The extension marker.
    UIImage *extendImage = [ImageCache.sharedCache getResPNG:kRecommendExtendImageName];
    self.extendImg = [[UIImageView alloc] initWithImage:extendImage];
    CGFloat extendHeight = self.extendImg.frame.size.height;
    self.extendImg.frame =
        CGRectMake(0,
                   (extendHeight - extendImage.size.width) + kRecommendExtendYNudge,
                   extendImage.size.width,
                   extendImage.size.height);

    [self addSubview:self.artworkView];
    [self addSubview:self.labelName];
    [self addSubview:self.labelArtist];
    [self addSubview:self.labelLevels];
    [self addSubview:self.buttonSample];
    [self addSubview:self.buttonLink];
    [self addSubview:self.extendImg];
    return self;
}

#pragma mark - Content

/** @ghidraAddress 0x88c48 */
- (void)setInfo:(StorePackInfo *)info {
    if (!info) {
        self.labelName.text = nil;
        self.labelArtist.text = nil;
        self.labelLevels.text = nil;
        self.artworkView.imageURL = nil;
        self.artworkView.image = [ImageCache.sharedCache getResPNG:kRecommendNoArtworkImageName];
        self.buttonLink.hidden = YES;
        self.buttonSample.hidden = YES;
        self.extendImg.hidden = YES;
        return;
    }
    // Only the pack name is shown; the artist and level labels are cleared.
    self.labelName.text = info.packName;
    self.labelArtist.text = nil;
    self.labelLevels.text = nil;
    self.artworkView.imageURL = info.artworkURL;
    self.artworkView.image = [ImageCache.sharedCache getResPNG:kRecommendNoArtworkImageName];
}

#pragma mark - Sample states

/** @ghidraAddress 0x89000 */
- (void)sampleStop {
    [self.indicatorSample stopAnimating];
    [self.buttonSample setImage:[ImageCache.sharedCache getResPNG:kRecommendSampleImageName]
                       forState:UIControlStateNormal];
}

/** @ghidraAddress 0x890d8 */
- (void)sampleDownloading {
    [self.indicatorSample startAnimating];
    [self.buttonSample setImage:[ImageCache.sharedCache getResPNG:kRecommendSampleImageName]
                       forState:UIControlStateNormal];
}

/** @ghidraAddress 0x891b0 */
- (void)samplePlaying {
    [self.indicatorSample stopAnimating];
    [self.buttonSample setImage:[ImageCache.sharedCache getResPNG:kRecommendSampleStopImageName]
                       forState:UIControlStateNormal];
}

@end
