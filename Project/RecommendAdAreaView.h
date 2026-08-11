/** @file
 * Reconstructed interface for the applilink recommend-advert SDK's @c RecommendAdAreaView.
 *
 * @c RecommendAdAreaView is the @c UIWebView subclass that renders a recommend-advert area loaded
 * from a cached HTML file on disk. It acts as its own @c UIWebViewDelegate: it loads the advert
 * file, registers the impression through @c RecommendWebAPI and @c RecommendCore once the content
 * finishes loading, intercepts advert taps on the @c applilink://ext-app scheme (routing clicks
 * through @c AnalysisNetworkCore, @c RecommendWebAPI, @c RecommendAdId, and the native App Store
 * through @c ApplilinkCore, playing an in-app movie through @c ApplilinkViewManager on a
 * @c movie command, and closing the advert on a @c close command), and reports the advert-list
 * lifecycle and failures to its @c applilinkDelegate through @c ApplilinkCore and to its
 * @c sdkDelegate directly. The applilink SDK ships as a closed third-party library.
 *
 * Reconstructed from Ghidra program Jubeat (class @c RecommendAdAreaView, image base
 * @c 0x100000000). All @ghidraAddress values are offsets relative to that image base. This is the
 * same closed SDK class the sibling @c ../rbplus-src tree reconstructs from the other binary that
 * embeds it; the jubeat build differs in that its advert-tap intercept additionally recognises the
 * @c applilink://ext-app:80/movie link and routes it to @c -showVideoViewWithQuery:, its
 * scheme-open path returns a distinct route code, and its click registration runs through a
 * completion block.
 */

#import <UIKit/UIKit.h>

#import "ApplilinkStore.h"
#import "ApplilinkViewDelegate.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The applilink recommend-advert area web view.
 */
@interface RecommendAdAreaView : UIWebView <SdkViewDelegate, UIWebViewDelegate>

/**
 * @brief The advert delegate notified of the advert-list lifecycle and failures.
 *
 * Held weakly: the view forwards each notice to it but does not own it.
 * @ghidraAddress 0x274a94 (getter), 0x274ab4 (setter)
 */
@property(nonatomic, weak, nullable) id<ApplilinkViewDelegate> applilinkDelegate;

/**
 * @brief The SDK delegate notified of the raw open, close, and failure notices. Held weakly.
 * @ghidraAddress 0x274ac8 (getter), 0x274ae8 (setter)
 */
@property(nonatomic, weak, nullable) id<SdkViewDelegate> sdkDelegate;

/**
 * @brief The current web-view load status (0 idle, 1 started, 2 finished).
 * @ghidraAddress 0x274afc (getter), 0x274b0c (setter)
 */
@property(nonatomic, assign) int webViewStatus;

/**
 * @brief The advert-type identifier being displayed.
 * @ghidraAddress 0x274b1c (getter), 0x274b2c (setter)
 */
@property(nonatomic, assign) int adType;

/**
 * @brief The advert-model identifier being displayed.
 * @ghidraAddress 0x274b3c (getter), 0x274b4c (setter)
 */
@property(nonatomic, assign) int adModel;

/**
 * @brief The advert-location identifier being displayed.
 * @ghidraAddress 0x274b5c (getter), 0x274b6c (setter)
 */
@property(nonatomic, strong, nullable) NSString *adLocation;

/**
 * @brief The impression identifier assigned when the advert content finishes loading.
 *
 * Read-only in the public interface; the SDK assigns it through @c -setImpressionId: or when the
 * content finishes loading.
 * @ghidraAddress 0x274ba4 (getter)
 */
@property(nonatomic, strong, readonly, nullable) NSString *impressionId;

/**
 * @brief The caller's opaque request code echoed back in delegate callbacks.
 *
 * The synthesised setter stores directly without a retain, and @c .cxx_destruct does not release
 * it, so this is an unowned reference.
 * @ghidraAddress 0x274bb4 (getter), 0x274bc4 (setter)
 */
@property(nonatomic, unsafe_unretained, nullable) id requestCode;

/**
 * @brief Copy an impression identifier into the view.
 * @param impressionId The impression identifier, copied through @c stringWithFormat: .
 * @ghidraAddress 0x271e88
 */
- (void)setImpressionId:(nullable NSString *)impressionId;

/**
 * @brief Load the advert-area contents from a filesystem path.
 * @param path The advert-content file path.
 * @ghidraAddress 0x271b9c
 */
- (void)startPath:(nullable NSString *)path;

