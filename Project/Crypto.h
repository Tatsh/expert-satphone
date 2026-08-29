/**
 * @file
 * @brief Hashing and AES helpers.
 *
 * Reconstructed from Ghidra program Jubeat (class Crypto, image base 0x100000000). All
 * @ghidraAddress values are offsets relative to that image base.
 *
 * The superclass is @c NSObject. The class has no ivars and no instance methods.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief Four CommonCrypto wrappers.
 */
@interface Crypto : NSObject

/**
 * @brief SHA-1 of a data buffer, returned as the raw twenty-byte digest.
 *
 * The only one of the three digest methods that takes data rather than a string, and the only one
 * whose length handling is correct.
 *
 * @param data The bytes to hash.
 * @return The digest, twenty bytes.
 * @ghidraAddress 0x266a44
 */
+ (nonnull NSData *)createHash:(nullable NSData *)data;

/**
 * @brief SHA-1 of a string, returned as forty lower-case hexadecimal characters.
 *
 * **Mis-measures non-ASCII input.** It takes the string's UTF-8 C string but its *character* count
 * from @c -length, so any string containing a character outside ASCII is hashed over the wrong
 * number of bytes. See TYPES_PENDING.md.
 *
 * @param string The text to hash.
 * @return The digest in hexadecimal.
 * @ghidraAddress 0x266b14
 */
+ (nonnull NSString *)sha1:(nullable NSString *)string;

/**
 * @brief SHA-256 of a string, returned as sixty-four lower-case hexadecimal characters.
 *
 * Carries the same length mismatch as @c +sha1: .
 *
 * @param string The text to hash.
 * @return The digest in hexadecimal.
 * @ghidraAddress 0x266c9c
 */
+ (nonnull NSString *)sha256:(nullable NSString *)string;

/**
 * @brief AES-128 encrypt or decrypt with PKCS#7 padding and no initialisation vector.
 *
 * The key length is fixed at sixteen bytes whatever @c key actually holds, so a shorter key reads
 * past its own buffer and a longer one is silently truncated. Running with no IV means ECB mode,
 * so identical plaintext blocks produce identical ciphertext.
 *
 * @param cryptor @c kCCEncrypt or @c kCCDecrypt.
 * @param value The bytes to transform.
 * @param key The key. Must be at least sixteen bytes.
 * @return The result, or nil when CommonCrypto reports a failure.
 * @ghidraAddress 0x266e24
 */
+ (nullable NSData *)cryptorToData:(unsigned int)cryptor
                             value:(nullable NSData *)value
                               key:(nullable NSData *)key;

@end

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
