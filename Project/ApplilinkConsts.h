/** @file
 * The applilink SDK's compile-time and runtime constants.
 *
 * Reconstructed from Ghidra program Jubeat (class ApplilinkConsts, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: a stub grown outwards from its callers. Only the one member reached so far
 * is declared.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Answers questions about what the SDK can do on this device.
 */
@interface ApplilinkConsts : NSObject

/**
 * @brief Whether the SDK is usable at all on this OS version.
 *
 * Callers that get NO answer their own callbacks with error 1025,
 * @c ApplilinkErrorSdkVersionNotSupported, whose message names iOS 6.1 as the floor.
 * DECLARED ONLY.
 * @ghidraAddress 0x22ec4c
 */
@property(class, nonatomic, readonly) BOOL canUseApplilinkSdk;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
