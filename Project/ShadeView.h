/**
 * @file
 * A dimming overlay that reports taps to its delegate.
 *
 * Reconstructed from Ghidra program Jubeat (class ShadeView, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIView, taken from the dyld bind at the class object's superclass slot
 * (0x352620) rather than from the name.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * What a @c ShadeView tells its owner.
 */
@protocol ShadeViewDelegate <NSObject>
@optional
/**
 * Sent when the shade is tapped.
 *
 * Optional: the view tests for it with @c -respondsToSelector: before sending.
 */
- (void)closeShadeView;
@end

/**
 * A flat dark panel that swallows touches and reports each tap.
 */
@interface ShadeView : UIView

/**
 * The object told when the shade is tapped.
 *
 * The metadata gives no ownership attribute, so this is @c assign rather than @c strong or
 * @c weak — the view does not keep the delegate alive and does not have it nilled on release.
 */
@property(nonatomic, assign, nullable) id<ShadeViewDelegate> delegate;

/**
 * Builds the shade: interaction enabled, and a flat dark fill at 80% alpha.
 * @param frame The view's initial frame.
 * @return The initialised view.
 * @ghidraAddress 0x25d674
 */
- (instancetype)initWithFrame:(CGRect)frame;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
