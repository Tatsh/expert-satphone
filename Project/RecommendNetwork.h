/**
 * @file
 * @brief The Applilink recommend network's public facade.
 *
 * A thin class-method facade over the private @c RecommendCore singleton: each entry point asks
 * @c ApplilinkConsts whether it may run, then forwards to @c RecommendCore (dispatching the status
 * queries onto a global queue) or reports a localised error to the caller.
 *
 * Reconstructed from Ghidra program Jubeat (class RecommendNetwork, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base. The class object is at 0x352078.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The recommend advert models.
 */
typedef NS_ENUM(NSInteger, RecommendAdModel) {
    RecommendAdModelAppList = 1,      /*!< The companion-application list advert model. */
    RecommendAdModelInterstitial = 5, /*!< The full-screen interstitial advert model. */
    RecommendAdModelOwnAd = 100,      /*!< The first-party (own) advert model. */
};

/** @brief Called with an advert status code and an optional error. */
typedef void (^RecommendAdStatusCallback)(NSInteger status, NSError *_Nullable error);

/** @brief Called with an advert display-status dictionary and an optional error. */
typedef void (^RecommendAdDisplayStatusCallback)(NSDictionary *_Nullable status,
                                                 NSError *_Nullable error);

/**
 * @brief The recommend network's public advert facade.
 */
@interface RecommendNetwork : NSObject

/**
 * @brief Queries the application-list status.
 * @param callback Called with the status code, or with an error when the query cannot run.
 * @ghidraAddress 0x23f588
 */
+ (void)getAppListStatusWithCallback:(nullable RecommendAdStatusCallback)callback;

/**
 * @brief Queries the advert status for a model.
 * @param adModel The advert model to query.
 * @param callback Called with the status code, or with an error when the query cannot run.
 * @ghidraAddress 0x23f5a4
 */
+ (void)getAdStatusWithAdModel:(RecommendAdModel)adModel
                      callback:(nullable RecommendAdStatusCallback)callback;

/**
 * @brief Queries the unread count for a model at a location.
 * @param adModel The advert model to query.
 * @param adLocation The advert placement identifier.
 * @param callback Called with the unread count, or with an error when the query cannot run.
 * @ghidraAddress 0x23f714
 */
+ (void)getUnreadCountWithAdModel:(RecommendAdModel)adModel
                       adLocation:(nullable NSString *)adLocation
                         callback:(nullable RecommendAdStatusCallback)callback;

/**
 * @brief Queries the advert display status for a model at a location.
 * @param adModel The advert model to query.
 * @param adLocation The advert placement identifier.
 * @param callback Called with the display-status dictionary, or with an error when the query cannot
 *                 run.
 * @ghidraAddress 0x23f8f4
 */
+ (void)getAdDisplayStatusWithAdModel:(RecommendAdModel)adModel
                           adLocation:(nullable NSString *)adLocation
                             callback:(nullable RecommendAdDisplayStatusCallback)callback;

/**
 * @brief Shows a first-party advert.
 * @param adLocation The advert placement identifier.
 * @param appliId The advertised application's identifier.
 * @param creativeId The advert creative's identifier.
 * @ghidraAddress 0x23fba8
 */
+ (void)showOwnAdWithAdLocation:(nullable NSString *)adLocation
                      toAppliId:(nullable NSString *)appliId
                     creativeId:(nullable NSString *)creativeId;

/**
 * @brief Shows a first-party advert for a model.
 * @param adLocation The advert placement identifier.
 * @param adModel The advert model to show.
 * @param appliId The advertised application's identifier.
 * @param creativeId The advert creative's identifier.
 * @ghidraAddress 0x23fc6c
 */
+ (void)showOwnAdWithAdLocation:(nullable NSString *)adLocation
                        adModel:(RecommendAdModel)adModel
                      toAppliId:(nullable NSString *)appliId
                     creativeId:(nullable NSString *)creativeId;

/**
 * @brief Registers a first-party advert touch.
 * @param adLocation The advert placement identifier.
 * @param appliId The advertised application's identifier.
 * @param creativeId The advert creative's identifier.
 * @param requestCode The caller's token, handed back to @p delegate to correlate the result.
 * @param delegate The object told how the request finished.
 * @ghidraAddress 0x23fd40
 */
+ (void)touchOwnAdWithAdLocation:(nullable NSString *)adLocation
                       toAppliId:(nullable NSString *)appliId
                      creativeId:(nullable NSString *)creativeId
                     requestCode:(nullable id)requestCode
                        delegate:(nullable id)delegate;

/**
 * @brief Registers a first-party advert touch for a model.
 * @param adLocation The advert placement identifier.
 * @param adModel The advert model that was touched.
 * @param appliId The advertised application's identifier.
 * @param creativeId The advert creative's identifier.
 * @param requestCode The caller's token, handed back to @p delegate to correlate the result.
 * @param delegate The object told how the request finished.
 * @ghidraAddress 0x23fe58
 */
+ (void)touchOwnAdWithAdLocation:(nullable NSString *)adLocation
                         adModel:(RecommendAdModel)adModel
                       toAppliId:(nullable NSString *)appliId
                      creativeId:(nullable NSString *)creativeId
                     requestCode:(nullable id)requestCode
                        delegate:(nullable id)delegate;

