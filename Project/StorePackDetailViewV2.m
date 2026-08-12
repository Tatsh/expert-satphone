#import "StorePackDetailViewV2.h"

#import "AudioManager.h"
#import "EditorIDManager.h"
#import "ImageCache.h"
#import "NSDictionary+TypedLookupExtension.h"
#import "PurchaseManager.h"
#import "ScratchUtil.h"
#import "SessionDownloader.h"
#import "StoreButton.h"
#import "StoreImageView.h"
#import "StoreLinkButton.h"
#import "StoreMusicInfo.h"
#import "StoreMusicListManager.h"
#import "StorePackInfo.h"
#import "StorePackMusicView.h"
#import "StoreRecommendPackTableView.h"
#import "StoreUtil.h"
#import "UIDevice+SystemVersionCheck.h"
#import "UnselectableTextViewV2.h"

// The BGM finish notification the card observes. The typo is the binary's own.
static NSString *const kFinishBgmNotificationName = @"JubeatAudioManagerFinishBgmNotifacation";

// The tiled pack-background artwork, the extend-download button icon, and the default pack artwork.
static NSString *const kPackBackgroundImageName = @"store_pack_bg_0";
static NSString *const kExtendDownloadButtonImageName = @"store_add_dl_btn_pad";
static NSString *const kDefaultArtworkImageName = @"store_jacket_160";

// The minimum iOS version at which the copyright text view keeps its full content inset.
static NSString *const kContentInsetVersion = @"7.0";

// The two relation-tab titles and the third (unused) title the binary lists alongside them.
static NSString *const kRelationTitleTracks = @"収録楽曲";
static NSString *const kRelationTitleRecommend = @"おすすめ";
static NSString *const kRelationTitleBoughtAlso =
    @"このパックを買った人はこんなパックも買っています";

// The recommended-pack request's POST keys.
static NSString *const kRecommendPostKeyPackID = @"pack_id";
static NSString *const kRecommendPostKeyUserID = @"user_id";

// The literal (non-localised) title of the pack-detail response-error alert.
static NSString *const kServerErrorTitle = @"Server Error";

// The keys read out of the alert-result dictionary and the store responses.
static NSString *const kAlertKeyButtonMessage = @"btnMessage";
static NSString *const kAlertKeyTag = @"Tag";
static NSString *const kResponseKeyError = @"Error";
static NSString *const kResponseKeyStatus = @"status";
static NSString *const kResponseKeyPackList = @"pack_list";
static NSString *const kEntryKeyID = @"ID";

// The alert tags echoed back through the AlertViewManager delegate: the link-confirmation alert and
// the network/server-error alert.
static const int kLinkAlertTag = 1;
static const int kErrorAlertTag = 2;

// The confirm button index within the link-confirmation alert.
static const int kConfirmButtonIndex = 1;

// The two relation tabs. currentList encodes as i (int). Index 0 is the included-tracks list
// ("収録楽曲") backed by musicViewBg; index 1 is the recommended-pack list ("おすすめ") backed by
// packViewBg.
static const int kRelationListMusic = 0;
static const int kRelationListRecommend = 1;

// The number of relation-tab buttons and the number of seed tune views the card allocates up front.
static const NSInteger kRelationButtonCount = 2;
static const NSInteger kSeedMusicViewCount = 4;
static const int kMaxVisibleMusicViews = 5;

// The sentinel stored in samplePlaying when no tune is playing a sample.
static const int kNoSamplePlaying = -1;

// The card-level layer shadow.
static const CGFloat kCardShadowRadius = 8.0;   // fmov immediate at 0x1dc078
static const CGFloat kCardShadowOpacity = 0.5f; // float fmov immediate at 0x1dc0ec

// The pack design size and the resizable-image cap inset shared by both background images.
static const CGFloat kPackBackgroundWidth = 650.0;  // @ghidraAddress 0x291c10
static const CGFloat kPackBackgroundHeight = 290.0; // @ghidraAddress 0x291e38
static const CGFloat kBackgroundCapInset = 4.0;     // fmov immediate at 0x1dc278

// The pack artwork: a 160-point square at (15, 20), with a one-point black drop shadow.
static const CGFloat kArtworkX = 15.0;             // fmov immediate at 0x1dc304
static const CGFloat kArtworkY = 20.0;             // fmov immediate at 0x1dc308
static const CGFloat kArtworkSize = 160.0;         // @ghidraAddress 0x28f438
static const CGFloat kArtworkShadowOffset = 1.0;   // fmov immediate at 0x1dc350
static const CGFloat kArtworkShadowOpacity = 0.6f; // float @ghidraAddress 0x28f3b8
static const CGFloat kArtworkShadowRadius = 1.0;   // fmov immediate shared with the offset

