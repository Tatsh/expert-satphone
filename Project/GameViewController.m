#import "GameViewController.h"

#import <GameKit/GameKit.h>
#import <Social/Social.h>

#import "AlertViewManager.h"
#import "AudioManager.h"
#import "BFCodec.h"
#import "CJSONSerializer.h"
#import "ChallengeStatus.h"
#import "Downloader.h"
#import "EAGLView.h"
#import "EditDataManager.h"
#import "EditorIDManager.h"
#import "EvaluateJcfView.h"
#import "GameNetworkUtil.h"
#import "GamePauseView.h"
#import "ImageLoading.h"
#import "JubeatAppDelegate.h"
#import "KUnzip.h"
#import "LabUtilities.h"
#import "MainGameRenderer.h"
#import "MainGameRendererKnt.h"
#import "MainGameRendererPad.h"
#import "MainGameRendererPadKnt.h"
#import "MainGameRendererPadRpl.h"
#import "MainGameRendererPhone.h"
#import "MainGameRendererPhoneKnt.h"
#import "MainGameRendererPhoneRpl.h"
#import "MainGameRendererRpl.h"
#import "NteGameOptionRenderer.h"
#import "RendererConf.h"
#import "ResultItemChance.h"
#import "ResultTweet.h"
#import "RootViewController.h"
#import "ScoreRecord.h"
#import "ScoreRecordManager.h"
#import "ScratchUtil.h"
#import "SearchPackIDView.h"
#import "Sequence.h"
#import "SessionDownloader.h"
#import "SharePlayManager.h"
#import "StoreMusicListManager.h"
#import "TuneInfo.h"
#import "jubeatLabAccess.h"
#import "packed_bit_table.h"

// The current-theme values read from JubeatAppDelegate: 1 is REFLEC BEAT (Rpl), 2 is Konami (Knt),
// and 0 (the default) is the standard theme.
enum {
    kGameThemeDefault = 0, // The standard theme.
    kGameThemeRpl = 1,     // The REFLEC BEAT theme.
    kGameThemeKnt = 2,     // The Konami theme.
};

// The renderer play-state values read from and written to the renderer's -state.
enum {
    kRendererStateNone = 0,       // No active play.
    kRendererStateReady = 1,      // Ready to begin play.
    kRendererStateStarting = 2,   // Waiting for the ready-go window before playing.
    kRendererStatePlaying = 3,    // Playing.
    kRendererStateEnding = 4,     // Ending; waiting to finish.
    kRendererStateEnded = 5,      // Ended; result shown.
    kRendererStateItemChance = 6, // Challenge item-chance overlay shown.
};

// The renderer sub-state sentinels the session state machine waits on.
enum {
    kRendererSubStateSessionWait = 20, // Waiting for the session partner (0x14).
    kRendererSubStateReadyGo = 30,     // Playing the ready-go animation (0x1e).
};

// The device-type values whose renderer overlays use an enlarged display scale.
enum {
    kDeviceTypeRetinaLow = 3,    // The first enlarged-scale device.
    kDeviceTypeRetinaHigh = 4,   // The second enlarged-scale device.
    kDeviceTypeLargestPhone = 5, // The largest-scale device.
};

// The play-time-to-sector conversion factor: the sequence advances 300 sectors per second.
// @ghidraAddress 0x28e010
static const float kSectorsPerSecond = 300.0f;

// The button-touch-width unit: the saved 0..1 button-width preference scales this pixel span.
static const float kButtonTouchWidthUnit = 20.0f;

// The evaluate-overlay fade-out animation duration.
// @ghidraAddress 0x28e050
static const double kEvaluateFadeDuration = -0.2;

// The seconds-to-nanoseconds factor for the session play-start dispatch delay.
// @ghidraAddress 0x28e058
static const double kNanosecondsPerSecond = 1000000000.0;

// The pack-ID search overlay fade-out animation duration.
// @ghidraAddress 0x28e040
static const double kPackIDSearchFadeDuration = 0.2;

// The default and enlarged renderer-overlay display scales, selected by device type.
static const float kDisplayScaleDefault = 1.0f;         // 0x3f800000
static const float kDisplayScaleLargePhone = 1.171875f; // 0x3f960000 (device types 3 and 4)
static const float kDisplayScaleLargestPhone = 1.2937500476837158f; // 0x3fa5999a (device type 5)

// The phone-idiom pause-button nudge: 4pt in from the right and 4pt up from the top.
static const double kPauseButtonPhoneXOffset = 4.0; // A phone-only fmov immediate.
static const double kPauseButtonPhoneY = -4.0;      // A phone-only fmov immediate.

// The 2D projection space dimensions, in points, by idiom and aspect.
static const double k2dSpacePadWidth = 768.0;        // @ghidraAddress 0x28e090
static const double k2dSpacePadHeight = 1024.0;      // @ghidraAddress 0x28e028
static const double k2dSpacePhoneWidth = 320.0;      // @ghidraAddress 0x28e098
static const double k2dSpacePhoneHeight = 480.0;     // @ghidraAddress 0x28e020
static const double k2dSpacePhoneHeightWide = 568.0; // @ghidraAddress 0x28dfd8

// The double-tap auto-play catcher overlay edge, in points, by idiom.
static const double kAutoSwitchSizePhone = 100.0; // @ghidraAddress 0x28e0a0
static const double kAutoSwitchSizePad = 200.0;   // @ghidraAddress 0x28e0a8

// The trailing tail length dropped from the tune's music archive.
static const NSUInteger kMusicArchiveTailLength = 16;

// The PrefEditSelect value that selects a custom (editor) chart.
enum { kEditSelectCustom = 1 };

// The number of taps that toggles auto-play on the catcher overlay.
enum { kTapCountAutoSwitch = 2 };

// The chart-archive member names uncompressed from the KUnzip container.
static NSString *const kArchiveMarkerMember = @"marker";
static NSString *const kArchiveBgmMember = @"bgm";
static NSString *const kArchiveArtworkMember = @"artwork";
static NSString *const kArchiveNameBMember =
    @"name_b"; // @ghidraAddress 0x2d4b40 / index for RPL, KNT
static NSString *const kArchiveNameWMember = @"name_w"; // index for the default theme

// The theme-specific pause-button, replay-button, and sequence resource names.
static NSString *const kImagePauseRpl = @"pause_btn_pause_rpl"; // @ghidraAddress 0x2d49a0
static NSString *const kImagePauseKnt = @"pause_btn_pause_knt"; // @ghidraAddress 0x2d49c0
static NSString *const kImagePauseDefault = @"pause_btn_pause"; // @ghidraAddress 0x2d49e0
static NSString *const kImageReplayRpl = @"replay_btn_rpl";     // @ghidraAddress 0x2d4a00
static NSString *const kImageReplayKnt = @"replay_btn_knt";     // @ghidraAddress 0x2d4a20
static NSString *const kImageReplayDefault = @"replay_btn";     // @ghidraAddress 0x2d4a40
static NSString *const kArchiveSeqAdvMember = @"seq_adv";       // @ghidraAddress 0x2d4a60
static NSString *const kArchiveSeqExtMember = @"seq_ext";       // @ghidraAddress 0x2d4a80
static NSString *const kArchiveSeqBasMember = @"seq_bas";       // @ghidraAddress 0x2d4aa0

// The Game Center leaderboard-score reporting completion handler ignores its error.
// @ghidraAddress 0x16eb0
static void GameViewControllerReportScoreNoopHandler(NSError *_Nullable error) {
    /** @ghidraAddress 0x16eb0 */
    (void)error;
}

// The theme-prefixed sound-effect name formats consumed by -soundName:.
static NSString *const kSoundNameFormatRpl = @"SD_RPL_%@"; // @ghidraAddress 0x2d4940
static NSString *const kSoundNameFormatKnt = @"SD_KNT_%@"; // @ghidraAddress 0x2d4960
static NSString *const kSoundNameFormatDefault = @"SD_%@"; // @ghidraAddress 0x2d4980

// The pause / replay-pause menu sound-effect base name.
static NSString *const kPauseSoundName = @"SKIP"; // @ghidraAddress 0x2d4e80

// The BGM-finished notification observed while a chart is playing.
static NSString *const kFinishBgmNotificationName = @"JubeatAudioManagerFinishBgmNotifacation";

// The documents subdirectory holding replay ghost recordings.
static NSString *const kGhostDirName = @"ghost"; // @ghidraAddress 0x2d5000

// The user-defaults keys read at play start.
static NSString *const kPrefAdjustSector = @"PrefAdjustSector";
static NSString *const kPrefShowCombo = @"PrefShowCombo";
static NSString *const kPrefButtonWidth = @"PrefButtonWidth";
static NSString *const kPrefEditSelect = @"PrefEditSelect";

// The stealth marker id whose selection hides the falling markers.
static NSString *const kStealthMarkerID = @"mk0025";

// The editor-info and score-data dictionary keys.
static NSString *const kEditorInfoLevelKey = @"level";
static NSString *const kEditorInfoDlFlagKey = @"dlFlag";
static NSString *const kEditorInfoSequenceIDKey = @"sequenceID";
static NSString *const kEditorInfoGoodJobSendKey = @"goodJobSend";
static NSString *const kScoreDataBestScoreKey = @"bestScore";

// The alert result dictionary keys echoed back through -alertSelect:.
static NSString *const kAlertButtonMessageKey = @"btnMessage";
static NSString *const kAlertTagKey = @"Tag";

// The alert-button positive-message value and the -alertSelect: tag values.
enum {
    kAlertButtonOK = 1,     // The positive (confirm) button.
    kAlertTagChallenge = 1, // The challenge-mode result alert.
    kAlertTagEnd = 2,       // The end-play confirmation alert.
};

// The alert-type values passed as the first makeAlert: argument.
enum { kAlertTypePlain = 0 };

// The end-play confirmation alert strings shown in challenge mode.
static NSString *const kEndAlertTitle =
    @"中断するとランキングへの登録、リザルトドロップが発生しませんが本当に中断しますか？";
// @ghidraAddress 0x2d4ea0
static NSString *const kEndAlertCancel = @"いいえ"; // @ghidraAddress 0x2d4ec0
static NSString *const kEndAlertConfirm = @"はい";  // @ghidraAddress 0x2d4ee0

// The item-chance sentinel that marks "no chance item".
enum { kChanceItemTypeNone = -1 };

// The number of playfield panels (a 4x4 grid), sizing the per-panel state arrays.
enum { kGamePanelCount = 16 };

// The per-idiom pixel offsets added to a renderer button position, in points.
static const double kButtonCenterXOffsetPad = 2.0;   // An fmov immediate.
static const double kButtonCenterXOffsetPhone = 1.0; // An fmov immediate.
static const double kButtonCenterYOffsetPad = 10.0;  // An fmov immediate.
static const double kButtonCenterYOffsetPhone = 4.0; // An fmov immediate.

// The good-job / share overlay's maximum alpha reported to the renderer.
static const float kGoodJobAlphaMax = 1.0f; // An fmov immediate.

// The good-job button image resource names.
static NSString *const kImageGoodJobButton = @"btn_goodjob";        // @ghidraAddress 0x2d4f00
static NSString *const kImageGoodJobString = @"btn_goodjob_string"; // @ghidraAddress 0x2d4f20

// The Twitter share button image names, by theme.
static NSString *const kImageTwitterRpl = @"game_twitter_rpl"; // @ghidraAddress 0x2d4f40
static NSString *const kImageTwitterKnt = @"game_twitter_knt"; // @ghidraAddress 0x2d4f60
static NSString *const kImageTwitterDefault = @"game_twitter"; // @ghidraAddress 0x2d4f80

// The store-move search button image names, by theme.
static NSString *const kImageSearchRpl = @"result_jbt_rpl"; // @ghidraAddress 0x2d4fa0
static NSString *const kImageSearchKnt = @"result_jbt_knt"; // @ghidraAddress 0x2d4fc0
static NSString *const kImageSearchDefault = @"result_jbt"; // @ghidraAddress 0x2d4fe0

// The number of trailing characters dropped from an edit file name to derive its sequence id.
enum { kEditFileNameSuffixLength = 4 };

// The good-job label's animation transform scales and per-idiom vertical offsets, in points.
static const double kGoodJobTxtInitialScale = 0.8;   // @ghidraAddress 0x28e060
static const double kGoodJobTxtFadeScale = 0.9;      // @ghidraAddress 0x28e070
static const double kGoodJobTxtInitialYPad = 20.0;   // An fmov immediate.
static const double kGoodJobTxtInitialYPhone = 10.0; // An fmov immediate.
static const double kGoodJobTxtRiseYPad = -50.0;     // @ghidraAddress 0x28e068
static const double kGoodJobTxtRiseYPhone = -20.0;   // An fmov immediate.
static const double kGoodJobTxtFadeYPad = -40.0;     // @ghidraAddress 0x28e078
static const double kGoodJobTxtFadeYPhone = -18.0;   // An fmov immediate.

// The good-job animation stage durations and the button's final resting alpha.
static const double kGoodJobRiseDuration = 0.2;                // @ghidraAddress 0x28e040
static const double kGoodJobFadeDuration = 0.8;                // @ghidraAddress 0x28e060
static const double kGoodJobBtnFadeDuration = 0.2;             // @ghidraAddress 0x28e040
static const float kGoodJobBtnFinalAlpha = 0.800000011920929f; // @ghidraAddress 0x28e080

// The label's centre within its parent button, expressed as the button's half extent.
static const float kGoodJobTxtCenterFactor = 0.5f; // An fmov immediate.

// The difficulty values read from -currentDiff.
enum {
    kGameDifficultyBasic = 0,    // The basic chart.
    kGameDifficultyAdvanced = 1, // The advanced chart.
    kGameDifficultyExtreme = 2,  // The extreme chart.
    kGameDifficultyCustom = 3,   // A custom (editor) chart.
};

// The result-screen music bar: 120 two-bit segments packed into 30 bytes.
enum {
    kMusicBarEntryCount = 120, // @ghidraAddress 0x12718
    kMusicBarByteLength = 30,  // @ghidraAddress 0x124d4
};

