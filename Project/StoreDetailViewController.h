/**
 * @file
 * The store pack-detail page: a header panel over a table of the pack's tunes, with per-row
 * sample playback, artwork download, in-app purchase, restore, and extend-music download.
 *
 * Reconstructed from Ghidra program Jubeat (class StoreDetailViewController, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIViewController : every @c super call in the class (init, loadView, the
 * lifecycle hooks, and dealloc) targets @c UIViewController , and the controller builds its own
 * @c UITableView ivar and wires itself as that table's data source and delegate — it is not a
 * @c UITableViewController .
 *
 * The screen shows a @c StoreDetailHeaderView as the table header, followed by one
 * @c StoreDetailMusicCell per track and a trailing @c StoreDetailCopyrightCell . Each row can play
 * a downloaded preview through @c AudioManager , download its jacket artwork through a per-row
 * @c ImageDownloader keyed in @c artworkDownloaders , and open its iTunes listing through an
 * @c SKStoreProductViewController . The header's purchase and extend buttons forward to a weak
 * @c delegate ; the navigation-close callbacks forward to a weak @c closeDelegate .
 */

#import <StoreKit/StoreKit.h>
#import <UIKit/UIKit.h>

#import "AlertViewManager.h"
#import "Downloader.h"
#import "ImageDownloader.h"

@class StoreDetailHeaderView;
@class StoreLoadingView;
@class StorePackInfo;

NS_ASSUME_NONNULL_BEGIN

/**
 * Receives the pack-detail page's purchase, redownload, and extend-download actions.
 *
 * Held weakly and dispatched dynamically with @c performSelector:withObject: after a
 * @c respondsToSelector: guard, so every method is optional.
 */
@protocol StoreDetailViewControllerDelegate <NSObject>
@optional
/**
 * Sent when the purchase button is tapped for a pack that is not yet owned.
 * @param packInfo The pack to purchase.
 */
- (void)detailViewStartPurchase:(nullable StorePackInfo *)packInfo;
/**
 * Sent when the purchase button is tapped for an owned pack that must be redownloaded.
 * @param packInfo The pack to redownload.
 */
- (void)detailViewStartRedownload:(nullable StorePackInfo *)packInfo;
/**
 * Sent when the extend-download button is tapped.
 * @param packInfo The pack whose extension should be downloaded.
 */
- (void)detailViewStartExtendDownload:(nullable StorePackInfo *)packInfo;
@end

/**
 * Receives the pack-detail page's navigation-close notification.
 *
 * Held weakly and dispatched dynamically with @c performSelector: after a @c respondsToSelector:
 * guard, so the method is optional.
 */
@protocol StoreDetailViewControllerCloseDelegate <NSObject>
@optional
/**
 * Sent as the page is being dismissed so the owner can tear down its navigation.
 */
- (void)detailViewCloseNavigation;
@end

/**
 * A store pack's detail screen.
 */
@interface StoreDetailViewController : UIViewController <UITableViewDataSource,
                                                         UITableViewDelegate,
                                                         DownloaderDelegate,
                                                         ImageDownloaderDelegate,
                                                         AlertViewManagerDelegate,
                                                         SKStoreProductViewControllerDelegate>

/**
 * The pack being displayed.
 * @ghidraAddress 0xf0c9c (getter)
 * @ghidraAddress 0xf0cac (setter)
 */
@property(nonatomic, strong, nullable) StorePackInfo *packInfo;

/**
 * The action delegate for purchase, redownload, and extend-download. Held weakly.
 * @ghidraAddress 0xf0cc0 (getter)
 * @ghidraAddress 0xf0ce0 (setter)
 */
@property(nonatomic, weak, nullable) id<StoreDetailViewControllerDelegate> delegate;

/**
 * The delegate notified as the page closes its navigation. Held weakly.
 * @ghidraAddress 0xf0cf4 (getter)
 * @ghidraAddress 0xf0d14 (setter)
 */
@property(nonatomic, weak, nullable) id<StoreDetailViewControllerCloseDelegate> closeDelegate;

/**
 * Whether the detail was reached through the restore flow, selecting the restore-pack-info
 * endpoint over the regular one.
 * @ghidraAddress 0xf0d28 (getter)
 * @ghidraAddress 0xf0d38 (setter)
 */
@property(nonatomic) BOOL bRestore;

