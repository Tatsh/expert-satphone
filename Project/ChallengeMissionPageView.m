#import "ChallengeMissionPageView.h"

#import "AlertViewManager.h"
#import "AudioManager.h"
#import "ChallengeMissionFileManager.h"
#import "ChallengeMissionListCell.h"
#import "ChallengeMissionReward.h"
#import "ChallengeMissionSheet.h"
#import "ChallengeRewardListCell.h"
#import "ChallengeStatus.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"
#import "ScratchUtil.h"

// The download indices carried by the SessionDownloader tag and the two list buttons.
typedef enum {
    ChallengeMissionListKindMission = 0, // The mission-sheet list.
    ChallengeMissionListKindReward = 1,  // The rewards list.
} ChallengeMissionListKind;

// The sheet-list and reward-list response JSON keys, verbatim from the binary.
static NSString *const kStatusKey = @"status";          // @ghidraAddress 0x2d5000
static NSString *const kErrMessageKey = @"err_message"; // @ghidraAddress 0x2d5040
static NSString *const kSheetListKey = @"sheet_list";   // @ghidraAddress 0x2d9be0
static NSString *const kSheetIDKey = @"sheet_id";       // @ghidraAddress 0x2d9c00
static NSString *const kRewardListKey = @"reward_list"; // @ghidraAddress 0x2d9c20
static NSString *const kRewardKey = @"reward";          // @ghidraAddress 0x2d9c40
static NSString *const kTagKey = @"Tag";                // @ghidraAddress 0x2d5160

// The cell reuse identifiers, verbatim from the binary.
static NSString *const kMissionSheetListCellID = @"MissionSheetListCell"; // @ghidraAddress 0x2d9c60
static NSString *const kRewardListCellID = @"RewardListCell";             // @ghidraAddress 0x2d9ca0

// The base names of the per-state artwork; the format's %02d is filled with the list index.
static NSString *const kSheetButtonImageFormat =
    @"cm_list_btn_sheet_%02d"; // @ghidraAddress 0x2d9b00
static NSString *const kRewardButtonImageFormat =
    @"cm_list_btn_fix_%02d";                                            // @ghidraAddress 0x2d9b20
static NSString *const kListBadgeImageFormat = @"cm_list_mark_%02d";    // @ghidraAddress 0x2d9b40
static NSString *const kListNewIconImageName = @"cm_list_new";          // @ghidraAddress 0x2d9b60
static NSString *const kListBackgroundImageFormat = @"cm_list_bg_%02d"; // @ghidraAddress 0x2d9b80
static NSString *const kPlateImageName = @"challenge_menu_bg";          // @ghidraAddress 0x2d6440
static NSString *const kTitleImageName = @"cm_list_title";              // @ghidraAddress 0x2d9ae0
static NSString *const kCloseButtonImageName = @"scratch_btn_back";     // @ghidraAddress 0x2d7f60

// The period line shown under an event sheet's title. @ghidraAddress 0x2d9c80
static NSString *const kPeriodFormat = @"%@年%@月%@日 %@まで";

// The empty-state labels for the two lists (mission and reward).
static NSString *const kNoMissionText =
    @"表示できるミッションがありません";                              // @ghidraAddress 0x2c0e6a
static NSString *const kNoRewardText = @"表示できる報酬がありません"; // @ghidraAddress 0x2c0e8c

// The challenge-scratch not-open message. @ghidraAddress 0x2d5d40
static NSString *const kNoScratchText = @"現在開催されているチャレンジスクラッチは存在しません";

// The localised-string keys and the cancel sound.
static NSString *const kServerErrorMsgKey = @"ServerErrorMsg";
static NSString *const kOKKey = @"OK";
static NSString *const kCancelSE = @"SD_CHALLENGE_CANCEL"; // @ghidraAddress 0x2d9cc0

enum {
    // The server error codes handled by -challengeConnectError:.
    kErrorCodeUpdateRequired = 0x186ab,
    kErrorCodeServer = 0x18b53,
    kErrorCodeNoScratch = 0x3212f,
    // The alert tags echoed back through -alertSelect: and -cancelSettingMenu:.
    kSessionErrorAlertTag = 9999,
    // The event-sheet period substring "YYYY-MM-DDThh:mm"; anything shorter has no period.
    kMinimumPeriodLength = 0x11,
    // The empty-state font size, and the pad/phone title top offsets.
    kEmptyLabelFontSize = 24.0,
};

