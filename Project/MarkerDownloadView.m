#import "MarkerDownloadView.h"

#import "JubeatAppDelegate.h"
#import "MarkerManager.h"
#import "StoreUtil.h"

// The progress panel's frame differs by idiom. Every value is read from __const as a double.
static const CGFloat kDialogWidthPhone = 300.0;  // @ghidraAddress 0x28f2d0
static const CGFloat kDialogHeightPhone = 270.0; // @ghidraAddress 0x28f2d8
static const CGFloat kDialogWidthPad = 400.0;    // @ghidraAddress 0x28f2e0
static const CGFloat kDialogHeightPad = 300.0;   // @ghidraAddress 0x28f2d0

// The message font is larger on a pad.
static const CGFloat kMessageFontSizePhone = 16.0; // fmov immediate at 0x5fe54
static const CGFloat kMessageFontSizePad = 18.0;   // fmov immediate at 0x5fde0

// The dimming cover: forty-per-cent black, faded in and out.
static const CGFloat kCoverAlpha = 0.4;          // @ghidraAddress 0x28f2c0
static const CGFloat kCentreRatio = 0.5;         // fmov immediate at 0x5fe94
static const NSTimeInterval kFadeDuration = 0.3; // @ghidraAddress 0x28f260

// The queue is built for markers whose identifier is below this value.
static const int kMaxMarkerID = 1000;

// The current marker is reset to this identifier when the check is cancelled: "mk%04d" with 26.
static const int kDefaultMarkerNumber = 26;

// The two alerts identify themselves to -alertSelect: by these tags.
static const int kAlertTagSkipConfirm = 1;
static const int kAlertTagDownloadRetry = 2;

// The cancel-slot button, index 0 in each alert. In the retry alert this is "再試行" (retry) and
// in the skip alert it is "Cancel"; the other button follows at index 1.
static const int kAlertButtonCancelSlot = 0;

// A user-default holding the current marker identifier as "mkNNNN".
static NSString *const kMarkerIDFormat = @"mk%04d";
static NSString *const kBannerNameFormat = @"tm%04d_banner";
static NSString *const kPrefCurrentMarkerID = @"PrefCurrentMarkerID";

// Keys in a downloaded / installed marker entry, and in a built download task.
static NSString *const kListKey = @"List";
static NSString *const kIDKey = @"ID";
static NSString *const kMarkerIDKey = @"markerID";
static NSString *const kVersionKey = @"version";
static NSString *const kVersionCapKey = @"Version";
static NSString *const kBannerNameKey = @"bannerName";
static NSString *const kDefaultVersion = @"0.0.0";

// Keys the alert result carries.
static NSString *const kInfoTagKey = @"Tag";
static NSString *const kInfoButtonKey = @"btnMessage";

// The two-character marker-number slice: "mkNNNN" -> characters 2..5 parsed as an integer.
static const NSUInteger kMarkerNumberLocation = 2;
static const NSUInteger kMarkerNumberLength = 4;

// MarkerManager vends the installed list and its default size; neither is reconstructed yet.
@interface MarkerManager (MarkerDownloadViewPending)
+ (NSMutableArray *)getMarkerList;
+ (int)getDefaultMarkerSize;
@end

@implementation MarkerDownloadView {
    StoreDialogView *dialogView;
    UIView *coverView;
    NSMutableArray *dlMarkerList;
    BOOL bEnableMarker; // Read but never written by any compiled method of this class.
    BOOL bListLegal;
    Downloader *listDownloader;
    MarkerDownloadManager *dlManager;
    int downloadListSize;
    int downloadedSize; // Set to zero in -createMarkerDownloadList but never read anywhere.
    BOOL isShowDialog;
}

#pragma mark - Lifecycle

/** @ghidraAddress 0x5fbb4 */
- (instancetype)init {
    CGRect bounds = UIScreen.mainScreen.bounds;
    self = [super initWithFrame:bounds];
    if (self) {
        coverView = [[UIView alloc] initWithFrame:bounds];
        coverView.opaque = NO;
        // The original built this with colorWithWhite:0 alpha:0.4.
        coverView.backgroundColor = [UIColor colorWithWhite:0 alpha:kCoverAlpha];
        coverView.alpha = 0;
        [self addSubview:coverView];

        BOOL isPad = JubeatAppDelegate.appDelegate.isPad;
        CGRect dialogFrame;
        CGFloat fontSize;
        if (isPad) {
            dialogFrame = CGRectMake(0, 0, kDialogWidthPad, kDialogHeightPad);
            fontSize = kMessageFontSizePad;
        } else {
            dialogFrame = CGRectMake(0, 0, kDialogWidthPhone, kDialogHeightPhone);
            fontSize = kMessageFontSizePhone;
        }
        dialogView = [[StoreDialogView alloc] initWithFrame:dialogFrame];
        dialogView.labelMessage.font = [UIFont systemFontOfSize:fontSize];
        dialogView.center =
            CGPointMake(bounds.size.width * kCentreRatio, bounds.size.height * kCentreRatio);
        dialogView.progressView.progress = 0;
        [coverView addSubview:dialogView];
        [dialogView layout:NO];

        bListLegal = NO;
        isShowDialog = NO;
    }
    return self;
}

