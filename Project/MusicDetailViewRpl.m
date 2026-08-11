#import "MusicDetailViewRpl.h"

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
#import "SharePlayManager.h"
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

// A music bar carries at least 30 bytes of resource map for the 120 dots.
static const NSUInteger kMbarMinimumLength = 30;

// A pending download selection pulses the scroll and difficulty-button lamps: alpha to zero and a
// vertical stretch, repeating over this duration after this delay.
static const NSTimeInterval kLampPulseDuration = 0.5; // fmov, 0.5
static const NSTimeInterval kLampPulseDelay = 0.5;    // fmov, 0.5
static const CGFloat kLampPulseHeightScale = 2.0;     // fmov, 2.0
static const NSInteger kJcfDownloadSelectPending = 1;

// Starting play shrinks the unselected buttons over this duration and locks input for a beat; a
// client waiting for the host shows this prompt.
static NSString *const kWaitingForHostKey = @"Waiting for host to start";
static const NSTimeInterval kStartPlayTransitionDuration = 0.6; // @ghidraAddress 0x28f288
static const NSTimeInterval kStartPlayInputLockDuration = 0.7;  // @ghidraAddress 0x28f2a0

// Scales out and fades every difficulty button except the selected one, plus both scroll buttons,
// when starting play.
static inline void MusicDetailViewRplScaleOutUnselectedButtons(UIButton *const *btnDiff,
                                                               UIButton *const *detailScrollButton,
                                                               int selected) {
    CATransform3D shrink =
        CATransform3DMakeScale(kEditButtonShrinkScale, kEditButtonShrinkScale, 1.0);
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

// With no edit loaded the three edit text fields dim to this alpha; the edit buttons fade in over
// this duration; a dlFlag of this value marks a downloaded edit.
static const CGFloat kEditTextDimmedAlpha = 0.5;          // fmov, 0.5
static const NSTimeInterval kResetTextFadeDuration = 0.1; // @ghidraAddress 0x28f290
static const NSInteger kEditDownloadFlag = 1;

// The pad edit-file delete list is presented as a 300x400 popover.
static const double kEditPopoverWidth = 300.0;  // @ghidraAddress 0x28f2d0
static const double kEditPopoverHeight = 400.0; // @ghidraAddress 0x28f2e0

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

// The host share-play button's background image, and the cancel image, waiting prompt, cancel cue,
// and fade duration used when starting or stopping a host share.
static NSString *const kHostButtonImage = @"menu_button_host_rpl";
static NSString *const kCancelButtonImage = @"menu_button_cancel_rpl";
static NSString *const kWaitingForClientKey = @"Waiting for client";
static NSString *const kHostShareCancelSound = @"SD_RPL_SKIP";
static const NSTimeInterval kHostShareStartFadeDuration = 0.3; // @ghidraAddress 0x28f260

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
static inline void MusicDetailViewRplSettleScrollPage(MusicDetailViewRpl *self,
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

// The high-score board's home centre (per idiom) and the extend-toggle slide offset subtracted from
// its X before it slides home, plus the per-difficulty voice cues and the input-lock durations.
static const double kHighscoreBoardXPad = 420.0;       // @ghidraAddress 0x292538
static const double kHighscoreBoardXRetina = 215.0;    // @ghidraAddress 0x292e68
static const double kHighscoreBoardXNonRetina = 210.0; // @ghidraAddress 0x28f200
static const double kHighscoreBoardSlidePad = 20.0;    // fmov, 20.0
static const double kHighscoreBoardSlidePhone = 10.0;  // fmov, 10.0
static const double kHighscoreBoardYPad = 240.0;       // @ghidraAddress 0x291bf0
static const double kHighscoreBoardYPhone = 120.0;     // @ghidraAddress 0x28f210
static NSString *const kDifficultyVoiceCues[] = {
    @"SD_RPL_CV_BASIC", @"SD_RPL_CV_ADVANCED", @"SD_RPL_CV_EXTREME"};
static const NSTimeInterval kSelectDiffInputLock = 0.4;       // @ghidraAddress 0x28f268
static const NSTimeInterval kSelectDiffExtendInputLock = 0.4; // @ghidraAddress 0x28f2c0

// Repositions the high-score text view for the current idiom (a shared reposition used by the
// difficulty-select path).
static inline void MusicDetailViewRplRepositionHighscoreText(MusicDetailViewRpl *self,
                                                             UIImageView *highscoreTextView) {
    double baseX = self.isPad ? kHighscoreBaseXPad : kHighscoreBaseXPhone;
    double centerY = self.isPad ? kHighscoreCenterYPad : kHighscoreCenterYPhone;
    [highscoreTextView setCenter:CGPointMake(baseX + kHighscoreCenterXNudge, centerY)];
}

// Repositions the high-score board view to its idiom home centre.
static inline void MusicDetailViewRplRepositionHighscoreBoard(MusicDetailViewRpl *self,
                                                              UIImageView *highscoreBoardView) {
    double homeX = self.isPad ?
                       kHighscoreBoardXPad :
                       (self.isRetina ? kHighscoreBoardXRetina : kHighscoreBoardXNonRetina);
    double y = self.isPad ? kHighscoreBoardYPad : kHighscoreBoardYPhone;
    [highscoreBoardView setCenter:CGPointMake(homeX, y)];
}

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

// The layout constants used only while building the card in -initWithFrame:. The reflec-beat theme
// lays everything out three ways: pad, retina phone, and non-retina phone.

// The scroll view's top band is (pad 410 / phone 210) minus its own height (pad 100 / phone 50); it
// holds two full-width pages of (pad 200 / phone 100) height.
static const double kScrollViewTopBasePad = 410.0;         // 0x19a
static const double kScrollViewTopBasePhone = 210.0;       // 0xd2
static const double kScrollViewTopInsetPad = 100.0;        // 0x64
static const double kScrollViewTopInsetPhone = 50.0;       // 0x32
static const double kScrollViewContentHeightPad = 200.0;   // @ghidraAddress 0x28f400
static const double kScrollViewContentHeightPhone = 100.0; // @ghidraAddress 0x28f3f0
static const NSInteger kScrollViewAutoresizingMask = 18;

// The card background is opaque white at 0.9 alpha; the gradient-layer border is 2pt light grey and
// its stops run from white (0.9 alpha) to 60% grey.
static const CGFloat kCardBackgroundWhite = 1.0;
static const CGFloat kCardBackgroundAlpha = 0.9; // @ghidraAddress 0x28f448
static const CGFloat kCardBorderWidth = 2.0;
static const CGFloat kGradientTopWhite = 0.9;    // @ghidraAddress 0x28f448
static const CGFloat kGradientBottomWhite = 0.6; // @ghidraAddress 0x28f230
static const CGFloat kGradientAlpha = 0.9;       // @ghidraAddress 0x28f448

// The full-card background image, sized to its own PNG and pinned to the card's bottom.
static NSString *const kDetailBackgroundImage = @"msel_detail_bg_rpl";

// The artwork and reflection (shared idiom sizing with the classic theme): square side (pad 200 /
// retina 110 / non-retina 95), inset (pad 10 / phone 8), reflection nudged (retina 0.5 /
// non-retina 1.0) and a fraction (pad 0.3 / phone 0.2) as tall.
static const double kArtworkInsetPad = 10.0;
static const double kArtworkInsetPhone = 8.0;
static const double kArtworkSizePad = 200.0;
static const double kArtworkSizeRetina = 110.0;   // 0x6e
static const double kArtworkSizeNonRetina = 95.0; // 0x5f
static const float kReflectionNudgeRetina = 0.5f;
static const float kReflectionNudgeNonRetina = 1.0f;
static const float kReflectionFractionPadF = 0.3f;   // @ghidraAddress 0x28e0b0 (g_flComboFadeBase)
static const float kReflectionFractionPhoneF = 0.2f; // @ghidraAddress 0x28f3c8

// The tune-name image and iTunes link sit right of the artwork: left edge the artwork's right plus
// an idiom gap, box (pad 340x64 / retina 170x32 / non-retina 204x38), the link at a per-idiom Y.
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

// The social recommend buttons stack rightwards from the card edge with a per-idiom inset.
static const int kSocialInsetPad = 24;
static const int kSocialGapPad = 10;

// The difficulty buttons ride the scroll view: first at a fixed left centre (pad 110 / phone 60),
// second at mid-page, third near the right, fourth (edit) one page over; all at centre Y
// (pad 100 / phone 50). Each carries a level-number image at a per-idiom frame.
static const double kDiffCenterEdgePad = 110.0;  // @ghidraAddress 0x28f5e8
static const double kDiffCenterEdgePhone = 60.0; // @ghidraAddress 0x28f258
static const double kDiffCenterYPad = 100.0;     // @ghidraAddress 0x28f3f0
static const double kDiffCenterYPhone = 50.0;    // @ghidraAddress 0x28f2c8
static NSString *const kDiffButtonNameFormat = @"msel_btn_%c_rpl";
static const double kLevelNumXPad = 93.0;    // @ghidraAddress 0x292e50
static const double kLevelNumYPad = 84.0;    // @ghidraAddress 0x292e58
static const double kLevelNumSizePad = 32.0; // @ghidraAddress 0x28f458
static const double kLevelNumXPhone = 50.0;  // @ghidraAddress 0x28f2c8
static const double kLevelNumYPhone = 46.0;  // @ghidraAddress 0x28f740
static const double kLevelNumSizePhone = 16.0;

// The start-play/host-share buttons stack along the card's bottom; X is the card centre less a
// per-idiom offset (pad 120 / phone 75).
static const int kStartButtonXOffsetPad = 120;  // 0x78
static const int kStartButtonXOffsetPhone = 75; // 0x4b
static const double kButtonStackGapPad = 24.0;
static const double kButtonStackGapPhone = 10.0;

// The share label and progress bar are 300 wide, the same value negated centres them on the host
// button. The label height/font, the progress height, and the gaps are per idiom.
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

// The note bar: its own view (width pad 568 / retina 290 / non-retina 240, height pad 38 /
// phone 19) centred at (barWidth/2, pad 150.5 / phone ...), and 120 dot views across it.
static const double kMusicBarWidthPad = 568.0;       // @ghidraAddress 0x28dfd8
static const double kMusicBarWidthRetina = 290.0;    // @ghidraAddress 0x291e38
static const double kMusicBarWidthNonRetina = 240.0; // @ghidraAddress 0x291bf0 (via 0x291e38 arm)
static const double kMusicBarHeightPad = 38.0;       // @ghidraAddress 0x28f4f8
static const double kMusicBarHeightPhone = 19.0;
static const double kMusicBarCenterYPad = 150.5;  // @ghidraAddress 0x292e60
static const double kMusicBarDotHeightPad = 36.0; // @ghidraAddress 0x28f530
static const int kMusicBarDotStartPad = 42;
static const int kMusicBarDotStartRetina = 25;
static const int kMusicBarDotStartNonRetina = 30;

// The high-score board and its text overlay, seven score digits, rating, and combo images.
static NSString *const kHighscoreBoardImage = @"msc_hsboard_rpl";
static NSString *const kHighscoreTextImage = @"msc_hstext_rpl";

// The scroll arrows, the info button, and the pad-only upload/edit buttons.
static NSString *const kScrollArrowRight = @"btn_edit_scroll_r_rpl";
static NSString *const kScrollArrowLeft = @"btn_edit_scroll_l_rpl";
static NSString *const kEditInfoTextImage = @"edit_info_text_rpl";
static NSString *const kUploadButtonImage = @"btn_upload_rpl";
static NSString *const kEditButtonImage = @"btn_edit_rpl";
static const int kEditTextFieldCount = 3;
static const int kEditCommentIndex = 2;
static const double kEditFieldWidthFraction = 0.95; // @ghidraAddress 0x28f6e0
static const double kInfoButtonDropPad = 212.0;     // @ghidraAddress 0x28f6d8
static const double kInfoButtonDropPhone = 114.0;   // @ghidraAddress 0x28f6d0
static const double kUploadContentPad = -128.0;     // @ghidraAddress 0x292e80

// The pending-download lamps: the scroll lamp reuses the Knit right-arrow image; the difficulty
// lamp the reflec-beat white button. The difficulty lamp is sized per idiom.
static NSString *const kScrollLampImage = @"btn_edit_scroll_r_knt";
static NSString *const kDiffButtonLampImage = @"msel_btn_white_rpl";
static const double kDiffLampWidthPad = 142.0;   // @ghidraAddress 0x292e88
static const double kDiffLampWidthPhone = 78.0;  // @ghidraAddress 0x28f5f0
static const double kDiffLampHeightPad = 138.0;  // @ghidraAddress 0x2924c8
static const double kDiffLampHeightPhone = 76.0; // @ghidraAddress 0x292488

// The hold and extend marks over each difficulty button, keyed by difficulty letters.
static const char kDiffButtonLetters[] = {'b', 'a', 'e', 'o'};
static NSString *const kHoldMarkFormat = @"hold_ico_%c_rpl";
static NSString *const kExtendMarkFormat = @"add_ico_%c_rpl";
static NSString *const kExtendOnMarkFormat = @"add_ico_%c_on_rpl";
static const double kHostGapNegative = -40.0; // @ghidraAddress 0x28e078
static const double kMarkInsetPad = 32.0;     // @ghidraAddress 0x28f458
static const double kMarkInsetPhone = 16.0;
static const double kMarkTopPad = 4.0; // 0x4010 -> via arm
static const double kMarkHeightPad = 16.0;

// Builds one difficulty slot: its button (added to the scroll view and centred) and its level
// number image. @p center is the button's centre in the scroll view.
static inline void MusicDetailViewRplBuildDifficultyButton(MusicDetailViewRpl *self,
                                                           UIButton *__strong *btnDiff,
                                                           UIImageView *__strong *levelNumView,
                                                           int index,
                                                           CGPoint center) {
    BOOL isPad = self.isPad;
    btnDiff[index] = [self
        diffButton:[NSString stringWithFormat:kDiffButtonNameFormat, kDiffButtonLetters[index]]];
    double numX = isPad ? kLevelNumXPad : kLevelNumXPhone;
    double numY = isPad ? kLevelNumYPad : kLevelNumYPhone;
    double numSize = isPad ? kLevelNumSizePad : kLevelNumSizePhone;
    levelNumView[index] =
        [[UIImageView alloc] initWithFrame:CGRectMake(numX, numY, numSize, numSize)];
    [btnDiff[index] addSubview:levelNumView[index]];
    [btnDiff[index] setCenter:center];
    [self.scrollView addSubview:btnDiff[index]];
}

@implementation MusicDetailViewRpl

/** @ghidraAddress 0x12ad40 */
+ (Class)layerClass {
    return [CAGradientLayer class];
}

/** @ghidraAddress 0x12ad54 */
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
    [self.scrollView setContentSize:CGSizeMake(width + width, scrollHeight)];
    self.editPage = (int)[NSUserDefaults.standardUserDefaults integerForKey:kPrefEditSelectKey];
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
        MusicDetailViewRplBuildDifficultyButton(
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
    [self.labelShareMessage setHidden:YES];
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
        setCenter:CGPointMake(barWidth * 0.5, isPad ? kMusicBarCenterYPad : kMusicBarHeightPhone)];
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
            digitFrame = CGRectMake((double)(i * 33), 0.0, 32.0, 40.0);
        } else {
            float step = isRetina ? 20.5f : 22.0f;
            digitFrame = CGRectMake((double)((float)i * step + 1.0f), 1.0, 19.0, 24.0);
        }
        highscoreNumView[i] = [[UIImageView alloc] initWithFrame:digitFrame];
        [highscoreBoardView addSubview:highscoreNumView[i]];
    }

    // The rating image: pad at 232, retina at 145, non-retina at 154; square (pad 40 / phone 24).
    CGRect ratingFrame = isPad    ? CGRectMake(232.0, 0.0, 40.0, 40.0) :
                         isRetina ? CGRectMake(145.0, 1.0, 24.0, 24.0) :
                                    CGRectMake(154.0, 1.0, 24.0, 24.0);
    ratingView = [[UIImageView alloc] initWithFrame:ratingFrame];
    [highscoreBoardView addSubview:ratingView];

    // The combo image: pad (90, 30, 140, 16), retina (58, 20, 88, 10), non-retina (70, 20, 88, 10).
    CGRect comboFrame = isPad    ? CGRectMake(90.0, 30.0, 140.0, 16.0) :
                        isRetina ? CGRectMake(58.0, 20.0, 88.0, 10.0) :
                                   CGRectMake(70.0, 20.0, 88.0, 10.0);
    comboView = [[UIImageView alloc] initWithFrame:comboFrame];
    [highscoreBoardView addSubview:comboView];

    highscoreTextView = [[UIImageView alloc] initWithImage:LoadScaledPngImage(kHighscoreTextImage)];
    double textX = isPad ? kHighscoreBaseXPad : kHighscoreBaseXPhone;
    double textY = isPad ? kHighscoreCenterYPad : kHighscoreCenterYPhone;
    [highscoreTextView setCenter:CGPointMake(textX, textY)];
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
    double scrollBtnY = isPad ? kHighscoreBoardSlidePad : kHighscoreBoardSlidePhone;
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
        double buttonX = self.scrollView.contentSize.width + kUploadContentPad;
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
    double lampWidth = isPad ? kDiffLampWidthPad : kDiffLampWidthPhone;
    double lampHeight = isPad ? kDiffLampHeightPad : kDiffLampHeightPhone;
    [diffBtnLamp setFrame:CGRectMake(0.0, 0.0, lampWidth, lampHeight)];
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