// The animation duration read from the __const pool at 0x28e040; options 0x30000 is
// UIViewAnimationOptionCurveLinear.
static const NSTimeInterval kMissionPageAnimationDuration = 0.2; // @ghidraAddress 0x28e040

@implementation ChallengeMissionPageView {
    UIImageView *titleImageView;
    UIButton *closeBtn;
    UIImage *rewardBtnImage[2];
    UIImage *sheetBtnImage[2];
    UIImage *listBgImage[2];
    UIImage *listBagdeImage[2];
    UIImage *listNewIconImage;
    UIImageView *listBgView;
    UIView *sheetBgView;
    UIButton *missionListBtn;
    UIButton *rewardListBtn;
    UIScrollView *sheetScrollView;
    NSMutableDictionary *sheetViewList;
    NSMutableArray *sheetList;
    NSMutableArray *eventSheetList;
    NSMutableArray *rewardSheetList;
    SessionDownloader *listDownloader;
    int listCellHeight;
    UILabel *notExistList;
    int selectedSheetID;
    int selectedList;
    CGRect tableRect;
    UITableView *sheetListView;
    UITableView *rewardListView;
    ChallengeMissionSheetView *currentSheetView;
    BOOL downloadWait;
    MissionRewardDownloadView *rewardDownloadView;
}

@synthesize aDelegate = _aDelegate;

#pragma mark - Construction

