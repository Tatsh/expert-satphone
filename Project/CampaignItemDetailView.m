#import "CampaignItemDetailView.h"

#import "AudioManager.h"
#import "CampaignItemInfo.h"
#import "ImageCache.h"
#import "MarkerManager.h"
#import "StoreButton.h"
#import "StoreImageView.h"
#import "StoreMusicListManager.h"
#import "StoreUtil.h"
#import "UIDevice+SystemVersionCheck.h"
#import "UnselectableTextView.h"

// StoreCampaignViewController owns this card and is only messaged, never sized, here; it is not yet
// reconstructed, so declare the selectors this class sends to it.
@interface StoreCampaignViewController : UIViewController
- (void)itemDownload;
- (void)moveExternalLink;
- (void)storePackDetailViewClose;
@end

// The BGM finish notification the card observes. The typo is the binary's own.
static NSString *const kFinishBgmNotificationName = @"JubeatAudioManagerFinishBgmNotifacation";

// The tiled pack-background artwork the card and the sample button draw.
static NSString *const kPackBackgroundImageName = @"store_pack_bg_0";
static NSString *const kSampleButtonImageName = @"store_sample_1";
static NSString *const kSamplePlayingImageName = @"store_sample_2";
static NSString *const kDefaultItemIconName = @"store_jacket_160";

// The minimum iOS version at which the copyright text view keeps its full content inset.
static NSString *const kContentInsetVersion = @"7.0";

// The near-white fill used for the two buttons' disabled state.
static const CGFloat kDisabledColorWhite = 0.6f; // @ghidraAddress 0x28f230

// The pack background fills the whole card; the card's design size is 600 x 260.
static const CGFloat kPackBackgroundWidth = 600.0;  // @ghidraAddress 0x291c30
static const CGFloat kPackBackgroundHeight = 260.0; // @ghidraAddress 0x291c80

// The resizable-image cap inset shared by both background images.
static const CGFloat kBackgroundCapInset = 4.0; // fmov immediate at 0x172178

// The top image sits below the pack background; its height fills the remainder of the card.
static const CGFloat kTopImageY = 261.0;            // @ghidraAddress 0x293418
static const CGFloat kTopImageHeightDelta = -261.0; // @ghidraAddress 0x293410

// The download, link, and sample buttons.
static const CGFloat kDownloadButtonX = 420.0;   // @ghidraAddress 0x292538
static const CGFloat kLinkButtonX = 240.0;       // @ghidraAddress 0x291bf0
static const CGFloat kActionButtonY = 220.0;     // @ghidraAddress 0x28f430
static const CGFloat kActionButtonWidth = 160.0; // @ghidraAddress 0x28f438
static const CGFloat kActionButtonHeight = 30.0; // fmov immediate at 0x1722a8
static const CGFloat kButtonCornerRadius = 4.0;  // fmov immediate at 0x172178
static const CGFloat kButtonFontSize = 16.0;     // fmov immediate at 0x17239c

static const CGFloat kSampleButtonX = 530.0;   // @ghidraAddress 0x293420
static const CGFloat kSampleButtonSize = 50.0; // @ghidraAddress 0x28f2c8

// The sample activity indicator is a 20-point square centred in the sample button.
static const CGFloat kSampleIndicatorSize = 20.0; // fmov immediate at 0x17270c

// The item icon: a 160-point square at (15, 20).
static const CGFloat kItemIconX = 15.0;     // fmov immediate at 0x172948
static const CGFloat kItemIconY = 20.0;     // fmov immediate at 0x17294c
static const CGFloat kItemIconSize = 160.0; // reuses 0x28f438

