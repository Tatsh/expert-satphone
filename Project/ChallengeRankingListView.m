#import "ChallengeRankingListView.h"

#import "AlertViewManager.h"
#import "AudioManager.h"
#import "ChallengeModeRootView.h"
#import "ChallengeRankingListViewCell.h"
#import "ChallengeStatus.h"
#import "Downloader.h"
#import "EditorIDManager.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"
#import "ScratchInfo.h"
#import "ScratchUtil.h"
#import "SessionDownloader.h"

// The image asset base names for the list chrome.
static NSString *const kResListBg = @"scratch_list_bg";
static NSString *const kResTitleCountry = @"scratch_list_title_japanrank";
static NSString *const kResTitleRival = @"scratch_list_title_rivalrank";
static NSString *const kResPlateOdd = @"scratch_list_plate_slim_01";
static NSString *const kResPlateEven = @"scratch_list_plate_slim_02";
static NSString *const kResPlatePickup = @"scratch_list_plate_slim_03";
static NSString *const kResBackButton = @"scratch_btn_back";
static NSString *const kResListLine = @"scratch_list_line";
static NSString *const kResRankingTag = @"scratch_list_ranking_tag";
static NSString *const kResDiffButtonSeed = @"scratch_rank_bas_0";
static NSString *const kResRankingName = @"scratch_ranking_name";
static NSString *const kResMyRankButton = @"scratch_list_btn_myrank";
static NSString *const kResTopRankButton = @"scratch_list_btn_toprank";
static NSString *const kResPrevButton = @"scratch_btn_prev";
static NSString *const kResNextButton = @"scratch_btn_next";
static NSString *const kResAreaButtonSeed = @"scratch_area_btn_0";
static NSString *const kResSheetRival = @"scratch_sheet_rival";
static NSString *const kResRivalRegMsg1 = @"scratch_rival_reg_m01";
static NSString *const kResRivalRegMsg2 = @"scratch_rival_reg_m02";
static NSString *const kResRivalRegMsg3 = @"scratch_rival_reg_m03";
static NSString *const kResButtonNo = @"scratch_btn_no";
static NSString *const kResButtonYes = @"scratch_btn_yes";
static NSString *const kResButtonOk = @"scratch_btn_ok";
static NSString *const kResBackButtonAlt = @"scratch_btn_cancel";

// The image-name format strings.
static NSString *const kFmtDiffButton = @"scratch_rank_%@_%d";
static NSString *const kFmtAreaButton = @"scratch_area_btn_%d";
static NSString *const kFmtRankIcon = @"challenge_rank_icon_0%d";
static NSString *const kFmtRankIconPrefix = @"challenge_rank_icon_pref_0%d";

// The four difficulty tokens spliced into kFmtDiffButton, one per button.
static NSString *const kDiffTokens[] = {@"bas", @"adv", @"ext", @"total"};

// The cell reuse identifier and the plain "%@" boxing format.
static NSString *const kCellReuseIdentifier = @"RivalListCell";
static NSString *const kBoxFormat = @"%@";

// The music-name-with-update format: "<name>(<updated> 更新)".
static NSString *const kMusicNameUpdatedFormat = @"%@(%@ 更新)";

// The sound-effect resource played when the close button is tapped.
static NSString *const kSeChallengeCancel = @"SD_CHALLENGE_CANCEL";

// The rival-registration alert messages.
static NSString *const kMsgAlreadyRegistered = @"登録済みのユーザーです";
static NSString *const kMsgRegisterFailed = @"ライバルの登録に失敗しました";
static NSString *const kMsgIsYourself = @"それはあなたです";

// The literal "yes" cancel-button title on the ranking-load failure alert.
static NSString *const kButtonYesText = @"はい";

// The preference key seeding the initial difficulty.
static NSString *const kPrefDifficultyKey = @"PrefDifficulty";

// The request body keys.
static NSString *const kBodyScratchIDKey = @"scratch_id";
static NSString *const kBodyMusicIDKey = @"music_id";
static NSString *const kBodyHeadKey = @"head";
static NSString *const kBodyLimitKey = @"limit";
static NSString *const kBodyKindKey = @"kind";
static NSString *const kBodyDifficultyKey = @"difficulty";
static NSString *const kBodyRivalIDKey = @"rival_id";
static NSString *const kBodyIsAddKey = @"is_add";

// The line-up / response dictionary keys.
static NSString *const kKeyName = @"name";
static NSString *const kKeyMusicID = @"music_id";
static NSString *const kKeyUserID = @"user_id";
static NSString *const kKeyStatus = @"status";
static NSString *const kKeyErrorMessage = @"err_message";
static NSString *const kKeyUpdated = @"updated";
static NSString *const kKeyRank = @"rank";
static NSString *const kKeyTotal = @"total";
static NSString *const kKeyMyRank = @"my_rank";
static NSString *const kKeyMyPosition = @"my_position";
static NSString *const kKeyScore = @"score";
static NSString *const kKeyUserType = @"user_type";
static NSString *const kKeyPrizeCount = @"prize_count";
static NSString *const kKeyHasNext = @"has_next";

// The alert-info keys echoed back to -alertSelect:.
static NSString *const kAlertInfoButtonMessageKey = @"btnMessage";
static NSString *const kAlertInfoTagKey = @"Tag";

// The localised bundle keys.
static NSString *const kBundleKeyOK = @"OK";
static NSString *const kBundleKeyServerErrorMsg = @"ServerErrorMsg";

// The server status codes handled specially.
static const int kStatusNone = -1;
static const int kStatusOK = 0;
static const int kStatusServerError = 0x18b53;
static const int kStatusUpdateRequired = 0x186ab;
static const int kStatusAlreadyRegistered = 0x192c1;

// The download tags: 1 identifies the ranking-page load, 2 the rival add/remove POST.
static const int kTagRankingLoad = 1;
static const int kTagRivalRegister = 2;

// The API tags for the two request kinds.
static const int kApiTagRankingLoad = 10;
static const int kApiTagRivalRegister = 0xf;

// The alert tags routing -alertSelect: and the download error alerts.
static const int kAddConfirmAlertTag = 5;
static const int kAlreadyRegisteredAlertTag = 6;
static const int kSessionErrorAlertTag = 9999;
static const int kDownloaderErrorAlertTag = 3;

// The plain-alert type shared by every alert this view raises.
static const int kPlainAlertType = 0;

// The tapped-button index that means "confirmed".
static const int kConfirmButtonIndex = 1;

// The head-row music id: the "all tunes" ranking has no tune of its own.
static const int kAllTunesMusicID = 0;

// The two selectable areas.
static const int kAreaCountry = 0;
static const int kAreaRival = 1;

// One page of the ranking is thirty rows.
static const int kPageSize = 30;

// The self-rank badge shows a prize count clamped to two digits.
static const int kMaxBadgeCount = 99;

// The user_type that carries a prize badge.
static const int kUserTypePrize = 7;

// The activity indicator's fixed square side.
static const CGFloat kIndicatorSide = 30.0;

