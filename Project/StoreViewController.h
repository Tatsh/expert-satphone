/** @file
 * The store's top-level tab container, the V1 (original) variant.
 *
 * Reconstructed from Ghidra program Jubeat (class StoreViewController, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base. The class object is at
 * 0x348ec0.
 *
 * The superclass is @c UITabBarController : @c -init chains to @c -[UITabBarController init] and
 * every lifecycle hook and @c -dealloc targets @c UITabBarController . The container builds four
 * child controllers — the pack browser (@c StoreMainViewController ), the purchased library
 * (@c StorePurchasedViewController ), the download manager (@c StoreManageViewController ), and the
 * campaign page (@c StoreCampaignViewController ) — each wrapped in a
 * @c RotatableNavigationController , and installs them as its tab bar's view controllers.
 *
 * It owns the store's shared machinery: the modal progress panel (@c StoreDialogView ), the dimming
 * cover behind it (@c coverView ), a per-run download manager (@c StoreDownloadManager ) fed a
 * queue of tune-file tasks, and the licence-agreement gate (@c usrPolicyView hosting a
 * @c LicenseAgreementView ) shown before the store opens. It drives in-app purchase and restore
 * through @c PurchaseManager , registers the player's age and total-purchase limits through a
 * signed
 * @c SessionDownloader , and provisions the editor id through an @c EditorIDManager . It acts as
 * the purchase, alert, dialog-cancel, download-manager, downloader, and editor-id delegate, and
 * forwards its children's purchase, redownload, and extend-download requests into the shared
 * purchase flow.
 */

#import <UIKit/UIKit.h>

#import "AlertViewManager.h"
#import "Downloader.h"
#import "EditorIDManager.h"
#import "PurchaseManager.h"
#import "StoreDialogView.h"
#import "StoreDownloadManager.h"

@class StoreDetailViewControllerV2;
@class StorePackInfo;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The store's root tab container and shared purchase, download, and agreement coordinator.
 */
@interface StoreViewController : UITabBarController <PurchaseManagerDelegate,
                                                     AlertViewManagerDelegate,
                                                     StoreDialogViewDelegate,
                                                     EditorIDManagerDelegate,
                                                     DownloaderDelegate,
                                                     StoreDownloadManagerDelegate>

/**
 * @brief The deep-link parameters used to pre-open a genre, pack, or campaign. Held strongly.
 * @ghidraAddress 0x907a4 (getter)
 * @ghidraAddress 0x907b4 (setter)
 */
@property(nonatomic, strong, nullable) NSDictionary *startupParameters;

/**
 * @brief The shared modal progress panel behind the dimming cover.
 * @ghidraAddress 0x907c8 (getter)
 */
@property(nonatomic, readonly, strong, nullable) StoreDialogView *modalDialog;

/**
 * @brief Builds the four child controllers, wraps each in a navigation controller, and installs
 * them as the tab bar's view controllers.
 * @return The initialised container.
 * @ghidraAddress 0x89460
 */
- (instancetype)init;

/**
 * @brief Reads the startup parameters and opens the deep-linked genre or pack (and, when present, a
 * campaign) in the appropriate child tab.
 * @ghidraAddress 0x89848
 */
- (void)firstStoreItemLoad;

/**
 * @brief Re-enables interaction and either provisions a missing editor id or builds the
 * licence-agreement gate over the store.
 * @ghidraAddress 0x899ec
 */
- (void)loadInitialStoreInfo;

/**
 * @brief Builds the tab container's view, the dimming cover, and the modal dialog sized for the
 * device idiom.
 * @ghidraAddress 0x8a188
 */
- (void)loadView;

/**
 * @brief Closes the pack browser and asks the root controller to end the store.
 * @param sender The sender; unused.
 * @ghidraAddress 0x8a584
 */
- (void)storeEnd:(nullable id)sender;

/**
 * @brief Fades the dimming cover and modal dialog in, starting the spinner and enabling the abort
 * button on completion.
 * @param delegate The object told when the panel's abort button is pressed.
 * @ghidraAddress 0x8a604
 */
- (void)showModalDialog:(nullable id<StoreDialogViewDelegate>)delegate;

