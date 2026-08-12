#import "StorePackDetailView.h"

#import "AudioManager.h"
#import "ImageCache.h"
#import "PurchaseManager.h"
#import "StoreButton.h"
#import "StoreImageView.h"
#import "StoreLinkButton.h"
#import "StoreMusicInfo.h"
#import "StoreMusicListManager.h"
#import "StorePackInfo.h"
#import "StorePackMusicView.h"
#import "StoreUtil.h"
#import "UIDevice+SystemVersionCheck.h"
#import "UnselectableTextView.h"

@interface StorePackDetailView ()
@end

// The BGM finish notification the card observes. The typo is the binary's own.
static NSString *const kFinishBgmNotificationName = @"JubeatAudioManagerFinishBgmNotifacation";

// The tiled pack-background artwork, the extend-download button icon, and the default pack artwork.
static NSString *const kPackBackgroundImageName = @"store_pack_bg_0";
static NSString *const kExtendDownloadButtonImageName = @"store_add_dl_btn_pad";
static NSString *const kDefaultArtworkImageName = @"store_jacket_160";

// The literal (non-localised) title of the pack-detail response-error alert.
static NSString *const kServerErrorTitle = @"Server Error";

// The minimum iOS version at which the copyright text view keeps its full content inset.
static NSString *const kContentInsetVersion = @"7.0";

// The keys read out of the alert-result dictionary.
static NSString *const kAlertKeyButtonMessage = @"btnMessage";
static NSString *const kAlertKeyTag = @"Tag";
static NSString *const kResponseKeyError = @"Error";

// The alert tags echoed back through the AlertViewManager delegate: the link-confirmation alert and
// the network/server-error alert.
static const int kLinkAlertTag = 1;
static const int kErrorAlertTag = 2;

// The confirm button index within the link-confirmation alert.
static const int kConfirmButtonIndex = 1;

// The number of seed tune views the card allocates up front and the maximum it keeps visible.
static const NSInteger kSeedMusicViewCount = 4;
static const int kMaxVisibleMusicViews = 5;

// The pack design size and the resizable-image cap inset shared by both background images.
static const CGFloat kPackBackgroundWidth = 600.0;  // @ghidraAddress 0x291c30
static const CGFloat kPackBackgroundHeight = 260.0; // @ghidraAddress 0x291c80
static const CGFloat kBackgroundCapInset = 4.0;     // fmov immediate at 0xb06dc

// The super frame extends the passed frame's height by 28 points.
static const CGFloat kSuperFrameHeightExtra = 28.0; // fmov immediate at 0xb0400

// The card-level layer shadow.
static const CGFloat kCardShadowRadius = 8.0;   // fmov immediate at 0xb04d0
static const CGFloat kCardShadowOpacity = 0.5f; // float fmov immediate at 0xb0540

// The pack artwork: a 160-point square at (15, 20), with a one-point black drop shadow.
static const CGFloat kArtworkX = 15.0;             // fmov immediate at 0xb075c
static const CGFloat kArtworkY = 20.0;             // fmov immediate at 0xb0760
static const CGFloat kArtworkSize = 160.0;         // @ghidraAddress 0x28f438
static const CGFloat kArtworkShadowOffset = 1.0;   // fmov immediate at 0xb07ac
static const CGFloat kArtworkShadowOpacity = 0.6f; // float g_flKeyTime060
static const CGFloat kArtworkShadowRadius = 1.0;   // fmov immediate shared with the offset

// The pack-name label: at (190, 20), 395 x 28, a bold 24-point font, with a near-white shadow.
static const CGFloat kPackNameX = 190.0;           // @ghidraAddress 0x291c88
static const CGFloat kPackNameY = 20.0;            // fmov immediate at 0xb08fc region
static const CGFloat kPackNameWidth = 395.0;       // @ghidraAddress 0x291c90
static const CGFloat kPackNameHeight = 28.0;       // fmov immediate at 0xb0900
static const CGFloat kPackNameFontSize = 24.0;     // fmov immediate at 0xb0960
static const CGFloat kPackNameMinimumScale = 0.75; // fmov immediate at 0xb0a1c
static const CGFloat kPackNameShadowOffsetY = 1.0; // fmov immediate (shares 1.0)
static const CGFloat kPackNameShadowAlpha = 0.7f;  // @ghidraAddress 0x291c98

// The comment label: at (190, 55), 395 x 114, a 13-point font.
static const CGFloat kCommentX = 190.0;       // reuses 0x291c88
static const CGFloat kCommentY = 55.0;        // @ghidraAddress 0x28f8d0
static const CGFloat kCommentWidth = 395.0;   // reuses 0x291c90
static const CGFloat kCommentHeight = 114.0;  // @ghidraAddress 0x28f6d0
static const CGFloat kCommentFontSize = 13.0; // fmov immediate at 0xb0ad8

// The copyright text view: at (15, 195), 280 x 50, a 10-point font.
static const CGFloat kCopyrightX = 15.0;                  // fmov immediate at 0xb0b54
static const CGFloat kCopyrightY = 195.0;                 // @ghidraAddress 0x291ca0
static const CGFloat kCopyrightWidth = 280.0;             // @ghidraAddress 0x28f658
static const CGFloat kCopyrightHeight = 50.0;             // @ghidraAddress 0x28f2c8
static const CGFloat kCopyrightFontSize = 10.0;           // fmov immediate at 0xb0ba0
static const CGFloat kContentInsetPreVersionDelta = -6.0; // fmov immediate at 0xb0c30

