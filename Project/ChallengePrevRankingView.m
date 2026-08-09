#import "ChallengePrevRankingView.h"

#import "AlertViewManager.h"
#import "ChallengePrevRankingListView.h"
#import "ChallengeStatus.h"
#import "Downloader.h"
#import "JubeatAppDelegate.h"
#import "ScratchUtil.h"
#import "SessionDownloader.h"
#import "SystemUtilities.h"

// The per-tune ranking sub-list, not reconstructed yet; forward-declare only what this view uses.
// See TYPES_PENDING.md.
@class ChallengeRankingListView;

// The ranking sub-list's delegate protocol, not reconstructed yet; forward-declare the selectors
// this view implements. See TYPES_PENDING.md.
@protocol ChallengeRankingListViewDelegate <NSObject>
@optional
/** The ranking sub-list wants to return to the line-up list. */
- (void)closeRanking;
/** A list button was tapped. */
- (void)selectListButton:(nullable id)sender;
/** The list was closed. */
- (void)closeList:(nullable id)sender;
/** The close button was tapped. */
- (void)tapClose:(nullable id)sender;
@end

@interface ChallengeRankingListView : UIView
- (nullable instancetype)initWithFrame:(CGRect)frame
                                 mDict:(nullable NSDictionary *)mDict
                             scratchID:(int)scratchID;
- (void)setADelegate:(nullable id)aDelegate;
@end

// The challenge root view messaged when a session-error alert is dismissed, reached through
// ChallengeStatus. Neither is fully declared yet. See TYPES_PENDING.md.
@protocol ChallengeRootView <NSObject>
- (void)closeChallengeModeSessionError;
@end

@interface ChallengeStatus (PrevRanking)
- (nullable id<ChallengeRootView>)rootView;
@end

// The previous-scratch request's post-body key and the "全曲ランキング" head row it prepends.
static NSString *const kPostPrevKey = @"prev";
static NSString *const kAllTunesRowTitle = @"全曲ランキング";

// The response keys.
static NSString *const kResponseStatusKey = @"status";
static NSString *const kResponseErrorMessageKey = @"err_message";
static NSString *const kResponseMusicListKey = @"music_list";
static NSString *const kResponseScratchIDKey = @"scratch_id";

// The per-record keys.
static NSString *const kRecordMusicIDKey = @"music_id";
static NSString *const kRecordNameKey = @"name";

// The per-task artwork key.
static NSString *const kTaskImageURLKey = @"image_url";

// The alert-info keys.
static NSString *const kAlertInfoButtonMessageKey = @"btnMessage";
static NSString *const kAlertInfoTagKey = @"Tag";

// The default line-up-load failure message when the server supplies none.
static NSString *const kListLoadFailedMessage = @"楽曲リストの取得に失敗しました";

// The download tags distinguishing the line-up load from an artwork fetch.
static const int kTagListLoad = 1;
static const int kTagArtwork = 2;

// The API tag for the line-up load request.
static const int kApiTagListLoad = 9;

// The server status codes handled specially.
static const int kStatusOK = 0;
static const int kStatusServerError = 0x18b53;
static const int kStatusUpdateRequired = 0x186ab;

// The status used when the response carries none.
static const int kStatusNone = -1;

// The alert tags routing the delegate calls.
static const int kListLoadErrorAlertTag = 4;
static const int kArtworkErrorAlertTag = 5;
static const int kServerErrorAlertTag = 9999;
static const int kDownloaderErrorAlertTag = 3;

// The plain-alert type shared by every alert this view raises.
static const int kPlainAlertType = 0;

// The tapped-button index that means "confirmed".
static const int kConfirmButtonIndex = 1;

// The head-row identifier prepended to the line-up: the "all tunes" ranking has no tune of its own.
static const int kAllTunesMusicID = 0;

