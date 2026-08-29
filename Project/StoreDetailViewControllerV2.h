/**
 * @file
 * @brief The store pack-detail page, the V2 (recommend-aware, relation-tab) variant.
 *
 * Reconstructed from Ghidra program Jubeat (class StoreDetailViewControllerV2, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIViewController : every @c super call in the class (init, loadView, the
 * lifecycle hooks, and dealloc) targets @c UIViewController , and the controller builds its own
 * tables as ivars and wires itself as their data source and delegate — it is not a
 * @c UITableViewController .
 *
 * Unlike @c StoreDetailViewController this variant keeps three parallel copies of a
 * @c StoreDetailHeaderViewV2 in @c headerViewArray , one mounted as the table header of each of the
 * three tables it owns: the tune list (@c detailTableView , tag 2), the recommended-pack list
 * (@c recommendPackTableView ), and a spare header carrier (@c tmpHeaderTable , tag 3). Each header
 * carries a relation-tab strip; tapping a tab cross-fades the visible table through the
 * @c -tapRelationButton: four-stage animation chain. The recommended-pack list is fetched through a
 * signed @c SessionDownloader against @c +[ScratchUtil recommendPackListURL] , and the packs it
 * names are resolved to @c StorePackInfo through an @c SKProductsRequest .
 *
 * Each tune row can play a downloaded preview through @c AudioManager , download its jacket artwork
 * through a per-row @c ImageDownloader keyed in @c artworkDownloaders , and open its iTunes listing
 * through an @c SKStoreProductViewController . The header's purchase and extend buttons forward to
 * a weak @c delegate ; the navigation-close callback forwards to a weak @c closeDelegate .
 */

#import <StoreKit/StoreKit.h>
#import <UIKit/UIKit.h>

#import "AlertViewManager.h"
#import "Downloader.h"
#import "ImageDownloader.h"

@class StoreDetailViewControllerV2;
@class StorePackInfo;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Receives the pack-detail page's purchase, redownload, and extend-download actions.
 *
 * Held weakly and dispatched dynamically with @c performSelector:withObject: after a
 * @c respondsToSelector: guard, so every method is optional. The purchase and redownload callbacks
 * are handed the detail controller itself; the extend callback is handed the pack.
 */
@protocol StoreDetailViewControllerV2Delegate <NSObject>
@optional
/**
 * @brief Sent when the purchase button is tapped for a pack that is not yet owned.
 * @param controller The detail controller reporting the purchase.
 */
- (void)detailViewStartPurchase:(nullable StoreDetailViewControllerV2 *)controller;
/**
 * @brief Sent when the purchase button is tapped for an owned pack that must be redownloaded.
 * @param controller The detail controller reporting the redownload.
 */
- (void)detailViewStartRedownload:(nullable StoreDetailViewControllerV2 *)controller;
/**
 * @brief Sent when the extend-download button is tapped.
 * @param packInfo The pack whose extension should be downloaded.
 */
- (void)detailViewStartExtendDownload:(nullable StorePackInfo *)packInfo;
@end

/**
 * @brief Receives the pack-detail page's navigation-close notification.
 *
 * Held weakly and dispatched dynamically with @c performSelector: after a @c respondsToSelector:
 * guard, so the method is optional.
 */
@protocol StoreDetailViewControllerV2CloseDelegate <NSObject>
@optional
/**
 * @brief Sent as the page is being dismissed so the owner can tear down its navigation.
 */
- (void)detailViewCloseNavigation;
@end

/**
 * @brief A store pack's detail screen (version 2).
 */
@interface StoreDetailViewControllerV2 : UIViewController <UITableViewDataSource,
                                                           UITableViewDelegate,
                                                           DownloaderDelegate,
                                                           ImageDownloaderDelegate,
                                                           AlertViewManagerDelegate,
                                                           SKProductsRequestDelegate,
                                                           SKStoreProductViewControllerDelegate>

/**
 * @brief The pack being displayed.
 * @ghidraAddress 0xe2b74 (getter)
 * @ghidraAddress 0xe2b84 (setter)
 */
@property(nonatomic, strong, nullable) StorePackInfo *packInfo;

/**
 * @brief The action delegate for purchase, redownload, and extend-download. Held weakly.
 * @ghidraAddress 0xe2b98 (getter)
 * @ghidraAddress 0xe2bb8 (setter)
 */
@property(nonatomic, weak, nullable) id<StoreDetailViewControllerV2Delegate> delegate;

/**
 * @brief The delegate notified as the page closes its navigation. Held weakly.
 * @ghidraAddress 0xe2bcc (getter)
 * @ghidraAddress 0xe2bec (setter)
 */
@property(nonatomic, weak, nullable) id<StoreDetailViewControllerV2CloseDelegate> closeDelegate;

/**
 * @brief Whether the detail was reached through the restore flow, selecting the restore-pack-info
 * endpoint over the regular one.
 * @ghidraAddress 0xe2c00 (getter)
 * @ghidraAddress 0xe2c10 (setter)
 */
@property(nonatomic) BOOL bRestore;

/**
 * @brief Sets the navigation title and, where available, opts out of opaque-bar layout.
 * @return The initialised controller.
 * @ghidraAddress 0xdc94c
 */
- (instancetype)init;

