/**
 * @file
 * @brief TouchJSON's @c NSDictionary @c JSONExtensions category.
 *
 * Reconstructed from Ghidra program Jubeat (image base 0x100000000). All @ghidraAddress values are
 * offsets relative to that image base. This is TouchJSON's convenience category, so the names are
 * TouchJSON's rather than Konami's. Both entry points build a fresh @c CJSONDeserializer per call
 * and forward to its generic @c deserialize:error:, so despite the @c dictionary… names neither
 * validates that the parsed root is actually a dictionary: a JSON document whose root is an array
 * comes back as an @c NSArray.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief One-call JSON deserialisation vending a Foundation object.
 */
@interface NSDictionary (JSONExtensions)

/**
 * @brief Deserialises JSON data via a fresh @c CJSONDeserializer.
 * @param data The JSON text.
 * @param error Out-parameter for a parse failure; may be @c NULL.
 * @return The parsed object, autoreleased, or @c nil on failure.
 * @ghidraAddress 0x633f8
 */
+ (nullable id)dictionaryWithJSONData:(nullable NSData *)data error:(NSError **)error;

/**
 * @brief Deserialises a JSON string by encoding it as UTF-8 and deferring to
 *        @c dictionaryWithJSONData:error:.
 * @param string The JSON text.
 * @param error Out-parameter for a parse failure; may be @c NULL.
 * @return The parsed object, autoreleased, or @c nil on failure.
 * @ghidraAddress 0x63488
 */
+ (nullable id)dictionaryWithJSONString:(nullable NSString *)string error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
