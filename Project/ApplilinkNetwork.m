#import "ApplilinkNetwork.h"

#import "ApplilinkConsts.h"
#import "ApplilinkCore.h"
#import "ApplilinkViewManager.h"
#import "RecommendCore.h"
#import "RewardCore.h"

@implementation ApplilinkNetwork

#pragma mark - Lifecycle

/** @ghidraAddress 0x27c1ac */
+ (void)initializeWithAppliId:(NSString *)appliId
                          env:(NSString *)env
                     callback:(void (^)(NSError *error))callback {
    [ApplilinkCore initializeWithAppliId:appliId env:env resume:NO callback:callback];
}

/** @ghidraAddress 0x27c220 */
+ (void)resume {
    [ApplilinkCore resume];
}

#pragma mark - Configuration

/** @ghidraAddress 0x27c238 */
+ (void)setUserId:(NSString *)userId {
    [ApplilinkConsts setUserId:userId];
}

/** @ghidraAddress 0x27c250 */
+ (void)setNavigationBarCommonAppearance:(BOOL)navigationBarCommonAppearance {
    [ApplilinkCore setNavigationBarCommonAppearance:navigationBarCommonAppearance];
}

/** @ghidraAddress 0x27c268 */
+ (void)setPriorityDeviceLanguages:(BOOL)priorityDeviceLanguages {
    [ApplilinkCore setPriorityDeviceLanguages:priorityDeviceLanguages];
}

/** @ghidraAddress 0x27c280 */
+ (void)setIndicatorColor:(UIColor *)indicatorColor {
    [ApplilinkCore setIndicatorColor:indicatorColor];
}

/** @ghidraAddress 0x27c298 */
+ (void)unusedInStore {
    [ApplilinkCore unusedInStore];
}

/** @ghidraAddress 0x27c2b0 */
+ (void)buildUnderXcode6 {
    [ApplilinkCore buildUnderXcode6];
}

#pragma mark - Identifiers and version

/** @ghidraAddress 0x27c2c8 */
+ (NSString *)appliId {
    return [ApplilinkConsts appliId];
}

/** @ghidraAddress 0x27c2e0 */
+ (NSString *)version {
    return [ApplilinkConsts version];
}

/** @ghidraAddress 0x27c2f8 */
+ (NSString *)versionDev {
    return [ApplilinkCore versionDev];
}

/** @ghidraAddress 0x27c310 */
+ (BOOL)isSupportediOSVersion {
    return [ApplilinkConsts canUseApplilinkSdk];
}

/** @ghidraAddress 0x27c328 */
+ (NSString *)currentUdid {
    return [ApplilinkCore currentUdid];
}

#pragma mark - Rotation and device info

/** @ghidraAddress 0x27c340 */
+ (void)rotateWithInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
                              duration:(NSTimeInterval)duration {
    if (![ApplilinkConsts canUseApplilinkSdk]) {
        return;
    }
    [[RewardCore sharedInstance] rotateAdScreenWithInterfaceOrientation:interfaceOrientation
                                                               duration:duration];
    [[RecommendCore sharedInstance] rotateWithInterfaceOrientation:interfaceOrientation
                                                          duration:duration];
    [[ApplilinkViewManager sharedInstance] rotateWithInterfaceOrientation:interfaceOrientation
                                                                 duration:duration];
}

/** @ghidraAddress 0x27c458 */
+ (void)collectDeviceInfo {
    [ApplilinkCore collectDeviceInfoCore];
}

@end