// The challenge-score upload tags.
enum {
    kDownloaderTagChallengeScore = 2, // @ghidraAddress 0x1d424 (Downloader -tag)
    kApiTagSendMusicScore = 8,        // @ghidraAddress 0x1d438 (SessionDownloader -apiTag)
};

// The server status codes handled in -downloaderFinished:.
enum {
    kServerStatusItemChanceOK = 0x31aed,   // @ghidraAddress 0x1b110
    kServerStatusUpdateRequired = 0x186ab, // @ghidraAddress 0x1b0b0
    kServerStatusServerError = 0x18b53,    // @ghidraAddress 0x1b0a0
};

// The alert tags used by the challenge-score download callbacks.
enum {
    kRetrySendAlertTag = 1,      // @ghidraAddress 0x1b490 (retry score send)
    kServerErrorAlertTag = 9999, // @ghidraAddress 0x1b2f8 (server-error notice)
};

// The download-response dictionary keys.
static NSString *const kResponseStatusKey = @"status";
static NSString *const kResponseErrorMessageKey = @"err_message";
static NSString *const kResponseItemTypeKey = @"item_type";
static NSString *const kResponseItemNumKey = @"item_num";

// The challenge-score request parameter keys.
static NSString *const kScorePostScratchIDKey = @"scratch_id";
static NSString *const kScorePostSessionSeedKey = @"session_seed";
static NSString *const kScorePostMusicIDKey = @"music_id";
static NSString *const kScorePostScoreKey = @"score";
static NSString *const kScorePostDifficultyKey = @"difficulty";
static NSString *const kScorePostIsFullComboKey = @"is_fullcombo";

// The localised alert-string keys and the retry-send alert strings.
static NSString *const kLocalizedServerErrorMsgKey = @"ServerErrorMsg";
static NSString *const kLocalizedOKKey = @"OK";
static NSString *const kEmptyLocalizedValue = @"";
static NSString *const kRetrySendMessage = @"スコアを送信できませんでした。再度通信を行いますか？";
static NSString *const kAlertYes = @"はい";
static NSString *const kAlertNo = @"いいえ";
static NSString *const kAlertOK = @"OK";

@interface GameViewController () {
@public
    BOOL isPad;                                // Whether the device is a pad idiom.
    BOOL isSession;                            // Whether a local-multiplayer session is active.
    BOOL scoreSaved;                           // Whether the play's score has been persisted.
    BOOL isCustom;                             // Whether the chart is a custom (editor) chart.
    BOOL isDownload;                           // Whether the chart was downloaded.
    BOOL hasMusic;                             // Whether the tune's music is available.
    double music_time;                         // The last computed music time.
    BOOL isMusicPlaying;                       // Whether BGM is currently playing.
    float buttonTouchWidth;                    // The half-width used for panel hit-testing.
    unsigned int buttonDown;                   // The panels that went down this frame.
    unsigned int buttonUp;                     // The panels that went up this frame.
    unsigned int buttonPress;                  // The panels held this frame.
    unsigned int buttonPressOld;               // The panels held last frame.
    unsigned int draw_count;                   // The frame counter used to compute fps.
    double past_time;                          // The timestamp of the last fps sample.
    float fps;                                 // The measured frames per second.
    int oldBestScore;                          // The best score before this play.
    SearchPackIDView *packSearchView;          // The pack-ID search overlay.
    UIView *coverView;                         // The dimming cover behind an overlay.
    EvaluateJcfView *evaluateView;             // The chart-evaluation overlay.
    jubeatLabAccess *playCountAccess;          // The pending play-count report.
    BOOL bGoodJobPress;                        // Whether the good-job vote has been cast.
    jubeatLabAccess *goodJobCommit;            // The pending good-job commit.
    RendererConf *confBak;                     // The renderer configuration used to build textures.
    UIImage *indexWBak;                        // The white index texture backup.
    UIImage *indexBBak;                        // The black index texture backup.
    BOOL bIsOpenSocialSend;                    // Whether a social-send sheet is open.
    Downloader *scoreUploader;                 // The challenge-score upload request.
    EditorIDManager *idManager;                // The editor-ID download manager.
    BOOL bBuildAutoFlag;                       // Whether the auto-play table has been built.
    BOOL isAuto;                               // Whether auto-play is enabled.
    UIView *autoSwitch;                        // The double-tap surface toggling auto-play.
    int currentTouchIndex;                     // The next debug-touch table index.
    NSArray *debugTouchTable;                  // The per-frame recorded touch table.
    int currentPressIndex;                     // The next debug-press table index.
    NSArray *debugPressTable;                  // The per-frame recorded press table.
    float adjustTime;                          // The play-time offset in seconds.
    BOOL bRestartFlag;                         // Whether a restart is pending.
    float displayScale;                        // The renderer-overlay display scale.
    ResultItemChance *itemChanceRender;        // The challenge item-chance renderer.
    BOOL bItemChance;                          // Whether an item-chance is active.
    int chanceItemType;                        // The active chance-item type.
    int chanceItemNum;                         // The active chance-item count.
    NSMutableArray *ghostJudgeTable;           // The recorded ghost judgements.
    NSMutableArray *ghostRecTouches;           // The recording ghost-touch table.
    NSArray *ghostPlayTouches;                 // The replay ghost-touch table.
    unsigned int startSector[kGamePanelCount]; // The per-panel play-start sectors.
    int currentGhostIndex;                     // The next ghost-touch frame index.
    BOOL bEnableGhost;                         // Whether ghost recording is enabled.
    unsigned int ghostDown;                    // The ghost panels that went down this frame.
    unsigned int ghostUp;                      // The ghost panels that went up this frame.
    BOOL nowReplaying;                         // Whether a replay is in progress.
    NSData *bgmData;                           // The decrypted BGM data for replay.
    UIButton *btnReplay;                       // The replay button.
    UIButton *btnReplayPause;                  // The replay-mode pause button.
    NteGameOptionRenderer *nteRender;          // The Naga-Cora option overlay renderer.
}
@end

// The music-time to sector conversion: the sequence advances 30 frames per second, each subdivided
// into 10 sectors.
static const double kSectorFramesPerSecond = 30.0; // An fmov immediate.
static const double kSectorSubdivision = 10.0;     // An fmov immediate.

// The 4x4 panel grid geometry.
enum { kPanelColumns = 4 };

// The per-idiom panel metrics, in pixels: the square panel edge and the top offset to the first
// panel row.
enum {
    kPanelWidthPad = 192,    // @ghidraAddress 0x1b7e0
    kPanelYOffsetPad = 256,  // @ghidraAddress 0x1b7e8
    kPanelWidthPhone = 80,   // @ghidraAddress 0x1b860
    kPanelYOffsetPhone = 160 // @ghidraAddress 0x1b874
};

// The judgement windows in sectors.
enum {
    kTouchHoldWindowSectors = 100,   // @ghidraAddress 0x1c114
    kPressReleaseMarginSectors = 10, // @ghidraAddress 0x1c388
};

// The replay-delay randomisation buckets.
enum {
    kDelaySectorProbabilityRange = 50,
    kDelaySectorStep = 10,
};

// The pad-idiom panel hit-test grid: panels are 0xc0 apart with an 8pt inset; the row origin adds
// 256pt and every panel rect is a fixed 176pt square.
enum {
    kHitTestPadPanelPitch = 0xc0, // @ghidraAddress 0x132b0 (192pt panel pitch)
    kHitTestPadPanelInset = 8,    // @ghidraAddress 0x133b8 (orr #0x8)
};
static const double kHitTestPadRowOriginY = 256.0; // @ghidraAddress 0x28e030
static const double kHitTestPadSide = 176.0;       // @ghidraAddress 0x28e038

// The phone-idiom panel hit-test grid: 0x50 (80pt) panels widened by the button-touch width; the
// row origin adds 160pt and the rect side is 2*touchWidth + 80pt.
enum { kHitTestPhonePanelPitch = 0x50 };
static const float kHitTestPhoneRowOriginY = 160.0; // @ghidraAddress 0x28e014
static const float kHitTestPhoneSideBase = 80.0;    // @ghidraAddress 0x28e018

// The playback catch-up step, in seconds, applied when following without live BGM.
static const double kPlaybackCatchupStep = 0.03333333333333333; // @ghidraAddress 0x28e048

// The renderer sub-state that gates each play-state transition in -loop:.
enum { kRendererSubStateReady = 10 };

// The result-screen fade-out cover alpha (half-transparent black).
static const double kResultCoverAlpha = 0.5; // An fmov immediate (0x3fe0000000000000).

// The session score-send cadence masks: the host sends on frame&0xf==0, the client on ==8.
enum {
    kSessionSendFrameMask = 0xf,
    kSessionSendFrameHost = 0,
    kSessionSendFrameClient = 8,
};

// The fps sample window: fps is recomputed every 8 frames as 8 / elapsed seconds.
enum { kFpsSampleFrameMask = 7 };
static const double kFpsSampleFrameCount = 8.0;

// The 4x4 panel grid column count and mask for the hit-test loop.
enum { kHitTestColumnMask = 3 };

// The end-of-play score-submission dictionary keys and difficulty labels.
static NSString *const kScoreJsonTargetKey = @"target";         // @ghidraAddress 0x2d4ca0
static NSString *const kScoreJsonUserIDKey = @"user_id";        // @ghidraAddress 0x2d4cc0
static NSString *const kScoreJsonUUIDKey = @"uuid";             // @ghidraAddress 0x2d41a0
static NSString *const kScoreJsonMusicIDKey = @"music_id";      // @ghidraAddress 0x2d4ce0
static NSString *const kScoreJsonDifficultyKey = @"difficulty"; // @ghidraAddress 0x2d4d20
static NSString *const kScoreJsonScoreKey = @"score";           // @ghidraAddress 0x2d4d40
static NSString *const kDifficultyLabelBas = @"bas";            // @ghidraAddress 0x2d4c20
static NSString *const kDifficultyLabelAdv = @"adv";            // @ghidraAddress 0x2d4c40
static NSString *const kDifficultyLabelExt = @"ext";            // @ghidraAddress 0x2d4c60
static NSString *const kDifficultyLabelCus = @"cus";            // @ghidraAddress 0x2d4c80
static NSString *const kIntegerFormat = @"%d";                  // @ghidraAddress 0x2d4d00

// The client-info dictionary uuid key.
static NSString *const kClientInfoUUIDKey = @"uuid"; // @ghidraAddress 0x2d41a0

// The good-job sound-effect name format, seeded with a random index.
static NSString *const kGoodJobSoundFormat = @"SD_EEFMN_0%d"; // @ghidraAddress 0x2d5920

// The result-screen overlay fade-in duration.
static const double kResultOverlayFadeDuration = 0.2; // @ghidraAddress 0x28e040

// The edit-score upload Downloader tag.
enum { kScoreUploaderTag = 1 };

// The result-screen "decide" menu sound-effect base name.
static NSString *const kDecideSoundName = @"OK"; // @ghidraAddress 0x2d4d80

// The result-share tweet message format (tune name, score, and the App Store URL) and the URL.
static NSString *const kTweetMessageFormat =
    @"%@をプレー！ Score:%d #jubeat_plus %@"; // @ghidraAddress 0x2d4e20
static NSString *const kTweetURL =
    @"https://itunes.apple.com/jp/app/jubeat-plus/id395192484"; // @ghidraAddress 0x2d4e00

// The number of good-job sound-effect variants selected at random.
enum { kGoodJobSoundVariantCount = 5 };

// The JCF-download preference and its post-play default in extreme difficulty.
static NSString *const kPrefJcfDownloadSelect = @"PrefJcfDownloadSelect";

// The music-bar / score-data field the session host and client exchange.
// (ScoreData +0x20 is displayed score, +0x24 the final bonus.)

// The current music position in sectors.
static inline int GameViewControllerNowSector(GameViewController *self) {
    return (int)([self getMusicTime] * kSectorFramesPerSecond * kSectorSubdivision);
}

// Tests whether a touch point (already converted into the GL view's coordinate space and divided by
// the display scale) lies within panel index's hit rectangle, and if so marks that panel in
// buttonPress. The rectangle differs per idiom: the pad uses a fixed 0xc0 grid with an 8pt inset,
// the phone a 0x50 grid widened by buttonTouchWidth (and a 4-inch top margin from the renderer).
static inline void GameViewControllerHitTestPanels(GameViewController *self, CGPoint pointInView) {
    float scale = self->displayScale;
    CGFloat px = pointInView.x / scale;
    CGFloat py = pointInView.y / scale;
    for (unsigned int panel = 0; panel < kGamePanelCount; ++panel) {
        int adjusted = ((int)panel < 0) ? ((int)panel + 3) : (int)panel;
        int column = (int)panel - (adjusted & ~kHitTestColumnMask);
        int row = adjusted >> 2;
        CGFloat rx;
        CGFloat ry;
        CGFloat side;
        if (self->isPad) {
            rx = (double)(column * kHitTestPadPanelPitch | kHitTestPadPanelInset);
            ry = (double)(row * kHitTestPadPanelPitch | kHitTestPadPanelInset) +
                 kHitTestPadRowOriginY;
            side = kHitTestPadSide;
        } else {
            int margin = 0;
            if ([[JubeatAppDelegate appDelegate] is4inchAspect]) {
                margin = [self.mainGameRenderer buttonMarginForScreen40];
            }
            float touchWidth = self->buttonTouchWidth;
            rx = (float)(column * kHitTestPhonePanelPitch) - touchWidth;
            ry = (float)margin + ((float)(row * kHitTestPhonePanelPitch) - touchWidth) +
                 kHitTestPhoneRowOriginY;
            side = touchWidth + touchWidth + kHitTestPhoneSideBase;
        }
        if ([self.mainGameRenderer state] == kRendererStateEnded) {
            ry += [self.mainGameRenderer buttonAreaOffset];
        }
        if (CGRectContainsPoint(CGRectMake(rx, ry, side, side), CGPointMake(px, py))) {
            self->buttonPress |= 1u << (panel & 0x1f);
        }
    }
}

