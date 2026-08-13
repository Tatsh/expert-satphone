#import "RotatableNavigationController.h"

#import <objc/runtime.h>

#import "neDebugLog.h"

// Diagnostic rate limits for the three orientation answers below. The first burst is logged in
// full, then only a changed answer, and past that only a periodic count: a storm of queries here is
// itself the finding, so what is bounded is the rate rather than the total.
static const unsigned int kOrientationLogBurst = 40;
static const unsigned int kOrientationLogInterval = 2000;

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
    UIInterfaceOrientationMask supported = self.topViewController.supportedInterfaceOrientations;
    if (NE_DBG_EVERY) {
        // A nil top controller answers 0 here, which is not a mask UIKit can honour, and an answer
        // that changes between two queries is what makes the window scene revise its orientation
        // preferences. Either would drive the lay-out-and-ask-again loop seen in a capture, so
        // record every distinct answer and who gave it.
        static unsigned int calls = 0;
        static UIInterfaceOrientationMask previous = 0;
        ++calls;
        if (calls <= kOrientationLogBurst || supported != previous ||
            (calls % kOrientationLogInterval) == 0) {
            neDebugLog("rotatableNav supported: 0x%lx top %s calls %u",
                       (unsigned long)supported,
                       self.topViewController ? object_getClassName(self.topViewController) : "nil",
                       calls);
        }
        previous = supported;
    }
    return supported;
}

/** @ghidraAddress 0x1bde80 */
- (BOOL)shouldAutorotate {
    BOOL autorotate = self.topViewController.shouldAutorotate;
    if (NE_DBG_EVERY) {
        // A nil top controller answers NO, which pins the scene to its current orientation, and
        // alternating NO and YES is exactly what would flip the scene's preferences back and forth.
        static unsigned int calls = 0;
        static BOOL previous = NO;
        ++calls;
        if (calls <= kOrientationLogBurst || autorotate != previous ||
            (calls % kOrientationLogInterval) == 0) {
            neDebugLog("rotatableNav autorotate: %d top %s calls %u",
                       (int)autorotate,
                       self.topViewController ? object_getClassName(self.topViewController) : "nil",
                       calls);
        }
        previous = autorotate;
    }
    return autorotate;
}

/** @ghidraAddress 0x1bdecc */
- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    // The only one of the four that guards. Every UIViewController answers this selector, so the
    // test can only fail when there is no top controller at all — in which case the message would
    // have gone to nil and returned zero, which is not a valid orientation. The fall-back below is
    // what makes that case sane, and it is the reason this override is not shaped like its three
    // siblings.
    UIInterfaceOrientation preferred;
    if ([self.topViewController
            respondsToSelector:@selector(preferredInterfaceOrientationForPresentation)]) {
        preferred = self.topViewController.preferredInterfaceOrientationForPresentation;
    } else {
        preferred = UIApplication.sharedApplication.statusBarOrientation;
    }
    if (NE_DBG_EVERY) {
        static unsigned int calls = 0;
        static UIInterfaceOrientation previous = UIInterfaceOrientationUnknown;
        ++calls;
        if (calls <= kOrientationLogBurst || preferred != previous ||
            (calls % kOrientationLogInterval) == 0) {
            neDebugLog("rotatableNav preferred: %ld top %s calls %u",
                       (long)preferred,
                       self.topViewController ? object_getClassName(self.topViewController) : "nil",
                       calls);
        }
        previous = preferred;
    }
    return preferred;
}

@end
