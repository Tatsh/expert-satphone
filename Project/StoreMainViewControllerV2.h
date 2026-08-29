/**
 * @file
 * The store's main "browse packs" screen, the V2 (recommend-aware) variant.
 *
 * Reconstructed from Ghidra program Jubeat (class StoreMainViewControllerV2, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIViewController : every @c super call in the class targets
 * @c UIViewController , and the controller builds its own @c StorePackTableView ivar, wires itself
 * as that table's view controller, and adds it as a subview — it is not a
 * @c UITableViewController .
 *
 * The screen lists the store's packs grouped by genre. It fetches the genre and pack lists through
 * a @c StorePackListController , shows a promotion carousel (@c StorePromotionView ) and a genre
 * selector (@c StoreGenreSelectView / @c StoreGenreTitleView ) in the table header, and reveals a
 * tapped pack's detail: on the phone a @c StoreDetailViewControllerV2 is pushed; on the pad a
 * dimming cover plus a stack of @c StorePackDetailViewV2 overlays fade and slide in. It also owns
 * the genre-list popover (@c StoreGenreTableViewController inside a
 * @c RotatableNavigationController ) and hosts an @c SKStoreProductViewController for affiliate
 * links. The controller acts as its own table data source and delegate, and adopts the store
 * pack-list, promotion, genre-select, pack-table, pack-detail, editor-id, alert, and StoreKit
 * product delegate protocols.
 */

#import <StoreKit/StoreKit.h>
#import <UIKit/UIKit.h>

#import "AlertViewManager.h"
#import "EditorIDManager.h"
#import "StoreDetailViewControllerV2.h"
#import "StoreGenreSelectView.h"
#import "StorePackListController.h"
#import "StorePromotionView.h"

@class EditorIDManager;
@class RotatableNavigationController;
@class StoreDetailViewControllerV2;
@class StoreGenreTableViewController;
@class StoreGenreTitleView;
@class StoreLoadingView;
@class StorePackDetailViewV2;
@class StorePackInfo;
@class StorePackTableView;
@class StoreViewControllerV2;

NS_ASSUME_NONNULL_BEGIN

/**
 * The store's genre-grouped pack browser with a promotion carousel and pack detail.
 */
@interface StoreMainViewControllerV2 : UIViewController <UITableViewDataSource,
                                                         UITableViewDelegate,
                                                         StorePackListDelegate,
                                                         StorePromotionViewDelegate,
                                                         StoreGenreSelectViewDelegate,
                                                         EditorIDManagerDelegate,
                                                         AlertViewManagerDelegate,
                                                         SKStoreProductViewControllerDelegate,
                                                         StoreDetailViewControllerV2Delegate,
                                                         StoreDetailViewControllerV2CloseDelegate>

/**
 * Builds the controller for a parent store view.
 *
 * Adjusts the layout flags, caches the device idiom, builds either a tappable title label (phone)
 * or a plain navigation title (pad), installs the tab-bar item and back button, and creates the
 * pack-list controller.
 * @param parent The owning @c StoreViewControllerV2 ; held strongly.
 * @return The initialised controller.
 * @ghidraAddress 0x17b488
 */
- (instancetype)initWithParent:(nullable StoreViewControllerV2 *)parent;

/**
 * Builds the view: a vertical grey gradient behind a pack table, plus (on pad) a rounded
 * pack-list container, dimming cover, pack-detail overlay, and the loading view.
 * @ghidraAddress 0x17ba14
 */
- (void)loadView;

/**
 * Starts the initial pack-list fetch, optionally pre-selecting a pack to reveal.
 * @param packID The pack identifier to reveal after loading, or a non-positive value for none.
 * @ghidraAddress 0x17c310
 */
- (void)loadInitialPacklist:(NSInteger)packID;

/**
 * Starts the initial pack-list fetch for a specific genre.
 * @param genreID The genre identifier to open once the list arrives.
 * @ghidraAddress 0x17c464
 */
- (void)loadInitialPacklistWithGenre:(NSInteger)genreID;

/**
 * Reloads the current genre's rows if it holds any packs.
 * @ghidraAddress 0x17c828
 */
- (void)refresh;