// The item name and explanation labels share a left edge at x = 190.
static const CGFloat kLabelLeftX = 190.0;          // @ghidraAddress 0x291c88
static const CGFloat kItemNameY = 20.0;            // fmov immediate at 0x172ae0 shares kItemIconY
static const CGFloat kItemNameWidth = 395.0;       // @ghidraAddress 0x291c90
static const CGFloat kItemNameHeight = 28.0;       // fmov immediate at 0x172ae0
static const CGFloat kItemNameFontSize = 24.0;     // fmov immediate at 0x172b30
static const CGFloat kItemNameShadowAlpha = 0.7f;  // @ghidraAddress 0x291c98
static const CGFloat kItemNameMinimumScale = 0.75; // fmov immediate at 0x172bdc

static const CGFloat kItemExpY = 55.0;        // @ghidraAddress 0x28f8d0
static const CGFloat kItemExpWidth = 345.0;   // @ghidraAddress 0x293428
static const CGFloat kItemExpHeight = 114.0;  // @ghidraAddress 0x28f6d0
static const CGFloat kItemExpFontSize = 13.0; // fmov immediate at 0x172c90

// The copyright text view (half the card wide, in the lower-right corner).
static const CGFloat kCopyrightX = 20.0;                  // fmov immediate at 0x1727f0
static const CGFloat kCopyrightYDelta = -60.0;            // @ghidraAddress 0x291bc8
static const CGFloat kCopyrightHeight = 50.0;             // reuses 0x28f2c8
static const CGFloat kCopyrightFontSize = 10.0;           // fmov immediate at 0x172858
static const CGFloat kContentInsetPreVersionDelta = -6.0; // fmov immediate at 0x1728e8

// The campaign explanation text view (below the item explanation).
static const CGFloat kCampaignExpX = 20.0;      // fmov immediate at 0x172948 shares kItemIconX->20
static const CGFloat kCampaignExpYExtra = 10.0; // fmov immediate at 0x172d18
static const CGFloat kCampaignExpWidthDelta = -40.0;  // @ghidraAddress 0x28e078
static const CGFloat kCampaignExpHeightDelta = -70.0; // @ghidraAddress 0x293430
static const CGFloat kCampaignExpFontSize = 18.0;     // fmov immediate at 0x172d90

// The item icon's card-level layer shadow.
static const CGFloat kCardShadowRadius = 8.0;   // fmov immediate at 0x171f68
static const CGFloat kCardShadowOpacity = 0.5f; // fmov immediate at 0x171fdc
static const CGFloat kIconShadowOffset = 1.0;   // fmov immediate at 0x172998
static const CGFloat kIconShadowOpacity = 0.6f; // @ghidraAddress 0x28f3b8
static const CGFloat kIconShadowRadius = 1.0;   // fmov immediate shared with kIconShadowOffset

// The download button's near-white disabled colour lightens the near-white fill fully opaque.
static const CGFloat kDisabledColorAlpha = 1.0; // fmov immediate at 0x172300

// The near-white value the download-button gradient's fill uses (0.6) is already
// kDisabledColorWhite.

// The alert tags echoed back through the AlertViewManager delegate.
static const int kInfoAlertTag = 3;
static const int kSampleAlertTag = 4;

// The item icon's default resource is rendered from the pack-background art at scale 3.

@implementation CampaignItemDetailView {
    int samplePlaying; // +0x... encodes as i
    BOOL isInfoLoaded;
    BOOL allowsRedownload;
    NSArray *arrayMusicView;
    UIView *packView;
    StoreImageView *itemIconView;
    UILabel *labelItemName;
    UILabel *labelItemExp;
    UILabel *labelItemTerms;
    UnselectableTextView *labelCampaignExp;
    CampaignItemInfo *itemInfo;
    StoreButton *downloadBtn;
    StoreButton *linkBtn;
    UIActivityIndicatorView *indicatorSample;
    UIActivityIndicatorView *indicator;
    UIButton *buttonSample;
    UnselectableTextView *copyrightView;
    UILabel *labelLoading;
    Downloader *infoDownloader;
    Downloader *sampleDownloader;
}

#pragma mark - Lifecycle