/** @ghidraAddress 0xaa91c */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }
    BOOL isPad = [[JubeatAppDelegate appDelegate] isPad];

    // The background plate fills a centred rectangle the size of the challenge_menu_bg artwork.
    UIImage *bgImage = LoadScaledPngImage(kPlateImageName);
    CGSize bgSize = bgImage.size;
    int bgWidth = (int)bgSize.width;
    int bgHeight = (int)bgSize.height;
    selectedSheetID = [[ChallengeStatus sharedStatus] getSelectedMissionSheetID];

    CGFloat bgW = (CGFloat)bgWidth;
    CGFloat bgH = (CGFloat)bgHeight;
    listBgView = [[UIImageView alloc] initWithFrame:CGRectMake((frame.size.width - bgW) * 0.5,
                                                               (frame.size.height - bgH) * 0.5,
                                                               bgW,
                                                               bgH)];
    listBgView.image = bgImage;
    listBgView.userInteractionEnabled = YES;
    [self addSubview:listBgView];

    // The empty-state label fills the plate.
    notExistList = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, bgW, bgH)];
    notExistList.textAlignment = NSTextAlignmentCenter;
    notExistList.font = [UIFont systemFontOfSize:kEmptyLabelFontSize];
    notExistList.hidden = YES;
    [listBgView addSubview:notExistList];

    // The title image sits near the top of the plate, at a device-specific offset.
    UIImage *titleImage = LoadScaledPngImage(kTitleImageName);
    CGSize titleSize = titleImage.size;
    // The title top: 38.0 from the __const pool on the pad, 26.0 on the phone.
    CGFloat titleTop = isPad ? 38.0 : 26.0; // @ghidraAddress 0x28f4f8 (pad value)
    CGFloat titleY = titleTop - titleSize.height * 0.5;
    titleImageView = [[UIImageView alloc] initWithFrame:CGRectMake((bgW - titleSize.width) * 0.5,
                                                                   titleY,
                                                                   titleSize.width,
                                                                   titleSize.height)];
    titleImageView.image = titleImage;
    [listBgView addSubview:titleImageView];

    // The close button sits at the plate's top-left, its x device-specific.
    UIImage *closeImage = LoadScaledPngImage(kCloseButtonImageName);
    closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    CGSize closeSize = closeImage.size;
    // The close-button left edge: 19.0 on the pad, 10.0 on the phone.
    CGFloat closeX = isPad ? 19.0 : 10.0;
    closeBtn.frame =
        CGRectMake(closeX, titleTop - closeSize.height * 0.5, closeSize.width, closeSize.height);
    [closeBtn setBackgroundImage:closeImage forState:UIControlStateNormal];
    [closeBtn addTarget:self
                  action:@selector(closeSettingMenu:)
        forControlEvents:UIControlEventTouchUpInside];
    closeBtn.exclusiveTouch = YES;
    [listBgView addSubview:closeBtn];

    // Kick off the sheet-list download.
    listDownloader = [[SessionDownloader alloc] initWithURL:[ScratchUtil getMissionListURL]
                                                   delegate:self];
    listDownloader.tag = ChallengeMissionListKindMission;
    [listDownloader startDownloading];

    // The table rectangle: an inset column between the two list buttons. Its x is a device
    // margin (11 pad, 5 phone), its y is 100.0 on the pad and 70.0 on the phone, its width is
    // the plate width less twice the margin, and its height the plate height plus a device
    // offset (-0x4b pad, -0x6f phone).
    int tableMargin = isPad ? 11 : 5;
    // The table top: 100.0 (pad) / 70.0 (phone) from the __const pool.
    CGFloat tableY = isPad ? 100.0 : 70.0; // @ghidraAddress 0x28f3f0 (pad value)
    int heightOffset = isPad ? -0x6f : -0x4b;
    tableRect = CGRectMake((CGFloat)tableMargin,
                           tableY,
                           (CGFloat)(bgWidth - tableMargin * 2),
                           (CGFloat)(heightOffset + bgHeight));
    currentSheetView = nil;
    downloadWait = NO;

    // Load the two-state artwork: index 0 is the unselected variant, index 1 the selected one.
    sheetBtnImage[0] = LoadScaledPngImage([NSString stringWithFormat:kSheetButtonImageFormat, 0]);
    rewardBtnImage[0] = LoadScaledPngImage([NSString stringWithFormat:kRewardButtonImageFormat, 0]);
    listBagdeImage[0] = LoadScaledPngImage([NSString stringWithFormat:kListBadgeImageFormat, 0]);
    sheetBtnImage[1] = LoadScaledPngImage([NSString stringWithFormat:kSheetButtonImageFormat, 1]);
    rewardBtnImage[1] = LoadScaledPngImage([NSString stringWithFormat:kRewardButtonImageFormat, 1]);
    listBagdeImage[1] = LoadScaledPngImage([NSString stringWithFormat:kListBadgeImageFormat, 1]);
    listNewIconImage = LoadScaledPngImage(kListNewIconImageName);

    // The two list buttons sit side by side below the title, using the mission-button artwork's
    // size. The mission button's y is titleY (=100.0/70.0) less the button height.
    CGSize btnSize = sheetBtnImage[0].size;
    missionListBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    missionListBtn.frame =
        CGRectMake((CGFloat)tableMargin, tableY - btnSize.height, btnSize.width, btnSize.height);
    [missionListBtn setBackgroundImage:sheetBtnImage[0] forState:UIControlStateNormal];
    missionListBtn.tag = ChallengeMissionListKindMission;
    [missionListBtn addTarget:self
                       action:@selector(tapListBtn:)
             forControlEvents:UIControlEventTouchUpInside];
    missionListBtn.exclusiveTouch = YES;
    missionListBtn.enabled = NO;
    [listBgView addSubview:missionListBtn];

    rewardListBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    rewardListBtn.frame = CGRectMake((CGFloat)tableMargin + btnSize.width,
                                     tableY - btnSize.height,
                                     btnSize.width,
                                     btnSize.height);
    [rewardListBtn setBackgroundImage:rewardBtnImage[1] forState:UIControlStateNormal];
    rewardListBtn.tag = ChallengeMissionListKindReward;
    rewardListBtn.exclusiveTouch = YES;
    rewardListBtn.enabled = NO;
    [rewardListBtn addTarget:self
                      action:@selector(tapListBtn:)
            forControlEvents:UIControlEventTouchUpInside];
    [listBgView addSubview:rewardListBtn];

    // The per-row cell background plates.
    listBgImage[0] = LoadScaledPngImage([NSString stringWithFormat:kListBackgroundImageFormat, 0]);
    listBgImage[1] = LoadScaledPngImage([NSString stringWithFormat:kListBackgroundImageFormat, 1]);
    listCellHeight = (int)listBgImage[0].size.height;
    selectedList = ChallengeMissionListKindMission;
    rewardListView = nil;

    return self;
}

