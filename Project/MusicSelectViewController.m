#import "MusicSelectViewController.h"

#import <QuartzCore/QuartzCore.h>

#import "AlertViewManager.h"
#import "BFCodec.h"
#import "BalloonView.h"
#import "ChallengeModeRootView.h"
#import "ChallengeStatus.h"
#import "Downloader.h"
#import "EditorIDManager.h"
#import "JcfDownloadPageNavController.h"
#import "JcfDownloadView.h"
#import "JubeatAppDelegate.h"
#import "KUnzip.h"
#import "LabUtilities.h"
#import "LicenseAgreementView.h"
#import "MarkerManager.h"
#import "MarkerSelectView.h"
#import "Md5Utilities.h"
#import "MusicDetailView.h"
#import "MusicListView.h"
#import "MusicPlaylistManager.h"
#import "MusicPlaylistViewController.h"
#import "MusicSelectBottomView.h"
#import "MusicShareView.h"
#import "MusicView.h"
#import "NSDictionary+PropertyList.h"
#import "NotificationPageNavController.h"
#import "PurchaseManager.h"
#import "PushNotificationView.h"
#import "RootViewController.h"
#import "RotatableNavigationController.h"
#import "ScoreRecord.h"
#import "ScratchUtil.h"
#import "SessionDownloader.h"
#import "SharePlayManager.h"
#import "StoreUtil.h"
#import "TuneInfo.h"
#import "cipher_keys.h"

extern const double g_dAnimDuration020; // @ghidraAddress 0x28f240 (0.2)

// Landscape-left and landscape-right make up the supported orientation mask.
static const UIInterfaceOrientationMask kSupportedOrientations =
    UIInterfaceOrientationMaskLandscapeLeft | UIInterfaceOrientationMaskLandscapeRight;

// The custom-BGM selection preferences: the chosen tune's id and whether the custom BGM is on.
static NSString *const kPrefCustomBgmIDKey = @"PrefCustomBgmID";
static NSString *const kPrefCustomBgmOnKey = @"PrefCustomBgmON";

// The menu BGM resumes with a one-fifth-second fade in when the app comes back to the foreground.
static const double kMenuBgmResumeFade = 0.2; // @ghidraAddress 0x28e040

// The extend-mode tutorial overlay fades out over this (negative, as the binary passes it)
// duration when the mode changes.
static const NSTimeInterval kExtendTutorialFadeDuration = -0.2; // @ghidraAddress 0x28e050

// The store-tap and challenge-tap sounds are looked up by these sound keys.
static NSString *const kStoreTapSoundKey = @"OK";
static NSString *const kChallengeTapSoundKey = @"MUSIC_SELECT";

// The challenge-mode root view sits on top of the menu at this layer z-position.
static const CGFloat kChallengeRootViewZPosition = 4000.0; // @ghidraAddress 0x28f238

// The challenge cover fades out over this duration.
static const NSTimeInterval kChallengeCoverFadeDuration = 0.3; // @ghidraAddress 0x28f260

// The challenge cover is a 40%-opaque black overlay carrying a 50-point activity indicator centred
// in it, and a one-second load-timeout timer.
static const CGFloat kChallengeCoverBackgroundAlpha = 0.4; // @ghidraAddress 0x28f2c0
static const CGFloat kChallengeIndicatorSize = 50.0;       // @ghidraAddress 0x28f2c8
static const NSTimeInterval kChallengeLoadTimeout = 1.0;   // fmov, 1.0

// The store update-time preference records the newest seen store timestamp.
static NSString *const kPrefStoreUpdateTimeKey = @"PrefStoreUpdateTime";

// The scratch (challenge) content update id preference; the challenge-new badge hides once the seen
// id catches up. The BGM fades out over this duration when launching challenge mode.
static NSString *const kPrefScratchUpdateIDKey = @"PrefScratchUpdateID";
static const double kChallengeBgmFadeOut = 0.5; // fmov, 0.5

// The marker button slides up out of view (or back) over this duration while the search box is
// lifted to sit above it at this z-position.
static const NSTimeInterval kButtonMarkerAnimDuration = 0.3; // @ghidraAddress 0x28f260
static const CGFloat kSearchBoxRaisedZPosition = 4000.0;     // @ghidraAddress 0x28f238

// The last-played tune id preference, used to bias the shuffle away from an immediate repeat.
static NSString *const kPrefLastPlayedIDKey = @"PrefLastPlayedID";

// The remembered playlist identifier and level-playlist flag preferences, and the new-info request
// URL query format.
static NSString *const kPrefLastPlaylistKey = @"PrefLastPlaylist";
static NSString *const kPrefPlayListLevelKey = @"PrefPlayListLevel";
static NSString *const kPrefPlayListHoldKey = @"PrefPlayListHold";
static NSString *const kNewInfoUserIDFormat = @"&userid=%@";
static NSString *const kNewInfoURLConcatFormat = @"%@%@";

// The marker-select view is a square (500 on the pad, 250 on the phone) hidden above the top of the
// screen, its width taken from a per-idiom pool value, sitting at this z-position.
static const CGFloat kMarkerSelectSizePad = 500.0;    // fmov via w, 500
static const CGFloat kMarkerSelectSizePhone = 250.0;  // fmov via w, 250
static const CGFloat kMarkerSelectWidthPad = 400.0;   // @ghidraAddress 0x28f308
static const CGFloat kMarkerSelectWidthPhone = 200.0; // @ghidraAddress 0x28f300
static const CGFloat kMarkerSelectZPosition = 3500.0; // @ghidraAddress 0x28f1e8

// Encoded strings decode as UTF-8.
static const NSStringEncoding kLabURLEncoding = NSUTF8StringEncoding;
static NSString *const kPrefJubeatLabURLKey = @"PrefjubeatLabURL";

// A received share payload appends a 16-byte MD5 digest over the preceding music data.
static const NSUInteger kShareMusicDigestLength = 16;

// The challenge-connect response carries a status code and an optional error message under these
// keys; two status codes are handled specially (an update prompt and a no-open-scratch message).
static NSString *const kChallengeStatusKey = @"status";
static NSString *const kChallengeErrorMessageKey = @"err_message";
static const int kChallengeStatusUpdateRequired = 100011;
static const int kChallengeStatusNoScratch = 205103;
static NSString *const kChallengeNoScratchMessage =
    @"現在開催されているチャレンジスクラッチは存在しません";

// The tune-info archive members, tried newest-first; the v3 payload is ciphered with the tune-info
// key and carries a four-byte header, the older members with the BGM key. Each archive skips a
// 16-byte trailer.
static NSString *const kInfoV3EntryName = @"infov3";
static NSString *const kInfoV2EntryName = @"infov2";
static NSString *const kInfoEntryName = @"info";
static const NSUInteger kTuneInfoArchiveTail = 16;
static const NSUInteger kTuneInfoV3HeaderLength = 4;

// A tune's own archive stores its BGM under this member (ciphered with the BGM key).
static NSString *const kTuneBgmEntryName = @"index";

// The join share view is a fixed size (pad 360x400, phone 300x360) centred on the screen and fades
// in over this duration.
static const CGFloat kJoinViewWidthPad = 360.0;          // @ghidraAddress 0x28f380
static const CGFloat kJoinViewHeightPad = 400.0;         // @ghidraAddress 0x28f390
static const CGFloat kJoinViewWidthPhone = 300.0;        // @ghidraAddress 0x28f388
static const CGFloat kJoinViewHeightPhone = 360.0;       // @ghidraAddress 0x28f398
static const NSTimeInterval kJoinViewFadeDuration = 0.2; // @ghidraAddress 0x28e040
static NSString *const kJoinSoundSuffix = @"MUSIC_SELECT";

// When the last-played tune sits on an earlier page, the stand-in detail music view is parked this
// many screen widths off to the left of centre so it slides in from that side.
static const CGFloat kDetailPanelOffscreenDirection = -4.0; // fmov, -4.0

// The shuffle animation fades the BGM out over this and plays the themed music-select cue. It runs
// as a slide (this duration) that pushes the detail view aside, then a flip whose whole duration is
// divided into thirds for the middle stage that swaps the tune data while the cover is edge-on.
static const CGFloat kShuffleBgmFadeOut = 0.075;         // @ghidraAddress 0x28f2b0
static const NSTimeInterval kShuffleSlideDuration = 0.1; // @ghidraAddress 0x28f2b8
static const CGFloat kShuffleFlipDuration = 0.1;         // fmov (float), 0.1
static const CGFloat kShuffleFlipStageDivisor = 3.0;     // fmov, 3.0
static NSString *const kShuffleSoundSuffix = @"MUSIC_SELECT";
// The detail view slides left by this many points; the pad slides 86, the phone 20.
static const int kShuffleSlideOffsetPad = 86;
static const int kShuffleSlideOffsetPhone = 20;

// The cover-flip 3D pose: a perspective m34 of -1/1000, a viewer distance that differs by idiom
// (iPhone 750, iPad 733.3333), a rotation of pi about the vertical axis for the front face and 2*pi
// for the back, and a shrink to a quarter (iPhone) or roughly a quarter (iPad).
static const CGFloat kCoverFlipPerspectiveM34 = -0.0010000000474974513; // movk, -1/1000
static const CGFloat kCoverFlipViewerDistancePhone = 750.0;             // @ghidraAddress 0x28f370
static const CGFloat kCoverFlipViewerDistancePad = 733.3333740234375;   // @ghidraAddress 0x28f378
static const CGFloat kCoverFlipScalePad = 0.2666666805744171;           // @ghidraAddress 0x28f270
static const CGFloat kCoverFlipScalePhone = 0.25;                       // fmov, 0.25
static const CGFloat g_dPi = 3.141592653589793;                         // @ghidraAddress 0x28f278
static const CGFloat g_dTwoPi = 6.283185307179586;                      // @ghidraAddress 0x28f298

// The custom-BGM archive member (ciphered with the BGM key, skipping the 16-byte trailer), the
// default menu BGM resource suffix, and the store-balloon animation key.
static NSString *const kCustomBgmEntryName = @"bgm";
static NSString *const kMenuBgmSoundSuffix = @"BGM_MENU";
static NSString *const kStoreBalloonAnimationKey = @"STORE_BALLOON_ANIM";

// The main BGM starts with this fade, and the store balloon fades out over the same duration.
static const NSTimeInterval kMainBgmStartFade = 0.3;         // @ghidraAddress 0x28f260
static const NSTimeInterval kStoreBalloonFadeDuration = 0.3; // @ghidraAddress 0x28f260

// Re-showing the store balloon nudges it down by this offset, then fades and re-runs its looping
// double-bounce hop animation over this duration.
static const CGFloat kStoreBalloonRetryDropOffset = 10.0;     // fmov, 10.0
static const NSTimeInterval kStoreBalloonRetryDuration = 0.8; // @ghidraAddress 0x28e060
static NSString *const kStoreBalloonAnimationKeyPath = @"transform.translation.y";
// The balloon rests for the first 40% of each five-second cycle, then performs two four-point
// upward hops before resting again; the animation repeats effectively forever.
static const CGFloat kStoreBalloonAnimationDuration = 5.0; // fmov, 5.0
static const CGFloat kStoreBalloonHopOffset = -4.0;        // fmov, -4.0
static const float kStoreBalloonRepeatForever = 1e30f;     // @ghidraAddress 0x28f3c4
static const CGFloat kStoreBalloonKeyTime040 = 0.4;        // @ghidraAddress 0x28f3b4
static const CGFloat kStoreBalloonKeyTime050 = 0.5;        // fmov, 0.5
static const CGFloat kStoreBalloonKeyTime060 = 0.6;        // @ghidraAddress 0x28f3b8
static const CGFloat kStoreBalloonKeyTime070 = 0.7;        // @ghidraAddress 0x28f3bc
static const CGFloat kStoreBalloonKeyTime080 = 0.8;        // @ghidraAddress 0x28f3c0

// The JCF download view and its cover fade out over this (negative, as the binary passes it)
// duration when the download completes.
static const NSTimeInterval kJcfDownloadEndFadeDuration = -0.2; // @ghidraAddress 0x28e050

// Closing the search box slides it and its cancel button up by this offset over this duration,
// playing the themed left cue.
static const NSTimeInterval kSearchBoxSlideDuration = 0.1; // @ghidraAddress 0x28f290
static const CGFloat kSearchBoxSlideOffset = -52.0;        // @ghidraAddress 0x28f228
static NSString *const kSearchBoxCloseSoundSuffix = @"MUSIC_LEFT";

// Completing a challenge-purchase restore records this marker under the restore-end preference and
// shows the completion alert (tag 3).
static NSString *const kRestoreCompleteMarker = @"Restore Complete";
static NSString *const kPrefChallengeRestoreEndKey = @"PrefChallengeRestoreEnd";
static const int kRestoreCompleteAlertTag = 3;

// Turning to the store while a consume receipt is pending records this verify-purchase type and
// shows the verify dialog; a completed purchase reports the shared success message. The
// challenge-info download path uses the other pending type.
static const int kVerifyPurchaseTypeStore = 2;
static const int kVerifyPurchaseTypeChallenge = 1;

