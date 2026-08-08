/** @file
 * The message-board modal that downloads and shows a text message with an Agree button.
 *
 * Reconstructed from Ghidra program Jubeat (class MessageTextView, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIView . The view's backing layer is a @c CAGradientLayer (see
 * @c +layerClass ) because @c -createMessageBoard: paints the board's paper gradient straight into
 * @c self.layer with @c setColors: and @c setLocations: .
 *
 * The view either downloads its body text from a signed endpoint (the URL initialiser) or is handed
 * the text directly (the message initialiser). It reports back to its delegate through
 * @c -closeMessage: and @c -messageDownloadError:msgStr: , dispatched dynamically.
 */

#import <UIKit/UIKit.h>

@class SessionDownloader;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Told when the message board closes or when its download fails.
 *
 * Both messages are sent through @c -respondsToSelector: / @c -performSelector: , so the delegate
 * may implement either, both, or neither.
 */
@protocol MessageTextViewDelegate <NSObject>
@optional
/**
 * @brief Sent when the user taps Agree and the board has begun its exit animation.
 * @param sender The message board.
 */
- (void)closeMessage:(nullable id)sender;
/**
 * @brief Sent when the message could not be downloaded.
 * @param sender The message board.
 * @param msgStr The server-supplied error text, or a localized network-error fallback.
 */
- (void)messageDownloadError:(nullable id)sender msgStr:(nullable NSString *)msgStr;
@end

/**
 * @brief A rounded, gradient-filled board that shows a title, a scrollable message body, and an
 * Agree button, fading itself in and out.
 */
@interface MessageTextView : UIView

/**
 * @brief The backing layer class, a @c CAGradientLayer so the board can host its paper gradient.
 * @return @c CAGradientLayer 's class.
 * @ghidraAddress 0xfab64
 */
+ (Class)layerClass;

/**
 * @brief Builds the board and kicks off a signed download of its body text.
 *
 * Stores @p delegate weakly and @p title as the board title, then opens a
 * @c SessionDownloader against @p url with @p send as the POST body and starts it; the board is
 * laid out later from @c -downloaderFinished: .
 * @param delegate The object told when the board closes or the download fails. Held weakly.
 * @param title The board's title text.
 * @param url The endpoint the body text is fetched from.
 * @param send The POST parameters.
 * @return The initialised board.
 * @ghidraAddress 0xfab78
 */
- (nullable instancetype)init:(nullable id<MessageTextViewDelegate>)delegate
                        title:(nullable NSString *)title
                          url:(nullable NSURL *)url
                         send:(nullable NSDictionary *)send;

/**
 * @brief Builds the board immediately from a title and a ready message body.
 *
 * Stores @p delegate weakly and @p title as the board title, then lays the board out at once with
 * @p message as the body text.
 * @param delegate The object told when the board closes. Held weakly.
 * @param title The board's title text.
 * @param message The body text.
 * @return The initialised board.
 * @ghidraAddress 0xfad40
 */
- (nullable instancetype)init:(nullable id<MessageTextViewDelegate>)delegate
                        title:(nullable NSString *)title
                      message:(nullable id)message;

/**
 * @brief Forwards a download failure to the delegate, if it responds.
 * @param msgStr The error text passed on to the delegate.
 * @ghidraAddress 0xfaeb0
 */
- (void)sendErrorDelegate:(nullable NSString *)msgStr;

/**
 * @brief Handles a completed download: builds the board, closes on a stale-client status, or
 * reports the error.
 *
 * Reads the JSON body: status 0 lays the board out with the @c policy text; status 100011 (a
 * client too old to continue) closes the board and shows the update alert; any other status or a
 * missing status reports the @c err_message (or a localized fallback) to the delegate.
 * @param downloader The finished request.
 * @ghidraAddress 0xfaf58
 */
- (void)downloaderFinished:(nullable id)downloader;

/**
 * @brief Handles a failed download by reporting a nil error to the delegate.
 * @param downloader The failed request.
 * @ghidraAddress 0xfb1c8
 */
- (void)downloaderError:(nullable id)downloader;

/**
 * @brief Progress callback; does nothing.
 * @param downloader The request.
 * @ghidraAddress 0xfb1d8
 */
- (void)downloaderProceed:(nullable id)downloader;

/**
 * @brief Displays a message; does nothing.
 * @param message The message.
 * @ghidraAddress 0xfb1dc
 */
- (void)displayMessage:(nullable id)message;

/**
 * @brief Lays out the whole board: the gradient paper, the title label, the scrollable body text
 * view, and the Agree button, then fades them in.
 * @param message The body text shown in the text view.
 * @ghidraAddress 0xfb1e0
 */
- (void)createMessageBoard:(nullable id)message;

/**
 * @brief The Agree button action: fades the board out and notifies the delegate it has closed.
 * @param sender The Agree button.
 * @ghidraAddress 0xfbc98
 */
- (void)pushAgree:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
