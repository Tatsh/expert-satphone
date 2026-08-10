#import "MusicSelectViewController.h"

#import "JubeatAppDelegate.h"
#import "MarkerSelectView.h"
#import "MusicDetailView.h"
#import "MusicListView.h"
#import "MusicPlaylistViewController.h"
#import "MusicShareView.h"
#import "MusicView.h"
#import "PushNotificationView.h"
#import "TuneInfo.h"

// Landscape-left and landscape-right make up the supported orientation mask.
static const UIInterfaceOrientationMask kSupportedOrientations =
    UIInterfaceOrientationMaskLandscapeLeft | UIInterfaceOrientationMaskLandscapeRight;

// The custom-BGM selection preferences: the chosen tune's id and whether the custom BGM is on.
static NSString *const kPrefCustomBgmIDKey = @"PrefCustomBgmID";
static NSString *const kPrefCustomBgmOnKey = @"PrefCustomBgmON";

@implementation MusicSelectViewController

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

/** @ghidraAddress 0x2ca20 */
- (void)musicViewPressed:(nullable id)sender {
    [musicListView hideAllPlaylistAction];
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

#pragma mark - Host select

/** @ghidraAddress 0x31b30 */
- (void)sharePlayManagerHostSelectStart:(nullable id)manager {
    willStart = YES;
    [self startPlay:musicDetailView.info];
}

#pragma mark - Share play

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

@end