/** @ghidraAddress 0x171e6c */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setContentScaleFactor:UIScreen.mainScreen.scale];
        self.userInteractionEnabled = YES;
        self.opaque = YES;
        self.layer.shadowRadius = kCardShadowRadius;
        self.layer.shadowOffset = CGSizeZero;
        self.layer.shadowOpacity = kCardShadowOpacity;
        self.layer.shouldRasterize = YES;
        self.backgroundColor = UIColor.grayColor;
        itemInfo = nil;
        (void)UIColor.clearColor; // Built, then discarded — the binary keeps the call for effect.
        UIImage *packImage = [[ImageCache sharedCache] getResPNG:kPackBackgroundImageName];

        packView = [[UIView alloc]
            initWithFrame:CGRectMake(0, 0, kPackBackgroundWidth, kPackBackgroundHeight)];
        UIImageView *packBackground = [[UIImageView alloc]
            initWithFrame:CGRectMake(0, 0, kPackBackgroundWidth, kPackBackgroundHeight)];
        [packBackground
            setImage:[packImage resizableImageWithCapInsets:UIEdgeInsetsMake(kBackgroundCapInset,
                                                                             kBackgroundCapInset,
                                                                             kBackgroundCapInset,
                                                                             kBackgroundCapInset)]];
        [self addSubview:packBackground];

        CGFloat topImageHeight = (int)(frame.size.height + kTopImageHeightDelta);
        UIImageView *topImage = [[UIImageView alloc]
            initWithFrame:CGRectMake(0, kTopImageY, frame.size.width, topImageHeight)];
        [topImage
            setImage:[packImage resizableImageWithCapInsets:UIEdgeInsetsMake(kBackgroundCapInset,
                                                                             kBackgroundCapInset,
                                                                             kBackgroundCapInset,
                                                                             kBackgroundCapInset)]];
        [self addSubview:topImage];

        downloadBtn = [[StoreButton alloc] initWithFrame:CGRectMake(kDownloadButtonX,
                                                                    kActionButtonY,
                                                                    kActionButtonWidth,
                                                                    kActionButtonHeight)];
        downloadBtn.disabledColor = [UIColor colorWithWhite:kDisabledColorWhite
                                                      alpha:kDisabledColorAlpha];
        downloadBtn.cornerRadius = kButtonCornerRadius;
        [downloadBtn setExclusiveTouch:YES];
        downloadBtn.titleLabel.font = [UIFont boldSystemFontOfSize:kButtonFontSize];
        [downloadBtn setHidden:YES];
        [downloadBtn addTarget:self
                        action:@selector(doPurchase:)
              forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:downloadBtn];

        linkBtn = [[StoreButton alloc] initWithFrame:CGRectMake(kLinkButtonX,
                                                                kActionButtonY,
                                                                kActionButtonWidth,
                                                                kActionButtonHeight)];
        linkBtn.disabledColor = [UIColor colorWithWhite:kDisabledColorWhite
                                                  alpha:kDisabledColorAlpha];
        linkBtn.cornerRadius = kButtonCornerRadius;
        [linkBtn setExclusiveTouch:YES];
        linkBtn.titleLabel.font = [UIFont boldSystemFontOfSize:kButtonFontSize];
        // The original used colorWithRed:green:blue:alpha: with all components zero (black).
        linkBtn.buttonColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:1.0];
        [linkBtn setTitle:@"詳しくはこちら" forState:UIControlStateNormal];
        [linkBtn setHidden:YES];
        [linkBtn addTarget:self
                      action:@selector(handleLink:)
            forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:linkBtn];

        buttonSample = [UIButton buttonWithType:UIButtonTypeCustom];
        [buttonSample
            setFrame:CGRectMake(
                         kSampleButtonX, kActionButtonY, kSampleButtonSize, kSampleButtonSize)];
        [buttonSample setContentMode:UIViewContentModeScaleAspectFit];
        [buttonSample setImage:[[ImageCache sharedCache] getResPNG:kSampleButtonImageName]
                      forState:UIControlStateNormal];
        [buttonSample setExclusiveTouch:YES];
        [buttonSample addTarget:self
                         action:@selector(handleSample:)
               forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:buttonSample];

        indicatorSample = [[UIActivityIndicatorView alloc]
            initWithFrame:CGRectMake(0, 0, kSampleIndicatorSize, kSampleIndicatorSize)];
        (void)buttonSample.frame;
        (void)buttonSample.frame; // The binary reads the frame twice, discarding both.
        [indicatorSample
            setCenter:CGPointMake(kSampleIndicatorSize * 0.5, kSampleIndicatorSize * 0.5)];
        [indicatorSample setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleWhite];
        [indicatorSample setHidesWhenStopped:YES];
        [buttonSample addSubview:indicatorSample];

        copyrightView = [[UnselectableTextView alloc]
            initWithFrame:CGRectMake(kCopyrightX,
                                     frame.size.height + kCopyrightYDelta,
                                     frame.size.width * 0.5,
                                     kCopyrightHeight)];
        copyrightView.backgroundColor = UIColor.clearColor;
        [copyrightView setEditable:NO];
        copyrightView.font = [UIFont systemFontOfSize:kCopyrightFontSize];
        (void)copyrightView.contentInset; // Read for effect before the version branch.
        UIEdgeInsets copyrightInset = copyrightView.contentInset;
        if (![UIDevice.currentDevice systemVersionGreaterEqual:kContentInsetVersion]) {
            copyrightInset.top += kContentInsetPreVersionDelta;
            copyrightInset.left += kContentInsetPreVersionDelta;
            copyrightInset.bottom += kContentInsetPreVersionDelta;
            copyrightInset.right += kContentInsetPreVersionDelta;
        }
        [copyrightView setContentInset:copyrightInset];
        [self addSubview:copyrightView];

        itemIconView = [[StoreImageView alloc]
            initWithFrame:CGRectMake(kItemIconX, kItemIconY, kItemIconSize, kItemIconSize)];
        itemIconView.layer.shadowOffset = CGSizeMake(kIconShadowOffset, kIconShadowOffset);
        itemIconView.layer.shadowColor = UIColor.blackColor.CGColor;
        itemIconView.layer.shadowOpacity = kIconShadowOpacity;
        itemIconView.layer.shadowRadius = kIconShadowRadius;
        itemIconView.layer.shouldRasterize = YES;
        [self addSubview:itemIconView];

        labelItemName = [[UILabel alloc]
            initWithFrame:CGRectMake(kLabelLeftX, kItemNameY, kItemNameWidth, kItemNameHeight)];
        labelItemName.backgroundColor = UIColor.clearColor;
        labelItemName.font = [UIFont boldSystemFontOfSize:kItemNameFontSize];
        [labelItemName setAdjustsFontSizeToFitWidth:YES];
        labelItemName.shadowOffset = CGSizeMake(0, kIconShadowOffset);
        labelItemName.shadowColor = [UIColor colorWithWhite:1.0 alpha:kItemNameShadowAlpha];
        [labelItemName setMinimumScaleFactor:kItemNameMinimumScale];
        [self addSubview:labelItemName];

        labelItemExp = [[UILabel alloc]
            initWithFrame:CGRectMake(kLabelLeftX, kItemExpY, kItemExpWidth, kItemExpHeight)];
        labelItemExp.backgroundColor = UIColor.clearColor;
        [labelItemExp setNumberOfLines:0];
        [labelItemExp setBaselineAdjustment:UIBaselineAdjustmentNone];
        labelItemExp.font = [UIFont systemFontOfSize:kItemExpFontSize];
        [self addSubview:labelItemExp];

        // The campaign explanation view sits below the item explanation. Its y is the item
        // explanation's bottom edge plus ten points, its width is the item explanation's width less
        // forty, and its height fills the remaining card down to seventy points from the bottom.
        CGRect expFrame = topImage.frame;
        (void)expFrame;
        CGFloat campExpHeight = (int)(kItemExpHeight + kCampaignExpHeightDelta);
        labelCampaignExp = [[UnselectableTextView alloc]
            initWithFrame:CGRectMake(kCampaignExpX,
                                     kItemExpY + kCampaignExpYExtra,
                                     kItemExpWidth + kCampaignExpWidthDelta,
                                     campExpHeight)];
        labelCampaignExp.backgroundColor = UIColor.clearColor;
        [labelCampaignExp setEditable:NO];
        labelCampaignExp.font = [UIFont systemFontOfSize:kCampaignExpFontSize];
        [self addSubview:labelCampaignExp];

        samplePlaying = CampaignItemSampleStateStopped;
    }
    return self;
}

