#import "StoreCampaignViewController.h"

#import "AlertViewManager.h"
#import "CJSONSerializer.h"
#import "CampaignDetailViewController.h"
#import "CampaignItemDetailView.h"
#import "CampaignItemInfo.h"
#import "Downloader.h"
#import "EditorIDManager.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"
#import "MarkerManager.h"
#import "Md5Utilities.h"
#import "StoreCampaignTableViewCell.h"
#import "StoreDownloadManager.h"
#import "StoreDownloadTask.h"
#import "StoreLoadingView.h"
#import "StoreMusicInfo.h"
#import "StoreMusicListManager.h"
#import "StoreUtil.h"
#import "StoreViewController.h"

// The reuse identifier for the campaign banner rows.
static NSString *const kCampaignCellReuseIdentifier = @"StorePrivilegeCell";

// The tab-bar image for this screen.
static NSString *const kTabImageName = @"tab_present";

// The request-body keys shared by the campaign-list, item-info, and serial-check posts.
static NSString *const kRequestKeyTarget = @"target";
static NSString *const kRequestKeyHead = @"head";
static NSString *const kRequestKeyLimit = @"limit";
static NSString *const kRequestKeyUserID = @"userId";
static NSString *const kRequestKeyPassword = @"passwd";
static NSString *const kRequestKeyCode = @"code";
static NSString *const kRequestKeyCampaignID = @"campId";
static NSString *const kRequestValueTargetJP = @"JP";

// The response keys read out of a decoded JSON reply.
static NSString *const kResponseKeyStatus = @"Status";
static NSString *const kResponseKeyList = @"List";
static NSString *const kResponseKeyError = @"Error";
static NSString *const kResponseKeyURL = @"URL";

// The alert-result dictionary keys.
static NSString *const kAlertKeyButtonMessage = @"btnMessage";
static NSString *const kAlertKeyTag = @"Tag";
static NSString *const kAlertKeyMessage = @"Message";

// The marker-info dictionary keys the marker download writes.
static NSString *const kMarkerKeyID = @"markerID";
static NSString *const kMarkerKeyVersion = @"version";
static NSString *const kMarkerKeyBannerName = @"bannerName";
static NSString *const kMarkerVersionInitial = @"1.0.0";

// The format strings the screen builds. The marker artwork names are derived from its ID.
static NSString *const kMarkerFilenameFormat = @"mk%04d";
static NSString *const kMarkerBannerFormat = @"tm%@_banner";
static NSString *const kIntegerFormat = @"%d";

// The App Store page opened when the tune needs an app update.
static NSString *const kAppStoreURLString =
    @"https://itunes.apple.com/WebObjects/MZStore.woa/wa/viewSoftware?id=395192484&mt=8";

// The localised string keys and empty value/table arguments common to every lookup.
static NSString *const kLocKeyOK = @"OK";
static NSString *const kLocKeyCancel = @"Cancel";
static NSString *const kLocKeyError = @"Error";
static NSString *const kLocKeyNetworkErrorMsg = @"NetworkErrorMsg";
static NSString *const kLocKeyDownloadErrorMsg = @"DownloadErrorMsg";
static NSString *const kLocKeyDownloading = @"Downloading %@ ...";
static NSString *const kLocKeyDownloadingAddition = @"Downloading %@ (addition item) ...";
static NSString *const kLocKeyUpdate = @"アップデート";
static NSString *const kLocKeyDownloadingMarker = @"マーカーをダウンロードしています...";
static NSString *const kEmptyValue = @"";

// The Japanese alert bodies and titles baked into this screen.
static NSString *const kSerialTitle = @"シリアルコード入力";
static NSString *const kSerialMessage = @"シリアルコードを入力してください";
static NSString *const kUpdateMessage =
    @"この曲を解禁するには、アプリをアップデートする必要があります";
static NSString *const kTermTitle = @"解禁条件";
static NSString *const kTermMessage = @"解禁条件は説明に書いてある、はず。";
static NSString *const kNotUnlockableMessage = @"ダウンロードの条件を満たしていません";
static NSString *const kMarkerDownloadFailedMessage = @"マーカーのダウンロードに失敗しました";

// The vertical grey gradient behind the table, from the RGB pools at 0x28fad8 and 0x28faf0.
static const CGFloat kGradientTopRed = 0.725;      // @ghidraAddress 0x28fad8
static const CGFloat kGradientTopGreen = 0.731;    // @ghidraAddress 0x28fae0
static const CGFloat kGradientTopBlue = 0.737;     // @ghidraAddress 0x28fae8
static const CGFloat kGradientBottomRed = 0.467;   // @ghidraAddress 0x28faf0
static const CGFloat kGradientBottomGreen = 0.489; // @ghidraAddress 0x28faf8
static const CGFloat kGradientBottomBlue = 0.511;  // @ghidraAddress 0x28fb00

// The pad detail card is a fixed square, centred in the view.
static const CGFloat kDetailCardSide = 600.0; // @ghidraAddress 0x291c30

// The pad cover-view dimming alpha and its opacity.
static const CGFloat kCoverDimAlpha = 0.5;

// The loading overlay's size by idiom (pools at 0x291d30/0x291c50 for pad, +8 for phone).
static const CGFloat kLoadingViewWidthPad = 600.0;    // @ghidraAddress 0x291d30
static const CGFloat kLoadingViewWidthPhone = 300.0;  // @ghidraAddress 0x291d38
static const CGFloat kLoadingViewHeightPad = 140.0;   // @ghidraAddress 0x291c50
static const CGFloat kLoadingViewHeightPhone = 200.0; // @ghidraAddress 0x291c58

// The row height by idiom, from the __const pair at 0x28fb10 indexed by isPad.
static const CGFloat kRowHeightPhone = 50.0; // @ghidraAddress 0x28fb10
static const CGFloat kRowHeightPad = 60.0;   // @ghidraAddress 0x28fb18

// The table's background white, from the pool at 0x291d20.
static const CGFloat kTableBackgroundWhite = 0.45; // @ghidraAddress 0x291d20

// The square artwork side by idiom, from the __const pair at 0x291d40 indexed by isPad.
static const CGFloat kArtworkSidePhone = 64.0; // @ghidraAddress 0x291d40
static const CGFloat kArtworkSidePad = 100.0;  // @ghidraAddress 0x291d48

// The two extra points a phone's square artwork is nudged up by; the pad uses zero.
static const CGFloat kArtworkPhoneYInset = 2.0;

