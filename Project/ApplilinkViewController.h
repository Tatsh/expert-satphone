/**
 * @file
 * The applilink SDK's App Store product-page view controller.
 *
 * @c ApplilinkViewController is the SDK @c UIViewController that owns and presents the native App
 * Store product page through a @c RotateStoreProductViewController (a rotation-unlocking
 * @c SKStoreProductViewController subclass) and reports the store lifecycle back to its
 * @c sdkDelegate. It shows an @c ApplilinkIndicator overlay while the product page loads, is itself
 * the product view controller's @c SKStoreProductViewControllerDelegate, and fires the App Store
 * opened, close, closed, and load-failure notices to the delegate.
 *
 * Reconstructed from Ghidra program Jubeat (image base 0x100000000). All @ghidraAddress values are
 * offsets relative to that image base. This is a closed SDK class, but the jubeat build differs
 * from the other binary that embeds it: it presents the product page first and
 * loads the product from the presentation-completion block, and it carries both the
 * @c -productViewControllerDidFinish: delegate callback and a no-argument
 * @c -productViewControllerDidFinish forced-teardown entry point.
 */

#import <StoreKit/StoreKit.h>
#import <UIKit/UIKit.h>

#import "ApplilinkIndicator.h"
#import "ApplilinkParameters.h"
#import "ApplilinkStore.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * The SDK view controller that presents the App Store product page.
 */
@interface ApplilinkViewController : UIViewController <SKStoreProductViewControllerDelegate>

/**
 * The delegate notified of the store lifecycle notices.
 *
 * Held weakly: the view controller forwards each notice to it but does not own it.
 */
@property(weak, nonatomic, nullable) id<SdkViewDelegate> sdkDelegate;

/**
 * The advert request parameters of the in-flight store request.
 */
@property(copy, nonatomic, nullable) ApplilinkParameters *applilinkParams;

/**
 * The loading overlay shown over the product page while it loads.
 */
@property(strong, nonatomic, nullable) ApplilinkIndicator *indicator;

/**
 * Present the App Store product page for an application.
 *
 * Sizes the view to the main screen, adds a loading @c ApplilinkIndicator overlay, hosts the view
 * in the SDK main window, and presents a @c RotateStoreProductViewController. From the
 * presentation-completion block it asks the store view controller to load the product identified by
 * @p appStoreId; on a successful load the overlay is torn down and the opened notice fires, and on
 * a failed load the whole overlay is removed and the load-failure notice fires.
 * @param appStoreId The App Store application identifier.
 * @param appParam The request parameters.
 * @param delegate The store lifecycle delegate.
 * @ghidraAddress 0x241364
 */
- (void)showSKStore:(nullable NSString *)appStoreId
           appParam:(nullable ApplilinkParameters *)appParam
           delegate:(nullable id<SdkViewDelegate>)delegate;

/**
 * Dismiss the presented App Store product page with animation and post the close notices.
 *
 * The @c SKStoreProductViewControllerDelegate finish callback: fires the close notice, dismisses
 * the product page with animation, and on completion fires the closed notice.
 * @param viewController The product view controller that finished.
 * @ghidraAddress 0x241a9c
 */
- (void)productViewControllerDidFinish:(nullable SKStoreProductViewController *)viewController;

/**
 * Dismiss the presented App Store product page without animation and post the close notices.
 *
 * The no-argument forced-teardown entry point: fires the close notice, dismisses the product page
 * without animation, and on completion fires the closed notice.
 * @ghidraAddress 0x241cc0
 */
- (void)productViewControllerDidFinish;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