/**
 * @brief Configure the advert area with its advert model, location, type, request code, and
 * delegate, then apply the per-model scroll behaviour.
 * @param adModel The advert-model identifier.
 * @param adLocation The advert-location identifier.
 * @param adType The advert-type identifier.
 * @param requestCode The caller's request code.
 * @param delegate The advert delegate.
 * @ghidraAddress 0x271cc8
 */
- (void)setAdModel:(int)adModel
        adLocation:(nullable NSString *)adLocation
            adType:(int)adType
       requestCode:(nullable id)requestCode
          delegate:(nullable id<ApplilinkViewDelegate>)delegate;

/**
 * @brief Tear down the advert area, notifying that the advert list disappeared.
 * @ghidraAddress 0x271f40
 */
- (void)closeAdArea;

/**
 * @brief Enable or disable scrolling on the advert's scroll subviews.
 * @param scrollEnabled @c YES to enable scrolling.
 * @ghidraAddress 0x271f50
 */
- (void)setScrollEnabled:(BOOL)scrollEnabled;

/**
 * @brief Enable or disable the bounce on the advert's scroll subviews.
 * @param scrollBoundsEnabled @c YES to enable bouncing.
 * @ghidraAddress 0x272240
 */
- (void)setScrollBoundsEnabled:(BOOL)scrollBoundsEnabled;

/**
 * @brief Show or hide the scroll indicators on the advert's scroll subviews.
 * @param scrollBarEnabled @c YES to show the scroll indicators.
 * @ghidraAddress 0x27250c
 */
- (void)setScrollBarEnabled:(BOOL)scrollBarEnabled;

/**
 * @brief Present an in-app video player for a movie link's query string.
 * @param query The video request query parsed from the intercepted
 * @c applilink://ext-app:80/movie link.
 * @ghidraAddress 0x2746f0
 */
- (void)showVideoViewWithQuery:(nullable NSString *)query;

/**
 * @brief Notify the delegates that the advert list appeared.
 * @ghidraAddress 0x272bd8
 */
- (void)appListDidAppear;

/**
 * @brief Notify the delegates that the advert list disappeared and clear the delegates.
 * @ghidraAddress 0x272d20
 */
- (void)appListDidDisappear;

/**
 * @brief Notify the delegates of an advert-list load failure and clear the SDK delegate.
 * @param error The load failure error.
 * @ghidraAddress 0x272ec0
 */
- (void)appListFailLoadWithError:(nullable NSError *)error;

/**
 * @brief Notify the delegates of an advert-list link failure.
 * @param error The link failure error.
 * @ghidraAddress 0x273030
 */
- (void)appListFailLinkWithError:(nullable NSError *)error;

/**
 * @brief Handle an advert-tap request, routing App Store transitions, first-party clicks, movie
 * playback, and the close command.
 * @param request The intercepted advert request.
 * @return 1 to let the web view load the request, 0 when the request was consumed, and 3 when a
 * server-supplied external scheme was opened directly.
 * @ghidraAddress 0x273194
 */
- (int)redirectWithRequest:(nullable NSURLRequest *)request;

/**
 * @brief Handle the advert opening. This is an empty hook.
 * @ghidraAddress 0x2748fc
 */
- (void)openedNotice;

/**
 * @brief Tear down the advert area and remove it from its superview.
 * @ghidraAddress 0x274900
 */
- (void)closeNotice;

/**
 * @brief Handle an advert open error. This is an empty hook.
 * @ghidraAddress 0x27493c
 */
- (void)openErrorNotice;

/**
 * @brief Handle the App Store product page opening. This is an empty hook.
 * @ghidraAddress 0x274940
 */
- (void)appStoreOpenedNotice;

/**
 * @brief Handle the App Store product page closing, tearing down the advert for advert model 5.
 * @ghidraAddress 0x274944
 */
- (void)appStoreCloseNotice;

/**
 * @brief Handle the App Store product page having closed. This is an empty hook.
 * @ghidraAddress 0x27496c
 */
- (void)appStoreClosedNotice;

/**
 * @brief Handle an App Store product-page load failure. This is an empty hook.
 * @param error The load failure error.
 * @ghidraAddress 0x274970
 */
- (void)appStoreFailLoadNoticeWithError:(nullable NSError *)error;

/**
 * @brief Handle the App Store product page transitioning. This is an empty hook.
 * @ghidraAddress 0x274974
 */
- (void)appStoreTransitionNotice;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
