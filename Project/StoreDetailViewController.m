#import "StoreDetailViewController.h"

#import "AlertViewManager.h"
#import "AudioManager.h"
#import "ImageCache.h"
#import "ImageDownloader.h"
#import "ImageLoading.h"
#import "PurchaseManager.h"
#import "StoreButton.h"
#import "StoreDetailCopyrightCell.h"
#import "StoreDetailHeaderView.h"
#import "StoreDetailMusicCell.h"
#import "StoreLoadingView.h"
#import "StoreMusicInfo.h"
#import "StoreMusicListManager.h"
#import "StorePackInfo.h"
#import "StoreUtil.h"

// The cell reuse identifiers, both taken verbatim from __const.
static NSString *const kMusicCellReuseIdentifier = @"StoreDetailTableMusicCell";
static NSString *const kCopyrightCellReuseIdentifier = @"StoreDetailTableCopyrightCell";

// The two alternating pack-row background images and the jacket placeholder.
static NSString *const kPackBgImage0Name = @"store_pack_bg_0";
static NSString *const kPackBgImage1Name = @"store_pack_bg_1";
static NSString *const kJacketPlaceholderName = @"store_jacket_128";

// The background-music-finished notification the sample player listens for.
static NSString *const kFinishBgmNotificationName = @"JubeatAudioManagerFinishBgmNotifacation";

// The literal (non-localised) title of the pack-detail response-error alert.
static NSString *const kServerErrorTitle = @"Server Error";

// The per-row difficulty-level format string, taken verbatim from __const (two spaces after the
// colon).
static NSString *const kLevelFormat = @"LEVEL:  %d / %d / %d";

// The keys read out of the alert-result dictionary and the pack-detail response.
static NSString *const kAlertKeyButtonMessage = @"btnMessage";
static NSString *const kAlertKeyTag = @"Tag";
static NSString *const kResponseKeyError = @"Error";

// The info-download error alert's tag, and the button index that pops the navigation stack.
static const int kInfoErrorAlertTag = 1;
static const int kConfirmButtonIndex = 1;

// The navigation title (a literal CFString, not a localised string).
static NSString *const kNavigationTitle = @"info";

// The number of downloader slots the artwork map is seeded with.
static const NSUInteger kArtworkDownloaderCapacity = 32;

// The measurement height the header is built with before it lays itself out to fit.
static const CGFloat kHeaderMeasureHeight = 120.0; // @ghidraAddress 0x28f210

// The loading overlay's size.
static const CGFloat kLoadingViewWidth = 300.0;  // @ghidraAddress 0x28f2d0
static const CGFloat kLoadingViewHeight = 200.0; // @ghidraAddress 0x28f400

// The copyright text is measured into a fixed-width, effectively unbounded-height box (the width
// slot is shared with the loading overlay's width at 0x28f2d0).
static const CGFloat kCopyrightMeasureWidth = 300.0;   // @ghidraAddress 0x28f2d0
static const CGFloat kCopyrightMeasureHeight = 9000.0; // @ghidraAddress 0x291df0

// The pooled greys behind the table and behind the copyright row.
static const CGFloat kTableBackgroundWhite = 0.4;        // @ghidraAddress 0x28f2c0
static const CGFloat kCopyrightRowBackgroundWhite = 0.6; // @ghidraAddress 0x28f230

// The fade-out time -stopSample and -viewWillDisappear: hand the audio manager.
static const NSTimeInterval kSampleFadeOutTime = 0.2; // @ghidraAddress 0x28e040

// The root gradient: an opaque grey vertical ramp, top lighter than bottom.
static const CGFloat kGradientTopRed = 0.725;      // @ghidraAddress 0x28fad8
static const CGFloat kGradientTopGreen = 0.731;    // @ghidraAddress 0x28fae0
static const CGFloat kGradientTopBlue = 0.737;     // @ghidraAddress 0x28fae8
static const CGFloat kGradientBottomRed = 0.467;   // @ghidraAddress 0x28faf0
static const CGFloat kGradientBottomGreen = 0.489; // @ghidraAddress 0x28faf8
static const CGFloat kGradientBottomBlue = 0.511;  // @ghidraAddress 0x28fb00

