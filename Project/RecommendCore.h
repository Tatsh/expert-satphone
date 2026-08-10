/** @file
 * Reconstructed interface for the Applilink recommend SDK's @c RecommendCore singleton.
 *
 * @c RecommendCore is KONAMI's Applilink recommend-advert controller: a shared instance that
 * regenerates the authentication session, queries advert status, unread counts, and display
 * status, presents the advert screen, advert area, full-screen advert, and movie view controllers,
 * and registers first-party advert impressions and clicks. Every public entry point first
 * regenerates the recommend session (through @c ApplilinkCore and @c RecommendWebAPI) and then
 * either forwards to the network layer or reports a localised @c ApplilinkNetworkError. Recovered
 * from the Objective-C metadata and Ghidra decompilation of the @e jubeat @e plus arm64 binary
 * (image base 0x100000000); @c \@ghidraAddress values are offsets relative to that image base.
 */

#import <UIKit/UIKit.h>

#import "ApplilinkParameters.h"

@class RecommendFullScreenController;
@class RecommendWebViewController;
@protocol ApplilinkViewDelegate;
@protocol InterstitiaViewDelegate;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The Applilink recommend SDK's shared advert controller.
 */
@interface RecommendCore : NSObject

/**
 * @brief Whether the recommend core has been initialised.
 */
@property(nonatomic, assign) int initializeFlg;

/**
 * @brief The full-screen (interstitial) advert view controller currently presented, if any.
 */
@property(nonatomic, strong, nullable) RecommendFullScreenController *interstitialViewController;

/**
 * @brief The advert-screen web view controller currently presented, if any.
 */
@property(nonatomic, strong, nullable) RecommendWebViewController *adScreenViewController;

/**
 * @brief The delegate that receives Applilink advert-screen lifecycle callbacks.
 */
@property(nonatomic, weak, nullable) id<ApplilinkViewDelegate> applilinkDelegate;

/**
 * @brief The advert-request parameters for the advert-screen presentation in flight.
 */
@property(nonatomic, copy, nullable) ApplilinkParameters *applilinkParams;

/**
 * @brief The pending App Store deep-link URL string, held between a redirect and its launch.
 */
@property(nonatomic, strong, nullable) NSString *urlString;

/**
 * @brief Whether the advert screen hides its navigation bar.
 */
@property(nonatomic, assign) BOOL navigationBarHidden;

/**
 * @brief Whether the advert screen has already been closed, guarding a double close.
 */
@property(nonatomic, assign) BOOL adScreenviewCloseFlg;

/**
 * @brief Whether a redirect (App Store or external application launch) is in flight.
 */
@property(nonatomic, assign) BOOL redirectFlg;

/**
 * @brief The delegate that receives advert-area lifecycle callbacks.
 */
@property(nonatomic, weak, nullable) id<ApplilinkViewDelegate> adAreaDelegate;

/**
 * @brief The delegate that receives interstitial advert-screen lifecycle callbacks.
 */
@property(nonatomic, weak, nullable) id<InterstitiaViewDelegate> adScreenDelegate;

/**
 * @brief The delegate that receives first-party advert (click) lifecycle callbacks.
 */
@property(nonatomic, weak, nullable) id<ApplilinkViewDelegate> uniqueAdDelegate;

/**
 * @brief The advert-request parameters for the first-party advert click in flight.
 */
@property(nonatomic, copy, nullable) ApplilinkParameters *uniqueApplilinkParams;

/**
 * @brief The shared recommend-core instance.
 * @return The singleton.
 * @ghidraAddress 0x268dc4
 */
+ (instancetype)sharedInstance;

/**
 * @brief Initialise the recommend core, serialising the super initialisation on its work queue.
 * @return The initialised instance.
 * @ghidraAddress 0x268adc
 */
- (instancetype)init;

/**
 * @brief Whether the recommend core is fully initialised.
 * @return @c YES when @c initializeFlg equals one.
 * @ghidraAddress 0x268e84
 */
- (BOOL)isInitialized;

/**
 * @brief Reset the initialisation flag and clear the cached advert data, expiry, and cache folder.
 * @ghidraAddress 0x268e9c
 */
- (void)clearInitialize;

/**
 * @brief Whether an application registered under @p scheme is installed on the device.
 * @param scheme The custom URL scheme to probe.
 * @return @c YES when the scheme can be opened.
 * @ghidraAddress 0x268f14
 */
- (BOOL)isInstalledAppliWithScheme:(nullable NSString *)scheme;

