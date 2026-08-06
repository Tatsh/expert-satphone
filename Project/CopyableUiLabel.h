/** @file
 * A label whose text can be copied by tapping it.
 *
 * Reconstructed from Ghidra program Jubeat (class CopyableUiLabel, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UILabel, from the dyld bind at the class object's superclass slot
 * (0x34e110).
 *
 * The class name is the binary's own, @c Ui rather than @c UI .
 *
 * @c InheritCodePayView uses it for the two code fields, which is the point: it is how a player
 * gets an inheritance code off the screen and into a message.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A label that becomes first responder when tapped and offers a Copy menu.
 *
 * The class declares no ivars and no properties. All five members are overrides.
 */
@interface CopyableUiLabel : UILabel

/**
 * @brief Makes the label transparent and, crucially, touchable.
 *
 * @c UILabel has user interaction off by default, so without this nothing else here would ever
 * run.
 *
 * @param frame The label's frame, passed straight to the superclass.
 * @return The initialised label.
 * @ghidraAddress 0xcae50
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Takes first responder status and shows the edit menu over the label.
 * @param touches The touches, forwarded to the superclass.
 * @param event The event, forwarded to the superclass.
 * @ghidraAddress 0xcaeec
 */
- (void)touchesEnded:(NSSet *)touches withEvent:(nullable UIEvent *)event;

/**
 * @brief Always YES, so the edit menu can appear.
 * @return YES.
 * @ghidraAddress 0xcafcc
 */
- (BOOL)canBecomeFirstResponder;

/**
 * @brief Allows @c copy: and defers every other action to the superclass.
 * @param action The action being offered.
 * @param sender The menu.
 * @return Whether the label handles that action.
 * @ghidraAddress 0xcafd4
 */
- (BOOL)canPerformAction:(SEL)action withSender:(nullable id)sender;

/**
 * @brief Puts the label's text on the general pasteboard.
 * @param sender The menu item. Unused.
 * @ghidraAddress 0xcb024
 */
- (void)copy:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
