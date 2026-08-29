/**
 * @file
 * The result screen's "item chance" flourish.
 *
 * Reconstructed from Ghidra program Jubeat (class ResultItemChance, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * A self-contained animation played over the result screen: a burst of particle sprites, a spun
 * item icon, and a number board, all timed by an integer frame counter. The class owns its own
 * @c Texture2D sprite sheet and reports when its fixed-length animation has finished.
 */

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

@class EAGLView;
@class Texture2D;

NS_ASSUME_NONNULL_BEGIN

/**
 * Draws and animates the result screen's item-chance sequence.
 */
@interface ResultItemChance : NSObject

/**
 * The delegate notified about the animation. Weakly held (@c W in the metadata).
 */
@property(nonatomic, weak, nullable) id aDelegate;

/**
 * The rendering surface. Strongly held (@c & in the metadata).
 */
@property(nonatomic, strong, nullable) EAGLView *eaglView;

/**
 * Builds the sprite sheet and resets the particle state.
 *
 * Allocates the @c Texture2D, decrypts the bundled @c item_chance_tex.tex atlas into it with the
 * texture cipher key, loads the sprite rectangles from @c item_chance_tex.plist , clears the frame
 * counter and the four particle-visibility quad-words, and reads the effect size from sprite 8.
 *
 * @ghidraAddress 0x139cac
 */
- (void)loadTexure;

/**
 * Drops the sprite sheet.
 *
 * @ghidraAddress 0x139e7c
 */
- (void)releaseTexture;

/**
 * Configures the sequence for one item award and seeds its particle field.
 *
 * The scale argument is inverted into @c displayScale (the reciprocal), and the centre and size
 * are pre-multiplied by that reciprocal so later drawing works in the unscaled sprite space. The
 * thirty-two particles are seeded with random type, direction, lifetime, and colour. The item icon
 * is loaded from @c chance_item_0<itemType> ; when more than one is awarded, the "x" glyph and the
 * decimal digits of @c itemNum are loaded from @c item_chance_num_<digit> into the trailing
 * sprites.
 *
 * @param itemType Selects the item icon (loaded as @c chance_item_0%d ).
 * @param itemNum How many were awarded; drives the digit sprites.
 * @param size The on-screen size, in scaled points.
 * @param center The on-screen centre, in scaled points.
 * @param scale The result screen's scale; stored inverted.
 * @ghidraAddress 0x139e94
 */
- (void)setInfo:(int)itemType
        itemNum:(int)itemNum
           size:(CGSize)size
         center:(CGPoint)center
          scale:(float)scale;

/**
 * Advances and renders one frame of the sequence.
 *
 * Fades the background frame in over its first eight frames, then runs the particle burst, plays
 * the award sound effect once, and stages the item icon, the "get" board, and the number board as
 * the frame counter passes their cue points. Advances the frame counter and reports completion.
 *
 * @return @c YES once the animation has run past its final frame (frame counter above 0x31).
 * @ghidraAddress 0x13a2a0
 */
- (BOOL)draw;

/**
 * Whether the sequence may be skipped.
 *
 * @return @c YES once the frame counter has passed 0x32.
 * @ghidraAddress 0x13a698
 */
- (BOOL)enableSkip;

/**
 * Draws one particle sprite at a point with an alpha.
 *
 * @param type The particle type; the sprite index is @c type + 8 .
 * @param posX The x centre, already offset by @c screenCenter .
 * @param posY The y centre.
 * @param alpha The opacity.
 * @ghidraAddress 0x13a6b0
 */
- (void)renderEffectParts:(int)type posX:(int)posX posY:(int)posY alpha:(float)alpha;

/**
 * Draws one particle sprite at a point tinted by a colour.
 *
 * Unused by the current @c renderEffect , which always calls the alpha overload; kept because the
 * binary carries it. It stretches the sprite into a fixed 64x64 rect (the @c inRect: overload) and
 * tints it.
 *
 * @param type The particle type; the sprite index is @c type + 8 .
 * @param posX The x centre.
 * @param posY The y centre.
 * @param color The tint colour.
 * @ghidraAddress 0x13a6fc
 */
- (void)renderEffectParts:(int)type posX:(int)posX posY:(int)posY color:(nullable id)color;

/**
 * Renders the thirty-two-particle burst for the current frame.
 *
 * Each live particle eases along its stored direction with a double @c sin -shaped envelope,
 * fading in over the first fifth of its life and out over the rest, and ages by one frame.
 *
 * @ghidraAddress 0x13a734
 */
- (void)renderEffect;

/**
 * Re-seeds the particle field and restarts the animation.
 *
 * Differs from the seeding in @c setInfo: : particle types run 0..2 rather than 0..8, the spread
 * is measured from @c effectSize rather than from an absolute offset, and @c displayScale is not
 * re-applied. Resets the frame counter to zero.
 *
 * @ghidraAddress 0x13a918
 */
- (void)restartAnimation;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