/** @ghidraAddress 0x174334 */
- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self
                                                  name:kFinishBgmNotificationName
                                                object:nil];
    [infoDownloader cancel];
    [sampleDownloader cancel];
}

#pragma mark - Button state

/** @ghidraAddress 0x171ca0 */
- (UIColor *)getButtonColor:(int)buttonType {
    switch (buttonType) {
    case CampaignItemDetailButtonTypeDownload:
        return UIColor.blueColor;
    case CampaignItemDetailButtonTypeDownloaded:
    case CampaignItemDetailButtonTypeLocked:
        return [UIColor colorWithRed:0.78 green:0.78 blue:0.8 alpha:1.0];
    case CampaignItemDetailButtonTypeSerial:
        return [UIColor colorWithRed:0 green:0.5882353186607361 blue:1.0 alpha:1.0];
    case CampaignItemDetailButtonTypeUpdate:
        return UIColor.greenColor;
    default:
        // The original used colorWithRed:green:blue:alpha: with all components one (white).
        return [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:1.0];
    }
}

/** @ghidraAddress 0x171de0 */
- (NSString *)getButtonName:(int)buttonType {
    switch (buttonType) {
    case CampaignItemDetailButtonTypeDownload:
    case CampaignItemDetailButtonTypeLocked:
    case CampaignItemDetailButtonTypeSerial:
        return @"ダウンロード";
    case CampaignItemDetailButtonTypeDownloaded:
        return @"ダウンロード済み";
    case CampaignItemDetailButtonTypeUpdate:
        return @"アップデート";
    default:
        return nil;
    }
}

