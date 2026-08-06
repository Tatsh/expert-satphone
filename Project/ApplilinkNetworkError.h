/** @file
 * The applilink SDK's localised @c NSError factory.
 *
 * Reconstructed from Ghidra program Jubeat (class ApplilinkNetworkError, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * The class owns the applilink error domain and a table mapping each error code to a localised
 * message, built once on the first call and cached in a file-scope global.
 *
 * The sibling `../rbplus-src` reconstructs the same class from the other binary and carries **40**
 * error codes; this build carries **43**, adding 1040 to 1042. That is the same version divergence
 * already recorded for `+[ApplilinkMessage localizedMessage:]`, so the disagreement is evidence
 * about SDK revisions rather than a reason to doubt either reading.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The domain of every @c NSError this class produces.
 * @ghidraAddress 0x2e4a80
 */
extern NSErrorDomain const ApplilinkErrorDomain;

/**
 * @brief Builds applilink errors carrying a localised description.
 */
@interface ApplilinkNetworkError : NSObject

/**
 * @brief Builds a localised error with no caller-supplied user info.
 *
 * A tail call to @c +localizedApplilinkErrorWithCode:userInfo: with nil.
 * @param code The applilink error code.
 * @return The error, in @c ApplilinkErrorDomain.
 * @ghidraAddress 0x23f56c
 */
+ (NSError *)localizedApplilinkErrorWithCode:(NSInteger)code;

/**
 * @brief Builds a localised error, merging caller-supplied user-info entries.
 *
 * The returned error's user info is @c userInfo plus the localised description for @c code under
 * @c NSLocalizedDescriptionKey. A code with no entry falls back to the unexpected-error message.
 *
 * @param code The applilink error code.
 * @param userInfo Entries to merge, or nil.
 * @return The error, in @c ApplilinkErrorDomain.
 * @ghidraAddress 0x23ce68
 */
+ (NSError *)localizedApplilinkErrorWithCode:(NSInteger)code
                                    userInfo:(nullable NSDictionary *)userInfo;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
