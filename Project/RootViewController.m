#import "RootViewController.h"

#import "JubeatAppDelegate.h"

// The animation names, from the CFStrings at 0x2e00a0 and 0x2e00c0.
static NSString *const kChangeThemeAnimationName = @"AnimChangeTheme";
static NSString *const kTitleSwitchAnimationName = @"AnimTitleSwitch";

// The theme-change fade timings. The 0.6 is the pooled double at 0x28f230, whose bit pattern
// 0x3FE3333340000000 is 0.6f widened rather than the closest double to 0.6.
static const double kChangeThemeFadeInDuration = 0.6f;
static const double kChangeThemeFadeOutDuration = 1.0;

// Both title-switch durations are the same immediate, an fmov of 0x3FF8000000000000.
static const double kTitleSwitchFadeDuration = 1.5;

// The selector -reloadMarkers forwards to, on the music-select controller.
@interface UIViewController (JubeatMarkerSelect)
- (void)reloadMarkerSelectView;
@end

@implementation RootViewController

- (void)changeThemeAndGoTitle {
    if (JubeatAppDelegate.appDelegate.isPad) {
        // Dismisses with no completion, then fades straight away.
        [self.musicSelectViewCtrl dismissViewControllerAnimated:YES completion:nil];
        [self fade:kChangeThemeAnimationName
              durationIn:kChangeThemeFadeInDuration
             durationOut:kChangeThemeFadeOutDuration];
        return;
    }
    [self.musicSelectViewCtrl dismissViewControllerAnimated:YES
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
    [self.musicSelectViewCtrl reloadMarkerSelectView];
}

@end