// The fade durations and the ignore-interaction release delay (pools at 0x28e040, 0x28f260,
// 0x28f268).
static const NSTimeInterval kArtworkFadeDuration = 0.2; // @ghidraAddress 0x28e040
static const NSTimeInterval kDetailFadeDuration = 0.3;  // @ghidraAddress 0x28f260
static const NSTimeInterval kEndIgnoringDelay = 0.4;    // @ghidraAddress 0x28f268

// The image-request timeout, from the fmov immediate at 0x1000c3d98.
static const NSTimeInterval kArtworkRequestTimeout = 10.125;

// The artwork cache's object limit and the campaign-list request's item limit.
static const NSUInteger kArtworkCacheCountLimit = 20;
static const int kCampaignListHead = 0;
static const int kCampaignListLimit = 30;

// The sentinels stored in working_index and startUpID when nothing is in flight.
static const int kNoWorkingRow = -1;
static const NSInteger kNoStartUpID = -1;

// The button types itemDownload dispatches on.
enum {
    kButtonTypeInfoDownload = 0,
    kButtonTypeNotUnlockable = 2,
    kButtonTypeUpdate = 3,
    kButtonTypeSerial = 4,
};

// The alert type (the makeAlert: first argument): a plain alert or one with a text-input field.
enum {
    kAlertTypePlain = 0,
    kAlertTypeTextInput = 1,
};

// The alert tags this screen raises.
enum {
    kAlertTagNotUnlockable = 2,
    kAlertTagSerial = 1,
    kAlertTagUpdate = 0,
};

// The item types the detail flow understands.
enum {
    kItemTypeTune = 0,
    kItemTypeMarker = 1,
};

// The Downloader tags echoed back through -downloaderFinished:/-downloaderError:.
enum {
    kDownloaderTagCampaignList = 0,
    kDownloaderTagMusicInfo = 1,
    kDownloaderTagSerialCheck = 2,
    kDownloaderTagItemInfo = 3,
    kDownloaderTagMarker = 4,
};

// The hide flag value that keeps an item out of the displayed list.
static const int kHideTypeHidden = 2;

// A campaign response with a serial-check button reports button index 1 as "confirmed" and 0 as
// "open App Store".
static const int kSerialConfirmButton = 1;
static const int kSerialOpenStoreButton = 0;

// The marker payload carries a trailing 16-byte MD5 digest.
static const NSUInteger kMd5DigestLength = 16;

// The marker ID digits 2..5 form its banner directory name (substring range {2, 4}).
static const NSUInteger kMarkerBannerSubstringLocation = 2;
static const NSUInteger kMarkerBannerSubstringLength = 4;

@implementation StoreCampaignViewController {
    NSInteger startUpID;
    int working_index;
    BOOL isPad;
    __weak id<StoreParentViewController> storeViewCtrl;
    UITableView *tableView;
    Downloader *infoDownloader;
    Downloader *musicInfoDownloader;
    Downloader *termsChecker;
    Downloader *itemURLDownloader;
    Downloader *markerDownloader;
    int infoRandomKey;
    StoreDownloadManager *dlManager;
    CampaignItemDetailView *itemDetailViewPad;
    UIView *coverViewPad;
    StoreLoadingView *loadingView;
    BOOL isOpenItemDetail;
    __weak CampaignDetailViewController *itemDetailViewController;
    NSMutableArray *downloadMusicList;
    NSArray *unlockMusicCheckList;
    BOOL firstDownloadFailed;
    NSCache *artworkCache;
    NSOperationQueue *operationQueue;
    NSMutableArray *downloadingList;
    NSString *musicName;
}

#pragma mark - Lifecycle

/** @ghidraAddress 0xbe580 */
- (instancetype)initWithParent:(nullable id<StoreParentViewController>)parent {
    self = [super init];
    if (self) {
        storeViewCtrl = parent;
        self.navigationItem.title = @"Gift";
        self.tabBarItem.title = @"Gift";
        self.tabBarItem.image = LoadScaledPngImage(kTabImageName);
        if ([self respondsToSelector:@selector(setExtendedLayoutIncludesOpaqueBars:)]) {
            [self performSelector:@selector(setExtendedLayoutIncludesOpaqueBars:) withObject:nil];
        }
        UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithTitle:@"Back"
                                                                     style:UIBarButtonItemStyleDone
                                                                    target:storeViewCtrl
                                                                    action:@selector(storeEnd:)];
        self.navigationItem.leftBarButtonItem = backItem;
        isPad = JubeatAppDelegate.appDelegate.isPad;
        working_index = kNoWorkingRow;
        startUpID = kNoStartUpID;
        artworkCache = [[NSCache alloc] init];
        artworkCache.countLimit = kArtworkCacheCountLimit;
        operationQueue = [[NSOperationQueue alloc] init];
        downloadingList = [[NSMutableArray alloc] init];
        unlockMusicCheckList = nil;
        firstDownloadFailed = NO;
        [self downloadCampaignList];
    }
    return self;
}

/** @ghidraAddress 0xbe8ec */
- (void)loadView {
    [super loadView];
    self.view.autoresizesSubviews = YES;
    CGRect bounds = self.view.bounds;

    // The full-bounds vertical grey gradient.
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

    // Only the pad gets an in-place dimming cover and detail card faded in over the table.
    if (isPad) {
        coverViewPad = [[UIView alloc] initWithFrame:self.view.bounds];
        coverViewPad.opaque = NO;
        coverViewPad.backgroundColor = [UIColor colorWithWhite:0.0 alpha:kCoverDimAlpha];
        coverViewPad.userInteractionEnabled = YES;
        coverViewPad.exclusiveTouch = YES;
        UITapGestureRecognizer *tap =
            [[UITapGestureRecognizer alloc] initWithTarget:self
                                                    action:@selector(handleTapCoverView:)];
        [coverViewPad addGestureRecognizer:tap];
        itemDetailViewPad = [[CampaignItemDetailView alloc]
            initWithFrame:CGRectMake(0.0, 0.0, kDetailCardSide, kDetailCardSide)];
        itemDetailViewPad.center =
            CGPointMake((CGFloat)(int)(bounds.origin.x + bounds.size.width * 0.5),
                        (CGFloat)(int)(bounds.origin.y + bounds.size.height * 0.5));
        itemDetailViewPad.delegate = storeViewCtrl;
        itemDetailViewPad.viewController = self;
    }

    // The loading overlay, sized by idiom and centred in the bounds.
    CGRect loadingFrame = CGRectMake(0.0,
                                     0.0,
                                     isPad ? kLoadingViewWidthPad : kLoadingViewWidthPhone,
                                     isPad ? kLoadingViewHeightPad : kLoadingViewHeightPhone);
    loadingView = [[StoreLoadingView alloc] initWithFrame:loadingFrame];
    loadingView.center = CGPointMake((CGFloat)((int)bounds.size.width >> 1),
                                     (CGFloat)((int)bounds.size.height >> 1));
    loadingView.hidden = YES;
    [self.view addSubview:loadingView];

    // The table fills the view below the tab header and above the tab footer.
    CGFloat headerHeight = [StoreUtil storeTabHeaderHeight];
    CGFloat footerHeight = [StoreUtil storeTabFooterHeight];
    CGRect tableFrame = CGRectMake(bounds.origin.x,
                                   bounds.origin.y,
                                   bounds.size.width,
                                   bounds.size.height - headerHeight - footerHeight);
    tableView = [[UITableView alloc] initWithFrame:tableFrame style:UITableViewStylePlain];
    tableView.rowHeight = isPad ? kRowHeightPad : kRowHeightPhone;
    tableView.delegate = self;
    tableView.dataSource = self;
    tableView.allowsSelection = NO;
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    tableView.backgroundColor = [UIColor colorWithWhite:kTableBackgroundWhite alpha:1.0];
    [self.view addSubview:tableView];

    // Reload from the cached unlock list if one already arrived, otherwise fetch it.
    if (unlockMusicCheckList) {
        [self refreshMusicList];
    } else {
        [self downloadCampaignList];
    }
}

