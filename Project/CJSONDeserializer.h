/** @file
 * TouchJSON's deserialiser.
 *
 * Reconstructed from Ghidra program Jubeat (class CJSONDeserializer, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c NSObject, from the dyld bind at the class object's superclass slot
 * (0x34cdb0).
 *
 * This is third-party code bundled into the application, so the names are TouchJSON's rather than
 * Konami's. The class is a facade: two of its four properties have no storage of their own and read
 * and write the scanner's instead.
 */

#import <Foundation/Foundation.h>

#import "CJSONScanner.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Turns JSON data into Foundation objects.
 */
@interface CJSONDeserializer : NSObject

/**
 * @brief The scanner that does the work, built on first use.
 * @ghidraAddress 0x63564 (getter)
 */
@property(nonatomic, strong, nullable) CJSONScanner *scanner;

/**
 * @brief What a JSON @c null becomes.
 *
 * Stored on the scanner, not here — the property has no backing ivar in the metadata.
 * @ghidraAddress 0x635c4 (getter)
 */
@property(nonatomic, strong, nullable) id nullObject;

/**
 * @brief Which text encoding the input is allowed to be in.
 *
 * Also stored on the scanner rather than here.
 * @ghidraAddress 0x63684 (getter)
 */
@property(nonatomic) NSUInteger allowedEncoding;

/**
 * @brief Deserialisation options.
 *
 * Unlike the two above, this one does have its own ivar — and nothing in the class reads it.
 * @ghidraAddress 0x63b34 (getter)
 */
@property(nonatomic) NSUInteger options;

/**
 * @brief A new autoreleased deserialiser.
 * @return The deserialiser.
 * @ghidraAddress 0x63504
 */
+ (instancetype)deserializer;

/**
 * @brief Builds a deserialiser. The scanner is not created here.
 * @return The initialised deserialiser.
 * @ghidraAddress 0x6352c
 */
- (instancetype)init;

/**
 * @brief Deserialises to whatever the JSON describes.
 *
 * Nil and empty input are the same case, and both are reported as error -11 rather than as an
 * empty result.
 *
 * @param data The JSON text.
 * @param outError Where to report a parse failure.
 * @return The parsed object, or nil.
 * @ghidraAddress 0x63718
 */
- (nullable id)deserialize:(nullable NSData *)data error:(NSError *__autoreleasing *)outError;

/**
 * @brief Deserialises, requiring a dictionary at the top level.
 *
 * @param data The JSON text.
 * @param outError Where to report a parse failure.
 * @return The parsed dictionary, or nil.
 * @ghidraAddress 0x63870
 */
- (nullable NSDictionary *)deserializeAsDictionary:(nullable NSData *)data
                                             error:(NSError *__autoreleasing *)outError;

/**
 * @brief Deserialises, requiring an array at the top level.
 *
 * @param data The JSON text.
 * @param outError Where to report a parse failure.
 * @return The parsed array, or nil.
 * @ghidraAddress 0x639c8
 */
- (nullable NSArray *)deserializeAsArray:(nullable NSData *)data
                                   error:(NSError *__autoreleasing *)outError;

@end

/**
 * @brief TouchJSON's convenience category vending a deserialised dictionary in one call.
 */
@interface NSDictionary (CJSONDeserializer)

/**
 * @brief Deserialises JSON data to a dictionary via a fresh @c CJSONDeserializer.
 * @param data The JSON text.
 * @param error Where to report a parse failure.
 * @return The parsed dictionary, or nil.
 */
+ (nullable id)dictionaryWithJSONData:(nullable NSData *)data error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