// The two-stage cross-fade between the line-up and ranking sub-lists.
static const NSTimeInterval kFadeDuration = 0.2;
static const NSTimeInterval kFadeDelay = 0.1;
static const UIViewAnimationOptions kFadeOptions =
    UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction;

@interface ChallengePrevRankingView () <ChallengePrevRankingListViewDelegate,
                                        ChallengeRankingListViewDelegate,
                                        AlertViewManagerDelegate,
                                        DownloaderDelegate>
@end

@implementation ChallengePrevRankingView {
    ChallengePrevRankingListView *lineupListView; // +0x8
    ChallengeRankingListView *rankingListView;    // +0x10
    int scratchID;                                // +0x18
    NSArray *lineupList;                          // +0x20
    NSMutableDictionary *lineupImg;               // +0x28
    int selectLineupIndex;                        // +0x30
    UIImageView *titleView;                       // (declared in the metadata; never assigned)
    UILabel *titleLabel;                          // (declared in the metadata; never assigned)
    CGRect listRect;                              // (declared in the metadata; never assigned)
    UIButton *closeBtn;                           // (declared in the metadata; never assigned)
    NSMutableArray *imageDLTasks;                 // +0x70
    NSDictionary *currentDownload;                // +0x78
}

@synthesize aDelegate = _aDelegate;

#pragma mark - Construction

/** @ghidraAddress 0x141108 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) {
        return self;
    }
    // Fetch the previous event's line-up over a signed session request; the chrome is built lazily
    // once the response and its artwork have arrived.
    NSDictionary *post = [NSDictionary dictionaryWithObjects:@[ @1 ] forKeys:@[ kPostPrevKey ]];
    SessionDownloader *downloader =
        [[SessionDownloader alloc] initWithURL:[ScratchUtil challengePrevScratchURL]
                                postDictionary:post
                                      delegate:self];
    downloader.tag = kTagListLoad;
    downloader.apiTag = kApiTagListLoad;
    [downloader startDownloading];
    lineupImg = [[NSMutableDictionary alloc] init];
    return self;
}

#pragma mark - Navigation

/** @ghidraAddress 0x1412d8 */
- (void)tapClose:(id)sender {
    if ([self.aDelegate respondsToSelector:@selector(closeMenu)]) {
        [self.aDelegate performSelector:@selector(closeMenu)];
    }
}

/** @ghidraAddress 0x141388 */
- (void)selectListCell:(NSIndexPath *)indexPath {
    selectLineupIndex = (int)indexPath.row;
    rankingListView = [[ChallengeRankingListView alloc] initWithFrame:self.frame
                                                                mDict:lineupList[indexPath.row]
                                                            scratchID:scratchID];
    rankingListView.alpha = 0;
    [rankingListView setADelegate:self];
    [self addSubview:rankingListView];

    // Fade the line-up list out, then fade the ranking list in.
    __weak UIView *weakLineupListView = lineupListView;
    __weak UIView *weakRankingListView = rankingListView;
    [UIView animateWithDuration:kFadeDuration
        delay:kFadeDelay
        options:kFadeOptions
        animations:^{
          /** @ghidraAddress 0x14160c */
          weakLineupListView.alpha = 0.0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x141658 */
          [UIView animateWithDuration:kFadeDuration
                                delay:kFadeDelay
                              options:kFadeOptions
                           animations:^{
                             /** @ghidraAddress 0x14170c */
                             weakRankingListView.alpha = 1.0;
                           }
                           completion:nil];
        }];
}

/** @ghidraAddress 0x141770 */
- (void)closeRanking {
    // Fade the ranking list out, then fade the line-up list back in.
    __weak UIView *weakLineupListView = lineupListView;
    __weak UIView *weakRankingListView = rankingListView;
    [UIView animateWithDuration:kFadeDuration
        delay:kFadeDelay
        options:kFadeOptions
        animations:^{
          /** @ghidraAddress 0x1418c0 */
          weakRankingListView.alpha = 0.0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x14190c */
          [UIView animateWithDuration:kFadeDuration
                                delay:kFadeDelay
                              options:kFadeOptions
                           animations:^{
                             /** @ghidraAddress 0x1419c0 */
                             weakLineupListView.alpha = 1.0;
                           }
                           completion:nil];
        }];
}