/** @ghidraAddress 0x173138 */
- (void)dlButtonUpdate {
    downloadBtn.buttonColor = [self getButtonColor:itemInfo.buttonType];
    [downloadBtn setTitle:[self getButtonName:itemInfo.buttonType] forState:UIControlStateNormal];
    [downloadBtn setTitle:[self getButtonName:CampaignItemDetailButtonTypeDownloaded]
                 forState:UIControlStateDisabled];
    [downloadBtn setEnabled:(itemInfo.buttonType != CampaignItemDetailButtonTypeDownloaded)];
}

#pragma mark - Content

/** @ghidraAddress 0x173474 */
- (void)setCampaignInfo:(CampaignItemInfo *)campaignInfo {
    itemInfo = campaignInfo;
}

/** @ghidraAddress 0x173288 */
- (void)updateCampaignState:(CampaignItemInfo *)campaignInfo {
    itemInfo = campaignInfo;
    [self dlButtonUpdate];
}

/** @ghidraAddress 0x173488 */
- (void)loadInfo {
    if (itemInfo == nil) {
        return;
    }
    [self dlButtonUpdate];
    [downloadBtn setHidden:NO];
    if (itemInfo.linkURL != nil) {
        [linkBtn setHidden:NO];
    }
    itemIconView.imageURL = itemInfo.itemImageURL;
    [itemIconView startDownloadImage];
    if (itemInfo.lisenceText != nil) {
        [copyrightView setText:itemInfo.lisenceText];
    }
    if (itemInfo.name != nil) {
        [labelItemName setText:itemInfo.name];
    }
    if (itemInfo.itemDescription != nil) {
        CGRect expFrame = labelItemExp.frame;
        [labelItemExp setText:itemInfo.itemDescription];
        [labelItemExp sizeToFit];
        expFrame.size.height = CGRectGetHeight(labelItemExp.frame);
        [labelItemExp setFrame:expFrame];
    }
    if (itemInfo.unlockDescription != nil) {
        [labelCampaignExp setText:itemInfo.unlockDescription];
    }
    [buttonSample setHidden:(itemInfo.sampleURL == nil)];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(finishBgm:)
                                               name:kFinishBgmNotificationName
                                             object:nil];
}

