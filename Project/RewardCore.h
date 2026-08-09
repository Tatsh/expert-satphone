/** @file
 * Reconstructed interface for the Applilink reward SDK's private @c RewardCore singleton.
 *
 * @c RewardCore is the reward SDK's stateful core: a lazily-created (via @c dispatch_once)
 * singleton that owns the reward-advert session lifecycle. It drives the create-UDID,
 * post-install, get-installed, and web-view-presentation chain behind
 * @c openAdScreenWithParentView:adLocation:requestCode:delegate:, queries the all-install and
 * banner-display status through @c RewardWebAPI, hosts the reward advert inside a
 * @c RewardWebViewController, forwards the @c applilink://ext-app:80 redirect scheme, relays a
 * reward-video request to @c ApplilinkViewManager, and reports lifecycle and failure callbacks to
 * its Applilink delegate through @c ApplilinkCore. The public @c RewardNetwork facade forwards to
 * @c [RewardCore sharedInstance].
 *
 * This is Konami's applilink SDK, the same one REFLEC BEAT plus embeds; the sibling
 * @c ../rbplus-src tree reconstructs the same class from the other binary. This build diverges:
 * @c clearInitialize also clears the reward authentication-session expiry, there is an extra
 * @c showVideoViewWithQuery: relay into @c ApplilinkViewManager, and
 * @c redirectWithRequest: returns a different set of result codes.
 *
 * Reconstructed from Ghidra program Jubeat (class @c RewardCore, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base. The class object is at 0x348c98.
 */

#import <UIKit/UIKit.h>

@class ApplilinkParameters;
@class RewardWebViewController;
@protocol ApplilinkViewDelegate;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The reward SDK's stateful core singleton.
 */
@interface RewardCore : NSObject

/**
 * @brief The SDK initialisation flag: non-zero once the install record has been posted.
 *
 * The getter is overridden to return @c 0 whenever advertising tracking is disabled, regardless of
 * the stored value.
 * @ghidraAddress 0x23153c
 */
@property(nonatomic, assign) int initializeFlg;

/**
 * @brief Whether the reward advert screen hides its navigation bar.
 * @ghidraAddress 0x235cdc
 */
@property(nonatomic, assign) BOOL isNavigationBarHidden;

/**
 * @brief The hosted reward advert web-view controller, created lazily on first open.
 * @ghidraAddress 0x235cfc
 */
@property(nonatomic, strong, nullable) RewardWebViewController *rewardViewController;

/**
 * @brief The Applilink delegate that receives advert lifecycle and failure callbacks.
 * @ghidraAddress 0x235d44
 */
@property(nonatomic, weak, nullable) id<ApplilinkViewDelegate> applilinkDelegate;

/**
 * @brief The request parameters for the advert currently being opened.
 * @ghidraAddress 0x235d78
 */
@property(nonatomic, copy, nullable) ApplilinkParameters *applilinkParams;

/**
 * @brief The shared @c RewardCore instance (created with @c dispatch_once).
 * @return The shared instance.
 * @ghidraAddress 0x23148c
 */
+ (instancetype)sharedInstance;

#pragma mark Session lifecycle

/**
 * @brief Clear the initialisation flag, forget the stored campaign flag, and drop the reward
 * authentication-session expiry.
 * @ghidraAddress 0x231588
 */
- (void)clearInitialize;

/**
 * @brief The stored campaign flag for the current session.
 * @return The campaign flag, or @c -2 when tracking is off, the session is not initialised, or no
 * flag is stored.
 * @ghidraAddress 0x23163c
 */
- (int)campaignFlg;

/**
 * @brief Create the device UDID, then post the application-install event, initialising the session.
 * @param callback The completion block invoked with an error, or @c nil on success.
 * @ghidraAddress 0x231740
 */
- (void)startWithCallback:(nullable void (^)(NSError *_Nullable error))callback;

/**
 * @brief Ensure a valid reward authentication session, regenerating and re-logging in when needed.
 * @param block The completion block invoked with an error, or @c nil on success.
 * @ghidraAddress 0x231be8
 */
- (void)startSessionWithBlock:(nullable void (^)(NSError *_Nullable error))block;

/**
 * @brief Start the session (via @c startWithCallback:), refreshing the reward auth session after.
 * @param block The completion block invoked with an error, or @c nil on success.
 * @ghidraAddress 0x232100
 */