// The panel metrics for the current device idiom (three arms: pad, 4-inch phone, other phone).
static inline void
GameViewControllerPanelMetrics(GameViewController *self, int *outWidth, int *outYOffset) {
    if (self->isPad) {
        *outWidth = kPanelWidthPad;
        *outYOffset = kPanelYOffsetPad;
    } else if ([[JubeatAppDelegate appDelegate] is4inchAspect]) {
        *outWidth = kPanelWidthPhone;
        *outYOffset = [self.mainGameRenderer buttonMarginForScreen40] + kPanelYOffsetPhone;
    } else {
        *outWidth = kPanelWidthPhone;
        *outYOffset = kPanelYOffsetPhone;
    }
}

// The pixel centre of a panel index within the grid.
static inline void
GameViewControllerPanelCenter(int panel, int panelWidth, int yOffset, float *outX, float *outY) {
    int halfWidth = panelWidth >> 1;
    int row = (panel < 0) ? (panel + 3) : panel;
    *outX = (float)(halfWidth + (panel % kPanelColumns) * panelWidth);
    *outY = (float)(halfWidth + yOffset + (row >> 2) * panelWidth);
}

// Loads the theme-appropriate scaled PNG for a resource whose name varies by theme.
static inline UIImage *
GameViewControllerThemeImage(unsigned int theme, NSString *rpl, NSString *knt, NSString *dflt) {
    if (theme == kGameThemeRpl) {
        return LoadScaledPngImage(rpl);
    }
    if (theme == kGameThemeKnt) {
        return LoadScaledPngImage(knt);
    }
    return LoadScaledPngImage(dflt);
}

// The screen centre for a renderer button position, scaled by the display scale and nudged by the
// per-idiom offsets. Shared by the good-job, Twitter, and search button builders.
static inline CGPoint GameViewControllerButtonCenter(GameViewController *self, CGPoint position) {
    float scale = self->displayScale;
    CGFloat x =
        position.x * scale + (self->isPad ? kButtonCenterXOffsetPad : kButtonCenterXOffsetPhone);
    CGFloat y =
        position.y * scale + (self->isPad ? kButtonCenterYOffsetPad : kButtonCenterYOffsetPhone);
    return CGPointMake(x, y);
}

// Installs a share-style button image view into the view at a scaled centre and reports it to the
// renderer. Shared by the Twitter and search button builders.
static inline UIImageView *
GameViewControllerAddScaledButton(GameViewController *self, UIImage *image, CGPoint center) {
    float scale = self->displayScale;
    UIImageView *view =
        [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, image.size.width, image.size.height)];
    view.image = image;
    view.center = center;
    view.alpha = 0.0;
    view.transform = CGAffineTransformScale(view.transform, scale, scale);
    [self.view addSubview:view];
    [self.mainGameRenderer setGoodJobImage:view];
    [self.mainGameRenderer setGoodJobAlphaMax:kGoodJobAlphaMax];
    return view;
}

// Deciphers a named archive member into a UIImage, returning nil when the member is missing or the
// decipher fails. Repeated four times over the artwork and index textures in -loadResources.
static inline UIImage *GameViewControllerDecipherImage(BFCodec *codec,
                                                       KUnzip *archive,
                                                       NSData *cipherKey,
                                                       NSString *member) {
    [codec cipherInit:cipherKey];
    NSData *data = [archive uncompress:member];
    if (data != nil && [codec decipher:data]) {
        return [[UIImage alloc] initWithData:data];
    }
    return nil;
}

// Merges the existing per-bar result blob with the just-played score's bars, keeping the higher
// grade per segment, into the packed two-bit output table. Repeated verbatim once per difficulty in
// -saveScore. A zero sequence grade is treated as the lowest (3) tier, matching the binary.
static inline void GameViewControllerMergeMusicBar(NSData *existingBlob,
                                                   const ScoreData *score,
                                                   unsigned char outTable[kMusicBarByteLength]) {
    const char *blob = existingBlob.bytes;
    const char *bars = score->musicBarResult;
    for (unsigned int i = 0; i < kMusicBarEntryCount; ++i) {
        unsigned int byteIndex = i >> 2;
        unsigned int shift = (i & 3) * 2;
        unsigned int existingValue = (blob[byteIndex] >> shift) & 3;
        int rawSequence = bars[byteIndex] >> shift;
        unsigned int sequenceValue = (rawSequence & 3) != 0 ? (unsigned int)(rawSequence & 3) : 3;
        unsigned int merged = sequenceValue > existingValue ? sequenceValue : existingValue;
        SetPackedTwoBitValue(outTable, i, merged);
    }
}

// Reports the accumulated total score to the Game Center leaderboard when authenticated. Shared by
// -pushBtnReplay: and the two -loop: end-of-play arms.
static inline void GameViewControllerReportTotalScore(GameViewController *self) {
    if (![[JubeatAppDelegate appDelegate] gameCenterAvailable] ||
        ![[GKLocalPlayer localPlayer] isAuthenticated]) {
        return;
    }
    NSString *category = [[JubeatAppDelegate appDelegate] totalScoreLeaderboardCategory];
    GKScore *score = [[GKScore alloc] initWithLeaderboardIdentifier:category];
    score.value = [ScoreRecord totalScore];
    [GKScore reportScores:@[ score ]
        withCompletionHandler:^(NSError *_Nullable error) {
          /** @ghidraAddress 0x16084 */
          (void)error;
        }];
}

// Persists the score at the end of play, reporting to Game Center or the editor. Shared by the two
// -loop: end-of-play arms.
static inline void GameViewControllerSaveAndReportScore(GameViewController *self) {
    if (!self->scoreSaved) {
        return;
    }
    if (!self->isCustom) {
        [self saveScore];
        GameViewControllerReportTotalScore(self);
    } else {
        EditDataManager *editManager = [EditDataManager sharedManager];
        int totalPoint = self.sequence.getScore->totalPoint;
        BOOL fullCombo = self.sequence.isFullcombo;
        [editManager scoreUpdate:totalPoint fullCombo:fullCombo tuneID:self.currentTune.tuneID];
    }
}

// Uploads the finished play's score as a JSON payload when it was played with an editor ID.
// Factored out of -loop: state 3 (playing → ending transition).
static inline void GameViewControllerSubmitEditScore(GameViewController *self) {
    NSDictionary *clientInfo = [JubeatAppDelegate clientInfo];
    unsigned int difficulty = self.currentDiff;
    BOOL isCustom = self->isCustom;
    NSArray *difficultyLabels =
        @[ kDifficultyLabelBas, kDifficultyLabelAdv, kDifficultyLabelExt, kDifficultyLabelCus ];
    NSString *musicIDString = [NSString stringWithFormat:kIntegerFormat, self.currentTune.tuneID];
    NSString *difficultyLabel =
        difficultyLabels[isCustom ? kGameDifficultyCustom : (int)difficulty];
    NSString *scoreString =
        [NSString stringWithFormat:kIntegerFormat, self.sequence.getScore->totalPoint];
    NSDictionary *payload = @{
        kScoreJsonTargetKey : [GameNetworkUtil getStoreTarget],
        kScoreJsonUserIDKey : [EditorIDManager getKeyString:[EditorIDManager getEditorIDKey]],
        kScoreJsonUUIDKey : clientInfo[kClientInfoUUIDKey],
        kScoreJsonMusicIDKey : musicIDString,
        kScoreJsonDifficultyKey : difficultyLabel,
        kScoreJsonScoreKey : scoreString,
    };
    NSData *json = [[CJSONSerializer serializer] serializeDictionary:payload error:nil];
    self->scoreUploader = [[Downloader alloc] initWithURL:[GameNetworkUtil scoreSendURL]
                                                 postData:json
                                                 delegate:self];
    self->scoreUploader.tag = kScoreUploaderTag;
    [self->scoreUploader startDownloading];
}

// Handles the play's transition into the ended state: stops BGM, records the play, applies the new
// record flag, submits the challenge score, builds the result buttons, and either shows the result
// or reports the final score to the session partner. Factored out of -loop: state 4.
static inline void GameViewControllerHandleEndingState(GameViewController *self,
                                                       AudioManager *audio) {
    if ([self.mainGameRenderer subState] != kRendererSubStateReady) {
        return;
    }
    if ([self->ghostRecTouches count] != 0) {
        if (![[JubeatAppDelegate appDelegate] bChallengeMode] && !self->isSession) {
            [self->btnReplayPause setHidden:YES];
            [self->btnReplay setHidden:NO];
        }
    }
    [self.mainGameRenderer replayEnd];
    if ([audio bgmPlaying]) {
        [audio stopBgm];
    }
    if (self->bBuildAutoFlag) {
        self->scoreSaved = NO;
    }
    self->isMusicPlaying = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kFinishBgmNotificationName
                                                  object:nil];
    [self requestAddPlayCount];

    if (self->scoreSaved) {
        int totalPoint = self.sequence.getScore->totalPoint;
        if (self->oldBestScore < totalPoint) {
            [self.mainGameRenderer setIsNewRecord:YES];
            int baseline = self->oldBestScore < 0 ? 0 : self->oldBestScore;
            [self.mainGameRenderer setScoreRecord:self.sequence.getScore->totalPoint - baseline];
        } else {
            [self.mainGameRenderer setIsNewRecord:NO];
        }
    }

    if ([[JubeatAppDelegate appDelegate] bChallengeMode]) {
        [self sendChallengeScore];
    }
    if (self->isCustom && self->isDownload && self->hasMusic) {
        [self createGoodJobBtn];
    }
    if (self->scoreSaved) {
        [self createTwitterBtn];
    }
    if (self->isSession && !self->hasMusic) {
        [self createSearchBtn];
    }

    if (self.shareManager == nil) {
        [self.mainGameRenderer setState:kRendererStateEnded];
        NSInteger jcfSelect =
            [NSUserDefaults.standardUserDefaults integerForKey:kPrefJcfDownloadSelect];
        if (jcfSelect == 0 && self.currentDiff == kGameDifficultyExtreme) {
            [NSUserDefaults.standardUserDefaults setInteger:1 forKey:kPrefJcfDownloadSelect];
        }
    } else {
        [self.mainGameRenderer setSubState:kRendererSubStateSessionWait];
        unsigned int point = self.sequence.getScore->point;
        unsigned int bonus = self.sequence.getScore->bonusPoint;
        BOOL fullCombo = self.sequence.isFullcombo;
        [self.shareManager sendFinalScore:point bonus:bonus fullCombo:fullCombo];
    }
}

