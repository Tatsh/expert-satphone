/**
 * @file
 * @brief The store's downloaded-music management screen.
 *
 * Reconstructed from Ghidra program Jubeat (class StoreManageViewController, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIViewController : every @c super call in the class targets
 * @c UIViewController , and the controller builds its own @c UITableView ivar, wires itself as that
 * table's data source and delegate, and adds it as a subview. It is not a
 * @c UITableViewController .
 *
 * The screen lists the user's purchased tunes, one per row, with a per-row button that either
 * deletes an already-downloaded tune (after a confirmation alert) or re-downloads a missing one
 * through a @c Downloader (for the tune info) and a @c StoreDownloadManager (for the pack data),
 * reporting progress through the parent @c StoreViewController 's modal dialog.
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
 * @brief Lists downloaded/purchased tunes with a per-row delete or re-download action.
 */
@interface StoreManageViewController : UIViewController <UITableViewDataSource,
                                                         UITableViewDelegate,
                                                         DownloaderDelegate,
                                                         StoreDownloadManagerDelegate,
                                                         AlertViewManagerDelegate,
                                                         StoreDialogViewDelegate>

/**
 * @brief Builds the controller for a parent store view.
 *
 * Sets the navigation and tab-bar titles, loads the tab image and the two per-row action icons,
 * installs a back button targeting the parent, and caches the device idiom.
 * @param parent The owning @c StoreViewController ; held weakly.
 * @return The initialised controller.
 * @ghidraAddress 0x90c58
 */
- (instancetype)initWithParent:(nullable id<StoreParentViewController>)parent;

/**
 * @brief Builds the view: a full-bounds vertical gradient behind a non-selectable table.
 * @ghidraAddress 0x90f28
 */
- (void)loadView;

/**
 * @brief Vends and lays out a row for a purchased tune.
 * @param aTableView The table asking.
 * @param indexPath The row's index path.
 * @return The cell for the tune, carrying its title and per-row action button.
 * @ghidraAddress 0x91358
 */
- (UITableViewCell *)tableView:(UITableView *)aTableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath;

/**
 * @brief The number of purchased tunes.
 * @param aTableView The table asking.
 * @param section The section asked about.
 * @return The purchased-music count held by the shared store music-list manager.
 * @ghidraAddress 0x91b84
 */
- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section;

/**
 * @brief Tints alternating rows before display.
 * @param aTableView The table asking.
 * @param cell The cell about to be drawn.
 * @param indexPath The row's index path.
 * @ghidraAddress 0x91bfc
 */
- (void)tableView:(UITableView *)aTableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath;

/**
 * @brief Always one section.
 * @param aTableView The table asking.
 * @return Always 1.
 * @ghidraAddress 0x91ca8
 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)aTableView;

/**
 * @brief The per-row action button's handler: delete an owned tune or start a re-download.
 * @param sender The row's button, whose tag is the row index.
 * @ghidraAddress 0x91cb0
 */
- (void)pushCellButton:(nullable id)sender;

/**
 * @brief Builds the download-task queue for the working row and starts the download manager.
 * @ghidraAddress 0x922f4
 */
- (void)startDownloadMusic;

/**
 * @brief Updates the modal dialog's message when a download task starts.
 * @param manager The download manager reporting the task.
 * @ghidraAddress 0x9260c
 */
- (void)downloadManagerStartTask:(StoreDownloadManager *)manager;

/**
 * @brief The tune-info fetch finished: register the tune(s), save the list, and start the pack
 * download.
 * @param downloader The downloader reporting the result.
 * @ghidraAddress 0x92824
 */
- (void)downloaderFinished:(id)downloader;

/**
 * @brief The tune-info fetch failed: proceed to the pack download anyway.
 * @param downloader The downloader reporting the failure.
 * @ghidraAddress 0x92a38
 */
- (void)downloaderError:(id)downloader;

/**
 * @brief The modal dialog's abort button was pressed: cancel everything and dismiss.
 * @param dialogView The dialog whose abort button was pressed.
 * @ghidraAddress 0x92a94
 */
- (void)storeDialogCancel:(id)dialogView;

/**
 * @brief A confirmation alert's button was tapped; performs the delete when confirmed.
 * @param info The alert's result, carrying the tapped button.
 * @ghidraAddress 0x92b68
 */
- (void)alertSelect:(NSDictionary *)info;

/**
 * @brief An alert was dismissed; clears the working row.
 * @param info The dismissed alert's identity.
 * @ghidraAddress 0x92e84
 */
- (void)alertClose:(NSDictionary *)info;

/**
 * @brief The pack download queue completed: reload the table and dismiss the dialog.
 * @param manager The download manager reporting completion.
 * @ghidraAddress 0x92e98
 */
- (void)downloadManagerCompleted:(StoreDownloadManager *)manager;

/**
 * @brief The pack download queue failed: show an error alert, reload, and dismiss.
 * @param manager The download manager reporting the failure.
 * @ghidraAddress 0x92f18
 */
- (void)downloadManagerFailed:(StoreDownloadManager *)manager;

/**
 * @brief A pack download task made progress: drive the dialog's progress bar.
 * @param manager The download manager reporting progress.
 * @ghidraAddress 0x9311c
 */
- (void)downloadManagerProceed:(StoreDownloadManager *)manager;

/**
 * @brief Closes any open alert.
 * @ghidraAddress 0x931c4
 */
- (void)storeClose;

/**
 * @brief Handles a low-memory warning by chaining to super.
 * @ghidraAddress 0x9320c
 */
- (void)didReceiveMemoryWarning;

/**
 * @brief Releases the table when the view is unloaded.
 * @ghidraAddress 0x93244
 */
- (void)viewDidUnload;

/**
 * @brief The view is about to appear.
 * @param animated Whether the appearance is animated.
 * @ghidraAddress 0x9329c
 */
- (void)viewWillAppear:(BOOL)animated;

/**
 * @brief The view has appeared.
 * @param animated Whether the appearance was animated.
 * @ghidraAddress 0x932d4
 */
- (void)viewDidAppear:(BOOL)animated;

/**
 * @brief The view is about to disappear.
 * @param animated Whether the disappearance is animated.
 * @ghidraAddress 0x93340
 */
- (void)viewWillDisappear:(BOOL)animated;

/**
 * @brief The view has disappeared.
 * @param animated Whether the disappearance was animated.
 * @ghidraAddress 0x933c8
 */
- (void)viewDidDisappear:(BOOL)animated;

/**
 * @brief Whether the screen may rotate to an orientation.
 * @param interfaceOrientation The orientation asked about.
 * @return YES for the two portrait orientations, NO otherwise.
 * @ghidraAddress 0x93400
 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;

/**
 * @brief The orientations the screen supports.
 * @return Both portrait orientations.
 * @ghidraAddress 0x93410
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations;

/**
 * @brief Whether the screen rotates.
 * @return Always YES.
 * @ghidraAddress 0x93418
 */
- (BOOL)shouldAutorotate;

/**
 * @brief Chains to super only; the strong ivars are torn down by the generated destructor.
 * @ghidraAddress 0x93420
 */
- (void)dealloc;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
