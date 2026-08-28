/** @file
 * A page of the unsealed-artwork viewer.
 *
 * Reconstructed from Ghidra program Jubeat (class UnsealDrawController, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIViewController, taken from the dyld bind at the class object's superclass
 * slot (0x34f8d0) rather than from the name.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Shows one encrypted artwork file, filling a caller-supplied rectangle.
 *
 * It carries no layout of its own beyond that rectangle: the file name and the frame are both
 * handed in at construction and only used once the view loads.
 */
@interface UnsealDrawController : UIViewController

/**
 * @brief This page's position within the viewer.
 *
 * A plain synthesised accessor pair. Four bytes wide in the metadata, so @c int rather than
 * @c NSInteger.
 */
@property(nonatomic) int pageTag;

/**
 * @brief Records the artwork to show and the rectangle to show it in.
 *
 * Note that it chains to plain @c -init, not to @c -initWithNibName:bundle:, so there is no nib.
 * Neither argument is used until @c -viewDidLoad.
 *
 * @param name The encrypted @c .tex resource's base name, with no scale suffix or extension.
 * @param frame The rectangle the artwork fills, in the loaded view's coordinates.
 * @return The initialised controller.
 * @ghidraAddress 0x15bcf0
 */
- (instancetype)initWithFileName:(nullable NSString *)name frame:(CGRect)frame;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
