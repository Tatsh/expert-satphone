#import "MusicDetailViewOrg.h"

#import <QuartzCore/QuartzCore.h>

#import "AlertViewManager.h"
#import "BFCodec.h"
#import "EditDataManager.h"
#import "EditFileListViewDeleteController.h"
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

// The classic theme resource names for the start-button image variants and the edit/close sounds.
static NSString *const kStartButtonImage = @"menu_button_start";
static NSString *const kRandomButtonImage = @"menu_button_random";
static NSString *const kSingleButtonImage = @"menu_button_single";
static NSString *const kEditSelectSound = @"SD_OK";
static NSString *const kMusicLeftSound = @"SD_MUSIC_LEFT";
static NSString *const kMusicRightSound = @"SD_MUSIC_RIGHT";
static NSString *const kMusicSelectSound = @"SD_MUSIC_SELECT";

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

// The three selectable difficulty buttons (a fourth extend slot follows).
enum { kDiffButtonCount = 3 };

// Entering edit shrinks the difficulty buttons to this scale over this duration, and input stays
// locked for a slightly longer beat.
static const CGFloat kEditButtonShrinkScale = 0.1;         // @ghidraAddress 0x28f2b8
static const NSTimeInterval kEditTransitionDuration = 0.6; // @ghidraAddress 0x28f288
static const NSTimeInterval kEditInputLockDuration = 0.7;  // @ghidraAddress 0x28f2a0

// The high-score board's home centre X (per idiom), the extend-mode slide offset subtracted from it
// before it slides home (per idiom), and its centre Y (per idiom). Toggling extend mode plays the
// Knit theme's left cue (the binary reuses that resource here) and animates over this duration,
// locking input for a beat.
static const double kHighscoreBoardXPad = 400.0;           // @ghidraAddress 0x28f2e0
static const double kHighscoreBoardXRetina = 230.0;        // @ghidraAddress 0x28f670
static const double kHighscoreBoardXNonRetina = 220.0;     // @ghidraAddress 0x28f430
static const double kHighscoreBoardSlidePad = 20.0;        // fmov, 20.0
static const double kHighscoreBoardSlidePhone = 10.0;      // fmov, 10.0
static const double kHighscoreBoardYPad = 220.0;           // @ghidraAddress 0x28f430
static const double kHighscoreBoardYPhone = 104.0;         // @ghidraAddress 0x28f678
static const NSTimeInterval kExtendModeAnimDuration = 0.3; // @ghidraAddress 0x28f260
static const NSTimeInterval kExtendModeInputLock = 0.4;    // @ghidraAddress 0x28f2c0
static NSString *const kExtendModeSound = @"SD_KNT_MUSIC_LEFT";

// The share-message label drops by this many points while the share progress shows, animated over
// this duration.
static const double kShareLabelDropOffset = 6.0;              // fmov, 6.0
static const NSTimeInterval kShareProgressAnimDuration = 0.3; // @ghidraAddress 0x28f260

// The extend marks crossfade over this duration when the extend mode changes.
static const NSTimeInterval kExtendCrossFadeDuration = 0.3; // @ghidraAddress 0x28f260

// The per-difficulty voice cues, the input-lock durations, and the high-score board's dimmed alpha
// while a difficulty change slides it in.
static NSString *const kDifficultyVoiceCues[] = {
    @"SD_CV_BASIC", @"SD_CV_ADVANCED", @"SD_CV_EXTREME"};
static const NSTimeInterval kSelectDiffInputLock = 0.4;       // @ghidraAddress 0x28f268
static const NSTimeInterval kSelectDiffExtendInputLock = 0.4; // @ghidraAddress 0x28f2c0
static const CGFloat kHighscoreBoardDimAlpha = 0.3;           // @ghidraAddress 0x28f248

// Repositions the high-score board view to its idiom home centre.
static inline void MusicDetailViewOrgRepositionHighscoreBoard(MusicDetailViewOrg *self) {
    double homeX = self.isPad ?
                       kHighscoreBoardXPad :
                       (self.isRetina ? kHighscoreBoardXRetina : kHighscoreBoardXNonRetina);
    double y = self.isPad ? kHighscoreBoardYPad : kHighscoreBoardYPhone;
    [self->highscoreBoardView setCenter:CGPointMake(homeX, y)];
}

// With no edit loaded the three edit text fields dim to this alpha; the edit buttons fade in over
// this duration; a dlFlag of this value marks a downloaded edit.
static const CGFloat kEditTextDimmedAlpha = 0.5;          // fmov, 0.5
static const NSTimeInterval kResetTextFadeDuration = 0.1; // @ghidraAddress 0x28f290
static const NSInteger kEditDownloadFlag = 1;

// The pad edit-file delete list is presented as a 300x400 popover.
static const double kEditPopoverWidth = 300.0;  // @ghidraAddress 0x28f2d0
static const double kEditPopoverHeight = 400.0; // @ghidraAddress 0x28f2e0

