#import "StoreDetailViewControllerV2.h"

#import "AudioManager.h"
#import "EditorIDManager.h"
#import "ImageCache.h"
#import "ImageDownloader.h"
#import "ImageLoading.h"
#import "PurchaseManager.h"
#import "ScratchUtil.h"
#import "SessionDownloader.h"
#import "StoreButton.h"
#import "StoreDetailCopyrightCell.h"
#import "StoreDetailHeaderViewV2.h"
#import "StoreDetailMusicCell.h"
#import "StoreLoadingView.h"
#import "StoreMusicInfo.h"
#import "StoreMusicListManager.h"
#import "StorePackInfo.h"
#import "StoreRecommendPackTableView.h"
#import "StoreUtil.h"

// The typed-accessor category the store dictionaries are read through; a category on NSDictionary
// not reconstructed as its own file yet. See TYPES_PENDING.md.
@interface NSDictionary (TypedAccessors)
- (nullable NSNumber *)numberForKey:(nonnull id)key;
- (nullable NSArray *)arrayForKey:(nonnull id)key;
@end

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

// The keys read out of the alert-result dictionary and the store responses.
static NSString *const kAlertKeyButtonMessage = @"btnMessage";
static NSString *const kAlertKeyTag = @"Tag";
static NSString *const kResponseKeyError = @"Error";
static NSString *const kResponseKeyStatus = @"status";
static NSString *const kResponseKeyPackList = @"pack_list";
static NSString *const kEntryKeyID = @"ID";

// The recommended-pack request's POST keys.
static NSString *const kRequestKeyPackID = @"pack_id";
static NSString *const kRequestKeyUserID = @"user_id";

// The info-download error alert's tag, and the button index that pops the navigation stack.
static const int kInfoErrorAlertTag = 1;
static const int kConfirmButtonIndex = 1;

// The navigation title (a literal CFString, not a localised string).
static NSString *const kNavigationTitle = @"info";

// The tags of the two tables the relation strip switches between, plus the spare header carrier.
static const NSInteger kDetailTableTag = 2;
static const NSInteger kHeaderCarrierTableTag = 3;

// The three parallel relation-strip headers, one per owned table.
static const NSUInteger kHeaderCount = 3;

// The relation-tab index that shows the tune list; any other index shows the recommend list.
static const int kRelationListDetail = 0;

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

// The relation cross-fade duration and the linear curve option. The duration pool slot is shared
// with the buy-button red channel.
static const NSTimeInterval kRelationFadeDuration = 0.2; // @ghidraAddress 0x28f240
static const UIViewAnimationOptions kRelationFadeOptions =
    0x30000; // UIViewAnimationOptionCurveLinear

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

static const CGFloat kPendingColorRed = 0.1;    // @ghidraAddress 0x28f2b8
static const CGFloat kPendingColorGreen = 0.25; // an fmov immediate (0x3fd0000000000000)
static const CGFloat kPendingColorBlue = 0.8;   // @ghidraAddress 0x28e080

// The resizable pack-background cap inset (fmov 4.0), the copyright font size and row-frame origin
// (fmov 10.0), and the copyright row's extra height (fmov 20.0) are all fmov immediates.
static const CGFloat kPackBgCapInset = 4.0;
static const CGFloat kCopyrightFontSize = 10.0;
static const CGFloat kCopyrightFrameOrigin = 10.0;
static const CGFloat kCopyrightRowExtraHeight = 20.0;

// The sentinel stored in rowSamplePlayed when no row is playing a sample.
static const int kNoSampleRow = -1;

@implementation StoreDetailViewControllerV2 {
    int rowSamplePlayed;
    BOOL isDownloadingSample;
    BOOL allowsRedownload;
    NSMutableArray *headerViewArray;
    UITableView *detailTableView;
    StoreLoadingView *loadingView;
    Downloader *infoDownloader;
    Downloader *sampleDownloader;
    NSMutableDictionary *artworkDownloaders;
    UIImage *packBgImage0;
    UIImage *packBgImage1;
    SKStoreProductViewController *itunesViewCtrl;
    BOOL bDismissing;
    SessionDownloader *recommendDownloader;
    StoreRecommendPackTableView *recommendPackTableView;
    NSString *storeCountry;
    NSArray *recommendPackDictArray;
    NSArray *recommendPackList;
    SKProductsRequest *productsRequest;
    int currentList;
    UITableView *tmpHeaderTable;
    BOOL _bRestore;
    StorePackInfo *_packInfo;
    __weak id<StoreDetailViewControllerV2Delegate> _delegate;
    __weak id<StoreDetailViewControllerV2CloseDelegate> _closeDelegate;
}

