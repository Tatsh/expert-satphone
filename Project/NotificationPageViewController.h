/** @file
 * The in-app notification/news web-page view controller.
 *
 * Reconstructed from Ghidra program Jubeat (class NotificationPageViewController, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base. It hosts a
 * @c UIWebView that loads the application notification page over a loading indicator. When an
 * editor identifier is missing it first provisions one through an @c EditorIDManager and loads the
 * request from that manager's success/failure callbacks; it signs outgoing resource requests with
 * the application user agent, gates the page's navigation, opens @c openurl:// links externally,
 * and intercepts the page's @c jbtstore:// deep links to move its delegate to the jubeat store at
 * a given pack.
 *
 * The superclass is @c UIViewController , from the @c super init chain-up at 0x1ea914.
 */

#import <UIKit/UIKit.h>

#import "EditorIDManager.h"

@class NotificationPageViewController;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Receives the store-navigation and pack-selection events the notification page emits.
 */
@protocol NotificationPageViewControllerDelegate <NSObject>

@optional

/**
 * @brief Sent when the page's @c jbtstore://.../pack/\<id\> deep link is followed. The controller
 *        dispatches it through @c performSelector:withObject: , so the argument is optional.
 * @param packInfomation A dictionary of the form @c {@"pack": \<id\>} , or nil when the link's path
 *        did not name a pack. The binary spelling @c clickPackInfomation is preserved verbatim.
 */
- (void)clickPackInfomation:(nullable NSDictionary<NSString *, NSString *> *)packInfomation;

/**
 * @brief Sent to move the delegate to the jubeat store at a given pack.
 * @param store The store target. The binary reloads the delegate into the object register and
 *        passes the delegate itself here rather than a distinct store object.
 * @param packID The pack identifier to open.
 */
- (void)moveStore:(nullable id)store packID:(nullable NSString *)packID;

@end

/**
 * @brief A view controller presenting the notification page in a @c UIWebView.
 */
@interface NotificationPageViewController
    : UIViewController <UIWebViewDelegate, EditorIDManagerDelegate>

/**
 * @brief Builds the web view and loading indicator and stores the delegate; does not load a
 *        request (see @c notificationRequest ).
 * @param delegate The delegate to receive store-navigation events. Held weakly.
 * @ghidraAddress 0x1ea528
 */
- (void)initPage:(nullable id<NotificationPageViewControllerDelegate>)delegate;

/**
 * @brief Loads the notification request into the web view. Builds it from
 *        @c -[JubeatAppDelegate notificationURL] when none was supplied at initialisation.
 * @ghidraAddress 0x1ea82c
 */
- (void)notificationRequest;

/**
 * @brief Initialises the controller for the application notification URL. When an editor
 *        identifier exists it loads immediately, otherwise it provisions one through an
 *        @c EditorIDManager .
 * @param delegate The delegate to receive store-navigation events. Held weakly.
 * @return The initialised controller.
 * @ghidraAddress 0x1ea914
 */
- (instancetype)init:(nullable id<NotificationPageViewControllerDelegate>)delegate;

/**
 * @brief Initialises the controller to load an explicit URL instead of the notification URL.
 * @param url The URL to load.
 * @param delegate The delegate to receive store-navigation events. Held weakly.
 * @return The initialised controller.
 * @ghidraAddress 0x1eaa8c
 */
- (instancetype)initWithURL:(nullable NSURL *)url
                   delegate:(nullable id<NotificationPageViewControllerDelegate>)delegate;

/**
 * @brief Resource-load hook that stamps the app's user agent onto every outgoing request.
 * @param uiWebView The web view loading the resource.
 * @param resource The resource being loaded.
 * @param request The outgoing request, stamped with the user agent.
 * @param redirectResponse The redirect that led here, or nil when there was none.
 * @param dataSource The data source driving the load.
 * @return The request to send.
 * @ghidraAddress 0x1eabc0
 */
- (nullable NSURLRequest *)uiWebView:(nullable id)uiWebView
                            resource:(nullable id)resource
                     willSendRequest:(nullable NSMutableURLRequest *)request
                    redirectResponse:(nullable NSURLResponse *)redirectResponse
                      fromDataSource:(nullable id)dataSource;

/**
 * @brief Gates the page's navigation. Only a user-clicked link is inspected: a @c twitter:// link
 *        is blocked, an @c openurl:// link is opened externally as @c https:// , and a
 *        @c jbtstore://.../pack/\<id\> link is delivered to the delegate. Returns @c NO for a
 *        handled link and @c YES otherwise.
 * @param webView The web view asking.
 * @param request The request it is about to load.
 * @param navigationType What triggered the navigation.
 * @return NO for a handled link, YES otherwise.
 * @ghidraAddress 0x1ead08
 */
- (BOOL)webView:(UIWebView *)webView
    shouldStartLoadWithRequest:(NSURLRequest *)request
                navigationType:(UIWebViewNavigationType)navigationType;

/**
 * @brief Stops and removes the loading indicator.
 * @ghidraAddress 0x1eb108
 */
- (void)stopIndicator;

/**
 * @brief Shows a network-error alert on a load failure, then stops the indicator.
 * @param webView The web view reporting the failure.
 * @param error The load failure.
 * @ghidraAddress 0x1eb164
 */
- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error;

/**
 * @brief Clears the shared URL cache when a load starts.
 * @param webView The web view that started loading.
 * @ghidraAddress 0x1eb25c
 */
- (void)webViewDidStartLoad:(UIWebView *)webView;

/**
 * @brief Stops the indicator when a load finishes and disables the WebKit touch-callout menu.
 * @param webView The web view that finished loading.
 * @ghidraAddress 0x1eb2a4
 */
- (void)webViewDidFinishLoad:(UIWebView *)webView;

/**
 * @brief Tells the delegate to move to the jubeat store at a given pack.
 * @param store The store target (unused by the binary beyond being forwarded).
 * @param packID The pack identifier to open.
 * @ghidraAddress 0x1eb314
 */
- (void)moveStore:(nullable id)store packID:(nullable NSString *)packID;

/**
 * @brief Closes any open alert when the view disappears.
 * @param animated Whether the disappearance is animated.
 * @ghidraAddress 0x1eb3bc
 */
- (void)viewWillDisappear:(BOOL)animated;

/**
 * @brief @c EditorIDManager callback: editor identifier provisioning failed. Loads the
 *        notification request regardless.
 * @param manager The manager that failed.
 * @param msgStr The server-supplied message, or nil.
 * @ghidraAddress 0x1eb404
 */
- (void)errorIDDownload:(nullable id)manager msgStr:(nullable NSString *)msgStr;

/**
 * @brief @c EditorIDManager callback: editor identifier provisioning succeeded. Loads the
 *        notification request.
 * @param manager The manager that finished.
 * @ghidraAddress 0x1eb410
 */
- (void)successIDDownload:(nullable id)manager;

/**
 * @brief Whether to rotate to a given interface orientation; portrait and portrait-upside-down
 *        only.
 * @param interfaceOrientation The orientation asked about.
 * @return YES for the two portrait orientations, NO otherwise.
 * @ghidraAddress 0x1eb41c
 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;

/**
 * @brief The supported interface orientations: portrait and portrait-upside-down.
 * @return Both portrait orientations.
 * @ghidraAddress 0x1eb42c
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations;

/**
 * @brief Whether the controller supports autorotation; always @c YES.
 * @return Always YES.
 * @ghidraAddress 0x1eb434
 */
- (BOOL)shouldAutorotate;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