#pragma mark - List toggling

/** @ghidraAddress 0xab448 */
- (void)tapListBtn:(id)sender {
    int list = (int)[sender tag];
    if (list == selectedList) {
        return;
    }
    selectedList = list;
    [missionListBtn setBackgroundImage:sheetBtnImage[list] forState:UIControlStateNormal];
    [rewardListBtn setBackgroundImage:rewardBtnImage[1 - selectedList]
                             forState:UIControlStateNormal];
    if (selectedList == ChallengeMissionListKindReward && rewardSheetList == nil) {
        listDownloader =
            [[SessionDownloader alloc] initWithURL:[ScratchUtil getMissionRewardListURL]
                                          delegate:self];
        listDownloader.tag = ChallengeMissionListKindReward;
        [listDownloader startDownloading];
        missionListBtn.enabled = NO;
        rewardListBtn.enabled = NO;
        return;
    }
    [self switchListView:list];
}

/** @ghidraAddress 0xab60c */
- (void)switchListView:(int)list {
    int otherCount = (int)sheetList.count + (int)eventSheetList.count;
    int selectedCount;
    int incomingCount;
    BOOL toReward;
    if (list == ChallengeMissionListKindMission) {
        selectedCount = (int)rewardSheetList.count;
        incomingCount = otherCount;
        toReward = NO;
    } else if (list == ChallengeMissionListKindReward) {
        selectedCount = otherCount;
        incomingCount = (int)rewardSheetList.count;
        toReward = YES;
    } else {
        selectedCount = otherCount;
        incomingCount = otherCount;
        toReward = NO;
    }

    if (incomingCount == 0) {
        notExistList.text = kNoMissionText;
        if (toReward) {
            notExistList.text = kNoRewardText;
        }
    }
    if (incomingCount == 0 && selectedCount == 0) {
        missionListBtn.enabled = YES;
        rewardListBtn.enabled = YES;
        return;
    }

    // Pick the outgoing view (the currently mounted table, or the empty-state label) and the
    // incoming view (the table for the chosen list, or the empty-state label when it is empty).
    __weak UIView *outgoing = nil;
    if (selectedCount == 0) {
        outgoing = notExistList;
    } else if (list == ChallengeMissionListKindMission) {
        outgoing = rewardListView;
    } else {
        outgoing = sheetListView;
    }

    __weak UIView *incoming = nil;
    if (incomingCount == 0) {
        incoming = notExistList;
    } else if (toReward) {
        incoming = rewardListView;
    } else {
        incoming = sheetListView;
    }

    incoming.alpha = 0;
    [UIView animateWithDuration:kMissionPageAnimationDuration
        delay:0
        options:UIViewAnimationOptionCurveLinear
        animations:^{
          /** @ghidraAddress 0xab948 */
          outgoing.alpha = 0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0xab994 */
          outgoing.hidden = YES;
          incoming.hidden = NO;
          [UIView animateWithDuration:kMissionPageAnimationDuration
              delay:0
              options:UIViewAnimationOptionCurveLinear
              animations:^{
                /** @ghidraAddress 0xabad4 */
                incoming.alpha = 1;
              }
              completion:^(BOOL finished2) {
                /** @ghidraAddress 0xabb20 */
                self->missionListBtn.enabled = YES;
                self->rewardListBtn.enabled = YES;
              }];
        }];
}

#pragma mark - Close and cancel

/** @ghidraAddress 0xabbf4 */
- (void)tapClose:(id)sender {
    [self.aDelegate closeMenu];
}

/** @ghidraAddress 0xabc34 */
- (void)cancelSettingMenu:(id)sender {
    if ([sender boolValue] == NO) {
        [self.aDelegate closeMenu];
    } else {
        [[[ChallengeStatus sharedStatus] rootView] closeChallengeModeSessionError];
    }
}

