#import "StorePackMusicView.h"

#import <QuartzCore/QuartzCore.h>

#import "ImageCache.h"

// The resource images.
static NSString *const kMusicBackgroundImageName = @"store_pack_bg_0";
static NSString *const kMusicNoArtworkImageName = @"store_jacket_100";
static NSString *const kMusicSampleImageName = @"store_sample_1";
static NSString *const kMusicSampleStopImageName = @"store_sample_2";
static NSString *const kMusicItunesImageName = @"store_itunes";
static NSString *const kMusicExtendImageName = @"store_pack_extend_ico";

// The background art's uniform resizable cap inset.
static const CGFloat kMusicBackgroundCapInset = 4.0;

// The label common inset and the title/artist/levels metrics.
static const CGFloat kMusicLabelX = 12.0;
static const CGFloat kMusicLabelWidth = 244.0; // @ghidraAddress 0x28fab0
static const CGFloat kMusicNameY = 8.0;
static const CGFloat kMusicNameHeight = 22.0;
static const CGFloat kMusicNameFontSize = 17.0;
static const CGFloat kMusicNameMinimumScaleFactor = 0.9411764740943909; // @ghidraAddress 0x28fab8
static const CGFloat kMusicArtistY = 32.0;                              // @ghidraAddress 0x28f458
static const CGFloat kMusicArtistHeight = 20.0;
static const CGFloat kMusicArtistFontSize = 15.0;
static const CGFloat kMusicLevelsXDelta = -170.0; // @ghidraAddress 0x28fac0
static const CGFloat kMusicLevelsY = 136.0;       // @ghidraAddress 0x28f768
static const CGFloat kMusicLevelsWidth = 150.0;   // @ghidraAddress 0x28f790
static const CGFloat kMusicLevelsFontSize = 16.0;

// The jacket's frame and drop shadow.
static const CGFloat kMusicArtworkY = 56.0;     // @ghidraAddress 0x28f878
static const CGFloat kMusicArtworkSize = 100.0; // @ghidraAddress 0x28f3f0
static const CGFloat kMusicArtworkShadowOffset = 1.0;
static const float kMusicArtworkShadowOpacity = 0.6f; // @ghidraAddress 0x28f3b8
static const CGFloat kMusicArtworkShadowRadius = 1.0;

// The sample button's frame: pinned to the right, fixed size. The x delta and size are pooled at
// 0x28e068 (−50) and 0x28f2c8 (50); the −1 nudge is an fmov immediate.
static const CGFloat kMusicSampleXDelta = -50.0; // @ghidraAddress 0x28e068
static const CGFloat kMusicSampleXNudge = -1.0;
static const CGFloat kMusicSampleY = 5.0;
static const CGFloat kMusicSampleSize = 50.0; // @ghidraAddress 0x28f2c8

// The iTunes link button's y; its size comes from the image.
static const CGFloat kMusicLinkY = 80.0; // @ghidraAddress 0x28f3f8

// The extend marker's one-point upward nudge.
static const CGFloat kMusicExtendYNudge = -1.0;

// The half-scale used to centre the spinner in the sample button.
static const CGFloat kMusicHalf = 0.5;

@implementation StorePackMusicView

@synthesize artworkView = _artworkView;
@synthesize labelName = _labelName;
@synthesize labelArtist = _labelArtist;
@synthesize labelLevels = _labelLevels;
@synthesize buttonSample = _buttonSample;
@synthesize buttonLink = _buttonLink;
@synthesize extendImg = _extendImg;
@synthesize indicatorSample = _indicatorSample;

#pragma mark - Construction

