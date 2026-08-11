#import "ChallengeModeRootView.h"

#import "AudioManager.h"
#import "BFCodec.h"
#import "ChallengeLoginMessageView.h"
#import "ChallengeMenuRootView.h"
#import "ChallengeStatus.h"
#import "ChallengeStatusView.h"
#import "CubePurchaseView.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"
#import "KUnzip.h"
#import "LabUtilities.h"
#import "MusicSelectViewController.h"
#import "ScratchBoardView.h"
#import "ScratchCompleteView.h"
#import "ScratchInfo.h"
#import "ScratchUtil.h"
#import "SessionDownloader.h"
#import "SystemUtilities.h"
#import "TuneInfo.h"

// The 0.2 s animation duration is a __const literal-pool slot, not an exported global; the binary
// loads it inline at each animation call. Two distinct pool slots both hold 0.2: 0x28f240 is used
// by the fade at 0x431..., and 0x28e040 by the menu/scratch animations and the 0.2 scale.
static const double kAnimDuration020 = 0.2;    // @ghidraAddress 0x28f240
static const double kAnimDuration020Alt = 0.2; // @ghidraAddress 0x28e040

@implementation ChallengeModeRootView {
    UIImageView *bgImageView;
    UIButton *closeBtn;
    ScratchBoardView *scratchBoard;
    ChallengeStatusView *statusView;
    ScratchMusicDetailView *detailView;
    ChallengeRankingListView *rankingView;
    ChallengeLoginMessageView *loginMessage;
    ChallengeLoginInformationView *loginInformation;
    ScratchView *selectedView;
    UIButton *menuBtn;
    ChallengeMenuRootView *menuView;
    BOOL bOpenTotalRank;
    UIButton *totalRankingBtn;
    UIButton *lineupBtn;
    ChallengeLineupView *lineupView;
    CubePurchaseView *cubePurchaseView;
    ScratchCompleteView *completeView;
    UIView *coverView;
    UIGestureRecognizer *coverGesture;
    UIView *modalCoverView;
    NSTimer *refreshTimer;
    BOOL isPad;
    BOOL bVerifyPurchase;
    BOOL bScratchEnable;
    BOOL bDetailOpen;
    BOOL bFirstPanelCheck;
    BOOL bDispLoginMessage;
    BOOL bDispMissionMessage;
    BOOL bDownloadItem;
    NSMutableArray *imageDLTasks;
    NSDictionary *currentDownload;
    ChallengeNameSettingView *nameSettingView;
    UIImageView *checkMarkImg;
    UIImageView *playExplain;
    UILabel *baseConsumeCoin;
    UILabel *consumeCoin;
    NSDictionary *achieveSendDict;
    NSInteger movePackID;
}

@synthesize modalDialog = _modalDialog;

