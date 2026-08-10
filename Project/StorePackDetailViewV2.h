/** @file
 * The store pack-detail card, the V2 (relation-tab, recommend-aware) variant.
 *
 * Reconstructed from Ghidra program Jubeat (class StorePackDetailViewV2, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIView : the chain-up in @c -initWithFrame: at 0x1dbf70 targets
 * @c UIView , and @c -dealloc chains to @c -[UIView dealloc] . Unlike the phone card the frame is
 * passed through to @c super unchanged (no height extension), and there is no @c IsPad() or theme
 * branch anywhere in the class.
 *
 * The card shows one downloaded pack's artwork, name, and comment, and switches between two lists
 * through a relation-tab strip: the pack's own tune views (backed by @c musicViewBg ) and a list of
 * recommended packs (backed by @c packViewBg and rendered by @c recommendPackTableView ). Tapping a
 * tab cross-fades the two backing scroll views through the @c -setRelationColor:animate: two-leg
 * animation. The recommended-pack list is fetched through a signed @c SessionDownloader against
 * @c +[ScratchUtil recommendPackListURL] , and the packs it names are resolved to @c StorePackInfo
 * through an @c SKProductsRequest .
 *
 * It acts as a @c DownloaderDelegate for its info fetch, its sample fetch, and its recommend fetch,
 * as an @c AlertViewManagerDelegate for the link confirmation and the network-error alerts it
 * raises, and as an @c SKProductsRequestDelegate for the recommended-pack product resolution. It is
 * a close sibling of @c StorePackDetailView and @c StoreDetailViewControllerV2 .
 */

#import <StoreKit/StoreKit.h>
#import <UIKit/UIKit.h>

#import "AlertViewManager.h"
#import "Downloader.h"

@class StorePackInfo;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A downloaded pack's detail card (version 2).
 */
@interface StorePackDetailViewV2
    : UIView <DownloaderDelegate, AlertViewManagerDelegate, SKProductsRequestDelegate>

/**
 * @brief The pack being shown.
 * @ghidraAddress 0x1e2714 (getter)
 * @ghidraAddress 0x1e2724 (setter)
 */
@property(nonatomic, strong, nullable) StorePackInfo *packInfo;

/**
 * @brief The card's delegate, told when to start a purchase, redownload, or extend download, and
 * asked to pop the detail list. Held weakly and dispatched dynamically, so the binary types it as a
 * bare @c id .
 * @ghidraAddress 0x1e2738 (getter)
 * @ghidraAddress 0x1e2758 (setter)
 */
@property(nonatomic, weak, nullable) id delegate;

/**
 * @brief The controller that owns this card, messaged to close the card and to open iTunes. Held
 * weakly.
 * @ghidraAddress 0x1e276c (getter)
 * @ghidraAddress 0x1e278c (setter)
 */
@property(nonatomic, weak, nullable) UIViewController *viewController;

/**
 * @brief Builds the card: the pack background and artwork, the name and comment labels, the
 * copyright text view, the relation-tab strip with its two tabs, the link button, the purchase and
 * extend-download buttons, the tune scroll view with its four seed tune views, the recommended-pack
 * table with its backing scroll view, the loading overlay, and the right-half back button.
 * @param frame The card's frame.
 * @return The initialised card.
 * @ghidraAddress 0x1dbf70
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Clears the pack and returns every subview to its empty state, resets the relation strip,
 * disables the relation buttons, and unsubscribes from the BGM finish notification.
 * @ghidraAddress 0x1dd9bc
 */
- (void)removePackInfo;

/**
 * @brief Relation-tab tap: switches the visible list to the tapped tab and cross-fades the backing
 * scroll views.
 * @param sender The tapped relation-tab button, whose tag names the list to show.
 * @ghidraAddress 0x1dddd4
 */
- (void)tapRelationButton:(nullable id)sender;

/**
 * @brief Recolours the relation strip for the given list index and shows or hides the backing
 * scroll views outright (no animation).
 * @param color The list index to select.
 * @param selectable Whether the non-selected tab is offered as selectable.
 * @ghidraAddress 0x1dde3c
 */
- (void)setRelationColor:(int)color selectable:(BOOL)selectable;

/**
 * @brief Recolours the relation strip for the given list index and, when animating, cross-fades the
 * two backing scroll views over two legs.
 * @param color The list index to select.
 * @param animate Whether to cross-fade the backing scroll views.
 * @ghidraAddress 0x1de130
 */
- (void)setRelationColor:(int)color animate:(BOOL)animate;

/**
 * @brief Cancels the in-flight info download, if any.
 * @ghidraAddress 0x1de7fc
 */
- (void)cancelLoading;

/**
 * @brief Stops the sample tune: fades out the BGM, drops the sample downloader, resets every tune
 * view, and clears the playing-row marker.
 * @ghidraAddress 0x1de848
 */
