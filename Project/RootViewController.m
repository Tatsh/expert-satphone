#import "RootViewController.h"

#import <QuartzCore/QuartzCore.h>

#import "AudioManager.h"
#import "CJSONSerializer.h"
#import "Downloader.h"
#import "EditorIDManager.h"
#import "ImageCache.h"
#import "JubeatAppDelegate.h"
#import "LogoViewController.h"
#import "MusicSelectViewController.h"
#import "ScratchUtil.h"
#import "TitleViewControllerKnt.h"
#import "TitleViewControllerNte.h"
#import "TitleViewControllerOrg.h"
#import "TitleViewControllerRpl.h"

// The ivars reached so far. None has an accessor pair anywhere in the binary, so none is a
// property. Offset globals in declaration order: 0x34b770, 0x34b778, 0x34b77c, 0x34b780, 0x34b784,
// 0x34b788, 0x34b78c, 0x34b794.
@interface RootViewController () {
    UIViewController *titleViewCtrl;
    UIViewController *gameViewCtrl;
    UIViewController *editViewCtrl;
    UIViewController *storeViewCtrl;
    NSString *suspendedAnimID;
    double durationIn;
    double durationOut;
    UIView *fadeView;
    LogoViewController *logoViewCtrl;
    NSString *currentSceneID;
    MusicSelectViewController *musicSelectViewCtrl;
    BOOL _isActive;
    // The achievement-message overlay, at offset global 0x34b774. Its concrete class is not
    // established yet, so it is typed UIView and its three selectors are declared below.
    UIView *achieveMessage;
}
// DECLARED ONLY — bodies not reconstructed yet; -appDidBecomeActive: sends all three.
// Bodies at 0x1aa4a4, 0x1aa60c, and 0x1aa71c.
- (void)downloadCustomSequence;
- (void)autoMoveChallenge;
- (void)autoMovePackDownload;
@end

// The five scene identifiers, from the CFStrings at 0x2e0000, 0x2e0080, and 0x2e01a0 to 0x2e01e0.
// "SceneStore" sits beside them in the pool and is not reached by anything recovered so far.
static NSString *const kLogoSceneID = @"SceneLogo";
static NSString *const kSelectSceneID = @"SceneSelect";
static NSString *const kTitleSceneID = @"SceneTitle";
static NSString *const kGameSceneID = @"SceneGame";
static NSString *const kEditSceneID = @"SceneEdit";

// The transition names the two dispatchers branch on, from the CFStrings at 0x2e0020 to 0x2e0180.
static NSString *const kTitleAnimationName = @"AnimTitle";
static NSString *const kChangeThemeAnimationName = @"AnimChangeTheme";
static NSString *const kTitleSwitchAnimationName = @"AnimTitleSwitch";
static NSString *const kSelectAnimationName = @"AnimSelect";
static NSString *const kStartGameAnimationName = @"AnimStartGame";
static NSString *const kGameRestartAnimationName = @"AnimGameRestart";
static NSString *const kGameReplayAnimationName = @"AnimGameReplay";
static NSString *const kReturnMusicSelectAnimationName = @"AnimReturnMusicSelect";
static NSString *const kStartEditAnimationName = @"AnimStartEdit";
static NSString *const kEndEditAnimationName = @"AnimEndEdit";

// The three keys of the push-receipt body, from the CFStrings at 0x2d4cc0, 0x2d5c20, and 0x2d5000.
static NSString *const kPushResponseUserIDKey = @"user_id";
static NSString *const kPushResponsePushIDKey = @"push_id";
static NSString *const kPushResponseStatusKey = @"status";

// The two values the status field takes, chosen by the tbz at 0x1ab1e8. The binary spells them as
// bare integers, so they are named here after the case each one reports.
static const int kPushResponseStatusLaunched = 1;
static const int kPushResponseStatusReceived = 2;

