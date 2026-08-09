/** @file
 * A modal "select where to send" panel: a dimmed, rounded gradient board carrying a title, a
 * two-row table of social targets (Twitter and Facebook), and OK/Cancel buttons.
 *
 * Reconstructed from Ghidra program Jubeat (class SocialSendSelectView, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * The class overrides @c +layerClass to back itself with a @c CAGradientLayer , and it acts as its
 * own table view's data source and delegate.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class SocialSendSelectView;

/**
 * @brief What a @c SocialSendSelectView tells its owner when a target is chosen or the panel is
 * dismissed.
 *
 * Both messages are dispatched through @c -respondsToSelector: , so the binary declares no
 * conformance and both methods are optional.
 */
@protocol SocialSendSelectViewDelegate <NSObject>
@optional
/**
 * @brief Sent when OK is pressed, carrying the chosen social service type and the message text.
 * @param socialType The selected social service type, an @c SLServiceType constant.
 * @param text The message text the panel was built with.
 */
- (void)socialSelectEnd:(nullable NSString *)socialType sendText:(nullable NSString *)text;
/**
 * @brief Sent when Cancel is pressed, carrying the panel itself.
 * @param view The panel whose Cancel button was pressed.
 */
- (void)socialSelectCancel:(nullable SocialSendSelectView *)view;
@end

/**
 * @brief A modal social-target picker over a dimmed gradient board.
 */
@interface SocialSendSelectView : UIView <UITableViewDataSource, UITableViewDelegate>

/**
 * @brief Backs the view with a @c CAGradientLayer .
 * @return The @c CAGradientLayer class.
 * @ghidraAddress 0x1bf168
 */
+ (Class)layerClass;

/**
 * @brief Builds a discardable store-style button.
 *
 * Builds a @c StoreButton at @c CGRectZero , tints it the shared blue-green, rounds and fonts it,
 * then throws it away: it is never stored nor added to any view. The argument is ignored.
 *
 * @param sender Ignored.
 * @ghidraAddress 0x1bf17c
 */
- (void)createStoreBtn:(nullable id)sender;

/**
 * @brief Builds the whole modal: the gradient board, its title, the target table with its inner
 * shadow, and the OK/Cancel buttons.
 *
 * @param message The message text handed back to the delegate when a target is chosen.
 * @param delegate The object told when a target is chosen or the panel is cancelled.
 * @return The initialised panel.
 * @ghidraAddress 0x1bf2b4
 */
- (instancetype)initWithMessage:(nullable NSString *)message
                       delegate:(nullable id<SocialSendSelectViewDelegate>)delegate;

/**
 * @brief OK button action: forwards the chosen social type and message to the delegate.
 * @param sender The OK button. Unused.
 * @ghidraAddress 0x1c00a0
 */
- (void)pushOK:(nullable id)sender;

/**
 * @brief Cancel button action: tells the delegate the panel was cancelled.
 * @param sender The Cancel button. Unused.
 * @ghidraAddress 0x1c0174
 */
- (void)pushCancel:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
