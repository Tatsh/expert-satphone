/**
 * @file
 * The store-parent interface shared by the two store tab controllers.
 *
 * The store's child tab controllers (@c StoreMainViewController, @c StorePurchasedViewController,
 * @c StoreManageViewController, and @c StoreCampaignViewController) are built by, and report back
 * to, whichever store tab controller owns them. The binary has two such owners —
 * @c StoreViewController and @c StoreViewControllerV2, unrelated @c UITabBarController subclasses —
 * so the children hold the parent through this protocol rather than a concrete class.
 */

#import <Foundation/Foundation.h>

#import "CampaignDetailViewController.h"
#import "StoreDetailViewController.h"

@class StoreDialogView;

NS_ASSUME_NONNULL_BEGIN

/**
 * What a store child controller needs from its owning store tab controller.
 *
 * The parent tab controller is also the delegate of the detail views its children open, so it
 * incorporates those delegate protocols.
 */
@protocol StoreParentViewController <NSObject,
                                     StoreDetailViewControllerDelegate,
                                     CampaignDetailViewControllerDelegate>

/** The shared modal progress/download dialog panel, or @c nil before it is built. */
@property(nonatomic, readonly, nullable) StoreDialogView *modalDialog;

/**
 * Shows the modal download dialog over the given sender.
 * @param sender The view the dialog is shown over.
 */
- (void)showModalDialog:(nullable id)sender;

/** Hides the modal download dialog. */
- (void)hideModalDialog;

/**
 * Opens the detail view for a pack.
 * @param packID The pack whose detail to open, boxed.
 */
- (void)openDetail:(nullable NSNumber *)packID;

/** Begins the first restore-purchases pass. */
- (void)firstRestore;

/**
 * Tears the store down.
 * @param sender The control that ended the store.
 */
- (void)storeEnd:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
