/** @file
 * The store's main "browse packs" screen, the V1 (original) variant.
 *
 * Reconstructed from Ghidra program Jubeat (class StoreMainViewController, image base
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
 * @c RotatableNavigationController ), a terms-of-service navigation controller
 * (@c TermsNavController ) reached by a right-hand bar button, a one-time "tap the title to scroll
 * to the top" balloon tutorial (@c BalloonView , phone only), and hosts an
 * @c SKStoreProductViewController for affiliate links. The controller acts as its own table data
 * source and delegate, and adopts the store pack-list, promotion, genre-select, StoreKit product,
 * popover, scroll, editor-id, alert, terms-navigation, and pack-detail delegate protocols.
 */

#import <StoreKit/StoreKit.h>
#import <UIKit/UIKit.h>

#import "AlertViewManager.h"
#import "EditorIDManager.h"
#import "SettingsNavController.h"
#import "StoreDetailViewControllerV2.h"
#import "StoreGenreSelectView.h"
#import "StorePackListController.h"
#import "StoreParentViewController.h"
#import "StorePromotionView.h"

@class BalloonView;
@class RotatableNavigationController;
@class StoreDetailViewControllerV2;
@class StoreGenreTableViewController;
@class StoreGenreTitleView;
@class StoreLeafletView;
@class StoreLoadingView;
@class StorePackDetailViewV2;
@class StorePackInfo;
@class StorePackTableView;
@class StoreViewController;
@class TermsNavController;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The store's genre-grouped pack browser with a promotion carousel and pack detail.
 */
@interface StoreMainViewController : UIViewController <UITableViewDataSource,
                                                       UITableViewDelegate,
                                                       UIScrollViewDelegate,
                                                       UIPopoverPresentationControllerDelegate,
                                                       StorePackListDelegate,
                                                       StorePromotionViewDelegate,
                                                       StoreGenreSelectViewDelegate,
                                                       EditorIDManagerDelegate,
                                                       AlertViewManagerDelegate,
                                                       SettingsNavControllerDelegate,
                                                       StoreDetailViewControllerV2Delegate,
                                                       StoreDetailViewControllerV2CloseDelegate,
                                                       SKStoreProductViewControllerDelegate>

/**
 * @brief Builds the controller for a parent store view.
 *
 * Builds the terms navigation controller, adjusts the layout flags, caches the device idiom, builds
 * either a tappable title label plus a one-time tutorial balloon (phone) or a plain navigation
 * title (pad), installs the tab-bar item, back button, and policy right button, and creates the
 * pack-list controller.
 * @param parent The owning @c StoreViewController ; held weakly.
 * @return The initialised controller.
 * @ghidraAddress 0xa1bc0
 */
- (instancetype)initWithParent:(nullable id<StoreParentViewController>)parent;

/**
 * @brief Builds the view: a vertical grey gradient behind a pack table, plus (on pad) a rounded
 * pack-list container, dimming cover, pack-detail overlay, and the loading view.
 * @ghidraAddress 0xa2618
 */
- (void)loadView;

/**
 * @brief Starts the initial pack-list fetch, optionally pre-selecting a pack to reveal.
 * @param packID The pack identifier to reveal after loading, or a non-positive value for none.
 * @ghidraAddress 0xa2f14
 */
- (void)loadInitialPacklist:(NSInteger)packID;

/**
 * @brief Starts the initial pack-list fetch for a specific genre.
 * @param genreID The genre identifier to open once the list arrives.
 * @ghidraAddress 0xa3068
 */
- (void)loadInitialPacklistWithGenre:(NSInteger)genreID;

/**
 * @brief Reloads the current genre's rows if it holds any packs.
 * @ghidraAddress 0xa342c
 */
- (void)refresh;

/**
 * @brief Scrolls the pack table back to the top, and dismisses the one-time tutorial balloon on its
 * first use (the navigation-bar title tap target).
 * @ghidraAddress 0xa70dc
 */
- (void)tapNavigation;

/**
 * @brief Pack-table scroll callback: fades the tutorial balloon back in.
 * @ghidraAddress 0xa72bc
 */
- (void)packListScrolled;

/**
 * @brief Updates the row for a pack whose purchase state changed and refreshes any open detail.
 * @param packID The pack identifier that was (re)purchased.
 * @ghidraAddress 0xa3128
 */
- (void)updatePurchaseStateForPackID:(int)packID;

/**
 * @brief Opens a pack's detail: pushes a @c StoreDetailViewControllerV2 on the phone or fades in
 * the pad overlay.
 * @param packInfo The pack to show.
 * @ghidraAddress 0xa3598
 */
