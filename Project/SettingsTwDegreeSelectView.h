/** @file
 * A modal table listing the Twitter-share DEGREE (rank/title) items, letting the user pick one to
 * equip or unlock. Each row is a @c degreeTableCell built from a positional array; picking a locked
 * row (one with a positive point cost) raises a point-purchase confirmation alert, and confirming
 * it unlocks the item.
 *
 * Reconstructed from Ghidra program Jubeat (class SettingsTwDegreeSelectView, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The view is its own table's data source and delegate, and it is the delegate of the shared
 * @c AlertViewManager (so it receives @c -alertSelect: ). The owning editor is held in @c delegate
 * and is messaged through the @c SettingsTwDegreeSelectViewDelegate protocol below. This class is a
 * near-twin of @c SettingsTwAccSelectView , differing in its cell class, its delegate selectors,
 * and the way it formats the value handed to the delegate.
 */

#import <UIKit/UIKit.h>

#import "AlertViewManager.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief What a @c SettingsTwDegreeSelectView tells its owner as degree rows are chosen, changed,
 * or a locked row's purchase alert is cancelled.
 *
 * Every message is dispatched through @c -respondsToSelector: , so the binary declares no
 * conformance and all methods are optional.
 */
@protocol SettingsTwDegreeSelectViewDelegate <NSObject>
@optional
/**
 * @brief Sent when a free (already unlocked) row is chosen, or after a purchased row unlocks.
 * @param display The chosen degree's display string, formatted from the row's array.
 */
- (void)degreeSelected:(nullable NSString *)display;
/**
 * @brief Sent when a locked row's purchase alert is raised, before the user confirms.
 * @param display The chosen degree's display string, formatted from the row's array.
 */
- (void)degreeChange:(nullable NSString *)display;
/**
 * @brief Sent when a locked row's purchase alert is cancelled, so the owner can refresh its state.
 */
- (void)refreshDegree;
@end

/**
 * @brief A modal degree-select table backed by a caller-supplied array of item rows.
 */
@interface SettingsTwDegreeSelectView : UIView <UITableViewDataSource,
                                                UITableViewDelegate,
                                                UIAlertViewDelegate,
                                                AlertViewManagerDelegate>

/**
 * @brief Builds the table (filling the whole view) and records the owner and the item array.
 * @param frame The view's frame; the table is laid out at the frame's own size.
 * @param delegate The owner told when rows are chosen, changed, or a purchase is cancelled.
 * @param dataSource The mutable array of item rows, each a mutable positional array.
 * @return The initialised view.
 * @ghidraAddress 0x123dc8
 */
- (instancetype)initWithFrame:(CGRect)frame
                     delegate:(nullable id<SettingsTwDegreeSelectViewDelegate>)delegate
                   dataSource:(nullable NSMutableArray *)dataSource;

/**
 * @brief The number of sections in the table.
 * @param tableView The table posing the question.
 * @return Always @c 1 .
 * @ghidraAddress 0x123f44
 */
- (NSInteger)numberOfSectionsInTableView:(nonnull UITableView *)tableView;

/**
 * @brief The number of rows in a section.
 * @param tableView The table posing the question.
 * @param section The section index.
 * @return The count of the item array.
 * @ghidraAddress 0x123f4c
 */
- (NSInteger)tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section;

/**
 * @brief The height of a row.
 * @param tableView The table posing the question.
 * @param indexPath The row's index path.
 * @return A fixed row height.
 * @ghidraAddress 0x123f64
 */
- (CGFloat)tableView:(nonnull UITableView *)tableView
    heightForRowAtIndexPath:(nonnull NSIndexPath *)indexPath;

/**
 * @brief Builds (or reuses) the degree cell for a row and shows a checkmark on the equipped one.
 * @param tableView The table posing the question.
 * @param indexPath The row's index path.
 * @return The configured cell.
 * @ghidraAddress 0x123f70
 */
- (nonnull UITableViewCell *)tableView:(nonnull UITableView *)tableView
                 cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath;

/**
 * @brief Called before a cell is displayed. This implementation does nothing.
 * @param tableView The table.
 * @param cell The cell about to be displayed.
 * @param indexPath The row's index path.
 * @ghidraAddress 0x124160
 */
- (void)tableView:(nonnull UITableView *)tableView
      willDisplayCell:(nonnull UITableViewCell *)cell
    forRowAtIndexPath:(nonnull NSIndexPath *)indexPath;

/**
 * @brief Handles a row tap: a free row is selected immediately; a costed row raises the unlock
 * confirmation alert.
 * @param tableView The table.
 * @param indexPath The tapped row's index path.
 * @ghidraAddress 0x124164
 */
- (void)tableView:(nonnull UITableView *)tableView
    didSelectRowAtIndexPath:(nonnull NSIndexPath *)indexPath;

/**
 * @brief @c AlertViewManager delegate callback: the tapped button routes to the unlock or to a
 * cancel that clears the pending item.
 * @param info The button info dictionary, carrying the tapped button index under @c "btnMessage" .
 * @ghidraAddress 0x124560
 */
- (void)alertSelect:(nonnull NSDictionary *)info;

/**
 * @brief Performs the unlock of the pending item. The shipped body is empty.
 * @ghidraAddress 0x12463c
 */
- (void)unlockItem;

/**
 * @brief Records a successful unlock: zeroes the item's cost, tells the owner, and refreshes.
 * @ghidraAddress 0x124640
 */
- (void)unlockSuccess;

/**
 * @brief Records a failed unlock: clears the pending item.
 * @ghidraAddress 0x124770
 */
- (void)unlockFailed;

/**
 * @brief Whether the view may rotate to an interface orientation (portrait orientations only).
 * @param interfaceOrientation The candidate orientation.
 * @return @c YES for portrait and portrait-upside-down.
 * @ghidraAddress 0x124784
 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;

/**
 * @brief The supported interface orientations (portrait mask).
 * @return @c UIInterfaceOrientationMaskPortrait | @c UIInterfaceOrientationMaskPortraitUpsideDown .
 * @ghidraAddress 0x124794
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations;

/**
 * @brief Whether the view should autorotate.
 * @return Always @c YES .
 * @ghidraAddress 0x12479c
 */
- (BOOL)shouldAutorotate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
