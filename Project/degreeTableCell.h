/**
 * @file
 * @brief A row of the editor's degree list.
 *
 * Reconstructed from Ghidra program Jubeat (class degreeTableCell, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: complete. The runtime metadata declares two methods for this class and both
 * are implemented.
 *
 * The lower-case class name is the binary's own, shared with @c accessoryTableCell and
 * @c frameTableCell. The three have the same two-selector shape and the same four ivar names, but
 * they are separate classes with no common base and their bodies differ, so each is reconstructed
 * on its own.
 *
 * The superclass was read from the class object's superclass slot at 0x34f0b0, which binds to
 * @c _OBJC_CLASS_$_UITableViewCell at load time rather than being stored in the file.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A cell showing a degree's name, unlock cost, and a lock overlay.
 */
@interface degreeTableCell : UITableViewCell

/**
 * @brief Builds the row's subviews, laid out against the table's width.
 *
 * The same four subviews as @c accessoryTableCell, built in the same order, but with a wider item
 * label that starts further left — this list has no per-row artwork to leave room for.
 *
 * @param width The table's width in points.
 * @ghidraAddress 0x123770
 */
- (instancetype)initWithWidth:(int)width;
/**
 * @brief Fills the row in from a four-element array.
 *
 * Unlike @c accessoryTableCell, element 2 is a **format string** and element 1 is its argument, so
 * the data controls how the name is rendered. Nothing is loaded into @c icon, which stays empty for
 * the whole life of the cell.
 *
 * @param info The row's fields, in order.
 * @ghidraAddress 0x123b74
 */
- (void)setInfo:(NSArray *)info;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