@synthesize packInfo = _packInfo;
@synthesize delegate = _delegate;
@synthesize closeDelegate = _closeDelegate;
@synthesize bRestore = _bRestore;

#pragma mark - Lifecycle

/** @ghidraAddress 0xdc94c */
- (nullable instancetype)init {
    self = [super init];
    if (self) {
        self.navigationItem.title = kNavigationTitle;
        if ([self respondsToSelector:@selector(setExtendedLayoutIncludesOpaqueBars:)]) {
            [self performSelector:@selector(setExtendedLayoutIncludesOpaqueBars:) withObject:nil];
        }
    }
    return self;
}

/** @ghidraAddress 0xdca08 */
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
    detailTableView.tag = kDetailTableTag;
    (void)detailTableView.frame; // Yes, the binary reads the frame and discards it.

    // Three parallel relation-strip headers, one to mount on each of the three tables.
    headerViewArray = [[NSMutableArray alloc] init];
    for (NSUInteger i = 0; i < kHeaderCount; ++i) {
        CGRect headerFrame = CGRectMake(0.0, 0.0, tableFrame.size.width, kHeaderMeasureHeight);
        StoreDetailHeaderViewV2 *header =
            [[StoreDetailHeaderViewV2 alloc] initWithFrame:headerFrame];
        [header.buttonPurchase setTitle:[NSBundle.mainBundle localizedStringForKey:@"Purchased"
                                                                             value:@""
                                                                             table:nil]
                               forState:UIControlStateDisabled];
        [header.buttonPurchase addTarget:self
                                  action:@selector(doPurchase:)
                        forControlEvents:UIControlEventTouchUpInside];
        [header.buttonExtendDownload addTarget:self
                                        action:@selector(downloadExtendMusic:)
                              forControlEvents:UIControlEventTouchUpInside];
        [headerViewArray addObject:header];
    }

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

    // Wire each header's relation-tab buttons to -tapRelationButton:.
    for (NSUInteger i = 0; i < kHeaderCount; ++i) {
        StoreDetailHeaderViewV2 *header = headerViewArray[i];
        for (UIButton *button in header.relationBtnArray) {
            [button addTarget:self
                          action:@selector(tapRelationButton:)
                forControlEvents:UIControlEventTouchUpInside];
        }
    }

    // The recommended-pack list, laid out over the same area and hidden until a tab switch.
    recommendPackTableView =
        [[StoreRecommendPackTableView alloc] initWithFrame:tableFrame style:UITableViewStylePlain];
    recommendPackTableView.parentView = self.closeDelegate;
    [self.view addSubview:recommendPackTableView];
    recommendPackTableView.hidden = YES;

    // A spare transparent table that carries the third header during a cross-fade.
    tmpHeaderTable = [[UITableView alloc] initWithFrame:tableFrame style:UITableViewStylePlain];
    tmpHeaderTable.backgroundColor = UIColor.clearColor;
    tmpHeaderTable.separatorStyle = UITableViewCellSeparatorStyleNone;
    tmpHeaderTable.tag = kHeaderCarrierTableTag;
}

/** @ghidraAddress 0xe155c */
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

/** @ghidraAddress 0xe1594 */
- (void)viewDidUnload {
    [super viewDidUnload];
    detailTableView = nil;
    loadingView = nil;
    packBgImage0 = nil;
    packBgImage1 = nil;
    [self stopDownloadArtworks];
    artworkDownloaders = nil;
    recommendPackTableView = nil;
    [headerViewArray removeAllObjects];
}

/** @ghidraAddress 0xe1678 */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // Refresh the purchase state if any header has already built its extend button.
    for (NSUInteger i = 0; i < kHeaderCount; ++i) {
        StoreDetailHeaderViewV2 *header = headerViewArray[i];
        if (header && header.buttonExtendDownload) {
            [self updatePurchaseState];
        }
    }
    if (recommendPackTableView) {
        [recommendPackTableView reloadData];
    }
}

/** @ghidraAddress 0xe180c */
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

/** @ghidraAddress 0xe18d8 */
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

/** @ghidraAddress 0xe1ad0 */
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

