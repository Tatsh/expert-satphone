/**
 * @file
 * A text view that cannot take focus.
 *
 * Reconstructed from Ghidra program Jubeat (class UnselectableTextViewV2, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: complete. The runtime metadata declares one method for this class and it is
 * implemented.
 *
 * The superclass was read from the class object's superclass slot at 0x350de8, which binds to
 * @c _OBJC_CLASS_$_UITextView at load time rather than being stored in the file.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A @c UITextView that refuses first-responder status.
 *
 * The third of three classes in this binary with this identical one-instruction override, after
 * @c DetailTextView and @c UnselectableTextView.
 */
@interface UnselectableTextViewV2 : UITextView
@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