/**
 * @brief Fades the dimming cover and modal dialog out, stopping the spinner and unmounting the
 * dialog on completion.
 * @ghidraAddress 0x8a958
 */
- (void)hideModalDialog;

/**
 * @brief Registers a purchased pack's tunes with the music-list manager and downloads any tune
 * files not already present, driving the modal dialog's progress.
 * @param packID The purchased pack identifier.
 * @ghidraAddress 0x8ac90
 */
- (void)startDownloadMusics:(int)packID;

/**
 * @brief Registers a pack's extend tunes and downloads any extend files not already present,
 * driving the modal dialog's progress.
 * @param packID The pack identifier being extended.
 * @ghidraAddress 0x8b5cc
 */
- (void)startDownloadExtendMusics:(int)packID;

/**
 * @brief Raises the "restore purchases?" confirmation alert.
 * @param sender The sender; unused.
 * @ghidraAddress 0x8bd3c
 */
- (void)performRestore:(nullable id)sender;

/**
 * @brief Child redownload callback: records the pack and raises the "already purchased, download?"
 * confirmation alert.
 * @param packInfo The detail controller reporting the redownload.
 * @ghidraAddress 0x8bf88
 */
- (void)detailViewStartRedownload:(nullable StoreDetailViewControllerV2 *)packInfo;

/**
 * @brief Whether buying a product would exceed the player's purchase limit, raising the appropriate
 * age-registration or limit-reached alert when it does.
 * @param product The StoreKit product about to be purchased.
 * @return @c YES when the limit alert was raised, @c NO when the purchase may proceed.
 * @ghidraAddress 0x8c218
 */
- (BOOL)checkAttainLimitPurchase:(nullable SKProduct *)product;

/**
 * @brief Child purchase callback: records the pack and, unless it is unpurchasable or over the
 * limit, shows the modal dialog and begins the purchase.
 * @param packInfo The detail controller reporting the purchase.
 * @ghidraAddress 0x8c594
 */
- (void)detailViewStartPurchase:(nullable StoreDetailViewControllerV2 *)packInfo;

/**
 * @brief Child extend-download callback: shows the modal dialog and downloads the pack's extend
 * files.
 * @param packInfo The pack being extended.
 * @ghidraAddress 0x8c974
 */
- (void)detailViewStartExtendDownload:(nullable StorePackInfo *)packInfo;

#pragma mark - PurchaseManagerDelegate

/**
 * @ghidraAddress 0x8c9fc
 */
- (void)purchaseSucceeded:(nullable NSString *)productID;

/**
 * @ghidraAddress 0x8cb0c
 */
- (void)purchaseFailed:(nullable NSString *)productID error:(nullable NSError *)error;

/**
 * @ghidraAddress 0x8d08c
 */
- (void)restoreSucceeded;

/**
 * @ghidraAddress 0x8d288
 */
- (void)restoreFailed:(nullable NSError *)error;

/**
 * @ghidraAddress 0x8d4e4
 */
- (void)restoreNothing;

/**
 * @brief Shows the modal dialog and begins a purchase restore.
 * @ghidraAddress 0x8d6c8
 */
- (void)firstRestore;

#pragma mark - AlertViewManagerDelegate

/**
 * @ghidraAddress 0x8d850
 */
- (void)alertSelect:(nonnull NSDictionary *)info;

#pragma mark - StoreDialogViewDelegate

/**
 * @ghidraAddress 0x8dfa8
 */
- (void)storeDialogCancel:(nullable id)dialogView;

#pragma mark - StoreDownloadManagerDelegate

/**
 * @ghidraAddress 0x8e0c4
 */
- (void)downloadManagerStartTask:(nonnull StoreDownloadManager *)manager;

/**
 * @ghidraAddress 0x8e350
 */
- (void)downloadManagerCompleted:(nonnull StoreDownloadManager *)manager;

/**
 * @ghidraAddress 0x8e38c
 */
- (void)downloadManagerFailed:(nonnull StoreDownloadManager *)manager;

/**
 * @ghidraAddress 0x8e5f8
 */
- (void)downloadManagerProceed:(nonnull StoreDownloadManager *)manager;