// The rating images, indexed by SequenceRank (E, D, C, B, A, S, SS, SSS) plus the excellent image.
static NSString *const kRatingImageNames[] = {@"msc_rate_e",
                                              @"msc_rate_d",
                                              @"msc_rate_c",
                                              @"msc_rate_b",
                                              @"msc_rate_a",
                                              @"msc_rate_s",
                                              @"msc_rate_ss",
                                              @"msc_rate_sss",
                                              @"msc_rate_exc"};
static NSString *const kHighscoreDigitFormat = @"msc_high_score_%d";

// The classic theme keeps a five-row level-glyph table, one row per difficulty word, each ten
// columns wide; the level-word labels sit alongside.
static NSString *const kLevelNumberFormats[] = {
    @"lv_b_%02d", @"lv_a_%02d", @"lv_e_%02d", @"lv_x_%02d", @"lv_o_%02d"};
static NSString *const kLevelTextNames[] = {
    @"word_level_b", @"word_level_a", @"word_level_e", @"word_level_x"};
static NSString *const kMiniDotFormat = @"mini_dot_%d_%d";
enum {
    kLevelImageCount = 10,
    kLevelWordRowCount = 5,
};

// The four music-bar bars stretch from resizable images with a single cap inset.
static NSString *const kMusicBarNames[] = {
    @"mini_bar_b", @"mini_bar_a", @"mini_bar_e", @"mini_bar_o"};
static const CGFloat kMusicBarCapInset = 40.0; // @ghidraAddress 0x28f1f8

static NSString *const kFullcomboImageName = @"msc_fullcombo_1";

// The host share-play button's background image, and the cancel image, waiting prompt, cancel cue,
// and fade duration used when starting or stopping a host share.
static NSString *const kHostButtonImage = @"menu_button_host";
static NSString *const kCancelButtonImage = @"menu_button_cancel";
static NSString *const kWaitingForClientKey = @"Waiting for client";
static NSString *const kHostShareCancelSound = @"SD_SKIP";
static const NSTimeInterval kHostShareStartFadeDuration = 0.3; // @ghidraAddress 0x28f260

// The classic difficulty button's fixed square frame: 160 on the pad, 80 on the retina phone, and
// 74 on the non-retina phone.
static const double kDiffButtonSizePad = 160.0;      // @ghidraAddress 0x28f438
static const double kDiffButtonSizeRetina = 80.0;    // @ghidraAddress 0x28f3f8
static const double kDiffButtonSizeNonRetina = 74.0; // @ghidraAddress 0x28f6f8

// The seven high-score digits render with a right-justified %7d through highscoreNumImg; the score
// is clamped to the perfect score.
enum {
    kHighscoreDigitCount = 7,
    kExcellentScore = 1000000,
    kDigitGlyphCount = 10,
};
static const char kDigitZero = '0';

// The preferred-difficulty preference selects which difficulty's light pair the blink animation
// plays on, keyed by this animation name.
static NSString *const kPrefDifficultyKey = @"PrefDifficulty";
static NSString *const kBlinkAnimationKey = @"AnimBlinkNormal";

// The scroll page persists across sessions under this preference key.
static NSString *const kPrefEditSelectKey = @"PrefEditSelect";

// The packed-content dictionary keys and the reflection height fraction (of the artwork height) on
// the pad. The classic theme stores the tune name under name_w (white), unlike the other themes.
static NSString *const kContentArtwork = @"artwork_s";
static NSString *const kContentNameW = @"name_w";
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

// The extend level image lives at difficulty-table row 4, column 4 of the level-number views.
enum {
    kExtendLevelNumIndex = 3,
    kExtendLevelRow = 4,
};

