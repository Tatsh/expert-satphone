#import "MusicDetailViewKnt.h"

#import <QuartzCore/QuartzCore.h>

#import "AlertViewManager.h"
#import "BFCodec.h"
#import "EditDataManager.h"
#import "EditFileListViewDeleteController.h"
#import "EditModalView.h"
#import "ImageCache.h"
#import "ImageLoading.h"
#import "JcfDownloadPageNavController.h"
#import "JcfManageNavController.h"
#import "JcfUpLoadView.h"
#import "JubeatAppDelegate.h"
#import "KUnzip.h"
#import "LatelyJcfListManager.h"
#import "MusicSelectViewController.h"
#import "Sequence.h"
#import "SharePlayManager.h"
#import "TuneInfo.h"
#import "cipher_keys.h"

// The shared 0.2 animation-duration double, reused here as the phone reflection-height fraction.
extern const double g_dAnimDuration020; // @ghidraAddress 0x28f240 (0.2)

// The edit-select confirmation sound played when the edit entry is chosen from the file list.
static NSString *const kEditSelectSound = @"SD_KNT_OK";

// The download-sequence alert messages, kept as the binary's own Japanese literals.
static NSString *const kConnectErrorMessage = @"通信エラー";
static NSString *const kDownloadFinishedMessage = @"ダウンロード終わり";

// The web-view close and info-edit confirmation sounds.
static NSString *const kMusicLeftSound = @"SD_KNT_MUSIC_LEFT";
static NSString *const kMusicRightSound = @"SD_KNT_MUSIC_RIGHT";

// The difficulty scroll-change sound.
static NSString *const kMusicSelectSound = @"SD_KNT_MUSIC_SELECT";

// The start-button images: the plain start button, the random-select variant, and the single-play
// variant, chosen from the app's random and hold flags.
static NSString *const kStartButtonImage = @"menu_button_start_knt";
static NSString *const kRandomButtonImage = @"menu_button_random_knt";
static NSString *const kSingleButtonImage = @"menu_button_single_knt";

// The host-share button's restored background image after a cancelled host share.
static NSString *const kHostButtonImage = @"menu_button_host_knt";

// The preferred-difficulty user default; a value above extreme (2) is snapped back to basic (0).
static NSString *const kPrefDifficultyKey = @"PrefDifficulty";

// The scroll button fades out across an eighth of the half-width scroll span.
static const float kScrollFadeSpanFraction = 0.125f;

// An unselected difficulty button dims to this alpha and shrinks to this scale; the selected one is
// shown full and unscaled.
static const CGFloat kDiffButtonDimAlpha = 0.4;  // @ghidraAddress 0x28f2c0
static const CGFloat kDiffButtonDimScale = 0.95; // @ghidraAddress 0x28f6e0
enum { kDiffButtonCount = 3, kExtendButtonIndex = 3 };

// The level image is shown behind the fourth (extend) difficulty's level-number view.
enum { kExtendLevelNumIndex = 3 };

// The music bar holds 120 dot views; each dot's sprite comes from a 4-bit nibble in the dot map and
// its image row from a 2-bit value in the resource map.
enum {
    kMusicBarDotCount = 120,
    kMusicBarDotSpriteCount = 8,
};

// The download-selection preference remembers that the download entry was chosen (value 2).
static NSString *const kPrefJcfDownloadSelectKey = @"PrefJcfDownloadSelect";
static const NSInteger kJcfDownloadSelectDownload = 2;

// The edit-selection preference records the page the difficulty scroll settled on.
static NSString *const kPrefEditSelectKey = @"PrefEditSelect";

// The packed extend-chart sequence entries and the archive trailer length.
static NSString *const kExtendSeqBasic = @"seq_bas";
static NSString *const kExtendSeqAdvanced = @"seq_adv";
static NSString *const kExtendSeqExtreme = @"seq_ext";
static const NSUInteger kExtendArchiveTail = 16;

// Each difficulty's extend music-bar row is 60 bytes wide within extendMbarDots[3][60]; the base
// music bars share the same three-row layout in mbarDots.
enum {
    kMbarBasicRow = 0,
    kMbarAdvancedRow = 1,
    kMbarExtremeRow = 2,
};

// The packed content-dictionary keys for the artwork, the tune-name plate, and the three charts.
static NSString *const kContentArtwork = @"artwork_s";
static NSString *const kContentNameB = @"name_b";
static NSString *const kContentSeqBasic = @"seq_bas";
static NSString *const kContentSeqAdvanced = @"seq_adv";
static NSString *const kContentSeqExtreme = @"seq_ext";

// The packed archive members: a full-size artwork on the pad and retina phone, a small one on the
// non-retina phone, plus the tune-name plate. The archive trailer is 16 bytes.
static NSString *const kArchiveArtworkFull = @"artwork";
static NSString *const kArchiveArtworkSmall = @"artwork_s";
static NSString *const kArchiveNameB = @"name_b";
static const NSUInteger kContentArchiveTail = 16;

// The reflection image's height is this fraction of the artwork's on the pad idiom; the phone uses
// the shared 0.2 fraction.
static const double kReflectionFractionPad = 0.3; // @ghidraAddress 0x28f248

// The upload sheet's dimming cover is translucent black; both fade in over a fifth of a second.
static const CGFloat kUploadCoverScrimAlpha = 0.3;     // @ghidraAddress 0x28f248
static const NSTimeInterval kUploadFadeDuration = 0.2; // @ghidraAddress 0x28e040

// The host-share prompt fades out over three tenths of a second when the share is cancelled.
static const NSTimeInterval kHostShareCancelFadeDuration = 0.3; // @ghidraAddress 0x28f260

// The random-select marker slides up ten points out of view when the random flag turns off; the
// toggle animates over three tenths of a second.
static const int kRandViewSlideOffset = 10;
static const NSTimeInterval kRandViewToggleDuration = 0.3; // @ghidraAddress 0x28f260

// Entering the editor dims and shrinks the difficulty buttons to a tenth over six tenths of a
// second, then re-enables input seven tenths of a second in.
static const CGFloat kEditButtonShrinkScale = 0.1;         // @ghidraAddress 0x28f2b8
static const NSTimeInterval kEditTransitionDuration = 0.6; // @ghidraAddress 0x28f288
static const NSTimeInterval kEditInputLockDuration = 0.7;  // @ghidraAddress 0x28f2a0

// The upload sheet fades out on this (negative, as the binary stores it) duration when the upload
// ends.
static const NSTimeInterval kUploadEndFadeDuration = -0.2; // @ghidraAddress 0x28e050

// The high-score text view's resting centre when the extend mode toggles: its x starts from a
// per-idiom base plus 40 points and its y sits slightly above the origin.
static const double kHighscoreBaseXPad = 56.0;             // @ghidraAddress 0x28f878
static const double kHighscoreBaseXRetina = 30.0;          // fmov d0, 30.0
static const double kHighscoreBaseXNonRetina = 33.0;       // @ghidraAddress 0x293328
static const double kHighscoreCenterXNudge = 40.0;         // @ghidraAddress 0x28f1f8
static const double kHighscoreCenterYPad = -7.0;           // fmov d0, -7.0
static const double kHighscoreCenterYPhone = -6.0;         // fmov d0, -6.0
static const NSTimeInterval kExtendModeAnimDuration = 0.3; // @ghidraAddress 0x28f260
static const NSTimeInterval kExtendModeInputLock = 0.4;    // @ghidraAddress 0x28f2c0

// The share-message label drops six points to make room for the progress bar; the show/hide
// animates over three tenths of a second.
static const double kShareLabelDropOffset = 6.0;              // fmov d1, 6.0
static const NSTimeInterval kShareProgressAnimDuration = 0.3; // @ghidraAddress 0x28f260

// The edit music bar uses the fourth music-bar image, its dot data spans 60 bytes, and its
// user-tag badge (blank/staff/artist) sits inset from the extend button's right edge.
enum { kEditMbarBackgroundImage = 3 };
static const NSUInteger kEditMbarDataLength = 60;
static NSString *const kUserTagIconNames[] = {
    @"list_icon_user_blank", @"icon_user_staff", @"icon_user_artist"};
