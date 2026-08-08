/** @file
 * MD5 helpers.
 *
 * Reconstructed from Ghidra program Jubeat (image base 0x100000000). All @ghidraAddress values are
 * offsets relative to that image base.
 *
 * This is one of the few genuine free functions in this tree. It takes no receiver argument and
 * belongs to no class, so the reconstruction rules' search for an owning class is exhausted and it
 * stays a free function.
 */

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

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END

// code: language=Objective-C
// kate: hl Objective-C;
// vim: set ft=objc :