// The key the push identifier is read out of the payload under, matching the delegate's own
// "id" entry. From the CFString at 0x2d46a0.
static NSString *const kNotificationIdentifierKey = @"id";

// The theme-change fade timings. The 0.6 is the pooled double at 0x28f230, whose bit pattern
// 0x3FE3333340000000 is 0.6f widened rather than the closest double to 0.6.
static const double kChangeThemeFadeInDuration = 0.6f;
static const double kChangeThemeFadeOutDuration = 1.0;

// Both title-switch durations are the same immediate, an fmov of 0x3FF8000000000000.
static const double kTitleSwitchFadeDuration = 1.5;

// The selectors the dispatcher sends to controllers whose concrete class is not established. The
// title screens have two implementations, and the game and edit screens have not been located at
// all, so these are declared on UIViewController; see TYPES_PENDING.md.
@interface UIViewController (JubeatScene)
- (void)start;
- (void)stopAnimation;
- (void)showLogo;
- (void)startGame;
- (void)startAnimation;
- (void)loadResources;
- (void)releaseResources;
- (void)terminate;
- (void)restartGame;
- (void)replayGame;
- (void)suspend;
- (void)resume;
@end

// The achievement-message overlay's selectors. Its class is not established yet; see
// -openAchiveMessage: and -messageClose. Declared on UIView so the overlay can be messaged.
@interface UIView (JubeatAchieveMessage)
- (void)setAchieveTitle:(nullable id)title;
- (void)transReset;
- (void)enterAnimationStart;
@end

@implementation RootViewController

#pragma mark - Transition helpers

// De-inlined. The binary emits this same three-message teardown five times, at 0x1a95a0, 0x1a965c,
// 0x1a970c, 0x1a990c, and 0x1a9c68. Nilling the ivar stays at the call site because each copy
// clears a different one.
- (void)detachChildViewController:(UIViewController *)controller {
    [controller willMoveToParentViewController:nil];
    [controller.view removeFromSuperview];
    [controller removeFromParentViewController];
}

// De-inlined. Emitted twice, at 0x1a9604 and 0x1a96c0, with identical bodies. Theme 2 delegates to
// -createKnitTitleViewController, which assigns titleViewCtrl itself; the other two allocate here.
// Note the fallback is the original skin, so an out-of-range theme lands there rather than failing.
- (void)createTitleViewControllerForTheme:(JubeatTheme)theme {
    if (theme == JubeatThemeKnit) {
        [self createKnitTitleViewController];
        return;
    }
    if (theme == JubeatThemeReflecBeatPlus) {
        titleViewCtrl = [[TitleViewControllerRpl alloc] init];
        return;
    }
    titleViewCtrl = [[TitleViewControllerOrg alloc] init];
}

// De-inlined from the two title routes: install the freshly built title screen and start it.
- (void)installTitleViewController {
    [self addChildViewController:titleViewCtrl];
    [titleViewCtrl didMoveToParentViewController:self];
    [self.view insertSubview:titleViewCtrl.view belowSubview:fadeView];
    [titleViewCtrl start];
}

// De-inlined from the tail at 0x1a9a94: fade the black cover back out over durationOut, and hand
// off to -fadeinAnimStop:finished:context:, which is what re-enables input.
- (void)beginFadeInForAnimation:(NSString *)animationID {
    [UIView beginAnimations:animationID context:NULL];
    [UIView setAnimationCurve:UIViewAnimationCurveLinear];
    [UIView setAnimationDuration:durationOut];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(fadeinAnimStop:finished:context:)];
    fadeView.alpha = 0.0;
    [UIView commitAnimations];
}

// The class-method calls to UIView below are the pre-iOS-4 begin/commit animation API, deprecated
// in 2010 and never removed. They are not a reconstruction artefact: the receiver resolves to
// _OBJC_CLASS_$_UIView at 0x348210, the imported UIKit class symbol with 449 cross-references, and
// all six selectors were read from their pointer slots at 0x345dd8, 0x345de0, 0x3424e0, 0x345de8,
// 0x345df8, and 0x345e00.
//
// Do not rewrite them as +animateWithDuration:animations:completion:. The whole two-phase
// transition is driven by setAnimationDelegate: plus setAnimationDidStopSelector:, which is what
// hands control from -fade: to -fadeoutAnimStop: and on to -fadeinAnimStop:. A block-based
// rewrite would restructure the control flow this file exists to document.