/** @ghidraAddress 0x141a24 */
- (void)selectListButton:(id)sender {
    // Empty in the binary.
}

/** @ghidraAddress 0x141a28 */
- (void)closeList:(id)sender {
    if ([self.aDelegate respondsToSelector:@selector(closeMenu)]) {
        [self.aDelegate performSelector:@selector(closeMenu)];
    }
}

#pragma mark - DownloaderDelegate

/** @ghidraAddress 0x141ad8 */
- (void)downloaderFinished:(id)downloader {
    NSDictionary *json = [downloader getDataInJSON];
    int status = kStatusNone;
    if (json[kResponseStatusKey]) {
        status = [json[kResponseStatusKey] intValue];
    }
    NSString *errMessage = nil;
    if (json[kResponseErrorMessageKey]) {
        errMessage = json[kResponseErrorMessageKey];
    }

    if (status == kStatusServerError) {
        NSString *msg = [NSBundle.mainBundle localizedStringForKey:@"ServerErrorMsg"
                                                             value:@""
                                                             table:nil];
        if (json[kResponseErrorMessageKey]) {
            msg = json[kResponseErrorMessageKey];
        }
        NSString *ok = [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil];
        [[AlertViewManager sharedManager] makeAlert:kPlainAlertType
                                           delegate:self
                                                tag:kServerErrorAlertTag
                                              title:@""
                                                msg:msg
                                             cancel:ok
                                            btnText:nil
                                               show:YES];
        return;
    }
    if (status == kStatusUpdateRequired) {
        [[AlertViewManager sharedManager] showUpdateAlert];
        return;
    }

    int tag = [downloader tag];
    if (tag == kTagArtwork) {
        [self storeArtworkFromDownloader:downloader];
    } else if (tag == kTagListLoad) {
        [self handleListLoadResponse:json status:status errMessage:errMessage];
    }
}

// Writes the finished artwork to its cache path, drops the task, and either fetches the next task
// or reveals the line-up list once the queue empties.
- (void)storeArtworkFromDownloader:(id)downloader {
    NSData *data = [downloader getData];
    NSString *path =
        [ScratchUtil imagePathForMusicID:[currentDownload[kRecordMusicIDKey] intValue]];
    NSURL *url = [[NSURL alloc] initFileURLWithPath:path isDirectory:NO];
    [data writeToURL:url atomically:YES];
    ExcludeUrlFromICloudBackup(url);
    [imageDLTasks removeObject:currentDownload];
    if (imageDLTasks.count == 0) {
        imageDLTasks = nil;
        [self showLineupList];
    } else {
        [self imageDownload];
    }
}

// Prepends the "all tunes" head row to the line-up, records the scratch identifier, and either
// reveals the list or begins downloading the missing artwork.
- (void)handleListLoadResponse:(NSDictionary *)json
                        status:(int)status
                    errMessage:(NSString *)errMessage {
    if (status == kStatusOK) {
        NSMutableArray *list = [json[kResponseMusicListKey] mutableCopy];
        NSDictionary *head =
            [NSDictionary dictionaryWithObjects:@[ @(kAllTunesMusicID), kAllTunesRowTitle ]
                                        forKeys:@[ kRecordMusicIDKey, kRecordNameKey ]];
        [list insertObject:head atIndex:0];
        lineupList = [NSArray arrayWithArray:list];
        scratchID = [json[kResponseScratchIDKey] intValue];
        if ([self checkArtworkDownload]) {
            [self showLineupList];
        } else {
            [self imageDownload];
        }
        return;
    }

    NSString *msg = errMessage;
    if (!msg) {
        msg = kListLoadFailedMessage;
    }
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil];
    [[AlertViewManager sharedManager] makeAlert:kPlainAlertType
                                       delegate:self
                                            tag:kListLoadErrorAlertTag
                                          title:@""
                                            msg:msg
                                         cancel:ok
                                        btnText:nil
                                           show:YES];
}

