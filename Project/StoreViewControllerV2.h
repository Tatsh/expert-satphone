/**
 * @file
 * The store's top-level tab-bar container, the V2 (recommend-aware) variant.
 *
 * Reconstructed from Ghidra program Jubeat (class StoreViewControllerV2, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UITabBarController : @c -init chains to @c UITabBarController and installs
 * four tabs — the genre-grouped pack browser (@c StoreMainViewControllerV2 ), the purchased-pack
 * list (@c StorePurchasedViewController ), the download-manager tab
 * (@c StoreManageViewController ), and the campaign tab (@c StoreCampaignViewController ) — each
 * wrapped in a @c RotatableNavigationController . The controller drives the shared purchase,
 * restore, download, editor-ID, and licence-agreement flows on behalf of its tabs: it owns the
 * @c StoreDialogView modal overlay, the @c StoreDownloadManager download queue, and the signed
 * @c SessionDownloader requests used to register the user's age, total purchase, and mission
 * achievements.
 *
 * It acts as the delegate for the purchase manager, the alert manager, the download manager, the
 * store dialog, the editor-ID manager, the session downloaders, and the licence-agreement view,
 * dispatching each callback dynamically through @c respondsToSelector: rather than a declared
 * conformance, so this interface declares no protocol adoption.
 */

#import <StoreKit/StoreKit.h>
#import <UIKit/UIKit.h>

#import "AlertViewManager.h"
#import "EditorIDManager.h"
#import "PurchaseManager.h"
#import "StoreDownloadManager.h"
#import "StoreParentViewController.h"

@class StoreDialogView;
@class StorePackInfo;

NS_ASSUME_NONNULL_BEGIN

/**
 * The store's four-tab container and shared purchase/restore/download coordinator.
 */
@interface StoreViewControllerV2 : UITabBarController <AlertViewManagerDelegate,
                                                       EditorIDManagerDelegate,
                                                       StoreDownloadManagerDelegate,
                                                       StoreParentViewController,
                                                       PurchaseManagerDelegate>

/**
 * Builds the four tabs, each wrapped in a non-translucent navigation controller.
 * @return The initialised controller.
 * @ghidraAddress 0xf1ba0
 */
- (instancetype)init;

/**
 * Opens the main tab on its startup pack or genre, and the campaign tab on its startup
 * campaign, from the startup parameters.
 * @ghidraAddress 0xf1f88
 */
- (void)firstStoreItemLoad;

/**
 * Resumes interaction, then either starts the editor-ID download (when no ID exists) or
 * builds the dimming licence-agreement overlay.
 * @ghidraAddress 0xf212c
 */
- (void)loadInitialStoreInfo;

/**
 * Editor-ID download failure: builds the dimming overlay and shows the error label.
 * @param manager The editor-ID manager.
 * @param msgStr The error message; the localised network-error message is substituted when nil or
 * empty.
 * @ghidraAddress 0xf2404
 */
- (void)errorIDDownload:(nullable id)manager msgStr:(nullable NSString *)msgStr;

/**
 * Editor-ID download success: clears the manager and builds the dimming licence-agreement
 * overlay.
 * @param manager The editor-ID manager.
 * @ghidraAddress 0xf2640
 */
- (void)successIDDownload:(nullable id)manager;

/**
 * Builds the modal cover view and the @c StoreDialogView progress overlay, sized for the
 * device idiom.
 * @ghidraAddress 0xf28a8
 */
- (void)loadView;

/**
 * Tells the root view controller to end the store.
 * @param sender The sender; unused.
 * @ghidraAddress 0xf2ca4
 */
- (void)storeEnd:(nullable id)sender;

/**
 * Fades the modal cover view in and re-enables the dialog's abort button once visible.
 * @param delegate The dialog's abort delegate.
 * @ghidraAddress 0xf2d0c
 */
- (void)showModalDialog:(nullable id)delegate;

/**
 * Fades the modal cover view out, stops the spinner, and unmounts it.
 * @ghidraAddress 0xf3060
 */
- (void)hideModalDialog;

/**
 * Registers the pack's tunes with the music-list manager, then downloads any missing tune
 * and extension files through a @c StoreDownloadManager .
 * @param packID The pack whose purchase state to refresh once queued.
 * @ghidraAddress 0xf3398
 */
- (void)startDownloadMusics:(int)packID;

/**
 * Registers the pack's extension tunes with the music-list manager, then downloads the
 * missing extension files.
 * @param packID The pack whose extensions to download.
 * @ghidraAddress 0xf3cd4
 */
- (void)startDownloadExtendMusics:(int)packID;