// The pack-name label: at (190, 20), 445 x 28, a bold 24-point font, with a near-white shadow.
static const CGFloat kPackNameX = 190.0;           // @ghidraAddress 0x291c88
static const CGFloat kPackNameY = 20.0;            // fmov immediate (shares 20.0)
static const CGFloat kPackNameWidth = 445.0;       // @ghidraAddress 0x293d08
static const CGFloat kPackNameHeight = 28.0;       // fmov immediate at 0x1dc4a4
static const CGFloat kPackNameFontSize = 24.0;     // fmov immediate at 0x1dc500
static const CGFloat kPackNameMinimumScale = 0.75; // fmov immediate at 0x1dc5c0
static const CGFloat kPackNameShadowOffsetY = 1.0; // fmov immediate (shares 1.0)
static const CGFloat kPackNameShadowAlpha = 0.7f;  // @ghidraAddress 0x291c98

// The comment label: at (190, 55), 445 x 114, a 13-point font.
static const CGFloat kCommentX = 190.0;       // reuses 0x291c88
static const CGFloat kCommentY = 55.0;        // @ghidraAddress 0x28f8d0
static const CGFloat kCommentWidth = 445.0;   // reuses 0x293d08
static const CGFloat kCommentHeight = 114.0;  // @ghidraAddress 0x28f6d0
static const CGFloat kCommentFontSize = 13.0; // fmov immediate at 0x1dc678

// The copyright text view: at (15, 188), 280 x 45, a 10-point font.
static const CGFloat kCopyrightX = 15.0;                  // fmov immediate (shares 15.0)
static const CGFloat kCopyrightY = 188.0;                 // @ghidraAddress 0x28f418
static const CGFloat kCopyrightWidth = 280.0;             // @ghidraAddress 0x28f658
static const CGFloat kCopyrightHeight = 45.0;             // @ghidraAddress 0x28f1e0
static const CGFloat kCopyrightFontSize = 10.0;           // fmov immediate at 0x1dc740
static const CGFloat kContentInsetPreVersionDelta = -6.0; // fmov immediate at 0x1dc7d0

// The relation view: at (100, 246), 450 x 30, corner radius 8, a 1.2-point sky-blue border.
static const CGFloat kRelationViewX = 100.0;          // @ghidraAddress 0x28f3f0
static const CGFloat kRelationViewY = 246.0;          // @ghidraAddress 0x292720
static const CGFloat kRelationViewWidth = 450.0;      // @ghidraAddress 0x293d10
static const CGFloat kRelationViewHeight = 30.0;      // fmov immediate at 0x1dc884
static const CGFloat kRelationViewCornerRadius = 8.0; // fmov immediate at 0x1dc8cc
static const CGFloat kRelationViewBorderWidth = 1.2;  // @ghidraAddress 0x292f38

// The two relation buttons: half-width each, pinned two points above the view top, four points
// taller than the view, with a half-point border.
static const CGFloat kRelationButtonY = -2.0;          // fmov immediate at 0x1dca84
static const CGFloat kRelationButtonHeightExtra = 4.0; // fmov immediate (shares 4.0)
static const CGFloat kRelationButtonBorderWidth = 0.5; // fmov immediate at 0x1dca8c

// The active tab's background and the inactive tab's title share a sky-blue: RGB(0, 0.478, 1).
static const CGFloat kRelationActiveColorRed = 0.0;
static const CGFloat kRelationActiveColorGreen = 0.478431373; // @ghidraAddress 0x293b08
static const CGFloat kRelationActiveColorBlue = 1.0;          // fmov immediate

// The active tab's title is near-white; the disabled (non-selectable) inactive tab uses greys.
static const CGFloat kRelationSelectedTitleWhite = 0.9;      // @ghidraAddress 0x28f448
static const CGFloat kRelationDisabledBackgroundWhite = 0.6; // @ghidraAddress 0x28f288
static const CGFloat kRelationDisabledTitleWhite = 0.8;      // @ghidraAddress 0x28e060

// The two-leg cross-fade between the tab backgrounds runs at 0.2 s per leg, linear.
static const NSTimeInterval kRelationCrossFadeDuration = 0.2; // @ghidraAddress 0x28f240

// The link button starts at CGRectZero and lays itself out in -showPackInfo. Its title uses a bold
// 14-point font with a near-white shadow and near-black title colour.
static const CGFloat kLinkButtonFontSize = 14.0;         // fmov immediate at 0x1dcd3c
static const CGFloat kLinkTitleColorWhite = 0.4;         // @ghidraAddress 0x28f2c0
static const CGFloat kLinkTitleShadowOffsetY = 1.0;      // fmov immediate (shares 1.0)
static const CGFloat kLinkTitleDisabledColorWhite = 0.1; // @ghidraAddress 0x28f2b8