static const double kUserTagInsetPad = 10.0;  // fmov d0, 10.0
static const double kUserTagInsetPhone = 6.0; // fmov d0, 6.0
static const double kUserTagTopPad = 22.0;    // fmov d1, 22.0
static const double kUserTagTopPhone = 12.0;  // fmov d0, 12.0

// The rating images, indexed by SequenceRank (E, D, C, B, A, S, SS, SSS).
static NSString *const kRatingImageNames[] = {@"msc_rate_e_knt",
                                              @"msc_rate_d_knt",
                                              @"msc_rate_c_knt",
                                              @"msc_rate_b_knt",
                                              @"msc_rate_a_knt",
                                              @"msc_rate_s_knt",
                                              @"msc_rate_ss_knt",
                                              @"msc_rate_sss_knt"};

// The high-score digit and level number image name formats; the level number is 1-based.
static NSString *const kHighscoreDigitFormat = @"msc_high_score_%d_knt";
static NSString *const kLevelNumberFormat = @"lv_%02d_knt";
enum { kLevelImageCount = 10 };

// The four music-bar bars, each resizable with per-idiom cap insets, and the mini-dot grid format.
static NSString *const kMusicBarNames[] = {
    @"mini_bar_b_knt", @"mini_bar_a_knt", @"mini_bar_e_knt", @"mini_bar_o_knt"};
static NSString *const kMiniDotFormat = @"mini_dot_%d_%d_knt";
static const CGFloat kMusicBarCapInsetPad = 48.0;   // @ghidraAddress 0x28f450
static const CGFloat kMusicBarCapInsetPhone = 32.0; // @ghidraAddress 0x28f458

// The full-combo and excellent mark images.
static NSString *const kFullcomboImageName = @"msc_fullcombo_knt";
static NSString *const kExcellentImageName = @"msc_excellent_knt";

// The seven high-score digits are rendered with a right-justified %7d and mapped through
// highscoreNumImg; the score board's rating uses the excellent image at a perfect score.
enum {
    kHighscoreDigitCount = 7,
    kExcellentScore = 1000000,
    kDigitGlyphCount = 10,
};
static const char kDigitZero = '0';

// The extend-icon crossfade runs over three tenths of a second.
static const NSTimeInterval kExtendCrossFadeDuration = 0.3; // @ghidraAddress 0x28f260

// The client's message while it waits for the host to start the shared play.
static NSString *const kWaitingForHostKey = @"Waiting for host to start";

// The host's message while it waits for a client to join, and the button imagery and cues for the
// host-share start/cancel flow.
static NSString *const kWaitingForClientKey = @"Waiting for client";
static NSString *const kCancelButtonImage = @"menu_button_cancel_knt";
static NSString *const kHostShareCancelSound = @"SD_KNT_SKIP";
static const NSTimeInterval kHostShareStartFadeDuration = 0.3; // @ghidraAddress 0x28f260

// Starting play shrinks the unselected difficulty buttons to a tenth over six tenths of a second,
// then re-enables input seven tenths of a second in.
static const CGFloat kStartPlayShrinkScale = 0.1;               // @ghidraAddress 0x28f2b8
static const NSTimeInterval kStartPlayTransitionDuration = 0.6; // @ghidraAddress 0x28f288
static const NSTimeInterval kStartPlayInputLockDuration = 0.7;  // @ghidraAddress 0x28f2a0

// The pad edit-file popover is 300x400 points.
static const double kEditPopoverWidth = 300.0;  // @ghidraAddress 0x28f2d0
static const double kEditPopoverHeight = 400.0; // @ghidraAddress 0x28f2e0

// A chart level is stored as a zero-based level-image index: an unset level (below 2) maps to the
// first image, and any level of 10 or more clamps to the last of the ten level images.
static inline char MusicDetailViewKntLevelIndex(int level) {
    if (level < 2) {
        return 0;
    }
    if (level < 10) {
        return (char)(level - 1);
    }
    return 9;
}

// Dims and shrinks every base difficulty button except the selected one, used when play starts.
// The extend button (index 3) is left untouched.
static inline void MusicDetailViewKntDimUnselectedButtons(MusicDetailViewKnt *self, int selected) {
    CATransform3D shrink =
        CATransform3DMakeScale(kStartPlayShrinkScale, kStartPlayShrinkScale, 1.0);
    for (int i = 0; i < kDiffButtonCount; ++i) {
        if (i != selected) {
            [self->btnDiff[i] setAlpha:0.0];
            self->btnDiff[i].layer.transform = shrink;
        }
    }
}

// Pre-seeds one difficulty row's extend marks before the crossfade: reveals the extend and
// extend-on marks and sets their starting alphas (the target mark full, the other transparent),
// then zeroes the hold mark. Used by changeExtend: for each difficulty that carries an extend
// chart, with extendOnTarget YES when the app is in extend mode.
static inline void
MusicDetailViewKntSeedExtendRow(MusicDetailViewKnt *self, int row, BOOL extendOnTarget) {
    [self->extendMark[row] setHidden:NO];
    [self->extendOnMark[row] setHidden:NO];
    [self->extendMark[row] setAlpha:(extendOnTarget ? 0.0 : 1.0)];
    [self->extendOnMark[row] setAlpha:(extendOnTarget ? 1.0 : 0.0)];
    [self->holdMark[row] setAlpha:0.0];
}

// The three scroll-settled delegate callbacks share this tail: it snaps the settled page,
// re-derives the hold flag from the current difficulty's hold mark (except on the edit page),
// refreshes the start button, records the page, and applies either the difficulty (snapping a stale
// extreme back to basic) on the detail page or the edit music bar on the edit page.
static inline void MusicDetailViewKntSettleScrollPage(MusicDetailViewKnt *self) {
    [self setEnableButton:YES];
    double width = self.scrollView.frame.size.width;
    int page = (int)((width * 0.5 + self.scrollView.contentOffset.x) / width);
    self.editPage = page;
    int difficulty = (int)[NSUserDefaults.standardUserDefaults integerForKey:kPrefDifficultyKey];
    BOOL holdHidden = self->holdMark[difficulty].isHidden;
    [JubeatAppDelegate.appDelegate setHoldFlag:(page != 1) && !holdHidden];
    [self refreshStartButton];
    if (self.isStarted) {
        return;
    }
    [NSUserDefaults.standardUserDefaults setInteger:page forKey:kPrefEditSelectKey];
    if (page == 0) {
        int detailDifficulty =
            (int)[NSUserDefaults.standardUserDefaults integerForKey:kPrefDifficultyKey];
        if (detailDifficulty > 2) {
            if (!self.isStarted) {
                [NSUserDefaults.standardUserDefaults setInteger:0 forKey:kPrefDifficultyKey];
            }
            detailDifficulty = 0;
        }
        [self changeDifficulty:detailDifficulty];
    } else {
        [self editMusicBar];
    }
    [self setStartButtonEnable];
}

@implementation MusicDetailViewKnt

/** @ghidraAddress 0x1955c4 */
+ (Class)layerClass {
    return [CAGradientLayer class];
}

/** @ghidraAddress 0x1999dc */
- (void)setInfo:(nullable TuneInfo *)info score:(nullable id)score {
    [super setInfo:info score:score];
    [[EditDataManager sharedManager] clearEditData];
    if (info == nil) {
        return;
    }
    self.levelBas = MusicDetailViewKntLevelIndex(info.lvBas);
    self.levelAdv = MusicDetailViewKntLevelIndex(info.lvAdv);
    self.levelExt = MusicDetailViewKntLevelIndex(info.lvExt);
    [self.buttonLink setEnabled:(info.iTunesURL != nil)];
    [self.buttonLink setHidden:(info.iTunesURL == nil)];
    [self.btnRecommendTwitter setHidden:NO];
    [self.btnRecommendFacebook setHidden:NO];
    [levelNumView[0] setImage:levelNumImg[self.levelBas]];
    [levelNumView[1] setImage:levelNumImg[self.levelAdv]];
    [levelNumView[2] setImage:levelNumImg[self.levelExt]];
    [levelNumView[kExtendLevelNumIndex] setImage:levelNumImg[self.levelExt]];
    [levelNumView[kExtendLevelNumIndex] setAlpha:0.0];
    [self resetScore];
    [self putScore:score];
    [self loadContentFromPath:info.filePath orData:nil];
    [self loadEditFile];
    [self resetTextField:(int)info.tuneID isFirst:YES];
    if (self.editPage != 0) {
        [self editMusicBar];
    }
}

