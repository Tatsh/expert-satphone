#import "SettingsNavController.h"

#import "JubeatAppDelegate.h"

// SettingsViewController is not yet reconstructed; declare the two selectors this class sends to
// it.
@interface SettingsViewController : UITableViewController
- (void)settingClose;
- (void)setSettingsDelegate:(id)settingsDelegate;
@end

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
        // Preservation patch, not in the binary. Tapping SETTINGS presents this controller and the
        // presentation succeeds -- the instrumentation in -tapSettings: reports
        // presentedViewController set and the presenting view in a window -- but nothing is drawn,
        // and UIKit warns that the settings table was laid out "without being in the view
        // hierarchy". The form-sheet container is what fails to come up; a full-screen
        // presentation uses the simpler path and does not depend on it. The sheet was already
        // full-width in spirit on the original 768x1024 iPad.
        self.modalPresentationStyle = UIModalPresentationFullScreen;
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
    // Persisted with no value written first, then told to flush.
    [NSUserDefaults.standardUserDefaults synchronize];

    // The delegate is loaded from the weak slot twice, once to test and once to send to.
    if ([self.settingsDelegate respondsToSelector:@selector(settingsNavViewClose:)]) {
        [self.settingsDelegate performSelector:@selector(settingsNavViewClose:) withObject:self];
    }
}

/** @ghidraAddress 0xe4930 */
- (void)settingClose {
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
}

/** @ghidraAddress 0xe4bf4 */
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

/** @ghidraAddress 0xe4c2c */
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

/** @ghidraAddress 0xe4c64 */
- (void)setSettingsDelegate:(id<SettingsNavControllerDelegate>)settingsDelegate {
    _settingsDelegate = settingsDelegate;
    // The same delegate is pushed down to the hosted controller once it exists.
    if (self.settingsViewCtrl) {
        [self.settingsViewCtrl setSettingsDelegate:settingsDelegate];
    }
}

@end
