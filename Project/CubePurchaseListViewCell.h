/** @file
 * One row of the cube-pack purchase list.
 *
 * Reconstructed from Ghidra program Jubeat (class CubePurchaseListViewCell, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UITableViewCell, taken from the dyld bind at the class object's superclass
 * slot (0x34ce50) rather than from the name.
 */

#import <UIKit/UIKit.h>

#import "CubePurchaseInfo.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A purchase row: a tappable plate carrying the cube count, a label plate, and two labels.
 *
 * The cube count is drawn digit by digit from per-digit artwork rather than as text, which is why
 * the row owns a fixed five-element array of image views.
 */
@interface CubePurchaseListViewCell : UITableViewCell

/**
 * @brief The object the row's button targets.
 *
 * Weak, per the @c W attribute in the runtime metadata, and genuinely untyped — the metadata
 * encodes it as a bare @c \@ with no protocol. It expects @c tapPurchaseBtn: .
 *
 * Note that @c -setBgImage:info:cache:aDelegate: does **not** write this ivar; it uses its own
 * @c aDelegate argument as the button's target and discards it.
 * @ghidraAddress 0x646f4 (getter)
 */
@property(nonatomic, weak) id aDelegate;

/**
 * @brief Declared readonly and never assigned by any method this class defines, so always nil.
 * @ghidraAddress 0x64728 (getter)
 */
@property(nonatomic, readonly, nullable) UIButton *addBtn;

/**
 * @brief Builds the row's subviews at the metrics for the current device idiom.
 *
 * @param style Passed straight through to @c UITableViewCell.
 * @param reuseIdentifier Passed straight through to @c UITableViewCell.
 * @param tag Set on the row's button so a tap can be traced back to its row.
 * @return The initialised cell.
 * @ghidraAddress 0x63dc0
 */
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(nullable NSString *)reuseIdentifier
                          tag:(int)tag;

/**
 * @brief Fills the row in, loading digit artwork through a caller-owned cache.
 *
 * @param bgImg The plate drawn behind the whole row, set as the button's normal background.
 * @param info The pack whose count, price and description the row shows.
 * @param cache A dictionary the row reads and writes, keyed by digit number and by the plate's
 *        resource name, so the artwork is loaded once across all rows.
 * @param aDelegate The object the button targets. Used and discarded, not retained in the ivar.
 * @ghidraAddress 0x64328
 */
- (void)setBgImage:(nullable UIImage *)bgImg
              info:(nullable CubePurchaseInfo *)info
             cache:(nullable NSMutableDictionary *)cache
         aDelegate:(nullable id)aDelegate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
