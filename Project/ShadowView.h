/**
 * @file
 * A view that draws an inner shadow along its own edge.
 *
 * Reconstructed from Ghidra program Jubeat (class ShadowView, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: complete. The runtime metadata declares two methods beyond the property
 * accessors and both are implemented.
 *
 * The superclass was read from the class object's superclass slot at 0x34e7f0, which binds to
 * @c _OBJC_CLASS_$_UIView at load time rather than being stored in the file.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A transparent, non-interactive overlay that casts a shadow inwards.
 *
 * The usual way to get an inner shadow out of Core Graphics, which only casts outwards: build a
 * path for the shape, build a second much larger path around it, append the first to the second,
 * and fill the pair with the even-odd rule so the shadow falls into the hole.
 */
@interface ShadowView : UIView

/** The corner radius of the shadowed shape. Zero draws a plain rectangle. */
@property(nonatomic) double cornerRadius;
/** How far the shadow spreads. Defaults to 4. */
@property(nonatomic) double shadowBlurRadius;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
