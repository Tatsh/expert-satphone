/** @file
 * The cube-purchase pack list view.
 *
 * Reconstructed from Ghidra program Jubeat (class CubePurchaseListView, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base. The class object is at
 * 0x34ce98.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class CubePurchaseListView;

/**
 * @brief Told when a purchase row is chosen.
 */
@protocol CubePurchaseListViewDelegate <NSObject>
@optional
/** @brief The row at the given index path was selected. */
- (void)selectListCell:(nullable NSIndexPath *)indexPath;
@end

/**
 * @brief A table of cube-purchase packs, each row a `CubePurchaseListViewCell` drawn over a shared
 * plate, with digit artwork loaded once through a shared cache.
 */
@interface CubePurchaseListView : UIView <UITableViewDataSource, UITableViewDelegate>

/**
 * @brief The delegate told when a row is chosen. Held weakly.
 * @ghidraAddress 0x64fe0 (getter), 0x65000 (setter)
 */
@property(nonatomic, weak, nullable) id<CubePurchaseListViewDelegate> aDelegate;

/**
 * @brief Builds the list view, its table, and the shared digit-artwork cache.
 * @param frame The view's frame.
 * @return The initialised view.
 * @ghidraAddress 0x6480c
 */
- (nullable instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Sets the pack rows and reloads the table.
 * @param listArray The pack records.
 * @ghidraAddress 0x64b58
 */
- (void)setListArray:(nullable NSArray *)listArray;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
