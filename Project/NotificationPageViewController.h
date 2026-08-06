/** @file
 * The controller inside NotificationPageNavController.
 *
 * Reconstructed from Ghidra program Jubeat (class NotificationPageViewController, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: declared only. The class is named by the ivar encoding
 * @c @"NotificationPageViewController" on NotificationPageNavController's first ivar; none of its
 * members is reconstructed.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Shows the notification page's web view.
 */
@interface NotificationPageViewController : UIViewController

/**
 * @brief Builds the controller around whatever the navigation controller was handed.
 *
 * DECLARED ONLY. The argument is untyped in the metadata and is the same object
 * @c NotificationPageNavController keeps as its weak delegate.
 *
 * @param arg The page's owner.
 * @return The initialised controller.
 */
- (instancetype)init:(nullable id)arg;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
