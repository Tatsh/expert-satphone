/** @file
 * A collection-view cell wrapping a music view.
 *
 * Reconstructed from Ghidra program Jubeat (class collectionCell, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base. The class name is the binary's
 * own lowercase @c collectionCell . @c MusicView is not reconstructed yet; see TYPES_PENDING.md.
 */

#import <UIKit/UIKit.h>

@class MusicView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A cell that hosts one @c MusicView, sized for the device idiom.
 */
@interface collectionCell : UICollectionViewCell

/**
 * @brief Builds the hosted music view and installs it.
 * @param parentDelegate The delegate messaged to load artwork; also the music view's delegate.
 * @param viewType The music view's column type.
 * @param labelDisp Whether the music view shows its label.
 * @ghidraAddress 0x3ac18
 */
- (void)initCell:(nullable id)info
    parentDelegate:(nullable id)parentDelegate
          viewType:(int)viewType
         labelDisp:(BOOL)labelDisp;

/**
 * @brief Refreshes the cell's text for the device idiom.
 * @param animated Whether the refresh animates.
 * @ghidraAddress 0x3ae74
 */
- (void)refleshText:(BOOL)animated;

/**
 * @brief Sets the music info and the cell's index, then requests its artwork.
 * @param info The music info.
 * @param index The cell's index.
 * @ghidraAddress 0x3aebc
 */
- (void)setInfo:(nullable id)info index:(int)index;

/**
 * @brief Sets the music info and requests its artwork.
 * @param info The music info.
 * @ghidraAddress 0x3afbc
 */
- (void)setInfo:(nullable id)info;

/**
 * @brief The hosted music view.
 * @ghidraAddress 0x3b084
 */
- (nullable MusicView *)getMusicView;

/**
 * @brief The hosted view's current tune identifier.
 * @ghidraAddress 0x3b094
 */
- (int)getTuneID;

/**
 * @brief Whether the cell currently hosts a music view.
 * @ghidraAddress 0x3b0ec
 */
- (BOOL)existMusicView;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
