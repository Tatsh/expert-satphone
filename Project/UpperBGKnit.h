/** @file
 * The knit upper-background decoration.
 *
 * Reconstructed from Ghidra program Jubeat (class UpperBGKnit, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c NSObject. The class builds four horizontal knit "waves" across the top of
 * the screen from precomputed tables, animates their scroll and a plug-in pulse, and renders them
 * into a set of six @c Texture2D drawing layers passed in from the caller.
 *
 * The ivars keep the engine's own names, which is what the runtime metadata records.
 */

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

@class Texture2D;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A four-line knit wave drawn across the upper background.
 */
@interface UpperBGKnit : NSObject

/**
 * @brief Builds the empty decoration.
 * @return The initialised object.
 * @ghidraAddress 0x193e38
 */
- (instancetype)init;

/**
 * @brief Sets up the geometry, palette, and precomputed wave tables.
 *
 * Fetches the base, line, and wave colours from the shared @c KnitColorManager, records the draw
 * area (widened by two points), and fills the four wave tables and the pulse table. Whether the
 * waves are drawn as rectangles or sine curves comes from @c JubeatAppDelegate.isRectangleWave .
 *
 * @param bg The rectangle the knit is drawn into.
 * @param waveBottom The baseline the waves sit on.
 * @param waveTop The height above the baseline the waves rise to.
 * @param pulseHeight The wave amplitude.
 * @param isPad Whether the device is an iPad, which doubles the scroll speed.
 * @ghidraAddress 0x193e70
 */
- (void)initBg:(CGRect)bg
     waveBottom:(float)waveBottom
        waveTop:(float)waveTop
    pulseHeight:(float)pulseHeight
          isPad:(BOOL)isPad;

/**
 * @brief Advances the plug-in pulse tables and eases the baseline towards its target.
 *
 * Clears the accumulated pulse buffer and rebuilds it from every active rise, decaying each rise's
 * timer. Then moves @c wavePosY towards @c pushWaveHeight : gently while playing, or with a fixed
 * approach factor while showing a result.
 *
 * @param tension The current tension, which biases the resting baseline while playing.
 * @param isResult Whether a result is being shown, which selects the faster approach.
 * @ghidraAddress 0x1943b0
 */
- (void)pulseUpdate:(int)tension isResult:(BOOL)isResult;

/**
 * @brief Draws the four wave lines and the background fill into the given layers.
 *
 * @param layers The six @c Texture2D drawing layers, indexed 0 to 5.
 * @param tension The current tension, forwarded to @c -pulseUpdate:isResult: .
 * @param isResult Whether a result is being shown, forwarded to @c -pulseUpdate:isResult: .
 * @ghidraAddress 0x19467c
 */
- (void)renderUpperBg:(NSArray<Texture2D *> *)layers tension:(int)tension isResult:(BOOL)isResult;

/**
 * @brief Triggers a rise pulse in every column at one row.
 *
 * The first argument only selects the column whose existing pulse is tested; when that cell is
 * clear the pulse is started in all four columns at row @c riseColumn .
 *
 * @param row The column tested before starting the pulse.
 * @param riseColumn The row the pulse is started at, across all columns.
 * @ghidraAddress 0x194d38
 */
- (void)riseUp:(int)row riseColumn:(int)riseColumn;

/**
 * @brief Commits all six drawing layers, from front to back.
 * @param layers The six @c Texture2D drawing layers, indexed 0 to 5.
 * @ghidraAddress 0x194d94
 */
- (void)commitBg:(NSArray<Texture2D *> *)layers;

/**
 * @brief Sets the tilt angle applied to the waves.
 * @param deg The tilt, in the units the wave maths expects.
 * @ghidraAddress 0x194eec
 */
- (void)setDeg:(float)deg;

/**
 * @brief Sets the acceleration amount.
 * @param accelerated The acceleration.
 * @ghidraAddress 0x194efc
 */
- (void)addAccelerated:(float)accelerated;

/**
 * @brief Starts or extends a plug-in wave pulse when the value crosses the threshold.
 * @param value The plug amount; a pulse starts only at or above @c pi/16 .
 * @ghidraAddress 0x194f0c
 */
- (void)plugWave:(float)value;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
