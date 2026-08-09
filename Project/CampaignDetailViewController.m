#import "CampaignDetailViewController.h"

#import "AlertViewManager.h"
#import "CampaignItemInfo.h"
#import "Downloader.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"
#import "StoreLoadingView.h"
#import "StoreUtil.h"

// StoreCampaignViewController owns this page and is only messaged, never sized, here; it is not yet
// reconstructed, so declare the selectors this class sends to it.
@interface StoreCampaignViewController : UIViewController
- (void)itemDownload;
- (void)moveExternalLink;
- (void)itemDeselect;
@end

// The two alternating pack-background arts for the terms and copyright rows.
static NSString *const kPackBackgroundImage0Name = @"store_pack_bg_0";
static NSString *const kPackBackgroundImage1Name = @"store_pack_bg_1";

// The reuse identifiers for the two rows.
static NSString *const kTermsCellReuseIdentifier = @"StoreDetailTerms";
static NSString *const kCopyrightCellReuseIdentifier = @"StoreDetailCopyRight";

// The finish notification the header observes. The typo is the binary's, not the reconstruction's.
static NSString *const kFinishBgmNotificationName = @"JubeatAudioManagerFinishBgmNotifacation";

// The root view's top-to-bottom gradient, from RGB components in the pool at 0x28fad8 and 0x28faf0.
static const CGFloat kGradientTopRed = 0.725f;      // @ghidraAddress 0x28fad8
static const CGFloat kGradientTopGreen = 0.731f;    // @ghidraAddress 0x28fae0
static const CGFloat kGradientTopBlue = 0.737f;     // @ghidraAddress 0x28fae8
static const CGFloat kGradientBottomRed = 0.467f;   // @ghidraAddress 0x28faf0
static const CGFloat kGradientBottomGreen = 0.489f; // @ghidraAddress 0x28faf8
static const CGFloat kGradientBottomBlue = 0.511f;  // @ghidraAddress 0x28fb00

// The table's background white and the copyright label's text-colour white.
static const CGFloat kTableBackgroundWhite = 0.4f; // @ghidraAddress 0x28f2c0
static const CGFloat kCopyrightTextWhite = 0.3f;   // @ghidraAddress 0x28f248

// The white and alpha applied to the copyright row's cell background.
static const CGFloat kCopyrightRowBackgroundWhite = 0.6f; // @ghidraAddress 0x28f230

// The pack-background art's resizable cap inset on every edge (fmov immediate at 0x1e8ec0).
static const CGFloat kPackBackgroundCapInset = 4.0f;

// The initial header height and the loading overlay's size (pool at 0x28f210, 0x28f2d0, 0x28f400).
static const CGFloat kHeaderInitialHeight = 120.0f; // @ghidraAddress 0x28f210
static const CGFloat kLoadingViewWidth = 300.0f;    // @ghidraAddress 0x28f2d0
static const CGFloat kLoadingViewHeight = 200.0f;   // @ghidraAddress 0x28f400

// The terms and copyright label font sizes (fmov immediates at 0x1e9280 and 0x1e93b0).
static const CGFloat kTermsFontSize = 16.0f;
static const CGFloat kCopyrightFontSize = 10.0f;

// The two extra vertical points each label's height grows by after sizing to its text (fmov
// immediates at 0x1e9730 and 0x1e97d0).
static const CGFloat kTermsHeightPadding = 16.0f;
static const CGFloat kCopyrightHeightPadding = 8.0f;

// The default terms-row height when the item carries no unlock description, and the copyright-row
// height when it carries no licence text (pool at 0x28f258; fmov immediate 20.0 for the copyright
// case).
static const CGFloat kTermsRowDefaultHeight = 60.0f; // @ghidraAddress 0x28f258
static const CGFloat kCopyrightRowDefaultHeight = 20.0f;

// The two table rows: the item's unlock terms above its licence copyright.
typedef enum : NSInteger {
    CampaignDetailRowTerms = 0,     // The unlock-terms row.
    CampaignDetailRowCopyright = 1, // The licence-copyright row.
} CampaignDetailRow;

@implementation CampaignDetailViewController {
    int rowSamplePlayed;
    BOOL isDownloadingSample;
    BOOL allowsRedownload;
    BOOL bDismissing;
    CampaignItemInfo *itemInfo;
    CampaignDetailHeaderView *headerView;
    UITableView *detailTableView;
    StoreLoadingView *loadingView;
    Downloader *infoDownloader;
    ImageDownloader *itemIconDownloader;
    UIImage *packBgImage0;
    UIImage *packBgImage1;
    SKStoreProductViewController *itunesViewCtrl;
    UILabel *labelItemTerms;
    UILabel *labelCopyRight;
}