/** @ghidraAddress 0x19a7f0 */
- (void)setExtendInfo:(nullable TuneInfo *)info score:(nullable id)score {
    [super setExtendInfo:info score:score];
    [self loadExtendMusicBar:info.filePath];
    for (int i = 0; i < kDiffButtonCount; ++i) {
        [holdMark[i] setHidden:YES];
        [extendMark[i] setHidden:YES];
        [extendOnMark[i] setHidden:YES];
    }
    self.extendLevelBas = MusicDetailViewKntLevelIndex(info.lvBas);
    self.extendLevelAdv = MusicDetailViewKntLevelIndex(info.lvAdv);
    self.extendLevelExt = MusicDetailViewKntLevelIndex(info.lvExt);
    if (info != nil) {
        // Each difficulty that carries an extend chart shows the on/off extend mark according to
        // the app's extend toggle.
        for (int i = 0; i < kDiffButtonCount; ++i) {
            if ((info.extendFlag & (1 << i)) != 0) {
                BOOL extendOn = JubeatAppDelegate.appDelegate.isExtend;
                [extendMark[i] setHidden:extendOn];
                [extendOnMark[i] setHidden:!extendOn];
            }
        }
    }
    if (score != nil) {
        [self putExtendScore:score];
    }
}

/** @ghidraAddress 0x1a0bb4 */
- (void)refreshStartButton {
    BOOL randomOn = JubeatAppDelegate.appDelegate.isRandom && !JubeatAppDelegate.appDelegate.isHold;
    if (randomOn == bRandomBak) {
        return;
    }
    bRandomBak = randomOn;

    // The start button shows the single-play image, or the start image when host-sharing; its
    // enabled state is preserved across the image swap.
    UIImage *image = self.isShared ? [self getStartImage] : [self getSingleImage];
    BOOL wasEnabled = self.buttonStartPlay.isEnabled;
    [self.buttonStartPlay setEnabled:YES];
    [self.buttonStartPlay setBackgroundImage:image forState:UIControlStateNormal];
    [self.buttonStartPlay setEnabled:wasEnabled];

    // The random marker rests in place when random is on and slides up out of view when off.
    if (randomOn) {
        [self.randView
            setTransform:CGAffineTransformMakeTranslation(0.0, -(double)kRandViewSlideOffset)];
    } else {
        [self.randView setTransform:CGAffineTransformIdentity];
    }

    __weak MusicDetailViewKnt *weakSelf = self;
    [UIView animateWithDuration:kRandViewToggleDuration
                     animations:^{
                       /** @ghidraAddress 0x1a0f18 */
                       [weakSelf.randView setAlpha:(randomOn ? 1.0 : 0.0)];
                       if (randomOn) {
                           [weakSelf.randView setTransform:CGAffineTransformIdentity];
                       } else {
                           [weakSelf.randView setTransform:CGAffineTransformMakeTranslation(
                                                               0.0, -(double)kRandViewSlideOffset)];
                       }
                     }
                     completion:nil];
}

/** @ghidraAddress 0x19e384 */
- (void)hostShareCancelled {
    [self.buttonHostSharePlay
        setBackgroundImage:[[ImageCache sharedCache] getResPNG:kHostButtonImage]
                  forState:UIControlStateNormal];
    [self.buttonStartPlay setEnabled:YES];
    [self setStartButtonEnable];
    [self.buttonStartPlay setBackgroundImage:[self getSingleImage] forState:UIControlStateNormal];
    [self.buttonLink setEnabled:YES];
    [self.btnRecommendTwitter setEnabled:YES];
    [self.btnRecommendFacebook setEnabled:YES];

    __weak MusicDetailViewKnt *weakSelf = self;
    [UIView animateWithDuration:kHostShareCancelFadeDuration
        animations:^{
          /** @ghidraAddress 0x19e68c */
          [weakSelf.labelShareMessage setAlpha:0.0];
          [weakSelf.buttonHostSharePlay setEnabled:NO];
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x19e778 */
          [weakSelf.labelShareMessage setHidden:YES];
          [weakSelf.buttonHostSharePlay setEnabled:YES];
        }];
}

/** @ghidraAddress 0x19fa54 */
- (void)uploadStart {
    [[AudioManager sharedManager] playSeResFile:kMusicSelectSound inDirectory:nil];

    // The dimming cover fills the card, translucent black, and starts transparent.
    topcover = [[UIView alloc] initWithFrame:self.bounds];
    [topcover setCenter:CGPointMake(self.bounds.size.width * 0.5, self.bounds.size.height * 0.5)];
    [topcover setOpaque:NO];
    [topcover setBackgroundColor:[UIColor colorWithWhite:0 alpha:kUploadCoverScrimAlpha]];

    // The upload sheet is built from the current custom chart data and centred over the card.
    NSData *customData = [[EditDataManager sharedManager] getCurrentCustomData];
    upLoadView = [[JcfUpLoadView alloc] initWithData:customData delegate:self ctrl:self.controller];
    [upLoadView setCenter:CGPointMake(self.frame.size.width * 0.5, self.frame.size.height * 0.5)];
    [topcover setAlpha:0.0];
    [upLoadView setAlpha:0.0];
    [self addSubview:topcover];
    [self addSubview:upLoadView];

    __weak UIView *weakCover = topcover;
    __weak JcfUpLoadView *weakUpload = upLoadView;
    [UIView animateWithDuration:kUploadFadeDuration
                     animations:^{
                       /** @ghidraAddress 0x19fe28 */
                       [weakUpload setAlpha:1.0];
                       [weakCover setAlpha:1.0];
                     }
                     completion:nil];
    [self.controller unenableCoverTap];
}

/** @ghidraAddress 0x198628 */
- (nullable UIButton *)diffButton:(nullable NSString *)imageName {
    UIImage *image = LoadScaledPngImage(imageName);
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setFrame:CGRectMake(0.0, 0.0, image.size.width, image.size.height)];
    [button setImage:image forState:UIControlStateNormal];
    [button setExclusiveTouch:YES];
    [button setAdjustsImageWhenHighlighted:NO];
    [button setAdjustsImageWhenDisabled:NO];
    [button addTarget:self
                  action:@selector(selectDiff:)
        forControlEvents:UIControlEventTouchUpInside];
    return button;
}

/** @ghidraAddress 0x198de8 */
- (void)loadContentFromDictionary:(nullable NSDictionary *)dict {
    UIImage *artwork = [UIImage imageWithData:dict[kContentArtwork]];
    if (artwork != nil) {
        [self.artworkView setImage:artwork];
        double fraction = self.isPad ? kReflectionFractionPad : g_dAnimDuration020;
        int reflectionHeight = (int)(artwork.size.height * fraction);
        [self.reflectionArtworkView setImage:CreateReflectedImage(artwork, reflectionHeight)];
    }
    UIImage *nameImage = [UIImage imageWithData:dict[kContentNameB]];
    if (nameImage != nil) {
        [self.tuneNameView setImage:nameImage];
    }
    if (dict[kContentSeqBasic] != nil) {
        [Sequence getMusicBarData:mbarDots[kMbarBasicRow] raw:dict[kContentSeqBasic]];
    }
    if (dict[kContentSeqAdvanced] != nil) {
        [Sequence getMusicBarData:mbarDots[kMbarAdvancedRow] raw:dict[kContentSeqAdvanced]];
    }
    if (dict[kContentSeqExtreme] != nil) {
        [Sequence getMusicBarData:mbarDots[kMbarExtremeRow] raw:dict[kContentSeqExtreme]];
    }
}