#pragma mark - Deep-link detail opening

/**
 * @brief Closes any open alert, opens the pack browser's detail for a pack, and switches to the
 * store tab.
 * @param packID The pack identifier, boxed.
 * @ghidraAddress 0x8e680
 */
- (void)openDetail:(nullable NSNumber *)packID;

/**
 * @brief Closes any open alert, opens the campaign page's detail for a campaign, and switches to
 * the campaign tab.
 * @param campaignID The campaign identifier, boxed.
 * @ghidraAddress 0x8e7cc
 */
- (void)openCampaignDetail:(nullable NSNumber *)campaignID;

/**
 * @brief Closes every child's store view and any open alert.
 * @ghidraAddress 0x8e918
 */
- (void)storeClose;

#pragma mark - Cover view and agreement gate

/**
 * @brief Fades the licence-agreement cover in.
 * @ghidraAddress 0x8e9bc
 */
- (void)becomeCoverView;

/**
 * @brief Fades the licence-agreement cover out.
 * @ghidraAddress 0x8eb08
 */
- (void)resignCoverView;

/**
 * @brief Adds a centred error label to the licence-agreement cover and fades the cover in.
 * @param msg The message; a localised network-error message is substituted when @c nil .
 * @ghidraAddress 0x8ec24
 */
- (void)dispErrorLabel:(nullable NSString *)msg;

/**
 * @brief Licence-agreement success: registers the player's total purchase or age limit through a
 * signed session request.
 * @param sender The agreement view; unused.
 * @ghidraAddress 0x8ee9c
 */
- (void)agreementSuccess:(nullable id)sender;

/**
 * @brief Licence-agreement fade-out failure: fades the agreement view out and ends the store.
 * @param sender The agreement view.
 * @ghidraAddress 0x8fda4
 */
- (void)agreementFailed:(nullable id)sender;

/**
 * @brief Licence-agreement gate raised: fades the cover in.
 * @param sender The agreement view; unused.
 * @ghidraAddress 0x8ff5c
 */
- (void)becomePolicyAgreement:(nullable id)sender;

/**
 * @brief Licence-agreement error: adds a centred error label to the cover and fades it in.
 * @param sender The agreement view; unused.
 * @param msg The error message; a localised network-error message is substituted when @c nil .
 * @ghidraAddress 0x8ff68
 */
- (void)agreementError:(nullable id)sender msgStr:(nullable NSString *)msg;

#pragma mark - DownloaderDelegate

/**
 * @ghidraAddress 0x8f170
 */
- (void)downloaderFinished:(nullable id)downloader;

/**
 * @ghidraAddress 0x8f8b8
 */
- (void)downloaderError:(nullable id)downloader;

#pragma mark - EditorIDManagerDelegate

/**
 * @ghidraAddress 0x89f10
 */
- (void)successIDDownload:(nullable id)manager;

/**
 * @ghidraAddress 0x89cd4
 */
- (void)errorIDDownload:(nullable id)manager msgStr:(nullable NSString *)msg;

#pragma mark - Mission achievement

/**
 * @brief Builds the mission-achievement-check session downloader for the challenge missions that
 * are unlocked-by-purchase and not yet cleared, when challenge mode is on.
 * @ghidraAddress 0x901e0
 */
- (void)createStoreMissionDownloader;

#pragma mark - View lifecycle

/**
 * @ghidraAddress 0x90634
 */
- (void)didReceiveMemoryWarning;

/**
 * @ghidraAddress 0x9066c
 */
- (void)viewWillAppear:(BOOL)animated;

/**
 * @ghidraAddress 0x906a4
 */
- (void)viewDidAppear:(BOOL)animated;

/**
 * @ghidraAddress 0x906dc
 */
- (void)viewWillDisappear:(BOOL)animated;

/**
 * @ghidraAddress 0x90714
 */
- (void)viewDidDisappear:(BOOL)animated;

/**
 * @ghidraAddress 0x9074c
 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;

/**
 * @ghidraAddress 0x9075c
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations;

/**
 * @ghidraAddress 0x90764
 */
- (BOOL)shouldAutorotate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
