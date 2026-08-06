/** @file
 * One pack tile in the store's pack grid.
 *
 * Reconstructed from Ghidra program Jubeat (class StorePackView, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: a stub grown outwards from its callers. Only the member
 * @c StoreTableCell touches is declared. The class object is at 0x348988.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A single pack tile.
 */
@interface StorePackView : UIView

/**
 * @brief Who to tell when the tile is used.
 *
 * Held weakly enough that @c -[StoreTableCell dealloc] clears it by hand, so the delegate outlives
 * the tile rather than the other way round. The protocol is not established; see TYPES_PENDING.md.
 */
@property(nonatomic, weak, nullable) id delegate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
