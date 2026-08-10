#import "MusicDetailViewRpl.h"

#import <QuartzCore/QuartzCore.h>

#import "AlertViewManager.h"
#import "BFCodec.h"
#import "EditDataManager.h"
#import "ImageCache.h"
#import "ImageLoading.h"
#import "JcfDownloadPageNavController.h"
#import "JcfManageNavController.h"
#import "JcfUpLoadView.h"
#import "JubeatAppDelegate.h"
#import "KUnzip.h"
#import "LabUtilities.h"
#import "LatelyJcfListManager.h"
#import "MusicSelectViewController.h"
#import "Sequence.h"
#import "TuneInfo.h"

extern const double g_dAnimDuration020; // @ghidraAddress 0x28f240 (0.2)

// The Ripples theme resource names for the start-button image variants and the edit/close sounds.
static NSString *const kStartButtonImage = @"menu_button_start_rpl";
static NSString *const kRandomButtonImage = @"menu_button_random_rpl";
static NSString *const kSingleButtonImage = @"menu_button_single_rpl";
static NSString *const kEditSelectSound = @"SD_RPL_OK";
static NSString *const kMusicLeftSound = @"SD_RPL_MUSIC_LEFT";
static NSString *const kMusicRightSound = @"SD_RPL_MUSIC_RIGHT";
static NSString *const kMusicSelectSound = @"SD_RPL_MUSIC_SELECT";

// The download-selection preference remembers that the download entry was chosen (value 2).
static NSString *const kPrefJcfDownloadSelectKey = @"PrefJcfDownloadSelect";
static const NSInteger kJcfDownloadSelectDownload = 2;

// The download-sequence alert messages, the binary's shared Japanese literals.
static NSString *const kConnectErrorMessage = @"通信エラー";
static NSString *const kDownloadFinishedMessage = @"ダウンロード終わり";

// The music bar holds 120 dot views; each dot's sprite is a 4-bit nibble of the dot map and its
// image row a 2-bit field of the resource map.
enum {
    kMusicBarDotCount = 120,
    kMusicBarDotSpriteCount = 8,
};

// The scroll button fades out across an eighth of the half-width scroll span.
static const float kScrollFadeSpanFraction = 0.125f;

// The upload sheet fades out over this (negative, as the binary passes it) duration.
static const NSTimeInterval kUploadEndFadeDuration = -0.2; // @ghidraAddress 0x28e050

// The dimming cover behind the upload sheet is translucent black at this alpha and both fade in
// over this duration.
static const CGFloat kUploadCoverScrimAlpha = 0.3;     // @ghidraAddress 0x28f248
static const NSTimeInterval kUploadFadeDuration = 0.2; // @ghidraAddress 0x28e040

// Cancelling a host share fades the share-message label out over this duration.
static const NSTimeInterval kHostShareCancelFadeDuration = 0.1; // @ghidraAddress 0x28f290

// The random marker slides up by this many points out of view and toggles over this duration.
static const int kRandViewSlideOffset = 10;
static const NSTimeInterval kRandViewToggleDuration = 0.3; // @ghidraAddress 0x28f260

// Entering edit shrinks the difficulty buttons to this scale over this duration, and input stays
// locked for a slightly longer beat.
static const CGFloat kEditButtonShrinkScale = 0.1;         // @ghidraAddress 0x28f2b8
static const NSTimeInterval kEditTransitionDuration = 0.6; // @ghidraAddress 0x28f288
static const NSTimeInterval kEditInputLockDuration = 0.7;  // @ghidraAddress 0x28f2a0

// The high-score text base X (per idiom), the extend-mode nudge added before it slides home, and
// the score-text centre Y (per idiom). Toggling extend mode plays the Knit theme's left cue (the
// binary reuses that resource here) and animates over this duration, locking input for a beat.
static const double kHighscoreBaseXPad = 45.0;             // @ghidraAddress 0x28f1e0
static const double kHighscoreBaseXPhone = 30.0;           // fmov d1, 30.0
static const double kHighscoreCenterXNudge = 40.0;         // @ghidraAddress 0x28f1f8
static const double kHighscoreCenterYPad = -8.0;           // fmov, -8.0
static const double kHighscoreCenterYPhone = -6.0;         // fmov, -6.0
static const NSTimeInterval kExtendModeAnimDuration = 0.3; // @ghidraAddress 0x28f260
static const NSTimeInterval kExtendModeInputLock = 0.4;    // @ghidraAddress 0x28f2c0
static NSString *const kExtendModeSound = @"SD_KNT_MUSIC_LEFT";