/** @ghidraAddress 0xbf074 */
- (void)downloadCampaignList {
    NSURL *url = [StoreUtil campaignListURL];
    NSMutableDictionary *body = [[NSMutableDictionary alloc] init];
    [body setValue:kRequestValueTargetJP forKey:kRequestKeyTarget];
    [body setValue:@(kCampaignListHead) forKey:kRequestKeyHead];
    [body setValue:@(kCampaignListLimit) forKey:kRequestKeyLimit];
    if ([EditorIDManager isExistEditorID]) {
        [body setValue:[EditorIDManager getKeyString:[EditorIDManager getEditorIDKey]]
                forKey:kRequestKeyUserID];
        [body setValue:[EditorIDManager getKeyString:[EditorIDManager getEditorPassKey]]
                forKey:kRequestKeyPassword];
    }
    NSData *post = [[CJSONSerializer serializer] serializeDictionary:body error:nil];
    infoDownloader = [[Downloader alloc] initWithURL:url postData:post delegate:self];
    infoDownloader.tag = kDownloaderTagCampaignList;
    [infoDownloader startDownloading];
}

/** @ghidraAddress 0xc49b0 */
- (void)dealloc {
    [self clearArtworkCache];
    // The binary sends -setDelegate:nil to the NSCache; NSCache exposes a delegate.
    artworkCache.delegate = nil;
}

#pragma mark - UITableViewDataSource

/** @ghidraAddress 0xbf800 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)aTableView {
    return 1;
}

/** @ghidraAddress 0xbf770 */
- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section {
    if (downloadMusicList) {
        return downloadMusicList.count;
    }
    return 0;
}

/** @ghidraAddress 0xbf808 */
- (CGFloat)tableView:(UITableView *)aTableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [StoreCampaignTableViewCell cellHeight:isPad];
}

/** @ghidraAddress 0xbf790 */
- (void)tableView:(UITableView *)aTableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath {
    cell.backgroundColor = UIColor.clearColor;
}

/** @ghidraAddress 0xbf344 */
- (UITableViewCell *)tableView:(UITableView *)aTableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    StoreCampaignTableViewCell *cell =
        [tableView dequeueReusableCellWithIdentifier:kCampaignCellReuseIdentifier];
    if (!cell) {
        cell = [[StoreCampaignTableViewCell alloc] initWithDeviceType:isPad
                                                      reuseIdentifier:kCampaignCellReuseIdentifier
                                                                  tag:(int)indexPath.row];
    }

    CampaignItemInfo *info = downloadMusicList[indexPath.row];
    cell.ctrlDelegate = self;
    [cell setInfo:info tag:(int)indexPath.row];

    UIImage *artwork = [self getArtwork:info];
    if (artwork) {
        CGSize size = artwork.size;
        if (size.width == size.height) {
            // A square banner: sized from the cell's per-idiom margin and nudged up 2pt on the
            // phone.
            CGSize margin = [cell getArtworkMargin:isPad];
            CGFloat side = isPad ? kArtworkSidePad : kArtworkSidePhone;
            CGFloat yInset = isPad ? 0.0 : kArtworkPhoneYInset;
            cell.artworkView.frame = CGRectMake(margin.width, margin.height - yInset, side, side);
        } else {
            // A non-square banner: sized to the cell's full item size at the origin.
            CGSize itemSize = [cell getItemSize:isPad];
            cell.artworkView.frame = CGRectMake(0.0, 0.0, itemSize.width, itemSize.height);
        }
        cell.artworkView.image = artwork;

        __weak UIImageView *weakArtwork = cell.artworkView;
        [UIView animateWithDuration:kArtworkFadeDuration
                         animations:^{
                           /** @ghidraAddress 0xbf720 */
                           weakArtwork.alpha = 1.0;
                         }
                         completion:^(BOOL finished){
                             /** @ghidraAddress 0xbf76c */
                         }];
    }

    return cell;
}

#pragma mark - Selection

/** @ghidraAddress 0xbfd60 */
- (void)selectItem:(int)index {
    if (working_index != kNoWorkingRow) {
        return;
    }
    working_index = index;
    if (!isPad) {
        CampaignItemInfo *info = downloadMusicList[index];
        isOpenItemDetail = YES;
        CampaignDetailViewController *detail = [[CampaignDetailViewController alloc] init];
        detail.viewController = self;
        detail.delegate = storeViewCtrl;
        [detail setCampaignInfo:info];
        [self.navigationController pushViewController:detail animated:YES];
        itemDetailViewController = detail;
        return;
    }

    [UIApplication.sharedApplication beginIgnoringInteractionEvents];
    isOpenItemDetail = YES;
    coverViewPad.alpha = 0.0;
    itemDetailViewPad.alpha = 0.0;
    [self.view addSubview:coverViewPad];
    [self.view addSubview:itemDetailViewPad];
    [itemDetailViewPad setCampaignInfo:downloadMusicList[index]];
    [itemDetailViewPad loadInfo];

    __weak UIView *weakCover = coverViewPad;
    __weak CampaignItemDetailView *weakDetail = itemDetailViewPad;
    [UIView animateWithDuration:kDetailFadeDuration
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
                       /** @ghidraAddress 0xc015c */
                       weakCover.alpha = 1.0;
                       weakDetail.alpha = 1.0;
                     }
                     completion:^(BOOL finished){
                         /** @ghidraAddress 0xc022c */
                     }];
    [UIApplication.sharedApplication performSelector:@selector(endIgnoringInteractionEvents)
                                          withObject:nil
                                          afterDelay:kEndIgnoringDelay];
}

