/** @file
 * One row of the challenge reward list.
 *
 * Reconstructed from Ghidra program Jubeat (class ChallengeRewardListCell, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UITableViewCell, taken from the dyld bind at the class object's superclass
 * slot (0x34dc10) rather than from the name.
 *
 * Unlike the other cells in this tree, the initialiser builds nothing: every subview is created
 * lazily by the two setters, and each is created only once. That makes the call order significant
 * — see @c -setTitle:period: .
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A reward row: a background plate carrying a title and an optional validity period.
 */
@interface ChallengeRewardListCell : UITableViewCell

/**
 * @brief Sets the cell's background colour and selection style. Creates no subviews.
 * @param style The cell style.
 * @param reuseIdentifier The reuse identifier, or nil for a non-reusable cell.
 * @return The initialised cell.
 * @ghidraAddress 0xaa4fc
 */
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(nullable NSString *)reuseIdentifier;

/**
 * @brief Creates the plate on first use and sets its image.
 *
 * The plate is sized to the image and placed at the cell's origin. Must be called before
 * @c -setTitle:period:, which measures against this plate and does nothing without it.
 *
 * @param bgImg The plate artwork.
 * @ghidraAddress 0xaa7e0
 */
- (void)setBgImage:(nullable UIImage *)bgImg;

/**
 * @brief Creates the two labels on first use and fills them in.
 *
 * Returns immediately when @c -setBgImage: has not run, since every coordinate here is derived
 * from the plate's frame. A nil @c period leaves the period label uncreated and centres the title
 * on its own.
 *
 * @param title The reward's name.
 * @param period The validity period, or nil for a reward that has none.
 * @ghidraAddress 0xaa598
 */
- (void)setTitle:(nullable NSString *)title period:(nullable NSString *)period;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
