/** @file
 * The JSON serialiser.
 *
 * Reconstructed from Ghidra program Jubeat (class CJSONSerializer, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: a stub grown outwards from its callers. The class object is at 0x348248.
 *
 * This is third-party code, not the application's own, which is why it sits under 3rdparty/ rather
 * than Project/. The class name and the two-member shape below — a @c +serializer convenience
 * constructor and @c -serializeDictionary:error: returning @c NSData — match TouchJSON. That is an
 * identification from the interface, not from a version string in the binary, so it is stated here
 * rather than asserted by vendoring the upstream sources.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Turns Foundation containers into JSON.
 */
@interface CJSONSerializer : NSObject

/**
 * @brief A new serialiser. DECLARED ONLY.
 */
+ (instancetype)serializer;

/**
 * @brief Serialises a dictionary to UTF-8 JSON.
 *
 * The one reconstructed caller passes NULL for the error, so a serialisation failure is not
 * distinguished from success there. DECLARED ONLY.
 *
 * @param dictionary The object graph to serialise.
 * @param error Out-parameter for the failure reason, or NULL.
 * @return The encoded JSON, or nil on failure.
 */
- (nullable NSData *)serializeDictionary:(NSDictionary *)dictionary
                                   error:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
