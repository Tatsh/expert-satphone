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

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
