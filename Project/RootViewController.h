/** @file
 * The application's root view controller.
 *
 * Reconstructed from Ghidra program Jubeat (class RootViewController, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: a stub grown outwards from its callers. Only the member reached so far is
 * declared.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Hosts the game's screens and owns the music-select controller it presents.
 */
@interface RootViewController : UIViewController

/**
 * @brief Dismisses the music-select screen and returns to the title under the new theme.
 *
 * Branches on @c JubeatAppDelegate.appDelegate.isPad: the iPad arm dismisses without a completion
 * and then runs a fade itself, while the other arm passes a completion block that performs the
 * fade. Only the entry point is declared here; the body is not reconstructed yet.
 * @ghidraAddress 0x1a8a68
 */
- (void)changeThemeAndGoTitle;

/**
 * @brief Refreshes the title screen for the current theme or event.
 *
 * Called from @c -[JubeatAppDelegate switchTitleEvent] at 0x8708, unconditionally on both arms.
 */
- (void)changeTitleTheme;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
