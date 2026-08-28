/** @file
 * One challenge-mission row inside a mission sheet.
 *
 * Reconstructed from Ghidra program Jubeat (class ChallengeMissionSheetCell, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIView, taken from the @c [super initWithFrame:] chain in the initialiser.
 *
 * The row draws a mission's icon inside an animated @c PieChartView progress ring, an achievement
 * percentage rendered from per-digit images, a completion or skip stamp, and an invisible button
 * spanning the ring that turns taps and long presses into delegate callbacks.
 */

#import <UIKit/UIKit.h>

#import "PieChartView.h"

NS_ASSUME_NONNULL_BEGIN

@class ChallengeMissionTerms;
@class ChallengeMissionAchieve;
@class ChallengeMissionSheetCell;

/**
 * @brief The cell's delegate: told when the row is tapped or long-pressed, and when the stamp
 *        animation finishes. Every callback is optional and reached through
 *        @c -respondsToSelector: / @c -performSelector: .
 */
@protocol ChallengeMissionSheetCellDelegate <NSObject>
@optional
/**
 * @brief The row was tapped.
 * @param cell The tapped cell.
 */
- (void)tapStampCell:(ChallengeMissionSheetCell *)cell;
/**
 * @brief The row was long-pressed.
 * @param cell The pressed cell.
 */
- (void)pressStampCell:(ChallengeMissionSheetCell *)cell;
/**
 * @brief The cell's stamp animation finished.
 * @param cell The cell whose animation finished.
 */
- (void)stampAnimationEnd:(ChallengeMissionSheetCell *)cell;
@end

/**
 * @brief A mission row: an icon in a progress ring, a percentage, a stamp, and a marker.
 */
@interface ChallengeMissionSheetCell : UIView <PieChartViewDelegate>

/**
 * @brief The delegate told when the stamp animation ends and when the row is tapped or pressed.
 *        Held weakly.
 * @ghidraAddress 0x1003421c0 (getter selector)
 */
@property(nonatomic, weak, nullable) id<ChallengeMissionSheetCellDelegate> aDelegate;

/**
 * @brief Builds the row: the ring, its icon, the percentage digits, the stamp, and the tap button.
 * @param frame The row's frame; every subview is laid out inset by ten points.
 * @return The initialised row.
 * @ghidraAddress 0x84144
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Renders the achievement percentage into the three digit views and centres it.
 * @ghidraAddress 0x84ac4
 */
- (void)setRateNumber;

/**
 * @brief Populates the row from a mission's terms and achievement record.
 *
 * Sets the title and icon, chooses the completion or skip stamp, computes the achievement rate
 * from the mission and achievement counts, and enables the row.
 *
 * @param terms The mission's terms.
 * @param achieve The mission's achievement record.
 * @return The computed achievement rate.
 * @ghidraAddress 0x84d78
 */
- (float)setMissionInfo:(nullable ChallengeMissionTerms *)terms
                achieve:(nullable ChallengeMissionAchieve *)achieve;

/**
 * @brief Sets the row's marker state. The shipped body does nothing.
 * @param marker The requested marker state.
 * @ghidraAddress 0x85378
 */
- (void)setMarker:(BOOL)marker;

/**
 * @brief Greys the row out: clears its background, hides the icon and percentage, and repaints the
 *        ring in the muted disabled palette.
 * @ghidraAddress 0x8537c
 */
- (void)disableCell;

/**
 * @brief Marks the row as an undecided mission: shows the lock icon and hides the percentage.
 * @ghidraAddress 0x85580
 */
- (void)undiceidedCell;

/**
 * @brief Reveals the row: animates the ring towards its rate, then either plays the stamp
 *        animation or tells the delegate the stamp animation is already done.
 * @ghidraAddress 0x855fc
 */
- (void)missionOpen;

/**
 * @brief Plays the stamp animation. The shipped body does nothing.
 * @ghidraAddress 0x85968
 */
- (void)stampAnimation;

/**
 * @brief The detail button's touch-up handler: tells the delegate the row was tapped.
 * @ghidraAddress 0x8596c
 */
- (void)tapDetail;

/**
 * @brief The long-press recogniser's handler: tells the delegate the row was pressed.
 * @ghidraAddress 0x85a44
 */
- (void)longPressBtnMode;

/**
 * @brief Enables or disables the row's detail touches.
 * @param enable Whether taps and long presses are forwarded to the delegate.
 * @ghidraAddress 0x85b1c
 */
- (void)enableTouch:(BOOL)enable;

/**
 * @brief The @c PieChartView delegate callback: when the ring reaches a full rate, fades the
 *        completion stamp in.
 * @ghidraAddress 0x85b2c
 */
- (void)chartAnimationEnd;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
