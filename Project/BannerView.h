/**
 * @file
 * A store banner that fetches its own artwork.
 *
 * Reconstructed from Ghidra program Jubeat (class BannerView, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIView, taken from the dyld bind at the class object's superclass slot
 * (0x3505f0) rather than from the name.
 */

#import <UIKit/UIKit.h>

#import "StorePromotion.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * A grey plate holding one aspect-fill image view, loaded over the network on demand.
 */
@interface BannerView : UIView

/**
 * The image view filling the banner.
 *
 * Readonly: it is built by the initialiser and never replaced.
 */
@property(nonatomic, readonly, nullable) UIImageView *imageView;

/**
 * The promotion whose artwork this banner shows.
 *
 * Read by @c -loadImageWithSession: to find the address to fetch.
 */
@property(nonatomic, strong, nullable) StorePromotion *promotion;

/**
 * Builds the grey plate and its clipped, aspect-filling image view.
 * @param frame The view's initial frame.
 * @return The initialised view.
 * @ghidraAddress 0x1bae8c
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * Rounds both the banner's own corners and its image view's, to the same radius.
 * @param cornerRadius The radius to apply to both layers.
 * @ghidraAddress 0x1bb028
 */
- (void)setCornerRadius:(CGFloat)cornerRadius;

/**
 * Starts fetching the promotion's artwork.
 *
 * Does nothing when the promotion's address does not parse as a URL. The task replaces any
 * previous one, and the image view is captured weakly so a banner that goes away mid-flight does
 * not keep it alive.
 *
 * @param session The session to create the data task on.
 * @ghidraAddress 0x1bb0c0
 */
- (void)loadImageWithSession:(nullable NSURLSession *)session;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