/** @ghidraAddress 0xc0230 */
- (void)pushCellButton:(nullable id)sender {
    if (working_index != kNoWorkingRow) {
        return;
    }
    working_index = (int)[(UIView *)sender tag];
    if (!isPad) {
        return;
    }

    [UIApplication.sharedApplication beginIgnoringInteractionEvents];
    isOpenItemDetail = YES;
    coverViewPad.alpha = 0.0;
    itemDetailViewPad.alpha = 0.0;
    [self.view addSubview:coverViewPad];
    [self.view addSubview:itemDetailViewPad];
    [itemDetailViewPad setCampaignInfo:downloadMusicList[[(UIView *)sender tag]]];
    [itemDetailViewPad loadInfo];

    __weak UIView *weakCover = coverViewPad;
    __weak CampaignItemDetailView *weakDetail = itemDetailViewPad;
    [UIView animateWithDuration:kDetailFadeDuration
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
                       /** @ghidraAddress 0xc0538 */
                       weakCover.alpha = 1.0;
                       weakDetail.alpha = 1.0;
                     }
                     completion:^(BOOL finished){
                         /** @ghidraAddress 0xc0608 */
                     }];
    [UIApplication.sharedApplication performSelector:@selector(endIgnoringInteractionEvents)
                                          withObject:nil
                                          afterDelay:kEndIgnoringDelay];
}

/** @ghidraAddress 0xbf82c */
- (void)handleTapCoverView:(nullable UITapGestureRecognizer *)recognizer {
    [UIApplication.sharedApplication beginIgnoringInteractionEvents];
    [itemDetailViewPad cancelLoading];
    [itemDetailViewPad stopSample];
    isOpenItemDetail = NO;

    __weak CampaignItemDetailView *weakDetail = itemDetailViewPad;
    __weak UIView *weakCover = coverViewPad;
    __weak StoreCampaignViewController *weakSelf = self;
    [UIView animateWithDuration:kDetailFadeDuration
        delay:0.0
        options:UIViewAnimationOptionBeginFromCurrentState
        animations:^{
          /** @ghidraAddress 0xbfa94 */
          weakCover.alpha = 0.0;
          weakDetail.alpha = 0.0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0xbfb58 */
          [weakCover removeFromSuperview];
          [weakDetail removeCampaignInfo];
          [weakDetail removeFromSuperview];
          StoreCampaignViewController *strongSelf = weakSelf;
          strongSelf->working_index = kNoWorkingRow;
        }];
    [UIApplication.sharedApplication performSelector:@selector(endIgnoringInteractionEvents)
                                          withObject:nil
                                          afterDelay:kEndIgnoringDelay];
}

/** @ghidraAddress 0xc4a2c */
- (void)addOpenDetail:(NSInteger)campaignID {
    if (campaignID < 0 || downloadMusicList.count == 0) {
        return;
    }

    // Find the row whose campaign ID matches; -1 means no match.
    int foundIndex = kNoWorkingRow;
    int scanIndex = 0;
    BOOL matched = NO;
    for (CampaignItemInfo *item in downloadMusicList) {
        if ((NSInteger)item.campaignID == campaignID) {
            foundIndex = scanIndex;
            matched = YES;
            break;
        }
        ++scanIndex;
    }
    if (!matched) {
        return;
    }
    if (foundIndex < 0) {
        return;
    }

    if (working_index == kNoWorkingRow) {
        [self selectItem:foundIndex];
        return;
    }

    if (!isPad) {
        [itemDetailViewController refreshCampaignItem:downloadMusicList[foundIndex]];
    } else {
        [itemDetailViewPad cancelLoading];
        [itemDetailViewPad stopSample];
        [itemDetailViewPad removeCampaignInfo];
        // FAITHFUL QUIRK: the pad arm reads the item from downloadingList (the artwork in-flight
        // list), not downloadMusicList like the search loop and the phone arm above. The binary
        // indexes downloadingList here at 0x1000c4bcc.
        [itemDetailViewPad setCampaignInfo:downloadingList[foundIndex]];
        [itemDetailViewPad loadInfo];
    }
    working_index = foundIndex;
}

/** @ghidraAddress 0xc4990 */
- (void)itemDeselect {
    working_index = kNoWorkingRow;
    isOpenItemDetail = NO;
}

/** @ghidraAddress 0xc4a1c */
- (void)initialCampaignID:(NSInteger)campaignID {
    startUpID = campaignID;
}

#pragma mark - External links

/** @ghidraAddress 0xbfc60 */
- (void)pushExternalLink:(nullable id)sender {
    int tag = (int)[(UIView *)sender tag];
    if (tag < 0) {
        return;
    }
    CampaignItemInfo *info = downloadMusicList[tag];
    if (info && info.linkURL) {
        [UIApplication.sharedApplication openURL:info.linkURL];
    }
}

/** @ghidraAddress 0xc060c */
- (void)moveExternalLink {
    if (working_index < 0) {
        return;
    }
    CampaignItemInfo *info = downloadMusicList[working_index];
    if (info && info.linkURL) {
        [UIApplication.sharedApplication openURL:info.linkURL];
    }
}

#pragma mark - Download flow

/** @ghidraAddress 0xc06f0 */
- (void)itemDownload {
    if (working_index == kNoWorkingRow) {
        return;
    }
    CampaignItemInfo *info = downloadMusicList[working_index];
    if (!info) {
        return;
    }
    switch (info.buttonType) {
    case kButtonTypeInfoDownload:
        [self itemInfoDownload];
        break;
    case kButtonTypeNotUnlockable:
        [AlertViewManager.sharedManager
            makeAlert:kAlertTypePlain
             delegate:self
                  tag:kAlertTagNotUnlockable
                title:kEmptyValue
                  msg:kNotUnlockableMessage
               cancel:[NSBundle.mainBundle localizedStringForKey:kLocKeyOK
                                                           value:kEmptyValue
                                                           table:nil]
              btnText:nil
                 show:YES];
        break;
    case kButtonTypeUpdate:
        [self displayUpdateAlert];
        break;
    case kButtonTypeSerial: {
        NSString *cancelText = [NSBundle.mainBundle localizedStringForKey:kLocKeyCancel
                                                                    value:kEmptyValue
                                                                    table:nil];
        NSString *okText = [NSBundle.mainBundle localizedStringForKey:kLocKeyOK
                                                                value:kEmptyValue
                                                                table:nil];
        [AlertViewManager.sharedManager makeAlert:kAlertTypeTextInput
                                         delegate:self
                                              tag:kAlertTagSerial
                                            title:kSerialTitle
                                              msg:kSerialMessage
                                           cancel:cancelText
                                          btnText:@[ okText ]
                                             show:YES];
        break;
    }
    default:
        break;
    }
}

