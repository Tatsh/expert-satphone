#import "RootViewController.h"

#import "JubeatAppDelegate.h"
#import "LogoViewController.h"

// The three ivars, at offset globals 0x34b784, 0x34b788, and 0x34b78c. None of them has an accessor
// pair anywhere in the binary, so none is a property.
@interface RootViewController () {
    LogoViewController *logoViewCtrl;
    NSString *currentSceneID;
    UIViewController *musicSelectViewCtrl;
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

// The theme-change fade timings. The 0.6 is the pooled double at 0x28f230, whose bit pattern
// 0x3FE3333340000000 is 0.6f widened rather than the closest double to 0.6.
static const double kChangeThemeFadeInDuration = 0.6f;
static const double kChangeThemeFadeOutDuration = 1.0;

// Both title-switch durations are the same immediate, an fmov of 0x3FF8000000000000.
static const double kTitleSwitchFadeDuration = 1.5;

// The two selectors this class forwards to the music-select controller. Its concrete class is not
// established, so they are declared on UIViewController; see TYPES_PENDING.md.
@interface UIViewController (JubeatMusicSelect)
- (void)reloadMarkerSelectView;
- (void)pushNotificate;
@end

@implementation RootViewController

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

- (void)changeTitleTheme {
    [self fade:kTitleSwitchAnimationName
         durationIn:kTitleSwitchFadeDuration
        durationOut:kTitleSwitchFadeDuration];
}

- (void)reloadMarkers {
    // No nil guard; a nil controller makes this a no-op.
    [musicSelectViewCtrl reloadMarkerSelectView];
}

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

@end