// The two-stage cross-fade shared by every animated transition, and its dimmed alpha.
static const NSTimeInterval kFadeDuration = 0.2; // @ghidraAddress 0x28e040
static const CGFloat kDimmedAlpha = 0.5;
static const UIViewAnimationOptions kFadeOptions =
    UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction;

// The country/rival title overlay's alpha.
static const CGFloat kTitleAlpha = 0.5;

@interface ChallengeRankingListView () <AlertViewManagerDelegate,
                                        DownloaderDelegate,
                                        UITableViewDataSource,
                                        UITableViewDelegate>
@end

@implementation ChallengeRankingListView {
    UIView *bgView;                             // +0x8
    UIImageView *bgImageView;                   // +0x10
    UIImageView *titleView;                     // +0x18
    UIButton *closeBtn;                         // +0x20
    UIImageView *listLineView;                  // +0x28
    UITableView *listView;                      // +0x30
    UIImage *plateBgImage0;                     // +0x38
    UIImage *plateBgImage1;                     // +0x40
    UIImage *plateBgPickup;                     // +0x48
    UIImage *iconImage[8];                      // +0x50
    UIImage *iconNumImage[10];                  // +0x90
    UIImageView *tagBeltView;                   // +0xe0
    UIButton *diffBtn[4];                       // +0xe8
    UIImage *btnImage[4][2];                    // +0x108
    UIImage *areaImage[2];                      // +0x148
    UIButton *areaBtn[2];                       // +0x158
    UIButton *prevBtn;                          // +0x168
    UIButton *nextBtn;                          // +0x170
    UIButton *myRankBtn;                        // +0x178
    UIButton *topRankBtn;                       // +0x180
    UIImageView *musicNameView;                 // +0x188
    UILabel *musicNameText;                     // +0x190
    NSString *musicDefName;                     // +0x198
    int cellHeight;                             // +0x1a0
    int dispRank;                               // +0x1a4
    int selectDifficulty;                       // +0x1a8
    int selectArea;                             // +0x1ac
    NSString *myID;                             // +0x1b0
    UIActivityIndicatorView *downloadIndicator; // +0x1b8
    int pickupSlot;                             // +0x1c0
    NSArray *rankingList;                       // +0x1c8
    int musicID;                                // +0x1d0
    NSString *musicName;                        // +0x1d8
    int myRank;                                 // +0x1e0
    int myIndex;                                // +0x1e4
    BOOL isNext;                                // +0x1e8
    int selectRankIndex;                        // +0x1ec
    int rankingTotal;                           // +0x1f0
    SessionDownloader *rankingDownloader;       // +0x1f8
    CGRect listRect;                            // +0x200 (declared in the metadata; unused)
    UILabel *myRankLabel;                       // +0x220 (declared in the metadata; unused)
    UILabel *currentPageLabel;                  // +0x228 (declared in the metadata; unused)
    ScratchInfo *targetInfo;                    // +0x230
    NSNumber *targetScratchID;                  // +0x238
    UIView *rivalCover;                         // +0x240
    UIImageView *addMessage;                    // +0x248
    UIView *rivalAddView;                       // +0x250
    UIImageView *addBgView;                     // +0x258
    UIButton *addBtn;                           // +0x260
    UIButton *cancelBtn;                        // +0x268
    UIButton *endBtn;                           // +0x270
    UILabel *rivalID;                           // +0x278
    UILabel *rivalName;                         // +0x280
    NSString *selectedRivalID;                  // +0x288
}

@synthesize aDelegate = _aDelegate;

#pragma mark - Construction

/** @ghidraAddress 0x156254 */
- (nullable instancetype)initWithFrame:(CGRect)frame
                                 mInfo:(nullable ScratchInfo *)mInfo
                              rankType:(int)rankType {
    self = [super initWithFrame:frame];
    if (!self) {
        return self;
    }
    myID = [EditorIDManager getKeyString:[EditorIDManager getEditorIDKey]];
    targetInfo = mInfo;
    musicName = mInfo.musicName;
    targetScratchID = [ChallengeStatus sharedStatus].scratchID;
    musicID = mInfo.musicID;
    selectDifficulty = (int)[NSUserDefaults.standardUserDefaults integerForKey:kPrefDifficultyKey];
    selectArea = rankType;
    myRank = [mInfo getMyRank:selectDifficulty];
    myIndex = [mInfo getMyIndex:selectDifficulty];
    if (selectArea == kAreaRival) {
        myIndex = -1;
        myRank = -1;
    }
    [self createView];
    return self;
}

/** @ghidraAddress 0x1564cc */
- (nullable instancetype)initWithFrame:(CGRect)frame
                                 mDict:(nullable NSDictionary *)mDict
                             scratchID:(int)scratchID {
    self = [super initWithFrame:frame];
    if (!self) {
        return self;
    }
    myID = [EditorIDManager getKeyString:[EditorIDManager getEditorIDKey]];
    targetInfo = nil;
    targetScratchID = @(scratchID);
    musicName = mDict[kKeyName];
    musicID = [mDict[kKeyMusicID] intValue];
    // The "all tunes" head row (music id 0) defaults to the extreme difficulty; every real tune
    // defaults to basic.
    selectDifficulty = (musicID == kAllTunesMusicID) ? 4 : 0;
    selectArea = kAreaCountry;
    myIndex = -1;
    myRank = -1;
    [self createView];
    return self;
}

#pragma mark - View building

