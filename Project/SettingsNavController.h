/**
 * @file
 * The navigation wrapper around the in-app settings screen, with a close button.
 *
 * Reconstructed from Ghidra program Jubeat (class SettingsNavController, image base 0x100000000).
 * All @c \@ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UINavigationController, from the dyld bind at the class object's superclass
 * slot (0x349068).
 */

#import <UIKit/UIKit.h>

#import "RotatableNavigationController.h"

@class SettingsViewController;

NS_ASSUME_NONNULL_BEGIN

/**
 * What a @c SettingsNavController tells its owner.
 *
 * The delegate ivar is untyped in the metadata (encoding @c \@), so the protocol is inferred from
 * the one selector the class sends and the dispatch goes through @c -respondsToSelector: .
 */
@protocol SettingsNavControllerDelegate <NSObject>
@optional
/**
 * Sent when the settings navigation controller is dismissed.
 * @param controller The controller that closed.
 */
- (void)settingsNavViewClose:(id)controller;
@end

/**
 * Presents the settings screen inside a navigation controller with a close button.
 */
@interface SettingsNavController : RotatableNavigationController

/**
 * The hosted settings view controller, built in @c -init .
 */
@property(strong, nonatomic, nullable) SettingsViewController *settingsViewCtrl;

/**
 * The owner notified when the screen closes, and forwarded to the hosted controller.
 */
@property(weak, nonatomic, nullable) id<SettingsNavControllerDelegate> settingsDelegate;

/**
 * Builds the controller, its settings view controller, and the close button.
 * @return The initialised controller.
 * @ghidraAddress 0xe43ac
 */
- (instancetype)init;

/**
 * Paints the view's background before it is shown.
 * @ghidraAddress 0xe4794
 */
- (void)loadView;

/**
 * Persists user defaults and tells the delegate the screen closed.
 * @param sender The control that closed the screen. Unused.
 * @ghidraAddress 0xe4844
 */
- (void)pushClose:(nullable id)sender;

/**
 * Forwards the close request to the hosted settings view controller.
 * @ghidraAddress 0xe4930
 */
- (void)settingClose;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