- (void)showDetailForPackInfo:(nullable StorePackInfo *)packInfo;

/**
 * @brief Switches the table to another genre, refetching or scrolling as needed and updating the
 * header title.
 * @param genreIndex The genre index to switch to.
 * @ghidraAddress 0xa3a70
 */
- (void)switchToGenre:(NSUInteger)genreIndex;

/**
 * @brief Opens a recommended pack's detail, capped at ten open details, alerting when the cap is
 * reached.
 * @param packInfo The recommended pack.
 * @return @c YES when the detail was opened, @c NO when the cap alert was shown.
 * @ghidraAddress 0xa050c
 */
- (BOOL)tapReccommendPack:(nullable StorePackInfo *)packInfo;

/**
 * @brief Pushes a pad pack-detail overlay onto the detail-window stack, sliding the neighbours.
 * @param detailView The new overlay to bring to the front.
 * @ghidraAddress 0xa088c
 */
- (void)pushDetailList:(nullable StorePackDetailViewV2 *)detailView;

/**
 * @brief Pops the top pad pack-detail overlay off the stack, sliding the stack back.
 * @ghidraAddress 0xa0f80
 */
- (void)popDetailList;

/**
 * @brief Adds a freshly-fetched additional pack to the detail stack; the shipped body is empty.
 * @ghidraAddress 0xa1650
 */
- (void)allReleaseDetail;

/**
 * @brief Fades out and dismantles every pad pack-detail overlay, keeping the root entry.
 * @ghidraAddress 0xa1654
 */
- (void)clearDetailWindow;

/**
 * @brief Closes the currently-open pad detail overlay and dismisses the presented controller.
 * @param genreID The genre identifier to refetch after closing.
 * @ghidraAddress 0xa6c44
 */
- (void)addOpenDetail:(NSInteger)genreID;

/**
 * @brief Forwards a recommended-pack open request to the parent store view, discarding the current
 * genre's first pack-list entry.
 * @param packID The pack identifier to open.
 * @ghidraAddress 0xa6e84
 */
- (void)pushOpenDetail:(nullable NSNumber *)packID;

/**
 * @brief Dismisses the iPad detail overlay: cancels loading and sample, then clears the stack.
 * @param recognizer The tap gesture recogniser on the dimming cover (may be @c nil ).
 * @ghidraAddress 0xa34d8
 */
- (void)handleTapCoverView:(nullable UITapGestureRecognizer *)recognizer;

/**
 * @brief Hides the genre selector by dismissing the presented popover.
 * @param sender The sender; unused.
 * @ghidraAddress 0xa3584
 */
- (void)hideGenreSelect:(nullable id)sender;

/**
 * @brief Back-button handler: stops the carousel, tells the parent to end the store, and cancels
 * pad detail loading.
 * @param sender The bar-button item.
 * @ghidraAddress 0xa3fa8
 */
- (void)handleBackButton:(nullable id)sender;

/**
 * @brief Policy-button handler: presents the terms navigation controller.
 * @param sender The bar-button item; unused.
 * @ghidraAddress 0xa4080
 */
- (void)handleTapPolicyButton:(nullable id)sender;

/**
 * @brief Closes any open alert and the pad detail overlay, then dismisses this controller.
 * @ghidraAddress 0xa67c0
 */
- (void)storeClose;

#pragma mark - StorePackListDelegate

/**
 * @ghidraAddress 0xa40bc
 */
- (void)packListDownloadSuccess:(StorePackListController *)controller
                      isInitial:(BOOL)isInitial
                       showPack:(nullable StorePackInfo *)showPack;

/**
 * @ghidraAddress 0xa5554
 */
- (void)additionPackInfoDownloadSuccess:(StorePackListController *)controller
                               showPack:(nullable StorePackInfo *)showPack;

/**
 * @ghidraAddress 0xa5640
 */
- (void)packListDownloadError:(StorePackListController *)controller
                 errorMessage:(nullable NSString *)errorMessage;

/**
 * @ghidraAddress 0xa58c8
 */
- (void)packListDownloadNothing:(StorePackListController *)controller;

#pragma mark - StorePromotionViewDelegate

/**
 * @ghidraAddress 0xa59b8
 */
- (void)storePromotionView:(StorePromotionView *)view packSelected:(StorePackInfo *)packInfo;

/**
 * @ghidraAddress 0xa59d0
 */
- (void)storePromotionView:(StorePromotionView *)view genreSelected:(NSUInteger)genreIndex;

#pragma mark - StoreGenreSelectViewDelegate

/**
 * @ghidraAddress 0xa5a1c
 */