#pragma mark - Transitions

/** @ghidraAddress 0x1a7770 */
- (void)fade:(NSString *)animationName
     durationIn:(double)durationIn
    durationOut:(double)durationOut {
    // Input is blocked for the whole transition. Nothing here re-enables it; that is
    // -fadeinAnimStop:finished:context:'s job, at the far end of the two animations.
    [UIApplication.sharedApplication beginIgnoringInteractionEvents];

    // Both durations are parked in ivars so the second half of the transition can read durationOut
    // long after this call has returned.
    self->durationIn = durationIn;
    self->durationOut = durationOut;

    [fadeView removeFromSuperview];
    fadeView = nil;

    // A full-screen black cover, built fresh each time rather than reused.
    fadeView = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    fadeView.opaque = NO;
    fadeView.backgroundColor = UIColor.blackColor;
    fadeView.alpha = 0.0;
    [self.view addSubview:fadeView];

    [UIView beginAnimations:animationName context:NULL];
    [UIView setAnimationCurve:UIViewAnimationCurveLinear];
    // Read back out of the ivar just written, not from the parameter register.
    [UIView setAnimationDuration:self->durationIn];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(fadeoutAnimStop:finished:context:)];
    // Fading the cover in, so the screen goes to black. The animation name is what tells the stop
    // callback which transition this was.
    fadeView.alpha = 1.0;
    [UIView commitAnimations];
}

