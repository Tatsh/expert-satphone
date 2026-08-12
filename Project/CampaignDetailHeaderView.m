#import "CampaignDetailHeaderView.h"

#import "AlertViewManager.h"
#import "AudioManager.h"
#import "CampaignItemInfo.h"
#import "ImageCache.h"
#import "ImageLoading.h"
#import "StoreButton.h"

// The stretchable background art and its uniform resizable cap inset (fmov 4.0-slot).
static NSString *const kBackgroundImageName = @"store_pack_bg_0";
static const CGFloat kBackgroundCapInset = 4.0;

// The artwork thumbnail, an 80.0-point square at (8, 8). The origin is the fmov 8.0-slot and the
// size is the pooled double at 0x28f3f8.
static const CGFloat kArtworkOrigin = 8.0;
static const CGFloat kArtworkSize = 80.0; // @ghidraAddress 0x28f3f8

// The faded reflection below the artwork: its y is the pooled double at 0x292400, its height comes
// from the fmov 16.0-slot, and it is drawn at 40% alpha (0x28f2c0). The reflection image itself is
// the top fifth of the artwork (0x28f240 == 0.2 in -setArtwork:).
static const CGFloat kReflectionY = 88.0; // @ghidraAddress 0x292400
static const CGFloat kReflectionHeight = 16.0;
static const CGFloat kReflectionAlpha = 0.4;         // @ghidraAddress 0x28f2c0
static const CGFloat kReflectionImageFraction = 0.2; // @ghidraAddress 0x28f240

// The centre fraction the sample button, its activity indicator, and the playing marker are placed
// at (fmov 0.5-slot); each is centred on the 80.0-point artwork square.
static const CGFloat kSampleCentreFraction = 0.5;

// The name label: inset right of the artwork, width shrinking with the header. From the pooled
// doubles at 0x28f908 (x), 0x292408 (width delta), and 0x28f1f8 (height); the y is the fmov
// 8.0-slot and the font the fmov 18.0-slot.
static const CGFloat kNameLabelX = 96.0; // @ghidraAddress 0x28f908
static const CGFloat kNameLabelY = 8.0;
static const CGFloat kNameLabelWidthDelta = -106.0; // @ghidraAddress 0x292408
static const CGFloat kNameLabelHeight = 40.0;       // @ghidraAddress 0x28f1f8
static const CGFloat kNameFontSize = 18.0;

// The white text shadow on the name label: a one-point downward drop at 70% alpha (0x291c98).
static const CGFloat kTextShadowWhite = 1.0;
static const CGFloat kTextShadowAlpha = 0.7; // @ghidraAddress 0x291c98
static const CGFloat kTextShadowOffsetY = 1.0;

// The comment label's initial layout, before -setCampaignInfo: re-sizes it. The y is the pooled
// double at 0x28f258, the height the fmov 10.0-slot, and the font the fmov 12.0-slot.
static const CGFloat kCommentLabelYInit = 60.0; // @ghidraAddress 0x28f258
static const CGFloat kCommentLabelHeightInit = 10.0;
static const CGFloat kCommentFontSize = 12.0;

// The comment sits this far (fmov 10.0-slot) below the bottom of the name label.
static const CGFloat kNameCommentGap = 10.0;

// The base header height accumulated below the content (0x28f5e8); with a comment the comment's
// measured height is added to it.
static const CGFloat kContentBaseHeight = 110.0; // @ghidraAddress 0x28f5e8

// The download and link buttons: fixed width/height, pinned near the header's right and bottom.
// The width is the pooled double at 0x28f210 and the x delta the pooled double at 0x291d58; the
// height is the fmov 28.0-slot, and the two vertical insets the fmov -28.0 and -4.0 slots. The link
// button sits 130 points (0x82) left of the download button.
static const CGFloat kButtonWidth = 120.0; // @ghidraAddress 0x28f210
static const CGFloat kButtonHeight = 28.0;
static const CGFloat kButtonXDelta = -130.0; // @ghidraAddress 0x291d58
static const CGFloat kButtonYInsetHeight = -28.0;
static const CGFloat kButtonYInsetPad = -4.0;
static const int kLinkButtonXOffset = -130;
static const CGFloat kButtonDisabledWhite = 0.6; // @ghidraAddress 0x28f230
static const CGFloat kButtonCornerRadius = 4.0;
static const CGFloat kButtonFontSize = 15.0;

