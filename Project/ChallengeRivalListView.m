#import "ChallengeRivalListView.h"

#import "AlertViewManager.h"
#import "ChallengeListView.h"
#import "ChallengeModeRootView.h"
#import "ChallengeStatus.h"
#import "Downloader.h"
#import "EditorIDManager.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"
#import "ScratchUtil.h"
#import "SessionDownloader.h"

// The challenge root view messaged when a session-error alert is dismissed. Not reconstructed yet.
// See TYPES_PENDING.md.
@protocol ChallengeRootView <NSObject>
- (void)closeChallengeModeSessionError;
@end
// The rival-list request's post-body keys and values.
static NSString *const kPostUserIDKey = @"user_id";
static NSString *const kPostTargetKey = @"target";
static NSString *const kTargetJP = @"JP";

// The remove-rival request's post-body keys.
static NSString *const kPostRivalIDKey = @"rival_id";
static NSString *const kPostIsAddKey = @"is_add";

// The response keys.
static NSString *const kResponseStatusKey = @"status";
static NSString *const kResponseErrorMessageKey = @"err_message";
static NSString *const kRivalArrayKey = @"rival";

// The alert-info keys.
static NSString *const kAlertInfoTagKey = @"Tag";
static NSString *const kAlertInfoButtonMessageKey = @"btnMessage";

// The remove-confirmation prompt format, and the yes/no button titles.
static NSString *const kRemovePromptFormat = @"ライバルリストから%@さんの登録を解除しますか？";
static NSString *const kYesButtonTitle = @"はい";
static NSString *const kNoButtonTitle = @"いいえ";

// The rival-list title art.
static NSString *const kTitleImageName = @"scratch_list_title_rival";

// The default alert messages when the server supplies none.
static NSString *const kRemovedMessage = @"解除しました";
static NSString *const kRemoveFailedMessage = @"解除できませんでした";

// The download tags distinguishing the list load from a remove.
static const int kTagListLoad = 1;
static const int kTagRemove = 2;

// The API tags for the two request kinds.
static const int kApiTagListLoad = 0xc;
static const int kApiTagRemove = 0xd;

// The server status codes handled specially.
static const int kStatusOK = 0;
static const int kStatusServerError = 0x18b53;
static const int kStatusUpdateRequired = 0x186ab;

// The alert tags used to route the delegate calls.
static const int kSessionErrorAlertTag = 9999;
static const int kRemoveConfirmTag = 6;

// The list's y position inside its frame, per idiom: one value for the successful load, a larger
// one for the empty/error load.
static const int kListPosYPad = 0x32;
static const int kListPosYPhone = 0x19;
static const int kListPosYErrorPad = 0x3c;
static const int kListPosYErrorPhone = 0x1e;

@interface ChallengeRivalListView () <AlertViewManagerDelegate, DownloaderDelegate> {
@public
    ChallengeListView *rivalListView; // +0x8
    NSArray *rivalNameList;           // +0x10
    NSArray *rivalIDList;             // +0x18
    int selectRivalIndex;             // +0x20
    CGRect listRect;                  // +0x28
}
@end