#pragma mark - Lifecycle

/** @ghidraAddress 0x1e8b40 */
- (instancetype)init {
    self = [super init];
    if (self) {
        self.navigationItem.title = @"info";
        if ([self respondsToSelector:@selector(setExtendedLayoutIncludesOpaqueBars:)]) {
            [self performSelector:@selector(setExtendedLayoutIncludesOpaqueBars:) withObject:nil];
        }
    }
    return self;
}

/** @ghidraAddress 0x1e8bfc */
- (void)loadView {
    [super loadView];
    self.view.opaque = YES;
    CGRect bounds = self.view.bounds;

    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = bounds;
    gradient.opaque = YES;
    UIColor *topColor = [UIColor colorWithRed:kGradientTopRed
                                        green:kGradientTopGreen
                                         blue:kGradientTopBlue
                                        alpha:1.0f];
    UIColor *bottomColor = [UIColor colorWithRed:kGradientBottomRed
                                           green:kGradientBottomGreen
                                            blue:kGradientBottomBlue
                                           alpha:1.0f];
    gradient.colors = @[ (__bridge id)topColor.CGColor, (__bridge id)bottomColor.CGColor ];
    [self.view.layer addSublayer:gradient];

    CGFloat tableHeight = bounds.size.height - (CGFloat)[StoreUtil storeTabHeaderHeight] -
                          (CGFloat)[StoreUtil storeTabFooterHeight];

    UIEdgeInsets caps = UIEdgeInsetsMake(kPackBackgroundCapInset,
                                         kPackBackgroundCapInset,
                                         kPackBackgroundCapInset,
                                         kPackBackgroundCapInset);
    packBgImage0 = [LoadScaledPngImage(kPackBackgroundImage0Name) resizableImageWithCapInsets:caps];
    packBgImage1 = [LoadScaledPngImage(kPackBackgroundImage1Name) resizableImageWithCapInsets:caps];

    detailTableView = [[UITableView alloc]
        initWithFrame:CGRectMake(bounds.origin.x, bounds.origin.y, bounds.size.width, tableHeight)
                style:UITableViewStylePlain];
    detailTableView.opaque = YES;
    detailTableView.allowsSelection = NO;
    detailTableView.backgroundColor = [UIColor colorWithWhite:kTableBackgroundWhite alpha:1.0f];
    detailTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    detailTableView.dataSource = self;
    detailTableView.delegate = self;
    CGRect tableFrame = detailTableView.frame;

    headerView = [[CampaignDetailHeaderView alloc]
        initWithFrame:CGRectMake(0.0f, 0.0f, tableFrame.size.width, kHeaderInitialHeight)];
    headerView.delegate = self;

    loadingView = [[StoreLoadingView alloc]
        initWithFrame:CGRectMake(0.0f, 0.0f, kLoadingViewWidth, kLoadingViewHeight)];
    loadingView.center =
        CGPointMake((CGFloat)((int)bounds.size.width >> 1), (CGFloat)((int)tableHeight >> 1));
    loadingView.hidden = YES;
    [self.view addSubview:loadingView];

    rowSamplePlayed = -1;
    bDismissing = NO;

    labelItemTerms = [[UILabel alloc]
        initWithFrame:CGRectMake(0.0f, 0.0f, tableFrame.size.width, kHeaderInitialHeight)];
    labelItemTerms.backgroundColor = UIColor.clearColor;
    labelItemTerms.numberOfLines = 0;
    labelItemTerms.lineBreakMode = NSLineBreakByWordWrapping;
    labelItemTerms.font = [UIFont systemFontOfSize:kTermsFontSize];

    CGRect tableFrameForCopyright = detailTableView.frame;
    labelCopyRight = [[UILabel alloc]
        initWithFrame:CGRectMake(0.0f, 0.0f, tableFrameForCopyright.size.width, 0.0f)];
    labelCopyRight.backgroundColor = UIColor.clearColor;
    labelCopyRight.numberOfLines = 0;
    labelCopyRight.lineBreakMode = NSLineBreakByWordWrapping;
    labelCopyRight.textColor = [UIColor colorWithWhite:kCopyrightTextWhite alpha:1.0f];
    labelCopyRight.font = [UIFont systemFontOfSize:kCopyrightFontSize];
}

