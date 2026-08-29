/**
 * @file
 * @brief A row of the store's pack grid, holding two pack tiles.
 *
 * Reconstructed from Ghidra program Jubeat (class StoreTableCell, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: complete. The runtime metadata declares two methods beyond the property
 * accessors and both are implemented.
 *
 * The superclass was read from the class object's superclass slot at 0x34f6f0, which binds to
 * @c _OBJC_CLASS_$_UITableViewCell at load time rather than being stored in the file.
 */

#import <UIKit/UIKit.h>

#import "StorePackView.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A table row that lays two pack tiles side by side.
 *
 * The grid is a table rather than a collection view, so each row carries a fixed pair of tiles at
 * fixed positions. Both are built once in the initialiser and never resized.
 */
@interface StoreTableCell : UITableViewCell

/**
 * @brief The tile on the left.
 *
 * Read-only per the property metadata (@c T@"StorePackView",R,N,V_leftPackView); the initialiser
 * assigns the backing ivar directly rather than going through a setter.
 */
@property(nonatomic, readonly, nullable) StorePackView *leftPackView;
/** @brief The tile on the right, read-only for the same reason. */
@property(nonatomic, readonly, nullable) StorePackView *rightPackView;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