// The share-message label drops by this many points while the share progress shows, animated over
// this duration.
static const double kShareLabelDropOffset = 6.0;              // fmov, 6.0
static const NSTimeInterval kShareProgressAnimDuration = 0.3; // @ghidraAddress 0x28f260

// The extend marks crossfade over this duration when the extend mode changes.
static const NSTimeInterval kExtendCrossFadeDuration = 0.3; // @ghidraAddress 0x28f260

// The rating images, indexed by SequenceRank (E, D, C, B, A, S, SS, SSS), and the score/level glyph
// and mini-dot resource-name formats, all with the Ripples suffix.
static NSString *const kRatingImageNames[] = {@"msc_rate_e_rpl",
                                              @"msc_rate_d_rpl",
                                              @"msc_rate_c_rpl",
                                              @"msc_rate_b_rpl",
                                              @"msc_rate_a_rpl",
                                              @"msc_rate_s_rpl",
                                              @"msc_rate_ss_rpl",
                                              @"msc_rate_sss_rpl"};
static NSString *const kHighscoreDigitFormat = @"msc_high_score_%d_rpl";
static NSString *const kLevelNumberFormat = @"lv_%02d_rpl";
static NSString *const kMiniDotFormat = @"mini_dot_%d_%d_rpl";
enum { kLevelImageCount = 10 };

// The four music-bar bars stretch from resizable images with per-idiom cap insets.
static NSString *const kMusicBarNames[] = {
    @"mini_bar_b_rpl", @"mini_bar_a_rpl", @"mini_bar_e_rpl", @"mini_bar_o_rpl"};
static const CGFloat kMusicBarCapInsetPad = 48.0;   // @ghidraAddress 0x28f450
static const CGFloat kMusicBarCapInsetPhone = 32.0; // @ghidraAddress 0x28f458

static NSString *const kFullcomboImageName = @"msc_fullcombo_rpl";
static NSString *const kExcellentImageName = @"msc_excellent_rpl";

// The host share-play button's background image.
static NSString *const kHostButtonImage = @"menu_button_host_rpl";

// An unselected difficulty button dims to this alpha and shrinks to this scale on the Ripples
// theme.
static const CGFloat kDiffButtonDimAlpha = 0.5;  // fmov 0x3fe0000000000000
static const CGFloat kDiffButtonDimScale = 0.95; // @ghidraAddress 0x28f6e0
enum { kDiffButtonCount = 3, kExtendButtonIndex = 3 };

// The difficulty button's fixed frame size, per idiom.
static const double kDiffButtonWidthPad = 142.0;   // @ghidraAddress 0x292e88
static const double kDiffButtonWidthPhone = 78.0;  // @ghidraAddress 0x28f5f0
static const double kDiffButtonHeightPad = 138.0;  // @ghidraAddress 0x2924c8
static const double kDiffButtonHeightPhone = 76.0; // @ghidraAddress 0x292488

// The seven high-score digits render with a right-justified %7d through highscoreNumImg; a perfect
// score shows the excellent image instead of a rank.
enum {
    kHighscoreDigitCount = 7,
    kExcellentScore = 1000000,
    kDigitGlyphCount = 10,
};
static const char kDigitZero = '0';

// The scroll page and preferred difficulty persist across sessions under these preference keys.
static NSString *const kPrefEditSelectKey = @"PrefEditSelect";
static NSString *const kPrefDifficultyKey = @"PrefDifficulty";

