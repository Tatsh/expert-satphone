/**
 * @file
 * A music row of the store detail table: jacket artwork, title, artist, level list, a
 * sample overlay with a play indicator, and an iTunes link button.
 *
 * Reconstructed from Ghidra program Jubeat (class StoreDetailMusicCell, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass was read from the class object's superclass slot, which binds to
 * @c _OBJC_CLASS_$_UITableViewCell at load time rather than being stored in the file.
 */

#import <UIKit/UIKit.h>

#import "AlertViewManager.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * A non-selectable cell describing one downloadable music entry.
 *
 * The cell forwards its iTunes prompt through @c AlertViewManager and conforms to that manager's
 * delegate protocol so it can react to the button tap; the protocol is dispatched dynamically, so
 * this header does not import it.
 */
@interface StoreDetailMusicCell : UITableViewCell <AlertViewManagerDelegate>

/**
 * The fixed row height for this cell.
 * @return The pooled height constant, @c 80.0.
 * @ghidraAddress 0xfbebc
 */
+ (CGFloat)cellHeight;

/**
 * The jacket artwork image view.
 */
@property(strong, nonatomic, nullable) UIImageView *artworkView;

/**
 * The music title label.
 */
@property(strong, nonatomic, nullable) UILabel *labelName;

/**
 * The artist label.
 */
@property(strong, nonatomic, nullable) UILabel *labelArtist;

/**
 * The difficulty-levels label.
 */
@property(strong, nonatomic, nullable) UILabel *labelLevels;

/**
 * The overlaid "extend" badge image, added directly to the cell.
 */
@property(strong, nonatomic, nullable) UIImageView *extendImg;

/**
 * The controller used to open the iTunes link; held weakly.
 */
@property(weak, nonatomic, nullable) UIViewController *viewController;

/**
 * Designated initialiser; builds every subview.
 * @param style The cell style forwarded to @c UITableViewCell.
 * @param reuseIdentifier The reuse identifier forwarded to @c UITableViewCell.
 * @return The initialised cell.
 * @ghidraAddress 0xfbec8
 */
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(nullable NSString *)reuseIdentifier;

/**
 * Sets the background image behind the whole cell.
 * @param image The image to display, or @c nil to clear it.
 * @ghidraAddress 0xfcfc0
 */
- (void)setBgImage:(nullable UIImage *)image;

/**
 * Sets the iTunes link from a URL string and shows or hides the link button accordingly.
 * @param link The link URL string, or @c nil to clear the link and hide the button.
 * @ghidraAddress 0xfcfd8
 */
- (void)setLink:(nullable NSString *)link;

/**
 * Hides the sample overlay and stops the download spinner.
 * @ghidraAddress 0xfd094
 */
- (void)sampleStop;

/**
 * Shows the sample overlay spinning while the sample downloads.
 * @ghidraAddress 0xfd0e0
 */
- (void)sampleDownloading;

/**
 * Shows the sample overlay with the play badge while the sample plays.
 * @ghidraAddress 0xfd148
 */
- (void)samplePlaying;

/**
 * Presents the "Show in iTunes Store?" confirmation for the link button.
 * @param sender The control that triggered the action.
 * @ghidraAddress 0xfcd5c
 */
- (void)handleLink:(nullable id)sender;

/**
 * @c AlertViewManager delegate callback; opens the iTunes link when OK is tapped.
 * @param info The alert result dictionary carrying the tapped button index under @c "btnMessage".
 * @ghidraAddress 0xfd1b0
 */
- (void)alertSelect:(nonnull NSDictionary *)info;

/**
 * No-op teardown hook retained from the original.
 * @ghidraAddress 0xfd2b8
 */
- (void)terminate;

/**
 * Closes any alert presented through @c AlertViewManager.
 * @ghidraAddress 0xfd2bc
 */
- (void)detailClose;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
