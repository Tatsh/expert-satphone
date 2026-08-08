#import "ChallengePresentView.h"

#import "AlertViewManager.h"
#import "ChallengeStatus.h"
#import "Downloader.h"
#import "EditorIDManager.h"
#import "ScratchUtil.h"
#import "SessionDownloader.h"

// The present-list table view this modal hosts. Not reconstructed as its own file yet, so it is
// reached through a forward declaration here. Its selectors are noted in TYPES_PENDING.md.
@class ChallengePresentView;

@interface ChallengePresentListView : UIView
- (instancetype)initWithFrame:(CGRect)frame;
- (void)setListArray:(nullable NSArray *)listArray;
- (void)setADelegate:(nullable id)delegate;
@end

// The challenge root view messaged when a session-error alert is dismissed, and the extra
// ChallengeStatus methods this modal reads and updates. Not reconstructed yet. See
// TYPES_PENDING.md.
@protocol ChallengeRootView <NSObject>
- (void)closeChallengeModeSessionError;
@end

@interface ChallengeStatus (Present)
- (void)receivePresent:(nullable NSDictionary *)json;
- (void)setPresentNum:(int)num;
- (nullable id<ChallengeRootView>)rootView;
@end

// The present-list request's post-body keys and values.
static NSString *const kPostUserIDKey = @"user_id";
static NSString *const kPostTargetKey = @"target";
static NSString *const kTargetJP = @"JP";

// The accept/decline request's post-body keys.
static NSString *const kPostPresentIDKey = @"present_id";
static NSString *const kPostAgreeKey = @"agree";

// The present-record keys read from the response.
static NSString *const kPresentIDKey = @"present_id";
static NSString *const kPresentNameKey = @"name";
static NSString *const kPresentArrayKey = @"present";

// The response keys.
static NSString *const kResponseStatusKey = @"status";
static NSString *const kResponseErrorMessageKey = @"err_message";
static NSString *const kResponseMessageKey = @"message";

// The alert-info keys.
static NSString *const kAlertInfoTagKey = @"Tag";
static NSString *const kAlertInfoButtonMessageKey = @"btnMessage";

// The confirmation-prompt format, and the yes/no button titles.
static NSString *const kReceivePromptFormat = @"%@を受け取りますか？";
static NSString *const kYesButtonTitle = @"はい";
static NSString *const kNoButtonTitle = @"いいえ";

// The default alert messages when the server supplies none.
static NSString *const kListFetchFailedMessage = @"プレゼントリストの取得に失敗しました";
static NSString *const kReceivedMessage = @"プレゼントを受け取りました";
static NSString *const kCoinOverflowPromptMessage =
    @"コインが上限を超えてしまいますが受け取りますか？";
static NSString *const kCoinLimitReachedMessage = @"コインが上限に達しています";
static NSString *const kReceiveFailedMessage = @"プレゼントを受け取れませんでした";

// The download tags distinguishing the list load from an accept/decline.
static const int kTagListLoad = 1;
static const int kTagAcceptDecline = 2;

// The API tags for the two request kinds.
static const int kApiTagListLoad = 0x10;
static const int kApiTagAcceptDecline = 0x11;

// The server status codes handled specially.
static const int kStatusOK = 0;
static const int kStatusServerError = 0x18b53;
static const int kStatusUpdateRequired = 0x186ab;
static const int kStatusCoinOverflow = 0x3195e;
static const int kStatusCoinLimit = 0x32518;

// The alert tags used to route the delegate calls.
static const int kSessionErrorAlertTag = 9999;
static const int kAcceptConfirmTag = 7;
static const int kCoinOverflowConfirmTag = 4;

@interface ChallengePresentView () <AlertViewManagerDelegate, DownloaderDelegate>
@end

@implementation ChallengePresentView {
    ChallengePresentListView *presentListView; // +0x8
    NSArray *presentList;                      // +0x10
    int selectPresentIndex;                    // +0x18
    UIImageView *titleView;                    // +0x20
    UILabel *titleLabel;                       // +0x28
    CGRect listRect;                           // +0x30
}

@synthesize aDelegate = _aDelegate;

#pragma mark - Construction