// The purchase button: at (480, 202), 150 x 30, near-white disabled fill, corner radius 4, a bold
// 16-point font.
static const CGFloat kPurchaseButtonX = 480.0;          // @ghidraAddress 0x28e020
static const CGFloat kPurchaseButtonY = 202.0;          // @ghidraAddress 0x293d18
static const CGFloat kPurchaseButtonWidth = 150.0;      // @ghidraAddress 0x28f790
static const CGFloat kPurchaseButtonHeight = 30.0;      // fmov immediate at 0x1dcee4
static const CGFloat kPurchaseDisabledColorWhite = 0.6; // @ghidraAddress 0x28f230
static const CGFloat kPurchaseButtonCornerRadius = 4.0; // fmov immediate at 0x1dcf50
static const CGFloat kPurchaseButtonFontSize = 16.0;    // fmov immediate at 0x1dcf90

// The extend-download button sits 10 points to the left of the purchase button, sized to its icon.
static const CGFloat kExtendButtonXInset = -10.0; // fmov immediate at 0x1dd114

// The music background image view and the tune scroll view fill the card below the pack panel.
static const CGFloat kMusicBgViewY = 290.0;      // reuses 0x291e38
static const CGFloat kMusicBgViewHeight = 340.0; // @ghidraAddress 0x28f5e0
static const CGFloat kMusicViewBgY = 290.0;      // reuses 0x291e38
static const CGFloat kMusicViewBgHeight = 364.0; // @ghidraAddress 0x293d20

// Each tune view is 325 wide and 170 tall; two columns per row, 170-point rows.
static const CGFloat kMusicViewWidth = 325.0;  // @ghidraAddress 0x293338
static const CGFloat kMusicViewHeight = 170.0; // @ghidraAddress 0x28f5d8
static const int kMusicViewColumnStride = 325; // integer column stride (0x145)
static const int kMusicViewRowStride = 170;    // integer row stride (0xaa)

// The scroll view's laid-out height differs by tune count: 356 for five or more tunes, 340 below.
static const CGFloat kMusicViewBgHeightMany = 356.0; // @ghidraAddress 0x293d30 (index 0)
static const CGFloat kMusicViewBgHeightFew = 340.0;  // @ghidraAddress 0x293d38 (index 1)

// The background image view is one point taller than the scroll view so its edge is not clipped.
static const CGFloat kMusicBgViewEdgeExtra = 1.0; // fadd with 1.0 in -showPackInfo

// The activity indicator: a 24-point square centred above the card centre, and the loading label:
// centred below it.
static const CGFloat kIndicatorSize = 24.0;             // fmov immediate at 0x1dd604
static const CGFloat kCentreFactor = 0.5;               // fmov immediate at 0x1dca8c
static const CGFloat kIndicatorCentreOffsetY = -15.0;   // fmov immediate at 0x1dd628
static const CGFloat kLoadingLabelWidth = 200.0;        // @ghidraAddress 0x28f400
static const CGFloat kLoadingLabelHeight = 24.0;        // fmov immediate (shares 24.0)
static const CGFloat kLoadingLabelFontSize = 18.0;      // fmov immediate at 0x1dd6d8
static const CGFloat kLoadingLabelShadowOffsetY = -1.0; // fmov immediate at 0x1dd784
static const CGFloat kLoadingLabelShadowAlpha = 0.4;    // @ghidraAddress 0x28f2c0
static const CGFloat kLoadingLabelCentreOffsetY = 15.0; // fmov immediate at 0x1dd818

// The background grey: a near-white 0.863 while the pack is shown, grey while loading.
static const CGFloat kShownBackgroundWhite = 0.863; // @ghidraAddress 0x291cb8

// The sample fade-out duration.
static const CGFloat kSampleFadeoutDuration = 0.2; // @ghidraAddress 0x28e040

// The purchase button's colour states.
static const CGFloat kBuyColorRed = 0.2;   // @ghidraAddress 0x28f240
static const CGFloat kBuyColorGreen = 0.7; // @ghidraAddress 0x291c98
static const CGFloat kBuyColorBlue = 0.2;  // @ghidraAddress 0x28f240

static const CGFloat kRedownloadColorRed = 0.2;    // @ghidraAddress 0x28f240
static const CGFloat kRedownloadColorGreen = 0.35; // @ghidraAddress 0x291cb0
static const CGFloat kRedownloadColorBlue = 0.9;   // @ghidraAddress 0x28f448

