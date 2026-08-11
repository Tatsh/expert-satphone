/** @file
 * The store-parent interface shared by the two store tab controllers.
 *
 * The store's child tab controllers (@c StoreMainViewController, @c StorePurchasedViewController,
 * @c StoreManageViewController, and @c StoreCampaignViewController) are built by, and report back
 * to, whichever store tab controller owns them. The binary has two such owners —
 * @c StoreViewController and @c StoreViewControllerV2, unrelated @c UITabBarController subclasses —
 * so the children hold the parent through this protocol rather than a concrete class.
 */

#import <Foundation/Foundation.h>

@class StoreDialogView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief What a store child controller needs from its owning store tab controller.
 */
@protocol StoreParentViewController <NSObject>

/** @brief The shared modal progress/download dialog panel, or @c nil before it is built. */
@property(nonatomic, readonly, nullable) StoreDialogView *modalDialog;

/** @brief Shows the modal download dialog over the given sender. */
- (void)showModalDialog:(nullable id)sender;

/** @brief Hides the modal download dialog. */
- (void)hideModalDialog;

/** @brief Opens the detail view for a pack. */
- (void)openDetail:(nullable NSNumber *)packID;

/** @brief Begins the first restore-purchases pass. */
- (void)firstRestore;

/** @brief Tears the store down. */
- (void)storeEnd:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