/** @ghidraAddress 0xc45ec */
- (void)itemInfoDownload {
    NSURL *url = [StoreUtil campaignItemURL];
    CampaignItemInfo *info = downloadMusicList[working_index];
    NSMutableDictionary *body = [[NSMutableDictionary alloc] init];
    [body setValue:kRequestValueTargetJP forKey:kRequestKeyTarget];
    if ([EditorIDManager isExistEditorID]) {
        [body setValue:[EditorIDManager getKeyString:[EditorIDManager getEditorIDKey]]
                forKey:kRequestKeyUserID];
        [body setValue:[EditorIDManager getKeyString:[EditorIDManager getEditorPassKey]]
                forKey:kRequestKeyPassword];
    }
    [body setValue:[NSString stringWithFormat:kIntegerFormat, info.campaignID]
            forKey:kRequestKeyCampaignID];
    NSData *post = [[CJSONSerializer serializer] serializeDictionary:body error:nil];
    itemURLDownloader = [[Downloader alloc] initWithURL:url postData:post delegate:self];
    itemURLDownloader.tag = kDownloaderTagItemInfo;
    [itemURLDownloader startDownloading];
}

/** @ghidraAddress 0xc48d8 */
- (void)itemUpdate {
    CampaignItemInfo *info = downloadMusicList[working_index];
    [info termCheck];
    if (!isPad) {
        [itemDetailViewController updateCampaignState:info];
    } else {
        [itemDetailViewPad updateCampaignState:info];
    }
}

/** @ghidraAddress 0xc0a04 */
- (void)displayTerm:(nullable id)sender {
    [AlertViewManager.sharedManager makeAlert:kAlertTypePlain
                                     delegate:nil
                                          tag:kAlertTagNotUnlockable
                                        title:kTermTitle
                                          msg:kTermMessage
                                       cancel:[NSBundle.mainBundle localizedStringForKey:kLocKeyOK
                                                                                   value:kEmptyValue
                                                                                   table:nil]
                                      btnText:nil
                                         show:YES];
}

/** @ghidraAddress 0xc0ae8 */
- (void)displayUpdateAlert {
    NSString *cancelText = [NSBundle.mainBundle localizedStringForKey:kLocKeyCancel
                                                                value:kEmptyValue
                                                                table:nil];
    [AlertViewManager.sharedManager makeAlert:kAlertTypePlain
                                     delegate:self
                                          tag:kAlertTagUpdate
                                        title:kEmptyValue
                                          msg:kUpdateMessage
                                       cancel:cancelText
                                      btnText:@[ kLocKeyUpdate ]
                                         show:YES];
}

/** @ghidraAddress 0xc0c4c */
- (void)alertSelect:(NSDictionary *)info {
    if ([info[kAlertKeyButtonMessage] intValue] != kSerialConfirmButton) {
        return;
    }
    int tag = [info[kAlertKeyTag] intValue];
    if (tag == kSerialConfirmButton) {
        NSString *code = info[kAlertKeyMessage];
        if (code.length == 0) {
            return;
        }
        CampaignItemInfo *item = downloadMusicList[working_index];
        NSMutableDictionary *body = [[NSMutableDictionary alloc] init];
        [body setValue:kRequestValueTargetJP forKey:kRequestKeyTarget];
        if ([EditorIDManager isExistEditorID]) {
            [body setValue:[EditorIDManager getKeyString:[EditorIDManager getEditorIDKey]]
                    forKey:kRequestKeyUserID];
            [body setValue:[EditorIDManager getKeyString:[EditorIDManager getEditorPassKey]]
                    forKey:kRequestKeyPassword];
        }
        [body setValue:code forKey:kRequestKeyCode];
        [body setValue:[NSString stringWithFormat:kIntegerFormat, item.campaignID]
                forKey:kRequestKeyCampaignID];
        NSData *post = [[CJSONSerializer serializer] serializeDictionary:body error:nil];
        NSURL *url = [StoreUtil campaignSerialCheckURL];
        termsChecker = [[Downloader alloc] initWithURL:url postData:post delegate:self];
        termsChecker.tag = kDownloaderTagSerialCheck;
        [termsChecker startDownloading];
    } else if (tag == kSerialOpenStoreButton) {
        NSURL *storeURL = [NSURL URLWithString:kAppStoreURLString];
        [UIApplication.sharedApplication openURL:storeURL];
    }
}

/** @ghidraAddress 0xc27cc */
- (void)storeDialogCancel:(id)dialogView {
    if (infoDownloader) {
        [infoDownloader cancel];
        infoDownloader = nil;
    }
    if (dlManager) {
        [dlManager cancel];
        dlManager = nil;
        [self itemUpdate];
    }
    [downloadMusicList[working_index] termCheck];
    [storeViewCtrl hideModalDialog];
}

#pragma mark - Downloader delegate

