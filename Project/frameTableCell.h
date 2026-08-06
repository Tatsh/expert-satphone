/** @file
 * A row of the tweet-frame picker.
 *
 * Reconstructed from Ghidra program Jubeat (class frameTableCell, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: complete. The runtime metadata declares two methods for this class and both
 * are implemented.
 *
 * The last of the three lower-case cell classes, after @c accessoryTableCell and
 * @c degreeTableCell. All three share a naming style, a two-selector shape and four ivar names, and
 * all three differ in their bodies.
 *
 * The superclass was read from the class object's superclass slot at 0x34eca0, which binds to
 * @c _OBJC_CLASS_$_UITableViewCell at load time rather than being stored in the file.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A cell for one tweet background frame, ticked when it is the one in use.
 */
@interface frameTableCell : UITableViewCell

/**
 * @brief Builds the row's subviews, laid out against the table's width.
 * @param width The table's width in points.
 * @ghidraAddress 0xfda00
 */
- (instancetype)initWithWidth:(int)width;
/**
 * @brief Fills the row in and ticks it when it names the frame currently in use.
 *
 * The only one of the three cells that reads outside its argument: it compares element 2 against
 * the @c "PrefTwitterBgFrame" user default and sets a checkmark accessory on a match. That is the
 * same default @c -[JubeatAppDelegate application:didFinishLaunchingWithOptions:] validates at
 * launch, discarding it when @c +[TweetResourceManager checkEnableSelecteFrame:] rejects it.
 *
 * @param info The row's fields, in order.
 * @ghidraAddress 0xfddf8
 */
- (void)setInfo:(NSArray *)info;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
