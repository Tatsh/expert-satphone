/**
 * @file
 * @brief The @c NSData Base64 category and its two upstream C codecs.
 *
 * Reconstructed from Ghidra program Jubeat (image base 0x100000000). All @ghidraAddress values are
 * offsets relative to that image base. This is Matt Gallagher's @c NSData+Base64, so the two C
 * codecs are library code, documented only to the extent needed to use them correctly. They are
 * genuine free functions: neither takes an object receiver nor belongs to a class, and each is
 * called only from the category methods here.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Base64-encodes a byte buffer, returning a freshly allocated NUL-terminated ASCII string.
 *
 * The output is sized @c ((cbLength+2)/3)*4+1 and uses the standard alphabet with @c '=' padding.
 * This copy is the three-argument variant with upstream's @c separateLines parameter stripped, so
 * no seventy-six-column line breaks are emitted. Returns @c nullptr without writing anything if the
 * allocation fails, in which case @p pcbOutputLength is left untouched, so a caller cannot
 * distinguish failure from a zero-length encode.
 *
 * @param pvBuffer The bytes to encode.
 * @param cbLength The number of input bytes.
 * @param pcbOutputLength Receives the output length excluding the NUL when not @c nullptr.
 * @return The @c malloc'd, NUL-terminated output; the caller must @c free() it.
 * @ghidraAddress 0x1ade18
 */
char *_Nullable NewBase64Encode(const void *pvBuffer,
                                size_t cbLength,
                                size_t *_Nullable pcbOutputLength);

/**
 * @brief Base64-decodes an ASCII buffer, returning a freshly allocated byte buffer.
 *
 * A @p cbLength of @c (size_t)-1 means the input is NUL-terminated and its length is measured with
 * @c strlen. Invalid characters are skipped rather than rejected. The output is sized
 * @c ((cbLength+3)/4)*3.
 *
 * @param pszInput The Base64 text to decode.
 * @param cbLength The number of input bytes, or @c (size_t)-1 for a NUL-terminated input.
 * @param pcbOutputLength Receives the decoded byte count when not @c nullptr.
 * @return The @c malloc'd output; the caller must @c free() it.
 * @ghidraAddress 0x1adc58
 */
void *_Nullable NewBase64Decode(const char *pszInput,
                                size_t cbLength,
                                size_t *_Nullable pcbOutputLength);

#ifdef __cplusplus
}
#endif

/**
 * @brief Base64 encoding and decoding for @c NSData, from Matt Gallagher's @c NSData+Base64.
 */
@interface NSData (Base64)

/**
 * @brief Decodes a Base64 string into the bytes it represents.
 * @param aString The Base64 text; UTF-8 bytes are decoded.
 * @return The decoded data, autoreleased.
 * @ghidraAddress 0x1adfc4
 */
+ (NSData *)dataFromBase64String:(NSString *)aString;

/**
 * @brief Encodes the receiver's bytes as a Base64 string.
 * @return The Base64 text, autoreleased.
 * @ghidraAddress 0x1ae084
 */
- (NSString *)base64EncodedString;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