/** @ghidraAddress 0xabce0 */
- (void)closeSettingMenu:(id)sender {
    if (currentSheetView != nil) {
        selectedSheetID = [[ChallengeStatus sharedStatus] getSelectedMissionSheetID];
        [self switchMissionView:NO];
        return;
    }
    [self.aDelegate closeMenu];
}

/** @ghidraAddress 0xabda0 */
- (void)missionSheetDisplayEnd {
    downloadWait = NO;
    closeBtn.enabled = YES;
}

#pragma mark - Downloading

/** @ghidraAddress 0xabdc8 */
- (void)downloaderFinished:(id)downloader {
    int tag = (int)[downloader tag];
    NSDictionary *json = [downloader getDataInJSON];
    if ([json[kStatusKey] intValue] != 0) {
        [self challengeConnectError:json];
        return;
    }

    if (tag == ChallengeMissionListKindReward) {
        rewardSheetList = nil;
        if ([json[kRewardListKey] count] == 0) {
            notExistList.text = kNoRewardText;
            notExistList.hidden = NO;
        } else {
            NSMutableArray *rewards = [[NSMutableArray alloc] init];
            for (id rewardEntry in json[kRewardListKey]) {
                NSMutableDictionary *wrapper = [[NSMutableDictionary alloc] init];
                wrapper[kRewardKey] = rewardEntry;
                ChallengeMissionReward *reward = [[ChallengeMissionReward alloc] init];
                [reward initWithDictionary:wrapper];
                [rewards addObject:reward];
            }
            rewardSheetList = [rewards copy];
        }
        if ((int)rewardSheetList.count > 0) {
            // The double init here mirrors the binary: a two-argument styled table is created
            // and immediately replaced by the plain single-argument one it keeps.
            rewardListView = [[UITableView alloc] initWithFrame:tableRect
                                                          style:UITableViewStyleGrouped];
            rewardListView = [[UITableView alloc] initWithFrame:tableRect];
            rewardListView.delegate = self;
            rewardListView.dataSource = self;
            rewardListView.backgroundColor = UIColor.clearColor;
            rewardListView.tag = ChallengeMissionListKindReward;
            rewardListView.exclusiveTouch = YES;
            [listBgView addSubview:rewardListView];
        }
        [self switchListView:ChallengeMissionListKindReward];
        return;
    }

    if (tag != ChallengeMissionListKindMission) {
        return;
    }

    sheetList = nil;
    eventSheetList = nil;
    if ([json[kSheetListKey] count] == 0) {
        notExistList.text = kNoMissionText;
        notExistList.hidden = NO;
    } else {
        NSMutableArray *sheets = [[NSMutableArray alloc] init];
        NSMutableArray *eventSheets = [[NSMutableArray alloc] init];
        NSDictionary *sheetDict = json[kSheetListKey];
        NSArray *keys =
            [sheetDict.allKeys sortedArrayUsingComparator:^NSComparisonResult(id left, id right) {
              /** @ghidraAddress 0xac93c */
              return [@([left intValue]) compare:@([right intValue])];
            }];
        for (id key in keys) {
            NSMutableDictionary *entry = [sheetDict[key] mutableCopy];
            entry[kSheetIDKey] = key;
            ChallengeMissionSheet *sheet = [[ChallengeMissionSheet alloc] init];
            [sheet initWithDictionary:entry];
            int sheetID = [key intValue];
            int missionCnt = sheet.missionCnt;
            NSString *updateTime = sheet.updateTime;
            if (![[ChallengeMissionFileManager sharedManager] isExistMissionSheet:sheetID
                                                                            count:missionCnt
                                                                       updateTime:updateTime]) {
                NSMutableArray *target = sheet.isEvent ? eventSheets : sheets;
                [target addObject:sheet];
                [[ChallengeMissionFileManager sharedManager] addMissionSheet:sheet];
            } else {
                ChallengeMissionSheet *stored =
                    [[ChallengeMissionFileManager sharedManager] getChallengeSheet:sheetID];
                NSMutableArray *target = sheet.isEvent ? eventSheets : sheets;
                [target addObject:stored];
            }
        }
        eventSheetList = [eventSheets copy];
        sheetList = [sheets copy];
        sheetViewList = [[NSMutableDictionary alloc] init];
    }

    if ((int)eventSheetList.count + (int)sheetList.count < 1) {
        listBgView.hidden = NO;
    } else {
        // The same double init as the reward path.
        sheetListView = [[UITableView alloc] initWithFrame:tableRect style:UITableViewStyleGrouped];
        sheetListView = [[UITableView alloc] initWithFrame:tableRect];
        sheetListView.delegate = self;
        sheetListView.dataSource = self;
        sheetListView.exclusiveTouch = YES;
        sheetListView.backgroundColor = UIColor.clearColor;
        sheetListView.tag = ChallengeMissionListKindMission;
        [listBgView addSubview:sheetListView];
    }
    missionListBtn.enabled = YES;
    [rewardListBtn setEnabled:YES];
}