/** @ghidraAddress 0x19bdd8 */
- (void)setScoreBoard:(int)score fullcombo:(BOOL)fullcombo {
    char digits[8] = {
        kDigitZero, kDigitZero, kDigitZero, kDigitZero, kDigitZero, kDigitZero, kDigitZero, 0};
    if (score < 0) {
        [ratingView setImage:nil];
        [comboView setImage:nil];
    } else if (score < kExcellentScore) {
        SequenceRank rank = [Sequence rankOfPoint:score];
        [ratingView setImage:ratingImg[rank]];
        [comboView setImage:(fullcombo ? fullcomboImg : nil)];
        snprintf(digits, sizeof(digits), "%7d", score);
    } else {
        [ratingView setImage:nil];
        [comboView setImage:excellentImg];
        snprintf(digits, sizeof(digits), "%7d", score);
    }
    for (int i = 0; i < kHighscoreDigitCount; ++i) {
        int glyph = digits[i] - kDigitZero;
        UIImage *image = ((unsigned int)glyph < kDigitGlyphCount) ? highscoreNumImg[glyph] : nil;
        [highscoreNumView[i] setImage:image];
    }
}

/** @ghidraAddress 0x19fff0 */
- (void)editStart {
    [[AudioManager sharedManager] playSeResFile:kEditSelectSound inDirectory:nil];
    [self.controller showButtonMarker:NO];
    [self.buttonStartPlay setEnabled:NO];

    __weak MusicDetailViewKnt *weakSelf = self;
    [UIView animateWithDuration:kEditTransitionDuration
        delay:0.0
        options:UIViewAnimationOptionBeginFromCurrentState
        animations:^{
          /** @ghidraAddress 0x1a0220 */
          CATransform3D shrink =
              CATransform3DMakeScale(kEditButtonShrinkScale, kEditButtonShrinkScale, 1.0);
          for (int i = 0; i < kDiffButtonCount; ++i) {
              [self->btnDiff[i] setAlpha:0.0];
              self->btnDiff[i].layer.transform = shrink;
          }
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x1a03bc */
          [weakSelf.controller startEdit:weakSelf.info];
        }];

    // Input is ignored through the transition and re-enabled a beat after it ends.
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    [[UIApplication sharedApplication] performSelector:@selector(endIgnoringInteractionEvents)
                                            withObject:nil
                                            afterDelay:kEditInputLockDuration];
}

/** @ghidraAddress 0x19e864 */
- (void)showDataProgress:(BOOL)show animated:(BOOL)animated {
    CGAffineTransform labelDrop = CGAffineTransformMakeTranslation(0.0, kShareLabelDropOffset);
    if (!animated) {
        if (show) {
            [self.shareDataProgress setHidden:NO];
            [self.shareDataProgress setAlpha:1.0];
            [self.shareDataProgress setProgress:0.0];
            [self.labelShareMessage setTransform:labelDrop];
        } else {
            [self.shareDataProgress setHidden:YES];
            [self.shareDataProgress setAlpha:0.0];
            [self.labelShareMessage setTransform:CGAffineTransformIdentity];
        }
        return;
    }

    __weak MusicDetailViewKnt *weakSelf = self;
    if (show) {
        [self.shareDataProgress setHidden:NO];
        [self.shareDataProgress setAlpha:0.0];
        [self.shareDataProgress setProgress:0.0];
        [UIView animateWithDuration:kShareProgressAnimDuration
                         animations:^{
                           /** @ghidraAddress 0x19ec40 */
                           [weakSelf.shareDataProgress setAlpha:1.0];
                           [weakSelf.labelShareMessage setTransform:labelDrop];
                         }];
    } else {
        [UIView animateWithDuration:kShareProgressAnimDuration
            animations:^{
              /** @ghidraAddress 0x19ed24 */
              [weakSelf.shareDataProgress setAlpha:0.0];
              [weakSelf.labelShareMessage setTransform:CGAffineTransformIdentity];
            }
            completion:^(BOOL finished) {
              /** @ghidraAddress 0x19ee04 */
              [weakSelf.shareDataProgress setHidden:YES];
            }];
    }
}

/** @ghidraAddress 0x1a3b8c */
- (void)changeExtendMode {
    if (self.info.extendID != 0) {
        int difficulty =
            (int)[NSUserDefaults.standardUserDefaults integerForKey:kPrefDifficultyKey];
        if (self.extendInfo != nil && (self.extendInfo.extendFlag & (1 << difficulty)) != 0) {
            // Flip the app-wide extend toggle, re-lay the extend info, and reposition the score
            // board for the new mode.
            [JubeatAppDelegate.appDelegate setExtendFlag:!JubeatAppDelegate.appDelegate.isExtend];
            [[AudioManager sharedManager] playSeResFile:kMusicRightSound inDirectory:nil];
            [self changeExtend:difficulty];

            double baseX;
            double centerY;
            if (self.isPad) {
                baseX = kHighscoreBaseXPad;
                centerY = kHighscoreCenterYPad;
            } else {
                baseX = self.isRetina ? kHighscoreBaseXRetina : kHighscoreBaseXNonRetina;
                centerY = kHighscoreCenterYPhone;
            }
            [highscoreTextView setCenter:CGPointMake(baseX + kHighscoreCenterXNudge, centerY)];
            [highscoreBoardView setAlpha:0.0];
            [NSUserDefaults.standardUserDefaults setInteger:difficulty forKey:kPrefDifficultyKey];

            [UIView animateWithDuration:kExtendModeAnimDuration
                             animations:^{
                               /** @ghidraAddress 0x1a3f1c */
                               [self changeDifficulty:difficulty];
                               double bx;
                               double cy;
                               if (self.isPad) {
                                   bx = kHighscoreBaseXPad;
                                   cy = kHighscoreCenterYPad;
                               } else {
                                   bx = self.isRetina ? kHighscoreBaseXRetina :
                                                        kHighscoreBaseXNonRetina;
                                   cy = kHighscoreCenterYPhone;
                               }
                               [self->highscoreTextView
                                   setCenter:CGPointMake(bx + kHighscoreCenterXNudge, cy)];
                               [self->highscoreBoardView setAlpha:1.0];
                             }];
        }
    }
    // Input is briefly locked out while the mode change settles.
    [[UIApplication sharedApplication] performSelector:@selector(endIgnoringInteractionEvents)
                                            withObject:nil
                                            afterDelay:kExtendModeInputLock];
}

/** @ghidraAddress 0x1a3690 */
- (void)uploadEnd:(nullable id)sender {
    __weak UIView *weakCover = topcover;
    __weak JcfUpLoadView *weakUpload = upLoadView;
    // The binary passes a negative fade duration here; kept as-is.
    [UIView animateWithDuration:kUploadEndFadeDuration
        animations:^{
          /** @ghidraAddress 0x1a3834 */
          [weakUpload setAlpha:0.0];
          [weakCover setAlpha:0.0];
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x1a38fc */
          [self removeUploadView];
        }];
    [self.controller enableCoverTap];
}

/** @ghidraAddress 0x19b3d0 */
- (void)clearInfo {
    [self.artworkView setImage:nil];
    [self.reflectionArtworkView setImage:nil];
    [self.tuneNameView setImage:nil];
    [self.controller dismissViewControllerAnimated:NO completion:nil];
}

/** @ghidraAddress 0x19ff00 */
- (void)pushButtonUpload:(nullable id)sender {
    if ([self checkEnableUpload]) {
        [self uploadStart];
    }
}

/** @ghidraAddress 0x19ff44 */
- (void)pushButtonEdit:(nullable id)sender {
    [self editStart];
}

/** @ghidraAddress 0x19ff50 */
- (void)editFileListViewSelectEdit {
    [[AudioManager sharedManager] playSeResFile:kEditSelectSound inDirectory:nil];
    [self.controller dismissViewControllerAnimated:YES completion:nil];
    [self editStart];
}

/** @ghidraAddress 0x1a1054 */
- (void)scrollViewWillBeginDragging:(nullable UIScrollView *)scrollView {
}

/** @ghidraAddress 0x1a1ce8 */
- (BOOL)checkDownloadFile {
    if ([[EditDataManager sharedManager] getLastEditFileName:(int)self.info.tuneID] == nil) {
        return YES;
    }
    return [EditDataManager sharedManager].bIsDownload;
}