/** @ghidraAddress 0x9516c */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) {
        return self;
    }
    // Request the present list for the current editor id.
    NSString *editorID = [EditorIDManager getKeyString:[EditorIDManager getEditorIDKey]];
    NSDictionary *post =
        [NSMutableDictionary dictionaryWithObjects:@[ editorID, kTargetJP ]
                                           forKeys:@[ kPostUserIDKey, kPostTargetKey ]];
    SessionDownloader *downloader =
        [[SessionDownloader alloc] initWithURL:[ScratchUtil presentListURL]
                                postDictionary:post
                                      delegate:self];
    downloader.tag = kTagListLoad;
    downloader.apiTag = kApiTagListLoad;
    [downloader startDownloading];
    return self;
}

#pragma mark - Actions

/** @ghidraAddress 0x953a0 */
- (void)tapClose:(id)sender {
    if ([self.aDelegate respondsToSelector:@selector(closeMenu)]) {
        [self.aDelegate performSelector:@selector(closeMenu)];
    }
}

/** @ghidraAddress 0x95450 */
- (void)selectListCell:(NSIndexPath *)indexPath {
    selectPresentIndex = (int)indexPath.row;
    NSString *name = presentList[selectPresentIndex][kPresentNameKey];
    NSString *msg = [NSString stringWithFormat:kReceivePromptFormat, name];
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:self
                                            tag:kAcceptConfirmTag
                                          title:@""
                                            msg:msg
                                         cancel:kNoButtonTitle
                                        btnText:@[ kYesButtonTitle ]
                                           show:YES];
}

/** @ghidraAddress 0x955fc */
- (void)selectListButton:(id)sender {
    // Empty in the binary.
}

/** @ghidraAddress 0x95600 */
- (void)closeList:(id)sender {
    // Empty in the binary.
}

#pragma mark - DownloaderDelegate

// Presents the shared alert with an empty title and a localised OK button.
- (void)showPlainAlertWithDelegate:(nullable id)delegate tag:(int)tag message:(NSString *)msg {
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil];
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:delegate
                                            tag:tag
                                          title:@""
                                            msg:msg
                                         cancel:ok
                                        btnText:nil
                                           show:YES];
}

/** @ghidraAddress 0x95604 */
- (void)downloaderFinished:(id)downloader {
    NSDictionary *json = [downloader getDataInJSON];
    int status = -1;
    if (json[kResponseStatusKey]) {
        status = [json[kResponseStatusKey] intValue];
        if (status == kStatusServerError) {
            // A server error routes its dismissal to the session-error handler.
            NSString *msg = json[kResponseErrorMessageKey];
            if (!msg) {
                msg = [NSBundle.mainBundle localizedStringForKey:@"ServerErrorMsg"
                                                           value:@""
                                                           table:nil];
            }
            [self showPlainAlertWithDelegate:self tag:kSessionErrorAlertTag message:msg];
            return;
        }
        if (status == kStatusUpdateRequired) {
            [[AlertViewManager sharedManager] showUpdateAlert];
            if ([self.aDelegate respondsToSelector:@selector(closeMenu)]) {
                [self.aDelegate performSelector:@selector(closeMenu)];
            }
            return;
        }
    }

    int tag = [downloader tag];
    if (tag == kTagAcceptDecline) {
        [self handleAcceptDeclineResponse:json status:status];
    } else if (tag == kTagListLoad) {
        [self handleListLoadResponse:json status:status];
    }
}