/** @ghidraAddress 0xacf9c */
- (void)downloaderError:(id)downloader {
    if ((int)[downloader tag] == ChallengeMissionListKindReward) {
        missionListBtn.enabled = YES;
        rewardListBtn.enabled = YES;
    }
    NSString *message = [NSBundle.mainBundle localizedStringForKey:kServerErrorMsgKey
                                                             value:@""
                                                             table:nil];
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:kOKKey value:@"" table:nil];
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:nil
                                            tag:0
                                          title:nil
                                            msg:message
                                         cancel:@""
                                        btnText:ok
                                           show:YES];
}

#pragma mark - Error alerts

/** @ghidraAddress 0xacaa8 */
- (void)challengeConnectError:(NSDictionary *)info {
    if (info[kStatusKey] != nil) {
        int code = [info[kStatusKey] intValue];
        if (code == kErrorCodeUpdateRequired) {
            [[AlertViewManager sharedManager] showUpdateAlert];
            return;
        }
        if (code == kErrorCodeServer) {
            NSString *message = [NSBundle.mainBundle localizedStringForKey:kServerErrorMsgKey
                                                                     value:@""
                                                                     table:nil];
            if (info[kErrMessageKey] != nil) {
                message = info[kErrMessageKey];
            }
            NSString *ok = [NSBundle.mainBundle localizedStringForKey:kOKKey value:@"" table:nil];
            [[AlertViewManager sharedManager] makeAlert:0
                                               delegate:self
                                                    tag:kSessionErrorAlertTag
                                                  title:nil
                                                    msg:message
                                                 cancel:@""
                                                btnText:ok
                                                   show:YES];
            return;
        }
        if (code == kErrorCodeNoScratch) {
            NSString *message = kNoScratchText;
            if (info[kErrMessageKey] != nil) {
                message = info[kErrMessageKey];
            }
            NSString *ok = [NSBundle.mainBundle localizedStringForKey:kOKKey value:@"" table:nil];
            [[AlertViewManager sharedManager] makeAlert:0
                                               delegate:nil
                                                    tag:0
                                                  title:nil
                                                    msg:message
                                                 cancel:@""
                                                btnText:ok
                                                   show:YES];
            return;
        }
    }
    NSString *message = [NSBundle.mainBundle localizedStringForKey:kServerErrorMsgKey
                                                             value:@""
                                                             table:nil];
    if (info[kErrMessageKey] != nil) {
        message = info[kErrMessageKey];
    }
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:kOKKey value:@"" table:nil];
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:nil
                                            tag:0
                                          title:nil
                                            msg:message
                                         cancel:@""
                                        btnText:ok
                                           show:YES];
}

#pragma mark - UITableViewDataSource / Delegate

/** @ghidraAddress 0xaca30 */
- (void)tableView:(UITableView *)tableView
    willDisplayHeaderView:(UIView *)view
               forSection:(NSInteger)section {
    view.tintColor = UIColor.whiteColor;
}