/**
 * @brief Start the recommend SDK, posting the application install once per install.
 * @param callback The completion callback invoked with an error, or @c nil on success.
 * @ghidraAddress 0x269014
 */
- (void)startWithCallback:(nullable void (^)(NSError *_Nullable error))callback;

/**
 * @brief Start a recommend session, calling @p callback when it completes.
 * @param callback The completion callback.
 * @ghidraAddress 0x269948
 */
- (void)startSessionWithCallback:(nullable void (^)(NSError *_Nullable error))callback;

/**
 * @brief Fetch the installed-application list, gating the request on a fresh session.
 * @param callback The completion callback invoked with the list and an error.
 * @ghidraAddress 0x269d84
 */
- (void)appliListWithCallBack:(nullable void (^)(id _Nullable list,
                                                 NSError *_Nullable error))callback;

/**
 * @brief Return the cached installed-application list, fetching it when absent.
 * @param callback The completion callback invoked with the list and an error.
 * @ghidraAddress 0x269ea4
 */
- (void)appliListCacheWithCallBack:(nullable void (^)(id _Nullable list,
                                                      NSError *_Nullable error))callback;

/**
 * @brief Query the advert status for @p adModel.
 * @param adModel The advert-model identifier.
 * @param callback The status callback.
 * @ghidraAddress 0x269f40
 */
- (void)getAdStatusWithAdModel:(int)adModel
                      callback:
                          (nullable void (^)(NSInteger status, NSError *_Nullable error))callback;

/**
 * @brief Query the unread advert count for @p adModel at @p adLocation.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier.
 * @param callback The status callback.
 * @ghidraAddress 0x26a1b8
 */
- (void)getUnreadCountWithAdModel:(int)adModel
                       adLocation:(nullable NSString *)adLocation
                         callback:(nullable void (^)(NSInteger status,
                                                     NSError *_Nullable error))callback;

/**
 * @brief Query the advert-display status for @p adModel at @p adLocation.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier.
 * @param callback The display-status callback.
 * @ghidraAddress 0x26a434
 */
- (void)getAdDisplayStatusWithAdModel:(int)adModel
                           adLocation:(nullable NSString *)adLocation
                             callback:(nullable void (^)(NSDictionary *_Nullable status,
                                                         NSError *_Nullable error))callback;

/**
 * @brief Query the advert status for every advert model.
 * @param callback The status callback.
 * @ghidraAddress 0x26a7ac
 */
- (void)getAllAdStatusWithCallback:(nullable void (^)(NSError *_Nullable error))callback;

/**
 * @brief Clear every cached advert-data record.
 * @ghidraAddress 0x26a98c
 */
- (void)clearAllAdData;

/**
 * @brief Clear and re-fetch every cached advert-data record.
 * @ghidraAddress 0x26a9a4
 */
- (void)reloadAllAdData;

/**
 * @brief Open the advert screen inside @p parentView.
 * @param parentView The view that hosts the advert screen.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier.
 * @param verticalAlign The vertical-alignment identifier.
 * @param requestCode The caller's request code.
 * @param delegate The advert delegate.
 * @ghidraAddress 0x26aa20
 */
- (void)openAdScreenWithParentView:(nullable UIView *)parentView
                           adModel:(int)adModel
                        adLocation:(nullable NSString *)adLocation
                     verticalAlign:(int)verticalAlign
                       requestCode:(nullable id)requestCode
                          delegate:(nullable id)delegate;

/**
 * @brief Open the advert area inside @p parentView.
 * @param parentView The view that hosts the advert area.
 * @param rect The advert area's frame within @p parentView.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier.
 * @param verticalAlign The vertical-alignment identifier.
 * @param requestCode The caller's request code.
 * @param delegate The advert delegate.
 * @ghidraAddress 0x26b650
 */
- (void)openAdAreaWithParentView:(nullable UIView *)parentView
                            rect:(CGRect)rect
                         adModel:(int)adModel
                      adLocation:(nullable NSString *)adLocation
                   verticalAlign:(int)verticalAlign
                     requestCode:(nullable id)requestCode
                        delegate:(nullable id)delegate;

/**
 * @brief Open a full-screen advert view controller.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier.
 * @param verticalAlign The vertical-alignment identifier.
 * @param requestCode The caller's request code.
 * @param delegate The advert delegate.
 * @ghidraAddress 0x26c0ac
 */
- (void)openFullViewControllerWithAdModel:(int)adModel
                               adLocation:(nullable NSString *)adLocation
                            verticalAlign:(int)verticalAlign
                              requestCode:(nullable id)requestCode
                                 delegate:(nullable id)delegate;