- (instancetype)init {
    self = [super initWithFrame:GetMainScreenBounds()];
    if (self) {
        [self setOpaque:NO];
        [self.layer setDoubleSided:NO];
        self.backgroundColor = [UIColor colorWithWhite:0.6 alpha:1.0]; // @ghidraAddress 0x28f230

        bOpenTotalRank = NO;
        bFirstPanelCheck = NO;
        bDownloadItem = NO;
        bDispLoginMessage = NO;

        isPad = JubeatAppDelegate.appDelegate.isPad;
        CGFloat phoneScreenRate = [[ChallengeStatus sharedStatus] phoneScreenRate];

        float scale =
            isPad ? 1.0f : phoneScreenRate * 0.4166666567325592f; // @ghidraAddress 0x28f898

        UIImage *bgImage = LoadScaledPngImage(@"scratch_bg");
        bgImageView = [[UIImageView alloc] initWithImage:bgImage];
        if (!isPad) {
            [bgImageView setFrame:CGRectMake(0,
                                             0,
                                             phoneScreenRate * bgImage.size.width,
                                             phoneScreenRate * bgImage.size.height)];
        }
        [self addSubview:bgImageView];

        UIImage *closeBtnImage = LoadScaledPngImage(@"scratch_btn_close");
        CGFloat screenWidth = GetMainScreenBounds().size.width;
        CGFloat screenHeight = GetMainScreenBounds().size.height;
        int closeBtnX = (int)(screenWidth - closeBtnImage.size.width - (int)(scale * 12.0));
        double closeBtnY = isPad ? 10.0 : 5.0;
        closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [closeBtn setFrame:CGRectMake(closeBtnX,
                                      closeBtnY,
                                      closeBtnImage.size.width,
                                      closeBtnImage.size.height)];
        [closeBtn addTarget:self
                      action:@selector(closeChallengeMode:)
            forControlEvents:UIControlEventTouchUpInside];
        [closeBtn setBackgroundImage:closeBtnImage forState:UIControlStateNormal];
        [closeBtn setExclusiveTouch:YES];
        [self addSubview:closeBtn];

        UIImage *menuBtnImage = LoadScaledPngImage(@"scratch_btn_menu");
        int menuBtnX = (int)(closeBtnX - ((int)(scale * 12.0) + menuBtnImage.size.width));
        double menuBtnY = isPad ? 10.0 : 5.0;
        menuBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [menuBtn
            setFrame:CGRectMake(
                         menuBtnX, menuBtnY, menuBtnImage.size.width, menuBtnImage.size.height)];
        [menuBtn addTarget:self
                      action:@selector(tapMenuBtn:)
            forControlEvents:UIControlEventTouchUpInside];
        [menuBtn setBackgroundImage:menuBtnImage forState:UIControlStateNormal];
        [menuBtn setExclusiveTouch:YES];
        [self addSubview:menuBtn];

        UIImage *checkMarkImage = LoadScaledPngImage(@"challenge_menu_mark");
        checkMarkImg = [[UIImageView alloc] initWithImage:checkMarkImage];
        double checkMarkX = menuBtn.frame.size.width - checkMarkImage.size.width;
        double checkMarkY = menuBtn.frame.size.height / -3.0;
        [checkMarkImg setFrame:CGRectMake(checkMarkX,
                                          checkMarkY,
                                          checkMarkImage.size.width,
                                          checkMarkImage.size.height)];
        [self setNotificateImage];
        [menuBtn addSubview:checkMarkImg];

        UIImage *scratchSheetImage = LoadScaledPngImage(@"scratch_sheet");
        int boardWidth, boardHeight, boardX, boardY;
        if (isPad) {
            boardWidth = (int)(scratchSheetImage.size.width);
            boardHeight = (int)(scratchSheetImage.size.height);
            boardX = (int)((screenWidth - boardWidth) * 0.5);
            boardY = (int)((screenHeight - boardHeight) -
                           (screenWidth - scratchSheetImage.size.width) * 0.5);
        } else {
            boardWidth = (int)(phoneScreenRate * scratchSheetImage.size.width);
            boardHeight = (int)(phoneScreenRate * scratchSheetImage.size.height);
            boardX = (int)((screenWidth - boardWidth) * 0.5);
            boardY = (int)((screenHeight - boardHeight) * 0.5);
            int deviceType = (int)JubeatAppDelegate.appDelegate.deviceType;
            if (deviceType == 1) {
                boardY += 22;
            }
        }
        scratchBoard = [[ScratchBoardView alloc]
            initWithFrame:CGRectMake(boardX, boardY, boardWidth, boardHeight)];
        [scratchBoard setDelegate:self];
        [self addSubview:scratchBoard];

        double detailWidth = isPad ? 600.0 : 320.0;  // @ghidraAddress 0x28f8b0
        double detailHeight = isPad ? 600.0 : 302.0; // @ghidraAddress 0x28f8c0
        detailView = [[ScratchMusicDetailView alloc]
            initWithFrame:CGRectMake(0, 0, detailWidth, detailHeight)];
        [detailView setCenter:CGPointMake(screenWidth * 0.5, screenHeight * 0.5)];
        [detailView setADelegate:self];

        double statusY, statusX, statusWidth, statusHeight;
        if (isPad) {
            statusY = 9.0;
            statusX = 14.0;
            statusWidth = (int)(scale * 452.0); // @ghidraAddress 0x28f89c
            statusHeight = 56.0;                // @ghidraAddress 0x28f878
        } else {
            statusY = 5.0;
            statusX = (double)(scale * 7.0);
            statusWidth = (int)(phoneScreenRate * 60.0);  // @ghidraAddress 0x28f8a0
            statusHeight = (int)(phoneScreenRate * 60.0); // @ghidraAddress 0x28f8a0
        }
        statusView = [[ChallengeStatusView alloc]
            initWithFrame:CGRectMake(statusX, statusY, statusWidth, statusHeight)];
        [statusView setUserInteractionEnabled:YES];
        [statusView setADelegate:self];
        [self addSubview:statusView];

        UIImage *lineupBtnImage = LoadScaledPngImage(@"scratch_btn_list");
        double lineupX, lineupY;
        if (isPad) {
            lineupX = (double)boardX + 16.0;
            lineupY = (double)((double)boardY + 732.0 - 100.0 +
                               16.0); // @ghidraAddress 0x28f880, 0x28f3f0
        } else {
            lineupX = (double)boardX -
                      (double)((double)(phoneScreenRate * lineupBtnImage.size.width) -
                               (double)(phoneScreenRate * 312.0)); // @ghidraAddress 0x28f888
            lineupY = (double)boardY + (double)(phoneScreenRate * (100.0 - 312.0) *
                                                0.5); // @ghidraAddress 0x28f3f0, 0x28f888
        }
        lineupBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [lineupBtn setBackgroundImage:lineupBtnImage forState:UIControlStateNormal];
        [lineupBtn setFrame:CGRectMake((int)lineupX,
                                       (int)lineupY,
                                       phoneScreenRate * lineupBtnImage.size.width,
                                       phoneScreenRate * lineupBtnImage.size.height)];
        [lineupBtn addTarget:self
                      action:@selector(tapLineupBtn:)
            forControlEvents:UIControlEventTouchUpInside];
        [lineupBtn setExclusiveTouch:YES];
        [self addSubview:lineupBtn];

        UIImage *totalRankingBtnImage = LoadScaledPngImage(@"scratch_btn_allranking");
        double totalRankingY = isPad ? 20.0 : 5.0;
        double totalRankingX =
            (double)((int)lineupX -
                     (totalRankingY + phoneScreenRate * totalRankingBtnImage.size.width));
        totalRankingBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [totalRankingBtn setBackgroundImage:totalRankingBtnImage forState:UIControlStateNormal];
        [totalRankingBtn setFrame:CGRectMake((int)totalRankingX,
                                             (int)lineupY,
                                             phoneScreenRate * totalRankingBtnImage.size.width,
                                             phoneScreenRate * totalRankingBtnImage.size.height)];
        [totalRankingBtn addTarget:self
                            action:@selector(tapRankingBtn:)
                  forControlEvents:UIControlEventTouchUpInside];
        [totalRankingBtn setExclusiveTouch:YES];
        [self addSubview:totalRankingBtn];

        int consumePlayCoin = [[ChallengeStatus sharedStatus] consumePlayCoin];

        UIImage *playExplainImage = LoadScaledPngImage(@"scratch_play_exp");
        double playExplainOffset = isPad ? 34.0 : 5.0; // @ghidraAddress 0x28f648
        double playExplainX =
            totalRankingX - (playExplainOffset + phoneScreenRate * playExplainImage.size.width);
        double playExplainY =
            lineupY +
            (phoneScreenRate * totalRankingBtnImage.size.height - playExplainOffset) * 0.5;
        playExplain = [[UIImageView alloc] initWithFrame:CGRectMake((int)playExplainX,
                                                                    (int)playExplainY,
                                                                    playExplainImage.size.width,
                                                                    playExplainOffset)];
        [playExplain setImage:playExplainImage];
        [self addSubview:playExplain];

        UIFont *smallFont = [UIFont boldSystemFontOfSize:isPad ? 18.0 : 9.0];
        UIFont *largeFont = [UIFont boldSystemFontOfSize:isPad ? 24.0 : 12.0];

        double labelWidth = playExplainImage.size.width * 0.5;
        double labelHeight = 24.0 * 0.5;
        baseConsumeCoin = [[UILabel alloc]
            initWithFrame:CGRectMake(labelWidth, labelHeight, labelWidth, labelHeight)];
        [baseConsumeCoin setFont:largeFont];
        [baseConsumeCoin setText:@"10"];
        [playExplain addSubview:baseConsumeCoin];

        if (consumePlayCoin < 10) {
            NSDictionary *strikeAttributes =
                [NSDictionary dictionaryWithObjects:@[ @9, UIColor.redColor ]
                                            forKeys:@[
                                                NSStrikethroughStyleAttributeName,
                                                NSStrikethroughColorAttributeName
                                            ]];
            baseConsumeCoin.attributedText =
                [[NSAttributedString alloc] initWithString:@"10" attributes:strikeAttributes];

            double consumeX = baseConsumeCoin.frame.origin.x;
            double consumeY = baseConsumeCoin.frame.origin.y;
            if (isPad) {
                consumeX += playExplainImage.size.width * 0.5;
            } else {
                consumeY += labelHeight * 0.5;
            }
            consumeCoin = [[UILabel alloc]
                initWithFrame:CGRectMake(consumeX, consumeY, labelWidth, labelHeight)];
            [consumeCoin setFont:largeFont];
            [consumeCoin setText:[NSString stringWithFormat:@"%d", consumePlayCoin]];
            [playExplain addSubview:consumeCoin];
        } else {
            [baseConsumeCoin setText:[NSString stringWithFormat:@"%d", consumePlayCoin]];
        }

        coverView = [[UIView alloc] initWithFrame:GetMainScreenBounds()];
        [coverView setOpaque:NO];
        coverView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.4]; // @ghidraAddress 0x28f2c0
        coverGesture = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                               action:@selector(closeView)];
        [coverView addGestureRecognizer:coverGesture];

        modalCoverView = [[UIView alloc] initWithFrame:GetMainScreenBounds()];
        [modalCoverView setOpaque:NO];
        modalCoverView.backgroundColor = [UIColor colorWithWhite:0
                                                           alpha:0.4]; // @ghidraAddress 0x28f2c0

        BOOL isPad2 = JubeatAppDelegate.appDelegate.isPad;
        double dialogWidth, dialogHeight;
        if (isPad2) {
            dialogWidth = 400.0;  // @ghidraAddress 0x28f2e0
            dialogHeight = 300.0; // @ghidraAddress 0x28f2d0
        } else {
            dialogWidth = 300.0;  // @ghidraAddress 0x28f2d0
            dialogHeight = 270.0; // @ghidraAddress 0x28f2d8
        }
        _modalDialog =
            [[StoreDialogView alloc] initWithFrame:CGRectMake(0, 0, dialogWidth, dialogHeight)];
        self.modalDialog.labelMessage.font = [UIFont systemFontOfSize:isPad2 ? 18.0 : 16.0];
        self.modalDialog.center = CGPointMake(screenWidth * 0.5, screenHeight * 0.5);
        [self.modalDialog.progressView setProgress:0];
        [self.modalDialog layout:0];
        [modalCoverView addSubview:self.modalDialog];

        bScratchEnable = YES;

        self.transform = CGAffineTransformMakeTranslation(0, -screenHeight);

        [[ChallengeStatus sharedStatus] setChallengeRootView:self];
    }
    return self;
}

#pragma mark - Cluster A (0x68f60 - 0x6abbc)

- (NSString *)soundName:(NSString *)name {
    // The sound-effect resource name is prefixed per current theme.
    switch (JubeatAppDelegate.appDelegate.currentTheme) {
    case JubeatThemeReflecBeatPlus:
        return [NSString stringWithFormat:@"SD_RPL_%@", name];
    case JubeatThemeKnit:
        return [NSString stringWithFormat:@"SD_KNT_%@", name];
    default:
        return [NSString stringWithFormat:@"SD_%@", name];
    }
}