/** @ghidraAddress 0x132508 */
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
        [levelNumView[kExtendButtonIndex] setAlpha:0.0];
        [manager clearEditData];
        [self setStartButtonEnable];
        [UIView animateWithDuration:kResetTextFadeDuration
                         animations:^{
                           /** @ghidraAddress 0x132c50 */
                           [weakInfo setAlpha:1.0];
                           [weakUpload setAlpha:1.0];
                           [weakEdit setAlpha:1.0];
                         }
                         completion:^(BOOL finished){
                             /** @ghidraAddress 0x132c4c */
                         }];
        return;
    }

    // An edit is loaded: show the fields fully, fade the edit buttons in, fill the fields from the
    // editor info, set the extend level image, and toggle the info button's tap feedback on the
    // download flag.
    self.isFirstSelect = NO;
    [self setStartButtonEnable];
    [editTxt[0] setAlpha:1.0];
    [editTxt[1] setAlpha:1.0];
    [editTxt[2] setAlpha:1.0];
    NSMutableDictionary *editorInfo = [manager getEditorInfo];
    int dlFlag = [editorInfo[@"dlFlag"] intValue];
    [UIView animateWithDuration:kResetTextFadeDuration
                     animations:^{
                       /** @ghidraAddress 0x132b48 */
                       [weakInfo setAlpha:1.0];
                       [weakUpload setAlpha:1.0];
                       [weakEdit setAlpha:1.0];
                     }
                     completion:^(BOOL finished){
                         /** @ghidraAddress 0x132d50 */
                     }];
    [editTxt[0] setText:editorInfo[@"fumenName"]];
    [editTxt[1] setText:editorInfo[@"editorName"]];
    [editTxt[2] setText:editorInfo[@"comment"]];
    int level = [editorInfo[@"level"] intValue];
    [levelNumView[kExtendButtonIndex] setImage:levelNumImg[level]];
    [levelNumView[kExtendButtonIndex] setAlpha:1.0];
    if (dlFlag == kEditDownloadFlag) {
        [infoBtn setAdjustsImageWhenHighlighted:NO];
        [infoBtn setAdjustsImageWhenDisabled:NO];
    } else {
        [infoBtn setAdjustsImageWhenHighlighted:YES];
        [infoBtn setAdjustsImageWhenDisabled:YES];
    }
}