/**
 * Scrolls the pack table back to the top (the navigation-bar title tap target).
 * @ghidraAddress 0x180250
 */
- (void)tapNavigation;

/**
 * Updates the row for a pack whose purchase state changed and refreshes any open detail.
 * @param packID The pack identifier that was (re)purchased.
 * @ghidraAddress 0x17c524
 */
- (void)updatePurchaseStateForPackID:(int)packID;

/**
 * Opens a pack's detail: pushes a @c StoreDetailViewControllerV2 on the phone or fades in
 * the pad overlay.
 * @param packInfo The pack to show.
 * @ghidraAddress 0x17c994
 */
- (void)showDetailForPackInfo:(nullable StorePackInfo *)packInfo;

/**
 * Switches the table to another genre, refetching or scrolling as needed and updating the
 * header title.
 * @param genreIndex The genre index to switch to.
 * @ghidraAddress 0x17ce6c
 */
- (void)switchToGenre:(NSUInteger)genreIndex;

/**
 * Opens a recommended pack's detail, capped at ten open details, alerting when the cap is
 * reached.
 * @param packInfo The recommended pack.
 * @return @c YES when the detail was opened, @c NO when the cap alert was shown.
 * @ghidraAddress 0x179dd4
 */
- (BOOL)tapReccommendPack:(nullable StorePackInfo *)packInfo;

/**
 * Pushes a pad pack-detail overlay onto the detail-window stack, sliding the neighbours.
 * @param detailView The new overlay to bring to the front.
 * @ghidraAddress 0x17a154
 */
- (void)pushDetailList:(nullable StorePackDetailViewV2 *)detailView;

/**
 * Pops the top pad pack-detail overlay off the stack, sliding the stack back.
 * @ghidraAddress 0x17a848
 */
- (void)popDetailList;

/**
 * Adds a freshly-fetched additional pack to the detail stack; the shipped body is empty.
 * @ghidraAddress 0x17af18
 */
- (void)allReleaseDetail;

/**
 * Fades out and dismantles every pad pack-detail overlay, keeping the root entry.
 * @ghidraAddress 0x17af1c
 */
- (void)clearDetailWindow;

/**
 * Closes the currently-open pad detail overlay and dismisses the presented controller.
 * @param genreID The genre identifier to refetch after closing.
 * @ghidraAddress 0x17fe98
 */
- (void)addOpenDetail:(NSInteger)genreID;

/**
 * Dismisses the iPad detail overlay: cancels loading and sample, then clears the stack.
 * @param recognizer The tap gesture recogniser on the dimming cover (may be @c nil ).
 * @ghidraAddress 0x17c8d4
 */
- (void)handleTapCoverView:(nullable UITapGestureRecognizer *)recognizer;

/**
 * Hides the genre selector by dismissing the presented popover.
 * @param sender The sender; unused.
 * @ghidraAddress 0x17c980
 */
- (void)hideGenreSelect:(nullable id)sender;

/**
 * Back-button handler: stops the carousel, tells the parent to end the store, and cancels
 * pad detail loading.
 * @param sender The bar-button item.
 * @ghidraAddress 0x17d324
 */
- (void)handleBackButton:(nullable id)sender;

/**
 * Closes any open alert and the pad detail overlay, then dismisses this controller.
 * @ghidraAddress 0x17fa14
 */
- (void)storeClose;

#pragma mark - StorePackListDelegate

/**
 * The pack list finished downloading: reloads the table and reveals a pack when asked.
 * @param controller The pack-list controller reporting the result.
 * @param isInitial Whether this is the first page of the list.
 * @param showPack The pack to reveal once the list is shown, or nil to reveal none.
 * @ghidraAddress 0x17d3fc
 */
- (void)packListDownloadSuccess:(StorePackListController *)controller
                      isInitial:(BOOL)isInitial
                       showPack:(nullable StorePackInfo *)showPack;

/**
 * A further page of pack information arrived: reveals the named pack's detail, if any.
 * @param controller The pack-list controller reporting the result.
 * @param showPack The pack whose detail to open, or nil to do nothing.
 * @ghidraAddress 0x17e7f4
 */
