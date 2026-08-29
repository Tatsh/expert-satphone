/**
 * @file
 * A row of the editor's accessory list.
 *
 * Reconstructed from Ghidra program Jubeat (class accessoryTableCell, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: complete. The runtime metadata declares two methods for this class and both
 * are implemented.
 *
 * The lower-case class name is the binary's own and is kept, as are the ivar names. Two sibling
 * classes, @c degreeTableCell and @c frameTableCell, share the same lower-case naming and the same
 * two-selector shape.
 *
 * The superclass was read from the class object's superclass slot at 0x34e750, which binds to
 * @c _OBJC_CLASS_$_UITableViewCell at load time rather than being stored in the file.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A cell showing an accessory's icon, name, unlock cost, and a lock overlay.
 *
 * It has no properties: the four subviews are plain ivars, declared in the implementation.
 */
@interface accessoryTableCell : UITableViewCell

/**
 * Builds the row's subviews, laid out against the table's width.
 *
 * The width is not stored; it is only used to place the three right-hand subviews, so the layout is
 * fixed at construction and does not follow a later resize.
 *
 * @param width The table's width in points.
 * @ghidraAddress 0xe2dac
 */
- (instancetype)initWithWidth:(int)width;
/**
 * Fills the row in from a four-element array.
 *
 * The array is positional, and only three of its four elements are read: element 1 is the name,
 * element 2 the icon's base file name, and element 3 the cost. Element 0 is never touched.
 *
 * @param info The row's fields, in order.
 * @ghidraAddress 0xe31b4
 */
- (void)setInfo:(NSArray *)info;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