// The three scroll-settled delegate callbacks share this tail: it snaps the settled page,
// re-derives the hold flag from the current difficulty's hold mark (except on the edit page),
// refreshes the start button, records the page, and applies either the difficulty (snapping a stale
// extreme back to basic) on the detail page or the edit music bar on the edit page.
static inline void MusicDetailViewOrgSettleScrollPage(MusicDetailViewOrg *self) {
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

// The user-tag badge origin, per idiom (pad, retina phone, non-retina phone). Unlike the other
// themes the classic theme places the badge at a fixed origin rather than inset from the button's
// right edge.
static const double kUserTagXPad = 15.0;       // fmov d0, 15.0
static const double kUserTagXRetina = 10.0;    // fmov d1, 10.0
static const double kUserTagXNonRetina = 3.0;  // fmov d0, 3.0
static const double kUserTagYPad = 40.0;       // @ghidraAddress 0x28f1f8
static const double kUserTagYRetina = 20.0;    // fmov d1, 20.0
static const double kUserTagYNonRetina = 19.0; // fmov d0, 19.0

// A chart level maps to a zero-based level-image index: below 2 -> first image, 10+ -> last of ten.
static inline char MusicDetailViewOrgLevelIndex(int level) {
    if (level < 2) {
        return 0;
    }
    if (level < 10) {
        return (char)(level - 1);
    }
    return 9;
}

@implementation MusicDetailViewOrg

/** @ghidraAddress 0x502bc */
+ (Class)layerClass {
    return [CAGradientLayer class];
}

/** @ghidraAddress 0x5e62c */
- (void)dealloc {
    // Empty in the binary too: the only instruction is the super call, and the class has a
    // .cxx_destruct, so that call is what ARC emits.
}

/** @ghidraAddress 0x5b3ec */
- (void)pushButtonEdit:(nullable id)sender {
    [self editStart];
}

/** @ghidraAddress 0x5b3a8 */
- (void)pushButtonUpload:(nullable id)sender {
    if ([self checkEnableUpload]) {
        [self uploadStart];
    }
}

/** @ghidraAddress 0x5d368 */
- (void)loadListRelease {
    [self.pFileListView setDelegate:nil];
    self.pFileListView = nil;
}

/** @ghidraAddress 0x5e2b4 */
- (void)popoverPresentationControllerDidDismissPopover:
    (nullable UIPopoverPresentationController *)popoverPresentationController {
    [self loadListRelease];
    [self.controller enableCoverTap];
}

/** @ghidraAddress 0x5c4fc */
- (void)scrollViewWillBeginDragging:(nullable UIScrollView *)scrollView {
}

/** @ghidraAddress 0x57170 */
- (void)setScoreBoard:(int)score fullcombo:(BOOL)fullcombo {
    // The classic theme clamps the score to the perfect score and shows only the rating and the
    // seven score digits (no combo/full-combo mark).
    int clamped = (score < kExcellentScore) ? score : kExcellentScore;
    char digits[8] = {
        kDigitZero, kDigitZero, kDigitZero, kDigitZero, kDigitZero, kDigitZero, kDigitZero, 0};
    if (clamped < 0) {
        [ratingView setImage:nil];
    } else {
        snprintf(digits, sizeof(digits), "%7d", clamped);
        SequenceRank rank = [Sequence rankOfPoint:clamped];
        [ratingView setImage:ratingImg[rank]];
    }
    for (int i = 0; i < kHighscoreDigitCount; ++i) {
        int glyph = digits[i] - kDigitZero;
        UIImage *image = ((unsigned int)glyph < kDigitGlyphCount) ? highscoreNumImg[glyph] : nil;
        [highscoreNumView[i] setImage:image];
    }
}

/** @ghidraAddress 0x537b0 */
- (nullable UIButton *)diffButton:(nullable NSString *)imageName {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    double size = self.isPad ? kDiffButtonSizePad :
                               (self.isRetina ? kDiffButtonSizeRetina : kDiffButtonSizeNonRetina);
    [button setFrame:CGRectMake(0.0, 0.0, size, size)];
    [button setImage:LoadScaledPngImage(imageName) forState:UIControlStateNormal];
    [button setExclusiveTouch:YES];
    [button setAdjustsImageWhenHighlighted:NO];
    [button setAdjustsImageWhenDisabled:NO];
    [button addTarget:self
                  action:@selector(selectDiff:)
        forControlEvents:UIControlEventTouchUpInside];
    return button;
}

/** @ghidraAddress 0x58ab8 */
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

/** @ghidraAddress 0x58938 */
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

/** @ghidraAddress 0x5ad18 */
- (void)editFileListViewSelectDownload {
    [[AudioManager sharedManager] playSeResFile:kMusicRightSound inDirectory:nil];
    [NSUserDefaults.standardUserDefaults setInteger:kJcfDownloadSelectDownload
                                             forKey:kPrefJcfDownloadSelectKey];
    [self.controller dismissViewControllerAnimated:self.isPad completion:nil];
    self.jcfDownloadPage = [[JcfDownloadPageNavController alloc] initWithMusicID:self.info.tuneID
                                                                        delegate:self];
    [self.controller presentViewController:self.jcfDownloadPage animated:YES completion:nil];
}

/** @ghidraAddress 0x5dc04 */
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

/** @ghidraAddress 0x5dd90 */
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

/** @ghidraAddress 0x5dfe4 */
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

/** @ghidraAddress 0x5e780 */
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

/** @ghidraAddress 0x5679c */
- (void)clearInfo {
    [self.artworkView setImage:nil];
    [self.reflectionArtworkView setImage:nil];
    [self.tuneNameView setImage:nil];
}

/** @ghidraAddress 0x5b3f8 */
- (void)editFileListViewSelectEdit {
    [[AudioManager sharedManager] playSeResFile:kEditSelectSound inDirectory:nil];
    [self.controller dismissViewControllerAnimated:YES completion:nil];
    [self editStart];
}

/** @ghidraAddress 0x5e308 */
- (void)editFileListViewCancel:(nullable id)sender {
    [self.controller enableCoverTap];
    [self.controller dismissViewControllerAnimated:YES completion:nil];
}

/** @ghidraAddress 0x5e1d8 */
- (void)selectEditFile:(nullable id)fileName {
    [[EditDataManager sharedManager] setLastEditFileName:(int)self.info.tuneID fileName:fileName];
    [self.controller enableCoverTap];
}

/** @ghidraAddress 0x5d0c4 */
- (BOOL)checkDownloadFile {
    if ([[EditDataManager sharedManager] getLastEditFileName:(int)self.info.tuneID] == nil) {
        return YES;
    }
    return [EditDataManager sharedManager].bIsDownload;
}

/** @ghidraAddress 0x5e38c */
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

/** @ghidraAddress 0x5e46c */
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

/** @ghidraAddress 0x5e54c */
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

/** @ghidraAddress 0x5e9b8 */
- (void)removeUploadView {
    if (upLoadView != nil) {
        [topcover removeFromSuperview];
        topcover = nil;
        [upLoadView removeFromSuperview];
        upLoadView = nil;
    }
}

/** @ghidraAddress 0x5e664 */
- (void)customWebViewClose:(nullable id)webView seqIndex:(nullable id)seqIndex {
    [self resetTextField:(int)self.info.tuneID isFirst:NO];
    [self setStartButtonEnable];
    [[AudioManager sharedManager] playSeResFile:kMusicLeftSound inDirectory:nil];
    [self.controller enableCoverTap];
    [self.controller dismissViewControllerAnimated:YES completion:nil];
}

/** @ghidraAddress 0x5c500 */
- (void)scrollViewDidScroll:(nullable UIScrollView *)scrollView {
    float offsetX = (float)scrollView.contentOffset.x;
    float half = (float)(scrollView.contentSize.width * 0.5);
    float denom = half * kScrollFadeSpanFraction;
    [detailScrollButton[0] setAlpha:(double)(1.0f - MIN(offsetX / denom, 1.0f))];
    [detailScrollButton[1] setAlpha:(double)(1.0f - MIN((half - offsetX) / denom, 1.0f))];
}

/** @ghidraAddress 0x57aa4 */
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

/** @ghidraAddress 0x5f390 */
- (CGPoint)getDifficultyPos:(int)difficulty {
    int index = (difficulty > 2) ? 0 : difficulty;
    int scrollY = (int)self.scrollView.frame.origin.y;
    int buttonX = (int)btnDiff[index].frame.origin.x;
    int scrollX = (int)self.scrollView.frame.origin.x;
    int buttonY = (int)btnDiff[index].frame.origin.y;
    return CGPointMake((double)(int)((double)scrollX + (double)buttonX),
                       (double)(int)((double)scrollY + (double)buttonY));
}

/** @ghidraAddress 0x599e4 */
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

    __weak MusicDetailViewOrg *weakSelf = self;
    if (show) {
        [self.shareDataProgress setHidden:NO];
        [self.shareDataProgress setAlpha:0.0];
        [self.shareDataProgress setProgress:0.0];
        [UIView animateWithDuration:kShareProgressAnimDuration
                         animations:^{
                           /** @ghidraAddress 0x59dc0 */
                           [weakSelf.shareDataProgress setAlpha:1.0];
                           [weakSelf.labelShareMessage setTransform:labelDrop];
                         }];
    } else {
        [UIView animateWithDuration:kShareProgressAnimDuration
            animations:^{
              /** @ghidraAddress 0x59ea4 */
              [weakSelf.shareDataProgress setAlpha:0.0];
              [weakSelf.labelShareMessage setTransform:CGAffineTransformIdentity];
            }
            completion:^(BOOL finished) {
              /** @ghidraAddress 0x59f84 */
              [weakSelf.shareDataProgress setHidden:YES];
            }];
    }
}

