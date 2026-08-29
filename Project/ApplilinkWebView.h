/**
 * @file
 * @brief The applilink recommendation web view — a self-delegating UIWebView.
 *
 * Reconstructed from Ghidra program Jubeat (class ApplilinkWebView, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base. The class object is at 0x351d58.
 * Part of the shared Konami applilink SDK.
 */

#import <UIKit/UIKit.h>

#import "ApplilinkStore.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A UIWebView that hosts applilink recommendation content and routes its custom link
 * schemes to an SDK delegate. The @c SdkViewDelegate protocol it messages (@c viewReady: ,
 * @c closeNotice: , @c repeatNotice: , @c storeNotice: , @c linkErrorNotice:error: ) is the single
 * SDK-wide protocol declared in @c ApplilinkStore.h , not a separate web-view protocol.
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