/** @ghidraAddress 0xe1b28 */
- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self
                                                  name:kFinishBgmNotificationName
                                                object:nil];
    [infoDownloader cancel];
    [sampleDownloader cancel];
    [self stopDownloadArtworks];
    [recommendDownloader cancel];
    if (productsRequest) {
        [productsRequest cancel];
        productsRequest = nil;
    }
    // [super dealloc] is compiler-emitted (ARC). The strong ivars are torn down by the
    // compiler-generated .cxx_destruct (0xe2c20), which is not authored here.
}

#pragma mark - Content loading

/** @ghidraAddress 0xdd47c */
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
                for (NSUInteger i = 0; i < kHeaderCount; ++i) {
                    ((StoreDetailHeaderViewV2 *)headerViewArray[i]).buttonPurchase.enabled = YES;
                }
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

        for (NSUInteger i = 0; i < kHeaderCount; ++i) {
            ((StoreDetailHeaderViewV2 *)headerViewArray[i]).buttonExtendDownload.hidden = YES;
        }
        if (!redownload) {
            if ([StoreUtil existDownloadableExtendMusic:self.packInfo.musicInfos]) {
                for (NSUInteger i = 0; i < kHeaderCount; ++i) {
                    ((StoreDetailHeaderViewV2 *)headerViewArray[i]).buttonExtendDownload.hidden =
                        NO;
                }
            }
            allowsRedownload = NO;
            for (NSUInteger i = 0; i < kHeaderCount; ++i) {
                ((StoreDetailHeaderViewV2 *)headerViewArray[i]).buttonPurchase.enabled = NO;
            }
        }
    } else if ([PurchaseManager.sharedManager isPending:productID]) {
        // A purchase is in flight: allow the pending download.
        allowsRedownload = YES;
        for (NSUInteger i = 0; i < kHeaderCount; ++i) {
            ((StoreDetailHeaderViewV2 *)headerViewArray[i]).buttonPurchase.enabled = YES;
        }
        buttonTitle = [NSBundle.mainBundle localizedStringForKey:@"DOWNLOAD" value:@"" table:nil];
        buttonColor = [[UIColor alloc] initWithRed:kPendingColorRed
                                             green:kPendingColorGreen
                                              blue:kPendingColorBlue
                                             alpha:1.0];
    } else {
        // Not owned and not pending: offer the buy button at its price.
        allowsRedownload = NO;
        for (NSUInteger i = 0; i < kHeaderCount; ++i) {
            ((StoreDetailHeaderViewV2 *)headerViewArray[i]).buttonPurchase.enabled = YES;
        }
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
        for (NSUInteger i = 0; i < kHeaderCount; ++i) {
            [((StoreDetailHeaderViewV2 *)headerViewArray[i]).buttonPurchase
                setTitle:buttonTitle
                forState:UIControlStateNormal];
        }
    }
    if (buttonColor) {
        for (NSUInteger i = 0; i < kHeaderCount; ++i) {
            ((StoreDetailHeaderViewV2 *)headerViewArray[i]).buttonPurchase.buttonColor =
                buttonColor;
        }
    }
}

/** @ghidraAddress 0xde248 */
- (void)showPackInfo {
    for (NSUInteger i = 0; i < kHeaderCount; ++i) {
        [(StoreDetailHeaderViewV2 *)headerViewArray[i] loadPackInfo:self.packInfo];
    }
    [self updatePurchaseState];

    // The tune list carries the first header; the recommend list and spare carry the others.
    detailTableView.tableHeaderView = headerViewArray[0];

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
    [self.view addSubview:tmpHeaderTable];

    // Fetch the recommended-pack list for this pack.
    NSURL *recommendURL = [ScratchUtil recommendPackListURL];
    NSDictionary *post = @{
        kRequestKeyPackID : @(self.packInfo.packID),
        kRequestKeyUserID : [EditorIDManager getKeyString:[EditorIDManager getEditorIDKey]]
    };
    recommendDownloader = [[SessionDownloader alloc] initWithURL:recommendURL
                                                  postDictionary:post
                                                        delegate:self];
    [recommendDownloader startDownloading];

    recommendPackTableView.tableHeaderView = headerViewArray[1];
    tmpHeaderTable.tableHeaderView = headerViewArray[2];
}

/** @ghidraAddress 0xde7d4 */
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

/** @ghidraAddress 0xde980 */
- (void)stopSample {
    [AudioManager.sharedManager fadeoutBgm:kSampleFadeOutTime];
    sampleDownloader = nil;
    rowSamplePlayed = kNoSampleRow;
    [detailTableView reloadData];
}

/** @ghidraAddress 0xdea10 */
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

