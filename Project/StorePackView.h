/** @file
 * One pack tile in the store's pack grid.
 *
 * Reconstructed from Ghidra program Jubeat (class StorePackView, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The class object is at 0x34e0b8.
 */

#import <UIKit/UIKit.h>

#import "StorePackInfo.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief What a @c StorePackView tells its owner.
 */
@protocol StorePackViewDelegate <NSObject>
@optional
/**
 * @brief Sent when the tile is tapped.
 * @param packView The tile that was tapped.
 */
- (void)storePackViewSelected:(nonnull id)packView;
@end

/**
 * @brief A tappable tile showing one pack's artwork, name, comment, price, and status markers.
 */
@interface StorePackView : UIView

/**
 * @brief The object told when the tile is tapped.
 *
 * Weak and untyped in the metadata, so the dispatch goes through @c -respondsToSelector: rather
 * than a declared conformance. @c StoreTableCell nils this in its @c -dealloc.
 */
@property(nonatomic, weak, nullable) id delegate;

/**
 * @brief The tile's artwork view.
 * @ghidraAddress 0xcad30 (getter)
 */
@property(nonatomic, strong, nullable) UIImageView *artworkView;

/**
 * @brief The tile's position in the pack list, as last given to @c -loadPackInfo:index: .
 * @ghidraAddress 0xcad20 (getter)
 */
@property(nonatomic, readonly) NSUInteger index;

/**
 * @brief Builds the tile's seven subviews.
 * @param frame The tile's frame.
 * @return The initialised tile.
 * @ghidraAddress 0xc9dd0
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Sets the tile's background image.
 * @param image The background image.
 * @ghidraAddress 0xca9e4
 */
- (void)setBgImage:(nullable UIImage *)image;

/**
 * @brief The tap handler: tells the delegate the tile was selected.
 * @param recognizer The tap recogniser.
 * @ghidraAddress 0xca9fc
 */
- (void)handleTap:(nonnull UITapGestureRecognizer *)recognizer;

/**
 * @brief Fills the tile's labels and markers from a pack's info.
 * @param packInfo The pack to display.
 * @param index The tile's position in the pack list.
 * @ghidraAddress 0xcaab0
 */
- (void)loadPackInfo:(nullable StorePackInfo *)packInfo index:(NSUInteger)index;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
