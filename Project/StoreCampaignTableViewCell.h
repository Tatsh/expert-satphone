/**
 * @file
 * @brief A campaign banner row in the store's campaign table.
 *
 * Reconstructed from Ghidra program Jubeat (class StoreCampaignTableViewCell, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base. The class object
 * is at 0x34e158.
 */

#import <UIKit/UIKit.h>

#import "StoreImageView.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A table cell showing one campaign's artwork banner.
 */
@interface StoreCampaignTableViewCell : UITableViewCell

/** @brief The campaign artwork view. @ghidraAddress 0xcb7c8 (getter) */
@property(nonatomic, strong, nullable) StoreImageView *artworkView;

/**
 * @brief The controller told when the cell is tapped. Held weakly; typed @c id until
 * @c StoreCampaignViewController is reconstructed (see TYPES_PENDING.md).
 * @ghidraAddress 0xcb7ec (getter)
 */
@property(nonatomic, weak, nullable) id ctrlDelegate;

/** @brief The displayed campaign's identifier. @ghidraAddress 0xcb820 (getter) */
@property(nonatomic, readonly) int campaignID;

/**
 * @brief The cell's height for a device idiom.
 * @param isPad Whether the device is a pad.
 * @return The row height (180 on a pad, 80 otherwise).
 * @ghidraAddress 0xcb700
 */
+ (CGFloat)cellHeight:(BOOL)isPad;

/**
 * @brief Builds the cell for a device idiom.
 * @param isPad Whether the device is a pad.
 * @param reuseIdentifier The table's reuse identifier.
 * @param tag The cell's tag.
 * @return The initialised cell.
 * @ghidraAddress 0xcb09c
 */
- (instancetype)initWithDeviceType:(BOOL)isPad
                   reuseIdentifier:(nullable NSString *)reuseIdentifier
                               tag:(int)tag;

/**
 * @brief Fills the cell from a campaign info object and sets its tag.
 * @param info The campaign info (a @c CampaignItemInfo ; typed @c id until reconstructed).
 * @param tag The cell's tag.
 * @ghidraAddress 0xcb694
 */
- (void)setInfo:(nullable id)info tag:(int)tag;

/**
 * @brief The top-left inset of the square artwork banner for the device idiom.
 * @param isPad Whether the pad metrics apply.
 * @ghidraAddress 0xcb71c
 */
- (CGSize)getArtworkMargin:(BOOL)isPad;

/**
 * @brief The full item size of a non-square banner for the device idiom.
 * @param isPad Whether the pad metrics apply.
 * @ghidraAddress 0xcb73c
 */
- (CGSize)getItemSize:(BOOL)isPad;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
