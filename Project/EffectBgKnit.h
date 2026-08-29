/**
 * @file
 * @brief One knit-background effect sprite.
 *
 * Reconstructed from Ghidra program Jubeat (class EffectBgKnit, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 */

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

@class Texture2D;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A single animated decoration on the knit background.
 *
 * One instance runs one effect of one type for a fixed number of frames and then reports that it
 * is finished. The class declares no properties; its nine ivars carry the sprite's texture,
 * position, frame counter and per-type width limits.
 */
@interface EffectBgKnit : NSObject

/**
 * @brief Sets the sprite up. **Returns void, not an object,** despite the name.
 *
 * The metadata encodes it @c v56@0:8@16i24{CGPoint=dd}28i44i48i52 and it never chains to an
 * initialiser. The frame counter starts at zero and the duration is chosen from the effect type:
 * ten frames for type zero and a hundred and twenty for every other.
 *
 * Note that @c width_ is the one ivar this does not set.
 *
 * @param texture The sprite's texture. Stored strongly.
 * @param effType Which of the six effects to run.
 * @param startPos Where to draw it.
 * @param wmin The narrowest width the effect uses.
 * @param wmax The widest width the effect uses.
 * @param move How far the effect travels.
 * @ghidraAddress 0x194ff4
 */
- (void)init:(nullable Texture2D *)texture
     effType:(int)effType
    startPos:(CGPoint)startPos
        wmin:(int)wmin
        wmax:(int)wmax
        move:(int)move;

/**
 * @brief A triangle wave over the effect's own cycle.
 *
 * Ramps from zero to @c max across the first half of @c totalFrame and back down across the
 * second, so the value peaks at the midpoint. Single precision throughout — the metadata encodes
 * both the argument and the return as @c f, not @c d.
 *
 * @param frame The current frame. Taken modulo @c totalFrame, so it may run past it.
 * @param totalFrame The cycle's length.
 * @param max The value at the midpoint.
 * @return The interpolated value.
 * @ghidraAddress 0x194fb0
 */
- (float)expand:(int)frame totalFrame:(int)totalFrame max:(float)max;

/**
 * @brief Advances the animation by one frame and draws it.
 *
 * Dispatches six ways on the effect type. Returns YES once the frame counter has reached the
 * effect's duration, so a caller can drop the sprite. A type outside the six draws nothing but
 * still ages, so it retires on schedule.
 * @ghidraAddress 0x1950c0
 */
- (BOOL)renderEffect;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
