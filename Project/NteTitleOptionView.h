/** @file
 * A title-screen ornament: a background plate that tilts, a car image that bobs on a loop, and a
 * puff of smog that fades in from nothing as the title appears.
 *
 * Reconstructed from Ghidra program Jubeat (class NteTitleOptionView, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIView, from the dyld bind at the class object's superclass slot.
 *
 * The view animates itself the moment it is built — the initialiser ends by calling
 * @c -startAnimation, which reveals the smog and starts the car loop.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A title-screen ornament made of a tiltable background, a looping car, and a smog puff.
 */
@interface NteTitleOptionView : UIView

/**
 * @brief Builds the three layered subviews at the given size and starts the reveal animation.
 *
 * Only the frame's size is used; its origin is ignored. The background plate and the car
 * container both fill the frame, the smog fills the loaded smog artwork's own size, and the car
 * artwork is placed to the right of the smog's width.
 * @param frame The view's frame; only @c size is read.
 * @return The initialised, already-animating ornament.
 * @ghidraAddress 0x2078e4
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Tilts and optionally mirrors the background plate.
 *
 * @param direction A bit-mask: bit 0 mirrors horizontally and negates the tilt, bit 1 tilts one
 * way, and bit 2 tilts the other way (overriding bit 1).
 * @ghidraAddress 0x207bc0
 */
- (void)setOptDirection:(int)direction;

/**
 * @brief Fades the smog in from a collapsed, offset start to its resting scale, then starts the
 * car loop.
 * @ghidraAddress 0x207cb0
 */
- (void)startAnimation;

/**
 * @brief Bobs the car up by a few points and reschedules itself while the loop is enabled.
 * @ghidraAddress 0x207fd4
 */
- (void)startCarAnimation;

/**
 * @brief Disables the car loop and clears every pending animation on the car and the smog.
 * @ghidraAddress 0x208214
 */
- (void)stopAnimation;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
