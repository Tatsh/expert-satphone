/**
 * @file
 * String-producing utility helpers.
 *
 * Reconstructed from Ghidra program Jubeat (image base 0x100000000). All @ghidraAddress values are
 * offsets relative to that image base.
 *
 * Both are genuine free functions: neither takes a receiver argument nor belongs to a class, so the
 * reconstruction rules' search for an owning class is exhausted and they stay free functions. They
 * sit beside the digest helpers in @c Md5Utilities in the binary's address space.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Builds a random string of the given length from a fixed sixty-four-character alphabet.
 *
 * Each character is drawn from the alphabet with a masked @c arc4random() value (a bitmask, not a
 * modulo: the alphabet is exactly sixty-four bytes, so the mask is uniform with no bias). Because
 * @c arc4random() is a CSPRNG this is suitable for nonce and token use. A length of zero returns
 * the shared empty string without allocating.
 *
 * @param length The number of characters to produce.
 * @return An autoreleased random string of exactly @p length characters, or @c \@"" when
 *         @p length is zero.
 * @ghidraAddress 0x7efd8
 */
NSString *CreateRandomString(NSUInteger length);

/**
 * Percent-encodes a string for use in a URL, allowing only alphanumerics.
 *
 * Forwards to @c -stringByAddingPercentEncodingWithAllowedCharacters: with
 * @c +[NSCharacterSet alphanumericCharacterSet], which is stricter than the URL query set: the
 * RFC 3986 unreserved marks @c "-", @c ".", @c "_", and @c "~" are percent-encoded too. The set is
 * Unicode-aware, so non-ASCII letters pass through unencoded rather than being UTF-8
 * percent-encoded. A @c nil input yields @c nil, indistinguishable from the encoder itself
 * returning @c nil.
 *
 * @param string The text to encode. @c nil is accepted.
 * @return The autoreleased percent-encoded string, or @c nil if the input was @c nil or the
 *         encoder failed.
 * @ghidraAddress 0x7fb90
 */
NSString *_Nullable CreateUrlEncodedString(NSString *_Nullable string);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