- (void)additionPackInfoDownloadSuccess:(StorePackListController *)controller
                               showPack:(nullable StorePackInfo *)showPack;

/**
 * The pack-list download failed: shows the error to the player.
 * @param controller The pack-list controller reporting the failure.
 * @param errorMessage The message to show, or nil to use the default network-error text.
 * @ghidraAddress 0x17e8e0
 */
- (void)packListDownloadError:(StorePackListController *)controller
                 errorMessage:(nullable NSString *)errorMessage;

/**
 * The pack-list download returned no packs: ends load-more, or shows the server error when
 * the list is not yet on screen.
 * @param controller The pack-list controller reporting the empty result.
 * @ghidraAddress 0x17eb68
 */
- (void)packListDownloadNothing:(StorePackListController *)controller;

#pragma mark - StorePromotionViewDelegate

/**
 * A pack was tapped in the promotion carousel: opens that pack's detail.
 * @param view The promotion carousel sending the message.
 * @param packInfo The tapped pack.
 * @ghidraAddress 0x17ec58
 */
- (void)storePromotionView:(StorePromotionView *)view packSelected:(StorePackInfo *)packInfo;

/**
 * A genre was tapped in the promotion carousel: scrolls the table to that genre.
 * @param view The promotion carousel sending the message.
 * @param genreIndex The index of the tapped genre.
 * @ghidraAddress 0x17ec70
 */
- (void)storePromotionView:(StorePromotionView *)view genreSelected:(NSUInteger)genreIndex;

#pragma mark - StoreGenreSelectViewDelegate

/**
 * A genre was chosen in the genre selector: reloads the table for that genre.
 * @param index The index of the chosen genre.
 * @ghidraAddress 0x17ec80
 */
- (void)StoreGenreSelectViewDelegateGenreSelected:(NSUInteger)index;

#pragma mark - Pack table / pack detail callbacks

/**
 * Pack-table load-more callback: fetches the next page for the current genre.
 * @ghidraAddress 0x17ec8c
 */
- (void)storePackTableViewLoadMore;

/**
 * Pack-table detail callback: opens a pack's detail.
 * @param packInfo The tapped pack.
 * @ghidraAddress 0x17ecec
 */
- (void)storePackTableViewShowDetail:(nullable StorePackInfo *)packInfo;

/**
 * Pack-detail close callback: dismisses the pad overlay.
 * @ghidraAddress 0x17ed00
 */
- (void)storePackDetailViewClose;

/**
 * Pack-detail iTunes callback: opens an affiliate product page or the raw URL.
 * @param url The iTunes URL to open.
 * @ghidraAddress 0x17ed10
 */
- (void)storePackDetailViewOpenItunesWithURL:(nullable NSURL *)url;

#pragma mark - Detail-close / recommend tracking

/**
 * Detail-close navigation callback: decrements the open-detail count unless the close was a
 * recommend push.
 * @ghidraAddress 0x17c8a8
 */
- (void)detailViewCloseNavigation;

/**
 * Pack-detail purchase callback: records the purchasing view and forwards to the parent.
 * @param packInfo The pack being purchased.
 * @ghidraAddress 0x179b8c
 */
- (void)detailViewStartPurchase:(nullable StoreDetailViewControllerV2 *)packInfo;

/**
 * Pack-detail redownload callback: records the redownloading view and forwards to the
 * parent.
 * @param packInfo The pack being redownloaded.
 * @ghidraAddress 0x179cb0
 */
- (void)detailViewStartRedownload:(nullable StoreDetailViewControllerV2 *)packInfo;

#pragma mark - EditorIDManagerDelegate

/**
 * The editor identity downloaded: drops the manager and refetches the current genre.
 * @param manager The editor-ID manager reporting the result.
 * @ghidraAddress 0x180160
 */
- (void)successIDDownload:(nullable id)manager;

/**
 * The editor-identity download failed: drops the manager and refetches the current genre.
 * @param manager The editor-ID manager reporting the failure.
 * @param msgStr The failure message. The binary ignores it; no alert is shown.
 * @ghidraAddress 0x1801d8
 */
- (void)errorIDDownload:(nullable id)manager msgStr:(nullable NSString *)msgStr;