// Handles the ended (result-screen) state: the end / twitter / evaluate / good-job / store-move
// button reactions. Factored out of -loop: state 5.
static inline void GameViewControllerHandleEndedState(GameViewController *self,
                                                      AudioManager *audio) {
    // End button.
    if ([self.mainGameRenderer subState] == kRendererSubStateReady) {
        unsigned int endButton = 1u << ([self.mainGameRenderer endButtonID] & 0x1f);
        if ((endButton & self->buttonUp) != 0 && !self->bIsOpenSocialSend) {
            if (![[JubeatAppDelegate appDelegate] bChallengeMode]) {
                [self.shareManager disconnect];
                self.shareManager = nil;
                [audio playSeResFile:[self soundName:kDecideSoundName] inDirectory:nil];
                [audio fadeoutBgm:1.0];
                GameViewControllerSaveAndReportScore(self);
                [[[JubeatAppDelegate appDelegate] rootViewCtrl] returnToMusicSelect];
                [self.mainGameRenderer endResult];
                return;
            }
            GameViewControllerSaveAndReportScore(self);
            [audio playSeResFile:[self soundName:kDecideSoundName] inDirectory:nil];
            [audio fadeoutBgm:1.0];
            if (self->bItemChance) {
                CGFloat viewWidth = self.view.frame.size.width;
                CGFloat gameOffset = [self.mainGameRenderer gameAreaOffset];
                CGFloat centerX;
                if (!self->isPad) {
                    centerX = self.view.frame.size.width * 0.5;
                } else {
                    centerX = (double)(int)gameOffset +
                              (self.view.frame.size.width - (double)(int)gameOffset) * 0.5;
                }
                if (self.twitterBtn != nil) {
                    [self.twitterBtn setHidden:YES];
                }
                CGSize boundsSize = self.view.bounds.size;
                [self->itemChanceRender setInfo:self->chanceItemType
                                        itemNum:self->chanceItemNum
                                           size:CGSizeMake(viewWidth, boundsSize.height)
                                         center:CGPointMake(centerX, boundsSize.width * 0.5)
                                          scale:self->displayScale];
                [self.mainGameRenderer setState:kRendererStateItemChance];
                return;
            }
            [[[JubeatAppDelegate appDelegate] rootViewCtrl] returnToMusicSelect];
            [self.mainGameRenderer endResult];
            return;
        }
    }

    if (!self->isCustom) {
        if (self->scoreSaved && [self.mainGameRenderer subState] == kRendererSubStateReady) {
            unsigned int tweetButton = 1u << ([self.mainGameRenderer twitterSendButtonID] & 0x1f);
            if ((tweetButton & self->buttonUp) != 0) {
                ResultTweet *tweet = [[ResultTweet alloc] initWithInfo:self.sequence
                                                                  conf:self->confBak];
                [tweet setTitle:self->indexBBak white:self->indexWBak];
                UIImage *tweetImage = [tweet generateTweetImage];
                UIImageView *tweetView = [[UIImageView alloc] initWithImage:tweetImage];
                int score = self.sequence.getScore->totalPoint;
                NSString *message = [NSString
                    stringWithFormat:kTweetMessageFormat, self.currentTune.name, score, kTweetURL];
                [self sendTwitter:tweetView.image mesStr:message];
            }
        }
        return;
    }

    if (self->isDownload && self->hasMusic) {
        if ([self.mainGameRenderer subState] == kRendererSubStateReady) {
            unsigned int evaluateButton = 1u << ([self.mainGameRenderer evaluateButtonID] & 0x1f);
            if ((evaluateButton & self->buttonUp) != 0) {
                [audio playSeResFile:[self soundName:kDecideSoundName] inDirectory:nil];
                EditDataManager *editManager = [EditDataManager sharedManager];
                NSDictionary *editorInfo = [editManager getEditorInfo];
                NSString *sequenceID = editorInfo[kEditorInfoSequenceIDKey];
                if (sequenceID == nil) {
                    NSString *name = [editManager getLastEditFileName:self.currentTune.tuneID];
                    sequenceID = [name substringToIndex:name.length - kEditFileNameSuffixLength];
                }
                int level = [editorInfo[kEditorInfoLevelKey] intValue];
                self->evaluateView = [[EvaluateJcfView alloc] initWithID:sequenceID
                                                            defaultLevel:level
                                                                delegate:self
                                                                  tuneID:self.currentTune.tuneID];
                CGSize viewSize = self.view.frame.size;
                [self->evaluateView
                    setCenter:CGPointMake(viewSize.width * 0.5, viewSize.height * 0.5)];
                [self->evaluateView setAlpha:0.0];
                self->coverView = [[UIView alloc] initWithFrame:self.view.bounds];
                [self->coverView setOpaque:NO];
                // The original used colorWithWhite:0 alpha:0.5.
                [self->coverView setBackgroundColor:[UIColor colorWithWhite:0
                                                                      alpha:kResultCoverAlpha]];
                [self->coverView setAlpha:0.0];
                [self.view addSubview:self->coverView];
                [self.view addSubview:self->evaluateView];

                __weak UIView *weakCover = self->coverView;
                __weak EvaluateJcfView *weakEvaluate = self->evaluateView;
                [UIView animateWithDuration:kResultOverlayFadeDuration
                                 animations:^{
                                   /** @ghidraAddress 0x1608c */
                                   [weakEvaluate setAlpha:1.0];
                                   [weakCover setAlpha:1.0];
                                 }
                                 completion:^(BOOL finished){
                                     /** @ghidraAddress 0x16160 */
                                 }];
            }
        }

        // Good-job button.
        EditDataManager *editManager = [EditDataManager sharedManager];
        int goodJobSent = [[editManager getEditorInfo][kEditorInfoGoodJobSendKey] intValue];
        BOOL alreadyPressed = self->bGoodJobPress;
        BOOL goodJobUp = NO;
        if ([self.mainGameRenderer subState] == kRendererSubStateReady) {
            unsigned int goodJobButton = 1u << ([self.mainGameRenderer goodJobButtonID] & 0x1f);
            goodJobUp = (goodJobButton & self->buttonUp) != 0;
        }
        if (goodJobSent != 1 && !alreadyPressed && goodJobUp) {
            int variant = rand() % kGoodJobSoundVariantCount;
            NSString *soundName = [NSString stringWithFormat:kGoodJobSoundFormat, variant];
            [audio playSeResFile:soundName inDirectory:nil];
            [self pushBtnGoodJob];
        }
        return;
    }

    // Store-move (pack search) button, session without music.
    if (self->isSession && !self->hasMusic) {
        if ([self.mainGameRenderer subState] == kRendererSubStateReady) {
            unsigned int storeButton = 1u << ([self.mainGameRenderer storeMoveButtonID] & 0x1f);
            if ((storeButton & self->buttonUp) != 0) {
                self->packSearchView = [[SearchPackIDView alloc] initWithID:self.currentTune
                                                                       type:nil
                                                                   delegate:self];
                CGSize viewSize = self.view.frame.size;
                [self->packSearchView
                    setCenter:CGPointMake(viewSize.width * 0.5, viewSize.height * 0.5)];
                [self->packSearchView setAlpha:0.0];
                self->coverView = [[UIView alloc] initWithFrame:self.view.bounds];
                [self->coverView setOpaque:NO];
                // The original used colorWithWhite:0 alpha:0.5.
                [self->coverView setBackgroundColor:[UIColor colorWithWhite:0
                                                                      alpha:kResultCoverAlpha]];
                [self->coverView setAlpha:0.0];
                [self.view addSubview:self->coverView];
                [self.view addSubview:self->packSearchView];

                __weak UIView *weakCover = self->coverView;
                __weak SearchPackIDView *weakSearch = self->packSearchView;
                [UIView animateWithDuration:kResultOverlayFadeDuration
                    animations:^{
                      /** @ghidraAddress 0x16164 */
                      [weakSearch setAlpha:1.0];
                      [weakCover setAlpha:1.0];
                    }
                    completion:^(BOOL finished) {
                      /** @ghidraAddress 0x16238 */
                      [self->packSearchView startDownload];
                    }];
            }
        }
    }
}

@implementation GameViewController

#pragma mark - Lifecycle

/** @ghidraAddress 0xfc10 */
- (instancetype)init {
    self = [super init];
    if (self) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        self->adjustTime = [defaults floatForKey:kPrefAdjustSector] / kSectorsPerSecond;
        JubeatAppDelegate *appDelegate = [JubeatAppDelegate appDelegate];
        self->isPad = [appDelegate isPad];
        EAGLView *glView = [[EAGLView alloc] initWithFrame:[UIScreen mainScreen].bounds];
        self.glView = glView;
        self.glView.opaque = YES;
        self.glView.multipleTouchEnabled = YES;
        if ([appDelegate isPhoneRetina]) {
            self.glView.contentScaleFactor = 2.0;
        }
        self->bIsOpenSocialSend = NO;
        self->bRestartFlag = NO;
        self->bItemChance = NO;
        self->chanceItemType = kChanceItemTypeNone;
        self->chanceItemNum = 0;
        self->nteRender = nil;
    }
    return self;
}

/** @ghidraAddress 0xfe80 */
- (double)getMusicTime {
    double time = [[AudioManager sharedManager] bgmPos] - (double)self->adjustTime;
    if (time <= 0.0) {
        time = 0.0;
    }
    return time;
}

/** @ghidraAddress 0xfef8 */
- (NSString *)soundName:(NSString *)name {
    unsigned int theme = [[JubeatAppDelegate appDelegate] currentTheme];
    if (theme == kGameThemeRpl) {
        return [NSString stringWithFormat:kSoundNameFormatRpl, name];
    }
    if (theme == kGameThemeKnt) {
        return [NSString stringWithFormat:kSoundNameFormatKnt, name];
    }
    return [NSString stringWithFormat:kSoundNameFormatDefault, name];
}

/** @ghidraAddress 0xffe8 */
- (void)loadView {
    [super loadView];
    self.view.autoresizesSubviews = NO;
    [self.view addSubview:self.glView];

    self.btnPause = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.btnPause addTarget:self
                      action:@selector(pushBtnPause:)
            forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.btnPause];

    self->btnReplay = [UIButton buttonWithType:UIButtonTypeCustom];
    [self->btnReplay addTarget:self
                        action:@selector(pushBtnReplay:)
              forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self->btnReplay];

    self->btnReplayPause = [UIButton buttonWithType:UIButtonTypeCustom];
    [self->btnReplayPause addTarget:self
                             action:@selector(pushBtnReplayPause:)
                   forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self->btnReplayPause];
}

/** @ghidraAddress 0x102a4 */
- (void)loadResources {
    JubeatAppDelegate *appDelegate = [JubeatAppDelegate appDelegate];
    RendererConf *conf = [[RendererConf alloc] init];

    // Naga-Cora (Konami theme) without Hinabita gets an extra option renderer over the view.
    if (appDelegate.currentTheme == kGameThemeKnt &&
        [[JubeatAppDelegate appDelegate] isNagaCoraMode] &&
        ![[JubeatAppDelegate appDelegate] isHinabitaMode] && self->nteRender == nil) {
        self->nteRender =
            [[NteGameOptionRenderer alloc] initWithFrame:[UIScreen mainScreen].bounds];
        [self->nteRender setUserInteractionEnabled:NO];
        [self.view addSubview:self->nteRender];
    }

    UIImage *pauseImage = GameViewControllerThemeImage(
        appDelegate.currentTheme, kImagePauseRpl, kImagePauseKnt, kImagePauseDefault);
    [self.btnPause setBackgroundImage:pauseImage forState:UIControlStateNormal];

    // The pause button is right-aligned at the top; the phone idiom nudges it in and up by 4pt.
    CGFloat pauseX = self.view.frame.size.width - pauseImage.size.width;
    CGFloat pauseY;
    if (self->isPad) {
        pauseY = 0.0;
    } else {
        pauseX += kPauseButtonPhoneXOffset;
        pauseY = kPauseButtonPhoneY;
    }
    [self.btnPause
        setFrame:CGRectMake(pauseX, pauseY, pauseImage.size.width, pauseImage.size.height)];

    // The replay-pause button reuses the pause image, top-aligned for both idioms, hidden at first.
    CGFloat replayPauseX = self.view.frame.size.width - pauseImage.size.width;
    [self->btnReplayPause
        setFrame:CGRectMake(replayPauseX, 0.0, pauseImage.size.width, pauseImage.size.height)];
    [self->btnReplayPause setHidden:YES];
    [self->btnReplayPause setBackgroundImage:pauseImage forState:UIControlStateNormal];

    UIImage *replayImage = GameViewControllerThemeImage(
        appDelegate.currentTheme, kImageReplayRpl, kImageReplayKnt, kImageReplayDefault);
    CGFloat replayX = self.view.frame.size.width - replayImage.size.width;
    [self->btnReplay
        setFrame:CGRectMake(replayX, 0.0, replayImage.size.width, replayImage.size.height)];
    [self->btnReplay setHidden:YES];
    [self->btnReplay setBackgroundImage:replayImage forState:UIControlStateNormal];

    BOOL is4inch = appDelegate.is4inchAspect;
    [self.glView createFramebuffer];

    // The 2D projection space: 768x1024 on the pad, 320x480 on the phone (568 tall on 4-inch).
    CGSize space2d;
    if (self->isPad) {
        space2d = CGSizeMake(k2dSpacePadWidth, k2dSpacePadHeight);
    } else {
        space2d =
            CGSizeMake(k2dSpacePhoneWidth, is4inch ? k2dSpacePhoneHeightWide : k2dSpacePhoneHeight);
    }
    [self.glView set2dSpace:space2d];

    // The main renderer for the theme and idiom (all six arms).
    MainGameRenderer *renderer;
    if (appDelegate.currentTheme == kGameThemeRpl) {
        renderer = self->isPad ? [[MainGameRendererPadRpl alloc] init] :
                                 [[MainGameRendererPhoneRpl alloc] init];
    } else if (appDelegate.currentTheme == kGameThemeKnt) {
        renderer = self->isPad ? [[MainGameRendererPadKnt alloc] init] :
                                 [[MainGameRendererPhoneKnt alloc] init];
    } else {
        renderer =
            self->isPad ? [[MainGameRendererPad alloc] init] : [[MainGameRendererPhone alloc] init];
    }
    [self setMainGameRenderer:renderer];

    // The index (title) texture member: name_b for the RPL and KNT themes, name_w for the default.
    NSString *indexTextureName =
        (appDelegate.currentTheme == kGameThemeRpl || appDelegate.currentTheme == kGameThemeKnt) ?
            kArchiveNameBMember :
            kArchiveNameWMember;

    [self.mainGameRenderer setEaglView:self.glView];
    [self.mainGameRenderer setState:kRendererStateNone];

    [conf setTuneID:self.currentTune.tuneID];
    [conf setDiff:self.currentDiff];

    NSString *sequenceName;
    if (conf.diff == kGameDifficultyExtreme) {
        [conf setLevel:self.currentTune.lvExt];
        sequenceName = kArchiveSeqExtMember;
    } else if (conf.diff == kGameDifficultyAdvanced) {
        [conf setLevel:self.currentTune.lvAdv];
        sequenceName = kArchiveSeqAdvMember;
    } else {
        [conf setLevel:self.currentTune.lvBas];
        sequenceName = kArchiveSeqBasMember;
    }

    [conf setMarkerID:self.currentMarker];
    if ([conf.markerID isEqualToString:kStealthMarkerID]) {
        [conf setIsStealth:YES];
    }
    [conf setPartnerName:self.shareManager.partnerScreenName];

    self->hasMusic = [[StoreMusicListManager sharedManager] hasMusic:self.currentTune.tuneID];
    self->scoreSaved = self->hasMusic;
    if ([[JubeatAppDelegate appDelegate] isRandom] &&
        ![[JubeatAppDelegate appDelegate] bChallengeMode]) {
        self->scoreSaved = NO;
    }

    @autoreleasepool {
        KUnzip *archive;
        if (self.musicData == nil) {
            archive = [[KUnzip alloc] initWithPath:self.currentTune.filePath
                                              tail:kMusicArchiveTailLength];
        } else {
            archive = [[KUnzip alloc]
                initWithData:self.musicData
                       range:NSMakeRange(0, self.musicData.length - kMusicArchiveTailLength)];
        }

        UIImage *artworkImage = nil;
        UIImage *indexImage = nil;
        if (archive != nil) {
            BFCodec *codec = [[BFCodec alloc] init];
            NSData *cipherKey = GetBgmCipherKey();

            NSData *sequenceData = [archive uncompress:sequenceName];
            [codec cipherInit:cipherKey];
            [codec decipher:sequenceData];

            self->isCustom = ([NSUserDefaults.standardUserDefaults integerForKey:kPrefEditSelect] ==
                              kEditSelectCustom);
            if ([[JubeatAppDelegate appDelegate] bChallengeMode]) {
                self->isCustom = NO;
            }
            self->isDownload = NO;

            Sequence *sequence;
            if (self->isCustom) {
                EditDataManager *editManager = [EditDataManager sharedManager];
                sequence = [[Sequence alloc] initWithCustomData:[editManager getEditSimpleData]
                                                      tableData:[editManager getSequenceTable]];
                [conf setDiff:kGameDifficultyCustom];
                [conf setLevel:[[editManager getEditorInfo][kEditorInfoLevelKey] intValue] + 1];
                if ([[editManager getEditorInfo][kEditorInfoDlFlagKey] intValue] == 1) {
                    self->isDownload = YES;
                }
            } else {
                sequence = [[Sequence alloc] initWithData:sequenceData];
            }

            [self.mainGameRenderer setIsCustom:self->isCustom];
            [self.mainGameRenderer setIsDownload:self->isDownload];
            [self.mainGameRenderer setHasMusic:self->hasMusic];

            if (sequence != nil) {
                [self setSequence:sequence];
                [self.sequence reset];
                [self.mainGameRenderer setSequence:self.sequence];
            }

            NSData *markerData = [archive uncompress:kArchiveMarkerMember];
            if ([archive fileExists:kArchiveMarkerMember]) {
                [conf setMarkerData:[NSData dataWithData:markerData]];
            }

            NSData *bgm = [archive uncompress:kArchiveBgmMember];
            if (bgm != nil) {
                [codec cipherInit:cipherKey];
                [codec decipher:bgm];
                self->bgmData = [bgm copy];
                [[AudioManager sharedManager] loadBgmData:bgm];
            }

            artworkImage =
                GameViewControllerDecipherImage(codec, archive, cipherKey, kArchiveArtworkMember);
            indexImage =
                GameViewControllerDecipherImage(codec, archive, cipherKey, indexTextureName);

            UIImage *nameBImage =
                GameViewControllerDecipherImage(codec, archive, cipherKey, kArchiveNameBMember);
            if (nameBImage != nil) {
                self->indexBBak = nameBImage;
            }
            UIImage *nameWImage =
                GameViewControllerDecipherImage(codec, archive, cipherKey, kArchiveNameWMember);
            if (nameWImage != nil) {
                self->indexWBak = nameWImage;
            }

            self->confBak = conf;
        }

        [self setMusicData:nil];
        [self.glView startRenderContext];
        [self.mainGameRenderer loadTexure:conf artwork:artworkImage index:indexImage];
    }

    if (self.shareManager == nil) {
        self->isSession = NO;
        [self.mainGameRenderer setIsSession:NO];
        [self.mainGameRenderer setIsConnected:NO];
    } else {
        self->isSession = YES;
        [self.mainGameRenderer setIsSession:YES];
        [self.mainGameRenderer setIsConnected:YES];
    }
    [self.mainGameRenderer setState:kRendererStateNone];

    self->oldBestScore = 0;
    ScoreRecord *record = [ScoreRecord recordForTuneID:self.currentTune.tuneID];
    if (record != nil && [ScoreRecord checkScore:record]) {
        if (self.currentDiff == kGameDifficultyExtreme) {
            self->oldBestScore = record.scoExt.intValue;
        } else if (self.currentDiff == kGameDifficultyAdvanced) {
            self->oldBestScore = record.scoAdv.intValue;
        } else if (self.currentDiff == kGameDifficultyBasic) {
            self->oldBestScore = record.scoBas.intValue;
        }
    }

    if (self->isCustom) {
        self->oldBestScore =
            [[EditDataManager sharedManager] getScoreData][kScoreDataBestScoreKey].intValue;
    }

    if ([[JubeatAppDelegate appDelegate] bChallengeMode]) {
        self->itemChanceRender = [[ResultItemChance alloc] init];
        [self->itemChanceRender setEaglView:self.glView];
        [self->itemChanceRender loadTexure];
    }

    [self setPauseView:[[GamePauseView alloc] init]];
    self.pauseView.delegate = self;
    [self.btnPause setHidden:YES];
    self->isMusicPlaying = NO;

    if (![EditorIDManager isExistEditorID]) {
        self->idManager = [[EditorIDManager alloc] initWithDelegate:self];
    }

    self->isAuto = NO;
    self->bBuildAutoFlag = NO;
    self->music_time = 0;
    self->currentTouchIndex = 0;
    self->currentPressIndex = 0;
    [self makeTouchesData];

    // The double-tap auto-play catcher: 100pt square on the phone, 200pt on the pad.
    CGFloat autoSwitchSize = self->isPad ? kAutoSwitchSizePad : kAutoSwitchSizePhone;
    self->autoSwitch =
        [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, autoSwitchSize, autoSwitchSize)];
    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGesture:)];
    tap.numberOfTapsRequired = kTapCountAutoSwitch;
    [self->autoSwitch addGestureRecognizer:tap];
    [self.view addSubview:self->autoSwitch];

    self->bGoodJobPress = NO;

    // The renderer-overlay display scale by device type.
    self->displayScale = kDisplayScaleDefault;
    NSInteger deviceType = [[JubeatAppDelegate appDelegate] deviceType];
    if (deviceType == kDeviceTypeRetinaLow || deviceType == kDeviceTypeRetinaHigh) {
        self->displayScale = kDisplayScaleLargePhone;
    } else if (deviceType == kDeviceTypeLargestPhone) {
        self->displayScale = kDisplayScaleLargestPhone;
    }

    self->nowReplaying = NO;
}