/** @ghidraAddress 0x1732dc */
- (BOOL)hasItem {
    int type = itemInfo.itemType;
    if (type == CampaignItemInfoItemTypeTune) {
        if (![[StoreMusicListManager sharedManager] hasMusic:itemInfo.itemID]) {
            return NO;
        }
        NSString *path = [StoreUtil filePathForMusicID:itemInfo.itemID];
        return [NSFileManager.defaultManager fileExistsAtPath:path];
    }
    if (type == CampaignItemInfoItemTypeMarker) {
        NSString *name = [NSString stringWithFormat:@"mk_%04d", itemInfo.itemID];
        return [MarkerManager checkMarkerData:name];
    }
    return NO;
}

/** @ghidraAddress 0x172e34 */
- (void)removeCampaignInfo {
    itemInfo = nil;
    self.backgroundColor = UIColor.grayColor;
    [labelItemName setText:nil];
    [labelItemExp setText:nil];
    [copyrightView setText:nil];
    [itemIconView setImage:[[ImageCache sharedCache] getResPNG:kDefaultItemIconName]];
    [itemIconView setImageURL:nil];
    [packView setHidden:YES];
    [downloadBtn setHidden:YES];
    [linkBtn setHidden:YES];
    [indicator stopAnimating];
    [indicator removeFromSuperview];
    [labelLoading removeFromSuperview];
    isInfoLoaded = NO;
    [NSNotificationCenter.defaultCenter removeObserver:self
                                                  name:kFinishBgmNotificationName
                                                object:nil];
}

/** @ghidraAddress 0x173060 */
- (void)cancelLoading {
    if (infoDownloader != nil) {
        [infoDownloader cancel];
        infoDownloader = nil;
    }
}

#pragma mark - Actions

/** @ghidraAddress 0x17384c */
- (void)doPurchase:(id)sender {
    [self.viewController itemDownload];
}

/** @ghidraAddress 0x17388c */
- (void)handleLink:(id)sender {
    [self.viewController moveExternalLink];
}

#pragma mark - Sample tune

/** @ghidraAddress 0x1738cc */
- (void)handleSample:(id)sender {
    if (samplePlaying == CampaignItemSampleStateStopped) {
        samplePlaying = CampaignItemSampleStateDownloading;
        sampleDownloader = [[Downloader alloc] initWithURL:itemInfo.sampleURL delegate:self];
        [sampleDownloader startDownloading];
        [self sampleDownloading];
    } else {
        [[AudioManager sharedManager] stopBgm];
        sampleDownloader = nil;
        samplePlaying = CampaignItemSampleStateStopped;
        [self sampleStop];
    }
}

/** @ghidraAddress 0x1730ac */
- (void)stopSample {
    [[AudioManager sharedManager] fadeoutBgm:0.5];
    sampleDownloader = nil;
    [self sampleStop];
    samplePlaying = CampaignItemSampleStateStopped;
}

/** @ghidraAddress 0x1739f8 */
- (void)finishBgm:(NSNotification *)notification {
    samplePlaying = CampaignItemSampleStateStopped;
    [self sampleStop];
}

