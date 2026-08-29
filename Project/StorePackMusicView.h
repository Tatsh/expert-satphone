/**
 * @file
 * One track row inside a store pack's detail page.
 *
 * Reconstructed from Ghidra program Jubeat (class StorePackMusicView, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base. The class object is at 0x34e3d8.
 */

#import <UIKit/UIKit.h>

#import "StoreImageView.h"
#import "StoreMusicInfo.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * A track row: jacket, title, artist, difficulty levels, a sample-play button, an iTunes
 * link, and an extension marker.
 */
@interface StorePackMusicView : UIView

/** The track jacket, which loads itself from a URL. @ghidraAddress 0xd3784 (getter) */
@property(nonatomic, strong, nullable) StoreImageView *artworkView;
/** The track title label. @ghidraAddress 0xd37a8 (getter) */
@property(nonatomic, strong, nullable) UILabel *labelName;
/** The artist label. @ghidraAddress 0xd37cc (getter) */
@property(nonatomic, strong, nullable) UILabel *labelArtist;
/** The difficulty-levels label. @ghidraAddress 0xd37f0 (getter) */
@property(nonatomic, strong, nullable) UILabel *labelLevels;
/** The sample-play button. @ghidraAddress 0xd3814 (getter) */
@property(nonatomic, strong, nullable) UIButton *buttonSample;
/** The iTunes link button. @ghidraAddress 0xd3838 (getter) */
@property(nonatomic, strong, nullable) UIButton *buttonLink;
/** The extension marker. @ghidraAddress 0xd385c (getter) */
@property(nonatomic, strong, nullable) UIImageView *extendImg;
/** The sample-download spinner over the sample button. @ghidraAddress 0xd3880 (getter) */
@property(nonatomic, strong, nullable) UIActivityIndicatorView *indicatorSample;

/**
 * Builds the row's subviews.
 * @param frame The row's frame.
 * @return The initialised row.
 * @ghidraAddress 0xd20e0
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * Fills the row from a track's info, or clears it when nil.
 * @param info The track info.
 * @ghidraAddress 0xd2f94
 */
- (void)setInfo:(nullable StoreMusicInfo *)info;

/**
 * Shows the sample button in its stopped state.
 * @ghidraAddress 0xd34fc
 */
- (void)sampleStop;

/**
 * Shows the sample button downloading, with the spinner running.
 * @ghidraAddress 0xd35d4
 */
- (void)sampleDownloading;

/**
 * Shows the sample button in its playing state.
 * @ghidraAddress 0xd36ac
 */
- (void)samplePlaying;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