- (void)showLoginMessage {
    NSString *myName = ChallengeStatus.sharedStatus.myName;
    if (myName != nil && [myName isEqualToString:@""]) {
        // The player has an account but no name yet: present the name-setting sheet.
        [self showMenuCoverView];
        nameSettingView = [[ChallengeNameSettingView alloc] initWithFrame:self.bounds
                                                               backEnable:NO];
        [nameSettingView setADelegate:self];
        [self addSubview:nameSettingView];
        __weak ChallengeNameSettingView *weakView = nameSettingView;
        nameSettingView.alpha = 0;
        [UIView animateWithDuration:kAnimDuration020Alt
            delay:0
            options:UIViewAnimationOptionCurveLinear
            animations:^{
              /** @ghidraAddress 0x69c78 */
              weakView.alpha = 1.0;
            }
            completion:^(BOOL finished) {
              /** @ghidraAddress 0x69cc4 */
              (void)finished;
            }];
        return;
    }
    if (ChallengeStatus.sharedStatus.informationURL != nil) {
        [self showMenuCoverView];
        loginInformation = [[ChallengeLoginInformationView alloc]
            initWithFrame:self.bounds
                  dispURL:ChallengeStatus.sharedStatus.informationURL
                  btnType:0];
        [loginInformation setADelegate:self];
        loginInformation.bIndependMenu = YES;
        [self addSubview:loginInformation];
        __weak ChallengeLoginInformationView *weakView = loginInformation;
        loginInformation.alpha = 0;
        [UIView animateWithDuration:kAnimDuration020Alt
            delay:0
            options:UIViewAnimationOptionCurveLinear
            animations:^{
              /** @ghidraAddress 0x69cc8 */
              weakView.alpha = 1.0;
            }
            completion:^(BOOL finished) {
              /** @ghidraAddress 0x69d14 */
              (void)finished;
            }];
        [ChallengeStatus.sharedStatus saveInformationURL];
        return;
    }
    if (ChallengeStatus.sharedStatus.personalInfoURL != nil) {
        [self showMenuCoverView];
        loginInformation = [[ChallengeLoginInformationView alloc]
            initWithFrame:self.bounds
                  dispURL:ChallengeStatus.sharedStatus.personalInfoURL
                  btnType:0];
        [loginInformation setADelegate:self];
        loginInformation.bIndependMenu = YES;
        [self addSubview:loginInformation];
        __weak ChallengeLoginInformationView *weakView = loginInformation;
        loginInformation.alpha = 0;
        [UIView animateWithDuration:kAnimDuration020Alt
            delay:0
            options:UIViewAnimationOptionCurveLinear
            animations:^{
              /** @ghidraAddress 0x69d18 */
              weakView.alpha = 1.0;
            }
            completion:^(BOOL finished) {
              /** @ghidraAddress 0x69d64 */
              (void)finished;
            }];
        [ChallengeStatus.sharedStatus savePersionalInformationURL];
        return;
    }
    if ([NSUserDefaults.standardUserDefaults objectForKey:@"PrefChallengeHowtoURL"] != nil) {
        // The how-to URL is already remembered: keep it fresh, then show the login message.
        if (ChallengeStatus.sharedStatus.howtoURL != nil) {
            [NSUserDefaults.standardUserDefaults setObject:ChallengeStatus.sharedStatus.howtoURL
                                                    forKey:@"PrefChallengeHowtoURL"];
        }
        if (bDispLoginMessage) {
            return;
        }
        if (ChallengeStatus.sharedStatus.nailNum <= 0) {
            return;
        }
        if (ChallengeStatus.sharedStatus.scratchablePanelNum < 1) {
            return;
        }
        loginMessage = [[ChallengeLoginMessageView alloc]
            initWithFrame:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)
               scratchNum:ChallengeStatus.sharedStatus.nailNum];
        [loginMessage setADelegate:self];
        [self showMenuCoverView];
        [self addSubview:loginMessage];
        __weak ChallengeLoginMessageView *weakView = loginMessage;
        loginMessage.alpha = 0;
        [UIView animateWithDuration:kAnimDuration020 // @ghidraAddress 0x28f240
            delay:0.10000000149011612                // @ghidraAddress 0x28f2b8
            options:UIViewAnimationOptionCurveLinear
            animations:^{
              /** @ghidraAddress 0x69db8 */
              weakView.alpha = 1.0;
            }
            completion:^(BOOL finished) {
              /** @ghidraAddress 0x69e04 */
              (void)finished;
            }];
        return;
    }
    // First time: seed the how-to URL default, then present the how-to sheet.
    [self showMenuCoverView];
    NSString *howtoURL = ChallengeStatus.sharedStatus.howtoURL;
    if (howtoURL == nil) {
        howtoURL = @"https://agx11.s.konaminet.jp/agx/web/info/iOS/v1/Scratch/";
    }
    [NSUserDefaults.standardUserDefaults setObject:howtoURL forKey:@"PrefChallengeHowtoURL"];
    loginInformation = [[ChallengeLoginInformationView alloc] initWithFrame:self.bounds
                                                                    dispURL:howtoURL
                                                                    btnType:0];
    [loginInformation setADelegate:self];
    [self addSubview:loginInformation];
    __weak ChallengeLoginInformationView *weakView = loginInformation;
    loginInformation.alpha = 0;
    [UIView animateWithDuration:kAnimDuration020Alt
        delay:0
        options:UIViewAnimationOptionCurveLinear
        animations:^{
          /** @ghidraAddress 0x69d68 */
          weakView.alpha = 1.0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x69db4 */
          (void)finished;
        }];
}

- (BOOL)checkArtworkDownload {
    NSMutableArray *tasks = [[NSMutableArray alloc] init];
    int count = (int)ChallengeStatus.sharedStatus.scratchLineUp.count;
    for (int i = 0; i < count; ++i) {
        NSDictionary *item = ChallengeStatus.sharedStatus.scratchLineUp[i];
        UIImage *image = [UIImage
            imageWithContentsOfFile:[ScratchUtil
                                        imagePathForMusicID:[[item objectForKey:@"music_id"]
                                                                intValue]]];
        if (image == nil) {
            [tasks addObject:item];
        } else {
            [ChallengeStatus.sharedStatus setLineupImage:image
                                                 musicID:[item objectForKey:@"music_id"]];
        }
    }
    if (tasks.count != 0) {
        imageDLTasks = [NSMutableArray arrayWithArray:tasks];
    }
    return tasks.count == 0;
}

- (void)imageDownload {
    if (imageDLTasks != nil && imageDLTasks.count != 0) {
        NSDictionary *task = imageDLTasks[0];
        NSURL *url = [NSURL URLWithString:[task objectForKey:@"image_url"]];
        Downloader *downloader = [[Downloader alloc] initWithURL:url delegate:self];
        downloader.tag = 7;
        [downloader startDownloading];
        currentDownload = task;
    }
}

- (void)setNotificateImage {
    checkMarkImg.hidden = ChallengeStatus.sharedStatus.presentNum < 1;
}

- (void)enterChallengeView:(BOOL)animated {
    // -checkArtworkDownload returns YES when nothing is missing, so this flag is "downloads
    // needed".
    BOOL downloadNeeded = ![self checkArtworkDownload];
    if (downloadNeeded) {
        [self showCoverView];
        [self showModalDialog:self];
        self.modalDialog.labelMessage.text = @"イメージデータをダウンロード中です";
        self.modalDialog.tag = 1;
        self.modalDialog.buttonAbort.hidden = YES;
        [self imageDownload];
    }
    AudioManager *audioManager = AudioManager.sharedManager;
    if (animated) {
        [audioManager playSeResFile:@"SD_CHALLENGE_OPEN" inDirectory:nil];
        // Start off-screen above the top edge, then animate back down to the identity transform.
        self.transform =
            CGAffineTransformMakeTranslation(0, -UIScreen.mainScreen.bounds.size.height);
        [UIView animateWithDuration:kAnimDuration020 // @ghidraAddress 0x28f240
            delay:0.10000000149011612                // @ghidraAddress 0x28f2b8
            options:UIViewAnimationOptionCurveLinear
            animations:^{
              /** @ghidraAddress 0x6a61c */
              self.transform = CGAffineTransformMakeTranslation(0, 0);
            }
            completion:^(BOOL finished) {
              /** @ghidraAddress 0x6a68c */
              (void)finished;
              AudioManager *manager = AudioManager.sharedManager;
              [manager loadBgmResAAC:@"SD_BGM_SCRATCH" inDirectory:nil];
              [manager startBgm:YES fadeTime:2.0];
              if (!downloadNeeded) {
                  [self showLoginMessage];
              }
            }];
    } else {
        [audioManager loadBgmResAAC:@"SD_BGM_SCRATCH" inDirectory:nil];
        [audioManager startBgm:YES fadeTime:kAnimDuration020]; // @ghidraAddress 0x28f240
        self.transform = CGAffineTransformMakeTranslation(0, 0);
        if (!downloadNeeded) {
            [self showLoginMessage];
        }
    }
}

- (void)outerChallengeView:(BOOL)animated {
    (void)animated; // Yes, the binary accepts this argument but never reads it.
    (void)ChallengeStatus.sharedStatus
        .bItemDownload; // Yes, the binary discards this getter's result.
    [AudioManager.sharedManager fadeoutBgm:1.0];
    self.transform = CGAffineTransformMakeTranslation(0, 0);
    [UIView animateWithDuration:kAnimDuration020 // @ghidraAddress 0x28f240
        delay:0.10000000149011612                // @ghidraAddress 0x28f2b8
        options:UIViewAnimationOptionCurveLinear
        animations:^{
          /** @ghidraAddress 0x6a89c */
          // Translate up by one full screen height, sliding the view off the top of the display.
          self.transform =
              CGAffineTransformMakeTranslation(0, -UIScreen.mainScreen.bounds.size.height);
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x6a940 */
          (void)finished;
          [self.controller challengeModeClose];
        }];
}

- (void)setChallengeData:(NSDictionary *)challengeData {
    [ChallengeStatus.sharedStatus initWithDictionary:challengeData];
    [self refreshView];
    [self deleteMusicData];
    [statusView updateDisplayStatus];
    if (![refreshTimer isValid]) {
        refreshTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                        target:self
                                                      selector:@selector(timerRefresh:)
                                                      userInfo:nil
                                                       repeats:YES];
    }
}