/** @ghidraAddress 0x1a1fc0 */
- (void)loadListRelease {
    [self.pFileListView setDelegate:nil];
    self.pFileListView = nil;
}

/** @ghidraAddress 0x1a2e30 */
- (void)selectEditFile:(nullable id)fileName {
    [[EditDataManager sharedManager] setLastEditFileName:(int)self.info.tuneID fileName:fileName];
    [self.controller enableCoverTap];
}

/** @ghidraAddress 0x1a2f0c */
- (void)popoverPresentationControllerDidDismissPopover:
    (nullable UIPopoverPresentationController *)popoverPresentationController {
    [self loadListRelease];
    [self.controller enableCoverTap];
}

/** @ghidraAddress 0x1a2f60 */
- (void)editFileListViewCancel:(nullable id)sender {
    [self.controller enableCoverTap];
    [self.controller dismissViewControllerAnimated:YES completion:nil];
}

/** @ghidraAddress 0x1a2fe4 */
- (void)errorSequenceDownload:(nullable id)sender {
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil];
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:nil
                                            tag:0
                                          title:nil
                                            msg:kConnectErrorMessage
                                         cancel:ok
                                        btnText:nil
                                           show:YES];
}

/** @ghidraAddress 0x1a30c4 */
- (void)finishedSequenceDownload:(nullable id)sender {
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil];
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:nil
                                            tag:0
                                          title:nil
                                            msg:kDownloadFinishedMessage
                                         cancel:ok
                                        btnText:nil
                                           show:YES];
}

/** @ghidraAddress 0x1a31a4 */
- (void)finishedSequenceOverCap:(nullable id)sender {
    NSString *ok = [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil];
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:nil
                                            tag:0
                                          title:nil
                                            msg:kDownloadFinishedMessage
                                         cancel:ok
                                        btnText:nil
                                           show:YES];
}

/** @ghidraAddress 0x19d4f8 */
- (void)setEnableButton:(BOOL)enable {
    [btnDiff[0] setEnabled:enable];
    [btnDiff[1] setEnabled:enable];
    [btnDiff[2] setEnabled:enable];
    [btnDiff[3] setEnabled:enable];
    [infoBtn setEnabled:enable];
    [uploadBtn setEnabled:enable];
    [editBtn setEnabled:enable];
    [detailScrollButton[0] setEnabled:enable];
    [detailScrollButton[1] setEnabled:enable];
    if (enable) {
        [infoBtn setEnabled:[self checkEnableInfoChange]];
        [uploadBtn setEnabled:[self checkEnableUpload]];
        [editBtn setEnabled:[self checkEnableEdit]];
    }
}

/** @ghidraAddress 0x19f870 */
- (void)editFileListViewSelectDownload {
    [[AudioManager sharedManager] playSeResFile:kMusicRightSound inDirectory:nil];
    [NSUserDefaults.standardUserDefaults setInteger:kJcfDownloadSelectDownload
                                             forKey:kPrefJcfDownloadSelectKey];
    [self.controller dismissViewControllerAnimated:self.isPad completion:nil];
    self.jcfDownloadPage = [[JcfDownloadPageNavController alloc] initWithMusicID:self.info.tuneID
                                                                        delegate:self];
    [self.controller presentViewController:self.jcfDownloadPage animated:YES completion:nil];
}

/** @ghidraAddress 0x1a1c2c */
- (void)selectUpdate:(nullable id)sender {
    [self.controller dismissViewControllerAnimated:YES
                                        completion:^{
                                          /** @ghidraAddress 0x1a1cc8 */
                                          [self uploadStart];
                                        }];
}

/** @ghidraAddress 0x1a285c */
- (void)editFileListViewSelectNewFile {
    [NSUserDefaults.standardUserDefaults setInteger:kJcfDownloadSelectDownload
                                             forKey:kPrefJcfDownloadSelectKey];
    [self selectEditFile:@""];
    [self resetTextField:(int)self.info.tuneID isFirst:NO];
    [[EditDataManager sharedManager] resetEditorInfo];
    [self.controller dismissViewControllerAnimated:YES completion:nil];
    [self editMusicBar];
    [self editStart];
    [[AudioManager sharedManager] playSeResFile:kEditSelectSound inDirectory:nil];
}

/** @ghidraAddress 0x1a2c3c */
- (void)editFileListViewDeleteFile:(nullable id)fileName {
    EditDataManager *manager = [EditDataManager sharedManager];
    NSString *lastEdit = [manager getLastEditFileName:(int)self.info.tuneID];
    NSString *path =
        [[manager getDirectoryPath:(int)self.info.tuneID] stringByAppendingPathComponent:fileName];
    [manager deleteJCF:path];
    if ([lastEdit isEqualToString:fileName]) {
        [manager clearEditData];
        [self editMusicBar];
        [self resetTextField:(int)self.info.tuneID isFirst:NO];
        [self setStartButtonEnable];
    }
}

/** @ghidraAddress 0x19c608 */
- (void)setMusicBarDot:(nullable char *)dots mbarRes:(nullable char *)mbarRes {
    if (dots == nullptr) {
        for (int i = 0; i < kMusicBarDotCount; ++i) {
            [mbarDotView[i] setImage:nil];
        }
        return;
    }
    for (int i = 0; i < kMusicBarDotCount; ++i) {
        int row = 0;
        if (mbarRes != nullptr) {
            row = (mbarRes[i >> 2] >> ((i & 3) * 2)) & 3;
        }
        int sprite = ((dots[i >> 1] >> ((i & 1) * 4)) & 0xf) - 1;
        UIImage *image =
            ((unsigned int)sprite < kMusicBarDotSpriteCount) ? mbarDotImg[row][sprite] : nil;
        [mbarDotView[i] setImage:image];
    }
}

/** @ghidraAddress 0x19d678 */
- (void)setStartButtonEnable {
    if (self.editPage == 1) {
        int notesNum = [[EditDataManager sharedManager].getEditorInfo[@"notesNum"] intValue];
        [uploadBtn setEnabled:[self checkEnableUpload]];
        [editBtn setEnabled:[self checkEnableEdit]];
        [infoBtn setEnabled:[self checkEnableInfoChange]];
        if (notesNum == 0) {
            [self.buttonStartPlay setEnabled:NO];
            return;
        }
    }
    [self.buttonStartPlay setEnabled:YES];
    if (self.controller.sharePlayManager != nil && !self.isSharedStartable) {
        [self.buttonStartPlay setEnabled:NO];
    }
}

/** @ghidraAddress 0x1a1dd8 */
- (void)pushInfoEdit:(nullable id)sender {
    if (![self checkDownloadFile] && self.isPad) {
        [[AudioManager sharedManager] playSeResFile:kMusicRightSound inDirectory:nil];
        if (self.pEditModalView != nil) {
            self.pEditModalView = nil;
        }
        self.pEditModalView = [[EditModalView alloc] initWithType:0];
        [self.pEditModalView setEditDelegate:self];
        self.isEditInfoOpen = YES;
        [self.controller presentViewController:self.pEditModalView animated:YES completion:nil];
        [self.controller unenableCoverTap];
    }
}

/** @ghidraAddress 0x1a32bc */
- (void)customWebViewClose:(nullable id)webView seqIndex:(nullable id)seqIndex {
    [self resetTextField:(int)self.info.tuneID isFirst:NO];
    [self setStartButtonEnable];
    [[AudioManager sharedManager] playSeResFile:kMusicLeftSound inDirectory:nil];
    [self.controller enableCoverTap];
    [self.controller dismissViewControllerAnimated:YES completion:nil];
}

/** @ghidraAddress 0x1a3fe0 */
- (CGPoint)getDifficultyPos:(int)difficulty {
    int index = (difficulty > 2) ? 0 : difficulty;
    int scrollY = (int)self.scrollView.frame.origin.y;
    int buttonX = (int)btnDiff[index].frame.origin.x;
    int scrollX = (int)self.scrollView.frame.origin.x;
    int buttonY = (int)btnDiff[index].frame.origin.y;
    return CGPointMake((double)(int)((double)scrollX + (double)buttonX),
                       (double)(int)((double)scrollY + (double)buttonY));
}