// The link button starts at CGRectZero and lays itself out in -showPackInfo. Its title uses a bold
// 14-point font with a near-white shadow and near-black title colour.
static const CGFloat kLinkButtonFontSize = 14.0;         // fmov immediate at 0xb0d2c
static const CGFloat kLinkTitleColorWhite = 0.4;         // @ghidraAddress 0x28f2c0
static const CGFloat kLinkTitleShadowOffsetY = 1.0;      // fmov immediate (shares 1.0)
static const CGFloat kLinkTitleDisabledColorWhite = 0.1; // @ghidraAddress 0x28f2b8

// The purchase button: at (430, 210), 150 x 30, near-white disabled fill, corner radius 4, a bold
// 16-point font.
static const CGFloat kPurchaseButtonX = 430.0;          // @ghidraAddress 0x28f500
static const CGFloat kPurchaseButtonY = 210.0;          // @ghidraAddress 0x28f200
static const CGFloat kPurchaseButtonWidth = 150.0;      // @ghidraAddress 0x28f790
static const CGFloat kPurchaseButtonHeight = 30.0;      // fmov immediate at 0xb0eec region
static const CGFloat kPurchaseDisabledColorWhite = 0.6; // @ghidraAddress 0x28f230
static const CGFloat kPurchaseButtonCornerRadius = 4.0; // fmov immediate at 0xb0ee0 region
static const CGFloat kPurchaseButtonFontSize = 16.0;    // fmov immediate at 0xb0f94

// The extend-download button sits 10 points to the left of the purchase button, sized to its icon.
static const CGFloat kExtendButtonXInset = -10.0; // fmov immediate at 0xb1118

// The music background image view and the tune scroll view fill the card below the pack panel.
static const CGFloat kMusicBgViewY = 260.0;      // reuses 0x291c80
static const CGFloat kMusicBgViewHeight = 340.0; // @ghidraAddress 0x28f5e0
static const CGFloat kMusicViewBgY = 260.0;      // reuses 0x291c80
static const CGFloat kMusicViewBgHeight = 368.0; // @ghidraAddress 0x291ca8

// Each tune view is 300 wide and 170 tall; two columns per row, 170-point rows.
static const CGFloat kMusicViewWidth = 300.0;  // @ghidraAddress 0x28f2d0
static const CGFloat kMusicViewHeight = 170.0; // @ghidraAddress 0x28f5d8
static const int kMusicViewColumnStride = 300; // integer column stride
static const int kMusicViewRowStride = 0xaa;   // 170-point integer row stride

// The scroll view's laid-out height differs by tune count: 360 for five or more tunes, 340 below.
static const CGFloat kMusicViewBgHeightMany = 360.0; // @ghidraAddress 0x291cc0 (index 0)
static const CGFloat kMusicViewBgHeightFew = 340.0;  // @ghidraAddress 0x291cc8 (index 1)

// The background image view is one point taller than the scroll view so its edge is not clipped.
static const CGFloat kMusicBgViewEdgeExtra = 1.0; // fmov immediate at 0xb23e0

// The activity indicator: a 24-point square centred above the card centre, and the loading label:
// centred below it.
static const CGFloat kIndicatorSize = 24.0;             // fmov immediate at 0xb153c
static const CGFloat kCentreFactor = 0.5;               // fmov immediate at 0xb1558
static const CGFloat kIndicatorCentreOffsetY = -15.0;   // fmov immediate at 0xb1564
static const CGFloat kLoadingLabelWidth = 200.0;        // @ghidraAddress 0x28f400
static const CGFloat kLoadingLabelHeight = 24.0;        // fmov immediate (shares 24.0)
static const CGFloat kLoadingLabelFontSize = 18.0;      // fmov immediate at 0xb1608
static const CGFloat kLoadingLabelShadowOffsetY = -1.0; // fmov immediate at 0xb16b4
static const CGFloat kLoadingLabelShadowAlpha = 0.4;    // @ghidraAddress 0x28f2c0
static const CGFloat kLoadingLabelCentreOffsetY = 15.0; // fmov immediate at 0xb1748

// The background greys: a near-white 0.863 while the pack is shown, grey while loading.
static const CGFloat kShownBackgroundWhite = 0.863; // @ghidraAddress 0x291cb8

// The purchase button's colour states.
static const CGFloat kBuyColorRed = 0.2;   // @ghidraAddress 0x28f240 (g_dAnimDuration020)
static const CGFloat kBuyColorGreen = 0.7; // @ghidraAddress 0x291c98
static const CGFloat kBuyColorBlue = 0.2;  // @ghidraAddress 0x28f240

static const CGFloat kRedownloadColorRed = 0.2;    // @ghidraAddress 0x28f240
static const CGFloat kRedownloadColorGreen = 0.35; // @ghidraAddress 0x291cb0
static const CGFloat kRedownloadColorBlue = 0.9;   // @ghidraAddress 0x28f448

static const CGFloat kPendingColorRed = 0.1;    // @ghidraAddress 0x28f2b8
static const CGFloat kPendingColorGreen = 0.25; // fmov immediate at 0xb1d10 region
static const CGFloat kPendingColorBlue = 0.8;   // @ghidraAddress 0x28e080

// The related-site link title's added padding when laid out in -showPackInfo.
static const CGFloat kLinkPaddingWidth = 12.0; // fmov immediate at 0xb2c60
static const CGFloat kLinkPaddingHeight = 4.0; // fmov immediate at 0xb2c68
static const CGFloat kLinkOffsetX = -15.0;     // fmov immediate at 0xb2c74

// The comment-measure bounding-rect options.
static const NSStringDrawingOptions kCommentMeasureOptions =
    NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingTruncatesLastVisibleLine;

// The sentinel stored in samplePlaying when no tune is playing a sample.
static const int kNoSamplePlaying = -1;

