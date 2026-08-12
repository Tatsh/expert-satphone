/** @file
 * Reconstructed interface for the applilink recommend-advert SDK's @c RecommendWebView.
 *
 * @c RecommendWebView is the @c UIView container that hosts a recommend advert. Unlike
 * @c RecommendAdWebView (which is the inner view that actually renders a live advert and drives its
 * network lifecycle), @c RecommendWebView is a lightweight wrapper that lazily creates the inner
 * advert view, overlays a loading activity indicator, and forwards the advert-list lifecycle to its
 * @c applilinkDelegate. It picks the concrete inner view at load time: advert models @c 5 and
 * @c 100..101 build a cached @c RecommendAdAreaView from a locally generated HTML file, and every
 * other model dispatches a layout block on the main queue that builds a @c RecommendAdWebView and
 * issues the request. The class adopts the @c ApplilinkViewDelegate protocol in the binary so it
 * can receive the advert-list callbacks from those inner views; since that protocol has no
 * definition in this reconstruction, those callbacks are declared here as an informal delegate.
 *
 * Reconstructed from Ghidra program Jubeat (class @c RecommendWebView, image base
 * @c 0x100000000). All @ghidraAddress values are offsets relative to that image base. This is the
 * closed SDK class, but the jubeat build
 * carries two extra sound-use callbacks (@c -appListSoundUseStart and @c -appListSoundUseFinish),
 * fires the sound-use-finish notice from @c -appListDidDisappear, and generates the cached-advert
 * HTML through an impression identifier and an @c ApplilinkFile template path.
 */

#import <UIKit/UIKit.h>

#import "ApplilinkViewDelegate.h"

@class ApplilinkParameters;
@class RecommendAdAreaView;
@class RecommendAdWebView;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The applilink recommend-advert web-view container.
 */
@interface RecommendWebView : UIView <ApplilinkViewDelegate>

/**
 * @brief The loading activity indicator overlaid while the advert loads.
 */
@property(nonatomic, strong, nullable) UIActivityIndicatorView *indicator;

/**
 * @brief The inner web view that renders a live recommend advert.
 */
@property(nonatomic, strong, nullable) RecommendAdWebView *webView;

/**
 * @brief The inner area view that renders a cached (local HTML) recommend advert.
 */
@property(nonatomic, strong, nullable) RecommendAdAreaView *adAreaWebView;

/**
 * @brief The advert delegate notified of the advert-list lifecycle and failures.
 *
 * Held weakly: the container forwards each notice to it but does not own it.
 */
@property(nonatomic, weak, nullable) id<ApplilinkViewDelegate> applilinkDelegate;

/**
 * @brief The request parameters for the advert currently being displayed.
 */
@property(nonatomic, copy, nullable) ApplilinkParameters *applilinkParams;

/**
 * @brief Whether the inner web view is allowed to scroll (bounce) when dragged.
 */
@property(nonatomic, assign) BOOL webViewBounces;

/**
 * @brief Initialise from an archive and apply the shared container configuration.
 * @param coder The unarchiver to decode from.
 * @return The initialised container, or @c nil.
 * @ghidraAddress 0x27882c
 */
- (instancetype)initWithCoder:(NSCoder *)coder;

/**
 * @brief Apply the shared container configuration (transparent, non-opaque, fully flexible
 * autoresizing, aspect-fit content mode).
 * @ghidraAddress 0x278890
 */
- (void)setInitParam;

/**
 * @brief Load the advert web content for an advert model at an advert location.
 *
 * Builds the request parameters, then delegates to
 * @c loadRequestWithAdModel:adLocation:verticalAlign:delegate:.
 * @param adModel The advert-model identifier.
 * @param adLocation The advert-location identifier.
 * @param verticalAlign The vertical-alignment identifier.
 * @param requestCode The caller's request code echoed back in delegate callbacks.
 * @param delegate The advert delegate to notify.
 * @ghidraAddress 0x27898c
 */
- (void)loadRequestWithAdModel:(int)adModel
                    adLocation:(nullable NSString *)adLocation
                 verticalAlign:(int)verticalAlign
                   requestCode:(nullable id)requestCode
                      delegate:(nullable id<ApplilinkViewDelegate>)delegate;

/**
 * @brief Load the advert, choosing the cached-HTML or live path based on the advert model.
 *
 * When the SDK may be used and the recommend core is initialised: advert models @c 5 and
 * @c 100..101 generate a cached HTML file and build a @c RecommendAdAreaView from it, and every
 * other model dispatches a layout block on the main queue that builds a @c RecommendAdWebView and
 * issues the request. Failures are reported through @c ApplilinkCore.
 * @param adModel The advert-model identifier.
 * @param adLocation The advert-location identifier.
 * @param verticalAlign The vertical-alignment identifier.
 * @param delegate The advert delegate to notify.
 * @ghidraAddress 0x278a94
 */
- (void)loadRequestWithAdModel:(int)adModel
                    adLocation:(nullable NSString *)adLocation
                 verticalAlign:(int)verticalAlign
                      delegate:(nullable id<ApplilinkViewDelegate>)delegate;

/**
 * @brief Set whether the inner web view may scroll, recording it as the bounce state and forwarding
 * it to the inner web view.
 * @param scrollEnabled @c YES to allow scrolling.
 * @ghidraAddress 0x2794bc
 */
- (void)setScrollEnabled:(BOOL)scrollEnabled;

/**
 * @brief Stop animating and cancel the pending auto-hide of the loading indicator.
 * @ghidraAddress 0x2793c4
 */
- (void)hiddenIndicator;

/**
 * @brief Tear down both inner advert views before this view leaves the tree.
 * @ghidraAddress 0x279418
 */
- (void)closeAdArea;

/**
 * @brief Notify the delegate that the advert list started.
 * @ghidraAddress 0x2794f4
 */
- (void)appListDidStart;

/**
 * @brief Remove the loading indicator and notify the delegate that the advert list appeared.
 * @ghidraAddress 0x27955c
 */
- (void)appListDidAppear;

/**
 * @brief Remove the loading indicator and inner web view, fire the sound-use-finish notice, notify
 * the delegate that the advert list disappeared, and clear the delegate.
 * @ghidraAddress 0x279628
 */
- (void)appListDidDisappear;

/**
 * @brief Notify the delegate of an advert-list load failure and clear the delegate.
 * @param error The load failure error.
 * @ghidraAddress 0x279748
 */
- (void)appListFailLoadWithError:(nullable NSError *)error;

/**
 * @brief Notify the delegate of an advert-list link failure.
 * @param error The link failure error.
 * @ghidraAddress 0x279850
 */
- (void)appListFailLinkWithError:(nullable NSError *)error;

/**
 * @brief Notify the delegate that the advert has begun using sound, so the host can pause its own
 * audio.
 * @ghidraAddress 0x2798d4
 */
- (void)appListSoundUseStart;

/**
 * @brief Notify the delegate that the advert has finished using sound, so the host can resume its
 * own audio.
 * @ghidraAddress 0x279924
 */
- (void)appListSoundUseFinish;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