/**
 * @brief Open a full-screen movie advert view controller.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier.
 * @param verticalAlign The vertical-alignment identifier.
 * @param requestCode The caller's request code.
 * @param delegate The advert delegate.
 * @ghidraAddress 0x26c5e0
 */
- (void)openMovieViewControllerWithAdModel:(int)adModel
                                adLocation:(nullable NSString *)adLocation
                             verticalAlign:(int)verticalAlign
                               requestCode:(nullable id)requestCode
                                  delegate:(nullable id)delegate;

/**
 * @brief Close the advert screen.
 * @ghidraAddress 0x26cb14
 */
- (void)closeAdScreen;

/**
 * @brief Present a video advert view for @p query inside the current advert-screen view.
 * @param query The video request query.
 * @ghidraAddress 0x26ccb4
 */
- (void)showVideoViewWithQuery:(nullable NSString *)query;

/**
 * @brief Rotate any open recommend-advert screen to a new interface orientation.
 * @param interfaceOrientation The target @c UIInterfaceOrientation.
 * @param duration The animation duration.
 * @ghidraAddress 0x26cdc4
 */
- (void)rotateWithInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
                              duration:(NSTimeInterval)duration;

/**
 * @brief Handle an advert-screen redirect request using the current advert parameters.
 * @param request The redirect request.
 * @return The redirect outcome code.
 * @ghidraAddress 0x26ce5c
 */
- (int)redirectViewContollerWithRequest:(nullable NSURLRequest *)request;

/**
 * @brief Handle an advert-screen redirect request with no advert parameters.
 * @param request The redirect request.
 * @return The redirect outcome code.
 * @ghidraAddress 0x26ce78
 */
- (int)redirectWithRequest:(nullable NSURLRequest *)request;

/**
 * @brief Handle an advert-screen redirect request, dispatching Applilink deep links.
 *
 * A URL under the @c applilink://ext-app:80 scheme is parsed into its ad identifier, country code,
 * category id, ad type, and store id, then either launched through an external application, opened
 * in the App Store, or forwarded to the advert screen. Ordinary URLs are handed back to the caller
 * to load.
 * @param request The redirect request; its URL may be rewritten in place.
 * @param appParam The advert parameters to report on failure, or @c nil.
 * @return The redirect outcome code.
 * @ghidraAddress 0x26ce8c
 */
- (int)redirectWithRequest:(nullable NSURLRequest *)request
                  appParam:(nullable ApplilinkParameters *)appParam;

/**
 * @brief Return the cached banner status for @p adModel, expiring stale entries.
 * @param adModel The advert-model identifier.
 * @return The cached status object, or @c nil when absent or expired.
 * @ghidraAddress 0x26dd44
 */
- (nullable id)getTemporaryCacheWithAdModel:(int)adModel;

/**
 * @brief Whether the banner cache may be used, clearing it when no UDID is available.
 * @return @c YES when at least one UDID is present.
 * @ghidraAddress 0x26e07c
 */
- (BOOL)canUseBannerCache;

/**
 * @brief Clear the cached banner status.
 * @ghidraAddress 0x26e150
 */
- (void)clearAdStatus;

/**
 * @brief Clear every stored HTTP cookie, ending the recommend session.
 * @ghidraAddress 0x26e1e4
 */
- (void)clearSession;

/**
 * @brief Clear recommend SDK data, except when the server environment is disabled ("0").
 * @ghidraAddress 0x26e33c
 */
+ (void)clearData;

/**
 * @brief Register an impression list for the displayed adverts.
 * @param adType The advert-type identifier.
 * @param adModel The advert-model identifier.
 * @param adLocation The ad-location identifier.
 * @param impressionId The impression identifier.
 * @ghidraAddress 0x26e474
 */
- (void)postAnalysisListRegistWithAdType:(int)adType
                                 AdModel:(int)adModel
                              adLocation:(nullable NSString *)adLocation
                            impressionId:(nullable NSString *)impressionId;

/**
 * @brief Show a first-party advert with the default advert model.
 * @param adLocation The ad-location identifier.
 * @param appliId The advert application identifier.
 * @param creativeId The advert creative identifier.
 * @ghidraAddress 0x26ea74
 */
- (void)showOwnAdWithAdLocation:(nullable NSString *)adLocation
                      toAppliId:(nullable NSString *)appliId
                     creativeId:(nullable NSString *)creativeId;