/** @ghidraAddress 0x580e8 */
- (void)resetTextField:(int)index isFirst:(BOOL)isFirst {
    EditDataManager *manager = [EditDataManager sharedManager];
    NSString *lastEdit = [manager getLastEditFileName:index];
    self.isFirstSelect = YES;
    __weak UIButton *weakInfo = infoBtn;
    __weak UIButton *weakUpload = uploadBtn;
    __weak UIButton *weakEdit = editBtn;
    if (lastEdit == nil) {
        // No edit loaded: blank and dim the three text fields, hide the extend level image, and
        // fade the edit buttons in.
        [editTxt[0] setText:@""];
        [editTxt[0] setAlpha:kEditTextDimmedAlpha];
        [editTxt[1] setText:@""];
        [editTxt[1] setAlpha:kEditTextDimmedAlpha];
        [editTxt[2] setText:@""];
        [editTxt[2] setAlpha:kEditTextDimmedAlpha];
        [levelNumView[kExtendLevelNumIndex] setAlpha:0.0];
        [manager clearEditData];
        [self setStartButtonEnable];
        [UIView animateWithDuration:kResetTextFadeDuration
                         animations:^{
                           /** @ghidraAddress 0x58834 */
                           [weakInfo setAlpha:1.0];
                           [weakUpload setAlpha:1.0];
                           [weakEdit setAlpha:1.0];
                         }
                         completion:nil];
        return;
    }

    // An edit is loaded: show the fields fully, fade the edit buttons in, fill the fields from the
    // editor info, set the extend level image (from the extend row of the level table), and toggle
    // the info button's tap feedback on the download flag.
    self.isFirstSelect = NO;
    [self setStartButtonEnable];
    [editTxt[0] setAlpha:1.0];
    [editTxt[1] setAlpha:1.0];
    [editTxt[2] setAlpha:1.0];
    NSMutableDictionary *editorInfo = [manager getEditorInfo];
    int dlFlag = [editorInfo[@"dlFlag"] intValue];
    [UIView animateWithDuration:kResetTextFadeDuration
                     animations:^{
                       /** @ghidraAddress 0x5872c */
                       [weakInfo setAlpha:1.0];
                       [weakUpload setAlpha:1.0];
                       [weakEdit setAlpha:1.0];
                     }
                     completion:nil];
    [editTxt[0] setText:editorInfo[@"fumenName"]];
    [editTxt[1] setText:editorInfo[@"editorName"]];
    [editTxt[2] setText:editorInfo[@"comment"]];
    int level = [editorInfo[@"level"] intValue];
    [levelNumView[kExtendLevelNumIndex] setImage:levelNumImg[kExtendLevelRow][level]];
    [levelNumView[kExtendLevelNumIndex] setAlpha:1.0];
    if (dlFlag == kEditDownloadFlag) {
        [infoBtn setAdjustsImageWhenHighlighted:NO];
        [infoBtn setAdjustsImageWhenDisabled:NO];
    } else {
        [infoBtn setAdjustsImageWhenHighlighted:YES];
        [infoBtn setAdjustsImageWhenDisabled:YES];
    }
}

