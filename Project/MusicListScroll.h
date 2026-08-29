/**
 * @file
 * A scroll view that shares its touches with the responder chain.
 *
 * Reconstructed from Ghidra program Jubeat (class MusicListScroll, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: complete. The runtime metadata declares two methods for this class and both
 * are implemented.
 *
 * The superclass was read from the class object's superclass slot at 0x34ca90, which binds to
 * @c _OBJC_CLASS_$_UIScrollView at load time rather than being stored in the file.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A @c UIScrollView that forwards touches to its next responder while it is not scrolling.
 *
 * This is what lets the song list respond to taps: a plain @c UIScrollView swallows touches, so
 * both overrides pass them up the responder chain first and only stop doing so once @c dragging is
 * set, which is the moment the gesture has become a scroll rather than a tap.
 */
@interface MusicListScroll : UIScrollView
@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
