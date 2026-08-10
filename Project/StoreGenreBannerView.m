#import "StoreGenreBannerView.h"

#import <QuartzCore/QuartzCore.h>

#import "JubeatAppDelegate.h"

// The banner's fallback border colour: an opaque blue at green 0.478. From the pooled double at
// 0x293b08 (green); red is zero, blue and alpha are one.
static const CGFloat kGenreBorderGreen = 0.47843137383461; // @ghidraAddress 0x293b08

// The banner button's corner radius and its inner subviews' corner radius.
static const CGFloat kGenreCornerRadius = 8.0;
static const CGFloat kGenreInnerCornerRadius = 6.0;

// The shadow/artwork subviews are inset from the banner by this much on each axis; the title is
// inset a second time by the same amount.
static const CGFloat kGenreSubviewInset = 3.0;
static const CGFloat kGenreSubviewSizeInset = 6.0;

// The shadow view's drop shadow: offset, radius, and opacity (the float at 0x28f3c0).
static const CGFloat kGenreShadowOffsetY = 0.5;
static const CGFloat kGenreShadowRadius = 1.5;
static const float kGenreShadowOpacity = 0.8f; // @ghidraAddress 0x28f3c0

// The artwork button's border width and its translucent-white background.
static const CGFloat kGenreBorderWidth = 1.2;            // @ghidraAddress 0x292f38
static const CGFloat kGenreArtworkBackgroundWhite = 0.9; // @ghidraAddress 0x28f448

// The title label's font size and minimum scale factor (the double at 0x28f230).
static const CGFloat kGenreTitleFontSize = 16.0;
static const CGFloat kGenreTitleMinimumScaleFactor = 0.6; // @ghidraAddress 0x28f230

// The downloaded artwork fades in over this interval; the pooled double at 0x28e040.
static const NSTimeInterval kGenreArtworkFadeDuration = 0.2; // @ghidraAddress 0x28e040

// The fallback border colour used until a genre supplies its own.
static inline UIColor *StoreGenreBannerViewFallbackBorderColor(void) {
    return [UIColor colorWithRed:0 green:kGenreBorderGreen blue:1 alpha:1];
}

@implementation StoreGenreBannerView {
    BOOL isPad;                   // +0x8
    UIImageView *genreShadowView; // +0x10
    UIImageView *genreBtn;        // +0x18
    UILabel *genreTitle;          // +0x20
    Downloader *imgDownloader;    // +0x28
    UIColor *borderColor;         // +0x30
    // _delegate (weak) at +0x38 is synthesised.
}

@synthesize delegate = _delegate;

#pragma mark - Construction

/** @ghidraAddress 0x1fd02c */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }
    isPad = JubeatAppDelegate.appDelegate.isPad;
    self.backgroundColor = UIColor.clearColor;
    self.layer.cornerRadius = kGenreCornerRadius;
    self.clipsToBounds = YES;
    [self addTarget:self
                  action:@selector(tapGenreBanner:)
        forControlEvents:UIControlEventTouchUpInside];

    CGFloat innerWidth = frame.size.width - kGenreSubviewSizeInset;
    CGFloat innerHeight = frame.size.height - kGenreSubviewSizeInset;
    CGRect innerFrame = CGRectMake(kGenreSubviewInset, kGenreSubviewInset, innerWidth, innerHeight);

    // The shadow view sits behind the artwork button and casts the banner's drop shadow.
    genreShadowView = [[UIImageView alloc] initWithFrame:innerFrame];
    genreShadowView.backgroundColor = UIColor.blackColor;
    genreShadowView.layer.cornerRadius = kGenreInnerCornerRadius;
    genreShadowView.layer.shadowOffset = CGSizeMake(0, kGenreShadowOffsetY);
    genreShadowView.layer.shadowColor = UIColor.blackColor.CGColor;
    genreShadowView.layer.shadowOpacity = kGenreShadowOpacity;
    genreShadowView.layer.shadowRadius = kGenreShadowRadius;
    [self addSubview:genreShadowView];

    // The artwork button carries the genre's border and a translucent-white fill until an image
    // arrives.
    genreBtn = [[UIImageView alloc] initWithFrame:innerFrame];
    genreBtn.layer.cornerRadius = kGenreInnerCornerRadius;
    genreBtn.layer.borderWidth = kGenreBorderWidth;
    genreBtn.clipsToBounds = YES;
    genreBtn.backgroundColor = [UIColor colorWithWhite:kGenreArtworkBackgroundWhite alpha:1];
    [self addSubview:genreBtn];

    // The title label is inset a second time inside the artwork button.
    genreTitle = [[UILabel alloc] initWithFrame:CGRectMake(kGenreSubviewInset,
                                                           kGenreSubviewInset,
                                                           innerWidth - kGenreSubviewSizeInset,
                                                           innerHeight - kGenreSubviewSizeInset)];
    genreTitle.backgroundColor = UIColor.clearColor;
    genreTitle.font = [UIFont boldSystemFontOfSize:kGenreTitleFontSize];
    genreTitle.textAlignment = NSTextAlignmentCenter;
    genreTitle.lineBreakMode = NSLineBreakByWordWrapping;
    genreTitle.minimumScaleFactor = kGenreTitleMinimumScaleFactor;
    genreTitle.adjustsFontSizeToFitWidth = YES;
    genreTitle.textColor = UIColor.blueColor;
    [genreBtn addSubview:genreTitle];

    imgDownloader = nil;
    return self;
}