- (void)deleteMusicData {
    NSArray *lineup = ChallengeStatus.sharedStatus.scratchLineUp;
    for (int i = 0; i < (int)lineup.count; ++i) {
        NSDictionary *item = [lineup objectAtIndex:i];
        if (item != nil) {
            (void)[[item objectForKey:@"music_id"]
                intValue]; // Yes, the binary discards this value.
        }
    }
}

- (void)refreshView {
    [self setNotificateImage];
    [scratchBoard refreshScratchTable];
    [scratchBoard refreshScratchCount];
}

#pragma mark - Cluster B (0x6ac08 - 0x6af40)

- (void)closeChallengeModeSessionError {
    [[AudioManager sharedManager] playSeResFile:@"SD_CHALLENGE_CLOSE" inDirectory:nil];
    [refreshTimer invalidate];
    [self outerChallengeView:YES];
}

- (void)closeChallengeMode:(UIButton *)sender {
    [[AudioManager sharedManager] playSeResFile:@"SD_CHALLENGE_CLOSE" inDirectory:nil];
    [refreshTimer invalidate];
    [self outerChallengeView:YES];
}

- (void)tapMenuBtn:(UIButton *)sender {
    [[AudioManager sharedManager] playSeResFile:@"SD_WINDOW_OPEN" inDirectory:nil];
    menuView = [[ChallengeMenuRootView alloc] initWithFrame:self.frame];
    [menuView setADelegate:self];
    [menuView setUserInteractionEnabled:YES];
    [self addSubview:menuView];
    [menuView enterRootMenu];
}

- (void)tapLineupBtn:(UIButton *)sender {
    [self showMenuCoverView];
    [[AudioManager sharedManager] playSeResFile:@"SD_WINDOW_OPEN" inDirectory:nil];
    // The lineup view is inset to the origin: it takes this view's size but is pinned to {0, 0}.
    CGRect selfFrame = self.frame;
    lineupView = [[ChallengeLineupView alloc]
        initWithFrame:CGRectMake(0, 0, selfFrame.size.width, selfFrame.size.height)];
    [self addSubview:lineupView];
    [lineupView setADelegate:self];
    [lineupView showLineup];
}

- (void)tapRankingBtn:(UIButton *)sender {
    [self openAllRanking];
}

- (void)dispCoverView:(NSNumber *)dispFlag {
    (void)[dispFlag boolValue]; // Yes, the binary calls boolValue and discards the result.
}

- (void)dispDownloadDialog:(NSNumber *)dispFlag {
}

- (void)alertSelect:(NSDictionary *)dict {
    // The alert result dictionary carries the tapped button (0 = cancel, 1 = confirm) under
    // "btnMessage" and the originating alert type under "Tag".
    int btnMessage = [dict[@"btnMessage"] intValue];
    int tag = [dict[@"Tag"] intValue];
    // Tag 9999 marks a dead challenge session; route to the session-error close path.
    if (tag == 9999) {
        [[[ChallengeStatus sharedStatus] rootView] closeChallengeModeSessionError];
        return;
    }
    if (btnMessage == 1) {
        ChallengeStatus *status = [ChallengeStatus sharedStatus];
        switch (tag) {
        case 1: {
            // Nail (single-panel) scratch.
            NSDictionary *post = [NSMutableDictionary
                dictionaryWithObjects:@[ [status scratchID], @((int)selectedView.tag) ]
                              forKeys:@[ @"scratch_id", @"position" ]];
            SessionDownloader *downloader =
                [[SessionDownloader alloc] initWithURL:[ScratchUtil nailScratchURL]
                                        postDictionary:post
                                              delegate:self];
            [downloader setTag:0];
            [downloader setApiTag:4];
            [downloader startDownloading];
            [selectedView startIndicator];
            [UIApplication.sharedApplication beginIgnoringInteractionEvents];
            break;
        }
        case 2: {
            // Scratch a single panel using cubes.
            int jCube = [status jCubeNum];
            if (jCube < [status consumeScratchCube]) {
                bScratchEnable = YES;
                [selectedView scratchCancel];
                [[AlertViewManager sharedManager] makeAlert:0
                                                   delegate:self
                                                        tag:4
                                                      title:@""
                                                        msg:@"jCubeが足りません。購入しますか？"
                                                     cancel:@"いいえ"
                                                    btnText:@[ @"はい" ]
                                                       show:YES];
                return;
            }
            [UIApplication.sharedApplication beginIgnoringInteractionEvents];
            NSDictionary *post = @{
                @"item_type" : @1,
                @"scratch_id" : [status scratchID],
                @"position" : @((int)selectedView.tag)
            };
            SessionDownloader *downloader =
                [[SessionDownloader alloc] initWithURL:[ScratchUtil cubeScratchURL]
                                        postDictionary:post
                                              delegate:self];
            [downloader setTag:2];
            [downloader setApiTag:5];
            [downloader startDownloading];
            break;
        }
        case 3: {
            // Scratch the remaining panels using cubes.
            int jCube = [status jCubeNum];
            if (jCube < [status consumeRestCube]) {
                [[AlertViewManager sharedManager] makeAlert:0
                                                   delegate:self
                                                        tag:4
                                                      title:@""
                                                        msg:@"jCubeが足りません。購入しますか？"
                                                     cancel:@"いいえ"
                                                    btnText:@[ @"はい" ]
                                                       show:YES];
                return;
            }
            NSDictionary *post = @{@"item_type" : @2};
            SessionDownloader *downloader =
                [[SessionDownloader alloc] initWithURL:[ScratchUtil cubeScratchURL]
                                        postDictionary:post
                                              delegate:self];
            [downloader setTag:6];
            [downloader setApiTag:5];
            [downloader startDownloading];
            break;
        }
        case 4:
            [self cubePurchaseStart];
            break;
        case 7:
            if ([imageDLTasks count] == 0) {
                imageDLTasks = nil;
                [self hideCoverView];
                [self showLoginMessage];
            } else {
                [self imageDownload];
            }
            break;
        case 8:
            [self openScratchComplete];
            [self refreshView];
            [selectedView scratchOpen:YES];
            bScratchEnable = YES;
            break;
        }
    } else if (btnMessage == 0) {
        if (tag == 11 || tag == 7) {
            [self closeChallengeMode:nil];
            return;
        }
        if (tag == 2) {
            bScratchEnable = YES;
            [selectedView scratchCancel];
            return;
        }
    }
    if (tag == 6) {
        [[PurchaseManager sharedManager] setDelegate:nil];
        if (bVerifyPurchase) {
            [self cubePurchaseStart];
        }
    }
}

#pragma mark - Cluster C (0x6b9a8 - 0x6c59c)

- (void)openDetailView {
    [[AudioManager sharedManager] playSeResFile:[self soundName:@"MUSIC_SELECT"] inDirectory:nil];
    [[AudioManager sharedManager] pushBgm];
    ScratchInfo *info =
        [[ChallengeStatus sharedStatus] scratchInfoTable][(NSUInteger)selectedView.tag];
    NSString *itemPath = [ScratchUtil itemPathForMusicID:(unsigned int)[info musicID]];
    KUnzip *unzip = [[KUnzip alloc] initWithPath:itemPath tail:0x10];
    NSData *packed = nil;
    if (unzip && (packed = [unzip uncompress:@"index"])) {
        BFCodec *codec = [[BFCodec alloc] init];
        [codec cipherInit:GetBgmCipherKey()];
        [codec decipher:packed];
        [[AudioManager sharedManager] loadBgmData:packed];
        [[AudioManager sharedManager] startBgm:1 fadeTime:0];
    }
    [self showMenuCoverView];
    detailView.alpha = 0;
    bDetailOpen = YES;
    [self addSubview:detailView];
    [detailView setDetailInfo:[selectedView tag]];
    [detailView showDetail];
    detailView.transform = CGAffineTransformMakeScale(kAnimDuration020Alt, kAnimDuration020Alt);
    __weak ScratchMusicDetailView *weakDetailView = detailView;
    [UIView animateWithDuration:kAnimDuration020Alt
        delay:0
        options:UIViewAnimationOptionCurveLinear
        animations:^{
          /** @ghidraAddress 0x6be34 */
          weakDetailView.alpha = 1;
          weakDetailView.transform = CGAffineTransformMakeScale(1, 1);
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x6beec */
          // Shared global no-op-style completion block.
          (void)finished;
          [UIApplication.sharedApplication endIgnoringInteractionEvents];
        }];
}