// Builds the entire ranking chrome: background, title, table, difficulty and area selectors,
// paging buttons, the music-name plate, and the rank-badge atlases, then fetches the first page.
//
// Every layout constant below is recovered from the disassembly at 0x154a18; the __const doubles
// are annotated with their image-relative addresses. The device idiom splits nearly every metric
// (pad values first, phone values in the isPad == NO arm).
//
/** @ghidraAddress 0x154a18 */
- (void)createView {
    BOOL isPad = [JubeatAppDelegate appDelegate].isPad;
    myID = [EditorIDManager getKeyString:[EditorIDManager getEditorIDKey]];
    (void)self.frame; // Yes, the binary fetches the frame here and discards it.
    dispRank = (myRank < 0) ? 0 : ((myRank - 1) / kPageSize) * kPageSize;

    // The background image and its container, centred in the modal.
    UIImage *bgImg = LoadScaledPngImage(kResListBg);
    bgView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, bgImg.size.width, bgImg.size.height)];
    [bgView setCenter:CGPointMake(self.frame.size.width * kDimmedAlpha,
                                  self.frame.size.height * kDimmedAlpha)];
    [self addSubview:bgView];
    bgImageView = [[UIImageView alloc] initWithImage:bgImg];
    [bgView addSubview:bgImageView];

    // The margins, per idiom: a leading inset, a bottom cover inset, and the belt/line gaps.
    const CGFloat inset = isPad ? 12.0 : 5.0;
    const CGFloat topGap = isPad ? 4.0 : 6.0;
    const CGFloat belowListGap = isPad ? 12.0 : 6.0;
    const CGFloat coverBottomInset = isPad ? 8.0 : 0.0;
    const CGFloat contentWidth = bgImg.size.width - inset * 2;

    // The semi-transparent rival cover sits over the content area.
    rivalCover = [[UIView alloc]
        initWithFrame:CGRectMake(inset,
                                 0,
                                 contentWidth,
                                 (self.frame.size.height * kDimmedAlpha - topGap) - belowListGap)];
    [rivalCover setCenter:CGPointMake(self.frame.size.width * kDimmedAlpha,
                                      (self.frame.size.height - coverBottomInset) * kDimmedAlpha)];
    // The original used colorWithWhite:0 alpha:0.5.
    [rivalCover setBackgroundColor:[UIColor colorWithWhite:0 alpha:kDimmedAlpha]];

    // The country/rival title art, one per area; on the phone it is centred over the background.
    areaImage[kAreaCountry] = LoadScaledPngImage(kResTitleCountry);
    areaImage[kAreaRival] = LoadScaledPngImage(kResTitleRival);
    UIImage *titleImg = areaImage[selectArea];
    CGFloat titleX = 0.0;
    if (!isPad) {
        titleX = (CGFloat)(int)((bgView.frame.size.width - titleImg.size.width) * kDimmedAlpha);
    }
    titleView = [[UIImageView alloc] initWithImage:titleImg];
    const CGFloat titleY = isPad ? 0.0 : 4.0;
    [titleView setFrame:CGRectMake(titleX, titleY, titleImg.size.width, titleImg.size.height)];
    [bgView addSubview:titleView];

    // The three row plates and the cell height.
    plateBgImage0 = LoadScaledPngImage(kResPlateOdd);
    plateBgImage1 = LoadScaledPngImage(kResPlateEven);
    plateBgPickup = LoadScaledPngImage(kResPlatePickup);
    cellHeight = isPad ? 0x24 : 0x18;

    // The close button, top-right of the background.
    UIImage *closeImg = LoadScaledPngImage(kResBackButton);
    const CGFloat closeX = isPad ? 16.0 : 8.0;
    const CGFloat closeY = (isPad ? 28.0 : 18.0) + closeImg.size.height * -0.5;
    closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [closeBtn setFrame:CGRectMake(closeX, closeY, closeImg.size.width, closeImg.size.height)];
    [closeBtn setImage:closeImg forState:UIControlStateNormal];
    [closeBtn addTarget:self
                  action:@selector(tapCloseBtn:)
        forControlEvents:UIControlEventTouchUpInside];
    [closeBtn setExclusiveTouch:YES];
    [bgView addSubview:closeBtn];

    // The list geometry: it starts below the title art at a per-idiom y, spans the content width,
    // and reaches down to the belt gap.
    const CGFloat listX = isPad ? 12.0 : 5.0;
    const CGFloat listY = isPad ? 212.0 : 155.0; // @ghidraAddress 0x28f6d8 / 0x2932b8
    const CGFloat listWidth = isPad ? 0x1cc : 0x135;
    const CGFloat listHeight =
        (CGFloat)(int)((bgImageView.image.size.height - listY) - belowListGap);
    listView = [[UITableView alloc] initWithFrame:CGRectMake(listX, listY, listWidth, listHeight)
                                            style:UITableViewStylePlain];
    [listView setBackgroundColor:UIColor.clearColor];
    [listView setDelegate:self];
    [listView setDataSource:self];
    [listView setAlpha:0];
    [listView setRowHeight:cellHeight];
    [bgView addSubview:listView];

    // The horizontal rule under the table header.
    UIImage *lineImg = LoadScaledPngImage(kResListLine);
    listLineView = [[UIImageView alloc] initWithImage:lineImg];
    [listLineView setFrame:CGRectMake(listX, listY, listWidth, lineImg.size.height)];
    [bgView addSubview:listLineView];

    // The ranking tag belt sits just above the list.
    UIImage *beltImg = LoadScaledPngImage(kResRankingTag);
    const CGFloat beltY = (CGFloat)(int)(listY - beltImg.size.height);
    tagBeltView = [[UIImageView alloc] initWithImage:beltImg];
    [tagBeltView setFrame:CGRectMake(listX, beltY, beltImg.size.width, beltImg.size.height)];
    [tagBeltView setImage:beltImg];
    [bgView addSubview:tagBeltView];

    // The difficulty buttons above the belt, or (for the "all tunes" head row) a shorter belt and
    // list without them.
    UIImage *diffSeedImg = LoadScaledPngImage(kResDiffButtonSeed);
    const CGFloat diffY = (CGFloat)(int)(beltY - diffSeedImg.size.height);
    if (musicID == kAllTunesMusicID) {
        // No difficulty buttons: drop the belt to the difficulty row's y, push the line down by
        // the belt height, and grow the list to reclaim the freed space.
        [tagBeltView setFrame:CGRectMake(tagBeltView.frame.origin.x,
                                         diffY,
                                         tagBeltView.frame.size.width,
                                         tagBeltView.frame.size.height)];
        const CGFloat lineY = (CGFloat)((int)tagBeltView.frame.size.height + (int)diffY);
        [listLineView setFrame:CGRectMake(listLineView.frame.origin.x,
                                          lineY,
                                          listLineView.frame.size.width,
                                          listLineView.frame.size.height)];
        [listView setFrame:CGRectMake(listView.frame.origin.x,
                                      listView.frame.origin.y,
                                      listView.frame.size.width,
                                      listView.frame.size.height + diffSeedImg.size.height)];
    } else {
        for (int i = 0; i < 4; ++i) {
            btnImage[i][0] =
                LoadScaledPngImage([NSString stringWithFormat:kFmtDiffButton, kDiffTokens[i], 0]);
            btnImage[i][1] =
                LoadScaledPngImage([NSString stringWithFormat:kFmtDiffButton, kDiffTokens[i], 1]);
            diffBtn[i] = [UIButton buttonWithType:UIButtonTypeCustom];
            const CGFloat bx = listX + (CGFloat)i * diffSeedImg.size.width;
            [diffBtn[i]
                setFrame:CGRectMake(bx, diffY, diffSeedImg.size.width, diffSeedImg.size.height)];
            [diffBtn[i] setBackgroundImage:(i == selectDifficulty) ? btnImage[i][0] : btnImage[i][1]
                                  forState:UIControlStateNormal];
            [diffBtn[i] setExclusiveTouch:YES];
            [diffBtn[i] addTarget:self
                           action:@selector(tapDifficulty:)
                 forControlEvents:UIControlEventTouchUpInside];
            [diffBtn[i] setTag:i];
            [bgView addSubview:diffBtn[i]];
        }
    }

    // The music-name plate and its centred label, above the difficulty row.
    UIImage *nameImg = LoadScaledPngImage(kResRankingName);
    const CGFloat nameFontSize = isPad ? 16.0 : 9.0;
    const CGFloat centreX = (CGFloat)((int)inset + (int)listWidth / 2);
    const CGFloat labelSpacing = isPad ? 6.0 : 3.0;
    const CGFloat nameY = (CGFloat)(int)(diffY - (labelSpacing + nameImg.size.height));
    // The area buttons sit at a fixed y, and the next button trails a per-idiom right edge.
    const CGFloat areaButtonY = isPad ? 54.0 : 32.0; // @ghidraAddress 0x28f640 / 0x28f458
    const CGFloat areaGap = isPad ? 472.0 : 314.0;   // @ghidraAddress 0x2932c0 / 0x28f940
    musicNameView = [[UIImageView alloc] initWithImage:nameImg];
    [musicNameView setFrame:CGRectMake(centreX - nameImg.size.width * kDimmedAlpha,
                                       nameY,
                                       nameImg.size.width,
                                       nameImg.size.height)];
    [bgView addSubview:musicNameView];
    musicNameText =
        [[UILabel alloc] initWithFrame:CGRectMake(0, 2.0, nameImg.size.width, nameImg.size.height)];
    [musicNameText setFont:[UIFont systemFontOfSize:nameFontSize]];
    [musicNameText setTextAlignment:NSTextAlignmentCenter];
    [musicNameText setText:musicName];
    [musicNameView addSubview:musicNameText];
    musicDefName = [musicName copy];

    // The "my rank" button trailing the name plate.
    UIImage *myRankImg = LoadScaledPngImage(kResMyRankButton);
    const CGFloat myRankX = centreX + myRankImg.size.width * kDimmedAlpha;
    const CGFloat buttonRowY = (CGFloat)(int)(nameY - (labelSpacing + myRankImg.size.height));
    myRankBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [myRankBtn setFrame:CGRectMake((CGFloat)(int)myRankX,
                                   buttonRowY,
                                   myRankImg.size.width,
                                   myRankImg.size.height)];
    [myRankBtn setBackgroundImage:myRankImg forState:UIControlStateNormal];
    [myRankBtn addTarget:self
                  action:@selector(tapMyRank:)
        forControlEvents:UIControlEventTouchUpInside];
    [myRankBtn setExclusiveTouch:YES];
    [bgView addSubview:myRankBtn];
    [self enableMyRankBtn];

    // The "top rank" button leading the name plate.
    UIImage *topRankImg = LoadScaledPngImage(kResTopRankButton);
    topRankBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [topRankBtn setFrame:CGRectMake((CGFloat)(int)(centreX + topRankImg.size.width * -1.5),
                                    buttonRowY,
                                    topRankImg.size.width,
                                    topRankImg.size.height)];
    [topRankBtn setBackgroundImage:topRankImg forState:UIControlStateNormal];
    [topRankBtn addTarget:self
                   action:@selector(tapTopRank:)
         forControlEvents:UIControlEventTouchUpInside];
    [topRankBtn setExclusiveTouch:YES];
    [bgView addSubview:topRankBtn];

    // The previous-page button at the leading edge.
    UIImage *prevImg = LoadScaledPngImage(kResPrevButton);
    prevBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [prevBtn setFrame:CGRectMake(listX, buttonRowY, prevImg.size.width, prevImg.size.height)];
    [prevBtn setBackgroundImage:prevImg forState:UIControlStateNormal];
    [prevBtn setExclusiveTouch:YES];
    [prevBtn addTarget:self
                  action:@selector(prevRivalList:)
        forControlEvents:UIControlEventTouchUpInside];
    [bgView addSubview:prevBtn];

    // The next-page button at the trailing edge.
    UIImage *nextImg = LoadScaledPngImage(kResNextButton);
    const CGFloat nextX = areaGap - nextImg.size.width;
    nextBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [nextBtn
        setFrame:CGRectMake(
                     (CGFloat)(int)nextX, buttonRowY, nextImg.size.width, nextImg.size.height)];
    [nextBtn setBackgroundImage:nextImg forState:UIControlStateNormal];
    [nextBtn setExclusiveTouch:YES];
    [nextBtn addTarget:self
                  action:@selector(nextRivalList:)
        forControlEvents:UIControlEventTouchUpInside];
    [bgView addSubview:nextBtn];

    // The two area buttons (country / rival), dimmed except the selected one.
    LoadScaledPngImage(kResAreaButtonSeed); // Yes, the binary loads this and discards it.
    for (int i = 0; i < 2; ++i) {
        UIImage *areaImg = LoadScaledPngImage([NSString stringWithFormat:kFmtAreaButton, i]);
        areaBtn[i] = [UIButton buttonWithType:UIButtonTypeCustom];
        const CGFloat ax = centreX + (CGFloat)(i - 1) * areaImg.size.width;
        [areaBtn[i] setFrame:CGRectMake(ax, areaButtonY, areaImg.size.width, areaImg.size.height)];
        [areaBtn[i] setBackgroundImage:areaImg forState:UIControlStateNormal];
        [areaBtn[i] setAlpha:(i == selectArea) ? 1.0 : kDimmedAlpha];
        [areaBtn[i] setExclusiveTouch:YES];
        [areaBtn[i] addTarget:self
                       action:@selector(tapArea:)
             forControlEvents:UIControlEventTouchUpInside];
        [areaBtn[i] setTag:i];
        [bgView addSubview:areaBtn[i]];
    }

    // The eight rank-icon atlases (slot 0 stays nil; slots 1-7 load "challenge_rank_icon_0N").
    iconImage[0] = nil;
    for (int i = 1; i < 8; ++i) {
        iconImage[i] = LoadScaledPngImage([NSString stringWithFormat:kFmtRankIcon, i]);
    }

    // The ten badge-digit atlases.
    for (int i = 0; i < 10; ++i) {
        iconNumImage[i] = LoadScaledPngImage([NSString stringWithFormat:kFmtRankIconPrefix, i]);
    }

    [self listDownload:dispRank size:kPageSize];
}