/** @ghidraAddress 0x11d94 */
- (void)releaseResources {
    [[AudioManager sharedManager] releaseBgm:YES];
    self.sequence = nil;
    [self.mainGameRenderer setSequence:nil];
    if ([[JubeatAppDelegate appDelegate] bChallengeMode]) {
        [self->itemChanceRender releaseTexture];
    }
    [self.glView startRenderContext];
    [self.mainGameRenderer releaseTexture];
    [self.glView destroyFramebuffer];
    self.mainGameRenderer = nil;
    if ([[JubeatAppDelegate appDelegate] bChallengeMode]) {
        self->itemChanceRender = nil;
    }
    [self.pauseView removeFromSuperview];
    [self.pauseView setDelegate:nil];
    self.pauseView = nil;
    if (self.btnGoodJob) {
        [self.btnGoodJob removeFromSuperview];
        self.btnGoodJob = nil;
    }
    if (self->evaluateView) {
        [self->evaluateView removeFromSuperview];
        [self->coverView removeFromSuperview];
        self->evaluateView = nil;
        self->coverView = nil;
    }
    if (self.twitterBtn) {
        [self.twitterBtn removeFromSuperview];
        self.twitterBtn = nil;
    }
    if (self.btnStoreMove) {
        [self.btnStoreMove removeFromSuperview];
        self.btnStoreMove = nil;
    }
    [self releaseSearchPackView];
    if (self->idManager) {
        [self->idManager cancel];
        self->idManager = nil;
    }
    if (self->scoreUploader) {
        [self->scoreUploader cancel];
        self->scoreUploader = nil;
    }
}

#pragma mark - Animation

/** @ghidraAddress 0x12d64 */
- (void)startAnimation {
    if (self.displayLink) {
        [self.displayLink invalidate];
    }
    if ([[JubeatAppDelegate appDelegate] isNagaCoraMode]) {
        if ([self.mainGameRenderer state] == kRendererStateNone ||
            [self.mainGameRenderer state] == kRendererStateReady) {
            [self->nteRender openStart];
        }
    }
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(loop:)];
    [self.displayLink setFrameInterval:2];
    [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
}

/** @ghidraAddress 0x12f8c */
- (void)stopAnimation {
    if (self.displayLink) {
        [self.displayLink invalidate];
        self.displayLink = nil;
    }
}

/** @ghidraAddress 0x13020 */
- (void)finishMusic:(NSNotification *)notification {
    self->isMusicPlaying = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kFinishBgmNotificationName
                                                  object:nil];
}

#pragma mark - Play control

/** @ghidraAddress 0x13088 */
- (void)loop:(CADisplayLink *)displayLink {
    AudioManager *audio = [AudioManager sharedManager];
    [self.glView prepareToRender];

    self->buttonPressOld = self->buttonPress;
    self->buttonPress = 0;

    BOOL isAuto;
    if ([self.mainGameRenderer state] == kRendererStateEnding) {
        isAuto = NO;
        self->isAuto = NO;
    } else {
        isAuto = self->isAuto;
    }

    NSArray *touches = [self.glView touches];
    if (!isAuto) {
        for (id touch in touches) {
            CGPoint point = [touch locationInView:self.glView];
            GameViewControllerHitTestPanels(self, point);
        }
        if (!self->nowReplaying) {
            [self addGhostTouches];
        }
    } else {
        NSArray *events = [self getTouches];
        if (self->nowReplaying) {
            events = [self getGhostTouches];
        }
        for (NSArray *event in events) {
            CGPoint point = CGPointMake([event[0] floatValue], [event[1] floatValue]);
            GameViewControllerHitTestPanels(self, point);
        }
        if (!self->nowReplaying) {
            [self addGhostTouches];
        }
    }

    self->buttonDown = self->buttonPress & ~self->buttonPressOld;
    self->buttonUp = self->buttonPressOld & ~self->buttonPress;
    [self.mainGameRenderer setBtnPress:self->buttonPress];
    [self.mainGameRenderer setBtnDown:self->buttonDown];

    switch ((int)[self.mainGameRenderer state]) {
    case kRendererStateReady: {
        if ([self.mainGameRenderer subState] != kRendererSubStateReady) {
            break;
        }
        if (self.shareManager == nil) {
            [self.mainGameRenderer setState:kRendererStateStarting];
        } else {
            [self.shareManager completeLoadingMusicData];
            [self.mainGameRenderer setSubState:kRendererSubStateSessionWait];
        }
        break;
    }
    case kRendererStateStarting: {
        if (![self.mainGameRenderer isEndState]) {
            break;
        }
        self->bRestartFlag = NO;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(finishMusic:)
                                                     name:kFinishBgmNotificationName
                                                   object:nil];
        [audio startBgm:0 fadeTime:0.0];
        self->isMusicPlaying = YES;
        [self.mainGameRenderer startPlay];
        break;
    }
    case kRendererStatePlaying: {
        if ([audio interrupted]) {
            break;
        }
        [self.sequence judge:self->buttonDown btnPress:self->buttonPress];
        if (self.shareManager != nil) {
            BOOL isHost = [self.shareManager isHost];
            BOOL shouldSend =
                isHost ? (self->draw_count & kSessionSendFrameMask) == kSessionSendFrameHost :
                         (self->draw_count & kSessionSendFrameMask) == kSessionSendFrameClient;
            if (shouldSend) {
                [self.shareManager sendScore:self.sequence.getScore->point];
            }
        }
        if (!self->isMusicPlaying) {
            [self.sequence seekToTime:self.sequence.currentTime + kPlaybackCatchupStep];
        } else {
            self->music_time = [self getMusicTime];
            [self.sequence seekToTime:self->music_time];
        }
        if ([self.sequence playPosition] >= 1.0f) {
            [self.mainGameRenderer setState:kRendererStateEnding];
            [self.btnPause setHidden:YES];
            if (!self->isCustom && self->hasMusic && [EditorIDManager isExistEditorID]) {
                GameViewControllerSubmitEditScore(self);
            }
        }
        break;
    }
    case kRendererStateEnding: {
        if ([self.mainGameRenderer subState] != kRendererSubStateReady) {
            break;
        }
        GameViewControllerHandleEndingState(self, audio);
        break;
    }
    case kRendererStateEnded: {
        GameViewControllerHandleEndedState(self, audio);
        break;
    }
    case kRendererStateItemChance: {
        if (self->buttonUp == 0 || ![self->itemChanceRender enableSkip]) {
            break;
        }
        [audio playSeResFile:[self soundName:kDecideSoundName] inDirectory:nil];
        [audio fadeoutBgm:1.0];
        [[[JubeatAppDelegate appDelegate] rootViewCtrl] returnToMusicSelect];
        [self.mainGameRenderer endResult];
        break;
    }
    }

    [self.mainGameRenderer draw];
    if ([self.mainGameRenderer state] == kRendererStateItemChance) {
        [self->itemChanceRender draw];
    }

    if (self->draw_count != 0 && (self->draw_count & kFpsSampleFrameMask) == 0) {
        double now = CFAbsoluteTimeGetCurrent();
        self->fps = (float)(kFpsSampleFrameCount / (now - self->past_time));
        self->past_time = now;
    }
    ++self->draw_count;
    [self.glView swapBuffer];
}

/** @ghidraAddress 0x16264 */
- (void)startGame {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self->adjustTime = [defaults floatForKey:kPrefAdjustSector] / kSectorsPerSecond;
    [self.sequence reset];
    [self.sequence seekToTime:0];
    if (!self->isSession || self.shareManager == nil) {
        [self.btnPause setHidden:NO];
    }
    self->bEnableGhost = NO;
    self->ghostRecTouches = nil;
    self->ghostRecTouches = [[NSMutableArray alloc] init];
    memset(self->startSector, 0, sizeof(self->startSector));
    [self.mainGameRenderer setState:kRendererStateReady];
    [self.mainGameRenderer setShowCombo:[defaults boolForKey:kPrefShowCombo]];
    float buttonWidth = [defaults floatForKey:kPrefButtonWidth];
    float clampedWidth;
    if (buttonWidth > 1.0f) {
        clampedWidth = 1.0f;
    } else if (buttonWidth >= 0.0f) {
        clampedWidth = buttonWidth;
    } else {
        clampedWidth = 0.0f;
    }
    self->buttonTouchWidth = clampedWidth * kButtonTouchWidthUnit;
}

/** @ghidraAddress 0x16514 */
- (void)replayGame {
    if (!self->nowReplaying) {
        [self.mainGameRenderer backupScoreData];
        [self setReplayData];
    }
    self->nowReplaying = YES;
    self->isAuto = YES;
    [self->btnReplay setHidden:YES];
    [self->btnReplayPause setHidden:NO];
    if (self.twitterBtn) {
        [self.twitterBtn setHidden:YES];
    }
    self->currentGhostIndex = 0;
    AudioManager *audio = [AudioManager sharedManager];
    [audio loadBgmData:self->bgmData];
    [self.sequence replay];
    [self.sequence seekToTime:0];
    [audio setBgmPos:0.0];
    self->music_time = 0;
    [self startAnimation];
    if (self->isSession) {
        (void)self.shareManager; // Yes, the binary reads the manager and discards it.
    }
    self->isMusicPlaying = NO;
    [self.mainGameRenderer setState:kRendererStateStarting];
    [self.mainGameRenderer setShowCombo:NO];
    self->bRestartFlag = YES;
}