/** @ghidraAddress 0x199708 */
- (void)loadExtendMusicBar:(nullable NSString *)path {
    BFCodec *codec = [[BFCodec alloc] init];
    NSData *cipherKey = GetBgmCipherKey();
    [codec cipherInit:cipherKey];
    if (path == nil) {
        return;
    }
    KUnzip *archive = [[KUnzip alloc] initWithPath:path tail:kExtendArchiveTail];
    if (archive == nil) {
        return;
    }

    [codec cipherInit:cipherKey];
    NSMutableData *seqBas = [archive uncompress:kExtendSeqBasic];
    [codec decipher:seqBas];
    [Sequence getMusicBarData:extendMbarDots[kExtendMbarBasicRow] raw:seqBas];

    [codec cipherInit:cipherKey];
    NSMutableData *seqAdv = [archive uncompress:kExtendSeqAdvanced];
    [codec decipher:seqAdv];
    [Sequence getMusicBarData:extendMbarDots[kExtendMbarAdvancedRow] raw:seqAdv];

    [codec cipherInit:cipherKey];
    NSMutableData *seqExt = [archive uncompress:kExtendSeqExtreme];
    [codec decipher:seqExt];
    [Sequence getMusicBarData:extendMbarDots[kExtendMbarExtremeRow] raw:seqExt];

    // A settled detail page re-applies the preferred difficulty once the bars are loaded.
    if ([NSUserDefaults.standardUserDefaults integerForKey:kPrefEditSelectKey] == 0) {
        int difficulty =
            (int)[NSUserDefaults.standardUserDefaults integerForKey:kPrefDifficultyKey];
        [self changeDifficulty:difficulty];
    }
}

/** @ghidraAddress 0x19c16c */
- (void)changeDifficulty:(int)difficulty {
    // The three base-difficulty buttons: the selected one is full and unscaled, the others dim and
    // shrink. The extend button (index 3) is always shown full.
    for (int i = 0; i < kDiffButtonCount; ++i) {
        if (i == difficulty) {
            [btnDiff[i] setAlpha:1.0];
            [btnDiff[i] setTransform:CGAffineTransformIdentity];
        } else {
            [btnDiff[i] setAlpha:kDiffButtonDimAlpha];
            [btnDiff[i]
                setTransform:CGAffineTransformMakeScale(kDiffButtonDimScale, kDiffButtonDimScale)];
        }
    }
    [btnDiff[kExtendButtonIndex] setAlpha:1.0];
    [btnDiff[kExtendButtonIndex] setTransform:CGAffineTransformIdentity];
    [self infoChange:difficulty];
}

/** @ghidraAddress 0x1a1058 */
- (void)scrollViewDidScroll:(nullable UIScrollView *)scrollView {
    float offsetX = (float)scrollView.contentOffset.x;
    float half = (float)(scrollView.contentSize.width * 0.5);
    float denom = half * kScrollFadeSpanFraction;
    float leftFade = MIN(offsetX / denom, 1.0f);
    [detailScrollButton[0] setAlpha:(double)(1.0f - leftFade)];
    float rightFade = MIN((half - offsetX) / denom, 1.0f);
    [detailScrollButton[1] setAlpha:(double)(1.0f - rightFade)];
}

/** @ghidraAddress 0x1a1134 */
- (void)scrollViewDidEndScrollingAnimation:(nullable UIScrollView *)scrollView {
    [detailScrollButton[0] setAlpha:1.0];
    [detailScrollButton[1] setAlpha:1.0];
    MusicDetailViewKntSettleScrollPage(self);
}

/** @ghidraAddress 0x1a1434 */
- (void)scrollViewDidEndDecelerating:(nullable UIScrollView *)scrollView {
    MusicDetailViewKntSettleScrollPage(self);
}

/** @ghidraAddress 0x1a16f8 */
- (void)scrollViewDidEndDragging:(nullable UIScrollView *)scrollView
                  willDecelerate:(BOOL)decelerate {
    if (!decelerate) {
        MusicDetailViewKntSettleScrollPage(self);
    }
}

/** @ghidraAddress 0x1a19c8 */
- (void)editModalViewClose:(nullable id)sender {
    [[AudioManager sharedManager] playSeResFile:kMusicRightSound inDirectory:nil];
    NSMutableDictionary *editorInfo = [[EditDataManager sharedManager] getEditorInfo];
    [editTxt[0] setText:editorInfo[@"fumenName"]];
    [editTxt[1] setText:editorInfo[@"editorName"]];
    [editTxt[2] setText:editorInfo[@"comment"]];
    int level = [editorInfo[@"level"] intValue];
    [levelNumView[kExtendLevelNumIndex] setImage:levelNumImg[level]];
    [levelNumView[kExtendLevelNumIndex] setAlpha:1.0];
    [self.controller dismissViewControllerAnimated:YES completion:nil];
    [self.controller enableCoverTap];
}

/** @ghidraAddress 0x1a046c */
- (void)pushButtonShare:(nullable id)sender {
    if (self.controller.sharePlayManager == nil) {
        // Begin hosting a share: swap the host button to a cancel image, lock the play and social
        // buttons, show the waiting prompt, and hand the packed chart to the controller.
        [[AudioManager sharedManager] playSeResFile:kMusicSelectSound inDirectory:nil];
        if (self.info != nil && self.info.filePath != nil) {
            [self.buttonHostSharePlay
                setBackgroundImage:[[ImageCache sharedCache] getResPNG:kCancelButtonImage]
                          forState:UIControlStateNormal];
            [self.buttonStartPlay setEnabled:NO];
            [self.buttonStartPlay setBackgroundImage:[self getStartImage]
                                            forState:UIControlStateNormal];
            [self.buttonLink setEnabled:NO];
            [self.btnRecommendTwitter setEnabled:NO];
            [self.btnRecommendFacebook setEnabled:NO];
            [self.labelShareMessage setHidden:NO];
            [self.labelShareMessage setAlpha:0.0];
            [self.labelShareMessage
                setText:[NSBundle.mainBundle localizedStringForKey:kWaitingForClientKey
                                                             value:@""
                                                             table:nil]];

            __weak MusicDetailViewKnt *weakSelf = self;
            [UIView animateWithDuration:kHostShareStartFadeDuration
                animations:^{
                  /** @ghidraAddress 0x1a0a70 */
                  [weakSelf.labelShareMessage setAlpha:1.0];
                  [weakSelf.buttonHostSharePlay setEnabled:NO];
                }
                completion:^(BOOL finished) {
                  /** @ghidraAddress 0x1a0b5c */
                  [weakSelf.buttonHostSharePlay setEnabled:YES];
                }];
            [self.controller startHostShare:[self infoDictForShare] filePath:self.info.filePath];
        }
    } else {
        // Already sharing: cancel it.
        [[AudioManager sharedManager] playSeResFile:kHostShareCancelSound inDirectory:nil];
        [self.controller cancelShare:NO];
        [self setIsSharedStartable:NO];
    }
    [self setEnableButton:YES];
}

