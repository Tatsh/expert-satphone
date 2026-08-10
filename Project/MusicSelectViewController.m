#import "MusicSelectViewController.h"

#import "AlertViewManager.h"
#import "ChallengeModeRootView.h"
#import "JcfDownloadPageNavController.h"
#import "JubeatAppDelegate.h"
#import "MarkerSelectView.h"
#import "MusicDetailView.h"
#import "MusicListView.h"
#import "MusicPlaylistViewController.h"
#import "MusicSelectBottomView.h"
#import "MusicShareView.h"
#import "MusicView.h"
#import "NotificationPageNavController.h"
#import "PurchaseManager.h"
#import "PushNotificationView.h"
#import "TuneInfo.h"

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

// Turning to the store while a consume receipt is pending records this verify-purchase type and
// shows the verify dialog; a completed purchase reports the shared success message.
static const int kVerifyPurchaseTypeStore = 2;
static NSString *const kPurchaseSuccessMessage = @"購入処理が完了しました";
static NSString *const kSettingsTapSoundSuffix = @"MUSIC_RIGHT";
static NSString *const kVerifyProcessingMessage = @"処理中...";

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

@implementation MusicSelectViewController

@synthesize sharePlayManager = _sharePlayManager;

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

#pragma mark - Sound and store navigation

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

/** @ghidraAddress 0x33374 */
- (void)moveStore:(nullable id)store packID:(nullable NSString *)packID {
    [self dismissViewControllerAnimated:YES
                             completion:^{
                               /** @ghidraAddress 0x33428 */
                               [self turnToPackPurchase:packID];
                             }];
}

#pragma mark - Search

/** @ghidraAddress 0x369f8 */
- (void)searchBar:(nullable UISearchBar *)searchBar textDidChange:(nullable NSString *)searchText {
    backUpString = [NSString stringWithString:searchText];
    if ([self searchStringChanged:searchText]) {
        [self exeSearchPickUp];
    }
}

#pragma mark - Store info

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

#pragma mark - Popover and challenge mode

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