@implementation StorePackDetailView {
    int samplePlaying; // encodes as i; the tune index playing a sample, or -1
    BOOL isInfoLoaded;
    BOOL allowsRedownload;
    UIImageView *musicBgView;
    UIScrollView *musicViewBg;
    NSMutableArray *arrayMusicView;
    UIView *packView;
    StoreImageView *packArtworkView;
    UILabel *labelPackName;
    UILabel *labelComment;
    UILabel *labelLoading;
    StoreButton *buttonPurchase;
    UnselectableTextView *copyrightView;
    UIButton *buttonLink;
    UIButton *buttonExtendDownload;
    UIActivityIndicatorView *indicator;
    NSURL *jumpURL;
    Downloader *infoDownloader;
    Downloader *sampleDownloader;
    StorePackInfo *_packInfo;
    __weak id<StoreDetailViewControllerDelegate> _delegate;
    __weak UIViewController *_viewController;
}

@synthesize packInfo = _packInfo;
@synthesize delegate = _delegate;
@synthesize viewController = _viewController;

#pragma mark - Lifecycle

/** @ghidraAddress 0xb03c0 */
- (instancetype)initWithFrame:(CGRect)frame {
    // The super frame extends the passed frame's height by 28 points.
    self = [super initWithFrame:CGRectMake(frame.origin.x,
                                           frame.origin.y,
                                           frame.size.width,
                                           frame.size.height + kSuperFrameHeightExtra)];
    if (self) {
        [self setContentScaleFactor:UIScreen.mainScreen.scale];
        self.userInteractionEnabled = YES;
        self.opaque = YES;
        self.layer.shadowRadius = kCardShadowRadius;
        self.layer.shadowOffset = CGSizeZero;
        self.layer.shadowOpacity = kCardShadowOpacity;
        self.layer.shouldRasterize = YES;
        self.backgroundColor = UIColor.grayColor;
        (void)UIColor.clearColor; // Built, then discarded — the binary keeps the call for effect.
        UIImage *packImage = [[ImageCache sharedCache] getResPNG:kPackBackgroundImageName];

        packView = [[UIView alloc]
            initWithFrame:CGRectMake(0, 0, kPackBackgroundWidth, kPackBackgroundHeight)];
        UIImageView *packBackground = [[UIImageView alloc]
            initWithFrame:CGRectMake(0, 0, kPackBackgroundWidth, kPackBackgroundHeight)];
        UIEdgeInsets caps = UIEdgeInsetsMake(
            kBackgroundCapInset, kBackgroundCapInset, kBackgroundCapInset, kBackgroundCapInset);
        [packBackground setImage:[packImage resizableImageWithCapInsets:caps]];
        [packView addSubview:packBackground];

        packArtworkView = [[StoreImageView alloc]
            initWithFrame:CGRectMake(kArtworkX, kArtworkY, kArtworkSize, kArtworkSize)];
        packArtworkView.layer.shadowOffset = CGSizeMake(kArtworkShadowOffset, kArtworkShadowOffset);
        packArtworkView.layer.shadowColor = UIColor.blackColor.CGColor;
        packArtworkView.layer.shadowOpacity = kArtworkShadowOpacity;
        packArtworkView.layer.shadowRadius = kArtworkShadowRadius;
        packArtworkView.layer.shouldRasterize = YES;
        [packView addSubview:packArtworkView];

        labelPackName = [[UILabel alloc]
            initWithFrame:CGRectMake(kPackNameX, kPackNameY, kPackNameWidth, kPackNameHeight)];
        labelPackName.backgroundColor = UIColor.clearColor;
        labelPackName.font = [UIFont boldSystemFontOfSize:kPackNameFontSize];
        [labelPackName setAdjustsFontSizeToFitWidth:YES];
        labelPackName.shadowOffset = CGSizeMake(0, kPackNameShadowOffsetY);
        labelPackName.shadowColor = [UIColor colorWithWhite:1.0 alpha:kPackNameShadowAlpha];
        [labelPackName setMinimumScaleFactor:kPackNameMinimumScale];
        [packView addSubview:labelPackName];

        labelComment = [[UILabel alloc]
            initWithFrame:CGRectMake(kCommentX, kCommentY, kCommentWidth, kCommentHeight)];
        labelComment.backgroundColor = UIColor.clearColor;
        [labelComment setNumberOfLines:0];
        [labelComment setBaselineAdjustment:UIBaselineAdjustmentNone];
        labelComment.font = [UIFont systemFontOfSize:kCommentFontSize];
        [packView addSubview:labelComment];

        copyrightView = [[UnselectableTextView alloc]
            initWithFrame:CGRectMake(kCopyrightX, kCopyrightY, kCopyrightWidth, kCopyrightHeight)];
        copyrightView.backgroundColor = UIColor.clearColor;
        [copyrightView setEditable:NO];
        copyrightView.font = [UIFont systemFontOfSize:kCopyrightFontSize];
        UIEdgeInsets copyrightInset = copyrightView.contentInset;
        if (![UIDevice.currentDevice systemVersionGreaterEqual:kContentInsetVersion]) {
            copyrightInset.top += kContentInsetPreVersionDelta;
            copyrightInset.left += kContentInsetPreVersionDelta;
            copyrightInset.bottom += kContentInsetPreVersionDelta;
            copyrightInset.right += kContentInsetPreVersionDelta;
        }
        [copyrightView setContentInset:copyrightInset];
        [packView addSubview:copyrightView];

        buttonLink = [[StoreLinkButton alloc] initWithFrame:CGRectZero];
        [buttonLink setExclusiveTouch:YES];
        [buttonLink setContentHorizontalAlignment:UIControlContentHorizontalAlignmentLeft];
        buttonLink.opaque = NO;
        buttonLink.backgroundColor = UIColor.clearColor;
        buttonLink.titleLabel.font = [UIFont boldSystemFontOfSize:kLinkButtonFontSize];
        buttonLink.titleLabel.shadowOffset = CGSizeMake(0, kLinkTitleShadowOffsetY);
        [buttonLink setTitleColor:[UIColor colorWithWhite:kLinkTitleColorWhite alpha:1.0]
                         forState:UIControlStateNormal];
        [buttonLink setTitleShadowColor:[UIColor colorWithWhite:1.0 alpha:kPackNameShadowAlpha]
                               forState:UIControlStateNormal];
        [buttonLink setTitleColor:[UIColor colorWithWhite:kLinkTitleDisabledColorWhite alpha:1.0]
                         forState:UIControlStateDisabled];
        [buttonLink addTarget:self
                       action:@selector(handleLink:)
             forControlEvents:UIControlEventTouchUpInside];
        [packView addSubview:buttonLink];

        buttonPurchase = [[StoreButton alloc] initWithFrame:CGRectMake(kPurchaseButtonX,
                                                                       kPurchaseButtonY,
                                                                       kPurchaseButtonWidth,
                                                                       kPurchaseButtonHeight)];
        buttonPurchase.disabledColor = [UIColor colorWithWhite:kPurchaseDisabledColorWhite
                                                         alpha:1.0];
        buttonPurchase.cornerRadius = kPurchaseButtonCornerRadius;
        [buttonPurchase setExclusiveTouch:YES];
        buttonPurchase.titleLabel.font = [UIFont boldSystemFontOfSize:kPurchaseButtonFontSize];
        [buttonPurchase setTitle:[NSBundle.mainBundle localizedStringForKey:@"Purchased"
                                                                      value:@""
                                                                      table:nil]
                        forState:UIControlStateDisabled];
        [buttonPurchase addTarget:self
                           action:@selector(doPurchase:)
                 forControlEvents:UIControlEventTouchUpInside];
        [packView addSubview:buttonPurchase];

        [self addSubview:packView];

        // The extend-download button sits 10 points left of the purchase button, sized to its icon.
        UIImage *extendImage = [[ImageCache sharedCache] getResPNG:kExtendDownloadButtonImageName];
        CGRect purchaseFrame = buttonPurchase.frame;
        CGSize extendSize = extendImage.size;
        buttonExtendDownload =
            [[UIButton alloc] initWithFrame:CGRectMake(purchaseFrame.origin.x - extendSize.width +
                                                           kExtendButtonXInset,
                                                       purchaseFrame.origin.y,
                                                       extendSize.width,
                                                       extendSize.height)];
        [buttonExtendDownload setImage:extendImage forState:UIControlStateNormal];
        [buttonExtendDownload setExclusiveTouch:YES];
        [buttonExtendDownload setHidden:YES];
        [buttonExtendDownload addTarget:self
                                 action:@selector(downloadExtendMusic:)
                       forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:buttonExtendDownload];

        musicBgView = [[UIImageView alloc]
            initWithFrame:CGRectMake(0, kMusicBgViewY, kPackBackgroundWidth, kMusicBgViewHeight)];
        [musicBgView setImage:[packImage resizableImageWithCapInsets:caps]];
        [musicBgView setHidden:YES];
        [self addSubview:musicBgView];

        musicViewBg = [[UIScrollView alloc]
            initWithFrame:CGRectMake(0, kMusicViewBgY, kPackBackgroundWidth, kMusicViewBgHeight)];
        [musicViewBg setContentSize:CGSizeMake(kPackBackgroundWidth, kMusicViewBgHeight)];
        [self addSubview:musicViewBg];

        // Seed the scroll view with four tune views in a two-column grid.
        NSMutableArray *seedViews = [NSMutableArray array];
        for (NSInteger i = 0; i < kSeedMusicViewCount; ++i) {
            int index = (int)i;
            int rowIndex = (index < 0) ? (index + 1) : index;
            StorePackMusicView *musicView = [[StorePackMusicView alloc]
                initWithFrame:CGRectMake((index % 2) * kMusicViewColumnStride,
                                         (rowIndex >> 1) * kMusicViewRowStride,
                                         kMusicViewWidth,
                                         kMusicViewHeight)];
            [musicView.buttonLink addTarget:self
                                     action:@selector(handleLink:)
                           forControlEvents:UIControlEventTouchUpInside];
            [musicView.buttonSample addTarget:self
                                       action:@selector(handleSample:)
                             forControlEvents:UIControlEventTouchUpInside];
            [musicViewBg addSubview:musicView];
            seedViews[i] = musicView;
        }
        arrayMusicView = [NSMutableArray arrayWithArray:seedViews];

        [self removePackInfo];
        // The overlay is centred on the card's own (extended) frame, not the passed frame.
        CGRect selfFrame = self.frame;

        indicator = [[UIActivityIndicatorView alloc]
            initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        [indicator setFrame:CGRectMake(0, 0, kIndicatorSize, kIndicatorSize)];
        [indicator
            setCenter:CGPointMake(selfFrame.size.width * kCentreFactor,
                                  selfFrame.size.height * kCentreFactor + kIndicatorCentreOffsetY)];

        labelLoading = [[UILabel alloc]
            initWithFrame:CGRectMake(0, 0, kLoadingLabelWidth, kLoadingLabelHeight)];
        labelLoading.backgroundColor = UIColor.clearColor;
        labelLoading.font = [UIFont boldSystemFontOfSize:kLoadingLabelFontSize];
        labelLoading.textColor = UIColor.whiteColor;
        labelLoading.shadowColor = [UIColor colorWithWhite:0 alpha:kLoadingLabelShadowAlpha];
        labelLoading.shadowOffset = CGSizeMake(0, kLoadingLabelShadowOffsetY);
        [labelLoading setTextAlignment:NSTextAlignmentCenter];
        [labelLoading setText:[NSBundle.mainBundle localizedStringForKey:@"Loading..."
                                                                   value:@""
                                                                   table:nil]];
        [labelLoading setCenter:CGPointMake(selfFrame.size.width * kCentreFactor,
                                            selfFrame.size.height * kCentreFactor +
                                                kLoadingLabelCentreOffsetY)];

        isInfoLoaded = NO;
    }
    return self;
}

/** @ghidraAddress 0xb4d98 */
- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self
                                                  name:kFinishBgmNotificationName
                                                object:nil];
    [infoDownloader cancel];
    [sampleDownloader cancel];
    // [super dealloc] is compiler-emitted (ARC); the strong ivars are torn down by the
    // compiler-generated .cxx_destruct (0xb4edc), which is not authored here.
}

