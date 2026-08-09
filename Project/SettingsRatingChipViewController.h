/** @file
 * The settings-screen rating-chip picker.
 *
 * Reconstructed from Ghidra program Jubeat (class SettingsRatingChipViewController, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base. It is a
 * @c UITableViewController presenting the three rating-chip styles — none, played, and all — one
 * per row in a single section. Each row shows its style name as a text label over a full-cell
 * background pattern image, and the currently-selected style carries a checkmark. Selecting a row
 * persists the choice under the @c PrefRatingChipType user-defaults key and notifies the weak
 * @c settingsDelegate so it can refresh the on-screen rating chip.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Notified when the player picks a new rating-chip style.
 */
@protocol SettingsRatingChipViewControllerDelegate <NSObject>

@optional

/**
 * @brief Asks the delegate to refresh the rating chip after the picked style changed.
 *
 * Invoked through @c -performSelector: only when the delegate responds to it.
 */
- (void)refreshRatingChip;

@end

/**
 * @brief A view controller letting the player pick the rating-chip style in the settings screen.
 */
@interface SettingsRatingChipViewController : UITableViewController

/**
 * @brief The object refreshed when the picked rating-chip style changes.
 *
 * Held weakly and backed by @c _settingsDelegate.
 * @ghidraAddress 0x973bc (getter)
 * @ghidraAddress 0x973dc (setter)
 */
@property(nonatomic, weak, nullable) id<SettingsRatingChipViewControllerDelegate> settingsDelegate;

/**
 * @brief Maps a rating-chip type index to its style name string.
 * @param type The rating-chip type (0 none, 1 played, 2 all); any other value yields the empty
 *        string.
 * @return The style name, or the empty string when @p type is out of range.
 * @ghidraAddress 0x966cc
 */
+ (nonnull NSString *)ratingChipType:(NSUInteger)type;

/**
 * @brief Sets the navigation title to "RATING CHIP" and seeds the selection from the persisted
 *        rating-chip type.
 * @param style The table-view style handed to @c UITableViewController.
 * @return The initialised controller.
 * @ghidraAddress 0x9673c
 */
- (nullable instancetype)initWithStyle:(UITableViewStyle)style;

/**
 * @brief Loads the table view, setting its row height per idiom and hiding the separators.
 * @ghidraAddress 0x96820
 */
- (void)loadView;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
