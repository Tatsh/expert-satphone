/** @file
 * The popover of editor buttons.
 *
 * Reconstructed from Ghidra program Jubeat (class EditButtonViewController, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIViewController, taken from the dyld bind at the class object's superclass
 * slot (0x3516d0) rather than from the name.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The keys of the dictionary handed to the delegate on a tap.
 */
typedef NSString *EditButtonSelectionKey NS_TYPED_ENUM;
/** @brief The controller's own name, as passed to @c -initWithButtonArray:selNum:delegate:ctrlName:
 */
extern EditButtonSelectionKey const EditButtonSelectionKeyName;
/** @brief The tapped button's index, boxed as an @c NSNumber. */
extern EditButtonSelectionKey const EditButtonSelectionKeySelect;

/**
 * @brief What an @c EditButtonViewController tells its owner.
 */
@protocol EditButtonViewControllerDelegate <NSObject>
@optional
/**
 * @brief Sent when one of the buttons is tapped.
 *
 * Note the argument names are the binary's and do not describe what arrives: the first argument is
 * the controller itself, and the second is a dictionary keyed by
 * @c EditButtonSelectionKeyName and @c EditButtonSelectionKeySelect — not a tag.
 *
 * @param controller The controller that was tapped.
 * @param info The selection dictionary.
 */
- (void)editBtnSelect:(EditButtonViewController *)controller tag:(NSDictionary *)info;
@end

/**
 * @brief A row of image buttons built from a list of artwork names.
 *
 * One button per name, laid out left to right with a two-point gap, each sized to its own artwork.
 * The selected entry loads a differently-named variant of its artwork.
 */
@interface EditButtonViewController : UIViewController

/**
 * @brief Builds the row and sizes the popover to it.
 *
 * @param buttonArray The artwork base names, one per button, in display order.
 * @param selNum The index whose artwork is loaded from its selected variant instead.
 * @param delegate The object told about taps. Stored weakly.
 * @param ctrlName This controller's name, handed back to the delegate on every tap.
 * @ghidraAddress 0x207348
 */
- (instancetype)initWithButtonArray:(nullable NSArray<NSString *> *)buttonArray
                             selNum:(int)selNum
                           delegate:(nullable id<EditButtonViewControllerDelegate>)delegate
                           ctrlName:(nullable NSString *)ctrlName;

/**
 * @brief The action every button targets.
 * @param sender The tapped button, whose tag is its index in the array.
 * @ghidraAddress 0x20773c
 */
- (void)pushBtn:(UIButton *)sender;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
