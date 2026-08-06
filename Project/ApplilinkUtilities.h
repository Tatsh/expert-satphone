/** @file
 * The applilink SDK's shared helpers.
 *
 * Reconstructed from Ghidra program Jubeat (class ApplilinkUtilities, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: a stub grown outwards from its callers. Only the one member reached so far
 * is declared.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Free-standing helpers the SDK's request builders share.
 */
@interface ApplilinkUtilities : NSObject

/**
 * @brief Flattens a parameter dictionary into a query string, adding the SDK's own user-agent
 * parameters.
 *
 * DECLARED ONLY.
 *
 * @param dictionary The caller's parameters.
 * @return The joined string.
 */
+ (nullable NSString *)userAgentParametersJoinDictionary:(nullable NSDictionary *)dictionary;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
