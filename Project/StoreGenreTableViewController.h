/**
 * @file
 * The store's genre table, locked to portrait.
 *
 * Reconstructed from Ghidra program Jubeat (class StoreGenreTableViewController, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UITableViewController, from the dyld bind at the class object's superclass
 * slot (0x3508e8).
 *
 * The class declares no ivars, no properties, and nothing but its three rotation answers — the
 * table's contents come from the superclass and its data source.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A genre table that rotates only between the two portrait orientations.
 */
@interface StoreGenreTableViewController : UITableViewController
@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
