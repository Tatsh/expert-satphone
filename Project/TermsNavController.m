#import "TermsNavController.h"

#import "JubeatAppDelegate.h"
#import "TermsViewController.h"

// The navigation bar's two greys: the first tints the bar background (or, on an older SDK without a
// bar tint, the controls), the second tints the controls.
static const CGFloat kBarBackgroundGrey = 0.6f; // @ghidraAddress 0x28f230
static const CGFloat kBarControlGrey = 0.9f;    // @ghidraAddress 0x28f448

// The white the loaded view's background is painted.
static const CGFloat kViewBackgroundGrey = 0.8f; // @ghidraAddress 0x28e080

// The rounded-corner radius applied to the form sheet on iPad.
static const CGFloat kPadCornerRadius = 6.0f;

@implementation TermsNavController

/** @ghidraAddress 0x9d1a4 */
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

        self.termsViewCtrl = [[TermsViewController alloc] initWithStyle:UITableViewStyleGrouped];

        UIBarButtonItem *closeItem =
            [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Close", nil)
                                             style:UIBarButtonItemStyleDone
                                            target:self
                                            action:@selector(pushClose:)];
        // The button goes on the child's navigation item, not this controller's.
        self.termsViewCtrl.navigationItem.leftBarButtonItem = closeItem;

        self.viewControllers = @[ self.termsViewCtrl ];
    }
    return self;
}

/** @ghidraAddress 0x9d58c */
- (void)loadView {
    [super loadView];
    self.view.backgroundColor = [UIColor colorWithWhite:kViewBackgroundGrey alpha:1.0];
}

/** @ghidraAddress 0x9d63c */
- (void)pushClose:(id)sender {
    // Persisted with no value written first, then told to flush.
    [NSUserDefaults.standardUserDefaults synchronize];

    // The delegate is loaded from the weak slot twice, once to test and once to send to.
    if ([self.settingsDelegate respondsToSelector:@selector(settingsNavViewClose:)]) {
        [self.settingsDelegate performSelector:@selector(settingsNavViewClose:) withObject:self];
    }
}

/** @ghidraAddress 0x9d728 */
- (void)settingClose {
    // The binary's body is empty; unlike SettingsNavController this does not forward to the child.
}

/** @ghidraAddress 0x9d72c */
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

/** @ghidraAddress 0x9d764 */
- (void)viewDidLoad {
    [super viewDidLoad];
}

/** @ghidraAddress 0x9d79c */
- (void)viewDidUnload {
    [super viewDidUnload];
}

/** @ghidraAddress 0x9d7d4 */
- (BOOL)disablesAutomaticKeyboardDismissal {
    return NO;
}

/** @ghidraAddress 0x9d7dc */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // On iPad the form sheet is given rounded corners, both on its superview and on its own view.
    if (JubeatAppDelegate.appDelegate.isPad) {
        self.view.superview.layer.cornerRadius = kPadCornerRadius;
        self.view.layer.cornerRadius = kPadCornerRadius;
        self.view.clipsToBounds = YES;
    }
}

/** @ghidraAddress 0x9d978 */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

/** @ghidraAddress 0x9d9b0 */
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

/** @ghidraAddress 0x9d9e8 */
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

/** @ghidraAddress 0x9da20 */
- (void)setSettingsDelegate:(id<SettingsNavControllerDelegate>)settingsDelegate {
    _settingsDelegate = settingsDelegate;
    // The same delegate is pushed down to the hosted controller once it exists.
    if (self.termsViewCtrl) {
        [self.termsViewCtrl setSettingsDelegate:settingsDelegate];
    }
}

@end
