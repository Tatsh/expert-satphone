/** @file
 * The settings-screen "inquiry" (contact/support) view controller.
 *
 * Reconstructed from Ghidra program Jubeat (class SettingsInquiryViewController, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base. It hosts a
 * @c UIWebView that loads the Konami support "inquiry" page over a loading indicator, and acts as
 * that web view's delegate: it clears the URL cache when a load starts, stamps the app user agent
 * onto outgoing resource requests, intercepts @c openurl:// links to open them externally, and
 * stops the indicator (or shows a network-error alert) when the load finishes or fails.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A view controller presenting the support inquiry page in a @c UIWebView.
 */
@interface SettingsInquiryViewController : UIViewController <UIWebViewDelegate>

/**
 * @brief Initialises the controller and builds its request and title from the inquiry URL.
 * @return The initialised controller.
 * @ghidraAddress 0xd8908
 */
- (instancetype)init;

/**
 * @brief Builds the web view and loading indicator, then loads the inquiry request. Called after
 *        the view is available; the request is built from @c +[ScratchUtil getInquiryURL].
 * @ghidraAddress 0xd8964
 */
- (void)initPageView;

/**
 * @brief Initialises the controller to load an explicit URL instead of the inquiry URL.
 * @param url The URL string to load.
 * @return The initialised controller.
 * @ghidraAddress 0xd8ccc
 */
- (instancetype)initWithURL:(nullable NSString *)url;

/**
 * @brief Clears the shared URL cache when a load starts.
 * @param webView The web view that started loading.
 * @ghidraAddress 0xd8de4
 */
- (void)webViewDidStartLoad:(UIWebView *)webView;

/**
 * @brief Resource-load hook that stamps the app's user agent onto every outgoing request.
 * @ghidraAddress 0xd8e2c
 */
- (nullable NSURLRequest *)uiWebView:(nullable id)uiWebView
                            resource:(nullable id)resource
                     willSendRequest:(nullable NSMutableURLRequest *)request
                    redirectResponse:(nullable NSURLResponse *)redirectResponse
                      fromDataSource:(nullable id)dataSource;

/**
 * @brief Intercepts the page's @c openurl:// links: rewrites them to @c https:// , opens them
 *        externally, and pops this controller. Returns @c NO for a handled link and @c YES
 *        otherwise.
 * @ghidraAddress 0xd8f74
 */
- (BOOL)webView:(UIWebView *)webView
    shouldStartLoadWithRequest:(NSURLRequest *)request
                navigationType:(UIWebViewNavigationType)navigationType;

/**
 * @brief Stops and removes the loading indicator when a load finishes.
 * @param webView The web view that finished loading.
 * @ghidraAddress 0xd912c
 */
- (void)webViewDidFinishLoad:(UIWebView *)webView;

/**
 * @brief Shows a network-error alert on a load failure.
 * @ghidraAddress 0xd9188
 */
- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error;

/**
 * @brief Whether to rotate to a given interface orientation; portrait and portrait-upside-down
 *        only.
 * @ghidraAddress 0xd9270
 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;

/**
 * @brief The supported interface orientations: portrait and portrait-upside-down.
 * @ghidraAddress 0xd9280
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations;

/**
 * @brief Whether the controller supports autorotation; always @c YES.
 * @ghidraAddress 0xd9288
 */
- (BOOL)shouldAutorotate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