// The link button's title, "詳しくはこちら" ("Read more here").
static NSString *const kLinkButtonTitle = @"詳しくはこちら";

// The download button's title per campaign button-type state (getButtonName:).
static NSString *const kButtonNameDownload = @"ダウンロード";
static NSString *const kButtonNameDownloaded = @"ダウンロード済み";
static NSString *const kButtonNameUpdate = @"アップデート";
static NSString *const kButtonNameSerialInput = @"シリアル入力";

// The colour components getButtonColor: builds for the "owned" and "unavailable" states.
static const CGFloat kOwnedColorRedGreen = 0.7799999713897705;    // @ghidraAddress 0x292e28
static const CGFloat kOwnedColorBlue = 0.800000011920929;         // @ghidraAddress 0x28e080
static const CGFloat kUnavailableColorGreen = 0.5882353186607361; // @ghidraAddress 0x292e20

// The fade-out time -stopSample passes to the audio manager (0x28e040).
static const CGFloat kSampleFadeOutTime = 0.2; // @ghidraAddress 0x28e040

// Download-button states, the values CampaignItemInfo -buttonType returns.
enum {
    kCampaignButtonTypeGet = 0,
    kCampaignButtonTypeOwned = 1,
    kCampaignButtonTypeBuy = 2,
    kCampaignButtonTypeUnavailable = 3,
    kCampaignButtonTypeServerLocked = 4,
};

@implementation CampaignDetailHeaderView {
    UIImageView *bgView;                      // +0x8
    UIImageView *artworkView;                 // +0x10
    UIImageView *reflectionArtworkView;       // +0x18
    UIImageView *newMarker;                   // +0x20
    UIImageView *playingView;                 // +0x28
    StoreButton *downloadBtn;                 // +0x30
    StoreButton *linkBtn;                     // +0x38
    UILabel *labelName;                       // +0x40
    UILabel *labelComment;                    // +0x48
    CampaignItemInfo *itemInfo;               // +0x50
    UIActivityIndicatorView *indicatorSample; // +0x58
    Downloader *sampleDownloader;             // +0x60
    BOOL bSamplePlaying;                      // +0x68
    UIButton *sampleButton;                   // +0x70
    // _delegate is the synthesised weak backing for the delegate property.
}

@synthesize delegate = _delegate;

#pragma mark - Construction