// Creates the spinning download indicator, centred over the whole view.
/** @ghidraAddress 0x15491c */
- (void)createIndicator {
    downloadIndicator = [[UIActivityIndicatorView alloc]
        initWithFrame:CGRectMake(0, 0, kIndicatorSide, kIndicatorSide)];
    [downloadIndicator setCenter:CGPointMake(self.frame.size.width * kDimmedAlpha,
                                             self.frame.size.height * kDimmedAlpha)];
    [downloadIndicator setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleWhiteLarge];
    [downloadIndicator setHidesWhenStopped:YES];
    [self addSubview:downloadIndicator];
    [downloadIndicator startAnimating];
}

// Places a fresh back-button image on the close button and left-aligns its content.
/** @ghidraAddress 0x15a440 */
- (void)replaceBackBtnImage {
    UIImage *img = LoadScaledPngImage(kResBackButtonAlt);
    [closeBtn setImage:img forState:UIControlStateNormal];
    [closeBtn setContentHorizontalAlignment:UIControlContentHorizontalAlignmentLeft];
}

#pragma mark - Button state

// Enables or disables every interactive control at once; when enabling, the my-rank button's own
// availability is then re-derived.
/** @ghidraAddress 0x1547e8 */
- (void)buttonEnable:(BOOL)enable {
    for (int i = 0; i < 4; ++i) {
        [diffBtn[i] setEnabled:enable];
    }
    [areaBtn[kAreaCountry] setEnabled:enable];
    [areaBtn[kAreaRival] setEnabled:enable];
    [prevBtn setEnabled:enable];
    [nextBtn setEnabled:enable];
    [myRankBtn setEnabled:enable];
    [topRankBtn setEnabled:enable];
    if (enable) {
        [self enableMyRankBtn];
    }
}