#pragma mark - AlertViewManagerDelegate

/**
 * An alert button was tapped: on Restore, starts the restore and shows the library tab.
 * @param info The alert's result, carrying the tapped button under the button-message key.
 * @ghidraAddress 0x17e80c
 */
- (void)alertSelect:(nonnull NSDictionary *)info;

#pragma mark - SKStoreProductViewControllerDelegate

/**
 * The StoreKit product page finished: dismisses it and drops the retained controller.
 * @param viewController The product view controller that finished.
 * @ghidraAddress 0x17eef0
 */
- (void)productViewControllerDidFinish:(SKStoreProductViewController *)viewController;

#pragma mark - UITableViewDataSource / UITableViewDelegate

/**
 * The number of sections in the genre popover table.
 * @param tableView The table asking.
 * @return Always 1; the genres occupy a single section.
 * @ghidraAddress 0x17f1e0
 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView;

/**
 * The number of rows in the genre popover table.
 * @param tableView The table asking.
 * @param section The section asked about.
 * @return The genre count held by the pack-list controller.
 * @ghidraAddress 0x17f1e8
 */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;

/**
 * The cell for a genre row.
 * @param tableView The table asking.
 * @param indexPath The row's index path.
 * @return The dequeued cell, titled with the genre's name.
 * @ghidraAddress 0x17ef80
 */
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath;

/**
 * The height of a genre row.
 * @param tableView The table asking.
 * @param indexPath The row's index path.
 * @return The fixed genre-popover row height.
 * @ghidraAddress 0x17f204
 */
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath;

/**
 * A genre row is about to be drawn.
 * @param tableView The table asking.
 * @param cell The cell about to be drawn.
 * @param indexPath The row's index path.
 * @ghidraAddress 0x17f200
 */
- (void)tableView:(UITableView *)tableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath;

/**
 * A genre row was tapped: selects that genre and closes the popover.
 * @param tableView The table sending the message.
 * @param indexPath The tapped row's index path.
 * @ghidraAddress 0x17f210
 */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;

#pragma mark - View lifecycle

/**
 * The view is about to appear.
 * @param animated Whether the appearance is animated.
 * @ghidraAddress 0x17f2c0
 */
- (void)viewWillAppear:(BOOL)animated;

/**
 * The view has appeared.
 * @param animated Whether the appearance was animated.
 * @ghidraAddress 0x17f438
 */
- (void)viewDidAppear:(BOOL)animated;

/**
 * The view is about to disappear.
 * @param animated Whether the disappearance is animated.
 * @ghidraAddress 0x17f68c
 */
- (void)viewWillDisappear:(BOOL)animated;

/**
 * The view has disappeared.
 * @param animated Whether the disappearance was animated.
 * @ghidraAddress 0x17f780
 */
- (void)viewDidDisappear:(BOOL)animated;

/**
 * Handles a low-memory warning.
 * @ghidraAddress 0x17f7b8
 */
- (void)didReceiveMemoryWarning;

/**
 * Gives every navigation-bar subview exclusive touch so a tap cannot fall through.
 * @ghidraAddress 0x17f7f0
 */
- (void)viewDidLoad;

/**
 * Releases the table, pad cover, pad detail overlay, and loading view.
 * @ghidraAddress 0x17f980
 */
- (void)viewDidUnload;

/**
 * Whether the screen may rotate to an orientation.
 * @param interfaceOrientation The orientation asked about.
 * @return YES for the two portrait orientations, NO otherwise. This contradicts
 *         @c -supportedInterfaceOrientations , which reports landscape; the binary does both.
 * @ghidraAddress 0x1800b8
 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;

/**
 * The orientations the screen supports.
 * @return @c UIInterfaceOrientationMaskLandscape .
 * @ghidraAddress 0x1800c8
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations;

/**
 * Whether the screen rotates.
 * @return Always YES.
 * @ghidraAddress 0x1800d0
 */
- (BOOL)shouldAutorotate;

/**
 * Clears the pack table's current genre and cancels any editor-ID download in flight.
 * @ghidraAddress 0x1800d8
 */
- (void)dealloc;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
