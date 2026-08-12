#import "MusicDetailViewKnt.h"

#import <QuartzCore/QuartzCore.h>

#import "AlertViewManager.h"
#import "AudioManager.h"
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
#import "LabUtilities.h"
#import "LatelyJcfListManager.h"
#import "MusicSelectViewController.h"
#import "Sequence.h"
#import "SharePlayManager.h"
#import "TuneInfo.h"
#import "cipher_keys.h"

// The shared 0.2 animation-duration double, reused here as the phone reflection-height fraction.
static const double g_dAnimDuration020 = 0.2; // @ghidraAddress 0x28f240

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
static const int kExtendLevelNumIndex = 3;

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
enum {
    kExtendMbarBasicRow = 0,
    kExtendMbarAdvancedRow = 1,
    kExtendMbarExtremeRow = 2,
};

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

// The per-difficulty voice cues, indexed by base difficulty.
static NSString *const kDifficultyVoiceCues[] = {
    @"SD_KNT_CV_BASIC", @"SD_KNT_CV_ADVANCED", @"SD_KNT_CV_EXTREME"};

// selectDiff: input-lock delays: 0.4 after a difficulty change, 0.3 after an extend toggle.
static const NSTimeInterval kSelectDiffInputLock = 0.4;       // @ghidraAddress 0x28f268
static const NSTimeInterval kSelectDiffExtendInputLock = 0.3; // @ghidraAddress 0x28f260

// The download-lamp pulse timing: after a half-second delay each lamp pulses to double height and
// fades out over a half second.
static const NSTimeInterval kLampPulseDuration = 0.5; // fmov d0, 0.5
static const NSTimeInterval kLampPulseDelay = 0.5;    // fmov d1, 0.5
static const CGFloat kLampPulseHeightScale = 2.0;     // fmov d1, 2.0
static const NSInteger kJcfDownloadSelectPending = 1;

// The share-message label drops six points to make room for the progress bar; the show/hide
// animates over three tenths of a second.
static const double kShareLabelDropOffset = 6.0;              // fmov d1, 6.0
static const NSTimeInterval kShareProgressAnimDuration = 0.3; // @ghidraAddress 0x28f260

// The edit music bar uses the fourth music-bar image, its dot data spans 60 bytes, and its
// user-tag badge (blank/staff/artist) sits inset from the extend button's right edge.
static const int kEditMbarBackgroundImage = 3;
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
static const int kLevelImageCount = 10;

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

// The edit text fields sit at half opacity when no edit is loaded, full when one is; the buttons
// fade over a tenth of a second. The download flag disables the info button's tap feedback.
static const CGFloat kEditTextDimmedAlpha = 0.5;          // fmov d0, 0.5
static const NSTimeInterval kResetTextFadeDuration = 0.1; // @ghidraAddress 0x28f290
static const NSInteger kEditDownloadFlag = 1;

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

// A music bar must carry at least 30 bytes of dot-resource data to be shown.
static const NSUInteger kMbarMinimumLength = 30;

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

// Moves the high-score text view to its per-idiom resting centre (base x + 40; y -7 on the pad,
// -6 on the phone). Shared by the difficulty-select and extend-toggle repositioning.
static inline void MusicDetailViewKntRepositionHighscore(MusicDetailViewKnt *self,
                                                         UIImageView *highscoreTextView) {
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
}

