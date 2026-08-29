/**
 * @file
 * @brief One row of the challenge present list.
 *
 * Reconstructed from Ghidra program Jubeat (class ChallengePresentListViewCell, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UITableViewCell, taken from the dyld bind at the class object's superclass
 * slot (0x351590) rather than from the name.
 *
 * Structurally identical to @c ChallengeListViewCell: same ivars, same properties, same two
 * selectors. It differs in being three lines tall and in getting its label's width arithmetic
 * right — see the note in the implementation.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A three-line present row: a background plate and a wrapping label.
 */
@interface ChallengePresentListViewCell : UITableViewCell

/**
 * @brief Weak and untyped, per the @c W attribute and bare @c \@ encoding in the metadata.
 *
 * Neither method this class defines reads or writes it.
 * @ghidraAddress 0x1fc4a0 (getter)
 */
@property(nonatomic, weak) id aDelegate;

/**
 * @brief Declared readonly and never assigned by any method this class defines, so always nil.
 * @ghidraAddress 0x1fc4d4 (getter)
 */
@property(nonatomic, readonly, nullable) UIButton *addBtn;

/**
 * @brief Builds the plate and the three-line label at the metrics for the current idiom.
 * @param style The cell style.
 * @param reuseIdentifier The reuse identifier, or nil for a non-reusable cell.
 * @return The initialised cell.
 * @ghidraAddress 0x1fc1cc
 */
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(nullable NSString *)reuseIdentifier;

/**
 * @brief Fills the row in.
 * @param bgImg The plate drawn behind the row.
 * @param text The row's text, wrapped over up to three lines.
 * @ghidraAddress 0x1fc40c
 */
- (void)setBgImage:(nullable UIImage *)bgImg text:(nullable NSString *)text;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