// The accept/decline response: on success show the message, record the present, refresh the
// delegate, and drop the accepted row; otherwise show the coin-overflow prompt, the coin-limit
// alert, or a generic failure.
- (void)handleAcceptDeclineResponse:(NSDictionary *)json status:(int)status {
    NSString *msg = json[kResponseMessageKey];
    if (status == kStatusOK) {
        if (!msg) {
            msg = kReceivedMessage;
        }
        [self showPlainAlertWithDelegate:nil tag:3 message:msg];
        [[ChallengeStatus sharedStatus] receivePresent:json];
        if ([self.aDelegate respondsToSelector:@selector(refreshStatus)]) {
            [self.aDelegate performSelector:@selector(refreshStatus)];
        }
        NSMutableArray *remaining = [NSMutableArray arrayWithArray:presentList];
        [remaining removeObjectAtIndex:selectPresentIndex];
        presentList = [NSArray arrayWithArray:remaining];
        [presentListView setListArray:presentList];
        [[ChallengeStatus sharedStatus] setPresentNum:(int)presentList.count];
        return;
    }

    if (!msg) {
        msg = json[kResponseErrorMessageKey];
    }
    if (status == kStatusCoinOverflow) {
        // Ask again, allowing an override that resends with agree = YES.
        if (!msg) {
            msg = kCoinOverflowPromptMessage;
        }
        [[AlertViewManager sharedManager] makeAlert:0
                                           delegate:self
                                                tag:kCoinOverflowConfirmTag
                                              title:@""
                                                msg:msg
                                             cancel:kNoButtonTitle
                                            btnText:@[ kYesButtonTitle ]
                                               show:YES];
        return;
    }
    if (status == kStatusCoinLimit) {
        if (!msg) {
            msg = kCoinLimitReachedMessage;
        }
        [self showPlainAlertWithDelegate:nil tag:3 message:msg];
        return;
    }
    if (!msg) {
        msg = kReceiveFailedMessage;
    }
    [self showPlainAlertWithDelegate:nil tag:0 message:msg];
}

// The list-load response: on success build the table view over the modal's frame and seed it with
// the presents; otherwise show the failure and close.
- (void)handleListLoadResponse:(NSDictionary *)json status:(int)status {
    if (status == kStatusOK) {
        presentList = [NSArray arrayWithArray:json[kPresentArrayKey]];
        presentListView = [[ChallengePresentListView alloc] initWithFrame:self.frame];
        [presentListView setADelegate:self];
        [presentListView setListArray:presentList];
        [self addSubview:presentListView];
        [[ChallengeStatus sharedStatus] setPresentNum:(int)presentList.count];
        return;
    }

    NSString *msg = json[kResponseErrorMessageKey];
    if (!msg) {
        msg = kListFetchFailedMessage;
    }
    [self showPlainAlertWithDelegate:nil tag:0 message:msg];
    if ([self.aDelegate respondsToSelector:@selector(closeMenu)]) {
        [self.aDelegate performSelector:@selector(closeMenu)];
    }
}

/** @ghidraAddress 0x96090 */
- (void)downloaderError:(id)downloader {
    NSString *msg = [NSBundle.mainBundle localizedStringForKey:@"ServerErrorMsg"
                                                         value:@""
                                                         table:nil];
    (void)[downloader tag]; // Read but unused, as in the binary.
    [self showPlainAlertWithDelegate:nil tag:3 message:msg];
}

#pragma mark - AlertViewManagerDelegate

/** @ghidraAddress 0x96200 */
- (void)alertSelect:(NSDictionary *)info {
    int button = [info[kAlertInfoButtonMessageKey] intValue];
    int tag = [info[kAlertInfoTagKey] intValue];
    if (tag == kSessionErrorAlertTag) {
        [[[ChallengeStatus sharedStatus] rootView] closeChallengeModeSessionError];
        return;
    }
    if (button != 1) {
        return;
    }
    // The accept-confirm (agree = YES) and coin-overflow-override (agree = NO) both resend the
    // accept request for the selected present.
    BOOL agree;
    if (tag == kAcceptConfirmTag) {
        agree = YES;
    } else if (tag == kCoinOverflowConfirmTag) {
        agree = NO;
    } else {
        return;
    }
    NSString *presentID = presentList[selectPresentIndex][kPresentIDKey];
    NSDictionary *post = [NSDictionary dictionaryWithObjects:@[ presentID, @(agree) ]
                                                     forKeys:@[ kPostPresentIDKey, kPostAgreeKey ]];
    SessionDownloader *downloader =
        [[SessionDownloader alloc] initWithURL:[ScratchUtil getPresentURL]
                                postDictionary:post
                                      delegate:self];
    downloader.tag = kTagAcceptDecline;
    downloader.apiTag = kApiTagAcceptDecline;
    [downloader startDownloading];
}

@end