/** @ghidraAddress 0xd20e0 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }
    CGFloat viewWidth = frame.size.width;

    // The stretchable background fills the row.
    UIImageView *background = [[UIImageView alloc] initWithFrame:self.bounds];
    background.image = [[ImageCache.sharedCache getResPNG:kMusicBackgroundImageName]
        resizableImageWithCapInsets:UIEdgeInsetsMake(kMusicBackgroundCapInset,
                                                     kMusicBackgroundCapInset,
                                                     kMusicBackgroundCapInset,
                                                     kMusicBackgroundCapInset)];
    [self addSubview:background];

    // The title label scales its font down to fit.
    self.labelName = [[UILabel alloc]
        initWithFrame:CGRectMake(kMusicLabelX, kMusicNameY, kMusicLabelWidth, kMusicNameHeight)];
    self.labelName.opaque = NO;
    self.labelName.backgroundColor = UIColor.clearColor;
    self.labelName.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    self.labelName.font = [UIFont boldSystemFontOfSize:kMusicNameFontSize];
    self.labelName.adjustsFontSizeToFitWidth = YES;
    self.labelName.minimumScaleFactor = kMusicNameMinimumScaleFactor;

    // The artist label.
    self.labelArtist = [[UILabel alloc]
        initWithFrame:CGRectMake(
                          kMusicLabelX, kMusicArtistY, kMusicLabelWidth, kMusicArtistHeight)];
    self.labelArtist.opaque = NO;
    self.labelArtist.backgroundColor = UIColor.clearColor;
    self.labelArtist.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    self.labelArtist.font = [UIFont systemFontOfSize:kMusicArtistFontSize];

    // The jacket, a URL-loading image view with a soft drop shadow.
    self.artworkView = [[StoreImageView alloc]
        initWithFrame:CGRectMake(
                          kMusicLabelX, kMusicArtworkY, kMusicArtworkSize, kMusicArtworkSize)];
    self.artworkView.image = [ImageCache.sharedCache getResPNG:kMusicNoArtworkImageName];
    self.artworkView.layer.shadowOffset =
        CGSizeMake(kMusicArtworkShadowOffset, kMusicArtworkShadowOffset);
    self.artworkView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.artworkView.layer.shadowOpacity = kMusicArtworkShadowOpacity;
    self.artworkView.layer.shadowRadius = kMusicArtworkShadowRadius;
    self.artworkView.layer.shouldRasterize = YES;

    // The sample button, pinned to the row's right edge.
    self.buttonSample = [UIButton buttonWithType:UIButtonTypeCustom];
    self.buttonSample.frame = CGRectMake(viewWidth + kMusicSampleXDelta + kMusicSampleXNudge,
                                         kMusicSampleY,
                                         kMusicSampleSize,
                                         kMusicSampleSize);
    self.buttonSample.contentMode = UIViewContentModeCenter;
    [self.buttonSample setImage:[ImageCache.sharedCache getResPNG:kMusicSampleImageName]
                       forState:UIControlStateNormal];

    // The difficulty-levels label.
    self.labelLevels = [[UILabel alloc] initWithFrame:CGRectMake(viewWidth + kMusicLevelsXDelta,
                                                                 kMusicLevelsY,
                                                                 kMusicLevelsWidth,
                                                                 kMusicArtistHeight)];
    self.labelLevels.opaque = NO;
    self.labelLevels.backgroundColor = UIColor.clearColor;
    self.labelLevels.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    self.labelLevels.font = [UIFont boldSystemFontOfSize:kMusicLevelsFontSize];

    // The download spinner, centred in the sample button and only visible while animating.
    CGFloat spinnerSide = self.buttonSample.frame.size.width * kMusicHalf;
    self.indicatorSample =
        [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0, 0, spinnerSide, spinnerSide)];
    self.indicatorSample.center = CGPointMake(self.buttonSample.frame.size.width * kMusicHalf,
                                              self.buttonSample.frame.size.height * kMusicHalf);
    self.indicatorSample.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
    self.indicatorSample.hidesWhenStopped = YES;
    [self.buttonSample addSubview:self.indicatorSample];

    // The iTunes link button, sized to its image.
    self.buttonLink = [UIButton buttonWithType:UIButtonTypeCustom];
    self.buttonLink.exclusiveTouch = YES;
    UIImage *itunesImage = [ImageCache.sharedCache getResPNG:kMusicItunesImageName];
    self.buttonLink.frame = CGRectMake(viewWidth + kMusicLevelsXDelta,
                                       kMusicLinkY,
                                       itunesImage.size.width,
                                       itunesImage.size.height);
    [self.buttonLink setBackgroundImage:itunesImage forState:UIControlStateNormal];

    // The extension marker.
    UIImage *extendImage = [ImageCache.sharedCache getResPNG:kMusicExtendImageName];
    self.extendImg = [[UIImageView alloc] initWithImage:extendImage];
    CGFloat extendHeight = self.extendImg.frame.size.height;
    self.extendImg.frame = CGRectMake(0,
                                      (extendHeight - extendImage.size.width) + kMusicExtendYNudge,
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

/** @ghidraAddress 0xd2f94 */
- (void)setInfo:(StoreMusicInfo *)info {
    if (!info) {
        self.labelName.text = nil;
        self.labelArtist.text = nil;
        self.labelLevels.text = nil;
        self.artworkView.imageURL = nil;
        self.artworkView.image = [ImageCache.sharedCache getResPNG:kMusicNoArtworkImageName];
        self.buttonLink.hidden = YES;
        self.buttonSample.hidden = YES;
        self.extendImg.hidden = YES;
        return;
    }
    self.labelName.text = info.name;
    self.labelArtist.text = info.artist;
    self.labelLevels.text =
        [NSString stringWithFormat:@"LEVEL : %d / %d / %d", info.lvBas, info.lvAdv, info.lvExt];
    self.artworkView.imageURL = info.artworkURL;
    self.artworkView.image = [ImageCache.sharedCache getResPNG:kMusicNoArtworkImageName];
    self.buttonSample.hidden = (info.sampleURL == nil);
    self.buttonLink.hidden = (info.itunesURL == nil);
    self.extendImg.hidden = (info.extendMusicID == 0);
}

#pragma mark - Sample states

/** @ghidraAddress 0xd34fc */
- (void)sampleStop {
    [self.indicatorSample stopAnimating];
    [self.buttonSample setImage:[ImageCache.sharedCache getResPNG:kMusicSampleImageName]
                       forState:UIControlStateNormal];
}

/** @ghidraAddress 0xd35d4 */
- (void)sampleDownloading {
    [self.indicatorSample startAnimating];
    [self.buttonSample setImage:[ImageCache.sharedCache getResPNG:kMusicSampleImageName]
                       forState:UIControlStateNormal];
}

/** @ghidraAddress 0xd36ac */
- (void)samplePlaying {
    [self.indicatorSample stopAnimating];
    [self.buttonSample setImage:[ImageCache.sharedCache getResPNG:kMusicSampleStopImageName]
                       forState:UIControlStateNormal];
}

@end
