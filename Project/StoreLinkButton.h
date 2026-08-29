/**
 * @file
 * @brief A store button that draws its own disclosure chevron.
 *
 * Reconstructed from Ghidra program Jubeat (class StoreLinkButton, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIButton, taken from the dyld bind at the class object's superclass slot
 * (0x3506e0) rather than from the name.
 *
 * The class declares no ivars and no properties: it only overrides three drawing-related methods.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A button with a chevron drawn at its trailing edge, in the title's own colour.
 *
 * The chevron follows the title colour and title shadow for the current control state, so the two
 * state setters below repaint whenever that state actually changes.
 */
@interface StoreLinkButton : UIButton
@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
