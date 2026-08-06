/** @file
 * One mission sheet's row in the challenge mission list.
 *
 * Reconstructed from Ghidra program Jubeat (class ChallengeMissionListCell, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UITableViewCell, from the dyld bind at the class object's superclass slot
 * (0x34dbc0).
 *
 * The initialiser builds nothing. Every subview is created lazily by the setter that first needs
 * it, and each is built once — a later call to the same setter only replaces the content. That
 * makes @c -setBgImage: an ordering requirement rather than a convenience: the other two setters
 * measure themselves against the background and return without doing anything if it is not there
 * yet.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A row showing a mission sheet's icon, title and period over a background image.
 */
@interface ChallengeMissionListCell : UITableViewCell

/**
 * @brief Makes the row transparent and unhighlightable.
 *
 * No subview is created here.
 *
 * @param style The cell style.
 * @param reuseIdentifier The reuse identifier.
 * @return The initialised row.
 * @ghidraAddress 0xa9dc8
 */
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(nullable NSString *)reuseIdentifier;

/**
 * @brief Sets the row's background, creating the background view at the image's own size.
 *
 * Must be called before the other two setters; both return early without it.
 *
 * @param bgImg The background.
 * @ghidraAddress 0xaa160
 */
- (void)setBgImage:(nullable UIImage *)bgImg;

/**
 * @brief Sets the row's two lines of text, creating the labels on the first call.
 *
 * With a period the two labels straddle the background's vertical centre; without one the title
 * sits on it. Does nothing if the background view does not exist yet.
 *
 * @param title The sheet's name.
 * @param period The sheet's run of dates, or nil for a single centred line.
 * @ghidraAddress 0xa9e64
 */
- (void)setTitle:(nullable NSString *)title period:(nullable NSString *)period;

/**
 * @brief Sets the row's icon and whether the row is marked as chosen.
 *
 * The chosen state is a border on the background, not on the icon. Does nothing if the background
 * view does not exist yet.
 *
 * @param iconImg The icon. The icon view is only created when this is non-nil.
 * @param selectedImage Whether to draw the chosen border. Despite the name this is a flag, not an
 * image — the metadata types it @c B .
 * @ghidraAddress 0xaa248
 */
- (void)setIconImage:(nullable UIImage *)iconImg selectedImage:(BOOL)selectedImage;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
