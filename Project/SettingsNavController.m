#import "SettingsNavController.h"

#import <objc/runtime.h>

#import "JubeatAppDelegate.h"
#import "SettingsViewController.h"
#import "neDebugLog.h"

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
    if (NE_DBG_FIRST(4)) {
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
    if (NE_DBG_FIRST(4)) {
        CGRect didRect = self.view.frame;
        neDebugLog("settingsNav didAppear: frame %.1f,%.1f %.1fx%.1f super %s window %s alpha %.2f",
                   didRect.origin.x,
                   didRect.origin.y,
                   didRect.size.width,
                   didRect.size.height,
                   self.view.superview ? object_getClassName(self.view.superview) : "nil",
                   self.view.window ? "yes" : "no",
                   self.view.alpha);
    }
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