#pragma mark - Content

/** @ghidraAddress 0xb17fc */
- (void)removePackInfo {
    self.packInfo = nil;
    self.backgroundColor = UIColor.grayColor;
    [labelPackName setText:nil];
    [labelComment setText:nil];
    [copyrightView setText:nil];
    [packArtworkView setImage:[[ImageCache sharedCache] getResPNG:kDefaultArtworkImageName]];
    [packArtworkView setImageURL:nil];
    [packView setHidden:YES];
    [buttonExtendDownload setHidden:YES];
    [musicBgView setHidden:YES];
    for (StorePackMusicView *musicView in arrayMusicView) {
        [musicView setInfo:nil];
        [musicView setHidden:YES];
    }
    [indicator stopAnimating];
    [indicator removeFromSuperview];
    [labelLoading removeFromSuperview];
    isInfoLoaded = NO;
    [NSNotificationCenter.defaultCenter removeObserver:self
                                                  name:kFinishBgmNotificationName
                                                object:nil];
}

/** @ghidraAddress 0xb1b3c */
- (void)cancelLoading {
    if (infoDownloader != nil) {
        [infoDownloader cancel];
        infoDownloader = nil;
    }
}

/** @ghidraAddress 0xb1d10 */
- (void)updatePurchaseState {
    NSString *productID = [StoreUtil productIDForPackID:self.packInfo.packID];
    UIColor *buttonColor = nil;
    NSString *buttonTitle = nil;

    if ([PurchaseManager.sharedManager isPurchased:productID]) {
        // The pack is owned: offer a redownload only when one of its tracks is missing on disk.
        BOOL redownload = NO;
        for (StoreMusicInfo *music in self.packInfo.musicInfos) {
            if (![StoreMusicListManager.sharedManager hasMusic:music.musicID]) {
                redownload = YES;
                allowsRedownload = YES;
                buttonPurchase.enabled = YES;
                buttonTitle = [NSBundle.mainBundle localizedStringForKey:@"DOWNLOAD"
                                                                   value:@""
                                                                   table:nil];
                buttonColor = [UIColor colorWithRed:kRedownloadColorRed
                                              green:kRedownloadColorGreen
                                               blue:kRedownloadColorBlue
                                              alpha:1.0];
                break;
            }
        }

        [buttonExtendDownload setHidden:YES];
        if (!redownload) {
            if ([StoreUtil existDownloadableExtendMusic:self.packInfo.musicInfos]) {
                [buttonExtendDownload setHidden:NO];
            }
            allowsRedownload = NO;
            [buttonPurchase setEnabled:NO];
        }
    } else if ([PurchaseManager.sharedManager isPending:productID]) {
        // A purchase is in flight: allow the pending download.
        allowsRedownload = YES;
        [buttonPurchase setEnabled:YES];
        buttonTitle = [NSBundle.mainBundle localizedStringForKey:@"DOWNLOAD" value:@"" table:nil];
        buttonColor = [UIColor colorWithRed:kPendingColorRed
                                      green:kPendingColorGreen
                                       blue:kPendingColorBlue
                                      alpha:1.0];
    } else {
        // Not owned and not pending: offer the buy button at its price.
        allowsRedownload = NO;
        [buttonPurchase setEnabled:YES];
        buttonTitle =
            [NSString stringWithFormat:[NSBundle.mainBundle localizedStringForKey:@"Buy: %@"
                                                                            value:@""
                                                                            table:nil],
                                       self.packInfo.priceString];
        buttonColor = [UIColor colorWithRed:kBuyColorRed
                                      green:kBuyColorGreen
                                       blue:kBuyColorBlue
                                      alpha:1.0];
    }

    if (buttonTitle) {
        [buttonPurchase setTitle:buttonTitle forState:UIControlStateNormal];
    }
    if (buttonColor) {
        buttonPurchase.buttonColor = buttonColor;
    }
}