// Presents the shared alert with an empty title and a localised OK button.
static inline void ChallengeRivalListViewShowPlainAlert(
    ChallengeRivalListView *__attribute__((unused)) self, id delegate, int tag, NSString *msg) {
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

// Builds the rival table over the modal's frame at the given list y position and seeds it with the
// current names.
static inline void ChallengeRivalListViewBuildListView(ChallengeRivalListView *self, int listPosY) {
    self->rivalListView = [[ChallengeListView alloc] initWithFrame:self.frame listPosY:listPosY];
    [self->rivalListView setADelegate:self];
    [self->rivalListView setTitleImage:LoadScaledPngImage(kTitleImageName) animation:NO];
    [self->rivalListView setListArray:self->rivalNameList];
    [self addSubview:self->rivalListView];
}

// The remove response: on success confirm and drop the removed name/id pair; otherwise show the
// failure.
static inline void ChallengeRivalListViewHandleRemoveResponse(ChallengeRivalListView *self,
                                                              NSDictionary *json,
                                                              int status) {
    if (status == kStatusOK) {
        NSString *ok = [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil];
        [[AlertViewManager sharedManager] makeAlert:0
                                           delegate:nil
                                                tag:3
                                              title:@""
                                                msg:kRemovedMessage
                                             cancel:ok
                                            btnText:nil
                                               show:YES];
        NSMutableArray *names = [NSMutableArray arrayWithArray:self->rivalNameList];
        NSMutableArray *ids = [NSMutableArray arrayWithArray:self->rivalIDList];
        [names removeObjectAtIndex:self->selectRivalIndex];
        [ids removeObjectAtIndex:self->selectRivalIndex];
        self->rivalNameList = [NSArray arrayWithArray:names];
        self->rivalIDList = [NSArray arrayWithArray:ids];
        [self->rivalListView setListArray:self->rivalNameList];
        return;
    }

    NSString *msg = json[kResponseErrorMessageKey];
    if (!msg) {
        msg = kRemoveFailedMessage;
    }
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:nil
                                            tag:0
                                          title:@""
                                            msg:msg
                                         cancel:kYesButtonTitle
                                        btnText:nil
                                           show:YES];
}

// The list-load response: split each rival record into parallel name and id arrays and build the
// table; on failure show the error and still build an empty table lower down.
static inline void ChallengeRivalListViewHandleListLoadResponse(ChallengeRivalListView *self,
                                                                NSDictionary *json,
                                                                int status,
                                                                BOOL isPad) {
    if (status == kStatusOK) {
        NSArray *rivals = [NSArray arrayWithArray:json[kRivalArrayKey]];
        NSMutableArray *ids = [[NSMutableArray alloc] init];
        NSMutableArray *names = [[NSMutableArray alloc] init];
        for (NSUInteger i = 0; i < rivals.count; ++i) {
            [names addObject:rivals[i][0]];
            [ids addObject:rivals[i][1]];
        }
        self->rivalNameList = [NSArray arrayWithArray:names];
        self->rivalIDList = [NSArray arrayWithArray:ids];
        ChallengeRivalListViewBuildListView(self, isPad ? kListPosYPad : kListPosYPhone);
        return;
    }

    NSString *msg = json[kResponseErrorMessageKey];
    if (!msg) {
        msg = [NSBundle.mainBundle localizedStringForKey:@"ServerErrorMsg" value:@"" table:nil];
    }
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:nil
                                            tag:0
                                          title:@""
                                            msg:msg
                                         cancel:kYesButtonTitle
                                        btnText:nil
                                           show:YES];
    // The failure still builds a list view with no names, sitting lower on the screen.
    self->rivalListView =
        [[ChallengeListView alloc] initWithFrame:self.frame
                                        listPosY:isPad ? kListPosYErrorPad : kListPosYErrorPhone];
    [self->rivalListView setADelegate:self];
    [self->rivalListView setTitleImage:LoadScaledPngImage(kTitleImageName) animation:NO];
    [self addSubview:self->rivalListView];
}

@implementation ChallengeRivalListView

@synthesize aDelegate = _aDelegate;

#pragma mark - Construction

