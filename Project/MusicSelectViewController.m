#import "MusicSelectViewController.h"

#import "MusicListView.h"
#import "MusicShareView.h"

// Landscape-left and landscape-right make up the supported orientation mask.
static const UIInterfaceOrientationMask kSupportedOrientations =
    UIInterfaceOrientationMaskLandscapeLeft | UIInterfaceOrientationMaskLandscapeRight;

@implementation MusicSelectViewController

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

#pragma mark - Share play

/** @ghidraAddress 0x30480 */
- (void)sharePlayManagerFailedSendMusicData:(nullable id)manager {
}

/** @ghidraAddress 0x30948 */
- (void)sharePlayManagerConnectHost:(nullable id)manager {
    [shareClientView changeClientModeConnected];
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