- (void)startWithBlock:(nullable void (^)(NSError *_Nullable error))block;

/**
 * @brief Create and persist the device UDID for the reward network.
 * @param block The completion block invoked with an error when creation fails.
 * @return @c YES when the UDID was created (or already present); @c NO when the block was invoked
 * with an error.
 * @ghidraAddress 0x232214
 */
- (BOOL)createUdidWithBlock:(nullable void (^)(NSError *_Nullable error))block;

/**
 * @brief Resolve, and persist to the keychain, the reward-network UDID for the stored storage
 * index.
 * @param error On failure, set to the localised error; may be @c nullptr.
 * @return @c YES on success.
 * @ghidraAddress 0x2323bc
 */
- (BOOL)createCFUdidWithError:(NSError *_Nullable *_Nullable)error;

#pragma mark Status queries

/**
 * @brief Query the all-install flag asynchronously.
 * @param callback The completion block, called with the all-install flag and an optional error.
 * @ghidraAddress 0x2326cc
 */
- (void)allInstallFlgWithCallback:(nullable void (^)(NSInteger flg,
                                                     NSError *_Nullable error))callback;

/**
 * @brief Query the ad-display status asynchronously.
 * @param callback The completion block, called with the status dictionary and an optional error.
 * @ghidraAddress 0x232924
 */
- (void)getAdDisplayStatusWithCallback:(nullable void (^)(NSDictionary *_Nullable status,
                                                          NSError *_Nullable error))callback;

/**
 * @brief Post the installed companion apps discovered on the device to the reward network.
 * @param callback The completion block, called with an error, or @c nil on success.
 * @ghidraAddress 0x232d2c
 */
- (void)postInstalledAppWithCallback:(nullable void (^)(NSError *_Nullable error))callback;

/**
 * @brief Query the full list of advertised application identifiers.
 * @param callback The completion block, called with the identifier array and an optional error.
 * @ghidraAddress 0x23320c
 */
- (void)getInstalledAppWithCallback:(nullable void (^)(NSArray *_Nullable appIdList,
                                                       NSError *_Nullable error))callback;

/**
 * @brief Query the app-list (reward-advert) status asynchronously.
 * @param block The completion block, called with the ad-status code and an optional error.
 * @ghidraAddress 0x233568
 */
- (void)getAppListStatusWithBlock:(nullable void (^)(NSInteger status,
                                                     NSError *_Nullable error))block;

#pragma mark Advert screen

/**
 * @brief Open the reward-advert screen inside @p parentView at @p adLocation, reporting to
 * @p delegate.
 * @param parentView The view that hosts the advert screen.
 * @param adLocation The ad-location identifier.
 * @param requestCode The request code forwarded to the SDK.
 * @param delegate The advert-screen delegate.
 * @ghidraAddress 0x233bc4
 */
- (void)openAdScreenWithParentView:(nullable UIView *)parentView
                        adLocation:(nullable NSString *)adLocation
                       requestCode:(nullable id)requestCode
                          delegate:(nullable id<ApplilinkViewDelegate>)delegate;

/**
 * @brief Close the reward-advert screen.
 * @ghidraAddress 0x2346fc
 */
- (void)closeAdScreen;

/**
 * @brief Rotate any open reward-advert screen to a new interface orientation.
 * @param interfaceOrientation The target @c UIInterfaceOrientation.
 * @param duration The animation duration.
 * @ghidraAddress 0x2347b4
 */
- (void)rotateAdScreenWithInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
                                      duration:(NSTimeInterval)duration;

/**
 * @brief Present a reward-video view for @p query through @c ApplilinkViewManager, hosted on the
 * open reward web-view controller's view.
 * @param query The video request query.
 * @ghidraAddress 0x2347d8
 */
- (void)showVideoViewWithQuery:(nullable NSString *)query;

/**
 * @brief Handle an @c applilink://ext-app:80 redirect request from the reward web view.
 * @param request The intercepted @c NSURLRequest.
 * @return @c 1 when the request is not an Applilink redirect, has no route, or the route was not
 * resolved; @c 0 when a path-segment URL was opened; @c 3 when a @c default_scheme URL was opened;
 * @c 4 when an app-store redirect was shown; or @c 7 for a recognised @c close route.
 * @ghidraAddress 0x2348e8
 */