#pragma mark - Flow

/** @ghidraAddress 0x5ff44 */
- (void)show {
    if (!JubeatAppDelegate.appDelegate.isMarkerLegal) {
        [self showModalDialog];
        isShowDialog = YES;
    }
    [self downloadMarkerList];
}

/** @ghidraAddress 0x5ffd0 */
- (void)downloadMarkerList {
    NSURL *url = [StoreUtil markerListURL];
    listDownloader = [[Downloader alloc] initWithURL:url delegate:self];
    [listDownloader startDownloading];
}

/** @ghidraAddress 0x60068 */
- (void)markerDownloadEnd {
    [self hideModalDialog];
    if ([self.delegate respondsToSelector:@selector(markerCheckEnd)]) {
        [self.delegate performSelector:@selector(markerCheckEnd)];
    }
}

/** @ghidraAddress 0x60128 */
- (void)markerDownloadCancel {
    [self hideModalDialog];
    [dlManager cancel];
    [NSUserDefaults.standardUserDefaults
        setObject:[NSString stringWithFormat:kMarkerIDFormat, kDefaultMarkerNumber]
           forKey:kPrefCurrentMarkerID];
    if ([self.delegate respondsToSelector:@selector(markerCheckEnd)]) {
        [self.delegate performSelector:@selector(markerCheckEnd)];
    }
}

/** @ghidraAddress 0x60270 */
- (void)markerDownload {
    if (dlMarkerList.count == 0) {
        [self markerDownloadEnd];
        return;
    }
    dialogView.labelMessage.text = [NSString stringWithFormat:@"マーカーをダウンロードしています"];
    dialogView.progressView.progress = 0;
    dialogView.progressView.hidden = NO;
    dlManager = [[MarkerDownloadManager alloc] initWithTasks:dlMarkerList delegate:self];
    [dlManager start];
}

/** @ghidraAddress 0x603ec */
- (void)createMarkerDownloadList {
    NSMutableArray *tasks = [[NSMutableArray alloc] init];
    NSMutableArray *installed = [MarkerManager getMarkerList];
    for (NSDictionary *downloaded in dlMarkerList) {
        NSRange numberRange = NSMakeRange(kMarkerNumberLocation, kMarkerNumberLength);
        int downloadedID = [[downloaded[kIDKey] substringWithRange:numberRange] intValue];
        BOOL matched = NO;
        for (NSDictionary *entry in installed) {
            int installedID = [[entry[kMarkerIDKey] substringWithRange:numberRange] intValue];
            if (downloadedID == installedID) {
                NSString *installedVersion = entry[kVersionKey];
                NSString *downloadedVersion = downloaded[kVersionCapKey];
                if (installedVersion == nil ||
                    [installedVersion compare:downloadedVersion] == NSOrderedAscending) {
                    [tasks addObject:[NSDictionary dictionaryWithDictionary:downloaded]];
                }
                matched = YES;
                break;
            }
        }
        if (matched) {
            continue;
        }
        if (downloadedID < kMaxMarkerID) {
            NSString *markerID = [NSString stringWithFormat:kMarkerIDFormat, downloadedID];
            NSString *bannerName = [NSString stringWithFormat:kBannerNameFormat, downloadedID];
            NSMutableDictionary *installedEntry = [[NSMutableDictionary alloc] init];
            installedEntry[kVersionKey] = kDefaultVersion;
            installedEntry[kMarkerIDKey] = markerID;
            installedEntry[kBannerNameKey] = bannerName;
            [installed addObject:[NSDictionary dictionaryWithDictionary:installedEntry]];
            [tasks addObject:[NSDictionary dictionaryWithDictionary:downloaded]];
        }
    }
    dlMarkerList = nil;
    dlMarkerList = [NSMutableArray arrayWithArray:tasks];
    downloadListSize = (int)dlMarkerList.count;
    downloadedSize = 0;
    if (!isShowDialog && downloadListSize != 0) {
        [self showModalDialog];
        isShowDialog = YES;
    }
}

#pragma mark - DownloaderDelegate

/** @ghidraAddress 0x609bc */
- (void)downloaderError:(id)downloader {
    [self listDownloadFailed];
}

/** @ghidraAddress 0x609c8 */
- (void)downloaderFinished:(id)downloader {
    if (listDownloader != downloader) {
        return;
    }
    NSDictionary *response = [StoreUtil checkStoreResponse:[downloader getData]];
    if (response == nil) {
        if (bEnableMarker) {
            [self markerDownloadEnd];
        } else {
            [self showDownloadRetryAlert];
        }
        return;
    }
    NSArray *list = response[kListKey];
    if (list.count >= (NSUInteger)[MarkerManager getDefaultMarkerSize]) {
        bListLegal = YES;
        dlMarkerList = [NSMutableArray arrayWithArray:list];
        [self createMarkerDownloadList];
        [self markerDownload];
    } else {
        [self listDownloadFailed];
    }
}