// Sets the difficulty buttons for a selected difficulty: the selected base button and the extend
// button are shown full and unscaled, the other two base buttons are dimmed and shrunk. Shared by
// changeDifficulty: and show:.
static inline void MusicDetailViewKntSetDifficultyButtons(UIButton *const *btnDiff, int selected) {
    for (int i = 0; i < kDiffButtonCount; ++i) {
        if (i == selected) {
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
}

// Dims and shrinks every base difficulty button except the selected one, used when play starts.
// The extend button (index 3) is left untouched.
static inline void MusicDetailViewKntDimUnselectedButtons(UIButton *const *btnDiff, int selected) {
    CATransform3D shrink =
        CATransform3DMakeScale(kStartPlayShrinkScale, kStartPlayShrinkScale, 1.0);
    for (int i = 0; i < kDiffButtonCount; ++i) {
        if (i != selected) {
            [btnDiff[i] setAlpha:0.0];
            btnDiff[i].layer.transform = shrink;
        }
    }
}

// Pre-seeds one difficulty row's extend marks before the crossfade: reveals the extend and
// extend-on marks and sets their starting alphas (the target mark full, the other transparent),
// then zeroes the hold mark. Used by changeExtend: for each difficulty that carries an extend
// chart, with extendOnTarget YES when the app is in extend mode.
static inline void MusicDetailViewKntSeedExtendRow(UIImageView *const *extendMark,
                                                   UIImageView *const *extendOnMark,
                                                   UIImageView *const *holdMark,
                                                   int row,
                                                   BOOL extendOnTarget) {
    [extendMark[row] setHidden:NO];
    [extendOnMark[row] setHidden:NO];
    [extendMark[row] setAlpha:(extendOnTarget ? 0.0 : 1.0)];
    [extendOnMark[row] setAlpha:(extendOnTarget ? 1.0 : 0.0)];
    [holdMark[row] setAlpha:0.0];
}

// The three scroll-settled delegate callbacks share this tail: it snaps the settled page,
// re-derives the hold flag from the current difficulty's hold mark (except on the edit page),
// refreshes the start button, records the page, and applies either the difficulty (snapping a stale
// extreme back to basic) on the detail page or the edit music bar on the edit page.
static inline void MusicDetailViewKntSettleScrollPage(MusicDetailViewKnt *self,
                                                      UIImageView *const *holdMark) {
    [self setEnableButton:YES];
    double width = self.scrollView.frame.size.width;
    int page = (int)((width * 0.5 + self.scrollView.contentOffset.x) / width);
    self.editPage = page;
    int difficulty = (int)[NSUserDefaults.standardUserDefaults integerForKey:kPrefDifficultyKey];
    BOOL holdHidden = holdMark[difficulty].isHidden;
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

// The layout constants used only while building the card in -initWithFrame:. The Knit theme lays
// everything out three ways: pad, retina phone, and non-retina phone.

// The scroll view's top band is (pad 418 / phone 210) minus its own height (pad 100 / phone 50); it
// holds two full-width pages of (pad 200 / phone 100) height.
static const double kScrollViewTopBasePad = 418.0;         // 0x1a2
static const double kScrollViewTopBasePhone = 210.0;       // 0xd2
static const double kScrollViewTopInsetPad = 100.0;        // 0x64
static const double kScrollViewTopInsetPhone = 50.0;       // 0x32
static const double kScrollViewContentHeightPad = 200.0;   // @ghidraAddress 0x28f400
static const double kScrollViewContentHeightPhone = 100.0; // @ghidraAddress 0x28f3f0
static const NSInteger kScrollViewAutoresizingMask = 18;

// The card background is opaque white at 0.9 alpha; the gradient border is 2pt light grey and its
// stops run white (0.9 alpha) to 60% grey.
static const CGFloat kCardBackgroundWhite = 1.0;
static const CGFloat kCardBackgroundAlpha = 0.9; // @ghidraAddress 0x28f448
static const CGFloat kCardBorderWidth = 2.0;
static const CGFloat kGradientTopWhite = 0.9;    // @ghidraAddress 0x28f448
static const CGFloat kGradientBottomWhite = 0.6; // @ghidraAddress 0x28f230
static const CGFloat kGradientAlpha = 0.9;       // @ghidraAddress 0x28f448

// The full-card background image, pinned to the card's bottom behind everything.
static NSString *const kDetailBackgroundImage = @"msel_detail_bg_knt";

// The artwork and reflection (shared idiom sizing): square side (pad 200 / retina 110 /
// non-retina 95), inset (pad 10 / phone 8), reflection nudged (retina 0.5 / non-retina 1.0) and a
// fraction (pad 0.3 / phone 0.2) as tall.
static const double kArtworkInsetPad = 10.0;
static const double kArtworkInsetPhone = 8.0;
static const double kArtworkSizePad = 200.0;
static const double kArtworkSizeRetina = 110.0;   // 0x6e
static const double kArtworkSizeNonRetina = 95.0; // 0x5f
static const float kReflectionNudgeRetina = 0.5f;
static const float kReflectionNudgeNonRetina = 1.0f;
static const float kReflectionFractionPadF = 0.3f;   // @ghidraAddress 0x28e0b0 (g_flComboFadeBase)
static const float kReflectionFractionPhoneF = 0.2f; // @ghidraAddress 0x28f3c8

// The tune-name image and iTunes link sit right of the artwork.
static const double kTuneNameGapPad = 10.0;
static const double kTuneNameGapRetina = 5.0;
static const double kTuneNameGapNonRetina = 6.0;
static const double kTuneNameWidthPad = 340.0;       // @ghidraAddress 0x28f5e0
static const double kTuneNameWidthRetina = 170.0;    // @ghidraAddress 0x28f5d8
static const double kTuneNameWidthNonRetina = 204.0; // @ghidraAddress 0x28f5d0
static const double kTuneNameHeightPad = 64.0;       // @ghidraAddress 0x28f1f0
static const double kTuneNameHeightRetina = 32.0;    // @ghidraAddress 0x28f458
static const double kTuneNameHeightNonRetina = 38.0; // @ghidraAddress 0x28f4f8
static const double kButtonLinkYPad = 80.0;          // @ghidraAddress 0x28f3f8
static const double kButtonLinkYPhone = 48.0;        // @ghidraAddress 0x28f450

// The social recommend buttons stack rightwards from the card edge.
static const int kSocialInsetPad = 24;
static const int kSocialGapPad = 10;

// The difficulty buttons: first at a fixed left centre (pad 110 / phone 60), second mid-page,
// third near the right, fourth (edit) one page over; all at centre Y (pad 100 / phone 50). Each
// carries a level-number image (pad 100x80 origin, 32 square / phone 39x(retina 41 / non-retina 39)
// origin, 18 square).
static const double kDiffCenterEdgePad = 110.0;  // @ghidraAddress 0x28f5e8
static const double kDiffCenterEdgePhone = 60.0; // @ghidraAddress 0x28f258
static const double kDiffCenterYPad = 100.0;     // @ghidraAddress 0x28f3f0
static const double kDiffCenterYPhone = 50.0;    // @ghidraAddress 0x28f2c8
static NSString *const kDiffButtonNameFormat = @"msel_btn_%c_knt";
static const char kDiffButtonLetters[] = {'b', 'a', 'e', 'o'};
static const double kLevelNumYPad = 80.0;    // @ghidraAddress 0x28f3f8
static const double kLevelNumSizePad = 32.0; // @ghidraAddress 0x28f458
static const double kLevelNumXPhone = 39.0;  // @ghidraAddress 0x28f608
static const double kLevelNumYRetina = 41.0; // @ghidraAddress 0x28f5f8
static const double kLevelNumSizePhone = 18.0;

// The start-play/host-share buttons stack along the card's bottom; X offset (pad 120 / phone 75).
static const int kStartButtonXOffsetPad = 120;  // 0x78
static const int kStartButtonXOffsetPhone = 75; // 0x4b
static const double kButtonStackGapPad = 24.0;
static const double kButtonStackGapPhone = 10.0;

// The share label and progress bar are 300 wide; the same value negated centres them on the host
// button. The gaps, heights, and fonts are per idiom.
static const double kShareLabelWidth = 300.0;         // @ghidraAddress 0x28f2d0
static const double kShareLabelWidthNegated = -300.0; // @ghidraAddress 0x28f3e8
static const double kShareLabelHeightPad = 20.0;
static const double kShareLabelHeightPhone = 16.0;
static const double kShareLabelGapPad = 56.0; // @ghidraAddress 0x28f878
static const double kShareLabelGapPhone = 30.0;
static const double kShareLabelFontPad = 16.0;       // 0x4030
static const double kShareLabelFontPhone = 12.0;     // 0x4028
static const double kShareProgressGapPad = 60.0;     // @ghidraAddress 0x28f258
static const double kShareProgressGapPhone = 34.0;   // @ghidraAddress 0x28f648
static const double kShareProgressHeightPad = 12.0;  // 0x4028
static const double kShareProgressHeightPhone = 8.0; // 0x4020

// The note bar: its own view (width pad 568 / retina 290 / non-retina 300, height pad 38 /
// phone 19) centred at (frameWidth/2, pad 300 / phone 158), and 120 dots across it.
static const double kMusicBarWidthPad = 568.0;       // 0x238
static const double kMusicBarWidthRetina = 290.0;    // 0x122
static const double kMusicBarWidthNonRetina = 300.0; // 0x12c
static const double kMusicBarHeightPad = 38.0;       // @ghidraAddress 0x28f4f8
static const double kMusicBarHeightPhone = 19.0;
static const double kMusicBarCenterYPad = 300.0;   // @ghidraAddress 0x28f2d0
static const double kMusicBarCenterYPhone = 158.0; // @ghidraAddress 0x293af0
static const double kMusicBarDotHeightPad = 36.0;  // @ghidraAddress 0x28f530
static const int kMusicBarDotStartPad = 42;
static const int kMusicBarDotStartRetina = 25;
static const int kMusicBarDotStartNonRetina = 30;

// The high-score board, its text overlay, seven digits, a rating, and a combo image.
static NSString *const kHighscoreBoardImage = @"msc_hsboard_knt";
static NSString *const kHighscoreTextImage = @"msc_hstext_knt";
static const double kHighscoreBoardXPad = 420.0;       // @ghidraAddress 0x292538
static const double kHighscoreBoardXRetina = 215.0;    // @ghidraAddress 0x292e68
static const double kHighscoreBoardXNonRetina = 210.0; // @ghidraAddress 0x28f200
static const double kHighscoreBoardYPad = 240.0;       // @ghidraAddress 0x291bf0
static const double kHighscoreBoardYPhone = 120.0;     // @ghidraAddress 0x28f210

// The scroll arrows, info button, and pad-only upload/edit buttons.
static NSString *const kScrollArrowRight = @"btn_edit_scroll_r_knt";
static NSString *const kScrollArrowLeft = @"btn_edit_scroll_l_knt";
static NSString *const kEditInfoTextImage = @"edit_info_text_knt";
static NSString *const kUploadButtonImage = @"btn_upload_knt";
static NSString *const kEditButtonImage = @"btn_edit_knt";
static const int kEditTextFieldCount = 3;
static const int kEditCommentIndex = 2;
static const double kEditFieldWidthFraction = 0.95; // @ghidraAddress 0x28f6e0
static const double kInfoButtonDropPad = 212.0;     // @ghidraAddress 0x28f6d8
static const double kInfoButtonDropPhone = 114.0;   // @ghidraAddress 0x28f6d0
static const double kScrollArrowYPad = 20.0;
static const double kScrollArrowYPhone = 10.0;

// The pending-download lamps: the scroll lamp reuses the Knit right-arrow image; the difficulty
// lamp the Knit white button, sized to the difficulty button.
static NSString *const kScrollLampImage = @"btn_edit_scroll_r_knt";
static NSString *const kDiffButtonLampImage = @"msel_btn_white_knt";

// The hold and extend marks over each difficulty button, keyed by difficulty letters.
static NSString *const kHoldMarkFormat = @"hold_ico_%c_knt";
static NSString *const kExtendMarkFormat = @"add_ico_%c_knt";
static NSString *const kExtendOnMarkFormat = @"add_ico_%c_on_knt";
static const double kHostGapNegative = -40.0; // @ghidraAddress 0x28e078
static const double kMarkInsetPad = 32.0;     // @ghidraAddress 0x28f458
static const double kMarkInsetPhone = 16.0;
static const double kMarkTopPad = 4.0;
static const double kMarkHeightPad = 16.0;

// Builds one difficulty slot: its button (added to the scroll view and centred) and its
// level-number image. @p center is the button's centre in the scroll view.
static inline void MusicDetailViewKntBuildDifficultyButton(MusicDetailViewKnt *self,
                                                           UIButton *__strong *btnDiff,
                                                           UIImageView *__strong *levelNumView,
                                                           int index,
                                                           CGPoint center) {
    BOOL isPad = self.isPad;
    BOOL isRetina = self.isRetina;
    btnDiff[index] = [self
        diffButton:[NSString stringWithFormat:kDiffButtonNameFormat, kDiffButtonLetters[index]]];
    CGRect numFrame;
    if (isPad) {
        numFrame = CGRectMake(kDiffCenterYPad, kLevelNumYPad, kLevelNumSizePad, kLevelNumSizePad);
    } else {
        double numX = kLevelNumXPhone;
        double numY = isRetina ? kLevelNumYRetina : kLevelNumXPhone;
        numFrame = CGRectMake(numX, numY, kLevelNumSizePhone, kLevelNumSizePhone);
    }
    levelNumView[index] = [[UIImageView alloc] initWithFrame:numFrame];
    [btnDiff[index] addSubview:levelNumView[index]];
    [btnDiff[index] setCenter:center];
    [self.scrollView addSubview:btnDiff[index]];
}

@implementation MusicDetailViewKnt

/** @ghidraAddress 0x1955c4 */
+ (Class)layerClass {
    return [CAGradientLayer class];
}

/** @ghidraAddress 0x1a3284 */
- (void)dealloc {
    // The binary emits an explicit override that only chains to super (its own .cxx_destruct runs
    // the ARC ivar teardown). [super dealloc] is compiler-emitted under ARC.
}

/** @ghidraAddress 0x1955d8 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self == nil) {
        return nil;
    }
    bRandomBak = NO;
    BOOL isPad = self.isPad;
    BOOL isRetina = self.isRetina;
    double width = frame.size.width;

    // The scroll view fills the lower band of the card and holds two full-width pages. It also
    // takes exclusive touch on the Knit theme.
    double scrollTop = (isPad ? kScrollViewTopBasePad : kScrollViewTopBasePhone) -
                       (isPad ? kScrollViewTopInsetPad : kScrollViewTopInsetPhone);
    double scrollHeight = isPad ? kScrollViewContentHeightPad : kScrollViewContentHeightPhone;
    self.scrollView =
        [[UIScrollView alloc] initWithFrame:CGRectMake(0.0, scrollTop, width, scrollHeight)];
    [self.scrollView setUserInteractionEnabled:YES];
    [self.scrollView setMultipleTouchEnabled:NO];
    [self.scrollView setAutoresizesSubviews:NO];
    [self.scrollView setExclusiveTouch:YES];
    [self.scrollView setOpaque:NO];
    [self.scrollView setBounces:NO];
    [self.scrollView setBackgroundColor:UIColor.clearColor];
    [self.scrollView setAutoresizingMask:kScrollViewAutoresizingMask];
    [self.scrollView setShowsVerticalScrollIndicator:NO];
    [self.scrollView setShowsHorizontalScrollIndicator:NO];
    [self.scrollView setPagingEnabled:YES];
    [self.scrollView setDelegate:self];
    [self.scrollView setContentSize:CGSizeMake(width + width, scrollHeight)];
    self.editPage = (int)[NSUserDefaults.standardUserDefaults integerForKey:kPrefEditSelectKey];
    if (self.editPage > 1) {
        self.editPage = 1;
    }
    [self.scrollView setContentOffset:CGPointMake((double)self.editPage * width, 0.0) animated:NO];
    [self addSubview:self.scrollView];

    // The card background and its gradient-layer border and stops.
    [self setBackgroundColor:[UIColor colorWithWhite:kCardBackgroundWhite
                                               alpha:kCardBackgroundAlpha]];
    CAGradientLayer *gradient = (CAGradientLayer *)self.layer;
    [gradient setBorderWidth:kCardBorderWidth];
    [gradient setBorderColor:UIColor.lightGrayColor.CGColor];
    id topColor = (id)[UIColor colorWithWhite:kGradientTopWhite alpha:kGradientAlpha].CGColor;
    id bottomColor = (id)[UIColor colorWithWhite:kGradientBottomWhite alpha:kGradientAlpha].CGColor;
    [gradient setColors:@[ topColor, bottomColor ]];

    // The full-card background image, pinned to the bottom of the card behind everything.
    UIImage *backgroundImage = LoadScaledPngImage(kDetailBackgroundImage);
    UIImageView *backgroundView = [[UIImageView alloc] initWithImage:backgroundImage];
    [backgroundView setFrame:CGRectMake(0.0,
                                        frame.size.height - backgroundImage.size.height,
                                        backgroundImage.size.width,
                                        backgroundImage.size.height)];
    [self insertSubview:backgroundView atIndex:0];

    // The square artwork and its reflection directly below it.
    double artworkInset = isPad ? kArtworkInsetPad : kArtworkInsetPhone;
    double artworkSize =
        isPad ? kArtworkSizePad : (isRetina ? kArtworkSizeRetina : kArtworkSizeNonRetina);
    [self.artworkView setFrame:CGRectMake(artworkInset, artworkInset, artworkSize, artworkSize)];
    float reflectionNudge = isRetina ? kReflectionNudgeRetina : kReflectionNudgeNonRetina;
    float reflectionFraction = isPad ? kReflectionFractionPadF : kReflectionFractionPhoneF;
    [self.reflectionArtworkView
        setFrame:CGRectMake(artworkInset,
                            (double)((float)(artworkInset + artworkSize) + reflectionNudge),
                            artworkSize,
                            (double)((float)artworkSize * reflectionFraction))];

    // The tune-name image to the right of the artwork.
    double artworkRight = artworkSize + artworkInset;
    double tuneNameGap =
        isPad ? kTuneNameGapPad : (isRetina ? kTuneNameGapRetina : kTuneNameGapNonRetina);
    double tuneNameWidth =
        isPad ? kTuneNameWidthPad : (isRetina ? kTuneNameWidthRetina : kTuneNameWidthNonRetina);
    double tuneNameHeight =
        isPad ? kTuneNameHeightPad : (isRetina ? kTuneNameHeightRetina : kTuneNameHeightNonRetina);
    [self.tuneNameView
        setFrame:CGRectMake(
                     artworkRight + tuneNameGap, artworkInset, tuneNameWidth, tuneNameHeight)];

    // The iTunes link keeps the tune-name box's size at its own per-idiom Y.
    [self.buttonLink frame];
    double linkGap = isPad ? kTuneNameGapPad : kTuneNameGapRetina;
    double linkY = isPad ? kButtonLinkYPad : kButtonLinkYPhone;
    [self.buttonLink
        setFrame:CGRectMake(artworkRight + linkGap, linkY, tuneNameWidth, tuneNameHeight)];

    // The social recommend buttons stack rightwards from the card's right edge, centred on the
    // link row; the Facebook button (gated on SLComposeViewController) takes the first slot.
    CGRect linkFrame = self.buttonLink.frame;
    int socialCenterY = (int)(linkY + tuneNameHeight * 0.5);
    int socialInset = isPad ? kSocialInsetPad : 0;
    BOOL hasFacebook = NO;
    if (NSClassFromString(@"SLComposeViewController") != nil) {
        [self.btnRecommendFacebook frame];
        [self.btnRecommendFacebook
            setFrame:CGRectMake((self.frame.size.width - linkFrame.size.width) -
                                    (double)socialInset,
                                (double)socialCenterY - linkFrame.size.height * 0.5,
                                linkFrame.size.width,
                                linkFrame.size.height)];
        [self.btnRecommendFacebook frame];
        socialInset = isPad ? kSocialGapPad : 0;
        hasFacebook = YES;
    }
    CGRect twitterFrame = self.btnRecommendTwitter.frame;
    double twitterRefWidth = hasFacebook ? linkFrame.size.width : twitterFrame.size.width;
    [self.btnRecommendTwitter
        setFrame:CGRectMake((self.frame.size.width - twitterRefWidth) - (double)socialInset,
                            (double)socialCenterY - twitterFrame.size.height * 0.5,
                            twitterFrame.size.width,
                            twitterFrame.size.height)];

    // The four difficulty buttons ride the scroll view at a shared centre Y.
    double diffEdge = isPad ? kDiffCenterEdgePad : kDiffCenterEdgePhone;
    double diffCenterY = isPad ? kDiffCenterYPad : kDiffCenterYPhone;
    CGPoint diffCenters[] = {CGPointMake(diffEdge, diffCenterY),
                             CGPointMake(width * 0.5, diffCenterY),
                             CGPointMake(width - diffEdge, diffCenterY),
                             CGPointMake(width + diffEdge, diffCenterY)};
    for (int i = 0; i < kExtendButtonIndex + 1; ++i) {
        MusicDetailViewKntBuildDifficultyButton(
            self, self->btnDiff, self->levelNumView, i, diffCenters[i]);
    }

    [self loadImages];
    double cardHeight = self.frame.size.height;
    int startXOffset = isPad ? kStartButtonXOffsetPad : kStartButtonXOffsetPhone;
    double stackGap = isPad ? kButtonStackGapPad : kButtonStackGapPhone;

    // The start-play and host-share buttons along the bottom of the card.
    UIImage *singleImage = [self getSingleImage];
    [self.buttonStartPlay
        setFrame:CGRectMake((double)((int)(self.frame.size.width - singleImage.size.width) / 2 -
                                     startXOffset),
                            cardHeight - (singleImage.size.height + stackGap),
                            singleImage.size.width,
                            singleImage.size.height)];
    [self.buttonStartPlay setBackgroundImage:singleImage forState:UIControlStateNormal];
    [self.buttonStartPlay addTarget:self
                             action:@selector(pushButtonStartPlay:)
                   forControlEvents:UIControlEventTouchUpInside];

    UIImage *hostImage = [[ImageCache sharedCache] getResPNG:kHostButtonImage];
    [self.buttonHostSharePlay
        setFrame:CGRectMake((double)(startXOffset +
                                     (int)(self.frame.size.width - hostImage.size.width) / 2),
                            cardHeight - (hostImage.size.height + stackGap),
                            hostImage.size.width,
                            hostImage.size.height)];
    [self.buttonHostSharePlay setBackgroundImage:hostImage forState:UIControlStateNormal];
    [self.buttonHostSharePlay addTarget:self
                                 action:@selector(pushButtonShare:)
                       forControlEvents:UIControlEventTouchUpInside];

    // The share-message label (black text) and the share-data progress bar, centred on the card.
    double shareX = (self.frame.size.width + kShareLabelWidthNegated) * 0.5;
    [self.labelShareMessage
        setFrame:CGRectMake(shareX,
                            self.frame.size.height -
                                (hostImage.size.height +
                                 (isPad ? kShareLabelGapPad : kShareLabelGapPhone)),
                            kShareLabelWidth,
                            (isPad ? kShareLabelHeightPad : kShareLabelHeightPhone))];
    [self.labelShareMessage
        setFont:[UIFont boldSystemFontOfSize:(isPad ? kShareLabelFontPad : kShareLabelFontPhone)]];
    [self.labelShareMessage setBackgroundColor:UIColor.clearColor];
    [self.labelShareMessage setTextColor:UIColor.blackColor];

    [self.shareDataProgress
        setFrame:CGRectMake(shareX,
                            self.frame.size.height -
                                (hostImage.size.height +
                                 (isPad ? kShareProgressGapPad : kShareProgressGapPhone)),
                            kShareLabelWidth,
                            (isPad ? kShareProgressHeightPad : kShareProgressHeightPhone))];
    [self.shareDataProgress setProgressViewStyle:UIProgressViewStyleBar];

    // The note bar and its 120 dot views.
    double barWidth =
        isPad ? kMusicBarWidthPad : (isRetina ? kMusicBarWidthRetina : kMusicBarWidthNonRetina);
    double barHeight = isPad ? kMusicBarHeightPad : kMusicBarHeightPhone;
    mbarBarView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0, 0.0, barWidth, barHeight)];
    [self addSubview:mbarBarView];
    [mbarBarView
        setCenter:CGPointMake(width * 0.5, isPad ? kMusicBarCenterYPad : kMusicBarCenterYPhone)];
    int dotX = kMusicBarDotStartPad;
    for (int i = 0; i < kMusicBarDotCount; ++i) {
        CGRect dotFrame;
        if (isPad) {
            dotFrame = CGRectMake((double)dotX, 0.0, 6.0, kMusicBarDotHeightPad);
        } else {
            int phoneX = i + (isRetina ? kMusicBarDotStartRetina : kMusicBarDotStartNonRetina);
            dotFrame = CGRectMake((double)phoneX, 0.0, 3.0, 18.0);
        }
        mbarDotView[i] = [[UIImageView alloc] initWithFrame:dotFrame];
        [mbarBarView addSubview:mbarDotView[i]];
        dotX += 4;
    }
    [self addSubview:mbarBarView];

    // The high-score board with seven right-justified digits, a rating, a combo, and a text
    // overlay.
    highscoreBoardView =
        [[UIImageView alloc] initWithImage:LoadScaledPngImage(kHighscoreBoardImage)];
    double boardX = isPad ? kHighscoreBoardXPad :
                            (isRetina ? kHighscoreBoardXRetina : kHighscoreBoardXNonRetina);
    double boardY = isPad ? kHighscoreBoardYPad : kHighscoreBoardYPhone;
    [highscoreBoardView setCenter:CGPointMake(boardX, boardY)];
    for (int i = 0; i < kHighscoreDigitCount; ++i) {
        CGRect digitFrame;
        if (isPad) {
            digitFrame = CGRectMake((double)(i * 33), 2.0, 32.0, 40.0);
        } else {
            float step = isRetina ? 20.5f : 22.0f;
            digitFrame =
                CGRectMake((double)((float)i * step + 1.0f), isRetina ? 1.0 : 2.0, 19.0, 24.0);
        }
        highscoreNumView[i] = [[UIImageView alloc] initWithFrame:digitFrame];
        [highscoreBoardView addSubview:highscoreNumView[i]];
    }

    // The rating image: pad at 236, retina at 145, non-retina at 154; square (pad 40 / phone 24).
    CGRect ratingFrame = isPad    ? CGRectMake(236.0, 0.0, 40.0, 40.0) :
                         isRetina ? CGRectMake(145.0, 1.0, 24.0, 24.0) :
                                    CGRectMake(154.0, 1.0, 24.0, 24.0);
    ratingView = [[UIImageView alloc] initWithFrame:ratingFrame];
    [highscoreBoardView addSubview:ratingView];

    // The combo image: pad (92, 38, 140, 16), retina (68, 22, 88, 11), non-retina (68, 22, 88, 11).
    CGRect comboFrame = isPad    ? CGRectMake(92.0, 38.0, 140.0, 16.0) :
                        isRetina ? CGRectMake(68.0, 22.0, 88.0, 11.0) :
                                   CGRectMake(68.0, 22.0, 88.0, 11.0);
    comboView = [[UIImageView alloc] initWithFrame:comboFrame];
    [highscoreBoardView addSubview:comboView];

    highscoreTextView = [[UIImageView alloc] initWithImage:LoadScaledPngImage(kHighscoreTextImage)];
    double textBaseX =
        isPad ? kHighscoreBaseXPad : (isRetina ? kHighscoreBaseXRetina : kHighscoreBaseXNonRetina);
    double textY = isPad ? kHighscoreCenterYPad : kHighscoreCenterYPhone;
    [highscoreTextView setCenter:CGPointMake(textBaseX + kHighscoreCenterXNudge, textY)];
    [highscoreBoardView addSubview:highscoreTextView];
    [self addSubview:highscoreBoardView];

    // The random marker, positioned relative to the rating image (keeping its own size).
    [self.randView frame];
    CGPoint randCenter = self.randView.center;
    CGSize randSize = self.randView.frame.size;
    double randX = ratingFrame.origin.x - randCenter.x - 3.0;
    double randY = (double)((int)(textY + ratingFrame.size.height * 0.5));
    [self.randView setFrame:CGRectMake(randX, randY, randSize.width, randSize.height)];

    // The two scroll arrows.
    [btnDiff[0] frame];
    double scrollBtnY = isPad ? kScrollArrowYPad : kScrollArrowYPhone;
    NSString *arrowNames[] = {kScrollArrowRight, kScrollArrowLeft};
    double edgeButtonHeight = btnDiff[0].frame.size.height;
    for (int i = 0; i < 2; ++i) {
        UIImage *arrow = LoadScaledPngImage(arrowNames[i]);
        detailScrollButton[i] = [UIButton buttonWithType:UIButtonTypeCustom];
        double arrowX =
            self.scrollView.frame.size.width - arrow.size.width + (double)i * arrow.size.width;
        [detailScrollButton[i]
            setFrame:CGRectMake(arrowX, scrollBtnY, arrow.size.width, edgeButtonHeight)];
        [detailScrollButton[i] setImage:arrow forState:UIControlStateNormal];
        [detailScrollButton[i] setExclusiveTouch:YES];
        [detailScrollButton[i] setAdjustsImageWhenHighlighted:YES];
        [detailScrollButton[i] setAdjustsImageWhenDisabled:YES];
        [detailScrollButton[i] addTarget:self
                                  action:@selector(scrollChange:)
                        forControlEvents:UIControlEventTouchUpInside];
        [self.scrollView addSubview:detailScrollButton[i]];
    }

    // The info-edit button on the edit page.
    double infoY =
        (double)(float)(scrollBtnY + (isPad ? kInfoButtonDropPad : kInfoButtonDropPhone));
    int infoWidth = isPad ? 26 : 13;
    UIImage *infoImage = LoadScaledPngImage(kEditInfoTextImage);
    infoBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [infoBtn setFrame:CGRectMake(0.0, infoY, (double)infoWidth, infoImage.size.height)];
    [infoBtn setBackgroundColor:UIColor.clearColor];
    [infoBtn setImage:infoImage forState:UIControlStateNormal];
    [infoBtn setExclusiveTouch:YES];
    if (!isPad) {
        [infoBtn setAdjustsImageWhenHighlighted:NO];
        [infoBtn setAdjustsImageWhenDisabled:NO];
    }
    [self.scrollView addSubview:infoBtn];
    [infoBtn addTarget:self
                  action:@selector(pushInfoEdit:)
        forControlEvents:UIControlEventTouchUpInside];

    // The three edit-info text fields stack down the edit page (the comment field, index 2, is the
    // tall multi-line one). Their width is 95% of the text image, rounded to an even pixel, and
    // centred under it.
    int fontSize = isPad ? 16 : 11;
    int fieldStep = isPad ? 6 : 5;
    int fieldHeight = (isPad ? 4 : 1) + fontSize;
    int firstFieldY = infoWidth + 4;
    int fieldWidth = (int)(infoImage.size.width * kEditFieldWidthFraction);
    fieldWidth -= (fieldWidth % 2 == 1) ? 1 : 0;
    double fieldX = (double)(int)((double)(float)infoY +
                                  (infoImage.size.width - (double)fieldWidth) * 0.5 + 2.0);
    int fieldY = firstFieldY;
    for (int i = 0; i < kEditTextFieldCount; ++i) {
        editTxt[i] = [[UILabel alloc]
            initWithFrame:CGRectMake(
                              fieldX, (double)fieldY, (double)fieldWidth, (double)fieldHeight)];
        [editTxt[i] setFont:[UIFont systemFontOfSize:(double)fontSize]];
        [editTxt[i] setText:@""];
        if (i == kEditCommentIndex) {
            int lines = self.isPad ? 3 : 2;
            [editTxt[i] setFrame:CGRectMake(fieldX,
                                            (double)fieldY,
                                            (double)fieldWidth,
                                            (double)(lines * (fieldHeight + 1)))];
            [editTxt[i] setNumberOfLines:lines];
            [editTxt[i] setLineBreakMode:NSLineBreakByWordWrapping];
        }
        [editTxt[i] setBackgroundColor:UIColor.clearColor];
        [self.scrollView addSubview:editTxt[i]];
        fieldY += fieldHeight + fieldStep;
    }

    // The pad-only upload and edit buttons follow the text fields, right-aligned to the scroll
    // content.
    if (self.isPad) {
        UIImage *uploadImage = LoadScaledPngImage(kUploadButtonImage);
        double buttonX = self.scrollView.contentSize.width + kMusicBarCenterYPad * -1.0 + 172.0;
        double buttonY = (double)(firstFieldY);
        uploadBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [uploadBtn setImage:uploadImage forState:UIControlStateNormal];
        [uploadBtn setFrame:CGRectMake((double)(int)buttonX,
                                       buttonY,
                                       uploadImage.size.width,
                                       uploadImage.size.height)];
        [uploadBtn setExclusiveTouch:YES];
        [self.scrollView addSubview:uploadBtn];
        [uploadBtn addTarget:self
                      action:@selector(pushButtonUpload:)
            forControlEvents:UIControlEventTouchUpInside];

        UIImage *editImage = LoadScaledPngImage(kEditButtonImage);
        editBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [editBtn setImage:editImage forState:UIControlStateNormal];
        [editBtn setFrame:CGRectMake((double)(int)buttonX,
                                     (double)(int)(buttonY + uploadImage.size.height + 8.0),
                                     editImage.size.width,
                                     editImage.size.height)];
        [editBtn setExclusiveTouch:YES];
        [self.scrollView addSubview:editBtn];
        [editBtn addTarget:self
                      action:@selector(pushButtonEdit:)
            forControlEvents:UIControlEventTouchUpInside];
    }

    // Apply the remembered difficulty (snapping a stale extreme back to basic) and enable the
    // difficulty buttons.
    userTagIcon = nil;
    int difficulty = (int)[NSUserDefaults.standardUserDefaults integerForKey:kPrefDifficultyKey];
    if ((unsigned int)difficulty > 2) {
        [NSUserDefaults.standardUserDefaults setInteger:0 forKey:kPrefDifficultyKey];
        difficulty = 0;
    }
    [btnDiff[0] setEnabled:YES];
    [btnDiff[1] setEnabled:YES];
    [btnDiff[2] setEnabled:YES];
    [self changeDifficulty:difficulty];

    // The two pending-download lamps; both start hidden.
    UIImage *scrollLampImage = LoadScaledPngImage(kScrollLampImage);
    scrollLamp = [[UIImageView alloc] initWithImage:scrollLampImage];
    [scrollLamp setFrame:CGRectMake(0.0, 0.0, scrollLampImage.size.width, (double)fieldHeight)];
    double lampCenterY = (double)((int)scrollHeight >> 1);
    [scrollLamp setCenter:CGPointMake(scrollLampImage.size.width * 0.5, lampCenterY)];
    [detailScrollButton[0] addSubview:scrollLamp];
    [scrollLamp setHidden:YES];

    UIImage *diffLampImage = LoadScaledPngImage(kDiffButtonLampImage);
    diffBtnLamp = [[UIImageView alloc] initWithImage:diffLampImage];
    [diffBtnLamp setFrame:CGRectMake(0.0,
                                     0.0,
                                     btnDiff[kExtendButtonIndex].frame.size.width,
                                     btnDiff[kExtendButtonIndex].frame.size.height)];
    [btnDiff[kExtendButtonIndex] addSubview:diffBtnLamp];
    [diffBtnLamp setAlpha:kDiffButtonDimAlpha];
    [diffBtnLamp setHidden:YES];
    if ([NSUserDefaults.standardUserDefaults integerForKey:kPrefJcfDownloadSelectKey] ==
        kJcfDownloadSelectPending) {
        [scrollLamp setHidden:NO];
        [diffBtnLamp setHidden:NO];
    }

    // The hold marks and the extend/extend-on marks over each difficulty button.
    double markInset = isPad ? kMarkInsetPad : kMarkInsetPhone;
    for (int i = 0; i < kDiffButtonCount; ++i) {
        UIImage *holdImage =
            LoadScaledPngImage([NSString stringWithFormat:kHoldMarkFormat, kDiffButtonLetters[i]]);
        holdMark[i] = [[UIImageView alloc] initWithImage:holdImage];
        double markX =
            btnDiff[i].frame.origin.x + holdImage.size.width + kHostGapNegative - markInset;
        [holdMark[i]
            setFrame:CGRectMake(markX - 4.0, kMarkTopPad, holdImage.size.width, kMarkHeightPad)];
        [holdMark[i] setHidden:YES];
        [btnDiff[i] addSubview:holdMark[i]];
    }
    for (int i = 0; i < kDiffButtonCount; ++i) {
        UIImage *extendImage = LoadScaledPngImage(
            [NSString stringWithFormat:kExtendMarkFormat, kDiffButtonLetters[i]]);
        double extendX =
            (double)(int)(btnDiff[i].frame.origin.x + extendImage.size.width - 20.0 - markInset);
        extendMark[i] = [[UIImageView alloc] initWithImage:extendImage];
        [extendMark[i]
            setFrame:CGRectMake(extendX, kMarkTopPad, extendImage.size.width, kMarkHeightPad)];
        [extendMark[i] setHidden:YES];
        [btnDiff[i] addSubview:extendMark[i]];

        UIImage *extendOnImage = LoadScaledPngImage(
            [NSString stringWithFormat:kExtendOnMarkFormat, kDiffButtonLetters[i]]);
        extendOnMark[i] = [[UIImageView alloc] initWithImage:extendOnImage];
        [extendOnMark[i]
            setFrame:CGRectMake(extendX, kMarkTopPad, extendOnImage.size.width, kMarkHeightPad)];
        [extendOnMark[i] setHidden:YES];
        [btnDiff[i] addSubview:extendOnMark[i]];
    }
    [self addSubview:self.coverView];

    return self;
}

/** @ghidraAddress 0x1999dc */
- (void)setInfo:(TuneInfo *)info score:(id)score {
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
    [levelNumView[0] setImage:levelNumImg[(int)self.levelBas]];
    [levelNumView[1] setImage:levelNumImg[(int)self.levelAdv]];
    [levelNumView[2] setImage:levelNumImg[(int)self.levelExt]];
    [levelNumView[kExtendLevelNumIndex] setImage:levelNumImg[(int)self.levelExt]];
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
- (void)setExtendInfo:(TuneInfo *)info score:(id)score {
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
                     completion:^(BOOL __attribute__((unused)) finished){
                         /** @ghidraAddress 0x1a1050 */
                     }];
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
        completion:^(BOOL __attribute__((unused)) finished) {
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
                     completion:^(BOOL __attribute__((unused)) finished){
                         /** @ghidraAddress 0x19fefc */
                     }];
    [self.controller unenableCoverTap];
}

/** @ghidraAddress 0x198628 */
- (UIButton *)diffButton:(NSString *)imageName {
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
- (void)loadContentFromDictionary:(NSDictionary *)dict {
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
        completion:^(BOOL __attribute__((unused)) finished) {
          /** @ghidraAddress 0x1a03bc */
          [weakSelf.controller startEdit:weakSelf.info];
        }];

    // Input is ignored through the transition and re-enabled a beat after it ends.
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    [[UIApplication sharedApplication] performSelector:@selector(endIgnoringInteractionEvents)
                                            withObject:nil
                                            afterDelay:kEditInputLockDuration];
}

/** @ghidraAddress 0x19d8d4 */
- (void)show:(BOOL)show {
    self.isShared = show;
    int difficulty = (int)[NSUserDefaults.standardUserDefaults integerForKey:kPrefDifficultyKey];
    MusicDetailViewKntSetDifficultyButtons(self->btnDiff, difficulty);
    [self.controller resetWillStart];

    // The start button and share prompt differ between the solo and host-share presentations.
    UIImage *startImage;
    UIImage *hostImage;
    if (!show) {
        startImage = [self getSingleImage];
        hostImage = [[ImageCache sharedCache] getResPNG:kHostButtonImage];
        [self.labelShareMessage setHidden:YES];
        [self.shareDataProgress setHidden:YES];
    } else {
        startImage = [self getStartImage];
        hostImage = [[ImageCache sharedCache] getResPNG:kCancelButtonImage];
        [self.labelShareMessage setText:@""];
        [self.labelShareMessage setAlpha:1.0];
        [self.labelShareMessage setHidden:NO];
        [self.buttonLink setHidden:YES];
        [self.btnRecommendTwitter setHidden:YES];
        [self.btnRecommendFacebook setHidden:YES];
        self.isSharedStartable = YES;
    }
    [self.buttonStartPlay setBackgroundImage:startImage forState:UIControlStateNormal];
    [self.buttonHostSharePlay setBackgroundImage:hostImage forState:UIControlStateNormal];
    [self setStartButtonEnable];
    self.isStarted = NO;

    // Restore the difficulty scroll to the remembered edit page (clamped to the detail/edit pair).
    self.editPage = (int)[NSUserDefaults.standardUserDefaults integerForKey:kPrefEditSelectKey];
    if (self.editPage > 1) {
        self.editPage = 1;
    }
    double width = self.scrollView.frame.size.width;
    [self.scrollView setContentOffset:CGPointMake(width * (double)self.editPage, 0.0) animated:NO];
    [self.scrollView setScrollEnabled:YES];
    [detailScrollButton[0] setAlpha:1.0];
    detailScrollButton[0].layer.transform = CATransform3DMakeScale(1.0, 1.0, 1.0);
    [detailScrollButton[1] setAlpha:1.0];
    detailScrollButton[1].layer.transform = CATransform3DMakeScale(1.0, 1.0, 1.0);

    // A pending download selection pulses the scroll and difficulty-button lamps.
    if ([[NSUserDefaults.standardUserDefaults objectForKey:kPrefJcfDownloadSelectKey] intValue] ==
        kJcfDownloadSelectPending) {
        __weak UIView *weakScrollLamp = scrollLamp;
        __weak UIView *weakDiffLamp = diffBtnLamp;
        [UIView animateWithDuration:kLampPulseDuration
                              delay:kLampPulseDelay
                            options:UIViewAnimationOptionRepeat
                         animations:^{
                           /** @ghidraAddress 0x19e28c */
                           [weakScrollLamp setAlpha:0.0];
                           [weakScrollLamp
                               setTransform:CGAffineTransformMakeScale(1.0, kLampPulseHeightScale)];
                         }
                         completion:nil];
        [UIView animateWithDuration:kLampPulseDuration
                              delay:kLampPulseDelay
                            options:UIViewAnimationOptionRepeat | UIViewAnimationOptionAutoreverse
                         animations:^{
                           /** @ghidraAddress 0x19e338 */
                           [weakDiffLamp setAlpha:0.0];
                           [weakDiffLamp
                               setTransform:CGAffineTransformMakeScale(1.0, kLampPulseHeightScale)];
                         }
                         completion:nil];
    }
    [self infoChange:difficulty];
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
            completion:^(BOOL __attribute__((unused)) finished) {
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
- (void)uploadEnd:(id)sender {
    __weak UIView *weakCover = topcover;
    __weak JcfUpLoadView *weakUpload = upLoadView;
    // The binary passes a negative fade duration here; kept as-is.
    [UIView animateWithDuration:kUploadEndFadeDuration
        animations:^{
          /** @ghidraAddress 0x1a3834 */
          [weakUpload setAlpha:0.0];
          [weakCover setAlpha:0.0];
        }
        completion:^(BOOL __attribute__((unused)) finished) {
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
- (void)pushButtonUpload:(id)sender {
    if ([self checkEnableUpload]) {
        [self uploadStart];
    }
}

/** @ghidraAddress 0x19ff44 */
- (void)pushButtonEdit:(id)sender {
    [self editStart];
}

/** @ghidraAddress 0x19ff50 */
- (void)editFileListViewSelectEdit {
    [[AudioManager sharedManager] playSeResFile:kEditSelectSound inDirectory:nil];
    [self.controller dismissViewControllerAnimated:YES completion:nil];
    [self editStart];
}

/** @ghidraAddress 0x1a1054 */
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
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
- (void)selectEditFile:(id)fileName {
    [[EditDataManager sharedManager] setLastEditFileName:(int)self.info.tuneID fileName:fileName];
    [self.controller enableCoverTap];
}

/** @ghidraAddress 0x1a2f0c */
- (void)popoverPresentationControllerDidDismissPopover:
    (UIPopoverPresentationController *)popoverPresentationController {
    [self loadListRelease];
    [self.controller enableCoverTap];
}

/** @ghidraAddress 0x1a2f60 */
- (void)editFileListViewCancel:(id)sender {
    [self.controller enableCoverTap];
    [self.controller dismissViewControllerAnimated:YES completion:nil];
}

/** @ghidraAddress 0x1a2fe4 */
- (void)errorSequenceDownload:(id)sender {
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
- (void)finishedSequenceDownload:(id)sender {
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
- (void)finishedSequenceOverCap:(id)sender {
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
- (void)selectUpdate:(id)sender {
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
- (void)editFileListViewDeleteFile:(id)fileName {
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
- (void)setMusicBarDot:(char *)dots mbarRes:(char *)mbarRes {
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
- (void)pushInfoEdit:(id)sender {
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
- (void)customWebViewClose:(id)webView seqIndex:(id)seqIndex {
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
- (void)loadExtendMusicBar:(NSString *)path {
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
    // The selected base button and the extend button are full; the other two base buttons dim and
    // shrink.
    MusicDetailViewKntSetDifficultyButtons(self->btnDiff, difficulty);
    [self infoChange:difficulty];
}

/** @ghidraAddress 0x1a1058 */
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    float offsetX = (float)scrollView.contentOffset.x;
    float half = (float)(scrollView.contentSize.width * 0.5);
    float denom = half * kScrollFadeSpanFraction;
    float leftFade = MIN(offsetX / denom, 1.0f);
    [detailScrollButton[0] setAlpha:(double)(1.0f - leftFade)];
    float rightFade = MIN((half - offsetX) / denom, 1.0f);
    [detailScrollButton[1] setAlpha:(double)(1.0f - rightFade)];
}

/** @ghidraAddress 0x1a1134 */
- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    [detailScrollButton[0] setAlpha:1.0];
    [detailScrollButton[1] setAlpha:1.0];
    MusicDetailViewKntSettleScrollPage(self, self->holdMark);
}

/** @ghidraAddress 0x1a1434 */
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    MusicDetailViewKntSettleScrollPage(self, self->holdMark);
}

/** @ghidraAddress 0x1a16f8 */
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (!decelerate) {
        MusicDetailViewKntSettleScrollPage(self, self->holdMark);
    }
}

/** @ghidraAddress 0x1a19c8 */
- (void)editModalViewClose:(id)sender {
    [[AudioManager sharedManager] playSeResFile:kMusicLeftSound inDirectory:nil];
    NSMutableDictionary *editorInfo = [[EditDataManager sharedManager] getEditorInfo];
    [editTxt[0] setText:editorInfo[@"fumenName"]];
    [editTxt[1] setText:editorInfo[@"editorName"]];
    [editTxt[2] setText:editorInfo[@"comment"]];
    int level = [editorInfo[@"level"] intValue];
    [levelNumView[kExtendLevelNumIndex] setImage:levelNumImg[(int)level]];
    [levelNumView[kExtendLevelNumIndex] setAlpha:1.0];
    [self.controller dismissViewControllerAnimated:YES completion:nil];
    [self.controller enableCoverTap];
}

/** @ghidraAddress 0x1a046c */
- (void)pushButtonShare:(id)sender {
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
                completion:^(BOOL __attribute__((unused)) finished) {
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
- (void)pushButtonStartPlay:(id)sender {
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
          MusicDetailViewKntDimUnselectedButtons(self->btnDiff, difficulty);
        }
        completion:^(BOOL __attribute__((unused)) finished) {
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

/** @ghidraAddress 0x199e88 */
- (void)infoChange:(int)difficulty {
    // Whether the shown difficulty is displaying its extend chart.
    BOOL showExtend = JubeatAppDelegate.appDelegate.isExtend && self.extendInfo != nil &&
                      (self.extendInfo.extendFlag & (1 << difficulty)) != 0;

    char resource[32] = {0};
    if (self.editPage == 0) {
        // Pick the score, full-combo flag, and music bar for the shown difficulty and chart.
        int score = -1;
        BOOL fullcombo = NO;
        NSData *mbar = nil;
        switch (difficulty) {
        case 0:
            score = showExtend ? self.extendScoreBas : self.scoreBas;
            fullcombo = showExtend ? self.extendFullComboBas : self.fullComboBas;
            mbar = showExtend ? self.extendMbarBas : self.mbarBas;
            break;
        case 1:
            score = showExtend ? self.extendScoreAdv : self.scoreAdv;
            fullcombo = showExtend ? self.extendFullComboAdv : self.fullComboAdv;
            mbar = showExtend ? self.extendMbarAdv : self.mbarAdv;
            break;
        case 2:
            score = showExtend ? self.extendScoreExt : self.scoreExt;
            fullcombo = showExtend ? self.extendFullComboExt : self.fullComboExt;
            mbar = showExtend ? self.extendMbarExt : self.mbarExt;
            break;
        default:
            break;
        }
        if (mbar.length >= kMbarMinimumLength) {
            [mbar getBytes:resource length:kMbarMinimumLength];
        }
        [self setScoreBoard:score fullcombo:fullcombo];

        // Fill the 120 dot views from the difficulty's dot map (base or extend) and the resource.
        [mbarBarView setImage:mbarBarImg[difficulty]];
        char *dotMap = showExtend ? extendMbarDots[difficulty] : mbarDots[difficulty];
        for (int i = 0; i < kMusicBarDotCount; ++i) {
            int sprite = ((dotMap[i >> 1] >> ((i & 1) * 4)) & 0xf) - 1;
            UIImage *image = nil;
            if ((unsigned int)sprite < kMusicBarDotSpriteCount) {
                int row = (resource[i >> 2] >> ((i & 3) * 2)) & 3;
                image = mbarDotImg[row][sprite];
            }
            [mbarDotView[i] setImage:image];
        }
    }

    // Reveal the hold marks for the difficulties that carry a hold chart in the shown mode.
    for (int i = 0; i < kDiffButtonCount; ++i) {
        BOOL isExtend = JubeatAppDelegate.appDelegate.isExtend;
        TuneInfo *source = self.info;
        if (isExtend && (self.extendInfo.extendFlag & (1 << i)) != 0) {
            source = self.extendInfo;
        }
        if ((source.holdFlag & (1 << i)) != 0) {
            [holdMark[i] setHidden:NO];
        }
    }

    // Update each difficulty's level image from the base or extend level, per chart shown.
    char levels[] = {self.levelBas, self.levelAdv, self.levelExt};
    char extendLevels[] = {self.extendLevelBas, self.extendLevelAdv, self.extendLevelExt};
    for (int i = 0; i < kDiffButtonCount; ++i) {
        BOOL isExtend = JubeatAppDelegate.appDelegate.isExtend;
        char level = levels[i];
        if (isExtend && (self.extendInfo.extendFlag & (1 << i)) != 0) {
            level = extendLevels[i];
        }
        [levelNumView[i] setImage:levelNumImg[(int)level]];
    }

    // The current difficulty's hold mark drives the app hold flag (except on the edit page).
    BOOL holdHidden = holdMark[difficulty].isHidden;
    [JubeatAppDelegate.appDelegate setHoldFlag:(self.editPage != 1) && !holdHidden];
    [self refreshStartButton];
}

/** @ghidraAddress 0x19b4bc */
- (void)selectDiff:(id)sender {
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
    } else if (btnDiff[kExtendButtonIndex] == sender) {
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

    __weak MusicDetailViewKnt *weakSelf = self;
    if (current == tapped) {
        // Re-tapping the current difficulty toggles the extend chart when the tune has one.
        NSTimeInterval inputLock = kSelectDiffInputLock;
        if (self.info.extendID != 0 && self.extendInfo != nil &&
            (self.extendInfo.extendFlag & (1 << current)) != 0) {
            [JubeatAppDelegate.appDelegate setExtendFlag:!JubeatAppDelegate.appDelegate.isExtend];
            [[AudioManager sharedManager] playSeResFile:kMusicRightSound inDirectory:nil];
            [self changeExtend:current];
            MusicDetailViewKntRepositionHighscore(self, self->highscoreTextView);
            [highscoreBoardView setAlpha:0.0];
            [NSUserDefaults.standardUserDefaults setInteger:current forKey:kPrefDifficultyKey];
            UIImageView *textView = highscoreTextView;
            UIImageView *boardView = highscoreBoardView;
            [UIView animateWithDuration:kExtendModeAnimDuration
                             animations:^{
                               /** @ghidraAddress 0x19bd14 */
                               [weakSelf changeDifficulty:current];
                               MusicDetailViewKntRepositionHighscore(weakSelf, textView);
                               [boardView setAlpha:1.0];
                             }];
            inputLock = kSelectDiffExtendInputLock;
        }
        [[UIApplication sharedApplication] performSelector:@selector(endIgnoringInteractionEvents)
                                                withObject:nil
                                                afterDelay:inputLock];
        return;
    }

    // A different difficulty: reposition the board, play the voice cue, persist the choice, and
    // slide the high-score panel into place.
    MusicDetailViewKntRepositionHighscore(self, self->highscoreTextView);
    [highscoreBoardView setAlpha:0.0];
    [[AudioManager sharedManager] playSeResFile:voiceCue inDirectory:nil];
    [NSUserDefaults.standardUserDefaults setInteger:tapped forKey:kPrefDifficultyKey];
    UIImageView *textView = highscoreTextView;
    UIImageView *boardView = highscoreBoardView;
    [UIView animateWithDuration:kExtendModeAnimDuration
                     animations:^{
                       /** @ghidraAddress 0x19bc50 */
                       [weakSelf changeDifficulty:tapped];
                       MusicDetailViewKntRepositionHighscore(weakSelf, textView);
                       [boardView setAlpha:1.0];
                     }];
    [[UIApplication sharedApplication] performSelector:@selector(endIgnoringInteractionEvents)
                                            withObject:nil
                                            afterDelay:kSelectDiffInputLock];
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
                MusicDetailViewKntSeedExtendRow(
                    self->extendMark, self->extendOnMark, self->holdMark, i, isExtend);
                if (isExtend) {
                    mix = 1.0f;
                }
            }
            [levelNumView[i] setAlpha:0.0];
        }

        UIImageView *const *levelNums = levelNumView;
        UIImageView *const *extendMarks = extendMark;
        UIImageView *const *extendOnMarks = extendOnMark;
        UIImageView *const *holdMarks = holdMark;
        [UIView animateWithDuration:kExtendCrossFadeDuration
                         animations:^{
                           /** @ghidraAddress 0x19b22c */
                           for (int i = 0; i < kDiffButtonCount; ++i) {
                               [levelNums[i] setAlpha:1.0];
                               [extendMarks[i] setAlpha:(1.0f - mix)];
                               [extendOnMarks[i] setAlpha:mix];
                               [holdMarks[i] setAlpha:1.0];
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

/** @ghidraAddress 0x19cc38 */
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
                           /** @ghidraAddress 0x19d3f4 */
                           [weakInfo setAlpha:1.0];
                           [weakUpload setAlpha:1.0];
                           [weakEdit setAlpha:1.0];
                         }
                         completion:^(BOOL __attribute__((unused)) finished){
                             /** @ghidraAddress 0x19d3f0 */
                         }];
        return;
    }

    // An edit is loaded: show the fields fully, load its JCF, fill the fields from the editor info,
    // set the extend level image, and toggle the info button's tap feedback on the download flag.
    self.isFirstSelect = NO;
    [self setStartButtonEnable];
    [editTxt[0] setAlpha:1.0];
    [editTxt[1] setAlpha:1.0];
    [editTxt[2] setAlpha:1.0];
    [manager loadJCF:[manager getLastEditFilePath:(int)self.info.tuneID]];
    NSMutableDictionary *editorInfo = [manager getEditorInfo];
    int dlFlag = [editorInfo[@"dlFlag"] intValue];
    [UIView animateWithDuration:kResetTextFadeDuration
                     animations:^{
                       /** @ghidraAddress 0x19d2ec */
                       [weakInfo setAlpha:1.0];
                       [weakUpload setAlpha:1.0];
                       [weakEdit setAlpha:1.0];
                     }
                     completion:^(BOOL __attribute__((unused)) finished){
                         /** @ghidraAddress 0x19d4f4 */
                     }];
    [editTxt[0] setText:editorInfo[@"fumenName"]];
    [editTxt[1] setText:editorInfo[@"editorName"]];
    [editTxt[2] setText:editorInfo[@"comment"]];
    int level = [editorInfo[@"level"] intValue];
    [levelNumView[kExtendLevelNumIndex] setImage:levelNumImg[(int)level]];
    [levelNumView[kExtendLevelNumIndex] setAlpha:1.0];
    if (dlFlag == kEditDownloadFlag) {
        [infoBtn setAdjustsImageWhenHighlighted:NO];
        [infoBtn setAdjustsImageWhenDisabled:NO];
    } else {
        [infoBtn setAdjustsImageWhenHighlighted:YES];
        [infoBtn setAdjustsImageWhenDisabled:YES];
    }
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
- (void)loadContentFromPath:(NSString *)path orData:(NSData *)data {
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
- (void)scrollChange:(id)sender {
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
- (void)downloadEnd:(id)sender {
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
- (id)getStartImage {
    if (![JubeatAppDelegate.appDelegate isRandom]) {
        return [[ImageCache sharedCache] getResPNG:kStartButtonImage];
    }
    if ([JubeatAppDelegate.appDelegate isHold]) {
        return [[ImageCache sharedCache] getResPNG:kStartButtonImage];
    }
    return [[ImageCache sharedCache] getResPNG:kRandomButtonImage];
}

/** @ghidraAddress 0x1a3a54 */
- (id)getSingleImage {
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