/** @ghidraAddress 0x130bb0 */
- (void)difficultyChangeAnimation {
    int difficulty = (int)[NSUserDefaults.standardUserDefaults integerForKey:kPrefDifficultyKey];
    // Nudge the high-score text to the right and zero the board, then slide both home while the
    // difficulty change applies inside the animation.
    double baseX = self.isPad ? kHighscoreBaseXPad : kHighscoreBaseXPhone;
    double centerY = self.isPad ? kHighscoreCenterYPad : kHighscoreCenterYPhone;
    [highscoreTextView setCenter:CGPointMake(baseX + kHighscoreCenterXNudge, centerY)];
    [highscoreBoardView setAlpha:0.0];
    __weak MusicDetailViewRpl *weakSelf = self;
    UIImageView *textView = highscoreTextView;
    UIImageView *boardView = highscoreBoardView;
    [UIView animateWithDuration:kExtendModeAnimDuration
                     animations:^{
                       /** @ghidraAddress 0x130d18 */
                       [weakSelf changeDifficulty:difficulty];
                       MusicDetailViewRplRepositionHighscoreText(weakSelf, textView);
                       [boardView setAlpha:1.0];
                     }];
}

/** @ghidraAddress 0x130dc0 */
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

    __weak MusicDetailViewRpl *weakSelf = self;
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
                               /** @ghidraAddress 0x1315e4 */
                               [weakSelf changeDifficulty:current];
                               MusicDetailViewRplRepositionHighscoreBoard(weakSelf, boardView);
                               [boardView setAlpha:1.0];
                             }];
            inputLock = kSelectDiffExtendInputLock;
        }
        [[UIApplication sharedApplication] performSelector:@selector(endIgnoringInteractionEvents)
                                                withObject:nil
                                                afterDelay:inputLock];
        return;
    }

    // A different difficulty: reposition the high-score text, play the voice cue, persist the
    // choice, and slide the text into place.
    MusicDetailViewRplRepositionHighscoreText(self, highscoreTextView);
    [highscoreBoardView setAlpha:0.0];
    [[AudioManager sharedManager] playSeResFile:voiceCue inDirectory:nil];
    [NSUserDefaults.standardUserDefaults setInteger:tapped forKey:kPrefDifficultyKey];
    UIImageView *textView = highscoreTextView;
    UIImageView *boardView = highscoreBoardView;
    [UIView animateWithDuration:kExtendModeAnimDuration
                     animations:^{
                       /** @ghidraAddress 0x13153c */
                       [weakSelf changeDifficulty:tapped];
                       MusicDetailViewRplRepositionHighscoreText(weakSelf, textView);
                       [boardView setAlpha:1.0];
                     }];
    [[UIApplication sharedApplication] performSelector:@selector(endIgnoringInteractionEvents)
                                            withObject:nil
                                            afterDelay:kSelectDiffInputLock];
}

