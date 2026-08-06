/** @file
 * A rounded, flat-coloured button used throughout the store.
 *
 * Reconstructed from Ghidra program Jubeat (class StoreButton, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIButton, from the dyld bind at the class object's superclass slot
 * (0x34fd80).
 *
 * DECLARED ONLY — no method of this class has been reconstructed yet. The three properties are
 * from the runtime metadata; they are what @c StoreDialogView sets.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A button that fills itself with a solid colour and rounds its own corners.
 */
@interface StoreButton : UIButton

/**
 * @brief The fill used while the button is enabled.
 */
@property(nonatomic, strong, nullable) UIColor *buttonColor;

/**
 * @brief The fill used while the button is disabled.
 */
@property(nonatomic, strong, nullable) UIColor *disabledColor;

/**
 * @brief The corner radius the button rounds itself to.
 */
@property(nonatomic) double cornerRadius;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
