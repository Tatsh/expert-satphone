#import "RootViewController.h"

#import "CJSONSerializer.h"
#import "Downloader.h"
#import "EditorIDManager.h"
#import "JubeatAppDelegate.h"
#import "LogoViewController.h"
#import "ScratchUtil.h"

// The ivars reached so far. None has an accessor pair anywhere in the binary, so none is a
// property. Offset globals in declaration order: 0x34b770, 0x34b778, 0x34b77c, 0x34b780, 0x34b784,
// 0x34b788, 0x34b78c, 0x34b794.
@interface RootViewController () {
    NSString *suspendedAnimID;
    double durationIn;
    double durationOut;
    UIView *fadeView;
    LogoViewController *logoViewCtrl;
    NSString *currentSceneID;
    UIViewController *musicSelectViewCtrl;
    BOOL _isActive;
}
@end

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

// The two selectors this class forwards to the music-select controller. Its concrete class is not
// established, so they are declared on UIViewController; see TYPES_PENDING.md.
@interface UIViewController (JubeatMusicSelect)
// Deliberately unannotated: 0x1aaaa4 is -[RootViewController pushNotificate], not this. The
// music-select controller's own implementation has not been located.
- (void)reloadMarkerSelectView;
- (void)pushNotificate;
@end

@implementation RootViewController

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
