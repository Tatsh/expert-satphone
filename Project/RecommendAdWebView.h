/**
 * @file
 * @brief Reconstructed interface for the applilink recommend-advert SDK's @c RecommendAdWebView.
 *
 * @c RecommendAdWebView is the @c UIWebView subclass that renders a live recommend advert and
 * drives its whole network lifecycle. It acts as its own @c UIWebViewDelegate: it opens a recommend
 * session through @c RecommendCore, fetches the banner detail through @c RecommendWebAPI, builds
 * the advert-request parameters, loads the request, intercepts the SDK's custom @c applilink://
 * links (opening an in-app video through @c ApplilinkViewManager or closing the advert), and fans
 * the advert-list lifecycle and failures out to its @c applilinkDelegate by way of @c
 * ApplilinkCore. It is the inner web view lazily created by @c RecommendWebView for non-cached
 * advert models.
 *
 * Reconstructed from Ghidra program Jubeat (class @c RecommendAdWebView, image base
 * @c 0x100000000). All @ghidraAddress values are offsets relative to that image base. This is the
 * closed SDK class; the jubeat build differs from the other binary that embeds it in that its
 * custom-scheme intercept additionally recognises an @c applilink://ext-app:80/movie link and
 * routes it to @c -showVideoViewWithQuery:.
 */

#import <UIKit/UIKit.h>

#import "ApplilinkViewDelegate.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The applilink recommend advert web view.
 */
@interface RecommendAdWebView : UIWebView <UIWebViewDelegate>

/**
 * @brief The advert delegate notified of the advert-list lifecycle and failures.
 *
 * Held weakly: the view forwards each notice to it but does not own it.
 */
@property(nonatomic, weak, nullable) id<ApplilinkViewDelegate> applilinkDelegate;

/**
 * @brief Whether the advert web content has finished loading.
 */
@property(nonatomic, assign) BOOL loadComplete;

/**
 * @brief Whether the advert web view has already loaded once (so a reload skips the
 * transparent-background setup).
 */
@property(nonatomic, assign) BOOL reloadFlg;

/**
 * @brief Whether the advert load has been cancelled (for example by removal from the view tree).
 */
@property(nonatomic, assign) BOOL cancelFlg;

/**
 * @brief Whether scrolling is enabled for the advert web view.
 */
@property(nonatomic, assign) BOOL scrollFlg;

/**
 * @brief The current web-view load status (0 idle, 1 started, 2 finished).
 */
@property(nonatomic, assign) int webViewStatus;

/**
 * @brief The advert-model identifier being displayed.
 */
@property(nonatomic, assign) int adModel;

/**
 * @brief The advert-location identifier being displayed.
 */
@property(nonatomic, strong, nullable) NSString *adLocation;

/**
 * @brief The vertical-alignment identifier for the advert.
 */
@property(nonatomic, assign) int verticalAlign;

/**
 * @brief The caller's opaque request code echoed back in delegate callbacks.
 *
 * The synthesised setter stores directly without a retain, and @c .cxx_destruct does not release
 * it, so this is an unowned reference.
 */
@property(nonatomic, unsafe_unretained, nullable) id requestCode;

/**
 * @brief Apply the shared advert web-view configuration (transparent background, autoresizing, and
 * reset flags).
 * @ghidraAddress 0x245184
 */
- (void)setInitParam;

/**
 * @brief Load the advert web content for an advert model at an advert location.
 * @param adModel The advert-model identifier.
 * @param adLocation The advert-location identifier.
 * @param verticalAlign The vertical-alignment identifier.
 * @param requestCode The caller's request code.
 * @param delegate The advert delegate to notify.
 * @ghidraAddress 0x24533c
 */
- (void)loadRequestWithAdModel:(int)adModel
                    adLocation:(nullable NSString *)adLocation
                 verticalAlign:(int)verticalAlign
                   requestCode:(nullable id)requestCode
                      delegate:(nullable id<ApplilinkViewDelegate>)delegate;

/**
 * @brief Begin the recommend session and load the advert on the main queue.
 * @ghidraAddress 0x2454c4
 */
- (void)loadRequest;

/**
 * @brief Load an advert request built from a URL string and its query parameters.
 * @param URL The advert request URL string.
 * @param parameters The request parameters appended to the URL.
 * @ghidraAddress 0x2462b8
 */
- (void)loadRequestWithURL:(nullable NSString *)URL parameters:(nullable NSDictionary *)parameters;

/**
 * @brief Stop any in-flight load and notify the delegate that the advert list closed.
 * @ghidraAddress 0x2463cc
 */
- (void)closeAdArea;

/**
 * @brief Enable or disable scrolling on the advert's scroll subviews.
 * @param scrollEnabled @c YES to enable scrolling.
 * @ghidraAddress 0x246420
 */
- (void)setScrollEnabled:(BOOL)scrollEnabled;

/**
 * @brief Enable or disable the bounce on the advert's scroll subviews.
 * @param scrollBoundsEnabled @c YES to enable bouncing.
 * @ghidraAddress 0x24671c
 */
- (void)setScrollBoundsEnabled:(BOOL)scrollBoundsEnabled;

/**
 * @brief Show or hide the scroll indicators on the advert's scroll subviews.
 * @param scrollBarEnabled @c YES to show the scroll indicators.
 * @ghidraAddress 0x2469e8
 */
- (void)setScrollBarEnabled:(BOOL)scrollBarEnabled;

/**
 * @brief Stop loading the advert web view.
 * @ghidraAddress 0x246bb8
 */
- (void)unloadRecommendView;

/**
 * @brief Handle the hosting controller disappearing.
 * @param viewDidDisappear @c YES if the disappearance was animated.
 * @ghidraAddress 0x246bc8
 */
- (void)viewDidDisappear:(BOOL)viewDidDisappear;

/**
 * @brief Unload the advert, clear the advert location, and notify that the advert list disappeared.
 * @ghidraAddress 0x246bcc
 */
- (void)appliListClosed;

/**
 * @brief Present an in-app video player for a movie link's query string.
 * @param query The video request query parsed from the intercepted @c applilink://ext-app:80/movie
 * link.
 * @ghidraAddress 0x2473d4
 */
- (void)showVideoViewWithQuery:(nullable NSString *)query;

/**
 * @brief Notify the delegate that the advert list started.
 * @ghidraAddress 0x247518
 */
- (void)appListDidStart;

/**
 * @brief Notify the delegate that the advert list appeared.
 * @ghidraAddress 0x2475cc
 */
- (void)appListDidAppear;

/**
 * @brief Notify the delegate that the advert list disappeared and clear the delegate.
 * @ghidraAddress 0x247694
 */
- (void)appListDidDisappear;

/**
 * @brief Notify the delegate of an advert-list load failure and clear the delegate.
 * @param error The load failure error.
 * @ghidraAddress 0x24776c
 */
- (void)appListFailLoadWithError:(nullable NSError *)error;

/**
 * @brief Notify the delegate of an advert-list link failure.
 * @param error The link failure error.
 * @ghidraAddress 0x24786c
 */
- (void)appListFailLinkWithError:(nullable NSError *)error;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