// The packed-content dictionary keys and the reflection height fraction (of the artwork height) on
// the pad.
static NSString *const kContentArtwork = @"artwork_s";
static NSString *const kContentNameB = @"name_b";
static NSString *const kContentSeqBasic = @"seq_bas";
// The packed archive stores the full-size artwork under "artwork" and the small one under
// "artwork_s"; both content archives skip a 16-byte trailer.
static NSString *const kArchiveArtworkFull = @"artwork";
static NSString *const kArchiveArtworkSmall = @"artwork_s";
static const NSUInteger kContentArchiveTail = 16;
static NSString *const kContentSeqAdvanced = @"seq_adv";
static NSString *const kContentSeqExtreme = @"seq_ext";
static const double kReflectionFractionPad = 0.3; // @ghidraAddress 0x28f248
enum {
    kMbarBasicRow = 0,
    kMbarAdvancedRow = 1,
    kMbarExtremeRow = 2,
};

// The extend music-bar archive stores each difficulty's sequence under these member names and skips
// a 16-byte trailer; the three deciphered bars fill the extendMbarDots rows.
static NSString *const kExtendSeqBasic = @"seq_bas";
static NSString *const kExtendSeqAdvanced = @"seq_adv";
static NSString *const kExtendSeqExtreme = @"seq_ext";
static const NSUInteger kExtendArchiveTail = 16;
enum {
    kExtendMbarBasicRow = 0,
    kExtendMbarAdvancedRow = 1,
    kExtendMbarExtremeRow = 2,
};

// The three scroll-settled delegate callbacks share this tail: it snaps the settled page,
// re-derives the hold flag from the current difficulty's hold mark (except on the edit page),
// refreshes the start button, records the page, and applies either the difficulty (snapping a stale
// extreme back to basic) on the detail page or the edit music bar on the edit page.
static inline void MusicDetailViewRplSettleScrollPage(MusicDetailViewRpl *self) {
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
            [NSUserDefaults.standardUserDefaults setInteger:0 forKey:kPrefDifficultyKey];
            detailDifficulty = 0;
        }
        [self changeDifficulty:detailDifficulty];
    } else {
        [self editMusicBar];
    }
    [self setStartButtonEnable];
}

// The edit music bar uses the fourth (index 3) bar background image and reads 60 bytes of simple
// edit data.
enum { kEditMbarBackgroundImage = 3 };
static const NSUInteger kEditMbarDataLength = 60;

// A downloaded edit's author badge, indexed by the userTag field.
static NSString *const kUserTagIconNames[] = {
    @"list_icon_user_blank", @"icon_user_staff", @"icon_user_artist"};

// The user-tag badge insets from the extend button's right edge and top, per idiom.
static const double kUserTagInsetPad = 14.0;   // fmov d0, 14.0
static const double kUserTagInsetPhone = 10.0; // fmov d0, 10.0
static const double kUserTagTopPad = 22.0;     // fmov d1, 22.0
static const double kUserTagTopPhone = 12.0;   // fmov d1, 12.0

// A chart level maps to a zero-based level-image index: below 2 -> first image, 10+ -> last of ten.
static inline char MusicDetailViewRplLevelIndex(int level) {
    if (level < 2) {
        return 0;
    }
    if (level < 10) {
        return (char)(level - 1);
    }
    return 9;
}

@implementation MusicDetailViewRpl

/** @ghidraAddress 0x12ad40 */
+ (Class)layerClass {
    return [CAGradientLayer class];
}

/** @ghidraAddress 0x13884c */
- (void)dealloc {
    // Empty in the binary too: the only instruction is the super call, and the class has a
    // .cxx_destruct, so that call is what ARC emits.
}

/** @ghidraAddress 0x135630 */
- (void)pushButtonEdit:(nullable id)sender {
    [self editStart];
}

/** @ghidraAddress 0x13554c */
- (void)pushButtonUpload:(nullable id)sender {
    if ([self checkEnableUpload]) {
        [self uploadStart];
    }
}

/** @ghidraAddress 0x13752c */
- (void)loadListRelease {
    [self.pFileListView setDelegate:nil];
    self.pFileListView = nil;
}