static const CGFloat kPendingColorRed = 0.1;    // @ghidraAddress 0x28f2b8
static const CGFloat kPendingColorGreen = 0.25; // fmov immediate 0x3fd0000000000000
static const CGFloat kPendingColorBlue = 0.8;   // @ghidraAddress 0x28e080

// The related-site link title's added padding when laid out in -showPackInfo.
static const CGFloat kLinkPaddingWidth = 12.0; // fmov immediate at 0x1dfac0
static const CGFloat kLinkPaddingHeight = 4.0; // fmov immediate at 0x1dfac8
static const CGFloat kLinkOffsetX = -15.0;     // fmov immediate at 0x1dfad4
static const CGFloat kLinkOffsetY = 2.0;       // fmov immediate at 0x1dfafc

// The comment-measure bounding-rect options.
static const NSStringDrawingOptions kCommentMeasureOptions =
    NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingTruncatesLastVisibleLine;

@implementation StorePackDetailViewV2 {
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
    StoreButton *buttonPurchase;
    UnselectableTextViewV2 *copyrightView;
    UIButton *buttonLink;
    UIButton *backButton;
    UIActivityIndicatorView *indicator;
    UILabel *labelLoading;
    NSURL *jumpURL;
    Downloader *infoDownloader;
    Downloader *sampleDownloader;
    UIButton *buttonExtendDownload;
    UIView *relationView;
    NSArray *relationBtnArray;
    UIScrollView *packViewBg;
    NSMutableArray *arrayPackView;
    StoreRecommendPackTableView *recommendPackTableView;
    SessionDownloader *recommendDownloader;
    NSArray *recommendPackDictArray;
    NSArray *recommendPackList;
    BOOL recommendReady;
    int currentList; // encodes as i; the visible relation-tab list index
    SKProductsRequest *productsRequest;
    NSString *storeCountry;
    StorePackInfo *_packInfo;
    __weak id _delegate;
    __weak UIViewController *_viewController;
}

@synthesize packInfo = _packInfo;
@synthesize delegate = _delegate;
@synthesize viewController = _viewController;

#pragma mark - Lifecycle

/** @ghidraAddress 0x1dbf70 */
- (instancetype)initWithFrame:(CGRect)frame {
    // Unlike the phone card, V2 passes the caller's frame through unchanged; there is no +28
    // height extension and no IsPad()/thema branch anywhere in this constructor.
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

        copyrightView = [[UnselectableTextViewV2 alloc]
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

        recommendReady = NO;

        // The relation view and its two related-pack buttons share a sky-blue border colour.
        UIColor *relationColor = [UIColor colorWithRed:kRelationActiveColorRed
                                                 green:kRelationActiveColorGreen
                                                  blue:kRelationActiveColorBlue
                                                 alpha:1.0];

        relationView = [[UIView alloc] initWithFrame:CGRectMake(kRelationViewX,
                                                                kRelationViewY,
                                                                kRelationViewWidth,
                                                                kRelationViewHeight)];
        relationView.layer.cornerRadius = kRelationViewCornerRadius;
        [relationView setClipsToBounds:YES];
        relationView.layer.borderWidth = kRelationViewBorderWidth;
        relationView.layer.borderColor = relationColor.CGColor;
        [packView addSubview:relationView];

        // The two related-pack buttons split the relation view's width in half; each is four points
        // taller than the view and pinned two points above its top.
        int relationHalfWidth = (int)relationView.frame.size.width / 2;
        NSMutableArray *relationButtons = [[NSMutableArray alloc] init];
        NSArray *relationTitles =
            @[ kRelationTitleTracks, kRelationTitleRecommend, kRelationTitleBoughtAlso ];
        int relationButtonX = 0;
        for (NSInteger i = 0; i < kRelationButtonCount; ++i) {
            UIButton *button =
                [[UIButton alloc] initWithFrame:CGRectMake(relationButtonX,
                                                           kRelationButtonY,
                                                           relationHalfWidth,
                                                           relationView.frame.size.height +
                                                               kRelationButtonHeightExtra)];
            [button setTitle:relationTitles[i] forState:UIControlStateNormal];
            [button setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
            button.layer.borderWidth = kRelationButtonBorderWidth;
            button.layer.borderColor = relationColor.CGColor;
            [button setTag:i];
            [button setEnabled:NO];
            [button addTarget:self
                          action:@selector(tapRelationButton:)
                forControlEvents:UIControlEventTouchUpInside];
            [relationView addSubview:button];
            [relationButtons addObject:button];
            // The binary adds the button to the relation view a second time.
            [relationView addSubview:button];
            relationButtonX += relationHalfWidth;
        }
        relationBtnArray = [relationButtons copy];
        [self setRelationColor:0 selectable:NO];

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
        StorePackMusicView *seedViews[kSeedMusicViewCount];
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
        arrayMusicView = [NSMutableArray arrayWithObjects:seedViews count:kSeedMusicViewCount];

        [self removePackInfo];

        packViewBg = [[UIScrollView alloc]
            initWithFrame:CGRectMake(0, kMusicViewBgY, kPackBackgroundWidth, kMusicViewBgHeight)];
        [packViewBg setContentSize:CGSizeMake(kPackBackgroundWidth, kMusicViewBgHeight)];
        [packViewBg setHidden:YES];
        [self addSubview:packViewBg];

        recommendPackTableView = [[StoreRecommendPackTableView alloc]
            initWithFrame:CGRectMake(0, 0, kPackBackgroundWidth, kMusicViewBgHeight)
                    style:UITableViewStylePlain];
        [packViewBg addSubview:recommendPackTableView];

        // The overlay is centred on the card's own frame.
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

        // The back button covers the right half of the card at full height; the binary configures
        // it but does not add it as a subview here.
        backButton =
            [[UIButton alloc] initWithFrame:CGRectMake(selfFrame.size.width * kCentreFactor,
                                                       0,
                                                       selfFrame.size.width * kCentreFactor,
                                                       selfFrame.size.height)];
        backButton.backgroundColor = UIColor.clearColor;
        [backButton addTarget:self
                       action:@selector(popOutDetailView)
             forControlEvents:UIControlEventTouchUpInside];

        currentList = 0;
    }
    return self;
}

/** @ghidraAddress 0x1e261c */
- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self
                                                  name:kFinishBgmNotificationName
                                                object:nil];
    [infoDownloader cancel];
    [sampleDownloader cancel];
    [recommendDownloader cancel];
    if (productsRequest != nil) {
        [productsRequest cancel];
        productsRequest = nil;
    }
    // [super dealloc] is compiler-emitted (ARC); the strong ivars are torn down by the
    // compiler-generated .cxx_destruct (0x1e27a0), which is not authored here.
}

