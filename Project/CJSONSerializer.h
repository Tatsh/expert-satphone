/** @file
 * TouchJSON's serialiser.
 *
 * Reconstructed from Ghidra program Jubeat (class CJSONSerializer, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * This is third-party code bundled into the application, so the names are TouchJSON's rather than
 * Konami's. In this build only the two entry points survive in the metadata: @c +initialize , which
 * primes the shared @c null / @c false / @c true token data, and @c +serializer , which vends a
 * fresh instance.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Turns Foundation objects into JSON data.
 */
@interface CJSONSerializer : NSObject

/**
 * @brief Vends a fresh serialiser instance.
 * @return A new @c CJSONSerializer .
 * @ghidraAddress 0x66acc
 */
+ (instancetype)serializer;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
