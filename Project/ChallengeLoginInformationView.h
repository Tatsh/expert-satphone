/** @file
 * The challenge-mode login/information modal — a self-delegating @c UIWebView sheet.
 *
 * Reconstructed from Ghidra program Jubeat (class ChallengeLoginInformationView, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base. The sheet
 * hosts the jubeat lab login/information page, shows a loading indicator, and intercepts the
 * page's @c twitter:// , @c openurl:// , and @c jbtstore:// links.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief What a @c ChallengeLoginInformationView tells its owner. The delegate ivar is untyped
 * (@c \@) in the binary and every message is guarded by @c -respondsToSelector: , so all methods
 * are optional.
 */
@protocol ChallengeLoginInformationViewDelegate <NSObject>
@optional
/** @brief The sheet's close button was tapped and the owner should dismiss the login sheet. */
- (void)closeLoginInformation;
/** @brief The close button was tapped and, lacking @c closeLoginInformation , the owner should
 * close its menu instead. */
- (void)closeMenu;
/**
 * @brief A @c jbtstore://pack/\<id\> link was followed.
 * @param info A dictionary @c \@{\@"pack": \<id\>} , or @c nil when the link carries no id.
 */
- (void)clickPackInfomation:(nullable NSDictionary *)info;
@end

/**
 * @brief A @c UIWebView sheet that shows the challenge login/information page and routes its
 * custom link schemes back to a delegate.
 */
@interface ChallengeLoginInformationView : UIView <UIWebViewDelegate>

/**
 * @brief Whether this sheet stands alone (plays its own close sound); backed by @c _bIndependMenu .
 */
@property(nonatomic) BOOL bIndependMenu;

/** @brief The owner told about close and pack-link events. Held weakly; backed by @c _aDelegate .
 */
@property(nonatomic, weak, nullable) id<ChallengeLoginInformationViewDelegate> aDelegate;

/**
 * @brief The designated initialiser.
 * @param frame The sheet's frame in its superview.
 * @param dispURL The page URL to load; when @c nil the challenge information URL is used.
 * @param btnType The close-button art selector; @c 1 uses the "back" image, otherwise "cancel".
 * @return The initialised sheet.
 * @ghidraAddress 0xaf19c
 */
- (instancetype)initWithFrame:(CGRect)frame
                      dispURL:(nullable NSString *)dispURL
                      btnType:(int)btnType;

/**
 * @brief Builds the sheet's subviews and starts loading. Funnelled to by the designated
 * initialiser.
 * @param frame The view's initial frame.
 * @return The initialised view.
 * @ghidraAddress 0xaf244
 */
- (instancetype)initWithFrame:(CGRect)frame;

/**
 * @brief Loads the sheet's request into the web view, building one from @c dispURL when
 * @c firstRequest is not already set.
 * @ghidraAddress 0xaf914
 */
- (void)notificationRequest;

/**
 * @brief Close-button action: plays the close sound when independent, then notifies the delegate.
 * @param sender The close button.
 * @ghidraAddress 0xaf9e0
 */
- (void)closeMessage:(nullable id)sender;

/**
 * @brief Resource-load hook that stamps the app's user agent onto every outgoing request.
 * @param uiWebView The web view loading the resource.
 * @param resource The resource being loaded.
 * @param request The outgoing request, stamped with the user agent.
 * @param redirectResponse The redirect that led here, or nil when there was none.
 * @param dataSource The data source driving the load.
 * @return The request to send.
 * @ghidraAddress 0xafb4c
 */
- (nullable NSURLRequest *)uiWebView:(nullable id)uiWebView
                            resource:(nullable id)resource
                     willSendRequest:(nullable NSMutableURLRequest *)request
                    redirectResponse:(nullable NSURLResponse *)redirectResponse
                      fromDataSource:(nullable id)dataSource;

/**
 * @brief Intercepts the page's custom link schemes; returns @c NO for a handled link and @c YES to
 * let the web view load the request.
 * @param webView The web view asking.
 * @param request The request it is about to load.
 * @param navigationType What triggered the navigation.
 * @return NO for a handled custom-scheme link, YES to let the web view load the request.
 * @ghidraAddress 0xafc94
 */
- (BOOL)webView:(UIWebView *)webView
    shouldStartLoadWithRequest:(NSURLRequest *)request
                navigationType:(UIWebViewNavigationType)navigationType;

/**
 * @brief Stops and removes the loading indicator.
 * @ghidraAddress 0xb00a8
 */
- (void)stopIndicator;

/**
 * @brief Shows a network-error alert and stops the indicator on a load failure.
 * @param webView The web view reporting the failure.
 * @param error The load failure.
 * @ghidraAddress 0xb0104
 */
- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error;

/**
 * @brief Clears the shared URL cache when a load starts.
 * @param webView The web view that started loading.
 * @ghidraAddress 0xb01f8
 */
- (void)webViewDidStartLoad:(UIWebView *)webView;

/**
 * @brief Stops the indicator and disables the WebKit touch callout when a load finishes.
 * @param webView The web view that finished loading.
 * @ghidraAddress 0xb0240
 */
- (void)webViewDidFinishLoad:(UIWebView *)webView;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