// The purchase button's three colour states.
static const CGFloat kBuyColorRed = 0.2;   // @ghidraAddress 0x28f240
static const CGFloat kBuyColorGreen = 0.7; // @ghidraAddress 0x291c98
static const CGFloat kBuyColorBlue = 0.2;  // @ghidraAddress 0x28f240

static const CGFloat kRedownloadColorRed = 0.2;    // @ghidraAddress 0x28f240
static const CGFloat kRedownloadColorGreen = 0.35; // @ghidraAddress 0x291cb0
static const CGFloat kRedownloadColorBlue = 0.9;   // @ghidraAddress 0x28f448

static const CGFloat kPendingColorRed = 0.1;  // @ghidraAddress 0x28f2b8
static const CGFloat kPendingColorBlue = 0.8; // @ghidraAddress 0x28e080

// The resizable pack-background cap inset (fmov 4.0), the copyright font size and row-frame origin
// (fmov 10.0), and the copyright row's extra height (fmov 20.0) are all fmov immediates.
static const CGFloat kPackBgCapInset = 4.0;
static const CGFloat kCopyrightFontSize = 10.0;
static const CGFloat kCopyrightFrameOrigin = 10.0;
static const CGFloat kCopyrightRowExtraHeight = 20.0;

// The sentinel stored in rowSamplePlayed when no row is playing a sample.
static const int kNoSampleRow = -1;

@implementation StoreDetailViewController {
    int rowSamplePlayed;
    BOOL isDownloadingSample;
    BOOL allowsRedownload;
    BOOL bDismissing;
    StoreDetailHeaderView *headerView;
    UITableView *detailTableView;
    StoreLoadingView *loadingView;
    Downloader *infoDownloader;
    Downloader *sampleDownloader;
    NSMutableDictionary *artworkDownloaders;
    UIImage *packBgImage0;
    UIImage *packBgImage1;
    SKStoreProductViewController *itunesViewCtrl;
    BOOL _bRestore;
    StorePackInfo *_packInfo;
    __weak id<StoreDetailViewControllerDelegate> _delegate;
    __weak id<StoreDetailViewControllerCloseDelegate> _closeDelegate;
}

@synthesize packInfo = _packInfo;
@synthesize delegate = _delegate;
@synthesize closeDelegate = _closeDelegate;
@synthesize bRestore = _bRestore;

#pragma mark - Lifecycle

/** @ghidraAddress 0xece2c */
- (instancetype)init {
    self = [super init];
    if (self) {
        self.navigationItem.title = kNavigationTitle;
        if ([self respondsToSelector:@selector(setExtendedLayoutIncludesOpaqueBars:)]) {
            [self performSelector:@selector(setExtendedLayoutIncludesOpaqueBars:) withObject:nil];
        }
    }
    return self;
}

