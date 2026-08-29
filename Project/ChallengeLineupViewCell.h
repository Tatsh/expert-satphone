/**
 * @file
 * One row of the challenge lineup, optionally with a store button.
 *
 * Reconstructed from Ghidra program Jubeat (class ChallengeLineupViewCell, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UITableViewCell, taken from the dyld bind at the class object's superclass
 * slot (0x34f5b0) rather than from the name.
 *
 * The plate, artwork and label metrics are the same figures @c ChallengePrevRankingListViewCell
 * uses, from the same pool slots. What this class adds is the store button — and that button
 * exists on the pad only.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * How a store type maps onto the button's state.
 *
 * The raw values are the two compares in @c -setLineupCell:name:bgImg:storeType: ; the names are
 * inferred from what each arm does, since the metadata types the argument only as @c i.
 */
typedef NS_ENUM(int, ChallengeLineupStoreType) {
    ChallengeLineupStoreTypeAvailable = 0, /*!< Button shown and tappable. */
    ChallengeLineupStoreTypeOwned = 1,     /*!< Button shown but disabled. */
};

/**
 * What a @c ChallengeLineupViewCell tells its owner.
 */
@protocol ChallengeLineupViewCellDelegate <NSObject>
@optional
/**
 * Sent when the row's store button is tapped.
 * @param cell The row that was tapped — not the button.
 */
- (void)tapStoreBtn:(id)cell;
@end

/**
 * A lineup row: a plate, a square artwork, a name, and on the pad a store button.
 */
@interface ChallengeLineupViewCell : UITableViewCell

/**
 * The object told when the store button is tapped.
 *
 * Weak and untyped in the metadata.
 * @ghidraAddress 0x14607c (getter)
 */
@property(nonatomic, weak) id aDelegate;

/**
 * Builds the row at the metrics for the current idiom.
 *
 * On the phone the store button is never created, so the row is plate, artwork and label only and
 * the label takes the full remaining width.
 * @param style The cell style.
 * @param reuseIdentifier The reuse identifier, or nil for a non-reusable cell.
 * @return The initialised cell.
 * @ghidraAddress 0x145a60
 */
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(nullable NSString *)reuseIdentifier;

/**
 * Fills the row in and sets the store button's state.
 *
 * A store type outside the two named values hides the button and leaves its enabled state alone.
 *
 * @param lineupCell The square artwork.
 * @param name The row's name.
 * @param bgImg The plate.
 * @param storeType Which button state to show.
 * @ghidraAddress 0x145e74
 */
- (void)setLineupCell:(nullable UIImage *)lineupCell
                 name:(nullable NSString *)name
                bgImg:(nullable UIImage *)bgImg
            storeType:(int)storeType;

/**
 * The store button's action.
 *
 * Takes no argument, unlike the tap handlers on the other cells in this tree, and hands the
 * delegate the cell.
 * @ghidraAddress 0x145fa8
 */
- (void)tapStoreMove;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