- (void)StoreGenreSelectViewDelegateGenreSelected:(NSInteger)index;

#pragma mark - Pack table / pack detail callbacks

/**
 * @brief Pack-table load-more callback: fetches the next page for the current genre.
 * @ghidraAddress 0xa5a28
 */
- (void)storePackTableViewLoadMore;

/**
 * @brief Pack-table detail callback: opens a pack's detail.
 * @param packInfo The tapped pack.
 * @ghidraAddress 0xa5a88
 */
- (void)storePackTableViewShowDetail:(nullable StorePackInfo *)packInfo;

/**
 * @brief Pack-detail close callback: dismisses the pad overlay.
 * @ghidraAddress 0xa5a9c
 */
- (void)storePackDetailViewClose;

/**
 * @brief Pack-detail iTunes callback: opens an affiliate product page or the raw URL.
 * @param url The iTunes URL to open.
 * @ghidraAddress 0xa5aac
 */
- (void)storePackDetailViewOpenItunesWithURL:(nullable NSURL *)url;

#pragma mark - Detail-close / recommend tracking

/**
 * @brief Detail-close navigation callback: decrements the open-detail count unless the close was a
 * recommend push.
 * @ghidraAddress 0xa34ac
 */
- (void)detailViewCloseNavigation;

/**
 * @brief Pack-detail purchase callback: records the purchasing view and forwards to the parent.
 * @param packInfo The pack being purchased.
 * @ghidraAddress 0xa0220
 */
- (void)detailViewStartPurchase:(nullable StoreDetailViewControllerV2 *)packInfo;

/**
 * @brief Pack-detail redownload callback: records the redownloading view and forwards to the
 * parent.
 * @param packInfo The pack being redownloaded.
 * @ghidraAddress 0xa0344
 */
- (void)detailViewStartRedownload:(nullable StoreDetailViewControllerV2 *)packInfo;

/**
 * @brief Pack-detail extend-download callback: forwards to the parent store view.
 * @param packInfo The pack being extended.
 * @ghidraAddress 0xa0468
 */
- (void)detailViewStartExtendDownload:(nullable StorePackInfo *)packInfo;

#pragma mark - EditorIDManagerDelegate

/**
 * @ghidraAddress 0xa6fec
 */
- (void)successIDDownload:(nullable id)manager;

/**
 * @ghidraAddress 0xa7064
 */
- (void)errorIDDownload:(nullable id)manager msgStr:(nullable NSString *)msgStr;

#pragma mark - AlertViewManagerDelegate

/**
 * @ghidraAddress 0xa556c
 */
- (void)alertSelect:(nonnull NSDictionary *)info;

#pragma mark - SettingsNavControllerDelegate

/**
 * @ghidraAddress 0xa40a0
 */
- (void)settingsNavViewClose:(nullable id)controller;

#pragma mark - SKStoreProductViewControllerDelegate

/**
 * @ghidraAddress 0xa5c8c
 */
- (void)productViewControllerDidFinish:(SKStoreProductViewController *)viewController;

#pragma mark - UITableViewDataSource / UITableViewDelegate

/**
 * @ghidraAddress 0xa5f7c
 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView;

/**
 * @ghidraAddress 0xa5f84
 */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;

/**
 * @ghidraAddress 0xa5d1c
 */
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath;

/**
 * @ghidraAddress 0xa5fa0
 */
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath;

/**
 * @ghidraAddress 0xa5f9c
 */
- (void)tableView:(UITableView *)tableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath;

/**
 * @ghidraAddress 0xa5fac
 */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;

#pragma mark - View lifecycle

/**
 * @ghidraAddress 0xa605c
 */
- (void)viewWillAppear:(BOOL)animated;

/**
 * @ghidraAddress 0xa61d4
 */
- (void)viewDidAppear:(BOOL)animated;

/**
 * @ghidraAddress 0xa6428
 */
- (void)viewWillDisappear:(BOOL)animated;

/**
 * @ghidraAddress 0xa652c
 */
- (void)viewDidDisappear:(BOOL)animated;

/**
 * @ghidraAddress 0xa6564
 */
- (void)didReceiveMemoryWarning;

/**
 * @ghidraAddress 0xa659c
 */
- (void)viewDidLoad;

/**
 * @ghidraAddress 0xa672c
 */
- (void)viewDidUnload;

/**
 * @ghidraAddress 0xa6e64
 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;

/**
 * @ghidraAddress 0xa6e74
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations;

/**
 * @ghidraAddress 0xa6e7c
 */
- (BOOL)shouldAutorotate;

/**
 * @ghidraAddress 0xa6f64
 */
- (void)dealloc;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