- (void)closeDetailView {
    bDetailOpen = NO;
    [self hideMenuCoverView];
    __weak ScratchMusicDetailView *weakDetailView = detailView;
    [UIView animateWithDuration:kAnimDuration020Alt
        delay:0
        options:UIViewAnimationOptionCurveLinear
        animations:^{
          /** @ghidraAddress 0x6c064 */
          weakDetailView.alpha = 0;
          weakDetailView.transform =
              CGAffineTransformMakeScale(kAnimDuration020Alt, kAnimDuration020Alt);
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x6c114 */
          (void)finished;
          [detailView removeFromSuperview];
          // The detail view is only removed; it is the selected panel that is released here.
          selectedView = nil;
          [[AudioManager sharedManager] playSeResFile:@"SKIP" inDirectory:nil];
          [[AudioManager sharedManager] popBgm];
          // The 0.2 fade time here is a float literal (promoted), unlike the exact double 0.2
          // used for the animation duration at 0x28e040.
          [[AudioManager sharedManager] startBgm:1 fadeTime:0.2f]; // @ghidraAddress 0x28f240
        }];
}

- (void)closeMenu {
    [self hideMenuCoverView];
    __weak ChallengeNameSettingView *weakNameSettingView = nameSettingView;
    [UIView animateWithDuration:kAnimDuration020Alt
        delay:0
        options:UIViewAnimationOptionCurveLinear
        animations:^{
          /** @ghidraAddress 0x6c370 */
          weakNameSettingView.alpha = 0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x6c3bc */
          (void)finished;
          [nameSettingView removeFromSuperview];
          nameSettingView = nil;
          [self showLoginMessage];
        }];
}

- (void)closeMenuView {
    [menuView removeFromSuperview];
    menuView = nil;
}

- (void)changeRanking {
    [detailView refreshDetail];
}

- (NSString *)scratchMessage {
    ChallengeStatus *status = [ChallengeStatus sharedStatus];
    int cube = [status consumeScratchCube];
    NSString *message = [NSString stringWithFormat:@"jCube×%dを使用してスクラッチしますか？", cube];
    double timeLeft = [status getTimeLeft:[status scratchResetDate]];
    // @ghidraAddress 0x28f890 (3600.0, seconds per hour); 24.0 is the hour threshold.
    if (timeLeft / 3600.0 < 24.0) {
        message = [NSString
            stringWithFormat:
                @"プレー可能な時間が24時間を切っていますが、jCube×%dを使用してスクラッチしますか？",
                cube];
    }
    return message;
}

- (void)startChallengeMusic {
    int coinNum = [[ChallengeStatus sharedStatus] coinNum];
    int playCoin = [[ChallengeStatus sharedStatus] consumePlayCoin];
    if (coinNum < playCoin) {
        int restCube = [[ChallengeStatus sharedStatus] consumeRestCube];
        NSString *msg = [NSString
            stringWithFormat:@"jCube×%dを使用してプレーコインを回復させますか？", restCube];
        [[AlertViewManager sharedManager] makeAlert:0
                                           delegate:self
                                                tag:3
                                              title:@""
                                                msg:msg
                                             cancel:@"いいえ"
                                            btnText:@[ @"はい" ]
                                               show:YES];
    } else {
        NSDictionary *post = @{
            @"scratch_id" : [[ChallengeStatus sharedStatus] scratchID],
            @"music_id" : @((int)[[detailView tuneInfo] tuneID]),
            @"difficulty_num" :
                @([NSUserDefaults.standardUserDefaults integerForKey:@"PrefDifficulty"])
        };
        SessionDownloader *downloader =
            [[SessionDownloader alloc] initWithURL:[ScratchUtil playMusicURL]
                                    postDictionary:post
                                          delegate:self];
        [downloader setTag:4];
        [downloader setApiTag:7];
        [downloader startDownloading];
        [self showCoverView];
        self.modalDialog.labelMessage.text = @"通信中...";
        self.modalDialog.buttonAbort.hidden = YES;
    }
}

#pragma mark - Cluster D (0x6ca44 - 0x6dd88)

- (void)updateNailState:(NSDictionary *)info {
    if ([info[@"status"] intValue] == 0) {
        [[ChallengeStatus sharedStatus] openScratch:info index:(int)selectedView.tag];
        if (bScratchEnable) {
            [self openScratchComplete];
            [self refreshView];
            [selectedView scratchOpen:YES];
        } else {
            [self refreshView];
            if ([selectedView scratchContinue]) {
                [self openScratchComplete];
            }
        }
    } else {
        NSString *msg = [[NSBundle mainBundle] localizedStringForKey:@"ServerErrorMsg"
                                                               value:@""
                                                               table:nil];
        [[AlertViewManager sharedManager] makeAlert:0
                                           delegate:nil
                                                tag:0
                                              title:@"通信エラー"
                                                msg:msg
                                             cancel:@"はい"
                                            btnText:nil
                                               show:YES];
    }
    [self refreshStatus];
}

- (void)showMenuCoverView {
    coverView.alpha = 0;
    [self addSubview:coverView];
    __weak UIView *weakCoverView = coverView;
    [UIView animateWithDuration:0.3
        delay:0
        options:UIViewAnimationOptionBeginFromCurrentState |
                UIViewAnimationOptionAllowUserInteraction
        animations:^{
          /** @ghidraAddress 0x6cd9c */
          weakCoverView.alpha = 1;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x6cde8 */
          (void)finished;
        }];
}

- (void)hideMenuCoverView {
    __weak UIView *weakCoverView = coverView;
    [UIView animateWithDuration:0.3
        delay:0
        options:UIViewAnimationOptionBeginFromCurrentState |
                UIViewAnimationOptionAllowUserInteraction
        animations:^{
          /** @ghidraAddress 0x6cf10 */
          weakCoverView.alpha = 0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x6cf5c */
          (void)finished;
          [weakCoverView removeFromSuperview];
        }];
}

- (void)showCoverView {
    modalCoverView.alpha = 0;
    [self addSubview:modalCoverView];
    __weak UIView *weakCoverView = modalCoverView;
    [UIView animateWithDuration:0.3
        delay:0
        options:UIViewAnimationOptionBeginFromCurrentState |
                UIViewAnimationOptionAllowUserInteraction
        animations:^{
          /** @ghidraAddress 0x6d0a4 */
          weakCoverView.alpha = 1;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x6d0f0 */
          (void)finished;
        }];
}

- (void)hideCoverView {
    __weak UIView *weakCoverView = modalCoverView;
    [UIView animateWithDuration:0.3
        delay:0
        options:UIViewAnimationOptionBeginFromCurrentState |
                UIViewAnimationOptionAllowUserInteraction
        animations:^{
          /** @ghidraAddress 0x6d218 */
          weakCoverView.alpha = 0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x6d264 */
          (void)finished;
          [weakCoverView removeFromSuperview];
        }];
}

- (void)showPurchaseDialog:(NSString *)message {
    modalCoverView.alpha = 0;
    [self addSubview:modalCoverView];
    [self.modalDialog.indicatorView startAnimating];
    self.modalDialog.labelMessage.text = message;
    [self.modalDialog.buttonAbort setEnabled:NO];
    self.modalDialog.delegate = nil;
    [self.modalDialog.buttonAbort setHidden:YES];
    __weak UIView *weakCoverView = modalCoverView;
    [UIView animateWithDuration:0.3
        delay:0
        options:UIViewAnimationOptionBeginFromCurrentState |
                UIViewAnimationOptionAllowUserInteraction
        animations:^{
          /** @ghidraAddress 0x6d54c */
          weakCoverView.alpha = 1;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x6d598 */
          (void)finished;
        }];
}

- (void)hidePurchaseDialog {
    [self.modalDialog.buttonAbort setEnabled:NO];
    self.modalDialog.delegate = nil;
    __weak UIView *weakCoverView = modalCoverView;
    __weak StoreDialogView *weakDialog = self.modalDialog;
    [UIView animateWithDuration:0.3
        delay:0
        options:UIViewAnimationOptionBeginFromCurrentState |
                UIViewAnimationOptionAllowUserInteraction
        animations:^{
          /** @ghidraAddress 0x6d7ac */
          weakCoverView.alpha = 0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x6d7f8 */
          (void)finished;
          [weakDialog.buttonAbort setHidden:NO];
          [weakDialog.indicatorView stopAnimating];
          [weakCoverView removeFromSuperview];
        }];
}

- (void)setPurchaseDialogMessage:(NSString *)message {
    self.modalDialog.labelMessage.text = message;
}

- (void)showModalDialog:(id)delegate {
    modalCoverView.alpha = 0;
    [self addSubview:modalCoverView];
    [self.modalDialog.indicatorView startAnimating];
    [self.modalDialog.buttonAbort setEnabled:NO];
    [self.modalDialog.buttonAbort setHidden:NO];
    self.modalDialog.delegate = delegate;
    self.modalDialog.labelMessage.text = @"";
    __weak UIView *weakCoverView = modalCoverView;
    __weak StoreDialogView *weakDialog = self.modalDialog;
    [UIView animateWithDuration:0.3
        delay:0
        options:UIViewAnimationOptionBeginFromCurrentState |
                UIViewAnimationOptionAllowUserInteraction
        animations:^{
          /** @ghidraAddress 0x6dcd0 */
          weakCoverView.alpha = 1;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x6dd1c */
          (void)finished;
          [weakDialog.buttonAbort setEnabled:YES];
        }];
}

