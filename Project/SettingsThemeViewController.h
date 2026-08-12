/** @file
 * The settings-screen theme picker.
 *
 * Reconstructed from Ghidra program Jubeat (class SettingsThemeViewController, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base. It is a grouped
 * @c UITableViewController presenting the three shipped themes — Original, Ripples, and
 * Knit — one per row in a single section. Each row shows its theme as a full-cell background
 * pattern image rather than a text label, and the currently-selected theme carries a checkmark. A
 * "Change Theme" bar-button item on the navigation bar commits the choice through
 * @c -[JubeatAppDelegate changeTheme:]; it is disabled until the selection differs from the theme
 * in effect.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A view controller letting the player pick the game theme in the settings screen.
 */
@interface SettingsThemeViewController : UITableViewController

/**
 * @brief The navigation-bar button that commits the picked theme.
 *
 * Backed by @c _changeBarBtn. Created in @c -initWithStyle:, wired to
 * @c -buttonCommitChange:, and left disabled until the player selects a theme other than the one
 * currently in effect.
 * @ghidraAddress 0x1449c4 (getter)
 * @ghidraAddress 0x1449d4 (setter)
 */
@property(nonatomic, strong, nullable) UIBarButtonItem *changeBarBtn;

/**
 * @brief Sets the navigation title to "THEME", builds the "Change Theme" commit button disabled,
 *        and seeds the selection from the theme currently in effect.
 * @param style The table-view style handed to @c UITableViewController.
 * @return The initialised controller.
 * @ghidraAddress 0x144198
 */
- (instancetype)initWithStyle:(UITableViewStyle)style;

/**
 * @brief Commits the picked theme by handing it to @c -[JubeatAppDelegate changeTheme:].
 * @param sender The bar-button item that fired the action.
 * @ghidraAddress 0x1443b4
 */
- (void)buttonCommitChange:(nullable id)sender;

/**
 * @brief Loads the table view and sets its row height to 42 points.
 * @ghidraAddress 0x14440c
 */
- (void)loadView;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
