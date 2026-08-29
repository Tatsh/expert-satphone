/**
 * @file
 * One expanding ripple on the background.
 *
 * Reconstructed from Ghidra program Jubeat (class BGRipple, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c NSObject, taken from the dyld bind at the class object's superclass slot
 * (0x34f470).
 */

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

@class Texture2D;

NS_ASSUME_NONNULL_BEGIN

/**
 * A single ripple sprite that drifts sideways, swells and fades.
 *
 * The owner steps every ripple once a frame and drops the ones that report themselves finished,
 * then renders the survivors.
 */
@interface BGRipple : NSObject

/**
 * Sets the ripple up. Nothing here is animated yet.
 *
 * @param aSprite The sprite index within the background texture.
 * @param aPoint Where the ripple is centred.
 * @param anXSpeed How far it drifts each step, horizontally only.
 * @param aLifetime How many steps it lasts.
 * @param basesize The sprite's nominal size, used only to offset the draw from its anchor.
 * @param aMag The scale before the swell is applied.
 * @param alpha The opacity before the fades are applied.
 * @ghidraAddress 0x143b38
 */
- (instancetype)initWithSprite:(NSUInteger)aSprite
                       atPoint:(CGPoint)aPoint
                        xSpeed:(float)anXSpeed
                      lifetime:(unsigned int)aLifetime
                      basesize:(float)basesize
                           mag:(float)aMag
                         alpha:(float)alpha;

/**
 * Advances the ripple by one frame.
 *
 * @return YES once the frame counter has passed the lifetime, at which point nothing further
 * happens and the owner should drop it.
 * @ghidraAddress 0x143c0c
 */
- (BOOL)step;

/**
 * Draws the ripple at its current scale and opacity.
 *
 * Silently does nothing once the ripple is past its lifetime, so a caller that ignores @c -step
 * simply stops seeing it.
 *
 * @param texture The background texture the sprite lives in.
 * @ghidraAddress 0x143c70
 */
- (void)renderWithTexture:(nullable Texture2D *)texture;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
