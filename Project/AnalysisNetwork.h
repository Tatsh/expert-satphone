/** @file
 * The guarded facade in front of the applilink SDK's analytics transport.
 *
 * Reconstructed from Ghidra program Jubeat (class AnalysisNetwork, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The class has no ivars and no properties: all three members are class methods that forward to
 * @c AnalysisNetworkCore.
 */

#import <Foundation/Foundation.h>

#import "AnalysisNetworkCore.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Forwards analytics calls to @c AnalysisNetworkCore, guarding the one that has a callback.
 *
 * Note the guard is not applied uniformly — see @c +openWebBrowserWithAppliId:env:callback: .
 */
@interface AnalysisNetwork : NSObject

/**
 * @brief Posts one analysis record, or reports that the SDK is unusable.
 *
 * The only member that consults @c ApplilinkConsts. When the SDK cannot be used the callback is
 * invoked directly with error 1025, @c ApplilinkErrorSdkVersionNotSupported, and nothing is sent.
 *
 * @param resultId The record's identifier.
 * @param callback Answered with nil on success or an error on failure.
 * @ghidraAddress 0x2410a4
 */
+ (void)postAnalysisDataWithResultId:(nullable NSString *)resultId
                            callback:(nullable ApplilinkAnalysisCallback)callback;

/**
 * @brief Opens an advert in the external browser, discarding any error.
 *
 * Supplies an empty callback to the core, so a failure here is silent. Note also that this does
 * not check whether the SDK can be used.
 *
 * @param url The advert's address.
 * @param env The SDK environment.
 * @ghidraAddress 0x24116c
 */
+ (void)openExternalWebBrowser:(nullable NSString *)url env:(nullable NSString *)env;

/**
 * @brief Opens an advert for one application identifier.
 *
 * A straight forward with no SDK-availability check, so on an unsupported OS this reaches the
 * transport where @c +postAnalysisDataWithResultId:callback: would have refused.
 *
 * @param appliId The application identifier to open.
 * @param env The SDK environment.
 * @param callback Answered by the core.
 * @ghidraAddress 0x2411c4
 */
+ (void)openWebBrowserWithAppliId:(nullable NSString *)appliId
                              env:(nullable NSString *)env
                         callback:(nullable ApplilinkAnalysisCallback)callback;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