#pragma mark - Content

/** @ghidraAddress 0x1dd9bc */
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
    [self setRelationColor:0 selectable:NO];
    recommendReady = NO;
    for (UIButton *relationButton in relationBtnArray) {
        [relationButton setEnabled:NO];
    }
    [NSNotificationCenter.defaultCenter removeObserver:self
                                                  name:kFinishBgmNotificationName
                                                object:nil];
}

/** @ghidraAddress 0x1de7fc */
- (void)cancelLoading {
    if (infoDownloader != nil) {
        [infoDownloader cancel];
        infoDownloader = nil;
    }
}

/** @ghidraAddress 0x1de848 */
- (void)stopSample {
    [[AudioManager sharedManager] fadeoutBgm:kSampleFadeoutDuration];
    sampleDownloader = nil;
    for (StorePackMusicView *musicView in arrayMusicView) {
        [musicView sampleStop];
    }
    samplePlaying = kNoSamplePlaying;
}

/** @ghidraAddress 0x1df04c */
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
                                   /** @ghidraAddress 0x1dfcac */
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
        // More views than tracks: trim the pool back towards the track count, unmounting each
        // removed view. The reverse enumeration strips off the tail; the boundary is >, so it
        // deliberately leaves one spare view (indices 0..trackCount survive).
        [arrayMusicView
            enumerateObjectsWithOptions:NSEnumerationReverse
                             usingBlock:^(
                                 StorePackMusicView *musicView, NSUInteger index, BOOL *stop) {
                               /** @ghidraAddress 0x1dfcf4 */
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

    // Kick off the recommended-pack list download for this pack.
    NSURL *recommendURL = [ScratchUtil recommendPackListURL];
    NSDictionary *postDictionary = @{
        kRecommendPostKeyPackID : @(self.packInfo.packID),
        kRecommendPostKeyUserID : [EditorIDManager getKeyString:[EditorIDManager getEditorIDKey]]
    };
    recommendDownloader = [[SessionDownloader alloc] initWithURL:recommendURL
                                                  postDictionary:postDictionary
                                                        delegate:self];
    [recommendDownloader startDownloading];
    [self setRelationColor:0 selectable:NO];

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
        CGFloat linkX = kPackBackgroundWidth - linkWidth + kLinkOffsetX;
        CGRect commentFrame = labelComment.frame;
        CGFloat linkY = commentFrame.origin.y + commentFrame.size.height + kLinkOffsetY;
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
      /** @ghidraAddress 0x1dfd8c */
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
      /** @ghidraAddress 0x1dfeb0 */
      [musicView.artworkView startDownloadImage];
    }];

    isInfoLoaded = YES;
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(finishBgm:)
                                               name:kFinishBgmNotificationName
                                             object:nil];
}

