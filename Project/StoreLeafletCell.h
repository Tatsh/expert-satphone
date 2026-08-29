/**
 * @file
 * @brief A leaflet row in the store — unfinished scaffolding rather than a working cell.
 *
 * Reconstructed from Ghidra program Jubeat (class StoreLeafletCell, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIView, from the dyld bind at the class object's superclass slot
 * (0x350960).
 *
 * Everything about this class reads as a placeholder that shipped: its one control is an
 * unstyled blue button captioned @c open at a hardcoded @c {100, 100, 100, 50} , the pack it opens
 * is the literal @c \@"10001" , its @c NSCache callback is empty, and the @c isPad flag it captures
 * on construction is never read anywhere in the binary. See TYPES_PENDING.md.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief What a @c StoreLeafletCell asks its owner to do.
 */
@protocol StoreLeafletCellDelegate <NSObject>
@optional
/**
 * @brief Asks the owner to open a pack's detail screen.
 * @param packID The pack to open.
 */
- (void)pushOpenDetail:(NSString *)packID;
@end

/**
 * @brief A view holding one button that opens a pack's detail screen.
 */
@interface StoreLeafletCell : UIView <NSCacheDelegate>

/**
 * @brief The object asked to perform the push.
 *
 * Weak and untyped in the metadata, so the dispatch goes through @c -respondsToSelector: rather
 * than a declared conformance.
 * @ghidraAddress 0x1c5964 (getter)
 */
@property(nonatomic, weak) id aDelegate;

/**
 * @brief Builds the row's single button.
 * @param frame The row's frame. It is not used — the button's frame is a constant.
 * @return The initialised row.
 * @ghidraAddress 0x1c56ec
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief The button's action. Asks the delegate to open pack @c 10001 .
 * @ghidraAddress 0x1c5870
 */
- (void)opendetail;

/**
 * @brief Inert. The body is a single @c ret .
 * @param cache Ignored.
 * @param obj Ignored.
 * @ghidraAddress 0x1c5928
 */
- (void)cache:(NSCache *)cache willEvictObject:(id)obj;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
