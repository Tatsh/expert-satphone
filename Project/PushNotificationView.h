/**
 * @file
 * A sliding push-notification banner that pops queued local notices.
 *
 * Reconstructed from Ghidra program Jubeat (class PushNotificationView, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base. The class object is at
 * 0x34e068.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A banner that slides a queued notification in from off-screen, holds it, and slides it
 * out.
 */
@interface PushNotificationView : UIView

/**
 * Builds the banner off-screen with its balloon, label, and tap button.
 * @param frame The banner's frame.
 * @param delegate The object told when a notice with a URL is tapped; held weakly.
 * @return The initialised banner.
 * @ghidraAddress 0xc8f98
 */
- (instancetype)initWithFrame:(CGRect)frame delegate:(nullable id)delegate;

/**
 * Starts displaying notifications if not already active.
 * @ghidraAddress 0xc9a10
 */
- (void)startNotification;

/**
 * Slides the current notification out and stops displaying.
 * @ghidraAddress 0xc9a30
 */
- (void)stopNotification;

/**
 * Whether a notification is currently being displayed.
 * @ghidraAddress 0xc9d34
 */
@property(nonatomic, readonly, getter=isActive) BOOL active;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
