/**
 * @file
 * A view that fills itself with a vertical two-stop gradient.
 *
 * Reconstructed from Ghidra program Jubeat (class GradationView, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIView, taken from the dyld bind at the class object's superclass slot
 * (0x352530) rather than from the name.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A vertical gradient between two colours, drawn top to bottom.
 *
 * Both colours default to clear, so a freshly built instance draws nothing visible.
 */
@interface GradationView : UIView

/**
 * The colour at the top edge. Defaults to clear.
 *
 * Declared @c copy in the metadata. Note that the initialiser assigns the ivar directly and so
 * retains rather than copies; only a caller going through this property gets a copy.
 */
@property(nonatomic, copy, nullable) UIColor *topColor;
/**
 * The colour at the bottom edge. Defaults to clear. Same copy caveat as @c topColor.
 */
@property(nonatomic, copy, nullable) UIColor *bottomColor;

/**
 * Sets both colours to clear.
 * @param frame The view's initial frame.
 * @return The initialised view.
 * @ghidraAddress 0x253cbc
 */
- (instancetype)initWithFrame:(CGRect)frame;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