/** @ghidraAddress 0x1a9420 */
- (void)fadeoutAnimStop:(NSString *)animationID
               finished:(NSNumber *)finished
                context:(void *)context {
    // Neither finished nor context is read anywhere in the method.
    //
    // A restart or a replay keeps its audio and its textures, which is what makes those two
    // transitions cheap. Every other transition drops both.
    if (![animationID isEqualToString:kGameRestartAnimationName] &&
        ![animationID isEqualToString:kGameReplayAnimationName]) {
        [AudioManager.sharedManager stopAllSe];
        [AudioManager.sharedManager releaseBgm:YES];
        [ImageCache.sharedCache clear];
    }

    // Read before the active test, so it is fetched even on the path that does nothing with it.
    JubeatTheme theme = JubeatAppDelegate.appDelegate.currentTheme;

    if (!_isActive) {
        // Off-screen: park the transition rather than run it. Something else replays it later.
        suspendedAnimID = animationID;
        return;
    }
    suspendedAnimID = nil;

    if ([animationID isEqualToString:kTitleAnimationName]) {
        // Logo to title. The logo screen gets no stop message before teardown, unlike the title and
        // music-select screens below.
        [self detachChildViewController:logoViewCtrl];
        logoViewCtrl = nil;
        [self createTitleViewControllerForTheme:theme];
        [self installTitleViewController];
    } else if ([animationID isEqualToString:kChangeThemeAnimationName]) {
        // Music select back to title under a new skin.
        [musicSelectViewCtrl stopStoreInfo];
        [self detachChildViewController:musicSelectViewCtrl];
        musicSelectViewCtrl = nil;
        [self createTitleViewControllerForTheme:theme];
        [self installTitleViewController];
    } else if ([animationID isEqualToString:kSelectAnimationName]) {
        // Title to music select.
        [titleViewCtrl stopAnimation];
        [self detachChildViewController:titleViewCtrl];
        titleViewCtrl = nil;
        musicSelectViewCtrl = [[MusicSelectViewController alloc] init];
        [self addChildViewController:musicSelectViewCtrl];
        [musicSelectViewCtrl didMoveToParentViewController:self];
        [self.view insertSubview:musicSelectViewCtrl.view belowSubview:fadeView];
        [musicSelectViewCtrl startMainBgm];
    } else if ([animationID isEqualToString:kStartGameAnimationName]) {
        // Music select into gameplay. gameViewCtrl is built elsewhere; this only reveals it.
        [self detachChildViewController:musicSelectViewCtrl];
        musicSelectViewCtrl = nil;
        [self.view insertSubview:gameViewCtrl.view belowSubview:fadeView];
        [gameViewCtrl loadResources];
        // Tested a second time, having already been tested above. Reproduced as compiled: a callee
        // between the two could in principle have cleared it.
        if (_isActive) {
            [gameViewCtrl startAnimation];
        }
    } else if ([animationID isEqualToString:kReturnMusicSelectAnimationName]) {
        // Gameplay back to music select. Note the game screen is torn down only partly: its view
        // goes, but it is never sent -willMoveToParentViewController: or
        // -removeFromParentViewController, and gameViewCtrl is not nilled.
        [gameViewCtrl terminate];
        [gameViewCtrl releaseResources];
        [gameViewCtrl.view removeFromSuperview];
        if (musicSelectViewCtrl == nil) {
            musicSelectViewCtrl = [[MusicSelectViewController alloc] init];
            [self addChildViewController:musicSelectViewCtrl];
            [self.view insertSubview:musicSelectViewCtrl.view belowSubview:fadeView];
            [musicSelectViewCtrl didMoveToParentViewController:self];
            [musicSelectViewCtrl startMainBgm];
        }
    } else if ([animationID isEqualToString:kStartEditAnimationName]) {
        // Music select into the note editor.
        [self detachChildViewController:musicSelectViewCtrl];
        musicSelectViewCtrl = nil;
        [self.view insertSubview:editViewCtrl.view belowSubview:fadeView];
        [editViewCtrl loadResources];
        if (_isActive) {
            [editViewCtrl startAnimation];
        }
    } else if ([animationID isEqualToString:kEndEditAnimationName]) {
        // Editor back to music select. Same partial teardown as the gameplay route, and here the
        // music-select screen is rebuilt unconditionally rather than only when nil.
        [editViewCtrl terminate];
        [editViewCtrl releaseResources];
        [editViewCtrl.view removeFromSuperview];
        musicSelectViewCtrl = [[MusicSelectViewController alloc] init];
        [self addChildViewController:musicSelectViewCtrl];
        [self.view insertSubview:musicSelectViewCtrl.view belowSubview:fadeView];
        [musicSelectViewCtrl didMoveToParentViewController:self];
        [musicSelectViewCtrl startMainBgm];
    } else if ([animationID isEqualToString:kGameRestartAnimationName]) {
        [self.view insertSubview:gameViewCtrl.view belowSubview:fadeView];
        [gameViewCtrl restartGame];
    } else if ([animationID isEqualToString:kGameReplayAnimationName]) {
        [self.view insertSubview:gameViewCtrl.view belowSubview:fadeView];
        [gameViewCtrl replayGame];
    } else if ([animationID isEqualToString:kTitleSwitchAnimationName]) {
        [self titleSwitch];
    }
    // Every arm, and an animation name matching none of them, converges here.
    [self beginFadeInForAnimation:animationID];
}