/** @ghidraAddress 0x1ea1a0 */
- (void)dealloc {
    [self.viewController itemDeselect];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kFinishBgmNotificationName
                                                  object:nil];
    [infoDownloader cancel];
    [headerView stopSample];
    [self stopDownloadArtworks];
}

#pragma mark - Campaign item

/** @ghidraAddress 0x1e9430 */
- (void)setCampaignInfo:(nullable CampaignItemInfo *)campaignInfo {
    itemInfo = campaignInfo;
}

/** @ghidraAddress 0x1e9444 */
- (void)removeCampaignInfo {
    itemInfo = nil;
}

/** @ghidraAddress 0x1e945c */
- (void)updateCampaignState:(nullable CampaignItemInfo *)campaignInfo {
    itemInfo = campaignInfo;
    [headerView updateCampaignState:campaignInfo];
}

/** @ghidraAddress 0x1e94bc */
- (void)refreshCampaignItem:(nullable CampaignItemInfo *)campaignInfo {
    [self stopDownloadArtworks];
    [headerView stopSample];
    itemInfo = campaignInfo;
    [self loadInfo];
    [detailTableView reloadData];
}

/** @ghidraAddress 0x1e9564 */
- (void)showPackInfo {
    // The shipped body is empty.
}

/** @ghidraAddress 0x1e9568 */
- (void)loadInfo {
    [headerView setCampaignInfo:itemInfo];
    detailTableView.tableHeaderView = headerView;
    [self.view addSubview:detailTableView];

    NSURL *iconURL = [NSURL URLWithString:itemInfo.itemImageURL];
    if (iconURL) {
        itemIconDownloader = [[ImageDownloader alloc] initWithImageURL:iconURL forKey:nil];
        itemIconDownloader.delegate = self;
        [itemIconDownloader startDownload];
    }

    if (itemInfo.unlockDescription) {
        labelItemTerms.text = itemInfo.unlockDescription;
        [labelItemTerms sizeToFit];
        CGRect frame = labelItemTerms.frame;
        frame.size.height += kTermsHeightPadding;
        labelItemTerms.frame = frame;
    }

    if (itemInfo.lisenceText) {
        labelCopyRight.text = itemInfo.lisenceText;
        [labelCopyRight sizeToFit];
        CGRect frame = labelCopyRight.frame;
        frame.size.height += kCopyrightHeightPadding;
        labelCopyRight.frame = frame;
    }
}

#pragma mark - Header delegate

/** @ghidraAddress 0x1e9800 */
- (void)doPurchase:(nullable id)sender {
    [self.viewController itemDownload];
}

/** @ghidraAddress 0x1e9840 */
- (void)handleLink:(nullable id)sender {
    [self.viewController moveExternalLink];
}

#pragma mark - SKStoreProductViewController delegate

/** @ghidraAddress 0x1e9880 */
- (void)productViewControllerDidFinish:(nonnull SKStoreProductViewController *)viewController {
    [self dismissViewControllerAnimated:YES
                             completion:^{
                               /** @ghidraAddress 0x1e98e8 */
                               // Clear the reference only after the dismissal animation
                               // finishes, which keeps the product controller alive while it is
                               // still on screen.
                               self->itunesViewCtrl = nil;
                             }];
}

#pragma mark - Downloader delegate

/** @ghidraAddress 0x1e9910 */
- (void)downloaderProceed:(nullable id)downloader {
    // The shipped body is empty.
}

#pragma mark - ImageDownloader delegate

/** @ghidraAddress 0x1e9cb0 */
- (void)imageDownloader:(nonnull ImageDownloader *)downloader didLoad:(nullable id)key {
    [headerView setArtwork:[downloader getImage]];
}

#pragma mark - Table data source

/** @ghidraAddress 0x1e9914 */
- (NSInteger)numberOfSectionsInTableView:(nonnull UITableView *)tableView {
    return 1;
}

/** @ghidraAddress 0x1e991c */
- (NSInteger)tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 2;
}

/** @ghidraAddress 0x1e9924 */
- (nullable UITableViewCell *)tableView:(nonnull UITableView *)tableView
                  cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    if (indexPath.row == CampaignDetailRowCopyright) {
        UITableViewCell *cell =
            [tableView dequeueReusableCellWithIdentifier:kCopyrightCellReuseIdentifier];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                          reuseIdentifier:kCopyrightCellReuseIdentifier];
        }
        [cell addSubview:labelCopyRight];
        return cell;
    }
    if (indexPath.row == CampaignDetailRowTerms) {
        UITableViewCell *cell =
            [tableView dequeueReusableCellWithIdentifier:kTermsCellReuseIdentifier];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                          reuseIdentifier:kTermsCellReuseIdentifier];
        }
        [cell addSubview:labelItemTerms];
        return cell;
    }
    return nil;
}

