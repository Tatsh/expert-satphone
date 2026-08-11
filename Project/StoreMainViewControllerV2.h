/** @file
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
 * @brief The store's genre-grouped pack browser with a promotion carousel and pack detail.
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
 * @brief Builds the controller for a parent store view.
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
 * @brief Builds the view: a vertical grey gradient behind a pack table, plus (on pad) a rounded
 * pack-list container, dimming cover, pack-detail overlay, and the loading view.
 * @ghidraAddress 0x17ba14
 */
- (void)loadView;

/**
 * @brief Starts the initial pack-list fetch, optionally pre-selecting a pack to reveal.
 * @param packID The pack identifier to reveal after loading, or a non-positive value for none.
 * @ghidraAddress 0x17c310
 */
- (void)loadInitialPacklist:(NSInteger)packID;

/**
 * @brief Starts the initial pack-list fetch for a specific genre.
 * @param genreID The genre identifier to open once the list arrives.
 * @ghidraAddress 0x17c464
 */
- (void)loadInitialPacklistWithGenre:(NSInteger)genreID;

/**
 * @brief Reloads the current genre's rows if it holds any packs.
 * @ghidraAddress 0x17c828
 */
- (void)refresh;

/**
 * @brief Scrolls the pack table back to the top (the navigation-bar title tap target).
 * @ghidraAddress 0x180250
 */
- (void)tapNavigation;

/**
 * @brief Updates the row for a pack whose purchase state changed and refreshes any open detail.
 * @param packID The pack identifier that was (re)purchased.
 * @ghidraAddress 0x17c524
 */
- (void)updatePurchaseStateForPackID:(int)packID;

/**
 * @brief Opens a pack's detail: pushes a @c StoreDetailViewControllerV2 on the phone or fades in
 * the pad overlay.
 * @param packInfo The pack to show.
 * @ghidraAddress 0x17c994
 */
- (void)showDetailForPackInfo:(nullable StorePackInfo *)packInfo;

/**
 * @brief Switches the table to another genre, refetching or scrolling as needed and updating the
 * header title.
 * @param genreIndex The genre index to switch to.
 * @ghidraAddress 0x17ce6c
 */
- (void)switchToGenre:(NSUInteger)genreIndex;

/**
 * @brief Opens a recommended pack's detail, capped at ten open details, alerting when the cap is
 * reached.
 * @param packInfo The recommended pack.
 * @return @c YES when the detail was opened, @c NO when the cap alert was shown.
 * @ghidraAddress 0x179dd4
 */
- (BOOL)tapReccommendPack:(nullable StorePackInfo *)packInfo;

/**
 * @brief Pushes a pad pack-detail overlay onto the detail-window stack, sliding the neighbours.
 * @param detailView The new overlay to bring to the front.
 * @ghidraAddress 0x17a154
 */
- (void)pushDetailList:(nullable StorePackDetailViewV2 *)detailView;

/**
 * @brief Pops the top pad pack-detail overlay off the stack, sliding the stack back.
 * @ghidraAddress 0x17a848
 */
- (void)popDetailList;

/**
 * @brief Adds a freshly-fetched additional pack to the detail stack; the shipped body is empty.
 * @ghidraAddress 0x17af18
 */
- (void)allReleaseDetail;

/**
 * @brief Fades out and dismantles every pad pack-detail overlay, keeping the root entry.
 * @ghidraAddress 0x17af1c
 */
- (void)clearDetailWindow;

/**
 * @brief Closes the currently-open pad detail overlay and dismisses the presented controller.
 * @param genreID The genre identifier to refetch after closing.
 * @ghidraAddress 0x17fe98
 */
- (void)addOpenDetail:(NSInteger)genreID;

/**
 * @brief Dismisses the iPad detail overlay: cancels loading and sample, then clears the stack.
 * @param recognizer The tap gesture recogniser on the dimming cover (may be @c nil ).
 * @ghidraAddress 0x17c8d4
 */
- (void)handleTapCoverView:(nullable UITapGestureRecognizer *)recognizer;

/**
 * @brief Hides the genre selector by dismissing the presented popover.
 * @param sender The sender; unused.
 * @ghidraAddress 0x17c980
 */
- (void)hideGenreSelect:(nullable id)sender;

/**
 * @brief Back-button handler: stops the carousel, tells the parent to end the store, and cancels
 * pad detail loading.
 * @param sender The bar-button item.
 * @ghidraAddress 0x17d324
 */
- (void)handleBackButton:(nullable id)sender;

/**
 * @brief Closes any open alert and the pad detail overlay, then dismisses this controller.
 * @ghidraAddress 0x17fa14
 */
- (void)storeClose;

#pragma mark - StorePackListDelegate

/**
 * @ghidraAddress 0x17d3fc
 */
- (void)packListDownloadSuccess:(StorePackListController *)controller
                      isInitial:(BOOL)isInitial
                       showPack:(nullable StorePackInfo *)showPack;

/**
 * @ghidraAddress 0x17e7f4
 */
- (void)additionPackInfoDownloadSuccess:(StorePackListController *)controller
                               showPack:(nullable StorePackInfo *)showPack;

