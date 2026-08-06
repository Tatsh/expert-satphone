#import "StoreGenreTableViewController.h"

@implementation StoreGenreTableViewController

/** @ghidraAddress 0x1c4764 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Compiled to the unsigned range test (orientation - 1) < 2, which is what the macro expands
    // to: the two portrait orientations are 1 and 2.
    return UIInterfaceOrientationIsPortrait(interfaceOrientation);
}

/** @ghidraAddress 0x1c4774 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

/** @ghidraAddress 0x1c477c */
- (BOOL)shouldAutorotate {
    return YES;
}

@end