// The my-rank button is only tappable once the player has a rank.
/** @ghidraAddress 0x1567c8 */
- (void)enableMyRankBtn {
    [myRankBtn setEnabled:(myRank != -1)];
}

#pragma mark - Selection state

// Re-reads the player's rank and index for the current difficulty from the resolved track; in the
// rival area there is no personal rank, so both are cleared.
/** @ghidraAddress 0x1566f4 */
- (void)updateMyRank {
    if (targetInfo != nil) {
        myRank = [targetInfo getMyRank:selectDifficulty];
        myIndex = [targetInfo getMyIndex:selectDifficulty];
        if (selectArea == kAreaRival) {
            myIndex = -1;
            myRank = -1;
        }
    }
}

// Records which row the player selected.
/** @ghidraAddress 0x156800 */
- (void)selectListCell:(NSIndexPath *)indexPath {
    selectRankIndex = (int)indexPath.row;
}

// Switches the active difficulty: re-skins the four buttons, refreshes the personal rank, and
// reloads the page containing it.
/** @ghidraAddress 0x156838 */
- (void)setDifficulty:(int)difficulty {
    if (selectDifficulty == difficulty) {
        return;
    }
    selectDifficulty = difficulty;
    for (int i = 0; i < 4; ++i) {
        [diffBtn[i] setBackgroundImage:(i == difficulty) ? btnImage[i][0] : btnImage[i][1]
                              forState:UIControlStateNormal];
    }
    [self updateMyRank];
    [self enableMyRankBtn];
    dispRank = (myRank < 0) ? 0 : ((myRank - 1) / kPageSize) * kPageSize;
    [self listDownload:dispRank size:kPageSize];
}

// Switches the active area: swaps the title art with a fade, re-dims the two area buttons,
// refreshes the personal rank, and reloads.
/** @ghidraAddress 0x1569bc */
- (void)setArea:(int)area {
    if (selectArea == area) {
        return;
    }
    [titleView setImage:areaImage[area]];
    __weak UIImageView *weakTitleView = titleView;
    titleView.alpha = kTitleAlpha;
    [UIView animateWithDuration:kFadeDuration
                          delay:0
                        options:kFadeOptions
                     animations:^{
                       /** @ghidraAddress 0x156be0 */
                       weakTitleView.alpha = 1.0;
                     }
                     completion:nil];
    selectArea = area;
    [areaBtn[kAreaCountry] setAlpha:(area == kAreaCountry) ? 1.0 : kDimmedAlpha];
    [areaBtn[kAreaRival] setAlpha:(area == kAreaRival) ? 1.0 : kDimmedAlpha];
    [self updateMyRank];
    [self enableMyRankBtn];
    dispRank = (myRank < 0) ? 0 : ((myRank - 1) / kPageSize) * kPageSize;
    [self listDownload:dispRank size:kPageSize];
}

#pragma mark - Networking

// Cancels any in-flight request, issues a signed session request for one ranking page, locks the
// controls, shows the spinner, fades the old list out, and starts the fetch once faded.
/** @ghidraAddress 0x156c30 */
- (void)listDownload:(int)head size:(int)size {
    if (rankingDownloader != nil) {
        [rankingDownloader cancel];
        rankingDownloader = nil;
    }
    NSDictionary *post = [NSDictionary dictionaryWithObjects:@[
        targetScratchID,
        @(musicID),
        @(head),
        @(size),
        @(selectArea),
        @(selectDifficulty)
    ]
                                                     forKeys:@[
                                                         kBodyScratchIDKey,
                                                         kBodyMusicIDKey,
                                                         kBodyHeadKey,
                                                         kBodyLimitKey,
                                                         kBodyKindKey,
                                                         kBodyDifficultyKey
                                                     ]];
    rankingDownloader = [[SessionDownloader alloc] initWithURL:[ScratchUtil rankingListURL]
                                                postDictionary:post
                                                      delegate:self];
    rankingDownloader.tag = kTagRankingLoad;
    rankingDownloader.apiTag = kApiTagRankingLoad;
    [self buttonEnable:NO];
    [self createIndicator];

    __weak UITableView *weakListView = listView;
    [UIView animateWithDuration:kFadeDuration
        delay:0
        options:kFadeOptions
        animations:^{
          /** @ghidraAddress 0x156fec */
          weakListView.alpha = 0.0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x157038 */
          [self->rankingDownloader startDownloading];
        }];
}

#pragma mark - DownloaderDelegate

// Shows the shared plain alert with the given tag, message, and a localised OK button.
- (void)showPlainAlertWithDelegate:(nullable id)delegate tag:(int)tag message:(NSString *)msg {
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:kBundleKeyOK value:@"" table:nil];
    [[AlertViewManager sharedManager] makeAlert:kPlainAlertType
                                       delegate:delegate
                                            tag:tag
                                          title:@""
                                            msg:msg
                                         cancel:ok
                                        btnText:nil
                                           show:YES];
}

/** @ghidraAddress 0x157064 */
- (void)downloaderFinished:(id)downloader {
    [[UIApplication sharedApplication] endIgnoringInteractionEvents];
    NSDictionary *json = [downloader getDataInJSON];
    int status = kStatusNone;
    if (json[kKeyStatus]) {
        status = [json[kKeyStatus] intValue];
        if (status == kStatusServerError) {
            NSString *msg = [NSBundle.mainBundle localizedStringForKey:kBundleKeyServerErrorMsg
                                                                 value:@""
                                                                 table:nil];
            if (json[kKeyErrorMessage]) {
                msg = json[kKeyErrorMessage];
            }
            [self showPlainAlertWithDelegate:self tag:kSessionErrorAlertTag message:msg];
            return;
        }
        if (status == kStatusUpdateRequired) {
            if (downloadIndicator != nil) {
                [downloadIndicator stopAnimating];
                downloadIndicator = nil;
            }
            [[AlertViewManager sharedManager] showUpdateAlert];
            return;
        }
    }

    int tag = [downloader tag];
    if (tag == kTagRivalRegister) {
        [self handleRivalRegisterResponse:json status:status];
    } else if (tag == kTagRankingLoad) {
        [self handleRankingLoadResponse:json status:status];
    }
}

// The rival add/remove response: on the "already registered" code and on success take the
// dedicated paths, otherwise present the error.
- (void)handleRivalRegisterResponse:(NSDictionary *)json status:(int)status {
    if (status == kStatusAlreadyRegistered) {
        NSString *ok = [NSBundle.mainBundle localizedStringForKey:kBundleKeyOK value:@"" table:nil];
        [[AlertViewManager sharedManager] makeAlert:kPlainAlertType
                                           delegate:self
                                                tag:kAlreadyRegisteredAlertTag
                                              title:@""
                                                msg:kMsgAlreadyRegistered
                                             cancel:ok
                                            btnText:nil
                                               show:YES];
        return;
    }
    if (status == kStatusOK) {
        [self switchRivalMessageView];
        return;
    }
    NSString *msg = json[kKeyErrorMessage];
    if (!msg) {
        msg = kMsgRegisterFailed;
    }
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:kBundleKeyOK value:@"" table:nil];
    [[AlertViewManager sharedManager] makeAlert:kPlainAlertType
                                       delegate:self
                                            tag:kAddConfirmAlertTag
                                          title:@""
                                            msg:msg
                                         cancel:ok
                                        btnText:nil
                                           show:YES];
}