/**
 * @ghidraAddress 0x17e8e0
 */
- (void)packListDownloadError:(StorePackListController *)controller
                 errorMessage:(nullable NSString *)errorMessage;

/**
 * @ghidraAddress 0x17eb68
 */
- (void)packListDownloadNothing:(StorePackListController *)controller;

#pragma mark - StorePromotionViewDelegate

/**
 * @ghidraAddress 0x17ec58
 */
- (void)storePromotionView:(StorePromotionView *)view packSelected:(StorePackInfo *)packInfo;

/**
 * @ghidraAddress 0x17ec70
 */
- (void)storePromotionView:(StorePromotionView *)view genreSelected:(NSUInteger)genreIndex;

#pragma mark - StoreGenreSelectViewDelegate

/**
 * @ghidraAddress 0x17ec80
 */
- (void)StoreGenreSelectViewDelegateGenreSelected:(NSInteger)index;

#pragma mark - Pack table / pack detail callbacks

/**
 * @brief Pack-table load-more callback: fetches the next page for the current genre.
 * @ghidraAddress 0x17ec8c
 */
- (void)storePackTableViewLoadMore;

/**
 * @brief Pack-table detail callback: opens a pack's detail.
 * @param packInfo The tapped pack.
 * @ghidraAddress 0x17ecec
 */
- (void)storePackTableViewShowDetail:(nullable StorePackInfo *)packInfo;

/**
 * @brief Pack-detail close callback: dismisses the pad overlay.
 * @ghidraAddress 0x17ed00
 */
- (void)storePackDetailViewClose;

/**
 * @brief Pack-detail iTunes callback: opens an affiliate product page or the raw URL.
 * @param url The iTunes URL to open.
 * @ghidraAddress 0x17ed10
 */
- (void)storePackDetailViewOpenItunesWithURL:(nullable NSURL *)url;

#pragma mark - Detail-close / recommend tracking

/**
 * @brief Detail-close navigation callback: decrements the open-detail count unless the close was a
 * recommend push.
 * @ghidraAddress 0x17c8a8
 */
- (void)detailViewCloseNavigation;

/**
 * @brief Pack-detail purchase callback: records the purchasing view and forwards to the parent.
 * @param packInfo The pack being purchased.
 * @ghidraAddress 0x179b8c
 */
- (void)detailViewStartPurchase:(nullable StoreDetailViewControllerV2 *)packInfo;

/**
 * @brief Pack-detail redownload callback: records the redownloading view and forwards to the
 * parent.
 * @param packInfo The pack being redownloaded.
 * @ghidraAddress 0x179cb0
 */
- (void)detailViewStartRedownload:(nullable StoreDetailViewControllerV2 *)packInfo;

#pragma mark - EditorIDManagerDelegate

/**
 * @ghidraAddress 0x180160
 */
- (void)successIDDownload:(nullable id)manager;

/**
 * @ghidraAddress 0x1801d8
 */
- (void)errorIDDownload:(nullable id)manager msgStr:(nullable NSString *)msgStr;

#pragma mark - AlertViewManagerDelegate

/**
 * @ghidraAddress 0x17e80c
 */
- (void)alertSelect:(nonnull NSDictionary *)info;

#pragma mark - SKStoreProductViewControllerDelegate

/**
 * @ghidraAddress 0x17eef0
 */
- (void)productViewControllerDidFinish:(SKStoreProductViewController *)viewController;

#pragma mark - UITableViewDataSource / UITableViewDelegate

/**
 * @ghidraAddress 0x17f1e0
 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView;

/**
 * @ghidraAddress 0x17f1e8
 */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;

/**
 * @ghidraAddress 0x17ef80
 */
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath;

/**
 * @ghidraAddress 0x17f204
 */
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath;

/**
 * @ghidraAddress 0x17f200
 */
- (void)tableView:(UITableView *)tableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath;

/**
 * @ghidraAddress 0x17f210
 */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;

#pragma mark - View lifecycle

/**
 * @ghidraAddress 0x17f2c0
 */
- (void)viewWillAppear:(BOOL)animated;

/**
 * @ghidraAddress 0x17f438
 */
- (void)viewDidAppear:(BOOL)animated;

/**
 * @ghidraAddress 0x17f68c
 */
- (void)viewWillDisappear:(BOOL)animated;

/**
 * @ghidraAddress 0x17f780
 */
- (void)viewDidDisappear:(BOOL)animated;

/**
 * @ghidraAddress 0x17f7b8
 */
- (void)didReceiveMemoryWarning;

/**
 * @ghidraAddress 0x17f7f0
 */
- (void)viewDidLoad;

/**
 * @ghidraAddress 0x17f980
 */
- (void)viewDidUnload;

/**
 * @ghidraAddress 0x1800b8
 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;

/**
 * @ghidraAddress 0x1800c8
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations;

/**
 * @ghidraAddress 0x1800d0
 */
- (BOOL)shouldAutorotate;

/**
 * @ghidraAddress 0x1800d8
 */
- (void)dealloc;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