#pragma mark - Table delegate

/** @ghidraAddress 0x1e9b04 */
- (CGFloat)tableView:(nonnull UITableView *)tableView
    heightForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    if (indexPath.row == CampaignDetailRowCopyright) {
        if (!itemInfo.lisenceText) {
            return kCopyrightRowDefaultHeight;
        }
        return labelCopyRight.frame.size.height;
    }
    if (indexPath.row != CampaignDetailRowTerms) {
        return 0.0f;
    }
    if (!itemInfo.unlockDescription) {
        return kTermsRowDefaultHeight;
    }
    return labelItemTerms.frame.size.height;
}

/** @ghidraAddress 0x1e9bd4 */
- (void)tableView:(nonnull UITableView *)tableView
      willDisplayCell:(nonnull UITableViewCell *)cell
    forRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    if (indexPath.row == CampaignDetailRowCopyright) {
        cell.backgroundColor = [UIColor colorWithWhite:kCopyrightRowBackgroundWhite alpha:1.0f];
        return;
    }
    if (indexPath.row != CampaignDetailRowTerms) {
        return;
    }
    // Only packBgImage1 is ever shown; packBgImage0 is loaded in -loadView but never displayed.
    cell.backgroundView = [[UIImageView alloc] initWithImage:packBgImage1];
}

/** @ghidraAddress 0x1e9cac */
- (void)tableView:(nonnull UITableView *)tableView
    didSelectRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    // The shipped body is empty.
}

#pragma mark - Teardown

/** @ghidraAddress 0x1e9d30 */
- (void)removeItem {
    headerView = nil;
    detailTableView = nil;
    loadingView = nil;
    labelItemTerms = nil;
    labelCopyRight = nil;
    [self stopDownloadArtworks];
}

/** @ghidraAddress 0x1e9dbc */
- (void)stopDownloadArtworks {
    [itemIconDownloader cancelDownload];
    itemIconDownloader.delegate = nil;
}

/** @ghidraAddress 0x1e9e00 */
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

/** @ghidraAddress 0x1e9e38 */
- (void)viewDidUnload {
    [super viewDidUnload];
    headerView = nil;
    detailTableView = nil;
    loadingView = nil;
    packBgImage0 = nil;
    packBgImage1 = nil;
    labelItemTerms = nil;
    labelCopyRight = nil;
    [self stopDownloadArtworks];
}

#pragma mark - View appearance

/** @ghidraAddress 0x1e9f18 */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

/** @ghidraAddress 0x1e9f50 */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:headerView
                                             selector:@selector(finishBgm:)
                                                 name:kFinishBgmNotificationName
                                               object:nil];
    if (!detailTableView.superview) {
        [self loadInfo];
    }
}

/** @ghidraAddress 0x1ea024 */
- (void)viewWillDisappear:(BOOL)animated {
    if (!bDismissing) {
        [[AlertViewManager sharedManager] closeAlert];
        bDismissing = YES;
    }
    [super viewWillDisappear:animated];
    [headerView stopSample];
    [[NSNotificationCenter defaultCenter] removeObserver:headerView
                                                    name:kFinishBgmNotificationName
                                                  object:nil];
    if (infoDownloader) {
        [infoDownloader cancel];
        infoDownloader = nil;
    }
}

/** @ghidraAddress 0x1ea148 */
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

#pragma mark - Rotation

/** @ghidraAddress 0x1ea180 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // The comparison is unsigned, so only portrait (1) and upside-down (2) pass.
    return (NSUInteger)(interfaceOrientation - 1) < 2;
}

/** @ghidraAddress 0x1ea190 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    // The binary returns 6, which is portrait plus upside-down (not landscape); this agrees with
    // -shouldAutorotateToInterfaceOrientation: allowing only the two portrait orientations.
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

/** @ghidraAddress 0x1ea198 */
- (BOOL)shouldAutorotate {
    return YES;
}

#pragma mark - Closing

/** @ghidraAddress 0x1ea294 */
- (void)detailClose {
    NSInteger rows = [self tableView:detailTableView numberOfRowsInSection:0];
    for (NSInteger row = 0; row < (int)rows; ++row) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
        UITableViewCell *cell = [detailTableView cellForRowAtIndexPath:indexPath];
        if ([cell respondsToSelector:@selector(detailClose)]) {
            [cell performSelector:@selector(detailClose)];
        }
    }
}

@end
