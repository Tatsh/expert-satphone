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