/** @ghidraAddress 0xad12c */
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    // Alternate the per-row background plate by row parity.
    UIImage *rowBg = listBgImage[indexPath.row % 2];
    if (tableView.tag == ChallengeMissionListKindMission) {
        BOOL isEventRow = (indexPath.section == 0) && (eventSheetList.count != 0);
        NSString *identifier = [NSString stringWithFormat:@"%@", kMissionSheetListCellID];
        ChallengeMissionListCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
        if (cell == nil) {
            cell = [[ChallengeMissionListCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                   reuseIdentifier:identifier];
        }
        cell.tag = indexPath.row;
        ChallengeMissionSheet *sheet;
        if (isEventRow) {
            sheet = eventSheetList[indexPath.row];
        } else {
            sheet = sheetList[indexPath.row];
        }
        NSString *name = sheet.sheetName;
        if (name == nil) {
            name = @"";
        }
        cell.textLabel.text = name;
        cell.backgroundColor = UIColor.clearColor;
        [cell setBgImage:rowBg];

        BOOL selected;
        if (isEventRow) {
            if (sheet.sheetEndDate.length < kMinimumPeriodLength) {
                [cell setTitle:name period:nil];
            } else {
                NSString *year = [sheet.sheetEndDate substringWithRange:NSMakeRange(0, 4)];
                NSString *month = [sheet.sheetEndDate substringWithRange:NSMakeRange(5, 2)];
                NSString *day = [sheet.sheetEndDate substringWithRange:NSMakeRange(8, 2)];
                NSString *time = [sheet.sheetEndDate substringWithRange:NSMakeRange(11, 5)];
                NSString *period = nil;
                if (sheet.sheetEndDate != nil) {
                    period = [NSString stringWithFormat:kPeriodFormat, year, month, day, time];
                }
                [cell setTitle:name period:period];
            }
            selected = NO;
        } else {
            [cell setTitle:name period:nil];
            selected = (selectedSheetID == sheet.sheetID);
        }
        UIImage *icon = sheet.bConfirmed ? nil : listNewIconImage;
        [cell setIconImage:icon selectedImage:selected];
        return cell;
    }

    NSString *identifier = [NSString stringWithFormat:@"%@", kRewardListCellID];
    ChallengeRewardListCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[ChallengeRewardListCell alloc] initWithStyle:UITableViewCellStyleDefault
                                              reuseIdentifier:identifier];
    }
    cell.tag = indexPath.row;
    ChallengeMissionReward *reward = rewardSheetList[indexPath.row];
    NSString *name = reward.rewardName;
    if (name == nil) {
        name = @"";
    }
    cell.textLabel.text = name;
    cell.backgroundColor = UIColor.clearColor;
    [cell setBgImage:rowBg];
    [cell setTitle:name period:nil];
    return cell;
}

/** @ghidraAddress 0xad87c */
- (void)tableView:(UITableView *)tableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath {
}

/** @ghidraAddress 0xad880 */
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return (CGFloat)listCellHeight;
}

/** @ghidraAddress 0xad898 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (tableView.tag == ChallengeMissionListKindMission) {
        return eventSheetList.count != 0 ? 2 : 1;
    }
    return 1;
}

/** @ghidraAddress 0xad8f4 */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (tableView.tag == ChallengeMissionListKindMission) {
        if (section != 1 && eventSheetList.count != 0) {
            return (NSInteger)eventSheetList.count;
        }
        return (NSInteger)sheetList.count;
    }
    return (NSInteger)rewardSheetList.count;
}