// The ranking-page response: on success cache the rows and personal rank, notify the delegate,
// find the player's own row, reload the table, and fade it in; on failure present the error.
- (void)handleRankingLoadResponse:(NSDictionary *)json status:(int)status {
    NSString *editorID = [EditorIDManager getKeyString:[EditorIDManager getEditorIDKey]];
    if (status != kStatusOK) {
        NSString *msg = json[kKeyErrorMessage];
        if (!msg) {
            msg = [NSBundle.mainBundle localizedStringForKey:kBundleKeyServerErrorMsg
                                                       value:@""
                                                       table:nil];
        }
        [[AlertViewManager sharedManager] makeAlert:kPlainAlertType
                                           delegate:nil
                                                tag:kPlainAlertType
                                              title:@""
                                                msg:msg
                                             cancel:kButtonYesText
                                            btnText:nil
                                               show:YES];
        rankingDownloader = nil;
        return;
    }

    // The head row's music name reflects the freshly updated tune, but only when this is the "all
    // tunes" list and the response's scratch id matches ours.
    id updated = json[kKeyUpdated];
    if (musicID == kAllTunesMusicID &&
        [targetScratchID isEqualToNumber:[ChallengeStatus sharedStatus].scratchID]) {
        if (!updated) {
            [musicNameText setText:musicDefName];
        } else {
            [musicNameText
                setText:[NSString stringWithFormat:kMusicNameUpdatedFormat, musicName, updated]];
        }
    }

    rankingList = json[kKeyRank];
    rankingTotal = [json[kKeyTotal] intValue];
    if (json[kKeyMyRank]) {
        myRank = [json[kKeyMyRank] intValue];
        if (!json[kKeyMyPosition]) {
            myIndex = myRank;
        } else {
            myIndex = [json[kKeyMyPosition] intValue];
        }
        [[ChallengeStatus sharedStatus] updateMusicRanking:musicID
                                                      diff:selectDifficulty
                                                      rank:myRank
                                                     index:myIndex];
        if ([self.aDelegate respondsToSelector:@selector(changeRanking)]) {
            [self.aDelegate performSelector:@selector(changeRanking)];
        }
    }

    pickupSlot = -1;
    for (NSUInteger i = 0; i < rankingList.count; ++i) {
        if ([editorID isEqualToString:rankingList[i][kKeyUserID]]) {
            pickupSlot = (int)i;
            break;
        }
    }
    [listView reloadData];
    if (downloadIndicator != nil) {
        [downloadIndicator stopAnimating];
        downloadIndicator = nil;
        __weak UITableView *weakListView = listView;
        [UIView animateWithDuration:kFadeDuration
            delay:0
            options:kFadeOptions
            animations:^{
              /** @ghidraAddress 0x157c00 */
              weakListView.alpha = 1.0;
            }
            completion:^(BOOL finished) {
              /** @ghidraAddress 0x157c4c */
              [self buttonEnable:YES];
              self->isNext = [json[kKeyHasNext] boolValue];
              [self->nextBtn setEnabled:(self->isNext != 0)];
              [self->prevBtn setEnabled:(self->dispRank > 0x1d)];
            }];
    }
    rankingDownloader = nil;
}

/** @ghidraAddress 0x157d90 */
- (void)downloaderError:(id)downloader {
    [[UIApplication sharedApplication] endIgnoringInteractionEvents];
    [self buttonEnable:YES];
    if (downloadIndicator != nil) {
        [downloadIndicator stopAnimating];
        downloadIndicator = nil;
    }
    NSString *msg = [NSBundle.mainBundle localizedStringForKey:kBundleKeyServerErrorMsg
                                                         value:@""
                                                         table:nil];
    int tag = [downloader tag];
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:kBundleKeyOK value:@"" table:nil];
    id delegate = self;
    int alertTag;
    if (tag == kTagRivalRegister) {
        msg = kMsgRegisterFailed;
        alertTag = kAddConfirmAlertTag;
    } else {
        alertTag = kDownloaderErrorAlertTag;
        delegate = nil;
    }
    [[AlertViewManager sharedManager] makeAlert:kPlainAlertType
                                       delegate:delegate
                                            tag:alertTag
                                          title:@""
                                            msg:msg
                                         cancel:ok
                                        btnText:nil
                                           show:YES];
}

#pragma mark - AlertViewManagerDelegate

/** @ghidraAddress 0x157fbc */
- (void)alertSelect:(NSDictionary *)info {
    (void)[info[kAlertInfoButtonMessageKey] intValue]; // Read and discarded, as in the binary.
    int tag = [info[kAlertInfoTagKey] intValue];
    if (tag == kAddConfirmAlertTag) {
        // Fade the confirm artwork out, swap it, and fade back in.
        __weak UIImageView *weakAddMessage = addMessage;
        __weak UIButton *weakAddBtn = addBtn;
        __weak UIButton *weakCancelBtn = cancelBtn;
        [UIView animateWithDuration:kFadeDuration
            delay:0
            options:kFadeOptions
            animations:^{
              /** @ghidraAddress 0x158284 */
              weakAddMessage.alpha = 0.0;
            }
            completion:^(BOOL finished) {
              /** @ghidraAddress 0x1582d0 */
              UIImage *img = LoadScaledPngImage(kResRivalRegMsg1);
              weakAddMessage.image = img;
              [UIView animateWithDuration:kFadeDuration
                                    delay:0
                                  options:kFadeOptions
                               animations:^{
                                 /** @ghidraAddress 0x158424 */
                                 weakAddMessage.alpha = 1.0;
                                 weakAddBtn.alpha = 1.0;
                                 weakCancelBtn.alpha = 1.0;
                               }
                               completion:nil];
            }];
    } else if (tag == kAlreadyRegisteredAlertTag) {
        [self selectRivalCancel:nil];
    } else if (tag == kSessionErrorAlertTag) {
        [[[ChallengeStatus sharedStatus] rootView] closeChallengeModeSessionError];
    }
}

#pragma mark - Paging actions

/** @ghidraAddress 0x1585dc */
- (void)tapDifficulty:(id)sender {
    [self setDifficulty:(int)[sender tag]];
}

/** @ghidraAddress 0x158618 */
- (void)tapArea:(id)sender {
    [self setArea:(int)[sender tag]];
}

/** @ghidraAddress 0x158654 */
- (void)tapMyRank:(id)sender {
    [self updateMyRank];
    if (myRank > 0) {
        dispRank = (myIndex < 0) ? 0 : ((myIndex - 1) / kPageSize) * kPageSize;
        [self listDownload:dispRank size:kPageSize];
    }
}