/** @ghidraAddress 0x14218c */
- (void)downloaderError:(id)downloader {
    NSString *msg = [NSBundle.mainBundle localizedStringForKey:@"ServerErrorMsg"
                                                         value:@""
                                                         table:nil];
    (void)[downloader tag]; // Read but unused, as in the binary.
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil];
    [[AlertViewManager sharedManager] makeAlert:kPlainAlertType
                                       delegate:nil
                                            tag:kDownloaderErrorAlertTag
                                          title:@""
                                            msg:msg
                                         cancel:ok
                                        btnText:nil
                                           show:YES];
}

#pragma mark - AlertViewManagerDelegate

/** @ghidraAddress 0x1422fc */
- (void)alertSelect:(NSDictionary *)info {
    int button = [info[kAlertInfoButtonMessageKey] intValue];
    int tag = [info[kAlertInfoTagKey] intValue];
    if (tag == kListLoadErrorAlertTag) {
        if ([self.aDelegate respondsToSelector:@selector(closeMenu)]) {
            [self.aDelegate performSelector:@selector(closeMenu)];
        }
        return;
    }
    if (tag == kArtworkErrorAlertTag) {
        // The cancel button closes the whole menu; either way the queue is advanced.
        if (button == 0 && [self.aDelegate respondsToSelector:@selector(closeMenu)]) {
            [self.aDelegate performSelector:@selector(closeMenu)];
        }
        if (imageDLTasks.count == 0) {
            imageDLTasks = nil;
            [self showLineupList];
        } else {
            [self imageDownload];
        }
        return;
    }
    if (tag == kServerErrorAlertTag) {
        [[[ChallengeStatus sharedStatus] rootView] closeChallengeModeSessionError];
    }
}

#pragma mark - Artwork download

/** @ghidraAddress 0x142590 */
- (BOOL)checkArtworkDownload {
    NSMutableArray *missing = [[NSMutableArray alloc] init];
    for (NSUInteger i = 0; i < lineupList.count; ++i) {
        NSDictionary *record = lineupList[i];
        NSString *path = [ScratchUtil imagePathForMusicID:[record[kRecordMusicIDKey] intValue]];
        if (![UIImage imageWithContentsOfFile:path]) {
            [missing addObject:record];
        }
    }
    if (missing.count != 0) {
        imageDLTasks = [NSMutableArray arrayWithArray:missing];
    }
    return missing.count == 0; // YES when every tune's artwork is already cached.
}

/** @ghidraAddress 0x142794 */
- (void)imageDownload {
    if (imageDLTasks == nil || imageDLTasks.count == 0) {
        return;
    }
    NSDictionary *task = imageDLTasks[0];
    NSURL *url = [NSURL URLWithString:task[kTaskImageURLKey]];
    Downloader *downloader = [[Downloader alloc] initWithURL:url delegate:self];
    downloader.tag = kTagArtwork;
    [downloader startDownloading];
    currentDownload = task;
}

#pragma mark - Line-up presentation

/** @ghidraAddress 0x1428c4 */
- (void)showLineupList {
    lineupListView = [[ChallengePrevRankingListView alloc] initWithFrame:self.frame
                                                                  lineup:lineupList];
    lineupListView.aDelegate = self;
    [self addSubview:lineupListView];
    [lineupListView showLineup];
}

/** @ghidraAddress 0x142970 */
- (void)closeLineupView {
    [lineupListView removeFromSuperview];
    lineupListView = nil;
    if ([self.aDelegate respondsToSelector:@selector(closeMenu)]) {
        [self.aDelegate performSelector:@selector(closeMenu)];
    }
}

@end
