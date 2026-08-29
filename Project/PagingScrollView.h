/**
 * @file
 * A paging scroll view whose neighbouring pages stay touchable.
 *
 * Reconstructed from Ghidra program Jubeat (class PagingScrollView, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: complete. The runtime metadata declares one method for this class and it is
 * implemented.
 *
 * The superclass was read from the class object's superclass slot at 0x3505c8, which binds to
 * @c _OBJC_CLASS_$_UIScrollView at load time rather than being stored in the file.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A @c UIScrollView that hit-tests its own subviews directly.
 *
 * The one override is the standard trick for a carousel whose pages are narrower than the screen:
 * the scroll view is made full width so it receives touches across the whole screen, and this
 * method redirects each touch to whichever page actually sits under it, including pages that
 * overflow the scroll view's own bounds.
 */
@interface PagingScrollView : UIScrollView
@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
