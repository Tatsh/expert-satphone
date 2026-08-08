/** @file
 * The applilink recommendation web view — a self-delegating UIWebView.
 *
 * Reconstructed from Ghidra program Jubeat (class ApplilinkWebView, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base. The class object is at 0x351d58.
 * Part of the shared Konami applilink SDK.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief What an @c ApplilinkWebView tells its SDK delegate.
 *
 * The protocol's name is the binary's own, from the delegate ivar's encoding
 * @c \@"<SdkViewDelegate>" .
 */
@protocol SdkViewDelegate <NSObject>
@optional
/** @brief The view finished loading and is ready. */
- (void)viewReady:(nonnull id)webView;
/** @brief A "close" link was followed. */
- (void)closeNotice:(nonnull id)webView;
/** @brief A "repeat" link was followed. */
- (void)repeatNotice:(nonnull id)webView;
/** @brief A "store" link was followed. */
- (void)storeNotice:(nonnull id)webView;
/** @brief A load error occurred. */
- (void)linkErrorNotice:(nonnull id)webView error:(nonnull NSError *)error;
@end

/**
 * @brief A UIWebView that hosts applilink recommendation content and routes its custom link
 * schemes to an SDK delegate.
 */
@interface ApplilinkWebView : UIWebView <UIWebViewDelegate>

/**
 * @brief The SDK delegate told about ready/close/repeat/store/error events. Held weakly.
 * @ghidraAddress 0x22e660 (getter)
 */
@property(nonatomic, weak, nullable) id<SdkViewDelegate> sdkDelegate;

/**
 * @brief The load state: 0 before loading, 1 loading, 2 loaded.
 * @ghidraAddress 0x22e678 (getter)
 */
@property(nonatomic) int webViewStatus;

/**
 * @brief Builds the web view, opaque-white and self-delegating.
 * @param frame The view's frame.
 * @return The initialised view.
 * @ghidraAddress 0x22dc50
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Forwards a store link to the SDK delegate.
 * @ghidraAddress 0x22e5dc
 */
- (void)storeAction;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
