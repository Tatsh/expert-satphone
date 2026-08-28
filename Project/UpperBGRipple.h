/** @file
 * One bouncing sprite in the upper background, with its reflection.
 *
 * Reconstructed from Ghidra program Jubeat (class UpperBGRipple, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c NSObject, from the dyld bind at the class object's superclass slot
 * (0x34f4c0).
 *
 * The ivars keep the engine's own @c snake_case names, which is what the runtime metadata records.
 * @c point.y is a height **above** the ground line and is never negative: it is clamped to zero on
 * landing. Everything else follows from that — the sprite is drawn at @c y_gnd @c - @c point.y and
 * its reflection at @c y_gnd @c + @c point.y .
 */

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

#import "Texture2D.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A sprite that drifts leftwards, bounces on a ground line, and casts a reflection.
 */
@interface UpperBGRipple : NSObject

/**
 * @brief The ground line this sprite bounces on, and the key it is depth-sorted by.
 * @ghidraAddress 0x144188 (getter)
 */
@property(nonatomic, readonly) float y_gnd;

/**
 * @brief Builds one sprite with its motion parameters.
 *
 * The mass is not a parameter: it is chosen here at random, between 4 and 6.875.
 *
 * @param aSprite The sprite index within the texture.
 * @param aPoint The starting position. Its @c y is a height above @c yGround .
 * @param xSpeed How far the sprite moves left each step.
 * @param yGround The ground line.
 * @param yAmp The wave amplitude.
 * @param yCenter The wave centre.
 * @param yPeriod The wave period.
 * @param yPhase The wave phase.
 * @param aMag The draw scale.
 * @return The initialised sprite.
 * @ghidraAddress 0x143dd0
 */
- (instancetype)initWithSprite:(NSUInteger)aSprite
                       atPoint:(CGPoint)aPoint
                        xSpeed:(float)xSpeed
                       yGround:(float)yGround
                          yAmp:(float)yAmp
                       yCenter:(float)yCenter
                       yPeriod:(unsigned int)yPeriod
                        yPhase:(unsigned int)yPhase
                           mag:(float)aMag;

/**
 * @brief Launches the sprite upwards, but only from rest.
 *
 * The guard is a window around zero rather than a test for exactly zero, so a sprite that is
 * airborne ignores the call entirely.
 *
 * @param force The impulse. Divided by the sprite's own mass to get its speed.
 * @ghidraAddress 0x143f18
 */
- (void)triggerJump:(float)force;

/**
 * @brief Advances the sprite one step: left by its speed, and up or down under gravity.
 *
 * @param resetX Where to put the sprite when it has drifted off the left edge. Despite being the
 * selector's first keyword this is a position, not a step.
 * @param gravity Subtracted from the vertical speed each step.
 * @param bounce How much of the vertical speed survives a landing.
 * @ghidraAddress 0x143f5c
 */
- (void)stepFall:(float)resetX gravity:(float)gravity bounce:(float)bounce;

/**
 * @brief Draws the sprite and, when it is still in view, its reflection.
 *
 * @param texture The texture to draw from.
 * @param yLimit How far down the reflection may be drawn before it is dropped.
 * @ghidraAddress 0x143fdc
 */
- (void)renderWithTexture:(nullable Texture2D *)texture yLimit:(float)yLimit;

/**
 * @brief Orders two sprites back to front by their ground lines.
 * @param other The sprite to compare against.
 * @return @c NSOrderedAscending , @c NSOrderedSame or @c NSOrderedDescending .
 * @ghidraAddress 0x144100
 */
- (NSInteger)compZ:(nullable UpperBGRipple *)other;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
