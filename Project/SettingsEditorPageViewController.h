/** @file
 * The jubeatLab editor web-page view controller.
 *
 * Reconstructed from Ghidra program Jubeat (class SettingsEditorPageViewController, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base. It hosts a
 * @c UIWebView that opens the jubeatLab editor start page over a @c jubeatLabAccess session. When
 * the editor identifier is missing it first provisions one through an @c EditorIDManager , then
 * opens a session; it signs outgoing resource requests with the application user agent, gates and
 * rewrites the page's session-failed and @c twitter:// links, and offers Twitter/Facebook sharing
 * through an @c SLComposeViewController .
 *
 * The superclass is @c UIViewController , from the @c super init chain-up at 0x1f7bb4.
 */

#import <UIKit/UIKit.h>

#import "EditorIDManager.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief A view controller presenting the jubeatLab editor page in a @c UIWebView.
 */
@interface SettingsEditorPageViewController
    : UIViewController <UIWebViewDelegate, EditorIDManagerDelegate>

/**
 * @brief Builds the request for the editor page: an @c NSURLRequest wrapping
 *        @c +[jubeatLabAccess getUserPageURL] .
 * @return The request. Despite the "URL" name the binary returns an @c NSURLRequest .
 * @ghidraAddress 0x1f7a88
 */
- (nullable NSURLRequest *)createEditorPageURL;

/**
 * @brief Loads the stored next request into the web view.
 * @ghidraAddress 0x1f7af0
 */
- (void)openStartPage;

/**
 * @brief Opens a jubeatLab session: builds a @c jubeatLabAccess session client bound to this
 *        controller and starts it.
 * @ghidraAddress 0x1f7b18
 */
- (void)sessionCreate;

/**
 * @brief Initialises the controller: builds the web view and its editor-page request, then either
 *        opens a session (when an editor identifier exists) or provisions one through an
 *        @c EditorIDManager .
 * @return The initialised controller.
 * @ghidraAddress 0x1f7b7c
 */
- (instancetype)init;

/**
 * @brief Resource-load hook that stamps the app's user agent onto every outgoing request.
 * @ghidraAddress 0x1f7dfc
 */
- (nullable NSURLRequest *)uiWebView:(nullable id)uiWebView
                            resource:(nullable id)resource
                     willSendRequest:(nullable NSMutableURLRequest *)request
                    redirectResponse:(nullable NSURLResponse *)redirectResponse
                      fromDataSource:(nullable id)dataSource;

/**
 * @brief Gates the page's navigation. A request to the session-failed URL re-opens a session; a
 *        clicked @c twitter:// link is turned into share text and sent to Twitter; any other
 *        clicked link is stored as the next request. Returns @c NO for a handled link and @c YES
 *        otherwise.
 * @ghidraAddress 0x1f7f44
 */
- (BOOL)webView:(UIWebView *)webView
    shouldStartLoadWithRequest:(NSURLRequest *)request
                navigationType:(UIWebViewNavigationType)navigationType;

/**
 * @brief Shows a communication-error alert on a load failure.
 * @ghidraAddress 0x1f8134
 */
- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error;

/**
 * @brief Clears the shared URL cache when a load starts.
 * @param webView The web view that started loading.
 * @ghidraAddress 0x1f821c
 */
- (void)webViewDidStartLoad:(UIWebView *)webView;

/**
 * @brief jubeatLab callback sent as the session proceeds. Does nothing.
 * @param access The jubeatLab client.
 * @ghidraAddress 0x1f8264
 */
- (void)jubeatLabAccessProceed:(nullable id)access;

/**
 * @brief jubeatLab callback sent when the session fails: clears the session and shows a
 *        communication-error alert.
 * @param access The jubeatLab client.
 * @ghidraAddress 0x1f8268
 */
- (void)jubeatLabAccessError:(nullable id)access;

/**
 * @brief jubeatLab callback sent when the session finishes. On a keychain-switch status it replaces
 *        the keychain and re-opens a session; on success it opens the start page; on any other
 *        status with a server message it shows that message.
 * @param access The jubeatLab client.
 * @ghidraAddress 0x1f838c
 */
- (void)jubeatLabAccessFinished:(nullable id)access;

/**
 * @brief @c EditorIDManager callback: editor identifier provisioning succeeded. Opens a session, or
 *        reports an error when the identifier is still absent.
 * @param manager The manager that finished.
 * @ghidraAddress 0x1f859c
 */
- (void)successIDDownload:(nullable id)manager;

/**
 * @brief @c EditorIDManager callback: editor identifier provisioning failed. Shows the server
 *        message (or a communication-error alert when it is absent).
 * @param manager The manager that failed.
 * @param msgStr The server-supplied message, or nil.
 * @ghidraAddress 0x1f8620
 */
- (void)errorIDDownload:(nullable id)manager msgStr:(nullable NSString *)msgStr;

/**
 * @brief Whether to rotate to a given interface orientation; portrait and portrait-upside-down
 *        only.
 * @ghidraAddress 0x1f8754
 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;

/**
 * @brief The supported interface orientations: portrait and portrait-upside-down.
 * @ghidraAddress 0x1f8764
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations;

/**
 * @brief Whether the controller supports autorotation; always @c YES.
 * @ghidraAddress 0x1f876c
 */
- (BOOL)shouldAutorotate;

/**
 * @brief Closes any open alert when the view disappears.
 * @ghidraAddress 0x1f8774
 */
- (void)viewWillDisappear:(BOOL)animated;

/**
 * @brief Presents the social share composer for a service type, seeded with the stored share text.
 * @param serviceType The @c SLServiceType constant to compose for.
 * @ghidraAddress 0x1f87f4
 */
- (void)socialSend:(nullable NSString *)serviceType;

/**
 * @brief Shares to Twitter.
 * @ghidraAddress 0x1f8944
 */
- (void)sendTwitter;

/**
 * @brief Shares to Facebook.
 * @ghidraAddress 0x1f895c
 */
- (void)sendFaceBook;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