/** @ghidraAddress 0x121ef4 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }
    bSamplePlaying = NO;

    // The stretchable background fills the header and follows its resize.
    bgView = [[UIImageView alloc] initWithFrame:self.bounds];
    UIImage *bg = [LoadScaledPngImage(kBackgroundImageName)
        resizableImageWithCapInsets:UIEdgeInsetsMake(kBackgroundCapInset,
                                                     kBackgroundCapInset,
                                                     kBackgroundCapInset,
                                                     kBackgroundCapInset)];
    bgView.image = bg;
    bgView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:bgView];

    // The artwork, an 80-point square at (8, 8).
    artworkView = [[UIImageView alloc]
        initWithFrame:CGRectMake(kArtworkOrigin, kArtworkOrigin, kArtworkSize, kArtworkSize)];
    artworkView.image = [ImageCache.sharedCache getResPNG:@"store_jacket_160"];
    [self addSubview:artworkView];

    // The transparent sample button overlays the artwork square exactly; a tap toggles playback.
    sampleButton = [UIButton buttonWithType:UIButtonTypeCustom];
    sampleButton.frame = artworkView.frame;
    [sampleButton addTarget:self
                     action:@selector(handleSample:)
           forControlEvents:UIControlEventTouchUpInside];
    sampleButton.backgroundColor = [UIColor colorWithWhite:0 alpha:0];
    sampleButton.exclusiveTouch = YES;
    [self addSubview:sampleButton];

    // The download-progress indicator, centred on the artwork square.
    CGFloat sampleWidth = sampleButton.frame.size.width * kSampleCentreFraction;
    CGFloat sampleHeight = sampleButton.frame.size.height * kSampleCentreFraction;
    indicatorSample =
        [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0, 0, sampleWidth, sampleHeight)];
    // The binary centres the indicator twice, once from the artwork size and once from the sample
    // button size; both resolve to the same point.
    indicatorSample.center = CGPointMake(artworkView.frame.size.width * kSampleCentreFraction,
                                         artworkView.frame.size.height * kSampleCentreFraction);
    indicatorSample.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
    indicatorSample.hidesWhenStopped = YES;
    indicatorSample.center = CGPointMake(sampleWidth, sampleHeight);
    [sampleButton addSubview:indicatorSample];

    // The "now playing" marker, hidden until a sample plays, centred on the artwork square.
    playingView =
        [[UIImageView alloc] initWithImage:[ImageCache.sharedCache getResPNG:@"store_play"]];
    playingView.center = CGPointMake(sampleWidth, sampleHeight);
    playingView.hidden = YES;
    [sampleButton addSubview:playingView];

    // The faded reflection below the artwork.
    reflectionArtworkView = [[UIImageView alloc]
        initWithFrame:CGRectMake(kArtworkOrigin, kReflectionY, kArtworkSize, kReflectionHeight)];
    reflectionArtworkView.alpha = kReflectionAlpha;
    [self addSubview:reflectionArtworkView];

    CGFloat headerWidth = self.frame.size.width;

    // The name label, two lines with a soft white drop shadow.
    labelName = [[UILabel alloc] initWithFrame:CGRectMake(kNameLabelX,
                                                          kNameLabelY,
                                                          headerWidth + kNameLabelWidthDelta,
                                                          kNameLabelHeight)];
    labelName.backgroundColor = UIColor.clearColor;
    labelName.numberOfLines = 2;
    labelName.lineBreakMode = NSLineBreakByWordWrapping;
    labelName.font = [UIFont boldSystemFontOfSize:kNameFontSize];
    labelName.shadowOffset = CGSizeMake(0, kTextShadowOffsetY);
    labelName.shadowColor = [UIColor colorWithWhite:kTextShadowWhite alpha:kTextShadowAlpha];
    [self addSubview:labelName];

    // The comment label, laid out fully in -setCampaignInfo:. It shares the name label's x but sits
    // at a fixed initial y.
    headerWidth = self.frame.size.width;
    labelComment = [[UILabel alloc] initWithFrame:CGRectMake(kNameLabelX,
                                                             kCommentLabelYInit,
                                                             headerWidth + kNameLabelWidthDelta,
                                                             kCommentLabelHeightInit)];
    labelComment.backgroundColor = UIColor.clearColor;
    labelComment.numberOfLines = 0;
    labelComment.lineBreakMode = NSLineBreakByWordWrapping;
    labelComment.font = [UIFont systemFontOfSize:kCommentFontSize];
    [self addSubview:labelComment];

    // The download button, pinned near the header's right and bottom.
    CGFloat frameWidth = self.frame.size.width;
    int downloadX = (int)(frameWidth + kButtonXDelta);
    int buttonY = (int)(self.frame.size.height + kButtonYInsetHeight + kButtonYInsetPad);
    downloadBtn = [[StoreButton alloc]
        initWithFrame:CGRectMake((double)downloadX, (double)buttonY, kButtonWidth, kButtonHeight)];
    downloadBtn.disabledColor = [UIColor colorWithWhite:kButtonDisabledWhite alpha:1];
    downloadBtn.cornerRadius = kButtonCornerRadius;
    downloadBtn.exclusiveTouch = YES;
    downloadBtn.titleLabel.font = [UIFont boldSystemFontOfSize:kButtonFontSize];
    [downloadBtn addTarget:self.delegate
                    action:@selector(doPurchase:)
          forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:downloadBtn];

    // The link button, 130 points left of the download button.
    linkBtn =
        [[StoreButton alloc] initWithFrame:CGRectMake((double)(downloadX + kLinkButtonXOffset),
                                                      (double)buttonY,
                                                      kButtonWidth,
                                                      kButtonHeight)];
    linkBtn.disabledColor = [UIColor colorWithWhite:kButtonDisabledWhite alpha:1];
    linkBtn.cornerRadius = kButtonCornerRadius;
    linkBtn.exclusiveTouch = YES;
    linkBtn.titleLabel.font = [UIFont boldSystemFontOfSize:kButtonFontSize];
    // The original built black from components (0, 0, 0, 1).
    linkBtn.buttonColor = UIColor.blackColor;
    [linkBtn setTitle:kLinkButtonTitle forState:UIControlStateNormal];
    [linkBtn addTarget:self.delegate
                  action:@selector(handleLink:)
        forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:linkBtn];

    return self;
}

#pragma mark - Download-button state

/** @ghidraAddress 0x121d28 */
- (UIColor *)getButtonColor:(int)state {
    switch (state) {
    case kCampaignButtonTypeGet:
        return UIColor.blueColor;
    case kCampaignButtonTypeOwned:
    case kCampaignButtonTypeBuy:
        return [UIColor colorWithRed:kOwnedColorRedGreen
                               green:kOwnedColorRedGreen
                                blue:kOwnedColorBlue
                               alpha:1];
    case kCampaignButtonTypeUnavailable:
        return [UIColor colorWithRed:0 green:kUnavailableColorGreen blue:1 alpha:1];
    case kCampaignButtonTypeServerLocked:
        return UIColor.greenColor;
    default:
        // The original built white from components (1, 1, 1, 1).
        return UIColor.whiteColor;
    }
}