/** @ghidraAddress 0xecee8 */
- (void)loadView {
    [super loadView];
    self.view.opaque = YES;
    CGRect bounds = self.view.bounds;

    // An opaque grey vertical gradient filling the whole view.
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = bounds;
    gradient.opaque = YES;
    UIColor *topColor = [UIColor colorWithRed:kGradientTopRed
                                        green:kGradientTopGreen
                                         blue:kGradientTopBlue
                                        alpha:1.0];
    UIColor *bottomColor = [UIColor colorWithRed:kGradientBottomRed
                                           green:kGradientBottomGreen
                                            blue:kGradientBottomBlue
                                           alpha:1.0];
    gradient.colors = @[ (__bridge id)topColor.CGColor, (__bridge id)bottomColor.CGColor ];
    [self.view.layer addSublayer:gradient];

    // The table fills the view below the tab header and above the tab footer.
    CGFloat headerHeight = [StoreUtil storeTabHeaderHeight];
    CGFloat footerHeight = [StoreUtil storeTabFooterHeight];
    CGRect tableFrame = CGRectMake(bounds.origin.x,
                                   bounds.origin.y,
                                   bounds.size.width,
                                   bounds.size.height - headerHeight - footerHeight);
    detailTableView = [[UITableView alloc] initWithFrame:tableFrame style:UITableViewStylePlain];
    detailTableView.opaque = YES;
    detailTableView.backgroundColor = [UIColor colorWithWhite:kTableBackgroundWhite alpha:1.0];
    detailTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    detailTableView.dataSource = self;
    detailTableView.delegate = self;

    // The header spans the table's width; its measurement height is refined in -loadPackInfo:.
    CGRect headerFrame =
        CGRectMake(0.0, 0.0, detailTableView.frame.size.width, kHeaderMeasureHeight);
    headerView = [[StoreDetailHeaderView alloc] initWithFrame:headerFrame];
    [headerView.buttonPurchase setTitle:[NSBundle.mainBundle localizedStringForKey:@"Purchased"
                                                                             value:@""
                                                                             table:nil]
                               forState:UIControlStateDisabled];
    [headerView.buttonPurchase addTarget:self
                                  action:@selector(doPurchase:)
                        forControlEvents:UIControlEventTouchUpInside];
    [headerView.buttonExtendDownload addTarget:self
                                        action:@selector(downloadExtendMusic:)
                              forControlEvents:UIControlEventTouchUpInside];

    // The loading overlay, centred on the table area and hidden until a download starts.
    CGRect loadingFrame = CGRectMake(0.0, 0.0, kLoadingViewWidth, kLoadingViewHeight);
    loadingView = [[StoreLoadingView alloc] initWithFrame:loadingFrame];
    loadingView.center = CGPointMake((int)bounds.size.width >> 1, (int)tableFrame.size.height >> 1);
    loadingView.hidden = YES;
    [self.view addSubview:loadingView];

    UIEdgeInsets caps =
        UIEdgeInsetsMake(kPackBgCapInset, kPackBgCapInset, kPackBgCapInset, kPackBgCapInset);
    packBgImage0 = [LoadScaledPngImage(kPackBgImage0Name) resizableImageWithCapInsets:caps];
    packBgImage1 = [LoadScaledPngImage(kPackBgImage1Name) resizableImageWithCapInsets:caps];

    artworkDownloaders = [NSMutableDictionary dictionaryWithCapacity:kArtworkDownloaderCapacity];
    rowSamplePlayed = kNoSampleRow;
    bDismissing = NO;
}

/** @ghidraAddress 0xf0618 */
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

/** @ghidraAddress 0xf0650 */
- (void)viewDidUnload {
    [super viewDidUnload];
    headerView = nil;
    detailTableView = nil;
    loadingView = nil;
    packBgImage0 = nil;
    packBgImage1 = nil;
    [self stopDownloadArtworks];
    artworkDownloaders = nil;
}

/** @ghidraAddress 0xf071c */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (headerView && headerView.buttonExtendDownload) {
        [self updatePurchaseState];
    }
}

/** @ghidraAddress 0xf07a0 */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(finishBgm:)
                                               name:kFinishBgmNotificationName
                                             object:nil];
    if (detailTableView.superview == nil) {
        [self loadInfo];
    }
}

/** @ghidraAddress 0xf086c */
- (void)viewWillDisappear:(BOOL)animated {
    if (!bDismissing) {
        [AlertViewManager.sharedManager closeAlert];
        bDismissing = YES;
    }
    [super viewWillDisappear:animated];
    [self stopSample];
    [AudioManager.sharedManager fadeoutBgm:kSampleFadeOutTime];
    sampleDownloader = nil;
    [NSNotificationCenter.defaultCenter removeObserver:self
                                                  name:kFinishBgmNotificationName
                                                object:nil];
    if ([self.closeDelegate respondsToSelector:@selector(detailViewCloseNavigation)]) {
        [self.closeDelegate performSelector:@selector(detailViewCloseNavigation)];
    }
    if (infoDownloader) {
        [infoDownloader cancel];
        infoDownloader = nil;
    }
}

/** @ghidraAddress 0xf0a64 */
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

/** @ghidraAddress 0xf0abc */
- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self
                                                  name:kFinishBgmNotificationName
                                                object:nil];
    [infoDownloader cancel];
    [sampleDownloader cancel];
    [self stopDownloadArtworks];
    // [super dealloc] is compiler-emitted (ARC). The strong ivars are torn down by the
    // compiler-generated .cxx_destruct (0xf0d48), which is not authored here.
}

#pragma mark - Content loading