/** @ghidraAddress 0xb2374 */
- (void)showPackInfo {
    if (isInfoLoaded) {
        return;
    }
    self.backgroundColor = [UIColor colorWithWhite:kShownBackgroundWhite alpha:1.0];

    int trackCount = (int)self.packInfo.musicInfos.count;
    int viewCount = (int)arrayMusicView.count;

    if (trackCount < kMaxVisibleMusicViews) {
        // Fewer than five tracks: trim the pool back to its first five entries. The reverse
        // enumeration removes from the tail inward.
        if (viewCount > kSeedMusicViewCount) {
            [arrayMusicView
                enumerateObjectsWithOptions:NSEnumerationReverse
                                 usingBlock:^(
                                     StorePackMusicView *musicView, NSUInteger index, BOOL *stop) {
                                   /** @ghidraAddress 0xb2e34 */
                                   // Reverse order: entries at index 5 and above are removed,
                                   // indices 0-4 survive.
                                   if (index > kSeedMusicViewCount) {
                                       [self->arrayMusicView removeObject:musicView];
                                   } else {
                                       *stop = YES;
                                   }
                                 }];
        }
    } else if (trackCount < viewCount) {
        // More views than tracks: trim the pool back to the track count, unmounting each removed
        // view. The reverse enumeration strips off the tail.
        [arrayMusicView
            enumerateObjectsWithOptions:NSEnumerationReverse
                             usingBlock:^(
                                 StorePackMusicView *musicView, NSUInteger index, BOOL *stop) {
                               /** @ghidraAddress 0xb2e7c */
                               if ((NSInteger)index > trackCount) {
                                   [musicView removeFromSuperview];
                                   [self->arrayMusicView removeObject:musicView];
                               } else {
                                   *stop = YES;
                               }
                             }];
    } else if (viewCount < trackCount) {
        // Fewer views than tracks: append new tune views to fill the grid.
        for (int index = viewCount; index != trackCount; ++index) {
            int rowIndex = (index < 0) ? (index + 1) : index;
            StorePackMusicView *musicView = [[StorePackMusicView alloc]
                initWithFrame:CGRectMake((index % 2) * kMusicViewColumnStride,
                                         (rowIndex >> 1) * kMusicViewRowStride,
                                         kMusicViewWidth,
                                         kMusicViewHeight)];
            [musicView.buttonLink addTarget:self
                                     action:@selector(handleLink:)
                           forControlEvents:UIControlEventTouchUpInside];
            [musicView.buttonSample addTarget:self
                                       action:@selector(handleSample:)
                             forControlEvents:UIControlEventTouchUpInside];
            [musicViewBg addSubview:musicView];
            [arrayMusicView addObject:musicView];
        }
    }

    // The music background image view drops to the scroll view's height, adjusted per tune count.
    // Its height is one point taller than the scroll view's so its edge is not clipped.
    CGRect scrollFrame = musicViewBg.frame;
    CGFloat bgHeight =
        (trackCount < kMaxVisibleMusicViews) ? kMusicViewBgHeightFew : kMusicViewBgHeightMany;
    [musicBgView setFrame:CGRectMake(scrollFrame.origin.x,
                                     scrollFrame.origin.y,
                                     scrollFrame.size.width,
                                     bgHeight + kMusicBgViewEdgeExtra)];
    [musicBgView setHidden:NO];
    [musicViewBg setContentOffset:CGPointZero];
    [musicViewBg
        setFrame:CGRectMake(
                     scrollFrame.origin.x, scrollFrame.origin.y, scrollFrame.size.width, bgHeight)];

    // The scroll content spans one row per pair of tunes.
    int rowsIndex = (trackCount + 1 < 0) ? (trackCount + 2) : (trackCount + 1);
    [musicViewBg
        setContentSize:CGSizeMake(kPackBackgroundWidth, (rowsIndex >> 1) * kMusicViewRowStride)];

    [labelPackName setText:self.packInfo.packName];
    [copyrightView setText:self.packInfo.copyright];
    [packArtworkView setImageURL:self.packInfo.artworkURL];

    if (self.packInfo.comment.length == 0) {
        [labelComment setText:@" "];
    } else {
        [labelComment setText:self.packInfo.comment];
    }

    // Measure and re-frame the comment label to its natural height.
    NSDictionary *attributes = @{NSFontAttributeName : labelComment.font};
    CGRect commentRect =
        [labelComment.text boundingRectWithSize:CGSizeMake(kCommentWidth, kCommentHeight)
                                        options:kCommentMeasureOptions
                                     attributes:attributes
                                        context:nil];
    [labelComment
        setFrame:CGRectMake(kCommentX, kCommentY, commentRect.size.width, commentRect.size.height)];

    if (![StoreUtil isValidURL:self.packInfo.linkURL]) {
        [buttonLink setHidden:YES];
    } else {
        if (self.packInfo.linkTitle.length == 0) {
            [buttonLink setTitle:[NSBundle.mainBundle localizedStringForKey:@"Related site"
                                                                      value:@""
                                                                      table:nil]
                        forState:UIControlStateNormal];
        } else {
            [buttonLink setTitle:self.packInfo.linkTitle forState:UIControlStateNormal];
        }
        [buttonLink sizeToFit];
        CGRect linkFrame = buttonLink.frame;
        CGFloat linkWidth = linkFrame.size.width + kLinkPaddingWidth;
        CGFloat linkHeight = linkFrame.size.height + kLinkPaddingHeight;
        CGRect commentFrame = labelComment.frame;
        CGFloat linkX = kPackBackgroundWidth - linkWidth + kLinkOffsetX;
        CGFloat linkY = commentFrame.origin.y + commentFrame.size.height + kLinkPaddingHeight;
        [buttonLink setFrame:CGRectMake(linkX, linkY, linkWidth, linkHeight)];
        [buttonLink setNeedsDisplay];
        [buttonLink setHidden:NO];
    }

    [self updatePurchaseState];
    [packView setHidden:NO];

    // Fill the visible tune views with their track info; blank and hide the surplus slots.
    [arrayMusicView enumerateObjectsUsingBlock:^(StorePackMusicView *musicView,
                                                 NSUInteger index,
                                                 BOOL *__attribute__((unused)) stop) {
      /** @ghidraAddress 0xb2f14 */
      if ((NSInteger)index < trackCount) {
          [musicView setInfo:self.packInfo.musicInfos[index]];
          [musicView setHidden:NO];
      } else {
          [musicView setInfo:nil];
          [musicView setHidden:YES];
      }
    }];

    [packArtworkView startDownloadImage];

    // Kick off the artwork download for each tune view (a capture-free global block).
    [arrayMusicView enumerateObjectsUsingBlock:^(StorePackMusicView *musicView,
                                                 NSUInteger __attribute__((unused)) index,
                                                 BOOL *__attribute__((unused)) stop) {
      /** @ghidraAddress 0xb3038 */
      [musicView.artworkView startDownloadImage];
    }];

    isInfoLoaded = YES;
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(finishBgm:)
                                               name:kFinishBgmNotificationName
                                             object:nil];
}