/**
 * Sets the navigation title and, where available, opts out of opaque-bar layout.
 * @return The initialised controller.
 * @ghidraAddress 0xece2c
 */
- (instancetype)init;

/**
 * Builds the gradient-backed root view, the detail table, the header, the loading overlay,
 * the alternating pack-background art, and the artwork-downloader map.
 * @ghidraAddress 0xecee8
 */
- (void)loadView;

/**
 * Refreshes the purchase button's title, colour, and enabled state, and shows or hides the
 * extend-download button, from the current purchase and download state.
 * @ghidraAddress 0xed604
 */
- (void)updatePurchaseState;

/**
 * Installs the header, refreshes the purchase state, starts the header artwork download,
 * and reveals the table.
 * @ghidraAddress 0xedd68
 */
- (void)showPackInfo;

/**
 * Shows the pack's detail: uses the already-loaded track list, or downloads it through a
 * @c Downloader keyed to the regular or restore endpoint.
 * @ghidraAddress 0xedf64
 */
- (void)loadInfo;

/**
 * Fades out the sample, drops the sample downloader, clears the playing row, and reloads.
 * @ghidraAddress 0xee110
 */
- (void)stopSample;

/**
 * Background-music-finished notification: stops the playing row's sample overlay.
 * @param notification The notification.
 * @ghidraAddress 0xee1a0
 */
- (void)finishBgm:(nullable NSNotification *)notification;

/**
 * Purchase-button tap: forwards purchase or redownload to the delegate.
 * @param sender The purchase button.
 * @ghidraAddress 0xee2ac
 */
- (void)doPurchase:(nullable id)sender;

/**
 * Extend-button tap: hides the button and forwards extend-download to the delegate.
 * @param sender The extend-download button.
 * @ghidraAddress 0xee408
 */
- (void)downloadExtendMusic:(nullable id)sender;

/**
 * Opens an iTunes URL, preferring an @c SKStoreProductViewController when the URL carries
 * affiliate parameters and falling back to the system browser otherwise.
 * @param url The iTunes URL.
 * @ghidraAddress 0xee530
 */
- (void)storeDetailViewOpenItunesWithURL:(nullable NSURL *)url;

/**
 * @c SKStoreProductViewController finish: dismisses it and clears the reference once the
 * dismissal completes.
 * @param viewController The finished product view controller.
 * @ghidraAddress 0xee710
 */
- (void)productViewControllerDidFinish:(nonnull SKStoreProductViewController *)viewController;

/**
 * Downloader completion: parses the pack detail for the info downloader, or loads and plays
 * a preview clip for the sample downloader.
 * @param downloader The finished request.
 * @ghidraAddress 0xee7a0
 */
- (void)downloaderFinished:(nullable id)downloader;

/**
 * Downloader failure: presents a network-error alert, tagged so the info downloader's alert
 * pops the navigation stack.
 * @param downloader The failed request.
 * @ghidraAddress 0xeeb58
 */
- (void)downloaderError:(nullable id)downloader;

/**
 * Downloader progress callback. The shipped body is empty.
 * @param downloader The request.
 * @ghidraAddress 0xeef00
 */
- (void)downloaderProceed:(nullable id)downloader;

/**
 * @c ImageDownloader completion: installs the loaded jacket into a music row, or the header
 * artwork for the header downloader.
 * @param downloader The finished image downloader.
 * @param key The index path the downloader was keyed with.
 * @ghidraAddress 0xf0138
 */
- (void)imageDownloader:(nonnull ImageDownloader *)downloader didLoad:(nullable id)key;

/**
 * Alert button callback: on the confirm button of the info-error alert, pops the navigation
 * stack once.
 * @param info The alert result dictionary carrying @c "btnMessage" and @c "Tag".
 * @ghidraAddress 0xf02ac
 */
- (void)alertSelect:(nonnull NSDictionary *)info;

/**
 * Alert dismissal callback: pops the navigation stack once.
 * @param info The alert result dictionary.
 * @ghidraAddress 0xf040c
 */
- (void)alertClose:(nonnull NSDictionary *)info;

/**
 * Cancels every in-flight artwork downloader, detaches its delegate, and empties the map.
 * @ghidraAddress 0xf0498
 */
- (void)stopDownloadArtworks;

/**
 * Sends @c -detailClose to every cell that answers it so the rows can shut themselves.
 * @ghidraAddress 0xf0b84
 */
- (void)detailClose;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