#pragma mark - Content

/** @ghidraAddress 0x1fd62c */
- (void)setGenreInfo:(StorePackListGenre *)info {
    genreTitle.text = info.genreName;
    NSString *imageURL = info.genreImageURL;

    // The border colour is the genre's own if it has one, otherwise the fallback blue.
    borderColor = info.genreColor ? info.genreColor : StoreGenreBannerViewFallbackBorderColor();
    genreBtn.layer.borderColor = borderColor.CGColor;

    // A genre with a non-empty artwork URL starts (or restarts) a fetch through the shared
    // Downloader.
    if (imageURL && ![imageURL isEqualToString:@""]) {
        if (imgDownloader) {
            [imgDownloader cancel];
            imgDownloader = nil;
        }
        imgDownloader = [[Downloader alloc] initWithURL:[NSURL URLWithString:imageURL]
                                               delegate:self];
        [imgDownloader startDownloading];
    }
}

/** @ghidraAddress 0x1fd88c */
- (void)tapGenreBanner:(id)sender {
    if ([self.delegate respondsToSelector:@selector(tapGenreBtn:)]) {
        [self.delegate performSelector:@selector(tapGenreBtn:) withObject:self];
    }
}

/** @ghidraAddress 0x1fd940 */
- (void)setSelectColor:(BOOL)selected {
    // Selected: a blue border on a clear background with no shadow. Unselected: the genre's own
    // border colour, a clear background, and a black shadow.
    UIColor *borderCol = StoreGenreBannerViewFallbackBorderColor();
    UIColor *backgroundCol = UIColor.clearColor;
    UIColor *shadowCol = UIColor.clearColor;
    if (!selected) {
        borderCol = borderColor;
        backgroundCol = UIColor.clearColor;
        shadowCol = UIColor.blackColor;
    }
    genreBtn.layer.borderColor = borderCol.CGColor;
    self.backgroundColor = backgroundCol;
    genreShadowView.layer.shadowColor = shadowCol.CGColor;
}

#pragma mark - DownloaderDelegate

/** @ghidraAddress 0x1fdb2c */
- (void)downloaderFinished:(Downloader *)downloader {
    if (imgDownloader != downloader) {
        return;
    }
    UIImage *image = [[UIImage alloc] initWithData:[downloader getData]];
    if (!image) {
        return;
    }
    // The artwork is added over the button and faded in from transparent, and the title and border
    // are cleared so only the artwork shows. Its frame is the button's size at the origin.
    CGSize buttonSize = genreBtn.frame.size;
    UIImageView *artwork =
        [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, buttonSize.width, buttonSize.height)];
    artwork.image = image;
    artwork.alpha = 0;
    [genreBtn addSubview:artwork];
    genreTitle.alpha = 0;
    genreBtn.layer.borderWidth = 0;

    __weak UIImageView *weakArtwork = artwork;
    [UIView animateWithDuration:kGenreArtworkFadeDuration
                          delay:0
                        options:UIViewAnimationOptionCurveLinear
                     animations:^{
                       /** @ghidraAddress 0x1fdd80 */
                       weakArtwork.alpha = 1.0;
                     }
                     completion:nil];
}

@end
