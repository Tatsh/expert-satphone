#import "ChallengePresentView.h"

#import "AlertViewManager.h"
#import "ChallengeModeRootView.h"
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

@interface ChallengePresentView () <AlertViewManagerDelegate, DownloaderDelegate> {
@public
    ChallengePresentListView *presentListView; // +0x8
    NSArray *presentList;                      // +0x10
    int selectPresentIndex;                    // +0x18
    UIImageView *titleView;                    // +0x20
    UILabel *titleLabel;                       // +0x28
    CGRect listRect;                           // +0x30
}
@end

// Presents the shared alert with an empty title and a localised OK button.
static inline void ChallengePresentViewShowPlainAlert(ChallengePresentView *self,
                                                      id delegate,
                                                      int tag,
                                                      NSString *msg) {
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

// The accept/decline response: on success show the message, record the present, refresh the
// delegate, and drop the accepted row; otherwise show the coin-overflow prompt, the coin-limit
// alert, or a generic failure.
static inline void ChallengePresentViewHandleAcceptDeclineResponse(ChallengePresentView *self,
                                                                   NSDictionary *json,
                                                                   int status) {
    NSString *msg = json[kResponseMessageKey];
    if (status == kStatusOK) {
        if (!msg) {
            msg = kReceivedMessage;
        }
        ChallengePresentViewShowPlainAlert(self, nil, 3, msg);
        [[ChallengeStatus sharedStatus] receivePresent:json];
        if ([self.aDelegate respondsToSelector:@selector(refreshStatus)]) {
            [self.aDelegate performSelector:@selector(refreshStatus)];
        }
        NSMutableArray *remaining = [NSMutableArray arrayWithArray:self->presentList];
        [remaining removeObjectAtIndex:self->selectPresentIndex];
        self->presentList = [NSArray arrayWithArray:remaining];
        [self->presentListView setListArray:self->presentList];
        [[ChallengeStatus sharedStatus] setPresentNum:(int)self->presentList.count];
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
        ChallengePresentViewShowPlainAlert(self, nil, 3, msg);
        return;
    }
    if (!msg) {
        msg = kReceiveFailedMessage;
    }
    ChallengePresentViewShowPlainAlert(self, nil, 0, msg);
}

// The list-load response: on success build the table view over the modal's frame and seed it with
// the presents; otherwise show the failure and close.
static inline void ChallengePresentViewHandleListLoadResponse(ChallengePresentView *self,
                                                              NSDictionary *json,
                                                              int status) {
    if (status == kStatusOK) {
        self->presentList = [NSArray arrayWithArray:json[kPresentArrayKey]];
        self->presentListView = [[ChallengePresentListView alloc] initWithFrame:self.frame];
        [self->presentListView setADelegate:self];
        [self->presentListView setListArray:self->presentList];
        [self addSubview:self->presentListView];
        [[ChallengeStatus sharedStatus] setPresentNum:(int)self->presentList.count];
        return;
    }

    NSString *msg = json[kResponseErrorMessageKey];
    if (!msg) {
        msg = kListFetchFailedMessage;
    }
    ChallengePresentViewShowPlainAlert(self, nil, 0, msg);
    if ([self.aDelegate respondsToSelector:@selector(closeMenu)]) {
        [self.aDelegate performSelector:@selector(closeMenu)];
    }
}

@implementation ChallengePresentView

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
            ChallengePresentViewShowPlainAlert(self, self, kSessionErrorAlertTag, msg);
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

    int tag = (int)[downloader tag];
    if (tag == kTagAcceptDecline) {
        ChallengePresentViewHandleAcceptDeclineResponse(self, json, status);
    } else if (tag == kTagListLoad) {
        ChallengePresentViewHandleListLoadResponse(self, json, status);
    }
}

/** @ghidraAddress 0x96090 */
- (void)downloaderError:(id)downloader {
    NSString *msg = [NSBundle.mainBundle localizedStringForKey:@"ServerErrorMsg"
                                                         value:@""
                                                         table:nil];
    (void)[downloader tag]; // Read but unused, as in the binary.
    ChallengePresentViewShowPlainAlert(self, nil, 3, msg);
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