/** @ghidraAddress 0x1384d4 */
- (void)popoverPresentationControllerDidDismissPopover:
    (nullable UIPopoverPresentationController *)popoverPresentationController {
    [self loadListRelease];
    [self.controller enableCoverTap];
}

/** @ghidraAddress 0x1366a0 */
- (void)scrollViewWillBeginDragging:(nullable UIScrollView *)scrollView {
}

/** @ghidraAddress 0x12f0dc */
- (void)setInfo:(nullable TuneInfo *)info score:(nullable id)score {
    [super setInfo:info score:score];
    if (info == nil) {
        return;
    }
    self.levelBas = MusicDetailViewRplLevelIndex(info.lvBas);
    self.levelAdv = MusicDetailViewRplLevelIndex(info.lvAdv);
    self.levelExt = MusicDetailViewRplLevelIndex(info.lvExt);
    [self.buttonLink setEnabled:(info.iTunesURL != nil)];
    [self.buttonLink setHidden:(info.iTunesURL == nil)];
    [self.btnRecommendTwitter setHidden:NO];
    [self.btnRecommendFacebook setHidden:NO];
    [levelNumView[0] setImage:levelNumImg[self.levelBas]];
    [levelNumView[1] setImage:levelNumImg[self.levelAdv]];
    [levelNumView[2] setImage:levelNumImg[self.levelExt]];
    [levelNumView[kExtendButtonIndex] setImage:levelNumImg[self.levelExt]];
    [levelNumView[kExtendButtonIndex] setAlpha:0.0];
    [self resetScore];
    [self putScore:score];
    [self loadContentFromPath:info.filePath orData:nil];
    [self loadEditFile];
    [self resetTextField:(int)info.tuneID isFirst:YES];
    [self editMusicBar];
}

/** @ghidraAddress 0x1316b4 */
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

/** @ghidraAddress 0x12dc84 */
- (nullable UIButton *)diffButton:(nullable NSString *)imageName {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    double width = self.isPad ? kDiffButtonWidthPad : kDiffButtonWidthPhone;
    double height = self.isPad ? kDiffButtonHeightPad : kDiffButtonHeightPhone;
    [button setFrame:CGRectMake(0.0, 0.0, width, height)];
    [button setImage:LoadScaledPngImage(imageName) forState:UIControlStateNormal];
    [button setExclusiveTouch:YES];
    [button setAdjustsImageWhenHighlighted:NO];
    [button setAdjustsImageWhenDisabled:NO];
    [button addTarget:self
                  action:@selector(selectDiff:)
        forControlEvents:UIControlEventTouchUpInside];
    return button;
}