/** @ghidraAddress 0x19ee70 */
- (void)pushButtonStartPlay:(nullable id)sender {
    if (!self.buttonStartPlay.isEnabled) {
        return;
    }
    self.isStarted = YES;
    double width = self.scrollView.frame.size.width;
    int page = self.editPage;
    [self.scrollView setScrollEnabled:NO];
    [self.scrollView setContentOffset:CGPointMake(width * (double)page, 0.0) animated:YES];
    int difficulty = (int)[NSUserDefaults.standardUserDefaults integerForKey:kPrefDifficultyKey];
    SharePlayManager *shareManager = self.controller.sharePlayManager;
    BOOL isHost = (shareManager != nil) && self.controller.sharePlayManager.isHost;
    [[AudioManager sharedManager] playSeResFile:kEditSelectSound inDirectory:nil];
    [self.controller showButtonMarker:NO];
    if (isHost) {
        [self.controller willStartPlay];
    }
    [self.buttonStartPlay setEnabled:NO];

    __weak MusicDetailViewKnt *weakSelf = self;
    BOOL hasShareManager = (shareManager != nil);
    [UIView animateWithDuration:kStartPlayTransitionDuration
        delay:0.0
        options:UIViewAnimationOptionBeginFromCurrentState
        animations:^{
          /** @ghidraAddress 0x19f304 */
          MusicDetailViewKntDimUnselectedButtons(self, difficulty);
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x19f5a4 */
          if (!hasShareManager) {
              [weakSelf.controller startPlay:weakSelf.info];
          } else if (!isHost) {
              [weakSelf.labelShareMessage
                  setText:[NSBundle.mainBundle localizedStringForKey:kWaitingForHostKey
                                                               value:@""
                                                               table:nil]];
              [weakSelf.controller.sharePlayManager sendClientReady];
              [weakSelf setIsSharedStartable:NO];
          } else {
              [weakSelf.controller.sharePlayManager sendSelectStart];
              [weakSelf.controller startPlay:weakSelf.info];
          }
        }];

    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    [[UIApplication sharedApplication] performSelector:@selector(endIgnoringInteractionEvents)
                                            withObject:nil
                                            afterDelay:kStartPlayInputLockDuration];
}

/** @ghidraAddress 0x19aca4 */
- (void)changeExtend:(int)difficulty {
    BOOL isExtend = JubeatAppDelegate.appDelegate.isExtend;
    // Every difficulty's hold and extend marks start hidden.
    for (int i = 0; i < kDiffButtonCount; ++i) {
        [holdMark[i] setHidden:YES];
        [extendMark[i] setHidden:YES];
        [extendOnMark[i] setHidden:YES];
    }
    if (self.extendInfo != nil) {
        // Reveal each difficulty that carries an extend chart, pre-seeding its marks so the
        // crossfade animates a real transition; the level numbers fade in from zero.
        float mix = 0.0f;
        unsigned int extendFlag = self.extendInfo.extendFlag;
        for (int i = 0; i < kDiffButtonCount; ++i) {
            if ((extendFlag & (1 << i)) != 0) {
                MusicDetailViewKntSeedExtendRow(self, i, isExtend);
                if (isExtend) {
                    mix = 1.0f;
                }
            }
            [levelNumView[i] setAlpha:0.0];
        }

        __weak MusicDetailViewKnt *weakSelf = self;
        [UIView animateWithDuration:kExtendCrossFadeDuration
                         animations:^{
                           /** @ghidraAddress 0x19b22c */
                           for (int i = 0; i < kDiffButtonCount; ++i) {
                               [weakSelf->levelNumView[i] setAlpha:1.0];
                               [weakSelf->extendMark[i] setAlpha:(1.0f - mix)];
                               [weakSelf->extendOnMark[i] setAlpha:mix];
                               [weakSelf->holdMark[i] setAlpha:1.0];
                           }
                         }];
    }
    [self infoChange:difficulty];
}

/** @ghidraAddress 0x1a201c */
- (void)editPopoverOpen {
    [self loadListRelease];
    [self.controller unenableCoverTap];
    EditDataManager *manager = [EditDataManager sharedManager];
    if (!self.isPad) {
        // The phone shows the edit-file list in a full nav controller.
        NSMutableArray *files = [manager getFileInfoList:self.info.tuneID];
        NSString *lastEdit = [manager getLastEditFileName:(int)self.info.tuneID];
        self.jcfMan = [[JcfManageNavController alloc] init:self fileList:files selName:lastEdit];
        [self.jcfMan setTuneID:self.info.tuneID];
        [self.jcfMan setShareFlg:(self.controller.sharePlayManager != nil)];
        [self.controller presentViewController:self.jcfMan animated:YES completion:nil];
        [[AudioManager sharedManager] playSeResFile:kMusicSelectSound inDirectory:nil];
        return;
    }
    // The pad shows a 300x400 delete-list, presented as a popover pointing up from the extend
    // difficulty button, or modally when not on a pad after all.
    if (self.pFileListView != nil) {
        return;
    }
    NSMutableArray *files = [manager getFileInfoList:self.info.tuneID];
    self.pFileListView = [[EditFileListViewDeleteController alloc]
        initWithSize:CGSizeMake(kEditPopoverWidth, kEditPopoverHeight)];
    [self.pFileListView setFileList:files];
    [self.pFileListView setDelegate:self];
    [self.pFileListView setTargetFileName:[manager getLastEditFileName:(int)self.info.tuneID]];
    [self.pFileListView setIsFirst:self.isFirstSelect];
    [self.pFileListView setIsShared:(self.controller.sharePlayManager != nil)];
    if (!self.isPad) {
        [self.controller presentViewController:self.pFileListView animated:YES completion:nil];
    } else {
        [self.pFileListView setModalPresentationStyle:UIModalPresentationPopover];
        UIPopoverPresentationController *popover = self.pFileListView.popoverPresentationController;
        [popover setDelegate:self];
        [popover setPermittedArrowDirections:UIPopoverArrowDirectionDown];
        [popover setSourceView:self.scrollView];
        [popover setSourceRect:btnDiff[kExtendButtonIndex].frame];
        [self.controller presentViewController:self.pFileListView animated:YES completion:nil];
    }
    [[AudioManager sharedManager] playSeResFile:kMusicSelectSound inDirectory:nil];
}

/** @ghidraAddress 0x198750 */
- (void)loadImages {
    @autoreleasepool {
        for (int i = 0; i < (int)(sizeof(kRatingImageNames) / sizeof(kRatingImageNames[0])); ++i) {
            ratingImg[i] = LoadScaledPngImage(kRatingImageNames[i]);
        }
        for (int i = 0; i < kLevelImageCount; ++i) {
            highscoreNumImg[i] =
                LoadScaledPngImage([NSString stringWithFormat:kHighscoreDigitFormat, i]);
            levelNumImg[i] =
                LoadScaledPngImage([NSString stringWithFormat:kLevelNumberFormat, i + 1]);
        }

        // The music-bar bars stretch from a resizable image with per-idiom cap insets.
        CGFloat capInset = self.isPad ? kMusicBarCapInsetPad : kMusicBarCapInsetPhone;
        UIEdgeInsets insets = UIEdgeInsetsMake(0, capInset, 0, capInset);
        for (int i = 0; i < (int)(sizeof(kMusicBarNames) / sizeof(kMusicBarNames[0])); ++i) {
            mbarBarImg[i] =
                [LoadScaledPngImage(kMusicBarNames[i]) resizableImageWithCapInsets:insets];
        }

        // The mini-dot grid: four rows of eight, named by (row, 1-based column).
        for (int row = 0; row < 4; ++row) {
            for (int col = 0; col < kMusicBarDotSpriteCount; ++col) {
                mbarDotImg[row][col] =
                    LoadScaledPngImage([NSString stringWithFormat:kMiniDotFormat, row, col + 1]);
            }
        }

        fullcomboImg = LoadScaledPngImage(kFullcomboImageName);
        excellentImg = LoadScaledPngImage(kExcellentImageName);
    }
}