/** @ghidraAddress 0x1a9fec */
- (void)fadeinAnimStop:(NSString *)animationID
              finished:(NSNumber *)finished
               context:(void *)context {
    // As with -fadeoutAnimStop:, neither finished nor context is read.
    JubeatAppDelegate *delegate = JubeatAppDelegate.appDelegate;

    // Each arm records which scene is now up, then wakes the screen that has just been revealed.
    if ([animationID isEqualToString:kTitleAnimationName] ||
        [animationID isEqualToString:kChangeThemeAnimationName] ||
        [animationID isEqualToString:kTitleSwitchAnimationName]) {
        currentSceneID = kTitleSceneID;
        [titleViewCtrl showLogo];
    } else if ([animationID isEqualToString:kSelectAnimationName] ||
               [animationID isEqualToString:kReturnMusicSelectAnimationName]) {
        currentSceneID = kSelectSceneID;
        [musicSelectViewCtrl checkAndRetryBgm];
        [musicSelectViewCtrl requestNewInfo];
    } else if ([animationID isEqualToString:kStartGameAnimationName]) {
        currentSceneID = kGameSceneID;
        [gameViewCtrl startGame];
    } else if ([animationID isEqualToString:kStartEditAnimationName]) {
        // The editor is started with the same -startGame selector the game screen uses.
        currentSceneID = kEditSceneID;
        [editViewCtrl startGame];
    } else if ([animationID isEqualToString:kEndEditAnimationName]) {
        currentSceneID = kSelectSceneID;
        [musicSelectViewCtrl checkAndRetryBgm];
        [musicSelectViewCtrl requestNewInfo];
        // Only opens the detail panel when the player has nothing else queued up.
        if (delegate.jcfDownloadID == nil && delegate.notificationURL == nil &&
            delegate.storePackID == nil && delegate.storeCampaignID == nil &&
            delegate.storeGenreID == nil) {
            [musicSelectViewCtrl startOpenDetailPanel];
        }
    }

    // The black cover is torn down here rather than merely hidden, so every transition allocates a
    // fresh one in -fade:durationIn:durationOut:.
    [fadeView removeFromSuperview];
    fadeView = nil;

    // Deferred work the delegate parked while another screen was up. This runs on arrival at music
    // select whichever route got there, including the two arms above that set the scene themselves.
    if ([currentSceneID isEqualToString:kSelectSceneID]) {
        BOOL startedDownload = NO;
        if (delegate.jcfDownloadID != nil) {
            [musicSelectViewCtrl JcfDownLoad:delegate.jcfDownloadID];
            startedDownload = YES;
        }
        if (delegate.storePackID != nil || delegate.storeCampaignID != nil ||
            delegate.storeGenreID != nil) {
            [musicSelectViewCtrl schemeMoveStore];
        } else if (!startedDownload) {
            [musicSelectViewCtrl notificationDisp];
        }
    }

    // The other end of the block -fade:durationIn:durationOut: put in place. Reached on every path,
    // including an unrecognised animation name, so input cannot be left disabled.
    [UIApplication.sharedApplication endIgnoringInteractionEvents];
}

/** @ghidraAddress 0x1a81b4 */
- (void)openStoreAnimStop:(NSString *)animationID
                 finished:(NSNumber *)finished
                  context:(void *)context {
    // The store slides in over music select with a 3-D layer transform rather than through the
    // fade machinery above, so this callback pairs with neither -fade: nor its two dispatchers.
    [AudioManager.sharedManager releaseBgm:YES];

    // Rasterisation was turned on for the duration of the transform and is turned off again here on
    // both layers, which is the usual trick for keeping a 3-D rotation smooth.
    musicSelectViewCtrl.view.layer.shouldRasterize = NO;
    // Restores the identity transform, copied 128 bytes at a time out of the CATransform3DIdentity
    // global at 0x2c8018 rather than built inline.
    self.view.layer.sublayerTransform = CATransform3DIdentity;
    storeViewCtrl.view.layer.shouldRasterize = NO;
    storeViewCtrl.view.layer.anchorPointZ = 0.0;

    // Music select goes away entirely once the store is up.
    [self detachChildViewController:musicSelectViewCtrl];
    musicSelectViewCtrl = nil;

    [storeViewCtrl loadInitialStoreInfo];
    [UIApplication.sharedApplication endIgnoringInteractionEvents];
}

