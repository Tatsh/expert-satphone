/** @file
 * A store row holding two recommended-pack tiles side by side.
 *
 * Reconstructed from Ghidra program Jubeat (class StoreRecommendTableCell, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UITableViewCell, taken from the dyld bind at the class object's superclass
 * slot (0x34fb50) rather than from the name.
 */

#import <UIKit/UIKit.h>

#import "StoreRecommendPackView.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Two pack tiles filling the row's width, each taking half of it.
 *
 * Both tiles go on the cell's @c contentView rather than on the cell itself, which is the
 * difference between this and the other list rows in this tree.
 */
@interface StoreRecommendTableCell : UITableViewCell

/** @brief The tile occupying the leading half. */
@property(nonatomic, readonly, nullable) StoreRecommendPackView *leftPackView;
/** @brief The tile occupying the trailing half. */
@property(nonatomic, readonly, nullable) StoreRecommendPackView *rightPackView;

/**
 * @brief Builds the row, splitting the supplied frame's width between the two tiles.
 *
 * Chains to @c UITableViewCell's own @c -initWithStyle:reuseIdentifier: with the default style,
 * so only the frame's width is used and its origin and height are discarded.
 *
 * @param frame The row's frame. Only @c size.width is read.
 * @param reuseIdentifier Passed straight through.
 * @return The initialised cell.
 * @ghidraAddress 0x165bf4
 */
- (instancetype)initWithFrame:(CGRect)frame reuseIdentifier:(nullable NSString *)reuseIdentifier;

/**
 * @brief Builds the row at a fixed tile width instead of measuring one.
 *
 * Otherwise identical to the frame-taking initialiser above.
 *
 * @param style Passed straight through to @c UITableViewCell.
 * @param reuseIdentifier Passed straight through.
 * @return The initialised cell.
 * @ghidraAddress 0x165d88
 */
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(nullable NSString *)reuseIdentifier;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