/** @ghidraAddress 0x1dfef8 */
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

/** @ghidraAddress 0x1e0114 */
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

#pragma mark - Relation tabs

/** @ghidraAddress 0x1dddd4 */
- (void)tapRelationButton:(id)sender {
    int tag = (int)[(UIView *)sender tag];
    if (tag == currentList) {
        return;
    }
    currentList = tag;
    [self setRelationColor:tag animate:YES];
}

/** @ghidraAddress 0x1dde3c */
- (void)setRelationColor:(int)color selectable:(BOOL)selectable {
    currentList = color;

    UIColor *activeColor = [UIColor colorWithRed:kRelationActiveColorRed
                                           green:kRelationActiveColorGreen
                                            blue:kRelationActiveColorBlue
                                           alpha:1.0];
    UIColor *unselectedBackground = UIColor.clearColor;
    UIColor *selectedTitle = [UIColor colorWithWhite:kRelationSelectedTitleWhite alpha:1.0];
    UIColor *unselectedTitle = activeColor;
    if (!selectable) {
        unselectedBackground = [UIColor colorWithWhite:kRelationDisabledBackgroundWhite alpha:1.0];
        unselectedTitle = [UIColor colorWithWhite:kRelationDisabledTitleWhite alpha:1.0];
    }

    UIButton *musicButton = relationBtnArray[0];
    UIColor *musicTitle = (color != kRelationListMusic) ? unselectedTitle : selectedTitle;
    UIColor *musicBackground = (color != kRelationListMusic) ? unselectedBackground : activeColor;
    [musicButton setBackgroundColor:musicBackground];
    [musicButton setTitleColor:musicTitle forState:UIControlStateNormal];

    UIButton *recommendButton = relationBtnArray[1];
    UIColor *recommendTitle = (color != kRelationListRecommend) ? unselectedTitle : selectedTitle;
    UIColor *recommendBackground =
        (color != kRelationListRecommend) ? unselectedBackground : activeColor;
    [recommendButton setBackgroundColor:recommendBackground];
    [recommendButton setTitleColor:recommendTitle forState:UIControlStateNormal];

    if (color == kRelationListRecommend) {
        [musicViewBg setHidden:YES];
        [packViewBg setHidden:NO];
    } else if (color == kRelationListMusic) {
        [musicViewBg setHidden:NO];
        [packViewBg setHidden:YES];
    }
}

/** @ghidraAddress 0x1de130 */
- (void)setRelationColor:(int)color animate:(BOOL)animate {
    UIColor *activeColor = [UIColor colorWithRed:kRelationActiveColorRed
                                           green:kRelationActiveColorGreen
                                            blue:kRelationActiveColorBlue
                                           alpha:1.0];
    UIColor *unselectedBackground = UIColor.clearColor;
    UIColor *selectedTitle = [UIColor colorWithWhite:kRelationSelectedTitleWhite alpha:1.0];

    UIButton *musicButton = relationBtnArray[0];
    UIColor *musicTitle = (color != kRelationListMusic) ? activeColor : selectedTitle;
    UIColor *musicBackground = (color != kRelationListMusic) ? unselectedBackground : activeColor;
    [musicButton setBackgroundColor:musicBackground];
    [musicButton setTitleColor:musicTitle forState:UIControlStateNormal];

    UIButton *recommendButton = relationBtnArray[1];
    UIColor *recommendTitle = (color != kRelationListRecommend) ? activeColor : selectedTitle;
    UIColor *recommendBackground =
        (color != kRelationListRecommend) ? unselectedBackground : activeColor;
    [recommendButton setBackgroundColor:recommendBackground];
    [recommendButton setTitleColor:recommendTitle forState:UIControlStateNormal];

    if (!animate) {
        // No animation: hide and show the tab backgrounds outright.
        if (color == kRelationListRecommend) {
            [musicViewBg setHidden:YES];
            [packViewBg setHidden:NO];
        } else if (color == kRelationListMusic) {
            [musicViewBg setHidden:NO];
            [packViewBg setHidden:YES];
        }
        return;
    }

    // Cross-fade the two tab backgrounds. Selecting the music tab (index 0) fades the recommend
    // background out and the music background in, and vice versa.
    UIScrollView *outgoing = (color == kRelationListMusic) ? packViewBg : musicViewBg;
    UIScrollView *incoming = (color == kRelationListMusic) ? musicViewBg : packViewBg;
    __weak UIScrollView *weakOutgoing = outgoing;
    __weak UIScrollView *weakIncoming = incoming;

    [outgoing setAlpha:1.0];
    [incoming setAlpha:0.0];
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];

    [UIView animateWithDuration:kRelationCrossFadeDuration
        delay:0.0
        options:UIViewAnimationOptionCurveLinear
        animations:^{
          /** @ghidraAddress 0x1de56c */
          // First leg: fade the outgoing background out.
          [weakOutgoing setAlpha:0.0];
        }
        completion:^(BOOL __attribute__((unused)) finished) {
          /** @ghidraAddress 0x1de5b8 */
          // Retire the outgoing background (reset to opaque for reuse, then hide), prime the
          // incoming one (unhide at zero alpha), and start the second leg.
          [weakOutgoing setAlpha:1.0];
          [weakOutgoing setHidden:YES];
          [weakIncoming setHidden:NO];
          [weakIncoming setAlpha:0.0];
          [UIView animateWithDuration:kRelationCrossFadeDuration
              delay:0.0
              options:UIViewAnimationOptionCurveLinear
              animations:^{
                /** @ghidraAddress 0x1de70c */
                // Second leg: fade the incoming background in.
                [weakIncoming setAlpha:1.0];
              }
              completion:^(BOOL __attribute__((unused)) finished2) {
                /** @ghidraAddress 0x1de758 */
                // A capture-free global block: re-enable touch input at the end of the sequence.
                [[UIApplication sharedApplication] endIgnoringInteractionEvents];
              }];
        }];
}