/** @ghidraAddress 0x173ef0 */
- (void)sampleStop {
    [indicatorSample stopAnimating];
    [buttonSample setImage:[[ImageCache sharedCache] getResPNG:kSampleButtonImageName]
                  forState:UIControlStateNormal];
}

/** @ghidraAddress 0x173f9c */
- (void)sampleDownloading {
    [indicatorSample startAnimating];
    [buttonSample setImage:[[ImageCache sharedCache] getResPNG:kSampleButtonImageName]
                  forState:UIControlStateNormal];
}

/** @ghidraAddress 0x174048 */
- (void)samplePlaying {
    [indicatorSample stopAnimating];
    [buttonSample setImage:[[ImageCache sharedCache] getResPNG:kSamplePlayingImageName]
                  forState:UIControlStateNormal];
}

#pragma mark - DownloaderDelegate

/** @ghidraAddress 0x173a14 */
- (void)downloaderFinished:(id)downloader {
    if (sampleDownloader == downloader) {
        if (samplePlaying >= CampaignItemSampleStatePlaying) {
            [[AudioManager sharedManager] loadBgmData:[downloader getData]];
            [[AudioManager sharedManager] startBgm:NO fadeTime:0.0];
            [self samplePlaying];
        }
        sampleDownloader = nil;
    }
}

/** @ghidraAddress 0x173b2c */
- (void)downloaderError:(id)downloader {
    if (infoDownloader == downloader) {
        [indicator stopAnimating];
        [indicator removeFromSuperview];
        [labelLoading removeFromSuperview];
        infoDownloader = nil;
        NSBundle *bundle = NSBundle.mainBundle;
        [[AlertViewManager sharedManager]
            makeAlert:0
             delegate:self
                  tag:kInfoAlertTag
                title:[bundle localizedStringForKey:@"Error" value:@"" table:nil]
                  msg:[bundle localizedStringForKey:@"NetworkErrorMsg" value:@"" table:nil]
               cancel:[bundle localizedStringForKey:@"OK" value:@"" table:nil]
              btnText:nil
                 show:YES];
    } else if (sampleDownloader == downloader) {
        if (samplePlaying >= CampaignItemSampleStatePlaying) {
            samplePlaying = CampaignItemSampleStateStopped;
        }
        [indicatorSample stopAnimating];
        sampleDownloader = nil;
        NSBundle *bundle = NSBundle.mainBundle;
        [[AlertViewManager sharedManager]
            makeAlert:0
             delegate:nil
                  tag:kSampleAlertTag
                title:[bundle localizedStringForKey:@"Error" value:@"" table:nil]
                  msg:[bundle localizedStringForKey:@"NetworkErrorMsg" value:@"" table:nil]
               cancel:[bundle localizedStringForKey:@"OK" value:@"" table:nil]
              btnText:nil
                 show:YES];
    }
}

/** @ghidraAddress 0x173eec */
- (void)downloaderProceed:(id)downloader {
}

#pragma mark - AlertViewManagerDelegate

/** @ghidraAddress 0x1740f4 */
- (void)alertClose:(NSDictionary *)info {
    if ([info[@"Tag"] intValue] == kInfoAlertTag) {
        if ([self.viewController respondsToSelector:@selector(storePackDetailViewClose)]) {
            [self.viewController performSelector:@selector(storePackDetailViewClose)];
        }
    }
}

/** @ghidraAddress 0x1741f0 */
- (void)alertSelect:(NSDictionary *)info {
    if ([info[@"Tag"] intValue] == kInfoAlertTag) {
        if ([self.viewController respondsToSelector:@selector(storePackDetailViewClose)]) {
            [self.viewController performSelector:@selector(storePackDetailViewClose)];
        }
    }
}

/** @ghidraAddress 0x1742ec */
- (void)detailClose {
    [[AlertViewManager sharedManager] closeAlert];
}

@end