/** @ghidraAddress 0x60b60 */
- (void)listDownloadFailed {
    if (JubeatAppDelegate.appDelegate.isMarkerLegal) {
        [self markerDownloadEnd];
    } else {
        [self downloadManagerFailed:nil];
    }
}

#pragma mark - Alerts

/** @ghidraAddress 0x60bec */
- (void)showDownloadRetryAlert {
    NSString *cancelTitle = [NSBundle.mainBundle localizedStringForKey:@"再試行"
                                                                 value:@""
                                                                 table:nil];
    NSString *skipTitle = [NSBundle.mainBundle localizedStringForKey:@"Skip" value:@"" table:nil];
    [[AlertViewManager sharedManager]
        makeAlert:0
         delegate:self
              tag:kAlertTagDownloadRetry
            title:nil
              msg:@"ダウンロードに失敗しました。このまま進めるとマーカーが初期の物に固定されます。"
           cancel:cancelTitle
          btnText:@[ skipTitle ]
             show:YES];
}

/** @ghidraAddress 0x60d9c */
- (void)showListSkipAlert {
    NSString *cancelTitle = [NSBundle.mainBundle localizedStringForKey:@"Cancel"
                                                                 value:@""
                                                                 table:nil];
    NSString *okTitle = [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil];
    [[AlertViewManager sharedManager]
        makeAlert:0
         delegate:self
              tag:kAlertTagSkipConfirm
            title:nil
              msg:@"このまま進めるとマーカーが初期の物に固定されます。"
           cancel:cancelTitle
          btnText:@[ okTitle ]
             show:YES];
}

/** @ghidraAddress 0x60f4c */
- (void)alertSelect:(NSDictionary *)info {
    int button = [info[kInfoButtonKey] intValue];
    int tag = [info[kInfoTagKey] intValue];
    if (button == kAlertButtonCancelSlot) {
        if (tag != kAlertTagDownloadRetry) {
            return;
        }
        if (bListLegal) {
            [self createMarkerDownloadList];
            dlManager = [[MarkerDownloadManager alloc] initWithTasks:dlMarkerList delegate:self];
            [dlManager start];
        } else {
            [self downloadMarkerList];
        }
    } else {
        [self markerDownloadCancel];
    }
}

#pragma mark - Modal presentation

/** @ghidraAddress 0x610c8 */
- (void)showModalDialog {
    dialogView.labelMessage.text =
        [NSString stringWithFormat:@"マーカーデータをチェックしています"];
    dialogView.progressView.hidden = YES;
    [dialogView.indicatorView startAnimating];
    dialogView.buttonAbort.enabled = YES;
    dialogView.delegate = self;

    __weak UIView *weakCover = coverView;
    __weak StoreDialogView *weakDialog = dialogView;
    [UIView animateWithDuration:kFadeDuration
        delay:0
        options:UIViewAnimationOptionCurveLinear
        animations:^{
          /** @ghidraAddress 0x61328 */
          weakCover.alpha = 1.0;
        }
        completion:^(BOOL __attribute__((unused)) finished) {
          /** @ghidraAddress 0x61374 */
          weakDialog.buttonAbort.enabled = YES;
        }];
}

/** @ghidraAddress 0x613e0 */
- (void)hideModalDialog {
    dialogView.buttonAbort.enabled = NO;
    dialogView.delegate = nil;

    __weak UIView *weakCover = coverView;
    __weak StoreDialogView *weakDialog = dialogView;
    [UIView animateWithDuration:kFadeDuration
        delay:0
        options:UIViewAnimationOptionCurveLinear
        animations:^{
          /** @ghidraAddress 0x61594 */
          weakCover.alpha = 0;
        }
        completion:^(BOOL __attribute__((unused)) finished) {
          /** @ghidraAddress 0x615e0 */
          [weakDialog.indicatorView stopAnimating];
          [weakCover removeFromSuperview];
        }];
}

#pragma mark - StoreDialogViewDelegate

/** @ghidraAddress 0x616bc */
- (void)storeDialogCancel:(id)dialogView {
    if (bEnableMarker) {
        [self markerDownloadEnd];
    } else {
        [self showListSkipAlert];
    }
}

#pragma mark - MarkerDownloadManagerDelegate

/** @ghidraAddress 0x616e4 */
- (void)downloadManagerProceed:(MarkerDownloadManager *)manager {
    dialogView.progressView.progress = dlManager.overallProgress;
}

/** @ghidraAddress 0x61750 */
- (void)downloadManagerCompleted:(MarkerDownloadManager *)manager {
    [JubeatAppDelegate.appDelegate markerDownloadComplete];
    dlManager = nil;
    [[AlertViewManager sharedManager] closeAlert];
    [self markerDownloadEnd];
}

/** @ghidraAddress 0x617f4 */
- (void)downloadManagerFailed:(MarkerDownloadManager *)manager {
    dlManager = nil;
    [[AlertViewManager sharedManager] closeAlert];
    [self showDownloadRetryAlert];
}

@end