/**
 * @brief Builds the gradient-backed root view, the three tables (tune list, recommended-pack list,
 * and spare header carrier), the three relation-strip headers, the loading overlay, the alternating
 * pack-background art, and the artwork-downloader map.
 * @ghidraAddress 0xdca08
 */
- (void)loadView;

/**
 * @brief Refreshes each header's purchase button title, colour, and enabled state, and shows or
 * hides the extend-download button, from the current purchase and download state.
 * @ghidraAddress 0xdd47c
 */
- (void)updatePurchaseState;

/**
 * @brief Installs the headers, refreshes the purchase state, starts the header artwork download,
 * reveals the tables, and fetches the recommended-pack list.
 * @ghidraAddress 0xde248
 */
- (void)showPackInfo;

/**
 * @brief Shows the pack's detail: uses the already-loaded track list, or downloads it through a
 * @c Downloader keyed to the regular or restore endpoint.
 * @ghidraAddress 0xde7d4
 */
- (void)loadInfo;

/**
 * @brief Fades out the sample, drops the sample downloader, clears the playing row, and reloads.
 * @ghidraAddress 0xde980
 */
- (void)stopSample;

/**
 * @brief Background-music-finished notification: stops the playing row's sample overlay.
 * @param notification The notification.
 * @ghidraAddress 0xdea10
 */
- (void)finishBgm:(nullable NSNotification *)notification;

/**
 * @brief Purchase-button tap: forwards purchase or redownload to the delegate.
 * @param sender The purchase button.
 * @ghidraAddress 0xdeb1c
 */
- (void)doPurchase:(nullable id)sender;

/**
 * @brief Extend-button tap: hides the button on every header and forwards extend-download to the
 * delegate.
 * @param sender The extend-download button.
 * @ghidraAddress 0xdec34
 */
- (void)downloadExtendMusic:(nullable id)sender;

/**
 * @brief Opens an iTunes URL, preferring an @c SKStoreProductViewController when the URL carries
 * affiliate parameters and falling back to the system browser otherwise.
 * @param url The iTunes URL.
 * @ghidraAddress 0xdee30
 */
- (void)storeDetailViewOpenItunesWithURL:(nullable NSURL *)url;

/**
 * @brief @c SKStoreProductViewController finish: dismisses it and clears the reference once the
 * dismissal completes.
 * @param viewController The finished product view controller.
 * @ghidraAddress 0xdf010
 */
- (void)productViewControllerDidFinish:(nonnull SKStoreProductViewController *)viewController;

/**
 * @brief Downloader completion: parses the pack detail for the info downloader, loads and plays a
 * preview clip for the sample downloader, or resolves the recommended-pack products for the
 * recommend downloader.
 * @param downloader The finished request.
 * @ghidraAddress 0xdf0a0
 */
- (void)downloaderFinished:(nullable id)downloader;

/**
 * @brief Downloader failure: presents a network-error alert, tagged so the info downloader's alert
 * pops the navigation stack.
 * @param downloader The failed request.
 * @ghidraAddress 0xdf994
 */
- (void)downloaderError:(nullable id)downloader;

/**
 * @brief Downloader progress callback. The shipped body is empty.
 * @param downloader The request.
 * @ghidraAddress 0xdfd3c
 */
- (void)downloaderProceed:(nullable id)downloader;

/**
 * @brief @c ImageDownloader completion: installs the loaded jacket into a music row, or the header
 * artwork on all three headers for the header downloader.
 * @param downloader The finished image downloader.
 * @param key The index path the downloader was keyed with.
 * @ghidraAddress 0xe0f9c
 */
- (void)imageDownloader:(nonnull ImageDownloader *)downloader didLoad:(nullable id)key;

/**
 * @brief Alert button callback: on the confirm button of the info-error alert, pops the navigation
 * stack once.
 * @param info The alert result dictionary carrying @c "btnMessage" and @c "Tag".
 * @ghidraAddress 0xe11f0
 */
- (void)alertSelect:(nonnull NSDictionary *)info;

/**
 * @brief Alert dismissal callback: pops the navigation stack once.
 * @param info The alert result dictionary.
 * @ghidraAddress 0xe1350
 */
- (void)alertClose:(nonnull NSDictionary *)info;

/**
 * @brief Cancels every in-flight artwork downloader, detaches its delegate, and empties the map.
 * @ghidraAddress 0xe13dc
 */
- (void)stopDownloadArtworks;

/**
 * @brief Sends @c -detailClose to every cell that answers it so the rows can shut themselves.
 * @ghidraAddress 0xe1c30
 */
- (void)detailClose;

/**
 * @brief Relation-tab tap: cross-fades between the tune list and the recommended-pack list, snaps
 * their scroll positions, and recolours the tab strips.
 * @param sender The tapped relation-tab button, whose tag names the list to show.
 * @ghidraAddress 0xe1d48
 */
- (void)tapRelationButton:(nullable id)sender;

/**
 * @brief @c SKProductsRequestDelegate callback: caches the store country, resolves the recommended
 * packs against the returned products, hands them to the recommend table, and re-enables the tab
 * strips.
 * @param request The finished products request.
 * @param response The returned products.
 * @ghidraAddress 0xe24b4
 */
- (void)productsRequest:(nonnull SKProductsRequest *)request
     didReceiveResponse:(nonnull SKProductsResponse *)response;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
