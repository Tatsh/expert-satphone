/** @file
 * A rounded, flat-coloured button used throughout the store.
 *
 * Reconstructed from Ghidra program Jubeat (class StoreButton, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIButton, from the dyld bind at the class object's superclass slot
 * (0x34fd80).
 *
 * The button draws itself rather than using a background image, which is why both colour setters
 * force a redraw and why the two state overrides exist at all.
 *
 * RECONSTRUCTION STATE: nine of twelve members written. @c -drawRect: is declared but not
 * reconstructed; see RECONSTRUCTION_STATUS.md.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A button that fills itself with a solid colour and rounds its own corners.
 */
@interface StoreButton : UIButton

/**
 * @brief The fill used while the button is enabled.
 *
 * Defaults to @c UIColor.blueColor , built on first read rather than in the initialiser.
 * @ghidraAddress 0x170c4c (getter)
 */
@property(nonatomic, strong, nullable) UIColor *buttonColor;

/**
 * @brief The fill used while the button is disabled.
 *
 * Defaults to @c UIColor.grayColor , likewise built lazily.
 * @ghidraAddress 0x170cfc (getter)
 */
@property(nonatomic, strong, nullable) UIColor *disabledColor;

/**
 * @brief The corner radius the button rounds itself to.
 * @ghidraAddress 0x170dac (getter)
 */
@property(nonatomic) double cornerRadius;

/**
 * @brief Builds the button.
 *
 * Sets the title colour and shadow for the normal, highlighted, and disabled states, and centres
 * the content both ways. The shadow offset depends on the screen scale so that it is one device
 * pixel on either kind of display.
 *
 * @param frame The button's frame.
 * @return The initialised button.
 * @ghidraAddress 0x170998
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Lightens a colour towards white.
 *
 * Each component becomes @c c*(1-factor) @c + @c factor . **The alpha is blended too**, so a
 * partly transparent colour also becomes more opaque as the factor rises.
 *
 * @param components Four components — red, green, blue, alpha — as raw doubles.
 * @param factor How far towards white, from 0 to 1.
 * @return The lightened colour.
 * @ghidraAddress 0x170dd4
 */
- (nullable UIColor *)highlightColor:(double *)components factor:(double)factor;

/**
 * @brief Redraws when the highlight actually changes.
 * @param highlighted The new state.
 * @ghidraAddress 0x170e1c
 */
- (void)setHighlighted:(BOOL)highlighted;

/**
 * @brief Redraws when the selection actually changes.
 * @param selected The new state.
 * @ghidraAddress 0x170ea8
 */
- (void)setSelected:(BOOL)selected;

/**
 * @brief Fills the button and rounds it.
 *
 * DECLARED ONLY — the body has not been reconstructed yet.
 *
 * @param rect The area to redraw.
 * @ghidraAddress 0x170f34
 */
- (void)drawRect:(CGRect)rect;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
