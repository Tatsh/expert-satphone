/** @file
 * The applilink recommend SDK's full-screen (interstitial) advert controller.
 *
 * @c RecommendFullScreenController is the @c UIViewController the applilink recommend SDK presents
 * for a full-screen interstitial advert. It lays a full-screen @c ShadeView dimmer over the window
 * and centres an advert base view inside it, sized for the current interface orientation, the
 * status bar, and the running iOS version. For an HTML interstitial it builds a
 * @c RecommendAdAreaView over the cached advert body; for a movie interstitial it forwards the
 * parsed movie query to the @c ApplilinkViewManager video presenter. It reports the advert
 * lifecycle (did start, did appear, did disappear, sound use, and the load and link failures) back
 * to its applilink delegate through @c ApplilinkCore, and asks its full-view delegate (the
 * presenting @c RecommendCore) to release it when the advert closes.
 *
 * Reconstructed from Ghidra program Jubeat (image base @c 0x100000000). All @ghidraAddress values
 * are offsets relative to that image base. The applilink SDK ships as a closed third-party library;
 * this interface is recovered in full from the class metadata. This is a closed SDK class, but
 * the jubeat build additionally opens a movie
 * interstitial (@c -openMovieWithAdModel:… and @c -showVideoViewWithQuery:), threads the impression
 * identifier through @c RecommendAdCache and @c ApplilinkFile, sets the advert-area tag and
 * impression identifier, and carries the extra sound-use and @c -closeNotice: relays.
 */

#import <UIKit/UIKit.h>

#import "ApplilinkViewDelegate.h"

@class ApplilinkParameters;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The applilink recommend full-screen (interstitial) advert controller.
 *
 * The class metadata declares conformance to the closed-SDK @c ShadeViewDelegate,
 * @c ApplilinkViewDelegate, and @c SdkViewDelegate protocols.
 */
@interface RecommendFullScreenController : UIViewController <ApplilinkViewDelegate>

/**
 * @brief Whether the interstitial advert is currently on screen.
 * @ghidraAddress 0x27bf78 (getter), 0x27bf88 (setter)
 */
@property(nonatomic, assign) BOOL isVisible;

/**
 * @brief Open a full-screen HTML interstitial advert.
 *
 * Stores the request parameters and delegates, lays the view out, and — once
 * @c RecommendAdCache has cached the advert body and its template exists on disk — spawns a
 * @c RecommendAdAreaView on the main queue to render and drive the advert. On a cache or
 * missing-file error it reports the failure through @c ApplilinkCore and releases itself.
 * @param adModel The advert-model identifier.
 * @param adLocation The advert-location identifier.
 * @param verticalAlign The vertical-alignment identifier.
 * @param applilinkParams The advert request parameters, echoed back on failure.
 * @param delegate The applilink delegate notified of the advert lifecycle.
 * @param closeDelegate The full-view delegate asked to release this controller on close.
 * @ghidraAddress 0x279df0
 */
- (void)openAdViewWithAdModel:(int)adModel
                   adLocation:(nullable NSString *)adLocation
                verticalAlign:(int)verticalAlign
              applilinkParams:(nullable ApplilinkParameters *)applilinkParams
                     delegate:(nullable id)delegate
                closeDelegate:(nullable id)closeDelegate;

/**
 * @brief Open a full-screen movie interstitial advert.
 *
 * Stores the request parameters and delegates, lays the view out, asks @c RecommendAdCache for the
 * movie query dictionary, picks one movie URL (a random entry from the @c movie_url_list, or the
 * lone @c movie_url), strips the @c applilink://ext-app:80/movie? prefix, appends the impression,
 * advert model, advert location, creative, display-number, and install-flag query parameters, then
 * presents it through @c -showVideoViewWithQuery: on the main queue. On a cache error it reports
 * the failure through @c ApplilinkCore and releases itself.
 * @param adModel The advert-model identifier.
 * @param adLocation The advert-location identifier.
 * @param verticalAlign The vertical-alignment identifier.
 * @param applilinkParams The advert request parameters, echoed back on failure.
 * @param delegate The applilink delegate notified of the advert lifecycle.
 * @param closeDelegate The full-view delegate asked to release this controller on close.
 * @ghidraAddress 0x27a394
 */
- (void)openMovieWithAdModel:(int)adModel
                  adLocation:(nullable NSString *)adLocation
               verticalAlign:(int)verticalAlign
             applilinkParams:(nullable ApplilinkParameters *)applilinkParams
                    delegate:(nullable id)delegate
               closeDelegate:(nullable id)closeDelegate;

/**
 * @brief Present the in-app movie player for @p query through @c ApplilinkViewManager.
 *
 * Hosts the player in this controller's own view, auto-playing, and makes this controller the
 * manager's SDK delegate.
 * @param query The movie request query.
 * @ghidraAddress 0x27a9e8
 */
- (void)showVideoViewWithQuery:(nullable NSString *)query;

/**
 * @brief Lay the shade view out over the whole screen and the advert base view centred within it.
 *
 * Sized for the current interface orientation, the status bar, and the running iOS version.
 * @ghidraAddress 0x27ab90
 */
- (void)setViewSize;

/**
 * @brief Rotate and resize the controller's view to match the current interface orientation.
 *
 * Re-runs @c -setViewSize, then on the legacy (pre-iOS 8 or non-Xcode 6) path applies a rotation
 * transform and bounds animated over @p duration.
 * @param duration The rotation animation duration.
 * @ghidraAddress 0x27b248
 */
- (void)rotateWebViewWithDuration:(double)duration;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
