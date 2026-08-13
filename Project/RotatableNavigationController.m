#import "RotatableNavigationController.h"

@implementation RotatableNavigationController

#ifdef ENABLE_PATCHES
- (void)patchApplyOpaqueBarAppearance {
    // Preservation patch, not in the binary, and deliberately opt-in rather than an automatic
    // -viewDidLoad override: SettingsNavController and JcfManageNavController derive from this
    // class and style their own bars black, and MusicSelectViewController builds its playlist bar
    // from it directly, so a blanket override would restyle four screens to fix one.
    //
    // -[StoreViewController init] (0x89460) only ever says -setTranslucent:NO on its bars (0x8956c,
    // 0x89600, 0x89690, 0x89724). It sets no bar style, no bar tint and no background image, and
    // the binary contains no UIAppearance proxy at all, so the store deliberately took UIKit's
    // stock opaque bar. iOS 15 made every navigation bar consult scrollEdgeAppearance and derive a
    // transparent background when it is nil, while the legacy translucent flag feeds only
    // standardAppearance. The bar therefore paints nothing and the black window set in
    // -[JubeatAppDelegate application:didFinishLaunchingWithOptions:] shows through. This restates
    // "stock opaque bar" in the modern spelling; no colour is pinned, because the patched build
    // already forces the light appearance and UIKit's own light chrome is the recovered value.
    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance *opaque = [[UINavigationBarAppearance alloc] init];
        [opaque configureWithOpaqueBackground];
        self.navigationBar.standardAppearance = opaque;
        self.navigationBar.compactAppearance = opaque;
        self.navigationBar.scrollEdgeAppearance = opaque;
        if (@available(iOS 15.0, *)) {
            self.navigationBar.compactScrollEdgeAppearance = opaque;
        }
    }
}
#endif

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
