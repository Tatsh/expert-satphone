/** @file
 * The edit-mode system menu: a two-section table of the EXIT command and the saved-chart load
 * slots.
 *
 * Reconstructed from Ghidra program Jubeat (class EditSystemMenuview, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * A subclass of @c EditFileListViewController that overrides the table data source and delegate to
 * present section 0 (a single EXIT row) and section 1 (a "LOAD" header over the saved-chart slots
 * from @c EditDataManager ). Selections are relayed to the inherited delegate through the
 * @c selectExit and @c selectLoadSlot: selectors, sent only when the delegate responds.
 */

#import "EditFileListViewController.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The edit-mode system menu table.
 */
@interface EditSystemMenuview : EditFileListViewController

/**
 * @brief Returns @c CAGradientLayer .
 *
 * **Never consulted**, as in the superclass: @c +layerClass is a @c UIView class method and this is
 * a @c UITableViewController . See TYPES_PENDING.md.
 * @return The @c CAGradientLayer class.
 * @ghidraAddress 0x218758
 */
+ (Class)layerClass;

/**
 * @brief Builds the menu at a given popover size.
 * @param size The preferred content size.
 * @return The initialised menu.
 * @ghidraAddress 0x21876c
 */
- (instancetype)initWithSize:(CGSize)size;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