- (void)hideModalDialog {
    [self.modalDialog.buttonAbort setEnabled:NO];
    self.modalDialog.delegate = nil;
    __weak UIView *weakCoverView = modalCoverView;
    __weak StoreDialogView *weakDialog = self.modalDialog;
    [UIView animateWithDuration:0.3
        delay:0
        options:UIViewAnimationOptionBeginFromCurrentState |
                UIViewAnimationOptionAllowUserInteraction
        animations:^{
          /** @ghidraAddress 0x6df98 */
          weakCoverView.alpha = 0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x6dfe4 */
          (void)finished;
          [weakDialog.indicatorView stopAnimating];
          [weakCoverView removeFromSuperview];
        }];
}

#pragma mark - Cluster E (0x6e0c0 - 0x70008)

- (void)timerRefresh:(NSTimer *)timer {
    (void)timer; // Yes, the binary accepts the timer argument but never reads it.
    [detailView timerUpdate];
    [statusView timerUpdate];
    [scratchBoard timerUpdate];
}

- (void)downloaderFinished:(id)downloader {
    NSDictionary *json = [downloader getDataInJSON];
    int status = -1;
    if (json[@"status"] != nil) {
        status = [json[@"status"] intValue];
        if (status != 0) {
            if (status == 0x18b53) {
                [UIApplication.sharedApplication endIgnoringInteractionEvents];
                NSString *serverErrorMsg =
                    [NSBundle.mainBundle localizedStringForKey:@"ServerErrorMsg"
                                                         value:@""
                                                         table:nil];
                if (json[@"err_message"] != nil) {
                    serverErrorMsg = json[@"err_message"];
                }
                [AlertViewManager.sharedManager
                    makeAlert:0
                     delegate:self
                          tag:9999
                        title:@""
                          msg:serverErrorMsg
                       cancel:[NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil]
                      btnText:nil
                         show:YES];
                return;
            }
            if (status == 0x186ab) {
                [UIApplication.sharedApplication endIgnoringInteractionEvents];
                int tag = (int)[downloader tag];
                if (tag == 0 || tag == 2) {
                    bScratchEnable = YES;
                    [selectedView scratchCancel];
                } else if (tag == 4) {
                    [self hideCoverView];
                }
                [AlertViewManager.sharedManager showUpdateAlert];
                return;
            }
            // Any other non-zero status falls through to the error dispatcher below.
        } else {
            switch ((int)[downloader tag]) {
            case 0:
            case 2:
                [UIApplication.sharedApplication endIgnoringInteractionEvents];
                [self updateNailState:json];
                [self hideCoverView];
                break;
            case 3: {
                [ChallengeStatus.sharedStatus openMusicDetail:json index:(int)selectedView.tag];
                [self hideCoverView];
                [self openDetailView];
                break;
            }
            case 4: {
                [refreshTimer invalidate];
                int difficulty = detailView.difficulty;
                NSDictionary *tuneInfo = detailView.tuneInfo;
                [self.controller challengeMusicStart:tuneInfo diff:difficulty];
                [ChallengeStatus.sharedStatus playMusic:json];
                [UIApplication.sharedApplication beginIgnoringInteractionEvents];
                [UIApplication.sharedApplication
                    performSelector:@selector(endIgnoringInteractionEvents)
                         withObject:nil
                         afterDelay:0.7]; // @ghidraAddress 0x28f2a0
                break;
            }
            case 6:
                [ChallengeStatus.sharedStatus restPlayCoin:json];
                [self refreshStatus];
                [AlertViewManager.sharedManager makeAlert:0
                                                 delegate:nil
                                                      tag:0
                                                    title:@""
                                                      msg:@"プレーコインを全回復しました"
                                                   cancel:@"はい"
                                                  btnText:nil
                                                     show:YES];
                break;
            case 7: {
                NSData *data = [downloader getData];
                NSString *path =
                    [ScratchUtil imagePathForMusicID:[currentDownload[@"music_id"] intValue]];
                NSURL *url = [[NSURL alloc] initFileURLWithPath:path isDirectory:NO];
                [data writeToURL:url atomically:YES];
                UIImage *image = [[UIImage alloc] initWithData:data];
                [ChallengeStatus.sharedStatus setLineupImage:image
                                                     musicID:currentDownload[@"music_id"]];
                ExcludeUrlFromICloudBackup(url);
                [imageDLTasks removeObject:currentDownload];
                if (imageDLTasks.count == 0) {
                    imageDLTasks = nil;
                    [self hideCoverView];
                }
                [self showLoginMessage];
                break;
            }
            }
            return;
        }
    }
    // Error dispatcher: no "status" key, or a non-zero status other than the two handled above.
    NSString *errMessage = json[@"err_message"];
    switch ((int)[downloader tag]) {
    case 2: {
        [UIApplication.sharedApplication endIgnoringInteractionEvents];
        if (status == 0x19710) {
            bScratchEnable = YES;
            [selectedView scratchCancel];
            [AlertViewManager.sharedManager makeAlert:0
                                             delegate:self
                                                  tag:4
                                                title:@""
                                                  msg:@"jCubeが足りません。購入しますか？"
                                               cancel:@"いいえ"
                                              btnText:@[ @"はい" ]
                                                 show:YES];
            break;
        }
        if (status == 0x31d47) {
            NSMutableDictionary *info = [NSMutableDictionary dictionaryWithDictionary:json];
            info[@"status"] = @(0);
            [self updateNailState:info];
            [self hideCoverView];
            [UIApplication.sharedApplication endIgnoringInteractionEvents];
            if (errMessage == nil) {
                errMessage = @"既に削ったスクラッチパネルだったためjCubeは消費されませんでした。";
            }
            [AlertViewManager.sharedManager makeAlert:0
                                             delegate:nil
                                                  tag:0
                                                title:@""
                                                  msg:errMessage
                                               cancel:@"はい"
                                              btnText:nil
                                                 show:YES];
            bScratchEnable = YES;
            break;
        }
        if (errMessage == nil) {
            errMessage = [NSBundle.mainBundle localizedStringForKey:@"ServerErrorMsg"
                                                              value:@""
                                                              table:nil];
        }
        [AlertViewManager.sharedManager makeAlert:0
                                         delegate:nil
                                              tag:0
                                            title:@""
                                              msg:errMessage
                                           cancel:@"はい"
                                          btnText:nil
                                             show:YES];
        bScratchEnable = YES;
        [selectedView scratchCancel];
        break;
    }
    case 3: {
        [UIApplication.sharedApplication endIgnoringInteractionEvents];
        if (errMessage == nil) {
            errMessage = [NSBundle.mainBundle localizedStringForKey:@"ServerErrorMsg"
                                                              value:@""
                                                              table:nil];
        }
        [AlertViewManager.sharedManager makeAlert:0
                                         delegate:self
                                              tag:4
                                            title:@""
                                              msg:errMessage
                                           cancel:@"はい"
                                          btnText:nil
                                             show:YES];
        break;
    }
    case 4: {
        if (errMessage == nil) {
            errMessage = [NSBundle.mainBundle localizedStringForKey:@"ServerErrorMsg"
                                                              value:@""
                                                              table:nil];
        }
        [AlertViewManager.sharedManager makeAlert:0
                                         delegate:nil
                                              tag:5
                                            title:@""
                                              msg:errMessage
                                           cancel:[NSBundle.mainBundle localizedStringForKey:@"OK"
                                                                                       value:@""
                                                                                       table:nil]
                                          btnText:nil
                                             show:YES];
        [self hideCoverView];
        break;
    }
    case 6: {
        if (errMessage == nil) {
            errMessage = [NSBundle.mainBundle localizedStringForKey:@"ServerErrorMsg"
                                                              value:@""
                                                              table:nil];
        }
        if (status == 0x19710) {
            [AlertViewManager.sharedManager makeAlert:0
                                             delegate:self
                                                  tag:4
                                                title:@""
                                                  msg:@"jCubeが足りません。購入しますか？"
                                               cancel:@"いいえ"
                                              btnText:@[ @"はい" ]
                                                 show:YES];
            break;
        }
        [AlertViewManager.sharedManager makeAlert:0
                                         delegate:nil
                                              tag:0
                                            title:@""
                                              msg:errMessage
                                           cancel:@"はい"
                                          btnText:nil
                                             show:YES];
        break;
    }
    case 7: {
        NSData *data = [downloader getData];
        NSString *path = [ScratchUtil imagePathForMusicID:[currentDownload[@"music_id"] intValue]];
        NSURL *url = [[NSURL alloc] initFileURLWithPath:path isDirectory:NO];
        [data writeToURL:url atomically:YES];
        UIImage *image = [[UIImage alloc] initWithData:data];
        [ChallengeStatus.sharedStatus setLineupImage:image musicID:currentDownload[@"music_id"]];
        ExcludeUrlFromICloudBackup(url);
        [imageDLTasks removeObject:currentDownload];
        if (imageDLTasks.count == 0) {
            imageDLTasks = nil;
            [self hideCoverView];
        }
        [self showLoginMessage];
        break;
    }
    case 0: {
        // Tag 0 additionally cancels the pending scratch after the alert.
        if (errMessage == nil) {
            errMessage = [NSBundle.mainBundle localizedStringForKey:@"ServerErrorMsg"
                                                              value:@""
                                                              table:nil];
        }
        [AlertViewManager.sharedManager makeAlert:0
                                         delegate:nil
                                              tag:0
                                            title:@""
                                              msg:errMessage
                                           cancel:@"はい"
                                          btnText:nil
                                             show:YES];
        bScratchEnable = YES;
        [selectedView scratchCancel];
        break;
    }
    default: {
        // Tags 1, 5, and anything above 7 show the generic server-error alert only.
        if (errMessage == nil) {
            errMessage = [NSBundle.mainBundle localizedStringForKey:@"ServerErrorMsg"
                                                              value:@""
                                                              table:nil];
        }
        [AlertViewManager.sharedManager makeAlert:0
                                         delegate:nil
                                              tag:0
                                            title:@""
                                              msg:errMessage
                                           cancel:@"はい"
                                          btnText:nil
                                             show:YES];
        break;
    }
    }
}

