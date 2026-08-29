/**
 * @file
 * One recommended pack's tile in the store.
 *
 * Reconstructed from Ghidra program Jubeat (class StoreRecommendPackView, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 */

#import <UIKit/UIKit.h>

#import "StorePackInfo.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * What a @c StoreRecommendPackView tells its owner.
 */
@protocol StoreRecommendPackViewDelegate <NSObject>
@optional
/**
 * Sent when the tile is tapped.
 * @param packView The tile that was tapped.
 */
- (void)storePackViewSelected:(id)packView;
@end

/**
 * A tappable tile showing one pack's artwork, name, price and status markers.
 */
@interface StoreRecommendPackView : UIView

/**
 * The object told when the tile is tapped.
 *
 * Weak and untyped in the metadata, so the dispatch goes through @c -respondsToSelector: rather
 * than a declared conformance. @c StoreRecommendTableCell nils this in its @c -dealloc.
 * @ghidraAddress 0x145964 (getter)
 */
@property(nonatomic, weak) id delegate;

/**
 * The tile's artwork view.
 * @ghidraAddress 0x145940 (getter)
 */
@property(nonatomic, strong, nullable) UIImageView *artworkView;

/**
 * The tile's position in the recommendation list, as last given to
 * @c -loadPackInfo:index: .
 * @ghidraAddress 0x145930 (getter)
 */
@property(nonatomic, readonly) NSUInteger index;

/**
 * Builds the tile's seven subviews.
 *
 * The tap recogniser goes on the background rather than on the tile itself. The comment and price
 * labels are sized from the "Purchased" badge's fitted frame, so both move with it.
 *
 * @param frame The tile's frame.
 * @return The initialised tile.
 * @ghidraAddress 0x1449fc
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * Sets the tile's background artwork.
 * @param bgImg The artwork.
 * @ghidraAddress 0x145638
 */
- (void)setBgImage:(nullable UIImage *)bgImg;

/**
 * Fills the tile in from a pack and records its position.
 *
 * A pack whose purchase is merely pending shows as owned, since the purchased marker is driven by
 * @c -isPurchased: **or** @c -isPending: .
 *
 * @param packInfo The pack to show.
 * @param index The tile's position, stored for the delegate to read back.
 * @ghidraAddress 0x145704
 */
- (void)loadPackInfo:(nullable StorePackInfo *)packInfo index:(NSUInteger)index;

/**
 * The tile's tap handler.
 * @param sender The gesture recogniser. Unused — the delegate is handed the tile.
 * @ghidraAddress 0x145650
 */
- (void)handleTap:(id)sender;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