/** @ghidraAddress 0x56850 */
- (void)selectDiff:(nullable id)sender {
    if (self.isStarted) {
        return;
    }
    int current = (int)[NSUserDefaults.standardUserDefaults integerForKey:kPrefDifficultyKey];
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];

    // Identify which difficulty button was tapped; the edit button (index 3) opens the edit
    // popover.
    NSString *voiceCue;
    int tapped;
    if (btnDiff[0] == sender) {
        voiceCue = kDifficultyVoiceCues[0];
        tapped = 0;
    } else if (btnDiff[1] == sender) {
        voiceCue = kDifficultyVoiceCues[1];
        tapped = 1;
    } else if (btnDiff[2] == sender) {
        voiceCue = kDifficultyVoiceCues[2];
        tapped = 2;
    } else if (btnDiff[kExtendLevelNumIndex] == sender) {
        // The edit button: on the first download selection, hide the lamps and remember the choice.
        if ([[NSUserDefaults.standardUserDefaults objectForKey:kPrefJcfDownloadSelectKey]
                intValue] == 1) {
            [NSUserDefaults.standardUserDefaults setInteger:kJcfDownloadSelectDownload
                                                     forKey:kPrefJcfDownloadSelectKey];
            [scrollLamp setHidden:YES];
            [diffBtnLamp setHidden:YES];
        }
        [self editPopoverOpen];
        [[UIApplication sharedApplication] performSelector:@selector(endIgnoringInteractionEvents)
                                                withObject:nil
                                                afterDelay:0.0];
        return;
    } else {
        return;
    }

    __weak MusicDetailViewOrg *weakSelf = self;
    if (current == tapped) {
        // Re-tapping the current difficulty toggles the extend chart when the tune has one; the
        // high-score board slides in from an offset.
        NSTimeInterval inputLock = kSelectDiffInputLock;
        if (self.info.extendID != 0 && self.extendInfo != nil &&
            (self.extendInfo.extendFlag & (1 << current)) != 0) {
            [JubeatAppDelegate.appDelegate setExtendFlag:!JubeatAppDelegate.appDelegate.isExtend];
            [[AudioManager sharedManager] playSeResFile:kExtendModeSound inDirectory:nil];
            [self changeExtend:current];
            double homeX = self.isPad ?
                               kHighscoreBoardXPad :
                               (self.isRetina ? kHighscoreBoardXRetina : kHighscoreBoardXNonRetina);
            double slide = self.isPad ? kHighscoreBoardSlidePad : kHighscoreBoardSlidePhone;
            double y = self.isPad ? kHighscoreBoardYPad : kHighscoreBoardYPhone;
            [highscoreBoardView setCenter:CGPointMake(homeX - slide, y)];
            [highscoreBoardView setAlpha:0.0];
            [NSUserDefaults.standardUserDefaults setInteger:current forKey:kPrefDifficultyKey];
            [UIView animateWithDuration:kExtendModeAnimDuration
                             animations:^{
                               /** @ghidraAddress 0x570a4 */
                               [weakSelf changeDifficulty:current];
                               MusicDetailViewOrgRepositionHighscoreBoard(weakSelf);
                               [weakSelf->highscoreBoardView setAlpha:1.0];
                             }];
            inputLock = kSelectDiffExtendInputLock;
        }
        [[UIApplication sharedApplication] performSelector:@selector(endIgnoringInteractionEvents)
                                                withObject:nil
                                                afterDelay:inputLock];
        return;
    }

    // A different difficulty: slide the high-score board out (dimmed), play the voice cue, persist
    // the choice, and slide it back in.
    double homeX = self.isPad ?
                       kHighscoreBoardXPad :
                       (self.isRetina ? kHighscoreBoardXRetina : kHighscoreBoardXNonRetina);
    double slide = self.isPad ? kHighscoreBoardSlidePad : kHighscoreBoardSlidePhone;
    double y = self.isPad ? kHighscoreBoardYPad : kHighscoreBoardYPhone;
    [highscoreBoardView setCenter:CGPointMake(homeX - slide, y)];
    [highscoreBoardView setAlpha:kHighscoreBoardDimAlpha];
    [[AudioManager sharedManager] playSeResFile:voiceCue inDirectory:nil];
    [NSUserDefaults.standardUserDefaults setInteger:tapped forKey:kPrefDifficultyKey];
    [UIView animateWithDuration:kExtendModeAnimDuration
                     animations:^{
                       /** @ghidraAddress 0x57054 */
                       [weakSelf changeDifficulty:tapped];
                     }];
    [[UIApplication sharedApplication] performSelector:@selector(endIgnoringInteractionEvents)
                                            withObject:nil
                                            afterDelay:kSelectDiffInputLock];
}

