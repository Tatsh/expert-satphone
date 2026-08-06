/** @file
 * The engine's sprite-sheet texture.
 *
 * Reconstructed from Ghidra program Jubeat (class Texture2D, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: a stub grown outwards from its callers. Only the one drawing entry point
 * reached so far is declared; the class carries six @c drawSprite… overloads in total.
 */

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A texture that can draw any of the sprites packed into it.
 */
@interface Texture2D : NSObject

/**
 * @brief Draws one sprite with a scale, a rotation about an anchor, and an alpha.
 *
 * DECLARED ONLY. The parameter widths come from the selector's type encoding
 * @c v72\@0:8Q16{CGPoint=dd}24f40f44{CGPoint=dd}48c64f68 : the scale, rotation and alpha are
 * @c float rather than @c CGFloat , and @c transform is a @c char .
 *
 * @param sprite The sprite index.
 * @param point Where to draw it.
 * @param scale The draw scale.
 * @param rotate The rotation in radians.
 * @param anchor The point to rotate about.
 * @param transform A transform selector, not a matrix.
 * @param alpha The opacity.
 */
- (void)drawSprite:(NSUInteger)sprite
           atPoint:(CGPoint)point
             scale:(float)scale
            rotate:(float)rotate
            anchor:(CGPoint)anchor
         transform:(char)transform
             alpha:(float)alpha;

/**
 * @brief Draws one sprite stretched into a rectangle.
 *
 * DECLARED ONLY. Encoding @c v64\@0:8Q16{CGRect=…}24c56f60 : @c transform is a @c char and
 * @c alpha a @c float , as in the overload above.
 *
 * @param sprite The sprite index.
 * @param rect Where to draw it.
 * @param transform A transform selector, not a matrix.
 * @param alpha The opacity.
 */
- (void)drawSprite:(NSUInteger)sprite
            inRect:(CGRect)rect
         transform:(char)transform
             alpha:(float)alpha;

/**
 * @brief Draws one sprite at a point, at its own size.
 *
 * DECLARED ONLY. Encoding @c v48\@0:8Q16{CGPoint=dd}24c40f44 .
 *
 * @param sprite The sprite index.
 * @param point Where to draw it.
 * @param transform A transform selector, not a matrix.
 * @param alpha The opacity.
 */
- (void)drawSprite:(NSUInteger)sprite
           atPoint:(CGPoint)point
         transform:(char)transform
             alpha:(float)alpha;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
