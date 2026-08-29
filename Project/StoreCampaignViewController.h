/**
 * @file
 * The store's campaign (privilege / gift) screen.
 *
 * Reconstructed from Ghidra program Jubeat (class StoreCampaignViewController, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIViewController : every @c super call in the class targets
 * @c UIViewController , and the controller builds its own @c UITableView ivar, wires itself as that
 * table's data source and delegate, and adds it as a subview. It is not a
 * @c UITableViewController .
 *
 * The screen lists downloadable campaign items (unlockable tunes and markers), one banner per row.
 * Tapping a row opens a detail card: on the phone a pushed @c CampaignDetailViewController , on the
 * pad an in-place @c CampaignItemDetailView faded in over a dimming cover. It fetches the campaign
 * list, per-item info, serial checks, and marker data through @c Downloader instances, drives pack
 * downloads through a @c StoreDownloadManager , and reports progress through the parent
 * @c StoreViewController 's modal dialog. Artwork is downloaded off the main thread through an
 * @c NSOperationQueue and cached in an @c NSCache .
 */

#import <UIKit/UIKit.h>

#import "AlertViewManager.h"
#import "Downloader.h"
#import "StoreDialogView.h"
#import "StoreDownloadManager.h"
#import "StoreParentViewController.h"

@class StoreViewController;

NS_ASSUME_NONNULL_BEGIN

/**
 * Lists downloadable campaign items and drives their unlock, download, and detail display.
 */
@interface StoreCampaignViewController : UIViewController <UITableViewDataSource,
                                                           UITableViewDelegate,
                                                           DownloaderDelegate,
                                                           StoreDownloadManagerDelegate,
                                                           AlertViewManagerDelegate,
                                                           StoreDialogViewDelegate>

/**
 * Builds the controller for a parent store view.
 *
 * Sets the navigation and tab-bar titles, loads the tab image, installs a back button targeting the
 * parent, caches the device idiom, creates the artwork cache, operation queue, and
 * download-tracking list, and kicks off the campaign-list download.
 * @param parent The owning @c StoreViewController ; held weakly.
 * @return The initialised controller.
 * @ghidraAddress 0xbe580
 */
- (instancetype)initWithParent:(nullable id<StoreParentViewController>)parent;

/**
 * Builds the view: a full-bounds vertical gradient, a non-selectable table, a loading
 * overlay, and — on the pad only — a dimming cover and an in-place detail card.
 * @ghidraAddress 0xbe8ec
 */
- (void)loadView;

/**
 * Posts the campaign-list request and starts its @c Downloader .
 * @ghidraAddress 0xbf074
 */
- (void)downloadCampaignList;

/**
 * Vends and lays out a banner row for a campaign item, installing cached artwork when ready.
 * @param aTableView The table asking.
 * @param indexPath The row's index path.
 * @return The banner cell for the campaign item.
 * @ghidraAddress 0xbf344
 */
- (UITableViewCell *)tableView:(UITableView *)aTableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath;

/**
 * The number of campaign items.
 * @param aTableView The table asking.
 * @param section The section asked about.
 * @return The campaign-item count, or 0 before the list has been fetched.
 * @ghidraAddress 0xbf770
 */
- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section;

/**
 * Clears each cell's background before display.
 * @param aTableView The table asking.
 * @param cell The cell about to be drawn.
 * @param indexPath The row's index path.
 * @ghidraAddress 0xbf790
 */
- (void)tableView:(UITableView *)aTableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath;

/**
 * Always one section.
 * @param aTableView The table asking.
 * @return Always 1.
 * @ghidraAddress 0xbf800
 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)aTableView;

/**
 * The row height for the device idiom.
 * @param aTableView The table asking.
 * @param indexPath The row's index path.
 * @return The campaign cell height for the current idiom.
 * @ghidraAddress 0xbf808
 */
- (CGFloat)tableView:(UITableView *)aTableView heightForRowAtIndexPath:(NSIndexPath *)indexPath;

/**
 * Pad cover-view tap: fades out the detail card and cover, then tears them down.
 * @param recognizer The tap gesture recogniser.
 * @ghidraAddress 0xbf82c
 */
