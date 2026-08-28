/** @file
 * The applilink SDK's advert surface.
 *
 * Reconstructed from Ghidra program Jubeat (class AppliView, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIView, taken from the dyld bind at the class object's superclass slot
 * (0x351c20) rather than from the name.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief What an @c AppliView tells its owner.
 */
@protocol AppliViewDelegate <NSObject>
@optional
/**
 * @brief Sent when the view is tapped.
 *
 * The spelling is the SDK's: the selector in the binary really is @c toucheEnded, not
 * @c touchEnded. Optional — the view tests for it with @c -respondsToSelector: first.
 */
- (void)toucheEnded;
@end

/**
 * @brief A full-bleed advert surface that reports each tap.
 */
@interface AppliView : UIView

/**
 * @brief The object told when the view is tapped.
 *
 * The metadata gives no ownership attribute, so this is @c assign rather than @c strong or
 * @c weak.
 */
@property(nonatomic, assign, nullable) id<AppliViewDelegate> delegate;

/**
 * @brief Builds the surface: interaction enabled, fully flexible autoresizing, aspect-fit content.
 * @param frame The view's initial frame.
 * @return The initialised view.
 * @ghidraAddress 0x226fd0
 */
- (instancetype)initWithFrame:(CGRect)frame;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
