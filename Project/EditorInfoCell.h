/** @file
 * A row of the editor's user list.
 *
 * Reconstructed from Ghidra program Jubeat (class EditorInfoCell, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: complete. The runtime metadata declares two methods beyond the property
 * accessor and both are implemented.
 *
 * The superclass was read from the class object's superclass slot at 0x3514a0, which binds to
 * @c _OBJC_CLASS_$_UITableViewCell at load time rather than being stored in the file.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A user row carrying a badge for the user's kind and a lock overlay.
 */
@interface EditorInfoCell : UITableViewCell

/**
 * @brief The lock overlay, pinned near the row's right edge.
 *
 * Positioned from the cell's own frame at construction, so it depends on the cell already having
 * its final width by then.
 */
@property(nonatomic, strong, nullable) UIImageView *lockView;

/**
 * @brief Builds the row, its lock overlay, and a blank badge.
 * @return The initialised cell.
 * @ghidraAddress 0x1f89f0
 */
- (instancetype)init;
/**
 * @brief Swaps the badge for the one matching a user kind.
 *
 * Selects from a three-entry table: blank, staff, artist. Any tag above 2 falls back to the blank
 * badge — but the fallback is one-sided, so a negative tag indexes off the front of the table.
 *
 * @param userTag The user kind: 0 blank, 1 staff, 2 artist.
 * @ghidraAddress 0x1f8bec
 */
- (void)setUserTag:(int)userTag;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