/**
 * @brief Opens the application list.
 * @param adLocation The advert placement identifier.
 * @param delegate The object told how the request finished.
 * @ghidraAddress 0x23ff80
 */
+ (void)openAppListWithAdLocation:(nullable NSString *)adLocation delegate:(nullable id)delegate;

/**
 * @brief Opens the application list with a request code.
 * @param adLocation The advert placement identifier.
 * @param requestCode The caller's token, handed back to @p delegate to correlate the result.
 * @param delegate The object told how the request finished.
 * @ghidraAddress 0x23ffd8
 */
+ (void)openAppListWithAdLocation:(nullable NSString *)adLocation
                      requestCode:(nullable id)requestCode
                         delegate:(nullable id)delegate;

/**
 * @brief Opens the advert screen for a model.
 * @param adModel The advert model to show.
 * @param adLocation The advert placement identifier.
 * @param delegate The object told how the request finished.
 * @ghidraAddress 0x2401c4
 */
+ (void)openAdScreenWithAdModel:(RecommendAdModel)adModel
                     adLocation:(nullable NSString *)adLocation
                       delegate:(nullable id)delegate;

/**
 * @brief Opens the advert screen for a model with a request code.
 * @param adModel The advert model to show.
 * @param adLocation The advert placement identifier.
 * @param requestCode The caller's token, handed back to @p delegate to correlate the result.
 * @param delegate The object told how the request finished.
 * @ghidraAddress 0x240224
 */
+ (void)openAdScreenWithAdModel:(RecommendAdModel)adModel
                     adLocation:(nullable NSString *)adLocation
                    requestCode:(nullable id)requestCode
                       delegate:(nullable id)delegate;

/**
 * @brief Opens an advert area inside a view.
 * @param parentView The view the advert area is added to.
 * @param rect The advert area's frame within @p parentView .
 * @param adModel The advert model to show.
 * @param adLocation The advert placement identifier.
 * @param verticalAlign The advert's vertical alignment within @p rect .
 * @param delegate The object told how the request finished.
 * @ghidraAddress 0x240414
 */
+ (void)openAdAreaWithParentView:(nullable UIView *)parentView
                            rect:(CGRect)rect
                         adModel:(RecommendAdModel)adModel
                      adLocation:(nullable NSString *)adLocation
                   verticalAlign:(int)verticalAlign
                        delegate:(nullable id)delegate;

/**
 * @brief Opens an advert area inside a view with a request code.
 * @param parentView The view the advert area is added to.
 * @param rect The advert area's frame within @p parentView .
 * @param adModel The advert model to show.
 * @param adLocation The advert placement identifier.
 * @param verticalAlign The advert's vertical alignment within @p rect .
 * @param requestCode The caller's token, handed back to @p delegate to correlate the result.
 * @param delegate The object told how the request finished.
 * @ghidraAddress 0x2404d0
 */
+ (void)openAdAreaWithParentView:(nullable UIView *)parentView
                            rect:(CGRect)rect
                         adModel:(RecommendAdModel)adModel
                      adLocation:(nullable NSString *)adLocation
                   verticalAlign:(int)verticalAlign
                     requestCode:(nullable id)requestCode
                        delegate:(nullable id)delegate;

/**
 * @brief Opens an interstitial advert.
 * @param adLocation The advert placement identifier.
 * @param delegate The object told how the request finished.
 * @ghidraAddress 0x240718
 */
+ (void)openInterstitialWithAdLocation:(nullable NSString *)adLocation
                              delegate:(nullable id)delegate;

/**
 * @brief Opens an interstitial advert with a request code.
 * @param adLocation The advert placement identifier.
 * @param requestCode The caller's token, handed back to @p delegate to correlate the result.
 * @param delegate The object told how the request finished.
 * @ghidraAddress 0x240770
 */
+ (void)openInterstitialWithAdLocation:(nullable NSString *)adLocation
                           requestCode:(nullable id)requestCode
                              delegate:(nullable id)delegate;

/**
 * @brief Opens an interstitial movie advert.
 * @param adLocation The advert placement identifier.
 * @param delegate The object told how the request finished.
 * @ghidraAddress 0x240958
 */
+ (void)openInterstitialMovieWithAdLocation:(nullable NSString *)adLocation
                                   delegate:(nullable id)delegate;

/**
 * @brief Opens an interstitial movie advert with a request code.
 * @param adLocation The advert placement identifier.
 * @param requestCode The caller's token, handed back to @p delegate to correlate the result.
 * @param delegate The object told how the request finished.
 * @ghidraAddress 0x2409b0
 */
+ (void)openInterstitialMovieWithAdLocation:(nullable NSString *)adLocation
                                requestCode:(nullable id)requestCode
                                   delegate:(nullable id)delegate;

/** @brief Closes the advert screen. @ghidraAddress 0x240b98 */
+ (void)closeAdScreen;

/**
 * @brief Closes any advert area inside a view.
 * @param parentView The view whose advert area is closed.
 * @ghidraAddress 0x240c10
 */
+ (void)closeAdAreaWithParentView:(nullable UIView *)parentView;

/**
 * @brief Shows or hides any advert area inside a view.
 * @param parentView The view whose advert area is shown or hidden.
 * @param flag YES to show the advert area, NO to hide it.
 * @ghidraAddress 0x240e54
 */
+ (void)setAdAreaVisibleWithParentView:(nullable UIView *)parentView flag:(BOOL)flag;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
