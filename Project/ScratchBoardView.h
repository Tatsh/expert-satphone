/** @file
 * The scratch board: a 4×4 grid of scratch panels with a message view.
 *
 * Reconstructed from Ghidra program Jubeat (class ScratchBoardView, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base. The class object is at 0x34d398.
 */

#import <UIKit/UIKit.h>

#import "ScratchMessageView.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A board of sixteen scratch panels over their backgrounds, plus a count/message view.
 */
@interface ScratchBoardView : UIView

/**
 * @brief The delegate forwarded to every scratch panel and the message view. Held weakly.
 * @ghidraAddress 0x821f8 (getter)
 */
@property(nonatomic, weak, nullable) id aDelegate;

/**
 * @brief Builds the board, its panel grid, and the message view, scaled for the device.
 * @param frame The board's frame.
 * @return The initialised board.
 * @ghidraAddress 0x818ac
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Sets the delegate on the board and forwards it to every panel.
 * @param delegate The delegate.
 * @ghidraAddress 0x81e00
 */
- (void)setDelegate:(nullable id)delegate;

/**
 * @brief Refreshes the message view's scratch count from the challenge status.
 * @ghidraAddress 0x81f58
 */
- (void)refreshScratchCount;

/**
 * @brief Refreshes every panel's enabled state from the challenge status.
 * @ghidraAddress 0x81fcc
 */
- (void)refreshScratchTable;

/**
 * @brief Forwards a timer tick to every panel and the message view.
 * @ghidraAddress 0x820f0
 */
- (void)timerUpdate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