/** @ghidraAddress 0xed604 */
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
                headerView.buttonPurchase.enabled = YES;
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

        headerView.buttonExtendDownload.hidden = YES;
        if (!redownload) {
            if ([StoreUtil existDownloadableExtendMusic:self.packInfo.musicInfos]) {
                headerView.buttonExtendDownload.hidden = NO;
            }
            allowsRedownload = NO;
            headerView.buttonPurchase.enabled = NO;
        }
    } else if ([PurchaseManager.sharedManager isPending:productID]) {
        // A purchase is in flight: allow the pending download.
        allowsRedownload = YES;
        headerView.buttonPurchase.enabled = YES;
        buttonTitle = [NSBundle.mainBundle localizedStringForKey:@"DOWNLOAD" value:@"" table:nil];
        // The pending green (0.25) is an fmov immediate.
        buttonColor = [UIColor colorWithRed:kPendingColorRed
                                      green:0.25
                                       blue:kPendingColorBlue
                                      alpha:1.0];
    } else {
        // Not owned and not pending: offer the buy button at its price.
        allowsRedownload = NO;
        headerView.buttonPurchase.enabled = YES;
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
        [headerView.buttonPurchase setTitle:buttonTitle forState:UIControlStateNormal];
    }
    if (buttonColor) {
        headerView.buttonPurchase.buttonColor = buttonColor;
    }
}

/** @ghidraAddress 0xedd68 */
- (void)showPackInfo {
    [headerView loadPackInfo:self.packInfo];
    [self updatePurchaseState];
    detailTableView.tableHeaderView = headerView;

    // The header artwork is keyed by row 0 of section 1, apart from the per-row jackets.
    NSIndexPath *headerKey = [NSIndexPath indexPathForRow:0 inSection:1];
    NSURL *artworkURL = [NSURL URLWithString:self.packInfo.artworkURL];
    if (artworkURL) {
        ImageDownloader *downloader = [[ImageDownloader alloc] initWithImageURL:artworkURL
                                                                         forKey:headerKey];
        downloader.delegate = self;
        artworkDownloaders[headerKey] = downloader;
        [downloader startDownload];
    }

    [self.view addSubview:detailTableView];
    [detailTableView reloadData];
}

/** @ghidraAddress 0xedf64 */
- (void)loadInfo {
    if (!self.packInfo) {
        return;
    }
    if (self.packInfo.musicInfos == nil) {
        [loadingView startLoading];
        NSURL *url = self.bRestore ? [StoreUtil restorePackInfoURL:self.packInfo.packID] :
                                     [StoreUtil packInfoURL:self.packInfo.packID];
        infoDownloader = [[Downloader alloc] initWithURL:url delegate:self];
        [infoDownloader startDownloading];
    } else {
        [self showPackInfo];
    }
}

#pragma mark - Sample playback

/** @ghidraAddress 0xee110 */
- (void)stopSample {
    [AudioManager.sharedManager fadeoutBgm:kSampleFadeOutTime];
    sampleDownloader = nil;
    rowSamplePlayed = kNoSampleRow;
    [detailTableView reloadData];
}

/** @ghidraAddress 0xee1a0 */
- (void)finishBgm:(nullable NSNotification *)notification {
    int row = rowSamplePlayed;
    if (row >= 0 && (NSUInteger)row < self.packInfo.musicInfos.count) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
        StoreDetailMusicCell *cell =
            (StoreDetailMusicCell *)[detailTableView cellForRowAtIndexPath:indexPath];
        [cell sampleStop];
    }
    rowSamplePlayed = kNoSampleRow;
}

#pragma mark - Purchase actions