/** @ghidraAddress 0x134524 */
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

    __weak MusicDetailViewRpl *weakSelf = self;
    BOOL hasShareManager = (shareManager != nil);
    [UIView animateWithDuration:kStartPlayTransitionDuration
        delay:0.0
        options:UIViewAnimationOptionBeginFromCurrentState
        animations:^{
          /** @ghidraAddress 0x1349a0 */
          MusicDetailViewRplScaleOutUnselectedButtons(
              self->btnDiff, self->detailScrollButton, difficulty);
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x134c40 */
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

/** @ghidraAddress 0x133130 */
- (void)show:(BOOL)show {
    self.isShared = show;
    int difficulty = (int)[NSUserDefaults.standardUserDefaults integerForKey:kPrefDifficultyKey];
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
                            options:UIViewAnimationOptionRepeat |
                                    UIViewAnimationOptionAllowUserInteraction
                         animations:^{
                           /** @ghidraAddress 0x133aa4 */
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
                           /** @ghidraAddress 0x133b50 */
                           [weakDiffLamp setAlpha:0.0];
                           [weakDiffLamp
                               setTransform:CGAffineTransformMakeScale(1.0, kLampPulseHeightScale)];
                         }
                         completion:nil];
    }
    [self infoChange:difficulty];
}

/** @ghidraAddress 0x12f538 */
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
        [levelNumView[i] setImage:levelNumImg[level]];
    }

    // The current difficulty's hold mark drives the app hold flag (except on the edit page).
    BOOL holdHidden = holdMark[difficulty].isHidden;
    [JubeatAppDelegate.appDelegate setHoldFlag:(self.editPage != 1) && !holdHidden];
    [self refreshStartButton];
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