/** @ghidraAddress 0xad9a4 */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView.tag != ChallengeMissionListKindMission) {
        [[AudioManager sharedManager] playSeResFile:kCancelSE inDirectory:nil];
        (void)indexPath.row; // Yes, the binary evaluates -row here and discards it.
        ChallengeMissionReward *reward = rewardSheetList[indexPath.row];
        rewardDownloadView = [[MissionRewardDownloadView alloc]
            initWithFrame:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)];
        [rewardDownloadView setMissionInfo:reward enableDownload:YES];
        rewardDownloadView.aDelegate = self;
        rewardDownloadView.alpha = 0;
        [self addSubview:rewardDownloadView];
        __weak MissionRewardDownloadView *weakView = rewardDownloadView;
        [UIView animateWithDuration:kMissionPageAnimationDuration
                              delay:0
                            options:UIViewAnimationOptionCurveLinear
                         animations:^{
                           /** @ghidraAddress 0xadefc */
                           weakView.alpha = 1;
                         }
                         completion:^(BOOL finished){
                             /** @ghidraAddress 0xadf48 */
                         }];
        return;
    }

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    ChallengeMissionSheet *sheet;
    if (indexPath.section != 1 && eventSheetList.count != 0) {
        sheet = eventSheetList[indexPath.row];
        (void)sheetList.count; // Yes, the binary reads -count here and discards it.
    } else {
        sheet = sheetList[indexPath.row];
    }
    (void)indexPath.row; // Yes, the binary evaluates -row again and discards it.
    NSNumber *key = @(sheet.sheetID);
    ChallengeMissionSheetView *view = sheetViewList[key];
    if (view == nil) {
        view = [[ChallengeMissionSheetView alloc] initWithFrame:self.frame sheetID:sheet.sheetID];
        view.aDelegate = self;
        sheetViewList[key] = view;
    } else {
        [sheetViewList[key] refreshSheetInfo];
    }
    currentSheetView = sheetViewList[key];
    if (!currentSheetView.bDownloadEnd) {
        downloadWait = YES;
    }
    [self switchMissionView:YES];
}

#pragma mark - Mission-sheet transition

/** @ghidraAddress 0xadf4c */
- (void)switchMissionView:(BOOL)showSheet {
    [[AudioManager sharedManager] playSeResFile:kCancelSE inDirectory:nil];
    __weak UIView *outgoing;
    __weak UIView *incoming;
    closeBtn.enabled = NO;
    if (showSheet == NO) {
        [sheetListView reloadData];
        outgoing = currentSheetView;
        incoming = listBgView;
        [self addSubview:listBgView];
    } else {
        outgoing = listBgView;
        incoming = currentSheetView;
        [self addSubview:currentSheetView];
        currentSheetView.alpha = 0;
    }
    [UIView animateWithDuration:kMissionPageAnimationDuration
        delay:0
        options:UIViewAnimationOptionCurveLinear
        animations:^{
          /** @ghidraAddress 0xae21c */
          outgoing.alpha = 0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0xae268 */
          [outgoing removeFromSuperview];
          if (showSheet == NO) {
              self->currentSheetView = nil;
          }
          [UIView animateWithDuration:kMissionPageAnimationDuration
              delay:0
              options:UIViewAnimationOptionCurveLinear
              animations:^{
                /** @ghidraAddress 0xae39c */
                incoming.alpha = 1;
              }
              completion:^(BOOL finished2) {
                /** @ghidraAddress 0xae3e8 */
                if (self->downloadWait) {
                    return;
                }
                self->closeBtn.enabled = YES;
              }];
        }];
}

#pragma mark - Alert and reward-window callbacks

/** @ghidraAddress 0xae498 */
- (void)alertSelect:(NSDictionary *)info {
    if ([info[kTagKey] intValue] == kSessionErrorAlertTag) {
        [[[ChallengeStatus sharedStatus] rootView] closeChallengeModeSessionError];
    }
}

/** @ghidraAddress 0xae558 */
- (void)closeRewardWin:(id)sender {
    [[AudioManager sharedManager] playSeResFile:kCancelSE inDirectory:nil];
    __weak MissionRewardDownloadView *weakView = rewardDownloadView;
    [UIView animateWithDuration:kMissionPageAnimationDuration
        delay:0
        options:UIViewAnimationOptionCurveLinear
        animations:^{
          /** @ghidraAddress 0xae6f0 */
          weakView.alpha = 0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0xae73c */
          [weakView removeFromSuperview];
          self->rewardDownloadView = nil;
        }];
}

#pragma mark - Delegate forwarding

/** @ghidraAddress 0xae7e0 */
- (void)cubePurchase {
    if ([self.aDelegate respondsToSelector:@selector(cubePurchase)]) {
        [self.aDelegate performSelector:@selector(cubePurchase)];
    }
}

/** @ghidraAddress 0xae890 */
- (void)refreshStatus {
    if ([self.aDelegate respondsToSelector:@selector(refreshStatus)]) {
        [self.aDelegate performSelector:@selector(refreshStatus)];
    }
}

@end