/** @ghidraAddress 0xb3080 */
- (void)loadInfo {
    if (self.packInfo == nil) {
        return;
    }
    if (self.packInfo.musicInfos == nil) {
        self.backgroundColor = UIColor.grayColor;
        [self addSubview:indicator];
        [self addSubview:labelLoading];
        [indicator startAnimating];
        infoDownloader =
            [[Downloader alloc] initWithURL:[StoreUtil packInfoURL:self.packInfo.packID]
                                   delegate:self];
        [infoDownloader startDownloading];
    } else {
        self.backgroundColor = [UIColor colorWithWhite:kShownBackgroundWhite alpha:1.0];
        [self showPackInfo];
    }
}

/** @ghidraAddress 0xb329c */
- (void)loadRestoreInfo {
    if (self.packInfo == nil) {
        return;
    }
    if (self.packInfo.musicInfos == nil) {
        self.backgroundColor = UIColor.grayColor;
        [self addSubview:indicator];
        [self addSubview:labelLoading];
        [indicator startAnimating];
        infoDownloader =
            [[Downloader alloc] initWithURL:[StoreUtil restorePackInfoURL:self.packInfo.packID]
                                   delegate:self];
        [infoDownloader startDownloading];
    } else {
        self.backgroundColor = [UIColor colorWithWhite:kShownBackgroundWhite alpha:1.0];
        [self showPackInfo];
    }
}