/** @ghidraAddress 0x1a8d7c */
- (void)endStoreAnimStop:(NSString *)animationID
                finished:(NSNumber *)finished
                 context:(void *)context {
    // The mirror of -openStoreAnimStop:. Note input is released first here and last there.
    [UIApplication.sharedApplication endIgnoringInteractionEvents];

    musicSelectViewCtrl.view.layer.shouldRasterize = NO;
    self.view.layer.sublayerTransform = CATransform3DIdentity;
    storeViewCtrl.view.layer.shouldRasterize = NO;

    [self detachChildViewController:storeViewCtrl];
    storeViewCtrl = nil;

    musicSelectViewCtrl.view.layer.anchorPointZ = 0.0;
    // Cleared a second time, having already been cleared at the top of the method. Reproduced as
    // compiled; nothing between the two sets it.
    musicSelectViewCtrl.view.layer.shouldRasterize = NO;

    [musicSelectViewCtrl startMainBgm];
    [musicSelectViewCtrl requestNewInfo];

    // The same deferred-download check the fade-in dispatcher performs, but without the store and
    // notification cases: coming back from the store, only a pending chart download is acted on.
    if (JubeatAppDelegate.appDelegate.jcfDownloadID != nil) {
        [musicSelectViewCtrl JcfDownLoad:JubeatAppDelegate.appDelegate.jcfDownloadID];
    }
}

/** @ghidraAddress 0x1a743c */
- (void)createKnitTitleViewController {
    // The hinabita collaboration wins when both flags are set: its test comes first and short
    // circuits to the knit screen without ever reading isNagaCoraMode.
    if (!JubeatAppDelegate.appDelegate.isHinabitaMode &&
        JubeatAppDelegate.appDelegate.isNagaCoraMode) {
        titleViewCtrl = [[TitleViewControllerNte alloc] init];
        return;
    }
    titleViewCtrl = [[TitleViewControllerKnt alloc] init];
}

/** @ghidraAddress 0x1a8bd0 */
- (void)titleSwitch {
    // Only the NagaCora screen is stopped before teardown. The knit screen it is replaced with is
    // not, so this is a class test rather than a nil guard.
    if ([titleViewCtrl isKindOfClass:TitleViewControllerNte.class]) {
        [titleViewCtrl stopAnimation];
    }
    [self detachChildViewController:titleViewCtrl];
    titleViewCtrl = nil;

    // Always the knit screen, whatever was there before: this transition only ever switches towards
    // it, never away.
    titleViewCtrl = [[TitleViewControllerKnt alloc] init];
    [self addChildViewController:titleViewCtrl];
    [titleViewCtrl didMoveToParentViewController:self];
    [self.view insertSubview:titleViewCtrl.view belowSubview:fadeView];
    [titleViewCtrl start];
}

/** @ghidraAddress 0x1a8a68 */
- (void)changeThemeAndGoTitle {
    if (JubeatAppDelegate.appDelegate.isPad) {
        // Dismisses with no completion, then fades straight away.
        [musicSelectViewCtrl dismissViewControllerAnimated:YES completion:nil];
        [self fade:kChangeThemeAnimationName
             durationIn:kChangeThemeFadeInDuration
            durationOut:kChangeThemeFadeOutDuration];
        return;
    }
    [musicSelectViewCtrl dismissViewControllerAnimated:YES
                                            completion:^{
                                              /** @ghidraAddress 0x1a8b80 */
                                              // The same fade as the iPad arm above, deferred
                                              // until the dismissal finishes.
                                              [self fade:kChangeThemeAnimationName
                                                   durationIn:kChangeThemeFadeInDuration
                                                  durationOut:kChangeThemeFadeOutDuration];
                                            }];
}

/** @ghidraAddress 0x1a8bb4 */
- (void)changeTitleTheme {
    [self fade:kTitleSwitchAnimationName
         durationIn:kTitleSwitchFadeDuration
        durationOut:kTitleSwitchFadeDuration];
}

/** @ghidraAddress 0x1a8d64 */
- (void)reloadMarkers {
    // No nil guard; a nil controller makes this a no-op.
    [musicSelectViewCtrl reloadMarkerSelectView];
}