// The challenge-info download reads the current marker into the client-info payload, gates on the
// challenge-policy agreement recorded under this defaults key, and requires the purchased packs to
// have been restored before it will run.
static NSString *const kPrefCurrentMarkerIDKey = @"PrefCurrentMarkerID";
static NSString *const kClientInfoMarkerIDKey = @"markerID";
static NSString *const kPrefAgreeChallengePolicyVersionKey = @"PrefAgreeChallengePolicyVersion";
static NSString *const kChallengePolicyRestoreRequiredMessage =
    @"チャレンジモードをプレイする前に、購入パックの復元を行う必要があります";

// The challenge-info request's apiTag: a full initialise before the challenge state is loaded, or a
// simple re-initialise once it already is. The downloader itself carries the challenge tag.
enum {
    kChallengeApiTagInitialize = 2,
    kChallengeApiTagSimpleInitialize = 3,
};
static const int kChallengeInfoDownloaderTag = 1;
static NSString *const kPurchaseSuccessMessage = @"購入処理が完了しました";
static NSString *const kSettingsTapSoundSuffix = @"MUSIC_RIGHT";
static NSString *const kVerifyProcessingMessage = @"処理中...";
static NSString *const kRestoreProcessingMessage = @"復元中...";

// The alert-select dictionary carries the tapped alert's tag and button index under these keys; the
// tags select the challenge-info download, the restore, the store/challenge retry, or a share
// cancel.
static NSString *const kAlertTagKey = @"Tag";
static NSString *const kAlertButtonMessageKey = @"btnMessage";
enum {
    kAlertTagShareCancel = 0,
    kAlertTagRetry = 1,
    kAlertTagRestore = 2,
    kAlertTagChallengeInfo = 3,
};

// The main BGM start voice cue, and the fixed music cues used when closing the web view or opening
// the notification (the binary hardcodes the Knit-theme resources for these).
static NSString *const kMainBgmVoiceSuffix = @"CV_MUSICSELECT";
static NSString *const kWebViewCloseSound = @"SD_KNT_MUSIC_LEFT";
static NSString *const kNotificationOpenSound = @"SD_KNT_MUSIC_RIGHT";

// The built-in playlist selections map to these sentinel indices in the playlist view controller.
enum {
    kPlaylistSelectionLevel = -10,
    kPlaylistSelectionHold = -11,
    kPlaylistSelectionNotHold = -12,
    kPlaylistSelectionNotPlayed = -1,
    kPlaylistSelectionDefault = -2,
};

// A tune matches a level when any of its three chart levels equals it, or its extend chart (looked
// up by extendID) has a matching level.
static BOOL MusicSelectTuneHasLevel(MusicSelectViewController *self, TuneInfo *tune, int level) {
    if ((int)tune.lvAdv == level || (int)tune.lvBas == level || (int)tune.lvExt == level) {
        return YES;
    }
    if (tune.extendID != 0) {
        TuneInfo *extend = self->dictAllExtendTune[@(tune.extendID)];
        if ((int)extend.lvAdv == level || (int)extend.lvBas == level ||
            (int)extend.lvExt == level) {
            return YES;
        }
    }
    return NO;
}

// A tune counts as a hold chart when its own hold flag is set or its extend chart (looked up by
// extendID) has a hold flag.
static BOOL MusicSelectTuneIsHold(MusicSelectViewController *self, TuneInfo *tune) {
    if (tune.holdFlag != 0) {
        return YES;
    }
    if (tune.extendID != 0) {
        TuneInfo *extend = self->dictAllExtendTune[@(tune.extendID)];
        if (extend.holdFlag != 0) {
            return YES;
        }
    }
    return NO;
}

@implementation MusicSelectViewController

@synthesize sharePlayManager = _sharePlayManager;

#pragma mark - Lifecycle

/** @ghidraAddress 0x38f04 */
- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
    [infoDownloader cancel];
    [infoBannerTimer invalidate];
    if (challengeModeView != nil) {
        [challengeModeView removeFromSuperview];
        challengeModeView = nil;
    }
    // [super dealloc] is compiler-emitted (ARC).
}

#pragma mark - View lifecycle

/** @ghidraAddress 0x31e40 */
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

/** @ghidraAddress 0x32ae4 */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

/** @ghidraAddress 0x32b1c */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self becomeFirstResponder];
}

/** @ghidraAddress 0x32b70 */
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

/** @ghidraAddress 0x32ba8 */
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

/** @ghidraAddress 0x31b98 */
- (void)appSuspended:(nullable id)notification {
    [self hiddenCoverView];
    [markerSelectView pauseAnimation];
    [self stopStoreInfo];
    [bottomView animStop];
    [imgStoreNew.layer removeAllAnimations];
    [imgStoreNew setHidden:YES];
    [btnChallenge.titleLabel.layer removeAllAnimations];
    [imgChallengeNew.layer removeAllAnimations];
    [imgChallengeNew setHidden:YES];
    // A live share session is torn down: the host that has started disconnects, otherwise the
    // pending share is cancelled.
    if (self.sharePlayManager != nil) {
        if (willStart) {
            [self.sharePlayManager disconnect];
            self.sharePlayManager = nil;
        } else {
            [self cancelShare:YES];
        }
    }
}

/** @ghidraAddress 0x31da4 */
- (void)appResumed:(nullable id)notification {
    [markerSelectView resumeAnimation];
    if (mainBgmSuspended) {
        [[AudioManager sharedManager] startBgm:YES fadeTime:kMenuBgmResumeFade];
        mainBgmSuspended = NO;
    }
    [self requestNewInfo];
}

#pragma mark - Music list

/** @ghidraAddress 0x22984 */
- (void)changeMusicListView:(NSInteger)listType musicID:(NSUInteger)musicID {
    [self changeMusicListView:listType musicID:musicID isFirst:NO];
}

/** @ghidraAddress 0x29fbc */
- (unsigned int)numberOfMusic {
    NSArray *list = arrayCurrentPlaylist ?: arrayAllTune;
    return (unsigned int)list.count;
}

/** @ghidraAddress 0x2aeec */
- (void)musicPlaylistViewControllerWillClosed:(nullable id)controller {
    if (playlistViewCtrl.listMode == MusicPlaylistListModeAddToPlaylist) {
        [musicListView hideAllPlaylistAction];
    }
    playlistViewCtrl = nil;
    playlistNavCtrl = nil;
    [self dismissViewControllerAnimated:YES
                             completion:^{
                             }];
    bOpenModal = NO;
    [self musicShuffleEnable];
}

/** @ghidraAddress 0x36cb0 */
- (void)updateMusicList {
    [self refreshMusicList];
    [musicListView updateViews];
    [markerSelectView updateMarkerList];
}

/** @ghidraAddress 0x33330 */
- (void)downloadEnd:(nullable id)sender musicID:(nullable id)musicID {
    [musicListView addDownloadMark:[musicID intValue]];
}

/** @ghidraAddress 0x329d4 */
- (void)markerSelectChanged:(nullable id)sender {
    [btnMarkerImg setImage:[markerSelectView getCurrentBanner]];
}

/** @ghidraAddress 0x2ca38 */
- (void)musicViewSelectBgmAction:(nullable id)musicView {
    // Re-tapping the current custom-BGM tune clears the preference; any other tune sets it.
    unsigned int tuneID = ((MusicView *)musicView).tuneInfo.tuneID;
    NSInteger current = [NSUserDefaults.standardUserDefaults integerForKey:kPrefCustomBgmIDKey];
    if (tuneID == current) {
        [NSUserDefaults.standardUserDefaults removeObjectForKey:kPrefCustomBgmIDKey];
        [NSUserDefaults.standardUserDefaults removeObjectForKey:kPrefCustomBgmOnKey];
    } else {
        [NSUserDefaults.standardUserDefaults setInteger:tuneID forKey:kPrefCustomBgmIDKey];
        [NSUserDefaults.standardUserDefaults setBool:YES forKey:kPrefCustomBgmOnKey];
    }
    [NSUserDefaults.standardUserDefaults synchronize];
    [self setupMainBgm];
    [musicListView refreshTextColor];
}

/** @ghidraAddress 0x2a228 */
- (nullable id)extendMusicInfoForMusicID:(unsigned int)musicID {
    return dictAllExtendTune[@(musicID)];
}

/** @ghidraAddress 0x2a298 */
- (nullable id)addMusicArray {
    return arrayAddList;
}

/** @ghidraAddress 0x2a2a8 */
- (nullable id)removeMusicArray {
    return arrayDeleteList;
}

#pragma mark - Rotation

/** @ghidraAddress 0x32be0 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
    // The two landscape orientations are UIInterfaceOrientationLandscapeLeft (1) and Right (2).
    return (orientation - 1) < 2;
}

/** @ghidraAddress 0x32bf0 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return kSupportedOrientations;
}

/** @ghidraAddress 0x32bf8 */
- (BOOL)shouldAutorotate {
    return YES;
}

#pragma mark - Shake

/** @ghidraAddress 0x358d4 */
- (BOOL)canBecomeFirstResponder {
    return YES;
}

/** @ghidraAddress 0x35854 */
- (BOOL)checkShakeEvent:(nullable id)event {
    // A shake counts only while shuffle is enabled and the event is a motion-shake.
    return bEnableShuffle && ((UIEvent *)event).type == UIEventTypeMotion &&
           ((UIEvent *)event).subtype == UIEventSubtypeMotionShake;
}

/** @ghidraAddress 0x358dc */
- (void)motionBegan:(UIEventSubtype)motion withEvent:(nullable UIEvent *)event {
    [self checkShakeEvent:event];
}

/** @ghidraAddress 0x358ec */
- (void)motionCancelled:(UIEventSubtype)motion withEvent:(nullable UIEvent *)event {
    [self checkShakeEvent:event];
}

/** @ghidraAddress 0x358fc */
- (void)motionEnded:(UIEventSubtype)motion withEvent:(nullable UIEvent *)event {
    if ([self checkShakeEvent:event]) {
        [self setRandomSelect];
    }
}

#pragma mark - Buttons

/** @ghidraAddress 0x3478c */
- (void)btnTouchesBegan:(nullable id)sender {
    [self setEnableGesture:NO];
}

/** @ghidraAddress 0x3479c */
- (void)btnTouchesCancel:(nullable id)sender {
    [self setEnableGesture:YES];
}

/** @ghidraAddress 0x347ac */
- (void)setEnableGesture:(BOOL)enable {
    // Gestures (and shuffle and search) stay off during a share session.
    BOOL on = (self.sharePlayManager == nil) && enable;
    bEnableShuffle = on;
    [self setSearchEnable:on];
}

/** @ghidraAddress 0x2ca20 */
- (void)musicViewPressed:(nullable id)sender {
    [musicListView hideAllPlaylistAction];
}

/** @ghidraAddress 0x2cfac */
- (NSUInteger)musicViewGetPlaylistActionType:(nullable id)musicView {
    // The not-played, level, hold, and not-hold system lists offer no add/remove action; a real
    // user playlist reports action type 1.
    id source = currentPlaylistSource;
    if (source == nil || source == arrayNotPlayedTune || source == arrayLevelList ||
        source == arrayHoldList || source == arrayNotHoldList) {
        return 0;
    }
    return 1;
}

/** @ghidraAddress 0x36c94 */
- (void)challengeModeEnable:(BOOL)enable {
    [btnChallenge setEnabled:YES];
}

#pragma mark - Play flow

/** @ghidraAddress 0x2ea0c */
- (void)resetWillStart {
    willStart = NO;
}

/** @ghidraAddress 0x2e9f8 */
- (void)willStartPlay {
    willStart = YES;
}

/** @ghidraAddress 0x34810 */
- (void)musicShuffleEnable {
    // Shuffle stays disabled while a share-play session is active.
    if (self.sharePlayManager == nil) {
        bEnableShuffle = YES;
    }
}

/** @ghidraAddress 0x3485c */
- (void)musicShuffleDisable {
    bEnableShuffle = NO;
}

/** @ghidraAddress 0x36b34 */
- (void)musicListScrollBegin {
    [searchBox resignFirstResponder];
}

/** @ghidraAddress 0x37094 */
- (void)refreshRatingChip {
    [musicListView refreshRatingChip];
}

#pragma mark - Search

/** @ghidraAddress 0x36b30 */
- (void)searchBar:(nullable UISearchBar *)searchBar
    selectedScopeButtonIndexDidChange:(NSInteger)selectedScope {
}

#pragma mark - Lab, challenge, and store

/** @ghidraAddress 0x34754 */
- (void)tapJubeatLab:(nullable id)sender {
    [self setEnableGesture:YES];
    [self JcfDownLoadTopPage];
}

/** @ghidraAddress 0x38a50 */
- (void)agreementFailed:(nullable id)sender {
    [sender removeFromSuperview];
    [self hideChallengeCoverView];
}

/** @ghidraAddress 0x382d0 */
- (void)hideVerifyDialog {
    [verifyDialog removeFromSuperview];
    verifyDialog = nil;
}

/** @ghidraAddress 0x36d04 */
- (void)tapChallengeMode:(nullable id)sender {
    [[AudioManager sharedManager] playSeResFile:[self soundName:kChallengeTapSoundKey]
                                    inDirectory:nil];
    [self downloadChallengeInfo];
}