/** @ghidraAddress 0xdeb1c */
- (void)doPurchase:(nullable id)sender {
    [self stopSample];
    if (allowsRedownload) {
        if ([self.delegate respondsToSelector:@selector(detailViewStartRedownload:)]) {
            [self.delegate performSelector:@selector(detailViewStartRedownload:) withObject:self];
        }
    } else {
        if ([self.delegate respondsToSelector:@selector(detailViewStartPurchase:)]) {
            [self.delegate performSelector:@selector(detailViewStartPurchase:) withObject:self];
        }
    }
}

/** @ghidraAddress 0xdec34 */
- (void)downloadExtendMusic:(nullable id)sender {
    [self stopSample];
    for (NSUInteger i = 0; i < kHeaderCount; ++i) {
        ((StoreDetailHeaderViewV2 *)headerViewArray[i]).buttonExtendDownload.hidden = YES;
    }
    if ([self.delegate respondsToSelector:@selector(detailViewStartExtendDownload:)]) {
        [self.delegate performSelector:@selector(detailViewStartExtendDownload:)
                            withObject:self.packInfo];
    }
}

/** @ghidraAddress 0xdee30 */
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
                           /** @ghidraAddress 0xdefa0 */
                           // The product load is deferred to the completion so it cannot race
                           // the sheet's own setup; a failed load is silently ignored (nil).
                           [self->itunesViewCtrl loadProductWithParameters:parameters
                                                           completionBlock:nil];
                         }];
    }
}

/** @ghidraAddress 0xdf010 */
- (void)productViewControllerDidFinish:(nonnull SKStoreProductViewController *)viewController {
    [self dismissViewControllerAnimated:YES
                             completion:^{
                               /** @ghidraAddress 0xdf078 */
                               // Drop the sheet only after the dismissal animation completes.
                               self->itunesViewCtrl = nil;
                             }];
}

#pragma mark - DownloaderDelegate

/** @ghidraAddress 0xdf0a0 */
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

            // Also request the products for any packs already resolved into recommendPackList.
            NSMutableSet *knownProductIDs = [[NSMutableSet alloc] init];
            for (StorePackInfo *pack in recommendPackList) {
                [knownProductIDs addObject:[StoreUtil productIDForPackID:pack.packID]];
            }
            if (knownProductIDs.count != 0) {
                productsRequest =
                    [[SKProductsRequest alloc] initWithProductIdentifiers:knownProductIDs];
                productsRequest.delegate = self;
                [productsRequest start];
            }
        }
    }
}

/** @ghidraAddress 0xdf994 */
- (void)downloaderError:(nullable id)downloader {
    // Both arms present the identical network-error alert, differing only in the tag: the info
    // downloader tags it so the delegate callbacks pop the navigation stack, the sample downloader
    // tags it 0. The recommend downloader's failure raises no alert.
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

/** @ghidraAddress 0xdfd3c */
- (void)downloaderProceed:(nullable id)downloader {
    // The shipped body is empty.
}

#pragma mark - SKProductsRequestDelegate

/** @ghidraAddress 0xe24b4 */
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

    // Re-enable every header's relation-tab buttons.
    for (NSUInteger i = 0; i < kHeaderCount; ++i) {
        StoreDetailHeaderViewV2 *header = headerViewArray[i];
        for (UIButton *button in header.relationBtnArray) {
            button.enabled = YES;
        }
    }

    recommendPackTableView.packList = nil;
    recommendPackTableView.packList = recommendPackList;
    recommendPackTableView.parentInfo = self.packInfo;
    [recommendPackTableView reloadData];

    // Colour every relation strip for the tune-list tab.
    for (NSUInteger i = 0; i < kHeaderCount; ++i) {
        [(StoreDetailHeaderViewV2 *)headerViewArray[i] setRelationColor:kRelationListDetail
                                                             selectable:YES];
    }
}

#pragma mark - ImageDownloaderDelegate

/** @ghidraAddress 0xe0f9c */
- (void)imageDownloader:(nonnull ImageDownloader *)downloader didLoad:(nullable id)key {
    NSIndexPath *indexPath = (NSIndexPath *)key;
    if (indexPath.section == 0) {
        UITableViewCell *cell = [detailTableView cellForRowAtIndexPath:indexPath];
        UIImage *image = [downloader getImage];
        if (cell && image) {
            ((StoreDetailMusicCell *)cell).artworkView.image = image;
        }
    } else if (indexPath.section == 1 && indexPath.row == 0) {
        for (NSUInteger i = 0; i < kHeaderCount; ++i) {
            [(StoreDetailHeaderViewV2 *)headerViewArray[i] setArtwork:[downloader getImage]];
        }
    }
}