/** @ghidraAddress 0xc1094 */
- (void)downloaderFinished:(id)downloader {
    if (infoDownloader == downloader) {
        NSDictionary *json = [downloader getDataInJSON];
        if (json) {
            if ([json[kResponseKeyStatus] intValue] == 0) {
                NSArray *list = json[kResponseKeyList];
                if (list.count != 0) {
                    unlockMusicCheckList = [NSArray arrayWithArray:list];
                    [self refreshUnlockTable];
                }
            } else {
                NSString *error = json[kResponseKeyError];
                if (error) {
                    [AlertViewManager.sharedManager
                        makeAlert:kAlertTypePlain
                         delegate:nil
                              tag:kAlertTagNotUnlockable
                            title:nil
                              msg:error
                           cancel:[NSBundle.mainBundle localizedStringForKey:kLocKeyOK
                                                                       value:kEmptyValue
                                                                       table:nil]
                          btnText:nil
                             show:YES];
                }
            }
        }
    }

    if (musicInfoDownloader == downloader) {
        NSDictionary *response = [StoreUtil checkStoreResponse:[downloader getData]];
        if (response) {
            StoreMusicInfo *musicInfo = [[StoreMusicInfo alloc] initWithDictionary:response];
            if (musicInfo) {
                StoreDialogView *dialog = storeViewCtrl.modalDialog;
                [dialog layout:NO];
                musicName = musicInfo.name;
                dialog.labelMessage.text = [NSString
                    stringWithFormat:[NSBundle.mainBundle localizedStringForKey:kLocKeyDownloading
                                                                          value:kEmptyValue
                                                                          table:nil],
                                     musicName];
                dialog.progressView.progress = 0.0;
                [storeViewCtrl showModalDialog:self];

                BOOL changed = [StoreMusicListManager.sharedManager addMusic:musicInfo];
                if (musicInfo.extendMusicID != 0) {
                    changed = (changed || [StoreMusicListManager.sharedManager
                                              addMusic:musicInfo.getExtendInfo]) &
                              1;
                }
                if (changed) {
                    [StoreMusicListManager.sharedManager saveMusicList];
                }
                [downloadMusicList[working_index] termCheck];
                [self refreshUnlockBadge];

                NSString *tunePath = [StoreUtil filePathForMusicID:musicInfo.musicID];
                StoreDownloadTask *tuneTask =
                    [[StoreDownloadTask alloc] initWithURL:musicInfo.itemURL path:tunePath];
                NSMutableArray *tasks = [NSMutableArray arrayWithObject:tuneTask];
                if (musicInfo.extendMusicID != 0) {
                    NSString *extendPath =
                        [StoreUtil filePathForMusicID:(int)musicInfo.extendMusicID];
                    StoreDownloadTask *extendTask =
                        [[StoreDownloadTask alloc] initWithURL:musicInfo.extendItemURL
                                                          path:extendPath];
                    [tasks addObject:extendTask];
                }
                dlManager = [[StoreDownloadManager alloc] initWithTasks:tasks delegate:self];
                [dlManager start];
            }
        }
    }

    if (termsChecker == downloader) {
        NSDictionary *json = [downloader getDataInJSON];
        if (json) {
            if ([json[kResponseKeyStatus] intValue] == 0) {
                [downloadMusicList[working_index] replaceServerUnlock:YES];
                [self itemUpdate];
                [self itemInfoDownload];
            } else {
                NSString *error = json[kResponseKeyError];
                if (error) {
                    [AlertViewManager.sharedManager
                        makeAlert:kAlertTypePlain
                         delegate:nil
                              tag:kAlertTagNotUnlockable
                            title:nil
                              msg:error
                           cancel:[NSBundle.mainBundle localizedStringForKey:kLocKeyOK
                                                                       value:kEmptyValue
                                                                       table:nil]
                          btnText:nil
                             show:YES];
                }
            }
        }
        termsChecker = nil;
    }

    if (itemURLDownloader == downloader) {
        NSDictionary *json = [downloader getDataInJSON];
        if (json) {
            if ([json[kResponseKeyStatus] intValue] == 0) {
                CampaignItemInfo *item = downloadMusicList[working_index];
                if (item.itemType == kItemTypeMarker) {
                    markerDownloader =
                        [[Downloader alloc] initWithURL:[NSURL URLWithString:json[kResponseKeyURL]]
                                               delegate:self];
                    markerDownloader.tag = kDownloaderTagMarker;
                    [markerDownloader startDownloading];
                    StoreDialogView *dialog = storeViewCtrl.modalDialog;
                    [dialog layout:NO];
                    dialog.labelMessage.text = [NSString
                        stringWithFormat:[NSBundle.mainBundle
                                             localizedStringForKey:kLocKeyDownloadingMarker
                                                             value:kEmptyValue
                                                             table:nil]];
                    dialog.progressView.progress = 0.0;
                    [storeViewCtrl showModalDialog:self];
                } else if (item.itemType == kItemTypeTune && json[kResponseKeyURL]) {
                    NSURL *musicURL = [StoreUtil privilegeMusicInfoURL:(unsigned int)item.itemID];
                    musicInfoDownloader = [[Downloader alloc] initWithURL:musicURL delegate:self];
                    musicInfoDownloader.tag = kDownloaderTagMusicInfo;
                    [musicInfoDownloader startDownloading];
                }
            } else {
                NSString *error = json[kResponseKeyError];
                [AlertViewManager.sharedManager
                    makeAlert:kAlertTypePlain
                     delegate:nil
                          tag:kAlertTagNotUnlockable
                        title:nil
                          msg:error
                       cancel:[NSBundle.mainBundle localizedStringForKey:kLocKeyOK
                                                                   value:kEmptyValue
                                                                   table:nil]
                      btnText:nil
                         show:YES];
            }
        }
        itemURLDownloader = nil;
    }

    if (markerDownloader == downloader) {
        NSData *data = [downloader getData];
        BOOL verified = NO;
        if (data.length > kMd5DigestLength) {
            unsigned char digest[kMd5DigestLength];
            NSUInteger payloadLength = data.length - kMd5DigestLength;
            [data getBytes:digest range:NSMakeRange(payloadLength, kMd5DigestLength)];
            verified = VerifyMd5Digest(data.bytes, (unsigned int)payloadLength, digest);
        }
        markerDownloader = nil;
        if (verified) {
            [storeViewCtrl hideModalDialog];
            CampaignItemInfo *item = downloadMusicList[working_index];
            NSString *markerID = [NSString stringWithFormat:kMarkerFilenameFormat, item.itemID];
            NSString *markerPath = [MarkerManager getMarkerPath:markerID];
            NSRange bannerRange =
                NSMakeRange(kMarkerBannerSubstringLocation, kMarkerBannerSubstringLength);
            NSString *bannerBase = [markerID substringWithRange:bannerRange];
            NSString *bannerName = [NSString stringWithFormat:kMarkerBannerFormat, bannerBase];
            [MarkerManager saveMarker:data markerID:markerID];
            [MarkerManager pullOutMarkerBanner:markerPath bannerID:bannerName];
            NSMutableDictionary *markerInfo = [[NSMutableDictionary alloc] init];
            [markerInfo setObject:markerID forKey:kMarkerKeyID];
            [markerInfo setObject:kMarkerVersionInitial forKey:kMarkerKeyVersion];
            [markerInfo setObject:bannerName forKey:kMarkerKeyBannerName];
            [MarkerManager setMarkerInfo:[NSDictionary dictionaryWithDictionary:markerInfo]];
            [self itemUpdate];
            [self refreshUnlockTable];
        } else {
            [AlertViewManager.sharedManager
                makeAlert:kAlertTypePlain
                 delegate:nil
                      tag:kAlertTagNotUnlockable
                    title:nil
                      msg:kMarkerDownloadFailedMessage
                   cancel:[NSBundle.mainBundle localizedStringForKey:kLocKeyCancel
                                                               value:kEmptyValue
                                                               table:nil]
                  btnText:nil
                     show:YES];
        }
    }
}