/**
 * @brief Show a first-party advert for @p adModel.
 * @param adLocation The ad-location identifier.
 * @param adModel The advert-model identifier.
 * @param appliId The advert application identifier.
 * @param creativeId The advert creative identifier.
 * @ghidraAddress 0x26eae8
 */
- (void)showOwnAdWithAdLocation:(nullable NSString *)adLocation
                        adModel:(int)adModel
                      toAppliId:(nullable NSString *)appliId
                     creativeId:(nullable NSString *)creativeId;

/**
 * @brief Register a first-party advert touch with the default advert model.
 * @param adLocation The ad-location identifier.
 * @param appliId The advert application identifier.
 * @param creativeId The advert creative identifier.
 * @param requestCode The caller's request code.
 * @param delegate The advert delegate.
 * @ghidraAddress 0x26f000
 */
- (void)touchOwnAdWithAdLocation:(nullable NSString *)adLocation
                       toAppliId:(nullable NSString *)appliId
                      creativeId:(nullable NSString *)creativeId
                     requestCode:(nullable id)requestCode
                        delegate:(nullable id)delegate;

/**
 * @brief Register a first-party advert touch for @p adModel.
 * @param adLocation The ad-location identifier.
 * @param adModel The advert-model identifier.
 * @param appliId The advert application identifier.
 * @param creativeId The advert creative identifier.
 * @param requestCode The caller's request code.
 * @param delegate The advert delegate.
 * @ghidraAddress 0x26f0b4
 */
- (void)touchOwnAdWithAdLocation:(nullable NSString *)adLocation
                         adModel:(int)adModel
                       toAppliId:(nullable NSString *)appliId
                      creativeId:(nullable NSString *)creativeId
                     requestCode:(nullable id)requestCode
                        delegate:(nullable id)delegate;

/**
 * @brief Launch the click link action for a first-party advert.
 * @param defaultScheme The advert's default URL scheme.
 * @param adIdTo The destination advert identifier.
 * @param adType The advert-type string.
 * @param adModel The advert-model string.
 * @param delegate The advert delegate.
 * @ghidraAddress 0x26fbd4
 */
- (void)linkActionWithDefaultScheme:(nullable NSString *)defaultScheme
                             adIdTo:(nullable NSString *)adIdTo
                             adType:(nullable NSString *)adType
                            adModel:(nullable NSString *)adModel
                           delegate:(nullable id)delegate;

/**
 * @brief Launch the click link action for a movie advert against a fully formed URL.
 * @param url The click URL string.
 * @param delegate The advert delegate.
 * @ghidraAddress 0x26fe28
 */
- (void)linkActionWithURL:(nullable NSString *)url delegate:(nullable id)delegate;

/**
 * @brief Store, or clear, the unique-advert impression identifier for @p adLocation.
 * @param adLocation The ad-location identifier.
 * @param impressionId The impression identifier, or @c nil to clear it.
 * @ghidraAddress 0x26ff34
 */
- (void)setUniqueAdWithAdLocation:(nullable NSString *)adLocation
                     impressionId:(nullable NSString *)impressionId;

/**
 * @brief Return the stored unique-advert impression identifier for @p adLocation.
 * @param adLocation The ad-location identifier.
 * @return The stored impression identifier, or @c nil.
 * @ghidraAddress 0x2700d0
 */
- (nullable id)getUniqueAdWithAdLocation:(nullable NSString *)adLocation;

/**
 * @brief Report a load failure for the click link connection.
 * @param error The load error.
 * @ghidraAddress 0x2701c4
 */
- (void)failLoadWithError:(nullable NSError *)error;

/**
 * @brief Report a load completion for the click link connection.
 * @param response The load response.
 * @ghidraAddress 0x270344
 */
- (void)finishLoadWithResponse:(nullable id)response;

/**
 * @brief Handle a redirect while loading the click link connection.
 * @param request The redirect request.
 * @return Always @c NO; the redirect is handled internally.
 * @ghidraAddress 0x2703ac
 */
- (BOOL)redirectStartLoad:(nullable NSURLRequest *)request;

/**
 * @brief Release the advert-screen view controller.
 * @ghidraAddress 0x270460
 */
- (void)releaseAdScreenViewController;

/**
 * @brief Release the full-screen (interstitial) advert view controller.
 * @ghidraAddress 0x2704b4
 */
- (void)releaseInterstitialViewController;

/**
 * @brief Notify the delegate that the installed-application list started.
 * @ghidraAddress 0x270534
 */
- (void)appListDidStart;