#pragma mark - AlertViewManagerDelegate

/** @ghidraAddress 0xe11f0 */
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

/** @ghidraAddress 0xe1350 */
- (void)alertClose:(nonnull NSDictionary *)info {
    if (self.navigationController) {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

#pragma mark - Artwork teardown

/** @ghidraAddress 0xe13dc */
- (void)stopDownloadArtworks {
    if (artworkDownloaders.count != 0) {
        for (ImageDownloader *downloader in artworkDownloaders.objectEnumerator) {
            [downloader cancelDownload];
            downloader.delegate = nil;
        }
        [artworkDownloaders removeAllObjects];
    }
}

/** @ghidraAddress 0xe1c30 */
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

#pragma mark - Relation-tab switching

/** @ghidraAddress 0xe1d48 */
- (void)tapRelationButton:(nullable id)sender {
    int index = (int)((UIView *)sender).tag;
    if (index == currentList) {
        return;
    }
    currentList = index;

    // Recolour every relation strip for the newly-selected tab.
    for (NSUInteger i = 0; i < kHeaderCount; ++i) {
        [(StoreDetailHeaderViewV2 *)headerViewArray[i] setRelationColor:index selectable:YES];
    }

    // Index 0 shows the tune list; any other index shows the recommend list. The carrier and the
    // incoming view both scroll to the outgoing view's offset so the cross-fade holds position.
    UITableView *outgoing =
        (index != kRelationListDetail) ? detailTableView : recommendPackTableView;
    UITableView *incoming =
        (index != kRelationListDetail) ? recommendPackTableView : detailTableView;

    CGPoint offset = outgoing.contentOffset;
    tmpHeaderTable.contentOffset = offset;
    tmpHeaderTable.hidden = NO;
    incoming.contentOffset = offset;

    __weak UITableView *weakOutgoing = outgoing;
    __weak UITableView *weakIncoming = incoming;
    __weak UITableView *weakCarrier = tmpHeaderTable;

    outgoing.alpha = 1.0;
    incoming.alpha = 0.0;

    [UIApplication.sharedApplication beginIgnoringInteractionEvents];
    [UIView animateWithDuration:kRelationFadeDuration
        delay:0.0
        options:kRelationFadeOptions
        animations:^{
          /** @ghidraAddress 0xe2118 */
          // Stage 1: fade the outgoing view out to transparent before the swap.
          weakOutgoing.alpha = 0.0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0xe2164 */
          // Stage-1 completion: hide the outgoing view, ready the incoming one at zero alpha,
          // then run the stage-2 fade-in and finish.
          weakOutgoing.hidden = YES;
          weakIncoming.hidden = NO;
          weakIncoming.alpha = 0.0;
          [UIView animateWithDuration:kRelationFadeDuration
              delay:0.0
              options:kRelationFadeOptions
              animations:^{
                /** @ghidraAddress 0xe2308 */
                // Stage 2: fade the incoming view in.
                weakIncoming.alpha = 1.0;
              }
              completion:^(BOOL innerFinished) {
                /** @ghidraAddress 0xe2354 */
                // Stage-2 completion: hide the carrier, snap the incoming scroll offset, and
                // re-enable input unconditionally so a cancelled transition cannot lock the UI.
                weakCarrier.hidden = YES;
                weakIncoming.contentOffset = offset;
                [UIApplication.sharedApplication endIgnoringInteractionEvents];
              }];
        }];
}

#pragma mark - UITableViewDataSource

/** @ghidraAddress 0xdfd40 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

/** @ghidraAddress 0xdfd48 */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // The spare header carrier shows no rows; the tune list shows one row per track plus the
    // trailing copyright row.
    if (tableView.tag == kHeaderCarrierTableTag) {
        return 0;
    }
    return self.packInfo.musicInfos.count + 1;
}

/** @ghidraAddress 0xdfde4 */
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

/** @ghidraAddress 0xe0778 */
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

/** @ghidraAddress 0xe09cc */
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

/** @ghidraAddress 0xe0b30 */
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

/** @ghidraAddress 0xe1b08 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Compiled to the unsigned range test (orientation - 1) < 2: the two portrait orientations.
    return UIInterfaceOrientationIsPortrait(interfaceOrientation);
}

/** @ghidraAddress 0xe1b18 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

/** @ghidraAddress 0xe1b20 */
- (BOOL)shouldAutorotate {
    return YES;
}

@end