- (int)redirectWithRequest:(nullable NSURLRequest *)request;

/**
 * @brief Set whether the reward advert screen hides its navigation bar.
 * @param navigationBarHidden @c YES to hide the navigation bar.
 * @ghidraAddress 0x235238
 */
- (void)setNavigationBarHidden:(BOOL)navigationBarHidden;

#pragma mark Temporary cache

/**
 * @brief Store a value in @c NSUserDefaults under @p key with an expiry.
 * @param key The cache key.
 * @param value The value to store.
 * @param expiration The lifetime in seconds; @c 0 stores a one-second lifetime.
 * @ghidraAddress 0x235248
 */
- (void)setTemporaryCacheWithKey:(nullable NSString *)key
                           value:(nullable id)value
                      expiration:(NSInteger)expiration;

/**
 * @brief Read a cached value from @c NSUserDefaults, removing it when it has expired.
 * @param key The cache key.
 * @return The cached value, or @c nil when it is absent or expired.
 * @ghidraAddress 0x2353fc
 */
- (nullable id)getTemporaryCacheWithKey:(nullable NSString *)key;

#pragma mark Delegate notifications

/**
 * @brief Report that the advert list started loading to the SDK delegate.
 * @param delegate The advert delegate.
 * @ghidraAddress 0x2355f0
 */
- (void)appListDidStart:(nullable id<ApplilinkViewDelegate>)delegate;

/**
 * @brief Report that the advert list appeared to the SDK delegate.
 * @param delegate The advert delegate.
 * @ghidraAddress 0x23561c
 */
- (void)appListDidAppear:(nullable id<ApplilinkViewDelegate>)delegate;

/**
 * @brief Report that the advert list disappeared to the SDK delegate.
 * @param delegate The advert delegate.
 * @ghidraAddress 0x235648
 */
- (void)appListDidDisappear:(nullable id<ApplilinkViewDelegate>)delegate;

/**
 * @brief Report a load failure to the SDK delegate.
 * @param error The load error.
 * @param delegate The advert delegate.
 * @ghidraAddress 0x235674
 */
- (void)appListFailLoadWithError:(nullable NSError *)error
                        delegate:(nullable id<ApplilinkViewDelegate>)delegate;

/**
 * @brief Report a link failure to the SDK delegate.
 * @param error The link error.
 * @param delegate The advert delegate.
 * @ghidraAddress 0x2356d8
 */
- (void)appListFailLinkWithError:(nullable NSError *)error
                        delegate:(nullable id<ApplilinkViewDelegate>)delegate;

#pragma mark Web-view notices

/**
 * @brief Notify the stored delegate that the advert list started (called by the web view).
 * @ghidraAddress 0x23573c
 */
- (void)startedNotice;

/**
 * @brief Notify the stored delegate that the advert list appeared (called by the web view).
 * @ghidraAddress 0x235788
 */
- (void)openedNotice;

/**
 * @brief Tear down the advert web view and notify the delegate it disappeared.
 * @ghidraAddress 0x2357d4
 */
- (void)closeNotice;

/**
 * @brief Notify the stored delegate of an advert open failure.
 * @param error The open error.
 * @ghidraAddress 0x235868
 */
- (void)failOpenNoticeWithError:(nullable NSError *)error;

/**
 * @brief Notify the stored delegate of an advert link failure.
 * @param error The link error.
 * @ghidraAddress 0x2358d8
 */
- (void)failLinkNoticeWithError:(nullable NSError *)error;

/**
 * @brief Notice hook for an advert open cancellation. The shipped build ignores the argument.
 * @param error The cancellation error.
 * @ghidraAddress 0x235948
 */
- (void)openCancelWithError:(nullable NSError *)error;

#pragma mark Cache and session teardown

/**
 * @brief Whether cached banner status may be used, clearing the cache when no UDID is available.
 * @return @c YES when any of the current, advertising, or old UDID is present.
 * @ghidraAddress 0x23594c
 */
- (BOOL)canUseBannerCache;

/**
 * @brief Clear the cached banner-display status and its expiry.
 * @ghidraAddress 0x235a28
 */
- (void)clearAdStatus;

/**
 * @brief Clear the reward session: delete every HTTP cookie and the stored session defaults.
 * @ghidraAddress 0x235a5c
 */
- (void)clearSession;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