#pragma mark - Purchase actions

/** @ghidraAddress 0xb34b8 */
- (void)doPurchase:(id)sender {
    [self stopSample];
    if (allowsRedownload) {
        if ([self.delegate respondsToSelector:@selector(detailViewStartRedownload:)]) {
            [self.delegate performSelector:@selector(detailViewStartRedownload:)
                                withObject:self.packInfo];
        }
    } else {
        if ([self.delegate respondsToSelector:@selector(detailViewStartPurchase:)]) {
            [self.delegate performSelector:@selector(detailViewStartPurchase:)
                                withObject:self.packInfo];
        }
    }
}

/** @ghidraAddress 0xb3614 */
- (void)downloadExtendMusic:(id)sender {
    [self stopSample];
    [buttonExtendDownload setHidden:YES];
    if ([self.delegate respondsToSelector:@selector(detailViewStartExtendDownload:)]) {
        [self.delegate performSelector:@selector(detailViewStartExtendDownload:)
                            withObject:self.packInfo];
    }
}

#pragma mark - Link

/** @ghidraAddress 0xb371c */
- (void)handleLink:(id)sender {
    NSString *urlString = nil;
    NSString *alertTitle = nil;
    NSString *alertMessage = nil;

    if (buttonLink == sender) {
        // The pack-level link button: confirm opening the related site in Safari.
        NSString *format = [NSBundle.mainBundle localizedStringForKey:@"Open \"%@\" in Safari?"
                                                                value:@""
                                                                table:nil];
        alertTitle =
            [NSString stringWithFormat:format, [buttonLink titleForState:UIControlStateNormal]];
        urlString = self.packInfo.linkURL;
    } else {
        // A tune's link button: find which tune view owns it, then confirm opening iTunes.
        __block int matchedIndex = kNoSamplePlaying;
        [arrayMusicView enumerateObjectsUsingBlock:^(
                            StorePackMusicView *musicView, NSUInteger index, BOOL *stop) {
          /** @ghidraAddress 0xb3c80 */
          if (sender == musicView.buttonLink) {
              matchedIndex = (int)index;
              *stop = YES;
          }
        }];
        if ((unsigned int)matchedIndex < kSeedMusicViewCount) {
            urlString = ((StoreMusicInfo *)self.packInfo.musicInfos[matchedIndex]).itunesURL;
        }
        alertTitle = [NSBundle.mainBundle localizedStringForKey:@"Show in iTunes Store?"
                                                          value:@""
                                                          table:nil];
        alertMessage = [NSBundle.mainBundle localizedStringForKey:@"iTunesStoreNoticeMsg"
                                                            value:@""
                                                            table:nil];
    }

    jumpURL = urlString ? [NSURL URLWithString:urlString] : nil;
    if (jumpURL != nil) {
        NSString *cancel = [NSBundle.mainBundle localizedStringForKey:@"Cancel"
                                                                value:@""
                                                                table:nil];
        NSString *ok = [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil];
        [[AlertViewManager sharedManager] makeAlert:0
                                           delegate:self
                                                tag:kLinkAlertTag
                                              title:alertTitle
                                                msg:alertMessage
                                             cancel:cancel
                                            btnText:@[ ok ]
                                               show:YES];
    }
}

#pragma mark - Sample tune

