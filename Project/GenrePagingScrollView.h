/** @file
 * A paging scroll view whose neighbouring pages stay touchable.
 *
 * Reconstructed from Ghidra program Jubeat (class GenrePagingScrollView, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: complete. The runtime metadata declares one method for this class and it is
 * implemented.
 *
 * The superclass was read from the class object's superclass slot at 0x350d48, which binds to
 * @c _OBJC_CLASS_$_UIScrollView at load time rather than being stored in the file.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A @c UIScrollView that hit-tests its own subviews directly.
 *
 * Its one method is instruction-for-instruction the same as
 * @c -[PagingScrollView hitTest:withEvent:]. The binary ships the two as separate classes with no
 * shared base, so both are reconstructed rather than one deriving from the other.
 */
@interface GenrePagingScrollView : UIScrollView
@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
