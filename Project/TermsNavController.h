/**
 * @file
 * @brief The navigation wrapper around the in-app terms-of-service screen, with a close button.
 *
 * Reconstructed from Ghidra program Jubeat (class TermsNavController, image base 0x100000000).
 * All @c \@ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UINavigationController, from the dyld bind at the class object's superclass
 * slot (0x348f10). This class is the near-identical sibling of @c SettingsNavController; it hosts a
 * @c TermsViewController rather than a @c SettingsViewController, and its @c -settingClose is a
 * no-op.
 */

#import <UIKit/UIKit.h>

// The close delegate is the same untyped (@) slot sending the same selector as
// SettingsNavController, so the shared SettingsNavControllerDelegate protocol is reused.
#import "SettingsNavController.h"

@class TermsViewController;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Presents the terms-of-service screen inside a navigation controller with a close button.
 */
@interface TermsNavController : UINavigationController

/**
 * @brief The hosted terms view controller, built in @c -init .
 */
@property(strong, nonatomic, nullable) TermsViewController *termsViewCtrl;

/**
 * @brief The owner notified when the screen closes, and forwarded to the hosted controller.
 */
@property(weak, nonatomic, nullable) id<SettingsNavControllerDelegate> settingsDelegate;

/**
 * @brief Builds the controller, its terms view controller, and the close button.
 * @return The initialised controller.
 * @ghidraAddress 0x9d1a4
 */
- (instancetype)init;

/**
 * @brief Paints the view's background before it is shown.
 * @ghidraAddress 0x9d58c
 */
- (void)loadView;

/**
 * @brief Persists user defaults and tells the delegate the screen closed.
 * @param sender The control that closed the screen. Unused.
 * @ghidraAddress 0x9d63c
 */
- (void)pushClose:(nullable id)sender;

/**
 * @brief A no-op in this class; the binary's body is empty.
 * @ghidraAddress 0x9d728
 */
- (void)settingClose;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