/** @ghidraAddress 0x167b4 */
- (void)restartGame {
    if (self->nowReplaying) {
        [self replayGame];
        return;
    }
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self->adjustTime = [defaults floatForKey:kPrefAdjustSector] / kSectorsPerSecond;
    self->currentTouchIndex = 0;
    self->currentPressIndex = 0;
    AudioManager *audio = [AudioManager sharedManager];
    [self.sequence reset];
    [self.sequence seekToTime:0];
    [audio setBgmPos:0.0];
    self->music_time = 0;
    [self startAnimation];
    if (!self->isSession || self.shareManager == nil) {
        [self.btnPause setHidden:NO];
    }
    [self.mainGameRenderer setState:kRendererStateReady];
    self->bEnableGhost = NO;
    self->ghostRecTouches = nil;
    self->ghostRecTouches = [[NSMutableArray alloc] init];
    memset(self->startSector, 0, sizeof(self->startSector));
    [self.mainGameRenderer setShowCombo:[defaults boolForKey:kPrefShowCombo]];
    float buttonWidth = [defaults floatForKey:kPrefButtonWidth];
    float clampedWidth;
    if (buttonWidth > 1.0f) {
        clampedWidth = 1.0f;
    } else if (buttonWidth >= 0.0f) {
        clampedWidth = buttonWidth;
    } else {
        clampedWidth = 0.0f;
    }
    self->buttonTouchWidth = clampedWidth * kButtonTouchWidthUnit;
    self->bRestartFlag = YES;
}

/** @ghidraAddress 0x16b24 */
- (void)pushBtnReplay:(id)sender {
    if ([self.mainGameRenderer state] != kRendererStateEnded) {
        return;
    }
    if (self->scoreSaved) {
        if (!self->isCustom) {
            [self saveScore];
            if ([[JubeatAppDelegate appDelegate] gameCenterAvailable] &&
                [[GKLocalPlayer localPlayer] isAuthenticated]) {
                NSString *category =
                    [[JubeatAppDelegate appDelegate] totalScoreLeaderboardCategory];
                GKScore *score = [[GKScore alloc] initWithLeaderboardIdentifier:category];
                score.value = [ScoreRecord totalScore];
                [GKScore reportScores:@[ score ]
                    withCompletionHandler:^(NSError *_Nullable error) {
                      /** @ghidraAddress 0x16eb0 */
                      GameViewControllerReportScoreNoopHandler(error);
                    }];
            }
        } else {
            EditDataManager *editManager = [EditDataManager sharedManager];
            int scoreValue = [self.sequence getScore]->totalPoint;
            BOOL fullCombo = [self.sequence isFullcombo];
            [editManager scoreUpdate:scoreValue
                           fullCombo:fullCombo
                              tuneID:[self.currentTune tuneID]];
        }
    }
    [self.mainGameRenderer replaySelect];
    [[[JubeatAppDelegate appDelegate] rootViewCtrl] musicReplay];
}

/** @ghidraAddress 0x16eb4 */
- (void)pushBtnReplayPause:(id)sender {
    [[AudioManager sharedManager] playSeResFile:[self soundName:kPauseSoundName] inDirectory:nil];
    [self stopAnimation];
    if (self->isMusicPlaying) {
        [[AudioManager sharedManager] stopBgm];
    }
    [self.pauseView showInView:self.view animated:YES];
}

/** @ghidraAddress 0x16ff8 */
- (void)pushBtnPause:(id)sender {
    [[AudioManager sharedManager] playSeResFile:[self soundName:kPauseSoundName] inDirectory:nil];
    [self stopAnimation];
    if (self->isMusicPlaying) {
        [[AudioManager sharedManager] stopBgm];
    }
    [self.pauseView showInView:self.view animated:YES];
}

/** @ghidraAddress 0x1713c */
- (void)restartInPauseView {
    [[[JubeatAppDelegate appDelegate] rootViewCtrl] musicRestart];
}

/** @ghidraAddress 0x171a4 */
- (void)resumeInPauseView {
    if ([[[JubeatAppDelegate appDelegate] rootViewCtrl] isActive]) {
        [self startAnimation];
        if (self->isMusicPlaying) {
            [[AudioManager sharedManager] startBgm:0 fadeTime:0.0];
        }
    }
}

/** @ghidraAddress 0x1728c */
- (void)endInPauseView {
    if ([[JubeatAppDelegate appDelegate] bChallengeMode]) {
        [[AlertViewManager sharedManager] makeAlert:kAlertTypePlain
                                           delegate:self
                                                tag:kAlertTagEnd
                                              title:nil
                                                msg:kEndAlertTitle
                                             cancel:kEndAlertCancel
                                            btnText:@[ kEndAlertConfirm ]
                                               show:YES];
    } else {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:kFinishBgmNotificationName
                                                      object:nil];
        [[[JubeatAppDelegate appDelegate] rootViewCtrl] returnToMusicSelect];
    }
}

/** @ghidraAddress 0x17488 */
- (void)end {
    [self dismissViewControllerAnimated:NO completion:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kFinishBgmNotificationName
                                                  object:nil];
    [[[JubeatAppDelegate appDelegate] rootViewCtrl] returnToMusicSelect];
}

#pragma mark - Evaluate overlay

/** @ghidraAddress 0x17840 */
- (void)removeEvaluate {
    [self->evaluateView removeFromSuperview];
    [self->coverView removeFromSuperview];
    self->evaluateView = nil;
    self->coverView = nil;
}

/** @ghidraAddress 0x178a8 */
- (void)closeEvaluate:(id)sender {
    __weak UIView *weakCover = self->coverView;
    __weak EvaluateJcfView *weakEvaluate = self->evaluateView;
    [UIView animateWithDuration:kEvaluateFadeDuration
        animations:^{
          /** @ghidraAddress 0x17a18 */
          [weakEvaluate setAlpha:0.0];
          [weakCover setAlpha:0.0];
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x17ae0 */
          [self removeEvaluate];
        }];
}

#pragma mark - SharePlayManagerDelegate

/** @ghidraAddress 0x17b00 */
- (void)sharePlayManagerDisconnect:(SharePlayManager *)manager {
    [self sessionDisconnect:YES];
}

/** @ghidraAddress 0x17b10 */
- (void)sharePlayManager:(SharePlayManager *)manager disconnectClient:(id)client {
    [self sessionDisconnect:YES];
}

/** @ghidraAddress 0x17b20 */
- (void)sharePlayManagerFailWithError:(SharePlayManager *)manager {
    [self sessionDisconnect:YES];
}

/** @ghidraAddress 0x17b30 */
- (void)sharePlayManagerAllClientLoaded:(SharePlayManager *)manager {
    [self.shareManager startPlaySync];
}

/** @ghidraAddress 0x17b70 */
- (void)sharePlayManager:(SharePlayManager *)manager startMusicTime:(float)musicTime {
    __weak GameViewController *weakSelf = self;
    [self.mainGameRenderer setSubState:kRendererSubStateReadyGo];
    float readyGo = [self.mainGameRenderer durationOfReadyGo];
    dispatch_time_t when =
        dispatch_time(0, (long)(((double)musicTime - (double)readyGo) * kNanosecondsPerSecond));
    dispatch_after(when, dispatch_get_main_queue(), ^{
      /** @ghidraAddress 0x17cc8 */
      [weakSelf.mainGameRenderer setState:kRendererStateStarting];
    });
}

/** @ghidraAddress 0x17d34 */
- (void)sharePlayManagerMusicStartTimeOut:(SharePlayManager *)manager {
}

/** @ghidraAddress 0x17d38 */
- (void)sharePlayManager:(SharePlayManager *)manager receiveScore:(int)score {
    [self.mainGameRenderer setPartnerScore:score];
}

/** @ghidraAddress 0x17d80 */
- (void)sharePlayManager:(SharePlayManager *)manager
       receiveFinalScore:(int)score
                   bonus:(int)bonus
               fullCombo:(BOOL)fullCombo {
    [self.mainGameRenderer setPartnerFinished:YES];
    [self.mainGameRenderer setPartnerScore:score];
    [self.mainGameRenderer setPartnerFinalBonus:bonus];
    [self.mainGameRenderer setPartnerFullcombo:fullCombo];
    [self.mainGameRenderer setState:kRendererStateEnded];
}

#pragma mark - Suspend / resume / terminate

/** @ghidraAddress 0x17ea8 */
- (void)suspend {
    switch ([self.mainGameRenderer state]) {
    case kRendererStateReady:
    case kRendererStateStarting:
        if ([self.pauseView superview]) {
            break;
        }
        [self stopAnimation];
        break;
    case kRendererStateNone:
    case kRendererStateEnding:
    case kRendererStateEnded:
        [self stopAnimation];
        break;
    case kRendererStatePlaying:
        if (![self.pauseView superview]) {
            [self stopAnimation];
            if (self->isMusicPlaying) {
                [[AudioManager sharedManager] stopBgm];
            }
        }
        break;
    }
    [self sessionDisconnect:NO];
}

/** @ghidraAddress 0x18038 */
- (void)resume {
    switch ([self.mainGameRenderer state]) {
    case kRendererStateNone:
    case kRendererStateEnded:
        break;
    case kRendererStateReady:
        if ([self.mainGameRenderer isSession] &&
            [self.mainGameRenderer subState] == kRendererSubStateSessionWait) {
            [self.mainGameRenderer setState:kRendererStateStarting];
        }
        // Fall through to the starting / playing pause handling.
    case kRendererStateStarting:
    case kRendererStatePlaying:
        if (self->bRestartFlag) {
            break;
        }
        if ([self.pauseView superview]) {
            return;
        }
        [self.pauseView showInView:self.view animated:NO];
        AudioManager *audio = [AudioManager sharedManager];
        if ([audio bgmPlaying]) {
            [audio stopBgm];
        }
        return;
    case kRendererStateEnding:
        if ([self.mainGameRenderer isSession] &&
            [self.mainGameRenderer subState] == kRendererSubStateSessionWait) {
            [self.mainGameRenderer setState:kRendererStateEnded];
        }
        break;
    default:
        return;
    }
    [self startAnimation];
}

/** @ghidraAddress 0x1833c */
- (void)terminate {
    AudioManager *audio = [AudioManager sharedManager];
    if ([audio bgmPlaying]) {
        [audio stopBgm];
    }
    [self stopAnimation];
    [self.glView prepareToRender];
    [self.glView swapBuffer];
    [self.glView resetTouches];
    [self.mainGameRenderer setState:kRendererStateNone];
}

#pragma mark - UIViewController overrides

/** @ghidraAddress 0x18474 */
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

/** @ghidraAddress 0x184ac */
- (void)viewDidUnload {
    [super viewDidUnload];
    [self.glView removeFromSuperview];
    self.btnPause = nil;
    [self.pauseView setDelegate:nil];
    self.pauseView = nil;
    if (self.btnGoodJob) {
        [self.btnGoodJob removeFromSuperview];
        self.btnGoodJob = nil;
        [self.mainGameRenderer setGoodJobImage:nil];
    }
    if (self.twitterBtn) {
        [self.twitterBtn removeFromSuperview];
        self.twitterBtn = nil;
    }
    if (self.btnStoreMove) {
        [self.btnStoreMove removeFromSuperview];
        self.btnStoreMove = nil;
    }
}

/** @ghidraAddress 0x186e8 */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

/** @ghidraAddress 0x18720 */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

/** @ghidraAddress 0x18758 */
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

/** @ghidraAddress 0x18790 */
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

/** @ghidraAddress 0x187c8 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return interfaceOrientation - 1 < 2;
}

/** @ghidraAddress 0x187d8 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscape;
}

/** @ghidraAddress 0x187e0 */
- (BOOL)shouldAutorotate {
    return YES;
}

#pragma mark - jubeat-lab access

/** @ghidraAddress 0x187e8 */
- (void)requestAddPlayCount {
    EditDataManager *editManager = [EditDataManager sharedManager];
    NSString *fileName = [editManager getLastEditFileName:[self.currentTune tuneID]];
    if (fileName && self->isDownload) {
        if ([[editManager getEditorInfo] objectForKey:kEditorInfoSequenceIDKey] == nil) {
            NSString *lastName = [editManager getLastEditFileName:[self.currentTune tuneID]];
            fileName = [lastName substringToIndex:[lastName length] - 4];
        }
        jubeatLabAccess *access = [[jubeatLabAccess alloc] initPlayApi:self
                                                                tuneID:[self.currentTune tuneID]
                                                                 seqID:fileName];
        self->playCountAccess = access;
        if (self->playCountAccess) {
            [self->playCountAccess startAccess];
        }
    }
}

/** @ghidraAddress 0x18a0c */
- (void)jubeatLabAccessError:(id)access {
    if (self->playCountAccess == access) {
        self->playCountAccess = nil;
    }
    if (self->goodJobCommit == access) {
        self->goodJobCommit = nil;
    }
}

/** @ghidraAddress 0x18a78 */
- (void)jubeatLabAccessFinished:(id)access {
    if (self->playCountAccess == access) {
        self->playCountAccess = nil;
    }
    if (self->goodJobCommit == access) {
        EditDataManager *editManager = [EditDataManager sharedManager];
        [[editManager getEditorInfo] setObject:@(1) forKey:kEditorInfoGoodJobSendKey];
        NSString *path = [editManager getLastEditFilePath:[self.currentTune tuneID]];
        [editManager saveJCF:path];
        self->goodJobCommit = nil;
    }
}

