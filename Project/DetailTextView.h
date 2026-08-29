/**
 * @file
 * @brief A text view that cannot take focus.
 *
 * Reconstructed from Ghidra program Jubeat (class DetailTextView, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: complete. The runtime metadata declares one method for this class and it is
 * implemented.
 *
 * The superclass was read from the class object's superclass slot at 0x34e9f8, which binds to
 * @c _OBJC_CLASS_$_UITextView at load time rather than being stored in the file.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A @c UITextView that refuses first-responder status.
 *
 * Overriding this one method is the standard way to show selectable, scrollable rich text without
 * ever presenting a caret, a selection, or the edit menu. @c UnselectableTextView and
 * @c UnselectableTextViewV2 are two more classes in this binary doing exactly the same thing.
 */
@interface DetailTextView : UITextView
@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
