/**
 * @file
 * @brief The challenge coin/cube status bar with a buy-cube button.
 *
 * Reconstructed from Ghidra program Jubeat (class ChallengeStatusView, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base. The class object is at 0x34d488.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A status bar showing the play-coin count over its limit, the J-cube count, the coin
 * regeneration time, and a button to buy cubes.
 */
@interface ChallengeStatusView : UIView

/**
 * @brief The delegate told when the buy-cube button (or its confirmation) fires. Held weakly.
 * @ghidraAddress 0x86ee4 (getter)
 */
@property(nonatomic, weak, nullable) id aDelegate;

/**
 * @brief Builds the status bar: the digit slots, slash, rest-time label, and buy-cube button.
 * @param frame The bar's frame.
 * @return The initialised bar.
 * @ghidraAddress 0x85e48
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Refreshes every displayed number and the coin rest-time label from the challenge status.
 * @ghidraAddress 0x868bc
 */
- (void)updateDisplayStatus;

/**
 * @brief The per-tick refresh: regenerates a coin when its timer elapses and updates the display.
 * @ghidraAddress 0x86a84
 */
- (void)timerUpdate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