- (void)stopSample;

/**
 * @brief Refreshes the purchase button's colour, title, and enabled state, shows or hides the
 * extend-download button from the pack's purchase state, and reloads the recommended-pack table.
 * @ghidraAddress 0x1de9d0
 */
- (void)updatePurchaseState;

/**
 * @brief Populates the card from the loaded pack: sizes the tune list, fills the labels and
 * artwork, lays out the link button, starts the artwork downloads, kicks off the recommended-pack
 * fetch, and subscribes to the BGM finish notification. Runs once, guarded by the loaded flag.
 * @ghidraAddress 0x1df04c
 */
- (void)showPackInfo;

/**
 * @brief Loads the pack detail: shows it directly when the track list is already present,
 * otherwise starts the info download for the pack.
 * @ghidraAddress 0x1dfef8
 */
- (void)loadInfo;

/**
 * @brief Loads the pack detail for a restore: like @c -loadInfo but fetches the restore endpoint.
 * @ghidraAddress 0x1e0114
 */
- (void)loadRestoreInfo;

/**
 * @brief Purchase-button tap: stops the sample, then asks the delegate to start a redownload or a
 * purchase depending on the pack's ownership. The card forwards itself to the delegate.
 * @param sender The purchase button.
 * @ghidraAddress 0x1e0330
 */
- (void)doPurchase:(nullable id)sender;

/**
 * @brief Extend-download-button tap: stops the sample, hides the button, and asks the delegate to
 * start the extend download.
 * @param sender The extend-download button.
 * @ghidraAddress 0x1e0448
 */
- (void)downloadExtendMusic:(nullable id)sender;

/**
 * @brief Link-button tap: builds the jump URL and raises a confirmation alert. The pack-level link
 * button confirms opening the related site in Safari; a tune's link button confirms opening the
 * iTunes Store.
 * @param sender The tapped link button.
 * @ghidraAddress 0x1e0550
 */
- (void)handleLink:(nullable id)sender;

/**
 * @brief Sample-button tap: toggles the tapped tune's preview. Stops it if already playing,
 * otherwise stops any other playing tune and starts downloading the tapped tune's preview.
 * @param sender The tapped sample button.
 * @ghidraAddress 0x1e0b8c
 */
- (void)handleSample:(nullable id)sender;

/**
 * @brief BGM-finish notification handler: resets every tune view and clears the playing-row marker.
 * @param notification The notification.
 * @ghidraAddress 0x1e0fdc
 */
- (void)finishBgm:(nullable NSNotification *)notification;

/**
 * @brief @c Downloader completion: parses the pack detail on the info download, loads and plays the
 * preview on the sample download, or resolves the recommended-pack products on the recommend
 * download.
 * @param downloader The finished request.
 * @ghidraAddress 0x1e1114
 */
- (void)downloaderFinished:(id)downloader;

/**
 * @brief @c Downloader failure: raises a network-error alert for the info or sample download.
 * @param downloader The failed request.
 * @ghidraAddress 0x1e1828
 */
- (void)downloaderError:(id)downloader;

/**
 * @brief @c Downloader progress. The shipped body is empty.
 * @param downloader The request.
 * @ghidraAddress 0x1e1c08
 */
- (void)downloaderProceed:(id)downloader;

/**
 * @brief Alert-button delegate: on the server-error alert closes the card; on the link alert opens
 * iTunes with the jump URL when the confirm button was tapped.
 * @param info The alert result dictionary.
 * @ghidraAddress 0x1e1c0c
 */
- (void)alertSelect:(nonnull NSDictionary *)info;

/**
 * @brief Alert-dismiss delegate: on the server-error alert tells the owning controller to close.
 * @param info The alert result dictionary.
 * @ghidraAddress 0x1e1df8
 */
- (void)alertClose:(nonnull NSDictionary *)info;

/**
 * @brief Closes any presented alert.
 * @ghidraAddress 0x1e1ef4
 */
- (void)detailClose;

/**
 * @brief Marks the card inactive by re-adding the right-half back button over it.
 * @ghidraAddress 0x1e1f3c
 */
- (void)setInactive;

/**
 * @brief Marks the card active by removing the right-half back button.
 * @ghidraAddress 0x1e1f54
 */
- (void)setActive;

/**
 * @brief Back-button tap: asks the delegate to pop the detail list.
 * @ghidraAddress 0x1e1f6c
 */
- (void)popOutDetailView;

/**
 * @brief @c SKProductsRequestDelegate callback: caches the store country, resolves the recommended
 * packs against the returned products, hands them to the recommend table, and re-enables the tab
 * strip.
 * @param request The finished products request.
 * @param response The returned products.
 * @ghidraAddress 0x1e201c
 */
- (void)productsRequest:(nonnull SKProductsRequest *)request
     didReceiveResponse:(nonnull SKProductsResponse *)response;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