/** @ghidraAddress 0x19917c */
- (void)loadContentFromPath:(nullable NSString *)path orData:(nullable NSData *)data {
    // The packed content comes from a file (skipping the 16-byte trailer) or, failing that, from an
    // in-memory range covering all but the trailer.
    KUnzip *archive = nil;
    if (path != nil) {
        archive = [[KUnzip alloc] initWithPath:path tail:kContentArchiveTail];
    }
    if (archive == nil) {
        if (data.length < kContentArchiveTail + 1) {
            return;
        }
        archive = [[KUnzip alloc] initWithData:data
                                         range:NSMakeRange(0, data.length - kContentArchiveTail)];
        if (archive == nil) {
            return;
        }
    }

    BFCodec *codec = [[BFCodec alloc] init];
    NSData *cipherKey = GetBgmCipherKey();
    [codec cipherInit:cipherKey];

    // The artwork: full-size on the pad and retina phone, small on the non-retina phone.
    NSString *artworkKey =
        (self.isPad || self.isRetina) ? kArchiveArtworkFull : kArchiveArtworkSmall;
    NSMutableData *artworkData = [archive uncompress:artworkKey];
    [codec decipher:artworkData];
    UIImage *artwork = [UIImage imageWithData:artworkData];
    if (artwork != nil) {
        [self.artworkView setImage:artwork];
        double fraction = self.isPad ? kReflectionFractionPad : g_dAnimDuration020;
        int reflectionHeight = (int)(artwork.size.height * fraction);
        [self.reflectionArtworkView setImage:CreateReflectedImage(artwork, reflectionHeight)];
    }

    [codec cipherInit:cipherKey];
    NSMutableData *nameData = [archive uncompress:kArchiveNameB];
    [codec decipher:nameData];
    UIImage *nameImage = [UIImage imageWithData:nameData];
    if (nameImage != nil) {
        [self.tuneNameView setImage:nameImage];
    }

    [codec cipherInit:cipherKey];
    NSMutableData *seqBas = [archive uncompress:kContentSeqBasic];
    [codec decipher:seqBas];
    [Sequence getMusicBarData:mbarDots[kMbarBasicRow] raw:seqBas];

    [codec cipherInit:cipherKey];
    NSMutableData *seqAdv = [archive uncompress:kContentSeqAdvanced];
    [codec decipher:seqAdv];
    [Sequence getMusicBarData:mbarDots[kMbarAdvancedRow] raw:seqAdv];

    [codec cipherInit:cipherKey];
    NSMutableData *seqExt = [archive uncompress:kContentSeqExtreme];
    [codec decipher:seqExt];
    [Sequence getMusicBarData:mbarDots[kMbarExtremeRow] raw:seqExt];

    // On the detail page, re-apply the preferred difficulty once the charts are loaded.
    if ([NSUserDefaults.standardUserDefaults integerForKey:kPrefEditSelectKey] == 0) {
        int difficulty =
            (int)[NSUserDefaults.standardUserDefaults integerForKey:kPrefDifficultyKey];
        [self changeDifficulty:difficulty];
    }
}

/** @ghidraAddress 0x19c72c */
- (void)editMusicBar {
    if (self.editPage == 0) {
        return;
    }
    EditDataManager *manager = [EditDataManager sharedManager];
    NSString *lastEdit = [manager getLastEditFileName:(int)self.info.tuneID];
    [mbarBarView setImage:mbarBarImg[kEditMbarBackgroundImage]];
    if (userTagIcon != nil) {
        [userTagIcon removeFromSuperview];
        userTagIcon = nil;
    }
    if (lastEdit == nil) {
        [self setMusicBarDot:nullptr mbarRes:nullptr];
        [ratingView setImage:nil];
        [comboView setImage:nil];
        [self setScoreBoard:-1 fullcombo:NO];
        return;
    }

    // The edit music bar comes from the simple edit data (60 bytes) with no resource overlay.
    char dots[64] = {0};
    NSData *musicBar = [manager getEditSimpleData][@"musicBar"];
    [musicBar getBytes:dots length:kEditMbarDataLength];
    [self setMusicBarDot:dots mbarRes:nullptr];

    // The score board reflects the edit's own best score and full-combo flag, if scored.
    NSMutableDictionary *scoreData = [manager getScoreData];
    int score = -1;
    BOOL fullcombo = NO;
    if (scoreData == nil) {
        [ratingView setImage:nil];
        [comboView setImage:nil];
    } else {
        score = [scoreData[@"bestScore"] intValue];
        fullcombo = [scoreData[@"fullcomboFlg"] boolValue];
    }
    [self setScoreBoard:score fullcombo:fullcombo];

    // A downloaded edit shows its author's user-tag badge, inset from the extend button's right
    // edge.
    NSMutableDictionary *editorInfo = [manager getEditorInfo];
    if (manager.bIsDownload) {
        int userTag = [editorInfo[@"userTag"] intValue];
        UIImage *badge = LoadScaledPngImage(kUserTagIconNames[userTag]);
        userTagIcon = [[UIImageView alloc] initWithImage:badge];
        double inset = self.isPad ? kUserTagInsetPad : kUserTagInsetPhone;
        double top = self.isPad ? kUserTagTopPad : kUserTagTopPhone;
        double x = btnDiff[kExtendButtonIndex].frame.size.width - badge.size.width - inset;
        [userTagIcon setFrame:CGRectMake(x, top, badge.size.width, badge.size.height)];
        [btnDiff[kExtendButtonIndex] addSubview:userTagIcon];
    }
}

/** @ghidraAddress 0x19c3d0 */
- (void)scrollChange:(nullable id)sender {
    if (self.isStarted) {
        return;
    }
    double width = self.scrollView.frame.size.width;
    double offsetX = self.scrollView.contentOffset.x;
    int page = (int)floor((width * 0.5 + offsetX) / width);
    double snapX = (page != 0) ? 0.0 : (double)(int)width;
    [self.scrollView setContentOffset:CGPointMake(snapX, 0.0) animated:YES];
    [self setEnableButton:NO];
    if (page == 1) {
        int difficulty =
            (int)[NSUserDefaults.standardUserDefaults integerForKey:kPrefDifficultyKey];
        if (difficulty > 2) {
            [NSUserDefaults.standardUserDefaults setInteger:0 forKey:kPrefDifficultyKey];
            difficulty = 0;
        }
        [self changeDifficulty:difficulty];
    } else {
        [self editMusicBar];
    }
    [[AudioManager sharedManager] playSeResFile:kMusicSelectSound inDirectory:nil];
    [self setStartButtonEnable];
}

/** @ghidraAddress 0x1a29e8 */
- (void)editFileListViewSelectItem:(int)index {
    if (index < 0) {
        return;
    }
    NSMutableArray<NSMutableDictionary *> *files =
        [[EditDataManager sharedManager] getFileInfoList:self.info.tuneID];
    [self selectEditFile:files[index][@"fileName"]];
    [self loadEditFile];
    [self resetTextField:(int)self.info.tuneID isFirst:NO];
    [self.controller dismissViewControllerAnimated:YES completion:nil];
    [self editMusicBar];
    [self setStartButtonEnable];
    [[AudioManager sharedManager] playSeResFile:kEditSelectSound inDirectory:nil];
    [self.controller enableCoverTap];
}

/** @ghidraAddress 0x1a33d8 */
- (void)downloadEnd:(nullable id)sender {
    if (!self.isPad && self.jcfMan != nil) {
        [self loadEditFile];
        NSMutableArray<NSMutableDictionary *> *files =
            [[EditDataManager sharedManager] getFileInfoList:self.info.tuneID];
        [self.jcfMan reloadList:files];
        [self resetTextField:(int)self.info.tuneID isFirst:NO];
        [self setStartButtonEnable];
    }
    [self editMusicBar];
    NSString *owner = [NSString stringWithFormat:@"%d", self.info.tuneID];
    [[LatelyJcfListManager sharedManager] removeJcfOwner:owner];
}

/** @ghidraAddress 0x1a391c */
- (nullable id)getStartImage {
    if (![JubeatAppDelegate.appDelegate isRandom]) {
        return [[ImageCache sharedCache] getResPNG:kStartButtonImage];
    }
    if ([JubeatAppDelegate.appDelegate isHold]) {
        return [[ImageCache sharedCache] getResPNG:kStartButtonImage];
    }
    return [[ImageCache sharedCache] getResPNG:kRandomButtonImage];
}

/** @ghidraAddress 0x1a3a54 */
- (nullable id)getSingleImage {
    if (![JubeatAppDelegate.appDelegate isRandom]) {
        return [[ImageCache sharedCache] getResPNG:kSingleButtonImage];
    }
    if ([JubeatAppDelegate.appDelegate isHold]) {
        return [[ImageCache sharedCache] getResPNG:kSingleButtonImage];
    }
    return [[ImageCache sharedCache] getResPNG:kRandomButtonImage];
}

/** @ghidraAddress 0x1a3610 */
- (void)removeUploadView {
    if (upLoadView != nil) {
        [topcover removeFromSuperview];
        topcover = nil;
        [upLoadView removeFromSuperview];
        upLoadView = nil;
    }
}

@end