- (void)downloaderError:(id)downloader {
    NSString *serverErrorMsg = [NSBundle.mainBundle localizedStringForKey:@"ServerErrorMsg"
                                                                    value:@""
                                                                    table:nil];
    switch ((int)[downloader tag]) {
    case 0:
        [AlertViewManager.sharedManager makeAlert:0
                                         delegate:nil
                                              tag:5
                                            title:@""
                                              msg:serverErrorMsg
                                           cancel:[NSBundle.mainBundle localizedStringForKey:@"OK"
                                                                                       value:@""
                                                                                       table:nil]
                                          btnText:nil
                                             show:YES];
        [self hideCoverView];
        bScratchEnable = YES;
        [selectedView scratchCancel];
        break;
    case 2:
    case 5:
        [AlertViewManager.sharedManager makeAlert:0
                                         delegate:nil
                                              tag:5
                                            title:@""
                                              msg:serverErrorMsg
                                           cancel:[NSBundle.mainBundle localizedStringForKey:@"OK"
                                                                                       value:@""
                                                                                       table:nil]
                                          btnText:nil
                                             show:YES];
        [self hideCoverView];
        bScratchEnable = YES;
        [selectedView scratchCancel];
        [UIApplication.sharedApplication endIgnoringInteractionEvents];
        break;
    case 3:
        [UIApplication.sharedApplication endIgnoringInteractionEvents];
        [AlertViewManager.sharedManager makeAlert:0
                                         delegate:nil
                                              tag:5
                                            title:@""
                                              msg:serverErrorMsg
                                           cancel:[NSBundle.mainBundle localizedStringForKey:@"OK"
                                                                                       value:@""
                                                                                       table:nil]
                                          btnText:nil
                                             show:YES];
        break;
    case 4:
        [AlertViewManager.sharedManager makeAlert:0
                                         delegate:nil
                                              tag:5
                                            title:@""
                                              msg:serverErrorMsg
                                           cancel:[NSBundle.mainBundle localizedStringForKey:@"OK"
                                                                                       value:@""
                                                                                       table:nil]
                                          btnText:nil
                                             show:YES];
        [self hideCoverView];
        break;
    case 6:
        [AlertViewManager.sharedManager makeAlert:0
                                         delegate:nil
                                              tag:5
                                            title:@""
                                              msg:serverErrorMsg
                                           cancel:[NSBundle.mainBundle localizedStringForKey:@"OK"
                                                                                       value:@""
                                                                                       table:nil]
                                          btnText:nil
                                             show:YES];
        break;
    case 7: {
        [AlertViewManager.sharedManager
            makeAlert:0
             delegate:self
                  tag:7
                title:@""
                  msg:@"イメージデータのダウンロードに失敗しました。"
               cancel:[NSBundle.mainBundle localizedStringForKey:@"キャンセル" value:@"" table:nil]
              btnText:@[ @"再試行" ]
                 show:YES];
        break;
    }
    }
}

- (void)cubePurchaseStart {
    if ([PurchaseManager.sharedManager verifyPendingConsumeReceipt]) {
        [PurchaseManager.sharedManager setDelegate:self];
        bVerifyPurchase = YES;
        return;
    }
    [AudioManager.sharedManager playSeResFile:@"SD_WINDOW_OPEN" inDirectory:nil];
    bVerifyPurchase = NO;
    cubePurchaseView = [[CubePurchaseView alloc]
        initWithFrame:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)];
    [cubePurchaseView setADelegate:self];
    [cubePurchaseView setUserInteractionEnabled:YES];
    if (!bDetailOpen) {
        [self showMenuCoverView];
    }
    [self addSubview:cubePurchaseView];
    __weak CubePurchaseView *weakView = cubePurchaseView;
    cubePurchaseView.alpha = 0;
    [UIView animateWithDuration:kAnimDuration020 // @ghidraAddress 0x28f240
        delay:0
        options:UIViewAnimationOptionBeginFromCurrentState |
                UIViewAnimationOptionAllowUserInteraction
        animations:^{
          /** @ghidraAddress 0x6fca4 */
          weakView.alpha = 1.0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x6fcf0 */
          (void)finished;
        }];
}

- (void)closeCubePurchase {
    if (!bDetailOpen) {
        [self hideMenuCoverView];
    }
    __weak CubePurchaseView *weakView = cubePurchaseView;
    [UIView animateWithDuration:kAnimDuration020 // @ghidraAddress 0x28f240
        delay:0
        options:UIViewAnimationOptionBeginFromCurrentState |
                UIViewAnimationOptionAllowUserInteraction
        animations:^{
          /** @ghidraAddress 0x6fe2c */
          weakView.alpha = 0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x6fe78 */
          (void)finished;
          [cubePurchaseView removeFromSuperview];
          cubePurchaseView = nil;
        }];
}

- (void)closeView {
    if (menuView != nil) {
        [menuView removeFromSuperview];
        menuView = nil;
        [self hideMenuCoverView];
        return;
    }
    // selectedView is a weak ivar; only dismiss the detail view when a scratch is selected.
    if (selectedView != nil) {
        [self closeDetailView];
    }
}

- (void)closeLineupView {
    [lineupView removeFromSuperview];
    lineupView = nil;
    [self hideMenuCoverView];
}

- (void)closeLoginMessage {
    [loginMessage removeFromSuperview];
    loginMessage = nil;
    bDispLoginMessage = YES;
    [self hideMenuCoverView];
    [self showLoginMessage];
}

- (void)closeLoginInformation {
    [loginInformation removeFromSuperview];
    loginInformation = nil;
    [self hideMenuCoverView];
    [self showLoginMessage];
}

#pragma mark - Cluster F (0x70064 - 0x70fc8)

- (void)purchaseSucceeded:(id)productID {
    (void)productID; // Yes, the binary ignores the product identifier here.
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:self
                                            tag:6
                                          title:@""
                                            msg:@"購入処理が完了しました"
                                         cancel:[[NSBundle mainBundle] localizedStringForKey:@"OK"
                                                                                       value:@""
                                                                                       table:nil]
                                        btnText:nil
                                           show:YES];
}

- (void)purchaseFailed:(NSString *)productID error:(NSError *)error {
    (void)productID; // Yes, the binary never reads the product identifier on failure.
    NSString *message = @"購入に失敗しました。";
    if (error.userInfo[NSLocalizedDescriptionKey] != nil) {
        message = error.userInfo[NSLocalizedDescriptionKey];
    }
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:nil
                                            tag:0
                                          title:@""
                                            msg:message
                                         cancel:[[NSBundle mainBundle] localizedStringForKey:@"OK"
                                                                                       value:@""
                                                                                       table:nil]
                                        btnText:nil
                                           show:YES];
    [[PurchaseManager sharedManager] setDelegate:nil];
}

- (void)storeDialogCancel:(StoreDialogView *)sender {
    if (sender.tag == 1) {
        [self closeChallengeMode:nil];
    }
}

