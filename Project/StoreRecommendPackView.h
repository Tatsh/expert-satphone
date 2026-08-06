/** @file
 * One recommended pack's tile in the store.
 *
 * Reconstructed from Ghidra program Jubeat (class StoreRecommendPackView, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: a stub grown outwards from its callers. Only the members
 * @c StoreRecommendTableCell reaches are declared; the class also carries @c -initWithFrame:,
 * @c -setBgImage:, @c -handleTap: and @c -loadPackInfo:index:, listed in TYPES_PENDING.md.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A tappable tile showing one pack's artwork.
 */
@interface StoreRecommendPackView : UIView

/**
 * @brief The object told when the tile is tapped.
 *
 * Weak and untyped in the metadata. @c StoreRecommendTableCell nils this in its @c -dealloc, which
 * is the only reason that method exists.
 * @ghidraAddress 0x145964 (getter)
 */
@property(nonatomic, weak) id delegate;

/**
 * @brief The tile's artwork. DECLARED ONLY.
 * @ghidraAddress 0x145940 (getter)
 */
@property(nonatomic, strong, nullable) UIImageView *artworkView;

/**
 * @brief The tile's position in the recommendation list. DECLARED ONLY.
 * @ghidraAddress 0x145930 (getter)
 */
@property(nonatomic, readonly) NSUInteger index;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