/** @ghidraAddress 0xb3d58 */
- (void)handleSample:(id)sender {
    __block int matchedIndex = kNoSamplePlaying;
    [arrayMusicView
        enumerateObjectsUsingBlock:^(StorePackMusicView *musicView, NSUInteger index, BOOL *stop) {
          /** @ghidraAddress 0xb40d0 */
          if (sender == musicView.buttonSample) {
              matchedIndex = (int)index;
              *stop = YES;
          }
        }];

    if ((unsigned int)matchedIndex >= kSeedMusicViewCount) {
        return;
    }

    if (matchedIndex == samplePlaying) {
        // Tapping the playing tune stops it.
        [[AudioManager sharedManager] stopBgm];
        sampleDownloader = nil;
        [arrayMusicView[samplePlaying] sampleStop];
        samplePlaying = kNoSamplePlaying;
    } else {
        // Stop any other playing tune first.
        if ((unsigned int)samplePlaying < kSeedMusicViewCount) {
            [[AudioManager sharedManager] stopBgm];
            sampleDownloader = nil;
            [arrayMusicView[samplePlaying] sampleStop];
        }
        StoreMusicInfo *info = self.packInfo.musicInfos[matchedIndex];
        samplePlaying = matchedIndex;
        [arrayMusicView[matchedIndex] sampleDownloading];
        sampleDownloader = [[Downloader alloc] initWithURL:[NSURL URLWithString:info.sampleURL]
                                                  delegate:self];
        [sampleDownloader startDownloading];
    }
}

/** @ghidraAddress 0xb1b88 */
- (void)stopSample {
    [[AudioManager sharedManager] fadeoutBgm:0.2];
    sampleDownloader = nil;
    for (StorePackMusicView *musicView in arrayMusicView) {
        [musicView sampleStop];
    }
    samplePlaying = kNoSamplePlaying;
}

/** @ghidraAddress 0xb41a8 */
- (void)finishBgm:(NSNotification *)notification {
    for (StorePackMusicView *musicView in arrayMusicView) {
        [musicView sampleStop];
    }
    samplePlaying = kNoSamplePlaying;
}

#pragma mark - DownloaderDelegate

/** @ghidraAddress 0xb42e0 */
- (void)downloaderFinished:(id)downloader {
    if (infoDownloader == downloader) {
        NSDictionary *response = [StoreUtil checkStoreResponse:[downloader getData]];
        if (![self.packInfo setPackDetailInfo:response]) {
            NSString *message = response[kResponseKeyError];
            if (message == nil) {
                message = [NSBundle.mainBundle localizedStringForKey:@"ServerErrorMsg"
                                                               value:@""
                                                               table:nil];
            }
            NSString *ok = [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil];
            [[AlertViewManager sharedManager] makeAlert:0
                                               delegate:self
                                                    tag:kErrorAlertTag
                                                  title:kServerErrorTitle
                                                    msg:message
                                                 cancel:ok
                                                btnText:nil
                                                   show:YES];
        } else {
            [self showPackInfo];
        }
        [indicator stopAnimating];
        [indicator removeFromSuperview];
        [labelLoading removeFromSuperview];
        infoDownloader = nil;
    } else if (sampleDownloader == downloader) {
        if (samplePlaying >= 0) {
            [[AudioManager sharedManager] loadBgmData:[downloader getData]];
            [[AudioManager sharedManager] startBgm:NO fadeTime:0.0];
            [arrayMusicView[samplePlaying] samplePlaying];
        }
        sampleDownloader = nil;
    }
}

/** @ghidraAddress 0xb4684 */
- (void)downloaderError:(id)downloader {
    NSString *title = [NSBundle.mainBundle localizedStringForKey:@"Error" value:@"" table:nil];
    NSString *message = [NSBundle.mainBundle localizedStringForKey:@"NetworkErrorMsg"
                                                             value:@""
                                                             table:nil];
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil];
    if (infoDownloader == downloader) {
        [indicator stopAnimating];
        [indicator removeFromSuperview];
        [labelLoading removeFromSuperview];
        infoDownloader = nil;
        [[AlertViewManager sharedManager] makeAlert:0
                                           delegate:self
                                                tag:kErrorAlertTag
                                              title:title
                                                msg:message
                                             cancel:ok
                                            btnText:nil
                                               show:YES];
    } else if (sampleDownloader == downloader) {
        if (samplePlaying >= 0) {
            [arrayMusicView[samplePlaying] sampleStop];
            samplePlaying = kNoSamplePlaying;
        }
        sampleDownloader = nil;
        // The sample-error alert takes no delegate and no tag.
        [[AlertViewManager sharedManager] makeAlert:0
                                           delegate:nil
                                                tag:0
                                              title:title
                                                msg:message
                                             cancel:ok
                                            btnText:nil
                                               show:YES];
    }
}

/** @ghidraAddress 0xb4a64 */
- (void)downloaderProceed:(id)downloader {
    // The shipped body is empty.
}

#pragma mark - AlertViewManagerDelegate

/** @ghidraAddress 0xb4a68 */
- (void)alertSelect:(NSDictionary *)info {
    int buttonMessage = [info[kAlertKeyButtonMessage] intValue];
    int tag = [info[kAlertKeyTag] intValue];
    if (tag == kErrorAlertTag) {
        if ([self.viewController respondsToSelector:@selector(storePackDetailViewClose)]) {
            [self.viewController performSelector:@selector(storePackDetailViewClose)];
        }
    } else if (buttonMessage == kConfirmButtonIndex && tag == kLinkAlertTag) {
        if ([self.viewController
                respondsToSelector:@selector(storePackDetailViewOpenItunesWithURL:)]) {
            [self.viewController performSelector:@selector(storePackDetailViewOpenItunesWithURL:)
                                      withObject:jumpURL];
        }
    }
}

/** @ghidraAddress 0xb4c54 */
- (void)alertClose:(NSDictionary *)info {
    if ([info[kAlertKeyTag] intValue] == kErrorAlertTag) {
        if ([self.viewController respondsToSelector:@selector(storePackDetailViewClose)]) {
            [self.viewController performSelector:@selector(storePackDetailViewClose)];
        }
    }
}

/** @ghidraAddress 0xb4d50 */
- (void)detailClose {
    [[AlertViewManager sharedManager] closeAlert];
}

@end