- (void)selectScratch:(ScratchView *)sender {
    int state = [sender getState];
    selectedView = sender;
    ChallengeStatus *status = [ChallengeStatus sharedStatus];
    if (state == 2) {
        // The panel is already fully scratched: confirm opening it (削り切りますか？).
        [[AlertViewManager sharedManager] makeAlert:0
                                           delegate:self
                                                tag:8
                                              title:@""
                                                msg:@"スクラッチパネルを削り切りますか？"
                                             cancel:@"いいえ"
                                            btnText:@[ @"はい" ]
                                               show:YES];
        return;
    }
    if (state == 1) {
        int nailNum = [status nailNum];
        BOOL hasUnfetched = NO;
        for (ScratchInfo *info in [status scratchInfoTable]) {
            if ([info musicID] == 0) {
                hasUnfetched = YES;
                break;
            }
        }
        if (nailNum < 1 || !hasUnfetched) {
            [UIApplication.sharedApplication beginIgnoringInteractionEvents];
            int musicID = (int)[[status scratchInfoTable][(NSUInteger)selectedView.tag] musicID];
            NSDictionary *post = [NSMutableDictionary
                dictionaryWithObjects:@[ @0, @(musicID), [status scratchID] ]
                              forKeys:@[ @"kind", @"music_id", @"scratch_id" ]];
            SessionDownloader *downloader =
                [[SessionDownloader alloc] initWithURL:[ScratchUtil musicInfoURL]
                                        postDictionary:post
                                              delegate:self];
            [downloader setTag:3];
            [downloader setApiTag:6];
            [downloader startDownloading];
        } else {
            [[AlertViewManager sharedManager]
                makeAlert:0
                 delegate:self
                      tag:1
                    title:@""
                      msg:[NSString stringWithFormat:@"先に %d 回スクラッチしてください", nailNum]
                   cancel:@"はい"
                  btnText:nil
                     show:YES];
        }
        return;
    }
    if (state != 0) {
        return;
    }
    int nailNum = [status nailNum];
    if (nailNum < 1) {
        // No nails left: offer to scratch using cubes instead.
        [[AlertViewManager sharedManager] makeAlert:0
                                           delegate:self
                                                tag:2
                                              title:@""
                                                msg:[self scratchMessage]
                                             cancel:@"いいえ"
                                            btnText:@[ @"はい" ]
                                               show:YES];
        return;
    }
    // Nails remain: confirm scratching this single panel (削りますか？).
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:self
                                            tag:1
                                          title:@""
                                            msg:@"このスクラッチパネルを削りますか？"
                                         cancel:@"いいえ"
                                        btnText:@[ @"はい" ]
                                           show:YES];
}

- (void)scratchEnable:(BOOL)enable {
    bScratchEnable = enable;
}

- (BOOL)isScratchEnable {
    return bScratchEnable;
}

- (void)scratchStart:(ScratchView *)sender {
    selectedView = sender;
    int nailNum = [[ChallengeStatus sharedStatus] nailNum];
    if (nailNum < 1) {
        [[AlertViewManager sharedManager] makeAlert:0
                                           delegate:self
                                                tag:2
                                              title:@""
                                                msg:[self scratchMessage]
                                             cancel:@"いいえ"
                                            btnText:@[ @"はい" ]
                                               show:YES];
    } else {
        ChallengeStatus *status = [ChallengeStatus sharedStatus];
        NSDictionary *post = [NSMutableDictionary
            dictionaryWithObjects:@[ [status scratchID], @((int)selectedView.tag) ]
                          forKeys:@[ @"scratch_id", @"position" ]];
        SessionDownloader *downloader =
            [[SessionDownloader alloc] initWithURL:[ScratchUtil nailScratchURL]
                                    postDictionary:post
                                          delegate:self];
        [downloader setTag:0];
        [downloader setApiTag:4];
        [downloader startDownloading];
        [UIApplication.sharedApplication beginIgnoringInteractionEvents];
    }
}

- (void)openScratchComplete {
    ScratchInfo *info =
        [[ChallengeStatus sharedStatus] scratchInfoTable][(NSUInteger)selectedView.tag];
    completeView = [[ScratchCompleteView alloc] initWithFrame:self.frame musicInfo:info];
    [completeView setADelegate:self];
    [self addSubview:completeView];
}

- (void)closeScratchComplete {
}

- (void)scratchEnd:(id)sender {
    [self openScratchComplete];
    bScratchEnable = YES;
    [self refreshView];
}

#pragma mark - Cluster G (0x7100c - 0x71b78)

- (void)openAllRanking {
    [self showMenuCoverView];
    bOpenTotalRank = YES;
    NSDictionary *mDict = @{@"music_id" : @0, @"name" : @"全曲ランキング"};
    (void)[ChallengeStatus sharedStatus]; // Yes, the binary discards this call's result.
    ChallengeRankingListView *view = [[ChallengeRankingListView alloc]
        initWithFrame:self.frame
                mDict:mDict
            scratchID:(int)[[[ChallengeStatus sharedStatus] scratchID] intValue]];
    rankingView = view;
    rankingView.alpha = 0;
    [rankingView setADelegate:self];
    [rankingView replaceBackBtnImage];
    [self addSubview:rankingView];
    __weak ChallengeRankingListView *weakRankingView = rankingView;
    [UIView animateWithDuration:0.2 // @ghidraAddress 0x28f240
        delay:0.1                   // @ghidraAddress 0x28f2b8
        options:UIViewAnimationOptionBeginFromCurrentState |
                UIViewAnimationOptionAllowUserInteraction
        animations:^{
          /** @ghidraAddress 0x71308 */
          weakRankingView.alpha = 1;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x71354 */
          (void)finished;
        }];
}

- (void)openRanking {
    ScratchInfo *mInfo = [[ChallengeStatus sharedStatus] scratchInfoTable][selectedView.tag];
    ChallengeRankingListView *view = [[ChallengeRankingListView alloc] initWithFrame:self.frame
                                                                               mInfo:mInfo
                                                                            rankType:0];
    rankingView = view;
    rankingView.alpha = 0;
    [rankingView setADelegate:self];
    [self addSubview:rankingView];
    __weak ScratchMusicDetailView *weakDetailView = detailView;
    __weak ChallengeRankingListView *weakRankingView = rankingView;
    [UIView animateWithDuration:0.2 // @ghidraAddress 0x28f240
        delay:0.1                   // @ghidraAddress 0x28f2b8
        options:UIViewAnimationOptionBeginFromCurrentState |
                UIViewAnimationOptionAllowUserInteraction
        animations:^{
          /** @ghidraAddress 0x715cc */
          weakDetailView.alpha = 0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x71618 */
          (void)finished;
          [UIView animateWithDuration:0.2 // @ghidraAddress 0x28f240
              delay:0.1                   // @ghidraAddress 0x28f2b8
              options:UIViewAnimationOptionBeginFromCurrentState |
                      UIViewAnimationOptionAllowUserInteraction
              animations:^{
                /** @ghidraAddress 0x716cc */
                weakRankingView.alpha = 1;
              }
              completion:^(BOOL finished) {
                /** @ghidraAddress 0x71718 */
                (void)finished;
              }];
        }];
}

- (void)closeRanking {
    __weak ScratchMusicDetailView *weakDetailView = detailView;
    __weak ChallengeRankingListView *weakRankingView = rankingView;
    if (bOpenTotalRank) {
        [self hideMenuCoverView];
    }
    [UIView animateWithDuration:0.2 // @ghidraAddress 0x28f240
        delay:0.1                   // @ghidraAddress 0x28f2b8
        options:UIViewAnimationOptionBeginFromCurrentState |
                UIViewAnimationOptionAllowUserInteraction
        animations:^{
          /** @ghidraAddress 0x718bc */
          weakRankingView.alpha = 0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x71908 */
          (void)finished;
          if (!bOpenTotalRank) {
              [UIView animateWithDuration:0.2 // @ghidraAddress 0x28f240
                  delay:0.1                   // @ghidraAddress 0x28f2b8
                  options:UIViewAnimationOptionBeginFromCurrentState |
                          UIViewAnimationOptionAllowUserInteraction
                  animations:^{
                    /** @ghidraAddress 0x719e4 */
                    weakDetailView.alpha = 1;
                  }
                  completion:^(BOOL finished) {
                    /** @ghidraAddress 0x71a30 */
                    (void)finished;
                  }];
          }
          bOpenTotalRank = NO;
        }];
}

- (void)openJubeatStore:(NSInteger)packID {
    if (packID > 0) {
        [JubeatAppDelegate appDelegate].challengeMode = YES;
        [self.controller turnToPackPurchase:[NSString stringWithFormat:@"%ld", (long)packID]];
    }
}

- (void)refreshStatus {
    [statusView updateDisplayStatus];
}

// controller / setController: / modalDialog are @property accessors (weak/nonatomic and
// readonly/strong/nonatomic respectively); ARC synthesises them. -dealloc (0x71b90) is only
// [super dealloc] and is ARC-synthesised, so it is intentionally omitted.

@end