/** @ghidraAddress 0x56070 */
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

        __weak MusicDetailViewOrg *weakSelf = self;
        [UIView animateWithDuration:kExtendCrossFadeDuration
                         animations:^{
                           /** @ghidraAddress 0x565f8 */
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

/** @ghidraAddress 0x5ef1c */
- (void)changeExtendMode {
    if (self.info.extendID != 0) {
        int difficulty =
            (int)[NSUserDefaults.standardUserDefaults integerForKey:kPrefDifficultyKey];
        if (self.extendInfo != nil && (self.extendInfo.extendFlag & (1 << difficulty)) != 0) {
            // Flip the app-wide extend toggle, re-lay the extend info, and slide the score board in
            // from an offset for the new mode.
            [JubeatAppDelegate.appDelegate setExtendFlag:!JubeatAppDelegate.appDelegate.isExtend];
            [[AudioManager sharedManager] playSeResFile:kExtendModeSound inDirectory:nil];
            [self changeExtend:difficulty];

            double homeX = self.isPad ?
                               kHighscoreBoardXPad :
                               (self.isRetina ? kHighscoreBoardXRetina : kHighscoreBoardXNonRetina);
            double slide = self.isPad ? kHighscoreBoardSlidePad : kHighscoreBoardSlidePhone;
            double y = self.isPad ? kHighscoreBoardYPad : kHighscoreBoardYPhone;
            [highscoreBoardView setCenter:CGPointMake(homeX - slide, y)];
            [highscoreBoardView setAlpha:0.0];
            [NSUserDefaults.standardUserDefaults setInteger:difficulty forKey:kPrefDifficultyKey];

            [UIView animateWithDuration:kExtendModeAnimDuration
                             animations:^{
                               /** @ghidraAddress 0x5f2c4 */
                               [self changeDifficulty:difficulty];
                               double hx = self.isPad ? kHighscoreBoardXPad :
                                                        (self.isRetina ? kHighscoreBoardXRetina :
                                                                         kHighscoreBoardXNonRetina);
                               double hy = self.isPad ? kHighscoreBoardYPad : kHighscoreBoardYPhone;
                               [self->highscoreBoardView setCenter:CGPointMake(hx, hy)];
                               [self->highscoreBoardView setAlpha:1.0];
                             }];
        }
    }
    // Input is briefly locked out while the mode change settles.
    [[UIApplication sharedApplication] performSelector:@selector(endIgnoringInteractionEvents)
                                            withObject:nil
                                            afterDelay:kExtendModeInputLock];
}

/** @ghidraAddress 0x57bc8 */
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

    // A downloaded edit shows its author's user-tag badge at a per-idiom fixed origin on the extend
    // button.
    NSMutableDictionary *editorInfo = [manager getEditorInfo];
    if (manager.bIsDownload) {
        int userTag = [editorInfo[@"userTag"] intValue];
        UIImage *badge = LoadScaledPngImage(kUserTagIconNames[userTag]);
        userTagIcon = [[UIImageView alloc] initWithImage:badge];
        double x =
            self.isPad ? kUserTagXPad : (self.isRetina ? kUserTagXRetina : kUserTagXNonRetina);
        double y =
            self.isPad ? kUserTagYPad : (self.isRetina ? kUserTagYRetina : kUserTagYNonRetina);
        [userTagIcon setFrame:CGRectMake(x, y, badge.size.width, badge.size.height)];
        [btnDiff[kExtendLevelNumIndex] addSubview:userTagIcon];
    }
}

/** @ghidraAddress 0x55bbc */
- (void)setExtendInfo:(nullable TuneInfo *)info score:(nullable id)score {
    [super setExtendInfo:info score:score];
    [self loadExtendMusicBar:info.filePath];

    // Every hold and extend mark starts hidden across the three difficulties.
    for (int i = 0; i < kDiffButtonCount; ++i) {
        [holdMark[i] setHidden:YES];
        [extendMark[i] setHidden:YES];
        [extendOnMark[i] setHidden:YES];
    }

    self.extendLevelBas = MusicDetailViewOrgLevelIndex(info.lvBas);
    self.extendLevelAdv = MusicDetailViewOrgLevelIndex(info.lvAdv);
    self.extendLevelExt = MusicDetailViewOrgLevelIndex(info.lvExt);

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

/** @ghidraAddress 0x5b914 */
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

            __weak MusicDetailViewOrg *weakSelf = self;
            [UIView animateWithDuration:kHostShareStartFadeDuration
                animations:^{
                  /** @ghidraAddress 0x5bf18 */
                  [weakSelf.labelShareMessage setAlpha:1.0];
                  [weakSelf.buttonHostSharePlay setEnabled:NO];
                }
                completion:^(BOOL finished) {
                  /** @ghidraAddress 0x5c004 */
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

/** @ghidraAddress 0x5aefc */
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
                       /** @ghidraAddress 0x5b2d0 */
                       [weakCover setAlpha:1.0];
                       [weakUpload setAlpha:1.0];
                     }
                     completion:nil];
    [self.controller unenableCoverTap];
}

/** @ghidraAddress 0x5b498 */
- (void)editStart {
    [[AudioManager sharedManager] playSeResFile:kEditSelectSound inDirectory:nil];
    [self.controller showButtonMarker:NO];
    [self.buttonStartPlay setEnabled:NO];

    __weak MusicDetailViewOrg *weakSelf = self;
    [UIView animateWithDuration:kEditTransitionDuration
        delay:0.0
        options:UIViewAnimationOptionBeginFromCurrentState
        animations:^{
          /** @ghidraAddress 0x5b6c8 */
          CATransform3D shrink =
              CATransform3DMakeScale(kEditButtonShrinkScale, kEditButtonShrinkScale, 1.0);
          for (int i = 0; i < kDiffButtonCount; ++i) {
              [self->btnDiff[i] setAlpha:0.0];
              self->btnDiff[i].layer.transform = shrink;
          }
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x5b864 */
          [weakSelf.controller startEdit:weakSelf.info];
        }];

    // Input is ignored through the transition and re-enabled a beat after it ends.
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    [[UIApplication sharedApplication] performSelector:@selector(endIgnoringInteractionEvents)
                                            withObject:nil
                                            afterDelay:kEditInputLockDuration];
}

/** @ghidraAddress 0x54ad8 */
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

/** @ghidraAddress 0x53958 */
- (void)loadImages {
    @autoreleasepool {
        for (int i = 0; i < (int)(sizeof(kRatingImageNames) / sizeof(kRatingImageNames[0])); ++i) {
            ratingImg[i] = LoadScaledPngImage(kRatingImageNames[i]);
        }

        // Each column loads the shared score glyph and the five per-difficulty level glyphs.
        for (int i = 0; i < kLevelImageCount; ++i) {
            highscoreNumImg[i] =
                LoadScaledPngImage([NSString stringWithFormat:kHighscoreDigitFormat, i]);
            for (int row = 0; row < kLevelWordRowCount; ++row) {
                levelNumImg[row][i] =
                    LoadScaledPngImage([NSString stringWithFormat:kLevelNumberFormats[row], i + 1]);
            }
        }

        for (int i = 0; i < (int)(sizeof(kLevelTextNames) / sizeof(kLevelTextNames[0])); ++i) {
            levelTextImg[i] = LoadScaledPngImage(kLevelTextNames[i]);
        }

        // The music-bar bars stretch from a resizable image with a single cap inset.
        UIEdgeInsets insets = UIEdgeInsetsMake(0, kMusicBarCapInset, 0, kMusicBarCapInset);
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

        // The classic theme has no separate excellent image.
        fullcomboImg = LoadScaledPngImage(kFullcomboImageName);
    }
}

/** @ghidraAddress 0x544f0 */
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
    NSMutableData *nameData = [archive uncompress:kContentNameW];
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

/** @ghidraAddress 0x5415c */
- (void)loadContentFromDictionary:(nullable NSDictionary *)dict {
    UIImage *artwork = [UIImage imageWithData:dict[kContentArtwork]];
    if (artwork != nil) {
        [self.artworkView setImage:artwork];
        double fraction = self.isPad ? kReflectionFractionPad : g_dAnimDuration020;
        int reflectionHeight = (int)(artwork.size.height * fraction);
        [self.reflectionArtworkView setImage:CreateReflectedImage(artwork, reflectionHeight)];
    }
    UIImage *nameImage = [UIImage imageWithData:dict[kContentNameW]];
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
    // On the detail page (edit page 0) the classic theme re-applies the preferred difficulty once
    // the bars are loaded.
    if ([NSUserDefaults.standardUserDefaults integerForKey:kPrefEditSelectKey] == 0) {
        int difficulty =
            (int)[NSUserDefaults.standardUserDefaults integerForKey:kPrefDifficultyKey];
        [self changeDifficulty:difficulty];
    }
}

/** @ghidraAddress 0x5c05c */
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

    __weak MusicDetailViewOrg *weakSelf = self;
    [UIView animateWithDuration:kRandViewToggleDuration
                     animations:^{
                       /** @ghidraAddress 0x5c3c0 */
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

/** @ghidraAddress 0x59668 */
- (void)hostShareCancelled {
    [self.buttonHostSharePlay
        setBackgroundImage:[[ImageCache sharedCache] getResPNG:kHostButtonImage]
                  forState:UIControlStateNormal];
    [self setStartButtonEnable];
    [self.buttonStartPlay setBackgroundImage:[self getSingleImage] forState:UIControlStateNormal];
    [self.buttonLink setEnabled:YES];
    [self.btnRecommendTwitter setEnabled:YES];
    [self.btnRecommendFacebook setEnabled:YES];

    __weak MusicDetailViewOrg *weakSelf = self;
    [UIView animateWithDuration:kHostShareCancelFadeDuration
        animations:^{
          /** @ghidraAddress 0x5990c */
          [weakSelf.labelShareMessage setAlpha:0.0];
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x59978 */
          [weakSelf.labelShareMessage setHidden:YES];
        }];
}

/** @ghidraAddress 0x5ea20 */
- (void)uploadEnd:(nullable id)sender {
    __weak UIView *weakCover = topcover;
    __weak JcfUpLoadView *weakUpload = upLoadView;
    // The binary passes a negative fade duration here; kept as-is.
    [UIView animateWithDuration:kUploadEndFadeDuration
        animations:^{
          /** @ghidraAddress 0x5ebc4 */
          [weakCover setAlpha:0.0];
          [weakUpload setAlpha:0.0];
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x5ec8c */
          [self removeUploadView];
        }];
    [self.controller enableCoverTap];
}

/** @ghidraAddress 0x5786c */
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

/** @ghidraAddress 0x5c5dc */
- (void)scrollViewDidEndScrollingAnimation:(nullable UIScrollView *)scrollView {
    [detailScrollButton[0] setAlpha:1.0];
    [detailScrollButton[1] setAlpha:1.0];
    MusicDetailViewOrgSettleScrollPage(self);
}

/** @ghidraAddress 0x5c8c8 */
- (void)scrollViewDidEndDecelerating:(nullable UIScrollView *)scrollView {
    MusicDetailViewOrgSettleScrollPage(self);
}

/** @ghidraAddress 0x5cb8c */
- (void)scrollViewDidEndDragging:(nullable UIScrollView *)scrollView
                  willDecelerate:(BOOL)decelerate {
    if (!decelerate) {
        MusicDetailViewOrgSettleScrollPage(self);
    }
}

/** @ghidraAddress 0x59ff0 */
- (void)activateAnim:(BOOL)activate {
    int difficulty = (int)[NSUserDefaults.standardUserDefaults integerForKey:kPrefDifficultyKey];
    if (activate) {
        [lightView[difficulty][0].layer addAnimation:lightBlinkAnim forKey:kBlinkAnimationKey];
        [lightView[difficulty][1].layer addAnimation:lightBlinkAnim forKey:kBlinkAnimationKey];
        return;
    }
    [lightView[difficulty][0].layer removeAnimationForKey:kBlinkAnimationKey];
    [lightView[difficulty][0] setAlpha:1.0];
    [lightView[difficulty][1].layer removeAnimationForKey:kBlinkAnimationKey];
    [lightView[difficulty][1] setAlpha:1.0];
}

/** @ghidraAddress 0x5d3c4 */
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
    [self.pFileListView setTuneID:self.info.tuneID];
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
        [popover setSourceRect:btnDiff[kExtendLevelNumIndex].frame];
        [self.controller presentViewController:self.pFileListView animated:YES completion:nil];
    }
    [[AudioManager sharedManager] playSeResFile:kMusicSelectSound inDirectory:nil];
}

/** @ghidraAddress 0x5d1b4 */
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

/** @ghidraAddress 0x5ce5c */
- (void)editModalViewClose:(nullable id)sender {
    [[AudioManager sharedManager] playSeResFile:kMusicLeftSound inDirectory:nil];
    NSMutableDictionary *editorInfo = [[EditDataManager sharedManager] getEditorInfo];
    [editTxt[0] setText:editorInfo[@"fumenName"]];
    [editTxt[1] setText:editorInfo[@"editorName"]];
    [editTxt[2] setText:editorInfo[@"comment"]];
    int level = [editorInfo[@"level"] intValue];
    // The classic theme keeps level images in a per-difficulty table; the extend slot uses the
    // extend row.
    [levelNumView[kExtendLevelNumIndex] setImage:levelNumImg[kExtendLevelRow][level]];
    [levelNumView[kExtendLevelNumIndex] setAlpha:1.0];
    [self.controller dismissViewControllerAnimated:YES completion:nil];
    [self.controller enableCoverTap];
}

/** @ghidraAddress 0x5ecac */
- (nullable id)getStartImage {
    if (![JubeatAppDelegate.appDelegate isRandom]) {
        return [[ImageCache sharedCache] getResPNG:kStartButtonImage];
    }
    if ([JubeatAppDelegate.appDelegate isHold]) {
        return [[ImageCache sharedCache] getResPNG:kStartButtonImage];
    }
    return [[ImageCache sharedCache] getResPNG:kRandomButtonImage];
}

/** @ghidraAddress 0x5ede4 */
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
