/** @file
 * TouchJSON's scanner, which does the actual parsing.
 *
 * Reconstructed from Ghidra program Jubeat (class CJSONScanner, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * RECONSTRUCTION STATE: a stub grown outwards from its callers. Only the members
 * @c CJSONDeserializer forwards to are declared.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Scans JSON text into Foundation objects.
 */
@interface CJSONScanner : NSObject

/**
 * @brief What a JSON @c null becomes. DECLARED ONLY.
 */
@property(nonatomic, strong, nullable) id nullObject;

/**
 * @brief Which text encoding the input is allowed to be in. DECLARED ONLY.
 */
@property(nonatomic) NSUInteger allowedEncoding;

/**
 * @brief Points the scanner at some JSON text. DECLARED ONLY.
 * @param data The text.
 * @param outError Where to report a failure.
 * @return Whether the data was accepted.
 */
- (BOOL)setData:(nullable NSData *)data error:(NSError *__autoreleasing *)outError;

/**
 * @brief Scans whatever the text describes. DECLARED ONLY.
 * @param outObject Where to put the result.
 * @param outError Where to report a failure.
 * @return Whether the scan succeeded.
 */
- (BOOL)scanJSONObject:(id __autoreleasing *)outObject error:(NSError *__autoreleasing *)outError;

/**
 * @brief Scans, requiring a dictionary. DECLARED ONLY.
 * @param outDictionary Where to put the result.
 * @param outError Where to report a failure.
 * @return Whether the scan succeeded.
 */
- (BOOL)scanJSONDictionary:(NSDictionary *__autoreleasing *)outDictionary
                     error:(NSError *__autoreleasing *)outError;

/**
 * @brief Scans, requiring an array. DECLARED ONLY.
 * @param outArray Where to put the result.
 * @param outError Where to report a failure.
 * @return Whether the scan succeeded.
 */
- (BOOL)scanJSONArray:(NSArray *__autoreleasing *)outArray
                error:(NSError *__autoreleasing *)outError;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