/** @ghidraAddress 0xee2ac */
- (void)doPurchase:(nullable id)sender {
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

/** @ghidraAddress 0xee408 */
- (void)downloadExtendMusic:(nullable id)sender {
    [self stopSample];
    headerView.buttonExtendDownload.hidden = YES;
    if ([self.delegate respondsToSelector:@selector(detailViewStartExtendDownload:)]) {
        [self.delegate performSelector:@selector(detailViewStartExtendDownload:)
                            withObject:self.packInfo];
    }
}

/** @ghidraAddress 0xee530 */
- (void)storeDetailViewOpenItunesWithURL:(nullable NSURL *)url {
    if (url == nil) {
        return;
    }
    NSDictionary *parameters = [StoreUtil affiliateParametersFromURL:url];
    if (parameters == nil) {
        [UIApplication.sharedApplication openURL:url];
    } else {
        itunesViewCtrl = [[SKStoreProductViewController alloc] init];
        itunesViewCtrl.delegate = self;
        [self presentViewController:itunesViewCtrl
                           animated:YES
                         completion:^{
                           /** @ghidraAddress 0xee6a0 */
                           // The product load is deferred to the completion so it cannot race
                           // the sheet's own setup; a failed load is silently ignored (nil).
                           [self->itunesViewCtrl loadProductWithParameters:parameters
                                                           completionBlock:nil];
                         }];
    }
}

/** @ghidraAddress 0xee710 */
- (void)productViewControllerDidFinish:(nonnull SKStoreProductViewController *)viewController {
    [self dismissViewControllerAnimated:YES
                             completion:^{
                               /** @ghidraAddress 0xee778 */
                               // Drop the sheet only after the dismissal animation completes.
                               self->itunesViewCtrl = nil;
                             }];
}

#pragma mark - DownloaderDelegate

/** @ghidraAddress 0xee7a0 */
- (void)downloaderFinished:(nullable id)downloader {
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
            [AlertViewManager.sharedManager makeAlert:0
                                             delegate:self
                                                  tag:0
                                                title:kServerErrorTitle
                                                  msg:message
                                               cancel:ok
                                              btnText:nil
                                                 show:YES];
        } else {
            [self showPackInfo];
        }
        [loadingView stopLoading];
        infoDownloader = nil;
    } else if (sampleDownloader == downloader) {
        if (rowSamplePlayed >= 0) {
            NSData *data = [downloader getData];
            [AudioManager.sharedManager loadBgmData:data];
            [AudioManager.sharedManager startBgm:NO fadeTime:0.0];
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:rowSamplePlayed inSection:0];
            StoreDetailMusicCell *cell =
                (StoreDetailMusicCell *)[detailTableView cellForRowAtIndexPath:indexPath];
            [cell samplePlaying];
            isDownloadingSample = NO;
        }
        sampleDownloader = nil;
    }
}

/** @ghidraAddress 0xeeb58 */
- (void)downloaderError:(nullable id)downloader {
    // Both arms present the identical network-error alert, differing only in the tag: the info
    // downloader tags it so the delegate callbacks pop the navigation stack, the sample downloader
    // tags it 0.
    NSString *title = [NSBundle.mainBundle localizedStringForKey:@"Error" value:@"" table:nil];
    NSString *message = [NSBundle.mainBundle localizedStringForKey:@"NetworkErrorMsg"
                                                             value:@""
                                                             table:nil];
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil];
    if (infoDownloader == downloader) {
        [loadingView stopLoading];
        infoDownloader = nil;
        [AlertViewManager.sharedManager makeAlert:0
                                         delegate:self
                                              tag:kInfoErrorAlertTag
                                            title:title
                                              msg:message
                                           cancel:ok
                                          btnText:nil
                                             show:YES];
    } else if (sampleDownloader == downloader) {
        if (rowSamplePlayed >= 0) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:rowSamplePlayed inSection:0];
            StoreDetailMusicCell *cell =
                (StoreDetailMusicCell *)[detailTableView cellForRowAtIndexPath:indexPath];
            [cell sampleStop];
            rowSamplePlayed = kNoSampleRow;
        }
        sampleDownloader = nil;
        [AlertViewManager.sharedManager makeAlert:0
                                         delegate:self
                                              tag:0
                                            title:title
                                              msg:message
                                           cancel:ok
                                          btnText:nil
                                             show:YES];
    }
}

/** @ghidraAddress 0xeef00 */
- (void)downloaderProceed:(nullable id)downloader {
    // The shipped body is empty.
}

#pragma mark - ImageDownloaderDelegate

/** @ghidraAddress 0xf0138 */
- (void)imageDownloader:(nonnull ImageDownloader *)downloader didLoad:(nullable id)key {
    NSIndexPath *indexPath = (NSIndexPath *)key;
    if (indexPath.section == 0) {
        UITableViewCell *cell = [detailTableView cellForRowAtIndexPath:indexPath];
        UIImage *image = [downloader getImage];
        if (cell && image) {
            ((StoreDetailMusicCell *)cell).artworkView.image = image;
        }
    } else if (indexPath.section == 1 && indexPath.row == 0) {
        [headerView setArtwork:[downloader getImage]];
    }
}

#pragma mark - AlertViewManagerDelegate

