#import "MusicDetailViewOrg.h"

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

static const double g_dAnimDuration020 = 0.2; // @ghidraAddress 0x28f240

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
static const int kDiffButtonCount = 3;

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

// A music bar carries at least 30 bytes of resource map for the 120 dots.
static const NSUInteger kMbarMinimumLength = 30;

// A pending download selection pulses the scroll and difficulty-button lamps: alpha to zero and a
// vertical stretch, repeating over this duration after this delay.
static const NSTimeInterval kLampPulseDuration = 0.5; // fmov, 0.5
static const NSTimeInterval kLampPulseDelay = 0.5;    // fmov, 0.5
static const CGFloat kLampPulseHeightScale = 2.0;     // fmov, 2.0
static const NSInteger kJcfDownloadSelectPending = 1;

// The four difficulty buttons (three selectable plus the extend slot). An unselected difficulty
// dims to this alpha; its level glyphs come from the "off" table row/word (index 3).
enum {
    kDiffButtonSlotCount = 4,
    kLevelOffRow = 3,
    kLevelOffWordIndex = 3,
};
static const CGFloat kDiffButtonUnselectedAlpha = 0.6; // @ghidraAddress 0x28f230

// Starting play shrinks the unselected buttons over this duration and locks input for a beat; a
// client waiting for the host shows this prompt. The selected difficulty's light views pulse with a
// fast opacity blink (1.0 -> 0.1 and back, 20 repeats, 0.08s each) under this key.
static NSString *const kWaitingForHostKey = @"Waiting for host to start";
static const NSTimeInterval kStartPlayTransitionDuration = 0.6; // @ghidraAddress 0x28f288
static const NSTimeInterval kStartPlayInputLockDuration = 0.7;  // @ghidraAddress 0x28f2a0
static const CGFloat kStartPlayShrinkScale = 0.1;               // @ghidraAddress 0x28f2b8
static NSString *const kBlinkFastAnimationKey = @"AnimBlinkFast";
static const CFTimeInterval kLightBlinkDuration = 0.08; // @ghidraAddress 0x28f700
static const float kLightBlinkFromOpacity = 1.0f;       // fmov, 1.0
static const float kLightBlinkToOpacity = 0.1f;         // @ghidraAddress 0x28f70c
static const float kLightBlinkRepeatCount = 20.0f;      // fmov, 20.0

// Scales out and fades every difficulty button except the selected one, plus both scroll buttons,
// when starting play.
static inline void MusicDetailViewOrgShrinkUnselectedButtons(UIButton *const *btnDiff,
                                                             UIButton *const *detailScrollButton,
                                                             int selected) {
    CATransform3D shrink =
        CATransform3DMakeScale(kStartPlayShrinkScale, kStartPlayShrinkScale, 1.0);
    for (int i = 0; i < kDiffButtonCount; ++i) {
        if (i != selected) {
            [btnDiff[i] setAlpha:0.0];
            btnDiff[i].layer.transform = shrink;
        }
    }
    [detailScrollButton[0] setAlpha:0.0];
    detailScrollButton[0].layer.transform = shrink;
    [detailScrollButton[1] setAlpha:0.0];
    detailScrollButton[1].layer.transform = shrink;
}

// The per-difficulty voice cues, the input-lock durations, and the high-score board's dimmed alpha
// while a difficulty change slides it in.
static NSString *const kDifficultyVoiceCues[] = {
    @"SD_CV_BASIC", @"SD_CV_ADVANCED", @"SD_CV_EXTREME"};
static const NSTimeInterval kSelectDiffInputLock = 0.4;       // @ghidraAddress 0x28f268
static const NSTimeInterval kSelectDiffExtendInputLock = 0.4; // @ghidraAddress 0x28f2c0
static const CGFloat kHighscoreBoardDimAlpha = 0.3;           // @ghidraAddress 0x28f248

