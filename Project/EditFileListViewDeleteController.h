/** @file
 * The edit-chart file list with per-row deletion.
 *
 * Reconstructed from Ghidra program Jubeat (class @c EditFileListViewDeleteController, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c EditFileListViewController (itself a @c UITableViewController), taken from
 * the @c objc_msgSendSuper target in @c -setFileList: (0x1faa48) and from the inherited
 * @c fileList and @c delegate accessors messaged throughout.
 */

#import <UIKit/UIKit.h>

#import "EditFileListViewController.h"

NS_ASSUME_NONNULL_BEGIN

@class JcfDownloadPageViewController;

/**
 * @brief What an @c EditFileListViewDeleteController tells its owner.
 *
 * Extends @c EditFileListViewDelegate with the three optional callbacks this subclass sends
 * (new-file, download, and delete), each messaged only when the delegate responds. The base
 * protocol's selector names are the binary's own; these three are the extra selectors messaged
 * through @c -respondsToSelector: guards in @c -tableView:didSelectRowAtIndexPath: and the delete
 * commit.
 */
@protocol EditFileListViewDeleteDelegate <EditFileListViewDelegate>
@optional
/** @brief Sent when the "make a chart" menu row is chosen. */
- (void)editFileListViewSelectNewFile;
/** @brief Sent when the "find a chart to download" menu row is chosen. */
- (void)editFileListViewSelectDownload;
/**
 * @brief Sent when a saved chart is deleted.
 * @param fileName The deleted chart's file name.
 */
- (void)editFileListViewDeleteFile:(nullable NSString *)fileName;
@end

/**
 * @brief A table of saved edit charts that supports deleting a chart by swiping a row.
 *
 * The table has three sections: a menu (new-chart / download-chart), the saved charts, and a run
 * of empty slots.
 */
@interface EditFileListViewDeleteController : EditFileListViewController

/**
 * @brief Initialises the controller at a given size and seeds the slot limit.
 * @details Chains to the superclass initialiser, clears the highlighted file name, and reads the
 * editable slot limit from the shared @c EditDataManager.
 * @param size The table view size passed to the superclass.
 * @return The initialised controller, or @c nil.
 * @ghidraAddress 0x1f8d10
 */
- (instancetype)initWithSize:(CGSize)size;

/**
 * @brief Builds (or dequeues) a menu cell for one of the top-section entries.
 * @param tableView The table asking for the cell.
 * @param row The menu index: @c 0 is "make a chart", @c 1 is "find a chart to download".
 * @return The configured menu cell.
 * @ghidraAddress 0x1f8db0
 */
- (UITableViewCell *)getNewFileCell:(UITableView *)tableView row:(int)row;

/**
 * @brief Returns the cell for a row across all three sections.
 * @ghidraAddress 0x1f8f78
 */
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath;

/**
 * @brief Tints a cell's background just before it is shown.
 * @ghidraAddress 0x1f97b0
 */
- (void)tableView:(UITableView *)tableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath;

/**
 * @brief Returns the row count for a section.
 * @ghidraAddress 0x1f9ba8
 */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;

/**
 * @brief Returns the section count (always three).
 * @ghidraAddress 0x1f9c7c
 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView;

/**
 * @brief Deletes a saved chart, updates the counts, and re-lays the table.
 * @ghidraAddress 0x1f9c84
 */
- (void)tableView:(UITableView *)tableView
    commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
     forRowAtIndexPath:(NSIndexPath *)indexPath;

/**
 * @brief Only saved-chart rows that exist may be edited (deleted).
 * @ghidraAddress 0x1fa274
 */
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath;

/**
 * @brief Returns the footer height for a section.
 * @ghidraAddress 0x1fa3d0
 */
- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section;

/**
 * @brief Builds the coloured footer strip for a section once the slots are full.
 * @ghidraAddress 0x1fa3f0
 */
- (nullable UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section;

/**
 * @brief Handles taps: opens the menu actions or reports the chosen chart.
 * @ghidraAddress 0x1fa5e4
 */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;

/**
 * @brief Records the file name of the chart to highlight in the list.
 * @param targetFileName The chart file name, or @c nil.
 * @ghidraAddress 0x1faa34
 */
- (void)setTargetFileName:(nullable NSString *)targetFileName;

/**
 * @brief Adopts a new chart list and recomputes the used and blank slot counts.
 * @param fileList The charts to list.
 * @ghidraAddress 0x1faa48
 */
- (void)setFileList:(nullable NSMutableArray *)fileList;

/**
 * @brief Reloads the backing table view.
 * @ghidraAddress 0x1fab04
 */
- (void)reloadTable;

/**
 * @brief Whether this is the first appearance (suppresses the new-chart highlight).
 * @ghidraAddress 0x1fab44
 */
@property(nonatomic) BOOL isFirst;

/**
 * @brief Whether the list is a shared (read-only) list.
 * @ghidraAddress 0x1fab64
 */
@property(nonatomic) BOOL isShared;

/**
 * @brief The music id the download action opens.
 * @ghidraAddress 0x1fab84
 */
@property(nonatomic) int tuneID;

/**
 * @brief The owning edit controller.
 * @ghidraAddress 0x1faba4
 */
@property(nonatomic, strong, nullable) EditFileListViewDeleteController *parentCtrl;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