/**
 * Presents the restore-confirmation alert.
 * @param sender The sender; unused.
 * @ghidraAddress 0xf4444
 */
- (void)performRestore:(nullable id)sender;

/**
 * Records the pack as the redownload target and presents the already-purchased alert.
 * @param packInfo The pack to redownload.
 * @ghidraAddress 0xf4690
 */
- (void)detailViewStartRedownload:(nullable StorePackInfo *)packInfo;

/**
 * Reports whether the pack's price would exceed the monthly purchase limit, presenting the
 * age-selection or limit-exceeded alert when it would.
 * @param product The StoreKit product being purchased.
 * @return @c YES when the purchase is blocked by the limit, @c NO when it may proceed.
 * @ghidraAddress 0xf4920
 */
- (BOOL)checkAttainLimitPurchase:(nullable SKProduct *)product;

/**
 * Begins a pack purchase: guards purchasability, checks the spend limit, shows the modal
 * dialog, and starts the purchase manager.
 * @param packInfo The pack to purchase.
 * @ghidraAddress 0xf4c9c
 */
- (void)detailViewStartPurchase:(nullable StorePackInfo *)packInfo;

/**
 * Records the pack, shows the modal dialog, and downloads its extension tunes.
 * @param packInfo The pack whose extensions to download.
 * @ghidraAddress 0xf507c
 */
- (void)detailViewStartExtendDownload:(nullable StorePackInfo *)packInfo;

/**
 * Purchase-manager success: clears the delegate, refreshes the purchased list where shown,
 * and downloads the purchased pack's tunes.
 * @param productID The purchased product identifier.
 * @ghidraAddress 0xf5104
 */
- (void)purchaseSucceeded:(nullable NSString *)productID;

/**
 * Purchase-manager failure: hides the dialog, refreshes the purchase state on a receipt
 * error, and presents the appropriate error alert.
 * @param productID The product identifier that failed.
 * @param error The failure.
 * @ghidraAddress 0xf5214
 */
- (void)purchaseFailed:(nullable NSString *)productID error:(nullable NSError *)error;

/**
 * Restore success: clears the delegate, hides the dialog, and shows the restore-complete
 * alert.
 * @ghidraAddress 0xf5794
 */
- (void)restoreSucceeded;

/**
 * Restore failure: clears the delegate, hides the dialog, and shows the restore-cancel
 * error alert.
 * @param error The failure.
 * @ghidraAddress 0xf5990
 */
- (void)restoreFailed:(nullable NSError *)error;

/**
 * Restore with nothing to restore: clears the delegate, hides the dialog, and shows the
 * nothing-to-restore alert.
 * @ghidraAddress 0xf5bec
 */
- (void)restoreNothing;

/**
 * Shows the processing dialog and begins a purchase restore.
 * @ghidraAddress 0xf5dd0
 */
- (void)firstRestore;

/**
 * Alert-button callback: drives restore, purchase, download, age registration, and
 * mission-check flows keyed by the alert tag and tapped button.
 * @param info The alert result dictionary carrying @c "btnMessage" and @c "Tag".
 * @ghidraAddress 0xf5f58
 */
- (void)alertSelect:(nonnull NSDictionary *)info;

/**
 * Store-dialog abort: cancels the download manager, hides the dialog, and refreshes the
 * purchase state.
 * @param dialogView The aborted dialog.
 * @ghidraAddress 0xf66b0
 */
- (void)storeDialogCancel:(nullable id)dialogView;

/**
 * Download-manager task start: updates the dialog's message with the current file name.
 * @param manager The download manager.
 * @ghidraAddress 0xf67cc
 */
- (void)downloadManagerStartTask:(nullable id)manager;

/**
 * Download-manager completion: drops the manager and hides the dialog.
 * @param manager The download manager.
 * @ghidraAddress 0xf6a58
 */
- (void)downloadManagerCompleted:(nullable id)manager;

/**
 * Download-manager failure: refreshes the purchase state, hides the dialog, and shows the
 * download-error alert.
 * @param manager The download manager.
 * @ghidraAddress 0xf6a94
 */
- (void)downloadManagerFailed:(nullable id)manager;

/**
 * Download-manager progress: updates the dialog's progress bar.
 * @param manager The download manager.
 * @ghidraAddress 0xf6d00
 */
- (void)downloadManagerProceed:(nullable id)manager;

/**
 * Closes any alert, opens the main tab's detail for the pack, and selects the main tab.
 * @param packID The pack identifier, boxed in an @c NSNumber .
 * @ghidraAddress 0xf6d88
 */
- (void)openDetail:(nullable NSNumber *)packID;