/** @ghidraAddress 0x27694 */
- (void)tapStoreInfo:(nullable id)info {
    [self setEnableGesture:YES];
    if (info != nil) {
        // A store-info entry that carries no challenge marker opens the store; otherwise it starts
        // the challenge download.
        if (((NSDictionary *)info)[@"challenge"] == nil) {
            [self turnToStore:info];
        } else {
            [self downloadChallengeInfo];
        }
    }
}

/** @ghidraAddress 0x32a34 */
- (void)tapStore:(nullable id)sender {
    [self setEnableGesture:YES];
    [[AudioManager sharedManager] playSeResFile:[self soundName:kStoreTapSoundKey] inDirectory:nil];
    [self turnToStore:nil];
}

/** @ghidraAddress 0x387d0 */
- (void)successIDDownload:(nullable id)sender {
    idManager = nil;
    [self downloadChallengeInfo];
}

/** @ghidraAddress 0x389e4 */
- (void)agreementSuccess:(nullable id)sender {
    checkPolicy = YES;
    [self downloadChallengeInfo];
    [sender removeFromSuperview];
}

/** @ghidraAddress 0x38a88 */
- (void)restoreFailed:(nullable id)sender {
    [self hideChallengeCoverView];
    PurchaseManager.sharedManager.delegate = nil;
    [self hideVerifyDialog];
}

/** @ghidraAddress 0x38fe8 */
- (void)scrollOffset:(float)offset {
    if (scrollBg == nil) {
        return;
    }
    int page = (scrollPageNum - 1) * (int)scrollBg.frame.size.width;
    int clamped = (offset < 0) ? 0 : (int)offset;
    int column = (page != 0) ? (clamped / page) : 0;
    [scrollBg setContentOffset:CGPointMake((double)(clamped - column * page), 0.0)];
}

#pragma mark - Notifications and challenge

/** @ghidraAddress 0x27cf8 */
- (void)pushNotificate {
    // A queued notification banner shows only when no modal, detail, settings, or challenge screen
    // is open.
    if (!bOpenChallenge && !bOpenMusicDetail && !bOpenSetting && !bOpenModal) {
        [notificationView startNotification];
    }
}

/** @ghidraAddress 0x37c24 */
- (void)loadTimeOver:(nullable id)sender {
    [indicatorTimer invalidate];
    indicatorTimer = nil;
    [indicatorChallenge startAnimating];
}

#pragma mark - Popover

/** @ghidraAddress 0x275dc */
- (BOOL)popoverPresentationControllerShouldDismissPopover:
    (nullable UIPopoverPresentationController *)popoverPresentationController {
    if (playlistViewCtrl.listMode == MusicPlaylistListModeAddToPlaylist) {
        [musicListView hideAllPlaylistAction];
    }
    return YES;
}

/** @ghidraAddress 0x27634 */
- (void)popoverPresentationControllerDidDismissPopover:
    (nullable UIPopoverPresentationController *)popoverPresentationController {
    playlistViewCtrl = nil;
    playlistNavCtrl = nil;
    [self JcfDownLoad];
    [self musicShuffleEnable];
}

#pragma mark - Cover tap and download view

/** @ghidraAddress 0x32c00 */
- (void)unenableCoverTap {
    [coverView setGestureRecognizers:nil];
    if (searchArray == nil) {
        [self showButtonMarker:NO];
    }
    [self musicShuffleDisable];
}

/** @ghidraAddress 0x32c68 */
- (void)enableCoverTap {
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:musicDetailView
                                                                          action:@selector(close)];
    [coverView addGestureRecognizer:tap];
    if (searchArray == nil) {
        [self showButtonMarker:YES];
    }
    [self musicShuffleEnable];
}

/** @ghidraAddress 0x3301c */
- (void)removeDownloadView {
    [jcfDownloadView removeFromSuperview];
    jcfDownloadView = nil;
    [coverView setHidden:YES];
    [self enableCoverTap];
}

#pragma mark - Jcf download

/** @ghidraAddress 0x32fa0 */
- (void)JcfDownLoad {
    [self JcfDownLoad:JubeatAppDelegate.appDelegate.jcfDownloadID];
}

#pragma mark - Search

/** @ghidraAddress 0x36720 */
- (void)handleSwipe:(nullable UISwipeGestureRecognizer *)recognizer {
    // A downward swipe pulls the search box in; a rightward swipe pushes it away.
    if (recognizer.direction == UISwipeGestureRecognizerDirectionDown) {
        [self pullSearchBox];
    } else if (recognizer.direction == UISwipeGestureRecognizerDirectionRight) {
        [self pushSearchBox];
    }
}

/** @ghidraAddress 0x36780 */
- (void)tapSearchCancel:(nullable id)sender {
    [self setEnableGesture:YES];
    [searchBox setText:@""];
    backUpString = @"";
    [self pushSearchBox];
}

/** @ghidraAddress 0x36aa8 */
- (void)searchBarSearchButtonClicked:(nullable UISearchBar *)searchBar {
    if ([self searchStringChanged:searchBar.text]) {
        [self exeSearchPickUp];
    }
    [searchBox resignFirstResponder];
}

#pragma mark - Host select

/** @ghidraAddress 0x31b30 */
- (void)sharePlayManagerHostSelectStart:(nullable id)manager {
    willStart = YES;
    [self startPlay:musicDetailView.info];
}

#pragma mark - Share play

/** @ghidraAddress 0x2ff10 */
- (void)shareHostSelected:(nullable id)host {
    [self.sharePlayManager sendConnectRequest:host];
    [shareClientView changeClientModeConnecting];
}

/** @ghidraAddress 0x30480 */
- (void)sharePlayManagerFailedSendMusicData:(nullable id)manager {
}

/** @ghidraAddress 0x30948 */
- (void)sharePlayManagerConnectHost:(nullable id)manager {
    [shareClientView changeClientModeConnected];
}

/** @ghidraAddress 0x31818 */
- (void)sharePlayManager:(nullable id)manager receiveProgress:(float)progress {
    [musicDetailView.shareDataProgress setProgress:progress];
}

/** @ghidraAddress 0x30b6c */
- (void)sharePlayManager:(nullable id)manager findHostID:(nullable id)hostID {
    [shareClientView addHost:hostID];
}

/** @ghidraAddress 0x30b88 */
- (void)sharePlayManager:(nullable id)manager lostHostID:(nullable id)hostID {
    [shareClientView removeHostTmp:hostID];
}

/** @ghidraAddress 0x30484 */
- (void)sharePlayManagerAllClientReady:(nullable id)manager {
    [musicDetailView.labelShareMessage
        setText:[NSBundle.mainBundle localizedStringForKey:@"Ready to start" value:@"" table:nil]];
    [musicDetailView.buttonStartPlay setEnabled:YES];
    [musicDetailView setIsSharedStartable:YES];
    [musicDetailView setStartButtonEnable];
}

/** @ghidraAddress 0x31874 */
- (BOOL)sharePlayManager:(nullable id)manager musicDataReceived:(nullable id)musicData {
    // The payload carries a trailing MD5 digest over the music bytes; reject a mismatch.
    NSData *data = musicData;
    if (data.length > kShareMusicDigestLength) {
        unsigned char digest[16];
        [data getBytes:digest
                 range:NSMakeRange(data.length - kShareMusicDigestLength, kShareMusicDigestLength)];
        if (VerifyMd5Digest(data.bytes, (int)data.length - (int)kShareMusicDigestLength, digest)) {
            [musicDetailView loadContentFromPath:nil orData:data];
            shareMusicData = data;
            [musicDetailView.buttonStartPlay setEnabled:YES];
            [musicDetailView setIsSharedStartable:YES];
            [musicDetailView setStartButtonEnable];
            [musicDetailView.labelShareMessage
                setText:[NSString stringWithFormat:[NSBundle.mainBundle
                                                       localizedStringForKey:@"Connected to %@"
                                                                       value:@""
                                                                       table:nil],
                                                   self.sharePlayManager.partnerScreenName]];
            [musicDetailView showDataProgress:NO animated:YES];
            return YES;
        }
    }
    return NO;
}

/** @ghidraAddress 0x30140 */
- (void)sharePlayManagerConnectClient:(nullable id)manager {
    [musicDetailView.labelShareMessage
        setText:[NSString
                    stringWithFormat:[NSBundle.mainBundle localizedStringForKey:@"Connected to %@"
                                                                          value:@""
                                                                          table:nil],
                                     self.sharePlayManager.partnerScreenName]];
}

/** @ghidraAddress 0x30340 */
- (void)sharePlayManagerSuccessSendMusicData:(nullable id)manager {
    [musicDetailView.labelShareMessage
        setText:[NSString
                    stringWithFormat:[NSBundle.mainBundle localizedStringForKey:@"Connected to %@"
                                                                          value:@""
                                                                          table:nil],
                                     self.sharePlayManager.partnerScreenName]];
}

/** @ghidraAddress 0x2effc */
- (void)startHostShare:(nullable id)musicInfo filePath:(nullable id)filePath {
    NSString *screenName = JubeatAppDelegate.appDelegate.gameCenterName;
    [musicDetailView setIsSharedStartable:NO];
    self.sharePlayManager = [[SharePlayManager alloc] initWithScreenName:screenName];
    [self.sharePlayManager setDelegate:self];
    [self.sharePlayManager startHostModeWithMusicInfo:musicInfo filePath:filePath];
    [self musicShuffleDisable];
}

/** @ghidraAddress 0x3073c */
- (void)sharePlayManager:(nullable id)manager disconnectClient:(nullable id)client {
    // A host that has started drops the session; otherwise the host is told a client disconnected.
    if (willStart) {
        [self.sharePlayManager disconnect];
        self.sharePlayManager = nil;
        return;
    }
    [[AlertViewManager sharedManager]
        makeAlert:0
         delegate:self
              tag:0
            title:[NSBundle.mainBundle localizedStringForKey:@"Error" value:@"" table:nil]
              msg:[NSBundle.mainBundle localizedStringForKey:@"SessionDisconnectedFromClientMessage"
                                                       value:@""
                                                       table:nil]
           cancel:[NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil]
          btnText:nil
             show:YES];
}

/** @ghidraAddress 0x30960 */
- (void)sharePlayManagerDisconnect:(nullable id)manager {
    // A host that has already started simply drops the session; otherwise the client is told the
    // host disconnected.
    if (willStart) {
        [self.sharePlayManager disconnect];
        self.sharePlayManager = nil;
        return;
    }
    [[AlertViewManager sharedManager]
        makeAlert:0
         delegate:self
              tag:0
            title:[NSBundle.mainBundle localizedStringForKey:@"Error" value:@"" table:nil]
              msg:[NSBundle.mainBundle localizedStringForKey:@"SessionDisconnectedFromHostMessage"
                                                       value:@""
                                                       table:nil]
           cancel:[NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil]
          btnText:nil
             show:YES];
}

/** @ghidraAddress 0x305a0 */
- (void)sharePlayManagerConnectFailed:(nullable id)manager {
    [[AlertViewManager sharedManager]
        makeAlert:0
         delegate:self
              tag:0
            title:[NSBundle.mainBundle localizedStringForKey:@"Error" value:@"" table:nil]
              msg:[NSBundle.mainBundle localizedStringForKey:@"SessionConnectErrorMessage"
                                                       value:@""
                                                       table:nil]
           cancel:[NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil]
          btnText:nil
             show:YES];
}

/** @ghidraAddress 0x30280 */
- (void)sharePlayManager:(nullable id)manager receiveExistMusicData:(BOOL)exist {
    // Only when the client lacks the music does the host show the sending-data prompt.
    if (exist) {
        return;
    }
    [musicDetailView.labelShareMessage
        setText:[NSBundle.mainBundle localizedStringForKey:@"Sending music data"
                                                     value:@""
                                                     table:nil]];
}

#pragma mark - BGM

/** @ghidraAddress 0x27f70 */
- (void)setupMainBgm {
    AudioManager *audio = [AudioManager sharedManager];
    int customID = (int)[NSUserDefaults.standardUserDefaults integerForKey:kPrefCustomBgmIDKey];
    BOOL customOn = [NSUserDefaults.standardUserDefaults boolForKey:kPrefCustomBgmOnKey];
    BOOL loaded = NO;
    if (customID != 0 && customOn) {
        // Find the chosen custom-BGM tune and load its deciphered bgm archive member.
        TuneInfo *tune = nil;
        for (TuneInfo *candidate in arrayAllTune) {
            if ((int)candidate.tuneID == customID) {
                tune = candidate;
            }
        }
        KUnzip *archive = [[KUnzip alloc] initWithPath:tune.filePath tail:kTuneInfoArchiveTail];
        if (archive != nil) {
            NSMutableData *bgm = [archive uncompress:kCustomBgmEntryName];
            if (bgm != nil) {
                BFCodec *codec = [[BFCodec alloc] init];
                [codec cipherInit:GetBgmCipherKey()];
                [codec decipher:bgm];
                loaded = [audio loadBgmData:bgm];
            }
        }
    }
    if (!loaded) {
        [audio loadBgmResAAC:[self soundName:kMenuBgmSoundSuffix] inDirectory:nil];
    }
    [audio startBgm:YES fadeTime:kMainBgmStartFade];
}

