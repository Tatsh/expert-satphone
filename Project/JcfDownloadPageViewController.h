/**
 * @file
 * @brief The view controller that presents the jubeatLab custom-sequence (jcf) download web page.
 *
 * Reconstructed from Ghidra program Jubeat (class JcfDownloadPageViewController, image base
 * 0x100000000). All @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c UIViewController (from the @c super init at 0x1e699c and the @c super
 * dealloc at 0x1e80f8). The controller hosts a @c UIWebView showing the jubeatLab chart download
 * page, opens a session through a @c jubeatLabAccess downloader, intercepts the custom-scheme SDK
 * and web navigation, drives a @c JcfDownloadView modal for the actual download, reports the
 * outcome through alerts, and offers Twitter and Facebook sharing of the downloaded chart.
 */

#import <UIKit/UIKit.h>

#import "AlertViewManager.h"
#import "EditorIDManager.h"
#import "JcfDownloadView.h"

@class JcfDownloadPageViewController;
@class jubeatLabAccess;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief What a @c JcfDownloadPageViewController tells its owner.
 *
 * Every message is dispatched dynamically behind a @c -respondsToSelector: guard, so all are
 * optional; this protocol only documents the selectors.
 */
@protocol JcfDownloadPageViewControllerDelegate <NSObject>
@optional
/**
 * @brief The user closed the custom-sequence web page.
 * @param controller The controller (the binary passes the controller itself here).
 * @param seqIndex The closing sequence index; the binary always passes the literal @c "none".
 */
- (void)customWebViewClose:(nullable JcfDownloadPageViewController *)controller
                  seqIndex:(nullable NSString *)seqIndex;
/**
 * @brief The download modal finished.
 * @param view The controller (the binary passes the controller itself here).
 */
- (void)downloadEnd:(nullable JcfDownloadPageViewController *)view;
/**
 * @brief The download modal finished, reporting the downloaded music id.
 * @param view The controller (the binary passes the controller itself here).
 * @param musicID The downloaded music id, boxed.
 */
- (void)downloadEnd:(nullable JcfDownloadPageViewController *)view
            musicID:(nullable NSNumber *)musicID;
/**
 * @brief Move the owner to the jubeat store at a given pack.
 * @param store The controller (the binary passes the controller itself here).
 * @param packID The pack identifier to open.
 */
- (void)moveStore:(nullable id)store packID:(nullable NSString *)packID;
@end

/**
 * @brief Hosts the jubeatLab chart download web page and drives its download modal.
 */
@interface JcfDownloadPageViewController : UIViewController <UIWebViewDelegate,
                                                             JcfDownloadViewDelegate,
                                                             EditorIDManagerDelegate,
                                                             AlertViewManagerDelegate>

/**
 * @brief Builds the web view and loading indicator, registers for the suspend notification, and
 *        loads the pending request.
 * @ghidraAddress 0x1e6648
 */
- (void)initPageView;

/**
 * @brief Initialises the controller to download by music id (a sequence-search page).
 * @param musicID The music id whose sequences to search.
 * @param delegate The object told when the page closes. Held weakly.
 * @return The initialised controller.
 * @ghidraAddress 0x1e699c
 */
- (instancetype)initWithMusicID:(unsigned int)musicID
                       delegate:(nullable id<JcfDownloadPageViewControllerDelegate>)delegate;

/**
 * @brief Initialises the controller to download by sequence id (a sequence-detail page).
 * @param sequenceID The sequence id to open.
 * @param delegate The object told when the page closes. Held weakly.
 * @return The initialised controller.
 * @ghidraAddress 0x1e6ad4
 */
- (instancetype)initWithSequenceID:(nullable NSString *)sequenceID
                          delegate:(nullable id<JcfDownloadPageViewControllerDelegate>)delegate;

/**
 * @brief Initialises the controller to load a raw URL, opening a top-page session first.
 * @param url The URL string to load.
 * @param delegate The object told when the page closes. Held weakly.
 * @return The initialised controller.
 * @ghidraAddress 0x1e6c1c
 */
