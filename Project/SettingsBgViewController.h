/** @file
 * The settings-screen in-game background-colour picker.
 *
 * Reconstructed from Ghidra program Jubeat (class SettingsBgViewController, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base. It is a
 * @c UITableViewController presenting the four background-colour choices — one per row in a single
 * section — as text labels over a full-cell background pattern image, with the currently-selected
 * colour carrying a checkmark. The colour names, the persisted user-defaults key, and the pattern
 * image names all vary by the theme in effect: the REFLEC BEAT plus theme uses the "ripples" set
 * and the @c PrefColorRipples key, while the Knit theme uses the "knit" set and the
 * @c PrefColorKnit key. The Original theme shows the rows without labels or backgrounds. Selecting
 * a row persists the choice under the theme's key.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A view controller letting the player pick the in-game background colour in the settings
 *        screen.
 */
@interface SettingsBgViewController : UITableViewController

/**
 * @brief Maps a background-colour index to its display name in the REFLEC BEAT plus (ripples)
 *        theme.
 * @param index The colour index (0 green, 1 blue, 2 lemon, 3 dark); any other value yields the
 *        empty string.
 * @return The colour name, or the empty string when @p index is out of range.
 * @ghidraAddress 0x1524b0
 */
+ (nonnull NSString *)ripplesColorName:(NSUInteger)index;

/**
 * @brief Maps a background-colour index to its display name in the Knit theme.
 * @param index The colour index (0 blue, 1 green, 2 lemon, 3 dark); any other value yields the
 *        empty string.
 * @return The colour name, or the empty string when @p index is out of range.
 * @ghidraAddress 0x152520
 */
+ (nonnull NSString *)knitColorName:(NSUInteger)index;

/**
 * @brief Sets the navigation title to "BG COLOR" and seeds the selection from the persisted colour
 *        index for the theme in effect.
 * @param style The table-view style handed to @c UITableViewController.
 * @return The initialised controller.
 * @ghidraAddress 0x152590
 */
- (nullable instancetype)initWithStyle:(UITableViewStyle)style;

/**
 * @brief Loads the table view, setting its row height to 42 points and hiding the separators.
 * @ghidraAddress 0x152710
 */
- (void)loadView;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
