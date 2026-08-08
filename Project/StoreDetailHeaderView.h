/** @file
 * The header panel atop a store pack's detail page.
 *
 * Reconstructed from Ghidra program Jubeat (class StoreDetailHeaderView, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base. The class object is at
 * 0x34eb58.
 */

#import <UIKit/UIKit.h>

#import "AlertViewManager.h"
#import "StoreButton.h"
#import "StoreLinkButton.h"
#import "StorePackInfo.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A pack's detail header: artwork with its reflection, name, comment, purchase and extend
 * buttons, a related-site link, and a "new" marker.
 */
@interface StoreDetailHeaderView : UIView <AlertViewManagerDelegate>

/**
 * @brief The pack's title label.
 * @ghidraAddress 0xfa9e4 (getter)
 */
@property(nonatomic, strong, nullable) UILabel *labelName;

/**
 * @brief The pack's description label.
 * @ghidraAddress 0xfaa08 (getter)
 */
@property(nonatomic, strong, nullable) UILabel *labelComment;

/**
 * @brief The purchase button.
 * @ghidraAddress 0xfaa2c (getter)
 */
@property(nonatomic, strong, nullable) StoreButton *buttonPurchase;

/**
 * @brief The "download extension" button, hidden unless the pack has an extension.
 * @ghidraAddress 0xfaa50 (getter)
 */
@property(nonatomic, strong, nullable) UIButton *buttonExtendDownload;

/**
 * @brief The related-site link button.
 * @ghidraAddress 0xfaa74 (getter)
 */
@property(nonatomic, readonly, nullable) StoreLinkButton *buttonLink;

/**
 * @brief Builds the header's subviews.
 * @param frame The header's frame.
 * @return The initialised header.
 * @ghidraAddress 0xf9074
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Lays the header out for a pack: sizes the name and comment to their text, positions the
 * link button, resizes the header to fit, and shows the "new" marker when appropriate.
 * @param packInfo The pack to display.
 * @ghidraAddress 0xf9dc4
 */
- (void)loadPackInfo:(nullable StorePackInfo *)packInfo;

/**
 * @brief Sets the artwork and rebuilds its reflection.
 * @param artwork The artwork image.
 * @ghidraAddress 0xfa84c
 */
- (void)setArtwork:(nullable UIImage *)artwork;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
