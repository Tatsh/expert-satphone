/**
 * @file
 * A popover listing the player's saved edit charts.
 *
 * Reconstructed from Ghidra program Jubeat (class EditFileListViewController, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UITableViewController, from the dyld bind at the class object's superclass
 * slot (0x351770).
 *
 * Three of the class's five ivars — @c labelMessage , @c tableFiles and @c shadowView — are
 * declared in the metadata and written by nothing in the class. They are left in place because the
 * ivar list is what the runtime records, not because anything uses them.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * What an @c EditFileListViewController tells its owner.
 *
 * The protocol's name is the binary's own, taken from the delegate ivar's encoding
 * @c \@"<EditFileListViewDelegate>" .
 */
@protocol EditFileListViewDelegate <NSObject>
@optional
/**
 * Sent when a chart is chosen.
 * @param index The chosen row.
 */
- (void)editFileListViewSelectItem:(NSInteger)index;
@end

/**
 * A table of saved edit charts, each showing its name and note count.
 */
@interface EditFileListViewController : UITableViewController

/**
 * The object told which chart was chosen.
 */
@property(nonatomic, weak, nullable) id<EditFileListViewDelegate> delegate;

/**
 * The charts to list. Each element is a dictionary.
 */
@property(nonatomic, strong, nullable) NSMutableArray *fileList;

/**
 * Returns @c CAGradientLayer .
 *
 * **Never consulted.** @c +layerClass is a @c UIView class method; UIKit does not ask a view
 * controller for one, and this class is a @c UITableViewController . See TYPES_PENDING.md.
 *
 * @return The @c CAGradientLayer class.
 * @ghidraAddress 0x208318
 */
+ (Class)layerClass;

/**
 * Builds the controller at a given popover size.
 * @param size The preferred content size.
 * @return The initialised controller.
 * @ghidraAddress 0x20832c
 */
- (instancetype)initWithSize:(CGSize)size;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
