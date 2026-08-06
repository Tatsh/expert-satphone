#import "RotateStoreProductViewController.h"

@implementation RotateStoreProductViewController

/** @ghidraAddress 0x274c34 */
- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    // Nothing but the super call.
    return [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
}

/** @ghidraAddress 0x274cac */
- (void)viewDidLoad {
    // The whole body. The override adds nothing at all.
    [super viewDidLoad];
}

/** @ghidraAddress 0x274ce8 */
- (void)didReceiveMemoryWarning {
    // Likewise.
    [super didReceiveMemoryWarning];
}

/** @ghidraAddress 0x274d24 */
- (BOOL)shouldAutorotate {
    return YES;
}

/** @ghidraAddress 0x274d2c */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

/** @ghidraAddress 0x274d34 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Unconditional, unlike StoreGenreTableViewController's, which tests for portrait.
    return YES;
}

@end
