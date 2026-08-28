/** @file
 * The knit-colour palette manager.
 *
 * Reconstructed from Ghidra program Jubeat (class KnitColorManager, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The class is complete: all nine hand-written members are recovered.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief One colour in a knit palette, as the table at 0x353d78 stores it.
 *
 * The components are four floats. The scale is confirmed by @c -makeColor:, which divides the first
 * three by the constant 255.0 at 0x28dff4 and passes the fourth through untouched: red, green, and
 * blue are on 0 to 255, alpha on 0 to 1.
 */
typedef struct {
    float red;   /*!< Red, 0 to 255. */
    float green; /*!< Green, 0 to 255. */
    float blue;  /*!< Blue, 0 to 255. */
    float alpha; /*!< Alpha, 0 to 1. */
} KnitColorComponents;

/**
 * @brief One row of the palette table at 0x353d78, 0x30 bytes wide.
 *
 * Offsets are documentation of the shipped 64-bit layout; always go through the named fields.
 */
typedef struct {
    KnitColorComponents base; /*!< The background fill colour. */ // +0x00
    KnitColorComponents line; /*!< The knit line colour. */       // +0x10
    KnitColorComponents wave; /*!< The wave overlay colour. */    // +0x20
} KnitColorPalette;

/**
 * @brief Holds the three colours the knit background is drawn with.
 */
@interface KnitColorManager : NSObject

/**
 * @brief The shared instance.
 * @ghidraAddress 0x165fe0
 */
@property(class, nonatomic, readonly) KnitColorManager *sharedManager;

/**
 * @brief Builds the manager.
 * @return The initialised manager.
 * @ghidraAddress 0x166060
 */
- (instancetype)init;

/**
 * @brief Whether the current palette differs from the default.
 *
 * Backed by @c isKnitColorDiffer (offset global 0x34b254). Set by @c -setColorWithType: to
 * @c (type != 0 && type != 5), so types 0 and 5 are the two that count as "not differing".
 */
@property(nonatomic, readonly) BOOL isKnitColorDiffer;
/**
 * @brief The knit background's base colour. Backed by @c baseColor (0x34b258).
 */
@property(nonatomic, readonly, nullable) UIColor *baseColor;
/**
 * @brief The knit background's line colour. Backed by @c lineColor (0x34b25c).
 */
@property(nonatomic, readonly, nullable) UIColor *lineColor;
/**
 * @brief The knit background's wave colour. Backed by @c waveColor (0x34b260).
 */
@property(nonatomic, readonly, nullable) UIColor *waveColor;

/**
 * @brief Selects a built-in palette by type.
 *
 * Indexes a table of 0x30-byte entries at 0x353d78 by @c type and builds the three colours from the
 * three 16-byte component groups inside the selected entry. The index is not range-checked, so an
 * out-of-range type reads past the table.
 * @ghidraAddress 0x1660d8
 */
- (void)setColorWithType:(unsigned int)type;
/**
 * @brief Builds a colour from one component group.
 *
 * Divides red, green, and blue by 255 and uses alpha as given. The receiver is ignored — the method
 * overwrites @c x0 with the @c UIColor class before doing anything — so it is effectively a free
 * function that happens to be a method.
 * @ghidraAddress 0x166098
 */
- (UIColor *)makeColor:(const KnitColorComponents *)components;
/**
 * @brief Replaces the palette from an array of colour components.
 *
 * Expects nine integers: three triples for base, line, and wave. Each triple is divided by 255 and
 * used with alpha 1.0. If the count is not nine, nothing happens and the differ flag is cleared.
 * @ghidraAddress 0x1661c0
 */
- (void)setColorWithArray:(NSArray *)colors;

/**
 * @brief The current palette's type, derived from the three colours.
 *
 * Returns 0 when the differ flag is clear, 1 when the colours match palette 1, 4 when they match
 * palette 4, and 5 otherwise.
 * @ghidraAddress 0x166528
 */
- (int)getColorType;

/**
 * @brief The current base colour.
 * @return The base colour.
 * @ghidraAddress 0x166744
 */
- (UIColor *)getBaseColor;

/**
 * @brief The current line colour.
 * @return The line colour.
 * @ghidraAddress 0x166754
 */
- (UIColor *)getLineColor;

/**
 * @brief The current wave colour.
 * @return The wave colour.
 * @ghidraAddress 0x166764
 */
- (UIColor *)getWaveColor;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
