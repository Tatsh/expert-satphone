/** @file
 * The knit-colour palette manager.
 *
 * Reconstructed from Ghidra program Jubeat (class KnitColorManager, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: grown outwards from its callers. The class object at 0x3480a0 has seven
 * cross-references; only the members reached so far are declared.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief One colour in a knit palette, as the table at 0x353d78 stores it.
 *
 * The components are four floats. The scale is PROVISIONAL: red, green, and blue look like 0 to 255
 * and alpha like 0 to 1, which fits the type 0 entry (255, 255, 255, 1 base; 252, 200, 0, 1 wave)
 * and most others — but the type 2 wave slot decodes to 2290, 0, 18, 1, which fits no colour scale.
 * The field names below are therefore the shape, not a confirmed interpretation. See
 * TYPES_PENDING.md.
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
    KnitColorComponents base; // +0x00
    KnitColorComponents line; // +0x10
    KnitColorComponents wave; // +0x20
} KnitColorPalette;

/**
 * @brief Holds the three colours the knit background is drawn with.
 */
@interface KnitColorManager : NSObject

/**
 * @brief The shared instance.
 *
 * DECLARED ONLY — the body has not been located yet. See TYPES_PENDING.md.
 */
@property(class, nonatomic, readonly) KnitColorManager *sharedManager;

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
- (void)setColorWithType:(int)type;
/**
 * @brief Replaces the palette from an array of colour components.
 *
 * DECLARED ONLY — the body has not been located yet. Called from
 * @c -[JubeatAppDelegate setKnitColor:] at 0x8f88, which passes its argument straight through, so
 * the element type is not established.
 */
- (void)setColorWithArray:(NSArray *)colors;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
