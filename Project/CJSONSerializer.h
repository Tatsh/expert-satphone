/** @file
 * TouchJSON's serialiser.
 *
 * Reconstructed from Ghidra program Jubeat (class CJSONSerializer, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * This is third-party code bundled into the application, so the names are TouchJSON's rather than
 * Konami's.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief An object may opt into serialisation by vending its own JSON data; TouchJSON's extension
 *        point.
 */
@protocol CJSONDataRepresentation <NSObject>
- (NSData *)JSONDataRepresentation;
@end

/**
 * @brief Turns Foundation objects into JSON data.
 */
@interface CJSONSerializer : NSObject

/**
 * @brief Serialisation options. A set low bit makes @c -serializeString:error: escape the forward
 * slash.
 */
@property(nonatomic) NSUInteger options;

/**
 * @brief Vends a fresh serialiser instance.
 * @return A new @c CJSONSerializer .
 * @ghidraAddress 0x66acc
 */
+ (instancetype)serializer;

/**
 * @brief Whether an object is one the serialiser can turn into JSON.
 * @param object The object to test.
 * @return YES for @c NSNull , @c NSNumber , @c NSString , @c NSArray , @c NSDictionary , @c NSData
 * , or any object answering @c -JSONDataRepresentation .
 * @ghidraAddress 0x66af4
 */
- (BOOL)isValidJSONObject:(nullable id)object;

/**
 * @brief Serialises any supported object to JSON data, dispatching on its class.
 * @param object The object to serialise.
 * @param error Out: the failure reason when serialisation fails.
 * @return The JSON data, or @c nil on failure.
 * @ghidraAddress 0x66c60
 */
- (nullable NSData *)serializeObject:(nullable id)object error:(NSError *_Nullable *_Nullable)error;

/**
 * @brief Serialises a null to the shared @c "null" token data.
 * @ghidraAddress 0x67118
 */
- (nullable NSData *)serializeNull:(nullable NSNull *)null
                             error:(NSError *_Nullable *_Nullable)error;

/**
 * @brief Serialises a number: a boolean to the shared @c "true"/"false" token data, otherwise its
 * string value as UTF-8.
 * @ghidraAddress 0x67124
 */
- (nullable NSData *)serializeNumber:(nullable NSNumber *)number
                               error:(NSError *_Nullable *_Nullable)error;

/**
 * @brief Serialises a string as a quoted, escaped JSON string.
 * @ghidraAddress 0x67220
 */
- (nullable NSData *)serializeString:(nullable NSString *)string
                               error:(NSError *_Nullable *_Nullable)error;

/**
 * @brief Serialises an array as a JSON array.
 * @ghidraAddress 0x6743c
 */
- (nullable NSData *)serializeArray:(nullable NSArray *)array
                              error:(NSError *_Nullable *_Nullable)error;

/**
 * @brief Serialises a dictionary as a JSON object.
 * @ghidraAddress 0x67608
 */
- (nullable NSData *)serializeDictionary:(nullable NSDictionary *)dictionary
                                   error:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
