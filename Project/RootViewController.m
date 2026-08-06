#import "RootViewController.h"

#import "AudioManager.h"
#import "CJSONSerializer.h"
#import "Downloader.h"
#import "EditorIDManager.h"
#import "ImageCache.h"
#import "JubeatAppDelegate.h"
#import "LogoViewController.h"
#import "MusicSelectViewController.h"
#import "ScratchUtil.h"
#import "TitleViewControllerOrg.h"
#import "TitleViewControllerRpl.h"

// The ivars reached so far. None has an accessor pair anywhere in the binary, so none is a
// property. Offset globals in declaration order: 0x34b770, 0x34b778, 0x34b77c, 0x34b780, 0x34b784,
// 0x34b788, 0x34b78c, 0x34b794.
@interface RootViewController () {
    UIViewController *titleViewCtrl;
    UIViewController *gameViewCtrl;
    UIViewController *editViewCtrl;
    NSString *suspendedAnimID;
    double durationIn;
    double durationOut;
    UIView *fadeView;
    LogoViewController *logoViewCtrl;
    NSString *currentSceneID;
    MusicSelectViewController *musicSelectViewCtrl;
    BOOL _isActive;
}
@end

// The transition names the dispatcher branches on, from the CFStrings at 0x2e0020 through 0x2e0180.
static NSString *const kTitleAnimationName = @"AnimTitle";
static NSString *const kSelectAnimationName = @"AnimSelect";
static NSString *const kStartGameAnimationName = @"AnimStartGame";
static NSString *const kGameRestartAnimationName = @"AnimGameRestart";
static NSString *const kGameReplayAnimationName = @"AnimGameReplay";
static NSString *const kReturnMusicSelectAnimationName = @"AnimReturnMusicSelect";
static NSString *const kStartEditAnimationName = @"AnimStartEdit";
static NSString *const kEndEditAnimationName = @"AnimEndEdit";

// The animation names, from the CFStrings at 0x2e00a0 and 0x2e00c0.
static NSString *const kChangeThemeAnimationName = @"AnimChangeTheme";
static NSString *const kTitleSwitchAnimationName = @"AnimTitleSwitch";

// The two scene identifiers reached so far, from the CFStrings at 0x2e0000 and 0x2e0080. The string
// pool around them also holds "SceneStore", "AnimTitle", and "AnimSelect", so the scene vocabulary
// is wider than the two names this file needs.
static NSString *const kLogoSceneID = @"SceneLogo";
static NSString *const kSelectSceneID = @"SceneSelect";

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
- (void)startAnimation;
- (void)loadResources;
- (void)releaseResources;
- (void)terminate;
- (void)restartGame;
- (void)replayGame;
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

@end