/** @ghidraAddress 0x18bf8 */
- (void)dealloc {
    [self stopAnimation];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kFinishBgmNotificationName
                                                  object:nil];
    [self.shareManager disconnect];
    [self.pauseView setDelegate:nil];
    if (self.btnGoodJob) {
        [self.btnGoodJob removeFromSuperview];
        self.btnGoodJob = nil;
        [self.mainGameRenderer setGoodJobImage:nil];
    }
    if (self->evaluateView) {
        [self->evaluateView removeFromSuperview];
        [self->coverView removeFromSuperview];
        self->evaluateView = nil;
        self->coverView = nil;
    }
    if (self.twitterBtn) {
        [self.twitterBtn removeFromSuperview];
        self.twitterBtn = nil;
    }
    if (self.btnStoreMove) {
        [self.btnStoreMove removeFromSuperview];
        self.btnStoreMove = nil;
    }
}

#pragma mark - Social

/** @ghidraAddress 0x1a3f0 */
- (void)sendTwitter:(UIImage *)image mesStr:(NSString *)mesStr {
    self->bIsOpenSocialSend = YES;
    SLComposeViewController *composer =
        [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeTwitter];
    [composer setInitialText:mesStr];
    [composer addImage:image];
    [composer setCompletionHandler:^(SLComposeViewControllerResult result) {
      /** @ghidraAddress 0x1a524 */
      self->bIsOpenSocialSend = NO;
      if (result == SLComposeViewControllerResultCancelled ||
          result == SLComposeViewControllerResultDone) {
          [self dismissViewControllerAnimated:YES completion:nil];
      }
    }];
    [self presentViewController:composer animated:YES completion:nil];
}

#pragma mark - Pack-ID download

/** @ghidraAddress 0x1afb8 */
- (void)errorIDDownload:(id)error msgStr:(id)msgStr {
    self->idManager = nil;
}

/** @ghidraAddress 0x1afd0 */
- (void)successIDDownload:(id)sender {
    self->idManager = nil;
}

/** @ghidraAddress 0x1b61c */
- (void)releaseSearchPackView {
    if (self->packSearchView) {
        [self->packSearchView removeFromSuperview];
        self->packSearchView = nil;
    }
    if (self->coverView) {
        [self->coverView removeFromSuperview];
        self->coverView = nil;
    }
}

#pragma mark - Alerts

/** @ghidraAddress 0x1d4a8 */
- (void)alertSelect:(NSDictionary *)info {
    int buttonMessage = [info[kAlertButtonMessageKey] intValue];
    int tag = [info[kAlertTagKey] intValue];
    if (tag == kAlertTagEnd) {
        if (buttonMessage == kAlertButtonOK) {
            [self end];
        }
    } else if (tag == kAlertTagChallenge) {
        if (buttonMessage == kAlertButtonOK) {
            [self sendChallengeScore];
        } else {
            self->bItemChance = NO;
            self->chanceItemType = kChanceItemTypeNone;
            self->chanceItemNum = 0;
        }
    }
}

/** @ghidraAddress 0x1d5e8 */
- (void)panelChanceClose {
    [[AudioManager sharedManager] fadeoutBgm:1.0];
    [[[JubeatAppDelegate appDelegate] rootViewCtrl] returnToMusicSelect];
    [self.mainGameRenderer endResult];
}

#pragma mark - Result-screen buttons

/** @ghidraAddress 0x18eb0 */
- (void)createGoodJobBtn {
    if ([[[EditDataManager sharedManager] getEditorInfo][kEditorInfoGoodJobSendKey] intValue] ==
        1) {
        return;
    }

    UIImage *image = LoadScaledPngImage(kImageGoodJobButton);
    self.btnGoodJob =
        [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, image.size.width, image.size.height)];
    self.btnGoodJob.image = image;
    self.btnGoodJob.center =
        GameViewControllerButtonCenter(self, self.mainGameRenderer.goodJobPosition);
    self.btnGoodJob.transform = CGAffineTransformMakeScale(self->displayScale, self->displayScale);
    self.btnGoodJob.alpha = 0.0;
    [self.view addSubview:self.btnGoodJob];
    [self.mainGameRenderer setGoodJobImage:self.btnGoodJob];
    [self.mainGameRenderer setGoodJobAlphaMax:kGoodJobAlphaMax];

    // The caption view is centred on the button image's integer-truncated dimensions.
    int btnWidth = (int)image.size.width;
    int btnHeight = (int)image.size.height;

    UIImage *txtImage = LoadScaledPngImage(kImageGoodJobString);
    self.goodJobTxt = [[UIImageView alloc]
        initWithFrame:CGRectMake(0, 0, txtImage.size.width, txtImage.size.height)];
    self.goodJobTxt.image = txtImage;
    self.goodJobTxt.center = CGPointMake((float)btnWidth * kGoodJobTxtCenterFactor,
                                         (float)btnHeight * kGoodJobTxtCenterFactor);
    self.goodJobTxt.alpha = 0.0;
    // The binary concatenates the scale with an identity translation; kept faithfully.
    self.goodJobTxt.transform = CGAffineTransformConcat(
        CGAffineTransformMakeScale(self->displayScale * kGoodJobTxtInitialScale,
                                   self->displayScale * kGoodJobTxtInitialScale),
        CGAffineTransformMakeTranslation(0, 0));
    [self.btnGoodJob addSubview:self.goodJobTxt];
}

/** @ghidraAddress 0x19518 */
- (void)pushBtnGoodJob {
    EditDataManager *editManager = [EditDataManager sharedManager];
    NSString *editFileName = [editManager getLastEditFileName:self.currentTune.tuneID];
    if (editFileName == nil) {
        return;
    }
    self->bGoodJobPress = YES;

    NSString *sequenceID = [editManager getEditorInfo][kEditorInfoSequenceIDKey];
    if (sequenceID == nil) {
        NSString *name = [editManager getLastEditFileName:self.currentTune.tuneID];
        sequenceID = [name substringToIndex:name.length - kEditFileNameSuffixLength];
    }

    self->goodJobCommit = [[jubeatLabAccess alloc] initGoodJobApi:self
                                                           tuneID:self.currentTune.tuneID
                                                            seqID:sequenceID];
    if (self->goodJobCommit != nil) {
        [self->goodJobCommit startAccess];
    }

    (void)[[JubeatAppDelegate appDelegate] isPhoneRetina]; // Yes, the binary discards this result.

    // The label's resting transform before the animation.
    self.goodJobTxt.transform = CGAffineTransformConcat(
        CGAffineTransformMakeScale(self->displayScale * kGoodJobTxtInitialScale,
                                   self->displayScale * kGoodJobTxtInitialScale),
        CGAffineTransformMakeTranslation(
            0, self->isPad ? kGoodJobTxtInitialYPad : kGoodJobTxtInitialYPhone));

    __weak UIImageView *weakTxt = self.goodJobTxt;
    CGAffineTransform riseTransform =
        CGAffineTransformConcat(CGAffineTransformMakeScale(self->displayScale, self->displayScale),
                                CGAffineTransformMakeTranslation(
                                    0, self->isPad ? kGoodJobTxtRiseYPad : kGoodJobTxtRiseYPhone));

    [UIView animateWithDuration:kGoodJobRiseDuration
        animations:^{
          /** @ghidraAddress 0x19a4c */
          weakTxt.alpha = 1.0;
          weakTxt.transform = riseTransform;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x19af0 */
          (void)[[JubeatAppDelegate appDelegate] isPhoneRetina]; // Discarded, as in the binary.
          CGAffineTransform fadeTransform = CGAffineTransformConcat(
              CGAffineTransformMakeScale(self->displayScale * kGoodJobTxtFadeScale,
                                         self->displayScale * kGoodJobTxtFadeScale),
              CGAffineTransformMakeTranslation(
                  0, self->isPad ? kGoodJobTxtFadeYPad : kGoodJobTxtFadeYPhone));
          [UIView animateWithDuration:kGoodJobFadeDuration
              animations:^{
                /** @ghidraAddress 0x19cc0 */
                weakTxt.alpha = 0.0;
                weakTxt.transform = fadeTransform;
              }
              completion:^(BOOL fadeFinished) {
                /** @ghidraAddress 0x19d64 */
                __weak UIImageView *weakBtn = self.btnGoodJob;
                [UIView animateWithDuration:kGoodJobBtnFadeDuration
                                 animations:^{
                                   /** @ghidraAddress 0x19e4c */
                                   weakBtn.alpha = kGoodJobBtnFinalAlpha;
                                 }
                                 completion:^(BOOL btnFinished){
                                     /** @ghidraAddress 0x19e9c */
                                 }];
              }];
        }];
}

/** @ghidraAddress 0x19f08 */
- (void)createTwitterBtn {
    if (self->isCustom) {
        return;
    }
    if (self.twitterBtn != nil) {
        self.twitterBtn.hidden = NO;
        self.twitterBtn.alpha = 0.0; // Un-hides but stays transparent, as in the binary.
        return;
    }

    JubeatAppDelegate *appDelegate = [JubeatAppDelegate appDelegate];
    UIImage *image = GameViewControllerThemeImage(
        appDelegate.currentTheme, kImageTwitterRpl, kImageTwitterKnt, kImageTwitterDefault);

    CGPoint center = GameViewControllerButtonCenter(self, self.mainGameRenderer.twitterBtnPosition);
    if (appDelegate.currentTheme == kGameThemeDefault) {
        center.y -= (self->isPad ? kButtonCenterYOffsetPad : kButtonCenterYOffsetPhone);
    }
    self.twitterBtn = GameViewControllerAddScaledButton(self, image, center);
}

/** @ghidraAddress 0x1a56c */
- (void)createSearchBtn {
    JubeatAppDelegate *appDelegate = [JubeatAppDelegate appDelegate];
    UIImage *image = GameViewControllerThemeImage(
        appDelegate.currentTheme, kImageSearchRpl, kImageSearchKnt, kImageSearchDefault);

    CGPoint center =
        GameViewControllerButtonCenter(self, self.mainGameRenderer.storeMoveBtnPosition);
    if (appDelegate.currentTheme == kGameThemeDefault) {
        center.y -= (self->isPad ? kButtonCenterYOffsetPad : kButtonCenterYOffsetPhone);
    }
    self.btnStoreMove = GameViewControllerAddScaledButton(self, image, center);
}

#pragma mark - Touch recording and replay

/** @ghidraAddress 0x1b690 */
- (void)makeTouchesData {
    self->currentTouchIndex = 0;

    NSMutableArray *playEvents = [NSMutableArray arrayWithArray:[self.sequence getPlayEvents]];
    NSMutableArray *holdEvents = [NSMutableArray arrayWithArray:[self.sequence getHoldEvents]];
    NSMutableArray *table = [[NSMutableArray alloc] init];

    int panelWidth;
    int yOffset;
    GameViewControllerPanelMetrics(self, &panelWidth, &yOffset);
    int halfWidth = panelWidth >> 1;

    NSMutableArray *group = nil;
    int groupTime = 0;
    for (NSArray *event in playEvents) {
        int time = [event[0] intValue];
        int panel = [event[1] intValue];
        if (groupTime != time) {
            if (group != nil) {
                [table addObject:@[ @(groupTime), [NSArray arrayWithArray:group] ]];
            }
            group = [[NSMutableArray alloc] init];
            groupTime = time;
        }
        float x;
        float y;
        GameViewControllerPanelCenter(panel, panelWidth, yOffset, &x, &y);
        [group addObject:@[ @(x), @(y) ]];
    }
    if ([group count] != 0) {
        [table addObject:@[ @(groupTime), [NSArray arrayWithArray:group] ]];
    }

    self->debugTouchTable = [NSArray arrayWithArray:table];
    [table removeAllObjects];

    // Hold events pack the lane, row, and duration into a single integer.
    for (NSArray *event in holdEvents) {
        int time = [event[0] intValue];
        unsigned int packed = [event[1] unsignedIntValue];
        float x = (float)(halfWidth + (packed & 3) * panelWidth);
        float y = (float)(halfWidth + yOffset + ((packed >> 2) & 3) * panelWidth);
        unsigned int duration = (packed >> 8) & 0xffffff;
        [table addObject:@[ @(time), @[ @(x), @(y) ], @(duration) ]];
    }

    self->debugPressTable = [NSArray arrayWithArray:table];
}

/** @ghidraAddress 0x1bfbc */
- (NSArray *)getTouches {
    int now = GameViewControllerNowSector(self);
    NSMutableArray *result = nil;

    if (self->currentTouchIndex < (int)[self->debugTouchTable count]) {
        int i = self->currentTouchIndex;
        while (i < (int)[self->debugTouchTable count]) {
            int time = [self->debugTouchTable[i][0] intValue];
            NSArray *positions = self->debugTouchTable[i][1];
            int windowEnd = time + kTouchHoldWindowSectors;
            if (time <= now && now <= windowEnd) {
                if (result == nil) {
                    result = [[NSMutableArray alloc] init];
                }
                [result addObjectsFromArray:positions];
            }
            if (windowEnd < now) {
                ++self->currentTouchIndex;
            }
            if ((int)[self->debugTouchTable count] <= self->currentTouchIndex) {
                break;
            }
            int nextTime = [self->debugTouchTable[self->currentTouchIndex][0] intValue];
            if (now < nextTime) {
                break;
            }
            ++i;
        }
    }

    if (self->currentPressIndex < (int)[self->debugPressTable count]) {
        int i = self->currentPressIndex;
        while (i < (int)[self->debugPressTable count]) {
            int time = [self->debugPressTable[i][0] intValue];
            NSArray *position = self->debugPressTable[i][1];
            int duration = [self->debugPressTable[i][2] intValue];
            int windowEnd = time + duration - kPressReleaseMarginSectors;
            if (time <= now && now <= windowEnd) {
                if (result == nil) {
                    result = [[NSMutableArray alloc] init];
                }
                [result addObjectsFromArray:@[ position ]];
            }
            if (windowEnd < now) {
                ++self->currentPressIndex;
            }
            if ((int)[self->debugPressTable count] <= self->currentPressIndex) {
                break;
            }
            int nextTime = [self->debugPressTable[self->currentPressIndex][0] intValue];
            if ((time + duration) < nextTime) { // The break uses the un-margined end. Faithful.
                break;
            }
            ++i;
        }
    }

    return (result == nil) ? nil : [NSArray arrayWithArray:result];
}