/**
 * Closes any alert, opens the campaign tab's detail, and selects the campaign tab.
 * @param campaignID The campaign identifier, boxed in an @c NSNumber .
 * @ghidraAddress 0xf6ed4
 */
- (void)openCampaignDetail:(nullable NSNumber *)campaignID;

/**
 * Closes every tab's store session and any open alert.
 * @ghidraAddress 0xf7020
 */
- (void)storeClose;

/**
 * Fades the user-policy overlay in.
 * @ghidraAddress 0xf70c4
 */
- (void)becomeCoverView;

/**
 * Fades the user-policy overlay out.
 * @ghidraAddress 0xf7210
 */
- (void)resignCoverView;

/**
 * Builds a centred error label on the user-policy overlay and fades the overlay in.
 * @param message The error text; the localised network-error message is substituted when nil.
 * @ghidraAddress 0xf732c
 */
- (void)dispErrorLabel:(nullable NSString *)message;

/**
 * Licence-agreement success: registers the user's total purchase or age through a signed
 * session download.
 * @param agreement The agreement view.
 * @ghidraAddress 0xf75a4
 */
- (void)agreementSuccess:(nullable id)agreement;

/**
 * Session-download completion: drives the age, total-purchase, and mission-check flows keyed
 * by the request tag and response status.
 * @param downloader The finished request.
 * @ghidraAddress 0xf7878
 */
- (void)downloaderFinished:(nullable id)downloader;

/**
 * Session-download failure: shows the tag-specific error alert, or an error label on the
 * overlay.
 * @param downloader The failed request.
 * @ghidraAddress 0xf7fc0
 */
- (void)downloaderError:(nullable id)downloader;

/**
 * Licence-agreement failure: fades the agreement view out and ends the store.
 * @param agreement The agreement view.
 * @ghidraAddress 0xf84ac
 */
- (void)agreementFailed:(nullable id)agreement;

/**
 * Licence-agreement acceptance-in-progress: fades the user-policy overlay in.
 * @param agreement The agreement view.
 * @ghidraAddress 0xf8664
 */
- (void)becomePolicyAgreement:(nullable id)agreement;

/**
 * Licence-agreement error: builds a centred error label on the overlay and fades it in.
 * @param agreement The agreement view.
 * @param msgStr The error message; the localised network-error message is substituted when nil.
 * @ghidraAddress 0xf8670
 */
- (void)agreementError:(nullable id)agreement msgStr:(nullable NSString *)msgStr;

/**
 * Builds the mission-achievement-check session downloader from the selected mission sheet's
 * unclaimed challenge missions.
 * @ghidraAddress 0xf88e8
 */
- (void)createStoreMissionDownloader;

/**
 * Chains to super; the override adds nothing of its own.
 * @ghidraAddress 0xf8d3c
 */
- (void)didReceiveMemoryWarning;

/**
 * The view is about to appear.
 * @param animated Whether the appearance is animated.
 * @ghidraAddress 0xf8d74
 */
- (void)viewWillAppear:(BOOL)animated;

/**
 * The view has appeared.
 * @param animated Whether the appearance was animated.
 * @ghidraAddress 0xf8dac
 */
- (void)viewDidAppear:(BOOL)animated;

/**
 * The view is about to disappear.
 * @param animated Whether the disappearance is animated.
 * @ghidraAddress 0xf8de4
 */
- (void)viewWillDisappear:(BOOL)animated;

/**
 * The view has disappeared.
 * @param animated Whether the disappearance was animated.
 * @ghidraAddress 0xf8e1c
 */
- (void)viewDidDisappear:(BOOL)animated;

/**
 * Whether the screen may rotate to an orientation.
 * @param interfaceOrientation The orientation asked about.
 * @return YES for the two portrait orientations, NO otherwise.
 * @ghidraAddress 0xf8e54
 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;

/**
 * The orientations the screen supports.
 * @return Both portrait orientations.
 * @ghidraAddress 0xf8e64
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations;

/**
 * Whether the screen rotates.
 * @return Always YES.
 * @ghidraAddress 0xf8e6c
 */
- (BOOL)shouldAutorotate;

/**
 * The parameters that seed the initial pack, genre, or campaign to open.
 * @ghidraAddress 0xf8eac (getter)
 * @ghidraAddress 0xf8ebc (setter)
 */
@property(nonatomic, strong, nullable) NSDictionary *startupParameters;

/**
 * The shared progress-and-abort modal overlay.
 * @ghidraAddress 0xf8ed0 (getter)
 */
@property(nonatomic, readonly, nullable) StoreDialogView *modalDialog;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
