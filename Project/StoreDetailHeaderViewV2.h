/** @file
 * The header panel atop a store pack's detail page (version 2).
 *
 * Reconstructed from Ghidra program Jubeat (class StoreDetailHeaderViewV2, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base. The class
 * object is at 0x350228.
 *
 * This is the V2 header. Unlike @c StoreDetailHeaderView it also builds a bordered relation view
 * carrying two relation-tab buttons and exposes the tab colours through
 * -setRelationColor:selectable: .
 */

#import <UIKit/UIKit.h>

#import "AlertViewManager.h"
#import "StoreButton.h"
#import "StoreLinkButton.h"
#import "StorePackInfo.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A pack's detail header: artwork with its reflection, name, comment, purchase and extend
 * buttons, a related-site link, a relation-tab strip, and a "new" marker.
 */
@interface StoreDetailHeaderViewV2 : UIView <AlertViewManagerDelegate>

/**
 * @brief The pack's title label.
 * @ghidraAddress 0x1a7284 (getter)
 */
@property(nonatomic, strong, nullable) UILabel *labelName;

/**
 * @brief The pack's description label.
 * @ghidraAddress 0x1a72a8 (getter)
 */
@property(nonatomic, strong, nullable) UILabel *labelComment;

/**
 * @brief The purchase button.
 * @ghidraAddress 0x1a72cc (getter)
 */
@property(nonatomic, strong, nullable) StoreButton *buttonPurchase;

/**
 * @brief The "download extension" button, hidden unless the pack has an extension.
 * @ghidraAddress 0x1a72f0 (getter)
 */
@property(nonatomic, strong, nullable) UIButton *buttonExtendDownload;

/**
 * @brief The related-site link button.
 * @ghidraAddress 0x1a7314 (getter)
 */
@property(nonatomic, readonly, nullable) StoreLinkButton *buttonLink;

/**
 * @brief The two relation-tab buttons of the relation strip.
 * @ghidraAddress 0x1a7324 (getter)
 */
@property(nonatomic, readonly, nullable) NSArray *relationBtnArray;

/**
 * @brief Builds the header's subviews.
 * @param frame The header's frame.
 * @return The initialised header.
 * @ghidraAddress 0x1a5154
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Lays the header out for a pack: sizes the name and comment to their text, positions the
 * link button, moves the relation strip below the content, and resizes the header to fit.
 * @param packInfo The pack to display.
 * @ghidraAddress 0x1a6370
 */
- (void)loadPackInfo:(nullable StorePackInfo *)packInfo;

/**
 * @brief Sets the artwork and rebuilds its reflection.
 * @param artwork The artwork image.
 * @ghidraAddress 0x1a6e54
 */
- (void)setArtwork:(nullable UIImage *)artwork;

/**
 * @brief Colours the relation-tab strip for a selected tab.
 * @param selectedIndex The index of the currently selected tab.
 * @param selectable Whether the unselected tabs read as tappable (accent) or dimmed (grey).
 * @ghidraAddress 0x1a6ffc
 */
- (void)setRelationColor:(int)selectedIndex selectable:(BOOL)selectable;

/**
 * @brief Handles a tap on a relation-tab button.
 * @param sender The tapped button.
 * @ghidraAddress 0x1a6fec
 */
- (void)tapRelationButton:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
