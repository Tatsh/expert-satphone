/** @file
 * The sliding reveal over the NTE game-option strip.
 *
 * Reconstructed from Ghidra program Jubeat (class NteGameOptionRenderer, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIView.
 *
 * The reveal is a chain of short translations rather than one long animation: each step's
 * completion block starts the next, until the strip has moved by its full division count.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A clipped strip that slides its artwork across in equal steps.
 */
@interface NteGameOptionRenderer : UIView

/**
 * @brief Builds the strip and fixes its step count and step size.
 *
 * The artwork is scaled by the phone's width relative to 320, and by nothing on the pad. A phone
 * that is neither a pad nor four-inch gets its height reduced by a flat sixty points instead of
 * scaled — see the note in the implementation.
 * @ghidraAddress 0x153404
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Slides the strip to the step after @c index and, on completion, starts the next.
 *
 * Recurses through its own completion block until the next index would reach the division count.
 *
 * @param index The step just completed. The animation moves to @c index @c + @c 1.
 * @ghidraAddress 0x15363c
 */
- (void)nextOpen:(int)index;

/**
 * @brief Resets the strip and begins the reveal after a one-second pause.
 * @ghidraAddress 0x1538a8
 */
- (void)openStart;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