/** @ghidraAddress 0x274f8 */
- (void)tapBgmSwitch:(nullable id)sender {
    BOOL on = [NSUserDefaults.standardUserDefaults boolForKey:kPrefCustomBgmOnKey];
    [NSUserDefaults.standardUserDefaults setBool:!on forKey:kPrefCustomBgmOnKey];
    [NSUserDefaults.standardUserDefaults synchronize];
    [self setupMainBgm];
}

/** @ghidraAddress 0x282a4 */
- (void)startMainBgm {
    if (JubeatAppDelegate.appDelegate.bChallengeMode) {
        return;
    }
    [self setupMainBgm];
    [[AudioManager sharedManager] playSeResFile:[self soundName:kMainBgmVoiceSuffix]
                                    inDirectory:nil];
}

/** @ghidraAddress 0x2838c */
- (void)checkAndRetryBgm {
    if (JubeatAppDelegate.appDelegate.bChallengeMode) {
        return;
    }
    if (![AudioManager sharedManager].bgmPlayer.isPlaying) {
        [self setupMainBgm];
    }
    if (balloonView == nil) {
        return;
    }
    balloonView.transform = CGAffineTransformMakeTranslation(0, kStoreBalloonRetryDropOffset);
    __weak BalloonView *weakBalloon = balloonView;
    [UIView animateWithDuration:kStoreBalloonRetryDuration
        animations:^{
          /** @ghidraAddress 0x2859c */
          weakBalloon.alpha = 1.0;
          weakBalloon.transform = CGAffineTransformIdentity;
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x28634 */
          CAKeyframeAnimation *animation =
              [CAKeyframeAnimation animationWithKeyPath:kStoreBalloonAnimationKeyPath];
          animation.duration = kStoreBalloonAnimationDuration;
          animation.values = @[
              @(0.0f),
              @(0.0f),
              @(kStoreBalloonHopOffset),
              @(0.0f),
              @(kStoreBalloonHopOffset),
              @(0.0f),
              @(0.0f)
          ];
          animation.keyTimes = @[
              @(0.0f),
              @(kStoreBalloonKeyTime040),
              @(kStoreBalloonKeyTime050),
              @(kStoreBalloonKeyTime060),
              @(kStoreBalloonKeyTime070),
              @(kStoreBalloonKeyTime080),
              @(1.0f)
          ];
          animation.repeatCount = kStoreBalloonRepeatForever;
          animation.timingFunction =
              [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
          animation.removedOnCompletion = NO;
          [weakBalloon.layer addAnimation:animation forKey:kStoreBalloonAnimationKey];
          weakBalloon.userInteractionEnabled = YES;
        }];
}

#pragma mark - Share join

/** @ghidraAddress 0x2f930 */
- (void)pushBtnJoin:(nullable id)sender {
    [[AudioManager sharedManager] playSeResFile:[self soundName:kJoinSoundSuffix] inDirectory:nil];
    [self showButtonMarker:NO];
    [coverView setHidden:NO];
    [coverView setAlpha:0.0];
    CGFloat width = isPad ? kJoinViewWidthPad : kJoinViewWidthPhone;
    CGFloat height = isPad ? kJoinViewHeightPad : kJoinViewHeightPhone;
    shareClientView = [[MusicShareView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    [shareClientView
        setCenter:CGPointMake(self.view.frame.size.width * 0.5, self.view.frame.size.height * 0.5)];
    [shareClientView setController:self];
    [shareClientView changeClientModeSearch];
    [shareClientView setAlpha:0.0];
    [self.view insertSubview:shareClientView aboveSubview:coverView];
    self.sharePlayManager =
        [[SharePlayManager alloc] initWithScreenName:JubeatAppDelegate.appDelegate.gameCenterName];
    [self.sharePlayManager setDelegate:self];
    __weak UIView *weakCover = coverView;
    __weak MusicShareView *weakShare = shareClientView;
    __weak SharePlayManager *weakManager = self.sharePlayManager;
    [UIView animateWithDuration:kJoinViewFadeDuration
        animations:^{
          /** @ghidraAddress 0x2fdf4 */
          [weakShare setAlpha:1.0];
          [weakCover setAlpha:1.0];
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x2fec8 */
          [weakManager startClient];
        }];
    [self musicShuffleDisable];
    [self setSearchEnable:NO];
}

#pragma mark - Sound and store navigation

/** @ghidraAddress 0x26d88 */
- (void)turnToStore {
    [notificationView stopNotification];
    id params = storeParams;
    storeParams = nil;
    if (bOpenSearchBox) {
        [searchBox setText:[NSString stringWithString:backUpString]];
        bOpenSearchBox = NO;
        [self pushSearchBox];
    }
    [self popoverClose];
    [self stopStoreInfo];
    [musicListView releaseArtworks];
    [JubeatAppDelegate.appDelegate.rootViewCtrl openStore:params];
    // Record the newest store update time seen (numeric comparison), persisting it when newer.
    if (storeUpdateTime != nil) {
        NSString *stored =
            [NSUserDefaults.standardUserDefaults stringForKey:kPrefStoreUpdateTimeKey];
        if (stored == nil || [stored compare:storeUpdateTime
                                     options:NSNumericSearch] == NSOrderedAscending) {
            [NSUserDefaults.standardUserDefaults setObject:storeUpdateTime
                                                    forKey:kPrefStoreUpdateTimeKey];
            [NSUserDefaults.standardUserDefaults synchronize];
        }
    }
}

/** @ghidraAddress 0x20c84 */
- (nullable id)soundName:(nullable id)suffix {
    // The sound-effect name carries the current theme's prefix.
    switch (JubeatAppDelegate.appDelegate.currentTheme) {
    case JubeatThemeReflecBeatPlus:
        return [NSString stringWithFormat:@"SD_RPL_%@", suffix];
    case JubeatThemeKnit:
        return [NSString stringWithFormat:@"SD_KNT_%@", suffix];
    default:
        return [NSString stringWithFormat:@"SD_%@", suffix];
    }
}

/** @ghidraAddress 0x272ac */
- (void)tapPlaylists:(nullable id)sender {
    [self setEnableGesture:YES];
    playlistViewCtrl = [[MusicPlaylistViewController alloc] initWithStyle:UITableViewStylePlain];
    [playlistViewCtrl setListMode:MusicPlaylistListModePlaylists];
    [playlistViewCtrl setPlaylistManager:playlistManager];
    [playlistViewCtrl setDelegate:self];
    playlistNavCtrl =
        [[RotatableNavigationController alloc] initWithRootViewController:playlistViewCtrl];
    if (!isPad) {
        [self presentViewController:playlistNavCtrl animated:YES completion:nil];
        bOpenModal = YES;
    } else {
        // The pad presents it as a popover pointing up from the bottom bar's playlist button.
        [playlistNavCtrl setModalPresentationStyle:UIModalPresentationPopover];
        UIPopoverPresentationController *popover = playlistNavCtrl.popoverPresentationController;
        [popover setDelegate:self];
        [popover setPermittedArrowDirections:UIPopoverArrowDirectionDown];
        [popover setSourceView:self.view];
        [popover setSourceRect:[bottomView getPlayListBtnRect]];
        [self presentViewController:playlistNavCtrl animated:YES completion:nil];
    }
    [self musicShuffleDisable];
}

/** @ghidraAddress 0x26f98 */
- (void)turnToStore:(nullable id)params {
    storeParams = params;
    // A pending consume receipt must be verified first; otherwise the store opens immediately.
    if ([[PurchaseManager sharedManager] verifyPendingConsumeReceipt]) {
        [[PurchaseManager sharedManager] setDelegate:self];
        verifyPurchaseType = kVerifyPurchaseTypeStore;
        [self showVerifyDialog:kVerifyProcessingMessage];
    } else {
        [self turnToStore];
    }
}

/** @ghidraAddress 0x26b30 */
- (void)turnToGenreOpen:(nullable id)sender {
    [self turnToStore:@{@"genre" : sender}];
}

/** @ghidraAddress 0x26bf8 */
- (void)turnToPackPurchase:(nullable id)sender {
    [self turnToStore:@{@"pack" : sender}];
}

/** @ghidraAddress 0x26cc0 */
- (void)turnToCampaignDetail:(nullable id)sender {
    [self turnToStore:@{@"campaign" : sender}];
}

/** @ghidraAddress 0x27098 */
- (void)clickPackInfomation:(nullable id)sender {
    [self dismissViewControllerAnimated:YES
                             completion:^{
                               /** @ghidraAddress 0x27188 */
                               [self turnToStore:sender];
                             }];
    bOpenModal = NO;
    bOpenInfo = NO;
    [self musicShuffleEnable];
    [self setSearchEnable:YES];
}

/** @ghidraAddress 0x2d2e0 */
- (void)tapLeaderboard:(nullable id)sender {
    [self setEnableGesture:YES];
    if (!GKLocalPlayer.localPlayer.isAuthenticated) {
        return;
    }
    [[AudioManager sharedManager] playSeResFile:[self soundName:kSettingsTapSoundSuffix]
                                    inDirectory:nil];
    GKGameCenterViewController *gc = [[GKGameCenterViewController alloc] init];
    [gc setLeaderboardIdentifier:JubeatAppDelegate.appDelegate.totalScoreLeaderboardCategory];
    [gc setGameCenterDelegate:self];
    [self presentViewController:gc animated:YES completion:nil];
    bOpenModal = YES;
    [self musicShuffleDisable];
    [self setSearchEnable:NO];
}

/** @ghidraAddress 0x34584 */
- (BOOL)checkLabURL {
    NSData *encoded = [NSUserDefaults.standardUserDefaults objectForKey:kPrefJubeatLabURLKey];
    if (encoded != nil) {
        NSMutableData *data = [NSMutableData dataWithData:encoded];
        BFCodec *codec = [[BFCodec alloc] init];
        [codec cipherInit:CreateLabUrlCipherKey()];
        [codec decipher:data];
        if (data != nil) {
            jubeatLabURL = [[NSString alloc] initWithData:data encoding:kLabURLEncoding];
            if (jubeatLabURL != nil) {
                return YES;
            }
        }
    }
    jubeatLabURL = nil;
    [NSUserDefaults.standardUserDefaults removeObjectForKey:kPrefJubeatLabURLKey];
    return NO;
}

/** @ghidraAddress 0x33374 */
- (void)moveStore:(nullable id)store packID:(nullable NSString *)packID {
    [self dismissViewControllerAnimated:YES
                             completion:^{
                               /** @ghidraAddress 0x33428 */
                               [self turnToPackPurchase:packID];
                             }];
}

#pragma mark - Playlist arrays

/** @ghidraAddress 0x21bbc */
- (void)createArrayLevel:(int)level {
    arrayLevelList = nil;
    arrayLevelList = [[NSMutableArray alloc] init];
    for (TuneInfo *tune in arrayAllTune) {
        if (MusicSelectTuneHasLevel(self, tune, level)) {
            [arrayLevelList addObject:tune];
        }
    }
}

/** @ghidraAddress 0x21e34 */
- (void)createArrayHold {
    if (arrayHoldList != nil) {
        arrayHoldList = nil;
    }
    arrayHoldList = [[NSMutableArray alloc] init];
    for (TuneInfo *tune in arrayAllTune) {
        if (MusicSelectTuneIsHold(self, tune)) {
            [arrayHoldList addObject:tune];
        }
    }
}

/** @ghidraAddress 0x22014 */
- (void)createArrayNotHold {
    // The binary tests arrayNotHoldList for the reset but clears arrayHoldList; kept as-is.
    if (arrayNotHoldList != nil) {
        arrayHoldList = nil;
    }
    arrayNotHoldList = [[NSMutableArray alloc] init];
    for (TuneInfo *tune in arrayAllTune) {
        if (!MusicSelectTuneIsHold(self, tune)) {
            [arrayNotHoldList addObject:tune];
        }
    }
}

#pragma mark - Edit and shuffle

/** @ghidraAddress 0x2ea1c */
- (void)startPlay:(nullable id)tune {
    [self stopStoreInfo];
    [musicListView releaseArtworks];
    [[AudioManager sharedManager] fadeoutBgm:1.0];
    // A non-host share client does not overwrite the last-played id.
    if (self.sharePlayManager == nil || self.sharePlayManager.isHost) {
        [NSUserDefaults.standardUserDefaults setInteger:((TuneInfo *)tune).tuneID
                                                 forKey:kPrefLastPlayedIDKey];
    }
    NSInteger editPage = [NSUserDefaults.standardUserDefaults integerForKey:kPrefEditSelectKey];
    NSInteger difficulty = [NSUserDefaults.standardUserDefaults integerForKey:kPrefDifficultyKey];
    // Off the edit page and in extend mode, play the extend chart when the tune carries one for the
    // current difficulty; otherwise play the base tune.
    TuneInfo *playTune = tune;
    if (((TuneInfo *)tune).extendID != 0 && editPage != 1 &&
        JubeatAppDelegate.appDelegate.isExtend) {
        TuneInfo *extend = dictAllExtendTune[@(((TuneInfo *)tune).extendID)];
        if (extend != nil && (extend.extendFlag & (1 << difficulty)) != 0) {
            playTune = extend;
        }
    }
    [JubeatAppDelegate.appDelegate.rootViewCtrl startMainGame:playTune
                                                 shareManager:self.sharePlayManager
                                                    musicData:shareMusicData];
    self.sharePlayManager = nil;
    shareMusicData = nil;
    [self setEnableGesture:NO];
}

/** @ghidraAddress 0x2ee04 */
- (void)startEdit:(nullable id)tune {
    [self stopStoreInfo];
    [musicListView releaseArtworks];
    [[AudioManager sharedManager] fadeoutBgm:1.0];
    // A non-host share client does not overwrite the last-played id.
    if (self.sharePlayManager == nil || self.sharePlayManager.isHost) {
        [NSUserDefaults.standardUserDefaults setInteger:((TuneInfo *)tune).tuneID
                                                 forKey:kPrefLastPlayedIDKey];
    }
    [JubeatAppDelegate.appDelegate.rootViewCtrl startEditNote:tune
                                                    musicData:shareMusicData
                                                      jcfName:nil];
    self.sharePlayManager = nil;
    shareMusicData = nil;
    [self setEnableGesture:NO];
}

/** @ghidraAddress 0x35628 */
- (void)setRandomSelect {
    NSArray<TuneInfo *> *list = arrayCurrentPlaylist ?: arrayAllTune;
    if (list.count == 0 || !bEnableShuffle) {
        return;
    }
    int lastPlayed = (int)[NSUserDefaults.standardUserDefaults integerForKey:kPrefLastPlayedIDKey];
    unsigned int count = (unsigned int)list.count;
    unsigned int index = arc4random() % count;
    TuneInfo *tune = list[index];
    // If the random pick repeats the last-played tune, step on by a second random offset.
    if ((int)tune.tuneID == lastPlayed) {
        index = (index + (unsigned int)rand()) % count;
        tune = list[index];
    }
    [NSUserDefaults.standardUserDefaults setInteger:tune.tuneID forKey:kPrefLastPlayedIDKey];
    if (!bOpenMusicDetail) {
        [self startOpenDetailPanel];
    } else if (list.count != 1 && !bSuffleAnim) {
        [self shuffleAnimation:tune];
    }
}

/** @ghidraAddress 0x3486c */
- (void)shuffleAnimation:(nullable id)tune {
    int slideOffset = isPad ? kShuffleSlideOffsetPad : kShuffleSlideOffsetPhone;
    bSuffleAnim = YES;
    __weak UIView *weakCover = coverView;
    __weak MusicDetailView *weakDetail = musicDetailView;
    __weak MusicView *weakSelected = selectedMusicView;
    musicDetailView.transform = CGAffineTransformMakeTranslation(0, 0);
    [[AudioManager sharedManager] fadeoutBgm:kShuffleBgmFadeOut];
    [[AudioManager sharedManager] playSeResFile:[self soundName:kShuffleSoundSuffix]
                                    inDirectory:nil];
    [UIView animateWithDuration:kShuffleSlideDuration
        delay:0.0
        options:UIViewAnimationOptionCurveEaseOut
        animations:^{
          /** @ghidraAddress 0x34ba0 */
          weakDetail.transform = CGAffineTransformMakeTranslation(-slideOffset, 0);
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x34c2c */
          [self changeMusicData:tune];
          [UIView animateWithDuration:kShuffleFlipDuration / kShuffleFlipStageDivisor
              delay:0.0
              options:UIViewAnimationOptionCurveEaseIn
              animations:^{
                /** @ghidraAddress 0x34dbc */
                weakDetail.transform = CGAffineTransformMakeTranslation(0, 0);
              }
              completion:^(BOOL innerFinished) {
                /** @ghidraAddress 0x34e40 */
                CGFloat viewerDistance =
                    isPad ? kCoverFlipViewerDistancePad : kCoverFlipViewerDistancePhone;
                CATransform3D perspective = CATransform3DIdentity;
                perspective.m34 = kCoverFlipPerspectiveM34;
                perspective = CATransform3DTranslate(perspective, 0, 0, viewerDistance);
                // The selected music view's artwork flips to its front (pi about the vertical
                // axis), centred over the cover.
                UIImageView *imgView = weakSelected.imgView;
                imgView.center = weakCover.center;
                imgView.layer.transform = CATransform3DRotate(perspective, g_dPi, 0, -1.0, 0);
                // The detail view flips full-circle (2*pi) at the shrunk cover-flip scale, also
                // centred over the cover.
                CGFloat scale = isPad ? kCoverFlipScalePad : kCoverFlipScalePhone;
                CATransform3D scaled = CATransform3DScale(perspective, scale, scale, 1.0);
                weakDetail.center = weakCover.center;
                weakDetail.layer.transform = CATransform3DRotate(scaled, g_dTwoPi, 0, 1.0, 0);
                bSuffleAnim = NO;
              }];
        }];
}

#pragma mark - Search box

/** @ghidraAddress 0x35dfc */
- (void)pushSearchBox {
    if (bOpenSearchBox) {
        [searchBox setText:[NSString stringWithString:backUpString]];
        [[AudioManager sharedManager] playSeResFile:[self soundName:kSearchBoxCloseSoundSuffix]
                                        inDirectory:nil];
    }
    bOpenSearchBox = NO;
    [self showButtonMarker:YES];
    if (searchArray.count != 0) {
        [searchArray removeAllObjects];
        [self exeSearchPickUp];
    }
    [searchBox resignFirstResponder];
    __weak UISearchBar *weakSearch = searchBox;
    __weak UIButton *weakCancel = searchCancelBtn;
    [UIView animateWithDuration:kSearchBoxSlideDuration
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState |
                                UIViewAnimationOptionAllowAnimatedContent
                     animations:^{
                       /** @ghidraAddress 0x36068 */
                       weakSearch.transform =
                           CGAffineTransformMakeTranslation(0.0, kSearchBoxSlideOffset);
                       weakCancel.transform =
                           CGAffineTransformMakeTranslation(0.0, kSearchBoxSlideOffset);
                     }
                     completion:nil];
}

#pragma mark - Button marker

/** @ghidraAddress 0x2e4fc */
- (void)showButtonMarker:(BOOL)show {
    __weak UIButton *weakMarker = btnMarker;
    // The search box is lifted above the marker button for the transition.
    searchBox.layer.zPosition = kSearchBoxRaisedZPosition;
    if (!show) {
        [btnMarker setEnabled:NO];
        [UIView animateWithDuration:kButtonMarkerAnimDuration
            animations:^{
              /** @ghidraAddress 0x2e8e0 */
              weakMarker.transform =
                  CGAffineTransformMakeTranslation(0.0, -weakMarker.frame.size.height);
            }
            completion:^(BOOL finished) {
              /** @ghidraAddress 0x2e994 */
              self->searchBox.layer.zPosition = 0.0;
            }];
    } else {
        [UIView animateWithDuration:kButtonMarkerAnimDuration
            animations:^{
              /** @ghidraAddress 0x2e744 */
              weakMarker.transform = CGAffineTransformIdentity;
            }
            completion:^(BOOL finished) {
              /** @ghidraAddress 0x2e7b4 */
              self->searchBox.layer.zPosition = 0.0;
              [weakMarker setEnabled:YES];
              if (!MarkerManager.enableMarkerSelect) {
                  [weakMarker setEnabled:NO];
              }
            }];
    }
}

#pragma mark - Scroll paging

/** @ghidraAddress 0x39078 */
- (void)scrollFromPageNum:(int)pageNum bAnim:(BOOL)animated {
    if (scrollBg == nil) {
        return;
    }
    int width = (int)scrollBg.frame.size.width;
    int quotient = (scrollPageNum != 0) ? pageNum / scrollPageNum : 0;
    int target = pageNum - quotient * scrollPageNum;
    int current = (int)(scrollBg.contentOffset.x / (double)width);
    // On the wrap boundary the target stays on the trailing clone page.
    int dest = (current != scrollPageNum - 1 || target != 0) ? target : scrollPageNum;
    // Jump the looped scroll view to the matching real page without animation before the animated
    // move, so paging past either end wraps seamlessly.
    if (current == scrollPageNum && dest == 1) {
        [scrollBg setContentOffset:CGPointMake(0.0, 0.0)];
    }
    if (current == 0 && dest == scrollPageNum - 1) {
        [scrollBg setContentOffset:CGPointMake((double)(scrollPageNum * width), 0.0)];
    }
    [scrollBg setContentOffset:CGPointMake((double)(dest * width), 0.0) animated:animated];
}

#pragma mark - Search

/** @ghidraAddress 0x221fc */
- (BOOL)matchTitle:(nullable id)tune {
    // Every search term must appear (case-insensitively) in at least one of the tune's search
    // strings, looked up by tune id. No terms matches everything.
    NSArray<NSString *> *strings = searchDictionary[@(((TuneInfo *)tune).tuneID)];
    for (NSString *term in searchArray) {
        BOOL matched = NO;
        for (NSString *candidate in strings) {
            if (candidate != nil &&
                [candidate rangeOfString:term options:NSCaseInsensitiveSearch].location !=
                    NSNotFound) {
                matched = YES;
            }
        }
        if (!matched) {
            return NO;
        }
    }
    return YES;
}

/** @ghidraAddress 0x35a9c */
- (BOOL)searchStringChanged:(nullable id)searchString {
    // Recompute the search terms; the query changed when the term count differs or any new term is
    // absent from the previous set.
    NSArray *previous = [NSArray arrayWithArray:searchArray];
    searchArray = [NSMutableArray arrayWithArray:[self getSearchArray:searchString]];
    if (previous.count != searchArray.count) {
        return YES;
    }
    for (id term in previous) {
        if (![searchArray containsObject:term]) {
            return YES;
        }
    }
    return NO;
}

/** @ghidraAddress 0x35cb8 */
- (void)setSearchEnable:(BOOL)enable {
    // The swipe recognisers are enabled only when a music detail is not open and the caller asks.
    BOOL on = !bOpenMusicDetail && enable;
    for (UIGestureRecognizer *recognizer in arraySwipeRecognizer) {
        [recognizer setEnabled:on];
    }
}

/** @ghidraAddress 0x35944 */
- (nullable id)getSearchArray:(nullable NSString *)searchString {
    // Normalise kana and width (twice each, matching the binary), split on spaces, de-duplicate via
    // a set, and drop empty terms.
    NSMutableString *normalised = [searchString mutableCopy];
    CFStringTransform(
        (CFMutableStringRef)normalised, NULL, kCFStringTransformHiraganaKatakana, false);
    CFStringTransform(
        (CFMutableStringRef)normalised, NULL, kCFStringTransformFullwidthHalfwidth, false);
    CFStringTransform(
        (CFMutableStringRef)normalised, NULL, kCFStringTransformHiraganaKatakana, false);
    CFStringTransform(
        (CFMutableStringRef)normalised, NULL, kCFStringTransformFullwidthHalfwidth, false);
    NSArray *terms = [normalised componentsSeparatedByString:@" "];
    NSMutableArray *unique = [NSMutableArray arrayWithArray:[NSSet setWithArray:terms].allObjects];
    [unique removeObject:@""];
    return unique;
}

/** @ghidraAddress 0x367f0 */
- (void)exeSearchPickUp {
    // The app-wide search string reflects the current query (nil when empty).
    if (searchArray.count == 0) {
        [JubeatAppDelegate.appDelegate setSearchString:nil];
    } else {
        [JubeatAppDelegate.appDelegate setSearchString:searchBox.text];
    }
    // Resolve the list selection: a remembered named playlist by index, or a built-in sentinel.
    NSUInteger listType =
        [playlistManager indexOfPlaylistWithIdentifier:[NSUserDefaults.standardUserDefaults
                                                           stringForKey:kPrefLastPlaylistKey]];
    if (listType == NSNotFound) {
        if ([NSUserDefaults.standardUserDefaults integerForKey:kPrefPlayListLevelKey] == 0) {
            listType = (playListIndex == -1) ? (NSUInteger)kPlaylistSelectionNotPlayed :
                                               (NSUInteger)kPlaylistSelectionDefault;
        } else {
            listType = (NSUInteger)kPlaylistSelectionLevel;
        }
    }
    NSUInteger lastPlayed =
        [NSUserDefaults.standardUserDefaults integerForKey:kPrefLastPlayedIDKey];
    [self changeMusicListView:(NSInteger)listType musicID:lastPlayed];
}

/** @ghidraAddress 0x369f8 */
- (void)searchBar:(nullable UISearchBar *)searchBar textDidChange:(nullable NSString *)searchText {
    backUpString = [NSString stringWithString:searchText];
    if ([self searchStringChanged:searchText]) {
        [self exeSearchPickUp];
    }
}

#pragma mark - Store info

/** @ghidraAddress 0x27d54 */
- (void)requestNewInfo {
    if (infoDownloader != nil) {
        [infoDownloader cancel];
        infoDownloader = nil;
    }
    storeUpdateTime = nil;
    NSURL *url = [StoreUtil storeNewInfoURL];
    // A logged-in editor appends its id to the request URL.
    if (EditorIDManager.isExistEditorID) {
        NSString *key = [EditorIDManager getKeyString:[EditorIDManager getEditorIDKey]];
        NSString *query = [NSString stringWithFormat:kNewInfoUserIDFormat, key];
        url = [NSURL
            URLWithString:[NSString
                              stringWithFormat:kNewInfoURLConcatFormat, url.absoluteString, query]];
    }
    infoDownloader = [[Downloader alloc] initWithURL:url delegate:self];
    [infoDownloader setTag:0];
    [infoDownloader startDownloading];
}

/** @ghidraAddress 0x271ec */
- (void)stopStoreInfo {
    if (infoDownloader != nil) {
        [infoDownloader cancel];
        infoDownloader = nil;
    }
    if (challengeInfoDownloader != nil) {
        [challengeInfoDownloader cancel];
        challengeInfoDownloader = nil;
    }
    if (infoBannerTimer != nil) {
        [infoBannerTimer invalidate];
        infoBannerTimer = nil;
    }
}

#pragma mark - Settings

/** @ghidraAddress 0x2d030 */
- (void)tapSettings:(nullable id)sender {
    if (notificationView.isActive) {
        [notificationView stopNotification];
    }
    [self setEnableGesture:YES];
    [[AudioManager sharedManager] playSeResFile:[self soundName:kSettingsTapSoundSuffix]
                                    inDirectory:nil];
    [self presentViewController:settingsNavCtrl animated:YES completion:nil];
    bOpenModal = YES;
    bOpenSetting = YES;
    [self musicShuffleDisable];
    [self setSearchEnable:NO];
}

/** @ghidraAddress 0x2d160 */
- (void)settingsNavViewClose:(nullable id)sender {
    [[AudioManager sharedManager] playSeResFile:[self soundName:@"MUSIC_LEFT"] inDirectory:nil];
    [self dismissViewControllerAnimated:YES completion:nil];
    bOpenModal = NO;
    bOpenSetting = NO;
    [self musicShuffleEnable];
    [self setSearchEnable:YES];
    [notificationView startNotification];
}

#pragma mark - Cover view

/** @ghidraAddress 0x2a2b8 */
- (void)showCoverView:(nullable id)appendViews addGesture:(nullable id)gesture {
    if (bOpenDelegateCover) {
        return;
    }
    bOpenDelegateCover = YES;
    if (!bOpenSearchBox) {
        [self showButtonMarker:NO];
    }
    [self setSearchEnable:NO];
    [self musicShuffleDisable];
    [coverView setHidden:NO];
    [coverView setAlpha:0.0];
    if (appendViews != nil) {
        // Tear down any previous appended cover views and add the new ones.
        if (appendCoverView != nil) {
            for (NSUInteger i = 0; i < appendCoverView.count; ++i) {
                [appendCoverView[i] removeFromSuperview];
            }
            appendCoverView = nil;
        }
        appendCoverView = appendViews;
        for (NSUInteger i = 0; i < ((NSArray *)appendViews).count; ++i) {
            [coverView addSubview:appendViews[i]];
        }
    }
    if (gesture != nil) {
        if (appendCoverGesture != nil) {
            [coverView removeGestureRecognizer:appendCoverGesture];
            appendCoverGesture = nil;
        }
        appendCoverGesture = gesture;
        [coverView addGestureRecognizer:gesture];
    }
    __weak UIView *weakCover = coverView;
    [UIView animateWithDuration:g_dAnimDuration020
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState |
                                UIViewAnimationOptionAllowAnimatedContent
                     animations:^{
                       /** @ghidraAddress 0x2a600 */
                       [weakCover setAlpha:1.0];
                     }
                     completion:nil];
}

/** @ghidraAddress 0x2a650 */
- (void)hiddenCoverView {
    if (!bOpenDelegateCover) {
        return;
    }
    bOpenDelegateCover = NO;
    if (!bOpenSearchBox) {
        [self showButtonMarker:YES];
    }
    [self setSearchEnable:YES];
    [self musicShuffleEnable];
    [coverView setAlpha:1.0];
    __weak UIView *weakCover = coverView;
    [UIView animateWithDuration:g_dAnimDuration020
        delay:0.0
        options:UIViewAnimationOptionBeginFromCurrentState |
                UIViewAnimationOptionAllowAnimatedContent
        animations:^{
          /** @ghidraAddress 0x2a7fc */
          [weakCover setAlpha:0.0];
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x2a848 */
          [weakCover setHidden:YES];
          if (appendCoverView != nil) {
              for (NSUInteger i = 0; i < appendCoverView.count; ++i) {
                  [appendCoverView[i] removeFromSuperview];
              }
              appendCoverView = nil;
          }
        }];
}

#pragma mark - Store balloon

/** @ghidraAddress 0x28ac4 */
- (void)hideStoreBalloon {
    if (balloonView == nil || balloonView.isHidden) {
        return;
    }
    [balloonView setUserInteractionEnabled:NO];
    __weak BalloonView *weakBalloon = balloonView;
    [UIView animateWithDuration:kStoreBalloonFadeDuration
        animations:^{
          /** @ghidraAddress 0x28c10 */
          [weakBalloon setAlpha:0.0];
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x28c5c */
          [weakBalloon.layer removeAnimationForKey:kStoreBalloonAnimationKey];
        }];
}

#pragma mark - Popover and challenge mode

/** @ghidraAddress 0x36e5c */
- (void)challengeMusicStart:(nullable id)tune diff:(int)difficulty {
    [self stopStoreInfo];
    [JubeatAppDelegate.appDelegate setChallengeMusic:((TuneInfo *)tune).tuneID diff:difficulty];
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    [[UIApplication sharedApplication] performSelector:@selector(endIgnoringInteractionEvents)
                                            withObject:nil
                                            afterDelay:kStartPlayInputLockDuration];
    [musicListView releaseArtworks];
    [[AudioManager sharedManager] fadeoutBgm:1.0];
    [JubeatAppDelegate.appDelegate.rootViewCtrl startMainGame:tune
                                                 shareManager:self.sharePlayManager
                                                    musicData:shareMusicData];
    self.sharePlayManager = nil;
    shareMusicData = nil;
    [self setEnableGesture:NO];
}

/** @ghidraAddress 0x28ccc */
- (void)launchChallengeMode {
    if ([indicatorTimer isValid]) {
        [indicatorTimer invalidate];
        indicatorTimer = nil;
    }
    if (!bLaunchCMode) {
        [[AudioManager sharedManager] fadeoutBgm:kChallengeBgmFadeOut];
    }
    [challengeModeView enterChallengeView:YES];
    // Once the current scratch content id has been seen, hide the challenge-new badge.
    int scratchID = currentScratchID;
    if ([NSUserDefaults.standardUserDefaults integerForKey:kPrefScratchUpdateIDKey] < scratchID) {
        [NSUserDefaults.standardUserDefaults setInteger:scratchID forKey:kPrefScratchUpdateIDKey];
        [NSUserDefaults.standardUserDefaults synchronize];
        [imgChallengeNew setHidden:YES];
    }
    [self setEnableGesture:NO];
}

#pragma mark - URL scheme

/** @ghidraAddress 0x3348c */
- (void)schemeMoveStore {
    // Close the marker-select overlay if it is open, restoring the covered view and marker button.
    if (isMarkerSelectOpen) {
        UIView *cover = (musicDetailView.superview == nil) ? coverView : musicDetailView.coverView;
        [cover setAlpha:1.0];
        [markerSelectView close];
        markerSelectView.transform = CGAffineTransformIdentity;
        btnMarker.transform = CGAffineTransformIdentity;
        [cover setAlpha:1.0];
        if (musicDetailView.superview != nil) {
            [musicDetailView activateAnim:YES];
        }
        [cover setHidden:YES];
        [markerSelectView setHidden:YES];
        [musicDetailView setHidden:YES];
        isMarkerSelectOpen = NO;
        [self musicShuffleEnable];
        [self setSearchEnable:YES];
    }
    // Dismiss any open modal.
    if (bOpenModal) {
        [self dismissViewControllerAnimated:NO completion:nil];
        bOpenModal = NO;
        [self musicShuffleEnable];
        [self setSearchEnable:YES];
    }
    if (selectedMusicView != nil) {
        [musicDetailView closePopWindow];
    }
    // Open whichever store target the URL scheme recorded, then clear it.
    JubeatAppDelegate *appDelegate = JubeatAppDelegate.appDelegate;
    if (appDelegate.storePackID != nil) {
        [self turnToPackPurchase:appDelegate.storePackID];
        [appDelegate resetDownloadPackID];
    } else if (appDelegate.storeCampaignID != nil) {
        [self turnToCampaignDetail:appDelegate.storeCampaignID];
        [appDelegate resetCampaignID];
    } else if (appDelegate.storeGenreID != nil) {
        [self turnToGenreOpen:appDelegate.storeGenreID];
        [appDelegate resetDownloadGenreID];
    }
}

#pragma mark - Playlist actions

/** @ghidraAddress 0x2cbfc */
- (void)musicViewPlaylistAction:(nullable id)view {
    MusicView *musicView = view;
    // On a built-in playlist source, open the add-to-playlist picker; on a named playlist, remove
    // the tune from it.
    id source = currentPlaylistSource;
    if (source == nil || source == arrayNotPlayedTune || source == arrayLevelList ||
        source == arrayHoldList || source == arrayNotHoldList) {
        playlistViewCtrl =
            [[MusicPlaylistViewController alloc] initWithStyle:UITableViewStylePlain];
        [playlistViewCtrl setListMode:MusicPlaylistListModeAddToPlaylist];
        [playlistViewCtrl setSelectedMusicID:musicView.tuneInfo.tuneID];
        [playlistViewCtrl setPlaylistManager:playlistManager];
        [playlistViewCtrl setDelegate:self];
        playlistNavCtrl =
            [[RotatableNavigationController alloc] initWithRootViewController:playlistViewCtrl];
        if (!isPad) {
            [self presentViewController:playlistNavCtrl animated:YES completion:nil];
            bOpenModal = YES;
        } else {
            [playlistNavCtrl setModalPresentationStyle:UIModalPresentationPopover];
            UIPopoverPresentationController *popover =
                playlistNavCtrl.popoverPresentationController;
            [popover setDelegate:self];
            [popover setPermittedArrowDirections:UIPopoverArrowDirectionUp |
                                                 UIPopoverArrowDirectionDown];
            [popover setSourceView:musicView];
            [popover setSourceRect:musicView.btnPlaylistAction.frame];
            [self presentViewController:playlistNavCtrl animated:YES completion:nil];
        }
        [self musicShuffleDisable];
    } else {
        NSUInteger index = [playlistManager indexOfPlaylist:source];
        if (index != NSNotFound) {
            [playlistManager removeMusic:musicView.tuneInfo.tuneID fromPlaylistAtIndex:index];
            [playlistManager synchronize];
            [arrayCurrentPlaylist removeObjectIdenticalTo:musicView.tuneInfo];
            [musicListView removeMusicView:musicView];
        }
    }
}

/** @ghidraAddress 0x370ac */
- (void)makeChallengeRootView {
    if (challengeModeView != nil) {
        [challengeModeView removeFromSuperview];
        challengeModeView = nil;
    }
    challengeModeView = [[ChallengeModeRootView alloc] init];
    [challengeModeView setController:self];
    challengeModeView.layer.zPosition = kChallengeRootViewZPosition;
    [self.view addSubview:challengeModeView];
}

/** @ghidraAddress 0x3433c */
- (void)customWebViewClose:(nullable id)webView seqIndex:(nullable id)seqIndex {
    [[AudioManager sharedManager] playSeResFile:kWebViewCloseSound inDirectory:nil];
    [self dismissViewControllerAnimated:YES
                             completion:^{
                               /** @ghidraAddress 0x34428 */
                               [self JcfDownLoad];
                             }];
    bOpenModal = NO;
    [self musicShuffleEnable];
    [self setSearchEnable:YES];
}

/** @ghidraAddress 0x34448 */
- (void)notificationDisp {
    if (JubeatAppDelegate.appDelegate.notificationURL == nil) {
        return;
    }
    if (notificationViewController != nil) {
        notificationViewController = nil;
    }
    notificationViewController = [[NotificationPageNavController alloc] init:self];
    [self presentViewController:notificationViewController animated:YES completion:nil];
    bOpenInfo = YES;
    bOpenModal = YES;
    [[AudioManager sharedManager] playSeResFile:kNotificationOpenSound inDirectory:nil];
}

/** @ghidraAddress 0x34040 */
- (void)startOpenDetailPanel {
    if (notificationView.isActive) {
        [notificationView stopNotification];
    }
    int lastPlayedID =
        (int)[NSUserDefaults.standardUserDefaults integerForKey:kPrefLastPlayedIDKey];
    MusicView *musicView = [musicListView getMusicView:lastPlayedID];
    if (musicView != nil) {
        // The last-played tune is on the current page; open its detail panel directly.
        [self musicViewTapped:musicView];
        return;
    }
    // The last-played tune is off-page: find its index in the full tune list, work out which page
    // that is, and open a stand-in music view sliding in from whichever side that page lies on.
    int currentPage = [musicListView getCurrentPage];
    TuneInfo *foundTune = nil;
    int tunePage = 0;
    int index = 0;
    for (TuneInfo *tune in arrayAllTune) {
        if (tune.tuneID == lastPlayedID) {
            foundTune = tune;
            int viewsPerPage = [musicListView currentViewsPerPage];
            tunePage = viewsPerPage != 0 ? index / viewsPerPage : 0;
            break;
        }
        ++index;
    }
    CGFloat width = self.view.frame.size.width;
    CGFloat direction = tunePage > currentPage ? 1.0 : kDetailPanelOffscreenDirection;
    farOpenMusicView.center = CGPointMake(width * 0.5 + direction * width, width * 0.5);
    [farOpenMusicView setInfo:foundTune];
    [self musicViewTapped:farOpenMusicView];
}

/** @ghidraAddress 0x338c0 */
- (void)popoverClose {
    if (isPad) {
        [self dismissViewControllerAnimated:NO completion:nil];
    }
    if (bOpenModal) {
        if (bOpenSetting) {
            [settingsNavCtrl settingClose];
        }
        [self dismissViewControllerAnimated:NO completion:nil];
        bOpenModal = NO;
        [self musicShuffleEnable];
    }
}

/** @ghidraAddress 0x37c78 */
- (void)hideChallengeCoverView {
    if ([indicatorTimer isValid]) {
        [indicatorTimer invalidate];
        indicatorTimer = nil;
    }
    bOpenChallenge = NO;
    __weak UIView *weakCover = challengeCoverView;
    [UIView animateWithDuration:kChallengeCoverFadeDuration
        delay:0.0
        options:UIViewAnimationOptionBeginFromCurrentState |
                UIViewAnimationOptionAllowAnimatedContent
        animations:^{
          /** @ghidraAddress 0x37df8 */
          [weakCover setAlpha:0.0];
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x37e44 */
          [weakCover removeFromSuperview];
          challengeCoverView = nil;
        }];
}

/** @ghidraAddress 0x37844 */
- (void)showChallengeCoverView {
    if (challengeCoverView != nil) {
        return;
    }
    bOpenChallenge = YES;
    challengeCoverView = [[UIView alloc] initWithFrame:self.view.frame];
    challengeCoverView.opaque = NO;
    // The original built this with colorWithWhite:0 alpha:0.4.
    challengeCoverView.backgroundColor = [UIColor colorWithWhite:0
                                                           alpha:kChallengeCoverBackgroundAlpha];
    [self.view addSubview:challengeCoverView];
    challengeCoverView.layer.zPosition = kChallengeRootViewZPosition;
    indicatorChallenge = [[UIActivityIndicatorView alloc]
        initWithFrame:CGRectMake(0, 0, kChallengeIndicatorSize, kChallengeIndicatorSize)];
    indicatorChallenge.center = CGPointMake(challengeCoverView.frame.size.width * 0.5,
                                            challengeCoverView.frame.size.height * 0.5);
    indicatorChallenge.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
    indicatorChallenge.hidesWhenStopped = YES;
    [challengeCoverView addSubview:indicatorChallenge];
    indicatorTimer = [NSTimer scheduledTimerWithTimeInterval:kChallengeLoadTimeout
                                                      target:self
                                                    selector:@selector(loadTimeOver:)
                                                    userInfo:nil
                                                     repeats:NO];
    challengeCoverView.alpha = 0.0;
    __weak UIView *weakCover = challengeCoverView;
    [UIView animateWithDuration:kChallengeCoverFadeDuration
                          delay:0.0
                        options:UIViewAnimationOptionCurveLinear
                     animations:^{
                       /** @ghidraAddress 0x37bd4 */
                       weakCover.alpha = 1.0;
                     }
                     completion:nil];
}

/** @ghidraAddress 0x371a4 */
- (void)downloadChallengeInfo {
    if (notificationView.isActive) {
        [notificationView stopNotification];
    }
    bLaunchCMode = JubeatAppDelegate.appDelegate.bChallengeMode;
    [self showChallengeCoverView];
    if (!EditorIDManager.isExistEditorID) {
        idManager = [[EditorIDManager alloc] initWithDelegate:self];
        return;
    }
    if ([PurchaseManager sharedManager].verifyPendingConsumeReceipt) {
        // A consume receipt is still pending: verify it before the challenge info can be fetched.
        verifyPurchaseType = kVerifyPurchaseTypeChallenge;
        [[PurchaseManager sharedManager] setDelegate:self];
        [self showVerifyDialog:kVerifyProcessingMessage];
        return;
    }
    if (!checkPolicy) {
        // The challenge policy has not yet been agreed: present the licence agreement over the
        // cover, centred on the screen.
        CGRect bounds = UIScreen.mainScreen.bounds;
        LicenseAgreementView *agreementView =
            [[LicenseAgreementView alloc] init:self keyString:kPrefAgreeChallengePolicyVersionKey];
        agreementView.center = CGPointMake(bounds.size.width * 0.5, bounds.size.height * 0.5);
        [challengeCoverView addSubview:agreementView];
        return;
    }
    if ([NSUserDefaults.standardUserDefaults valueForKey:kPrefChallengeRestoreEndKey] == nil) {
        // The purchased packs have not been restored yet, which challenge mode requires first.
        [[AlertViewManager sharedManager]
            makeAlert:0
             delegate:self
                  tag:kAlertTagRestore
                title:@""
                  msg:kChallengePolicyRestoreRequiredMessage
               cancel:[NSBundle.mainBundle localizedStringForKey:@"Cancel" value:@"" table:nil]
              btnText:@[ [NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil] ]
                 show:YES];
        return;
    }
    NSMutableDictionary *postDictionary = [JubeatAppDelegate.clientInfo mutableCopy];
    postDictionary[kClientInfoMarkerIDKey] =
        [NSUserDefaults.standardUserDefaults objectForKey:kPrefCurrentMarkerIDKey];
    NSURL *url = ScratchUtil.challengeInitializeURL;
    if (ChallengeStatus.sharedStatus.bInitialized) {
        url = ScratchUtil.challengeSimpleInitializeURL;
    }
    int apiTag = ChallengeStatus.sharedStatus.bInitialized ? kChallengeApiTagSimpleInitialize :
                                                             kChallengeApiTagInitialize;
    challengeInfoDownloader = [[SessionDownloader alloc] initWithURL:url
                                                      postDictionary:postDictionary
                                                            delegate:self];
    [challengeInfoDownloader setTag:kChallengeInfoDownloaderTag];
    challengeInfoDownloader.apiTag = apiTag;
    [challengeInfoDownloader startDownloading];
}

/** @ghidraAddress 0x36da0 */
- (void)challengeModeClose {
    [self setupMainBgm];
    [challengeModeView removeFromSuperview];
    challengeModeView = nil;
    [JubeatAppDelegate.appDelegate setChallengeMode:NO];
    [self hideChallengeCoverView];
    [self setSearchEnable:YES];
    [notificationView startNotification];
}

#pragma mark - JCF download and purchases

/** @ghidraAddress 0x33084 */
- (void)jcfDownloadEnd:(nullable id)sender {
    __weak UIView *weakCover = coverView;
    __weak JcfDownloadView *weakDownload = jcfDownloadView;
    [musicListView addDownloadMark:[jcfDownloadView getDownloadMusicID]];
    // The binary passes a negative fade duration here; kept as-is.
    [UIView animateWithDuration:kJcfDownloadEndFadeDuration
        animations:^{
          /** @ghidraAddress 0x33248 */
          [weakCover setAlpha:0.0];
          [weakDownload setAlpha:0.0];
        }
        completion:^(BOOL finished) {
          /** @ghidraAddress 0x33310 */
          [self removeDownloadView];
        }];
    [self setSearchEnable:YES];
}

/** @ghidraAddress 0x32d10 */
- (void)JcfDownLoad:(nullable id)sequenceID {
    if (sequenceID == nil) {
        return;
    }
    [JubeatAppDelegate.appDelegate resetDownLoadIndex];
    if (jcfDLPageViewController != nil) {
        jcfDLPageViewController = nil;
    }
    jcfDLPageViewController = [[JcfDownloadPageNavController alloc] initWithSequenceID:sequenceID
                                                                              delegate:self];
    [self presentViewController:jcfDLPageViewController animated:YES completion:nil];
    bOpenModal = YES;
    [self musicShuffleDisable];
    [self setSearchEnable:NO];
}

/** @ghidraAddress 0x32e34 */
- (void)JcfDownLoadTopPage {
    if (jubeatLabURL == nil) {
        return;
    }
    [JubeatAppDelegate.appDelegate resetDownLoadIndex];
    if (jcfDLPageViewController != nil) {
        jcfDLPageViewController = nil;
    }
    jcfDLPageViewController = [[JcfDownloadPageNavController alloc] initWithURL:jubeatLabURL
                                                                       delegate:self];
    [self presentViewController:jcfDLPageViewController animated:YES completion:nil];
    bOpenModal = YES;
    [self musicShuffleDisable];
    [searchBox resignFirstResponder];
    [self setSearchEnable:NO];
    [[AudioManager sharedManager] playSeResFile:kNotificationOpenSound inDirectory:nil];
}

/** @ghidraAddress 0x2d4a8 */
- (void)gameCenterViewControllerDidFinish:(nullable id)controller {
    [[AudioManager sharedManager] playSeResFile:[self soundName:@"MUSIC_LEFT"] inDirectory:nil];
    [self dismissViewControllerAnimated:YES
                             completion:^{
                               /** @ghidraAddress 0x2d5c8 */
                               [self JcfDownLoad];
                             }];
    bOpenModal = NO;
    [self musicShuffleEnable];
    [self setSearchEnable:YES];
}

/** @ghidraAddress 0x36b4c */
- (void)tapChangeMode:(nullable id)sender {
    [musicDetailView changeExtendMode];
    __weak UIView *weakTutorial = extendTutorialView;
    // The binary passes a negative fade duration here; kept as-is.
    [UIView animateWithDuration:kExtendTutorialFadeDuration
                     animations:^{
                       /** @ghidraAddress 0x36c48 */
                       [weakTutorial setAlpha:0.0];
                     }];
}

/** @ghidraAddress 0x2ff94 */
- (void)alertSelect:(nullable id)alert {
    // Each tag selects an action performed by the shared tail; the restore and cancel paths return
    // early instead.
    int tag = [alert[kAlertTagKey] intValue];
    SEL action = @selector(downloadChallengeInfo);
    if (tag != kAlertTagChallengeInfo) {
        if (tag == kAlertTagRestore) {
            // The restore is confirmed only when the user tapped the affirmative button.
            if ([alert[kAlertButtonMessageKey] intValue] != 0) {
                [self showVerifyDialog:kRestoreProcessingMessage];
                [[PurchaseManager sharedManager] setDelegate:self];
                [[PurchaseManager sharedManager] beginRestore];
                return;
            }
            action = @selector(hideChallengeCoverView);
        } else if (tag != kAlertTagRetry) {
            [self cancelShare:NO];
            return;
        } else if (verifyPurchaseType == kVerifyPurchaseTypeStore) {
            action = @selector(turnToStore);
        } else if (verifyPurchaseType != kVerifyPurchaseTypeChallenge) {
            return;
        }
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self performSelector:action];
#pragma clang diagnostic pop
}

/** @ghidraAddress 0x28e84 */
- (void)challengeConnectError:(nullable id)response {
    int status = [response[kChallengeStatusKey] intValue];
    if (response[kChallengeStatusKey] != nil) {
        if (status == kChallengeStatusUpdateRequired) {
            [self hideChallengeCoverView];
            [[AlertViewManager sharedManager] showUpdateAlert];
            return;
        }
        if (status == kChallengeStatusNoScratch) {
            NSString *message = response[kChallengeErrorMessageKey] ?: kChallengeNoScratchMessage;
            [self hideChallengeCoverView];
            [[AlertViewManager sharedManager]
                makeAlert:0
                 delegate:nil
                      tag:0
                    title:@""
                      msg:message
                   cancel:[NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil]
                  btnText:nil
                     show:YES];
            return;
        }
    }
    // Any other status shows the generic server-error message, overridden by the response's own.
    NSString *message = response[kChallengeErrorMessageKey] ?:
                            [NSBundle.mainBundle localizedStringForKey:@"ServerErrorMsg"
                                                                 value:@""
                                                                 table:nil];
    [self hideChallengeCoverView];
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:nil
                                            tag:0
                                          title:@""
                                            msg:message
                                         cancel:[NSBundle.mainBundle localizedStringForKey:@"OK"
                                                                                     value:@""
                                                                                     table:nil]
                                        btnText:nil
                                           show:YES];
}

/** @ghidraAddress 0x38618 */
- (void)errorIDDownload:(nullable id)sender msgStr:(nullable NSString *)message {
    if (message == nil || [message isEqualToString:@""]) {
        message = [NSBundle.mainBundle localizedStringForKey:@"NetworkErrorMsg"
                                                       value:@""
                                                       table:nil];
    }
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:nil
                                            tag:0
                                          title:@""
                                            msg:message
                                         cancel:[NSBundle.mainBundle localizedStringForKey:@"OK"
                                                                                     value:@""
                                                                                     table:nil]
                                        btnText:nil
                                           show:YES];
    idManager = nil;
    [self hideChallengeCoverView];
}

/** @ghidraAddress 0x29df8 */
- (void)downloaderError:(nullable id)downloader {
    int tag = ((Downloader *)downloader).tag;
    if ((unsigned int)(tag - 1) < 3) {
        [self hideChallengeCoverView];
        [[AlertViewManager sharedManager]
            makeAlert:0
             delegate:nil
                  tag:0
                title:@""
                  msg:[NSBundle.mainBundle localizedStringForKey:@"ServerErrorMsg"
                                                           value:@""
                                                           table:nil]
               cancel:[NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil]
              btnText:nil
                 show:YES];
        return;
    }
    if (tag == 0) {
        infoDownloader = nil;
        [self challengeModeEnable:NO];
    }
}

/** @ghidraAddress 0x3880c */
- (void)agreementError:(nullable id)view msgStr:(nullable NSString *)message {
    if (message == nil || [message isEqualToString:@""]) {
        message = [NSBundle.mainBundle localizedStringForKey:@"NetworkErrorMsg"
                                                       value:@""
                                                       table:nil];
    }
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:nil
                                            tag:0
                                          title:@""
                                            msg:message
                                         cancel:[NSBundle.mainBundle localizedStringForKey:@"OK"
                                                                                     value:@""
                                                                                     table:nil]
                                        btnText:nil
                                           show:YES];
    [view removeFromSuperview];
    [self hideChallengeCoverView];
}