/** @ghidraAddress 0x121e68 */
- (NSString *)getButtonName:(int)state {
    switch (state) {
    case kCampaignButtonTypeGet:
    case kCampaignButtonTypeBuy:
        return kButtonNameDownload;
    case kCampaignButtonTypeOwned:
        return kButtonNameDownloaded;
    case kCampaignButtonTypeUnavailable:
        return kButtonNameUpdate;
    case kCampaignButtonTypeServerLocked:
        return kButtonNameSerialInput;
    default:
        return nil;
    }
}

/** @ghidraAddress 0x122f48 */
- (void)dlButtonUpdate {
    downloadBtn.buttonColor = [self getButtonColor:itemInfo.buttonType];
    [downloadBtn setTitle:[self getButtonName:itemInfo.buttonType] forState:UIControlStateNormal];
    // The disabled-state title is always the "downloaded" name, regardless of the current state.
    [downloadBtn setTitle:[self getButtonName:kCampaignButtonTypeOwned]
                 forState:UIControlStateDisabled];
    downloadBtn.enabled = (itemInfo.buttonType != kCampaignButtonTypeOwned);
}

#pragma mark - Content

/** @ghidraAddress 0x122a90 */
- (void)setCampaignInfo:(CampaignItemInfo *)info {
    [self stopSample];
    CGFloat headerWidth = self.frame.size.width;
    itemInfo = info;

    // Size the name label to its text, enforcing a minimum height of 40 points.
    CGFloat nameWidth = self.frame.size.width + kNameLabelWidthDelta;
    labelName.frame = CGRectMake(kNameLabelX, kNameLabelY, nameWidth, kNameLabelHeight);
    labelName.text = info.name;
    [labelName sizeToFit];
    if (labelName.frame.size.height < kNameLabelHeight) {
        labelName.frame = CGRectMake(kNameLabelX, kNameLabelY, nameWidth, kNameLabelHeight);
    }
    CGFloat nameHeight = labelName.frame.size.height;

    // The running height the header grows to fit its content. The comment is gated on the item's
    // -description (an always-non-nil NSObject string), so the comment branch is effectively always
    // taken.
    CGFloat contentBottom;
    if (!info.description) {
        labelComment.hidden = YES;
        contentBottom = kContentBaseHeight;
    } else {
        int commentY = (int)(nameHeight + kNameCommentGap + kNameLabelY);
        CGFloat commentWidth = self.frame.size.width + kNameLabelWidthDelta;
        labelComment.frame =
            CGRectMake(kNameLabelX, (double)commentY, commentWidth, kCommentLabelHeightInit);
        labelComment.text = info.itemDescription;
        labelComment.hidden = NO;
        [labelComment sizeToFit];
        contentBottom = labelComment.frame.size.height + kContentBaseHeight;
    }

    linkBtn.hidden = (info.linkURL == nil);

    // Reposition the download and link buttons below the content, using the header's current width.
    int downloadX = (int)(headerWidth + kButtonXDelta);
    int buttonY = (int)(contentBottom + kButtonYInsetHeight + kButtonYInsetPad);
    downloadBtn.frame = CGRectMake((double)downloadX, (double)buttonY, kButtonWidth, kButtonHeight);
    linkBtn.frame = CGRectMake(
        (double)(downloadX + kLinkButtonXOffset), (double)buttonY, kButtonWidth, kButtonHeight);

    // Grow the header to enclose everything, keeping its origin and width.
    CGRect headerFrame = self.frame;
    self.frame = CGRectMake(
        headerFrame.origin.x, headerFrame.origin.y, headerFrame.size.width, contentBottom);

    [self dlButtonUpdate];
    sampleButton.enabled = (itemInfo.sampleURL != nil);
}

