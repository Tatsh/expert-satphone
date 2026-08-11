/** @file
 * The store's downloaded-music management screen.
 *
 * Reconstructed from Ghidra program Jubeat (class StoreManageViewController, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIViewController : every @c super call in the class targets
 * @c UIViewController , and the controller builds its own @c UITableView ivar, wires itself as that
 * table's data source and delegate, and adds it as a subview — it is not a @c UITableViewController
 * .
 *
 * The screen lists the user's purchased tunes, one per row, with a per-row button that either
 * deletes an already-downloaded tune (after a confirmation alert) or re-downloads a missing one
 * through a @c Downloader (for the tune info) and a @c StoreDownloadManager (for the pack data),
 * reporting progress through the parent @c StoreViewController 's modal dialog.
 */

#import <UIKit/UIKit.h>

@protocol AlertViewManagerDelegate;
@protocol DownloaderDelegate;
@protocol StoreDialogViewDelegate;
@protocol StoreDownloadManagerDelegate;

@class StoreDownloadManager;
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
- (instancetype)initWithParent:(nullable StoreViewController *)parent;

/**
 * @brief Builds the view: a full-bounds vertical gradient behind a non-selectable table.
 * @ghidraAddress 0x90f28
 */
- (void)loadView;

/**
 * @brief Vends and lays out a row for a purchased tune.
 * @ghidraAddress 0x91358
 */
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath;

/**
 * @brief The number of purchased tunes.
 * @ghidraAddress 0x91b84
 */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;

/**
 * @brief Tints alternating rows before display.
 * @ghidraAddress 0x91bfc
 */
- (void)tableView:(UITableView *)tableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath;

/**
 * @brief Always one section.
 * @ghidraAddress 0x91ca8
 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView;

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
 * @ghidraAddress 0x9260c
 */
- (void)downloadManagerStartTask:(StoreDownloadManager *)manager;

/**
 * @brief The tune-info fetch finished: register the tune(s), save the list, and start the pack
 * download.
 * @ghidraAddress 0x92824
 */
- (void)downloaderFinished:(id)downloader;

/**
 * @brief The tune-info fetch failed: proceed to the pack download anyway.
 * @ghidraAddress 0x92a38
 */
- (void)downloaderError:(id)downloader;

/**
 * @brief The modal dialog's abort button was pressed: cancel everything and dismiss.
 * @ghidraAddress 0x92a94
 */
- (void)storeDialogCancel:(id)dialogView;

/**
 * @brief A confirmation alert's button was tapped; performs the delete when confirmed.
 * @ghidraAddress 0x92b68
 */
- (void)alertSelect:(NSDictionary *)info;

/**
 * @brief An alert was dismissed; clears the working row.
 * @ghidraAddress 0x92e84
 */
- (void)alertClose:(NSDictionary *)info;

/**
 * @brief The pack download queue completed: reload the table and dismiss the dialog.
 * @ghidraAddress 0x92e98
 */
- (void)downloadManagerCompleted:(StoreDownloadManager *)manager;

/**
 * @brief The pack download queue failed: show an error alert, reload, and dismiss.
 * @ghidraAddress 0x92f18
 */
- (void)downloadManagerFailed:(StoreDownloadManager *)manager;

/**
 * @brief A pack download task made progress: drive the dialog's progress bar.
 * @ghidraAddress 0x9311c
 */
- (void)downloadManagerProceed:(StoreDownloadManager *)manager;

/**
 * @brief Closes any open alert.
 * @ghidraAddress 0x931c4
 */
- (void)storeClose;

/**
 * @ghidraAddress 0x9320c
 */
- (void)didReceiveMemoryWarning;

/**
 * @ghidraAddress 0x93244
 */
- (void)viewDidUnload;

/**
 * @ghidraAddress 0x9329c
 */
- (void)viewWillAppear:(BOOL)animated;

/**
 * @ghidraAddress 0x932d4
 */
- (void)viewDidAppear:(BOOL)animated;

/**
 * @ghidraAddress 0x93340
 */
- (void)viewWillDisappear:(BOOL)animated;

/**
 * @ghidraAddress 0x933c8
 */
- (void)viewDidDisappear:(BOOL)animated;

/**
 * @ghidraAddress 0x93400
 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;

/**
 * @ghidraAddress 0x93410
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations;

/**
 * @ghidraAddress 0x93418
 */
- (BOOL)shouldAutorotate;

/**
 * @ghidraAddress 0x93420
 */
- (void)dealloc;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