/** @ghidraAddress 0x38434 */
- (void)purchaseFailed:(nullable id)productID error:(nullable NSError *)error {
    [[PurchaseManager sharedManager] setDelegate:nil];
    // A network failure (code 1) shows the error and then hides the challenge cover; any other
    // failure re-requests the challenge info. Either way the verify dialog is hidden last.
    SEL action = @selector(downloadChallengeInfo);
    if (error.code == 1) {
        [[AlertViewManager sharedManager]
            makeAlert:0
             delegate:nil
                  tag:0
                title:@""
                  msg:[NSBundle.mainBundle localizedStringForKey:@"NetworkErrorMsg"
                                                           value:@""
                                                           table:nil]
               cancel:[NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil]
              btnText:nil
                 show:YES];
        action = @selector(hideChallengeCoverView);
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self performSelector:action];
#pragma clang diagnostic pop
    [self hideVerifyDialog];
}

/** @ghidraAddress 0x38af4 */
- (void)restoreNothing {
    [NSUserDefaults.standardUserDefaults setObject:kRestoreCompleteMarker
                                            forKey:kPrefChallengeRestoreEndKey];
    [[PurchaseManager sharedManager] setDelegate:nil];
    [self hideVerifyDialog];
    [[AlertViewManager sharedManager]
        makeAlert:0
         delegate:self
              tag:kRestoreCompleteAlertTag
            title:@""
              msg:[NSBundle.mainBundle localizedStringForKey:@"RestoreCompleteTitle"
                                                       value:@""
                                                       table:nil]
           cancel:[NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil]
          btnText:nil
             show:YES];
}

