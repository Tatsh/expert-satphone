/**
 * @file
 * @brief A page-turning viewer over a set of unsealed-artwork files.
 *
 * Reconstructed from Ghidra program Jubeat (class UnsealViewController, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIViewController, taken from the class object's superclass slot rather than
 * from the name. It hosts a @c UIPageViewController with a page-curl transition and drives it as
 * both data source and delegate, and vets the page view controller's gestures as their delegate.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class UnsealViewController;

/**
 * @brief Receives the viewer's page-change notifications.
 *
 * The delegate is stored in a bare @c id slot in the binary; it is only ever messaged through this
 * one selector.
 */
@protocol UnsealViewControllerDelegate <NSObject>

/**
 * @brief Reports the page the viewer has settled on after a turn.
 *
 * @param index The index of the newly shown artwork within the name array.
 * @param completed Whether the page-turn animation ran to completion.
 */
- (void)changeSelectedImage:(int)index completed:(BOOL)completed;

@end

/**
 * @brief A flip-book over an array of artwork file names.
 *
 * Construction records the names and the rectangle each page fills; @c -loadView then builds one
 * @c UnsealDrawController page per name and installs a page-curl @c UIPageViewController as a
 * child. Turning back a page picks a new random artwork, so the viewer never shows the same file
 * twice in a row.
 */
@interface UnsealViewController : UIViewController <UIPageViewControllerDataSource,
                                                    UIPageViewControllerDelegate,
                                                    UIGestureRecognizerDelegate>

/**
 * @brief The object told which artwork the viewer settled on.
 *
 * Weak and non-atomic in the metadata; stored in the @c _aDelegate ivar.
 */
@property(weak, nonatomic, nullable) id<UnsealViewControllerDelegate> aDelegate;

/**
 * @brief Records the artwork names to page through and the rectangle each page fills.
 *
 * Chains to @c UIViewController's plain @c -init (no nib). The names are copied; neither the names
 * nor the rectangle are used until @c -loadView.
 *
 * @param nameArray The artwork base names, one per page.
 * @param bounds The rectangle each page's artwork fills, in the loaded view's coordinates.
 * @return The initialised controller.
 * @ghidraAddress 0x15c094
 */
- (instancetype)initWithNameArray:(nullable NSArray<NSString *> *)nameArray bounds:(CGRect)bounds;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