/** @ghidraAddress 0x135ab8 */
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

            __weak MusicDetailViewRpl *weakSelf = self;
            [UIView animateWithDuration:kHostShareStartFadeDuration
                animations:^{
                  /** @ghidraAddress 0x1360bc */
                  [weakSelf.labelShareMessage setAlpha:1.0];
                  [weakSelf.buttonHostSharePlay setEnabled:NO];
                }
                completion:^(BOOL finished) {
                  /** @ghidraAddress 0x1361a8 */
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
                     completion:^(BOOL finished){
                         /** @ghidraAddress 0x135548 */
                     }];
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
                     completion:^(BOOL finished){
                         /** @ghidraAddress 0x13669c */
                     }];
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
    MusicDetailViewRplSettleScrollPage(self, self->holdMark);
}

/** @ghidraAddress 0x136a80 */
- (void)scrollViewDidEndDecelerating:(nullable UIScrollView *)scrollView {
    MusicDetailViewRplSettleScrollPage(self, self->holdMark);
}

/** @ghidraAddress 0x136d54 */
- (void)scrollViewDidEndDragging:(nullable UIScrollView *)scrollView
                  willDecelerate:(BOOL)decelerate {
    if (!decelerate) {
        MusicDetailViewRplSettleScrollPage(self, self->holdMark);
    }
}

/** @ghidraAddress 0x137588 */
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
        [popover setSourceRect:btnDiff[kExtendButtonIndex].frame];
        [self.controller presentViewController:self.pFileListView animated:YES completion:nil];
    }
    [[AudioManager sharedManager] playSeResFile:kMusicSelectSound inDirectory:nil];
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
