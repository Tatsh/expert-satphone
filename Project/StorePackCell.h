/** @file
 * One pack's row in the store's pack table.
 *
 * Reconstructed from Ghidra program Jubeat (class StorePackCell, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UITableViewCell, from the dyld bind at the class object's superclass slot
 * (0x34eac0).
 */

#import <UIKit/UIKit.h>

#import "StorePackInfo.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A table row showing one pack's artwork, name, price and status markers.
 *
 * The row's six subviews are ivars rather than properties; only the artwork is exposed, and only
 * for reading.
 */
@interface StorePackCell : UITableViewCell

/**
 * @brief The row's artwork view.
 * @ghidraAddress 0xf1aec (getter)
 */
@property(nonatomic, readonly, strong, nullable) UIImageView *artworkView;

/**
 * @brief Whether the row shows its owned marker.
 *
 * There is no backing ivar: the property is stored in the purchased label's own visibility, and
 * both accessors invert it.
 * @ghidraAddress 0xf1878 (getter)
 */
@property(nonatomic) BOOL isPurchased;

/**
 * @brief Builds the row's six subviews.
 *
 * The background image view becomes the cell's @c backgroundView rather than a subview. The other
 * six go on the content view, and their horizontal frames are measured against its width once,
 * with autoresizing masks carrying them through any later change.
 *
 * @param style The cell style.
 * @param reuseIdentifier The reuse identifier.
 * @return The initialised row.
 * @ghidraAddress 0xf0e48
 */
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(nullable NSString *)reuseIdentifier;

/**
 * @brief Fills the row in from a pack.
 *
 * A pack whose purchase is merely pending shows as owned, since the purchased marker is driven by
 * @c -isPurchased: **or** @c -isPending: .
 *
 * @param packInfo The pack to show.
 * @ghidraAddress 0xf18c0
 */
- (void)loadPackInfo:(nullable StorePackInfo *)packInfo;

/**
 * @brief Sets the row's background artwork.
 * @param bgImg The artwork.
 * @ghidraAddress 0xf1ad4
 */
- (void)setBgImage:(nullable UIImage *)bgImg;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