- (void)handleTapCoverView:(nullable UITapGestureRecognizer *)recognizer;

/**
 * Opens the campaign banner's external link for a tapped cell.
 * @param sender The cell's button, whose tag is the row index.
 * @ghidraAddress 0xbfc60
 */
- (void)pushExternalLink:(nullable id)sender;

/**
 * Opens the detail for a row: pushes a @c CampaignDetailViewController on the phone or fades
 * in the in-place card on the pad.
 * @param index The row index.
 * @ghidraAddress 0xbfd60
 */
- (void)selectItem:(int)index;

/**
 * Cell-button tap: on the pad, fades in the in-place detail card for the tapped row.
 * @param sender The cell's button, whose tag is the row index.
 * @ghidraAddress 0xc0230
 */
- (void)pushCellButton:(nullable id)sender;

/**
 * Opens the working row's external link.
 * @ghidraAddress 0xc060c
 */
- (void)moveExternalLink;

/**
 * Starts the download flow for the working item, branching on its button type.
 * @ghidraAddress 0xc06f0
 */
- (void)itemDownload;

/**
 * Shows the "unlock terms" informational alert.
 * @param sender The button that requested it.
 * @ghidraAddress 0xc0a04
 */
- (void)displayTerm:(nullable id)sender;

/**
 * Shows the "an app update is required to unlock this tune" alert.
 * @ghidraAddress 0xc0ae8
 */
- (void)displayUpdateAlert;

/**
 * Alert-button handler: on the serial-code alert, posts a serial check; on the update alert,
 * opens the App Store page.
 * @param info The alert-result dictionary.
 * @ghidraAddress 0xc0c4c
 */
- (void)alertSelect:(NSDictionary *)info;

/**
 * Downloader completion: dispatches by the finished request (campaign list, item info,
 * serial check, or marker data) and advances the unlock/download flow.
 * @param downloader The finished request.
 * @ghidraAddress 0xc1094
 */
- (void)downloaderFinished:(id)downloader;

/**
 * Downloader failure: shows the appropriate error alert and clears the request.
 * @param downloader The failed request.
 * @ghidraAddress 0xc22ec
 */
- (void)downloaderError:(id)downloader;

/**
 * The modal dialog's abort button was pressed: cancel the info fetch and pack download, then
 * dismiss.
 * @param dialogView The dialog.
 * @ghidraAddress 0xc27cc
 */
- (void)storeDialogCancel:(id)dialogView;

/**
 * A pack download task started: set the dialog's message.
 * @param manager The download manager.
 * @ghidraAddress 0xc28cc
 */
- (void)downloadManagerStartTask:(StoreDownloadManager *)manager;

/**
 * The pack download completed: re-evaluate the item, dismiss the dialog, and refresh.
 * @param manager The download manager.
 * @ghidraAddress 0xc2ae4
 */
- (void)downloadManagerCompleted:(StoreDownloadManager *)manager;

/**
 * The pack download failed: show an error alert, refresh, and dismiss.
 * @param manager The download manager.
 * @ghidraAddress 0xc2b94
 */
- (void)downloadManagerFailed:(StoreDownloadManager *)manager;

/**
 * A download task made progress: drive the dialog's progress bar from the marker or pack
 * download depending on the item type.
 * @param manager The download manager.
 * @ghidraAddress 0xc2d7c
 */
- (void)downloadManagerProceed:(StoreDownloadManager *)manager;

/**
 * Closes any open alert.
 * @ghidraAddress 0xc2eac
 */
- (void)storeClose;

/**
 * Rebuilds the unlock table and refreshes the music list.
 * @ghidraAddress 0xc2ef4
 */
- (void)reloadUnlockList;

/**
 * The cached artwork for a campaign item, queuing a background download when it is missing.
 * @param info The campaign item.
 * @return The cached image, or nil while it downloads.
 * @ghidraAddress 0xc2f28
 */
- (nullable UIImage *)getArtwork:(nullable id)info;

/**
 * Ensures every item's artwork is fetched, then reloads the table.
 * @ghidraAddress 0xc3168
 */
