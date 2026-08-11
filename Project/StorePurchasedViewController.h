/** @file
 * The store's "restore / manage purchased packs" screen.
 *
 * Reconstructed from Ghidra program Jubeat (class StorePurchasedViewController, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIViewController : every @c super call in the class targets
 * @c UIViewController , and the controller builds its own @c StorePackTableView ivar, wires itself
 * as that table's view controller, and adds it as a subview — it is not a @c UITableViewController
 * .
 *
 * The screen lists the packs the user has already purchased (or has pending). It gathers the
 * owned/pending pack identifiers from the @c PurchaseManager , fetches the matching catalogue
 * entries through a @c Downloader , resolves their @c SKProduct records with an
 * @c SKProductsRequest , and displays them in a @c StorePackTableView . Tapping a pack opens its
 * detail: on the pad an in-place dimming cover plus a @c StorePackDetailView overlay fade in; on
 * the phone a @c StoreDetailViewController is pushed. A navigation-bar restore button offers to
 * restore purchases.
 */

#import <StoreKit/StoreKit.h>
#import <UIKit/UIKit.h>

#import "Downloader.h"

@class StorePackDetailView;
@class StorePackInfo;
@class StorePackListGenre;
@class StorePackTableView;
@class StoreButton;
@class StoreLoadingView;
@class StoreViewController;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Lists the user's purchased packs with a restore-purchases action and a pack detail view.
 */
@interface StorePurchasedViewController
    : UIViewController <DownloaderDelegate, SKProductsRequestDelegate>

/**
 * @brief Builds the controller for a parent store view.
 *
 * Sets the navigation and tab-bar titles, loads the tab image, installs a back button targeting
 * the parent, builds the restore button in the right bar-button slot, and caches the device idiom.
 * @param parent The owning @c StoreViewController ; held weakly.
 * @return The initialised controller.
 * @ghidraAddress 0x1b4324
 */
- (instancetype)initWithParent:(nullable StoreViewController *)parent;

/**
 * @brief Clears the resolved and unresolved pack lists and the table's current genre.
 * @ghidraAddress 0x1b4948
 */
- (void)resetPurchasedList;

/**
 * @brief Gathers the owned and pending pack identifiers, then either shows the empty-list message
 * or starts the catalogue fetch.
 * @ghidraAddress 0x1b49b4
 */
- (void)startLoadPurchasedList;

/**
 * @brief Resets and reloads the purchased-pack list from scratch.
 * @ghidraAddress 0x1b4d8c
 */
- (void)reloadPurchasedList;

/**
 * @brief Builds the view: a vertical grey gradient behind the pack table, plus the iPad detail
 * overlay and the loading view.
 * @ghidraAddress 0x1b4dc0
 */
- (void)loadView;

/**
 * @brief Refreshes the row for a pack whose purchase state changed.
 * @param packID The pack identifier that was (re)purchased.
 * @ghidraAddress 0x1b546c
 */
- (void)updatePurchaseStateForPackID:(int)packID;

/**
 * @brief Dismisses the iPad detail overlay: fades both overlay views out and detaches them.
 * @param recognizer The tap gesture recogniser on the dimming cover (may be @c nil when invoked
 * from @c -storePackDetailViewClose ).
 * @ghidraAddress 0x1b5738
 */
- (void)handleTapCoverView:(nullable UITapGestureRecognizer *)recognizer;

/**
 * @brief Fetches the next page of purchased-pack catalogue entries.
 * @ghidraAddress 0x1b5b40
 */
- (void)startFetch;

/**
 * @brief Cancels the in-flight catalogue downloader and product request.
 * @ghidraAddress 0x1b5c84
 */
- (void)cancelFetching;

/**
 * @brief Reports an error, either in the loading view (before the table is shown) or as an alert.
 * @param message The message to show; a network-error message is substituted when @c nil .
 * @ghidraAddress 0x1b5cf8
 */
- (void)showError:(nullable NSString *)message;

/**
 * @brief @c StorePackTableView load-more callback: fetches the next page.
 * @ghidraAddress 0x1b5f44
 */
- (void)storePackTableViewLoadMore;

/**
 * @brief @c StorePackTableView detail callback: opens a pack's detail (iPad overlay or iPhone
 * push).
 * @param packInfo The tapped pack.
 * @ghidraAddress 0x1b5f50
 */
- (void)storePackTableViewShowDetail:(nullable StorePackInfo *)packInfo;

/**
 * @brief @c StorePackDetailView close callback: dismisses the iPad overlay.
 * @ghidraAddress 0x1b6404
 */
- (void)storePackDetailViewClose;

/**
 * @brief The catalogue fetch finished: resolve product identifiers and fire the product request.
 * @ghidraAddress 0x1b6414
 */
- (void)downloaderFinished:(id)downloader;

/**
 * @brief The catalogue fetch failed: show a network error.
 * @ghidraAddress 0x1b69c8
 */
- (void)downloaderError:(id)downloader;

/**
 * @brief Progress callback; the shipped body is empty.
 * @ghidraAddress 0x1b6a88
 */
- (void)downloaderProceed:(id)downloader;

/**
 * @brief The product request resolved: build the pack list and reload the table.
 * @ghidraAddress 0x1b6a8c
 */
- (void)productsRequest:(SKProductsRequest *)request
     didReceiveResponse:(SKProductsResponse *)response;

/**
 * @brief The product request finished: clears the request.
 * @ghidraAddress 0x1b6f80
 */
- (void)requestDidFinish:(SKRequest *)request;

/**
 * @brief The product request failed: re-enable restore and clear the request state.
 * @ghidraAddress 0x1b6f98
 */
- (void)request:(SKRequest *)request didFailWithError:(NSError *)error;

/**
 * @ghidraAddress 0x1b6ff4
 */
- (void)viewDidUnload;

/**
 * @ghidraAddress 0x1b702c
 */
- (void)viewWillAppear:(BOOL)animated;

/**
 * @ghidraAddress 0x1b71a8
 */
- (void)viewDidAppear:(BOOL)animated;

/**
 * @ghidraAddress 0x1b720c
 */
- (void)viewWillDisappear:(BOOL)animated;

/**
 * @ghidraAddress 0x1b72d4
 */
- (void)viewDidDisappear:(BOOL)animated;

/**
 * @brief Closes any open alert.
 * @ghidraAddress 0x1b730c
 */
- (void)storeClose;

/**
 * @ghidraAddress 0x1b7354
 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;

/**
 * @ghidraAddress 0x1b7364
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations;

/**
 * @ghidraAddress 0x1b736c
 */
- (BOOL)shouldAutorotate;

/**
 * @ghidraAddress 0x1b7374
 */
- (void)dealloc;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