/** @ghidraAddress 0x1303d0 */
- (void)changeExtend:(int)difficulty {
    BOOL isExtend = JubeatAppDelegate.appDelegate.isExtend;
    // Every difficulty's hold and extend marks start hidden.
    for (int i = 0; i < kDiffButtonCount; ++i) {
        [holdMark[i] setHidden:YES];
        [extendMark[i] setHidden:YES];
        [extendOnMark[i] setHidden:YES];
    }
    if (self.extendInfo != nil) {
        // Reveal each difficulty that carries an extend chart, pre-seeding its marks to the current
        // extend state so the crossfade animates a real transition; the level numbers fade in from
        // zero. The crossfade target is the extend-on mark only when toggling extend off.
        float mix = 0.0f;
        for (int i = 0; i < kDiffButtonCount; ++i) {
            if ((self.extendInfo.extendFlag & (1 << i)) != 0) {
                [extendMark[i] setHidden:NO];
                [extendOnMark[i] setHidden:NO];
                if (isExtend) {
                    [extendMark[i] setAlpha:1.0];
                    [extendOnMark[i] setAlpha:0.0];
                    mix = 1.0f;
                } else {
                    [extendMark[i] setAlpha:0.0];
                    [extendOnMark[i] setAlpha:1.0];
                }
                [holdMark[i] setAlpha:0.0];
            }
            [levelNumView[i] setAlpha:0.0];
        }

        __weak MusicDetailViewRpl *weakSelf = self;
        [UIView animateWithDuration:kExtendCrossFadeDuration
                         animations:^{
                           /** @ghidraAddress 0x130958 */
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

/** @ghidraAddress 0x131a48 */
- (void)changeDifficulty:(int)difficulty {
    // The selected base button is full and unscaled; the other two dim and shrink; the extend
    // button is always full.
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

/** @ghidraAddress 0x132ed4 */
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

/** @ghidraAddress 0x132d54 */
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

/** @ghidraAddress 0x134ebc */
- (void)editFileListViewSelectDownload {
    [[AudioManager sharedManager] playSeResFile:kMusicRightSound inDirectory:nil];
    [NSUserDefaults.standardUserDefaults setInteger:kJcfDownloadSelectDownload
                                             forKey:kPrefJcfDownloadSelectKey];
    [self.controller dismissViewControllerAnimated:self.isPad completion:nil];
    self.jcfDownloadPage = [[JcfDownloadPageNavController alloc] initWithMusicID:self.info.tuneID
                                                                        delegate:self];
    [self.controller presentViewController:self.jcfDownloadPage animated:YES completion:nil];
}

/** @ghidraAddress 0x137e24 */
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

/** @ghidraAddress 0x137fb0 */
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

/** @ghidraAddress 0x138204 */
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

/** @ghidraAddress 0x1389a0 */
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

/** @ghidraAddress 0x130afc */
- (void)clearInfo {
    [self.artworkView setImage:nil];
    [self.reflectionArtworkView setImage:nil];
    [self.tuneNameView setImage:nil];
}

/** @ghidraAddress 0x135590 */
- (void)editFileListViewSelectEdit {
    [[AudioManager sharedManager] playSeResFile:kEditSelectSound inDirectory:nil];
    [self.controller dismissViewControllerAnimated:YES completion:nil];
    [self editStart];
}

/** @ghidraAddress 0x138528 */
- (void)editFileListViewCancel:(nullable id)sender {
    [self.controller enableCoverTap];
    [self.controller dismissViewControllerAnimated:YES completion:nil];
}

/** @ghidraAddress 0x1383f8 */
- (void)selectEditFile:(nullable id)fileName {
    [[EditDataManager sharedManager] setLastEditFileName:(int)self.info.tuneID fileName:fileName];
    [self.controller enableCoverTap];
}

/** @ghidraAddress 0x137288 */
- (BOOL)checkDownloadFile {
    if ([[EditDataManager sharedManager] getLastEditFileName:(int)self.info.tuneID] == nil) {
        return YES;
    }
    return [EditDataManager sharedManager].bIsDownload;
}

/** @ghidraAddress 0x1385ac */
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

/** @ghidraAddress 0x13868c */
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

/** @ghidraAddress 0x13876c */
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

/** @ghidraAddress 0x138bd8 */
- (void)removeUploadView {
    if (upLoadView != nil) {
        [topcover removeFromSuperview];
        topcover = nil;
        [upLoadView removeFromSuperview];
        upLoadView = nil;
    }
}

/** @ghidraAddress 0x138884 */
- (void)customWebViewClose:(nullable id)webView seqIndex:(nullable id)seqIndex {
    [self resetTextField:(int)self.info.tuneID isFirst:NO];
    [self setStartButtonEnable];
    [[AudioManager sharedManager] playSeResFile:kMusicLeftSound inDirectory:nil];
    [self.controller enableCoverTap];
    [self.controller dismissViewControllerAnimated:YES completion:nil];
}

/** @ghidraAddress 0x1366a4 */
- (void)scrollViewDidScroll:(nullable UIScrollView *)scrollView {
    float offsetX = (float)scrollView.contentOffset.x;
    float half = (float)(scrollView.contentSize.width * 0.5);
    float denom = half * kScrollFadeSpanFraction;
    [detailScrollButton[0] setAlpha:(double)(1.0f - MIN(offsetX / denom, 1.0f))];
    [detailScrollButton[1] setAlpha:(double)(1.0f - MIN((half - offsetX) / denom, 1.0f))];
}

/** @ghidraAddress 0x131ed8 */
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

/** @ghidraAddress 0x139544 */
- (CGPoint)getDifficultyPos:(int)difficulty {
    int index = (difficulty > 2) ? 0 : difficulty;
    int scrollY = (int)self.scrollView.frame.origin.y;
    int buttonX = (int)btnDiff[index].frame.origin.x;
    int scrollX = (int)self.scrollView.frame.origin.x;
    int buttonY = (int)btnDiff[index].frame.origin.y;
    return CGPointMake((double)(int)((double)scrollX + (double)buttonX),
                       (double)(int)((double)scrollY + (double)buttonY));
}

/** @ghidraAddress 0x133f18 */
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

    __weak MusicDetailViewRpl *weakSelf = self;
    if (show) {
        [self.shareDataProgress setHidden:NO];
        [self.shareDataProgress setAlpha:0.0];
        [self.shareDataProgress setProgress:0.0];
        [UIView animateWithDuration:kShareProgressAnimDuration
                         animations:^{
                           /** @ghidraAddress 0x1342f4 */
                           [weakSelf.shareDataProgress setAlpha:1.0];
                           [weakSelf.labelShareMessage setTransform:labelDrop];
                         }];
    } else {
        [UIView animateWithDuration:kShareProgressAnimDuration
            animations:^{
              /** @ghidraAddress 0x1343d8 */
              [weakSelf.shareDataProgress setAlpha:0.0];
              [weakSelf.labelShareMessage setTransform:CGAffineTransformIdentity];
            }
            completion:^(BOOL finished) {
              /** @ghidraAddress 0x1344b8 */
              [weakSelf.shareDataProgress setHidden:YES];
            }];
    }
}

/** @ghidraAddress 0x13913c */
- (void)changeExtendMode {
    if (self.info.extendID != 0) {
        int difficulty =
            (int)[NSUserDefaults.standardUserDefaults integerForKey:kPrefDifficultyKey];
        if (self.extendInfo != nil && (self.extendInfo.extendFlag & (1 << difficulty)) != 0) {
            // Flip the app-wide extend toggle, re-lay the extend info, and reposition the score
            // board for the new mode.
            [JubeatAppDelegate.appDelegate setExtendFlag:!JubeatAppDelegate.appDelegate.isExtend];
            [[AudioManager sharedManager] playSeResFile:kExtendModeSound inDirectory:nil];
            [self changeExtend:difficulty];

            double baseX = self.isPad ? kHighscoreBaseXPad : kHighscoreBaseXPhone;
            double centerY = self.isPad ? kHighscoreCenterYPad : kHighscoreCenterYPhone;
            [highscoreTextView setCenter:CGPointMake(baseX + kHighscoreCenterXNudge, centerY)];
            [highscoreBoardView setAlpha:0.0];
            [NSUserDefaults.standardUserDefaults setInteger:difficulty forKey:kPrefDifficultyKey];

            [UIView animateWithDuration:kExtendModeAnimDuration
                             animations:^{
                               /** @ghidraAddress 0x13949c */
                               [self changeDifficulty:difficulty];
                               double bx = self.isPad ? kHighscoreBaseXPad : kHighscoreBaseXPhone;
                               double cy =
                                   self.isPad ? kHighscoreCenterYPad : kHighscoreCenterYPhone;
                               [self->highscoreTextView setCenter:CGPointMake(bx, cy)];
                               [self->highscoreBoardView setAlpha:1.0];
                             }];
        }
    }
    // Input is briefly locked out while the mode change settles.
    [[UIApplication sharedApplication] performSelector:@selector(endIgnoringInteractionEvents)
                                            withObject:nil
                                            afterDelay:kExtendModeInputLock];
}

/** @ghidraAddress 0x131ffc */
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

/** @ghidraAddress 0x12ddf4 */
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

/** @ghidraAddress 0x12ff1c */
- (void)setExtendInfo:(nullable TuneInfo *)info score:(nullable id)score {
    [super setExtendInfo:info score:score];
    [self loadExtendMusicBar:info.filePath];

    // Every hold and extend mark starts hidden across the three difficulties.
    for (int i = 0; i < kDiffButtonCount; ++i) {
        [holdMark[i] setHidden:YES];
        [extendMark[i] setHidden:YES];
        [extendOnMark[i] setHidden:YES];
    }

    self.extendLevelBas = MusicDetailViewRplLevelIndex(info.lvBas);
    self.extendLevelAdv = MusicDetailViewRplLevelIndex(info.lvAdv);
    self.extendLevelExt = MusicDetailViewRplLevelIndex(info.lvExt);

    // Each difficulty that carries an extend chart (a set bit of extendFlag) reveals its extend and
    // extend-on marks, showing whichever matches the current extend mode.
    if (info != nil) {
        BOOL extendOn = JubeatAppDelegate.appDelegate.isExtend;
        for (int i = 0; i < kDiffButtonCount; ++i) {
            if ((info.extendFlag >> i) & 1) {
                [extendMark[i] setHidden:extendOn];
                [extendOnMark[i] setHidden:!extendOn];
            }
        }
    }
    if (score != nil) {
        [self putExtendScore:score];
    }
}

/** @ghidraAddress 0x1350a0 */
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
                       /** @ghidraAddress 0x135474 */
                       [weakCover setAlpha:1.0];
                       [weakUpload setAlpha:1.0];
                     }
                     completion:nil];
    [self.controller unenableCoverTap];
}

/** @ghidraAddress 0x13563c */
- (void)editStart {
    [[AudioManager sharedManager] playSeResFile:kEditSelectSound inDirectory:nil];
    [self.controller showButtonMarker:NO];
    [self.buttonStartPlay setEnabled:NO];

    __weak MusicDetailViewRpl *weakSelf = self;
    [UIView animateWithDuration:kEditTransitionDuration
        delay:0.0
        options:UIViewAnimationOptionBeginFromCurrentState
        animations:^{
          /** @ghidraAddress 0x13586c */
          CATransform3D shrink =
              CATransform3DMakeScale(kEditButtonShrinkScale, kEditButtonShrinkScale, 1.0);
          for (int i = 0; i < kDiffButtonCount; ++i) {
              [self->btnDiff[i] setAlpha:0.0];
              self->btnDiff[i].layer.transform = shrink;
          }
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x135a08 */
          [weakSelf.controller startEdit:weakSelf.info];
        }];

    // Input is ignored through the transition and re-enabled a beat after it ends.
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    [[UIApplication sharedApplication] performSelector:@selector(endIgnoringInteractionEvents)
                                            withObject:nil
                                            afterDelay:kEditInputLockDuration];
}

/** @ghidraAddress 0x12ee08 */
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

/** @ghidraAddress 0x12e820 */
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
    NSMutableData *nameData = [archive uncompress:kContentNameB];
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

/** @ghidraAddress 0x12e48c */
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
    // On the detail page (edit page 0) the Ripples theme re-applies the preferred difficulty once
    // the bars are loaded.
    if ([NSUserDefaults.standardUserDefaults integerForKey:kPrefEditSelectKey] == 0) {
        int difficulty =
            (int)[NSUserDefaults.standardUserDefaults integerForKey:kPrefDifficultyKey];
        [self changeDifficulty:difficulty];
    }
}

