#import "SettingsNavController.h"

#import <objc/runtime.h>

#import "JubeatAppDelegate.h"
#import "SettingsViewController.h"
#import "neDebugLog.h"
#import "neUIProbe.h"

#if JBDBG
// Diagnostics only, and declared here rather than in the header so the reconstructed interface
// stays exactly what the binary's metadata describes. The binary sets no navigation delegate at
// all; -navigationController:willShowViewController:animated: and its did- counterpart are pure
// observers, and the pair is what distinguishes a push or pop that never started from one that
// started and never finished.
@interface SettingsNavController () <UINavigationControllerDelegate>
@end
#endif

// The navigation bar's two greys: the first tints the bar background (or, on an older SDK without a
// bar tint, the controls), the second tints the controls.
static const CGFloat kBarBackgroundGrey = 0.6f; // @ghidraAddress 0x28f230
static const CGFloat kBarControlGrey = 0.9f;    // @ghidraAddress 0x28f448

// The white the loaded view's background is painted.
static const CGFloat kViewBackgroundGrey = 0.8f; // @ghidraAddress 0x28e080

// The rounded-corner radius applied to the form sheet on iPad.
static const CGFloat kPadCornerRadius = 6.0f;

@implementation SettingsNavController

/** @ghidraAddress 0xe43ac */
- (instancetype)init {
    self = [super init];
    if (self) {
        self.modalPresentationStyle = UIModalPresentationFormSheet;
#ifdef ENABLE_PATCHES
        // Preservation patch, not in the binary. A form sheet was not interactively dismissible
        // when this shipped, so the binary can assume the only way out is the Close item and its
        // -pushClose: (0xe4844). Since iOS 13 the sheet can be swiped away, which bypasses
        // -pushClose: entirely and so never reaches -[MusicSelectViewController
        // settingsNavViewClose:] -- the sole clear of bOpenSetting (0x2d20c) and the sole re-enable
        // of the select screen's shuffle and swipe recognisers. Refusing the interactive dismissal
        // restores the original behaviour rather than inventing new behaviour.
        if (@available(iOS 13.0, *)) {
            self.modalInPresentation = YES;
        }
#endif
        self.navigationBar.barStyle = UIBarStyleBlack;
        self.navigationBar.translucent = NO;

        // Built once and used by whichever arm runs.
        UIColor *barGrey = [UIColor colorWithWhite:kBarBackgroundGrey alpha:1.0];
        if ([self.navigationBar respondsToSelector:@selector(setBarTintColor:)]) {
            [self.navigationBar performSelector:@selector(setBarTintColor:) withObject:barGrey];
            self.navigationBar.tintColor = [UIColor colorWithWhite:kBarControlGrey alpha:1.0];
        } else {
            // Without a bar tint the same grey goes on the controls instead.
            self.navigationBar.tintColor = barGrey;
        }

        self.settingsViewCtrl =
            [[SettingsViewController alloc] initWithStyle:UITableViewStyleGrouped];

        UIBarButtonItem *closeItem =
            [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Close", nil)
                                             style:UIBarButtonItemStyleDone
                                            target:self
                                            action:@selector(pushClose:)];
        // The button goes on the child's navigation item, not this controller's.
        self.settingsViewCtrl.navigationItem.leftBarButtonItem = closeItem;

        self.viewControllers = @[ self.settingsViewCtrl ];

#if JBDBG
        self.delegate = self;
#endif
    }
    return self;
}

/** @ghidraAddress 0xe4794 */
- (void)loadView {
    [super loadView];
    self.view.backgroundColor = [UIColor colorWithWhite:kViewBackgroundGrey alpha:1.0];
}

/** @ghidraAddress 0xe4844 */
- (void)pushClose:(id)sender {
    if (NE_DBG_EVERY) {
        neUIProbeLogController("pushClose nav", self);
        neDebugLog(
            "settingsNav pushClose: delegate %s responds %d",
            self.settingsDelegate ? "set" : "nil",
            (int)[self.settingsDelegate respondsToSelector:@selector(settingsNavViewClose:)]);
    }
    // Persisted with no value written first, then told to flush.
    [NSUserDefaults.standardUserDefaults synchronize];

    // The delegate is loaded from the weak slot twice, once to test and once to send to.
    if ([self.settingsDelegate respondsToSelector:@selector(settingsNavViewClose:)]) {
        [self.settingsDelegate performSelector:@selector(settingsNavViewClose:) withObject:self];
    }
}