/** @ghidraAddress 0x38cfc */
- (void)restoreSucceeded {
    [NSUserDefaults.standardUserDefaults setObject:kRestoreCompleteMarker
                                            forKey:kPrefChallengeRestoreEndKey];
    [[PurchaseManager sharedManager] setDelegate:nil];
    [self hideVerifyDialog];
    [[AlertViewManager sharedManager]
        makeAlert:0
         delegate:self
              tag:kRestoreCompleteAlertTag
            title:@""
              msg:[NSBundle.mainBundle localizedStringForKey:@"RestoreCompleteTitle"
                                                       value:@""
                                                       table:nil]
           cancel:[NSBundle.mainBundle localizedStringForKey:@"OK" value:@"" table:nil]
          btnText:nil
             show:YES];
}

/** @ghidraAddress 0x3830c */
- (void)purchaseSucceeded:(nullable id)sender {
    [[PurchaseManager sharedManager] setDelegate:nil];
    [[AlertViewManager sharedManager] makeAlert:0
                                       delegate:self
                                            tag:1
                                          title:@""
                                            msg:kPurchaseSuccessMessage
                                         cancel:[NSBundle.mainBundle localizedStringForKey:@"OK"
                                                                                     value:@""
                                                                                     table:nil]
                                        btnText:nil
                                           show:YES];
}