// Repositions the high-score board view to its idiom home centre.
static inline void MusicDetailViewOrgRepositionHighscoreBoard(MusicDetailViewOrg *self,
                                                              UIImageView *highscoreBoardView) {
    double homeX = self.isPad ?
                       kHighscoreBoardXPad :
                       (self.isRetina ? kHighscoreBoardXRetina : kHighscoreBoardXNonRetina);
    double y = self.isPad ? kHighscoreBoardYPad : kHighscoreBoardYPhone;
    [highscoreBoardView setCenter:CGPointMake(homeX, y)];
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
static inline void MusicDetailViewOrgSettleScrollPage(MusicDetailViewOrg *self,
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
static const int kEditMbarBackgroundImage = 3;
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

// The layout constants used only while building the card in -initWithFrame:. The classic theme
// lays everything out three ways: pad, retina phone, and non-retina phone.

// The scroll view spans the lower band of the card: its top is (pad 400 / phone 200) minus its own
// height (pad 100 / phone 50), and it holds two full-width pages.
static const double kScrollViewTopBasePad = 400.0;         // @ghidraAddress 0x28f2e0
static const double kScrollViewTopBasePhone = 200.0;       // fmov, 200
static const double kScrollViewTopInsetPad = 100.0;        // @ghidraAddress 0x28f3f0
static const double kScrollViewTopInsetPhone = 50.0;       // fmov, 50
static const double kScrollViewContentHeightPad = 200.0;   // @ghidraAddress 0x28f400
static const double kScrollViewContentHeightPhone = 100.0; // @ghidraAddress 0x28f3f0
static const NSInteger kScrollViewAutoresizingMask = 18;

// The card's background and its gradient-layer border and stops.
static const CGFloat kCardBackgroundWhite = 0.1; // @ghidraAddress 0x28f2b8
static const CGFloat kCardBackgroundAlpha = 0.9; // @ghidraAddress 0x28f448
static const CGFloat kCardBorderWidth = 2.0;     // fmov, 2.0
static const CGFloat kGradientTopWhite = 0.3;    // @ghidraAddress 0x28f248
static const CGFloat kGradientBottomWhite = 0.0;
static const CGFloat kGradientAlpha = 0.9; // @ghidraAddress 0x28f448

// The artwork and its reflection. The square artwork is (pad 200 / retina 110 / non-retina 95) on a
// side, inset (pad 10 / phone 8) from the corner; the reflection sits directly below it (nudged by
// retina 0.5 / non-retina 1.0) and is a fraction (pad 0.3 / phone 0.2) as tall.
static const double kArtworkSizePad = 200.0;      // fmov, 200
static const double kArtworkSizeRetina = 110.0;   // 0x6e
static const double kArtworkSizeNonRetina = 95.0; // 0x5f
static const double kArtworkInsetPad = 10.0;      // fmov, 10.0
static const double kArtworkInsetPhone = 8.0;     // fmov, 8.0
static const float kReflectionNudgeRetina = 0.5f; // fmov, 0.5
static const float kReflectionNudgeNonRetina = 1.0f;
static const float kReflectionFractionPadF = 0.3f;   // @ghidraAddress 0x28e0b0 (g_flComboFadeBase)
static const float kReflectionFractionPhoneF = 0.2f; // @ghidraAddress 0x28f3c8

// The tune-name image and the iTunes link sit to the right of the artwork. Their left edge is the
// artwork's right edge plus a small idiom gap; the name box is (pad 340x64 / retina 170x32 /
// non-retina 204x38) and the link box keeps its own size at a per-idiom Y.
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

// The social recommend buttons stack rightwards from the card's right edge, each vertically centred
// on the link row, with a per-idiom right/inter-button inset.
static const int kSocialInsetPad = 24;
static const int kSocialGapPad = 10;

// The four difficulty buttons ride the scroll view. Their centres are: the first at a fixed left
// edge (pad 110 / phone 60), the second at mid-page (width/2), the third near the right edge
// (width - (pad 110 / phone 60)), and the fourth (edit) one page over (width + (pad 110 / phone
// 60)); all at centre Y (pad 100 / phone 50).
static const double kDiffCenterEdgePad = 110.0;  // @ghidraAddress 0x28f5e8
static const double kDiffCenterEdgePhone = 60.0; // @ghidraAddress 0x28f258
static const double kDiffCenterYPad = 100.0;     // @ghidraAddress 0x28f3f0
static const double kDiffCenterYPhone = 50.0;    // @ghidraAddress 0x28f2c8

// The difficulty-text image over each button is square (pad 160 / retina 80 / non-retina 74).
static const double kDiffTextSizePad = 160.0;      // 0xa0
static const double kDiffTextSizeRetina = 80.0;    // 0x50
static const double kDiffTextSizeNonRetina = 74.0; // 0x4a

// The light-pair image beneath each button and the blink it plays. The classic theme blinks each
// selected difficulty's two lights forever between full and dim opacity over half a second.
static const CFTimeInterval kNormalBlinkDuration = 0.5; // fmov, 0.5
static const float kNormalBlinkFrom = 1.0f;             // fmov, 1.0
static const float kNormalBlinkTo = 0.2f;               // @ghidraAddress 0x28f3c8

// The start-play and host-share buttons sit below the artwork. Their X is the card centre minus a
// per-idiom offset (pad 120 / phone 75); their Y and height come from stacking below the artwork.
static const int kStartButtonXOffsetPad = 120;  // 0x78
static const int kStartButtonXOffsetPhone = 75; // 0x4b
// The share-message label and progress bar are 300 wide; the same 300 negated centres them on the
// host button. The label height and font, and the progress height, are per idiom.
static const double kShareLabelWidth = 300.0;         // @ghidraAddress 0x28f2d0
static const double kShareLabelWidthNegated = -300.0; // @ghidraAddress 0x28f3e8
static const double kShareLabelHeightPad = 20.0;      // 0x4034
static const double kShareLabelHeightPhone = 16.0;    // 0x4030
static const double kShareLabelGapPad = 54.0;         // @ghidraAddress 0x28f640
static const double kShareLabelGapPhone = 28.0;       // fmov, 28
static const double kShareLabelFontPad = 20.0;        // 0x4034
static const double kShareLabelFontPhone = 16.0;      // 0x4030
static const double kShareProgressGapPad = 60.0;      // @ghidraAddress 0x28f258
static const double kShareProgressGapPhone = 34.0;    // @ghidraAddress 0x28f648
static const double kShareProgressHeightPad = 12.0;   // 0x4028
static const double kShareProgressHeightPhone = 8.0;  // 0x4020

// The music bar: its own view (width pad 560 / phone 280, height pad 40 / phone 20) centred at
// (barWidth/2, pad 294 / phone 144), and 120 dot views spaced across it.
static const double kMusicBarWidthPad = 560.0;     // @ghidraAddress 0x28f650
static const double kMusicBarWidthPhone = 280.0;   // @ghidraAddress 0x28f658
static const double kMusicBarHeightPad = 40.0;     // @ghidraAddress 0x28f1f8
static const double kMusicBarHeightPhone = 20.0;   // fmov, 20
static const double kMusicBarCenterYPad = 294.0;   // @ghidraAddress 0x28f668
static const double kMusicBarCenterYPhone = 144.0; // @ghidraAddress 0x28f660
static const int kMusicBarDotStartPad = 40;
static const int kMusicBarDotStartPhone = 30;       // pad-off value 20 at 0x28f... handled inline
static const double kMusicBarDotYPad = 3.0;         // fmov, 3.0
static const double kMusicBarDotWidthPad = 6.0;     // fmov, 6.0
static const double kMusicBarDotHeightPad = 36.0;   // @ghidraAddress 0x28f530
static const double kMusicBarDotYPhone = 1.0;       // fmov, 1.0
static const double kMusicBarDotWidthPhone = 2.0;   // fmov, 2.0
static const double kMusicBarDotHeightPhone = 18.0; // fmov, 18

// The high-score board image and its centre (see kHighscoreBoardX*/Y*), then seven right-justified
// score digits, a rating image, and a combo image, each at per-idiom coordinates.
static NSString *const kHighscoreBoardImage = @"msc_hsboard";

// The four difficulty slots take their button/word/light PNG names from a one-letter suffix.
static const char kDiffButtonLetters[] = {'b', 'a', 'e', 'o'};
static NSString *const kDiffButtonNameFormat = @"msel_btn_%c";
static NSString *const kDiffTextNameFormat = @"msel_btn_str_%c";
static NSString *const kDiffLightNameFormat = @"msel_btn_light_%c";

// Builds one difficulty slot: its button (added to the scroll view and centred), the difficulty
// word and level-number glyphs, and the two blink lights. All subview frames are within the
// button's own coordinate system and are laid out three ways. The word glyph is omitted for the
// fourth (edit) slot. @p center is the button's centre in the scroll view.
static inline void MusicDetailViewOrgBuildDifficultyButton(MusicDetailViewOrg *self,
                                                           UIButton *__strong *btnDiff,
                                                           UIImageView *__strong *diffTextView,
                                                           UIImageView *__strong *levelTextView,
                                                           UIImageView *__strong *levelNumView,
                                                           UIImageView *__strong (*lightView)[2],
                                                           int index,
                                                           CGPoint center) {
    BOOL isPad = self.isPad;
    BOOL isRetina = self.isRetina;
    char letter = kDiffButtonLetters[index];

    btnDiff[index] = [self diffButton:[NSString stringWithFormat:kDiffButtonNameFormat, letter]];

    if (index != kExtendLevelNumIndex) {
        double textSize =
            isPad ? kDiffTextSizePad : (isRetina ? kDiffTextSizeRetina : kDiffTextSizeNonRetina);
        UIImage *wordImage =
            LoadScaledPngImage([NSString stringWithFormat:kDiffTextNameFormat, letter]);
        diffTextView[index] = [[UIImageView alloc] initWithImage:wordImage];
        [diffTextView[index] setFrame:CGRectMake(0.0, 0.0, textSize, textSize)];
        [diffTextView[index] setAlpha:0.0];
        [btnDiff[index] addSubview:diffTextView[index]];

        CGRect wordFrame = isPad    ? CGRectMake(26.0, 90.0, 78.0, 25.0) :
                           isRetina ? CGRectMake(13.0, 45.0, 39.0, 13.0) :
                                      CGRectMake(5.0, 41.0, 47.0, 15.0);
        levelTextView[index] = [[UIImageView alloc] initWithFrame:wordFrame];
        [btnDiff[index] addSubview:levelTextView[index]];
    }

    CGRect numFrame = isPad    ? CGRectMake(100.0, 90.0, 28.0, 25.0) :
                      isRetina ? CGRectMake(50.0, 45.0, 14.0, 13.0) :
                                 CGRectMake(50.0, 41.0, 17.0, 15.0);
    levelNumView[index] = [[UIImageView alloc] initWithFrame:numFrame];
    [btnDiff[index] addSubview:levelNumView[index]];

    UIImage *lightImage =
        LoadScaledPngImage([NSString stringWithFormat:kDiffLightNameFormat, letter]);
    CGRect topLightFrame = isPad    ? CGRectMake(-2.0, 0.0, 80.0, 28.0) :
                           isRetina ? CGRectMake(-1.0, 0.0, 40.0, 14.0) :
                                      CGRectMake(-4.0, -3.0, 40.0, 14.0);
    lightView[index][0] = [[UIImageView alloc] initWithImage:lightImage];
    [lightView[index][0] setFrame:topLightFrame];
    [btnDiff[index] addSubview:lightView[index][0]];

    CGRect bottomLightFrame = isPad    ? CGRectMake(81.0, 132.0, 80.0, 28.0) :
                              isRetina ? CGRectMake(40.5, 66.0, 40.0, 14.0) :
                                         CGRectMake(37.0, 63.0, 40.0, 14.0);
    lightView[index][1] = [[UIImageView alloc] initWithImage:lightImage];
    [lightView[index][1] setFrame:bottomLightFrame];
    [btnDiff[index] addSubview:lightView[index][1]];

    [btnDiff[index] setCenter:center];
    [self.scrollView addSubview:btnDiff[index]];
}

// The two scroll arrows on the difficulty page.
static NSString *const kScrollArrowRight = @"btn_edit_scroll_r";
static NSString *const kScrollArrowLeft = @"btn_edit_scroll_l";

// The pending-download lamps: the scroll lamp reuses the Knit right-arrow image, the difficulty
// lamp the plain white button image.
static NSString *const kScrollLampImage = @"btn_edit_scroll_r_knt";
static NSString *const kDiffButtonLampImage = @"msel_btn_white";

// The edit-page controls: the info button's text image, the two pad-only action buttons, and the
// three stacked text fields (the comment field, index 2, is the multi-line one).
static NSString *const kEditInfoTextImage = @"edit_info_text";
static NSString *const kUploadButtonImage = @"btn_upload";
static NSString *const kEditButtonImage = @"btn_edit";
static const int kEditTextFieldCount = 3;
static const int kEditCommentIndex = 2;
// The info button drops below the scroll-arrow row by a per-idiom amount.
static const double kInfoButtonDropPad = 212.0;   // @ghidraAddress 0x28f6d8
static const double kInfoButtonDropPhone = 114.0; // @ghidraAddress 0x28f6d0
// The text fields span 95% of the text image, rounded down to an even pixel; the pad action
// buttons sit 138 points left of the scroll content's right edge.
static const double kEditFieldWidthFraction = 0.95; // @ghidraAddress 0x28f6e0
static const double kUploadButtonXOffset = -138.0;  // @ghidraAddress 0x28f6f0

// The hold and extend marks over each difficulty button, keyed by the same difficulty letters used
// above. Each mark's X is its own image width less the host gap and a per-idiom inset; the Y and
// height are fixed.
static NSString *const kHoldMarkFormat = @"hold_ico_%c";
static NSString *const kExtendMarkFormat = @"add_ico_%c";
static NSString *const kExtendOnMarkFormat = @"add_ico_%c_on";
static const double kHostGapNegative = -40.0; // @ghidraAddress 0x28e078
static const double kMarkInsetPad = 32.0;     // @ghidraAddress 0x28f458
static const double kMarkInsetPhone = 16.0;   // fmov, 16
static const double kMarkOffsetY = 4.0;       // fmov, 4
static const double kMarkHeight = 14.0;       // fmov, 14

@implementation MusicDetailViewOrg

/** @ghidraAddress 0x502bc */
+ (Class)layerClass {
    return [CAGradientLayer class];
}

/** @ghidraAddress 0x502d0 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self == nil) {
        return nil;
    }
    bRandomBak = NO;
    BOOL isPad = self.isPad;
    BOOL isRetina = self.isRetina;
    double width = frame.size.width;

    // The scroll view fills the lower band of the card and holds two full-width pages.
    double scrollTop = (isPad ? kScrollViewTopBasePad : kScrollViewTopBasePhone) -
                       (isPad ? kScrollViewTopInsetPad : kScrollViewTopInsetPhone);
    double scrollHeight = isPad ? kScrollViewContentHeightPad : kScrollViewContentHeightPhone;
    self.scrollView =
        [[UIScrollView alloc] initWithFrame:CGRectMake(0.0, scrollTop, width, scrollHeight)];
    [self.scrollView setUserInteractionEnabled:YES];
    [self.scrollView setMultipleTouchEnabled:NO];
    [self.scrollView setAutoresizesSubviews:NO];
    [self.scrollView setOpaque:NO];
    [self.scrollView setBounces:NO];
    [self.scrollView setBackgroundColor:UIColor.clearColor];
    [self.scrollView setAutoresizingMask:kScrollViewAutoresizingMask];
    [self.scrollView setShowsVerticalScrollIndicator:NO];
    [self.scrollView setShowsHorizontalScrollIndicator:NO];
    [self.scrollView setPagingEnabled:YES];
    [self.scrollView setDelegate:self];
    [self.scrollView setContentSize:CGSizeMake(width + width, isPad ? scrollHeight : scrollTop)];
    self.editPage = (int)[NSUserDefaults.standardUserDefaults integerForKey:kPrefEditSelectKey];
    [self.scrollView setContentOffset:CGPointMake((double)self.editPage * width, 0.0) animated:NO];
    [self addSubview:self.scrollView];

    // The card's translucent white background and its gradient-layer border and stops.
    [self setBackgroundColor:[UIColor colorWithWhite:kCardBackgroundWhite
                                               alpha:kCardBackgroundAlpha]];
    CAGradientLayer *gradient = (CAGradientLayer *)self.layer;
    [gradient setBorderWidth:kCardBorderWidth];
    [gradient setBorderColor:UIColor.lightGrayColor.CGColor];
    id topColor = (id)[UIColor colorWithWhite:kGradientTopWhite alpha:kGradientAlpha].CGColor;
    id bottomColor = (id)[UIColor colorWithWhite:kGradientBottomWhite alpha:kGradientAlpha].CGColor;
    [gradient setColors:@[ topColor, bottomColor ]];

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

    // The tune-name image sits to the right of the artwork.
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

    // The iTunes link keeps the tune-name box's size at its own per-idiom Y (gap 10 on the pad,
    // 5 on both phones).
    [self.buttonLink frame];
    double linkGap = isPad ? kTuneNameGapPad : kTuneNameGapRetina;
    double linkY = isPad ? kButtonLinkYPad : kButtonLinkYPhone;
    [self.buttonLink
        setFrame:CGRectMake(artworkRight + linkGap, linkY, tuneNameWidth, tuneNameHeight)];

    // The social recommend buttons stack rightwards from the card's right edge, each centred on
    // the link's vertical centre. The Facebook button is present only when the social compose
    // sheet class exists; it consumes the first slot when so.
    CGRect linkFrame = self.buttonLink.frame;
    int socialCenterY = (int)(linkY + tuneNameHeight * 0.5);
    int socialInset = isPad ? kSocialInsetPad : 0;
    BOOL hasFacebook = NO;
    if (NSClassFromString(@"SLComposeViewController") != nil) {
        [self.btnRecommendFacebook frame];
        CGRect selfFrame = self.frame;
        [self.btnRecommendFacebook
            setFrame:CGRectMake((selfFrame.size.width - linkFrame.size.width) - (double)socialInset,
                                (double)socialCenterY - linkFrame.size.height * 0.5,
                                linkFrame.size.width,
                                linkFrame.size.height)];
        [self.btnRecommendFacebook frame];
        socialInset = isPad ? kSocialGapPad : 0;
        hasFacebook = YES;
    }
    CGRect twitterFrame = self.btnRecommendTwitter.frame;
    double twitterRefWidth = hasFacebook ? linkFrame.size.width : twitterFrame.size.width;
    double selfWidth = hasFacebook ? self.frame.size.width : self.frame.size.width;
    [self.btnRecommendTwitter
        setFrame:CGRectMake((selfWidth - twitterRefWidth) -
                                (double)(hasFacebook ? kSocialGapPad : 0),
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
    for (int i = 0; i < kDiffButtonSlotCount; ++i) {
        MusicDetailViewOrgBuildDifficultyButton(self,
                                                self->btnDiff,
                                                self->diffTextView,
                                                self->levelTextView,
                                                self->levelNumView,
                                                self->lightView,
                                                i,
                                                diffCenters[i]);
    }

    // The forever-blinking light animation, added to the first difficulty's two lights.
    lightBlinkAnim = [CABasicAnimation animationWithKeyPath:@"opacity"];
    [lightBlinkAnim setDuration:kNormalBlinkDuration];
    [lightBlinkAnim setFromValue:@(kNormalBlinkFrom)];
    [lightBlinkAnim setToValue:@(kNormalBlinkTo)];
    [lightBlinkAnim setAutoreverses:YES];
    [lightBlinkAnim setRepeatCount:1e30f]; // g_flRepeatForever1e30
    [lightBlinkAnim
        setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]];
    [lightBlinkAnim setRemovedOnCompletion:NO];
    [lightView[0][0].layer addAnimation:lightBlinkAnim forKey:kBlinkAnimationKey];
    [lightView[0][1].layer addAnimation:lightBlinkAnim forKey:kBlinkAnimationKey];

    [self loadImages];

    // The start-play and host-share buttons sit along the bottom of the card, each at its own image
    // size, the start button left of centre and the host button right of centre.
    double cardHeight = self.frame.size.height;
    int startXOffset = isPad ? kStartButtonXOffsetPad : kStartButtonXOffsetPhone;
    double stackGap = isPad ? 24.0 : 10.0;
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

    // The share-message label, centred horizontally on the card and just above the buttons.
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
    [self.labelShareMessage setHidden:YES];
    [self.labelShareMessage setBackgroundColor:UIColor.clearColor];
    [self.labelShareMessage setTextColor:UIColor.whiteColor];

    // The share-data progress bar, on the same centre line a little lower.
    [self.shareDataProgress
        setFrame:CGRectMake(shareX,
                            self.frame.size.height -
                                (hostImage.size.height +
                                 (isPad ? kShareProgressGapPad : kShareProgressGapPhone)),
                            kShareLabelWidth,
                            (isPad ? kShareProgressHeightPad : kShareProgressHeightPhone))];
    [self.shareDataProgress setProgressViewStyle:UIProgressViewStyleDefault];

    // The music bar and its 120 dot views.
    double barWidth = isPad ? kMusicBarWidthPad : kMusicBarWidthPhone;
    double barHeight = isPad ? kMusicBarHeightPad : kMusicBarHeightPhone;
    mbarBarView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0, 0.0, barWidth, barHeight)];
    [self addSubview:mbarBarView];
    [mbarBarView
        setCenter:CGPointMake(barWidth * 0.5, isPad ? kMusicBarCenterYPad : kMusicBarCenterYPhone)];
    int dotX = isPad ? kMusicBarDotStartPad : 30;
    for (int i = 0; i < kMusicBarDotCount; ++i) {
        CGRect dotFrame;
        if (isPad) {
            dotFrame = CGRectMake(
                (double)dotX, kMusicBarDotYPad, kMusicBarDotWidthPad, kMusicBarDotHeightPad);
        } else {
            int phoneX = i + (isRetina ? kMusicBarDotStartPhone : 20);
            dotFrame = CGRectMake((double)phoneX,
                                  kMusicBarDotYPhone,
                                  kMusicBarDotWidthPhone,
                                  kMusicBarDotHeightPhone);
        }
        mbarDotView[i] = [[UIImageView alloc] initWithFrame:dotFrame];
        [mbarBarView addSubview:mbarDotView[i]];
        dotX += 4;
    }
    [self addSubview:mbarBarView];

    // The high-score board and its seven right-justified score digits.
    highscoreBoardView =
        [[UIImageView alloc] initWithImage:LoadScaledPngImage(kHighscoreBoardImage)];
    double boardX = isPad ? kHighscoreBoardXPad :
                            (isRetina ? kHighscoreBoardXRetina : kHighscoreBoardXNonRetina);
    double boardY = isPad ? kHighscoreBoardYPad : kHighscoreBoardYPhone;
    [highscoreBoardView setCenter:CGPointMake(boardX, boardY)];
    for (int i = 0; i < kHighscoreDigitCount; ++i) {
        CGRect digitFrame;
        if (isPad) {
            digitFrame = CGRectMake((double)(14 + i * 28), 28.0, 28.0, 32.0);
        } else if (isRetina) {
            digitFrame = CGRectMake((double)(7 + i * 14), 14.0, 14.0, 16.0);
        } else {
            digitFrame = CGRectMake((double)((float)i * 17.5f + 8.0f), 11.0, 17.5, 20.0);
        }
        highscoreNumView[i] = [[UIImageView alloc] initWithFrame:digitFrame];
        [highscoreBoardView addSubview:highscoreNumView[i]];
    }

    // The rating image on the board.
    CGRect ratingFrame = isPad    ? CGRectMake(216.0, 2.0, 100.0, 64.0) :
                         isRetina ? CGRectMake(108.0, 1.0, 50.0, 32.0) :
                                    CGRectMake(134.0, 2.0, 50.0, 32.0);
    ratingView = [[UIImageView alloc] initWithFrame:ratingFrame];
    [highscoreBoardView addSubview:ratingView];

    // The combo image on the board.
    CGRect comboFrame = isPad    ? CGRectMake(197.0, 36.0, 140.0, 70.0) :
                        isRetina ? CGRectMake(98.0, 18.0, 70.0, 35.0) :
                                   CGRectMake(124.0, 12.0, 70.0, 40.0);
    comboView = [[UIImageView alloc] initWithFrame:comboFrame];
    [highscoreBoardView addSubview:comboView];
    [self addSubview:highscoreBoardView];
    [highscoreBoardView frame];

    // The random marker keeps its own size but is repositioned relative to the rating image: its
    // left edge one point inside the rating's, and its top the rating's centre line, less a small
    // idiom inset.
    CGPoint randCenter = self.randView.center;
    CGSize randSize = self.randView.frame.size;
    int randInset = isPad ? 5 : 3;
    double randX = ratingFrame.origin.x - randCenter.x - 1.0;
    double randY =
        (double)((int)(ratingFrame.origin.y + (ratingFrame.size.height - randCenter.y) * 0.5) -
                 randInset);
    [self.randView setFrame:CGRectMake(randX, randY, randSize.width, randSize.height)];

    // The two scroll arrows: the right arrow, then the left, each fading out from a page edge.
    CGRect edgeButtonFrame = btnDiff[0].frame;
    double scrollBtnY = isPad ? 20.0 : 10.0;
    NSString *arrowNames[] = {kScrollArrowRight, kScrollArrowLeft};
    for (int i = 0; i < 2; ++i) {
        UIImage *arrow = LoadScaledPngImage(arrowNames[i]);
        detailScrollButton[i] = [UIButton buttonWithType:UIButtonTypeCustom];
        [self.scrollView frame];
        double arrowX =
            self.scrollView.frame.size.width - arrow.size.width + (double)i * arrow.size.width;
        [detailScrollButton[i]
            setFrame:CGRectMake(arrowX, scrollBtnY, arrow.size.width, edgeButtonFrame.size.height)];
        [detailScrollButton[i] setImage:arrow forState:UIControlStateNormal];
        [detailScrollButton[i] setExclusiveTouch:YES];
        [detailScrollButton[i] setAdjustsImageWhenHighlighted:YES];
        [detailScrollButton[i] setAdjustsImageWhenDisabled:YES];
        [detailScrollButton[i] addTarget:self
                                  action:@selector(scrollChange:)
                        forControlEvents:UIControlEventTouchUpInside];
        [self.scrollView addSubview:detailScrollButton[i]];
    }

    // The info-edit button on the edit page: below the difficulty buttons at a per-idiom drop, its
    // width per idiom and height the text image's own.
    UIImage *infoImage = LoadScaledPngImage(kEditInfoTextImage);
    double infoY =
        (double)(float)(scrollBtnY + (isPad ? kInfoButtonDropPad : kInfoButtonDropPhone));
    int infoWidth = isPad ? 30 : 14;
    infoBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [infoBtn
        setFrame:CGRectMake(
                     edgeButtonFrame.origin.y, infoY, (double)infoWidth, infoImage.size.height)];
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

    // The three edit-info text fields stack down the edit page. Their font size is per idiom
    // (16 on the pad, 11 on the phone), the step between them per idiom (8 / 5), and the comment
    // field (index 2) is the tall multi-line one. The fields' width comes from the text image
    // rounded down to an even pixel; their left edge centres that width under the image.
    int fontSize = isPad ? 16 : 11;
    int fieldStep = isPad ? 8 : 5;
    int fieldHeight = (isPad ? 4 : 1) + fontSize;
    int firstFieldY = infoWidth + 4;
    double imageWidth = infoImage.size.width;
    int fieldWidth = (int)(imageWidth * kEditFieldWidthFraction);
    fieldWidth -= (fieldWidth % 2 == 1) ? 1 : 0;
    double fieldX = (double)(int)(infoY + (infoImage.size.width - (double)fieldWidth) * 0.5 + 2.0);
    int fieldY = firstFieldY;
    for (int i = 0; i < kEditTextFieldCount; ++i) {
        editTxt[i] = [[UILabel alloc]
            initWithFrame:CGRectMake(
                              fieldX, (double)fieldY, (double)fieldWidth, (double)fieldHeight)];
        [editTxt[i] setFont:[UIFont systemFontOfSize:(double)fontSize]];
        [editTxt[i] setTextColor:[UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:1.0]];
        [editTxt[i] setText:@""];
        if (i == kEditCommentIndex) {
            int lines = self.isPad ? 3 : 2;
            [editTxt[i] setFrame:CGRectMake(fieldX,
                                            (double)fieldY,
                                            (double)fieldWidth,
                                            (double)(int)(lines * (fieldHeight + 1)))];
            [editTxt[i] setNumberOfLines:lines];
            [editTxt[i] setLineBreakMode:NSLineBreakByCharWrapping];
        }
        [editTxt[i] setBackgroundColor:UIColor.clearColor];
        [self.scrollView addSubview:editTxt[i]];
        fieldY += fieldHeight + fieldStep;
    }

    // On the pad the upload and edit buttons follow the text fields, right-aligned to the scroll
    // content and stacked at the info button's row.
    if (self.isPad) {
        double buttonX = self.scrollView.contentSize.width + kUploadButtonXOffset;
        double buttonY = (double)(firstFieldY - 2);
        UIImage *uploadImage = LoadScaledPngImage(kUploadButtonImage);
        uploadBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [uploadBtn setBackgroundImage:uploadImage forState:UIControlStateNormal];
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
        [editBtn setBackgroundImage:editImage forState:UIControlStateNormal];
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

    // Apply the remembered difficulty (a stale extreme snaps back to basic) and enable the
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
    if (self.editPage != 0) {
        [self editMusicBar];
    }

    // The two lamp overlays that pulse to advertise a pending download; both start hidden. The
    // scroll lamp reuses the Knit right-arrow image, sized to the rating image's width and centred
    // on the upper half of the scroll view; the difficulty lamp overlays the extend button.
    UIImage *scrollLampImage = LoadScaledPngImage(kScrollLampImage);
    scrollLamp = [[UIImageView alloc] initWithImage:scrollLampImage];
    [scrollLamp setFrame:CGRectMake(0.0, 0.0, scrollLampImage.size.width, ratingFrame.size.width)];
    double lampCenterY = (double)((int)scrollHeight >> 1);
    [scrollLamp setCenter:CGPointMake(scrollLampImage.size.width * 0.5, lampCenterY)];
    [self.scrollView addSubview:scrollLamp];
    [scrollLamp setHidden:YES];

    UIImage *diffLampImage = LoadScaledPngImage(kDiffButtonLampImage);
    diffBtnLamp = [[UIImageView alloc] initWithImage:diffLampImage];
    [diffBtnLamp setFrame:CGRectMake(0.0, 0.0, diffLampImage.size.width, lampCenterY)];
    [btnDiff[kExtendLevelNumIndex] addSubview:diffBtnLamp];
    [diffBtnLamp setAlpha:kNormalBlinkDuration];
    [diffBtnLamp setHidden:YES];
    if ([NSUserDefaults.standardUserDefaults integerForKey:kPrefJcfDownloadSelectKey] ==
        kJcfDownloadSelectPending) {
        [scrollLamp setHidden:NO];
        [diffBtnLamp setHidden:NO];
    }

    // The hold marks and the extend/extend-on marks over each difficulty button. Each mark's X is
    // its own image width shifted left by the host gap (-40) and a per-idiom inset (pad 32 /
    // phone 16); the Y and height are a fixed small inset. All start hidden.
    double markInset = isPad ? kMarkInsetPad : kMarkInsetPhone;
    for (int i = 0; i < kDiffButtonCount; ++i) {
        UIImage *holdImage =
            LoadScaledPngImage([NSString stringWithFormat:kHoldMarkFormat, kDiffButtonLetters[i]]);
        holdMark[i] = [[UIImageView alloc] initWithImage:holdImage];
        double markX = holdImage.size.width + kHostGapNegative - markInset;
        [holdMark[i] setFrame:CGRectMake(markX, kMarkOffsetY, holdImage.size.width, kMarkHeight)];
        [holdMark[i] setHidden:YES];
        [btnDiff[i] addSubview:holdMark[i]];
    }
    for (int i = 0; i < kDiffButtonCount; ++i) {
        UIImage *extendImage = LoadScaledPngImage(
            [NSString stringWithFormat:kExtendMarkFormat, kDiffButtonLetters[i]]);
        double extendX = extendImage.size.width + kHostGapNegative - markInset;
        extendMark[i] = [[UIImageView alloc] initWithFrame:CGRectMake((double)(int)extendX,
                                                                      kMarkOffsetY,
                                                                      extendImage.size.width,
                                                                      kMarkHeight)];
        [extendMark[i] setHidden:YES];
        [btnDiff[i] addSubview:extendMark[i]];

        UIImage *extendOnImage = LoadScaledPngImage(
            [NSString stringWithFormat:kExtendOnMarkFormat, kDiffButtonLetters[i]]);
        extendOnMark[i] = [[UIImageView alloc] initWithImage:extendOnImage];
        [extendOnMark[i] setFrame:CGRectMake((double)(int)extendX,
                                             kMarkOffsetY,
                                             extendOnImage.size.width,
                                             kMarkHeight)];
        [extendOnMark[i] setHidden:YES];
        [btnDiff[i] addSubview:extendOnMark[i]];
    }
    [self addSubview:self.coverView];

    return self;
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
            completion:^(BOOL __attribute__((unused)) finished) {
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
                         completion:^(BOOL __attribute__((unused)) finished){
                             /** @ghidraAddress 0x58934 */
                         }];
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
                     completion:^(BOOL __attribute__((unused)) finished){
                         /** @ghidraAddress 0x58830 */
                     }];
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

