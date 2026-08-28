/** @file
 * The banner showing how many free scratches remain and when they reset.
 *
 * Reconstructed from Ghidra program Jubeat (class ScratchMessageView, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIView.
 *
 * Unlike the rest of this tree, which carries a separate constant per idiom, this view lays out in
 * pad coordinates and multiplies everything by @c -[ChallengeStatus phoneScreenRate] on the phone.
 * All of that arithmetic is single precision.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A remaining-scratches digit and a countdown to the next reset.
 */
@interface ScratchMessageView : UIView

/**
 * @brief Builds the digit and the countdown label, scaled for the current idiom.
 * @param frame The view's initial frame.
 * @return The initialised view.
 * @ghidraAddress 0x73c20
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Shows a remaining-scratch count.
 *
 * Counts above nine are clamped to nine rather than rejected, since the artwork is a single digit.
 *
 * @param scratchCnt How many scratches remain.
 * @ghidraAddress 0x73fb8
 */
- (void)setScratchCnt:(int)scratchCnt;

/**
 * @brief Refreshes the countdown text from the shared challenge state.
 *
 * Under one second remaining shows a fixed expiry message instead of a countdown.
 * @ghidraAddress 0x74054
 */
- (void)timerUpdate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
