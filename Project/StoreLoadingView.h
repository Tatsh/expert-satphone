/**
 * @file
 * The store's inline loading and error overlay.
 *
 * Reconstructed from Ghidra program Jubeat (class StoreLoadingView, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIView, from the dyld bind at the class object's superclass slot
 * (0x350500).
 *
 * The three subviews are built once and then added to and removed from the hierarchy rather than
 * hidden, so which of them has a superview is the view's state.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A spinner with a caption, swapped for a message when something fails.
 */
@interface StoreLoadingView : UIView

/**
 * Builds the spinner and the two labels.
 *
 * None of the three is added to the hierarchy here; @c -startLoading and @c -showError: do that.
 *
 * @param frame The overlay's frame. Every subview is centred against its size.
 * @return The initialised overlay.
 * @ghidraAddress 0x1b98d0
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * Shows the spinner and its caption, and takes the error message away.
 * @ghidraAddress 0x1b9dac
 */
- (void)startLoading;

/**
 * Hides the overlay and takes the spinner and its caption away.
 *
 * The spinner is removed rather than stopped; @c -stopAnimating is never sent.
 * @ghidraAddress 0x1b9eb4
 */
- (void)stopLoading;

/**
 * Replaces the spinner with a message.
 * @param error The message to show.
 * @ghidraAddress 0x1b9f6c
 */
- (void)showError:(nullable NSString *)error;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
