/** @file
 * One row of the challenge menu, with a badge showing an unread count.
 *
 * Reconstructed from Ghidra program Jubeat (class ChallengeMenuViewCell, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UITableViewCell, taken from the dyld bind at the class object's superclass
 * slot (0x34cb30) rather than from the name.
 *
 * RECONSTRUCTION STATE: three of four members written. @c -setBgImage:numImage: is declared but
 * not reconstructed; see RECONSTRUCTION_STATUS.md.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A menu row whose badge draws its number from per-digit artwork.
 *
 * The row owns two fixed arrays of image views, one two digits wide and one three, and picks
 * between them by magnitude rather than resizing either.
 */
@interface ChallengeMenuViewCell : UITableViewCell

/**
 * @brief Weak and untyped, per the metadata. Nothing this class defines reads it.
 * @ghidraAddress 0x425e8 (getter)
 */
@property(nonatomic, weak) id aDelegate;

/**
 * @brief Clears the button, goes clear-backed and drops the selection style. Builds no subviews.
 * @ghidraAddress 0x41b74
 */
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(nullable NSString *)reuseIdentifier;

/**
 * @brief Builds the row's button, badge plate and digit views.
 *
 * DECLARED ONLY — the body has not been reconstructed yet.
 *
 * @param bgImg The row's background artwork.
 * @param numImg The digit artwork, indexed 0 to 9.
 * @ghidraAddress 0x41c24
 */
- (void)setBgImage:(nullable UIImage *)bgImg numImage:(nullable NSArray *)numImg;

/**
 * @brief Shows a number on the badge, or hides the badge entirely.
 *
 * Zero hides the plate and returns. One to nine goes in the **middle** slot of the three-wide row
 * rather than in the two-wide one. Ten to ninety-nine uses the two-wide row, and anything larger
 * uses the three-wide row. Values above 999 are clamped to 999 rather than rejected.
 *
 * @param number The count to show.
 * @ghidraAddress 0x42314
 */
- (void)setNumber:(int)number;

/**
 * @brief The row button's action. Does nothing at all — the body is a single return.
 * @param sender The tapped button. Unused.
 * @ghidraAddress 0x425e4
 */
- (void)tapMenu:(id)sender;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
