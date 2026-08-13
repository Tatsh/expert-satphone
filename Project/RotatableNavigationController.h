/** @file
 * A navigation controller that delegates its rotation policy to the top view controller.
 *
 * Reconstructed from Ghidra program Jubeat (class RotatableNavigationController, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UINavigationController, taken from the dyld bind at the class object's
 * superclass slot (0x350758). The class object was located by scanning for its name string rather
 * than from a super call, since none of its four methods makes one.
 *
 * @c UINavigationController answers rotation questions itself and does not consult its children.
 * This subclass exists solely to reverse that, so a pushed controller can decide.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Forwards every rotation decision to @c topViewController.
 *
 * The class declares no ivars and no properties; all four members are overrides.
 */
@interface RotatableNavigationController : UINavigationController

#ifdef ENABLE_PATCHES
/**
 * @brief Restates the stock opaque navigation bar in the modern appearance API.
 *
 * Not present in the binary. The store's bars are configured with nothing but
 * @c -setTranslucent:NO , which since iOS 15 leaves @c scrollEdgeAppearance nil and so makes the
 * bar transparent, showing the window's black background. Callers opt in; the setting sheet and
 * the jubeat Lab manage sheet style their own bars and must not receive this.
 */
- (void)patchApplyOpaqueBarAppearance;
#endif

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