/** @ghidraAddress 0xc22ec */
- (void)downloaderError:(id)downloader {
    switch ([(Downloader *)downloader tag]) {
    case kDownloaderTagCampaignList:
        if (!firstDownloadFailed) {
            firstDownloadFailed = YES;
            return;
        }
        infoDownloader = nil;
        [AlertViewManager.sharedManager
            makeAlert:kAlertTypePlain
             delegate:nil
                  tag:kAlertTagNotUnlockable
                title:[NSBundle.mainBundle localizedStringForKey:kLocKeyError
                                                           value:kEmptyValue
                                                           table:nil]
                  msg:[NSBundle.mainBundle localizedStringForKey:kLocKeyNetworkErrorMsg
                                                           value:kEmptyValue
                                                           table:nil]
               cancel:[NSBundle.mainBundle localizedStringForKey:kLocKeyOK
                                                           value:kEmptyValue
                                                           table:nil]
              btnText:nil
                 show:YES];
        break;
    case kDownloaderTagMusicInfo:
        infoDownloader = nil;
        [AlertViewManager.sharedManager
            makeAlert:kAlertTypePlain
             delegate:nil
                  tag:kAlertTagNotUnlockable
                title:[NSBundle.mainBundle localizedStringForKey:kLocKeyError
                                                           value:kEmptyValue
                                                           table:nil]
                  msg:[NSBundle.mainBundle localizedStringForKey:kLocKeyNetworkErrorMsg
                                                           value:kEmptyValue
                                                           table:nil]
               cancel:[NSBundle.mainBundle localizedStringForKey:kLocKeyOK
                                                           value:kEmptyValue
                                                           table:nil]
              btnText:nil
                 show:YES];
        break;
    case kDownloaderTagSerialCheck:
        termsChecker = nil;
        break;
    case kDownloaderTagItemInfo:
        itemURLDownloader = nil;
        [AlertViewManager.sharedManager
            makeAlert:kAlertTypePlain
             delegate:nil
                  tag:kAlertTagNotUnlockable
                title:[NSBundle.mainBundle localizedStringForKey:kLocKeyError
                                                           value:kEmptyValue
                                                           table:nil]
                  msg:[NSBundle.mainBundle localizedStringForKey:kLocKeyNetworkErrorMsg
                                                           value:kEmptyValue
                                                           table:nil]
               cancel:[NSBundle.mainBundle localizedStringForKey:kLocKeyOK
                                                           value:kEmptyValue
                                                           table:nil]
              btnText:nil
                 show:YES];
        break;
    case kDownloaderTagMarker:
        markerDownloader = nil;
        [storeViewCtrl hideModalDialog];
        break;
    default:
        break;
    }
}

#pragma mark - Download manager delegate

/** @ghidraAddress 0xc28cc */
- (void)downloadManagerStartTask:(StoreDownloadManager *)manager {
    NSString *message =
        [NSString stringWithFormat:[NSBundle.mainBundle localizedStringForKey:kLocKeyDownloading
                                                                        value:kEmptyValue
                                                                        table:nil],
                                   musicName];
    if (manager.currentIndex == 1) {
        message = [NSString
            stringWithFormat:[NSBundle.mainBundle localizedStringForKey:kLocKeyDownloadingAddition
                                                                  value:kEmptyValue
                                                                  table:nil],
                             musicName];
    }
    storeViewCtrl.modalDialog.labelMessage.text = message;
}

/** @ghidraAddress 0xc2ae4 */
- (void)downloadManagerCompleted:(StoreDownloadManager *)manager {
    dlManager = nil;
    [downloadMusicList[working_index] termCheck];
    [storeViewCtrl hideModalDialog];
    [self itemUpdate];
}

/** @ghidraAddress 0xc2b94 */
- (void)downloadManagerFailed:(StoreDownloadManager *)manager {
    dlManager = nil;
    [AlertViewManager.sharedManager
        makeAlert:kAlertTypePlain
         delegate:nil
              tag:kAlertTagNotUnlockable
            title:[NSBundle.mainBundle localizedStringForKey:kLocKeyError
                                                       value:kEmptyValue
                                                       table:nil]
              msg:[NSBundle.mainBundle localizedStringForKey:kLocKeyDownloadErrorMsg
                                                       value:kEmptyValue
                                                       table:nil]
           cancel:[NSBundle.mainBundle localizedStringForKey:kLocKeyOK value:kEmptyValue table:nil]
          btnText:nil
             show:YES];
    [self itemUpdate];
    [storeViewCtrl hideModalDialog];
}

/** @ghidraAddress 0xc2d7c */
- (void)downloadManagerProceed:(StoreDownloadManager *)manager {
    CampaignItemInfo *item = downloadMusicList[working_index];
    StoreDialogView *dialog = storeViewCtrl.modalDialog;
    if (item.itemType == kItemTypeMarker) {
        dialog.progressView.progress = markerDownloader.currentProgress;
    } else if (item.itemType == kItemTypeTune) {
        dialog.progressView.progress = dlManager.overallProgress;
    }
}

#pragma mark - Store dialog

/** @ghidraAddress 0xc2eac */
- (void)storeClose {
    [AlertViewManager.sharedManager closeAlert];
}

#pragma mark - List and badge

/** @ghidraAddress 0xc2ef4 */
- (void)reloadUnlockList {
    [self refreshUnlockTable];
    [self refreshMusicList];
}

/** @ghidraAddress 0xc3168 */
- (void)refreshMusicList {
    for (NSUInteger i = 0; i < downloadMusicList.count; ++i) {
        [self getArtwork:downloadMusicList[i]];
    }
    [tableView reloadData];
}

/** @ghidraAddress 0xc325c */
- (void)refreshUnlockTable {
    if (!unlockMusicCheckList) {
        return;
    }
    downloadMusicList = nil;
    downloadMusicList = [[NSMutableArray alloc] init];
    int newUnlockCount = 0;
    for (NSUInteger i = 0; i < unlockMusicCheckList.count; ++i) {
        NSMutableDictionary *entry =
            [NSMutableDictionary dictionaryWithDictionary:unlockMusicCheckList[i]];
        CampaignItemInfo *item = [[CampaignItemInfo alloc] initWithDictionary:entry];
        newUnlockCount += [item checkNewUnlock];
        if (item.hideType != kHideTypeHidden) {
            BOOL duplicate = NO;
            for (CampaignItemInfo *existing in downloadMusicList) {
                if (item.campaignID == existing.campaignID) {
                    duplicate = YES;
                    break;
                }
            }
            if (!duplicate) {
                [downloadMusicList addObject:item];
            }
        }
    }

    // Open any campaign that was queued to open at start-up, then clear the queue.
    if (startUpID != kNoStartUpID) {
        int flatIndex = 0;
        for (CampaignItemInfo *item in downloadMusicList) {
            if ((NSInteger)item.campaignID == startUpID) {
                [self selectItem:flatIndex];
                break;
            }
            ++flatIndex;
        }
        startUpID = kNoStartUpID;
    }

    [self setBadgeCnt:newUnlockCount];
}