/** @ghidraAddress 0x1aaaa4 */
- (void)pushNotificate {
    // Two guards, unlike -reloadMarkers above, which has none. The scene test comes first, so a
    // notification arriving anywhere but the select screen is dropped here rather than shown.
    if (![currentSceneID isEqualToString:kSelectSceneID]) {
        return;
    }
    if (musicSelectViewCtrl == nil) {
        return;
    }
    [musicSelectViewCtrl pushNotificate];
}

/** @ghidraAddress 0x1a79d4 */
- (void)startLogo {
    logoViewCtrl = [[LogoViewController alloc] init];
    [self addChildViewController:logoViewCtrl];
    [logoViewCtrl didMoveToParentViewController:self];
    [self.view addSubview:logoViewCtrl.view];
    [logoViewCtrl start];
    // A plain objc_storeStrong into the ivar, which is why this is an assignment and not a setter
    // call: the class has no -setCurrentSceneID:.
    currentSceneID = kLogoSceneID;
}

/** @ghidraAddress 0x1a7ad8 */
- (void)endLogo {
    // Fade out the logo over 0.5 and back in over 1.0, then start the Game Center login. The two
    // durations are fmov immediates 0x3fe0000000000000 (0.5) and 0x3ff0000000000000 (1.0) at
    // 0x1a7af4-0x1a7af8.
    [self fade:kTitleAnimationName durationIn:0.5 durationOut:1.0];
    [JubeatAppDelegate.appDelegate loginGameCenter];
}

/** @ghidraAddress 0x1a7b3c */
- (void)endTitle {
    // A single fade into the select screen: durationIn 1.5, durationOut 0.5 (fmov immediates
    // 0x3ff8000000000000 and 0x3fe0000000000000 at 0x1a7b4c-0x1a7b50).
    [self fade:kSelectAnimationName durationIn:1.5 durationOut:0.5];
}

#pragma mark - Game transitions

/** @ghidraAddress 0x1a925c */
- (void)musicRestart {
    // Restart keeps its audio and textures, so the fade dispatcher's AnimGameRestart arm is cheap.
    [self fade:kGameRestartAnimationName durationIn:1.0 durationOut:0.5];
}

/** @ghidraAddress 0x1a9278 */
- (void)musicReplay {
    [self fade:kGameReplayAnimationName durationIn:1.0 durationOut:0.5];
}

/** @ghidraAddress 0x1a9294 */
- (void)returnToMusicSelect {
    [self fade:kReturnMusicSelectAnimationName durationIn:1.0 durationOut:0.5];
}

#pragma mark - Achievement message

/** @ghidraAddress 0x1ab008 */
- (void)openAchiveMessage:(id)title {
    // The title argument is forwarded straight into -setAchieveTitle: (x2 is untouched between the
    // method entry and the call at 0x1ab030). The overlay resets its transform, starts its enter
    // animation, and is added to the root view.
    [achieveMessage setAchieveTitle:title];
    [achieveMessage transReset];
    [achieveMessage enterAnimationStart];
    [self.view addSubview:achieveMessage];
}

/** @ghidraAddress 0x1ab094 */
- (void)messageClose {
    [achieveMessage transReset];
    [achieveMessage removeFromSuperview];
}

