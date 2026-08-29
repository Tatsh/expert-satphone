/**
 * @file
 * @brief The store's "leaflet" scroller: an empty rounded plate that hosts a single leaflet cell.
 *
 * Reconstructed from Ghidra program Jubeat (class StoreLeafletView, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIView, from the dyld bind at the class object's superclass slot.
 *
 * As shipped the class is scaffolding: its table data source reports @c numPackRows as @c 0, so
 * @c -tableView:cellForRowAtIndexPath: is never reached and returns @c nil, and both
 * @c -tableView:willDisplayCell:forRowAtIndexPath: and @c -tableView:didSelectRowAtIndexPath: are
 * empty. Construction only builds a yellow rounded @c leafletView plate and drops one
 * @c StoreLeafletCell into it. See TYPES_PENDING.md.
 */

#import <UIKit/UIKit.h>

#import "StoreLeafletCell.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A rounded plate that carries one @c StoreLeafletCell and forwards its open request on to
 * an owner.
 *
 * Conforms to the table data-source and delegate protocols for a table it never actually feeds, to
 * @c UIScrollViewDelegate, and to @c StoreLeafletCellDelegate (it is set as the leaflet cell's
 * @c aDelegate).
 */
@interface StoreLeafletView : UIView <UITableViewDataSource,
                                      UITableViewDelegate,
                                      UIScrollViewDelegate,
                                      StoreLeafletCellDelegate>

/**
 * @brief The object told to open a pack's detail screen.
 *
 * Weak and untyped in the metadata, so the dispatch goes through @c -respondsToSelector: rather
 * than a declared conformance.
 */
@property(nonatomic, weak, nullable) id aDelegate;

/**
 * @brief Builds the plate and its single leaflet cell.
 * @param frame The view's frame.
 * @return The initialised view.
 * @ghidraAddress 0x124844
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief The number of pack rows the table would show. Always @c 0 as shipped.
 * @return Zero.
 * @ghidraAddress 0x124ac0
 */
- (NSInteger)numPackRows;

/**
 * @brief Would vend a row cell. Unreachable because @c numPackRows is @c 0.
 * @param tableView The table view.
 * @param indexPath The row's index path.
 * @return @c nil.
 * @ghidraAddress 0x124ac8
 */
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath;

/**
 * @brief The number of sections in the table.
 * @param tableView The table view.
 * @return One.
 * @ghidraAddress 0x124ad0
 */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView;

/**
 * @brief The number of rows in a section, which is @c numPackRows.
 * @param tableView The table view.
 * @param section The section index.
 * @return @c numPackRows .
 * @ghidraAddress 0x124ad8
 */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;

/**
 * @brief The height for a row.
 * @param tableView The table view.
 * @param indexPath The row's index path.
 * @return The valid-row height when the row index is below @c numPackRows, otherwise the
 * placeholder height; the valid-row height differs between pad and phone.
 * @ghidraAddress 0x124ae4
 */
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath;

/**
 * @brief Inert. The body is a single @c ret .
 * @param tableView Ignored.
 * @param cell Ignored.
 * @param indexPath Ignored.
 * @ghidraAddress 0x124b68
 */
- (void)tableView:(UITableView *)tableView
      willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath;

/**
 * @brief Inert. The body is a single @c ret .
 * @param tableView Ignored.
 * @param indexPath Ignored.
 * @ghidraAddress 0x124b6c
 */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;

/**
 * @brief Scroll callback. The shipped body is empty (a single @c ret ), so the view ignores
 * scrolling.
 * @param scrollView The scrolling view.
 * @ghidraAddress 0x124b70
 */
- (void)scrollViewDidScroll:(UIScrollView *)scrollView;

/**
 * @brief Asks @c aDelegate to open a pack's detail screen, if it responds.
 * @param packID The pack to open.
 * @ghidraAddress 0x124b74
 */
- (void)pushOpenDetail:(nullable id)packID;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
