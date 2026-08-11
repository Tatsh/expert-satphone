/** @file
 * The inherit-code input view controller — the screen that hosts the inherit-code entry panel.
 *
 * Reconstructed from Ghidra program Jubeat (class InheritCodeInputViewController, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIViewController , from the class object's superclass slot and the
 * @c objc_msgSendSuper2 dispatches into @c UIViewController lifecycle methods.
 *
 * The controller owns a single @c InheritCodeInputView , which it builds in @c -loadView over a
 * dimming overlay and drives as its child, and registers for the app-suspend and app-resume
 * notifications so it can react while backgrounded.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A view controller presenting the inherit-code entry panel.
 */
@interface InheritCodeInputViewController : UIViewController

/**
 * @brief Builds the controller: sets the navigation title and subscribes to the app
 *        suspend and resume notifications.
 * @return The initialised controller.
 * @ghidraAddress 0x219254
 */
- (instancetype)init;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
