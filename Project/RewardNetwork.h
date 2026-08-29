/**
 * @file
 * @brief The Applilink reward-network advert facade: a thin public wrapper over the private
 * @c RewardCore singleton and the @c ApplilinkConsts / @c ApplilinkNetworkError helpers.
 *
 * It opens and closes the advert screen and forwards the ad-status, all-install-flag, and
 * ad-display-status queries.
 *
 * Reconstructed from Ghidra program Jubeat (class RewardNetwork, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base. The class object is at 0x3522f8.
 * This is Konami's applilink SDK.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The companion-application reward-advert facade over the Applilink SDK.
 *
 * Every method forwards to @c [RewardCore sharedInstance] once @c ApplilinkConsts reports the SDK
 * is usable on this device.
 */
@interface RewardNetwork : NSObject

/**
 * @brief Opens the reward-advert screen at the given ad location without a parent view.
 * @param adLocation The ad-location identifier, such as @c "ADL_TOP".
 * @param requestCode The request code forwarded to the SDK.
 * @param delegate The advert-screen delegate.
 * @ghidraAddress 0x24f590
 */
+ (void)openAdScreenWithAdLocation:(nullable NSString *)adLocation
                       requestCode:(nullable id)requestCode
                          delegate:(nullable id)delegate;

/**
 * @brief Opens the reward-advert screen inside @p parentView at the given ad location.
 * @param parentView The view that hosts the advert screen.
 * @param adLocation The ad-location identifier.
 * @param delegate The advert-screen delegate.
 * @ghidraAddress 0x24f604
 */
+ (void)openAdScreenWithParentView:(nullable UIView *)parentView
                        adLocation:(nullable NSString *)adLocation
                          delegate:(nullable id)delegate;

/**
 * @brief Opens the reward-advert screen inside @p parentView with a request code.
 * @param parentView The view that hosts the advert screen.
 * @param adLocation The ad-location identifier.
 * @param requestCode The request code forwarded to the SDK.
 * @param delegate The advert-screen delegate.
 * @ghidraAddress 0x24f678
 */
+ (void)openAdScreenWithParentView:(nullable UIView *)parentView
                        adLocation:(nullable NSString *)adLocation
                       requestCode:(nullable id)requestCode
                          delegate:(nullable id)delegate;

/**
 * @brief Closes the reward-advert screen.
 * @ghidraAddress 0x24f874
 */
+ (void)closeAdScreen;

/**
 * @brief Queries the all-install flag asynchronously.
 * @param callback The completion block, called with the all-install flag and an optional error.
 * @ghidraAddress 0x24f8ec
 */
+ (void)allInstallFlgWithCallback:(nullable void (^)(NSInteger flg,
                                                     NSError *_Nullable error))callback;

/**
 * @brief Queries the ad-display status asynchronously.
 * @param callback The completion block, called with a status dictionary (keyed @c "allInstallFlg"
 *        and @c "bannerDisplayStatus") and an optional error.
 * @ghidraAddress 0x24fa4c
 */
+ (void)getAdDisplayStatusWithCallback:(nullable void (^)(NSDictionary *_Nullable status,
                                                          NSError *_Nullable error))callback;

/**
 * @brief Queries the reward-advert status asynchronously.
 * @param block The completion block, called with the ad-status code and an optional error.
 * @ghidraAddress 0x24fc80
 */
+ (void)getAdStatusWithBlock:(nullable void (^)(NSInteger status, NSError *_Nullable error))block;

/**
 * @brief Hides or shows the reward-advert navigation bar.
 * @param navigationBarHidden Whether the navigation bar should be hidden.
 * @ghidraAddress 0x24fde0
 */
+ (void)setNavigationBarHidden:(BOOL)navigationBarHidden;

/**
 * @brief The localised reward app-list navigation-bar title.
 * @return The localised title from the reward message bundle.
 * @ghidraAddress 0x24fe38
 */
+ (nullable NSString *)getNavigationTitle;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
