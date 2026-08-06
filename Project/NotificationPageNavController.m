#import "NotificationPageNavController.h"

#import "JubeatAppDelegate.h"
#import "NotificationPageViewController.h"

// Where the last-seen notification time is remembered, so the page is not shown again.
static NSString *const kInfoUpdateTimeKey = @"PrefInfoUpdateTime";

// The sequence index the delegate is handed. Always this literal.
static NSString *const kNoSequence = @"none";

@implementation NotificationPageNavController {
    NotificationPageViewController *pageViewController;
    UIWebView *notificationPage;
    // Weak, from the objc_loadWeakRetained in -pushClose:; the ivar's own encoding is a bare @ and
    // says nothing about it.
    __weak id delegate;
}

// The navigation bar's two greys. On iOS 7 the first tints the bar and the second its controls; on
// anything older the first tints the controls and the second is not used.
static const CGFloat kBarGrey = 0.6f;     // @ghidraAddress 0x28f230
static const CGFloat kBarTintGrey = 0.9f; // @ghidraAddress 0x28f448

/** @ghidraAddress 0x182b8c */
- (instancetype)init:(id)arg {
    self = [super init];
    if (self) {
        self.modalPresentationStyle = UIModalPresentationFormSheet;
        self.navigationBar.barStyle = UIBarStyleBlack;
        self.navigationBar.translucent = NO;

        // Two iOS 7 properties, reached by selector so the class still builds against an older SDK.
        if ([self respondsToSelector:@selector(setExtendedLayoutIncludesOpaqueBars:)]) {
            [self performSelector:@selector(setExtendedLayoutIncludesOpaqueBars:) withObject:nil];
        }
        if ([self respondsToSelector:@selector(setAutomaticallyAdjustsScrollViewInsets:)]) {
            // Yes, self. The setter wants a BOOL and receives an object pointer — see
            // TYPES_PENDING.md.
            [self performSelector:@selector(setAutomaticallyAdjustsScrollViewInsets:)
                       withObject:self];
        }

        // Built once and used by whichever arm runs.
        UIColor *barGrey = [UIColor colorWithWhite:kBarGrey alpha:1.0];
        if ([self.navigationBar respondsToSelector:@selector(setBarTintColor:)]) {
            [self.navigationBar performSelector:@selector(setBarTintColor:) withObject:barGrey];
            self.navigationBar.tintColor = [UIColor colorWithWhite:kBarTintGrey alpha:1.0];
        } else {
            // Without a bar tint the same grey goes on the controls instead.
            self.navigationBar.tintColor = barGrey;
        }

        pageViewController = [[NotificationPageViewController alloc] init:arg];

        UIBarButtonItem *closeItem =
            [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Close", nil)
                                             style:UIBarButtonItemStyleDone
                                            target:self
                                            action:@selector(pushClose:)];
        // The button goes on the child's navigation item, not this controller's.
        pageViewController.navigationItem.leftBarButtonItem = closeItem;

        self.viewControllers = @[ pageViewController ];

        // The same object is both the page's argument and this controller's weak delegate.
        delegate = arg;
    }
    return self;
}

/** @ghidraAddress 0x182fcc */
- (void)pushClose:(id)sender {
    // The read mark is whatever the app delegate is holding, written straight to defaults with no
    // -synchronize afterwards.
    [NSUserDefaults.standardUserDefaults setValue:JubeatAppDelegate.appDelegate.notificationTime
                                           forKey:kInfoUpdateTimeKey];

    // Two nils clear the pending page, so nothing re-presents it.
    [JubeatAppDelegate.appDelegate setNotificationPageURL:nil updateTime:nil];

    // The delegate is loaded from the weak slot twice, once to test and once to send to.
    if ([delegate respondsToSelector:@selector(customWebViewClose:seqIndex:)]) {
        [delegate performSelector:@selector(customWebViewClose:seqIndex:)
                       withObject:self
                       withObject:kNoSequence];
    }
}

/** @ghidraAddress 0x183124 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return UIInterfaceOrientationIsPortrait(interfaceOrientation);
}

/** @ghidraAddress 0x183134 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

/** @ghidraAddress 0x18313c */
- (BOOL)shouldAutorotate {
    return YES;
}

/** @ghidraAddress 0x183144 */
- (void)dealloc {
    // Empty in the binary too: only the super call, which ARC emits — the class has a
    // .cxx_destruct at 0x18317c.
}

@end
