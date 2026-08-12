/** @file
 * The applilink reward SDK's in-application web-view host controller.
 *
 * @c RewardWebViewController is the reward-advert SDK's in-application web-view host: a
 * @c UIViewController that owns a base @c UIView, a @c UIWebView, an optional @c UINavigationBar
 * with a close button, and an @c ApplilinkIndicator loading overlay. It loads the reward-advert
 * page, tracks the load through the @c UIWebViewDelegate callbacks, intercepts the SDK
 * @c applilink:// schemes (close and @c ext-app movie), injects the applilink-domain cookies on a
 * server redirect, rotates its content to follow the status-bar orientation, and reports the advert
 * lifecycle back to its @c SdkViewDelegate. It is created and driven by @c RewardCore.
 *
 * Reconstructed from Ghidra program Jubeat (image base 0x100000000). All @ghidraAddress values are
 * offsets relative to that image base. This is a closed SDK class, but the jubeat build routes
 * @c ext-app movie links to
 * @c RewardCore -showVideoViewWithQuery:, injects the applilink cookies on a redirect reload, and
 * carries a @c -closeNotice: relay into @c ApplilinkViewManager.
 */

#import <UIKit/UIKit.h>

#import "ApplilinkIndicator.h"
#import "ApplilinkStore.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The current load state of the advert web view.
 */
typedef NS_ENUM(int, RewardWebViewControllerWebViewStatus) {
    RewardWebViewControllerWebViewStatusIdle = 0,     /*!< No load has started. */
    RewardWebViewControllerWebViewStatusLoading = 1,  /*!< A load is in progress. */
    RewardWebViewControllerWebViewStatusFinished = 2, /*!< The load has finished. */
};

/**
 * @brief The in-application host controller for the reward-advert web page.
 */
@interface RewardWebViewController : UIViewController

/**
 * @brief The SDK delegate that receives the advert lifecycle notices.
 *
 * Held weakly: the controller forwards each notice to it but does not own it, and clears the
 * reference once the closing or open-failure notice has been sent.
 */
@property(weak, nonatomic, nullable) id<SdkViewDelegate> sdkDelegate;

/**
 * @brief The host view the advert web view is added to.
 *
 * When @c nil the advert is added to @c [ApplilinkCore mainWindow] instead.
 */
@property(strong, nonatomic, nullable) UIView *parentView;

/**
 * @brief The container view that hosts the web view and navigation bar.
 */
@property(strong, nonatomic, nullable) UIView *baseView;

/**
 * @brief The web view that renders the reward-advert page.
 */
@property(strong, nonatomic, nullable) UIWebView *webView;

/**
 * @brief The navigation bar carrying the advert title and close button.
 *
 * Created only when the navigation bar is not hidden.
 */
@property(strong, nonatomic, nullable) UINavigationBar *navigationBar;

/**
 * @brief The loading overlay shown while the advert page loads.
 */
@property(strong, nonatomic, nullable) ApplilinkIndicator *indicator;

/**
 * @brief Whether the advert screen hides its navigation bar.
 */
@property(nonatomic) BOOL isNavigationBarHidden;

/**
 * @brief Whether the web view's scroll view is allowed to bounce.
 *
 * The stored value is inverted by @c -setWebViewBounces:, then cleared after @c -loadView applies
 * it to the scroll view.
 */
@property(nonatomic) BOOL webViewBounces;

/**
 * @brief The current load state of the advert web view.
 */
@property(nonatomic) RewardWebViewControllerWebViewStatus webViewStatus;

/**
 * @brief Set whether the advert screen hides its navigation bar.
 *
 * This is the SDK-facing alias for @c isNavigationBarHidden used by @c RewardCore; it stores
 * straight into the backing ivar, distinct from the synthesized @c -setIsNavigationBarHidden:.
 * @param navigationBarHidden @c YES to hide the navigation bar.
 * @ghidraAddress 0x24cd64
 */
- (void)setNavigationBarHidden:(BOOL)navigationBarHidden;

/**
 * @brief Show or hide the loading overlay.
 * @param show @c YES to show the overlay, @c NO to hide it.
 * @ghidraAddress 0x24d130
 */
- (void)updateIndicator:(BOOL)show;

/**
 * @brief Load the reward-advert page from a URL with request parameters.
 *
 * Resets the load state, attaches the controller's view to @c parentView (or the main window),
 * builds a thirty-second, no-cache mutable request with the parameters appended to the URL, lazily
 * creates the web view, aligns it to the current status-bar orientation, and starts the load.
 * @param url The reward-advert page URL string.
 * @param parameters The request parameters to append as a query string.
 * @ghidraAddress 0x24cd7c
 */
- (void)loadRequestWithURL:(nullable NSString *)url parameters:(nullable NSDictionary *)parameters;

/**
 * @brief Present the reward-video view for @p query through @c RewardCore.
 * @param query The video request query.
 * @ghidraAddress 0x24d018
 */
- (void)showVideoViewWithQuery:(nullable NSString *)query;

/**
 * @brief Close the advert list from an external request.
 *
 * Cancels the pending indicator activation, marks the view closed, stops any in-flight load, and
 * tears the advert web view down.
 * @ghidraAddress 0x24d090
 */
- (void)appliListClosed;

/**
 * @brief Relay a close notice through @c ApplilinkViewManager.
 * @param view The view reporting the close.
 * @ghidraAddress 0x24dc64
 */
- (void)closeNotice:(nullable id)view;

/**
 * @brief Tear down the advert web view and release its subviews.
 * @ghidraAddress 0x24cc54
 */
- (void)viewDealloc;

/**
 * @brief Clear the SDK delegate and detach the web view's delegate.
 * @ghidraAddress 0x24f208
 */
- (void)clearDelegate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
