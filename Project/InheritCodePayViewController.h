/** @file
 * The inherit-code payment view controller — the screen that hosts the inherit-code issue panel.
 *
 * Reconstructed from Ghidra program Jubeat (class InheritCodePayViewController, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIViewController , from the class object's superclass slot and the
 * @c objc_msgSendSuper2 dispatches into @c UIViewController lifecycle methods.
 *
 * The controller owns a single @c InheritCodePayView , which it builds in @c -loadView over a
 * dimming overlay and drives as its child, and registers for the app-suspend and app-resume
 * notifications so it can react while backgrounded.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A view controller presenting the inherit-code issue panel.
 */
@interface InheritCodePayViewController : UIViewController

/**
 * @brief Builds the controller: sets the navigation title and subscribes to the app
 *        suspend and resume notifications.
 * @return The initialised controller.
 * @ghidraAddress 0xaeb90
 */
- (nullable instancetype)init;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