/** @ghidraAddress 0x1ab0d4 */
- (void)responseRemoteNotification:(BOOL)launchedFromNotification
                          pushInfo:(NSDictionary *)pushInfo {
    NSMutableDictionary *body = [[NSMutableDictionary alloc] init];
    // setValue:forKey:, not setObject:forKey:, which matters: a nil push identifier removes the key
    // rather than raising. The rest of the tree uses setObject:forKey:, so this is a real
    // difference and not a house style.
    [body setValue:[EditorIDManager getKeyString:EditorIDManager.getEditorIDKey]
            forKey:kPushResponseUserIDKey];
    [body setValue:[pushInfo objectForKey:kNotificationIdentifierKey]
            forKey:kPushResponsePushIDKey];
    // The tbz at 0x1ab1e8 tests bit 0 only, so this is the BOOL argument and nothing else.
    [body setValue:@(launchedFromNotification ? kPushResponseStatusLaunched :
                                                kPushResponseStatusReceived)
            forKey:kPushResponseStatusKey];

    // NULL for the error, so a serialisation failure is indistinguishable from success and would
    // reach -initWithURL:postJsonData:delegate: as nil.
    NSData *json = [CJSONSerializer.serializer serializeDictionary:body error:NULL];

    // A nil delegate, so nothing observes the outcome: the receipt is sent and forgotten.
    Downloader *downloader = [[Downloader alloc] initWithURL:ScratchUtil.pushNotificationResponseURL
                                                postJsonData:json
                                                    delegate:nil];
    [downloader startDownloading];
}

#pragma mark - Application state

/** @ghidraAddress 0x1aab40 */
- (void)appWillResignActive:(NSNotification *)notification {
    // Any open alert is dismissed and the controller marks itself inactive, which is what makes a
    // transition arriving while backgrounded park its name in suspendedAnimID instead of running.
    [[NSClassFromString(@"AlertViewManager") sharedManager] closeAlert];
    _isActive = NO;
    // The game and edit screens are suspended only while they are the visible child — their view's
    // superview is the root view. Verified at 0x1aac0c and the mirror at the edit block.
    if (gameViewCtrl.view.superview == self.view) {
        [gameViewCtrl suspend];
    }
    if (editViewCtrl.view.superview == self.view) {
        [editViewCtrl suspend];
    }
}

/** @ghidraAddress 0x1aacc8 */
- (void)appDidBecomeActive:(NSNotification *)notification {
    _isActive = YES;
    // A transition that arrived while inactive was parked in suspendedAnimID; run it now, clearing
    // the ivar first so a re-entrant become-active does not run it twice.
    NSString *parked = suspendedAnimID;
    if (parked) {
        suspendedAnimID = nil;
        [self fadeoutAnimStop:parked finished:nil context:NULL];
    }
    [self downloadCustomSequence];
    [self autoMoveChallenge];
    [self autoMovePackDownload];
    // The mirror of -appWillResignActive:: resume the visible game or edit child.
    if (gameViewCtrl.view.superview == self.view) {
        [gameViewCtrl resume];
    }
    if (editViewCtrl.view.superview == self.view) {
        [editViewCtrl resume];
    }
}

/** @ghidraAddress 0x1aae84 */
- (void)appWillTerminate:(NSNotification *)notification {
    [NSUserDefaults.standardUserDefaults synchronize];
    [gameViewCtrl terminate];
    [editViewCtrl terminate];
}

/** @ghidraAddress 0x1aab08 */
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - View lifecycle

/** @ghidraAddress 0x1aaf00 */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

/** @ghidraAddress 0x1aaf38 */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

/** @ghidraAddress 0x1aaf70 */
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

/** @ghidraAddress 0x1aafa8 */
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

#pragma mark - Rotation

/** @ghidraAddress 0x1aafe0 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
    // orientation - 1 < 2 (unsigned), so only Portrait (1) and PortraitUpsideDown (2) rotate.
    // Verified at 0x1aafe0: sub x8,x2,#0x1 / cmp x8,#0x2 / cset w0,cc.
    return (NSUInteger)(orientation - UIInterfaceOrientationPortrait) < 2;
}

/** @ghidraAddress 0x1aaff0 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    // 0x6 = Portrait | PortraitUpsideDown. Verified at 0x1aaff0: orr w0,wzr,#0x6.
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

/** @ghidraAddress 0x1aaff8 */
- (BOOL)shouldAutorotate {
    return YES;
}

/** @ghidraAddress 0x1ab000 */
- (BOOL)prefersStatusBarHidden {
    return YES;
}

@end