- (instancetype)initWithURL:(nullable NSString *)url
                   delegate:(nullable id<JcfDownloadPageViewControllerDelegate>)delegate;

/**
 * @brief Informal @c UIWebView resource-load delegate: stamps the jubeatLab User-Agent on every
 *        outgoing request.
 * @param webView The web view.
 * @param resource The resource identifier.
 * @param request The request about to be sent.
 * @param redirectResponse The redirect response, if any.
 * @param dataSource The data source.
 * @return The request, with its @c User-Agent header set.
 * @ghidraAddress 0x1e6d68
 */
- (nullable NSURLRequest *)uiWebView:(nullable id)webView
                            resource:(nullable id)resource
                     willSendRequest:(nullable NSURLRequest *)request
                    redirectResponse:(nullable NSURLResponse *)redirectResponse
                      fromDataSource:(nullable id)dataSource;

/**
 * @brief @c UIWebViewDelegate : clears the shared URL cache when a load starts.
 * @param webView The web view.
 * @ghidraAddress 0x1e6eb0
 */
- (void)webViewDidStartLoad:(nullable UIWebView *)webView;

/**
 * @brief Close action: persists defaults and tells the delegate @c -customWebViewClose:seqIndex: .
 *        Ignored while the download modal is up.
 * @param sender The sender.
 * @ghidraAddress 0x1e6ef8
 */
- (void)pushClose:(nullable id)sender;

/**
 * @brief @c UIWebViewDelegate : intercepts the jubeatLab session-failed URL, the @c jubeatplus
 *        custom scheme (download and Twitter share), and lets other requests through.
 * @param webView The web view.
 * @param request The request about to load.
 * @param navigationType The navigation type.
 * @return @c YES to allow the load, @c NO to intercept it.
 * @ghidraAddress 0x1e6fe8
 */
- (BOOL)webView:(nullable UIWebView *)webView
    shouldStartLoadWithRequest:(nullable NSURLRequest *)request
                navigationType:(UIWebViewNavigationType)navigationType;

/**
 * @brief @c UIWebViewDelegate : stops and removes the loading indicator when the load finishes.
 * @param webView The web view.
 * @ghidraAddress 0x1e7820
 */
- (void)webViewDidFinishLoad:(nullable UIWebView *)webView;

/**
 * @brief @c UIWebViewDelegate : shows the failure alert.
 * @param webView The web view.
 * @param error The load error.
 * @ghidraAddress 0x1e787c
 */
- (void)webView:(nullable UIWebView *)webView didFailLoadWithError:(nullable NSError *)error;

/**
 * @brief Tears down the download modal and its dimming cover, and restores the navigation chrome.
 * @ghidraAddress 0x1e7964
 */
- (void)removeDownloadView;

/**
 * @brief @c JcfDownloadViewDelegate : the modal finished; fades it out, tells the delegate, and
 *        clears the downloading flag.
 * @param view The modal.
 * @ghidraAddress 0x1e7a4c
 */
- (void)jcfDownloadEnd:(nullable JcfDownloadView *)view;

/**
 * @brief @c JcfDownloadViewDelegate : the modal requested a store jump; fades it out and tells the
 *        delegate @c -moveStore:packID: .
 * @param view The modal.
 * @param packID The comprised-pack identifier.
 * @ghidraAddress 0x1e7de8
 */
- (void)jcfDownloadMoveStore:(nullable JcfDownloadView *)view packID:(nullable NSString *)packID;

/**
 * @brief Portrait-only autorotation predicate.
 * @param interfaceOrientation The proposed orientation.
 * @return @c YES for the two portrait orientations.
 * @ghidraAddress 0x1e80d8
 */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;

/**
 * @brief The supported orientations mask: portrait only.
 * @return The portrait orientation mask.
 * @ghidraAddress 0x1e80e8
 */
- (UIInterfaceOrientationMask)supportedInterfaceOrientations;