- (void)refreshMusicList;

/**
 * Rebuilds the displayed item list from the server unlock-check list, deduplicating by
 * campaign and honouring the hide flag, then updates the badge and opens any pending start-up item.
 * @ghidraAddress 0xc325c
 */
- (void)refreshUnlockTable;

/**
 * Recomputes the tab badge count from the newly-unlocked items.
 * @ghidraAddress 0xc369c
 */
- (void)refreshUnlockBadge;

/**
 * Sets the tab-bar badge to a count, clearing it when zero or negative.
 * @param count The badge count.
 * @ghidraAddress 0xc37e4
 */
- (void)setBadgeCnt:(int)count;

/**
 * Chains to super; the override adds nothing of its own.
 * @ghidraAddress 0xc388c
 */
- (void)didReceiveMemoryWarning;

/**
 * Makes the navigation bar and its subviews exclusive-touch.
 * @ghidraAddress 0xc38c4
 */
- (void)viewDidLoad;

/**
 * Drops the table view reference when the view is unloaded.
 * @ghidraAddress 0xc3aa4
 */
- (void)viewDidUnload;

/**
 * The view is about to appear.
 * @param animated Whether the appearance is animated.
 * @ghidraAddress 0xc3afc
 */
- (void)viewWillAppear:(BOOL)animated;

/**
 * The view has appeared.
 * @param animated Whether the appearance was animated.
 * @ghidraAddress 0xc3b78
 */
- (void)viewDidAppear:(BOOL)animated;

/**
 * The view is about to disappear.
 * @param animated Whether the disappearance is animated.
 * @ghidraAddress 0xc3bd4
 */
- (void)viewWillDisappear:(BOOL)animated;

/**
 * The view has disappeared.
 * @param animated Whether the disappearance was animated.
 * @ghidraAddress 0xc3c5c
 */
- (void)viewDidDisappear:(BOOL)animated;

/**
 * Whether the screen may rotate to an orientation.
 * @param interfaceOrientation The orientation asked about.
 * @return YES for the two portrait orientations, NO otherwise.
 * @ghidraAddress 0xc3c94
 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;

/**
 * The orientations the screen supports.
 * @return Both portrait orientations.
 * @ghidraAddress 0xc3ca4
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations;

/**
 * Whether the screen rotates.
 * @return Always YES.
 * @ghidraAddress 0xc3cac
 */
- (BOOL)shouldAutorotate;

/**
 * Empties the artwork cache, cancels every pending download operation, and clears the
 * in-flight list.
 * @ghidraAddress 0xc3cb4
 */
- (void)clearArtworkCache;

/**
 * Background operation body: downloads one campaign banner, rescales it for the screen,
 * caches it, and applies it to any visible cell.
 * @param arguments A two-element array of the banner @c NSURL and the campaign-ID @c NSNumber .
 * @ghidraAddress 0xc3d14
 */
- (void)downloadImageSync:(nullable NSArray *)arguments;

/**
 * Posts the per-item info request for the working item and starts its @c Downloader .
 * @ghidraAddress 0xc45ec
 */
- (void)itemInfoDownload;

/**
 * Re-evaluates the working item and forwards its new state to the open detail card.
 * @ghidraAddress 0xc48d8
 */
- (void)itemUpdate;

/**
 * Clears the working row and the detail-open flag.
 * @ghidraAddress 0xc4990
 */
- (void)itemDeselect;

/**
 * Empties the artwork cache and detaches its delegate.
 * @ghidraAddress 0xc49b0
 */
- (void)dealloc;

/**
 * Records a campaign ID to open automatically once the list loads.
 * @param campaignID The campaign to open, or -1 for none.
 * @ghidraAddress 0xc4a1c
 */
- (void)initialCampaignID:(NSInteger)campaignID;

/**
 * Opens the detail for a campaign by ID: selects it if nothing is open, otherwise swaps the
 * open card to it.
 * @param campaignID The campaign to open.
 * @ghidraAddress 0xc4a2c
 */
- (void)addOpenDetail:(NSInteger)campaignID;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