#pragma mark - Purchase state

/** @ghidraAddress 0x1de9d0 */
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
                [buttonPurchase setEnabled:YES];
                buttonTitle = [NSBundle.mainBundle localizedStringForKey:@"DOWNLOAD"
                                                                   value:@""
                                                                   table:nil];
                buttonColor = [[UIColor alloc] initWithRed:kRedownloadColorRed
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
        buttonColor = [[UIColor alloc] initWithRed:kPendingColorRed
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
        buttonColor = [[UIColor alloc] initWithRed:kBuyColorRed
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
    // V2 addition: the recommend-pack table shares this refresh point.
    [recommendPackTableView reloadData];
}

#pragma mark - Purchase actions

/** @ghidraAddress 0x1e0330 */
- (void)doPurchase:(id)sender {
    [self stopSample];
    if (allowsRedownload) {
        if ([self.delegate respondsToSelector:@selector(detailViewStartRedownload:)]) {
            // The V2 view forwards itself, not its pack info, to the redownload delegate.
            [self.delegate performSelector:@selector(detailViewStartRedownload:) withObject:self];
        }
    } else {
        if ([self.delegate respondsToSelector:@selector(detailViewStartPurchase:)]) {
            // The V2 view forwards itself, not its pack info, to the purchase delegate.
            [self.delegate performSelector:@selector(detailViewStartPurchase:) withObject:self];
        }
    }
}

/** @ghidraAddress 0x1e0448 */
- (void)downloadExtendMusic:(id)sender {
    [self stopSample];
    [buttonExtendDownload setHidden:YES];
    if ([self.delegate respondsToSelector:@selector(detailViewStartExtendDownload:)]) {
        [self.delegate performSelector:@selector(detailViewStartExtendDownload:)
                            withObject:self.packInfo];
    }
}

#pragma mark - Link

/** @ghidraAddress 0x1e0550 */
- (void)handleLink:(id)sender {
    NSString *urlString = nil;
    NSString *alertTitle = nil;
    NSString *alertMessage = nil;

    if (buttonLink == sender) {
        // The pack-level link button: confirm opening the related site in Safari. The V2 view
        // puts the formatted prompt in the alert message and leaves the title nil.
        NSString *format = [NSBundle.mainBundle localizedStringForKey:@"Open \"%@\" in Safari?"
                                                                value:@""
                                                                table:nil];
        alertMessage =
            [NSString stringWithFormat:format, [buttonLink titleForState:UIControlStateNormal]];
        urlString = self.packInfo.linkURL;
    } else {
        // A tune's link button: find which tune view owns it, then confirm opening iTunes.
        __block int matchedIndex = kNoSamplePlaying;
        [arrayMusicView enumerateObjectsUsingBlock:^(
                            StorePackMusicView *musicView, NSUInteger index, BOOL *stop) {
          /** @ghidraAddress 0x1e0ab4 */
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

/** @ghidraAddress 0x1e0b8c */
- (void)handleSample:(id)sender {
    __block int matchedIndex = kNoSamplePlaying;
    [arrayMusicView
        enumerateObjectsUsingBlock:^(StorePackMusicView *musicView, NSUInteger index, BOOL *stop) {
          /** @ghidraAddress 0x1e0f04 */
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

/** @ghidraAddress 0x1e0fdc */
- (void)finishBgm:(NSNotification *)notification {
    for (StorePackMusicView *musicView in arrayMusicView) {
        [musicView sampleStop];
    }
    samplePlaying = kNoSamplePlaying;
}

#pragma mark - DownloaderDelegate

/** @ghidraAddress 0x1e1114 */
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
    } else if (recommendDownloader == downloader) {
        NSDictionary *json = [downloader getDataInJSON];
        if (json[kResponseKeyStatus] != nil && [json[kResponseKeyStatus] intValue] == 0) {
            NSArray *packList = [json arrayForKey:kResponseKeyPackList];
            if (packList.count != 0) {
                // Collect the product identifiers of every recommended pack and request them.
                NSMutableSet *productIDs = [[NSMutableSet alloc] init];
                recommendPackDictArray = [packList copy];
                for (id entry in packList) {
                    if ([entry isKindOfClass:[NSDictionary class]]) {
                        NSNumber *packID = [entry numberForKey:kEntryKeyID];
                        if (packID) {
                            [productIDs addObject:[StoreUtil productIDForPackID:packID.intValue]];
                        }
                    }
                }
                if (productIDs.count != 0) {
                    productsRequest =
                        [[SKProductsRequest alloc] initWithProductIdentifiers:productIDs];
                    productsRequest.delegate = self;
                    [productsRequest start];
                }
            }
        }
    }
}

/** @ghidraAddress 0x1e1828 */
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

/** @ghidraAddress 0x1e1c08 */
- (void)downloaderProceed:(id)downloader {
    // The shipped body is empty.
}

#pragma mark - AlertViewManagerDelegate

/** @ghidraAddress 0x1e1c0c */
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

/** @ghidraAddress 0x1e1df8 */
- (void)alertClose:(NSDictionary *)info {
    if ([info[kAlertKeyTag] intValue] == kErrorAlertTag) {
        if ([self.viewController respondsToSelector:@selector(storePackDetailViewClose)]) {
            [self.viewController performSelector:@selector(storePackDetailViewClose)];
        }
    }
}

/** @ghidraAddress 0x1e1ef4 */
- (void)detailClose {
    [[AlertViewManager sharedManager] closeAlert];
}

#pragma mark - Activity

/** @ghidraAddress 0x1e1f3c */
- (void)setInactive {
    [self addSubview:backButton];
}

/** @ghidraAddress 0x1e1f54 */
- (void)setActive {
    [backButton removeFromSuperview];
}

/** @ghidraAddress 0x1e1f6c */
- (void)popOutDetailView {
    if ([self.delegate respondsToSelector:@selector(popDetailList)]) {
        [self.delegate performSelector:@selector(popDetailList)];
    }
}

#pragma mark - SKProductsRequestDelegate

/** @ghidraAddress 0x1e201c */
- (void)productsRequest:(SKProductsRequest *)request
     didReceiveResponse:(SKProductsResponse *)response {
    NSMutableArray *packs = [[NSMutableArray alloc] init];

    // Cache the store's country from the last product's locale.
    if (response.products.count != 0) {
        NSString *country =
            [response.products.lastObject.priceLocale objectForKey:NSLocaleCountryCode];
        if (storeCountry == nil || ![storeCountry isEqualToString:country]) {
            storeCountry = [[NSString alloc] initWithString:country];
        }
    }

    // Match each recommended-pack dictionary to a returned product by pack identifier.
    NSArray *dictArray = [recommendPackDictArray copy];
    for (NSDictionary *entry in dictArray) {
        if (entry != nil) {
            for (SKProduct *product in response.products) {
                int entryID = [entry numberForKey:kEntryKeyID].intValue;
                int productPackID = [StoreUtil packIDForProductID:product.productIdentifier];
                if (entryID == productPackID) {
                    [packs addObject:[[StorePackInfo alloc] initWithDictionary:entry
                                                                       product:product]];
                }
            }
        }
    }
    recommendPackList = [packs copy];

    // Re-enable the relation-tab buttons.
    for (UIButton *button in relationBtnArray) {
        button.enabled = YES;
    }

    recommendPackTableView.packList = nil;
    recommendPackTableView.packList = recommendPackList;
    recommendPackTableView.parentInfo = self.packInfo;
    recommendPackTableView.parentView = self.viewController;
    [recommendPackTableView reloadData];

    // Colour the relation strip for the tune-list tab.
    [self setRelationColor:kRelationListMusic selectable:YES];
}

@end