/** @ghidraAddress 0x1586f8 */
- (void)tapTopRank:(id)sender {
    dispRank = 0;
    [self listDownload:0 size:kPageSize];
}

/** @ghidraAddress 0x158718 */
- (void)prevRivalList:(id)sender {
    int prev = dispRank - kPageSize;
    if (dispRank > 0x1d) {
        dispRank = prev;
        [self listDownload:prev size:kPageSize];
        if (dispRank < 0x1f) {
            [prevBtn setEnabled:NO];
        }
    }
}

/** @ghidraAddress 0x158790 */
- (void)nextRivalList:(id)sender {
    if (isNext) {
        int next = dispRank + kPageSize;
        dispRank = next;
        [self listDownload:next size:kPageSize];
        if (rankingTotal < dispRank + kPageSize) {
            [nextBtn setEnabled:NO];
        }
    }
}

#pragma mark - Navigation

/** @ghidraAddress 0x15859c */
- (void)tapClose:(id)sender {
    [self.aDelegate closeRanking];
}

/** @ghidraAddress 0x158cec */
- (void)tapCloseBtn:(id)sender {
    [[AudioManager sharedManager] playSeResFile:kSeChallengeCancel inDirectory:nil];
    if (rankingDownloader != nil) {
        [rankingDownloader cancel];
        rankingDownloader = nil;
    }
    [self.aDelegate closeRanking];
}

#pragma mark - UITableViewDataSource / UITableViewDelegate

/** @ghidraAddress 0x158834 */
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *identifier = [NSString stringWithFormat:kBoxFormat, kCellReuseIdentifier];
    ChallengeRankingListViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[ChallengeRankingListViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                   reuseIdentifier:identifier];
    }
    cell.tag = indexPath.row;
    return cell;
}

/** @ghidraAddress 0x15893c */
- (void)tableView:(UITableView *)tableView
      willDisplayCell:(ChallengeRankingListViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath {
    UIImage *plate = (indexPath.row & 1) ? plateBgImage1 : plateBgImage0;
    if (indexPath.row == pickupSlot) {
        plate = plateBgPickup;
    }
    NSDictionary *record = rankingList[indexPath.row];
    NSString *rank = [NSString stringWithFormat:kBoxFormat, record[kKeyRank]];
    NSString *name = [NSString stringWithFormat:kBoxFormat, record[kKeyName]];
    NSString *score = [NSString stringWithFormat:kBoxFormat, record[kKeyScore]];
    [cell setRivalInfo:plate rank:rank name:name score:score];

    int userType = [record[kKeyUserType] intValue];
    int prizeCount = [record[kKeyPrizeCount] intValue];
    int badge = (userType == kUserTypePrize) ? prizeCount : 0;
    if (badge > kMaxBadgeCount) {
        badge = kMaxBadgeCount;
    }
    UIImage *digit1 = iconNumImage[badge % 10];
    UIImage *digit2 = iconNumImage[badge / 10];
    // A badge below 10 hides the tens digit; a zero badge hides both.
    if (badge + 9U < 0x13) {
        if (badge == 0) {
            digit2 = nil;
            digit1 = nil;
        } else {
            digit2 = nil;
        }
    }
    [cell setRivalIcon:iconImage[userType] digit1Image:digit1 digit2Image:digit2];
}

/** @ghidraAddress 0x158dd4 */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *rowID = rankingList[indexPath.row][kKeyUserID];
    if (![rowID isEqualToString:[[ChallengeStatus sharedStatus] mySearchID]]) {
        [listView deselectRowAtIndexPath:indexPath animated:YES];
        [self createRivalAddMessage:(int)indexPath.row];
        [self addSubview:rivalCover];
        [self addSubview:rivalAddView];
        __weak UIView *weakRivalAddView = rivalAddView;
        __weak UIView *weakRivalCover = rivalCover;
        rivalAddView.alpha = 0;
        rivalCover.alpha = 0;
        [UIView animateWithDuration:kFadeDuration
                              delay:0
                            options:kFadeOptions
                         animations:^{
                           /** @ghidraAddress 0x15918c */
                           weakRivalAddView.alpha = 1.0;
                           weakRivalCover.alpha = 1.0;
                         }
                         completion:nil];
    } else {
        NSString *ok = [NSBundle.mainBundle localizedStringForKey:kBundleKeyOK value:@"" table:nil];
        [[AlertViewManager sharedManager] makeAlert:kPlainAlertType
                                           delegate:nil
                                                tag:kPlainAlertType
                                              title:nil
                                                msg:kMsgIsYourself
                                             cancel:ok
                                            btnText:nil
                                               show:YES];
    }
}

/** @ghidraAddress 0x158d9c */
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return cellHeight;
}

/** @ghidraAddress 0x158dbc */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return rankingList.count;
}