/** @ghidraAddress 0x5749c */
- (void)changeDifficulty:(int)difficulty {
    char levels[] = {self.levelBas, self.levelAdv, self.levelExt};
    for (int i = 0; i < kDiffButtonCount; ++i) {
        char level = levels[i];
        if (i == difficulty) {
            // The selected difficulty is shown full, its light pair blinks, and its own level word
            // and number glyphs appear.
            [btnDiff[i] setAlpha:1.0];
            [diffTextView[i] setAlpha:1.0];
            [lightView[i][0].layer addAnimation:lightBlinkAnim forKey:kBlinkAnimationKey];
            [lightView[i][1].layer addAnimation:lightBlinkAnim forKey:kBlinkAnimationKey];
            [levelTextView[i] setImage:levelTextImg[i]];
            [levelNumView[i] setImage:levelNumImg[i][(int)level]];
        } else {
            // The others dim, hide their difficulty text, stop their light blink, and show the
            // "off" level word and number glyphs.
            [btnDiff[i] setAlpha:kDiffButtonUnselectedAlpha];
            [diffTextView[i] setAlpha:0.0];
            [lightView[i][0].layer removeAnimationForKey:kBlinkAnimationKey];
            [lightView[i][1].layer removeAnimationForKey:kBlinkAnimationKey];
            [lightView[i][0] setAlpha:0.0];
            [lightView[i][1] setAlpha:0.0];
            [levelTextView[i] setImage:levelTextImg[kLevelOffWordIndex]];
            [levelNumView[i] setImage:levelNumImg[kLevelOffRow][(int)level]];
        }
    }
    // The extend button is always full and unscaled.
    [btnDiff[kExtendLevelNumIndex] setAlpha:1.0];
    [btnDiff[kExtendLevelNumIndex] setTransform:CGAffineTransformIdentity];
    [self infoChange:difficulty];
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
            UIImageView *boardView = highscoreBoardView;
            [UIView animateWithDuration:kExtendModeAnimDuration
                             animations:^{
                               /** @ghidraAddress 0x570a4 */
                               [weakSelf changeDifficulty:current];
                               MusicDetailViewOrgRepositionHighscoreBoard(weakSelf, boardView);
                               [boardView setAlpha:1.0];
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

/** @ghidraAddress 0x5a1c0 */
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

    // The selected difficulty's two light views swap their slow blink for a fast opacity pulse.
    CABasicAnimation *blink = [CABasicAnimation animationWithKeyPath:@"opacity"];
    [blink setDuration:kLightBlinkDuration];
    [blink setFromValue:@(kLightBlinkFromOpacity)];
    [blink setToValue:@(kLightBlinkToOpacity)];
    [blink setAutoreverses:YES];
    [blink setRepeatCount:kLightBlinkRepeatCount];
    [blink setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]];
    [blink setRemovedOnCompletion:NO];
    [lightView[difficulty][0].layer removeAnimationForKey:kBlinkAnimationKey];
    [lightView[difficulty][0].layer addAnimation:blink forKey:kBlinkFastAnimationKey];
    [lightView[difficulty][1].layer removeAnimationForKey:kBlinkAnimationKey];
    [lightView[difficulty][1].layer addAnimation:blink forKey:kBlinkFastAnimationKey];

    __weak MusicDetailViewOrg *weakSelf = self;
    BOOL hasShareManager = (shareManager != nil);
    [UIView animateWithDuration:kStartPlayTransitionDuration
        delay:0.0
        options:UIViewAnimationOptionBeginFromCurrentState
        animations:^{
          /** @ghidraAddress 0x5a894 */
          MusicDetailViewOrgShrinkUnselectedButtons(
              self->btnDiff, self->detailScrollButton, difficulty);
        }
        completion:^(BOOL __attribute__((unused)) finished) {
          /** @ghidraAddress 0x5aa9c */
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

/** @ghidraAddress 0x58d14 */
- (void)show:(BOOL)show {
    [self.controller resetWillStart];
    self.isShared = show;
    // The classic theme resets every difficulty button's transform to identity (selection is shown
    // through the light views, not a button scale).
    for (int i = 0; i < kDiffButtonSlotCount; ++i) {
        [btnDiff[i] setTransform:CGAffineTransformIdentity];
    }

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

    // Restore the difficulty scroll to the remembered edit page.
    self.editPage = (int)[NSUserDefaults.standardUserDefaults integerForKey:kPrefEditSelectKey];
    double width = self.scrollView.frame.size.width;
    [self.scrollView setContentOffset:CGPointMake(width * (double)self.editPage, 0.0) animated:NO];
    [self.scrollView setScrollEnabled:YES];
    [detailScrollButton[0] setAlpha:1.0];
    detailScrollButton[0].layer.transform = CATransform3DMakeScale(1.0, 1.0, 1.0);
    [detailScrollButton[1] setAlpha:1.0];
    detailScrollButton[1].layer.transform = CATransform3DMakeScale(1.0, 1.0, 1.0);

    // A pending download selection pulses the scroll and difficulty-button lamps.
    int difficulty = (int)[NSUserDefaults.standardUserDefaults integerForKey:kPrefDifficultyKey];
    if ([[NSUserDefaults.standardUserDefaults objectForKey:kPrefJcfDownloadSelectKey] intValue] ==
        kJcfDownloadSelectPending) {
        __weak UIView *weakScrollLamp = scrollLamp;
        __weak UIView *weakDiffLamp = diffBtnLamp;
        [UIView animateWithDuration:kLampPulseDuration
                              delay:kLampPulseDelay
                            options:UIViewAnimationOptionRepeat |
                                    UIViewAnimationOptionAllowUserInteraction
                         animations:^{
                           /** @ghidraAddress 0x59570 */
                           [weakScrollLamp setAlpha:0.0];
                           [weakScrollLamp
                               setTransform:CGAffineTransformMakeScale(1.0, kLampPulseHeightScale)];
                         }
                         completion:nil];
        [UIView animateWithDuration:kLampPulseDuration
                              delay:kLampPulseDelay
                            options:UIViewAnimationOptionRepeat |
                                    UIViewAnimationOptionAllowUserInteraction |
                                    UIViewAnimationOptionAutoreverse
                         animations:^{
                           /** @ghidraAddress 0x5961c */
                           [weakDiffLamp setAlpha:0.0];
                           [weakDiffLamp
                               setTransform:CGAffineTransformMakeScale(1.0, kLampPulseHeightScale)];
                         }
                         completion:nil];
    }
    [self infoChange:difficulty];
}

/** @ghidraAddress 0x551d4 */
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

    // Update each difficulty's level image from the base or extend level; the classic theme keeps a
    // per-difficulty level-glyph row.
    char levels[] = {self.levelBas, self.levelAdv, self.levelExt};
    char extendLevels[] = {self.extendLevelBas, self.extendLevelAdv, self.extendLevelExt};
    for (int i = 0; i < kDiffButtonCount; ++i) {
        BOOL isExtend = JubeatAppDelegate.appDelegate.isExtend;
        char level = levels[i];
        if (isExtend && (self.extendInfo.extendFlag & (1 << i)) != 0) {
            level = extendLevels[i];
        }
        [levelNumView[i] setImage:levelNumImg[i][(int)level]];
    }

    // The current difficulty's hold mark drives the app hold flag (except on the edit page).
    BOOL holdHidden = holdMark[difficulty].isHidden;
    [JubeatAppDelegate.appDelegate setHoldFlag:(self.editPage != 1) && !holdHidden];
    [self refreshStartButton];
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

        UIImageView *const *levelNums = levelNumView;
        UIImageView *const *extendMarks = extendMark;
        UIImageView *const *extendOnMarks = extendOnMark;
        UIImageView *const *holdMarks = holdMark;
        [UIView animateWithDuration:kExtendCrossFadeDuration
                         animations:^{
                           /** @ghidraAddress 0x565f8 */
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
                completion:^(BOOL __attribute__((unused)) finished) {
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
                     completion:^(BOOL __attribute__((unused)) finished){
                         /** @ghidraAddress 0x5b3a4 */
                     }];
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
        completion:^(BOOL __attribute__((unused)) finished) {
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

/** @ghidraAddress 0x54dac */
- (void)setInfo:(nullable TuneInfo *)info score:(nullable id)score {
    [super setInfo:info score:score];
    if (info == nil) {
        return;
    }
    self.levelBas = MusicDetailViewOrgLevelIndex(info.lvBas);
    self.levelAdv = MusicDetailViewOrgLevelIndex(info.lvAdv);
    self.levelExt = MusicDetailViewOrgLevelIndex(info.lvExt);
    [self.buttonLink setEnabled:(info.iTunesURL != nil)];
    [self.buttonLink setHidden:(info.iTunesURL == nil)];
    [self.btnRecommendTwitter setHidden:NO];
    [self.btnRecommendFacebook setHidden:NO];
    // The base level images come from the "off" difficulty-word row until a difficulty is selected.
    [levelNumView[0] setImage:levelNumImg[kLevelOffRow][(int)self.levelBas]];
    [levelNumView[1] setImage:levelNumImg[kLevelOffRow][(int)self.levelAdv]];
    [levelNumView[2] setImage:levelNumImg[kLevelOffRow][(int)self.levelExt]];
    [self resetScore];
    [self putScore:score];
    [self loadContentFromPath:info.filePath orData:nil];
    [self loadEditFile];
    [self resetTextField:(int)info.tuneID isFirst:YES];
    [self editMusicBar];
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
                     completion:^(BOOL __attribute__((unused)) finished){
                         /** @ghidraAddress 0x5c4f8 */
                     }];
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
        completion:^(BOOL __attribute__((unused)) finished) {
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
        completion:^(BOOL __attribute__((unused)) finished) {
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
    MusicDetailViewOrgSettleScrollPage(self, self->holdMark);
}

/** @ghidraAddress 0x5c8c8 */
- (void)scrollViewDidEndDecelerating:(nullable UIScrollView *)scrollView {
    MusicDetailViewOrgSettleScrollPage(self, self->holdMark);
}

/** @ghidraAddress 0x5cb8c */
- (void)scrollViewDidEndDragging:(nullable UIScrollView *)scrollView
                  willDecelerate:(BOOL)decelerate {
    if (!decelerate) {
        MusicDetailViewOrgSettleScrollPage(self, self->holdMark);
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
