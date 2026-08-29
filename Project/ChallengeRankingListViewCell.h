/**
 * @file
 * One row of the challenge ranking list.
 *
 * Reconstructed from Ghidra program Jubeat (class ChallengeRankingListViewCell, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UITableViewCell, taken from the dyld bind at the class object's superclass
 * slot (0x34f7e0) rather than from the name.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A ranking row: rank, name and score across the plate, with a two-digit badge at its
 * leading edge.
 */
@interface ChallengeRankingListViewCell : UITableViewCell

/**
 * Weak and untyped, per the metadata. Nothing this class defines reads it.
 * @ghidraAddress 0x154704 (getter)
 */
@property(nonatomic, weak) id aDelegate;

/**
 * Builds the plate, the three labels and the badge at the metrics for the current idiom.
 * @param style The cell style.
 * @param reuseIdentifier The reuse identifier, or nil for a non-reusable cell.
 * @return The initialised cell.
 * @ghidraAddress 0x153f88
 */
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(nullable NSString *)reuseIdentifier;

/**
 * Fills the row in, and re-frames the plate.
 *
 * Note it sets the plate's frame on every call rather than leaving the one the initialiser gave
 * it, so the plate's size is re-established from the device idiom each time.
 *
 * @param rivalInfo The plate artwork.
 * @param rank The rank text.
 * @param name The rival's name.
 * @param score The score text.
 * @ghidraAddress 0x1544d0
 */
- (void)setRivalInfo:(nullable UIImage *)rivalInfo
                rank:(nullable NSString *)rank
                name:(nullable NSString *)name
               score:(nullable NSString *)score;

/**
 * Sets the badge and its two digits.
 *
 * The two digit views are laid out right-aligned inside the badge and abut exactly, with
 * @c digit1Image in the trailing slot and @c digit2Image in the leading one — so the first
 * argument is the lower-order digit.
 *
 * @param rivalIcon The badge artwork.
 * @param digit1Image The trailing digit.
 * @param digit2Image The leading digit.
 * @ghidraAddress 0x154648
 */
- (void)setRivalIcon:(nullable UIImage *)rivalIcon
         digit1Image:(nullable UIImage *)digit1Image
         digit2Image:(nullable UIImage *)digit2Image;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
