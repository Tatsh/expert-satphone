#import "RotatableNavigationController.h"

@implementation RotatableNavigationController

/** @ghidraAddress 0x1bdde0 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return [self.topViewController shouldAutorotateToInterfaceOrientation:interfaceOrientation];
}

/** @ghidraAddress 0x1bde34 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return self.topViewController.supportedInterfaceOrientations;
}

/** @ghidraAddress 0x1bde80 */
- (BOOL)shouldAutorotate {
    return self.topViewController.shouldAutorotate;
}

/** @ghidraAddress 0x1bdecc */
- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    // The only one of the four that guards. Every UIViewController answers this selector, so the
    // test can only fail when there is no top controller at all — in which case the message would
    // have gone to nil and returned zero, which is not a valid orientation. The fall-back below is
    // what makes that case sane, and it is the reason this override is not shaped like its three
    // siblings.
    if ([self.topViewController
            respondsToSelector:@selector(preferredInterfaceOrientationForPresentation)]) {
        return self.topViewController.preferredInterfaceOrientationForPresentation;
    }
    return UIApplication.sharedApplication.statusBarOrientation;
}

@end