#pragma mark - Music list

/** @ghidraAddress 0x2ae28 */
- (NSInteger)musicPlaylistViewControllerCurrentSelection:(nullable id)controller {
    // The built-in playlists map to sentinel selection indices; a manager playlist maps to its
    // index, and anything else (or none) is the default.
    id source = currentPlaylistSource;
    if (source == arrayNotPlayedTune) {
        return kPlaylistSelectionNotPlayed;
    }
    if (source == arrayHoldList) {
        return kPlaylistSelectionHold;
    }
    if (source == arrayNotHoldList) {
        return kPlaylistSelectionNotHold;
    }
    if (source == arrayLevelList) {
        return kPlaylistSelectionLevel;
    }
    if (source != nil) {
        NSUInteger index = [playlistManager indexOfPlaylist:source];
        if (index != NSNotFound) {
            return (NSInteger)index;
        }
    }
    return kPlaylistSelectionDefault;
}

/** @ghidraAddress 0x2a9e4 */
- (void)musicPlaylistViewController:(nullable id)controller
                   playlistSelected:(NSInteger)selection
                    selectedMusicID:(NSUInteger)musicID {
    // In add-to-playlist mode a real playlist index adds the music and the picker's actions hide.
    if (((MusicPlaylistViewController *)controller).listMode != MusicPlaylistListModePlaylists) {
        if (((MusicPlaylistViewController *)controller).listMode ==
            MusicPlaylistListModeAddToPlaylist) {
            if (selection >= 0 && (NSUInteger)selection < playlistManager.numberOfPlaylists) {
                [playlistManager addMusic:musicID toPlaylistAtIndex:selection];
                [playlistManager synchronize];
            }
            [musicListView hideAllPlaylistAction];
        }
        [self dismissViewControllerAnimated:YES completion:nil];
        [self musicShuffleEnable];
        [self setSearchEnable:YES];
        return;
    }

    // Browse mode: the built-in filters use sentinel indices; a real index is a saved playlist.
    BOOL builtIn =
        (selection == kPlaylistSelectionNotPlayed || selection == kPlaylistSelectionDefault ||
         selection == kPlaylistSelectionLevel || selection == kPlaylistSelectionHold ||
         selection == kPlaylistSelectionNotHold);
    if (builtIn) {
        [self changeMusicListView:selection musicID:0];
        if (selection != kPlaylistSelectionLevel) {
            [NSUserDefaults.standardUserDefaults setInteger:0 forKey:kPrefPlayListLevelKey];
        }
    } else {
        if (selection < 0 || (NSUInteger)selection >= playlistManager.numberOfPlaylists) {
            [self dismissViewControllerAnimated:YES completion:nil];
            [self musicShuffleEnable];
            [self setSearchEnable:YES];
            return;
        }
        [self changeMusicListView:selection musicID:0];
        [NSUserDefaults.standardUserDefaults setInteger:0 forKey:kPrefPlayListLevelKey];
    }

    // Record the selection: the hold filters set the hold flag, the others clear the remembered
    // playlist, and a real index stores that playlist's identifier.
    switch (selection) {
    case kPlaylistSelectionNotHold:
        [NSUserDefaults.standardUserDefaults removeObjectForKey:kPrefLastPlaylistKey];
        [NSUserDefaults.standardUserDefaults setInteger:2 forKey:kPrefPlayListHoldKey];
        break;
    case kPlaylistSelectionHold:
        [NSUserDefaults.standardUserDefaults removeObjectForKey:kPrefLastPlaylistKey];
        [NSUserDefaults.standardUserDefaults setInteger:1 forKey:kPrefPlayListHoldKey];
        break;
    case kPlaylistSelectionLevel:
        [NSUserDefaults.standardUserDefaults setInteger:0 forKey:kPrefPlayListHoldKey];
        break;
    case kPlaylistSelectionDefault:
    case kPlaylistSelectionNotPlayed:
        [NSUserDefaults.standardUserDefaults removeObjectForKey:kPrefLastPlaylistKey];
        break;
    default:
        if (selection >= 0) {
            [NSUserDefaults.standardUserDefaults
                setObject:[playlistManager identifierOfPlaylistAtIndex:selection]
                   forKey:kPrefLastPlaylistKey];
        }
        break;
    }
    [bottomView playlistButtonChanged:selection];
    [self dismissViewControllerAnimated:YES completion:nil];
    [self musicShuffleEnable];
    [self setSearchEnable:YES];
}