/**
 * @brief Notify the delegate that the installed-application list appeared.
 * @ghidraAddress 0x27063c
 */
- (void)appListDidAppear;

/**
 * @brief Notify the delegate that the installed-application list disappeared.
 * @ghidraAddress 0x27075c
 */
- (void)appListDidDisappear;

/**
 * @brief Report an installed-application list open failure to the delegate.
 * @param error The open error.
 * @ghidraAddress 0x2708c8
 */
- (void)appListFailOpenWithError:(nullable NSError *)error;

/**
 * @brief Report an installed-application list load failure to the delegate.
 * @param error The load error.
 * @ghidraAddress 0x270a70
 */
- (void)appListFailLoadWithError:(nullable NSError *)error;

/**
 * @brief Report an installed-application list failure to the delegate.
 * @param error The failure error.
 * @ghidraAddress 0x270c18
 */
- (void)appListFailWithError:(nullable NSError *)error;

/**
 * @brief Notify the delegate that the advert list started using sound.
 * @ghidraAddress 0x270dc0
 */
- (void)appListSoundUseStart;

/**
 * @brief Notify the delegate that the advert list finished using sound.
 * @ghidraAddress 0x270e10
 */
- (void)appListSoundUseFinish;

/**
 * @brief Notify the delegate that the advert started.
 * @ghidraAddress 0x270e60
 */
- (void)startedNotice;

/**
 * @brief Notify the delegate that the advert opened.
 * @ghidraAddress 0x270ec8
 */
- (void)openedNotice;

/**
 * @brief Notify the delegate that the advert closed.
 * @ghidraAddress 0x270f68
 */
- (void)closeNotice;

/**
 * @brief Report an advert open failure to the delegate.
 * @param error The open error.
 * @ghidraAddress 0x27102c
 */
- (void)failOpenNoticeWithError:(nullable NSError *)error;

/**
 * @brief Report an advert link failure to the delegate.
 * @param error The link error.
 * @ghidraAddress 0x2710fc
 */
- (void)failLinkNoticeWithError:(nullable NSError *)error;

/**
 * @brief Notify the delegate that the App Store advert opened.
 * @param appParam The advert parameters.
 * @ghidraAddress 0x271180
 */
- (void)appStoreOpenedNoticeWithAppParam:(nullable ApplilinkParameters *)appParam;

/**
 * @brief Notify the delegate that the App Store advert is about to close.
 * @param appParam The advert parameters.
 * @ghidraAddress 0x271208
 */
- (void)appStoreCloseNoticeWithAppParam:(nullable ApplilinkParameters *)appParam;

/**
 * @brief Notify the delegate that the App Store advert closed.
 * @param appParam The advert parameters.
 * @ghidraAddress 0x27120c
 */
- (void)appStoreClosedNoticeWithAppParam:(nullable ApplilinkParameters *)appParam;

/**
 * @brief Report an App Store advert load failure, launching a pending deep link if one is held.
 * @param error The load error.
 * @param appParam The advert parameters.
 * @ghidraAddress 0x2712d8
 */
- (void)appStoreFailLoadNoticeWithError:(nullable NSError *)error
                               appParam:(nullable ApplilinkParameters *)appParam;

/**
 * @brief Notify the delegate that the App Store advert transitioned.
 * @param appParam The advert parameters.
 * @ghidraAddress 0x2714c4
 */
- (void)appStoreTransitionNoticeWithAppParam:(nullable ApplilinkParameters *)appParam;

/**
 * @brief Build the movie-end reporting URL from its request parameters.
 * @param adIdFrom The source advert identifier.
 * @param adIdTo The destination advert identifier.
 * @param adModel The advert-model string.
 * @param adLocation The ad-location identifier.
 * @param impressionId The impression identifier.
 * @param creativeId The creative identifier.
 * @param displayNumber The display-number string.
 * @param installFlg The install-flag string.
 * @return The reporting URL, or @c nil when any argument is @c nil.
 * @ghidraAddress 0x2714c8
 */
- (nullable NSString *)getMovideEndUrlWithAdIdFrom:(nullable NSString *)adIdFrom
                                            adIdTo:(nullable NSString *)adIdTo
                                           adModel:(nullable NSString *)adModel
                                        adLocation:(nullable NSString *)adLocation
                                      impressionId:(nullable NSString *)impressionId
                                        creativeId:(nullable NSString *)creativeId
                                     displayNumber:(nullable NSString *)displayNumber
                                        installFlg:(nullable NSString *)installFlg;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
