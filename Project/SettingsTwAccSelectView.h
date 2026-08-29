/**
 * @file
 * @brief A modal table listing the Twitter-account accessory items, letting the user pick one to
 * equip or unlock.
 *
 * Each row is an @c accessoryTableCell built from a positional array; picking a locked row (one
 * with a positive point cost) raises a point-purchase confirmation alert, and confirming it
 * unlocks the item.
 *
 * Reconstructed from Ghidra program Jubeat (class SettingsTwAccSelectView, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The view is its own table's data source and delegate, and it is the delegate of the shared
 * @c AlertViewManager (so it receives @c -alertSelect: ). The owning editor is held in @c delegate
 * and is messaged through the @c SettingsTwAccSelectViewDelegate protocol below.
 */

#import <UIKit/UIKit.h>

#import "AlertViewManager.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief What a @c SettingsTwAccSelectView tells its owner as accessory rows are chosen, changed,
 * or a locked row's purchase alert is cancelled.
 *
 * Every message is dispatched through @c -respondsToSelector: , so the binary declares no
 * conformance and all methods are optional.
 */
@protocol SettingsTwAccSelectViewDelegate <NSObject>
@optional
/**
 * @brief Sent when a free (already unlocked) row is chosen, or after a purchased row unlocks.
 * @param identifier The chosen accessory's identifier (element 2 of the row's array).
 */
- (void)accessorySelected:(nullable NSString *)identifier;
/**
 * @brief Sent when a locked row's purchase alert is raised, before the user confirms.
 * @param identifier The chosen accessory's identifier (element 2 of the row's array).
 */
- (void)accessoryChange:(nullable NSString *)identifier;
/**
 * @brief Sent when a locked row's purchase alert is cancelled, so the owner can refresh its state.
 */
- (void)refreshAccessory;
@end

/**
 * @brief A modal accessory-select table backed by a caller-supplied array of item rows.
 */
@interface SettingsTwAccSelectView : UIView <UITableViewDataSource,
                                             UITableViewDelegate,
                                             UIAlertViewDelegate,
                                             AlertViewManagerDelegate>

/**
 * @brief Builds the table (filling the whole view) and records the owner and the item array.
 * @param frame The view's frame; the table is laid out at the frame's own size.
 * @param delegate The owner told when rows are chosen, changed, or a purchase is cancelled.
 * @param dataSource The mutable array of item rows, each a mutable positional array.
 * @return The initialised view.
 * @ghidraAddress 0xe34bc
 */
- (instancetype)initWithFrame:(CGRect)frame
                     delegate:(nullable id<SettingsTwAccSelectViewDelegate>)delegate
                   dataSource:(nullable NSMutableArray *)dataSource;

/**
 * @brief The number of sections in the table.
 * @param tableView The table posing the question.
 * @return Always @c 1 .
 * @ghidraAddress 0xe3638
 */
- (NSInteger)numberOfSectionsInTableView:(nonnull UITableView *)tableView;

/**
 * @brief The number of rows in a section.
 * @param tableView The table posing the question.
 * @param section The section index.
 * @return The count of the item array.
 * @ghidraAddress 0xe3640
 */
- (NSInteger)tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section;

/**
 * @brief The height of a row.
 * @param tableView The table posing the question.
 * @param indexPath The row's index path.
 * @return A fixed row height.
 * @ghidraAddress 0xe3658
 */
- (CGFloat)tableView:(nonnull UITableView *)tableView
    heightForRowAtIndexPath:(nonnull NSIndexPath *)indexPath;

/**
 * @brief Builds (or reuses) the accessory cell for a row and shows a checkmark on the equipped one.
 * @param tableView The table posing the question.
 * @param indexPath The row's index path.
 * @return The configured cell.
 * @ghidraAddress 0xe3664
 */
- (nonnull UITableViewCell *)tableView:(nonnull UITableView *)tableView
                 cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath;

/**
 * @brief Called before a cell is displayed. This implementation does nothing.
 * @param tableView The table.
 * @param cell The cell about to be displayed.
 * @param indexPath The row's index path.
 * @ghidraAddress 0xe3854
 */
- (void)tableView:(nonnull UITableView *)tableView
      willDisplayCell:(nonnull UITableViewCell *)cell
    forRowAtIndexPath:(nonnull NSIndexPath *)indexPath;

/**
 * @brief Handles a row tap: a free row is selected immediately; a costed row raises the unlock
 * confirmation alert.
 * @param tableView The table.
 * @param indexPath The tapped row's index path.
 * @ghidraAddress 0xe3858
 */
- (void)tableView:(nonnull UITableView *)tableView
    didSelectRowAtIndexPath:(nonnull NSIndexPath *)indexPath;

/**
 * @brief @c AlertViewManager delegate callback: the tapped button routes to the unlock or to a
 * cancel that clears the pending item.
 * @param info The button info dictionary, carrying the tapped button index under @c "btnMessage" .
 * @ghidraAddress 0xe3c3c
 */
- (void)alertSelect:(nonnull NSDictionary *)info;

/**
 * @brief Performs the unlock of the pending item. The shipped body is empty.
 * @ghidraAddress 0xe3d18
 */
- (void)unlockItem;

/**
 * @brief Records a successful unlock: zeroes the item's cost, tells the owner, and refreshes.
 * @ghidraAddress 0xe3d1c
 */
- (void)unlockSuccess;

/**
 * @brief Records a failed unlock: clears the pending item.
 * @ghidraAddress 0xe3e4c
 */
- (void)unlockFailed;

/**
 * @brief Whether the view may rotate to an interface orientation (portrait orientations only).
 * @param interfaceOrientation The candidate orientation.
 * @return @c YES for portrait and portrait-upside-down.
 * @ghidraAddress 0xe3e60
 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;

/**
 * @brief The supported interface orientations (portrait mask).
 * @return @c UIInterfaceOrientationMaskPortrait | @c UIInterfaceOrientationMaskPortraitUpsideDown .
 * @ghidraAddress 0xe3e70
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations;

/**
 * @brief Whether the view should autorotate.
 * @return Always @c YES .
 * @ghidraAddress 0xe3e78
 */
- (BOOL)shouldAutorotate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