/** @ghidraAddress 0xd9ec4 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) {
        return self;
    }
    // Request the rival list for the current editor id.
    NSString *editorID = [EditorIDManager getKeyString:[EditorIDManager getEditorIDKey]];
    NSDictionary *post =
        [NSMutableDictionary dictionaryWithObjects:@[ editorID, kTargetJP ]
                                           forKeys:@[ kPostUserIDKey, kPostTargetKey ]];
    SessionDownloader *downloader =
        [[SessionDownloader alloc] initWithURL:[ScratchUtil rivalListURL]
                                postDictionary:post
                                      delegate:self];
    downloader.tag = kTagListLoad;
    downloader.apiTag = kApiTagListLoad;
    [downloader startDownloading];
    return self;
}

#pragma mark - Actions

/** @ghidraAddress 0xda0f8 */
- (void)selectListCell:(NSIndexPath *)indexPath {
    selectRivalIndex = (int)indexPath.row;
    NSString *name = rivalNameList[selectRivalIndex];
    NSString *msg = [NSString stringWithFormat:kRemovePromptFormat, name];
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:self
                                            tag:kRemoveConfirmTag
                                          title:@""
                                            msg:msg
                                         cancel:kNoButtonTitle
                                        btnText:@[ kYesButtonTitle ]
                                           show:YES];
}

/** @ghidraAddress 0xda27c */
- (void)selectListButton:(id)sender {
    // Empty in the binary.
}

/** @ghidraAddress 0xda280 */
- (void)closeList:(id)sender {
    // Empty in the binary.
}

/** @ghidraAddress 0xdb0cc */
- (void)tapClose:(id)sender {
    if ([self.aDelegate respondsToSelector:@selector(closeMenu)]) {
        [self.aDelegate performSelector:@selector(closeMenu)];
    }
}

#pragma mark - DownloaderDelegate

/** @ghidraAddress 0xda284 */
- (void)downloaderFinished:(id)downloader {
    BOOL isPad = [JubeatAppDelegate appDelegate].isPad;
    NSDictionary *json = [downloader getDataInJSON];
    int status = -1;
    if (json[kResponseStatusKey]) {
        status = [json[kResponseStatusKey] intValue];
        if (status == kStatusServerError) {
            NSString *msg = json[kResponseErrorMessageKey];
            if (!msg) {
                msg = [NSBundle.mainBundle localizedStringForKey:@"ServerErrorMsg"
                                                           value:@""
                                                           table:nil];
            }
            ChallengeRivalListViewShowPlainAlert(self, self, kSessionErrorAlertTag, msg);
            return;
        }
        if (status == kStatusUpdateRequired) {
            [[AlertViewManager sharedManager] showUpdateAlert];
            return;
        }
    }

    int tag = (int)[(Downloader *)downloader tag];
    if (tag == kTagRemove) {
        ChallengeRivalListViewHandleRemoveResponse(self, json, status);
    } else if (tag == kTagListLoad) {
        ChallengeRivalListViewHandleListLoadResponse(self, json, status, isPad);
    }
}

/** @ghidraAddress 0xdac68 */
- (void)downloaderError:(id)downloader {
    NSString *msg = [NSBundle.mainBundle localizedStringForKey:@"ServerErrorMsg"
                                                         value:@""
                                                         table:nil];
    (void)[(Downloader *)downloader tag]; // Read but unused, as in the binary.
    ChallengeRivalListViewShowPlainAlert(self, nil, 3, msg);
}

#pragma mark - AlertViewManagerDelegate

/** @ghidraAddress 0xdadd8 */
- (void)alertSelect:(NSDictionary *)info {
    int button = [info[kAlertInfoButtonMessageKey] intValue];
    int tag = [info[kAlertInfoTagKey] intValue];
    if (tag == kSessionErrorAlertTag) {
        [[[ChallengeStatus sharedStatus] rootView] closeChallengeModeSessionError];
        return;
    }
    if (button == 1 && tag == kRemoveConfirmTag) {
        NSString *rivalID = rivalIDList[selectRivalIndex];
        NSDictionary *post =
            [NSDictionary dictionaryWithObjects:@[ rivalID, @NO ]
                                        forKeys:@[ kPostRivalIDKey, kPostIsAddKey ]];
        SessionDownloader *downloader =
            [[SessionDownloader alloc] initWithURL:[ScratchUtil removeRivalURL]
                                    postDictionary:post
                                          delegate:self];
        downloader.tag = kTagRemove;
        downloader.apiTag = kApiTagRemove;
        [downloader startDownloading];
    }
}

@end
