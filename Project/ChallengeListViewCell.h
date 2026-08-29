/**
 * @file
 * @brief One row of the challenge list.
 *
 * Reconstructed from Ghidra program Jubeat (class ChallengeListViewCell, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UITableViewCell, taken from the dyld bind at the class object's superclass
 * slot (0x3517c0) rather than from the name.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A single-line challenge row: a background plate and a label, both on the cell itself.
 */
@interface ChallengeListViewCell : UITableViewCell

/**
 * @brief Weak and untyped, per the @c W attribute and bare @c \@ encoding in the metadata.
 *
 * Neither method this class defines reads or writes it; it exists only for a caller to set.
 * @ghidraAddress 0x208a88 (getter)
 */
@property(nonatomic, weak) id aDelegate;

/**
 * @brief Declared readonly and never assigned by any method this class defines, so always nil.
 *
 * The same dead property as on @c CubePurchaseListViewCell — no setter exists, and the ivar is
 * private, so nothing can write it.
 * @ghidraAddress 0x208abc (getter)
 */
@property(nonatomic, readonly, nullable) UIButton *addBtn;

/**
 * @brief Builds the plate and the label at the metrics for the current device idiom.
 * @param style The cell style.
 * @param reuseIdentifier The reuse identifier, or nil for a non-reusable cell.
 * @return The initialised cell.
 * @ghidraAddress 0x2087e0
 */
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(nullable NSString *)reuseIdentifier;

/**
 * @brief Fills the row in.
 * @param bgImg The plate drawn behind the row.
 * @param text The row's single line of text.
 * @ghidraAddress 0x2089f4
 */
- (void)setBgImage:(nullable UIImage *)bgImg text:(nullable NSString *)text;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
