/**
 * @file
 * @brief The campaign-detail page: a table with a campaign header, the item's terms and licence,
 * and the artwork it downloads.
 *
 * Reconstructed from Ghidra program Jubeat (class CampaignDetailViewController, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIViewController, from the chain-up in @c -init at 0x1e8b40. The controller
 * hosts a @c CampaignItemInfo, shows it through a @c CampaignDetailHeaderView table header, and
 * offers two extra rows: the item's unlock terms and its licence text. It acts as the header's
 * delegate (forwarding purchase and link taps to its owning @c StoreCampaignViewController), as an
 * @c ImageDownloader delegate for the item artwork, as an @c SKStoreProductViewController delegate
 * for iTunes items, and as the table's own data source and delegate.
 */

#import <StoreKit/StoreKit.h>
#import <UIKit/UIKit.h>

#import "CampaignDetailHeaderView.h"
#import "ImageDownloader.h"

@class CampaignItemInfo;
@class StoreCampaignViewController;

NS_ASSUME_NONNULL_BEGIN

@class CampaignDetailViewController;

/**
 * @brief Receives the campaign-detail page's lifecycle callbacks.
 *
 * The delegate is held weakly and dispatched dynamically; the binary records no methods for it.
 */
@protocol CampaignDetailViewControllerDelegate <NSObject>

@optional

@end

/**
 * @brief A campaign item's detail page.
 */
@interface CampaignDetailViewController : UIViewController <CampaignDetailHeaderViewDelegate,
                                                            ImageDownloaderDelegate,
                                                            SKStoreProductViewControllerDelegate,
                                                            UITableViewDataSource,
                                                            UITableViewDelegate>

/**
 * @brief The page's delegate. Held weakly.
 * @ghidraAddress 0x1ea3ac (getter)
 * @ghidraAddress 0x1ea3cc (setter)
 */
@property(nonatomic, weak, nullable) id<CampaignDetailViewControllerDelegate> delegate;

/**
 * @brief The store campaign controller that owns this page. Held weakly.
 * @ghidraAddress 0x1ea3e0 (getter)
 * @ghidraAddress 0x1ea400 (setter)
 */
@property(nonatomic, weak, nullable) StoreCampaignViewController *viewController;

/**
 * @brief Sets the navigation title and, where available, opts out of opaque-bar layout.
 * @return The initialised controller.
 * @ghidraAddress 0x1e8b40
 */
- (instancetype)init;

/**
 * @brief Builds the gradient-backed root view, the pack-background art, the detail table, the
 * campaign header, the loading overlay, and the terms and copyright labels.
 * @ghidraAddress 0x1e8bfc
 */
- (void)loadView;

/**
 * @brief Stores the campaign item to display.
 * @param campaignInfo The campaign item.
 * @ghidraAddress 0x1e9430
 */
- (void)setCampaignInfo:(nullable CampaignItemInfo *)campaignInfo;

/**
 * @brief Clears the stored campaign item.
 * @ghidraAddress 0x1e9444
 */
- (void)removeCampaignInfo;

/**
 * @brief Replaces the campaign item and forwards it to the header.
 * @param campaignInfo The new campaign item.
 * @ghidraAddress 0x1e945c
 */
- (void)updateCampaignState:(nullable CampaignItemInfo *)campaignInfo;

/**
 * @brief Swaps in a fresh campaign item: cancels the artwork download, stops the sample, reloads
 * the info, and reloads the table.
 * @param campaignInfo The new campaign item.
 * @ghidraAddress 0x1e94bc
 */
- (void)refreshCampaignItem:(nullable CampaignItemInfo *)campaignInfo;

/**
 * @brief Navigates to the pack info. The shipped body is empty.
 * @ghidraAddress 0x1e9564
 */
- (void)showPackInfo;

/**
 * @brief Populates the header and table from the current item, downloads the artwork, and sizes
 * the terms and licence labels to their text.
 * @ghidraAddress 0x1e9568
 */
- (void)loadInfo;

/**
 * @brief Header download-button tap: forwards to the owning controller's item download.
 * @param sender The download button.
 * @ghidraAddress 0x1e9800
 */
- (void)doPurchase:(nullable id)sender;

/**
 * @brief Header link-button tap: forwards to the owning controller's external link.
 * @param sender The link button.
 * @ghidraAddress 0x1e9840
 */
- (void)handleLink:(nullable id)sender;

/**
 * @brief SKStoreProductViewController finish: dismisses it, then clears the reference once the
 * dismissal animation completes.
 * @param viewController The finished product view controller.
 * @ghidraAddress 0x1e9880
 */
- (void)productViewControllerDidFinish:(nonnull SKStoreProductViewController *)viewController;

/**
 * @brief Downloader progress callback. The shipped body is empty.
 * @param downloader The request.
 * @ghidraAddress 0x1e9910
 */
- (void)downloaderProceed:(nullable id)downloader;

/**
 * @brief Cancels the artwork download and detaches its delegate.
 * @ghidraAddress 0x1e9dbc
 */
- (void)stopDownloadArtworks;

/**
 * @brief Tears down the view references and cancels the artwork download.
 * @ghidraAddress 0x1e9d30
 */
- (void)removeItem;

/**
 * @brief Sends @c -detailClose to every cell that answers it, so the table can shut its rows.
 * @ghidraAddress 0x1ea294
 */
- (void)detailClose;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