/** @ghidraAddress 0xe4930 */
- (void)settingClose {
    if (NE_DBG_EVERY) {
        neDebugLog("settingsNav settingClose: stack depth %lu top %s",
                   (unsigned long)self.viewControllers.count,
                   self.topViewController ? object_getClassName(self.topViewController) : "nil");
    }
    [self.settingsViewCtrl settingClose];
}

/** @ghidraAddress 0xe4970 */
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

/** @ghidraAddress 0xe49a8 */
- (void)viewDidLoad {
    [super viewDidLoad];
}

/** @ghidraAddress 0xe49e0 */
- (void)viewDidUnload {
    [super viewDidUnload];
}

/** @ghidraAddress 0xe4a18 */
- (BOOL)disablesAutomaticKeyboardDismissal {
    return NO;
}

/** @ghidraAddress 0xe4a20 */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (NE_DBG_EVERY) {
        CGRect willRect = self.view.frame;
        neDebugLog("settingsNav willAppear: animated %d frame %.1f,%.1f %.1fx%.1f super %s "
                   "window %s",
                   (int)animated,
                   willRect.origin.x,
                   willRect.origin.y,
                   willRect.size.width,
                   willRect.size.height,
                   self.view.superview ? object_getClassName(self.view.superview) : "nil",
                   self.view.window ? "yes" : "no");
        neUIProbeLogController("nav willAppear", self);
        // The presentation's own coordinator. Its completion is the same event that drives
        // -viewDidAppear:, so a completion that never runs and a -viewDidAppear: that never runs
        // are one finding, while a completion that runs cancelled is a different one.
        neUIProbeTraceTransition("nav present", self);
    }
    // On iPad the form sheet is given rounded corners, both on its superview and on its own view.
    if (JubeatAppDelegate.appDelegate.isPad) {
        self.view.superview.layer.cornerRadius = kPadCornerRadius;
        self.view.layer.cornerRadius = kPadCornerRadius;
        self.view.clipsToBounds = YES;
    }
}

/** @ghidraAddress 0xe4bbc */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (NE_DBG_EVERY) {
        CGRect didRect = self.view.frame;
        neDebugLog("settingsNav didAppear: frame %.1f,%.1f %.1fx%.1f super %s window %s alpha %.2f",
                   didRect.origin.x,
                   didRect.origin.y,
                   didRect.size.width,
                   didRect.size.height,
                   self.view.superview ? object_getClassName(self.view.superview) : "nil",
                   self.view.window ? "yes" : "no",
                   self.view.alpha);
        neUIProbeLogController("nav didAppear", self);
        neUIProbeLogWindowTree("nav didAppear");
    }
}

/** @ghidraAddress 0xe4bf4 */
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (NE_DBG_EVERY) {
        neUIProbeLogController("nav willDisappear", self);
        neUIProbeTraceTransition("nav dismiss", self);
    }
}

/** @ghidraAddress 0xe4c2c */
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    if (NE_DBG_EVERY) {
        neUIProbeLogController("nav didDisappear", self);
        // The state the next presentation starts from. A sheet that dismissed cleanly leaves no
        // presented controller behind and no view in a window.
        neUIProbeLogWindowTree("nav didDisappear");
    }
}

/** @ghidraAddress 0xe4c64 */
- (void)setSettingsDelegate:(id<SettingsNavControllerDelegate>)settingsDelegate {
    _settingsDelegate = settingsDelegate;
    // The same delegate is pushed down to the hosted controller once it exists.
    if (self.settingsViewCtrl) {
        [self.settingsViewCtrl setSettingsDelegate:settingsDelegate];
    }
}

#if JBDBG

#pragma mark - UINavigationControllerDelegate (diagnostics only)

// Not in the binary. willShow fires as the push or pop begins, didShow only once the transition
// has finished; a willShow with no matching didShow is a transition that started and stalled,
// which is the reported symptom for the back button and cannot be seen any other way.

- (void)navigationController:(UINavigationController *)navigationController
      willShowViewController:(UIViewController *)viewController
                    animated:(BOOL)animated {
    neDebugLog("settingsNav willShow: %s animated %d depth %lu interactive %d",
               object_getClassName(viewController),
               (int)animated,
               (unsigned long)navigationController.viewControllers.count,
               (int)(navigationController.transitionCoordinator.initiallyInteractive));
    neUIProbeTraceTransition("nav push/pop", navigationController);
}

- (void)navigationController:(UINavigationController *)navigationController
       didShowViewController:(UIViewController *)viewController
                    animated:(BOOL)animated {
    neDebugLog("settingsNav didShow: %s animated %d depth %lu",
               object_getClassName(viewController),
               (int)animated,
               (unsigned long)navigationController.viewControllers.count);
    neUIProbeLogWindowTree("nav didShow");
}

#endif

@end
