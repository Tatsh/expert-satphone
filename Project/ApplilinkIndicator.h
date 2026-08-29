/**
 * @file
 * The applilink SDK's blocking activity overlay.
 *
 * Reconstructed from Ghidra program Jubeat (class ApplilinkIndicator, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIView, from the dyld bind at the class object's superclass slot
 * (0x3523a0).
 *
 * The view is a half-opaque black sheet with a spinner in the middle. It blocks touches by being
 * there; @c -touchEventActived is what stops it doing so.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A dimming sheet with a centred activity indicator.
 */
@interface ApplilinkIndicator : UIView

/**
 * The spinner. Cleared by @c -close , which does not remove it from the hierarchy.
 * @ghidraAddress 0x250398 (getter)
 */
@property(nonatomic, strong, nullable) UIActivityIndicatorView *indicator;

/**
 * Builds the sheet and its spinner.
 *
 * The spinner's own frame is a fixed square; it is only positioned in @c -layoutSubviews .
 *
 * @param frame The sheet's frame.
 * @return The initialised sheet.
 * @ghidraAddress 0x250048
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * Centres the spinner in the sheet.
 * @ghidraAddress 0x25017c
 */
- (void)layoutSubviews;

/**
 * Shows the sheet and starts the spinner.
 * @ghidraAddress 0x25022c
 */
- (void)show;

/**
 * Hides the sheet, stops the spinner, and forgets it.
 *
 * The spinner stays a subview; only the reference goes. The sheet cannot be shown again in any
 * meaningful way afterwards — see TYPES_PENDING.md.
 * @ghidraAddress 0x250284
 */
- (void)close;

/**
 * Stops the sheet blocking: clears the dimming and lets touches through.
 *
 * Despite the name it *disables* this view's own touch handling, which is what allows the views
 * behind it to receive events again.
 * @ghidraAddress 0x2502e8
 */
- (void)touchEventActived;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
