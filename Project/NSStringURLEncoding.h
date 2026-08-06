/** @file
 * The applilink SDK's URL percent-encoding helper.
 *
 * Reconstructed from Ghidra program Jubeat (class NSStringURLEncoding, image base 0x100000000).
 * All @ghidraAddress values are offsets relative to that image base.
 *
 * Despite the name this is a standalone @c NSObject subclass, not a category on @c NSString: the
 * runtime metadata carries it as its own class with two class methods and no ivars.
 *
 * The sibling `../rbplus-src` reconstructs the same class from the other binary. Both bodies agree
 * line for line, including the escape set and the empty leave-escaped string, so this reading is
 * corroborated rather than merely self-consistent.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Wraps the two CoreFoundation percent-escape calls.
 */
@interface NSStringURLEncoding : NSObject

/**
 * @brief Percent-encodes a string for use in a URL query component.
 *
 * Escapes the RFC 3986 reserved set plus the percent sign and square brackets, in UTF-8.
 *
 * @param string The string to encode.
 * @return The encoded string, or nil when CoreFoundation could not convert it.
 * @ghidraAddress 0x235df4
 */
+ (nullable NSString *)URLEncodedString:(nullable NSString *)string;

/**
 * @brief Percent-decodes a URL-encoded string.
 *
 * Leaves nothing escaped, so every sequence in the input is decoded.
 *
 * @param string The percent-encoded string to decode.
 * @return The decoded string, or nil when CoreFoundation could not convert it.
 * @ghidraAddress 0x235e4c
 */
+ (nullable NSString *)URLDecodedString:(nullable NSString *)string;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
