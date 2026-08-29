/**
 * @file
 * The store's "restore / manage purchased packs" screen.
 *
 * Reconstructed from Ghidra program Jubeat (class StorePurchasedViewController, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIViewController : every @c super call in the class targets
 * @c UIViewController , and the controller builds its own @c StorePackTableView ivar, wires itself
 * as that table's view controller, and adds it as a subview. It is not a
 * @c UITableViewController .
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
#import "StoreParentViewController.h"

@class StorePackDetailView;
@class StorePackInfo;
@class StorePackListGenre;
@class StorePackTableView;
@class StoreButton;
@class StoreLoadingView;
@class StoreViewController;

NS_ASSUME_NONNULL_BEGIN

/**
 * Lists the user's purchased packs with a restore-purchases action and a pack detail view.
 */
// clang-format off
// One protocol per line: a continuation line that begins with ": Base <" is read by Doxygen as
// undocumented ivars named after the trailing protocols.
@interface StorePurchasedViewController : UIViewController <DownloaderDelegate,
                                                            SKProductsRequestDelegate>
// clang-format on

/**
 * Builds the controller for a parent store view.
 *
 * Sets the navigation and tab-bar titles, loads the tab image, installs a back button targeting
 * the parent, builds the restore button in the right bar-button slot, and caches the device idiom.
 * @param parent The owning @c StoreViewController ; held weakly.
 * @return The initialised controller.
 * @ghidraAddress 0x1b4324
 */
- (instancetype)initWithParent:(nullable id<StoreParentViewController>)parent;

/**
 * Clears the resolved and unresolved pack lists and the table's current genre.
 * @ghidraAddress 0x1b4948
 */
- (void)resetPurchasedList;

/**
 * Gathers the owned and pending pack identifiers, then either shows the empty-list message
 * or starts the catalogue fetch.
 * @ghidraAddress 0x1b49b4
 */
- (void)startLoadPurchasedList;

/**
 * Resets and reloads the purchased-pack list from scratch.
 * @ghidraAddress 0x1b4d8c
 */
- (void)reloadPurchasedList;

/**
 * Builds the view: a vertical grey gradient behind the pack table, plus the iPad detail
 * overlay and the loading view.
 * @ghidraAddress 0x1b4dc0
 */
- (void)loadView;

/**
 * Refreshes the row for a pack whose purchase state changed.
 * @param packID The pack identifier that was (re)purchased.
 * @ghidraAddress 0x1b546c
 */
- (void)updatePurchaseStateForPackID:(int)packID;

/**
 * Dismisses the iPad detail overlay: fades both overlay views out and detaches them.
 * @param recognizer The tap gesture recogniser on the dimming cover (may be @c nil when invoked
 * from @c -storePackDetailViewClose ).
 * @ghidraAddress 0x1b5738
 */
- (void)handleTapCoverView:(nullable UITapGestureRecognizer *)recognizer;

/**
 * Fetches the next page of purchased-pack catalogue entries.
 * @ghidraAddress 0x1b5b40
 */
- (void)startFetch;

/**
 * Cancels the in-flight catalogue downloader and product request.
 * @ghidraAddress 0x1b5c84
 */
- (void)cancelFetching;

/**
 * Reports an error, either in the loading view (before the table is shown) or as an alert.
 * @param message The message to show; a network-error message is substituted when @c nil .
 * @ghidraAddress 0x1b5cf8
 */
- (void)showError:(nullable NSString *)message;

/**
 * @c StorePackTableView load-more callback: fetches the next page.
 * @ghidraAddress 0x1b5f44
 */
- (void)storePackTableViewLoadMore;

/**
 * @c StorePackTableView detail callback: opens a pack's detail (iPad overlay or iPhone
 * push).
 * @param packInfo The tapped pack.
 * @ghidraAddress 0x1b5f50
 */
- (void)storePackTableViewShowDetail:(nullable StorePackInfo *)packInfo;

/**
 * @c StorePackDetailView close callback: dismisses the iPad overlay.
 * @ghidraAddress 0x1b6404
 */
- (void)storePackDetailViewClose;

/**
 * The catalogue fetch finished: resolve product identifiers and fire the product request.
 * @param downloader The downloader reporting the result.
 * @ghidraAddress 0x1b6414
 */
- (void)downloaderFinished:(id)downloader;

/**
 * The catalogue fetch failed: show a network error.
 * @param downloader The downloader reporting the failure.
 * @ghidraAddress 0x1b69c8
 */
- (void)downloaderError:(id)downloader;

/**
 * Progress callback; the shipped body is empty.
 * @param downloader The downloader reporting progress. The binary ignores it.
 * @ghidraAddress 0x1b6a88
 */
- (void)downloaderProceed:(id)downloader;

/**
 * The product request resolved: build the pack list and reload the table.
 * @param request The product request that resolved.
 * @param response The resolved products.
 * @ghidraAddress 0x1b6a8c
 */
- (void)productsRequest:(SKProductsRequest *)request
     didReceiveResponse:(SKProductsResponse *)response;

/**
 * The product request finished: clears the request.
 * @param request The request that finished.
 * @ghidraAddress 0x1b6f80
 */
- (void)requestDidFinish:(SKRequest *)request;

/**
 * The product request failed: re-enable restore and clear the request state.
 * @param request The request that failed.
 * @param error The failure.
 * @ghidraAddress 0x1b6f98
 */
- (void)request:(SKRequest *)request didFailWithError:(NSError *)error;

/**
 * Chains to super; the override adds nothing of its own.
 * @ghidraAddress 0x1b6ff4
 */
- (void)viewDidUnload;

/**
 * The view is about to appear.
 * @param animated Whether the appearance is animated.
 * @ghidraAddress 0x1b702c
 */
- (void)viewWillAppear:(BOOL)animated;

/**
 * The view has appeared.
 * @param animated Whether the appearance was animated.
 * @ghidraAddress 0x1b71a8
 */
- (void)viewDidAppear:(BOOL)animated;

/**
 * The view is about to disappear.
 * @param animated Whether the disappearance is animated.
 * @ghidraAddress 0x1b720c
 */
- (void)viewWillDisappear:(BOOL)animated;

/**
 * The view has disappeared.
 * @param animated Whether the disappearance was animated.
 * @ghidraAddress 0x1b72d4
 */
- (void)viewDidDisappear:(BOOL)animated;

/**
 * Closes any open alert.
 * @ghidraAddress 0x1b730c
 */
- (void)storeClose;

/**
 * Whether the screen may rotate to an orientation.
 * @param interfaceOrientation The orientation asked about.
 * @return YES for the two portrait orientations, NO otherwise.
 * @ghidraAddress 0x1b7354
 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;

/**
 * The orientations the screen supports.
 * @return Both portrait orientations.
 * @ghidraAddress 0x1b7364
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations;

/**
 * Whether the screen rotates.
 * @return Always YES.
 * @ghidraAddress 0x1b736c
 */
- (BOOL)shouldAutorotate;

/**
 * Cancels nothing and removes no observers; the ivars are torn down by the generated
 * destructor.
 * @ghidraAddress 0x1b7374
 */
- (void)dealloc;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
