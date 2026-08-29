/**
 * @file
 * One row of the previous challenge's ranking list.
 *
 * Reconstructed from Ghidra program Jubeat (class ChallengePrevRankingListViewCell, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UITableViewCell, taken from the dyld bind at the class object's superclass
 * slot (0x34d030) rather than from the name.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A ranking row: a background plate carrying a square artwork and the player's name.
 *
 * The whole row is built in the initialiser and filled in afterwards by
 * @c -setLineupCell:name:bgImg:. It declares no properties; the three subviews are private ivars.
 */
@interface ChallengePrevRankingListViewCell : UITableViewCell

/**
 * Builds the row's three subviews at the metrics for the current device idiom.
 *
 * The pad's metrics are exactly double the phone's except for the label's height, which is 20
 * points on both.
 *
 * @param style Passed straight through to @c UITableViewCell.
 * @param reuseIdentifier Passed straight through to @c UITableViewCell.
 * @return The initialised cell.
 * @ghidraAddress 0x72ba0
 */
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(nullable NSString *)reuseIdentifier;

/**
 * Fills the row in.
 *
 * @param lineupCell The square artwork shown at the row's leading edge.
 * @param name The player's name.
 * @param bgImg The plate drawn behind the whole row.
 * @ghidraAddress 0x72de8
 */
- (void)setLineupCell:(nullable UIImage *)lineupCell
                 name:(nullable NSString *)name
                bgImg:(nullable UIImage *)bgImg;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