/** @ghidraAddress 0x352ac */
- (BOOL)changeMusicData:(nullable id)tune {
    // Load the tune's base info and score into the detail view.
    ScoreRecord *record = [ScoreRecord recordForTuneID:((TuneInfo *)tune).tuneID];
    [musicDetailView setInfo:tune score:record];
    // Load the extend chart when the tune has one whose file is present; otherwise clear it.
    if (((TuneInfo *)tune).extendID != 0 &&
        [StoreUtil existMusicFile:((TuneInfo *)tune).extendID]) {
        TuneInfo *extend = dictAllExtendTune[@(((TuneInfo *)tune).extendID)];
        ScoreRecord *extendRecord = [ScoreRecord recordForTuneID:((TuneInfo *)tune).extendID];
        [musicDetailView setExtendInfo:extend score:extendRecord];
    } else {
        [musicDetailView setExtendInfo:nil score:nil];
    }
    [musicDetailView
        infoChange:(int)[NSUserDefaults.standardUserDefaults integerForKey:kPrefDifficultyKey]];
    // Load and start the tune's own BGM if its archive carries one.
    KUnzip *archive = [[KUnzip alloc] initWithPath:((TuneInfo *)tune).filePath
                                              tail:kTuneInfoArchiveTail];
    NSMutableData *bgm = [archive uncompress:kTuneBgmEntryName];
    if (bgm != nil) {
        BFCodec *codec = [[BFCodec alloc] init];
        [codec cipherInit:GetBgmCipherKey()];
        [codec decipher:bgm];
        [[AudioManager sharedManager] loadBgmData:bgm];
        [[AudioManager sharedManager] startBgm:YES fadeTime:0.0];
    }
    return YES;
}

/** @ghidraAddress 0x20d74 */
- (nullable id)getTuneInfo:(nullable id)path {
    KUnzip *archive = [[KUnzip alloc] initWithPath:path tail:kTuneInfoArchiveTail];
    if (archive == nil) {
        return nil;
    }
    // The v3 member is ciphered with the tune-info key and carries a four-byte header.
    NSMutableData *v3 = [archive uncompress:kInfoV3EntryName];
    if (v3 != nil) {
        BFCodec *codec = [[BFCodec alloc] init];
        [codec cipherInit:CreateTuneInfoCipherKey()];
        [codec decipher:v3];
        NSData *body = [v3 subdataWithRange:NSMakeRange(kTuneInfoV3HeaderLength,
                                                        v3.length - kTuneInfoV3HeaderLength)];
        return [NSDictionary dictionaryFromPropertyListData:body];
    }
    // The older members use the BGM key and no header.
    NSMutableData *legacy = [archive uncompress:kInfoV2EntryName];
    if (legacy == nil) {
        legacy = [archive uncompress:kInfoEntryName];
        if (legacy == nil) {
            return nil;
        }
    }
    BFCodec *codec = [[BFCodec alloc] init];
    [codec cipherInit:GetBgmCipherKey()];
    [codec decipher:legacy];
    return [NSDictionary dictionaryFromPropertyListData:legacy];
}

/** @ghidraAddress 0x2a0b0 */
- (int)musicIndexForTuneID:(int)tuneID {
    NSArray<TuneInfo *> *list = arrayCurrentPlaylist ?: arrayAllTune;
    for (NSUInteger i = 0; i < list.count; ++i) {
        if ((int)list[i].tuneID == tuneID) {
            return (int)i;
        }
    }
    return -1;
}

/** @ghidraAddress 0x26998 */
- (void)reloadMarkerSelectView {
    if (markerSelectView.superview != nil) {
        [markerSelectView removeFromSuperview];
    }
    markerSelectView = nil;
    CGFloat size = isPad ? kMarkerSelectSizePad : kMarkerSelectSizePhone;
    CGFloat width = isPad ? kMarkerSelectWidthPad : kMarkerSelectWidthPhone;
    markerSelectView = [[MarkerSelectView alloc] initWithFrame:CGRectMake(0, -size, width, size)];
    [markerSelectView setDelegate:self];
    [markerSelectView setHidden:YES];
    isMarkerSelectOpen = NO;
    markerSelectView.layer.zPosition = kMarkerSelectZPosition;
    [self.view insertSubview:markerSelectView aboveSubview:btnMarker];
}

/** @ghidraAddress 0x2a004 */
- (nullable id)musicInfoForIndex:(NSUInteger)index {
    // Prefer the current playlist; without one, index the full tune array.
    if (arrayCurrentPlaylist == nil) {
        if (index < arrayAllTune.count) {
            return arrayAllTune[index];
        }
    } else if (index < arrayCurrentPlaylist.count) {
        return arrayCurrentPlaylist[index];
    }
    return nil;
}

#pragma mark - Game Center

/** @ghidraAddress 0x2d260 */
- (void)gameCenterStateChanged:(nullable id)sender {
    [btnLeaderboard setEnabled:GKLocalPlayer.localPlayer.isAuthenticated];
}

@end