/** @ghidraAddress 0x158db4 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

#pragma mark - Rival add overlay

// Builds the rival-add overlay for the tapped row: a centred panel over the list carrying the
// rival's id and name, plus the yes/no/end buttons, all laid out at the per-idiom metrics.
//
// Every layout constant is recovered from the disassembly at 0x159b34.
//
/** @ghidraAddress 0x159b34 */
- (void)createRivalAddMessage:(int)index {
    NSDictionary *record = rankingList[index];
    selectedRivalID = record[kKeyUserID];
    BOOL isPad = [JubeatAppDelegate appDelegate].isPad;

    // The scale factor applied to every panel metric on the phone.
    const CGFloat scale = isPad ? 1.0 : 0.5;
    UIImage *sheetImg = LoadScaledPngImage(kResSheetRival);

    // The panel origin and size, centred in the view.
    const int panelX = isPad ? 0xc : 5;
    const int panelY = isPad ? 4 : 6;
    const CGFloat panelWidth = sheetImg.size.width + (CGFloat)((float)panelX * -1.5);
    rivalAddView =
        [[UIView alloc] initWithFrame:CGRectMake(panelX, panelY, panelWidth, sheetImg.size.height)];
    [rivalAddView setCenter:CGPointMake(self.frame.size.width * kDimmedAlpha,
                                        self.frame.size.height * kDimmedAlpha)];

    // The panel background, offset by half the inset.
    addBgView = [[UIImageView alloc] initWithImage:sheetImg];
    [addBgView setFrame:CGRectMake((CGFloat)(int)-(panelX >> 1),
                                   (CGFloat)-panelY,
                                   sheetImg.size.width,
                                   sheetImg.size.height)];
    [rivalAddView addSubview:addBgView];

    // The rival-id label, top-centred.
    const CGFloat idX = isPad ? 20.0 : 10.0;  // @ghidraAddress 0x291e30 / 0x2932c8
    const CGFloat idY = isPad ? 70.0 : 44.0;  // @ghidraAddress 0x28f6a0 / 0x291e30
    const CGFloat labelWidth = scale * 352.0; // @ghidraAddress 0x2932d0
    const CGFloat labelHeight = scale * 38.0; // @ghidraAddress 0x292ae4
    rivalID = [[UILabel alloc] initWithFrame:CGRectMake(idX, idY, labelWidth, labelHeight)];
    [rivalID setTextAlignment:NSTextAlignmentCenter];
    [rivalID setFont:[UIFont systemFontOfSize:(scale * 24.0)]];
    [rivalID setText:selectedRivalID];
    [rivalAddView addSubview:rivalID];

    // The registration message image, centred horizontally near the top.
    UIImage *msgImg = LoadScaledPngImage(kResRivalRegMsg1);
    addMessage = [[UIImageView alloc] initWithImage:msgImg];
    [addMessage setCenter:CGPointMake(rivalAddView.frame.size.width * kDimmedAlpha,
                                      scale * 76.0)]; // @ghidraAddress 0x28f8f8
    [rivalAddView addSubview:addMessage];

    // The rival-name label, below the id.
    const CGFloat nameX = scale * 44.0; // @ghidraAddress 0x2932d4
    rivalName =
        [[UILabel alloc] initWithFrame:CGRectMake(nameX, scale * 20.0, labelWidth, labelHeight)];
    [rivalName setTextAlignment:NSTextAlignmentCenter];
    [rivalName setFont:[UIFont systemFontOfSize:(scale * 24.0)]];
    [rivalName setText:record[kKeyName]];
    [rivalAddView addSubview:rivalName];

    // The "no" (cancel) button, leading half of the button row.
    UIImage *noImg = LoadScaledPngImage(kResButtonNo);
    const CGFloat buttonY = scale * 210.0; // @ghidraAddress 0x291dc8
    cancelBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [cancelBtn
        setFrame:CGRectMake((rivalAddView.frame.size.width * kDimmedAlpha - noImg.size.width) -
                                10.0,
                            buttonY,
                            noImg.size.width,
                            noImg.size.height)];
    [cancelBtn setBackgroundImage:noImg forState:UIControlStateNormal];
    [cancelBtn addTarget:self
                  action:@selector(selectRivalCancel:)
        forControlEvents:UIControlEventTouchUpInside];
    [cancelBtn setExclusiveTouch:YES];
    [rivalAddView addSubview:cancelBtn];

    // The "yes" (add) button, trailing half of the button row.
    UIImage *yesImg = LoadScaledPngImage(kResButtonYes);
    addBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [addBtn setFrame:CGRectMake(rivalAddView.frame.size.width * kDimmedAlpha + 10.0,
                                buttonY,
                                yesImg.size.width,
                                yesImg.size.height)];
    [addBtn setBackgroundImage:yesImg forState:UIControlStateNormal];
    [addBtn addTarget:self
                  action:@selector(selectRivalAdd:)
        forControlEvents:UIControlEventTouchUpInside];
    [addBtn setExclusiveTouch:YES];
    [rivalAddView addSubview:addBtn];

    // The "end"/ok button, centred and initially hidden; it reuses the cancel action.
    UIImage *okImg = LoadScaledPngImage(kResButtonOk);
    endBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [endBtn setFrame:CGRectMake(rivalAddView.frame.size.width * kDimmedAlpha -
                                    okImg.size.width * kDimmedAlpha,
                                buttonY,
                                okImg.size.width,
                                okImg.size.height)];
    [endBtn setBackgroundImage:okImg forState:UIControlStateNormal];
    [endBtn addTarget:self
                  action:@selector(selectRivalCancel:)
        forControlEvents:UIControlEventTouchUpInside];
    [endBtn setAlpha:0];
    [endBtn setExclusiveTouch:YES];
    [rivalAddView addSubview:endBtn];
}

// Confirms the rival addition: fades the confirm controls out, POSTs the registration, locks
// input, swaps the message artwork, and fades it back in.
/** @ghidraAddress 0x159514 */
- (void)selectRivalAdd:(id)sender {
    __weak UIImageView *weakAddMessage = addMessage;
    __weak UIButton *weakAddBtn = addBtn;
    __weak UIButton *weakCancelBtn = cancelBtn;
    [UIView animateWithDuration:kFadeDuration
        delay:0
        options:kFadeOptions
        animations:^{
          /** @ghidraAddress 0x1596fc */
          weakAddMessage.alpha = 0.0;
          weakAddBtn.alpha = 0.0;
          weakCancelBtn.alpha = 0.0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x1597f4 */
          NSDictionary *post =
              [NSDictionary dictionaryWithObjects:@[ self->selectedRivalID, @YES ]
                                          forKeys:@[ kBodyRivalIDKey, kBodyIsAddKey ]];
          SessionDownloader *downloader =
              [[SessionDownloader alloc] initWithURL:[ScratchUtil registRivalURL]
                                      postDictionary:post
                                            delegate:self];
          downloader.tag = kTagRivalRegister;
          downloader.apiTag = kApiTagRivalRegister;
          [downloader startDownloading];
          [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
          UIImage *img = LoadScaledPngImage(kResRivalRegMsg2);
          weakAddMessage.image = img;
          [UIView animateWithDuration:kFadeDuration
                                delay:0
                              options:kFadeOptions
                           animations:^{
                             /** @ghidraAddress 0x159a8c */
                             weakAddMessage.alpha = 1.0;
                           }
                           completion:nil];
        }];
}

// Cancels the rival-add overlay: fades the panel and its cover out, then removes the panel.
/** @ghidraAddress 0x159260 */
- (void)selectRivalCancel:(id)sender {
    __weak UIView *weakRivalAddView = rivalAddView;
    __weak UIView *weakRivalCover = rivalCover;
    [UIView animateWithDuration:kFadeDuration
        delay:0
        options:kFadeOptions
        animations:^{
          /** @ghidraAddress 0x1593d8 */
          weakRivalAddView.alpha = 0.0;
          weakRivalCover.alpha = 0.0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x15949c */
          // Asymmetric teardown: rivalAddView is removed and its ivar cleared, but rivalCover is
          // only removed and kept for reuse.
          [self->rivalAddView removeFromSuperview];
          self->rivalAddView = nil;
          [self->rivalCover removeFromSuperview];
        }];
}

// After a successful registration: fades the message out, swaps the completion artwork with the
// end button visible, and fades both back in.
/** @ghidraAddress 0x15a4b4 */
- (void)switchRivalMessageView {
    __weak UIImageView *weakAddMessage = addMessage;
    __weak UIButton *weakEndBtn = endBtn;
    [UIView animateWithDuration:kFadeDuration
        delay:0
        options:kFadeOptions
        animations:^{
          /** @ghidraAddress 0x15a620 */
          weakAddMessage.alpha = 0.0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x15a66c */
          UIImage *img = LoadScaledPngImage(kResRivalRegMsg3);
          weakAddMessage.image = img;
          [UIView animateWithDuration:kFadeDuration
                                delay:0
                              options:kFadeOptions
                           animations:^{
                             /** @ghidraAddress 0x15a798 */
                             weakAddMessage.alpha = 1.0;
                             weakEndBtn.alpha = 1.0;
                           }
                           completion:nil];
        }];
}

@end
