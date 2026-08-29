/**
 * @file
 * Reconstructed interface for the applilink recommend-advert SDK's @c RecommendAdWebView.
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
 * The applilink recommend advert web view.
 */
@interface RecommendAdWebView : UIWebView <UIWebViewDelegate>

/**
 * The advert delegate notified of the advert-list lifecycle and failures.
 *
 * Held weakly: the view forwards each notice to it but does not own it.
 */
@property(nonatomic, weak, nullable) id<ApplilinkViewDelegate> applilinkDelegate;

/**
 * Whether the advert web content has finished loading.
 */
@property(nonatomic, assign) BOOL loadComplete;

/**
 * Whether the advert web view has already loaded once (so a reload skips the
 * transparent-background setup).
 */
@property(nonatomic, assign) BOOL reloadFlg;

/**
 * Whether the advert load has been cancelled (for example by removal from the view tree).
 */
@property(nonatomic, assign) BOOL cancelFlg;

/**
 * Whether scrolling is enabled for the advert web view.
 */
@property(nonatomic, assign) BOOL scrollFlg;

/**
 * The current web-view load status (0 idle, 1 started, 2 finished).
 */
@property(nonatomic, assign) int webViewStatus;

/**
 * The advert-model identifier being displayed.
 */
@property(nonatomic, assign) int adModel;

/**
 * The advert-location identifier being displayed.
 */
@property(nonatomic, strong, nullable) NSString *adLocation;

/**
 * The vertical-alignment identifier for the advert.
 */
@property(nonatomic, assign) int verticalAlign;

/**
 * The caller's opaque request code echoed back in delegate callbacks.
 *
 * The synthesised setter stores directly without a retain, and @c .cxx_destruct does not release
 * it, so this is an unowned reference.
 */
@property(nonatomic, unsafe_unretained, nullable) id requestCode;

/**
 * Apply the shared advert web-view configuration (transparent background, autoresizing, and
 * reset flags).
 * @ghidraAddress 0x245184
 */
- (void)setInitParam;

/**
 * Load the advert web content for an advert model at an advert location.
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
 * Begin the recommend session and load the advert on the main queue.
 * @ghidraAddress 0x2454c4
 */
- (void)loadRequest;

/**
 * Load an advert request built from a URL string and its query parameters.
 * @param URL The advert request URL string.
 * @param parameters The request parameters appended to the URL.
 * @ghidraAddress 0x2462b8
 */
- (void)loadRequestWithURL:(nullable NSString *)URL parameters:(nullable NSDictionary *)parameters;

/**
 * Stop any in-flight load and notify the delegate that the advert list closed.
 * @ghidraAddress 0x2463cc
 */
- (void)closeAdArea;

/**
 * Enable or disable scrolling on the advert's scroll subviews.
 * @param scrollEnabled @c YES to enable scrolling.
 * @ghidraAddress 0x246420
 */
- (void)setScrollEnabled:(BOOL)scrollEnabled;

/**
 * Enable or disable the bounce on the advert's scroll subviews.
 * @param scrollBoundsEnabled @c YES to enable bouncing.
 * @ghidraAddress 0x24671c
 */
- (void)setScrollBoundsEnabled:(BOOL)scrollBoundsEnabled;

/**
 * Show or hide the scroll indicators on the advert's scroll subviews.
 * @param scrollBarEnabled @c YES to show the scroll indicators.
 * @ghidraAddress 0x2469e8
 */
- (void)setScrollBarEnabled:(BOOL)scrollBarEnabled;

/**
 * Stop loading the advert web view.
 * @ghidraAddress 0x246bb8
 */
- (void)unloadRecommendView;

/**
 * Handle the hosting controller disappearing.
 * @param viewDidDisappear @c YES if the disappearance was animated.
 * @ghidraAddress 0x246bc8
 */
- (void)viewDidDisappear:(BOOL)viewDidDisappear;

/**
 * Unload the advert, clear the advert location, and notify that the advert list disappeared.
 * @ghidraAddress 0x246bcc
 */
- (void)appliListClosed;

/**
 * Present an in-app video player for a movie link's query string.
 * @param query The video request query parsed from the intercepted @c applilink://ext-app:80/movie
 * link.
 * @ghidraAddress 0x2473d4
 */
- (void)showVideoViewWithQuery:(nullable NSString *)query;

/**
 * Notify the delegate that the advert list started.
 * @ghidraAddress 0x247518
 */
- (void)appListDidStart;

/**
 * Notify the delegate that the advert list appeared.
 * @ghidraAddress 0x2475cc
 */
- (void)appListDidAppear;

/**
 * Notify the delegate that the advert list disappeared and clear the delegate.
 * @ghidraAddress 0x247694
 */
- (void)appListDidDisappear;

/**
 * Notify the delegate of an advert-list load failure and clear the delegate.
 * @param error The load failure error.
 * @ghidraAddress 0x24776c
 */
- (void)appListFailLoadWithError:(nullable NSError *)error;

/**
 * Notify the delegate of an advert-list link failure.
 * @param error The link failure error.
 * @ghidraAddress 0x24786c
 */
- (void)appListFailLinkWithError:(nullable NSError *)error;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
