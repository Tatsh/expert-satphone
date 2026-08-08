/** @file
 * Marker download progress view.
 *
 * Reconstructed from Ghidra program Jubeat (class MarkerDownloadView, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: a stub. Only the members reached so far are declared.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The view shown while markers are being checked and downloaded.
 */
@interface MarkerDownloadView : UIView

/**
 * @brief Sets the delegate that is notified when the check finishes.
 * @param delegate The delegate.
 * @ghidraAddress 0x1b74e4
 */
- (void)setDelegate:(id)delegate;

/**
 * @brief Shows the view and starts the check.
 * @ghidraAddress 0x1b7500
 */
- (void)show;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