/** @ghidraAddress 0xf02ac */
- (void)alertSelect:(nonnull NSDictionary *)info {
    int buttonMessage = [info[kAlertKeyButtonMessage] intValue];
    int tag = [info[kAlertKeyTag] intValue];
    if (buttonMessage == kConfirmButtonIndex && tag == kInfoErrorAlertTag && !bDismissing) {
        bDismissing = YES;
        if (self.navigationController) {
            [self.navigationController popViewControllerAnimated:YES];
        }
    }
}

/** @ghidraAddress 0xf040c */
- (void)alertClose:(nonnull NSDictionary *)info {
    if (self.navigationController) {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

#pragma mark - Artwork teardown

/** @ghidraAddress 0xf0498 */
- (void)stopDownloadArtworks {
    if (artworkDownloaders.count != 0) {
        for (ImageDownloader *downloader in artworkDownloaders.objectEnumerator) {
            [downloader cancelDownload];
            downloader.delegate = nil;
        }
        [artworkDownloaders removeAllObjects];
    }
}

/** @ghidraAddress 0xf0b84 */
- (void)detailClose {
    NSInteger rows = [self tableView:detailTableView numberOfRowsInSection:0];
    for (NSInteger row = 0; row < rows; ++row) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
        UITableViewCell *cell = [detailTableView cellForRowAtIndexPath:indexPath];
        if ([cell respondsToSelector:@selector(detailClose)]) {
            [cell performSelector:@selector(detailClose)];
        }
    }
}

#pragma mark - UITableViewDataSource

/** @ghidraAddress 0xeef04 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

/** @ghidraAddress 0xeef0c */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // One row per track, plus the trailing copyright row.
    return self.packInfo.musicInfos.count + 1;
}

/** @ghidraAddress 0xeef80 */
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSUInteger row = indexPath.row;
    if (row < self.packInfo.musicInfos.count) {
        // A music row. The dequeue result is discarded; the binary always allocates a fresh cell.
        [tableView dequeueReusableCellWithIdentifier:kMusicCellReuseIdentifier];
        StoreDetailMusicCell *cell =
            [[StoreDetailMusicCell alloc] initWithStyle:UITableViewCellStyleDefault
                                        reuseIdentifier:kMusicCellReuseIdentifier];
        cell.viewController = self;

        StoreMusicInfo *info = self.packInfo.musicInfos[indexPath.row];
        if (info == nil) {
            cell.extendImg.hidden = YES;
        } else {
            cell.labelName.text = info.name;
            cell.labelArtist.text = info.artist;
            cell.labelLevels.text =
                [NSString stringWithFormat:kLevelFormat, info.lvBas, info.lvAdv, info.lvExt];
            [cell setLink:info.itunesURL];

            ImageDownloader *downloader = artworkDownloaders[indexPath];
            UIImage *image = nil;
            if (downloader == nil) {
                NSURL *url = [NSURL URLWithString:info.artworkURL];
                if (url) {
                    ImageDownloader *newDownloader =
                        [[ImageDownloader alloc] initWithImageURL:url forKey:indexPath];
                    newDownloader.delegate = self;
                    artworkDownloaders[indexPath] = newDownloader;
                    [newDownloader startDownload];
                }
            } else {
                image = [downloader getImage];
            }
            if (image == nil) {
                cell.artworkView.image = [ImageCache.sharedCache getResPNG:kJacketPlaceholderName];
            } else {
                cell.artworkView.image = image;
            }
            cell.extendImg.hidden = (info.extendMusicID == 0);
        }

        // Reflect the sample-playback state of this row.
        if ((int)row == rowSamplePlayed) {
            if (isDownloadingSample) {
                [cell sampleDownloading];
            } else {
                [cell samplePlaying];
            }
        } else {
            [cell sampleStop];
        }
        return cell;
    }

    // The trailing copyright row.
    StoreDetailCopyrightCell *cell =
        [tableView dequeueReusableCellWithIdentifier:kCopyrightCellReuseIdentifier];
    if (cell == nil) {
        cell = [[StoreDetailCopyrightCell alloc] initWithStyle:UITableViewCellStyleDefault
                                               reuseIdentifier:kCopyrightCellReuseIdentifier];
    }
    cell.labelCopyright.font = [UIFont systemFontOfSize:kCopyrightFontSize];
    if (self.packInfo.copyright.length == 0) {
        cell.labelCopyright.text = @"";
    } else {
        NSDictionary *attributes = @{NSFontAttributeName : cell.labelCopyright.font};
        CGRect rect = [self.packInfo.copyright
            boundingRectWithSize:CGSizeMake(kCopyrightMeasureWidth, kCopyrightMeasureHeight)
                         options:NSStringDrawingUsesLineFragmentOrigin |
                                 NSStringDrawingTruncatesLastVisibleLine
                      attributes:attributes
                         context:nil];
        cell.labelCopyright.frame = CGRectMake(
            kCopyrightFrameOrigin, kCopyrightFrameOrigin, rect.size.width, rect.size.height);
        cell.labelCopyright.text = self.packInfo.copyright;
    }
    return cell;
}