/** @ghidraAddress 0x1c544 */
- (void)tapGesture:(UITapGestureRecognizer *)gesture {
    if ([[JubeatAppDelegate appDelegate] bEnableAutoPlay] && !self->nowReplaying) {
        if (![[JubeatAppDelegate appDelegate] bChallengeMode]) {
            BOOL wasAuto = self->isAuto;
            self->isAuto = !self->isAuto;
            if (!wasAuto) {
                self->bBuildAutoFlag = YES;
            }
        }
    }
}

/** @ghidraAddress 0x1c61c */
- (int)getDelaySector {
    switch (rand() % kDelaySectorProbabilityRange) {
    case 0:
    case 3:
        return ~(rand() % 2) * kDelaySectorStep;
    case 1:
    case 2:
        return (rand() % 2) * kDelaySectorStep + kDelaySectorStep;
    default:
        return 0;
    }
}

/** @ghidraAddress 0x1c6d0 */
- (void)addGhostTouches {
    if ((int)[self.mainGameRenderer state] != kRendererStatePlaying) {
        return;
    }
    unsigned int oldMask = self->buttonPressOld;
    unsigned int newMask = self->buttonPress;
    int now = GameViewControllerNowSector(self);
    if (now == 0) {
        return;
    }
    unsigned int pressed = newMask & ~oldMask;
    unsigned int released = oldMask & ~newMask;
    if (pressed != 0) {
        for (int panel = 0; panel < kGamePanelCount; ++panel) {
            if ((1u << (panel & 0x1f)) & pressed) {
                self->startSector[panel] = now;
            }
        }
    }
    if (released != 0) {
        for (int panel = 0; panel < kGamePanelCount; ++panel) {
            if ((1u << (panel & 0x1f)) & released) {
                unsigned int start = self->startSector[panel];
                self->startSector[panel] = 0;
                [self->ghostRecTouches
                    addObject:@[ @(start), @(panel), @((unsigned int)(now - start)) ]];
            }
        }
    }
}

/** @ghidraAddress 0x1c8fc */
- (NSString *)getGhostDirectoryPath {
    return [[JubeatAppDelegate appDocumentsDirectory] stringByAppendingPathComponent:kGhostDirName];
}

/** @ghidraAddress 0x1c960 */
- (void)setReplayData {
    if ([self->ghostRecTouches count] == 0) {
        return;
    }
    int panelWidth;
    int yOffset;
    GameViewControllerPanelMetrics(self, &panelWidth, &yOffset);

    NSMutableArray *playTouches = [[NSMutableArray alloc] init];
    for (NSArray *rec in self->ghostRecTouches) {
        int start = [rec[0] intValue];
        int panel = [rec[1] intValue];
        int duration = [rec[2] intValue];
        float x;
        float y;
        GameViewControllerPanelCenter(panel, panelWidth, yOffset, &x, &y);
        [playTouches addObject:@[ @(start), @[ @(x), @(y) ], @(duration) ]];
    }

    self->ghostPlayTouches = [NSArray arrayWithArray:playTouches];
}

/** @ghidraAddress 0x1cdd4 */
- (NSArray *)getGhostTouches {
    int now = GameViewControllerNowSector(self);
    if (self->currentGhostIndex < (int)[self->ghostPlayTouches count]) {
        int i = self->currentGhostIndex;
        NSMutableArray *result = nil;
        while (i < (int)[self->ghostPlayTouches count]) {
            int start = [self->ghostPlayTouches[i][0] intValue];
            NSArray *position = self->ghostPlayTouches[i][1];
            int duration = [self->ghostPlayTouches[i][2] intValue];
            int windowEnd = start + duration;
            if (start <= now && now <= windowEnd) {
                if (result == nil) {
                    result = [[NSMutableArray alloc] init];
                }
                [result addObjectsFromArray:@[ position ]];
            }
            if (windowEnd < now) {
                ++self->currentGhostIndex;
            }
            if ((int)[self->ghostPlayTouches count] <= self->currentGhostIndex) {
                break;
            }
            ++i;
        }
        if (result != nil) {
            return [NSArray arrayWithArray:result];
        }
    }
    return nil;
}

#pragma mark - Score persistence and networking

/** @ghidraAddress 0x121f8 */
- (void)saveScore {
    ScoreRecord *record = [ScoreRecord recordForTuneID:self.currentTune.tuneID];
    if (record == nil) {
        record = [ScoreRecord createRecordWithTuneID:self.currentTune.tuneID];
    } else if (![ScoreRecord checkScore:record]) {
        // The stored digest did not verify, so the record is treated as tampered and reset.
        [ScoreRecord reset:record];
    }

    const ScoreData *score = self.sequence.getScore;
    int poorMissCount = score->nMiss + score->nPoor;
    int totalPoint = score->totalPoint;

    switch (self.currentDiff) {
    case kGameDifficultyBasic: {
        if (record.scoBas.intValue < totalPoint) {
            record.scoBas = @(totalPoint);
        }
        unsigned char table[kMusicBarByteLength];
        GameViewControllerMergeMusicBar(record.mbBas, score, table);
        record.mbBas = [NSData dataWithBytes:table length:kMusicBarByteLength];
        if (self.sequence.isFullcombo) {
            record.fcBas = @YES;
        }
        if (record.pmBas.intValue > poorMissCount) {
            record.pmBas = @(poorMissCount);
        }
        break;
    }
    case kGameDifficultyAdvanced: {
        if (record.scoAdv.intValue < totalPoint) {
            record.scoAdv = @(totalPoint);
        }
        unsigned char table[kMusicBarByteLength];
        GameViewControllerMergeMusicBar(record.mbAdv, score, table);
        record.mbAdv = [NSData dataWithBytes:table length:kMusicBarByteLength];
        if (self.sequence.isFullcombo) {
            record.fcAdv = @YES;
        }
        if (record.pmAdv.intValue > poorMissCount) {
            record.pmAdv = @(poorMissCount);
        }
        break;
    }
    case kGameDifficultyExtreme: {
        if (record.scoExt.intValue < totalPoint) {
            record.scoExt = @(totalPoint);
        }
        unsigned char table[kMusicBarByteLength];
        GameViewControllerMergeMusicBar(record.mbExt, score, table);
        record.mbExt = [NSData dataWithBytes:table length:kMusicBarByteLength];
        if (self.sequence.isFullcombo) {
            record.fcExt = @YES;
        }
        if (record.pmExt.intValue > poorMissCount) {
            record.pmExt = @(poorMissCount);
        }
        break;
    }
    default:
        break;
    }

    record.chksco = [ScoreRecord hashScore:record];
    record.lastPlayDate = [NSDate date];
    record.playCount = @(record.playCount.intValue + 1);

    NSError *error = nil;
    if (![[ScoreRecordManager sharedManager].managedObjectContext save:&error]) {
        NSArray *detailedErrors = error.userInfo[NSDetailedErrorsKey];
        if (detailedErrors != nil && detailedErrors.count != 0) {
            for (NSError *detailedError in detailedErrors) {
                (void)detailedError; // The binary enumerates but does nothing with each error.
            }
        }
    }
}

/** @ghidraAddress 0x1d0dc */
- (void)sendChallengeScore {
    if (self->bBuildAutoFlag) {
        return;
    }
    self->bItemChance = NO;
    self->chanceItemType = kChanceItemTypeNone;
    self->chanceItemNum = 0;

    unsigned int tuneID = self.currentTune.tuneID;
    int score = self.sequence.getScore->totalPoint;
    unsigned int difficulty = self.currentDiff;
    ChallengeStatus *status = [ChallengeStatus sharedStatus];
    BOOL fullCombo = self.sequence.isFullcombo | self.sequence.isExcellent;

    NSDictionary *post = @{
        kScorePostScratchIDKey : status.scratchID,
        kScorePostSessionSeedKey : status.sessionSeed,
        kScorePostMusicIDKey : @(tuneID),
        kScorePostScoreKey : @(score),
        kScorePostDifficultyKey : @(difficulty),
        kScorePostIsFullComboKey : @(fullCombo),
    };

    SessionDownloader *uploader =
        [[SessionDownloader alloc] initWithURL:[ScratchUtil sendMusicScoreURL]
                                postDictionary:post
                                      delegate:self];
    uploader.tag = kDownloaderTagChallengeScore;
    uploader.apiTag = kApiTagSendMusicScore;
    [uploader startDownloading];
}

/** @ghidraAddress 0x1754c */
- (void)sessionDisconnect:(BOOL)showAlert {
    if (self.shareManager == nil) {
        return;
    }
    [self.shareManager disconnect];
    self.shareManager = nil;

    [self.mainGameRenderer setIsConnected:NO];

    unsigned int state = [self.mainGameRenderer state];
    if (state == kRendererStateReady || state == kRendererStateStarting ||
        state == kRendererStatePlaying) {
        [self.btnPause setHidden:NO];
    }

    if (showAlert) {
        if ([self.mainGameRenderer state] == kRendererStateReady) {
            if ([self.mainGameRenderer subState] == kRendererSubStateSessionWait) {
                [self.mainGameRenderer setState:kRendererStateStarting];
            }
        } else if ([self.mainGameRenderer state] == kRendererStateEnding) {
            if ([self.mainGameRenderer subState] == kRendererSubStateSessionWait) {
                [self.mainGameRenderer setState:kRendererStateEnded];
            }
        }
    }
}

#pragma mark - DownloaderDelegate

/** @ghidraAddress 0x1afe8 */
- (void)downloaderFinished:(id)downloader {
    NSDictionary *json = [downloader getDataInJSON];

    int status;
    if (json[kResponseStatusKey] == nil) {
        status = -1;
    } else {
        status = [json[kResponseStatusKey] intValue];
        if (status == kServerStatusServerError) {
            NSString *message =
                [NSBundle.mainBundle localizedStringForKey:kLocalizedServerErrorMsgKey
                                                     value:kEmptyLocalizedValue
                                                     table:nil];
            if (json[kResponseErrorMessageKey] != nil) {
                message = json[kResponseErrorMessageKey];
            }
            NSString *ok = [NSBundle.mainBundle localizedStringForKey:kLocalizedOKKey
                                                                value:kEmptyLocalizedValue
                                                                table:nil];
            [[AlertViewManager sharedManager] makeAlert:kAlertTypePlain
                                               delegate:nil
                                                    tag:kServerErrorAlertTag
                                                  title:kEmptyLocalizedValue
                                                    msg:message
                                                 cancel:ok
                                                btnText:nil
                                                   show:YES];
            return;
        }
        if (status == kServerStatusUpdateRequired) {
            [[AlertViewManager sharedManager] showUpdateAlert];
            return;
        }
    }

    if ([downloader tag] == kDownloaderTagChallengeScore) {
        if (status == kServerStatusItemChanceOK || status == 0) {
            if (json[kResponseItemTypeKey] != nil) {
                self->chanceItemType = [json[kResponseItemTypeKey] intValue];
                self->chanceItemNum = [json[kResponseItemNumKey] intValue];
            }
            if (self->chanceItemType >= 0) {
                self->bItemChance = YES;
            }
            [[ChallengeStatus sharedStatus] updateCubeState:json];
        } else if (json[kResponseErrorMessageKey] == nil) {
            [[AlertViewManager sharedManager] makeAlert:kAlertTypePlain
                                               delegate:self
                                                    tag:kRetrySendAlertTag
                                                  title:nil
                                                    msg:kRetrySendMessage
                                                 cancel:kAlertNo
                                                btnText:@[ kAlertYes ]
                                                   show:YES];
        } else {
            [[AlertViewManager sharedManager] makeAlert:kAlertTypePlain
                                               delegate:nil
                                                    tag:0
                                                  title:nil
                                                    msg:json[kResponseErrorMessageKey]
                                                 cancel:kAlertOK
                                                btnText:nil
                                                   show:YES];
        }
    }
}

/** @ghidraAddress 0x1b50c */
- (void)downloaderError:(id)downloader {
    if ([downloader tag] == kDownloaderTagChallengeScore) {
        [[AlertViewManager sharedManager] makeAlert:kAlertTypePlain
                                           delegate:self
                                                tag:kRetrySendAlertTag
                                              title:nil
                                                msg:kRetrySendMessage
                                             cancel:kAlertNo
                                            btnText:@[ kAlertYes ]
                                               show:YES];
    }
}

#pragma mark - SearchPackIDViewDelegate

/** @ghidraAddress 0x1a99c */
- (void)packIDSearchEnd:(id)packID {
    NSString *resolvedID = [NSString stringWithFormat:@"%@", [self->packSearchView getPackID]];
    [[JubeatAppDelegate appDelegate] setDownloadPackID:resolvedID];

    SearchPackIDView *searchView = self->packSearchView;
    __weak SearchPackIDView *weakSearchView = searchView;
    __weak UIView *weakCoverView = self->coverView;
    searchView.alpha = 1.0;
    weakCoverView.alpha = 1.0;
    [UIView animateWithDuration:kPackIDSearchFadeDuration
        animations:^{
          /** @ghidraAddress 0x1abf8 */
          weakCoverView.alpha = 0.0;
          weakSearchView.alpha = 0.0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x1acc0 */
          [self releaseSearchPackView];
          [self end];
        }];
}

/** @ghidraAddress 0x1ad08 */
- (void)packIDSearchCancel:(id)sender {
    SearchPackIDView *searchView = self->packSearchView;
    __weak SearchPackIDView *weakSearchView = searchView;
    __weak UIView *weakCoverView = self->coverView;
    searchView.alpha = 1.0;
    weakCoverView.alpha = 1.0;
    [UIView animateWithDuration:kPackIDSearchFadeDuration
        animations:^{
          /** @ghidraAddress 0x1aed0 */
          weakCoverView.alpha = 0.0;
          weakSearchView.alpha = 0.0;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x1af98 */
          [self releaseSearchPackView];
        }];
}

@end
