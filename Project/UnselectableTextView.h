/** @file
 * A text view that cannot take focus.
 *
 * Reconstructed from Ghidra program Jubeat (class UnselectableTextView, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: complete. The runtime metadata declares one method for this class and it is
 * implemented.
 *
 * The superclass was read from the class object's superclass slot at 0x34dd78, which binds to
 * @c _OBJC_CLASS_$_UITextView at load time rather than being stored in the file.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A @c UITextView that refuses first-responder status.
 *
 * Byte-for-byte the same override as @c DetailTextView and @c UnselectableTextViewV2. The binary
 * ships three separate classes rather than one shared base, so all three are reconstructed
 * separately rather than collapsed.
 */
@interface UnselectableTextView : UITextView
@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
