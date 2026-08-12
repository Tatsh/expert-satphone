/** @file
 * The applilink advertising SDK's public network front end.
 *
 * Reconstructed from Ghidra program Jubeat (class ApplilinkNetwork, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base. The class object is at 0x3529d8.
 *
 * This is Konami's applilink SDK; its full reconstruction
 * exists in the sibling @c ../rbplus-src tree. Every member is a thin class-method facade that
 * forwards to an internal SDK collaborator (@c ApplilinkCore , @c ApplilinkConsts , @c RewardCore ,
 * @c RecommendCore , @c ApplilinkViewManager ); the class holds no instance state.
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The SDK's network front end.
 */
@interface ApplilinkNetwork : NSObject

/**
 * @brief Brings the SDK up. @c +[JubeatAppDelegate initialize] passes @c "3" and @c "0".
 * @param appliId The applilink application identifier.
 * @param env The server environment name, or nil for production.
 * @param callback Invoked with an error, or nil on success.
 * @ghidraAddress 0x27c1ac
 */
+ (void)initializeWithAppliId:(nullable NSString *)appliId
                          env:(nullable NSString *)env
                     callback:(nullable void (^)(NSError *_Nullable error))callback;

/** @brief Resumes the SDK. @ghidraAddress 0x27c220 */
+ (void)resume;

/** @brief Sets the applilink user identifier, or nil to clear it. @ghidraAddress 0x27c238 */
+ (void)setUserId:(nullable NSString *)userId;

/** @brief Sets whether the SDK applies its common navigation-bar appearance.
 *  @ghidraAddress 0x27c250 */
+ (void)setNavigationBarCommonAppearance:(BOOL)navigationBarCommonAppearance;

/** @brief Sets whether the device languages take priority. @ghidraAddress 0x27c268 */
+ (void)setPriorityDeviceLanguages:(BOOL)priorityDeviceLanguages;

/** @brief Sets the loading-indicator colour. @ghidraAddress 0x27c280 */
+ (void)setIndicatorColor:(nullable UIColor *)indicatorColor;

/** @brief Marks the SDK unused in the store build. @ghidraAddress 0x27c298 */
+ (void)unusedInStore;

/** @brief Marks the build as produced under Xcode 6. @ghidraAddress 0x27c2b0 */
+ (void)buildUnderXcode6;

/** @brief The applilink application identifier. @ghidraAddress 0x27c2c8 */
+ (nullable NSString *)appliId;

/** @brief The SDK version. @ghidraAddress 0x27c2e0 */
+ (nullable NSString *)version;

/** @brief The SDK development version. @ghidraAddress 0x27c2f8 */
+ (nullable NSString *)versionDev;

/** @brief Whether the running iOS version supports the SDK. @ghidraAddress 0x27c310 */
+ (BOOL)isSupportediOSVersion;

/** @brief The current advertising UDID. @ghidraAddress 0x27c328 */
+ (nullable NSString *)currentUdid;

/**
 * @brief Forwards a rotation to the reward, recommend, and view-manager collaborators.
 * @param interfaceOrientation The new interface orientation.
 * @param duration The rotation duration.
 * @ghidraAddress 0x27c340
 */
+ (void)rotateWithInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
                              duration:(NSTimeInterval)duration;

/** @brief Collects device information for the SDK. @ghidraAddress 0x27c458 */
+ (void)collectDeviceInfo;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