#pragma mark - UITableViewDelegate

/** @ghidraAddress 0xef914 */
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSUInteger row = indexPath.row;
    if (row < self.packInfo.musicInfos.count) {
        return [StoreDetailMusicCell cellHeight];
    }
    if (self.packInfo.copyright == nil) {
        return kCopyrightFrameOrigin;
    }
    UIFont *font = [UIFont systemFontOfSize:kCopyrightFontSize];
    NSDictionary *attributes = @{NSFontAttributeName : font};
    CGRect rect = [self.packInfo.copyright
        boundingRectWithSize:CGSizeMake(kCopyrightMeasureWidth, kCopyrightMeasureHeight)
                     options:NSStringDrawingUsesLineFragmentOrigin |
                             NSStringDrawingTruncatesLastVisibleLine
                  attributes:attributes
                     context:nil];
    return rect.size.height + kCopyrightRowExtraHeight;
}

/** @ghidraAddress 0xefb68 */
- (void)tableView:(UITableView *)tableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath {
    NSUInteger row = indexPath.row;
    if (row < self.packInfo.musicInfos.count) {
        UIImage *background = (row & 1) ? packBgImage0 : packBgImage1;
        [(StoreDetailMusicCell *)cell setBgImage:background];
    } else {
        cell.backgroundColor = [UIColor colorWithWhite:kCopyrightRowBackgroundWhite alpha:1.0];
    }
}

/** @ghidraAddress 0xefccc */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSUInteger row = indexPath.row;
    if (row >= self.packInfo.musicInfos.count) {
        return;
    }

    int playingRow = rowSamplePlayed;
    if ((int)row == playingRow) {
        // Tapping the playing row stops it.
        [AudioManager.sharedManager stopBgm];
        sampleDownloader = nil;
        NSIndexPath *playingPath = [NSIndexPath indexPathForRow:rowSamplePlayed inSection:0];
        StoreDetailMusicCell *cell =
            (StoreDetailMusicCell *)[tableView cellForRowAtIndexPath:playingPath];
        [cell sampleStop];
        rowSamplePlayed = kNoSampleRow;
        [tableView reloadData];
        return;
    }

    // Stop any other playing row first.
    if (playingRow >= 0 && (NSUInteger)playingRow < self.packInfo.musicInfos.count) {
        [AudioManager.sharedManager stopBgm];
        sampleDownloader = nil;
        NSIndexPath *playingPath = [NSIndexPath indexPathForRow:rowSamplePlayed inSection:0];
        StoreDetailMusicCell *cell =
            (StoreDetailMusicCell *)[tableView cellForRowAtIndexPath:playingPath];
        [cell sampleStop];
    }

    // Begin downloading the tapped row's preview, if it has one.
    StoreMusicInfo *info = self.packInfo.musicInfos[indexPath.row];
    if (info.sampleURL != nil) {
        StoreDetailMusicCell *cell =
            (StoreDetailMusicCell *)[tableView cellForRowAtIndexPath:indexPath];
        rowSamplePlayed = (int)indexPath.row;
        isDownloadingSample = YES;
        [cell sampleDownloading];
        NSURL *url = [NSURL URLWithString:info.sampleURL];
        sampleDownloader = [[Downloader alloc] initWithURL:url delegate:self];
        [sampleDownloader startDownloading];
    }
}

#pragma mark - Rotation

/** @ghidraAddress 0xf0a9c */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Compiled to the unsigned range test (orientation - 1) < 2: the two portrait orientations.
    return UIInterfaceOrientationIsPortrait(interfaceOrientation);
}

/** @ghidraAddress 0xf0aac */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

/** @ghidraAddress 0xf0ab4 */
- (BOOL)shouldAutorotate {
    return YES;
}

@end