/** @ghidraAddress 0xc369c */
- (void)refreshUnlockBadge {
    int count = 0;
    for (CampaignItemInfo *item in downloadMusicList) {
        if (item) {
            count += [item checkNewUnlock];
        }
    }
    [self setBadgeCnt:count];
}

/** @ghidraAddress 0xc37e4 */
- (void)setBadgeCnt:(int)count {
    if (count < 1) {
        self.tabBarItem.badgeValue = nil;
    } else {
        self.tabBarItem.badgeValue = [NSString stringWithFormat:kIntegerFormat, count];
    }
}

#pragma mark - Artwork

/** @ghidraAddress 0xc2f28 */
- (nullable UIImage *)getArtwork:(nullable id)info {
    NSNumber *key = @([info campaignID]);
    UIImage *cached = [artworkCache objectForKey:key];
    if (!cached) {
        if ([downloadingList indexOfObject:key] == NSNotFound && [info bannerURL]) {
            NSURL *bannerURL = [NSURL URLWithString:[info bannerURL]];
            if (bannerURL) {
                NSInvocationOperation *operation =
                    [[NSInvocationOperation alloc] initWithTarget:self
                                                         selector:@selector(downloadImageSync:)
                                                           object:@[ bannerURL, key ]];
                [downloadingList addObject:key];
                [operationQueue addOperation:operation];
            }
        }
    }
    return cached;
}

/** @ghidraAddress 0xc3d14 */
- (void)downloadImageSync:(nullable NSArray *)arguments {
    @autoreleasepool {
        NSURL *url = arguments[0];
        NSNumber *campaignID = arguments[1];
        NSMutableURLRequest *request =
            [NSMutableURLRequest requestWithURL:url
                                    cachePolicy:NSURLRequestUseProtocolCachePolicy
                                timeoutInterval:kArtworkRequestTimeout];
        [request setValue:JubeatAppDelegate.appDelegate.userAgent forHTTPHeaderField:@"User-Agent"];
        __weak StoreCampaignViewController *weakSelf = self;
        NSURLSessionDataTask *task = [NSURLSession.sharedSession
            dataTaskWithRequest:request
              completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                /** @ghidraAddress 0xc3f14 */
                if (!data) {
                    return;
                }
                StoreCampaignViewController *strongSelf = weakSelf;
                UIImage *image = [[UIImage alloc] initWithData:data];
                if (image) {
                    if (UIScreen.mainScreen.scale != 1.0) {
                        image = [UIImage imageWithCGImage:image.CGImage
                                                    scale:UIScreen.mainScreen.scale
                                              orientation:UIImageOrientationUp];
                    }
                    [strongSelf->artworkCache setObject:image forKey:campaignID];
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                  /** @ghidraAddress 0xc40fc */
                  StoreCampaignViewController *innerSelf = weakSelf;
                  UIImage *cached = [innerSelf->artworkCache objectForKey:campaignID];
                  if (cached) {
                      for (StoreCampaignTableViewCell *cell in innerSelf->tableView.visibleCells) {
                          if (cell.campaignID == campaignID.intValue) {
                              cell.artworkView.image = cached;
                              CGSize size = cached.size;
                              if (size.width == size.height) {
                                  CGSize margin = [cell getArtworkMargin:innerSelf->isPad];
                                  CGFloat side =
                                      innerSelf->isPad ? kArtworkSidePad : kArtworkSidePhone;
                                  CGFloat yInset = innerSelf->isPad ? 0.0 : kArtworkPhoneYInset;
                                  cell.artworkView.frame =
                                      CGRectMake(margin.width, margin.height - yInset, side, side);
                              } else {
                                  CGSize itemSize = [cell getItemSize:innerSelf->isPad];
                                  cell.artworkView.frame =
                                      CGRectMake(0.0, 0.0, itemSize.width, itemSize.height);
                              }
                              cell.artworkView.image = cached;
                              __weak UIImageView *weakArtwork = cell.artworkView;
                              [UIView animateWithDuration:kArtworkFadeDuration
                                               animations:^{
                                                 /** @ghidraAddress 0xc44fc */
                                                 weakArtwork.alpha = 1.0;
                                               }
                                               completion:^(BOOL finished){
                                                   /** @ghidraAddress 0xc4548 */
                                               }];
                              break;
                          }
                      }
                  }
                  [innerSelf->downloadingList removeObject:campaignID];
                });
              }];
        [task resume];
    }
}

/** @ghidraAddress 0xc3cb4 */
- (void)clearArtworkCache {
    [artworkCache removeAllObjects];
    [operationQueue cancelAllOperations];
    [downloadingList removeAllObjects];
}

#pragma mark - View lifecycle

/** @ghidraAddress 0xc388c */
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

/** @ghidraAddress 0xc38c4 */
- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationController.navigationBar.exclusiveTouch = YES;
    for (UIView *subview in self.navigationController.navigationBar.subviews) {
        subview.exclusiveTouch = YES;
    }
}

/** @ghidraAddress 0xc3aa4 */
- (void)viewDidUnload {
    [super viewDidUnload];
    tableView = nil;
}

/** @ghidraAddress 0xc3afc */
- (void)viewWillAppear:(BOOL)animated {
    if (unlockMusicCheckList) {
        [self refreshUnlockTable];
        [self refreshMusicList];
    }
    [super viewWillAppear:animated];
}

/** @ghidraAddress 0xc3b78 */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [tableView flashScrollIndicators];
}

/** @ghidraAddress 0xc3bd4 */
- (void)viewWillDisappear:(BOOL)animated {
    [AlertViewManager.sharedManager closeAlert];
    [super viewWillDisappear:animated];
}

/** @ghidraAddress 0xc3c5c */
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

/** @ghidraAddress 0xc3c94 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (interfaceOrientation - 1) < 2;
}

/** @ghidraAddress 0xc3ca4 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    // The binary returns 6 = (1 << Portrait) | (1 << PortraitUpsideDown).
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

/** @ghidraAddress 0xc3cac */
- (BOOL)shouldAutorotate {
    return YES;
}

@end
