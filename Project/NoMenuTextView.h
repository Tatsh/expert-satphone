/** @file
 * A text view with no edit menu and no long-press.
 *
 * Reconstructed from Ghidra program Jubeat (class NoMenuTextView, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: complete. The runtime metadata declares two methods for this class and both
 * are implemented.
 *
 * The superclass was read from the class object's superclass slot at 0x34e340, which binds to
 * @c _OBJC_CLASS_$_UITextView at load time rather than being stored in the file.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A @c UITextView that suppresses the selection menu from both ends.
 *
 * The fourth text view in this binary that fights the edit menu, and the only one that does more
 * than refuse first-responder status: it disables the long-press recogniser that raises the menu,
 * and then refuses every action the menu could offer.
 */
@interface NoMenuTextView : UITextView
@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
