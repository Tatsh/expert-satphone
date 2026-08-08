/** @file
 * Message-digest helpers.
 *
 * Reconstructed from Ghidra program Jubeat (image base 0x100000000). All @ghidraAddress values are
 * offsets relative to that image base.
 *
 * These are among the few genuine free functions in this tree. None takes a receiver argument or
 * belongs to a class, so the reconstruction rules' search for an owning class is exhausted and they
 * stay free functions. Most are MD5, with one SHA-256 helper that sits beside them in the binary.
 */

#include <stdbool.h>

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Hashes a NUL-terminated C string and returns the digest as a hexadecimal string.
 *
 * Plain CommonCrypto MD5 over @c strlen bytes, rendered as 32 lower-case hexadecimal characters.
 * The binary unrolls the sixteen per-byte appends rather than looping.
 *
 * @param lpcszInput The string to hash, as UTF-8 bytes.
 * @return The digest rendered in hexadecimal, 32 characters long.
 * @ghidraAddress 0x7f168
 */
NSString *CreateMd5HexStringFromCString(const char *lpcszInput);

/**
 * @brief Hashes a NUL-terminated C string and returns the raw 16-byte digest as data.
 *
 * Plain CommonCrypto MD5 over @c strlen bytes, wrapped in @c +[NSData dataWithBytes:length:] .
 * Because the input is measured with @c strlen an embedded NUL truncates the hashed region, so
 * this cannot hash arbitrary binary data; use @c CreateMD5HexString for explicit-length input.
 *
 * @param lpcszInput The string to hash, as UTF-8 bytes. Not checked for @c nullptr .
 * @return The raw digest, exactly 16 bytes.
 * @ghidraAddress 0x7f0d0
 */
NSData *CreateMd5DataFromCString(const char *lpcszInput);

/**
 * @brief Hashes an explicit-length buffer and returns the digest as a hexadecimal string.
 *
 * The save-data integrity hash, used on both the encode and decode sides. Plain CommonCrypto MD5
 * over @p cbLength bytes, rendered as 32 lower-case hexadecimal characters. The binary unrolls the
 * sixteen per-byte appends rather than looping.
 *
 * @param pvData The bytes to hash.
 * @param cbLength The byte count.
 * @return The digest rendered in hexadecimal, 32 characters long.
 * @ghidraAddress 0x1c7258
 */
NSString *CreateMD5HexString(const void *pvData, unsigned int cbLength);

/**
 * @brief Hashes an explicit-length buffer with MD5 and compares it against an expected digest.
 *
 * Plain CommonCrypto MD5 over @p cbLength bytes, whose sixteen-byte result is compared against the
 * caller's expected digest. The comparison is byte-by-byte and short-circuits on the first
 * mismatch, so it is not constant time: fine for detecting accidental corruption, unsuitable as an
 * authentication check against an adversary who can time it. Unlike the @c strlen -based helpers
 * above it takes an explicit length, so it hashes arbitrary binary data (including embedded NULs)
 * correctly and is the right one for file or asset integrity checks.
 *
 * @param pvData The bytes to hash.
 * @param cbLength The byte count.
 * @param pbExpectedDigest The expected digest. The caller must guarantee at least
 *                         @c CC_MD5_DIGEST_LENGTH readable bytes; the length is implicit.
 * @return @c true if the computed digest matches, @c false otherwise.
 * @ghidraAddress 0x7f560
 */
bool VerifyMd5Digest(const void *pvData,
                     unsigned int cbLength,
                     const unsigned char *pbExpectedDigest);

/**
 * @brief Hashes an @c NSData with SHA-256 and returns the digest as a hexadecimal string.
 *
 * Plain CommonCrypto SHA-256 over the data's explicit length, rendered as sixty-four hexadecimal
 * characters. Hashes arbitrary binary data correctly, unlike the @c strlen -based MD5 helpers. The
 * binary duplicates the whole thirty-two-iteration append loop rather than selecting the format
 * string inside it; the two loops differ only in the per-byte format. This is the cluster's only
 * SHA-256 user.
 *
 * @param data The bytes to hash.
 * @param uppercase @c true selects the upper-case @c "%02X" format, @c false the lower-case
 *                  @c "%02x" . The binary tests only bit 0.
 * @return The digest rendered in hexadecimal, 64 characters long.
 * @ghidraAddress 0x7f3d0
 */
NSString *CreateSha256HexStringFromData(NSData *data, bool uppercase);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