/** @ghidraAddress 0x136200 */
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

    __weak MusicDetailViewRpl *weakSelf = self;
    [UIView animateWithDuration:kRandViewToggleDuration
                     animations:^{
                       /** @ghidraAddress 0x136564 */
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

/** @ghidraAddress 0x133b9c */
- (void)hostShareCancelled {
    [self.buttonHostSharePlay
        setBackgroundImage:[[ImageCache sharedCache] getResPNG:kHostButtonImage]
                  forState:UIControlStateNormal];
    [self setStartButtonEnable];
    [self.buttonStartPlay setBackgroundImage:[self getSingleImage] forState:UIControlStateNormal];
    [self.buttonLink setEnabled:YES];
    [self.btnRecommendTwitter setEnabled:YES];
    [self.btnRecommendFacebook setEnabled:YES];

    __weak MusicDetailViewRpl *weakSelf = self;
    [UIView animateWithDuration:kHostShareCancelFadeDuration
        animations:^{
          /** @ghidraAddress 0x133e40 */
          [weakSelf.labelShareMessage setAlpha:0.0];
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x133eac */
          [weakSelf.labelShareMessage setHidden:YES];
        }];
}

/** @ghidraAddress 0x138c40 */
- (void)uploadEnd:(nullable id)sender {
    __weak UIView *weakCover = topcover;
    __weak JcfUpLoadView *weakUpload = upLoadView;
    // The binary passes a negative fade duration here; kept as-is.
    [UIView animateWithDuration:kUploadEndFadeDuration
        animations:^{
          /** @ghidraAddress 0x138de4 */
          [weakCover setAlpha:0.0];
          [weakUpload setAlpha:0.0];
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x138eac */
          [self removeUploadView];
        }];
    [self.controller enableCoverTap];
}

/** @ghidraAddress 0x131ca0 */
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

/** @ghidraAddress 0x136780 */
- (void)scrollViewDidEndScrollingAnimation:(nullable UIScrollView *)scrollView {
    [detailScrollButton[0] setAlpha:1.0];
    [detailScrollButton[1] setAlpha:1.0];
    MusicDetailViewRplSettleScrollPage(self);
}

/** @ghidraAddress 0x136a80 */
- (void)scrollViewDidEndDecelerating:(nullable UIScrollView *)scrollView {
    MusicDetailViewRplSettleScrollPage(self);
}

/** @ghidraAddress 0x136d54 */
- (void)scrollViewDidEndDragging:(nullable UIScrollView *)scrollView
                  willDecelerate:(BOOL)decelerate {
    if (!decelerate) {
        MusicDetailViewRplSettleScrollPage(self);
    }
}

/** @ghidraAddress 0x137378 */
- (void)pushInfoEdit:(nullable id)sender {
    if (![self checkDownloadFile] && self.isPad) {
        [[AudioManager sharedManager] playSeResFile:kMusicRightSound inDirectory:nil];
        self.pEditModalView = [[EditModalView alloc] initWithType:0];
        [self.pEditModalView setEditDelegate:self];
        self.isEditInfoOpen = YES;
        [self.controller presentViewController:self.pEditModalView animated:YES completion:nil];
        [self.controller unenableCoverTap];
    }
}

/** @ghidraAddress 0x137024 */
- (void)editModalViewClose:(nullable id)sender {
    [[AudioManager sharedManager] playSeResFile:kMusicLeftSound inDirectory:nil];
    NSMutableDictionary *editorInfo = [[EditDataManager sharedManager] getEditorInfo];
    [editTxt[0] setText:editorInfo[@"fumenName"]];
    [editTxt[1] setText:editorInfo[@"editorName"]];
    [editTxt[2] setText:editorInfo[@"comment"]];
    int level = [editorInfo[@"level"] intValue];
    [levelNumView[kExtendButtonIndex] setImage:levelNumImg[level]];
    [levelNumView[kExtendButtonIndex] setAlpha:1.0];
    [self.controller dismissViewControllerAnimated:YES completion:nil];
    [self.controller enableCoverTap];
}

/** @ghidraAddress 0x138ecc */
- (nullable id)getStartImage {
    if (![JubeatAppDelegate.appDelegate isRandom]) {
        return [[ImageCache sharedCache] getResPNG:kStartButtonImage];
    }
    if ([JubeatAppDelegate.appDelegate isHold]) {
        return [[ImageCache sharedCache] getResPNG:kStartButtonImage];
    }
    return [[ImageCache sharedCache] getResPNG:kRandomButtonImage];
}

/** @ghidraAddress 0x139004 */
- (nullable id)getSingleImage {
    if (![JubeatAppDelegate.appDelegate isRandom]) {
        return [[ImageCache sharedCache] getResPNG:kSingleButtonImage];
    }
    if ([JubeatAppDelegate.appDelegate isHold]) {
        return [[ImageCache sharedCache] getResPNG:kSingleButtonImage];
    }
    return [[ImageCache sharedCache] getResPNG:kRandomButtonImage];
}

@end