/** @ghidraAddress 0x122e70 */
- (void)setArtwork:(UIImage *)artwork {
    if (!artwork) {
        return;
    }
    artworkView.image = artwork;
    int reflectionHeight = (int)(artwork.size.height * kReflectionImageFraction);
    reflectionArtworkView.image = CreateReflectedImage(artwork, reflectionHeight);
}

/** @ghidraAddress 0x123098 */
- (void)updateCampaignState:(CampaignItemInfo *)info {
    itemInfo = info;
    [self dlButtonUpdate];
}

#pragma mark - BGM sample playback

/** @ghidraAddress 0x1230ec */
- (void)handleSample:(id)sender {
    if (!bSamplePlaying) {
        bSamplePlaying = YES;
        sampleDownloader = [[Downloader alloc] initWithURL:itemInfo.sampleURL delegate:self];
        [sampleDownloader startDownloading];
        [indicatorSample startAnimating];
    } else {
        [AudioManager.sharedManager stopBgm];
        sampleDownloader = nil;
        bSamplePlaying = NO;
        playingView.hidden = YES;
        [indicatorSample stopAnimating];
    }
}

/** @ghidraAddress 0x123240 */
- (void)stopSample {
    [AudioManager.sharedManager fadeoutBgm:kSampleFadeOutTime];
    sampleDownloader = nil;
    [indicatorSample stopAnimating];
    playingView.hidden = YES;
    bSamplePlaying = NO;
}

/** @ghidraAddress 0x1232ec */
- (void)finishBgm:(NSNotification *)notification {
    bSamplePlaying = NO;
    playingView.hidden = YES;
}

#pragma mark - DownloaderDelegate

/** @ghidraAddress 0x123314 */
- (void)downloaderFinished:(id)downloader {
    if (sampleDownloader != downloader) {
        return;
    }
    if (bSamplePlaying) {
        NSData *data = [downloader getData];
        [AudioManager.sharedManager loadBgmData:data];
        [AudioManager.sharedManager startBgm:NO fadeTime:0.0];
        [indicatorSample stopAnimating];
        playingView.hidden = NO;
    }
    sampleDownloader = nil;
}

/** @ghidraAddress 0x123450 */
- (void)downloaderError:(id)downloader {
    if (sampleDownloader != downloader) {
        return;
    }
    [self stopSample];
    NSString *title = [NSBundle.mainBundle localizedStringForKey:@"Error" value:@"" table:nil];
    NSString *message = [NSBundle.mainBundle localizedStringForKey:@"NetworkErrorMsg"
                                                             value:@""
                                                             table:nil];
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil];
    [AlertViewManager.sharedManager makeAlert:0
                                     delegate:nil
                                          tag:0
                                        title:title
                                          msg:message
                                       cancel:ok
                                      btnText:nil
                                         show:YES];
}

/** @ghidraAddress 0x12360c */
- (void)downloaderProceed:(id)downloader {
    // The binary's body is empty.
}

@end
