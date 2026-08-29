/**
 * @file
 * The store pack-detail card.
 *
 * Reconstructed from Ghidra program Jubeat (class StorePackDetailView, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIView, from the chain-up in @c -initWithFrame: at 0xb03f0 (the super frame
 * is the passed frame with its height extended by 28 points).
 *
 * The card shows one downloaded pack's artwork, name, and comment over a scrolling list of the
 * pack's tune views, with a purchase button, an extend-download button, a related-site link
 * button, a loading overlay, and per-tune sample playback. It acts as a @c DownloaderDelegate for
 * its info fetch and its sample fetch, and as an @c AlertViewManagerDelegate for the link
 * confirmation and the network-error alerts it raises. It is a close sibling of
 * @c CampaignItemDetailView and @c StoreDetailViewController.
 */

#import <UIKit/UIKit.h>

#import "AlertViewManager.h"
#import "Downloader.h"
#import "StoreDetailViewController.h"

@class StorePackInfo;

NS_ASSUME_NONNULL_BEGIN

/**
 * A downloaded pack's detail card.
 */
@interface StorePackDetailView : UIView <DownloaderDelegate, AlertViewManagerDelegate>

/**
 * The pack being shown.
 * @ghidraAddress 0xb4e50 (getter)
 * @ghidraAddress 0xb4e60 (setter)
 */
@property(nonatomic, strong, nullable) StorePackInfo *packInfo;

/**
 * The card's delegate, told when to start a purchase, redownload, or extend download. Held
 * weakly.
 * @ghidraAddress 0xb4e74 (getter)
 * @ghidraAddress 0xb4e94 (setter)
 */
@property(nonatomic, weak, nullable) id<StoreDetailViewControllerDelegate> delegate;

/**
 * The controller that owns this card, messaged to close the card and to open iTunes. Held
 * weakly.
 * @ghidraAddress 0xb4ea8 (getter)
 * @ghidraAddress 0xb4ec8 (setter)
 */
@property(nonatomic, weak, nullable) UIViewController *viewController;

/**
 * Builds the card: the pack background, the pack artwork, the name and comment labels, the
 * copyright text view, the link button, the purchase button, the extend-download button, the
 * scrolling tune list with its four seed tune views, the loading label, and the activity
 * indicator.
 * @param frame The card's frame.
 * @return The initialised card.
 * @ghidraAddress 0xb03c0
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * Clears the pack and returns every subview to its empty state, and unsubscribes from the
 * BGM finish notification.
 * @ghidraAddress 0xb17fc
 */
- (void)removePackInfo;

/**
 * Cancels the in-flight info download, if any.
 * @ghidraAddress 0xb1b3c
 */
- (void)cancelLoading;

/**
 * Stops the sample tune: fades out the BGM, drops the sample downloader, resets every tune
 * view, and clears the playing-row marker.
 * @ghidraAddress 0xb1b88
 */
- (void)stopSample;

/**
 * Refreshes the purchase button's colour, title, and enabled state, and shows or hides the
 * extend-download button, from the pack's purchase state.
 * @ghidraAddress 0xb1d10
 */
- (void)updatePurchaseState;

/**
 * Populates the card from the loaded pack: sizes the tune list, fills the labels and
 * artwork, lays out the link button, starts the artwork downloads, and subscribes to the BGM
 * finish notification. Runs once, guarded by the loaded flag.
 * @ghidraAddress 0xb2374
 */
- (void)showPackInfo;

/**
 * Loads the pack detail: shows it directly when the track list is already present,
 * otherwise starts the info download for the pack.
 * @ghidraAddress 0xb3080
 */
- (void)loadInfo;

/**
 * Loads the pack detail for a restore: like @c -loadInfo but fetches the restore endpoint.
 * @ghidraAddress 0xb329c
 */
- (void)loadRestoreInfo;

/**
 * Purchase-button tap: stops the sample, then asks the delegate to start a redownload or a
 * purchase depending on the pack's ownership.
 * @param sender The purchase button.
 * @ghidraAddress 0xb34b8
 */
- (void)doPurchase:(nullable id)sender;

/**
 * Extend-download-button tap: stops the sample, hides the button, and asks the delegate to
 * start the extend download.
 * @param sender The extend-download button.
 * @ghidraAddress 0xb3614
 */
- (void)downloadExtendMusic:(nullable id)sender;

/**
 * Link-button tap: builds the jump URL and raises a confirmation alert. The pack-level link
 * button confirms opening the related site in Safari; a tune's link button confirms opening the
 * iTunes Store.
 * @param sender The tapped link button.
 * @ghidraAddress 0xb371c
 */
- (void)handleLink:(nullable id)sender;

/**
 * Sample-button tap: toggles the tapped tune's preview. Stops it if already playing,
 * otherwise stops any other playing tune and starts downloading the tapped tune's preview.
 * @param sender The tapped sample button.
 * @ghidraAddress 0xb3d58
 */
- (void)handleSample:(nullable id)sender;

/**
 * BGM-finish notification handler: resets every tune view and clears the playing-row marker.
 * @param notification The notification.
 * @ghidraAddress 0xb41a8
 */
- (void)finishBgm:(nullable NSNotification *)notification;

/**
 * @c Downloader completion: parses the pack detail on the info download, or loads and plays
 * the preview on the sample download.
 * @param downloader The finished request.
 * @ghidraAddress 0xb42e0
 */
- (void)downloaderFinished:(id)downloader;

/**
 * @c Downloader failure: raises a network-error alert for the info or sample download.
 * @param downloader The failed request.
 * @ghidraAddress 0xb4684
 */
- (void)downloaderError:(id)downloader;

/**
 * @c Downloader progress. The shipped body is empty.
 * @param downloader The request.
 * @ghidraAddress 0xb4a64
 */
- (void)downloaderProceed:(id)downloader;

/**
 * Alert-button delegate: on the server-error alert closes the card; on the link alert opens
 * iTunes with the jump URL when the confirm button was tapped.
 * @param info The alert result dictionary.
 * @ghidraAddress 0xb4a68
 */
- (void)alertSelect:(nonnull NSDictionary *)info;

/**
 * Alert-dismiss delegate: on the server-error alert tells the owning controller to close.
 * @param info The alert result dictionary.
 * @ghidraAddress 0xb4c54
 */
- (void)alertClose:(nonnull NSDictionary *)info;

/**
 * Closes any presented alert.
 * @ghidraAddress 0xb4d50
 */
- (void)detailClose;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
