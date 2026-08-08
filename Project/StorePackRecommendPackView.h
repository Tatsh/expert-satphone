/** @file
 * A recommended-pack tile that shares the pack track row's layout.
 *
 * Reconstructed from Ghidra program Jubeat (class StorePackRecommendPackView, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base. The class object
 * is at 0x34d578. The layout is identical to @c StorePackMusicView , but @c -setInfo: takes a whole
 * @c StorePackInfo and shows only its name.
 */

#import <UIKit/UIKit.h>

#import "StoreImageView.h"
#import "StorePackInfo.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A recommended-pack tile: jacket, name, and the (here unused) sample and link controls.
 */
@interface StorePackRecommendPackView : UIView

/** @brief The pack jacket, which loads itself from a URL. @ghidraAddress 0x89288 (getter) */
@property(nonatomic, strong, nullable) StoreImageView *artworkView;
/** @brief The pack name label. @ghidraAddress 0x892ac (getter) */
@property(nonatomic, strong, nullable) UILabel *labelName;
/** @brief The artist label (cleared by @c -setInfo:). @ghidraAddress 0x892d0 (getter) */
@property(nonatomic, strong, nullable) UILabel *labelArtist;
/** @brief The difficulty-levels label (cleared by @c -setInfo:). @ghidraAddress 0x892f4 (getter) */
@property(nonatomic, strong, nullable) UILabel *labelLevels;
/** @brief The sample-play button. @ghidraAddress 0x89318 (getter) */
@property(nonatomic, strong, nullable) UIButton *buttonSample;
/** @brief The iTunes link button. @ghidraAddress 0x8933c (getter) */
@property(nonatomic, strong, nullable) UIButton *buttonLink;
/** @brief The extension marker. @ghidraAddress 0x89360 (getter) */
@property(nonatomic, strong, nullable) UIImageView *extendImg;
/** @brief The sample-download spinner over the sample button. @ghidraAddress 0x89384 (getter) */
@property(nonatomic, strong, nullable) UIActivityIndicatorView *indicatorSample;

/**
 * @brief Builds the tile's subviews.
 * @param frame The tile's frame.
 * @return The initialised tile.
 * @ghidraAddress 0x87d94
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Fills the tile from a pack's info, or clears it when nil.
 * @param info The pack info.
 * @ghidraAddress 0x88c48
 */
- (void)setInfo:(nullable StorePackInfo *)info;

/**
 * @brief Shows the sample button in its stopped state.
 * @ghidraAddress 0x89000
 */
- (void)sampleStop;

/**
 * @brief Shows the sample button downloading, with the spinner running.
 * @ghidraAddress 0x890d8
 */
- (void)sampleDownloading;

/**
 * @brief Shows the sample button in its playing state.
 * @ghidraAddress 0x891b0
 */
- (void)samplePlaying;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
