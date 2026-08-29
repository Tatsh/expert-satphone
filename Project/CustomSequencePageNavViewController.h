/**
 * @file
 * The navigation controller for the custom-sequence page.
 *
 * Reconstructed from Ghidra program Jubeat (class CustomSequencePageNavViewController, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: complete. The runtime metadata declares one method for this class and it is
 * implemented.
 *
 * The superclass was read from the class object's superclass slot at 0x350f50, which binds to
 * @c _OBJC_CLASS_$_UITableViewController at load time rather than being stored in the file.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A table view controller that holds a weak delegate.
 */
@interface CustomSequencePageNavViewController : UITableViewController

/**
 * Forwards to @c -[UITableViewController initWithStyle:] and stores a weak delegate.
 *
 * The delegate is stored with @c objc_storeWeak, so the reference does not keep it alive. The
 * protocol it is expected to conform to is not established — nothing reconstructed sends it
 * anything yet — so it is typed @c id; see TYPES_PENDING.md.
 *
 * @param style The table style to pass to the superclass.
 * @param delegate The delegate, held weakly.
 * @return The initialised controller.
 * @ghidraAddress 0x1e587c
 */
- (instancetype)initWithStyle:(UITableViewStyle)style delegate:(nullable id)delegate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
