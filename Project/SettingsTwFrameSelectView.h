/**
 * @file
 * A modal table listing the Twitter-share frame items, letting the user pick one to equip
 * or unlock.
 *
 * Each row is a @c frameTableCell built from a positional array; picking a locked row (one with a
 * positive point cost) raises a point-purchase confirmation alert, and confirming it unlocks the
 * frame.
 *
 * Reconstructed from Ghidra program Jubeat (class SettingsTwFrameSelectView, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The view is its own table's data source and delegate, and it is the delegate of the shared
 * @c AlertViewManager (so it receives @c -alertSelect: ). The owning editor is held in @c delegate
 * and is messaged through the @c SettingsTwFrameSelectViewDelegate protocol below.
 */

#import <UIKit/UIKit.h>

#import "AlertViewManager.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * What a @c SettingsTwFrameSelectView tells its owner as frame rows are chosen, changed, or
 * a locked row's purchase alert is cancelled.
 *
 * Every message is dispatched through @c -respondsToSelector: , so the binary declares no
 * conformance and all methods are optional.
 */
@protocol SettingsTwFrameSelectViewDelegate <NSObject>
@optional
/**
 * Sent when a free (already unlocked) row is chosen, or after a purchased row unlocks.
 * @param identifier The chosen frame's identifier (element 2 of the row's array).
 */
- (void)frameSelected:(nullable NSString *)identifier;
/**
 * Sent when a locked row's purchase alert is raised, before the user confirms.
 * @param identifier The chosen frame's identifier (element 2 of the row's array).
 */
- (void)frameChange:(nullable NSString *)identifier;
/**
 * Sent when a locked row's purchase alert is cancelled, so the owner can refresh its state.
 */
- (void)refreshAccessory;
@end

/**
 * A modal frame-select table backed by a caller-supplied array of item rows.
 */
@interface SettingsTwFrameSelectView : UIView <UITableViewDataSource,
                                               UITableViewDelegate,
                                               UIAlertViewDelegate,
                                               AlertViewManagerDelegate>

/**
 * Builds the table (filling the whole view), records the owner, and deep-copies the item
 * rows into a mutable working array.
 * @param frame The view's frame; the table is laid out at the frame's own size.
 * @param delegate The owner told when rows are chosen, changed, or a purchase is cancelled.
 * @param dataSource The array of item rows; each row is copied into a mutable array.
 * @return The initialised view.
 * @ghidraAddress 0xfe0a8
 */
- (instancetype)initWithFrame:(CGRect)frame
                     delegate:(nullable id<SettingsTwFrameSelectViewDelegate>)delegate
                   dataSource:(nullable NSMutableArray *)dataSource;

/**
 * The number of sections in the table.
 * @param tableView The table posing the question.
 * @return Always @c 1 .
 * @ghidraAddress 0xfe324
 */
- (NSInteger)numberOfSectionsInTableView:(nonnull UITableView *)tableView;

/**
 * The number of rows in a section.
 * @param tableView The table posing the question.
 * @param section The section index.
 * @return The count of the item array.
 * @ghidraAddress 0xfe32c
 */
- (NSInteger)tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section;

/**
 * Builds (or reuses) the frame cell for a row.
 * @param tableView The table posing the question.
 * @param indexPath The row's index path.
 * @return The configured cell.
 * @ghidraAddress 0xfe344
 */
- (nonnull UITableViewCell *)tableView:(nonnull UITableView *)tableView
                 cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath;

/**
 * Called before a cell is displayed. This implementation does nothing.
 * @param tableView The table.
 * @param cell The cell about to be displayed.
 * @param indexPath The row's index path.
 * @ghidraAddress 0xfe46c
 */
- (void)tableView:(nonnull UITableView *)tableView
      willDisplayCell:(nonnull UITableViewCell *)cell
    forRowAtIndexPath:(nonnull NSIndexPath *)indexPath;

/**
 * Handles a row tap: a free row is selected immediately; a costed row raises the unlock
 * confirmation alert.
 * @param tableView The table.
 * @param indexPath The tapped row's index path.
 * @ghidraAddress 0xfe470
 */
- (void)tableView:(nonnull UITableView *)tableView
    didSelectRowAtIndexPath:(nonnull NSIndexPath *)indexPath;

/**
 * @c AlertViewManager delegate callback: the tapped button routes to the unlock or to a
 * cancel that clears the pending item.
 * @param info The button info dictionary, carrying the tapped button index under @c "btnMessage" .
 * @ghidraAddress 0xfe854
 */
- (void)alertSelect:(nonnull NSDictionary *)info;

/**
 * Performs the unlock of the pending item. The shipped body is empty.
 * @ghidraAddress 0xfe930
 */
- (void)unlockItem;

/**
 * Records a successful unlock: zeroes the item's cost, tells the owner, and refreshes.
 * @ghidraAddress 0xfe934
 */
- (void)unlockSuccess;

/**
 * Records a failed unlock: clears the pending item.
 * @ghidraAddress 0xfea64
 */
- (void)unlockFailed;

/**
 * Whether the view may rotate to an interface orientation (portrait orientations only).
 * @param interfaceOrientation The candidate orientation.
 * @return @c YES for portrait and portrait-upside-down.
 * @ghidraAddress 0xfea78
 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;

/**
 * The supported interface orientations (portrait mask).
 * @return @c UIInterfaceOrientationMaskPortrait | @c UIInterfaceOrientationMaskPortraitUpsideDown .
 * @ghidraAddress 0xfea88
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations;

/**
 * Whether the view should autorotate.
 * @return Always @c YES .
 * @ghidraAddress 0xfea90
 */
- (BOOL)shouldAutorotate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