/**
 * @brief Whether the controller may autorotate: always @c YES.
 * @return Always YES.
 * @ghidraAddress 0x1e80f0
 */
- (BOOL)shouldAutorotate;

/**
 * @brief Removes the suspend observer, then chains to @c super .
 * @ghidraAddress 0x1e80f8
 */
- (void)dealloc;

/**
 * @brief Loads the pending @c nextUrlRequest into the web view.
 * @ghidraAddress 0x1e8174
 */
- (void)openStartPage;

/**
 * @brief Opens a top-page jubeatLab session and starts it.
 * @ghidraAddress 0x1e819c
 */
- (void)sessionCreate;

/**
 * @brief @c jubeatLabAccess delegate: progress callback (empty).
 * @param access The downloader.
 * @ghidraAddress 0x1e8200
 */
- (void)jubeatLabAccessProceed:(nullable jubeatLabAccess *)access;

/**
 * @brief @c jubeatLabAccess delegate: the session request failed; clears the downloader and shows
 *        the failure alert.
 * @param access The failed downloader.
 * @ghidraAddress 0x1e8204
 */
- (void)jubeatLabAccessError:(nullable jubeatLabAccess *)access;

/**
 * @brief @c jubeatLabAccess delegate: the session request finished; dispatches on the response
 *        @c Status (open the page, refresh the keychain and retry, or show the server message).
 * @param access The finished downloader.
 * @ghidraAddress 0x1e8328
 */
- (void)jubeatLabAccessFinished:(nullable jubeatLabAccess *)access;

/**
 * @brief @c EditorIDManagerDelegate : identifier provisioning succeeded; opens a session or reports
 *        the error.
 * @param manager The manager.
 * @ghidraAddress 0x1e8538
 */
- (void)successIDDownload:(nullable id)manager;

/**
 * @brief @c EditorIDManagerDelegate : identifier provisioning failed; shows an alert.
 * @param manager The manager.
 * @param msgStr The failure message, or @c nil to use the default communication-error text.
 * @ghidraAddress 0x1e85bc
 */
- (void)errorIDDownload:(nullable id)manager msgStr:(nullable NSString *)msgStr;

/**
 * @brief Dismisses any presented alert on the way off screen.
 * @param animated Whether the disappearance is animated.
 * @ghidraAddress 0x1e86f0
 */
- (void)viewWillDisappear:(BOOL)animated;

/**
 * @brief Presents an @c SLComposeViewController for a social service, seeded with @c socialString .
 * @param serviceType The social service type constant.
 * @ghidraAddress 0x1e8738
 */
- (void)socialSend:(nullable NSString *)serviceType;

/**
 * @brief Presents the Twitter share composer.
 * @ghidraAddress 0x1e88c0
 */
- (void)sendTwitter;

/**
 * @brief Presents the Facebook share composer, when the Social framework is available.
 * @ghidraAddress 0x1e88d8
 */
- (void)sendFaceBook;

/**
 * @brief Suspend-notification handler: dismisses an open share composer.
 * @param notification The notification.
 * @ghidraAddress 0x1e8904
 */
- (void)appSuspended:(nullable NSNotification *)notification;

/**
 * @brief Builds the page on first appearance and, for the raw-URL flow, opens a session or
 *        provisions an editor identifier.
 * @param animated Whether the appearance is animated.
 * @ghidraAddress 0x1e8954
 */
- (void)viewDidAppear:(BOOL)animated;

/**
 * @brief Whether the controller was pushed onto a navigation stack (hides the back button while the
 *        modal is up rather than disabling the left bar button).
 * @ghidraAddress 0x1e89fc
 * @ghidraAddress 0x1e8a0c
 */
@property(nonatomic) BOOL bFromNavigate;

/**
 * @brief Whether closing the controller should trigger a store move.
 * @ghidraAddress 0x1e8a1c
 * @ghidraAddress 0x1e8a2c
 */
@property(nonatomic) BOOL bCloseStoreMove;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
